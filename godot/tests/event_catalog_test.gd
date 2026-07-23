extends SceneTree

const EventCatalogScript = preload("res://scripts/event_catalog.gd")
const GameStateScript = preload("res://scripts/game_state.gd")
const StorySystemScript = preload("res://scripts/story_system.gd")
const EncounterSystemScript = preload("res://scripts/encounter_system.gd")

var failures: Array[String] = []


func _init() -> void:
	var validation: Dictionary = EventCatalogScript.validate_catalog()
	_expect(bool(validation.get("ok", false)) and
		int(validation.get("event_count", 0)) >=
			EventCatalogScript.ERAS.size() * EventCatalogScript.MIN_EVENTS_PER_ERA,
		"事件目录必须满足六时代最低内容配额")
	_expect(int(validation.get("thread_count", 0)) == 12,
		"三十六个自由历练事件必须编排为十二条三章外篇")
	var era_counts_value: Variant = validation.get("era_counts", {})
	var era_counts: Dictionary = era_counts_value if era_counts_value is Dictionary else {}
	for era in EventCatalogScript.ERAS:
		_expect(int(era_counts.get(era, 0)) >= EventCatalogScript.MIN_EVENTS_PER_ERA,
			"每个时代必须至少提供六个自由历练事件：%s" % era)
	_test_combat_content_density()

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
		var opening_thread_id := ""
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
				_expect(not str(selected.get("side_thread_id", "")).is_empty(),
					"每个时代事件必须属于可追踪的三章外篇：%s" % era)
				if event_index == 0:
					opening_thread_id = str(selected.get("side_thread_id", ""))
				if event_index < EventCatalogScript.SIDE_THREAD_LENGTH:
					_expect(str(selected.get("side_thread_id", "")) == opening_thread_id and
						int(selected.get("side_thread_stage", -1)) == event_index and
						int(selected.get("chapter_number", 0)) == event_index + 1 and
						int(selected.get("chapter_total", 0)) == EventCatalogScript.SIDE_THREAD_LENGTH,
						"选定一条外篇后必须连续读完三章，不能重新随机跳事：%s" % era)
				if event_index > 0:
					_expect(not str(selected.get("previous_choice_recap", "")).is_empty(),
						"下一章必须自然回顾上一章行动与结果：%s" % era)
			elif not last_event_id.is_empty():
				_expect(event_id != last_event_id, "冷却回退不得立即重复刚结算的事件：%s" % era)
			last_event_id = event_id
			state.player.total_events = int(state.player.total_events) + 1
			twin.player.total_events = int(twin.player.total_events) + 1
			var selected_choice: Dictionary = (selected.get("choices", []) as Array)[event_index % 3]
			var twin_choice: Dictionary = (twin_selected.get("choices", []) as Array)[event_index % 3]
			var recorded: Dictionary = EventCatalogScript.record_resolution(state, selected, selected_choice)
			var twin_recorded: Dictionary = EventCatalogScript.record_resolution(twin, twin_selected, twin_choice)
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
		StorySystemScript.normalize(persisted)
		_expect(int(persisted.rng_cursor) == int(state.rng_cursor) and
			_numeric_dictionary_equal(persisted.story.event_cooldowns, state.story.event_cooldowns) and
			persisted.story.life_event_ids == state.story.life_event_ids and
			persisted.story.side_thread_progress == state.story.side_thread_progress and
			persisted.story.last_authored_context == state.story.last_authored_context,
			"存档往返后必须保留事件游标、冷却、外篇进度与上一章结果：%s" % era)

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


func _test_combat_content_density() -> void:
	var tier_sets := {}
	var enemy_ids := {}
	for era in EventCatalogScript.ERAS:
		tier_sets[era] = {}
	for event_value in EventCatalogScript.load_events():
		var event: Dictionary = event_value
		for choice_value in (event.get("choices", []) as Array):
			var choice: Dictionary = choice_value
			if not bool(choice.get("combat_trigger", false)):
				continue
			var encounter: Dictionary = choice.get("encounter", {})
			var enemy_id := str(encounter.get("enemy_id", ""))
			var tier := str(encounter.get("encounter_tier", ""))
			enemy_ids[enemy_id] = true
			(tier_sets[str(event.get("era", ""))] as Dictionary)[tier] = true
			_expect(not str(choice.get("id", "")).is_empty() and not enemy_id.is_empty() and
				tier in ["normal", "elite", "boss"],
				"战斗选择必须有稳定选择ID、敌人ID与层级：%s" % str(event.get("id", "")))
			for field in ["motivation", "stakes", "victory_consequence", "defeat_consequence",
				"escape_consequence"]:
				_expect(not str(encounter.get(field, "")).is_empty(),
					"剧情敌踪缺少%s：%s" % [field, enemy_id])
			if tier != "normal":
				_expect(not str(encounter.get("ally_support_id", "")).is_empty() and
					not str(encounter.get("support_effect", "")).is_empty(),
					"精英与首领战必须落实一名选择触发的盟友支援：%s" % enemy_id)
			if tier == "boss":
				_expect(not str(encounter.get("rematch_key", "")).is_empty() and
					choice.get("combat_outcomes", {}) is Dictionary,
					"首领必须有复战键与胜败余波：%s" % enemy_id)
			var state := GameStateScript.create_new_game("敌踪审计", enemy_id.hash(), [7, 7, 7, 7, 7])
			var offered := EncounterSystemScript.offer_from_choice(state, event, choice)
			var summary: Dictionary = EncounterSystemScript.summary(state)
			_expect(bool(offered.get("ok", false)) and
				str(summary.get("visual_profile_id", "")).begins_with("enemy.") and
				str(summary.get("weapon_profile_id", "")).begins_with("weapon.") and
				str(summary.get("vfx_profile_id", "")).begins_with("vfx."),
				"正式敌人必须在敌踪阶段解析三组视觉契约：%s" % enemy_id)
	_expect(enemy_ids.size() == 18, "六纪元必须提供18个稳定敌人身份")
	for era in EventCatalogScript.ERAS:
		var tiers: Dictionary = tier_sets[era]
		_expect(tiers.has("normal") and tiers.has("elite") and tiers.has("boss"),
			"每个纪元必须同时有普通敌、精英与剧情首领：%s" % era)


func _numeric_dictionary_equal(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for key in right.keys():
		if not left.has(key) or int(left[key]) != int(right[key]):
			return false
	return true
