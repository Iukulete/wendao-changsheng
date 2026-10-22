extends SceneTree
## Display-backed Compatibility check. Launch minimized/no_focus; all images use SubViewport.
## Default wave profile only: raster height <=.02m, normal angle <=.02rad.
const Water = preload("res://scripts/adapters/ark_analytic_water.gd")
var output := ""
func _initialize() -> void:
	_run.call_deferred()
func _draw() -> void:
	await process_frame
	RenderingServer.force_draw(false)
func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "actual GL context required")
	root.mode = Window.MODE_MINIMIZED
	root.unfocusable = true
	output = OS.get_environment("ARK_GERSTNER_ARTIFACT_ROOT")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	viewport.add_child(environment)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(300, 300)
	mesh.subdivide_width = 199
	mesh.subdivide_depth = 199
	plane.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/ark_ocean.gdshader")
	plane.material_override = material
	viewport.add_child(plane)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 40.0
	camera.position = Vector3(0, 30, 0)
	camera.rotation_degrees.x = -90.0
	camera.current = true
	viewport.add_child(camera)
	var water := Water.new()
	assert(water.enable_gerstner())
	water.apply_visual(material)
	material.set_shader_parameter("height_probe", true)
	var direct_error := 0.0
	var srgb_error := 0.0
	for known in [0.25, 0.5, 0.75]:
		material.set_shader_parameter("height_probe_reference", known)
		await _draw()
		await _draw()
		var pixel: Color = viewport.get_texture().get_image().get_pixel(256, 256)
		direct_error += absf(pixel.r - known)
		srgb_error += absf(pixel.srgb_to_linear().r - known)
	var decode_srgb := srgb_error < direct_error
	assert(minf(direct_error, srgb_error) < 0.012, "fixed transfer calibration must pass")
	material.set_shader_parameter("height_probe_reference", -1.0)
	var height_errors: Array[float] = []
	var normal_errors: Array[float] = []
	for case in range(6):
		water.waves[0]["phase"] = fposmod(case * 1.1, TAU)
		water.waves[1]["phase"] = fposmod(case * 0.7, TAU)
		plane.position = Vector3(7, -1.05, -11) if case % 2 else Vector3(0, -1.05, 0)
		plane.rotation.y = 0.43 if case % 2 else 0.0
		water.apply_visual(material)
		material.set_shader_parameter("normal_probe", false)
		await _draw()
		await _draw()
		var height_image := viewport.get_texture().get_image()
		height_image.save_png(output.path_join("height_%d.png" % case))
		material.set_shader_parameter("normal_probe", true)
		await _draw()
		await _draw()
		var normal_image := viewport.get_texture().get_image()
		normal_image.save_png(output.path_join("normal_%d.png" % case))
		for px in range(16, 496, 13):
			for py in range(16, 496, 13):
				var world := Vector3(((px + 0.5) / 512.0 - 0.5) * 40.0, 0, ((py + 0.5) / 512.0 - 0.5) * 40.0)
				var sample: Dictionary = water.query(world)
				assert(sample["ok"])
				var color := height_image.get_pixel(px, py)
				var ncolor := normal_image.get_pixel(px, py)
				if decode_srgb:
					color = color.srgb_to_linear()
					ncolor = ncolor.srgb_to_linear()
				height_errors.append(absf(color.r - 0.5 + water.mean_height - sample["height"]))
				var normal := Vector3(ncolor.r * 2 - 1, ncolor.g * 2 - 1, ncolor.b * 2 - 1).normalized()
				normal_errors.append(acos(clampf(normal.dot(sample["normal"]), -1, 1)))
	height_errors.sort()
	normal_errors.sort()
	assert(height_errors.back() <= 0.02)
	assert(normal_errors.back() <= 0.02)
	viewport.queue_free()
	await process_frame
	assert(await _capture_game())
	var report := {"renderer": RenderingServer.get_video_adapter_name(), "height_samples": height_errors.size(), "max_height_error": height_errors.back(), "height_p95": height_errors[int(height_errors.size() * 0.95)], "max_normal_angle": normal_errors.back(), "normal_p95": normal_errors[int(normal_errors.size() * 0.95)], "height_tolerance": 0.02, "normal_tolerance": 0.02, "default_profile_only": true, "decode_srgb": decode_srgb, "source_hashes": {}}
	for path in ["res://scripts/adapters/ark_analytic_water.gd", "res://scripts/ark_greybox.gd", "res://shaders/ark_ocean.gdshader", "res://tests/ark_gerstner_render_test.gd"]:
		report["source_hashes"][path] = FileAccess.get_sha256(path)
	var file := FileAccess.open(output.path_join("measurements.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("ARK_GERSTNER_RENDER_TEST_OK: ", JSON.stringify(report))
	quit()

func _capture_game() -> bool:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 768)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var save_root := ProjectSettings.globalize_path("res://../.local/test_gerstner_render")
	assert(preload("res://tests/ark_test_paths.gd").is_safe_save_root(save_root))
	var helper = preload("res://scripts/ark_greybox_save.gd").new(save_root)
	helper.clear_for_test()
	var scene := load("res://scenes/ark_greybox.tscn") as PackedScene
	var game = scene.instantiate()
	game.save_root_override = save_root
	viewport.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	assert(game.water.enable_gerstner())
	game.sailing_mode = true
	for child in game.get_children():
		if child is CanvasLayer:
			child.visible = false
	var camera := viewport.get_camera_3d()
	camera.global_position = game.ark_root.global_position + Vector3(10, 4, 12)
	camera.look_at(game.ark_root.global_position + Vector3(0, -0.2, 0))
	var body: CharacterBody3D = game.player
	body.global_position = game.ark_root.to_global(Vector3(0, 0.3, 0))
	body.velocity = Vector3.ZERO
	var contacts := 0
	for i in range(60):
		assert(game._sail_step(1.0 / 60.0, 0.2, 0.0))
		game._step_water(1.0 / 60.0)
		body.velocity.y -= 22.0 / 60.0
		body.move_and_slide()
		if body.is_on_floor():
			contacts += 1
		await physics_frame
		await _draw()
	assert(contacts > 30 and body.is_on_floor() and not game.is_swimming)
	print("GERSTNER_RENDER_DECK_CONTACTS ", contacts, " floor=true swim=false")
	viewport.get_texture().get_image().save_png(output.path_join("ark_unobstructed.png"))
	assert(game._save_progress())
	game.queue_free()
	await process_frame
	game = scene.instantiate()
	game.save_root_override = save_root
	viewport.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	assert(game.water.model_version == 2)
	await _draw()
	viewport.get_texture().get_image().save_png(output.path_join("ark_restored.png"))
	viewport.queue_free()
	await process_frame
	return true
