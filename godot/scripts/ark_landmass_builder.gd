extends RefCounted

## Small deterministic low-poly landforms for the first continuous-world slice.
## Kept separate from gameplay state so the greybox can later swap to authored
## Terrain3D landscapes without changing save IDs or interaction logic.

const GRASS_RADIUS := 0.76
const GRASS_RINGS := 8
const SHORE_RINGS := 5
const SHORE_SEGMENTS := 32


func build_island(
		island_name: String,
		center: Vector3,
		radii: Vector2,
		seed: float,
		grass_color: Color = Color("536d50"),
		shore_color: Color = Color("77735b"),
		surface_uv_xz: bool = false
	) -> StaticBody3D:
	var island := StaticBody3D.new()
	island.name = island_name
	island.position = center
	island.collision_layer = 1
	island.collision_mask = 1
	_add_surface(island, "Shoreline", _build_ring_mesh(radii, GRASS_RADIUS, 1.0, SHORE_RINGS, seed, 0.04, -0.45, surface_uv_xz), shore_color, true)
	_add_surface(island, "Grassland", _build_disc_mesh(radii, GRASS_RADIUS, GRASS_RINGS, seed, 0.04, surface_uv_xz), grass_color, true)
	return island


func _add_surface(parent: StaticBody3D, surface_name: String, mesh: ArrayMesh, color: Color, collidable: bool) -> void:
	var visual := MeshInstance3D.new()
	visual.name = surface_name
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.vertex_color_use_as_albedo = false
	visual.material_override = material
	parent.add_child(visual)
	if not collidable:
		return
	var collision := CollisionShape3D.new()
	collision.name = "%sCollision" % surface_name
	var trimesh := mesh.create_trimesh_shape() as ConcavePolygonShape3D
	trimesh.backface_collision = true
	collision.shape = trimesh
	parent.add_child(collision)


func _build_disc_mesh(radii: Vector2, outer_scale: float, ring_count: int, seed: float, base_height: float, surface_uv_xz: bool) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0.0, base_height, 0.0)
	for segment in range(SHORE_SEGMENTS):
		var angle_a := TAU * float(segment) / float(SHORE_SEGMENTS)
		var angle_b := TAU * float(segment + 1) / float(SHORE_SEGMENTS)
		var first_ring_scale := outer_scale / float(ring_count)
		var edge_a := _point_on_island(radii, first_ring_scale, angle_a, seed, base_height)
		var edge_b := _point_on_island(radii, first_ring_scale, angle_b, seed, base_height)
		_add_triangle(surface, center, edge_b, edge_a, surface_uv_xz)
	# Add nested triangles between the center fan and outer grass edge. They keep
	# the plateau nearly level while avoiding a mechanically perfect rectangle.
	for ring in range(1, ring_count):
		var inner_scale := outer_scale * float(ring) / float(ring_count)
		var outer_ring_scale := outer_scale * float(ring + 1) / float(ring_count)
		for segment in range(SHORE_SEGMENTS):
			var angle_a := TAU * float(segment) / float(SHORE_SEGMENTS)
			var angle_b := TAU * float(segment + 1) / float(SHORE_SEGMENTS)
			var inner_a := _point_on_island(radii, inner_scale, angle_a, seed, base_height)
			var inner_b := _point_on_island(radii, inner_scale, angle_b, seed, base_height)
			var outer_a := _point_on_island(radii, outer_ring_scale, angle_a, seed, base_height)
			var outer_b := _point_on_island(radii, outer_ring_scale, angle_b, seed, base_height)
			_add_quad(surface, inner_a, inner_b, outer_a, outer_b, surface_uv_xz)
	surface.generate_normals()
	return surface.commit()


func _build_ring_mesh(radii: Vector2, inner_scale: float, outer_scale: float, ring_count: int, seed: float, inner_height: float, outer_height: float, surface_uv_xz: bool) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(ring_count):
		var blend_a := float(ring) / float(ring_count)
		var blend_b := float(ring + 1) / float(ring_count)
		var scale_a := lerpf(inner_scale, outer_scale, blend_a)
		var scale_b := lerpf(inner_scale, outer_scale, blend_b)
		var height_a := lerpf(inner_height, outer_height, blend_a)
		var height_b := lerpf(inner_height, outer_height, blend_b)
		for segment in range(SHORE_SEGMENTS):
			var angle_a := TAU * float(segment) / float(SHORE_SEGMENTS)
			var angle_b := TAU * float(segment + 1) / float(SHORE_SEGMENTS)
			var inner_a := _point_on_island(radii, scale_a, angle_a, seed, height_a)
			var inner_b := _point_on_island(radii, scale_a, angle_b, seed, height_a)
			var outer_a := _point_on_island(radii, scale_b, angle_a, seed, height_b)
			var outer_b := _point_on_island(radii, scale_b, angle_b, seed, height_b)
			_add_quad(surface, inner_a, inner_b, outer_a, outer_b, surface_uv_xz)
	surface.generate_normals()
	return surface.commit()


func _point_on_island(radii: Vector2, scale: float, angle: float, seed: float, height: float) -> Vector3:
	var contour := 1.0 + 0.055 * sin(angle * 3.0 + seed) + 0.035 * sin(angle * 5.0 - seed * 0.7) + 0.018 * cos(angle * 9.0 + seed * 1.3)
	var x := cos(angle) * radii.x * scale * contour
	var z := sin(angle) * radii.y * scale * contour
	return Vector3(x, height, z)


func _add_quad(surface: SurfaceTool, inner_a: Vector3, inner_b: Vector3, outer_a: Vector3, outer_b: Vector3, surface_uv_xz: bool) -> void:
	_add_triangle(surface, inner_a, outer_b, outer_a, surface_uv_xz)
	_add_triangle(surface, inner_a, inner_b, outer_b, surface_uv_xz)


func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, surface_uv_xz: bool) -> void:
	# Opt-in only: emit local-meter XZ UVs before the original vertices. Keeping
	# the original construction and normal generation avoids mesh re-encoding.
	if surface_uv_xz:
		surface.set_uv(Vector2(a.x, a.z))
	surface.add_vertex(a)
	if surface_uv_xz:
		surface.set_uv(Vector2(c.x, c.z))
	surface.add_vertex(c)
	if surface_uv_xz:
		surface.set_uv(Vector2(b.x, b.z))
	surface.add_vertex(b)
