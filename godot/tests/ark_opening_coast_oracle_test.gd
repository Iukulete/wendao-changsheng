extends SceneTree
## Adversarial calibration for the test-only coast inverse projection.
## Mutations affect real native resources/nodes, never just fabricated records.
## Every case restores exact live identities/raw bytes/full state before the next.
## This supplements, never replaces or relaxes, the unchanged old goldens and
## the surface/night tests' raw same-runtime assertions. Not a visual/FPS gate.
const Paths = preload("res://tests/ark_test_paths.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
const History = preload("res://tests/support/coast_historical_projection.gd")
const Scene = preload("res://scenes/ark_greybox.tscn")

class Collector:
	extends RefCounted
	# Serialization methods below are byte-identical copies (apart from this
	# class's indentation) of surface/night's actual observation methods. A
	# lightweight collector records expected failures without push_error noise.
	const UV_TARGETS := ["IslandLandmass/Shoreline", "IslandLandmass/Grassland"]
	var game: Node3D
	var history: RefCounted
	var failures: Array[String] = []

	func _check(ok: bool, message: String) -> void:
		if not ok:
			failures.append(message)

	func _history() -> RefCounted:
		return history

	func _plain(value: Variant) -> Variant:
		if value is Color:
			return [snappedf(value.r, 0.000001), snappedf(value.g, 0.000001), snappedf(value.b, 0.000001), snappedf(value.a, 0.000001)]
		if value is Vector3:
			return [snappedf(value.x, 0.000001), snappedf(value.y, 0.000001), snappedf(value.z, 0.000001)]
		if value is float:
			return snappedf(value, 0.000001)
		if value is Resource:
			if value is Material or value is Environment or value is ProceduralSkyMaterial or value is CameraAttributes:
				return _resource(value)
			if value is Shader:
				return {"class": value.get_class(), "code_sha256": value.code.sha256_text()}
			return {"class": value.get_class(), "path": value.resource_path}
		if value is Dictionary:
			var result := {}
			for key in value:
				result[key] = _plain(value[key])
			return result
		if value is Array:
			var result: Array = []
			for entry in value:
				result.append(_plain(entry))
			return result
		if typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME]:
			return value
		return str(value)


	func _resource(resource: Resource) -> Dictionary:
		var result := {"class": resource.get_class()}
		for item in resource.get_property_list():
			var id := str(item.name)
			if int(item.usage) & PROPERTY_USAGE_STORAGE and id not in ["resource_name", "resource_path", "resource_local_to_scene", "script"]:
				result[id] = _plain(resource.get(id))
		return result


	# Independent exact-node recognition, not the production helper's cache/tags.
	# These metadata are never part of the historical name-only material digest.


	func _surface_sample_path(node: MeshInstance3D) -> String:
		var path := str(game.get_path_to(node))
		if path in ["IslandLandmass/Shoreline", "IslandLandmass/Grassland"]:
			return path
		for index in range(8):
			if path == "ArkRoot/BuiltShelter/CabinFloorboards/FloorPlank%d" % index:
				return path
		var parent_path := str(game.get_path_to(node.get_parent()))
		if parent_path in ["ArkRoot/RaftTop", "ArkRoot/RaftBoardingGangplank"]:
			var direct_meshes := 0
			for child in node.get_parent().get_children():
				if child is MeshInstance3D:
					direct_meshes += 1
			if direct_meshes == 1:
				return parent_path + "/MeshInstance3D#0"
		return ""


	func _materials() -> Array:
		var result: Array = []
		for node in game.find_children("*", "MeshInstance3D", true, false):
			var entry := {"_history_path": _history().node_path(node), "_surface_sample_path": _surface_sample_path(node), "name": str(node.name), "override": _plain(node.material_override), "overlay": _plain(node.material_overlay), "surfaces": []}
			if node.mesh:
				for index in range(node.mesh.get_surface_count()):
					entry.surfaces.append(_plain(node.get_active_material(index)))
			result.append(entry)
		return result


	func _lighting() -> Dictionary:
		var sun: DirectionalLight3D = game.get("sun_light")
		var env: Environment = game.get("weather_environment")
		var overlay: ColorRect = game.get("storm_overlay")
		var lights: Array = []
		for light in game.find_children("*", "Light3D", true, false):
			lights.append({"name": str(light.name) if not str(light.name).begins_with("@") else light.get_class(), "class": light.get_class(), "color": _plain(light.light_color), "energy": _plain(light.light_energy), "shadow": light.shadow_enabled, "position": _plain(light.position), "rotation": _plain(light.rotation_degrees), "range": light.omni_range if light is OmniLight3D else null})
		var camera: Camera3D = game.get("camera")
		return {"profile": _plain(game.call("_daylight_profile")), "environment": _resource(env), "sky": _resource(game.get("sky_material")), "lights": lights, "sun": {"color": _plain(sun.light_color), "energy": _plain(sun.light_energy), "rotation": _plain(sun.rotation_degrees), "shadow": sun.shadow_enabled}, "overlay": {"visible": overlay.visible, "color": _plain(overlay.color)}, "camera_attributes": _plain(camera.attributes) if camera else null, "materials": _materials()}


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


	func _observed_arrays(node: MeshInstance3D, index: int, restore_old_surface_uv: bool) -> Array:
		var arrays := node.mesh.surface_get_arrays(index)
		if restore_old_surface_uv and index == 0 and _stable_path(node) in UV_TARGETS:
			# ONLY one explicit UV array on each exact target is normalized to the
			# captured old null. Other array fields/types/bytes and all other meshes
			# remain intact. Correct added UVs are asserted independently below.
			arrays = arrays.duplicate()
			arrays[Mesh.ARRAY_TEX_UV] = null
		return arrays


var game: Node3D
var collector: Collector
var history: RefCounted
var saves: RefCounted
var save_root: String
var failures := 0
var baselines := {}
var cases: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("COAST_ORACLE: " + message)

func _digest(value: Variant) -> String:
	return var_to_bytes(value).hex_encode().sha256_text()

func _evaluate(domain: String) -> String:
	if domain == "geometry":
		return _digest(history.geometry(collector._geometry_rows(true)))
	if domain == "materials":
		return _digest(history.materials(collector._surface_rows()))
	history.validate_lighting()
	var output: Dictionary = history.lighting(collector._lighting())
	output.erase("materials")
	return _digest(output)

func _raw_signature() -> String:
	# No coast/HUD/history normalization here. IDs and full raw native mesh,
	# collision, raster and transform data must return to the very same state.
	var rows: Array = []
	for node in game.find_children("*", "", true, false):
		var row: Array = [collector._stable_path(node), node.get_instance_id()]
		if node is Node3D:
			row.append(node.transform)
		if node is MeshInstance3D:
			row.append(node.mesh.get_instance_id() if node.mesh else 0)
			row.append(node.material_override.get_instance_id() if node.material_override else 0)
			row.append(node.material_overlay.get_instance_id() if node.material_overlay else 0)
			if node.mesh:
				for index in range(node.mesh.get_surface_count()):
					row.append(_digest(node.mesh.surface_get_arrays(index)))
		if node is CollisionShape3D:
			row.append(node.shape.get_instance_id() if node.shape else 0)
			if node.shape is ConcavePolygonShape3D:
				row.append(_digest(node.shape.get_faces()))
			elif node.shape is ConvexPolygonShape3D:
				row.append(_digest(node.shape.points))
		rows.append(row)
	var sea: ShaderMaterial = game.get_node("Sea").material_override
	var raster: Texture2D = sea.get_shader_parameter("opening_heights")
	var water: RefCounted = game.get("water")
	return _digest([rows, collector._geometry_rows(), collector._surface_rows(),
		collector._lighting(), raster.get_instance_id(), raster.get_image().get_data(),
		game.call("_build_save_state"), water.get_instance_id(), water.snapshot()])

func _exercise(label: String, domain: String, mutate: Callable, restore: Callable, expected_diagnostic: String = "") -> void:
	var started := Time.get_ticks_msec()
	print("COAST_ORACLE_CASE_BEGIN ", label)
	var raw_before := _raw_signature()
	collector.failures.clear()
	mutate.call()
	var changed := _evaluate(domain)
	var diagnostics: Array[String] = collector.failures.duplicate()
	var rejected: bool = not diagnostics.is_empty() or changed != baselines[domain]
	var diagnostic_found := expected_diagnostic.is_empty()
	for message in diagnostics:
		if message.contains(expected_diagnostic):
			diagnostic_found = true
	# Restore even when the oracle unexpectedly accepts; a missed mutation must
	# fail the test rather than poison subsequent independent cases.
	restore.call()
	var restored := _raw_signature() == raw_before
	_check(rejected, "actual mutation escaped inverse projection: " + label)
	_check(diagnostic_found, "missing independent validation diagnostic for " + label + ": " + str(diagnostics))
	_check(restored, "actual mutation did not restore all raw resources/state: " + label)
	cases.append({"case": label, "domain": domain, "rejected": rejected,
		"independent_diagnostics": diagnostics, "raw_exact_restored": restored})
	collector.failures.clear()
	print("COAST_ORACLE_CASE_END ", label, " ms=", Time.get_ticks_msec()-started, " rejected=", rejected, " restored=", restored)

func _replace_mesh_array(label: String, path: String, slot: int, changed: Variant, expected_diagnostic: String = "") -> void:
	var visual := game.get_node(path) as MeshInstance3D
	var original: Mesh = visual.mesh
	var arrays: Array = original.surface_get_arrays(0).duplicate(true)
	arrays[slot] = changed
	var altered := ArrayMesh.new()
	altered.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Preserve the old surface material too; this case changes only one array.
	altered.surface_set_material(0, original.surface_get_material(0))
	_exercise(label, "geometry", func() -> void: visual.mesh = altered,
		func() -> void: visual.mesh = original, expected_diagnostic)

func _geometry_cases() -> void:
	var collision := game.get_node("IslandLandmass/ShorelineCollision") as CollisionShape3D
	var original_shape := collision.shape as ConcavePolygonShape3D
	var bad_shape := original_shape.duplicate() as ConcavePolygonShape3D
	var faces: PackedVector3Array = bad_shape.get_faces()
	faces[0].y += .025
	bad_shape.set_faces(faces)
	_exercise("opening_top_collider_mismatch", "geometry",
		func() -> void: collision.shape = bad_shape,
		func() -> void: collision.shape = original_shape, "opening collision must exactly equal approved top")
	var top := game.get_node("IslandLandmass/Shoreline") as MeshInstance3D
	var uv: PackedVector2Array = top.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV].duplicate()
	uv[0] += Vector2(.03125, .0625)
	_replace_mesh_array("opening_top_actual_uv", "IslandLandmass/Shoreline", Mesh.ARRAY_TEX_UV, uv,
		"opening top raw vertex/normal/UV/tangent/index arrays differ")
	var extra_satellite := game.get_node("CoastClusterRock00").duplicate() as StaticBody3D
	extra_satellite.name = "CoastClusterRock09"
	_exercise("extra_satellite_outside_whitelist", "geometry",
		func() -> void: game.add_child(extra_satellite),
		func() -> void: extra_satellite.free())
	var known_satellite := game.get_node("CoastClusterRock00") as Node3D
	var extra_satellite_child := Node3D.new()
	extra_satellite_child.name = "UnexpectedCoastChild"
	_exercise("extra_child_inside_projected_satellite", "geometry",
		func() -> void: known_satellite.add_child(extra_satellite_child),
		func() -> void: extra_satellite_child.free(), "exactly29 approved new coast node rows")
	var pivot := game.get_node("residentMarker/CoastVisualGroundOffset") as Node3D
	var pivot_position := pivot.position
	_exercise("ground_pivot_xz", "geometry",
		func() -> void: pivot.position.x += .125,
		func() -> void: pivot.position = pivot_position, "pivot may only add localY")
	var unexpected := MeshInstance3D.new()
	unexpected.name = "UnexpectedPivotMesh"
	unexpected.mesh = BoxMesh.new()
	unexpected.material_override = StandardMaterial3D.new()
	_exercise("unexpected_mesh_under_ground_pivot", "geometry",
		func() -> void: pivot.add_child(unexpected),
		func() -> void: unexpected.free())
	var main_rock := game.get_node("ShoreRockA") as Node3D
	var main_position := main_rock.position
	_exercise("main_rock_authored_xz", "geometry",
		func() -> void: main_rock.position.z += .125,
		func() -> void: main_rock.position = main_position, "main-rock XZ must remain authored")
	_exercise("main_rock_frozen_support_y", "geometry",
		func() -> void: main_rock.position.y += .125,
		func() -> void: main_rock.position = main_position, "main-rock complete transform must retain independent frozen supportY")
	var other := game.get_node("FarReefLandmass/Shoreline") as MeshInstance3D
	var normals: PackedVector3Array = other.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL].duplicate()
	normals[0].x += .03125
	_replace_mesh_array("other_island_actual_normal", "FarReefLandmass/Shoreline", Mesh.ARRAY_NORMAL, normals)
	var arrays := other.mesh.surface_get_arrays(0)
	if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array and not arrays[Mesh.ARRAY_INDEX].is_empty():
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX].duplicate()
		var first := indices[0]
		indices[0] = indices[1]
		indices[1] = first
		_replace_mesh_array("other_island_actual_triangle_winding", "FarReefLandmass/Shoreline", Mesh.ARRAY_INDEX, indices)
	else:
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
		var first := vertices[0]
		vertices[0] = vertices[1]
		vertices[1] = first
		_replace_mesh_array("other_island_actual_triangle_winding", "FarReefLandmass/Shoreline", Mesh.ARRAY_VERTEX, vertices)

func _material_cases() -> void:
	var terrain := game.get_node("IslandLandmass/Shoreline").material_override as ShaderMaterial
	var grass: Variant = terrain.get_shader_parameter("grass_diff")
	var sand: Variant = terrain.get_shader_parameter("sand_diff")
	_check(grass != sand, "map calibration needs independently different existing texture resources")
	_exercise("coast_albedo_map_binding", "materials",
		func() -> void: terrain.set_shader_parameter("grass_diff", sand),
		func() -> void: terrain.set_shader_parameter("grass_diff", grass), "complete opening terrain material contract")
	var sea := game.get_node("Sea").material_override as ShaderMaterial
	var depth: Variant = sea.get_shader_parameter("depth_tint")
	_exercise("coast_water_new_tint_uniform", "materials",
		func() -> void: sea.set_shader_parameter("depth_tint", Color(.9, .1, .7, 1)),
		func() -> void: sea.set_shader_parameter("depth_tint", depth), "new presentation uniform may use only frozen default: depth_tint")
	var original_raster := sea.get_shader_parameter("opening_heights") as Texture2D
	var raster_bytes := original_raster.get_image().get_data().duplicate()
	var image := original_raster.get_image().duplicate() as Image
	image.set_pixel(192, 192, Color(image.get_pixel(192, 192).r + .125, 0, 0, 1))
	var altered_raster := ImageTexture.create_from_image(image)
	_check(original_raster.get_image().get_data() == raster_bytes, "preparing a raster mutation must not alter the original ImageTexture backing image")
	_exercise("coast_water_height_raster_pixel", "materials",
		func() -> void: sea.set_shader_parameter("opening_heights", altered_raster),
		func() -> void: sea.set_shader_parameter("opening_heights", original_raster), "water raster must exactly match frozen approved final triangles")
	var old_height: Variant = sea.get_shader_parameter("mean_height")
	_exercise("unprojected_water_mean_height", "materials",
		func() -> void: sea.set_shader_parameter("mean_height", float(old_height) + .03125),
		func() -> void: sea.set_shader_parameter("mean_height", old_height))
	var old_time: Variant = sea.get_shader_parameter("water_time")
	_exercise("unprojected_water_time", "materials",
		func() -> void: sea.set_shader_parameter("water_time", float(old_time) + .125),
		func() -> void: sea.set_shader_parameter("water_time", old_time))
	var old_motion: Variant = sea.get_shader_parameter("gerstner_motion")
	var changed_motion: Vector4 = old_motion
	changed_motion.y += .0625
	_exercise("unprojected_gerstner_wave_phase", "materials",
		func() -> void: sea.set_shader_parameter("gerstner_motion", changed_motion),
		func() -> void: sea.set_shader_parameter("gerstner_motion", old_motion))

func _lighting_and_hud_cases() -> void:
	var existing_lights := game.find_children("*", "OmniLight3D", true, false)
	_check(not existing_lights.is_empty(), "earned home fixture must include its actual original lamp")
	if not existing_lights.is_empty():
		var lamp := existing_lights[0] as OmniLight3D
		var energy := lamp.light_energy
		_exercise("existing_non_sun_light_energy", "lighting",
			func() -> void: lamp.light_energy += .125,
			func() -> void: lamp.light_energy = energy)
	var extra_light := OmniLight3D.new()
	extra_light.name = "UnexpectedCoastLight"
	_exercise("additional_non_sun_light", "lighting",
		func() -> void: game.add_child(extra_light),
		func() -> void: extra_light.free())
	var environment: Environment = game.get("weather_environment")
	var ambient := environment.ambient_light_energy
	_exercise("weather_ambient_not_normalized", "lighting",
		func() -> void: environment.ambient_light_energy += .0625,
		func() -> void: environment.ambient_light_energy = ambient)
	var hud: Node = game.get("nearfuture_hud")
	var overlay: Control = hud.get("overlay")
	var duplicate := overlay.duplicate() as Control
	duplicate.name = "DuplicateNearfutureHud"
	duplicate.process_mode = Node.PROCESS_MODE_DISABLED
	_exercise("additional_hud_overlay", "geometry",
		func() -> void: overlay.get_parent().add_child(duplicate),
		func() -> void: duplicate.free())

func _interact(id: String) -> void:
	for entry in game.get("interactables") as Array:
		if str(entry.get("id", "")) == id:
			(game.get("player") as Node3D).global_position = (entry.node as Node3D).global_position + Vector3.UP * .15
			game.call("_interact")
			return
	_check(false, "missing real earned-fixture interaction: " + id)

func _setup_actions() -> void:
	# Exact same earned-actions fixture as the historical surface gate. Three
	# paid wood collections settle; the final collected shell is still queued.
	# All calibrations below run synchronously before its deletion, so the helper
	# must see its historical exact eight pivots rather than a widened count.
	for pile in range(3):
		_interact("wood")
		await process_frame
	_check(int(game.get("wood")) == 8, "fixture must earn its actual 2+2+3 finite wood piles")
	(game.get("player") as Node3D).position = Vector3(0, 1.1, 1.75)
	_check(bool(game.call("_try_place_workshop_home_template", Vector3(0, .12, 0))), "fixture must pay seven wood for the existing home")
	_interact("resident")
	_interact("shellfish")
	(game.get("player") as Node3D).position = Vector3(.25, 1.1, 1.2)
	_check(bool(game.get("resident_met")) and not (game.get("world_events") as Array).is_empty(), "fixture must retain real meeting/history")

func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/test_opening_coast_oracle_%d_%d" % [OS.get_process_id(), int(Time.get_unix_time_from_system() * 1000000)]).simplify_path()
	if not Paths.is_safe_save_root(save_root):
		_check(false, "unique throwaway test path required; never use a preview/personal save")
		quit(1)
		return
	saves = Save.new(save_root)
	saves.clear_for_test()
	game = Scene.instantiate() as Node3D
	game.set("save_root_override", save_root)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.get("player").set_physics_process(false)
	await physics_frame
	await _setup_actions()
	collector = Collector.new()
	collector.game = game
	history = History.new()
	collector.history = history
	history.configure(game, collector)
	for domain in ["geometry", "materials", "lighting"]:
		baselines[domain] = _evaluate(domain)
	_check(collector.failures.is_empty(), "unmutated independent contract must pass before calibration: " + str(collector.failures))
	if failures == 0:
		var raw_before := _raw_signature()
		_geometry_cases()
		_material_cases()
		_lighting_and_hud_cases()
		_check(cases.size() == 20, "all twenty actual mutate/restore cases must execute")
		for domain in ["geometry", "materials", "lighting"]:
			collector.failures.clear()
			_check(_evaluate(domain) == baselines[domain] and collector.failures.is_empty(), "clean restored independent contract: " + domain)
		_check(_raw_signature() == raw_before, "all calibrations together must retain exact original raw world/authority/state")
	print("COAST_ORACLE_CALIBRATION_CASES: ", JSON.stringify(cases))
	history.observer = null
	collector.history = null
	history = null
	collector = null
	game.set("save_service", null)
	game.queue_free()
	await process_frame
	saves.clear_for_test()
	if failures == 0:
		print("ARK_OPENING_COAST_ORACLE_TEST_OK: twenty actual resource/node mutations rejected and exactly restored; historical coast projection cannot conceal changed geometry/materials/water/non-Sun weather/HUD; old goldens and raw tests remain separate")
	quit(0 if failures == 0 else 1)
