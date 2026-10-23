extends "res://tests/ark_night_lighting_test.gd"

## Independent installation/preservation gate, NOT an aesthetic or old-bug claim.
## BEFORE: verified47, official Godot 4.7.1; actual executable observations repeated
## twice, matching full geometry/collision/node and per-period material hashes.
## Actual rendered quality, exposure and frame-time remain separate renderer gates.
# Second candidate: only the two opening-island surface-0 UV arrays are added.
# Platform-bound raw BEFORE/AFTER proof lives in separate QA, not a universal
# cross-OS byte golden. Portable byte assertions compare the SAME runtime.
# No candidate-derived geometry/material goldens are regenerated.
const UV_TARGETS := ["IslandLandmass/Shoreline", "IslandLandmass/Grassland"]
const BEFORE_GEOMETRY := "7d03058de485c8a2f119ca4d84a54ed9cab57baf6b12537afb4281184b914394"
const OLD_SURFACES := {
	"0_0": "cb9176c0b9c68d9a604e0ac51cca203284977a1b228fc563af54bdfd086f4954",
	"0_1": "d306f28626b3353fa8dcc17acf0d1fa9864d47b452aa63bc3dc2f4734a94b535",
	"0_2": "cb9176c0b9c68d9a604e0ac51cca203284977a1b228fc563af54bdfd086f4954",
	"1_0": "1c213479bac8bab67c4a1b8ed07a4790a5dab378ce052349466a57b758eb3f87",
	"1_1": "d306f28626b3353fa8dcc17acf0d1fa9864d47b452aa63bc3dc2f4734a94b535",
	"1_2": "1c213479bac8bab67c4a1b8ed07a4790a5dab378ce052349466a57b758eb3f87",
	"2_0": "9519ee0266574b238fb50f9e6ebd26d8af7cce1d27de492c0b1e25f0dfaf28e2",
	"2_1": "9519ee0266574b238fb50f9e6ebd26d8af7cce1d27de492c0b1e25f0dfaf28e2",
	"2_2": "9519ee0266574b238fb50f9e6ebd26d8af7cce1d27de492c0b1e25f0dfaf28e2",
	"3_0": "bd1bda3e1422be7065af45ce7b0e4c29a26020841cb45fdb83700ac9aeb4673e",
	"3_1": "bd1bda3e1422be7065af45ce7b0e4c29a26020841cb45fdb83700ac9aeb4673e",
	"3_2": "bd1bda3e1422be7065af45ce7b0e4c29a26020841cb45fdb83700ac9aeb4673e"
}
const TARGETS := [
	"IslandLandmass/Shoreline", "IslandLandmass/Grassland",
	"ArkRoot/RaftTop/MeshInstance3D#0", "ArkRoot/RaftBoardingGangplank/MeshInstance3D#0",
	"ArkRoot/BuiltShelter/CabinFloorboards/FloorPlank0", "ArkRoot/BuiltShelter/CabinFloorboards/FloorPlank1",
	"ArkRoot/BuiltShelter/CabinFloorboards/FloorPlank2", "ArkRoot/BuiltShelter/CabinFloorboards/FloorPlank3",
	"ArkRoot/BuiltShelter/CabinFloorboards/FloorPlank4", "ArkRoot/BuiltShelter/CabinFloorboards/FloorPlank5",
	"ArkRoot/BuiltShelter/CabinFloorboards/FloorPlank6", "ArkRoot/BuiltShelter/CabinFloorboards/FloorPlank7"
]
const TEXTURE_HASHES := {
	"terrain_detail.png": "04e687230183356bfe450f06d81f6003767d3fb4c266328cd66c9c887a46c59a",
	"wood_grain.png": "967ee279dc5d8180e669976ad04795cd0791c13a0957892c8b8f3bfe2fda45fa",
	"deck_planks.png": "f6ace5d7a780b03f0dabdc0356a07937a1270a03e2964ee5e5d2459a476a4f0d"
}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("SURFACE_SAMPLE: " + message)


func _expected_texture(path: String) -> String:
	if path.begins_with("IslandLandmass/"):
		return "terrain_detail.png"
	return "wood_grain.png" if path.contains("/CabinFloorboards/") else "deck_planks.png"


func _expected_scale(path: String) -> Vector3:
	if path == "IslandLandmass/Shoreline":
		return Vector3.ONE / 1.8
	if path == "IslandLandmass/Grassland":
		return Vector3.ONE / 2.8
	return Vector3(1.0 / 1.48, 1.0 / 1.48, 1.0 / 3.2)


func _surface_contract(rows: Array) -> Array:
	var result: Array = rows.duplicate(true)
	for row in result:
		if str(row.path) in TARGETS:
			# Only three actual changed fields. Overlay, base color, world anchoring,
			# roughness, filter, cull and EVERY other field remain fully hashed.
			row.override = _old_surface_fields(row.override)
			for index in range(row.surfaces.size()):
				row.surfaces[index] = _old_surface_fields(row.surfaces[index])
	return result


func _target_nodes() -> Dictionary:
	var result := {}
	for node in game.find_children("*", "MeshInstance3D", true, false):
		var path := _stable_path(node)
		if path in TARGETS:
			result[path] = node
	return result


func _inspect_install(label: String, expected_count: int = 12) -> void:
	var targets := _target_nodes()
	_check(targets.size() == expected_count, label + " must resolve exactly the independent target whitelist")
	var sampled: Array[String] = []
	var texture_ids := {}
	var material_ids := {}
	for node in game.find_children("*", "MeshInstance3D", true, false):
		var path := _stable_path(node)
		var material := node.material_override as StandardMaterial3D
		var texture: Texture2D = material.albedo_texture if material else null
		if texture and texture.resource_path.begins_with("res://art/surface_sample/"):
			sampled.append(path)
		if not path in TARGETS:
			continue
		_check(material != null and texture != null, label + " target needs a standard textured material: " + path)
		if not material or not texture:
			continue
		_check(texture.resource_path == "res://art/surface_sample/" + _expected_texture(path), label + " wrong actual texture: " + path)
		_check(material.uv1_triplanar == (not path in UV_TARGETS) and not material.uv1_world_triplanar, label + " must use ordinary local XZ UV on only two terrain meshes; ten ship meshes retain local triplanar: " + path)
		_check(material.uv1_scale.is_equal_approx(_expected_scale(path)) and material.uv1_offset == Vector3.ZERO and is_equal_approx(material.uv1_triplanar_sharpness, 1.0), label + " changed scale/offset/blend contract: " + path)
		_check(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS and material.texture_repeat, label + " must retain repeat + mipmapped linear filtering: " + path)
		_check(material.cull_mode == BaseMaterial3D.CULL_BACK and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL, label + " must not hide geometry/lighting with two-sided, transparent or unshaded material: " + path)
		_check(not material.normal_enabled and not material.emission_enabled and not material.vertex_color_use_as_albedo and is_zero_approx(material.metallic), label + " must not add normal/emission/vertex-color/metallic effects: " + path)
		_check(node.material_overlay == null and node.mesh != null and node.mesh.get_surface_count() == 1 and node.get_active_material(0) == material, label + " must use existing override without overlay/additional surfaces: " + path)
		texture_ids[texture.get_instance_id()] = true
		material_ids[material.get_instance_id()] = true
	_check(sampled.size() == expected_count and material_ids.size() == expected_count, label + " must install one duplicated material on only each target, not other islands/characters/walls/roof/trim")
	for path in sampled:
		_check(path in TARGETS, label + " texture escaped whitelist: " + path)
	_check(texture_ids.size() == (3 if expected_count == 12 else 2), label + " must share exactly the three offline textures, no per-board texture generation")
	var helper: RefCounted = game.get("surface_sample")
	_check(helper != null and not helper.has_method("_process") and not helper.has_method("_physics_process"), label + " helper must not add a real process loop")
	if helper:
		_check((helper.get("_materials") as Dictionary).size() == expected_count, label + " material cache must be bounded by target slots")


func _inspect_textures() -> void:
	for name in TEXTURE_HASHES:
		var path: String = "res://art/surface_sample/" + name
		_check(FileAccess.get_sha256(path) == TEXTURE_HASHES[name], "offline PNG bytes differ: " + name)
		var source := Image.new()
		_check(source.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK, "source PNG must decode: " + name)
		var texture := load(path) as Texture2D
		_check(source != null and source.get_size() == Vector2i(256, 256), "source must be baked 256x256 PNG: " + name)
		_check(texture != null and texture.get_size() == Vector2(256, 256), "actual imported texture must be 256x256: " + name)
		if not source or not texture:
			continue
		var imported := texture.get_image()
		_check(imported != null and imported.has_mipmaps() and imported.get_mipmap_count() == 8, "actual imported resource must contain full 8-level mip chain: " + name)
		if imported:
			imported.clear_mipmaps()
			source.convert(Image.FORMAT_RGBA8)
			imported.convert(Image.FORMAT_RGBA8)
			_check(imported.get_data() == source.get_data(), "lossless imported base pixels must equal the baked PNG: " + name)
			_check(source.detect_alpha() == Image.ALPHA_NONE, "sample textures must remain opaque: " + name)


func _resource_ids() -> Dictionary:
	var rows := {}
	for node in game.find_children("*", "", true, false):
		var row: Array = [node.get_instance_id()]
		if node is MeshInstance3D:
			row.append(node.mesh.get_instance_id() if node.mesh else 0)
			row.append(node.material_override.get_instance_id() if node.material_override else 0)
			row.append(node.material_overlay.get_instance_id() if node.material_overlay else 0)
		if node is CollisionShape3D:
			row.append(node.shape.get_instance_id() if node.shape else 0)
		rows[_stable_path(node)] = row
	return rows


func _apply_again() -> void:
	var before_state := _state()
	var helper: RefCounted = game.get("surface_sample")
	helper.call("apply_world", game)
	helper.call("apply_shelter", game.get_node("ArkRoot/BuiltShelter"))
	_check(_state() == before_state, "helper application must preserve full save state without exclusions")


func _idempotence() -> void:
	var before_ids := _resource_ids()
	var before_materials := _digest(_surface_rows())
	var before_geometry := _digest(_geometry_rows())
	var before_raw_arrays := _digest(_raw_arrays())
	for repeat in range(24):
		_apply_again()
	_check(_resource_ids() == before_ids, "24 applications must retain every node/mesh/material/collision instance ID")
	_check(_digest(_surface_rows()) == before_materials and _digest(_geometry_rows()) == before_geometry, "24 applications must change no actual geometry/material field")
	_check(_digest(_raw_arrays()) == before_raw_arrays, "24 applications must preserve every raw mesh array and collision-face byte on the same runtime")
	_inspect_install("idempotence")


func _duplicate_contract() -> void:
	# Shared-source adversarial fixture: production must duplicate, not mutate the
	# original or its nonwhitelisted consumer. This uses no production target table.
	var helper := load("res://scripts/presentation/ark_surface_sample.gd").new() as RefCounted
	var world := Node3D.new()
	var island := Node3D.new()
	island.name = "IslandLandmass"
	world.add_child(island)
	var ark := Node3D.new()
	ark.name = "ArkRoot"
	world.add_child(ark)
	var shelter := Node3D.new()
	shelter.name = "BuiltShelter"
	ark.add_child(shelter)
	var floorboards := Node3D.new()
	floorboards.name = "CabinFloorboards"
	shelter.add_child(floorboards)
	var source := StandardMaterial3D.new()
	source.albedo_color = Color(0.21, 0.32, 0.43)
	source.roughness = 0.73
	var before := _resource(source)
	var visuals: Array[MeshInstance3D] = []
	for path in TARGETS:
		var parent: Node = floorboards if path.contains("FloorPlank") else island
		if path.contains("/Raft"):
			parent = Node3D.new()
			parent.name = path.get_slice("/", 1)
			ark.add_child(parent)
		var visual := MeshInstance3D.new()
		visual.name = path.get_file()
		visual.mesh = BoxMesh.new()
		visual.material_override = source
		parent.add_child(visual)
		visuals.append(visual)
	var sentinel := MeshInstance3D.new()
	sentinel.name = "UntouchedWall"
	sentinel.material_override = source
	shelter.add_child(sentinel)
	helper.call("apply_world", world)
	helper.call("apply_shelter", shelter)
	_check(_resource(source) == before and sentinel.material_override == source, "duplicating targets must not mutate shared source/nonwhitelist consumers")
	for visual in visuals:
		_check(visual.material_override != source, "target must receive a duplicate, not mutate the original")
		_check(_old_surface_fields(_resource(visual.material_override)) == before, "duplication may alter only the three explicit sampled fields")
	_check((helper.get("_materials") as Dictionary).size() == 12, "isolated helper cache must have exactly 12 fixed slots")
	world.free()


func _boat_local_mapping() -> void:
	var ark := game.get_node("ArkRoot") as Node3D
	var original_transform := ark.transform
	var before_ids := _resource_ids()
	var local_probe := Vector3(0.17, 0.025, 0.73)
	var probes := {}
	for path in _target_nodes():
		if path.begins_with("ArkRoot/"):
			var visual: MeshInstance3D = _target_nodes()[path]
			probes[path] = visual.to_global(local_probe)
	game.set("sailing_mode", true)
	_check(bool(game.call("_sail_step", 0.35, -1.0, 0.7)), "actual vessel navigation must translate and yaw for mapping test")
	game.set("sailing_mode", false)
	_check(ark.position.distance_to(original_transform.origin) > 0.1 and not ark.basis.is_equal_approx(original_transform.basis), "actual vessel must both translate and yaw, not just mutate a test shader coordinate")
	for path in probes:
		var visual: MeshInstance3D = _target_nodes()[path]
		var material := visual.material_override as StandardMaterial3D
		var moved_world := visual.to_global(local_probe)
		_check(moved_world.distance_to(probes[path]) > 0.05, "wood sample must actually move through world space: " + path)
		_check(visual.to_local(moved_world).is_equal_approx(local_probe) and material.uv1_triplanar and not material.uv1_world_triplanar and material.uv1_scale.is_equal_approx(_expected_scale(path)), "standard local-triplanar grain must retain mesh-local coordinates after actual sailing: " + path)
	_check(_resource_ids() == before_ids, "actual boat movement must not rebuild textures/materials/nodes")
	ark.transform = original_transform
	# Rendering of directional grain under movement is a separate visual gate.


func _reconstruct_surface(expected: Dictionary, label: String) -> void:
	_reconstructed(expected, label)
	_check(_semantics(_state()) == expected, label + " must preserve exact full semantics, including no added/missing fields")
	_inspect_install(label)
	_uv_scope_contract()
	var before_ids := _resource_ids()
	_apply_again()
	_check(before_ids == _resource_ids(), label + " reapplied helper must retain node/resource identities")
	_check(game.find_children("FloorPlank*", "MeshInstance3D", true, false).size() == 8, label + " must reconstruct only eight floorboards")
	var interactions := {}
	for entry in game.get("interactables") as Array:
		var id := str(entry.get("id", ""))
		interactions[id] = int(interactions.get(id, 0)) + 1
	for id in ["cot", "hearth", "resident_keepsake", "sailmaker_awning"]:
		_check(int(interactions.get(id, 0)) <= 1, label + " must not accumulate shelter interaction: " + id)


func _save_roundtrip(expected: Dictionary, label: String) -> void:
	await _spawn()
	_reconstruct_surface(expected, label + "_fresh")
	var first_shelter_count := game.get_node("ArkRoot/BuiltShelter").find_children("*", "", true, false).size()
	var helper: RefCounted = game.get("surface_sample")
	var cache: Dictionary = (helper.get("_materials") as Dictionary).duplicate()
	for repeat in range(3):
		game.call("_load_progress")
		await process_frame
		await physics_frame
		await process_frame
		_reconstruct_surface(expected, label + "_repeat_%d" % repeat)
		_check(game.get_node("ArkRoot/BuiltShelter").find_children("*", "", true, false).size() == first_shelter_count, label + " repeated shelter rebuild must not accumulate nodes")
		# Independent pre-edit47 diagnosis reproduces unrelated storage/workbench
		# duplication on whole-scene reload. Do not conceal it as a material fix:
		# this gate requires exact shelter cardinality and helper no-node mutation.
		print("SURFACE_RECONSTRUCTION_NODES: ", label, " repeat=", repeat, " total=", game.find_children("*", "", true, false).size(), " shelter_descendants=", first_shelter_count)
		_check(helper.get("_materials") == cache, label + " repeated shelter rebuild must reuse exact bounded cache resources")
	await _drop()


func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/test_surface_sample_%d_%d" % [OS.get_process_id(), int(Time.get_unix_time_from_system() * 1000000)]).simplify_path()
	assert(Paths.is_safe_save_root(save_root), "surface contract must never touch normal preview/user saves")
	saves = Save.new(save_root)
	saves.clear_for_test()
	_inspect_textures()
	_default_builder_contract()
	_duplicate_contract()
	await _spawn()
	_inspect_install("fresh_world", 4)
	await _setup_actions()
	_check(_digest(_geometry_rows(true)) == BEFORE_GEOMETRY, "actual complete node graph/geometry/normals/UVs/collision/poses must match repeated pre-edit47 observations")
	_uv_scope_contract()
	_inspect_install("built_home")
	_idempotence()
	for period in range(4):
		for weather in range(3):
			game.set("day_period", period)
			game.set("weather_phase", weather)
			_inspect("initial")
			var key := "%d_%d" % [period, weather]
			_check(_digest(_surface_contract(_surface_rows())) == OLD_SURFACES[key], "exact-path full material contract differs outside three fields: " + key)
			_apply_again()
			_inspect_install(key)
	_boat_local_mapping()
	game.set("player_health", 3)
	game.set("life_period_elapsed", 23.5)
	_check(bool(game.get("water").advance(0.125).get("ok", false)), "fixture must advance real water authority")
	game.get("water").apply_visual((game.get_node("Sea") as MeshInstance3D).material_override)
	game.set("weather_phase", 1)
	_inspect("nondefault_night_storm", false)
	_check(bool(game.call("_save_progress")), "current state must use actual checksum save service")
	var saved: Dictionary = saves.load_state().get("state", {})
	_check(int(saved.get("schema_version", 0)) == 36 and str(ProjectSettings.get_setting("application/config/version")) == "0.1.003", "surface presentation must not bump save schema/game version")
	var expected := _semantics(saved)
	await _drop()
	await _save_roundtrip(expected, "current36")
	var legacy := saved.duplicate(true)
	legacy.schema_version = 35
	for field in ["sailmaker_awning_phase", "sailmaker_awning_sewing_elapsed", "sailmaker_awning_install_elapsed"]:
		legacy.erase(field)
	_check(bool(saves.save_state(legacy).get("ok", false)), "explicit synthetic schema35-format fixture must pass normal save validation")
	await _save_roundtrip(expected, "synthetic35")
	var old_fixture := OS.get_environment("ARK_SURFACE_OLD_TEST_SAVE")
	if not old_fixture.is_empty():
		saves.clear_for_test()
		var fixture_hash := FileAccess.get_sha256(old_fixture)
		var file := FileAccess.open(saves.get_save_path(), FileAccess.WRITE)
		assert(file != null)
		file.store_string(FileAccess.get_file_as_string(old_fixture))
		file.close()
		var loaded: Dictionary = saves.load_state()
		_check(bool(loaded.get("ok", false)), "actual pre-edit47 fixture must pass checksum/schema")
		if loaded.get("ok", false):
			await _save_roundtrip(_semantics(loaded.state), "actual_pre_edit47")
		_check(FileAccess.get_sha256(old_fixture) == fixture_hash, "actual pre-edit47 input fixture must remain byte-identical")
		print("ARK_SURFACE_ACTUAL_PRE_EDIT47_CHECKED: ", fixture_hash)
	else:
		print("ARK_SURFACE_ACTUAL_PRE_EDIT47_NOT_REQUESTED: set ARK_SURFACE_OLD_TEST_SAVE for external baseline fixture")
	saves.clear_for_test()
	if failures == 0:
		print("ARK_SURFACE_SAMPLE_TEST_OK: exact12 mesh installation; baked PNG bytes/imported pixels/mipmaps; original geometry/normals/collision/materials; exact2 opt-in localXZ UV arrays with all other mesh bytes preserved and default builder unchanged; 12 lighting/weather/save invariants; actual vessel local mapping; bounded idempotent cache; current36/synthetic35 repeated reconstruction. Known pre-edit47 whole-world repeated-load storage/workbench duplication remains; this is NOT a whole-world reload idempotency claim. Aesthetic/performance gates remain independent.")
	else:
		print("ARK_SURFACE_SAMPLE_TEST_RED: failures=", failures)
	quit(1 if failures > 0 else 0)


func _stable_path(node: Node) -> String:
	var segments: Array[String] = []
	while node != game:
		var segment := str(node.name)
		if segment.begins_with("@"):
			var ordinal := 0
			for sibling in node.get_parent().get_children():
				if sibling == node:
					break
				if str(sibling.name).begins_with("@") and sibling.get_class() == node.get_class():
					ordinal += 1
			segment = node.get_class() + "#%d" % ordinal
		segments.push_front(segment)
		node = node.get_parent()
	return "/".join(segments)


func _geometry_plain(value: Variant) -> Variant:
	if value is Vector2:
		return [roundi(value.x * 100000), roundi(value.y * 100000)]
	if value is Vector3:
		return [roundi(value.x * 100000), roundi(value.y * 100000), roundi(value.z * 100000)]
	if value is Transform3D:
		return [_geometry_plain(value.basis), _geometry_plain(value.origin)]
	if value is Basis:
		return [_geometry_plain(value.x), _geometry_plain(value.y), _geometry_plain(value.z)]
	if value is Array or value is PackedVector3Array or value is PackedVector2Array or value is PackedFloat32Array or value is PackedInt32Array or value is PackedColorArray or value is PackedFloat64Array or value is PackedInt64Array or value is PackedByteArray:
		var items: Array = []
		for item in value:
			items.append(_geometry_plain(item))
		return items
	return _plain(value)


func _geometry_rows(restore_old_surface_uv: bool = false) -> Array:
	# Entire live node graph: meshes include winding, normals, UVs and indices;
	# shapes retain full stored properties. No material filtering is done here.
	var rows: Array = []
	for node in game.find_children("*", "", true, false):
		var row := {"path": _stable_path(node), "class": node.get_class()}
		if node is Node3D:
			row.transform = _geometry_plain(node.transform)
			row.visible = node.visible
		if node is MeshInstance3D:
			row.cast_shadow = node.cast_shadow
			row.layers = node.layers
			row.mesh_class = node.mesh.get_class() if node.mesh else "null"
			row.surfaces = []
			if node.mesh:
				for index in range(node.mesh.get_surface_count()):
					row.surfaces.append({"primitive": (node.mesh.surface_get_primitive_type(index) if node.mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES), "arrays": JSON.stringify(_geometry_plain(_observed_arrays(node, index, restore_old_surface_uv)), "", true).sha256_text()})
		if node is CollisionObject3D:
			row.layer = node.collision_layer
			row.mask = node.collision_mask
			row.ray_pickable = node.input_ray_pickable
		if node is CollisionShape3D:
			row.disabled = node.disabled
			row.shape = _resource(node.shape) if node.shape else null
		rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.path < b.path)
	return rows


func _surface_rows() -> Array:
	var rows: Array = []
	for node in game.find_children("*", "MeshInstance3D", true, false):
		var row := {"path": _stable_path(node), "override": _plain(node.material_override), "overlay": _plain(node.material_overlay), "surfaces": []}
		if node.mesh:
			for index in range(node.mesh.get_surface_count()):
				row.surfaces.append(_plain(node.get_active_material(index)))
		rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.path < b.path)
	return rows


func _setup_actions() -> void:
	for pile in range(3):
		_interact("wood")
		await process_frame
	_check(int(game.get("wood")) == 8, "fixture must earn its 2+2+3 finite wood piles")
	(game.get("player") as Node3D).position = Vector3(0, 1.1, 1.75)
	_check(bool(game.call("_try_place_workshop_home_template", Vector3(0, 0.12, 0))), "fixture must build the actual seven-wood home")
	_interact("resident")
	_interact("shellfish")
	(game.get("player") as Node3D).position = Vector3(0.25, 1.1, 1.2)
	_check(bool(game.get("resident_met")) and not (game.get("world_events") as Array).is_empty() and not (game.get("collected_ids") as Array).is_empty(), "fixture must retain earned actions and history")


func _spawn() -> void:
	game = load("res://scenes/ark_greybox.tscn").instantiate() as Node3D
	game.set("save_root_override", save_root)
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await physics_frame


func _observed_arrays(node: MeshInstance3D, index: int, restore_old_surface_uv: bool) -> Array:
	var arrays := node.mesh.surface_get_arrays(index)
	if restore_old_surface_uv and index == 0 and _stable_path(node) in UV_TARGETS:
		# ONLY one explicit UV array on each exact target is normalized to the
		# captured old null. Other array fields/types/bytes and all other meshes
		# remain intact. Correct added UVs are asserted independently below.
		arrays = arrays.duplicate()
		arrays[Mesh.ARRAY_TEX_UV] = null
	return arrays


func _byte_sha(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(value))
	return context.finish().hex_encode()


func _raw_arrays(restore_old_surface_uv: bool = false) -> Array:
	var rows: Array = []
	for node in game.find_children("*", "MeshInstance3D", true, false):
		var row := {"path": _stable_path(node), "surfaces": [], "faces": _byte_sha(node.mesh.get_faces()) if node.mesh else ""}
		if node.mesh:
			for index in range(node.mesh.get_surface_count()):
				row.surfaces.append(_byte_sha(_observed_arrays(node, index, restore_old_surface_uv)))
		rows.append(row)
	for node in game.find_children("*", "CollisionShape3D", true, false):
		if node.shape is ConcavePolygonShape3D:
			rows.append({"path": _stable_path(node), "collision_faces": _byte_sha(node.shape.get_faces()), "backface": node.shape.backface_collision})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.path < b.path)
	return rows


func _valid_local_xz(arrays: Array) -> bool:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if not arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array:
		return false
	var coordinates: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	if coordinates.size() != vertices.size() or coordinates.is_empty():
		return false
	for index in range(vertices.size()):
		# Independent design coordinates, NOT helper/builder constants or tags.
		# One local metre is one unscaled UV unit; material scale sets 1.8/2.8m.
		if not coordinates[index].is_finite() or coordinates[index] != Vector2(vertices[index].x, vertices[index].z):
			return false
	return true


func _uv_scope_contract() -> void:
	var count := 0
	for island in ["IslandLandmass", "FarReefLandmass", "MoonbackIsland", "JadeSailShoal", "SteamWreckIslet"]:
		for part in ["Shoreline", "Grassland"]:
			var path: String = island + "/" + part
			var visual := game.get_node(path) as MeshInstance3D
			var mesh := visual.mesh as ArrayMesh
			var arrays := mesh.surface_get_arrays(0)
			if path not in UV_TARGETS:
				_check(arrays[Mesh.ARRAY_TEX_UV] == null, "all four other islands must retain the actual old absent UV field: " + path)
				continue
			count += 1
			_check(mesh.get_surface_count() == 1 and _valid_local_xz(arrays), "every emitted UV must equal corresponding local vertex X,Z without topology/reordering: " + path)
			var material := visual.material_override as StandardMaterial3D
			_check(not material.uv1_triplanar and not material.uv1_world_triplanar and material.uv1_scale.is_equal_approx(_expected_scale(path)), "terrain must use ordinary UV at unchanged physical scale: " + path)
			var changed := arrays.duplicate(true)
			var wrong_uv: PackedVector2Array = changed[Mesh.ARRAY_TEX_UV]
			wrong_uv[0] += Vector2(0.01, 0.02)
			changed[Mesh.ARRAY_TEX_UV] = wrong_uv
			_check(not _valid_local_xz(changed), "UV oracle must reject displaced/swapped/sign-changed mapping rather than blindly exclude UV")
	_check(count == 2, "only two independently named terrain meshes may acquire UVs")


func _builder_record(island: StaticBody3D, restore_old_uv: bool = false) -> Dictionary:
	var record := {"position": _plain(island.position), "layer": island.collision_layer, "mask": island.collision_mask, "children": island.get_child_count()}
	for part in ["Shoreline", "Grassland"]:
		var mesh: ArrayMesh = island.get_node(part).mesh
		var shape: ConcavePolygonShape3D = island.get_node(part + "Collision").shape
		var arrays := mesh.surface_get_arrays(0)
		if restore_old_uv:
			arrays = arrays.duplicate()
			arrays[Mesh.ARRAY_TEX_UV] = null
		record[part] = {"arrays": _byte_sha(arrays), "faces": _byte_sha(mesh.get_faces()), "collision": _byte_sha(shape.get_faces()), "backface": shape.backface_collision, "material": _resource(island.get_node(part).material_override)}
	return record


func _default_builder_contract() -> void:
	var builder := load("res://scripts/ark_landmass_builder.gd").new() as RefCounted
	var case_index := 0
	for parameters in [["DefaultOpening",Vector3(11,0,-14),Vector2(12,10),1.2], ["ArbitraryProbe",Vector3(4,0,-8),Vector2(9.2,7.4),2.31]]:
		var plain: StaticBody3D = builder.callv("build_island", parameters)
		var explicit_parameters: Array = parameters.duplicate()
		explicit_parameters.append_array([Color("536d50"), Color("77735b"), false])
		var explicit_false: StaticBody3D = builder.callv("build_island", explicit_parameters)
		explicit_parameters[-1] = true
		var sampled: StaticBody3D = builder.callv("build_island", explicit_parameters)
		var post_default: StaticBody3D = builder.callv("build_island", parameters)
		var original := _builder_record(plain)
		_check(_builder_record(post_default) == original, "opt-in must not leak UV/mapping/state into a subsequent default build")
		_check(_builder_record(explicit_false) == original, "explicit false must retain original default builder geometry/material/collision")
		_check(_builder_record(sampled, true) == original, "opt-in may add only two UV arrays, not vertices/normals/faces/material/collision/transform")
		for part in ["Shoreline", "Grassland"]:
			var old_arrays: Array = plain.get_node(part).mesh.surface_get_arrays(0)
			var new_arrays: Array = sampled.get_node(part).mesh.surface_get_arrays(0)
			_check(old_arrays[Mesh.ARRAY_TEX_UV] == null and _valid_local_xz(new_arrays), "default UV remains absent; opt-in emits independent exact local XZ: " + part)
			for field in range(Mesh.ARRAY_MAX):
				if field != Mesh.ARRAY_TEX_UV:
					_check(var_to_bytes(old_arrays[field]) == var_to_bytes(new_arrays[field]), "every non-UV slot must be BIT-identical: %s field=%d" % [part, field])
			# Calibration: the same strict oracle rejects even a small normal change.
			var normals: PackedVector3Array = new_arrays[Mesh.ARRAY_NORMAL].duplicate()
			normals[0].x += 0.00001
			_check(var_to_bytes(old_arrays[Mesh.ARRAY_NORMAL]) != var_to_bytes(normals), "raw geometry oracle must reject a changed normal")
		plain.free()
		explicit_false.free()
		sampled.free()
		post_default.free()
		case_index += 1
