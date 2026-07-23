extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const NarrativeScript = preload("res://scripts/narrative_consequence_system.gd")
const StorySystemScript = preload("res://scripts/story_system.gd")

const PROSE_BASELINE_COUNTS := {
	"不是": 17, "而是": 14, "第一次": 15, "终于": 10, "从此": 3,
	"不能再": 3, "不再": 11, "真正": 15, "共同": 16, "同一": 10,
}
const PROSE_TERM_LIMITS := {
	"不是": 8, "而是": 7, "第一次": 7, "终于": 5, "从此": 2,
	"不能再": 2, "不再": 5, "真正": 7, "共同": 8, "同一": 6,
}

var failures: Array[String] = []


func _init() -> void:
	var validation: Dictionary = StorySystemScript.validate_definitions()
	_expect(bool(validation.get("ok", false)) and int(validation.get("arc_count", 0)) == 4,
		"剧情数据必须包含四条主卷")
	_expect(int(validation.get("node_count", 0)) == 28 and
		int(validation.get("choice_count", 0)) == 84 and
		int(validation.get("variant_count", 0)) >= 72,
		"四条主卷必须包含 28 个章节、每章三个独立选择和跨路线正文变体")
	var definitions: Dictionary = StorySystemScript.load_definitions()
	_test_static_graph_validation()
	_test_choice_targets_drive_graph()
	_test_choice_visibility_and_enabled_state(definitions)
	_test_legacy_stage_cursor_migration()
	_test_prose_repetition(definitions)
	_test_resource_reachability(definitions)
	_test_authored_obligation_lifecycle(definitions)

	var state := GameStateScript.create_new_game("章节校验", 737300, [7, 7, 7, 7, 7])
	var first_event: Dictionary = StorySystemScript.next_event(state)
	_expect(str(first_event.get("story_arc_id", "")) == "jade" and
		int(first_event.get("story_stage", -1)) == 0 and
		(first_event.get("choices", []) as Array).size() == 3,
		"首章必须从固定的旧玉主卷开始并提供三个行动")
	var twin := state.duplicate(true)
	var twin_event: Dictionary = StorySystemScript.next_event(twin)
	_expect(first_event == twin_event and int(state.get("rng_cursor", 0)) ==
		int(twin.get("rng_cursor", 0)), "相同状态必须得到相同首章，主流程不得靠随机跳卷")

	var jade_choice: Dictionary = (first_event.choices as Array)[0]
	var jade_route := str(jade_choice.get("route_id", ""))
	state.player.total_events = int(state.player.total_events) + 1
	var first_result: Dictionary = StorySystemScript.resolve_choice(state, first_event, 0)
	_expect(bool(first_result.get("ok", false)) and str(first_result.get("route_id", "")) == jade_route,
		"章节选择必须写入路线历史")
	var routed_event: Dictionary = StorySystemScript.next_event(state)
	var jade_arc: Dictionary = (definitions.arcs as Array)[0]
	var jade_second: Dictionary = (jade_arc.main as Array)[1]
	var routed_variant: Dictionary = (jade_second.route_variants as Dictionary).get(jade_route, {})
	_expect(str(routed_event.get("story_arc_id", "")) == "jade" and
		int(routed_event.get("story_stage", -1)) == 1 and
		str(routed_event.get("previous_route_id", "")) == jade_route and
		str(routed_event.get("title", "")) == str(routed_variant.get("title", "")) and
		str(routed_event.get("description", "")).contains(str(routed_variant.get("description", ""))),
		"上一章路线必须在下一章标题和正文中产生可见变体")

	var journal_state := GameStateScript.create_new_game("长卷校验", 737301, [7, 7, 7, 7, 7])
	var journal_event: Dictionary = StorySystemScript.next_event(journal_state)
	var journal_choice: Dictionary = (journal_event.choices as Array)[0]
	var journal_entry: Dictionary = StorySystemScript.record_chapter(journal_state, journal_event,
		journal_choice, str(journal_choice.outcome), "主卷推进", "阶段命途", "敌踪")
	_expect(str(journal_entry.get("title", "")) == str(journal_event.get("title", "")) and
		str(journal_entry.get("choice", "")) == str(journal_choice.get("text", "")) and
		int(journal_entry.get("generation", 0)) == 1 and
		str(StorySystemScript.previous_choice_recap(journal_state, journal_event)).contains(
			str(journal_choice.get("text", ""))),
		"章节日志必须保留标题、行动、结果和前情摘要")
	for chapter_index in range(StorySystemScript.MAX_CHAPTER_LOG + 8):
		journal_event["id"] = "bounded_%d" % chapter_index
		StorySystemScript.record_chapter(journal_state, journal_event, journal_choice,
			"第%d条有界章节" % chapter_index)
	_expect((journal_state.story.chapter_log as Array).size() == StorySystemScript.MAX_CHAPTER_LOG,
		"章节日志必须有上限")

	var main_state := GameStateScript.create_new_game("今生长卷", 737373, [7, 7, 7, 7, 7])
	var expected_arcs := ["jade", "jade", "jade", "jade", "sect", "sect", "sect", "sect",
		"family", "family", "family", "family", "rival", "rival", "rival", "rival"]
	var observed_arcs: Array[String] = []
	var observed_stages: Array[int] = []
	for step in range(expected_arcs.size()):
		var event: Dictionary = StorySystemScript.next_event(main_state)
		_expect(not event.is_empty(), "今生第%d章必须可达" % (step + 1))
		if event.is_empty():
			break
		observed_arcs.append(str(event.get("story_arc_id", "")))
		observed_stages.append(int(event.get("story_stage", -1)))
		var choice_index := _first_available(event)
		main_state.player.total_events = int(main_state.player.total_events) + 1
		var result: Dictionary = StorySystemScript.resolve_choice(main_state, event, choice_index)
		_expect(bool(result.get("ok", false)), "第%d章的选择必须能结算" % (step + 1))
	_expect(observed_arcs == expected_arcs and observed_stages == [0, 1, 2, 3, 0, 1, 2, 3,
		0, 1, 2, 3, 0, 1, 2, 3], "四卷必须各自连续完成四章，不得随机跳线")
	for arc_id in StorySystemScript.ARC_IDS:
		_expect(int(main_state.story.arc_progress[arc_id]) == StorySystemScript.MAIN_STAGE_COUNT and
			not str(main_state.story.arc_legacies[arc_id]).is_empty(),
			"主卷必须写入路线定局：%s" % arc_id)
	_expect((main_state.story.route_history as Dictionary).size() == 4 and
		int(main_state.story.choice_count) == 16 and
		(main_state.story.resolved_arcs as Array).size() == 4,
		"四卷完成后必须保留完整路线历史和可审计定局")
	_expect(StorySystemScript.next_event(main_state).is_empty(), "今生四卷完成后不得重复刷章")

	main_state.generation = 2
	main_state.player = GameStateScript.create_player("续章校验", 747474, [7, 7, 7, 7, 7])
	main_state.player.total_events = 0
	main_state.story.next_arc_event_at = 0
	main_state.story.active_arc_id = ""
	var before_birth: Dictionary = main_state.player.duplicate(true)
	var birth: Dictionary = StorySystemScript.apply_birth_legacies(main_state)
	var after_birth: Dictionary = main_state.player.duplicate(true)
	var duplicate_birth: Dictionary = StorySystemScript.apply_birth_legacies(main_state)
	_expect(bool(birth.get("applied", false)) and not bool(duplicate_birth.get("applied", true)) and
		main_state.player == after_birth and main_state.player != before_birth,
		"跨世定局只能在新的一世应用一次")

	var echo_arcs: Array[String] = []
	for step in range(12):
		var echo_event: Dictionary = StorySystemScript.next_event(main_state)
		_expect(not echo_event.is_empty() and str(echo_event.get("story_phase", "")) == "echo",
			"第二世第%d个续章必须可达" % (step + 1))
		if echo_event.is_empty():
			break
		echo_arcs.append(str(echo_event.get("story_arc_id", "")))
		main_state.player.total_events = int(main_state.player.total_events) + 1
		var echo_result: Dictionary = StorySystemScript.resolve_choice(main_state, echo_event,
			_first_available(echo_event))
		_expect(bool(echo_result.get("ok", false)), "续章选择必须能结算")
	_expect(echo_arcs == ["jade", "jade", "jade", "sect", "sect", "sect", "family", "family",
		"family", "rival", "rival", "rival"], "续章必须按前世定局顺序连续推进")
	_expect(StorySystemScript.next_event(main_state).is_empty(), "所有续章完成后不得重复刷章")
	_expect((main_state.story.unresolved_threads as Array).is_empty(),
		"已完成的主卷和续章不得留下伪未竟线程")

	if failures.is_empty():
		print("STORY_SYSTEM_TEST_OK: schema3 branch graph, conditions, cursor migration, resolutions and second-life echoes passed")
		quit(0)
	else:
		for failure in failures:
			push_error("STORY_SYSTEM_TEST_FAILED: %s" % failure)
		quit(1)


func _first_available(event: Dictionary) -> int:
	var choices: Array = event.get("choices", [])
	for index in range(choices.size()):
		if bool((choices[index] as Dictionary).get("available", true)):
			return index
	return 0


func _test_static_graph_validation() -> void:
	var valid_graph := {"arcs": [{
		"id": "test", "entry_node_id": "main_a", "echo_entry_node_id": "echo_a",
		"main": [
			{"id": "main_a", "choices": [{"id": "go_b", "target_node_id": "main_b"}]},
			{"id": "main_b", "choices": [{"id": "finish_main", "terminal": true}]},
		],
		"echo": [
			{"id": "echo_a", "choices": [{"id": "finish_echo", "terminal": true}]},
		],
	}]}
	var valid_result: Dictionary = StorySystemScript.validate_graph(valid_graph)
	_expect(bool(valid_result.get("ok", false)) and int(valid_result.get("node_count", 0)) == 3,
		"静态图校验必须接受入口可达且有终点的有向图")

	var dangling: Dictionary = valid_graph.duplicate(true)
	dangling.arcs[0].main[0].choices[0].target_node_id = "missing"
	_expect(str(StorySystemScript.validate_graph(dangling).get("code", "")) ==
		"dangling_story_target", "静态图校验必须定位悬空选择目标")

	var unreachable: Dictionary = valid_graph.duplicate(true)
	unreachable.arcs[0].main.append(
		{"id": "main_orphan", "choices": [{"id": "orphan_end", "terminal": true}]})
	_expect(str(StorySystemScript.validate_graph(unreachable).get("code", "")) ==
		"unreachable_story_node", "静态图校验必须定位入口不可达节点")

	var cyclic: Dictionary = valid_graph.duplicate(true)
	cyclic.arcs[0].main[1].choices[0] = {"id": "back_to_a", "target_node_id": "main_a"}
	_expect(str(StorySystemScript.validate_graph(cyclic).get("code", "")) == "story_cycle",
		"静态图校验必须拒绝节点循环")

	var no_fallback: Dictionary = valid_graph.duplicate(true)
	no_fallback.arcs[0].main[0].choices[0].visible_if = {"flags_all": ["never"]}
	_expect(str(StorySystemScript.validate_graph(no_fallback).get("code", "")) ==
		"missing_hidden_fallback", "全部可能隐藏的作者选项必须声明回退节点")


func _test_choice_targets_drive_graph() -> void:
	var normal_state := GameStateScript.create_new_game("节点分流", 737305, [7, 7, 7, 7, 7])
	var normal_event: Dictionary = StorySystemScript.next_event(normal_state)
	normal_state.player.total_events = int(normal_state.player.total_events) + 1
	var normal_result: Dictionary = StorySystemScript.resolve_choice(normal_state, normal_event, 0)
	var normal_next: Dictionary = StorySystemScript.next_event(normal_state)

	var branch_state := GameStateScript.create_new_game("节点分流", 737305, [7, 7, 7, 7, 7])
	var branch_event: Dictionary = StorySystemScript.next_event(branch_state)
	branch_state.player.total_events = int(branch_state.player.total_events) + 1
	var branch_result: Dictionary = StorySystemScript.resolve_choice(branch_state, branch_event, 2)
	var branch_next: Dictionary = StorySystemScript.next_event(branch_state)
	_expect(str(normal_result.get("next_node_id", "")) == "jade_main_2" and
		str(normal_next.get("id", "")) == "jade_main_2" and
		str(branch_result.get("next_node_id", "")) == "jade_main_3" and
		str(branch_next.get("id", "")) == "jade_main_3" and
		str(normal_next.get("id", "")) != str(branch_next.get("id", "")),
		"同一剧情节点的不同选择必须真正写入不同 next 节点")


func _test_choice_visibility_and_enabled_state(definitions: Dictionary) -> void:
	var conditional_definitions: Dictionary = definitions.duplicate(true)
	var first_node: Dictionary = conditional_definitions.arcs[0].main[0]
	first_node.choices[0]["visible_if"] = {"flags_all": ["secret_known"]}
	first_node.choices[1]["enabled_if"] = {"flags_all": ["permission_granted"]}
	first_node.choices[1]["disabled_reason"] = "你还没有取得许可。"
	StorySystemScript._definitions_cache = conditional_definitions
	var state := GameStateScript.create_new_game("条件分离", 737306, [7, 7, 7, 7, 7])
	var event: Dictionary = StorySystemScript.next_event(state)
	var choices: Array = event.get("choices", [])
	_expect(choices.size() == 2 and str((choices[0] as Dictionary).get("id", "")) ==
		"jade_m1_anchor" and not bool((choices[0] as Dictionary).get("available", true)) and
		str((choices[0] as Dictionary).get("unavailable_reason", "")) == "你还没有取得许可。",
		"visible_if 必须移除隐藏项，enabled_if 必须保留并禁用可见项")
	var disabled_result: Dictionary = StorySystemScript.resolve_choice(state, event, 0)
	_expect(str(disabled_result.get("code", "")) == "choice_unavailable",
		"可见但禁用的选择不能结算")
	var forged_event := event.duplicate(true)
	(forged_event.choices as Array).append(first_node.choices[0].duplicate(true))
	var forged_result: Dictionary = StorySystemScript.resolve_choice(
		state, forged_event, (forged_event.choices as Array).size() - 1)
	_expect(str(forged_result.get("code", "")) == "hidden_or_unknown_choice",
		"伪造显示索引不能选中隐藏项")
	var fallback_definitions: Dictionary = definitions.duplicate(true)
	var fallback_node: Dictionary = fallback_definitions.arcs[0].main[0]
	for choice_value in (fallback_node.choices as Array):
		(choice_value as Dictionary)["visible_if"] = {"flags_all": ["never_visible"]}
	fallback_node["fallback_node_id"] = "jade_main_2"
	StorySystemScript._definitions_cache = fallback_definitions
	var fallback_state := GameStateScript.create_new_game("作者回退", 737308, [7, 7, 7, 7, 7])
	var fallback_event: Dictionary = StorySystemScript.next_event(fallback_state)
	_expect(str(fallback_event.get("id", "")) == "jade_main_2" and
		str(fallback_state.story.arc_node_cursors.jade) == "jade_main_2",
		"全部选择隐藏时必须持久推进到作者指定 fallback 节点")
	StorySystemScript._definitions_cache = definitions


func _test_legacy_stage_cursor_migration() -> void:
	var legacy_state := GameStateScript.create_new_game("旧档迁移", 737307, [7, 7, 7, 7, 7])
	legacy_state.story.erase("arc_node_cursors")
	legacy_state.story.arc_progress["jade"] = 2
	legacy_state.story.arc_echoes["jade"] = {"stage": 1, "resolution": ""}
	var migrated: Dictionary = StorySystemScript.normalize(legacy_state)
	_expect(str(migrated.arc_node_cursors.jade) == "jade_main_3" and
		str(migrated.arc_echoes.jade.node_id) == "jade_echo_2" and
		int(migrated.arc_progress.jade) == 2 and int(migrated.arc_echoes.jade.stage) == 1,
		"旧存档 stage 必须稳定迁移为相同章节的节点游标")


func _test_resource_reachability(definitions: Dictionary) -> void:
	var baseline := GameStateScript.create_player("资源校验", 737302, [7, 7, 7, 7, 7])
	var resource_ids := ["spirit_stones", "pills"]
	for phase in ["main", "echo"]:
		var combinations := _route_combinations(definitions, phase)
		_expect(combinations.size() == 81,
			"%s必须覆盖四卷三路线的81种组合" % phase)
		for combination_value in combinations:
			var combination: Array = combination_value
			var resources := {
				"spirit_stones": int(baseline.spirit_stones),
				"pills": int(baseline.pills),
			}
			var blocked := false
			var arcs: Array = definitions.get("arcs", [])
			for arc_index in range(arcs.size()):
				var arc: Dictionary = arcs[arc_index]
				var route_id := str(combination[arc_index])
				for node_value in (arc.get(phase, []) as Array):
					var node: Dictionary = node_value
					var choice := _choice_for_route(node, route_id)
					for resource_id in resource_ids:
						var delta := int((choice.get("deltas", {}) as Dictionary).get(resource_id, 0))
						if int(resources[resource_id]) + delta < 0:
							_expect(false, "%s路线组合%s在%s/%s因%s不足中断" % [
								phase, str(combination), str(arc.get("id", "")),
								str(node.get("id", "")), resource_id])
							blocked = true
							break
						resources[resource_id] = int(resources[resource_id]) + delta
					if blocked:
						break
				if blocked:
					break

		# Route variants remain switchable at every chapter. The minimum reachable
		# balance guards all within-arc switches without enumerating 3^16 paths.
		var minimum := {
			"spirit_stones": int(baseline.spirit_stones),
			"pills": int(baseline.pills),
		}
		for arc_value in (definitions.get("arcs", []) as Array):
			var arc: Dictionary = arc_value
			for node_value in (arc.get(phase, []) as Array):
				var node: Dictionary = node_value
				var choices: Array = node.get("choices", [])
				for resource_id in resource_ids:
					var minimum_delta := 0
					for choice_value in choices:
						var choice: Dictionary = choice_value
						minimum_delta = mini(minimum_delta,
							int((choice.get("deltas", {}) as Dictionary).get(resource_id, 0)))
					_expect(int(minimum[resource_id]) + minimum_delta >= 0,
						"%s任意换线在%s/%s可能耗尽%s" % [phase,
							str(arc.get("id", "")), str(node.get("id", "")), resource_id])
					minimum[resource_id] = int(minimum[resource_id]) + minimum_delta


func _test_prose_repetition(definitions: Dictionary) -> void:
	var text_units: Array[String] = []
	_collect_prose_units(definitions, text_units)
	var combined := "\n".join(text_units)
	var current: Dictionary = {}
	for term in PROSE_TERM_LIMITS.keys():
		var count := combined.count(str(term))
		current[term] = count
		_expect(count <= int(PROSE_TERM_LIMITS[term]),
			"正文模板词%s超过上限：%d/%d" % [term, count, int(PROSE_TERM_LIMITS[term])])
	print("STORY_PROSE_STATS: units=%d baseline=%s current=%s" % [
		text_units.size(), JSON.stringify(PROSE_BASELINE_COUNTS), JSON.stringify(current)])


func _collect_prose_units(value: Variant, output: Array[String]) -> void:
	if value is Array:
		for item in value as Array:
			_collect_prose_units(item, output)
		return
	if not value is Dictionary:
		return
	var dictionary: Dictionary = value
	for key in dictionary.keys():
		var item: Variant = dictionary[key]
		if (str(key) == "description" or str(key) == "outcome") and item is String:
			output.append(str(item))
		_collect_prose_units(item, output)


func _test_authored_obligation_lifecycle(definitions: Dictionary) -> void:
	var promise_ids: Dictionary = {}
	var debt_ids: Dictionary = {}
	var promise_closures: Dictionary = {}
	var debt_closures: Dictionary = {}
	for arc_value in (definitions.get("arcs", []) as Array):
		var arc: Dictionary = arc_value
		for phase in ["main", "echo"]:
			for node_value in (arc.get(phase, []) as Array):
				var node: Dictionary = node_value
				for choice_value in (node.get("choices", []) as Array):
					var choice: Dictionary = choice_value
					_collect_record_ids(choice.get("promises_add", []), promise_ids)
					_collect_record_ids(choice.get("debts_add", []), debt_ids)
					_collect_string_ids(choice.get("promises_resolve", []), promise_closures)
					_collect_string_ids(choice.get("promises_break", []), promise_closures)
					_collect_string_ids(choice.get("debts_resolve", []), debt_closures)
					_collect_string_ids(choice.get("debts_forgive", []), debt_closures)
	for promise_id in promise_ids.keys():
		_expect(promise_closures.has(promise_id), "承诺必须在后续章节兑现或明确打破：%s" % promise_id)
	for debt_id in debt_ids.keys():
		_expect(debt_closures.has(debt_id), "债务必须在后续章节偿还或明确免除：%s" % debt_id)
	for promise_id in promise_closures.keys():
		_expect(promise_ids.has(promise_id), "承诺闭环不得引用不存在的记录：%s" % promise_id)
	for debt_id in debt_closures.keys():
		_expect(debt_ids.has(debt_id), "债务闭环不得引用不存在的记录：%s" % debt_id)

	var state := GameStateScript.create_new_game("义务闭环", 737303, [7, 7, 7, 7, 7])
	var characters: Array = definitions.get("characters", [])
	for arc_value in (definitions.get("arcs", []) as Array):
		var arc: Dictionary = arc_value
		for phase in ["main", "echo"]:
			var nodes: Array = arc.get(phase, [])
			for stage in range(nodes.size()):
				var node: Dictionary = nodes[stage]
				var event := {"story_arc_id": str(arc.get("id", "")),
					"story_phase": phase, "story_stage": stage}
				for choice_value in (node.get("choices", []) as Array):
					var choice: Dictionary = choice_value
					# The refusal route is tested separately; otherwise it would forgive
					# family debts before the repayment ending can close them.
					if str(choice.get("id", "")) == "family_e1_break":
						continue
					NarrativeScript.apply_choice(state, event, choice, characters)
	var open_promises := _records_with_status(state.story.promises, "open")
	var open_debts := _records_with_status(state.story.debts, "open")
	_expect(open_promises.is_empty() and open_debts.is_empty(),
		"完成卷章后不得继续显示已履行义务：承诺%s，债务%s" % [open_promises, open_debts])

	var refusal_state := GameStateScript.create_new_game("拒绝继承", 737304, [7, 7, 7, 7, 7])
	for choice_id in ["family_m1_truth", "family_m2_truth", "family_m3_truth", "family_e1_break"]:
		var authored: Dictionary = _choice_by_id(definitions, choice_id)
		NarrativeScript.apply_choice(refusal_state,
			{"story_arc_id": "family", "story_phase": "echo" if choice_id == "family_e1_break" else "main"},
			authored, characters)
	_expect(_records_with_status(refusal_state.story.debts, "forgiven").size() == 3 and
		_records_with_status(refusal_state.story.debts, "open").is_empty(),
		"拒绝继承旧名后，三笔族债必须从玩家当前义务中移除并保留历史")


func _collect_record_ids(values: Variant, output: Dictionary) -> void:
	if not values is Array:
		return
	for value in values as Array:
		if value is Dictionary:
			var record_id := str((value as Dictionary).get("id", ""))
			if not record_id.is_empty():
				output[record_id] = true


func _collect_string_ids(values: Variant, output: Dictionary) -> void:
	if not values is Array:
		return
	for value in values as Array:
		var record_id := str(value)
		if not record_id.is_empty():
			output[record_id] = true


func _records_with_status(values: Variant, status: String) -> Array[String]:
	var result: Array[String] = []
	if not values is Array:
		return result
	for value in values as Array:
		if value is Dictionary and str((value as Dictionary).get("status", "")) == status:
			result.append(str((value as Dictionary).get("id", "")))
	return result


func _choice_by_id(definitions: Dictionary, choice_id: String) -> Dictionary:
	for arc_value in (definitions.get("arcs", []) as Array):
		var arc: Dictionary = arc_value
		for phase in ["main", "echo"]:
			for node_value in (arc.get(phase, []) as Array):
				var node: Dictionary = node_value
				for choice_value in (node.get("choices", []) as Array):
					var choice: Dictionary = choice_value
					if str(choice.get("id", "")) == choice_id:
						return choice
	return {}


func _route_combinations(definitions: Dictionary, phase: String) -> Array:
	var combinations: Array = [[]]
	for arc_value in (definitions.get("arcs", []) as Array):
		var arc: Dictionary = arc_value
		var mapping: Dictionary = arc.get("%s_route_resolutions" % phase, {})
		var expanded: Array = []
		for combination_value in combinations:
			for route_value in mapping.keys():
				var combination: Array = (combination_value as Array).duplicate()
				combination.append(str(route_value))
				expanded.append(combination)
		combinations = expanded
	return combinations


func _choice_for_route(node: Dictionary, route_id: String) -> Dictionary:
	for choice_value in (node.get("choices", []) as Array):
		var choice: Dictionary = choice_value
		if str(choice.get("route_id", "")) == route_id:
			return choice
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
