extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _count_events(game: Node, event_id: String) -> int:
	var count := 0
	for event in game.get("world_events") as Array:
		if str(event.get("id", "")) == event_id:
			count += 1
	return count


func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_reef_surge_save").simplify_path()
	assert(save_root.to_lower().begins_with("d:"), "reef surge test saves must remain on D:")
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	save_helper.clear_for_test()
	var packed := load("res://scenes/ark_greybox.tscn") as PackedScene
	assert(packed != null, "the ark slice should load for a reef encounter")
	var game: Node = packed.instantiate()
	game.set("save_root_override", save_root)
	root.add_child(game)
	await physics_frame
	var warning := game.get_node_or_null("ReefSurgeChannelWarning") as Node3D
	assert(warning != null and warning.get_node_or_null("FoamLine0") is MeshInstance3D, "white foam and a visible warning stake should mark the dangerous low-water channel before commitment")
	assert(str((warning.get_node("Name") as Label3D).text).contains("沿礁脊可绕行"), "the landmark should communicate a real safer route rather than a level gate")
	var destinations: Array[Dictionary] = game.call("_world_chart_destinations")
	var reef_destination: Dictionary = {}
	for destination in destinations:
		if str(destination.get("id", "")) == "far_reef":
			reef_destination = destination
	assert(str(reef_destination.get("description", "")).contains("不设等级门槛") and str(reef_destination.get("description", "")).contains("沿礁脊绕行"), "the open-world chart should explain both the risk and the ungated high-ground route")
	var chart := game.get("world_chart") as Control
	assert(chart.call("_destination_risk_color", 3) == Color("e29a72") and chart.call("_destination_risk_color", 0) == Color("e4e3d0"), "high-risk destinations should be visually distinct on the map without becoming inaccessible")

	var player: CharacterBody3D = game.get("player") as CharacterBody3D
	player.global_position = Vector3(35.0, -1.5, -35.5)
	player.velocity = Vector3.ZERO
	game.set("is_swimming", true)
	game.call("_apply_reef_surge", 1.0 / 60.0)
	var push_direction := Vector2(-0.52, -0.85).normalized()
	var applied_push := Vector2(player.velocity.x, player.velocity.z)
	assert(applied_push.dot(push_direction) > 3.9, "swimming through the marked channel should be pushed out toward the open water, not blocked by an invisible wall")
	assert(_count_events(game, "reef_surge_deflected") == 1, "the current should record a factual, non-damaging encounter")
	assert(not bool((game.get("world_events") as Array).back().get("facts", {}).get("damage", -1)), "the first surge response should explicitly be survivable without damage")
	game.call("_apply_reef_surge", 1.0 / 60.0)
	assert(_count_events(game, "reef_surge_deflected") == 1, "the short current cooldown should prevent event spam")

	player.global_position = Vector3(39.0, 0.6, -29.0)
	player.velocity = Vector3.ZERO
	game.set("is_swimming", false)
	game.call("_apply_reef_surge", 2.0)
	assert(Vector2(player.velocity.x, player.velocity.z).is_zero_approx(), "walking along the high reef should avoid the current and preserve access to the wreck")
	player.global_position = Vector3(39.0, 1.1, -29.0)
	game.call("_interact")
	assert(bool(game.get("keel_wreck_searched")) and int(game.get("keel_beams")) == 1, "the freely reachable far-reef wreck should still grant its unique exploration reward")
	assert(_count_events(game, "keel_wreck_salvaged") == 1, "the reward source should be recorded once")
	assert(bool(game.call("_save_progress")), "the route and encounter history should save")
	game.queue_free()
	await process_frame
	var restored: Node = packed.instantiate()
	restored.set("save_root_override", save_root)
	root.add_child(restored)
	await physics_frame
	assert(_count_events(restored, "reef_surge_deflected") == 1 and _count_events(restored, "keel_wreck_salvaged") == 1, "the risk and recovered reward should both remain in the event history after reload")
	assert(bool(restored.get("keel_wreck_searched")) and int(restored.get("keel_beams")) == 1, "loading should not erase or duplicate the once-only reward")
	restored.queue_free()
	await process_frame
	save_helper.clear_for_test()
	print("ARK_REEF_SURGE_TEST_OK:")
	quit()
