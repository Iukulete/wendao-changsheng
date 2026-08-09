class_name ChronicleSystem
extends RefCounted

## One authored novel-length volume belongs to each era. The cursor is scoped
## to a life, while route history, relationships and obligations remain in the
## shared story state so later lives can answer earlier choices.

const CharacterArtCatalogScript = preload("res://scripts/character_art_catalog.gd")
const NarrativeConsequenceScript = preload("res://scripts/narrative_consequence_system.gd")

const ERA_IDS := [
	"classical", "steam", "star_network", "wasteland", "final_age", "immortal_dynasty",
]
const DATA_PATHS := {
	"classical": "res://data/chronicles/classical_v1.json",
	"steam": "res://data/chronicles/steam_v1.json",
	"star_network": "res://data/chronicles/star_network_v1.json",
	"wasteland": "res://data/chronicles/wasteland_v1.json",
	"final_age": "res://data/chronicles/final_age_v1.json",
	"immortal_dynasty": "res://data/chronicles/immortal_dynasty_v1.json",
}
const STATE_VERSION := 1
const MAX_HISTORY := 64
const MAX_UNRESOLVED_THREADS := 128
const MAX_RESOLVED_ARCS := 256

static var _volume_cache: Dictionary = {}


static func load_volume(era_id: String) -> Dictionary:
	if _volume_cache.has(era_id):
		return _volume_cache[era_id]
	var path := str(DATA_PATHS.get(era_id, ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	# Long prose may keep manually authored continuation paragraphs as arrays.
	# Materialization only joins those exact paragraphs; it never invents text.
	var materialized: Variant = _materialize_authored_blocks(parsed)
	var volume: Dictionary = materialized
	_volume_cache[era_id] = volume
	return volume


static func clear_cache() -> void:
	_volume_cache.clear()


static func validate_volume(era_id: String) -> Dictionary:
	var volume := load_volume(era_id)
	if volume.is_empty() or int(volume.get("schema_version", 0)) != 1:
		return _invalid("missing_or_unsupported_chronicle", era_id)
	if str(volume.get("era_id", "")) != era_id or str(volume.get("id", "")).is_empty() or \
			str(volume.get("name", "")).is_empty():
		return _invalid("invalid_chronicle_identity", era_id)
	var route_ids: Array = volume.get("route_ids", [])
	if route_ids.size() != 3 or _unique_strings(route_ids).size() != 3:
		return _invalid("invalid_chronicle_routes", era_id)
	var resolutions_value: Variant = volume.get("route_resolutions", {})
	if not resolutions_value is Dictionary:
		return _invalid("missing_chronicle_resolutions", era_id)
	for route_value in route_ids:
		if str((resolutions_value as Dictionary).get(str(route_value), "")).is_empty():
			return _invalid("missing_chronicle_resolution", era_id, str(route_value))
	var chapters_value: Variant = volume.get("chapters", [])
	if not chapters_value is Array or (chapters_value as Array).size() < 24:
		return _invalid("chronicle_too_short", era_id)
	var chapters: Array = chapters_value
	var chapter_ids := {}
	var choice_ids := {}
	var characters := _character_map()
	for chapter_index in range(chapters.size()):
		var chapter_value: Variant = chapters[chapter_index]
		if not chapter_value is Dictionary:
			return _invalid("invalid_chronicle_chapter", era_id, str(chapter_index))
		var chapter: Dictionary = chapter_value
		var chapter_id := str(chapter.get("id", ""))
		if chapter_id.is_empty() or chapter_ids.has(chapter_id) or \
				str(chapter.get("title", "")).is_empty() or str(chapter.get("description", "")).is_empty():
			return _invalid("invalid_chronicle_chapter", era_id, chapter_id)
		chapter_ids[chapter_id] = true
		var choices_value: Variant = chapter.get("choices", [])
		if not choices_value is Array or (choices_value as Array).size() != 3:
			return _invalid("invalid_chronicle_choice_count", era_id, chapter_id)
		for choice_value in choices_value as Array:
			if not choice_value is Dictionary:
				return _invalid("invalid_chronicle_choice", era_id, chapter_id)
			var choice: Dictionary = choice_value
			var choice_id := str(choice.get("id", ""))
			if choice_ids.has(choice_id) or not route_ids.has(str(choice.get("route_id", ""))):
				return _invalid("invalid_chronicle_choice", era_id, chapter_id, choice_id)
			var choice_validation := NarrativeConsequenceScript.validate_choice(
				choice, characters, str(volume.id), chapter_id)
			if not bool(choice_validation.get("ok", false)):
				return choice_validation
			choice_ids[choice_id] = true
		if chapter_index > 0:
			var variants_value: Variant = chapter.get("route_variants", {})
			if not variants_value is Dictionary:
				return _invalid("missing_chronicle_route_variants", era_id, chapter_id)
			for route_value in route_ids:
				if not (variants_value as Dictionary).has(str(route_value)):
					return _invalid("missing_chronicle_route_variant", era_id,
						chapter_id, str(route_value))
	var entry_id := str(volume.get("entry_chapter_id", ""))
	if not chapter_ids.has(entry_id):
		return _invalid("invalid_chronicle_entry", era_id, entry_id)
	for chapter_value in chapters:
		var chapter: Dictionary = chapter_value
		for choice_value in (chapter.get("choices", []) as Array):
			var choice: Dictionary = choice_value
			if bool(choice.get("terminal", false)):
				continue
			var target_id := str(choice.get("target_chapter_id", ""))
			if not chapter_ids.has(target_id):
				return _invalid("dangling_chronicle_target", era_id,
					str(chapter.get("id", "")), target_id)
	return {"ok": true, "code": "valid", "era_id": era_id,
		"volume_id": str(volume.id), "chapter_count": chapters.size()}


static func validate_all() -> Dictionary:
	for era_id in ERA_IDS:
		var result := validate_volume(era_id)
		if not bool(result.get("ok", false)):
			return result
	return {"ok": true, "code": "valid", "volume_count": ERA_IDS.size()}


static func normalize(state: Dictionary) -> Dictionary:
	var story := NarrativeConsequenceScript.normalize(
		state, CharacterArtCatalogScript.story_characters())
	var generation := clampi(int(state.get("generation", 1)), 1, 100000)
	var era_id := str(state.get("current_era_id", "classical"))
	var volume := load_volume(era_id)
	var volume_id := str(volume.get("id", ""))
	var entry_id := str(volume.get("entry_chapter_id", ""))
	var history := _normalize_history(story.get("chronicle_history", []))
	var cursor_value: Variant = story.get("life_chronicle", {})
	var cursor: Dictionary = cursor_value.duplicate(true) if cursor_value is Dictionary else {}
	if int(cursor.get("generation", 0)) != generation or \
			str(cursor.get("era_id", "")) != era_id or str(cursor.get("volume_id", "")) != volume_id:
		cursor = _fresh_cursor(generation, era_id, volume_id, entry_id)
	else:
		cursor["version"] = STATE_VERSION
		cursor["chapter_index"] = clampi(int(cursor.get("chapter_index", 0)), 0, 100000)
		cursor["completed"] = bool(cursor.get("completed", false))
		cursor["current_chapter_id"] = str(cursor.get("current_chapter_id", entry_id)).left(96)
		cursor["last_route_id"] = str(cursor.get("last_route_id", "")).left(64)
		cursor["resolution"] = str(cursor.get("resolution", "")).left(1200)
	story["life_chronicle"] = cursor
	story["chronicle_history"] = history
	state["story"] = story
	return cursor


static func next_event(state: Dictionary) -> Dictionary:
	var era_id := str(state.get("current_era_id", "classical"))
	var validation := validate_volume(era_id)
	if not bool(validation.get("ok", false)):
		return {}
	var cursor := normalize(state)
	if bool(cursor.get("completed", false)):
		return {}
	var volume := load_volume(era_id)
	var chapter := _chapter_by_id(volume, str(cursor.get("current_chapter_id", "")))
	if chapter.is_empty():
		return {}
	var echoes: Array = NarrativeConsequenceScript.deliver_due_echoes(
		state, CharacterArtCatalogScript.story_characters())
	var event := _build_event(state, volume, chapter, cursor)
	if not event.is_empty() and not echoes.is_empty():
		event["consequence_echoes"] = echoes.duplicate(true)
		event["description"] = "%s\n\n%s" % ["\n\n".join(echoes),
			str(event.get("description", ""))]
	return event


static func resolve_choice(state: Dictionary, event: Dictionary, choice_index: int) -> Dictionary:
	if str(event.get("source", "")) != "life_chronicle":
		return {"ok": false, "code": "not_chronicle_event"}
	var submitted_choices: Array = event.get("choices", [])
	if choice_index < 0 or choice_index >= submitted_choices.size():
		return {"ok": false, "code": "invalid_choice"}
	var era_id := str(state.get("current_era_id", "classical"))
	var cursor := normalize(state)
	var volume := load_volume(era_id)
	var volume_id := str(volume.get("id", ""))
	var chapter_id := str(cursor.get("current_chapter_id", ""))
	if bool(cursor.get("completed", false)) or str(event.get("chronicle_volume_id", "")) != volume_id or \
			str(event.get("id", "")) != chapter_id:
		return {"ok": false, "code": "stale_chronicle_event"}
	var chapter := _chapter_by_id(volume, chapter_id)
	var authoritative_event := _build_event(state, volume, chapter, cursor)
	var submitted_choice: Dictionary = submitted_choices[choice_index]
	var choice := {}
	for choice_value in (authoritative_event.get("choices", []) as Array):
		var candidate: Dictionary = choice_value
		if str(candidate.get("id", "")) == str(submitted_choice.get("id", "")):
			choice = candidate
			break
	if choice.is_empty():
		return {"ok": false, "code": "hidden_or_unknown_choice"}
	if not bool(choice.get("available", false)):
		return {"ok": false, "code": "choice_unavailable",
			"reason": str(choice.get("unavailable_reason", ""))}
	var terminal := bool(choice.get("terminal", false))
	var target_id := str(choice.get("target_chapter_id", ""))
	if not terminal and _chapter_by_id(volume, target_id).is_empty():
		return {"ok": false, "code": "invalid_chronicle_target", "target_chapter_id": target_id}
	var consequence_result := NarrativeConsequenceScript.apply_choice(
		state, authoritative_event, choice, CharacterArtCatalogScript.story_characters())
	if not bool(consequence_result.get("ok", false)):
		return consequence_result
	var story: Dictionary = state.get("story", {})
	cursor = story.get("life_chronicle", cursor)
	cursor["chapter_index"] = int(cursor.get("chapter_index", 0)) + 1
	cursor["last_route_id"] = str(choice.get("route_id", ""))
	var resolution := ""
	if terminal:
		cursor["completed"] = true
		cursor["current_chapter_id"] = ""
		resolution = NarrativeConsequenceScript.route_resolution(story,
			{"main_route_resolutions": volume.get("route_resolutions", {})},
			volume_id, "main")
		if resolution.is_empty():
			resolution = str(choice.get("resolution", "这一世的长卷已经写完。"))
		cursor["resolution"] = resolution
		_append_completion(story, state, volume, cursor, resolution)
	else:
		cursor["current_chapter_id"] = target_id
	story["life_chronicle"] = cursor
	_update_thread(story, volume, cursor, terminal)
	state["story"] = story
	var volume_name := str(volume.get("name", "无名长卷"))
	var message := "《%s》第%d章已经写入此世记录。" % [volume_name,
		int(cursor.get("chapter_index", 0))]
	if terminal:
		message = "《%s》已经完卷：%s" % [volume_name, resolution]
	return {"ok": true, "code": "chronicle_resolved", "terminal": terminal,
		"volume_id": volume_id, "resolution": resolution, "message": message,
		"route_id": str(consequence_result.get("route_id", "")),
		"next_chapter_id": "" if terminal else target_id}


static func digest(state: Dictionary) -> String:
	var cursor := normalize(state)
	var volume := load_volume(str(state.get("current_era_id", "classical")))
	if volume.is_empty():
		return "本纪元长卷尚未装订。"
	var total := (volume.get("chapters", []) as Array).size()
	if bool(cursor.get("completed", false)):
		return "《%s》已完卷\n%s" % [str(volume.get("name", "无名长卷")),
			str(cursor.get("resolution", "此世已有定局。"))]
	var next_chapter := mini(total, int(cursor.get("chapter_index", 0)) + 1)
	return "《%s》 · 第%d/%d章\n%s" % [str(volume.get("name", "无名长卷")),
		next_chapter, total, str(volume.get("summary", "这一世的故事仍在展开。"))]


static func previous_choice_recap(state: Dictionary, event: Dictionary) -> String:
	var story: Dictionary = state.get("story", {})
	var chapters: Array = story.get("chapter_log", [])
	var volume_id := str(event.get("chronicle_volume_id", event.get("story_arc_id", "")))
	for index in range(chapters.size() - 1, -1, -1):
		var entry: Dictionary = chapters[index]
		if str(entry.get("arc_id", "")) != volume_id:
			continue
		return "上回你选择了“%s”。%s" % [str(entry.get("choice", "沉默")),
			str(entry.get("outcome", "余波还没有散去。")).left(260)]
	return ""


static func _build_event(state: Dictionary, volume: Dictionary, chapter: Dictionary,
		cursor: Dictionary) -> Dictionary:
	if chapter.is_empty():
		return {}
	var node := chapter.duplicate(true)
	var route_id := str(cursor.get("last_route_id", ""))
	var previous_life_route := ""
	if int(cursor.get("chapter_index", 0)) == 0:
		var previous_completion := _previous_completion(state, str(volume.get("id", "")))
		previous_life_route = str(previous_completion.get("last_route_id", ""))
		var inheritance_value: Variant = (volume.get("inheritance_variants", {}) as Dictionary).get(
			previous_life_route, "") if volume.get("inheritance_variants", {}) is Dictionary else ""
		if inheritance_value is Dictionary:
			var inheritance: Dictionary = inheritance_value
			if inheritance.has("title"):
				node["title"] = str(inheritance.title)
			if inheritance.has("description"):
				node["description"] = "%s\n\n%s" % [str(inheritance.description),
					str(node.get("description", ""))]
		elif not str(inheritance_value).is_empty():
			node["description"] = "%s\n\n%s" % [str(inheritance_value),
				str(node.get("description", ""))]
	var variants_value: Variant = node.get("route_variants", {})
	if not route_id.is_empty() and variants_value is Dictionary and \
			(variants_value as Dictionary).has(route_id):
		var variant_value: Variant = (variants_value as Dictionary)[route_id]
		if variant_value is Dictionary:
			var variant: Dictionary = variant_value
			if variant.has("title"):
				node["title"] = str(variant.title)
			if variant.has("description"):
				node["description"] = "%s\n\n%s" % [str(variant.description),
					str(node.get("description", ""))]
		elif not str(variant_value).is_empty():
			node["description"] = "%s\n\n%s" % [str(variant_value),
				str(node.get("description", ""))]
	var choices: Array = []
	for choice_value in (node.get("choices", []) as Array):
		var choice: Dictionary = (choice_value as Dictionary).duplicate(true)
		var availability := NarrativeConsequenceScript.choice_availability(
			state, choice, CharacterArtCatalogScript.story_characters())
		choice["visible"] = true
		choice["available"] = bool(availability.get("available", false))
		choice["unavailable_reason"] = str(availability.get("reason", ""))
		choices.append(choice)
	var art: Dictionary = volume.get("art", {})
	for field in ["scene", "portrait", "portrait_name", "portrait_title", "character_id",
			"motion_profile", "portrait_mode", "portrait_focus_y"]:
		if node.has(field):
			continue
		if art.has(field):
			node[field] = art[field]
	node["choices"] = choices
	node["era"] = str(state.get("current_era", ""))
	node["source"] = "life_chronicle"
	node["chronicle_volume_id"] = str(volume.get("id", ""))
	node["chronicle_chapter_id"] = str(chapter.get("id", ""))
	node["chronicle_timespan"] = str(volume.get("timespan", ""))
	node["story_arc_id"] = str(volume.get("id", ""))
	node["story_arc_name"] = str(volume.get("name", "无名长卷"))
	node["story_phase"] = "chronicle"
	node["story_stage"] = int(cursor.get("chapter_index", 0))
	node["chapter_number"] = int(cursor.get("chapter_index", 0)) + 1
	node["chapter_total"] = (volume.get("chapters", []) as Array).size()
	node["chapter_phase_name"] = "今世长卷"
	node["time_years"] = clampi(int(node.get("time_years",
		volume.get("default_chapter_years", 0))), 0, 100)
	node["generation"] = int(state.get("generation", 1))
	node["world_year"] = int((state.get("world", {}) as Dictionary).get("year", 1))
	node["previous_route_id"] = route_id
	node["previous_life_route_id"] = previous_life_route
	node["previous_choice_recap"] = previous_choice_recap(state, node)
	return node


static func _chapter_by_id(volume: Dictionary, chapter_id: String) -> Dictionary:
	for chapter_value in (volume.get("chapters", []) as Array):
		if chapter_value is Dictionary and str((chapter_value as Dictionary).get("id", "")) == chapter_id:
			return (chapter_value as Dictionary).duplicate(true)
	return {}


static func _fresh_cursor(generation: int, era_id: String, volume_id: String,
		entry_id: String) -> Dictionary:
	return {
		"version": STATE_VERSION,
		"generation": generation,
		"era_id": era_id,
		"volume_id": volume_id,
		"current_chapter_id": entry_id,
		"chapter_index": 0,
		"last_route_id": "",
		"completed": volume_id.is_empty() or entry_id.is_empty(),
		"resolution": "",
	}


static func _previous_completion(state: Dictionary, current_volume_id: String) -> Dictionary:
	var story: Dictionary = state.get("story", {})
	var history: Array = story.get("chronicle_history", [])
	var generation := int(state.get("generation", 1))
	for index in range(history.size() - 1, -1, -1):
		var entry_value: Variant = history[index]
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		if int(entry.get("generation", generation)) >= generation or \
				str(entry.get("volume_id", "")) == current_volume_id:
			continue
		return entry.duplicate(true)
	return {}


static func _append_completion(story: Dictionary, state: Dictionary, volume: Dictionary,
		cursor: Dictionary, resolution: String) -> void:
	var record := {
		"volume_id": str(volume.get("id", "")),
		"era_id": str(volume.get("era_id", "")),
		"name": str(volume.get("name", "无名长卷")),
		"resolution": resolution,
		"last_route_id": str(cursor.get("last_route_id", "")),
		"chapter_count": int(cursor.get("chapter_index", 0)),
		"generation": int(state.get("generation", 1)),
		"turn": int(state.get("turn", 0)),
	}
	var history: Array = story.get("chronicle_history", [])
	history.append(record)
	story["chronicle_history"] = _normalize_history(history)
	var resolved: Array = story.get("resolved_arcs", [])
	resolved.append({
		"arc_id": str(volume.get("id", "")),
		"arc_name": str(volume.get("name", "无名长卷")),
		"phase": "chronicle",
		"resolution": resolution,
		"generation": int(state.get("generation", 1)),
		"turn": int(state.get("turn", 0)),
	})
	story["resolved_arcs"] = _bounded_dictionaries(resolved, MAX_RESOLVED_ARCS)


static func _update_thread(story: Dictionary, volume: Dictionary, cursor: Dictionary,
		terminal: bool) -> void:
	var prefix := "chronicle:%s::" % str(volume.get("id", ""))
	var threads: Array = story.get("unresolved_threads", [])
	var kept: Array = []
	for value in threads:
		if not str(value).begins_with(prefix):
			kept.append(value)
	if not terminal:
		kept.append("%s《%s》推进至第%d/%d章，仍待后续。" % [prefix,
			str(volume.get("name", "无名长卷")), int(cursor.get("chapter_index", 0)),
			(volume.get("chapters", []) as Array).size()])
	while kept.size() > MAX_UNRESOLVED_THREADS:
		kept.pop_front()
	story["unresolved_threads"] = kept


static func _character_map() -> Dictionary:
	var result := {}
	for value in CharacterArtCatalogScript.story_characters():
		var character: Dictionary = value
		result[str(character.get("id", ""))] = character
	return result


static func _unique_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		var text := str(value)
		if text.is_empty() or result.has(text):
			continue
		result.append(text)
	return result


static func _materialize_authored_blocks(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary_result: Dictionary = (value as Dictionary).duplicate(false)
		for key_value in dictionary_result.keys():
			dictionary_result[key_value] = _materialize_authored_blocks(dictionary_result[key_value])
		for field in ["description", "outcome"]:
			var blocks_key := "%s_blocks" % field
			var blocks_value: Variant = dictionary_result.get(blocks_key, [])
			if not blocks_value is Array or (blocks_value as Array).is_empty():
				continue
			var parts: Array[String] = []
			var base := str(dictionary_result.get(field, "")).strip_edges()
			if not base.is_empty():
				parts.append(base)
			for block_value in blocks_value as Array:
				var block := str(block_value).strip_edges()
				if not block.is_empty():
					parts.append(block)
			dictionary_result[field] = "\n\n".join(parts)
			dictionary_result.erase(blocks_key)
		return dictionary_result
	if value is Array:
		var array_result: Array = []
		for child_value in value as Array:
			array_result.append(_materialize_authored_blocks(child_value))
		return array_result
	return value


static func _bounded_dictionaries(value: Variant, maximum: int) -> Array:
	var result: Array = []
	if value is Array:
		for entry_value in value as Array:
			if entry_value is Dictionary:
				result.append((entry_value as Dictionary).duplicate(true))
	while result.size() > maximum:
		result.pop_front()
	return result


static func _normalize_history(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for entry_value in value as Array:
			if not entry_value is Dictionary:
				continue
			var entry: Dictionary = entry_value
			result.append({
				"volume_id": str(entry.get("volume_id", "")).left(64),
				"era_id": str(entry.get("era_id", "")).left(48),
				"name": str(entry.get("name", "无名长卷")).left(96),
				"resolution": str(entry.get("resolution", "")).left(1200),
				"last_route_id": str(entry.get("last_route_id", "")).left(64),
				"chapter_count": clampi(int(entry.get("chapter_count", 0)), 0, 100000),
				"generation": clampi(int(entry.get("generation", 1)), 1, 100000),
				"turn": clampi(int(entry.get("turn", 0)), 0, 0x7fffffff),
			})
	while result.size() > MAX_HISTORY:
		result.pop_front()
	return result


static func _invalid(code: String, era_id: String, location: String = "",
		detail: String = "") -> Dictionary:
	return {"ok": false, "code": code, "era_id": era_id,
		"location": location, "detail": detail}
