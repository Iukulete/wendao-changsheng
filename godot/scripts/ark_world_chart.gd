extends Control

signal destination_selected(destination_id: String, title: String)

const WORLD_HALF_EXTENT := 140.0
const PANEL_SIZE := Vector2(960.0, 620.0)
const STATUS_RESERVE := 96.0
const MAP_LABEL_SIZE := 15
const UI_FONT = preload("res://art/fonts/ark_ui_font.tres")

var player_position := Vector3.ZERO
var destinations: Array[Dictionary] = []
var selected_id := "home"
var _panel_rect := Rect2()
var _map_rect := Rect2()
var _label_rects: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func refresh(position: Vector3, points: Array[Dictionary], selection: String = "") -> void:
	player_position = position
	destinations = points.duplicate(true)
	if not selection.is_empty():
		selected_id = selection
	queue_redraw()


func _draw() -> void:
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
	draw_string(font, Vector2(left, _panel_rect.end.y - 22.0), "点击地点查看方向与距离　·　M 或 Esc 收起", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d3d8c5", 0.8))


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
		return
	var x := origin.x
	var y := origin.y + 8.0
	draw_string(font, Vector2(x, y), str(selected.get("title", "地点")), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("f2dfae"))
	y += 34.0
	var description := str(selected.get("description", ""))
	for line in description.split("\n"):
		draw_string(font, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, 250.0, 15, Color("d8e1d4"))
		y += 24.0
	y += 12.0
	var target: Vector3 = selected.get("position", Vector3.ZERO)
	var delta := target - player_position
	var distance := Vector2(delta.x, delta.z).length()
	draw_string(font, Vector2(x, y), "约 %.0f 米 · %s" % [distance, _direction_name(delta)], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("d9c58f"))
	y += 38.0
	var risk := int(selected.get("risk", 0))
	var risk_text := "暂无明显风险" if risk == 0 else "环境风险参考 %d/5 · 无等级门槛" % risk
	draw_string(font, Vector2(x, y), risk_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, _destination_risk_color(risk))


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
	for destination in destinations:
		var id := str(destination.get("id", ""))
		if event.position.distance_to(_world_to_map(destination.get("position", Vector3.ZERO))) <= 15.0 or (_label_rects.has(id) and (_label_rects[id] as Rect2).has_point(event.position)):
			selected_id = id
			destination_selected.emit(id, str(destination.get("title", "地点")))
			queue_redraw()
			accept_event()
			return


func _world_to_map(world_position: Vector3) -> Vector2:
	var normalized := Vector2(world_position.x, world_position.z) / (WORLD_HALF_EXTENT * 2.0) + Vector2(0.5, 0.5)
	return _map_rect.position + Vector2(normalized.x * _map_rect.size.x, normalized.y * _map_rect.size.y)


func _direction_name(delta: Vector3) -> String:
	if Vector2(delta.x, delta.z).length() < 0.5:
		return "就在这里"
	var horizontal := "东" if delta.x > 0.5 else "西" if delta.x < -0.5 else ""
	var vertical := "南" if delta.z > 0.5 else "北" if delta.z < -0.5 else ""
	return vertical + horizontal if not vertical.is_empty() else horizontal
