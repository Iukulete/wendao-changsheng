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
	var game := MainScene.instantiate()
	game.set("save_service", service)
	root.add_child(game)

	var name_input := game.find_child("DaoNameInput", true, false) as LineEdit
	_expect(name_input != null, "新生菜单应存在道号输入框")
	if name_input != null:
		name_input.text = "归档真人"
		game.call("_start_new_game", name_input)

	_expect(FileAccess.file_exists(str(service.call("get_save_path"))), "开始新生应立即创建主档")
	var player_before: Dictionary = game.get("player")
	var exp_before := int(player_before.get("exp", 0))
	game.call("_meditate")
	var player_after: Dictionary = game.get("player")
	var saved_exp := int(player_after.get("exp", 0))
	_expect(saved_exp > exp_before, "修炼应改变修为")
	_expect(FileAccess.file_exists(str(service.call("get_backup_path"))), "自动保存应轮换上一个完整快照")

	player_after["exp"] = 0
	game.call("_show_menu")
	var continue_button := game.find_child("ContinueButton", true, false) as Button
	_expect(continue_button != null and not continue_button.disabled, "存在有效旧档时继续按钮应可用")
	game.call("_continue_game")
	var restored_player: Dictionary = game.get("player")
	_expect(int(restored_player.get("exp", -1)) == saved_exp, "继续游戏应恢复自动保存的修为")
	_expect(str(restored_player.get("name", "")) == "归档真人", "继续游戏应恢复道号")

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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
