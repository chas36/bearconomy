# paper_panel.gd — центрированный документ поверх сцены города.
# Контент (бумага рынка/конторы/заказов) вставляется через open(); при
# закрытии остаётся внутри скрытой панели — refresh продолжает работать.
extends Control

signal closed

const UiTheme := preload("res://ui/ui_theme.gd")
const GenAssets := preload("res://ui/gen_assets.gd")

const PAPER_WIDTH := 700.0
const CONTENT_HEIGHT := 520.0

var _title_label: Label
var _content_slot: MarginContainer
var _content: Control = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	theme = UiTheme.build_paper()
	_build()


func open(title: String, content: Control) -> void:
	_title_label.text = title
	if _content != null and _content != content:
		_content_slot.remove_child(_content)
		_content.visible = false
	if content.get_parent() != _content_slot:
		var old_parent := content.get_parent()
		if old_parent != null:
			old_parent.remove_child(content)
		_content_slot.add_child(content)
	_content = content
	content.visible = true
	show()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var paper := PanelContainer.new()
	paper.custom_minimum_size.x = PAPER_WIDTH
	paper.add_theme_stylebox_override("panel", _paper_stylebox())
	center.add_child(paper)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	paper.add_child(body)

	body.add_child(_build_header())

	var rule := ColorRect.new()
	rule.color = Color(UiTheme.COL_INK, 0.5)
	rule.custom_minimum_size.y = 1
	body.add_child(rule)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(PAPER_WIDTH - 40.0, CONTENT_HEIGHT)
	body.add_child(scroll)

	_content_slot = MarginContainer.new()
	_content_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_content_slot.add_theme_constant_override(side, 4)
	scroll.add_child(_content_slot)


func _build_header() -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)

	_title_label = Label.new()
	_title_label.theme_type_variation = "InkTitleLabel"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title_label)

	head.add_child(_build_seal())

	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(34, 34)
	close_button.pressed.connect(close)
	head.add_child(close_button)
	return head


func _build_seal() -> Control:
	var seal_texture := GenAssets.texture("chrome/seal.png")
	if seal_texture != null:
		var seal := TextureRect.new()
		seal.texture = seal_texture
		seal.custom_minimum_size = Vector2(44, 44)
		seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return seal
	return UiTheme.WaxSeal.new()


func _paper_stylebox() -> StyleBox:
	var frame := GenAssets.texture("chrome/paper_frame.png")
	if frame == null:
		return get_theme_stylebox("panel", "ParchmentPanel")
	var box := StyleBoxTexture.new()
	box.texture = frame
	# Однородный центр листа начинается с ~25% от краёв (см. asset-brief)
	var margin := frame.get_width() * 0.25
	box.set_texture_margin_all(margin)
	# Поля с запасом: угловые орнаменты рамки не должны попадать под текст
	box.set_content_margin_all(56.0)
	return box


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
