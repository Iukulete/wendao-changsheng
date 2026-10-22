extends SceneTree

const ArkTestPaths = preload("res://tests/ark_test_paths.gd")


func _initialize() -> void:
	call_deferred("_run")


func _key_event(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	event.shift_pressed = pressed if keycode == KEY_SHIFT else Input.is_key_pressed(KEY_SHIFT)
	return event


func _set_key(keycode: Key, pressed: bool) -> void:
	Input.parse_input_event(_key_event(keycode, pressed))
	Input.flush_buffered_events()


func _count_events(events: Array, event_id: String) -> int:
	var count := 0
	for event in events:
		if event is Dictionary and str(event.get("id", "")) == event_id:
			count += 1
	return count


func _hold_until(keycode: Key, max_frames: int, condition: Callable) -> int:
	_set_key(keycode, true)
	var elapsed := 0
	while elapsed < max_frames:
		await physics_frame
		elapsed += 1
		if condition.call():
			break
	_set_key(keycode, false)
	await physics_frame
	return elapsed


func _sail_to_waypoint(game: Node, target: Vector2, max_steps: int = 900) -> bool:
	var ark_root := game.get("ark_root") as Node3D
	for step in range(max_steps):
		var offset := Vector2(target.x - ark_root.global_position.x, target.y - ark_root.global_position.z)
		if offset.length() <= 0.55:
			return true
		var direction := offset.normalized()
		ark_root.rotation.y = atan2(-direction.x, -direction.y)
		if not bool(game.call("_sail_step", 0.2, 1.0, 0.0)):
			return false
		if step % 8 == 0:
			await physics_frame
	return Vector2(target.x - ark_root.global_position.x, target.y - ark_root.global_position.z).length() <= 0.8


func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_save_world_travel").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(save_root), "test saves must be isolated in this repository; Windows saves must remain on D:")
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	save_helper.clear_for_test()
	var scene := load("res://scenes/ark_greybox.tscn") as PackedScene
	assert(scene != null, "the world-travel fixture must load")
	var game := scene.instantiate()
	game.set("save_root_override", save_root)
	root.add_child(game)
	# This timed expedition uses the retained 5 m/s Shift run speed.
	_set_key(KEY_SHIFT, true)
	await process_frame
	var player: CharacterBody3D = game.get("player")
	# Prepare the home-side prerequisites through the normal construction methods.
	# The test focuses on whether a player can physically complete the expedition
	# and bring its unique reward back; other tests cover gathering these materials.
	game.set("wood", 11)
	assert(bool(game.call("_try_place_shelter", Vector3(0.0, 0.12, 0.0))), "the return-trip fixture should be able to establish a shelter")
	assert(bool(game.call("_try_place_storage", Vector3(2.0, 0.12, 1.0))), "the return-trip fixture should be able to establish storage")
	assert(bool(game.call("_try_place_workbench", Vector3(-2.0, 0.12, 1.0))), "the return-trip fixture should be able to establish the blueprint workbench")
	var exit_leg := await _hold_until(KEY_S, 110, func() -> bool: return player.global_position.z >= 3.4)
	assert(exit_leg < 110 and player.global_position.z >= 3.0, "the stern gangplank should provide a clear, walkable exit from the starting raft")
	var first_leg := await _hold_until(KEY_D, 1000, func() -> bool: return player.global_position.x >= 27.0)
	print("TRAVEL_FIRST_LEG: frames=%d position=%s velocity=%s" % [first_leg, player.global_position, player.velocity])
	assert(first_leg < 1000 and player.global_position.x >= 26.5, "the player should cross the open-water gap by walking and swimming, without a map teleport")
	var second_leg := await _hold_until(KEY_W, 1200, func() -> bool: return player.global_position.z <= -34.0)
	assert(second_leg < 1200 and player.global_position.z <= -33.5, "the player should be able to steer around the main island into the north channel")
	var reef_approach := await _hold_until(KEY_D, 260, func() -> bool: return player.global_position.x >= 31.0)
	assert(reef_approach < 260 and player.global_position.x >= 30.5, "the far reef should be reachable from open water")
	_set_key(KEY_D, true)
	for _attempt in range(5):
		_set_key(KEY_SPACE, true)
		_set_key(KEY_SPACE, false)
		for _frame in range(55):
			await physics_frame
			if player.is_on_floor() and player.global_position.x >= 32.5:
				break
		if player.is_on_floor() and player.global_position.x >= 32.5:
			break
	_set_key(KEY_D, false)
	print("TRAVEL_REEF_LANDING: position=%s velocity=%s on_floor=%s" % [player.global_position, player.velocity, player.is_on_floor()])
	assert(player.is_on_floor() and player.global_position.x >= 32.5, "swimming player should be able to climb onto the far reef using the jump stroke")
	var reef_walk := await _hold_until(KEY_D, 220, func() -> bool: return player.global_position.x >= 39.0)
	assert(reef_walk < 220 and player.global_position.x >= 38.5, "the player should cross the reef on foot")
	var wreck_approach := await _hold_until(KEY_S, 140, func() -> bool: return player.global_position.z >= -30.0)
	assert(wreck_approach < 140 and player.global_position.z >= -30.5, "the player should reach the marked wreck on the reef")
	game.call("_interact")
	assert(bool(game.get("keel_wreck_searched")) and int(game.get("keel_beams")) == 1, "actual traversal should reach the unique keel salvage")
	var return_north := await _hold_until(KEY_W, 150, func() -> bool: return player.global_position.z <= -31.0)
	print("TRAVEL_RETURN_NORTH: frames=%d position=%s velocity=%s" % [return_north, player.global_position, player.velocity])
	assert(return_north < 150 and player.global_position.z <= -30.5, "the return route should first clear the exposed reef")
	var return_west_channel := await _hold_until(KEY_A, 420, func() -> bool: return player.global_position.x <= 31.0)
	print("TRAVEL_RETURN_WEST: frames=%d position=%s velocity=%s" % [return_west_channel, player.global_position, player.velocity])
	assert(return_west_channel < 420 and player.global_position.x <= 31.5, "the return route should cross around the reef edge and outside the island")
	var return_south := await _hold_until(KEY_S, 2400, func() -> bool: return player.global_position.z >= 3.4)
	print("TRAVEL_RETURN_SOUTH: frames=%d position=%s velocity=%s" % [return_south, player.global_position, player.velocity])
	assert(return_south < 2400 and player.global_position.z >= 3.0, "the player should be able to swim south of the island back toward the ark")
	var return_to_ark := await _hold_until(KEY_A, 2400, func() -> bool: return player.global_position.x <= 0.05)
	print("TRAVEL_RETURN_ARK: frames=%d position=%s velocity=%s" % [return_to_ark, player.global_position, player.velocity])
	assert(return_to_ark < 2400 and player.global_position.x <= 0.1, "the player should center on the ark's stern gangplank without a map teleport")
	_set_key(KEY_W, true)
	var board_ark := 0
	for _attempt in range(5):
		_set_key(KEY_SPACE, true)
		_set_key(KEY_SPACE, false)
		for _frame in range(55):
			await physics_frame
			board_ark += 1
			if player.is_on_floor() and player.global_position.z <= 1.6:
				break
		if player.is_on_floor() and player.global_position.z <= 1.6:
			break
	_set_key(KEY_W, false)
	await physics_frame
	print("TRAVEL_BOARD_ARK: frames=%d position=%s velocity=%s on_floor=%s" % [board_ark, player.global_position, player.velocity, player.is_on_floor()])
	assert(board_ark < 120 and player.is_on_floor() and absf(player.global_position.x) <= 1.0, "the stern gangplank should be walkable in reverse so the player can come home")
	assert(int(game.get("wood")) == 8 and int(game.get("keel_beams")) == 1, "the unique reef reward should arrive home intact for construction")
	assert(bool(game.call("_try_place_raft_extension", Vector3(0.0, 0.12, -4.2))), "the returned keel and planks should allow real home growth")
	assert(bool(game.get("raft_extension_built")) and game.get_node_or_null("ArkRoot/BuiltRaftExtension") != null and int(game.get("wood")) == 4, "the expanded deck should exist and charge the return-trip materials")
	game.set("weather_phase", 2)
	game.call("_toggle_sailing")
	assert(bool(game.get("sailing_mode")), "after the weather clears, the mobile home should be free to sail toward a distant region")
	for waypoint in [Vector2(0.0, 35.0), Vector2(35.0, 35.0), Vector2(35.0, 68.0), Vector2(92.0, 68.0)]:
		assert(await _sail_to_waypoint(game, waypoint), "the ship should physically navigate the continuous sea to the outer steam-wreck coast")
	var ark_root := game.get("ark_root") as Node3D
	ark_root.rotation.y = 0.0
	game.call("_toggle_sailing")
	_set_key(KEY_S, true)
	var outer_shore_landing := 0
	for _attempt in range(5):
		_set_key(KEY_SPACE, true)
		_set_key(KEY_SPACE, false)
		for _frame in range(55):
			await physics_frame
			outer_shore_landing += 1
			if player.is_on_floor() and player.global_position.z >= 74.0:
				break
		if player.is_on_floor() and player.global_position.z >= 74.0:
			break
	_set_key(KEY_S, false)
	await physics_frame
	assert(outer_shore_landing < 275 and player.is_on_floor() and player.global_position.z >= 74.0 and absf(player.global_position.x - ark_root.global_position.x) < 2.2, "the player should climb directly from open water onto the mechanical islet without a travel gate")
	var vent_warning_frames := await _hold_until(KEY_S, 100, func() -> bool: return bool(game.get("pressure_vent_warning_active")))
	assert(vent_warning_frames < 100 and _count_events(game.get("world_events") as Array, "pressure_vent_warning") >= 1, "walking toward the wreck should trigger the visible pressure-vent warning in-world")
	var sidestep_frames := await _hold_until(KEY_A, 100, func() -> bool: return player.global_position.x <= 89.8)
	assert(sidestep_frames < 100, "the open landing should allow a lateral route around the vent")
	var approach_frames := await _hold_until(KEY_S, 360, func() -> bool: return absf(player.global_position.z - 88.8) <= 0.35)
	assert(approach_frames < 360 and absf(player.global_position.x - 89.5) <= 0.45, "the player should walk around the vent and reach the wreck by foot")
	assert(int(game.get("player_health")) == 4 and _count_events(game.get("world_events") as Array, "pressure_vent_burst") >= 1, "the vent should release during exploration while the safe route avoids damage")
	game.call("_interact")
	assert(bool(game.get("pressure_wreck_searched")) and int(game.get("pressure_cores")) == 1 and (game.get("learned_blueprint_ids") as Array).has("pressure_galley"), "physical arrival should let the player recover the unique core and permanently learn its template")
	var return_align_frames := await _hold_until(KEY_D, 100, func() -> bool: return player.global_position.x >= 91.8)
	assert(return_align_frames < 100, "the player should be able to return to the waiting ark across the same open island")
	var return_shore_frames := await _hold_until(KEY_W, 420, func() -> bool: return player.global_position.z <= ark_root.global_position.z + 4.0)
	assert(return_shore_frames < 420, "the route back should remain open across the shore and surrounding water")
	_set_key(KEY_W, true)
	var outer_board_frames := 0
	for _attempt in range(5):
		_set_key(KEY_SPACE, true)
		_set_key(KEY_SPACE, false)
		for _frame in range(55):
			await physics_frame
			outer_board_frames += 1
			if player.is_on_floor() and player.global_position.z <= ark_root.global_position.z + 1.6:
				break
		if player.is_on_floor() and player.global_position.z <= ark_root.global_position.z + 1.6:
			break
	_set_key(KEY_W, false)
	await physics_frame
	assert(outer_board_frames < 120 and player.is_on_floor() and absf(player.global_position.x - ark_root.global_position.x) <= 1.0, "the player should physically reboard the ark after the outer-islet expedition")
	assert(int(game.get("pressure_cores")) == 1 and bool(game.get("pressure_wreck_searched")), "the unique outer-islet salvage should return aboard intact")
	game.call("_save_progress")
	var elapsed := first_leg + second_leg + reef_approach + reef_walk + wreck_approach + return_north + return_west_channel + return_south + return_to_ark + board_ark
	_set_key(KEY_SHIFT, false)
	print("ARK_WORLD_TRAVEL_TEST_OK: x=%.1f z=%.1f elapsed=%d" % [player.global_position.x, player.global_position.z, elapsed])
	game.queue_free()
	await process_frame
	var restored := scene.instantiate()
	restored.set("save_root_override", save_root)
	root.add_child(restored)
	await process_frame
	assert(bool(restored.get("raft_extension_built")) and restored.get_node_or_null("ArkRoot/BuiltRaftExtension") != null, "the home-grown deck should survive save and reload")
	assert(bool(restored.get("keel_wreck_searched")) and int(restored.get("keel_beams")) == 0, "reload must preserve the one-time salvage history without duplicating the spent keel")
	assert(bool(restored.get("pressure_wreck_searched")) and int(restored.get("pressure_cores")) == 1 and (restored.get("learned_blueprint_ids") as Array).has("pressure_galley"), "the physical outer-islet expedition and learned blueprint should survive the return voyage")
	restored.queue_free()
	await process_frame
	save_helper.clear_for_test()
	quit(0)
