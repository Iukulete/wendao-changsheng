extends RefCounted
const Memory = preload("res://scripts/modules/memory/ark_memory.gd")
## Sole finite stock, inventory and carried-payload owner. Values are JSON-safe.
var _sources: Dictionary = {}
var _inventories: Dictionary = {}
var _capacities: Dictionary = {}
var _reservations: Dictionary = {}
var _cargo: Dictionary = {}
var _receipts: Dictionary = {}
var _totals: Dictionary = {}

func _bucket(resource: String) -> Dictionary:
	if not _totals.has(resource):
		_totals[resource] = {"initial":0,"input":0,"consumed":0,"outflow":0}
	return _totals[resource]

func _amounts(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key in value:
		if not key is String or key.is_empty() or not _quantity(value[key]): return false
	return true

func _quantity(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) == floor(float(value)) and float(value) <= 1000000000

func seed_inventory(owner: String, amounts: Dictionary) -> bool:
	if owner.is_empty() or _inventories.has(owner) or not _amounts(amounts): return false
	_inventories[owner] = amounts.duplicate(true)
	for resource in amounts: _bucket(resource).initial += int(amounts[resource])
	return true

func inventory(owner: String, resource: String) -> int:
	return int(_inventories.get(owner, {}).get(resource, 0))

func sync_inventory(owner: String, resource: String, amount: int, _reason: String = "legacy_write") -> bool:
	if amount < 0 or owner.is_empty() or resource.is_empty(): return false
	var delta := amount - inventory(owner, resource)
	if not _inventories.has(owner): _inventories[owner] = {}
	_inventories[owner][resource] = amount
	if delta >= 0: _bucket(resource).input += delta
	else: _bucket(resource).consumed -= delta
	return true

func seed_source(id: String, resource: String, amount: int, region: String = "shore") -> bool:
	if id.is_empty() or resource.is_empty() or amount < 0 or _sources.has(id): return false
	_sources[id] = {"resource":resource,"remaining":amount,"region":region}
	_bucket(resource).initial += amount
	return true

func seed_carried(task_id: String, resource: String, amount: int) -> bool:
	if task_id.is_empty() or resource.is_empty() or amount <= 0 or _cargo.has(task_id): return false
	_cargo[task_id] = {"resource":resource,"amount":amount}
	_bucket(resource).initial += amount
	return true

func source(id: String) -> Dictionary: return _sources.get(id, {}).duplicate(true)
func carried(id: String) -> Dictionary: return _cargo.get(id, {}).duplicate(true)
func set_capacity(owner: String, amount: int) -> bool:
	if amount < 0: return false
	_capacities[owner] = amount
	return true

func can_accept(owner: String, amounts: Dictionary) -> bool:
	if not _amounts(amounts): return false
	var total := 0
	for value in _inventories.get(owner, {}).values(): total += int(value)
	for value in amounts.values(): total += int(value)
	return total <= int(_capacities.get(owner, 1000000000))

func reserve(source_id: String, task_id: String) -> Dictionary:
	if not _sources.has(source_id) or int(_sources[source_id].remaining) <= 0: return {"ok":false,"code":"depleted"}
	for id in _reservations:
		if _reservations[id] == task_id and id != source_id: return {"ok":false,"code":"already_reserved"}
	if _reservations.has(source_id) and _reservations[source_id] != task_id: return {"ok":false,"code":"reserved"}
	_reservations[source_id] = task_id
	return {"ok":true}

func release(task_id: String) -> void:
	for id in _reservations.keys():
		if _reservations[id] == task_id: _reservations.erase(id)

func harvest(task_id: String) -> Dictionary:
	if _cargo.has(task_id): return {"ok":true,"payload":carried(task_id),"duplicate":true}
	if _receipts.has("deliver:" + task_id): return {"ok":false,"code":"already_delivered"}
	for id in _reservations:
		if _reservations[id] != task_id: continue
		var entry: Dictionary = _sources[id]
		var amount := int(entry.remaining)
		if amount <= 0: return {"ok":false,"code":"depleted"}
		_cargo[task_id] = {"resource":entry.resource,"amount":amount}
		entry.remaining = 0
		_reservations.erase(id)
		return {"ok":true,"payload":carried(task_id)}
	return {"ok":false,"code":"no_reservation"}

func deliver(task_id: String, owner: String) -> Dictionary:
	var receipt := "deliver:" + task_id
	if _receipts.has(receipt): return {"ok":true,"duplicate":true}
	if not _cargo.has(task_id): return {"ok":false,"code":"no_payload"}
	var payload: Dictionary = _cargo[task_id]
	var amounts := {str(payload.resource):int(payload.amount)}
	if not can_accept(owner, amounts): return {"ok":false,"code":"capacity"}
	_add(owner, amounts)
	_cargo.erase(task_id)
	_receipts[receipt] = true
	return {"ok":true,"amount":payload.amount,"resource":payload.resource}

func collect_direct(source_id: String, owner: String) -> Dictionary:
	if not _sources.has(source_id) or int(_sources[source_id].remaining) <= 0: return {"ok":false,"code":"depleted"}
	var entry: Dictionary = _sources[source_id]
	var amount := int(entry.remaining)
	var amounts := {str(entry.resource):amount}
	if not can_accept(owner, amounts): return {"ok":false,"code":"capacity"}
	var displaced := str(_reservations.get(source_id, ""))
	_reservations.erase(source_id)
	entry.remaining = 0
	_add(owner, amounts)
	return {"ok":true,"amount":amount,"resource":entry.resource,"displaced_task_id":displaced}

func _add(owner: String, amounts: Dictionary) -> void:
	if not _inventories.has(owner): _inventories[owner] = {}
	for resource in amounts: _inventories[owner][resource] = inventory(owner, resource) + int(amounts[resource])

func consume(owner: String, costs: Dictionary, operation_id: String) -> Dictionary:
	if _receipts.has(operation_id): return {"ok":true,"duplicate":true}
	if operation_id.is_empty() or not _amounts(costs): return {"ok":false,"code":"invalid"}
	for resource in costs:
		if inventory(owner, resource) < int(costs[resource]): return {"ok":false,"code":"materials"}
	for resource in costs:
		_inventories[owner][resource] = inventory(owner, resource) - int(costs[resource])
		_bucket(resource).consumed += int(costs[resource])
	_receipts[operation_id] = true
	return {"ok":true}

func input(owner: String, resource: String, amount: int, operation_id: String) -> Dictionary:
	return input_many(owner, {resource:amount}, operation_id)

func input_many(owner: String, amounts: Dictionary, operation_id: String) -> Dictionary:
	if _receipts.has(operation_id): return {"ok":true,"duplicate":true}
	if operation_id.is_empty() or not can_accept(owner, amounts): return {"ok":false,"code":"capacity_or_invalid"}
	_add(owner, amounts)
	for resource in amounts: _bucket(resource).input += int(amounts[resource])
	_receipts[operation_id] = true
	return {"ok":true}

func transfer(from_owner: String, to_owner: String, amounts: Dictionary, operation_id: String) -> Dictionary:
	if _receipts.has(operation_id): return {"ok":true,"duplicate":true}
	if operation_id.is_empty() or not _amounts(amounts) or not can_accept(to_owner, amounts): return {"ok":false,"code":"invalid_or_capacity"}
	for resource in amounts:
		if inventory(from_owner, resource) < int(amounts[resource]): return {"ok":false,"code":"materials"}
	for resource in amounts: _inventories[from_owner][resource] = inventory(from_owner, resource) - int(amounts[resource])
	_add(to_owner, amounts)
	_receipts[operation_id] = true
	return {"ok":true}

func snapshot() -> Dictionary:
	return {"sources":_sources.duplicate(true),"inventories":_inventories.duplicate(true),"capacities":_capacities.duplicate(true),"reservations":_reservations.duplicate(true),"cargo":_cargo.duplicate(true),"receipts":_receipts.duplicate(true),"totals":_totals.duplicate(true)}

func _assign(saved: Dictionary) -> void:
	_sources = saved.sources.duplicate(true)
	_inventories = saved.inventories.duplicate(true)
	_capacities = saved.capacities.duplicate(true)
	_reservations = saved.reservations.duplicate(true)
	_cargo = saved.cargo.duplicate(true)
	_receipts = saved.receipts.duplicate(true)
	_totals = saved.totals.duplicate(true)

func restore(saved: Dictionary) -> bool:
	if not Memory._plain(saved): return false
	for key in ["sources","inventories","capacities","reservations","cargo","receipts","totals"]:
		if not saved.get(key) is Dictionary: return false
	var old := snapshot()
	_assign(saved)
	if not audit().ok:
		_assign(old)
		return false
	return true

func audit() -> Dictionary:
	var observed: Dictionary = {}
	for owner in _inventories:
		if not owner is String or not _amounts(_inventories[owner]): return {"ok":false,"code":"inventory"}
		for resource in _inventories[owner]: observed[resource] = int(observed.get(resource,0)) + int(_inventories[owner][resource])
	for id in _sources:
		var entry: Variant = _sources[id]
		if not id is String or not entry is Dictionary or not entry.get("resource") is String or not entry.get("region") is String or not _quantity(entry.get("remaining")): return {"ok":false,"code":"source"}
		observed[entry.resource] = int(observed.get(entry.resource,0)) + int(entry.remaining)
	for id in _cargo:
		if _receipts.has("deliver:" + str(id)): return {"ok":false,"code":"settled_cargo"}
		var entry: Variant = _cargo[id]
		if not id is String or not entry is Dictionary or not entry.get("resource") is String or not _quantity(entry.get("amount")) or int(entry.amount) <= 0: return {"ok":false,"code":"cargo"}
		observed[entry.resource] = int(observed.get(entry.resource,0)) + int(entry.amount)
	var seen: Dictionary = {}
	for id in _reservations:
		var task: Variant = _reservations[id]
		if not task is String or task.is_empty() or not _sources.has(id) or int(_sources[id].remaining) <= 0 or seen.has(task) or _cargo.has(task): return {"ok":false,"code":"reservation"}
		if _receipts.has("deliver:" + task): return {"ok":false,"code":"settled_reservation"}
		seen[task] = true
	for owner in _capacities:
		if not owner is String or not _quantity(_capacities[owner]): return {"ok":false,"code":"capacity"}
	for id in _receipts:
		if not id is String or id.is_empty() or _receipts[id] != true: return {"ok":false,"code":"receipt"}
	for resource in _totals:
		var totals: Variant = _totals[resource]
		if not resource is String or not _amounts(totals): return {"ok":false,"code":"totals"}
		for key in ["initial","input","consumed","outflow"]:
			if not totals.has(key): return {"ok":false,"code":"totals"}
		if int(totals.initial) + int(totals.input) != int(observed.get(resource,0)) + int(totals.consumed) + int(totals.outflow): return {"ok":false,"code":"conservation","resource":resource}
		observed.erase(resource)
	return {"ok":observed.is_empty(),"code":"ok" if observed.is_empty() else "unaccounted"}
