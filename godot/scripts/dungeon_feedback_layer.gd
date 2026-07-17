class_name DungeonFeedbackLayer
extends Control

var feedback: Dictionary = {}
var accent := Color("e4be4c")
var elapsed := 0.0
var lifetime := 1.8


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func configure(next_feedback: Dictionary, next_accent: Color) -> void:
	feedback = next_feedback.duplicate(true)
	accent = next_accent
	var kind := str(feedback.get("kind", "card"))
	var resolution := _resolution_feedback()
	if kind == "encounter":
		lifetime = 2.65 if str(feedback.get("rank", "combat")) == "boss" else 2.15
	elif kind in ["victory", "defeat"] or not resolution.is_empty():
		lifetime = 2.45
	else:
		lifetime = 2.25 if bool(feedback.get("phase_shifted", false)) else 1.8
	elapsed = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= lifetime:
		queue_free()


func _draw() -> void:
	if feedback.is_empty() or size.x < 400.0 or size.y < 300.0:
		return
	var progress := clampf(elapsed / lifetime, 0.0, 1.0)
	var fade := pow(1.0 - progress, 0.72)
	var pulse := 0.76 + sin(elapsed * 12.0) * 0.24
	var player_position := Vector2(size.x * 0.16, size.y * 0.29)
	var enemy_position := Vector2(size.x * 0.84, size.y * 0.29)
	var hand_position := Vector2(size.x * 0.50, size.y * 0.62)
	var kind := str(feedback.get("kind", ""))
	if kind == "card":
		_draw_card_cast(hand_position, enemy_position, player_position, fade, pulse)
	elif kind == "enemy":
		_draw_enemy_action(enemy_position, player_position, fade, pulse)
	elif kind == "encounter":
		_draw_encounter(enemy_position, fade, pulse)
	elif kind in ["victory", "defeat"]:
		var result_position := Vector2(size.x * 0.50, size.y * 0.34)
		_draw_resolution(feedback, result_position, result_position, fade, pulse)
	if bool(feedback.get("phase_shifted", false)):
		_draw_phase_break(enemy_position, fade, pulse)
	if bool(feedback.get("heart_awakened", false)):
		_draw_heart_awaken(player_position, fade, pulse)
	var resolution := _resolution_feedback()
	if not resolution.is_empty():
		_draw_resolution(resolution, player_position, enemy_position, fade, pulse)


func _resolution_feedback() -> Dictionary:
	var value: Variant = feedback.get("resolution", {})
	return value as Dictionary if value is Dictionary else {}


func _draw_encounter(center: Vector2, fade: float, pulse: float) -> void:
	var rank := str(feedback.get("rank", "combat"))
	var is_boss := rank == "boss"
	var is_elite := rank == "elite"
	var tint := Color("c95055") if is_boss else Color("d79b4d") if is_elite else accent
	draw_rect(Rect2(Vector2.ZERO, size), Color(tint, fade * (0.060 if is_boss else 0.035)), true)
	var progress := clampf(elapsed / lifetime, 0.0, 1.0)
	for index in range(5 if is_boss else 3):
		var radius := 46.0 + float(index) * 24.0 + progress * 32.0
		draw_arc(center, radius, -PI * (0.92 - float(index) * 0.04),
			PI * (0.92 - float(index) * 0.04), 56,
			Color(tint, fade * (0.58 - float(index) * 0.085)),
			4.0 if index == 0 else 2.2, true)
	for side in [-1.0, 1.0]:
		var x := center.x + float(side) * (56.0 + progress * 22.0)
		draw_line(Vector2(x, center.y - 112.0), Vector2(x, center.y + 112.0),
			Color(tint, fade * (0.48 + pulse * 0.16)), 3.0, true)
	if is_boss:
		for index in range(6):
			var angle := float(index) * TAU / 6.0 + elapsed * 0.22
			var inner := center + Vector2(cos(angle), sin(angle)) * 72.0
			var outer := center + Vector2(cos(angle), sin(angle)) * (118.0 + pulse * 9.0)
			draw_line(inner, outer, Color("f2b06e", fade * 0.66), 2.6, true)


func _draw_resolution(result: Dictionary, player_position: Vector2, enemy_position: Vector2,
		fade: float, pulse: float) -> void:
	var victory := str(result.get("kind", "victory")) == "victory"
	var center := enemy_position if victory else player_position
	var rank := str(result.get("rank", "combat"))
	var color := Color("f0c36b") if victory else Color("b94d5d")
	if rank == "boss" and victory:
		color = Color("f29a67")
	draw_rect(Rect2(Vector2.ZERO, size), Color(color, fade * 0.045), true)
	var progress := clampf(elapsed / lifetime, 0.0, 1.0)
	for index in range(4):
		var radius := 34.0 + float(index) * 22.0 + progress * 58.0
		draw_arc(center, radius, elapsed * (0.18 + float(index) * 0.05),
			elapsed * (0.18 + float(index) * 0.05) + PI * 1.72, 56,
			Color(color, fade * (0.68 - float(index) * 0.11)),
			3.4 if index == 0 else 2.0, true)
	for index in range(14 if rank == "boss" else 10):
		var angle := float(index) * TAU / float(14 if rank == "boss" else 10) + elapsed * 0.28
		var distance := 24.0 + progress * (118.0 + float(index % 3) * 18.0)
		var direction := Vector2(cos(angle), sin(angle))
		var inner := center + direction * distance
		var outer := inner + direction * (18.0 + pulse * 7.0)
		draw_line(inner, outer, Color(color, fade * 0.70), 2.4, true)


func _draw_card_cast(origin: Vector2, target: Vector2, player_position: Vector2,
		fade: float, pulse: float) -> void:
	var damage := int(feedback.get("damage", 0))
	var block := int(feedback.get("block", 0))
	var stress_delta := int(feedback.get("stress_delta", 0))
	if damage > 0:
		var direction := (target - origin).normalized()
		var normal := Vector2(-direction.y, direction.x)
		var travel := clampf(elapsed * 2.8, 0.0, 1.0)
		for offset in [-13.0, 0.0, 13.0]:
			var start: Vector2 = origin + normal * float(offset)
			var end: Vector2 = start.lerp(target - direction * 34.0, travel)
			draw_line(start, end, Color(accent, fade * (0.42 + pulse * 0.28)),
				3.0 if offset == 0.0 else 1.5, true)
		_draw_impact(target, Color("f06b63"), fade, pulse, 38.0 + mini(24.0, float(damage)))
	if block > 0:
		for index in range(3):
			draw_arc(player_position, 45.0 + float(index) * 9.0, PI * 0.78, PI * 2.22,
				42, Color("72c8e8", fade * (0.46 - float(index) * 0.09)), 3.0, true)
	if stress_delta > 0:
		draw_arc(player_position, 72.0 + pulse * 5.0, 0.0, TAU, 48,
			Color("df5f6d", fade * 0.58), 3.0, true)


func _draw_enemy_action(origin: Vector2, target: Vector2, fade: float, pulse: float) -> void:
	var damage := int(feedback.get("damage", 0))
	var block_delta := int(feedback.get("enemy_block_delta", 0))
	var stress_delta := int(feedback.get("stress_delta", 0))
	if damage > 0:
		var direction := (target - origin).normalized()
		var normal := Vector2(-direction.y, direction.x)
		var travel := clampf(elapsed * 3.1, 0.0, 1.0)
		for offset in [-10.0, 10.0]:
			var start: Vector2 = origin + normal * float(offset)
			var end: Vector2 = start.lerp(target - direction * 38.0, travel)
			draw_line(start, end, Color("ef665e", fade * 0.76), 4.0, true)
		_draw_impact(target, Color("ef665e"), fade, pulse, 42.0 + mini(22.0, float(damage)))
	if block_delta > 0:
		for index in range(3):
			draw_arc(origin, 45.0 + float(index) * 9.0, PI * 0.72, PI * 2.28,
				42, Color("75bee2", fade * (0.50 - float(index) * 0.10)), 3.0, true)
	if stress_delta > 0:
		for index in range(3):
			var radius := 54.0 + float(index) * 12.0 + pulse * 5.0
			draw_arc(target, radius, elapsed * 0.7 + float(index),
				elapsed * 0.7 + float(index) + PI * 1.45, 42,
				Color("bd5364", fade * (0.48 - float(index) * 0.08)), 2.4, true)


func _draw_phase_break(center: Vector2, fade: float, pulse: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("e46b5f", fade * 0.035), true)
	for index in range(5):
		var radius := 62.0 + float(index) * 23.0 + elapsed * 24.0
		draw_arc(center, radius, -PI * 0.88, PI * 0.88, 64,
			Color("f0a06d", fade * (0.54 - float(index) * 0.075)),
			4.0 if index == 0 else 2.0, true)
	draw_line(center + Vector2(0, -110), center + Vector2(0, 114),
		Color("ffe0a1", fade * (0.55 + pulse * 0.25)), 3.0, true)


func _draw_heart_awaken(center: Vector2, fade: float, pulse: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("8d2038", fade * 0.055), true)
	for index in range(4):
		var radius := 48.0 + float(index) * 21.0 + pulse * 8.0
		draw_arc(center, radius, elapsed * (0.5 + float(index) * 0.1),
			elapsed * (0.5 + float(index) * 0.1) + PI * 1.55, 52,
			Color("df5f79", fade * (0.62 - float(index) * 0.11)), 2.6, true)


func _draw_impact(center: Vector2, color: Color, fade: float, pulse: float, radius: float) -> void:
	draw_circle(center, radius * 0.34, Color(color, fade * 0.12))
	draw_arc(center, radius * (0.86 + pulse * 0.10), 0.0, TAU, 48,
		Color(color, fade * 0.82), 4.0, true)
	for index in range(8):
		var angle := float(index) * TAU / 8.0 + elapsed * 0.35
		var inner := center + Vector2(cos(angle), sin(angle)) * radius * 0.52
		var outer := center + Vector2(cos(angle), sin(angle)) * radius * (0.96 + pulse * 0.12)
		draw_line(inner, outer, Color(color, fade * 0.66), 2.2, true)
