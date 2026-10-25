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
	# Expanded room/work details can put actions below the drawer's clip. Scroll
	# the real container first, as a user must, rather than clicking offscreen.
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await _settle()
			assert(ancestor.get_global_rect().has_point(control.get_global_rect().get_center()))
			break
		ancestor = ancestor.get_parent()
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
	var presentation: Node = game.get("nearfuture_hud")
	var status := presentation.get("status_panel") as Control
	assert(not (game.get("hud_panel") as Control).visible and status.is_visible_in_tree())
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
	assert((presentation.get("build_panel") as Control).is_visible_in_tree() and context.mouse_filter == Control.MOUSE_FILTER_IGNORE)
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
	# Structured choices stay outside the scroll, even with very long narrative.
	# Do not weaken the source text or parse its numeric prose to build buttons.
	for fixture in [
		["raft_extension_dismantle_pending", "dismantle", 2],
		["household_work_choice_pending", "household", 3],
		["jade_sail_guest_choice_pending", "guest", 2],
		["jade_sail_industry_choice_pending", "industry", 2],
		["pressure_galley_choice_pending", "galley", 2],
		["resident_gather_policy_choice_pending", "gather", 4],
		["traveler_choice_pending", "tidekeeper", 2],
		["sailmaker_choice_pending", "sailmaker", 2],
		["resident_repair_choice_pending", "resident_repair", 2],
		["preparation_choice_pending", "preparation", 3],
		["repair_choice_pending", "repair", 3],
	]:
		game.set(fixture[0], true)
		game.set("message", "这是一段很长的居民对话，选项不应被挤到看不见的地方。".repeat(60))
		game.call("_update_hud")
		await _settle()
		var view: Dictionary = game.call("_hud_choice_view")
		assert(view.id == fixture[1] and view.options.size() == fixture[2])
		var pinned := presentation.get("choice_panel") as Control
		assert(pinned.is_visible_in_tree() and root.get_visible_rect().encloses(pinned.get_global_rect()))
		assert(not pinned.get_global_rect().intersects(context.get_global_rect()))
		var buttons: Array = presentation.get("choice_buttons")
		for index in range(int(fixture[2])):
			assert(buttons[index].is_visible_in_tree() and pinned.get_global_rect().encloses(buttons[index].get_global_rect()))
		game.set(fixture[0], false)
	game.set("resident_gather_policy_choice_pending", true)
	game.call("_update_hud")
	await _settle()
	await _click((presentation.get("choice_buttons") as Array)[1])
	assert(not game.get("resident_gather_policy_choice_pending") and game.get("resident_gather_policy") == "shellfish_first", "actual pinned mouse choice must reach the original controller")
	game.call("_on_hud_choice_requested", KEY_1, "gather")
	assert(not game.get("building_mode"), "retired choice clicks must not leak into a new world action")
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
	assert((presentation.get("health_label") as Label).text == "生命 1/4" and (presentation.get("alert_panel") as Control).is_visible_in_tree())
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
