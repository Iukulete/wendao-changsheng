extends RefCounted
## ISOLATED EXPERIMENT. Stable world lattice + exact physical endpoint connectors.
## Not production acceptance, whole-body avoidance, or general path completeness.
const CELL := 0.75
const MARGIN := 4.5
const SPAN := 32.0
const WATER_FALLBACK_Y := 0.15
const BLOCKER_HEIGHT := 0.5
const ROOT_OFFSET := 0.12
var world: Node3D
var rocks: Array = []
var radius := 0.0
var queries := 0
var checked_edges := 0
var last_stats: Dictionary = {}

class Graph extends AStar3D:
	var validator: RefCounted
	var cache: Dictionary = {}
	func _filter_neighbor(from_id: int, neighbor_id: int) -> bool:
		var key := Vector2i(mini(from_id,neighbor_id),maxi(from_id,neighbor_id))
		if not cache.has(key):
			cache[key] = validator.edge_clear(get_point_position(from_id),get_point_position(neighbor_id))
		return not bool(cache[key])

func configure(scene: Node3D) -> bool:
	world = scene
	rocks.clear()
	radius = 0.0
	queries = 0
	checked_edges = 0
	var figure := world.find_child("TidekeeperFigure",true,false) as Node3D
	if figure == null: return false
	# Neutral-radius contract is valid only at world unit scale and upright yaw.
	var basis := figure.global_transform.basis
	if basis.y.distance_to(Vector3.UP)>0.00001 or absf(basis.x.length()-1.0)>0.00001 or absf(basis.z.length()-1.0)>0.00001 or absf(basis.x.dot(basis.z))>0.00001 or absf(basis.determinant()-1.0)>0.00001:
		last_stats={"rejected":"non_unit_or_tilted_actor_transform"}
		return false
	for name_ in ["LegLeft","LegRight"]:
		var leg := figure.find_child(name_,true,false) as MeshInstance3D
		if leg == null or leg.mesh == null: return false
		for vertex in leg.mesh.get_faces():
			var local: Vector3 = figure.to_local(leg.to_global(vertex))
			radius = maxf(radius,Vector2(local.x,local.z).length())
	radius += 0.00001
	if radius <= 0.0: return false
	var names := ["ShoreRockA","ShoreRockB"]
	for i in range(9): names.append("CoastClusterRock%02d" % i)
	for name_ in names:
		var body := world.get_node_or_null(NodePath(name_)) as StaticBody3D
		if body == null: return false
		var points := PackedVector2Array()
		for child in body.get_children():
			if child is CollisionShape3D and child.shape is ConvexPolygonShape3D:
				for point in child.shape.points:
					var p: Vector3 = child.global_transform * point
					points.append(Vector2(p.x,p.z))
		if points.size() < 3: return false
		var hull := Geometry2D.convex_hull(points)
		var bounds := Rect2(hull[0],Vector2.ZERO)
		for p in hull: bounds = bounds.expand(p)
		rocks.append({"polygon":hull,"bounds":bounds.grow(radius)})
	# Authored lateral barriers only; support remains in every native root query.
	for name_ in ["RaftBow","RaftPort","RaftStarboard","RaftSternPort","RaftSternStarboard"]:
		var body := world.get_node_or_null(NodePath("ArkRoot/"+name_)) as StaticBody3D
		if body == null: return false
		var points := PackedVector2Array()
		for child in body.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D:
				var half: Vector3 = child.shape.size*0.5
				for x in [-1,1]:
					for y in [-1,1]:
						for z in [-1,1]:
							var p: Vector3 = child.global_transform*Vector3(x*half.x,y*half.y,z*half.z)
							points.append(Vector2(p.x,p.z))
		if points.size()<3: return false
		var hull := Geometry2D.convex_hull(points)
		var bounds := Rect2(hull[0],Vector2.ZERO)
		for p in hull: bounds=bounds.expand(p)
		rocks.append({"polygon":hull,"bounds":bounds.grow(radius)})
	return true

func _ray(a: Vector3,b: Vector3) -> Dictionary:
	queries += 1
	var query := PhysicsRayQueryParameters3D.create(a,b,1)
	query.hit_from_inside = true
	return world.get_world_3d().direct_space_state.intersect_ray(query)

func _point_edge_distance(p: Vector2,a: Vector2,b: Vector2) -> float:
	var edge := b-a
	if edge.length_squared() == 0.0: return p.distance_to(a)
	return p.distance_to(a+edge*clampf((p-a).dot(edge)/edge.length_squared(),0.0,1.0))

func edge_clear(a: Vector3,b: Vector3) -> bool:
	checked_edges += 1
	if not a.is_finite() or not b.is_finite(): return false
	var p := Vector2(a.x,a.z)
	var q := Vector2(b.x,b.z)
	var segment_box := Rect2(p,Vector2.ZERO).expand(q)
	for rock in rocks:
		# Include touching bounds. A zero-width segment must not evade broad phase.
		var box: Rect2 = rock.bounds
		if segment_box.end.x < box.position.x or segment_box.position.x > box.end.x or segment_box.end.y < box.position.y or segment_box.position.y > box.end.y: continue
		var hull: PackedVector2Array = rock.polygon
		if Geometry2D.is_point_in_polygon(p,hull) or Geometry2D.is_point_in_polygon(q,hull): return false
		for i in range(hull.size()-1):
			var x := hull[i]
			var y := hull[i+1]
			if Geometry2D.segment_intersects_segment(p,q,x,y) != null: return false
			if minf(minf(_point_edge_distance(p,x,y),_point_edge_distance(q,x,y)),minf(_point_edge_distance(x,p,q),_point_edge_distance(y,p,q))) <= radius: return false
	# No body/RID exclusions. Same-position initial-overlap and both ray directions.
	if not _ray(a,a).is_empty() or not _ray(b,b).is_empty(): return false
	return _ray(a,b).is_empty() and _ray(b,a).is_empty()

func build(scene: Node3D,start: Vector3,destination: Vector3) -> PackedVector3Array:
	var began := Time.get_ticks_usec()
	var empty := PackedVector3Array()
	if not start.is_finite() or not destination.is_finite(): return empty
	for p in [start,destination]:
		if absf(p.x)>float(scene.get_script().get_script_constant_map()["PLAYER_WORLD_EDGE_LIMIT"]) or absf(p.z)>float(scene.get_script().get_script_constant_map()["PLAYER_WORLD_EDGE_LIMIT"]): return empty
	if absf(start.x-destination.x)>SPAN or absf(start.z-destination.z)>SPAN: return empty
	if not configure(scene): return empty
	var low := Vector2i(floori((minf(start.x,destination.x)-MARGIN)/CELL),floori((minf(start.z,destination.z)-MARGIN)/CELL))
	var high := Vector2i(ceili((maxf(start.x,destination.x)+MARGIN)/CELL),ceili((maxf(start.z,destination.z)+MARGIN)/CELL))
	var graph := Graph.new()
	graph.validator = self
	graph.neighbor_filter_enabled = true
	var ids: Dictionary = {}
	var next_id := 2
	for z in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var hit := _ray(Vector3(x*CELL,4,z*CELL),Vector3(x*CELL,-3,z*CELL))
			if not hit.is_empty() and float(hit.position.y)>BLOCKER_HEIGHT: continue
			var y := WATER_FALLBACK_Y
			if not hit.is_empty() and float(hit.position.y)>float(scene.get_script().get_script_constant_map()["WATER_SURFACE_Y"]): y=float(hit.position.y)+ROOT_OFFSET
			graph.add_point(next_id,Vector3(x*CELL,y,z*CELL))
			ids[Vector2i(x,z)] = next_id
			next_id += 1
	for cell in ids:
		for offset in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(-1,1)]:
			var neighbor: Vector2i = cell+offset
			if not ids.has(neighbor): continue
			if offset.x!=0 and offset.y!=0 and (not ids.has(cell+Vector2i(offset.x,0)) or not ids.has(cell+Vector2i(0,offset.y))): continue
			graph.connect_points(ids[cell],ids[neighbor],true)
	graph.add_point(0,start)
	graph.add_point(1,destination)
	for endpoint in [0,1]:
		var p := start if endpoint==0 else destination
		for cell in ids:
			var node: Vector3 = graph.get_point_position(ids[cell])
			if absf(node.x-p.x)<=MARGIN and absf(node.z-p.z)<=MARGIN:
				graph.connect_points(endpoint,ids[cell],true)
	if absf(start.x-destination.x)<=MARGIN and absf(start.z-destination.z)<=MARGIN:
		graph.connect_points(0,1,true)
	var route := graph.get_point_path(0,1)
	last_stats = {"nodes":graph.get_point_count(),"cached_edges":graph.cache.size(),"physical_rays":queries,"clearance_radius":radius,"authored_obstacle_count":rocks.size(),"build_usec":Time.get_ticks_usec()-began,"world_cells_low":var_to_str(low),"world_cells_high":var_to_str(high),"water_fallback_y":WATER_FALLBACK_Y,"route_points":route.size()}
	graph.validator = null
	return route
