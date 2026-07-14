# main.gd — сборка игрового экрана: карта, город-сцена, планка, события
# UI только читает симуляцию и шлёт команды через публичные API /sim.
extends Control

const Gameplay := preload("res://sim/gameplay.gd")
const OpenRouterNpc := preload("res://game/openrouter_npc.gd")
const UiTheme := preload("res://ui/ui_theme.gd")
const MapView := preload("res://ui/map_view.gd")
const CityScreen := preload("res://ui/city_screen.gd")
const TopBar := preload("res://ui/top_bar.gd")
const MarketPaper := preload("res://ui/papers/market_paper.gd")
const CaravanPaper := preload("res://ui/papers/caravan_paper.gd")
const WorksPaper := preload("res://ui/papers/works_paper.gd")
const ContractsPanel := preload("res://ui/contracts_panel.gd")
const JournalPanel := preload("res://ui/journal_panel.gd")
const EventDialog := preload("res://ui/event_dialog.gd")
const PaperPanel := preload("res://ui/paper_panel.gd")

const PAPER_TITLES := {
	"market": "Торговые ряды",
	"works": "Заводская контора",
	"contracts": "Приказная доска",
	"caravans": "Ямской двор",
}

const TOP_BAR_HEIGHT := 48.0
const STATUS_BAR_HEIGHT := 30.0

var gameplay := Gameplay.new()
var current_speed := 0
var last_speed := 1

var _tick_timer: Timer
var _top_bar: TopBar
var _map_view: MapView
var _city_screen: CityScreen
var _market_paper: MarketPaper
var _caravan_paper: CaravanPaper
var _works_paper: WorksPaper
var _contracts_panel: ContractsPanel
var _journal_panel: JournalPanel
var _event_dialog: EventDialog
var _paper_panel: PaperPanel
var _panel_store: Control
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

	_map_view = MapView.new()
	_map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_view.offset_top = TOP_BAR_HEIGHT
	_map_view.offset_bottom = -STATUS_BAR_HEIGHT
	_map_view.setup(gameplay.economy)
	_map_view.node_clicked.connect(_on_map_node_clicked)
	add_child(_map_view)

	_city_screen = CityScreen.new()
	_city_screen.setup(gameplay.economy)
	_city_screen.back_requested.connect(_on_city_back)
	_city_screen.paper_requested.connect(_on_paper_requested)
	_city_screen.hide()
	add_child(_city_screen)

	_build_panel_store()

	_top_bar = TopBar.new()
	_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_bar.step_pressed.connect(_advance_tick)
	_top_bar.speed_selected.connect(_set_speed)
	_top_bar.save_pressed.connect(_on_save)
	_top_bar.load_pressed.connect(_on_load)
	add_child(_top_bar)

	add_child(_build_status_bar())

	_paper_panel = PaperPanel.new()
	add_child(_paper_panel)

	_event_dialog = EventDialog.new()
	_event_dialog.choice_made.connect(_on_event_choice)
	_event_dialog.llm_requested.connect(_on_event_llm)
	add_child(_event_dialog)


# Склад бумаг: контент живёт скрытым, paper_panel забирает его на показ
func _build_panel_store() -> void:
	_panel_store = Control.new()
	_panel_store.visible = false
	add_child(_panel_store)

	_market_paper = MarketPaper.new()
	_caravan_paper = CaravanPaper.new()
	_works_paper = WorksPaper.new()
	_contracts_panel = ContractsPanel.new()
	_journal_panel = JournalPanel.new()
	for panel in _all_papers():
		panel.setup(gameplay)
		_panel_store.add_child(panel)
	for panel in [_market_paper, _caravan_paper, _works_paper, _contracts_panel]:
		panel.action_performed.connect(_on_panel_action)


func _all_papers() -> Array:
	return [_market_paper, _caravan_paper, _works_paper, _contracts_panel, _journal_panel]


func _build_status_bar() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "StatusPanel"
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN

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
	if _city_screen.visible:
		_city_screen.refresh()
	for panel in _all_papers():
		panel.refresh()

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
	for paper in [_market_paper, _caravan_paper, _works_paper]:
		paper.set_node_index(index)
	_map_view.refresh()


func _on_map_node_clicked(index: int) -> void:
	_select_node(index)
	_map_view.hide()
	_city_screen.show_city(index)


func _on_city_back() -> void:
	_city_screen.hide()
	_map_view.show()


func _on_paper_requested(paper_id: String) -> void:
	var paper: Control
	match paper_id:
		"market":
			paper = _market_paper
		"works":
			paper = _works_paper
		"contracts":
			paper = _contracts_panel
		"caravans":
			paper = _caravan_paper
		_:
			return
	var node_name: String = gameplay.economy.nodes[_map_view.selected_index].name
	_paper_panel.open("%s — %s" % [PAPER_TITLES[paper_id], node_name], paper)


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
	_city_screen.setup(gameplay.economy)
	_paper_panel.close()
	_on_city_back()
	_select_node(min(_market_paper.node_index, gameplay.economy.nodes.size() - 1))
	_status_label.text = "Игра загружена."
	_journal_panel.add_line("Игра загружена.")
	if gameplay.has_pending_event():
		_show_pending_event()
	_refresh_all()
