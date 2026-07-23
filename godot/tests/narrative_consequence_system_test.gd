extends SceneTree

const NarrativeScript = preload("res://scripts/narrative_consequence_system.gd")

const CHARACTERS := [
	{"id": "lin", "name": "Lin", "age": 26},
	{"id": "mei", "name": "Mei", "age": 31},
]

var failures: Array[String] = []


func _init() -> void:
	_test_new_state_normalization()
	_test_choice_persists_consequences_and_echoes()
	_test_obligation_lifecycle()
	_test_relationship_dimensions_are_independent()
	_test_intimacy_boundaries_and_control_gate()
	_test_route_divergence_changes_next_echo_and_resolution()
	_test_combat_outcomes_wait_for_result()

	if failures.is_empty():
		print("NARRATIVE_CONSEQUENCE_SYSTEM_TEST_OK: normalization, authored consequences, combat outcomes, consent boundaries, route divergence and delayed echoes passed")
		quit(0)
	else:
		for failure in failures:
			push_error("NARRATIVE_CONSEQUENCE_SYSTEM_TEST_FAILED: %s" % failure)
		quit(1)


func _test_new_state_normalization() -> void:
	var state := {"story": {"choice_count": -99, "flags": {"kept": true, "discarded": false},
		"route_history": {"broken": "not-an-array"}, "relationships": {"lin": {
			"trust": 999, "agency": -12, "coercion": 999, "dependency": -3, "corruption": 999}},
		"pending_echoes": "not-an-array"}}
	var story: Dictionary = NarrativeScript.normalize(state, CHARACTERS)
	var relationships: Dictionary = story.get("relationships", {})
	var lin: Dictionary = relationships.get("lin", {})
	_expect(int(story.get("story_version", 0)) == NarrativeScript.STATE_VERSION,
		"a fresh or legacy story state must be upgraded to the current narrative version")
	_expect(int(story.get("choice_count", -1)) == 0 and
		(story.get("route_history", {}) as Dictionary).is_empty() and
		(story.get("pending_echoes", []) as Array).is_empty(),
		"invalid counters, route history and echo containers must normalize to bounded defaults")
	_expect((story.get("flags", {}) as Dictionary).has("kept") and
		not (story.get("flags", {}) as Dictionary).has("discarded"),
		"flag normalization must retain truthy flags and discard false values")
	_expect(int(lin.get("trust", 0)) == 100 and int(lin.get("agency", -1)) == 0 and
		int(lin.get("coercion", -1)) == 100 and int(lin.get("dependency", -1)) == 0 and
		int(lin.get("corruption", -1)) == 100 and int(lin.get("age", 0)) == 26,
		"relationship dimensions and adult age must be clamped independently")
	_expect((story.get("promises", []) as Array).is_empty() and
		(story.get("debts", []) as Array).is_empty() and
		(story.get("delivered_echoes", []) as Array).is_empty(),
		"a new state must expose empty obligation and delivered-echo collections")


func _test_choice_persists_consequences_and_echoes() -> void:
	var state := _new_state()
	state.story.flags["old_flag"] = true
	var choice := _base_choice("shelter", "shelter_route")
	choice["route_weight"] = 3
	choice["flags_add"] = ["rescued", "remembered"]
	choice["flags_remove"] = ["old_flag"]
	choice["promises_add"] = [{"id": "promise_lantern", "text": "Return the lantern", "character_id": "lin"}]
	choice["debts_add"] = ["A debt owed to the river"]
	choice["relationship_deltas"] = {"lin": {
		"trust": 12, "respect": 7, "desire": 5, "agency": -9,
		"coercion": 11, "dependency": 13, "corruption": 17,
		"stance": "watchful", "consent_state": "unresolved"}}
	choice["faction_deltas"] = {"river_court": 14}
	choice["statuses_add"] = ["marked"]
	choice["delayed_echoes"] = [{
		"id": "lantern_echo", "after_chapters": 2,
		"text": "The lantern is returned in the next chapter.",
		"effects": {"flags_add": ["echo_returned"], "statuses_add": ["remembered"],
			"relationship_deltas": {"lin": {"trust": 4}},
			"faction_deltas": {"river_court": -3}},
	}]
	var event := {"story_arc_id": "river", "story_phase": "main", "story_stage": 1}
	var result: Dictionary = NarrativeScript.apply_choice(state, event, choice, CHARACTERS)
	var story: Dictionary = state.story
	var relation: Dictionary = (story.relationships as Dictionary).get("lin", {})
	_expect(bool(result.get("ok", false)) and int(result.get("choice_count", 0)) == 1,
		"an authored choice must be recorded and increment the narrative choice counter")
	_expect(NarrativeScript.last_route_for_arc(state, "river") == "shelter_route" and
		int((story.route_scores as Dictionary).river.shelter_route) == 3,
		"route history and weighted route scores must retain the selected route")
	_expect(bool((story.flags as Dictionary).get("rescued", false)) and
		not (story.flags as Dictionary).has("old_flag") and
		bool((story.flags as Dictionary).get("remembered", false)),
		"choice flags must add new facts and remove explicitly retired facts")
	var promises: Array = story.promises
	var debts: Array = story.debts
	_expect(promises.size() == 1 and str((promises[0] as Dictionary).get("kind", "")) == "promise" and
		str((promises[0] as Dictionary).get("source_choice_id", "")) == "shelter" and
		debts.size() == 1 and str((debts[0] as Dictionary).get("kind", "")) == "debt",
		"promises and debts must carry their kind and source choice for later prose")
	_expect(int(relation.get("trust", 0)) == 12 and int(relation.get("respect", 0)) == 7 and
		int(relation.get("desire", 0)) == 5 and int(relation.get("agency", 0)) == 91 and
		int(relation.get("coercion", 0)) == 11 and int(relation.get("dependency", 0)) == 13 and
		int(relation.get("corruption", 0)) == 17 and
		str(relation.get("stance", "")) == "watchful" and
		str(relation.get("consent_state", "")) == "unresolved",
		"relationship trust, respect, desire, agency, control, dependency and corruption must persist")
	_expect(int((story.faction_standings as Dictionary).get("river_court", 0)) == 14 and
		(state.player.statuses as Array).has("marked"),
		"faction consequences and player status consequences must be applied with the choice")
	var pending: Array = story.pending_echoes
	_expect(pending.size() == 1 and int((pending[0] as Dictionary).get("due_choice", -1)) == 2 and
		NarrativeScript.deliver_due_echoes(state, CHARACTERS).is_empty(),
		"a delayed echo must remain pending until its due chapter")

	# A second chapter advances the choice counter to the echo's due point.
	NarrativeScript.apply_choice(state, {"story_arc_id": "river", "story_phase": "main", "story_stage": 2},
		_base_choice("quiet_followup", "quiet_route"), CHARACTERS)
	var delivered: Array = NarrativeScript.deliver_due_echoes(state, CHARACTERS)
	var delivered_story: Dictionary = state.story
	_expect(delivered.size() == 1 and str(delivered[0]) == "The lantern is returned in the next chapter." and
		(delivered_story.pending_echoes as Array).is_empty() and
		(delivered_story.delivered_echoes as Array).size() == 1 and
		bool((delivered_story.flags as Dictionary).get("echo_returned", false)) and
		(state.player.statuses as Array).has("remembered") and
		int((delivered_story.faction_standings as Dictionary).get("river_court", 0)) == 11 and
		int((delivered_story.relationships as Dictionary).lin.trust) == 16,
		"due echoes must deliver text and their flags, statuses, relationship and faction effects")


func _test_relationship_dimensions_are_independent() -> void:
	var state := _new_state()
	var event := {"story_arc_id": "dimensions", "story_phase": "main", "story_stage": 0}
	NarrativeScript.apply_choice(state, event,
		_base_choice_with_relation("agency_only", "agency_route", {"agency": -18}), CHARACTERS)
	var relation: Dictionary = (state.story.relationships as Dictionary).lin
	_expect(int(relation.agency) == 82 and int(relation.coercion) == 0 and
		int(relation.dependency) == 0 and int(relation.corruption) == 0,
		"changing autonomy must not imply control, dependency or corruption")
	NarrativeScript.apply_choice(state, event,
		_base_choice_with_relation("control_only", "control_route", {"coercion": 23}), CHARACTERS)
	relation = (state.story.relationships as Dictionary).lin
	_expect(int(relation.agency) == 82 and int(relation.coercion) == 23 and
		int(relation.dependency) == 0 and int(relation.corruption) == 0,
		"changing control must not rewrite autonomy, dependency or corruption")
	NarrativeScript.apply_choice(state, event,
		_base_choice_with_relation("dependency_only", "dependency_route", {"dependency": 31}), CHARACTERS)
	relation = (state.story.relationships as Dictionary).lin
	_expect(int(relation.agency) == 82 and int(relation.coercion) == 23 and
		int(relation.dependency) == 31 and int(relation.corruption) == 0,
		"changing dependency must not rewrite autonomy, control or corruption")
	NarrativeScript.apply_choice(state, event,
		_base_choice_with_relation("corruption_only", "corruption_route", {"corruption": 47}), CHARACTERS)
	relation = (state.story.relationships as Dictionary).lin
	_expect(int(relation.agency) == 82 and int(relation.coercion) == 23 and
		int(relation.dependency) == 31 and int(relation.corruption) == 47,
		"changing corruption must not rewrite autonomy, control or dependency")


func _test_obligation_lifecycle() -> void:
	var state := _new_state()
	var event := {"story_arc_id": "oath", "story_phase": "main", "story_stage": 0}
	var opening := _base_choice("make_oath", "oath_route")
	opening["promises_add"] = [{"id": "keep_watch", "text": "Keep watch", "character_id": "lin"}]
	opening["debts_add"] = [{"id": "river_price", "text": "Repay the river", "character_id": "mei"}]
	NarrativeScript.apply_choice(state, event, opening, CHARACTERS)
	_expect(NarrativeScript.open_obligation_summary(state, CHARACTERS) == "Keep watch",
		"an open promise must be visible before it is closed")

	state.turn = 11
	var closure := _base_choice("keep_word", "oath_route")
	closure["promises_resolve"] = ["keep_watch"]
	closure["debts_forgive"] = ["river_price"]
	NarrativeScript.apply_choice(state, event, closure, CHARACTERS)
	var fulfilled: Dictionary = state.story.promises[0]
	var forgiven: Dictionary = state.story.debts[0]
	_expect(str(fulfilled.status) == "fulfilled" and str(forgiven.status) == "forgiven" and
		int(fulfilled.closed_turn) == 11 and str(fulfilled.closed_by_choice_id) == "keep_word",
		"choices must persist how and when a promise was fulfilled or a debt was forgiven")
	_expect(NarrativeScript.open_obligation_summary(state, CHARACTERS).contains("没有"),
		"closed obligations must leave the current-obligation summary")

	var delayed := _base_choice("dangerous_bargain", "oath_route")
	delayed["promises_add"] = [{"id": "impossible_oath", "text": "Do the impossible"}]
	delayed["debts_add"] = [{"id": "medicine_debt", "text": "Return the medicine"}]
	delayed["delayed_echoes"] = [{"id": "bargain_fallout", "after_chapters": 1,
		"text": "The bargain comes due.", "effects": {
			"promises_break": ["impossible_oath"], "debts_resolve": ["medicine_debt"]}}]
	NarrativeScript.apply_choice(state, event, delayed, CHARACTERS)
	NarrativeScript.deliver_due_echoes(state, CHARACTERS)
	var broken: Dictionary = state.story.promises[-1]
	var repaid: Dictionary = state.story.debts[-1]
	_expect(str(broken.status) == "broken" and str(repaid.status) == "repaid" and
		str(broken.closed_by_choice_id) == "bargain_fallout",
		"delayed story echoes must be able to break promises and repay debts without deleting history")


func _test_intimacy_boundaries_and_control_gate() -> void:
	var adult_choice := _base_choice("adult_intimacy", "adult_route")
	adult_choice["content_tags"] = ["romance"]
	adult_choice["consent"] = "affirmative"
	adult_choice["content_mode"] = "fade_to_black"
	adult_choice["participants"] = ["player", "lin"]
	var validation: Dictionary = NarrativeScript.validate_choice(adult_choice, _character_map(),
		"intimacy_arc", "adult_node")
	_expect(bool(validation.get("ok", false)),
		"an adult, affirmative, fade-to-black intimate choice must pass validation")
	var available_state := _new_state()
	var availability: Dictionary = NarrativeScript.choice_availability(available_state,
		adult_choice, CHARACTERS)
	_expect(bool(availability.get("available", false)),
		"an adult intimate choice must be selectable when agency is high and control is zero")

	var mixed_choice := adult_choice.duplicate(true)
	mixed_choice["id"] = "coerced_intimacy"
	mixed_choice["content_tags"] = ["intimacy", "coercion"]
	var mixed_validation: Dictionary = NarrativeScript.validate_choice(mixed_choice, _character_map(),
		"intimacy_arc", "mixed_node")
	_expect(not bool(mixed_validation.get("ok", true)) and
		str(mixed_validation.get("code", "")) == "coercion_cannot_be_intimacy",
		"coercion combined with intimacy must always be rejected")

	var controlled_state := _new_state()
	controlled_state.story.relationships.lin.coercion = 1
	var controlled_availability: Dictionary = NarrativeScript.choice_availability(controlled_state,
		adult_choice, CHARACTERS)
	_expect(not bool(controlled_availability.get("available", true)),
		"intimacy must be unavailable while any unresolved control remains")
	controlled_state.story.relationships.lin.coercion = 0
	var released_availability: Dictionary = NarrativeScript.choice_availability(controlled_state,
		adult_choice, CHARACTERS)
	_expect(bool(released_availability.get("available", false)),
		"releasing control must reopen an otherwise valid adult intimate choice")


func _test_route_divergence_changes_next_echo_and_resolution() -> void:
	var event := {"story_arc_id": "fork", "story_phase": "main", "story_stage": 0}
	var mercy := _base_choice("mercy", "mercy")
	mercy["delayed_echoes"] = [{"id": "mercy_next", "after_chapters": 1,
		"text": "The next chapter remembers mercy."}]
	var domination := _base_choice("domination", "domination")
	domination["delayed_echoes"] = [{"id": "domination_next", "after_chapters": 1,
		"text": "The next chapter remembers domination."}]
	var mercy_state := _new_state()
	var domination_state := _new_state()
	NarrativeScript.apply_choice(mercy_state, event, mercy, CHARACTERS)
	NarrativeScript.apply_choice(domination_state, event, domination, CHARACTERS)
	_expect(NarrativeScript.last_route_for_arc(mercy_state, "fork") == "mercy" and
		NarrativeScript.last_route_for_arc(domination_state, "fork") == "domination" and
		mercy_state.story.route_history != domination_state.story.route_history,
		"different first choices must create different route histories")
	var arc := {"main_route_resolutions": {"mercy": "mercy_ending", "domination": "domination_ending"}}
	var mercy_resolution := NarrativeScript.route_resolution(mercy_state.story, arc, "fork", "main")
	var domination_resolution := NarrativeScript.route_resolution(domination_state.story, arc, "fork", "main")
	_expect(mercy_resolution == "mercy_ending" and domination_resolution == "domination_ending" and
		mercy_resolution != domination_resolution,
		"different preferred routes must resolve to different authored final settlements")
	var mercy_next: Array = NarrativeScript.deliver_due_echoes(mercy_state, CHARACTERS)
	var domination_next: Array = NarrativeScript.deliver_due_echoes(domination_state, CHARACTERS)
	_expect(mercy_next.size() == 1 and domination_next.size() == 1 and
		str(mercy_next[0]) != str(domination_next[0]),
		"different preferred routes must carry different next-chapter variants through delayed echoes")


func _test_combat_outcomes_wait_for_result() -> void:
	var victory_state := _new_state()
	var event := {"id": "ambush_gate", "story_arc_id": "rival", "story_phase": "main",
		"story_stage": 2}
	var choice := _base_choice("recover_evidence", "alliance")
	choice["combat_trigger"] = true
	choice["combat_outcomes"] = {
		"victory": {"flags_add": ["evidence_recovered"], "statuses_remove": ["marked"]},
		"escaped": {"flags_add": ["evidence_incomplete"], "statuses_add": ["marked"]},
		"expired": {"flags_add": ["vault_resealed"]},
	}
	NarrativeScript.apply_choice(victory_state, event, choice, CHARACTERS)
	_expect(not bool((victory_state.story.flags as Dictionary).get("evidence_recovered", false)) and
		(victory_state.story.pending_combat_consequences as Array).size() == 1,
		"choosing to fight must queue outcome facts instead of claiming victory before combat")
	var victory: Dictionary = NarrativeScript.resolve_combat_outcome(victory_state,
		"ambush_gate", "recover_evidence", "victory", CHARACTERS)
	_expect(bool(victory.get("applied", false)) and
		bool((victory_state.story.flags as Dictionary).get("evidence_recovered", false)) and
		(victory_state.story.pending_combat_consequences as Array).is_empty() and
		str((victory_state.story.combat_consequence_history[-1] as Dictionary).outcome) == "victory",
		"victory must atomically apply its authored facts, clear pending state and enter history")
	var repeated: Dictionary = NarrativeScript.resolve_combat_outcome(victory_state,
		"ambush_gate", "recover_evidence", "escaped", CHARACTERS)
	_expect(not bool(repeated.get("applied", true)) and
		not bool((victory_state.story.flags as Dictionary).get("evidence_incomplete", false)),
		"combat consequence resolution must be idempotent and never apply a second outcome")

	var escape_state := _new_state()
	NarrativeScript.apply_choice(escape_state, event, choice, CHARACTERS)
	NarrativeScript.resolve_combat_outcome(escape_state, "ambush_gate", "recover_evidence",
		"escaped", CHARACTERS)
	_expect(bool((escape_state.story.flags as Dictionary).get("evidence_incomplete", false)) and
		not bool((escape_state.story.flags as Dictionary).get("evidence_recovered", false)) and
		(escape_state.player.statuses as Array).has("marked"),
		"escape must apply only its own persistent aftermath, never the victory facts")

	var legacy_state := _new_state()
	legacy_state.story["pending_combat_consequences"] = "broken"
	legacy_state.story["combat_consequence_history"] = [{"outcome": "impossible"}]
	var normalized: Dictionary = NarrativeScript.normalize(legacy_state, CHARACTERS)
	_expect((normalized.pending_combat_consequences as Array).is_empty() and
		(normalized.combat_consequence_history as Array).is_empty(),
		"legacy or corrupted combat-consequence containers must fail closed during normalization")


func _new_state() -> Dictionary:
	var state := {
		"generation": 1,
		"turn": 7,
		"player": {"age": 24, "spirit_stones": 100, "pills": 10, "statuses": []},
		"story": {},
	}
	NarrativeScript.normalize(state, CHARACTERS)
	return state


func _character_map() -> Dictionary:
	return {"lin": {"id": "lin", "name": "Lin", "age": 26},
		"mei": {"id": "mei", "name": "Mei", "age": 31}}


func _base_choice(choice_id: String, route_id: String) -> Dictionary:
	return {"id": choice_id, "text": choice_id, "outcome": "recorded", "route_id": route_id,
		"deltas": {}, "path_deltas": {}}


func _base_choice_with_relation(choice_id: String, route_id: String,
		deltas: Dictionary) -> Dictionary:
	var choice := _base_choice(choice_id, route_id)
	choice["relationship_deltas"] = {"lin": deltas}
	return choice


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
