extends SceneTree
const Kitchen = preload("res://scripts/modules/residents/ark_kitchen_work.gd")
const Economy = preload("res://scripts/modules/economy/ark_economy.gd")
const Roles = preload("res://scripts/modules/rooms/ark_room_roles.gd")
var failures := 0
func _initialize() -> void: _run.call_deferred()
func _check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error("KITCHEN_WORK: "+message)
func _state(work: RefCounted,economy: RefCounted,day: int = 2) -> Dictionary:
	return {"schema_version":42,"day_count":day,"traveler_boarded":true,"shelter_built":true,"kitchen":work.snapshot(),"modules":{"economy":economy.snapshot()}}
func _run() -> void:
	_check(Roles.available("galley",{"shelter":true,"hearth":true}) and not Roles.available("galley",{"shelter":true}),"role needs actual station facts, not a room label")
	_check(not Roles.available("workshop",{"shelter":true,"storage":true,"workbench":"true"}),"role facts are explicit booleans")
	var economy := Economy.new()
	_check(economy.seed_inventory("player",{"shellfish":1,"stew_servings":0}),"finite ingredient fixture")
	var work := Kitchen.new()
	_check(work.begin(2) and not work.complete(2,economy).ok,"one actual timed order required")
	work.advance(4000000,false)
	_check(work.order.elapsed_usec == 0 and economy.inventory("player","shellfish") == 1,"remote or oversized tick never manufactures dinner")
	for i in 39: work.advance(100000,true)
	_check(not work.ready() and not work.complete(2,economy).ok,"less than four actual seconds cannot finish")
	var partial := JSON.parse_string(JSON.stringify(work.snapshot())) as Dictionary
	var restored := Kitchen.new()
	_check(restored.restore(partial) and restored.order.elapsed_usec == 3900000,"integer work progress survives JSON")
	restored.enabled = false
	restored.advance(100000,true)
	_check(not restored.ready(),"disabled station pauses without prepayment")
	restored.enabled = true
	restored.advance(100000,true)
	_check(restored.ready(),"actual remaining work completes")
	economy.set_capacity("player",0)
	_check(not restored.complete(2,economy).ok and economy.inventory("player","shellfish") == 1 and economy.inventory("player","stew_servings") == 0,"capacity failure is atomic")
	economy.set_capacity("player",10)
	_check(restored.complete(2,economy).ok and economy.inventory("player","shellfish") == 0 and economy.inventory("player","stew_servings") == 1,"one shell becomes exactly one serving")
	_check(not restored.complete(2,economy).ok and not restored.begin(2) and economy.audit().ok,"no repeated same-day work or duplicate output")
	var saved := _state(restored,economy)
	_check(Kitchen.matches_save(JSON.parse_string(JSON.stringify(saved))),"strict module/stream save is JSON-compatible")
	for mutation in ["completed","stream","shared","future","owner","totals","foreign_stream","downgrade"]:
		var bad := saved.duplicate(true)
		match mutation:
			"completed": bad.kitchen.completed = 0
			"stream": bad.modules.economy.streams[Kitchen.STREAM].sequence = 2
			"shared": bad.modules.economy.streams[Kitchen.STREAM]["shared"] = {"shellfish":["foreign_ark"]}
			"future": bad.kitchen.last_completed_day = 3
			"owner": bad.modules.economy.streams[Kitchen.STREAM].owner = "storage"
			"totals": bad.modules.economy.totals.shellfish.consumed = "invalid"
			"foreign_stream": bad.modules.economy.streams["domestic:galley:invented"] = bad.modules.economy.streams[Kitchen.STREAM].duplicate(true)
			"downgrade": bad.schema_version = 41
		_check(not Kitchen.matches_save(bad),"reject inconsistent/reserved kitchen ledger "+mutation)
	var legacy := {"schema_version":41,"modules":{"economy":Economy.new().snapshot()}}
	_check(Kitchen.matches_save(legacy),"real older schema needs no kitchen state")
	legacy["kitchen"] = Kitchen.DEFAULT.duplicate(true)
	_check(Kitchen.matches_save(legacy),"synthetic older format may retain only an untouched new default")
	legacy.kitchen.enabled = false
	_check(not Kitchen.matches_save(legacy),"cannot silently downgrade an explicit new policy")
	var fast := Kitchen.new()
	fast.begin(1)
	for i in 19: fast.advance(100000,true,true)
	_check(not fast.ready(),"pressure still requires actual two seconds")
	fast.advance(100000,true,true)
	_check(fast.ready(),"real pressure tool doubles effective work, no free ingredients")
	var bounded := Kitchen.new()
	var stock := Economy.new()
	stock.seed_inventory("player",{"shellfish":1000,"stew_servings":0})
	for day in range(1,1001):
		_check(bounded.begin(day),"daily finite order "+str(day))
		for i in 40: bounded.advance(100000,true)
		_check(bounded.complete(day,stock).ok,"bounded daily completion "+str(day))
		stock.sync_inventory("player","stew_servings",0) # Declared consumption fixture.
	_check(stock.snapshot().streams.size() == 1 and stock.snapshot().receipts.is_empty() and bounded.completed == 1000 and stock.inventory("player","shellfish") == 0 and stock.audit().ok,"one stable stream, not one receipt per meal, with real finite cost")
	_check(Kitchen.matches_save(_state(bounded,stock,1000)),"bounded thousand-day module/ledger agreement")
	if failures == 0: print("ARK_KITCHEN_WORK_TEST_OK:")
	quit(1 if failures else 0)
