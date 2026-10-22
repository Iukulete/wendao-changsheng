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
	game.set_process(false)
	game.set_physics_process(false)
	game.set("save_root_override", save_root)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await physics_frame
	return game


func _interact_at(game: Node, interactable_id: String) -> void:
	var target: Node3D = null
	for entry in game.get("interactables") as Array:
		if str(entry.get("id", "")) == interactable_id:
			target = entry.get("node") as Node3D
			break
	assert(target != null, "the expected luxury-ark point should exist: " + interactable_id)
	var player := game.get("player") as CharacterBody3D
	player.global_position = target.global_position + Vector3(0.0, 0.55, 0.0)
	game.call("_interact")


func _choose_guest_offer(game: Node, accept: bool) -> void:
	var choice := InputEventKey.new()
	choice.keycode = KEY_1 if accept else KEY_2
	choice.pressed = true
	game.call("_unhandled_key_input", choice)


func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_jade_sail_guest_stay_save").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(save_root), "test saves must be isolated in this repository; Windows saves must remain on D:")
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	save_helper.clear_for_test()
	var scene := load("res://scenes/ark_greybox.tscn") as PackedScene
	assert(scene != null, "the greybox scene must load for the luxury-ark hospitality slice")
	var game := await _new_game(scene, save_root)
	var wreck := game.get_node("JadeSailArk") as Node3D
	var deck_body := wreck.get_node_or_null("GuestDeckWalkable") as StaticBody3D
	assert(deck_body != null and deck_body.get_child_count() == 1 and deck_body.get_child(0) is CollisionShape3D, "the luxury vessel's deck must be physically walkable")
	var ramp := wreck.get_node_or_null("GuestBoardingRamp") as StaticBody3D
	assert(ramp != null, "the boarding ramp should be a solid body")
	assert(ramp.get_child_count() == 2 and ramp.get_child(1) is CollisionShape3D and ramp.rotation.x > 0.2, "a walkable sloped gangway should connect the shoal to the guest deck")
	assert(wreck.get_node_or_null("GuestCabinBackWall") is StaticBody3D and wreck.get_node_or_null("GuestBerthMattress") is MeshInstance3D and wreck.get_node_or_null("GuestRegistryBook") is MeshInstance3D, "the room should contain a real berth and guest registry, not only a service timer")
	var player := game.get("player") as CharacterBody3D
	player.global_position = Vector3(-53.0, 1.3, -45.0)
	game.call("_interact")
	assert(bool(game.get("jade_sail_ark_searched")) and int(game.get("guest_cabin_frames")) == 1, "the guest service must not consume or replace the existing unique cabin-frame reward")
	var keeper := game.get_node("JadeSailKeeper") as Node3D
	player.global_position = keeper.global_position + Vector3(0.0, 0.8, 0.0)
	game.call("_interact")
	assert(bool(game.get("jade_sail_keeper_met")) and not bool(game.get("jade_sail_guest_choice_pending")), "meeting the keeper alone must not fabricate a guest pass")
	_interact_at(game, "jade_sail_guest_bead")
	assert(bool(game.get("jade_sail_guest_bead_collected")) and _count_events(game, "jade_sail_guest_bead_found") == 1, "the optional rare bead should be found once inside the actual guest cabin")
	await process_frame
	assert(game.get_node_or_null("JadeSailArk/jade_sail_guest_beadMarker") == null, "the recovered bead and its interaction marker should disappear from the room")
	_interact_at(game, "jade_sail_guest_registry")
	assert(bool(game.get("jade_sail_guest_choice_pending")), "the independent registry should offer a one-night stay after the rare item is found")
	_choose_guest_offer(game, false)
	assert(bool(game.get("jade_sail_guest_bead_collected")) and not bool(game.get("jade_sail_guest_pass_active")) and _count_events(game, "jade_sail_guest_pass_declined") == 1, "declining the offer must preserve the rare item")
	_interact_at(game, "jade_sail_guest_registry")
	_choose_guest_offer(game, true)
	assert(not bool(game.get("jade_sail_guest_bead_collected")) and bool(game.get("jade_sail_guest_pass_active")), "accepting should spend only the guest bead and grant one stay")
	assert(not bool(game.get("jade_sail_industry_active")) and not bool(game.get("jade_sail_industry_acquired")) and int(game.get("wood")) == 1, "guest rights must not start an industry contract, transfer ownership, or spend construction wood")
	assert(_count_events(game, "jade_sail_guest_pass_granted") == 1 and not bool((game.get("world_events") as Array).back().get("facts", {}).get("vessel_ownership_transferred", true)), "the guest-pass ledger must explicitly preserve ship ownership")
	assert(bool(game.call("_save_progress")), "an unused guest pass should save before the player retires for the night")
	game.set("save_service", null)
	game.queue_free()
	await process_frame

	game = await _new_game(scene, save_root)
	player = game.get("player") as CharacterBody3D
	assert(bool(game.get("jade_sail_guest_pass_active")) and not bool(game.get("jade_sail_guest_stay_used")), "the unused stay should survive a reload without being consumed")
	var spent_bead := game.get_node_or_null("JadeSailArk/GuestPassBead") as MeshInstance3D
	assert(spent_bead != null and not spent_bead.visible, "reloading a granted stay must not recreate the spent bead")
	game.set("day_count", 7)
	game.set("day_period", 2)
	game.set("cold_exposure_level", 2)
	game.set("cold_exposure", true)
	_interact_at(game, "jade_sail_guest_berth")
	assert(not bool(game.get("jade_sail_guest_pass_active")) and bool(game.get("jade_sail_guest_stay_used")), "using the physical berth should consume the pass exactly once")
	assert(int(game.get("day_count")) == 8 and int(game.get("day_period")) == 0, "one guest night should advance the shared world clock exactly to the next morning")
	assert(int(game.get("cold_exposure_level")) == 0 and _count_events(game, "jade_sail_guest_night_completed") == 1, "the dry guest room should resolve exposure and record one completed night")
	assert(_count_events(game, "time_advanced") >= 2 and not bool(game.get("jade_sail_industry_active")), "the stay should use ordinary game-time advancement without granting business rights")
	assert(bool(game.call("_save_progress")), "the completed stay should save")
	game.set("save_service", null)
	game.queue_free()
	await process_frame

	game = await _new_game(scene, save_root)
	assert(bool(game.get("jade_sail_guest_stay_used")) and not bool(game.get("jade_sail_guest_pass_active")) and _count_events(game, "jade_sail_guest_night_completed") == 1, "the completed night should not repeat after reload")
	var legacy_state: Dictionary = game.call("_build_save_state")
	legacy_state["schema_version"] = 27
	legacy_state["world_events"] = []
	legacy_state["event_sequence"] = 0
	for field in ["jade_sail_guest_bead_collected", "jade_sail_guest_pass_active", "jade_sail_guest_stay_used"]:
		legacy_state.erase(field)
	assert(bool(save_helper.save_state(legacy_state).get("ok", false)), "a schema-27 migration fixture should be writable")
	game.set("save_service", null)
	game.queue_free()
	await process_frame

	game = await _new_game(scene, save_root)
	assert(not bool(game.get("jade_sail_guest_bead_collected")) and not bool(game.get("jade_sail_guest_pass_active")) and not bool(game.get("jade_sail_guest_stay_used")), "schema-27 saves must not gain a submitted item, pass, or completed stay from missing fields")
	assert(bool(game.get("jade_sail_ark_searched")) and game.get_node_or_null("JadeSailArk/jade_sail_guest_beadMarker") != null, "old saves that already explored the vessel may find the newly added unique guest item")
	game.set("save_service", null)
	game.queue_free()
	await process_frame
	save_helper.clear_for_test()
	print("ARK_JADE_SAIL_GUEST_STAY_TEST_OK:")
	quit(0)
