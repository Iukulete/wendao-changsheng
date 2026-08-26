class_name DialogueStorySaveAdapter
extends RefCounted

## Keeps dialogue state additive to the v2 save.  SaveService already persists
## the whole game dictionary; this adapter supplies stable defaults and a
## focused snapshot for tests or future split-save tooling.

const EffectExecutorScript = preload("res://scripts/dialogue/effect_executor.gd")
const MAX_HISTORY := 256


static func normalize(state: Dictionary) -> Dictionary:
	var dialogue := EffectExecutorScript.ensure_dialogue_state(state)
	dialogue["version"] = 1
	dialogue["mode"] = str(dialogue.get("mode", "idle"))
	dialogue["current_scene_id"] = str(dialogue.get("current_scene_id", ""))
	dialogue["current_node_id"] = str(dialogue.get("current_node_id", ""))
	dialogue["combat_return_context"] = _dictionary(dialogue.get("combat_return_context", {}))
	dialogue["procedural_npcs"] = _array(dialogue.get("procedural_npcs", []))
	dialogue["node_enter_completed"] = _dictionary(dialogue.get("node_enter_completed", {}))
	dialogue["applied_effect_ids"] = _bounded_array(dialogue.get("applied_effect_ids", []))
	state["dialogue"] = dialogue
	return state


static func capture(state: Dictionary) -> Dictionary:
	normalize(state)
	var dialogue: Dictionary = state.dialogue
	var story: Dictionary = state.get("story", {}) if state.get("story", {}) is Dictionary else {}
	var player: Dictionary = state.get("player", {}) if state.get("player", {}) is Dictionary else {}
	return {
		"dialogue": dialogue.duplicate(true),
		"story": {
			"flags": _dictionary(story.get("flags", {})),
			"relationships": _dictionary(story.get("relationships", {})),
		},
		"player": {
			"karma": int(player.get("karma", 0)),
			"reputation": int(player.get("reputation", 0)),
		},
		"procedural_npcs": _array(dialogue.get("procedural_npcs", [])),
		"combat_return_context": _dictionary(dialogue.get("combat_return_context", {})),
	}


static func restore(state: Dictionary, snapshot: Dictionary) -> Dictionary:
	if snapshot.has("dialogue") and snapshot.dialogue is Dictionary:
		state["dialogue"] = snapshot.dialogue.duplicate(true)
	# Full SaveService snapshots already contain story/player; focused snapshots
	# may only contain the fields listed above, so merge them conservatively.
	if snapshot.has("story") and snapshot.story is Dictionary:
		var story := _dictionary(state.get("story", {}))
		var saved_story: Dictionary = snapshot.story
		if saved_story.has("flags"):
			story["flags"] = _dictionary(saved_story.flags)
		if saved_story.has("relationships"):
			story["relationships"] = _dictionary(saved_story.relationships)
		state["story"] = story
	if snapshot.has("player") and snapshot.player is Dictionary:
		var player := _dictionary(state.get("player", {}))
		var saved_player: Dictionary = snapshot.player
		for field in ["karma", "reputation"]:
			if saved_player.has(field):
				player[field] = int(saved_player[field])
		state["player"] = player
	return normalize(state)


static func _dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}


static func _array(value: Variant) -> Array:
	return value.duplicate(true) if value is Array else []


static func _bounded_array(value: Variant) -> Array:
	var result := _array(value)
	while result.size() > MAX_HISTORY:
		result.pop_front()
	return result
