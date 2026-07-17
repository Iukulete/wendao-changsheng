extends SceneTree

const SaveServiceScript = preload("res://scripts/save_service.gd")
const MainScene = preload("res://scenes/main.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var test_root := ProjectSettings.globalize_path("res://").path_join("..").path_join(".tmp").path_join("godot-save-tests").path_join("integration").simplify_path()
	var service: RefCounted = SaveServiceScript.new("integrationtest", test_root)
	service.call("clear_slot")
	DirAccess.remove_absolute(test_root)
	DirAccess.make_dir_recursive_absolute(test_root)
	var legacy_source_path := test_root.path_join("slot_1.txt")
	_write_text(legacy_source_path, _minimal_legacy_save())
	var game := MainScene.instantiate()
	game.set("save_service", service)
	root.add_child(game)

	var name_input := game.find_child("DaoNameInput", true, false) as LineEdit
	_expect(name_input != null, "新生菜单应存在道号输入框")
	_expect(game.find_child("LegacyImportButton", true, false) != null,
		"发现有效 SAVE_V4/V5 六槽旧录时菜单必须提供只读导入入口")
	DirAccess.remove_absolute(legacy_source_path)
	if name_input != null:
		name_input.text = "归档真人"
		game.call("_start_new_game", name_input)

	_expect(FileAccess.file_exists(str(service.call("get_save_path"))), "开始新生应立即创建主档")
	var initialized_state: Dictionary = game.get("run_state")
	_expect(((initialized_state.get("world", {}) as Dictionary).get("factions", []) as Array).size() >= 3,
		"新生立档时必须初始化时代势力")
	_expect(((initialized_state.get("world", {}) as Dictionary).get("npcs", []) as Array).size() >= 6,
		"新生立档时必须初始化同世人物")
	var local_ai_button := game.find_child("LocalAIButton", true, false) as Button
	_expect(local_ai_button != null and local_ai_button.disabled,
		"CI 无本地模型时 AI 动作必须明确禁用，不能伪装就绪")
	var inventory_button := game.find_child("InventoryButton", true, false) as Button
	_expect(inventory_button != null and not inventory_button.disabled,
		"新生必须能进入行囊与炼器界面")
	var combat_button := game.find_child("CombatButton", true, false) as Button
	_expect(combat_button != null and not combat_button.disabled,
		"新生必须能从主界面进入确定性战斗")
	var return_button := game.find_child("ReturnToMenuButton", true, false) as Button
	_expect(return_button != null and not return_button.disabled,
		"主界面必须提供安全封存并返回标题的入口")
	if return_button != null:
		game.set("feedback", "返回标题自动封存验收")
		return_button.emit_signal("pressed")
		await process_frame
		_expect(game.find_child("DaoNameInput", true, false) != null,
			"返回标题动作必须回到可交互菜单")
		game.call("_continue_game")
		_expect(str(game.get("feedback")) == "返回标题自动封存验收",
			"返回标题前必须原子保存当前命途，续接后不能丢失反馈状态")
	var armory_button := game.find_child("ArmoryButton", true, false) as Button
	_expect(armory_button != null and not armory_button.disabled,
		"主界面必须能够查看成就和永久玉兵")
	game.call("_show_armory")
	_expect(game.find_child("ArmoryBackButton", true, false) != null,
		"玉藏兵界面必须提供明确返回动作")
	game.call("_show_game")
	var dungeon_button := game.find_child("DungeonButton", true, false) as Button
	_expect(dungeon_button != null and not dungeon_button.disabled,
		"镜湖秘境必须是主线之外的明确可选入口")
	game.call("_enter_dungeon")
	var active_dungeon_state: Dictionary = game.get("run_state")
	_expect(bool((active_dungeon_state.get("dungeon", {}) as Dictionary).get("active", false)),
		"进入秘境必须创建独立且可保存的副本状态")
	_expect(game.find_child("DungeonRouteButton0", true, false) != null,
		"秘境必须显示可选择的路线道标")
	var route_index := 0
	var routes: Array = active_dungeon_state.dungeon.run.route_choices
	for index in range(routes.size()):
		if str((routes[index] as Dictionary).type) in ["combat", "elite", "boss"]:
			route_index = index
			break
	game.call("_choose_dungeon_route", route_index)
	_expect(game.find_child("DungeonCardButton0", true, false) != null and
		game.find_child("DungeonEndTurnButton", true, false) != null,
		"副本交锋必须显示角色能力牌与结束回合动作")
	game.call("_save_current_state", "测试秘境断点")
	game.call("_show_menu")
	game.call("_continue_game")
	_expect(game.find_child("DungeonCardButton0", true, false) != null,
		"续接存档必须直接恢复秘境能力牌战斗")
	game.call("_abandon_dungeon")
	var exited_dungeon_state: Dictionary = game.get("run_state")
	_expect(not bool((exited_dungeon_state.get("dungeon", {}) as Dictionary).get("active", true)) and
		game.find_child("DungeonButton", true, false) != null,
		"撤离秘境必须回到原有主线且不替换普通战斗入口")
	game.call("_show_inventory")
	_expect(game.find_child("InventoryBackButton", true, false) != null,
		"行囊界面必须提供明确返回动作")
	game.call("_show_game")
	game.call("_start_combat")
	var active_combat_state: Dictionary = game.get("run_state")
	_expect(bool((active_combat_state.get("combat", {}) as Dictionary).get("active", false)),
		"开始战斗必须写入可保存的进行中战局")
	_expect(game.find_child("CombatAttackButton", true, false) != null,
		"战斗界面必须提供明确的攻击行动")
	active_combat_state.combat.current.enemy_hp = 1
	active_combat_state.combat.current.enemy_defense = 0
	active_combat_state.combat.current.player_attack = 999
	game.call("_save_current_state", "测试战局断点")
	game.call("_show_menu")
	game.call("_continue_game")
	_expect(game.find_child("CombatAttackButton", true, false) != null,
		"续接存档必须直接恢复进行中的战斗，而不是绕回主界面")
	game.call("_resolve_combat_action", "attack")
	var finished_combat_state: Dictionary = game.get("run_state")
	_expect(not bool((finished_combat_state.get("combat", {}) as Dictionary).get("active", true)),
		"胜利后必须结束进行中的战斗状态")
	_expect(((finished_combat_state.combat as Dictionary).get("history", []) as Array).size() == 1,
		"战斗结果必须写入有界战史")
	var player_before: Dictionary = game.get("player")
	var blocked_choice := {"deltas": {"spirit_stones": -int(player_before.spirit_stones) - 1}}
	_expect(not str(game.call("_choice_unavailable_reason", blocked_choice)).is_empty(),
		"资源不足的付费选择必须在应用负数前被拒绝")
	var exp_before := int(player_before.get("exp", 0))
	var level_before := int(player_before.get("level", 1))
	var age_before := int(player_before.get("age", 0))
	game.call("_meditate")
	var player_after: Dictionary = game.get("player")
	var saved_exp := int(player_after.get("exp", 0))
	_expect(int(player_after.get("age", 0)) == age_before + 1,
		"修炼必须稳定推进一岁，不能依赖随机剩余修为判断成功")
	_expect(int(player_after.get("level", 1)) > level_before or saved_exp != exp_before,
		"修炼必须推进层级或留下修为积累")
	_expect(FileAccess.file_exists(str(service.call("get_backup_path"))), "自动保存应轮换上一个完整快照")

	player_after["exp"] = 0
	game.call("_show_menu")
	var continue_button := game.find_child("ContinueButton", true, false) as Button
	_expect(continue_button != null and not continue_button.disabled, "存在有效旧档时继续按钮应可用")
	game.call("_continue_game")
	var restored_player: Dictionary = game.get("player")
	_expect(int(restored_player.get("exp", -1)) == saved_exp, "继续游戏应恢复自动保存的修为")
	_expect(str(restored_player.get("name", "")) == "归档真人", "继续游戏应恢复道号")
	var restored_state: Dictionary = game.get("run_state")
	_expect(int(restored_state.get("schema_version", 0)) == 2, "主界面必须恢复 v2 完整状态")
	_expect(int((restored_state.get("world", {}) as Dictionary).get("year", 0)) > 1,
		"保存读取必须保留已经推进的世界时间")
	_expect((restored_state.world as Dictionary).has("last_year_summary"),
		"保存读取必须保留年度世界摘要")
	var ai_bridge: Node = game.get("ai_bridge")
	var ai_fixture := "【因果】镜湖来书\n沈照川从年史暗页里找到一封未署名的来书，墨痕正随你的道心明灭，等你决定如何回应。\n替人守信\n照见墨痕\n借书破局"
	var ai_resolution: Dictionary = ai_bridge.call("resolve_generated_text", ai_fixture, restored_state, "integration-fixture")
	game.call("_on_ai_event_ready", ai_resolution.event, {"code": "generated", "backend": "integration-fixture", "fallback": false})
	_expect(str((game.get("current_event") as Dictionary).get("source", "")) == "local_ai",
		"合法本地 AI 输出必须进入同一结构化事件界面")
	game.call("_resolve_choice", 0)
	var ai_state: Dictionary = (game.get("run_state") as Dictionary).get("ai", {})
	_expect(str(ai_state.get("last_backend", "")) == "integration-fixture",
		"本地 AI 后端状态必须随完整存档保存")
	restored_state.player.age = restored_state.player.lifespan
	var death_save: Dictionary = service.call("save_game", restored_state)
	_expect(bool(death_save.get("ok", false)), "寿尽状态应能写入以验证续档收尾")
	game.call("_show_menu")
	game.call("_continue_game")
	var closed_state: Dictionary = game.get("run_state")
	_expect(bool(closed_state.get("life_closed", false)), "续接寿尽旧档时必须自动封存此世")
	_expect(((closed_state.get("legacy", {}) as Dictionary).get("past_lives", []) as Array).size() == 1,
		"续接寿尽旧档必须生成前世记录，不能卡在空轮回页")

	_write_text(str(service.call("get_save_path")), "broken")
	_write_text(str(service.call("get_backup_path")), "broken too")
	game.call("_show_menu")
	continue_button = game.find_child("ContinueButton", true, false) as Button
	_expect(continue_button != null and continue_button.disabled, "主备份均损坏时继续按钮应禁用")

	service.call("clear_slot")
	DirAccess.remove_absolute(test_root)
	game.free()
	if failures.is_empty():
		print("MAIN_SAVE_INTEGRATION_TEST_OK: menu, autosave, continue and corrupt-save UI passed")
		quit(0)
	else:
		for failure in failures:
			push_error("MAIN_SAVE_INTEGRATION_TEST_FAILED: %s" % failure)
		quit(1)


func _write_text(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("无法为坏档场景写入测试文件")
		return
	file.store_string(contents)
	file.close()


func _minimal_legacy_save() -> String:
	return "\n".join([
		"SAVE_V5", "旧录访客", "1", "1", "0", "100", "100", "50", "50",
		"0", "0", "0", "0", "16", "80", "10", "0", "10", "5",
		"5", "5", "5", "5", "5", "0", "0", "0",
		"WORLD_ERA_V1", "古典修仙纪",
		"WORLD_V2", "1", "0", "0", "0",
		"LEGACY_V1", "1", "0", "黑白轮回玉", "0", "0", "未定道痕", "0", "0",
	]) + "\n"


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
