extends SceneTree

const ArkTestPaths = preload("res://tests/ark_test_paths.gd")


func _initialize() -> void:
	_run.call_deferred()


func _count_events(events: Array, event_id: String) -> int:
	var count := 0
	for event in events:
		if event is Dictionary and str(event.get("id", "")) == event_id:
			count += 1
	return count


func _run() -> void:
	var test_save_root := ProjectSettings.globalize_path("res://../.local/test_save").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(test_save_root), "test saves must be isolated in this repository; Windows saves must remain on D:")
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(test_save_root)
	save_helper.clear_for_test()
	var packed := load("res://scenes/ark_greybox.tscn") as PackedScene
	assert(packed != null, "greybox scene must load")
	var game := packed.instantiate()
	game.set("save_root_override", test_save_root)
	root.add_child(game)
	await process_frame
	var return_button := game.find_child("ArkReturnToMainButton", true, false) as Button
	var exploration_blueprint_button := game.find_child("ArkRaftExpansionBlueprintButton", true, false) as Button
	var opening_hud := game.get("hud") as Label
	assert(return_button != null and not return_button.disabled, "the 3D slice should offer a clear route back to the saved main interface")
	assert(exploration_blueprint_button != null and exploration_blueprint_button.disabled, "the distinctive expansion blueprint should remain locked until its remote exploration source is found")
	assert(opening_hud != null and opening_hud.text.contains("现在就能掌舵") and opening_hud.text.contains("收集 2 块漂木") and opening_hud.text.contains("木料 1（随身）"), "the first HUD should make immediate sailing, shore supplies, and current starting resource obvious")
	assert(not opening_hud.text.contains("产业簿") and not opening_hud.text.contains("蒸潮饭釜"), "late-game ark systems should not crowd out the opening survival objective")
	game.set("weather_phase", 1)
	game.call("_update_hud")
	assert(opening_hud.text.contains("当前目标：风雨正急，眼下还没有避风棚"), "a player who reaches a storm without building should never be directed to shelter that does not exist")
	game.set("weather_phase", 0)
	game.call("_update_hud")
	game.set("stored_wood", 2)
	game.call("_update_hud")
	assert(opening_hud.text.contains("从储物箱取出全部 2 块木料"), "the opening objective should reflect that storage interaction retrieves all stored wood at once")
	game.set("stored_wood", 0)
	game.call("_update_hud")
	assert(game.get_node_or_null("ArkRoot/RaftBoardingGangplank") is StaticBody3D, "the starting raft should have a real collidable boarding gangplank")
	var sea := game.get_node_or_null("Sea") as MeshInstance3D
	var sea_mesh := sea.mesh as PlaneMesh if sea else null
	var sea_material := sea.material_override as ShaderMaterial if sea else null
	assert(sea_mesh != null and sea_mesh.size.is_equal_approx(Vector2(300.0, 300.0)) and sea_mesh.subdivide_width >= 64 and sea_mesh.subdivide_depth >= 64, "the expanded world ocean should cover the outer sea and remain suitable for gentle procedural swells")
	assert(game.get_node_or_null("JadeSailShoal") is StaticBody3D and game.get_node_or_null("JadeSailArk") is Node3D, "the fourth reachable shoal should contain the stranded luxury ark landmark")
	assert(game.get_node_or_null("SteamWreckIslet") is StaticBody3D and game.get_node_or_null("PressureWreck") is Node3D, "the outer mechanical islet should be reachable within the same continuous sea")
	var guest_cabin_blueprint_button := game.find_child("ArkGuestCabinBlueprintButton", true, false) as Button
	assert(guest_cabin_blueprint_button != null and guest_cabin_blueprint_button.disabled, "the guest-cabin blueprint should remain unavailable until the unique ark salvage is found")
	assert(sea_material != null and sea_material.shader != null and sea_material.shader.resource_path == "res://shaders/ark_ocean.gdshader", "the ocean should use the authored restrained stylized shader")
	assert(sea_material.get_shader_parameter("jade_sail_center").is_equal_approx(Vector2(-53.0, -45.0)) and sea_material.get_shader_parameter("steam_wreck_center").is_equal_approx(Vector2(92.0, 86.0)), "the ocean shoreline blend should include the later luxury-ark and pressure-wreck islands")
	assert(sea.get_node_or_null("CollisionShape3D") == null, "the decorative ocean surface must not introduce a new collision plane")
	if return_button != null:
		var return_connections: Array = return_button.pressed.get_connections()
		var return_callable: Callable = return_connections[0].get("callable", Callable()) if not return_connections.is_empty() else Callable()
		assert(return_callable.is_valid() and return_callable.get_method() == "_return_to_main_menu", "the return control should save and return through its actual handler")
	assert(int(game.get("wood")) == 1, "the player should begin with one plank")
	var starter_blueprints: Array = game.get("learned_blueprint_ids")
	assert(starter_blueprints.has("starter_shelter") and starter_blueprints.has("starter_home"), "starter building templates should be permanent learned knowledge rather than inventory items")
	var time_environment := game.get("weather_environment") as Environment
	var time_sun := game.get("sun_light") as DirectionalLight3D
	var period_ambient_colors: Array[Color] = []
	var period_sun_angles: Array[Vector3] = []
	var period_sky_colors: Array[Color] = []
	var period_lantern_energies: Array[float] = []
	var raft_lantern := game.get_node("ArkRoot/LanternMarker/RaftLanternLight") as OmniLight3D
	game.set("weather_phase", 2)
	for period in range(4):
		game.set("day_period", period)
		game.call("_set_weather_visuals")
		period_ambient_colors.append(time_environment.ambient_light_color)
		period_sun_angles.append(time_sun.rotation_degrees)
		period_sky_colors.append((game.get("sky_material") as ProceduralSkyMaterial).sky_top_color)
		period_lantern_energies.append(raft_lantern.light_energy)
	assert(period_ambient_colors[0] != period_ambient_colors[1] and period_ambient_colors[1] != period_ambient_colors[2] and period_ambient_colors[2] != period_ambient_colors[3], "morning, day, evening, and night should each have a distinct ambient-light mood")
	assert(period_sun_angles[0] != period_sun_angles[1] and period_sun_angles[1] != period_sun_angles[2] and period_sun_angles[2] != period_sun_angles[3], "sun position should follow the day period instead of remaining fixed")
	assert(period_sky_colors[0] != period_sky_colors[1] and period_sky_colors[1] != period_sky_colors[2] and period_sky_colors[2] != period_sky_colors[3], "the sky gradient should visibly change across the full day-night cycle")
	assert(period_lantern_energies[3] > period_lantern_energies[1], "the raft lantern should provide more warm light at night than during the day")
	game.set("day_period", 0)
	game.set("weather_phase", 0)
	game.call("_set_weather_visuals")
	var player: CharacterBody3D = game.get("player")
	var avatar := game.get("avatar_visual") as Node3D
	assert(avatar != null and avatar.get("skeleton") is Skeleton3D, "the player should use the skinned Emma 3D avatar")
	var resident_marker := game.get_node("residentMarker") as Node3D
	var resident_figure := (game.get("opening_coast") as RefCounted).call("visual_child", resident_marker, "TidekeeperFigure") as Node3D
	assert(resident_figure != null and resident_figure.get_node_or_null("Head") is MeshInstance3D, "the first resident should also have visible 3D volume")
	player.global_position = Vector3(-4.0, 1.1, 1.5)
	game.call("_update_interaction_hint")
	var interaction_hint := game.find_child("ArkInteractionHint", true, false) as Label
	var interaction_focus_ring := game.get_node_or_null("ArkInteractionFocusRing") as MeshInstance3D
	assert(interaction_hint != null and interaction_hint.visible and interaction_hint.text.contains("拾取漂木"), "coming within interaction range should reveal a clear contextual action prompt")
	assert(interaction_focus_ring != null and interaction_focus_ring.visible and interaction_focus_ring.global_position.x == -4.0 and interaction_focus_ring.global_position.z == 1.5, "the world-space focus ring should identify the same nearby driftwood as the contextual prompt")
	game.call("_interact")
	assert(not interaction_hint.visible or not interaction_hint.text.contains("拾取漂木"), "collecting the nearby resource should clear its stale interaction prompt")
	assert(not interaction_focus_ring.visible, "collecting a focused resource should clear its world-space focus ring")
	assert(int(game.get("wood")) == 3, "the nearby driftwood should be collectible")
	var early_events: Array = game.get("world_events")
	assert(_count_events(early_events, "resource_collected") == 1, "collecting a world resource should leave one factual event")
	assert(str((early_events[0].get("facts") as Dictionary).get("node_id", "")) == "DriftwoodNear", "the collection event should identify the actual source node")
	player.global_position = Vector3(9.0, 1.1, -4.0)
	game.call("_update_interaction_hint")
	var second_focus_target := game.find_child("DriftwoodShore", true, false) as Node3D
	assert(interaction_focus_ring.visible and interaction_focus_ring.global_position.x == second_focus_target.global_position.x and interaction_focus_ring.global_position.z == second_focus_target.global_position.z, "moving to another salvage point should move the ring to the new nearest target")
	game.call("_interact")
	assert(int(game.get("wood")) == 5, "the second visible driftwood pile should be collectible once")
	assert(_count_events(game.get("world_events"), "resource_collected") == 2, "each unique driftwood pile should produce exactly one collection event")
	player.global_position = Vector3(0.0, 1.1, 0.6)
	game.call("_interact")
	assert(not bool(game.get("shelter_built")), "interacting should not instantly place a shelter")
	game.call("_start_build")
	assert(not interaction_focus_ring.visible, "the interaction focus ring should hide while placement mode owns player input")
	assert(not bool(game.call("_try_place_shelter", Vector3(2.0, 0.12, 0.0))), "placement outside the raft should be rejected")
	assert(int(game.get("wood")) == 5, "an invalid placement must not spend materials")
	assert(bool(game.call("_try_place_shelter", Vector3(0.0, 0.12, 0.0))), "a valid raft position should accept the shelter")
	assert(bool(game.get("shelter_built")), "the shelter should be physically placed")
	game.call("_update_hud")
	assert(opening_hud.text.contains("棚屋已能随舟远行") and opening_hud.text.contains("可邀请岸上居民同行"), "building the first shelter should advance the HUD to mobile-home growth and optional resident invitation")
	assert(_count_events(game.get("world_events"), "shelter_built") == 1, "the shelter event should record the completed construction once")
	var shelter_event: Dictionary = (game.get("world_events") as Array)[2]
	assert(int((shelter_event.get("facts") as Dictionary).get("wood_spent", 0)) == 3, "construction history should preserve the actual material cost")
	assert(game.get_node_or_null("ArkRoot/BuiltShelter/Cot") != null and game.get_node_or_null("ArkRoot/BuiltShelter/Bedroll") != null, "a constructed shelter should include a visible usable cot")
	assert(game.get_node_or_null("ArkRoot/BuiltShelter/CabinFloorboards/FloorPlank0") != null and game.get_node_or_null("ArkRoot/BuiltShelter/CabinFloorboards/FloorPlank7") != null, "the shelter floor should read as laid planks rather than one featureless graybox")
	assert(game.get_node_or_null("ArkRoot/BuiltShelter/CabinFrameDetails/FramePost_1_1") != null and game.get_node_or_null("ArkRoot/BuiltShelter/CabinFrameDetails/EntranceCanvas") != null, "the shelter should visibly use timber framing and a patched entry awning")
	var shelter_lamp := game.get_node_or_null("ArkRoot/BuiltShelter/Lamp") as Node3D
	var lamp_glow := shelter_lamp.get_node_or_null("LampGlow") as OmniLight3D if shelter_lamp else null
	var lamp_glass := shelter_lamp.get_node_or_null("WarmGlass") as MeshInstance3D if shelter_lamp else null
	assert(lamp_glow != null and lamp_glow.light_energy > 0.0 and lamp_glass != null and (lamp_glass.material_override as StandardMaterial3D).emission_enabled, "the shelter lamp should be a glowing warm fixture, not a solid colored box")
	assert(game.get_node_or_null("ArkRoot/BuiltShelter/HearthPot/PotBody") != null and game.get_node_or_null("ArkRoot/BuiltShelter/Roof/RoofCanvasPatch") != null, "the living corner should include a shaped cooking pot and a visible repaired canvas patch")
	game.set("day_period", 3)
	game.call("_set_weather_visuals")
	var night_shelter_light := game.get_node("ArkRoot/BuiltShelter/WarmLight") as OmniLight3D
	assert(night_shelter_light.light_energy > 0.8, "the shelter should cast a strong warm pool of light at night")
	game.set("day_period", 0)
	game.call("_set_weather_visuals")
	game.call("_start_build")
	assert(str(game.get("build_type")) == "storage", "the next construction step should be a material storage box")
	assert(not bool(game.call("_try_place_storage", Vector3(0.0, 0.12, 0.0))), "the storage box should not overlap the shelter")
	assert(bool(game.call("_try_place_storage", Vector3(2.0, 0.12, -1.5))), "the raft should accept a second useful structure")
	assert(_count_events(game.get("world_events"), "storage_built") == 1, "the storage construction should enter the event ledger")
	assert(game.get_node_or_null("ArkRoot/BuiltStorage/Body") != null and game.get_node_or_null("ArkRoot/BuiltStorage/Lid") != null, "the storage box should be visible in the world")
	assert(str((game.get_node("ArkRoot/StorageInteractable/Name") as Label3D).text).contains("存取木料"), "the storage box should communicate its interaction affordance")
	assert(int(game.get("wood")) == 0, "building storage should spend its exact material cost")
	player.global_position = Vector3(19.0, 1.1, -5.5)
	game.call("_interact")
	assert(int(game.get("wood")) == 3, "the ridge salvage should reward a farther exploration trip")
	player.global_position = Vector3(2.0, 1.1, -1.5)
	game.call("_interact")
	assert(int(game.get("wood")) == 0 and int(game.get("stored_wood")) == 3, "the player should be able to bring expedition materials home and store them")
	var day_before_rest := int(game.get("day_count"))
	var period_before_rest := int(game.get("day_period"))
	player.global_position = Vector3(0.72, 1.1, 0.2)
	game.call("_interact")
	assert(int(game.get("day_period")) == (period_before_rest + 1) % 4, "using the cot should advance the persistent day period")
	assert(_count_events(game.get("world_events"), "time_advanced") == 1, "rest should record the time transition for future story conditions")
	assert(int(game.get("day_count")) == day_before_rest, "the day counter should advance only after the full day-night cycle")
	assert((game.get("message") as String).contains("睡了一觉"), "resting should produce a clear in-world response")
	player.global_position = Vector3(13.0, 1.1, -6.0)
	game.call("_interact")
	assert(bool(game.get("resident_met")), "the resident should be reachable and interactable")
	assert(not bool(game.get("traveler_boarded")), "meeting must not automatically recruit the traveler")
	game.call("_interact")
	assert(bool(game.get("traveler_choice_pending")), "boarding requires an explicit player choice after shelter is built")
	game.call("_choose_traveler_boarding", true)
	assert(bool(game.get("traveler_boarded")), "the traveler should board only after accepting the invitation")
	assert(_count_events(game.get("world_events"), "resident_invitation_decided") == 1, "the resident's explicit boarding choice should be recorded once")
	assert(str(game.get("traveler_action")) == "整理浮标箱", "the boarded traveler should follow her daytime routine even before the first storm")
	game.call("_process", 10.0)
	var traveler_marker: Node3D = game.get("traveler_marker")
	assert(traveler_marker.position.is_equal_approx(game.get("traveler_target_position")), "the traveler should physically move to her current activity")
	player.global_position = Vector3(0.0, 1.1, 0.6)
	game.call("_interact")
	assert(bool(game.get("preparation_choice_pending")), "the player should receive a storm-preparation choice")
	game.call("_choose_weather_preparation", "shelter")
	assert(not bool(game.get("rope_available")), "the single rope should be consumed by preparation")
	assert(str(game.get("rope_use")) == "shelter", "the selected preparation target should be recorded")
	game.call("_advance_weather")
	assert(int(game.get("weather_phase")) == 1, "the storm should begin only when the player advances time")
	assert(str(game.get("traveler_action")) == "棚下避雨", "the traveler should respond to the active storm by taking shelter")
	assert(not bool(game.get("raft_edge_damaged")), "the storm should not resolve in the middle of its active phase")
	game.call("_advance_weather")
	assert(int(game.get("weather_phase")) == 2, "the storm should resolve into the aftermath")
	assert(not bool(game.get("shelter_roof_damaged")), "a shelter secured with the rope should withstand the storm")
	assert(bool(game.get("raft_edge_damaged")), "the unprotected raft edge should show a repairable consequence")
	assert(str(game.get("traveler_action")) == "查看筏舷", "after the storm the traveler should inspect the actual damaged part")
	var storm_events: Array = game.get("world_events")
	assert(_count_events(storm_events, "storm_prepared") == 1 and _count_events(storm_events, "storm_started") == 1 and _count_events(storm_events, "storm_resolved") == 1, "the storm sequence should preserve preparation, onset, and outcome as distinct events")
	var storm_outcome: Dictionary = storm_events.back()
	assert(bool((storm_outcome.get("facts") as Dictionary).get("raft_damaged", false)), "the storm outcome event should reflect the actual damaged raft")
	game.queue_free()
	await process_frame
	var restored := packed.instantiate()
	restored.set("save_root_override", test_save_root)
	root.add_child(restored)
	await process_frame
	assert(int(restored.get("wood")) == 0 and int(restored.get("stored_wood")) == 3, "carried and stored materials should both reload")
	assert(bool(restored.get("shelter_built")), "placed construction should survive reload")
	assert(bool(restored.get("storage_built")) and restored.get_node_or_null("ArkRoot/BuiltStorage/Body") != null, "the storage construction should be reconstructed after reload")
	assert(int(restored.get("day_count")) == day_before_rest, "the day counter should survive reload")
	assert(int(restored.get("day_period")) == (period_before_rest + 1) % 4, "the current time period should survive reload")
	var restored_sun := restored.get("sun_light") as DirectionalLight3D
	assert(restored_sun.rotation_degrees.is_equal_approx(Vector3(-55.0, -28.0, 0.0)), "reloading should restore the sun angle for the saved daytime period")
	assert(bool(restored.get("resident_met")), "resident progress should survive reload")
	assert(bool(restored.get("traveler_boarded")), "the traveler's choice should survive reload")
	assert(restored.get_node_or_null("ArkRoot/BuiltShelter/Cot") != null, "the usable cot should be reconstructed after reload")
	assert(int(restored.get("weather_phase")) == 2, "weather progression should survive reload")
	assert(str(restored.get("rope_use")) == "shelter", "the one-time preparation choice should survive reload")
	assert(bool(restored.get("raft_edge_damaged")), "storm damage should survive reload")
	assert(str(restored.get("traveler_action")) == "查看筏舷", "the resident's contextual activity should be reconstructed from saved facts")
	assert((restored.get("collected_ids") as Array).has("DriftwoodNear") and (restored.get("collected_ids") as Array).has("DriftwoodRidge"), "collected objects should persist to prevent farming on reload")
	assert(_count_events(restored.get("world_events"), "storm_resolved") == 1 and _count_events(restored.get("world_events"), "resident_invitation_decided") == 1, "the storm and resident decisions should remain in the factual history after reload")
	var restored_player: CharacterBody3D = restored.get("player")
	var storm_reflection_traveler_marker := restored.get("traveler_marker") as Node3D
	assert(int((restored.get("last_resolved_storm_facts") as Dictionary).get("storm_number", 0)) == 1, "the last storm's grounded outcome facts should survive reload")
	restored_player.global_position = storm_reflection_traveler_marker.global_position
	restored.call("_interact")
	assert(_count_events(restored.get("world_events"), "resident_storm_reflection") == 1 and int(restored.get("tidekeeper_last_storm_reflection")) == 1, "the tidekeeper should reflect once on a saved storm outcome")
	var storm_reflection: Dictionary = (restored.get("world_events") as Array).back()
	assert(str(restored.get("message")).contains("棚顶") and str(restored.get("message")).contains("筏舷裂了一道口子") and str((storm_reflection.get("facts", {}) as Dictionary).get("rope_use", "")) == "shelter" and bool((storm_reflection.get("facts", {}) as Dictionary).get("raft_damaged", false)), "the reflection should name the actual preparation and damage rather than generic praise")
	restored_player.global_position = Vector3(2.0, 1.1, -1.5)
	restored.call("_interact")
	assert(int(restored.get("wood")) == 3 and int(restored.get("stored_wood")) == 0, "stored materials should be retrievable for repairs")
	restored_player.global_position = Vector3(0.0, 1.1, 0.6)
	restored.call("_interact")
	assert(bool(restored.get("repair_choice_pending")), "repair should be offered at home when wood remains")
	restored.call("_repair_damaged_part", "raft")
	assert(not bool(restored.get("raft_edge_damaged")), "the raft edge should be repairable")
	assert(_count_events(restored.get("world_events"), "structure_repaired") == 1, "repair should create a factual event instead of rewriting the storm outcome")
	assert(str(restored.get("traveler_action")) == "整理浮标箱", "the resident should return to her daytime routine after repairs")
	assert(int(restored.get("wood")) == 2, "repair should consume exactly one plank from the retrieved stock")
	var repaired_period := int(restored.get("day_period"))
	restored_player.global_position = Vector3(0.72, 1.1, 0.2)
	restored.call("_interact")
	assert(int(restored.get("day_period")) == (repaired_period + 1) % 4, "resting should move the world into the next time period")
	assert(str(restored.get("traveler_action")) == "照看灯火", "the resident should tend the lantern in the evening")
	restored.call("_interact")
	assert(str(restored.get("traveler_action")) == "棚下临时歇脚", "after the storm the resident should choose temporary refuge without claiming the player's cot")
	restored.call("_process", 10.0)
	assert((restored.get("traveler_marker") as Node3D).position.is_equal_approx(restored.get("traveler_target_position")), "the resident should walk to her temporary refuge point after the player rests")
	var night_count := int(restored.get("day_count"))
	restored.call("_interact")
	assert(int(restored.get("day_period")) == 0 and int(restored.get("day_count")) == night_count + 1, "sleeping through the night should begin a new morning and increment the day")
	assert(_count_events(restored.get("world_events"), "time_advanced") == 4, "each sleep transition should append one ordered time event")
	assert(int(restored.get("wood")) == 2, "the recovered stock should leave enough wood for one home upgrade")
	restored.call("_start_build")
	assert(str(restored.get("build_type")) == "workbench", "the third construction should unlock a home crafting station")
	assert(not bool(restored.call("_try_place_workbench", Vector3(0.0, 0.12, 0.0))), "the workbench should not overlap the shelter")
	assert(bool(restored.call("_try_place_workbench", Vector3(-2.0, 0.12, 1.5))), "the raft should accept the workbench in the remaining space")
	assert(_count_events(restored.get("world_events"), "workbench_built") == 1, "the workbench construction should enter the event ledger")
	assert(restored.get_node_or_null("ArkRoot/BuiltWorkbench/SpiritSocket") != null, "the workbench should be physically constructed")
	restored_player.global_position = Vector3(23.0, 1.1, -17.0)
	restored.call("_interact")
	assert(int(restored.get("ancient_parts")) == 1 and bool(restored.get("cold_exposure")), "the open ruin should provide a unique relic with a survival cost")
	restored_player.global_position = Vector3(-2.0, 1.1, 1.5)
	restored.call("_interact")
	assert(bool(restored.get("lantern_tuned")) and int(restored.get("ancient_parts")) == 0, "the home workbench should convert the relic into a persistent lantern upgrade")
	assert(_count_events(restored.get("world_events"), "lantern_tuned") == 1, "the actual lantern upgrade should be logged exactly once")
	assert(bool(restored.get("cold_exposure")), "crafting the upgrade should not instantly erase the expedition consequence")
	restored.call("_interact")
	assert(_count_events(restored.get("world_events"), "lantern_tuned") == 1, "re-inspecting an already tuned lantern must not duplicate the upgrade event")
	restored_player.global_position = Vector3(-2.15, 1.1, -0.9)
	restored.call("_physics_process", 1.0 / 60.0)
	assert(not bool(restored.get("cold_exposure")), "the tuned lantern should passively protect the home area from ruin chill")
	restored.queue_free()
	await process_frame
	var crafted_restored := packed.instantiate()
	crafted_restored.set("save_root_override", test_save_root)
	root.add_child(crafted_restored)
	await process_frame
	assert(bool(crafted_restored.get("workbench_built")) and bool(crafted_restored.get("lantern_tuned")), "the crafted structure and its gameplay upgrade should survive reload")
	assert(crafted_restored.get_node_or_null("ArkRoot/BuiltWorkbench/SpiritSocket") != null, "the crafted workbench should reconstruct after reload")
	var persisted_events: Array = crafted_restored.get("world_events")
	assert(_count_events(persisted_events, "ruin_searched") == 1 and _count_events(persisted_events, "lantern_tuned") == 1, "the expedition and home-upgrade facts should survive reload without duplication")
	var previous_sequence := 0
	for event in persisted_events:
		var sequence := int((event as Dictionary).get("sequence", 0))
		assert(sequence > previous_sequence, "persisted world events should remain strictly ordered")
		previous_sequence = sequence
	assert(int(crafted_restored.get("event_sequence")) == previous_sequence, "the event sequence should continue from the last saved event")
	var long_trip_player: CharacterBody3D = crafted_restored.get("player")
	long_trip_player.global_position = Vector3(39.0, 1.1, -29.0)
	crafted_restored.call("_interact")
	assert(int(crafted_restored.get("keel_beams")) == 1 and int(crafted_restored.get("wood")) == 4, "the open far reef should provide one keel and enough planks for the first visible ark expansion")
	assert(bool(crafted_restored.get("cold_exposure")), "the exposed reef salvage should carry a real survival cost")
	assert(_count_events(crafted_restored.get("world_events"), "keel_wreck_salvaged") == 1, "rare salvage should record its source and actual yield")
	assert(_count_events(crafted_restored.get("world_events"), "blueprint_discovered") == 1, "exploration should explicitly record the blueprint as a separate discovery")
	var learned_event: Dictionary = (crafted_restored.get("world_events") as Array).back()
	assert(bool((learned_event.get("facts", {}) as Dictionary).get("permanent_knowledge", false)), "finding a blueprint should directly add permanent knowledge, not a fragile inventory item")
	assert((crafted_restored.get("learned_blueprint_ids") as Array).has("keel_deck_expansion"), "exploring the wreck should permanently teach the expansion plan")
	var unlocked_blueprint_button := crafted_restored.find_child("ArkRaftExpansionBlueprintButton", true, false) as Button
	assert(unlocked_blueprint_button != null and not unlocked_blueprint_button.disabled and unlocked_blueprint_button.text.contains("已学会"), "the found exploration blueprint should become visibly available")
	var blueprint_save_restore := packed.instantiate()
	blueprint_save_restore.set("save_root_override", test_save_root)
	root.add_child(blueprint_save_restore)
	await process_frame
	var restored_blueprint_button := blueprint_save_restore.find_child("ArkRaftExpansionBlueprintButton", true, false) as Button
	assert(bool(blueprint_save_restore.get("keel_wreck_searched")) and restored_blueprint_button != null and not restored_blueprint_button.disabled, "the exploration blueprint should remain unlocked after loading the pre-construction save")
	assert((blueprint_save_restore.get("learned_blueprint_ids") as Array).has("keel_deck_expansion"), "learned plans should survive a save/reload independently of wreck state")
	blueprint_save_restore.queue_free()
	await process_frame
	var legacy_blueprint_save_root := ProjectSettings.globalize_path("res://../.local/test_save_legacy_blueprint").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(legacy_blueprint_save_root), "test saves must be isolated in this repository; Windows saves must remain on D:")
	var legacy_blueprint_save_helper := preload("res://scripts/ark_greybox_save.gd").new(legacy_blueprint_save_root)
	legacy_blueprint_save_helper.clear_for_test()
	var legacy_blueprint_state: Dictionary = crafted_restored.call("_build_save_state")
	legacy_blueprint_state["schema_version"] = 12
	legacy_blueprint_state.erase("learned_blueprint_ids")
	assert(bool(legacy_blueprint_save_helper.save_state(legacy_blueprint_state).get("ok", false)), "a schema 12 save should be prepared for blueprint migration coverage")
	var migrated_blueprint_game := packed.instantiate()
	migrated_blueprint_game.set("save_root_override", legacy_blueprint_save_root)
	root.add_child(migrated_blueprint_game)
	await process_frame
	assert((migrated_blueprint_game.get("learned_blueprint_ids") as Array).has("keel_deck_expansion"), "legacy exploration unlocks should migrate into the learned plan book")
	migrated_blueprint_game.queue_free()
	await process_frame
	legacy_blueprint_save_helper.clear_for_test()
	crafted_restored.call("_interact")
	assert(int(crafted_restored.get("keel_beams")) == 1 and int(crafted_restored.get("wood")) == 4, "the wreck must not allow repeat farming")
	unlocked_blueprint_button.pressed.emit()
	assert(str(crafted_restored.get("build_type")) == "raft_extension", "the collected expansion blueprint should start the structural ark upgrade preview")
	assert(not bool(crafted_restored.call("_try_place_raft_extension", Vector3(0.0, 0.12, -3.0))), "the extension should reject a placement that does not join the raft bow")
	assert(int(crafted_restored.get("wood")) == 4 and int(crafted_restored.get("keel_beams")) == 1, "an invalid extension placement must not consume expedition materials")
	assert(bool(crafted_restored.call("_try_place_raft_extension", Vector3(0.0, 0.12, -4.2))), "the recovered keel should let the player add a real deck extension")
	assert(int(crafted_restored.get("wood")) == 0 and int(crafted_restored.get("keel_beams")) == 0, "the visible extension must consume its exact wood and keel costs")
	assert(crafted_restored.get_node_or_null("ArkRoot/BuiltRaftExtension/Deck") != null, "the ark should visibly gain a walkable extension deck")
	assert(_count_events(crafted_restored.get("world_events"), "raft_extension_built") == 1, "the home expansion should record its cost and salvage origin")
	var upgraded_bow := crafted_restored.get_node("ArkRoot/RaftBow") as StaticBody3D
	assert(upgraded_bow.get_child(1) is CollisionShape3D and (upgraded_bow.get_child(1) as CollisionShape3D).shape is BoxShape3D, "the upgraded bow must retain a solid collision rail")
	crafted_restored.queue_free()
	await process_frame
	var expanded_restored := packed.instantiate()
	expanded_restored.set("save_root_override", test_save_root)
	root.add_child(expanded_restored)
	await process_frame
	assert(bool(expanded_restored.get("raft_extension_built")) and expanded_restored.get_node_or_null("ArkRoot/BuiltRaftExtension/Deck") != null, "the expanded ark and its deck geometry should survive reload")
	assert(expanded_restored.get_node_or_null("ArkRoot/BuiltRaftExtension/Berth/Bedroll") != null and expanded_restored.get_node_or_null("ArkRoot/BuiltRaftExtension/Berth/CanvasAwning") != null, "the learned keel-deck template should create a visible, sheltered resident berth rather than an empty platform")
	assert(int(expanded_restored.get("wood")) == 0 and int(expanded_restored.get("keel_beams")) == 0, "reloading should not refund expansion materials")
	assert(bool(expanded_restored.get("keel_wreck_searched")) and expanded_restored.get_node_or_null("KeelWreck/SalvageBeam") == null, "the exhausted far-reef wreck should remain visibly exhausted after reload")
	assert((expanded_restored.get("learned_blueprint_ids") as Array).has("keel_deck_expansion"), "building from a learned plan must not consume the permanent blueprint knowledge")
	var completed_blueprint_button := expanded_restored.find_child("ArkRaftExpansionBlueprintButton", true, false) as Button
	assert(completed_blueprint_button != null and completed_blueprint_button.disabled, "a completed template should leave the blueprint visible but no longer buildable")
	assert(_count_events(expanded_restored.get("world_events"), "keel_wreck_salvaged") == 1 and _count_events(expanded_restored.get("world_events"), "raft_extension_built") == 1, "the exploration-to-home-growth causal history should survive reload")
	expanded_restored.call("_abort_resident_gathering", "test_resident_idle_for_night_schedule")
	expanded_restored.set("day_period", 3)
	expanded_restored.call("_update_traveler_schedule")
	var night_berth_target: Vector3 = expanded_restored.get("traveler_target_position")
	assert(str(expanded_restored.get("traveler_action")) == "甲板铺位歇息" and night_berth_target.is_equal_approx(Vector3(0.95, 0.24, -5.35)), "the tidekeeper should choose the new berth as her night destination after the ark grows")
	for _step in range(20):
		expanded_restored.call("_process", 1.0)
	assert((expanded_restored.get("traveler_marker") as Node3D).position.is_equal_approx(expanded_restored.get("traveler_target_position")), "the resident should physically walk to the expanded-deck berth at night")
	expanded_restored.set("sailing_mode", true)
	assert(not bool(expanded_restored.call("_dismantle_raft_extension")) and bool(expanded_restored.get("raft_extension_built")) and int(expanded_restored.get("wood")) == 0 and int(expanded_restored.get("keel_beams")) == 0, "dismantling must be rejected during active navigation without changing materials or structure")
	expanded_restored.set("sailing_mode", false)
	var extension_player := expanded_restored.get("player") as CharacterBody3D
	var extension_marker := expanded_restored.get_node("ArkRoot/RaftExtensionInteractable") as Node3D
	extension_player.global_position = extension_marker.global_position
	expanded_restored.call("_interact")
	assert(bool(expanded_restored.get("raft_extension_dismantle_pending")), "the installed deck should expose an explicit dismantle confirmation at its management marker")
	var confirm_dismantle_key := InputEventKey.new()
	confirm_dismantle_key.pressed = true
	confirm_dismantle_key.keycode = KEY_1
	expanded_restored.call("_unhandled_key_input", confirm_dismantle_key)
	await process_frame
	assert(not bool(expanded_restored.get("raft_extension_built")) and expanded_restored.get_node_or_null("ArkRoot/BuiltRaftExtension") == null, "confirming dismantle should remove the extension geometry and construction state")
	assert(str(expanded_restored.get("traveler_action")) == "棚下临时歇脚", "dismantling optional accommodation should return the resident to temporary refuge, not the player's cot")
	assert(int(expanded_restored.get("wood")) == 4 and int(expanded_restored.get("keel_beams")) == 1 and (expanded_restored.get("learned_blueprint_ids") as Array).has("keel_deck_expansion"), "dismantle should return the exact materials without consuming permanent blueprint knowledge")
	var restored_bow_rail := expanded_restored.get_node("ArkRoot/RaftBow") as StaticBody3D
	var restored_bow_collision := restored_bow_rail.get_child(1) as CollisionShape3D
	assert(restored_bow_rail.position.is_equal_approx(Vector3(0, 0.35, -2.2)) and (restored_bow_collision.shape as BoxShape3D).size.is_equal_approx(Vector3(5.2, 0.45, 0.16)), "dismantle should restore both original bow-rail transform and collision bounds")
	var restored_port_rail := expanded_restored.get_node("ArkRoot/RaftPort") as StaticBody3D
	var restored_starboard_rail := expanded_restored.get_node("ArkRoot/RaftStarboard") as StaticBody3D
	assert(restored_port_rail.position.is_equal_approx(Vector3(-2.95, 0.35, 0.0)) and ((restored_port_rail.get_child(1) as CollisionShape3D).shape as BoxShape3D).size.is_equal_approx(Vector3(0.16, 0.45, 4.3)), "dismantle should restore the original port rail geometry and collision")
	assert(restored_starboard_rail.position.is_equal_approx(Vector3(2.95, 0.35, 0.0)) and ((restored_starboard_rail.get_child(1) as CollisionShape3D).shape as BoxShape3D).size.is_equal_approx(Vector3(0.16, 0.45, 4.3)), "dismantle should restore the original starboard rail geometry and collision")
	var player_after_dismantle_local: Vector3 = (expanded_restored.get_node("ArkRoot") as Node3D).to_local(extension_player.global_position)
	assert(absf(player_after_dismantle_local.x) < 2.8 and player_after_dismantle_local.z > -2.0 and player_after_dismantle_local.z < 2.0, "dismantling should move the player back onto supported original deck")
	assert(bool(expanded_restored.get("keel_wreck_searched")) and _count_events(expanded_restored.get("world_events"), "keel_wreck_salvaged") == 1 and _count_events(expanded_restored.get("world_events"), "raft_extension_dismantled") == 1, "rebuilding access must not duplicate one-time reef salvage and should preserve a factual dismantle event")
	expanded_restored.queue_free()
	await process_frame
	var dismantled_restored := packed.instantiate()
	dismantled_restored.set("save_root_override", test_save_root)
	root.add_child(dismantled_restored)
	await process_frame
	assert(not bool(dismantled_restored.get("raft_extension_built")) and dismantled_restored.get_node_or_null("ArkRoot/BuiltRaftExtension") == null and int(dismantled_restored.get("wood")) == 4 and int(dismantled_restored.get("keel_beams")) == 1, "the dismantled home and returned materials should survive reload without reconstructing the removed deck")
	assert(not bool((dismantled_restored.find_child("ArkRaftExpansionBlueprintButton", true, false) as Button).disabled) and _count_events(dismantled_restored.get("world_events"), "raft_extension_dismantled") == 1, "the permanent plan should be buildable again after reload, with the dismantle event preserved")
	var rebuild_button := dismantled_restored.find_child("ArkRaftExpansionBlueprintButton", true, false) as Button
	rebuild_button.pressed.emit()
	assert(bool(dismantled_restored.call("_try_place_raft_extension", Vector3(0.0, 0.12, -4.2))), "the learned plan should rebuild the salvaged structure after dismantling and reloading")
	assert(int(dismantled_restored.get("wood")) == 0 and int(dismantled_restored.get("keel_beams")) == 0 and _count_events(dismantled_restored.get("world_events"), "raft_extension_built") == 2, "rebuilding should charge exact materials and append a second construction event instead of rewriting history")
	dismantled_restored.queue_free()
	await process_frame
	var rebuilt_restored := packed.instantiate()
	rebuilt_restored.set("save_root_override", test_save_root)
	root.add_child(rebuilt_restored)
	await process_frame
	assert(bool(rebuilt_restored.get("raft_extension_built")) and rebuilt_restored.get_node_or_null("ArkRoot/BuiltRaftExtension/Deck") != null and _count_events(rebuilt_restored.get("world_events"), "raft_extension_built") == 2 and _count_events(rebuilt_restored.get("world_events"), "raft_extension_dismantled") == 1, "the rebuilt structure and chronological build-dismantle-build history should survive another reload")
	rebuilt_restored.queue_free()
	await process_frame
	save_helper.clear_for_test()
	var alternate_save_root := ProjectSettings.globalize_path("res://../.local/test_save_alternate").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(alternate_save_root), "test saves must be isolated in this repository; Windows saves must remain on D:")
	var alternate_save_helper := preload("res://scripts/ark_greybox_save.gd").new(alternate_save_root)
	alternate_save_helper.clear_for_test()
	var alternate := packed.instantiate()
	alternate.set("save_root_override", alternate_save_root)
	root.add_child(alternate)
	await process_frame
	var alternate_player: CharacterBody3D = alternate.get("player")
	alternate_player.global_position = Vector3(-4.0, 1.1, 1.5)
	alternate.call("_interact")
	alternate_player.global_position = Vector3(9.0, 1.1, -4.0)
	alternate.call("_interact")
	var alternate_shelter_position := Vector3(0.5, 0.12, 0.5)
	assert(bool(alternate.call("_try_place_shelter", alternate_shelter_position)), "free construction should allow a safe off-center shelter placement")
	assert((alternate.get_node("ArkRoot/BuiltShelter") as Node3D).position.is_equal_approx(alternate_shelter_position), "the constructed shelter should occupy the player's chosen safe deck position")
	alternate_player.global_position = Vector3(13.0, 1.1, -6.0)
	alternate.call("_interact")
	alternate.call("_interact")
	alternate.call("_choose_traveler_boarding", false)
	assert(not bool(alternate.get("traveler_boarded")), "declining to board should leave the traveler independent")
	assert(bool(alternate.get("safe_channel_marked")), "declining should create an actual safe-channel marker")
	assert(alternate.get_node_or_null("SafeChannelMark") != null, "the safe-channel marker should exist in the world")
	alternate.call("_interact_home")
	alternate.call("_choose_weather_preparation", "raft")
	alternate.call("_advance_weather")
	alternate.call("_advance_weather")
	assert(not bool(alternate.get("raft_edge_damaged")), "tying the raft should protect it")
	assert(bool(alternate.get("shelter_roof_damaged")), "the unprotected shelter roof should have a visible repairable consequence")
	var damaged_roof := alternate.get_node("ArkRoot/BuiltShelter/Roof") as Node3D
	assert(not damaged_roof.visible, "the storm consequence should be visible in the world, not only in a status value")
	alternate.queue_free()
	await process_frame
	var alternate_restored := packed.instantiate()
	alternate_restored.set("save_root_override", alternate_save_root)
	root.add_child(alternate_restored)
	await process_frame
	assert(bool(alternate_restored.get("safe_channel_marked")), "the declined route's world change should survive reload")
	assert((alternate_restored.get("shelter_position") as Vector3).is_equal_approx(alternate_shelter_position), "a freely placed shelter should preserve its chosen position in the save")
	assert(alternate_restored.get_node_or_null("SafeChannelMark") != null, "the saved marker should be reconstructed in the world")
	alternate_restored.queue_free()
	await process_frame
	alternate_save_helper.clear_for_test()
	var ruin_save_root := ProjectSettings.globalize_path("res://../.local/test_save_ruin").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(ruin_save_root), "test saves must be isolated in this repository; Windows saves must remain on D:")
	var ruin_save_helper := preload("res://scripts/ark_greybox_save.gd").new(ruin_save_root)
	ruin_save_helper.clear_for_test()
	var explorer := packed.instantiate()
	explorer.set("save_root_override", ruin_save_root)
	root.add_child(explorer)
	await process_frame
	var explorer_player: CharacterBody3D = explorer.get("player")
	explorer_player.global_position = Vector3(23.0, 1.1, -17.0)
	explorer.call("_interact")
	assert(bool(explorer.get("ruin_searched")), "the ruin should be reachable without a quest or level gate")
	assert(int(explorer.get("ancient_parts")) == 1, "the ruin should yield one unique ancient part")
	assert(bool(explorer.get("cold_exposure")), "salvaging the ruin should expose the explorer to cold")
	var cold_speed := float(explorer.call("_current_walk_speed"))
	assert(cold_speed < float(explorer.get("WALK_SPEED")), "cold should have a direct movement consequence")
	explorer.call("_interact")
	assert(int(explorer.get("ancient_parts")) == 1, "the ruin should not allow repeat farming")
	assert(_count_events(explorer.get("world_events"), "ruin_searched") == 1, "revisiting a searched ruin must not duplicate its discovery event")
	var chart: Control = explorer.get("world_chart")
	assert(chart != null and not chart.visible, "the world chart should be available without covering the exploration view by default")
	explorer.call("_toggle_world_chart")
	await process_frame
	assert(chart.visible, "the player should be able to open the chart without entering a separate level")
	var charted_position: Vector3 = explorer_player.global_position
	explorer_player.velocity = Vector3(4.0, 0.0, 0.0)
	explorer.call("_physics_process", 0.25)
	assert(explorer_player.velocity.is_zero_approx() and explorer_player.global_position.is_equal_approx(charted_position), "opening the chart should hold the player in place while the destination is considered")
	var far_reef_point: Vector2 = chart.call("_world_to_map", Vector3(39.0, 0.04, -29.0))
	var map_click := InputEventMouseButton.new()
	map_click.button_index = MOUSE_BUTTON_LEFT
	map_click.pressed = true
	map_click.position = far_reef_point
	chart.call("_gui_input", map_click)
	assert(explorer_player.global_position.is_equal_approx(charted_position), "selecting a destination on the chart must never teleport the player")
	var chart_events: Array = explorer.get("world_events")
	assert(str(chart_events.back().get("id", "")) == "chart_destination_considered", "choosing a chart marker should record intent, not a completed journey")
	assert(str((chart_events.back().get("facts", {}) as Dictionary).get("destination_id", "")) == "far_reef", "the chart event should preserve which unrestricted destination the player considered")
	explorer.call("_toggle_world_chart")
	assert(not chart.visible, "the map shortcut should close the chart and return to uninterrupted movement")
	explorer.queue_free()
	await process_frame
	var warmed_explorer := packed.instantiate()
	warmed_explorer.set("save_root_override", ruin_save_root)
	root.add_child(warmed_explorer)
	await process_frame
	assert(bool(warmed_explorer.get("ruin_searched")), "ruin progress should persist after reloading")
	assert(bool(warmed_explorer.get("cold_exposure")), "cold exposure should persist after reloading")
	assert(int(warmed_explorer.get("ancient_parts")) == 1, "the unique salvage should persist after reloading")
	var warmed_player: CharacterBody3D = warmed_explorer.get("player")
	warmed_player.global_position = Vector3(-2.15, 1.1, -0.9)
	warmed_explorer.call("_interact")
	assert(not bool(warmed_explorer.get("cold_exposure")), "returning to the old lantern should restore warmth")
	assert(is_equal_approx(float(warmed_explorer.call("_current_walk_speed")), float(warmed_explorer.get("WALK_SPEED"))), "warming should restore normal movement speed")
	warmed_player.global_position = Vector3(30.0, -1.8, 20.0)
	warmed_player.velocity.y = -1.0
	warmed_explorer.call("_physics_process", 1.0 / 60.0)
	assert(bool(warmed_explorer.get("is_swimming")), "falling off the raft or shore should enter swim movement rather than falling into the void")
	assert(absf(warmed_player.global_position.y - (float(warmed_explorer.get("water").query(warmed_player.global_position).height) - 0.45)) < 0.002, "the water surface should keep the player afloat")
	assert((warmed_explorer.get("hud") as Label).text.contains("游泳"), "the HUD should reflect entering the water")
	warmed_explorer.call("_jump_player")
	assert(not bool(warmed_explorer.get("is_swimming")), "a swim stroke should transition into an upward climb")
	warmed_explorer.call("_physics_process", 0.1)
	assert(warmed_player.global_position.y > float(warmed_explorer.get("WATER_FLOAT_ROOT_Y")), "a swim stroke should let the player climb toward a nearby shore")
	warmed_explorer.queue_free()
	await process_frame
	ruin_save_helper.clear_for_test()
	var resident_job_root := ProjectSettings.globalize_path("res://../.local/test_save_resident_job").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(resident_job_root), "test saves must be isolated in this repository; Windows saves must remain on D:")
	var resident_job_save := preload("res://scripts/ark_greybox_save.gd").new(resident_job_root)
	resident_job_save.clear_for_test()
	var resident_job_game := packed.instantiate()
	resident_job_game.set("save_root_override", resident_job_root)
	root.add_child(resident_job_game)
	await process_frame
	var resident_job_player: CharacterBody3D = resident_job_game.get("player")
	resident_job_player.global_position = Vector3(-4.0, 1.1, 1.5)
	resident_job_game.call("_interact")
	resident_job_player.global_position = Vector3(9.0, 1.1, -4.0)
	resident_job_game.call("_interact")
	assert(bool(resident_job_game.call("_try_place_shelter", Vector3.ZERO)), "the resident-job fixture should build the first shelter")
	assert(bool(resident_job_game.call("_try_place_storage", Vector3(2.0, 0.12, -1.5))), "the resident-job fixture should build storage")
	resident_job_player.global_position = Vector3(19.0, 1.1, -5.5)
	resident_job_game.call("_interact")
	resident_job_player.global_position = Vector3(2.0, 1.1, -1.5)
	resident_job_game.call("_interact")
	assert(int(resident_job_game.get("stored_wood")) == 3, "the resident should have a real stored-material reserve to work from")
	resident_job_player.global_position = Vector3(13.0, 1.1, -6.0)
	resident_job_game.call("_interact")
	resident_job_game.call("_interact")
	resident_job_game.call("_choose_traveler_boarding", true)
	resident_job_player.global_position = Vector3(0.0, 1.1, 0.6)
	resident_job_game.call("_interact")
	resident_job_game.call("_choose_weather_preparation", "shelter")
	resident_job_game.call("_advance_weather")
	resident_job_game.call("_advance_weather")
	var job_marker: Node3D = resident_job_game.get("traveler_marker")
	resident_job_player.global_position = job_marker.global_position + Vector3(0.0, 1.0, 0.0)
	resident_job_game.call("_interact")
	assert(_count_events(resident_job_game.get("world_events"), "resident_storm_reflection") == 1, "the resident should remember the resolved storm before offering new work")
	resident_job_game.call("_interact")
	assert(bool(resident_job_game.get("resident_repair_choice_pending")), "the resident should offer labor when a repair, a home reserve, and consent are all present")
	resident_job_game.call("_choose_resident_repair", true)
	assert(bool(resident_job_game.get("resident_repair_pending")) and int(resident_job_game.get("stored_wood")) == 2, "accepting the job should reserve exactly one stored plank")
	assert(str(resident_job_game.get("traveler_action")) == "修补筏舷", "the resident should visibly take a repair destination")
	assert(_count_events(resident_job_game.get("world_events"), "resident_repair_started") == 1, "the accepted labor should be recorded as an event")
	resident_job_game.queue_free()
	await process_frame
	var resident_job_restored := packed.instantiate()
	resident_job_restored.set("save_root_override", resident_job_root)
	root.add_child(resident_job_restored)
	await process_frame
	assert(bool(resident_job_restored.get("resident_repair_pending")) and str(resident_job_restored.get("resident_repair_part")) == "raft_edge", "an in-progress resident job should survive reload")
	assert(int(resident_job_restored.get("stored_wood")) == 2, "reloading should not restore the wood already reserved for the job")
	assert(_count_events(resident_job_restored.get("world_events"), "resident_repair_started") == 1, "reloading must not duplicate the accepted task event")
	var resident_job_restored_player: CharacterBody3D = resident_job_restored.get("player")
	resident_job_restored_player.global_position = Vector3(0.72, 1.1, 0.2)
	resident_job_restored.call("_interact")
	assert(bool(resident_job_restored.get("resident_repair_pending")) and bool(resident_job_restored.get("raft_edge_damaged")), "time alone should not complete repair before the resident reaches the damage")
	resident_job_restored.call("_process", 10.0)
	assert((resident_job_restored.get("traveler_marker") as Node3D).position.is_equal_approx(resident_job_restored.get("traveler_target_position")), "the resident should walk to the actual repair site")
	resident_job_restored.call("_interact")
	await process_frame
	assert(not bool(resident_job_restored.get("resident_repair_pending")) and not bool(resident_job_restored.get("raft_edge_damaged")), "the resident should repair the raft after reaching the work site and spending a time period")
	assert(resident_job_restored.get_node_or_null("ArkRoot/RaftDamageMark") == null, "resident repair should remove the visible damage marker")
	assert(_count_events(resident_job_restored.get("world_events"), "resident_repair_completed") == 1, "completed resident labor should be recorded exactly once")
	assert(int(resident_job_restored.get("stored_wood")) == 2, "the resident repair should retain its one-plank cost after completion")
	resident_job_restored.queue_free()
	await process_frame
	resident_job_save.clear_for_test()
	var legacy_save_root := ProjectSettings.globalize_path("res://../.local/test_save_legacy_events").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(legacy_save_root), "test saves must be isolated in this repository; Windows saves must remain on D:")
	var legacy_save_helper := preload("res://scripts/ark_greybox_save.gd").new(legacy_save_root)
	legacy_save_helper.clear_for_test()
	var legacy_result: Dictionary = legacy_save_helper.save_state({"schema_version": 7, "resident_met": true, "shelter_built": true, "wood": 2})
	assert(bool(legacy_result.get("ok", false)), "a valid previous-version save should be written for migration coverage")
	var legacy_restored := packed.instantiate()
	legacy_restored.set("save_root_override", legacy_save_root)
	root.add_child(legacy_restored)
	await process_frame
	assert(bool(legacy_restored.get("resident_met")) and bool(legacy_restored.get("shelter_built")), "the prior save's world state should still load")
	assert((legacy_restored.get("world_events") as Array).is_empty(), "migration must not invent a history for events that were never recorded")
	assert(int(legacy_restored.get("event_sequence")) == 0, "legacy saves should begin a new factual event sequence")
	legacy_restored.queue_free()
	await process_frame
	legacy_save_helper.clear_for_test()
	var previous_schema_root := ProjectSettings.globalize_path("res://../.local/test_save_schema9").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(previous_schema_root), "test saves must be isolated in this repository; Windows saves must remain on D:")
	var previous_schema_save := preload("res://scripts/ark_greybox_save.gd").new(previous_schema_root)
	previous_schema_save.clear_for_test()
	var previous_schema_result: Dictionary = previous_schema_save.save_state({"schema_version": 9, "shelter_built": true, "wood": 2, "world_events": []})
	assert(bool(previous_schema_result.get("ok", false)), "the immediate prior save schema should be available for migration coverage")
	var previous_schema_restored := packed.instantiate()
	previous_schema_restored.set("save_root_override", previous_schema_root)
	root.add_child(previous_schema_restored)
	await process_frame
	assert(bool(previous_schema_restored.get("shelter_built")) and int(previous_schema_restored.get("wood")) == 2, "schema 9 progress should load unchanged")
	assert(int(previous_schema_restored.get("keel_beams")) == 0 and not bool(previous_schema_restored.get("keel_wreck_searched")) and not bool(previous_schema_restored.get("raft_extension_built")), "schema 9 saves must not invent new reef salvage or an ark extension")
	previous_schema_restored.queue_free()
	await process_frame
	previous_schema_save.clear_for_test()
	var template_save_root := ProjectSettings.globalize_path("res://../.local/test_save_template").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(template_save_root), "test saves must be isolated in this repository; Windows saves must remain on D:")
	var template_save := preload("res://scripts/ark_greybox_save.gd").new(template_save_root)
	template_save.clear_for_test()
	var template_game := packed.instantiate()
	template_game.set("save_root_override", template_save_root)
	root.add_child(template_game)
	await process_frame
	template_game.set("wood", 5)
	var template_button := template_game.find_child("ArkStarterHomeTemplateButton", true, false) as Button
	var basic_template_button := template_game.find_child("ArkBasicShelterTemplateButton", true, false) as Button
	var free_build_button := template_game.find_child("ArkFreeBuildButton", true, false) as Button
	assert(basic_template_button != null and template_button != null and free_build_button != null, "two starter templates and free-build should all be visible in the HUD")
	template_button.pressed.emit()
	assert(bool(template_game.get("building_mode")) and str(template_game.get("build_type")) == "starter_home_template", "the one-click starter-home template should enter its own placement preview mode")
	free_build_button.pressed.emit()
	await process_frame
	assert(str(template_game.get("build_type")) == "shelter" and template_game.find_child("StarterHomeTemplatePreview", true, false) == null, "switching to free construction should cleanly replace the active template preview")
	template_game.call("_cancel_build", false)
	template_button.pressed.emit()
	assert(template_game.get_node_or_null("ArkRoot/StarterHomeTemplatePreview/Storage") is MeshInstance3D, "the template preview should show the bundled storage location")
	assert(not bool(template_game.call("_try_place_starter_home_template", Vector3(2.0, 0.12, 0.0))), "the complete home template must reject a footprint outside the raft")
	assert(int(template_game.get("wood")) == 5, "a rejected template placement must not consume resources")
	assert(bool(template_game.call("_try_place_starter_home_template", Vector3(0.0, 0.12, 0.0))), "the starter-home template should place its full checked layout")
	assert(int(template_game.get("wood")) == 0 and bool(template_game.get("shelter_built")) and bool(template_game.get("storage_built")), "the template should charge the exact combined cost and create both structures")
	assert(template_game.get_node_or_null("ArkRoot/BuiltShelter/Cot") != null and template_game.get_node_or_null("ArkRoot/BuiltStorage/Body") != null, "the completed template should create usable shelter and storage, not a cosmetic stamp")
	assert(_count_events(template_game.get("world_events"), "shelter_built") == 1 and _count_events(template_game.get("world_events"), "storage_built") == 1, "bundled template placement should retain ordinary factual build events")
	template_game.queue_free()
	await process_frame
	var template_restored := packed.instantiate()
	template_restored.set("save_root_override", template_save_root)
	root.add_child(template_restored)
	await process_frame
	assert(bool(template_restored.get("shelter_built")) and bool(template_restored.get("storage_built")) and int(template_restored.get("wood")) == 0, "the bundled home layout and exact remaining resources should survive a save reload")
	assert(template_restored.get_node_or_null("ArkRoot/BuiltShelter/Cot") != null and template_restored.get_node_or_null("ArkRoot/BuiltStorage/Body") != null, "both template structures should be reconstructed from the ordinary save fields")
	template_restored.queue_free()
	await process_frame
	template_save.clear_for_test()
	var basic_template_save_root := ProjectSettings.globalize_path("res://../.local/test_save_basic_template").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(basic_template_save_root), "test saves must be isolated in this repository; Windows saves must remain on D:")
	var basic_template_save := preload("res://scripts/ark_greybox_save.gd").new(basic_template_save_root)
	basic_template_save.clear_for_test()
	var basic_template_game := packed.instantiate()
	basic_template_game.set("save_root_override", basic_template_save_root)
	root.add_child(basic_template_game)
	await process_frame
	basic_template_game.set("wood", 3)
	var basic_template_game_button := basic_template_game.find_child("ArkBasicShelterTemplateButton", true, false) as Button
	assert(basic_template_game_button != null, "the basic shelter blueprint should be available as a visible HUD choice")
	basic_template_game_button.pressed.emit()
	assert(basic_template_game.find_child("BasicShelterTemplatePreview", true, false) is Node3D, "the basic shelter blueprint should preview a full preplanned structure")
	assert(bool(basic_template_game.call("_try_place_shelter", Vector3.ZERO)), "the basic shelter blueprint should construct using the regular shelter rule")
	assert(int(basic_template_game.get("wood")) == 0 and not bool(basic_template_game.get("storage_built")), "the basic blueprint should charge only its advertised material and remain distinct from the bundled home")
	basic_template_game.queue_free()
	await process_frame
	basic_template_save.clear_for_test()
	var meal_save_root := ProjectSettings.globalize_path("res://../.local/test_save_meals").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(meal_save_root), "test saves must be isolated in this repository; Windows saves must remain on D:")
	var meal_save := preload("res://scripts/ark_greybox_save.gd").new(meal_save_root)
	meal_save.clear_for_test()
	var meal_game := packed.instantiate()
	meal_game.set("save_root_override", meal_save_root)
	root.add_child(meal_game)
	await process_frame
	var meal_player: CharacterBody3D = meal_game.get("player")
	meal_player.global_position = Vector3(8.4, 1.1, -6.1)
	meal_game.call("_interact")
	assert(int(meal_game.get("raw_shellfish")) == 1, "a real shoreline forage should provide one shellfish ingredient")
	assert(_count_events(meal_game.get("world_events"), "resource_collected") == 1, "foraged food should enter the factual resource ledger")
	meal_game.set("wood", 3)
	assert(bool(meal_game.call("_try_place_shelter", Vector3.ZERO)), "a cooking hearth should become available with the starter shelter")
	assert(meal_game.get_node_or_null("ArkRoot/BuiltShelter/HearthPot") != null and meal_game.get_node_or_null("ArkRoot/HearthInteractable") != null, "the shelter should visibly provide an actual cooking point")
	meal_player.global_position = Vector3(-1.05, 1.1, -0.75)
	meal_game.call("_interact")
	assert(int(meal_game.get("raw_shellfish")) == 0 and int(meal_game.get("stew_servings")) == 1, "using the hearth should consume one ingredient and produce a real serving")
	assert(_count_events(meal_game.get("world_events"), "meal_prepared") == 1, "cooking should record its recipe and material cost")
	meal_player.global_position = Vector3(13.0, 1.1, -6.0)
	meal_game.call("_interact")
	meal_game.call("_interact")
	meal_game.call("_choose_traveler_boarding", true)
	meal_game.set("cold_exposure", true)
	meal_player.global_position = Vector3(-1.0, 0.19, 0.85)
	meal_game.call("_interact")
	assert(int(meal_game.get("stew_servings")) == 0 and int(meal_game.get("shared_meal_count")) == 1, "sharing dinner should consume the serving and record a household moment")
	assert(str(meal_game.get("message")).contains("今天已经一起吃过饭"), "sharing should not call the meal dinner when players can share food at any time")
	assert(not bool(meal_game.get("cold_exposure")), "a shared hot meal should have a modest, visible warming effect")
	assert(_count_events(meal_game.get("world_events"), "resident_meal_shared") == 1, "the resident meal should create a durable narrative hook")
	assert(bool(meal_game.get("resident_keepsake_present")) and meal_game.get_node_or_null("ArkRoot/BuiltShelter/TideShellKeepsake/PolishedShell") is MeshInstance3D, "the first shared meal should leave a small physical keepsake in the home")
	assert(_count_events(meal_game.get("world_events"), "resident_keepsake_placed") == 1, "the keepsake should be grounded in exactly one recorded household event")
	var keepsake_marker := meal_game.get_node("ArkRoot/ResidentKeepsakeInteractable") as Node3D
	meal_player.global_position = keepsake_marker.global_position
	meal_game.call("_interact")
	assert(str(meal_game.get("message")).contains("第一次分着喝完热汤") and _count_events(meal_game.get("world_events"), "resident_keepsake_placed") == 1, "inspecting the shell should recall the actual shared meal without generating another event")
	meal_game.call("_interact")
	assert(int(meal_game.get("shared_meal_count")) == 1, "the same day's meal interaction should not duplicate the shared meal")
	meal_player.global_position = Vector3(13.8, 1.1, -11.8)
	meal_game.call("_interact")
	assert(int(meal_game.get("raw_shellfish")) == 1, "the second cove should provide an independent food-gathering trip")
	meal_game.call("_rest_at_cot")
	meal_game.call("_rest_at_cot")
	for _period_step in range(4):
		meal_game.call("_rest_at_cot")
	# Pre-storm mornings now permit a real shift. Let the worker return rather
	# than making dinner preempt her job or inventing a completed-work day.
	assert(bool(meal_game.get("resident_gather_pending")), "crossing dawn before the first storm should start a real nearby gathering shift")
	var meal_wood_before_delivery := int(meal_game.get("wood")) + int(meal_game.get("stored_wood"))
	var meal_shellfish_before_delivery := int(meal_game.get("raw_shellfish"))
	assert(str(meal_game.get("resident_gather_target_id")) == "DriftwoodNear", "this cooking fixture should first collect its untouched nearby two-plank pile")
	for _gather_step in range(600):
		if not bool(meal_game.get("resident_gather_pending")):
			break
		meal_game.call("_process_resident_gathering", 0.1)
	assert(not bool(meal_game.get("resident_gather_pending")), "the dawn worker must physically return before taking up evening cooking")
	assert(_count_events(meal_game.get("world_events"), "resident_gather_delivered") == 1 and int(meal_game.get("wood")) + int(meal_game.get("stored_wood")) == meal_wood_before_delivery + 2, "the completed trip must deliver the two real planks exactly once")
	assert(int(meal_game.get("raw_shellfish")) == meal_shellfish_before_delivery and bool(meal_game.get("economy").audit().ok), "gathering wood must preserve cooking ingredients and the resource ledger")
	meal_game.set("weather_phase", 2)
	meal_game.call("_update_traveler_schedule")
	assert(str(meal_game.get("traveler_action")) == "准备潮滩晚饭", "at dusk the resident should choose the hearth when food is available; action=%s period=%d day=%d shared_day=%d raw=%d" % [str(meal_game.get("traveler_action")), int(meal_game.get("day_period")), int(meal_game.get("day_count")), int(meal_game.get("shared_meal_day")), int(meal_game.get("raw_shellfish"))])
	meal_game.call("_process", 10.0)
	assert((meal_game.get("traveler_marker") as Node3D).position.is_equal_approx(meal_game.get("traveler_target_position")), "the resident should physically reach the cooking place")
	meal_game.call("_rest_at_cot")
	assert(int(meal_game.get("raw_shellfish")) == 0 and int(meal_game.get("stew_servings")) == 1, "advancing the evening after she reaches the hearth should complete her cooking task")
	assert(_count_events(meal_game.get("world_events"), "resident_meal_prepared") == 1, "resident cooking should preserve its actual ingredient cost and source")
	meal_game.queue_free()
	await process_frame
	var meal_restored := packed.instantiate()
	meal_restored.set("save_root_override", meal_save_root)
	root.add_child(meal_restored)
	await process_frame
	assert(int(meal_restored.get("shared_meal_count")) == 1 and int(meal_restored.get("shared_meal_day")) == 1 and int(meal_restored.get("day_count")) == 2, "the shared-meal daily limit should survive reload and be available again on the next day")
	assert(int(meal_restored.get("stew_servings")) == 1, "a resident-prepared serving should survive reload without being consumed")
	assert(meal_restored.get_node_or_null("ArkRoot/BuiltShelter/HearthPot") != null, "the actual cooking hearth should reconstruct")
	assert(int(meal_restored.get("last_shore_replenish_day")) == 2 and _count_events(meal_restored.get("world_events"), "shore_supply_replenished") == 2, "the two consumed patches should each renew once at day-two dawn, not again on load")
	for renewed_id in ["TidalShellsNear", "TidalShellsCove"]:
		assert(meal_restored.get_node_or_null(NodePath(renewed_id)) != null and not renewed_id in meal_restored.get("collected_ids"), "dawn-renewed forage must reconstruct with an uncollected mirror")
		assert(int(meal_restored.get("economy").source(renewed_id).remaining) == 1, "reload must preserve exactly one new physical serving at each patch, without stacking or regranting inventory")
	assert(int(meal_restored.get("raw_shellfish")) == 0 and meal_restored.get("economy").audit().ok, "renewed shore food stays in the world, not in the player meal inventory")
	assert(bool(meal_restored.get("resident_keepsake_present")) and meal_restored.get_node_or_null("ArkRoot/BuiltShelter/TideShellKeepsake/PolishedShell") is MeshInstance3D, "the personal reminder should reconstruct from the saved household state")
	assert(_count_events(meal_restored.get("world_events"), "meal_prepared") == 1 and _count_events(meal_restored.get("world_events"), "resident_meal_prepared") == 1 and _count_events(meal_restored.get("world_events"), "resident_meal_shared") == 1, "cooking and sharing should not replay on load")
	assert(_count_events(meal_restored.get("world_events"), "resident_keepsake_placed") == 1, "loading should not replay or duplicate the keepsake placement event")
	var restored_meal_player := meal_restored.get("player") as CharacterBody3D
	var restored_tidekeeper := meal_restored.get("traveler_marker") as Node3D
	restored_meal_player.global_position = restored_tidekeeper.global_position
	meal_restored.call("_interact")
	assert(int(meal_restored.get("shared_meal_count")) == 2 and int(meal_restored.get("stew_servings")) == 0, "a second shared meal on the next day should advance a real relationship memory without duplicating food")
	assert(meal_restored.get_node_or_null("ArkRoot/BuiltShelter/TideShellKeepsake/SecondPolishedShell") is MeshInstance3D, "the second shared meal should add a distinct physical shell to the home")
	assert(_count_events(meal_restored.get("world_events"), "resident_keepsake_pair_completed") == 1 and str(meal_restored.get("message")).contains("第二次分着喝完热汤"), "the milestone should produce its own truthful response and one factual event")
	var paired_keepsake_marker := meal_restored.get_node("ArkRoot/ResidentKeepsakeInteractable") as Node3D
	restored_meal_player.global_position = paired_keepsake_marker.global_position
	meal_restored.call("_interact")
	assert(str(meal_restored.get("message")).contains("两枚潮贝") and _count_events(meal_restored.get("world_events"), "resident_keepsake_pair_completed") == 1, "inspecting the paired memory should recall the earned milestone without replaying it")
	var legacy_shared_meal_state: Dictionary = meal_restored.call("_build_save_state")
	meal_restored.queue_free()
	await process_frame
	legacy_shared_meal_state["schema_version"] = 13
	legacy_shared_meal_state.erase("resident_keepsake_present")
	legacy_shared_meal_state["world_events"] = []
	legacy_shared_meal_state["event_sequence"] = 0
	assert(bool(meal_save.save_state(legacy_shared_meal_state).get("ok", false)), "a schema 13 save with a prior shared meal should be seedable without the later keepsake field")
	var legacy_meal_restored := packed.instantiate()
	legacy_meal_restored.set("save_root_override", meal_save_root)
	root.add_child(legacy_meal_restored)
	await process_frame
	assert(bool(legacy_meal_restored.get("resident_keepsake_present")) and legacy_meal_restored.get_node_or_null("ArkRoot/BuiltShelter/TideShellKeepsake/PolishedShell") is MeshInstance3D and legacy_meal_restored.get_node_or_null("ArkRoot/BuiltShelter/TideShellKeepsake/SecondPolishedShell") is MeshInstance3D, "older saves with two shared meals should reconstruct both physical memory shells")
	assert(_count_events(legacy_meal_restored.get("world_events"), "resident_keepsake_placed") == 0 and _count_events(legacy_meal_restored.get("world_events"), "resident_keepsake_pair_completed") == 0, "migration should rebuild earned memories without inventing historical events")
	legacy_meal_restored.queue_free()
	await process_frame
	meal_save.clear_for_test()
	var sailmaker_save_root := ProjectSettings.globalize_path("res://../.local/test_save_sailmaker").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(sailmaker_save_root), "test saves must be isolated in this repository; Windows saves must remain on D:")
	var sailmaker_save := preload("res://scripts/ark_greybox_save.gd").new(sailmaker_save_root)
	sailmaker_save.clear_for_test()
	var sailmaker_game := packed.instantiate()
	sailmaker_game.set("save_root_override", sailmaker_save_root)
	root.add_child(sailmaker_game)
	await process_frame
	sailmaker_game.set("wood", 3)
	assert(bool(sailmaker_game.call("_try_place_shelter", Vector3.ZERO)), "the new resident should only be invited after the player has built a real shelter")
	var sailmaker_player: CharacterBody3D = sailmaker_game.get("player")
	var tidekeeper_shore_marker := sailmaker_game.get_node("residentMarker") as Node3D
	sailmaker_player.global_position = tidekeeper_shore_marker.global_position
	sailmaker_game.call("_interact")
	sailmaker_game.call("_interact")
	sailmaker_game.call("_choose_traveler_boarding", true)
	assert(bool(sailmaker_game.get("traveler_boarded")), "the first resident should remain independently recruitable alongside the new visitor")
	var sailmaker_shore_marker := sailmaker_game.get_node("sailmakerMarker") as Node3D
	sailmaker_player.global_position = sailmaker_shore_marker.global_position
	sailmaker_game.call("_interact")
	assert(bool(sailmaker_game.get("sailmaker_met")) and bool(sailmaker_game.get("resident_met")), "meeting the original sailmaker should preserve the tidekeeper's separate identity state")
	sailmaker_game.call("_interact")
	assert(bool(sailmaker_game.get("sailmaker_choice_pending")), "the sailmaker should make her own explicit boarding decision available")
	var decline_sailmaker_key := InputEventKey.new()
	decline_sailmaker_key.pressed = true
	decline_sailmaker_key.keycode = KEY_2
	sailmaker_game.call("_unhandled_key_input", decline_sailmaker_key)
	assert(not bool(sailmaker_game.get("sailmaker_choice_pending")), "the displayed second choice should resolve from the actual 2 key input")
	var sailmaker_decline_event: Dictionary = (sailmaker_game.get("world_events") as Array).back()
	assert(not bool(sailmaker_game.get("sailmaker_boarded")) and str((sailmaker_decline_event.get("facts") as Dictionary).get("resident_id", "")) == "sailmaker" and not bool((sailmaker_decline_event.get("facts") as Dictionary).get("accepted", true)), "declining this invitation should leave the sailmaker ashore without recruiting her")
	sailmaker_game.call("_interact")
	var accept_sailmaker_key := InputEventKey.new()
	accept_sailmaker_key.pressed = true
	accept_sailmaker_key.keycode = KEY_1
	sailmaker_game.call("_unhandled_key_input", accept_sailmaker_key)
	assert(bool(sailmaker_game.get("sailmaker_boarded")) and bool(sailmaker_game.get("traveler_boarded")), "boarding the sailmaker should preserve the first resident's independently boarded state")
	assert((sailmaker_game.get("opening_coast") as RefCounted).call("visual_child", sailmaker_game.get("sailmaker_marker"), "SailmakerFigure/Head") is MeshInstance3D and (sailmaker_game.get("opening_coast") as RefCounted).call("visual_child", sailmaker_game.get("sailmaker_marker"), "OldSailBundle") is MeshInstance3D, "the second resident should have a distinct volumetric placeholder and visible personal kit")
	var sailmaker_ark := sailmaker_game.get_node("ArkRoot") as Node3D
	var boarded_sailmaker_marker := sailmaker_game.get("sailmaker_marker") as Node3D
	var boarded_traveler_marker := sailmaker_game.get("traveler_marker") as Node3D
	assert(boarded_sailmaker_marker.get_parent() == sailmaker_ark and boarded_traveler_marker.get_parent() == sailmaker_ark, "both residents should become physical passengers in the ark hierarchy")
	sailmaker_ark.global_position = Vector3(-8.0, 0.0, 3.0)
	sailmaker_ark.rotation.y = 0.65
	assert(boarded_sailmaker_marker.global_position.is_equal_approx(sailmaker_ark.to_global(boarded_sailmaker_marker.position)), "the second resident's world position should be derived from the moving ark deck")
	assert(str(sailmaker_game.get("sailmaker_action")) == "看云脚收帆" and str(sailmaker_game.get("traveler_action")) == "查看潮势" and not sailmaker_game.get("sailmaker_target_position").is_equal_approx(sailmaker_game.get("traveler_target_position")), "both residents should run distinct weather-aware routines and destinations")
	sailmaker_player.global_position = Vector3(30.0, 1.1, 30.0)
	var wait_player_position := sailmaker_player.global_position
	var wait_ark_position := sailmaker_ark.global_position
	var wait_weather_phase := int(sailmaker_game.get("weather_phase"))
	var time_events_before_wait := _count_events(sailmaker_game.get("world_events"), "time_advanced")
	sailmaker_game.set("cold_exposure", true)
	for _period_step in range(4):
		var wait_key := InputEventKey.new()
		wait_key.pressed = true
		wait_key.keycode = KEY_T
		sailmaker_game.call("_unhandled_key_input", wait_key)
	assert(bool(sailmaker_game.get("cold_exposure")), "waiting away from the cot should not cure cold exposure")
	assert(sailmaker_player.global_position.is_equal_approx(wait_player_position) and sailmaker_ark.global_position.is_equal_approx(wait_ark_position), "waiting should not teleport the player or move the ark")
	assert(int(sailmaker_game.get("weather_phase")) == wait_weather_phase, "waiting should not advance the separately controlled weather phase")
	assert(_count_events(sailmaker_game.get("world_events"), "time_advanced") == time_events_before_wait + 4, "each T press should advance and record exactly one world period")
	var wait_cause_count := 0
	for event in sailmaker_game.get("world_events"):
		if event is Dictionary and str(event.get("id", "")) == "time_advanced" and int(event.get("sequence", 0)) > 0:
			var facts: Dictionary = event.get("facts", {})
			if str(facts.get("cause", "")) == "wait":
				wait_cause_count += 1
				assert(int(facts.get("period", -1)) in [0, 1, 2, 3], "wait facts should preserve a valid target period")
	assert(wait_cause_count == 4, "the event ledger should distinguish each voluntary wait from bed rest")
	assert(int(sailmaker_game.get("day_count")) == 2 and not bool(sailmaker_game.get("sailmaker_awning_raised")), "dawn makes the personal gift eligible; four T presses cannot fabricate sewing and installation")
	assert(sailmaker_game.get_node_or_null("ArkRoot/BuiltShelter/SailmakerAwning") == null and _count_events(sailmaker_game.get("world_events"), "resident_sail_awning_raised") == 0, "calendar advancement alone must not create a mesh or completed work fact")
	for _work_step in range(700):
		if bool(sailmaker_game.get("sailmaker_awning_raised")):
			break
		sailmaker_game.call("_process", 0.05)
	assert(bool(sailmaker_game.get("sailmaker_awning_raised")), "ordinary resident processing must physically sew, carry, and install the one-time personal contribution")
	assert(str(sailmaker_game.get("message")).contains("雨檐"), "the new resident's work should be reported when it becomes visible")
	assert(sailmaker_game.get_node_or_null("ArkRoot/BuiltShelter/SailmakerAwning/PatchedCanvas") is MeshInstance3D and sailmaker_game.get_node_or_null("ArkRoot/SailmakerAwningInteractable") != null, "the patched rain awning should be physical, visible, and inspectable")
	assert(_count_events(sailmaker_game.get("world_events"), "resident_sail_awning_raised") == 1, "raising the awning should produce exactly one factual resident event")
	sailmaker_game.call("_process", 0.5)
	sailmaker_game.set_process(false)
	var saved_traveler_deck_position := (sailmaker_game.get("traveler_marker") as Node3D).position
	var saved_sailmaker_deck_position := (sailmaker_game.get("sailmaker_marker") as Node3D).position
	assert(bool(sailmaker_game.call("_save_progress")), "resident positions should be saved with the moving ark state")
	var legacy_sailmaker_state: Dictionary = sailmaker_game.call("_build_save_state")
	sailmaker_game.queue_free()
	await process_frame
	var sailmaker_restored := packed.instantiate()
	sailmaker_restored.set("save_root_override", sailmaker_save_root)
	root.add_child(sailmaker_restored)
	sailmaker_restored.set_process(false)
	await process_frame
	assert(bool(sailmaker_restored.get("sailmaker_boarded")) and bool(sailmaker_restored.get("sailmaker_awning_raised")), "the independent resident and her completed home contribution should survive save reload")
	assert(int(sailmaker_restored.get("day_count")) == 2 and _count_events(sailmaker_restored.get("world_events"), "time_advanced") == time_events_before_wait + 4, "voluntarily waited periods and their day transition should persist through reload exactly once")
	var restored_wait_cause_count := 0
	for event in sailmaker_restored.get("world_events"):
		if event is Dictionary and str(event.get("id", "")) == "time_advanced" and str((event.get("facts", {}) as Dictionary).get("cause", "")) == "wait":
			restored_wait_cause_count += 1
	assert(restored_wait_cause_count == 4, "loading should retain the four intentional wait facts without replaying them")
	assert(sailmaker_restored.get_node_or_null("ArkRoot/SailmakerAwningInteractable") != null and _count_events(sailmaker_restored.get("world_events"), "resident_sail_awning_raised") == 1, "reload should rebuild the awning and must not replay its event")
	var restored_sailmaker_ark := sailmaker_restored.get_node("ArkRoot") as Node3D
	var restored_sailmaker_marker := sailmaker_restored.get("sailmaker_marker") as Node3D
	assert(restored_sailmaker_marker.get_parent() == restored_sailmaker_ark and restored_sailmaker_marker.global_position.is_equal_approx(restored_sailmaker_ark.to_global(restored_sailmaker_marker.position)), "the boarded resident should be reconstructed aboard the persisted ark after reload")
	assert(restored_sailmaker_ark.global_position.is_equal_approx(Vector3(-8.0, 0.0, 3.0)) and is_equal_approx(restored_sailmaker_ark.rotation.y, 0.65), "the residents should reload with the ark's persisted position and heading")
	var restored_traveler_marker := sailmaker_restored.get("traveler_marker") as Node3D
	assert(saved_traveler_deck_position.distance_to(Vector3(-1.0, 0.12, 0.85)) > 0.1 and saved_sailmaker_deck_position.distance_to(Vector3(1.15, 0.12, 0.75)) > 0.1, "the save fixture should capture both residents partway through their routines")
	assert(restored_traveler_marker.position.distance_to(saved_traveler_deck_position) < 0.05 and restored_sailmaker_marker.position.distance_to(saved_sailmaker_deck_position) < 0.05, "both residents should resume near their saved deck positions instead of snapping back to spawn points")
	legacy_sailmaker_state["schema_version"] = 14
	for field in ["traveler_position", "sailmaker_position", "sailmaker_met", "sailmaker_boarded", "sailmaker_joined_day", "sailmaker_awning_raised", "sailmaker_awning_phase", "sailmaker_awning_sewing_elapsed", "sailmaker_awning_install_elapsed"]:
		legacy_sailmaker_state.erase(field)
	legacy_sailmaker_state["world_events"] = []
	legacy_sailmaker_state["event_sequence"] = 0
	sailmaker_restored.queue_free()
	await process_frame
	assert(bool(sailmaker_save.save_state(legacy_sailmaker_state).get("ok", false)), "a schema 14 save should be seedable for second-resident migration coverage")
	var legacy_sailmaker_restored := packed.instantiate()
	legacy_sailmaker_restored.set("save_root_override", sailmaker_save_root)
	root.add_child(legacy_sailmaker_restored)
	await process_frame
	assert(not bool(legacy_sailmaker_restored.get("sailmaker_met")) and not bool(legacy_sailmaker_restored.get("sailmaker_boarded")) and not bool(legacy_sailmaker_restored.get("sailmaker_awning_raised")), "schema 14 saves should not invent a meeting, invitation, or completed resident contribution")
	assert(legacy_sailmaker_restored.get_node_or_null("ArkRoot/BuiltShelter/SailmakerAwning") == null and (legacy_sailmaker_restored.get("world_events") as Array).is_empty(), "old-save migration must not create the new awning or fabricate resident history")
	legacy_sailmaker_restored.queue_free()
	await process_frame
	sailmaker_save.clear_for_test()
	var storm_cycle_save_root := ProjectSettings.globalize_path("res://../.local/test_save_storm_cycle").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(storm_cycle_save_root), "test saves must be isolated in this repository; Windows saves must remain on D:")
	var storm_cycle_save := preload("res://scripts/ark_greybox_save.gd").new(storm_cycle_save_root)
	storm_cycle_save.clear_for_test()
	var storm_cycle_game := packed.instantiate()
	storm_cycle_game.set("save_root_override", storm_cycle_save_root)
	root.add_child(storm_cycle_game)
	storm_cycle_game.set_process(false)
	await process_frame
	storm_cycle_game.set("wood", 5)
	assert(bool(storm_cycle_game.call("_try_place_shelter", Vector3(0.0, 0.12, 0.0))), "the recurring-storm fixture should build a shelter for a protected-surface test")
	storm_cycle_game.call("_interact_home")
	storm_cycle_game.call("_choose_weather_preparation", "shelter")
	storm_cycle_game.call("_advance_weather")
	storm_cycle_game.call("_advance_weather")
	assert(int(storm_cycle_game.get("resolved_storm_count")) == 1 and int(storm_cycle_game.get("next_storm_day")) == 3, "the first resolved storm should schedule a distinct, predictable later forecast")
	assert(bool(storm_cycle_game.get("raft_edge_damaged")) and not bool(storm_cycle_game.get("shelter_roof_damaged")), "the first storm should retain its original rope-protection result; rope=%s raft=%s roof=%s" % [str(storm_cycle_game.get("rope_use")), str(storm_cycle_game.get("raft_edge_damaged")), str(storm_cycle_game.get("shelter_roof_damaged"))])
	storm_cycle_game.set("repair_choice_pending", true)
	storm_cycle_game.call("_repair_damaged_part", "raft")
	assert(not bool(storm_cycle_game.get("raft_edge_damaged")) and _count_events(storm_cycle_game.get("world_events"), "structure_repaired") == 1, "the player should be able to repair the first storm's unprotected structure before the next forecast")
	var first_storm_legacy_state: Dictionary = storm_cycle_game.call("_build_save_state")
	first_storm_legacy_state["schema_version"] = 16
	first_storm_legacy_state.erase("resolved_storm_count")
	first_storm_legacy_state.erase("next_storm_day")
	first_storm_legacy_state.erase("last_resolved_storm_facts")
	first_storm_legacy_state.erase("tidekeeper_last_storm_reflection")
	first_storm_legacy_state["resident_met"] = true
	first_storm_legacy_state["traveler_boarded"] = true
	var legacy_storm_save_root := ProjectSettings.globalize_path("res://../.local/test_save_legacy_storm").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(legacy_storm_save_root), "test saves must be isolated in this repository; Windows saves must remain on D:")
	var legacy_storm_save := preload("res://scripts/ark_greybox_save.gd").new(legacy_storm_save_root)
	legacy_storm_save.clear_for_test()
	assert(bool(legacy_storm_save.save_state(first_storm_legacy_state).get("ok", false)), "a schema 16 aftermath save should be seedable for recurring-weather migration coverage")
	storm_cycle_game.queue_free()
	await process_frame
	var migrated_storm_game := packed.instantiate()
	migrated_storm_game.set("save_root_override", legacy_storm_save_root)
	root.add_child(migrated_storm_game)
	migrated_storm_game.set_process(false)
	await process_frame
	assert(int(migrated_storm_game.get("resolved_storm_count")) == 1 and int(migrated_storm_game.get("next_storm_day")) == int(migrated_storm_game.get("day_count")) + 2, "schema 16 aftermath should migrate to a pending forecast without inventing another completed storm")
	assert(_count_events(migrated_storm_game.get("world_events"), "storm_started") == 1 and _count_events(migrated_storm_game.get("world_events"), "storm_resolved") == 1, "legacy weather migration must preserve the original storm history without fabricated events")
	assert((migrated_storm_game.get("last_resolved_storm_facts") as Dictionary).is_empty() and int(migrated_storm_game.get("tidekeeper_last_storm_reflection")) == 1, "legacy saves should not invent a grounded storm memory retroactively")
	var migrated_traveler_marker := migrated_storm_game.get("traveler_marker") as Node3D
	(migrated_storm_game.get("player") as CharacterBody3D).global_position = migrated_traveler_marker.global_position
	migrated_storm_game.call("_interact")
	assert(_count_events(migrated_storm_game.get("world_events"), "resident_storm_reflection") == 0, "an old save must not append a fictional memory event")
	migrated_storm_game.queue_free()
	await process_frame
	legacy_storm_save.clear_for_test()
	var next_storm_game := packed.instantiate()
	next_storm_game.set("save_root_override", storm_cycle_save_root)
	root.add_child(next_storm_game)
	next_storm_game.set_process(false)
	await process_frame
	for _period in range(8):
		var weather_before_wait := int(next_storm_game.get("weather_phase"))
		next_storm_game.call("_wait_one_period")
		assert(int(next_storm_game.get("weather_phase")) == weather_before_wait, "ordinary waiting should never silently advance weather into a storm")
	assert(int(next_storm_game.get("day_count")) == 3 and bool(next_storm_game.call("_storm_forecast_due")), "the next storm forecast should arrive visibly on the scheduled morning after two calm days")
	var storm_hud := next_storm_game.get("hud") as Label
	assert(storm_hud.text.contains("下一场风雨已预报") and int(next_storm_game.get("weather_phase")) == 2, "a due storm forecast should be visible while the aftermath remains navigation-compatible")
	var saved_storm_events: int = (next_storm_game.get("world_events") as Array).size()
	next_storm_game.queue_free()
	await process_frame
	var forecast_restored := packed.instantiate()
	forecast_restored.set("save_root_override", storm_cycle_save_root)
	root.add_child(forecast_restored)
	forecast_restored.set_process(false)
	await process_frame
	assert(bool(forecast_restored.call("_storm_forecast_due")) and int(forecast_restored.get("next_storm_day")) == 3 and (forecast_restored.get("world_events") as Array).size() == saved_storm_events, "the due forecast and its event history should survive reload without replay")
	forecast_restored.call("_advance_weather")
	assert(int(forecast_restored.get("weather_phase")) == 1 and _count_events(forecast_restored.get("world_events"), "storm_started") == 2 and not bool(forecast_restored.get("rope_available")) and str(forecast_restored.get("rope_use")) == "shelter", "the player should explicitly start the second storm without regaining or consuming another rope")
	var second_storm_start: Dictionary = (forecast_restored.get("world_events") as Array).back()
	assert(int((second_storm_start.get("facts", {}) as Dictionary).get("storm_number", 0)) == 2, "the second storm should have its own numbered onset fact")
	forecast_restored.call("_advance_weather")
	assert(int(forecast_restored.get("resolved_storm_count")) == 2 and int(forecast_restored.get("next_storm_day")) == 6 and bool(forecast_restored.get("raft_edge_damaged")) and not bool(forecast_restored.get("shelter_roof_damaged")), "a later storm should again damage the repaired unprotected edge while preserving the anchored shelter rope")
	assert(_count_events(forecast_restored.get("world_events"), "storm_resolved") == 2 and _count_events(forecast_restored.get("world_events"), "structure_repaired") == 1, "both storm outcomes and the intervening repair should remain distinct factual history")
	forecast_restored.queue_free()
	await process_frame
	storm_cycle_save.clear_for_test()
	print("ARK_GREYBOX_SMOKE_OK:")
	quit(0)
