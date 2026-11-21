extends RefCounted
## Paid fishing authority. Only fixed counters are saved; tickets never are.
## The caller owns tool/deck/modal checks, battle rules and honest save feedback.
const Economy = preload("res://scripts/modules/economy/ark_economy.gd")
const Memory = preload("res://scripts/modules/memory/ark_memory.gd")
const ATTEMPT := "bait_fishing:attempt_v1"
const CATCH := "bait_fishing:catch_v1"
const COOK := "bait_cooking:large_fish_soup_v1"
const RESOURCE := "large_fish"
const SCHEMA := 47
const LIMIT := 1000000000
const DEPOSIT := "home_food:deposit"
const WITHDRAW := "home_food:withdraw_large_fish"
var _ticket: RefCounted
var _economy: RefCounted
var _attempt_sequence := 0
var _catch_sequence := 0

func active() -> bool: return _ticket != null

## Preflight both payment and a hypothetical successful reward. In particular,
## two missing stream IDs need two free slots, not just one payment slot.
## No catch is persisted before success and no receipt is added per cast.
func begin(economy: RefCounted) -> Dictionary:
	if active(): return _failure("active_ticket")
	var before: Dictionary = economy.snapshot()
	var staged := Economy.new()
	if not staged.restore(before) or not _valid_ledger(before): return _failure("invalid_ledger")
	var attempt_sequence := _sequence(before, ATTEMPT) + 1
	var catch_sequence := _sequence(before, CATCH) + 1
	var paid := _apply(staged, ATTEMPT, attempt_sequence, {"shellfish":1}, {})
	if not paid.get("ok", false): return paid
	var paid_state: Dictionary = staged.snapshot()
	var reward := _apply(staged, CATCH, catch_sequence, {}, {RESOURCE:1})
	if not reward.get("ok", false): return reward
	if not staged.audit().get("ok", false) or not _valid_ledger(staged.snapshot()): return _failure("invalid_ledger")
	if not Memory.facts_equal(economy.snapshot(), before): return _failure("ledger_changed")
	if not economy.restore(paid_state): return _failure("commit_failed")
	_ticket = RefCounted.new()
	_economy = economy
	_attempt_sequence = attempt_sequence
	_catch_sequence = catch_sequence
	return {"ok":true, "duplicate":false, "ticket":_ticket, "attempt_sequence":attempt_sequence, "catch_sequence":catch_sequence}

## Every valid settlement request closes its ticket, including capacity/ledger
## failure. Repeated result callbacks cannot retry it or produce another reward.
func settle(economy: RefCounted, ticket: Variant) -> Dictionary:
	if not _owns(ticket) or economy != _economy: return _failure("stale_ticket")
	var expected_attempt := _attempt_sequence
	var expected_catch := _catch_sequence
	reset()
	var before: Dictionary = economy.snapshot()
	if not _valid_ledger(before): return _failure("invalid_ledger")
	if _sequence(before, ATTEMPT) != expected_attempt or _sequence(before, CATCH) + 1 != expected_catch:
		return _failure("stale_ticket")
	return _transaction(economy, CATCH, expected_catch, {}, {RESOURCE:1})

func cancel(ticket: Variant) -> Dictionary:
	if not _owns(ticket): return _failure("stale_ticket")
	reset()
	return {"ok":true, "duplicate":false}

## Call only when the cast closes or an actual load has been accepted. A refused
## load must preserve the live ticket, just like its still-running battle.
func reset() -> void:
	_ticket = null
	_economy = null
	_attempt_sequence = 0
	_catch_sequence = 0

## Read-only evidence for the battle adapter. Identity stays opaque; modifying
## this returned dictionary cannot alter the authoritative transient counters.
func ticket_info(economy: RefCounted, ticket: Variant) -> Dictionary:
	if not _owns(ticket) or economy != _economy: return {}
	return {"attempt_sequence":_attempt_sequence, "catch_sequence":_catch_sequence}

func _owns(ticket: Variant) -> bool:
	return _ticket != null and ticket is RefCounted and ticket == _ticket

static func next_cook(economy: RefCounted) -> int:
	var saved: Dictionary = economy.snapshot()
	return _sequence(saved, COOK) + 1 if _valid_ledger(saved) else 0

static func cook(economy: RefCounted, sequence: int) -> Dictionary:
	return _transaction(economy, COOK, sequence, {RESOURCE:1}, {"stew_servings":3})

static func _transaction(economy: RefCounted, id: String, sequence: int, costs: Dictionary, outputs: Dictionary) -> Dictionary:
	var before: Dictionary = economy.snapshot()
	var staged := Economy.new()
	if not staged.restore(before) or not _valid_ledger(before): return _failure("invalid_ledger")
	var result := _apply(staged, id, sequence, costs, outputs)
	if not result.get("ok", false): return result
	if result.get("duplicate", false): return result
	var after: Dictionary = staged.snapshot()
	if not staged.audit().get("ok", false) or not _valid_ledger(after): return _failure("invalid_ledger")
	if not Memory.facts_equal(economy.snapshot(), before): return _failure("ledger_changed")
	if not economy.restore(after): return _failure("commit_failed")
	return result

static func _apply(staged: RefCounted, id: String, sequence: int, costs: Dictionary, outputs: Dictionary) -> Dictionary:
	var saved: Dictionary = staged.snapshot()
	# A legitimate exact duplicate stays harmless even at a cumulative limit.
	if sequence != _sequence(saved, id):
		for resource in costs:
			if int(saved.totals.get(resource, {}).get("consumed", 0)) > LIMIT-int(costs[resource]): return _failure("quantity_limit")
		for resource in outputs:
			if int(saved.totals.get(resource, {}).get("input", 0)) > LIMIT-int(outputs[resource]): return _failure("quantity_limit")
	return staged.process_stream("player", id, sequence, costs, outputs)

static func _failure(code: String) -> Dictionary: return {"ok":false, "code":code}

static func _sequence(e: Dictionary, id: String) -> int:
	var streams: Variant = e.get("streams", {})
	if not streams is Dictionary: return 0
	var row: Variant = streams.get(id, {})
	return int(row.get("sequence", 0)) if row is Dictionary and _quantity(row.get("sequence", 0)) else 0

static func _quantity(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= LIMIT and value == floor(float(value))

static func _recipe(e: Dictionary, id: String, costs: Dictionary, outputs: Dictionary) -> bool:
	if not e.streams.has(id): return true
	var row: Variant = e.streams[id]
	if not row is Dictionary or not _quantity(row.get("sequence")) or row.sequence < 1: return false
	return Memory.facts_equal(row, {"owner":"player", "sequence":int(row.sequence), "costs":costs, "outputs":outputs})

## Strict new-domain facts, plus a complete Economy audit. Ordinary fish is
## deliberately not recategorized; its original validator remains authoritative.
static func _valid_ledger(e: Dictionary) -> bool:
	var canonical := Economy.new()
	if not canonical.restore(e): return false
	e = canonical.snapshot()
	if _future_economy(e): return false
	if not _recipe(e, ATTEMPT, {"shellfish":1}, {}) or not _recipe(e, CATCH, {}, {RESOURCE:1}) or not _recipe(e, COOK, {RESOURCE:1}, {"stew_servings":3}): return false
	var paid := _sequence(e, ATTEMPT)
	var caught := _sequence(e, CATCH)
	var cooked_count := _sequence(e, COOK)
	if caught > paid or cooked_count > caught or cooked_count > LIMIT / 3: return false
	var count := 0
	var has_resource := false
	for owner in e.inventories:
		var inventory: Dictionary = e.inventories[owner]
		if not inventory.has(RESOURCE): continue
		has_resource = true
		if owner not in ["player", "storage_food"]: return false
		count += int(inventory[RESOURCE])
	for field in ["sources", "cargo"]:
		for row in e[field].values():
			if row.resource == RESOURCE: return false
	for id in e.get("streams", {}):
		var row: Dictionary = e.streams[id]
		if id not in [CATCH, COOK] and (row.costs.has(RESOURCE) or row.outputs.has(RESOURCE)): return false
	for id in e.get("flows", {}):
		var row: Dictionary = e.flows[id]
		if _reserved_id(id): return false
		for field in ["costs", "outputs"]:
			for amounts in row[field].values():
				if amounts.has(RESOURCE): return false
		for move in row.moves:
			if move.resource != RESOURCE: continue
			has_resource = true
			if id not in [DEPOSIT, WITHDRAW]: return false
			if move.get("from") != ("player" if id == DEPOSIT else "storage_food") or move.to != ("storage_food" if id == DEPOSIT else "player"): return false
			if move.amount < 1 or move.amount > 8 or (id == WITHDRAW and (move.amount != 1 or row.moves.size() != 1)): return false
	if count + cooked_count != caught: return false
	if caught == 0:
		if has_resource or e.totals.has(RESOURCE): return false
	elif not Memory.facts_equal(e.totals.get(RESOURCE), {"initial":0, "input":caught, "consumed":cooked_count, "outflow":0}): return false
	if int(e.totals.get("shellfish", {}).get("consumed", 0)) < paid: return false
	if int(e.totals.get("stew_servings", {}).get("input", 0)) < 3*cooked_count: return false
	return true

static func matches_save(state: Dictionary) -> bool: return check_state(state).get("ok", false)

## Unknown reserved facts must be classified before unrelated corruption, even
## if somebody labels them with an old schema. The caller combines this result
## with other domain compatibility checks before attempting backup recovery.
static func check_state(state: Dictionary) -> Dictionary:
	var modules: Variant = state.get("modules", {})
	if modules is Dictionary:
		for id in modules:
			if _reserved_id(str(id)) or str(id) in ["bait_fishing", "bait_cooking"]: return _failure("unsupported_version")
		if modules.get("economy") is Dictionary and _future_economy(modules.economy): return _failure("unsupported_version")
	var schema: Variant = state.get("schema_version", 0)
	if (schema is int or schema is float) and is_finite(float(schema)) and schema > SCHEMA and schema == floor(float(schema)): return _failure("unsupported_version")
	if not _quantity(schema) or not modules is Dictionary: return _failure("invalid_state")
	var e: Variant = modules.get("economy", {})
	if not e is Dictionary: return _failure("invalid_state")
	var has_data := _has_data(e)
	if not has_data and schema < SCHEMA: return {"ok":true}
	if schema < SCHEMA or not _valid_ledger(e): return _failure("invalid_state")
	# Work only with canonical dictionaries after the complete typed audit.
	var canonical := Economy.new()
	if not canonical.restore(e): return _failure("invalid_state")
	e = canonical.snapshot()
	var kitchen: Variant = state.get("kitchen", {})
	if not kitchen is Dictionary or not _quantity(kitchen.get("completed", 0)): return _failure("invalid_state")
	var completed := int(kitchen.get("completed", 0))
	var old_cook: Variant = e.streams.get("manual_cooking:fish_soup", {})
	if not old_cook is Dictionary or not _quantity(old_cook.get("sequence", 0)): return _failure("invalid_state")
	var shell_total := int(e.totals.get("shellfish", {}).get("consumed", 0))
	var soup_total := int(e.totals.get("stew_servings", {}).get("input", 0))
	if shell_total < completed+_sequence(e, ATTEMPT): return _failure("invalid_state")
	if soup_total < completed+int(old_cook.get("sequence", 0))+3*_sequence(e, COOK): return _failure("invalid_state")
	return {"ok":true}

static func _reserved_id(id: String) -> bool:
	return id.begins_with("bait_fishing:") or id.begins_with("bait_cooking:")

static func _future_resource(resource: Variant) -> bool:
	return resource is String and resource != RESOURCE and (resource.begins_with("large_fish:") or resource.begins_with("large_fish_"))

static func _resource_keys_future(amounts: Variant) -> bool:
	if not amounts is Dictionary: return false
	for resource in amounts:
		if _future_resource(resource): return true
	return false

static func _future_economy(e: Dictionary) -> bool:
	for field in ["streams", "flows"]:
		var rows: Variant = e.get(field, {})
		if not rows is Dictionary: continue
		for id in rows:
			if str(id).begins_with(WITHDRAW) and (field != "flows" or id != WITHDRAW): return true
			if _reserved_id(str(id)) and (field != "streams" or id not in [ATTEMPT, CATCH, COOK]): return true
			var row: Variant = rows[id]
			if not row is Dictionary: continue
			for group in ["costs", "outputs", "shared"]:
				var amounts: Variant = row.get(group, {})
				if _resource_keys_future(amounts): return true
				if field == "flows" and amounts is Dictionary:
					for nested in amounts.values():
						if _resource_keys_future(nested): return true
			if row.get("moves") is Array:
				for move in row.moves:
					if move is Dictionary and _future_resource(move.get("resource")): return true
	var inventories: Variant = e.get("inventories", {})
	if inventories is Dictionary:
		for amounts in inventories.values():
			if _resource_keys_future(amounts): return true
	if _resource_keys_future(e.get("totals", {})): return true
	for field in ["sources", "cargo"]:
		var rows: Variant = e.get(field, {})
		if rows is Dictionary:
			for row in rows.values():
				if row is Dictionary and _future_resource(row.get("resource")): return true
	return false

static func _has_data(e: Dictionary) -> bool:
	for field in ["streams", "flows"]:
		var rows: Variant = e.get(field, {})
		if not rows is Dictionary: continue
		for id in rows:
			if _reserved_id(str(id)) or str(id).begins_with(WITHDRAW): return true
			var row: Variant = rows[id]
			if not row is Dictionary: continue
			for group in ["costs", "outputs", "shared"]:
				var amounts: Variant = row.get(group, {})
				if amounts is Dictionary:
					if amounts.has(RESOURCE): return true
					for nested in amounts.values():
						if nested is Dictionary and nested.has(RESOURCE): return true
			if row.get("moves") is Array:
				for move in row.moves:
					if move is Dictionary and move.get("resource") is String and move.resource == RESOURCE: return true
	var inventories: Variant = e.get("inventories", {})
	if inventories is Dictionary:
		for amounts in inventories.values():
			if amounts is Dictionary and amounts.has(RESOURCE): return true
	if e.get("totals") is Dictionary and e.totals.has(RESOURCE): return true
	for field in ["sources", "cargo"]:
		var rows: Variant = e.get(field, {})
		if rows is Dictionary:
			for row in rows.values():
				if row is Dictionary and row.get("resource") is String and row.resource == RESOURCE: return true
	return false
