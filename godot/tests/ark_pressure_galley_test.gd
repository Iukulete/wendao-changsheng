extends SceneTree

const ArkTestPaths = preload("res://tests/ark_test_paths.gd")

const PRESSURE_VENT_WINDUP_SECONDS := 1.4

func _initialize() -> void:
	_run.call_deferred()


func _count_events(game: Node, event_id: String) -> int:
	var count := 0
	for event in game.get("world_events") as Array:
		if str(event.get("id", "")) == event_id:
			count += 1
	return count


func _find_event(game: Node, event_id: String) -> Dictionary:
	for event in game.get("world_events") as Array:
		if str(event.get("id", "")) == event_id:
			return event
	return {}


func _new_game(scene: PackedScene, save_root: String) -> Node:
	var game := scene.instantiate()
	game.set_process(false)
	game.set_physics_process(false)
	game.set("save_root_override", save_root)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await physics_frame
	return game


func _send_key(game: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	game.call("_unhandled_key_input", event)


func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_pressure_galley_save").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(save_root), "test saves must be isolated in this repository; Windows saves must remain on D:")
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	save_helper.clear_for_test()
	var scene := load("res://scenes/ark_greybox.tscn") as PackedScene
	assert(scene != null, "the mobile-home survival scene must load")
	var game := await _new_game(scene, save_root)
	var sea := game.get_node("Sea") as MeshInstance3D
	assert(sea != null and (sea.mesh as PlaneMesh).size == Vector2(300.0, 300.0), "the continuous sea mesh should cover the enlarged outer region")
	assert(game.get_node_or_null("SteamWreckIslet") is StaticBody3D and game.get_node_or_null("PressureWreck") is Node3D, "the steam-era islet and wreck should exist as real world landmarks")
	assert(bool(game.call("_is_ark_position_navigable", Vector3(110.0, 0.0, 0.0))), "open water near the outer navigation limit should remain reachable")
	assert(bool(game.call("_is_ark_position_navigable", Vector3(92.0, 0.0, 68.0))), "the ship should be able to approach the mechanical islet through surrounding water")
	assert(not bool(game.call("_is_ark_position_navigable", Vector3(92.0, 0.0, 86.0))), "the island itself should remain land rather than becoming a fake water waypoint")
	var destinations: Array = game.call("_world_chart_destinations")
	var wreck_position := Vector3(92.0, 0.2, 86.0)
	var chart_has_wreck := false
	for destination in destinations:
		if str(destination.get("id", "")) == "pressure_wreck":
			var mapped_position: Vector3 = destination.get("position", Vector3.ZERO)
			chart_has_wreck = mapped_position.is_equal_approx(wreck_position)
	assert(chart_has_wreck, "the chart should show the outer mechanical wreck without teleporting the player")
	var chart_script := load("res://scripts/ark_world_chart.gd") as GDScript
	var game_constants := (load("res://scripts/ark_greybox.gd") as GDScript).get_script_constant_map()
	assert(float(chart_script.get_script_constant_map().get("WORLD_HALF_EXTENT", 0.0)) == float(game_constants.get("PLAYER_WORLD_EDGE_LIMIT", 0.0)), "the chart should include the full player swimming range beyond the ark navigation limit")
	var chart := chart_script.new() as Control
	chart.set("_map_rect", Rect2(Vector2.ZERO, Vector2(100.0, 100.0)))
	var wreck_map_position: Vector2 = chart.call("_world_to_map", wreck_position)
	assert(wreck_map_position.x > 0.0 and wreck_map_position.x < 100.0 and wreck_map_position.y > 0.0 and wreck_map_position.y < 100.0, "the outer steam islet should remain visible within chart bounds")
	chart.free()

	var player := game.get("player") as CharacterBody3D
	var wreck_marker := game.get_node("PressureWreckInteractable") as Node3D
	var vent_position := Vector3(93.65, 1.1, 85.88)
	player.global_position = vent_position
	game.call("_process_pressure_vent", 0.0)
	assert(bool(game.get("pressure_vent_warning_active")) and bool((game.get_node("PressureWreck/VentWarningRing") as MeshInstance3D).visible), "approaching the hot-pressure vent should visibly warn before it bursts")
	player.global_position += Vector3(4.0, 0.0, 0.0)
	game.call("_process_pressure_vent", PRESSURE_VENT_WINDUP_SECONDS)
	assert(int(game.get("player_health")) == 4 and _count_events(game, "pressure_vent_burst") == 1 and _count_events(game, "pressure_vent_hit") == 0, "the warning window should let the player dodge the vent without a level gate")
	game.set("pressure_vent_cooldown_remaining", 0.0)
	player.global_position = vent_position
	game.call("_process_pressure_vent", 0.0)
	game.call("_process_pressure_vent", PRESSURE_VENT_WINDUP_SECONDS)
	assert(int(game.get("player_health")) == 3 and _count_events(game, "pressure_vent_hit") == 1, "ignoring the second clear warning should cause one recoverable hit without removing inventory")
	assert(game.get_node("PressureWreck/SteamBurst") is GPUParticles3D, "the pressure release should have a visible steam burst at its source")
	player.global_position = wreck_marker.global_position + Vector3(0.0, 1.1, 0.0)
	game.call("_interact")
	assert(bool(game.get("pressure_wreck_searched")) and int(game.get("pressure_cores")) == 1, "searching the wreck should yield exactly one pressure core")
	assert((game.get("learned_blueprint_ids") as Array).has("pressure_galley"), "the steam galley should become permanent blueprint knowledge")
	assert(int(game.get("cold_exposure_level")) == 1 and int(game.get("player_health")) == 3 and _count_events(game, "pressure_wreck_salvaged") == 1, "the salvage should carry a readable cold cost and preserve the recoverable vent hit")
	assert(bool((_find_event(game, "pressure_wreck_salvaged").get("facts", {}) as Dictionary).get("vent_disarmed", false)), "recovering the unique pressure core should physically end the vent hazard")
	await process_frame
	assert(game.get_node_or_null("PressureWreck/PressureCore") == null, "the unique pressure core should visibly disappear after recovery")
	game.call("_process_pressure_vent", 8.0)
	assert(_count_events(game, "pressure_vent_hit") == 1 and int(game.get("player_health")) == 3, "a recovered core should not let the steam vent damage the player again")
	player.global_position = wreck_marker.global_position + Vector3(0.0, 1.1, 0.0)
	game.call("_interact")
	assert(int(game.get("pressure_cores")) == 1 and _count_events(game, "pressure_wreck_salvaged") == 1, "searching the wreck again must not duplicate the core or event")

	game.set("wood", 20)
	assert(bool(game.call("_try_place_workbench", Vector3(2.0, 0.12, 1.5))), "the player should be able to construct a real workbench on the outer deck")
	game.call("_interact_workbench")
	assert(not bool(game.get("pressure_galley_choice_pending")) and str(game.get("message")).contains("先搭起避风棚"), "the blueprint cannot be installed before a sheltered home exists")
	assert(bool(game.call("_try_place_shelter", Vector3(0.0, 0.12, -0.5))), "the player should be able to build the actual shelter required by the galley without overlapping the outer-deck workbench")
	game.call("_interact_workbench")
	assert(bool(game.get("pressure_galley_choice_pending")) and int(game.get("wood")) == 15 and int(game.get("pressure_cores")) == 1, "the install prompt should reserve no materials before confirmation")
	_send_key(game, KEY_2)
	assert(not bool(game.get("pressure_galley_choice_pending")) and int(game.get("wood")) == 15 and int(game.get("pressure_cores")) == 1 and _count_events(game, "pressure_galley_built") == 0, "cancelling should preserve all construction materials and the unique core")
	game.call("_interact_workbench")
	_send_key(game, KEY_1)
	assert(bool(game.get("pressure_galley_built")) and int(game.get("pressure_cores")) == 0 and int(game.get("wood")) == 12, "installing should consume exactly one core and three wood")
	var shelter := game.get_node("ArkRoot/BuiltShelter") as Node3D
	assert(shelter.get_node_or_null("PressureGalley") != null and shelter.get_node_or_null("HearthPot") == null, "the upgrade should replace the starter pot instead of stacking duplicate cookware")
	var hearth_marker := game.get_node("ArkRoot/HearthInteractable") as Node3D
	assert((hearth_marker.get_node("Name") as Label3D).text.contains("蒸汽饭釜"), "the installed appliance should update its in-world interaction label")
	assert(_count_events(game, "pressure_galley_built") == 1, "installation should create one auditable construction event")

	game.set("raw_shellfish", 1)
	game.call("_interact_hearth")
	assert(int(game.get("raw_shellfish")) == 0 and int(game.get("stew_servings")) == 1, "cooking should consume one real ingredient and create one serving")
	var cooked_event := _find_event(game, "meal_prepared")
	var cooked_facts: Dictionary = cooked_event.get("facts", {})
	assert(str(cooked_facts.get("tool_id", "")) == "pressure_galley" and int(cooked_facts.get("servings_added", 0)) == 1 and int(cooked_facts.get("warmth_levels", 0)) == 2, "the meal ledger should identify the actual appliance and serving outcome")
	game.set("resident_met", true)
	game.set("traveler_boarded", true)
	game.call("_set_traveler_boarded")
	game.set("cold_exposure_level", 3)
	game.set("cold_exposure", true)
	var traveler := game.get("traveler_marker") as Node3D
	player.global_position = traveler.global_position + Vector3(0.0, 1.1, 0.0)
	game.call("_interact")
	assert(int(game.get("cold_exposure_level")) == 1 and int(game.get("stew_servings")) == 0, "a shared meal from the pressure galley should relieve two of three cold levels")
	var shared_event := _find_event(game, "resident_meal_shared")
	var shared_facts: Dictionary = shared_event.get("facts", {})
	assert(int(shared_facts.get("cold_exposure_levels", 0)) == 2 and int(shared_facts.get("cold_exposure_level_after", 0)) == 1 and str(shared_facts.get("tool_id", "")) == "pressure_galley", "the shared meal event should preserve its exact warming and appliance facts")
	assert(bool(game.call("_save_progress")), "the upgraded home and meal should save")
	game.queue_free()
	await process_frame

	game = await _new_game(scene, save_root)
	assert(bool(game.get("pressure_wreck_searched")) and bool(game.get("pressure_galley_built")) and int(game.get("pressure_cores")) == 0, "the wreck, permanent blueprint, and spent core should survive reload without duplication")
	assert(game.get_node_or_null("ArkRoot/BuiltShelter/PressureGalley") != null and game.get_node_or_null("ArkRoot/BuiltShelter/HearthPot") == null, "the installed galley should reconstruct as the shelter's only cooking appliance")
	assert(int(game.get("cold_exposure_level")) == 1 and int(game.get("player_health")) == 4 and int(game.get("stew_servings")) == 0 and _count_events(game, "resident_meal_shared") == 1, "the shared meal should heal the vent injury and preserve its exact post-meal state once")
	assert(game.get_node_or_null("PressureWreck/PressureCore") == null, "reload must not restore the recovered core to the wreck")
	var legacy_state: Dictionary = {"schema_version": 25}
	game.queue_free()
	await process_frame
	assert(bool(save_helper.save_state(legacy_state).get("ok", false)), "a schema-25 save without the steam feature should be seedable")
	game = await _new_game(scene, save_root)
	assert(not bool(game.get("pressure_wreck_searched")) and not bool(game.get("pressure_galley_built")) and int(game.get("pressure_cores")) == 0, "a schema-25 save must not be upgraded with invented pressure salvage or construction")
	assert(not (game.get("learned_blueprint_ids") as Array).has("pressure_galley") and game.get_node_or_null("PressureWreck/PressureCore") != null, "an older save should retain an unsearched, reward-bearing wreck")
	game.queue_free()
	await process_frame
	save_helper.clear_for_test()
	print("ARK_PRESSURE_GALLEY_TEST_OK:")
	quit(0)
