extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const DialogueRepositoryScript = preload("res://scripts/dialogue/dialogue_repository.gd")
const DialogueDirectorScript = preload("res://scripts/dialogue/dialogue_director.gd")
const DialogueEffectExecutorScript = preload("res://scripts/dialogue/effect_executor.gd")
const DialoguePortraitControllerScript = preload("res://scripts/dialogue/portrait_controller.gd")
const DialogueSaveAdapterScript = preload("res://scripts/dialogue/story_save_adapter.gd")
const LegacyEventAdapterScript = preload("res://scripts/dialogue/legacy_event_adapter.gd")

var failures: Array[String] = []


func _init() -> void:
	var index_validation := DialogueRepositoryScript.validate_index()
	_expect(bool(index_validation.get("ok", false)) and int(index_validation.get("scene_count", 0)) == 3,
		"三套试运行对话场景必须通过仓库校验")
	_test_portrait_fallback()
	_test_qingheng_flow()
	_test_xuanheng_conditions_and_check()
	_test_shuangya_combat_save_return()
	_test_legacy_adapter()
	if failures.is_empty():
		print("DIALOGUE_SYSTEM_TEST_OK: repository, conditions, effects, portraits, combat return and save round-trip passed")
		quit(0)
	else:
		for failure in failures:
			push_error("DIALOGUE_SYSTEM_TEST_FAILED: %s" % failure)
		quit(1)


func _test_portrait_fallback() -> void:
	var qingheng := DialoguePortraitControllerScript.resolve("qingheng_zhenren", "default", "stern")
	_expect(bool(qingheng.get("ok", false)) and
		str(qingheng.get("portrait_source", "")) == "portrait_master" and
		str(qingheng.get("portrait_path", "")).begins_with("res://art/portraits/"),
		"待生成对话胸像必须安全回退到已登记的主立绘")
	var minor_safe := DialoguePortraitControllerScript.resolve("a_cen_sister", "default", "soft")
	var profile: Dictionary = minor_safe.get("presentation_profile", {})
	_expect(int(profile.get("sensuality_max", -1)) == 0 and not bool(profile.get("adult_only", true)),
		"未知年龄角色必须保持零卖肉上限")


func _test_qingheng_flow() -> void:
	var state := GameStateScript.create_new_game("试运行者", 710001, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("qingheng_first_meeting", state)
	_expect(bool(first.get("ok", false)) and first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "qh_line_01",
		"清蘅试运行必须从第一句对话开始")
	var choice_node := director.advance()
	_expect(choice_node.get("kind") == "choice" and director.choices().size() == 2,
		"清蘅试运行必须进入二选一节点")
	var chosen := director.choose("qh_choice_honest")
	_expect(chosen.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("qingheng_first_answer_honest", false)),
		"清蘅诚实选项必须写入旗标并继续对话")
	var relation_before := int(((state.story.relationships as Dictionary).get("qingheng_zhenren", {}) as Dictionary).get("respect", 0))
	var advance_result := director.advance()
	_expect(advance_result.get("kind") == "finished" and relation_before == 2,
		"清蘅场景结束时关系效果必须只应用一次")
	var duplicate := DialogueEffectExecutorScript.apply_effects(state,
		[{"type": "relation_delta", "character_id": "qingheng_zhenren", "stat": "respect", "delta": 9}],
		"test:duplicate")
	var repeated := DialogueEffectExecutorScript.apply_effects(state,
		[{"type": "relation_delta", "character_id": "qingheng_zhenren", "stat": "respect", "delta": 9}],
		"test:duplicate")
	_expect(bool(duplicate.get("applied", false)) and not bool(repeated.get("applied", true)) and
		int(((state.story.relationships as Dictionary).get("qingheng_zhenren", {}) as Dictionary).get("respect", 0)) == 11,
		"相同效果事务在重入时不得重复结算")


func _test_xuanheng_conditions_and_check() -> void:
	var state := GameStateScript.create_new_game("问询者", 710002, [7, 7, 7, 7, 7])
	state.story.flags["saw_hidden_jade"] = true
	state.player.reputation = 2
	var director := DialogueDirectorScript.new()
	director.start("xuanheng_first_inquiry", state)
	director.advance()
	director.advance()
	var choices := director.choices()
	_expect(choices.size() == 2 and bool((choices[1] as Dictionary).get("available", false)),
		"满足旗标与声望后玄衡隐藏选项必须可见")
	var result := director.choose("xh_choice_use_rule")
	_expect(result.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("challenged_xuanheng_authority", false)),
		"玄衡隐藏选项必须走到规则反问结局")


func _test_shuangya_combat_save_return() -> void:
	var state := GameStateScript.create_new_game("截路者", 710003, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	director.start("shuangya_first_intercept", state)
	director.advance()
	var request := director.choose("sy_choice_refuse")
	_expect(request.get("kind") == "combat" and str(request.get("encounter_id", "")) == "star_echo_hunter",
		"霜鸦选择必须把 encounter 交给战斗桥")
	var saved := DialogueSaveAdapterScript.capture(state)
	var restored := GameStateScript.create_new_game("恢复者", 710004, [7, 7, 7, 7, 7])
	DialogueSaveAdapterScript.restore(restored, saved)
	_expect(DialogueSaveAdapterScript.normalize(restored).dialogue.mode == "combat" and
		DialogueSaveAdapterScript.normalize(restored).dialogue.combat_return_context is Dictionary,
		"存档往返必须保留对话战斗返回上下文")
	var resumed := director.resume_after_combat("victory")
	_expect(resumed.get("kind") == "line" and str(director.current_node().get("id", "")) == "sy_victory",
		"战斗胜利必须返回霜鸦胜利对话节点")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("shuangya_survived_first_duel", false)),
		"战斗返回后的胜利效果必须继续写入剧情状态")


func _test_legacy_adapter() -> void:
	var scene := LegacyEventAdapterScript.to_dialogue_scene({
		"id": "legacy_test",
		"title": "旧事件",
		"character_id": "protagonist",
		"description": "旧事件描述",
		"choices": [{"id": "a", "text": "选择甲", "outcome": "结果甲"},
			{"id": "b", "text": "选择乙", "outcome": "结果乙"}],
	})
	var validation := DialogueRepositoryScript.validate_scene(scene)
	_expect(bool(validation.get("ok", false)), "旧事件适配器必须产出可校验的新对话图")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
