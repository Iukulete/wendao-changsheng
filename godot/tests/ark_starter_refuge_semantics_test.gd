extends SceneTree

## Acceptance boundary: refuge admission is not a promise of a dedicated bed.
## Resource fixtures isolate this change; the workshop test covers real salvage.
const Paths = preload("res://tests/ark_test_paths.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
var scene: PackedScene
var save_root: String


func _initialize() -> void:
	_run.call_deferred()


func _spawn() -> Node:
	var game := scene.instantiate()
	game.set("save_root_override", save_root)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	(game.get("player") as Node).set_physics_process(false)
	await physics_frame
	return game


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _key(game: Node, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game.call("_unhandled_key_input", event)


func _marker(game: Node, id: String) -> Node3D:
	for entry in game.get("interactables") as Array:
		if str(entry.get("id", "")) == id:
			return entry.get("node") as Node3D
	assert(false, "missing actual interaction " + id)
	return null


func _interact(game: Node, id: String) -> void:
	var player := game.get("player") as Node3D
	var ark := game.get_node("ArkRoot") as Node3D
	player.global_position = ark.to_global(_player_approach(game, id))
	game.call("_update_interaction_hint")
	assert((game.get("interaction_hint") as Label).text == "E  ·  " + str(game.call("_interaction_hint_action", id)), "resident refuge points must not steal the nearest interaction for " + id)
	_key(game, KEY_E)


func _player_approach(game: Node, id: String) -> Vector3:
	var ark := game.get_node("ArkRoot") as Node3D
	var player := game.get("player") as Node3D
	var before := player.global_position
	var center := ark.to_local(_marker(game, id).global_position)
	var excluded: Array[RID] = []
	for offset in [Vector2.ZERO, Vector2(0.25, 0), Vector2(-0.25, 0), Vector2(0, 0.25), Vector2(0, -0.25), Vector2(0.25, 0.25), Vector2(-0.25, 0.25), Vector2(0.25, -0.25), Vector2(-0.25, -0.25), Vector2(0.5, 0), Vector2(-0.5, 0), Vector2(0, 0.5), Vector2(0, -0.5)]:
		var candidate := Vector3(snappedf(center.x + offset.x, 0.25), 1.1, snappedf(center.z + offset.y, 0.25))
		if bool(game.call("_ark_local_walk_cell_blocked", Vector2(candidate.x, candidate.z), excluded, 0.38)):
			continue
		player.global_position = ark.to_global(candidate)
		game.call("_update_interaction_hint")
		if (game.get("interaction_hint") as Label).text == "E  ·  " + str(game.call("_interaction_hint_action", id)):
			player.global_position = before
			return candidate
	player.global_position = before
	assert(false, "no body-sized clear approach selects " + id + " instead of a refuge occupant")
	return Vector3.INF


func _admit_both(game: Node) -> void:
	game.set("resident_met", true)
	game.set("traveler_choice_pending", true)
	_key(game, KEY_1)
	game.set("sailmaker_met", true)
	game.set("sailmaker_choice_pending", true)
	_key(game, KEY_1)
	assert(bool(game.get("traveler_boarded")) and bool(game.get("sailmaker_boarded")), "existing explicit consent must still admit both refugees")
	assert(int(game.call("_resident_occupancy")) == 2)
	assert(bool(game.call("_can_board_resident", "tidekeeper")) and bool(game.call("_can_board_resident", "sailmaker")), "already admitted residents must not be expelled by the bed distinction")


func _night(game: Node) -> void:
	game.set("weather_phase", 2) # After the storm, no repair/meal overrides.
	game.set("day_period", 3)
	game.call("_update_traveler_schedule")
	game.call("_update_sailmaker_schedule")


func _capacities(game: Node, accepted: int, beds: int) -> void:
	assert(int(game.call("_resident_capacity")) == accepted, "existing admission limits must remain 2/3/4, excluding the player")
	assert(int(game.call("_resident_berth_capacity")) == beds, "dedicated NPC beds must count only actual expansion/cabin accommodation")
	assert(int(game.call("_resident_temporary_refuge_capacity")) == (2 if accepted > 0 else 0))
	game.call("_update_hud")
	var text := (game.get("hud_details") as Label).text
	assert(text.contains("避难者 %d/%d" % [int(game.call("_resident_occupancy")), accepted]) and text.contains("不含玩家"), "HUD must explain whose finite admission limit it displays")
	assert(text.contains("居民专用床位 %d" % beds) and text.contains("临时避难名额 %d" % (2 if accepted > 0 else 0)), "HUD must not relabel temporary shelter as permanent beds")
	assert(text.contains("玩家床铺 %d" % (1 if accepted > 0 else 0)), "player's separate cot must be disclosed rather than counted as an NPC berth")
	assert(not text.contains("居住泊位 %d" % accepted), "admission cannot masquerade as an all-beds count")
	assert((game.get_node_or_null("ArkRoot/BuiltRaftExtension/Berth") != null) == (beds >= 1))
	assert((game.get_node_or_null("ArkRoot/BuiltRaftExtension/GuestCabin/BedFrame") != null) == (beds == 2))


func _assert_temporary_targets(game: Node, temporary_action: bool = true) -> void:
	var shelter := game.get_node("ArkRoot/BuiltShelter") as Node3D
	var cot := game.get_node("ArkRoot/BuiltShelter/Cot") as Node3D
	var targets: Array[Vector3] = [game.get("traveler_target_position"), game.get("sailmaker_target_position")]
	assert(Vector2(targets[0].x, targets[0].z).distance_to(Vector2(targets[1].x, targets[1].z)) >= 0.46, "the refugees need distinct body-sized temporary rest destinations")
	for target in targets:
		var local := target - shelter.position
		assert(absf(local.x) <= 1.2 and absf(local.z) <= 0.9, "temporary rest must be inside usable shelter floor, not offshore or beyond a wall")
		var cot_offset := local - cot.position
		assert(absf(cot_offset.x) >= 0.46 + 0.23 or absf(cot_offset.z) >= 0.26 + 0.23, "neither resident may occupy the player's physical cot footprint")
		assert(not bool(game.call("_ark_local_walk_cell_blocked", Vector2(target.x, target.z))), "temporary rest endpoint must be physically walkable")
	if temporary_action:
		for property in ["traveler_action", "sailmaker_action"]:
			assert(str(game.get(property)).contains("临时"), "nightly activity should honestly identify temporary refuge")


func _walk_to_night_targets(game: Node) -> void:
	var ark := game.get_node("ArkRoot") as Node3D
	var residents: Array[Node3D] = [game.get("traveler_marker"), game.get("sailmaker_marker")]
	var targets: Array[Vector3] = [game.get("traveler_target_position"), game.get("sailmaker_target_position")]
	for index in range(2):
		assert(residents[index].get_parent() == ark)
		residents[index].position = Vector3(-0.35 if index == 0 else 0.35, 0.12, 1.55)
		game.set("traveler_routine_route_target_set" if index == 0 else "sailmaker_routine_route_target_set", false)
		var route: PackedVector3Array = game.call("_build_ark_local_walk_route", residents[index].position, targets[index])
		assert(not route.is_empty(), "real resident route must reach its assigned rest space")
	for step in range(260):
		game.call("_process", 0.1)
		for resident in residents:
			assert(not bool(game.call("_ark_local_walk_cell_blocked", Vector2(resident.position.x, resident.position.z))), "rest walking must not cross solid walls, furniture, or unsupported water: %s at %s, step %d" % [resident.name, resident.position, step])
	for index in range(2):
		assert(residents[index].position.distance_to(targets[index]) < 0.07, "resident must actually arrive, not only be assigned a nominal destination")


func _assert_player_approaches(game: Node) -> void:
	# Independent player-radius flood fill; do not reuse a resident's smaller radius.
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, 21, 16)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var minimum := Vector2(-2.5, -2.0)
	var excluded: Array[RID] = []
	for z in range(16):
		for x in range(21):
			var point := minimum + Vector2(x, z) * 0.25
			grid.set_point_solid(Vector2i(x, z), bool(game.call("_ark_local_walk_cell_blocked", point, excluded, 0.38)))
	var start := Vector2i(10, 14)
	for id in ["cot", "hearth", "helm"]:
		var local := _player_approach(game, id)
		var target := Vector2i(roundi((local.x - minimum.x) / 0.25), roundi((local.z - minimum.y) / 0.25))
		assert(not grid.is_point_solid(target) and not grid.get_id_path(start, target).is_empty(), "player-radius route must still reach " + id)


func _assert_unchanged_owners(before: Dictionary, after: Dictionary) -> void:
	for field in ["economy", "construction", "construction_sequence"]:
		assert(_json(before[field]) == _json(after[field]), "changing refuge labels/derived rest roles must not fabricate costs, ownership or construction receipts: " + field)


func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/test_starter_refuge_semantics").simplify_path()
	assert(Paths.is_safe_save_root(save_root))
	var saves := Save.new(save_root)
	saves.clear_for_test()
	scene = load("res://scenes/ark_greybox.tscn") as PackedScene
	var legacy_state: Dictionary
	for template in ["shelter", "starter_home_template", "workshop_home_template"]:
		var game := await _spawn()
		_capacities(game, 0, 0)
		assert(not bool(game.call("_can_board_resident", "tidekeeper")), "without a shelter, admission must remain unavailable")
		game.set("wood", 30)
		(game.get("player") as Node3D).position = Vector3(0, 1.1, 1.75)
		var origin := Vector3(-0.5 if template == "shelter" else 0.0, 0.12, 0)
		assert(bool(game.call("_try_place_" + template, origin)), "free-placed and complete starter homes must both retain their refuge behavior")
		var expected_cost := 3 if template == "shelter" else 5 if template == "starter_home_template" else 7
		assert(int(game.get("wood")) == 30 - expected_cost, "refuge semantics must not change any opening template's actual price")
		assert(not bool(game.get("raft_extension_built")) and not bool(game.get("guest_cabin_built")), "a shelter must not auto-enlarge or manufacture dedicated resident beds")
		assert(not bool(game.get("traveler_boarded")) and not bool(game.get("sailmaker_boarded")), "building refuge space must not invent either resident's consent")
		_admit_both(game)
		_capacities(game, 2, 0)
		assert(not bool(game.call("_can_board_resident", "future_resident")), "no spare bed promise or unlimited refuge admission may be invented")
		_night(game)
		await physics_frame
		_assert_temporary_targets(game)
		_walk_to_night_targets(game)
		_assert_player_approaches(game)
		game.set("weather_phase", 1)
		game.call("_update_traveler_schedule")
		game.call("_update_sailmaker_schedule")
		_assert_temporary_targets(game, false)
		_walk_to_night_targets(game)
		_night(game)
		# Actual E dispatch while both NPCs stand at their temporary rest points.
		# Evening -> night isolates rest from unrelated dawn gathering and refill.
		game.set("day_period", 2)
		var clock_before := int(game.get("event_sequence"))
		game.set("player_health", 2)
		_interact(game, "cot")
		assert(int(game.get("day_period")) == 3 and int(game.get("player_health")) == 4, "player's cot must remain usable and retain its existing time/health effect")
		assert(int(game.get("event_sequence")) == clock_before + 2, "cot use should still produce only its existing time transition and health recovery, not new housing events")
		_assert_temporary_targets(game)
		game.set("raw_shellfish", 1)
		_interact(game, "hearth")
		assert(int(game.get("raw_shellfish")) == 0 and int(game.get("stew_servings")) == 1, "temporary rest positions must preserve actual cooking interaction")
		_interact(game, "helm")
		assert(bool(game.get("sailing_mode")), "temporary refuge occupants must not steal the helm interaction")
		_key(game, KEY_E)
		assert(not bool(game.get("sailing_mode")))
		if template == "workshop_home_template":
			# Recreate the exact old night-placement bug in a supported old save.
			(game.get("traveler_marker") as Node3D).position = Vector3(0.72, 0.24, 0.2)
			legacy_state = game.call("_build_save_state")
		game.queue_free()
		await process_frame
		saves.clear_for_test()

	# Existing two-resident saves are retained, not evicted or silently upgraded.
	for schema in [34, 35]:
		var old := legacy_state.duplicate(true)
		old["schema_version"] = schema
		assert(bool(saves.save_state(old).get("ok", false)))
		var game := await _spawn()
		assert(not bool(game.get_meta("save_load_blocked", false)))
		assert(bool(game.get("traveler_boarded")) and bool(game.get("sailmaker_boarded")))
		for role in ["traveler", "sailmaker"]:
			var position: Dictionary = old[role + "_position"]
			assert((game.get(role + "_marker") as Node3D).position.is_equal_approx(Vector3(position.x, position.y, position.z)), "old residents must resume their saved position before ordinary movement, not be teleported by migration")
		assert(int(game.get("day_count")) == int(old.day_count) and int(game.get("day_period")) == int(old.day_period), "derived rest roles must not advance saved time")
		_capacities(game, 2, 0)
		_assert_temporary_targets(game)
		var loaded: Dictionary = game.call("_build_save_state")
		assert(_json(loaded.world_events) == _json(old.world_events) and loaded.event_sequence == old.event_sequence, "reloading new rest roles must not invent consent, past accommodation, or historical events")
		_assert_unchanged_owners(old.modules, loaded.modules)
		assert(int(loaded.schema_version) == 36, "legacy refuge presentation survives migration to current schema 36")
		# Start at the preserved old Cot coordinate and use ordinary movement away.
		for step in range(100):
			game.call("_process", 0.1)
		assert((game.get("traveler_marker") as Node3D).position.distance_to(game.get("traveler_target_position")) < 0.07, "legacy resident at the player's cot must find the new temporary rest point without teleport migration")
		var ark := game.get_node("ArkRoot") as Node3D
		ark.position = Vector3(-8, 0, 3)
		ark.rotation.y = 0.65
		await physics_frame
		_walk_to_night_targets(game)
		_assert_player_approaches(game)
		assert(bool(game.call("_save_progress")))
		var saved: Dictionary = saves.load_state().get("state", {})
		_assert_unchanged_owners(old.modules, saved.modules)
		game.queue_free()
		await process_frame
		game = await _spawn()
		_capacities(game, 2, 0)
		assert((game.get_node("ArkRoot") as Node3D).position.is_equal_approx(Vector3(-8, 0, 3)))
		_assert_unchanged_owners(saved.modules, (game.call("_build_save_state") as Dictionary).modules)
		game.queue_free()
		await process_frame
		saves.clear_for_test()

	# Upgrades retain real geometry, costs and their existing dedicated assignments.
	assert(bool(saves.save_state(legacy_state).get("ok", false)))
	var game := await _spawn()
	game.set("wood", 20)
	game.set("keel_beams", 1)
	game.set("guest_cabin_frames", 1)
	game.call("_learn_blueprint", "tide_guest_cabin", "refuge_test_fixture")
	assert(bool(game.call("_try_place_raft_extension", Vector3(0, 0.12, -4.2))))
	assert(int(game.get("wood")) == 16 and int(game.get("keel_beams")) == 0)
	_capacities(game, 3, 1)
	assert(str(game.get("traveler_action")) == "甲板铺位歇息" and str(game.get("sailmaker_action")).contains("临时"))
	assert((game.get("traveler_target_position") as Vector3).is_equal_approx(Vector3(0.95, 0.24, -5.35)))
	await physics_frame
	_walk_to_night_targets(game)
	assert(bool(game.call("_try_place_guest_cabin_template", Vector3(0, 0.12, -4.2))))
	assert(int(game.get("wood")) == 13 and int(game.get("guest_cabin_frames")) == 0)
	_capacities(game, 4, 2)
	assert(str(game.get("sailmaker_action")) == "在听潮客舱歇息")
	assert((game.get("sailmaker_target_position") as Vector3).is_equal_approx(Vector3(-0.85, 0.12, -4.34)))
	await physics_frame
	_walk_to_night_targets(game)
	assert(bool(game.call("_dismantle_raft_extension")), "two existing refugees must remain admissible after optional dedicated beds are removed")
	await physics_frame
	_capacities(game, 2, 0)
	_assert_temporary_targets(game)
	_walk_to_night_targets(game)
	assert(int(game.get("wood")) == 20 and int(game.get("keel_beams")) == 1 and int(game.get("guest_cabin_frames")) == 1, "existing dismantle refund must be unchanged")
	game.queue_free()
	await process_frame
	saves.clear_for_test()
	print("ARK_STARTER_REFUGE_SEMANTICS_TEST_OK: all opening templates/costs; honest NPC limits and real beds; distinct reachable refuge rest; actual E cot/hearth/helm; schema34/35 two-resident saves without invented history/receipts; mobile routes; real upgrades/dismantle")
	quit()
