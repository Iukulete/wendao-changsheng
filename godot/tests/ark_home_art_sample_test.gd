extends SceneTree
const Paths = preload("res://tests/ark_test_paths.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
const Memory = preload("res://scripts/modules/memory/ark_memory.gd")
var game: Node3D
var output_root: String

func _initialize() -> void:
	root.mode = Window.MODE_MINIMIZED
	root.unfocusable = true
	_run.call_deferred()

func _collisions() -> Dictionary:
	var result := {}
	for node in game.find_children("*", "CollisionShape3D", true, false):
		result[str(game.get_path_to(node))] = [node.get_instance_id(), node.shape.get_instance_id(), node.global_transform, node.disabled]
	return result

func _key() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_F7
	event.pressed = true
	game.call("_unhandled_key_input", event)

func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_home_art_sample").simplify_path()
	assert(Paths.is_safe_save_root(save_root))
	var saver = Save.new(save_root)
	saver.clear_for_test()
	game = load("res://scenes/ark_greybox.tscn").instantiate()
	game.set("save_root_override", save_root)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	(game.get("player") as Node).set_physics_process(false)
	await physics_frame
	game.set("wood", 9)
	(game.get("player") as Node3D).position = Vector3(0, 1.1, 1.75)
	assert(game.call("_try_place_workshop_home_template", Vector3.ZERO))
	var sample = game.get("home_art_sample")
	assert(sample.enabled and game.get("home_art_button").button_pressed, "normal play starts with the home presentation, not the old graybox")
	assert(game.get_node("ArkRoot/BuiltShelter/Bedroll").get_child(0).material_override.shader == sample.CANVAS_SHADER)
	assert(game.get_node("ArkRoot/RaftPort").get_child(0).material_override.get_shader_parameter("dark_tone") == Vector3(.08,.155,.14), "painted trim is not another undifferentiated wood plane")
	_key()
	assert(not sample.enabled and sample.get("_timber") == null and not game.get("home_art_button").button_pressed, "F7 releases presentation resources and restores the baseline")
	var state: Dictionary = game.call("_build_save_state")
	var collisions := _collisions()
	var coast := game.get_node("IslandLandmass/Shoreline") as MeshInstance3D
	var material := coast.material_override
	var geometry := coast.mesh
	var floor_visual := game.get_node("ArkRoot/RaftTop").get_child(0) as MeshInstance3D
	var floor_geometry := floor_visual.mesh
	var socket := game.get_node("ArkRoot/BuiltWorkbench/SpiritSocket").get_child(0) as MeshInstance3D
	var socket_material := socket.material_override
	var meal_destination: Vector3 = game.get("shelter_position") + game.TIDEKEEPER_SHARED_MEAL_OFFSET
	var meal_obstacles: Array[Rect2] = game.call("_shared_meal_route_obstacles", meal_destination)
	_key()
	assert(sample.timber_texture().get_size() == Vector2(1254, 1254) and sample.timber_texture().get_image().has_mipmaps())
	assert(sample.enabled and coast.material_override != material and coast.mesh == geometry)
	assert(socket.material_override == socket_material, "functional fixture cues retain their authored material")
	assert(game.call("_shared_meal_route_obstacles", meal_destination) == meal_obstacles, "candidate never changes the resident meal planner's cot/hearth obstacles")
	assert(floor_visual.mesh == floor_geometry,"the structural deck keeps its complete original support mesh; plank joinery is material-only")
	var painted_count: int = sample.get("_originals").size()
	for repeat in range(12): sample.apply(game)
	assert(sample.get("_originals").size() == painted_count)
	var storage := game.get_node("ArkRoot/BuiltStorage") as Node3D
	var storage_visual := storage.get_node("Body").get_child(0) as MeshInstance3D
	var storage_original: Dictionary = sample.get("_originals")[storage_visual.get_instance_id()]
	assert(storage_visual.mesh is ArrayMesh and storage_visual.mesh.get_aabb().is_equal_approx(storage_original.mesh.get_aabb()),"isolated furniture keeps chamfers within its original bounds")
	var ark := storage.get_parent()
	ark.remove_child(storage) # Explicit temporary-detachment fixture, not gameplay demolition.
	sample.apply(game)
	assert(storage_visual.mesh == storage_original.mesh and storage_visual.material_override == storage_original.material,"detached but live parts retain an authentic reversible baseline")
	ark.add_child(storage)
	sample.apply(game)
	assert(sample.get("_originals").size() == painted_count and storage_visual.mesh is ArrayMesh)
	assert(game.get_node("ArkRoot/HomeArtCandidate").find_children("*", "CollisionObject3D", true, false).is_empty())
	assert(_collisions() == collisions, "decor is visual-only, no altered physics resources")
	var timings: Array[int] = []
	for repeat in 100:
		var clock := Time.get_ticks_usec()
		sample.apply(game)
		timings.append(Time.get_ticks_usec()-clock)
	timings.sort()
	print("HOME_PRESENTATION_CPU usec p50=",timings[50]," p95=",timings[95]," max=",timings[-1]," calls=100 headless apply-only; not frame/GPU/FPS")
	assert(Memory.facts_equal(state, game.call("_build_save_state")), "toggling never alters game or save state")
	_key()
	assert(not sample.enabled and coast.material_override == material and coast.mesh == geometry)
	assert(floor_visual.mesh == floor_geometry, "original mesh identity restores too")
	assert(not game.has_node("ArkRoot/HomeArtCandidate"))
	_key()
	assert(game.call("_save_progress"))
	for repeat in range(12):
		game.call("_load_progress")
		await process_frame
		sample.apply(game)
		assert(sample.get("_decor").size() == 3 and sample.get("_originals").size() == painted_count, "repeated reconstruction keeps live-only adapter caches")
	assert(sample.enabled and game.has_node("ArkRoot/BuiltShelter/HomeArtCandidate"))
	assert(_collisions().size() == collisions.size() and game.get("economy").audit().ok)
	# Native rail resize code must still see its BoxMesh while the sample is on.
	game.set("wood", 4)
	game.set("keel_beams", 1)
	game.call("_learn_blueprint", "keel_deck_expansion", "art_lifecycle_test_fixture")
	assert(game.call("_try_place_raft_extension", Vector3(0, .12, -4.2)))
	_assert_rail_geometry()
	assert(game.call("_shared_meal_route_obstacles", meal_destination) == meal_obstacles)
	assert(game.call("_dismantle_raft_extension"))
	_assert_rail_geometry()
	_key()
	assert(not sample.enabled)
	_assert_rail_geometry()
	if DisplayServer.get_name() != "headless":
		await _render_pairs()
	game.free()
	saver.clear_for_test()
	print("ARK_HOME_ART_SAMPLE_TEST_OK: production default/F7, reversible materials, bounded decor, unchanged geometry/physics/save, rebuild; render pairs only when display-backed")
	quit()

func _assert_rail_geometry() -> void:
	for name_ in ["RaftBow", "RaftPort", "RaftStarboard"]:
		var body := game.get_node("ArkRoot/" + name_)
		var mesh := (body.get_child(0) as MeshInstance3D).mesh
		var shape := (body.get_child(1) as CollisionShape3D).shape
		assert(mesh is BoxMesh and shape is BoxShape3D and mesh.size.is_equal_approx(shape.size), "live rail mesh/collision sizes must agree throughout candidate build/dismantle/restore")

func _render_pairs() -> void:
	output_root = OS.get_environment("ARK_HOME_ART_CAPTURE_ROOT")
	assert(output_root.is_absolute_path() and output_root.replace("\\", "/").to_lower().begins_with("d:/"))
	assert(DirAccess.make_dir_recursive_absolute(output_root) == OK)
	root.size = Vector2i(1280, 720)
	# Authored camera samples, not gameplay performance evidence. UI stays in the
	# wide view; close material/room views hide it equally before and after.
	var camera := game.get("camera") as Camera3D
	var overlay := (game.get("nearfuture_hud") as Node).get("overlay") as Control
	(game.get("nearfuture_hud") as Node).set_process(false)
	(game.get("player") as Node3D).position = Vector3(-.5, .22, .7)
	for label in game.find_children("*", "Label3D", true, false): label.visible = false
	var views := [
		["deck", Vector3(7.4, 5.4, 9.0), Vector3(0, .6, -.4)],
		["cabin", Vector3(2.5, 2.4, 5.3), Vector3(-.25, 1.1, -.2)],
		["coast", Vector3(1, 5.3, 4), Vector3(11, .1, -11)],
	]
	for weather in [["day", 1, 2], ["night", 3, 2], ["storm", 3, 1]]:
		game.set("day_period", weather[1])
		game.set("weather_phase", weather[2])
		game.call("_set_weather_visuals")
		game.call("_update_hud")
		for view in views:
			camera.global_position = view[1]
			camera.look_at(view[2])
			overlay.visible = view[0] == "deck"
			for layer in game.find_children("*", "CanvasLayer", true, false):
				layer.visible = view[0] == "deck"
			# Cutaway both variants identically, exposing the actual existing room.
			(game.get_node("ArkRoot/BuiltShelter/Roof") as Node3D).visible = view[0] != "cabin"
			for variant in ["before", "candidate"]:
				game.get("home_art_sample").set_enabled(game, variant == "candidate")
				for frame in range(5): await process_frame
				RenderingServer.force_draw(false)
				var image := root.get_texture().get_image()
				assert(image != null and image.get_size() == Vector2i(1280, 720))
				assert(image.save_png(output_root.path_join("%s_%s_%s.png" % [view[0], weather[0], variant])) == OK)
		game.get("home_art_sample").set_enabled(game, false)
	print("ARK_HOME_ART_CAPTURES_OK: 18 before/candidate frames; GL renderer; " + output_root)
