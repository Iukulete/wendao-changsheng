extends RefCounted
## Authored regional relief. Static terrain is not serialized as gameplay state.
## Original landmass builder remains the frozen low-detail reference for old saves.
const CENTER := Vector3(-28,0,23)
const STATION := Vector3(-32,3.03,25)
const SEGMENTS := 96
const RINGS := 30
const TRAIL := [Vector3(-28,.04,15), Vector3(-30,.35,17), Vector3(-32.4,.95,18), Vector3(-34,1.7,20.4), Vector3(-34,2.8,23.1), Vector3(-32,2.8,25)]
const Legacy = preload("res://scripts/ark_landmass_builder.gd")
var legacy_faces := PackedVector3Array()
var initialized := false
var position_correction := {}

static func height(local: Vector2, radius: float) -> float:
	var hill := 4.2*exp(-((local-Vector2(-4,1.8))/Vector2(4.4,4.0)).length_squared())
	hill += 1.65*exp(-((local-Vector2(4,-1.7))/Vector2(3.2,4.0)).length_squared())
	var edge := 1.0-smoothstep(.58,.76,radius)
	var y := .04+hill*edge
	for i in range(TRAIL.size()-1):
		var a: Vector3 = TRAIL[i]-CENTER
		var b: Vector3 = TRAIL[i+1]-CENTER
		var line := Vector2(b.x-a.x,b.z-a.z)
		var t := clampf((local-Vector2(a.x,a.z)).dot(line)/line.length_squared(),0,1)
		var d := local.distance_to(Vector2(a.x,a.z)+line*t)
		y = lerpf(y,lerpf(a.y,b.y,t),(1.0-smoothstep(.72,1.45,d))*edge)
	var plateau := 1.0-smoothstep(2.35,2.95,local.distance_to(Vector2(-4,2)))
	return lerpf(y,2.8,plateau*edge)

func initialize(world: Node3D, materials: Dictionary) -> Dictionary:
	var island := world.get_node_or_null("MoonbackIsland") as StaticBody3D
	if island == null or island.position != CENTER or not materials.has("terrain"):
		return {"ok":false,"errors":["Moonback terrain dependencies unavailable."]}
	var grass := island.get_node("Grassland") as MeshInstance3D
	var shape := island.get_node("GrasslandCollision") as CollisionShape3D
	legacy_faces = shape.shape.get_faces()
	var builder := Legacy.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for ring in range(RINGS):
		for segment in range(SEGMENTS):
			var a := _point(builder,ring,segment)
			var b := _point(builder,ring,segment+1)
			var c := _point(builder,ring+1,segment)
			var d := _point(builder,ring+1,segment+1)
			_triangle(st,a,d,c)
			if ring > 0: _triangle(st,a,b,d)
	st.generate_normals()
	st.generate_tangents()
	var mesh := st.commit()
	grass.mesh = mesh
	var collision := mesh.create_trimesh_shape() as ConcavePolygonShape3D
	collision.backface_collision = true
	shape.shape = collision
	# A duplicate material, never mutate the approved opening-island instance.
	var material: ShaderMaterial = materials.terrain.duplicate()
	material.shader = preload("res://shaders/ark_moonback_terrain.gdshader")
	grass.material_override = material
	island.get_node("Shoreline").material_override = material
	initialized = true
	return {"ok":true,"errors":[],"triangles":mesh.get_faces().size()/3}

func _point(builder: RefCounted, ring: int, segment: int) -> Vector3:
	var r := .76*float(ring)/RINGS
	# Subdivide the ORIGINAL 32-edge polygon, rather than independently sampling
	# its curved formula at 96 angles: both resolutions must share exact seams.
	var subdivision := float(segment%SEGMENTS)*32.0/SEGMENTS
	var index := floori(subdivision)
	var first: Vector3 = builder._point_on_island(Vector2(14,12),r,TAU*index/32.0,5.4,.04)
	var second: Vector3 = builder._point_on_island(Vector2(14,12),r,TAU*(index+1)/32.0,5.4,.04)
	var point := first.lerp(second,subdivision-float(index))
	point.y = height(Vector2(point.x,point.z),r)
	return point

func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for p in [a,c,b]:
		st.set_uv(Vector2(p.x,p.z))
		st.add_vertex(p)

func reconcile_loaded_player(world: Node3D, sampler: RefCounted) -> Dictionary:
	position_correction = {"applied":false,"reason":"not resting on legacy Moonback grass"}
	if not initialized or world.sailing_mode or world.is_swimming or world.vessel_navigation.has_active_task("player"):
		return position_correction
	var body: CharacterBody3D = world.player
	if absf(body.velocity.y) > .2: return position_correction
	var collider := body.get_child(0) as CollisionShape3D
	if collider == null or not collider.shape is CapsuleShape3D or not collider.global_basis.y.is_equal_approx(Vector3.UP): return position_correction
	var old: Variant = _legacy_height(body.global_position)
	var foot: float = collider.global_position.y-collider.shape.height*.5
	if old == null or absf(foot-float(old)) > .10: return position_correction
	var support: Variant = sampler.sample_height(body.global_position)
	if support == null or float(support) <= foot+.05: return position_correction
	var highest := float(support)
	for i in 8:
		var p: Vector3 = body.global_position+Vector3(cos(TAU*i/8.),0,sin(TAU*i/8.))*collider.shape.radius
		var h: Variant = sampler.sample_height(p)
		if h != null: highest = maxf(highest,float(h))
	var before := body.global_position
	body.global_position.y += highest-foot+.02
	position_correction = {"applied":true,"before":before,"after":body.global_position,"reason":"upward-only legacy Moonback support correction"}
	return position_correction

func _legacy_height(world: Vector3) -> Variant:
	var p := Vector2(world.x-CENTER.x,world.z-CENTER.z)
	for i in range(0,legacy_faces.size(),3):
		var a := legacy_faces[i]
		var ab := Vector2(legacy_faces[i+1].x-a.x,legacy_faces[i+1].z-a.z)
		var ac := Vector2(legacy_faces[i+2].x-a.x,legacy_faces[i+2].z-a.z)
		var ap := p-Vector2(a.x,a.z)
		var determinant := ab.cross(ac)
		if absf(determinant) < .0000001: continue
		var u := ap.cross(ac)/determinant
		var v := ab.cross(ap)/determinant
		if u >= -.00001 and v >= -.00001 and u+v <= 1.00001: return .04
	return null
