class_name StorySystem
extends RefCounted

const CharacterArtCatalogScript = preload("res://scripts/character_art_catalog.gd")
const NarrativeConsequenceScript = preload("res://scripts/narrative_consequence_system.gd")
const DATA_PATH := "res://data/story_arcs_v1.json"
const ARC_IDS := ["jade", "sect", "family", "rival"]
const MAIN_STAGE_COUNT := 4
const ECHO_STAGE_COUNT := 3
const MAX_RESOLVED := 256
const MAX_THREADS := 128
const MAX_CHAPTER_LOG := 96
const MAX_CHOICES_PER_NODE := 8
const TERMINAL_TARGETS := ["", "legacy", "resolution", "terminal"]

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
	if int(data.get("schema_version", 0)) != 3:
		return {"ok": false, "code": "unsupported_story_schema"}
	var story_characters: Array = CharacterArtCatalogScript.story_characters()
	var character_validation: Dictionary = NarrativeConsequenceScript.validate_character_definitions(
		story_characters)
	if not bool(character_validation.get("ok", false)):
		return character_validation
	var characters := {}
	for character_value in story_characters:
		var character: Dictionary = character_value
		characters[str(character.get("id", ""))] = character
	var arcs_value: Variant = data.get("arcs", [])
	if not arcs_value is Array or (arcs_value as Array).size() != ARC_IDS.size():
		return {"ok": false, "code": "invalid_arc_count"}
	var seen_arcs := {}
	var seen_nodes := {}
	var seen_choices := {}
	var choice_count := 0
	var variant_count := 0
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
			var nodes_value: Variant = arc.get(phase, [])
			if not nodes_value is Array or (nodes_value as Array).is_empty():
				return {"ok": false, "code": "invalid_%s_nodes" % phase, "arc_id": arc_id}
			for node_index in range((nodes_value as Array).size()):
				var node_value: Variant = (nodes_value as Array)[node_index]
				if not node_value is Dictionary:
					return {"ok": false, "code": "invalid_story_node"}
				var node: Dictionary = node_value
				var node_id := str(node.get("id", ""))
				if node_id.is_empty() or seen_nodes.has(node_id) or str(node.get("title", "")).is_empty() or \
						str(node.get("description", "")).is_empty():
					return {"ok": false, "code": "invalid_story_node", "arc_id": arc_id}
				if not _valid_art_binding(_resolved_art(arc, node)):
					return {"ok": false, "code": "invalid_story_art", "arc_id": arc_id,
						"node_id": node_id}
				var variants_value: Variant = node.get("route_variants", {})
				if not variants_value is Dictionary:
					return {"ok": false, "code": "invalid_route_variants", "arc_id": arc_id,
						"node_id": node_id}
				var requires_route_variants: bool = node_index > 0 or phase == "echo"
				if requires_route_variants and (variants_value as Dictionary).size() < 3:
					return {"ok": false, "code": "missing_route_variants", "arc_id": arc_id,
						"node_id": node_id}
				for route_value in (variants_value as Dictionary).keys():
					var variant_value: Variant = (variants_value as Dictionary)[route_value]
					if not variant_value is Dictionary or \
							str((variant_value as Dictionary).get("title", "")).is_empty() or \
							str((variant_value as Dictionary).get("description", "")).is_empty():
						return {"ok": false, "code": "invalid_route_variant", "arc_id": arc_id,
							"node_id": node_id, "route_id": str(route_value)}
				variant_count += (variants_value as Dictionary).size()
				var choices_value: Variant = node.get("choices", [])
				if not choices_value is Array or (choices_value as Array).is_empty() or \
						(choices_value as Array).size() > MAX_CHOICES_PER_NODE:
					return {"ok": false, "code": "invalid_story_choices", "arc_id": arc_id,
						"node_id": node_id}
				for choice_value in (choices_value as Array):
					if not choice_value is Dictionary:
						return {"ok": false, "code": "invalid_story_choice"}
					var choice: Dictionary = choice_value
					var choice_id := str(choice.get("id", ""))
					if choice_id.is_empty() or seen_choices.has(choice_id):
						return {"ok": false, "code": "duplicate_story_choice", "arc_id": arc_id,
							"node_id": node_id, "choice_id": choice_id}
					var choice_validation: Dictionary = NarrativeConsequenceScript.validate_choice(
						choice, characters, arc_id, node_id)
					if not bool(choice_validation.get("ok", false)):
						return choice_validation
					if not bool(choice.get("terminal", false)) and \
							str(choice.get("target_node_id", "")).is_empty():
						return {"ok": false, "code": "missing_choice_target", "arc_id": arc_id,
							"node_id": node_id, "choice_id": choice_id}
					for condition_field in ["visible_if", "enabled_if"]:
						var condition_validation := _validate_condition(choice.get(condition_field, {}))
						if not bool(condition_validation.get("ok", false)):
							return {"ok": false, "code": "invalid_%s" % condition_field,
								"arc_id": arc_id, "node_id": node_id, "choice_id": choice_id,
								"detail": str(condition_validation.get("code", "invalid_condition"))}
					if choice.has("enabled_if") and str(choice.get("disabled_reason", "")).is_empty():
						return {"ok": false, "code": "missing_disabled_reason", "arc_id": arc_id,
							"node_id": node_id, "choice_id": choice_id}
					seen_choices[choice_id] = true
					choice_count += 1
				seen_nodes[node_id] = true
			var resolutions_value: Variant = arc.get("%s_route_resolutions" % phase, {})
			if not resolutions_value is Dictionary or (resolutions_value as Dictionary).size() < 3:
				return {"ok": false, "code": "missing_route_resolutions", "arc_id": arc_id,
					"phase": phase}
	if seen_arcs.size() != ARC_IDS.size():
		return {"ok": false, "code": "missing_arc"}
	var graph_validation := validate_graph(data)
	if not bool(graph_validation.get("ok", false)):
		return graph_validation
	return {"ok": true, "code": "valid", "arc_count": seen_arcs.size(),
		"node_count": seen_nodes.size(), "choice_count": choice_count,
		"variant_count": variant_count, "character_count": characters.size(),
		"edge_count": int(graph_validation.get("edge_count", 0))}


static func validate_graph(data: Dictionary) -> Dictionary:
	var all_node_ids := {}
	var all_choice_ids := {}
	var edge_count := 0
	var reachable_count := 0
	for arc_value in (data.get("arcs", []) as Array):
		if not arc_value is Dictionary:
			return {"ok": false, "code": "invalid_arc"}
		var arc: Dictionary = arc_value
		var arc_id := str(arc.get("id", ""))
		for phase in ["main", "echo"]:
			var nodes_value: Variant = arc.get(phase, [])
			if not nodes_value is Array or (nodes_value as Array).is_empty():
				return {"ok": false, "code": "invalid_%s_nodes" % phase, "arc_id": arc_id}
			var nodes := {}
			for node_value in (nodes_value as Array):
				if not node_value is Dictionary:
					return {"ok": false, "code": "invalid_story_node", "arc_id": arc_id}
				var node: Dictionary = node_value
				var node_id := str(node.get("id", ""))
				if node_id.is_empty() or nodes.has(node_id) or all_node_ids.has(node_id):
					return {"ok": false, "code": "duplicate_story_node", "arc_id": arc_id,
						"phase": phase, "node_id": node_id}
				nodes[node_id] = node
				all_node_ids[node_id] = true
			var entry_field := "entry_node_id" if phase == "main" else "echo_entry_node_id"
			var entry_id := str(arc.get(entry_field, ""))
			if entry_id.is_empty() or not nodes.has(entry_id):
				return {"ok": false, "code": "invalid_entry_node", "arc_id": arc_id,
					"phase": phase, "node_id": entry_id}
			var edges := {}
			var incoming := {}
			for node_id_value in nodes.keys():
				edges[str(node_id_value)] = []
				incoming[str(node_id_value)] = 0
			for node_id_value in nodes.keys():
				var node_id := str(node_id_value)
				var node: Dictionary = nodes[node_id]
				var has_unconditional_visible := false
				for choice_value in (node.get("choices", []) as Array):
					if not choice_value is Dictionary:
						return {"ok": false, "code": "invalid_story_choice", "arc_id": arc_id,
							"phase": phase, "node_id": node_id}
					var choice: Dictionary = choice_value
					var choice_id := str(choice.get("id", ""))
					if choice_id.is_empty() or all_choice_ids.has(choice_id):
						return {"ok": false, "code": "duplicate_story_choice", "arc_id": arc_id,
							"phase": phase, "node_id": node_id, "choice_id": choice_id}
					all_choice_ids[choice_id] = true
					if not choice.has("visible_if") or (choice.get("visible_if", {}) as Dictionary).is_empty():
						has_unconditional_visible = true
					if bool(choice.get("terminal", false)):
						continue
					var target_id := str(choice.get("target_node_id", ""))
					if TERMINAL_TARGETS.has(target_id):
						return {"ok": false, "code": "missing_choice_target", "arc_id": arc_id,
							"phase": phase, "node_id": node_id, "choice_id": choice_id}
					if not nodes.has(target_id):
						return {"ok": false, "code": "dangling_story_target", "arc_id": arc_id,
							"phase": phase, "node_id": node_id, "choice_id": choice_id,
							"target_node_id": target_id}
					(edges[node_id] as Array).append(target_id)
					incoming[target_id] = int(incoming[target_id]) + 1
					edge_count += 1
				var fallback_id := str(node.get("fallback_node_id", ""))
				if not has_unconditional_visible and fallback_id.is_empty():
					return {"ok": false, "code": "missing_hidden_fallback", "arc_id": arc_id,
						"phase": phase, "node_id": node_id}
				if not fallback_id.is_empty():
					if not nodes.has(fallback_id):
						return {"ok": false, "code": "dangling_story_fallback", "arc_id": arc_id,
							"phase": phase, "node_id": node_id, "target_node_id": fallback_id}
					(edges[node_id] as Array).append(fallback_id)
					incoming[fallback_id] = int(incoming[fallback_id]) + 1
					edge_count += 1
			var reachable := {}
			var pending: Array[String] = [entry_id]
			while not pending.is_empty():
				var node_id: String = pending.pop_front()
				if reachable.has(node_id):
					continue
				reachable[node_id] = true
				for target_value in (edges[node_id] as Array):
					pending.append(str(target_value))
			if reachable.size() != nodes.size():
				for node_id_value in nodes.keys():
					if not reachable.has(str(node_id_value)):
						return {"ok": false, "code": "unreachable_story_node", "arc_id": arc_id,
							"phase": phase, "node_id": str(node_id_value)}
			reachable_count += reachable.size()
			var roots: Array[String] = []
			for node_id_value in nodes.keys():
				if int(incoming[node_id_value]) == 0:
					roots.append(str(node_id_value))
			var processed := 0
			while not roots.is_empty():
				var node_id: String = roots.pop_front()
				processed += 1
				for target_value in (edges[node_id] as Array):
					var target_id := str(target_value)
					incoming[target_id] = int(incoming[target_id]) - 1
					if int(incoming[target_id]) == 0:
						roots.append(target_id)
			if processed != nodes.size():
				return {"ok": false, "code": "story_cycle", "arc_id": arc_id,
					"phase": phase}
	return {"ok": true, "code": "valid_graph", "node_count": reachable_count,
		"edge_count": edge_count}


static func _validate_condition(value: Variant) -> Dictionary:
	if value == null:
		return {"ok": true}
	if not value is Dictionary:
		return {"ok": false, "code": "condition_not_dictionary"}
	var condition: Dictionary = value
	var allowed := ["all", "any", "not", "flags_all", "flags_none", "player_min",
		"player_max", "generation_min", "generation_max"]
	for key_value in condition.keys():
		var key := str(key_value)
		if not allowed.has(key):
			return {"ok": false, "code": "unknown_condition_%s" % key}
		if key in ["all", "any"]:
			if not condition[key] is Array:
				return {"ok": false, "code": "%s_not_array" % key}
			for child in (condition[key] as Array):
				var child_validation := _validate_condition(child)
				if not bool(child_validation.get("ok", false)):
					return child_validation
		elif key == "not":
			var child_validation := _validate_condition(condition[key])
			if not bool(child_validation.get("ok", false)):
				return child_validation
		elif key in ["flags_all", "flags_none"] and not condition[key] is Array:
			return {"ok": false, "code": "%s_not_array" % key}
		elif key in ["player_min", "player_max"] and not condition[key] is Dictionary:
			return {"ok": false, "code": "%s_not_dictionary" % key}
	return {"ok": true}


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
	var story: Dictionary = NarrativeConsequenceScript.normalize(
		state, CharacterArtCatalogScript.story_characters())
	story["story_version"] = NarrativeConsequenceScript.STATE_VERSION
	story["completed_event_ids"] = _bounded_array(story.get("completed_event_ids", []), 2048)
	story["life_event_ids"] = _bounded_array(story.get("life_event_ids", []), 512)
	story["chapter_log"] = _normalize_chapter_log(story.get("chapter_log", []))
	story["resolved_arcs"] = _bounded_array(story.get("resolved_arcs", []), MAX_RESOLVED)
	story["unresolved_threads"] = _bounded_array(story.get("unresolved_threads", []), MAX_THREADS)
	story["event_cooldowns"] = _dictionary(story.get("event_cooldowns", {}))
	story["arc_progress"] = _normalize_progress(story.get("arc_progress", {}), MAIN_STAGE_COUNT)
	story["arc_node_cursors"] = _normalize_node_cursors(
		story.get("arc_node_cursors", {}), story.arc_progress)
	story["arc_legacies"] = _normalize_string_map(story.get("arc_legacies", {}))
	story["arc_echoes"] = _normalize_echoes(story.get("arc_echoes", {}))
	story["side_thread_progress"] = _normalize_named_int_map(
		story.get("side_thread_progress", {}), 0, 3)
	story["side_active_threads"] = _normalize_named_string_map(
		story.get("side_active_threads", {}), 64)
	story["side_route_scores"] = _normalize_nested_int_map(
		story.get("side_route_scores", {}), 0, 100000)
	story["side_chapter_count"] = clampi(int(story.get("side_chapter_count", 0)), 0, 1000000)
	story["last_authored_context"] = _normalize_authored_context(
		story.get("last_authored_context", {}))
	story["last_arc_id"] = str(story.get("last_arc_id", "")) if ARC_IDS.has(str(story.get("last_arc_id", ""))) else ""
	story["active_arc_id"] = str(story.get("active_arc_id", "")) if \
		ARC_IDS.has(str(story.get("active_arc_id", ""))) else ""
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
	var phases: Array[String] = ["main"]
	if int(state.get("generation", 1)) >= 2:
		phases = ["echo", "main"]
	var selected := {}
	var active_arc_id := str(story.get("active_arc_id", ""))
	if not active_arc_id.is_empty():
		for phase in phases:
			selected = _selection_for(state, story, active_arc_id, phase)
			if not selected.is_empty():
				break
	if selected.is_empty():
		for phase in phases:
			for arc_id in ARC_IDS:
				selected = _selection_for(state, story, arc_id, phase)
				if not selected.is_empty():
					break
			if not selected.is_empty():
				break
	if selected.is_empty():
		story["active_arc_id"] = ""
		state["story"] = story
		return {}
	story["active_arc_id"] = str(selected.arc_id)
	state["story"] = story
	var consequence_echoes: Array = NarrativeConsequenceScript.deliver_due_echoes(
		state, CharacterArtCatalogScript.story_characters())
	var event := _build_event(state, selected)
	if not event.is_empty() and not consequence_echoes.is_empty():
		event["consequence_echoes"] = consequence_echoes.duplicate(true)
		event["description"] = "%s\n\n%s" % ["\n\n".join(consequence_echoes),
			str(event.get("description", ""))]
	return event


static func resolve_choice(state: Dictionary, event: Dictionary, choice_index: int) -> Dictionary:
	if str(event.get("source", "")) != "story_arc":
		return {"ok": false, "code": "not_story_event"}
	var submitted_choices: Array = event.get("choices", [])
	if choice_index < 0 or choice_index >= submitted_choices.size():
		return {"ok": false, "code": "invalid_choice"}
	var story := normalize(state)
	var arc_id := str(event.get("story_arc_id", ""))
	var phase := str(event.get("story_phase", ""))
	if not ARC_IDS.has(arc_id) or phase not in ["main", "echo"]:
		return {"ok": false, "code": "invalid_story_event"}
	var current_node_id := _cursor_for(story, arc_id, phase)
	if current_node_id.is_empty() or str(event.get("id", "")) != current_node_id:
		return {"ok": false, "code": "stale_story_event"}
	var authoritative_event := _build_event(state,
		{"arc_id": arc_id, "phase": phase, "node_id": current_node_id})
	var submitted_choice: Dictionary = submitted_choices[choice_index]
	var submitted_choice_id := str(submitted_choice.get("id", ""))
	var choice := {}
	for choice_value in (authoritative_event.get("choices", []) as Array):
		var candidate: Dictionary = choice_value
		if str(candidate.get("id", "")) == submitted_choice_id:
			choice = candidate
			break
	if choice.is_empty():
		return {"ok": false, "code": "hidden_or_unknown_choice"}
	if not bool(choice.get("available", false)):
		return {"ok": false, "code": "choice_unavailable",
			"reason": str(choice.get("unavailable_reason", ""))}
	var arc := _arc_definition(arc_id)
	var nodes: Array = arc.get(phase, [])
	var stage := _node_index(nodes, current_node_id)
	if stage < 0:
		return {"ok": false, "code": "stale_story_event"}
	var terminal := bool(choice.get("terminal", false))
	var target_node_id := str(choice.get("target_node_id", ""))
	if not terminal and _node_index(nodes, target_node_id) < 0:
		return {"ok": false, "code": "invalid_story_target", "target_node_id": target_node_id}
	var consequence_result: Dictionary = NarrativeConsequenceScript.apply_choice(
		state, authoritative_event, choice, CharacterArtCatalogScript.story_characters())
	if not bool(consequence_result.get("ok", false)):
		return consequence_result
	story = state.get("story", {})
	var resolution := ""
	if phase == "main":
		story.arc_progress[arc_id] = nodes.size() if terminal else _node_index(nodes, target_node_id)
		story.arc_node_cursors[arc_id] = "" if terminal else target_node_id
		if terminal:
			resolution = NarrativeConsequenceScript.route_resolution(story,
				arc, arc_id, phase)
			if resolution.is_empty():
				resolution = str(choice.get("resolution", "未竟之局"))
			story.arc_legacies[arc_id] = resolution
	else:
		var echo: Dictionary = (story.arc_echoes as Dictionary).get(arc_id,
			{"stage": 0, "node_id": "", "resolution": ""})
		echo["stage"] = nodes.size() if terminal else _node_index(nodes, target_node_id)
		echo["node_id"] = "" if terminal else target_node_id
		if terminal:
			resolution = NarrativeConsequenceScript.route_resolution(story,
				arc, arc_id, phase)
			if resolution.is_empty():
				resolution = str(choice.get("resolution", "未竟之局"))
			echo["resolution"] = resolution
		story.arc_echoes[arc_id] = echo
	story["last_arc_id"] = arc_id
	story["active_arc_id"] = "" if terminal else arc_id
	# The next chapter can follow immediately. Authored side events should be
	# entered by the chapter itself, not forced between every two pages.
	story["next_arc_event_at"] = int((state.get("player", {}) as Dictionary).get("total_events", 0))
	var cooldowns: Dictionary = story.event_cooldowns
	cooldowns[str(event.get("id", ""))] = int(story.next_arc_event_at) + 1
	story["event_cooldowns"] = cooldowns
	var arc_name := str(event.get("story_arc_name", arc_id))
	_update_thread(story, arc_id, arc_name, phase,
		nodes.size() if terminal else _node_index(nodes, target_node_id), terminal)
	if terminal:
		var resolved: Array = story.resolved_arcs
		resolved.append({"arc_id": arc_id, "arc_name": arc_name, "phase": phase,
			"resolution": resolution, "generation": int(state.get("generation", 1)),
			"turn": int(state.get("turn", 0))})
		story["resolved_arcs"] = _bounded_array(resolved, MAX_RESOLVED)
	state["story"] = story
	var label := "今生定局" if phase == "main" else "轮回续章"
	var message := "《%s》节点「%s」已经落笔。" % [arc_name, current_node_id]
	if terminal:
		message = "《%s》%s：%s。" % [arc_name, label, resolution]
	return {"ok": true, "code": "story_resolved", "terminal": terminal,
		"phase": phase, "arc_id": arc_id, "resolution": resolution, "message": message,
		"route_id": str(consequence_result.get("route_id", "")),
		"next_node_id": "" if terminal else target_node_id}


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


static func record_chapter(state: Dictionary, event: Dictionary, choice: Dictionary,
		outcome: String, story_message: String = "", objective_message: String = "",
		encounter_message: String = "") -> Dictionary:
	var story := normalize(state)
	var source := str(event.get("source", "authored_event")).left(48)
	var arc_name := str(event.get("story_arc_name", _source_name(source))).left(64)
	var phase := str(event.get("story_phase", "chronicle")).left(24)
	var stage := int(event.get("story_stage", -1))
	var chapter_number := int(event.get("chapter_number", stage + 1 if stage >= 0 else \
		int((state.get("player", {}) as Dictionary).get("total_events", 1))))
	var chapter_total := int(event.get("chapter_total", 0))
	var event_turn := maxi(0, int(event.get("turn", state.get("turn", 0))))
	var entry := {
		"id": "%s:%d:%d:%d" % [str(event.get("id", source)).left(80),
			int(state.get("generation", 1)), event_turn, chapter_number],
		"title": str(event.get("title", "无名因果")).left(160),
		"choice": str(choice.get("text", "沉默")).left(240),
		"outcome": outcome.strip_edges().left(1600),
		"arc_id": str(event.get("story_arc_id", "")).left(48),
		"arc_name": arc_name,
		"phase": phase,
		"stage": stage,
		"chapter_number": maxi(1, chapter_number),
		"chapter_total": maxi(0, chapter_total),
		"generation": clampi(int(state.get("generation", 1)), 1, 100000),
		"year": maxi(1, int(event.get("world_year",
			(state.get("world", {}) as Dictionary).get("year", 1)))),
		"turn": event_turn,
		"source": source,
		"story_message": story_message.strip_edges().left(480),
		"objective_message": objective_message.strip_edges().left(480),
		"encounter_message": encounter_message.strip_edges().left(480),
	}
	var chapters: Array = story.chapter_log
	chapters.append(entry)
	story["chapter_log"] = _bounded_array(chapters, MAX_CHAPTER_LOG)
	state["story"] = story
	return entry


static func recent_chapters(state: Dictionary, maximum: int = 12) -> Array:
	var chapters: Array = normalize(state).chapter_log
	var result: Array = []
	var limit := clampi(maximum, 0, MAX_CHAPTER_LOG)
	if limit == 0:
		return result
	for index in range(chapters.size() - 1, -1, -1):
		result.append((chapters[index] as Dictionary).duplicate(true))
		if result.size() >= limit:
			break
	return result


static func previous_choice_recap(state: Dictionary, event: Dictionary) -> String:
	var chapters: Array = normalize(state).chapter_log
	var arc_id := str(event.get("story_arc_id", ""))
	for index in range(chapters.size() - 1, -1, -1):
		var entry: Dictionary = chapters[index]
		if not arc_id.is_empty() and str(entry.get("arc_id", "")) != arc_id:
			continue
		return "上回你选择了“%s”。%s" % [str(entry.get("choice", "沉默")),
			str(entry.get("outcome", "余波仍未散去。")).left(220)]
	return ""


static func _build_event(state: Dictionary, selected: Dictionary) -> Dictionary:
	var arc := _arc_definition(str(selected.arc_id))
	var phase := str(selected.phase)
	var nodes: Array = arc.get(phase, [])
	var node_id := str(selected.get("node_id", ""))
	var stage := _node_index(nodes, node_id)
	if stage < 0:
		return {}
	var node: Dictionary = (nodes[stage] as Dictionary).duplicate(true)
	var previous_route := NarrativeConsequenceScript.last_route_for_arc(
		state, str(selected.arc_id), CharacterArtCatalogScript.story_characters())
	var variants: Dictionary = node.get("route_variants", {})
	if not previous_route.is_empty() and variants.has(previous_route) and \
			variants[previous_route] is Dictionary:
		var variant: Dictionary = variants[previous_route]
		for field in ["title", "description", "next", "art"]:
			if variant.has(field):
				node[field] = variant[field].duplicate(true) if variant[field] is Dictionary else variant[field]
	var choices: Array = []
	var realm_index := int((state.get("player", {}) as Dictionary).get("realm_index", 0))
	for choice_value in (node.get("choices", []) as Array):
		var choice: Dictionary = (choice_value as Dictionary).duplicate(true)
		if not _condition_matches(state, choice.get("visible_if", {})):
			continue
		var deltas: Dictionary = choice.get("deltas", {})
		if deltas.has("exp"):
			deltas["exp"] = int(deltas.exp) + realm_index * 8 + stage * 16
		choice["deltas"] = deltas
		var availability: Dictionary = NarrativeConsequenceScript.choice_availability(
			state, choice, CharacterArtCatalogScript.story_characters())
		var enabled := _condition_matches(state, choice.get("enabled_if", {}))
		choice["visible"] = true
		choice["available"] = enabled and bool(availability.get("available", false))
		choice["unavailable_reason"] = str(availability.get("reason", "")) if enabled else \
			str(choice.get("disabled_reason", "条件尚未满足。"))
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
	node["chapter_number"] = stage + 1
	node["chapter_total"] = nodes.size()
	node["chapter_phase_name"] = "今生卷" if phase == "main" else "轮回续章"
	node["generation"] = int(state.get("generation", 1))
	node["world_year"] = int((state.get("world", {}) as Dictionary).get("year", 1))
	node["previous_choice_recap"] = previous_choice_recap(state, node)
	node["previous_route_id"] = previous_route
	var legacy := str((state.story.arc_legacies as Dictionary).get(str(arc.id), ""))
	if phase == "echo" and not legacy.is_empty():
		node["description"] = "%s\n\n前世定局：%s。" % [str(node.description), legacy]
	return node


static func _selection_for(state: Dictionary, story: Dictionary, arc_id: String,
		phase: String) -> Dictionary:
	if not ARC_IDS.has(arc_id):
		return {}
	if phase == "echo":
		if int(state.get("generation", 1)) < 2 or \
				str((story.arc_legacies as Dictionary).get(arc_id, "")).is_empty():
			return {}
		var echo: Dictionary = (story.arc_echoes as Dictionary).get(arc_id,
			{"stage": 0, "node_id": "", "resolution": ""})
		if not str(echo.get("resolution", "")).is_empty():
			return {}
		var echo_node_id := str(echo.get("node_id", ""))
		if echo_node_id.is_empty():
			return {}
		echo_node_id = _resolve_fallback_cursor(state, story, arc_id, phase, echo_node_id)
		return {"arc_id": arc_id, "phase": phase, "node_id": echo_node_id} if \
			not echo_node_id.is_empty() else {}
	if phase != "main":
		return {}
	if not str((story.arc_legacies as Dictionary).get(arc_id, "")).is_empty() or \
			not _main_arc_available(state, arc_id):
		return {}
	var node_id := str((story.arc_node_cursors as Dictionary).get(arc_id, ""))
	if node_id.is_empty():
		return {}
	node_id = _resolve_fallback_cursor(state, story, arc_id, phase, node_id)
	return {"arc_id": arc_id, "phase": phase, "node_id": node_id} if \
		not node_id.is_empty() else {}


static func _resolve_fallback_cursor(state: Dictionary, story: Dictionary, arc_id: String,
		phase: String, initial_node_id: String) -> String:
	var arc := _arc_definition(arc_id)
	var nodes: Array = arc.get(phase, [])
	var current_node_id := initial_node_id
	var visited := {}
	while not current_node_id.is_empty() and not visited.has(current_node_id):
		visited[current_node_id] = true
		var node_index := _node_index(nodes, current_node_id)
		if node_index < 0:
			return ""
		var node: Dictionary = nodes[node_index]
		var visible_count := 0
		for choice_value in (node.get("choices", []) as Array):
			var choice: Dictionary = choice_value
			if _condition_matches(state, choice.get("visible_if", {})):
				visible_count += 1
		if visible_count > 0:
			return current_node_id
		var fallback_node_id := str(node.get("fallback_node_id", ""))
		if fallback_node_id.is_empty() or _node_index(nodes, fallback_node_id) < 0:
			return ""
		current_node_id = fallback_node_id
		if phase == "main":
			story.arc_node_cursors[arc_id] = current_node_id
			story.arc_progress[arc_id] = _node_index(nodes, current_node_id)
		else:
			var echo: Dictionary = story.arc_echoes.get(arc_id, {})
			echo["node_id"] = current_node_id
			echo["stage"] = _node_index(nodes, current_node_id)
			story.arc_echoes[arc_id] = echo
	return ""


static func _condition_matches(state: Dictionary, value: Variant) -> bool:
	if value == null:
		return true
	if not value is Dictionary:
		return false
	var condition: Dictionary = value
	if condition.is_empty():
		return true
	for child in (condition.get("all", []) as Array):
		if not _condition_matches(state, child):
			return false
	var any_conditions: Array = condition.get("any", [])
	if not any_conditions.is_empty():
		var any_matched := false
		for child in any_conditions:
			if _condition_matches(state, child):
				any_matched = true
				break
		if not any_matched:
			return false
	if condition.has("not") and _condition_matches(state, condition.not):
		return false
	var story: Dictionary = state.get("story", {})
	var flags: Dictionary = story.get("flags", {})
	for flag_value in (condition.get("flags_all", []) as Array):
		if not bool(flags.get(str(flag_value), false)):
			return false
	for flag_value in (condition.get("flags_none", []) as Array):
		if bool(flags.get(str(flag_value), false)):
			return false
	var player: Dictionary = state.get("player", {})
	for field_value in (condition.get("player_min", {}) as Dictionary).keys():
		if int(player.get(str(field_value), 0)) < int(condition.player_min[field_value]):
			return false
	for field_value in (condition.get("player_max", {}) as Dictionary).keys():
		if int(player.get(str(field_value), 0)) > int(condition.player_max[field_value]):
			return false
	var generation := int(state.get("generation", 1))
	if condition.has("generation_min") and generation < int(condition.generation_min):
		return false
	if condition.has("generation_max") and generation > int(condition.generation_max):
		return false
	return true


static func _node_index(nodes: Array, node_id: String) -> int:
	for index in range(nodes.size()):
		if str((nodes[index] as Dictionary).get("id", "")) == node_id:
			return index
	return -1


static func _cursor_for(story: Dictionary, arc_id: String, phase: String) -> String:
	if phase == "echo":
		return str(((story.arc_echoes as Dictionary).get(arc_id, {}) as Dictionary).get("node_id", ""))
	return str((story.arc_node_cursors as Dictionary).get(arc_id, ""))


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


static func _source_name(source: String) -> String:
	match source:
		"story_arc": return "命途主卷"
		"local_ai": return "天机外章"
		"authored_event": return "山河异闻"
		_: return "无名纪事"


static func _normalize_chapter_log(value: Variant) -> Array:
	if not value is Array:
		return []
	var result: Array = []
	for entry_value in (value as Array).slice(-MAX_CHAPTER_LOG):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		result.append({
			"id": str(entry.get("id", "chapter")).left(160),
			"title": str(entry.get("title", "无名因果")).left(160),
			"choice": str(entry.get("choice", "沉默")).left(240),
			"outcome": str(entry.get("outcome", "")).left(1600),
			"arc_id": str(entry.get("arc_id", "")).left(48),
			"arc_name": str(entry.get("arc_name", "无名纪事")).left(64),
			"phase": str(entry.get("phase", "chronicle")).left(24),
			"stage": int(entry.get("stage", -1)),
			"chapter_number": maxi(1, int(entry.get("chapter_number", 1))),
			"chapter_total": maxi(0, int(entry.get("chapter_total", 0))),
			"generation": clampi(int(entry.get("generation", 1)), 1, 100000),
			"year": maxi(1, int(entry.get("year", 1))),
			"turn": maxi(0, int(entry.get("turn", 0))),
			"source": str(entry.get("source", "authored_event")).left(48),
			"story_message": str(entry.get("story_message", "")).left(480),
			"objective_message": str(entry.get("objective_message", "")).left(480),
			"encounter_message": str(entry.get("encounter_message", "")).left(480),
		})
	return result


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


static func _normalize_node_cursors(value: Variant, progress: Dictionary) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for arc_id in ARC_IDS:
		var arc := _arc_definition(arc_id)
		var nodes: Array = arc.get("main", [])
		var cursor := str(source.get(arc_id, ""))
		if _node_index(nodes, cursor) < 0:
			var legacy_stage := int(progress.get(arc_id, 0))
			cursor = str((nodes[legacy_stage] as Dictionary).get("id", "")) if \
				legacy_stage >= 0 and legacy_stage < nodes.size() else ""
		result[arc_id] = cursor
	return result


static func _normalize_string_map(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for arc_id in ARC_IDS:
		result[arc_id] = str(source.get(arc_id, "")).left(48)
	return result


static func _normalize_named_int_map(value: Variant, minimum: int, maximum: int) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for key in source.keys():
		result[str(key).left(64)] = clampi(int(source[key]), minimum, maximum)
	return result


static func _normalize_named_string_map(value: Variant, length: int) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for key in source.keys():
		result[str(key).left(64)] = str(source[key]).left(length)
	return result


static func _normalize_nested_int_map(value: Variant, minimum: int, maximum: int) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for outer_key in source.keys():
		result[str(outer_key).left(64)] = _normalize_named_int_map(source[outer_key], minimum, maximum)
	return result


static func _normalize_authored_context(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	if source.is_empty():
		return {}
	return {
		"event_id": str(source.get("event_id", "")).left(96),
		"title": str(source.get("title", "")).left(96),
		"choice": str(source.get("choice", "")).left(120),
		"outcome": str(source.get("outcome", "")).left(280),
		"thread_id": str(source.get("thread_id", "")).left(64),
		"thread_name": str(source.get("thread_name", "")).left(64),
		"generation": clampi(int(source.get("generation", 1)), 1, 100000),
		"turn": maxi(0, int(source.get("turn", 0))),
	}


static func _normalize_echoes(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for arc_id in ARC_IDS:
		var echo_value: Variant = source.get(arc_id, {})
		var echo: Dictionary = echo_value if echo_value is Dictionary else {}
		var nodes: Array = _arc_definition(arc_id).get("echo", [])
		var resolution := str(echo.get("resolution", "")).left(48)
		var stage := clampi(int(echo.get("stage", 0)), 0, nodes.size())
		var node_id := str(echo.get("node_id", ""))
		if not resolution.is_empty():
			node_id = ""
		elif _node_index(nodes, node_id) < 0:
			node_id = str((nodes[stage] as Dictionary).get("id", "")) if stage < nodes.size() else ""
		result[arc_id] = {"stage": stage, "node_id": node_id, "resolution": resolution}
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
