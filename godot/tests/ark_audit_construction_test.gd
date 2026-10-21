extends SceneTree

const ArkTestPaths = preload("res://tests/ark_test_paths.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_ark_audit_construction").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(save_root), "audit saves must stay in this repository's isolated test directory")
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	save_helper.clear_for_test()
	var game := (load("res://scenes/ark_greybox.tscn") as PackedScene).instantiate()
	game.set("save_root_override", save_root)
	root.add_child(game)
	await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.set("workbench_built", true)
	game.set("wood", 7)
	game.set("keel_beams", 1)
	game.set("guest_cabin_frames", 1)
	game.call("_learn_blueprint", "keel_deck_expansion", "audit")
	game.call("_learn_blueprint", "tide_guest_cabin", "audit")
	for _cycle in range(3):
		assert(bool(game.call("_try_place_raft_extension", Vector3(0.0, 0.12, -4.0))), "a dismantled extension should be rebuildable immediately")
		assert(bool(game.call("_try_place_guest_cabin_template", Vector3(0.0, 0.12, -4.0))), "a replacement deck must own a real addressable cabin")
		assert(game.get_node_or_null("ArkRoot/BuiltRaftExtension/GuestCabin") != null, "same-frame replacement must retain stable structure names")
		assert(int(game.get("wood")) == 0 and int(game.get("keel_beams")) == 0 and int(game.get("guest_cabin_frames")) == 0, "building must spend one deck/cabin resource bundle")
		game.set("traveler_routine_route", PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.12, -5.0)]))
		game.set("traveler_routine_route_target_set", true)
		assert(bool(game.call("_dismantle_raft_extension")), "a replacement deck must remain dismantlable")
		assert((game.get("traveler_routine_route") as PackedVector3Array).is_empty() and not bool(game.get("traveler_routine_route_target_set")), "dismantling must discard cached routes over removed flooring")
		assert(game.get_node_or_null("ArkRoot/BuiltRaftExtension") == null, "retired structure names must be released before deferred deletion")
		assert(int(game.get("wood")) == 7 and int(game.get("keel_beams")) == 1 and int(game.get("guest_cabin_frames")) == 1, "dismantling must refund exactly the original bundle")
		assert(not bool(game.call("_dismantle_raft_extension")), "repeated dismantle cannot refund the same deck twice")
	assert(bool(game.call("_try_place_raft_extension", Vector3(0.0, 0.12, -4.0))), "final rebuilt deck should be usable after the queued deletions drain")
	await process_frame
	assert(game.get_node_or_null("ArkRoot/BuiltRaftExtension") != null and game.get_node_or_null("ArkRoot/RaftExtensionInteractable") != null, "only the retired nodes should disappear at frame end")
	var markers := 0
	for entry in game.get("interactables") as Array:
		if str(entry.get("id", "")) == "raft_extension":
			markers += 1
	assert(markers == 1, "repeated rebuilds must preserve a single live extension interaction")
	assert(bool(game.call("_dismantle_raft_extension")), "the final deck should still be dismantlable after a frame")
	assert(int(game.get("wood")) == 7, "rebuild cycles must neither mint nor lose wood")
	game.queue_free()
	await process_frame
	save_helper.clear_for_test()
	print("ARK_AUDIT_CONSTRUCTION_TEST_OK:")
	quit()
