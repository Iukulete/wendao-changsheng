extends Control

signal node_selected(node_id: String)

const MAP_SIZE := Vector2(900.0, 470.0)
const LAND_NODES := {
	"main": [Vector2(0.12, 0.48), Vector2(0.17, 0.30), Vector2(0.31, 0.19), Vector2(0.49, 0.21), Vector2(0.66, 0.30), Vector2(0.78, 0.48), Vector2(0.72, 0.68), Vector2(0.57, 0.80), Vector2(0.36, 0.81), Vector2(0.18, 0.70)],
	"reef": [Vector2(0.11, 0.78), Vector2(0.19, 0.73), Vector2(0.27, 0.81), Vector2(0.22, 0.92), Vector2(0.13, 0.91)],
	"beacon": [Vector2(0.82, 0.34), Vector2(0.91, 0.30), Vector2(0.98, 0.40), Vector2(0.94, 0.53), Vector2(0.84, 0.50)],
}

var map_nodes: Array = []
var selected_id := "beach"
var current_day := 1
var sea_time := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(620, 350)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_map(nodes: Array, selection: String, day: int) -> void:
	map_nodes = nodes.duplicate(true)
	selected_id = selection
	current_day = day
	queue_redraw()


func _process(delta: float) -> void:
	sea_time += delta
	queue_redraw()


func _draw() -> void:
	var size := get_size()
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var sx := size.x / MAP_SIZE.x
	var sy := size.y / MAP_SIZE.y
	var scale_point := func(point: Vector2) -> Vector2: return Vector2(point.x * MAP_SIZE.x * sx, point.y * MAP_SIZE.y * sy)
	var font := ThemeDB.fallback_font
	var sea := Color("092b3a")
	draw_rect(Rect2(Vector2.ZERO, size), sea, true)
	for index in range(13):
		var y := fposmod(float(index) * 41.0 + sea_time * (5.0 + float(index % 3)), size.y)
		var x := float((index * 83) % 800) * sx
		draw_line(Vector2(x, y), Vector2(x + (54.0 + float(index % 4) * 12.0) * sx, y), Color(0.48, 0.78, 0.77, 0.08), 1.5)
	var main_land := PackedVector2Array()
	for point in LAND_NODES.main:
		main_land.append(scale_point.call(point))
	draw_colored_polygon(main_land, Color("55584a"))
	draw_polyline(main_land, Color("d0b879"), 5.0, true)
	var inner_land := PackedVector2Array()
	for point in LAND_NODES.main:
		var shifted: Vector2 = Vector2(0.45, 0.49) + (point - Vector2(0.45, 0.49)) * 0.82
		inner_land.append(scale_point.call(shifted))
	draw_colored_polygon(inner_land, Color("385c4c"))
	for key in ["reef", "beacon"]:
		var island := PackedVector2Array()
		for point in LAND_NODES[key]:
			island.append(scale_point.call(point))
		draw_colored_polygon(island, Color("484c42"))
		draw_polyline(island, Color("c6ae77"), 4.0, true)
	var by_id: Dictionary = {}
	for node_value in map_nodes:
		var node: Dictionary = node_value
		by_id[str(node.get("id", ""))] = node
	for node_value in map_nodes:
		var node: Dictionary = node_value
		if not bool(node.get("revealed", false)):
			continue
		for neighbor_id in node.get("neighbors", []):
			var other: Dictionary = by_id.get(str(neighbor_id), {})
			if other.is_empty() or not bool(other.get("revealed", false)) or str(other.id) < str(node.id):
				continue
			var from: Vector2 = scale_point.call(Vector2(float(node.x), float(node.y)))
			var to: Vector2 = scale_point.call(Vector2(float(other.x), float(other.y)))
			draw_dashed_line(from, to, Color("f1d58e", 0.46), 2.0, 8.0)
	for node_value in map_nodes:
		var node: Dictionary = node_value
		var point: Vector2 = scale_point.call(Vector2(float(node.get("x", 0.5)), float(node.get("y", 0.5))))
		if not bool(node.get("revealed", false)):
			draw_circle(point, 16.0, Color("a2bdba", 0.34))
			draw_string(font, point + Vector2(-5.0, 6.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("edf4e9", 0.82))
			continue
		var is_camp := str(node.get("id", "")) == "camp"
		var is_selected := str(node.get("id", "")) == selected_id
		var radius := 20.0 if is_camp else 16.0
		draw_circle(point + Vector2(0, 4), radius + (4.0 if is_selected else 0.0), Color(0, 0, 0, 0.27))
		draw_circle(point, radius + (4.0 if is_selected else 0.0), Color("e5c776") if is_selected else Color("d7e1ca"))
		draw_circle(point, radius - 4.0, _node_color(node))
		var symbol := _node_symbol(node)
		draw_string(font, point + Vector2(-7.0, 6.0), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("fff5da"))
		var label := str(node.get("name", "地点"))
		var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, point + Vector2(-text_width * 0.5, radius + 22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f0e8d1"))
	draw_string(font, Vector2(18, 30), "灵潮海 · 第 %d 日" % current_day, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("d9e6db"))
	draw_string(font, Vector2(18, size.y - 17), "点击地图上的地点查看探索行动" , HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d9e6db", 0.72))


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var point: Vector2 = event.position
	var scale := Vector2(get_size().x / MAP_SIZE.x, get_size().y / MAP_SIZE.y)
	var best_id := ""
	var best_distance := 35.0
	for node_value in map_nodes:
		var node: Dictionary = node_value
		if not bool(node.get("revealed", false)):
			continue
		var position: Vector2 = Vector2(float(node.x) * MAP_SIZE.x * scale.x, float(node.y) * MAP_SIZE.y * scale.y)
		var distance: float = point.distance_to(position)
		if distance < best_distance:
			best_distance = distance
			best_id = str(node.id)
	if not best_id.is_empty():
		node_selected.emit(best_id)
		accept_event()


func _node_color(node: Dictionary) -> Color:
	match str(node.get("kind", "")):
		"camp": return Color("b18353")
		"grove": return Color("4b9372")
		"shelter": return Color("8c7960")
		"ruins": return Color("778894")
		"cave": return Color("755d86")
		"reef": return Color("538c96")
		"beacon": return Color("c4934a")
	return Color("c3995e")


func _node_symbol(node: Dictionary) -> String:
	if not bool(node.get("explored", false)):
		return "…"
	match str(node.get("kind", "")):
		"camp": return "营"
		"beach": return "木"
		"grove": return "草"
		"shelter": return "人"
		"ruins": return "矿"
		"cave": return "晶"
		"reef": return "潮"
		"beacon": return "灯"
	return "·"
