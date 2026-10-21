extends SceneTree

const ArkSave = preload("res://scripts/ark_greybox_save.gd")
const TestPaths = preload("res://tests/ark_test_paths.gd")

var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_ark_persistence_sanitize_audit").simplify_path()
	assert(TestPaths.is_safe_save_root(save_root))
	var service := ArkSave.new(save_root)
	service.clear_for_test()
	var snapshot := {
		"schema_version": 33, "wood": 17, "raw_shellfish": 9,
		"day_count": {"bad": true}, "stored_wood": [], "weather_phase": null,
		"shelter_built": "false", "collected_ids": null,
		"player_position": {"x": [], "y": "bad", "z": null},
		"ark_position": {"x": {}, "y": 0, "z": 0}, "ark_yaw": [],
		"storage_quarter_turns": {"bad": true}, "workbench_quarter_turns": [1, 2],
		"world_events": [{"sequence": [], "id": "bad"}, {"sequence": 7, "id": "valid", "facts": {}}],
	}
	_expect(service.save_state(snapshot).get("ok", false), "Partially malformed optional fields remain recoverable")
	var scene := load("res://scenes/ark_greybox.tscn") as PackedScene
	var game := scene.instantiate()
	game.set("save_root_override", save_root)
	root.add_child(game)
	await process_frame
	_expect(int(game.call("_build_save_state").get("schema_version")) == ArkSave.MAX_SCHEMA_VERSION, "Save service schema ceiling must match the current controller")
	_expect(int(game.get("wood")) == 17 and int(game.get("raw_shellfish")) == 9, "Keep valid resources from a partially malformed save")
	_expect(int(game.get("day_count")) == 1 and int(game.get("stored_wood")) == 0, "Malformed numeric fields use safe defaults")
	_expect(not game.get("shelter_built"), "String false must not become true")
	_expect((game.get("collected_ids") as Array).is_empty(), "Malformed collected list cannot interrupt remaining load")
	_expect(int(game.get("storage_quarter_turns")) == 0 and int(game.get("workbench_quarter_turns")) == 0, "Malformed fixture rotations keep legacy orientation")
	var player := game.get("player") as Node3D
	_expect(player.position.is_finite(), "Malformed coordinates cannot poison player position")
	for event in game.get("world_events"):
		_expect(event.get("sequence") is int or event.get("sequence") is float, "Malformed event sequences are filtered")
	game.call("_toggle_world_chart")
	_press_f5(game)
	var status := game.find_child("ArkSaveStatus", true, false) as Label
	_expect(status != null and status.visible and status.text.contains("旧玉"), "Successful chart F5 has visible confirmation")
	var primary_before_failure := FileAccess.get_file_as_string(service.get_save_path())
	var temp_path := service.get_save_path() + ".tmp"
	assert(DirAccess.make_dir_absolute(temp_path) == OK)
	_press_f5(game)
	_expect(status != null and status.visible and status.text.contains("未写入"), "Chart F5 reports filesystem failure rather than success")
	_expect(FileAccess.get_file_as_string(service.get_save_path()) == primary_before_failure, "Filesystem failure leaves prior good save untouched")
	DirAccess.remove_absolute(temp_path)
	_press_f5(game)
	_expect(str(game.get_meta("save_warning", "")).is_empty() and status.text.contains("旧玉"), "Retry after repaired write path clears stale failure status")
	game.call("_toggle_world_chart")
	game.queue_free()
	await process_frame
	service.clear_for_test()
	for failure_kind in ["future", "corrupt"]:
		service.save_state({"schema_version": 33, "wood": 44})
		var original := "broken save"
		if failure_kind == "future":
			var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(service.get_save_path()))
			envelope.version = 999
			original = JSON.stringify(envelope)
		_write(service.get_save_path(), original)
		game = scene.instantiate()
		game.set("save_root_override", save_root)
		root.add_child(game)
		await process_frame
		_expect(game.get_meta("save_load_blocked", false), "Unreadable/future files explicitly block automatic overwrite")
		_expect(str(game.get_meta("save_warning", "")).contains("不会保存"), "Loading blocked save warns that this temporary session is unsaved")
		game.call("_toggle_world_chart")
		_press_f5(game)
		var notice := game.find_child("ArkSaveStatus", true, false) as Label
		_expect(notice != null and notice.visible and notice.text.contains("不会保存"), "Chart F5 must display the real save failure above its overlay")
		game.call("_toggle_world_chart")
		game.set("editing_fixture_id", "storage")
		_press_f5(game)
		_expect(str(game.get("message")).contains("不会保存"), "Fixture edit F5 must preserve detailed save failure")
		game.set("editing_fixture_id", "")
		_expect(FileAccess.get_file_as_string(service.get_save_path()) == original, "Manual/automatic failed writes preserve unreadable source bytes")
		game.queue_free()
		await process_frame
		_expect(FileAccess.get_file_as_string(service.get_save_path()) == original, "Exit must not replace the blocked save with fresh defaults")
		service.clear_for_test()
	DirAccess.remove_absolute(save_root)
	if failures.is_empty():
		print("ARK_PERSISTENCE_SANITIZE_AUDIT_TEST_OK: malformed fields default safely without dropping valid resources")
		quit(0)
	else:
		for failure in failures:
			push_error("ARK_PERSISTENCE_SANITIZE_AUDIT_TEST_FAILED: " + failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _press_f5(game: Node) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_F5
	event.pressed = true
	game.call("_unhandled_key_input", event)


func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(value)
	file.close()
