extends "res://scripts/modules/leisure/ark_fishing.gd"
## Isolated provisional paid-cast rhythm. Payment belongs to BaitAuthority.begin,
## never this battle. This transient object and its opaque ticket are not saved.
const BaitAuthority = preload("res://scripts/modules/leisure/ark_bait_fishing.gd")
const INITIAL_DISTANCE := 1.35
const BURST_SECONDS := 1.0
const PERIOD_SECONDS := 5.0
const BURST_FORCE := 0.24
var total_distance := INITIAL_DISTANCE
var attempt_sequence := 0
var _authority: RefCounted
var _paid_economy: RefCounted
var _paid_ticket: RefCounted
var _ticket_closed := true
var _settled := false

## Ordinary and automatic retry casts must instantiate the original free rules.
func cast(_economy: RefCounted, _weather: float, _rod_id: String = "basic") -> bool:
	return false

func cast_paid(economy: RefCounted, weather: float, rod_id: String, authority: RefCounted, payment: Dictionary) -> bool:
	if active() or not authority is BaitAuthority or not authority.active(): return false
	var next_profile: Dictionary = RodProfiles.profile(rod_id)
	if next_profile.is_empty() or payment.get("ok") != true or payment.get("duplicate", false): return false
	if not payment.get("ticket") is RefCounted: return false
	for key in ["attempt_sequence", "catch_sequence"]:
		if not payment.get(key) is int or payment[key] < 1 or payment[key] > BaitAuthority.LIMIT: return false
	var authorized: Dictionary = authority.ticket_info(economy, payment.ticket)
	if authorized.is_empty() or authorized.get("attempt_sequence") != payment.attempt_sequence or authorized.get("catch_sequence") != payment.catch_sequence: return false
	_rod_profile = next_profile
	_authority = authority; _paid_economy = economy; _paid_ticket = payment.ticket
	_ticket_closed = false; _settled = false
	attempt_sequence = int(payment.attempt_sequence)
	sequence = int(payment.catch_sequence) # Independent successful-catch sequence for the UI event.
	phase = "waiting"; elapsed = 0.0; tension = 0.3; total_distance = INITIAL_DISTANCE; distance = total_distance
	stress = 0.0; slack = 0.0; held = false; released = false; pull = false
	wind = clampf(weather, 0.0, 1.0); reason = ""
	wait_time = 2.8 + float(attempt_sequence % 3) * 0.55
	return true

func progress() -> float:
	return clampf(1.0 - distance / total_distance, 0.0, 1.0)

func cancel() -> void:
	_close_ticket()
	super.cancel()

func _close_ticket() -> void:
	if _ticket_closed: return
	_ticket_closed = true
	if _authority != null and _paid_ticket != null: _authority.cancel(_paid_ticket)
	_paid_ticket = null

func step(delta: float, weather: float) -> void:
	wind = clampf(weather, 0.0, 1.0)
	var remaining := minf(delta, 0.25) # Preserve the free-cast suspension clamp and substep.
	while remaining > 0.0:
		var dt := minf(remaining, 0.02); remaining -= dt
		elapsed += dt
		if phase == "waiting" and elapsed >= wait_time:
			phase = "bite"; elapsed = 0.0
		elif phase == "bite" and elapsed > float(_rod_profile.bite_window):
			phase = "failed"; reason = "鱼已脱钩：下次浮漂下沉时按 E 提竿。鱼饵已用掉，鱼竿完好。"
		elif phase == "fighting":
			pull = fmod(elapsed, PERIOD_SECONDS) < BURST_SECONDS
			# Rest removes fish force only; the original weather force still applies.
			var force := (BURST_FORCE if pull else 0.0) + wind * 0.13
			tension = clampf(tension + ((0.31 + force) if held else (-0.38 + force)) * dt, 0.0, 1.0)
			if held and tension < 0.9: distance -= dt * (0.17 if not pull else 0.075) * float(_rod_profile.reel_scale)
			elif not held: distance = minf(total_distance, distance + dt * 0.025)
			stress = stress + dt if tension >= 0.97 else 0.0
			slack = slack + dt if tension <= 0.03 else 0.0
			if stress >= float(_rod_profile.stress_limit):
				phase = "failed"; reason = "线绷得太紧，鱼挣脱了。鱼饵已用掉，鱼竿完好。"
			elif slack >= 2.0:
				phase = "failed"; reason = "线松得太久，鱼游走了。鱼饵已用掉，鱼竿完好。"
			elif distance <= 0.0: phase = "landed"; held = false
		if phase == "failed": _close_ticket()

func settle(economy: RefCounted) -> Dictionary:
	if phase != "landed": return {"ok":false, "code":"not_landed"}
	if _settled or _ticket_closed or _authority == null: return {"ok":false, "code":"closed_ticket"}
	if economy != _paid_economy: return {"ok":false, "code":"wrong_economy"}
	_settled = true # Set before dispatch, so even a repeated callback cannot retry.
	_ticket_closed = true
	var result: Dictionary = _authority.settle(economy, _paid_ticket)
	# A rejected wrong/stale token may leave an authority active; cancellation is
	# token-scoped, so it cannot close any newer or unrelated legitimate ticket.
	if _authority.active(): _authority.cancel(_paid_ticket)
	_paid_ticket = null
	phase = "caught" if result.get("ok", false) else "failed"
	reason = "肥鱼 ×1 已放入背包；可存进储物箱，或煮成三份鱼汤。" if phase == "caught" else "这次肥鱼未入库，鱼饵已用掉；可收竿后再试。"
	return result
