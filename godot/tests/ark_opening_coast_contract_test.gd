extends SceneTree
## Permanent native contract, not an aesthetic/FPS gate. Frozen geometry and
## water authority are checked independently from same-runtime preservation.
const Paths = preload("res://tests/ark_test_paths.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
const WATER_SHA := "89daf71344da795262bd94dc726ac7ef710fb17b7257d03ced764be3ea12e994"
var game: Node3D
var failures := 0
var save_root: String

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("OPENING_COAST: " + message)

func _bytes(value: Variant) -> String:
	return var_to_bytes(value).hex_encode().sha256_text()

func _point(p: Vector3) -> String:
	return "%.6f,%.6f,%.6f" % [p.x, p.y, p.z]

func _raw() -> Dictionary:
	var result := {}
	for node in game.find_children("*", "", true, false):
		var row: Array = [node.get_instance_id()]
		if node is Node3D:
			row.append(node.transform)
		if node is MeshInstance3D:
			row.append(node.mesh.get_instance_id())
			for index in range(node.mesh.get_surface_count()):
				row.append(_bytes(node.mesh.surface_get_arrays(index)))
			row.append(node.material_override.get_instance_id() if node.material_override else 0)
		if node is CollisionShape3D:
			row.append(node.shape.get_instance_id())
			if node.shape is ConcavePolygonShape3D:
				row.append(_bytes(node.shape.get_faces()))
			elif node.shape is ConvexPolygonShape3D:
				row.append(_bytes(node.shape.points))
		result[str(game.get_path_to(node))] = row
	return result

func _top_contract() -> void:
	var island := game.get_node("IslandLandmass") as StaticBody3D
	var visual := island.get_node("Shoreline") as MeshInstance3D
	var mesh := visual.mesh as ArrayMesh
	var collider := island.get_node("ShorelineCollision") as CollisionShape3D
	var shape := collider.shape as ConcavePolygonShape3D
	_check(island.position == Vector3(11,0,-14) and island.basis == Basis.IDENTITY and island.collision_layer == 1 and island.collision_mask == 1, "opening transform/collision policy stays exact")
	_check(island.get_child_count() == 5 and not island.get_node("Grassland").visible and island.get_node("GrasslandCollision").disabled, "one final top/collider plus one submerged visual cap; legacy grass not colliding")
	_check(mesh != null and mesh.get_surface_count() == 1 and visual.transform == Transform3D.IDENTITY, "top uses one untransformed ArrayMesh")
	if mesh == null:
		return
	var faces := mesh.get_faces()
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	_check(faces.size() == 7127*3 and vertices.size() == faces.size(), "frozen final coast has exactly7127 nonindexed top triangles")
	_check(shape != null and not collider.disabled and shape.backface_collision and _bytes(shape.get_faces()) == _bytes(faces), "actual collider must exactly equal final rendered top faces in this runtime")
	_check(normals.size() == vertices.size() and uv.size() == vertices.size() and tangents.size() == vertices.size()*4, "normals/UV/tangents cover every actual emitted vertex")
	var edges := {}
	var unique := {}
	var bad_faces := 0
	var bad_normals := 0
	var bad_uv := 0
	for index in range(vertices.size()):
		unique[_point(vertices[index])] = true
		if not normals[index].is_finite() or normals[index].y <= 0 or absf(normals[index].length()-1) > .0001:
			bad_normals += 1
		if uv[index] != Vector2(vertices[index].x, vertices[index].z):
			bad_uv += 1
	for value in tangents:
		_check(is_finite(value), "every tangent component is finite")
	for index in range(0,faces.size(),3):
		var front := (faces[index+2]-faces[index]).cross(faces[index+1]-faces[index])
		if front.y <= .000000001:
			bad_faces += 1
		for pair in [[0,1],[1,2],[2,0]]:
			var a: Vector3 = faces[index+pair[0]]
			var b: Vector3 = faces[index+pair[1]]
			var names: Array[String] = [_point(a),_point(b)]
			names.sort()
			var key := "|".join(names)
			if not edges.has(key):
				edges[key] = {"count": 0, "a": a, "b": b}
			edges[key].count += 1
	var boundary := 0
	var invalid := 0
	for edge in edges.values():
		if edge.count == 1:
			boundary += 1
			if not is_equal_approx(edge.a.y,-1.6) or not is_equal_approx(edge.b.y,-1.6):
				invalid += 1
		elif edge.count != 2:
			invalid += 1
	_check(unique.size() == 3614 and boundary == 99 and invalid == 0 and bad_faces == 0, "independent welded-topology audit:3614vertices/99original-outline edges/no degenerate or interior-open edges")
	_check(bad_normals == 0 and bad_uv == 0, "actual normals are up/unit and every UV equals local vertexXZ")
	var cap := island.get_node("SubmergedVisualCap") as MeshInstance3D
	_check(cap.mesh.get_faces().size() == 96*3 and cap.material_override == visual.material_override, "exact96triangle submerged visual cap shares coast material")
	_check(game.find_children("CoastClusterRock*","StaticBody3D",true,false).size() == 9, "exactly9 additional matched rock bodies")
	for index in range(9):
		var body := game.get_node("CoastClusterRock%02d" % index) as StaticBody3D
		_check(body.get_child_count() == 2 and body.get_child(0) is MeshInstance3D and body.get_child(1) is CollisionShape3D, "each satellite keeps one mesh and one collider")
		var rock_mesh: Mesh = body.get_child(0).mesh
		var rock_shape := body.get_child(1).shape as ConvexPolygonShape3D
		_check(rock_shape != null and _bytes(rock_mesh.get_faces()) == _bytes(rock_shape.points), "satellite hull points derive from exact actual rock mesh")
	var rock08 := game.get_node("CoastClusterRock08") as Node3D
	_check(is_equal_approx(rock08.position.x,17.35) and is_equal_approx(rock08.position.z,-18), "only proven Rock08 relocation stays frozen")

func _other_islands() -> void:
	var builder := load("res://scripts/ark_landmass_builder.gd").new() as RefCounted
	for row in [["FarReefLandmass",Vector3(39,0,-29),Vector2(7.5,6),3.7,Color("626451"),Color("b4a274")], ["MoonbackIsland",Vector3(-28,0,23),Vector2(14,12),5.4,Color("4e615a"),Color("87928a")], ["JadeSailShoal",Vector3(-53,0,-45),Vector2(10,8),9.1,Color("596856"),Color("a09270")], ["SteamWreckIslet",Vector3(92,0,86),Vector2(14,11),14.7,Color("555d54"),Color("98795e")]]:
		var expected: StaticBody3D = builder.callv("build_island",row)
		var actual := game.get_node(row[0]) as StaticBody3D
		_check(actual.transform == expected.transform and actual.get_child_count() == 4, "other island root unchanged:"+row[0])
		for part in ["Shoreline","Grassland"]:
			var a: MeshInstance3D = actual.get_node(part)
			var b: MeshInstance3D = expected.get_node(part)
			_check(_bytes(a.mesh.surface_get_arrays(0)) == _bytes(b.mesh.surface_get_arrays(0)), "every raw other-island array including absentUV unchanged:"+row[0]+part)
			_check(_bytes(actual.get_node(part+"Collision").shape.get_faces()) == _bytes(expected.get_node(part+"Collision").shape.get_faces()), "other island collider bytes unchanged:"+row[0]+part)
			_check(a.material_override.albedo_color == b.material_override.albedo_color and a.visible, "other island material/visibility unchanged")
		expected.free()

func _raster_and_water() -> void:
	var coast: RefCounted = game.get("opening_coast")
	var texture: ImageTexture = coast.get("height_texture")
	var image := texture.get_image()
	_check(image.get_size() == Vector2i(384,384) and image.get_format() == Image.FORMAT_RF, "one384squareRF triangle-derived height raster")
	_check(image.get_pixel(0,0).r == -3.0 and image.get_pixel(383,383).r == -3.0, "outside height support uses exact deep sentinel")
	var material := game.get_node("Sea").material_override as ShaderMaterial
	_check(material.get_shader_parameter("opening_heights") == texture and FileAccess.get_sha256("res://shaders/ark_ocean.gdshader") == WATER_SHA, "frozen water shader and actual final raster are bound")
	var sea_mesh := game.get_node("Sea").mesh as PlaneMesh
	_check(sea_mesh.size == Vector2(300,300) and sea_mesh.subdivide_width == 199 and sea_mesh.subdivide_depth == 199 and is_equal_approx(game.get_node("Sea").position.y, -1.05), "water tessellation/mean plane unchanged")
	var authority: RefCounted = game.get("water")
	var before: Dictionary = authority.snapshot().duplicate(true)
	var queries: Array = []
	var positions := [Vector3.ZERO,Vector3(11,0,-7),Vector3(7,0,-4),Vector3(20,0,-10),Vector3(-5,0,4)]
	for point in positions:
		var result: Dictionary = authority.query(point)
		_check(result.ok and is_finite(result.height) and result.normal.is_finite() and absf(result.normal.length()-1) < .00001, "native water queries remain finite/unit")
		queries.append(result.duplicate(true))
	for repeat in range(3):
		authority.apply_visual(material)
	_check(before == authority.snapshot(), "visual binding cannot advance or modify water authority")
	for index in range(positions.size()):
		_check(queries[index] == authority.query(positions[index]), "same-time full query dictionary remains exact")
	var excluded: Array[RID] = []
	var island := game.get_node("IslandLandmass") as StaticBody3D
	for node in game.find_children("*","CollisionObject3D",true,false):
		if node != island:
			excluded.append(node.get_rid())
	var space := game.get_world_3d().direct_space_state
	for point in [Vector3(11,0,-14),Vector3(16.2,0,-18.1),Vector3(9,0,-4),Vector3(8.4,0,-6.1),Vector3(13,0,-6),Vector3(20,0,-17)]:
		var expected: Variant = coast.sample_height(point)
		var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*4,point+Vector3.DOWN*3,1,excluded)
		ray.hit_back_faces = true
		var hit := space.intersect_ray(ray)
		_check(expected != null and hit.get("collider") == island and absf(float(expected)-hit.position.y) < .0001, "native ray equals final triangle sample at"+str(point))

func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/test_opening_coast_contract_%d" % OS.get_process_id()).simplify_path()
	_check(Paths.is_safe_save_root(save_root), "isolated test save root")
	var saves := Save.new(save_root)
	saves.clear_for_test()
	game = load("res://scenes/ark_greybox.tscn").instantiate()
	game.set("save_root_override",save_root)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.get("player").set_physics_process(false)
	_check(game.get("opening_coast_result").ok and not game.get_meta("save_load_blocked",false), "real production construction/load succeeded")
	await physics_frame
	# Missing imported maps fail before producing materials; no fallback silently
	# claims the reviewed look or changes any world dependency/state.
	var material_builder := load("res://scripts/presentation/ark_coast_materials.gd").new() as RefCounted
	var before_missing := _raw()
	var absent: Dictionary = material_builder.build("res://art/coast/nonexistent_regression")
	_check(not absent.ok and absent.materials.is_empty() and absent.errors.size() == 9, "all missing reviewed map dependencies reject safely")
	_check(_raw() == before_missing, "missing material dependencies never mutate world")
	_top_contract()
	_other_islands()
	_raster_and_water()
	var state: Dictionary = game.call("_build_save_state").duplicate(true)
	var raw := _raw()
	var coast: RefCounted = game.get("opening_coast")
	var texture: Texture2D = coast.get("height_texture")
	for repeat in range(12):
		_check(coast.initialize(game,{}).get("reused",false), "static reinitialize reuses scene geometry")
		_check(coast.refresh_loaded_visuals().ok, "load grounding repeats safely")
		coast.refresh_moving_actors()
		coast.reconcile_loaded_player()
	_check(_raw() == raw and coast.get("height_texture") == texture, "12 repeats preserve every live node/mesh/material/collider/transform/raster ID and raw array")
	_check(game.call("_build_save_state") == state, "12 presentation repeats preserve complete gameplay state")
	game.set("save_service",null)
	game.queue_free()
	await process_frame
	saves.clear_for_test()
	if failures == 0:
		print("ARK_OPENING_COAST_CONTRACT_TEST_OK: exact topology/collision/UV/raster/water/four-island and idempotence contracts; not final-art or FPS acceptance")
	quit(0 if failures == 0 else 1)
