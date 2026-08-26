class_name DialogueCombatBridge
extends RefCounted

## Boundary between a dialogue graph and the existing combat system.  The
## bridge stores enough return context for victory, defeat, escape and special
## outcomes without making the pilot dialogue runtime own combat state.

static func begin(state: Dictionary, scene_id: String, node: Dictionary) -> Dictionary:
	var dialogue := _dialogue(state)
	var routes_value: Variant = node.get("return_routes", {})
	var routes: Dictionary = routes_value if routes_value is Dictionary else {}
	var context := {
		"scene_id": scene_id,
		"node_id": str(node.get("id", "")),
		"encounter_id": str(node.get("encounter_id", "")),
		"combat_label": str(node.get("combat_label", "")),
		"return_routes": routes.duplicate(true),
		"started_generation": int(state.get("generation", 1)),
		"started_turn": int(state.get("turn", 0)),
	}
	dialogue["combat_return_context"] = context
	dialogue["mode"] = "combat"
	state["dialogue"] = dialogue
	return {
		"ok": not str(context.encounter_id).is_empty(),
		"code": "dialogue_combat_requested" if not str(context.encounter_id).is_empty() else "missing_encounter_id",
		"encounter_id": str(context.encounter_id),
		"label": str(context.combat_label),
		"return_context": context.duplicate(true),
	}


static func has_pending(state: Dictionary) -> bool:
	var dialogue := _dialogue(state)
	return dialogue.get("mode", "dialogue") == "combat" and \
			dialogue.get("combat_return_context", {}) is Dictionary and \
			not (dialogue.get("combat_return_context", {}) as Dictionary).is_empty()


static func finish(state: Dictionary, outcome: String) -> Dictionary:
	var dialogue := _dialogue(state)
	var context_value: Variant = dialogue.get("combat_return_context", {})
	if not context_value is Dictionary or (context_value as Dictionary).is_empty():
		return {"ok": false, "code": "no_dialogue_combat_context"}
	var context: Dictionary = context_value
	var routes: Dictionary = context.get("return_routes", {})
	var normalized := "escape" if outcome == "escaped" else outcome
	var next_node := str(routes.get(normalized, routes.get("special", "")))
	dialogue["mode"] = "dialogue"
	dialogue["combat_return_context"] = {}
	dialogue["last_combat_outcome"] = normalized
	state["dialogue"] = dialogue
	return {
		"ok": not next_node.is_empty(),
		"code": "dialogue_combat_returned" if not next_node.is_empty() else "missing_combat_return_route",
		"scene_id": str(context.get("scene_id", "")),
		"combat_node_id": str(context.get("node_id", "")),
		"next_node": next_node,
		"outcome": normalized,
	}


static func _dialogue(state: Dictionary) -> Dictionary:
	var value: Variant = state.get("dialogue", {})
	return value.duplicate(true) if value is Dictionary else {}
