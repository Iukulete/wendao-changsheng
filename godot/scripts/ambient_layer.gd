extends Control

var mode: String = "motes"
var accent: Color = Color(0.9, 0.74, 0.3, 1.0)
var elapsed: float = 0.0
var particles: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_particles()
	set_process(true)


func configure(next_mode: String, next_accent: Color) -> void:
	mode = next_mode
	accent = next_accent
	_build_particles()
	queue_redraw()


func _build_particles() -> void:
	particles.clear()
	var count := 44 if mode in ["rain", "embers"] else 34
	for index in range(count):
		var seed := float((index * 97 + 31) % 997) / 997.0
		particles.append({
			"x": fmod(seed * 1.731 + float(index % 5) * 0.127, 1.0),
			"y": fmod(seed * 2.417 + float(index % 7) * 0.083, 1.0),
			"speed": 0.018 + float((index * 13) % 17) * 0.0019,
			"size": 1.1 + float(index % 5) * 0.58,
			"phase": seed * TAU,
			"alpha": 0.16 + float(index % 6) * 0.045,
		})


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	for particle in particles:
		var speed: float = particle.speed
		var phase: float = particle.phase
		var px: float = particle.x
		var py: float = particle.y
		var alpha: float = particle.alpha
		var radius: float = particle.size
		if mode == "rain":
			var rain_y := fposmod(py + elapsed * speed * 3.7, 1.12) - 0.06
			var rain_x := fposmod(px + elapsed * 0.008 + sin(elapsed * 0.31 + phase) * 0.008, 1.0)
			var start := Vector2(rain_x * size.x, rain_y * size.y)
			draw_line(start, start + Vector2(-5.0, 22.0), Color(accent, alpha), 1.15, true)
		elif mode == "embers":
			var ember_y := 1.06 - fposmod(1.0 - py + elapsed * speed * 1.8, 1.12)
			var ember_x := fposmod(px + sin(elapsed * 0.9 + phase) * 0.018, 1.0)
			var ember_pos := Vector2(ember_x * size.x, ember_y * size.y)
			draw_circle(ember_pos, radius, Color(accent, alpha * 1.2))
			draw_circle(ember_pos, radius * 3.1, Color(accent, alpha * 0.12))
		else:
			var mote_y := 1.04 - fposmod(1.0 - py + elapsed * speed, 1.09)
			var mote_x := fposmod(px + sin(elapsed * 0.55 + phase) * 0.012, 1.0)
			var mote_pos := Vector2(mote_x * size.x, mote_y * size.y)
			var shimmer := 0.72 + sin(elapsed * 1.7 + phase) * 0.28
			draw_circle(mote_pos, radius, Color(accent, alpha * shimmer))
			if int(radius) % 2 == 0:
				draw_circle(mote_pos, radius * 3.6, Color(accent, alpha * 0.075))
