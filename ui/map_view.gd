# map_view.gd — карта путей: гравюра-фон или чертёж-фолбэк, узлы, обозы
# Только читает состояние экономики; команды идут через сигнал node_clicked.
# Раскладка узлов — ui/map_layout.gd, ассеты — ui/assets/gen (с фолбэком).
extends Control

signal node_clicked(index: int)

const Goods := preload("res://sim/goods.gd")
const Labor := preload("res://sim/labor.gd")
const UiTheme := preload("res://ui/ui_theme.gd")
const GameText := preload("res://ui/game_text.gd")
const GenAssets := preload("res://ui/gen_assets.gd")
const MapLayout := preload("res://ui/map_layout.gd")

const NODE_RADIUS := 15.0
const HIT_RADIUS := 34.0
const MARKER_SIZE := 76.0
const CARAVAN_WIDTH := 48.0
const MAP_ASPECT := 16.0 / 9.0

const RIVER_VOLGA := [
	Vector2(0.40, 0.02),
	Vector2(0.435, 0.16),
	Vector2(0.425, 0.30),
	Vector2(0.455, 0.44),
	Vector2(0.47, 0.56),
	Vector2(0.44, 0.70),
	Vector2(0.38, 0.84),
	Vector2(0.35, 0.98),
]
const RIVER_MOSKVA := [
	Vector2(0.02, 0.60),
	Vector2(0.08, 0.645),
	Vector2(0.15, 0.69),
	Vector2(0.23, 0.71),
	Vector2(0.31, 0.75),
]
const RIVER_CHUSOVAYA := [
	Vector2(0.97, 0.08),
	Vector2(0.91, 0.18),
	Vector2(0.87, 0.32),
	Vector2(0.89, 0.46),
	Vector2(0.85, 0.60),
]

const FOREST_CLUSTERS := [
	Vector2(0.24, 0.26),
	Vector2(0.33, 0.40),
	Vector2(0.58, 0.30),
	Vector2(0.63, 0.66),
	Vector2(0.20, 0.86),
	Vector2(0.70, 0.14),
]
const TREE_OFFSETS := [
	Vector2(0.0, 0.0),
	Vector2(-0.030, 0.015),
	Vector2(0.028, 0.020),
	Vector2(-0.012, -0.024),
	Vector2(0.016, -0.014),
]

const STAIN_SPOTS := [
	Vector2(0.22, 0.18),
	Vector2(0.68, 0.78),
	Vector2(0.82, 0.12),
	Vector2(0.10, 0.90),
]

var economy
var selected_index := 0

var _hovered_index := -1


func setup(economy_ref) -> void:
	economy = economy_ref


func refresh() -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(event.position)
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _hovered_index >= 0:
			node_clicked.emit(_hovered_index)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hovered_index != -1:
		_hovered_index = -1
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.COL_BG)
	var background := GenAssets.texture("map/map_background.png")
	if background != null:
		draw_texture_rect(background, _map_rect(), false)
	else:
		_draw_parchment()
		_draw_rivers()
		_draw_ridge()
		_draw_forests()
		_draw_compass()
		_draw_frame()
	if economy != null:
		_draw_routes()
		_draw_caravans()
		_draw_nodes()
	_draw_cartouche()


# Кадр карты: 16:9, вписан в контрол по центру (letterbox)
func _map_rect() -> Rect2:
	var frame := size
	if frame.x / max(frame.y, 1.0) > MAP_ASPECT:
		frame = Vector2(frame.y * MAP_ASPECT, frame.y)
	else:
		frame = Vector2(frame.x, frame.x / MAP_ASPECT)
	return Rect2((size - frame) * 0.5, frame)


func _norm_to_px(normalized: Vector2) -> Vector2:
	var rect := _map_rect()
	return rect.position + normalized * rect.size


func _update_hover(mouse_pos: Vector2) -> void:
	var new_hover := -1
	if economy != null:
		for i in range(economy.nodes.size()):
			if _node_center(i).distance_to(mouse_pos) <= HIT_RADIUS:
				new_hover = i
				break
	if new_hover == _hovered_index:
		return
	_hovered_index = new_hover
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if new_hover >= 0 else Control.CURSOR_ARROW
	)
	tooltip_text = _node_tooltip(new_hover) if new_hover >= 0 else ""
	queue_redraw()


func _node_tooltip(index: int) -> String:
	var node = economy.nodes[index]
	var lines: Array[String] = [node.name]
	for g in Goods.Good.values():
		if node.stock[g] > 0.05 or node.consumption[g] > 0.0:
			lines.append("%s: %.1f по %.2f" % [Goods.NAMES[g], node.stock[g], node.price(g)])
	lines.append("Наёмных на рынке: %d" % node.labor_pool[Labor.Type.HIRED])
	return "\n".join(lines)


func _node_center(index: int) -> Vector2:
	var node = economy.nodes[index]
	var info: Dictionary = MapLayout.node_info(node.name)
	var normalized: Vector2 = info.get("pos", _fallback_pos(index))
	return _norm_to_px(normalized)


func _fallback_pos(index: int) -> Vector2:
	var count: int = max(economy.nodes.size() - 1, 1)
	return Vector2(0.2 + 0.6 * float(index) / count, 0.84)


func _draw_parchment() -> void:
	var rect := _map_rect()
	draw_rect(rect, UiTheme.COL_PARCHMENT)
	for spot in STAIN_SPOTS:
		draw_circle(_norm_to_px(spot), rect.size.x * 0.09, Color(UiTheme.COL_INK, 0.03))
		draw_circle(_norm_to_px(spot), rect.size.x * 0.05, Color(UiTheme.COL_INK, 0.03))
	_draw_vignette()


func _draw_vignette() -> void:
	var rect := _map_rect()
	var depth: float = min(rect.size.x, rect.size.y) * 0.10
	var shade := Color(0.20, 0.13, 0.06, 0.22)
	var clear := Color(0.20, 0.13, 0.06, 0.0)
	var top_left := rect.position
	var w := rect.size.x
	var h := rect.size.y
	var strips := [
		[Vector2(0, 0), Vector2(w, 0), Vector2(w, depth), Vector2(0, depth)],
		[Vector2(0, h), Vector2(w, h), Vector2(w, h - depth), Vector2(0, h - depth)],
		[Vector2(0, 0), Vector2(0, h), Vector2(depth, h), Vector2(depth, 0)],
		[Vector2(w, 0), Vector2(w, h), Vector2(w - depth, h), Vector2(w - depth, 0)],
	]
	for strip in strips:
		var points := PackedVector2Array()
		for corner in strip:
			points.append(top_left + corner)
		var colors := PackedColorArray([shade, shade, clear, clear])
		draw_polygon(points, colors)


func _draw_frame() -> void:
	var rect := _map_rect()
	var ink := Color(UiTheme.COL_INK, 0.75)
	draw_rect(Rect2(rect.position + Vector2(7, 7), rect.size - Vector2(14, 14)), ink, false, 2.5)
	draw_rect(
		Rect2(rect.position + Vector2(13, 13), rect.size - Vector2(26, 26)),
		Color(UiTheme.COL_INK, 0.4),
		false,
		1.0
	)


func _draw_rivers() -> void:
	for river in [RIVER_VOLGA, RIVER_MOSKVA, RIVER_CHUSOVAYA]:
		var points := _smooth_polyline(river)
		draw_polyline(points, Color(UiTheme.COL_RIVER, 0.5), 4.0, true)
		draw_polyline(points, Color(UiTheme.COL_RIVER, 0.75), 1.5, true)


func _draw_ridge() -> void:
	# Уральский хребет: гряда «домиков» тушью с лёгким изгибом
	var ink := Color(UiTheme.COL_INK, 0.5)
	for k in range(10):
		var normalized := Vector2(0.775 + 0.018 * sin(k * 2.1), 0.06 + k * 0.095)
		var center := _norm_to_px(normalized)
		var span := 9.0 + 3.0 * sin(k * 1.3)
		var peak := center + Vector2(0, -span * 0.9)
		draw_line(center + Vector2(-span, 0), peak, ink, 1.6, true)
		draw_line(peak, center + Vector2(span, 0), ink, 1.6, true)
		draw_line(peak, peak + Vector2(span * 0.35, span * 0.45), Color(UiTheme.COL_INK, 0.25), 1.0)


func _draw_forests() -> void:
	var ink := Color(UiTheme.COL_INK, 0.30)
	for cluster in FOREST_CLUSTERS:
		for offset in TREE_OFFSETS:
			var base: Vector2 = _norm_to_px(cluster + offset)
			var h := 9.0
			draw_line(base + Vector2(-4, 0), base + Vector2(0, -h), ink, 1.2, true)
			draw_line(base + Vector2(0, -h), base + Vector2(4, 0), ink, 1.2, true)
			draw_line(base, base + Vector2(0, 3), ink, 1.2, true)


func _draw_routes() -> void:
	for i in range(economy.nodes.size()):
		for j in range(i + 1, economy.nodes.size()):
			var points := _route_points(i, j)
			# Светлый подслой держит читаемость пунктира на тёмной гравюре
			draw_polyline(points, Color(UiTheme.COL_PARCHMENT, 0.45), 5.0, true)
			for k in range(0, points.size() - 1, 2):
				draw_line(points[k], points[k + 1], Color(UiTheme.COL_INK, 0.65), 1.6, true)


func _draw_caravans() -> void:
	var sprite := GenAssets.texture("map/caravan.png")
	var route_load := {}
	for caravan in economy.caravans:
		var origin_index: int = economy.nodes.find(caravan.origin)
		var destination_index: int = economy.nodes.find(caravan.destination)
		if origin_index < 0 or destination_index < 0:
			continue
		var progress: float = 1.0 - float(caravan.remaining_ticks) / float(caravan.total_ticks)
		var pos := _route_position(origin_index, destination_index, progress)
		var key := (
			"%d_%d" % [min(origin_index, destination_index), max(origin_index, destination_index)]
		)
		var stack: int = route_load.get(key, 0)
		route_load[key] = stack + 1
		pos += Vector2(0, -14.0 * stack)

		var owner_agent = economy.agent_by_id(caravan.owner_id)
		var is_player: bool = owner_agent != null and owner_agent.is_player
		if sprite != null:
			var heading_left: bool = (
				_node_center(destination_index).x < _node_center(origin_index).x
			)
			_draw_caravan_sprite(sprite, pos, is_player, heading_left)
		else:
			draw_circle(pos + Vector2(1, 2), 7.0, Color(0, 0, 0, 0.2))
			draw_circle(pos, 6.5, UiTheme.agent_color(is_player))
			draw_circle(pos, 3.8, UiTheme.GOOD_COLORS[caravan.good])
			draw_arc(pos, 6.5, 0, TAU, 24, Color(UiTheme.COL_INK, 0.8), 1.2, true)
		draw_string(
			UiTheme.font_bold(),
			pos + Vector2(-40, -20),
			"%.0f" % caravan.qty,
			HORIZONTAL_ALIGNMENT_CENTER,
			80,
			12,
			Color(UiTheme.COL_INK, 0.85)
		)


func _draw_caravan_sprite(
	sprite: Texture2D, pos: Vector2, is_player: bool, heading_left: bool
) -> void:
	var w := CARAVAN_WIDTH
	var h := w * float(sprite.get_height()) / float(sprite.get_width())
	var rect := Rect2(pos - Vector2(w * 0.5, h * 0.5), Vector2(w, h))
	if heading_left:
		# Отрицательная ширина зеркалит текстуру по горизонтали
		rect = Rect2(Vector2(rect.position.x + w, rect.position.y), Vector2(-w, h))
	draw_texture_rect(sprite, rect, false)
	# Флажок цвета владельца над повозкой
	var mast_base := pos + Vector2(0, -h * 0.5)
	var mast_top := mast_base + Vector2(0, -9)
	draw_line(mast_base, mast_top, Color(UiTheme.COL_INK, 0.85), 1.4, true)
	var flag := PackedVector2Array([mast_top, mast_top + Vector2(8, 2.5), mast_top + Vector2(0, 5)])
	draw_colored_polygon(flag, UiTheme.agent_color(is_player))


func _draw_nodes() -> void:
	for i in range(economy.nodes.size()):
		var node = economy.nodes[i]
		var center := _node_center(i)
		var info: Dictionary = MapLayout.node_info(node.name)
		var marker: Texture2D = null
		var asset_key: String = info.get("key", "")
		if asset_key != "":
			marker = GenAssets.texture("map/marker_%s.png" % asset_key)
		var radius := MARKER_SIZE * 0.5 if marker != null else NODE_RADIUS

		if marker == null:
			draw_circle(center + Vector2(2, 3), radius + 2, Color(0, 0, 0, 0.18))
		if i == selected_index:
			draw_circle(center, radius + 7, Color(UiTheme.COL_GOLD, 0.20))
			draw_arc(center, radius + 5, 0, TAU, 48, UiTheme.COL_GOLD, 2.0, true)
		elif i == _hovered_index:
			draw_arc(center, radius + 5, 0, TAU, 48, Color(UiTheme.COL_GOLD, 0.6), 1.5, true)

		if marker != null:
			var half := Vector2(MARKER_SIZE, MARKER_SIZE) * 0.5
			draw_texture_rect(
				marker, Rect2(center - half, Vector2(MARKER_SIZE, MARKER_SIZE)), false
			)
		else:
			draw_circle(center, radius, UiTheme.COL_PARCHMENT_DARK)
			draw_arc(center, radius, 0, TAU, 40, UiTheme.COL_INK, 2.0, true)
			_draw_node_glyph(info.get("kind", "town"), center)
		_draw_node_caption(i, node, center, radius)


func _draw_node_caption(index: int, node, center: Vector2, radius: float) -> void:
	var info: Dictionary = MapLayout.node_info(node.name)
	var name_pos := center + Vector2(-90, radius + 18)
	draw_string(
		UiTheme.font_bold(),
		name_pos + Vector2(1, 1),
		node.name,
		HORIZONTAL_ALIGNMENT_CENTER,
		180,
		16,
		Color(UiTheme.COL_PARCHMENT, 0.9)
	)
	draw_string(
		UiTheme.font_bold(),
		name_pos,
		node.name,
		HORIZONTAL_ALIGNMENT_CENTER,
		180,
		16,
		UiTheme.COL_INK
	)
	var subtitle: String = info.get("subtitle", "")
	if subtitle != "":
		draw_string(
			UiTheme.font_italic(),
			center + Vector2(-90, radius + 33),
			subtitle,
			HORIZONTAL_ALIGNMENT_CENTER,
			180,
			12,
			Color(UiTheme.COL_INK, 0.7)
		)
	_draw_enterprise_badges(index, center, radius)


func _draw_enterprise_badges(index: int, center: Vector2, radius: float) -> void:
	var node = economy.nodes[index]
	var badges: Array[Color] = []
	for agent in economy.agents:
		for enterprise in agent.enterprises:
			if enterprise.node == node:
				badges.append(UiTheme.agent_color(agent.is_player))
	var construction_count := 0
	for construction in economy.construction_queue:
		if construction.node == node:
			construction_count += 1

	var badge_size := 7.0
	var gap := 3.0
	var total := badges.size() * (badge_size + gap) - gap
	if construction_count > 0:
		total += badge_size + gap
	var start := center + Vector2(-total * 0.5, radius + 40)
	for k in range(badges.size()):
		var rect := Rect2(
			start + Vector2(k * (badge_size + gap), 0), Vector2(badge_size, badge_size)
		)
		draw_rect(rect, badges[k])
		draw_rect(rect, Color(UiTheme.COL_INK, 0.7), false, 1.0)
	if construction_count > 0:
		var cx := (
			start + Vector2(badges.size() * (badge_size + gap) + badge_size * 0.5, badge_size * 0.5)
		)
		var half := badge_size * 0.7
		var diamond := PackedVector2Array(
			[
				cx + Vector2(0, -half),
				cx + Vector2(half, 0),
				cx + Vector2(0, half),
				cx + Vector2(-half, 0),
			]
		)
		draw_colored_polygon(diamond, UiTheme.COL_GOLD)
		draw_polyline(diamond + PackedVector2Array([diamond[0]]), Color(UiTheme.COL_INK, 0.8), 1.0)


func _draw_node_glyph(kind: String, center: Vector2) -> void:
	var ink := UiTheme.COL_INK
	match kind:
		"capital":
			draw_rect(Rect2(center + Vector2(-4, -3), Vector2(8, 9)), ink)
			var roof := PackedVector2Array(
				[center + Vector2(-5, -3), center + Vector2(5, -3), center + Vector2(0, -10)]
			)
			draw_colored_polygon(roof, ink)
			draw_line(center + Vector2(0, -10), center + Vector2(0, -13), ink, 1.4, true)
		"fair":
			var tent := PackedVector2Array(
				[center + Vector2(-7, 6), center + Vector2(7, 6), center + Vector2(0, -7)]
			)
			draw_colored_polygon(tent, ink)
			draw_line(center + Vector2(0, -7), center + Vector2(0, -11), ink, 1.4, true)
			draw_line(center + Vector2(0, -11), center + Vector2(4, -9), ink, 1.4, true)
		_:
			draw_rect(Rect2(center + Vector2(-6, -1), Vector2(12, 7)), ink)
			var roof := PackedVector2Array(
				[center + Vector2(-7, -1), center + Vector2(7, -1), center + Vector2(0, -7)]
			)
			draw_colored_polygon(roof, ink)
			draw_rect(Rect2(center + Vector2(3, -10), Vector2(3, 6)), ink)
			draw_circle(center + Vector2(5, -12), 1.6, Color(ink, 0.5))
			draw_circle(center + Vector2(7, -15), 1.2, Color(ink, 0.35))


func _draw_compass() -> void:
	var center := _norm_to_px(Vector2(0.075, 0.16))
	var ink := Color(UiTheme.COL_INK, 0.65)
	draw_arc(center, 17, 0, TAU, 40, ink, 1.4, true)
	draw_arc(center, 3, 0, TAU, 20, ink, 1.2, true)
	for k in range(8):
		var angle := TAU * k / 8.0
		var outer := 16.0 if k % 2 == 0 else 9.0
		draw_line(
			center + Vector2(cos(angle), sin(angle)) * 5,
			center + Vector2(cos(angle), sin(angle)) * outer,
			ink,
			1.2,
			true
		)
	draw_string(
		UiTheme.font_bold(),
		center + Vector2(-10, -22),
		"С",
		HORIZONTAL_ALIGNMENT_CENTER,
		20,
		14,
		UiTheme.COL_INK
	)


func _draw_cartouche() -> void:
	var rect := _map_rect()
	var box_size := Vector2(252, 78)
	var origin := rect.position + rect.size - box_size - Vector2(22, 22)
	# На гравюре-фоне картуш уже нарисован — кладём в него только текст
	if GenAssets.texture("map/map_background.png") == null:
		draw_rect(Rect2(origin, box_size), Color(UiTheme.COL_PARCHMENT_DARK, 0.85))
		draw_rect(Rect2(origin, box_size), Color(UiTheme.COL_INK, 0.8), false, 1.6)
		draw_rect(
			Rect2(origin + Vector2(4, 4), box_size - Vector2(8, 8)),
			Color(UiTheme.COL_INK, 0.35),
			false,
			1.0
		)
	draw_string(
		UiTheme.font_bold(),
		origin + Vector2(0, 24),
		"ЧЕРТЕЖЪ ТОРГОВЫХЪ ПУТЕЙ",
		HORIZONTAL_ALIGNMENT_CENTER,
		box_size.x,
		14,
		UiTheme.COL_INK
	)
	var tick: int = economy.tick_count if economy != null else 0
	draw_string(
		UiTheme.font_italic(),
		origin + Vector2(0, 43),
		GameText.year_line(tick),
		HORIZONTAL_ALIGNMENT_CENTER,
		box_size.x,
		13,
		Color(UiTheme.COL_INK, 0.75)
	)
	_draw_legend_row(origin + Vector2(30, 56))


func _draw_legend_row(pos: Vector2) -> void:
	draw_rect(Rect2(pos, Vector2(8, 8)), UiTheme.COL_PLAYER)
	draw_string(
		UiTheme.font_regular(),
		pos + Vector2(13, 9),
		"Демидовы",
		HORIZONTAL_ALIGNMENT_LEFT,
		90,
		12,
		Color(UiTheme.COL_INK, 0.8)
	)
	draw_rect(Rect2(pos + Vector2(105, 0), Vector2(8, 8)), UiTheme.COL_RIVAL)
	draw_string(
		UiTheme.font_regular(),
		pos + Vector2(118, 9),
		"соперники",
		HORIZONTAL_ALIGNMENT_LEFT,
		90,
		12,
		Color(UiTheme.COL_INK, 0.8)
	)


func _route_points(index_a: int, index_b: int) -> PackedVector2Array:
	var start := _node_center(index_a)
	var finish := _node_center(index_b)
	if economy.nodes[index_a].name > economy.nodes[index_b].name:
		var swap := start
		start = finish
		finish = swap
	var control := _route_control(start, finish)
	var points := PackedVector2Array()
	var steps := 24
	for k in range(steps + 1):
		points.append(_bezier(start, control, finish, float(k) / steps))
	return points


func _route_position(origin_index: int, destination_index: int, progress: float) -> Vector2:
	var start := _node_center(origin_index)
	var finish := _node_center(destination_index)
	# Контрольная точка не зависит от направления движения
	var control: Vector2
	if economy.nodes[origin_index].name > economy.nodes[destination_index].name:
		control = _route_control(finish, start)
	else:
		control = _route_control(start, finish)
	return _bezier(start, control, finish, clampf(progress, 0.02, 0.98))


func _route_control(start: Vector2, finish: Vector2) -> Vector2:
	var mid := (start + finish) * 0.5
	var perpendicular := (finish - start).orthogonal().normalized()
	return mid + perpendicular * start.distance_to(finish) * 0.09


func _bezier(a: Vector2, control: Vector2, b: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u + control * 2.0 * u * t + b * t * t


func _smooth_polyline(normalized_points: Array) -> PackedVector2Array:
	var source: Array[Vector2] = []
	for p in normalized_points:
		source.append(_norm_to_px(p))
	var result := PackedVector2Array()
	for i in range(source.size() - 1):
		var p0 := source[max(i - 1, 0)]
		var p1 := source[i]
		var p2 := source[i + 1]
		var p3 := source[min(i + 2, source.size() - 1)]
		for k in range(6):
			result.append(_catmull_rom(p0, p1, p2, p3, k / 6.0))
	result.append(source[source.size() - 1])
	return result


func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return (
		0.5
		* (
			2.0 * p1
			+ (p2 - p0) * t
			+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
			+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3
		)
	)
