extends SceneTree

## Independent geometry and distance oracle. Routine polyline expenditure is
## measured before/after every controlled call; net displacement alone can hide
## unpaid backtracking. Gathering intentionally retains its separate skip rule.
const Paths = preload("res://tests/ark_test_paths.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
const EPS := 0.000008
var game: Node3D
var saver: RefCounted
var save_root: String
var failures: Array[String] = []
var controlled_cases := 0
var front_checks := 0
var life_steps := 0
var life_arrivals := 0
var work_front_checks := 0
var gather_samples := {"tidekeeper/outbound": 0, "tidekeeper/returning": 0, "jade/outbound": 0, "jade/returning": 0}


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, explanation: String) -> void:
	if not ok:
		failures.append(explanation)
		printerr("MOTION_REGRESSION_FAILED: " + explanation)


func _spawn() -> void:
	game = load("res://scenes/ark_greybox.tscn").instantiate() as Node3D
	game.set("save_root_override", save_root)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	(game.get("player") as Node).set_physics_process(false)
	await physics_frame
	_check(not bool(game.get_meta("save_load_blocked", false)), "valid motion save must load without quarantine")


func _drop() -> void:
	game.set("save_service", null)
	game.queue_free()
	await process_frame


func _fresh() -> void:
	await _drop()
	saver.clear_for_test()
	await _spawn()


func _ark() -> Node3D:
	return game.get_node("ArkRoot") as Node3D


func _marker(id: String) -> Node3D:
	return game.get("traveler_marker" if id == "tidekeeper" else "sailmaker_marker") as Node3D


func _prefix(id: String) -> String:
	return "traveler" if id == "tidekeeper" else "sailmaker"


func _front(marker: Node3D) -> Vector3:
	# Actual rendered face/body positions include marker yaw, figure transforms,
	# ark rotation and idle bob; neither -basis.z nor a copied atan2 is an oracle.
	var face := marker.find_child("Face", true, false) as Node3D
	var body := marker.find_child("Body", true, false) as Node3D
	assert(face != null and body != null)
	var result := face.global_position - body.global_position
	result.y = 0.0
	_check(result.length() > 0.1, "actual face must establish a visible body-front")
	return result.normalized()


func _faces(marker: Node3D, world_direction: Vector3, context: String) -> void:
	world_direction.y = 0.0
	if world_direction.length() < 0.00001:
		return
	var alignment := _front(marker).dot(world_direction.normalized())
	_check(alignment > 0.999, "%s actual Face/body front dot=%s" % [context, alignment])
	front_checks += 1


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _owners() -> Variant:
	var saved: Dictionary = game.call("_build_save_state")
	return _json({"economy": saved.modules.economy, "construction": saved.modules.construction, "construction_sequence": saved.modules.construction_sequence, "world_events": saved.world_events, "event_sequence": saved.event_sequence})


func _economy() -> Variant:
	return _json((game.call("_build_save_state") as Dictionary).modules.economy)


func _events(id: String) -> int:
	var count := 0
	for event in game.get("world_events") as Array:
		if str(event.get("id", "")) == id:
			count += 1
	return count


func _route(id: String, points: PackedVector3Array) -> void:
	var prefix := _prefix(id)
	game.set(prefix + "_routine_route", points)
	game.set(prefix + "_routine_route_index", 0)
	game.set(prefix + "_routine_route_target", points[-1])
	game.set(prefix + "_routine_route_target_set", true)


func _arc_sample(start: Vector3, points: PackedVector3Array, budget: float) -> Dictionary:
	# Cumulative arc-length parameterization, independent of the mover's loop.
	var length := 0.0
	var from := start
	var last_leg := Vector3.ZERO
	for index in range(points.size()):
		var leg := points[index] - from
		var next_length := length + leg.length()
		if budget < next_length:
			return {"position": from + leg.normalized() * maxf(0.0, budget - length), "index": index, "direction": leg if budget > length else last_leg, "spent": budget}
		if leg.length() > 0.00001:
			last_leg = leg
		length = next_length
		from = points[index]
	return {"position": points[-1], "index": points.size(), "direction": last_leg, "spent": length}


func _controlled(id: String, start: Vector3, points: PackedVector3Array, delta: float, strict: bool, label: String) -> void:
	var marker := _marker(id)
	var speed := 0.72 if id == "tidekeeper" else 0.64
	marker.position = start
	marker.rotation.y = 0.31
	_route(id, points)
	var expected := _arc_sample(start, points, maxf(0.0, delta) * speed)
	var before_front := _front(marker)
	var moving: bool = game.call("_move_ark_resident_toward", marker, points[-1], delta, speed, id, strict)
	var error := marker.position.distance_to(expected.position)
	_check(error <= EPS, "%s/%s dt=%s strict=%s polyline expected=%s actual=%s error=%s budget=%s" % [id, label, delta, strict, expected.position, marker.position, error, maxf(0.0, delta) * speed])
	_check(int(game.get(_prefix(id) + "_routine_route_index")) == int(expected.index), label + " must pay for residuals before advancing the route cursor")
	_check(moving == (int(expected.index) < points.size()), label + " moving status must match paid route completion")
	if delta <= 0.0:
		_check(marker.position == start and _front(marker).is_equal_approx(before_front), "zero/negative time cannot move or turn a resident")
	elif float(expected.spent) > 0.00001:
		_faces(marker, _ark().global_basis * (expected.direction as Vector3), id + "/" + label)
	controlled_cases += 1


func _test_controlled_routes() -> void:
	for id in ["tidekeeper", "sailmaker"]:
		game.set("traveler_boarded" if id == "tidekeeper" else "sailmaker_boarded", true)
		game.call("_set_traveler_boarded" if id == "tidekeeper" else "_set_sailmaker_boarded")
	var owners: Variant = _owners()
	var origin := Vector3(0.0, 0.12, 0.0)
	for yaw in [0.0, 0.67, -1.13]:
		_ark().rotation.y = yaw
		for id in ["tidekeeper", "sailmaker"]:
			for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3(1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(-1, 0, -1)]:
				_controlled(id, origin, PackedVector3Array([origin + direction.normalized() * 0.8]), 0.05, false, "cardinal/diagonal yaw=" + str(yaw))
				if id == "sailmaker":
					_controlled(id, origin, PackedVector3Array([origin + direction.normalized() * 0.8]), 0.05, true, "strict cardinal/diagonal yaw=" + str(yaw))
	for id in ["tidekeeper", "sailmaker"]:
		for centimeters in range(1, 7):
			var residual := float(centimeters) / 100.0
			for delta in [0.0, -0.1, 0.0001, 0.001, 0.01, 0.05, 0.1, 0.25]:
				_controlled(id, origin, PackedVector3Array([origin + Vector3(residual, 0, 0), origin + Vector3(0.8, 0, 0)]), delta, false, "single residual=%scm" % centimeters)
				_controlled(id, origin, PackedVector3Array([origin + Vector3(residual, 0, 0)]), delta, false, "final approach=%scm" % centimeters)
				# Returning over a just-traversed segment hides distance in a net
				# displacement check. Every 1–6cm leg must still consume budget.
				var backtrack := PackedVector3Array([origin + Vector3(residual, 0, 0), origin, origin + Vector3(0, 0, residual), origin + Vector3(0.8, 0, residual)])
				_controlled(id, origin, backtrack, delta, false, "multi residual/backtrack=%scm" % centimeters)
		# Deliberate 90-degree turn: the final leg differs sharply from net move.
		var corner := PackedVector3Array([origin + Vector3(0.02, 0, 0), origin + Vector3(0.02, 0, 0.7)])
		_controlled(id, origin, corner, 0.05, false, "corner last-leg, not net displacement")
		var marker := _marker(id)
		var target := origin + Vector3(0.045, 0, 0)
		_controlled(id, origin, PackedVector3Array([target]), 0.1, false, "paid final approach")
		var settled := marker.position
		var settled_front := _front(marker)
		for delta in [0.0, 0.001, 0.05, 0.1]:
			_check(not bool(game.call("_move_ark_resident_toward", marker, target, delta, 0.72 if id == "tidekeeper" else 0.64, id)), "settled route must remain idle")
			_check(marker.position == settled and _front(marker).is_equal_approx(settled_front), "settling cannot creep, teleport or flip facing")
		# Planner tolerance is deliberately unchanged: a new sub-6cm route is
		# empty, unlike an already planned route's unpaid final residual.
		var near: PackedVector3Array = game.call("_build_ark_local_walk_route", origin, origin + Vector3(0.05, 0, 0))
		_check(near.is_empty(), "routine destination tolerance must remain 6cm")
	# Exact and numerical-zero waypoints may advance without movement, never
	# assign their tiny residual for free. A zero-delta call advances nothing.
	for id in ["tidekeeper", "sailmaker"]:
		var marker := _marker(id)
		var target := origin + Vector3(0, 0, 0.8)
		marker.position = origin
		_route(id, PackedVector3Array([origin, origin, target]))
		game.call("_move_ark_resident_toward", marker, target, 0.0, 0.64, id)
		_check(marker.position == origin and int(game.get(_prefix(id) + "_routine_route_index")) == 0, "zero dt cannot traverse even duplicate waypoints")
		game.call("_move_ark_resident_toward", marker, target, 0.05, 0.64, id)
		_check(marker.position.distance_to(origin + Vector3(0, 0, 0.032)) < EPS and int(game.get(_prefix(id) + "_routine_route_index")) == 2, "duplicate waypoints cannot stall paid movement")
		marker.position = origin
		_route(id, PackedVector3Array([origin + Vector3(0.000005, 0, 0), target]))
		game.call("_move_ark_resident_toward", marker, target, 0.05, 0.64, id)
		_check(absf(marker.position.x) < 0.0000001 and marker.position.distance_to(origin + Vector3(0, 0, 0.032)) < EPS, "numerical-zero skip must not assign its unpaid position")
		_faces(marker, _ark().global_basis * Vector3.BACK, id + "/numerical-zero skip paid leg")
		controlled_cases += 3
	_check(_owners() == owners, "controlled motion cannot mutate economy, construction or history")
	print("RESIDENT_MOTION_CONTROLLED: cases=", controlled_cases, " genuine front checks=", front_checks, "; zero/small/normal dt, 1–6cm final/residual/backtrack, arc expenditure, corners, rotated ark, strict routes and settling")


func _collect_resource(resource: String) -> void:
	for entry in (game.get("interactables") as Array).duplicate():
		if str(entry.get("id", "")) != resource:
			continue
		(game.get("player") as Node3D).global_position = (entry.node as Node3D).global_position
		game.call("_interact")
		return
	assert(false, "finite resource fixture exhausted: " + resource)


func _prepare_home(eligible_work: bool) -> void:
	_collect_resource("wood")
	_check(bool(game.call("_try_place_shelter", Vector3.ZERO)), "finite gathered wood must construct real shelter")
	game.set("weather_phase", 2)
	game.set("sailmaker_met", true)
	game.set("sailmaker_choice_pending", true)
	game.call("_choose_sailmaker_boarding", true)
	if eligible_work:
		for _period in range(4):
			var key := InputEventKey.new()
			key.pressed = true
			key.keycode = KEY_T
			game.call("_unhandled_key_input", key)
	game.set("resident_met", true)
	game.set("traveler_choice_pending", true)
	game.call("_choose_traveler_boarding", true)
	_check(bool(game.get("traveler_boarded")) and bool(game.get("sailmaker_boarded")), "both residents must really board")
	await physics_frame


func _last_routine_leg(id: String, before: Vector3, after: Vector3) -> Vector3:
	var route: PackedVector3Array = game.get(_prefix(id) + "_routine_route")
	var index := int(game.get(_prefix(id) + "_routine_route_index"))
	if index > 0 and after.distance_to(route[index - 1]) < EPS:
		return route[index - 1] - (route[index - 2] if index > 1 else before)
	if index < route.size():
		return route[index] - after
	return after - before


func _tick_life(context: String, delta: float = 0.05) -> void:
	var before := {"tidekeeper": _marker("tidekeeper").position, "sailmaker": _marker("sailmaker").position}
	game.call("_process", delta)
	for id in ["tidekeeper", "sailmaker"]:
		var marker := _marker(id)
		var moved := marker.position.distance_to(before[id])
		var speed := 0.72 if id == "tidekeeper" else 0.64
		_check(moved <= speed * delta + EPS, "%s/%s travel=%s exceeds physical speed×dt=%s" % [context, id, moved, speed * delta])
		var work_pose := false
		if id == "sailmaker" and bool(game.call("_sailmaker_awning_work_can_run")):
			var phase := str(game.get("sailmaker_awning_phase"))
			var installing := phase == "installing"
			var target: Vector3 = game.call("_sailmaker_awning_work_target", installing)
			work_pose = phase in ["sewing", "installing"] and marker.position.distance_to(target) <= 0.06001 and absf(marker.position.y - target.y) <= 0.02501
			if work_pose:
				var facing_target: Vector3 = game.call("_sailmaker_awning_work_target", true)
				var cloth := marker.get_node("OldSailBundle") as Node3D
				var body := marker.find_child("Body", true, false) as Node3D
				_check((cloth.global_position - body.global_position).dot(_front(marker)) > 0.1, "stationary work must retain cloth in the actual front half-plane")
				if not installing:
					_faces(marker, _ark().to_global(facing_target) - marker.global_position, "stationary sewing")
				work_front_checks += 1
		if moved > 0.00001 and not work_pose:
			_faces(marker, _ark().global_basis * _last_routine_leg(id, before[id], marker.position), context + "/" + id + "/last leg")
	life_steps += 1


func _walk_life(context: String, expected: Array[Vector3]) -> void:
	var settled := 0
	var traveled := [0.0, 0.0]
	_check((game.get("traveler_target_position") as Vector3).distance_to(expected[0]) < EPS and (game.get("sailmaker_target_position") as Vector3).distance_to(expected[1]) < EPS, context + " must preserve existing destination semantics")
	for _step in range(1000):
		var before: Array[Vector3] = [_marker("tidekeeper").position, _marker("sailmaker").position]
		_tick_life(context)
		var arrived := true
		for index in range(2):
			var marker := _marker("tidekeeper" if index == 0 else "sailmaker")
			traveled[index] += marker.position.distance_to(before[index])
			arrived = arrived and marker.position.distance_to(expected[index]) <= 0.06001
		settled = settled + 1 if arrived else 0
		if settled >= 20:
			break
	_check(settled >= 20, "%s must physically arrive and settle: actual=%s/%s target=%s" % [context, _marker("tidekeeper").position, _marker("sailmaker").position, expected])
	_check(traveled[0] > 0.1 or traveled[1] > 0.1, context + " must observe actual movement, not a posed endpoint")
	life_arrivals += 2 if settled >= 20 else 0


func _schedule() -> Array[Vector3]:
	game.call("_update_traveler_schedule")
	game.call("_update_sailmaker_schedule")
	return [game.get("traveler_target_position"), game.get("sailmaker_target_position")]


func _reload_exact() -> void:
	var owners: Variant = _owners()
	var positions := [_marker("tidekeeper").global_position, _marker("sailmaker").global_position]
	_check(bool(game.call("_save_progress")), "valid motion state must save")
	await _drop()
	await _spawn()
	_check(_owners() == owners, "reload cannot change economy/construction/history")
	_check(_marker("tidekeeper").global_position.distance_to(positions[0]) < 0.02 and _marker("sailmaker").global_position.distance_to(positions[1]) < 0.02, "reload must preserve actual resident positions")


func _test_home_life() -> void:
	await _fresh()
	await _prepare_home(true)
	_ark().rotation.y = 0.67
	_ark().position = Vector3(12, 0, 6)
	(game.get("player") as Node3D).global_position = Vector3(30, 1, 30)
	await physics_frame
	var economy: Variant = _economy()
	var paused_once := false
	var phases: Array[String] = []
	var install_fronts: Array[Dictionary] = []
	for _step in range(1200):
		var phase := str(game.get("sailmaker_awning_phase"))
		if not phases.has(phase):
			phases.append(phase)
		if bool(game.get("sailmaker_awning_raised")):
			break
		_tick_life("real awning " + phase)
		if game.get("sailmaker_awning_phase") == "installing" and bool(game.call("_sailmaker_at_awning_work_target", game.call("_sailmaker_awning_work_target", true))):
			install_fronts.append({"position": _marker("sailmaker").global_position, "front": _front(_marker("sailmaker"))})
		if not paused_once and game.get("sailmaker_awning_phase") == "carrying":
			paused_once = true
			var progress := [game.get("sailmaker_awning_phase"), game.get("sailmaker_awning_sewing_elapsed"), game.get("sailmaker_awning_install_elapsed")]
			game.set("weather_phase", 1)
			_schedule()
			for _pause in range(40):
				_tick_life("storm-paused work ordinary travel")
			_check(progress == [game.get("sailmaker_awning_phase"), game.get("sailmaker_awning_sewing_elapsed"), game.get("sailmaker_awning_install_elapsed")], "storm pause cannot earn or lose awning progress")
			await _reload_exact()
			game.set("weather_phase", 2)
			_schedule()
	_check(bool(game.get("sailmaker_awning_raised")) and paused_once and phases.has("sewing") and phases.has("installing"), "actual work must sew, carry, pause, resume and install")
	_check(_economy() == economy and _events("resident_sail_awning_raised") == 1, "work must preserve economy and create exactly one contribution")
	var canvas := game.get_node_or_null("ArkRoot/BuiltShelter/SailmakerAwning/PatchedCanvas") as Node3D
	assert(canvas != null)
	for sample in install_fronts:
		var direction: Vector3 = canvas.global_position - sample.position
		direction.y = 0.0
		_check((sample.front as Vector3).dot(direction.normalized()) > 0.95, "stationary installation must face the actual finished canvas")
	_check(install_fronts.size() > 10 and work_front_checks > 20, "stationary work needs sustained geometry evidence")
	var history: Variant = _owners()
	var shelter_origin: Vector3 = game.get("shelter_position")
	_walk_life("post-work routine transition", _schedule())
	game.set("day_period", 3)
	_schedule()
	_walk_life("night refuge", [shelter_origin + Vector3(0.5, 0.12, -0.5), shelter_origin + Vector3(-0.72, 0.12, 0.25)])
	game.set("day_period", 0)
	_walk_life("daytime refuge departure", _schedule())
	game.set("weather_phase", 1)
	_schedule()
	_walk_life("storm refuge", [shelter_origin + Vector3(0.5, 0.12, -0.5), shelter_origin + Vector3(-0.72, 0.12, 0.25)])
	_check(_owners() == history, "routine/night/storm movement cannot rewrite economy or history")
	game.set("weather_phase", 2)
	_collect_resource("shellfish")
	game.call("_interact_hearth")
	_check(int(game.get("stew_servings")) == 1, "finite shellfish must cook one meal")
	(game.get("player") as Node3D).global_position = _ark().to_global(Vector3(0.15, 0.19, 0.9))
	game.call("_begin_shared_table_meal")
	_check(bool(game.get("shared_meal_gathering_pending")), "actual meal reservation must start")
	_walk_life("shared meal", [shelter_origin + Vector3(-0.95, 0.12, -0.15), shelter_origin + Vector3(0.05, 0.12, 0.95)])
	_check(bool(game.call("_shared_table_ready")), "both real residents must be ready at the table")
	var eat := InputEventKey.new()
	eat.pressed = true
	eat.keycode = KEY_E
	game.call("_unhandled_key_input", eat)
	_check(int(game.get("shared_meal_count")) == 1 and _events("resident_meal_shared") == 1, "real meal input must consume exactly one shared meal")
	# Real finite salvage/build operations, rather than geometry-only flags.
	(game.get("player") as Node3D).global_position = Vector3(-53, 1.3, -45)
	game.call("_interact")
	_check(int(game.get("guest_cabin_frames")) == 1, "ledger must provide real unique cabin frame")
	(game.get("player") as Node3D).global_position = Vector3(33, 1, -34)
	game.call("_interact")
	if int(game.get("keel_beams")) == 0:
		# Resolve the unique keel interactable itself, never synthesize an item.
		for entry in game.get("interactables") as Array:
			if str(entry.get("id", "")) == "keel_wreck":
				(game.get("player") as Node3D).global_position = (entry.node as Node3D).global_position
				game.call("_interact")
				break
	while int(game.get("wood")) < 9:
		_collect_resource("wood")
	_check(bool(game.call("_try_place_workbench", Vector3(-2, 0.12, 1))), "finite wood must build prerequisite workbench")
	_check(bool(game.call("_try_place_raft_extension", Vector3(0, 0.12, -4.2))), "real keel and wood must build extension")
	_check(bool(game.call("_try_place_guest_cabin_template", Vector3(0, 0.12, -4.2))), "real frame and wood must build cabin")
	await physics_frame
	game.set("day_period", 3)
	_schedule()
	_walk_life("guest cabin/berth night", [Vector3(0.95, 0.24, -5.35), Vector3(-0.85, 0.12, -4.34)])
	_check(bool(game.get("sailmaker_guest_cabin_first_night")) and _events("resident_guest_cabin_occupied") == 1, "real cabin arrival must record occupancy exactly once")
	await _reload_exact()
	for _idle in range(20):
		_tick_life("persisted settled cabin")
	_check(_events("resident_guest_cabin_occupied") == 1 and _events("resident_sail_awning_raised") == 1 and _events("resident_meal_shared") == 1, "save/resume cannot replay one-time life events")
	print("RESIDENT_MOTION_LIFE: steps=", life_steps, " arrivals=", life_arrivals, " stationary work frames=", work_front_checks, "; real awning/pause/routine/night/storm/meal/cabin and persistence")


func _observe_gather(id: String) -> void:
	var jade := id == "jade"
	var pending := "jade_sail_industry_pending" if jade else "resident_gather_pending"
	var phase_key := "jade_sail_industry_phase" if jade else "resident_gather_phase"
	var process_method := "_process_jade_sail_industry_gathering" if jade else "_process_resident_gathering"
	var marker := game.get("jade_sail_keeper_marker") as Node3D if jade else _marker("tidekeeper")
	var reloaded := false
	for _step in range(1600):
		if not bool(game.get(pending)):
			break
		var phase := str(game.get(phase_key))
		var before := marker.global_position
		var parent := marker.get_parent()
		game.call(process_method, 0.05)
		var direction := marker.global_position - before
		# Delivery/recall may intentionally reparent/snap under their existing
		# separate tolerance contract; this regression does not redefine it.
		if marker.get_parent() == parent and phase in ["outbound", "returning"] and direction.length() > 0.0011:
			_faces(marker, direction, id + "/actual " + phase)
			gather_samples[id + "/" + phase] += 1
		if not reloaded and phase == "outbound" and int(gather_samples[id + "/outbound"]) > 10:
			reloaded = true
			var owners: Variant = _owners()
			var position := marker.global_position
			_check(bool(game.call("_save_progress")), "actual outbound gather must save")
			await _drop()
			await _spawn()
			marker = game.get("jade_sail_keeper_marker") as Node3D if jade else _marker("tidekeeper")
			_check(marker.global_position.distance_to(position) < 0.02 and _owners() == owners, "outbound reload must preserve position, reservation, economy and history")
	_check(not bool(game.get(pending)), id + " real outbound/pickup/return must finish")
	_check(reloaded and int(gather_samples[id + "/outbound"]) > 10 and int(gather_samples[id + "/returning"]) > 10, id + " must observe both real moving phases, including persistence")
	_check(bool(game.get("economy").audit().ok), "gathering must preserve economic audit")


func _test_actual_gatherers() -> void:
	await _fresh()
	await _prepare_home(false)
	_ark().rotation.y = -0.55
	await physics_frame
	var wood_before := int(game.get("wood"))
	_check(bool(game.call("_begin_resident_daily_gather")), "real finite tidekeeper gather must start")
	var tide_target := str(game.get("resident_gather_target_id"))
	await _observe_gather("tidekeeper")
	_check(tide_target in game.get("collected_ids") and int(game.get("wood")) == wood_before + 2, "tidekeeper delivery must transfer exactly the actual two-plank source")
	_check(_events("resident_gather_started") == 1 and _events("resident_gather_harvested") == 1 and _events("resident_gather_delivered") == 1, "tidekeeper task history must remain exact once")
	(game.get("player") as Node3D).global_position = Vector3(-53, 1.3, -45)
	game.call("_interact")
	while int(game.get("wood")) < 3:
		_collect_resource("wood")
	var keeper := game.get("jade_sail_keeper_marker") as Node3D
	for _talk in range(2):
		(game.get("player") as Node3D).global_position = keeper.global_position
		game.call("_interact")
	_check(bool(game.get("jade_sail_industry_choice_pending")), "ledger/materials/keeper must offer actual contract")
	game.call("_choose_jade_sail_industry_contract", true)
	_check(bool(game.get("jade_sail_industry_active")) and bool(game.call("_begin_jade_sail_industry_daily_gather")), "real jade contract must dispatch actual finite source")
	var jade_target := str(game.get("jade_sail_industry_target_id"))
	var player_shellfish := int(game.get("raw_shellfish"))
	await _observe_gather("jade")
	_check(jade_target in game.get("collected_ids") and int(game.get("jade_sail_industry_deliveries")) == 1 and int(game.get("jade_sail_industry_shellfish")) == 1 and int(game.get("raw_shellfish")) == player_shellfish, "jade delivery must preserve separate finite vessel hold and player inventory")
	_check(_events("jade_sail_industry_gather_started") == 1 and _events("jade_sail_industry_gather_harvested") == 1 and _events("jade_sail_industry_supply_delivered") == 1, "jade task history must remain exact once")
	var owners: Variant = _owners()
	await _reload_exact()
	_check(_owners() == owners, "delivered task reload cannot mint cargo or history")
	print("RESIDENT_MOTION_GATHER: ", gather_samples, "; actual finite outbound/return and in-flight reload for both gatherers; separate delivery/skip semantics unchanged")


func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/test_resident_motion_budget_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]).simplify_path()
	assert(Paths.is_safe_save_root(save_root))
	print("RESIDENT_MOTION_SAVE_ROOT: ", save_root)
	saver = Save.new(save_root)
	await _spawn()
	_test_controlled_routes()
	await _test_home_life()
	await _test_actual_gatherers()
	await _drop()
	saver.clear_for_test()
	if failures.is_empty():
		print("ARK_RESIDENT_MOTION_BUDGET_TEST_OK: actual Face/body +Z; cardinal/diagonal/rotated marker facing; paid 1–6cm route residuals/backtracking/final approach; strict work, corners, zero/small/normal dt, settling; real gather/awning/meal/refuge/cabin persistence and exact-once economy/history")
	else:
		printerr("MOTION_REGRESSION_FAILURE_COUNT: ", failures.size())
	quit(0 if failures.is_empty() else 1)
