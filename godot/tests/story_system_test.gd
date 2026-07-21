extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const StorySystemScript = preload("res://scripts/story_system.gd")

var failures: Array[String] = []
var main_trigger_points: Array[int] = []
var echo_trigger_points: Array[int] = []


func _init() -> void:
	var validation: Dictionary = StorySystemScript.validate_definitions()
	_expect(bool(validation.get("ok", false)) and int(validation.get("arc_count", 0)) == 4 and
		int(validation.get("node_count", 0)) == 28,
		"剧情数据必须包含四条主线、十六幕今生章节与十二幕二世续章")
	var staged_art: Dictionary = StorySystemScript._build_event(
		GameStateScript.create_new_game("分镜校验", 737300, [7, 7, 7, 7, 7]),
		{"arc_id":"jade", "phase":"main", "stage":0})
	_expect(str(staged_art.get("character_id", "")) == "protagonist" and
		str(staged_art.get("motion_profile", "")) == "spectral" and
		str(staged_art.get("scene", "")).begins_with("res://art/scenes/"),
		"每一幕必须能够覆盖角色身份、分镜场景与动效档位")
	var jade_arc: Dictionary = (StorySystemScript.load_definitions().arcs[0] as Dictionary)
	var scene_only_art: Dictionary = StorySystemScript._resolved_art(jade_arc,
		{"art":{"portrait_mode":"scene_only", "portrait":""}})
	_expect(bool(StorySystemScript._valid_art_binding(scene_only_art)) and
		str(scene_only_art.get("portrait_mode", "")) == "scene_only",
		"关键剧情必须支持不重复叠加立绘的全幅分镜模式")

	var state := GameStateScript.create_new_game("照卷人", 737373, [7, 7, 7, 7, 7])
	StorySystemScript.normalize(state)
	var twin := state.duplicate(true)
	var first_a: Dictionary = StorySystemScript.next_event(state)
	var first_b: Dictionary = StorySystemScript.next_event(twin)
	_expect(first_a == first_b and state.rng_cursor == twin.rng_cursor,
		"相同世界状态必须选出相同剧情节点")
	state = GameStateScript.create_new_game("照卷人", 737373, [7, 7, 7, 7, 7])
	StorySystemScript.normalize(state)

	var main_events := _advance_until(state, false, 120, main_trigger_points)
	_expect(main_events == 16, "四条今生主线必须各推进四幕且不重复刷已完成节点")
	_expect(_pacing_is_healthy(main_trigger_points, 16, 48),
		"今生主线必须保持至少两次普通抉择的呼吸间隔，并在48次事件内收束")
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
	var echo_events := _advance_until(state, true, 120, echo_trigger_points)
	_expect(echo_events == 12, "第二世必须完整运行四条三幕定局续章")
	_expect(_pacing_is_healthy(echo_trigger_points, 12, 36),
		"二世续章必须保持至少两次普通抉择的呼吸间隔，并在36次事件内收束")
	for arc_id in StorySystemScript.ARC_IDS:
		var echo: Dictionary = state.story.arc_echoes[arc_id]
		_expect(int(echo.stage) == StorySystemScript.ECHO_STAGE_COUNT and not str(echo.resolution).is_empty(),
			"二世续章必须形成结论：%s" % arc_id)
	_expect(StorySystemScript.next_event(state).is_empty(),
		"四条续章完成后不得重复刷同一批章节")
	_expect((state.story.unresolved_threads as Array).is_empty(),
		"已经定局的剧情不得残留为未竟因果")

	if failures.is_empty():
		print("STORY_PACING: main=%s echo=%s" % [
			JSON.stringify(_pacing_summary(main_trigger_points)),
			JSON.stringify(_pacing_summary(echo_trigger_points)),
		])
		print("STORY_SYSTEM_TEST_OK: 4x4 main arcs, 4x3 second-life echoes, persistence and birth effects passed")
		quit(0)
	else:
		for failure in failures:
			push_error("STORY_SYSTEM_TEST_FAILED: %s" % failure)
		quit(1)


func _advance_until(state: Dictionary, echo_phase: bool, limit: int,
		trigger_points: Array[int]) -> int:
	var resolved_events := 0
	for _step in range(limit):
		var event: Dictionary = StorySystemScript.next_event(state)
		if event.is_empty():
			state.player.total_events = int(state.player.total_events) + 1
			continue
		if (str(event.story_phase) == "echo") != echo_phase:
			state.player.total_events = int(state.player.total_events) + 1
			continue
		trigger_points.append(int(state.player.total_events))
		state.player.total_events = int(state.player.total_events) + 1
		var result: Dictionary = StorySystemScript.resolve_choice(state, event, resolved_events % 3)
		_expect(bool(result.get("ok", false)), "有效剧情节点必须能够解析选择")
		resolved_events += 1
		if _phase_complete(state, echo_phase):
			break
	return resolved_events


func _pacing_is_healthy(trigger_points: Array[int], expected_count: int,
		maximum_final_event: int) -> bool:
	if trigger_points.size() != expected_count or trigger_points.is_empty() or \
			trigger_points[-1] > maximum_final_event:
		return false
	for index in range(1, trigger_points.size()):
		if trigger_points[index] - trigger_points[index - 1] < 2:
			return false
	return true


func _pacing_summary(trigger_points: Array[int]) -> Dictionary:
	var gaps: Array[int] = []
	for index in range(1, trigger_points.size()):
		gaps.append(trigger_points[index] - trigger_points[index - 1])
	return {
		"chapters": trigger_points.size(),
		"first_event": trigger_points[0] if not trigger_points.is_empty() else -1,
		"last_event": trigger_points[-1] if not trigger_points.is_empty() else -1,
		"minimum_gap": gaps.min() if not gaps.is_empty() else 0,
		"maximum_gap": gaps.max() if not gaps.is_empty() else 0,
	}


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
