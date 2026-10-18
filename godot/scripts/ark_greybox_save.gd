extends RefCounted

## Prototype-only save slot. In the editor this resolves under the worktree's
## .local/save directory (D:), never under user:// / AppData on C:.

const FORMAT := "wendao-ark-greybox"
const VERSION := 1
const FILE_NAME := "ark_greybox_v1.json"

var _root_path := ""
var _save_path := ""
var _backup_path := ""
var _temp_path := ""


func _init(root_override: String = "") -> void:
	if not root_override.strip_edges().is_empty():
		_root_path = root_override.simplify_path()
	else:
		_root_path = ProjectSettings.globalize_path("res://../.local/save").simplify_path()
	_save_path = _root_path.path_join(FILE_NAME)
	_backup_path = _save_path + ".backup"
	_temp_path = _save_path + ".tmp"


func save_state(state: Dictionary) -> Dictionary:
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
	file.store_string(JSON.stringify(envelope, "\t"))
	file.flush()
	file.close()

	var moved_primary := false
	if FileAccess.file_exists(_save_path):
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
	if bool(primary.get("ok", false)):
		return primary
	var backup := _read_path(_backup_path)
	if bool(backup.get("ok", false)):
		backup["recovered"] = true
		return backup
	return {"ok": false, "code": "no_valid_save"}


func clear_for_test() -> void:
	for path in [_save_path, _backup_path, _temp_path]:
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
	var raw := file.get_as_text()
	file.close()
	var outer := JSON.new()
	if outer.parse(raw) != OK or not outer.data is Dictionary:
		return {"ok": false, "code": "invalid_envelope"}
	var envelope: Dictionary = outer.data
	if str(envelope.get("format", "")) != FORMAT or int(envelope.get("version", -1)) != VERSION:
		return {"ok": false, "code": "unsupported_format"}
	var payload_value = envelope.get("payload", null)
	if not payload_value is String or _sha256(str(payload_value)) != str(envelope.get("sha256", "")):
		return {"ok": false, "code": "checksum_mismatch"}
	var inner := JSON.new()
	if inner.parse(str(payload_value)) != OK or not inner.data is Dictionary:
		return {"ok": false, "code": "invalid_payload"}
	return {"ok": true, "state": (inner.data as Dictionary).duplicate(true), "path": path}


func _sha256(value: String) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(value.to_utf8_buffer()) != OK:
		return ""
	return context.finish().hex_encode()
