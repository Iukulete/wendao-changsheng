extends RefCounted
## UI-selected transfers over existing owners. No new inventory/save schema.
const Economy = preload("res://scripts/modules/economy/ark_economy.gd")
const Food = preload("res://scripts/modules/rooms/ark_food_storage.gd")
const RESOURCES := ["wood","shellfish","stew_servings","fish","large_fish"]

static func owner(side: String, resource: String) -> String:
	if side=="player": return "player"
	if side=="box" and resource in RESOURCES: return "storage" if resource=="wood" else Food.OWNER
	return ""

static func preview(economy: RefCounted, source: String, resource: String, mode: String) -> Dictionary:
	if source not in ["player","box"] or resource not in RESOURCES or mode not in ["all","one"]: return {}
	var destination := "box" if source=="player" else "player"
	var from_owner := owner(source,resource)
	var to_owner := owner(destination,resource)
	var available: int=economy.inventory(from_owner,resource)
	var state: Dictionary=economy.snapshot()
	var occupied:=0
	for amount in state.inventories.get(to_owner,{}).values(): occupied+=int(amount)
	var room:=maxi(0,int(state.capacities.get(to_owner,1000000000))-occupied)
	var amount:=mini(mini(available,room),1 if mode=="one" else available)
	return {"source":source,"destination":destination,"resource":resource,"mode":mode,"amount":amount,"available":available,"space":room}

static func commit(economy: RefCounted, intent: Dictionary, operation_id: String) -> Dictionary:
	var current:=preview(economy,str(intent.get("source","")),str(intent.get("resource","")),str(intent.get("mode","")))
	if current.is_empty() or operation_id.is_empty(): return {"ok":false,"code":"invalid"}
	# An all-stack action must retain the exact displayed quantity/space. A
	# single-item intent may tolerate other quantities changing, never its kind.
	if current.destination!=intent.get("destination") or int(intent.get("amount",0))<=0 or current.amount!=intent.get("amount"): return {"ok":false,"code":"changed"}
	if current.mode=="all" and (current.available!=intent.get("available") or current.space!=intent.get("space")): return {"ok":false,"code":"changed"}
	var resource: String=current.resource
	var amount: int=current.amount
	if resource=="wood":
		return economy.transfer(owner(current.source,resource),owner(current.destination,resource),{resource:amount},operation_id)
	if amount>Food.CAPACITY: return {"ok":false,"code":"invalid_amount"}
	if current.source=="player":
		if Food.next(economy,Food.DEPOSIT)>Food.MAX_OPERATIONS: return {"ok":false,"code":"operation_limit"}
		# Explicitly selected kind, original one/two-resource deposit flow shape.
		return economy.process_flow(Food.DEPOSIT,Food.next(economy,Food.DEPOSIT),[{"from":"player","to":Food.OWNER,"resource":resource,"amount":amount}])
	var flow_id: String=Food.WITHDRAW_SHELL if resource=="shellfish" else Food.WITHDRAW_FISH if resource=="fish" else Food.WITHDRAW_LARGE_FISH if resource=="large_fish" else Food.WITHDRAW_STEW
	if int(economy.flow(flow_id).get("sequence",0))+amount>Food.MAX_OPERATIONS: return {"ok":false,"code":"operation_limit"}
	# Existing schema validates a withdrawal flow's last move.amount == 1.
	# Run <=8 original single-serving steps on an isolated complete ledger, then
	# commit once to the SAME authority instance. Never expose partial batches.
	var before: Dictionary=economy.snapshot()
	var staged:=Economy.new()
	if not staged.restore(before): return {"ok":false,"code":"invalid_ledger"}
	for index in amount:
		var step: Dictionary=Food.withdraw(staged,resource)
		if not step.get("ok",false) or step.get("duplicate",false): return {"ok":false,"code":step.get("code","batch_failed")}
	if economy.snapshot()!=before: return {"ok":false,"code":"ledger_changed"}
	if not economy.restore(staged.snapshot()): return {"ok":false,"code":"commit_failed"}
	return {"ok":true,"duplicate":false}
