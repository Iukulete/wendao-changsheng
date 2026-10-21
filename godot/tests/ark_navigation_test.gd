extends SceneTree

const ArkTestPaths = preload("res://tests/ark_test_paths.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_navigation_save").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(save_root), "test saves must be isolated in this repository; Windows saves must remain on D:")
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	save_helper.clear_for_test()
	var packed := load("res://scenes/ark_greybox.tscn") as PackedScene
	assert(packed != null, "the ark scene must load")
	var game := packed.instantiate()
	game.set("save_root_override", save_root)
	root.add_child(game)
	await physics_frame

	var ark_root := game.get_node("ArkRoot") as Node3D
	var player := game.get("player") as CharacterBody3D
	assert(player.get_parent() == ark_root, "the player must travel with the ark, not remain at a fixed world coordinate")
	assert(ark_root.get_node_or_null("RaftBase") is StaticBody3D, "raft collision must be part of the mobile ark hierarchy")
	assert(ark_root.get_node_or_null("LanternMarker") != null, "the lantern must travel with the ark")
	assert(not bool(game.call("_is_ark_position_navigable", Vector3(11.0, 0.0, -9.0))), "the hull clearance query must reject a route through the island")
	assert(bool(game.call("_is_ark_position_navigable", Vector3(0.0, 0.0, 3.6))), "the open-water side behind the stranded raft should be navigable")
	ark_root.global_position = Vector3(11.0, 0.0, -14.0)
	var blocked_turn_position := ark_root.global_position
	var blocked_turn_yaw := ark_root.rotation.y
	game.set("sailing_mode", true)
	assert(not bool(game.call("_sail_step", 0.5, 0.0, 1.0)), "a turn that would sweep the hull through an island must be rejected")
	assert(ark_root.global_position.is_equal_approx(blocked_turn_position) and is_equal_approx(ark_root.rotation.y, blocked_turn_yaw), "a blocked turn must preserve both ship position and heading")
	assert(bool(game.get("sailing_mode")), "a blocked turn should leave control at the helm so the player can correct course")
	var blocked_event_count := (game.get("world_events") as Array).size()
	game.call("_sail_step", 0.5, 0.0, 1.0)
	assert((game.get("world_events") as Array).size() == blocked_event_count, "holding a blocked helm input must not spam duplicate events or disk saves")
	ark_root.global_position = Vector3.ZERO
	game.set("sailing_mode", false)
	player.global_position = Vector3(0.0, -1.5, 139.7)
	player.velocity = Vector3.ZERO
	_set_key(KEY_S, true)
	for _frame in range(30):
		await physics_frame
	_set_key(KEY_S, false)
	assert(player.global_position.z <= 140.001 and player.global_position.z >= 139.9, "swimming beyond the mapped sea should meet a recoverable world-current boundary")
	assert(str(game.get("message")).contains("外海涌流"), "the world edge should explain why the uncharted sea turns the player back")
	var edge_position := player.global_position
	_set_key(KEY_W, true)
	for _frame in range(30):
		await physics_frame
	_set_key(KEY_W, false)
	assert(player.global_position.z < edge_position.z - 0.5, "the edge current must not trap the player; swimming back toward known waters remains possible")

	game.set("weather_phase", 2)
	player.position = Vector3(0.0, 1.1, 1.55)
	player.velocity = Vector3.ZERO
	game.set("is_swimming", false)
	game.call("_toggle_sailing")
	assert(bool(game.get("sailing_mode")), "a repaired ark after the opening storm should enter a distinct helm control mode")
	var start_position := ark_root.global_position
	var start_player_position := player.global_position
	assert(bool(game.call("_sail_step", 1.0, -1.0, 0.0)), "the ark should sail out into open water")
	assert(ark_root.global_position.distance_to(start_position) > 3.0, "sailing should move the ark through world space")
	assert(player.global_position.distance_to(start_player_position) > 3.0, "the player should move with the ark while at the helm")
	var start_yaw := ark_root.rotation.y
	game.call("_sail_step", 0.5, 0.0, 1.0)
	assert(not is_equal_approx(ark_root.rotation.y, start_yaw), "A/D steering should rotate the ark")
	game.call("_toggle_sailing")
	assert(not bool(game.get("sailing_mode")), "the helm should release back to on-foot movement")

	ark_root.global_position = Vector3(-8.0, 0.0, 3.0)
	ark_root.rotation.y = 0.65
	player.position = Vector3(0.0, 1.1, 0.4)
	player.velocity = Vector3.ZERO
	game.set("is_swimming", false)
	game.set("shelter_built", true)
	game.set("shelter_position", Vector3(0.0, 0.12, -0.5))
	assert(bool(game.call("_save_progress")), "the ark position and heading should save")
	game.queue_free()
	await process_frame

	var restored := packed.instantiate()
	restored.set("save_root_override", save_root)
	root.add_child(restored)
	await physics_frame
	var restored_ark := restored.get_node("ArkRoot") as Node3D
	var restored_player := restored.get("player") as CharacterBody3D
	assert(restored_ark.global_position.is_equal_approx(Vector3(-8.0, 0.0, 3.0)), "the mobile ark world position should survive reload")
	assert(is_equal_approx(restored_ark.rotation.y, 0.65), "the ark heading should survive reload")
	assert(restored_player.get_parent() == restored_ark and restored_player.position.distance_to(Vector3(0.0, 1.1, 0.4)) < 0.12, "the player should be restored aboard in the same local area after standing physics settles")
	var restored_shelter := restored_ark.get_node_or_null("BuiltShelter") as Node3D
	assert(restored_shelter != null, "built homes must be reconstructed beneath the mobile ark")
	assert(restored_shelter.global_position.distance_to(restored_ark.to_global(Vector3(0.0, 0.12, -0.5))) < 0.03, "the home must keep its deck-local placement after the ark turns and reloads")
	assert(int((restored.call("_build_save_state") as Dictionary).get("schema_version", 0)) == 34, "mobile ark, learned blueprints, home traces, residents, grounded memories, mooring rewards, accumulated exposure, resident work policies, guest cabin, vessel industry, operating rights, pressure galley, combat health, regional wildlife, luxury-ark guest stays, optional vessel title and resumable shared meals should use the current save schema")
	restored.queue_free()
	await process_frame
	save_helper.clear_for_test()
	assert(save_helper.save_state({"schema_version": 11, "player_position": {"x": 2.0, "y": 1.1, "z": 3.0}, "shelter_built": true, "shelter_position": {"x": 1.0, "y": 0.12, "z": -2.0}}).get("ok", false), "legacy schema 11 state should be seedable")
	var legacy := packed.instantiate()
	legacy.set("save_root_override", save_root)
	root.add_child(legacy)
	await physics_frame
	var legacy_player := legacy.get("player") as CharacterBody3D
	assert(legacy_player.global_position.distance_to(Vector3(2.0, 1.1, 3.0)) < 0.03, "schema 11 player world coordinates must remain unchanged during migration")
	var legacy_shelter := legacy.get_node("ArkRoot/BuiltShelter") as Node3D
	assert(legacy_shelter.global_position.distance_to(Vector3(1.0, 0.12, -2.0)) < 0.03, "schema 11 home world coordinates must remain unchanged during migration")
	legacy.queue_free()
	await process_frame
	save_helper.clear_for_test()
	assert(save_helper.save_state({"schema_version": 15, "player_position": {"x": 2.0, "y": 1.1, "z": 3.0}, "workbench_position": "malformed"}).get("ok", false), "a partially malformed recent save should be seedable")
	var malformed_recent := packed.instantiate()
	malformed_recent.set("save_root_override", save_root)
	root.add_child(malformed_recent)
	await physics_frame
	var malformed_recent_player := malformed_recent.get("player") as CharacterBody3D
	assert(malformed_recent_player.position.distance_to(Vector3(2.0, 1.1, 3.0)) < 0.03, "an invalid optional workbench location must not suppress restoration of the saved player position")
	malformed_recent.queue_free()
	await physics_frame
	save_helper.clear_for_test()
	print("ARK_NAVIGATION_TEST_OK:")
	quit()


func _set_key(keycode: Key, pressed: bool) -> void:
	Input.parse_input_event(_key_event(keycode, pressed))


func _key_event(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	return event
