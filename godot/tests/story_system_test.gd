extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const StorySystemScript = preload("res://scripts/story_system.gd")

var failures: Array[String] = []


func _init() -> void:
	var validation: Dictionary = StorySystemScript.validate_definitions()
	_expect(bool(validation.get("ok", false)) and int(validation.get("arc_count", 0)) == 4 and
		int(validation.get("node_count", 0)) == 28,
		"剧情数据必须包含四条主线、十六幕今生章节与十二幕二世续章")

	var state := GameStateScript.create_new_game("照卷人", 737373, [7, 7, 7, 7, 7])
	StorySystemScript.normalize(state)
	var twin := state.duplicate(true)
	var first_a: Dictionary = StorySystemScript.next_event(state)
	var first_b: Dictionary = StorySystemScript.next_event(twin)
	_expect(first_a == first_b and state.rng_cursor == twin.rng_cursor,
		"相同世界状态必须选出相同剧情节点")
	state = GameStateScript.create_new_game("照卷人", 737373, [7, 7, 7, 7, 7])
	StorySystemScript.normalize(state)

	var main_events := _advance_until(state, false, 120)
	_expect(main_events == 16, "四条今生主线必须各推进四幕且不重复刷已完成节点")
	for arc_id in StorySystemScript.ARC_IDS:
		_expect(int(state.story.arc_progress[arc_id]) == StorySystemScript.MAIN_STAGE_COUNT,
			"今生主线必须收束到4/4：%s" % arc_id)
		_expect(not str(state.story.arc_legacies[arc_id]).is_empty(),
			"今生终局必须写入稳定跨世定局：%s" % arc_id)
	_expect((state.story.resolved_arcs as Array).size() == 4,
		"四条今生终局必须各生成一项可审计记录")

	state["generation"] = 2
	state["player"] = GameStateScript.create_player("续卷人", 747474, [7, 7, 7, 7, 7])
	var before_birth: Dictionary = state.player.duplicate(true)
	var birth: Dictionary = StorySystemScript.apply_birth_legacies(state)
	var after_birth: Dictionary = state.player.duplicate(true)
	var duplicate_birth: Dictionary = StorySystemScript.apply_birth_legacies(state)
	_expect(bool(birth.get("applied", false)) and not bool(duplicate_birth.get("applied", true)) and
		state.player == after_birth and state.player != before_birth,
		"跨世定局加成必须在每一世仅应用一次")

	state.story.next_arc_event_at = 0
	var echo_events := _advance_until(state, true, 120)
	_expect(echo_events == 12, "第二世必须完整运行四条三幕定局续章")
	for arc_id in StorySystemScript.ARC_IDS:
		var echo: Dictionary = state.story.arc_echoes[arc_id]
		_expect(int(echo.stage) == StorySystemScript.ECHO_STAGE_COUNT and not str(echo.resolution).is_empty(),
			"二世续章必须形成结论：%s" % arc_id)
	_expect(StorySystemScript.next_event(state).is_empty(),
		"四条续章完成后不得重复刷同一批章节")
	_expect((state.story.unresolved_threads as Array).is_empty(),
		"已经定局的剧情不得残留为未竟因果")

	if failures.is_empty():
		print("STORY_SYSTEM_TEST_OK: 4x4 main arcs, 4x3 second-life echoes, persistence and birth effects passed")
		quit(0)
	else:
		for failure in failures:
			push_error("STORY_SYSTEM_TEST_FAILED: %s" % failure)
		quit(1)


func _advance_until(state: Dictionary, echo_phase: bool, limit: int) -> int:
	var resolved_events := 0
	for _step in range(limit):
		var event: Dictionary = StorySystemScript.next_event(state)
		if event.is_empty():
			state.player.total_events = int(state.player.total_events) + 1
			continue
		if (str(event.story_phase) == "echo") != echo_phase:
			state.player.total_events = int(state.player.total_events) + 1
			continue
		state.player.total_events = int(state.player.total_events) + 1
		var result: Dictionary = StorySystemScript.resolve_choice(state, event, resolved_events % 3)
		_expect(bool(result.get("ok", false)), "有效剧情节点必须能够解析选择")
		resolved_events += 1
		if _phase_complete(state, echo_phase):
			break
	return resolved_events


func _phase_complete(state: Dictionary, echo_phase: bool) -> bool:
	for arc_id in StorySystemScript.ARC_IDS:
		if echo_phase:
			if int((state.story.arc_echoes[arc_id] as Dictionary).stage) < StorySystemScript.ECHO_STAGE_COUNT:
				return false
		elif int(state.story.arc_progress[arc_id]) < StorySystemScript.MAIN_STAGE_COUNT:
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
