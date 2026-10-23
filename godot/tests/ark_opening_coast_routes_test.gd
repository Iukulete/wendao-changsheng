extends SceneTree

## Focused PRODUCTION movement gate, not the full original traversal observer.
## Only new inner walking legs, old-cove settling/south exit, and nearshore sail.
## The two historical outer-lip no-jump failures remain BASELINE-KNOWN in frozen
## raw traversal evidence (exit42); they are NOT run, weakened or relabeled here.
## Input, route budgets, 60-frame dwell and native hull/anchor checks retain the
## frozen traversal_refinement05/sailing_refined05/cove_south_probe contracts.
## Initial position/phase fixtures are explicit below. No midroute teleport,
## controller, floor angle, swim rule, speed, water height or tick-rate changes.
const Paths = preload("res://tests/ark_test_paths.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
const Scene = preload("res://scenes/ark_greybox.tscn")
var game: Node3D
var coast: RefCounted
var saves: RefCounted
var save_root: String
var failures := 0
var checks := 0
var frame := 0
var keys: Dictionary = {}
var report: Dictionary = {"scope": "two inner walking legs; cove settle/south; nearshore sailing", "known_outer_lip_raw_exit": 42, "fixtures": []}
var active: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error("OPENING_COAST_ROUTES: " + label)
		if not active.is_empty():
			active.failures.append({"message": label, "state": _feet()})
	return ok

func _player() -> CharacterBody3D:
	return game.get("player") as CharacterBody3D

func _vector(point: Vector3) -> Array:
	return [point.x, point.y, point.z]

func _freeze() -> void:
	game.set_process(false)
	game.set_physics_process(false)

func _resume() -> void:
	game.set_process(true)
	game.set_physics_process(true)

func _spawn(label: String) -> void:
	_release()
	saves.clear_for_test()
	game = Scene.instantiate() as Node3D
	game.set("save_root_override", save_root)
	root.add_child(game)
	_freeze()
	coast = game.get("opening_coast") as RefCounted
	frame = 0
	active = {"label": label, "failures": [], "route": [], "samples": [], "transitions": []}
	_check(coast != null and bool(game.get("opening_coast_result").get("ok", false)), label + " uses initialized native production terrain")
	_check(not game.get_meta("save_load_blocked", false), label + " fresh synthetic scene loads normally")
	_check(is_equal_approx(_player().floor_max_angle, deg_to_rad(45.0)), label + " retains canonical default floor angle")
	_check(is_equal_approx(float(game.get("water").mean_height), -1.05), label + " retains canonical mean water height")
	# Register current colliders before any movement queries. Simulation is frozen,
	# not PROCESS_MODE_DISABLED, so bodies remain in the actual physics space.
	await physics_frame

func _drop() -> void:
	_release()
	_freeze()
	active.physics_frames = frame
	active.final = _feet()
	active.game_state = {"wood": game.get("wood"), "shellfish": game.get("raw_shellfish"), "collected_ids": game.get("collected_ids").duplicate(), "day_count": game.get("day_count"), "day_period": game.get("day_period"), "life_period_elapsed": game.get("life_period_elapsed"), "water_time": game.get("water").time_seconds}
	report.fixtures.append(active)
	active = {}
	game.set("save_service", null)
	game.queue_free()
	game = null
	coast = null
	await process_frame

func _key(code: Key, pressed: bool) -> void:
	if keys.get(code, false) == pressed:
		return
	keys[code] = pressed
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	# Dispatch at this declared observer frame, not a later idle iteration.
	Input.flush_buffered_events()

func _release() -> void:
	for code in [KEY_A, KEY_D, KEY_W, KEY_S, KEY_SHIFT, KEY_SPACE, KEY_E]:
		_key(code, false)

func _tap(code: Key) -> void:
	_key(code, true)
	_key(code, false)

func _feet() -> Dictionary:
	if not is_instance_valid(game):
		return {}
	var player := _player()
	var point := player.global_position
	var shape: CollisionShape3D = player.get_child(0)
	var capsule := shape.shape as CapsuleShape3D
	var hits: Array = []
	for index in range(player.get_slide_collision_count()):
		var hit := player.get_slide_collision(index)
		hits.append({"collider": str(hit.get_collider().name), "normal": _vector(hit.get_normal())})
	return {"frame": frame, "position": _vector(point), "velocity": _vector(player.velocity), "capsule_foot_y": shape.global_position.y - capsule.height * 0.5, "terrain_height": coast.call("sample_height", point), "floor": player.is_on_floor(), "floor_normal": _vector(player.get_floor_normal()), "swimming": game.get("is_swimming"), "collisions": hits, "water_time": game.get("water").time_seconds, "water_height": game.get("water").query(point).height}

func _step(frames: int) -> void:
	for _index in range(frames):
		var old_swim: bool = game.get("is_swimming")
		var old_floor := _player().is_on_floor()
		await physics_frame
		frame += 1
		if frame % 120 == 0:
			active.samples.append(_feet())
		if old_swim != game.get("is_swimming") or old_floor != _player().is_on_floor():
			active.transitions.append(_feet())

func _go(label: String, target: Vector2, budget: int = 1400, sprint: bool = false) -> bool:
	# Same thresholds, per-key decisions, 180-frame stall window and budgets as
	# the original frozen traversal observer. No fallback jump in these two legs.
	_release()
	var start := _feet()
	var last := _player().global_position
	for index in range(budget):
		var point := _player().global_position
		var difference := target - Vector2(point.x, point.z)
		if difference.length() < 0.14:
			_release()
			await _step(8)
			active.route.append({"label": label, "target": [target.x, target.y], "start": start, "end": _feet(), "frames": index, "sprint": sprint})
			return true
		_key(KEY_A, difference.x < -0.07)
		_key(KEY_D, difference.x > 0.07)
		_key(KEY_W, difference.y < -0.07)
		_key(KEY_S, difference.y > 0.07)
		_key(KEY_SHIFT, sprint)
		await _step(1)
		if index > 0 and index % 180 == 0:
			if _player().global_position.distance_to(last) < 0.18:
				_release()
				_check(false, "stuck en route to " + label + " after " + str(index) + " frames")
				return false
			last = _player().global_position
	_release()
	_check(false, "budget exhausted en route to " + label)
	return false

func _inner_walk() -> void:
	await _spawn("inner_walking_legs")
	# One initial staged position at the ORIGINAL first-leg anchor, not an
	# alternative route or a transform correction after movement has begun.
	_player().global_position = Vector3(9, 1.5, -4)
	_player().velocity = Vector3.ZERO
	active.initial_fixture = {"position": _vector(_player().global_position), "reason": "start at first resource anchor; no outer-lip approach in this focused gate"}
	_resume()
	await _step(90)
	active.settled_start = _feet()
	_check(_player().is_on_floor() and not game.get("is_swimming"), "first resource fixture settles on original native controller")
	for row in [["TidalShellsNear", Vector2(8.4, -6.1)], ["residentMarker", Vector2(13, -6)]]:
		if not await _go(row[0], row[1], 1400, false):
			await _drop()
			return
		await _step(60)
		active.route[-1].settled_after_60_frames = _feet()
		var anchor := game.get_node(row[0]) as Node3D
		var distance := _player().global_position.distance_to(anchor.global_position)
		active.route[-1].anchor_distance_m = distance
		_check(distance < 2.8, "actual interaction distance retained at " + row[0])
		_check(_player().is_on_floor() and not game.get("is_swimming"), "new inner leg reaches walkable ground without any jump: " + row[0])
	_check(not keys.get(KEY_SPACE, false), "focused inner legs never request jump recovery")
	await _drop()

func _cove_south(cycle: int) -> void:
	await _spawn("old_cove_south_%d" % cycle)
	# Exact independent observed old canonical cove position from frozen QA
	# (capsule foot -0.2227737904). This is disclosed test setup, not a user save.
	_player().global_position = Vector3(11, -0.217773795127869, -5.2)
	_player().velocity = Vector3.ZERO
	# The original cove observer saved after 91 authority steps. Advance through
	# the existing water API to that initial phase; do not rewrite waves/height.
	var phase_ok := true
	for _water_step in range(91):
		phase_ok = bool(game.get("water").advance(1.0 / 60.0).get("ok", false)) and phase_ok
	_check(phase_ok, "cove fixture establishes original saved water phase through 91 unchanged authority steps")
	game.get("water").apply_visual((game.get_node("Sea") as MeshInstance3D).material_override)
	var start_xz := Vector2(_player().global_position.x, _player().global_position.z)
	active.initial_fixture = {"position": _vector(_player().global_position), "water": game.get("water").snapshot(), "source": "frozen old-cove actual native observation, then normal controller settlement"}
	if cycle == 2:
		await _step(2)
	_resume()
	for count in [1, 4, 25, 60, 90]:
		await _step(count)
		active.samples.append(_feet())
	var settled := _feet()
	active.settled = settled
	_check(settled.terrain_height != null and settled.floor and absf(float(settled.capsule_foot_y) - float(settled.terrain_height)) < 0.15, "old cove settles against actual lower collider without support teleport")
	_check(Vector2(_player().global_position.x, _player().global_position.z) == start_xz, "cove settlement preserves original XZ")
	var escape_start := _player().global_position
	_key(KEY_S, true)
	await _step(180)
	_release()
	active.escape_start = _vector(escape_start)
	active.escape_end = _feet()
	active.escape_distance = _player().global_position.distance_to(escape_start)
	_check(game.get("is_swimming") and not _player().is_on_floor() and _player().global_position.z - escape_start.z > 2.0, "actual S input exits the cove south into swimming within original 180-frame budget")
	await _drop()

func _sailing_state() -> Dictionary:
	var ark := game.get("ark_root") as Node3D
	return {"ark": _vector(ark.global_position), "yaw": ark.rotation.y, "blocked": game.get("ark_navigation_blocked")}

func _nearshore_sail() -> void:
	await _spawn("native_nearshore_sail")
	# No staged player/boat transform here: canonical fresh spawn and native E.
	_resume()
	await _step(90)
	active.start = _feet()
	_tap(KEY_E)
	await _step(2)
	if not _check(bool(game.get("sailing_mode")), "actual E at original helm engages native sailing"):
		await _drop()
		return
	var ark := game.get("ark_root") as Node3D
	active.sailing = {"start_ark": _vector(ark.global_position)}
	for action in [["reverse_to_open_water", KEY_S, 100], ["turn_east", KEY_A, 131], ["sail_east", KEY_W, 100], ["turn_north", KEY_D, 131]]:
		_key(action[1], true)
		await _step(action[2])
		_release()
		active.sailing[action[0]] = _sailing_state()
	var start := ark.global_position
	_key(KEY_W, true)
	var approach_frames := 0
	for _index in range(240):
		await _step(1)
		approach_frames += 1
		if game.get("ark_navigation_blocked"):
			break
	_release()
	var approach := _sailing_state()
	approach.frames = approach_frames
	approach.xz_distance = Vector2(ark.global_position.x - start.x, ark.global_position.z - start.z).length()
	active.sailing.approach = approach
	_check(bool(game.get("ark_navigation_blocked")), "nearshore approach establishes original native hull block within 240 frames")
	start = ark.global_position
	_key(KEY_W, true)
	await _step(30)
	_release()
	var held := _sailing_state()
	held.xz_drift = Vector2(ark.global_position.x - start.x, ark.global_position.z - start.z).length()
	held.native_hull_clear = bool(game.call("_is_ark_position_navigable", ark.global_position))
	active.sailing.held_block = held
	_check(held.native_hull_clear, "held nearshore input never leaves native hull overlap")
	_key(KEY_S, true)
	await _step(90)
	_release()
	var reverse := _sailing_state()
	reverse.xz_distance = Vector2(ark.global_position.x - start.x, ark.global_position.z - start.z).length()
	active.sailing.reverse_escape = reverse
	_check(not game.get("ark_navigation_blocked") and float(reverse.xz_distance) >= 3.0, "reverse escapes real coast block within original 90-frame budget")
	_key(KEY_A, true)
	await _step(131)
	_release()
	_key(KEY_S, true)
	await _step(100)
	_release()
	_key(KEY_D, true)
	await _step(131)
	_release()
	for _index in range(160):
		var point := ark.global_position
		if absf(point.z) < 0.08:
			break
		_key(KEY_W, point.z > 0.0)
		_key(KEY_S, point.z < 0.0)
		await _step(1)
	_release()
	active.sailing.return_ark = _vector(ark.global_position)
	active.sailing.return_xz_distance = Vector2(ark.global_position.x, ark.global_position.z).length()
	_check(float(active.sailing.return_xz_distance) <= 0.2, "actual return reaches original XZ vicinity, no boat teleport")
	_tap(KEY_E)
	await _step(2)
	active.sailing.exited = not game.get("sailing_mode")
	_check(active.sailing.exited, "actual E exits helm after native return")
	await _drop()

func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/test_opening_coast_routes_%d_%d" % [OS.get_process_id(), int(Time.get_unix_time_from_system() * 1000000)]).simplify_path()
	if not _check(Paths.is_safe_save_root(save_root), "unique isolated test root required"):
		quit(1)
		return
	_check(Engine.physics_ticks_per_second == 60, "route budgets retain original 60Hz physics contract")
	saves = Save.new(save_root)
	await _inner_walk()
	await _cove_south(1)
	await _cove_south(2)
	await _nearshore_sail()
	saves.clear_for_test()
	report.checks = checks
	report.failures = failures
	print("OPENING_COAST_ROUTES_OBSERVATIONS: ", JSON.stringify(report))
	if failures == 0:
		print("ARK_OPENING_COAST_ROUTES_TEST_OK: ", checks, " focused checks; known outer-lip full-route exit42 remains separate")
	else:
		print("ARK_OPENING_COAST_ROUTES_TEST_FAILED: ", failures, " / ", checks)
	quit(0 if failures == 0 else 1)
