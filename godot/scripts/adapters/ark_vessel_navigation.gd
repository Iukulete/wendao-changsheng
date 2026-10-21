extends RefCounted
## Controlled CharacterBody movement. Positions are vessel-local across floors;
## floor_id names topology, not a hidden transform. World actors use global positions.
## Layout definitions and physics bodies are rebound, never stored in the save.
var _vessel: Node3D
var _vessel_id := ""
var _points: Dictionary = {}
var _links: Array = []
var _actors: Dictionary = {}
var _bodies: Dictionary = {}
static var _next_session := 0
var _session := 0
var _epoch := 0
var layout_version := 0
var plan_count := 0
var collision_stops := 0
const SPEED := 2.0

func _init() -> void:
	_next_session += 1
	_session = _next_session

func configure(vessel: Node3D, vessel_id: String) -> void:
	_vessel = vessel
	_vessel_id = vessel_id

func bind_actor(id: String, body: CharacterBody3D, floor_id: String) -> void:
	_bodies[id] = body
	if not _actors.has(id):
		_actors[id] = {"space": "vessel", "vessel_id": _vessel_id, "floor_id": floor_id,
			"task_id": "", "target": "", "phase": "idle", "generation": 0, "path": [], "index": 0, "layout_version": -1}
	elif _actors[id].phase == "idle":
		_actors[id].floor_id = floor_id

func define_layout(points: Dictionary, links: Array) -> void:
	_points = points.duplicate(true)
	_links = links.duplicate(true)
	invalidate_layout()

func invalidate_layout() -> void:
	layout_version += 1
	for state in _actors.values():
		if state.phase in ["moving", "waiting_layout", "blocked"] and not str(state.target).is_empty():
			state.phase = "moving"
			state.layout_version = -1

func has_active_task(id: String) -> bool:
	return _actors.has(id) and _actors[id].phase in ["moving", "waiting_layout"]

func inspect_actor(id: String) -> Dictionary:
	return _actors.get(id, {}).duplicate(true)

func request_move(id: String, target: String, task_id: String) -> Dictionary:
	if not _actors.has(id) or task_id.is_empty() or not _points.has(target):
		return {"ok": false, "code": "unknown_actor_or_target"}
	var state: Dictionary = _actors[id]
	if state.space != "vessel":
		return {"ok": false, "code": "not_aboard"}
	state.generation = int(state.generation) + 1
	if state.generation > 2147483647:
		state.generation = 0
		_epoch += 1
	state.task_id = task_id
	state.target = target
	state.phase = "moving"
	return _plan(id)

func is_request_current(id: String, token: Dictionary) -> bool:
	return has_active_task(id) and int(token.get("session", -1)) == _session and int(token.get("epoch", -1)) == _epoch and int(token.get("generation", -1)) == int(_actors[id].generation) and int(token.get("layout_version", -1)) == layout_version

func cancel(id: String) -> void:
	if not _actors.has(id):
		return
	var state: Dictionary = _actors[id]
	state.generation = int(state.generation) + 1
	if state.generation > 2147483647:
		state.generation = 0
		_epoch += 1
	state.phase = "cancelled"
	state.path = []
	state.target = ""
	if _bodies.has(id):
		_bodies[id].velocity = Vector3.ZERO

func transfer_space(id: String, parent: Node3D, space: String, floor_id: String = "") -> bool:
	if not _actors.has(id) or not _bodies.has(id) or space not in ["world", "vessel"] or (space == "vessel" and parent != _vessel):
		return false
	cancel(id)
	var body: CharacterBody3D = _bodies[id]
	if body.get_parent() != parent:
		body.reparent(parent, true)
	var state: Dictionary = _actors[id]
	state.space = space
	state.vessel_id = _vessel_id if space == "vessel" else ""
	state.floor_id = floor_id if space == "vessel" else ""
	return true

func step(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	for id in _actors:
		var state: Dictionary = _actors[id]
		if not has_active_task(id) or not _bodies.has(id):
			continue
		if _points.is_empty():
			state.phase = "waiting_layout"
			continue
		if state.layout_version != layout_version and not _plan(id).ok:
			continue
		var body: CharacterBody3D = _bodies[id]
		var remaining := SPEED * minf(delta, 0.25)
		while state.index < state.path.size() and remaining > 0.0:
			var point: Dictionary = _points[state.path[state.index]]
			var target: Vector3 = point.position
			if str(point.floor_id).begins_with("stairs:"):
				state.floor_id = point.floor_id
			var difference := target - body.position
			if difference.length() <= 0.025:
				state.floor_id = point.floor_id
				state.index += 1
				continue
			var distance := minf(remaining, difference.length())
			if body.move_and_collide(_vessel.global_basis * difference.normalized() * distance) != null:
				collision_stops += 1
				state.phase = "blocked"
				body.velocity = Vector3.ZERO
				break
			remaining -= distance
		if state.phase == "moving" and state.index >= state.path.size():
			state.phase = "arrived"
			body.velocity = Vector3.ZERO

func _plan(id: String) -> Dictionary:
	plan_count += 1
	var state: Dictionary = _actors[id]
	var body: CharacterBody3D = _bodies[id]
	state.path = []
	state.index = 0
	state.layout_version = layout_version
	if _points.is_empty() or not _points.has(state.target):
		state.phase = "waiting_layout"
		return {"ok": false, "code": "layout_unavailable"}
	var start := ""
	var nearest := INF
	for point_id in _points:
		var point: Dictionary = _points[point_id]
		if str(point.floor_id) != str(state.floor_id):
			continue
		var distance: float = body.position.distance_to(point.position)
		if distance < nearest and _edge_clear(body, body.position, point.position):
			nearest = distance
			start = str(point_id)
	if start.is_empty():
		state.phase = "blocked"
		return {"ok": false, "code": "unreachable"}
	var queue: Array = [start]
	var previous: Dictionary = {start: ""}
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if current == state.target:
			break
		for edge in _links:
			var next := str(edge[1]) if str(edge[0]) == current else str(edge[0]) if str(edge[1]) == current else ""
			if next.is_empty() or previous.has(next) or not _points.has(next):
				continue
			if _edge_clear(body, _points[current].position, _points[next].position):
				previous[next] = current
				queue.append(next)
	if not previous.has(state.target):
		state.phase = "blocked"
		return {"ok": false, "code": "unreachable"}
	var cursor: String = state.target
	var path: Array = []
	while not cursor.is_empty():
		path.push_front(cursor)
		cursor = previous[cursor]
	state.path = path
	state.phase = "moving"
	return {"ok": true, "session": _session, "epoch": _epoch, "layout_version": layout_version, "generation": state.generation}

func _edge_clear(body: CharacterBody3D, from: Vector3, to: Vector3) -> bool:
	var transform := body.global_transform
	transform.origin = _vessel.to_global(from)
	if body.test_move(transform, _vessel.global_basis * (to - from)):
		return false
	# A clear sweep alone is not a walkable route: sample real support across gaps.
	var samples := maxi(1, ceili(from.distance_to(to) / 0.25))
	for index in range(samples + 1):
		var local := from.lerp(to, float(index) / float(samples))
		var query := PhysicsRayQueryParameters3D.create(_vessel.to_global(local + Vector3.UP * 0.1), _vessel.to_global(local - Vector3.UP * 0.45), 1, [body.get_rid()])
		if body.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return false
	return true

func snapshot() -> Dictionary:
	var result: Dictionary = {"vessel_id": _vessel_id, "actors": {}}
	for id in _actors:
		if not _bodies.has(id) or not is_instance_valid(_bodies[id]):
			continue
		var state: Dictionary = _actors[id]
		var body: CharacterBody3D = _bodies[id]
		var position := body.position if state.space == "vessel" else _world_position(body)
		result.actors[id] = {"space": state.space, "vessel_id": state.vessel_id, "floor_id": state.floor_id,
			"position": {"x": position.x, "y": position.y, "z": position.z}, "task_id": state.task_id,
			"target": state.target, "phase": state.phase, "generation": state.generation}
	return result

func _world_position(body: Node3D) -> Vector3:
	if body.is_inside_tree():
		return body.global_position
	# Children have already left the tree during a parent's exit snapshot.
	var composed := body.transform
	var parent := body.get_parent()
	while parent is Node3D:
		composed = (parent as Node3D).transform * composed
		parent = parent.get_parent()
	return composed.origin

func validate_snapshot(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 2 or data.get("vessel_id") != _vessel_id or not data.get("actors") is Dictionary:
		return false
	var actors: Dictionary = data.actors
	# Unknown/unbound IDs cannot be silently dropped. Register restored actors
	# before validating, and require a snapshot for each registered owner.
	if actors.size() != _bodies.size():
		return false
	var keys := ["space", "vessel_id", "floor_id", "position", "task_id", "target", "phase", "generation"]
	for id in actors:
		if not id is String or not _bodies.has(id) or not actors[id] is Dictionary:
			return false
		var state: Dictionary = actors[id]
		if state.size() != keys.size():
			return false
		for key in keys:
			if not state.has(key):
				return false
		for key in ["space", "vessel_id", "floor_id", "task_id", "target", "phase"]:
			if not state[key] is String or state[key].length() > 256:
				return false
		if state.space not in ["world", "vessel"] or state.phase not in ["idle", "moving", "waiting_layout", "blocked", "arrived", "cancelled"]:
			return false
		if state.space == "vessel":
			if state.vessel_id != _vessel_id or state.floor_id.is_empty():
				return false
		elif state.vessel_id != "" or state.floor_id != "" or state.phase in ["moving", "waiting_layout", "blocked", "arrived"]:
			return false
		if state.phase in ["moving", "waiting_layout", "blocked", "arrived"] and (state.task_id.is_empty() or state.target.is_empty()):
			return false
		if state.phase in ["idle", "cancelled"] and not state.target.is_empty():
			return false
		var generation: Variant = state.generation
		if not (generation is int or generation is float) or not is_finite(float(generation)) or float(generation) != floor(float(generation)) or float(generation) < 0 or float(generation) > 2147483647:
			return false
		if not state.position is Dictionary or state.position.size() != 3:
			return false
		for axis in ["x", "y", "z"]:
			var value: Variant = state.position.get(axis)
			if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value)) > 1000000.0:
				return false
	return true

func restore(data: Dictionary) -> bool:
	if not validate_snapshot(data):
		return false
	_epoch += 1 # Repeated loads invalidate pre-load deferred work too.
	for id in data.actors:
		var incoming: Dictionary = data.actors[id]
		var position: Dictionary = incoming.position
		var local := Vector3(float(position.x), float(position.y), float(position.z))
		var state: Dictionary = _actors[id]
		for key in ["space", "vessel_id", "floor_id", "task_id", "target", "phase"]:
			state[key] = incoming[key]
		state.generation = int(incoming.generation)
		var body: CharacterBody3D = _bodies[id]
		var parent: Node3D = _vessel.get_parent() if state.space == "world" else _vessel
		if body.get_parent() != parent:
			body.reparent(parent, true)
		if state.space == "world":
			body.global_position = local
		else:
			body.position = local
		state.path = []
		state.index = 0
		state.layout_version = -1
		if state.phase == "moving":
			state.phase = "waiting_layout"
	return true
