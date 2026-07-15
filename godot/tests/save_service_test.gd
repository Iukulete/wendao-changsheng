extends SceneTree

const SaveServiceScript = preload("res://scripts/save_service.gd")

var failures: Array[String] = []


func _init() -> void:
	var default_service: RefCounted = SaveServiceScript.new("pathprobe")
	var default_root := str(default_service.call("get_save_root")).replace("\\", "/")
	var expected_root := ProjectSettings.globalize_path("res://").path_join("..").path_join(".local").path_join("save").simplify_path().replace("\\", "/")
	_expect(default_root == expected_root, "编辑器默认存档根应为 res://../.local/save")
	_expect(not default_root.to_lower().begins_with("c:/users/"), "默认存档根不得落入 C:/Users")
	var rejected_user_root := str((SaveServiceScript.new("pathprobe", "user://forbidden") as RefCounted).call("get_save_root")).replace("\\", "/")
	_expect(rejected_user_root == expected_root, "user:// 覆盖必须被拒绝，不能回落到 AppData")

	var test_root := ProjectSettings.globalize_path("res://").path_join("..").path_join(".tmp").path_join("godot-save-tests").path_join("service").simplify_path()
	var service: RefCounted = SaveServiceScript.new("selftest", test_root)
	service.call("clear_slot")
	DirAccess.remove_absolute(test_root)

	var first := _snapshot("测试道君", "古典修仙纪", 37, ["第一次记忆"])
	var first_save: Dictionary = service.call("save_game", first)
	_expect(bool(first_save.get("ok", false)), "首次保存应成功")
	var first_load: Dictionary = service.call("load_game")
	_expect(bool(first_load.get("ok", false)), "首次读取应成功")
	_expect(_loaded_name(first_load) == "测试道君", "道号应完整恢复")
	_expect(_loaded_exp(first_load) == 37, "修为应完整恢复")

	var second := _snapshot("第二世", "星穹道网纪", 88, ["第二次记忆", "星网回响"])
	var second_save: Dictionary = service.call("save_game", second)
	_expect(bool(second_save.get("ok", false)), "第二次保存应成功并产生备份")
	_expect(FileAccess.file_exists(str(service.call("get_backup_path"))), "轮换后应存在备份")

	_write_text(str(service.call("get_save_path")), "{broken primary")
	var recovered: Dictionary = service.call("load_game")
	_expect(bool(recovered.get("ok", false)), "主档损坏时应从备份恢复")
	_expect(bool(recovered.get("recovered", false)), "恢复结果应明确标记 recovered")
	_expect(_loaded_name(recovered) == "测试道君", "备份应是上一次完整快照")
	var repaired: Dictionary = service.call("load_game")
	_expect(bool(repaired.get("ok", false)) and not bool(repaired.get("recovered", true)),
		"备份恢复后主档应已修复")

	_write_text(str(service.call("get_save_path")), "not json")
	_write_text(str(service.call("get_backup_path")), "also not json")
	var corrupt: Dictionary = service.call("load_game")
	_expect(not bool(corrupt.get("ok", true)), "主档与备份均损坏时必须安全失败")
	_expect(str(corrupt.get("code", "")) == "corrupt_save", "坏档应返回可识别错误码")

	service.call("clear_slot")
	DirAccess.remove_absolute(test_root)
	if failures.is_empty():
		print("SAVE_SERVICE_TEST_OK: atomic write, checksum, restore and corruption handling passed")
		quit(0)
	else:
		for failure in failures:
			push_error("SAVE_SERVICE_TEST_FAILED: %s" % failure)
		quit(1)


func _snapshot(dao_name: String, era: String, cultivation: int, memories: Array[String]) -> Dictionary:
	return {
		"current_era": era,
		"player": {
			"name": dao_name,
			"realm": "炼气",
			"level": 3,
			"exp": cultivation,
			"hp": 91,
			"max_hp": 112,
			"mp": 51,
			"max_mp": 60,
			"age": 19,
			"lifespan": 120,
			"spirit_stones": 44,
			"pills": 2,
			"karma": -3,
			"dao_heart": 9,
			"reputation": 7,
			"enmity": 1,
			"roots": [8, 6, 9, 5, 7],
		},
		"recent_memories": memories,
		"feedback": "测试中的山河仍在流动。",
	}


func _loaded_name(result: Dictionary) -> String:
	var state: Dictionary = result.get("state", {})
	var loaded_player: Dictionary = state.get("player", {})
	return str(loaded_player.get("name", ""))


func _loaded_exp(result: Dictionary) -> int:
	var state: Dictionary = result.get("state", {})
	var loaded_player: Dictionary = state.get("player", {})
	return int(loaded_player.get("exp", -1))


func _write_text(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("测试无法写入 %s" % path)
		return
	file.store_string(contents)
	file.close()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
