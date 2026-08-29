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
	_expect(bool(index_validation.get("ok", false)) and int(index_validation.get("scene_count", 0)) >= 12,
		"至少十二套试运行对话场景必须通过仓库校验")
	_test_portrait_fallback()
	_test_qingheng_flow()
	_test_xuanheng_conditions_and_check()
	_test_shuangya_combat_save_return()
	_test_lu_xiao_flow()
	_test_wen_zhaoye_flow()
	_test_song_jian_flow()
	_test_shan_weqing_flow()
	_test_qin_man_flow()
	_test_sang_xian_flow()
	_test_a_sang_flow()
	_test_du_sanqiu_flow()
	_test_feng_wendi_flow()
	_test_feng_dunjia_flow()
	_test_xiao_he_flow()
	_test_ge_wenji_flow()
	_test_lu_hanwei_flow()
	_test_bao_qiyun_flow()
	_test_zhou_yi_flow()
	_test_xiao_man_flow()
	_test_qi_lian_flow()
	_test_gu_xianting_flow()
	_test_qiao_suying_flow()
	_test_du_hengqiu_flow()
	_test_liang_zhen_flow()
	_test_mei_lan_flow()
	_test_bai_yao_flow()
	_test_xu_dongsuo_flow()
	_test_xu_weitang_flow()
	_test_lu_ling_flow()
	_test_gu_chenbi_flow()
	_test_lu_shifu_flow()
	_test_a_lu_flow()
	_test_tang_kui_flow()
	_test_chen_yusuo_flow()
	_test_meng_duan_flow()
	_test_ge_xiulin_flow()
	_test_gao_sui_flow()
	_test_du_yong_flow()
	_test_huang_ji_flow()
	_test_luo_wantang_flow()
	_test_shan_qiuhe_flow()
	_test_bo_li_flow()
	_test_tao_sao_flow()
	_test_shen_yanqiu_flow()
	_test_zhu_yao_flow()
	_test_jian_tiezhi_flow()
	_test_wen_yin_flow()
	_test_a_luo_flow()
	_test_ge_sui_flow()
	_test_yu_he_flow()
	_test_zhou_lan_flow()
	_test_liang_zhi_flow()
	_test_shao_hongli_flow()
	_test_cen_ya_flow()
	_test_fang_xiaoman_flow()
	_test_jiao_wenwei_flow()
	_test_yi_chenshuang_flow()
	_test_gu_shuying_flow()
	_test_shentu_jingjian_flow()
	_test_zhu_zhen_flow()
	_test_wen_zhaolan_flow()
	_test_cheng_yanhui_flow()
	_test_lu_liao_flow()
	_test_mu_lianchou_flow()
	_test_yu_baidi_flow()
	_test_ruan_tongchen_flow()
	_test_zhou_daiping_flow()
	_test_tao_xihuai_flow()
	_test_yin_di_flow()
	_test_luo_jin_flow()
	_test_ying_chaojian_flow()
	_test_zhang_he_flow()
	_test_liu_heting_flow()
	_test_liu_hesheng_flow()
	_test_luo_suzhi_flow()
	_test_duan_qiuhe_flow()
	_test_lu_hai_shan_flow()
	_test_xue_cunyan_flow()
	_test_he_qie_flow()
	_test_ruan_he_flow()
	_test_xie_lu_flow()
	_test_tao_xi_flow()
	_test_wen_tao_flow()
	_test_yu_qing_flow()
	_test_qu_he_flow()
	_test_liang_du_flow()
	_test_lu_he_flow()
	_test_meng_die_flow()
	_test_ji_shuangquan_flow()
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
	var lu_xiao := DialoguePortraitControllerScript.resolve("lu_xiao", "default", "protective")
	_expect(bool(lu_xiao.get("ok", false)) and
		str(lu_xiao.get("portrait_source", "")) == "portrait_master" and
		int((lu_xiao.get("presentation_profile", {}) as Dictionary).get("sensuality_max", -1)) == 0,
		"陆绡在立绘待生成阶段必须回退到主立绘路径并保持零呈现尺度")


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
	var restored_director := DialogueDirectorScript.new()
	var restored_combat := restored_director.restore(restored)
	_expect(restored_combat.get("kind") == "combat" and
		str((restored_combat.get("node", {}) as Dictionary).get("id", "")) == "sy_combat" and
		str(restored_combat.get("encounter_id", "")) == "star_echo_hunter" and
		restored_combat.get("return_context", {}) is Dictionary and
		str(((restored_combat.get("return_context", {}) as Dictionary).get("return_routes", {}) as Dictionary).get("victory", "")) == "sy_victory",
		"从存档恢复时必须停在原对话战斗节点，不能跳过战斗")
	var resumed := restored_director.resume_after_combat("victory")
	_expect(resumed.get("kind") == "line" and str(restored_director.current_node().get("id", "")) == "sy_victory",
		"战斗胜利必须返回霜鸦胜利对话节点")
	var finished := restored_director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((restored.story.flags as Dictionary).get("shuangya_survived_first_duel", false)),
		"战斗返回后的胜利效果必须继续写入剧情状态")


func _test_lu_xiao_flow() -> void:
	var state := GameStateScript.create_new_game("归潮联络者", 710004, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("lu_xiao_return_tide_rescue", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "lx_line_01",
		"陆绡对话必须从归潮八号的求救现场开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and director.choices().size() == 2,
		"陆绡对话必须提供两条救援优先级选择")
	var line := director.choose("lx_choice_consent_first")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("lu_xiao_consent_first", false)),
		"陆绡同意优先选项必须写入旗标并继续")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("lu_xiao_rescue_contacted", false)) and
		int(((state.story.relationships as Dictionary).get("lu_xiao", {}) as Dictionary).get("trust", 0)) == 2,
		"陆绡对话完成后必须写入救援联系旗标与信任关系")


func _test_wen_zhaoye_flow() -> void:
	var state := GameStateScript.create_new_game("孩子席记录员", 710005, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("wen_zhaoye_dry_tide_consent", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "wz_line_01",
		"温照野对话必须从木签与姐姐旧契号开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and director.choices().size() == 2,
		"温照野对话必须提供孩子表达与姐姐记录两条路径")
	var line := director.choose("wz_choice_child_voice")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("wen_zhaoye_child_voice_first", false)),
		"温照野儿童表达选项必须写入旗标并继续")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("wen_zhaoye_heard_and_recorded", false)) and
		int(((state.story.relationships as Dictionary).get("wen_zhaoye", {}) as Dictionary).get("respect", 0)) == 2,
		"温照野对话完成后必须保留记录旗标与尊重关系")


func _test_song_jian_flow() -> void:
	var state := GameStateScript.create_new_game("停止标记者", 710006, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("song_jian_procedure_boundary", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "sj_line_01",
		"宋鉴对话必须从停止标记与程序边界开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"宋鉴对话必须提供程序留档与亲属记忆两条路径")
	var line := director.choose("sj_choice_record_boundary")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("song_jian_boundary_recorded", false)),
		"宋鉴程序留档选项必须写入边界旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("song_jian_procedure_boundary_respected", false)) and
		int(((state.story.relationships as Dictionary).get("song_jian", {}) as Dictionary).get("trust", 0)) == 2,
		"宋鉴对话完成后必须保留边界旗标与信任关系")


func _test_shan_weqing_flow() -> void:
	var state := GameStateScript.create_new_game("留样见证者", 710007, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("shan_weqing_memory_boundary", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "sw_line_01",
		"单苇青对话必须从白布鞋与留样边界开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"单苇青对话必须提供分段封存与立即重构两条路径")
	var line := director.choose("sw_choice_seal_in_parts")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("shan_weqing_memory_sealed_in_parts", false)),
		"单苇青分段封存选项必须写入记忆旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("shan_weqing_identity_boundary_respected", false)) and
		int(((state.story.relationships as Dictionary).get("shan_weqing", {}) as Dictionary).get("respect", 0)) == 2,
		"单苇青对话完成后必须保留边界旗标与尊重关系")


func _test_qin_man_flow() -> void:
	var state := GameStateScript.create_new_game("可逆护理记录员", 710008, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("qin_man_reversible_care", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "qm_line_01",
		"秦慢对话必须从眼动图卡与本人表达开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"秦慢对话必须提供可逆护理与亲属代答两条路径")
	var line := director.choose("qm_choice_reversible_order")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("qin_man_reversible_care_order", false)),
		"秦慢可逆护理选项必须写入短令旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("qin_man_agency_recorded", false)) and
		int(((state.story.relationships as Dictionary).get("qin_man", {}) as Dictionary).get("trust", 0)) == 2,
		"秦慢对话完成后必须保留本人表达旗标与信任关系")


func _test_sang_xian_flow() -> void:
	var state := GameStateScript.create_new_game("荒原分水记录员", 710009, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("sang_xian_water_limit", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "sx_line_01",
		"桑弦对话必须从六桶水的资源上限开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"桑弦对话必须提供公开记录上限与无限征用两条路径")
	var line := director.choose("sx_choice_record_limit")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("sang_xian_water_limit_recorded", false)),
		"桑弦公开记录选项必须写入水量上限旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("sang_xian_community_limit_respected", false)) and
		int(((state.story.relationships as Dictionary).get("sang_xian", {}) as Dictionary).get("trust", 0)) == 2,
		"桑弦对话完成后必须保留社区边界旗标与信任关系")


func _test_a_sang_flow() -> void:
	var state := GameStateScript.create_new_game("蒸汽城账证见证者", 710010, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("a_sang_wage_medicine", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "as_line_01",
		"阿桑对话必须从药单与工牌印拓片开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"阿桑对话必须提供分账核对与接受亲切照顾两条路径")
	var line := director.choose("as_choice_separate_accounts")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("a_sang_accounts_separated", false)),
		"阿桑分账选项必须写入医疗工资边界旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("a_sang_wage_medicine_boundary", false)) and
		int(((state.story.relationships as Dictionary).get("a_sang", {}) as Dictionary).get("trust", 0)) == 2,
		"阿桑对话完成后必须保留分账旗标与信任关系")


func _test_du_sanqiu_flow() -> void:
	var state := GameStateScript.create_new_game("旧意愿核验员", 710011, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("du_sanqiu_old_will", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "ds_line_01",
		"杜三秋对话必须从旧意愿与七日复核开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"杜三秋对话必须提供分项建档与家属代答两条路径")
	var line := director.choose("ds_choice_keep_conditions")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("du_sanqiu_old_will_kept_separate", false)),
		"杜三秋分项建档选项必须写入旧意愿旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("du_sanqiu_agency_boundary_recorded", false)) and
		int(((state.story.relationships as Dictionary).get("du_sanqiu", {}) as Dictionary).get("trust", 0)) == 2,
		"杜三秋对话完成后必须保留旧意愿旗标与信任关系")


func _test_feng_wendi_flow() -> void:
	var state := GameStateScript.create_new_game("规程审阅员", 710012, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("feng_wendi_protocol_pen", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "fw_line_01",
		"封闻笛对话必须从编号记录与本人字段开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"封闻笛对话必须提供本人字段与统一表格两条路径")
	var line := director.choose("fw_choice_user_fields")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("feng_wendi_user_fields_kept", false)),
		"封闻笛本人字段选项必须写入规程旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("feng_wendi_human_first_protocol", false)) and
		int(((state.story.relationships as Dictionary).get("feng_wendi", {}) as Dictionary).get("trust", 0)) == 2,
		"封闻笛对话完成后必须保留人本规程旗标与信任关系")


func _test_feng_dunjia_flow() -> void:
	var state := GameStateScript.create_new_game("炉区救援记录员", 710013, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("feng_dunjia_name_board", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "fd_line_01",
		"丰敦甲对话必须从点名板与现场自治开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"丰敦甲对话必须提供工人自治与官方统一指挥两条路径")
	var line := director.choose("fd_choice_worker_led")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("feng_dunjia_worker_led_rescue", false)),
		"丰敦甲工人自治选项必须写入救援旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("feng_dunjia_responsibility_delegated", false)) and
		int(((state.story.relationships as Dictionary).get("feng_dunjia", {}) as Dictionary).get("trust", 0)) == 2,
		"丰敦甲对话完成后必须保留责任旗标与信任关系")


func _test_xiao_he_flow() -> void:
	var state := GameStateScript.create_new_game("年龄记录员", 710014, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("xiao_he_age_record", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "xh_line_01",
		"小何对话必须从实际年龄与炉工记录开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"小何对话必须提供年龄单独留档与同伴匿名保护两条路径")
	var line := director.choose("xh_choice_keep_age")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("xiao_he_actual_age_recorded", false)),
		"小何实际年龄留档选项必须写入未成年保护旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("xiao_he_worker_record_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("xiao_he", {}) as Dictionary).get("trust", 0)) == 2,
		"小何对话完成后必须保留工龄记录与信任关系")


func _test_ge_wenji_flow() -> void:
	var state := GameStateScript.create_new_game("黑账核验员", 710015, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("ge_wenji_black_ledger", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "gw_line_01",
		"葛闻机对话必须从黑脊账本的双重责任开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"葛闻机对话必须提供分账留证与整本封存两条路径")
	var line := director.choose("gw_choice_open_accounts")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("ge_wenji_black_ledger_separated", false)),
		"葛闻机分账留证选项必须写入责任拆分旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("ge_wenji_accountability_recorded", false)) and
		int(((state.story.relationships as Dictionary).get("ge_wenji", {}) as Dictionary).get("trust", 0)) == 2,
		"葛闻机对话完成后必须保留账务责任记录与信任关系")


func _test_lu_hanwei_flow() -> void:
	var state := GameStateScript.create_new_game("证据链见证者", 710016, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("lu_hanwei_evidence_chain", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "lh_line_01",
		"陆含微对话必须从重量、封条与未检内容开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"陆含微对话必须提供三方见证与官方单独开库两条路径")
	var line := director.choose("lh_choice_three_party")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("lu_hanwei_three_party_evidence", false)),
		"陆含微三方见证选项必须写入证据边界旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("lu_hanwei_evidence_chain_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("lu_hanwei", {}) as Dictionary).get("trust", 0)) == 2,
		"陆含微对话完成后必须保留证据链与信任关系")


func _test_bao_qiyun_flow() -> void:
	var state := GameStateScript.create_new_game("滤芯报价核验员", 710017, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("bao_qiyun_filter_price", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "bq_line_01",
		"包绮云对话必须从材料报价与风险押金开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"包绮云对话必须提供公开分项与延后供应账两条路径")
	var line := director.choose("bq_choice_open_price")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("bao_qiyun_price_breakdown_open", false)),
		"包绮云公开报价选项必须写入供应链旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("bao_qiyun_supply_responsibility_recorded", false)) and
		int(((state.story.relationships as Dictionary).get("bao_qiyun", {}) as Dictionary).get("trust", 0)) == 2,
		"包绮云对话完成后必须保留供应责任记录与信任关系")


func _test_zhou_yi_flow() -> void:
	var state := GameStateScript.create_new_game("街坊安全验收员", 710018, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("zhou_yi_wet_grain", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "zy_line_01",
		"周姨对话必须从湿粮拆包与分项安全验收开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"周姨对话必须提供拆粮核验与快速搬离两条路径")
	var line := director.choose("zy_choice_split_and_verify")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("zhou_yi_split_grain_and_verify", false)),
		"周姨拆粮核验选项必须写入分户安全旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("zhou_yi_separate_safety_acceptance", false)) and
		int(((state.story.relationships as Dictionary).get("zhou_yi", {}) as Dictionary).get("trust", 0)) == 2,
		"周姨对话完成后必须保留分项验收与信任关系")


func _test_xiao_man_flow() -> void:
	var state := GameStateScript.create_new_game("交班记录员", 710019, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("xiao_man_shift_handoff", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "xm_line_01",
		"小满对话必须从领炉牌与按时交班开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"小满对话必须提供按时交班与写完记录两条路径")
	var line := director.choose("xm_choice_handoff_on_time")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("xiao_man_handoff_on_time", false)),
		"小满按时交班选项必须写入轮班边界旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("xiao_man_daily_boundary_recorded", false)) and
		int(((state.story.relationships as Dictionary).get("xiao_man", {}) as Dictionary).get("trust", 0)) == 2,
		"小满对话完成后必须保留日常边界与信任关系")


func _test_qi_lian_flow() -> void:
	var state := GameStateScript.create_new_game("缺页见证者", 710020, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("qi_lian_missing_pages", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "ql_line_01",
		"祁练对话必须从缺页与自保理由开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"祁练对话必须提供记录自保动机与强迫认错两条路径")
	var line := director.choose("ql_choice_record_motive")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("qi_lian_self_protection_recorded", false)),
		"祁练记录自保动机选项必须写入证据旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("qi_lian_evidence_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("qi_lian", {}) as Dictionary).get("trust", 0)) == 2,
		"祁练对话完成后必须保留证据边界与信任关系")


func _test_gu_xianting_flow() -> void:
	var state := GameStateScript.create_new_game("窄权限见证者", 710021, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("gu_xianting_narrow_warrant", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "gx_line_01",
		"顾弦庭对话必须从临时保全的能力与边界开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"顾弦庭对话必须提供拆分权限与扩大读取两条路径")
	var line := director.choose("gx_choice_split_permissions")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("gu_xianting_permissions_split", false)),
		"顾弦庭拆分权限选项必须写入程序边界旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("gu_xianting_narrow_scope_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("gu_xianting", {}) as Dictionary).get("trust", 0)) == 2,
		"顾弦庭对话完成后必须保留窄权限与信任关系")


func _test_qiao_suying_flow() -> void:
	var state := GameStateScript.create_new_game("医疗因果记录员", 710022, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("qiao_suying_medical_causality", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "qs_line_01",
		"乔素英对话必须从药物、伤情与长期因果开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"乔素英对话必须提供分开因果与先收首月款两条路径")
	var line := director.choose("qs_choice_separate_causality")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("qiao_suying_causality_separated", false)),
		"乔素英分开因果选项必须写入医疗记录旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("qiao_suying_patient_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("qiao_suying", {}) as Dictionary).get("trust", 0)) == 2,
		"乔素英对话完成后必须保留患者边界与信任关系")


func _test_du_hengqiu_flow() -> void:
	var state := GameStateScript.create_new_game("限时裁定员", 710023, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("du_hengqiu_timed_ruling", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "dh_line_01",
		"杜衡秋对话必须从临时裁定的权限与终止时刻开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"杜衡秋对话必须提供边界化筹码与宽泛授权两条路径")
	var line := director.choose("dh_choice_bound_trust")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("du_hengqiu_bound_trust_enforced", false)),
		"杜衡秋边界化筹码选项必须写入限时裁定旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("du_hengqiu_timed_ruling_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("du_hengqiu", {}) as Dictionary).get("trust", 0)) == 2,
		"杜衡秋对话完成后必须保留限时裁定与信任关系")


func _test_liang_zhen_flow() -> void:
	var state := GameStateScript.create_new_game("救急授权核验员", 710024, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("liang_zhen_emergency_authority", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "lz_line_01",
		"梁箴对话必须从最初救急与长期续签的差异开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"梁箴对话必须提供分开条款与优先维持服务两条路径")
	var line := director.choose("lz_choice_separate_terms")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("liang_zhen_authority_terms_separated", false)),
		"梁箴分开条款选项必须写入授权边界旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("liang_zhen_emergency_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("liang_zhen", {}) as Dictionary).get("trust", 0)) == 2,
		"梁箴对话完成后必须保留救急边界与信任关系")


func _test_mei_lan_flow() -> void:
	var state := GameStateScript.create_new_game("诊区红线记录员", 710025, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("mei_lan_clinic_bandwidth", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "ml_line_01",
		"梅澜对话必须从诊区带宽与心脉机红线开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"梅澜对话必须提供提前通知与全量广播两条路径")
	var line := director.choose("ml_choice_notice_before_cut")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("mei_lan_clinic_redline_recorded", false)),
		"梅澜提前通知选项必须写入诊区红线旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("mei_lan_patient_data_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("mei_lan", {}) as Dictionary).get("trust", 0)) == 2,
		"梅澜对话完成后必须保留患者数据边界与信任关系")


func _test_bai_yao_flow() -> void:
	var state := GameStateScript.create_new_game("荒原分诊员", 710026, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("bai_yao_triage_priority", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "by_line_01",
		"白药对话必须从红黄绿分诊与有限药量开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"白药对话必须提供按伤情与按忠诚分诊两条路径")
	var line := director.choose("by_choice_triage_by_harm")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("bai_yao_harm_based_triage", false)),
		"白药按伤情选项必须写入分诊旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("bai_yao_medical_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("bai_yao", {}) as Dictionary).get("trust", 0)) == 2,
		"白药对话完成后必须保留医疗边界与信任关系")


func _test_xu_dongsuo_flow() -> void:
	var state := GameStateScript.create_new_game("织机补助", 710027, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("xu_dongsuo_piece_rate", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "xd_line_01",
		"许东梭对话必须从订单损失与女工计件边界开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"许东梭对话必须提供直付补助与厂内统一池两条路径")
	var line := director.choose("xd_choice_direct_subsidy")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("xu_dongsuo_direct_subsidy_recorded", false)),
		"许东梭直付选项必须写入女工补助旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("xu_dongsuo_wage_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("xu_dongsuo", {}) as Dictionary).get("trust", 0)) == 2,
		"许东梭对话完成后必须保留女工收入边界与信任关系")


func _test_xu_weitang_flow() -> void:
	var state := GameStateScript.create_new_game("补签说明", 710028, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("xu_weitang_informed_choice", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "xw_line_01",
		"许微棠对话必须从救济急迫与知情边界冲突开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"许微棠对话必须提供完整说明与先发急款两条路径")
	var line := director.choose("xw_choice_full_terms")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("xu_weitang_full_terms_recorded", false)),
		"许微棠完整说明选项必须写入知情说明旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("xu_weitang_informed_choice_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("xu_weitang", {}) as Dictionary).get("trust", 0)) == 2,
		"许微棠对话完成后必须保留救济与撤回边界")


func _test_lu_ling_flow() -> void:
	var state := GameStateScript.create_new_game("家属联络", 710029, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("lu_ling_family_boundary", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "ll_line_01",
		"陆菱对话必须从家庭核验与本人边界开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"陆菱对话必须提供十分钟边界与家属代办两条路径")
	var line := director.choose("ll_choice_honor_ten_minutes")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("lu_ling_ten_minute_boundary_recorded", false)),
		"陆菱尊重十分钟选项必须写入联络边界旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("lu_ling_family_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("lu_ling", {}) as Dictionary).get("trust", 0)) == 2,
		"陆菱对话完成后必须保留家属联络与本人授权边界")


func _test_gu_chenbi_flow() -> void:
	var state := GameStateScript.create_new_game("总契复审", 710030, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("gu_chenbi_covenant_boundary", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "gc_line_01",
		"顾沉璧对话必须从删改限制与城防收益开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"顾沉璧对话必须提供恢复限制与维持总契两条路径")
	var line := director.choose("gc_choice_restore_limits")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("gu_chenbi_limits_restored", false)),
		"顾沉璧恢复限制选项必须写入契约复审旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("gu_chenbi_covenant_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("gu_chenbi", {}) as Dictionary).get("trust", 0)) == 2,
		"顾沉璧对话完成后必须保留收益与身体代价分栏边界")


func _test_lu_shifu_flow() -> void:
	var state := GameStateScript.create_new_game("河工救援", 710031, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("lu_shifu_rescue_rule", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "ls_line_01",
		"鲁师傅对话必须从三息收人和绳号规程开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"鲁师傅对话必须提供规程优先与快速下潜两条路径")
	var line := director.choose("ls_choice_three_breaths")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("lu_shifu_rescue_rule_recorded", false)),
		"鲁师傅规程选项必须写入救援规则旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("lu_shifu_rescue_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("lu_shifu", {}) as Dictionary).get("trust", 0)) == 2,
		"鲁师傅对话完成后必须保留救援与取证边界")


func _test_a_lu_flow() -> void:
	var state := GameStateScript.create_new_game("粮仓报旗", 710032, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("a_lu_signal_triage", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "al_line_01",
		"阿芦对话必须从伤情分流与回旗确认开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"阿芦对话必须提供伤情优先与到达顺序两条路径")
	var line := director.choose("al_choice_harm_first")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("a_lu_harm_first_signal_recorded", false)),
		"阿芦伤情优先选项必须写入报旗分流旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("a_lu_signal_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("a_lu", {}) as Dictionary).get("trust", 0)) == 2,
		"阿芦对话完成后必须保留局部路线与匿名边界")


func _test_tang_kui_flow() -> void:
	var state := GameStateScript.create_new_game("三日急救", 710033, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("tang_kui_child_shelter", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "tk_line_01",
		"唐葵对话必须从孩子药页与临时命印边界开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"唐葵对话必须提供受限复核与公开总表两条路径")
	var line := director.choose("tk_choice_limited_review")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("tang_kui_limited_review_recorded", false)),
		"唐葵受限复核选项必须写入临时保护旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("tang_kui_child_shelter_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("tang_kui", {}) as Dictionary).get("trust", 0)) == 2,
		"唐葵对话完成后必须保留急救与反追踪边界")


func _test_chen_yusuo_flow() -> void:
	var state := GameStateScript.create_new_game("计件与照护", 710034, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("chen_yusuo_wage_care", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "cy_line_01",
		"陈玉梭对话必须从计件工资与停机账边界开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"陈玉梭对话必须提供个人补助与厂方总账两条路径")
	var line := director.choose("cy_choice_direct_wage")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("chen_yusuo_direct_wage_recorded", false)),
		"陈玉梭个人计件补助选项必须写入分栏登记旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("chen_yusuo_wage_care_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("chen_yusuo", {}) as Dictionary).get("trust", 0)) == 2,
		"陈玉梭对话完成后必须保留工资、替班与照护边界")


func _test_meng_duan_flow() -> void:
	var state := GameStateScript.create_new_game("工牌与复核", 710035, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("meng_duan_injury_wage", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "md_line_01",
		"孟端对话必须从工牌、欠薪与工伤边界开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"孟端对话必须提供分栏预付与一次性和解两条路径")
	var line := director.choose("md_choice_recorded_advance")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("meng_duan_recorded_advance", false)),
		"孟端分栏预付选项必须写入工伤记录旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("meng_duan_injury_wage_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("meng_duan", {}) as Dictionary).get("trust", 0)) == 2,
		"孟端对话完成后必须保留工牌、工资与复健边界")


func _test_ge_xiulin_flow() -> void:
	var state := GameStateScript.create_new_game("资料修复", 710036, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("ge_xiulin_data_repair", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "gx_line_01",
		"葛绣林对话必须从承认抄录与区分传播链开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"葛绣林对话必须提供链路通知与单人背责两条路径")
	var line := director.choose("gx_choice_trace_notify")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("ge_xiulin_trace_notify_recorded", false)),
		"葛绣林链路通知选项必须写入资料修复旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("ge_xiulin_data_repair_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("ge_xiulin", {}) as Dictionary).get("trust", 0)) == 2,
		"葛绣林对话完成后必须保留责任与补救边界")


func _test_gao_sui_flow() -> void:
	var state := GameStateScript.create_new_game("恒温匣遗愿", 710037, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("gao_sui_legacy_choice", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "gs_line_01",
		"高遂对话必须从遗愿与另一段脉纹边界开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"高遂对话必须提供分离同意与遗愿直读两条路径")
	var line := director.choose("gs_choice_separate_consent")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("gao_sui_separate_consent_recorded", false)),
		"高遂分离同意选项必须写入脉纹来源旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("gao_sui_legacy_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("gao_sui", {}) as Dictionary).get("trust", 0)) == 2,
		"高遂对话完成后必须保留遗愿、来源与现时同意边界")


func _test_du_yong_flow() -> void:
	var state := GameStateScript.create_new_game("身份契约", 710038, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("du_yong_identity_covenant", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "dy_line_01",
		"杜雍对话必须从稳定称呼与旧样本边界开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"杜雍对话必须提供分栏授权与统一总库两条路径")
	var line := director.choose("dy_choice_scoped_name")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("du_yong_scoped_name_recorded", false)),
		"杜雍分栏称呼选项必须写入授权范围旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("du_yong_identity_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("du_yong", {}) as Dictionary).get("trust", 0)) == 2,
		"杜雍对话完成后必须保留身份、医疗与样本边界")


func _test_huang_ji_flow() -> void:
	var state := GameStateScript.create_new_game("维修工资", 710039, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("huang_ji_maintenance_wage", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "hj_line_01",
		"黄稷对话必须从维修经验与工资边界开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"黄稷对话必须提供工资交接与延后补算两条路径")
	var line := director.choose("hj_choice_wage_handoff")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("huang_ji_wage_handoff_recorded", false)),
		"黄稷工资交接选项必须写入维护账旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("huang_ji_maintenance_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("huang_ji", {}) as Dictionary).get("trust", 0)) == 2,
		"黄稷对话完成后必须保留维修、伤情与工资边界")


func _test_luo_wantang_flow() -> void:
	var state := GameStateScript.create_new_game("可持续换班", 710040, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("luo_wantang_shift_rule", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "lw_line_01",
		"罗晚棠对话必须从休息、进食与连续班次开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"罗晚棠对话必须提供可持续换班与高压订单两条路径")
	var line := director.choose("lw_choice_sustainable_shift")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("luo_wantang_sustainable_shift_recorded", false)),
		"罗晚棠可持续换班选项必须写入轮值旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("luo_wantang_shift_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("luo_wantang", {}) as Dictionary).get("trust", 0)) == 2,
		"罗晚棠对话完成后必须保留疲劳、照护与工资边界")


func _test_shan_qiuhe_flow() -> void:
	var state := GameStateScript.create_new_game("分层停机", 710041, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("shan_qiuhe_safety_authority", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "sq_line_01",
		"单秋禾对话必须从三层停机权限开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"单秋禾对话必须提供分层停机与单点授权两条路径")
	var line := director.choose("sq_choice_layered_stop")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("shan_qiuhe_layered_stop_recorded", false)),
		"单秋禾分层停机选项必须写入安全权限旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("shan_qiuhe_safety_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("shan_qiuhe", {}) as Dictionary).get("trust", 0)) == 2,
		"单秋禾对话完成后必须保留停机、复查与结算边界")


func _test_bo_li_flow() -> void:
	var state := GameStateScript.create_new_game("城防与警报", 710042, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("bo_li_defense_signal", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "bl_line_01",
		"柏砺对话必须从拦截复验与居民警报开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"柏砺对话必须提供确定拦截与全火力两条路径")
	var line := director.choose("bl_choice_confirmed_intercept")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("bo_li_confirmed_intercept_recorded", false)),
		"柏砺确定拦截选项必须写入城防信号旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("bo_li_defense_signal_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("bo_li", {}) as Dictionary).get("trust", 0)) == 2,
		"柏砺对话完成后必须保留拦截、暴露与居民警报边界")


func _test_tao_sao_flow() -> void:
	var state := GameStateScript.create_new_game("鱼市洪灾", 710043, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("tao_sao_flood_compensation", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "ts_line_01",
		"陶嫂对话必须从屋顶搜救与授权范围开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"陶嫂对话必须提供先救人再清点与全开闸两条路径")
	var line := director.choose("ts_choice_rescue_then_loss")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("tao_sao_rescue_then_loss_recorded", false)),
		"陶嫂先救人选项必须写入洪灾分栏旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("tao_sao_rescue_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("tao_sao", {}) as Dictionary).get("trust", 0)) == 2,
		"陶嫂对话完成后必须保留撤离、闸门与赔偿边界")


func _test_shen_yanqiu_flow() -> void:
	var state := GameStateScript.create_new_game("迁舟条款", 710044, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("shen_yanqiu_migration_terms", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "sy_line_01",
		"沈砚秋对话必须从迁舟条件与真实费用开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"沈砚秋对话必须提供知情船票与优先登船两条路径")
	var line := director.choose("sy_choice_informed_ticket")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("shen_yanqiu_informed_ticket_recorded", false)),
		"沈砚秋知情船票选项必须写入迁舟条款旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("shen_yanqiu_migration_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("shen_yanqiu", {}) as Dictionary).get("trust", 0)) == 2,
		"沈砚秋对话完成后必须保留费用、医疗与撤回边界")


func _test_zhu_yao_flow() -> void:
	var state := GameStateScript.create_new_game("证人边界", 710045, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("zhu_yao_witness_boundary", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "zy_line_01",
		"祝遥对话必须从证人优先与个人选择开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"祝遥对话必须提供证人优先与证据优先两条路径")
	var line := director.choose("zy_choice_person_first")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("zhu_yao_person_first_recorded", false)),
		"祝遥证人优先选项必须写入撤签边界旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("zhu_yao_witness_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("zhu_yao", {}) as Dictionary).get("trust", 0)) == 2,
		"祝遥对话完成后必须保留证据、隐私与本人选择边界")


func _test_jian_tiezhi_flow() -> void:
	var state := GameStateScript.create_new_game("共同试钻", 710046, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("jian_tiezhi_drilling_terms", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "jt_line_01",
		"简铁枝对话必须从试钻、饮水与土地条款开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"简铁枝对话必须提供共同试钻与土地优先两条路径")
	var line := director.choose("jt_choice_shared_test")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("jian_tiezhi_shared_test_recorded", false)),
		"简铁枝共同试钻选项必须写入三方投入旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("jian_tiezhi_drilling_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("jian_tiezhi", {}) as Dictionary).get("trust", 0)) == 2,
		"简铁枝对话完成后必须保留钻井、土地与停止权边界")


func _test_wen_yin_flow() -> void:
	var state := GameStateScript.create_new_game("见青种库", 710047, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("wen_yin_seed_consent", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "wi_line_01",
		"闻茵对话必须从种子、温风与四十席边界开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"闻茵对话必须提供公开田账与提交名单两条路径")
	var line := director.choose("wi_choice_public_ledger")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("wen_yin_public_ledger_recorded", false)),
		"闻茵公开田账选项必须写入种库协作旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("wen_yin_seed_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("wen_yin", {}) as Dictionary).get("trust", 0)) == 2,
		"闻茵对话完成后必须保留种子、失踪种户与共同管理边界")


func _test_a_luo_flow() -> void:
	var state := GameStateScript.create_new_game("声音分流", 710048, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("a_luo_voice_rights", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "al2_line_01",
		"阿洛对话必须从信号分流与本人声音开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"阿洛对话必须提供分离授权与强行合并两条路径")
	var line := director.choose("al2_choice_separate_voice")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("a_luo_separate_voice_recorded", false)),
		"阿洛分离声音选项必须写入信号授权旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("a_luo_voice_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("a_luo", {}) as Dictionary).get("trust", 0)) == 2,
		"阿洛对话完成后必须保留声音、记忆与技术授权边界")


func _test_ge_sui_flow() -> void:
	var state := GameStateScript.create_new_game("灰堤闸楼", 710049, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("ge_sui_gate_duty", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "gsi_line_01",
		"葛穗对话必须从闸楼病人数量与责任链开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"葛穗对话必须提供双侧手动核验与强行断闸两条路径")
	var line := director.choose("gsi_choice_manual_check")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("ge_sui_manual_check_recorded", false)),
		"葛穗手动核验选项必须写入闸门责任旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("ge_sui_gate_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("ge_sui", {}) as Dictionary).get("trust", 0)) == 2,
		"葛穗对话完成后必须保留病人、雨障与责任核查边界")


func _test_yu_he_flow() -> void:
	var state := GameStateScript.create_new_game("热阵欠薪", 710050, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("yu_he_heat_wage", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "yh_line_01",
		"郁禾对话必须从热阵安全与工人月薪开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"郁禾对话必须提供先付工资与恢复旧债接口两条路径")
	var line := director.choose("yh_choice_wage_first")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("yu_he_wage_first_recorded", false)),
		"郁禾先付工资选项必须写入热阵账旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("yu_he_heat_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("yu_he", {}) as Dictionary).get("trust", 0)) == 2,
		"郁禾对话完成后必须保留热阵、工资与姓名接口边界")


func _test_zhou_lan_flow() -> void:
	var state := GameStateScript.create_new_game("病区复核", 710051, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("zhou_lan_care_consent", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "zl_line_01",
		"周岚对话必须从生命支持与可停止沟通开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"周岚对话必须提供窄范围护理与全面代签两条路径")
	var line := director.choose("zl_choice_narrow_care")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("zhou_lan_narrow_care_recorded", false)),
		"周岚窄范围护理选项必须写入医护授权旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("zhou_lan_care_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("zhou_lan", {}) as Dictionary).get("trust", 0)) == 2,
		"周岚对话完成后必须保留急救、声纹与本人停止权边界")


func _test_liang_zhi_flow() -> void:
	var state := GameStateScript.create_new_game("炉区欠薪", 710052, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("liang_zhi_wage_boundary", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "lz_line_01",
		"梁直对话必须从家庭过冬与已付未付边注开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"梁直对话必须提供分栏核验与一次性和解两条路径")
	var line := director.choose("lz_choice_itemized_wage")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("liang_zhi_itemized_wage_recorded", false)),
		"梁直分栏工资选项必须写入欠薪证据旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("liang_zhi_wage_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("liang_zhi", {}) as Dictionary).get("trust", 0)) == 2,
		"梁直对话完成后必须保留家庭、工资与共同证据边界")


func _test_shao_hongli_flow() -> void:
	var state := GameStateScript.create_new_game("配给契盘", 710053, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("shao_hongli_ration_debt", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "shr_line_01",
		"邵红砾对话必须从错印、济急契与配给缺口开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"邵红砾对话必须提供公开排序与立即拔针两条路径")
	var line := director.choose("shr_choice_public_order")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("shao_hongli_public_order_recorded", false)),
		"邵红砾公开排序选项必须写入配给证据旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("shao_hongli_ration_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("shao_hongli", {}) as Dictionary).get("trust", 0)) == 2,
		"邵红砾对话完成后必须保留配给、契期与本人印记边界")


func _test_cen_ya_flow() -> void:
	var state := GameStateScript.create_new_game("岑芽的饭盒", 710054, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("cen_ya_family_memory", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "cya_line_01",
		"岑芽对话必须从吃饭、回家与安全路线开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"岑芽对话必须提供留下第四双筷子与画安全路线两条路径")
	var line := director.choose("cya_choice_fourth_chopstick")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("cen_ya_fourth_chopstick_recorded", false)),
		"岑芽第四双筷子选项必须写入家庭记忆旗标")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("cen_ya_memory_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("cen_ya", {}) as Dictionary).get("trust", 0)) == 2,
		"岑芽对话完成后必须保留儿童表达、家庭照护与安全路线边界")


func _test_fang_xiaoman_flow() -> void:
	var state := GameStateScript.create_new_game("方小满的红石", 710055, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("fang_xiaoman_child_welfare", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "fxm_line_01",
		"方小满对话必须从红石、咳嗽与儿童自己表达开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"方小满对话必须提供停止抽息与儿童自主选择两条路径")
	var line := director.choose("fxm_choice_keep_red_stone")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("fang_xiaoman_current_safety_recorded", false)),
		"方小满保留红石的选项必须记录当下安全边界")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("fang_xiaoman_child_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("fang_xiaoman", {}) as Dictionary).get("trust", 0)) == 2,
		"方小满对话完成后必须保留儿童表达、照护边界与当下选择")


func _test_jiao_wenwei_flow() -> void:
	var state := GameStateScript.create_new_game("焦闻苇的三色石", 710056, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("jiao_wenwei_child_consent", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "jww_line_01",
		"焦闻苇对话必须从育幼院、三色石与孩子表达开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"焦闻苇对话必须提供公开记录与先保住孩子两条路径")
	var line := director.choose("jww_choice_public_stones")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("jiao_wenwei_child_choices_recorded", false)),
		"焦闻苇公开三色石的选项必须记录儿童表达")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("jiao_wenwei_child_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("jiao_wenwei", {}) as Dictionary).get("trust", 0)) == 2,
		"焦闻苇对话完成后必须保留儿童选择、院长照护与程序边界")


func _test_yi_chenshuang_flow() -> void:
	var state := GameStateScript.create_new_game("易沉霜的观察表", 710057, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("yi_chenshuang_care_review", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "ycs_line_01",
		"易沉霜对话必须从观察、推断与逐床复问开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"易沉霜对话必须提供分开记录与先做能力评估两条路径")
	var line := director.choose("ycs_choice_separate_records")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("yi_chenshuang_observation_recorded", false)),
		"易沉霜分开记录的选项必须保留观察与推断边界")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("yi_chenshuang_care_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("yi_chenshuang", {}) as Dictionary).get("trust", 0)) == 2,
		"易沉霜对话完成后必须保留逐床复问、护理责任与记录边界")


func _test_gu_shuying_flow() -> void:
	var state := GameStateScript.create_new_game("顾疏萤的五下敲击", 710058, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("gu_shuying_independent_choice", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "gsy_line_01",
		"顾疏萤对话必须从敲击表达、停与再测开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"顾疏萤对话必须提供停止城防用途与继续评估两条路径")
	var line := director.choose("gsy_choice_stop_city_defense")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("gu_shuying_city_defense_stopped", false)),
		"顾疏萤停止城防用途的选项必须记录本人明确表达")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("gu_shuying_choice_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("gu_shuying", {}) as Dictionary).get("trust", 0)) == 2,
		"顾疏萤对话完成后必须保留本人表达、医疗支持与城防用途边界")


func _test_shentu_jingjian_flow() -> void:
	var state := GameStateScript.create_new_game("申屠敬简的条件", 710059, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("shentu_jingjian_resource_terms", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "sjj_line_01",
		"申屠敬简对话必须从集中资源、药柜条件与风险说明开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"申屠敬简对话必须提供公开条件与先行急救两条路径")
	var line := director.choose("sjj_choice_publish_terms")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("shentu_jingjian_terms_public", false)),
		"申屠敬简公开条件的选项必须留下资金与授权链")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("shentu_jingjian_accountability_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("shentu_jingjian", {}) as Dictionary).get("trust", 0)) == 2,
		"申屠敬简对话完成后必须保留资源风险、孩子选择与责任链边界")


func _test_zhu_zhen_flow() -> void:
	var state := GameStateScript.create_new_game("祝砧的九门手调图", 710060, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("zhu_zhen_gate_responsibility", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "zz_line_01",
		"祝砧对话必须从九门检修、现场读数与个人牵挂开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"祝砧对话必须提供逐门签收与先救病患两条路径")
	var line := director.choose("zz_choice_sign_local_gate")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("zhu_zhen_local_gate_signed", false)),
		"祝砧逐门签收的选项必须记录设备动作与责任归属")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("zhu_zhen_responsibility_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("zhu_zhen", {}) as Dictionary).get("trust", 0)) == 2,
		"祝砧对话完成后必须保留现场叫停、个人牵挂与设备责任边界")


func _test_wen_zhaolan_flow() -> void:
	var state := GameStateScript.create_new_game("温照岚的薄账", 710061, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("wen_zhaolan_evidence_boundary", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "wzl_line_01",
		"温照岚对话必须从供养记录、同伴安全与证据开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"温照岚对话必须提供保密住址与先停抽取两条路径")
	var line := director.choose("wzl_choice_protect_addresses")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("wen_zhaolan_addresses_protected", false)),
		"温照岚保密住址的选项必须记录证据与受害者边界")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("wen_zhaolan_evidence_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("wen_zhaolan", {}) as Dictionary).get("trust", 0)) == 2,
		"温照岚对话完成后必须保留未成年安全、证据保护与退出边界")


func _test_cheng_yanhui_flow() -> void:
	var state := GameStateScript.create_new_game("程雁回的到期印", 710062, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("cheng_yanhui_shift_boundary", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "cyh_line_01",
		"程雁回对话必须从旧井值班、妹妹药票与有限期限开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"程雁回对话必须提供完成当班与立即退出两条路径")
	var line := director.choose("cyh_choice_finish_shift")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("cheng_yanhui_shift_end_recorded", false)),
		"程雁回完成当班的选项必须记录明确到期时间")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("cheng_yanhui_wage_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("cheng_yanhui", {}) as Dictionary).get("trust", 0)) == 2,
		"程雁回对话完成后必须保留工资、家属药票与退出边界")


func _test_lu_liao_flow() -> void:
	var state := GameStateScript.create_new_game("卢蓼的草木药", 710063, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("lu_liao_midwife_ethic", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "lla_line_01",
		"卢蓼对话必须从接生急诊、替代药与真实时限开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"卢蓼对话必须提供等待草木药与维持急诊两条路径")
	var line := director.choose("lla_choice_alternative_medicine")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("lu_liao_alternative_medicine_recorded", false)),
		"卢蓼替代药的选项必须记录病患时限与药物来源")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("lu_liao_care_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("lu_liao", {}) as Dictionary).get("trust", 0)) == 2,
		"卢蓼对话完成后必须保留病患照护、替代药与责任边界")


func _test_mu_lianchou_flow() -> void:
	var state := GameStateScript.create_new_game("穆连筹的七号棚", 710064, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("mu_lianchou_trade_accountability", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "mlc_line_01",
		"穆连筹对话必须从药棚交易、供养契与来源说明开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"穆连筹对话必须提供公开交易链与先封伤害两条路径")
	var line := director.choose("mlc_choice_publish_source")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("mu_lianchou_source_chain_recorded", false)),
		"穆连筹公开来源的选项必须记录药管、时纹与供养者损失")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("mu_lianchou_accountability_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("mu_lianchou", {}) as Dictionary).get("trust", 0)) == 2,
		"穆连筹对话完成后必须保留交易证据、病患救急与责任边界")


func _test_yu_baidi_flow() -> void:
	var state := GameStateScript.create_new_game("余白荻的听震片", 710065, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("yu_baidi_listening_work", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "ybd_line_01",
		"余白荻对话必须从听震、听力损伤与转岗开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"余白荻对话必须提供井外转岗与短班培训两条路径")
	var line := director.choose("ybd_choice_outside_listening")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("yu_baidi_outside_work_recorded", false)),
		"余白荻井外转岗的选项必须记录听力保护与工资边界")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("yu_baidi_work_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("yu_baidi", {}) as Dictionary).get("trust", 0)) == 2,
		"余白荻对话完成后必须保留听力保护、转岗工资与退出边界")


func _test_ruan_tongchen_flow() -> void:
	var state := GameStateScript.create_new_game("阮同尘的到期令", 710066, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("ruan_tongchen_due_process", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "rtc_line_01",
		"阮同尘对话必须从分类审理、止扣令与证据期限开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"阮同尘对话必须提供分案审理与总令冻结两条路径")
	var line := director.choose("rtc_choice_split_cases")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("ruan_tongchen_case_split_recorded", false)),
		"阮同尘分案选项必须记录本人、机构与待核证据边界")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("ruan_tongchen_due_process_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("ruan_tongchen", {}) as Dictionary).get("trust", 0)) == 2,
		"阮同尘对话完成后必须保留最低保障、程序期限与责任拆分")


func _test_zhou_daiping_flow() -> void:
	var state := GameStateScript.create_new_game("周黛瓶的两枚灵石", 710067, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("zhou_daiping_filter_witness", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "zdp_line_01",
		"周黛瓶对话必须从收款、喘药与死者同意边界开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"周黛瓶对话必须提供分开立案与退钱优先两条路径")
	var line := director.choose("zdp_choice_separate_receipt")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("zhou_daiping_receipt_boundary_recorded", false)),
		"周黛瓶分案选项必须记录收款、风险费和死者证词边界")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("zhou_daiping_witness_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("zhou_daiping", {}) as Dictionary).get("trust", 0)) == 2,
		"周黛瓶对话完成后必须保留急救、家属证词与补签责任边界")


func _test_tao_xihuai_flow() -> void:
	var state := GameStateScript.create_new_game("陶细槐的路线木片", 710068, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("tao_xihuai_runner_boundary", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "txh_line_01",
		"陶细槐对话必须从十七岁跑腿、知情范围与车号开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"陶细槐对话必须提供停工结薪与陪同继续两条路径")
	var line := director.choose("txh_choice_stop_with_pay")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("tao_xihuai_stop_with_pay_recorded", false)),
		"陶细槐停工选项必须记录已完成工钱与未送纸袋封存")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("tao_xihuai_runner_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("tao_xihuai", {}) as Dictionary).get("trust", 0)) == 2,
		"陶细槐对话完成后必须保留未成年保护、工资与知情边界")


func _test_yin_di_flow() -> void:
	var state := GameStateScript.create_new_game("尹荻的两栏记录", 710069, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("yin_di_medical_boundary", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "ydi_line_01",
		"尹荻对话必须从手术救命与授权造假两栏开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"尹荻对话必须提供医疗分栏与公开追责两条路径")
	var line := director.choose("ydi_choice_split_medical_record")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("yin_di_medical_record_split", false)),
		"尹荻分栏选项必须记录手术结果、当下观点与旧授权差异")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("yin_di_medical_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("yin_di", {}) as Dictionary).get("trust", 0)) == 2,
		"尹荻对话完成后必须保留医疗主体性、当前用药与机构责任边界")


func _test_luo_jin_flow() -> void:
	var state := GameStateScript.create_new_game("骆谨的三个孔", 710070, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("luo_jin_hearing_boundary", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "ljn_line_01",
		"骆谨对话必须从听见、拒绝与回问三个孔开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"骆谨对话必须提供恢复拒绝页与保护急救者两条路径")
	var line := director.choose("ljn_choice_restore_refusal")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("luo_jin_refusal_restored", false)),
		"骆谨恢复拒绝页选项必须区分药效、副作用、拒绝与后续拒赔")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("luo_jin_hearing_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("luo_jin", {}) as Dictionary).get("trust", 0)) == 2,
		"骆谨对话完成后必须保留听力辅助、拒绝记录与补偿责任边界")


func _test_ying_chaojian_flow() -> void:
	var state := GameStateScript.create_new_game("应朝俭的十二只罐", 710071, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("ying_chaojian_accountability", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "ycj_line_01",
		"应朝俭对话必须从验印、验人与十二只应急罐开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"应朝俭对话必须提供公开负载表与封存验签印两条路径")
	var line := director.choose("ycj_choice_open_load_table")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("ying_chaojian_load_table_opened", false)),
		"应朝俭公开负载表选项必须记录库存、伤者与城防余量的分栏")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("ying_chaojian_accountability_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("ying_chaojian", {}) as Dictionary).get("trust", 0)) == 2,
		"应朝俭对话完成后必须保留公开流水、继续值守与外部复核边界")


func _test_zhang_he_flow() -> void:
	var state := GameStateScript.create_new_game("章禾的旧账页", 710072, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("zhang_he_archive_boundary", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "zhe_line_01",
		"章禾对话必须从十七年守库与九十日临时条款开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"章禾对话必须提供恢复临时条款与公开灰池两条路径")
	var line := director.choose("zhe_choice_restore_temporary_terms")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("zhang_he_temporary_terms_restored", false)),
		"章禾恢复临时条款选项必须记录公共储备、个人尾差、工资与待认领款分栏")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("zhang_he_archive_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("zhang_he", {}) as Dictionary).get("trust", 0)) == 2,
		"章禾对话完成后必须保留档案、期限与缺席者记录边界")


func _test_liu_heting_flow() -> void:
	var state := GameStateScript.create_new_game("柳鹤汀的结清木签", 710073, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("liu_heting_wage_boundary", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "lht_line_01",
		"柳鹤汀对话必须从结清工资与六年浅眠开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"柳鹤汀对话必须提供断已清工资线与有条件缓三天两条路径")
	var line := director.choose("lht_choice_cut_paid_lines")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("liu_heting_paid_lines_cut", false)),
		"柳鹤汀断线选项必须记录清账事实、本地开关与不转嫁夜班责任")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("liu_heting_wage_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("liu_heting", {}) as Dictionary).get("trust", 0)) == 2,
		"柳鹤汀对话完成后必须保留清账、退出和替代供给边界")


func _test_liu_hesheng_flow() -> void:
	var state := GameStateScript.create_new_game("柳鹤生的本名工牌", 710074, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("liu_hesheng_identity_boundary", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "lhs_line_01",
		"柳鹤生对话必须从活人死籍、母亲的药与旧屋保护开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"柳鹤生对话必须提供恢复本人服务与切断死籍新约两条路径")
	var line := director.choose("lhs_choice_restore_services_first")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("liu_hesheng_services_restored", false)),
		"柳鹤生恢复服务选项必须记录本名、工龄、母亲代领权与旧屋分案")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("liu_hesheng_identity_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("liu_hesheng", {}) as Dictionary).get("trust", 0)) == 2,
		"柳鹤生对话完成后必须保留身份、劳动、住房与城市合同边界")


func _test_luo_suzhi_flow() -> void:
	var state := GameStateScript.create_new_game("罗素织的门契", 710075, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("luo_suzhi_housing_boundary", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "lsz_line_01",
		"罗素织对话必须从旧屋、修缮与自动换锁风险开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"罗素织对话必须提供现状保护与中立租金匣两条路径")
	var line := director.choose("lsz_choice_hold_housing")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("luo_suzhi_housing_protected", false)),
		"罗素织现状保护选项必须记录三户居住、修缮与押金分案")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("luo_suzhi_housing_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("luo_suzhi", {}) as Dictionary).get("trust", 0)) == 2,
		"罗素织对话完成后必须保留身份纠正、现住保护与产权分案边界")


func _test_duan_qiuhe_flow() -> void:
	var state := GameStateScript.create_new_game("段秋禾的代领纸", 710076, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("duan_qiuhe_proxy_boundary", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "dqh_line_01",
		"段秋禾对话必须从完整录音、基础药与失联维护费开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"段秋禾对话必须提供恢复完整记录与封存家庭证明两条路径")
	var line := director.choose("dqh_choice_restore_full_record")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("duan_qiuhe_full_record_restored", false)),
		"段秋禾恢复记录选项必须限定基础药代领并冻结失联维护费与新债")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("duan_qiuhe_proxy_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("duan_qiuhe", {}) as Dictionary).get("trust", 0)) == 2,
		"段秋禾对话完成后必须保留原意、代领和代理权限边界")


func _test_lu_hai_shan_flow() -> void:
	var state := GameStateScript.create_new_game("陆还山的床边一班", 710077, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("lu_hai_shan_care_boundary", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "lhsn_line_01",
		"陆还山对话必须从师徒识别、撤下脉线与不代领开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"陆还山对话必须提供先撤脉与独立计薪补班两条路径")
	var line := director.choose("lhsn_choice_remove_pulse_first")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("lu_hai_shan_pulse_removed_first", false)),
		"陆还山撤脉选项必须保留身份线索、表达评估与财产暂停的边界")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("lu_hai_shan_care_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("lu_hai_shan", {}) as Dictionary).get("trust", 0)) == 2,
		"陆还山对话完成后必须保留照护工时、师徒关系与代领权限边界")


func _test_xue_cunyan_flow() -> void:
	var state := GameStateScript.create_new_game("薛存砚的慢回答", 710078, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("xue_cunyan_slow_consent", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "xcy_line_01",
		"薛存砚对话必须从慢回答、撤下脉线与不代答开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"薛存砚对话必须提供慢速眼动评估与限制旧工牌两条路径")
	var line := director.choose("xcy_choice_slow_eye_assessment")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("xue_cunyan_slow_assessment_started", false)),
		"薛存砚慢速评估选项必须把陆还山记忆限定为线索而非本人同意")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("xue_cunyan_slow_consent_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("xue_cunyan", {}) as Dictionary).get("trust", 0)) == 2,
		"薛存砚对话完成后必须保留慢回答、本人同意与照护边界")


func _test_he_qie_flow() -> void:
	var state := GameStateScript.create_new_game("贺箧的纸房清单", 710079, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("he_qie_pulp_room_boundary", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "hqi_line_01",
		"贺箧对话必须从六十七岁老吏、配纸事实与有限知情开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"贺箧对话必须提供记录有限知情与保留善意陈述两条路径")
	var line := director.choose("hqi_choice_record_limited_knowledge")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("he_qie_limited_knowledge_recorded", false)),
		"贺箧有限知情选项必须把亲手配纸、见过的印和未看过的内容分开")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("he_qie_fact_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("he_qie", {}) as Dictionary).get("trust", 0)) == 2,
		"贺箧对话完成后必须保留劳动事实、机构授权与替罪羊边界")


func _test_ruan_he_flow() -> void:
	var state := GameStateScript.create_new_game("阮禾的池边辨认", 710080, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("ruan_he_pool_boundary", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "rhe_line_01",
		"阮禾对话必须从三结细线、池边热量与家属选择开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"阮禾对话必须提供知情短接与保留家属安置两条路径")
	var line := director.choose("rhe_choice_record_informed_bridge")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("ruan_he_informed_bridge_recorded", false)),
		"阮禾知情短接选项必须保留期限、替代热源与家属知情边界")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("ruan_he_family_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("ruan_he", {}) as Dictionary).get("trust", 0)) == 2,
		"阮禾对话完成后必须保留家属辨认、公共热源与死者安置边界")


func _test_xie_lu_flow() -> void:
	var state := GameStateScript.create_new_game("谢芦的临时医疗门", 710081, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("xie_lu_medical_entry", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "xlu_line_01",
		"谢芦对话必须从身份门误判、本人点头与医疗范围开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"谢芦对话必须提供窄权限医疗凭证与保留机械出口两条路径")
	var line := director.choose("xlu_choice_narrow_medical_pass")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("xie_lu_narrow_medical_pass", false)),
		"谢芦窄权限凭证选项必须把医疗、身份、债务与调查字段分开")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("xie_lu_medical_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("xie_lu", {}) as Dictionary).get("trust", 0)) == 2,
		"谢芦对话完成后必须保留本人确认、机械退出与医疗范围边界")


func _test_tao_xi_flow() -> void:
	var state := GameStateScript.create_new_game("陶熹的触点确认", 710082, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("tao_xi_identity_touch", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "txi_line_01",
		"陶熹对话必须从旧执业号、触点停止与拒绝同名归并开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"陶熹对话必须提供窄范围暂用身份与保留触点证据两条路径")
	var line := director.choose("txi_choice_narrow_temporary_identity")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("tao_xi_narrow_identity_signed", false)),
		"陶熹窄范围身份选项必须把医疗通行与财产亲属权限分开")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("tao_xi_identity_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("tao_xi", {}) as Dictionary).get("trust", 0)) == 2,
		"陶熹对话完成后必须保留触点表达、停止动作与同名归并边界")


func _test_wen_tao_flow() -> void:
	var state := GameStateScript.create_new_game("闻桃的两张页", 710083, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("wen_tao_scope_boundary", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "wta_line_01",
		"闻桃对话必须从工会页、诊宫页与雇主读取边界开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"闻桃对话必须提供分栏读取与记录系统缺陷两条路径")
	var line := director.choose("wta_choice_split_medical_and_wage")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("wen_tao_pages_split_by_scope", false)),
		"闻桃分栏选项必须把伤情、药量、工资与雇主读取范围分开")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("wen_tao_scope_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("wen_tao", {}) as Dictionary).get("trust", 0)) == 2,
		"闻桃对话完成后必须保留医疗检验、工会工资与雇主权限边界")


func _test_yu_qing_flow() -> void:
	var state := GameStateScript.create_new_game("郁青的急救班", 710084, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("yu_qing_shift_boundary", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "yuq_line_01",
		"郁青对话必须从手腕工伤、急救班与旧工资边界开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"郁青对话必须提供先付急救班与先认培训工时两条路径")
	var line := director.choose("yuq_choice_pay_urgent_shift")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("yu_qing_urgent_shift_paid", false)),
		"郁青急救班选项必须先结算工时并保留家庭隐私边界")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("yu_qing_shift_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("yu_qing", {}) as Dictionary).get("trust", 0)) == 2,
		"郁青对话完成后必须保留一桌一人、替换记录与工伤者免展示边界")


func _test_qu_he_flow() -> void:
	var state := GameStateScript.create_new_game("屈禾的共同遗物", 710085, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("qu_he_shared_relic", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "qhe_line_01",
		"屈禾对话必须从襁褓、药布与生活记忆证据开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"屈禾对话必须提供药布核验与共同保管两条路径")
	var line := director.choose("qhe_choice_test_medicine_cloth")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("qu_he_relic_evidence_tested", false)),
		"屈禾药布核验选项必须记录双方记忆并保留外部证据")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("qu_he_relic_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("qu_he", {}) as Dictionary).get("trust", 0)) == 2,
		"屈禾对话完成后必须保留共同遗物、供能与家庭关系边界")


func _test_liang_du_flow() -> void:
	var state := GameStateScript.create_new_game("梁度的冲突许可", 710086, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("liang_du_conflict_permit", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "ldu_line_01",
		"梁度对话必须从旧私章、复制授权器与责任分离开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"梁度对话必须提供完整保全与收窄签章范围两条路径")
	var line := director.choose("ldu_choice_seize_old_records")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("liang_du_records_preserved", false)),
		"梁度完整保全选项必须同时保留旧章、值班簿、许可和复制器证据")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("liang_du_responsibility_split_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("liang_du", {}) as Dictionary).get("trust", 0)) == 2,
		"梁度对话完成后必须保留签章归属、设备日志与实际操作人边界")


func _test_lu_he_flow() -> void:
	var state := GameStateScript.create_new_game("陆禾不是行李", 710087, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("lu_he_natural_person", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "lhe_line_01",
		"陆禾对话必须先暂停随行物归类并建立儿童保护边界")
	var line := director.advance()
	_expect(line.get("kind") == "line" and
		str((line.get("node", {}) as Dictionary).get("id", "")) == "lhe_line_02",
		"陆禾对话必须让孩子自己的节律与名字进入记录")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"陆禾对话必须提供独立姓名册与暂保母子依附两条安全路径")
	var finished := director.choose("lhe_choice_separate_identity")
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("lu_he_independent_identity_opened", false)) and
		bool((state.story.flags as Dictionary).get("lu_he_natural_person_boundary_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("lu_he", {}) as Dictionary).get("trust", 0)) == 2,
		"陆禾对话完成后必须保留儿童独立身份、期限与母子保护边界")


func _test_meng_die_flow() -> void:
	var state := GameStateScript.create_new_game("孟迭每天管哪一页", 710088, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("meng_die_archive_scope", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "mdi_line_01",
		"孟迭对话必须从单页规程、跨页冲突与开柜范围开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"孟迭对话必须提供分册读取与独立钥匙保全两条路径")
	var line := director.choose("mdi_choice_split_pages")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("meng_die_pages_split_by_scope", false)),
		"孟迭分册选项必须记录用途、页码、开柜人和归还时刻")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("meng_die_archive_scope_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("meng_die", {}) as Dictionary).get("trust", 0)) == 2,
		"孟迭对话完成后必须保留原件、副本、钥匙与读取范围边界")


func _test_ji_shuangquan_flow() -> void:
	var state := GameStateScript.create_new_game("纪双泉的停针", 710089, [7, 7, 7, 7, 7])
	var director := DialogueDirectorScript.new()
	var first := director.start("ji_shuangquan_stop_rule", state)
	_expect(first.get("kind") == "line" and
		str((first.get("node", {}) as Dictionary).get("id", "")) == "jsq_line_01",
		"纪双泉对话必须从异常风险、停针七分钟与不以时限逼同意开始")
	var choice := director.advance()
	_expect(choice.get("kind") == "choice" and (choice.get("choices", []) as Array).size() == 2,
		"纪双泉对话必须提供复测脉搏与并行加固两条路径")
	var line := director.choose("jsq_choice_wait_for_heartbeat")
	_expect(line.get("kind") == "line" and
		bool((state.story.flags as Dictionary).get("ji_shuangquan_pause_and_recheck", false)),
		"纪双泉复测选项必须分别记录身体回答、救援时限与替代器材")
	var finished := director.advance()
	_expect(finished.get("kind") == "finished" and
		bool((state.story.flags as Dictionary).get("ji_shuangquan_stop_rule_preserved", false)) and
		int(((state.story.relationships as Dictionary).get("ji_shuangquan", {}) as Dictionary).get("trust", 0)) == 2,
		"纪双泉对话完成后必须保留停针、复测与三方在场边界")


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
