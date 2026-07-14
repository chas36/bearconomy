# contracts_panel.gd — вкладка «Заказы»: приказная доска и взятые подряды
extends VBoxContainer

signal action_performed(message: String)

const Goods := preload("res://sim/goods.gd")
const UiTheme := preload("res://ui/ui_theme.gd")
const GameText := preload("res://ui/game_text.gd")

var gameplay

var _open_box: VBoxContainer
var _active_box: VBoxContainer
var _completed_label: Label


func _init() -> void:
	add_theme_constant_override("separation", 8)


func setup(gameplay_ref) -> void:
	gameplay = gameplay_ref
	_build()
	refresh()


func open_count() -> int:
	return gameplay.open_contracts().size()


func refresh() -> void:
	_fill_open_contracts()
	_fill_active_contracts()
	var completed: int = gameplay.board.completed_count.get(gameplay.economy.player.id, 0)
	_completed_label.text = "Исполнено подрядов: %d" % completed


func _build() -> void:
	_add_subheader("Приказная доска")
	_open_box = VBoxContainer.new()
	_open_box.add_theme_constant_override("separation", 6)
	add_child(_open_box)

	_add_subheader("Взятые подряды")
	_active_box = VBoxContainer.new()
	_active_box.add_theme_constant_override("separation", 6)
	add_child(_active_box)

	var separator := HSeparator.new()
	add_child(separator)

	_completed_label = Label.new()
	_completed_label.theme_type_variation = "DimLabel"
	add_child(_completed_label)


func _add_subheader(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "SubHeaderLabel"
	add_child(label)


func _fill_open_contracts() -> void:
	_clear_children(_open_box)

	var contracts: Array = gameplay.open_contracts()
	if contracts.is_empty():
		_open_box.add_child(_empty_label("Доска пуста — новые заказы появятся позже."))
		return

	for contract in contracts:
		var card := _card_base(contract)
		var body: VBoxContainer = card.get_child(0)

		var terms := Label.new()
		terms.text = (
			"Срок %s · штраф %s · казна +%.0f"
			% [
				GameText.weeks(_ticks_left(contract)),
				GameText.money(contract["penalty"]),
				contract["relations_bonus"],
			]
		)
		terms.theme_type_variation = "SmallDimLabel"
		terms.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(terms)

		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 6)
		body.add_child(buttons)

		var accept := Button.new()
		accept.text = "Взять подряд"
		accept.theme_type_variation = "AccentButton"
		accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		accept.pressed.connect(_on_accept.bind(contract["id"]))
		buttons.add_child(accept)

		var decline := Button.new()
		decline.text = "Отказ"
		decline.pressed.connect(_on_decline.bind(contract["id"]))
		buttons.add_child(decline)

		_open_box.add_child(card)


func _fill_active_contracts() -> void:
	_clear_children(_active_box)

	var contracts: Array = gameplay.player_contracts()
	if contracts.is_empty():
		_active_box.add_child(_empty_label("Дом свободен от обязательств."))
		return

	for contract in contracts:
		var card := _card_base(contract)
		var body: VBoxContainer = card.get_child(0)

		var delivered: float = gameplay.board.progress(contract, gameplay.economy)
		var bar := ProgressBar.new()
		bar.max_value = contract["qty"]
		bar.value = delivered
		bar.show_percentage = false
		bar.custom_minimum_size.y = 8
		body.add_child(bar)

		var status := Label.new()
		status.text = (
			"Продано %.1f из %.1f · осталось %s"
			% [delivered, contract["qty"], GameText.weeks(_ticks_left(contract))]
		)
		status.theme_type_variation = "SmallDimLabel"
		body.add_child(status)

		_active_box.add_child(card)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			child.visible = false
		child.queue_free()


func _card_base(contract: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	card.add_child(body)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	body.add_child(head)

	var icon := TextureRect.new()
	icon.texture = UiTheme.good_icon(contract["good"])
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(icon)

	var destination = gameplay.economy.nodes[contract["destination_index"]]
	var title := Label.new()
	title.text = "%.1f %s в %s" % [contract["qty"], Goods.NAMES[contract["good"]], destination.name]
	title.theme_type_variation = "HeaderLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(title)

	var reward := Label.new()
	reward.text = "+%s" % GameText.money(contract["reward"])
	reward.theme_type_variation = "ValueLabel"
	head.add_child(reward)

	return card


func _empty_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "DimLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _ticks_left(contract: Dictionary) -> int:
	return max(0, contract["deadline_tick"] - gameplay.economy.tick_count)


func _on_accept(contract_id: int) -> void:
	if gameplay.accept_contract(contract_id):
		action_performed.emit("Подряд №%d взят." % contract_id)
	else:
		action_performed.emit("Подряд уже недоступен.")


func _on_decline(contract_id: int) -> void:
	if gameplay.decline_contract(contract_id):
		action_performed.emit("Подряд №%d снят с доски." % contract_id)
	else:
		action_performed.emit("Подряд уже недоступен.")
