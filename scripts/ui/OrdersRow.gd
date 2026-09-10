extends HBoxContainer
## Anexar a um HBoxContainer (dentro de ScrollContainer pra rolagem horizontal).
## Só lê GameState.orders e desenha — regras de pedido moram no GameState.

func _ready() -> void:
	GameState.orders_changed.connect(_refresh)
	GameState.board_changed.connect(_refresh) # habilita/desabilita "Entregar" quando o tabuleiro muda
	_refresh()


func _refresh() -> void:
	for child in get_children():
		child.queue_free()
	for order in GameState.orders:
		add_child(_build_order_card(order))


func _build_order_card(order: Dictionary) -> Control:
	var level: int = order["level"]
	var has_item := false
	for cell in GameState.board:
		if cell is Dictionary and cell["level"] == level:
			has_item = true
			break

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(96, 108)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var icon := TextureRect.new()
	icon.texture = ItemData.get_item_texture(level)
	icon.custom_minimum_size = Vector2(42, 42)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(icon)

	var reward_label := Label.new()
	reward_label.text = "+%d 🪙" % order["reward"]
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(reward_label)

	var deliver_btn := Button.new()
	deliver_btn.text = tr("Entregar")
	deliver_btn.disabled = not has_item
	deliver_btn.pressed.connect(func():
		if GameState.try_fulfill_order(order["id"]):
			SoundManager.play_sfx("deliver")
	)
	vbox.add_child(deliver_btn)

	return panel
