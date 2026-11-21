extends RefCounted
## A transient cast. Only a completed catch enters the existing bounded ledger.
const Memory = preload("res://scripts/modules/memory/ark_memory.gd")
const STREAM := "fishing:catch"
const RodProfiles = preload("res://scripts/modules/leisure/ark_fishing_rod_profiles.gd")
var _rod_profile:Dictionary = RodProfiles.profile("basic")
func rod_profile() -> Dictionary: return _rod_profile.duplicate(true)
const Cooking = preload("res://scripts/modules/food/ark_manual_cooking.gd")
var phase := "idle"
var elapsed := 0.0
var tension := 0.3
var distance := 1.0
var stress := 0.0
var slack := 0.0
var held := false
var released := false
var pull := false
var wind := 0.0
var reason := ""
var sequence := 0
var wait_time := 3.0

func active() -> bool: return phase != "idle"

func cast(economy: RefCounted, weather: float, rod_id: String = "basic") -> bool:
	var next_profile:Dictionary=RodProfiles.profile(rod_id)
	if next_profile.is_empty(): return false
	_rod_profile=next_profile
	sequence = int(economy.snapshot().streams.get(STREAM, {}).get("sequence", 0)) + 1
	phase = "waiting"; elapsed = 0.0; tension = 0.3; distance = 1.0
	stress = 0.0; slack = 0.0; held = false; released = false; pull = false
	wind = clampf(weather, 0.0, 1.0); reason = ""
	wait_time = 2.8 + float(sequence % 3) * 0.55
	return true

func press() -> void:
	if not released: return
	if phase == "bite": phase = "fighting"; elapsed = 0.0; held = true
	elif phase == "fighting": held = true

func release() -> void:
	held = false; released = true

func cancel() -> void:
	phase = "idle"; held = false; released = false

func step(delta: float, weather: float) -> void:
	wind = clampf(weather, 0.0, 1.0)
	var remaining := minf(delta, 0.25) # A suspended window cannot lose a whole cast.
	while remaining > 0.0:
		var dt := minf(remaining, 0.02); remaining -= dt
		elapsed += dt
		if phase == "waiting" and elapsed >= wait_time:
			phase = "bite"; elapsed = 0.0
		elif phase == "bite" and elapsed > float(_rod_profile.bite_window):
			phase = "failed"; reason = "鱼已脱钩：下次浮漂下沉时按 E 提竿。"
		elif phase == "fighting":
			pull = fmod(elapsed, 4.0) < 1.5
			var force := (0.18 if pull else 0.0) + wind * 0.13
			tension = clampf(tension + ((0.31 + force) if held else (-0.38 + force)) * dt, 0.0, 1.0)
			if held and tension < 0.9: distance -= dt * (0.17 if not pull else 0.075) * float(_rod_profile.reel_scale)
			elif not held: distance = minf(1.0, distance + dt * 0.025)
			stress = stress + dt if tension >= 0.97 else 0.0
			slack = slack + dt if tension <= 0.03 else 0.0
			if stress >= float(_rod_profile.stress_limit):
				phase = "failed"; reason = "线绷得太紧，鱼挣脱了。鱼竿完好，可以再试。"
			elif slack >= 2.0:
				phase = "failed"; reason = "线松得太久，鱼游走了。可以再试。"
			elif distance <= 0.0: phase = "landed"; held = false

func settle(economy: RefCounted) -> Dictionary:
	if phase != "landed": return {"ok":false,"code":"not_landed"}
	var result: Dictionary = economy.process_stream("player", STREAM, sequence, {}, {"fish":1})
	phase = "caught" if result.get("ok", false) else "failed"
	reason = "鲜鱼 ×1 已放入背包；可存进本舟储物箱。" if phase == "caught" else "背包无法接收，这次未入库。可收竿后再试。"
	return result

static func matches_save(state: Dictionary) -> bool:
	if not Cooking.matches_save(state): return false
	if state.has("schema_version") and not _quantity(state.schema_version): return false
	var modules = state.get("modules", {})
	if not modules is Dictionary: return false
	var economy = modules.get("economy", {})
	if not economy is Dictionary: return false
	for key in ["inventories","sources","cargo","streams","totals","flows"]:
		if not economy.get(key,{}) is Dictionary: return false
	var count := 0
	for owner in economy.get("inventories", {}):
		var inventory = economy.inventories[owner]
		if not inventory is Dictionary: return false
		var amount = inventory.get("fish", 0)
		if not _quantity(amount): return false
		if amount > 0 and owner not in ["player","storage_food"]: return false
		count += int(amount)
	for key in ["sources","cargo"]:
		for entry in economy.get(key, {}).values():
			if not entry is Dictionary or entry.get("resource") == "fish": return false
	var streams: Dictionary = economy.get("streams", {})
	for id in streams:
		var entry = streams[id]
		if not entry is Dictionary: return false
		if not entry.get("costs",{}) is Dictionary or not entry.get("outputs",{}) is Dictionary: return false
		if str(id).begins_with("fishing:") and id != STREAM: return false
		if id not in [STREAM, Cooking.STREAM] and (entry.get("costs",{}).has("fish") or entry.get("outputs",{}).has("fish")): return false
	var fish_flow := false
	for flow in economy.get("flows",{}).values():
		if not flow is Dictionary or not flow.get("moves",[]) is Array: return false
		for move in flow.get("moves",[]):
			if not move is Dictionary: return false
			if move.get("resource") == "fish": fish_flow = true
	var ledger = streams.get(STREAM, {})
	if (count > 0 or not ledger.is_empty() or fish_flow or economy.get("totals",{}).has("fish")) and int(state.get("schema_version",0)) < 44: return false
	if ledger.is_empty(): return Cooking.cooked(state) == 0 and count == 0 and not fish_flow and not economy.get("totals", {}).has("fish")
	if ledger.size() != 4 or ledger.get("owner") != "player" or ledger.get("costs") != {} or not Memory.facts_equal(ledger.get("outputs"), {"fish":1}): return false
	var sequence_ = ledger.get("sequence", 0)
	if not _quantity(sequence_) or sequence_ < 1: return false
	var cooked_count := Cooking.cooked(state)
	return cooked_count >= 0 and cooked_count <= int(sequence_) and count + cooked_count == int(sequence_) and Memory.facts_equal(economy.get("totals", {}).get("fish"), {"initial":0,"input":int(sequence_),"consumed":cooked_count,"outflow":0})

static func _quantity(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= 1000000000 and value == floor(float(value))
