extends SceneTree

## Editing must be transactional: preview is not a second build or saved state.
## Keep saves inside the checkout on both Windows and cloud Linux.
const ArkTestPaths = preload("res://tests/ark_test_paths.gd")
const FixturePlacement = preload("res://scripts/ark_fixture_placement.gd")
const SAVE_DIR := "res://../.local/test_fixture_edit_save"


func _initialize() -> void:
	_run.call_deferred()


func _new_game(scene: PackedScene, save_root: String) -> Node:
	var game := scene.instantiate()
	game.set("save_root_override", save_root)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	(game.get("player") as Node).set_physics_process(false)
	await physics_frame
	return game


func _marker(game: Node, fixture_id: String) -> Node3D:
	var found: Node3D = null
	var count := 0
	for entry in game.get("interactables") as Array:
		if str(entry.get("id", "")) == fixture_id:
			count += 1
			found = entry.get("node") as Node3D
	assert(count == 1 and found != null, "each fixture must have exactly one live interaction marker")
	return found


func _press_key(game: Node, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	game.call("_unhandled_key_input", event)


func _start_edit(game: Node, fixture_id: String) -> void:
	var player := game.get("player") as Node3D
	player.global_position = _marker(game, fixture_id).global_position + Vector3(0.0, 0.6, 0.8)
	_press_key(game, KEY_F)
	assert(bool(game.get("building_mode")) and str(game.get("editing_fixture_id")) == fixture_id, "edit mode must identify its source fixture")


func _resource_state(game: Node) -> Array:
	return [game.get("wood"), game.get("stored_wood"), game.get("ancient_parts"), game.get("keel_beams"), game.get("lantern_tuned"), game.get("tide_compass_tuned"), (game.get("learned_blueprint_ids") as Array).duplicate()]


func _assert_fixture(game: Node, fixture_id: String, position: Vector3, turns: int) -> void:
	var node_name := "BuiltStorage" if fixture_id == "storage" else "BuiltWorkbench"
	var fixture := game.get_node("ArkRoot/" + node_name) as Node3D
	var ark := game.get_node("ArkRoot") as Node3D
	assert((game.get(fixture_id + "_position") as Vector3).is_equal_approx(position), "saved placement state must match the confirmed local point")
	assert(fixture.position.is_equal_approx(position), "fixture model must keep its deck-local placement")
	assert(is_equal_approx(wrapf(fixture.rotation.y, 0.0, TAU), float(turns) * PI * 0.5), "model orientation must match quarter-turn state")
	assert(int(game.get(fixture_id + "_quarter_turns")) == turns, "orientation state must be normalized")
	assert(fixture.global_position.is_equal_approx(ark.to_global(position)), "model must follow the moving ark")
	var marker := _marker(game, fixture_id)
	assert(Vector2(marker.position.x, marker.position.z).is_equal_approx(Vector2(position.x, position.z)), "interaction must follow the new placement rather than remain at the old point")
	assert(marker.get_parent() == ark, "interaction marker must remain deck-local")


func _assert_collision_mode(game: Node, fixture_id: String, enabled: bool) -> void:
	assert(bool(game.get(fixture_id + "_collision_enabled")) == enabled, "collision activation must be explicit saved state")
	var fixture: Node3D = game.call("_fixture_node", fixture_id)
	var body_count := 0
	for child in fixture.get_children():
		if child is StaticBody3D:
			body_count += 1
			assert((child.collision_layer != 0) == enabled, "solid bodies must agree with their collision activation state")
	assert(body_count >= 2, "both the fixture body and tabletop/lid must retain solid geometry")


func _valid_other_position(game: Node, fixture_id: String, old: Vector3, turns: int) -> Vector3:
	# Scan a fixed legal deck grid, not a random seed. Separate rejection tests below
	# independently require out-of-bounds, occupied, and doorway positions to fail.
	for z in [-1.5, 1.5, -1.0, 1.0, 0.0]:
		for x in [-2.0, 2.0, -2.5, 2.5]:
			var candidate := Vector3(x, 0.12, z)
			if candidate.distance_to(old) > 0.25 and str(game.call("_fixture_placement_error", fixture_id, candidate, turns)).is_empty():
				return candidate
	assert(false, "the starter home must retain at least one usable alternate placement")
	return old


func _run() -> void:
	var save_root := ProjectSettings.globalize_path(SAVE_DIR).simplify_path()
	assert(ArkTestPaths.is_safe_save_root(save_root), "regression saves must stay in repository-local test storage")
	assert(FixturePlacement.saved_turns("bad") == 0 and FixturePlacement.saved_turns(INF) == 0 and FixturePlacement.saved_turns({}) == 0 and FixturePlacement.saved_turns([]) == 0 and FixturePlacement.saved_turns(-1) == 3, "malformed optional orientation must safely default")
	assert(FixturePlacement.normalize_turns(-1) == 3 and FixturePlacement.normalize_turns(4) == 0, "rotations must normalize without drift")
	assert(FixturePlacement.half_size("workbench", 1).is_equal_approx(Vector2(0.39, 0.56)), "rotation must swap the rectangular footprint")
	assert(not FixturePlacement.supported(Vector3(2.2, 0.12, 0.0), FixturePlacement.half_size("workbench", 0)), "unrotated overhang must fail")
	assert(FixturePlacement.supported(Vector3(2.2, 0.12, 0.0), FixturePlacement.half_size("workbench", 1)), "rotated footprint can fit where its unrotated width cannot")
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	save_helper.clear_for_test()
	var scene := load("res://scenes/ark_greybox.tscn") as PackedScene
	assert(scene != null, "ark scene must load")
	var game := await _new_game(scene, save_root)
	assert(not bool(game.call("_start_fixture_edit", "storage")), "editing must not create a missing fixture")
	assert(not bool(game.call("_start_fixture_edit", "not_a_fixture")), "unknown fixture IDs must be rejected")
	game.set("wood", 100)
	assert(bool(game.call("_try_place_shelter", Vector3(0.0, 0.12, -0.5))), "seed a real shelter")
	assert(bool(game.call("_try_place_storage", Vector3(2.0, 0.12, -1.5))), "seed a real storage fixture")
	assert(bool(game.call("_try_place_workbench", Vector3(-2.0, 0.12, 1.5))), "seed a real workbench")
	game.set("wood", 7)
	game.set("stored_wood", 11)
	game.set("ancient_parts", 2)
	game.set("keel_beams", 1)
	game.set("lantern_tuned", true)
	game.set("tide_compass_tuned", true)
	(game.get("learned_blueprint_ids") as Array).append("keel_deck_expansion")
	_assert_collision_mode(game, "storage", false)
	_assert_collision_mode(game, "workbench", false)
	var resources := _resource_state(game)
	await physics_frame

	for fixture_id in ["workbench", "storage"]:
		var node_name := "BuiltStorage" if fixture_id == "storage" else "BuiltWorkbench"
		var original := game.get_node("ArkRoot/" + node_name) as Node3D
		var original_id := original.get_instance_id()
		var marker_id := _marker(game, fixture_id).get_instance_id()
		var old: Vector3 = game.get(fixture_id + "_position")
		_start_edit(game, fixture_id)
		assert(is_instance_valid(game.get("build_preview")), "editing needs a visible preview")
		var weather_before: int = game.get("weather_phase")
		_press_key(game, KEY_R)
		assert(int(game.get("weather_phase")) == weather_before, "R in edit mode must rotate furniture rather than change weather")
		assert(int(game.get("preview_quarter_turns")) == 1, "rotate advances the preview by one quarter turn")
		_assert_fixture(game, fixture_id, old, 0)
		assert(_resource_state(game) == resources, "preview must not charge or move materials")
		assert(bool(game.call("_save_progress")), "saving with a preview open must remain possible")
		var preview_save: Dictionary = save_helper.load_state().get("state", {})
		assert(int(preview_save.get(fixture_id + "_quarter_turns", -1)) == 0, "unconfirmed rotation must not enter a save")
		var preview_saved_position: Dictionary = preview_save.get(fixture_id + "_position", {})
		assert(is_equal_approx(float(preview_saved_position.get("x")), old.x) and is_equal_approx(float(preview_saved_position.get("z")), old.z), "unconfirmed preview must not replace saved placement")
		_press_key(game, KEY_ESCAPE)
		await process_frame
		assert(not bool(game.get("building_mode")) and game.get("build_preview") == null, "cancel must remove the preview")
		_assert_fixture(game, fixture_id, old, 0)
		assert(original.get_instance_id() == original_id and _marker(game, fixture_id).get_instance_id() == marker_id, "cancel must preserve fixture and interaction identities")

		_start_edit(game, fixture_id)
		for invalid in [Vector3(20.0, 0.12, 20.0), Vector3(0.0, 0.12, 0.0), Vector3(INF, 0.12, 0.0)]:
			assert(not str(game.call("_fixture_placement_error", fixture_id, invalid, 1)).is_empty(), "edge and building overlap must be invalid")
			assert(not bool(game.call("_try_move_fixture", invalid, 1)), "invalid confirmation must not commit")
			_assert_fixture(game, fixture_id, old, 0)
		assert(not str(game.call("_fixture_placement_error", fixture_id, Vector3(-2.15, 0.12, -0.9), 0)).is_empty(), "fixed lantern space must not be occupied by moved furniture")
		var other_id := "workbench" if fixture_id == "storage" else "storage"
		var occupied: Vector3 = game.get(other_id + "_position")
		assert(not bool(game.call("_try_move_fixture", occupied, 0)), "moving onto the other fixture must fail")
		assert(_resource_state(game) == resources, "failed moves must not charge/refund or change upgrades and blueprints")
		(game.get("player") as Node3D).position = Vector3(0.0, 1.1, 1.75)
		var confirmed_turns := 1 if fixture_id == "workbench" else 3
		var target := _valid_other_position(game, fixture_id, old, confirmed_turns)
		# The location otherwise passes, so this specifically tests actor safety.
		var player := game.get("player") as Node3D
		var player_before := player.position
		player.position = target + Vector3(0.0, 1.0, 0.0)
		assert(not bool(game.call("_try_move_fixture", target, confirmed_turns)), "solid furniture must never be confirmed through the player")
		var half: Vector2 = FixturePlacement.half_size(fixture_id, confirmed_turns)
		player.position = target + Vector3(half.x + 0.30, 1.0, 0.0)
		assert(not bool(game.call("_try_move_fixture", target, confirmed_turns)), "player capsule radius, not the smaller resident radius, must prevent near-edge overlap")
		player.position = player_before
		assert(not str(game.call("_fixture_placement_error", fixture_id, Vector3(0.0, 0.12, 1.5), 0)).is_empty(), "a supported non-overlapping footprint blocking the helm/door passage must be rejected")
		game.set("traveler_routine_route_target_set", true)
		game.set("sailmaker_routine_route_target_set", true)
		assert(bool(game.call("_try_move_fixture", target, confirmed_turns)), "a valid rotated move must commit")
		assert(not bool(game.get("building_mode")), "successful move must exit editing")
		assert(not bool(game.get("traveler_routine_route_target_set")) and not bool(game.get("sailmaker_routine_route_target_set")), "both residents must replan stale routes after furniture moves")
		assert(game.get_node("ArkRoot/" + node_name).get_instance_id() == original_id and _marker(game, fixture_id).get_instance_id() == marker_id, "moving must transform existing objects, not duplicate them")
		_assert_fixture(game, fixture_id, target, confirmed_turns)
		_assert_collision_mode(game, fixture_id, true)
		assert(_resource_state(game) == resources, "successful move must preserve material accounts and unlocks")
		assert(not bool(game.call("_try_move_fixture", old, 0)), "confirmation without active editing must not perform a second move")
		await physics_frame

	var storage_position: Vector3 = game.get("storage_position")
	var workbench_position: Vector3 = game.get("workbench_position")
	var ark := game.get_node("ArkRoot") as Node3D
	ark.position = Vector3(-8.0, 0.0, 3.0)
	ark.rotation.y = 0.65
	_assert_fixture(game, "storage", storage_position, 3)
	_assert_fixture(game, "workbench", workbench_position, 1)
	game.set("sailing_mode", true)
	assert(not bool(game.call("_start_fixture_edit", "storage")), "editing while sailing must be rejected")
	game.set("sailing_mode", false)
	assert(bool(game.call("_save_progress")), "confirmed fixtures must save")
	var saved: Dictionary = save_helper.load_state().get("state", {})
	assert(int(saved.get("schema_version", 0)) == 33, "fixture orientations use schema 33")
	game.queue_free()
	await process_frame
	game = await _new_game(scene, save_root)
	_assert_fixture(game, "storage", storage_position, 3)
	_assert_fixture(game, "workbench", workbench_position, 1)
	assert((game.get_node("ArkRoot") as Node3D).position.is_equal_approx(Vector3(-8.0, 0.0, 3.0)), "reload preserves sailed ark position")
	assert(_resource_state(game) == resources, "reload preserves both inventory accounts and upgrades")
	_assert_collision_mode(game, "storage", true)
	_assert_collision_mode(game, "workbench", true)
	# Use the actual E interaction dispatcher at the relocated marker, not the direct storage handler.
	(game.get("player") as Node3D).global_position = _marker(game, "storage").global_position + Vector3(0.0, 0.15, 0.0)
	_press_key(game, KEY_E)
	assert(int(game.get("wood")) == 0 and int(game.get("stored_wood")) == 18, "moved storage must retain ordinary deposit functionality")
	_press_key(game, KEY_E)
	assert(int(game.get("wood")) == 18 and int(game.get("stored_wood")) == 0, "moved storage must retain ordinary withdrawal functionality")
	game.queue_free()
	await process_frame

	# A pre-edit schema has no orientation keys. Its original yaw must remain zero.
	saved["schema_version"] = 32
	saved.erase("storage_quarter_turns")
	saved.erase("workbench_quarter_turns")
	assert(bool(save_helper.save_state(saved).get("ok", false)), "legacy state must seed")
	game = await _new_game(scene, save_root)
	_assert_fixture(game, "storage", storage_position, 0)
	_assert_fixture(game, "workbench", workbench_position, 0)
	assert(_resource_state(game) == resources, "legacy orientation migration must not rewrite resource history")
	_assert_collision_mode(game, "storage", false)
	_assert_collision_mode(game, "workbench", false)
	game.queue_free()
	await process_frame
	# Resume the valid rotated layout for behavioral checks; defaulting a deliberately
	# synthetic legacy save does not imply its old yaw has a valid new footprint.
	saved["schema_version"] = 33
	saved["storage_quarter_turns"] = 3
	saved["workbench_quarter_turns"] = 1
	assert(bool(save_helper.save_state(saved).get("ok", false)), "restore modern layout before resident checks")
	game = await _new_game(scene, save_root)
	# A subsequent daily target can be occupied even when the resident was elsewhere
	# during editing. Schedules must choose a clear reachable replacement, not force
	# an A* endpoint inside a newly collidable crate.
	_start_edit(game, "storage")
	(game.get("player") as Node3D).position = Vector3(0.0, 1.1, 1.75)
	assert(bool(game.call("_try_move_fixture", Vector3(2.0, 0.12, -1.0), 1)), "place a crate beside the future sail-repair work area")
	await physics_frame
	game.set("sailmaker_boarded", true)
	game.call("_set_sailmaker_boarded")
	game.set("weather_phase", 2)
	game.set("raft_edge_damaged", true)
	game.set("shelter_roof_damaged", false)
	game.call("_update_sailmaker_schedule")
	var routine_target: Vector3 = game.get("sailmaker_target_position")
	assert(not routine_target.is_equal_approx(Vector3(1.45, 0.12, -1.25)), "a later repair schedule must redirect its now-obstructed target")
	assert(not bool(game.call("_ark_local_walk_cell_blocked", Vector2(routine_target.x, routine_target.z))), "redirected resident target must have actual clearance")
	var resident := game.get("sailmaker_marker") as Node3D
	resident.position = Vector3(0.0, 0.12, 1.5)
	var route: PackedVector3Array = game.call("_build_ark_local_walk_route", resident.position, routine_target)
	assert(not route.is_empty(), "resident must retain an actual route to the replacement task target")
	for waypoint in route:
		assert(not FixturePlacement.contains_actor(Vector2(waypoint.x, waypoint.z), Vector3(2.0, 0.12, -1.0), FixturePlacement.half_size("storage", 1)), "resident route must not cut through the moved storage footprint")
	game.queue_free()
	await process_frame
	saved["schema_version"] = 33
	saved["storage_quarter_turns"] = {"bad": true}
	saved["workbench_quarter_turns"] = [1, 2]
	assert(bool(save_helper.save_state(saved).get("ok", false)), "partially malformed new save must seed")
	game = await _new_game(scene, save_root)
	_assert_fixture(game, "storage", storage_position, 0)
	_assert_fixture(game, "workbench", workbench_position, 0)
	assert(_resource_state(game) == resources, "bad optional rotation fields must not suppress valid resource data")
	game.queue_free()
	await process_frame
	# Default pre-edit layouts were nonblocking. Loading one must not trap residents
	# behind furniture when they walk to an existing expanded-deck berth.
	saved["schema_version"] = 32
	saved["ark_position"] = {"x": 0.0, "y": 0.0, "z": 0.0}
	saved["ark_yaw"] = 0.0
	saved["shelter_position"] = {"x": 0.0, "y": 0.12, "z": 0.0}
	saved["storage_position"] = {"x": 2.0, "y": 0.12, "z": -1.5}
	saved["workbench_position"] = {"x": -2.0, "y": 0.12, "z": 1.5}
	saved["raft_extension_built"] = false
	saved["traveler_boarded"] = false
	assert(bool(save_helper.save_state(saved).get("ok", false)), "seed exact legacy starter home for editing")
	game = await _new_game(scene, save_root)
	_start_edit(game, "storage")
	(game.get("player") as Node3D).position = Vector3(0.0, 1.1, 1.75)
	assert(bool(game.call("_try_move_fixture", Vector3(2.0, 0.12, 0.0), 1)), "exact legacy starter layout must support a useful validated storage move")
	_assert_fixture(game, "storage", Vector3(2.0, 0.12, 0.0), 1)
	_assert_collision_mode(game, "storage", true)
	_assert_collision_mode(game, "workbench", false)
	_start_edit(game, "workbench")
	(game.get("player") as Node3D).position = Vector3(0.0, 1.1, 1.75)
	var legacy_bench_target := _valid_other_position(game, "workbench", Vector3(-2.0, 0.12, 1.5), 1)
	assert(bool(game.call("_try_move_fixture", legacy_bench_target, 1)), "legacy starter workbench must support a validated edit after storage moves")
	_assert_fixture(game, "workbench", legacy_bench_target, 1)
	_assert_collision_mode(game, "workbench", true)
	assert(bool(game.call("_fixture_routes_clear", "workbench", legacy_bench_target, 1)), "both edited solid fixtures must preserve required paths")
	game.queue_free()
	await process_frame
	saved["raft_extension_built"] = true
	saved["traveler_boarded"] = true
	saved["resident_gather_pending"] = false
	saved["weather_phase"] = 2
	saved["day_period"] = 3
	assert(bool(save_helper.save_state(saved).get("ok", false)), "legacy default home and expanded deck must seed")
	game = await _new_game(scene, save_root)
	_assert_collision_mode(game, "storage", false)
	_assert_collision_mode(game, "workbench", false)
	game.call("_abort_resident_gathering", "fixture_legacy_test")
	game.set("day_period", 3)
	game.set("weather_phase", 2)
	game.call("_update_traveler_schedule")
	assert((game.get("traveler_target_position") as Vector3).is_equal_approx(Vector3(0.95, 0.24, -5.35)), "legacy resident still chooses the expanded-deck berth")
	for _step in range(30):
		game.call("_process", 1.0)
	assert((game.get("traveler_marker") as Node3D).position.is_equal_approx(game.get("traveler_target_position")), "legacy furniture must not trap residents en route to their existing berth")
	game.queue_free()
	await process_frame
	save_helper.clear_for_test()
	print("ARK_FIXTURE_EDIT_TEST_OK:")
	quit()
