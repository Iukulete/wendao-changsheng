extends SceneTree

const ArkTestPaths = preload("res://tests/ark_test_paths.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_ark_audit_navigation").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(save_root), "audit saves must stay in this repository's isolated test directory")
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	save_helper.clear_for_test()
	var game := (load("res://scenes/ark_greybox.tscn") as PackedScene).instantiate()
	game.set("save_root_override", save_root)
	root.add_child(game)
	await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	var ark := game.get_node("ArkRoot") as Node3D
	ark.position = Vector3(-80.0, 0.0, 70.0)
	game.call("_add_box", "AuditBowObstacle", ark.to_global(Vector3(0.0, 0.0, -5.0)), Vector3.ONE, Color.WHITE, true)
	await physics_frame
	assert(bool(game.call("_is_ark_position_navigable", ark.position)), "a rock beyond the original bow must not block the shorter hull")
	game.set("raft_extension_built", true)
	game.call("_build_raft_extension_at", Vector3(0.0, 0.12, -4.0))
	await physics_frame
	assert(not bool(game.call("_is_ark_position_navigable", ark.position)), "expanded bow clearance must include the added deck, not just the original raft")
	game.set("sailing_mode", true)
	var previous_transform := ark.transform
	assert(not bool(game.call("_sail_step", 0.2, 1.0, 0.0)), "an extended bow must not sail through an obstacle")
	assert(ark.transform.is_equal_approx(previous_transform), "rejected extended-hull movement must preserve position and yaw")
	ark.rotation.y = PI / 2.0
	var obstacle := game.get_node("AuditBowObstacle") as Node3D
	obstacle.global_position = ark.to_global(Vector3(0.0, 0.0, -5.0))
	await physics_frame
	assert(not bool(game.call("_is_ark_position_navigable", ark.position)), "extended clearance must rotate with the mobile ark")
	obstacle.queue_free()
	await physics_frame
	assert(bool(game.call("_is_ark_position_navigable", ark.position)), "the extended ark must still navigate clear open water")
	game.set("sailing_mode", false)
	game.set("raft_extension_built", false)
	assert(bool(game.call("_ark_local_walk_cell_blocked", Vector2(8.0, 0.0))), "off-deck empty space is not a walkable resident cell")
	assert(bool(game.call("_ark_local_walk_cell_blocked", Vector2(0.0, -5.0))), "the bow area needs a real extension before it supports a route")
	var empty_local: PackedVector3Array = game.call("_build_ark_local_walk_route", Vector3.ZERO, Vector3(1000000.0, 0.12, 0.0))
	assert(empty_local.is_empty(), "invalid local endpoints must be rejected before grid allocation")
	game.call("_add_box", "AuditDeckPartition", Vector3(0.0, 1.0, 0.0), Vector3(6.0, 2.0, 0.4), Color.WHITE, true, ark)
	await physics_frame
	var no_detour: PackedVector3Array = game.call("_build_ark_local_walk_route", Vector3(0.0, 0.12, -1.0), Vector3(0.0, 0.12, 1.0))
	assert(no_detour.is_empty(), "a full-width deck partition must not be bypassed by walking over the sea")
	for endpoint in [Vector3(150.0, 0.12, 150.0), Vector3(1000000.0, 0.12, 0.0), Vector3(100.0, 0.12, 100.0), Vector3(NAN, 0.12, 0.0), Vector3(INF, 0.12, 0.0)]:
		var invalid_route: PackedVector3Array = game.call("_build_resident_walk_route", Vector3.ZERO, endpoint)
		assert(invalid_route.is_empty(), "world-sized or non-finite resident tasks must not allocate a grid")
	var normal_route: PackedVector3Array = game.call("_build_resident_walk_route", Vector3(2.0, 0.12, -7.0), Vector3(8.0, 0.12, -7.0))
	assert(normal_route.size() > 2, "bounded routing must preserve a real near-shore detour")
	game.queue_free()
	await process_frame
	save_helper.clear_for_test()
	print("ARK_AUDIT_NAVIGATION_TEST_OK:")
	quit()
