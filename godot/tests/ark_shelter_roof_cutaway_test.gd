extends SceneTree

## Independent emitted-geometry / input / lifetime regression, not readability QA.
## Actual renderer captures separately judge whether the unchanged camera reads well.
const Paths = preload("res://tests/ark_test_paths.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
const CENTER_PARTS := ["CenterFace", "RoofRidgeBinding", "RoofCanvasPatch", "RoofCanvasPatchSeam"]
const EAVE_PARTS := ["EaveFront", "EaveBack", "EaveLeft", "EaveRight"]
var game: Node3D
var saves: RefCounted
var save_root: String


func _initialize() -> void:
	_run.call_deferred()


func _spawn() -> void:
	game = load("res://scenes/ark_greybox.tscn").instantiate() as Node3D
	# Raw opaque geometry oracle; production art occlusion has its own test.
	game.set("start_with_home_art", false)
	game.set("save_root_override", save_root)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	_player().set_physics_process(false)
	await physics_frame


func _drop() -> void:
	game.set("save_service", null)
	game.queue_free()
	await process_frame


func _ark() -> Node3D:
	return game.get_node("ArkRoot") as Node3D


func _shelter() -> Node3D:
	return game.get_node("ArkRoot/BuiltShelter") as Node3D


func _roof() -> Node3D:
	return _shelter().get_node("Roof") as Node3D


func _player() -> CharacterBody3D:
	return game.get("player") as CharacterBody3D


func _key(code: Key, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _tap(code: Key) -> void:
	_key(code)
	_key(code, false)


func _stand(local: Vector3) -> void:
	_player().global_position = _shelter().to_global(local)
	_player().velocity = Vector3.ZERO
	game.set("is_swimming", false)
	game.call("_update_shelter_roof_cutaway")


func _assert_visibility(cutaway: bool, damaged: bool = false) -> void:
	var roof := _roof()
	assert(_shelter().is_visible_in_tree(), "cutaway must not hide the shelter root, which resident work uses")
	assert(roof.visible == not damaged, "Roof root visibility belongs to structural damage, not cutaway")
	for id in CENTER_PARTS:
		var part := roof.get_node(id) as MeshInstance3D
		assert(part != null and part.mesh != null, "roof oracle must inspect an actual emitted mesh: " + id)
		assert(part.visible == not cutaway and part.is_visible_in_tree() == (not cutaway and not damaged), "central roof mesh must agree with real visibility: " + id)
	for id in EAVE_PARTS:
		var part := roof.get_node(id) as MeshInstance3D
		assert(part.visible and part.is_visible_in_tree() == not damaged, "narrow eaves remain visible except when damage hides the whole Roof")
	for id in ["Back", "Left", "Right", "Floor", "Cot", "Bedroll", "HearthStone", "CabinFrameDetails", "CabinFrameDetails/EntranceCanvas", "Lamp"]:
		assert((_shelter().get_node(id) as Node3D).is_visible_in_tree(), "cutaway must retain the real home and entrance canopy: " + id)
	var brace := _shelter().get_node_or_null("ReefShellStormBrace") as Node3D
	if brace != null:
		assert(brace.is_visible_in_tree() == (not cutaway and not damaged), "real upgraded shell plates must not float across the open roof or damage")
		for part in brace.get_children():
			assert((part as MeshInstance3D).is_visible_in_tree() == (not cutaway and not damaged))


func _bounds(mesh: MeshInstance3D, reference: Node3D) -> AABB:
	var box := mesh.get_aabb()
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for x in [box.position.x, box.end.x]:
		for y in [box.position.y, box.end.y]:
			for z in [box.position.z, box.end.z]:
				var point := reference.to_local(mesh.to_global(Vector3(x, y, z)))
				minimum = minimum.min(point)
				maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum)


func _assert_roof_geometry() -> void:
	var roof := _roof()
	assert(roof.position.is_equal_approx(Vector3(0, 2.38, 0)) and roof.basis.is_equal_approx(Basis.IDENTITY), "preserve the old roof transform")
	var expected := Rect2(-1.6, -1.3, 3.2, 2.6)
	var rectangles: Array[Rect2] = []
	var area := 0.0
	var envelope := Rect2()
	var names: Array = ["CenterFace"] + EAVE_PARTS
	for id in names:
		var part := roof.get_node(id) as MeshInstance3D
		assert(part.mesh is BoxMesh and part.basis.is_equal_approx(Basis.IDENTITY), "roof coverage must use complete opaque boxes, not misleading AABBs")
		var material := part.material_override
		if material is ShaderMaterial:
			var canvas_path := "res://shaders/ark_home_canvas.gdshader"
			assert(game.get("home_art_sample").enabled and material.shader != null and material.shader.resource_path == canvas_path)
			assert(FileAccess.get_sha256(canvas_path) == "de8cb55192965aa9679d37a15b62410a1f50ac290edda9b23f21bb14d337d099" and material.shader.code == FileAccess.get_file_as_string(canvas_path),"the exact reviewed opaque canvas has no ALPHA/discard/transparency substitution, including cached shader code")
		else:
			assert(material is StandardMaterial3D and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and is_equal_approx(material.albedo_color.a, 1.0), "cutaway must not substitute transparency for opaque exterior geometry")
		var box := _bounds(part, roof)
		assert(is_equal_approx(box.position.y, -0.09) and is_equal_approx(box.size.y, 0.18), "all pieces preserve old roof thickness and height")
		var rect := Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
		assert(expected.grow(0.00001).encloses(rect), "no roof piece may protrude outside the old 3.2 by 2.6 envelope")
		for previous in rectangles:
			assert(rect.intersection(previous).get_area() < 0.00001, "base roof pieces must not overlap in area or z-fight")
		rectangles.append(rect)
		area += rect.get_area()
		envelope = rect if rectangles.size() == 1 else envelope.merge(rect)
	assert(envelope.position.is_equal_approx(expected.position) and envelope.size.is_equal_approx(expected.size), "union of actual geometry must retain the exact old exterior envelope")
	assert(is_equal_approx(area, expected.get_area()), "non-overlapping complete boxes must cover the old roof without gaps")
	assert((_roof().get_node("CenterFace") as MeshInstance3D).mesh.get_aabb().size.is_equal_approx(Vector3(2.84, 0.18, 2.24)), "the hidden face must leave only a narrow rim, not most of the occluding roof")
	assert(roof.find_children("*", "CollisionObject3D", true, false).is_empty(), "visual roof splitting must not create player or NPC collisions")


# Independent visibility oracle for only the explicitly approved HUD whitelist.
# Every unlisted label/actor keeps the original strict visibility comparison.
func _assert_hud_name_visibility() -> Dictionary:
	var presentation: Node = game.get("nearfuture_hud")
	presentation.call("refresh")
	var focus: Node3D = null
	var nearest := 2.8
	for entry in game.get("interactables"):
		var marker := entry.get("node") as Node3D
		if not is_instance_valid(marker):
			continue
		var distance := _player().global_position.distance_to(marker.global_position)
		if distance < nearest:
			nearest = distance
			focus = marker
	var result := {}
	for entry in game.get("interactables"):
		var id := str(entry.get("id", ""))
		if id not in ["home", "helm", "storage", "workbench", "cot", "hearth", "resident", "sailmaker", "tidekeeper_box", "sailmaker_awning", "resident_keepsake", "wood", "shellfish"]:
			continue
		var marker := entry.get("node") as Node3D
		if not is_instance_valid(marker):
			continue
		var sign := marker.get_node_or_null("Name") as Label3D
		if sign == null:
			continue
		var distance := _player().global_position.distance_to(marker.global_position)
		var nearby := (id in ["resident", "sailmaker"] and distance <= 7.0) or (id in ["wood", "shellfish"] and distance <= 4.0)
		var expected := (marker == focus or nearby) and not (game.get("world_chart") as Control).visible
		assert(sign.visible == expected, "approved Name visibility must follow real focus/distance/map state: " + id)
		result[sign.get_instance_id()] = true
	return result


func _preserved_state(ignore_nameplate_lift: bool = false) -> Dictionary:
	var hud_names := _assert_hud_name_visibility()
	var result: Dictionary = {}
	var nodes := _shelter().find_children("*", "Node3D", true, false)
	nodes.append_array(_ark().find_children("*", "Label3D", true, false))
	for marker_name in ["HearthInteractable", "residentMarker", "sailmakerMarker"]:
		var marker := _ark().get_node_or_null(marker_name) as Node3D
		if marker:
			nodes.append(marker)
			nodes.append_array(marker.find_children("*", "Node3D", true, false))
	nodes.append(game.get("camera"))
	for item in nodes:
		var node := item as Node3D
		if node == _roof() or _roof().is_ancestor_of(node) or str(node.get_path()).contains("ReefShellStormBrace"):
			continue
		var pose: Variant = node.basis if ignore_nameplate_lift and _targeted_nameplate(node) else node.transform
		var value: Array = [node.get_instance_id(), pose, "hud-prioritized" if hud_names.has(node.get_instance_id()) else node.visible, node.process_mode]
		if node is CollisionObject3D:
			value.append_array([node.collision_layer, node.collision_mask])
		if node is CollisionShape3D:
			value.append_array([node.disabled, node.shape.get_rid()])
		if node is MeshInstance3D:
			value.append_array([node.mesh.get_instance_id(), node.mesh.get_aabb(), node.material_override])
		if node is Label3D:
			value.append_array([node.text, node.font.get_instance_id(), node.font_size, node.pixel_size, node.width, node.outline_size, node.modulate, node.billboard])
		if node is Camera3D:
			value.append_array([node.fov, node.projection, node.current])
		result[str(node.get_path())] = value
	return result


func _targeted_nameplate(node: Node) -> bool:
	# Only the exact three parent-owned Name nodes have an approved Y exception.
	return node == _ark().get_node_or_null("HearthInteractable/Name") or node == _ark().get_node_or_null("residentMarker/Name") or node == _ark().get_node_or_null("sailmakerMarker/Name")


func _nameplate_rows() -> Array[Dictionary]:
	return [
		{"marker": _ark().get_node("HearthInteractable"), "base": Vector3(0, 0.8, 0), "lane": 3.1},
		{"marker": game.get("traveler_marker"), "base": Vector3(0, 2.7, 0), "lane": 4.2},
		{"marker": game.get("sailmaker_marker"), "base": Vector3(0, 1.85, 0), "lane": 5.3},
	]


func _assert_nameplate_geometry(active: bool) -> void:
	_assert_hud_name_visibility()
	var camera := game.get("camera") as Camera3D
	for row in _nameplate_rows():
		var marker := row.marker as Node3D
		assert(is_instance_valid(marker))
		var sign := marker.get_node("Name") as Label3D
		var base_global := marker.to_global(row.base)
		assert(sign.basis.is_equal_approx(Basis.IDENTITY) and sign.is_inside_tree(), "label lanes retain identity transform and live label; visibility follows the independently asserted HUD policy")
		assert(Vector2(sign.global_position.x, sign.global_position.z).is_equal_approx(Vector2(base_global.x, base_global.z)), "only vertical label lift is authorized; the actor's horizontal label anchor must remain")
		if active:
			var reference := _shelter().global_position + camera.global_basis.y * float(row.lane)
			if camera.is_position_behind(reference):
				assert(sign.position.is_finite() and sign.position.is_equal_approx(row.base) and not sign.has_meta("cutaway_base_position"), "a fresh load before normal camera placement must preserve finite original labels")
			else:
				var projected := camera.unproject_position(sign.global_position).y
				assert(absf(projected - camera.unproject_position(reference).y) < 0.01, "actual projected label Y must match its cabin-anchored lane despite different actor depths")
		else:
			assert(sign.position.is_equal_approx(row.base) and not sign.has_meta("cutaway_base_position"), "leaving/removing/reloading the cabin must restore exact original label offsets without stale presentation state")


func _assert_nameplate_lifecycle() -> void:
	_stand(Vector3(0, 0.2, 2.3))
	game.set("traveler_boarded", true)
	game.call("_set_traveler_boarded")
	var traveler := game.get("traveler_marker") as Node3D
	var sailmaker := game.get("sailmaker_marker") as Node3D
	var originals: Array[Vector3] = [traveler.position, sailmaker.position]
	traveler.position = _shelter().position + Vector3(-0.5, 0, 0.5)
	sailmaker.position = _shelter().position + Vector3(0.65, 0, -0.15)
	_assert_nameplate_geometry(false)
	var unchanged := _preserved_state(true)
	var ownership := _ownership()
	for repeat in range(12):
		_stand(Vector3(0, 0.2, 0))
		_assert_nameplate_geometry(true)
		assert(_preserved_state(true) == unchanged, "only the three approved Name Y offsets and explicitly checked HUD name visibility may change; exact text/font/camera/geometry must remain")
		_stand(Vector3(0, 0.2, 2.3))
		_assert_nameplate_geometry(false)
	assert(_ownership() == ownership, "label presentation must not touch resources, history or construction")
	_stand(Vector3(0, 0.2, 0))
	var sign := traveler.get_node("Name") as Label3D
	traveler.position = Vector3(-2.5, 0.12, 1.5)
	game.call("_update_shelter_roof_cutaway")
	assert(sign.position.is_equal_approx(Vector3(0, 2.7, 0)), "a distant deck resident must retain ordinary labeling")
	traveler.position = _shelter().position + Vector3(-0.5, 0, 0.5)
	game.set("traveler_boarded", false)
	game.call("_update_shelter_roof_cutaway")
	assert(sign.position.is_equal_approx(Vector3(0, 2.7, 0)), "non-boarded actors must not inherit cabin label offsets")
	game.set("traveler_boarded", true)
	game.call("_update_shelter_roof_cutaway")
	traveler.reparent(game, true)
	game.call("_update_shelter_roof_cutaway")
	assert(sign.position.is_equal_approx(Vector3(0, 2.7, 0)), "off-ark gathering/reparenting must restore the original label even at a nearby global point")
	traveler.reparent(_ark(), true)
	traveler.position = _shelter().position + Vector3(-0.5, 0, 0.5)
	game.call("_update_shelter_roof_cutaway")
	_assert_nameplate_geometry(true)
	var ark_pose := _ark().transform
	_ark().position = Vector3(-8, 0, 3)
	_ark().rotation.y = 0.65
	_stand(Vector3(0, 0.2, 0))
	_assert_nameplate_geometry(true)
	_ark().transform = ark_pose
	traveler.position = originals[0]
	sailmaker.position = originals[1]
	_stand(Vector3(0, 0.2, 2.3))
	_assert_nameplate_geometry(false)


func _assert_hysteresis_and_support() -> void:
	_stand(Vector3(0, 0.2, 2.3))
	_assert_visibility(false)
	var preserved := _preserved_state()
	_stand(Vector3(0, 0.2, 1.75))
	_assert_visibility(true)
	for index in range(20):
		_stand(Vector3(0, 0.2, 1.84 if index % 2 == 0 else 1.86))
		_assert_visibility(true)
	_stand(Vector3(0, 0.2, 2.11))
	_assert_visibility(false)
	for index in range(20):
		_stand(Vector3(0, 0.2, 2.09 if index % 2 == 0 else 2.11))
		_assert_visibility(false)
	_stand(Vector3(0, 0.2, 0))
	_assert_visibility(true)
	for local in [Vector3(0, -0.7, 0), Vector3(0, 2.6, 0), Vector3(1.4, 0.2, 0), Vector3(0, 0.2, -1.15)]:
		_stand(local)
		_assert_visibility(false)
		_stand(Vector3(0, 0.2, 0))
		_assert_visibility(true)
	game.set("is_swimming", true)
	game.call("_update_shelter_roof_cutaway")
	_assert_visibility(false)
	game.set("is_swimming", false)
	var original_position := _shelter().position
	_shelter().position = Vector3(2.0, original_position.y, original_position.z)
	_stand(Vector3(1.0, 0.2, 0))
	_assert_visibility(false) # Inside entry region but outside radius-aware deck support.
	_shelter().position = original_position
	assert(_preserved_state() == preserved, "roof toggles must not alter walls/posts/canopy/collisions/camera/labels")


func _walk_ingress_egress(check_nameplates: bool = false) -> void:
	# Actual held W/S input drives the shipped CharacterBody move_and_slide;
	# direct positioning only stages the clear exterior starting point.
	_stand(Vector3(0, 0.2, 2.3))
	for frame in range(5):
		await physics_frame
		game.call("_physics_process", 1.0 / 60.0)
		game.call("_process", 1.0 / 60.0 if check_nameplates else 0.0)
		if check_nameplates:
			_assert_nameplate_geometry(not (_roof().get_node("CenterFace") as MeshInstance3D).visible)
	_assert_visibility(false)
	var start := _player().global_position
	_key(KEY_W)
	var entered := false
	for frame in range(100):
		await physics_frame
		game.call("_physics_process", 1.0 / 60.0)
		game.call("_process", 1.0 / 60.0 if check_nameplates else 0.0)
		if check_nameplates:
			_assert_nameplate_geometry(not (_roof().get_node("CenterFace") as MeshInstance3D).visible)
		var local := _shelter().to_local(_player().global_position)
		if local.z < 0.5:
			entered = true
			break
	_key(KEY_W, false)
	assert(entered and _player().global_position.distance_to(start) > 1.4, "real movement must enter the home, not merely move a fixture for the predicate")
	_assert_visibility(true)
	_key(KEY_S)
	var exited := false
	for frame in range(100):
		await physics_frame
		game.call("_physics_process", 1.0 / 60.0)
		game.call("_process", 1.0 / 60.0 if check_nameplates else 0.0)
		if check_nameplates:
			_assert_nameplate_geometry(not (_roof().get_node("CenterFace") as MeshInstance3D).visible)
		if _shelter().to_local(_player().global_position).z > 2.12:
			exited = true
			break
	_key(KEY_S, false)
	assert(exited, "ordinary collision movement must leave the doorway")
	_assert_visibility(false)


func _assert_jump_at(local_z: float) -> void:
	# Genuine Space input above supported feet must not flash the roof.
	_player().position.z = local_z
	game.call("_process", 1.0 / 60.0)
	_assert_visibility(true)
	_tap(KEY_SPACE)
	var airborne := false
	var peak := _player().position.y
	for frame in range(60):
		await physics_frame
		game.call("_physics_process", 1.0 / 60.0)
		game.call("_process", 1.0 / 60.0)
		airborne = airborne or not _player().is_on_floor()
		peak = maxf(peak, _player().position.y)
		if frame == 5:
			assert(not _player().is_on_floor(), "midair re-jump guard must be exercised above the real deck")
			var velocity_before := _player().velocity.y
			_tap(KEY_SPACE)
			assert(is_equal_approx(_player().velocity.y, velocity_before), "another Space press must not replenish an airborne jump")
		if not (_roof().get_node("CenterFace") as MeshInstance3D).visible:
			_assert_visibility(true)
			_assert_nameplate_geometry(true)
		else:
			print("ROOF_EDGE_JUMP_DIAGNOSTIC: frame=", frame, " local=", _shelter().to_local(_player().global_position), " floor=", _player().is_on_floor(), " swimming=", game.get("is_swimming"))
			assert(false, "ordinary airborne doorway movement must retain the already-open roof above supported deck")
	assert(airborne and peak > 0.5 and _player().is_on_floor(), "Space input must actually jump and land, not only toggle presentation state")
	print("ROOF_JUMP_OBSERVATION: z=%.2f peak_ark_y=%.6f landed=true cutaway_retained=true" % [local_z, peak])


func _assert_default_deck_edge_hysteresis() -> void:
	# A full player radius reaches the starter deck edge at z=1.87, before
	# the doorway's held-state exit. Feet are still physically grounded here.
	_stand(Vector3(0, 0.2, 1.75))
	for frame in range(16):
		await physics_frame
		game.call("_physics_process", 1.0 / 60.0)
		game.call("_process", 1.0 / 60.0)
	_assert_visibility(true)
	_player().position.z = 1.86
	for cycle in range(6):
		for code in [KEY_S, KEY_W]:
			_key(code)
			await physics_frame
			game.call("_physics_process", 1.0 / 60.0)
			game.call("_process", 1.0 / 60.0)
			_key(code, false)
			assert(_player().is_on_floor() and not bool(game.get("is_swimming")), "edge jitter fixture must genuinely remain grounded")
			_assert_visibility(true)
			_assert_nameplate_geometry(true)
	await _assert_jump_at(1.9)
	await _assert_jump_at(0.0)
	# Retention is not permission to keep the roof hidden after losing support.
	_player().position = Vector3(0, -0.8, 1.9)
	_player().velocity = Vector3.ZERO
	for frame in range(2):
		await physics_frame
		game.call("_physics_process", 1.0 / 60.0)
		game.call("_process", 1.0 / 60.0)
	assert(not _player().is_on_floor())
	_assert_visibility(false)


func _assert_swim_and_return() -> void:
	# Stage only the offshore starting fixture, then use real swim/Space/W input.
	_player().position = Vector3(0, -1.6, 4.1)
	_player().velocity = Vector3.ZERO
	for frame in range(8):
		await physics_frame
		game.call("_physics_process", 1.0 / 60.0)
		game.call("_process", 0.0)
	assert(bool(game.get("is_swimming")) and not _player().is_on_floor(), "offshore fixture must actually enter swimming")
	_assert_visibility(false)
	var before := _player().position
	_key(KEY_S)
	for frame in range(10):
		await physics_frame
		game.call("_physics_process", 1.0 / 60.0)
		game.call("_process", 0.0)
	_key(KEY_S, false)
	assert(_player().position.z > before.z + 0.1 and bool(game.get("is_swimming")), "ordinary S input must still swim, without a grounded launch regression")
	_key(KEY_W)
	var returned := false
	var swim_launched := false
	for attempt in range(5):
		_tap(KEY_SPACE)
		swim_launched = swim_launched or _player().velocity.y > 8.0
		for frame in range(55):
			await physics_frame
			game.call("_physics_process", 1.0 / 60.0)
			game.call("_process", 0.0)
			if _player().is_on_floor() and _player().position.z <= 1.6:
				returned = true
				break
		if returned:
			break
	_key(KEY_W, false)
	assert(swim_launched and returned and not bool(game.get("is_swimming")), "Space-assisted swimming must physically return over the existing gangplank onto the real deck")
	_assert_visibility(true)


func _assert_inputs() -> void:
	_stand(Vector3(-0.7, 0.2, -0.5))
	_assert_visibility(true)
	game.set("raw_shellfish", 1)
	var servings := int(game.get("stew_servings"))
	_tap(KEY_E)
	assert(int(game.get("raw_shellfish")) == 0 and int(game.get("stew_servings")) == servings + 1, "E must still dispatch to the actual hearth beneath the open roof")
	_stand(Vector3(0.9, 0.2, 0))
	_tap(KEY_F)
	assert(bool(game.get("building_mode")) and str(game.get("editing_fixture_id")) == "storage", "F must still select nearby real storage while under the cutaway")
	_tap(KEY_ESCAPE)
	assert(not bool(game.get("building_mode")))
	_stand(Vector3(0, 0.2, 0))
	_tap(KEY_H)
	assert((game.get("hud_drawer") as Control).visible)
	_tap(KEY_ESCAPE)
	assert(not (game.get("hud_drawer") as Control).visible)
	_tap(KEY_M)
	assert((game.get("world_chart") as Control).visible)
	_tap(KEY_F5)
	assert((game.get("save_status_notice") as Label).is_visible_in_tree(), "F5 status must remain above the chart")
	_tap(KEY_ESCAPE)
	assert(not (game.get("world_chart") as Control).visible)
	game.set("player_health", 1)
	game.set("cold_exposure_level", 3)
	game.set_meta("save_warning", "存档写入失败，旧档已保留；本次进度尚未保存。")
	game.call("_update_hud")
	assert((game.get("hud") as Label).text.contains("生命 1/4") and (game.get("save_status_notice") as Label).is_visible_in_tree(), "roof openness must not suppress health/cold/save warning UI")
	_tap(KEY_H)
	assert((game.get("save_status_notice") as Label).is_visible_in_tree())
	_tap(KEY_ESCAPE)
	game.remove_meta("save_warning")
	game.set("player_health", 4)
	game.set("cold_exposure_level", 0)
	_assert_visibility(true)


func _assert_damage_and_repair() -> void:
	_stand(Vector3(0, 0.2, 0))
	game.set("rope_use", "raft")
	game.call("_apply_storm_damage")
	_assert_visibility(true, true)
	_stand(Vector3(0, 0.2, 2.3))
	_assert_visibility(false, true)
	_stand(Vector3(0, 0.2, 0))
	game.set("repair_choice_pending", true)
	var wood := int(game.get("wood"))
	game.call("_repair_damaged_part", "shelter")
	assert(not bool(game.get("shelter_roof_damaged")) and int(game.get("wood")) == wood - 1)
	_assert_visibility(true)
	_stand(Vector3(0, 0.2, 2.3))
	_assert_visibility(false)


func _assert_npc_work() -> void:
	game.set("sailmaker_met", true)
	game.set("sailmaker_boarded", true)
	game.set("sailmaker_joined_day", 1)
	game.set("day_count", 2)
	game.set("day_period", 0)
	game.set("weather_phase", 2)
	game.call("_set_sailmaker_boarded")
	var resident := game.get("sailmaker_marker") as Node3D
	resident.position = game.call("_sailmaker_awning_work_target", false)
	game.set("sailmaker_awning_phase", "sewing")
	game.set("sailmaker_awning_sewing_elapsed", 0.0)
	_stand(Vector3(0, 0.2, 0))
	_assert_visibility(true)
	assert(bool(game.call("_sailmaker_awning_work_can_run")), "hiding central roof meshes must not make the visible shelter invalid for work")
	for step in range(4):
		game.call("_process", 0.1)
	assert(float(game.get("sailmaker_awning_sewing_elapsed")) >= 0.39 and resident.is_visible_in_tree(), "actual sewing progress must continue with a visible resident while the roof is open")
	game.set("day_period", 3) # Pause work for unrelated lifetime/geometry checks.


func _assert_brace() -> void:
	(game.get("learned_blueprint_ids") as Array).append("reef_shell_storm_brace")
	game.set("reef_beast_defeated", true)
	game.set("reef_shell_plates", 1)
	_stand(Vector3(0, 0.2, 0))
	game.call("_apply_storm_damage") # Install over a genuinely damaged roof, not a fabricated hidden node.
	_assert_visibility(true, true)
	game.call("_install_reef_shell_brace")
	assert(bool(game.get("reef_shell_brace_installed")))
	var brace := _shelter().get_node("ReefShellStormBrace") as Node3D
	assert(brace.get_child_count() == 7, "preserve all five shell plates and both lashings")
	for index in range(5):
		var plate := brace.get_node("ShellPlate_%d" % index) as MeshInstance3D
		assert((plate.mesh as BoxMesh).size.is_equal_approx(Vector3(0.42, 0.055, 2.28)), "upgrade plates cannot shrink to fake openness")
	_assert_visibility(true, true)
	_stand(Vector3(0, 0.2, 2.3))
	_assert_visibility(false, true)
	_stand(Vector3(0, 0.2, 0))
	game.set("repair_choice_pending", true)
	game.call("_repair_damaged_part", "shelter")
	game.call("_process", 0.0)
	_assert_visibility(true)
	_stand(Vector3(0, 0.2, 2.3))
	_assert_visibility(false)
	game.call("_apply_storm_damage")
	assert(not bool(game.get("shelter_roof_damaged")), "roof cutaway must preserve installed storm protection")


func _assert_one_shelter() -> void:
	var count := 0
	for node in _ark().find_children("*", "Node3D", true, false):
		if node.get_node_or_null("Roof/CenterFace") != null:
			count += 1
	assert(count == 1, "reload must not leave a duplicate opaque shelter/roof behind the canonical one")
	for id in ["cot", "hearth", "sailmaker_awning", "resident_keepsake"]:
		var markers := 0
		for entry in game.get("interactables") as Array:
			if str(entry.get("id", "")) == id:
				markers += 1
				assert(is_instance_valid(entry.node) and (entry.node as Node).is_inside_tree())
		assert(markers == 1, "reload must leave one live shelter interaction: " + id)
	for id in ["CotInteractable", "HearthInteractable", "SailmakerAwningInteractable", "ResidentKeepsakeInteractable"]:
		var actual := _ark().find_children(id + "*", "Node3D", false, false)
		assert(actual.size() == 1, "no duplicate/orphan external shelter marker nodes: " + id)
	for id in ["PressureGalley", "SailmakerAwning", "TideShellKeepsake", "ReefShellStormBrace"]:
		assert(_shelter().get_node_or_null(id) != null, "rebuild must restore every previously earned home upgrade: " + id)
	assert(_shelter().get_node_or_null("HearthPot") == null, "upgraded galley must not regain a duplicate old pot")
	assert((_shelter().get_node("SailmakerAwning/PatchedCanvas") as MeshInstance3D).is_visible_in_tree(), "earned rain awning is not an occluding roof plate and must remain visible")
	_assert_nameplate_geometry(not (_roof().get_node("CenterFace") as MeshInstance3D).visible)
	# The fresh-load callback legitimately precedes the first physics camera pose.
	# After checking its finite baseline, establish the unchanged normal view and
	# check actual perspective-projected labels independently of helper metadata.
	var camera := game.get("camera") as Camera3D
	var target := _player().global_position + Vector3(0, 1.0, 0)
	camera.global_position = target + Vector3(0, 8.5, 10.5)
	camera.look_at(target, Vector3.UP)
	game.call("_update_shelter_roof_cutaway")
	_assert_nameplate_geometry(not (_roof().get_node("CenterFace") as MeshInstance3D).visible)


func _ownership() -> Array:
	var state: Dictionary = game.call("_build_save_state")
	var modules: Dictionary = state.modules
	return JSON.parse_string(JSON.stringify([state.world_events, state.event_sequence, modules.economy, modules.construction, modules.construction_sequence]))


func _stage_home_upgrades() -> void:
	# Earned-upgrade fixture: lifecycle tests separately cover earning these gifts.
	game.set("sailmaker_awning_raised", true)
	game.set("sailmaker_awning_phase", "complete")
	game.set("sailmaker_awning_sewing_elapsed", 0.0)
	game.call("_add_sailmaker_awning")
	game.set("resident_keepsake_present", true)
	game.set("shared_meal_count", 2)
	game.call("_add_resident_keepsake")
	(game.get("learned_blueprint_ids") as Array).append("pressure_galley")
	game.set("pressure_wreck_searched", true)
	game.set("pressure_cores", 1)
	game.set("pressure_galley_choice_pending", true)
	game.call("_build_pressure_galley")
	assert(bool(game.get("pressure_galley_built")))


func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/test_shelter_roof_cutaway_%d_%d" % [OS.get_process_id(), int(Time.get_unix_time_from_system() * 1000000.0)]).simplify_path()
	assert(Paths.is_safe_save_root(save_root), "roof regression needs a unique safe test-only save root")
	saves = Save.new(save_root)
	saves.clear_for_test()
	await _spawn()
	var unbuilt: Dictionary = game.call("_build_save_state")
	var unbuilt_ownership := _ownership()
	game.set("wood", 60)
	game.call("_start_basic_shelter_template")
	var preview := game.get("build_preview") as Node3D
	var ghost := preview.get_node("Roof") as MeshInstance3D
	game.call("_process", 0.0)
	assert(ghost.is_visible_in_tree() and (ghost.mesh as BoxMesh).size.is_equal_approx(Vector3(3.2, 0.18, 2.6)), "unbuilt ghost preview must retain its full roof")
	_tap(KEY_ESCAPE)
	assert(bool(game.call("_try_place_shelter", Vector3(0, 0.12, -0.5))))
	assert(bool(game.call("_try_place_storage", Vector3(2.0, 0.12, -1.5))))
	await physics_frame
	_assert_roof_geometry()
	_assert_hysteresis_and_support()
	await _walk_ingress_egress()
	_assert_inputs()
	_assert_damage_and_repair()
	_assert_npc_work()
	_assert_nameplate_lifecycle()
	await _walk_ingress_egress(true)
	_assert_brace()
	_stage_home_upgrades()
	var storage_id := game.get_node("ArkRoot/BuiltStorage").get_instance_id()
	var rebuild_ownership := _ownership()
	game.call("_build_shelter_at", game.get("shelter_position"))
	await process_frame
	_assert_one_shelter()
	assert(game.get_node("ArkRoot/BuiltStorage").get_instance_id() == storage_id and _ownership() == rebuild_ownership, "targeted shelter rebuild must preserve unrelated fixtures and all ownership/history")
	# Heading and translation change, but cutaway remains shelter/ark-local.
	_ark().position = Vector3(-8, 0, 3)
	_ark().rotation.y = 0.65
	_stand(Vector3(0, 0.2, 0))
	_assert_visibility(true)
	var boat_before := _ark().global_transform
	var player_local := _player().position
	game.set("sailing_mode", true)
	for step in range(4):
		assert(bool(game.call("_sail_step", 0.1, -1.0, 0.5)), "real collision-checked movement must remain available with a cutaway")
		game.call("_process", 0.0)
		_assert_visibility(true)
	game.set("sailing_mode", false)
	assert(_ark().global_position.distance_to(boat_before.origin) > 0.5 and not _ark().basis.is_equal_approx(boat_before.basis), "boat must genuinely translate and yaw, not only test fixed transform fixtures")
	assert(_player().position.is_equal_approx(player_local), "a moving and yawing vessel retains its actor's local relation to the cabin")
	_assert_roof_geometry()
	_stand(Vector3(0, 0.2, 2.3))
	_assert_visibility(false)
	_stand(Vector3(0, 0.2, 0))
	assert(bool(game.call("_save_progress")))
	var saved: Dictionary = saves.load_state().get("state", {})
	assert(int(saved.get("schema_version", 0)) == 43 and str(ProjectSettings.get_setting("application/config/version")) == "0.1.003", "visual cutaway remains compatible with kitchen schema43 and the unchanged game version")
	assert(not JSON.stringify(saved).contains("cutaway"), "presentation hysteresis must not leak into saved gameplay state")
	var ownership := _ownership()
	await _drop()
	await _spawn()
	assert(_ownership() == ownership, "fresh reload must preserve history, resources and construction receipts")
	_assert_visibility(true)
	_assert_roof_geometry()
	_assert_one_shelter()
	for repeat in range(2):
		game.call("_load_progress")
		await process_frame
		_assert_one_shelter()
		assert(_ownership() == ownership, "same-scene rebuild must not duplicate events or rewrite economic/construction history")
		_assert_visibility(true)
		_assert_roof_geometry()
	# A genuine pre-construction modular save must remove an existing cabin,
	# including all externally parented upgrade markers, without rewriting it.
	assert(bool(saves.save_state(unbuilt).get("ok", false)))
	game.call("_load_progress")
	await process_frame
	assert(not bool(game.get_meta("save_load_blocked", false)))
	assert(not bool(game.get("shelter_built")) and _ark().get_node_or_null("BuiltShelter") == null, "restoring valid unbuilt state must not leave a ghost shelter/roof")
	for id in ["CotInteractable", "HearthInteractable", "SailmakerAwningInteractable", "ResidentKeepsakeInteractable"]:
		assert(_ark().find_children(id + "*", "Node3D", false, false).is_empty(), "unbuilt restore must remove every shelter-owned external marker")
	for entry in game.get("interactables") as Array:
		assert(str(entry.get("id", "")) not in ["cot", "hearth", "sailmaker_awning", "resident_keepsake"], "unbuilt restore must remove orphan shelter interactions")
	assert(_ownership() == unbuilt_ownership, "valid pre-construction ownership/history must restore unchanged")
	for pair in [[game.get("traveler_marker"), Vector3(0, 2.7, 0)], [game.get("sailmaker_marker"), Vector3(0, 1.85, 0)]]:
		var sign := (pair[0] as Node3D).get_node("Name") as Label3D
		assert(sign.position.is_equal_approx(pair[1]) and not sign.has_meta("cutaway_base_position"), "removing the shelter must restore resident labels before discarding its context")
	# Restore the built sample for the observational update measurement.
	assert(bool(saves.save_state(saved).get("ok", false)))
	game.call("_load_progress")
	await process_frame
	_assert_visibility(true)
	# Cheap observational update timing, deliberately not a frame-rate gate.
	var started := Time.get_ticks_usec()
	for sample in range(1000):
		game.call("_update_shelter_roof_cutaway")
	var elapsed := Time.get_ticks_usec() - started
	print("ROOF_CUTAWAY_UPDATE_OBSERVATION: calls=1000 total_usec=%d average_usec=%.3f (non-gating; not FPS)" % [elapsed, float(elapsed) / 1000.0])
	await _drop()
	saves.clear_for_test()
	# A second real legal build avoids hard-coding the original shelter origin.
	await _spawn()
	game.set("wood", 12)
	assert(bool(game.call("_try_place_shelter", Vector3(0.5, 0.12, -0.5))))
	_assert_hysteresis_and_support()
	_assert_roof_geometry()
	await _drop()
	saves.clear_for_test()
	await _spawn()
	game.set("wood", 12)
	assert(bool(game.call("_try_place_shelter", Vector3(0, 0.12, 0))))
	game.set("traveler_boarded", true)
	game.call("_set_traveler_boarded")
	game.set("sailmaker_boarded", true)
	game.call("_set_sailmaker_boarded")
	await _assert_default_deck_edge_hysteresis()
	await _assert_swim_and_return()
	await _drop()
	saves.clear_for_test()
	print("ARK_SHELTER_ROOF_CUTAWAY_TEST_OK: emitted geometry, actual input movement, local hysteresis/support, damage/repair/brace, NPC work, keys/warnings, fresh/repeated load; readability separate")
	quit()
