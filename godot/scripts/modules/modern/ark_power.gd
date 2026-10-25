extends RefCounted
## Abstract game charge, not an electrical engineering simulation. Pure data;
## no scene handles, inventory, wall clock, randomness or worker threads.
const CAPACITY := 10000
const MICROS := 1000000
const MAX_TOTAL := 1000000000000
var solar_installed := false
var battery_installed := false
var charge := 0
var generated := 0
var consumed := 0
var curtailed := 0
var remainder := 0
var consumers: Dictionary = {}

func install() -> void:
	solar_installed = true
	battery_installed = true

func can_generate(microseconds: int, period: int, weather: int) -> bool:
	if microseconds < 0 or microseconds > 180000000 or period < 0 or period > 3 or weather < 0 or weather > 2: return false
	var rate: int = [60,140,40,0][period]
	rate = rate * [50,15,100][weather] / 100
	return not solar_installed or generated + (remainder+rate*microseconds)/MICROS <= MAX_TOTAL

func advance(microseconds: int, period: int, weather: int) -> Dictionary:
	if microseconds < 0 or microseconds > MICROS or period < 0 or period > 3 or weather < 0 or weather > 2:
		return {"ok":false,"code":"invalid_step"}
	if not solar_installed or microseconds == 0: return {"ok":true,"generated":0}
	var rate: int = [60,140,40,0][period]
	rate = rate * [50,15,100][weather] / 100
	var numerator: int = remainder + rate * microseconds
	var whole: int = numerator / MICROS
	if generated + whole > MAX_TOTAL: return {"ok":false,"code":"counter_limit"}
	remainder = numerator % MICROS
	generated += whole
	var accepted := mini(whole,CAPACITY-charge) if battery_installed else 0
	charge += accepted
	curtailed += whole - accepted
	return {"ok":true,"generated":whole,"stored":accepted}

func debit(consumer_id: String, sequence: int, amount: int) -> Dictionary:
	if consumer_id.is_empty() or consumer_id.length() > 64 or sequence < 1 or sequence > 1000000000 or amount < 1 or amount > CAPACITY:
		return {"ok":false,"code":"invalid_command"}
	var previous: Dictionary = consumers.get(consumer_id,{"sequence":0,"amount":0})
	if sequence == int(previous.sequence):
		return {"ok":true,"duplicate":true} if amount == int(previous.amount) else {"ok":false,"code":"conflicting_replay"}
	if sequence != int(previous.sequence)+1: return {"ok":false,"code":"stale_or_skipped_sequence"}
	if not consumers.has(consumer_id) and consumers.size() >= 64: return {"ok":false,"code":"consumer_limit"}
	if not battery_installed or charge < amount: return {"ok":false,"code":"insufficient_charge"}
	charge -= amount
	consumed += amount
	consumers[consumer_id] = {"sequence":sequence,"amount":amount}
	return {"ok":true,"duplicate":false}

func snapshot() -> Dictionary:
	return {"version":1,"solar":solar_installed,"battery":battery_installed,"charge":charge,"generated":generated,"consumed":consumed,"curtailed":curtailed,"remainder":remainder,"consumers":consumers.duplicate(true)}

static func integer(value: Variant, maximum: int = MAX_TOTAL) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= 0 and float(value) <= maximum

static func valid(state: Dictionary) -> bool:
	if state.size() != 9 or state.get("version") != 1 or not state.get("solar") is bool or not state.get("battery") is bool: return false
	for field in ["charge","generated","consumed","curtailed","remainder"]:
		if not integer(state.get(field)): return false
	if state.charge > CAPACITY or state.remainder >= MICROS or state.charge != state.generated-state.consumed-state.curtailed: return false
	if not state.battery and (state.charge != 0 or state.consumed != 0): return false
	if not state.solar and (state.generated != 0 or state.remainder != 0): return false
	if not state.get("consumers") is Dictionary or state.consumers.size() > 64: return false
	var lower_bound := 0
	for id in state.consumers:
		var entry: Variant = state.consumers[id]
		if not id is String or id.is_empty() or id.length() > 64 or not entry is Dictionary or entry.size() != 2: return false
		if not integer(entry.get("sequence"),1000000000) or entry.sequence < 1 or not integer(entry.get("amount"),CAPACITY) or entry.amount < 1: return false
		lower_bound += int(entry.amount)
	return state.consumed >= lower_bound and (state.consumed == 0) == state.consumers.is_empty()

func restore(state: Dictionary) -> bool:
	if not valid(state): return false
	solar_installed = state.solar
	battery_installed = state.battery
	charge = int(state.charge)
	generated = int(state.generated)
	consumed = int(state.consumed)
	curtailed = int(state.curtailed)
	remainder = int(state.remainder)
	consumers.clear()
	for id in state.consumers:
		consumers[id] = {"sequence":int(state.consumers[id].sequence),"amount":int(state.consumers[id].amount)}
	return true
