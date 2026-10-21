extends SceneTree

const ArkSave = preload("res://scripts/ark_greybox_save.gd")
const TestPaths = preload("res://tests/ark_test_paths.gd")

var failures: Array[String] = []
var test_root: String


func _init() -> void:
	test_root = ProjectSettings.globalize_path("res://../.local/test_ark_save_integrity_audit").simplify_path()
	assert(TestPaths.is_safe_save_root(test_root))
	DirAccess.make_dir_recursive_absolute(test_root)
	_test_recovery()
	_test_versions()
	_test_failed_write_preserves_files()
	_test_malformed_envelopes()
	_test_nonfinite_snapshot()
	if failures.is_empty():
		print("ARK_SAVE_INTEGRITY_AUDIT_TEST_OK: Ark recovery, version protection, malformed data and write failure checks passed")
		quit(0)
	else:
		for failure in failures:
			push_error("ARK_SAVE_INTEGRITY_AUDIT_TEST_FAILED: " + failure)
		quit(1)


func _test_recovery() -> void:
	var service := ArkSave.new(test_root)
	service.clear_for_test()
	_expect(service.save_state({"schema_version": 33, "wood": 8}).get("ok", false), "Ark initial save")
	_expect(service.save_state({"schema_version": 33, "wood": 12}).get("ok", false), "Ark second save")
	_write(service.get_save_path(), "broken primary")
	var recovered: Dictionary = service.load_state()
	_expect(recovered.get("ok", false) and recovered.get("recovered", false), "Ark recovers backup")
	_expect(service.save_state({"schema_version": 33, "wood": 15}).get("ok", false), "Ark save after recovery")
	_write(service.get_save_path(), "another broken primary")
	var second_recovery: Dictionary = service.load_state()
	_expect(second_recovery.get("ok", false) and second_recovery.get("state", {}).get("wood", -1) == 8,
		"Ark must retain the last valid backup after recovery and another save")
	service.clear_for_test()
	service.save_state({"schema_version": 33, "wood": 8})
	service.save_state({"schema_version": 33, "wood": 12})
	_write(service.get_save_path(), "broken before save without load")
	service.save_state({"schema_version": 33, "wood": 15})
	_write(service.get_save_path(), "broken again")
	_expect(service.load_state().get("ok", false), "Ark direct save must not rotate corrupt primary over valid backup")
	service.clear_for_test()


func _test_versions() -> void:
	var service := ArkSave.new(test_root)
	var state := {"schema_version": 33, "wood": 7}
	service.save_state(state)
	service.save_state(state)
	var path := service.get_save_path()
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	envelope.version = 999
	var future := JSON.stringify(envelope)
	_write(path, future)
	_expect(not service.load_state().get("ok", true), "Future envelope must not silently fall back to an older backup")
	_expect(FileAccess.get_file_as_string(path) == future, "Loading future envelope must not overwrite it")
	_expect(not service.save_state(state).get("ok", true), "Autosave must not overwrite future envelope")
	_expect(FileAccess.get_file_as_string(path) == future, "Future envelope remains byte-identical")
	service.clear_for_test()
	service.save_state(state)
	envelope = JSON.parse_string(FileAccess.get_file_as_string(path))
	state.schema_version = 999
	envelope.payload = JSON.stringify(state)
	envelope.sha256 = str(envelope.payload).sha256_text()
	future = JSON.stringify(envelope)
	_write(path, future)
	_expect(not service.save_state({"schema_version": 33}).get("ok", true), "Autosave must not overwrite future payload schema")
	_expect(FileAccess.get_file_as_string(path) == future, "Future schema remains byte-identical")
	service.clear_for_test()


func _test_failed_write_preserves_files() -> void:
	var service := ArkSave.new(test_root)
	var state := {"schema_version": 33, "wood": 7}
	service.save_state(state)
	service.save_state(state)
	var path := service.get_save_path()
	var backup := path + ".backup"
	var temp := path + ".tmp"
	var before_primary := FileAccess.get_file_as_string(path)
	var before_backup := FileAccess.get_file_as_string(backup)
	assert(DirAccess.make_dir_absolute(temp) == OK)
	_expect(not service.save_state(state).get("ok", true), "Failed temp open must report failure")
	_expect(FileAccess.get_file_as_string(path) == before_primary and FileAccess.get_file_as_string(backup) == before_backup,
		"Failed temp open must leave both primary and backup byte-identical")
	DirAccess.remove_absolute(temp)
	service.clear_for_test()


func _test_malformed_envelopes() -> void:
	var service := ArkSave.new(test_root)
	var state := {"schema_version": 33, "wood": 7}
	service.save_state(state)
	service.save_state(state)
	var path := service.get_save_path()
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for bad_version in [{"bad": true}, [], null, 1.5, "2", 0, -1]:
		envelope.version = bad_version
		_write(path, JSON.stringify(envelope))
		var recovered: Dictionary = service.load_state()
		_expect(recovered.get("ok", false) and recovered.get("recovered", false), "Malformed version field must recover safely")
	envelope = JSON.parse_string(FileAccess.get_file_as_string(path))
	for bad_schema in [0, -1]:
		state.schema_version = bad_schema
		envelope.payload = JSON.stringify(state)
		envelope.sha256 = str(envelope.payload).sha256_text()
		_write(path, JSON.stringify(envelope))
		var recovered: Dictionary = service.load_state()
		_expect(recovered.get("ok", false) and recovered.get("recovered", false), "Invalid lower schema must recover from backup instead of blocking it")
	service.clear_for_test()


func _test_nonfinite_snapshot() -> void:
	var service := ArkSave.new(test_root)
	_expect(not service.save_state({"schema_version": 33, "ark_yaw": NAN}).get("ok", true), "Ark rejects NaN instead of silently serializing null")
	service.clear_for_test()


func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(value)
	file.close()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
