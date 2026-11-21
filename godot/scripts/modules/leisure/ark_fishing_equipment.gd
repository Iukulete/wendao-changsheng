extends RefCounted
## Equipment ownership is a fixed, conserved wood transaction, not a new resource.
const Memory = preload("res://scripts/modules/memory/ark_memory.gd")
const PREFIX := "gear:"
const EVENT := "gear_equipped"
const IDS := ["basic", "light", "resilient"]
const COST := 2

static func stream(id: String) -> String: return "gear:craft:" + id + "_v1"
static func owned(economy: RefCounted, id: String) -> bool:
	if id == "basic": return true
	return id in IDS and valid_economy(economy.snapshot()) and economy.snapshot().streams.has(stream(id))

static func craft(economy: RefCounted, id: String, use_storage: bool) -> Dictionary:
	if id not in ["light", "resilient"]: return {"ok":false,"code":"unknown_gear"}
	if not valid_economy(economy.snapshot()): return {"ok":false,"code":"invalid_gear"}
	if owned(economy,id): return {"ok":true,"duplicate":true}
	if int(economy.snapshot().totals.get("wood",{}).get("consumed",0)) > 1000000000-COST: return {"ok":false,"code":"quantity_limit"}
	return economy.process_shared_stream("player",stream(id),1,{"wood":COST},{},{"wood":["storage"]} if use_storage else {})

static func selected(memories: RefCounted) -> String:
	var known: Dictionary = memories.latest(EVENT)
	if not known.known: return "basic"
	var facts:Dictionary=known.event.facts
	return str(facts.get("id","")) if facts.get("profile_version")==1 and facts.get("id") in IDS else ""

static func equip(economy: RefCounted, memories: RefCounted, id: String, day: int, period: int) -> Dictionary:
	if id not in IDS or not owned(economy,id): return {"ok":false,"code":"not_owned"}
	if not matches_bundle({"economy":economy.snapshot(),"memories":memories.snapshot()}): return {"ok":false,"code":"invalid_gear"}
	if selected(memories)==id: return {"ok":true,"duplicate":true}
	var event: Dictionary = memories.record(EVENT,{"profile_version":1,"id":id},day,period)
	return {"ok":not event.is_empty(),"code":"ok" if not event.is_empty() else "memory_limit"}

static func valid_economy(e: Dictionary) -> bool:
	if not e.get("streams") is Dictionary or not e.get("flows") is Dictionary: return false
	var count:=0
	for id in e.streams:
		if not str(id).begins_with(PREFIX): continue
		if id not in [stream("light"),stream("resilient")]: return false
		count+=1
		var row = e.streams[id]
		var exact := {"owner":"player","sequence":1,"costs":{"wood":COST},"outputs":{}}
		if row is Dictionary and row.has("shared"): exact["shared"]={"wood":["storage"]}
		if not Memory.facts_equal(row,exact): return false
	if count>0:
		if not e.get("totals") is Dictionary or not e.totals.get("wood") is Dictionary: return false
		var consumed=e.totals.wood.get("consumed")
		if not (consumed is int or consumed is float) or not is_finite(float(consumed)) or consumed< COST*count or consumed>1000000000 or consumed!=floor(float(consumed)): return false
	for id in e.flows:
		if str(id).begins_with(PREFIX): return false
	return true

static func matches_bundle(bundle: Dictionary) -> bool:
	if not bundle.get("economy") is Dictionary or not bundle.get("memories") is Dictionary: return false
	var e:Dictionary=bundle.economy
	if not valid_economy(e): return false
	var memory=Memory.new()
	if not memory.restore(bundle.memories): return false
	# Check retained history as well as the durable current selection. Never repair
	# an unknown future version by silently switching to basic and saving over it.
	var entries:Array=memory.events()
	for event in memory.snapshot().durable.values(): entries.append(event)
	for event in entries:
		if str(event.id).begins_with("gear_") and event.id != EVENT: return false
		if event.id != EVENT: continue
		var facts=event.facts
		if not facts is Dictionary or facts.get("id") not in IDS: return false
		if not Memory.facts_equal(facts,{"profile_version":1,"id":facts.id}): return false
		if facts.id!="basic" and not e.streams.has(stream(facts.id)): return false
	return true

static func compatibility(bundle: Variant) -> Dictionary:
	if not bundle is Dictionary: return {"ok":false,"code":"invalid_state"}
	# Future gear data must use the existing two-slot unsupported-version guard,
	# not corrupt-file recovery, which might otherwise overwrite its primary.
	var e=bundle.get("economy",{})
	if e is Dictionary:
		for field in ["streams","flows"]:
			var rows=e.get(field,{})
			if rows is Dictionary:
				for id in rows:
					if str(id).begins_with(PREFIX) and (field=="flows" or id not in [stream("light"),stream("resilient")]): return {"ok":false,"code":"unsupported_version"}
	var m=bundle.get("memories",{})
	if m is Dictionary:
		var entries:Array=[]
		if m.get("events") is Array: entries.append_array(m.events)
		if m.get("durable") is Dictionary: entries.append_array(m.durable.values())
		for event in entries:
			if not event is Dictionary: continue
			var id=str(event.get("id",""))
			if id.begins_with("gear_") and id!=EVENT: return {"ok":false,"code":"unsupported_version"}
			var facts=event.get("facts",{})
			if id==EVENT and facts is Dictionary:
				var version=facts.get("profile_version")
				if (version is int or version is float) and is_finite(float(version)) and version>1: return {"ok":false,"code":"unsupported_version"}
				if facts.get("id") is String and facts.id not in IDS: return {"ok":false,"code":"unsupported_version"}
	return {"ok":true} if matches_bundle(bundle) else {"ok":false,"code":"invalid_state"}

static func has_data(bundle: Variant) -> bool:
	if not bundle is Dictionary: return false
	var e=bundle.get("economy",{})
	if e is Dictionary:
		for field in ["streams","flows"]:
			var rows=e.get(field,{})
			if rows is Dictionary:
				for id in rows:
					if str(id).begins_with(PREFIX): return true
	var m=bundle.get("memories",{})
	if m is Dictionary:
		if m.get("durable") is Dictionary:
			for id in m.durable:
				if str(id).begins_with("gear_"): return true
		if m.get("events") is Array:
			for event in m.events:
				if event is Dictionary and str(event.get("id","")).begins_with("gear_"): return true
	return false

static func check_state(state: Dictionary) -> Dictionary:
	var bundle=state.get("modules")
	var contains_gear:=has_data(bundle)
	if int(state.get("schema_version",0))<45 and not contains_gear: return {"ok":true}
	var result:=compatibility(bundle)
	if not result.get("ok",false): return result
	if int(state.get("schema_version",0))<45 and contains_gear: return {"ok":false,"code":"invalid_state"}
	return {"ok":true}
