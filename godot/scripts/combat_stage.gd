class_name CombatStage
extends Control

const CombatVisualCatalogScript = preload("res://scripts/combat_visual_catalog.gd")

var battle: Dictionary = {}
var accent := Color("e4be4c")
var enemy_color := Color("e36f62")
var elapsed := 0.0
var motes: Array[Dictionary] = []
var feedback_cue := ""
var feedback_kind := ""
var feedback_actor := "system"
var feedback_seed := 0
var debug_capture_only := false
var debug_pixel_cells: Dictionary = {}
var player_art_layers: Dictionary = {}
var enemy_art_layers: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size.y = 210
	set_process(true)


func configure(next_battle: Dictionary, next_accent: Color) -> void:
	battle = next_battle.duplicate(true)
	accent = next_accent
	enemy_color = Color("cb665c") if bool(battle.get("second_phase_active", false)) else Color("b36d62")
	elapsed = 0.0
	_build_motes()
	_read_latest_feedback()
	player_art_layers = _resolve_battle_art("player")
	enemy_art_layers = _resolve_battle_art("enemy")
	feedback_seed = absi(hash("%s:%s:%s" % [battle.get("turn", 0), feedback_kind, feedback_cue]))
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _build_motes() -> void:
	motes.clear()
	var seed_value := absi(hash(str(battle.get("enemy_id", "enemy"))))
	for index in range(15):
		motes.append({
			"x": float((seed_value + index * 83) % 997) / 997.0,
			"y": float((seed_value / 7 + index * 137) % 991) / 991.0,
			"speed": 0.006 + float(index % 5) * 0.003,
			"phase": float(index) * 0.71,
			"radius": 0.65 + float(index % 3) * 0.38,
		})


func _read_latest_feedback() -> void:
	feedback_cue = ""
	feedback_kind = ""
	feedback_actor = "system"
	var history_value: Variant = battle.get("event_history", [])
	var history: Array = history_value if history_value is Array else []
	if history.is_empty() or not history[-1] is Dictionary:
		return
	var steps_value: Variant = (history[-1] as Dictionary).get("steps", [])
	var steps: Array = steps_value if steps_value is Array else []
	for reverse_index in range(steps.size() - 1, -1, -1):
		var step_value: Variant = steps[reverse_index]
		if not step_value is Dictionary:
			continue
		var step: Dictionary = step_value
		var kind := str(step.get("kind", ""))
		if kind not in ["damage", "shield", "heal", "phase_shift"]:
			continue
		feedback_cue = str(step.get("cue", ""))
		feedback_kind = kind
		feedback_actor = str(step.get("actor", "system"))
		return


func _draw() -> void:
	if size.x < 240.0 or size.y < 120.0 or battle.is_empty():
		return
	# The stage is a character performance space, not a distant battlefield map.
	# Scale from the half-screen layout so silhouettes and held weapons remain
	# readable at 1280p while still fitting narrow screens.
	var scale_value := clampf(minf(size.x / 520.0, size.y / 310.0), 0.72, 1.45)
	var pixel_size := _pixel_size(scale_value)
	var player_position := _snap_to_pixel(Vector2(size.x * 0.23, size.y * 0.78), pixel_size)
	var enemy_position := _snap_to_pixel(Vector2(size.x * 0.76, size.y * 0.76), pixel_size)
	var shake := _feedback_shake(scale_value)
	if feedback_actor == "enemy":
		player_position += _snap_to_pixel(shake, pixel_size)
	else:
		enemy_position += _snap_to_pixel(shake, pixel_size)
	_draw_arena(scale_value)
	_draw_motion_pressure(player_position, enemy_position, scale_value)
	_draw_phase_feedback(enemy_position, scale_value)
	_draw_rank_presence(enemy_position, scale_value)
	var player_presence_radius := maxf(56.0 * scale_value, pixel_size * 27.0)
	var enemy_presence_radius := maxf(62.0 * scale_value, pixel_size * 29.0)
	_draw_presence(player_position, player_presence_radius, accent,
		_ratio("player_hp", "player_max_hp"), battle.get("player_statuses", {}), false)
	_draw_presence(enemy_position, enemy_presence_radius, enemy_color,
		_ratio("enemy_hp", "enemy_max_hp"), battle.get("enemy_statuses", {}), true)
	_draw_player(player_position, scale_value, _actor_pose("player"))
	_draw_enemy(enemy_position, scale_value, _actor_pose("enemy"))
	_draw_intent(enemy_position, player_position, scale_value)
	_draw_clash_line(player_position, enemy_position, scale_value)
	_draw_latest_feedback(player_position, enemy_position, scale_value)
	_draw_counter_beats(scale_value)


func _draw_arena(scale_value: float) -> void:
	# An opaque, low-contrast ink wash keeps the tactical silhouettes readable over scene art.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.024, 0.028, 0.93), true)
	for band_index in range(14):
		var band_y := size.y * float(band_index) / 14.0
		var band_t := float(band_index) / 13.0
		draw_rect(Rect2(0, band_y, size.x, size.y / 14.0 + 1.0),
			Color(0.038 + band_t * 0.008, 0.068 + band_t * 0.014,
				0.074 + band_t * 0.012, 0.22), true)
	# A dim moon and its broken reflection add depth without competing with combat information.
	var moon := Vector2(size.x * 0.78, size.y * 0.19)
	draw_circle(moon, 34.0 * scale_value, Color(0.72, 0.70, 0.57, 0.055))
	draw_circle(moon, 21.0 * scale_value, Color(0.84, 0.78, 0.59, 0.075))
	var rear_ridge := PackedVector2Array([
		Vector2(0, size.y * 0.46), Vector2(size.x * 0.12, size.y * 0.30),
		Vector2(size.x * 0.22, size.y * 0.43), Vector2(size.x * 0.38, size.y * 0.24),
		Vector2(size.x * 0.52, size.y * 0.45), Vector2(size.x * 0.70, size.y * 0.27),
		Vector2(size.x * 0.84, size.y * 0.41), Vector2(size.x, size.y * 0.22),
		Vector2(size.x, size.y * 0.66), Vector2(0, size.y * 0.66),
	])
	draw_colored_polygon(rear_ridge, Color(0.030, 0.052, 0.056, 0.74))
	var front_ridge := PackedVector2Array([
		Vector2(0, size.y * 0.58), Vector2(size.x * 0.18, size.y * 0.43),
		Vector2(size.x * 0.33, size.y * 0.55), Vector2(size.x * 0.52, size.y * 0.39),
		Vector2(size.x * 0.71, size.y * 0.56), Vector2(size.x * 0.88, size.y * 0.44),
		Vector2(size.x, size.y * 0.52), Vector2(size.x, size.y * 0.75),
		Vector2(0, size.y * 0.75),
	])
	draw_colored_polygon(front_ridge, Color(0.016, 0.028, 0.030, 0.94))
	_draw_era_motif(scale_value)
	for line_index in range(4):
		var mist_y := size.y * (0.36 + float(line_index) * 0.13)
		var mist_points := PackedVector2Array()
		for point_index in range(13):
			var x := size.x * float(point_index) / 12.0
			var y := mist_y + sin(elapsed * 0.22 + float(point_index) * 0.73 + line_index) * \
				(3.0 + float(line_index)) * scale_value
			mist_points.append(Vector2(x, y))
		draw_polyline(mist_points, Color(0.62, 0.70, 0.67, 0.022 + line_index * 0.006),
			(3.0 + line_index * 0.7) * scale_value, true)
	var ground_y := size.y * 0.82
	draw_line(Vector2(size.x * 0.04, ground_y), Vector2(size.x * 0.96, ground_y),
		Color(0.62, 0.54, 0.34, 0.18), 1.0, true)
	for stroke_index in range(3):
		var inset := size.x * (0.08 + stroke_index * 0.055)
		draw_line(Vector2(inset, ground_y + (5.0 + stroke_index * 4.0) * scale_value),
			Vector2(size.x - inset, ground_y + (5.0 + stroke_index * 4.0) * scale_value),
			Color(0.005, 0.012, 0.013, 0.72 - stroke_index * 0.14),
			(7.0 - stroke_index * 1.7) * scale_value, true)
	for mote in motes:
		var px := fposmod(float(mote.x) + sin(elapsed * 0.24 + float(mote.phase)) * 0.018, 1.0)
		var py := fposmod(float(mote.y) - elapsed * float(mote.speed), 1.0)
		var position := Vector2(px * size.x, py * size.y)
		var glow := 0.45 + sin(elapsed * 1.15 + float(mote.phase)) * 0.30
		draw_circle(position, float(mote.radius) * scale_value, Color(accent, 0.055 * glow))
	# A hairline inner frame reads as crafted lacquer rather than a glowing panel.
	draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), Color(0.56, 0.48, 0.31, 0.18), false, 1.0)


func _draw_era_motif(scale_value: float) -> void:
	var era_key := _combat_era_key()
	var motif_color := Color(accent, 0.12)
	match era_key:
		"steam":
			for pipe_index in range(3):
				var pipe_y := size.y * (0.29 + pipe_index * 0.10)
				draw_line(Vector2(size.x * 0.05, pipe_y), Vector2(size.x * 0.24, pipe_y),
					motif_color, (2.0 + pipe_index) * scale_value, false)
				draw_line(Vector2(size.x * 0.24, pipe_y), Vector2(size.x * 0.24, pipe_y + 22.0),
					motif_color, (2.0 + pipe_index) * scale_value, false)
			for gear_index in range(2):
				var center := Vector2(size.x * (0.76 + gear_index * 0.10), size.y * (0.42 - gear_index * 0.12))
				var radius := (24.0 + gear_index * 12.0) * scale_value
				draw_arc(center, radius, 0.0, TAU, 24, Color(accent, 0.10), 2.0, false)
				for tooth_index in range(8):
					var angle := float(tooth_index) * TAU / 8.0 + elapsed * 0.03
					draw_line(center + Vector2(cos(angle), sin(angle)) * radius,
						center + Vector2(cos(angle), sin(angle)) * (radius + 7.0 * scale_value),
						Color(accent, 0.09), 2.0, false)
		"star":
			for line_index in range(5):
				var y := size.y * (0.19 + line_index * 0.10)
				draw_line(Vector2(size.x * 0.08, y), Vector2(size.x * 0.92, y),
					Color("74b6ca", 0.045 + line_index * 0.008), 1.0, false)
			for star_index in range(9):
				var seed := absi(hash("star:%s" % star_index))
				var star := Vector2(size.x * (0.08 + float(seed % 83) / 100.0),
					size.y * (0.11 + float((seed / 83) % 47) / 100.0))
				draw_circle(star, (1.0 + star_index % 2) * scale_value,
					Color("a7d9e6", 0.16 + star_index % 3 * 0.04))
				if star_index > 0:
					var prior_seed := absi(hash("star:%s" % (star_index - 1)))
					var prior := Vector2(size.x * (0.08 + float(prior_seed % 83) / 100.0),
						size.y * (0.11 + float((prior_seed / 83) % 47) / 100.0))
					draw_line(prior, star, Color("79b4c7", 0.055), 1.0, false)
		"wasteland":
			for rain_index in range(17):
				var rain_x := size.x * float(rain_index + 1) / 18.0
				var rain_y := fposmod(rain_index * 37.0 + elapsed * 13.0, size.y * 0.58)
				draw_line(Vector2(rain_x, rain_y), Vector2(rain_x - 8.0, rain_y + 26.0) * Vector2(1.0, 1.0),
					Color("87918b", 0.07 + rain_index % 3 * 0.02), 1.0, false)
			for post_index in range(4):
				var post_x := size.x * (0.12 + post_index * 0.25)
				draw_line(Vector2(post_x, size.y * 0.42), Vector2(post_x + 3.0, size.y * 0.72),
					Color("8d6d50", 0.11), 3.0, false)
		"final_age":
			for slip_index in range(6):
				var x := size.x * (0.09 + slip_index * 0.15)
				var top := size.y * (0.15 + (slip_index % 2) * 0.06)
				var slip := Rect2(x, top, 24.0 * scale_value, 54.0 * scale_value)
				draw_rect(slip, Color("8c9f98", 0.055), true)
				draw_rect(slip, Color("c6b980", 0.10), false, 1.0)
				for stroke_index in range(3):
					draw_line(slip.position + Vector2(5.0, 12.0 + stroke_index * 10.0) * scale_value,
						slip.position + Vector2(19.0, 12.0 + stroke_index * 10.0) * scale_value,
						Color("d4ca94", 0.10), 1.0, false)
		"immortal":
			for step_index in range(5):
				var inset := size.x * (0.10 + step_index * 0.045)
				var y := size.y * (0.50 - step_index * 0.065)
				draw_line(Vector2(inset, y), Vector2(size.x - inset, y),
					Color("b8c6e8", 0.055 + step_index * 0.012), 1.0, false)
			for cloud_index in range(4):
				var cloud_center := Vector2(size.x * (0.12 + cloud_index * 0.26), size.y * 0.32)
				draw_arc(cloud_center, (18.0 + cloud_index % 2 * 7.0) * scale_value,
					PI * 1.08, PI * 1.92, 18, Color("b8c6e8", 0.085), 2.0, false)
		_:
			for roof_index in range(3):
				var roof_y := size.y * (0.33 + roof_index * 0.085)
				var center_x := size.x * (0.50 + (roof_index - 1) * 0.18)
				var half_width := (58.0 - roof_index * 8.0) * scale_value
				draw_polyline(PackedVector2Array([
					Vector2(center_x - half_width, roof_y + 8.0 * scale_value),
					Vector2(center_x, roof_y),
					Vector2(center_x + half_width, roof_y + 8.0 * scale_value),
				]), Color("c4b176", 0.08), 2.0, false)


func _combat_era_key() -> String:
	var enemy_id := str(battle.get("enemy_id", ""))
	if enemy_id.begins_with("steam_"):
		return "steam"
	if enemy_id.begins_with("star_"):
		return "star"
	if enemy_id.begins_with("wasteland_"):
		return "wasteland"
	if enemy_id.begins_with("final_age_"):
		return "final_age"
	if enemy_id.begins_with("immortal_"):
		return "immortal"
	return "classical"


func _draw_rank_presence(enemy_position: Vector2, scale_value: float) -> void:
	var anatomy := CombatVisualCatalogScript.enemy_anatomy(str(battle.get("enemy_id", "")))
	var rank := str(anatomy.get("rank", "normal"))
	if rank == "normal":
		return
	var pixel := _pixel_size(scale_value)
	var root := _snap_to_pixel(enemy_position, pixel)
	var aura_color := Color(enemy_color, 0.16 if rank == "elite" else 0.23)
	var banner_count := 2 if rank == "elite" else 4
	for banner_index in range(banner_count):
		var side := -1.0 if banner_index % 2 == 0 else 1.0
		var tier := float(banner_index / 2)
		var top := root + Vector2(side * (48.0 + tier * 20.0), -128.0 + tier * 18.0) * scale_value
		var bottom := root + Vector2(side * (39.0 + tier * 18.0), -32.0 + tier * 8.0) * scale_value
		draw_line(top, bottom, aura_color, (2.0 if rank == "elite" else 3.0) * scale_value, false)
		draw_colored_polygon(PackedVector2Array([
			top, top + Vector2(-side * 20.0, 7.0) * scale_value,
			top + Vector2(-side * 5.0, 26.0) * scale_value,
		]), Color(enemy_color, 0.075 if rank == "elite" else 0.12))
	if rank == "boss":
		for ring_index in range(3):
			var radius := (62.0 + ring_index * 19.0) * scale_value
			draw_arc(root + Vector2(0, -66.0) * scale_value, radius,
				-PI * 0.82, -PI * 0.18, 28, Color(enemy_color, 0.14 - ring_index * 0.025),
				2.0 * scale_value, false)


func _draw_motion_pressure(player_position: Vector2, enemy_position: Vector2,
		scale_value: float) -> void:
	if feedback_kind.is_empty() or elapsed > 0.62:
		return
	var source := enemy_position if feedback_actor == "enemy" else player_position
	var target := player_position if feedback_actor == "enemy" else enemy_position
	var direction := (target - source).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var fade := clampf(1.0 - elapsed / 0.62, 0.0, 1.0)
	var pressure_color := Color(enemy_color if feedback_actor == "enemy" else accent, fade * 0.12)
	for line_index in range(9):
		var lane := float(line_index - 4) * 13.0 * scale_value
		var stagger := float((feedback_seed + line_index * 17) % 43) * scale_value
		var start := source - direction * (34.0 + stagger) * scale_value + normal * lane
		var end := target - direction * (48.0 + stagger * 0.35) * scale_value + normal * lane * 0.45
		draw_line(start, end, pressure_color, 1.0 + line_index % 3, false)


func _draw_phase_feedback(center: Vector2, scale_value: float) -> void:
	var phase_active := bool(battle.get("second_phase_active", false))
	var phase_pending := bool(battle.get("phase_shift_pending", false))
	if not phase_active and not phase_pending:
		return
	var phase_pulse := 0.52 + sin(elapsed * (2.2 if phase_active else 1.45)) * 0.12
	var phase_color := Color("c96056") if phase_active else Color("b69863")
	# The second phase stains the ground and tears the surrounding ink wash instead of adding neon rings.
	var body_center := center + Vector2(0, -28) * scale_value
	var stain_center := center + Vector2(0, 3) * scale_value
	for stain_index in range(4):
		var stain_points := _ellipse_arc_points(stain_center,
			Vector2(62.0 + stain_index * 9.0, 13.0 + stain_index * 2.0) * scale_value,
			PI * (0.05 + stain_index * 0.06), PI * (1.72 - stain_index * 0.03), 30)
		draw_polyline(stain_points, Color(phase_color,
			phase_pulse * (0.16 - stain_index * 0.025)), (2.2 - stain_index * 0.25) * scale_value, true)
	if phase_active:
		for crack_index in range(9):
			var angle := float(crack_index) * TAU / 9.0 + sin(elapsed * 0.4) * 0.05
			var start := body_center + Vector2(cos(angle), sin(angle)) * 45.0 * scale_value
			var bend := start + Vector2(cos(angle + 0.19), sin(angle + 0.19)) * 11.0 * scale_value
			var end := bend + Vector2(cos(angle - 0.11), sin(angle - 0.11)) * 14.0 * scale_value
			draw_polyline(PackedVector2Array([start, bend, end]), Color(phase_color, 0.28),
				1.2 * scale_value, true)
		for ember_index in range(7):
			var phase := float((feedback_seed + ember_index * 53) % 101) / 101.0
			var ember_x := (phase - 0.5) * 118.0
			var ember_y := fposmod(elapsed * (10.0 + ember_index) + ember_index * 17.0, 94.0)
			var ember := body_center + Vector2(ember_x, 42.0 - ember_y) * scale_value
			draw_line(ember, ember + Vector2(-1.5, -5.0) * scale_value,
				Color(phase_color, 0.12 + (ember_index % 3) * 0.05), 1.0 * scale_value, true)


func _draw_presence(center: Vector2, radius: float, color: Color, health_ratio: float,
		statuses_value: Variant, enemy_side: bool) -> void:
	var statuses: Dictionary = statuses_value if statuses_value is Dictionary else {}
	var pulse := 1.0 + sin(elapsed * 1.55 + (1.4 if enemy_side else 0.0)) * 0.018
	var foot := center + Vector2(0, radius * 0.08)
	var shadow := _ellipse_arc_points(foot, Vector2(radius * 0.92, radius * 0.18) * pulse,
		0.0, TAU, 40)
	draw_colored_polygon(shadow, Color(0.002, 0.007, 0.008, 0.68))
	var full_stroke := _ellipse_arc_points(foot, Vector2(radius * 1.03, radius * 0.23) * pulse,
		PI * 0.08, PI * 1.92, 48)
	draw_polyline(full_stroke, Color(color, 0.13), 1.3, true)
	var health_stroke := _ellipse_arc_points(foot, Vector2(radius * 1.05, radius * 0.25) * pulse,
		PI * 0.08, PI * 0.08 + PI * 1.84 * health_ratio, 48)
	draw_polyline(health_stroke, Color(color, 0.58), 2.3, true)
	if int(statuses.get("shield", 0)) > 0:
		var shield_side := -1.0 if enemy_side else 1.0
		var barrier_center := center + Vector2(shield_side * radius * 0.38, -radius * 0.04)
		draw_arc(barrier_center, radius * 0.92, -PI * 0.58, PI * 0.58, 34,
			Color("79acbc", 0.52), 3.0, true)
		draw_arc(barrier_center, radius * 0.80, -PI * 0.54, PI * 0.54, 30,
			Color("d5e8e6", 0.18), 1.0, true)
	if int(statuses.get("bleed", 0)) > 0:
		for offset in [-14.0, 0.0, 14.0]:
			draw_line(center + Vector2(offset, radius * 0.92),
				center + Vector2(offset - 3.0, radius * 1.09), Color("b8494c", 0.60), 1.5, true)
	if int(statuses.get("weak", 0)) > 0:
		for wisp_index in range(3):
			var angle := elapsed * -0.23 + wisp_index * TAU / 3.0
			var wisp := center + Vector2(cos(angle) * radius * 0.76,
				sin(angle) * radius * 0.38 - radius * 0.22)
			draw_circle(wisp, 2.2, Color("9479a3", 0.48))


func _draw_catalog_player(position: Vector2, scale_value: float, pose: String) -> void:
	var pixel := _pixel_size(scale_value)
	var root := _snap_to_pixel(position, pixel)
	if pose == "idle" and int(floor(elapsed * 1.6)) % 2 == 1:
		root.y -= pixel
	elif pose == "hit":
		root.x -= pixel * 2.0
	var loadout := CombatVisualCatalogScript.resolve_loadout(battle)
	var path := CombatVisualCatalogScript.path_profile(str(loadout.path_id))
	var path_palette: Array = path.get("palette", ["#203238", "#466d73", "#9ab9ae", "#e2c578"])
	var outline := Color("10181a")
	var body := Color(str(path_palette[0]))
	var cloth := Color(str(path_palette[1]))
	var light := Color(str(path_palette[2]))
	var trim := Color(str(path_palette[3]))
	var stance := _path_stance(path, pose)
	# Separate anatomy keeps the six path outfits readable and lets attacks move
	# arms and weapon independently from the center of mass.
	var legs := [[-6,-8,5,10],[2,-8,5,10]]
	var torso := [[-6,-22,13,14],[-8,-16,17,7]]
	var head := [[-4,-31,9,9],[-5,-34,11,4]]
	_draw_catalog_cells(root, pixel, path.get("backpiece", []), outline, true)
	_draw_catalog_cells(root, pixel, path.get("backpiece", []), body, false)
	_draw_catalog_cells(root, pixel, legs, outline, true)
	_draw_catalog_cells(root, pixel, legs, body, false)
	_draw_catalog_cells(root, pixel, path.get("garment", []), outline, true)
	_draw_catalog_cells(root, pixel, path.get("garment", []), cloth, false)
	_draw_catalog_cells(root, pixel, torso, outline, true)
	_draw_catalog_cells(root, pixel, torso, cloth, false)
	var back_arm := [[-11,-22,5,12]]
	var front_arm := [[7,-22,5,12]]
	if pose == "attack":
		back_arm = [[-10,-20,5,10]]
		front_arm = [[5,-21,10,4],[13,-20,6,3]]
	elif pose == "charge":
		back_arm = [[-10,-24,5,11]]
		front_arm = [[4,-25,8,4],[10,-28,4,6]]
	elif pose == "guard":
		back_arm = [[-11,-23,5,12]]
		front_arm = [[-6,-23,14,5],[5,-20,6,4]]
	elif pose == "hit":
		back_arm = [[-8,-24,5,11]]
		front_arm = [[8,-18,7,4],[13,-15,4,5]]
	_draw_catalog_cells(root, pixel, back_arm, outline, true)
	_draw_catalog_cells(root, pixel, back_arm, body, false)
	_draw_catalog_cells(root, pixel, head, outline, true)
	_draw_catalog_cells(root, pixel, head, light, false)
	_draw_catalog_cells(root, pixel, path.get("headgear", []), outline, true)
	_draw_catalog_cells(root, pixel, path.get("headgear", []), trim, false)
	_draw_catalog_cells(root, pixel, front_arm, outline, true)
	_draw_catalog_cells(root, pixel, front_arm, light, false)
	_draw_catalog_cells(root, pixel, path.get("mantle", []), cloth, false)
	_draw_catalog_cells(root, pixel, path.get("sigil", []), trim, false)
	_draw_catalog_cells(root, pixel, [[-2,-28,2,1],[2,-28,1,1]], Color("42332d"), false)
	_draw_player_crest(root, pixel, str(path.get("crest", "eye")), trim)
	var armor := CombatVisualCatalogScript.equipment_profile(str(loadout.armor_id))
	_draw_catalog_cells(root, pixel, armor.get("cells", []), Color(str((armor.get("palette", ["#586d78"]))[0])), false)
	if armor.has("cells"):
		_draw_catalog_cells(root, pixel, armor.get("cells", []), Color(str((armor.get("palette", ["#586d78", "#a9c4ca"]))[1])), true, 1)
	var relic := CombatVisualCatalogScript.equipment_profile(str(loadout.relic_id))
	_draw_catalog_cells(root, pixel, relic.get("cells", []), Color(str((relic.get("palette", ["#96a8aa"]))[0])), false)
	_draw_catalog_weapon(root, pixel, str(loadout.weapon_id), pose, stance)
	if not str(loadout.jade_weapon_id).is_empty():
		var jade := CombatVisualCatalogScript.jade_weapon_profile(str(loadout.jade_weapon_id))
		var jade_palette: Array = jade.get("palette", ["#b8daca", "#edffe0"])
		_draw_catalog_cells(root, pixel, jade.get("mark", []), Color(str(jade_palette[0]), 0.78), false)
		_draw_catalog_cells(root, pixel, jade.get("mark", []), Color(str(jade_palette[1]), 0.72), true, 1)
		var jade_cells: Array = jade.get("cells", [])
		var jade_offset := stance
		if pose == "attack": jade_offset += Vector2i(9, 3)
		elif pose == "charge": jade_offset += Vector2i(-2, -8)
		elif pose == "guard": jade_offset += Vector2i(-5, -4)
		_draw_jade_motion(root, pixel, jade_cells, pose, Color(str(jade_palette[0])), jade_offset)
		for value in jade_cells:
			var cell: Array = value
			var shifted := [int(cell[0]) + jade_offset.x, int(cell[1]) + jade_offset.y,
				int(cell[2]), int(cell[3])]
			_draw_catalog_cells(root, pixel, [shifted], Color("102023", 0.70), true)
			_draw_catalog_cells(root, pixel, [shifted], Color(str(jade_palette[0]), 0.72), false)
	if pose == "guard":
		_draw_catalog_cells(root, pixel, [[-12,-22,2,12],[10,-22,2,12],[-10,-24,20,2]], Color("c8e4d9", 0.72), false)
	elif pose == "charge":
		_draw_catalog_cells(root, pixel, [[10,-28,2,2],[13,-31,2,2],[16,-34,2,2]], trim, false)
	elif pose == "phase":
		_draw_catalog_cells(root, pixel, [[-13,-26,2,2],[11,-23,2,2],[-10,-16,1,3],[9,-14,1,3]], Color("d783ac", 0.74), false)


func _draw_jade_motion(root: Vector2, pixel: float, cells: Array, pose: String,
		color: Color, offset: Vector2i) -> void:
	if pose == "attack":
		for echo_index in range(1, 4):
			var echo_cells: Array = []
			for value in cells:
				var cell: Array = value
				echo_cells.append([int(cell[0]) + offset.x - echo_index * 5,
					int(cell[1]) + offset.y - echo_index, int(cell[2]), int(cell[3])])
			_draw_catalog_cells(root, pixel, echo_cells, Color(color, 0.23 - echo_index * 0.045), false)
		var seed_value := absi(hash(JSON.stringify(cells)))
		for trail_index in range(5):
			var y := -29 + int((seed_value / (trail_index + 2) + trail_index * 7) % 24)
			_pixel_line(root, pixel, Vector2i(-12 - trail_index * 2, y),
				Vector2i(8 + trail_index * 3, y + trail_index % 3), Color(color, 0.38), 1)
	elif pose == "charge":
		for spark_index in range(7):
			var angle_index := (spark_index + int(floor(elapsed * 7.0))) % 7
			var x := offset.x + 5 + angle_index * 4
			var y := offset.y - 32 + (spark_index % 3) * 5
			_pixel_rect(root, pixel, Rect2i(x, y, 2, 2), Color(color, 0.46 + spark_index % 2 * 0.12))
	elif pose == "guard":
		for ward_index in range(5):
			_pixel_rect(root, pixel, Rect2i(-13 + ward_index * 5, -29 - ward_index % 2 * 2,
				3, 2), Color(color, 0.40))
	else:
		var pulse_cell := offset + Vector2i(30, -22 + int(floor(elapsed * 2.0)) % 2)
		_pixel_rect(root, pixel, Rect2i(pulse_cell, Vector2i(2, 2)), Color(color, 0.42))


func _draw_catalog_enemy(position: Vector2, scale_value: float, pose: String) -> void:
	var pixel := _pixel_size(scale_value)
	var enemy_id := str(battle.get("enemy_id", ""))
	var profile := CombatVisualCatalogScript.enemy_profile_for_battle(battle)
	var anatomy := CombatVisualCatalogScript.enemy_anatomy(enemy_id)
	var root := _snap_to_pixel(position, pixel)
	if pose == "idle" and int(floor(elapsed * 1.8)) % 2 == 1:
		root.y -= pixel
	elif pose == "hit":
		root.x += pixel * 2.0
	var palette: Array = profile.get("palette", ["#171a1e", "#3d4549", "#7d8c8d", "#d6bd7b"])
	var outline := Color(str(palette[0]))
	if anatomy.is_empty():
		_draw_catalog_cells(root, pixel, profile.get("body", []), outline, true)
		_draw_catalog_cells(root, pixel, profile.get("body", []), Color(str(palette[2])), false)
	else:
		var part_order := ["back_arm", "legs", "garment", "torso", "head", "front_arm", "ornament"]
		var part_colors := {"back_arm":1, "legs":1, "garment":1, "torso":2,
			"head":2, "front_arm":2, "ornament":3}
		for part_id in part_order:
			var part_root := root + Vector2(_enemy_part_offset(anatomy, str(part_id), pose)) * pixel
			var cells: Array = anatomy.get(part_id, [])
			_draw_catalog_cells(part_root, pixel, cells, outline, true)
			_draw_catalog_cells(part_root, pixel, cells, Color(str(palette[int(part_colors[part_id])])), false)
	var weapon_profile_id := str(battle.get("weapon_profile_id", profile.get("weapon_profile_id", "")))
	_draw_enemy_weapon(root, pixel, weapon_profile_id, pose, Color(str(palette[3])),
		_enemy_part_offset(anatomy, "weapon", pose))
	if pose == "guard":
		_draw_catalog_cells(root, pixel, [[-14,-24,2,13],[-11,-27,2,2],[-9,-29,18,2],[9,-27,2,2],[12,-24,2,13]], Color("9cc4c2", 0.70), false)
	elif pose == "charge":
		_draw_catalog_cells(root, pixel, [[-19,-29,2,2],[-23,-26,2,2],[-27,-23,2,2]], Color(str(palette[3]), 0.72), false)
	elif pose == "phase":
		_draw_catalog_cells(root, pixel, [[-16,-31,2,2],[-11,-34,2,2],[-5,-36,2,2],[2,-35,2,2],[8,-32,2,2],[14,-28,2,2]], Color("e27b73", 0.80), false)


func _enemy_part_offset(anatomy: Dictionary, part_id: String, pose: String) -> Vector2i:
	if pose == "attack":
		var offsets_value: Variant = anatomy.get("attack_offsets", {})
		var offsets: Dictionary = offsets_value if offsets_value is Dictionary else {}
		var value: Variant = offsets.get(part_id, [0, 0])
		if value is Array and (value as Array).size() >= 2:
			return Vector2i(int((value as Array)[0]), int((value as Array)[1]))
	if pose == "charge":
		return {"head":Vector2i(-1,-2), "torso":Vector2i(0,1),
			"front_arm":Vector2i(-4,-6), "back_arm":Vector2i(3,2),
			"weapon":Vector2i(-5,-7)}.get(part_id, Vector2i.ZERO)
	if pose == "guard":
		return {"head":Vector2i(1,1), "torso":Vector2i(1,1),
			"front_arm":Vector2i(-5,-4), "back_arm":Vector2i(-3,-2),
			"weapon":Vector2i(-4,-6)}.get(part_id, Vector2i.ZERO)
	if pose == "hit":
		return {"head":Vector2i(3,2), "torso":Vector2i(2,1),
			"front_arm":Vector2i(4,4), "back_arm":Vector2i(3,-2),
			"weapon":Vector2i(5,5), "legs":Vector2i(-2,0)}.get(part_id, Vector2i.ZERO)
	if pose == "phase" and part_id in ["head", "front_arm", "ornament"]:
		return Vector2i(-1 if part_id == "head" else 2, -2)
	return Vector2i.ZERO


func _draw_catalog_cells(root: Vector2, pixel: float, cells_value: Variant, color: Color,
		outline: bool = false, inset: int = 0) -> void:
	if not cells_value is Array:
		return
	for cell_value in cells_value:
		if not cell_value is Array or (cell_value as Array).size() < 4:
			continue
		var cell: Array = cell_value
		var rect := Rect2i(int(cell[0]) + inset, int(cell[1]) + inset,
			maxi(1, int(cell[2]) - inset * 2), maxi(1, int(cell[3]) - inset * 2))
		if outline:
			_pixel_rect(root, pixel, Rect2i(rect.position - Vector2i.ONE, rect.size + Vector2i.ONE * 2), color)
		else:
			_pixel_rect(root, pixel, rect, color)


func _draw_player_crest(root: Vector2, pixel: float, crest: String, color: Color) -> void:
	match crest:
		"lotus": _draw_catalog_cells(root, pixel, [[-4,-31,2,2],[0,-33,2,2],[4,-31,2,2]], color)
		"crown": _draw_catalog_cells(root, pixel, [[-4,-31,2,2],[-1,-33,2,3],[2,-31,2,2]], color)
		"split": _draw_catalog_cells(root, pixel, [[-3,-32,1,4],[1,-32,1,4]], color)
		"eye": _draw_catalog_cells(root, pixel, [[-3,-31,6,1],[0,-30,1,2]], color)
		"forge": _draw_catalog_cells(root, pixel, [[-3,-31,2,3],[1,-31,2,3]], color)
		"knot": _draw_catalog_cells(root, pixel, [[-3,-31,2,2],[1,-31,2,2],[-1,-33,2,2]], color)


func _path_stance(path: Dictionary, pose: String) -> Vector2i:
	var stance_value: Variant = path.get("stance", {})
	var stances: Dictionary = stance_value if stance_value is Dictionary else {}
	var value: Variant = stances.get(pose, stances.get("idle", [0, 0]))
	if value is Array and (value as Array).size() >= 2:
		return Vector2i(int((value as Array)[0]), int((value as Array)[1]))
	return Vector2i.ZERO


func _draw_catalog_weapon(root: Vector2, pixel: float, equipment_id: String, pose: String,
		stance: Vector2i = Vector2i.ZERO) -> void:
	var profile := CombatVisualCatalogScript.equipment_profile(equipment_id)
	var palette: Array = profile.get("palette", ["#d5d8ca", "#fff0ae"])
	var cells: Array = profile.get("cells", [])
	var anchor := Vector2i(8, -19) + stance
	var shift := 0
	if pose == "attack":
		shift = 6
	elif pose == "guard":
		shift = -2
	for value in cells:
		if not value is Array:
			continue
		var cell: Array = value
		var shifted := [int(cell[0]) + shift + anchor.x, int(cell[1]) + anchor.y,
			int(cell[2]), int(cell[3])]
		_draw_catalog_cells(root, pixel, [shifted], Color(str(palette[0])), true)
		_draw_catalog_cells(root, pixel, [shifted], Color(str(palette[1])), false)


func _draw_enemy_weapon(root: Vector2, pixel: float, profile_id: String, pose: String,
		color: Color, part_offset: Vector2i = Vector2i.ZERO) -> void:
	var weapon_profile := CombatVisualCatalogScript.enemy_weapon_profile(profile_id)
	var cells: Array = weapon_profile.get("cells", [])
	var shift := 0 if pose != "attack" else -4
	for value in cells:
		var cell: Array = value
		var shifted := [int(cell[0]) + shift + part_offset.x, int(cell[1]) + part_offset.y,
			int(cell[2]), int(cell[3])]
		_draw_catalog_cells(root, pixel, [shifted], Color("10161a"), true)
		_draw_catalog_cells(root, pixel, [shifted], color, false)


func _resolve_battle_art(side: String) -> Dictionary:
	var result: Dictionary = {}
	var requested_value: Variant = battle.get("%s_art" % side, {})
	var requested: Dictionary = requested_value if requested_value is Dictionary else {}
	var identity := "protagonist" if side == "player" else str(
		battle.get("encounter_id", battle.get("enemy_id", "")))
	identity = _safe_art_identity(identity)
	var default_body := ""
	if not identity.is_empty():
		default_body = "res://art/combat/characters/%s/battle_body.png" % identity
	var body_path := str(requested.get("body_path", battle.get("%s_art_path" % side, "")))
	if body_path.is_empty() and not default_body.is_empty() and ResourceLoader.exists(default_body):
		body_path = default_body
	var body := _load_battle_texture(body_path)
	if body == null:
		return {}
	result["body"] = body
	for layer in ["back", "weapon", "aura"]:
		var layer_path := str(requested.get("%s_path" % layer, ""))
		var texture := _load_battle_texture(layer_path)
		if texture != null:
			result[layer] = texture
	result["display_height"] = clampf(float(requested.get("display_height", 226.0)), 160.0, 340.0)
	var pivot_value: Variant = requested.get("pivot", [0.5, 0.96])
	if pivot_value is Array and (pivot_value as Array).size() >= 2:
		result["pivot"] = Vector2(clampf(float((pivot_value as Array)[0]), 0.0, 1.0),
			clampf(float((pivot_value as Array)[1]), 0.0, 1.0))
	else:
		result["pivot"] = Vector2(0.5, 0.96)
	result["source_id"] = identity
	return result


func _safe_art_identity(value: String) -> String:
	var normalized := value.strip_edges().to_lower().left(80)
	if normalized.is_empty():
		return ""
	for character in normalized:
		if not character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789_-":
			return ""
	return normalized


func _load_battle_texture(path: String) -> Texture2D:
	var normalized := path.strip_edges()
	if normalized.is_empty() or not normalized.begins_with("res://art/combat/") or \
			not normalized.get_extension().to_lower() in ["png", "webp"] or \
			not ResourceLoader.exists(normalized):
		return null
	var loaded := ResourceLoader.load(normalized)
	return loaded as Texture2D if loaded is Texture2D else null


func _draw_external_actor(art: Dictionary, position: Vector2, scale_value: float,
		pose: String, enemy_side: bool) -> bool:
	var body_value: Variant = art.get("body", null)
	if not body_value is Texture2D:
		return false
	var body: Texture2D = body_value
	var source_size := body.get_size()
	if source_size.x <= 1.0 or source_size.y <= 1.0:
		return false
	var target_height := minf(float(art.get("display_height", 226.0)) * scale_value,
		size.y * 0.88)
	var target_size := Vector2(target_height * source_size.x / source_size.y, target_height)
	var pivot: Vector2 = art.get("pivot", Vector2(0.5, 0.96))
	var movement := Vector2(0.0, sin(elapsed * 2.15 + (1.2 if enemy_side else 0.0)) * 2.4)
	var facing := -1.0 if enemy_side else 1.0
	var rotation := sin(elapsed * 1.18 + (0.8 if enemy_side else 0.0)) * 0.008
	match pose:
		"attack":
			movement.x += facing * 18.0 * scale_value
			rotation += facing * 0.045
		"charge":
			movement.x -= facing * 4.0 * scale_value
			movement.y -= 4.0 * scale_value
		"guard":
			movement.x -= facing * 6.0 * scale_value
			rotation -= facing * 0.018
		"hit":
			movement.x -= facing * 12.0 * scale_value
			rotation -= facing * 0.055
	var actor_origin := position + movement
	var rect := Rect2(-target_size.x * pivot.x, -target_size.y * pivot.y, target_size.x, target_size.y)
	var key_color := Color(enemy_color if enemy_side else accent, 0.12)
	_draw_external_layer(art.get("aura", null), actor_origin, rect.grow(10.0 * scale_value),
		enemy_side, rotation * 0.45, Color(1.0, 1.0, 1.0, 0.55))
	for key_offset in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		_draw_external_layer(body, actor_origin + key_offset * scale_value, rect, enemy_side,
			rotation, key_color)
	_draw_external_layer(art.get("back", null), actor_origin, rect, enemy_side, rotation,
		Color.WHITE)
	var body_modulate := Color(1.0, 0.72, 0.68, 1.0) if pose == "hit" else Color.WHITE
	if pose == "defeat":
		body_modulate = Color(0.58, 0.62, 0.65, 0.76)
	_draw_external_layer(body, actor_origin, rect, enemy_side, rotation, body_modulate)
	var weapon_value: Variant = art.get("weapon", null)
	if pose == "attack" and weapon_value is Texture2D:
		for echo_index in range(3, 0, -1):
			_draw_external_layer(weapon_value,
				actor_origin - Vector2(facing * echo_index * 7.0, echo_index * 1.5) * scale_value,
				rect, enemy_side, rotation - facing * echo_index * 0.018,
				Color(1.0, 0.90, 0.58, 0.08 + echo_index * 0.04))
	_draw_external_layer(weapon_value, actor_origin, rect, enemy_side, rotation, Color.WHITE)
	if pose == "guard":
		draw_arc(actor_origin + Vector2(facing * 8.0, -target_size.y * 0.48),
			target_size.y * 0.38, -PI * 0.68, PI * 0.68, 42,
			Color("d7ece8", 0.46), 2.4 * scale_value, true)
	return true


func _draw_external_layer(texture_value: Variant, origin: Vector2, rect: Rect2,
		enemy_side: bool, rotation: float, modulate: Color) -> void:
	if not texture_value is Texture2D:
		return
	var mirror := -1.0 if enemy_side else 1.0
	draw_set_transform(origin, rotation, Vector2(mirror, 1.0))
	draw_texture_rect(texture_value as Texture2D, rect, false, modulate)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_player(position: Vector2, scale_value: float, pose: String) -> void:
	if _draw_external_actor(player_art_layers, position, scale_value, pose, false):
		return
	_draw_catalog_player(position, scale_value, pose)
	return
	var pixel := _pixel_size(scale_value)
	var root := position
	if pose == "idle" and int(floor(elapsed * 1.6)) % 2 == 1:
		root.y -= pixel
	elif pose == "hit":
		root.x -= pixel * 2.0
	var outline := Color("111a1b")
	var deep := Color(accent.darkened(0.67), 1.0)
	var cloth := Color(accent.darkened(0.48), 1.0)
	var light := Color(accent.darkened(0.19), 1.0)
	var trim := Color("d8b862")
	var skin := Color("d9c9ad")
	var hair := Color("172023")
	# Feet and lower robe.
	_pixel_rect(root, pixel, Rect2i(-7, -4, 15, 4), outline)
	_pixel_rect(root, pixel, Rect2i(-6, -8, 13, 4), outline)
	_pixel_rect(root, pixel, Rect2i(-5, -12, 11, 4), outline)
	_pixel_rect(root, pixel, Rect2i(-4, -16, 9, 4), outline)
	_pixel_rect(root, pixel, Rect2i(-6, -3, 13, 2), deep)
	_pixel_rect(root, pixel, Rect2i(-5, -7, 11, 4), cloth)
	_pixel_rect(root, pixel, Rect2i(-4, -11, 9, 4), cloth)
	_pixel_rect(root, pixel, Rect2i(-3, -15, 7, 4), cloth)
	_pixel_rect(root, pixel, Rect2i(-4, -10, 2, 7), light)
	_pixel_rect(root, pixel, Rect2i(2, -14, 1, 11), deep)
	_pixel_rect(root, pixel, Rect2i(3, -10, 1, 7), trim)
	_pixel_rect(root, pixel, Rect2i(-6, 0, 4, 2), outline)
	_pixel_rect(root, pixel, Rect2i(3, 0, 4, 2), outline)
	# Head, topknot and face are framed in dark pixels for a stable reading size.
	_pixel_rect(root, pixel, Rect2i(-3, -23, 7, 7), outline)
	_pixel_rect(root, pixel, Rect2i(-2, -22, 5, 5), skin)
	_pixel_rect(root, pixel, Rect2i(-3, -24, 6, 3), hair)
	_pixel_rect(root, pixel, Rect2i(-1, -27, 3, 3), hair)
	_pixel_rect(root, pixel, Rect2i(2, -26, 4, 1), trim)
	_pixel_rect(root, pixel, Rect2i(2, -20, 1, 1), Color("43362d"))
	# Pose-specific sword arm. Each keyframe uses the same integer grid.
	if pose == "attack":
		_pixel_rect(root, pixel, Rect2i(3, -15, 7, 3), outline)
		_pixel_rect(root, pixel, Rect2i(4, -14, 6, 1), light)
		_pixel_rect(root, pixel, Rect2i(9, -14, 2, 2), skin)
		_pixel_line(root, pixel, Vector2i(10, -14), Vector2i(24, -14), outline, 2)
		_pixel_line(root, pixel, Vector2i(11, -14), Vector2i(25, -14), Color("e7e3d4"), 1)
		_pixel_rect(root, pixel, Rect2i(24, -15, 3, 1), Color("f1d88b"))
		for after_index in range(3):
			_pixel_rect(root, pixel, Rect2i(16 + after_index * 3, -17 + after_index, 2, 1),
				Color(accent, 0.34 - after_index * 0.08))
	elif pose == "guard":
		_pixel_rect(root, pixel, Rect2i(2, -16, 5, 4), outline)
		_pixel_rect(root, pixel, Rect2i(3, -15, 3, 2), light)
		_pixel_line(root, pixel, Vector2i(7, -22), Vector2i(7, -5), outline, 2)
		_pixel_line(root, pixel, Vector2i(7, -23), Vector2i(7, -6), Color("e5e2d5"), 1)
		_pixel_rect(root, pixel, Rect2i(5, -14, 5, 1), trim)
	elif pose == "charge":
		_pixel_rect(root, pixel, Rect2i(2, -17, 6, 4), outline)
		_pixel_rect(root, pixel, Rect2i(3, -16, 4, 2), light)
		_pixel_line(root, pixel, Vector2i(7, -16), Vector2i(16, -26), outline, 2)
		_pixel_line(root, pixel, Vector2i(8, -16), Vector2i(17, -27), Color("e8e3d2"), 1)
		for spark_index in range(4):
			var spark_frame := (spark_index + int(floor(elapsed * 6.0))) % 4
			_pixel_rect(root, pixel, Rect2i(12 + spark_index * 2, -29 + spark_frame, 1, 1),
				Color("efd47e", 0.74))
	elif pose == "hit":
		_pixel_rect(root, pixel, Rect2i(2, -16, 4, 3), outline)
		_pixel_rect(root, pixel, Rect2i(3, -15, 3, 1), Color("b65a4f"))
		_pixel_line(root, pixel, Vector2i(5, -15), Vector2i(12, -8), outline, 2)
		_pixel_line(root, pixel, Vector2i(6, -15), Vector2i(13, -8), Color("d5d2c8"), 1)
	else:
		_pixel_rect(root, pixel, Rect2i(3, -16, 6, 4), outline)
		_pixel_rect(root, pixel, Rect2i(4, -15, 4, 2), light)
		_pixel_rect(root, pixel, Rect2i(8, -14, 2, 2), skin)
		_pixel_line(root, pixel, Vector2i(9, -14), Vector2i(18, -23), outline, 2)
		_pixel_line(root, pixel, Vector2i(10, -14), Vector2i(19, -24), Color("dddace"), 1)
		_pixel_rect(root, pixel, Rect2i(17, -25, 3, 1), trim)


func _draw_enemy(position: Vector2, scale_value: float, pose: String) -> void:
	if _draw_external_actor(enemy_art_layers, position, scale_value, pose, true):
		return
	_draw_catalog_enemy(position, scale_value, pose)
	return
	var enemy_id := str(battle.get("enemy_id", ""))
	if "wolf" in enemy_id or "hound" in enemy_id or "beast" in enemy_id:
		_draw_beast_enemy(position, scale_value, enemy_id, pose)
	elif "void" in enemy_id:
		_draw_void_enemy(position, scale_value, pose)
	else:
		_draw_humanoid_enemy(position, scale_value, pose)


func _draw_beast_enemy(position: Vector2, scale_value: float, enemy_id: String,
		pose: String) -> void:
	var pixel := _pixel_size(scale_value)
	var root := position
	if pose == "idle" and int(floor(elapsed * 1.8)) % 2 == 1:
		root.y -= pixel
	elif pose == "charge":
		root.x += pixel
	elif pose == "attack":
		root.x -= pixel * 3.0
	elif pose == "hit":
		root.x += pixel * 2.0
	var outline := Color("21191a")
	var deep := Color(enemy_color.darkened(0.56), 1.0)
	var hide := Color(enemy_color.darkened(0.30), 1.0)
	var rim := Color(enemy_color.lightened(0.13), 1.0)
	var mane := Color("5b3733")
	# Layered body strips create a readable fur mass without vector silhouettes.
	_pixel_rect(root, pixel, Rect2i(-7, -12, 15, 3), outline)
	_pixel_rect(root, pixel, Rect2i(-9, -9, 19, 6), outline)
	_pixel_rect(root, pixel, Rect2i(-7, -3, 15, 3), outline)
	_pixel_rect(root, pixel, Rect2i(-6, -11, 13, 3), hide)
	_pixel_rect(root, pixel, Rect2i(-8, -8, 17, 5), hide)
	_pixel_rect(root, pixel, Rect2i(-6, -3, 13, 2), deep)
	_pixel_rect(root, pixel, Rect2i(-4, -10, 8, 2), rim)
	_pixel_rect(root, pixel, Rect2i(4, -7, 4, 3), deep)
	# Neck, ears and muzzle face the player.
	_pixel_rect(root, pixel, Rect2i(-11, -14, 7, 9), outline)
	_pixel_rect(root, pixel, Rect2i(-13, -16, 7, 7), outline)
	_pixel_rect(root, pixel, Rect2i(-16, -13, 6, 4), outline)
	_pixel_rect(root, pixel, Rect2i(-12, -15, 5, 5), mane)
	_pixel_rect(root, pixel, Rect2i(-15, -12, 5, 2), hide)
	_pixel_rect(root, pixel, Rect2i(-12, -19, 2, 4), outline)
	_pixel_rect(root, pixel, Rect2i(-8, -18, 2, 4), outline)
	_pixel_rect(root, pixel, Rect2i(-11, -18, 1, 3), rim)
	_pixel_rect(root, pixel, Rect2i(-14, -13, 1, 1), Color("f0c675"))
	_pixel_rect(root, pixel, Rect2i(-16, -11, 1, 1), Color("c9a48a"))
	# Four articulated legs retain their stance during motion frames.
	for leg_x in [-6, 5]:
		var front_shift := -2 if pose == "attack" and leg_x < 0 else 0
		_pixel_rect(root, pixel, Rect2i(leg_x, -2, 3, 8), outline)
		_pixel_rect(root, pixel, Rect2i(leg_x + 1, -1, 1, 6), hide)
		_pixel_rect(root, pixel, Rect2i(leg_x - 1 + front_shift, 5, 4, 2), outline)
	# A stepped tail is animated by one grid cell, never fractional pixels.
	var tail_frame := int(floor(elapsed * 2.0)) % 2
	_pixel_line(root, pixel, Vector2i(8, -9), Vector2i(14, -14 - tail_frame), outline, 3)
	_pixel_line(root, pixel, Vector2i(9, -9), Vector2i(15, -15 - tail_frame), hide, 1)
	_pixel_rect(root, pixel, Rect2i(14, -17 - tail_frame, 3, 3), rim)
	if "hound" in enemy_id:
		_pixel_rect(root, pixel, Rect2i(-1, -7, 5, 1), Color("b18b55"))
		_pixel_rect(root, pixel, Rect2i(0, -9, 1, 5), Color("d2aa67"))
	if pose == "charge":
		_pixel_rect(root, pixel, Rect2i(-17, -10, 3, 2), outline)
		_pixel_rect(root, pixel, Rect2i(-16, -9, 2, 1), Color("d87561"))
		for charge_index in range(3):
			_pixel_rect(root, pixel, Rect2i(-20 - charge_index * 3,
				-13 + ((charge_index + int(floor(elapsed * 8.0))) % 3), 1, 1),
				Color("d6a660", 0.72))
	elif pose == "guard":
		for plate_index in range(4):
			_pixel_rect(root, pixel, Rect2i(-5 + plate_index * 3, -14 - plate_index % 2,
				2, 3), outline)
			_pixel_rect(root, pixel, Rect2i(-4 + plate_index * 3, -13 - plate_index % 2,
				1, 2), rim)
	if pose == "phase":
		for shard_index in range(6):
			var sx := -14 + shard_index * 5
			var sy := -20 + ((shard_index + int(floor(elapsed * 5.0))) % 4) * 3
			_pixel_rect(root, pixel, Rect2i(sx, sy, 1, 2), Color("dd7464", 0.78))


func _draw_humanoid_enemy(position: Vector2, scale_value: float, pose: String) -> void:
	var pixel := _pixel_size(scale_value)
	var root := position
	if pose == "idle" and int(floor(elapsed * 1.5)) % 2 == 1:
		root.y -= pixel
	elif pose == "hit":
		root.x += pixel * 2.0
	var outline := Color("19191b")
	var deep := Color(enemy_color.darkened(0.62), 1.0)
	var cloth := Color(enemy_color.darkened(0.36), 1.0)
	var rim := Color(enemy_color.lightened(0.12), 1.0)
	var metal := Color("c8c1ae")
	_pixel_rect(root, pixel, Rect2i(-7, -4, 15, 4), outline)
	_pixel_rect(root, pixel, Rect2i(-6, -9, 13, 5), outline)
	_pixel_rect(root, pixel, Rect2i(-5, -15, 11, 6), outline)
	_pixel_rect(root, pixel, Rect2i(-6, -3, 13, 2), deep)
	_pixel_rect(root, pixel, Rect2i(-5, -8, 11, 4), cloth)
	_pixel_rect(root, pixel, Rect2i(-4, -14, 9, 6), cloth)
	_pixel_rect(root, pixel, Rect2i(2, -13, 2, 10), deep)
	_pixel_rect(root, pixel, Rect2i(-4, -12, 2, 8), rim)
	_pixel_rect(root, pixel, Rect2i(-3, -23, 7, 8), outline)
	_pixel_rect(root, pixel, Rect2i(-2, -22, 5, 5), Color("bba991"))
	_pixel_rect(root, pixel, Rect2i(-4, -25, 9, 4), deep)
	_pixel_rect(root, pixel, Rect2i(-2, -27, 5, 3), rim)
	_pixel_rect(root, pixel, Rect2i(-1, -20, 3, 1), Color("5a3736"))
	if pose == "attack":
		_pixel_rect(root, pixel, Rect2i(-9, -16, 7, 4), outline)
		_pixel_rect(root, pixel, Rect2i(-8, -15, 5, 2), rim)
		_pixel_line(root, pixel, Vector2i(-9, -15), Vector2i(-24, -11), outline, 2)
		_pixel_line(root, pixel, Vector2i(-10, -15), Vector2i(-25, -11), metal, 1)
		_pixel_rect(root, pixel, Rect2i(-27, -12, 4, 2), Color("e0d5bd"))
	elif pose == "guard":
		_pixel_rect(root, pixel, Rect2i(-8, -16, 6, 5), outline)
		_pixel_rect(root, pixel, Rect2i(-7, -15, 4, 3), rim)
		_pixel_line(root, pixel, Vector2i(-8, -23), Vector2i(-8, -4), outline, 2)
		_pixel_line(root, pixel, Vector2i(-8, -24), Vector2i(-8, -5), metal, 1)
	elif pose == "charge":
		_pixel_rect(root, pixel, Rect2i(-8, -17, 6, 4), outline)
		_pixel_rect(root, pixel, Rect2i(-7, -16, 4, 2), rim)
		_pixel_line(root, pixel, Vector2i(-7, -16), Vector2i(-14, -28), outline, 2)
		_pixel_line(root, pixel, Vector2i(-8, -16), Vector2i(-15, -29), metal, 1)
		for charge_index in range(3):
			_pixel_rect(root, pixel, Rect2i(-19 + charge_index * 4,
				-30 + ((charge_index + int(floor(elapsed * 7.0))) % 3), 1, 1),
				Color("d6a268", 0.68))
	else:
		_pixel_rect(root, pixel, Rect2i(-8, -16, 6, 4), outline)
		_pixel_rect(root, pixel, Rect2i(-7, -15, 4, 2), rim)
		_pixel_line(root, pixel, Vector2i(-8, -15), Vector2i(-18, -24), outline, 2)
		_pixel_line(root, pixel, Vector2i(-9, -15), Vector2i(-19, -25), metal, 1)
	if pose == "phase":
		for shard_index in range(5):
			_pixel_rect(root, pixel, Rect2i(-10 + shard_index * 5,
				-28 + ((shard_index + int(floor(elapsed * 6.0))) % 3) * 4, 1, 2),
				Color("d56c60", 0.78))


func _draw_void_enemy(position: Vector2, scale_value: float, pose: String) -> void:
	var pixel := _pixel_size(scale_value)
	var root := position
	var frame := int(floor(elapsed * 2.4)) % 2
	if pose == "idle" and frame == 1:
		root.y -= pixel
	elif pose == "hit":
		root.x += pixel * 2.0
	var outline := Color("15131c")
	var abyss := Color("241d31")
	var cloth := Color("443653")
	var rim := Color("806b91") if pose != "phase" else Color("b06a70")
	_pixel_rect(root, pixel, Rect2i(-8, -4, 17, 4), outline)
	_pixel_rect(root, pixel, Rect2i(-7, -9, 15, 5), outline)
	_pixel_rect(root, pixel, Rect2i(-6, -15, 13, 6), outline)
	_pixel_rect(root, pixel, Rect2i(-5, -20, 11, 5), outline)
	_pixel_rect(root, pixel, Rect2i(-7, -3, 4, 2), abyss)
	_pixel_rect(root, pixel, Rect2i(-2, -3, 4, 3), cloth)
	_pixel_rect(root, pixel, Rect2i(4, -3, 4, 2), abyss)
	_pixel_rect(root, pixel, Rect2i(-6, -8, 13, 4), cloth)
	_pixel_rect(root, pixel, Rect2i(-5, -14, 11, 5), abyss)
	_pixel_rect(root, pixel, Rect2i(-4, -19, 9, 4), cloth)
	_pixel_rect(root, pixel, Rect2i(-4, -26, 9, 7), outline)
	_pixel_rect(root, pixel, Rect2i(-3, -25, 7, 6), abyss)
	_pixel_rect(root, pixel, Rect2i(-2, -23, 2, 1), Color("c6a4d2"))
	_pixel_rect(root, pixel, Rect2i(3, -13, 2, 8), rim)
	for wisp_index in range(4):
		var wx := -13 + wisp_index * 8
		var wy := -22 + ((wisp_index + frame) % 3) * 5
		_pixel_rect(root, pixel, Rect2i(wx, wy, 2, 2), Color(rim, 0.54))
		_pixel_rect(root, pixel, Rect2i(wx + 1, wy - 2, 1, 2), Color(rim, 0.34))
	if pose == "attack":
		_pixel_line(root, pixel, Vector2i(-6, -15), Vector2i(-19, -15), outline, 3)
		_pixel_line(root, pixel, Vector2i(-7, -15), Vector2i(-20, -15), rim, 1)
		_pixel_rect(root, pixel, Rect2i(-23, -18, 4, 7), Color(rim, 0.56))
	elif pose == "charge":
		_pixel_line(root, pixel, Vector2i(-5, -17), Vector2i(-14, -26), outline, 3)
		_pixel_line(root, pixel, Vector2i(-6, -17), Vector2i(-15, -27), rim, 1)
		for charge_index in range(4):
			_pixel_rect(root, pixel, Rect2i(-20 + charge_index * 4,
				-30 + ((charge_index + int(floor(elapsed * 7.0))) % 4), 2, 2),
				Color(rim, 0.52))
	elif pose == "guard":
		for guard_y in range(-21, -5, 4):
			_pixel_rect(root, pixel, Rect2i(-13, guard_y, 2, 3), Color("8ba5ad", 0.68))
	if pose == "phase":
		for fracture_index in range(7):
			var fx := -15 + fracture_index * 5
			var fy := -29 + ((fracture_index + int(floor(elapsed * 7.0))) % 5) * 5
			_pixel_rect(root, pixel, Rect2i(fx, fy, 1, 2), Color("d86f70", 0.78))


func _draw_intent(enemy_position: Vector2, player_position: Vector2, scale_value: float) -> void:
	var intent := str(battle.get("intent", "strike"))
	_draw_enemy_signature_vfx(enemy_position, scale_value)
	var progress := 0.24 + fposmod(elapsed * 0.20, 1.0) * 0.58
	if intent == "guard":
		var barrier_center := enemy_position + Vector2(-18, -2) * scale_value
		draw_arc(barrier_center, 54.0 * scale_value, PI * 0.63, PI * 1.37, 34,
			Color("88b3bd", 0.46), 3.0 * scale_value, true)
		draw_arc(barrier_center, 47.0 * scale_value, PI * 0.66, PI * 1.34, 30,
			Color("d2e1dc", 0.15), 1.0 * scale_value, true)
		return
	if intent == "weaken":
		for index in range(3):
			var angle := elapsed * 0.32 + float(index) * TAU / 3.0
			var orb := enemy_position + Vector2(cos(angle) * 61.0, sin(angle) * 34.0) * scale_value
			draw_circle(orb, 2.8 * scale_value, Color("8f789b", 0.58))
			_draw_broken_line(orb, player_position, Color("8f789b", 0.12),
				1.0 * scale_value, 7.0 * scale_value)
		return
	var direction := (player_position - enemy_position).normalized()
	var normal := Vector2(-direction.y, direction.x)
	if intent == "heavy":
		var tip := enemy_position.lerp(player_position, progress * 0.90)
		var wedge := PackedVector2Array([
			enemy_position + normal * 12.0 * scale_value,
			enemy_position - normal * 12.0 * scale_value,
			tip,
		])
		draw_colored_polygon(wedge, Color("b94e4c", 0.045))
		draw_line(enemy_position + normal * 12.0 * scale_value, tip,
			Color("bd5952", 0.52), 2.6 * scale_value, true)
		draw_line(enemy_position - normal * 12.0 * scale_value, tip,
			Color("bd5952", 0.32), 1.4 * scale_value, true)
		for mark_index in range(2):
			var mark_center := player_position - direction * (28.0 + mark_index * 12.0) * scale_value
			draw_line(mark_center - normal * 8.0 * scale_value,
				mark_center + normal * 8.0 * scale_value, Color("bd5952", 0.42),
				1.3 * scale_value, true)
		return
	var intent_color := Color("a94853") if intent == "bleed" else Color("b98755")
	var start: Vector2 = enemy_position + direction * 54.0 * scale_value
	var destination: Vector2 = player_position - direction * 50.0 * scale_value
	_draw_broken_line(start, destination, Color(intent_color, 0.20), 1.0 * scale_value,
		10.0 * scale_value)
	var moving_tip := start.lerp(destination, progress)
	draw_line(moving_tip - direction * 22.0 * scale_value, moving_tip,
		Color(intent_color, 0.68), (2.2 if intent == "bleed" else 1.7) * scale_value, true)
	draw_line(moving_tip, moving_tip - direction * 8.0 * scale_value + normal * 5.0 * scale_value,
		Color(intent_color, 0.52), 1.2 * scale_value, true)
	draw_line(moving_tip, moving_tip - direction * 8.0 * scale_value - normal * 5.0 * scale_value,
		Color(intent_color, 0.52), 1.2 * scale_value, true)


func _draw_clash_line(player_position: Vector2, enemy_position: Vector2,
		scale_value: float) -> void:
	var midpoint := player_position.lerp(enemy_position, 0.5)
	var energy := 0.22 + sin(elapsed * 1.7) * 0.05
	draw_line(player_position + Vector2(38, -18) * scale_value,
		enemy_position + Vector2(-48, -4) * scale_value, Color(accent, 0.05), 1.0, true)
	draw_circle(midpoint, 2.4 * scale_value, Color("d6c590", energy))
	draw_circle(midpoint, 8.0 * scale_value, Color("d6c590", energy * 0.08))


func _draw_latest_feedback(player_position: Vector2, enemy_position: Vector2,
		scale_value: float) -> void:
	if feedback_cue.is_empty():
		return
	_draw_semantic_feedback(player_position, enemy_position, scale_value)
	return
	var fade := clampf(1.0 - elapsed / 1.20, 0.0, 1.0)
	if fade <= 0.0:
		return
	var player_hit := feedback_actor == "enemy" or feedback_cue == "combat_enemy_hit"
	var target := player_position if player_hit else enemy_position
	var source := enemy_position if player_hit else player_position
	var pixel := _pixel_size(scale_value)
	target += Vector2(0, -26) * scale_value
	source += Vector2(0, -26) * scale_value
	target = _snap_to_pixel(target, pixel)
	source = _snap_to_pixel(source, pixel)
	var impact_color := Color("f06458") if player_hit else Color("f5d77c")
	if feedback_kind == "phase_shift":
		impact_color = Color("d57b64")
		var phase_progress := clampf(elapsed / 0.75, 0.0, 1.0)
		for slash_index in range(5):
			var angle := -1.1 + float(slash_index) * 0.48
			var slash_start := target + Vector2(cos(angle), sin(angle)) * 12.0 * scale_value
			var slash_end := target + Vector2(cos(angle), sin(angle)) * (26.0 + phase_progress * 34.0) * scale_value
			_pixel_world_line(slash_start, slash_end, pixel,
				Color(impact_color, fade * 0.50), 1 + slash_index % 2)
		return
	if feedback_kind == "shield" or feedback_cue in ["combat_guard", "combat_enemy_guard"]:
		var barrier := target + Vector2(-8.0 if not player_hit else 8.0, -2.0) * scale_value
		for barrier_index in range(13):
			var barrier_angle := lerpf(-PI * 0.72, PI * 0.72, float(barrier_index) / 12.0)
			var barrier_pixel := _snap_to_pixel(barrier + Vector2(cos(barrier_angle),
				sin(barrier_angle)) * 30.0 * scale_value, pixel)
			_pixel_rect(Vector2.ZERO, pixel, Rect2i(roundi(barrier_pixel.x / pixel),
				roundi(barrier_pixel.y / pixel), 1, 2), Color("a5cfca", fade * 0.66))
		for shard_index in range(3):
			var shard_angle := -0.48 + shard_index * 0.48
			var shard := barrier + Vector2(cos(shard_angle), sin(shard_angle)) * 31.0 * scale_value
			_pixel_world_line(shard,
				shard + Vector2(-sin(shard_angle), cos(shard_angle)) * 7.0 * scale_value,
				pixel, Color("d9e8dc", fade * 0.46), 1)
		return
	if feedback_kind == "heal":
		for ray_index in range(5):
			var angle := float(ray_index) * TAU / 6.0 + elapsed * 0.65
			var start := target + Vector2(cos(angle), sin(angle)) * 12.0 * scale_value
			var end := target + Vector2(cos(angle), sin(angle)) * 29.0 * scale_value
			_pixel_world_line(start, end, pixel, Color("9bcab2", fade * 0.60), 1)
		return
	var travel := clampf(elapsed / 0.52, 0.0, 1.0)
	var impact := _snap_to_pixel(source.lerp(target, travel), pixel)
	for offset in [-5.0, 0.0, 5.0]:
		var direction := (target - source).normalized()
		var normal := Vector2(-direction.y, direction.x)
		_pixel_world_line(source + normal * offset * scale_value,
			impact + normal * offset * scale_value,
			pixel, Color(impact_color, fade * 0.48), 1)
	if travel > 0.56:
		var burst_fade := fade * clampf((travel - 0.56) / 0.44, 0.0, 1.0)
		_pixel_rect(Vector2.ZERO, pixel, Rect2i(roundi(target.x / pixel) - 1,
			roundi(target.y / pixel) - 1, 3, 3), Color(impact_color, burst_fade * 0.20))
		for spark_index in range(7):
			var spark_seed := float((feedback_seed + spark_index * 31) % 97) / 97.0
			var spark_angle := spark_seed * TAU
			var spark_start := target + Vector2(cos(spark_angle), sin(spark_angle)) * 5.0 * scale_value
			var spark_end := target + Vector2(cos(spark_angle), sin(spark_angle)) * (11.0 + spark_seed * 16.0) * scale_value
			_pixel_world_line(spark_start, spark_end, pixel,
				Color(impact_color, burst_fade * 0.66), 1)


func _draw_enemy_signature_vfx(enemy_position: Vector2, scale_value: float) -> void:
	var profile := CombatVisualCatalogScript.enemy_profile_for_battle(battle)
	var vfx_id := str(battle.get("vfx_profile_id", profile.get("vfx_profile_id", "vfx.fallback")))
	var signature := CombatVisualCatalogScript.signature_vfx_profile(vfx_id)
	var pixel := _pixel_size(scale_value)
	var root := _snap_to_pixel(enemy_position, pixel)
	var palette: Array = signature.get("palette", ["#a86f6d", "#e6c184"])
	var marks: Array = signature.get("marks", [])
	for index in range(marks.size()):
		var mark: Array = marks[index]
		if mark.size() < 4:
			continue
		var pulse := 0.26 + sin(elapsed * (1.3 + index * 0.2) + index) * 0.08
		_pixel_rect(root, pixel, Rect2i(int(mark[0]), int(mark[1]), int(mark[2]), int(mark[3])),
			Color(str(palette[index % palette.size()]), pulse))
	_draw_signature_composition(root, pixel, str(signature.get("shape", "shards")),
		Color(str(palette[0]), 0.42), Color(str(palette[1]), 0.30))


func _draw_signature_composition(root: Vector2, pixel: float, shape: String,
		primary: Color, secondary: Color) -> void:
	match shape:
		"droplets":
			for index in range(7):
				_pixel_line(root, pixel, Vector2i(-22 + index * 7, -35 - index % 2 * 5),
					Vector2i(-24 + index * 7, -18 + index % 3), primary, 1)
			_pixel_line(root, pixel, Vector2i(-24, 4), Vector2i(22, 4), secondary, 2)
		"shards":
			for index in range(10):
				var angle := float(index) * TAU / 10.0 + elapsed * 0.25
				var point := Vector2i(roundi(cos(angle) * 24.0), roundi(-17 + sin(angle) * 18.0))
				_pixel_rect(root, pixel, Rect2i(point, Vector2i(2 + index % 2, 4)), primary)
		"ink":
			_pixel_line(root, pixel, Vector2i(-30,-33), Vector2i(25,-12), primary, 3)
			_pixel_line(root, pixel, Vector2i(-25,-28), Vector2i(18,-6), secondary, 2)
			for index in range(6):
				_pixel_rect(root, pixel, Rect2i(-23 + index * 9, -8 + index % 2 * 3, 5, 2), primary)
		"vents":
			for index in range(5):
				var x := -19 + index * 10
				_pixel_line(root, pixel, Vector2i(x, -7), Vector2i(x - 4 + index % 3, -37), primary, 2)
				_pixel_rect(root, pixel, Rect2i(x - 6, -42 - index % 2 * 4, 7, 3), secondary)
		"seal":
			for inset in range(3):
				var left := -29 + inset * 6
				var top := -39 + inset * 6
				var width := 58 - inset * 12
				var height := 43 - inset * 12
				_pixel_line(root, pixel, Vector2i(left, top), Vector2i(left + width, top), primary)
				_pixel_line(root, pixel, Vector2i(left, top), Vector2i(left, top + height), primary)
				_pixel_line(root, pixel, Vector2i(left + width, top), Vector2i(left + width, top + height), primary)
		"furnace":
			_draw_pixel_diamond(root, pixel, Vector2i(0,-18), Vector2i(25,25), primary)
			_draw_pixel_diamond(root, pixel, Vector2i(0,-18), Vector2i(16,16), secondary)
			for index in range(6):
				_pixel_line(root, pixel, Vector2i(-15 + index * 6, -5),
					Vector2i(-11 + index * 5, -35 - index % 3 * 5), primary, 2)
		"scan":
			for index in range(5):
				var y := -39 + index * 10
				_pixel_line(root, pixel, Vector2i(-31 + index % 2 * 5, y),
					Vector2i(31 - index % 2 * 5, y), primary, 1 + index % 2)
			_pixel_line(root, pixel, Vector2i(-27,-43), Vector2i(-27,6), secondary, 2)
		"refraction":
			for index in range(8):
				var x := -29 + index * 8
				_pixel_line(root, pixel, Vector2i(x,-38 + index % 3 * 5),
					Vector2i(x + 11,-7 - index % 2 * 5), primary, 2)
		"rollback":
			for index in range(4):
				var inset := index * 6
				_pixel_line(root, pixel, Vector2i(28 - inset,-42 + inset),
					Vector2i(-29 + inset,-42 + inset), primary, 2)
				_pixel_line(root, pixel, Vector2i(-29 + inset,-42 + inset),
					Vector2i(-29 + inset,-4 - inset), secondary, 1)
			_pixel_rect(root, pixel, Rect2i(23,-46,7,7), primary)
		"rain":
			for index in range(11):
				var x := -31 + index * 6
				_pixel_line(root, pixel, Vector2i(x,-45 + index % 4 * 3),
					Vector2i(x - 5,-10 + index % 3 * 4), primary, 1 + index % 2)
			_pixel_line(root, pixel, Vector2i(-34,5), Vector2i(30,5), secondary, 3)
		"plunder":
			for index in range(6):
				var y := -37 + index * 7
				_pixel_line(root, pixel, Vector2i(31,y), Vector2i(8,y + 4), primary, 2)
				_pixel_rect(root, pixel, Rect2i(-26 + index * 4,-28 + index % 3 * 6,5,3), secondary)
		"eclipse":
			_draw_pixel_diamond(root, pixel, Vector2i(0,-24), Vector2i(29,29), primary)
			_draw_pixel_diamond(root, pixel, Vector2i(6,-28), Vector2i(20,20), Color("081012", 0.76))
			for index in range(8):
				var angle := float(index) * TAU / 8.0
				_pixel_line(root, pixel, Vector2i(roundi(cos(angle)*31),roundi(-24+sin(angle)*31)),
					Vector2i(roundi(cos(angle)*38),roundi(-24+sin(angle)*38)), secondary, 2)
		"receipt":
			for index in range(6):
				_pixel_rect(root, pixel, Rect2i(-29 + index * 10,-40 + index % 2 * 5,7,3), primary)
				_pixel_line(root, pixel, Vector2i(-26 + index * 10,-37),
					Vector2i(-22 + index * 8,-8), secondary, 1)
		"silence":
			for index in range(5):
				var y := -39 + index * 9
				_pixel_line(root, pixel, Vector2i(-31 + index * 3,y),
					Vector2i(31 - index * 3,y), primary, 3)
				_pixel_rect(root, pixel, Rect2i(-3,y-2,7,5), Color("081012", 0.88))
		"meridian":
			_pixel_line(root, pixel, Vector2i(0,-45), Vector2i(0,4), primary, 2)
			for index in range(7):
				var y := -39 + index * 7
				_pixel_line(root, pixel, Vector2i(0,y), Vector2i(-20 + index % 2 * 40,y+5), secondary, 2)
				_pixel_rect(root, pixel, Rect2i(-2,y-2,5,5), primary)
		"law":
			for index in range(3):
				var radius := 15 + index * 10
				for side in range(8):
					var angle := float(side) * TAU / 8.0 + index * 0.18
					var point := Vector2i(roundi(cos(angle)*radius),roundi(-22+sin(angle)*radius))
					_pixel_rect(root, pixel, Rect2i(point,Vector2i(4,2)), primary if index % 2 == 0 else secondary)
		"unbound":
			for index in range(7):
				_pixel_line(root, pixel, Vector2i(-34,-42 + index * 7),
					Vector2i(34,-29 + index * 6), primary, 1 + index % 3)
		"erasure":
			for index in range(5):
				var y := -41 + index * 9
				_pixel_line(root, pixel, Vector2i(-32,y), Vector2i(30,y+5), primary, 3)
				_pixel_rect(root, pixel, Rect2i(-15 + index * 6,y-1,20,4), Color("081012",0.66))
		_:
			_draw_pixel_diamond(root, pixel, Vector2i(0,-20), Vector2i(24,24), primary)


func _draw_pixel_diamond(root: Vector2, pixel: float, center: Vector2i,
		radius: Vector2i, color: Color) -> void:
	_pixel_line(root, pixel, center + Vector2i(0,-radius.y), center + Vector2i(radius.x,0), color, 2)
	_pixel_line(root, pixel, center + Vector2i(radius.x,0), center + Vector2i(0,radius.y), color, 2)
	_pixel_line(root, pixel, center + Vector2i(0,radius.y), center + Vector2i(-radius.x,0), color, 2)
	_pixel_line(root, pixel, center + Vector2i(-radius.x,0), center + Vector2i(0,-radius.y), color, 2)


func _draw_semantic_feedback(player_position: Vector2, enemy_position: Vector2,
		scale_value: float) -> void:
	var fade := clampf(1.0 - elapsed / 1.20, 0.0, 1.0)
	if fade <= 0.0:
		return
	var normalized_cue := CombatVisualCatalogScript.normalize_cue(feedback_cue, feedback_kind)
	var profile := CombatVisualCatalogScript.vfx_profile(normalized_cue)
	var shape := str(profile.get("shape", "slash"))
	var palette: Array = profile.get("palette", ["#f2d58c", "#fff0c0"])
	var primary := Color(str(palette[0]), fade * 0.72)
	var secondary := Color(str(palette[1]), fade * 0.52)
	var player_hit := feedback_actor == "enemy" or feedback_cue == "combat_enemy_hit"
	var target := player_position if player_hit else enemy_position
	var source := enemy_position if player_hit else player_position
	var pixel := _pixel_size(scale_value)
	target = _snap_to_pixel(target + Vector2(0, -27) * scale_value, pixel)
	source = _snap_to_pixel(source + Vector2(0, -27) * scale_value, pixel)
	var travel := clampf(elapsed / 0.50, 0.0, 1.0)
	match shape:
		"barrier":
			for index in range(15):
				var angle := lerpf(-PI * 0.72, PI * 0.72, float(index) / 14.0)
				var point := _snap_to_pixel(target + Vector2(cos(angle), sin(angle)) * 31.0 * scale_value, pixel)
				_pixel_rect(Vector2.ZERO, pixel, Rect2i(roundi(point.x / pixel), roundi(point.y / pixel), 1, 2), primary)
		"sigil":
			for index in range(8):
				var angle := float(index) * TAU / 8.0 + elapsed * 0.8
				var a := target + Vector2(cos(angle), sin(angle)) * 13.0 * scale_value
				var b := target + Vector2(cos(angle + 1.7), sin(angle + 1.7)) * 29.0 * scale_value
				_pixel_world_line(a, b, pixel, primary, 1)
		"ripple":
			for index in range(3):
				var radius := (9.0 + index * 9.0 + elapsed * 8.0) * scale_value
				for segment in range(12):
					var angle := float(segment) * TAU / 12.0
					var point := target + Vector2(cos(angle) * radius, sin(angle) * radius * 0.42)
					_pixel_rect(Vector2.ZERO, pixel, Rect2i(roundi(point.x / pixel), roundi(point.y / pixel), 1, 1), primary)
		"droplets":
			for index in range(7):
				var point := target + Vector2(-18 + index * 6, -12 + ((feedback_seed + index * 3) % 8)) * scale_value
				_pixel_world_line(point, point + Vector2(-2, 8 + index % 3) * scale_value, pixel, primary, 1)
		"chains":
			for index in range(6):
				var point := target + Vector2(-22 + index * 8, -13 + index % 2 * 8) * scale_value
				_pixel_rect(Vector2.ZERO, pixel, Rect2i(roundi(point.x / pixel), roundi(point.y / pixel), 3, 2), primary)
		"fracture":
			for index in range(10):
				var angle := -1.3 + float(index) * 0.28
				_pixel_world_line(target + Vector2(cos(angle), sin(angle)) * 8.0 * scale_value,
					target + Vector2(cos(angle + 0.08), sin(angle + 0.08)) * (24.0 + index * 2.0) * scale_value,
					pixel, primary, 1 + index % 2)
		"burst":
			for index in range(12):
				var angle := float(index) * TAU / 12.0
				_pixel_world_line(target + Vector2(cos(angle), sin(angle)) * 5.0 * scale_value,
					target + Vector2(cos(angle), sin(angle)) * 35.0 * scale_value, pixel, primary, 1)
		"spiral":
			var previous := target
			for index in range(18):
				var angle := float(index) * 0.66
				var point := target + Vector2(cos(angle), sin(angle)) * (3.0 + index * 1.4) * scale_value
				_pixel_world_line(previous, point, pixel, primary, 1)
				previous = point
		_:
			var impact := source.lerp(target, travel)
			for offset in [-4.0, 0.0, 4.0]:
				var direction := (target - source).normalized()
				var normal := Vector2(-direction.y, direction.x)
				_pixel_world_line(source + normal * offset * scale_value,
					impact + normal * offset * scale_value, pixel, primary, 1)
			if travel > 0.55:
				for index in range(7):
					var angle := float((feedback_seed + index * 31) % 97) / 97.0 * TAU
					_pixel_world_line(target, target + Vector2(cos(angle), sin(angle)) * (11.0 + index * 2.0) * scale_value,
						pixel, secondary, 1)


func _draw_counter_beats(scale_value: float) -> void:
	var progress := clampi(int(battle.get("counter_chain", 0)), 0, 3)
	var center_x := size.x * 0.50
	var y := size.y * 0.91
	for beat_index in range(3):
		var point := Vector2(center_x + (float(beat_index) - 1.0) * 19.0 * scale_value, y)
		var filled := beat_index < progress
		var diamond := PackedVector2Array([
			point + Vector2(0, -5) * scale_value, point + Vector2(5, 0) * scale_value,
			point + Vector2(0, 5) * scale_value, point + Vector2(-5, 0) * scale_value,
		])
		draw_colored_polygon(diamond, Color(accent, 0.78) if filled else Color(0.30, 0.37, 0.37, 0.28))
		draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]),
			Color(accent, 0.60) if filled else Color(0.49, 0.55, 0.52, 0.22), 1.0, true)


func debug_capture_sprite(kind: String, pose: String, frame_time: float = 0.20) -> Dictionary:
	if kind == "player":
		return debug_capture_player("insight", "iron_sword", "cloud_robe",
			"black_white_jade", "", pose, frame_time)
	var enemy_id: String = str({
		"wolf": "classical_razor_wolf",
		"humanoid": "classical_oath_breaker",
		"void": "star_void_daemon",
	}.get(kind, kind))
	return debug_capture_enemy(enemy_id, pose, frame_time)


func debug_validate_external_art_contract() -> Dictionary:
	var valid_identity := _safe_art_identity("story_enemy-01")
	var invalid_identity := _safe_art_identity("../outside")
	var rejected_outside := _load_battle_texture("res://art/portraits/protagonist.png")
	var rejected_missing := _load_battle_texture(
		"res://art/combat/characters/missing/battle_body.png")
	return {
		"ok": valid_identity == "story_enemy-01" and invalid_identity.is_empty() and
			rejected_outside == null and rejected_missing == null,
		"valid_identity": valid_identity,
		"outside_rejected": rejected_outside == null,
		"missing_rejected": rejected_missing == null,
	}


func debug_capture_enemy(enemy_id: String, pose: String, frame_time: float = 0.20) -> Dictionary:
	var previous_elapsed := elapsed
	var previous_battle := battle.duplicate(true)
	debug_capture_only = true
	debug_pixel_cells.clear()
	elapsed = frame_time
	battle = {"enemy_id": enemy_id}
	_draw_catalog_enemy(Vector2.ZERO, 1.0, pose)
	debug_capture_only = false
	elapsed = previous_elapsed
	battle = previous_battle
	return _debug_capture_result(enemy_id, pose)


func debug_capture_player(path_id: String, weapon_id: String, armor_id: String,
		relic_id: String, jade_weapon_id: String, pose: String,
		frame_time: float = 0.20) -> Dictionary:
	var previous_elapsed := elapsed
	var previous_battle := battle.duplicate(true)
	debug_capture_only = true
	debug_pixel_cells.clear()
	elapsed = frame_time
	battle = {"visual_loadout": {"path_id": path_id, "weapon_id": weapon_id,
		"armor_id": armor_id, "relic_id": relic_id, "jade_weapon_id": jade_weapon_id}}
	_draw_catalog_player(Vector2.ZERO, 1.0, pose)
	debug_capture_only = false
	elapsed = previous_elapsed
	battle = previous_battle
	return _debug_capture_result("player:%s:%s:%s:%s:%s" % [path_id, weapon_id,
		armor_id, relic_id, jade_weapon_id], pose)


func debug_capture_vfx(cue: String, kind: String = "damage",
		frame_time: float = 0.34) -> Dictionary:
	var previous_elapsed := elapsed
	var previous_cue := feedback_cue
	var previous_kind := feedback_kind
	var previous_actor := feedback_actor
	debug_capture_only = true
	debug_pixel_cells.clear()
	elapsed = frame_time
	feedback_cue = cue
	feedback_kind = kind
	feedback_actor = "player"
	_draw_semantic_feedback(Vector2(-40, 0), Vector2(40, 0), 1.0)
	debug_capture_only = false
	elapsed = previous_elapsed
	feedback_cue = previous_cue
	feedback_kind = previous_kind
	feedback_actor = previous_actor
	return _debug_capture_result("vfx:%s" % cue, kind)


func debug_capture_enemy_weapon(profile_id: String, pose: String = "idle") -> Dictionary:
	debug_capture_only = true
	debug_pixel_cells.clear()
	_draw_enemy_weapon(Vector2.ZERO, 2.0, profile_id, pose, Color("e9d18a"))
	debug_capture_only = false
	return _debug_capture_result("enemy_weapon:%s" % profile_id, pose)


func debug_capture_signature_vfx(enemy_id: String) -> Dictionary:
	var previous_battle := battle.duplicate(true)
	debug_capture_only = true
	debug_pixel_cells.clear()
	var profile := CombatVisualCatalogScript.enemy_profile(enemy_id)
	battle = {"enemy_id": enemy_id, "visual_profile_id": profile.get("profile_id", ""),
		"vfx_profile_id": profile.get("vfx_profile_id", "")}
	_draw_enemy_signature_vfx(Vector2.ZERO, 1.0)
	debug_capture_only = false
	battle = previous_battle
	return _debug_capture_result("signature_vfx:%s" % enemy_id, "intent")


func _debug_capture_result(kind: String, pose: String) -> Dictionary:
	var cells := debug_pixel_cells.duplicate()
	var keys: Array = cells.keys()
	keys.sort()
	var serialized := PackedStringArray()
	var minimum := Vector2i(100000, 100000)
	var maximum := Vector2i(-100000, -100000)
	for key_value in keys:
		var key := str(key_value)
		serialized.append("%s=%s" % [key, cells[key]])
		var components := key.split(":")
		if components.size() == 2:
			var point := Vector2i(int(components[0]), int(components[1]))
			minimum.x = mini(minimum.x, point.x)
			minimum.y = mini(minimum.y, point.y)
			maximum.x = maxi(maximum.x, point.x)
			maximum.y = maxi(maximum.y, point.y)
	var dimensions := Vector2i.ZERO if keys.is_empty() else maximum - minimum + Vector2i.ONE
	return {
		"kind": kind,
		"pose": pose,
		"cell_count": keys.size(),
		"hash": hash("|".join(serialized)),
		"minimum": minimum,
		"maximum": maximum,
		"dimensions": dimensions,
	}


func debug_validate_pixel_pipeline() -> Dictionary:
	var failures: Array[String] = []
	var definitions := CombatVisualCatalogScript.validate_definitions()
	for failure in definitions.get("failures", []):
		failures.append("catalog:%s" % failure)
	var poses := ["idle", "charge", "attack", "hit", "guard", "phase"]
	var identity_hashes := {}
	var pose_count := 0
	for enemy_id in CombatVisualCatalogScript.enemy_ids():
		var pose_hashes: Dictionary = {}
		for pose_value in poses:
			var pose := str(pose_value)
			var capture := debug_capture_enemy(str(enemy_id), pose, 0.20)
			var count := int(capture.get("cell_count", 0))
			var dimensions: Vector2i = capture.get("dimensions", Vector2i.ZERO)
			var capture_hash := int(capture.get("hash", 0))
			pose_count += 1
			if count < 80:
				failures.append("%s/%s detail threshold:%d" % [enemy_id, pose, count])
			if dimensions.x > 72 or dimensions.y > 72 or dimensions.x <= 0 or dimensions.y <= 0:
				failures.append("%s/%s bounds:%s" % [enemy_id, pose, dimensions])
			if pose_hashes.has(capture_hash):
				failures.append("%s poses %s and %s render the same cells" % [
					enemy_id, pose_hashes[capture_hash], pose])
			pose_hashes[capture_hash] = pose
			if pose == "idle":
				if identity_hashes.has(capture_hash):
					failures.append("enemy identity collision:%s:%s" % [identity_hashes[capture_hash], enemy_id])
				identity_hashes[capture_hash] = enemy_id
		var idle_low := debug_capture_enemy(str(enemy_id), "idle", 0.10)
		var idle_high := debug_capture_enemy(str(enemy_id), "idle", 0.82)
		if int(idle_low.get("hash", 0)) == int(idle_high.get("hash", 0)):
			failures.append("%s idle breathing frames are identical" % enemy_id)
	var weapon_hashes := {}
	for weapon_id in CombatVisualCatalogScript.jade_weapon_ids():
		var capture := debug_capture_player("insight", "iron_sword", "cloud_robe",
			"black_white_jade", str(weapon_id), "idle", 0.20)
		var capture_hash := int(capture.get("hash", 0))
		if weapon_hashes.has(capture_hash):
			failures.append("jade weapon collision:%s:%s" % [weapon_hashes[capture_hash], weapon_id])
		weapon_hashes[capture_hash] = weapon_id
	var enemy_weapon_hashes := {}
	var signature_vfx_hashes := {}
	for enemy_id in CombatVisualCatalogScript.enemy_ids():
		var profile := CombatVisualCatalogScript.enemy_profile(str(enemy_id))
		var weapon_profile_id := str(profile.get("weapon_profile_id", ""))
		var weapon_capture := debug_capture_enemy_weapon(weapon_profile_id)
		var weapon_hash := int(weapon_capture.get("hash", 0))
		if enemy_weapon_hashes.has(weapon_hash):
			failures.append("enemy weapon collision:%s:%s" % [enemy_weapon_hashes[weapon_hash], enemy_id])
		enemy_weapon_hashes[weapon_hash] = enemy_id
		var signature_capture := debug_capture_signature_vfx(str(enemy_id))
		var signature_hash := int(signature_capture.get("hash", 0))
		if signature_vfx_hashes.has(signature_hash):
			failures.append("signature vfx collision:%s:%s" % [signature_vfx_hashes[signature_hash], enemy_id])
		signature_vfx_hashes[signature_hash] = enemy_id
	var path_hashes := {}
	for path_id in CombatVisualCatalogScript.path_ids():
		var capture := debug_capture_player(str(path_id), "iron_sword", "cloud_robe",
			"black_white_jade", "", "idle", 0.20)
		var capture_hash := int(capture.get("hash", 0))
		if path_hashes.has(capture_hash):
			failures.append("path collision:%s:%s" % [path_hashes[capture_hash], path_id])
		path_hashes[capture_hash] = path_id
	var cue_hashes := {}
	var cue_kinds := {"combat.impact":"damage", "combat.guard":"shield", "combat.spell":"spell",
		"combat.heal":"heal", "combat.status.bleed":"damage", "combat.status.weak":"damage",
		"combat.phase":"phase_shift", "combat.break":"damage", "combat.swap":"phase_shift"}
	for cue in cue_kinds:
		var capture := debug_capture_vfx(str(cue), str(cue_kinds[cue]))
		var capture_hash := int(capture.get("hash", 0))
		if cue_hashes.has(capture_hash):
			failures.append("vfx collision:%s:%s" % [cue_hashes[capture_hash], cue])
		cue_hashes[capture_hash] = cue
	return {
		"ok": failures.is_empty(),
		"failures": failures,
		"enemy_count": identity_hashes.size(),
		"path_count": path_hashes.size(),
		"jade_weapon_count": weapon_hashes.size(),
		"enemy_weapon_count": enemy_weapon_hashes.size(),
		"signature_vfx_count": signature_vfx_hashes.size(),
		"vfx_count": cue_hashes.size(),
		"pose_count": pose_count,
		"pixel_sizes": [_pixel_size(0.70), _pixel_size(1.0), _pixel_size(1.35)],
	}


func _actor_pose(side: String) -> String:
	var source_side := "enemy" if feedback_actor == "enemy" else "player"
	var target_side := "player" if source_side == "enemy" else "enemy"
	if elapsed <= 0.72 and not feedback_kind.is_empty():
		if feedback_kind == "phase_shift" and side == "enemy":
			return "phase"
		if feedback_kind == "shield" and side == source_side:
			return "guard"
		if feedback_kind == "damage":
			if side == source_side:
				return "charge" if elapsed < 0.16 else "attack"
			if side == target_side and elapsed >= 0.30:
				return "hit"
	if side == "enemy" and bool(battle.get("second_phase_active", false)) and elapsed < 0.62:
		return "phase"
	if side == "player" and bool(battle.get("counter_burst_ready", false)):
		return "charge"
	return "idle"


func _pixel_size(scale_value: float) -> float:
	# Four-pixel cells at the standard half-screen stage give the sprites a
	# deliberate pixel-art silhouette instead of making them read as UI icons.
	return float(maxi(3, int(round(scale_value * 3.5))))


func _snap_to_pixel(value: Vector2, pixel: float) -> Vector2:
	return Vector2(round(value.x / pixel) * pixel, round(value.y / pixel) * pixel)


func _pixel_rect(origin: Vector2, pixel: float, tile_rect: Rect2i, color: Color) -> void:
	var top_left := origin + Vector2(tile_rect.position) * pixel
	var dimensions := Vector2(tile_rect.size) * pixel
	if debug_capture_only:
		var cell_origin := Vector2i(roundi(top_left.x / pixel), roundi(top_left.y / pixel))
		for cell_y in range(tile_rect.size.y):
			for cell_x in range(tile_rect.size.x):
				debug_pixel_cells["%d:%d" % [cell_origin.x + cell_x, cell_origin.y + cell_y]] = \
					color.to_html(true)
		return
	draw_rect(Rect2(top_left, dimensions), color, true)


func _pixel_line(origin: Vector2, pixel: float, from_tile: Vector2i, to_tile: Vector2i,
		color: Color, thickness: int = 1) -> void:
	var x := from_tile.x
	var y := from_tile.y
	var dx := absi(to_tile.x - from_tile.x)
	var sx := 1 if from_tile.x < to_tile.x else -1
	var dy := -absi(to_tile.y - from_tile.y)
	var sy := 1 if from_tile.y < to_tile.y else -1
	var error := dx + dy
	while true:
		_pixel_rect(origin, pixel, Rect2i(x - thickness / 2, y - thickness / 2,
			thickness, thickness), color)
		if x == to_tile.x and y == to_tile.y:
			break
		var doubled := error * 2
		if doubled >= dy:
			error += dy
			x += sx
		if doubled <= dx:
			error += dx
			y += sy


func _pixel_world_line(from_point: Vector2, to_point: Vector2, pixel: float,
		color: Color, thickness: int = 1) -> void:
	_pixel_line(Vector2.ZERO, pixel,
		Vector2i(roundi(from_point.x / pixel), roundi(from_point.y / pixel)),
		Vector2i(roundi(to_point.x / pixel), roundi(to_point.y / pixel)), color, thickness)


func _feedback_shake(scale_value: float) -> Vector2:
	if feedback_kind not in ["damage", "phase_shift"] or elapsed > 0.24:
		return Vector2.ZERO
	var strength := (1.0 - elapsed / 0.24) * 4.0 * scale_value
	return Vector2(sin(elapsed * 85.0 + feedback_seed) * strength,
		cos(elapsed * 71.0 + feedback_seed * 0.7) * strength * 0.42)


func _ellipse_arc_points(center: Vector2, radii: Vector2, start_angle: float,
		end_angle: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments + 1):
		var t := float(index) / float(segments)
		var angle := lerpf(start_angle, end_angle, t)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points


func _draw_broken_line(from_point: Vector2, to_point: Vector2, color: Color,
		width: float, dash_length: float) -> void:
	var distance := from_point.distance_to(to_point)
	if distance <= 0.1:
		return
	var direction := (to_point - from_point) / distance
	var cursor := 0.0
	while cursor < distance:
		var segment_start := from_point + direction * cursor
		var segment_end := from_point + direction * minf(cursor + dash_length * 0.56, distance)
		draw_line(segment_start, segment_end, color, width, true)
		cursor += dash_length


func _ratio(value_key: String, maximum_key: String) -> float:
	return clampf(float(battle.get(value_key, 0)) / maxf(1.0,
		float(battle.get(maximum_key, 1))), 0.0, 1.0)
