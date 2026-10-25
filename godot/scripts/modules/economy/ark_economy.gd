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
var _streams: Dictionary = {}
var _flows: Dictionary = {}
const MAX_STREAMS := 64

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

# A named depleted world source receives new physical stock, never inventory.
# The caller owns the fixed per-site quota and excludes active resident jobs.
func replenish_source(id: String, resource: String, amount: int, operation_id: String) -> Dictionary:
	if operation_id.is_empty() or id.is_empty() or resource.is_empty() or amount <= 0 or not _quantity(amount):
		return {"ok":false,"code":"invalid"}
	if _receipts.has(operation_id): return {"ok":true,"duplicate":true}
	if _reservations.has(id): return {"ok":false,"code":"reserved"}
	if _sources.has(id) and (_sources[id].resource != resource or int(_sources[id].remaining) != 0):
		return {"ok":false,"code":"not_depleted"}
	# Legacy saves may omit already collected sources entirely.
	var region := str(_sources.get(id, {}).get("region", "shore"))
	_sources[id] = {"resource":resource,"remaining":amount,"region":region}
	_bucket(resource).input += amount
	_receipts[operation_id] = true
	return {"ok":true,"amount":amount}

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
	return consume_shared(owner, costs, operation_id, {})

## Only explicitly allowed resource/owner pairs participate. Plan all deductions
## before writing any inventory: a missing rare component must not spend wood.
## As with consume/transfer, intent belongs to the command-owning service: reuse
## a receipt only for the same command (Construction compares its full intent).
func consume_shared(owner: String, costs: Dictionary, operation_id: String, shared: Dictionary) -> Dictionary:
	if _receipts.has(operation_id): return {"ok":true,"duplicate":true}
	if operation_id.is_empty() or owner.is_empty() or not _amounts(costs) or not valid_shared_sources(owner, shared): return {"ok":false,"code":"invalid"}
	var deductions: Dictionary = {}
	for resource in costs:
		var remaining := int(costs[resource])
		var owners: Array = [owner]
		owners.append_array(shared.get(resource, []))
		for source_owner in owners:
			var taken := mini(remaining, inventory(source_owner, resource))
			if taken > 0:
				if not deductions.has(source_owner): deductions[source_owner] = {}
				deductions[source_owner][resource] = taken
				remaining -= taken
		if remaining > 0: return {"ok":false,"code":"materials"}
	for source_owner in deductions:
		for resource in deductions[source_owner]:
			var taken := int(deductions[source_owner][resource])
			_inventories[source_owner][resource] = inventory(source_owner, resource) - taken
			_bucket(resource).consumed += taken
	_receipts[operation_id] = true
	return {"ok":true,"deductions":deductions}

static func valid_shared_sources(owner: String, shared: Dictionary) -> bool:
	for resource in shared:
		if not resource is String or resource.is_empty() or not shared[resource] is Array: return false
		var seen: Array = [owner]
		for source_owner in shared[resource]:
			if not source_owner is String or source_owner.is_empty() or seen.has(source_owner): return false
			seen.append(source_owner)
	return true

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

## Bounded machine ledger: one latest intent per stable producer/consumer, not
## one receipt per frame. Costs and outputs settle atomically for one owner.
func process_stream(owner: String, stream_id: String, sequence: int, costs: Dictionary, outputs: Dictionary) -> Dictionary:
	return process_shared_stream(owner,stream_id,sequence,costs,outputs,{})

## Bounded same-command ledger with explicit shared cost sources. Outputs still
## belong to one owner; all source deductions and output capacity are preflighted.
## Empty shared sources retain the original four-field stream representation.
func process_shared_stream(owner: String, stream_id: String, sequence: int, costs: Dictionary, outputs: Dictionary, shared: Dictionary) -> Dictionary:
	if owner.is_empty() or owner.length() > 64 or stream_id.is_empty() or stream_id.length() > 64 or sequence < 1 or sequence > 1000000000:
		return {"ok":false,"code":"invalid_stream"}
	if costs.size() > 8 or outputs.size() > 8 or not _amounts(costs) or not _amounts(outputs) or (costs.is_empty() and outputs.is_empty()):
		return {"ok":false,"code":"invalid_stream"}
	if not _valid_stream_sources(owner,costs,shared): return {"ok":false,"code":"invalid_stream"}
	for amount in costs.values()+outputs.values():
		if amount <= 0: return {"ok":false,"code":"invalid_stream"}
	var intent := {"owner":owner,"sequence":sequence,"costs":costs.duplicate(true),"outputs":outputs.duplicate(true)}
	if not shared.is_empty(): intent["shared"] = shared.duplicate(true)
	var previous: Dictionary = _streams.get(stream_id, {})
	if sequence == int(previous.get("sequence", 0)):
		return {"ok":true,"duplicate":true} if Memory.facts_equal(previous,intent) else {"ok":false,"code":"conflicting_replay"}
	if sequence != int(previous.get("sequence", 0)) + 1: return {"ok":false,"code":"stale_or_skipped_sequence"}
	if not _streams.has(stream_id) and _streams.size()+_flows.size() >= MAX_STREAMS: return {"ok":false,"code":"stream_limit"}
	var total := 0
	for value in _inventories.get(owner, {}).values(): total += int(value)
	var deductions: Dictionary = {}
	for resource in costs:
		var remaining := int(costs[resource])
		var owners: Array = [owner]
		owners.append_array(shared.get(resource,[]))
		for source_owner in owners:
			var taken := mini(remaining,inventory(source_owner,resource))
			if taken > 0:
				if not deductions.has(source_owner): deductions[source_owner] = {}
				deductions[source_owner][resource] = taken
				remaining -= taken
				if source_owner == owner: total -= taken
		if remaining > 0: return {"ok":false,"code":"materials"}
	for value in outputs.values(): total += int(value)
	if total > int(_capacities.get(owner, 1000000000)): return {"ok":false,"code":"capacity"}
	for resource in outputs:
		if inventory(owner,resource)-int(deductions.get(owner,{}).get(resource,0))+int(outputs[resource]) > 1000000000: return {"ok":false,"code":"quantity_limit"}
	for source_owner in deductions:
		for resource in deductions[source_owner]:
			var taken := int(deductions[source_owner][resource])
			_inventories[source_owner][resource] = inventory(source_owner,resource)-taken
			_bucket(resource).consumed += taken
	_add(owner, outputs)
	for resource in outputs: _bucket(resource).input += int(outputs[resource])
	_streams[stream_id] = intent
	return {"ok":true,"duplicate":false}

static func _valid_stream_sources(owner: String, costs: Dictionary, shared: Dictionary) -> bool:
	if shared.size() > 8 or not valid_shared_sources(owner,shared): return false
	for resource in shared:
		if not costs.has(resource) or shared[resource].size() > 8: return false
		for source_owner in shared[resource]:
			if source_owner.length() > 64: return false
	return true

## Multi-container production/hauling transaction. Transfers move stock without
## pretending to consume/recreate it; only recipe costs/outputs affect totals.
## All deductions, credits and capacities are planned before the first write.
func process_flow(id: String, sequence: int, moves: Array, costs: Dictionary = {}, outputs: Dictionary = {}) -> Dictionary:
	var intent := {"sequence":sequence,"moves":moves.duplicate(true),"costs":costs.duplicate(true),"outputs":outputs.duplicate(true)}
	if not _flow_valid(id,intent): return {"ok":false,"code":"invalid_flow"}
	var previous: Dictionary = _flows.get(id,{})
	if sequence == int(previous.get("sequence",0)):
		return {"ok":true,"duplicate":true} if Memory.facts_equal(previous,intent) else {"ok":false,"code":"conflicting_replay"}
	if sequence != int(previous.get("sequence",0))+1: return {"ok":false,"code":"stale_or_skipped_sequence"}
	if not _flows.has(id) and _flows.size()+_streams.size() >= MAX_STREAMS: return {"ok":false,"code":"stream_limit"}
	var debits := costs.duplicate(true)
	var credits := outputs.duplicate(true)
	for move in moves:
		_flow_add(debits,move["from"],move.resource,int(move.amount))
		_flow_add(credits,move.to,move.resource,int(move.amount))
	for owner in debits:
		for resource in debits[owner]:
			if inventory(owner,resource) < int(debits[owner][resource]): return {"ok":false,"code":"materials"}
	var owners: Dictionary = {}
	for owner in debits.keys()+credits.keys(): owners[owner] = true
	for owner in owners:
		var projected: Dictionary = _inventories[owner].duplicate(true)
		for resource in debits.get(owner,{}): projected[resource] = int(projected.get(resource,0))-int(debits[owner][resource])
		for resource in credits.get(owner,{}): projected[resource] = int(projected.get(resource,0))+int(credits[owner][resource])
		var total := 0
		for value in projected.values():
			if not _quantity(value): return {"ok":false,"code":"quantity_limit"}
			total += int(value)
		if total > int(_capacities.get(owner,1000000000)): return {"ok":false,"code":"capacity"}
	for owner in debits:
		for resource in debits[owner]: _inventories[owner][resource] = inventory(owner,resource)-int(debits[owner][resource])
	for owner in credits: _add(owner,credits[owner])
	for owner in costs:
		for resource in costs[owner]: _bucket(resource).consumed += int(costs[owner][resource])
	for owner in outputs:
		for resource in outputs[owner]: _bucket(resource).input += int(outputs[owner][resource])
	_flows[id] = intent
	return {"ok":true,"duplicate":false}

func flow(id: String) -> Dictionary: return _flows.get(id,{}).duplicate(true)

func _flow_add(plan: Dictionary, owner: String, resource: String, amount: int) -> void:
	if not plan.has(owner): plan[owner] = {}
	plan[owner][resource] = int(plan[owner].get(resource,0))+amount

func _flow_valid(id: Variant, intent: Variant) -> bool:
	if not id is String or id.is_empty() or id.length() > 64 or not intent is Dictionary or intent.size() != 4: return false
	if not _quantity(intent.get("sequence")) or intent.sequence < 1 or not intent.get("moves") is Array or intent.moves.size() > 8: return false
	var work := 0
	for key in ["costs","outputs"]:
		if not intent.get(key) is Dictionary or intent[key].size() > 8: return false
		for owner in intent[key]:
			if not _flow_owner(owner) or not _amounts(intent[key][owner]) or intent[key][owner].is_empty() or intent[key][owner].size() > 8: return false
			for amount in intent[key][owner].values():
				if amount <= 0: return false
			work += 1
	var seen := {}
	for move in intent.moves:
		if not move is Dictionary or move.size() != 4 or not _flow_owner(move.get("from")) or not _flow_owner(move.get("to")) or move["from"] == move.to: return false
		if not move.get("resource") is String or move.resource.is_empty() or move.resource.length() > 64 or not _quantity(move.get("amount")) or move.amount <= 0: return false
		var key := str([move["from"],move.to,move.resource])
		if seen.has(key): return false
		seen[key] = true
		work += 1
	return work > 0

func _flow_owner(owner: Variant) -> bool:
	return owner is String and not owner.is_empty() and owner.length() <= 64 and _inventories.has(owner)

func snapshot() -> Dictionary:
	return {"sources":_sources.duplicate(true),"inventories":_inventories.duplicate(true),"capacities":_capacities.duplicate(true),"reservations":_reservations.duplicate(true),"cargo":_cargo.duplicate(true),"receipts":_receipts.duplicate(true),"totals":_totals.duplicate(true),"streams":_streams.duplicate(true),"flows":_flows.duplicate(true)}

func _assign(saved: Dictionary) -> void:
	_sources = saved.sources.duplicate(true)
	_inventories = saved.inventories.duplicate(true)
	_capacities = saved.capacities.duplicate(true)
	_reservations = saved.reservations.duplicate(true)
	_cargo = saved.cargo.duplicate(true)
	_receipts = saved.receipts.duplicate(true)
	_totals = saved.totals.duplicate(true)
	_streams = saved.get("streams", {}).duplicate(true)
	_flows = saved.get("flows", {}).duplicate(true)

func restore(saved: Dictionary) -> bool:
	if not Memory._plain(saved): return false
	for key in ["sources","inventories","capacities","reservations","cargo","receipts","totals"]:
		if not saved.get(key) is Dictionary: return false
	if not saved.get("streams", {}) is Dictionary or not saved.get("flows",{}) is Dictionary: return false
	var old := snapshot()
	_assign(saved)
	if not audit().ok:
		_assign(old)
		return false
	return true

func audit() -> Dictionary:
	var observed: Dictionary = {}
	if _streams.size()+_flows.size() > MAX_STREAMS: return {"ok":false,"code":"streams"}
	for id in _flows:
		if not _flow_valid(id,_flows[id]): return {"ok":false,"code":"flows"}
	for id in _streams:
		var stream: Variant = _streams[id]
		if not id is String or id.is_empty() or id.length() > 64 or not stream is Dictionary or stream.size() not in [4,5]: return {"ok":false,"code":"streams"}
		if not stream.get("owner") is String or stream.owner.is_empty() or stream.owner.length() > 64 or not _inventories.has(stream.owner): return {"ok":false,"code":"streams"}
		if not _quantity(stream.get("sequence")) or stream.sequence < 1: return {"ok":false,"code":"streams"}
		if not _amounts(stream.get("costs")) or not _amounts(stream.get("outputs")) or stream.costs.size() > 8 or stream.outputs.size() > 8 or (stream.costs.is_empty() and stream.outputs.is_empty()): return {"ok":false,"code":"streams"}
		if stream.size() == 5 and (not stream.get("shared") is Dictionary or stream.shared.is_empty() or not _valid_stream_sources(stream.owner,stream.costs,stream.shared)): return {"ok":false,"code":"streams"}
		for amount in stream.costs.values()+stream.outputs.values():
			if amount <= 0: return {"ok":false,"code":"streams"}
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
