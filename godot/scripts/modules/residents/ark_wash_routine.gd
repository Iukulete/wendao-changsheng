extends RefCounted
## One station, two bounded residents. Intents only: this module cannot move a
## scene actor, consume stock/power or invent a memory. Unfinished work is
## intentionally transient; load/cancel restarts the two-second action unpaid.
const ACTORS := ["tidekeeper","sailmaker"]
const WASH_US := 2000000
var owner := ""
var phase := "idle"
var elapsed_us := 0
var cursor := 0

func cancel() -> void:
	owner = ""
	phase = "idle"
	elapsed_us = 0

func reconcile(eligible: Array) -> Dictionary:
	if eligible.size() > 2: return {"ok":false}
	var seen: Array = []
	for actor in eligible:
		if actor not in ACTORS or actor in seen: return {"ok":false}
		seen.append(actor)
	var previous := owner
	if not owner.is_empty() and owner not in eligible: cancel()
	if owner.is_empty():
		for offset in 2:
			var candidate: String = ACTORS[(cursor+offset)%2]
			if candidate in eligible:
				owner = candidate
				phase = "walking"
				break
	return {"ok":true,"owner":owner,"changed":owner != previous}

func advance(microseconds: int, eligible: Array, arrived: bool) -> Dictionary:
	if microseconds < 0 or microseconds > 250000: return {"ok":false,"code":"invalid_step"}
	var selection := reconcile(eligible)
	if not selection.ok: return {"ok":false,"code":"invalid_eligibility"}
	if owner.is_empty(): return {"ok":true,"owner":"","intent":"idle","settle":false}
	if selection.changed: return {"ok":true,"owner":owner,"intent":"walk_to_station","settle":false}
	if phase == "settling": return {"ok":true,"owner":owner,"intent":"await_settlement","settle":false}
	if not arrived:
		phase = "walking"
		elapsed_us = 0
		return {"ok":true,"owner":owner,"intent":"walk_to_station","settle":false}
	phase = "washing"
	elapsed_us = mini(WASH_US,elapsed_us+microseconds)
	if elapsed_us == WASH_US:
		phase = "settling"
		return {"ok":true,"owner":owner,"intent":"settle_actual_wash","settle":true}
	return {"ok":true,"owner":owner,"intent":"wash_at_station","settle":false}

func acknowledge(actor: String, success: bool) -> Dictionary:
	if actor != owner or phase != "settling": return {"ok":false}
	cursor = (ACTORS.find(owner)+1)%2
	cancel()
	return {"ok":true,"completed":success}

func view() -> Dictionary:
	return {"owner":owner,"phase":phase,"elapsed_us":elapsed_us,"cursor":cursor}
