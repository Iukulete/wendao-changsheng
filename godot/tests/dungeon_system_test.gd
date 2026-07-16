extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const DungeonSystemScript = preload("res://scripts/dungeon_system.gd")

var failures: Array[String] = []


func _init() -> void:
	var validation: Dictionary = DungeonSystemScript.validate_definitions()
	_expect(bool(validation.get("ok", false)) and int(validation.get("card_count", 0)) >= 14,
		"可选秘境必须拥有独立、可校验的灵诀牌池")
	var base := GameStateScript.create_new_game("入梦人", 969696, [8, 8, 8, 8, 8])
	base.player.max_hp = 1200
	base.player.hp = 1200
	base.player.attack = 180
	var first := base.duplicate(true)
	var second := base.duplicate(true)
	var start_a: Dictionary = DungeonSystemScript.start(first)
	var start_b: Dictionary = DungeonSystemScript.start(second)
	_expect(start_a == start_b and first == second, "相同状态必须生成相同秘境牌组与路线")
	_expect((first.dungeon.run.deck as Array).size() >= 10 and
		(first.dungeon.run.route_choices as Array).size() >= 1,
		"进入秘境才应生成临时牌组与分岔路线")

	var combat_index := _find_route(first.dungeon.run.route_choices, "combat")
	if combat_index < 0: combat_index = 0
	var chosen: Dictionary = DungeonSystemScript.choose_route(first, combat_index)
	if str(chosen.code) != "dungeon_battle_started":
		while DungeonSystemScript.has_active_run(first) and (first.dungeon.run.battle as Dictionary).is_empty():
			DungeonSystemScript.choose_route(first, 0)
	_expect(not (first.dungeon.run.battle as Dictionary).is_empty() and
		(first.dungeon.run.battle.hand as Array).size() == 5 and int(first.dungeon.run.battle.energy) == 3,
		"副本战斗必须以5张手牌、3点灵力和公开敌方意图开始")
	_expect(not DungeonSystemScript.intent_label(str(first.dungeon.run.battle.intent)).is_empty(),
		"副本敌人必须公开下一行动意图")

	var pressure := first.duplicate(true)
	pressure.dungeon.run.stress = 99
	pressure.dungeon.run.battle.intent = "stress"
	pressure.dungeon.run.battle.intent_cycle = ["stress"]
	DungeonSystemScript.end_turn(pressure)
	var curse_count := 0
	for card_value in pressure.dungeon.run.battle.discard_pile:
		if str((card_value as Dictionary).card_id) == "heart_demon": curse_count += 1
	_expect(int(pressure.dungeon.run.stress) == 60 and curse_count == 1,
		"心魔压力满值必须生成可处理的心障牌，而不是只做装饰数值")

	var completed_a := base.duplicate(true)
	var completed_b := base.duplicate(true)
	DungeonSystemScript.start(completed_a)
	DungeonSystemScript.start(completed_b)
	var final_a: Dictionary = DungeonSystemScript.auto_resolve(completed_a, 512)
	var final_b: Dictionary = DungeonSystemScript.auto_resolve(completed_b, 512)
	_expect(final_a == final_b and completed_a == completed_b,
		"完整秘境长局必须可复现")
	_expect(not DungeonSystemScript.has_active_run(completed_a) and int(final_a.actions) <= 512,
		"秘境自动运行必须在硬上限内结束，不能阻断长局")
	_expect(str(final_a.outcome) in ["completed", "defeat", "abandoned"],
		"秘境必须形成明确退出结算")
	_expect((completed_a.dungeon.history as Array).size() == 1,
		"副本结果必须写入有界历史且不替代主线剧情状态")

	if failures.is_empty():
		print("DUNGEON_SYSTEM_TEST_OK: optional deck, routes, intents, stress, deterministic resolution and exit passed")
		quit(0)
	else:
		for failure in failures:
			push_error("DUNGEON_SYSTEM_TEST_FAILED: %s" % failure)
		quit(1)


func _find_route(routes: Array, node_type: String) -> int:
	for index in range(routes.size()):
		if str((routes[index] as Dictionary).type) == node_type: return index
	return -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
