extends RefCounted
## Commit boundary for existing placement validators and material accounting.
## No preview, Node, collision, or UI state is persisted here. The caller applies
## committed presentation only when ok AND NOT duplicate, then saves the session.
const Memory = preload("res://scripts/modules/memory/ark_memory.gd")
var _economy: RefCounted
var _receipts: Dictionary = {}
var _busy := false
var _sequence := 0
var _structures: Dictionary = {}
var _baseline_structures: Dictionary = {}

func configure(economy: RefCounted) -> void:
	_economy = economy

func commit(operation_id: String, owner: String, costs: Dictionary, validate: Callable, facts: Dictionary = {}) -> Dictionary:
	return _transaction("build", operation_id, owner, costs, validate, facts)

func refund(operation_id: String, owner: String, amounts: Dictionary, validate: Callable, facts: Dictionary = {}) -> Dictionary:
	return _transaction("dismantle", operation_id, owner, amounts, validate, facts)

func move(operation_id: String, validate: Callable, facts: Dictionary = {}) -> Dictionary:
	return _transaction("move", operation_id, "", {}, validate, facts)

func _transaction(kind: String, operation_id: String, owner: String, amounts: Dictionary, validate: Callable, facts: Dictionary) -> Dictionary:
	if _busy or operation_id.is_empty() or not Memory._plain(facts) or not _valid_structure_facts(facts) or not _valid_amounts(amounts):
		return {"ok": false, "code": "invalid_command"}
	var command := {"kind": kind, "owner": owner, "amounts": amounts.duplicate(true), "facts": facts.duplicate(true)}
	if _receipts.has(operation_id):
		var previous: Dictionary = _receipts[operation_id].duplicate(true)
		previous.erase("sequence")
		if previous != command:
			return {"ok": false, "code": "operation_conflict"}
		return {"ok": true, "duplicate": true, "facts": facts.duplicate(true)}
	if not validate.is_valid() or (kind != "move" and (_economy == null or owner.is_empty())):
		return {"ok": false, "code": "invalid_dependencies"}
	if kind != "move" and _economy.snapshot().receipts.has("construction:" + operation_id):
		return {"ok": false, "code": "orphan_economic_receipt"}
	_busy = true
	var accepted: Variant = validate.call()
	if not accepted is bool or not accepted:
		_busy = false
		return {"ok": false, "code": "placement_rejected"}
	var result: Dictionary = {"ok": true}
	if kind == "build":
		result = _economy.consume(owner, amounts, "construction:" + operation_id)
	elif kind == "dismantle":
		# Must happen before the caller removes support geometry or evacuates actors.
		if not _economy.can_accept(owner, amounts):
			_busy = false
			return {"ok": false, "code": "capacity"}
		result = _economy.input_many(owner, amounts, "construction:" + operation_id)
	if not result.get("ok", false):
		_busy = false
		return result.duplicate(true)
	_sequence += 1
	command["sequence"] = _sequence
	_receipts[operation_id] = command
	for id in _project(facts):
		_structures[id] = _project(facts)[id]
	_busy = false
	return {"ok": true, "duplicate": false, "facts": facts.duplicate(true)}

func import_legacy(structures: Dictionary) -> bool:
	if _busy or not _receipts.is_empty() or not _structures.is_empty() or not Memory._plain(structures) or not _valid_structure_facts({"structures": structures}):
		return false
	_baseline_structures = structures.duplicate(true)
	_structures = structures.duplicate(true)
	return true

func state() -> Dictionary:
	return _structures.duplicate(true)

func structure(id: String) -> Dictionary:
	return _structures.get(id, {}).duplicate(true)

func snapshot() -> Dictionary:
	return {"version": 1, "sequence": _sequence, "receipts": _receipts.duplicate(true), "structures": _structures.duplicate(true), "baseline_structures": _baseline_structures.duplicate(true)}

func restore(saved: Dictionary) -> bool:
	if _busy or saved.get("version", 0) != 1 or not saved.get("receipts") is Dictionary or not Memory._plain(saved):
		return false
	var baseline: Variant = saved.get("baseline_structures", {})
	if not baseline is Dictionary or not _valid_structure_facts({"structures": baseline}):
		return false
	var structures: Dictionary = baseline.duplicate(true)
	var ordered: Array[Dictionary] = []
	for id in saved.receipts:
		var entry: Variant = saved.receipts[id]
		if id.is_empty() or not entry is Dictionary:
			return false
		if entry.get("kind", "") not in ["build", "dismantle", "move"] or not entry.get("owner") is String or not entry.get("facts") is Dictionary or not entry.get("amounts") is Dictionary:
			return false
		if not _valid_structure_facts(entry.facts) or not _valid_amounts(entry.amounts) or (entry.kind != "move" and entry.owner.is_empty()):
			return false
		if not Memory._integer(entry.get("sequence")) or int(entry.sequence) < 1:
			return false
		ordered.append(entry)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.sequence) < int(b.sequence))
	var sequence := 0
	for entry in ordered:
		sequence += 1
		if int(entry.sequence) != sequence:
			return false
		for structure_id in _project(entry.facts):
			structures[structure_id] = _project(entry.facts)[structure_id]
	if saved.get("sequence", sequence) != sequence:
		return false
	if saved.get("structures", structures) != structures:
		return false
	if not _economic_receipts_match(saved.receipts):
		return false
	_sequence = sequence
	_baseline_structures = baseline.duplicate(true)
	_structures = structures
	_receipts = saved.receipts.duplicate(true)
	return true

func audit() -> Dictionary:
	return {"ok": _economic_receipts_match(_receipts)}

func _economic_receipts_match(receipts: Dictionary) -> bool:
	var economic: Dictionary = {} if _economy == null else _economy.snapshot().receipts
	for id in receipts:
		if receipts[id].kind != "move" and not economic.has("construction:" + id):
			return false
	for id in economic:
		if str(id).begins_with("construction:"):
			var construction_id := str(id).trim_prefix("construction:")
			if not receipts.has(construction_id) or receipts[construction_id].kind == "move":
				return false
	return true

static func _valid_amounts(amounts: Dictionary) -> bool:
	for resource in amounts:
		if not resource is String or resource.is_empty() or not Memory._integer(amounts[resource]):
			return false
	return true

static func _project(facts: Dictionary) -> Dictionary:
	if facts.has("structures"):
		return facts.structures.duplicate(true)
	if facts.has("structure_id"):
		return {facts.structure_id: facts.duplicate(true)}
	return {}

static func _valid_structure_facts(facts: Dictionary) -> bool:
	if facts.has("structures") and facts.has("structure_id"):
		return false
	if facts.has("structures"):
		if not facts.structures is Dictionary:
			return false
		for id in facts.structures:
			if not id is String or id.is_empty() or not _valid_structure(facts.structures[id]):
				return false
		return true
	if not facts.has("structure_id"):
		return true
	return facts.structure_id is String and not facts.structure_id.is_empty() and _valid_structure(facts)

static func _valid_structure(value: Variant) -> bool:
	if not value is Dictionary or not value.get("built") is bool or not value.get("position") is Dictionary:
		return false
	for axis in ["x", "y", "z"]:
		var number: Variant = value.position.get(axis)
		if not (number is int or number is float) or not is_finite(float(number)):
			return false
	return true
