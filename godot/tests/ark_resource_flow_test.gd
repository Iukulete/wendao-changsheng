extends SceneTree
const Economy = preload("res://scripts/modules/economy/ark_economy.gd")
func _initialize() -> void:
	var e = Economy.new()
	e.seed_inventory("store",{"shellfish":3})
	e.seed_inventory("carry",{})
	e.set_capacity("carry",1)
	e.seed_inventory("pantry",{})
	e.set_capacity("pantry",1)
	var move := [{"from":"store","to":"carry","resource":"shellfish","amount":1}]
	var totals: Dictionary = e.snapshot().totals
	assert(e.process_flow("take",1,move).ok and e.inventory("store","shellfish") == 2 and e.inventory("carry","shellfish") == 1)
	assert(e.snapshot().totals == totals,"physical transfer is not fabricated input and consumption")
	var before: Dictionary = e.snapshot()
	assert(e.process_flow("take",1,move).duplicate and e.snapshot() == before)
	assert(not e.process_flow("take",1,[{"from":"store","to":"carry","resource":"shellfish","amount":2}]).ok and e.snapshot() == before)
	assert(not e.process_flow("take",2,move).ok and e.snapshot() == before,"capacity is preflighted without removing food")
	assert(e.process_flow("cook",1,[],{"carry":{"shellfish":1}},{"pantry":{"stew_servings":1}}).ok)
	assert(e.inventory("carry","shellfish") == 0 and e.inventory("pantry","stew_servings") == 1 and e.audit().ok)
	assert(e.process_flow("take",2,move).ok)
	before = e.snapshot()
	assert(not e.process_flow("cook",2,[],{"carry":{"shellfish":1}},{"pantry":{"stew_servings":1}}).ok and e.snapshot() == before,"full output does not eat an ingredient")
	assert(e.process_flow("return",1,[{"from":"carry","to":"store","resource":"shellfish","amount":1}]).ok)
	assert(e.inventory("store","shellfish") == 2)
	for i in 1000:
		assert(e.process_flow("take",3+i,move).ok)
		assert(e.process_flow("return",2+i,[{"from":"carry","to":"store","resource":"shellfish","amount":1}]).ok)
	assert(e.snapshot().flows.size() == 3 and e.snapshot().receipts.is_empty() and e.audit().ok)
	before = e.snapshot()
	var restored = Economy.new()
	assert(restored.restore(JSON.parse_string(JSON.stringify(before))))
	assert(restored.process_flow("take",1002,move).duplicate,"the exact last transfer remains deduplicated after restore")
	for kind in ["owner","sequence","amount","extra","unknown_container","empty"]:
		var bad := before.duplicate(true)
		match kind:
			"owner": bad.flows.take.moves[0]["from"] = true
			"sequence": bad.flows.take.sequence = 0
			"amount": bad.flows.take.moves[0].amount = -1
			"extra": bad.flows.take.extra = 1
			"unknown_container": bad.flows.take.moves[0].to = "foreign"
			"empty": bad.flows.take.moves.clear()
		assert(not restored.restore(bad) and restored.Memory.facts_equal(restored.snapshot(),before),kind)
	var old := before.duplicate(true)
	old.erase("flows")
	assert(Economy.new().restore(old),"old conserved ledger has an empty bounded flow table on migration")
	print("ARK_RESOURCE_FLOW_TEST_OK: real inter-container transfer, routed recipe, replay, failed-capacity atomicity, conserved old restore and 1000 bounded round trips")
	quit()
