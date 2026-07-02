# journal_panel.gd — вкладка «Летопись»: обозы в пути и записи приказчика
extends VBoxContainer

const Goods := preload("res://sim/goods.gd")
const UiTheme := preload("res://ui/ui_theme.gd")
const GameText := preload("res://ui/game_text.gd")

const MAX_LOG_LINES := 24

var gameplay

var _caravan_box: VBoxContainer
var _log_box: VBoxContainer
var _log_lines: Array[String] = []


func _init() -> void:
	add_theme_constant_override("separation", 8)


func setup(gameplay_ref) -> void:
	gameplay = gameplay_ref
	_build()
	refresh()


func add_line(text: String) -> void:
	_log_lines.push_front("Тик %d: %s" % [gameplay.economy.tick_count, text])
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines.resize(MAX_LOG_LINES)


func refresh() -> void:
	_fill_caravans()
	_fill_log()


func _build() -> void:
	_add_subheader("Обозы в пути")
	_caravan_box = VBoxContainer.new()
	_caravan_box.add_theme_constant_override("separation", 4)
	add_child(_caravan_box)

	_add_subheader("Записи приказчика")
	_log_box = VBoxContainer.new()
	_log_box.add_theme_constant_override("separation", 3)
	add_child(_log_box)


func _add_subheader(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "SubHeaderLabel"
	add_child(label)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			child.visible = false
		child.queue_free()


func _fill_caravans() -> void:
	_clear_children(_caravan_box)

	var caravans: Array = gameplay.economy.caravans
	if caravans.is_empty():
		var empty := Label.new()
		empty.text = "Дороги пусты."
		empty.theme_type_variation = "DimLabel"
		_caravan_box.add_child(empty)
		return

	for caravan in caravans:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var owner = gameplay.economy.agent_by_id(caravan.owner_id)
		var is_player: bool = owner != null and owner.is_player
		var dot := TextureRect.new()
		dot.texture = UiTheme.owner_dot(is_player)
		dot.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(dot)

		var label := Label.new()
		label.text = (
			"%s → %s: %.1f %s, ещё %s%s"
			% [
				caravan.origin.name,
				caravan.destination.name,
				caravan.qty,
				Goods.NAMES[caravan.good],
				GameText.weeks(caravan.remaining_ticks),
				" (на продажу)" if caravan.sell_on_arrival else "",
			]
		)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		_caravan_box.add_child(row)


func _fill_log() -> void:
	_clear_children(_log_box)

	var lines: Array[String] = []
	for line in _log_lines:
		lines.append(line)
	for notice in gameplay.notices:
		lines.append(notice)

	if lines.is_empty():
		var empty := Label.new()
		empty.text = "Пока записей нет."
		empty.theme_type_variation = "DimLabel"
		_log_box.add_child(empty)
		return

	for line in lines:
		var label := Label.new()
		label.text = line
		label.theme_type_variation = "SmallDimLabel"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_log_box.add_child(label)
