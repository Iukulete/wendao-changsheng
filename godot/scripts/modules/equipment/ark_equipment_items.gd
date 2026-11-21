extends RefCounted
## Each non-stackable instance has one authoritative container or owner/slot address.
## Definitions describe use; the fixed legacy mint map and Gear streams prove ownership.
const Economy = preload("res://scripts/modules/economy/ark_economy.gd")
const Memory = preload("res://scripts/modules/memory/ark_memory.gd")
const Legacy = preload("res://scripts/modules/leisure/ark_fishing_equipment.gd")
const VERSION := 2
const MAX_REVISION := 1000000000
const BAG := {"kind":"container", "id":"player.bag"}
const BOX := {"kind":"container", "id":"ark.storage"}
const TOOL := {"kind":"slot", "owner":"player", "slot":"tool"}
const CONTAINERS := ["player.bag", "ark.storage"]
const SLOTS := {"player":["tool"]}
const DEFINITIONS := {
	"rod.basic":{"profile":"basic", "slot":"tool"},
	"rod.light":{"profile":"light", "slot":"tool"},
	"rod.resilient":{"profile":"resilient", "slot":"tool"},
}
const LEGACY_MINTS := {
	"legacy.rod.basic":"rod.basic",
	"legacy.rod.light":"rod.light",
	"legacy.rod.resilient":"rod.resilient",
}
var _state: Dictionary = {}

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= MAX_REVISION and value == floor(float(value))

static func asset_id(profile_id: String) -> String:
	for id in LEGACY_MINTS:
		if DEFINITIONS[LEGACY_MINTS[id]].profile == profile_id: return id
	return ""

static func _valid_economy(economy: Dictionary) -> bool:
	if not Legacy.valid_economy(economy): return false
	var ledger := Economy.new()
	return ledger.restore(economy) and Memory.facts_equal(ledger.snapshot(), economy)

static func migrate_legacy(economy: Dictionary, memories: Dictionary) -> Dictionary:
	# The pre-46 caller normalizes old modules first. Never normalize v2 item data.
	if not _valid_economy(economy) or not Legacy.matches_bundle({"economy":economy, "memories":memories}): return {}
	var history := Memory.new()
	if not history.restore(memories) or not Memory.facts_equal(history.snapshot(), memories): return {}
	var selected_profile := Legacy.selected(history)
	if selected_profile not in Legacy.IDS: return {}
	var instances: Dictionary = {}
	for id in LEGACY_MINTS:
		var definition: String = LEGACY_MINTS[id]
		var profile_id: String = DEFINITIONS[definition].profile
		if profile_id != "basic" and not economy.streams.has(Legacy.stream(profile_id)): continue
		instances[id] = {"definition":definition, "address":(TOOL if profile_id == selected_profile else BAG).duplicate(true)}
	return {"version":VERSION, "revision":0, "instances":instances}

static func _future_address(where: Variant) -> bool:
	if not where is Dictionary: return false
	var kind = where.get("kind")
	if not kind is String: return false
	if kind not in ["container", "slot"]: return true
	if kind == "container":
		return where.get("id") is String and where.id not in CONTAINERS
	if kind == "slot":
		if where.get("owner") is String and not SLOTS.has(where.owner): return true
		# All currently understood owners expose only the tool namespace.
		if where.get("slot") is String and where.slot not in SLOTS.player: return true
	return false

static func _future_marker(data: Variant) -> bool:
	if not data is Dictionary: return false
	var version = data.get("version")
	if (version is int or version is float) and is_finite(float(version)) and version == floor(float(version)):
		# v1 was an unpublished location-string experiment, not a migration source.
		if version == 1 or version > VERSION: return true
	var instances = data.get("instances")
	if instances is Dictionary:
		for row in instances.values():
			if not row is Dictionary: continue
			if row.get("definition") is String and row.definition not in DEFINITIONS: return true
			if _future_address(row.get("address")): return true
	return false

static func _valid_address(where: Variant) -> bool:
	if not where is Dictionary or not where.get("kind") is String: return false
	if where.kind == "container":
		return where.size() == 2 and where.get("id") is String and where.id in CONTAINERS
	if where.kind == "slot":
		return where.size() == 3 and where.get("owner") is String and SLOTS.has(where.owner) and where.get("slot") is String and where.slot in SLOTS[where.owner]
	return false

static func _accepts_slot(definition: String, where: Dictionary) -> bool:
	return where.kind != "slot" or DEFINITIONS[definition].slot == where.slot

static func compatibility(data: Variant, economy: Variant, box_built: bool) -> Dictionary:
	# Scan every recognized future marker before rejecting any corrupt field.
	# This must preserve a future primary save rather than invite backup recovery.
	if _future_marker(data): return {"ok":false, "code":"unsupported_version"}
	if not data is Dictionary or not economy is Dictionary: return {"ok":false, "code":"invalid_state"}
	if data.size() != 3 or not Memory.facts_equal(data.get("version"), VERSION) or not _integer(data.get("revision")) or not data.get("instances") is Dictionary: return {"ok":false, "code":"invalid_state"}
	if not _valid_economy(economy): return {"ok":false, "code":"invalid_state"}
	var expected: Array = []
	for id in LEGACY_MINTS:
		var profile_id: String = DEFINITIONS[LEGACY_MINTS[id]].profile
		if profile_id == "basic" or economy.streams.has(Legacy.stream(profile_id)): expected.append(id)
	var occupied: Dictionary = {}
	for id in data.instances:
		var row = data.instances[id]
		if not id is String or id not in LEGACY_MINTS or not row is Dictionary: return {"ok":false, "code":"invalid_state"}
		if row.size() != 2 or not row.get("definition") is String or row.definition != LEGACY_MINTS[id] or not _valid_address(row.get("address")): return {"ok":false, "code":"invalid_state"}
		if id not in expected or not _accepts_slot(row.definition, row.address): return {"ok":false, "code":"invalid_state"}
		var where: Dictionary = row.address
		if Memory.facts_equal(where, BOX) and not box_built: return {"ok":false, "code":"invalid_state"}
		if where.kind == "slot":
			# Uniqueness belongs to an owner/slot pair, not a global equipped count.
			if not occupied.has(where.owner): occupied[where.owner] = {}
			if occupied[where.owner].has(where.slot): return {"ok":false, "code":"invalid_state"}
			occupied[where.owner][where.slot] = id
	if data.instances.size() != expected.size(): return {"ok":false, "code":"invalid_state"}
	return {"ok":true}

static func check_state(state: Dictionary) -> Dictionary:
	var modules = state.get("modules")
	var contains_items: bool = modules is Dictionary and modules.has("equipment_items")
	if contains_items and _future_marker(modules.equipment_items): return {"ok":false, "code":"unsupported_version"}
	var schema = state.get("schema_version")
	if not _integer(schema): return {"ok":false, "code":"invalid_state"}
	if schema < 46:
		return {"ok":false, "code":"unsupported_version"} if contains_items else {"ok":true}
	if not contains_items or not state.get("storage_built") is bool: return {"ok":false, "code":"invalid_state"}
	return compatibility(modules.equipment_items, modules.get("economy"), state.storage_built)

func restore(data: Dictionary, economy: Dictionary, box_built: bool) -> bool:
	if not compatibility(data, economy, box_built).get("ok", false): return false
	_state = data.duplicate(true)
	return true

func snapshot() -> Dictionary: return _state.duplicate(true)
func revision() -> int: return int(_state.get("revision", 0))

func profile(id: String) -> String:
	var definition: String = _state.get("instances", {}).get(id, {}).get("definition", "")
	return str(DEFINITIONS.get(definition, {}).get("profile", ""))

func address(id: String) -> Dictionary:
	return _state.get("instances", {}).get(id, {}).get("address", {}).duplicate(true)

func selected(slot: String = "tool") -> String:
	var wanted := {"kind":"slot", "owner":"player", "slot":slot}
	for id in _state.get("instances", {}):
		if Memory.facts_equal(address(id), wanted): return profile(id)
	return ""

func location(id: String) -> String:
	# Read-only view aliases. They are never accepted as command/save authority.
	var where := address(id)
	if Memory.facts_equal(where, BAG): return "bag"
	if Memory.facts_equal(where, BOX): return "box"
	if Memory.facts_equal(where, TOOL): return "equipment"
	return ""

func at(where: String) -> Array:
	var result: Array = []
	if where not in ["bag", "box", "equipment"]: return result
	for id in _state.get("instances", {}):
		if location(id) == where: result.append(id)
	result.sort()
	return result

func _space_ok(data: Dictionary, capacities: Dictionary) -> bool:
	# No new gameplay cap. Optional QA/future limits use exact container IDs.
	for container_id in capacities:
		if container_id not in CONTAINERS or not _integer(capacities[container_id]): return false
	for container_id in CONTAINERS:
		var count := 0
		for row in data.instances.values():
			if row.address.kind == "container" and row.address.id == container_id: count += 1
		if count > capacities.get(container_id, MAX_REVISION): return false
	return true

func move(id: String, source: Dictionary, destination: Dictionary, expected_revision: int, economy: Dictionary, box_built: bool, capacities: Dictionary = {}) -> Dictionary:
	if not compatibility(_state, economy, box_built).get("ok", false): return {"ok":false, "code":"invalid_items"}
	if expected_revision != revision(): return {"ok":false, "code":"stale"}
	if id not in _state.instances or not _valid_address(source) or not _valid_address(destination): return {"ok":false, "code":"invalid_item"}
	if not Memory.facts_equal(address(id), source): return {"ok":false, "code":"moved"}
	if Memory.facts_equal(source, destination): return {"ok":true, "duplicate":true}
	if revision() >= MAX_REVISION: return {"ok":false, "code":"operation_limit"}
	if (Memory.facts_equal(source, BOX) or Memory.facts_equal(destination, BOX)) and not box_built: return {"ok":false, "code":"no_storage"}
	if not _accepts_slot(_state.instances[id].definition, destination): return {"ok":false, "code":"invalid_item"}
	# Chest presence/UI mode does not restrict equipping carried items.
	if (Memory.facts_equal(source, BOX) and destination.kind == "slot") or (source.kind == "slot" and Memory.facts_equal(destination, BOX)): return {"ok":false, "code":"take_out_first"}
	var next := snapshot()
	if destination.kind == "slot":
		# The displaced item returns to the initiating bag. Only this exact slot swaps.
		if not Memory.facts_equal(source, BAG): return {"ok":false, "code":"invalid_item"}
		for other in next.instances:
			if Memory.facts_equal(next.instances[other].address, destination): next.instances[other].address = source.duplicate(true)
	next.instances[id].address = destination.duplicate(true)
	next.revision = revision() + 1
	if not _space_ok(next, capacities): return {"ok":false, "code":"capacity"}
	if not compatibility(next, economy, box_built).get("ok", false): return {"ok":false, "code":"invalid_items"}
	_state = next
	return {"ok":true, "duplicate":false}

func craft(economy: RefCounted, profile_id: String, box_built: bool, expected_revision: int, capacities: Dictionary = {}, use_storage: bool = true) -> Dictionary:
	var before: Dictionary = economy.snapshot()
	if not compatibility(_state, before, box_built).get("ok", false): return {"ok":false, "code":"invalid_items"}
	if expected_revision != revision(): return {"ok":false, "code":"stale"}
	if profile_id not in ["light", "resilient"]: return {"ok":false, "code":"unknown_gear"}
	var id := asset_id(profile_id)
	if _state.instances.has(id): return {"ok":true, "duplicate":true}
	if revision() >= MAX_REVISION: return {"ok":false, "code":"operation_limit"}
	var next := snapshot()
	next.instances[id] = {"definition":LEGACY_MINTS[id], "address":BAG.duplicate(true)}
	next.revision = revision() + 1
	if not _space_ok(next, capacities): return {"ok":false, "code":"capacity"}
	var staged := Economy.new()
	if not staged.restore(before): return {"ok":false, "code":"invalid_ledger"}
	# Acquisition remains the original exact two-wood Gear transaction, not a definition field.
	var paid: Dictionary = Legacy.craft(staged, profile_id, box_built and use_storage)
	if not paid.get("ok", false) or paid.get("duplicate", false): return paid
	if not staged.audit().get("ok", false) or not compatibility(next, staged.snapshot(), box_built).get("ok", false): return {"ok":false, "code":"invalid_ledger"}
	if not Memory.facts_equal(economy.snapshot(), before): return {"ok":false, "code":"ledger_changed"}
	if not economy.restore(staged.snapshot()): return {"ok":false, "code":"commit_failed"}
	_state = next
	return {"ok":true, "duplicate":false}
