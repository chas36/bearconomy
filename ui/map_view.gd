# map_view.gd — схематичная карта: узлы, маршруты, караваны, предприятия, стройки
extends Control

signal node_clicked(index: int)

const Goods := preload("res://sim/goods.gd")

# Нормированные координаты узлов (умножаются на size), схематично запад -> восток.
const NODE_POS := {
	"Москва": Vector2(0.15, 0.62),
	"Макарьево": Vector2(0.5, 0.45),
	"Невьянск": Vector2(0.85, 0.3),
}
const FALLBACK_POS := Vector2(0.5, 0.85)

const BG_COLOR := Color(0.09, 0.11, 0.13)
const ROUTE_COLOR := Color(0.32, 0.3, 0.26)
const ROUTE_ACTIVE_COLOR := Color(0.55, 0.5, 0.38)
const ROUTE_WIDTH := 1.5
const ROUTE_ACTIVE_WIDTH := 3.5
const NODE_COLOR := Color(0.85, 0.8, 0.7)
const NODE_SELECTED_COLOR := Color(1.0, 0.95, 0.8)
const NODE_RADIUS := 13.0
const ENTERPRISE_SIZE := 9.0
const ENTERPRISE_GAP := 3.0
const CARAVAN_RADIUS := 5.0
const CONSTRUCTION_COLOR := Color(0.9, 0.6, 0.2)
const TEXT_COLOR := Color(0.92, 0.9, 0.85)
const CARGO_TEXT_COLOR := Color(0.8, 0.78, 0.72)
const OWNER_COLORS := {
	"player": Color(0.95, 0.78, 0.3),
	"stroganov": Color(0.45, 0.65, 0.95),
}
const DEFAULT_OWNER_COLOR := Color(0.7, 0.7, 0.7)
const BUTTON_SIZE := 48.0
const NAME_FONT_SIZE := 14
const CARGO_FONT_SIZE := 11

var economy
var selected_node_index := -1
var _node_buttons: Array[Button] = []


func refresh(economy_ref) -> void:
	economy = economy_ref
	if _node_buttons.size() != economy.nodes.size():
		_rebuild_node_buttons()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_position_node_buttons()
		queue_redraw()


func _rebuild_node_buttons() -> void:
	for button in _node_buttons:
		button.queue_free()
	_node_buttons.clear()
	for i in range(economy.nodes.size()):
		var button := Button.new()
		button.flat = true
		button.tooltip_text = economy.nodes[i].name
		button.pressed.connect(_on_node_button_pressed.bind(i))
		add_child(button)
		_node_buttons.append(button)
	_position_node_buttons()


func _position_node_buttons() -> void:
	if economy == null:
		return
	for i in range(_node_buttons.size()):
		var center := _node_position(economy.nodes[i])
		_node_buttons[i].position = center - Vector2(BUTTON_SIZE, BUTTON_SIZE) * 0.5
		_node_buttons[i].size = Vector2(BUTTON_SIZE, BUTTON_SIZE)


func _on_node_button_pressed(index: int) -> void:
	node_clicked.emit(index)


func _node_position(node) -> Vector2:
	var normalized: Vector2 = NODE_POS.get(node.name, FALLBACK_POS)
	return normalized * size


func _owner_color(owner_id: String) -> Color:
	return OWNER_COLORS.get(owner_id, DEFAULT_OWNER_COLOR)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)
	if economy == null:
		return
	_draw_routes()
	_draw_caravans()
	_draw_nodes()


func _draw_routes() -> void:
	var active_pairs := {}
	for c in economy.caravans:
		active_pairs[_pair_key(c.origin.name, c.destination.name)] = true

	for i in range(economy.nodes.size()):
		for j in range(i + 1, economy.nodes.size()):
			var a: Vector2 = _node_position(economy.nodes[i])
			var b: Vector2 = _node_position(economy.nodes[j])
			var key := _pair_key(economy.nodes[i].name, economy.nodes[j].name)
			if active_pairs.has(key):
				draw_line(a, b, ROUTE_ACTIVE_COLOR, ROUTE_ACTIVE_WIDTH)
			else:
				draw_line(a, b, ROUTE_COLOR, ROUTE_WIDTH)


func _pair_key(name_a: String, name_b: String) -> String:
	if name_a < name_b:
		return name_a + "|" + name_b
	return name_b + "|" + name_a


func _draw_caravans() -> void:
	var font := get_theme_default_font()
	for c in economy.caravans:
		# Прижим к 0.08..0.92, чтобы точка и подпись не ложились на кружок узла.
		var progress := clampf(1.0 - float(c.remaining_ticks) / float(c.total_ticks), 0.08, 0.92)
		var pos := _node_position(c.origin).lerp(_node_position(c.destination), progress)
		draw_circle(pos, CARAVAN_RADIUS, _owner_color(c.owner_id))
		var label: String = Goods.NAMES[c.good]
		draw_string(
			font,
			pos + Vector2(-30.0, -CARAVAN_RADIUS - 4.0),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			60.0,
			CARGO_FONT_SIZE,
			CARGO_TEXT_COLOR
		)


func _draw_nodes() -> void:
	var font := get_theme_default_font()
	var constructing := _nodes_under_construction()
	for i in range(economy.nodes.size()):
		var node = economy.nodes[i]
		var pos := _node_position(node)
		var color := NODE_SELECTED_COLOR if i == selected_node_index else NODE_COLOR
		draw_circle(pos, NODE_RADIUS, color)
		if i == selected_node_index:
			draw_arc(pos, NODE_RADIUS + 3.0, 0.0, TAU, 32, NODE_SELECTED_COLOR, 2.0)
		draw_string(
			font,
			pos + Vector2(-60.0, NODE_RADIUS + 16.0),
			node.name,
			HORIZONTAL_ALIGNMENT_CENTER,
			120.0,
			NAME_FONT_SIZE,
			TEXT_COLOR
		)
		_draw_enterprises(node, pos)
		if constructing.has(node):
			_draw_construction_icon(pos)


func _draw_enterprises(node, node_pos: Vector2) -> void:
	var owners: Array[String] = []
	for agent in economy.agents:
		for e in agent.enterprises:
			if e.node == node:
				owners.append(agent.id)

	var total_width := owners.size() * (ENTERPRISE_SIZE + ENTERPRISE_GAP) - ENTERPRISE_GAP
	var start_x := node_pos.x - total_width * 0.5
	var y := node_pos.y + NODE_RADIUS + 20.0
	for i in range(owners.size()):
		var rect := Rect2(
			Vector2(start_x + i * (ENTERPRISE_SIZE + ENTERPRISE_GAP), y),
			Vector2(ENTERPRISE_SIZE, ENTERPRISE_SIZE)
		)
		draw_rect(rect, _owner_color(owners[i]))


func _draw_construction_icon(node_pos: Vector2) -> void:
	# Треугольник-«леса» над узлом: идёт стройка или расширение.
	var top := node_pos + Vector2(0.0, -NODE_RADIUS - 14.0)
	var points := PackedVector2Array([top, top + Vector2(-7.0, 11.0), top + Vector2(7.0, 11.0)])
	draw_colored_polygon(points, CONSTRUCTION_COLOR)


func _nodes_under_construction() -> Dictionary:
	var result := {}
	for c in economy.construction_queue:
		var node = c.node if c.expand_target == null else c.expand_target.node
		if node != null:
			result[node] = true
	return result
