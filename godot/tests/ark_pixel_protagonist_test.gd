extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	# Standalone presentation fixture allows recovery before the main-scene integration.
	var world := Node3D.new()
	root.add_child(world)
	var body := CharacterBody3D.new()
	world.add_child(body)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.65
	collision.shape = capsule
	body.add_child(collision)
	var legacy := Node3D.new()
	body.add_child(legacy)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 8.5, 10.5)
	camera.look_at(Vector3.UP)
	var visual := preload("res://scripts/presentation/ark_pixel_protagonist.gd").new()
	body.add_child(visual)
	visual.setup(body, legacy, camera)
	visual.set_physics_process(false)
	for entry in [[Vector3.RIGHT, "side", false], [Vector3.LEFT, "side", true], [Vector3.FORWARD, "back", false], [Vector3.BACK, "front", false]]:
		visual.update_motion(entry[0], 0.15)
		assert(visual.facing == entry[1] and visual.mirrored == entry[2])
		for index in range(4):
			visual.show_pose(entry[1], index, entry[2])
			var atlas := visual.sprite.texture as AtlasTexture
			var anchor: Vector2 = visual.ANCHORS[entry[1]][index]
			assert(atlas.region == visual.REGIONS[entry[1]][index])
			assert(is_zero_approx(visual.sprite.offset.y + atlas.region.size.y * 0.5 - anchor.y))
		# Every direction stops on an actual standing atlas view, never a stride frame.
		visual.update_motion(Vector3.ZERO, 0.1)
		assert(visual.facing == entry[1] and visual.mirrored == entry[2])
		assert(visual.pose_key == "idle_" + entry[1])
		assert(visual.sprite.texture.atlas == visual.SOURCES["idle"])
		assert(visual.sprite.texture.region == visual.REGIONS[visual.pose_key][0])
		assert(visual.sprite.flip_h == entry[2])
		var stopped_pose: String = visual.pose_key
		for tick in range(5):
			visual.update_motion(Vector3.ZERO, 1.0 / 60.0)
			await process_frame
		assert(visual.pose_key == stopped_pose and visual.animation_clock == 0.0)
	visual.update_motion(Vector3.ZERO, 0.1)
	assert(visual.sprite.texture.atlas == visual.SOURCES["idle"])
	assert(is_equal_approx(visual.sprite.pixel_size * 821.0, 1.65))
	camera.position = Vector3(10.5, 8.5, 0)
	camera.look_at(Vector3.UP)
	visual.update_motion(Vector3.RIGHT, 0.15)
	assert(visual.facing == "front")
	var visited := {}
	for tick in range(50):
		body.position.x += 0.02
		visual._physics_process(1.0 / 60.0)
		visited[visual.frame_index] = true
		var clock_before: float = visual.animation_clock
		for render_tick in range(3): await process_frame
		assert(visual.animation_clock == clock_before)
	assert(visited.size() == 4)
	visual._physics_process(1.0 / 60.0)
	assert(visual.animation_clock == 0.0)
	var hull_pose: String = visual.pose_key
	var hull_facing: String = visual.facing
	var hull_mirror: bool = visual.mirrored
	world.position += Vector3(3, 0, 1)
	world.rotation.y += 0.5
	visual._physics_process(1.0 / 60.0)
	assert(visual.animation_clock == 0.0)
	assert(visual.pose_key == hull_pose and visual.facing == hull_facing and visual.mirrored == hull_mirror)
	var position_before := body.position
	for value in [false, true]:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_F8
		key.pressed = true
		root.push_input(key)
		await process_frame
		assert(visual.enabled == value and legacy.visible == not value)
	assert(body.position == position_before and collision.shape == capsule)
	assert(is_equal_approx(capsule.height, 1.65) and is_equal_approx(capsule.radius, 0.38))
	assert(not visual.sprite.no_depth_test)
	assert(visual.sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
	world.queue_free()
	await process_frame
	print("ARK_PIXEL_PROTAGONIST_TEST_OK:")
	quit()
