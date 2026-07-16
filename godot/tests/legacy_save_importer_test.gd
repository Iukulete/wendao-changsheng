extends SceneTree

const LegacyImporterScript = preload("res://scripts/legacy_save_importer.gd")
const SaveServiceScript = preload("res://scripts/save_service.gd")
const GameStateScript = preload("res://scripts/game_state.gd")

var failures: Array[String] = []


func _init() -> void:
	var test_root := ProjectSettings.globalize_path("res://").path_join("..").path_join(".tmp").path_join("godot-save-tests").path_join("legacy-import").simplify_path()
	DirAccess.make_dir_recursive_absolute(test_root)
	var source_path := test_root.path_join("slot_3.txt")
	_write_text(source_path, _save_v5_fixture())
	var original_hash := _file_sha256(source_path)
	var v4_path := test_root.path_join("slot_4.txt")
	_write_text(v4_path, _save_v4_fixture())

	var imported: Dictionary = LegacyImporterScript.import_file(source_path)
	_expect(bool(imported.get("ok", false)), "完整 SAVE_V5 旧档必须可只读解析")
	if bool(imported.get("ok", false)):
		var state: Dictionary = imported.state
		var player: Dictionary = state.player
		_expect(str(player.name) == "迁移道君" and str(player.realm_id) == "golden_immortal" and int(player.level) == 7,
			"角色名、境界和层数必须无损迁移")
		_expect(int(player.exp) == 9876 and int(player.dao_heart) == 44 and int(player.reputation) == 73,
			"旧版核心成长数值必须迁移")
		_expect((player.roots as Array) == [9, 8, 7, 6, 5] and int(player.family.wealth) == 34,
			"五行和家世字段必须迁移")
		_expect(str(state.current_era_id) == "star_network" and int(state.world.year) == 23,
			"纪元和世界年份必须迁移")
		_expect((state.world.npcs as Array).size() >= 2 and str(state.world.npcs[0].name) == "旧友沈川" and
			int(state.world.npcs[0].player_relation) == 61,
			"动态人物与玩家关系必须迁移")
		var social_npc: Dictionary = {}
		for npc_value in (state.world.npcs as Array):
			if str((npc_value as Dictionary).name) == "陆听雪":
				social_npc = npc_value
				break
		_expect(not social_npc.is_empty() and int(social_npc.player_relation) == 48 and
			str(social_npc.next_move) == "前往镜湖",
			"独立人情线人物、关系和下一步行动必须并入新版世界")
		_expect(int(state.generation) == 4 and (state.legacy.past_lives as Array).size() == 1 and
			str(state.legacy.past_lives[0].cause_of_death) == "寿尽坐化",
			"轮回世数、前世和死因必须迁移")
		_expect(str(state.legacy.inherited_echoes[0].name) == "太虚剑意" and
			int(state.legacy.relic.resonance) == 188,
			"传承回响与旧玉状态必须迁移")
		_expect(bool(state.legacy.armory.achievements.first_ascension) and
			int(state.legacy.armory.weapons.qingxiao.resonance) == 42 and
			str(state.legacy.armory.equipped_id) == "qingxiao",
			"旧成就、玉兵养成与装备状态必须迁移")
		_expect(int(state.story.arc_progress.jade) == 4 and str(state.story.arc_legacies.jade) == "旧我为证",
			"连续剧情分线进度与跨世定局必须迁移")

	var v4_imported: Dictionary = LegacyImporterScript.import_file(v4_path)
	_expect(bool(v4_imported.get("ok", false)) and int(v4_imported.state.player.dao_heart) == 0 and
		int(v4_imported.state.player.reputation) == 18 and int(v4_imported.state.player.enmity) == 0,
		"SAVE_V4 缺失的道心、名望和仇怨必须按旧版规则安全补全")
	var candidates: Array[Dictionary] = LegacyImporterScript.find_candidates([test_root])
	var candidate_slots: Array[int] = []
	for candidate in candidates:
		candidate_slots.append(int(candidate.slot))
	_expect(candidates.size() == 2 and candidate_slots.has(3) and candidate_slots.has(4),
		"六槽扫描必须发现并识别 SAVE_V4/SAVE_V5 旧档")

	var service_root := test_root.path_join("new-save")
	var service: RefCounted = SaveServiceScript.new("import-test", service_root)
	service.call("clear_slot")
	var existing := GameStateScript.create_new_game("不可覆盖", 20260716, [5, 5, 5, 5, 5])
	_expect(bool((service.call("save_game", existing) as Dictionary).get("ok", false)),
		"导入保护测试必须先建立新版存档")
	var broken_path := test_root.path_join("broken.txt")
	_write_text(broken_path, "SAVE_V5\n截断旧档\n")
	var rejected: Dictionary = service.call("import_legacy_save", broken_path)
	_expect(not bool(rejected.get("ok", true)), "截断旧档必须在写新版存档前被拒绝")
	var after_rejection: Dictionary = service.call("load_game")
	_expect(bool(after_rejection.get("ok", false)) and str(after_rejection.state.player.name) == "不可覆盖",
		"旧档导入失败不得覆盖已有新版存档")

	var saved_import: Dictionary = service.call("import_legacy_save", source_path)
	_expect(bool(saved_import.get("ok", false)) and str(saved_import.get("code", "")) == "legacy_imported",
		"有效旧档必须经原子存档服务写入新版格式")
	var restored: Dictionary = service.call("load_game")
	_expect(bool(restored.get("ok", false)) and str(restored.state.player.name) == "迁移道君" and
		int(restored.state.generation) == 4,
		"迁入后的新版存档必须可立即重读")
	_expect(original_hash == _file_sha256(source_path) and original_hash == str(saved_import.get("source_sha256", "")),
		"导入全过程不得修改旧版源文件")

	service.call("clear_slot")
	for path in [source_path, v4_path, broken_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(service_root)
	DirAccess.remove_absolute(test_root)
	if failures.is_empty():
		print("LEGACY_SAVE_IMPORTER_TEST_OK: SAVE_V4/V5 player/world/reincarnation import is read-only and atomic")
		quit(0)
	else:
		for failure in failures:
			push_error("LEGACY_SAVE_IMPORTER_TEST_FAILED: %s" % failure)
		quit(1)


func _save_v5_fixture() -> String:
	var lines: Array[String] = [
		"SAVE_V5", "迁移道君", "14", "7", "9876", "860", "900", "520", "600",
		"36", "44", "73", "12", "143", "680", "4567", "9", "188", "91",
		"9", "8", "7", "6", "5", "87", "31", "14",
		"FAMILY_V1", "旧宗旁支", "沈氏", "沈怀山", "陆清荷", "镜湖老医",
		"族谱末页藏着旧玉来历。", "12 34 1 0",
		"WORLD_ERA_V11", "星穹道网纪", "万法接入星网。", "灵讯可改因果。",
		"旧世回声", "纪元已转", "追索星图断层", "4 1", "0", "0", "0", "0",
		"", "", "", "", "", "", "0 0", "星门坍缩", "", "", "", "",
		"STORY_STATE_V4", "星网记录众生", "鸿蒙不可复制", "旧玉只认本心",
		"不受星网定义", "旧友仍在星海等待", "前往断裂星门", "47", "1",
		"沈川尚未偿还旧诺", "1", "沈川（旧友）", "61", "0", "4 3 2 1 0",
		"旧我为证", "守律立道", "护亲问源", "照雪盟友", "1 0 0 0 0",
		"今生辨认旧玉", "", "", "",
		"HONGMENG_PROGRESS_V1", "", "0",
		"GENERATED_WORLD_V1", "0", "0", "0",
		"WORLD_V2", "23", "2",
		"旧友沈川", "8 7 6 132 480 55 1 2 61 1 0", "陆听雪", "宿敌无名",
		"星使弦七", "12 10 4 88 700 -12 2 1 -25 1 1", "", "旧友沈川",
		"1", "星门余震", "断裂星门仍在吞吐旧纪元灵讯。", "4 1 0",
		"2", "第21年，镜湖剑庭撤离星门。", "第22年，沈川留下未竟旧诺。",
		"MEMORY_V3", "4", "2", "旧玉记得第一世\\n留下的剑痕。", "弦七在星网尽头回望。",
		"0", "0",
		"SOCIAL_V3", "1", "陆听雪仍在寻找失落的旧剑。", "1",
		"陆听雪", "旧盟剑修", "心怀歉意", "等待还剑", "金丹期", "修为尚藏",
		"偿还旧约", "再次失去同门", "前往镜湖", "48 1",
		"LEGACY_V4", "4", "1", "1", "太虚剑意", "经脉仍记得旧世剑路。", "72",
		"黑白轮回玉", "188", "2", "星纹道痕", "1", "照因大道", "66",
		"1", "3", "前世云归", "9", "210", "寿尽坐化", "81", "66", "20", "12",
		"1", "0", "镜湖旧忆", "记得镜湖未被星网覆盖前的水声。", "38",
		"1", "镜湖水声", "1", "沈川尚未偿还旧诺",
		"ACHIEVEMENTS_V3", "16",
		"1", "0", "0", "0", "1", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0",
		"16", "1 42 1 75 2", "0 0 0 0 0", "0 0 0 0 0", "0 0 0 0 0",
		"1 12 0 20 0", "0 0 0 0 0", "0 0 0 0 0", "0 0 0 0 0",
		"0 0 0 0 0", "0 0 0 0 0", "0 0 0 0 0", "0 0 0 0 0",
		"0 0 0 0 0", "0 0 0 0 0", "0 0 0 0 0", "0 0 0 0 0", "0",
	]
	return "\n".join(lines) + "\n"


func _save_v4_fixture() -> String:
	var lines := _save_v5_fixture().strip_edges().split("\n", true)
	lines[0] = "SAVE_V4"
	for _index in range(3):
		lines.remove_at(10)
	return "\n".join(lines) + "\n"


func _write_text(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("测试无法写入 %s" % path)
		return
	file.store_string(contents)
	file.close()


func _file_sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	while not file.eof_reached():
		context.update(file.get_buffer(65536))
	file.close()
	return context.finish().hex_encode()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
