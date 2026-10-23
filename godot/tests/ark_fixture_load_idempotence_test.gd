extends SceneTree

## Storage/workbench reconstruction is replacement, never a build/refund action.
## Synthetic presence variants below use isolated test saves and the existing
## serializer's module-compatible move bridge. No personal slot is read/written.
## Historical #48 logged same-live growth as a caveat, not a desired contract.
const Paths = preload("res://tests/ark_test_paths.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
const FIXTURES := {"storage": ["BuiltStorage", "StorageInteractable", "Body", "Lid", "FrontHandle"], "workbench": ["BuiltWorkbench", "WorkbenchInteractable", "Legs", "Top", "SpiritSocket"]}
var game: Node3D
var saves: RefCounted
var save_root: String
var failures := 0
var assertions := 0
var observations: Array = []
var states := {}
var references := {}
var source_save_bytes := ""

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("FIXTURE_LOAD_IDEMPOTENCE: " + label)

func _settle() -> void:
	await process_frame
	await physics_frame
	await process_frame

func _spawn() -> void:
	game = load("res://scenes/ark_greybox.tscn").instantiate() as Node3D
	game.set("save_root_override", save_root)
	root.add_child(game)
	_freeze()
	await _settle()

func _freeze() -> void:
	# Freeze simulation callbacks, not PROCESS_MODE_DISABLED: that mode removes
	# CollisionObject3D bodies from physics space and would fake collision QA.
	game.set_process(false)
	game.set_physics_process(false)
	(game.get("player") as Node).set_physics_process(false)

func _drop() -> void:
	if is_instance_valid(game):
		game.set("save_service", null)
		game.queue_free()
	game = null
	await _settle()

func _write_state(state: Dictionary) -> void:
	saves.clear_for_test()
	_check(bool(saves.save_state(state).get("ok", false)), "synthetic compatible save must pass envelope/schema validation")
	source_save_bytes = FileAccess.get_file_as_string(saves.get_save_path())

func _plain(value: Variant) -> Variant:
	if value is Vector3:
		return [_plain(value.x), _plain(value.y), _plain(value.z)]
	if value is Transform3D:
		return [_plain(value.basis.x), _plain(value.basis.y), _plain(value.basis.z), _plain(value.origin)]
	if value is float:
		return snappedf(value, 0.000001)
	if value is Array:
		var result: Array = []
		for item in value: result.append(_plain(item))
		return result
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = _plain(value[key])
		return result
	return value

func _semantics() -> Dictionary:
	var result: Dictionary = game.call("_build_save_state")
	# Existing loader presentation, schema migration, and task-token invalidation.
	# Everything else (including the exact key set) is compared to fresh loading.
	result.erase("schema_version")
	result.erase("message")
	result.modules.gathering.erase("generation")
	return _plain(result)

func _stable_path(node: Node) -> String:
	var parts: Array[String] = []
	while node != game:
		var part := str(node.name)
		if part.begins_with("@"):
			var index := 0
			for sibling in node.get_parent().get_children():
				if sibling == node: break
				if str(sibling.name).begins_with("@") and sibling.get_class() == node.get_class(): index += 1
			part = node.get_class() + "#%d" % index
		parts.push_front(part)
		node = node.get_parent()
	return "/".join(parts)

func _graph() -> Dictionary:
	var rows: Array = []
	var bodies := 0
	var shapes := 0
	var queued := 0
	for node in game.find_children("*", "", true, false):
		var row := {"path": _stable_path(node), "class": node.get_class()}
		if node.is_queued_for_deletion(): queued += 1
		if node is Node3D:
			row.transform = _plain(node.transform)
			row.visible = node.visible
		if node is CollisionObject3D:
			bodies += 1
			row.layer = node.collision_layer
			row.mask = node.collision_mask
		if node is CollisionShape3D:
			shapes += 1
			row.disabled = node.disabled
			row.shape = node.shape.get_class() if node.shape else "null"
			if node.shape is BoxShape3D: row.size = _plain(node.shape.size)
		if node is MeshInstance3D:
			row.mesh = node.mesh.get_class() if node.mesh else "null"
			if node.mesh:
				row.bounds_position = _plain(node.mesh.get_aabb().position)
				row.bounds_size = _plain(node.mesh.get_aabb().size)
		rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.path < b.path)
	var entries: Array = []
	for entry in game.get("interactables"):
		var node: Node = entry.get("node")
		entries.append({"id": str(entry.get("id", "")), "item": str(entry.get("item_id", "")), "path": _stable_path(node) if is_instance_valid(node) and game.is_ancestor_of(node) else "INVALID"})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return JSON.stringify(a) < JSON.stringify(b))
	return {"nodes": rows.size(), "bodies": bodies, "shapes": shapes, "queued": queued, "rows": rows, "interactions": entries}

func _anchors() -> Dictionary:
	var result := {}
	for field in ["player", "ark_root", "traveler_marker", "sailmaker_marker", "jade_sail_keeper_marker", "surface_sample"]:
		var value: Object = game.get(field)
		result[field] = value.get_instance_id() if is_instance_valid(value) else 0
	for path in ["Sea", "IslandLandmass", "Camera3D"]:
		var node := game.get_node_or_null(path)
		result[path] = node.get_instance_id() if node else 0
	return result

func _owned_ids() -> Array[int]:
	var result: Array[int] = []
	for id in FIXTURES:
		for index in [0, 1]:
			var node := game.get_node_or_null("ArkRoot/" + FIXTURES[id][index])
			if node:
				result.append(node.get_instance_id())
				for child in node.find_children("*", "", true, false): result.append(child.get_instance_id())
	return result

func _retired(ids: Array[int], settled: bool, label: String) -> void:
	for id in ids:
		var node := instance_from_id(id) as Node
		if settled:
			_check(node == null, label + " retired fixture/marker descendant must be freed, not queued detritus")
		elif is_instance_valid(node):
			_check(not node.is_inside_tree() and not game.is_ancestor_of(node), label + " old fixture node must leave scene immediately")
			if node is Node3D: _check(not node.is_visible_in_tree(), label + " old visual must be invisible immediately")
			if node is CollisionObject3D:
				_check(PhysicsServer3D.body_get_space(node.get_rid()) == RID(), label + " old body must leave physics space immediately")
		for entry in game.get("interactables"):
			var marker: Node = entry.get("node")
			_check(not is_instance_valid(marker) or marker.get_instance_id() != id, label + " registry must not reference retired marker")

func _fixture_contract(saved: Dictionary, label: String) -> void:
	var ark := game.get_node("ArkRoot") as Node3D
	for id in FIXTURES:
		var built: bool = saved[id + "_built"]
		var model := ark.get_node_or_null(FIXTURES[id][0]) as Node3D
		var marker := ark.get_node_or_null(FIXTURES[id][1]) as Node3D
		# Independent ownership recognition catches renamed duplicate roots too.
		var owned_roots := 0
		for candidate in ark.get_children():
			if candidate.has_node(FIXTURES[id][2]) and candidate.has_node(FIXTURES[id][3]) and candidate.has_node(FIXTURES[id][4]):
				owned_roots += 1
				for body in candidate.get_children():
					if body is StaticBody3D:
						var expected_layer := 1 if bool(saved[id + "_collision_enabled"]) else 0
						_check(built and body.collision_layer == expected_layer and body.collision_mask == expected_layer, label + " ALL surviving owned bodies obey saved collision flag, including renamed roots: " + str(candidate.name) + "/" + str(body.name))
		_check(owned_roots == (1 if built else 0), label + " signature-based ownership finds exactly saved model count: " + id)
		var entries: Array = []
		for entry in game.get("interactables"):
			if str(entry.get("id", "")) == id: entries.append(entry)
		_check((model != null) == built and (marker != null) == built, label + " exact " + id + " roots match saved presence")
		_check(entries.size() == (1 if built else 0), label + " unique " + id + " interaction registration")
		_check(bool(game.get(id + "_built")) == built, label + " built flag restored for " + id)
		if not built or model == null or marker == null: continue
		_check(model.get_child_count() == 3 and model.find_children("*", "", true, false).size() == 8, label + " model has exactly its original nine nodes: " + id)
		_check(marker.get_child_count() == 1 and marker.get_node_or_null("Name") is Label3D, label + " marker has exactly two nodes: " + id)
		_check(entries.size() == 1 and entries[0].node == marker, label + " interaction refers to the current marker")
		var p: Dictionary = saved[id + "_position"]
		var position := Vector3(p.x, p.y, p.z)
		var turns := int(saved[id + "_quarter_turns"])
		_check(model.position.is_equal_approx(position), label + " saved local position restored: " + id)
		_check(marker.position.is_equal_approx(position + Vector3(0, 0.5, 0)), label + " marker follows saved local position: " + id)
		_check(is_equal_approx(wrapf(model.rotation.y, 0, TAU), turns * PI / 2), label + " saved rotation restored: " + id)
		_check(is_equal_approx(wrapf(marker.rotation.y, 0, TAU), turns * PI / 2), label + " marker rotation restored: " + id)
		_check(model.global_position.is_equal_approx(ark.to_global(position)), label + " model remains in ark-local space")
		var body_count := 0
		var shape_count := 0
		var enabled: bool = saved[id + "_collision_enabled"]
		for child in model.get_children():
			_check(str(child.name) in FIXTURES[id].slice(2), label + " original fixture child names retained")
			if child is StaticBody3D:
				body_count += 1
				_check((child.collision_layer != 0) == enabled and (child.collision_mask != 0) == enabled, label + " restored collision policy for " + id)
				_check(PhysicsServer3D.body_get_space(child.get_rid()) == game.get_world_3d().space, label + " current body in live physics space")
			for descendant in child.get_children():
				if descendant is CollisionShape3D: shape_count += 1
		_check(body_count == 2 and shape_count == 2, label + " exactly two original collision bodies/shapes per fixture")
	# Direct anonymous Node3D roots are the actual pre-fix collision-name symptom.
	# Anonymous child meshes are normal and are deliberately not banned.
	for child in ark.get_children():
		_check(not (child.get_class() == "Node3D" and str(child.name).begins_with("@")), label + " no renamed stale @Node3D fixture/marker roots")
	for entry in game.get("interactables"):
		var node: Node = entry.get("node")
		_check(is_instance_valid(node) and node.is_inside_tree() and game.is_ancestor_of(node) and not node.is_queued_for_deletion(), label + " every interaction has a valid live scene reference")
	var nav: RefCounted = game.get("vessel_navigation")
	_check(nav.get("_vessel") == ark, label + " navigation keeps the current ark binding")
	for body in (nav.get("_bodies") as Dictionary).values():
		_check(is_instance_valid(body) and body.is_inside_tree() and game.is_ancestor_of(body), label + " navigation body binding remains valid")
	_check(game.get_node_or_null("ArkRoot/BuiltShelter") != null, label + " unrelated shelter survives")
	for id in ["cot", "hearth"]:
		var count := 0
		for entry in game.get("interactables"):
			if entry.id == id: count += 1
		_check(count == 1, label + " exactly one unrelated " + id + " interaction")

func _collision_witnesses() -> Array:
	var result: Array = []
	for id in FIXTURES:
		for candidate in game.get_node("ArkRoot").get_children():
			if candidate.has_node(FIXTURES[id][2]) and candidate.has_node(FIXTURES[id][3]) and candidate.has_node(FIXTURES[id][4]):
				for body in candidate.get_children():
					if body is StaticBody3D:
						result.append({"fixture": id, "root": str(candidate.name), "path": str(game.get_path_to(body)), "instance_id": body.get_instance_id(), "layer": body.collision_layer, "mask": body.collision_mask, "in_physics_space": PhysicsServer3D.body_get_space(body.get_rid()) == game.get_world_3d().space, "saved_enabled": bool(game.get(id + "_collision_enabled")), "saved_built": bool(game.get(id + "_built"))})
	return result

func _capture(label: String) -> Dictionary:
	var graph := _graph()
	var record := {"semantics": _semantics(), "graph": graph}
	observations.append({"label": label, "nodes": graph.nodes, "bodies": graph.bodies, "shapes": graph.shapes, "queued": graph.queued, "interactions": graph.interactions.size(), "fixture_bodies": _collision_witnesses()})
	print("FIXTURE_LOAD_COUNTS ", label, " nodes=", graph.nodes, " bodies=", graph.bodies, " shapes=", graph.shapes, " queued=", graph.queued, " interactions=", graph.interactions.size())
	return record

func _matches(key: String, label: String) -> void:
	var actual := _capture(label)
	var expected: Dictionary = references[key]
	_check(actual.graph == expected.graph, label + " entire attached graph, transforms, geometry, collision and interaction membership equal fresh load")
	_check(actual.graph.queued == 0, label + " attached queued nodes cannot count as success")
	_check(actual.semantics == expected.semantics, label + " full saved semantics equal fresh load; no duplicate inventory/history/refund/module receipts")
	_fixture_contract(states[key], label)

func _interact(id: String) -> void:
	for entry in game.get("interactables"):
		if str(entry.id) == id:
			(game.get("player") as Node3D).global_position = entry.node.global_position + Vector3.UP * 0.15
			game.call("_interact")
			return
	_check(false, "fixture setup requires real interaction " + id)

func _edit(id: String, turns: int) -> void:
	(game.get("player") as Node3D).position = Vector3(0, 1.1, 1.75)
	_check(bool(game.call("_start_fixture_edit", id)), "start existing fixture edit")
	var old: Vector3 = game.get(id + "_position")
	for z in [-1.5, 1.5, -1.0, 1.0, 0.0]:
		for x in [-2.0, 2.0, -2.5, 2.5]:
			var point := Vector3(x, 0.12, z)
			if point.distance_to(old) > 0.25 and str(game.call("_fixture_placement_error", id, point, turns)).is_empty():
				_check(bool(game.call("_try_move_fixture", point, turns)), "actual move commits edited pose/collision with zero material cost")
				return
	_check(false, "fixture must have a legal edited pose: " + id)
	game.call("_cancel_build", false)

func _make_states() -> void:
	saves.clear_for_test()
	await _spawn()
	for _index in range(3):
		_interact("wood")
		await _settle()
	_check(int(game.get("wood")) == 8, "real finite wood collections fund setup")
	(game.get("player") as Node3D).position = Vector3(0, 1.1, 1.75)
	_check(bool(game.call("_try_place_workshop_home_template", Vector3(0, 0.12, 0))), "build real seven-wood home template")
	_interact("resident")
	_interact("shellfish")
	(game.get("player") as Node3D).position = Vector3(0.25, 1.1, 1.2)
	states.both = game.call("_build_save_state")
	var inventory := [game.get("wood"), game.get("stored_wood"), game.get("raw_shellfish")]
	_edit("storage", 3)
	await _settle()
	_edit("workbench", 1)
	_check(inventory == [game.get("wood"), game.get("stored_wood"), game.get("raw_shellfish")], "real pose edits do not consume or refund inventory")
	(game.get("player") as Node3D).position = Vector3(0.25, 1.1, 1.2)
	await _settle()
	states.edited = game.call("_build_save_state")
	# The serializer records these explicit synthetic presence changes through
	# its existing compatible module bridge. This is not claimed as gameplay.
	for item in [["neither", false, false], ["storage", true, false], ["workbench", false, true], ["both_alternate", true, true]]:
		game.set("storage_built", item[1])
		game.set("workbench_built", item[2])
		states[item[0]] = game.call("_build_save_state")
	# Legacy nonblocking placement is supported save state, not a new policy.
	game.set("storage_collision_enabled", false)
	game.set("workbench_collision_enabled", false)
	states.nonblocking = game.call("_build_save_state")
	game.set("storage_collision_enabled", true)
	states.mixed_collision = game.call("_build_save_state")
	_check(not bool(states.nonblocking.storage_collision_enabled) and not bool(states.nonblocking.workbench_collision_enabled) and bool(states.edited.storage_collision_enabled) and bool(states.edited.workbench_collision_enabled), "matrix explicitly covers both saved collision flag values for both fixtures")
	var legacy: Dictionary = states.edited.duplicate(true)
	legacy.schema_version = 35
	for field in ["sailmaker_awning_phase", "sailmaker_awning_sewing_elapsed", "sailmaker_awning_install_elapsed"]: legacy.erase(field)
	states.schema35 = legacy
	await _drop()
	for key in states:
		_write_state(states[key])
		await _spawn()
		_check(not bool(game.get_meta("save_load_blocked", false)), key + " fresh reference accepts normal validated save")
		_fixture_contract(states[key], key + " fresh")
		references[key] = _capture(key + " fresh")
		await _drop()

func _same_and_alternating() -> void:
	_write_state(states.both)
	await _spawn()
	var anchors := _anchors()
	for key in ["both", "both", "both", "nonblocking", "nonblocking", "nonblocking", "mixed_collision", "edited", "neither", "neither", "storage", "storage", "workbench", "both_alternate", "schema35", "neither", "schema35", "edited", "both"]:
		_write_state(states[key])
		var retired := _owned_ids()
		_seed_stale_routes()
		game.call("_load_progress")
		_routes_cleared(key)
		_retired(retired, false, key + " immediate")
		_matches(key, key + " immediate")
		_check(_anchors() == anchors, key + " load preserves unrelated player/residents/sea/island/ark/helper identity")
		_check(FileAccess.get_file_as_string(saves.get_save_path()) == source_save_bytes, key + " successful load does not rewrite or duplicate save transactions")
		await _settle()
		_retired(retired, true, key + " settled")
		_matches(key, key + " settled")
	# An open preview is unsaved transient state, not a second fixture.
	for id in ["storage", "workbench"]:
		_write_state(states.edited)
		game.call("_load_progress")
		await _settle()
		_check(bool(game.call("_start_fixture_edit", id)), "open preview before compatible load")
		var preview: Node3D = game.get("build_preview")
		var preview_id := preview.get_instance_id()
		game.call("_rotate_fixture_preview")
		var before := _owned_ids()
		_write_state(states.neither)
		game.call("_load_progress")
		_check(not bool(game.get("building_mode")) and str(game.get("editing_fixture_id")).is_empty() and game.get("build_preview") == null, "load clears only obsolete fixture selection/preview")
		_check(instance_from_id(preview_id) == null, "obsolete preview is freed immediately, never visible queued debris")
		_retired(before, false, id + " preview removal")
		_matches("neither", id + " preview immediate")
		await _settle()
		_matches("neither", id + " preview settled")
	await _drop()

func _seed_stale_routes() -> void:
	for field in ["resident_gather_route", "traveler_routine_route", "sailmaker_routine_route"]:
		game.set(field, PackedVector3Array([Vector3(2, 0.12, 1.5), Vector3(2, 0.12, -0.5)]))
	game.set("resident_gather_route_index", 1)
	game.set("traveler_routine_route_target_set", true)
	game.set("sailmaker_routine_route_target_set", true)

func _routes_cleared(label: String) -> void:
	for field in ["resident_gather_route", "traveler_routine_route", "sailmaker_routine_route"]:
		_check((game.get(field) as PackedVector3Array).is_empty(), label + " old fixture layout route must not survive: " + field)
	_check(int(game.get("resident_gather_route_index")) == 0 and not bool(game.get("traveler_routine_route_target_set")) and not bool(game.get("sailmaker_routine_route_target_set")), label + " stale resident route cursor/target invalidated")

func _builder_replacement() -> void:
	_write_state(states.edited)
	await _spawn()
	var anchors := _anchors()
	var semantics := _semantics()
	var graph := _graph()
	# No frame yield in this loop: queue-only cleanup cannot satisfy this gate.
	for iteration in range(12):
		var retired := _owned_ids()
		_seed_stale_routes()
		for id in FIXTURES:
			game.call("_build_" + id + "_at", game.get(id + "_position"))
		_retired(retired, false, "builder burst")
		_retired(retired, true, "builder burst immediate free")
		_fixture_contract(states.edited, "builder burst %d" % iteration)
		_routes_cleared("builder burst")
		_check(_graph() == graph and _anchors() == anchors, "direct builder reentry must preserve whole graph and unrelated identities immediately")
		_check(_semantics() == semantics, "direct builder reentry must not create receipts/refunds/history or change other state")
	await _settle()
	_check(_graph() == graph and _semantics() == semantics, "builder burst remains exact after process and physics settlement")
	observations.append({"label": "builder_burst", "repeats": 12, "nodes": graph.nodes, "bodies": graph.bodies, "queued": graph.queued})
	await _drop()

func _rejected_loads() -> void:
	for kind in ["missing", "corrupt", "future_envelope", "future_schema", "invalid_state", "module_mismatch"]:
		_write_state(states.edited)
		await _spawn()
		_check(bool(game.call("_start_fixture_edit", "storage")), kind + " setup selected fixture")
		var before_ids := _owned_ids()
		var before_graph := _graph()
		var preview: Node3D = game.get("build_preview")
		var preview_id := preview.get_instance_id()
		var before_water: Dictionary = (game.get("water") as RefCounted).snapshot()
		var before_navigation: Dictionary = (game.get("vessel_navigation") as RefCounted).snapshot()
		var navigation_id := (game.get("vessel_navigation") as RefCounted).get_instance_id()
		saves.clear_for_test()
		var raw := "intentionally malformed test bytes"
		if kind not in ["missing", "corrupt"]:
			var state: Dictionary = states.edited.duplicate(true)
			if kind == "future_schema": state.schema_version = 999
			if kind == "invalid_state": state.life_period_elapsed = -1
			if kind == "module_mismatch": state.storage_built = false
			var payload := JSON.stringify(state)
			raw = JSON.stringify({"format": Save.FORMAT, "version": 999 if kind == "future_envelope" else Save.VERSION, "payload": payload, "sha256": payload.sha256_text()})
		if kind != "missing":
			var file := FileAccess.open(saves.get_save_path(), FileAccess.WRITE)
			file.store_string(raw)
			file.close()
		game.call("_load_progress")
		_check(_owned_ids() == before_ids and _graph() == before_graph, kind + " rejected load must not run fixture teardown or alter attached graph")
		_check(bool(game.get("building_mode")) and str(game.get("editing_fixture_id")) == "storage" and is_instance_valid(game.get("build_preview")) and game.get("build_preview").get_instance_id() == preview_id, kind + " rejected load preserves existing selection and preview")
		if kind != "missing": _check(FileAccess.get_file_as_string(saves.get_save_path()) == raw, kind + " unreadable/future source bytes preserved")
		await _settle()
		_check(_owned_ids() == before_ids and _graph() == before_graph, kind + " rejected load remains non-destructive after settling")
		# Observable existing wrapper limitation, NOT a desired behavior assertion.
		# Failed-load water/module lifecycle repair is deliberately outside #49.
		var after_water: Dictionary = (game.get("water") as RefCounted).snapshot()
		var after_navigation: Dictionary = (game.get("vessel_navigation") as RefCounted).snapshot()
		var observation := {"label": "rejected_" + kind, "water_changed": before_water != after_water, "navigation_changed": before_navigation != after_navigation, "navigation_replaced": navigation_id != (game.get("vessel_navigation") as RefCounted).get_instance_id(), "water_before": before_water, "water_after": after_water, "navigation_before": before_navigation, "navigation_after": after_navigation}
		observations.append(observation)
		print("FIXTURE_REJECTED_OBSERVATION ", kind, " water_changed=", observation.water_changed, " navigation_changed=", observation.navigation_changed, " navigation_replaced=", observation.navigation_replaced)
		await _drop()

func _menu_continue() -> void:
	_write_state(states.edited)
	var menu: Node = load("res://scenes/main.tscn").instantiate()
	menu.set("save_root_override", save_root)
	root.add_child(menu)
	current_scene = menu
	await _settle()
	var enter := menu.find_child("ArkEnterButton", true, false) as Button
	_check(enter != null and enter.text == "继续归舟", "normal menu recognizes isolated saved slot")
	if enter == null:
		menu.free()
		return
	enter.pressed.emit()
	enter.pressed.emit()
	# Scene replacement happens at end of frame. Freeze at tree entry, before
	# timers/player physics can add nondeterministic movement to the reference.
	for _frame in range(4):
		await process_frame
		if current_scene is Node3D:
			game = current_scene
			_freeze()
	_check(game != null and game.scene_file_path == "res://scenes/ark_greybox.tscn", "real menu continuation opens fresh Ark scene")
	if game != null:
		await _settle()
		_fixture_contract(states.edited, "normal menu continue")
		_check(str(game.get("save_root_override")) == save_root, "normal menu preserves isolated save path")
		_check(int(game.get("wood")) == int(states.edited.wood) and int(game.get("stored_wood")) == int(states.edited.stored_wood), "normal menu restores stock without duplicate transactions")
		var count := 0
		for child in root.get_children():
			if child.scene_file_path == "res://scenes/ark_greybox.tscn": count += 1
		_check(count == 1, "rapid continuation opens one fresh Ark")
	current_scene = null
	await _drop()
	if has_meta("ark_menu_save_root_override"): remove_meta("ark_menu_save_root_override")

func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/test_fixture_load_idempotence_%d" % OS.get_process_id()).simplify_path()
	_check(Paths.is_safe_save_root(save_root), "all writes restricted to isolated repository-local test path")
	if not Paths.is_safe_save_root(save_root):
		quit(1)
		return
	saves = Save.new(save_root)
	await _make_states()
	await _same_and_alternating()
	await _builder_replacement()
	await _rejected_loads()
	await _menu_continue()
	var evidence := OS.get_environment("ARK_FIXTURE_EVIDENCE_DIR")
	if not evidence.is_empty():
		var file := FileAccess.open(evidence.path_join("test49-observations.json"), FileAccess.WRITE)
		_check(file != null, "requested QA evidence directory must already be writable")
		if file:
			file.store_string(JSON.stringify({"assertions": assertions, "failures": failures, "observations": observations}, "\t", true))
			file.close()
	saves.clear_for_test()
	if failures == 0:
		print("ARK_FIXTURE_LOAD_IDEMPOTENCE_TEST_OK: ", assertions, " checks; same-live replacement, presence/edits, schema35/36, menu, guarded failures")
	else:
		print("ARK_FIXTURE_LOAD_IDEMPOTENCE_TEST_FAILED: ", failures, " / ", assertions)
	quit(0 if failures == 0 else 1)
