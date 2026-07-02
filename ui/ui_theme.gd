# ui_theme.gd — палитра, шрифты и тема интерфейса «старой конторы»
# Ассеты не нужны: иконки генерируются кодом, шрифт — Old Standard TT (OFL).
extends RefCounted

const Goods := preload("res://sim/goods.gd")

const FONT_DIR := "res://ui/assets/fonts"

# Палитра: тёмное дерево конторы + пергамент карты
const COL_BG := Color("221a12")
const COL_PANEL := Color("2e241a")
const COL_PANEL_LIGHT := Color("3b2e20")
const COL_PANEL_DARK := Color("281f15")
const COL_BORDER := Color("5d4930")
const COL_GOLD := Color("c9a44c")
const COL_GOLD_DIM := Color("9a7e3e")
const COL_TEXT := Color("e8dcc2")
const COL_TEXT_BRIGHT := Color("f6edd8")
const COL_TEXT_DIM := Color("a4906f")
const COL_PARCHMENT := Color("d9c69e")
const COL_PARCHMENT_DARK := Color("c9b189")
const COL_INK := Color("38291a")
const COL_INK_SOFT := Color("604b32")
const COL_RIVER := Color("6f8b96")
const COL_UP := Color("b0563c")  # цена растёт — дефицит
const COL_DOWN := Color("77935a")  # цена падает — избыток
const COL_PLAYER := Color("3f6b53")  # демидовская зелень
const COL_RIVAL := Color("8a3d33")  # строгановский кармин
const COL_SEAL := Color("7d2f26")

const GOOD_COLORS := {
	Goods.Good.RUDA: Color("8a6a4a"),
	Goods.Good.CHUGUN: Color("4c4c54"),
	Goods.Good.ZHELEZO: Color("7f8a94"),
	Goods.Good.ZERNO: Color("c2a23c"),
	Goods.Good.MUKA: Color("e2d3b3"),
	Goods.Good.VODKA: Color("9fb7c4"),
}

static var _fonts := {}
static var _textures := {}


static func font_regular() -> Font:
	return _font("regular", "OldStandard-Regular.ttf")


static func font_bold() -> Font:
	return _font("bold", "OldStandard-Bold.ttf")


static func font_italic() -> Font:
	return _font("italic", "OldStandard-Italic.ttf")


static func agent_color(agent_is_player: bool) -> Color:
	return COL_PLAYER if agent_is_player else COL_RIVAL


# Кружок товара для таблиц, списков и карты
static func good_dot(good: int, diameter := 12) -> Texture2D:
	var key := "good_%d_%d" % [good, diameter]
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(
			_circle_image(diameter, GOOD_COLORS[good], COL_INK)
		)
	return _textures[key]


static func owner_dot(is_player: bool, diameter := 10) -> Texture2D:
	var key := "owner_%s_%d" % [is_player, diameter]
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(
			_circle_image(diameter, agent_color(is_player), COL_INK)
		)
	return _textures[key]


# Стрелка тренда цены: 1 — вверх, -1 — вниз, 0 — ровно
static func trend_texture(direction: int, size := 12) -> Texture2D:
	var key := "trend_%d_%d" % [direction, size]
	if not _textures.has(key):
		var image: Image
		if direction > 0:
			image = _triangle_image(size, COL_UP, true)
		elif direction < 0:
			image = _triangle_image(size, COL_DOWN, false)
		else:
			image = _dash_image(size, Color(COL_TEXT_DIM, 0.6))
		_textures[key] = ImageTexture.create_from_image(image)
	return _textures[key]


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = font_regular()
	theme.default_font_size = 16

	_setup_labels(theme)
	_setup_buttons(theme)
	_setup_panels(theme)
	_setup_inputs(theme)
	_setup_misc(theme)
	return theme


static func _setup_labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", COL_TEXT)

	_label_variation(theme, "TitleLabel", font_bold(), 21, COL_GOLD)
	_label_variation(theme, "HeaderLabel", font_bold(), 18, COL_TEXT_BRIGHT)
	_label_variation(theme, "SubHeaderLabel", font_bold(), 16, COL_GOLD_DIM)
	_label_variation(theme, "DimLabel", font_regular(), 14, COL_TEXT_DIM)
	_label_variation(theme, "SmallDimLabel", font_regular(), 13, COL_TEXT_DIM)
	_label_variation(theme, "ValueLabel", font_bold(), 16, COL_GOLD)
	_label_variation(theme, "InkLabel", font_regular(), 16, COL_INK)
	_label_variation(theme, "InkDimLabel", font_italic(), 14, COL_INK_SOFT)
	_label_variation(theme, "InkTitleLabel", font_bold(), 22, COL_INK)


static func _label_variation(
	theme: Theme, type_name: String, font: Font, size: int, color: Color
) -> void:
	theme.set_type_variation(type_name, "Label")
	theme.set_font("font", type_name, font)
	theme.set_font_size("font_size", type_name, size)
	theme.set_color("font_color", type_name, color)


static func _setup_buttons(theme: Theme) -> void:
	for type_name in ["Button", "OptionButton", "CheckBox", "MenuButton"]:
		theme.set_stylebox("normal", type_name, _flat(COL_PANEL_LIGHT, COL_BORDER, 1, 3, 6.0))
		theme.set_stylebox("hover", type_name, _flat(Color("493a28"), COL_GOLD_DIM, 1, 3, 6.0))
		theme.set_stylebox("pressed", type_name, _flat(COL_PANEL_DARK, COL_GOLD, 1, 3, 6.0))
		theme.set_stylebox(
			"disabled",
			type_name,
			_flat(Color(COL_PANEL_DARK, 0.6), Color(COL_BORDER, 0.4), 1, 3, 6.0)
		)
		theme.set_stylebox("focus", type_name, StyleBoxEmpty.new())
		theme.set_color("font_color", type_name, COL_TEXT)
		theme.set_color("font_hover_color", type_name, COL_TEXT_BRIGHT)
		theme.set_color("font_pressed_color", type_name, COL_GOLD)
		theme.set_color("font_disabled_color", type_name, Color(COL_TEXT_DIM, 0.55))

	# Главные действия — латунная кнопка
	theme.set_type_variation("AccentButton", "Button")
	theme.set_stylebox("normal", "AccentButton", _flat(Color("6d5626"), COL_GOLD_DIM, 1, 3, 6.0))
	theme.set_stylebox("hover", "AccentButton", _flat(Color("83682e"), COL_GOLD, 1, 3, 6.0))
	theme.set_stylebox("pressed", "AccentButton", _flat(Color("57451f"), COL_GOLD, 1, 3, 6.0))
	theme.set_font("font", "AccentButton", font_bold())
	theme.set_color("font_color", "AccentButton", COL_TEXT_BRIGHT)

	# Кнопки на пергаменте (событийное письмо)
	theme.set_type_variation("ParchmentButton", "Button")
	theme.set_stylebox(
		"normal", "ParchmentButton", _flat(COL_PARCHMENT_DARK, COL_INK_SOFT, 1, 3, 8.0)
	)
	theme.set_stylebox("hover", "ParchmentButton", _flat(Color("bda478"), COL_INK, 1, 3, 8.0))
	theme.set_stylebox("pressed", "ParchmentButton", _flat(Color("ab9268"), COL_INK, 1, 3, 8.0))
	theme.set_color("font_color", "ParchmentButton", COL_INK)
	theme.set_color("font_hover_color", "ParchmentButton", Color("241708"))
	theme.set_color("font_pressed_color", "ParchmentButton", Color("241708"))

	# Вкладки боковой панели: плоские, активная подчёркнута латунью
	theme.set_type_variation("TabButton", "Button")
	var tab_idle := _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 6.0)
	var tab_hover := _flat(Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), 0, 0, 6.0)
	var tab_active := _flat(COL_PANEL_LIGHT, COL_GOLD, 0, 0, 6.0)
	tab_active.border_width_bottom = 2
	theme.set_stylebox("normal", "TabButton", tab_idle)
	theme.set_stylebox("hover", "TabButton", tab_hover)
	theme.set_stylebox("pressed", "TabButton", tab_active)
	theme.set_font("font", "TabButton", font_bold())
	theme.set_color("font_color", "TabButton", COL_TEXT_DIM)
	theme.set_color("font_pressed_color", "TabButton", COL_GOLD)
	theme.set_color("font_hover_color", "TabButton", COL_TEXT)


static func _setup_panels(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer", _flat(COL_PANEL, COL_BORDER, 1, 4, 10.0))

	theme.set_type_variation("CardPanel", "PanelContainer")
	theme.set_stylebox("panel", "CardPanel", _flat(COL_PANEL_LIGHT, COL_BORDER, 1, 3, 8.0))

	theme.set_type_variation("BarPanel", "PanelContainer")
	var bar := _flat(COL_PANEL_DARK, COL_BORDER, 0, 0, 8.0)
	bar.border_width_bottom = 1
	theme.set_stylebox("panel", "BarPanel", bar)

	theme.set_type_variation("StatusPanel", "PanelContainer")
	var status := _flat(COL_PANEL_DARK, COL_BORDER, 0, 0, 4.0)
	status.border_width_top = 1
	theme.set_stylebox("panel", "StatusPanel", status)

	theme.set_type_variation("ParchmentPanel", "PanelContainer")
	var parchment := _flat(COL_PARCHMENT, COL_INK_SOFT, 2, 4, 20.0)
	parchment.shadow_color = Color(0, 0, 0, 0.45)
	parchment.shadow_size = 12
	theme.set_stylebox("panel", "ParchmentPanel", parchment)


static func _setup_inputs(theme: Theme) -> void:
	theme.set_stylebox("normal", "LineEdit", _flat(Color("1d1610"), COL_BORDER, 1, 3, 5.0))
	theme.set_stylebox("focus", "LineEdit", _flat(Color("1d1610"), COL_GOLD_DIM, 1, 3, 5.0))
	theme.set_color("font_color", "LineEdit", COL_TEXT)
	theme.set_color("caret_color", "LineEdit", COL_GOLD)

	theme.set_stylebox("background", "ProgressBar", _flat(Color("1d1610"), COL_BORDER, 1, 2, 1.0))
	theme.set_stylebox("fill", "ProgressBar", _flat(COL_GOLD_DIM, COL_GOLD_DIM, 0, 2, 1.0))
	theme.set_color("font_color", "ProgressBar", COL_TEXT_BRIGHT)


static func _setup_misc(theme: Theme) -> void:
	theme.set_stylebox("panel", "PopupMenu", _flat(COL_PANEL_DARK, COL_BORDER, 1, 3, 4.0))
	theme.set_stylebox("hover", "PopupMenu", _flat(COL_PANEL_LIGHT, Color(0, 0, 0, 0), 0, 2, 2.0))
	theme.set_color("font_color", "PopupMenu", COL_TEXT)
	theme.set_color("font_hover_color", "PopupMenu", COL_TEXT_BRIGHT)

	theme.set_stylebox("panel", "TooltipPanel", _flat(COL_PARCHMENT, COL_INK_SOFT, 1, 3, 7.0))
	theme.set_color("font_color", "TooltipLabel", COL_INK)

	var separator := StyleBoxLine.new()
	separator.color = Color(COL_BORDER, 0.7)
	theme.set_stylebox("separator", "HSeparator", separator)


static func _flat(
	bg: Color, border: Color, border_width: int, radius: int, margin: float
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


static func _font(kind: String, file_name: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var font: Font = _load_ttf("%s/%s" % [FONT_DIR, file_name])
	_fonts[kind] = font
	return font


static func _load_ttf(path: String) -> Font:
	var font_file := FontFile.new()
	if font_file.load_dynamic_font(path) != OK:
		push_warning("Шрифт не найден, используется системный: %s" % path)
		return ThemeDB.fallback_font
	var fallbacks: Array[Font] = [ThemeDB.fallback_font]
	font_file.fallbacks = fallbacks
	return font_file


static func _circle_image(diameter: int, fill: Color, border: Color) -> Image:
	var image := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var radius := diameter * 0.5
	var center := Vector2(radius, radius)
	for y in range(diameter):
		for x in range(diameter):
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(center)
			var color := border if distance > radius - 1.8 else fill
			color.a = clampf(radius - distance, 0.0, 1.0)
			image.set_pixel(x, y, color)
	return image


static func _triangle_image(size: int, color: Color, pointing_up: bool) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		var row := float(y) if pointing_up else float(size - 1 - y)
		var half_width := (row + 1.0) / size * (size * 0.5)
		for x in range(size):
			var dx: float = abs(x + 0.5 - size * 0.5)
			var pixel := color
			pixel.a = clampf(half_width - dx, 0.0, 1.0) * color.a
			image.set_pixel(x, y, pixel)
	return image


static func _dash_image(size: int, color: Color) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var top := int(size * 0.5) - 1
	for y in range(top, top + 2):
		for x in range(int(size * 0.2), int(size * 0.8)):
			image.set_pixel(x, y, color)
	return image
