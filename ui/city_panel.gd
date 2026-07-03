# city_panel.gd — вкладка «Город»: рынок, торг, снаряжение обозов, стройка
extends VBoxContainer

signal node_selected(index: int)
signal action_performed(message: String)

const Goods := preload("res://sim/goods.gd")
const Labor := preload("res://sim/labor.gd")
const Recipes := preload("res://sim/recipes.gd")
const UiTheme := preload("res://ui/ui_theme.gd")
const GameText := preload("res://ui/game_text.gd")

const BUILD_RECIPE_IDS := ["rudnik", "domna", "kuznitsa", "melnitsa", "vinokurnya"]
const MODE_BUY_AND_SEND := 0
const MODE_SEND_FROM_STOCK := 1

var gameplay
var node_index := 0

var _node_select: OptionButton
var _labor_label: Label
var _market_rows := {}  # Good -> {stock, price, trend}
var _good_select: OptionButton
var _qty_spin: SpinBox
var _trade_preview: Label
var _destination_select: OptionButton
var _destination_indices: Array[int] = []
var _mode_select: OptionButton
var _sell_on_arrival: CheckBox
var _travel_label: Label
var _recipe_select: OptionButton
var _possessional_spin: SpinBox
var _build_preview: Label
var _enterprise_list: VBoxContainer


func _init() -> void:
	add_theme_constant_override("separation", 8)


func setup(gameplay_ref) -> void:
	gameplay = gameplay_ref
	_build()
	refresh()


func set_node_index(index: int) -> void:
	node_index = clampi(index, 0, gameplay.economy.nodes.size() - 1)
	_node_select.select(node_index)
	_rebuild_destinations()
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
	_update_travel_label()
	_update_dispatch_modes()
	_update_build_preview()
	_refresh_enterprise_list()


func _build() -> void:
	_node_select = OptionButton.new()
	for n in gameplay.economy.nodes:
		_node_select.add_item(n.name)
	_node_select.item_selected.connect(func(index: int) -> void: node_selected.emit(index))
	add_child(_node_select)

	_labor_label = Label.new()
	_labor_label.theme_type_variation = "DimLabel"
	add_child(_labor_label)

	_build_market_grid()
	_build_trade_box()
	_build_caravan_box()
	_build_construction_box()

	_add_subheader("Дворы и заводы")
	_enterprise_list = VBoxContainer.new()
	_enterprise_list.add_theme_constant_override("separation", 4)
	add_child(_enterprise_list)

	_rebuild_destinations()


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


func _build_caravan_box() -> void:
	_add_subheader("Обоз")
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


func _build_construction_box() -> void:
	_add_subheader("Стройка")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	_recipe_select = OptionButton.new()
	for recipe_id in BUILD_RECIPE_IDS:
		_recipe_select.add_item(Recipes.DEFS[recipe_id]["display_name"])
	_recipe_select.select(0)
	_recipe_select.item_selected.connect(func(_i: int) -> void: refresh())
	_recipe_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_recipe_select)

	_possessional_spin = SpinBox.new()
	_possessional_spin.min_value = 0
	_possessional_spin.max_value = Labor.POSSESSIONAL_MAX_PER_CAPACITY
	_possessional_spin.value = 2
	_possessional_spin.custom_minimum_size.x = 70
	_possessional_spin.tooltip_text = "Посессионные работники: покупаются вместе с заводом"
	_possessional_spin.value_changed.connect(func(_v: float) -> void: refresh())
	row.add_child(_possessional_spin)

	_build_preview = Label.new()
	_build_preview.theme_type_variation = "SmallDimLabel"
	add_child(_build_preview)

	var build_button := Button.new()
	build_button.text = "Заложить завод"
	build_button.theme_type_variation = "AccentButton"
	build_button.pressed.connect(_on_build)
	add_child(build_button)


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


func _refresh_enterprise_list() -> void:
	_clear_children(_enterprise_list)

	var node = _node()
	var found := false
	for agent in gameplay.economy.agents:
		for enterprise in agent.enterprises:
			if enterprise.node != node:
				continue
			found = true
			_enterprise_list.add_child(
				_enterprise_row(
					agent.is_player,
					(
						"%s — %s, мощность %.1f"
						% [enterprise.name, agent.display_name, enterprise.effective_capacity()]
					)
				)
			)
	for construction in gameplay.economy.construction_queue:
		if construction.node != node:
			continue
		found = true
		var owner = gameplay.economy.agent_by_id(construction.owner_id)
		var is_player: bool = owner != null and owner.is_player
		_enterprise_list.add_child(
			_enterprise_row(
				is_player,
				(
					"%s — стройка, ещё %s"
					% [construction.display_name, GameText.weeks(construction.remaining_ticks)]
				)
			)
		)
	if not found:
		var empty := Label.new()
		empty.text = "Пусто: ни дворов, ни строек."
		empty.theme_type_variation = "DimLabel"
		_enterprise_list.add_child(empty)


func _enterprise_row(is_player: bool, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var dot := TextureRect.new()
	dot.texture = UiTheme.owner_dot(is_player)
	dot.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(dot)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


func _update_trade_preview() -> void:
	var node = _node()
	var good := _selected_good()
	var total: float = node.price(good) * _qty_spin.value
	_trade_preview.text = "По нынешней цене выйдет около %s" % GameText.money(total)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			child.visible = false
		child.queue_free()


func _update_travel_label() -> void:
	if _destination_indices.is_empty() or _destination_select.selected < 0:
		_travel_label.text = ""
		return
	var destination = gameplay.economy.nodes[_destination_indices[_destination_select.selected]]
	_travel_label.text = GameText.weeks(GameText.route_ticks(_node().name, destination.name))


func _update_build_preview() -> void:
	var recipe: Dictionary = Recipes.DEFS[_selected_recipe_id()]
	var cost: float = recipe["build_cost"] + _possessional_spin.value * Labor.POSSESSIONAL_PRICE
	_build_preview.text = (
		"Обойдётся в %s, срок %s" % [GameText.money(cost), GameText.weeks(recipe["build_ticks"])]
	)


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


func _selected_recipe_id() -> String:
	return BUILD_RECIPE_IDS[max(_recipe_select.selected, 0)]


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


func _on_build() -> void:
	var economy = gameplay.economy
	var ok: bool = economy.start_construction(
		economy.player, _node(), _selected_recipe_id(), 1.0, int(_possessional_spin.value)
	)
	if ok:
		action_performed.emit(
			"Заложен %s в %s." % [Recipes.DEFS[_selected_recipe_id()]["display_name"], _node().name]
		)
	else:
		action_performed.emit("Стройка не начата: не хватает денег.")
