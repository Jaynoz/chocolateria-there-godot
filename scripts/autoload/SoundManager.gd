extends Node
## Autoload "SoundManager" — trilha sonora e efeitos. Registrar depois de
## GameState (depende de GameState.sound_enabled e dos sinais de jogo).
##
## Carrega os arquivos com segurança: se um .wav não existir (pasta vazia,
## asset ainda não trocado por uma faixa definitiva), o jogo continua
## rodando normal, só sem aquele som específico — nunca trava por causa
## de áudio faltando.

const MUSIC_PATH := "res://assets/audio/music/theme.wav"

const SFX_PATHS := {
	"click": "res://assets/audio/sfx/click.wav",
	"coin": "res://assets/audio/sfx/coin.wav",
	"merge": "res://assets/audio/sfx/merge.wav",
	"merge_bonus": "res://assets/audio/sfx/merge_bonus.wav",
	"golden": "res://assets/audio/sfx/golden.wav",
	"deliver": "res://assets/audio/sfx/deliver.wav",
	"vitrine_complete": "res://assets/audio/sfx/vitrine_complete.wav",
	"win": "res://assets/audio/sfx/win.wav",
}

const SFX_POOL_SIZE := 6   # tocadores simultâneos disponíveis pra efeitos que se sobrepõem (ex: fusões em sequência rápida)

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {}
var _next_sfx_player := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # continua tocando som mesmo com get_tree().paused (menu de pausa)

	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	_music_player.volume_db = -9.0
	_load_music()

	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)

	for key in SFX_PATHS:
		if ResourceLoader.exists(SFX_PATHS[key]):
			_sfx_cache[key] = load(SFX_PATHS[key])

	GameState.item_merged.connect(_on_item_merged)
	GameState.golden_collected.connect(func(_idx): play_sfx("golden"))
	GameState.item_shipped.connect(func(_idx, _bonus): play_sfx("coin"))
	GameState.vitrine_completed.connect(func(_i): play_sfx("vitrine_complete"))
	GameState.game_won.connect(func(): play_sfx("win"))

	set_sound_enabled(GameState.sound_enabled)


func _load_music() -> void:
	if not ResourceLoader.exists(MUSIC_PATH):
		return
	var stream = load(MUSIC_PATH)
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD   # o .wav já foi gerado com início/fim que se conectam sem clique
	_music_player.stream = stream


func _on_item_merged(_cell_index: int, tag: String) -> void:
	if tag == "jump" or tag == "bonus":
		play_sfx("merge_bonus")
	else:
		play_sfx("merge")


## Toca um efeito pelo nome (chaves de SFX_PATHS). Usa um pool de
## AudioStreamPlayers em rodízio — permite tocar o mesmo som várias vezes
## em sequência rápida (ex: várias fusões seguidas) sem cortar a anterior.
func play_sfx(key: String) -> void:
	if not GameState.sound_enabled:
		return
	if not _sfx_cache.has(key):
		return
	var player := _sfx_players[_next_sfx_player]
	_next_sfx_player = (_next_sfx_player + 1) % _sfx_players.size()
	player.stream = _sfx_cache[key]
	player.play()


func play_music() -> void:
	if _music_player.stream and GameState.sound_enabled:
		_music_player.play()

func stop_music() -> void:
	_music_player.stop()

## Chamado pelo toggle de som do menu de pausa (Main.gd). Controla música
## e efeitos com a mesma flag — GameState.sound_enabled já é salvo junto
## do resto do progresso, então a preferência persiste entre sessões.
func set_sound_enabled(enabled: bool) -> void:
	GameState.sound_enabled = enabled
	if enabled:
		play_music()
	else:
		stop_music()
