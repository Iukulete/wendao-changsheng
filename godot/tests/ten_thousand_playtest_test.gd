extends SceneTree

const DEFAULT_RUN_COUNT := 10000
const BASE_SEED := 73000001
const ERA_IDS := [
	"classical", "steam", "star_network", "wasteland", "final_age", "immortal_dynasty",
]
const RESOURCE_FIELDS := [
	"exp", "hp", "mp", "karma", "dao_heart", "reputation", "enmity",
	"spirit_stones", "pills",
]
const PATH_FIELDS := [
	"compassion", "ambition", "defiance", "insight", "creation", "bonds",
]
const GameStateScript = preload("res://scripts/game_state.gd")
const WorldSimulationScript = preload("res://scripts/world_simulation.gd")
const CultivationScript = preload("res://scripts/cultivation_system.gd")
const ReincarnationScript = preload("res://scripts/reincarnation_system.gd")
const EventCatalogScript = preload("res://scripts/event_catalog.gd")
const StorySystemScript = preload("res://scripts/story_system.gd")
const ObjectiveSystemScript = preload("res://scripts/objective_system.gd")
const EncounterSystemScript = preload("res://scripts/encounter_system.gd")
const ItemSystemScript = preload("res://scripts/item_system.gd")
const AchievementSystemScript = preload("res://scripts/achievement_system.gd")
const CombatSystemScript = preload("res://scripts/combat_system.gd")
const DungeonSystemScript = preload("res://scripts/dungeon_system.gd")
const SaveServiceScript = preload("res://scripts/save_service.gd")
const LocalAIBridgeScript = preload("res://scripts/local_ai_bridge.gd")

var failures: Array[String] = []
var mode_counts: Dictionary = {}
var failure_counts: Dictionary = {}
var save_service: RefCounted
var ai_bridge: Node
var run_count := DEFAULT_RUN_COUNT
var run_offset := 0
var telemetry: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var configured_count := int(OS.get_environment("WENDAO_PLAYTEST_COUNT"))
	if configured_count > 0:
		run_count = mini(configured_count, 100000)
	run_offset = maxi(0, int(OS.get_environment("WENDAO_PLAYTEST_OFFSET")))
	telemetry = _new_telemetry()
	var save_root := ProjectSettings.globalize_path("res://").path_join("..").path_join(
		".tmp").path_join("playtest-saves-%d" % run_offset).simplify_path()
	save_service = SaveServiceScript.new("stress", save_root)
	save_service.call("clear_slot")
	ai_bridge = LocalAIBridgeScript.new()
	root.add_child(ai_bridge)
	var started_usec := Time.get_ticks_usec()
	for local_index in range(run_count):
		var index := run_offset + local_index
		var mode := index % 6
		mode_counts[str(mode)] = int(mode_counts.get(str(mode), 0)) + 1
		var result := _play_one(index, mode)
		if not bool(result.get("ok", false)):
			_record_failure(index, mode, result)
		if local_index > 0 and local_index % 500 == 0:
			print("PLAYTEST_PROGRESS: %d/%d offset=%d failures=%d" % [
				local_index, run_count, run_offset, failures.size()])
	var elapsed_seconds := float(Time.get_ticks_usec() - started_usec) / 1000000.0
	save_service.call("clear_slot")
	DirAccess.remove_absolute(save_root)
	ai_bridge.free()
	var summary := {
		"runs": run_count,
		"offset": run_offset,
		"failures": failures.size(),
		"failure_counts": failure_counts,
		"mode_counts": mode_counts,
		"elapsed_seconds": snappedf(elapsed_seconds, 0.001),
		"runs_per_second": snappedf(float(run_count) / maxf(0.001, elapsed_seconds), 0.001),
		"failure_samples": failures.slice(0, 24),
		"telemetry": telemetry,
	}
	print("PLAYTEST_SUMMARY: %s" % JSON.stringify(summary))
	if failures.is_empty():
		print("TEN_THOUSAND_PLAYTEST_OK: %d deterministic mixed sessions passed at offset %d" % [
			run_count, run_offset])
		quit(0)
	else:
		for failure in failures:
			push_error("TEN_THOUSAND_PLAYTEST_FAILED: %s" % failure)
		quit(1)


func _play_one(index: int, mode: int) -> Dictionary:
	var seed_value := BASE_SEED + index * 7919
	var roots: Array = []
	if index % 10 == 0:
		roots = [1, 1, 1, 1, 1]
	elif index % 10 == 1:
		roots = [10, 10, 10, 10, 10]
	var state := GameStateScript.create_new_game("试玩%d" % (index + 1), seed_value, roots)
	var root_cohort := _root_cohort(state.player)
	_increment(telemetry.root_cohort_sessions, root_cohort)
	state["current_era_id"] = ERA_IDS[index % ERA_IDS.size()]
	state["current_era"] = str(GameStateScript.ERA_NAMES.get(
		str(state.current_era_id), GameStateScript.ERA_NAMES.classical))
	var initialized := WorldSimulationScript.initialize(state)
	if not bool(initialized.get("ok", false)):
		return _fail("world_initialize", initialized)
	GameStateScript.ensure_v2(state)
	ItemSystemScript.normalize(state)
	CombatSystemScript.normalize(state)
	DungeonSystemScript.normalize(state)
	StorySystemScript.normalize(state)
	ObjectiveSystemScript.normalize(state)
	EncounterSystemScript.normalize(state)
	ObjectiveSystemScript.choose(state,
		str(ObjectiveSystemScript.OBJECTIVE_IDS[mode % ObjectiveSystemScript.OBJECTIVE_IDS.size()]))
	AchievementSystemScript.normalize(state)
	AchievementSystemScript.check_progress(state)
	var invariant := _assert_state(state, "new")
	if not bool(invariant.get("ok", false)):
		return invariant

	var event := EventCatalogScript.select_event(state, str(state.current_era))
	if event.is_empty() or (event.get("choices", []) as Array).size() != 3:
		return _fail("event_select", {"era": state.current_era})
	var event_result := _resolve_event(state, event, (index + mode) % 3)
	if not bool(event_result.get("ok", false)):
		return event_result
	invariant = _assert_state(state, "event")
	if not bool(invariant.get("ok", false)):
		return invariant

	var story_event := StorySystemScript.next_event(state)
	if not story_event.is_empty():
		_increment(telemetry, "story_triggers")
		telemetry["story_trigger_event_total"] = int(telemetry.story_trigger_event_total) + \
			int((state.get("player", {}) as Dictionary).get("total_events", 0))
		var story_result := _resolve_event(state, story_event, (index + 1) % 3)
		if not bool(story_result.get("ok", false)):
			return story_result
		invariant = _assert_state(state, "story")
		if not bool(invariant.get("ok", false)):
			return invariant

	var meditation_count := 1 + (mode % 3)
	for step in range(meditation_count):
		var meditation_mode: String = str(CultivationScript.MEDITATION_MODE_IDS[
			(mode + step) % CultivationScript.MEDITATION_MODE_IDS.size()])
		var meditation := CultivationScript.meditate(
			state, 52 + ((index + step) % 43), meditation_mode)
		if not bool(meditation.get("ok", false)) and str(meditation.get("code", "")) == "insufficient_hp":
			meditation_mode = "steady"
			meditation = CultivationScript.meditate(state, 52 + ((index + step) % 43), meditation_mode)
		if not bool(meditation.get("ok", false)):
			return _fail("meditate", meditation)
		_record_product_action(state, "meditate_%s" % meditation_mode)
		if CultivationScript.is_dead(state):
			break
	invariant = _assert_state(state, "cultivation")
	if not bool(invariant.get("ok", false)):
		return invariant

	if mode == 2 or mode == 5:
		var player: Dictionary = state.player
		player["level"] = 9
		player["exp"] = CultivationScript.exp_needed(player)
		state["player"] = player
		var breakthrough := CultivationScript.attempt_breakthrough(state, 1)
		if not bool(breakthrough.get("ok", false)) or not bool(breakthrough.get("success", false)):
			return _fail("breakthrough", breakthrough)
		_record_product_action(state, "breakthrough_success")
		invariant = _assert_state(state, "breakthrough")
		if not bool(invariant.get("ok", false)):
			return invariant

	if mode == 0 or mode == 4 or mode == 5:
		if not CultivationScript.is_dead(state):
			if not bool(EncounterSystemScript.summary(state).get("active", false)):
				EncounterSystemScript.offer(state, "playtest", "自动试玩敌踪",
					"由已完成的历练选择引来。")
			var combat_start := CombatSystemScript.start_combat(state)
			if not bool(combat_start.get("ok", false)):
				return _fail("combat_start", combat_start)
			EncounterSystemScript.consume(state)
			_increment(telemetry, "encounters_engaged")
			var combat_result := CombatSystemScript.auto_resolve(state, 128)
			var combat_outcome := str(combat_result.get("outcome", ""))
			if combat_outcome not in ["victory", "defeat", "abandoned"]:
				return _fail("combat_finish", combat_result)
			_increment(telemetry.combat_outcomes, combat_outcome)
			_increment(telemetry.combat_outcomes_by_root, "%s:%s" % [root_cohort, combat_outcome])
			_record_combat_pressure(combat_result, root_cohort)
			if combat_outcome == "victory":
				CultivationScript.advance_time(state, 1)
				_record_product_action(state, "combat_victory")
			if CombatSystemScript.has_active_combat(state):
				return _fail("combat_still_active", combat_result)
			invariant = _assert_state(state, "combat")
			if not bool(invariant.get("ok", false)):
				return invariant

	if mode == 1 or mode == 4 or mode == 5:
		if not CultivationScript.is_dead(state):
			var dungeon_start := DungeonSystemScript.start(state)
			if not bool(dungeon_start.get("ok", false)):
				return _fail("dungeon_start", dungeon_start)
			var dungeon_result := DungeonSystemScript.auto_resolve(state, 512)
			var dungeon_outcome := str(dungeon_result.get("outcome", ""))
			if dungeon_outcome not in ["completed", "defeat", "abandoned"]:
				return _fail("dungeon_finish", dungeon_result)
			_increment(telemetry.dungeon_outcomes, dungeon_outcome)
			_increment(telemetry.dungeon_outcomes_by_root, "%s:%s" % [root_cohort, dungeon_outcome])
			var dungeon_run: Dictionary = dungeon_result.get("run", {})
			CultivationScript.advance_time(state,
				maxi(1, int(ceil(float(dungeon_run.get("depth", 1)) / 2.0))))
			_record_product_action(state, "dungeon_completed" if dungeon_outcome == "completed" else \
				"dungeon_defeat" if dungeon_outcome == "defeat" else "dungeon_abandoned")
			if DungeonSystemScript.has_active_run(state):
				return _fail("dungeon_still_active", dungeon_result)
			invariant = _assert_state(state, "dungeon")
			if not bool(invariant.get("ok", false)):
				return invariant

	if index % 17 == 0:
		var fallback_a: Dictionary = ai_bridge.fallback_event(state, "10k-playtest")
		var fallback_b: Dictionary = ai_bridge.fallback_event(state, "10k-playtest")
		if fallback_a != fallback_b or (fallback_a.get("choices", []) as Array).size() != 3:
			return _fail("ai_fallback", fallback_a)
		_increment(telemetry, "ai_fallbacks")

	if index % 10 == 0:
		save_service.call("clear_slot")
		var saved: Dictionary = save_service.call("save_game", state)
		if not bool(saved.get("ok", false)):
			return _fail("save", saved)
		var loaded: Dictionary = save_service.call("load_game")
		if not bool(loaded.get("ok", false)):
			return _fail("load", loaded)
		var restored: Dictionary = loaded.get("state", {})
		if int(restored.get("rng_cursor", -1)) != int(state.get("rng_cursor", -2)) or \
				int((restored.get("player", {}) as Dictionary).get("total_events", -1)) != \
				int((state.get("player", {}) as Dictionary).get("total_events", -2)):
			return _fail("save_roundtrip", {"loaded": loaded})
		_increment(telemetry, "save_roundtrips")
		save_service.call("clear_slot")

	if CultivationScript.is_dead(state):
		_increment(telemetry, "natural_deaths")
	if mode == 3 or mode == 5:
		var player: Dictionary = state.player
		player["age"] = int(player.get("lifespan", 1))
		state["player"] = player
		var closed := ReincarnationScript.close_life(state, "自动试玩轮回压力")
		if not bool(closed.get("ok", false)):
			return _fail("close_life", closed)
		var next := ReincarnationScript.begin_next_life(state, "试玩续世%d" % (index + 2))
		if not bool(next.get("ok", false)):
			return _fail("begin_life", next)
		_increment(telemetry, "reincarnations")
		invariant = _assert_state(state, "reincarnation")
		if not bool(invariant.get("ok", false)):
			return invariant
	_record_session_telemetry(state)
	return {"ok": true, "code": "playtest_passed"}


func _resolve_event(state: Dictionary, event: Dictionary, choice_index: int) -> Dictionary:
	var choices: Array = event.get("choices", [])
	_record_offered_choices(event)
	if choice_index < 0 or choice_index >= choices.size():
		return _fail("event_choice", {"event_id": event.get("id", "")})
	var requested_choice_index := choice_index
	var player: Dictionary = state.player
	var choice: Dictionary = {}
	for offset in range(choices.size()):
		var candidate: Dictionary = choices[(choice_index + offset) % choices.size()]
		if _choice_is_available(player, candidate):
			choice_index = (choice_index + offset) % choices.size()
			choice = candidate
			break
	if choice.is_empty():
		return _fail("event_no_available_choice", {"event_id": event.get("id", "")})
	if choice_index != requested_choice_index:
		_increment(telemetry, "choice_availability_fallbacks")
	_record_selected_choice(event, choice_index, choice)
	var deltas: Dictionary = choice.get("deltas", {})
	for key in deltas.keys():
		if player.has(key):
			player[key] = int(player[key]) + int(deltas[key])
	var path: Dictionary = player.get("path", {})
	for path_id in (choice.get("path_deltas", {}) as Dictionary).keys():
		if path.has(path_id):
			path[path_id] = int(path[path_id]) + int((choice.path_deltas as Dictionary)[path_id])
	player["path"] = path
	player["hp"] = clampi(int(player.get("hp", 0)), 0, int(player.get("max_hp", 1)))
	player["exp"] = maxi(0, int(player.get("exp", 0)))
	player["total_events"] = int(player.get("total_events", 0)) + 1
	state["player"] = player
	var record := EventCatalogScript.record_resolution(state, event)
	if not bool(record.get("ok", false)):
		return _fail("event_record", record)
	var story_result := StorySystemScript.resolve_choice(state, event, choice_index)
	if str(event.get("source", "")) == "story_arc" and not bool(story_result.get("ok", false)):
		return _fail("story_resolve", story_result)
	AchievementSystemScript.add_resonance(state, 3, "10k 自动试玩抉择")
	state["feedback"] = str(choice.get("outcome", "因果落定。"))
	var memories: Array = state.get("recent_memories", [])
	memories.append("%s：%s" % [str(event.get("title", "无名事件")), str(choice.get("text", "沉默"))])
	while memories.size() > 12:
		memories.pop_front()
	state["recent_memories"] = memories
	CultivationScript.advance_time(state, 1)
	_record_product_action(state, "story_event" if str(event.get("source", "")) == "story_arc" else \
		"local_ai_event" if str(event.get("source", "")) == "local_ai" else "adventure")
	var encounter_offer := EncounterSystemScript.offer_from_choice(state, event, choice)
	if str(encounter_offer.get("code", "")) == "encounter_offered":
		_increment(telemetry, "encounters_offered")
	return {"ok": true, "code": "event_resolved"}


func _record_product_action(state: Dictionary, action_id: String) -> void:
	var expiry := EncounterSystemScript.expire_if_needed(state)
	if bool(expiry.get("expired", false)):
		_increment(telemetry, "encounters_expired")
	var objective_result := ObjectiveSystemScript.record_action(state, action_id)
	if str(objective_result.get("code", "")) == "objective_completed":
		_increment(telemetry.objective_completions,
			str(objective_result.get("objective_id", "unknown")))
	elif str(objective_result.get("code", "")) == "objective_missed":
		_increment(telemetry.objective_misses,
			str(objective_result.get("objective_id", "unknown")))


func _assert_state(state: Dictionary, phase: String) -> Dictionary:
	GameStateScript.ensure_v2(state)
	ObjectiveSystemScript.normalize(state)
	EncounterSystemScript.normalize(state)
	var player: Dictionary = state.get("player", {})
	var world: Dictionary = state.get("world", {})
	var current_era_id := str(state.get("current_era_id", ""))
	if current_era_id not in GameStateScript.ERA_IDS:
		return _fail("invariant_era:%s" % phase, {"era": current_era_id})
	if int(player.get("max_hp", 0)) <= 0 or int(player.get("hp", -1)) < 0 or \
			int(player.get("hp", 0)) > int(player.get("max_hp", 0)):
		return _fail("invariant_hp:%s" % phase, {"player": player})
	if int(player.get("max_mp", 0)) <= 0 or int(player.get("mp", -1)) < 0 or \
			int(player.get("mp", 0)) > int(player.get("max_mp", 0)):
		return _fail("invariant_mp:%s" % phase, {"player": player})
	if int(player.get("spirit_stones", -1)) < 0 or int(player.get("pills", -1)) < 0 or \
			int(player.get("exp", -1)) < 0:
		return _fail("invariant_resources:%s" % phase, {"player": player})
	if int(world.get("year", 0)) < 1 or int(state.get("rng_cursor", -1)) < 0:
		return _fail("invariant_world:%s" % phase, {"world": world})
	if CombatSystemScript.has_active_combat(state) and DungeonSystemScript.has_active_run(state):
		return _fail("invariant_dual_encounter:%s" % phase, {})
	return {"ok": true, "code": "invariant_ok"}


func _choice_is_available(player: Dictionary, choice: Dictionary) -> bool:
	var deltas: Dictionary = choice.get("deltas", {})
	for resource_id in ["spirit_stones", "pills"]:
		if int(player.get(resource_id, 0)) + int(deltas.get(resource_id, 0)) < 0:
			return false
	return true


func _fail(code: String, detail: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "detail": detail}


func _record_failure(index: int, mode: int, result: Dictionary) -> void:
	var code := str(result.get("code", "unknown"))
	failure_counts[code] = int(failure_counts.get(code, 0)) + 1
	if failures.size() < 64:
		failures.append("run=%d mode=%d seed=%d code=%s detail=%s" % [
			index, mode, BASE_SEED + index * 7919, code, JSON.stringify(result.get("detail", {}))])


func _new_telemetry() -> Dictionary:
	return {
		"sessions": 0,
		"event_resolutions": {"catalog": 0, "story": 0},
		"choice_positions": {"0": 0, "1": 0, "2": 0},
		"event_choice_counts": {},
		"offered_choice_profiles": {"total": 0, "costless": 0, "player_cost": 0, "path_cost": 0},
		"selected_choice_profiles": {"total": 0, "costless": 0, "player_cost": 0, "path_cost": 0},
		"choice_availability_fallbacks": 0,
		"combat_outcomes": {},
		"combat_outcomes_by_root": {},
		"combat_turn_total": 0,
		"combat_hp_loss_basis_points_total": 0,
		"combat_near_deaths": 0,
		"combat_turn_total_by_root": {},
		"combat_hp_loss_basis_points_by_root": {},
		"dungeon_outcomes": {},
		"dungeon_outcomes_by_root": {},
		"objective_completions": {},
		"objective_misses": {},
		"encounters_offered": 0,
		"encounters_engaged": 0,
		"encounters_expired": 0,
		"root_cohort_sessions": {},
		"natural_deaths": 0,
		"reincarnations": 0,
		"ai_fallbacks": 0,
		"save_roundtrips": 0,
		"story_triggers": 0,
		"story_trigger_event_total": 0,
		"story_stage_total": 0,
		"final_year_total": 0,
		"final_resource_totals": {},
		"final_path_totals": {},
	}


func _record_offered_choices(event: Dictionary) -> void:
	for choice_variant in (event.get("choices", []) as Array):
		_record_choice_profile(telemetry.offered_choice_profiles, choice_variant as Dictionary)


func _record_selected_choice(event: Dictionary, choice_index: int, choice: Dictionary) -> void:
	var source_key := "story" if str(event.get("source", "")) == "story_arc" else "catalog"
	_increment(telemetry.event_resolutions, source_key)
	_increment(telemetry.choice_positions, str(choice_index))
	_increment(telemetry.event_choice_counts, "%s#%d" % [str(event.get("id", "unknown")), choice_index])
	_record_choice_profile(telemetry.selected_choice_profiles, choice)


func _record_choice_profile(counter: Dictionary, choice: Dictionary) -> void:
	_increment(counter, "total")
	var has_player_cost := false
	var player_deltas: Dictionary = choice.get("deltas", {})
	for field in player_deltas.keys():
		var value := int(player_deltas[field])
		if (str(field) == "enmity" and value > 0) or (str(field) != "enmity" and value < 0):
			has_player_cost = true
			break
	var has_path_cost := false
	for value in (choice.get("path_deltas", {}) as Dictionary).values():
		if int(value) < 0:
			has_path_cost = true
			break
	if has_player_cost:
		_increment(counter, "player_cost")
	if has_path_cost:
		_increment(counter, "path_cost")
	if not has_player_cost and not has_path_cost:
		_increment(counter, "costless")


func _record_session_telemetry(state: Dictionary) -> void:
	_increment(telemetry, "sessions")
	var player: Dictionary = state.get("player", {})
	for field in RESOURCE_FIELDS:
		telemetry.final_resource_totals[field] = \
			int(telemetry.final_resource_totals.get(field, 0)) + int(player.get(field, 0))
	var path: Dictionary = player.get("path", {})
	for field in PATH_FIELDS:
		telemetry.final_path_totals[field] = \
			int(telemetry.final_path_totals.get(field, 0)) + int(path.get(field, 0))
	telemetry["final_year_total"] = int(telemetry.final_year_total) + \
		int((state.get("world", {}) as Dictionary).get("year", 1))
	var story: Dictionary = state.get("story", {})
	for stage in (story.get("arc_progress", {}) as Dictionary).values():
		telemetry["story_stage_total"] = int(telemetry.story_stage_total) + int(stage)


func _record_combat_pressure(result: Dictionary, root_cohort: String) -> void:
	var battle: Dictionary = result.get("battle", {})
	var turns := maxi(1, int(battle.get("turn", 1)))
	var max_hp := maxi(1, int(battle.get("player_max_hp", 1)))
	var remaining_hp := clampi(int(battle.get("player_hp", 0)), 0, max_hp)
	var loss_basis_points := int(round(float(max_hp - remaining_hp) * 10000.0 / float(max_hp)))
	telemetry["combat_turn_total"] = int(telemetry.combat_turn_total) + turns
	telemetry["combat_hp_loss_basis_points_total"] = \
		int(telemetry.combat_hp_loss_basis_points_total) + loss_basis_points
	_increment(telemetry.combat_turn_total_by_root, root_cohort, turns)
	_increment(telemetry.combat_hp_loss_basis_points_by_root, root_cohort, loss_basis_points)
	if remaining_hp * 4 <= max_hp:
		_increment(telemetry, "combat_near_deaths")


func _increment(counter: Dictionary, key: String, amount: int = 1) -> void:
	counter[key] = int(counter.get(key, 0)) + amount


func _root_cohort(player: Dictionary) -> String:
	var total := 0
	for value in (player.get("roots", []) as Array):
		total += int(value)
	if total <= 15:
		return "low"
	if total >= 40:
		return "high"
	return "standard"
