extends SceneTree

const ArkTestPaths = preload("res://tests/ark_test_paths.gd")


func _initialize() -> void:
	_run.call_deferred()


func _count_events(game: Node, event_id: String) -> int:
	var count := 0
	for event in game.get("world_events") as Array:
		if str(event.get("id", "")) == event_id:
			count += 1
	return count


func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_reef_beast_save").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(save_root), "test saves must be isolated in this repository; Windows saves must remain on D:")
	var wound_save_root := ProjectSettings.globalize_path("res://../.local/test_reef_wound_save").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(wound_save_root), "test saves must be isolated in this repository; Windows saves must remain on D:")
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	var wound_save_helper := preload("res://scripts/ark_greybox_save.gd").new(wound_save_root)
	save_helper.clear_for_test()
	wound_save_helper.clear_for_test()
	var packed := load("res://scenes/ark_greybox.tscn") as PackedScene
	assert(packed != null, "the ark slice should load for a regional wildlife encounter")
	var game: Node = packed.instantiate()
	game.set("save_root_override", save_root)
	root.add_child(game)
	await physics_frame
	var beast := game.get_node_or_null("ReefBeast") as Node3D
	var warning := game.get_node_or_null("ReefBeastWarning") as Node3D
	assert(beast != null and beast.get_node_or_null("Name") is Label3D, "the far reef should show a volumetric, replaceable wildlife placeholder")
	assert(warning != null and str((warning.get_node("Name") as Label3D).text).contains("碎壳"), "environmental tracks should warn the player before approaching the threat")
	var destinations: Array[Dictionary] = game.call("_world_chart_destinations")
	var reef_description := ""
	for destination in destinations:
		if str(destination.get("id", "")) == "far_reef":
			reef_description = str(destination.get("description", ""))
	assert(reef_description.contains("可撤离") and reef_description.contains("不设等级门槛"), "the chart should state that the threat is avoidable and the region is ungated")

	var player := game.get("player") as CharacterBody3D
	game.set("is_swimming", false)
	player.global_position = Vector3(45.2, 0.6, -27.5)
	game.call("_process_reef_beast", 1.0 / 60.0)
	assert(float(game.get("reef_beast_charge_remaining")) > 1.0 and _count_events(game, "reef_beast_warning") == 1, "entering the territory should give a readable wind-up rather than an instant hit")
	player.global_position = Vector3(39.0, 0.6, -29.0)
	game.call("_process_reef_beast", 1.0 / 60.0)
	assert(is_zero_approx(float(game.get("reef_beast_charge_remaining"))) and not bool(game.get("reef_beast_spooked")), "leaving the territory should cancel the rush without trapping the player")
	assert(_count_events(game, "reef_beast_evaded") == 1, "an avoided rush should leave a factual record")

	player.global_position = Vector3(45.2, 0.6, -27.5)
	game.call("_process_reef_beast", 1.0 / 60.0)
	assert(int(game.get("reef_beast_health")) == 3 and int(game.get("player_health")) == 4, "the encounter should expose health for both combatants")
	game.call("_attack_reef_beast")
	assert(int(game.get("reef_beast_health")) == 2 and int(game.get("player_health")) == 4, "Q should land a close-range hit and slow the wind-up without damage trading")
	game.set("player_attack_cooldown", 0.0)
	game.call("_attack_reef_beast")
	game.set("player_attack_cooldown", 0.0)
	game.call("_attack_reef_beast")
	assert(bool(game.get("reef_beast_defeated")) and int(game.get("reef_shell_plates")) == 1, "defeating the beast should award one unique shell plate")
	assert((game.get("learned_blueprint_ids") as Array).has("reef_shell_storm_brace"), "the encounter should teach the permanent storm-brace blueprint")
	assert(not beast.visible and _count_events(game, "reef_beast_defeated") == 1, "a defeated creature should not respawn or duplicate its reward")
	game.call("_attack_reef_beast")
	assert(int(game.get("reef_shell_plates")) == 1 and _count_events(game, "reef_beast_defeated") == 1, "repeated attack input must not duplicate the unique reward")
	assert(int((game.call("_build_save_state") as Dictionary).get("schema_version", 0)) == 36, "combat health, the unique blueprint, resident work policies and resumable shared meals should use the current save schema")
	assert(bool(game.call("_save_progress")), "the defeated-creature state should save")
	game.queue_free()
	await process_frame

	var restored: Node = packed.instantiate()
	restored.set("save_root_override", save_root)
	root.add_child(restored)
	await physics_frame
	assert(bool(restored.get("reef_beast_defeated")) and int(restored.get("reef_shell_plates")) == 1, "reload should preserve the unique reward and defeated state")
	assert((restored.get("learned_blueprint_ids") as Array).has("reef_shell_storm_brace"), "the permanent blueprint should survive reload")
	assert(not (restored.get_node("ReefBeast") as Node3D).visible and _count_events(restored, "reef_beast_defeated") == 1, "loading must not respawn the beast or repeat the deed")
	var restored_player := restored.get("player") as CharacterBody3D
	restored_player.global_position = Vector3(39.0, 1.1, -29.0)
	restored.call("_interact")
	assert(bool(restored.get("keel_wreck_searched")) and int(restored.get("keel_beams")) == 1, "the player should still recover the unique wreck reward after combat")
	restored.set("shelter_built", true)
	restored.set("shelter_position", Vector3(0.0, 0.12, -0.5))
	restored.call("_build_shelter_at", Vector3(0.0, 0.12, -0.5))
	restored.set("wood", 2)
	restored.call("_install_reef_shell_brace")
	assert(bool(restored.get("reef_shell_brace_installed")) and int(restored.get("reef_shell_plates")) == 0 and int(restored.get("wood")) == 0, "the blueprint should install on the real shelter for its exact cost")
	assert(restored.get_node_or_null("ArkRoot/BuiltShelter/ReefShellStormBrace") != null, "the upgrade should have a visible, replaceable shelter model")
	restored.set("rope_use", "none")
	restored.set("shelter_roof_damaged", false)
	restored.call("_apply_storm_damage")
	assert(not bool(restored.get("shelter_roof_damaged")), "the installed shell brace should protect the shelter roof during later storms")
	assert(bool(restored.call("_save_progress")), "the installed home upgrade should save")
	restored.queue_free()
	await process_frame

	restored = packed.instantiate()
	restored.set("save_root_override", save_root)
	root.add_child(restored)
	await physics_frame
	assert(bool(restored.get("reef_shell_brace_installed")) and restored.get_node_or_null("ArkRoot/BuiltShelter/ReefShellStormBrace") != null, "reload should rebuild the visible shelter protection")
	var schema_29_state: Dictionary = restored.call("_build_save_state")
	schema_29_state["schema_version"] = 29
	schema_29_state.erase("player_health")
	schema_29_state.erase("reef_beast_defeated")
	schema_29_state.erase("reef_beast_health")
	schema_29_state.erase("reef_shell_plates")
	schema_29_state.erase("reef_shell_brace_installed")
	schema_29_state["reef_beast_spooked"] = true
	var old_blueprints: Array = schema_29_state.get("learned_blueprint_ids", []).duplicate()
	old_blueprints.erase("reef_shell_storm_brace")
	schema_29_state["learned_blueprint_ids"] = old_blueprints
	var old_events: Array = []
	for event in schema_29_state.get("world_events", []) as Array:
		if str(event.get("id", "")) not in ["reef_beast_hit", "reef_beast_defeated", "reef_shell_brace_installed"] and not (str(event.get("id", "")) == "blueprint_discovered" and str(event.get("facts", {}).get("blueprint_id", "")) == "reef_shell_storm_brace"):
			old_events.append(event)
	schema_29_state["world_events"] = old_events
	assert(bool(save_helper.save_state(schema_29_state).get("ok", false)), "a legacy schema-29 fixture must be writable")
	restored.set("save_service", null)
	restored.queue_free()
	await process_frame
	var legacy: Node = packed.instantiate()
	legacy.set("save_root_override", save_root)
	root.add_child(legacy)
	await physics_frame
	assert(bool(legacy.get("reef_beast_spooked")) and not bool(legacy.get("reef_beast_defeated")), "old retreat records should retain their old meaning without becoming combat victories")
	assert(int(legacy.get("reef_shell_plates")) == 0 and not (legacy.get("learned_blueprint_ids") as Array).has("reef_shell_storm_brace"), "schema-29 saves must not invent combat rewards or blueprints")
	assert(int(legacy.get("player_health")) == 4 and not bool(legacy.get("reef_shell_brace_installed")), "old saves should migrate to full health without receiving an unearned upgrade")
	legacy.queue_free()
	await process_frame
	save_helper.clear_for_test()

	var wound_game: Node = packed.instantiate()
	wound_game.set("save_root_override", wound_save_root)
	root.add_child(wound_game)
	await physics_frame
	var wound_player := wound_game.get("player") as CharacterBody3D
	wound_player.global_position = Vector3(45.2, 0.6, -27.5)
	wound_game.set("player_health", 1)
	wound_game.call("_process_reef_beast", 1.0 / 60.0)
	wound_game.set("reef_beast_charge_remaining", 0.01)
	wound_game.call("_process_reef_beast", 0.1)
	assert(int(wound_game.get("player_health")) == 1 and wound_player.global_position.distance_to((wound_game.get("ark_root") as Node3D).to_global(Vector3(0.0, 1.1, 1.55))) < 0.05, "a lethal hit should recall the player to their own ark at 1 health instead of ending the run")
	assert(_count_events(wound_game, "player_knocked_out") == 1 and int(wound_game.get("wood")) == 1, "knockout should be recorded without deleting carried resources")
	wound_game.set("shelter_built", true)
	wound_game.call("_build_shelter_at", Vector3(0.0, 0.12, -0.5))
	wound_game.set("player_health", 1)
	wound_game.call("_rest_at_cot")
	assert(int(wound_game.get("player_health")) == 4 and _count_events(wound_game, "player_health_recovered") == 1, "sleeping in the shelter should restore health and record the recovery")
	wound_game.set("resident_met", true)
	wound_game.set("traveler_boarded", true)
	wound_game.call("_set_traveler_boarded")
	var meal_player := wound_game.get("player") as CharacterBody3D
	var meal_ark := wound_game.get("ark_root") as Node3D
	meal_player.global_position = meal_ark.to_global(Vector3(0.0, 0.31, 0.0))
	var meal_resident := wound_game.get("traveler_marker") as Node3D
	meal_resident.position = meal_ark.to_local(meal_player.global_position)
	wound_game.set("player_health", 2)
	wound_game.set("stew_servings", 1)
	wound_game.set("shared_meal_day", int(wound_game.get("day_count")) - 1)
	assert(bool(wound_game.call("_player_at_shared_table")), "healing meal requires deck-level presence")
	wound_game.call("_interact")
	assert(int(wound_game.get("player_health")) == 3 and int(wound_game.get("stew_servings")) == 0, "a real shared meal should consume one prepared serving and heal a wounded player")
	assert(_count_events(wound_game, "resident_meal_shared") == 1 and _count_events(wound_game, "player_health_recovered") == 2, "the meal should record one shared event and a separate factual recovery")
	wound_game.call("_interact")
	assert(int(wound_game.get("player_health")) == 3 and _count_events(wound_game, "resident_meal_shared") == 1, "the same resident cannot provide a second shared meal on the same day")
	assert(bool(wound_game.call("_save_progress")), "health recovery should persist")
	wound_game.queue_free()
	await process_frame
	var wound_restored: Node = packed.instantiate()
	wound_restored.set("save_root_override", wound_save_root)
	root.add_child(wound_restored)
	await physics_frame
	assert(int(wound_restored.get("player_health")) == 3 and _count_events(wound_restored, "player_knocked_out") == 1, "reloading should retain the meal recovery, remaining health and the single knockout record")
	assert(_count_events(wound_restored, "resident_meal_shared") == 1 and _count_events(wound_restored, "player_health_recovered") == 2, "reloading must not repeat the shared-meal recovery or its event")
	wound_restored.queue_free()
	await process_frame
	wound_save_helper.clear_for_test()
	print("ARK_REEF_BEAST_TEST_OK:")
	quit()
