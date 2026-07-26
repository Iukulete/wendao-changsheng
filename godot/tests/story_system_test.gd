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
	_test_jade_story_clarity(definitions)
	_test_rival_story_agency(definitions)
	_test_story_continuity_details(definitions)
	_test_authored_choice_consequences(definitions)
	_test_resource_reachability(definitions)
	_test_authored_obligation_lifecycle(definitions)
	_test_obligation_closure_across_route_switches(definitions)

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
	var routed_description := str(routed_event.get("description", ""))
	_expect(str(routed_event.get("story_arc_id", "")) == "jade" and
		int(routed_event.get("story_stage", -1)) == 1 and
		str(routed_event.get("previous_route_id", "")) == jade_route and
		str(routed_event.get("title", "")) == str(routed_variant.get("title", "")) and
		routed_description.begins_with(str(jade_second.get("description", ""))) and
		routed_description.contains(str(routed_variant.get("description", ""))),
		"下一章必须先交代完整公共场景，再说明上一选择造成的变化")

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
	var definitions: Dictionary = StorySystemScript.load_definitions()
	for arc_value in (definitions.get("arcs", []) as Array):
		var arc: Dictionary = arc_value
		for phase in ["main", "echo"]:
			var nodes: Array = arc.get(phase, [])
			var opening_choices: Array = (nodes[0] as Dictionary).get("choices", [])
			_expect(str((opening_choices[2] as Dictionary).get("target_node_id", "")) ==
				str((nodes[1] as Dictionary).get("id", "")),
				"%s 卷 %s 首节点的第三个选择不得跳过第二节点" % [
					str(arc.get("id", "")), phase])

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
		str(branch_result.get("next_node_id", "")) == "jade_main_2" and
		str(branch_next.get("id", "")) == "jade_main_2",
		"首节点的不同路线都必须先进入第二节点")


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


func _test_jade_story_clarity(definitions: Dictionary) -> void:
	var jade: Dictionary = {}
	for arc_value in (definitions.get("arcs", []) as Array):
		var arc: Dictionary = arc_value
		if str(arc.get("id", "")) == "jade":
			jade = arc
			break
	_expect(not jade.is_empty(), "旧玉剧情必须存在")
	if jade.is_empty():
		return
	var opening: Dictionary = (jade.get("main", []) as Array)[0]
	var opening_description := str(opening.get("description", ""))
	_expect(opening_description.contains("保存着前世记忆") and
		opening_description.contains("可能残缺") and opening_description.contains("可能被人改过"),
		"旧玉开场必须直接说明用途，以及记忆可能残缺或被篡改")
	var opening_choices: Array = opening.get("choices", [])
	_expect(opening_choices.size() == 3 and
		str((opening_choices[0] as Dictionary).get("text", "")).contains("按线索调查") and
		str((opening_choices[1] as Dictionary).get("text", "")).contains("现实") and
		str((opening_choices[2] as Dictionary).get("text", "")).contains("封住"),
		"旧玉开场的三个选项必须直接说明调查、现实核对和封存的区别")
	var witness_outcome := str((opening_choices[0] as Dictionary).get("outcome", ""))
	_expect(witness_outcome.contains("人和地点") and witness_outcome.contains("一概不能当真") and
		not witness_outcome.contains("相信其中任何人"),
		"旧玉开场结果必须说明具体调查动作与证据标准，不能把记忆内容误写成人物信任")
	var visible_text: Array[String] = []
	_collect_jade_visible_text(jade.get("main", []), visible_text)
	_collect_jade_visible_text(jade.get("echo", []), visible_text)
	var combined := "\n".join(visible_text)
	for opaque_term in ["回响", "定锚", "命途", "因果", "牵系", "未偿", "伪忆", "梦兆", "旧我"]:
		_expect(not combined.contains(opaque_term),
			"旧玉玩家文案不得用未解释的抽象词：%s" % opaque_term)
	for required_fact in ["南渡口安置院", "程观鹤", "鹤纹铜扣", "红灯", "许青梧",
			"私卖药材", "补回死伤名单", "追回药款"]:
		_expect(combined.contains(required_fact),
			"旧玉主卷必须交代完整旧案线索与受害者诉求：%s" % required_fact)
	for choice_id in ["jade_m4_witness", "jade_m4_anchor", "jade_m4_seal"]:
		var final_outcome := str(_choice_by_id(definitions, choice_id).get("outcome", ""))
		_expect(final_outcome.contains("许青梧") or final_outcome.contains("幸存者"),
			"旧玉终章三条路线都必须先向幸存者交付证据并接受追责：%s" % choice_id)
	var all_story_text: Array[String] = []
	_collect_jade_visible_text(definitions.get("arcs", []), all_story_text)
	var all_combined := "\n".join(all_story_text)
	for awkward_fragment in ["相信其中任何人", "把传闻变成一张", "名字刚重现",
			"血脉因此获得来处", "祖名只能加入关系", "自由和恶堕不会因",
			"引敌之情", "宿敌因此成为双方反复选择的名字",
			"一座没有登记的渡口", "亲手合上最后一页",
			"新门规还没有第一位违犯者", "血脉能说明你从哪里来",
			"两样东西都在等你决定是否留下", "无法把对方当作普通路人",
			"只有一盏灯和一个等你回答的时辰", "他只要求今后",
			"旁人插不进你们的规则", "无需用伤害证明关系真实"]:
		_expect(not all_combined.contains(awkward_fragment),
			"主线文案出现指代不清或抽象拼接：%s" % awkward_fragment)


func _test_rival_story_agency(definitions: Dictionary) -> void:
	var rival_main_3: Dictionary = {}
	for arc_value in (definitions.get("arcs", []) as Array):
		var arc: Dictionary = arc_value
		if str(arc.get("id", "")) != "rival":
			continue
		for node_value in (arc.get("main", []) as Array):
			var node: Dictionary = node_value
			if str(node.get("id", "")) == "rival_main_3":
				rival_main_3 = node
				break
	_expect(not rival_main_3.is_empty(), "江照雪主卷第三章必须存在")
	if rival_main_3.is_empty():
		return
	var description := str(rival_main_3.get("description", ""))
	_expect(description.contains("止血丹") and description.contains("当面否决") and
		description.contains("遮去三人的姓名"),
		"江照雪出阵后必须主动分药，并否决公开递信人姓名的方案")
	for choice_value in (rival_main_3.get("choices", []) as Array):
		var choice: Dictionary = choice_value
		var outcome := str(choice.get("outcome", ""))
		_expect(outcome.contains("遮名") or outcome.contains("遮去") or
			outcome.contains("递信人名单"),
			"江照雪第三章的每条路线都必须保护递信人姓名：%s" %
				str(choice.get("id", "")))


func _test_story_continuity_details(definitions: Dictionary) -> void:
	var jade_main_3 := str(_node_by_id(definitions, "jade_main_3").get("description", ""))
	_expect(jade_main_3.contains("主事审案") and jade_main_3.contains("篡忆阵"),
		"旧玉第三章必须说明程观鹤扣玉和篡改记忆的手段")
	for choice_id in ["jade_e1_witness", "jade_e1_anchor", "jade_e1_seal"]:
		var outcome := str(_choice_by_id(definitions, choice_id).get("outcome", ""))
		_expect(outcome.contains("罗慎") and
			(outcome.contains("副本") or outcome.contains("原件")),
			"旧玉续章首章必须处理巷外罗慎并护住收据：%s" % choice_id)
	for choice_id in ["jade_e2_witness", "jade_e2_anchor", "jade_e2_seal"]:
		var outcome := str(_choice_by_id(definitions, choice_id).get("outcome", ""))
		_expect(outcome.contains("官署") and outcome.contains("宅产"),
			"旧玉续章第二章必须写明官署判决与赔偿来源：%s" % choice_id)
	_expect(str(_choice_by_id(definitions, "jade_e3_witness").get("outcome", "")).contains(
		"官署账吏"), "旧玉见证结局不得让玩家无数值地自掏赔偿")
	var jade_anchor_end := str(_choice_by_id(definitions, "jade_e3_anchor").get("outcome", ""))
	_expect(jade_anchor_end.contains("六户") and jade_anchor_end.contains("见证人"),
		"旧玉现实结局必须由六户签收、玩家仅作见证")

	var sect_compromise := str(_choice_by_id(definitions, "sect_m4_compromise").get("outcome", ""))
	_expect(sect_compromise.contains("外院教习") and sect_compromise.contains("拒绝") and
		sect_compromise.contains("一月内"), "山门协商结局必须写清职位、拒绝权与补救期限")
	var sect_envoy := str(_choice_by_id(definitions, "sect_e1_compromise").get("outcome", ""))
	_expect(sect_envoy.contains("旧宗使者") and sect_envoy.contains("陆崖"),
		"山门续章必须区分旧宗使者与今生师长")
	var sect_bell := str(_choice_by_id(definitions, "sect_e1_escape").get("outcome", ""))
	_expect(sect_bell.contains("铃声") and sect_bell.contains("拘押印") and
		sect_bell.contains("反噬"), "执律铃必须触发拘押印并造成可见反噬")
	var sect_join := _choice_by_id(definitions, "sect_e3_compromise")
	_expect(str(sect_join.get("text", "")).contains("两代同门") and
		str(sect_join.get("outcome", "")).contains("两边名册"),
		"山门续章折中路线的选项、结果和归属必须一致")

	var family_text: Array[String] = []
	_collect_jade_visible_text(_arc_by_id(definitions, "family"), family_text)
	var family_combined := "\n".join(family_text)
	for person_name in ["沈砚秋", "宁岚", "陆闻青"]:
		_expect(family_combined.count(person_name) >= 3,
			"家世线关键人物必须使用稳定姓名：%s" % person_name)
	var family_break := str(_choice_by_id(definitions, "family_e1_break").get("outcome", ""))
	_expect(family_break.contains("拒名文书") and family_break.contains("债务人印"),
		"上世拒契路线必须说明官署改回旧账的凭据")
	for choice_id in ["family_m3_truth", "family_m3_care", "family_m3_break"]:
		_expect(str(_choice_by_id(definitions, choice_id).get("outcome", "")).contains("陆闻青"),
			"家世第三章每条路线必须先保障见证人安全：%s" % choice_id)
	var care_name := str(_choice_by_id(definitions, "family_m4_care").get("outcome", ""))
	_expect(care_name.contains("生身来处"), "养恩路线必须限定祖族姓名只记录生身来处")

	var diverted := str(_choice_by_id(definitions, "rival_m1_alliance").get("outcome", ""))
	_expect(diverted.contains("其中一队") and diverted.contains("护送契"),
		"战帖首章合作路线必须真正引走追兵并交代灵石来源")
	var burned_post := str(_choice_by_id(definitions, "rival_m1_boundaries").get("outcome", ""))
	_expect(burned_post.contains("接受") and burned_post.contains("芥蒂"),
		"江照雪必须接受改帖条件，同时对焚帖保留真实情绪")
	_expect(str(_choice_by_id(definitions, "rival_m3_boundaries").get("outcome", "")).contains(
		"名单之外"), "公开战帖证据时只能记录递信人名单之外的全文")
	var rival_main_final := str(_node_by_id(definitions, "rival_main_4").get("description", ""))
	var rival_echo_final := str(_node_by_id(definitions, "rival_echo_3").get("description", ""))
	_expect(rival_main_final.contains("优先") and rival_main_final.contains("普通对手") and
		rival_echo_final.contains("优先") and rival_echo_final.contains("普通对手"),
		"战帖两次终章都必须说清宿敌与普通对手的区别")


func _test_authored_choice_consequences(definitions: Dictionary) -> void:
	var wound_terms := ["伤", "血", "痛", "灼", "裂", "反噬", "经脉", "神识", "灵根", "周天", "受创"]
	var source_terms := ["退还", "保管单", "追回", "遗产", "继承文书", "悬赏", "护送契",
		"月俸", "祖库", "官署", "公账", "拍卖"]
	var spend_terms := ["花", "付", "支出", "买", "购", "公证"]
	for arc_value in (definitions.get("arcs", []) as Array):
		var arc: Dictionary = arc_value
		for phase in ["main", "echo"]:
			for node_value in (arc.get(phase, []) as Array):
				var node: Dictionary = node_value
				for choice_value in (node.get("choices", []) as Array):
					var choice: Dictionary = choice_value
					var deltas: Dictionary = choice.get("deltas", {})
					var outcome := str(choice.get("outcome", ""))
					if int(deltas.get("hp", 0)) < 0:
						_expect(_contains_any(outcome, wound_terms),
							"掉 HP 的剧情选择必须写明可见伤势或反噬：%s" %
								str(choice.get("id", "")))
					if int(deltas.get("spirit_stones", 0)) > 0:
						_expect(outcome.contains("灵石") and _contains_any(outcome, source_terms),
							"增加灵石的剧情选择必须写明合法具体来源：%s" %
								str(choice.get("id", "")))
					if int(deltas.get("spirit_stones", 0)) < 0:
						_expect(outcome.contains("灵石") and _contains_any(outcome, spend_terms),
							"扣除灵石的剧情选择必须写明具体用途：%s" %
								str(choice.get("id", "")))


func _contains_any(text: String, terms: Array) -> bool:
	for term_value in terms:
		if text.contains(str(term_value)):
			return true
	return false


func _arc_by_id(definitions: Dictionary, arc_id: String) -> Dictionary:
	for arc_value in (definitions.get("arcs", []) as Array):
		var arc: Dictionary = arc_value
		if str(arc.get("id", "")) == arc_id:
			return arc
	return {}


func _node_by_id(definitions: Dictionary, node_id: String) -> Dictionary:
	for arc_value in (definitions.get("arcs", []) as Array):
		var arc: Dictionary = arc_value
		for phase in ["main", "echo"]:
			for node_value in (arc.get(phase, []) as Array):
				var node: Dictionary = node_value
				if str(node.get("id", "")) == node_id:
					return node
	return {}


func _collect_jade_visible_text(value: Variant, output: Array[String]) -> void:
	if value is Array:
		for item in value as Array:
			_collect_jade_visible_text(item, output)
		return
	if not value is Dictionary:
		return
	var dictionary: Dictionary = value
	for key in dictionary.keys():
		var item: Variant = dictionary[key]
		if str(key) in ["title", "description", "text", "outcome", "resolution", "stance"] and \
				item is String:
			output.append(str(item))
		_collect_jade_visible_text(item, output)


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


func _test_obligation_closure_across_route_switches(definitions: Dictionary) -> void:
	for arc_value in (definitions.get("arcs", []) as Array):
		var arc: Dictionary = arc_value
		var branches: Array = [{"promises": {}, "debts": {}, "path": []}]
		for phase in ["main", "echo"]:
			for node_value in (arc.get(phase, []) as Array):
				var node: Dictionary = node_value
				var expanded: Array = []
				for branch_value in branches:
					for choice_value in (node.get("choices", []) as Array):
						var branch: Dictionary = (branch_value as Dictionary).duplicate(true)
						var choice: Dictionary = choice_value
						_apply_symbolic_obligations(branch, choice)
						var path: Array = branch.get("path", [])
						path.append(str(choice.get("id", "missing_choice")))
						branch["path"] = path
						expanded.append(branch)
				branches = expanded
		var unresolved_count := 0
		var example := ""
		for branch_value in branches:
			var branch: Dictionary = branch_value
			var promises: Dictionary = branch.get("promises", {})
			var debts: Dictionary = branch.get("debts", {})
			if promises.is_empty() and debts.is_empty():
				continue
			unresolved_count += 1
			if example.is_empty():
				example = "%s；承诺%s；债务%s" % [
					(branch.get("path", []) as Array), promises.keys(), debts.keys()]
		_expect(unresolved_count == 0,
			"卷章任意换线后都必须闭环义务：%s 尚有%d条路径，示例%s" % [
				str(arc.get("id", "missing_arc")), unresolved_count, example])

	var switch_paths := [
		{"arc": "jade", "choices": ["jade_m1_witness", "jade_m2_anchor", "jade_m3_anchor",
			"jade_m4_seal", "jade_e1_witness", "jade_e2_witness", "jade_e3_witness"]},
		{"arc": "sect", "choices": ["sect_m1_reform", "sect_m2_compromise", "sect_m3_compromise",
			"sect_m4_escape", "sect_e1_compromise", "sect_e2_compromise", "sect_e3_escape"]},
		{"arc": "family", "choices": ["family_m1_care", "family_m2_truth", "family_m3_care",
			"family_m4_truth", "family_e1_truth", "family_e2_truth", "family_e3_break"]},
		{"arc": "rival", "choices": ["rival_m1_alliance", "rival_m2_duel", "rival_m3_alliance",
			"rival_m4_boundaries", "rival_e1_duel", "rival_e2_alliance", "rival_e3_duel"]},
	]
	var characters: Array = definitions.get("characters", [])
	for case_value in switch_paths:
		var switch_case: Dictionary = case_value
		var arc_id := str(switch_case.get("arc", "missing_arc"))
		var state := GameStateScript.create_new_game("换线闭环-%s" % arc_id,
			737400 + switch_paths.find(case_value), [7, 7, 7, 7, 7])
		for choice_id_value in (switch_case.get("choices", []) as Array):
			var choice_id := str(choice_id_value)
			var choice := _choice_by_id(definitions, choice_id)
			NarrativeScript.apply_choice(state, {
				"story_arc_id": arc_id,
				"story_phase": "echo" if choice_id.contains("_e") else "main",
			}, choice, characters)
		var open_promises := _records_with_status(state.story.promises, "open")
		var open_debts := _records_with_status(state.story.debts, "open")
		_expect(open_promises.is_empty() and open_debts.is_empty(),
			"真实换线路径必须闭环：%s，承诺%s，债务%s" % [arc_id, open_promises, open_debts])
		if arc_id == "rival":
			_expect(_records_with_status(state.story.promises, "broken").has(
				"rival_echo_promise_aftercare"), "带伤改走宿敌线必须明确记为打破休养约定")


func _apply_symbolic_obligations(branch: Dictionary, choice: Dictionary) -> void:
	var promises: Dictionary = branch.get("promises", {})
	var debts: Dictionary = branch.get("debts", {})
	for record_value in (choice.get("promises_add", []) as Array):
		var record: Dictionary = record_value
		var record_id := str(record.get("id", ""))
		if not record_id.is_empty():
			promises[record_id] = true
	for record_value in (choice.get("debts_add", []) as Array):
		var record: Dictionary = record_value
		var record_id := str(record.get("id", ""))
		if not record_id.is_empty():
			debts[record_id] = true
	for field in ["promises_resolve", "promises_break"]:
		for record_id_value in (choice.get(field, []) as Array):
			promises.erase(str(record_id_value))
	for field in ["debts_resolve", "debts_forgive"]:
		for record_id_value in (choice.get(field, []) as Array):
			debts.erase(str(record_id_value))
	branch["promises"] = promises
	branch["debts"] = debts


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
