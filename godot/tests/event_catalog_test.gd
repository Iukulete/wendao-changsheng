extends SceneTree

const EventCatalogScript = preload("res://scripts/event_catalog.gd")
const GameStateScript = preload("res://scripts/game_state.gd")

var failures: Array[String] = []


func _init() -> void:
	var validation: Dictionary = EventCatalogScript.validate_catalog()
	_expect(bool(validation.get("ok", false)) and
		int(validation.get("event_count", 0)) >=
			EventCatalogScript.ERAS.size() * EventCatalogScript.MIN_EVENTS_PER_ERA,
		"事件目录必须满足六时代最低内容配额")
	var era_counts_value: Variant = validation.get("era_counts", {})
	var era_counts: Dictionary = era_counts_value if era_counts_value is Dictionary else {}
	for era in EventCatalogScript.ERAS:
		_expect(int(era_counts.get(era, 0)) >= EventCatalogScript.MIN_EVENTS_PER_ERA,
			"每个时代必须至少提供六个自由历练事件：%s" % era)

	for era_index in range(EventCatalogScript.ERAS.size()):
		var era: String = EventCatalogScript.ERAS[era_index]
		var state := GameStateScript.create_new_game("录因人", 810000 + era_index, [7, 7, 7, 7, 7])
		for event_value in EventCatalogScript.load_events():
			var catalog_event: Dictionary = event_value
			if str(catalog_event.get("era", "")) == era:
				state.story.event_cooldowns[str(catalog_event.id)] = 1000 + era_index
		var twin := state.duplicate(true)
		var seen := {}
		var last_event_id := ""
		var era_event_count := int(era_counts.get(era, 0))
		for event_index in range(era_event_count + 1):
			var selected: Dictionary = EventCatalogScript.select_event(state, era)
			var twin_selected: Dictionary = EventCatalogScript.select_event(twin, era)
			_expect(selected == twin_selected and state.rng_cursor == twin.rng_cursor,
				"相同世界状态必须生成相同的时代事件序列：%s" % era)
			var event_id := str(selected.get("id", ""))
			_expect(not event_id.is_empty() and str(selected.get("source", "")) == "authored_event",
				"目录覆盖及下一次选择都必须返回可结算的创作事件：%s" % era)
			if event_index < era_event_count:
				_expect(not seen.has(event_id), "同一世必须先遍历时代事件再允许重复：%s" % era)
				seen[event_id] = true
			elif not last_event_id.is_empty():
				_expect(event_id != last_event_id, "冷却回退不得立即重复刚结算的事件：%s" % era)
			last_event_id = event_id
			state.player.total_events = int(state.player.total_events) + 1
			twin.player.total_events = int(twin.player.total_events) + 1
			var recorded: Dictionary = EventCatalogScript.record_resolution(state, selected)
			var twin_recorded: Dictionary = EventCatalogScript.record_resolution(twin, twin_selected)
			_expect(recorded == twin_recorded and bool(recorded.get("ok", false)),
				"事件结算记录必须稳定写回状态：%s" % era)
		_expect(seen.size() == era_event_count,
			"每个时代必须先覆盖全部事件再允许重复：%s" % era)
		_expect(int(state.rng_cursor) == era_event_count + 1 and state == twin,
			"事件随机游标和冷却状态必须保持确定性：%s" % era)
		var cooldowns: Dictionary = state.story.event_cooldowns
		_expect(cooldowns.size() == era_event_count,
			"创作事件冷却必须按事件ID持久化：%s" % era)
		var persisted_value: Variant = JSON.parse_string(JSON.stringify(state))
		var persisted: Dictionary = GameStateScript.ensure_v2(persisted_value as Dictionary)
		_expect(int(persisted.rng_cursor) == int(state.rng_cursor) and
			_numeric_dictionary_equal(persisted.story.event_cooldowns, state.story.event_cooldowns) and
			persisted.story.life_event_ids == state.story.life_event_ids,
			"存档往返后必须保留事件游标、冷却与本世事件记录：%s" % era)

	if failures.is_empty():
		print("EVENT_CATALOG_TEST_OK: six-era quotas, deterministic variety, cross-life cooldowns and persistence passed")
		quit(0)
	else:
		for failure in failures:
			push_error("EVENT_CATALOG_TEST_FAILED: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _numeric_dictionary_equal(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for key in right.keys():
		if not left.has(key) or int(left[key]) != int(right[key]):
			return false
	return true
