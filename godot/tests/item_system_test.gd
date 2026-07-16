extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const ItemSystemScript = preload("res://scripts/item_system.gd")

var failures: Array[String] = []


func _init() -> void:
	var state := GameStateScript.create_new_game("铸痕", 414141, [6, 6, 7, 7, 6])
	state.inventory = {"items": [], "materials": {},
		"equipped": {"weapon_id": "", "armor_id": "", "relic_id": "black_white_jade"}}
	ItemSystemScript.normalize(state)
	_expect(ItemSystemScript.add_item(state, "spirit_herb", 8).ok, "材料必须能进入稳定计数背包")
	_expect(ItemSystemScript.add_item(state, "black_iron", 8).ok, "锻造材料必须能入库")
	_expect(ItemSystemScript.add_item(state, "star_sand", 4).ok, "稀有材料必须能入库")
	_expect(ItemSystemScript.add_item(state, "healing_pill", 2).ok, "消耗品必须支持有界堆叠")
	_expect(ItemSystemScript.count(state, "healing_pill") == 2, "堆叠数量必须可查询")
	var before_failed_remove := state.duplicate(true)
	_expect(not ItemSystemScript.remove_item(state, "healing_pill", 3).ok and state == before_failed_remove,
		"资源不足的扣除必须原子失败")
	state.player.hp = 10
	var consumed: Dictionary = ItemSystemScript.use_consumable(state, "healing_pill")
	_expect(bool(consumed.ok) and int(state.player.hp) > 10 and
		ItemSystemScript.count(state, "healing_pill") == 1, "丹药必须真实恢复并消耗一份")

	ItemSystemScript.add_item(state, "iron_sword", 1)
	var sword_reference := str((state.inventory.items as Array).filter(
		func(entry): return str((entry as Dictionary).item_id) == "iron_sword")[0].instance_id)
	_expect(ItemSystemScript.equip(state, sword_reference).ok, "拥有的武器必须能装备")
	var effective_a: Dictionary = ItemSystemScript.effective_stats(state)
	var effective_b: Dictionary = ItemSystemScript.effective_stats(state)
	_expect(int(effective_a.attack) == int(state.player.attack) + 8 and effective_a == effective_b,
		"装备加成必须按需计算且重复查询不得叠加")

	state.player.path.creation = 20
	var forge_a := state.duplicate(true)
	var forge_b := state.duplicate(true)
	var result_a: Dictionary = ItemSystemScript.forge(forge_a, "spirit_blade")
	var result_b: Dictionary = ItemSystemScript.forge(forge_b, "spirit_blade")
	_expect(bool(result_a.ok) and result_a == result_b and forge_a == forge_b,
		"相同种子、游标与材料必须得到相同锻造品质和实例")
	_expect(ItemSystemScript.equip(forge_a, str(result_a.instance_id)).ok,
		"自铸器物必须能用稳定实例 ID 装备")
	var forged_stats := ItemSystemScript.effective_stats(forge_a)
	_expect(int(forged_stats.attack) > int(forge_a.player.attack), "自铸武器必须提供质量缩放加成")

	var insufficient := GameStateScript.create_new_game("空炉", 7, [5, 5, 5, 5, 5])
	var insufficient_before := insufficient.duplicate(true)
	var failed_forge: Dictionary = ItemSystemScript.forge(insufficient, "warding_armor")
	_expect(not bool(failed_forge.ok) and insufficient == insufficient_before,
		"材料不足的锻造不得扣灵石或推进随机游标")

	ItemSystemScript.add_item(forge_a, "jade_qingxiao", 1)
	ItemSystemScript.add_item(forge_a, "cultivation_pill", 3)
	ItemSystemScript.add_item(forge_a, "fate_thread", 5)
	ItemSystemScript.equip(forge_a, sword_reference)
	var reincarnation: Dictionary = ItemSystemScript.apply_reincarnation(forge_a)
	_expect(bool(reincarnation.ok) and ItemSystemScript.count(forge_a, "jade_qingxiao") == 1,
		"轮回玉兵必须跨世保留")
	_expect(ItemSystemScript.count(forge_a, "cultivation_pill") == 0,
		"普通当世消耗品必须在轮回中散失")
	_expect(str(forge_a.inventory.equipped.weapon_id).is_empty() and
		str(forge_a.inventory.equipped.relic_id) == "black_white_jade",
		"轮回后普通装备卸下，黑白轮回玉必须仍在")

	var malformed := GameStateScript.create_new_game("坏匣", 9, [5, 5, 5, 5, 5])
	malformed.inventory = {"items": ["bad", {"item_id": "unknown", "quantity": 999999}],
		"materials": {"black_iron": 999999999, "unknown": 8}, "equipped": "bad"}
	ItemSystemScript.normalize(malformed)
	_expect((malformed.inventory.items as Array).is_empty() and
		int(malformed.inventory.materials.black_iron) == ItemSystemScript.MAX_MATERIAL_COUNT,
		"坏档物品必须被有界归一化，未知条目不得进入运行时")

	if failures.is_empty():
		print("ITEM_SYSTEM_TEST_OK: stacking, consumption, equipment, forging and reincarnation passed")
		quit(0)
	else:
		for failure in failures:
			push_error("ITEM_SYSTEM_TEST_FAILED: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
