# main.gd — минимальный Control UI поверх чистой симуляции
extends Control

const Goods := preload("res://sim/goods.gd")
const Labor := preload("res://sim/labor.gd")
const TradeNode := preload("res://sim/trade_node.gd")
const Enterprise := preload("res://sim/enterprise.gd")
const Gameplay := preload("res://sim/gameplay.gd")
const OpenRouterNpc := preload("res://game/openrouter_npc.gd")

var gameplay := Gameplay.new()
var economy
var scenario := {}
var goods: Array = Goods.Good.values()

var selected_node_index := 0
var selected_enterprise_index := 0
var selected_good_index := 0
var is_running := false

var tick_timer: Timer
var header_label: Label
var money_label: Label
var node_select: OptionButton
var enterprise_select: OptionButton
var good_select: OptionButton
var qty_spin: SpinBox
var speed_select: OptionButton
var play_button: Button
var contract_label: Label
var event_title_label: Label
var event_body_label: Label
var event_choice_box: VBoxContainer
var event_llm_button: Button
var node_grid: GridContainer
var enterprise_grid: GridContainer
var caravan_box: VBoxContainer
var log_label: Label
var wage_spin: SpinBox
var log_lines: Array[String] = []


func _ready() -> void:
	gameplay.setup()
	_sync_from_gameplay()
	_build_ui()
	_refresh_all()

	tick_timer = Timer.new()
	tick_timer.timeout.connect(_on_tick_timer_timeout)
	add_child(tick_timer)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	page.add_child(header)

	header_label = Label.new()
	header_label.text = "Демидов"
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_label)

	money_label = Label.new()
	header.add_child(money_label)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	header.add_child(controls)

	var step_button := Button.new()
	step_button.text = "Тик"
	step_button.pressed.connect(_on_step_pressed)
	controls.add_child(step_button)

	play_button = Button.new()
	play_button.text = "Пуск"
	play_button.pressed.connect(_on_play_pressed)
	controls.add_child(play_button)

	speed_select = OptionButton.new()
	speed_select.add_item("1/с", 1)
	speed_select.add_item("2/с", 2)
	speed_select.add_item("4/с", 4)
	speed_select.selected = 0
	speed_select.item_selected.connect(_on_speed_selected)
	controls.add_child(speed_select)

	var save_button := Button.new()
	save_button.text = "Сохранить"
	save_button.pressed.connect(_on_save_pressed)
	controls.add_child(save_button)

	var load_button := Button.new()
	load_button.text = "Загрузить"
	load_button.pressed.connect(_on_load_pressed)
	controls.add_child(load_button)

	contract_label = Label.new()
	contract_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(contract_label)

	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 10)
	page.add_child(columns)

	var left := _add_panel(columns, "Узел")
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	node_select = OptionButton.new()
	for n in economy.nodes:
		node_select.add_item(n.name)
	node_select.item_selected.connect(_on_node_selected)
	left.add_child(node_select)

	node_grid = GridContainer.new()
	node_grid.columns = 4
	node_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(node_grid)

	var trade_row := HBoxContainer.new()
	trade_row.add_theme_constant_override("separation", 8)
	left.add_child(trade_row)

	good_select = OptionButton.new()
	for g in goods:
		good_select.add_item(Goods.NAMES[g])
	good_select.item_selected.connect(_on_good_selected)
	trade_row.add_child(good_select)

	qty_spin = SpinBox.new()
	qty_spin.min_value = 1.0
	qty_spin.max_value = 100.0
	qty_spin.step = 1.0
	qty_spin.value = 5.0
	qty_spin.custom_minimum_size.x = 90
	trade_row.add_child(qty_spin)

	var buy_button := Button.new()
	buy_button.text = "Купить"
	buy_button.pressed.connect(_on_buy_pressed)
	trade_row.add_child(buy_button)

	var sell_button := Button.new()
	sell_button.text = "Продать"
	sell_button.pressed.connect(_on_sell_pressed)
	trade_row.add_child(sell_button)

	var logistics_row := HBoxContainer.new()
	logistics_row.add_theme_constant_override("separation", 8)
	left.add_child(logistics_row)

	var grain_button := Button.new()
	grain_button.text = "Зерно на завод"
	grain_button.pressed.connect(_on_send_grain_pressed)
	logistics_row.add_child(grain_button)

	var iron_button := Button.new()
	iron_button.text = "Железо в Москву"
	iron_button.pressed.connect(_on_send_iron_pressed)
	logistics_row.add_child(iron_button)

	var middle := _add_panel(columns, "Предприятие")
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	enterprise_select = OptionButton.new()
	for e in economy.player.enterprises:
		enterprise_select.add_item(e.name)
	enterprise_select.item_selected.connect(_on_enterprise_selected)
	middle.add_child(enterprise_select)

	enterprise_grid = GridContainer.new()
	enterprise_grid.columns = 2
	enterprise_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(enterprise_grid)

	var wage_row := HBoxContainer.new()
	wage_row.add_theme_constant_override("separation", 8)
	middle.add_child(wage_row)

	var wage_label := Label.new()
	wage_label.text = "Ставка"
	wage_row.add_child(wage_label)

	wage_spin = SpinBox.new()
	wage_spin.min_value = 0.5
	wage_spin.max_value = 4.0
	wage_spin.step = 0.1
	wage_spin.value_changed.connect(_on_wage_changed)
	wage_spin.custom_minimum_size.x = 100
	wage_row.add_child(wage_spin)

	var ascribed_button := Button.new()
	ascribed_button.text = "Просить приписных"
	ascribed_button.pressed.connect(_on_ascribed_pressed)
	middle.add_child(ascribed_button)

	var right := _add_panel(columns, "Ход")
	right.custom_minimum_size.x = 280

	event_title_label = Label.new()
	right.add_child(event_title_label)

	event_body_label = Label.new()
	event_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(event_body_label)

	event_llm_button = Button.new()
	event_llm_button.text = "LLM-описание"
	event_llm_button.pressed.connect(_on_event_llm_pressed)
	right.add_child(event_llm_button)

	event_choice_box = VBoxContainer.new()
	event_choice_box.add_theme_constant_override("separation", 6)
	right.add_child(event_choice_box)

	var event_separator := HSeparator.new()
	right.add_child(event_separator)

	caravan_box = VBoxContainer.new()
	right.add_child(caravan_box)

	var separator := HSeparator.new()
	right.add_child(separator)

	log_label = Label.new()
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(log_label)


func _add_panel(parent: Container, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title_label := Label.new()
	title_label.text = title
	box.add_child(title_label)
	return box


func _refresh_all() -> void:
	header_label.text = "Демидов | тик %d" % economy.tick_count
	money_label.text = (
		"Деньги %.1f | Казна %.1f" % [economy.player.money, economy.player.state_relations]
	)
	contract_label.text = gameplay.contract_status_text()
	_refresh_node_panel()
	_refresh_enterprise_panel()
	_refresh_event_panel()
	_refresh_caravans()
	log_label.text = _joined_log_text()


func _sync_from_gameplay() -> void:
	economy = gameplay.economy
	scenario = gameplay.scenario


func _refresh_event_panel() -> void:
	_clear_children(event_choice_box)
	if not gameplay.has_pending_event():
		event_title_label.text = "Событий нет"
		event_body_label.text = ""
		event_llm_button.disabled = true
		return

	event_title_label.text = gameplay.pending_event_title()
	event_body_label.text = gameplay.pending_event_body()
	event_llm_button.disabled = false
	var choices := gameplay.pending_event_choices()
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var button := Button.new()
		button.text = choice["text"]
		button.pressed.connect(_on_event_choice_pressed.bind(i))
		event_choice_box.add_child(button)


func _refresh_node_panel() -> void:
	_clear_children(node_grid)
	_add_grid_label(node_grid, "Товар")
	_add_grid_label(node_grid, "Склад")
	_add_grid_label(node_grid, "Цель")
	_add_grid_label(node_grid, "Цена")

	var node := _selected_node()
	for g in goods:
		_add_grid_label(node_grid, Goods.NAMES[g])
		_add_grid_label(node_grid, "%.1f" % node.stock[g])
		_add_grid_label(node_grid, "%.1f" % node.target_stock[g])
		_add_grid_label(node_grid, "%.2f" % node.price(g))

	_add_grid_label(node_grid, "Наёмные")
	_add_grid_label(node_grid, "%d" % node.labor_pool[Labor.Type.HIRED])
	_add_grid_label(node_grid, "")
	_add_grid_label(node_grid, "")


func _refresh_enterprise_panel() -> void:
	_clear_children(enterprise_grid)
	var e := _selected_enterprise()
	wage_spin.set_value_no_signal(e.hired_wage_offer)

	_add_grid_label(enterprise_grid, "Узел")
	_add_grid_label(enterprise_grid, e.node.name)
	_add_grid_label(enterprise_grid, "Мощность")
	_add_grid_label(enterprise_grid, "%.1f" % e.effective_capacity())
	_add_grid_label(enterprise_grid, "Штат")
	_add_grid_label(enterprise_grid, "%d/%d" % [e.worker_count(), int(ceil(e.labor_needed()))])
	_add_grid_label(enterprise_grid, "Наёмные")
	_add_grid_label(enterprise_grid, "%d" % e.workers[Labor.Type.HIRED])
	_add_grid_label(enterprise_grid, "Приписные")
	_add_grid_label(enterprise_grid, "%d" % e.workers[Labor.Type.ASCRIBED])
	_add_grid_label(enterprise_grid, "Посессионные")
	_add_grid_label(enterprise_grid, "%d" % e.workers[Labor.Type.POSSESSIONAL])


func _refresh_caravans() -> void:
	_clear_children(caravan_box)
	if economy.caravans.is_empty():
		var empty := Label.new()
		empty.text = "Караванов нет"
		caravan_box.add_child(empty)
		return

	for c in economy.caravans:
		var label := Label.new()
		label.text = (
			"%s -> %s: %.1f %s, %d т."
			% [c.origin.name, c.destination.name, c.qty, Goods.NAMES[c.good], c.remaining_ticks]
		)
		caravan_box.add_child(label)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			child.visible = false
		if not child.is_queued_for_deletion():
			child.queue_free()


func _add_grid_label(grid: GridContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	grid.add_child(label)


func _selected_node() -> TradeNode:
	return economy.nodes[selected_node_index]


func _selected_enterprise() -> Enterprise:
	return economy.player.enterprises[selected_enterprise_index]


func _selected_good() -> int:
	return int(goods[selected_good_index])


func _advance_tick() -> void:
	if gameplay.has_pending_event():
		_add_log("Сначала выберите решение события.")
		_refresh_all()
		return
	gameplay.advance_tick()
	_add_log("Тик %d" % economy.tick_count)
	if gameplay.has_pending_event():
		is_running = false
		play_button.text = "Пуск"
		tick_timer.stop()
	_refresh_all()


func _add_log(text: String) -> void:
	log_lines.push_front(text)
	if log_lines.size() > 8:
		log_lines.resize(8)


func _joined_log_text() -> String:
	var lines: Array[String] = []
	for notice in gameplay.notices:
		lines.append(notice)
	for line in log_lines:
		lines.append(line)
	if lines.size() > 10:
		lines.resize(10)
	return "\n".join(lines)


func _on_step_pressed() -> void:
	_advance_tick()


func _on_play_pressed() -> void:
	is_running = not is_running
	play_button.text = "Пауза" if is_running else "Пуск"
	if is_running:
		_update_timer_speed()
		tick_timer.start()
	else:
		tick_timer.stop()


func _on_speed_selected(_index: int) -> void:
	_update_timer_speed()


func _update_timer_speed() -> void:
	var ticks_per_second: int = max(1, speed_select.get_selected_id())
	tick_timer.wait_time = 1.0 / float(ticks_per_second)
	if is_running:
		tick_timer.start()


func _on_tick_timer_timeout() -> void:
	_advance_tick()


func _on_node_selected(index: int) -> void:
	selected_node_index = index
	_refresh_all()


func _on_enterprise_selected(index: int) -> void:
	selected_enterprise_index = index
	_refresh_all()


func _on_good_selected(index: int) -> void:
	selected_good_index = index


func _on_buy_pressed() -> void:
	var qty: float = economy.buy(
		economy.player, _selected_node(), _selected_good(), float(qty_spin.value)
	)
	_add_log("Куплено %.1f %s" % [qty, Goods.NAMES[_selected_good()]])
	_refresh_all()


func _on_sell_pressed() -> void:
	economy.sell(economy.player, _selected_node(), _selected_good(), float(qty_spin.value))
	_add_log("Продано %.1f %s" % [qty_spin.value, Goods.NAMES[_selected_good()]])
	_refresh_all()


func _on_send_grain_pressed() -> void:
	var makarievo: TradeNode = scenario["makarievo"]
	var nevyansk: TradeNode = scenario["nevyansk"]
	var qty: float = economy.buy_and_dispatch(
		economy.player,
		makarievo,
		nevyansk,
		Goods.Good.ZERNO,
		float(qty_spin.value),
		Gameplay.GRAIN_ROUTE_TICKS
	)
	_add_log("Зерно в Невьянск: %.1f" % qty)
	_refresh_all()


func _on_send_iron_pressed() -> void:
	var nevyansk: TradeNode = scenario["nevyansk"]
	var moskva: TradeNode = scenario["moskva"]
	var qty: float = economy.dispatch(
		economy.player,
		nevyansk,
		moskva,
		Goods.Good.ZHELEZO,
		nevyansk.stock[Goods.Good.ZHELEZO],
		Gameplay.IRON_ROUTE_TICKS,
		true
	)
	_add_log("Железо в Москву: %.1f" % qty)
	_refresh_all()


func _on_wage_changed(value: float) -> void:
	var e := _selected_enterprise()
	economy.set_hired_wage_offer(e, value)
	_add_log("%s: ставка %.2f" % [e.name, value])
	_refresh_all()


func _on_ascribed_pressed() -> void:
	var e := _selected_enterprise()
	var granted: int = economy.request_ascribed_workers(economy.player, e, 1)
	_add_log("%s: приписных +%d" % [e.name, granted])
	_refresh_all()


func _on_event_choice_pressed(choice_index: int) -> void:
	gameplay.choose_event(choice_index)
	_refresh_all()


func _on_event_llm_pressed() -> void:
	if not gameplay.has_pending_event():
		return
	event_llm_button.disabled = true
	event_llm_button.text = "Запрос..."
	_refresh_all()

	var client := OpenRouterNpc.new()
	var result := client.generate_event_text(gameplay.to_llm_context())
	if result.get("ok", false):
		gameplay.set_pending_event_narrative(result["text"])
		_add_log("LLM: описание обновлено (%s)." % result.get("model", "model"))
	else:
		_add_log("LLM: %s" % result.get("error", "не удалось получить описание"))

	event_llm_button.text = "LLM-описание"
	event_llm_button.disabled = false
	_refresh_all()


func _on_save_pressed() -> void:
	if gameplay.save_to_file():
		_add_log("Сохранено.")
	else:
		_add_log("Сохранение не удалось.")
	_refresh_all()


func _on_load_pressed() -> void:
	if gameplay.load_from_file():
		_sync_from_gameplay()
		selected_node_index = min(selected_node_index, economy.nodes.size() - 1)
		selected_enterprise_index = min(
			selected_enterprise_index, economy.player.enterprises.size() - 1
		)
		_add_log("Загружено.")
	else:
		_add_log("Загрузка не удалась.")
	_refresh_all()
