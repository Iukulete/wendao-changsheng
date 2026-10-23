extends RefCounted
## RECONSTRUCTED QA helper, not recovered run06 source or validated production code.
## Call once on a fully instantiated, frozen canonical ark_greybox scene.
## Does not load/save, move the camera, change weather/time/water, or touch files.
## Compatibility candidate: collected resources + upward-only old-floor reconciliation.

const SEGMENTS := 96
const RINGS := 30
const EXPECTED_ISLAND_ORIGIN := Vector3(11, 0, -14)
const VISUAL_PIVOT := "QA_VisualGroundOffset"
const GROUND_TARGETS := [
	"residentMarker", "sailmakerMarker", "TidekeeperFloatboxInteractable",
	"DriftwoodShore", "DriftwoodRidge", "TidalShellsNear", "TidalShellsCove",
]
const RESOURCE_TARGETS := ["DriftwoodShore", "DriftwoodRidge", "TidalShellsNear", "TidalShellsCove"]
# Reconstructed hand-authored silhouettes. Restored a370 has boxes, not these rocks.
const ROCK_A_POINTS := [
	Vector3(-.34,-.78,-.55), Vector3(.35,-.78,-.72), Vector3(.68,-.78,-.30),
	Vector3(.40,-.78,.05), Vector3(-.10,-.78,.02), Vector3(-.46,-.78,-.20),
	Vector3(-.86,-.20,-.39), Vector3(-.59,-.08,-.94), Vector3(.25,-.18,-.96),
	Vector3(.88,-.12,-.56), Vector3(.91,-.20,.35), Vector3(.32,-.22,.90),
	Vector3(-.57,-.28,.70), Vector3(-.89,-.23,.15), Vector3(-.53,.38,-.39),
	Vector3(.22,.52,-.57), Vector3(.65,.26,.02), Vector3(.08,.23,.51), Vector3(-.56,.12,.30),
]
const ROCK_A_FACES := [
	6,0,7,14,15,17,14,13,6,14,7,15,14,6,7,16,17,15,16,9,10,16,15,9,
	5,6,13,5,0,6,11,16,10,11,17,16,1,7,0,18,13,14,18,14,17,12,11,4,
	12,4,5,12,5,13,12,13,18,12,17,11,12,18,17,2,10,9,2,9,1,8,7,1,
	8,1,9,8,15,7,8,9,15,3,11,10,3,10,2,3,4,11,3,5,4,3,0,5,3,1,0,3,2,1,
]
const ROCK_B_POINTS := [
	Vector3(-1.08,-.78,-.57), Vector3(-.50,-.78,-.99), Vector3(.61,-.78,-.89),
	Vector3(1.18,-.78,-.34), Vector3(1.16,-.78,.44), Vector3(.39,-.78,1.01),
	Vector3(-.62,-.78,.89), Vector3(-1.27,-.78,.24), Vector3(-1.37,-.13,-.27),
	Vector3(-.86,.05,-1.05), Vector3(.32,.13,-1.11), Vector3(1.35,-.04,-.65),
	Vector3(1.41,-.13,.31), Vector3(.68,-.04,1.04), Vector3(-.44,-.08,1.12),
	Vector3(-1.32,-.14,.69), Vector3(-.86,.38,-.20), Vector3(-.30,.57,-.53),
	Vector3(.67,.47,-.44), Vector3(.90,.33,.32), Vector3(.01,.34,.70), Vector3(-.79,.26,.44),
]
const ROCK_B_FACES := [
	11,12,19,0,9,8,16,17,21,16,8,9,16,9,17,13,19,12,13,5,14,20,14,21,
	20,13,14,20,19,13,20,21,17,20,17,19,18,19,17,18,11,19,15,21,14,
	15,8,16,15,16,21,1,9,0,4,13,12,4,5,13,10,11,18,10,2,11,10,17,9,
	10,18,17,10,1,2,10,9,1,7,0,8,7,8,15,3,12,11,3,4,12,3,11,2,
	6,7,15,6,14,5,6,15,14,6,0,7,6,2,1,6,1,0,6,5,4,6,3,2,6,4,3,
]

var scene: Node3D
var island: StaticBody3D
var top_mesh: ArrayMesh
var top_faces_local := PackedVector3Array()
var ground_grid: Dictionary = {}
var rock_bodies: Array[StaticBody3D] = []
var offsets: Array = []
var anchor_snapshot: Array = []
var errors: Array[String] = []
var _rock_material: Material
var skipped_collected_visuals: Array[String] = []
var position_correction: Dictionary = {"applied": false, "reason": "not evaluated"}
var topology_audit: Dictionary = {}

func apply(world: Node3D, materials: Dictionary = {}) -> Dictionary:
	# No rollback: a post-mutation failure requires discarding this isolated scene.
	# Caller applies once after canonical load; no per-frame correction or automatic respawn policy.
	if world == null:
		return {"ok": false, "error": "Scene is null.", "mutated": false}
	if scene != null or world.has_meta("qa_authored_coast_rederived"):
		return {"ok": false, "error": "Apply only once to a new isolated scene."}
	var contract_errors := validate_contract(world)
	if not contract_errors.is_empty():
		return {"ok": false, "errors": contract_errors, "mutated": false}
	scene = world
	island = scene.get_node("IslandLandmass") as StaticBody3D
	var previous_support := _capture_previous_player_support()
	for entry in scene.get("interactables"):
		anchor_snapshot.append({"node": entry.node, "id": str(entry.id), "transform": entry.node.global_transform})
	world.set_meta("qa_authored_coast_rederived", true)
	_replace_terrain(materials.get("terrain", null))
	_replace_rocks(materials.get("rock", null))
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "mutated": true, "discard_scene": true}
	_add_groups(materials.get("grass", null))
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "mutated": true, "discard_scene": true}
	for name_ in GROUND_TARGETS:
		var target := scene.get_node_or_null(name_) as Node3D
		if target == null or target.is_queued_for_deletion():
			# validate_contract already requires the exact canonical collected flag.
			skipped_collected_visuals.append(name_)
			continue
		ground_visuals(target)
		if not errors.is_empty():
			return {"ok": false, "errors": errors, "mutated": true, "discard_scene": true}
	var ruin := scene.get_node("ShoreRuin") as Node3D
	ground_visuals(ruin, ruin.get_node("RuinPillarLeft"))
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "mutated": true, "discard_scene": true}
	ground_visuals(ruin.get_node(VISUAL_PIVOT + "/RuinBrokenStone"))
	ground_visuals(ruin.get_node(VISUAL_PIVOT + "/RuinPillarRight"))
	if not interaction_roots_unchanged():
		errors.append("Interaction root changed unexpectedly; discard scene.")
	if errors.is_empty():
		_reconcile_raised_player_support(previous_support)
	return {
		"ok": errors.is_empty(), "mutated": true, "errors": errors,
		"status": "rederived helper applied; native validation still required",
		"terrain_top": top_mesh, "island": island, "offsets": offsets,
		"triangles": top_faces_local.size() / 3, "rock_bodies": rock_bodies,
		"materials_injected": materials.keys(),
		"skipped_collected_visuals": skipped_collected_visuals,
		"position_correction": position_correction,
		"topology_audit": topology_audit,
	}

func validate_contract(world: Node3D) -> Array[String]:
	var out: Array[String] = []
	if not world.is_inside_tree():
		out.append("Scene must be inside the tree and fully initialized.")
	for path in ["IslandLandmass", "IslandLandmass/Shoreline", "IslandLandmass/Grassland",
		"IslandLandmass/ShorelineCollision", "IslandLandmass/GrasslandCollision",
		"ShoreRockA", "ShoreRockB", "ArkRoot", "ShoreRuin/RuinPillarLeft",
		"ShoreRuin/RuinPillarRight", "ShoreRuin/RuinBrokenStone"]:
		if world.get_node_or_null(path) == null:
			out.append("Missing node: " + path)
	for path in GROUND_TARGETS:
		var target := world.get_node_or_null(path)
		if (target == null or target.is_queued_for_deletion()) and not _confirmed_collected_resource(world, path):
			out.append("Missing required/uncollected visual target: " + path)
	if not out.is_empty():
		return out
	var land := world.get_node("IslandLandmass") as StaticBody3D
	if land == null or land.global_position != EXPECTED_ISLAND_ORIGIN or land.global_basis != Basis.IDENTITY:
		out.append("Expected untransformed opening island at (11,0,-14).")
	for name_ in ["ShoreRockA", "ShoreRockB"]:
		var rock := world.get_node(name_) as StaticBody3D
		if rock == null or rock.get_child_count() != 2 or not rock.get_child(0) is MeshInstance3D or not rock.get_child(1) is CollisionShape3D:
			out.append("Unexpected restored-a370 rock contract: " + name_)
	return out

func _confirmed_collected_resource(world: Node3D, target_name: String) -> bool:
	# Canonical _load_progress owns collection semantics. Do not recreate/remove
	# resources or infer collection merely from a failed node lookup.
	var ids: Variant = world.get("collected_ids")
	return target_name in RESOURCE_TARGETS and ids is Array and ids.has(target_name)

func _height_on_faces(point: Vector3, faces: PackedVector3Array, transform: Transform3D) -> Variant:
	var height: Variant = null
	for i in range(0, faces.size(), 3):
		var a := transform * faces[i]
		var b := transform * faces[i+1]
		var c := transform * faces[i+2]
		var ab := Vector2(b.x-a.x, b.z-a.z)
		var ac := Vector2(c.x-a.x, c.z-a.z)
		var ap := Vector2(point.x-a.x, point.z-a.z)
		var determinant := ab.cross(ac)
		if absf(determinant) < .0000001:
			continue
		var u := ap.cross(ac) / determinant
		var v := ab.cross(ap) / determinant
		if u >= -.00001 and v >= -.00001 and u+v <= 1.00001:
			var candidate := a.y + u*(b.y-a.y) + v*(c.y-a.y)
			if height == null or candidate > float(height):
				height = candidate
	return height

func _capture_previous_player_support() -> Dictionary:
	# Geometry evidence is available immediately after _ready, before physics has
	# populated is_on_floor(). Check the original *collider* triangles, not flags.
	var body := scene.get("player") as CharacterBody3D
	var result := {"eligible": false, "reason": "no player"}
	if body == null:
		return result
	result.before = body.global_position
	result.velocity_before = body.velocity
	if bool(scene.get("sailing_mode")) or bool(scene.get("is_swimming")):
		result.reason = "sailing or swimming; preserve existing policy"
		return result
	if scene.get("vessel_navigation").has_active_task("player"):
		result.reason = "active vessel navigation; preserve support"
		return result
	if absf(body.velocity.y) > .20:
		result.reason = "airborne velocity; preserve trajectory"
		return result
	var collision := body.get_child(0) as CollisionShape3D
	if collision == null or not collision.shape is CapsuleShape3D or not collision.global_basis.y.is_equal_approx(Vector3.UP):
		result.reason = "unsupported player capsule contract"
		return result
	var capsule := collision.shape as CapsuleShape3D
	var foot := collision.global_position.y - capsule.height*.5
	var old_height: Variant = null
	for path in ["ShorelineCollision", "GrasslandCollision"]:
		var surface := island.get_node(path) as CollisionShape3D
		if surface.disabled or not surface.shape is ConcavePolygonShape3D:
			continue
		var h: Variant = _height_on_faces(body.global_position, (surface.shape as ConcavePolygonShape3D).get_faces(), surface.global_transform)
		if h != null and (old_height == null or float(h) > float(old_height)):
			old_height = h
	result.old_surface_height = old_height
	result.capsule_foot_before = foot
	if old_height == null or absf(foot - float(old_height)) > .10:
		result.reason = "not resting on replaced island support"
		return result
	result.eligible = true
	result.reason = "resting on original island collider"
	result.foot_offset = foot - body.global_position.y
	result.capsule_radius = capsule.radius
	return result

func _reconcile_raised_player_support(previous: Dictionary) -> void:
	position_correction = previous.duplicate(true)
	position_correction.applied = false
	if not previous.eligible:
		return
	var body := scene.get("player") as CharacterBody3D
	var center_height: Variant = sample_height(body.global_position)
	if center_height == null or float(center_height) <= float(previous.old_surface_height)+.05 or float(center_height) <= float(previous.capsule_foot_before)+.02:
		position_correction.reason = "no raised-support penetration"
		return
	# Conservative support over this existing capsule footprint, plus 2 cm to
	# allow normal move_and_slide to settle. No XZ/velocity, swimming or time edits.
	var support := float(center_height)
	for i in range(8):
		var angle := TAU*float(i)/8.0
		var p := body.global_position + Vector3(cos(angle),0,sin(angle))*float(previous.capsule_radius)
		var h: Variant = sample_height(p)
		if h != null:
			support = maxf(support, float(h))
	var corrected_y := support - float(previous.foot_offset) + .02
	if corrected_y <= body.global_position.y:
		return
	body.global_position.y = corrected_y
	position_correction.applied = true
	position_correction.reason = "upward-only reconciliation of raised island support"
	position_correction.new_surface_height = center_height
	position_correction.footprint_support_height = support
	position_correction.after = body.global_position
	position_correction.delta_y = body.global_position.y - (previous.before as Vector3).y
	position_correction.xz_unchanged = body.global_position.x == (previous.before as Vector3).x and body.global_position.z == (previous.before as Vector3).z

func _lobe(angle: float, center: float, width: float) -> float:
	var distance := wrapf(angle - center, -PI, PI) / width
	return exp(-0.5 * distance * distance)

func outline(angle: float) -> Vector2:
	var base := 1.0 + .055 * sin(angle * 3.0 + 1.2) + .035 * sin(angle * 5.0 - .84) + .018 * cos(angle * 9.0 + 1.56)
	var contour := base + .25 * _lobe(angle, .90, .20) + .10 * _lobe(angle, 1.78, .16) - .14 * _lobe(angle, 1.58, .11)
	contour += .23 * _lobe(angle, -.26, .18) + .025 * _lobe(angle, -.55, .5) - .06 * _lobe(angle, -2.3, .55)
	return Vector2(12.0 * cos(angle), 10.0 * sin(angle)) * contour

func height_profile(local: Vector2, radius_fraction: float) -> float:
	var q := (local - Vector2(5.2, -4.1)) / Vector2(4.1, 3.6)
	var shoulder := 1.25 * exp(-q.length_squared())
	var second := .24 * exp(-((local - Vector2(7.8, -2.0)) / Vector2(2.1, 3.0)).length_squared())
	var y := .055 + shoulder + second
	y += .045 * sin(local.x * .55 + local.y * .21) * sin(local.y * .39) * (1.0 - smoothstep(.62, .9, radius_fraction))
	y = lerpf(y, -1.60, smoothstep(.72, 1.0, radius_fraction))
	var world := local + Vector2(11, -14)
	for anchor in [Vector2(11,-7), Vector2(13,-6), Vector2(14.25,-6.45), Vector2(16,-10), Vector2(13.8,-11.8), Vector2(8.4,-6.1)]:
		var flat := 1.0 - smoothstep(.7, 1.65, world.distance_to(anchor))
		y = lerpf(y, .045, flat * (1.0 - smoothstep(.86, 1.0, radius_fraction)))
	for anchor in [Vector2(9,-4), Vector2(19,-5.5)]:
		var support := 1.0 - smoothstep(.65, 1.35, world.distance_to(anchor))
		y = lerpf(y, -.32, support * (1.0 - smoothstep(.80, 1.0, radius_fraction)))
	var closest := Geometry2D.get_closest_point_to_segment(world, Vector2(21.4,-17), Vector2(24.4,-17))
	var ruin_support := (1.0 - smoothstep(.43, 1.0, world.distance_to(closest))) * (1.0 - smoothstep(.90, 1.0, radius_fraction))
	y = lerpf(y, .20, ruin_support)
	# Only the two proven walking corridors: retain the radial outline/cove and
	# outer lip, but remove steep seams between isolated activity flatten masks.
	y = _walk_corridor_height(world, radius_fraction, y, Vector2(9,-4), Vector2(8.4,-6.1), -.44, .045, .60, 1.40, 0.0)
	var before_corridors := y
	y = _walk_corridor_height(world, radius_fraction, y, Vector2(8.4,-6.1), Vector2(13,-6), .045, .045, .75, 1.40, .15)
	# Keep the actual submerged inlet; local conforming refinement below prevents
	# a coarse high shared edge from spanning this cove and catching a capsule.
	var restore_cove := smoothstep(-5.9,-5.6,world.y)*(1.0-smoothstep(.9,1.5,absf(world.x-11.0)))
	return lerpf(y,before_corridors,restore_cove)

func _walk_corridor_height(world: Vector2, radius_fraction: float, original_y: float, start: Vector2, finish: Vector2, start_y: float, finish_y: float, core: float, edge: float, dish: float) -> float:
	var segment := finish-start
	var t := clampf((world-start).dot(segment)/segment.length_squared(), 0.0, 1.0)
	var distance := world.distance_to(start+segment*t)
	var weight := (1.0-smoothstep(core,edge,distance))*(1.0-smoothstep(.98,1.0,radius_fraction))
	var target := lerpf(start_y,finish_y,t)-dish*pow(sin(PI*t),2.0)
	return lerpf(original_y,target,weight)

func terrain_vertex(segment: int, ring: int) -> Vector3:
	var r := float(ring) / float(RINGS)
	var p := outline(TAU * float(segment) / float(SEGMENTS)) * r
	return Vector3(p.x, height_profile(p, r), p.y)

func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, intended: Vector3 = Vector3.UP) -> void:
	if (c - a).cross(b - a).dot(intended) < 0.0:
		var temporary := b
		b = c
		c = temporary
	for p in [a, b, c]:
		st.set_uv(Vector2(p.x, p.z))
		st.add_vertex(p)

func _smooth(mesh: ArrayMesh, tangents: bool) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var sums: Dictionary = {}
	for i in range(0, vertices.size(), 3):
		var weighted := (vertices[i+2] - vertices[i]).cross(vertices[i+1] - vertices[i])
		for j in range(3):
			sums[vertices[i+j]] = sums.get(vertices[i+j], Vector3.ZERO) + weighted
	var normals := PackedVector3Array()
	for p in vertices:
		normals.append((sums[p] as Vector3).normalized())
	arrays[Mesh.ARRAY_NORMAL] = normals
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if tangents:
		var st := SurfaceTool.new()
		st.create_from(result, 0)
		st.generate_tangents()
		result = st.commit()
	return result

func _from_parameter(p: Vector3) -> Vector3:
	# p.y stores the original/interpolated radial fraction, not height.
	return Vector3(p.x,height_profile(Vector2(p.x,p.z),p.y),p.z)

func _edge(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a,b),maxi(a,b))

func _refined_topology() -> Dictionary:
	var vertices: Array[Vector3] = [Vector3.ZERO]
	for ring in range(1,RINGS+1):
		for i in range(SEGMENTS):
			var r := float(ring)/RINGS
			var p := outline(TAU*float(i)/SEGMENTS)*r
			vertices.append(Vector3(p.x,r,p.y))
	var faces: Array = []
	for i in range(SEGMENTS):
		faces.append([0,1+i,1+(i+1)%SEGMENTS])
	for ring in range(1,RINGS):
		for i in range(SEGMENTS):
			var j := (i+1)%SEGMENTS
			var inner := 1+(ring-1)*SEGMENTS
			var outer := inner+SEGMENTS
			faces.append([inner+i,inner+j,outer+i])
			faces.append([inner+j,outer+j,outer+i])
	var original_vertex_count := vertices.size()
	for iteration in range(2):
		var mids: Dictionary = {}
		for face in faces:
			var a:Vector3=vertices[face[0]];var b:Vector3=vertices[face[1]];var c:Vector3=vertices[face[2]]
			var xmin:=minf(a.x,minf(b.x,c.x))+11.;var xmax:=maxf(a.x,maxf(b.x,c.x))+11.
			var zmin:=minf(a.z,minf(b.z,c.z))-14.;var zmax:=maxf(a.z,maxf(b.z,c.z))-14.
			if xmax<8.8 or xmin>13.4 or zmax< -6.6 or zmin> -5.3:
				continue
			for pair in [[face[0],face[1]],[face[1],face[2]],[face[2],face[0]]]:
				var key:=_edge(pair[0],pair[1])
				if not mids.has(key):
					mids[key]=vertices.size()
					vertices.append((vertices[pair[0]]+vertices[pair[1]])*.5)
		var refined: Array = []
		for face in faces:
			var a:int=face[0];var b:int=face[1];var c:int=face[2]
			var ab:int=mids.get(_edge(a,b),-1);var bc:int=mids.get(_edge(b,c),-1);var ca:int=mids.get(_edge(c,a),-1)
			var count:=int(ab>=0)+int(bc>=0)+int(ca>=0)
			if count==0:
				refined.append(face)
			elif count==3:
				refined.append_array([[a,ab,ca],[ab,b,bc],[ca,bc,c],[ab,bc,ca]])
			else:
				# Transition neighbors share exactly the same split edge IDs.
				var boundary:Array[int]=[]
				for pair in [[a,ab],[b,bc],[c,ca]]:
					boundary.append(pair[0])
					if pair[1]>=0:boundary.append(pair[1])
				var center:=vertices.size()
				vertices.append((vertices[a]+vertices[b]+vertices[c])/3.)
				for i in range(boundary.size()):
					refined.append([center,boundary[i],boundary[(i+1)%boundary.size()]])
		faces=refined
	var edges:Dictionary={};var degenerate:=0;var boundary_edges:=0;var invalid_edges:=0
	for face in faces:
		var a:Vector3=vertices[face[0]];var b:Vector3=vertices[face[1]];var c:Vector3=vertices[face[2]]
		if absf(Vector2(b.x-a.x,b.z-a.z).cross(Vector2(c.x-a.x,c.z-a.z)))<.00000001:degenerate+=1
		for pair in [[face[0],face[1]],[face[1],face[2]],[face[2],face[0]]]:
			var key:=_edge(pair[0],pair[1]);edges[key]=edges.get(key,0)+1
	for key in edges:
		if edges[key]==1:
			boundary_edges+=1
			if not is_equal_approx(vertices[key.x].y,1.) or not is_equal_approx(vertices[key.y].y,1.):invalid_edges+=1
		elif edges[key]!=2:invalid_edges+=1
	var lower:=Vector3(INF,INF,INF);var upper:=Vector3(-INF,-INF,-INF)
	for i in range(original_vertex_count,vertices.size()):
		var p:=_from_parameter(vertices[i])+EXPECTED_ISLAND_ORIGIN
		lower=lower.min(p);upper=upper.max(p)
	var ok:=invalid_edges==0 and degenerate==0 and faces.size()<=12000
	topology_audit={"passed":ok,"original_vertices":original_vertex_count,"vertices":vertices.size(),"original_triangles":5664,"triangles":faces.size(),"added_triangles":faces.size()-5664,"subdivision_rounds":2,"boundary_edges":boundary_edges,"invalid_or_interior_open_edges":invalid_edges,"degenerate_faces":degenerate,"new_vertex_world_min":lower,"new_vertex_world_max":upper,"outline_edges_preserved":true}
	return {"ok":ok,"vertices":vertices,"faces":faces}

func _replace_terrain(material: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var data := _refined_topology()
	if not data.ok:
		errors.append("Local topology gate failed: "+str(topology_audit))
		return
	for face in data.faces:
		_triangle(st, _from_parameter(data.vertices[face[0]]), _from_parameter(data.vertices[face[1]]), _from_parameter(data.vertices[face[2]]))
	top_mesh = _smooth(st.commit(), true)
	top_faces_local = top_mesh.get_faces()
	_build_height_index()
	var visual := island.get_node("Shoreline") as MeshInstance3D
	visual.mesh = top_mesh
	visual.material_override = material if material != null else _fallback_terrain()
	island.get_node("Grassland").visible = false
	island.get_node("GrasslandCollision").disabled = true
	var shape := top_mesh.create_trimesh_shape() as ConcavePolygonShape3D
	shape.backface_collision = true
	island.get_node("ShorelineCollision").shape = shape
	var cap := SurfaceTool.new()
	cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(SEGMENTS):
		_triangle(cap, Vector3(0,-1.60,0), terrain_vertex(i,RINGS), terrain_vertex((i+1)%SEGMENTS,RINGS), Vector3.DOWN)
	var closed := MeshInstance3D.new()
	closed.name = "QA_SubmergedVisualCap"
	closed.mesh = cap.commit()
	closed.material_override = visual.material_override
	island.add_child(closed)

func _build_height_index() -> void:
	for i in range(0, top_faces_local.size(), 3):
		var a := top_faces_local[i]
		var b := top_faces_local[i+1]
		var c := top_faces_local[i+2]
		for z in range(int(floor(minf(a.z,minf(b.z,c.z)))), int(floor(maxf(a.z,maxf(b.z,c.z))))+1):
			for x in range(int(floor(minf(a.x,minf(b.x,c.x)))), int(floor(maxf(a.x,maxf(b.x,c.x))))+1):
				var key := Vector2i(x,z)
				if not ground_grid.has(key):
					ground_grid[key] = []
				ground_grid[key].append(i)

func sample_height(world_position: Vector3) -> Variant:
	if island == null:
		return null
	var p := island.to_local(world_position)
	for i in ground_grid.get(Vector2i(int(floor(p.x)),int(floor(p.z))), []):
		var a: Vector3 = top_faces_local[i]
		var b: Vector3 = top_faces_local[i+1]
		var c: Vector3 = top_faces_local[i+2]
		var ab := Vector2(b.x-a.x,b.z-a.z)
		var ac := Vector2(c.x-a.x,c.z-a.z)
		var ap := Vector2(p.x-a.x,p.z-a.z)
		var determinant := ab.cross(ac)
		if absf(determinant) < .0000001:
			continue
		var u := ap.cross(ac) / determinant
		var v := ab.cross(ap) / determinant
		if u >= -.00001 and v >= -.00001 and u+v <= 1.00001:
			return a.y + u*(b.y-a.y) + v*(c.y-a.y) + island.global_position.y
	return null

func contact(target: Node3D) -> Dictionary:
	var low := INF
	var vertices := PackedVector3Array()
	for mesh in target.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree():
			continue
		for v in mesh.mesh.get_faces():
			var p: Vector3 = mesh.to_global(v)
			vertices.append(p)
			low = minf(low, p.y)
	var gap := INF
	var point := Vector3.ZERO
	var ground := 0.0
	var count := 0
	for p in vertices:
		if p.y > low + .035:
			continue
		var h: Variant = sample_height(p)
		if h == null:
			continue
		count += 1
		if p.y - float(h) < gap:
			gap = p.y - float(h)
			point = p
			ground = h
	return {"gap": gap, "point": point, "ground": ground, "sampled_vertices": count}

func ground_visuals(target: Node3D, reference: Node3D = null) -> void:
	var before := contact(target if reference == null else reference)
	if before.sampled_vertices == 0:
		errors.append("No terrain contact under " + str(scene.get_path_to(target)))
		return
	var pivot := Node3D.new()
	pivot.name = VISUAL_PIVOT
	target.add_child(pivot)
	for child in target.get_children():
		if child != pivot and child is Node3D and not child is Label3D and not child is CollisionObject3D:
			child.reparent(pivot, true)
	pivot.position.y = -float(before.gap) - .012
	offsets.append({"path": str(scene.get_path_to(target)), "visual_y_offset": pivot.position.y, "before": before, "after": contact(target)})

func interaction_roots_unchanged() -> bool:
	for row in anchor_snapshot:
		if not is_instance_valid(row.node) or row.node.global_transform != row.transform:
			return false
	return true

func _rock_mesh(points: Array, faces: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in faces:
		var p: Vector3 = points[index]
		st.set_uv(Vector2(p.x,p.z))
		st.add_vertex(p)
	return _smooth(st.commit(), false)

func _replace_rocks(material: Material) -> void:
	_rock_material = material
	if _rock_material == null:
		_rock_material = _plain_material(Color("777a71"))
	for row in [["ShoreRockA", ROCK_A_POINTS, ROCK_A_FACES], ["ShoreRockB", ROCK_B_POINTS, ROCK_B_FACES]]:
		var body := scene.get_node(row[0]) as StaticBody3D
		var mesh := _rock_mesh(row[1], row[2])
		(body.get_child(0) as MeshInstance3D).mesh = mesh
		(body.get_child(0) as MeshInstance3D).material_override = _rock_material
		var shape := ConvexPolygonShape3D.new()
		shape.points = mesh.get_faces()
		(body.get_child(1) as CollisionShape3D).shape = shape
		var before := contact(body)
		if before.sampled_vertices == 0:
			errors.append("No main-rock support: " + str(body.name))
			return
		var dy := -float(before.gap) - .10
		body.position.y += dy
		offsets.append({"path": str(body.name), "root_y_delta": dy, "xz_unchanged": true, "matched_collider_moves_with_root": true})
		rock_bodies.append(body)

func _satellite(mesh: ArrayMesh, name_: String, point: Vector3, scale_: Vector3, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.name = name_
	body.position = point
	body.scale = scale_
	body.rotation.y = yaw
	body.collision_layer = 1
	body.collision_mask = 1
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _rock_material
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = mesh.get_faces()
	collision.shape = shape
	body.add_child(collision)
	scene.add_child(body)
	var c := contact(body)
	if c.sampled_vertices == 0:
		errors.append("No satellite support: " + name_)
		return
	body.position.y -= float(c.gap) + .08
	rock_bodies.append(body)

func _add_groups(grass_material: Material) -> void:
	var template := _rock_mesh(ROCK_A_POINTS, ROCK_A_FACES)
	var placements := [
		[Vector3(3.8,0,-7.8),Vector3(.72,.56,.8),.7], [Vector3(6.1,0,-8.0),Vector3(.48,.38,.72),-1.1], [Vector3(4.1,0,-6.7),Vector3(.28,.22,.38),1.4],
		[Vector3(19.1,0,-14.0),Vector3(.88,.66,1.1),.4], [Vector3(19.75,0,-12.95),Vector3(.50,.33,.70),-1.2], [Vector3(18.2,0,-14.8),Vector3(.43,.32,.56),.8],
		[Vector3(17.9,0,-18.6),Vector3(1.25,.64,1.00),-.25], [Vector3(19.0,0,-18.9),Vector3(.75,.42,.88),.5], [Vector3(17.35,0,-18.0),Vector3(.54,.35,.73),-.8],
	]
	for i in range(placements.size()):
		_satellite(template, "QA_ClusterRock%02d" % i, placements[i][0], placements[i][1], placements[i][2])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centers := [Vector3(4.8,.51,-8.5),Vector3(18.7,.64,-14.9),Vector3(16.8,.76,-19.2),Vector3(18.7,.72,-19.9),Vector3(14.4,.58,-19.0)]
	for ci in range(centers.size()):
		var center: Vector3 = centers[ci]
		for tuft in range(11):
			var angle := float(tuft)*2.39996 + float(ci)*.7
			var spread := .22 + .15*sqrt(float(tuft))
			var p := Vector3(center.x+cos(angle)*spread,0,center.z+sin(angle)*spread*.7)
			var h: Variant = sample_height(p)
			if h == null:
				continue
			p.y = float(h)-.02
			for leaf in range(8):
				var a := angle+leaf*2.39996
				var across := Vector3(cos(a),0,sin(a))
				var width := Vector3(-across.z,0,across.x)*(.028+.009*(leaf%3))
				var height := center.y*(.70+.05*leaf)
				var base := p+across*.045
				var middle := base+Vector3.UP*height*.59+across*.14
				var tip := base+Vector3.UP*height+across*.32+Vector3(.02,0,-.08)
				for tri in [[base-width,base+width,middle+width*.65],[base-width,middle+width*.65,middle-width*.65],[middle-width*.65,middle+width*.65,tip]]:
					var normal: Vector3 = (tri[2]-tri[0]).cross(tri[1]-tri[0]).normalized()
					for v in tri:
						st.set_normal(normal)
						st.set_color(Color(.72+.025*leaf,.74+.025*leaf,.64+.022*leaf))
						st.set_uv(Vector2.ZERO)
						st.add_vertex(v)
	var visual := MeshInstance3D.new()
	visual.name = "QA_ShelteredGrassGroups"
	visual.mesh = st.commit()
	if grass_material == null:
		var default_grass := _plain_material(Color("65704b"))
		default_grass.vertex_color_use_as_albedo = true
		default_grass.cull_mode = BaseMaterial3D.CULL_DISABLED
		grass_material = default_grass
	visual.material_override = grass_material
	scene.add_child(visual)

func build_height_image(size: int = 384) -> Image:
	# Actual final triangles -> local 32m-square float raster at pixel centers.
	# Water shader convention: UV=((world.xz-island_center)+16)/32, -3 sentinel.
	if top_faces_local.is_empty() or size < 16 or size > 1024:
		return null
	var image := Image.create(size, size, false, Image.FORMAT_RF)
	image.fill(Color(-3,0,0))
	for i in range(0, top_faces_local.size(), 3):
		var a := top_faces_local[i]
		var b := top_faces_local[i+1]
		var c := top_faces_local[i+2]
		var aa := (Vector2(a.x,a.z)+Vector2.ONE*16.0)/32.0*size-Vector2.ONE*.5
		var bb := (Vector2(b.x,b.z)+Vector2.ONE*16.0)/32.0*size-Vector2.ONE*.5
		var cc := (Vector2(c.x,c.z)+Vector2.ONE*16.0)/32.0*size-Vector2.ONE*.5
		var ab := bb-aa
		var ac := cc-aa
		var determinant := ab.cross(ac)
		if absf(determinant) < .00001:
			continue
		for y in range(maxi(0,int(floor(minf(aa.y,minf(bb.y,cc.y))))),mini(size-1,int(ceil(maxf(aa.y,maxf(bb.y,cc.y)))))+1):
			for x in range(maxi(0,int(floor(minf(aa.x,minf(bb.x,cc.x))))),mini(size-1,int(ceil(maxf(aa.x,maxf(bb.x,cc.x)))))+1):
				var ap := Vector2(x,y)-aa
				var u := ap.cross(ac)/determinant
				var v := ab.cross(ap)/determinant
				if u >= 0 and v >= 0 and u+v <= 1:
					image.set_pixel(x,y,Color(a.y+u*(b.y-a.y)+v*(c.y-a.y),0,0))
	return image

func top_faces_world() -> PackedVector3Array:
	var result := PackedVector3Array()
	for point in top_faces_local:
		result.append(island.to_global(point))
	return result

func ground_focus_ring() -> void:
	# Call after scene._update_interaction_hint(), which may reset its position.
	var ring: MeshInstance3D = scene.get("interaction_focus_ring")
	if ring != null and ring.visible:
		var h: Variant = sample_height(ring.global_position)
		if h != null:
			ring.global_position.y = float(h)+.022

func _plain_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic_specular = .28
	return material

func _fallback_terrain() -> ShaderMaterial:
	# Deliberate asset-free diagnostic fallback, NOT the lost scan-textured look.
	var shader := Shader.new()
	shader.code = """shader_type spatial;
	varying vec3 p;
	void vertex() { p=VERTEX; }
	void fragment() {
		float turf=smoothstep(-.04,.23,p.y+.10*sin(p.x*.48+p.z*.25)+.06*cos(p.z*.61));
		float wet=1.-smoothstep(-1.05,-.40,p.y);
		ALBEDO=mix(vec3(.22,.19,.14),vec3(.12,.15,.08),turf)*mix(1.,.73,wet);
		ROUGHNESS=.94; SPECULAR=.28;
	}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material
