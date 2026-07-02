# event_dialog.gd — событие как письмо на пергаменте с сургучной печатью
extends Control

signal choice_made(index: int)
signal llm_requested

const UiTheme := preload("res://ui/ui_theme.gd")

var _title_label: Label
var _location_label: Label
var _body_label: Label
var _stakes_label: Label
var _choice_box: VBoxContainer
var _llm_button: Button


class WaxSeal:
	extends Control

	func _init() -> void:
		custom_minimum_size = Vector2(52, 52)

	func _draw() -> void:
		var center := size * 0.5
		var radius: float = min(size.x, size.y) * 0.5 - 2.0
		draw_circle(center + Vector2(1, 2), radius, Color(0, 0, 0, 0.25))
		draw_circle(center, radius, UiTheme.COL_SEAL)
		draw_circle(
			center + Vector2(-radius * 0.3, -radius * 0.35), radius * 0.25, Color(1, 1, 1, 0.10)
		)
		draw_arc(center, radius * 0.72, 0, TAU, 40, Color(0, 0, 0, 0.30), 1.5, true)
		draw_string(
			UiTheme.font_bold(),
			center + Vector2(-radius, radius * 0.45),
			"Д",
			HORIZONTAL_ALIGNMENT_CENTER,
			radius * 2.0,
			int(radius * 1.1),
			Color("e8d7b0", 0.9)
		)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func show_event(event: Dictionary) -> void:
	_title_label.text = event.get("title", "Событие")
	_location_label.text = event.get("location", "")
	_location_label.visible = _location_label.text != ""
	_body_label.text = event.get("generated_body", event.get("body", ""))
	_stakes_label.text = event.get("stakes", "")
	_stakes_label.visible = _stakes_label.text != ""

	for child in _choice_box.get_children():
		child.queue_free()
	var choices: Array = event.get("choices", [])
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var button := Button.new()
		button.text = choice.get("text", "")
		button.theme_type_variation = "ParchmentButton"
		button.pressed.connect(_on_choice.bind(i))
		_choice_box.add_child(button)

		var effect: String = choice.get("effect_summary", "")
		if effect != "":
			var effect_label := Label.new()
			effect_label.text = effect
			effect_label.theme_type_variation = "InkDimLabel"
			effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_choice_box.add_child(effect_label)

	set_llm_busy(false)
	show()


func set_body_text(text: String) -> void:
	_body_label.text = text


func set_llm_busy(busy: bool) -> void:
	_llm_button.disabled = busy
	_llm_button.text = "Летописец пишет..." if busy else "Спросить летописца"


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.theme_type_variation = "ParchmentPanel"
	panel.custom_minimum_size = Vector2(580, 0)
	center.add_child(panel)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	body.add_child(head)

	var head_text := VBoxContainer.new()
	head_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_text)

	_title_label = Label.new()
	_title_label.theme_type_variation = "InkTitleLabel"
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head_text.add_child(_title_label)

	_location_label = Label.new()
	_location_label.theme_type_variation = "InkDimLabel"
	head_text.add_child(_location_label)

	head.add_child(WaxSeal.new())

	var rule := ColorRect.new()
	rule.color = Color(UiTheme.COL_INK, 0.5)
	rule.custom_minimum_size.y = 1
	body.add_child(rule)

	_body_label = Label.new()
	_body_label.theme_type_variation = "InkLabel"
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size.x = 520
	body.add_child(_body_label)

	_stakes_label = Label.new()
	_stakes_label.theme_type_variation = "InkDimLabel"
	_stakes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_stakes_label)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 6)
	body.add_child(_choice_box)

	var footer := HBoxContainer.new()
	body.add_child(footer)

	_llm_button = Button.new()
	_llm_button.theme_type_variation = "ParchmentButton"
	_llm_button.tooltip_text = "Попросить LLM переписать описание живым языком (числа не меняются)"
	_llm_button.pressed.connect(func() -> void: llm_requested.emit())
	footer.add_child(_llm_button)


func _on_choice(index: int) -> void:
	hide()
	choice_made.emit(index)
