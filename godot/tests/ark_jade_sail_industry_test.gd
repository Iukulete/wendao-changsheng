extends SceneTree

const JADE_INDUSTRY_TEST_RESOURCE_IDS := ["JadeSailTidalShells", "JadeSailTidalShellsWest", "JadeSailTidalShellsNorth"]


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


func _talk_to_keeper(game: Node) -> void:
	var player := game.get("player") as CharacterBody3D
	var keeper := game.get_node("JadeSailKeeper") as Node3D
	player.global_position = keeper.global_position + Vector3(0.0, 1.0, 0.0)
	game.call("_interact")


func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_jade_sail_industry_save").simplify_path()
	assert(save_root.to_lower().begins_with("d:"), "industry contract, cargo and migration saves must remain on D:")
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	save_helper.clear_for_test()
	var scene := load("res://scenes/ark_greybox.tscn") as PackedScene
	assert(scene != null, "the greybox scene must load for the vessel-industry slice")
	var game := await _new_game(scene, save_root)
	var player := game.get("player") as CharacterBody3D
	var keeper := game.get_node("JadeSailKeeper") as Node3D
	assert(game.get_node_or_null("JadeSailArk/jade_sail_cargoMarker") != null, "the luxury vessel must have its own inspectable cargo hold")

	_talk_to_keeper(game)
	assert(bool(game.get("jade_sail_keeper_met")) and not bool(game.get("jade_sail_industry_choice_pending")), "meeting the keeper is possible before the wreck ledger, but must not skip informed consent")
	_talk_to_keeper(game)
	assert(not bool(game.get("jade_sail_industry_choice_pending")), "the business offer must remain unavailable until the player reads the vessel ledger")
	player.global_position = Vector3(-53.0, 1.3, -45.0)
	game.call("_interact")
	assert(bool(game.get("jade_sail_ark_searched")) and int(game.get("guest_cabin_frames")) == 1, "the ship ledger and unique cabin frame should retain their original exploration reward")
	game.set("wood", 2)
	_talk_to_keeper(game)
	assert(not bool(game.get("jade_sail_industry_choice_pending")), "the player must not sign a repair contract without the required real materials")

	game.set("wood", 3)
	_talk_to_keeper(game)
	assert(bool(game.get("jade_sail_industry_choice_pending")), "the informed contract should be offered once ledger, crew contact, and repair wood are present")
	var decline := InputEventKey.new()
	decline.keycode = KEY_2
	decline.pressed = true
	game.call("_unhandled_key_input", decline)
	assert(not bool(game.get("jade_sail_industry_active")) and int(game.get("wood")) == 3 and _count_events(game, "jade_sail_industry_contract_declined") == 1, "declining must preserve materials and leave the ship independent")
	_talk_to_keeper(game)
	var accept := InputEventKey.new()
	accept.keycode = KEY_1
	accept.pressed = true
	game.call("_unhandled_key_input", accept)
	assert(bool(game.get("jade_sail_industry_active")) and int(game.get("wood")) == 0, "signing should spend exactly three wood and add this vessel to the industry ledger")
	assert(_count_events(game, "jade_sail_industry_contract_signed") == 1 and bool((game.get("world_events") as Array).back().get("facts", {}).get("crew_authority_retained", false)), "the contract must record crew consent and retained authority")
	assert(game.get_node_or_null("JadeSailArk/WarmServiceLamp") != null and game.get_node_or_null("JadeSailArk/RepairedTradeApron") != null, "the investment should visibly repair and relight the luxury vessel")
	assert(int(game.get("raw_shellfish")) == 0, "the player's inventory must stay separate when the contract begins")

	game.set("weather_phase", 2)
	game.set("day_period", 3)
	game.set("day_count", 1)
	var first_morning: Dictionary = game.call("_advance_world_period", "industry_regression")
	assert(bool(first_morning.get("jade_industry_gather_started", false)), "the contracted vessel should start a real supply run on an in-game morning")
	var first_target := str(game.get("jade_sail_industry_target_id"))
	assert(bool(game.get("jade_sail_industry_pending")) and ["JadeSailTidalShells", "JadeSailTidalShellsWest", "JadeSailTidalShellsNorth"].has(first_target), "the worker must claim one specific finite node near the luxury vessel")
	var target_node: Node3D = null
	for entry in game.get("interactables") as Array:
		if str(entry.get("item_id", "")) == first_target:
			target_node = entry.get("node") as Node3D
			break
	assert(target_node != null, "the worker's resource target must exist in the actual world")
	player.global_position = target_node.global_position + Vector3(0.0, 1.0, 0.0)
	game.call("_interact")
	var player_shellfish_after_race := int(game.get("raw_shellfish"))
	game.call("_process", 0.1)
	assert(player_shellfish_after_race > 0 and not bool(game.get("jade_sail_industry_pending")) and int(game.get("jade_sail_industry_shellfish")) == 0, "if the player takes a claimed node first, the trip must cancel without duplicate yield")
	assert(_count_events(game, "jade_sail_industry_gather_cancelled") == 1, "a contested finite supply run should produce one cancellation fact")

	for _period in range(4):
		game.call("_advance_world_period", "industry_regression")
	assert(bool(game.get("jade_sail_industry_pending")) and str(game.get("jade_sail_industry_target_id")) != first_target, "the next in-game morning should assign a different still-existing finite node")
	var storm_target := str(game.get("jade_sail_industry_target_id"))
	game.set("weather_phase", 1)
	game.call("_process", 0.1)
	assert(not bool(game.get("jade_sail_industry_pending")) and int(game.get("jade_sail_industry_shellfish")) == 0 and not (game.get("collected_ids") as Array).has(storm_target), "a storm before pickup must recall the worker without consuming or creating supply")
	assert(_count_events(game, "jade_sail_industry_gather_cancelled") == 2, "the separate weather cancellation should be recorded exactly once")
	game.set("weather_phase", 2)
	for _period in range(4):
		game.call("_advance_world_period", "industry_regression")
	assert(bool(game.get("jade_sail_industry_pending")) and str(game.get("jade_sail_industry_target_id")) == storm_target, "the next morning should retry the same finite node after a weather cancellation")
	var second_target := str(game.get("jade_sail_industry_target_id"))
	game.call("_process", 0.5)
	var saved_keeper_position := keeper.global_position
	assert(bool(game.call("_save_progress")), "an active supply run must be persistable mid-trip")
	game.set("save_service", null)
	game.queue_free()
	await process_frame

	game = await _new_game(scene, save_root)
	player = game.get("player") as CharacterBody3D
	keeper = game.get_node("JadeSailKeeper") as Node3D
	assert(bool(game.get("jade_sail_industry_active")) and bool(game.get("jade_sail_industry_pending")) and str(game.get("jade_sail_industry_target_id")) == second_target, "the contract and exact in-transit resource target must resume after reload")
	assert(keeper.global_position.distance_to(saved_keeper_position) < 0.03, "the crew member's physical in-transit position should survive reload")
	assert(int(game.get("raw_shellfish")) == player_shellfish_after_race and int(game.get("jade_sail_industry_shellfish")) == 0, "reload must not merge the vessel hold into the player's bag")
	for _step in range(600):
		if not bool(game.get("jade_sail_industry_pending")):
			break
		game.call("_process", 0.1)
	assert(not bool(game.get("jade_sail_industry_pending")) and int(game.get("jade_sail_industry_shellfish")) == 1, "the keeper should walk to an actual node, harvest it once, and deliver one unit to the vessel hold")
	assert(int(game.get("raw_shellfish")) == player_shellfish_after_race and _count_events(game, "jade_sail_industry_supply_delivered") == 1, "delivery must affect only the independent vessel hold and be recorded once")
	assert(second_target in (game.get("collected_ids") as Array), "a delivered industry resource must be permanently marked collected in the world")
	assert(bool(game.call("_save_progress")), "the delivered cargo state must be persisted")
	game.set("save_service", null)
	game.queue_free()
	await process_frame

	game = await _new_game(scene, save_root)
	player = game.get("player") as CharacterBody3D
	assert(int(game.get("jade_sail_industry_shellfish")) == 1 and int(game.get("jade_sail_industry_deliveries")) == 1 and _count_events(game, "jade_sail_industry_supply_delivered") == 1, "reloading delivered cargo must not repeat its shipment")
	var cargo_marker := game.get_node("JadeSailArk/jade_sail_cargoMarker") as Node3D
	player.global_position = cargo_marker.global_position + Vector3(0.0, 1.0, 0.0)
	game.call("_interact")
	assert(int(game.get("jade_sail_industry_shellfish")) == 0 and int(game.get("raw_shellfish")) == player_shellfish_after_race + 1, "claiming the contractual shipment should transfer it once from the separate hold to inventory")
	assert(_count_events(game, "jade_sail_industry_supply_withdrawn") == 1, "cargo withdrawal should be auditable exactly once")
	for _period in range(4):
		game.call("_advance_world_period", "industry_regression")
	assert(bool(game.get("jade_sail_industry_pending")), "the next morning should start a second real delivery for the trial contract")
	var trial_target := str(game.get("jade_sail_industry_target_id"))
	assert(trial_target != second_target, "the second trial delivery must claim a different finite patch")
	for _step in range(600):
		if not bool(game.get("jade_sail_industry_pending")):
			break
		game.call("_process", 0.1)
	assert(not bool(game.get("jade_sail_industry_pending")) and int(game.get("jade_sail_industry_deliveries")) == 2, "the two-delivery pilot threshold must require two completed physical runs")
	game.set("wood", 2)
	_talk_to_keeper(game)
	assert(not bool(game.get("jade_sail_industry_choice_pending")), "the long-term affiliation offer must not appear without its real repair contribution")
	game.set("wood", 3)
	_talk_to_keeper(game)
	assert(bool(game.get("jade_sail_industry_choice_pending")) and str(game.get("jade_sail_industry_choice_kind")) == "affiliation", "two physical deliveries and three repair wood should unlock a separate affiliation choice")
	var decline_affiliation := InputEventKey.new()
	decline_affiliation.keycode = KEY_2
	decline_affiliation.pressed = true
	game.call("_unhandled_key_input", decline_affiliation)
	assert(not bool(game.get("jade_sail_industry_acquired")) and bool(game.get("jade_sail_industry_active")) and int(game.get("wood")) == 3, "declining full affiliation must retain the cooperative pilot and all materials")
	_talk_to_keeper(game)
	var accept_affiliation := InputEventKey.new()
	accept_affiliation.keycode = KEY_1
	accept_affiliation.pressed = true
	game.call("_unhandled_key_input", accept_affiliation)
	assert(bool(game.get("jade_sail_industry_acquired")) and int(game.get("wood")) == 0, "accepting affiliation should spend the agreed repair material and acquire operating rights")
	var affiliation_facts: Dictionary = (game.get("world_events") as Array).back().get("facts", {})
	assert(bool(affiliation_facts.get("management_rights_transferred", false)) and not bool(affiliation_facts.get("vessel_ownership_transferred", true)) and bool(affiliation_facts.get("crew_authority_retained", false)), "the affiliation must transfer business rights by consent without confiscating the vessel or its crew authority")
	for entry in (game.get("interactables") as Array).duplicate():
		if str(entry.get("id", "")) != "shellfish" or not JADE_INDUSTRY_TEST_RESOURCE_IDS.has(str(entry.get("item_id", ""))):
			continue
		var shell_node := entry.get("node") as Node3D
		if shell_node and is_instance_valid(shell_node):
			player.global_position = shell_node.global_position + Vector3(0.0, 1.0, 0.0)
			game.call("_interact")
	for _period in range(4):
		game.call("_advance_world_period", "industry_regression")
	assert(bool(game.get("jade_sail_industry_pending")) and str(game.get("jade_sail_industry_resource")) == "wood" and str(game.get("jade_sail_industry_target_id")) == "JadeSailDriftwood", "acquired operating rights should expand work to the real finite driftwood node beside the vessel")
	for _step in range(600):
		if not bool(game.get("jade_sail_industry_pending")):
			break
		game.call("_process", 0.1)
	assert(not bool(game.get("jade_sail_industry_pending")) and int(game.get("jade_sail_industry_wood")) == 3, "the acquired industry should deliver the actual three-piece driftwood pile to its own hold")
	assert(_count_events(game, "jade_sail_industry_supply_delivered") == 3, "each shellfish or driftwood delivery should be accounted exactly once")
	assert(bool(game.call("_save_progress")), "acquired operating rights and expanded cargo must persist")
	game.set("save_service", null)
	game.queue_free()
	await process_frame

	game = await _new_game(scene, save_root)
	player = game.get("player") as CharacterBody3D
	assert(bool(game.get("jade_sail_industry_acquired")) and int(game.get("jade_sail_industry_wood")) == 3, "schema 25 should restore the affiliation tier and separate wood cargo")
	cargo_marker = game.get_node("JadeSailArk/jade_sail_cargoMarker") as Node3D
	player.global_position = cargo_marker.global_position + Vector3(0.0, 1.0, 0.0)
	game.call("_interact")
	assert(int(game.get("jade_sail_industry_wood")) == 0 and int(game.get("wood")) == 3, "withdrawing the acquired industry's wood should move actual stock into player inventory exactly once")
	assert(_count_events(game, "jade_sail_industry_supply_withdrawn") == 3, "both shellfish batches and the acquired driftwood should remain separately auditable")
	_talk_to_keeper(game)
	assert(bool(game.get("jade_sail_industry_choice_pending")) and str(game.get("jade_sail_industry_choice_kind")) == "vessel_title", "three real deliveries and operating rights should unlock an optional, separate vessel-title transfer")
	var decline_title := InputEventKey.new()
	decline_title.keycode = KEY_2
	decline_title.pressed = true
	game.call("_unhandled_key_input", decline_title)
	assert(not bool(game.get("jade_sail_vessel_title_owned")) and bool(game.get("jade_sail_industry_acquired")) and int(game.get("wood")) == 3 and _count_events(game, "jade_sail_vessel_title_transfer_declined") == 1, "declining ship ownership must retain operating rights and all materials")
	_talk_to_keeper(game)
	assert(bool(game.get("jade_sail_industry_choice_pending")), "the voluntary title offer should remain available after a decline")
	game.set("wood", 2)
	var stale_title_accept := InputEventKey.new()
	stale_title_accept.keycode = KEY_1
	stale_title_accept.pressed = true
	game.call("_unhandled_key_input", stale_title_accept)
	assert(not bool(game.get("jade_sail_vessel_title_owned")) and int(game.get("wood")) == 2, "the title-transfer choice must revalidate its maintenance reserve before changing ownership")
	game.set("wood", 3)
	_talk_to_keeper(game)
	var player_ark := game.get("ark_root") as Node3D
	var player_ark_position := player_ark.position
	var accept_title := InputEventKey.new()
	accept_title.keycode = KEY_1
	accept_title.pressed = true
	game.call("_unhandled_key_input", accept_title)
	assert(bool(game.get("jade_sail_vessel_title_owned")) and bool(game.get("jade_sail_industry_acquired")) and int(game.get("wood")) == 0 and int(game.get("jade_sail_industry_wood")) == 3, "accepting the title should transfer the agreed wood into the vessel's maintenance reserve without removing its industry rights")
	assert(player_ark.position.is_equal_approx(player_ark_position), "acquiring the luxury vessel must not replace or move the player's home ark")
	var title_facts: Dictionary = (game.get("world_events") as Array).back().get("facts", {})
	assert(bool(title_facts.get("vessel_ownership_transferred", false)) and bool(title_facts.get("crew_can_leave", false)) and bool(title_facts.get("crew_can_refuse_work", false)) and not bool(title_facts.get("crew_employment_transferred", true)) and not bool(title_facts.get("player_ark_replaced", true)), "the title deed must record voluntary transfer while preserving crew agency and the player's original ark")
	assert(_count_events(game, "jade_sail_vessel_title_transferred") == 1 and str((game.get_node("JadeSailArk/Name") as Label3D).text).contains("船体自有"), "the deed should be unique and visibly distinguish owned hull title from operating rights")
	_talk_to_keeper(game)
	assert(not bool(game.get("jade_sail_industry_choice_pending")) and _count_events(game, "jade_sail_vessel_title_transferred") == 1 and int(game.get("wood")) == 0, "revisiting after the deed must not prompt or transfer the vessel twice")
	assert(bool(game.call("_save_progress")), "the vessel asset deed and maintenance reserve must save")
	game.set("save_service", null)
	game.queue_free()
	await process_frame
	game = await _new_game(scene, save_root)
	assert(bool(game.get("jade_sail_vessel_title_owned")) and bool(game.get("jade_sail_industry_acquired")) and int(game.get("jade_sail_industry_wood")) == 3, "schema 29 should restore vessel title ownership and its maintenance reserve")
	var schema_28_state: Dictionary = game.call("_build_save_state")
	schema_28_state["schema_version"] = 28
	schema_28_state.erase("jade_sail_vessel_title_owned")
	schema_28_state["jade_sail_industry_wood"] = 0
	schema_28_state["wood"] = 3
	var schema_28_events: Array = []
	for event in schema_28_state.get("world_events", []) as Array:
		if str(event.get("id", "")) != "jade_sail_vessel_title_transferred":
			schema_28_events.append(event)
	schema_28_state["world_events"] = schema_28_events
	assert(bool(save_helper.save_state(schema_28_state).get("ok", false)), "a version-28 fixture must be writable to verify the new title migration")
	game.set("save_service", null)
	game.queue_free()
	await process_frame
	game = await _new_game(scene, save_root)
	assert(not bool(game.get("jade_sail_vessel_title_owned")) and bool(game.get("jade_sail_industry_acquired")) and int(game.get("jade_sail_industry_wood")) == 0, "version-28 industry saves must retain operating rights but never gain invented vessel ownership or reserves")

	var schema_24_state: Dictionary = game.call("_build_save_state")
	schema_24_state["schema_version"] = 24
	for new_key in ["jade_sail_industry_acquired", "jade_sail_vessel_title_owned", "jade_sail_industry_wood", "jade_sail_industry_resource"]:
		schema_24_state.erase(new_key)
	assert(bool(save_helper.save_state(schema_24_state).get("ok", false)), "a version-24 industry fixture must be writable for forward migration coverage")
	game.set("save_service", null)
	game.queue_free()
	await process_frame
	game = await _new_game(scene, save_root)
	assert(bool(game.get("jade_sail_industry_active")) and not bool(game.get("jade_sail_industry_acquired")) and not bool(game.get("jade_sail_vessel_title_owned")) and int(game.get("jade_sail_industry_wood")) == 0, "version-24 cooperative contracts should remain cooperative and must not gain acquired rights, vessel ownership, or invented cargo")

	var legacy_state: Dictionary = game.call("_build_save_state")
	legacy_state["schema_version"] = 23
	legacy_state["world_events"] = []
	legacy_state["event_sequence"] = 0
	legacy_state["collected_ids"] = []
	for industry_key in ["jade_sail_keeper_met", "jade_sail_industry_active", "jade_sail_industry_acquired", "jade_sail_vessel_title_owned", "jade_sail_industry_shellfish", "jade_sail_industry_wood", "jade_sail_industry_last_day", "jade_sail_industry_pending", "jade_sail_industry_phase", "jade_sail_industry_resource", "jade_sail_industry_target_id", "jade_sail_industry_target_position", "jade_sail_industry_payload", "jade_sail_industry_pickup_remaining", "jade_sail_industry_deliveries", "jade_sail_keeper_position"]:
		legacy_state.erase(industry_key)
	assert(bool(save_helper.save_state(legacy_state).get("ok", false)), "a version-23 fixture must be writable for migration coverage")
	game.set("save_service", null)
	game.queue_free()
	await process_frame
	game = await _new_game(scene, save_root)
	assert(not bool(game.get("jade_sail_industry_active")) and not bool(game.get("jade_sail_industry_acquired")) and not bool(game.get("jade_sail_vessel_title_owned")) and int(game.get("jade_sail_industry_shellfish")) == 0 and int(game.get("jade_sail_industry_wood")) == 0 and not bool(game.get("jade_sail_industry_pending")), "version-23 saves must migrate without inventing a contract, acquired rights, vessel ownership, or cargo")
	assert(bool(game.get("jade_sail_ark_searched")) and game.get_node_or_null("JadeSailArk/WarmServiceLamp") == null, "legacy vessel exploration remains intact while industry defaults to absent")
	game.set("save_service", null)
	game.queue_free()
	await process_frame
	save_helper.clear_for_test()
	print("ARK_JADE_SAIL_INDUSTRY_TEST_OK:")
	quit(0)
