# main.gd — сборка игрового экрана: планка, карта, вкладки конторы, события
# UI только читает симуляцию и шлёт команды через публичные API /sim.
extends Control

const Gameplay := preload("res://sim/gameplay.gd")
const OpenRouterNpc := preload("res://game/openrouter_npc.gd")
const UiTheme := preload("res://ui/ui_theme.gd")
const MapView := preload("res://ui/map_view.gd")
const TopBar := preload("res://ui/top_bar.gd")
const CityPanel := preload("res://ui/city_panel.gd")
const WorksPanel := preload("res://ui/works_panel.gd")
const ContractsPanel := preload("res://ui/contracts_panel.gd")
const JournalPanel := preload("res://ui/journal_panel.gd")
const EventDialog := preload("res://ui/event_dialog.gd")

const SIDE_PANEL_WIDTH := 420.0
const TAB_CITY := 0
const TAB_WORKS := 1
const TAB_CONTRACTS := 2
const TAB_JOURNAL := 3

var gameplay := Gameplay.new()
var current_speed := 0
var last_speed := 1

var _tick_timer: Timer
var _top_bar: TopBar
var _map_view: MapView
var _city_panel: CityPanel
var _works_panel: WorksPanel
var _contracts_panel: ContractsPanel
var _journal_panel: JournalPanel
var _event_dialog: EventDialog
var _tab_buttons: Array[Button] = []
var _tab_panels: Array[Control] = []
var _status_label: Label
var _counts_label: Label
var _last_money := 0.0


func _ready() -> void:
	gameplay.setup()
	_last_money = gameplay.economy.player.money

	theme = UiTheme.build()
	_build_ui()
	_refresh_all()

	_tick_timer = Timer.new()
	_tick_timer.timeout.connect(_advance_tick)
	add_child(_tick_timer)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE and not gameplay.has_pending_event():
			_set_speed(last_speed if current_speed == 0 else 0)
			_top_bar.show_speed(current_speed)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = UiTheme.COL_BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	margin.add_child(page)

	_top_bar = TopBar.new()
	_top_bar.step_pressed.connect(_advance_tick)
	_top_bar.speed_selected.connect(_set_speed)
	_top_bar.save_pressed.connect(_on_save)
	_top_bar.load_pressed.connect(_on_load)
	page.add_child(_top_bar)

	var center := HBoxContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 8)
	page.add_child(center)

	_map_view = MapView.new()
	_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_view.setup(gameplay.economy)
	_map_view.node_clicked.connect(_on_map_node_clicked)
	center.add_child(_map_view)

	center.add_child(_build_side_panel())
	page.add_child(_build_status_bar())

	_event_dialog = EventDialog.new()
	_event_dialog.choice_made.connect(_on_event_choice)
	_event_dialog.llm_requested.connect(_on_event_llm)
	add_child(_event_dialog)


func _build_side_panel() -> Control:
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = SIDE_PANEL_WIDTH
	side.add_theme_constant_override("separation", 0)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	side.add_child(tabs)

	_city_panel = CityPanel.new()
	_works_panel = WorksPanel.new()
	_contracts_panel = ContractsPanel.new()
	_journal_panel = JournalPanel.new()
	for panel in [_city_panel, _works_panel, _contracts_panel, _journal_panel]:
		panel.setup(gameplay)
	_city_panel.node_selected.connect(_on_city_node_selected)
	for panel in [_city_panel, _works_panel, _contracts_panel]:
		panel.action_performed.connect(_on_panel_action)
	_tab_panels.assign([_city_panel, _works_panel, _contracts_panel, _journal_panel])

	var group := ButtonGroup.new()
	var captions := ["Город", "Заводы", "Заказы", "Летопись"]
	for i in range(captions.size()):
		var button := Button.new()
		button.text = captions[i]
		button.theme_type_variation = "TabButton"
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_tab_selected.bind(i))
		tabs.add_child(button)
		_tab_buttons.append(button)

	var holder := PanelContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(holder)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)
	for panel in _tab_panels:
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(panel)

	_tab_buttons[TAB_CITY].button_pressed = true
	_on_tab_selected(TAB_CITY)
	return side


func _build_status_bar() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "StatusPanel"

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)

	_status_label = Label.new()
	_status_label.theme_type_variation = "DimLabel"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_status_label)

	_counts_label = Label.new()
	_counts_label.theme_type_variation = "SmallDimLabel"
	row.add_child(_counts_label)
	return bar


func _refresh_all() -> void:
	var economy = gameplay.economy
	_top_bar.set_state(economy, economy.player.money - _last_money)
	_last_money = economy.player.money

	_map_view.refresh()
	for panel in _tab_panels:
		panel.refresh()

	var open_count: int = _contracts_panel.open_count()
	_tab_buttons[TAB_CONTRACTS].text = ("Заказы (%d)" % open_count if open_count > 0 else "Заказы")
	_counts_label.text = (
		"Обозов в пути: %d · Строек: %d"
		% [economy.caravans.size(), economy.construction_queue.size()]
	)
	if not gameplay.notices.is_empty() and _status_label.text == "":
		_status_label.text = gameplay.notices[0]


func _advance_tick() -> void:
	if gameplay.has_pending_event():
		_set_speed(0)
		_top_bar.show_speed(0)
		_show_pending_event()
		return
	gameplay.advance_tick()
	if not gameplay.notices.is_empty():
		_status_label.text = gameplay.notices[0]
	if gameplay.has_pending_event():
		_set_speed(0)
		_top_bar.show_speed(0)
		_show_pending_event()
	_refresh_all()


func _show_pending_event() -> void:
	_event_dialog.show_event(gameplay.pending_event)


func _set_speed(ticks_per_second: int) -> void:
	current_speed = ticks_per_second
	if ticks_per_second <= 0:
		_tick_timer.stop()
		return
	last_speed = ticks_per_second
	_tick_timer.wait_time = 1.0 / ticks_per_second
	_tick_timer.start()


func _select_node(index: int) -> void:
	_map_view.selected_index = index
	_city_panel.set_node_index(index)
	_map_view.refresh()


func _on_map_node_clicked(index: int) -> void:
	_select_node(index)
	_tab_buttons[TAB_CITY].button_pressed = true
	_on_tab_selected(TAB_CITY)


func _on_city_node_selected(index: int) -> void:
	_select_node(index)


func _on_tab_selected(index: int) -> void:
	for i in range(_tab_panels.size()):
		_tab_panels[i].visible = i == index


func _on_panel_action(message: String) -> void:
	_status_label.text = message
	_journal_panel.add_line(message)
	_refresh_all()


func _on_event_choice(index: int) -> void:
	gameplay.choose_event(index)
	if not gameplay.notices.is_empty():
		_status_label.text = gameplay.notices[0]
	_refresh_all()


func _on_event_llm() -> void:
	if not gameplay.has_pending_event():
		return
	_event_dialog.set_llm_busy(true)

	var client := OpenRouterNpc.new()
	var result := client.generate_event_text(gameplay.to_llm_context())
	if result.get("ok", false):
		gameplay.set_pending_event_narrative(result["text"])
		_event_dialog.set_body_text(gameplay.pending_event_body())
		_journal_panel.add_line("Летописец переписал событие (%s)." % result.get("model", "модель"))
	else:
		_journal_panel.add_line("Летописец молчит: %s" % result.get("error", "нет ответа"))
	_event_dialog.set_llm_busy(false)


func _on_save() -> void:
	var message := "Игра сохранена." if gameplay.save_to_file() else "Сохранение не удалось."
	_on_panel_action(message)


func _on_load() -> void:
	if not gameplay.load_from_file():
		_on_panel_action("Загрузка не удалась.")
		return
	_map_view.setup(gameplay.economy)
	_select_node(min(_city_panel.node_index, gameplay.economy.nodes.size() - 1))
	_status_label.text = "Игра загружена."
	_journal_panel.add_line("Игра загружена.")
	if gameplay.has_pending_event():
		_show_pending_event()
	_refresh_all()
