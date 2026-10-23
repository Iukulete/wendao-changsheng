extends SceneTree

## Real finite opening collection funds the template. Actor positioning isolates
## shore travel; route assertions below exercise actual resident movement.
const Paths = preload("res://tests/ark_test_paths.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
const Placement = preload("res://scripts/ark_fixture_placement.gd")
const SAVE_DIR := "res://../.local/test_workshop_home_template"
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


func _key(game: Node, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game.call("_unhandled_key_input", event)


func _marker(game: Node, id: String) -> Node3D:
	for entry in game.get("interactables") as Array:
		if str(entry.get("id", "")) == id:
			return entry.get("node") as Node3D
	assert(false, "missing live interaction: " + id)
	return null


func _interact(game: Node, id: String) -> void:
	(game.get("player") as Node3D).global_position = _marker(game, id).global_position + Vector3(0.0, 0.15, 0.0)
	_key(game, KEY_E)


func _helm_position(game: Node) -> void:
	(game.get("player") as Node3D).position = Vector3(0.0, 1.1, 1.75)


func _owned(game: Node) -> Dictionary:
	# Normalize JSON numeric representation for exact save/reload comparison.
	return JSON.parse_string(JSON.stringify(game.call("_module_snapshot"))) as Dictionary


func _empty(game: Node) -> void:
	for id in ["shelter", "storage", "workbench"]:
		assert(not bool(game.get(id + "_built")), "failed or preview construction must not set flags")
	for name in ["BuiltShelter", "BuiltStorage", "BuiltWorkbench"]:
		assert(game.get_node_or_null("ArkRoot/" + name) == null, "failed construction must not leave scene structures")


func _route_to_function(game: Node, id: String) -> void:
	var marker := _marker(game, id)
	var ark := game.get_node("ArkRoot") as Node3D
	var center := ark.to_local(marker.global_position)
	var start := Vector3(0.0, 0.12, 1.55)
	var target := Vector3(INF, 0.12, INF)
	# Pick an actually clear interaction approach, not an endpoint inside a prop.
	for offset in [Vector3(0, 0, 0.9), Vector3(0, 0, -0.9), Vector3(0.9, 0, 0), Vector3(-0.9, 0, 0), Vector3.ZERO]:
		var candidate: Vector3 = Vector3(center.x, 0.12, center.z) + offset
		if bool(game.call("_ark_local_walk_cell_blocked", Vector2(candidate.x, candidate.z))):
			continue
		var route: PackedVector3Array = game.call("_build_ark_local_walk_route", start, candidate)
		if not route.is_empty():
			target = candidate
			break
	assert(target.is_finite(), "new complete home must provide an actual route to " + id)
	var resident := game.get("traveler_marker") as Node3D
	assert(resident != null and resident.get_parent() == ark, "consenting resident must be aboard")
	resident.position = start
	game.set("traveler_routine_route_target_set", false)
	for step in range(120):
		game.call("_move_ark_resident_toward", resident, target, 0.1, 0.72, "tidekeeper")
		for fixture in ["storage", "workbench"]:
			assert(not Placement.contains_actor(Vector2(resident.position.x, resident.position.z), game.get(fixture + "_position"), Placement.half_size(fixture, int(game.get(fixture + "_quarter_turns")))), "resident must not walk through solid " + fixture)
	assert(resident.position.distance_to(target) < 0.07, "resident must arrive at " + id)


func _move_fixture(game: Node, id: String) -> void:
	var original: Vector3 = game.get(id + "_position")
	var node: Node3D = game.call("_fixture_node", id)
	var identity := node.get_instance_id()
	assert(bool(game.call("_start_fixture_edit", id)))
	var initial_turns: int = game.get(id + "_quarter_turns")
	_key(game, KEY_R)
	assert(int(game.get("preview_quarter_turns")) == (initial_turns + 1) % 4)
	for turn in range(4):
		if int(game.get("preview_quarter_turns")) == 1:
			break
		_key(game, KEY_R)
	_helm_position(game)
	var target := Vector3(INF, 0.12, INF)
	for z in [-1.5, 1.5, -1.0, 1.0, 0.0]:
		for x in [-2.0, 2.0, -2.5, 2.5]:
			var candidate := Vector3(x, 0.12, z)
			if candidate.distance_to(original) > 0.25 and str(game.call("_fixture_placement_error", id, candidate, 1)).is_empty():
				target = candidate
				break
		if target.is_finite():
			break
	assert(target.is_finite(), "template must leave a useful movable location for " + id)
	assert(bool(game.call("_try_move_fixture", target, 1)))
	assert(node.get_instance_id() == identity and node.position.is_equal_approx(target), "move must preserve model identity")
	assert(int(game.get(id + "_quarter_turns")) == 1)
	assert(bool(game.get(id + "_collision_enabled")))
	await physics_frame


func _run() -> void:
	save_root = ProjectSettings.globalize_path(SAVE_DIR).simplify_path()
	assert(Paths.is_safe_save_root(save_root))
	var saves := Save.new(save_root)
	saves.clear_for_test()
	scene = load("res://scenes/ark_greybox.tscn") as PackedScene
	var game := await _spawn()
	var origin := Vector3(0.0, 0.12, 0.0)
	_key(game, KEY_H)
	var button := game.find_child("ArkWorkshopHomeTemplateButton", true, false) as Button
	assert(button != null and button.is_visible_in_tree(), "workshop template must be discoverable in the HUD")
	assert(button.text.contains("7") and button.text.contains("起居工坊"), "button must disclose template and real price")
	_key(game, KEY_ESCAPE)
	assert(int(game.get("wood")) == 1)
	_helm_position(game)
	assert(bool(game.call("_is_valid_workshop_home_template_position", origin)), "insufficient-funds test must otherwise have valid space")
	var initial := _owned(game)
	assert(not bool(game.call("_try_place_workshop_home_template", origin)), "fresh insufficient inventory must reject the whole template")
	assert(_owned(game) == initial)
	_empty(game)
	for pile in range(3):
		_interact(game, "wood")
		await process_frame
	assert(int(game.get("wood")) == 8, "one starting plank plus real 2+2+3 piles must fund seven-wood template")
	_helm_position(game)
	var gathered := _owned(game)
	_key(game, KEY_H)
	assert(button.is_visible_in_tree())
	button.emit_signal("pressed")
	assert(bool(game.get("building_mode")) and str(game.get("build_type")) == "workshop_home_template")
	var preview := game.get("build_preview") as Node3D
	assert(preview != null and preview.name == "WorkshopHomeTemplatePreview")
	assert(preview.get_node_or_null("Storage") != null and preview.get_node_or_null("Workbench") != null and preview.get_child_count() >= 3, "all three prospective structures need visible ghosts")
	assert(_owned(game) == gathered)
	_empty(game)
	assert(bool(game.call("_save_progress")))
	var preview_saved: Dictionary = saves.load_state().get("state", {})
	assert(preview_saved.modules == gathered, "saving preview must persist only actual owners")
	assert(not preview_saved.shelter_built and not preview_saved.storage_built and not preview_saved.workbench_built)
	_key(game, KEY_ESCAPE)
	assert(not bool(game.get("building_mode")) and game.get("build_preview") == null)
	game.call("_start_workshop_home_template")
	game.call("_start_basic_shelter_template")
	assert(str(game.get("build_type")) == "shelter" and _owned(game) == gathered, "switching templates is free and atomic")
	_key(game, KEY_ESCAPE)
	game.call("_start_workshop_home_template")
	for invalid in [Vector3(20, 0.12, 20), Vector3(INF, 0.12, 0), Vector3(-1, 0.12, -0.5)]:
		assert(not bool(game.call("_try_place_workshop_home_template", invalid)), "unsafe three-object footprint must reject")
		assert(_owned(game) == gathered)
		_empty(game)
	assert(bool(game.call("_is_valid_workshop_home_template_position", origin)), "default layout must fit an empty starter deck")
	# Diagnostic only: this is one prospective validation call (both actor radii),
	# not frame time/FPS and not a flaky timing threshold in the acceptance gate.
	var validation_times: Array[int] = []
	for sample in range(50):
		var started_usec := Time.get_ticks_usec()
		var layout_error := str(game.call("_home_template_layout_error", origin, true))
		validation_times.append(Time.get_ticks_usec() - started_usec)
		assert(layout_error.is_empty(), "timed prospective validation must evaluate the valid real scene")
	validation_times.sort()
	print("WORKSHOP_PROSPECTIVE_VALIDATION_USEC: calls=50 radii=0.23,0.38 p50=%d p95=%d max=%d (validation call only; not frame/FPS)" % [validation_times[24], validation_times[47], validation_times[49]])
	(game.get("player") as Node3D).position = Vector3(2.0, 1.1, 1.5)
	assert(not bool(game.call("_try_place_workshop_home_template", origin)), "a prospective crate must not trap the player")
	assert(_owned(game) == gathered)
	(game.get("player") as Node3D).position = Vector3(-1.5, 1.1, 0.0)
	assert(not bool(game.call("_try_place_workshop_home_template", origin)), "prospective shelter wall must not enclose the player")
	assert(_owned(game) == gathered)
	_helm_position(game)
	assert(bool(game.call("_try_place_workshop_home_template", origin)))
	assert(int(game.get("wood")) == 1 and int(game.get("stored_wood")) == 0)
	assert(int(game.call("_resident_capacity")) == 2 and not bool(game.get("raft_extension_built")) and not bool(game.get("guest_cabin_built")), "template must not invent extra beds or resident capacity")
	var built := _owned(game)
	assert(int(built.construction_sequence) == int(gathered.construction_sequence) + 1, "all three structures must share one atomic construction command")
	for id in ["shelter", "storage", "workbench"]:
		assert(bool(game.get(id + "_built")) and bool(built.construction.structures[id].built))
	for id in ["storage", "workbench"]:
		assert(bool(game.get(id + "_collision_enabled")), "new validated furniture must be solid")
		var spot: Vector3 = game.get(id + "_position")
		var half: Vector2 = Placement.half_size(id, int(game.get(id + "_quarter_turns")))
		assert(Placement.supported(spot, half), "entire solid footprint must stay on deck")
		assert(not Placement.overlaps(spot, half, (game.get_node("ArkRoot/LanternMarker") as Node3D).position, Vector2(0.18, 0.18)), "template must preserve the fixed lamp")
	assert(not bool(game.call("_try_place_workshop_home_template", origin)) and _owned(game) == built, "repeat confirmation cannot charge or duplicate")
	_interact(game, "resident")
	_interact(game, "resident")
	_key(game, KEY_1)
	assert(bool(game.get("traveler_boarded")), "real invitation must enable onboard resident route checks")
	game.call("_abort_resident_gathering", "template_route_test")
	await physics_frame
	for id in ["hearth", "cot", "storage", "workbench"]:
		_route_to_function(game, id)
	_interact(game, "storage")
	assert(int(game.get("wood")) == 0 and int(game.get("stored_wood")) == 1)
	_interact(game, "storage")
	assert(int(game.get("wood")) == 1 and int(game.get("stored_wood")) == 0)
	_interact(game, "shellfish")
	var raw_before: int = game.get("raw_shellfish")
	_interact(game, "hearth")
	assert(int(game.get("raw_shellfish")) == raw_before - 1 and int(game.get("stew_servings")) == 1)
	var period_before: int = game.get("day_period")
	_interact(game, "cot")
	assert(int(game.get("day_period")) != period_before, "template cot must support real rest")
	game.set("ancient_parts", 1) # Isolated upgrade fixture, not construction funding.
	_interact(game, "workbench")
	assert(bool(game.get("lantern_tuned")) and int(game.get("ancient_parts")) == 0)
	var inventory_before: Dictionary = _owned(game).economy
	# Move the resident away from edit safety checks.
	(game.get("traveler_marker") as Node3D).position = Vector3(0.0, 0.12, 0.0)
	for id in ["storage", "workbench"]:
		await _move_fixture(game, id)
	assert(_owned(game).economy == inventory_before, "editing cannot charge/refund resources")
	var positions := {"shelter": game.get("shelter_position"), "storage": game.get("storage_position"), "workbench": game.get("workbench_position")}
	_interact(game, "helm")
	assert(bool(game.get("sailing_mode")))
	var ark := game.get_node("ArkRoot") as Node3D
	var start := ark.position
	assert(bool(game.call("_sail_step", 0.5, -1.0, 0.2)))
	assert(ark.position.distance_to(start) > 0.1)
	_key(game, KEY_E)
	assert(not bool(game.get("sailing_mode")))
	var sailed_position := ark.position
	for id in positions:
		assert((game.get(id + "_position") as Vector3).is_equal_approx(positions[id]))
	assert(bool(game.call("_save_progress")))
	var saved_owned := _owned(game)
	game.queue_free()
	await process_frame
	game = await _spawn()
	assert(not game.get_meta("save_load_blocked", false))
	var restored := _owned(game)
	assert(restored.economy == saved_owned.economy, "recreation must preserve every resource owner, source and receipt")
	assert(restored.construction == saved_owned.construction, "unchanged JSON reload must preserve construction ownership, receipt count and exact original receipts")
	assert(restored.construction_sequence == saved_owned.construction_sequence, "unchanged JSON reload must not fabricate a synthetic move command")
	# Gathering generation is deliberately renewed on restore; construction is not.
	for repeat in range(3):
		var repeated := _owned(game)
		assert(repeated.construction == saved_owned.construction and repeated.construction_sequence == saved_owned.construction_sequence, "repeated snapshots must be read-only for unchanged construction")
		assert(repeated.economy == saved_owned.economy, "repeated snapshots must not rewrite material ownership")
	assert((game.get_node("ArkRoot") as Node3D).position.is_equal_approx(sailed_position))
	assert(bool(game.get("lantern_tuned")))
	for id in positions:
		assert((game.get(id + "_position") as Vector3).is_equal_approx(positions[id]))
	for id in ["storage", "workbench"]:
		assert(int(game.get(id + "_quarter_turns")) == 1 and bool(game.get(id + "_collision_enabled")))
	game.queue_free()
	await process_frame
	saves.clear_for_test()
	# Regression: five-wood template formerly put its new crate over an existing bench.
	game = await _spawn()
	game.set("wood", 20)
	assert(bool(game.call("_try_place_workbench", Vector3(2.0, 0.12, -1.5))))
	_helm_position(game)
	var occupied := _owned(game)
	assert(not bool(game.call("_try_place_starter_home_template", origin)))
	assert(_owned(game) == occupied and not bool(game.get("shelter_built")) and not bool(game.get("storage_built")))
	assert(not bool(game.call("_try_place_workshop_home_template", origin)) and _owned(game) == occupied)
	game.queue_free()
	await process_frame
	saves.clear_for_test()
	print("ARK_WORKSHOP_HOME_TEMPLATE_TEST_OK: real opening stock; HUD/three ghosts; cancel/switch/save atomicity; invalid/player/occupied/repeat rejection; one seven-wood owner transaction; function interactions and real resident routes; solid editable fixtures; sailing/recreation")
	quit()
