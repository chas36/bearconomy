# caravan_paper.gd — бумага «Ямской двор»: снаряжение обозов из узла
# Код перенесён из city_panel.gd; выбор товара/количества теперь свой.
extends VBoxContainer

signal action_performed(message: String)

const Goods := preload("res://sim/goods.gd")
const UiTheme := preload("res://ui/ui_theme.gd")
const GameText := preload("res://ui/game_text.gd")

const MODE_BUY_AND_SEND := 0
const MODE_SEND_FROM_STOCK := 1

var gameplay
var node_index := 0

var _good_select: OptionButton
var _qty_spin: SpinBox
var _destination_select: OptionButton
var _destination_indices: Array[int] = []
var _mode_select: OptionButton
var _sell_on_arrival: CheckBox
var _travel_label: Label


func _init() -> void:
	add_theme_constant_override("separation", 8)


func setup(gameplay_ref) -> void:
	gameplay = gameplay_ref
	_build()
	refresh()


func set_node_index(index: int) -> void:
	node_index = clampi(index, 0, gameplay.economy.nodes.size() - 1)
	_rebuild_destinations()
	refresh()


func refresh() -> void:
	_update_travel_label()
	_update_dispatch_modes()


func _build() -> void:
	_add_subheader("Груз")
	var goods_row := HBoxContainer.new()
	goods_row.add_theme_constant_override("separation", 6)
	add_child(goods_row)

	_good_select = OptionButton.new()
	for g in Goods.Good.values():
		_good_select.add_icon_item(UiTheme.good_dot(g), Goods.NAMES[g])
	_good_select.select(0)
	_good_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goods_row.add_child(_good_select)

	_qty_spin = SpinBox.new()
	_qty_spin.min_value = 1.0
	_qty_spin.max_value = 200.0
	_qty_spin.value = 5.0
	_qty_spin.custom_minimum_size.x = 80
	goods_row.add_child(_qty_spin)

	_add_subheader("Куда")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	var to_label := Label.new()
	to_label.text = "В"
	to_label.theme_type_variation = "DimLabel"
	row.add_child(to_label)

	_destination_select = OptionButton.new()
	_destination_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_destination_select.item_selected.connect(func(_i: int) -> void: refresh())
	row.add_child(_destination_select)

	_travel_label = Label.new()
	_travel_label.theme_type_variation = "SmallDimLabel"
	row.add_child(_travel_label)

	_mode_select = OptionButton.new()
	_mode_select.add_item("Выкупить на рынке и отправить", MODE_BUY_AND_SEND)
	_mode_select.add_item("Отправить со склада узла", MODE_SEND_FROM_STOCK)
	_mode_select.select(MODE_BUY_AND_SEND)
	_mode_select.tooltip_text = "Со склада можно отправлять там, где у дома есть свой завод"
	add_child(_mode_select)

	_sell_on_arrival = CheckBox.new()
	_sell_on_arrival.text = "Продать по прибытии"
	add_child(_sell_on_arrival)

	var send_button := Button.new()
	send_button.text = "Снарядить обоз"
	send_button.theme_type_variation = "AccentButton"
	send_button.pressed.connect(_on_send_caravan)
	add_child(send_button)

	_rebuild_destinations()


func _add_subheader(text: String) -> void:
	var separator := HSeparator.new()
	add_child(separator)
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "SubHeaderLabel"
	add_child(label)


func _rebuild_destinations() -> void:
	_destination_select.clear()
	_destination_indices.clear()
	for i in range(gameplay.economy.nodes.size()):
		if i == node_index:
			continue
		_destination_select.add_item(gameplay.economy.nodes[i].name)
		_destination_indices.append(i)
	if _destination_select.item_count > 0:
		_destination_select.select(0)


func _update_travel_label() -> void:
	if _destination_indices.is_empty() or _destination_select.selected < 0:
		_travel_label.text = ""
		return
	var destination = gameplay.economy.nodes[_destination_indices[_destination_select.selected]]
	_travel_label.text = GameText.weeks(GameText.route_ticks(_node().name, destination.name))


# v0-заглушка: у симуляции нет личных складов, запас узла общий.
# Guard «нужен свой завод в узле» лишь прикрывает бесплатный вывоз рынка;
# честное решение — инвентарь агента в /sim (см. docs/roadmap-history.md).
func _player_has_works_here() -> bool:
	var node = _node()
	for enterprise in gameplay.economy.player.enterprises:
		if enterprise.node == node:
			return true
	return false


func _update_dispatch_modes() -> void:
	var has_works := _player_has_works_here()
	_mode_select.set_item_disabled(MODE_SEND_FROM_STOCK, not has_works)
	if not has_works and _mode_select.selected == MODE_SEND_FROM_STOCK:
		_mode_select.select(MODE_BUY_AND_SEND)


func _node():
	return gameplay.economy.nodes[node_index]


func _selected_good() -> int:
	return Goods.Good.values()[max(_good_select.selected, 0)]


func _on_send_caravan() -> void:
	if _destination_indices.is_empty() or _destination_select.selected < 0:
		return
	var economy = gameplay.economy
	var origin = _node()
	var destination = economy.nodes[_destination_indices[_destination_select.selected]]
	var good := _selected_good()
	var ticks := GameText.route_ticks(origin.name, destination.name)
	var sell: bool = _sell_on_arrival.button_pressed
	var qty := 0.0
	if _mode_select.selected == MODE_SEND_FROM_STOCK:
		if not _player_has_works_here():
			action_performed.emit("Со склада слать нельзя: в %s нет завода дома." % origin.name)
			return
		qty = economy.dispatch(
			economy.player, origin, destination, good, float(_qty_spin.value), ticks, sell
		)
	else:
		qty = economy.buy_and_dispatch(
			economy.player, origin, destination, good, float(_qty_spin.value), ticks, sell
		)
	if qty <= 0.05:
		action_performed.emit("Обоз не вышел: нет товара или денег.")
	else:
		action_performed.emit(
			(
				"Обоз в %s: %.1f %s, в пути %s."
				% [destination.name, qty, Goods.NAMES[good], GameText.weeks(ticks)]
			)
		)
