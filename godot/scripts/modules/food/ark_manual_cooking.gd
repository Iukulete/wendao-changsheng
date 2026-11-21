extends RefCounted
## Manual fish recipe only; resident shellfish orders keep their own ledger.
const Memory = preload("res://scripts/modules/memory/ark_memory.gd")
const STREAM := "manual_cooking:fish_soup"

static func next(economy: RefCounted) -> int:
	return int(economy.snapshot().get("streams", {}).get(STREAM, {}).get("sequence", 0)) + 1

static func cook(economy: RefCounted, sequence: int) -> Dictionary:
	return economy.process_stream("player", STREAM, sequence, {"fish":1}, {"stew_servings":1})

static func cooked(state: Dictionary) -> int:
	return int(state.get("modules", {}).get("economy", {}).get("streams", {}).get(STREAM, {}).get("sequence", 0))

static func matches_save(state: Dictionary) -> bool:
	var modules: Variant = state.get("modules", {})
	if not modules is Dictionary: return false
	var economy: Variant = modules.get("economy", {})
	if not economy is Dictionary or not economy.get("streams", {}) is Dictionary or not economy.get("flows", {}) is Dictionary: return false
	var streams: Dictionary = economy.get("streams", {})
	for id in streams:
		if str(id).begins_with("manual_cooking:") and id != STREAM: return false
	for id in economy.get("flows", {}):
		if str(id).begins_with("manual_cooking:"): return false
		var flow: Variant = economy.flows[id]
		if not flow is Dictionary or not flow.get("costs", {}) is Dictionary or not flow.get("outputs", {}) is Dictionary: return false
		# Fish may move between the existing owners, never be produced/consumed by
		# an unregistered flow which would evade the precise cooking stream.
		for group in [flow.get("costs", {}), flow.get("outputs", {})]:
			for amounts in group.values():
				if not amounts is Dictionary or amounts.has("fish"): return false
	if not streams.has(STREAM): return true
	if not Memory._integer(state.get("schema_version")) or int(state.schema_version) < 45: return false
	var recipe: Variant = streams[STREAM]
	if not recipe is Dictionary or recipe.size() != 4 or not Memory._integer(recipe.get("sequence")) or recipe.sequence < 1 or recipe.sequence > 1000000000: return false
	if not Memory.facts_equal(recipe, {"owner":"player", "sequence":int(recipe.sequence), "costs":{"fish":1}, "outputs":{"stew_servings":1}}): return false
	if not economy.get("totals", {}) is Dictionary: return false
	var soup: Variant = economy.get("totals", {}).get("stew_servings", {})
	if not soup is Dictionary or not Memory._integer(soup.get("input")): return false
	var kitchen: Variant = state.get("kitchen", {})
	if not kitchen is Dictionary or not Memory._integer(kitchen.get("completed", 0)) or kitchen.get("completed", 0) < 0: return false
	return int(soup.input) >= int(recipe.sequence) + int(kitchen.get("completed", 0))
