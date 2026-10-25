extends RefCounted
## Arrival belongs to the adapter; Economy owns the real one-item food tote.
const Memory = preload("res://scripts/modules/memory/ark_memory.gd")
const Food = preload("res://scripts/modules/rooms/ark_food_storage.gd")
const RECIPES := {"tidal_shellfish_stew":{"role":"galley","work_usec":4000000,"costs":{"shellfish":1},"outputs":{"stew_servings":1},"target_stock":2}}
const STREAM := "domestic:galley:stew"
const TAKE := "domestic_flow:galley:take"
const COOK := "domestic_flow:galley:cook"
const RETURN := "domestic_flow:galley:return"
const DELIVER := "domestic_flow:galley:deliver"
const MAX_ORDERS := 1000000
const DEFAULT_V1 := {"version":1,"enabled":true,"completed":0,"attempts":0,"last_completed_day":0,"order":{}}
const DEFAULT := {"version":2,"enabled":true,"completed":0,"attempts":0,"last_completed_day":0,"order":{},"pantry_picked":0,"pantry_cooked":0,"pantry_returned":0,"pantry_stored":0}
var enabled := true
var completed := 0
var attempts := 0
var last_completed_day := 0
var pantry_picked := 0
var pantry_cooked := 0
var pantry_returned := 0
var pantry_stored := 0
var order := {}

func active() -> bool: return not order.is_empty()
func carrying_raw() -> bool: return pantry_picked-pantry_cooked-pantry_returned == 1
func carrying_stew() -> bool: return pantry_cooked-pantry_stored == 1
func carrying() -> bool: return carrying_raw() or carrying_stew()
func returning() -> bool: return active() and order.phase == "return"
func delivering() -> bool: return active() and order.phase == "deliver"
func ready() -> bool: return active() and order.phase == "cook" and int(order.elapsed_usec) == int(RECIPES[order.recipe].work_usec)
func can_begin(day: int) -> bool: return enabled and not active() and not carrying() and day > last_completed_day and day <= MAX_ORDERS and attempts < MAX_ORDERS
func begin(day: int,supply: String = "player") -> bool:
	if day < 1 or not can_begin(day) or supply not in ["player","storage"]: return false
	attempts += 1
	order = {"recipe":"tidal_shellfish_stew","room":"starter.galley","resident":"tidekeeper","started_day":day,"attempt":attempts,"elapsed_usec":0,"supply":supply,"phase":"fetch" if supply=="storage" else "cook"}
	return true

func cancel() -> void:
	if carrying() and active(): order.phase = "deliver" if carrying_stew() else "return"
	else: order = {}

func fetch(economy: RefCounted) -> Dictionary:
	if not enabled or not active() or order.phase!="fetch" or order.supply!="storage": return {"ok":false,"code":"not_fetching"}
	var result: Dictionary = economy.process_flow(TAKE,pantry_picked+1,[{"from":Food.OWNER,"to":Food.CARRY,"resource":"shellfish","amount":1}])
	if not result.ok or result.get("duplicate",false): return {"ok":false,"code":result.get("code","replay")}
	pantry_picked += 1
	order.phase = "cook"
	return {"ok":true,"attempt":int(order.attempt)}

func return_food(economy: RefCounted,to_owner: String = Food.OWNER) -> Dictionary:
	if not returning() or not carrying_raw() or to_owner not in [Food.OWNER,"player"]: return {"ok":false,"code":"not_returning"}
	var result: Dictionary = economy.process_flow(RETURN,pantry_returned+1,[{"from":Food.CARRY,"to":to_owner,"resource":"shellfish","amount":1}])
	if not result.ok or result.get("duplicate",false): return {"ok":false,"code":result.get("code","replay")}
	var attempt: int = order.attempt
	pantry_returned += 1
	order = {}
	return {"ok":true,"attempt":attempt,"destination":to_owner}

func deliver_food(economy: RefCounted,to_owner: String = Food.OWNER) -> Dictionary:
	if not delivering() or not carrying_stew() or to_owner not in [Food.OWNER,"player"]: return {"ok":false,"code":"not_delivering"}
	var payment: Dictionary = economy.process_flow(DELIVER,pantry_stored+1,[{"from":Food.CARRY,"to":to_owner,"resource":"stew_servings","amount":1}])
	if not payment.ok or payment.get("duplicate",false): return {"ok":false,"code":payment.get("code","replay")}
	var result := {"ok":true,"recipe":str(order.recipe),"room":str(order.room),"attempt":int(order.attempt),"supply":"storage","destination":to_owner}
	pantry_stored += 1
	order = {}
	return result

func advance(usec: int,arrived: bool,pressure: bool = false) -> void:
	if not enabled or not active() or order.phase!="cook" or not arrived or usec <= 0: return
	order.elapsed_usec = mini(int(RECIPES[order.recipe].work_usec),int(order.elapsed_usec)+mini(usec,100000)*(2 if pressure else 1))

func complete(day: int,economy: RefCounted) -> Dictionary:
	if not enabled or not ready() or day <= last_completed_day or day < int(order.started_day): return {"ok":false,"code":"not_ready"}
	var recipe: Dictionary = RECIPES[order.recipe]
	if economy.inventory("player","stew_servings")+economy.inventory(Food.OWNER,"stew_servings") >= int(recipe.target_stock): return {"ok":false,"code":"enough_food"}
	var pantry: bool = order.supply == "storage"
	var payment: Dictionary
	if pantry: payment = economy.process_flow(COOK,pantry_cooked+1,[],{Food.CARRY:recipe.costs},{Food.CARRY:recipe.outputs})
	else: payment = economy.process_stream("player",STREAM,completed-pantry_cooked+1,recipe.costs,recipe.outputs)
	if not payment.get("ok",false) or payment.get("duplicate",false): return {"ok":false,"code":payment.get("code","unexpected_replay")}
	var result := {"ok":true,"recipe":str(order.recipe),"room":str(order.room),"attempt":int(order.attempt),"supply":str(order.supply),"destination":Food.CARRY if pantry else "player","delivery_pending":pantry}
	completed += 1
	if pantry: pantry_cooked += 1
	last_completed_day = day
	if pantry: order.phase = "deliver"
	else: order = {}
	return result

func snapshot() -> Dictionary:
	return {"version":2,"enabled":enabled,"completed":completed,"attempts":attempts,"last_completed_day":last_completed_day,"order":order.duplicate(true),"pantry_picked":pantry_picked,"pantry_cooked":pantry_cooked,"pantry_returned":pantry_returned,"pantry_stored":pantry_stored}

static func _current(saved: Dictionary) -> Dictionary:
	var result := saved.duplicate(true)
	if result.get("version")==1:
		result.version = 2
		for key in ["pantry_picked","pantry_cooked","pantry_returned","pantry_stored"]: result[key] = 0
		if result.get("order") is Dictionary and not result.order.is_empty():
			result.order["supply"] = "player"
			result.order["phase"] = "cook"
	return result

static func valid(raw: Dictionary) -> bool:
	if not Memory._plain(raw) or not Memory._integer(raw.get("version")) or int(raw.version) not in [1,2] or raw.size()!=(6 if raw.version==1 else 10): return false
	if not raw.get("enabled") is bool or not raw.get("order") is Dictionary: return false
	if not raw.order.is_empty() and raw.order.size()!=(6 if raw.version==1 else 8): return false
	var saved := _current(raw)
	for key in ["completed","attempts","last_completed_day","pantry_picked","pantry_cooked","pantry_returned","pantry_stored"]:
		if not Memory._integer(saved.get(key)) or float(saved[key]) < 0 or float(saved[key]) > MAX_ORDERS: return false
	if saved.completed > saved.attempts or (saved.completed == 0) != (saved.last_completed_day == 0) or saved.completed > saved.last_completed_day or saved.pantry_cooked>saved.completed or saved.pantry_picked>saved.attempts: return false
	var held: int = int(saved.pantry_picked)-int(saved.pantry_cooked)-int(saved.pantry_returned)
	var soup: int = int(saved.pantry_cooked)-int(saved.pantry_stored)
	if held not in [0,1] or soup not in [0,1] or held+soup>1: return false
	var current: Dictionary = saved.order
	if current.is_empty(): return held+soup==0
	for pair in [["recipe","tidal_shellfish_stew"],["room","starter.galley"],["resident","tidekeeper"]]:
		if not current.get(pair[0]) is String or current[pair[0]] != pair[1]: return false
	if current.get("supply") not in ["player","storage"] or current.get("phase") not in ["fetch","cook","return","deliver"]: return false
	if current.supply=="player" and (current.phase!="cook" or held+soup!=0): return false
	if current.supply=="storage" and (held!=(1 if current.phase in ["cook","return"] else 0) or soup!=(1 if current.phase=="deliver" else 0)): return false
	for key in ["started_day","attempt","elapsed_usec"]:
		if not Memory._integer(current.get(key)): return false
	if current.phase=="fetch" and current.elapsed_usec!=0: return false
	if current.phase=="deliver" and (current.elapsed_usec!=4000000 or current.started_day>saved.last_completed_day): return false
	if current.phase!="deliver" and (current.started_day<=saved.last_completed_day or current.attempt<=saved.completed): return false
	return current.started_day<=MAX_ORDERS and current.started_day>=1 and current.attempt==saved.attempts and current.attempt>=saved.completed and current.elapsed_usec>=0 and current.elapsed_usec<=RECIPES[current.recipe].work_usec

func restore(saved: Dictionary) -> bool:
	if not valid(saved): return false
	var current := _current(saved)
	enabled = current.enabled
	completed = int(current.completed)
	attempts = int(current.attempts)
	last_completed_day = int(current.last_completed_day)
	pantry_picked = int(current.pantry_picked)
	pantry_cooked = int(current.pantry_cooked)
	pantry_returned = int(current.pantry_returned)
	pantry_stored = int(current.pantry_stored)
	order = current.order.duplicate(true)
	for key in ["started_day","attempt","elapsed_usec"]:
		if order.has(key): order[key] = int(order[key])
	return true

static func matches_save(state: Dictionary) -> bool:
	if not Memory._integer(state.get("schema_version")) or not Food.matches_save(state): return false
	var schema: int = int(state.schema_version)
	var modules: Variant = state.get("modules")
	if schema<42:
		if state.has("kitchen") and (not state.kitchen is Dictionary or not valid(state.kitchen) or not Memory.facts_equal(_current(state.kitchen),DEFAULT)): return false
		if not modules is Dictionary or not modules.get("economy") is Dictionary: return schema<34
	elif not modules is Dictionary or not modules.get("economy") is Dictionary: return false
	var e: Dictionary = modules.economy
	var streams: Variant = e.get("streams",{})
	var flows: Variant = e.get("flows",{})
	if not streams is Dictionary or not flows is Dictionary: return false
	for id in streams:
		if str(id).begins_with("domestic:") and (schema<42 or id!=STREAM): return false
	for id in flows:
		if str(id).begins_with("domestic:"): return false
		if str(id).begins_with("domestic_flow:") and (schema<43 or id not in [TAKE,COOK,RETURN,DELIVER]): return false
	if schema<42: return true
	if not state.get("kitchen") is Dictionary or not valid(state.kitchen): return false
	var saved := _current(state.kitchen)
	if schema==42 and (saved.pantry_picked!=0 or saved.pantry_cooked!=0 or saved.pantry_returned!=0 or saved.pantry_stored!=0 or (not saved.order.is_empty() and saved.order.supply!="player")): return false
	if not Memory._integer(state.get("day_count")) or saved.last_completed_day > state.day_count: return false
	if not saved.order.is_empty():
		if saved.order.started_day>state.day_count or (saved.order.phase not in ["return","deliver"] and not state.get("traveler_boarded",false)): return false
		if saved.order.phase not in ["return","deliver"] and not state.get("shelter_built",false): return false
	var held: int = int(saved.pantry_picked)-int(saved.pantry_cooked)-int(saved.pantry_returned)
	if int(e.inventories.get(Food.CARRY,{}).get("shellfish",0))!=held: return false
	if int(e.inventories.get(Food.CARRY,{}).get("stew_servings",0))!=int(saved.pantry_cooked)-int(saved.pantry_stored): return false
	var player_completed: int = int(saved.completed)-int(saved.pantry_cooked)
	if player_completed==0:
		if streams.has(STREAM): return false
	elif not streams.has(STREAM) or not Memory.facts_equal(streams[STREAM],{"owner":"player","sequence":player_completed,"costs":{"shellfish":1},"outputs":{"stew_servings":1}}): return false
	for id in [TAKE,COOK,RETURN,DELIVER]:
		var count: int = int(saved.pantry_picked if id==TAKE else saved.pantry_cooked if id==COOK else saved.pantry_returned if id==RETURN else saved.pantry_stored)
		if count==0:
			if flows.has(id): return false
			continue
		var expected := {"sequence":count,"moves":[],"costs":{},"outputs":{}}
		if id==TAKE: expected.moves = [{"from":Food.OWNER,"to":Food.CARRY,"resource":"shellfish","amount":1}]
		elif id==COOK:
			expected.costs = {Food.CARRY:{"shellfish":1}}
			expected.outputs = {Food.CARRY:{"stew_servings":1}}
		else:
			if not flows.get(id) is Dictionary: return false
			var to_owner: Variant = flows[id].get("moves",[])
			if not to_owner is Array or to_owner.size()!=1 or not to_owner[0] is Dictionary or to_owner[0].get("to") not in [Food.OWNER,"player"]: return false
			expected.moves = [{"from":Food.CARRY,"to":str(to_owner[0].to),"resource":"shellfish" if id==RETURN else "stew_servings","amount":1}]
		if not flows.has(id) or not Memory.facts_equal(flows[id],expected): return false
	if saved.completed==0: return true
	var totals: Variant = e.get("totals")
	if not totals is Dictionary: return false
	for pair in [["shellfish","consumed"],["stew_servings","input"]]:
		var bucket: Variant = totals.get(pair[0])
		if not bucket is Dictionary or not Memory._integer(bucket.get(pair[1])) or bucket[pair[1]] < saved.completed: return false
	return true
