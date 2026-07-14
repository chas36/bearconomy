# market_paper.gd — бумага «Торговые ряды»: рынок узла, торг
# Код перенесён из city_panel.gd; узел задаётся снаружи (set_node_index).
extends VBoxContainer

signal action_performed(message: String)

const Goods := preload("res://sim/goods.gd")
const Labor := preload("res://sim/labor.gd")
const UiTheme := preload("res://ui/ui_theme.gd")
const GameText := preload("res://ui/game_text.gd")

var gameplay
var node_index := 0

var _labor_label: Label
var _market_rows := {}  # Good -> {stock, price, trend}
var _good_select: OptionButton
var _qty_spin: SpinBox
var _trade_preview: Label


func _init() -> void:
	add_theme_constant_override("separation", 8)


func setup(gameplay_ref) -> void:
	gameplay = gameplay_ref
	_build()
	refresh()


func set_node_index(index: int) -> void:
	node_index = clampi(index, 0, gameplay.economy.nodes.size() - 1)
	refresh()


func refresh() -> void:
	var node = _node()
	_labor_label.text = "Наёмных на рынке: %d" % node.labor_pool[Labor.Type.HIRED]

	for g in Goods.Good.values():
		var row: Dictionary = _market_rows[g]
		row["stock"].text = "%.1f" % node.stock[g]
		row["price"].text = "%.2f" % node.price(g)
		row["trend"].texture = UiTheme.trend_texture(_trend_direction(node, g))

	_update_trade_preview()


func _build() -> void:
	_labor_label = Label.new()
	_labor_label.theme_type_variation = "DimLabel"
	add_child(_labor_label)

	_build_market_grid()
	_build_trade_box()


func _build_market_grid() -> void:
	_add_subheader("Рынок")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 3)
	add_child(grid)

	for caption in ["Товар", "Запас", "Цена", ""]:
		var header := Label.new()
		header.text = caption
		header.theme_type_variation = "SmallDimLabel"
		grid.add_child(header)

	for g in Goods.Good.values():
		var name_box := HBoxContainer.new()
		name_box.add_theme_constant_override("separation", 6)
		var icon := TextureRect.new()
		icon.texture = UiTheme.good_dot(g)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		name_box.add_child(icon)
		var name_label := Label.new()
		name_label.text = Goods.NAMES[g]
		name_box.add_child(name_label)
		grid.add_child(name_box)

		var stock := Label.new()
		stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stock.custom_minimum_size.x = 52
		grid.add_child(stock)

		var price := Label.new()
		price.theme_type_variation = "ValueLabel"
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price.custom_minimum_size.x = 56
		grid.add_child(price)

		var trend := TextureRect.new()
		trend.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		trend.tooltip_text = "Куда идёт цена: дефицит поднимает, избыток роняет"
		grid.add_child(trend)

		_market_rows[g] = {"stock": stock, "price": price, "trend": trend}


func _build_trade_box() -> void:
	_add_subheader("Торг")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	_good_select = OptionButton.new()
	for g in Goods.Good.values():
		_good_select.add_icon_item(UiTheme.good_dot(g), Goods.NAMES[g])
	_good_select.select(0)
	_good_select.item_selected.connect(func(_i: int) -> void: refresh())
	_good_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_good_select)

	_qty_spin = SpinBox.new()
	_qty_spin.min_value = 1.0
	_qty_spin.max_value = 200.0
	_qty_spin.value = 5.0
	_qty_spin.custom_minimum_size.x = 80
	_qty_spin.value_changed.connect(func(_v: float) -> void: refresh())
	row.add_child(_qty_spin)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	add_child(actions)

	var buy_button := Button.new()
	buy_button.text = "Купить"
	buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_button.pressed.connect(_on_buy)
	actions.add_child(buy_button)

	var sell_button := Button.new()
	sell_button.text = "Продать"
	sell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_button.pressed.connect(_on_sell)
	actions.add_child(sell_button)

	_trade_preview = Label.new()
	_trade_preview.theme_type_variation = "SmallDimLabel"
	add_child(_trade_preview)


func _add_subheader(text: String) -> void:
	var separator := HSeparator.new()
	add_child(separator)
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "SubHeaderLabel"
	add_child(label)


func _update_trade_preview() -> void:
	var node = _node()
	var good := _selected_good()
	var total: float = node.price(good) * _qty_spin.value
	_trade_preview.text = "По нынешней цене выйдет около %s" % GameText.money(total)


func _trend_direction(node, good: int) -> int:
	var current: float = node.price(good)
	var target: float = node.target_price(good)
	if target > current * 1.02:
		return 1
	if target < current * 0.98:
		return -1
	return 0


func _node():
	return gameplay.economy.nodes[node_index]


func _selected_good() -> int:
	return Goods.Good.values()[max(_good_select.selected, 0)]


func _on_buy() -> void:
	var economy = gameplay.economy
	var good := _selected_good()
	var qty: float = economy.buy(economy.player, _node(), good, float(_qty_spin.value))
	action_performed.emit("Куплено %.1f %s в %s." % [qty, Goods.NAMES[good], _node().name])


func _on_sell() -> void:
	var economy = gameplay.economy
	var good := _selected_good()
	economy.sell(economy.player, _node(), good, float(_qty_spin.value))
	action_performed.emit(
		"Продано %.1f %s в %s." % [_qty_spin.value, Goods.NAMES[good], _node().name]
	)
