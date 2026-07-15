extends Control

const ELEMENT_COLORS: Array[Color] = [
	Color("e26f52"),
	Color("55a9d6"),
	Color("65bd83"),
	Color("d7d1c1"),
	Color("c9a15f"),
]

var roots: Array[int] = [6, 6, 6, 6, 6]
var karma: int = 0
var dao_heart: int = 0
var accent: Color = Color("e4be4c")
var elapsed: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func set_stats(next_roots: Array, next_karma: int, next_dao_heart: int, next_accent: Color) -> void:
	roots.clear()
	for value in next_roots:
		roots.append(int(value))
	while roots.size() < 5:
		roots.append(1)
	karma = next_karma
	dao_heart = next_dao_heart
	accent = next_accent
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.37
	if radius < 18.0:
		return
	var pulse: float = 0.5 + sin(elapsed * 1.45) * 0.5
	for ring in range(4):
		var ring_radius: float = radius * (0.42 + float(ring) * 0.19)
		var ring_alpha: float = 0.10 + float(ring) * 0.025
		draw_arc(center, ring_radius, 0.0, TAU, 96, Color(accent, ring_alpha), 1.0, true)

	var polygon := PackedVector2Array()
	for index in range(5):
		var angle: float = -PI * 0.5 + float(index) * TAU / 5.0
		var normalized: float = clampf(float(roots[index]) / 10.0, 0.15, 1.0)
		var point: Vector2 = center + Vector2.from_angle(angle) * radius * normalized
		polygon.append(point)
		var outer: Vector2 = center + Vector2.from_angle(angle) * radius
		draw_line(center, outer, Color(accent, 0.10), 1.0, true)
		draw_circle(outer, 5.0 + pulse * 1.4, Color(ELEMENT_COLORS[index], 0.90))
		draw_circle(outer, 13.0 + pulse * 4.0, Color(ELEMENT_COLORS[index], 0.07))
	if polygon.size() == 5:
		var fill_colors := PackedColorArray()
		for _index in range(5):
			fill_colors.append(Color(accent, 0.13))
		draw_polygon(polygon, fill_colors)
		for index in range(5):
			draw_line(polygon[index], polygon[(index + 1) % 5], Color(accent, 0.82), 2.0, true)

	var core_radius: float = 11.0 + clampf(float(absi(karma) + dao_heart) / 120.0, 0.0, 1.0) * 8.0
	draw_circle(center, core_radius + pulse * 2.5, Color(accent, 0.24))
	draw_circle(center, core_radius * 0.55, Color(0.92, 0.96, 0.91, 0.86))
	draw_arc(center, radius * 0.88, elapsed * 0.19, elapsed * 0.19 + PI * 1.25,
		72, Color(accent, 0.62), 2.2, true)
