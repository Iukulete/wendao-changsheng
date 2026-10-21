extends SceneTree

const ArkTestPaths = preload("res://tests/ark_test_paths.gd")


func _initialize() -> void:
	_run.call_deferred()


func _has_event(game: Node, event_id: String) -> bool:
	for event in game.get("world_events") as Array:
		if str(event.get("id", "")) == event_id:
			return true
	return false


func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_refuge_save").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(save_root), "test saves must be isolated in this repository; Windows saves must remain on D:")
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	save_helper.clear_for_test()
	var packed := load("res://scenes/ark_greybox.tscn") as PackedScene
	assert(packed != null, "the ark scene must load")
	var game: Node = packed.instantiate()
	game.set("save_root_override", save_root)
	root.add_child(game)
	await physics_frame
	var ark_root: Node3D = game.get_node("ArkRoot") as Node3D
	var player: CharacterBody3D = game.get("player") as CharacterBody3D
	assert(bool(game.call("_is_within_ark_refuge")), "the player should begin inside the mobile ark's refuge radius")
	assert(((game.get("hud") as Label).text).contains("仙舟庇护圈 8m"), "the HUD should make the base refuge radius legible")

	player.position = Vector3(21.0, 1.1, 0.0)
	game.call("_refresh_refuge_state")
	assert(not bool(game.call("_is_within_ark_refuge")) and _has_event(game, "ark_refuge_left"), "leaving refuge should be visible in-world state, not a level gate")
	game.set("weather_phase", 1)
	game.call("_advance_weather")
	assert(bool(game.get("cold_exposure")), "storm resolution outside the mobile home's refuge should create readable exposure")
	assert(_has_event(game, "storm_exposure"), "storm exposure should be recorded for reliable saves and narrative review")
	var exposure_sequence := int(game.get("event_sequence"))
	assert(bool(game.call("_save_progress")), "the exposed state and event history should save")
	game.queue_free()
	await process_frame
	var restored_game: Node = packed.instantiate()
	restored_game.set("save_root_override", save_root)
	root.add_child(restored_game)
	await physics_frame
	game = restored_game
	ark_root = game.get_node("ArkRoot") as Node3D
	player = game.get("player") as CharacterBody3D
	assert(bool(game.get("cold_exposure")) and int(game.get("event_sequence")) == exposure_sequence and _has_event(game, "storm_exposure"), "exposure and its causal event should survive a save/reload")

	player.position = Vector3(7.0, 1.1, 0.0)
	game.call("_refresh_refuge_state")
	assert(bool(game.call("_is_within_ark_refuge")) and not bool(game.get("cold_exposure")), "returning aboard the ark should recover exposure without requiring a tuned upgrade")
	assert(_has_event(game, "ark_refuge_entered"), "returning home should create a visible world event")

	player.position = Vector3(14.0, 1.1, 0.0)
	game.call("_refresh_refuge_state")
	assert(not bool(game.call("_is_within_ark_refuge")), "the untuned ark should leave nearby but exposed waters as a meaningful risk")
	game.set("workbench_built", true)
	game.set("workbench_position", Vector3(-2.0, 0.12, 1.5))
	game.call("_build_workbench_at", Vector3(-2.0, 0.12, 1.5))
	game.set("ancient_parts", 1)
	player.position = Vector3(-2.0, 0.62, 1.5)
	game.call("_interact")
	assert(bool(game.get("lantern_tuned")) and int(game.get("ancient_parts")) == 0, "the workbench must consume the unique relic to tune the moving home's lamp")
	var tuned_event: Dictionary = (game.get("world_events") as Array).back()
	var tuned_facts: Dictionary = tuned_event.get("facts", {})
	assert(str(tuned_event.get("id", "")) == "lantern_tuned" and float(tuned_facts.get("home_refuge_radius", 0.0)) == 15.0, "the upgrade event must record the actual refuge radius")
	assert(((game.get("hud") as Label).text).contains("仙舟庇护圈 15m"), "the refuge expansion should be visible in the HUD")
	game.call("_refresh_refuge_state")
	player.position = Vector3(14.0, 1.1, 0.0)
	game.call("_refresh_refuge_state")
	assert(bool(game.call("_is_within_ark_refuge")), "the tuned spirit lantern should visibly expand the moving refuge radius")

	game.set("weather_phase", 1)
	game.set("cold_exposure", false)
	game.set("cold_exposure_level", 0)
	game.call("_advance_weather")
	assert(not bool(game.get("cold_exposure")), "the mobile home's refuge should protect nearby exploration during the storm")
	var events: Array = game.get("world_events")
	var resolution: Dictionary = events.back()
	assert(str(resolution.get("id", "")) == "storm_resolved" and not bool((resolution.get("facts", {}) as Dictionary).get("player_exposed", true)), "storm history should distinguish protected and exposed outcomes")

	assert(bool(game.call("_save_progress")), "refuge event history should save")
	game.queue_free()
	await process_frame
	save_helper.clear_for_test()
	print("ARK_REFUGE_TEST_OK:")
	quit()
