extends RefCounted
const Memory = preload("res://scripts/modules/memory/ark_memory.gd")
## Resident jobs own no Nodes. Economy is sole payload/source authority.
var _economy: RefCounted
var _tasks: Dictionary = {}
var _active: Dictionary = {}
var _inactive_regions: Dictionary = {}
var _sequence := 0
var _generation := 0
var _instance := 0
var _routes: Dictionary = {}

func _init() -> void: _instance = get_instance_id()
func configure(economy: RefCounted) -> void: _economy = economy
func task(id: String) -> Dictionary: return _tasks.get(id, {}).duplicate(true)
func active_task(resident: String) -> Dictionary: return task(str(_active.get(resident, "")))

func source_in_use(source_id: String) -> bool:
	for id in _active.values():
		if _tasks[id].source_id == source_id: return true
	return false

func dispatch(resident: String, source_id: String, destination: String, region: String = "shore") -> Dictionary:
	if _economy == null or resident.is_empty() or _inactive_regions.has(region): return {"ok":false,"code":"inactive"}
	if _active.has(resident):
		var existing := active_task(resident)
		return {"ok":existing.source_id == source_id,"task_id":existing.id,"duplicate":true}
	_sequence += 1
	var id := "gather:%d" % _sequence
	var reserved: Dictionary = _economy.reserve(source_id,id)
	if not reserved.ok: return reserved
	_tasks[id] = {"id":id,"resident_id":resident,"source_id":source_id,"destination":destination,"region":region,"phase":"outbound","version":1,"collect_elapsed":0.0}
	_active[resident] = id
	return {"ok":true,"task_id":id}

func token(id: String) -> Dictionary:
	return {"instance":_instance,"generation":_generation,"task_id":id,"version":int(_tasks.get(id,{}).get("version",-1))}

func accept_result(value: Dictionary, layout_version: int = -1) -> bool:
	var id := str(value.get("task_id",""))
	if int(value.get("instance",-1)) != _instance or int(value.get("generation",-1)) != _generation or not _tasks.has(id): return false
	var entry: Dictionary = _tasks[id]
	return int(value.get("version",-1)) == int(entry.version) and _active.get(entry.resident_id) == id and (layout_version < 0 or int(value.get("layout_version",-2)) == layout_version)

func set_destination(id: String, destination: String) -> bool:
	if not _tasks.has(id) or destination.is_empty(): return false
	_tasks[id].destination = destination
	return true

func mark_collecting(id: String) -> bool:
	if not _tasks.has(id): return false
	var entry: Dictionary = _tasks[id]
	if entry.phase == "collecting": return true
	if entry.phase != "outbound": return false
	entry.phase = "collecting"
	entry.collect_elapsed = 0.0
	entry.version = int(entry.version) + 1
	return true

func collection_tick(id: String, delta: float) -> Dictionary:
	if not _tasks.has(id) or _tasks[id].phase != "collecting" or not is_finite(delta) or delta < 0:
		return {"ok":false,"remaining":0.65,"complete":false}
	var entry: Dictionary = _tasks[id]
	entry.collect_elapsed = minf(0.65,float(entry.collect_elapsed) + delta)
	var remaining := maxf(0.0,0.65 - float(entry.collect_elapsed))
	return {"ok":true,"remaining":remaining,"complete":remaining <= 0.0}

func harvest(id: String) -> Dictionary:
	if not _tasks.has(id): return {"ok":false,"code":"unknown"}
	var entry: Dictionary = _tasks[id]
	if entry.phase in ["cancelled","delivered"]: return {"ok":false,"code":"terminal"}
	var result: Dictionary = _economy.harvest(id)
	if result.ok and entry.phase != "returning":
		entry.phase = "returning"
		entry.version = int(entry.version) + 1
	return result

func _finish(id: String, phase: String) -> void:
	var entry: Dictionary = _tasks[id]
	entry.phase = phase
	entry.version = int(entry.version) + 1
	if _active.get(entry.resident_id) == id: _active.erase(entry.resident_id)
	_routes.erase(id)

func deliver(id: String) -> Dictionary:
	if not _tasks.has(id): return {"ok":false,"code":"unknown"}
	var entry: Dictionary = _tasks[id]
	if entry.phase == "delivered": return {"ok":true,"duplicate":true}
	var result: Dictionary = _economy.deliver(id,str(entry.destination))
	if result.ok: _finish(id,"delivered")
	return result

func cancel(id: String, _reason: String = "cancelled") -> Dictionary:
	if not _tasks.has(id): return {"ok":false,"code":"unknown"}
	var entry: Dictionary = _tasks[id]
	if entry.phase in ["cancelled","delivered"]: return {"ok":true,"duplicate":true}
	_economy.release(id)
	entry.version = int(entry.version) + 1
	_routes.erase(id)
	if not _economy.carried(id).is_empty():
		var result: Dictionary = _economy.deliver(id,str(entry.destination))
		if not result.ok:
			entry.phase = "cancel_return_pending"
			return result
	_finish(id,"cancelled")
	return {"ok":true}

func unload_region(region: String) -> void:
	_inactive_regions[region] = true
	for id in _tasks.keys():
		if _tasks[id].region == region and _active.get(_tasks[id].resident_id) == id: cancel(id,"region_unload")
func reload_region(region: String) -> void: _inactive_regions.erase(region)

func import_legacy_task(resident: String, source_id: String, destination: String, phase: String, payload: int, resource: String, pickup_remaining: float = 0.65) -> Dictionary:
	if _active.has(resident): return {"ok":true,"task_id":_active[resident]}
	if payload <= 0:
		var result := dispatch(resident,source_id,destination)
		if result.ok and phase == "collecting":
			mark_collecting(result.task_id)
			_tasks[result.task_id].collect_elapsed = 0.65 - clampf(pickup_remaining,0.0,0.65)
		return result
	_sequence += 1
	var id := "gather:%d" % _sequence
	if not _economy.seed_carried(id,resource,payload): return {"ok":false}
	_tasks[id] = {"id":id,"resident_id":resident,"source_id":source_id,"destination":destination,"region":"shore","phase":"returning","version":1,"collect_elapsed":0.0}
	_active[resident] = id
	return {"ok":true,"task_id":id,"legacy_phase":phase}

static func advance_route(position: Vector3, route: PackedVector3Array, index: int, delta: float, speed: float, tolerance: float = 0.22) -> Dictionary:
	var next := position
	var cursor := index
	var budget := maxf(0.0,delta) * maxf(0.0,speed)
	while cursor < route.size():
		var target := route[cursor]
		var distance := next.distance_to(target)
		if distance <= tolerance:
			cursor += 1
			continue
		if budget <= 0: break
		var step := minf(budget,distance)
		next = next.move_toward(target,step)
		budget -= step
	return {"position":next,"index":cursor,"arrived":cursor >= route.size()}

func tick(id: String, delta: float, position: Vector3, target: Vector3, home: Vector3, path_builder: Callable, speed: float = 2.4) -> Dictionary:
	if not _tasks.has(id) or delta < 0 or not is_finite(delta): return {"ok":false,"position":position}
	var entry: Dictionary = _tasks[id]
	if entry.phase in ["cancelled","delivered"]: return {"ok":true,"position":position,"phase":entry.phase}
	if entry.phase == "cancel_return_pending":
		var returned := cancel(id)
		return {"ok":returned.ok,"position":position,"phase":entry.phase}
	if entry.phase == "collecting":
		var progress := collection_tick(id,delta)
		if progress.complete:
			var harvested := harvest(id)
			_routes.erase(id)
			if not harvested.ok: cancel(id,"harvest_failed")
		return {"ok":true,"position":position,"phase":entry.phase}
	var goal := home if entry.phase == "returning" else target
	if not _routes.has(id):
		var path: Variant = path_builder.call(position,goal)
		if not path is PackedVector3Array or path.is_empty():
			cancel(id,"no_path")
			return {"ok":false,"position":position,"code":"no_path"}
		_routes[id] = {"points":path,"index":0}
	var route: Dictionary = _routes[id]
	var moved := advance_route(position,route.points,int(route.index),delta,speed)
	route.index = moved.index
	if moved.arrived:
		_routes.erase(id)
		if entry.phase == "returning": deliver(id)
		else:
			mark_collecting(id)
	return {"ok":true,"position":moved.position,"phase":entry.phase}

func invalidate_routes() -> void:
	_generation += 1
	_routes.clear()

func snapshot() -> Dictionary:
	return {"tasks":_tasks.duplicate(true),"active":_active.duplicate(true),"inactive_regions":_inactive_regions.duplicate(true),"sequence":_sequence,"generation":_generation}

func restore(saved: Dictionary) -> bool:
	if not Memory._plain(saved): return false
	if _economy == null or not saved.get("tasks") is Dictionary or not saved.get("active") is Dictionary or not saved.get("inactive_regions") is Dictionary: return false
	for key in ["sequence","generation"]:
		if not _economy._quantity(saved.get(key)): return false
	var economic: Dictionary = _economy.snapshot()
	for region in saved.inactive_regions:
		if not region is String or saved.inactive_regions[region] != true: return false
	for id in saved.tasks:
		var entry: Variant = saved.tasks[id]
		if not id is String or not entry is Dictionary: return false
		for key in ["id","resident_id","source_id","destination","region","phase"]:
			if not entry.get(key) is String: return false
		if entry.id != id or not id.begins_with("gather:") or not id.substr(7).is_valid_int() or int(id.substr(7)) > int(saved.sequence): return false
		if not _economy._quantity(entry.get("version")) or int(entry.version) < 1: return false
		if not (entry.get("collect_elapsed") is float or entry.get("collect_elapsed") is int) or not is_finite(float(entry.collect_elapsed)) or float(entry.collect_elapsed) < 0 or float(entry.collect_elapsed) > 0.65: return false
		if entry.phase not in ["outbound","collecting","returning","cancel_return_pending","cancelled","delivered"]: return false
		var active: bool = entry.phase not in ["cancelled","delivered"]
		if active != (saved.active.get(entry.resident_id) == id): return false
		if entry.phase in ["outbound","collecting"] and economic.reservations.get(entry.source_id) != id: return false
		if entry.phase in ["returning","cancel_return_pending"] and not economic.cargo.has(id): return false
		if entry.phase == "delivered" and not economic.receipts.has("deliver:" + id): return false
		if not active and (economic.cargo.has(id) or id in economic.reservations.values()): return false
	for resident in saved.active:
		var id: Variant = saved.active[resident]
		if not resident is String or not id is String or not saved.tasks.has(id) or saved.tasks[id].resident_id != resident: return false
	for id in economic.cargo:
		if not saved.tasks.has(id) or saved.tasks[id].phase not in ["returning","cancel_return_pending"]: return false
	for id in economic.reservations.values():
		if not saved.tasks.has(id) or saved.tasks[id].phase not in ["outbound","collecting"]: return false
	_tasks = saved.tasks.duplicate(true)
	_active = saved.active.duplicate(true)
	_inactive_regions = saved.inactive_regions.duplicate(true)
	_sequence = int(saved.sequence)
	_generation = maxi(_generation,int(saved.generation)) + 1
	_routes.clear()
	return true
