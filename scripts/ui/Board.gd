extends GridContainer
## Anexar a um GridContainer, columns = 5. Monta as 25 células por código.
## Só lê GameState e desenha — nenhuma regra de jogo mora aqui.

# 70x70 cabe 5 colunas na largura da tela (420px viewport, menos margens)
# com folga. Se aumentar, checar 5*CELL_SIZE + 4*separação < largura útil.
const CELL_SIZE := Vector2(70, 70)

var _cell_buttons: Array[TextureButton] = []
var _level_labels: Array[Label] = []
var _brand_labels: Array[Label] = []

func _ready() -> void:
	columns = 5
	for i in range(GameState.BOARD_SIZE):
		var btn := TextureButton.new()
		btn.custom_minimum_size = CELL_SIZE
		btn.ignore_texture_size = true   # sem isso, herda o tamanho nativo do PNG e estoura o layout
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		# Sem pivô no centro, a animação de "pop" da fusão cresce a partir do
		# canto superior esquerdo e a peça parece escorregar pro lado.
		btn.pivot_offset = CELL_SIZE / 2.0
		btn.pressed.connect(_on_cell_pressed.bind(i))

		var level_label := Label.new()
		level_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		level_label.add_theme_font_size_override("font_size", 12)
		btn.add_child(level_label)

		var brand_label := Label.new()
		brand_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		brand_label.add_theme_font_size_override("font_size", 9)
		brand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		brand_label.visible = false
		btn.add_child(brand_label)

		add_child(btn)
		_cell_buttons.append(btn)
		_level_labels.append(level_label)
		_brand_labels.append(brand_label)

	GameState.board_changed.connect(_refresh)
	GameState.item_merged.connect(_on_item_merged)
	GameState.item_shipped.connect(_on_item_shipped)
	GameState.golden_collected.connect(_on_golden_collected)
	_refresh()


func _on_cell_pressed(idx: int) -> void:
	SoundManager.play_sfx("click")
	SDK.haptic(12)
	GameState.on_cell_tapped(idx)


func _refresh() -> void:
	for i in range(GameState.BOARD_SIZE):
		var cell = GameState.board[i]
		var btn := _cell_buttons[i]
		var level_label := _level_labels[i]
		var brand_label := _brand_labels[i]

		# "is Dictionary" antes de comparar com "golden": Dictionary == String
		# quebra em runtime se comparado direto sem checar o tipo primeiro.
		if cell is Dictionary:
			var level: int = cell["level"]
			btn.texture_normal = ItemData.get_item_texture(level)
			level_label.text = tr("Nv%d") % level
			var brand := ItemData.get_brand_label(level)
			brand_label.text = brand
			brand_label.visible = brand != ""
		elif cell is String and cell == "golden":
			btn.texture_normal = ItemData.get_cached_texture("res://assets/golden/caixa_dourada.png")
			level_label.text = ""
			brand_label.visible = false
		else:
			btn.texture_normal = null
			level_label.text = ""
			brand_label.visible = false

		btn.modulate = Color(1.3, 1.15, 0.7) if i == GameState.selected_index else Color.WHITE


func _on_item_merged(cell_index: int, tag: String) -> void:
	var btn := _cell_buttons[cell_index]
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(1.25, 1.25), 0.1)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.15)

	if tag == "jump":
		_flash_effect(cell_index, "res://assets/effects/efeito_lote.png")
	elif tag == "bonus":
		_flash_effect(cell_index, "res://assets/effects/efeito_fornada.png")
	else:
		_flash_effect(cell_index, "res://assets/effects/efeito_normal.png")

	_particle_burst(cell_index)


## Estoura uns quadradinhos coloridos saindo do centro da célula, cada um
## numa direção aleatória, encolhendo e sumindo — dá o "pop" de partícula
## sem precisar de CPUParticles2D (que é baseado em Node2D, e misturar
## isso dentro da árvore de Control complica mais do que ajuda aqui).
func _particle_burst(cell_index: int) -> void:
	var btn := _cell_buttons[cell_index]
	var colors := [Color(0.93, 0.6, 0.25), Color(0.98, 0.78, 0.4), Color(0.55, 0.32, 0.12)]
	for i in range(7):
		var p := ColorRect.new()
		p.color = colors[i % colors.size()]
		p.size = Vector2(6, 6)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.set_anchors_preset(Control.PRESET_CENTER)
		p.position -= p.size / 2.0
		btn.add_child(p)

		var angle := (TAU / 7.0) * i + randf_range(-0.2, 0.2)
		var dist := randf_range(22.0, 34.0)
		var target := Vector2(cos(angle), sin(angle)) * dist

		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "position", p.position + target, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "scale", Vector2.ZERO, 0.45).set_delay(0.1)
		tw.tween_property(p, "modulate:a", 0.0, 0.45).set_delay(0.15)
		tw.chain().tween_callback(p.queue_free)


func _on_item_shipped(_cell_index: int, _bonus: float) -> void:
	pass  # gancho pra efeito visual futuro (ex: animação de caminhão)


func _on_golden_collected(_cell_index: int) -> void:
	pass  # gancho pra efeito visual futuro


func _flash_effect(cell_index: int, texture_path: String) -> void:
	var fx := TextureRect.new()
	fx.texture = ItemData.get_cached_texture(texture_path)
	fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fx.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sem pivô central, o scale de 0.3 -> 1.4 cresce a partir do canto
	# superior esquerdo: o brilho da fusão nascia deslocado pra fora da
	# peça em vez de estourar em cima dela.
	fx.pivot_offset = CELL_SIZE / 2.0
	_cell_buttons[cell_index].add_child(fx)

	var tw := create_tween()
	tw.tween_property(fx, "scale", Vector2(1.4, 1.4), 0.7).from(Vector2(0.3, 0.3))
	tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.7).from(1.0)
	tw.tween_callback(fx.queue_free)
