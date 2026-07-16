extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const ItemSystemScript = preload("res://scripts/item_system.gd")
const CombatSystemScript = preload("res://scripts/combat_system.gd")

var failures: Array[String] = []


func _init() -> void:
	var base := GameStateScript.create_new_game("问剑", 515151, [7, 7, 7, 7, 7])
	var deterministic_a := base.duplicate(true)
	var deterministic_b := base.duplicate(true)
	var start_a: Dictionary = CombatSystemScript.start_combat(deterministic_a, "classical_razor_wolf")
	var start_b: Dictionary = CombatSystemScript.start_combat(deterministic_b, "classical_razor_wolf")
	_expect(bool(start_a.ok) and start_a == start_b and deterministic_a == deterministic_b,
		"同一状态与敌人必须生成完全相同的战局")
	_expect(not CombatSystemScript.intent_label(start_a.battle).is_empty(), "敌人必须提前暴露明确意图")
	var first_turn: Dictionary = CombatSystemScript.perform_action(deterministic_a, "attack")
	_expect(bool(first_turn.ok) and int(first_turn.battle.turn) == 2 and
		(first_turn.battle.log as Array).size() >= 3, "攻击必须推进双方行动并留下战斗日志")

	var guard_state := base.duplicate(true)
	CombatSystemScript.start_combat(guard_state, "classical_oath_breaker")
	guard_state.combat.current.intent = "heavy"
	guard_state.combat.current.intent_cycle = ["heavy"]
	var hp_before := int(guard_state.combat.current.player_hp)
	var guarded: Dictionary = CombatSystemScript.perform_action(guard_state, "guard")
	_expect(int(guarded.battle.player_hp) > 0 and int(guarded.battle.player_hp) >= hp_before - 20,
		"防御必须用护盾吸收蓄势重击，而不是装饰选项")

	var spell_state := base.duplicate(true)
	CombatSystemScript.start_combat(spell_state, "classical_razor_wolf")
	var mp_before := int(spell_state.combat.current.player_mp)
	var spell: Dictionary = CombatSystemScript.perform_action(spell_state, "spell")
	_expect(bool(spell.ok) and int(spell.battle.player_mp) == mp_before - CombatSystemScript.SPELL_COST and
		int((spell.battle.enemy_statuses as Dictionary).weak) > 0,
		"术法必须消耗灵力并施加可持续虚弱")

	var pill_state := base.duplicate(true)
	CombatSystemScript.start_combat(pill_state, "classical_razor_wolf")
	pill_state.combat.current.player_hp = 10
	var pills_before := ItemSystemScript.count(pill_state, "healing_pill")
	var pill: Dictionary = CombatSystemScript.perform_action(pill_state, "pill")
	_expect(bool(pill.ok) and int(pill.battle.player_hp) > 10 and
		ItemSystemScript.count(pill_state, "healing_pill") == pills_before - 1,
		"战斗丹药必须真实恢复并消耗库存")

	var victory_state := base.duplicate(true)
	victory_state.player.attack = 500
	CombatSystemScript.start_combat(victory_state, "classical_razor_wolf")
	var victory: Dictionary = CombatSystemScript.auto_resolve(victory_state)
	_expect(str(victory.outcome) == "victory" and not CombatSystemScript.has_active_combat(victory_state),
		"强势角色自动战斗必须在硬上限内获胜并结束")
	_expect(int(victory_state.player.battles_won) == 1 and int(victory_state.player.exp) > 0 and
		ItemSystemScript.count(victory_state, str(victory.rewards.material)) > 0,
		"胜利必须写入战绩、修为与稳定材料奖励")

	var defeat_state := base.duplicate(true)
	defeat_state.player.hp = 12
	defeat_state.player.max_hp = 12
	defeat_state.player.attack = 1
	defeat_state.player.defense = 0
	CombatSystemScript.start_combat(defeat_state, "immortal_unchained_duelist")
	var defeat: Dictionary = CombatSystemScript.auto_resolve(defeat_state)
	_expect(str(defeat.outcome) == "defeat" and int(defeat_state.player.hp) == 0,
		"致命战斗必须形成可供轮回系统识别的死亡状态")
	_expect(int(defeat.get("actions", 0)) <= CombatSystemScript.MAX_TURNS,
		"自动战斗必须保证终止，不能形成阻断长局的死循环")

	if failures.is_empty():
		print("COMBAT_SYSTEM_TEST_OK: deterministic intents, actions, statuses, rewards and termination passed")
		quit(0)
	else:
		for failure in failures:
			push_error("COMBAT_SYSTEM_TEST_FAILED: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
