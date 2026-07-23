extends Control

# A compact, readable tactical stage for the dungeon combat surface. It is
# code-drawn so a missing portrait never collapses combat into an empty panel.

var run: Dictionary = {}
var battle: Dictionary = {}
var accent := Color("e4be4c")
var enemy_color := Color("cc6d63")
var elapsed := 0.0
var seed_value := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size = Vector2(260, 132)
	set_process(true)


func configure(next_run: Dictionary, next_battle: Dictionary, next_accent: Color) -> void:
	run = next_run.duplicate(true)
	battle = next_battle.duplicate(true)
	accent = next_accent
	var rank := str(battle.get("rank", "combat"))
	enemy_color = Color("e45f61") if rank == "boss" else (Color("d58463") if rank == "elite" else Color("bd746b"))
	seed_value = absi(hash("%s:%s:%s" % [battle.get("enemy_name", "enemy"),
		battle.get("turn", 1), battle.get("intent", "strike")]))
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	if size.x < 180.0 or size.y < 90.0:
		return
	var scale_value := clampf(minf(size.x / 540.0, size.y / 214.0), 0.68, 1.32)
	var ground_y := size.y * 0.79
	var player_position := Vector2(size.x * 0.25, ground_y)
	var enemy_position := Vector2(size.x * 0.75, ground_y)
	_draw_background(scale_value, ground_y)
	_draw_intent_lane(player_position, enemy_position, scale_value)
	_draw_presence(player_position, accent, false, scale_value)
	_draw_presence(enemy_position, enemy_color, true, scale_value)
	_draw_player(player_position, scale_value)
	_draw_enemy(enemy_position, scale_value)
	_draw_phase_mark(enemy_position, scale_value)


func _draw_background(scale_value: float, ground_y: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.008, 0.018, 0.027, 0.97), true)
	for band_index in range(7):
		var y := size.y * float(band_index) / 7.0
		var alpha := 0.10 - float(band_index) * 0.008
		draw_rect(Rect2(0, y, size.x, size.y / 7.0 + 1.0),
			Color(0.06, 0.12, 0.14, alpha), true)
	var moon := Vector2(size.x * 0.78, size.y * 0.20)
	draw_circle(moon, 24.0 * scale_value, Color(0.86, 0.79, 0.58, 0.08))
	draw_circle(moon, 14.0 * scale_value, Color(0.93, 0.86, 0.66, 0.10))
	for ring in range(3):
		var radius := (26.0 + ring * 13.0) * scale_value
		draw_arc(Vector2(size.x * 0.5, size.y * 0.47), radius,
			-PI * 0.14, PI * 1.14, 32, Color(accent, 0.055 - ring * 0.012), 1.0, true)
	var horizon := size.y * 0.55
	draw_line(Vector2(size.x * 0.06, horizon), Vector2(size.x * 0.94, horizon),
		Color(accent, 0.12), 1.0, true)
	var platform := _ellipse_points(Vector2(size.x * 0.5, ground_y + 8.0 * scale_value),
		Vector2(size.x * 0.39, 15.0 * scale_value), 32)
	draw_colored_polygon(platform, Color(0.015, 0.035, 0.041, 0.92))
	draw_polyline(platform, Color(accent, 0.24), 1.2, true)
	for index in range(5):
		var x := size.x * (0.18 + float(index) * 0.16)
		draw_line(Vector2(x, ground_y + 11.0 * scale_value),
			Vector2(x + 18.0 * scale_value, ground_y + 17.0 * scale_value),
			Color(0.44, 0.58, 0.58, 0.16), 1.0, true)
	# A thin frame keeps the stage legible against any era backdrop.
	draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), Color(accent, 0.18), false, 1.0)


func _draw_intent_lane(player_position: Vector2, enemy_position: Vector2, scale_value: float) -> void:
	var intent := str(battle.get("intent", "strike"))
	var lane_start := enemy_position + Vector2(-28.0, -58.0) * scale_value
	var lane_end := player_position + Vector2(28.0, -58.0) * scale_value
	var direction := (lane_end - lane_start).normalized()
	var lane_color := Color("e88670") if intent not in ["guard", "fortify"] else Color("d7b866")
	var pulse := 0.35 + (sin(elapsed * 2.1) + 1.0) * 0.13
	for index in range(7):
		var t := (float(index) + 0.25) / 7.0
		var point := lane_start.lerp(lane_end, t)
		draw_circle(point, (2.0 + float(index % 2)) * scale_value, Color(lane_color, pulse))
	draw_line(lane_start, lane_end, Color(lane_color, 0.16), 1.0 * scale_value, true)
	var head := lane_end
	var normal := Vector2(-direction.y, direction.x)
	draw_colored_polygon(PackedVector2Array([
		head,
		head - direction * 13.0 * scale_value + normal * 7.0 * scale_value,
		head - direction * 13.0 * scale_value - normal * 7.0 * scale_value,
	]), Color(lane_color, 0.75))
	if intent in ["guard", "fortify"]:
		var shield_center := enemy_position + Vector2(-18.0, -54.0) * scale_value
		draw_arc(shield_center, 18.0 * scale_value, -PI * 0.72, PI * 0.72,
			24, Color(lane_color, 0.70), 2.0 * scale_value, true)


func _draw_presence(center: Vector2, color: Color, enemy_side: bool, scale_value: float) -> void:
	var bob := sin(elapsed * 1.45 + (0.8 if enemy_side else 0.0)) * 1.4 * scale_value
	var foot := center + Vector2(0, 4.0 * scale_value)
	var shadow := _ellipse_points(foot, Vector2(48.0, 8.0) * scale_value, 24)
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.55))
	draw_arc(foot, 42.0 * scale_value, PI * 0.08, PI * 0.92,
		20, Color(color, 0.64), 2.0 * scale_value, true)
	var aura_center := center + Vector2(0, -45.0 * scale_value + bob)
	draw_arc(aura_center, 35.0 * scale_value, -PI * 0.8, PI * 0.8,
		26, Color(color, 0.22), 1.0 * scale_value, true)


func _draw_player(root: Vector2, scale_value: float) -> void:
	var bob := sin(elapsed * 1.45) * 1.4 * scale_value
	var p := root + Vector2(0, bob)
	var robe := Color("477f9e")
	var robe_light := Color("8cc0c2")
	var skin := Color("e4c09b")
	var dark := Color("1b3047")
	# Broad silhouette, shoulder-to-foot height is intentionally large on both layouts.
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-19, -59) * scale_value,
		p + Vector2(17, -59) * scale_value,
		p + Vector2(25, -18) * scale_value,
		p + Vector2(15, 2) * scale_value,
		p + Vector2(-17, 2) * scale_value,
		p + Vector2(-26, -18) * scale_value,
	]), robe)
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-17, -56) * scale_value,
		p + Vector2(4, -56) * scale_value,
		p + Vector2(0, -8) * scale_value,
		p + Vector2(-12, -8) * scale_value,
	]), robe_light)
	draw_circle(p + Vector2(0, -73) * scale_value, 13.0 * scale_value, skin)
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-16, -77) * scale_value,
		p + Vector2(0, -91) * scale_value,
		p + Vector2(17, -77) * scale_value,
		p + Vector2(10, -69) * scale_value,
		p + Vector2(-12, -69) * scale_value,
	]), dark)
	draw_line(p + Vector2(-22, -50) * scale_value, p + Vector2(-37, -29) * scale_value,
		Color(robe_light, 0.92), 7.0 * scale_value, true)
	draw_line(p + Vector2(20, -50) * scale_value, p + Vector2(37, -29) * scale_value,
		Color(robe_light, 0.92), 7.0 * scale_value, true)
	draw_line(p + Vector2(-8, 1) * scale_value, p + Vector2(-12, 22) * scale_value,
		Color(dark, 0.96), 8.0 * scale_value, true)
	draw_line(p + Vector2(8, 1) * scale_value, p + Vector2(12, 22) * scale_value,
		Color(dark, 0.96), 8.0 * scale_value, true)
	# A held blade ties the silhouette to the action lane.
	draw_line(p + Vector2(29, -30) * scale_value, p + Vector2(56, -66) * scale_value,
		Color("d9c889"), 3.0 * scale_value, true)
	draw_line(p + Vector2(29, -30) * scale_value, p + Vector2(42, -17) * scale_value,
		Color("6d483e"), 5.0 * scale_value, true)


func _draw_enemy(root: Vector2, scale_value: float) -> void:
	var rank := str(battle.get("rank", "combat"))
	var bob := sin(elapsed * 1.23 + 0.9) * 1.8 * scale_value
	var p := root + Vector2(0, bob)
	var body := enemy_color
	var body_light := Color("e7a071") if rank != "boss" else Color("efbd72")
	var dark := Color("321d35")
	var torso_width := 24.0 if rank == "combat" else (31.0 if rank == "elite" else 39.0)
	var torso_height := 45.0 if rank == "combat" else (53.0 if rank == "elite" else 62.0)
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-torso_width, -torso_height) * scale_value,
		p + Vector2(torso_width, -torso_height) * scale_value,
		p + Vector2(torso_width + 9.0, -8) * scale_value,
		p + Vector2(-torso_width - 9.0, -8) * scale_value,
	]), body)
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-torso_width * 0.68, -torso_height + 7) * scale_value,
		p + Vector2(3, -torso_height + 7) * scale_value,
		p + Vector2(-4, -18) * scale_value,
		p + Vector2(-torso_width * 0.42, -18) * scale_value,
	]), body_light)
	var head_radius := 15.0 if rank == "combat" else (19.0 if rank == "elite" else 23.0)
	draw_circle(p + Vector2(0, -torso_height - head_radius + 5) * scale_value,
		head_radius * scale_value, dark)
	if rank == "boss":
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(-22, -torso_height - 8) * scale_value,
			p + Vector2(-10, -torso_height - 34) * scale_value,
			p + Vector2(-2, -torso_height - 13) * scale_value,
			p + Vector2(11, -torso_height - 36) * scale_value,
			p + Vector2(21, -torso_height - 8) * scale_value,
		]), body_light)
	elif rank == "elite":
		draw_line(p + Vector2(-17, -torso_height - 14) * scale_value,
			p + Vector2(-29, -torso_height - 31) * scale_value, body_light, 4.0 * scale_value, true)
		draw_line(p + Vector2(17, -torso_height - 14) * scale_value,
			p + Vector2(29, -torso_height - 31) * scale_value, body_light, 4.0 * scale_value, true)
	draw_line(p + Vector2(-torso_width - 3, -torso_height + 10) * scale_value,
		p + Vector2(-torso_width - 25, -torso_height + 28) * scale_value,
		Color(body_light, 0.92), 8.0 * scale_value, true)
	draw_line(p + Vector2(torso_width + 3, -torso_height + 10) * scale_value,
		p + Vector2(torso_width + 25, -torso_height + 28) * scale_value,
		Color(body_light, 0.92), 8.0 * scale_value, true)
	draw_line(p + Vector2(-12, -8) * scale_value, p + Vector2(-16, 18) * scale_value,
		Color(dark, 0.98), 9.0 * scale_value, true)
	draw_line(p + Vector2(12, -8) * scale_value, p + Vector2(16, 18) * scale_value,
		Color(dark, 0.98), 9.0 * scale_value, true)
	# Weapon silhouette varies with rank so the stage communicates threat before text is read.
	var weapon_color := Color("d8c37d") if rank != "boss" else Color("f0df9e")
	draw_line(p + Vector2(-31, -torso_height + 18) * scale_value,
		p + Vector2(-62, -torso_height - 20) * scale_value,
		weapon_color, 3.0 * scale_value, true)
	if rank == "boss":
		draw_arc(p + Vector2(0, -torso_height - 20) * scale_value, 26.0 * scale_value,
			PI * 0.12, PI * 0.88, 24, Color(weapon_color, 0.65), 2.0 * scale_value, true)


func _draw_phase_mark(center: Vector2, scale_value: float) -> void:
	if not bool(battle.get("phase_active", false)) and not bool(battle.get("phase_shift_pending", false)):
		return
	var phase_color := Color("ed765f") if bool(battle.get("phase_active", false)) else Color("d6b269")
	var pulse := 0.45 + sin(elapsed * 2.0) * 0.12
	for ring in range(2):
		draw_arc(center + Vector2(0, -62.0) * scale_value,
			(50.0 + ring * 10.0) * scale_value, -PI * 0.88, PI * 0.88, 28,
			Color(phase_color, pulse - ring * 0.13), 2.0 * scale_value, true)


func _ellipse_points(center: Vector2, radius: Vector2, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(count):
		var angle := TAU * float(index) / float(count)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
