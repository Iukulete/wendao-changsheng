class_name EventCatalog
extends RefCounted

const CharacterArtCatalogScript = preload("res://scripts/character_art_catalog.gd")
const DATA_PATH := "res://data/events_v014.json"
const ERAS := [
	"古典修仙纪", "灵机蒸汽纪", "星穹道网纪",
	"废土返道纪", "末法裂变纪", "仙朝鼎盛纪",
]
const PATH_IDS := ["compassion", "ambition", "defiance", "insight", "creation", "bonds"]
const PLAYER_DELTA_IDS := [
	"exp", "hp", "mp", "karma", "dao_heart", "reputation", "enmity",
	"spirit_stones", "pills",
]
const MIN_EVENTS_PER_ERA := 6
const AUTHORED_EVENT_COOLDOWN := 4
const SIDE_THREAD_LENGTH := 3
const SIDE_THREADS := [
	{"id": "classical_memory_register", "name": "镜湖旧梦册", "era": "古典修仙纪",
		"events": ["classical_void_threshold", "classical_mirror_census", "classical_lantern_bazaar"]},
	{"id": "classical_oath_wound", "name": "山门旧诺", "era": "古典修仙纪",
		"events": ["classical_mountain_oath", "classical_borrowed_wound_elixir", "classical_sword_letter"]},
	{"id": "steam_rail_night", "name": "灵轨长夜", "era": "灵机蒸汽纪",
		"events": ["steam_spirit_rail", "steam_twelve_hour_strike", "steam_forge_strike"]},
	{"id": "steam_awakened_forge", "name": "百炉醒火", "era": "灵机蒸汽纪",
		"events": ["steam_bazaar_black_box", "steam_awakening_furnace", "steam_resonance_patent"]},
	{"id": "star_persona_claim", "name": "谁拥有旧我", "era": "星穹道网纪",
		"events": ["star_cloud_echo", "star_unindexed_persona", "star_identity_fork"]},
	{"id": "star_sword_authority", "name": "剑阵署名权", "era": "星穹道网纪",
		"events": ["star_orbital_sword_array", "star_memory_ownership_trial", "star_rival_handshake"]},
	{"id": "wasteland_rain_archive", "name": "黑雨迁徙录", "era": "废土返道纪",
		"events": ["wasteland_black_rain", "wasteland_black_rain_archive", "wasteland_mobile_sect_rooms"]},
	{"id": "wasteland_fireseed_watch", "name": "火种夜讯", "era": "废土返道纪",
		"events": ["wasteland_seed_vault", "wasteland_fireseed_well", "wasteland_oath_radio"]},
	{"id": "final_age_breath_queue", "name": "最后一口灵息", "era": "末法裂变纪",
		"events": ["final_age_spirit_ration", "final_age_nursery_lottery", "final_last_teacher"]},
	{"id": "final_age_body_contract", "name": "经脉契书", "era": "末法裂变纪",
		"events": ["final_age_lifespan_bazaar", "final_age_meridian_mortgage", "final_contract_audit"]},
	{"id": "imperial_merit_ledger", "name": "仙城功德账", "era": "仙朝鼎盛纪",
		"events": ["imperial_falling_skycourt", "imperial_merit_rain", "imperial_ascension_registry"]},
	{"id": "imperial_blank_fate", "name": "空白命印", "era": "仙朝鼎盛纪",
		"events": ["imperial_void_registry", "imperial_fate_blank", "imperial_siming_order"]},
]

static var _events_cache: Array = []
static var _validation_cache: Dictionary = {}


static func load_events() -> Array:
	if not _events_cache.is_empty():
		return _events_cache
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Array:
		_events_cache = (parsed as Array).duplicate(true)
	return _events_cache


static func validate_catalog() -> Dictionary:
	if not _validation_cache.is_empty():
		return _validation_cache.duplicate(true)
	var character_art_validation: Dictionary = CharacterArtCatalogScript.validate_catalog()
	if not bool(character_art_validation.get("ok", false)):
		return {"ok": false, "code": "invalid_character_art_catalog",
			"detail": str(character_art_validation.get("code", "unknown"))}
	var events := load_events()
	if events.is_empty():
		return {"ok": false, "code": "empty_event_catalog"}
	var seen := {}
	var era_counts := {}
	var event_eras := {}
	for era in ERAS:
		era_counts[era] = 0
	for event_value in events:
		if not event_value is Dictionary:
			return {"ok": false, "code": "invalid_event"}
		var event: Dictionary = event_value
		var event_id := str(event.get("id", ""))
		var era := str(event.get("era", ""))
		if event_id.is_empty() or seen.has(event_id):
			return {"ok": false, "code": "invalid_event_id", "event_id": event_id}
		if not ERAS.has(era):
			return {"ok": false, "code": "invalid_event_era", "event_id": event_id}
		for text_field in ["title", "description", "portrait_name", "portrait_title"]:
			if str(event.get(text_field, "")).strip_edges().is_empty():
				return {"ok": false, "code": "missing_event_text", "event_id": event_id}
		for resource_field in ["scene", "portrait"]:
			var resource_path := str(event.get(resource_field, ""))
			if not resource_path.begins_with("res://") or not ResourceLoader.exists(resource_path):
				return {"ok": false, "code": "missing_event_resource", "event_id": event_id,
					"resource": resource_path}
		var character_id := str(event.get("character_id", ""))
		var motion_profile := str(event.get("motion_profile", ""))
		if not CharacterArtCatalogScript.has_character(character_id):
			return {"ok": false, "code": "invalid_event_character", "event_id": event_id,
				"character_id": character_id}
		if motion_profile.is_empty() or not CharacterArtCatalogScript.has_motion_profile(motion_profile):
			return {"ok": false, "code": "invalid_event_motion_profile", "event_id": event_id}
		var choices_value: Variant = event.get("choices", [])
		if not choices_value is Array or (choices_value as Array).size() != 3:
			return {"ok": false, "code": "invalid_event_choices", "event_id": event_id}
		for choice_value in (choices_value as Array):
			if not choice_value is Dictionary:
				return {"ok": false, "code": "invalid_event_choice", "event_id": event_id}
			var choice: Dictionary = choice_value
			if str(choice.get("text", "")).strip_edges().is_empty() or \
					str(choice.get("outcome", "")).strip_edges().is_empty():
				return {"ok": false, "code": "missing_choice_text", "event_id": event_id}
			var deltas_value: Variant = choice.get("deltas", {})
			var paths_value: Variant = choice.get("path_deltas", {})
			if not deltas_value is Dictionary or not paths_value is Dictionary or \
					(paths_value as Dictionary).is_empty():
				return {"ok": false, "code": "invalid_choice_deltas", "event_id": event_id}
			for delta_id in (deltas_value as Dictionary).keys():
				if not PLAYER_DELTA_IDS.has(str(delta_id)) or not _is_number(deltas_value[delta_id]):
					return {"ok": false, "code": "invalid_player_delta", "event_id": event_id}
			for path_id in (paths_value as Dictionary).keys():
				if not PATH_IDS.has(str(path_id)) or not _is_number(paths_value[path_id]) or \
						int(paths_value[path_id]) == 0:
					return {"ok": false, "code": "invalid_path_delta", "event_id": event_id}
		seen[event_id] = true
		event_eras[event_id] = era
		era_counts[era] = int(era_counts[era]) + 1
	for era in ERAS:
		if int(era_counts[era]) < MIN_EVENTS_PER_ERA:
			return {"ok": false, "code": "insufficient_era_events", "era": era,
				"event_count": int(era_counts[era]), "minimum": MIN_EVENTS_PER_ERA}
	var seen_threads := {}
	var threaded_events := {}
	for thread_value in SIDE_THREADS:
		var thread: Dictionary = thread_value
		var thread_id := str(thread.get("id", ""))
		var thread_name := str(thread.get("name", ""))
		var thread_era := str(thread.get("era", ""))
		var thread_events: Array = thread.get("events", [])
		if thread_id.is_empty() or thread_name.is_empty() or seen_threads.has(thread_id) or \
				not ERAS.has(thread_era) or thread_events.size() != SIDE_THREAD_LENGTH:
			return {"ok": false, "code": "invalid_side_thread", "thread_id": thread_id}
		for event_id_value in thread_events:
			var event_id := str(event_id_value)
			if not seen.has(event_id) or threaded_events.has(event_id) or \
					str(event_eras.get(event_id, "")) != thread_era:
				return {"ok": false, "code": "invalid_side_thread_event",
					"thread_id": thread_id, "event_id": event_id}
			threaded_events[event_id] = thread_id
		seen_threads[thread_id] = true
	if threaded_events.size() != seen.size():
		return {"ok": false, "code": "unthreaded_authored_event",
			"threaded": threaded_events.size(), "events": seen.size()}
	_validation_cache = {
		"ok": true,
		"code": "valid",
		"event_count": seen.size(),
		"era_counts": era_counts,
		"thread_count": seen_threads.size(),
	}
	return _validation_cache.duplicate(true)


static func select_event(state: Dictionary, era: String) -> Dictionary:
	if not bool(validate_catalog().get("ok", false)):
		return {}
	var candidates: Array = []
	for event_value in load_events():
		var event: Dictionary = event_value
		if str(event.get("era", "")) == era:
			candidates.append(event)
	if candidates.is_empty():
		candidates = load_events().duplicate()
	if candidates.is_empty():
		return {}

	var story_value: Variant = state.get("story", {})
	var story: Dictionary = story_value if story_value is Dictionary else {}
	var life_events_value: Variant = story.get("life_event_ids", [])
	var life_events: Array = life_events_value if life_events_value is Array else []
	var cooldowns_value: Variant = story.get("event_cooldowns", {})
	var cooldowns: Dictionary = cooldowns_value if cooldowns_value is Dictionary else {}
	var total_events := int((state.get("player", {}) as Dictionary).get("total_events", 0))
	var fresh: Array = []
	var cooled_down: Array = []
	var earliest_unlock := 0x7fffffff
	var earliest_pool: Array = []
	for event_value in candidates:
		var event: Dictionary = event_value
		var event_id := str(event.id)
		var unlock_at := int(cooldowns.get(event_id, 0))
		if not life_events.has(event_id):
			fresh.append(event)
		elif unlock_at <= total_events:
			cooled_down.append(event)
		elif unlock_at < earliest_unlock:
			earliest_unlock = unlock_at
			earliest_pool = [event]
		elif unlock_at == earliest_unlock:
			earliest_pool.append(event)
	var pool := fresh if not fresh.is_empty() else cooled_down
	if pool.is_empty():
		pool = earliest_pool if not earliest_pool.is_empty() else candidates
	var roll_index := _roll(state, 0, pool.size() - 1)
	var selected := _select_thread_event(story, era, pool, roll_index)
	if selected.is_empty():
		selected = (pool[roll_index] as Dictionary).duplicate(true)
	selected["source"] = "authored_event"
	_decorate_side_chapter(state, story, selected)
	return selected


static func record_resolution(state: Dictionary, event: Dictionary,
		choice: Dictionary = {}) -> Dictionary:
	var event_id := str(event.get("id", ""))
	if event_id.is_empty():
		return {"ok": false, "code": "missing_event_id"}
	var story_value: Variant = state.get("story", {})
	var story: Dictionary = story_value if story_value is Dictionary else {}
	var completed_value: Variant = story.get("completed_event_ids", [])
	var completed: Array = completed_value if completed_value is Array else []
	if not completed.has(event_id):
		completed.append(event_id)
	while completed.size() > 2048:
		completed.pop_front()
	story["completed_event_ids"] = completed
	var life_value: Variant = story.get("life_event_ids", [])
	var life_events: Array = life_value if life_value is Array else []
	life_events.append(event_id)
	while life_events.size() > 512:
		life_events.pop_front()
	story["life_event_ids"] = life_events
	if str(event.get("source", "")) == "authored_event":
		var cooldown_value: Variant = story.get("event_cooldowns", {})
		var cooldowns: Dictionary = cooldown_value if cooldown_value is Dictionary else {}
		var total_events := int((state.get("player", {}) as Dictionary).get("total_events", 0))
		cooldowns[event_id] = total_events + AUTHORED_EVENT_COOLDOWN
		story["event_cooldowns"] = cooldowns
		_record_side_resolution(state, story, event, choice)
	state["story"] = story
	return {"ok": true, "code": "event_recorded", "event_id": event_id,
		"side_thread_id": str(event.get("side_thread_id", "")),
		"side_thread_stage": int(event.get("side_thread_stage", -1))}


static func _select_thread_event(story: Dictionary, era: String, pool: Array,
		roll_index: int) -> Dictionary:
	var progress_value: Variant = story.get("side_thread_progress", {})
	var progress: Dictionary = progress_value if progress_value is Dictionary else {}
	var active_value: Variant = story.get("side_active_threads", {})
	var active: Dictionary = active_value if active_value is Dictionary else {}
	var eligible: Array[Dictionary] = []
	var active_thread_id := str(active.get(era, ""))
	if not active_thread_id.is_empty():
		var active_thread := _thread_by_id(active_thread_id)
		var active_candidate := _next_thread_candidate(active_thread, progress, pool)
		if not active_candidate.is_empty():
			return active_candidate
	for thread_value in SIDE_THREADS:
		var thread: Dictionary = thread_value
		if str(thread.get("era", "")) != era:
			continue
		var candidate := _next_thread_candidate(thread, progress, pool)
		if not candidate.is_empty():
			eligible.append(candidate)
	if eligible.is_empty():
		return {}
	return eligible[posmod(roll_index, eligible.size())].duplicate(true)


static func _next_thread_candidate(thread: Dictionary, progress: Dictionary,
		pool: Array) -> Dictionary:
	if thread.is_empty():
		return {}
	var thread_id := str(thread.get("id", ""))
	var event_ids: Array = thread.get("events", [])
	var stage := clampi(int(progress.get(thread_id, 0)), 0, event_ids.size())
	if stage >= event_ids.size():
		return {}
	var event_id := str(event_ids[stage])
	for event_value in pool:
		var event: Dictionary = event_value
		if str(event.get("id", "")) == event_id:
			return event.duplicate(true)
	return {}


static func _decorate_side_chapter(state: Dictionary, story: Dictionary,
		event: Dictionary) -> void:
	var thread := _thread_for_event(str(event.get("id", "")))
	var side_chapter := maxi(1, int(story.get("side_chapter_count", 0)) + 1)
	event["generation"] = int(state.get("generation", 1))
	event["world_year"] = int((state.get("world", {}) as Dictionary).get("year", 1))
	event["story_phase"] = "side"
	event["chapter_phase_name"] = "山河外篇"
	if not thread.is_empty():
		var thread_id := str(thread.get("id", ""))
		var event_ids: Array = thread.get("events", [])
		var stage := event_ids.find(str(event.get("id", "")))
		var progress_value: Variant = story.get("side_thread_progress", {})
		var progress: Dictionary = progress_value if progress_value is Dictionary else {}
		var first_pass := int(progress.get(thread_id, 0)) <= stage
		event["side_thread_id"] = thread_id
		event["side_thread_stage"] = stage
		event["side_thread_total"] = event_ids.size()
		event["story_arc_name"] = str(thread.get("name", "山河外篇")) + ("" if first_pass else "·余波")
		event["chapter_number"] = stage + 1 if first_pass else side_chapter
		event["chapter_total"] = event_ids.size() if first_pass else 0
	else:
		event["story_arc_name"] = "山河余篇"
		event["chapter_number"] = side_chapter
		event["chapter_total"] = 0
	var recap := _side_recap(story, int(state.get("generation", 1)))
	if not recap.is_empty():
		event["previous_choice_recap"] = recap


static func _record_side_resolution(state: Dictionary, story: Dictionary,
		event: Dictionary, choice: Dictionary) -> void:
	story["side_chapter_count"] = clampi(int(story.get("side_chapter_count", 0)) + 1,
		0, 1000000)
	var thread := _thread_for_event(str(event.get("id", "")))
	var thread_id := str(thread.get("id", ""))
	if not thread.is_empty():
		var event_ids: Array = thread.get("events", [])
		var stage := event_ids.find(str(event.get("id", "")))
		var progress_value: Variant = story.get("side_thread_progress", {})
		var progress: Dictionary = progress_value if progress_value is Dictionary else {}
		var current_stage := clampi(int(progress.get(thread_id, 0)), 0, event_ids.size())
		if stage == current_stage:
			current_stage = mini(event_ids.size(), current_stage + 1)
			progress[thread_id] = current_stage
		story["side_thread_progress"] = progress
		var active_value: Variant = story.get("side_active_threads", {})
		var active: Dictionary = active_value if active_value is Dictionary else {}
		active[str(thread.get("era", ""))] = thread_id if current_stage < event_ids.size() else ""
		story["side_active_threads"] = active
		_update_side_thread(story, thread, current_stage)
		_record_side_route(story, thread_id, choice)
	story["last_authored_context"] = {
		"event_id": str(event.get("id", "")).left(96),
		"title": str(event.get("title", "山河异闻")).left(96),
		"choice": str(choice.get("text", "")).left(120),
		"outcome": str(choice.get("outcome", "")).left(280),
		"thread_id": thread_id.left(64),
		"thread_name": str(thread.get("name", "山河外篇")).left(64),
		"generation": int(state.get("generation", 1)),
		"turn": int(state.get("turn", 0)),
	}


static func _record_side_route(story: Dictionary, thread_id: String,
		choice: Dictionary) -> void:
	if thread_id.is_empty() or choice.is_empty():
		return
	var path_deltas_value: Variant = choice.get("path_deltas", {})
	if not path_deltas_value is Dictionary:
		return
	var best_path := ""
	var best_value := 0
	for path_id in PATH_IDS:
		var value := int((path_deltas_value as Dictionary).get(path_id, 0))
		if value > best_value:
			best_path = path_id
			best_value = value
	if best_path.is_empty():
		return
	var score_maps_value: Variant = story.get("side_route_scores", {})
	var score_maps: Dictionary = score_maps_value if score_maps_value is Dictionary else {}
	var scores_value: Variant = score_maps.get(thread_id, {})
	var scores: Dictionary = scores_value if scores_value is Dictionary else {}
	scores[best_path] = clampi(int(scores.get(best_path, 0)) + best_value, 0, 100000)
	score_maps[thread_id] = scores
	story["side_route_scores"] = score_maps


static func _update_side_thread(story: Dictionary, thread: Dictionary,
		progress: int) -> void:
	var thread_id := str(thread.get("id", ""))
	var prefix := "side:%s:" % thread_id
	var threads_value: Variant = story.get("unresolved_threads", [])
	var threads: Array = threads_value if threads_value is Array else []
	for index in range(threads.size() - 1, -1, -1):
		if str(threads[index]).begins_with(prefix):
			threads.remove_at(index)
	var total := (thread.get("events", []) as Array).size()
	if progress < total:
		threads.append("%s《%s》推进至第%d/%d章，余波尚未落定。" % [prefix,
			str(thread.get("name", "山河外篇")), progress, total])
	while threads.size() > 128:
		threads.pop_front()
	story["unresolved_threads"] = threads


static func _side_recap(story: Dictionary, generation: int) -> String:
	var context_value: Variant = story.get("last_authored_context", {})
	if not context_value is Dictionary or (context_value as Dictionary).is_empty():
		return ""
	var context: Dictionary = context_value
	var title := str(context.get("title", "前一桩旧事"))
	var choice := str(context.get("choice", ""))
	var outcome := str(context.get("outcome", ""))
	var lead := "前世" if int(context.get("generation", generation)) < generation else "上一章"
	if choice.is_empty():
		return "%s《%s》的余波仍在。" % [lead, title]
	return "%s《%s》里，你曾“%s”。%s" % [lead, title, choice, outcome]


static func _thread_for_event(event_id: String) -> Dictionary:
	for thread_value in SIDE_THREADS:
		var thread: Dictionary = thread_value
		if (thread.get("events", []) as Array).has(event_id):
			return thread
	return {}


static func _thread_by_id(thread_id: String) -> Dictionary:
	for thread_value in SIDE_THREADS:
		var thread: Dictionary = thread_value
		if str(thread.get("id", "")) == thread_id:
			return thread
	return {}


static func _roll(state: Dictionary, minimum: int, maximum: int) -> int:
	var cursor := int(state.get("rng_cursor", 0))
	var seed_value := (int(state.get("world_seed", 1)) + cursor * 214013 + 0x2f6e2b1) & 0x7fffffff
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	state["rng_cursor"] = cursor + 1
	return rng.randi_range(minimum, maximum)


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
