extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const DungeonSystemScript = preload("res://scripts/dungeon_system.gd")
const AchievementSystemScript = preload("res://scripts/achievement_system.gd")
const ItemSystemScript = preload("res://scripts/item_system.gd")

var failures: Array[String] = []


func _init() -> void:
	var validation: Dictionary = DungeonSystemScript.validate_definitions()
	_expect(bool(validation.get("ok", false)) and int(validation.get("card_count", 0)) >= 19,
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
	_expect((first.dungeon.run.deck as Array).size() >= 11 and
		(first.dungeon.run.route_choices as Array).size() >= 1,
		"进入秘境才应生成临时牌组与分岔路线")
	_expect(str(first.dungeon.run.ability_profile.primary_path_id) == "insight" and
		str(first.dungeon.run.ability_profile.secondary_path_id) == "creation",
		"未偏科角色必须按稳定优先级映出主次道途，而不是依赖字典顺序")

	var identity := base.duplicate(true)
	identity.player.path.bonds = 24
	identity.player.path.insight = 18
	identity.player.path.creation = 12
	identity.world.npcs = [{"id":"npc_test_bond", "name":"沈照川", "alive":true,
		"player_relation":88}]
	_expect(bool(ItemSystemScript.equip(identity, "item_iron_sword_000001").get("ok", false)),
		"测试角色必须能装备已有青铁剑")
	var armor_result: Dictionary = ItemSystemScript.add_item(identity, "cloud_robe")
	_expect(bool(armor_result.get("ok", false)) and bool(ItemSystemScript.equip(identity,
		str(armor_result.get("instance_id", ""))).get("ok", false)), "测试角色必须能装备流云袍")
	var armory: Dictionary = AchievementSystemScript.normalize(identity)
	var jade_weapon: Dictionary = armory.weapons.qingxiao
	jade_weapon["unlocked"] = true
	armory.weapons.qingxiao = jade_weapon
	armory["equipped_id"] = "qingxiao"
	identity.legacy.armory = armory
	identity.legacy.inherited_echoes = [{"id":"test_echo", "type":"technique",
		"name":"前世行功残篇", "description":"旧经脉仍记得行功路线。", "power":30}]
	var identity_start: Dictionary = DungeonSystemScript.start(identity)
	var identity_deck: Array = identity.dungeon.run.deck
	var card_ids: Array[String] = []
	var card_uids := {}
	var sourced_cards := 0
	for card_value in identity_deck:
		var card: Dictionary = card_value
		card_ids.append(str(card.card_id))
		card_uids[str(card.uid)] = true
		if not str(card.get("source_name", "")).is_empty(): sourced_cards += 1
	_expect(bool(identity_start.get("ok", false)) and identity_deck.size() == 13 and
		card_uids.size() == identity_deck.size() and sourced_cards == identity_deck.size(),
		"角色能力牌必须拥有唯一实例ID与可审计来源")
	_expect("weapon_resonance" in card_ids and "armor_circulation" in card_ids and
		"realm_manifestation" in card_ids and "relic_cycle" in card_ids and
		"shared_oath" in card_ids and "cause_trace" in card_ids and
		"mind_mirror" in card_ids and "past_life_echo" in card_ids,
		"装备、境界、主次道途、玉兵与前世回响必须共同构成临时牌组")
	var profile: Dictionary = identity.dungeon.run.ability_profile
	_expect(str(profile.primary_path_id) == "bonds" and str(profile.primary_source_name) == "沈照川" and
		str(profile.secondary_path_id) == "insight" and str(profile.weapon_name) == "青铁剑" and
		str(profile.armor_name) == "流云袍" and str(profile.jade_weapon_name) == "青霄问心剑" and
		str(profile.memory_name) == "前世行功残篇" and int(identity.dungeon.run.attack_power) > 0 and
		int(identity.dungeon.run.guard_power) > 0,
		"能力映照必须保留角色身份与装备形成的实际加成")
	var persisted_value: Variant = JSON.parse_string(JSON.stringify(identity))
	var persisted: Dictionary = GameStateScript.ensure_v2(persisted_value as Dictionary)
	DungeonSystemScript.normalize(persisted)
	_expect(DungeonSystemScript.ability_profile_label(persisted.dungeon.run) ==
		DungeonSystemScript.ability_profile_label(identity.dungeon.run) and
		(persisted.dungeon.run.deck as Array).size() == identity_deck.size() and
		str((persisted.dungeon.run.deck as Array)[0].source_name) == str(identity_deck[0].source_name),
		"进行中的能力来源与临时牌组必须通过存档往返")

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
	var battle_curse_count := 0
	for card_value in pressure.dungeon.run.battle.discard_pile:
		if str((card_value as Dictionary).card_id) == "heart_demon": battle_curse_count += 1
	var deck_curse_count := 0
	for card_value in pressure.dungeon.run.deck:
		if str((card_value as Dictionary).card_id) == "heart_demon": deck_curse_count += 1
	_expect(int(pressure.dungeon.run.stress) == 60 and battle_curse_count == 1 and deck_curse_count == 1,
		"心魔压力满值必须生成跨战斗保留的可处理心障牌，而不是只做装饰数值")

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
		print("DUNGEON_SYSTEM_TEST_OK: character ability projection, sources, routes, intents, stress and deterministic exit passed")
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
