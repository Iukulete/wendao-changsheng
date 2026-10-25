extends SceneTree

const Rig = preload("res://scripts/adapters/ark_orbit_camera.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
var game: Node3D

func _initialize() -> void:
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_MINIMIZED
		root.unfocusable = true
	_run.call_deferred()

func _button(button: MouseButton, pressed: bool = true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = Vector2(800, 300)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT if button == MOUSE_BUTTON_RIGHT and pressed else 0
	return event

func _motion(relative: Vector2, held: bool = true) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.position = Vector2(800, 300)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT if held else 0
	return event

func _capture(name_: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var folder := OS.get_environment("ARK_CAMERA_CAPTURE_ROOT")
	assert(folder.is_absolute_path() and folder.replace("\\", "/").to_lower().begins_with("d:/"))
	DirAccess.make_dir_recursive_absolute(folder)
	for tick in range(4):
		game.call("_refresh_nearfuture_hud")
		game.call("_update_shelter_roof_cutaway")
		await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(folder.path_join(name_ + ".png")) == OK)

func _run() -> void:
	var rig = Rig.new()
	assert(rig.offset() == Rig.DEFAULT_OFFSET)
	assert(not rig.handle(_motion(Vector2(40, 20))))
	assert(rig.handle(_button(MOUSE_BUTTON_RIGHT)))
	assert(rig.handle(_motion(Vector2(80, 20))) and rig.yaw != 0 and rig.pitch > Rig.DEFAULT_PITCH)
	assert(not rig.handle(_motion(Vector2.ONE, false)) and not rig.dragging)
	for tick in range(100): rig.handle(_button(MOUSE_BUTTON_WHEEL_UP))
	assert(rig.distance == Rig.MIN_DISTANCE)
	for tick in range(100): rig.handle(_button(MOUSE_BUTTON_WHEEL_DOWN))
	assert(rig.distance == Rig.MAX_DISTANCE)
	rig.handle(_button(MOUSE_BUTTON_RIGHT))
	rig.handle(_motion(Vector2(0, 100000)))
	assert(rig.pitch == Rig.MAX_PITCH)
	rig.handle(_motion(Vector2(0, -100000)))
	assert(rig.pitch == Rig.MIN_PITCH)
	rig.reset()
	assert(rig.offset() == Rig.DEFAULT_OFFSET and not rig.dragging and not rig.adjusted)
	rig.yaw = PI / 2.0
	assert(rig.movement(Vector2(0, -1)).is_equal_approx(Vector3(-1, 0, 0)))
	rig.reset()
	var save_root := ProjectSettings.globalize_path("res://../.local/test_orbit_camera_%d" % OS.get_process_id()).simplify_path()
	var service = Save.new(save_root)
	service.clear_for_test()
	game = load("res://scenes/ark_greybox.tscn").instantiate()
	game.save_root_override = save_root
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await physics_frame
	game.call("_update_follow_camera")
	var initial: Transform3D = game.camera.global_transform
	var economy_before: Dictionary = game.economy.snapshot()
	var events_before: Array = game.world_events.duplicate(true)
	await _capture("01_default")
	# Deliver actual input through the scene tree, not just the rig unit API.
	Input.parse_input_event(_button(MOUSE_BUTTON_RIGHT))
	Input.flush_buffered_events()
	assert(game.orbit_camera.dragging, "right press outside UI must reach the game")
	Input.parse_input_event(_motion(Vector2(100, -15)))
	Input.flush_buffered_events()
	await physics_frame
	game.call("_physics_process", 0.0)
	assert(game.orbit_camera.adjusted and absf(game.orbit_camera.yaw) > 0.5)
	var orbit: Transform3D = game.camera.global_transform
	assert(not orbit.is_equal_approx(initial) and game.camera.fov == 54.0)
	game.call("_physics_process", 0.0)
	assert(game.orbit_camera.yaw < -0.5, "the physics follow must not overwrite user angles")
	await _capture("02_dragged")
	Input.parse_input_event(_button(MOUSE_BUTTON_RIGHT, false))
	Input.flush_buffered_events()
	assert(not game.orbit_camera.dragging)
	var old_distance: float = game.orbit_camera.distance
	game.call("_unhandled_input", _button(MOUSE_BUTTON_WHEEL_UP))
	assert(game.orbit_camera.distance < old_distance and game.camera.fov == 54.0)
	await physics_frame
	game.call("_physics_process", 0.0)
	await _capture("03_zoomed")
	# A real collision body between actor and desired camera shortens the ray.
	var blocker := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 2, 2)
	collider.shape = box
	blocker.add_child(collider)
	root.add_child(blocker)
	var target: Vector3 = game.player.global_position + Vector3(0, 1, 0)
	blocker.global_position = target + game.orbit_camera.offset().normalized() * 4.0
	await physics_frame
	game.call("_update_follow_camera")
	assert(game.camera.global_position.distance_to(target) < 4.0, "adjusted camera must stop before an opaque collision obstacle")
	blocker.free()
	var key := InputEventKey.new()
	key.keycode = KEY_HOME
	key.pressed = true
	game.call("_unhandled_key_input", key)
	assert(game.orbit_camera.offset() == Rig.DEFAULT_OFFSET)
	assert(game.camera.global_position == game.player.global_position + Vector3(0, 1, 0) + Rig.DEFAULT_OFFSET)
	await _capture("04_reset")
	assert(game.economy.snapshot() == economy_before and game.world_events == events_before)
	game.call("_unhandled_input", _button(MOUSE_BUTTON_RIGHT))
	assert(game.orbit_camera.dragging)
	game.hud_drawer.show()
	await physics_frame
	game.call("_physics_process", 0.0)
	assert(not game.orbit_camera.dragging, "opening a modal mid-drag must release orbit")
	game.hud_drawer.hide()
	for modal in ["drawer", "chart", "choice"]:
		if modal == "drawer": game.hud_drawer.show()
		if modal == "chart": game.world_chart.show()
		if modal == "choice": game.household_work_choice_pending = true
		game.call("_unhandled_input", _button(MOUSE_BUTTON_RIGHT))
		game.call("_unhandled_input", _motion(Vector2(80, 80)))
		game.call("_unhandled_input", _button(MOUSE_BUTTON_WHEEL_UP))
		assert(not game.orbit_camera.dragging and not game.orbit_camera.adjusted, "modal must own mouse: " + modal)
		game.hud_drawer.hide()
		game.world_chart.hide()
		game.household_work_choice_pending = false
	# Real finite material pickup, then right-click keeps its original cancel role.
	game.player.global_position = game.get_node("DriftwoodNear").global_position
	game.call("_interact")
	game.player.position = Vector3(0, 1.1, 1.75)
	var wood: int = game.wood
	game.call("_start_build")
	assert(game.building_mode)
	game.call("_unhandled_input", _button(MOUSE_BUTTON_RIGHT))
	assert(not game.building_mode and game.wood == wood and not game.orbit_camera.dragging)
	game.call("_unhandled_input", _button(MOUSE_BUTTON_RIGHT))
	assert(game.orbit_camera.dragging)
	game.call("_notification", Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert(not game.orbit_camera.dragging)
	game.free()
	service.clear_for_test()
	print("ARK_ORBIT_CAMERA_TEST_OK: real mouse dispatch; persistent orbit, camera-relative movement, zoom/pitch bounds, Home exact reset; modal/build input ownership; focus/release cleanup; no economy/history changes")
	quit()
