extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const CultivationScript = preload("res://scripts/cultivation_system.gd")
const ReincarnationScript = preload("res://scripts/reincarnation_system.gd")
const CombatSystemScript = preload("res://scripts/combat_system.gd")
const AchievementSystemScript = preload("res://scripts/achievement_system.gd")
const SaveServiceScript = preload("res://scripts/save_service.gd")

var failures: Array[String] = []


func _init() -> void:
	var base := GameStateScript.create_new_game("十世照见", 10101010, [20, 20, 20, 20, 20])
	var first := _run_ten_lives(base.duplicate(true))
	var second := _run_ten_lives(base.duplicate(true))
	_expect(first == second, "相同初始状态的十世长局必须逐字段完全一致")
	_expect(int(first.generation) == 10 and (first.legacy.past_lives as Array).size() == 10,
		"长局必须完整封存十世，而不是只把代数改到10")

	var natural_deaths := 0
	var combat_deaths := 0
	var ascended_lives := 0
	var dao_ancestor_lives := 0
	var heavenly_dao_lives := 0
	for life_value in (first.legacy.past_lives as Array):
		var life: Dictionary = life_value
		var cause := str(life.cause_of_death)
		if cause == "寿元自然耗尽": natural_deaths += 1
		if cause.begins_with("战败身陨"): combat_deaths += 1
		if int(life.realm_index) >= 10: ascended_lives += 1
		if int(life.realm_index) >= 19: dao_ancestor_lives += 1
		if int(life.realm_index) >= 20: heavenly_dao_lives += 1
	_expect(natural_deaths >= 1, "十世长局必须实际覆盖自然寿尽")
	_expect(combat_deaths >= 1, "十世长局必须实际覆盖战斗死亡")
	_expect(ascended_lives >= 1, "十世长局必须通过真实突破路线完成飞升")
	_expect(dao_ancestor_lives >= 1 and heavenly_dao_lives >= 1,
		"十世长局必须通过真实修炼抵达道祖与天道境")
	_expect(int(first.world.year) > 500 and (first.world.history as Array).size() <= 128 and
		(first.world.annual_summaries as Array).size() <= 32,
		"十世期间世界必须持续演进且长期历史保持有界")
	_expect((first.combat.history as Array).size() >= 2 and (first.combat.history as Array).size() <= 64,
		"跨世战绩必须保留且不无限增长")
	_expect(bool(first.legacy.armory.achievements.first_ascension) and
		bool(first.legacy.armory.achievements.dao_ancestor) and
		bool(first.legacy.armory.achievements.heavenly_dao) and
		bool(first.legacy.armory.achievements.ten_lives),
		"飞升、道祖、天道与十世成就必须在同一长局自然解锁")

	var test_root := ProjectSettings.globalize_path("res://").path_join("..").path_join(".tmp").path_join("godot-save-tests").path_join("ten-life").simplify_path()
	var service: RefCounted = SaveServiceScript.new("tenlife", test_root)
	service.call("clear_slot")
	DirAccess.remove_absolute(test_root)
	var saved: Dictionary = service.call("save_game", first)
	var loaded: Dictionary = service.call("load_game")
	_expect(bool(saved.get("ok", false)) and bool(loaded.get("ok", false)),
		"十世完整状态必须通过校验和与原子写入存档")
	if bool(loaded.get("ok", false)):
		var restored: Dictionary = loaded.state
		_expect(int(restored.generation) == 10 and (restored.legacy.past_lives as Array).size() == 10 and
			str(restored.legacy.past_lives[-1].cause_of_death) == str(first.legacy.past_lives[-1].cause_of_death),
			"十世存档读取必须保留代数、全部前世和最终死因")
	service.call("clear_slot")
	DirAccess.remove_absolute(test_root)

	if failures.is_empty():
		print("TEN_LIFE_LONG_RUN_TEST_OK: deterministic 10 lives, natural/combat death, ascension, heavenly dao and save passed")
		quit(0)
	else:
		for failure in failures:
			push_error("TEN_LIFE_LONG_RUN_TEST_FAILED: %s" % failure)
		quit(1)


func _run_ten_lives(state: Dictionary) -> Dictionary:
	for life_number in range(1, 11):
		state.player.path[GameStateScript.PATH_DIMENSIONS[(life_number - 1) % GameStateScript.PATH_DIMENSIONS.size()]] = life_number * 9
		var cause := "寿元自然耗尽"
		if life_number == 2:
			cause = _cause_combat_death(state, "第二世试炼")
		elif life_number == 3:
			state.player.roots = [20, 20, 20, 20, 20]
			_cultivate_to_realm(state, 10)
			AchievementSystemScript.check_progress(state)
			cause = _cause_combat_death(state, "飞升后战陨")
		elif life_number == 4:
			state.player.roots = [20, 20, 20, 20, 20]
			state.player.dao_heart = 120
			_cultivate_to_realm(state, 20)
			AchievementSystemScript.check_progress(state)
			cause = "天劫余波中身陨"
		else:
			var remaining := maxi(0, int(state.player.lifespan) - int(state.player.age))
			CultivationScript.advance_time(state, remaining)
			_expect(CultivationScript.is_dead(state), "第%d世必须真实走到寿元终点" % life_number)
		var closed: Dictionary = ReincarnationScript.close_life(state, cause, 1)
		_expect(bool(closed.get("ok", false)), "第%d世必须能封存为前世" % life_number)
		AchievementSystemScript.check_progress(state)
		if life_number < 10:
			var next: Dictionary = ReincarnationScript.begin_next_life(state, "第%d世照见" % (life_number + 1))
			_expect(bool(next.get("ok", false)), "第%d世结束后必须进入下一世" % life_number)
	AchievementSystemScript.check_progress(state)
	return state


func _cultivate_to_realm(state: Dictionary, target_realm: int) -> void:
	var actions := 0
	while int(state.player.realm_index) < target_realm and actions < 5000:
		while (int(state.player.level) < 9 or
				(int(state.player.realm_index) > 0 and int(state.player.exp) < CultivationScript.exp_needed(state.player))) and actions < 5000:
			var meditation: Dictionary = CultivationScript.meditate(state, 100)
			_expect(bool(meditation.get("ok", false)) and not bool(meditation.get("dead", false)),
				"高根骨修炼路线不得在目标境界前中断")
			actions += 1
		var breakthrough: Dictionary = CultivationScript.attempt_breakthrough(state, 1)
		_expect(bool(breakthrough.get("success", false)),
			"满足条件且使用确定性成功点数时必须突破")
		actions += 1
	_expect(int(state.player.realm_index) == target_realm and actions < 5000,
		"修炼路线必须在硬上限内抵达目标境界%d" % target_realm)


func _cause_combat_death(state: Dictionary, label: String) -> String:
	state.player.hp = 1
	var started: Dictionary = CombatSystemScript.start_combat(state, "immortal_unchained_duelist")
	_expect(bool(started.get("ok", false)), "%s必须能进入致命战斗" % label)
	var result: Dictionary = CombatSystemScript.auto_resolve(state)
	_expect(str(result.get("outcome", "")) == "defeat" and int(state.player.hp) == 0,
		"%s必须由战斗系统真实形成死亡" % label)
	return "战败身陨：%s" % str((result.get("battle", {}) as Dictionary).get("enemy_name", "无名强敌"))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
