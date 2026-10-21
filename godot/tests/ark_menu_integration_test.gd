extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const ArkSave = preload("res://scripts/ark_greybox_save.gd")
const TestPaths = preload("res://tests/ark_test_paths.gd")

var failures: Array[String] = []
var test_root: String
var save_service: RefCounted


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	test_root = ProjectSettings.globalize_path("res://../.local/test_ark_menu_integration").simplify_path()
	assert(TestPaths.is_safe_save_root(test_root), "all menu writes must stay in this isolated test directory")
	var default_before := _default_save_fingerprint()
	save_service = ArkSave.new(test_root)
	save_service.clear_for_test()
	DirAccess.make_dir_recursive_absolute(test_root)
	var legacy_path := test_root.path_join("save_slot_1.txt")
	var legacy_bytes := "legacy slot sentinel: never import, reset, or change"
	_write(legacy_path, legacy_bytes)
	var menu := _new_menu()
	await _settle()
	for viewport_size in [Vector2i(1280, 720), Vector2i(1440, 900)]:
		root.size = viewport_size
		await _settle()
		_check_menu(menu)
	_expect(not FileAccess.file_exists(save_service.get_save_path()), "opening a fresh menu does not create a save")
	var enter := menu.find_child("ArkEnterButton", true, false) as Button
	_expect(enter.text == "进入归舟", "empty independent slot offers entry, never destructive reset")
	enter.pressed.emit()
	enter.pressed.emit()
	await _settle()
	var game := current_scene
	_expect(game != null and game.scene_file_path == "res://scenes/ark_greybox.tscn", "entry opens the actual 3D Ark scene")
	if game == null or not game is Node3D:
		_finish(default_before)
		return
	_freeze(game)
	_expect(_ark_scene_count() == 1, "rapid repeated entry creates exactly one Ark")
	_expect(str(game.get("save_root_override")) == test_root, "entry forwards the isolated save root before Ark ready")
	_expect(int(game.get("wood")) == 1, "first entry uses the existing Ark starting state")
	game.set("wood", 11)
	(game.find_child("ArkReturnToMainButton", true, false) as Button).pressed.emit()
	await _settle()
	menu = current_scene
	_check_menu(menu)
	_expect(str(menu.get("save_root_override")) == test_root, "real return keeps the same isolated root")
	_expect((menu.find_child("ArkEnterButton", true, false) as Button).text == "继续归舟", "saved progress offers continue")
	_expect(int(save_service.load_state().get("state", {}).get("wood", -1)) == 11, "return saves current materials")
	(menu.find_child("ArkEnterButton", true, false) as Button).pressed.emit()
	await _settle()
	game = current_scene
	_freeze(game)
	_expect(int(game.get("wood")) == 11, "continue restores progress without resetting it")
	_expect(str(game.get("save_root_override")) == test_root, "continued Ark still uses isolated root")
	var save_before := FileAccess.get_file_as_string(save_service.get_save_path())
	var blocked_temp: String = save_service.get_save_path() + ".tmp"
	assert(DirAccess.make_dir_absolute(blocked_temp) == OK)
	(game.find_child("ArkReturnToMainButton", true, false) as Button).pressed.emit()
	await _settle()
	_expect(current_scene == game, "failed return-save keeps the player in Ark")
	_expect(FileAccess.get_file_as_string(save_service.get_save_path()) == save_before, "failed return-save preserves existing bytes")
	DirAccess.remove_absolute(blocked_temp)
	(game.find_child("ArkReturnToMainButton", true, false) as Button).pressed.emit()
	await _settle()
	_expect(current_scene.scene_file_path == "res://scenes/main.tscn", "return succeeds after the write obstruction is removed")
	await _remove_current()

	# Neither merely viewing the menu nor entering/returning may erase an
	# unreadable or newer save. Ark's existing read-only protection owns this.
	for damaged_kind in ["future", "corrupt"]:
		save_service.clear_for_test()
		assert(save_service.save_state({"schema_version": 33, "wood": 23}).get("ok", false))
		var protected_bytes := "intentionally corrupt save; preserve verbatim"
		if damaged_kind == "future":
			var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_service.get_save_path()))
			envelope.version = 999
			protected_bytes = JSON.stringify(envelope)
		_write(save_service.get_save_path(), protected_bytes)
		menu = _new_menu()
		await _settle()
		_expect(FileAccess.get_file_as_string(save_service.get_save_path()) == protected_bytes, damaged_kind + " menu view is read-only")
		(menu.find_child("ArkEnterButton", true, false) as Button).pressed.emit()
		await _settle()
		game = current_scene
		_freeze(game)
		_expect(bool(game.get_meta("save_load_blocked", false)), damaged_kind + " entry visibly protects the unreadable slot")
		(game.find_child("ArkReturnToMainButton", true, false) as Button).pressed.emit()
		await _settle()
		_expect(current_scene.scene_file_path == "res://scenes/main.tscn", damaged_kind + " read-only game still permits return")
		_expect(FileAccess.get_file_as_string(save_service.get_save_path()) == protected_bytes, damaged_kind + " entry and return preserve bytes")
		await _remove_current()
	# A direct Ark launch has no menu-created session metadata. Its real return
	# must still keep the explicit root, rather than falling into a normal save.
	save_service.clear_for_test()
	if has_meta("ark_menu_save_root_override"):
		remove_meta("ark_menu_save_root_override")
	game = (load("res://scenes/ark_greybox.tscn") as PackedScene).instantiate()
	game.set("save_root_override", test_root)
	root.add_child(game)
	current_scene = game
	await _settle()
	_freeze(game)
	game.set("wood", 29)
	(game.find_child("ArkReturnToMainButton", true, false) as Button).pressed.emit()
	await _settle()
	menu = current_scene
	_expect(str(menu.get("save_root_override")) == test_root, "direct Ark return forwards the explicit save root")
	(menu.find_child("ArkEnterButton", true, false) as Button).pressed.emit()
	await _settle()
	game = current_scene
	_freeze(game)
	_expect(str(game.get("save_root_override")) == test_root and int(game.get("wood")) == 29, "continue after direct Ark return stays isolated and restores its progress")
	await _remove_current()
	_expect(FileAccess.get_file_as_string(legacy_path) == legacy_bytes, "legacy slot remains unread and unchanged")
	DirAccess.remove_absolute(legacy_path)
	save_service.clear_for_test()
	if has_meta("ark_menu_save_root_override"):
		remove_meta("ark_menu_save_root_override")
	_finish(default_before)


func _new_menu() -> Control:
	var menu := MainScene.instantiate() as Control
	menu.set("save_root_override", test_root)
	root.add_child(menu)
	current_scene = menu
	return menu


func _check_menu(menu: Node) -> void:
	_expect(menu != null and menu.scene_file_path == "res://scenes/main.tscn", "stable main.tscn resolves to the Ark menu")
	if menu == null:
		return
	var title := menu.find_child("ArkMenuTitle", true, false) as Label
	_expect(title != null and title.text == "问道：归舟", "the only product title is 问道：归舟")
	if title != null:
		_expect(title.get_theme_font("font").has_char(0x95ee) and title.get_theme_font("font").has_char(0x821f), "menu Chinese glyphs come from the runtime font")
	var buttons := menu.find_children("*", "Button", true, false)
	_expect(buttons.size() == 2, "only enter/continue and quit actions exist; no old 2D entry or reset button")
	for node_name in ["ArkMenuPanel", "ArkMenuTitle", "ArkEnterButton", "ArkQuitButton", "ArkMenuControlsTitle", "ArkMenuSaveNotice", "ArkMenuFooter"]:
		var control := menu.find_child(node_name, true, false) as Control
		_expect(control != null and root.get_visible_rect().encloses(control.get_global_rect()), "%s fits %s without clipping" % [node_name, root.size])
	var scroll := menu.find_child("ArkMenuScroll", true, false) as ScrollContainer
	_expect(scroll != null and not scroll.get_v_scroll_bar().visible, "required desktop menu sizes need no scrolling")
	for old_entry in ["ContinueButton", "MenuStartButton", "LegacyImportButton", "MenuAudioSettingsButton", "DaoNameInput"]:
		_expect(menu.find_child(old_entry, true, false) == null, "obsolete action removed: " + old_entry)
	var source: String = menu.get_script().source_code
	for old_script in ["game_state.gd", "combat_system.gd", "save_service.gd", "legacy_save_importer.gd", "chronicle_system.gd"]:
		_expect(not source.contains(old_script), "menu has no dependency on " + old_script)


func _freeze(game: Node) -> void:
	game.set_process(false)
	game.set_physics_process(false)


func _ark_scene_count() -> int:
	var count := 0
	for child in root.get_children():
		if child.scene_file_path == "res://scenes/ark_greybox.tscn":
			count += 1
	return count


func _remove_current() -> void:
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	await _settle()


func _settle() -> void:
	for _frame in range(4):
		await process_frame


func _default_save_fingerprint() -> Dictionary:
	var path: String = ArkSave.new().get_save_path().get_base_dir()
	var result := {}
	if DirAccess.dir_exists_absolute(path):
		for filename in DirAccess.get_files_at(path):
			result[filename] = FileAccess.get_sha256(path.path_join(filename))
	return result


func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(value)
	file.close()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish(default_before: Dictionary) -> void:
	_expect(_default_save_fingerprint() == default_before, "normal .local/save contents are unchanged")
	if failures.is_empty():
		print("ARK_MENU_INTEGRATION_TEST_OK: entry, continue, return, repeated input, protected saves, layout, independent roots")
		quit(0)
	else:
		for failure in failures:
			push_error("ARK_MENU_INTEGRATION_TEST_FAILED: " + failure)
		quit(1)
