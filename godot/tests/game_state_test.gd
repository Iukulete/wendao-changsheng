extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const CultivationScript = preload("res://scripts/cultivation_system.gd")
const ReincarnationScript = preload("res://scripts/reincarnation_system.gd")

var failures: Array[String] = []


func _init() -> void:
	var state := GameStateScript.create_new_game("照世者", 20260716, [7, 7, 8, 6, 7])
	_expect(int(state.get("schema_version", 0)) == 2, "新游戏必须使用 v2 状态")
	_expect(state.has("legacy") and state.has("world") and state.has("inventory") and state.has("story"),
		"v2 状态必须覆盖轮回、世界、物品与剧情")
	_expect(str(state.player.realm_id) == "mortal" and int(state.player.realm_index) == 0,
		"新生必须从稳定境界 ID 开始")
	_expect((state.player.path as Dictionary).size() == 6, "道途必须包含六个可持续维度")

	var first_gain: Dictionary = CultivationScript.meditate(state, 50)
	_expect(bool(first_gain.get("ok", false)) and int(first_gain.get("gain", 0)) > 0,
		"修炼必须推进修为")
	_expect(int(state.player.age) == 17 and int(state.world.year) == 2,
		"修炼必须同时推进角色寿元与世界时间")
	_expect((state.world.factions as Array).size() >= 3 and (state.world.npcs as Array).size() >= 6,
		"第一年必须生成可持续演化的势力与人物")
	_expect(state.world.has("last_year_summary"), "修炼推进的年份必须写入世界年史")

	var mode_state := GameStateScript.create_new_game("行功者", 20260721, [7, 7, 7, 7, 7])
	mode_state.player.level = 9
	mode_state.player.hp = 60
	var steady_preview: Dictionary = CultivationScript.meditation_preview(mode_state, "steady")
	var rush_preview: Dictionary = CultivationScript.meditation_preview(mode_state, "rush")
	var insight_preview: Dictionary = CultivationScript.meditation_preview(mode_state, "insight")
	_expect(int(rush_preview.minimum_gain) > int(steady_preview.minimum_gain) and
		int(rush_preview.hp_cost) > 0 and int(insight_preview.dao_heart_gain) == 1,
		"三种运功法必须在预览中呈现真实不同的收益与代价")
	var hp_before_steady := int(mode_state.player.hp)
	var steady_result: Dictionary = CultivationScript.meditate(mode_state, 50, "steady")
	_expect(int(mode_state.player.hp) > hp_before_steady and int(steady_result.hp_recovered) > 0,
		"守一周天必须实际恢复受损气血")
	var hp_before_rush := int(mode_state.player.hp)
	var rush_result: Dictionary = CultivationScript.meditate(mode_state, 50, "rush")
	_expect(int(rush_result.gain) > int(steady_result.gain) and
		int(mode_state.player.hp) < hp_before_rush,
		"燃血冲脉必须用可见气血成本换取更高修为")
	var heart_before := int(mode_state.player.dao_heart)
	var insight_result: Dictionary = CultivationScript.meditate(mode_state, 50, "insight")
	_expect(int(insight_result.dao_heart_gain) == 1 and int(mode_state.player.dao_heart) == heart_before + 1,
		"引潮悟道必须真实增长道心，而非只有文案差异")

	state.player.level = 9
	state.player.exp = 9999
	var ready: Dictionary = CultivationScript.can_breakthrough(state.player)
	_expect(bool(ready.get("ok", false)), "九层且积累充足时应允许突破")
	var breakthrough: Dictionary = CultivationScript.attempt_breakthrough(state, 1)
	_expect(bool(breakthrough.get("success", false)), "确定性低点数应突破成功")
	_expect(str(state.player.realm_id) == "qi_refining" and str(state.player.realm) == "炼气期",
		"突破必须同时更新稳定 ID 与展示名")

	state.player.path.insight = 28
	state.player.total_events = 24
	state.player.age = state.player.lifespan
	_expect(CultivationScript.is_dead(state), "道祖前寿元耗尽必须结束当前一世")
	var closed: Dictionary = ReincarnationScript.close_life(state, "寿元耗尽")
	_expect(bool(closed.get("ok", false)), "死亡必须形成前世记录")
	_expect((state.legacy.past_lives as Array).size() == 1, "前世记录必须进入持久轮回状态")
	_expect(str(state.legacy.past_lives[0].dao_id) == "insight", "最强道途维度必须塑造前世道痕")
	var world_year_before := int(state.world.year)
	var era_before := str(state.current_era_id)
	var next_life: Dictionary = ReincarnationScript.begin_next_life(state, "问镜")
	_expect(bool(next_life.get("ok", false)), "已封存的一世必须能进入下一世")
	_expect(int(state.generation) == 2 and int(state.legacy.generation) == 2,
		"轮回代数必须一致推进")
	_expect(int(state.world.year) > world_year_before, "转世期间世界必须继续前进")
	_expect(str(state.current_era_id) != era_before and
		str(state.current_era) == str(GameStateScript.ERA_NAMES[state.current_era_id]),
		"轮回必须自然推进纪元，不能依赖产品界面的开发切换按钮")
	_expect((state.world.annual_summaries as Array).size() > 1,
		"轮回间隔必须逐年演算世界，而不是只修改年份")
	_expect((state.legacy.inherited_echoes as Array).size() > 0, "下一世必须继承可解释的前世回响")
	_expect(not bool(state.life_closed), "下一世开始后生命状态必须重新打开")

	var migrated := GameStateScript.ensure_v2({
		"current_era": "星穹道网纪",
		"player": {
			"name": "旧档客", "realm": "筑基期", "level": 3, "exp": 30,
			"hp": 80, "max_hp": 100, "mp": 40, "max_mp": 50,
			"age": 30, "lifespan": 200, "spirit_stones": 12, "pills": 1,
			"karma": 2, "dao_heart": 1, "reputation": 0, "enmity": 0,
			"roots": [5, 5, 5, 5, 5],
		},
		"recent_memories": ["旧档记忆"], "feedback": "旧档仍在。",
	})
	_expect(int(migrated.schema_version) == 2 and str(migrated.current_era_id) == "star_network",
		"v1 状态必须无损升级时代 ID")
	_expect(str(migrated.player.realm_id) == "foundation", "v1 境界展示名必须迁移为稳定 ID")
	var migrated_short_name := GameStateScript.ensure_v2({
		"current_era": "古典修仙纪",
		"player": {"name": "短名旧档", "realm": "炼气", "roots": [5, 5, 5, 5, 5]},
	})
	_expect(str(migrated_short_name.player.realm_id) == "qi_refining",
		"旧版境界短名也必须迁移为稳定 ID")
	var migrated_overflow := GameStateScript.ensure_v2({
		"current_era": "古典修仙纪",
		"player": {"name": "十层旧档", "realm": "凡人", "level": 10,
			"roots": [5, 5, 5, 5, 5]},
	})
	_expect(str(migrated_overflow.player.realm_id) == "qi_refining" and
		int(migrated_overflow.player.level) == 1,
		"v1 超额层数必须折算到下一境界，不能被新版拒绝")

	var ended_state := GameStateScript.create_new_game("已逝者", 91, [6, 6, 6, 6, 6])
	ended_state.player.level = 9
	ended_state.player.exp = 9999
	ended_state.player.age = ended_state.player.lifespan
	var realm_before := str(ended_state.player.realm_id)
	var forbidden_breakthrough: Dictionary = CultivationScript.attempt_breakthrough(ended_state, 1)
	_expect(not bool(forbidden_breakthrough.get("ok", true)) and
		str(forbidden_breakthrough.get("code", "")) == "life_ended",
		"寿尽后不得再靠突破复活")
	_expect(str(ended_state.player.realm_id) == realm_before, "被拒绝的死后突破不得改变境界")
	ended_state.player.age = 16
	ended_state.life_closed = true
	var closed_breakthrough: Dictionary = CultivationScript.attempt_breakthrough(ended_state, 1)
	_expect(str(closed_breakthrough.get("code", "")) == "life_ended",
		"已经封存的一世不得继续突破")

	if failures.is_empty():
		print("GAME_STATE_TEST_OK: v2 state, cultivation, lifespan and reincarnation passed")
		quit(0)
	else:
		for failure in failures:
			push_error("GAME_STATE_TEST_FAILED: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
