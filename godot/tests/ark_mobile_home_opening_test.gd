extends SceneTree

const ArkTestPaths = preload("res://tests/ark_test_paths.gd")

# Acceptance scope: real E/W input and collision-checked continuous boat travel.
# Shore interactions use explicitly positioned player fixtures, not a claim that
# this test walks/swims every island leg. No inventory or AFTER-state injection.
func _initialize() -> void:
	_run.call_deferred()

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _tap(code: Key) -> void:
	_key(code, true)
	_key(code, false)

func _interactable(game: Node, id: String) -> Node3D:
	for entry in game.get("interactables") as Array:
		if str(entry.get("id", "")) == id:
			return entry.node as Node3D
	return null

func _at_interaction(game: Node, id: String) -> void:
	var target := _interactable(game, id)
	assert(target != null, "world interaction must actually exist: " + id)
	var player := game.get("player") as CharacterBody3D
	player.global_position = target.global_position + Vector3(0, 0.4, 0)
	player.velocity = Vector3.ZERO
	_tap(KEY_E)

func _sail_to(game: Node, target: Vector2) -> void:
	var ark := game.get_node("ArkRoot") as Node3D
	for step in range(2400):
		var offset := target - Vector2(ark.position.x, ark.position.z)
		if offset.length() < 0.65:
			return
		var yaw_error := wrapf(atan2(-offset.x, -offset.y) - ark.rotation.y, -PI, PI)
		var throttle := 1.0 if absf(yaw_error) < 0.15 else 0.0
		assert(bool(game.call("_sail_step", 1.0 / 30.0, throttle, clampf(yaw_error * 3.0, -1.0, 1.0))), "open-water route blocked at %s toward %s" % [ark.position, target])
		if step % 60 == 0:
			await physics_frame
	assert(false, "boat did not reach waypoint %s" % target)

func _event_count(game: Node, id: String) -> int:
	var count := 0
	for event in game.get("world_events") as Array:
		if str(event.get("id", "")) == id:
			count += 1
	return count

func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_mobile_home_opening").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(save_root))
	var saves := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	saves.clear_for_test()
	var scene := load("res://scenes/ark_greybox.tscn") as PackedScene
	var game := scene.instantiate()
	game.set("save_root_override", save_root)
	root.add_child(game)
	await physics_frame
	await physics_frame
	var ark := game.get_node("ArkRoot") as Node3D
	var player := game.get("player") as CharacterBody3D
	assert(int(game.get("weather_phase")) == 0 and int(game.get("wood")) == 1)
	assert(not bool(game.get("shelter_built")) and not bool(game.get("raft_edge_damaged")))
	# Starting position must expose the helm through ordinary E input.
	_tap(KEY_E)
	assert(bool(game.get("sailing_mode")), "new-game FORECAST must allow E to take the intact helm, before construction")
	var start := ark.global_position
	_key(KEY_S, true)
	for frame in range(45):
		await physics_frame
	_key(KEY_S, false)
	await physics_frame
	assert(ark.global_position.distance_to(start) > 1.0, "held movement input must move the new-game ship, not only toggle a flag")
	print("EARLY_HOME_INPUT_LEG: displacement=%.2f phase=%d wood=%d" % [ark.global_position.distance_to(start), int(game.get("weather_phase")), int(game.get("wood"))])
	assert(player.get_parent() == ark and player.global_position.distance_to(ark.global_position) < 4.0, "the player must travel aboard")
	_tap(KEY_E)
	assert(not bool(game.get("sailing_mode")), "E must dock in place")
	# Collect finite, real opening resources; explicitly isolate shore walking.
	for pile in range(3):
		_at_interaction(game, "wood")
		await process_frame
	assert(int(game.get("wood")) == 8, "initial one plank plus the three real 2+2+3 piles must fund the home")
	player.position = Vector3(0, 1.1, 1.55)
	assert(bool(game.call("_try_place_shelter", Vector3(0, 0.12, 0))))
	assert(int(game.get("wood")) == 5, "shelter costs three gathered planks")
	assert(bool(game.call("_try_place_storage", Vector3(2, 0.12, 1))))
	assert(int(game.get("wood")) == 3, "storage costs two gathered planks")
	assert(bool(game.call("_try_place_workbench", Vector3(-2, 0.12, 1))))
	assert(int(game.get("wood")) == 1, "workbench costs two: the complete home must be affordable before storm")
	_at_interaction(game, "resident")
	assert(bool(game.get("resident_met")) and not bool(game.get("traveler_boarded")))
	_at_interaction(game, "resident")
	assert(bool(game.get("traveler_choice_pending")) and not bool(game.get("traveler_boarded")), "shelter enables an invitation, never automatic boarding")
	_tap(KEY_2)
	assert(not bool(game.get("traveler_boarded")), "declining must respect resident consent")
	_at_interaction(game, "resident")
	_tap(KEY_1)
	assert(bool(game.get("traveler_boarded")), "explicit invitation should bring the resident aboard")
	var resident := game.get("traveler_marker") as Node3D
	assert(resident.get_parent() == ark)
	_at_interaction(game, "helm")
	assert(bool(game.get("sailing_mode")))
	# No direct ship-transform assignment: all legs turn and translate through
	# the production swept-hull navigation method. The authored opening coast
	# intersects the old x=27 straight lane. This test-only dogleg clears its
	# actual hull footprint, then returns west of FarReef; navigation is unchanged.
	for waypoint in [Vector2(0, 8), Vector2(29, 8), Vector2(29, -22), Vector2(27, -25), Vector2(27, -42), Vector2(39, -42)]:
		await _sail_to(game, waypoint)
	assert(not bool(game.call("_is_ark_position_navigable", Vector3(39, 0, -29))), "a reef interior must not be navigable")
	# Aim toward the reef using the real rudder, then try one oversized move.
	# Swept substeps must reject the shore, not tunnel across it.
	for turn_step in range(180):
		var yaw_error := wrapf(PI - ark.rotation.y, -PI, PI)
		if absf(yaw_error) < 0.03:
			break
		assert(bool(game.call("_sail_step", 1.0 / 30.0, 0.0, clampf(yaw_error * 3.0, -1.0, 1.0))))
	assert(absf(wrapf(PI - ark.rotation.y, -PI, PI)) < 0.03)
	var before_collision := ark.global_position
	assert(not bool(game.call("_sail_step", 6.0, 1.0, 0.0)), "oversized forward motion must collide with the intervening reef")
	assert(ark.global_position.is_equal_approx(before_collision), "blocked swept move must restore the last safe mooring")
	assert(_event_count(game, "ark_navigation_blocked") > 0)
	_tap(KEY_E)
	var reef_mooring := ark.global_position
	_at_interaction(game, "keel_wreck")
	assert(bool(game.get("keel_wreck_searched")) and int(game.get("keel_beams")) == 1 and int(game.get("wood")) == 5, "actual wreck interaction yields unique keel and four planks")
	_at_interaction(game, "keel_wreck")
	assert(int(game.get("keel_beams")) == 1 and int(game.get("wood")) == 5 and _event_count(game, "keel_wreck_salvaged") == 1)
	assert(ark.global_position.is_equal_approx(reef_mooring), "shore interaction must leave the home at its real mooring")
	_at_interaction(game, "helm")
	for waypoint in [Vector2(27, -42), Vector2(27, -25), Vector2(29, -22), Vector2(29, 8), Vector2(0, 8), Vector2(-10, 0)]:
		await _sail_to(game, waypoint)
	_tap(KEY_E)
	assert(bool(game.call("_try_place_raft_extension", Vector3(0, 0.12, -4.2))), "bring unique salvage home and construct the deck through the normal cost transaction")
	assert(int(game.get("wood")) == 1 and int(game.get("keel_beams")) == 0)
	var extension := ark.get_node("BuiltRaftExtension") as Node3D
	var extension_local := extension.position
	_at_interaction(game, "helm")
	await _sail_to(game, Vector2(-16, -6))
	assert(extension.position.is_equal_approx(extension_local) and extension.global_position.distance_to(ark.global_position) < 7.0, "expanded deck must follow the mobile home")
	assert(resident.get_parent() == ark and resident.global_position.distance_to(ark.global_position) < 5.0, "consenting resident must follow the boat")
	_tap(KEY_E)
	var saved_position := ark.global_position
	assert(bool(game.call("_save_progress")))
	game.queue_free()
	await process_frame
	game = scene.instantiate()
	game.set("save_root_override", save_root)
	root.add_child(game)
	await physics_frame
	await physics_frame
	ark = game.get_node("ArkRoot") as Node3D
	assert(ark.global_position.distance_to(saved_position) < 0.05, "reload must restore the new mooring, not the starting beach")
	for path in ["BuiltShelter", "BuiltStorage", "BuiltWorkbench", "BuiltRaftExtension"]:
		assert(ark.get_node_or_null(path) != null, "fixture must persist under moving home: " + path)
	assert(bool(game.get("traveler_boarded")) and (game.get("traveler_marker") as Node3D).get_parent() == ark)
	assert(int(game.get("weather_phase")) == 0 and int(game.get("wood")) == 1 and int(game.get("keel_beams")) == 0)
	_at_interaction(game, "keel_wreck")
	assert(int(game.get("wood")) == 1 and int(game.get("keel_beams")) == 0 and _event_count(game, "keel_wreck_salvaged") == 1, "reload cannot regenerate the spent unique award")
	_at_interaction(game, "helm")
	assert(bool(game.get("sailing_mode")))
	game.call("_advance_weather")
	assert(int(game.get("weather_phase")) == 1 and not bool(game.get("sailing_mode")), "storm arrival must stop an already moving ship")
	var storm_position := ark.global_position
	assert(not bool(game.call("_sail_step", 1.0, 1.0, 0.0)) and ark.global_position.is_equal_approx(storm_position))
	_at_interaction(game, "helm")
	assert(not bool(game.get("sailing_mode")), "STORM must still prevent departure")
	# Negative fixture only: damage gating is independent of the storm gate.
	game.set("weather_phase", 0)
	game.set("raft_edge_damaged", true)
	_at_interaction(game, "helm")
	assert(not bool(game.get("sailing_mode")), "an actually damaged edge must still prevent FORECAST departure")
	game.queue_free()
	await process_frame
	saves.clear_for_test()
	print("ARK_MOBILE_HOME_OPENING_TEST_OK: fresh FORECAST E/input sailing; real finite resources/costs; consent; swept-hull round trip; unique salvage/deck; moved-home reload; storm/damage gates (shore interactions positioned explicitly)")
	quit(0)
