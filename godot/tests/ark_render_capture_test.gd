extends SceneTree
## Run with a real display and GL Compatibility; headless runs are not visual QA.

const MainScene = preload("res://scenes/main.tscn")
const ArkSave = preload("res://scripts/ark_greybox_save.gd")
const TestPaths = preload("res://tests/ark_test_paths.gd")

var failures: Array[String] = []
var output_root: String


func _initialize() -> void:
	root.mode = Window.MODE_MINIMIZED
	root.unfocusable = true
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("ARK_RENDER_CAPTURE_TEST_FAILED: a real display is required; headless is not a pixel-render pass")
		quit(1)
		return
	var test_root := ProjectSettings.globalize_path("res://../.local/test_ark_render").simplify_path()
	assert(TestPaths.is_safe_save_root(test_root), "render saves must stay in this isolated test directory")
	output_root = OS.get_environment("ARK_RENDER_CAPTURE_ROOT")
	if output_root.is_empty():
		output_root = ProjectSettings.globalize_path("res://../.tmp/ark-render-captures").simplify_path()
	DirAccess.make_dir_recursive_absolute(output_root)
	var service := ArkSave.new(test_root)
	service.clear_for_test()
	var menu := MainScene.instantiate() as Control
	menu.set("save_root_override", test_root)
	root.add_child(menu)
	current_scene = menu
	for viewport_size in [Vector2i(1280, 720), Vector2i(1440, 900)]:
		root.size = viewport_size
		await _settle()
		_check_menu(menu)
		await _capture("menu_%sx%s.png" % [viewport_size.x, viewport_size.y], viewport_size)
	root.size = Vector2i(1280, 720)
	await _settle()
	(menu.find_child("ArkEnterButton", true, false) as Button).pressed.emit()
	await _settle()
	var game := current_scene
	_expect(game != null and game is Node3D, "the menu opens a volumetric Ark scene")
	if game == null or not game is Node3D:
		_finish()
		return
	game.set_process(false)
	game.set_physics_process(false)
	_expect(str(game.get("save_root_override")) == test_root, "render entry uses only the isolated save")
	_expect(game.get_node_or_null("Sea") is MeshInstance3D, "actual Ark ocean geometry is rendered")
	game.call("_update_hud")
	await _settle()
	# Deliver the actual fresh starting state, not the save-test mutation.
	await _capture("ark_1280x720.png", Vector2i(1280, 720))
	game.set("wood", 17)
	(game.find_child("ArkReturnToMainButton", true, false) as Button).pressed.emit()
	await _settle()
	menu = current_scene as Control
	_check_menu(menu)
	_expect(str(menu.get("save_root_override")) == test_root, "render return preserves the isolated save root")
	_expect((menu.find_child("ArkEnterButton", true, false) as Button).text == "继续归舟", "real return changes entry into continue")
	_expect(int(service.load_state().get("state", {}).get("wood", -1)) == 17, "real return persisted the Ark state")
	await _capture("menu_return_1280x720.png", Vector2i(1280, 720))
	current_scene.queue_free()
	current_scene = null
	await process_frame
	service.clear_for_test()
	if has_meta("ark_menu_save_root_override"):
		remove_meta("ark_menu_save_root_override")
	_finish()


func _check_menu(menu: Control) -> void:
	_expect(menu != null, "Ark menu exists")
	if menu == null:
		return
	for node_name in ["ArkMenuPanel", "ArkMenuTitle", "ArkEnterButton", "ArkQuitButton", "ArkMenuControlsTitle", "ArkMenuSaveNotice", "ArkMenuFooter"]:
		var control := menu.find_child(node_name, true, false) as Control
		_expect(control != null and root.get_visible_rect().encloses(control.get_global_rect()), "%s fits %s" % [node_name, root.size])
	_expect(menu.find_children("*", "Button", true, false).size() == 2, "no old 2D action or destructive new-game action is rendered")
	var scroll := menu.find_child("ArkMenuScroll", true, false) as ScrollContainer
	_expect(scroll != null and not scroll.get_v_scroll_bar().visible, "desktop menu is fully visible without scrolling")


func _settle() -> void:
	for _frame in range(6):
		await process_frame
	RenderingServer.force_draw(false)


func _capture(filename: String, expected_size: Vector2i) -> void:
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		failures.append("empty render capture: " + filename)
		return
	_expect(image.get_size() == expected_size, "capture size is exact: " + filename)
	var colors := {}
	for y in range(0, image.get_height(), 31):
		for x in range(0, image.get_width(), 31):
			colors[image.get_pixel(x, y).to_html()] = true
	_expect(colors.size() > 8, "capture has rendered detail instead of a blank surface: " + filename)
	_expect(image.save_png(output_root.path_join(filename)) == OK, "PNG write succeeds: " + filename)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ARK_RENDER_CAPTURE_TEST_OK: real menu 1280x720/1440x900, 3D entry and saved return; " + output_root)
		quit(0)
	else:
		for failure in failures:
			push_error("ARK_RENDER_CAPTURE_TEST_FAILED: " + failure)
		quit(1)
