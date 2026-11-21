extends Control

signal destination_selected(destination_id: String, title: String)

const WORLD_HALF_EXTENT := 140.0
const PANEL_SIZE := Vector2(960.0, 620.0)
const STATUS_RESERVE := 96.0
const MAP_LABEL_SIZE := 15
const DESCRIPTION_SIZE := 15
const DESCRIPTION_LINE_HEIGHT := 24.0
const DESCRIPTION_BREAK_PUNCTUATION := "，；。！？"
const DESCRIPTION_CLOSING_PUNCTUATION := "”’」』）》】"
const UI_FONT = preload("res://art/fonts/ark_ui_font.tres")

var player_position := Vector3.ZERO
var destinations: Array[Dictionary] = []
var selected_id := "home"
var _helm_origin := false
var _panel_rect := Rect2()
var _map_rect := Rect2()
var _label_rects: Dictionary = {}
# Opt-in presentation audit; normal rendering does not allocate line records.
var _description_graphemes := RegEx.create_from_string("\\X")
var _record_details_draw := false
var _details_draw_records: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func refresh(position: Vector3, points: Array[Dictionary], selection: String = "", helm_origin: bool = false) -> void:
	player_position = position
	_helm_origin = helm_origin
	destinations = points.duplicate(true)
	if not selection.is_empty():
		selected_id = selection
	queue_redraw()


func _draw() -> void:
	_details_draw_records.clear()
	var viewport_size := get_size()
	if viewport_size.x < 1.0 or viewport_size.y < 1.0:
		return
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.015, 0.035, 0.045, 0.82), true)
	# Save feedback is a sibling anchored to the bottom 90 px. Keep both the
	# map and its close instructions above that strip, even at 1280 x 720.
	_panel_rect.size = Vector2(minf(PANEL_SIZE.x, viewport_size.x - 36.0), minf(PANEL_SIZE.y, viewport_size.y - STATUS_RESERVE - 36.0))
	_panel_rect.position = (viewport_size - Vector2(0.0, STATUS_RESERVE) - _panel_rect.size) * 0.5
	draw_rect(_panel_rect, Color("142d31"), true)
	draw_rect(_panel_rect, Color("cfb77c"), false, 2.0)
	var font: Font = UI_FONT
	var left := _panel_rect.position.x + 24.0
	var top := _panel_rect.position.y + 36.0
	draw_string(font, Vector2(left, top), "潮痕图", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("f2dfae"))
	draw_string(font, Vector2(left + 122.0, top), "已绘海域可自由探索；边缘涌流仅标记当前地图范围", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("b7c9b8"))
	var side := minf(_panel_rect.size.y - 128.0, _panel_rect.size.x - 356.0)
	_map_rect = Rect2(Vector2(left, top + 26.0), Vector2(side, side))
	_draw_map(font)
	_draw_selected_details(font, Vector2(_map_rect.end.x + 28.0, _map_rect.position.y + 12.0))
	_draw_detail_text(font, Vector2(left, _panel_rect.end.y - 22.0), "点击地点查看方向与距离　·　M 或 Esc 收起", 14, Color("d3d8c5", 0.8), "footer")


func _draw_map(font: Font) -> void:
	draw_rect(_map_rect, Color("092b3a"), true)
	draw_rect(_map_rect, Color("52756e", 0.64), false, 1.0)
	for step in range(1, 6):
		var unit := float(step) / 6.0
		var x := lerpf(_map_rect.position.x, _map_rect.end.x, unit)
		var y := lerpf(_map_rect.position.y, _map_rect.end.y, unit)
		draw_line(Vector2(x, _map_rect.position.y), Vector2(x, _map_rect.end.y), Color("73918a", 0.16), 1.0)
		draw_line(Vector2(_map_rect.position.x, y), Vector2(_map_rect.end.x, y), Color("73918a", 0.16), 1.0)
	_draw_island(Vector3(11.0, 0.0, -14.0), Vector2(24.0, 20.0), 24, Color("536d50"), Color("aaa47d"))
	_draw_island(Vector3(39.0, 0.0, -29.0), Vector2(15.0, 12.0), 18, Color("626451"), Color("b4a274"))
	_draw_island(Vector3(-28.0, 0.0, 23.0), Vector2(20.0, 16.0), 22, Color("4e615a"), Color("87928a"))
	_draw_island(Vector3(-53.0, 0.0, -45.0), Vector2(20.0, 16.0), 26, Color("596856"), Color("a09270"))
	_draw_island(Vector3(92.0, 0.0, 86.0), Vector2(28.0, 22.0), 28, Color("555d54"), Color("98795e"))
	var font_color := Color("f0e6c5")
	_label_rects.clear()
	var occupied: Array[Rect2] = []
	for destination in destinations:
		occupied.append(Rect2(_world_to_map(destination.get("position", Vector3.ZERO)) - Vector2(12, 12), Vector2(24, 24)))
	occupied.append(Rect2(_world_to_map(player_position) - Vector2(12, 12), Vector2(24, 24)))
	for destination in destinations:
		var id := str(destination.get("id", ""))
		var map_point := _world_to_map(destination.get("position", Vector3.ZERO))
		var is_selected := id == selected_id
		var marker_color: Color = Color("e2c77f") if is_selected else _destination_risk_color(int(destination.get("risk", 0)))
		draw_circle(map_point + Vector2(0, 3), 10.0 if is_selected else 7.0, Color(0.0, 0.0, 0.0, 0.32))
		draw_circle(map_point, 9.0 if is_selected else 6.0, marker_color)
		if id == "home":
			draw_circle(map_point, 4.0, Color("d88556"))
		var label := str(destination.get("title", "地点"))
		var label_rect := _place_map_label(map_point, font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, MAP_LABEL_SIZE), occupied)
		_label_rects[id] = label_rect
		occupied.append(label_rect.grow(3.0))
		var leader_end := Vector2(clampf(map_point.x, label_rect.position.x, label_rect.end.x), clampf(map_point.y, label_rect.position.y, label_rect.end.y))
		draw_line(map_point, leader_end, Color("a8b9a0", 0.6), 1.0, true)
		draw_rect(label_rect.grow(2.0), Color("092b3a", 0.9))
		draw_string(font, label_rect.position + Vector2(0.0, font.get_ascent(MAP_LABEL_SIZE)), label, HORIZONTAL_ALIGNMENT_LEFT, -1, MAP_LABEL_SIZE, font_color)
	var player_point := _world_to_map(player_position)
	draw_circle(player_point, 6.0, Color("89dcce"))
	draw_arc(player_point, 10.0, 0.0, TAU, 24, Color("89dcce", 0.8), 2.0)
	draw_string(font, _map_rect.position + Vector2(8, _map_rect.size.y - 10.0), "N ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d9e6db"))
	# Last map layer: a thin outlined bow needle anchored at the real home point.
	# Extending its paint does not extend any original marker/label hitbox.
	var navigation := navigation_facts(destinations, selected_id)
	if bool(navigation.heading_valid):
		for destination in destinations:
			if str(destination.get("id", "")) == "home":
				var home_point := _world_to_map(destination.position)
				var arrow := heading_triangle(navigation.forward)
				for index in arrow.size(): arrow[index] += home_point
				var shaft_end: Vector2 = home_point + navigation.forward * 20.0
				draw_line(home_point, shaft_end, Color("09202a"), 4.0, true)
				draw_line(home_point, shaft_end, Color("fff4d2"), 2.0, true)
				draw_colored_polygon(arrow, Color("fff4d2"))
				draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[0]]), Color("09202a"), 2.0, true)
				break


func _place_map_label(point: Vector2, label_size: Vector2, occupied: Array[Rect2]) -> Rect2:
	var bounds := _map_rect.grow(-8.0)
	var candidate := Rect2(point + Vector2(14, -label_size.y - 4), label_size)
	for row in range(8):
		for offset in [Vector2(14, -label_size.y - 4 - row * 22), Vector2(-label_size.x - 14, -label_size.y - 4 - row * 22), Vector2(14, 14 + row * 22), Vector2(-label_size.x - 14, 14 + row * 22)]:
			candidate.position = point + offset
			candidate.position.x = clampf(candidate.position.x, bounds.position.x, bounds.end.x - label_size.x)
			candidate.position.y = clampf(candidate.position.y, bounds.position.y, bounds.end.y - label_size.y)
			var clear := true
			for other in occupied:
				if candidate.grow(3.0).intersects(other):
					clear = false
					break
			if clear:
				return candidate
	return candidate


func _draw_island(center: Vector3, extent: Vector2, vertex_count: int, fill: Color, shore: Color) -> void:
	var points := PackedVector2Array()
	for index in range(vertex_count):
		var angle := TAU * float(index) / float(vertex_count)
		var wobble := 0.86 + 0.12 * sin(float(index) * 2.31 + center.x)
		var world_point := Vector3(center.x + cos(angle) * extent.x * 0.5 * wobble, 0.0, center.z + sin(angle) * extent.y * 0.5 * wobble)
		points.append(_world_to_map(world_point))
	draw_colored_polygon(points, fill)
	draw_polyline(points, shore, 2.5, true)


func _draw_selected_details(font: Font, origin: Vector2) -> void:
	var selected: Dictionary = {}
	for destination in destinations:
		if str(destination.get("id", "")) == selected_id:
			selected = destination
			break
	if selected.is_empty():
		_draw_navigation_details(font, origin + Vector2(0, 8))
		return
	var x := origin.x
	var y := origin.y + 8.0
	_draw_detail_text(font, Vector2(x, y), str(selected.get("title", "地点")), 22, Color("f2dfae"), "title")
	y += 34.0
	var description := str(selected.get("description", ""))
	var available_width := maxf(1.0, _panel_rect.end.x - 24.0 - x)
	var line_height := maxf(DESCRIPTION_LINE_HEIGHT, ceilf(font.get_height(DESCRIPTION_SIZE)))
	for line in _description_lines(font, description, available_width):
		# Draw each complete line without a second clipping width.
		_draw_detail_text(font, Vector2(x, y), line, DESCRIPTION_SIZE, Color("d8e1d4"), "body")
		y += line_height
	y += 12.0
	_draw_detail_text(font, Vector2(x, y), _selected_distance_text(selected), 17, Color("d9c58f"), "distance")
	y += 38.0
	var risk := int(selected.get("risk", 0))
	var risk_text := "暂无明显风险" if risk == 0 else "环境风险参考 %d/5 · 无等级门槛" % risk
	_draw_detail_text(font, Vector2(x, y), risk_text, 14, _destination_risk_color(risk), "risk")
	_draw_navigation_details(font, Vector2(x, y + 28.0))


func _selected_distance_text(point: Dictionary) -> String:
	if _helm_origin:
		var view := navigation_facts(destinations, selected_id)
		match str(view.target_status):
			"bearing": return "距本舟 " + _distance_text(float(view.target_distance_m))
			"home": return "本舟当前位置"
			"coincident": return "与本舟同点"
			_: return "距本舟未知"
	var target: Vector3 = point.get("position", Vector3.ZERO)
	var delta := target - player_position
	return "约 %.0f 米 · %s" % [Vector2(delta.x, delta.z).length(), _direction_name(delta)]


static func _distance_text(distance: float) -> String:
	if not is_finite(distance) or distance <= 0.0: return "未知"
	return "不足1米" if distance < 1.0 else "约%.0f米" % distance


static func helm_text(view: Dictionary) -> String:
	var heading := "船首 %03d°" % (roundi(float(view.heading_degrees)) % 360) if bool(view.heading_valid) else "船首未知"
	match str(view.target_status):
		"bearing":
			var target := "%s %03d° · %s" % [str(view.target_title), roundi(float(view.target_degrees)) % 360, _distance_text(float(view.target_distance_m))]
			return target + "\n" + heading + " · 直线参考，请绕岸"
		"home": return "当前选点为本舟\n" + heading
		"coincident": return "目标与本舟同点\n" + heading
		_: return "目标未知\n" + heading


# Presentation only: no node mutation, event, persistence, input or route query.
static func navigation_facts(points: Array[Dictionary], selection: String) -> Dictionary:
	var view := {"heading_valid": false, "heading_degrees": 0.0, "forward": Vector2.ZERO, "target_status": "unknown", "target_degrees": 0.0, "target_title": "", "target_distance_m": 0.0}
	var home: Dictionary = {}
	var target: Dictionary = {}
	for point in points:
		if str(point.get("id", "")) == "home": home = point
		if str(point.get("id", "")) == selection: target = point
	if home.is_empty() or not bool(home.get("ship_present", false)):
		return view
	var origin: Variant = home.get("position")
	if not origin is Vector3 or not origin.is_finite(): return view
	var raw_forward: Variant = home.get("forward", Vector3.ZERO)
	if raw_forward is Vector3 and raw_forward.is_finite():
		var horizontal := Vector2(raw_forward.x, raw_forward.z)
		var length_squared := horizontal.length_squared()
		if is_finite(length_squared) and length_squared > 1e-12:
			var unit := horizontal.normalized()
			if unit.is_finite() and not unit.is_zero_approx():
				var degrees := fposmod(rad_to_deg(atan2(unit.x, -unit.y)), 360.0)
				if is_finite(degrees):
					view.heading_valid = true
					view.heading_degrees = degrees
					view.forward = unit
	if selection == "home":
		view.target_status = "home"
		return view
	var destination: Variant = target.get("position")
	if target.is_empty() or not origin is Vector3 or not destination is Vector3:
		return view
	if not origin.is_finite() or not destination.is_finite():
		return view
	var offset: Vector3 = destination - origin
	if not offset.is_finite(): return view
	var horizontal := Vector2(offset.x, offset.z)
	var length_squared := horizontal.length_squared()
	if not is_finite(length_squared): return view
	view.target_title = str(target.get("title", "所选地点"))
	if length_squared <= 1e-8:
		view.target_status = "coincident"
		return view
	var degrees := fposmod(rad_to_deg(atan2(horizontal.x, -horizontal.y)), 360.0)
	if is_finite(degrees):
		view.target_status = "bearing"
		view.target_degrees = degrees
		view.target_distance_m = sqrt(length_squared)
	return view


static func navigation_text(view: Dictionary) -> String:
	var heading := "船首%03d°" % (roundi(float(view.heading_degrees)) % 360) if bool(view.heading_valid) else "船首未知"
	match str(view.target_status):
		"bearing":
			return heading + "｜%s%03d°（本舟直线方位，需自行绕岸）" % [str(view.target_title), roundi(float(view.target_degrees)) % 360]
		"home": return heading + "｜当前选点为本舟"
		"coincident": return heading + "｜目标与本舟同点，方位未定义"
		_: return heading + "｜目标未知"


static func heading_triangle(unit: Vector2) -> PackedVector2Array:
	var side := Vector2(-unit.y, unit.x)
	return PackedVector2Array([unit * 26.0, unit * 18.0 + side * 4.0, unit * 18.0 - side * 4.0])


func _draw_navigation_details(font: Font, baseline: Vector2) -> void:
	var width := maxf(1.0, _panel_rect.end.x - 24.0 - baseline.x)
	var line_height := maxf(DESCRIPTION_LINE_HEIGHT, ceilf(font.get_height(DESCRIPTION_SIZE)))
	var y := baseline.y
	for line in _description_lines(font, navigation_text(navigation_facts(destinations, selected_id)), width):
		_draw_detail_text(font, Vector2(baseline.x, y), line, DESCRIPTION_SIZE, Color("89dcce"), "navigation")
		y += line_height


func _draw_detail_text(font: Font, baseline: Vector2, text: String, points: int, color: Color, role: String) -> void:
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, points, color)
	if _record_details_draw:
		var advance := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, points).x
		var cell := Rect2(baseline - Vector2(0, font.get_ascent(points)), Vector2(advance, font.get_height(points)))
		_details_draw_records.append({"role": role, "text": text, "baseline": baseline, "cell": cell, "font_size": points})


func _description_lines(font: Font, description: String, width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var available := maxf(1.0, width)
	for paragraph_text in description.split("\n"):
		if paragraph_text.is_empty() or _description_width(font, paragraph_text) <= available:
			lines.append(paragraph_text)
			continue
		var pending := ""
		for clause in _description_clauses(paragraph_text):
			if _description_width(font, pending + clause) <= available:
				pending += clause
				continue
			if not pending.is_empty():
				lines.append(pending)
				pending = ""
			if _description_width(font, clause) <= available:
				pending = clause
			else:
				# An overlong clause still uses the engine's legal word/CJK
				# breaks. Tiny viewports cannot guarantee the absence of tails.
				var fallback := _description_fallback_lines(font, clause, available)
				for index in range(fallback.size() - 1):
					lines.append(fallback[index])
				pending = fallback[-1] if not fallback.is_empty() else ""
		if not pending.is_empty():
			lines.append(pending)
	return lines


func _description_width(font: Font, text: String) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, DESCRIPTION_SIZE).x


func _description_clauses(text: String) -> PackedStringArray:
	var clauses := PackedStringArray()
	var current := ""
	var after_punctuation := false
	# Unicode extended graphemes keep combining marks with their character.
	# Consecutive sentence marks and following closing quotes stay together.
	for grapheme_match in _description_graphemes.search_all(text):
		var cluster := grapheme_match.get_string()
		var first := cluster.substr(0, 1)
		var sentence_mark := DESCRIPTION_BREAK_PUNCTUATION.contains(first)
		var closing_mark := DESCRIPTION_CLOSING_PUNCTUATION.contains(first)
		if after_punctuation and not sentence_mark and not closing_mark:
			clauses.append(current)
			current = ""
		current += cluster
		if sentence_mark:
			after_punctuation = true
		elif not closing_mark:
			after_punctuation = false
	if not current.is_empty():
		clauses.append(current)
	return clauses


func _description_fallback_lines(font: Font, text: String, width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var paragraph := TextParagraph.new()
	paragraph.width = width
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.add_string(text, font, DESCRIPTION_SIZE)
	for index in range(paragraph.get_line_count()):
		var span := paragraph.get_line_range(index)
		lines.append(text.substr(span.x, span.y - span.x))
	return lines


func _destination_risk_color(risk: int) -> Color:
	if risk >= 4:
		return Color("df766a")
	if risk >= 3:
		return Color("e29a72")
	if risk >= 2:
		return Color("dfcc9c")
	if risk == 1:
		return Color("b7d5c4")
	return Color("e4e3d0")


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var destination := _destination_at_position(event.position)
	if destination.is_empty():
		return
	var id := str(destination.get("id", ""))
	selected_id = id
	destination_selected.emit(id, str(destination.get("title", "地点")))
	queue_redraw()
	accept_event()


func _destination_at_position(position: Vector2) -> Dictionary:
	# Labels identify an explicit destination. Resolve all labels before dots;
	# if labels overlap, the last drawn (visually topmost) label owns the click.
	for index in range(destinations.size() - 1, -1, -1):
		var destination: Dictionary = destinations[index]
		var id := str(destination.get("id", ""))
		if _label_rects.has(id) and (_label_rects[id] as Rect2).has_point(position):
			return destination
	# Keep the original 15px target, but choose its genuinely nearest centre.
	# Reverse draw order breaks exact ties only; no epsilon can steal a centre.
	var nearest: Dictionary = {}
	var nearest_distance_squared := INF
	for index in range(destinations.size() - 1, -1, -1):
		var destination: Dictionary = destinations[index]
		var distance_squared := position.distance_squared_to(_world_to_map(destination.get("position", Vector3.ZERO)))
		if distance_squared <= 15.0 * 15.0 and distance_squared < nearest_distance_squared:
			nearest = destination
			nearest_distance_squared = distance_squared
	return nearest


func _world_to_map(world_position: Vector3) -> Vector2:
	var normalized := Vector2(world_position.x, world_position.z) / (WORLD_HALF_EXTENT * 2.0) + Vector2(0.5, 0.5)
	return _map_rect.position + Vector2(normalized.x * _map_rect.size.x, normalized.y * _map_rect.size.y)


func _direction_name(delta: Vector3) -> String:
	if Vector2(delta.x, delta.z).length() < 0.5:
		return "就在这里"
	var horizontal := "东" if delta.x > 0.5 else "西" if delta.x < -0.5 else ""
	var vertical := "南" if delta.z > 0.5 else "北" if delta.z < -0.5 else ""
	return vertical + horizontal if not vertical.is_empty() else horizontal
