extends SceneTree
const TestPaths = preload("res://tests/ark_test_paths.gd")
func _initialize() -> void:
	_run.call_deferred()
func _settle() -> void:
	for frame in range(4): await process_frame
func _key(code: Key, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event)
func _tap(code: Key) -> void:
	_key(code)
	_key(code, false)
func _click(control: Control) -> void:
	assert(control.is_visible_in_tree())
	var center := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	root.push_input(motion)
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = center
		click.global_position = center
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		root.push_input(click)
	await _settle()
func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_hud_clarity").simplify_path()
	assert(TestPaths.is_safe_save_root(save_root))
	var saver := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	saver.clear_for_test()
	var game := load("res://scenes/ark_greybox.tscn").instantiate() as Node3D
	game.set("save_root_override", save_root)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var drawer := game.get("hud_drawer") as Control
	var toggle := game.get("hud_toggle") as Button
	var status := game.get("hud_panel") as Control
	var context := game.get("note_panel") as Control
	var player := game.get("player") as CharacterBody3D
	for screen in [Vector2i(1280, 720), Vector2i(1440, 900)]:
		root.size = screen
		await _settle()
		assert(not drawer.visible and toggle.is_visible_in_tree())
		assert(status.size.x <= 362 and status.size.y < 260)
		assert(not status.get_global_rect().intersects(context.get_global_rect()))
		var label := game.get("hud") as Label
		assert(label.text.contains("生命") and label.text.contains("当前目标") and label.text.contains("木料"))
		await _click(toggle)
		assert(drawer.visible)
		assert(drawer.get_global_rect().end.x <= screen.x and drawer.get_global_rect().end.y < screen.y - 128)
		assert(not drawer.get_global_rect().intersects(context.get_global_rect()))
		var period := int(game.get("day_period"))
		var weather := int(game.get("weather_phase"))
		var position := player.global_position
		for code in [KEY_E, KEY_R, KEY_T, KEY_Q, KEY_B, KEY_F, KEY_SPACE]: _tap(code)
		game.call("_physics_process", 0.1)
		assert(player.global_position == position and not game.get("building_mode"))
		assert(game.get("day_period") == period and game.get("weather_phase") == weather)
		_tap(KEY_F5)
		assert((game.get("save_status_notice") as Label).visible)
		await _click(game.find_child("ArkHelpCloseButton", true, false) as Control)
		assert(not drawer.visible)
		_tap(KEY_H)
		assert(drawer.visible)
		_tap(KEY_ESCAPE)
		assert(not drawer.visible)
	game.set("weather_phase", 2)
	game.set("wood", 12)
	_tap(KEY_H)
	await _settle()
	await _click(game.find_child("ArkBasicShelterTemplateButton", true, false) as Control)
	assert(game.get("building_mode") and not drawer.visible)
	assert((game.get("hud") as Control).visible and context.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	_tap(KEY_H)
	var wood := int(game.get("wood"))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(650, 320)
	root.push_input(click)
	assert(game.get("wood") == wood and not game.get("shelter_built"))
	_tap(KEY_ESCAPE)
	assert(not drawer.visible and game.get("building_mode"))
	_tap(KEY_ESCAPE)
	assert(not game.get("building_mode"))
	game.call("_toggle_sailing")
	assert(game.get("sailing_mode"))
	_tap(KEY_H)
	_tap(KEY_E)
	assert(game.get("sailing_mode"))
	_tap(KEY_ESCAPE)
	assert(game.get("sailing_mode") and not drawer.visible)
	_tap(KEY_E)
	assert(not game.get("sailing_mode"))
	game.set("traveler_choice_pending", true)
	game.set("message", "这处今晚能挡雨吗？\n1 邀请上筏，共同过夜\n2 尊重对方，暂不同行\nEsc 暂不决定")
	game.call("_update_hud")
	_tap(KEY_H)
	assert(not drawer.visible and toggle.disabled and (game.get("note") as Label).text.contains("2 尊重"))
	_tap(KEY_ESCAPE)
	assert(not game.get("traveler_choice_pending"))
	root.size = Vector2i(1280, 720)
	game.set("message", "居民正在讲述风雨中的准备。".repeat(100))
	game.call("_update_hud")
	await _settle()
	var scroll := game.get("note_scroll") as ScrollContainer
	scroll.scroll_vertical = 100
	await _settle()
	assert(scroll.scroll_vertical > 0)
	game.call("_update_hud")
	await _settle()
	assert(scroll.scroll_vertical > 0)
	game.set("message", "另一位居民带来不同选择。".repeat(100))
	game.call("_update_hud")
	await _settle()
	assert(scroll.scroll_vertical == 0)
	game.set("message", "请先避寒，并修复受损棚顶与筏舷。")
	game.set("player_health", 1)
	game.set("cold_exposure_level", 3)
	game.set("shelter_roof_damaged", true)
	game.set("raft_edge_damaged", true)
	game.set_meta("save_warning", "存档写入失败，旧档已保留；本次进度尚未保存。请检查可写目录后按 F5 重试。")
	game.call("_update_hud")
	await _settle()
	var warning := game.get("save_status_notice") as Label
	assert(not status.get_global_rect().intersects(context.get_global_rect()))
	assert(not warning.get_global_rect().intersects(context.get_global_rect()))
	assert(warning.visible and (game.get("hud") as Label).text.contains("生命 1/4"))
	_tap(KEY_H)
	assert(warning.visible)
	_tap(KEY_M)
	assert(not drawer.visible and (game.get("world_chart") as Control).visible and warning.visible)
	_tap(KEY_ESCAPE)
	assert(warning.visible and not drawer.visible)
	game.queue_free()
	await process_frame
	saver.clear_for_test()
	print("ARK_HUD_CLARITY_TEST_OK: reconstructed actual key/mouse routes and layout")
	quit()
