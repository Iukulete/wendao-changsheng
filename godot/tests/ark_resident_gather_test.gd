extends SceneTree


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
	game.set_process(false)
	game.set_physics_process(false)
	game.set("save_root_override", save_root)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await physics_frame
	return game


func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_resident_gather_save").simplify_path()
	assert(save_root.to_lower().begins_with("d:"), "resident gathering regression saves must remain on D:")
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	save_helper.clear_for_test()
	var scene := load("res://scenes/ark_greybox.tscn") as PackedScene
	assert(scene != null, "the ark scene must load for resident gathering")
	var game := await _new_game(scene, save_root)
	var rock_detour: PackedVector3Array = game.call("_build_resident_walk_route", Vector3(2.0, 0.12, -7.0), Vector3(8.0, 0.12, -7.0))
	assert(rock_detour.size() > 2, "the resident route planner should create intermediate waypoints around a blocking shore rock")
	var moved_around_rock := false
	for waypoint in rock_detour:
		assert(not (waypoint.x > 4.0 and waypoint.x < 6.0 and waypoint.z > -8.1 and waypoint.z < -5.9), "the resident path must not pass through the solid shore-rock footprint")
		if waypoint.distance_to(Vector3(2.0, 0.12, -7.0)) > 0.1 and waypoint.distance_to(Vector3(8.0, 0.12, -7.0)) > 0.1:
			moved_around_rock = moved_around_rock or waypoint.x < 3.5 or waypoint.x > 6.5 or waypoint.z < -8.5 or waypoint.z > -5.5
	assert(moved_around_rock, "a blocked straight-line trip should bend around the shore instead of walking through the rock")
	var deck_blocker := StaticBody3D.new()
	deck_blocker.name = "RoutinePathBlockerTest"
	var deck_blocker_shape := CollisionShape3D.new()
	var deck_blocker_box := BoxShape3D.new()
	deck_blocker_box.size = Vector3(0.75, 1.6, 0.75)
	deck_blocker_shape.shape = deck_blocker_box
	deck_blocker_shape.position.y = 0.8
	deck_blocker.add_child(deck_blocker_shape)
	(game.get_node("ArkRoot") as Node3D).add_child(deck_blocker)
	await physics_frame
	var deck_detour: PackedVector3Array = game.call("_build_ark_local_walk_route", Vector3(-1.0, 0.12, 0.0), Vector3(1.0, 0.12, 0.0))
	assert(deck_detour.size() > 2, "an onboard daily routine should receive a local detour around a collidable fixture")
	var walked_around_fixture := false
	for waypoint in deck_detour:
		if absf(waypoint.x) < 0.5:
			assert(absf(waypoint.z) > 0.45, "a crew route must not cross the footprint of a deck fixture")
			walked_around_fixture = true
	assert(walked_around_fixture, "a blocked shipboard route should bend around the fixture rather than walk through it")
	deck_blocker.queue_free()
	await physics_frame
	var shoreline_route: PackedVector3Array = game.call("_build_resident_walk_route", Vector3(18.0, 0.12, -14.0), Vector3(24.0, 0.12, -14.0))
	assert(shoreline_route.size() > 2, "a resident route crossing the island's sloped shoreline should include sampled ground waypoints")
	var follows_shore_slope := false
	for waypoint in shoreline_route:
		follows_shore_slope = follows_shore_slope or waypoint.y < -0.02
	assert(follows_shore_slope, "a resident should descend with the real shoreline instead of hovering at the route's starting height")
	game.set("traveler_boarded", true)
	game.call("_set_traveler_boarded")
	var slope_marker := game.get("traveler_marker") as Node3D
	slope_marker.global_position = Vector3(18.0, 0.12, -14.0)
	game.set("resident_gather_pending", true)
	game.set("resident_gather_phase", "outbound")
	game.set("resident_gather_target_position", Vector3(24.0, 0.12, -14.0))
	var lowest_resident_y := slope_marker.global_position.y
	for _step in range(400):
		game.call("_process_resident_gathering", 0.1)
		lowest_resident_y = minf(lowest_resident_y, slope_marker.global_position.y)
		if str(game.get("resident_gather_phase")) == "collecting":
			break
	assert(lowest_resident_y < 0.0 and str(game.get("resident_gather_phase")) == "collecting", "the resident should physically descend across the shore slope and reach the actual collection point")
	game.set("resident_gather_pending", false)
	game.set("resident_gather_phase", "")
	game.set("shelter_built", true)
	game.set("traveler_boarded", true)
	game.set("sailmaker_boarded", true)
	assert(int(game.call("_resident_capacity")) == 2 and int(game.call("_resident_occupancy")) == 2, "the first habitable ark should have finite resident berths")
	assert(not bool(game.call("_can_board_resident", "future_resident")), "the ark should refuse residents beyond its physical berth capacity")
	game.set("raft_extension_built", true)
	assert(int(game.call("_resident_capacity")) == 3 and bool(game.call("_can_board_resident", "future_resident")), "a real ark expansion should add one resident berth")
	game.set("raft_extension_built", false)
	game.set("sailmaker_boarded", false)
	game.set("weather_phase", 2)
	game.set("day_count", 1)
	game.set("day_period", 3)
	game.call("_set_traveler_boarded")
	var ark := game.get_node("ArkRoot") as Node3D
	var marker := game.get("traveler_marker") as Node3D
	assert(marker.get_parent() == ark, "the resident should begin the day aboard the moving home")
	assert((game.get("interactables") as Array).any(func(entry: Dictionary) -> bool: return str(entry.get("item_id", "")) == "DriftwoodNear"), "the starter shore should contain real finite driftwood for a worker to find")

	var advancement: Dictionary = game.call("_advance_world_period", "resident_gather_test")
	assert(bool(advancement.get("resident_gather_started", false)) and bool(game.get("resident_gather_pending")), "the resident should automatically start a nearby gathering shift at dawn")
	assert(str(game.get("resident_gather_target_id")) == "DriftwoodNear" and str(game.get("resident_gather_resource")) == "wood", "the resident should choose the nearest existing resource rather than inventing a drop")
	assert(marker.get_parent() == game, "the resident should physically leave the ark to gather")
	var start_position := marker.global_position
	game.call("_process", 0.5)
	assert(marker.global_position.distance_to(start_position) > 0.1, "the resident should visibly move toward the real collection point")
	var saved_world_position := marker.global_position
	assert(bool(game.call("_save_progress")), "an in-flight resident trip should save")
	var persisted_result: Dictionary = save_helper.load_state()
	assert(bool(persisted_result.get("ok", false)), "the in-flight resident save should be readable before unloading")
	var persisted_state: Dictionary = persisted_result.get("state", {})
	var persisted_position_data: Dictionary = persisted_state.get("traveler_position", {})
	var persisted_world_position := Vector3(float(persisted_position_data.get("x", 0.0)), float(persisted_position_data.get("y", 0.0)), float(persisted_position_data.get("z", 0.0)))
	assert(persisted_world_position.distance_to(saved_world_position) < 0.02, "the save should serialize the resident's actual world-space position")
	game.queue_free()
	await process_frame
	game = await _new_game(scene, save_root)
	marker = game.get("traveler_marker") as Node3D
	assert(bool(game.get("resident_gather_pending")) and str(game.get("resident_gather_phase")) == "outbound", "an in-flight gathering task should resume after loading")
	assert(marker.get_parent() == game and marker.global_position.distance_to(persisted_world_position) < 0.02, "the resident should resume at the persisted world-space position")
	assert((game.get("resident_gather_route") as PackedVector3Array).is_empty(), "navigation waypoints should be recalculated from the saved resident position rather than saved as stale world geometry")

	for _step in range(160):
		if not bool(game.get("resident_gather_pending")):
			break
		game.call("_process", 0.1)
		await physics_frame
	assert(not bool(game.get("resident_gather_pending")) and marker.get_parent() == game.get_node("ArkRoot"), "the worker should return aboard after collecting")
	assert((game.get("collected_ids") as Array).has("DriftwoodNear") and int(game.get("wood")) == 3 and int(game.get("stored_wood")) == 0, "without a built storage crate, collected wood should join the usable supply instead of becoming inaccessible cargo")
	assert(_count_events(game, "resident_gather_started") == 1 and _count_events(game, "resident_gather_harvested") == 1 and _count_events(game, "resident_gather_delivered") == 1, "the automatic trip should record start, pickup, and delivery exactly once")
	var pickup_event: Dictionary = {}
	for event in game.get("world_events") as Array:
		if str(event.get("id", "")) == "resource_collected" and str((event.get("facts", {}) as Dictionary).get("collector", "")) == "resident":
			pickup_event = event
	assert(str((pickup_event.get("facts", {}) as Dictionary).get("node_id", "")) == "DriftwoodNear", "the collection ledger should identify the resident and exact source")
	assert(bool(game.call("_save_progress")), "delivered cargo should save")
	game.queue_free()
	await process_frame
	game = await _new_game(scene, save_root)
	marker = game.get("traveler_marker") as Node3D
	assert(int(game.get("wood")) == 3 and int(game.get("stored_wood")) == 0 and not bool(game.get("resident_gather_pending")), "loading a completed trip must preserve its usable delivery without duplicating resources")

	for _period in range(4):
		game.call("_advance_world_period", "resident_gather_race_test")
	assert(bool(game.get("resident_gather_pending")) and str(game.get("resident_gather_target_id")) == "DriftwoodShore", "the worker should autonomously use the next real nearby pile on a later day")
	var shore_pile: Node3D = null
	for entry in game.get("interactables") as Array:
		if str(entry.get("item_id", "")) == "DriftwoodShore":
			shore_pile = entry.get("node") as Node3D
	assert(shore_pile != null, "the second wood source should still exist before either collector reaches it")
	(game.get("player") as CharacterBody3D).global_position = shore_pile.global_position + Vector3(0.0, 1.0, 0.0)
	game.call("_interact")
	assert((game.get("collected_ids") as Array).has("DriftwoodShore"), "the player should remain able to take a source before the worker arrives")
	for _step in range(160):
		if not bool(game.get("resident_gather_pending")):
			break
		game.call("_process", 0.1)
		await physics_frame
	assert(not bool(game.get("resident_gather_pending")) and int(game.get("wood")) == 5 and int(game.get("stored_wood")) == 0, "a resident must not duplicate a resource collected by the player in a race")
	assert(_count_events(game, "resident_gather_cancelled") == 1, "a vanished source should cancel the work trip with an auditable reason")
	for _period in range(4):
		game.call("_advance_world_period", "resident_gather_departure_test")
	assert(bool(game.get("resident_gather_pending")) and str(game.get("resident_gather_target_id")) == "TidalShellsNear", "the worker should fall back to the next real local resource after nearby wood is depleted")
	game.call("_toggle_sailing")
	assert(bool(game.get("sailing_mode")) and not bool(game.get("resident_gather_pending")), "the player must be free to sail without waiting for a resident work trip")
	assert((game.get("interactables") as Array).any(func(entry: Dictionary) -> bool: return str(entry.get("item_id", "")) == "TidalShellsNear"), "recalling before collection must leave the world resource available")
	assert(int(game.get("wood")) == 5 and int(game.get("stored_wood")) == 0 and int(game.get("raw_shellfish")) == 0 and marker.get_parent() == game.get_node("ArkRoot"), "recall should preserve usable supplies, avoid phantom collection, and bring the resident aboard")
	game.queue_free()
	await process_frame
	save_helper.clear_for_test()
	await _run_policy_checks(scene)
	await _run_shared_table_meal_checks(scene)
	await _run_tidekeeper_box_checks(scene)
	await _run_storage_free_delivery_checks(scene)
	print("ARK_RESIDENT_GATHER_TEST_OK:")
	quit()


func _run_storage_free_delivery_checks(scene: PackedScene) -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_resident_delivery_storage_save").simplify_path()
	assert(save_root.to_lower().begins_with("d:"), "resident delivery regression saves must remain on D:")
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	save_helper.clear_for_test()
	var game := await _new_game(scene, save_root)
	game.set("storage_built", false)
	game.set("wood", 1)
	game.set("resident_gather_pending", true)
	game.set("resident_gather_resource", "wood")
	game.set("resident_gather_target_id", "TestDriftwood")
	game.set("resident_gather_payload", 2)
	game.call("_finish_resident_gathering", "returned")
	assert(int(game.get("wood")) == 3 and int(game.get("stored_wood")) == 0, "a resident should deliver wood into the usable shared supply when no storage crate exists")
	assert(bool(game.call("_try_place_shelter", Vector3.ZERO)) and bool(game.get("shelter_built")) and int(game.get("wood")) == 0, "the no-storage delivery should be immediately spendable on the first shelter")
	var delivered_facts: Dictionary = {}
	for event in game.get("world_events") as Array:
		if str(event.get("id", "")) == "resident_gather_delivered":
			delivered_facts = event.get("facts", {})
	assert(str(delivered_facts.get("destination", "")) == "available_supplies", "the event ledger should identify the no-storage delivery destination")
	game.queue_free()
	await process_frame
	game = await _new_game(scene, save_root)
	game.set("storage_built", true)
	game.set("wood", 1)
	game.set("resident_gather_pending", true)
	game.set("resident_gather_resource", "wood")
	game.set("resident_gather_target_id", "TestStoredDriftwood")
	game.set("resident_gather_payload", 2)
	game.call("_finish_resident_gathering", "returned")
	assert(int(game.get("wood")) == 1 and int(game.get("stored_wood")) == 2, "when a storage crate exists, resident wood should remain reserved in ark storage")
	delivered_facts = {}
	for event in game.get("world_events") as Array:
		if str(event.get("id", "")) == "resident_gather_delivered":
			delivered_facts = event.get("facts", {})
	assert(str(delivered_facts.get("destination", "")) == "ark_storage", "the event ledger should identify the built storage destination")
	game.queue_free()
	await process_frame
	save_helper.clear_for_test()


func _run_policy_checks(scene: PackedScene) -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_resident_policy_save").simplify_path()
	assert(save_root.to_lower().begins_with("d:"), "resident work policy saves must remain on D:")
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	save_helper.clear_for_test()
	var game := await _new_game(scene, save_root)
	game.set("shelter_built", true)
	game.set("resident_met", true)
	game.set("traveler_boarded", true)
	game.set("weather_phase", 2)
	game.set("day_period", 0)
	game.call("_set_traveler_boarded")
	game.set("resident_repair_pending", true)
	assert(not bool(game.call("_begin_resident_daily_gather")) and int(game.get("resident_gather_last_day")) == 0, "a resident already repairing the ark must not abandon that job for an automatic shift")
	game.set("resident_repair_pending", false)
	var marker := game.get("traveler_marker") as Node3D
	(game.get("player") as CharacterBody3D).global_position = marker.global_position + Vector3(0.0, 1.0, 0.0)
	game.call("_interact")
	assert(bool(game.get("resident_gather_policy_choice_pending")), "an idle boarded resident should offer a persistent work preference in conversation")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_2
	game.call("_unhandled_key_input", key)
	assert(str(game.get("resident_gather_policy")) == "shellfish_first" and not bool(game.get("resident_gather_policy_choice_pending")), "the actual choice key should set the food preference and close the prompt")
	assert((game.get("hud") as Label).text.contains("鲜贝优先") and _count_events(game, "resident_gather_policy_set") == 1, "the work preference should be visible and recorded once")
	assert(bool(game.call("_begin_resident_daily_gather")) and str(game.get("resident_gather_resource")) == "shellfish", "food priority should select an existing shellfish source while real driftwood is also available")
	var current_target := str(game.get("resident_gather_target_id"))
	game.set("resident_gather_policy_choice_pending", true)
	key.keycode = KEY_1
	game.call("_unhandled_key_input", key)
	assert(str(game.get("resident_gather_policy")) == "wood_first" and str(game.get("resident_gather_target_id")) == current_target, "a policy change should apply to the next shift without replacing a current resource reservation")
	assert(bool(game.call("_save_progress")), "a changed preference and in-flight task should save together")
	game.queue_free()
	await process_frame
	game = await _new_game(scene, save_root)
	assert(str(game.get("resident_gather_policy")) == "wood_first" and str(game.get("resident_gather_target_id")) == current_target, "reload should preserve the future preference and the original active trip")
	game.call("_recall_resident_gatherer", "policy_regression")
	assert(not bool(game.call("_begin_resident_daily_gather")), "changing a preference must not bypass the one-shift-per-day limit")
	game.set("day_count", 2)
	assert(bool(game.call("_begin_resident_daily_gather")) and str(game.get("resident_gather_resource")) == "wood", "the following dawn should honor the persisted wood preference")
	game.call("_recall_resident_gatherer", "legacy_fixture")
	var legacy_state: Dictionary = game.call("_build_save_state")
	legacy_state["schema_version"] = 30
	legacy_state["resident_gather_policy"] = "shellfish_first"
	var previous_events := _count_events(game, "resident_gather_policy_set")
	assert(bool(save_helper.save_state(legacy_state).get("ok", false)), "a schema-30 compatibility fixture should save")
	game.set("save_service", null)
	game.queue_free()
	await process_frame
	game = await _new_game(scene, save_root)
	assert(str(game.get("resident_gather_policy")) == "wood_first", "schema-30 saves should retain the legacy wood-first behavior rather than adopting a new-schema field")
	assert(_count_events(game, "resident_gather_policy_set") == previous_events, "migration should not invent a policy choice event")
	game.set("resident_gather_policy_choice_pending", true)
	key.keycode = KEY_ESCAPE
	game.call("_unhandled_key_input", key)
	assert(not bool(game.get("resident_gather_policy_choice_pending")) and str(game.get("resident_gather_policy")) == "wood_first", "Escape should preserve the current work policy")
	game.queue_free()
	await process_frame
	save_helper.clear_for_test()


func _run_shared_table_meal_checks(scene: PackedScene) -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_shared_table_meal_save").simplify_path()
	assert(save_root.to_lower().begins_with("d:"), "shared-table meal regression saves must remain on D:")
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	save_helper.clear_for_test()
	var game := await _new_game(scene, save_root)
	game.set("wood", 3)
	assert(bool(game.call("_try_place_shelter", Vector3.ZERO)), "a shared-table meal requires the real starter shelter")
	game.set("resident_met", true)
	game.set("traveler_boarded", true)
	game.set("sailmaker_met", true)
	game.set("sailmaker_boarded", true)
	game.set("weather_phase", 2)
	game.set("day_count", 2)
	game.set("day_period", 2)
	game.set("stew_servings", 1)
	game.set("shared_meal_day", 1)
	game.set("player_health", 2)
	game.call("_set_traveler_boarded")
	game.call("_set_sailmaker_boarded")
	var player := game.get("player") as CharacterBody3D
	var tidekeeper := game.get("traveler_marker") as Node3D
	var sailmaker := game.get("sailmaker_marker") as Node3D
	player.global_position = tidekeeper.global_position
	game.call("_interact")
	assert(bool(game.get("shared_meal_gathering_pending")) and int(game.get("stew_servings")) == 0, "serving soup to both residents should reserve exactly one meal while they walk to the firelight")
	assert(int(game.get("shared_meal_count")) == 0 and _count_events(game, "resident_meal_shared") == 0, "the meal should not be recorded as shared until both residents physically arrive")
	assert((game.get("shared_meal_participants") as Array).has("sailmaker"), "the companion who accepted a berth should be part of the actual shared meal")
	var tidekeeper_before := tidekeeper.position
	var sailmaker_before := sailmaker.position
	game.call("_process", 0.5)
	assert(tidekeeper.position.distance_to(tidekeeper_before) > 0.05 and sailmaker.position.distance_to(sailmaker_before) > 0.05, "both residents should visibly leave their separate routines and approach the shared table")
	var saved_tidekeeper := tidekeeper.position
	var saved_sailmaker := sailmaker.position
	assert(bool(game.call("_save_progress")), "an in-progress household meal should save its reserved serving and both resident positions")
	game.queue_free()
	await process_frame
	game = await _new_game(scene, save_root)
	tidekeeper = game.get("traveler_marker") as Node3D
	sailmaker = game.get("sailmaker_marker") as Node3D
	assert(bool(game.get("shared_meal_gathering_pending")) and int(game.get("stew_servings")) == 0, "loading should resume the real in-progress meal without restoring or re-spending its serving")
	assert(tidekeeper.position.distance_to(saved_tidekeeper) < 0.05 and sailmaker.position.distance_to(saved_sailmaker) < 0.05, "both residents should resume near their saved positions instead of snapping to the table")
	for _step in range(240):
		if not bool(game.get("shared_meal_gathering_pending")):
			break
		game.call("_process", 0.1)
		await physics_frame
	assert(not bool(game.get("shared_meal_gathering_pending")) and int(game.get("shared_meal_count")) == 1, "the shared meal should complete once both residents reach the firelight")
	assert(int(game.get("player_health")) == 3 and int(game.get("stew_servings")) == 0, "the shared serving should restore the player's meal benefit exactly once")
	var meal_event: Dictionary = {}
	for event in game.get("world_events") as Array:
		if str(event.get("id", "")) == "resident_meal_shared":
			meal_event = event
	var meal_facts: Dictionary = meal_event.get("facts", {})
	assert((meal_facts.get("participant_ids", []) as Array) == ["player", "tidekeeper", "sailmaker"] and bool(meal_facts.get("shared_table", false)), "the factual meal event should identify everyone who actually sat together")
	assert(_count_events(game, "resident_meal_gathering_started") == 1 and _count_events(game, "resident_meal_shared") == 1 and _count_events(game, "resident_keepsake_placed") == 1, "arrival should finalize exactly one meal and one physical keepsake after a single start event")
	assert(str(game.get("message")).contains("给我留了一只碗"), "the sailmaker should respond to her first truthful invitation to the shared table")
	var completed_state: Dictionary = game.call("_build_save_state")
	game.queue_free()
	await process_frame
	assert(bool(save_helper.save_state(completed_state).get("ok", false)), "the completed shared-table state should save")
	game = await _new_game(scene, save_root)
	assert(not bool(game.get("shared_meal_gathering_pending")) and int(game.get("shared_meal_count")) == 1 and _count_events(game, "resident_meal_shared") == 1, "reload should preserve the completed shared meal without replaying it")
	assert(game.get_node_or_null("ArkRoot/BuiltShelter/TideShellKeepsake/PolishedShell") is MeshInstance3D, "the shared meal's home memory should be reconstructed from the saved event state")
	game.queue_free()
	await process_frame
	save_helper.clear_for_test()

	var busy_save_root := ProjectSettings.globalize_path("res://../.local/test_shared_table_meal_busy_save").simplify_path()
	var busy_save := preload("res://scripts/ark_greybox_save.gd").new(busy_save_root)
	busy_save.clear_for_test()
	var busy_game := await _new_game(scene, busy_save_root)
	busy_game.set("shelter_built", true)
	busy_game.set("resident_met", true)
	busy_game.set("traveler_boarded", true)
	busy_game.set("sailmaker_met", true)
	busy_game.set("sailmaker_boarded", true)
	busy_game.set("stew_servings", 1)
	busy_game.set("shared_meal_day", 0)
	busy_game.set("resident_gather_pending", true)
	busy_game.set("resident_gather_resource", "wood")
	busy_game.set("weather_phase", 2)
	busy_game.call("_set_traveler_boarded")
	busy_game.call("_set_sailmaker_boarded")
	var busy_player := busy_game.get("player") as CharacterBody3D
	var busy_tidekeeper := busy_game.get("traveler_marker") as Node3D
	busy_player.global_position = busy_tidekeeper.global_position
	busy_game.call("_interact")
	assert(not bool(busy_game.get("shared_meal_gathering_pending")) and int(busy_game.get("stew_servings")) == 1 and _count_events(busy_game, "resident_meal_gathering_started") == 0, "a resident already out gathering should not be pulled away or have the meal consumed")
	busy_game.queue_free()
	await process_frame
	busy_save.clear_for_test()


func _run_tidekeeper_box_checks(scene: PackedScene) -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_tidekeeper_box_save").simplify_path()
	assert(save_root.to_lower().begins_with("d:"), "the tidekeeper's physical keepsake box test must save on D:")
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	save_helper.clear_for_test()
	var game := await _new_game(scene, save_root)
	var box := game.get_node("TidekeeperFloatboxInteractable") as Node3D
	assert(box != null and box.get_node_or_null("SaltWornCrate") is MeshInstance3D and box.get_node_or_null("SpareBuoyFloat") is MeshInstance3D, "the opening story's old float box should exist as an inspectable physical world prop")
	assert(box.get_parent() == game and box.position.is_equal_approx(Vector3(14.25, 0.08, -6.45)), "before inviting the tidekeeper, her box should remain beside her on shore")
	assert((game.get("interactables") as Array).any(func(entry: Dictionary) -> bool: return str(entry.get("id", "")) == "tidekeeper_box"), "the physical box should also have a real inspect interaction")
	var player := game.get("player") as CharacterBody3D
	var starting_wood := int(game.get("wood"))
	player.global_position = box.global_position
	game.call("_interact")
	assert(str(game.get("message")).contains("私绳") and int(game.get("wood")) == starting_wood, "inspecting the shore box should show that it belongs to the tidekeeper rather than letting the player loot it")
	game.set("shelter_built", true)
	game.set("resident_met", true)
	game.set("traveler_boarded", true)
	game.call("_set_traveler_boarded")
	assert(box.get_parent() == game.get_node("ArkRoot") and box.position.is_equal_approx(Vector3(2.15, 0.12, -0.45)), "accepting the traveler should move her actual box aboard to a deck-local cargo position")
	assert(bool(game.call("_save_progress")), "the resident and box placement should save")
	game.queue_free()
	await process_frame
	game = await _new_game(scene, save_root)
	box = game.get_node("ArkRoot/TidekeeperFloatboxInteractable") as Node3D
	assert(bool(game.get("traveler_boarded")) and box.get_parent() == game.get_node("ArkRoot") and box.position.is_equal_approx(Vector3(2.15, 0.12, -0.45)), "loading an accepted invitation should reconstruct the box aboard rather than duplicate it ashore")
	player = game.get("player") as CharacterBody3D
	player.global_position = box.global_position
	game.call("_interact")
	assert(str(game.get("message")).contains("旧标灯和干燥的修补料"), "inspecting the onboard prop should recall only what the resident actually brought")
	game.queue_free()
	await process_frame
	save_helper.clear_for_test()

	var decline_root := ProjectSettings.globalize_path("res://../.local/test_tidekeeper_box_decline_save").simplify_path()
	var decline_save := preload("res://scripts/ark_greybox_save.gd").new(decline_root)
	decline_save.clear_for_test()
	var declined_game := await _new_game(scene, decline_root)
	var shore_box := declined_game.get_node("TidekeeperFloatboxInteractable") as Node3D
	declined_game.set("traveler_choice_pending", true)
	declined_game.call("_choose_traveler_boarding", false)
	assert(not bool(declined_game.get("traveler_boarded")) and shore_box.get_parent() == declined_game, "declining shared travel should leave the protected box with its owner on shore")
	declined_game.queue_free()
	await process_frame
	decline_save.clear_for_test()
