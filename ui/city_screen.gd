# city_screen.gd — полноэкранная сцена города: панорама + здания
# Здания-кнопки появятся отдельной задачей; каркас держит фон и навигацию.
extends Control

signal back_requested
signal paper_requested(paper_id: String)  # market / works / contracts / caravans

const UiTheme := preload("res://ui/ui_theme.gd")
const GenAssets := preload("res://ui/gen_assets.gd")
const MapLayout := preload("res://ui/map_layout.gd")

var economy
var node_index := -1

var _built := false
var _panorama: TextureRect
var _fallback_bg: ColorRect
var _title_label: Label
var _subtitle_label: Label
var _buildings_box: Control


func setup(economy_ref) -> void:
	economy = economy_ref
	if not _built:
		_build()
		_built = true


func show_city(index: int) -> void:
	node_index = index
	refresh()
	show()


func refresh() -> void:
	if economy == null or node_index < 0 or node_index >= economy.nodes.size():
		return
	var node = economy.nodes[node_index]
	var info: Dictionary = MapLayout.node_info(node.name)
	var panorama: Texture2D = null
	var asset_key: String = info.get("key", "")
	if asset_key != "":
		panorama = GenAssets.texture("cities/panorama_%s.png" % asset_key)
	_panorama.texture = panorama
	_panorama.visible = panorama != null
	_title_label.text = node.name
	_subtitle_label.text = info.get("subtitle", "")
	_subtitle_label.visible = _subtitle_label.text != ""
	_rebuild_buildings(node.name)


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_fallback_bg = ColorRect.new()
	_fallback_bg.color = UiTheme.COL_BG
	_fallback_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fallback_bg)

	_panorama = TextureRect.new()
	_panorama.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panorama.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_panorama.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_panorama)

	_buildings_box = Control.new()
	_buildings_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_buildings_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_buildings_box)

	add_child(_build_title_plate())
	add_child(_build_back_button())


func _rebuild_buildings(node_name: String) -> void:
	for child in _buildings_box.get_children():
		child.queue_free()
	for building in MapLayout.buildings(node_name):
		_buildings_box.add_child(_make_building(building))


func _make_building(building: Dictionary) -> Control:
	var rect: Rect2 = building["rect"]
	var paper_id: String = building["id"]
	var caption: String = building["label"]
	var sprite_name: String = building["sprite"]
	var texture: Texture2D = null
	if sprite_name != "":
		texture = GenAssets.texture("buildings/%s.png" % sprite_name)

	var button: BaseButton
	if texture != null:
		button = _sprite_button(texture)
	else:
		# Фолбэк: табличка-кнопка на месте здания
		var plain := Button.new()
		plain.text = caption
		plain.theme_type_variation = "ParchmentButton"
		button = plain
	button.anchor_left = rect.position.x
	button.anchor_top = rect.position.y
	button.anchor_right = rect.end.x
	button.anchor_bottom = rect.end.y
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func() -> void: paper_requested.emit(paper_id))

	var ribbon := _caption_ribbon(caption)
	button.add_child(ribbon)
	button.mouse_entered.connect(
		func() -> void:
			button.modulate = Color(1.12, 1.12, 1.05)
			ribbon.visible = true
	)
	button.mouse_exited.connect(
		func() -> void:
			button.modulate = Color.WHITE
			ribbon.visible = false
	)
	return button


func _sprite_button(texture: Texture2D) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = texture
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	# Клик только по непрозрачным пикселям спрайта
	var mask := BitMap.new()
	mask.create_from_image_alpha(texture.get_image())
	button.texture_click_mask = mask
	return button


# Лента с названием у нижнего края здания; видна при наведении
func _caption_ribbon(caption: String) -> Control:
	var plate := PanelContainer.new()
	plate.theme_type_variation = "BarPanel"
	plate.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.visible = false

	var label := Label.new()
	label.text = caption
	label.theme_type_variation = "ValueLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(label)
	return plate


func _build_title_plate() -> Control:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 58)

	var plate := PanelContainer.new()
	plate.theme_type_variation = "BarPanel"
	margin.add_child(plate)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	plate.add_child(box)

	_title_label = Label.new()
	_title_label.theme_type_variation = "TitleLabel"
	box.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.theme_type_variation = "DimLabel"
	box.add_child(_subtitle_label)
	return margin


func _build_back_button() -> Control:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_bottom", 44)

	var button := Button.new()
	button.text = "На карту"
	button.theme_type_variation = "AccentButton"
	button.pressed.connect(func() -> void: back_requested.emit())
	margin.add_child(button)
	return margin
