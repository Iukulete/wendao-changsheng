extends SceneTree

const MOONBACK_STATION := Vector3(-28.0, 0.2, 23.0)
const TEST_DELTA := 1.0 / 30.0


func _initialize() -> void:
	_run.call_deferred()


func _key_event(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	return event


func _set_key(keycode: Key, pressed: bool) -> void:
	Input.parse_input_event(_key_event(keycode, pressed))


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


func _sail_to(game: Node, target: Vector3, max_steps: int = 2400) -> int:
	var ark := game.get_node("ArkRoot") as Node3D
	var steps := 0
	while steps < max_steps and Vector2(ark.global_position.x - target.x, ark.global_position.z - target.z).length() > 1.8:
		var offset := target - ark.global_position
		var desired_yaw := atan2(-offset.x, -offset.z)
		var yaw_error := wrapf(desired_yaw - ark.rotation.y, -PI, PI)
		var steer := clampf(yaw_error * 2.2, -1.0, 1.0)
		var distance := Vector2(offset.x, offset.z).length()
		var throttle := 1.0 if distance > 1.7 and absf(yaw_error) < 0.28 else 0.0
		var moved: bool = game.call("_sail_step", TEST_DELTA, throttle, steer)
		assert(moved, "the planned open-water route should not collide with a shore or world edge at %s" % ark.global_position)
		steps += 1
	return steps


func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_save_mooring").simplify_path()
	assert(save_root.to_lower().begins_with("d:"), "mooring regression saves must remain on D:")
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	save_helper.clear_for_test()
	var scene := load("res://scenes/ark_greybox.tscn") as PackedScene
	assert(scene != null, "the open-world ark scene must load")
	var game := scene.instantiate()
	game.set("save_root_override", save_root)
	root.add_child(game)
	await physics_frame
	await physics_frame

	var ark := game.get_node("ArkRoot") as Node3D
	var player := game.get("player") as CharacterBody3D
	var chart_before := ark.global_position
	game.call("_on_world_chart_destination_selected", "moonback", "月背泊地")
	assert(ark.global_position.is_equal_approx(chart_before) and player.global_position.distance_to(chart_before) < 3.0, "choosing the chart marker must only record direction, never teleport the ark or player")
	assert((game.get("world_events") as Array).back().get("id", "") == "chart_destination_considered", "considering the destination should leave a factual event")

	# A real rudder trip establishes a second mooring in the same continuous world.
	game.set("weather_phase", 2)
	game.call("_toggle_sailing")
	assert(bool(game.get("sailing_mode")), "the repaired ark should be sail-ready after the opening storm")
	var first_leg := await _sail_to(game, Vector3(-28.0, 0.0, 6.0))
	var heading_steps := 0
	while heading_steps < 180 and absf(wrapf(-ark.rotation.y, -PI, PI)) > 0.08:
		var yaw_error := wrapf(-ark.rotation.y, -PI, PI)
		var turned: bool = game.call("_sail_step", TEST_DELTA, 0.0, clampf(yaw_error * 2.2, -1.0, 1.0))
		assert(turned, "the ark should be able to align its stern at the open-water mooring")
		heading_steps += 1
	print("MOONBACK_DOCK: steps=%d position=%s yaw=%.3f heading_steps=%d" % [first_leg, ark.global_position, ark.rotation.y, heading_steps])
	assert(Vector2(ark.global_position.x + 28.0, ark.global_position.z - 6.0).length() <= 2.1, "the ark should physically reach the north-side mooring approach")
	assert(absf(ark.rotation.y) < 0.08, "the stern gangplank should face the island")
	game.call("_toggle_sailing")
	var shore_leg := await _hold_until(KEY_S, 900, func() -> bool: return player.global_position.distance_to(MOONBACK_STATION) < 2.6)
	print("MOONBACK_SHORE: frames=%d boat=%s player=%s floor=%s swim=%s" % [shore_leg, ark.global_position, player.global_position, player.is_on_floor(), game.get("is_swimming")])
	assert(shore_leg < 900 and player.global_position.distance_to(MOONBACK_STATION) < 2.8, "the player should disembark and reach the tide station on foot")
	game.call("_interact")
	assert(bool(game.get("tide_station_searched")) and int(game.get("tide_relay_cores")) == 1, "the station should yield exactly one relay core")
	assert(bool(game.call("_has_blueprint", "tide_compass")), "the station should teach a permanent tide-compass blueprint")
	var learned := game.get("learned_blueprint_ids") as Array
	assert(learned.count("tide_compass") == 1, "permanent knowledge should not create duplicate blueprint entries")
	var events: Array = game.get("world_events")
	var salvage_events := 0
	for event in events:
		if str(event.get("id", "")) == "tide_station_salvaged":
			salvage_events += 1
	assert(salvage_events == 1, "the unique station reward should create one salvage event")
	game.call("_interact")
	assert(int(game.get("tide_relay_cores")) == 1 and (game.get("learned_blueprint_ids") as Array).count("tide_compass") == 1, "searching an empty station again must not duplicate its reward")
	game.call("_save_progress")
	game.queue_free()
	await process_frame

	var restored_at_moonback := scene.instantiate()
	restored_at_moonback.set("save_root_override", save_root)
	root.add_child(restored_at_moonback)
	await physics_frame
	await physics_frame
	assert(bool(restored_at_moonback.get("tide_station_searched")) and int(restored_at_moonback.get("tide_relay_cores")) == 1, "a mid-expedition reload should preserve the unspent unique core")
	assert(bool(restored_at_moonback.call("_has_blueprint", "tide_compass")), "the learned blueprint must remain permanent after a mid-expedition reload")
	assert(restored_at_moonback.get_node("MoonbackTideStation").get_node_or_null("RelayCore") == null, "the salvaged core prop must stay absent after a mid-expedition reload")
	var restored_events: Array = restored_at_moonback.get("world_events")
	assert(restored_events.filter(func(event: Dictionary) -> bool: return str(event.get("id", "")) == "tide_station_salvaged").size() == 1, "reload must preserve exactly one salvage event")
	game = restored_at_moonback
	ark = game.get_node("ArkRoot") as Node3D
	player = game.get("player") as CharacterBody3D

	var return_to_helm := await _hold_until(KEY_W, 1000, func() -> bool: return Vector2(player.global_position.x - ark.global_position.x, player.global_position.z - (ark.global_position.z + 1.55)).length() < 2.0)
	assert(return_to_helm < 1000, "the player should walk back onto the same ark after searching the station")
	game.call("_interact")
	assert(bool(game.get("sailing_mode")), "the same ark should be controllable after the expedition")
	var second_leg := await _sail_to(game, Vector3(0.0, 0.0, 0.0))
	game.call("_toggle_sailing")
	assert(not bool(game.get("sailing_mode")), "the player should arrive home and leave the helm")

	# The workbench is prepared through the normal construction API; move across the deck to use it.
	game.set("wood", 8)
	assert(bool(game.call("_try_place_workbench", Vector3(-2.0, 0.12, 0.7))), "the home-side fixture should construct a workbench from resources")
	player.position = Vector3(-1.8, 1.1, 0.9)
	game.call("_interact")
	assert(bool(game.get("tide_compass_tuned")) and int(game.get("tide_relay_cores")) == 0, "the recovered core should tune the tide compass at the workbench")
	assert(is_equal_approx(float(game.call("_current_sail_speed")), 4.6), "tuning should create a measurable permanent sail-speed improvement")
	game.call("_save_progress")
	game.queue_free()
	await process_frame

	var restored := scene.instantiate()
	restored.set("save_root_override", save_root)
	root.add_child(restored)
	await physics_frame
	await physics_frame
	assert(bool(restored.get("tide_station_searched")) and int(restored.get("tide_relay_cores")) == 0, "reload should preserve the searched site and spent relay core")
	assert(bool(restored.call("_has_blueprint", "tide_compass")) and bool(restored.get("tide_compass_tuned")), "reload should preserve permanent blueprint knowledge and the tuned compass")
	assert(is_equal_approx(float(restored.call("_current_sail_speed")), 4.6), "the upgraded sail speed should survive reload")
	assert(restored.get_node("MoonbackTideStation").get_node_or_null("RelayCore") == null, "the collected world prop must remain absent after reload")
	assert((restored.get("world_events") as Array).any(func(event: Dictionary) -> bool: return str(event.get("id", "")) == "tide_compass_tuned"), "the saved event ledger should explain the upgrade")
	print("ARK_MOORING_TEST_OK: first_leg=%d return_leg=%d heading=%d" % [first_leg, second_leg, heading_steps])
	restored.queue_free()
	await process_frame
	save_helper.clear_for_test()
	quit(0)
