extends SceneTree
## Display-only recovery gate. Never count headless as visual acceptance.
## Capture runner must be isolated/minimized/no-focus; export interactive packs
## from the NORMAL production project, never from this runner's project settings.
var view: SubViewport
var destination := ""
func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.mode = Window.MODE_MINIMIZED
	_run.call_deferred()
func capture(label: String) -> void:
	for frame in range(4):
		await process_frame
		RenderingServer.force_draw(false)
	var picture := view.get_texture().get_image()
	assert(picture != null and picture.get_size() == view.size)
	assert(picture.save_png(destination.path_join(label + ".png")) == OK)
func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	destination = OS.get_environment("ARK_PIXEL_ARTIFACT_ROOT")
	if destination.is_empty(): destination = ProjectSettings.globalize_path("res://../.tmp/pixel-recovery/render")
	assert(destination.contains("/.tmp/") and destination.contains("pixel"))
	DirAccess.make_dir_recursive_absolute(destination)
	# Critical rerun isolation: do not reload the previous capture's final swim save.
	var saver := preload("res://scripts/ark_greybox_save.gd").new(destination.path_join("test_save"))
	saver.clear_for_test()
	view = SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var game := load("res://scenes/ark_greybox.tscn").instantiate() as Node3D
	game.set("save_root_override", destination.path_join("test_save"))
	view.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var player := game.get("player") as CharacterBody3D
	var camera := game.get("camera") as Camera3D
	var visual := player.get_node("PixelProtagonistTrial")
	visual.set_physics_process(false)
	visual.set_enabled(true)
	for frame in range(45):
		game.call("_physics_process", 1.0 / 60.0)
		await physics_frame
	assert(player.is_on_floor() and not game.get("is_swimming"))
	await capture("01_game_camera_front_idle")
	var save_before: Dictionary = game.call("_build_save_state")
	visual.set_enabled(false)
	await capture("02_game_camera_original")
	visual.set_enabled(true)
	assert(game.call("_build_save_state") == save_before)
	player.position.x = 1.3
	for tick in range(6):
		game.call("_physics_process", 1.0 / 60.0)
		await physics_frame
	camera.global_position = player.global_position + Vector3(0, 8.5, 10.5)
	camera.look_at(player.global_position + Vector3.UP)
	assert(player.is_on_floor() and not game.get("is_swimming"))
	await capture("02b_game_camera_clear_front")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	game.set_physics_process(true)
	visual.previous_position = player.position
	visual.set_physics_process(true)
	var seen := {}
	var walking_start := player.position
	for tick in range(22):
		await physics_frame
		seen[visual.frame_index] = true
	key = InputEventKey.new()
	key.physical_keycode = KEY_W
	key.keycode = KEY_W
	key.pressed = false
	Input.parse_input_event(key)
	assert(seen.size() >= 2 and player.position.distance_to(walking_start) > 0.1)
	assert(player.is_on_floor() and not game.get("is_swimming"))
	game.set_physics_process(false)
	visual.set_physics_process(false)
	await capture("02c_live_wasd_walk")
	visual.update_motion(Vector3.ZERO, 0.1)
	assert(visual.animation_clock == 0.0)
	visual.show_pose("idle_front", 0, false)
	camera.global_position = player.global_position + Vector3(0, 3.2, 4.4)
	camera.look_at(player.global_position + Vector3(0, 0.85, 0))
	assert(player.is_on_floor() and not game.get("is_swimming"))
	print("PIXEL_DECK_PROOF: local=", player.position, " floor=", player.is_on_floor(), " swimming=", game.get("is_swimming"))
	await capture("03_close_front_idle")
	# Four move -> stop transitions on real collider, with supplied standing views.
	# Keep each short movement on the clear deck and explicitly release every key.
	for stop_case in [[KEY_S, "front", false], [KEY_W, "back", false], [KEY_D, "side", false], [KEY_A, "side", true]]:
		player.position = Vector3(1.9 if stop_case[2] else 1.3, player.position.y + 0.02, 0.0)
		player.velocity = Vector3.ZERO
		visual.previous_position = player.position
		game.set_physics_process(true)
		visual.set_physics_process(true)
		var move_key := InputEventKey.new()
		move_key.keycode = stop_case[0]
		move_key.physical_keycode = stop_case[0]
		move_key.pressed = true
		Input.parse_input_event(move_key)
		for tick in range(8): await physics_frame
		move_key = InputEventKey.new()
		move_key.keycode = stop_case[0]
		move_key.physical_keycode = stop_case[0]
		move_key.pressed = false
		Input.parse_input_event(move_key)
		for tick in range(5): await physics_frame
		game.set_physics_process(false)
		visual.set_physics_process(false)
		assert(player.is_on_floor() and not game.get("is_swimming"))
		assert(visual.facing == stop_case[1] and visual.mirrored == stop_case[2])
		assert(visual.pose_key == "idle_" + stop_case[1] and visual.animation_clock == 0.0)
		camera.global_position = player.global_position + Vector3(0, 3.2, 4.4)
		camera.look_at(player.global_position + Vector3(0, 0.85, 0))
		var stop_label: String = "left" if stop_case[2] else ("right" if stop_case[1] == "side" else stop_case[1])
		await capture("03b_stop_" + stop_label)
	# Return posed frame inspection to clear deck; do not let the final left walk
	# place every later screenshot behind the existing helm label.
	player.position = Vector3(1.3, player.position.y + 0.02, -0.55)
	player.velocity = Vector3.ZERO
	for tick in range(6):
		game.call("_physics_process", 1.0 / 60.0)
		await physics_frame
	assert(player.is_on_floor() and not game.get("is_swimming"))
	camera.global_position = player.global_position + Vector3(0, 3.2, 4.4)
	camera.look_at(player.global_position + Vector3(0, 0.85, 0))
	for direction in ["front", "back", "side"]:
		for frame in range(4):
			visual.show_pose(direction, frame, false)
			await capture("04_close_%s_%d" % [direction, frame])
	visual.show_pose("side", 1, true)
	await capture("05_close_left_mirrored")
	var blocker := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.4, 0.65, 0.15)
	blocker.mesh = box
	blocker.position = player.global_position + Vector3(0, 0.325, 0.45)
	game.add_child(blocker)
	visual.show_pose("idle_front", 0, false)
	await capture("06_depth_occlusion")
	blocker.queue_free()
	await process_frame
	var ark := game.get_node("ArkRoot") as Node3D
	ark.rotation.y = 0.65
	camera.global_position = player.global_position + Vector3(0, 8.5, 10.5)
	camera.look_at(player.global_position + Vector3.UP)
	await capture("07_turned_hull")
	player.global_position = Vector3(0, -1.5, 10)
	player.velocity = Vector3.ZERO
	for frame in range(12):
		game.call("_physics_process", 1.0 / 60.0)
		await physics_frame
	assert(game.get("is_swimming"))
	visual.update_motion(Vector3.RIGHT, 0.2)
	await capture("08_swimming_game_camera")
	game.queue_free()
	await process_frame
	print("ARK_PIXEL_PROTAGONIST_RENDER_TEST_OK: 25 captures, four directional stops, actual grounded input movement and swimming")
	quit()
