extends SceneTree

## Normal returning travel, including delivery/ownership transfer, spends distance.
## Outbound pickup tolerances and emergency recalls deliberately remain separate.
## The real-flow tests never set an NPC position/phase. Synthetic residual probes
## are explicitly labelled and restore a payload earned by those real workflows.
const Paths = preload("res://tests/ark_test_paths.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
const Gathering = preload("res://scripts/modules/residents/ark_gathering.gd")
# World coordinates near -53 use float32 Vector3; 1e-5 m covers observed ULPs,
# not gameplay centimetres. The very same allowance includes terminal placement.
const EPS := 0.00001
const SPEED := 1.8
const DECK := Vector3(-1.0, 0.12, 0.85)
const JADE_HOME := Vector3(-53.0, 0.12, -41.8)
var game: Node3D
var saver: RefCounted
var save_root: String
var failures: Array[String] = []
var samples := 0
var synthetic_cases := 0
var actual_arrivals := 0
var reloads := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, context: String) -> void:
	if not ok:
		failures.append(context)
		printerr("GATHER_RETURN_FAILED: " + context)


func _spawn() -> void:
	game = load("res://scenes/ark_greybox.tscn").instantiate() as Node3D
	game.set("save_root_override", save_root)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	(game.get("player") as Node).set_physics_process(false)
	await physics_frame
	_check(not bool(game.get_meta("save_load_blocked", false)), "earned save must load without quarantine")


func _drop() -> void:
	if is_instance_valid(game):
		game.set("save_service", null)
		game.queue_free()
		await process_frame


func _fresh() -> void:
	await _drop()
	saver.clear_for_test()
	await _spawn()


func _ark() -> Node3D:
	return game.get_node("ArkRoot") as Node3D


func _prefix(jade: bool) -> String:
	return "jade_sail_industry" if jade else "resident_gather"


func _marker(jade: bool) -> Node3D:
	return game.get("jade_sail_keeper_marker" if jade else "traveler_marker") as Node3D


func _home(jade: bool) -> Vector3:
	return JADE_HOME if jade else _ark().to_global(DECK)


func _task(jade: bool) -> String:
	return str(game.get("jade_task_id" if jade else "resident_task_id"))


func _pending(jade: bool) -> bool:
	return bool(game.get(_prefix(jade) + "_pending"))


func _phase(jade: bool) -> String:
	return str(game.get(_prefix(jade) + "_phase"))


func _event(jade: bool, suffix: String) -> String:
	if jade and suffix == "delivered":
		return "jade_sail_industry_supply_delivered"
	return ("jade_sail_industry_gather_" if jade else "resident_gather_") + suffix


func _count(id: String) -> int:
	var result := 0
	for event in game.get("world_events") as Array:
		if str(event.get("id", "")) == id:
			result += 1
	return result


func _owners() -> Variant:
	var state: Dictionary = game.call("_build_save_state")
	return JSON.parse_string(JSON.stringify({"economy": state.modules.economy, "events": state.world_events, "sequence": state.event_sequence, "construction": state.modules.construction}))


func _collect_wood() -> void:
	for entry in (game.get("interactables") as Array).duplicate():
		if str(entry.get("id", "")) == "wood":
			(game.get("player") as Node3D).global_position = (entry.node as Node3D).global_position
			game.call("_interact")
			return
	_check(false, "real finite wood fixture exhausted")


func _prepare(jade: bool, shifted: bool = false) -> void:
	await _fresh()
	game.set("weather_phase", 2)
	if jade:
		(game.get("player") as Node3D).global_position = Vector3(-53, 1.3, -45)
		game.call("_interact")
		for _supply in range(4):
			if int(game.get("wood")) >= 3:
				break
			_collect_wood()
		for _talk in range(2):
			(game.get("player") as Node3D).global_position = _marker(true).global_position
			game.call("_interact")
		_check(bool(game.get("jade_sail_industry_choice_pending")), "real ledger, crew and finite materials must offer contract")
		game.call("_choose_jade_sail_industry_contract", true)
		_check(bool(game.get("jade_sail_industry_active")), "real jade contract must be accepted")
	else:
		_collect_wood()
		_check(bool(game.call("_try_place_shelter", Vector3.ZERO)), "finite pickup must pay for real shelter")
		game.set("resident_met", true)
		game.set("traveler_choice_pending", true)
		game.call("_choose_traveler_boarding", true)
		_check(bool(game.get("traveler_boarded")), "resident must accept actual boarding")
		if shifted:
			# Valid stationary world layout, not a forced NPC trajectory/result.
			_ark().position = Vector3(-0.75, 0, 0.4)
			_ark().rotation.y = -0.55
			_check(bool(game.call("_is_ark_position_navigable", _ark().global_position)), "shifted layout must be navigable")
	await physics_frame
	_check(bool(game.call("_begin_jade_sail_industry_daily_gather" if jade else "_begin_resident_daily_gather")), "real finite job must dispatch")


func _tick(jade: bool, delta: float, label: String, enforce: bool = true) -> void:
	var marker := _marker(jade)
	var before := marker.global_position
	var was_returning := _phase(jade) == "returning"
	var task_id := _task(jade)
	var payload: Dictionary = game.get("economy").carried(task_id)
	game.call("_process_jade_sail_industry_gathering" if jade else "_process_resident_gathering", delta)
	if not was_returning or not enforce:
		return
	var moved := marker.global_position.distance_to(before)
	var budget := maxf(0.0, delta) * SPEED
	_check(moved <= budget + EPS, "%s dt=%.9f return step=%.9f budget=%.9f before=%s after=%s terminal=%s" % [label, delta, moved, budget, before, marker.global_position, not _pending(jade)])
	if delta <= 0.0:
		_check(moved <= EPS, label + " zero/negative time must not relocate returner")
	if _pending(jade):
		_check(game.get("economy").carried(task_id) == payload, label + " en-route cargo must remain owned by task")
		_check(_count(_event(jade, "delivered")) == 0, label + " no delivery history before actual home arrival")
	else:
		_check(marker.global_position.distance_to(_home(jade)) <= EPS, label + " completion requires exact actual world home")
		_check(before.distance_to(_home(jade)) <= budget + EPS, label + " final placement cannot stand in for paid home arrival")
		_check(str(game.get("gathering").task(task_id).phase) == "delivered" and game.get("economy").carried(task_id).is_empty(), label + " arrived task must deliver and clear cargo")
		if not jade:
			_check(marker.get_parent() == _ark() and marker.position.distance_to(DECK) <= EPS, label + " world-to-ark ownership transfer must preserve actual arrival")
		print("GATHER_RETURN_TERMINAL: ", label, " dt=", delta, " step=", moved, " home_before=", before.distance_to(_home(jade)))
	# Actual rendered Face/Body geometry, not an assumed yaw axis.
	var direction := marker.global_position - before
	direction.y = 0.0
	if direction.length() > 0.0011:
		var face := marker.find_child("Face", true, false) as Node3D
		var body := marker.find_child("Body", true, false) as Node3D
		var front := face.global_position - body.global_position
		front.y = 0.0
		_check(front.normalized().dot(direction.normalized()) > 0.99, label + " actual Face must retain forward +Z travel")
	samples += 1


func _reload(jade: bool, label: String) -> void:
	var position := _marker(jade).global_position
	var saved: Dictionary = game.call("_build_save_state")
	var persisted: Dictionary = saved["jade_sail_keeper_position" if jade else "traveler_position"]
	var persisted_position := Vector3(float(persisted.x), float(persisted.y), float(persisted.z))
	if not jade and not _pending(jade):
		persisted_position = _ark().to_global(persisted_position)
	# Existing Jade save serialization rounds each coordinate to 1 cm. Check
	# those exact bytes independently; that reload rounding is NOT travel or arrival.
	_check(position.distance_to(persisted_position) <= (0.00867 if jade else EPS), label + " serialized position quantization remains bounded")
	var task_phase := str(game.get("gathering").task(_task(jade)).get("phase", ""))
	var owners: Variant = _owners()
	var phase := _phase(jade)
	var task_id := _task(jade)
	var ark_transform := _ark().global_transform
	_check(bool(game.call("_save_progress")), label + " earned flow must save")
	await _drop()
	await _spawn()
	_check(_marker(jade).global_position.distance_to(persisted_position) <= EPS and _phase(jade) == phase, label + " reload must preserve exact serialized world position and phase")
	_check(str(game.get("gathering").task(task_id).get("phase", "")) == task_phase, label + " reload must preserve authoritative task identity/phase")
	if not phase.is_empty():
		_check(_task(jade) == task_id, label + " active task facade must preserve identity")
	_check(_owners() == owners and _ark().global_transform.is_equal_approx(ark_transform), label + " reload must preserve inventory/history and ark frame")
	if not jade and _pending(jade):
		_check(_marker(jade).get_parent() == game and (game.get("resident_gather_route") as PackedVector3Array).is_empty(), label + " returning reload must rebuild route in world frame")
	reloads += 1


func _actual(jade: bool, variable: bool) -> Dictionary:
	await _prepare(jade, variable and not jade)
	var label := ("jade" if jade else "tide") + ("/variable_shifted" if variable else "/fixed")
	var task_id := _task(jade)
	var target := str(game.get(_prefix(jade) + "_target_id"))
	var resource := str(game.get(_prefix(jade) + "_resource"))
	var amount := int(game.get("economy").source(target).remaining)
	var owner := "jade_sail" if jade else "player"
	var inventory_before := int(game.get("economy").inventory(owner, resource))
	var other_before := int(game.get("economy").inventory("player" if jade else "jade_sail", resource))
	var earned := {}
	var reloaded := false
	var near_reloaded := false
	var returning_steps := 0
	var near_probe := false
	for step in range(2200):
		if not _pending(jade):
			break
		var delta := 0.05
		if _phase(jade) == "returning":
			returning_steps += 1
			if earned.is_empty():
				earned = (game.call("_build_save_state") as Dictionary).duplicate(true)
				_check(int(game.get("economy").source(target).remaining) == 0 and int(game.get("economy").carried(task_id).amount) == amount, label + " actual harvest must consume source once into carried payload")
			if not reloaded and returning_steps == 7:
				reloaded = true
				await _reload(jade, label + "/inflight")
			if variable:
				var remaining := _marker(jade).global_position.distance_to(_home(jade))
				# Vary only elapsed time. Jade genuinely walks to a 4 cm residual;
				# the next zero-delta frame must not turn that into a free delivery.
				if jade and remaining > 0.06 and remaining < 0.4 and not near_probe:
					delta = (remaining - 0.04) / SPEED
					near_probe = true
				elif jade and remaining > EPS and remaining < 0.06 and not near_reloaded:
					await _reload(jade, label + "/near_home")
					near_reloaded = true
					delta = 0.0
				elif not jade and remaining > EPS and remaining < 0.21 and not near_reloaded:
					await _reload(jade, label + "/near_home")
					near_reloaded = true
					delta = 0.0
				else:
					delta = [0.0, 0.0001, 0.017, 0.05, 0.093][step % 5]
		_tick(jade, delta, label)
	_check(not _pending(jade) and returning_steps > 10 and reloaded, label + " genuine outbound/collection/inflight-return must finish")
	if variable:
		_check(near_reloaded, label + " actual near-home returning state must be saved/reloaded")
	_check(int(game.get("economy").source(target).remaining) == 0 and target in game.get("collected_ids"), label + " finite source must remain consumed exactly once")
	_check(int(game.get("economy").inventory(owner, resource)) == inventory_before + amount and int(game.get("economy").inventory("player" if jade else "jade_sail", resource)) == other_before, label + " delivery must affect only correct inventory exactly once")
	for suffix in ["started", "harvested", "delivered"]:
		_check(_count(_event(jade, suffix)) == 1, label + "/" + suffix + " history exactly once")
	_check(_count(_event(jade, "cancelled")) == 0 and bool(game.get("economy").audit().ok), label + " successful route must not cancel or violate conservation")
	var completed: Variant = _owners()
	for delta in [0.0, 0.0001, 0.05, 0.25]:
		_tick(jade, delta, label + "/settled")
	_check(_owners() == completed, label + " repeated terminal ticks cannot duplicate cargo/history")
	await _reload(jade, label + "/completed")
	_check(_owners() == completed and not _pending(jade), label + " existing completed save must remain completed")
	actual_arrivals += 1
	print("GATHER_RETURN_REAL_FLOW: ", label, " target=", target, " amount=", amount, " returning_steps=", returning_steps)
	return earned


func _restore_earned(jade: bool, earned: Dictionary) -> void:
	# Targeted synthetic parameter cases only: restore real economic authority,
	# then arrange residual geometry. Never cited as a passed genuine workflow.
	_check(bool(game.get("economy").restore(earned.modules.economy)), "synthetic earned economy restore")
	_check(bool(game.get("gathering").restore(earned.modules.gathering)), "synthetic earned task restore")
	_check(bool(game.get("memories").restore(earned.modules.memories)), "synthetic earned memories restore")
	game.set("world_events", game.get("memories").events())
	game.set("event_sequence", game.get("memories").sequence())
	for suffix in ["pending", "phase", "resource", "target_id", "payload", "pickup_remaining"]:
		var key: String = _prefix(jade) + "_" + suffix
		game.set(key, earned[key])
	game.set("jade_task_id" if jade else "resident_task_id", earned["jade_task_id" if jade else "resident_task_id"])
	if jade:
		game.set("jade_sail_industry_deliveries", earned.jade_sail_industry_deliveries)
	game.set("weather_phase", 2)
	game.set("sailing_mode", false)
	if not jade and _marker(false).get_parent() != game:
		_marker(false).reparent(game, true)


func _synthetic(jade: bool, earned: Dictionary) -> void:
	game.set("save_service", null)
	for residual in [0.0, 0.001, 0.01, 0.04, 0.06, 0.21, 0.3]:
		for delta in [0.0, -0.1, 0.0001, 0.01, 0.05, 0.25]:
			for mode in (["direct"] if jade else ["last_waypoint", "empty_route", "stale_endpoint"]):
				_restore_earned(jade, earned)
				var home := _home(jade)
				# Nonzero Y is deliberate: horizontal equality is not 3D arrival.
				var start: Vector3 = home + Vector3(0.8, 0.36, -0.48).normalized() * residual
				_marker(jade).global_position = start
				if not jade:
					var points := PackedVector3Array()
					if mode == "last_waypoint":
						points = PackedVector3Array([start.lerp(home, 0.5), home])
					elif mode == "stale_endpoint":
						points = PackedVector3Array([home + Vector3(0.5, 0, 0)])
					game.set("resident_gather_route", points)
					game.set("resident_gather_route_index", 0)
				var label := "SYNTHETIC/%s/%s/residual=%s" % ["jade" if jade else "tide", mode, residual]
				_tick(jade, delta, label)
				if residual > maxf(0.0, delta) * SPEED + EPS:
					_check(_pending(jade), label + " insufficient travel budget cannot complete")
				if residual <= EPS:
					_check(not _pending(jade), label + " already exact home may transfer without relocation")
				# Settle the same earned task through actual subsequent calls.
				for _step in range(80):
					if not _pending(jade):
						break
					_tick(jade, 0.05, label + "/settle")
				_check(not _pending(jade) and _count(_event(jade, "delivered")) == 1 and bool(game.get("economy").audit().ok), label + " residual task eventually delivers exactly once")
				synthetic_cases += 1
	# Outbound shared module/planner tolerances are intentionally not tightened.
	var origin := Vector3.ZERO
	var skipped := Gathering.advance_route(origin, PackedVector3Array([Vector3(0.05, 0, 0)]), 0, 0.0, SPEED)
	_check(bool(skipped.arrived) and (skipped.position as Vector3) == origin, "shared outbound skip semantics remain unchanged")
	_check((game.call("_build_resident_walk_route", _home(jade), _home(jade) + Vector3(0.1, 0, 0)) as PackedVector3Array).size() == 1, "outbound short-route planner semantics remain unchanged")
	print("GATHER_RETURN_SYNTHETIC: ", "jade" if jade else "tide", " residual matrix complete; explicit synthetic geometry with genuinely earned payload authority")


func _emergency(jade: bool, collected: bool, reason: String) -> void:
	await _prepare(jade)
	var target := str(game.get(_prefix(jade) + "_target_id"))
	var task_id := _task(jade)
	var source_amount := int(game.get("economy").source(target).remaining)
	if collected:
		for _step in range(1800):
			if _phase(jade) == "returning":
				break
			_tick(jade, 0.05, "emergency setup", false)
		_check(_phase(jade) == "returning", "emergency cargo must come from actual collection")
	else:
		_tick(jade, 0.05, "emergency outbound setup", false)
	if reason == "storm":
		game.set("weather_phase", 1)
		_tick(jade, 0.0, "intentional storm recall", false)
	elif reason == "sailing":
		game.call("_toggle_sailing")
	else:
		game.call("_abort_jade_sail_industry_gathering" if jade else "_recall_resident_gatherer", "explicit_cancel_regression")
	_check(not _pending(jade) and _marker(jade).global_position.distance_to(_home(jade)) <= EPS, "emergency recall intentionally returns home immediately")
	_check(game.get("economy").carried(task_id).is_empty() and bool(game.get("economy").audit().ok), "emergency recall must leave no orphan cargo")
	_check(int(game.get("economy").source(target).remaining) == (0 if collected else source_amount), "emergency source preservation/consumption unchanged")
	_check(_count(_event(jade, "delivered" if collected else "cancelled")) == 1, "emergency terminal history exactly once")
	var owners: Variant = _owners()
	_tick(jade, 0.05, "repeated emergency", false)
	_check(_owners() == owners, "repeated emergency call cannot duplicate outcome")


func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/test_gather_return_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]).simplify_path()
	assert(Paths.is_safe_save_root(save_root))
	print("GATHER_RETURN_SAVE_ROOT: ", save_root)
	saver = Save.new(save_root)
	for jade in [false, true]:
		await _actual(jade, false)
		var earned := await _actual(jade, true)
		if not earned.is_empty():
			_synthetic(jade, earned)
		for collected in [false, true]:
			for reason in (["cancel", "storm"] if jade else ["cancel", "storm", "sailing"]):
				await _emergency(jade, collected, reason)
	await _drop()
	saver.clear_for_test()
	if failures.is_empty():
		print("ARK_GATHER_RETURN_ARRIVAL_TEST_OK: real_flows=", actual_arrivals, " returning_samples=", samples, " reloads=", reloads, " synthetic_cases=", synthetic_cases, "; paid 3D normal home arrival and exact-once delivery, world/ark frames, variable/zero/tiny delta; outbound tolerances and emergency recalls unchanged")
	else:
		printerr("GATHER_RETURN_FAILURE_COUNT: ", failures.size())
	quit(0 if failures.is_empty() else 1)
