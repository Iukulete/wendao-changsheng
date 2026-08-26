class_name DialogueRepository
extends RefCounted

## Data-only dialogue repository.  The legacy event catalog remains the
## runtime default until an arc is migrated; this repository is the v2 pilot
## surface for authored scenes, non-combat portraits and RPG-style choices.

const INDEX_PATH := "res://data/dialogue/dialogue_index_v1.json"
const ALLOWED_NODE_TYPES := ["line", "choice", "condition", "check", "effect", "combat", "end"]
const ALLOWED_EFFECT_TYPES := [
	"relation_delta", "reputation_delta", "karma_delta", "set_flag",
	"character_outfit", "character_expression", "set_variable",
]

static var _index_cache: Dictionary = {}
static var _scene_cache: Dictionary = {}


static func clear_cache() -> void:
	_index_cache = {}
	_scene_cache = {}


static func load_index() -> Dictionary:
	if not _index_cache.is_empty():
		return _index_cache.duplicate(true)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	if not parsed is Dictionary:
		return {}
	_index_cache = (parsed as Dictionary).duplicate(true)
	return _index_cache.duplicate(true)


static func scene_ids() -> Array[String]:
	var result: Array[String] = []
	for entry_value in (load_index().get("scenes", []) as Array):
		if not entry_value is Dictionary:
			continue
		var scene_id := str((entry_value as Dictionary).get("scene_id", ""))
		if not scene_id.is_empty():
			result.append(scene_id)
	return result


static func load_scene(scene_id: String) -> Dictionary:
	var safe_id := scene_id.strip_edges()
	if safe_id.is_empty():
		return {}
	if _scene_cache.has(safe_id):
		return (_scene_cache[safe_id] as Dictionary).duplicate(true)
	var path := scene_path(safe_id)
	if path.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	var scene := (parsed as Dictionary).duplicate(true)
	_scene_cache[safe_id] = scene
	return scene.duplicate(true)


static func scene_path(scene_id: String) -> String:
	for entry_value in (load_index().get("scenes", []) as Array):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("scene_id", "")) == scene_id:
			return str(entry.get("path", ""))
	return ""


static func validate_index() -> Dictionary:
	var index := load_index()
	if index.is_empty() or int(index.get("schema_version", 0)) != 1:
		return {"ok": false, "code": "invalid_dialogue_index"}
	var seen := {}
	for entry_value in (index.get("scenes", []) as Array):
		if not entry_value is Dictionary:
			return {"ok": false, "code": "invalid_dialogue_index_entry"}
		var entry: Dictionary = entry_value
		var scene_id := str(entry.get("scene_id", ""))
		var path := str(entry.get("path", ""))
		if scene_id.is_empty() or seen.has(scene_id) or not path.begins_with("res://"):
			return {"ok": false, "code": "invalid_dialogue_scene_entry", "scene_id": scene_id}
		seen[scene_id] = true
		var validation := validate_scene(load_scene(scene_id))
		if not bool(validation.get("ok", false)):
			validation["scene_id"] = scene_id
			return validation
	return {"ok": true, "code": "valid_dialogue_index", "scene_count": seen.size()}


static func validate_scene(scene: Dictionary) -> Dictionary:
	if scene.is_empty() or int(scene.get("schema_version", 0)) != 1:
		return {"ok": false, "code": "invalid_dialogue_scene"}
	var scene_id := str(scene.get("scene_id", ""))
	var entry_node := str(scene.get("entry_node", ""))
	var nodes_value: Variant = scene.get("nodes", [])
	if scene_id.is_empty() or entry_node.is_empty() or not nodes_value is Array or \
			(nodes_value as Array).is_empty():
		return {"ok": false, "code": "missing_dialogue_scene_fields"}
	var nodes: Array = nodes_value
	var ids := {}
	for node_value in nodes:
		if not node_value is Dictionary:
			return {"ok": false, "code": "invalid_dialogue_node"}
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		var node_type := str(node.get("type", ""))
		if node_id.is_empty() or ids.has(node_id) or not ALLOWED_NODE_TYPES.has(node_type):
			return {"ok": false, "code": "invalid_dialogue_node_header", "node_id": node_id}
		ids[node_id] = true
		if node_type == "line" and str(node.get("text", "")).strip_edges().is_empty():
			return {"ok": false, "code": "empty_dialogue_line", "node_id": node_id}
		if node_type == "line" and str(node.get("speaker_id", "")).strip_edges().is_empty():
			return {"ok": false, "code": "line_without_speaker", "node_id": node_id}
		if node_type == "choice":
			var choices_value: Variant = node.get("choices", [])
			if not choices_value is Array or (choices_value as Array).is_empty():
				return {"ok": false, "code": "choice_without_choices", "node_id": node_id}
			var choice_ids := {}
			for choice_value in choices_value as Array:
				if not choice_value is Dictionary:
					return {"ok": false, "code": "invalid_dialogue_choice", "node_id": node_id}
				var choice: Dictionary = choice_value
				var choice_id := str(choice.get("id", ""))
				if choice_id.is_empty() or choice_ids.has(choice_id) or \
						str(choice.get("text", "")).strip_edges().is_empty():
					return {"ok": false, "code": "invalid_dialogue_choice_header", "node_id": node_id}
				choice_ids[choice_id] = true
		for effect_value in _effects_for_node(node):
			if not effect_value is Dictionary or \
					not ALLOWED_EFFECT_TYPES.has(str((effect_value as Dictionary).get("type", ""))):
				return {"ok": false, "code": "invalid_dialogue_effect", "node_id": node_id}

	if not ids.has(entry_node):
		return {"ok": false, "code": "missing_dialogue_entry_node"}
	for node_value in nodes:
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		for target in _targets_for_node(node):
			if not ids.has(target):
				return {"ok": false, "code": "broken_dialogue_link", "node_id": node_id,
					"target": target}
	return {"ok": true, "code": "valid_dialogue_scene", "node_count": nodes.size()}


static func _effects_for_node(node: Dictionary) -> Array:
	var effects_value: Variant = node.get("effects", [])
	var result: Array = effects_value if effects_value is Array else []
	if node.get("type", "") == "choice":
		for choice_value in (node.get("choices", []) as Array):
			if choice_value is Dictionary:
				var choice: Dictionary = choice_value
				var choice_effects: Variant = choice.get("effects", [])
				if choice_effects is Array:
					result.append_array(choice_effects)
	return result


static func _targets_for_node(node: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for field in ["next", "if_true", "if_false", "success", "failure"]:
		var target := str(node.get(field, ""))
		if not target.is_empty():
			result.append(target)
	if str(node.get("type", "")) == "choice":
		for choice_value in (node.get("choices", []) as Array):
			if choice_value is Dictionary:
				var target := str((choice_value as Dictionary).get("next", ""))
				if not target.is_empty():
					result.append(target)
	if str(node.get("type", "")) == "combat":
		var routes_value: Variant = node.get("return_routes", {})
		if routes_value is Dictionary:
			for target_value in (routes_value as Dictionary).values():
				var target := str(target_value)
				if not target.is_empty():
					result.append(target)
	return result
