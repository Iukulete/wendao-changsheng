extends SceneTree
## Actual Ark/player validation of controlled motion, not a replacement product.
## Tolerances: target 0.03m, transfer 0.001m. Rig geometry is test-only.
var _step_usec: Array[int] = []

func _initialize() -> void:
	_run.call_deferred()

static func _box(parent: Node3D, label: String, size: Vector3, position: Vector3, roll: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = position
	body.rotation.z = roll
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body

static func install_rig(game: Node3D, reset_actor: bool = true) -> Dictionary:
	var vessel := game.get_node("ArkRoot") as Node3D
	_box(vessel, "ValidationLowerDeck", Vector3(12, 0.2, 6), Vector3(0, -0.1, 12))
	_box(vessel, "ValidationUpperDeck", Vector3(3, 0.2, 3), Vector3(4.5, 2.3, 12))
	var slope := atan2(2.4, 6.0)
	_box(vessel, "ValidationStairRamp", Vector3(sqrt(36 + 2.4 * 2.4), 0.2, 2), Vector3(0, 1.2 - 0.1 / cos(slope), 12), slope)
	var points := {
		"lower_home": {"position": Vector3(-5, 0.2, 12), "floor_id": "lower"},
		"lower_side": {"position": Vector3(-5, 0.2, 14), "floor_id": "lower"},
		"lower_corner": {"position": Vector3(5, 0.2, 14), "floor_id": "lower"},
		"lower_under": {"position": Vector3(5, 0.2, 12), "floor_id": "lower"},
		"lower_landing": {"position": Vector3(-3, 0.2, 12), "floor_id": "lower"},
		"stair_mid": {"position": Vector3(0, 1.4, 12), "floor_id": "stairs:lower_upper"},
		"upper_landing": {"position": Vector3(3, 2.6, 12), "floor_id": "upper"},
		"upper_home": {"position": Vector3(5, 2.6, 12), "floor_id": "upper"}}
	var links := [["lower_home", "lower_side"], ["lower_side", "lower_corner"], ["lower_corner", "lower_under"], ["lower_home", "lower_landing"], ["lower_landing", "stair_mid"], ["stair_mid", "upper_landing"], ["upper_landing", "upper_home"]]
	var nav = game.get("vessel_navigation")
	assert(nav != null, "real game must own the service")
	var player := game.get("player") as CharacterBody3D
	if reset_actor:
		player.position = points.lower_home.position
		player.velocity = Vector3.ZERO
	nav.bind_actor("player", player, "lower")
	nav.define_layout(points, links)
	return {"nav": nav, "body": player, "points": points, "links": links}

func _new_game(save_root: String) -> Node3D:
	var game := load("res://scenes/ark_greybox.tscn").instantiate() as Node3D
	game.set("save_root_override", save_root)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await physics_frame
	return game

func _walk(game: Node3D, nav: RefCounted, sailing: bool = false) -> void:
	nav.step(0.000001) # one permitted layout/restore replan before measurement
	var plans: int = nav.plan_count
	var frames := 0
	while nav.has_active_task("player") and frames < 1200:
		if sailing:
			assert(game.call("_sail_step", 1.0 / 60.0, -0.2, 0.1))
		var started := Time.get_ticks_usec()
		nav.step(1.0 / 60.0)
		_step_usec.append(Time.get_ticks_usec() - started)
		var player := game.get("player") as CharacterBody3D
		assert(player.position.y >= 0.17 and player.position.y <= 2.63, "no floor penetration or wrong-floor jump")
		frames += 1
		await physics_frame
	assert(nav.inspect_actor("player").phase == "arrived", "collision body must complete the actual route")
	assert(nav.plan_count == plans, "vessel motion must not invalidate local paths")

func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.tmp/refactor-round/test_multifloor_save").simplify_path()
	assert(save_root.contains("/.tmp/refactor-round/test_"))
	if OS.get_name() == "Windows":
		assert(save_root.to_lower().begins_with("d:/"))
	var saver := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	saver.clear_for_test()
	var game := await _new_game(save_root)
	var vessel := game.get_node("ArkRoot") as Node3D
	vessel.position = Vector3(0, 0, 30)
	var rig := install_rig(game)
	var nav: RefCounted = rig.nav
	await physics_frame
	assert(nav.request_move("player", "upper_home", "risk_a:stationary").ok)
	await _walk(game, nav)
	assert(nav.inspect_actor("player").floor_id == "upper")
	assert(nav.request_move("player", "lower_under", "risk_a:stacked").ok)
	assert(nav.inspect_actor("player").path.has("stair_mid"), "same XZ on different floors requires stairs")
	await _walk(game, nav)
	assert(rig.body.position.distance_to(rig.points.lower_under.position) < 0.03)
	assert(nav.request_move("player", "upper_home", "risk_a:stacked_return").ok)
	await _walk(game, nav)
	game.set("sailing_mode", true)
	assert(nav.request_move("player", "lower_home", "risk_a:moving").ok)
	await _walk(game, nav, true)
	assert(absf(vessel.rotation.y) > 0.1 and vessel.position.distance_to(Vector3(0, 0, 30)) > 0.5)
	game.set("sailing_mode", false)
	var token: Dictionary = nav.request_move("player", "upper_home", "risk_a:cancel")
	assert(token.ok and nav.is_request_current("player", token))
	var before_invalid: Dictionary = nav.snapshot()
	assert(nav.validate_snapshot(before_invalid))
	for invalid in ["not_a_number", true, INF]:
		var malformed := before_invalid.duplicate(true)
		malformed.actors.player.position.x = invalid
		assert(not nav.validate_snapshot(malformed) and not nav.restore(malformed))
		assert(nav.snapshot() == before_invalid and nav.is_request_current("player", token), "invalid snapshots must not partially mutate session or invalidate current work")
	var wrong_owner := before_invalid.duplicate(true)
	wrong_owner.actors.player.vessel_id = "unknown_ark"
	assert(not nav.restore(wrong_owner) and nav.snapshot() == before_invalid)
	nav.step(0.1)
	nav.cancel("player")
	var stopped: Vector3 = rig.body.position
	nav.step(0.2)
	assert(rig.body.position.is_equal_approx(stopped) and not nav.is_request_current("player", token))
	token = nav.request_move("player", "upper_home", "risk_a:layout")
	assert(token.ok)
	var blocker := _box(vessel, "ValidationBlockedStair", Vector3(0.8, 2, 2.2), Vector3(0, 2.2, 12))
	await physics_frame
	var plans_before: int = nav.plan_count
	nav.invalidate_layout()
	assert(not nav.is_request_current("player", token))
	nav.step(0.1)
	assert(nav.inspect_actor("player").phase == "blocked" and nav.plan_count > plans_before)
	assert(not nav.request_move("player", "upper_home", "risk_a:unreachable").ok)
	blocker.queue_free()
	await physics_frame
	nav.invalidate_layout()
	token = nav.request_move("player", "upper_home", "risk_a:save")
	assert(token.ok)
	game.set("sailing_mode", true)
	for index in range(150):
		assert(game.call("_sail_step", 1.0 / 60.0, -0.2, -0.1))
		nav.step(1.0 / 60.0)
		await physics_frame
	assert(nav.has_active_task("player"))
	var saved_local: Vector3 = rig.body.position
	var saved_world: Vector3 = rig.body.global_position
	assert(game.call("_save_progress"), "use actual gameplay persistence boundary")
	var saved: Dictionary = saver.load_state().state
	assert(saved.has("vessel_navigation"))
	var serialized := JSON.stringify(saved.vessel_navigation)
	assert(not serialized.contains("path") and not serialized.contains("Node"))
	game.queue_free()
	await process_frame
	game = await _new_game(save_root)
	rig = install_rig(game, false)
	nav = rig.nav
	await physics_frame
	assert(rig.body.position.distance_to(saved_local) < 0.03 and rig.body.global_position.distance_to(saved_world) < 0.03)
	assert(nav.has_active_task("player") and not nav.is_request_current("player", token))
	# Repeated loading must not admit a result from the preceding session epoch.
	nav.restore(saved.vessel_navigation)
	assert(not nav.is_request_current("player", token))
	await _walk(game, nav)
	game.set("sailing_mode", false)
	assert(nav.request_move("player", "lower_home", "risk_a:dock").ok)
	await _walk(game, nav)
	vessel = game.get_node("ArkRoot") as Node3D
	var dock := _box(game, "ValidationDock", Vector3(3, 0.2, 3), Vector3.ZERO)
	dock.global_transform = Transform3D(vessel.global_basis, vessel.to_global(Vector3(-7.5, -0.1, 12)))
	await physics_frame
	for direction in [-1.0, 1.0]:
		var switched := false
		for index in range(60):
			assert(rig.body.move_and_collide(vessel.global_basis * Vector3(direction * 0.05, 0, 0)) == null)
			var local: Vector3 = vessel.to_local(rig.body.global_position)
			var leave: bool = direction < 0 and local.x < -6.01 and nav.inspect_actor("player").space == "vessel"
			var board: bool = direction > 0 and local.x > -5.99 and nav.inspect_actor("player").space == "world"
			if leave or board:
				var before: Vector3 = rig.body.global_position
				assert(nav.transfer_space("player", game if leave else vessel, "world" if leave else "vessel", "" if leave else "lower"))
				assert(rig.body.global_position.distance_to(before) < 0.001)
				switched = true
			var ray := PhysicsRayQueryParameters3D.create(rig.body.global_position + Vector3.UP * 0.1, rig.body.global_position - Vector3.UP * 0.4, 1, [rig.body.get_rid()])
			assert(not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "every dock step needs real support")
			await physics_frame
		assert(switched and nav.inspect_actor("player").space == ("world" if direction < 0 else "vessel"))
		if direction < 0:
			assert(not nav.request_move("player", "lower_home", "risk_a:not_aboard").ok)
	assert(nav.snapshot().actors.player.vessel_id == "starter_ark")
	assert(nav.transfer_space("player", game, "world"))
	var exit_world: Vector3 = rig.body.global_position
	# The real exit hook must not query global transforms after children exit.
	game.queue_free()
	await process_frame
	var exit_actor: Dictionary = saver.load_state().state.vessel_navigation.actors.player
	var exit_position := Vector3(float(exit_actor.position.x), float(exit_actor.position.y), float(exit_actor.position.z))
	assert(exit_actor.space == "world" and exit_position.distance_to(exit_world) < 0.001)
	_step_usec.sort()
	print("ARK_MULTIFLOOR_MEASURE: samples=%d p50_usec=%d p95_usec=%d max_usec=%d; movement step only, no rendering/capacity claim" % [_step_usec.size(), _step_usec[_step_usec.size() / 2], _step_usec[int(_step_usec.size() * 0.95)], _step_usec.back()])
	print("ARK_MULTIFLOOR_RISK_TEST_OK: real player/hull; overlapping floors/ramp; moving/yaw/docked; blocked/cancel/layout; save/recreate; stale tokens; walked dock ownership; exit snapshot")
	quit()
