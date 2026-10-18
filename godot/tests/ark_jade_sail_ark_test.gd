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
	var save_root := ProjectSettings.globalize_path("res://../.local/test_jade_sail_ark_save").simplify_path()
	assert(save_root.to_lower().begins_with("d:"), "the new-region and cabin regression save must remain on D:")
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	save_helper.clear_for_test()
	var scene := load("res://scenes/ark_greybox.tscn") as PackedScene
	assert(scene != null, "the ark scene must load for the jade sail expedition")
	var game := await _new_game(scene, save_root)
	var jade_position := Vector3(-53.0, 0.2, -45.0)
	var sea := game.get_node("Sea") as MeshInstance3D
	assert(sea != null and (sea.mesh as PlaneMesh).size == Vector2(300.0, 300.0), "the expanded sea surface must contain the new open-water region")
	assert(game.get_node_or_null("JadeSailShoal") is StaticBody3D and game.get_node_or_null("JadeSailArk") is Node3D, "the new shoal and stranded luxury ark must be real world landmarks")
	var destinations: Array = game.call("_world_chart_destinations")
	var chart_has_jade_sail_ark := false
	for destination in destinations:
		if str(destination.get("id", "")) == "jade_sail_ark":
			var mapped_position: Vector3 = destination.get("position", Vector3.ZERO)
			chart_has_jade_sail_ark = mapped_position.is_equal_approx(jade_position)
	assert(chart_has_jade_sail_ark, "the chart should show the new ark without moving the player")
	var chart_script := load("res://scripts/ark_world_chart.gd") as GDScript
	var game_constants := (game.get_script() as GDScript).get_script_constant_map()
	assert(float(chart_script.get_script_constant_map().get("WORLD_HALF_EXTENT", 0.0)) == float(game_constants.get("PLAYER_WORLD_EDGE_LIMIT", 0.0)), "the world chart should include the full player swimming range beyond the ark navigation limit")
	var chart := chart_script.new() as Control
	chart.set("_map_rect", Rect2(Vector2.ZERO, Vector2(100.0, 100.0)))
	var jade_map_position: Vector2 = chart.call("_world_to_map", jade_position)
	assert(jade_map_position.x > 0.0 and jade_map_position.x < 100.0 and jade_map_position.y > 0.0 and jade_map_position.y < 100.0, "the fourth island must remain visible inside the updated chart bounds")
	chart.free()
	assert(bool(game.call("_is_ark_position_navigable", Vector3(-53.0, 0.0, -28.0))), "the extended boundary should include open water adjacent to the far shoal")
	var player := game.get("player") as CharacterBody3D
	player.global_position = jade_position + Vector3(0.0, 1.1, 0.0)
	game.call("_interact")
	assert(bool(game.get("jade_sail_ark_searched")) and int(game.get("guest_cabin_frames")) == 1, "searching the stranded ark should yield one unique cabin frame")
	assert((game.get("learned_blueprint_ids") as Array).has("tide_guest_cabin"), "the guest cabin should become permanent learned knowledge")
	assert(_count_events(game, "jade_sail_ark_salvaged") == 1 and _count_events(game, "blueprint_discovered") >= 1, "the salvage and permanent blueprint should be auditable")
	assert(int(game.get("cold_exposure_level")) == 1, "the dead ward should impose a readable environmental cost")
	await process_frame
	assert(game.get_node_or_null("JadeSailArk/SalvageFrame") == null, "the unique frame should visibly disappear from the wreck after recovery")
	game.call("_interact")
	assert(int(game.get("guest_cabin_frames")) == 1 and _count_events(game, "jade_sail_ark_salvaged") == 1, "revisiting the wreck must not duplicate its unique frame or reward")

	game.set("wood", 20)
	game.set("shelter_built", true)
	game.set("workbench_built", true)
	game.set("keel_beams", 1)
	game.call("_learn_blueprint", "keel_deck_expansion", "test_fixture")
	assert(not bool(game.call("_try_place_guest_cabin_template", Vector3(0.0, 0.12, -4.2))), "a cabin cannot be built on a deck that has not been expanded")
	assert(bool(game.call("_try_place_raft_extension", Vector3(0.0, 0.12, -4.2))), "the recovered keel should allow the home deck to grow first")
	assert(int(game.call("_resident_capacity")) == 3, "the real extension berth should raise capacity before the cabin is built")
	assert(bool(game.call("_try_place_guest_cabin_template", Vector3(0.0, 0.12, -4.2))), "the learned template and unique frame should place on the reserved deck footprint")
	assert(bool(game.get("guest_cabin_built")) and int(game.get("guest_cabin_frames")) == 0 and int(game.get("wood")) == 13, "construction should charge exactly three wood and one unique frame")
	assert(int(game.call("_resident_capacity")) == 4 and game.get_node_or_null("ArkRoot/BuiltRaftExtension/GuestCabin") != null, "the built cabin should add one physical resident berth and reconstruct as scene geometry")
	assert(game.get_node_or_null("ArkRoot/GuestCabinInteractable") != null, "the guest cabin should be inspectable on the actual extension")
	assert(_count_events(game, "guest_cabin_built") == 1, "construction should record a single materials-and-capacity event")
	await physics_frame
	var cabin_button := game.find_child("ArkGuestCabinBlueprintButton", true, false) as Button
	assert(cabin_button.disabled and cabin_button.text.contains("已建成"), "the blueprint control should reflect the constructed cabin")
	game.set("sailmaker_met", true)
	game.set("sailmaker_boarded", true)
	game.set("sailmaker_joined_day", 1)
	game.set("day_count", 2)
	game.set("day_period", 3)
	game.set("weather_phase", 2)
	game.call("_set_sailmaker_boarded")
	game.call("_update_sailmaker_schedule")
	var sailmaker := game.get("sailmaker_marker") as Node3D
	var cabin_target: Vector3 = game.get("sailmaker_target_position")
	assert(str(game.get("sailmaker_action")) == "在听潮客舱歇息" and cabin_target.is_equal_approx(Vector3(-0.85, 0.12, -4.34)), "the guest room should become a real night destination for an onboard resident")
	for _step in range(120):
		if bool(game.get("sailmaker_guest_cabin_first_night")):
			break
		game.call("_process", 0.1)
	assert(sailmaker.get_parent() == game.get_node("ArkRoot") and sailmaker.position.distance_to(cabin_target) < 0.08, "the sailmaker should visibly walk into the cabin rather than only increasing a capacity number")
	assert(bool(game.get("sailmaker_guest_cabin_first_night")) and _count_events(game, "resident_guest_cabin_occupied") == 1, "the first actual night in the cabin should create one persistent resident-life fact")
	assert(bool(game.call("_save_progress")), "the first night in the cabin should be saved with the resident position")
	assert(bool(game.call("_save_progress")), "the learned blueprint, unique frame state, and room should save")
	game.queue_free()
	await process_frame

	game = await _new_game(scene, save_root)
	assert(bool(game.get("jade_sail_ark_searched")) and bool(game.get("guest_cabin_built")) and int(game.get("guest_cabin_frames")) == 0, "the searched landmark and spent frame must survive reload without duplication")
	assert(int(game.call("_resident_capacity")) == 4 and game.get_node_or_null("ArkRoot/BuiltRaftExtension/GuestCabin") != null and game.get_node_or_null("ArkRoot/GuestCabinInteractable") != null, "the expanded cabin and its berth should be reconstructed after reload")
	assert(bool(game.get("sailmaker_guest_cabin_first_night")) and _count_events(game, "resident_guest_cabin_occupied") == 1, "the first-night fact should survive reload without repeating its event")
	var restored_sailmaker := game.get("sailmaker_marker") as Node3D
	assert(restored_sailmaker.position.distance_to(Vector3(-0.85, 0.12, -4.34)) < 0.08, "the resident should reload at the room she actually chose")
	assert(game.get_node_or_null("JadeSailArk/SalvageFrame") == null, "reloading a searched wreck must not restore its recovered frame")
	assert(bool(game.call("_dismantle_raft_extension")), "the player should be able to reclaim an unoccupied extension and its guest cabin")
	assert(not bool(game.get("raft_extension_built")) and not bool(game.get("guest_cabin_built")) and int(game.get("keel_beams")) == 1, "dismantling should remove the cabin and return the keel")
	assert(int(game.get("wood")) == 20 and int(game.get("guest_cabin_frames")) == 1, "dismantling should return all four extension boards, three cabin boards, and its unique cabin frame")
	assert((game.get("learned_blueprint_ids") as Array).has("tide_guest_cabin"), "dismantling must never erase a learned blueprint")
	await process_frame
	assert(game.get_node_or_null("ArkRoot/GuestCabinInteractable") == null, "dismantling must remove the cabin interactable instead of leaving a ghost prompt")
	assert(not bool(game.call("_is_on_raft_extension_deck", restored_sailmaker.position)), "a resident must be safely returned to the original deck before the extension is removed")
	assert(bool(game.call("_try_place_raft_extension", Vector3(0.0, 0.12, -4.2))) and bool(game.call("_try_place_guest_cabin_template", Vector3(0.0, 0.12, -4.2))), "the learned templates and returned materials should allow the room to be rebuilt")
	game.call("_update_sailmaker_schedule")
	for _step in range(120):
		game.call("_process", 0.1)
	assert(_count_events(game, "resident_guest_cabin_occupied") == 1, "rebuilding the same room must not fabricate a second first-night milestone")
	assert(bool(game.call("_save_progress")), "the rebuilt room and its resident schedule should remain saveable")
	game.queue_free()
	await process_frame
	save_helper.clear_for_test()
	print("ARK_JADE_SAIL_ARK_TEST_OK:")
	quit(0)
