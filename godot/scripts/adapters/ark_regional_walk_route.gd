extends RefCounted
## Bounded regional foot routes. Empty sea is never a floor. Uses installed
## terrain triangles and actual box supports, plus physics for body clearance.
const CELL := .4
const FOOT_RADIUS := .18
const OFFSET := .12
var world: Node3D
var supports: Array[CollisionShape3D] = []
var heights := {}
var samples := 0
var rejected_edges := []
var done := true
var result := PackedVector3Array()
var _phase := ""
var _graph: AStar3D
var _cells := {}
var _keys := []
var _minimum := Vector2.ZERO
var _size := Vector2i.ZERO
var _start := Vector3.ZERO
var _destination := Vector3.ZERO
var _floor_start := Vector3.ZERO
var _end := Vector3.ZERO
var _cursor := 0
var _start_id := 0
var _end_id := 0
var _attempt := 0
var _path := PackedInt64Array()
var _route := PackedVector3Array()

static func handles(point: Vector3) -> bool:
	return Vector2(point.x+28,point.z-23).length() < 20

func configure(scene: Node3D) -> void:
	world = scene
	heights.clear()
	supports.clear()
	for path in ["ArkRoot/RaftBase","ArkRoot/RaftBoardingGangplank","ArkRoot/BuiltRaftExtension","MoonbackOldLanding/PierDeck","MoonbackOldLanding/ShoreApproach"]:
		var body := world.get_node_or_null(path)
		if body == null: continue
		for child in body.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D and not child.disabled: supports.append(child)

func _height(point: Vector3) -> Variant:
	var key := Vector2(point.x,point.z)
	if heights.has(key): return heights[key]
	samples += 1
	var value: Variant = world._ground_height_at(point)
	for box in supports:
		var size: Vector3 = box.shape.size*.5
		var top: Vector3 = box.to_global(Vector3(0,size.y,0))
		var normal: Vector3 = box.global_basis.y.normalized()
		if normal.y < .7: continue
		var y: float = top.y-(normal.x*(point.x-top.x)+normal.z*(point.z-top.z))/normal.y
		var local: Vector3 = box.to_local(Vector3(point.x,y,point.z))
		var outside := Vector2(maxf(0,absf(local.x)-size.x),maxf(0,absf(local.z)-size.z))
		if outside.length() <= FOOT_RADIUS:
			if value == null or y > float(value): value = y
	if value != null and float(value) <= world.WATER_SURFACE_Y+.12: value = null
	heights[key] = value
	return value

func support(point: Vector3) -> Variant:
	# Box support uses the real foot radius; actual terrain uses its center face.
	# Dense edge sampling and the capsule clearance query reject steep contacts.
	return _height(point)

func _clear(point: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = FOOT_RADIUS
	capsule.height = 1.6
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY,point+Vector3.UP*(.8-OFFSET+.025))
	query.collision_mask = 1
	query.exclude = [world.player.get_rid()]
	query.margin = .001
	return world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _segment(a: Vector3,b: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	var steps := maxi(1,ceili(Vector2(b.x-a.x,b.z-a.z).length()/.10))
	var previous := a
	for i in range(1,steps+1):
		var p := a.lerp(b,float(i)/steps)
		var h: Variant = support(p)
		if h == null: return PackedVector3Array()
		p.y = float(h)+OFFSET
		var horizontal := Vector2(p.x-previous.x,p.z-previous.z).length()
		if absf(p.y-previous.y) > maxf(.16,horizontal*1.02) or not _clear(p): return PackedVector3Array()
		result.append(p)
		previous = p
	return result

func can_move(a: Vector3,b: Vector3) -> bool:
	return a.distance_to(b) < .00001 or not _segment(a,b).is_empty()

func _coarse_connection(a: Vector3,b: Vector3) -> bool:
	var horizontal := Vector2(a.x-b.x,a.z-b.z).length()
	if absf(a.y-b.y) > maxf(.16,horizontal*.9): return false
	var previous := a.y
	for t in [.25,.5,.75,1.]:
		var h: Variant = support(a.lerp(b,t))
		if h == null or absf(float(h)+OFFSET-previous) > maxf(.16,horizontal*.255): return false
		previous = float(h)+OFFSET
	return true

func build(start: Vector3,destination: Vector3) -> PackedVector3Array:
	begin(start,destination)
	while not done: step(100000)
	return result

func begin(start: Vector3,destination: Vector3) -> void:
	heights.clear()
	samples = 0
	rejected_edges.clear()
	result.clear()
	done = true
	if not start.is_finite() or not destination.is_finite() or not handles(start) or not handles(destination): return
	if absf(start.x-destination.x) > 32 or absf(start.z-destination.z) > 32: return
	var a: Variant = support(start)
	var b: Variant = support(destination)
	if a == null or b == null or absf(start.y-(float(a)+OFFSET)) > .4: return
	_end = Vector3(destination.x,float(b)+OFFSET,destination.z)
	if not _clear(_end): return
	_start = start
	_destination = destination
	_floor_start = Vector3(start.x,float(a)+OFFSET,start.z)
	_minimum = Vector2(minf(start.x,_end.x),minf(start.z,_end.z))-Vector2.ONE*4.5
	_size = Vector2i(ceili((absf(start.x-_end.x)+9.)/CELL)+1,ceili((absf(start.z-_end.z)+9.)/CELL)+1)
	_graph = AStar3D.new()
	_cells.clear()
	_cursor = 0
	_attempt = 0
	_phase = "cells"
	done = false

func step(budget_usec: int = 1500) -> void:
	var clock := Time.get_ticks_usec()
	while not done and Time.get_ticks_usec()-clock < maxi(100,budget_usec):
		match _phase:
			"cells":
				if _cursor >= _size.x*_size.y:
					_keys = _cells.keys()
					_cursor = 0
					_phase = "edges"
					continue
				var cell := Vector2i(_cursor%_size.x,_cursor/_size.x)
				var p := Vector3(_minimum.x+cell.x*CELL,0,_minimum.y+cell.y*CELL)
				var h: Variant = support(p)
				if h != null:
					p.y = float(h)+OFFSET
					if _clear(p):
						_cells[cell] = _cursor
						_graph.add_point(_cursor,p)
				_cursor += 1
			"edges":
				if _cursor >= _keys.size():
					_start_id = _size.x*_size.y
					_end_id = _start_id+1
					_graph.add_point(_start_id,_floor_start)
					_graph.add_point(_end_id,_end)
					_cursor = 0
					_phase = "endpoints"
					continue
				var cell: Vector2i = _keys[_cursor]
				for offset in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(-1,1)]:
					if not _cells.has(cell+offset): continue
					var id: int = _cells[cell]
					var other: int = _cells[cell+offset]
					var first := _graph.get_point_position(id)
					var second := _graph.get_point_position(other)
					if _coarse_connection(first,second):
						_graph.connect_points(id,other)
				_cursor += 1
			"endpoints":
				if _cursor >= _keys.size():
					_phase = "search"
					continue
				var id: int = _cells[_keys[_cursor]]
				var p := _graph.get_point_position(id)
				if p.distance_to(_floor_start) < CELL*1.6 and not _segment(_floor_start,p).is_empty(): _graph.connect_points(_start_id,id)
				if p.distance_to(_end) < CELL*1.6 and not _segment(p,_end).is_empty(): _graph.connect_points(id,_end_id)
				_cursor += 1
			"search":
				_attempt += 1
				if _attempt > 12:
					done = true
					continue
				_path = _graph.get_id_path(_start_id,_end_id)
				if _path.is_empty():
					done = true
					continue
				_route = PackedVector3Array([_start])
				if _start.distance_to(_floor_start) > .001: _route.append(_floor_start)
				_cursor = 1
				_phase = "validate"
			"validate":
				if _cursor >= _path.size():
					if _destination.is_equal_approx(world.ark_root.to_global(world.RESIDENT_DECK_POSITION)) and _end.distance_to(_destination) < .15: _route.append(_destination)
					result = _route
					done = true
					continue
				var segment := _segment(_graph.get_point_position(_path[_cursor-1]),_graph.get_point_position(_path[_cursor]))
				if segment.is_empty():
					rejected_edges.append([_graph.get_point_position(_path[_cursor-1]),_graph.get_point_position(_path[_cursor])])
					_graph.disconnect_points(_path[_cursor-1],_path[_cursor])
					_phase = "search"
				else:
					_route.append_array(segment)
					_cursor += 1
