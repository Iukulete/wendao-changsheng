class_name CombatTechniqueCatalog
extends RefCounted

const DATA_PATH := "res://data/combat_techniques_v1.json"

const PATH_IDS := ["compassion", "ambition", "defiance", "insight", "creation", "bonds"]
const PATH_TIE_ORDER := ["insight", "creation", "compassion", "bonds", "defiance", "ambition"]
const SLOT_IDS := ["pressure", "guard", "turn"]
const SLOT_EQUIPMENT := {
	"pressure": "weapon",
	"guard": "armor",
	"turn": "relic",
}
const TIMINGS := ["action", "reaction", "follow_up"]
const BASE_ACTIONS := ["attack", "guard", "spell"]
const SUPPORTED_EFFECTS := ["damage", "block", "heal", "mp", "status", "draw"]
const SUPPORTED_STATUSES := ["bleed", "weak", "shield"]
const STATUS_TARGETS := ["self", "enemy"]
const AUDIO_CUES := ["combat.impact", "combat.guard", "combat.spell"]
const AI_WEIGHT_IDS := ["pressure", "survival", "tempo"]

static var _data_cache: Dictionary = {}


static func load_definitions() -> Dictionary:
	if _data_cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_data_cache = (parsed as Dictionary).duplicate(true)
	return _data_cache.duplicate(true)


static func validate_definitions(data_override: Variant = null) -> Dictionary:
	var data: Dictionary
	if data_override == null:
		data = load_definitions()
	elif data_override is Dictionary:
		data = (data_override as Dictionary).duplicate(true)
	else:
		return {"ok": false, "code": "invalid_technique_catalog"}
	if int(data.get("schema_version", 0)) != 1:
		return {"ok": false, "code": "unsupported_technique_schema"}
	if str(data.get("cost_resource", "")) != "mp":
		return {"ok": false, "code": "invalid_cost_resource"}
	var techniques_value: Variant = data.get("techniques", [])
	if not techniques_value is Array or (techniques_value as Array).is_empty():
		return {"ok": false, "code": "missing_techniques"}

	var ids := {}
	var path_counts := {}
	var selection_keys := {}
	for path_id in PATH_IDS:
		path_counts[path_id] = 0
	for value in (techniques_value as Array):
		if not value is Dictionary:
			return {"ok": false, "code": "invalid_technique"}
		var technique: Dictionary = value
		var required := _validate_required_fields(technique)
		if not bool(required.get("ok", false)):
			return required
		var technique_id := str(technique.id)
		if ids.has(technique_id):
			return {"ok": false, "code": "duplicate_technique_id", "technique_id": technique_id}
		ids[technique_id] = true
		var path_id := str(technique.path)
		var slot_id := str(technique.slot)
		var variant := str(technique.variant)
		path_counts[path_id] = int(path_counts[path_id]) + 1
		var expected_variant := str(SLOT_EQUIPMENT[slot_id])
		if variant != "base" and variant != expected_variant:
			return {"ok": false, "code": "invalid_technique_variant", "technique_id": technique_id}
		var selection_key := "%s|%s|%s" % [path_id, slot_id, variant]
		if selection_keys.has(selection_key):
			return {"ok": false, "code": "duplicate_technique_selection", "selection": selection_key}
		selection_keys[selection_key] = technique_id

	for path_id in PATH_IDS:
		if int(path_counts[path_id]) < 4:
			return {"ok": false, "code": "insufficient_path_techniques", "path": path_id}
		for slot_id in SLOT_IDS:
			for variant in ["base", str(SLOT_EQUIPMENT[slot_id])]:
				var selection_key := "%s|%s|%s" % [path_id, slot_id, variant]
				if not selection_keys.has(selection_key):
					return {"ok": false, "code": "missing_loadout_technique", "selection": selection_key}
	return {
		"ok": true,
		"code": "valid",
		"technique_count": ids.size(),
		"path_counts": path_counts,
		"selection_count": selection_keys.size(),
	}


static func technique_definition(technique_id: String) -> Dictionary:
	for value in (load_definitions().get("techniques", []) as Array):
		if value is Dictionary and str((value as Dictionary).get("id", "")) == technique_id:
			return (value as Dictionary).duplicate(true)
	return {}


static func techniques_for_path(path_id: String) -> Array:
	var normalized_path := path_id if PATH_IDS.has(path_id) else PATH_TIE_ORDER[0]
	var result: Array = []
	for value in (load_definitions().get("techniques", []) as Array):
		if value is Dictionary and str((value as Dictionary).get("path", "")) == normalized_path:
			result.append((value as Dictionary).duplicate(true))
	return result


static func dominant_path(player: Dictionary) -> String:
	var path_value: Variant = player.get("path", {})
	var path: Dictionary = path_value if path_value is Dictionary else {}
	var best_id := str(PATH_TIE_ORDER[0])
	var best_score := -2147483648
	for path_id in PATH_TIE_ORDER:
		var score := int(path.get(path_id, 0))
		if score > best_score:
			best_score = score
			best_id = str(path_id)
	return best_id


static func build_slots(player: Dictionary, inventory: Dictionary) -> Array:
	var path_id := dominant_path(player)
	var result: Array = []
	for slot_id in SLOT_IDS:
		var equipment_kind := str(SLOT_EQUIPMENT[slot_id])
		var equipment_id := _equipped_reference(inventory, equipment_kind)
		var variant := equipment_kind if not equipment_id.is_empty() else "base"
		var technique := _find_selection(path_id, str(slot_id), variant)
		if technique.is_empty() and variant != "base":
			variant = "base"
			technique = _find_selection(path_id, str(slot_id), variant)
		if technique.is_empty():
			continue
		technique["loadout_source"] = variant
		technique["equipment_id"] = equipment_id if variant != "base" else ""
		technique["execution"] = execution_payload(technique)
		result.append(technique)
	return result


static func slots_for_state(state: Dictionary) -> Array:
	var player_value: Variant = state.get("player", {})
	var inventory_value: Variant = state.get("inventory", {})
	var player: Dictionary = player_value if player_value is Dictionary else {}
	var inventory: Dictionary = inventory_value if inventory_value is Dictionary else {}
	return build_slots(player, inventory)


static func effect_tags(technique: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var effects_value: Variant = technique.get("effects", {})
	if not effects_value is Dictionary:
		return result
	for effect_id in SUPPORTED_EFFECTS:
		if (effects_value as Dictionary).has(effect_id):
			result.append("effect:%s" % effect_id)
	return result


static func execution_payload(technique: Dictionary) -> Dictionary:
	var base_action := str(technique.get("base_action", ""))
	var effects_value: Variant = technique.get("effects", {})
	var cost_value: Variant = technique.get("cost", null)
	if base_action not in BASE_ACTIONS or not effects_value is Dictionary or not _is_number(cost_value):
		return {}
	return {
		"technique_id": str(technique.get("id", "")),
		"base_action": base_action,
		"cost_resource": "mp",
		"cost": int(cost_value),
		"timing": str(technique.get("timing", "action")),
		"effects": (effects_value as Dictionary).duplicate(true),
		"cue": str(technique.get("cue", "combat.spell")),
	}


static func _validate_required_fields(technique: Dictionary) -> Dictionary:
	for field_id in ["id", "name", "path", "timing", "base_action", "cost", "tags", "effects", "cue",
			"description", "ai_weights"]:
		if not technique.has(field_id):
			return {"ok": false, "code": "missing_technique_field", "field": field_id}
	var technique_id := str(technique.get("id", ""))
	if not _is_ascii_id(technique_id):
		return {"ok": false, "code": "invalid_technique_id", "technique_id": technique_id}
	if str(technique.get("name", "")).strip_edges().is_empty() or \
			str(technique.get("description", "")).strip_edges().is_empty():
		return {"ok": false, "code": "invalid_technique_text", "technique_id": technique_id}
	if str(technique.get("path", "")) not in PATH_IDS:
		return {"ok": false, "code": "invalid_technique_path", "technique_id": technique_id}
	if str(technique.get("slot", "")) not in SLOT_IDS:
		return {"ok": false, "code": "invalid_technique_slot", "technique_id": technique_id}
	if str(technique.get("variant", "")) not in ["base", "weapon", "armor", "relic"]:
		return {"ok": false, "code": "invalid_technique_variant", "technique_id": technique_id}
	if str(technique.get("timing", "")) not in TIMINGS:
		return {"ok": false, "code": "invalid_technique_timing", "technique_id": technique_id}
	if str(technique.get("base_action", "")) not in BASE_ACTIONS:
		return {"ok": false, "code": "invalid_base_action", "technique_id": technique_id}
	var cost_value: Variant = technique.get("cost", null)
	if not _is_number(cost_value) or float(cost_value) != floor(float(cost_value)) or \
			int(cost_value) < 0 or int(cost_value) > 100:
		return {"ok": false, "code": "invalid_technique_cost", "technique_id": technique_id}
	if str(technique.get("cue", "")) not in AUDIO_CUES:
		return {"ok": false, "code": "invalid_technique_cue", "technique_id": technique_id}
	var tag_result := _validate_tags(technique.get("tags", null), technique_id)
	if not bool(tag_result.get("ok", false)):
		return tag_result
	var effect_result := _validate_effects(technique.get("effects", null), technique_id)
	if not bool(effect_result.get("ok", false)):
		return effect_result
	return _validate_ai_weights(technique.get("ai_weights", null), technique_id)


static func _validate_tags(tags_value: Variant, technique_id: String) -> Dictionary:
	if not tags_value is Array or (tags_value as Array).is_empty() or (tags_value as Array).size() > 8:
		return {"ok": false, "code": "invalid_technique_tags", "technique_id": technique_id}
	var seen := {}
	for tag_value in (tags_value as Array):
		if typeof(tag_value) != TYPE_STRING:
			return {"ok": false, "code": "invalid_technique_tag", "technique_id": technique_id}
		var tag := str(tag_value).strip_edges()
		if not _is_ascii_id(tag) or seen.has(tag):
			return {"ok": false, "code": "invalid_technique_tag", "technique_id": technique_id}
		seen[tag] = true
	return {"ok": true, "code": "valid"}


static func _validate_effects(effects_value: Variant, technique_id: String) -> Dictionary:
	if not effects_value is Dictionary or (effects_value as Dictionary).is_empty():
		return {"ok": false, "code": "invalid_technique_effects", "technique_id": technique_id}
	for effect_value in (effects_value as Dictionary).keys():
		var effect_id := str(effect_value)
		if effect_id not in SUPPORTED_EFFECTS:
			return {"ok": false, "code": "unsupported_technique_effect", "technique_id": technique_id,
				"effect": effect_id}
		var value: Variant = (effects_value as Dictionary)[effect_value]
		if effect_id == "status":
			var status_result := _validate_status(value, technique_id)
			if not bool(status_result.get("ok", false)):
				return status_result
		elif not _is_number(value) or float(value) != floor(float(value)) or \
				int(value) <= 0 or int(value) > 1000:
			return {"ok": false, "code": "invalid_technique_effect", "technique_id": technique_id,
				"effect": effect_id}
	return {"ok": true, "code": "valid"}


static func _validate_status(status_value: Variant, technique_id: String) -> Dictionary:
	if not status_value is Dictionary:
		return {"ok": false, "code": "invalid_technique_status", "technique_id": technique_id}
	var status: Dictionary = status_value
	for field_id in status.keys():
		if str(field_id) not in ["id", "target", "duration"]:
			return {"ok": false, "code": "invalid_technique_status", "technique_id": technique_id}
	if str(status.get("id", "")) not in SUPPORTED_STATUSES or \
			str(status.get("target", "")) not in STATUS_TARGETS or \
			typeof(status.get("duration", null)) != TYPE_FLOAT and typeof(status.get("duration", null)) != TYPE_INT:
		return {"ok": false, "code": "invalid_technique_status", "technique_id": technique_id}
	var duration_value: Variant = status.get("duration", 0)
	if float(duration_value) != floor(float(duration_value)) or int(duration_value) < 1 or int(duration_value) > 10:
		return {"ok": false, "code": "invalid_technique_status", "technique_id": technique_id}
	return {"ok": true, "code": "valid"}


static func _validate_ai_weights(weights_value: Variant, technique_id: String) -> Dictionary:
	if not weights_value is Dictionary or (weights_value as Dictionary).size() != AI_WEIGHT_IDS.size():
		return {"ok": false, "code": "invalid_ai_weights", "technique_id": technique_id}
	for weight_id in AI_WEIGHT_IDS:
		var value: Variant = (weights_value as Dictionary).get(weight_id, null)
		if not _is_number(value) or float(value) < 0.0 or float(value) > 5.0:
			return {"ok": false, "code": "invalid_ai_weights", "technique_id": technique_id}
	return {"ok": true, "code": "valid"}


static func _find_selection(path_id: String, slot_id: String, variant: String) -> Dictionary:
	for value in (load_definitions().get("techniques", []) as Array):
		if not value is Dictionary:
			continue
		var technique: Dictionary = value
		if str(technique.get("path", "")) == path_id and str(technique.get("slot", "")) == slot_id and \
				str(technique.get("variant", "")) == variant:
			return technique.duplicate(true)
	return {}


static func _equipped_reference(inventory: Dictionary, equipment_kind: String) -> String:
	var equipped_value: Variant = inventory.get("equipped", {})
	if not equipped_value is Dictionary:
		return ""
	var equipped: Dictionary = equipped_value
	var reference_value: Variant = equipped.get("%s_id" % equipment_kind,
		equipped.get(equipment_kind, ""))
	if typeof(reference_value) != TYPE_STRING:
		return ""
	return str(reference_value).strip_edges().left(96)


static func _is_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT]


static func _is_ascii_id(value: String) -> bool:
	if value.is_empty() or value.length() > 64:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 97 and code <= 122) and not (code >= 48 and code <= 57) and code != 95:
			return false
	return true
