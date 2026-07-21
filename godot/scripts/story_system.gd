class_name StorySystem
extends RefCounted

const CharacterArtCatalogScript = preload("res://scripts/character_art_catalog.gd")
const DATA_PATH := "res://data/story_arcs_v1.json"
const ARC_IDS := ["jade", "sect", "family", "rival"]
const MAIN_STAGE_COUNT := 4
const ECHO_STAGE_COUNT := 3
const MAX_RESOLVED := 256
const MAX_THREADS := 128

static var _definitions_cache: Dictionary = {}


static func load_definitions() -> Dictionary:
	if not _definitions_cache.is_empty():
		return _definitions_cache
	var payload := FileAccess.get_file_as_string(DATA_PATH)
	var parsed: Variant = JSON.parse_string(payload)
	if parsed is Dictionary:
		_definitions_cache = (parsed as Dictionary).duplicate(true)
	return _definitions_cache


static func validate_definitions() -> Dictionary:
	var character_art_validation: Dictionary = CharacterArtCatalogScript.validate_catalog()
	if not bool(character_art_validation.get("ok", false)):
		return {"ok": false, "code": "invalid_character_art_catalog",
			"detail": str(character_art_validation.get("code", "unknown"))}
	var data := load_definitions()
	if int(data.get("schema_version", 0)) != 1:
		return {"ok": false, "code": "unsupported_story_schema"}
	var arcs_value: Variant = data.get("arcs", [])
	if not arcs_value is Array or (arcs_value as Array).size() != ARC_IDS.size():
		return {"ok": false, "code": "invalid_arc_count"}
	var seen_arcs := {}
	var seen_nodes := {}
	for arc_value in (arcs_value as Array):
		if not arc_value is Dictionary:
			return {"ok": false, "code": "invalid_arc"}
		var arc: Dictionary = arc_value
		var arc_id := str(arc.get("id", ""))
		if not ARC_IDS.has(arc_id) or seen_arcs.has(arc_id):
			return {"ok": false, "code": "invalid_arc_id"}
		var arc_art := _resolved_art(arc, {})
		if not _valid_art_binding(arc_art):
			return {"ok": false, "code": "invalid_arc_art", "arc_id": arc_id}
		seen_arcs[arc_id] = true
		for phase in ["main", "echo"]:
			var expected := MAIN_STAGE_COUNT if phase == "main" else ECHO_STAGE_COUNT
			var nodes_value: Variant = arc.get(phase, [])
			if not nodes_value is Array or (nodes_value as Array).size() != expected:
				return {"ok": false, "code": "invalid_%s_nodes" % phase, "arc_id": arc_id}
			for node_value in (nodes_value as Array):
				if not node_value is Dictionary:
					return {"ok": false, "code": "invalid_story_node"}
				var node: Dictionary = node_value
				var node_id := str(node.get("id", ""))
				if node_id.is_empty() or seen_nodes.has(node_id) or str(node.get("title", "")).is_empty() or \
					str(node.get("description", "")).is_empty() or str(node.get("next", "")).is_empty():
					return {"ok": false, "code": "invalid_story_node", "arc_id": arc_id}
				if not _valid_art_binding(_resolved_art(arc, node)):
					return {"ok": false, "code": "invalid_story_art", "arc_id": arc_id,
						"node_id": node_id}
				seen_nodes[node_id] = true
			var choices_value: Variant = arc.get("%s_choices" % phase, [])
			if not choices_value is Array or (choices_value as Array).size() != 3:
				return {"ok": false, "code": "invalid_story_choices", "arc_id": arc_id}
			var costless_choice_count := 0
			for choice_value in (choices_value as Array):
				if not choice_value is Dictionary:
					return {"ok": false, "code": "invalid_story_choice"}
				var choice: Dictionary = choice_value
				if str(choice.get("text", "")).is_empty() or str(choice.get("outcome", "")).is_empty() or \
						not choice.get("deltas", null) is Dictionary or not choice.get("path_deltas", null) is Dictionary or \
						str(choice.get("resolution", "")).is_empty():
					return {"ok": false, "code": "invalid_story_choice", "arc_id": arc_id}
				if not _choice_has_explicit_cost(choice):
					costless_choice_count += 1
			if costless_choice_count > 1:
				return {"ok": false, "code": "imbalanced_story_choices", "arc_id": arc_id,
					"phase": phase, "costless_choices": costless_choice_count}
	if seen_arcs.size() != ARC_IDS.size():
		return {"ok": false, "code": "missing_arc"}
	return {"ok": true, "code": "valid", "arc_count": seen_arcs.size(), "node_count": seen_nodes.size()}


static func _choice_has_explicit_cost(choice: Dictionary) -> bool:
	var deltas: Dictionary = choice.get("deltas", {})
	for field in deltas.keys():
		var value := int(deltas[field])
		if (str(field) == "enmity" and value > 0) or (str(field) != "enmity" and value < 0):
			return true
	for value in (choice.get("path_deltas", {}) as Dictionary).values():
		if int(value) < 0:
			return true
	return false


static func normalize(state: Dictionary) -> Dictionary:
	var story_value: Variant = state.get("story", {})
	var story: Dictionary = story_value.duplicate(true) if story_value is Dictionary else {}
	story["story_version"] = 1
	story["completed_event_ids"] = _bounded_array(story.get("completed_event_ids", []), 2048)
	story["life_event_ids"] = _bounded_array(story.get("life_event_ids", []), 512)
	story["resolved_arcs"] = _bounded_array(story.get("resolved_arcs", []), MAX_RESOLVED)
	story["unresolved_threads"] = _bounded_array(story.get("unresolved_threads", []), MAX_THREADS)
	story["event_cooldowns"] = _dictionary(story.get("event_cooldowns", {}))
	story["arc_progress"] = _normalize_progress(story.get("arc_progress", {}), MAIN_STAGE_COUNT)
	story["arc_legacies"] = _normalize_string_map(story.get("arc_legacies", {}))
	story["arc_echoes"] = _normalize_echoes(story.get("arc_echoes", {}))
	story["last_arc_id"] = str(story.get("last_arc_id", "")) if ARC_IDS.has(str(story.get("last_arc_id", ""))) else ""
	story["next_arc_event_at"] = clampi(int(story.get("next_arc_event_at", 0)), 0, 0x7fffffff)
	story["birth_effects_applied_generation"] = clampi(
		int(story.get("birth_effects_applied_generation", 0)), 0, 100000)
	state["story"] = story
	return story


static func next_event(state: Dictionary) -> Dictionary:
	var validation := validate_definitions()
	if not bool(validation.get("ok", false)):
		return {}
	var story := normalize(state)
	var total_events := int((state.get("player", {}) as Dictionary).get("total_events", 0))
	if total_events < int(story.next_arc_event_at):
		return {}
	var candidates: Array[Dictionary] = []
	if int(state.get("generation", 1)) >= 2:
		for arc_id in ARC_IDS:
			if not str((story.arc_legacies as Dictionary).get(arc_id, "")).is_empty():
				var echo: Dictionary = (story.arc_echoes as Dictionary).get(arc_id, {"stage": 0, "resolution": ""})
				if int(echo.get("stage", 0)) < ECHO_STAGE_COUNT:
					candidates.append({"arc_id": arc_id, "phase": "echo", "stage": int(echo.get("stage", 0))})
	if candidates.is_empty():
		for arc_id in ARC_IDS:
			var progress := int((story.arc_progress as Dictionary).get(arc_id, 0))
			if progress < MAIN_STAGE_COUNT and str((story.arc_legacies as Dictionary).get(arc_id, "")).is_empty() and \
					_main_arc_available(state, arc_id):
				candidates.append({"arc_id": arc_id, "phase": "main", "stage": progress})
	if candidates.is_empty():
		return {}
	var minimum_stage := 100
	for candidate in candidates:
		minimum_stage = mini(minimum_stage, int(candidate.stage))
	var preferred: Array[Dictionary] = []
	for candidate in candidates:
		if int(candidate.stage) == minimum_stage and str(candidate.arc_id) != str(story.last_arc_id):
			preferred.append(candidate)
	if preferred.is_empty():
		for candidate in candidates:
			if int(candidate.stage) == minimum_stage:
				preferred.append(candidate)
	var selected: Dictionary = preferred[_roll(state, 0, preferred.size() - 1)]
	return _build_event(state, selected)


static func resolve_choice(state: Dictionary, event: Dictionary, choice_index: int) -> Dictionary:
	if str(event.get("source", "")) != "story_arc":
		return {"ok": false, "code": "not_story_event"}
	var choices: Array = event.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return {"ok": false, "code": "invalid_choice"}
	var story := normalize(state)
	var arc_id := str(event.get("story_arc_id", ""))
	var phase := str(event.get("story_phase", ""))
	var stage := int(event.get("story_stage", -1))
	if not ARC_IDS.has(arc_id) or phase not in ["main", "echo"]:
		return {"ok": false, "code": "invalid_story_event"}
	var expected_stage := int((story.arc_progress as Dictionary).get(arc_id, 0))
	if phase == "echo":
		expected_stage = int(((story.arc_echoes as Dictionary).get(arc_id, {}) as Dictionary).get("stage", 0))
	if stage != expected_stage:
		return {"ok": false, "code": "stale_story_event"}
	var choice: Dictionary = choices[choice_index]
	var terminal := stage == (MAIN_STAGE_COUNT - 1 if phase == "main" else ECHO_STAGE_COUNT - 1)
	var resolution := ""
	if phase == "main":
		story.arc_progress[arc_id] = mini(MAIN_STAGE_COUNT, stage + 1)
		if terminal:
			resolution = str(choice.get("resolution", ""))
			story.arc_legacies[arc_id] = resolution
	else:
		var echo: Dictionary = (story.arc_echoes as Dictionary).get(arc_id, {"stage": 0, "resolution": ""})
		echo["stage"] = mini(ECHO_STAGE_COUNT, stage + 1)
		if terminal:
			resolution = str(choice.get("resolution", ""))
			echo["resolution"] = resolution
		story.arc_echoes[arc_id] = echo
	story["last_arc_id"] = arc_id
	story["next_arc_event_at"] = int((state.get("player", {}) as Dictionary).get("total_events", 0)) + 2
	var cooldowns: Dictionary = story.event_cooldowns
	cooldowns[str(event.get("id", ""))] = int(story.next_arc_event_at) + 2
	story["event_cooldowns"] = cooldowns
	var arc_name := str(event.get("story_arc_name", arc_id))
	_update_thread(story, arc_id, arc_name, phase, stage + 1, terminal)
	if terminal:
		var resolved: Array = story.resolved_arcs
		resolved.append({"arc_id": arc_id, "arc_name": arc_name, "phase": phase,
			"resolution": resolution, "generation": int(state.get("generation", 1)),
			"turn": int(state.get("turn", 0))})
		story["resolved_arcs"] = _bounded_array(resolved, MAX_RESOLVED)
	state["story"] = story
	var label := "跨世定局" if phase == "main" else "续章结论"
	var message := "%s推进至%d/%d。" % [arc_name, stage + 1,
		MAIN_STAGE_COUNT if phase == "main" else ECHO_STAGE_COUNT]
	if terminal:
		message = "【%s】%s·%s已写入轮回。" % [label, arc_name, resolution]
	return {"ok": true, "code": "story_resolved", "terminal": terminal,
		"phase": phase, "arc_id": arc_id, "resolution": resolution, "message": message}


static func apply_birth_legacies(state: Dictionary) -> Dictionary:
	var story := normalize(state)
	var generation := int(state.get("generation", 1))
	if generation <= 1 or int(story.birth_effects_applied_generation) == generation:
		return {"ok": true, "applied": false, "notes": []}
	var player: Dictionary = state.get("player", {})
	var notes: Array[String] = []
	for arc_value in (load_definitions().get("arcs", []) as Array):
		var arc: Dictionary = arc_value
		var arc_id := str(arc.id)
		var legacy_tag := str((story.arc_legacies as Dictionary).get(arc_id, ""))
		if not legacy_tag.is_empty():
			var effects: Dictionary = (arc.get("legacy_birth_effects", {}) as Dictionary).get(legacy_tag, {})
			_apply_effects(player, effects)
			notes.append("%s定局·%s" % [str(arc.name), legacy_tag])
		var echo: Dictionary = (story.arc_echoes as Dictionary).get(arc_id, {})
		var echo_tag := str(echo.get("resolution", ""))
		if not echo_tag.is_empty():
			var echo_effects: Dictionary = (arc.get("echo_birth_effects", {}) as Dictionary).get(echo_tag, {})
			_apply_effects(player, echo_effects)
			notes.append("%s续章·%s" % [str(arc.name), echo_tag])
	_clamp_player(player)
	state["player"] = player
	story["birth_effects_applied_generation"] = generation
	state["story"] = story
	return {"ok": true, "applied": true, "notes": notes}


static func digest(state: Dictionary) -> String:
	var story := normalize(state)
	var definitions := load_definitions()
	var names := {}
	for arc_value in (definitions.get("arcs", []) as Array):
		var arc: Dictionary = arc_value
		names[str(arc.id)] = str(arc.name)
	var parts: Array[String] = []
	for arc_id in ARC_IDS:
		var legacy := str((story.arc_legacies as Dictionary).get(arc_id, ""))
		if legacy.is_empty():
			parts.append("%s %d/%d" % [str(names.get(arc_id, arc_id)),
				int((story.arc_progress as Dictionary).get(arc_id, 0)), MAIN_STAGE_COUNT])
		else:
			var echo: Dictionary = (story.arc_echoes as Dictionary).get(arc_id, {})
			var echo_resolution := str(echo.get("resolution", ""))
			parts.append("%s %s" % [str(names.get(arc_id, arc_id)),
				echo_resolution if not echo_resolution.is_empty() else "%s·续章%d/%d" % [legacy,
					int(echo.get("stage", 0)), ECHO_STAGE_COUNT]])
	return "｜".join(parts)


static func _build_event(state: Dictionary, selected: Dictionary) -> Dictionary:
	var arc := _arc_definition(str(selected.arc_id))
	var phase := str(selected.phase)
	var stage := int(selected.stage)
	var nodes: Array = arc.get(phase, [])
	var node: Dictionary = (nodes[stage] as Dictionary).duplicate(true)
	var choices: Array = []
	var realm_index := int((state.get("player", {}) as Dictionary).get("realm_index", 0))
	for choice_value in (arc.get("%s_choices" % phase, []) as Array):
		var choice: Dictionary = (choice_value as Dictionary).duplicate(true)
		var deltas: Dictionary = choice.get("deltas", {})
		if deltas.has("exp"):
			deltas["exp"] = int(deltas.exp) + realm_index * 8 + stage * 16
		choice["deltas"] = deltas
		choices.append(choice)
	node["era"] = str(state.get("current_era", ""))
	var art := _resolved_art(arc, node)
	for field in ["scene", "portrait", "portrait_name", "portrait_title", "character_id", "motion_profile",
			"portrait_mode"]:
		node[field] = str(art.get(field, ""))
	node["choices"] = choices
	node["source"] = "story_arc"
	node["story_arc_id"] = str(arc.id)
	node["story_arc_name"] = str(arc.name)
	node["story_phase"] = phase
	node["story_stage"] = stage
	var legacy := str((state.story.arc_legacies as Dictionary).get(str(arc.id), ""))
	if phase == "echo" and not legacy.is_empty():
		node["description"] = "%s\n\n前世定局：%s。" % [str(node.description), legacy]
	return node


static func _resolved_art(arc: Dictionary, story_node: Dictionary) -> Dictionary:
	var result := {}
	var fields := ["scene", "portrait", "portrait_name", "portrait_title", "character_id", "motion_profile",
		"portrait_mode"]
	for field in fields:
		result[field] = arc.get(field, "focus" if field == "portrait_mode" else "")
	var arc_art_value: Variant = arc.get("art", {})
	if arc_art_value is Dictionary:
		for field in fields:
			if (arc_art_value as Dictionary).has(field):
				result[field] = (arc_art_value as Dictionary)[field]
	var node_art_value: Variant = story_node.get("art", {})
	if node_art_value is Dictionary:
		for field in fields:
			if (node_art_value as Dictionary).has(field):
				result[field] = (node_art_value as Dictionary)[field]
	return result


static func _valid_art_binding(art: Dictionary) -> bool:
	var character_id := str(art.get("character_id", ""))
	var scene_path := str(art.get("scene", ""))
	var portrait_path := str(art.get("portrait", ""))
	var profile_id := str(art.get("motion_profile", ""))
	var portrait_mode := str(art.get("portrait_mode", "focus"))
	var portrait_valid := portrait_mode == "scene_only" or \
		(not portrait_path.is_empty() and ResourceLoader.exists(portrait_path))
	return not character_id.is_empty() and CharacterArtCatalogScript.has_character(character_id) and \
		not scene_path.is_empty() and ResourceLoader.exists(scene_path) and \
		portrait_mode in ["focus", "scene_only"] and portrait_valid and \
		not str(art.get("portrait_name", "")).is_empty() and \
		not str(art.get("portrait_title", "")).is_empty() and \
		not profile_id.is_empty() and CharacterArtCatalogScript.has_motion_profile(profile_id)


static func _arc_definition(arc_id: String) -> Dictionary:
	for arc_value in (load_definitions().get("arcs", []) as Array):
		var arc: Dictionary = arc_value
		if str(arc.id) == arc_id:
			return arc
	return {}


static func _main_arc_available(state: Dictionary, arc_id: String) -> bool:
	if arc_id == "rival":
		var player: Dictionary = state.get("player", {})
		return int(player.get("total_events", 0)) >= 3 or int(player.get("realm_index", 0)) >= 2
	return true


static func _update_thread(story: Dictionary, arc_id: String, arc_name: String,
		phase: String, progress: int, terminal: bool) -> void:
	var prefix := "story:%s:" % arc_id
	var threads: Array = story.unresolved_threads
	for index in range(threads.size() - 1, -1, -1):
		if str(threads[index]).begins_with(prefix):
			threads.remove_at(index)
	if not terminal:
		threads.append("%s:%s%s推进至%d章，仍待后续。" % [prefix, arc_name,
			"续章" if phase == "echo" else "主线", progress])
	story["unresolved_threads"] = _bounded_array(threads, MAX_THREADS)


static func _apply_effects(player: Dictionary, effects: Dictionary) -> void:
	for key_value in effects.keys():
		var key := str(key_value)
		var amount := int(effects[key])
		if key == "family_fame" or key == "family_wealth":
			var family: Dictionary = player.get("family", {})
			var family_key := key.trim_prefix("family_")
			family[family_key] = int(family.get(family_key, 0)) + amount
			player["family"] = family
		elif player.has(key):
			player[key] = int(player[key]) + amount


static func _clamp_player(player: Dictionary) -> void:
	player["hp"] = clampi(int(player.get("hp", 0)), 0, int(player.get("max_hp", 1)))
	player["mp"] = clampi(int(player.get("mp", 0)), 0, int(player.get("max_mp", 0)))
	player["exp"] = maxi(0, int(player.get("exp", 0)))
	player["spirit_stones"] = maxi(0, int(player.get("spirit_stones", 0)))
	player["enmity"] = maxi(0, int(player.get("enmity", 0)))
	var family: Dictionary = player.get("family", {})
	family["fame"] = clampi(int(family.get("fame", 0)), -100, 100)
	family["wealth"] = clampi(int(family.get("wealth", 0)), 0, 100000)
	player["family"] = family


static func _normalize_progress(value: Variant, maximum: int) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for arc_id in ARC_IDS:
		result[arc_id] = clampi(int(source.get(arc_id, 0)), 0, maximum)
	return result


static func _normalize_string_map(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for arc_id in ARC_IDS:
		result[arc_id] = str(source.get(arc_id, "")).left(48)
	return result


static func _normalize_echoes(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for arc_id in ARC_IDS:
		var echo_value: Variant = source.get(arc_id, {})
		var echo: Dictionary = echo_value if echo_value is Dictionary else {}
		result[arc_id] = {"stage": clampi(int(echo.get("stage", 0)), 0, ECHO_STAGE_COUNT),
			"resolution": str(echo.get("resolution", "")).left(48)}
	return result


static func _dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}


static func _bounded_array(value: Variant, maximum: int) -> Array:
	var result: Array = value.duplicate(true) if value is Array else []
	while result.size() > maximum:
		result.pop_front()
	return result


static func _roll(state: Dictionary, minimum: int, maximum: int) -> int:
	var cursor := int(state.get("rng_cursor", 0))
	var seed_value := (int(state.get("world_seed", 1)) + cursor * 130363 + 0x51ed270b) & 0x7fffffff
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	state["rng_cursor"] = cursor + 1
	return rng.randi_range(minimum, maximum)
