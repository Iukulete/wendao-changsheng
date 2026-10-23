extends SceneTree

## Render-facing regression over the actual world's emitted meshes, not ray hits.
## Two-sided collision made the old inverted surfaces physically walkable.
const Paths = preload("res://tests/ark_test_paths.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
# Captured from the pre-fix official 4.7.1 world (builder SHA256 b2d4f029df9724a55ed1cc1b57e2172016f2b6c4ded279f8d9600b324dccaac7).
# Each SHA sorts vertices WITHIN each triangle, then sorts the triangles. A winding
# reversal is permitted; changing contour, height, triangulation or multiplicity is not.
# Positions are quantized to 0.00001 world units to avoid text formatting noise.
const OLD_WORLD := {
	"FarReefLandmass": {"center": Vector3(39, 0, -29),
		"Grassland": ["e40f023cd219ea7eebace3018f9c6c026b351fa92b1fb2aed3331a4f47b162f3", Color("626451ff")],
		"Shoreline": ["1988c836deb9ac536584c3ecfb16f2796023ec358e541bd35064f2b986ba6f36", Color("b4a274ff")],
	},
	"IslandLandmass": {"center": Vector3(11, 0, -14),
		"Grassland": ["1800e1e839b42884fbf29c52b0f2fb0cefd2358572cd04fc1deb60890bbcb925", Color("536d50ff")],
		"Shoreline": ["0427914e4521f5058f3bd6f14eedf757e1770ef97be447f9350737c41a9c0ae5", Color("77735bff")],
	},
	"JadeSailShoal": {"center": Vector3(-53, 0, -45),
		"Grassland": ["c2f6aae56a8b85a166b68cccdd2bce9b655a49fe30c2bbfc303d1b457d214aed", Color("596856ff")],
		"Shoreline": ["63ee07d14c4e468aa2893d95552e0bf68f2aa7c6862fe19cec4b4b540587fb6c", Color("a09270ff")],
	},
	"MoonbackIsland": {"center": Vector3(-28, 0, 23),
		"Grassland": ["3b9772a9c74d87923c32a6be4e186220050b49b132842d86a34f10e212463e19", Color("4e615aff")],
		"Shoreline": ["6207f5f4c6abf0c4f628dbf0fa277f988b44a44d94f8b393d26c4ac125e35f76", Color("87928aff")],
	},
	"SteamWreckIslet": {"center": Vector3(92, 0, 86),
		"Grassland": ["d7ca4252640240902c735d5165379be46d08df9c82d22d501dc7fbb15b87660e", Color("555d54ff")],
		"Shoreline": ["4daf8b10f5bc0a2013f7d33a4d62a8c41f1cf992623a351dfaa4b0151a29a4bf", Color("98795eff")],
	},
}
var game: Node3D
var saves: RefCounted
var save_root: String
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("LANDMASS_SURFACE: " + message)


func _spawn() -> void:
	game = load("res://scenes/ark_greybox.tscn").instantiate() as Node3D
	game.set("save_root_override", save_root)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	(game.get("player") as Node).set_physics_process(false)
	await physics_frame


func _drop() -> void:
	game.set("save_service", null)
	game.queue_free()
	await process_frame


func _point(v: Vector3) -> String:
	return "%d,%d,%d" % [roundi(v.x * 100000.0), roundi(v.y * 100000.0), roundi(v.z * 100000.0)]


func _geometry(faces: PackedVector3Array) -> String:
	var triangles: Array[String] = []
	for i in range(0, faces.size(), 3):
		var points: Array[String] = [_point(faces[i]), _point(faces[i + 1]), _point(faces[i + 2])]
		points.sort()
		triangles.append("|".join(points))
	triangles.sort()
	return "\n".join(triangles).sha256_text()


func _clockwise_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	# Godot's front faces wind clockwise when viewed from the front.
	return (c - a).cross(b - a).normalized()


func _calibrate_oracle() -> void:
	# Independently verify the sign against the engine's own +Y PlaneMesh,
	# rather than reproducing the landmass builder's triangle ordering.
	var plane := PlaneMesh.new()
	var faces := plane.get_faces()
	var normals: PackedVector3Array = plane.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	_check(faces.size() == 6 and normals.size() == 4, "built-in calibration plane must have two triangles and four normals")
	for normal in normals:
		_check(normal.dot(Vector3.UP) > 0.9999, "built-in calibration normals must face up")
	for i in range(0, faces.size(), 3):
		_check(_clockwise_normal(faces[i], faces[i + 1], faces[i + 2]).dot(Vector3.UP) > 0.9999, "clockwise oracle must agree with actual engine PlaneMesh")
		_check(_clockwise_normal(faces[i], faces[i + 2], faces[i + 1]).dot(Vector3.UP) < -0.9999, "oracle must reject a reversed engine triangle")
	var reversed := PackedVector3Array([faces[0], faces[2], faces[1], faces[3], faces[5], faces[4]])
	_check(_geometry(faces) == _geometry(reversed), "geometry oracle must permit winding reversal")
	reversed[0] += Vector3(0.001, 0, 0)
	_check(_geometry(faces) != _geometry(reversed), "geometry oracle must reject a contour change")


func _inspect_world(label: String) -> Dictionary:
	var result := {}
	var total := 0
	for id in OLD_WORLD:
		var island := game.get_node_or_null(NodePath(id)) as StaticBody3D
		_check(island != null, label + " must reconstruct " + id)
		if island == null:
			continue
		_check(island.position.is_equal_approx(OLD_WORLD[id].center) and island.basis.is_equal_approx(Basis.IDENTITY) and island.is_visible_in_tree(), id + " must retain its old world transform and visibility")
		_check(island.collision_layer == 1 and island.collision_mask == 1 and island.get_child_count() == 4, id + " must retain the old land collision policy and exactly two visual/shape pairs")
		var island_total := 0
		for part in ["Grassland", "Shoreline"]:
			var key: String = id + "/" + part
			var visual := island.get_node(part) as MeshInstance3D
			var mesh := visual.mesh as ArrayMesh
			_check(mesh != null and mesh.get_surface_count() == 1, key + " must retain one actual ArrayMesh surface")
			if mesh == null or mesh.get_surface_count() != 1:
				continue
			_check(mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES, key + " must remain triangles")
			_check(visual.transform.is_equal_approx(Transform3D.IDENTITY) and visual.is_visible_in_tree(), key + " must not hide, translate or rotate to compensate for inverted geometry")
			var arrays := mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var faces := mesh.get_faces()
			var expected_count := 480 if part == "Grassland" else 320
			_check(faces.size() == expected_count * 3 and vertices.size() == expected_count * 3 and normals.size() == vertices.size(), key + " must retain original triangle and normal counts")
			_check(arrays[Mesh.ARRAY_INDEX] == null or (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty(), key + " must retain the actual non-indexed surface layout")
			var nondegenerate := 0
			var up_faces := 0
			var up_normals := 0
			var aligned_normals := 0
			for i in range(0, faces.size(), 3):
				var area := (faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i])
				if area.length_squared() > 0.0000000001:
					nondegenerate += 1
				var front := _clockwise_normal(faces[i], faces[i + 1], faces[i + 2])
				if front.y > 0.0:
					up_faces += 1
				for offset in range(3):
					if i + offset < normals.size():
						var normal := normals[i + offset]
						if normal.is_finite() and normal.y > 0.0 and absf(normal.length() - 1.0) < 0.0001:
							up_normals += 1
						# SurfaceTool smooths shared-position normals; require the same
						# outward hemisphere, not exact equality to a flat face normal.
						if normal.dot(front) > 0.99:
							aligned_normals += 1
			_check(nondegenerate == expected_count, key + " must contain only nondegenerate triangles")
			_check(up_faces == expected_count, "%s has %d/%d up-facing clockwise triangles; two-sided collision is not proof of rendered visibility" % [key, up_faces, expected_count])
			_check(up_normals == expected_count * 3 and aligned_normals == expected_count * 3, "%s must have unit up-facing normals aligned to every rendered front face; got up=%d aligned=%d" % [key, up_normals, aligned_normals])
			var digest := _geometry(faces)
			_check(digest == OLD_WORLD[id][part][0], key + " changed the old per-triangle vertex sets/contour/heights")
			var material := visual.material_override as StandardMaterial3D
			_check(material != null, key + " must retain its opaque standard material")
			if material:
				_check(material.cull_mode == BaseMaterial3D.CULL_BACK and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, key + " must keep default backface culling, not disguise winding by making both sides visible")
				_check(material.albedo_color.is_equal_approx(OLD_WORLD[id][part][1]) and is_equal_approx(material.roughness, 1.0) and not material.vertex_color_use_as_albedo, key + " must retain original material colors/lighting policy")
			var collision := island.get_node(part + "Collision") as CollisionShape3D
			var shape := collision.shape as ConcavePolygonShape3D
			_check(shape != null and not collision.disabled and collision.transform.is_equal_approx(Transform3D.IDENTITY), key + " collision must remain enabled and untransformed")
			if shape:
				_check(shape.backface_collision and _geometry(shape.get_faces()) == digest, key + " must retain the same two-sided collision geometry, not alter traversability")
			result[key] = digest
			island_total += nondegenerate
			total += nondegenerate
			print("LANDMASS_SURFACE_OBSERVATION: ", label, " ", key, " triangles=", nondegenerate, " upward_faces=", up_faces, " upward_normals=", up_normals, " geometry=", digest)
		_check(island_total == 800, id + " must retain all 800 nondegenerate triangles")
	_check(total == 4000, label + " must inspect all 4000 actual generated world triangles")
	return result


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _state() -> Dictionary:
	return _json(game.call("_build_save_state")) as Dictionary


func _semantics(state: Dictionary) -> Dictionary:
	var result := {}
	# Capture the complete persistence contract except schema-version migration
	# and message presentation. Runtime-only navigation/water IDs are separately
	# covered by their unchanged canonical regressions.
	for field in state:
		if field not in ["schema_version", "message", "vessel_navigation", "water"]:
			result[field] = state[field]
	# Restoration deliberately invalidates stale asynchronous gather handles;
	# this counter is not an earned resource, task outcome, or history record.
	result = result.duplicate(true)
	(result.modules.gathering as Dictionary).erase("generation")
	return result


func _actor_pose() -> Array:
	var result: Array = []
	for property in ["player", "traveler_marker", "sailmaker_marker", "jade_sail_keeper_marker", "ark_root"]:
		var actor := game.get(property) as Node3D
		if actor == null and property in ["traveler_marker", "sailmaker_marker"]:
			actor = game.get_node_or_null("residentMarker" if property == "traveler_marker" else "sailmakerMarker") as Node3D
		if actor == null:
			result.append([property, null])
			continue
		result.append([property, str(actor.get_parent().name), actor.position, actor.basis])
	return result


func _poses_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for index in range(a.size()):
		if a[index].size() != b[index].size() or a[index][0] != b[index][0] or a[index][1] != b[index][1]:
			return false
		if a[index].size() == 4 and (not (a[index][2] as Vector3).is_equal_approx(b[index][2]) or not (a[index][3] as Basis).is_equal_approx(b[index][3])):
			return false
	return true


func _exercise_existing_actions() -> void:
	# Stage only proximity, never fabricate collection/meeting records or rewards.
	# Long physical crossings stay in the unchanged world-travel regression.
	var player := game.get("player") as Node3D
	var wood_before := int(game.get("wood"))
	for interaction in ["wood", "resident"]:
		for entry in game.get("interactables") as Array:
			if str(entry.get("id", "")) == interaction:
				player.global_position = (entry.node as Node3D).global_position + Vector3.UP * 0.5
				game.call("_interact")
				break
	_check(int(game.get("wood")) > wood_before and bool(game.get("resident_met")), "fixture must really collect existing wood and meet the resident through normal interactions")
	_check(not (game.get("collected_ids") as Array).is_empty() and not (game.get("world_events") as Array).is_empty(), "save fixture must contain real acquisition/history, not empty-state-only coverage")
	player.position = Vector3(0.25, 1.1, 1.2)
	var ark := game.get("ark_root") as Node3D
	var before := ark.transform
	game.set("sailing_mode", true)
	_check(bool(game.call("_sail_step", 0.2, -1.0, 0.25)), "unchanged collision-checked sailing must remain usable")
	game.set("sailing_mode", false)
	_check(not ark.transform.is_equal_approx(before), "save fixture must include genuine vessel translation and yaw")


func _assert_reconstructed(expected: Dictionary, actors: Array, geometry: Dictionary, label: String) -> void:
	_check(not bool(game.get_meta("save_load_blocked", false)), label + " must load without a migration block")
	var current := _semantics(_state())
	for field in expected:
		_check(current.has(field) and current[field] == expected[field], label + " must preserve saved actor/boat/resource/history field: " + field)
	_check(_poses_equal(_actor_pose(), actors), label + " must preserve actor parents/local poses and boat transform")
	_check(_inspect_world(label) == geometry, label + " must reconstruct the same five islands without serializing terrain")


func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/test_landmass_surface_%d_%d" % [OS.get_process_id(), int(Time.get_unix_time_from_system() * 1000000.0)]).simplify_path()
	assert(Paths.is_safe_save_root(save_root), "landmass regression requires a unique repository-local test-only save root")
	saves = Save.new(save_root)
	saves.clear_for_test()
	_calibrate_oracle()
	await _spawn()
	var original_state := _state()
	var geometry := _inspect_world("fresh_world")
	_check(_state() == original_state, "terrain observation must not mutate gameplay state")
	# Stop cleanly on the original bug, after printing evidence for all five islands.
	if failures > 0:
		await _drop()
		saves.clear_for_test()
		print("ARK_LANDMASS_SURFACE_TEST_RED: failures=", failures)
		quit(1)
		return
	_exercise_existing_actions()
	_check(bool(game.call("_save_progress")), "actual action state must save successfully")
	var saved: Dictionary = saves.load_state().get("state", {})
	_check(int(saved.schema_version) == 36 and str(ProjectSettings.get_setting("application/config/version")) == "0.1.003", "terrain orientation must not bump save or game version")
	for id in OLD_WORLD:
		_check(not JSON.stringify(saved).contains(id), "static land geometry must not leak into saves")
	var expected := _semantics(_json(saved))
	var actors := _actor_pose()
	await _drop()
	await _spawn()
	_assert_reconstructed(expected, actors, geometry, "current_fresh_load")
	for repeat in range(2):
		game.call("_load_progress")
		await process_frame
		_assert_reconstructed(expected, actors, geometry, "current_repeat_%d" % repeat)
	# Schema 35 is a historical-format fixture generated from real actions, NOT
	# a claim that new meetings/harvests happened in a historical user save.
	var legacy := saved.duplicate(true)
	legacy.schema_version = 35
	for field in ["sailmaker_awning_phase", "sailmaker_awning_sewing_elapsed", "sailmaker_awning_install_elapsed"]:
		legacy.erase(field)
	_check(bool(saves.save_state(legacy).get("ok", false)), "previous-schema fixture must be accepted")
	await _drop()
	await _spawn()
	_assert_reconstructed(expected, actors, geometry, "schema35_fresh_load")
	for repeat in range(2):
		game.call("_load_progress")
		await process_frame
		_assert_reconstructed(expected, actors, geometry, "schema35_repeat_%d" % repeat)
	await _drop()
	# Optional read-only PRE-FIX test envelope captured before production edits.
	# Copy into our unique throwaway slot; never open an ordinary save for writing.
	var old_fixture := OS.get_environment("ARK_LANDMASS_OLD_TEST_SAVE")
	if not old_fixture.is_empty():
		saves.clear_for_test()
		DirAccess.make_dir_recursive_absolute(save_root)
		var file := FileAccess.open(saves.get_save_path(), FileAccess.WRITE)
		assert(file != null)
		file.store_string(FileAccess.get_file_as_string(old_fixture))
		file.close()
		var loaded: Dictionary = saves.load_state()
		_check(bool(loaded.get("ok", false)), "actual pre-fix test envelope must pass normal checksum/schema validation")
		if loaded.get("ok", false):
			await _spawn()
			var old_expected := _semantics(_json(loaded.state))
			var old_actors := _actor_pose()
			_assert_reconstructed(old_expected, old_actors, geometry, "actual_pre_fix_save")
			for repeat in range(2):
				game.call("_load_progress")
				await process_frame
				_assert_reconstructed(old_expected, old_actors, geometry, "actual_pre_fix_repeat_%d" % repeat)
			await _drop()
	saves.clear_for_test()
	if failures == 0:
		print("ARK_LANDMASS_SURFACE_TEST_OK: all five actual islands, 4000 clockwise faces, 12000 normals, old geometry/material/collision policy, current/legacy/repeated save reconstruction")
	else:
		print("ARK_LANDMASS_SURFACE_TEST_RED: failures=", failures)
	quit(1 if failures > 0 else 0)
