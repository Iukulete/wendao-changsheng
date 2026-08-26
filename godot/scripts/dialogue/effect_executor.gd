class_name DialogueEffectExecutor
extends RefCounted

## Applies small, typed dialogue effects and records transaction IDs in the
## save state.  Re-entering a saved node therefore cannot double-apply a
## relationship, flag or stat change.

const SocialBridgeScript = preload("res://scripts/social/social_bridge.gd")
const MAX_APPLIED_EFFECT_IDS := 256


static func ensure_dialogue_state(state: Dictionary) -> Dictionary:
	var value: Variant = state.get("dialogue", {})
	var dialogue: Dictionary = value.duplicate(true) if value is Dictionary else {}
	if not dialogue.has("variables") or not dialogue.variables is Dictionary:
		dialogue["variables"] = {}
	if not dialogue.has("character_presentation") or not dialogue.character_presentation is Dictionary:
		dialogue["character_presentation"] = {}
	if not dialogue.has("applied_effect_ids") or not dialogue.applied_effect_ids is Array:
		dialogue["applied_effect_ids"] = []
	state["dialogue"] = dialogue
	return dialogue


static func apply_effects(state: Dictionary, effects: Variant,
		transaction_id: String = "") -> Dictionary:
	var dialogue := ensure_dialogue_state(state)
	var applied_ids: Array = dialogue.applied_effect_ids
	if not transaction_id.is_empty() and applied_ids.has(transaction_id):
		return {"ok": true, "code": "effect_transaction_already_applied", "applied": false,
			"transaction_id": transaction_id}
	var effect_list: Array = effects if effects is Array else ([effects] if effects is Dictionary else [])
	var changes: Array = []
	for effect_value in effect_list:
		if not effect_value is Dictionary:
			return {"ok": false, "code": "invalid_dialogue_effect"}
		var result := _apply_one(state, effect_value as Dictionary)
		if not bool(result.get("ok", false)):
			return result
		changes.append(result)
	if not transaction_id.is_empty():
		applied_ids.append(transaction_id.left(128))
		while applied_ids.size() > MAX_APPLIED_EFFECT_IDS:
			applied_ids.pop_front()
		dialogue["applied_effect_ids"] = applied_ids
		state["dialogue"] = dialogue
	return {"ok": true, "code": "dialogue_effects_applied", "applied": true,
		"transaction_id": transaction_id, "changes": changes}


static func _apply_one(state: Dictionary, effect: Dictionary) -> Dictionary:
	var effect_type := str(effect.get("type", ""))
	match effect_type:
		"set_flag":
			var story := _dictionary(state, "story")
			var flags := _dictionary_from(story, "flags")
			var flag := str(effect.get("flag", "")).strip_edges()
			if flag.is_empty():
				return {"ok": false, "code": "empty_dialogue_flag"}
			flags[flag] = bool(effect.get("value", true))
			story["flags"] = flags
			state["story"] = story
			return {"ok": true, "type": effect_type, "flag": flag}
		"relation_delta":
			return SocialBridgeScript.apply_relation_delta(state,
				str(effect.get("character_id", "")), str(effect.get("stat", "trust")),
				int(effect.get("delta", 0)))
		"reputation_delta", "karma_delta":
			var player := _dictionary(state, "player")
			var field := "reputation" if effect_type == "reputation_delta" else "karma"
			player[field] = int(player.get(field, 0)) + int(effect.get("delta", 0))
			state["player"] = player
			return {"ok": true, "type": effect_type, "field": field, "delta": int(effect.get("delta", 0))}
		"character_outfit", "character_expression":
			var dialogue := ensure_dialogue_state(state)
			var presentation := _dictionary_from(dialogue, "character_presentation")
			var character_id := str(effect.get("character_id", "")).strip_edges()
			if character_id.is_empty():
				return {"ok": false, "code": "presentation_effect_without_character"}
			var current: Dictionary = presentation.get(character_id, {}) if presentation.get(character_id, {}) is Dictionary else {}
			var field := "outfit" if effect_type == "character_outfit" else "expression"
			current[field] = str(effect.get(field, "default")).left(64)
			presentation[character_id] = current
			dialogue["character_presentation"] = presentation
			state["dialogue"] = dialogue
			return {"ok": true, "type": effect_type, "character_id": character_id, "field": field}
		"set_variable":
			var dialogue := ensure_dialogue_state(state)
			var variables := _dictionary_from(dialogue, "variables")
			var variable_name := str(effect.get("name", "")).strip_edges()
			if variable_name.is_empty():
				return {"ok": false, "code": "empty_dialogue_variable"}
			variables[variable_name] = effect.get("value")
			dialogue["variables"] = variables
			state["dialogue"] = dialogue
			return {"ok": true, "type": effect_type, "name": variable_name}
		_:
			return {"ok": false, "code": "unknown_dialogue_effect", "type": effect_type}


static func _dictionary(state: Dictionary, field: String) -> Dictionary:
	var value: Variant = state.get(field, {})
	return value.duplicate(true) if value is Dictionary else {}


static func _dictionary_from(parent: Dictionary, field: String) -> Dictionary:
	var value: Variant = parent.get(field, {})
	return value.duplicate(true) if value is Dictionary else {}
