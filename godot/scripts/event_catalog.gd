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
		era_counts[era] = int(era_counts[era]) + 1
	for era in ERAS:
		if int(era_counts[era]) < MIN_EVENTS_PER_ERA:
			return {"ok": false, "code": "insufficient_era_events", "era": era,
				"event_count": int(era_counts[era]), "minimum": MIN_EVENTS_PER_ERA}
	_validation_cache = {
		"ok": true,
		"code": "valid",
		"event_count": seen.size(),
		"era_counts": era_counts,
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
	var selected: Dictionary = (pool[_roll(state, 0, pool.size() - 1)] as Dictionary).duplicate(true)
	selected["source"] = "authored_event"
	return selected


static func record_resolution(state: Dictionary, event: Dictionary) -> Dictionary:
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
	state["story"] = story
	return {"ok": true, "code": "event_recorded", "event_id": event_id}


static func _roll(state: Dictionary, minimum: int, maximum: int) -> int:
	var cursor := int(state.get("rng_cursor", 0))
	var seed_value := (int(state.get("world_seed", 1)) + cursor * 214013 + 0x2f6e2b1) & 0x7fffffff
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	state["rng_cursor"] = cursor + 1
	return rng.randi_range(minimum, maximum)


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
