extends SceneTree

const ChronicleSystemScript = preload("res://scripts/chronicle_system.gd")
const GameStateScript = preload("res://scripts/game_state.gd")
const ReincarnationSystemScript = preload("res://scripts/reincarnation_system.gd")
const StorySystemScript = preload("res://scripts/story_system.gd")

var failures: Array[String] = []


func _init() -> void:
	var validation := ChronicleSystemScript.validate_all()
	_expect(bool(validation.get("ok", false)) and int(validation.get("volume_count", 0)) == 6,
		"六个纪元必须各有一部可加载的今世长卷")
	if not bool(validation.get("ok", false)):
		push_error("CHRONICLE_SYSTEM_TEST_FAILED: %s" % JSON.stringify(validation))
		quit(1)
		return

	var state := GameStateScript.create_new_game("长卷行者", 20260726, [8, 8, 8, 8, 8])
	state.player.spirit_stones = 100000
	state.player.pills = 100000
	var completed_names: Array[String] = []
	var prior_life_route := ""
	for era_index in range(ChronicleSystemScript.ERA_IDS.size()):
		var era_id: String = str(ChronicleSystemScript.ERA_IDS[era_index])
		state.current_era_id = era_id
		state.current_era = str(GameStateScript.ERA_NAMES.get(era_id, era_id))
		state.generation = era_index + 1
		var volume := ChronicleSystemScript.load_volume(era_id)
		var expected_chapters := (volume.get("chapters", []) as Array).size()
		var first_event := ChronicleSystemScript.next_event(state)
		_expect(str(first_event.get("source", "")) == "life_chronicle" and
			int(first_event.get("chapter_number", 0)) == 1 and
			(first_event.get("choices", []) as Array).size() == 3,
			"%s 必须从第一章开始并提供三个行动" % era_id)
		if era_index > 0:
			var inherited_value: Variant = (volume.get("inheritance_variants", {}) as Dictionary).get(
				prior_life_route, "")
			var inherited_text := str((inherited_value as Dictionary).get("description", "")) if \
				inherited_value is Dictionary else str(inherited_value)
			_expect(str(first_event.get("previous_life_route_id", "")) == prior_life_route and
				str(first_event.get("description", "")).begins_with(inherited_text),
				"%s 首章必须用作者手写段落承接上一世真实结局" % era_id)
		if first_event.is_empty():
			continue
		var stale_copy := first_event.duplicate(true)
		var event := first_event
		var previous_route := ""
		for chapter_index in range(expected_chapters):
			if chapter_index > 0:
				event = ChronicleSystemScript.next_event(state)
			_expect(not event.is_empty() and int(event.get("chapter_number", 0)) == chapter_index + 1,
				"%s 第%d章必须按图可达" % [era_id, chapter_index + 1])
			if event.is_empty():
				break
			if chapter_index > 0:
				var chapter: Dictionary = (volume.get("chapters", []) as Array)[chapter_index]
				var variant_value: Variant = (chapter.get("route_variants", {}) as Dictionary).get(
					previous_route, "")
				var variant_text := str((variant_value as Dictionary).get("description", "")) if \
					variant_value is Dictionary else str(variant_value)
				_expect(str(event.get("previous_route_id", "")) == previous_route and
					str(event.get("description", "")).begins_with(variant_text),
					"%s 第%d章必须先承接上一选择造成的变化，再进入本章现场" % [era_id,
						chapter_index + 1])
			var choice_index := _available_choice_index(event, chapter_index % 3)
			var choice: Dictionary = (event.get("choices", []) as Array)[choice_index]
			_expect(bool(choice.get("available", false)),
				"%s 第%d章的测试路线必须可选" % [era_id, chapter_index + 1])
			var result := ChronicleSystemScript.resolve_choice(state, event, choice_index)
			_expect(bool(result.get("ok", false)),
				"%s 第%d章必须成功结算：%s" % [era_id, chapter_index + 1,
					str(result.get("code", "unknown"))])
			state.player.total_events = int(state.player.total_events) + 1
			previous_route = str(choice.get("route_id", ""))
			StorySystemScript.record_chapter(state, event, choice, str(choice.get("outcome", "")),
				str(result.get("message", "")))
		_expect(bool((state.story.life_chronicle as Dictionary).get("completed", false)) and
			ChronicleSystemScript.next_event(state).is_empty(),
			"%s 完卷后不得重复刷出同一章" % era_id)
		_expect(str((state.story.life_chronicle as Dictionary).get("resolution", "")).length() >= 30,
			"%s 必须按累计路线写入明确结局" % era_id)
		prior_life_route = str((state.story.life_chronicle as Dictionary).get("last_route_id", ""))
		completed_names.append(str(volume.get("name", era_id)))
		if era_index == 0:
			var closed_state := state.duplicate(true)
			var closed := ReincarnationSystemScript.close_life(closed_state, "长卷测试", 50)
			var past_lives: Array = (closed_state.legacy as Dictionary).get("past_lives", [])
			var past_life: Dictionary = past_lives[-1] if not past_lives.is_empty() else {}
			var inherited_chronicle_echo := false
			for echo_value in (past_life.get("echoes", []) as Array):
				if str((echo_value as Dictionary).get("id", "")).begins_with("chronicle_"):
					inherited_chronicle_echo = true
					break
			_expect(bool(closed.get("ok", false)) and
				bool((past_life.get("chronicle", {}) as Dictionary).get("completed", false)) and
				inherited_chronicle_echo,
				"完卷定局必须写入前世档案并成为下一世可继承的余响")
		var stale_result := ChronicleSystemScript.resolve_choice(state, stale_copy, 0)
		_expect(str(stale_result.get("code", "")) == "stale_chronicle_event",
			"%s 必须拒绝旧章节重复结算" % era_id)

	_expect(completed_names.size() == 6 and
		(state.story.chronicle_history as Array).size() == 6,
		"六世完卷记录必须跨纪元保留")
	_expect((state.story.route_history as Dictionary).size() >= 6 and
		int(state.story.choice_count) >= 144,
		"长卷选择必须进入统一路线与因果账本")
	_expect((state.story.chapter_log as Array).size() == StorySystemScript.MAX_CHAPTER_LOG,
		"长篇章节日志必须沿用有界存档，不能无限膨胀")
	state.generation = 7
	state.current_era_id = "classical"
	state.current_era = str(GameStateScript.ERA_NAMES.classical)
	var cycle_volume := ChronicleSystemScript.load_volume("classical")
	var cycle_inheritance: Dictionary = (cycle_volume.get("inheritance_variants", {}) as Dictionary).get(
		prior_life_route, {})
	var cycle_event := ChronicleSystemScript.next_event(state)
	_expect(str(cycle_event.get("previous_life_route_id", "")) == prior_life_route and
		str(cycle_event.get("description", "")).begins_with(
			str(cycle_inheritance.get("description", ""))),
		"第七世回到古典纪元时仍必须承接第六世仙朝结局")

	var reset_state := GameStateScript.create_new_game("换世校验", 20260727, [7, 7, 7, 7, 7])
	var old_event := ChronicleSystemScript.next_event(reset_state)
	ChronicleSystemScript.resolve_choice(reset_state, old_event, 0)
	reset_state.generation = 2
	reset_state.current_era_id = "steam"
	reset_state.current_era = str(GameStateScript.ERA_NAMES.steam)
	var reset_event := ChronicleSystemScript.next_event(reset_state)
	var steam_volume := ChronicleSystemScript.load_volume("steam")
	_expect(int(reset_event.get("chapter_number", 0)) == 1 and
		str(reset_event.get("chronicle_volume_id", "")) == str(steam_volume.get("id", "")) and
		int((reset_state.story.life_chronicle as Dictionary).get("generation", 0)) == 2,
		"新一世必须自动切换纪元长卷并从第一章开始")

	if failures.is_empty():
		print("CHRONICLE_SYSTEM_TEST_OK: six volumes, 144+ choices, route consequences, stale protection and reincarnation reset passed")
		quit(0)
	else:
		for failure in failures:
			push_error("CHRONICLE_SYSTEM_TEST_FAILED: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _available_choice_index(event: Dictionary, preferred: int) -> int:
	var choices: Array = event.get("choices", [])
	if preferred >= 0 and preferred < choices.size() and \
			bool((choices[preferred] as Dictionary).get("available", false)):
		return preferred
	for index in range(choices.size()):
		if bool((choices[index] as Dictionary).get("available", false)):
			return index
	return 0
