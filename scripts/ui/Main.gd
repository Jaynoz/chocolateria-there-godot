extends Control
## Script da cena principal — liga cada elemento de UI ao GameState.
## Nenhuma regra de jogo mora aqui, só a ponte entre toque e estado.

@onready var coin_label: Label = %CoinLabel
@onready var gem_label: Label = %GemLabel
@onready var heat_bar: ProgressBar = %HeatBar
@onready var heat_label: Label = %HeatLabel

@onready var oven_button: Button = %OvenButton
@onready var oven_progress: ProgressBar = %OvenProgress

@onready var prestige_panel: Control = %PrestigePanel
@onready var prestige_label: Label = %PrestigeLabel
@onready var prestige_button: Button = %PrestigeButton

@onready var oven_speed_button: Button = %OvenSpeedButton
@onready var income_button: Button = %IncomeButton
@onready var spawn_boost_button: Button = %SpawnBoostButton
@onready var watch_ad_button: Button = %WatchAdButton
@onready var no_ads_button: Button = %NoAdsButton
@onready var restore_purchases_button: Button = %RestorePurchasesButton

@onready var offline_modal: Control = %OfflineModal
@onready var offline_away_label: Label = %OfflineAwayLabel
@onready var offline_earned_label: Label = %OfflineEarnedLabel
@onready var offline_double_button: Button = %OfflineDoubleButton
@onready var offline_collect_button: Button = %OfflineCollectButton

@onready var win_modal: Control = %WinModal
@onready var win_fireworks: CPUParticles2D = %WinFireworks
@onready var restart_button: Button = %RestartButton

@onready var pause_button: Button = %PauseButton
@onready var pause_modal: Control = %PauseModal
@onready var sound_toggle: CheckButton = %SoundToggle
@onready var language_button: OptionButton = %LanguageButton
@onready var screen_mode_button: OptionButton = %ScreenModeButton

@onready var account_status_label: Label = %AccountStatusLabel
@onready var sign_in_apple_button: Button = %SignInAppleButton
@onready var sign_in_google_button: Button = %SignInGoogleButton
@onready var sign_out_button: Button = %SignOutButton
@onready var delete_account_button: Button = %DeleteAccountButton
@onready var delete_account_confirm_dialog: ConfirmationDialog = %DeleteAccountConfirmDialog
@onready var visit_store_button: Button = %VisitStoreButton
@onready var reset_progress_button: Button = %ResetProgressButton
@onready var resume_button: Button = %ResumeButton
@onready var reset_confirm_dialog: ConfirmationDialog = %ResetConfirmDialog

@onready var estopa_img: TextureRect = %EstopaImg
@onready var estopa_label: Label = %EstopaLabel

@onready var fx_layer: Control = %FxLayer
@onready var flash_rect: ColorRect = %FlashRect
@onready var board_panel: PanelContainer = %BoardPanel

var _pending_offline_coins: float = 0.0
var _offline_doubled: bool = false

# ---------------- Estopa: piadas e reações de humor ----------------
const ESTOPA_JOKES_GENERAL := [
	"I'm not saying I ate a cocoa bean when nobody was looking. I'm also not NOT saying that.",
	"Fun fact: I have zero opposable thumbs and I still outwork most interns.",
	"They said a dog can't run a chocolate factory. Bold of them to assume I'm JUST a dog.",
	"I dream in shades of brown. My therapist says it's fine. I don't fully believe her.",
	"My love language is cacao. Second love language: also cacao.",
	"I'd tell you a chocolate joke, but it's a little dark.",
	"Somewhere, a cat is judging this entire operation. Ignore it.",
	"I tried to merge two of my socks earlier. Didn't work. Still proud of myself.",
	"Breaking news: local dog still hasn't been paid in actual treats.",
	"I have an honorary PhD in Looking Adorable While Doing Nothing.",
	"Working hard or hardly working? Yes.",
	"I once stared at the golden box for six minutes straight. No regrets.",
	"Is it just me, or does the cocoa smell like a promotion?",
	"I'm 90% fur, 10% ambition.",
]
const ESTOPA_JOKES_FAST := [
	"Whoa, slow down speed racer! You're making ME look lazy!",
	"Okay THAT was impressive. Telling all the cocoa beans about you.",
	"You merge like you've got something to prove. Respect.",
	"Not crying, that's just cocoa dust. Great work out there!",
	"At this rate we're getting promoted. To what, unclear. But something!",
	"Certified chocolate machine right here, folks.",
]
const ESTOPA_JOKES_SLOW := [
	"Take your time. I'll just be over here. Aging.",
	"I've seen glaciers move faster than this board is filling up.",
	"Is this a chocolate factory or a nap convention?",
	"Starting to think you forgot I exist. Rude, but okay.",
	"No pressure, but the cocoa beans are literally begging for attention.",
	"Tick tock, chocolate doesn't merge itself. Well — it doesn't merge AT ALL right now.",
]
var _estopa_last_action_ms: int = 0
var _estopa_merge_times: Array[int] = []
var _estopa_timer_s: float = 2.0


func _ready() -> void:
	GameState.coins_changed.connect(_on_coins_changed)
	GameState.gems_changed.connect(_on_gems_changed)
	GameState.board_changed.connect(_refresh_oven_and_heat)
	GameState.offline_earnings_ready.connect(_show_offline_modal)
	GameState.game_won.connect(_show_win_modal)
	GameState.item_merged.connect(_on_item_merged_for_estopa)
	GameState.item_merged.connect(func(_cell_index, _tag): _fly_coin())
	GameState.item_shipped.connect(func(_cell_index, _bonus): _fly_coin())
	GameState.vitrine_completed.connect(_on_vitrine_completed_fx)

	oven_button.pressed.connect(_on_oven_pressed)
	oven_speed_button.pressed.connect(_on_oven_speed_pressed)
	income_button.pressed.connect(_on_income_pressed)
	spawn_boost_button.pressed.connect(_on_spawn_boost_pressed)
	watch_ad_button.pressed.connect(_on_watch_ad_pressed)
	no_ads_button.pressed.connect(_on_no_ads_pressed)
	restore_purchases_button.pressed.connect(_on_restore_purchases_pressed)

	offline_double_button.pressed.connect(_on_offline_double)
	offline_collect_button.pressed.connect(_on_offline_collect)
	restart_button.pressed.connect(_on_restart)

	pause_button.pressed.connect(_on_pause_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	visit_store_button.pressed.connect(_on_visit_store_pressed)
	reset_progress_button.pressed.connect(_on_reset_progress_pressed)
	reset_confirm_dialog.confirmed.connect(_on_reset_confirmed)
	sound_toggle.toggled.connect(_on_sound_toggled)
	sound_toggle.button_pressed = GameState.sound_enabled

	_setup_language_button()
	_setup_screen_mode_button()

	sign_in_apple_button.pressed.connect(_on_sign_in_apple_pressed)
	sign_in_google_button.pressed.connect(_on_sign_in_google_pressed)
	sign_out_button.pressed.connect(_on_sign_out_pressed)
	delete_account_button.pressed.connect(_on_delete_account_pressed)
	delete_account_confirm_dialog.confirmed.connect(_on_delete_account_confirmed)
	_refresh_account_ui()

	if prestige_button:
		prestige_button.pressed.connect(_on_prestige_pressed)

	offline_modal.visible = false
	win_modal.visible = false
	pause_modal.visible = false

	SDK.rewarded_ad_finished.connect(_on_rewarded_ad_finished)
	SDK.purchase_finished.connect(_on_purchase_finished)
	SDK.auth_changed.connect(func(_signed_in, _name): _refresh_account_ui())

	_apply_safe_area()
	get_tree().get_root().size_changed.connect(_apply_safe_area)

	_on_coins_changed(GameState.coins)
	_on_gems_changed(GameState.gems)
	_refresh_shop()
	_refresh_oven_and_heat()
	_estopa_last_action_ms = Time.get_ticks_msec()

	# A renda offline é calculada no autoload, antes desta cena existir —
	# por isso ela é buscada aqui em vez de esperar o sinal chegar.
	GameState.consume_pending_offline()

	set_process(true)


## Empurra a UI pra dentro da área segura da tela: notch e ilha dinâmica no
## iPhone, câmera furada e barra de gestos no Android (que desde o Android
## 15 desenha por baixo do app por padrão, sem pedir licença).
func _apply_safe_area() -> void:
	var m := SDK.safe_area_margins()
	var root_margin := $MarginContainer as MarginContainer
	root_margin.add_theme_constant_override("margin_left", 16 + int(m["left"]))
	root_margin.add_theme_constant_override("margin_right", 16 + int(m["right"]))
	root_margin.add_theme_constant_override("margin_top", maxi(20, int(m["top"])) + 12)
	root_margin.add_theme_constant_override("margin_bottom", maxi(16, int(m["bottom"])) + 12)

func _on_vitrine_completed_fx(_vitrine_index: int) -> void:
	_screen_pop()
	SDK.haptic(35)


func _process(delta: float) -> void:
	# Este nó roda com process_mode = ALWAYS (senão o Esc não fecharia o
	# menu de pausa), então precisa se conter sozinho enquanto pausado.
	if get_tree().paused:
		return

	_refresh_oven_and_heat()
	_refresh_prestige()
	_refresh_shop_dynamic_labels()
	# _refresh_account_ui() saiu daqui: era um get_node + reescrita de label
	# 60x por segundo. Agora só roda quando o estado de login muda.

	_estopa_timer_s -= delta
	if _estopa_timer_s <= 0.0:
		_estopa_timer_s = 12.0 + randf() * 6.0
		_estopa_speak()

## Atalhos de teclado — ui_accept/ui_cancel já vêm mapeados pro Enter/Espaço
## e Esc por padrão no Godot, sem precisar configurar InputMap. Isso é o
## suporte de teclado exigido pro selo "Otimizado" do Google Play Games
## para PC (o Input SDK em si não é necessário — o jogo só usa clique
## esquerdo/toque simples, que está isento dessa exigência).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if pause_modal.visible:
			_on_resume_pressed()
		else:
			_on_pause_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		var modal_open := pause_modal.visible or offline_modal.visible or win_modal.visible or reset_confirm_dialog.visible or delete_account_confirm_dialog.visible
		if not modal_open:
			_on_oven_pressed()
			get_viewport().set_input_as_handled()


# ---------------- Header ----------------

func _on_coins_changed(v: float) -> void:
	coin_label.text = "🪙 %s" % _fmt(v)

func _on_gems_changed(v: int) -> void:
	gem_label.text = "💎 %d" % v

func _fmt(n: float) -> String:
	if n >= 1_000_000:
		return "%.2fM" % (n / 1_000_000.0)
	if n >= 1000:
		return "%.1fk" % (n / 1000.0)
	return str(int(n))


# ---------------- Forno / calor de produção ----------------

func _on_oven_pressed() -> void:
	SoundManager.play_sfx("click")
	_estopa_last_action_ms = Time.get_ticks_msec()
	if GameState.is_board_full():
		return
	GameState.spawn_base()
	GameState.oven_timer_ms = max(0.0, GameState.oven_timer_ms - GameState.oven_interval_ms * 0.4)

func _on_oven_speed_pressed() -> void:
	if GameState.buy_oven_speed():
		SoundManager.play_sfx("click")
	_refresh_shop()

func _on_income_pressed() -> void:
	if GameState.buy_income_upgrade():
		SoundManager.play_sfx("click")
	_refresh_shop()

func _on_spawn_boost_pressed() -> void:
	if GameState.buy_spawn_boost():
		SoundManager.play_sfx("click")
	_refresh_shop()

func _on_watch_ad_pressed() -> void:
	# O prêmio NÃO é dado aqui. Quem decide é o retorno do anúncio, em
	# _on_rewarded_ad_finished — se o jogador fechar o vídeo no meio, a
	# rede de anúncios não paga e o bônus não pode ser concedido.
	watch_ad_button.disabled = true
	watch_ad_button.text = tr("Carregando…")
	SDK.show_rewarded_ad("income_boost")

func _on_no_ads_pressed() -> void:
	SDK.purchase(SDK.PRODUCT_REMOVE_ADS)

func _on_restore_purchases_pressed() -> void:
	restore_purchases_button.disabled = true
	SDK.restore_purchases()

func _on_purchase_finished(product_id: String, success: bool, message: String) -> void:
	restore_purchases_button.disabled = false
	if success:
		SoundManager.play_sfx("coin")
	elif message != "":
		account_status_label.text = message
	_refresh_shop()

## reward_id identifica qual botão pediu o anúncio; granted diz se o
## jogador realmente assistiu até o fim.
func _on_rewarded_ad_finished(reward_id: String, granted: bool) -> void:
	match reward_id:
		"income_boost":
			if granted:
				GameState.watch_ad_for_income_boost()
				SoundManager.play_sfx("coin")
		"offline_double":
			if granted:
				_apply_offline_double()
			else:
				offline_double_button.disabled = false
				offline_double_button.text = tr("🎬 Assistir anúncio: dobrar")
	_refresh_shop()
	_refresh_shop_dynamic_labels()

func _on_prestige_pressed() -> void:
	GameState.do_prestige()

func _refresh_oven_and_heat() -> void:
	var full := GameState.is_board_full()
	oven_button.disabled = full
	oven_button.text = tr("🍫 Tabuleiro cheio") if full else tr("🍫 Produzir Cacau")

	var boosted := Time.get_ticks_msec() < GameState.spawn_boost_until_ms
	var effective_interval: float = GameState.oven_interval_ms / 2.0 if boosted else GameState.oven_interval_ms
	oven_progress.value = clamp((GameState.oven_timer_ms / effective_interval) * 100.0, 0.0, 100.0)

	var rate := GameState.total_income()
	heat_label.text = "+%s/s" % _fmt(rate)
	heat_bar.value = clamp(8.0 + rate * 2.2, 0.0, 100.0)


# ---------------- Prestígio ----------------

func _refresh_prestige() -> void:
	var threshold := GameState.prestige_threshold()
	var panel_visible := GameState.prestige_count > 0 or GameState.lifetime_coins >= threshold * 0.5
	prestige_panel.visible = panel_visible
	if not panel_visible:
		return
	var gain := 0.15 + GameState.prestige_count * 0.05
	var can := GameState.can_prestige()
	prestige_label.text = (
		tr("Resete e ganhe +%.2fx de renda permanente. %s")
		% [gain, (tr("Disponível agora!") if can else tr("Precisa de %s moedas (%s/%s)") % [_fmt(threshold), _fmt(GameState.lifetime_coins), _fmt(threshold)])]
	)
	prestige_button.disabled = not can
	prestige_button.text = tr("Renascer (x%.2f)") % (GameState.prestige_mult + gain)


# ---------------- Loja ----------------

func _refresh_shop() -> void:
	oven_speed_button.text = "🪙 %d" % GameState.oven_speed_cost()
	oven_speed_button.disabled = GameState.coins < GameState.oven_speed_cost()

	income_button.text = "🪙 %d" % GameState.income_cost()
	income_button.disabled = GameState.coins < GameState.income_cost()

	spawn_boost_button.disabled = GameState.gems < 8

	no_ads_button.disabled = GameState.no_ads
	# Sem loja no build (PC de desenvolvimento, por exemplo), esconde o que
	# não tem como funcionar em vez de deixar botão morto na tela.
	no_ads_button.visible = SDK.has_iap() or OS.is_debug_build()
	restore_purchases_button.visible = no_ads_button.visible

func _refresh_shop_dynamic_labels() -> void:
	var boosted := Time.get_ticks_msec() < GameState.spawn_boost_until_ms
	if boosted:
		var secs := int(ceil((GameState.spawn_boost_until_ms - Time.get_ticks_msec()) / 1000.0))
		spawn_boost_button.text = tr("Ativo (%ds)") % secs
	else:
		spawn_boost_button.text = "💎 8"

	var ad_on_cooldown := Time.get_ticks_msec() < GameState.ad_cooldown_until_ms
	var ad_ok := SDK.is_rewarded_ad_available()
	watch_ad_button.disabled = ad_on_cooldown or not ad_ok
	if GameState.no_ads:
		watch_ad_button.text = tr("Ativo (sem anúncios)")
	elif not ad_ok:
		watch_ad_button.text = tr("Indisponível")
	elif ad_on_cooldown:
		watch_ad_button.text = tr("Aguarde…")
	else:
		watch_ad_button.text = tr("Assistir")


# ---------------- Renda offline ----------------

func _show_offline_modal(seconds_away: float, coins_earned: float) -> void:
	_pending_offline_coins = coins_earned
	_offline_doubled = false
	var h := int(seconds_away / 3600)
	var m := int((int(seconds_away) % 3600) / 60)
	offline_away_label.text = (
		tr("Sua chocolateria trabalhou sozinha por %dh %dmin") % [h, m] if h > 0
		else tr("Sua chocolateria trabalhou sozinha por %d minutos") % m
	)
	offline_earned_label.text = "🪙 %s" % _fmt(_pending_offline_coins)
	offline_double_button.visible = SDK.is_rewarded_ad_available()
	offline_double_button.disabled = false
	offline_double_button.text = tr("🎬 Assistir anúncio: dobrar")
	offline_modal.visible = true

func _on_offline_double() -> void:
	if _offline_doubled:
		return
	offline_double_button.disabled = true
	offline_double_button.text = tr("Carregando…")
	SDK.show_rewarded_ad("offline_double")

func _apply_offline_double() -> void:
	if _offline_doubled:
		return
	_offline_doubled = true
	_pending_offline_coins *= 2.0
	offline_earned_label.text = "🪙 %s" % _fmt(_pending_offline_coins)
	offline_double_button.disabled = true
	offline_double_button.text = tr("✓ Renda dobrada")

func _on_offline_collect() -> void:
	GameState.collect_offline_earnings(_pending_offline_coins)
	_pending_offline_coins = 0.0
	offline_modal.visible = false


# ---------------- Vitória (5 vitrines) + fogos de artifício ----------------

func _show_win_modal() -> void:
	win_modal.visible = true
	win_fireworks.restart()
	win_fireworks.emitting = true

func _on_restart() -> void:
	win_modal.visible = false
	GameState.hard_reset()


# ---------------- Pausa + menu ----------------

func _on_pause_pressed() -> void:
	SoundManager.play_sfx("click")
	get_tree().paused = true
	pause_modal.visible = true

func _on_resume_pressed() -> void:
	get_tree().paused = false
	pause_modal.visible = false

func _on_visit_store_pressed() -> void:
	SDK.open_store_page()

func _on_reset_progress_pressed() -> void:
	reset_confirm_dialog.popup_centered()

func _on_reset_confirmed() -> void:
	GameState.hard_reset()
	get_tree().paused = false
	pause_modal.visible = false

func _on_sound_toggled(pressed: bool) -> void:
	SoundManager.set_sound_enabled(pressed)
	GameState.save_game()


# ---------------- Conta (login com Apple/Google) ----------------
# Tudo passa pelo autoload SDK: ele sabe se o plugin de login existe, e
# quais botões fazem sentido em cada plataforma (a App Store exige o
# "Entrar com Apple" sempre que houver login do Google no iOS).

func _on_sign_in_apple_pressed() -> void:
	SDK.sign_in("apple")
	_refresh_account_ui()

func _on_sign_in_google_pressed() -> void:
	SDK.sign_in("google")
	_refresh_account_ui()

func _on_sign_out_pressed() -> void:
	SDK.sign_out()
	_refresh_account_ui()

func _on_delete_account_pressed() -> void:
	delete_account_confirm_dialog.popup_centered()

func _on_delete_account_confirmed() -> void:
	SDK.delete_account()
	_refresh_account_ui()

func _refresh_account_ui() -> void:
	var signed_in := SDK.is_signed_in()
	var methods := SDK.available_sign_in_methods()

	sign_in_apple_button.visible = not signed_in and methods.has("apple")
	sign_in_google_button.visible = not signed_in and methods.has("google")
	sign_out_button.visible = signed_in
	delete_account_button.visible = signed_in

	if signed_in:
		# "name" seria sombra da propriedade Node.name — daí "who".
		var who := SDK.display_name()
		account_status_label.text = (
			tr("Conectado como %s") % who if who != "" else tr("Conta conectada")
		)
	elif not SDK.has_auth():
		account_status_label.text = tr("Jogando como convidado")
	else:
		account_status_label.text = tr("Entre para salvar seu progresso na nuvem")


# ---------------- Idioma ----------------

# Português e espanhol no topo — são os dois primeiros mercados.
# "Automático" segue o idioma do aparelho.
const LANGUAGES := [
	["", "🌐 Automático"],
	["pt_BR", "Português (BR)"],
	["es", "Español"],
	["en", "English"],
	["fr", "Français"],
	["de", "Deutsch"],
	["it", "Italiano"],
	["nl", "Nederlands"],
]

func _setup_language_button() -> void:
	language_button.clear()
	var current_index := 0
	for i in range(LANGUAGES.size()):
		var entry: Array = LANGUAGES[i]
		language_button.add_item(entry[1])
		if entry[0] == GameState.locale:
			current_index = i
	language_button.selected = current_index
	language_button.item_selected.connect(_on_language_selected)

func _on_language_selected(index: int) -> void:
	var code: String = LANGUAGES[index][0]
	GameState.locale = code
	GameState.apply_locale()
	GameState.save_game()
	# Os textos escritos pelo script (custo de upgrade, status da conta,
	# estado do forno) não são retraduzidos sozinhos como os que vêm da
	# cena — precisam ser redesenhados na troca de idioma.
	_refresh_shop()
	_refresh_shop_dynamic_labels()
	_refresh_account_ui()
	_refresh_oven_and_heat()
	_setup_screen_mode_button()


# ---------------- Modo de tela ----------------

const SCREEN_MODES := [
	["auto", "🔄 Automático"],
	["mobile", "📱 Celular"],
	["desktop", "🖥️ Desktop"],
]

func _setup_screen_mode_button() -> void:
	var ja_conectado := screen_mode_button.item_selected.is_connected(_on_screen_mode_selected)
	screen_mode_button.clear()
	var atual := 0
	for i in range(SCREEN_MODES.size()):
		screen_mode_button.add_item(tr(SCREEN_MODES[i][1]))
		if SCREEN_MODES[i][0] == GameState.display_mode:
			atual = i
	screen_mode_button.selected = atual
	if not ja_conectado:
		screen_mode_button.item_selected.connect(_on_screen_mode_selected)

func _on_screen_mode_selected(index: int) -> void:
	GameState.display_mode = SCREEN_MODES[index][0]
	GameState.save_game()
	# O SDK cuida da escala da interface, do filtro de textura e do tamanho
	# da janela; aqui só recalculamos as margens de área segura, que mudam
	# junto com a escala.
	SDK.apply_display_mode()
	_apply_safe_area()


# ---------------- Estopa: piadas e reações de humor ----------------

## Cada fusão conta como "ação recente" (pra medir se o jogador está indo
## rápido) e reseta o relógio de inatividade. Guarda só os últimos 15s de
## timestamps — o resto é descartado a cada chamada.
func _on_item_merged_for_estopa(_cell_index: int, _tag: String) -> void:
	var now := Time.get_ticks_msec()
	_estopa_merge_times.append(now)
	_estopa_merge_times = _estopa_merge_times.filter(func(t): return now - t < 15000)
	_estopa_last_action_ms = now

## Escolhe a fala de acordo com o ritmo do jogador: parado há mais de 20s
## → zoeira; 4+ fusões nos últimos 15s → elogio; senão → piada aleatória.
func _estopa_speak() -> void:
	var now := Time.get_ticks_msec()
	var idle_ms := now - _estopa_last_action_ms
	var line: String
	var pose: Texture2D

	if idle_ms > 20000:
		line = ESTOPA_JOKES_SLOW[randi() % ESTOPA_JOKES_SLOW.size()]
		pose = load("res://assets/mascot/estopa_esperando.png")
	elif _estopa_merge_times.size() >= 4:
		line = ESTOPA_JOKES_FAST[randi() % ESTOPA_JOKES_FAST.size()]
		pose = load("res://assets/mascot/estopa_feliz.png")
	else:
		line = ESTOPA_JOKES_GENERAL[randi() % ESTOPA_JOKES_GENERAL.size()]
		pose = load("res://assets/mascot/estopa_neutro.png")

	estopa_label.text = line
	estopa_img.texture = pose


# ---------------- "Suco": moeda voando, tremor e flash ----------------

## Cria um "🪙" que voa do centro do tabuleiro até o contador de moedas no
## cabeçalho, com um arco leve e sumindo no final. Usa posição GLOBAL (não
## a do layout) porque atravessa vários containers diferentes — por isso
## mora na FxLayer, que fica por cima de tudo, sem ser cortada por nenhum
## painel no meio do caminho.
func _fly_coin() -> void:
	var coin := Label.new()
	coin.text = "🪙"
	coin.add_theme_font_size_override("font_size", 20)
	coin.z_index = 100
	fx_layer.add_child(coin)

	var start := board_panel.get_global_rect().get_center()
	var end := coin_label.get_global_rect().get_center()
	coin.global_position = start

	var mid := start.lerp(end, 0.5) + Vector2(0, -60)  # sobe um pouco no meio do caminho, cai suave no fim

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(t: float):
		var p := start.bezier_interpolate(mid, mid, end, t)
		coin.global_position = p
	, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(coin, "scale", Vector2(0.6, 0.6), 0.55).set_delay(0.15)
	tw.chain().tween_callback(coin.queue_free)

## Pulso rápido de zoom no contador de moedas + flash dourado na tela
## inteira, disparado quando uma vitrine fecha (é o momento mais
## importante de progresso do jogo, merece o efeito mais forte).
func _screen_pop() -> void:
	var tw := create_tween()
	tw.tween_property(coin_label, "scale", Vector2(1.4, 1.4), 0.1)
	tw.tween_property(coin_label, "scale", Vector2.ONE, 0.2)

	flash_rect.modulate.a = 1.0
	flash_rect.color.a = 0.35
	var flash_tw := create_tween()
	flash_tw.tween_property(flash_rect, "color:a", 0.0, 0.35)

	# tremor leve: desloca o root da UI em ziguezague por alguns frames e
	# volta pro lugar — dá peso ao momento sem precisar de Camera2D/shader.
	var shake_tw := create_tween()
	var original_pos := position
	for i in range(5):
		var offset := Vector2(randf_range(-4, 4), randf_range(-4, 4))
		shake_tw.tween_property(self, "position", original_pos + offset, 0.03)
	shake_tw.tween_property(self, "position", original_pos, 0.03)
