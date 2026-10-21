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


func _new_game(scene: PackedScene, save_root: String) -> Node:
	var game := scene.instantiate()
	game.set("save_root_override", save_root)
	root.add_child(game)
	await physics_frame
	return game


func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_exposure_save").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(save_root), "test saves must be isolated in this repository; Windows saves must remain on D:")
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	save_helper.clear_for_test()
	var scene := load("res://scenes/ark_greybox.tscn") as PackedScene
	assert(scene != null, "the mobile-home survival scene must load")
	var game := await _new_game(scene, save_root)
	var player := game.get("player") as CharacterBody3D

	# Staying outside through both storm beats causes a readable two-step risk, never a movement lock.
	player.global_position = Vector3(21.0, 1.1, 0.0)
	game.call("_refresh_refuge_state")
	game.call("_advance_weather")
	assert(int(game.get("cold_exposure_level")) == 1 and bool(game.get("cold_exposure")), "storm arrival outside the moving refuge should add the first exposure level")
	game.call("_advance_weather")
	assert(int(game.get("cold_exposure_level")) == 2, "remaining outside until the storm passes should deepen the exposure")
	assert(float(game.call("_current_walk_speed")) > 0.0 and float(game.call("_current_walk_speed")) < float(game.get("WALK_SPEED")), "severe exposure should slow but never immobilize the player")
	assert(_count_events(game, "storm_exposure") == 2, "storm arrival and persistence should be separately grounded in the event ledger")
	assert(bool(game.call("_save_progress")), "the stepped exposure state should save")
	game.queue_free()
	await process_frame
	game = await _new_game(scene, save_root)
	assert(int(game.get("cold_exposure_level")) == 2, "the current exposure intensity should survive a save/reload")

	# A schema-19 save has only a boolean; migrate it to the first intensity level.
	var legacy_state: Dictionary = game.call("_build_save_state")
	legacy_state["schema_version"] = 19
	legacy_state.erase("cold_exposure_level")
	legacy_state["cold_exposure"] = true
	game.queue_free()
	await process_frame
	assert(bool(save_helper.save_state(legacy_state).get("ok", false)), "a legacy boolean exposure save should be seedable")
	game = await _new_game(scene, save_root)
	assert(int(game.get("cold_exposure_level")) == 1 and bool(game.get("cold_exposure")), "old boolean exposure should migrate conservatively to light chill")

	# Returning to the ark fully restores warmth; unique distant salvage then stacks up to three levels.
	player = game.get("player") as CharacterBody3D
	player.global_position = Vector3(7.0, 1.1, 0.0)
	game.call("_refresh_refuge_state")
	assert(int(game.get("cold_exposure_level")) == 0 and not bool(game.get("cold_exposure")), "the moving ark should clear every accumulated exposure level")
	player.global_position = Vector3(23.0, 1.1, -17.0)
	game.call("_interact")
	assert(int(game.get("cold_exposure_level")) == 1, "the exposed shore ruin should add one level")
	player.global_position = Vector3(39.0, 1.1, -29.0)
	game.call("_interact")
	assert(int(game.get("cold_exposure_level")) == 2, "the far-reef wreck should deepen an existing expedition chill")
	player.global_position = Vector3(-28.0, 1.1, 23.0)
	game.call("_interact")
	assert(int(game.get("cold_exposure_level")) == 3, "the moonback station should be survivable but make a long expedition feel costly")
	assert(((game.get("hud") as Label).text).contains("彻骨 3/3"), "the HUD should name the severity and show its bounded level")
	var worsened_before_cap := _count_events(game, "cold_exposure_worsened")
	game.call("_raise_cold_exposure", "test_cap")
	assert(int(game.get("cold_exposure_level")) == 3 and _count_events(game, "cold_exposure_worsened") == worsened_before_cap, "exposure should cap at three without event spam")
	assert(bool(game.call("_save_progress")), "the expedition exposure and source events should save")
	game.queue_free()
	await process_frame
	game = await _new_game(scene, save_root)
	assert(int(game.get("cold_exposure_level")) == 3 and bool(game.get("cold_exposure")), "maximum exposure should persist after reloading at the remote station")
	var salvaged_events := game.get("world_events") as Array
	var tide_event: Dictionary = {}
	for event in salvaged_events:
		if str(event.get("id", "")) == "tide_station_salvaged":
			tide_event = event
	assert(int((tide_event.get("facts", {}) as Dictionary).get("cold_exposure_level", 0)) == 3, "the unique station reward should record the exposure severity at acquisition")
	var relieved_level: int = game.call("_relieve_cold_exposure", "shared_hot_meal", 1)
	assert(relieved_level == 2 and bool(game.get("cold_exposure")), "a shared hot meal should relieve one level without pretending to cure a severe expedition chill")
	player = game.get("player") as CharacterBody3D
	player.global_position = Vector3(7.0, 1.1, 0.0)
	game.call("_refresh_refuge_state")
	assert(int(game.get("cold_exposure_level")) == 0 and not bool(game.get("cold_exposure")), "returning to the mobile ark should fully recover even maximum exposure")
	assert(_count_events(game, "cold_exposure_relieved") >= 2 and _count_events(game, "ark_refuge_warmed") >= 1, "warm food and refuge recovery should leave separate causal facts")
	assert(bool(game.call("_save_progress")), "the recovered home state should save")
	game.queue_free()
	await process_frame
	game = await _new_game(scene, save_root)
	assert(int(game.get("cold_exposure_level")) == 0 and not bool(game.get("cold_exposure")), "a recovered state should remain warm after reloading")
	game.queue_free()
	await process_frame
	save_helper.clear_for_test()
	print("ARK_EXPOSURE_TEST_OK:")
	quit()
