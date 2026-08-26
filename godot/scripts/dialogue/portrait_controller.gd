class_name DialoguePortraitController
extends RefCounted

## Resolves a dialogue speaker to a stable identity and the best available
## asset.  Planned busts fall back to the approved portrait master so a
## non-combat NPC can already appear in dialogue before its final bust is
## generated.

const REGISTRY_PATH := "res://data/characters/character_registry_v2.json"
static var _registry_cache: Dictionary = {}


static func clear_cache() -> void:
	_registry_cache = {}


static func load_registry() -> Dictionary:
	if not _registry_cache.is_empty():
		return _registry_cache.duplicate(true)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
	if not parsed is Dictionary:
		return {}
	_registry_cache = (parsed as Dictionary).duplicate(true)
	return _registry_cache.duplicate(true)


static func resolve(character_id: String, outfit_id: String = "default",
		expression_id: String = "") -> Dictionary:
	var characters: Dictionary = load_registry().get("characters", {})
	var character_value: Variant = characters.get(character_id, {})
	if not character_value is Dictionary:
		return {"ok": false, "code": "unknown_dialogue_character", "character_id": character_id}
	var character: Dictionary = character_value
	var identity: Dictionary = character.get("identity", {})
	var presentation: Dictionary = character.get("presentation_profile", {})
	var assets: Dictionary = character.get("assets", {})
	var master: Dictionary = assets.get("portrait_master", {})
	var selected_outfit := _outfit(character, outfit_id)
	var selected_expression := _expression(character, expression_id)
	var bust: Dictionary = assets.get("dialogue_bust", {})
	var bust_path := str(bust.get("path", ""))
	var bust_status := str(bust.get("status", "planned"))
	var master_path := str(master.get("path", ""))
	var selected_path := master_path
	var source := "portrait_master"
	if bust_status in ["ready", "curated"] and ResourceLoader.exists(bust_path):
		selected_path = bust_path
		source = "dialogue_bust"
	return {
		"ok": not selected_path.is_empty(),
		"code": "portrait_resolved" if not selected_path.is_empty() else "portrait_missing",
		"character_id": character_id,
		"display_name": str(identity.get("display_name", character_id)),
		"portrait_path": selected_path,
		"portrait_source": source,
		"outfit": selected_outfit,
		"expression": selected_expression,
		"presentation_profile": presentation.duplicate(true),
		"visual_identity": (character.get("visual_identity", {}) as Dictionary).duplicate(true),
		"asset_status": str(master.get("status", "planned")),
	}


static func resolve_participants(participants: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for participant_value in participants:
		if not participant_value is Dictionary:
			var participant := resolve(str(participant_value))
			if bool(participant.get("ok", false)):
				result.append(participant)
			continue
		var participant_data: Dictionary = participant_value
		result.append(resolve(
			str(participant_data.get("character_id", "")),
			str(participant_data.get("outfit", "default")),
			str(participant_data.get("expression", ""))))
	return result


static func _outfit(character: Dictionary, outfit_id: String) -> String:
	var assets: Dictionary = character.get("assets", {})
	var outfits_value: Variant = assets.get("outfits", [])
	var maximum := int((character.get("presentation_profile", {}) as Dictionary).get("sensuality_max", 0))
	for outfit_value in outfits_value as Array:
		if not outfit_value is Dictionary:
			continue
		var outfit: Dictionary = outfit_value
		if str(outfit.get("id", "")) != outfit_id:
			continue
		if int(outfit.get("sensuality", 0)) <= maximum:
			return outfit_id
	return "default"


static func _expression(character: Dictionary, expression_id: String) -> String:
	if expression_id.is_empty():
		expression_id = str((character.get("dialogue_defaults", {}) as Dictionary).get("expression", "stern"))
	var expressions_value: Variant = (character.get("assets", {}) as Dictionary).get("expressions", [])
	for value in expressions_value as Array:
		if str(value) == expression_id:
			return expression_id
	return str((character.get("dialogue_defaults", {}) as Dictionary).get("expression", "stern"))
