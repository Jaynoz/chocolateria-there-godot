extends HBoxContainer
## Anexar a um HBoxContainer. Monta as 5 miniaturas da Vitrine do
## Supermercado e anima a revelação (P&B → colorido) via reveal.gdshader.

const THUMB_SIZE := Vector2(58, 58)
const REVEAL_SHADER := preload("res://assets/shaders/reveal.gdshader")
## Asset dedicado: a gôndola já vem dentro da moldura redonda, então não
## dá pra confundir com o ícone do item nem trocar por outra imagem sem
## querer. É a gôndola do supermercado — nunca a flor da marca, que é
## exclusiva do cabeçalho, ao lado do nome do jogo.
const VITRINE_TEXTURE := "res://assets/vitrine/vitrine_gondola.png"

## Duração da passagem de preto e branco para colorido. A versão web já
## animava isso (transition de 0.4s no clip-path); aqui o valor do shader
## era trocado de uma vez e a cor aparecia num piscar — o momento mais
## comemorativo do jogo passava despercebido.
const REVEAL_TIME := 0.45

var _thumbs: Array[TextureRect] = []
var _materials: Array[ShaderMaterial] = []
var _tweens: Array[Tween] = []

func _ready() -> void:
	for i in range(GameState.VITRINE_GOAL):
		var thumb := TextureRect.new()
		thumb.texture = ItemData.get_cached_texture(VITRINE_TEXTURE)
		thumb.custom_minimum_size = THUMB_SIZE
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		# Cada miniatura precisa do próprio ShaderMaterial — compartilhar a
		# mesma instância faria o "progress" de uma afetar todas.
		var mat := ShaderMaterial.new()
		mat.shader = REVEAL_SHADER
		mat.set_shader_parameter("progress", 0.0)
		thumb.material = mat

		add_child(thumb)
		_thumbs.append(thumb)
		_materials.append(mat)
		_tweens.append(null)

	GameState.vitrine_progress_changed.connect(_refresh)
	GameState.vitrine_completed.connect(_on_vitrine_completed)
	# Na abertura o progresso já salvo aparece pronto, sem animar 5 vitrines
	# de uma vez na cara do jogador.
	_refresh(false)


func _refresh(animar: bool = true) -> void:
	for i in range(GameState.VITRINE_GOAL):
		var alvo := 0.0
		if i < GameState.vitrines_completed:
			alvo = 1.0
		elif i == GameState.vitrines_completed:
			alvo = float(GameState.super_count) / float(GameState.SUPER_TARGET)
		_set_progress(i, alvo, animar)


func _set_progress(i: int, alvo: float, animar: bool) -> void:
	var atual: float = _materials[i].get_shader_parameter("progress")
	if is_equal_approx(atual, alvo):
		return

	# Um tween por miniatura, sempre substituindo o anterior: sem isso, duas
	# atualizações seguidas deixariam dois tweens disputando o mesmo valor.
	if _tweens[i] != null and _tweens[i].is_valid():
		_tweens[i].kill()

	if not animar or alvo < atual:
		# Voltar pra trás (prestígio, reinício) é imediato — animar uma
		# barra "descolorindo" só confunde.
		_materials[i].set_shader_parameter("progress", alvo)
		return

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(
		func(v: float) -> void: _materials[i].set_shader_parameter("progress", v),
		atual, alvo, REVEAL_TIME
	)
	_tweens[i] = tw


func _on_vitrine_completed(vitrine_index: int) -> void:
	var i := vitrine_index - 1   # sinal é 1-indexado, array é 0-indexado
	if i < 0 or i >= _thumbs.size():
		return
	var thumb := _thumbs[i]
	thumb.pivot_offset = thumb.size / 2.0   # o "pop" cresce do centro, não do canto
	var tw := create_tween()
	tw.tween_property(thumb, "scale", Vector2(1.15, 1.15), 0.15)
	tw.tween_property(thumb, "scale", Vector2.ONE, 0.2)
