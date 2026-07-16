class_name CombatStage
extends Control

var battle: Dictionary = {}
var accent := Color("e4be4c")
var enemy_color := Color("e36f62")
var elapsed := 0.0
var motes: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size.y = 210
	set_process(true)


func configure(next_battle: Dictionary, next_accent: Color) -> void:
	battle = next_battle.duplicate(true)
	accent = next_accent
	_build_motes()
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _build_motes() -> void:
	motes.clear()
	var seed_value := absi(hash(str(battle.get("enemy_id", "enemy"))))
	for index in range(20):
		motes.append({
			"x": float((seed_value + index * 83) % 997) / 997.0,
			"y": float((seed_value / 7 + index * 137) % 991) / 991.0,
			"speed": 0.025 + float(index % 6) * 0.006,
			"phase": float(index) * 0.71,
			"radius": 1.1 + float(index % 4) * 0.55,
		})


func _draw() -> void:
	if size.x < 240.0 or size.y < 120.0 or battle.is_empty():
		return
	_draw_arena()
	var player_position := Vector2(size.x * 0.24, size.y * 0.61)
	var enemy_position := Vector2(size.x * 0.76, size.y * 0.47)
	var player_ratio := _ratio("player_hp", "player_max_hp")
	var enemy_ratio := _ratio("enemy_hp", "enemy_max_hp")
	var pulse := 1.0 + sin(elapsed * 2.1) * 0.035
	_draw_aura(player_position, 54.0 * pulse, accent, player_ratio,
		battle.get("player_statuses", {}))
	_draw_aura(enemy_position, 58.0 / pulse, enemy_color, enemy_ratio,
		battle.get("enemy_statuses", {}))
	_draw_player(player_position, accent)
	_draw_enemy(enemy_position, enemy_color)
	_draw_intent(enemy_position, player_position)
	_draw_clash_line(player_position, enemy_position)


func _draw_arena() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.025, 0.04, 0.58), true)
	for index in range(6):
		var y := size.y * (0.18 + float(index) * 0.11)
		draw_line(Vector2(size.x * 0.06, y), Vector2(size.x * 0.94, y),
			Color(accent, 0.025 + float(index % 2) * 0.012), 1.0)
	var horizon_y := size.y * 0.79
	draw_line(Vector2(size.x * 0.04, horizon_y), Vector2(size.x * 0.96, horizon_y),
		Color(accent, 0.22), 1.2, true)
	for mote in motes:
		var px := fposmod(float(mote.x) + elapsed * float(mote.speed), 1.0)
		var py := float(mote.y) + sin(elapsed * 0.8 + float(mote.phase)) * 0.025
		var position := Vector2(px * size.x, py * size.y)
		var glow := 0.45 + sin(elapsed * 1.6 + float(mote.phase)) * 0.25
		draw_circle(position, float(mote.radius), Color(accent, 0.12 * glow))


func _draw_aura(center: Vector2, radius: float, color: Color, health_ratio: float,
		statuses_value: Variant) -> void:
	var statuses: Dictionary = statuses_value if statuses_value is Dictionary else {}
	draw_circle(center, radius * 1.18, Color(color, 0.035))
	draw_arc(center, radius, -PI * 0.5, PI * 1.5, 72, Color(color, 0.18), 2.0, true)
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * health_ratio, 72,
		Color(color, 0.92), 4.0, true)
	draw_arc(center, radius * 0.78, elapsed * 0.18, elapsed * 0.18 + PI * 1.35,
		48, Color(color, 0.28), 1.2, true)
	if int(statuses.get("shield", 0)) > 0:
		draw_arc(center, radius * 1.3, PI * 0.92, PI * 2.08, 40,
			Color("76c9ed"), 5.0, true)
	if int(statuses.get("bleed", 0)) > 0:
		for offset in [-15.0, 0.0, 15.0]:
			draw_line(center + Vector2(offset, radius * 0.84),
				center + Vector2(offset - 4.0, radius * 1.10), Color("df4f58"), 2.0, true)
	if int(statuses.get("weak", 0)) > 0:
		draw_arc(center, radius * 1.42, 0.0, TAU, 32, Color("9a79c9"), 2.0, true)


func _draw_player(position: Vector2, color: Color) -> void:
	draw_circle(position + Vector2(0, -30), 10.0, Color("e9dfcd"))
	var robe := PackedVector2Array([
		position + Vector2(0, -19), position + Vector2(-20, 28),
		position + Vector2(19, 28),
	])
	draw_colored_polygon(robe, Color(color.darkened(0.42), 0.96))
	draw_polyline(PackedVector2Array([
		position + Vector2(-23, 4), position + Vector2(5, -7),
		position + Vector2(31, -31),
	]), Color("f5ecd6"), 3.2, true)
	draw_line(position + Vector2(30, -32), position + Vector2(43, -45),
		Color(color.lightened(0.25), 0.92), 2.0, true)


func _draw_enemy(position: Vector2, color: Color) -> void:
	var head := PackedVector2Array([
		position + Vector2(0, -43), position + Vector2(11, -31),
		position + Vector2(0, -19), position + Vector2(-11, -31),
	])
	draw_colored_polygon(head, Color(color.lightened(0.12), 0.96))
	var body := PackedVector2Array([
		position + Vector2(0, -20), position + Vector2(25, 30),
		position + Vector2(0, 21), position + Vector2(-25, 30),
	])
	draw_colored_polygon(body, Color(color.darkened(0.48), 0.98))
	draw_polyline(PackedVector2Array([
		position + Vector2(-29, -25), position + Vector2(-5, -4),
		position + Vector2(23, 4),
	]), Color(color.lightened(0.34), 0.95), 3.2, true)


func _draw_intent(enemy_position: Vector2, player_position: Vector2) -> void:
	var intent := str(battle.get("intent", "strike"))
	var progress := 0.55 + sin(elapsed * 3.0) * 0.16
	if intent == "guard":
		for offset in range(3):
			draw_arc(enemy_position, 72.0 + float(offset) * 7.0, PI * 0.72, PI * 2.28,
				36, Color("72b7dc", 0.38 - float(offset) * 0.08), 3.0, true)
		return
	if intent == "weaken":
		for index in range(3):
			var angle := elapsed * 0.7 + float(index) * TAU / 3.0
			var orb := enemy_position + Vector2(cos(angle), sin(angle)) * 76.0
			draw_circle(orb, 4.5, Color("a779d4", 0.72))
			draw_line(orb, player_position, Color("a779d4", 0.09), 1.0, true)
		return
	var intent_color := Color("f1a259")
	var width := 2.5
	if intent == "heavy":
		intent_color = Color("f06458")
		width = 6.0
	elif intent == "bleed":
		intent_color = Color("d94b64")
	var direction := (player_position - enemy_position).normalized()
	var normal := Vector2(-direction.y, direction.x)
	for offset in [-12.0, 0.0, 12.0]:
		var start: Vector2 = enemy_position + direction * 62.0 + normal * offset
		var end: Vector2 = start.lerp(player_position - direction * 62.0, progress)
		draw_line(start, end, Color(intent_color, 0.58), width, true)


func _draw_clash_line(player_position: Vector2, enemy_position: Vector2) -> void:
	var midpoint := player_position.lerp(enemy_position, 0.5)
	var energy := 0.32 + sin(elapsed * 2.4) * 0.08
	draw_line(player_position + Vector2(35, -10), enemy_position + Vector2(-39, 5),
		Color(accent, 0.10), 1.0, true)
	draw_circle(midpoint, 4.0, Color("f5df9b", energy))
	draw_circle(midpoint, 15.0, Color("f5df9b", energy * 0.16))


func _ratio(value_key: String, maximum_key: String) -> float:
	return clampf(float(battle.get(value_key, 0)) / maxf(1.0, float(battle.get(maximum_key, 1))), 0.0, 1.0)
