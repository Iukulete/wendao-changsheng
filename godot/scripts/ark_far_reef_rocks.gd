extends RefCounted
## Only the two named FarReef rocks. World geometry, never a graphics-mode toggle.
## Inset water cliffs and grass-connected land shoulders, entirely inside the formal080 Boxes.

func definition(id: String) -> Dictionary:
	if id == "FarReefRockA":
		return {"origin": Vector3(34, 0.95, -28), "size": Vector3(2.5, 2, 2.4),
			"top": PackedVector3Array([
				Vector3(-1.15, -0.73, -1.1), Vector3(-0.7, -0.75, -1.18), Vector3(-0.18, -0.73, -1.12), Vector3(0.55, -0.50, -1.2), Vector3(1.25, -0.91, -1.2),
				Vector3(-1.18, -0.71, -0.55), Vector3(-0.65, -0.59, -0.6), Vector3(-0.12, -0.46, -0.5), Vector3(0.53, -0.49, -0.62), Vector3(1.25, -0.91, -0.55),
				Vector3(-1.15, -0.73, 0.12), Vector3(-0.62, -0.47, 0.16), Vector3(-0.18, -0.27, 0.12), Vector3(0.55, -0.50, 0.03), Vector3(1.25, -0.91, 0.12),
				Vector3(-1.22, -0.75, 0.65), Vector3(-0.58, -0.57, 0.63), Vector3(-0.1, -0.51, 0.72), Vector3(0.6, -0.53, 0.62), Vector3(1.25, -0.91, 0.65),
				Vector3(-1.15, -0.73, 1.1), Vector3(-0.7, -0.75, 1.18), Vector3(-0.18, -0.73, 1.03), Vector3(0.55, -0.50, 1.15), Vector3(1.25, -0.91, 1.2)
			]), "exposure": PackedFloat32Array([128, 128, 128, 128, 0, 128, 32, 160, 96, 0, 128, 208, 255, 224, 0, 128, 64, 176, 16, 0, 128, 128, 128, 128, 0])}
	if id == "FarReefRockB":
		return {"origin": Vector3(44, 0.8, -32), "size": Vector3(3.2, 1.7, 2.4),
			"top": PackedVector3Array([
				Vector3(-1.5, -0.58, -1.1), Vector3(-0.78, -0.58, -1.16), Vector3(0.12, -0.58, -1.2), Vector3(0.82, -0.58, -1.2), Vector3(1.6, -0.58, -1.2),
				Vector3(-1.6, -0.76, -0.64), Vector3(-0.78, -0.29, -0.58), Vector3(0.18, -0.38, -0.62), Vector3(0.8, -0.35, -0.54), Vector3(1.6, -0.58, -0.64),
				Vector3(-1.6, -0.76, -0.1), Vector3(-0.72, -0.25, -0.04), Vector3(0.12, -0.18, -0.1), Vector3(0.75, -0.4, 0.06), Vector3(1.6, -0.58, -0.1),
				Vector3(-1.6, -0.76, 0.57), Vector3(-0.85, -0.34, 0.58), Vector3(0.04, -0.36, 0.55), Vector3(0.84, -0.35, 0.63), Vector3(1.6, -0.58, 0.57),
				Vector3(-1.6, -0.76, 1.2), Vector3(-0.78, -0.76, 1.2), Vector3(0.12, -0.76, 1.2), Vector3(0.82, -0.58, 1.12), Vector3(1.6, -0.58, 1.2)
			]), "exposure": PackedFloat32Array([128, 128, 128, 128, 128, 0, 32, 160, 96, 128, 0, 208, 255, 224, 128, 0, 64, 176, 16, 128, 0, 0, 0, 128, 128])}
	return {}

func _triangle(faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	# Godot front faces are clockwise. Physics and visible arrays consume these same faces.
	if (b - a).cross(c - a).dot(outward) > 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
	faces.append(a)
	faces.append(b)
	faces.append(c)

func authored_faces(id: String) -> PackedVector3Array:
	var spec: Dictionary = definition(id)
	if spec.is_empty(): return PackedVector3Array()
	var size: Vector3 = spec["size"]
	var top: PackedVector3Array = spec["top"]
	var faces := PackedVector3Array()
	# Staggered interior ridges and alternating short diagonals, not one cross-rock plane.
	for row in range(4):
		for col in range(4):
			var q: int = row * 5 + col
			if (row + col) % 2 == 0:
				_triangle(faces, top[q], top[q + 1], top[q + 6], Vector3.UP)
				_triangle(faces, top[q], top[q + 6], top[q + 5], Vector3.UP)
			else:
				_triangle(faces, top[q], top[q + 1], top[q + 5], Vector3.UP)
				_triangle(faces, top[q + 1], top[q + 6], top[q + 5], Vector3.UP)
	# Follow the real inset outline all the way down; no hidden rectangular bottom.
	var perimeter := PackedInt32Array([0,1,2,3,4,9,14,19,24,23,22,21,20,15,10,5])
	var low_center := Vector3(0, -size.y * .5, 0)
	for i in range(perimeter.size()):
		var a: Vector3 = top[perimeter[i]]
		var b: Vector3 = top[perimeter[(i + 1) % perimeter.size()]]
		var low_a := Vector3(a.x, -size.y * .5, a.z)
		var low_b := Vector3(b.x, -size.y * .5, b.z)
		var outward := Vector3(b.z - a.z, 0, a.x - b.x)
		_triangle(faces, a, b, low_b, outward)
		_triangle(faces, a, low_b, low_a, outward)
	# Keep one contiguous top/side/bottom index domain for native normal QA.
	for i in range(perimeter.size()):
		var a: Vector3 = top[perimeter[i]]
		var b: Vector3 = top[perimeter[(i + 1) % perimeter.size()]]
		_triangle(faces, low_center, Vector3(a.x, -size.y * .5, a.z), Vector3(b.x, -size.y * .5, b.z), Vector3.DOWN)
	return faces

func terrain_normal(terrain: Node3D, root_point: Vector3) -> Dictionary:
	# Read only the already-built two FarReef surfaces, never a physics query or UP guess.
	# Both terrain and rocks are direct children of the same world root.
	var hit: Dictionary = {}
	if terrain == null: return hit
	for name_: String in ["Grassland", "Shoreline"]:
		var visual := terrain.get_node_or_null(name_) as MeshInstance3D
		if visual == null or not visual.mesh is ArrayMesh: continue
		var arrays: Array = visual.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var relative: Transform3D = terrain.transform * visual.transform
		var normal_basis: Basis = relative.basis.inverse().transposed()
		if normals.size() != vertices.size(): continue
		for i in range(0, vertices.size(), 3):
			var a: Vector3 = relative * vertices[i]
			var b: Vector3 = relative * vertices[i + 1]
			var c: Vector3 = relative * vertices[i + 2]
			var edge_b := Vector2(b.x - a.x, b.z - a.z)
			var edge_c := Vector2(c.x - a.x, c.z - a.z)
			var offset := Vector2(root_point.x - a.x, root_point.z - a.z)
			var determinant: float = edge_b.cross(edge_c)
			if determinant == 0.0: continue
			var wb: float = offset.cross(edge_c) / determinant
			var wc: float = edge_b.cross(offset) / determinant
			var wa: float = 1.0 - wb - wc
			if not is_finite(wa) or not is_finite(wb) or not is_finite(wc) or minf(wa, minf(wb, wc)) < 0.0: continue
			var height: float = a.y * wa + b.y * wb + c.y * wc
			var normal: Vector3 = normal_basis * (normals[i] * wa + normals[i + 1] * wb + normals[i + 2] * wc)
			if not normal.is_finite() or normal.length_squared() == 0.0 or normal.y <= 0.0: continue
			if hit.is_empty() or height > float(hit.height):
				hit = {"surface": name_, "triangle_start": i, "weights": Vector3(wa, wb, wc), "height": height, "normal": normal.normalized()}
	return hit

func _top_normals(spec: Dictionary, faces: PackedVector3Array, terrain: Node3D) -> PackedVector3Array:
	var top: PackedVector3Array = spec["top"]
	var exposure: PackedFloat32Array = spec["exposure"]
	var origin: Vector3 = spec["origin"]
	var sums := PackedVector3Array()
	sums.resize(top.size())
	# Only the original 32 cap triangles participate. No side/bottom contribution.
	for i in range(0, 96, 3):
		var area_normal: Vector3 = -(faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i])
		for j in range(3):
			var index: int = top.find(faces[i + j])
			sums[index] += area_normal
	for i in range(top.size()):
		var smooth: Vector3 = sums[i].normalized()
		var sample: Dictionary = terrain_normal(terrain, origin + top[i])
		# Where the old footprint extends beyond actual land, retain its real cap normal.
		# Else reuse the existing exposed-stone weight: outer sand matches actual terrain,
		# inner stone retains the area-weighted slope. Never flatten side faces upward.
		if not sample.is_empty():
			var stone: float = smoothstep(0.05, 0.85, exposure[i] / 255.0)
			var ground_normal: Vector3 = sample["normal"]
			smooth = ground_normal.lerp(smooth, stone).normalized()
		sums[i] = smooth
	return sums

func build_rock(id: String, terrain: Node3D = null) -> StaticBody3D:
	var spec: Dictionary = definition(id)
	if spec.is_empty():
		push_error("FarReefRocks: unknown named rock")
		return null
	var faces: PackedVector3Array = authored_faces(id)
	var top: PackedVector3Array = spec["top"]
	var exposure: PackedFloat32Array = spec["exposure"]
	var cap_normals: PackedVector3Array = _top_normals(spec, faces, terrain)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, faces.size(), 3):
		var normal: Vector3 = -(faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i]).normalized()
		for j in range(3):
			var point: Vector3 = faces[i + j]
			var index: int = top.find(point)
			surface.set_normal(cap_normals[index] if i < 96 else normal)
			var stone: float = exposure[index] / 255.0 if index >= 0 else 0.0
			surface.set_color(Color(stone, stone, stone, 1.0))
			if absf(normal.y) >= maxf(absf(normal.x), absf(normal.z)): surface.set_uv(Vector2(point.x, point.z))
			elif absf(normal.x) >= absf(normal.z): surface.set_uv(Vector2(point.z, point.y))
			else: surface.set_uv(Vector2(point.x, point.y))
			surface.add_vertex(point)
	surface.generate_tangents()
	var mesh: ArrayMesh = surface.commit()
	var body := StaticBody3D.new()
	body.name = id
	body.position = spec["origin"]
	body.collision_layer = 1
	body.collision_mask = 1
	body.set_meta("far_reef_world_shape", id)
	var visual := MeshInstance3D.new()
	visual.name = "RockVisual"
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("686c68")
	material.roughness = 0.84
	visual.material_override = material
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.name = "RockCollision"
	# Use the final nonindexed render surface directly. Mesh.get_faces()/create_trimesh_shape()
	# pass through TriangleMesh's snappedf(.0001), which changes the exact old footprint.
	var mesh_arrays: Array = mesh.surface_get_arrays(0)
	var actual_faces: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX]
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(actual_faces)
	shape.backface_collision = true
	collision.shape = shape
	body.add_child(collision)
	return body
