class_name CombatEventPipeline
extends RefCounted

const SCHEMA_VERSION := 1
const MAX_STEPS := 48
const MAX_HISTORY := 12

const PHASES := [
	"before_action",
	"action_begin",
	"action_content",
	"action_end",
	"after_action",
	"before_enemy",
	"enemy_begin",
	"enemy_content",
	"enemy_end",
	"after_enemy",
	"turn_end",
	"combat_end",
]

const KINDS := [
	"action", "damage", "shield", "heal", "resource", "status", "signature",
	"counter", "phase_shift", "intent", "outcome", "note",
]

const ACTORS := ["player", "enemy", "system"]
const TARGETS := ["player", "enemy", "battle", "none"]


static func begin(battle: Dictionary, action_id: String) -> Dictionary:
	var battle_id := str(battle.get("id", "battle"))
	var turn := maxi(1, int(battle.get("turn", 1)))
	return {
		"schema_version": SCHEMA_VERSION,
		"id": "%s:%d:%s" % [battle_id, turn, action_id],
		"battle_id": battle_id,
		"turn": turn,
		"action_id": action_id.left(48),
		"phase": "created",
		"status": "running",
		"cancel_reason": "",
		"steps": [],
		"result": {},
	}


static func advance(event: Dictionary, next_phase: String) -> Dictionary:
	if str(event.get("status", "")) != "running":
		return {"ok": false, "code": "event_not_running"}
	var next_index := PHASES.find(next_phase)
	if next_index < 0:
		return {"ok": false, "code": "unknown_phase", "phase": next_phase}
	var current_phase := str(event.get("phase", "created"))
	var current_index := -1 if current_phase == "created" else PHASES.find(current_phase)
	if current_index < -1 or next_index <= current_index:
		return {"ok": false, "code": "invalid_phase_order", "phase": next_phase}
	event["phase"] = next_phase
	return {"ok": true, "code": "phase_advanced", "phase": next_phase}


static func emit(event: Dictionary, kind: String, actor: String, target: String,
		text: String, value: int = 0, cue: String = "", data: Dictionary = {}) -> Dictionary:
	if str(event.get("status", "")) != "running":
		return {"ok": false, "code": "event_not_running"}
	var phase := str(event.get("phase", "created"))
	if not PHASES.has(phase):
		return {"ok": false, "code": "event_phase_required"}
	if not KINDS.has(kind) or not ACTORS.has(actor) or not TARGETS.has(target):
		return {"ok": false, "code": "invalid_step_contract"}
	var steps_value: Variant = event.get("steps", [])
	var steps: Array = steps_value if steps_value is Array else []
	if steps.size() >= MAX_STEPS:
		return {"ok": false, "code": "event_step_limit"}
	var step := {
		"index": steps.size(),
		"phase": phase,
		"kind": kind,
		"actor": actor,
		"target": target,
		"text": text.strip_edges().left(240),
		"value": value,
		"cue": cue.strip_edges().left(64),
		"data": _json_dictionary(data),
	}
	steps.append(step)
	event["steps"] = steps
	return {"ok": true, "code": "step_emitted", "step": step}


static func cancel(event: Dictionary, reason: String) -> Dictionary:
	if str(event.get("status", "")) != "running":
		return {"ok": false, "code": "event_not_running"}
	event["status"] = "cancelled"
	event["cancel_reason"] = reason.strip_edges().left(120)
	return {"ok": true, "code": "event_cancelled"}


static func complete(event: Dictionary, result: Dictionary = {}) -> Dictionary:
	if str(event.get("status", "")) != "running":
		return {"ok": false, "code": "event_not_running"}
	if str(event.get("phase", "created")) != "combat_end":
		var advanced := advance(event, "combat_end")
		if not bool(advanced.get("ok", false)):
			return advanced
	event["status"] = "completed"
	event["result"] = _json_dictionary(result)
	event["trace_hash"] = trace_hash(event)
	return {"ok": true, "code": "event_completed", "event": event}


static func trace_hash(event: Dictionary) -> String:
	var stable := {
		"schema_version": int(event.get("schema_version", 0)),
		"id": str(event.get("id", "")),
		"battle_id": str(event.get("battle_id", "")),
		"turn": int(event.get("turn", 0)),
		"action_id": str(event.get("action_id", "")),
		"phase": str(event.get("phase", "")),
		"status": str(event.get("status", "")),
		"cancel_reason": str(event.get("cancel_reason", "")),
		"steps": (event.get("steps", []) as Array).duplicate(true),
		"result": _json_dictionary(event.get("result", {})),
	}
	return JSON.stringify(stable).sha256_text()


static func validate(event: Dictionary) -> Dictionary:
	if int(event.get("schema_version", 0)) != SCHEMA_VERSION or \
			str(event.get("id", "")).is_empty() or str(event.get("battle_id", "")).is_empty():
		return {"ok": false, "code": "invalid_event_header"}
	var status := str(event.get("status", ""))
	if status not in ["running", "completed", "cancelled"]:
		return {"ok": false, "code": "invalid_event_status"}
	var phase := str(event.get("phase", "created"))
	if phase != "created" and not PHASES.has(phase):
		return {"ok": false, "code": "invalid_event_phase"}
	var steps_value: Variant = event.get("steps", [])
	if not steps_value is Array or (steps_value as Array).size() > MAX_STEPS:
		return {"ok": false, "code": "invalid_event_steps"}
	var previous_phase_index := -1
	for index in range((steps_value as Array).size()):
		var step_value: Variant = (steps_value as Array)[index]
		if not step_value is Dictionary:
			return {"ok": false, "code": "invalid_event_step", "index": index}
		var step: Dictionary = step_value
		var phase_index := PHASES.find(str(step.get("phase", "")))
		if int(step.get("index", -1)) != index or phase_index < previous_phase_index or \
				not KINDS.has(str(step.get("kind", ""))) or \
				not ACTORS.has(str(step.get("actor", ""))) or \
				not TARGETS.has(str(step.get("target", ""))):
			return {"ok": false, "code": "invalid_event_step", "index": index}
		previous_phase_index = phase_index
	if status == "completed":
		if phase != "combat_end" or str(event.get("trace_hash", "")) != trace_hash(event):
			return {"ok": false, "code": "invalid_completed_event"}
	return {"ok": true, "code": "valid"}


static func append_history(battle: Dictionary, event: Dictionary) -> void:
	if not bool(validate(event).get("ok", false)):
		return
	var history_value: Variant = battle.get("event_history", [])
	var history: Array = history_value.duplicate(true) if history_value is Array else []
	history.append(event.duplicate(true))
	while history.size() > MAX_HISTORY:
		history.pop_front()
	battle["event_history"] = history


static func normalize_history(value: Variant) -> Array:
	var source: Array = value if value is Array else []
	var result: Array = []
	for event_value in source:
		if event_value is Dictionary and bool(validate(event_value).get("ok", false)):
			result.append((event_value as Dictionary).duplicate(true))
	while result.size() > MAX_HISTORY:
		result.pop_front()
	return result


static func _json_dictionary(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var parsed: Variant = JSON.parse_string(JSON.stringify(value))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}
