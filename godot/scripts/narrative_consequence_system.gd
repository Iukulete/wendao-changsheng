class_name NarrativeConsequenceSystem
extends RefCounted

## Persistent authored consequences behind the prose. None of these fields are
## presented as an omniscient risk/reward table: the story reveals them through
## later scenes, remembered promises and changes in character behaviour.

const STATE_VERSION := 5
const MAX_ROUTE_HISTORY := 128
const MAX_RECORDS := 128
const MAX_ECHOES := 128
const MAX_PENDING_COMBAT_CONSEQUENCES := 64
const MAX_COMBAT_CONSEQUENCE_HISTORY := 128
const RELATION_FIELDS := [
	"trust", "respect", "desire", "agency", "coercion", "dependency", "corruption",
]
const INTIMATE_TAGS := ["intimacy", "romance", "dual_cultivation"]
const COERCION_TAGS := ["coercion", "captivity", "exploitation"]
const PROMISE_STATUSES := ["open", "fulfilled", "broken"]
const DEBT_STATUSES := ["open", "repaid", "forgiven"]
const COMBAT_OUTCOMES := ["victory", "escaped", "defeat", "expired"]


static func normalize(state: Dictionary, characters: Array = []) -> Dictionary:
	var value: Variant = state.get("story", {})
	var story: Dictionary = value.duplicate(true) if value is Dictionary else {}
	story["story_version"] = STATE_VERSION
	story["choice_count"] = clampi(int(story.get("choice_count", 0)), 0, 1000000)
	story["route_history"] = _normalize_route_history(story.get("route_history", {}))
	story["route_scores"] = _normalize_nested_int_map(story.get("route_scores", {}))
	story["flags"] = _normalize_flags(story.get("flags", {}))
	story["promises"] = _normalize_records(story.get("promises", []), "promise")
	story["debts"] = _normalize_records(story.get("debts", []), "debt")
	story["relationships"] = _normalize_relationships(story.get("relationships", {}), characters)
	story["faction_standings"] = _normalize_int_map(story.get("faction_standings", {}), -100, 100)
	story["pending_echoes"] = _normalize_echoes(story.get("pending_echoes", []), false)
	story["delivered_echoes"] = _normalize_echoes(story.get("delivered_echoes", []), true)
	story["last_echoes"] = _bounded_strings(story.get("last_echoes", []), 8, 360)
	story["pending_combat_consequences"] = _normalize_pending_combat_consequences(
		story.get("pending_combat_consequences", []))
	story["combat_consequence_history"] = _normalize_combat_consequence_history(
		story.get("combat_consequence_history", []))
	state["story"] = story
	return story


static func validate_character_definitions(characters_value: Variant) -> Dictionary:
	if not characters_value is Array:
		return {"ok": false, "code": "invalid_story_characters"}
	var seen := {}
	for value in characters_value as Array:
		if not value is Dictionary:
			return {"ok": false, "code": "invalid_story_character"}
		var character: Dictionary = value
		var character_id := str(character.get("id", ""))
		if character_id.is_empty() or seen.has(character_id) or \
				str(character.get("name", "")).is_empty() or int(character.get("age", 0)) < 18:
			return {"ok": false, "code": "invalid_or_underage_story_character",
				"character_id": character_id}
		seen[character_id] = true
	return {"ok": true, "code": "valid", "character_count": seen.size()}


static func validate_choice(choice: Dictionary, characters: Dictionary,
		arc_id: String, node_id: String) -> Dictionary:
	for required in ["id", "text", "outcome", "route_id", "deltas", "path_deltas"]:
		if not choice.has(required):
			return _invalid("missing_choice_field", arc_id, node_id, choice, required)
	if str(choice.id).is_empty() or str(choice.text).is_empty() or str(choice.outcome).is_empty() or \
			str(choice.route_id).is_empty() or not choice.deltas is Dictionary or \
			not choice.path_deltas is Dictionary:
		return _invalid("invalid_story_choice", arc_id, node_id, choice)
	var tags := _string_array(choice.get("content_tags", []), 16, 32)
	var has_intimacy := _contains_any(tags, INTIMATE_TAGS)
	var has_coercion := _contains_any(tags, COERCION_TAGS)
	if has_intimacy and has_coercion:
		return _invalid("coercion_cannot_be_intimacy", arc_id, node_id, choice)
	if has_intimacy:
		if str(choice.get("consent", "")) != "affirmative" or \
				str(choice.get("content_mode", "")) != "fade_to_black":
			return _invalid("invalid_intimacy_boundary", arc_id, node_id, choice)
		var participants := _string_array(choice.get("participants", []), 8, 48)
		if participants.size() < 2 or not participants.has("player"):
			return _invalid("invalid_intimacy_participants", arc_id, node_id, choice)
		for participant in participants:
			if participant == "player":
				continue
			if not characters.has(participant) or int((characters[participant] as Dictionary).get("age", 0)) < 18:
				return _invalid("underage_or_unknown_intimacy_participant", arc_id, node_id, choice,
					participant)
	if has_coercion and str(choice.get("consent", "none")) == "affirmative":
		return _invalid("coercion_cannot_claim_consent", arc_id, node_id, choice)
	var combat_outcomes_value: Variant = choice.get("combat_outcomes", {})
	if not combat_outcomes_value is Dictionary:
		return _invalid("invalid_combat_outcomes", arc_id, node_id, choice)
	if not (combat_outcomes_value as Dictionary).is_empty():
		if not bool(choice.get("combat_trigger", false)):
			return _invalid("combat_outcomes_without_trigger", arc_id, node_id, choice)
		for outcome_value in (combat_outcomes_value as Dictionary).keys():
			var outcome := str(outcome_value)
			if not COMBAT_OUTCOMES.has(outcome) or \
					not (combat_outcomes_value as Dictionary)[outcome_value] is Dictionary:
				return _invalid("invalid_combat_outcome_effects", arc_id, node_id, choice,
					outcome)
	return {"ok": true, "code": "valid"}


static func apply_choice(state: Dictionary, event: Dictionary, choice: Dictionary,
		characters: Array = []) -> Dictionary:
	var story := normalize(state, characters)
	var arc_id := str(event.get("story_arc_id", "chronicle")).left(48)
	var phase := str(event.get("story_phase", "chronicle")).left(24)
	var choice_id := str(choice.get("id", "choice")).left(80)
	var route_id := str(choice.get("route_id", "unmarked")).left(48)
	story["choice_count"] = int(story.choice_count) + 1

	var histories: Dictionary = story.route_history
	var history: Array = histories.get(arc_id, [])
	history.append({
		"choice_id": choice_id,
		"route_id": route_id,
		"phase": phase,
		"stage": int(event.get("story_stage", -1)),
		"generation": int(state.get("generation", 1)),
		"turn": int(state.get("turn", 0)),
	})
	while history.size() > MAX_ROUTE_HISTORY:
		history.pop_front()
	histories[arc_id] = history
	story["route_history"] = histories

	var score_maps: Dictionary = story.route_scores
	var scores: Dictionary = score_maps.get(arc_id, {})
	scores[route_id] = clampi(int(scores.get(route_id, 0)) + maxi(1,
		int(choice.get("route_weight", 1))), 0, 100000)
	score_maps[arc_id] = scores
	story["route_scores"] = score_maps

	var flags: Dictionary = story.flags
	for flag_id in _string_array(choice.get("flags_add", []), 32, 64):
		flags[flag_id] = true
	for flag_id in _string_array(choice.get("flags_remove", []), 32, 64):
		flags.erase(flag_id)
	story["flags"] = flags
	story["promises"] = _append_records(story.promises, choice.get("promises_add", []),
		"promise", state, choice_id)
	story["debts"] = _append_records(story.debts, choice.get("debts_add", []),
		"debt", state, choice_id)
	story["promises"] = _transition_records(story.promises,
		choice.get("promises_resolve", []), "promise", "fulfilled", state, choice_id)
	story["promises"] = _transition_records(story.promises,
		choice.get("promises_break", []), "promise", "broken", state, choice_id)
	story["debts"] = _transition_records(story.debts,
		choice.get("debts_resolve", []), "debt", "repaid", state, choice_id)
	story["debts"] = _transition_records(story.debts,
		choice.get("debts_forgive", []), "debt", "forgiven", state, choice_id)
	_apply_relationship_deltas(story, choice.get("relationship_deltas", {}), characters)
	_apply_faction_deltas(story, choice.get("faction_deltas", {}))
	_apply_status_changes(state, choice)
	_schedule_echoes(story, choice.get("delayed_echoes", []), arc_id, choice_id)
	_queue_combat_consequences(story, state, event, choice, arc_id, choice_id)
	state["story"] = story
	return {
		"ok": true,
		"code": "narrative_consequences_recorded",
		"choice_id": choice_id,
		"route_id": route_id,
		"choice_count": int(story.choice_count),
	}


static func resolve_combat_outcome(state: Dictionary, source_event_id: String,
		source_choice_id: String, outcome_value: String, characters: Array = []) -> Dictionary:
	var outcome := "escaped" if outcome_value == "escape" else outcome_value
	if not COMBAT_OUTCOMES.has(outcome):
		return {"ok": false, "code": "invalid_combat_outcome", "outcome": outcome}
	var story := normalize(state, characters)
	var pending: Array = story.pending_combat_consequences
	var match_index := -1
	for index in range(pending.size() - 1, -1, -1):
		var entry: Dictionary = pending[index]
		if str(entry.get("source_event_id", "")) == source_event_id and \
				str(entry.get("source_choice_id", "")) == source_choice_id:
			match_index = index
			break
	if match_index < 0:
		return {"ok": true, "code": "no_pending_combat_consequence", "applied": false,
			"outcome": outcome}
	var pending_entry: Dictionary = pending[match_index]
	pending.remove_at(match_index)
	story["pending_combat_consequences"] = pending
	var outcomes: Dictionary = pending_entry.get("outcomes", {})
	var effects_value: Variant = outcomes.get(outcome, {})
	var effects: Dictionary = effects_value.duplicate(true) if effects_value is Dictionary else {}
	var resolution_id := "%s_%s" % [str(pending_entry.get("source_choice_id", "combat")), outcome]
	_apply_effect_bundle(state, story, effects, str(pending_entry.get("arc_id", "chronicle")),
		resolution_id, characters)
	var history: Array = story.combat_consequence_history
	history.append({
		"id": str(pending_entry.get("id", "combat_consequence")),
		"source_event_id": source_event_id.left(96),
		"source_choice_id": source_choice_id.left(96),
		"arc_id": str(pending_entry.get("arc_id", "chronicle")).left(48),
		"outcome": outcome,
		"generation": clampi(int(state.get("generation", 1)), 1, 100000),
		"turn": maxi(0, int(state.get("turn", 0))),
		"effects_applied": not effects.is_empty(),
	})
	while history.size() > MAX_COMBAT_CONSEQUENCE_HISTORY:
		history.pop_front()
	story["combat_consequence_history"] = history
	state["story"] = story
	return {"ok": true, "code": "combat_consequence_resolved", "applied": not effects.is_empty(),
		"outcome": outcome, "effects": effects.duplicate(true)}


static func deliver_due_echoes(state: Dictionary, characters: Array = []) -> Array:
	var story := normalize(state, characters)
	var pending: Array = story.pending_echoes
	var remaining: Array = []
	var delivered: Array = story.delivered_echoes
	var texts: Array[String] = []
	for echo_value in pending:
		var echo: Dictionary = echo_value
		if int(echo.get("due_choice", 0)) > int(story.choice_count):
			remaining.append(echo)
			continue
		var text := str(echo.get("text", "")).strip_edges().left(360)
		if not text.is_empty():
			texts.append(text)
		var effects: Dictionary = echo.get("effects", {})
		var flags: Dictionary = story.flags
		for flag_id in _string_array(effects.get("flags_add", []), 32, 64):
			flags[flag_id] = true
		for flag_id in _string_array(effects.get("flags_remove", []), 32, 64):
			flags.erase(flag_id)
		story["flags"] = flags
		_apply_relationship_deltas(story, effects.get("relationship_deltas", {}), characters)
		_apply_faction_deltas(story, effects.get("faction_deltas", {}))
		_apply_status_changes(state, effects)
		var echo_id := str(echo.get("id", "delayed_echo")).left(80)
		story["promises"] = _transition_records(story.promises,
			effects.get("promises_resolve", []), "promise", "fulfilled", state, echo_id)
		story["promises"] = _transition_records(story.promises,
			effects.get("promises_break", []), "promise", "broken", state, echo_id)
		story["debts"] = _transition_records(story.debts,
			effects.get("debts_resolve", []), "debt", "repaid", state, echo_id)
		story["debts"] = _transition_records(story.debts,
			effects.get("debts_forgive", []), "debt", "forgiven", state, echo_id)
		echo["delivered_generation"] = int(state.get("generation", 1))
		echo["delivered_turn"] = int(state.get("turn", 0))
		delivered.append(echo)
	while delivered.size() > MAX_ECHOES:
		delivered.pop_front()
	story["pending_echoes"] = remaining
	story["delivered_echoes"] = delivered
	story["last_echoes"] = texts
	state["story"] = story
	return texts


static func choice_availability(state: Dictionary, choice: Dictionary,
		characters: Array = []) -> Dictionary:
	var story := normalize(state, characters)
	var player: Dictionary = state.get("player", {})
	var requires: Dictionary = choice.get("requires", {})
	for flag_id in _string_array(requires.get("flags_all", []), 32, 64):
		if not bool((story.flags as Dictionary).get(flag_id, false)):
			return {"available": false, "reason": "此前的因果尚未走到这里。"}
	for flag_id in _string_array(requires.get("flags_none", []), 32, 64):
		if bool((story.flags as Dictionary).get(flag_id, false)):
			return {"available": false, "reason": "此前的选择已经关闭这条路。"}
	var relation_requires: Dictionary = requires.get("relationship", {})
	for character_id in relation_requires.keys():
		var relation: Dictionary = (story.relationships as Dictionary).get(str(character_id), {})
		var thresholds: Dictionary = relation_requires[character_id]
		for field in thresholds.keys():
			var threshold := int(thresholds[field])
			if str(field).begins_with("max_"):
				var actual_field := str(field).trim_prefix("max_")
				if int(relation.get(actual_field, 0)) > threshold:
					return {"available": false, "reason": "你们之间还没有这样的余地。"}
			elif int(relation.get(str(field), 0)) < threshold:
				return {"available": false, "reason": "你们之间还没有这样的余地。"}

	var tags := _string_array(choice.get("content_tags", []), 16, 32)
	if _contains_any(tags, INTIMATE_TAGS):
		if int(player.get("age", 0)) < 18 or str(choice.get("consent", "")) != "affirmative":
			return {"available": false, "reason": "这段关系尚未具备成年且明确自愿的前提。"}
		for participant in _string_array(choice.get("participants", []), 8, 48):
			if participant == "player":
				continue
			var relation: Dictionary = (story.relationships as Dictionary).get(participant, {})
			if int(relation.get("age", 0)) < 18 or int(relation.get("agency", 0)) < 70 or \
					int(relation.get("coercion", 0)) > 0:
				return {"available": false, "reason": "对方尚未处在能够自由同意或拒绝的状态。"}
	for resource_id in ["spirit_stones", "pills"]:
		var delta := int((choice.get("deltas", {}) as Dictionary).get(resource_id, 0))
		if int(player.get(resource_id, 0)) + delta < 0:
			return {"available": false, "reason": "%s不足。" % (
				"灵石" if resource_id == "spirit_stones" else "丹药")}
	return {"available": true, "reason": ""}


static func route_resolution(story: Dictionary, arc: Dictionary, arc_id: String,
		phase: String) -> String:
	var mapping_value: Variant = arc.get("%s_route_resolutions" % phase, {})
	var mapping: Dictionary = mapping_value if mapping_value is Dictionary else {}
	var score_maps: Dictionary = story.get("route_scores", {})
	var scores: Dictionary = score_maps.get(arc_id, {})
	var best_route := ""
	var best_score := -1
	var histories: Dictionary = story.get("route_history", {})
	var history: Array = histories.get(arc_id, [])
	for route_value in mapping.keys():
		var route_id := str(route_value)
		var score := int(scores.get(route_id, 0))
		if score > best_score or (score == best_score and _last_route_index(history, route_id) >
				_last_route_index(history, best_route)):
			best_route = route_id
			best_score = score
	return str(mapping.get(best_route, "未竟之局"))


static func last_route_for_arc(state: Dictionary, arc_id: String,
		characters: Array = []) -> String:
	var history: Array = (normalize(state, characters).route_history as Dictionary).get(arc_id, [])
	if history.is_empty():
		return ""
	return str((history[-1] as Dictionary).get("route_id", ""))


static func relationship_summary(state: Dictionary, characters: Array = []) -> String:
	var relationships: Dictionary = normalize(state, characters).relationships
	var best: Dictionary = {}
	var best_weight := -100000
	for value in relationships.values():
		var relation: Dictionary = value
		var weight: int = absi(int(relation.get("trust", 0))) + absi(int(relation.get("respect", 0))) + \
			int(relation.get("dependency", 0)) + int(relation.get("coercion", 0)) + \
			int(relation.get("corruption", 0))
		if weight > best_weight:
			best_weight = weight
			best = relation
	if best.is_empty() or best_weight <= 0:
		return "尚无人真正走近你的命途。"
	var state_text := "彼此试探"
	if int(best.get("coercion", 0)) > 0:
		state_text = "控制仍未解除"
	elif int(best.get("corruption", 0)) >= 55:
		state_text = "立场已向暗处偏移"
	elif int(best.get("trust", 0)) >= 45:
		state_text = "已经能够托付后背"
	elif int(best.get("respect", 0)) >= 35:
		state_text = "承认彼此分量"
	return "%s · %s" % [str(best.get("name", "故人")), state_text]


static func open_obligation_summary(state: Dictionary, characters: Array = []) -> String:
	var story := normalize(state, characters)
	for records_value in [story.promises, story.debts]:
		var records: Array = records_value
		for index in range(records.size() - 1, -1, -1):
			var record: Dictionary = records[index]
			if str(record.get("status", "open")) == "open":
				return str(record.get("text", "一件旧事仍待偿还。"))
	return "暂时没有写在明面上的旧约。"


static func _queue_combat_consequences(story: Dictionary, state: Dictionary,
		event: Dictionary, choice: Dictionary, arc_id: String, choice_id: String) -> void:
	if not bool(choice.get("combat_trigger", false)):
		return
	var outcomes_value: Variant = choice.get("combat_outcomes", {})
	if not outcomes_value is Dictionary or (outcomes_value as Dictionary).is_empty():
		return
	var source_event_id := str(event.get("id", "")).left(96)
	if source_event_id.is_empty():
		return
	var outcomes := _normalize_combat_outcomes(outcomes_value)
	if outcomes.is_empty():
		return
	var generation := clampi(int(state.get("generation", 1)), 1, 100000)
	var turn := maxi(0, int(state.get("turn", 0)))
	var pending: Array = story.pending_combat_consequences
	for index in range(pending.size() - 1, -1, -1):
		var existing: Dictionary = pending[index]
		if str(existing.get("source_event_id", "")) == source_event_id and \
				str(existing.get("source_choice_id", "")) == choice_id and \
				int(existing.get("queued_generation", 0)) == generation:
			pending.remove_at(index)
	pending.append({
		"id": "combat_consequence_%s" % ("%s|%s|%d|%d" % [source_event_id,
			choice_id, generation, turn]).sha256_text().left(16),
		"source_event_id": source_event_id,
		"source_choice_id": choice_id,
		"arc_id": arc_id.left(48),
		"queued_generation": generation,
		"queued_turn": turn,
		"outcomes": outcomes,
	})
	while pending.size() > MAX_PENDING_COMBAT_CONSEQUENCES:
		pending.pop_front()
	story["pending_combat_consequences"] = pending


static func _apply_effect_bundle(state: Dictionary, story: Dictionary, effects: Dictionary,
		arc_id: String, resolution_id: String, characters: Array) -> void:
	var flags: Dictionary = story.flags
	for flag_id in _string_array(effects.get("flags_add", []), 32, 64):
		flags[flag_id] = true
	for flag_id in _string_array(effects.get("flags_remove", []), 32, 64):
		flags.erase(flag_id)
	story["flags"] = flags
	story["promises"] = _append_records(story.promises, effects.get("promises_add", []),
		"promise", state, resolution_id)
	story["debts"] = _append_records(story.debts, effects.get("debts_add", []),
		"debt", state, resolution_id)
	story["promises"] = _transition_records(story.promises,
		effects.get("promises_resolve", []), "promise", "fulfilled", state, resolution_id)
	story["promises"] = _transition_records(story.promises,
		effects.get("promises_break", []), "promise", "broken", state, resolution_id)
	story["debts"] = _transition_records(story.debts,
		effects.get("debts_resolve", []), "debt", "repaid", state, resolution_id)
	story["debts"] = _transition_records(story.debts,
		effects.get("debts_forgive", []), "debt", "forgiven", state, resolution_id)
	_apply_relationship_deltas(story, effects.get("relationship_deltas", {}), characters)
	_apply_faction_deltas(story, effects.get("faction_deltas", {}))
	_apply_status_changes(state, effects)
	_schedule_echoes(story, effects.get("delayed_echoes", []), arc_id, resolution_id)


static func _apply_relationship_deltas(story: Dictionary, value: Variant,
		characters: Array) -> void:
	if not value is Dictionary:
		return
	var relationships: Dictionary = _normalize_relationships(story.get("relationships", {}), characters)
	for character_value in (value as Dictionary).keys():
		var character_id := str(character_value).left(48)
		var deltas_value: Variant = (value as Dictionary)[character_value]
		if not deltas_value is Dictionary:
			continue
		var relation: Dictionary = relationships.get(character_id,
			_default_relationship(character_id, character_id, 18))
		var deltas: Dictionary = deltas_value
		for field in RELATION_FIELDS:
			if deltas.has(field):
				relation[field] = clampi(int(relation.get(field, 0)) + int(deltas[field]), 0 if field in [
					"agency", "coercion", "dependency", "corruption"] else -100, 100)
		if deltas.has("stance"):
			relation["stance"] = str(deltas.stance).left(48)
		if deltas.has("consent_state"):
			relation["consent_state"] = str(deltas.consent_state).left(32)
		relationships[character_id] = relation
	story["relationships"] = relationships


static func _apply_faction_deltas(story: Dictionary, value: Variant) -> void:
	if not value is Dictionary:
		return
	var standings: Dictionary = story.get("faction_standings", {})
	for faction_value in (value as Dictionary).keys():
		var faction_id := str(faction_value).left(64)
		standings[faction_id] = clampi(int(standings.get(faction_id, 0)) +
			int((value as Dictionary)[faction_value]), -100, 100)
	story["faction_standings"] = standings


static func _apply_status_changes(state: Dictionary, source: Dictionary) -> void:
	var player: Dictionary = state.get("player", {})
	var statuses: Array = player.get("statuses", [])
	for status in _string_array(source.get("statuses_add", []), 32, 64):
		if not statuses.has(status):
			statuses.append(status)
	for status in _string_array(source.get("statuses_remove", []), 32, 64):
		statuses.erase(status)
	while statuses.size() > 64:
		statuses.pop_front()
	player["statuses"] = statuses
	state["player"] = player


static func _schedule_echoes(story: Dictionary, value: Variant, arc_id: String,
		choice_id: String) -> void:
	if not value is Array:
		return
	var pending: Array = story.pending_echoes
	for index in range((value as Array).size()):
		var echo_value: Variant = (value as Array)[index]
		if not echo_value is Dictionary:
			continue
		var echo: Dictionary = echo_value.duplicate(true)
		var delay := clampi(int(echo.get("after_chapters", 1)), 1, 64)
		echo["id"] = str(echo.get("id", "%s_echo_%d" % [choice_id, index])).left(96)
		echo["arc_id"] = arc_id
		echo["source_choice_id"] = choice_id
		echo["due_choice"] = int(story.choice_count) + delay - 1
		echo["text"] = str(echo.get("text", "")).left(360)
		echo["effects"] = echo.get("effects", {}).duplicate(true) if echo.get("effects", {}) is Dictionary else {}
		pending.append(echo)
	while pending.size() > MAX_ECHOES:
		pending.pop_front()
	story["pending_echoes"] = pending


static func _append_records(existing_value: Variant, additions_value: Variant, kind: String,
		state: Dictionary, choice_id: String) -> Array:
	var records := _normalize_records(existing_value, kind)
	if not additions_value is Array:
		return records
	for index in range((additions_value as Array).size()):
		var value: Variant = (additions_value as Array)[index]
		var record: Dictionary = value.duplicate(true) if value is Dictionary else {"text": str(value)}
		record["id"] = str(record.get("id", "%s_%s_%d" % [kind, choice_id, index])).left(96)
		record["kind"] = kind
		record["text"] = str(record.get("text", "")).left(240)
		record["character_id"] = str(record.get("character_id", "")).left(48)
		record["status"] = _record_status(record.get("status", "open"), kind)
		record["generation"] = int(state.get("generation", 1))
		record["turn"] = int(state.get("turn", 0))
		record["source_choice_id"] = choice_id
		if not record.text.is_empty():
			records.append(record)
	while records.size() > MAX_RECORDS:
		records.pop_front()
	return records


static func _transition_records(existing_value: Variant, ids_value: Variant, kind: String,
		status: String, state: Dictionary, choice_id: String) -> Array:
	var records := _normalize_records(existing_value, kind)
	var ids := _string_array(ids_value, 32, 96)
	if ids.is_empty():
		return records
	for index in range(records.size()):
		var record: Dictionary = records[index]
		if not ids.has(str(record.get("id", ""))) or str(record.get("status", "open")) != "open":
			continue
		record["status"] = _record_status(status, kind)
		record["closed_generation"] = int(state.get("generation", 1))
		record["closed_turn"] = int(state.get("turn", 0))
		record["closed_by_choice_id"] = choice_id.left(80)
		records[index] = record
	return records


static func _normalize_relationships(value: Variant, characters: Array) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for character_value in characters:
		if not character_value is Dictionary:
			continue
		var character: Dictionary = character_value
		var character_id := str(character.get("id", "")).left(48)
		if character_id.is_empty():
			continue
		var relation_value: Variant = source.get(character_id, {})
		var relation: Dictionary = relation_value if relation_value is Dictionary else {}
		var normalized := _default_relationship(character_id, str(character.get("name", character_id)),
			int(character.get("age", 18)))
		for key in relation.keys():
			normalized[key] = relation[key]
		for field in RELATION_FIELDS:
			var minimum := 0 if field in ["agency", "coercion", "dependency", "corruption"] else -100
			normalized[field] = clampi(int(normalized.get(field, 0)), minimum, 100)
		normalized["age"] = maxi(18, int(character.get("age", normalized.get("age", 18))))
		normalized["name"] = str(character.get("name", normalized.get("name", character_id))).left(48)
		result[character_id] = normalized
	for character_value in source.keys():
		var character_id := str(character_value).left(48)
		if result.has(character_id) or not source[character_value] is Dictionary:
			continue
		var relation: Dictionary = source[character_value]
		result[character_id] = _default_relationship(character_id,
			str(relation.get("name", character_id)), maxi(18, int(relation.get("age", 18))))
		for field in RELATION_FIELDS:
			result[character_id][field] = clampi(int(relation.get(field, result[character_id][field])),
				0 if field in ["agency", "coercion", "dependency", "corruption"] else -100, 100)
	return result


static func _default_relationship(character_id: String, display_name: String, age: int) -> Dictionary:
	return {
		"id": character_id,
		"name": display_name.left(48),
		"age": maxi(18, age),
		"trust": 0,
		"respect": 0,
		"desire": 0,
		"agency": 100,
		"coercion": 0,
		"dependency": 0,
		"corruption": 0,
		"stance": "尚未相识",
		"consent_state": "none",
	}


static func _normalize_route_history(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var result := {}
	for arc_value in (value as Dictionary).keys():
		var history_value: Variant = (value as Dictionary)[arc_value]
		if not history_value is Array:
			continue
		var history: Array = []
		for entry_value in (history_value as Array).slice(-MAX_ROUTE_HISTORY):
			if not entry_value is Dictionary:
				continue
			var entry: Dictionary = entry_value
			history.append({
				"choice_id": str(entry.get("choice_id", "")).left(80),
				"route_id": str(entry.get("route_id", "")).left(48),
				"phase": str(entry.get("phase", "main")).left(24),
				"stage": int(entry.get("stage", -1)),
				"generation": clampi(int(entry.get("generation", 1)), 1, 100000),
				"turn": maxi(0, int(entry.get("turn", 0))),
			})
		result[str(arc_value).left(48)] = history
	return result


static func _normalize_nested_int_map(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var result := {}
	for outer in (value as Dictionary).keys():
		result[str(outer).left(48)] = _normalize_int_map((value as Dictionary)[outer], 0, 100000)
	return result


static func _normalize_int_map(value: Variant, minimum: int, maximum: int) -> Dictionary:
	if not value is Dictionary:
		return {}
	var result := {}
	for key in (value as Dictionary).keys():
		result[str(key).left(64)] = clampi(int((value as Dictionary)[key]), minimum, maximum)
	return result


static func _normalize_flags(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var result := {}
	for key in (value as Dictionary).keys():
		if bool((value as Dictionary)[key]):
			result[str(key).left(64)] = true
	return result


static func _normalize_records(value: Variant, kind: String) -> Array:
	if not value is Array:
		return []
	var result: Array = []
	for entry_value in (value as Array).slice(-MAX_RECORDS):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var status := _record_status(entry.get("status", "open"), kind)
		var normalized := {
			"id": str(entry.get("id", kind)).left(96),
			"kind": kind,
			"text": str(entry.get("text", "")).left(240),
			"character_id": str(entry.get("character_id", "")).left(48),
			"status": status,
			"generation": clampi(int(entry.get("generation", 1)), 1, 100000),
			"turn": maxi(0, int(entry.get("turn", 0))),
			"source_choice_id": str(entry.get("source_choice_id", "")).left(80),
		}
		if status != "open":
			normalized["closed_generation"] = clampi(
				int(entry.get("closed_generation", normalized.generation)), 1, 100000)
			normalized["closed_turn"] = maxi(0,
				int(entry.get("closed_turn", normalized.turn)))
			normalized["closed_by_choice_id"] = str(
				entry.get("closed_by_choice_id", "")).left(80)
		result.append(normalized)
	return result


static func _record_status(value: Variant, kind: String) -> String:
	var status := str(value).left(24)
	var allowed: Array = PROMISE_STATUSES if kind == "promise" else DEBT_STATUSES
	return status if allowed.has(status) else "open"


static func _normalize_echoes(value: Variant, delivered: bool) -> Array:
	if not value is Array:
		return []
	var result: Array = []
	for entry_value in (value as Array).slice(-MAX_ECHOES):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value.duplicate(true)
		entry["id"] = str(entry.get("id", "echo")).left(96)
		entry["arc_id"] = str(entry.get("arc_id", "")).left(48)
		entry["source_choice_id"] = str(entry.get("source_choice_id", "")).left(80)
		entry["due_choice"] = maxi(0, int(entry.get("due_choice", 0)))
		entry["text"] = str(entry.get("text", "")).left(360)
		entry["effects"] = entry.get("effects", {}).duplicate(true) if entry.get("effects", {}) is Dictionary else {}
		if delivered:
			entry["delivered_generation"] = clampi(int(entry.get("delivered_generation", 1)), 1, 100000)
			entry["delivered_turn"] = maxi(0, int(entry.get("delivered_turn", 0)))
		result.append(entry)
	return result


static func _normalize_combat_outcomes(value: Variant) -> Dictionary:
	var result := {}
	if not value is Dictionary:
		return result
	for outcome in COMBAT_OUTCOMES:
		if not (value as Dictionary).has(outcome):
			continue
		var effects_value: Variant = (value as Dictionary).get(outcome, {})
		if effects_value is Dictionary:
			result[outcome] = (effects_value as Dictionary).duplicate(true)
	return result


static func _normalize_pending_combat_consequences(value: Variant) -> Array:
	if not value is Array:
		return []
	var result: Array = []
	for entry_value in (value as Array).slice(-MAX_PENDING_COMBAT_CONSEQUENCES):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var source_event_id := str(entry.get("source_event_id", "")).left(96)
		var source_choice_id := str(entry.get("source_choice_id", "")).left(96)
		var outcomes := _normalize_combat_outcomes(entry.get("outcomes", {}))
		if source_event_id.is_empty() or source_choice_id.is_empty() or outcomes.is_empty():
			continue
		result.append({
			"id": str(entry.get("id", "combat_consequence")).left(96),
			"source_event_id": source_event_id,
			"source_choice_id": source_choice_id,
			"arc_id": str(entry.get("arc_id", "chronicle")).left(48),
			"queued_generation": clampi(int(entry.get("queued_generation", 1)), 1, 100000),
			"queued_turn": maxi(0, int(entry.get("queued_turn", 0))),
			"outcomes": outcomes,
		})
	return result


static func _normalize_combat_consequence_history(value: Variant) -> Array:
	if not value is Array:
		return []
	var result: Array = []
	for entry_value in (value as Array).slice(-MAX_COMBAT_CONSEQUENCE_HISTORY):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var outcome := str(entry.get("outcome", ""))
		if not COMBAT_OUTCOMES.has(outcome):
			continue
		result.append({
			"id": str(entry.get("id", "combat_consequence")).left(96),
			"source_event_id": str(entry.get("source_event_id", "")).left(96),
			"source_choice_id": str(entry.get("source_choice_id", "")).left(96),
			"arc_id": str(entry.get("arc_id", "chronicle")).left(48),
			"outcome": outcome,
			"generation": clampi(int(entry.get("generation", 1)), 1, 100000),
			"turn": maxi(0, int(entry.get("turn", 0))),
			"effects_applied": bool(entry.get("effects_applied", false)),
		})
	return result


static func _string_array(value: Variant, maximum: int, length: int) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item in (value as Array).slice(0, maximum):
		var text := str(item).strip_edges().left(length)
		if not text.is_empty() and not result.has(text):
			result.append(text)
	return result


static func _bounded_strings(value: Variant, maximum: int, length: int) -> Array[String]:
	var result := _string_array(value, maximum, length)
	while result.size() > maximum:
		result.pop_front()
	return result


static func _contains_any(values: Array[String], needles: Array) -> bool:
	for needle in needles:
		if values.has(str(needle)):
			return true
	return false


static func _last_route_index(history: Array, route_id: String) -> int:
	for index in range(history.size() - 1, -1, -1):
		if str((history[index] as Dictionary).get("route_id", "")) == route_id:
			return index
	return -1


static func _invalid(code: String, arc_id: String, node_id: String,
		choice: Dictionary, detail: String = "") -> Dictionary:
	return {"ok": false, "code": code, "arc_id": arc_id, "node_id": node_id,
		"choice_id": str(choice.get("id", "")), "detail": detail}
