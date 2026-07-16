extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const SaveServiceScript = preload("res://scripts/save_service.gd")
const MainScene = preload("res://scenes/main.tscn")

const VIEWPORTS := [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(1920, 1080)]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_root := ProjectSettings.globalize_path("res://").path_join("..").path_join(".tmp").path_join("render-captures").simplify_path()
	DirAccess.make_dir_recursive_absolute(output_root)
	var save_root := ProjectSettings.globalize_path("res://").path_join("..").path_join(".tmp").path_join("godot-save-tests").path_join("render").simplify_path()
	var service: RefCounted = SaveServiceScript.new("rendercapture", save_root)
	service.call("clear_slot")
	DirAccess.remove_absolute(save_root)
	DirAccess.make_dir_recursive_absolute(save_root)
	var legacy_source_path := save_root.path_join("slot_1.txt")
	_write_text(legacy_source_path, _minimal_legacy_save())
	var game := MainScene.instantiate()
	game.set("save_service", service)
	game.set("run_state", GameStateScript.create_new_game("镜湖照影", 42424242, [8, 8, 8, 8, 8]))
	root.add_child(game)
	await process_frame
	root.size = Vector2i(1280, 720)
	await _settle_frames(4)
	_capture(root, output_root.path_join("menu_1280x720.png"), Vector2i(1280, 720), "主菜单 1280x720")
	DirAccess.remove_absolute(legacy_source_path)
	game.call("_show_game")

	for viewport_size in VIEWPORTS:
		root.size = viewport_size
		await _settle_frames(4)
		_capture(root, output_root.path_join("main_%dx%d.png" % [viewport_size.x, viewport_size.y]),
			viewport_size, "主界面 %dx%d" % [viewport_size.x, viewport_size.y])

	root.size = Vector2i(1440, 900)
	game.call("_enter_dungeon")
	await _settle_frames(4)
	_capture(root, output_root.path_join("dungeon_route_1440x900.png"), Vector2i(1440, 900), "秘境路线")
	var run_state: Dictionary = game.get("run_state")
	var route_index := 0
	for index in range((run_state.dungeon.run.route_choices as Array).size()):
		var node: Dictionary = run_state.dungeon.run.route_choices[index]
		if str(node.type) in ["combat", "elite", "boss"]:
			route_index = index
			break
	game.call("_choose_dungeon_route", route_index)
	await _settle_frames(4)
	_capture(root, output_root.path_join("dungeon_combat_1440x900.png"), Vector2i(1440, 900), "秘境能力战斗")

	game.call("_abandon_dungeon")
	service.call("clear_slot")
	DirAccess.remove_absolute(save_root)
	game.free()
	if failures.is_empty():
		print("RENDER_CAPTURE_TEST_OK: menu, 3 main viewports and dungeon route/combat are nonblank and correctly sized")
		quit(0)
	else:
		for failure in failures:
			push_error("RENDER_CAPTURE_TEST_FAILED: %s" % failure)
		quit(1)


func _capture(viewport: Viewport, path: String, expected_size: Vector2i, label: String) -> void:
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		failures.append("%s没有生成图像" % label)
		return
	if image.get_size() != expected_size:
		failures.append("%s尺寸错误：%s" % [label, image.get_size()])
	var minimum_luminance := 1.0
	var maximum_luminance := 0.0
	var opaque_samples := 0
	for y in range(0, image.get_height(), maxi(1, int(image.get_height() / 24.0))):
		for x in range(0, image.get_width(), maxi(1, int(image.get_width() / 32.0))):
			var color := image.get_pixel(x, y)
			var luminance := color.get_luminance()
			minimum_luminance = minf(minimum_luminance, luminance)
			maximum_luminance = maxf(maximum_luminance, luminance)
			if color.a > 0.95:
				opaque_samples += 1
	if maximum_luminance - minimum_luminance < 0.08 or opaque_samples < 100:
		failures.append("%s像素变化不足，疑似空白或未渲染" % label)
	var save_error := image.save_png(path)
	if save_error != OK:
		failures.append("%s无法保存截图：%s" % [label, error_string(save_error)])


func _settle_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _write_text(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("无法创建渲染测试旧录")
		return
	file.store_string(contents)
	file.close()


func _minimal_legacy_save() -> String:
	return "\n".join([
		"SAVE_V5", "旧录访客", "1", "1", "0", "100", "100", "50", "50",
		"0", "0", "0", "0", "16", "80", "10", "0", "10", "5",
		"5", "5", "5", "5", "5", "0", "0", "0",
		"WORLD_ERA_V1", "古典修仙纪",
		"WORLD_V2", "1", "0", "0", "0",
		"LEGACY_V1", "1", "0", "黑白轮回玉", "0", "0", "未定道痕", "0", "0",
	]) + "\n"
