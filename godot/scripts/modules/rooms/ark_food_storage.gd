extends RefCounted
## One physical chest, separate dry-wood and household-food compartments. Food is
## never mirrored into player stock; Economy owns every container and transfer.
const Memory = preload("res://scripts/modules/memory/ark_memory.gd")
const OWNER := "storage_food"
const CARRY := "kitchen_carry"
const CAPACITY := 8
const MAX_OPERATIONS := 1000000
const DEPOSIT := "home_food:deposit"
const WITHDRAW_SHELL := "home_food:withdraw_shell"
const WITHDRAW_STEW := "home_food:withdraw_stew"
const RESOURCES := ["shellfish","stew_servings"]

static func initialize(economy: RefCounted) -> void:
	economy.seed_inventory(OWNER,{})
	economy.seed_inventory(CARRY,{})
	economy.set_capacity(OWNER,CAPACITY)
	economy.set_capacity(CARRY,1)

static func stock(economy: RefCounted) -> int:
	return economy.inventory(OWNER,"shellfish")+economy.inventory(OWNER,"stew_servings")

static func next(economy: RefCounted,id: String) -> int:
	return int(economy.flow(id).get("sequence",0))+1

static func deposit(economy: RefCounted) -> Dictionary:
	var room := CAPACITY-stock(economy)
	var moves: Array = []
	var amounts := {}
	for resource in ["stew_servings","shellfish"]:
		var amount := mini(room,economy.inventory("player",resource))
		if amount <= 0: continue
		moves.append({"from":"player","to":OWNER,"resource":resource,"amount":amount})
		amounts[resource] = amount
		room -= amount
	if moves.is_empty() or next(economy,DEPOSIT)>MAX_OPERATIONS: return {"ok":false,"code":"empty_or_full"}
	var result: Dictionary = economy.process_flow(DEPOSIT,next(economy,DEPOSIT),moves)
	if result.ok: result["amounts"] = amounts
	return result

static func withdraw(economy: RefCounted,resource: String) -> Dictionary:
	if resource not in RESOURCES: return {"ok":false,"code":"resource"}
	var id := WITHDRAW_SHELL if resource == "shellfish" else WITHDRAW_STEW
	if next(economy,id)>MAX_OPERATIONS: return {"ok":false,"code":"operation_limit"}
	return economy.process_flow(id,next(economy,id),[{"from":OWNER,"to":"player","resource":resource,"amount":1}])

static func matches_save(state: Dictionary) -> bool:
	if not Memory._integer(state.get("schema_version")): return false
	var schema: int = int(state.get("schema_version",0))
	if schema>=43 and not state.get("storage_built") is bool: return false
	var modules: Variant = state.get("modules")
	if not modules is Dictionary or not modules.get("economy") is Dictionary: return schema<34
	var e: Dictionary = modules.economy
	if not e.get("inventories") is Dictionary or not e.get("capacities") is Dictionary or not e.get("flows",{}) is Dictionary or not e.get("streams",{}) is Dictionary: return false
	for pair in [[OWNER,CAPACITY],[CARRY,1]]:
		var owner: String = pair[0]
		if schema>=43 and (not e.inventories.has(owner) or not e.capacities.has(owner)): return false
		var inventory: Variant = e.inventories.get(owner,{})
		if not inventory is Dictionary: return false
		var total := 0
		for resource in inventory:
			if resource not in RESOURCES or not Memory._integer(inventory[resource]) or inventory[resource]<0: return false
			total += int(inventory[resource])
		if total>int(pair[1]) or (schema<43 and total>0): return false
		if e.capacities.has(owner) and (not Memory._integer(e.capacities[owner]) or e.capacities[owner] != pair[1]): return false
	if schema>=43 and stock_from(e.inventories)>0 and not state.get("storage_built",false): return false
	for id in e.get("streams",{}):
		if str(id).begins_with("home_food:") or str(id).begins_with("domestic_flow:"): return false
	for id in e.get("flows",{}):
		if not str(id).begins_with("home_food:"): continue
		if schema<43 or not _valid_household_flow(str(id),e.flows[id]): return false
	return true

static func stock_from(inventories: Dictionary) -> int:
	var food: Dictionary = inventories.get(OWNER,{})
	return int(food.get("shellfish",0))+int(food.get("stew_servings",0))

static func _valid_household_flow(id: String,flow: Variant) -> bool:
	if id not in [DEPOSIT,WITHDRAW_SHELL,WITHDRAW_STEW] or not flow is Dictionary or flow.size()!=4: return false
	if not Memory._integer(flow.get("sequence")) or flow.sequence<1 or flow.sequence>MAX_OPERATIONS or flow.get("costs")!={} or flow.get("outputs")!={}: return false
	if not flow.get("moves") is Array or flow.moves.is_empty() or flow.moves.size()>(2 if id==DEPOSIT else 1): return false
	var seen := []
	for move in flow.moves:
		if not move is Dictionary or move.size()!=4 or move.get("resource") not in RESOURCES or seen.has(move.resource): return false
		if not Memory._integer(move.get("amount")) or move.amount<1 or move.amount>CAPACITY: return false
		seen.append(move.resource)
		if id==DEPOSIT:
			if move.get("from")!="player" or move.get("to")!=OWNER: return false
		else:
			if move.get("from")!=OWNER or move.get("to")!="player" or move.amount!=1 or move.resource!=("shellfish" if id==WITHDRAW_SHELL else "stew_servings"): return false
	return true
