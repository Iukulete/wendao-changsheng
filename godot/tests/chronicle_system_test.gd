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
	_verify_terminal_choice_resolution()
	_verify_outcome_variants()
	_verify_route_switch_matrix()

	if failures.is_empty():
		print("CHRONICLE_SYSTEM_TEST_OK: six volumes, 144+ choices, 1242 route-switch transitions, authored outcome variants, terminal-choice endings, stale protection and reincarnation reset passed")
		quit(0)
	else:
		for failure in failures:
			push_error("CHRONICLE_SYSTEM_TEST_FAILED: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _verify_terminal_choice_resolution() -> void:
	var terminal_state := GameStateScript.create_new_game(
		"终章校验", 20260820, [8, 8, 8, 8, 8])
	terminal_state.current_era_id = "classical"
	terminal_state.current_era = str(GameStateScript.ERA_NAMES.classical)
	terminal_state.player.spirit_stones = 100000
	terminal_state.player.pills = 100000
	var volume := ChronicleSystemScript.load_volume("classical")
	var chapter_count := (volume.get("chapters", []) as Array).size()
	var terminal_result: Dictionary = {}
	var terminal_route_id := ""
	for chapter_index in range(chapter_count):
		var event := ChronicleSystemScript.next_event(terminal_state)
		var choice_index := 0 if chapter_index < chapter_count - 1 else 2
		var choices: Array = event.get("choices", [])
		if choices.size() != 3:
			_expect(false, "终章选择校验必须读到完整的三选一章节")
			return
		var choice: Dictionary = choices[choice_index]
		terminal_route_id = str(choice.get("route_id", ""))
		terminal_result = ChronicleSystemScript.resolve_choice(
			terminal_state, event, choice_index)
		if not bool(terminal_result.get("ok", false)):
			_expect(false, "终章选择校验路径必须能完整结算")
			return
	var resolutions: Dictionary = volume.get("route_resolutions", {})
	_expect(str(terminal_result.get("resolution", "")) ==
		str(resolutions.get(terminal_route_id, "")),
		"完卷摘要必须服从终章真实选择，不能被前二十三章的累计路线票数改写")


func _verify_outcome_variants() -> void:
	var variant_count := 0
	for era_value in ChronicleSystemScript.ERA_IDS:
		var era_id := str(era_value)
		var volume := ChronicleSystemScript.load_volume(era_id)
		var chapters: Array = volume.get("chapters", [])
		for chapter_index in range(chapters.size()):
			var chapter: Dictionary = chapters[chapter_index]
			for source_choice_value in (chapter.get("choices", []) as Array):
				var source_choice: Dictionary = source_choice_value
				var variants_value: Variant = source_choice.get("outcome_variants", {})
				if not variants_value is Dictionary or (variants_value as Dictionary).is_empty():
					continue
				for previous_route_value in (variants_value as Dictionary).keys():
					var previous_route_id := str(previous_route_value)
					var variant_state := GameStateScript.create_new_game(
						"换线结果校验", 20260820 + variant_count, [8, 8, 8, 8, 8])
					variant_state.current_era_id = era_id
					variant_state.current_era = str(GameStateScript.ERA_NAMES.get(era_id, era_id))
					variant_state.player.spirit_stones = 100000
					variant_state.player.pills = 100000
					var cursor := ChronicleSystemScript.normalize(variant_state)
					cursor["chapter_index"] = chapter_index
					cursor["current_chapter_id"] = str(chapter.get("id", ""))
					cursor["last_route_id"] = previous_route_id
					var story: Dictionary = variant_state.get("story", {})
					story["life_chronicle"] = cursor
					variant_state["story"] = story
					var event := ChronicleSystemScript.next_event(variant_state)
					var rendered_choice: Dictionary = {}
					for rendered_choice_value in (event.get("choices", []) as Array):
						if str((rendered_choice_value as Dictionary).get("id", "")) == \
								str(source_choice.get("id", "")):
							rendered_choice = rendered_choice_value
							break
					_expect(str(rendered_choice.get("outcome", "")) ==
						str((variants_value as Dictionary).get(previous_route_id, "")),
						"换线结果必须按上一章真实路线选择作者写明的 outcome_variants")
					variant_count += 1
	_expect(variant_count > 0, "至少一个关键换线节点必须提供逐路线结果文本")


func _verify_route_switch_matrix() -> void:
	var transition_count := 0
	for era_value in ChronicleSystemScript.ERA_IDS:
		var era_id := str(era_value)
		var volume := ChronicleSystemScript.load_volume(era_id)
		var route_ids: Array = volume.get("route_ids", [])
		var chapters: Array = volume.get("chapters", [])
		for chapter_index in range(1, chapters.size()):
			var chapter: Dictionary = chapters[chapter_index]
			for previous_route_value in route_ids:
				var previous_route_id := str(previous_route_value)
				var switch_state := GameStateScript.create_new_game(
					"逐章换线校验", 20270000 + transition_count, [8, 8, 8, 8, 8])
				switch_state.current_era_id = era_id
				switch_state.current_era = str(GameStateScript.ERA_NAMES.get(era_id, era_id))
				switch_state.player.spirit_stones = 100000
				switch_state.player.pills = 100000
				var cursor := ChronicleSystemScript.normalize(switch_state)
				cursor["chapter_index"] = chapter_index
				cursor["current_chapter_id"] = str(chapter.get("id", ""))
				cursor["last_route_id"] = previous_route_id
				var story: Dictionary = switch_state.get("story", {})
				story["life_chronicle"] = cursor
				switch_state["story"] = story
				var event := ChronicleSystemScript.next_event(switch_state)
				var choices: Array = event.get("choices", [])
				_expect(str(event.get("previous_route_id", "")) == previous_route_id and
					choices.size() == 3,
					"每章必须保留上一行动的回声，并继续给出三条可换路线")
				var offered_routes: Array[String] = []
				for choice_index in range(choices.size()):
					var choice: Dictionary = choices[choice_index]
					var outgoing_route_id := str(choice.get("route_id", ""))
					offered_routes.append(outgoing_route_id)
					_expect(bool(choice.get("visible", false)) and
						bool(choice.get("available", false)),
						"高资源且无额外前置时，任一来路都必须能改选三条路线")
					var choice_state: Dictionary = switch_state.duplicate(true)
					var result := ChronicleSystemScript.resolve_choice(
						choice_state, event, choice_index)
					_expect(bool(result.get("ok", false)) and
						str(result.get("route_id", "")) == outgoing_route_id,
						"逐章换线的九种来去组合都必须能真实结算")
					transition_count += 1
				var unique_routes: Array[String] = []
				for offered_route_id in offered_routes:
					if not unique_routes.has(offered_route_id):
						unique_routes.append(offered_route_id)
				_expect(unique_routes.size() == 3,
					"每章三项行动必须分别通往三条不同路线")
	_expect(transition_count == 6 * 23 * 3 * 3,
		"六卷二十三个换线节点必须覆盖全部 1242 种来去组合")


func _available_choice_index(event: Dictionary, preferred: int) -> int:
	var choices: Array = event.get("choices", [])
	if preferred >= 0 and preferred < choices.size() and \
			bool((choices[preferred] as Dictionary).get("available", false)):
		return preferred
	for index in range(choices.size()):
		if bool((choices[index] as Dictionary).get("available", false)):
			return index
	return 0
