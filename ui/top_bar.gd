# top_bar.gd — верхняя планка: дом, дата, деньги, казна, ход времени
extends PanelContainer

signal step_pressed
signal speed_selected(ticks_per_second: int)
signal save_pressed
signal load_pressed

const UiTheme := preload("res://ui/ui_theme.gd")
const GameText := preload("res://ui/game_text.gd")

const SPEEDS := [0, 1, 2, 4]  # 0 = пауза
const SPEED_LABELS := {0: "II", 1: ">", 2: ">>", 4: ">>>"}

var _date_label: Label
var _money_label: Label
var _delta_label: Label
var _relations_bar: ProgressBar
var _relations_value: Label
var _speed_buttons := {}


func _init() -> void:
	theme_type_variation = "BarPanel"
	_build()


func set_state(economy, money_delta: float) -> void:
	_date_label.text = GameText.date_line(economy.tick_count)
	_money_label.text = GameText.money(economy.player.money)
	if abs(money_delta) < 0.05:
		_delta_label.text = ""
	else:
		_delta_label.text = "%s%.0f" % ["+" if money_delta > 0 else "−", abs(money_delta)]
		_delta_label.add_theme_color_override(
			"font_color", UiTheme.COL_DOWN if money_delta > 0 else UiTheme.COL_UP
		)
	_relations_bar.value = economy.player.state_relations
	_relations_value.text = "%.0f" % economy.player.state_relations


func show_speed(ticks_per_second: int) -> void:
	for speed in _speed_buttons:
		_speed_buttons[speed].set_pressed_no_signal(speed == ticks_per_second)


func _build() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)

	var title := Label.new()
	title.text = "Дом Демидовых"
	title.theme_type_variation = "TitleLabel"
	row.add_child(title)

	_date_label = Label.new()
	_date_label.theme_type_variation = "DimLabel"
	_date_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_date_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_money_label = Label.new()
	_money_label.theme_type_variation = "ValueLabel"
	_money_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_money_label)

	_delta_label = Label.new()
	_delta_label.theme_type_variation = "SmallDimLabel"
	_delta_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_delta_label.custom_minimum_size.x = 36
	row.add_child(_delta_label)

	var relations_caption := Label.new()
	relations_caption.text = "Казна"
	relations_caption.theme_type_variation = "DimLabel"
	relations_caption.tooltip_text = "Связи с казной: открывают приписных работников и заказы"
	relations_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(relations_caption)

	_relations_bar = ProgressBar.new()
	_relations_bar.min_value = 0
	_relations_bar.max_value = 100
	_relations_bar.show_percentage = false
	_relations_bar.custom_minimum_size = Vector2(80, 10)
	_relations_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_relations_bar)

	_relations_value = Label.new()
	_relations_value.theme_type_variation = "DimLabel"
	_relations_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_relations_value.custom_minimum_size.x = 28
	row.add_child(_relations_value)

	_build_time_controls(row)


func _build_time_controls(row: HBoxContainer) -> void:
	var group := ButtonGroup.new()
	for speed in SPEEDS:
		var button := Button.new()
		button.text = SPEED_LABELS[speed]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size.x = 40
		button.tooltip_text = "Пауза" if speed == 0 else "%d тик/с" % speed
		button.pressed.connect(_on_speed_pressed.bind(speed))
		row.add_child(button)
		_speed_buttons[speed] = button
	_speed_buttons[0].button_pressed = true

	var step_button := Button.new()
	step_button.text = "Неделя"
	step_button.tooltip_text = "Прожить одну неделю (один тик)"
	step_button.pressed.connect(func() -> void: step_pressed.emit())
	row.add_child(step_button)

	var save_button := Button.new()
	save_button.text = "Сохранить"
	save_button.pressed.connect(func() -> void: save_pressed.emit())
	row.add_child(save_button)

	var load_button := Button.new()
	load_button.text = "Загрузить"
	load_button.pressed.connect(func() -> void: load_pressed.emit())
	row.add_child(load_button)


func _on_speed_pressed(speed: int) -> void:
	speed_selected.emit(speed)
