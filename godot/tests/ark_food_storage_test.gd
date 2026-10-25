extends SceneTree
const Food = preload("res://scripts/modules/rooms/ark_food_storage.gd")
const Kitchen = preload("res://scripts/modules/residents/ark_kitchen_work.gd")
const Economy = preload("res://scripts/modules/economy/ark_economy.gd")
func _initialize() -> void: _run.call_deferred()
func _state(work: RefCounted,e: RefCounted,day: int = 2) -> Dictionary:
	return {"schema_version":43,"day_count":day,"traveler_boarded":true,"storage_built":true,"shelter_built":true,"kitchen":work.snapshot(),"modules":{"economy":e.snapshot()}}
func _roundtrip(work: RefCounted,e: RefCounted,day: int = 2) -> void:
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_state(work,e,day)))
	assert(Kitchen.matches_save(saved),"physical stock and kitchen phases match the persisted ledger")
	assert(Economy.new().restore(saved.modules.economy) and Kitchen.new().restore(saved.kitchen),"JSON phase restores without catch-up work")
func _run() -> void:
	var e = Economy.new()
	e.seed_inventory("player",{"shellfish":10,"stew_servings":2})
	Food.initialize(e)
	assert(Food.deposit(e).ok and e.inventory(Food.OWNER,"stew_servings")==2 and e.inventory(Food.OWNER,"shellfish")==6 and e.inventory("player","shellfish")==4)
	var full: Dictionary = e.snapshot()
	assert(not Food.deposit(e).ok and e.snapshot()==full,"finite eight-slot box does not eat overflow")
	assert(Food.withdraw(e,"stew_servings").ok and Food.withdraw(e,"stew_servings").ok)
	assert(not Food.withdraw(e,"stew_servings").ok and not Food.withdraw(e,"wood").ok)
	var work = Kitchen.new()
	assert(work.begin(2,"storage") and work.order.phase=="fetch")
	_roundtrip(work,e)
	assert(not work.complete(2,e).ok and e.inventory(Food.CARRY,"shellfish")==0,"no completion before the adapter proves physical fetch arrival")
	assert(work.fetch(e).ok and e.inventory(Food.CARRY,"shellfish")==1 and e.inventory(Food.OWNER,"shellfish")==5)
	_roundtrip(work,e)
	for i in 39: work.advance(100000,true)
	assert(not work.ready())
	work.advance(100000,true)
	# Existing carried soups count toward the target; do not cook endlessly.
	var before: Dictionary = e.snapshot()
	assert(not work.complete(2,e).ok and e.snapshot()==before)
	e.sync_inventory("player","stew_servings",0) # Explicit meal-consumption fixture.
	assert(work.complete(2,e).ok and work.delivering() and e.inventory(Food.CARRY,"stew_servings")==1 and e.inventory(Food.OWNER,"stew_servings")==0)
	assert(e.inventory(Food.CARRY,"shellfish")==0 and not work.complete(2,e).ok,"real recipe transforms only the tote contents, once")
	_roundtrip(work,e)
	# A player can fill the newly freed slot while the cook is carrying dinner.
	assert(Food.deposit(e).ok and Food.stock(e)==8)
	before = e.snapshot()
	assert(not work.deliver_food(e).ok and e.snapshot()==before and work.delivering(),"full destination retains cooked food in transit")
	assert(Food.withdraw(e,"shellfish").ok and work.deliver_food(e).ok and not work.active() and Food.stock(e)==8)
	assert(e.inventory(Food.OWNER,"stew_servings")==1 and e.inventory("player","stew_servings")==0)
	_roundtrip(work,e)
	assert(Food.withdraw(e,"shellfish").ok)
	assert(work.begin(3,"storage") and work.fetch(e).ok)
	work.advance(100000,true)
	work.cancel()
	assert(work.returning() and not work.ready())
	_roundtrip(work,e,3)
	assert(work.return_food(e).ok and not work.active() and work.completed==1 and work.pantry_returned==1)
	_roundtrip(work,e,3)
	var saved := _state(work,e,3)
	for mutation in ["counter","tote","capacity","downgrade","stream_type","flow_type","foreign_flow","missing_owner","resource"]:
		var bad := saved.duplicate(true)
		match mutation:
			"counter": bad.kitchen.pantry_stored = 0
			"tote": bad.modules.economy.inventories[Food.CARRY]["stew_servings"] = 1
			"capacity": bad.modules.economy.capacities[Food.OWNER] = 9
			"downgrade": bad.schema_version = 42
			"stream_type": bad.modules.economy.streams = "invalid"
			"flow_type": bad.modules.economy.flows[Kitchen.DELIVER] = "invalid"
			"foreign_flow": bad.modules.economy.flows["home_food:invented"] = bad.modules.economy.flows[Food.DEPOSIT]
			"missing_owner": bad.modules.economy.inventories.erase(Food.CARRY)
			"resource": bad.modules.economy.inventories[Food.CARRY]["wood"] = 0
		assert(not Kitchen.matches_save(bad),"reject pantry/kitchen mismatch: "+mutation)
	# Real v1 partial work has no new owner/flow requirement or free migration meal.
	var old_e = Economy.new()
	old_e.seed_inventory("player",{"shellfish":1})
	var legacy: Dictionary = Kitchen.DEFAULT_V1.duplicate(true)
	legacy.attempts = 1
	legacy.order = {"recipe":"tidal_shellfish_stew","room":"starter.galley","resident":"tidekeeper","started_day":2,"attempt":1,"elapsed_usec":1700000}
	var old_state := {"schema_version":42,"day_count":2,"traveler_boarded":true,"shelter_built":true,"kitchen":legacy,"modules":{"economy":old_e.snapshot()}}
	assert(Kitchen.matches_save(JSON.parse_string(JSON.stringify(old_state))))
	var old_work = Kitchen.new()
	assert(old_work.restore(legacy) and old_work.order.elapsed_usec==1700000 and old_work.order.supply=="player" and not old_work.carrying())
	# Repeated physical trips retain one stable record per operation, not per meal.
	var stock = Economy.new()
	stock.seed_inventory("player",{"shellfish":1000})
	Food.initialize(stock)
	var cook = Kitchen.new()
	for day in range(1,1001):
		assert(Food.deposit(stock).ok or Food.stock(stock)>0)
		assert(cook.begin(day,"storage") and cook.fetch(stock).ok)
		for i in 20: cook.advance(100000,true,true)
		assert(cook.complete(day,stock).ok and cook.deliver_food(stock).ok)
		assert(Food.withdraw(stock,"stew_servings").ok)
		stock.sync_inventory("player","stew_servings",0) # Explicit actual-eater fixture.
	assert(cook.completed==1000 and stock.snapshot().flows.size()==5 and stock.snapshot().receipts.is_empty() and stock.audit().ok)
	_roundtrip(cook,stock,1000)
	print("ARK_FOOD_STORAGE_TEST_OK: finite pantry, raw/cooked tote, staged delivery, full-box retention, cancellation, real v1 migration, malformed saves and 1000 bounded trips")
	quit()
