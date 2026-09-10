extends Node
## Autoload "GameState" — todo o estado e regras do jogo, sem UI.
## Registrar depois de ItemData nos autoloads.
## UI só lê e chama métodos públicos; nunca escreve em `board` direto.

signal coins_changed(new_value: float)
signal gems_changed(new_value: int)
signal board_changed()
signal item_merged(cell_index: int, tag: String) # tag: "" | "jump" | "bonus"
signal item_shipped(cell_index: int, bonus: float)
signal vitrine_progress_changed()
signal vitrine_completed(vitrine_index: int)
signal game_won()
signal golden_collected(cell_index: int)
signal orders_changed()
signal offline_earnings_ready(seconds_away: float, coins_earned: float)

const BOARD_SIZE := 25
const MAX_LEVEL := 10
const SUPER_TARGET := 1        # itens de nível 10 necessários pra colorir 1 gôndola inteira
const VITRINE_GOAL := 5        # vitrines pra "vencer" o ciclo
const MAX_OFFLINE_SECONDS := 8.0 * 3600.0
const SAVE_PATH := "user://savegame.json"

var coins: float = 0.0
var gems: int = 5
var lifetime_coins: float = 0.0    # nunca decresce; usado no requisito de prestígio

# board[i]: null | "golden" | {"level": int}
var board: Array = []
var golden_indices: Array[int] = []
var selected_index: int = -1

var oven_timer_ms: float = 0.0
var oven_interval_ms: float = 4000.0
var oven_speed_lvl: int = 0
var income_lvl: int = 0

var boost_until_ms: int = 0
var ad_cooldown_until_ms: int = 0
var spawn_boost_until_ms: int = 0
var no_ads: bool = false
var sound_enabled: bool = true     # preferência, sobrevive a hard_reset
## "auto" | "mobile" | "desktop" — escolhido pelo jogador no menu de pausa.
## "auto" deixa o SDK decidir pelo aparelho.
var display_mode: String = "auto"

## Idioma inicial do jogo. "en" = inglês para todo mundo na primeira
## execução; o jogador troca no menu de pausa, onde também existe a opção
## "Automático" ("") pra seguir o idioma do aparelho.
var locale: String = "en"

var prestige_mult: float = 1.0
var prestige_count: int = 0

var orders: Array = []             # [{id, level, reward}], sempre 3 itens

var super_count: int = 0
var vitrines_completed: int = 0

## A renda offline é calculada durante load_game(), que roda no _ready()
## deste autoload — ou seja, ANTES da cena principal existir. Emitir o
## sinal ali era o mesmo que emitir pro vazio: ninguém estava conectado
## ainda e o aviso nunca aparecia. Agora fica guardado aqui e a UI busca
## quando ela mesma estiver pronta.
var pending_offline_seconds: float = 0.0
var pending_offline_coins: float = 0.0

var _autosave_accum: float = 0.0
var _tick_accum: float = 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	_new_board()
	var loaded := load_game()
	apply_locale()
	if not loaded:
		spawn_base(); spawn_base(); spawn_base()
	ensure_orders()


## Aplica o idioma escolhido (ou o do aparelho, se for automático).
func apply_locale() -> void:
	TranslationServer.set_locale(locale if locale != "" else OS.get_locale())


## iOS e Android encerram o app em segundo plano sem aviso nenhum. Estes
## são os únicos momentos garantidos pra gravar o progresso — sem isso, o
## jogador podia perder até 15s de jogo toda vez que trocasse de app.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			save_game()


func _process(delta: float) -> void:
	_tick_accum += delta
	if _tick_accum >= 1.0:
		_tick_accum -= 1.0
		_tick()

	_autosave_accum += delta
	if _autosave_accum >= 15.0:
		_autosave_accum = 0.0
		save_game()


func _new_board() -> void:
	board = []
	board.resize(BOARD_SIZE)
	board.fill(null)


# ================= ECONOMIA =================

func oven_speed_cost() -> int:
	return int(round(60.0 * pow(1.55, oven_speed_lvl)))

func income_cost() -> int:
	return int(round(90.0 * pow(1.65, income_lvl)))

func income_multiplier() -> float:
	var m := 1.0 + income_lvl * 0.25
	# no_ads é um bônus permanente por si só; antes ele era simulado com um
	# "boost de 1 ano" medido em ticks, que zeravam a cada reinício do app.
	if no_ads or Time.get_ticks_msec() < boost_until_ms:
		m *= 2.0
	return m * prestige_mult

func total_income() -> float:
	var total := 0.0
	for cell in board:
		if cell is Dictionary:
			total += ItemData.item_income(cell["level"])
	return total * income_multiplier()


# ================= TABULEIRO =================

func rand_empty_cell() -> int:
	var empties: Array[int] = []
	for i in range(BOARD_SIZE):
		if board[i] == null:
			empties.append(i)
	if empties.is_empty():
		return -1
	return empties[rng.randi_range(0, empties.size() - 1)]

func spawn_base() -> bool:
	var idx := rand_empty_cell()
	if idx < 0:
		return false
	board[idx] = {"level": 1}
	board_changed.emit()
	return true

func maybe_spawn_golden() -> void:
	if not golden_indices.is_empty():
		return
	if rng.randf() < 0.05:
		var idx := rand_empty_cell()
		if idx >= 0:
			board[idx] = "golden"
			golden_indices.append(idx)

func is_board_full() -> bool:
	for cell in board:
		if cell == null:
			return false
	return true

func highest_level_on_board() -> int:
	var max_lvl := 1
	for cell in board:
		if cell is Dictionary:
			max_lvl = max(max_lvl, cell["level"])
	return max_lvl


# ================= FUSÃO =================

## Resultado de fundir 2 itens do mesmo nível: 85% resultado normal,
## 5% pula 2 níveis ("jump"), 10% sobe 1 nível com bônus de moeda ("bonus").
## Chance de uma fusão pular um nível inteiro (1 + 1 = 3). Era 5%, que
## parece pouco no papel mas não é: numa partida se fazem dezenas de fusões
## por minuto, então 1 em 20 acontecia o tempo todo e o pulo deixava de ser
## surpresa.
const JUMP_CHANCE := 0.02

## Chance do bônus de moedas (mesmo nível de sempre, só paga mais).
const BONUS_CHANCE := 0.10

## Fusões mínimas entre dois pulos. Só baixar a porcentagem não resolveria
## sozinho: sorteio independente forma grupos, e dois pulos seguidos são
## justamente o que dá a sensação de "está acontecendo demais". Com o
## intervalo mínimo, o pulo sai a cada ~60 fusões em vez de ~20, e nunca
## em dupla.
const MIN_MERGES_BETWEEN_JUMPS := 12

var _merges_since_jump: int = MIN_MERGES_BETWEEN_JUMPS


func merge_result(level: int) -> Dictionary:
	_merges_since_jump += 1
	var r := rng.randf()

	if (r < JUMP_CHANCE
			and level + 2 <= MAX_LEVEL
			and _merges_since_jump >= MIN_MERGES_BETWEEN_JUMPS):
		_merges_since_jump = 0
		return {"level": level + 2, "tag": "jump"}

	if r < JUMP_CHANCE + BONUS_CHANCE:
		return {"level": mini(level + 1, MAX_LEVEL), "tag": "bonus"}

	return {"level": mini(level + 1, MAX_LEVEL), "tag": ""}

func on_cell_tapped(idx: int) -> void:
	var v = board[idx]

	# "is String and" checa o tipo antes de comparar — Dictionary == String
	# quebra em runtime no Godot se comparado direto.
	if v is String and v == "golden":
		board[idx] = null
		golden_indices.erase(idx)
		gems += 3
		gems_changed.emit(gems)
		golden_collected.emit(idx)
		board_changed.emit()
		return

	if v == null:
		return

	if selected_index == -1:
		selected_index = idx
		board_changed.emit()
		return

	if selected_index == idx:
		selected_index = -1
		board_changed.emit()
		return

	var a := selected_index
	var b := idx
	var va = board[a]
	var vb = board[b]

	if va is Dictionary and vb is Dictionary and va["level"] == vb["level"] and va["level"] < MAX_LEVEL:
		var result := merge_result(va["level"])
		board[a] = null
		board[b] = {"level": result["level"]}
		selected_index = -1

		var gain := float(result["level"]) * 5.0
		if result["tag"] == "jump":
			gain += 15.0
		elif result["tag"] == "bonus":
			gain += 12.0
		_add_coins(gain)

		item_merged.emit(b, result["tag"])
		_ship_if_final_item(b, result["level"])
		board_changed.emit()
	else:
		# Níveis diferentes: troca a seleção em vez de ignorar o toque.
		selected_index = idx
		board_changed.emit()

## Item no MAX_LEVEL sai sozinho do tabuleiro (não funde mais) e conta
## como entrega pra vitrine atual.
func _ship_if_final_item(idx: int, level: int) -> bool:
	if level < MAX_LEVEL:
		return false
	board[idx] = null
	var bonus := float(level) * 20.0
	_add_coins(bonus)
	super_count += 1
	item_shipped.emit(idx, bonus)
	vitrine_progress_changed.emit()

	if super_count >= SUPER_TARGET:
		super_count = 0
		vitrines_completed += 1
		vitrine_completed.emit(vitrines_completed)
		if vitrines_completed >= VITRINE_GOAL:
			game_won.emit()
	return true

func _add_coins(amount: float) -> void:
	coins += amount
	lifetime_coins += amount
	coins_changed.emit(coins)


# ================= PEDIDOS DOS CLIENTES =================

func make_order() -> Dictionary:
	# Nunca pede o item máximo (sai sozinho do tabuleiro, não dá pra guardar
	# pra entrega) nem nível acima do que o jogador já produziu.
	var cap: int = mini(MAX_LEVEL - 1, highest_level_on_board() + 1)
	var level: int = 1 + rng.randi_range(0, cap - 1)
	return {
		"id": str(rng.randi()) + str(Time.get_ticks_msec()),
		"level": level,
		"reward": level * 40 + 20,
	}

func ensure_orders() -> void:
	while orders.size() < 3:
		orders.append(make_order())
	orders_changed.emit()

func try_fulfill_order(order_id: String) -> bool:
	var order = null
	for o in orders:
		if o["id"] == order_id:
			order = o
			break
	if order == null:
		return false

	var idx := -1
	for i in range(BOARD_SIZE):
		var cell = board[i]
		if cell is Dictionary and cell["level"] == order["level"]:
			idx = i
			break
	if idx < 0:
		return false

	board[idx] = null
	_add_coins(float(order["reward"]))
	orders.erase(order)
	ensure_orders()
	board_changed.emit()
	return true


# ================= LOJA / UPGRADES =================

func buy_oven_speed() -> bool:
	var cost := oven_speed_cost()
	if coins < cost:
		return false
	coins -= cost
	oven_speed_lvl += 1
	oven_interval_ms = max(800.0, 4000.0 - oven_speed_lvl * 300.0)
	coins_changed.emit(coins)
	return true

func buy_income_upgrade() -> bool:
	var cost := income_cost()
	if coins < cost:
		return false
	coins -= cost
	income_lvl += 1
	coins_changed.emit(coins)
	return true

## Cacau nasce 2x mais rápido por 30s — mesmo total de itens que 60s no
## ritmo normal, só concentrado em metade do tempo.
func buy_spawn_boost() -> bool:
	if gems < 8:
		return false
	gems -= 8
	spawn_boost_until_ms = Time.get_ticks_msec() + 30_000
	gems_changed.emit(gems)
	return true

func watch_ad_for_income_boost() -> bool:
	if no_ads or Time.get_ticks_msec() < ad_cooldown_until_ms:
		return false
	boost_until_ms = Time.get_ticks_msec() + 30_000
	ad_cooldown_until_ms = Time.get_ticks_msec() + 60_000
	return true

func buy_no_ads() -> void:
	no_ads = true
	coins_changed.emit(coins)
	save_game()

## Usado pelo SDK quando uma compra de gemas é confirmada pela loja.
func add_gems(amount: int) -> void:
	gems += amount
	gems_changed.emit(gems)
	save_game()


# ================= PRESTÍGIO =================

func prestige_threshold() -> float:
	return 4000.0 * pow(2.0, prestige_count)

func can_prestige() -> bool:
	return lifetime_coins >= prestige_threshold()

func do_prestige() -> void:
	if not can_prestige():
		return
	prestige_mult += 0.15 + prestige_count * 0.05
	prestige_count += 1
	_new_board()
	golden_indices.clear()
	coins = 0.0
	selected_index = -1
	oven_timer_ms = 0.0
	coins_changed.emit(coins)
	board_changed.emit()
	save_game()


# ================= TICK PRINCIPAL =================

func _tick() -> void:
	var income := total_income()
	if income > 0.0:
		_add_coins(income)

	var boosted := Time.get_ticks_msec() < spawn_boost_until_ms
	var effective_interval: float = oven_interval_ms / 2.0 if boosted else oven_interval_ms
	oven_timer_ms += 1000.0
	if oven_timer_ms >= effective_interval:
		oven_timer_ms = 0.0
		spawn_base()

	maybe_spawn_golden()


# ================= VITÓRIA + REINÍCIO =================

## Reset completo — zera tudo, inclusive gems/upgrades/prestígio, que
## do_prestige() preserva. sound_enabled e locale são as únicas exceções.
func hard_reset() -> void:
	coins = 0.0
	gems = 5
	lifetime_coins = 0.0
	_new_board()
	golden_indices.clear()
	selected_index = -1
	oven_timer_ms = 0.0
	oven_interval_ms = 4000.0
	oven_speed_lvl = 0
	income_lvl = 0
	boost_until_ms = 0
	ad_cooldown_until_ms = 0
	spawn_boost_until_ms = 0
	# no_ads é uma compra de verdade — apagar progresso não pode tirar do
	# jogador algo que ele pagou (e as duas lojas tratam isso como bug).
	prestige_mult = 1.0
	prestige_count = 0
	orders = []
	super_count = 0
	vitrines_completed = 0
	pending_offline_seconds = 0.0
	pending_offline_coins = 0.0
	_merges_since_jump = MIN_MERGES_BETWEEN_JUMPS

	spawn_base(); spawn_base(); spawn_base()
	ensure_orders()

	coins_changed.emit(coins)
	gems_changed.emit(gems)
	board_changed.emit()
	vitrine_progress_changed.emit()

	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	save_game()


# ================= SAVE / LOAD =================
# JSON em user:// (sem window.storage — isso é Godot, não navegador).

## Quanto falta (em ms) pra um prazo vencer, nunca negativo.
func _remaining(deadline_ms: int) -> int:
	return maxi(0, deadline_ms - Time.get_ticks_msec())

func serialize() -> Dictionary:
	return {
		"coins": coins, "gems": gems, "lifetime_coins": lifetime_coins,
		"board": board, "golden_indices": golden_indices,
		"oven_timer_ms": oven_timer_ms, "oven_interval_ms": oven_interval_ms,
		"oven_speed_lvl": oven_speed_lvl, "income_lvl": income_lvl,
		# Prazos vão pro disco como TEMPO RESTANTE, não como instante final.
		# Time.get_ticks_msec() conta desde que o app abriu e volta pra zero
		# a cada execução — salvar o instante final fazia um boost de 30s
		# virar "30 segundos a partir do zero" e reaparecer ativo na sessão
		# seguinte, e o cooldown de anúncio travar o botão sem motivo.
		"boost_remaining_ms": _remaining(boost_until_ms),
		"ad_cooldown_remaining_ms": _remaining(ad_cooldown_until_ms),
		"spawn_boost_remaining_ms": _remaining(spawn_boost_until_ms),
		"no_ads": no_ads, "sound_enabled": sound_enabled, "locale": locale,
		"display_mode": display_mode,
		"prestige_mult": prestige_mult, "prestige_count": prestige_count,
		"orders": orders, "super_count": super_count,
		"vitrines_completed": vitrines_completed,
		"saved_at_unix": Time.get_unix_time_from_system(),
	}

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(serialize()))
	f.close()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return false

	apply_save_data(parsed)
	return true

## Aplica um save (formato de serialize()) ao estado atual — usado tanto
## pro save local quanto por uma futura integração de save na nuvem
## (accounts_scaffold/CloudSaveManager.gd).
func apply_save_data(parsed: Dictionary) -> void:
	coins = parsed.get("coins", 0.0)
	gems = parsed.get("gems", 5)
	lifetime_coins = parsed.get("lifetime_coins", 0.0)
	board = parsed.get("board", board)
	# JSON não distingue int/float — todo número volta como float. "level"
	# precisa ser int (índices/parâmetros tipados), normaliza aqui uma vez.
	for i in range(board.size()):
		if board[i] is Dictionary and board[i].has("level"):
			board[i]["level"] = int(board[i]["level"])
	golden_indices.assign(parsed.get("golden_indices", []))
	oven_timer_ms = parsed.get("oven_timer_ms", 0.0)
	oven_interval_ms = parsed.get("oven_interval_ms", 4000.0)
	oven_speed_lvl = parsed.get("oven_speed_lvl", 0)
	income_lvl = parsed.get("income_lvl", 0)
	var now := Time.get_ticks_msec()
	boost_until_ms = now + int(parsed.get("boost_remaining_ms", 0))
	ad_cooldown_until_ms = now + int(parsed.get("ad_cooldown_remaining_ms", 0))
	spawn_boost_until_ms = now + int(parsed.get("spawn_boost_remaining_ms", 0))
	no_ads = parsed.get("no_ads", false)
	display_mode = parsed.get("display_mode", "auto")
	sound_enabled = parsed.get("sound_enabled", true)
	locale = parsed.get("locale", "")
	prestige_mult = parsed.get("prestige_mult", 1.0)
	prestige_count = parsed.get("prestige_count", 0)
	orders = parsed.get("orders", [])
	for o in orders:
		if o is Dictionary:
			if o.has("level"):
				o["level"] = int(o["level"])
			if o.has("reward"):
				o["reward"] = int(o["reward"])
	super_count = parsed.get("super_count", 0)
	vitrines_completed = parsed.get("vitrines_completed", 0)

	# Renda offline: só notifica se ficou fora 45s+, com teto de 8h.
	var saved_at: float = parsed.get("saved_at_unix", Time.get_unix_time_from_system())
	var elapsed: float = Time.get_unix_time_from_system() - saved_at
	if elapsed >= 45.0:
		var capped: float = min(elapsed, MAX_OFFLINE_SECONDS)
		var earned: float = total_income() * capped
		if earned > 0.0:
			pending_offline_seconds = elapsed
			pending_offline_coins = earned
			offline_earnings_ready.emit(elapsed, earned)

	coins_changed.emit(coins)
	gems_changed.emit(gems)
	board_changed.emit()
	vitrine_progress_changed.emit()

func collect_offline_earnings(amount: float) -> void:
	pending_offline_seconds = 0.0
	pending_offline_coins = 0.0
	_add_coins(amount)
	save_game()

## Chamado pela UI assim que ela termina de montar, pra pegar uma renda
## offline que tenha sido calculada antes dela existir.
func consume_pending_offline() -> bool:
	if pending_offline_coins <= 0.0:
		return false
	offline_earnings_ready.emit(pending_offline_seconds, pending_offline_coins)
	return true
