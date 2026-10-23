extends RefCounted

## Prototype-only save slot. In the editor this resolves under the worktree's
## .local/save directory (D:), never under user:// / AppData on C:.

const FORMAT := "wendao-ark-greybox"
const VERSION := 1
const FILE_NAME := "ark_greybox_v1.json"
const MAX_SCHEMA_VERSION := 36
const SAILMAKER_AWNING_SEW_SECONDS := 3.0
const SAILMAKER_AWNING_INSTALL_SECONDS := 2.0
const MAX_FILE_BYTES := 16 * 1024 * 1024

var _root_path := ""
var _save_path := ""
var _backup_path := ""
var _temp_path := ""
var _corrupt_path := ""


func _init(root_override: String = "") -> void:
	var requested := root_override.strip_edges()
	if not requested.is_empty() and not requested.begins_with("user://"):
		if requested.begins_with("res://"):
			_root_path = ProjectSettings.globalize_path(requested).simplify_path()
		elif requested.is_absolute_path():
			_root_path = requested.simplify_path()
		else:
			_root_path = ProjectSettings.globalize_path("res://").path_join(requested).simplify_path()
	else:
		# Keep the established location in exports too: changing it without a
		# migration would hide saves made by earlier prototype releases.
		_root_path = ProjectSettings.globalize_path("res://../.local/save").simplify_path()
	_save_path = _root_path.path_join(FILE_NAME)
	_backup_path = _save_path + ".backup"
	_temp_path = _save_path + ".tmp"
	_corrupt_path = _save_path + ".corrupt"


func save_state(state: Dictionary) -> Dictionary:
	var validation := _validate_state(state)
	if not validation.get("ok", false):
		return validation
	var primary := _read_path(_save_path)
	var backup := _read_path(_backup_path)
	for existing in [primary, backup]:
		if existing.get("code", "") == "unsupported_version":
			return existing
	if not primary.get("ok", false) and not backup.get("ok", false) and (FileAccess.file_exists(_save_path) or FileAccess.file_exists(_backup_path)):
		return {"ok": false, "code": "corrupt_save"}
	var create_error := DirAccess.make_dir_recursive_absolute(_root_path)
	if create_error != OK and not DirAccess.dir_exists_absolute(_root_path):
		return {"ok": false, "error": "save_directory:%s" % error_string(create_error)}
	var payload := JSON.stringify(state)
	var envelope := {
		"format": FORMAT,
		"version": VERSION,
		"payload": payload,
		"sha256": _sha256(payload),
	}
	var file := FileAccess.open(_temp_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "save_write:%s" % error_string(FileAccess.get_open_error())}
	var contents := JSON.stringify(envelope, "\t")
	if contents.to_utf8_buffer().size() > MAX_FILE_BYTES:
		file.close()
		DirAccess.remove_absolute(_temp_path)
		return {"ok": false, "code": "save_too_large"}
	file.store_string(contents)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or not _read_path(_temp_path).get("ok", false):
		DirAccess.remove_absolute(_temp_path)
		return {"ok": false, "code": "save_write_failed"}

	var moved_primary := false
	if FileAccess.file_exists(_save_path) and not primary.get("ok", false):
		if not _quarantine_primary():
			DirAccess.remove_absolute(_temp_path)
			return {"ok": false, "code": "save_quarantine_failed"}
	elif FileAccess.file_exists(_save_path):
		if FileAccess.file_exists(_backup_path):
			var remove_error := DirAccess.remove_absolute(_backup_path)
			if remove_error != OK:
				DirAccess.remove_absolute(_temp_path)
				return {"ok": false, "error": "save_backup_remove:%s" % error_string(remove_error)}
		var backup_error := DirAccess.rename_absolute(_save_path, _backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(_temp_path)
			return {"ok": false, "error": "save_backup_rotate:%s" % error_string(backup_error)}
		moved_primary = true
	var replace_error := DirAccess.rename_absolute(_temp_path, _save_path)
	if replace_error != OK:
		if moved_primary and not FileAccess.file_exists(_save_path):
			DirAccess.rename_absolute(_backup_path, _save_path)
		return {"ok": false, "error": "save_replace:%s" % error_string(replace_error)}
	return {"ok": true, "path": _save_path}


func load_state() -> Dictionary:
	var primary := _read_path(_save_path)
	if bool(primary.get("ok", false)) or primary.get("code", "") == "unsupported_version":
		return primary
	var backup := _read_path(_backup_path)
	if backup.get("code", "") == "unsupported_version":
		return backup
	if bool(backup.get("ok", false)):
		backup["recovered"] = true
		backup["repaired"] = _restore_primary_from_backup()
		return backup
	return {"ok": false, "code": "corrupt_save" if FileAccess.file_exists(_save_path) or FileAccess.file_exists(_backup_path) else "no_save"}


func clear_for_test() -> void:
	for path in [_save_path, _backup_path, _temp_path, _corrupt_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func get_save_path() -> String:
	return _save_path


func _read_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "code": "missing"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "code": "read_failed"}
	if file.get_length() <= 0 or file.get_length() > MAX_FILE_BYTES:
		file.close()
		return {"ok": false, "code": "invalid_size"}
	var raw := file.get_as_text()
	file.close()
	var outer := JSON.new()
	if outer.parse(raw) != OK or not outer.data is Dictionary:
		return {"ok": false, "code": "invalid_envelope"}
	var envelope: Dictionary = outer.data
	if envelope.get("format", "") != FORMAT:
		return {"ok": false, "code": "unsupported_format"}
	var version_value: Variant = envelope.get("version", null)
	if not _is_integer(version_value) or float(version_value) < 1:
		return {"ok": false, "code": "invalid_version"}
	if float(version_value) > VERSION:
		return {"ok": false, "code": "unsupported_version"}
	var payload_value = envelope.get("payload", null)
	if not payload_value is String or _sha256(str(payload_value)) != str(envelope.get("sha256", "")):
		return {"ok": false, "code": "checksum_mismatch"}
	var inner := JSON.new()
	if inner.parse(str(payload_value)) != OK or not inner.data is Dictionary:
		return {"ok": false, "code": "invalid_payload"}
	var validation := _validate_state(inner.data)
	if not validation.get("ok", false):
		return validation
	return {"ok": true, "state": (inner.data as Dictionary).duplicate(true), "path": path}


func _sha256(value: String) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(value.to_utf8_buffer()) != OK:
		return ""
	return context.finish().hex_encode()


func _validate_state(state: Dictionary) -> Dictionary:
	var schema: Variant = state.get("schema_version", null)
	if not _is_integer(schema) or float(schema) < 1:
		return {"ok": false, "code": "invalid_schema"}
	if float(schema) > MAX_SCHEMA_VERSION:
		return {"ok": false, "code": "unsupported_version"}
	if int(schema) >= 35:
		var elapsed: Variant = state.get("life_period_elapsed")
		var renewed: Variant = state.get("last_shore_replenish_day")
		var day: Variant = state.get("day_count")
		if not (elapsed is float or elapsed is int) or not is_finite(float(elapsed)) or float(elapsed) < 0.0 or float(elapsed) >= 180.0:
			return {"ok": false, "code": "invalid_state"}
		if not _is_integer(day) or float(day) < 1 or not _is_integer(renewed) or float(renewed) < 1 or float(renewed) > float(day):
			return {"ok": false, "code": "invalid_state"}
	if int(schema) >= 36 and not _valid_sailmaker_awning_work(state):
		return {"ok": false, "code": "invalid_state"}
	if not _json_safe(state):
		return {"ok": false, "code": "invalid_state"}
	return {"ok": true}


func _valid_sailmaker_awning_work(state: Dictionary) -> bool:
	var phase: Variant = state.get("sailmaker_awning_phase")
	var sewing: Variant = state.get("sailmaker_awning_sewing_elapsed")
	var installing: Variant = state.get("sailmaker_awning_install_elapsed")
	if not phase is String or not phase in ["unstarted", "to_sew", "sewing", "carrying", "installing", "complete"]:
		return false
	for timer in [sewing, installing]:
		if not (timer is int or timer is float) or not is_finite(float(timer)) or float(timer) < 0.0:
			return false
	if float(sewing) > SAILMAKER_AWNING_SEW_SECONDS or float(installing) > SAILMAKER_AWNING_INSTALL_SECONDS:
		return false
	for field in ["sailmaker_met", "sailmaker_boarded", "sailmaker_awning_raised", "shelter_built"]:
		if not state.get(field) is bool:
			return false
	var completed: bool = state.sailmaker_awning_raised
	if completed != (phase == "complete"):
		return false
	if phase in ["unstarted", "to_sew", "complete"] and (float(sewing) != 0.0 or float(installing) != 0.0):
		return false
	if phase == "sewing" and (float(sewing) >= SAILMAKER_AWNING_SEW_SECONDS or float(installing) != 0.0):
		return false
	if phase in ["carrying", "installing"] and float(sewing) != SAILMAKER_AWNING_SEW_SECONDS:
		return false
	if phase == "carrying" and float(installing) != 0.0:
		return false
	if phase == "installing" and float(installing) >= SAILMAKER_AWNING_INSTALL_SECONDS:
		return false
	if phase != "unstarted":
		if not state.sailmaker_met or not state.sailmaker_boarded or not state.shelter_built:
			return false
		# Completed legacy gifts contain no reconstructed sewing history; only
		# unfinished work requires explicit next-day eligibility.
		if phase != "complete":
			var joined: Variant = state.get("sailmaker_joined_day")
			if not _is_integer(joined) or float(joined) < 0.0 or float(joined) >= float(state.day_count):
				return false
	return true


func _is_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value)) == float(value)


func _json_safe(value: Variant, depth: int = 0) -> bool:
	if depth > 64:
		return false
	if value is float:
		return is_finite(value)
	if value is Dictionary:
		for key in value:
			if not key is String or not _json_safe(value[key], depth + 1):
				return false
		return true
	if value is Array:
		for entry in value:
			if not _json_safe(entry, depth + 1):
				return false
		return true
	return value == null or value is String or value is int or value is bool


func _quarantine_primary() -> bool:
	if FileAccess.file_exists(_corrupt_path) and DirAccess.remove_absolute(_corrupt_path) != OK:
		return false
	return DirAccess.rename_absolute(_save_path, _corrupt_path) == OK


func _restore_primary_from_backup() -> bool:
	if DirAccess.copy_absolute(_backup_path, _temp_path) != OK or not _read_path(_temp_path).get("ok", false):
		DirAccess.remove_absolute(_temp_path)
		return false
	var quarantined := FileAccess.file_exists(_save_path)
	if quarantined and not _quarantine_primary():
		DirAccess.remove_absolute(_temp_path)
		return false
	if DirAccess.rename_absolute(_temp_path, _save_path) != OK:
		if quarantined:
			DirAccess.rename_absolute(_corrupt_path, _save_path)
		return false
	return true
