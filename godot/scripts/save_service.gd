class_name SaveService
extends RefCounted

const GameStateScript = preload("res://scripts/game_state.gd")
const ItemSystemScript = preload("res://scripts/item_system.gd")
const CombatSystemScript = preload("res://scripts/combat_system.gd")
const StorySystemScript = preload("res://scripts/story_system.gd")

## Versioned, checksummed and atomically replaced JSON saves.
##
## The payload is stored as a JSON string inside the envelope.  This keeps the
## exact bytes used for the checksum stable after the outer JSON is parsed.
## Development builds store beside the project on D:, while exported builds
## store beside the executable.  We deliberately never fall back to AppData.

const SAVE_VERSION: int = 2
const MIN_READABLE_VERSION: int = 1
const FORMAT_ID := "wendao-changsheng-save"
const VALID_ERAS := [
	"古典修仙纪", "灵机蒸汽纪", "星穹道网纪", "废土返道纪", "末法裂变纪", "仙朝鼎盛纪",
]
const PLAYER_INT_FIELDS := [
	"level", "exp", "hp", "max_hp", "mp", "max_mp", "age", "lifespan",
	"spirit_stones", "pills", "karma", "dao_heart", "reputation", "enmity",
	"realm_index", "attack", "defense", "total_events", "battles_won", "npcs_met",
]

var _slot_name: String
var _root_path: String
var _save_path: String
var _backup_path: String
var _temp_path: String
var _corrupt_path: String


func _init(slot_name: String = "main", root_override: String = "") -> void:
	_slot_name = _safe_slot_name(slot_name)
	_root_path = _resolve_root_path(root_override)
	var prefix := _root_path.path_join("wendao_%s" % _slot_name)
	_save_path = prefix + ".json"
	_backup_path = prefix + ".backup.json"
	_temp_path = prefix + ".tmp"
	_corrupt_path = prefix + ".corrupt.json"


func save_game(snapshot: Dictionary) -> Dictionary:
	var directory_result := _ensure_root_directory()
	if not bool(directory_result.get("ok", false)):
		return directory_result
	var normalized := _normalize_snapshot(snapshot)
	if not bool(normalized.get("ok", false)):
		return normalized

	var payload := JSON.stringify(normalized.get("state", {}))
	var checksum := _sha256(payload)
	if checksum.is_empty():
		return _failure("checksum_failed", "无法计算存档校验值。")

	var envelope := {
		"format": FORMAT_ID,
		"version": SAVE_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"payload": payload,
		"sha256": checksum,
	}
	var write_result := _atomic_write(JSON.stringify(envelope, "\t"))
	if bool(write_result.get("ok", false)):
		write_result["saved_at_unix"] = envelope.saved_at_unix
		write_result["message"] = "旧玉已封存此刻。"
	return write_result


func load_game() -> Dictionary:
	var directory_result := _ensure_root_directory()
	if not bool(directory_result.get("ok", false)):
		return directory_result
	var primary := _read_save(_save_path)
	if bool(primary.get("ok", false)):
		primary["recovered"] = false
		primary["message"] = "旧玉已续接上一次命途。"
		return primary

	var backup := _read_save(_backup_path)
	if bool(backup.get("ok", false)):
		var repaired := _restore_primary_from_backup()
		backup["recovered"] = true
		backup["repaired"] = repaired
		backup["message"] = (
			"主档受损，已从完整备份恢复并修复。"
			if repaired
			else "主档受损，已从完整备份恢复；本次进度仍可继续。"
		)
		return backup

	if not has_any_save():
		return _failure("no_save", "尚无可继续的旧档。")

	return _failure("corrupt_save", "存档校验失败，主档与备份均无法读取；文件已保留。")


func inspect_save() -> Dictionary:
	return load_game()


func has_any_save() -> bool:
	return FileAccess.file_exists(_save_path) or FileAccess.file_exists(_backup_path)


func clear_slot() -> void:
	for path in [_save_path, _backup_path, _temp_path, _corrupt_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func get_save_root() -> String:
	return _root_path


func get_save_path() -> String:
	return _save_path


func get_backup_path() -> String:
	return _backup_path


func _atomic_write(contents: String) -> Dictionary:
	var temp_file := FileAccess.open(_temp_path, FileAccess.WRITE)
	if temp_file == null:
		return _failure("write_failed", "无法写入存档目录 %s：%s。请确认游戏位于可写的 D 盘目录。" % [
			_root_path, error_string(FileAccess.get_open_error())])
	temp_file.store_string(contents)
	temp_file.flush()
	temp_file.close()

	var moved_primary := false

	if FileAccess.file_exists(_save_path):
		if FileAccess.file_exists(_backup_path):
			var remove_error := DirAccess.remove_absolute(_backup_path)
			if remove_error != OK:
				DirAccess.remove_absolute(_temp_path)
				return _failure("backup_failed", "无法更新存档备份：%s" % error_string(remove_error))
		var backup_error := DirAccess.rename_absolute(_save_path, _backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(_temp_path)
			return _failure("backup_failed", "无法轮换存档备份：%s" % error_string(backup_error))
		moved_primary = true

	var replace_error := DirAccess.rename_absolute(_temp_path, _save_path)
	if replace_error != OK:
		if moved_primary and not FileAccess.file_exists(_save_path):
			DirAccess.rename_absolute(_backup_path, _save_path)
		return _failure("replace_failed", "无法原子替换存档：%s" % error_string(replace_error))

	return {"ok": true, "code": "saved"}


func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("missing", "存档不存在。")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("read_failed", "无法打开存档。")
	var raw := file.get_as_text()
	file.close()
	var envelope_parser := JSON.new()
	if envelope_parser.parse(raw) != OK:
		return _failure("invalid_envelope", "存档外层 JSON 无效。")
	var parsed = envelope_parser.data
	if not parsed is Dictionary:
		return _failure("invalid_envelope", "存档外层格式无效。")
	var envelope: Dictionary = parsed
	if str(envelope.get("format", "")) != FORMAT_ID:
		return _failure("invalid_format", "这不是问道长生存档。")
	var stored_version := int(envelope.get("version", -1))
	if stored_version < MIN_READABLE_VERSION or stored_version > SAVE_VERSION:
		return _failure("unsupported_version", "存档版本暂不受支持。")
	var payload_value = envelope.get("payload", null)
	var checksum_value = envelope.get("sha256", null)
	if not payload_value is String or not checksum_value is String:
		return _failure("invalid_envelope", "存档载荷或校验字段缺失。")
	var payload: String = payload_value
	if not _constant_time_equal(_sha256(payload), str(checksum_value)):
		return _failure("checksum_mismatch", "存档内容校验失败。")
	var payload_parser := JSON.new()
	if payload_parser.parse(payload) != OK:
		return _failure("invalid_payload", "存档载荷 JSON 无效。")
	var state_value = payload_parser.data
	if not state_value is Dictionary:
		return _failure("invalid_payload", "存档载荷不是有效状态。")
	var normalized := _normalize_snapshot(state_value)
	if not bool(normalized.get("ok", false)):
		return normalized
	var result := {
		"ok": true,
		"code": "loaded",
		"state": normalized.get("state", {}),
		"saved_at_unix": int(envelope.get("saved_at_unix", 0)),
	}
	if stored_version < SAVE_VERSION:
		result["migrated_from_version"] = stored_version
	return result


func _normalize_snapshot(snapshot: Dictionary) -> Dictionary:
	var preflight := _preflight_snapshot(snapshot)
	if not bool(preflight.get("ok", false)):
		return preflight
	var upgraded := GameStateScript.ensure_v2(snapshot)
	var era_value = upgraded.get("current_era", null)
	var player_value = upgraded.get("player", null)
	var memories_value = upgraded.get("recent_memories", null)
	if not era_value is String or str(era_value).strip_edges().is_empty():
		return _failure("invalid_state", "存档缺少有效时代。")
	if not VALID_ERAS.has(str(era_value)):
		return _failure("invalid_state", "存档中的时代不受当前版本支持。")
	if not player_value is Dictionary:
		return _failure("invalid_state", "存档缺少角色状态。")
	if not memories_value is Array:
		return _failure("invalid_state", "存档缺少近期记忆。")

	var source_player: Dictionary = player_value
	var name_value = source_player.get("name", null)
	var realm_value = source_player.get("realm", null)
	var realm_id_value = source_player.get("realm_id", null)
	var roots_value = source_player.get("roots", null)
	if not name_value is String or str(name_value).strip_edges().is_empty():
		return _failure("invalid_state", "存档中的道号无效。")
	if not realm_value is String or str(realm_value).strip_edges().is_empty():
		return _failure("invalid_state", "存档中的境界无效。")
	if not realm_id_value is String or not GameStateScript.REALM_IDS.has(str(realm_id_value)):
		return _failure("invalid_state", "存档中的境界 ID 无效。")
	if not roots_value is Array or roots_value.size() != 5:
		return _failure("invalid_state", "存档中的五行灵根无效。")

	var normalized_player := {
		"name": str(name_value).strip_edges().left(32),
		"realm": str(realm_value).strip_edges().left(32),
		"realm_id": str(realm_id_value),
	}
	for field in PLAYER_INT_FIELDS:
		if not source_player.has(field) or not _is_number(source_player[field]):
			return _failure("invalid_state", "存档角色字段 %s 无效。" % field)
		normalized_player[field] = int(source_player[field])

	if normalized_player.level < 1 or normalized_player.level > 9 or normalized_player.max_hp < 1 or normalized_player.max_mp < 0:
		return _failure("invalid_state", "存档中的境界或生命上限无效。")
	if normalized_player.realm_index < 0 or normalized_player.realm_index >= GameStateScript.REALM_IDS.size():
		return _failure("invalid_state", "存档中的境界序号无效。")
	if str(GameStateScript.REALM_IDS[normalized_player.realm_index]) != normalized_player.realm_id:
		return _failure("invalid_state", "存档中的境界 ID 与序号不一致。")
	if normalized_player.age < 0 or normalized_player.lifespan < 1:
		return _failure("invalid_state", "存档中的寿元无效。")
	if normalized_player.exp < 0 or normalized_player.spirit_stones < 0 or normalized_player.pills < 0:
		return _failure("invalid_state", "存档中的资源数值无效。")
	normalized_player.hp = clampi(normalized_player.hp, 0, normalized_player.max_hp)
	normalized_player.mp = clampi(normalized_player.mp, 0, normalized_player.max_mp)

	var normalized_roots: Array[int] = []
	for root_value in roots_value:
		if not _is_number(root_value):
			return _failure("invalid_state", "存档中的灵根数值无效。")
		var root_number := int(root_value)
		if root_number < 0 or root_number > 100000:
			return _failure("invalid_state", "存档中的灵根数值越界。")
		normalized_roots.append(root_number)
	normalized_player["roots"] = normalized_roots
	var path_value = source_player.get("path", null)
	if not path_value is Dictionary:
		return _failure("invalid_state", "存档中的道途维度无效。")
	var normalized_path := {}
	for path_id in GameStateScript.PATH_DIMENSIONS:
		if not path_value.has(path_id) or not _is_number(path_value[path_id]):
			return _failure("invalid_state", "存档道途字段 %s 无效。" % path_id)
		normalized_path[path_id] = clampi(int(path_value[path_id]), -100000, 100000)
	normalized_player["path"] = normalized_path
	var family_value = source_player.get("family", {})
	if not family_value is Dictionary:
		return _failure("invalid_state", "存档中的家世状态无效。")
	normalized_player["family"] = (family_value as Dictionary).duplicate(true)
	var statuses_value = source_player.get("statuses", [])
	if not statuses_value is Array:
		return _failure("invalid_state", "存档中的角色状态列表无效。")
	normalized_player["statuses"] = (statuses_value as Array).duplicate().slice(-64)

	var normalized_memories: Array[String] = []
	for memory_value in memories_value:
		if not memory_value is String:
			return _failure("invalid_state", "存档中的近期记忆无效。")
		var memory := str(memory_value).strip_edges().left(512)
		if not memory.is_empty():
			normalized_memories.append(memory)
	while normalized_memories.size() > 64:
		normalized_memories.pop_front()

	var feedback_value = upgraded.get("feedback", "旧玉从沉眠中醒来。")
	if not feedback_value is String:
		feedback_value = "旧玉从沉眠中醒来。"
	var current_era_id := str(upgraded.get("current_era_id", ""))
	if not GameStateScript.ERA_IDS.has(current_era_id):
		return _failure("invalid_state", "存档中的时代 ID 无效。")
	for required_dictionary in ["legacy", "world", "inventory", "combat", "story", "ai"]:
		if not upgraded.get(required_dictionary, null) is Dictionary:
			return _failure("invalid_state", "存档缺少 %s 状态。" % required_dictionary)
	var normalized_state := upgraded.duplicate(true)
	normalized_state["schema_version"] = SAVE_VERSION
	normalized_state["run_id"] = str(upgraded.get("run_id", "wendao-imported")).left(96)
	normalized_state["world_seed"] = int(upgraded.get("world_seed", 1)) & 0x7fffffff
	normalized_state["rng_cursor"] = clampi(int(upgraded.get("rng_cursor", 0)), 0, 0x7fffffff)
	normalized_state["generation"] = clampi(int(upgraded.get("generation", 1)), 1, 100000)
	normalized_state["turn"] = clampi(int(upgraded.get("turn", 0)), 0, 0x7fffffff)
	normalized_state["current_era_id"] = current_era_id
	normalized_state["current_era"] = str(era_value).strip_edges().left(32)
	normalized_state["player"] = normalized_player
	normalized_state["recent_memories"] = normalized_memories
	normalized_state["feedback"] = str(feedback_value).left(1024)
	normalized_state["life_closed"] = bool(upgraded.get("life_closed", false))
	_normalize_nested_state(normalized_state)
	return {
		"ok": true,
		"code": "valid",
		"state": normalized_state,
	}


func _preflight_snapshot(snapshot: Dictionary) -> Dictionary:
	var schema_value = snapshot.get("schema_version", 1)
	if not _is_number(schema_value):
		return _failure("invalid_state", "存档版本字段无效。")
	var schema_version := int(schema_value)
	if schema_version < MIN_READABLE_VERSION or schema_version > SAVE_VERSION:
		return _failure("invalid_state", "存档状态版本暂不受支持。")

	var era_value = snapshot.get("current_era", null)
	if not era_value is String or not VALID_ERAS.has(str(era_value)):
		return _failure("invalid_state", "存档中的时代无效或不受支持。")
	var player_value = snapshot.get("player", null)
	if not player_value is Dictionary:
		return _failure("invalid_state", "存档缺少有效角色状态。")
	var memories_value = snapshot.get("recent_memories", null)
	if not memories_value is Array:
		return _failure("invalid_state", "存档中的近期记忆列表无效。")

	var source_player: Dictionary = player_value
	var name_value = source_player.get("name", null)
	var realm_value = source_player.get("realm", null)
	if not name_value is String or str(name_value).strip_edges().is_empty():
		return _failure("invalid_state", "存档中的道号格式无效。")
	if not realm_value is String or str(realm_value).strip_edges().is_empty():
		return _failure("invalid_state", "存档中的境界名称格式无效。")
	var realm_name := str(realm_value).strip_edges()
	if not GameStateScript.REALM_NAMES.has(realm_name) and not GameStateScript.LEGACY_REALM_ALIASES.has(realm_name):
		return _failure("invalid_state", "存档中的境界名称不受支持。")
	var roots_value = source_player.get("roots", null)
	if not roots_value is Array or roots_value.size() != 5:
		return _failure("invalid_state", "存档中的五行灵根格式无效。")
	for root_value in roots_value:
		if not _is_number(root_value):
			return _failure("invalid_state", "存档中的五行灵根数值类型无效。")
	for memory_value in memories_value:
		if not memory_value is String:
			return _failure("invalid_state", "存档中的近期记忆内容无效。")
	for field in PLAYER_INT_FIELDS:
		if source_player.has(field) and not _is_number(source_player[field]):
			return _failure("invalid_state", "存档角色字段 %s 类型无效。" % field)
	if source_player.has("path") and not source_player.path is Dictionary:
		return _failure("invalid_state", "存档中的道途维度格式无效。")
	if source_player.has("family") and not source_player.family is Dictionary:
		return _failure("invalid_state", "存档中的家世状态格式无效。")
	if source_player.has("statuses") and not source_player.statuses is Array:
		return _failure("invalid_state", "存档中的角色状态列表格式无效。")

	if schema_version >= 2:
		var era_id := str(snapshot.get("current_era_id", ""))
		if not GameStateScript.ERA_IDS.has(era_id) or str(GameStateScript.ERA_NAMES[era_id]) != str(era_value):
			return _failure("invalid_state", "存档中的时代 ID 与时代名称不一致。")
		for required_dictionary in ["legacy", "world", "inventory", "story"]:
			if not snapshot.get(required_dictionary, null) is Dictionary:
				return _failure("invalid_state", "存档缺少有效的 %s 状态。" % required_dictionary)
		var realm_id := str(source_player.get("realm_id", ""))
		var realm_index_value = source_player.get("realm_index", null)
		if not _is_number(realm_index_value):
			return _failure("invalid_state", "存档中的境界序号无效。")
		var realm_index := int(realm_index_value)
		if not GameStateScript.REALM_IDS.has(realm_id) or realm_index < 0 or realm_index >= GameStateScript.REALM_IDS.size():
			return _failure("invalid_state", "存档中的境界标识无效。")
		if str(GameStateScript.REALM_IDS[realm_index]) != realm_id:
			return _failure("invalid_state", "存档中的境界 ID 与序号冲突。")
		if str(GameStateScript.REALM_NAMES[realm_index]) != realm_name:
			return _failure("invalid_state", "存档中的境界名称与稳定 ID 冲突。")
	return {"ok": true, "code": "preflight_valid"}


func _normalize_nested_state(state: Dictionary) -> void:
	var legacy: Dictionary = state.legacy
	legacy["generation"] = clampi(int(legacy.get("generation", state.generation)), 1, 100000)
	legacy["past_lives"] = _bounded_array(legacy.get("past_lives", []), 64)
	legacy["inherited_echoes"] = _bounded_array(legacy.get("inherited_echoes", []), 16)
	legacy["unresolved_threads"] = _bounded_array(legacy.get("unresolved_threads", []), 64)
	state["legacy"] = legacy
	var world: Dictionary = state.world
	world["year"] = clampi(int(world.get("year", 1)), 1, 0x7fffffff)
	world["age"] = clampi(int(world.get("age", 0)), 0, 0x7fffffff)
	world["history"] = _bounded_array(world.get("history", []), 128)
	world["factions"] = _bounded_array(world.get("factions", []), 128)
	world["npcs"] = _bounded_array(world.get("npcs", []), 512)
	world["active_events"] = _bounded_array(world.get("active_events", []), 64)
	state["world"] = world
	ItemSystemScript.normalize(state)
	CombatSystemScript.normalize(state)
	StorySystemScript.normalize(state)
	var story: Dictionary = state.story
	story["completed_event_ids"] = _bounded_array(story.get("completed_event_ids", []), 2048)
	story["life_event_ids"] = _bounded_array(story.get("life_event_ids", []), 512)
	story["resolved_arcs"] = _bounded_array(story.get("resolved_arcs", []), 256)
	story["unresolved_threads"] = _bounded_array(story.get("unresolved_threads", []), 128)
	state["story"] = story
	var ai: Dictionary = state.ai
	ai["enabled"] = bool(ai.get("enabled", true))
	ai["local_only"] = true
	ai["last_status"] = str(ai.get("last_status", "not_requested")).left(64)
	ai["last_backend"] = str(ai.get("last_backend", "")).left(96)
	ai["request_count"] = clampi(int(ai.get("request_count", 0)), 0, 1000000)
	ai["fallback_count"] = clampi(int(ai.get("fallback_count", 0)), 0, 1000000)
	state["ai"] = ai


func _bounded_array(value: Variant, maximum: int) -> Array:
	if not value is Array:
		return []
	var items: Array = (value as Array).duplicate(true)
	if items.size() > maximum:
		items = items.slice(items.size() - maximum)
	return items


func _restore_primary_from_backup() -> bool:
	var backup_file := FileAccess.open(_backup_path, FileAccess.READ)
	if backup_file == null:
		return false
	var contents := backup_file.get_as_text()
	backup_file.close()
	var temp_file := FileAccess.open(_temp_path, FileAccess.WRITE)
	if temp_file == null:
		return false
	temp_file.store_string(contents)
	temp_file.flush()
	temp_file.close()

	if FileAccess.file_exists(_corrupt_path):
		DirAccess.remove_absolute(_corrupt_path)
	var quarantined := false
	if FileAccess.file_exists(_save_path):
		if DirAccess.rename_absolute(_save_path, _corrupt_path) != OK:
			DirAccess.remove_absolute(_temp_path)
			return false
		quarantined = true
	var restore_error := DirAccess.rename_absolute(_temp_path, _save_path)
	if restore_error != OK:
		if quarantined:
			DirAccess.rename_absolute(_corrupt_path, _save_path)
		return false
	return true


func _resolve_root_path(root_override: String) -> String:
	if not root_override.strip_edges().is_empty():
		var requested := root_override.strip_edges()
		if requested.begins_with("user://"):
			return _default_root_path()
		if requested.begins_with("res://"):
			return ProjectSettings.globalize_path(requested).simplify_path()
		if requested.is_absolute_path():
			return requested.simplify_path()
		return ProjectSettings.globalize_path("res://").path_join(requested).simplify_path()
	return _default_root_path()


func _default_root_path() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://").path_join("..").path_join(".local").path_join("save").simplify_path()
	return OS.get_executable_path().get_base_dir().path_join("save").simplify_path()


func _ensure_root_directory() -> Dictionary:
	if DirAccess.dir_exists_absolute(_root_path):
		return {"ok": true, "code": "directory_ready"}
	var create_error := DirAccess.make_dir_recursive_absolute(_root_path)
	if create_error != OK:
		return _failure("directory_failed", "无法创建存档目录 %s：%s。请将游戏放在可写的 D 盘目录。" % [
			_root_path, error_string(create_error)])
	return {"ok": true, "code": "directory_created"}


func _sha256(value: String) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(value.to_utf8_buffer()) != OK:
		return ""
	return context.finish().hex_encode()


func _constant_time_equal(left: String, right: String) -> bool:
	if left.length() != right.length():
		return false
	var difference := 0
	for index in range(left.length()):
		difference |= left.unicode_at(index) ^ right.unicode_at(index)
	return difference == 0


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _safe_slot_name(value: String) -> String:
	var safe := ""
	for index in range(value.length()):
		var character := value.substr(index, 1)
		if "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-".contains(character):
			safe += character
	return safe.left(32) if not safe.is_empty() else "main"


func _failure(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
