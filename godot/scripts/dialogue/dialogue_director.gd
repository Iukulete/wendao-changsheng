class_name DialogueDirector
extends RefCounted

signal node_changed(node: Dictionary)
signal combat_requested(request: Dictionary)
signal dialogue_finished(result: Dictionary)

const RepositoryScript = preload("res://scripts/dialogue/dialogue_repository.gd")
const ConditionEvaluatorScript = preload("res://scripts/dialogue/condition_evaluator.gd")
const EffectExecutorScript = preload("res://scripts/dialogue/effect_executor.gd")
const CombatBridgeScript = preload("res://scripts/dialogue/combat_bridge.gd")
const SaveAdapterScript = preload("res://scripts/dialogue/story_save_adapter.gd")

var state: Dictionary = {}
var scene: Dictionary = {}
var scene_id := ""
var current_node_id := ""
var active := false
var last_error := ""


func start(target_scene_id: String, target_state: Dictionary) -> Dictionary:
	var loaded := RepositoryScript.load_scene(target_scene_id)
	var validation := RepositoryScript.validate_scene(loaded)
	if not bool(validation.get("ok", false)):
		last_error = str(validation.get("code", "invalid_dialogue_scene"))
		return {"ok": false, "code": last_error, "scene_id": target_scene_id}
	state = target_state
	scene = loaded
	scene_id = target_scene_id
	current_node_id = str(scene.get("entry_node", ""))
	active = true
	last_error = ""
	SaveAdapterScript.normalize(state)
	_save_cursor("dialogue")
	return _process_until_interactive()


func current_node() -> Dictionary:
	for node_value in (scene.get("nodes", []) as Array):
		if node_value is Dictionary and str((node_value as Dictionary).get("id", "")) == current_node_id:
			return (node_value as Dictionary).duplicate(true)
	return {}


func advance() -> Dictionary:
	if not active:
		return {"ok": false, "code": "dialogue_not_active"}
	if CombatBridgeScript.has_pending(state):
		return {"ok": false, "code": "dialogue_waiting_for_combat"}
	var node := current_node()
	if node.is_empty():
		return _fail("missing_current_dialogue_node")
	var node_type := str(node.get("type", ""))
	if node_type not in ["line", "end"]:
		return _process_until_interactive()
	if node_type == "end":
		return _finish(str(node.get("result", "completed")))
	return _move_to(str(node.get("next", "")))


func choose(choice_id: String) -> Dictionary:
	if not active:
		return {"ok": false, "code": "dialogue_not_active"}
	if CombatBridgeScript.has_pending(state):
		return {"ok": false, "code": "dialogue_waiting_for_combat"}
	var node := current_node()
	if str(node.get("type", "")) != "choice":
		return {"ok": false, "code": "dialogue_choice_not_expected"}
	for choice_value in (node.get("choices", []) as Array):
		if not choice_value is Dictionary:
			continue
		var choice: Dictionary = choice_value
		if str(choice.get("id", "")) != choice_id:
			continue
		if not ConditionEvaluatorScript.evaluate(choice.get("condition"), state):
			return {"ok": false, "code": "dialogue_choice_locked", "choice_id": choice_id}
		var choice_effects: Variant = choice.get("effects", [])
		var effect_result := EffectExecutorScript.apply_effects(state, choice_effects,
				"choice:%s:%s:%s" % [scene_id, current_node_id, choice_id])
		if not bool(effect_result.get("ok", false)):
			return effect_result
		return _move_to(str(choice.get("next", "")))
	return {"ok": false, "code": "unknown_dialogue_choice", "choice_id": choice_id}


func resume_after_combat(outcome: String) -> Dictionary:
	var result := CombatBridgeScript.finish(state, outcome)
	if not bool(result.get("ok", false)):
		return result
	if str(result.get("scene_id", "")) != scene_id:
		return _fail("combat_return_scene_mismatch")
	current_node_id = str(result.get("next_node", ""))
	active = true
	_save_cursor("dialogue")
	return _process_until_interactive()


func choices() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var node := current_node()
	if str(node.get("type", "")) != "choice":
		return result
	for choice_value in (node.get("choices", []) as Array):
		if not choice_value is Dictionary:
			continue
		var choice: Dictionary = (choice_value as Dictionary).duplicate(true)
		choice["available"] = ConditionEvaluatorScript.evaluate(choice.get("condition"), state)
		result.append(choice)
	return result


func snapshot() -> Dictionary:
	return {
		"scene_id": scene_id,
		"current_node_id": current_node_id,
		"active": active,
		"state": state.duplicate(true),
	}


func _process_until_interactive() -> Dictionary:
	for _guard in range(32):
		if not active:
			return {"ok": true, "kind": "finished", "scene_id": scene_id}
		var node := current_node()
		if node.is_empty():
			return _fail("missing_dialogue_node")
		var entry_result := _enter_node(node)
		if not bool(entry_result.get("ok", false)):
			return entry_result
		var node_type := str(node.get("type", ""))
		match node_type:
			"line":
				_save_cursor("line")
				node_changed.emit(node.duplicate(true))
				return {"ok": true, "kind": "line", "node": node.duplicate(true)}
			"choice":
				_save_cursor("choice")
				node_changed.emit(node.duplicate(true))
				return {"ok": true, "kind": "choice", "node": node.duplicate(true),
					"choices": choices()}
			"condition":
				var condition_next := str(node.get("if_false", ""))
				if ConditionEvaluatorScript.evaluate(node.get("condition"), state):
					condition_next = str(node.get("if_true", ""))
				var move_result := _move_to(condition_next)
				if not bool(move_result.get("ok", false)):
					return move_result
			"check":
				var check_result := _resolve_check(node)
				if not bool(check_result.get("ok", false)):
					return check_result
				var check_next := str(node.get("failure", ""))
				if bool(check_result.get("success", false)):
					check_next = str(node.get("success", ""))
				var check_move := _move_to(check_next)
				if not bool(check_move.get("ok", false)):
					return check_move
			"effect":
				var effect_move := _move_to(str(node.get("next", "")))
				if not bool(effect_move.get("ok", false)):
					return effect_move
			"combat":
				var combat_request := CombatBridgeScript.begin(state, scene_id, node)
				if not bool(combat_request.get("ok", false)):
					return combat_request
				combat_requested.emit(combat_request.duplicate(true))
				_save_cursor("combat")
				return combat_request.merged({"kind": "combat"})
			"end":
				return _finish(str(node.get("result", "completed")))
			_:
				return _fail("unsupported_dialogue_node_type")
	return _fail("dialogue_auto_chain_limit")


func _enter_node(node: Dictionary) -> Dictionary:
	var transaction_id := "node:%s:%s:enter" % [scene_id, str(node.get("id", ""))]
	var result := EffectExecutorScript.apply_effects(state, node.get("effects", []), transaction_id)
	if not bool(result.get("ok", false)):
		return result
	var dialogue := _dialogue()
	var completed: Dictionary = dialogue.get("node_enter_completed", {}) if \
			dialogue.get("node_enter_completed", {}) is Dictionary else {}
	completed[transaction_id] = true
	dialogue["node_enter_completed"] = completed
	state["dialogue"] = dialogue
	return {"ok": true}


func _resolve_check(node: Dictionary) -> Dictionary:
	var check_value: Variant = node.get("check", {})
	var check: Dictionary = check_value if check_value is Dictionary else {}
	var player: Dictionary = state.get("player", {}) if state.get("player", {}) is Dictionary else {}
	var stat := str(check.get("stat", "dao_heart"))
	var base := int(player.get(stat, 0))
	var difficulty := int(check.get("difficulty", 0))
	var roll_seed := "%s:%s:%s:%s" % [scene_id, current_node_id,
			int(state.get("world_seed", 0)), int(state.get("generation", 1))]
	var deterministic_roll := absi(hash(roll_seed)) % 6
	var total := base + deterministic_roll
	var success := total >= difficulty
	var dialogue := _dialogue()
	dialogue["last_check"] = {
		"check_id": str(check.get("check_id", current_node_id)),
		"stat": stat,
		"base": base,
		"roll": deterministic_roll,
		"total": total,
		"difficulty": difficulty,
		"success": success,
	}
	state["dialogue"] = dialogue
	return {"ok": true, "kind": "check", "success": success,
		"total": total, "difficulty": difficulty, "check_id": str(check.get("check_id", current_node_id))}


func _move_to(target_node_id: String) -> Dictionary:
	if target_node_id.is_empty():
		return _fail("dialogue_link_without_target")
	current_node_id = target_node_id
	_save_cursor("dialogue")
	return _process_until_interactive()


func _finish(result_id: String) -> Dictionary:
	active = false
	var dialogue := _dialogue()
	dialogue["mode"] = "idle"
	dialogue["last_result"] = result_id
	state["dialogue"] = dialogue
	_save_cursor("idle")
	var result := {"ok": true, "kind": "finished", "scene_id": scene_id, "result": result_id}
	dialogue_finished.emit(result.duplicate(true))
	return result


func _fail(code: String) -> Dictionary:
	last_error = code
	return {"ok": false, "code": code, "scene_id": scene_id, "node_id": current_node_id}


func _dialogue() -> Dictionary:
	var value: Variant = state.get("dialogue", {})
	return value.duplicate(true) if value is Dictionary else {}


func _save_cursor(mode: String) -> void:
	var dialogue := _dialogue()
	dialogue["current_scene_id"] = scene_id
	dialogue["current_node_id"] = current_node_id
	dialogue["mode"] = mode
	state["dialogue"] = dialogue
