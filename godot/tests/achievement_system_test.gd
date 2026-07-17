extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const AchievementSystemScript = preload("res://scripts/achievement_system.gd")

var failures: Array[String] = []


func _init() -> void:
	var validation: Dictionary = AchievementSystemScript.validate_definitions()
	_expect(bool(validation.get("ok", false)) and int(validation.get("achievement_count", 0)) == 16 and
		int(validation.get("weapon_count", 0)) == 16,
		"玉藏兵数据必须完整定义16项成就和16件永久玉兵")
	var state := GameStateScript.create_new_game("藏兵主", 858585, [7, 7, 7, 7, 7])
	AchievementSystemScript.normalize(state)
	_expect(AchievementSystemScript.current_weapon(state).is_empty(), "未达成成就前不得凭空装备玉兵")
	var definitions: Dictionary = AchievementSystemScript.load_definitions()
	var first_ascension: Dictionary = (definitions.achievements as Array)[0]
	var first_progress: Dictionary = AchievementSystemScript.achievement_progress(state, first_ascension)
	_expect(int(first_progress.current) == 0 and int(first_progress.target) == 10 and
		is_equal_approx(float(first_progress.ratio), 0.0) and not bool(first_progress.met),
		"成就进度必须从真实角色状态推导当前值、目标值与完成状态")
	state.player.realm_index = 7
	first_progress = AchievementSystemScript.achievement_progress(state, first_ascension)
	_expect(str(first_progress.label) == "7 / 10" and is_equal_approx(float(first_progress.ratio), 0.7),
		"阶段型成就必须提供可直接呈现的进度文字与比例")
	var demonic: Dictionary = (definitions.achievements as Array)[3]
	state.player.karma = -80
	var demonic_progress: Dictionary = AchievementSystemScript.achievement_progress(state, demonic)
	_expect(int(demonic_progress.current) == 80 and int(demonic_progress.target) == 200 and
		is_equal_approx(float(demonic_progress.ratio), 0.4) and not bool(demonic_progress.met),
		"负向阈值成就必须按绝对推进量显示，不能产生负进度")
	state.player.karma = 20
	demonic_progress = AchievementSystemScript.achievement_progress(state, demonic)
	_expect(int(demonic_progress.current) == 0 and str(demonic_progress.label) == "0 / 200",
		"尚未踏入负向因果时进度必须稳定归零")

	state.player.realm_index = 10
	state.player.karma = 0
	var unlock: Dictionary = AchievementSystemScript.check_progress(state)
	_expect((unlock.unlocked as Array).size() == 1 and AchievementSystemScript.unlocked_count(state) == 1,
		"踏入半仙必须只解锁初次飞升及青霄问心剑")
	var weapon: Dictionary = AchievementSystemScript.current_weapon(state)
	_expect(str(weapon.id) == "qingxiao" and bool(weapon.unlocked), "成就奖励玉兵必须自动显化并共鸣")
	first_progress = AchievementSystemScript.achievement_progress(state, first_ascension)
	_expect(bool(first_progress.unlocked) and bool(first_progress.met) and float(first_progress.ratio) == 1.0,
		"达成后的成就进度必须同时保持已解锁、已完成和满比例")
	var bonuses: Dictionary = AchievementSystemScript.effective_bonuses(state)
	_expect(int(bonuses.attack) == 8 and int(bonuses.dao_heart) == 2,
		"沉眠玉兵必须提供一次动态基础属性，不能写入玩家基础值")

	var first_gain: Dictionary = AchievementSystemScript.add_resonance(state, 30, "回归试炼")
	bonuses = AchievementSystemScript.effective_bonuses(state)
	_expect(bool(first_gain.awakened) and int(first_gain.stage) == 1 and int(bonuses.attack) > 8,
		"共鸣30必须进入初鸣并增强有效属性")
	AchievementSystemScript.add_resonance(state, 95, "长线试炼")
	weapon = AchievementSystemScript.current_weapon(state)
	_expect(int(weapon.stage) == 2 and int(weapon.charge) == 100,
		"共鸣120必须进入真名且显圣蓄能上限为100")
	state.player.hp = 10
	var invoked: Dictionary = AchievementSystemScript.invoke(state)
	_expect(bool(invoked.ok) and int(AchievementSystemScript.current_weapon(state).charge) == 0 and
		int(AchievementSystemScript.current_weapon(state).invocations) == 1,
		"玉兵显圣必须消耗全部蓄能并累计次数")

	state.player.realm_index = 20
	state.player.battles_won = 100
	state.player.karma = 220
	state.player.age = 500
	state.player.total_events = 100
	state.player.dao_heart = 100
	state.player.reputation = 120
	state.generation = 10
	state.legacy.relic.awakening_stage = 3
	for arc_id in ["jade", "sect", "family", "rival"]:
		state.story.arc_progress[arc_id] = 4
		state.story.arc_legacies[arc_id] = "测试定局"
	AchievementSystemScript.check_progress(state)
	_expect(AchievementSystemScript.unlocked_count(state) >= 12,
		"长局条件必须自然解锁足够成就并触发玉中万兵")
	var unlocked_weapons := 0
	for weapon_state in (state.legacy.armory.weapons as Dictionary).values():
		if bool((weapon_state as Dictionary).unlocked): unlocked_weapons += 1
	_expect(unlocked_weapons == AchievementSystemScript.unlocked_count(state),
		"每项已解锁成就必须一一对应永久玉兵")
	var snapshot := state.duplicate(true)
	AchievementSystemScript.normalize(state)
	_expect(state == snapshot, "玉藏兵存档归一化必须幂等，不能重复叠加属性或通知")

	if failures.is_empty():
		print("ACHIEVEMENT_SYSTEM_TEST_OK: 16 achievements, jade weapons, awakening, invocation and idempotence passed")
		quit(0)
	else:
		for failure in failures:
			push_error("ACHIEVEMENT_SYSTEM_TEST_FAILED: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
