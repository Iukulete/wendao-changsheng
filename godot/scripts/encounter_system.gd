class_name EncounterSystem
extends RefCounted

## Contextual combat opportunities. Combat is a response to a visible threat,
## not a permanently enabled resource button.

const VERSION := 1
const DEFAULT_DURATION_TURNS := 3


static func normalize(state: Dictionary) -> Dictionary:
	var source: Variant = state.get("encounter", {})
	var encounter: Dictionary = source.duplicate(true) if source is Dictionary else {}
	var generation := clampi(int(state.get("generation", 1)), 1, 100000)
	if int(encounter.get("generation", generation)) != generation:
		encounter["active"] = false
		encounter["source"] = ""
		encounter["title"] = ""
		encounter["detail"] = ""
	encounter["version"] = VERSION
	encounter["generation"] = generation
	encounter["active"] = bool(encounter.get("active", false))
	encounter["source"] = str(encounter.get("source", "")).left(32)
	encounter["title"] = str(encounter.get("title", "")).left(96)
	encounter["detail"] = str(encounter.get("detail", "")).left(240)
	encounter["offered_turn"] = clampi(int(encounter.get("offered_turn", 0)), 0, 0x7fffffff)
	encounter["expires_turn"] = clampi(int(encounter.get("expires_turn", 0)), 0, 0x7fffffff)
	encounter["offered_total"] = clampi(int(encounter.get("offered_total", 0)), 0, 1000000)
	encounter["resolved_total"] = clampi(int(encounter.get("resolved_total", 0)), 0, 1000000)
	encounter["expired_total"] = clampi(int(encounter.get("expired_total", 0)), 0, 1000000)
	encounter["last_result"] = str(encounter.get("last_result", "")).left(32)
	if not encounter.active:
		encounter["source"] = ""
		encounter["title"] = ""
		encounter["detail"] = ""
	state["encounter"] = encounter
	return encounter


static func offer(state: Dictionary, source: String, title: String, detail: String,
		duration_turns: int = DEFAULT_DURATION_TURNS) -> Dictionary:
	var encounter := normalize(state)
	if bool(encounter.active):
		return {"ok": false, "code": "encounter_active", "encounter": encounter.duplicate(true)}
	var current_turn := clampi(int(state.get("turn", 0)), 0, 0x7fffffff)
	encounter["active"] = true
	encounter["source"] = source.left(32)
	encounter["title"] = title.left(96)
	encounter["detail"] = detail.left(240)
	encounter["offered_turn"] = current_turn
	encounter["expires_turn"] = mini(0x7fffffff, current_turn + maxi(1, duration_turns))
	encounter["offered_total"] = int(encounter.offered_total) + 1
	encounter["last_result"] = "offered"
	state["encounter"] = encounter
	return {"ok": true, "code": "encounter_offered", "encounter": encounter.duplicate(true),
		"message": "敌踪已现：%s。%s" % [title, detail]}


static func offer_from_choice(state: Dictionary, event: Dictionary,
		choice: Dictionary) -> Dictionary:
	var deltas: Dictionary = choice.get("deltas", {})
	var path_deltas: Dictionary = choice.get("path_deltas", {})
	var total_events := int((state.get("player", {}) as Dictionary).get("total_events", 0))
	var should_offer := int(deltas.get("enmity", 0)) > 0 or \
		int(path_deltas.get("defiance", 0)) >= 2 or (total_events > 0 and total_events % 2 == 0)
	if not should_offer:
		return {"ok": true, "code": "choice_left_no_enemy", "offered": false}
	var event_title := str(event.get("title", "无名因果")).trim_prefix("【").left(42)
	return offer(state, "event", "因果追兵 · %s" % event_title,
		"你刚才的抉择在山河中留下了回声，三次年轮内可追索这道杀机。")


static func expire_if_needed(state: Dictionary) -> Dictionary:
	var encounter := normalize(state)
	if not bool(encounter.active):
		return {"ok": true, "code": "no_encounter", "expired": false}
	var current_turn := int(state.get("turn", 0))
	if current_turn <= int(encounter.expires_turn):
		return {"ok": true, "code": "encounter_active", "expired": false,
			"encounter": encounter.duplicate(true)}
	var title := str(encounter.title)
	encounter["active"] = false
	encounter["expired_total"] = int(encounter.expired_total) + 1
	encounter["last_result"] = "expired"
	state["encounter"] = encounter
	var world: Dictionary = state.get("world", {})
	world["stability"] = clampi(int(world.get("stability", 65)) - 3, 0, 100)
	world["era_pressure"] = clampi(int(world.get("era_pressure", 0)) + 2, 0, 100)
	state["world"] = world
	return {"ok": true, "code": "encounter_expired", "expired": true,
		"message": "敌踪【%s】已从山河中消散；你没有回应，局势稳定度下降。" % title}


static func consume(state: Dictionary) -> Dictionary:
	var encounter := normalize(state)
	if not bool(encounter.active):
		return {"ok": false, "code": "no_encounter"}
	var snapshot := encounter.duplicate(true)
	encounter["active"] = false
	encounter["resolved_total"] = int(encounter.resolved_total) + 1
	encounter["last_result"] = "engaged"
	state["encounter"] = encounter
	return {"ok": true, "code": "encounter_consumed", "encounter": snapshot}


static func summary(state: Dictionary) -> Dictionary:
	var encounter := normalize(state)
	if not bool(encounter.active):
		return {"active": false, "last_result": str(encounter.last_result)}
	var remaining := int(encounter.expires_turn) - int(state.get("turn", 0))
	return {
		"active": remaining >= 0,
		"title": str(encounter.title),
		"detail": str(encounter.detail),
		"source": str(encounter.source),
		"remaining_turns": maxi(0, remaining),
	}
