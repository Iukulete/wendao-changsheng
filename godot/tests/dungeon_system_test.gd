extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const DungeonSystemScript = preload("res://scripts/dungeon_system.gd")
const AchievementSystemScript = preload("res://scripts/achievement_system.gd")
const ItemSystemScript = preload("res://scripts/item_system.gd")

var failures: Array[String] = []


func _init() -> void:
	var validation: Dictionary = DungeonSystemScript.validate_definitions()
	_expect(bool(validation.get("ok", false)) and int(validation.get("card_count", 0)) >= 19 and
		int(validation.get("route_node_count", 0)) == 36 and int(validation.get("trait_count", 0)) == 6,
		"可选秘境必须拥有灵诀牌池、六时代36个路线节点与六条首领法则")
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

	var route_names := {}
	var trait_ids := {}
	for era_id in DungeonSystemScript.ERA_IDS:
		for node_type in DungeonSystemScript.ROUTE_TYPES:
			var node: Dictionary = DungeonSystemScript.route_definition(str(era_id), str(node_type))
			_expect(str(node.get("type", "")) == str(node_type) and not str(node.get("name", "")).is_empty() and
				not str(node.get("description", "")).is_empty(), "每个时代的路线节点必须完整可读：%s/%s" % [era_id, node_type])
			route_names[str(node.name)] = true
		var boss_rule: Dictionary = DungeonSystemScript.boss_trait_for_era(str(era_id))
		_expect(not str(boss_rule.get("id", "")).is_empty() and not str(boss_rule.get("description", "")).is_empty(),
			"每个时代首领必须公开独立法则：%s" % era_id)
		trait_ids[str(boss_rule.id)] = true
	_expect(route_names.size() == 36 and trait_ids.size() == 6,
		"六时代路线名称与首领法则不得只是同一内容换皮")

	var classical_boss := _start_boss("classical", 970101)
	_set_test_hand(classical_boss, ["sword_cut"])
	var mirror_hp := int(classical_boss.dungeon.run.hp)
	DungeonSystemScript.play_card(classical_boss, 0)
	_expect(int(classical_boss.dungeon.run.hp) == mirror_hp - 4,
		"古典首领的镜身照返必须反噬每回合首张伤害灵诀")

	var steam_boss := _start_boss("steam", 970102)
	_set_test_hand(steam_boss, ["sword_cut", "sword_cut", "sword_cut"])
	for _index in range(3): DungeonSystemScript.play_card(steam_boss, 0)
	_expect(int(steam_boss.dungeon.run.stress) == 9,
		"蒸汽首领必须在第三张灵诀时触发炉压过载")

	var star_boss := _start_boss("star_network", 970103)
	_set_test_hand(star_boss, ["sword_cut"])
	DungeonSystemScript.play_card(star_boss, 0)
	var star_discard: Array = star_boss.dungeon.run.battle.discard_pile
	_expect(star_discard.size() == 2 and int(star_boss.dungeon.run.stress) == 4 and
		str((star_discard[-1] as Dictionary).source_kind) == "trait",
		"星网首领必须复制每回合首张灵诀并留下可审计来源")
	var star_payload: Variant = JSON.parse_string(JSON.stringify(star_boss))
	var restored_star: Dictionary = GameStateScript.ensure_v2(star_payload as Dictionary)
	DungeonSystemScript.normalize(restored_star)
	_expect(str(restored_star.dungeon.run.battle.trait.id) == "memory_fork" and
		int(restored_star.dungeon.run.battle.cards_played_turn) == 1,
		"首领法则与本回合触发状态必须通过存档往返")

	var wasteland_boss := _start_boss("wasteland", 970104)
	_set_boss_intent(wasteland_boss, "guard")
	var rain_hp := int(wasteland_boss.dungeon.run.hp)
	DungeonSystemScript.end_turn(wasteland_boss)
	_expect(int(wasteland_boss.dungeon.run.hp) == rain_hp - 3,
		"废土首领必须在回合末执行黑雨侵蚀")

	var final_boss := _start_boss("final_age", 970105)
	_expect(int(final_boss.dungeon.run.battle.energy) == 2 and
		DungeonSystemScript.energy_cap(final_boss.dungeon.run.battle) == 2,
		"末法首领必须公开并执行灵息抽税")

	var imperial_boss := _start_boss("immortal_dynasty", 970106)
	_set_boss_intent(imperial_boss, "guard")
	DungeonSystemScript.end_turn(imperial_boss)
	_expect(int(imperial_boss.dungeon.run.stress) == 10,
		"仙朝首领结界护体时必须追加天册敕令压力")

	var rest_state := _resolve_noncombat("classical", "rest", 970201)
	_expect(int(rest_state.dungeon.run.hp) > 500 and int(rest_state.dungeon.run.stress) < 50,
		"时代休整节点必须执行数据中的恢复与平心效果")
	var forge_state := _resolve_noncombat("star_network", "forge", 970202)
	_expect(int(forge_state.dungeon.run.attack_power) >= 2 and int(forge_state.dungeon.run.guard_power) >= 2 and
		int(forge_state.dungeon.run.stress) == 54,
		"时代炼器节点必须执行器诀、护诀与压力代价（实际 %d/%d/%d）" % [
			int(forge_state.dungeon.run.attack_power), int(forge_state.dungeon.run.guard_power),
			int(forge_state.dungeon.run.stress)])
	var fire_state := _resolve_noncombat("wasteland", "forge", 970203)
	_expect(int(fire_state.dungeon.run.hp) == 494 and int(fire_state.dungeon.run.attack_power) >= 5,
		"废土深火焊台必须以气血换取器诀成长")

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
		print("DUNGEON_SYSTEM_TEST_OK: character abilities, 36 era routes, six boss rules and deterministic exit passed")
		quit(0)
	else:
		for failure in failures:
			push_error("DUNGEON_SYSTEM_TEST_FAILED: %s" % failure)
		quit(1)


func _start_boss(era_id: String, seed_value: int) -> Dictionary:
	var state := GameStateScript.create_new_game("法则见证人", seed_value, [8, 8, 8, 8, 8])
	state.current_era_id = era_id
	state.current_era = str(GameStateScript.ERA_NAMES.get(era_id, "古典修仙纪"))
	state.player.max_hp = 1200
	state.player.hp = 1200
	state.player.attack = 180
	DungeonSystemScript.start(state)
	state.dungeon.run.route_choices = [DungeonSystemScript.route_definition(era_id, "boss")]
	var result: Dictionary = DungeonSystemScript.choose_route(state, 0)
	_expect(str(result.get("code", "")) == "dungeon_battle_started" and
		str(state.dungeon.run.battle.get("rank", "")) == "boss",
		"测试必须能直接进入时代首领战：%s" % era_id)
	return state


func _set_test_hand(state: Dictionary, card_ids: Array[String]) -> void:
	var battle: Dictionary = state.dungeon.run.battle
	var hand: Array = []
	for index in range(card_ids.size()):
		hand.append({"uid":"test_card_%02d" % index, "card_id":card_ids[index], "upgrade":0,
			"source_kind":"test", "source_name":"回归灵诀"})
	battle["hand"] = hand
	battle["draw_pile"] = []
	battle["discard_pile"] = []
	battle["exhausted"] = []
	battle["energy"] = DungeonSystemScript.STARTING_ENERGY
	state.dungeon.run.battle = battle


func _set_boss_intent(state: Dictionary, intent: String) -> void:
	var battle: Dictionary = state.dungeon.run.battle
	battle["intent"] = intent
	battle["intent_cycle"] = [intent]
	battle["intent_index"] = 0
	state.dungeon.run.battle = battle


func _resolve_noncombat(era_id: String, node_type: String, seed_value: int) -> Dictionary:
	var state := GameStateScript.create_new_game("道标见证人", seed_value, [8, 8, 8, 8, 8])
	state.current_era_id = era_id
	state.current_era = str(GameStateScript.ERA_NAMES.get(era_id, "古典修仙纪"))
	state.player.max_hp = 1000
	state.player.hp = 1000
	state.player.attack = 180
	DungeonSystemScript.start(state)
	state.dungeon.run.hp = 500
	state.dungeon.run.stress = 50
	state.dungeon.run.route_choices = [DungeonSystemScript.route_definition(era_id, node_type)]
	var result: Dictionary = DungeonSystemScript.choose_route(state, 0)
	_expect(str(result.get("code", "")) == "dungeon_node_completed",
		"测试必须能解析时代非战斗节点：%s/%s" % [era_id, node_type])
	return state


func _find_route(routes: Array, node_type: String) -> int:
	for index in range(routes.size()):
		if str((routes[index] as Dictionary).type) == node_type: return index
	return -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
