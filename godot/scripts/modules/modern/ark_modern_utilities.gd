extends RefCounted
## Power/device authority; Economy remains the sole material/water owner.
const Power = preload("res://scripts/modules/modern/ark_power.gd")
const Memory = preload("res://scripts/modules/memory/ark_memory.gd")
const BLUEPRINT := "solar_water_corner"
const SOURCE := "PressureUtilityCore"
const WOOD_COST := 4
const TANK := "utilities_tank"
const STEP := 250000
const FILTER_TIME := 8000000
const FILTER_COST := 2500
const WASH_COST := 500
const ACTORS := ["player","tidekeeper","sailmaker"]
const MAX_INSTALLATIONS := 1000000
const REINSTALL_STREAM := "modern_utilities:reinstall"
const PACK_STREAM := "modern_utilities:pack"
var power = Power.new()
var salvaged := false
var installed := false
var automatic := true
var carry_us := 0
var filter_us := 0
var produced := 0
var washes: Dictionary = {}
var installations := 0
var removals := 0

func install(economy: RefCounted, shared: Dictionary) -> Dictionary:
	if installed: return {"ok":false,"code":"already_installed"}
	if not salvaged: return {"ok":false,"code":"blueprint"}
	if installations >= MAX_INSTALLATIONS or not (shared.is_empty() or Memory.facts_equal(shared,{"wood":["storage"]})): return {"ok":false,"code":"invalid_install"}
	var payment: Dictionary
	if installations == 0:
		# Preserve the one historical installation receipt for schema40 saves.
		payment = economy.consume_shared("player",{"wood":WOOD_COST,"utility_core":1},"modern_utilities:install",shared)
	else:
		payment = economy.process_shared_stream("player",REINSTALL_STREAM,installations,{"wood":WOOD_COST,"utility_core":1},{},shared)
	if not payment.get("ok",false) or payment.get("duplicate",false): return {"ok":false,"code":payment.get("code","ledger")}
	installed = true
	installations += 1
	if installations == 1: power.install()
	return {"ok":true,"installation":installations}

func pack(economy: RefCounted) -> Dictionary:
	if not installed or removals >= MAX_INSTALLATIONS: return {"ok":false,"code":"not_installed"}
	var returned: Dictionary = economy.process_stream("player",PACK_STREAM,removals+1,{}, {"wood":WOOD_COST,"utility_core":1})
	if not returned.get("ok",false) or returned.get("duplicate",false): return {"ok":false,"code":returned.get("code","ledger")}
	installed = false
	removals += 1
	# The same commissioned battery/filter/tank travels in the unique component.
	# Keeping all counters, charge and unfinished filtering prevents reset exploits.
	return {"ok":true,"removal":removals}

func commissioned() -> bool: return installations > 0

func advance(microseconds: int, period: int, weather: int, intake_ready: bool, economy: RefCounted) -> Dictionary:
	if microseconds < 0 or microseconds > 180000000 or period < 0 or period > 3 or weather < 0 or weather > 2: return {"ok":false,"code":"invalid_step"}
	if not installed: return {"ok":true,"produced":0}
	var stepped_us: int = ((carry_us+microseconds)/STEP)*STEP
	if not power.can_generate(stepped_us,period,weather): return {"ok":false,"code":"counter_limit"}
	var before := produced
	carry_us += microseconds
	while carry_us >= STEP:
		carry_us -= STEP
		if not power.advance(STEP,period,weather).ok: return {"ok":false,"code":"power"}
		if not automatic or not intake_ready or economy.inventory(TANK,"fresh_water") >= 6: continue
		if power.charge < FILTER_COST: continue
		filter_us += STEP
		if filter_us < FILTER_TIME: continue
		var old_power: Dictionary = power.snapshot()
		var debit: Dictionary = power.debit("purifier",produced+1,FILTER_COST)
		var output: Dictionary = economy.process_stream(TANK,"ark_purifier",produced+1,{}, {"fresh_water":1}) if debit.ok else {"ok":false}
		if not output.ok or output.get("duplicate",false):
			power.restore(old_power)
			filter_us = FILTER_TIME-STEP
			continue
		filter_us = 0
		produced += 1
	return {"ok":true,"produced":produced-before}

func wash_error(actor: String, day: int, economy: RefCounted) -> String:
	if not installed or actor not in ACTORS or day < 1 or day > 9999: return "invalid"
	var previous: Dictionary = washes.get(actor,{"day":0,"count":0})
	if day <= int(previous.day): return "already_today"
	if economy.inventory(TANK,"fresh_water") < 1: return "water"
	if power.charge < WASH_COST: return "charge"
	return ""

func wash(actor: String, day: int, economy: RefCounted) -> Dictionary:
	var error := wash_error(actor,day,economy)
	if not error.is_empty(): return {"ok":false,"code":error}
	var previous: Dictionary = washes.get(actor,{"day":0,"count":0})
	var sequence := int(previous.count)+1
	var old_power: Dictionary = power.snapshot()
	var debit: Dictionary = power.debit("wash:"+actor,sequence,WASH_COST)
	if not debit.ok: return {"ok":false,"code":"charge"}
	var payment: Dictionary = economy.process_stream(TANK,"wash:"+actor,sequence,{"fresh_water":1},{})
	if not payment.ok or payment.get("duplicate",false):
		power.restore(old_power)
		return {"ok":false,"code":"ledger"}
	washes[actor] = {"day":day,"count":sequence}
	return {"ok":true,"count":sequence}

func snapshot() -> Dictionary:
	return {"version":2,"salvaged":salvaged,"installed":installed,"automatic":automatic,"carry_us":carry_us,"filter_us":filter_us,"produced":produced,"washes":washes.duplicate(true),"power":power.snapshot(),"installations":installations,"removals":removals}

static func _upgraded(state: Dictionary) -> Dictionary:
	if not Power.integer(state.get("version"),2) or state.version < 1: return {}
	if state.get("version") == 2: return state.duplicate(true)
	if state.size() != 9 or state.get("version") != 1 or not state.get("installed") is bool: return {}
	var result := state.duplicate(true)
	result.version = 2
	result["installations"] = 1 if state.installed else 0
	result["removals"] = 0
	return result

static func valid(state: Dictionary) -> bool:
	state = _upgraded(state)
	if state.size() != 11 or state.get("version") != 2: return false
	for key in ["salvaged","installed","automatic"]:
		if not state.get(key) is bool: return false
	if not Power.integer(state.get("carry_us"),STEP-1) or not Power.integer(state.get("filter_us"),FILTER_TIME-STEP) or int(state.filter_us)%STEP != 0: return false
	if not Power.integer(state.get("produced"),1000000000) or not state.get("power") is Dictionary or not Power.valid(state.power): return false
	if not Power.integer(state.get("installations"),MAX_INSTALLATIONS) or not Power.integer(state.get("removals"),MAX_INSTALLATIONS): return false
	if state.installations-state.removals != (1 if state.installed else 0) or (state.installations > 0 and not state.salvaged): return false
	var commissioned_: bool = state.installations > 0
	if commissioned_ != state.power.solar or commissioned_ != state.power.battery: return false
	if not state.get("washes") is Dictionary or state.washes.size() > 3: return false
	var spent := int(state.produced)*FILTER_COST
	var consumers: Dictionary = {}
	if state.produced > 0: consumers.purifier = {"sequence":state.produced,"amount":FILTER_COST}
	for actor in state.washes:
		var record: Variant = state.washes[actor]
		if actor not in ACTORS or not record is Dictionary or record.size() != 2: return false
		if not Power.integer(record.get("day"),9999) or record.day < 1 or not Power.integer(record.get("count"),9999) or record.count < 1 or record.count > record.day: return false
		spent += int(record.count)*WASH_COST
		consumers["wash:"+actor] = {"sequence":record.count,"amount":WASH_COST}
	if state.power.consumed != spent or not Memory.facts_equal(state.power.consumers,consumers): return false
	return commissioned_ or (state.carry_us == 0 and state.filter_us == 0 and state.produced == 0 and state.washes.is_empty())

func restore(state: Dictionary) -> bool:
	if not valid(state): return false
	state = _upgraded(state)
	salvaged = state.salvaged
	installed = state.installed
	automatic = state.automatic
	carry_us = int(state.carry_us)
	filter_us = int(state.filter_us)
	produced = int(state.produced)
	installations = int(state.installations)
	removals = int(state.removals)
	washes.clear()
	for actor in state.washes:
		washes[actor] = {"day":int(state.washes[actor].day),"count":int(state.washes[actor].count)}
	return power.restore(state.power)

static func matches_save(saved: Dictionary) -> bool:
	if not Power.integer(saved.get("day_count"),9999) or saved.day_count < 1: return false
	var state: Variant = saved.get("modern_utilities")
	if not state is Dictionary or not valid(state): return false
	if not Power.integer(saved.get("schema_version"),preload("res://scripts/modules/ark_save_schema.gd").CURRENT) or saved.schema_version < 40: return false
	if state.version != (2 if saved.schema_version >= 41 else 1): return false
	state = _upgraded(state)
	if not saved.get("learned_blueprint_ids") is Array or saved.learned_blueprint_ids.has(BLUEPRINT) != state.salvaged: return false
	if not saved.get("collected_ids") is Array or saved.collected_ids.has(SOURCE) != state.salvaged: return false
	if state.salvaged and saved.get("pressure_wreck_searched") != true: return false
	if state.installed and saved.get("raft_extension_built") != true: return false
	var modules: Variant = saved.get("modules")
	if not modules is Dictionary or not modules.get("economy") is Dictionary: return false
	var es: Dictionary = modules.economy
	for key in ["sources","inventories","capacities","receipts","streams","totals","cargo","reservations"]:
		if not es.get(key) is Dictionary: return false
	for owner in es.inventories:
		if not owner is String or not es.inventories[owner] is Dictionary: return false
	for cargo in es.cargo.values():
		if not cargo is Dictionary: return false
	var source: Variant = es.sources.get(SOURCE)
	if not source is Dictionary or source.get("resource") != "utility_core" or source.get("remaining") != (0 if state.salvaged else 1) or source.get("region") != "pressure_wreck": return false
	if es.receipts.get("modern_utilities:install",false) != (state.installations > 0) or es.capacities.get(TANK) != 6: return false
	var washes_count := 0
	var expected_streams: Dictionary = {}
	if state.removals > 0: expected_streams[PACK_STREAM] = {"owner":"player","sequence":state.removals,"costs":{},"outputs":{"wood":4,"utility_core":1}}
	if state.installations > 1:
		var reinstall: Variant = es.streams.get(REINSTALL_STREAM)
		if not reinstall is Dictionary or reinstall.size() not in [4,5]: return false
		var expected := {"owner":"player","sequence":state.installations-1,"costs":{"wood":4,"utility_core":1},"outputs":{}}
		if reinstall.has("shared"):
			if not Memory.facts_equal(reinstall.shared,{"wood":["storage"]}): return false
			expected["shared"] = {"wood":["storage"]}
		expected_streams[REINSTALL_STREAM] = expected
	if state.produced > 0: expected_streams.ark_purifier = {"owner":TANK,"sequence":state.produced,"costs":{},"outputs":{"fresh_water":1}}
	for actor in state.washes:
		var record: Dictionary = state.washes[actor]
		if record.day > saved.get("day_count",0): return false
		if actor != "player" and saved.get("traveler_boarded" if actor == "tidekeeper" else "sailmaker_boarded") != true: return false
		washes_count += int(record.count)
		expected_streams["wash:"+actor] = {"owner":TANK,"sequence":record.count,"costs":{"fresh_water":1},"outputs":{}}
	for id in es.streams:
		if (id == "ark_purifier" or str(id).begins_with("wash:") or str(id).begins_with("modern_utilities:")) and not expected_streams.has(id): return false
	for id in expected_streams:
		if not Memory.facts_equal(es.streams.get(id),expected_streams[id]): return false
	if not Memory.facts_equal(es.inventories.get(TANK,{}),({} if state.produced == 0 else {"fresh_water":int(state.produced)-washes_count})): return false
	if not es.inventories.has(TANK) or state.produced-washes_count < 0 or state.produced-washes_count > 6: return false
	var expected_core := 1 if state.salvaged and not state.installed else 0
	for owner in es.inventories:
		if es.inventories[owner].get("utility_core",0) != (expected_core if owner == "player" else 0): return false
		if owner != TANK and es.inventories[owner].get("fresh_water",0) != 0: return false
	for cargo in es.get("cargo",{}).values():
		if cargo.get("resource") in ["utility_core","fresh_water"]: return false
	if es.get("reservations",{}).has(SOURCE): return false
	var wood_totals: Variant = es.totals.get("wood")
	if state.installations > 0 and (not wood_totals is Dictionary or not Power.integer(wood_totals.get("input")) or not Power.integer(wood_totals.get("consumed")) or wood_totals.input < state.removals*4 or wood_totals.consumed < state.installations*4): return false
	return Memory.facts_equal(es.totals.get("utility_core"),{"initial":1,"input":state.removals,"consumed":state.installations,"outflow":0}) and Memory.facts_equal(es.totals.get("fresh_water",{"initial":0,"input":0,"consumed":0,"outflow":0}),{"initial":0,"input":state.produced,"consumed":washes_count,"outflow":0})
