extends SceneTree
const Water = preload("res://scripts/adapters/ark_analytic_water.gd")
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var water := Water.new()
	assert(water.enable_gerstner())
	var maximum := 0.0
	for phase in [0.0, 1.2, 6.28]:
		water.waves[0]["phase"] = phase
		for x in range(-90, 91, 9):
			for z in range(-90, 91, 9):
				var f: Dictionary = water.forward(Vector2(x, z))
				var q: Dictionary = water.query(f["position"])
				assert(q["ok"])
				maximum = maxf(maximum, absf(q["height"] - f["y"]))
				assert(absf(q["height"] - f["y"]) < 0.00001)
				assert(q["normal"].distance_to(f["normal"]) < 0.00001)
	var steep: Array = water.waves.duplicate(true)
	steep[0]["k"] = 2.0
	steep[0]["amplitude"] = 0.25
	steep[0]["steepness"] = 1.0
	steep[1]["steepness"] = 0.0
	assert(water.enable_gerstner(steep))
	for x in range(-20, 21):
		var p := Vector3(x * 0.17, 0, -3.2)
		var sample: Dictionary = water.query(p)
		assert(sample["ok"])
		var dx: float = (water.query(p + Vector3(0.001, 0, 0))["height"] - water.query(p - Vector3(0.001, 0, 0))["height"]) / 0.002
		var dz: float = (water.query(p + Vector3(0, 0, 0.001))["height"] - water.query(p - Vector3(0, 0, 0.001))["height"]) / 0.002
		assert(sample["normal"].distance_to(Vector3(-dx, 1, -dz).normalized()) < 0.001)
	water.waves[0]["phase"] = TAU - 0.000000000000001
	var wrapped := Water.new()
	assert(wrapped.restore(JSON.parse_string(JSON.stringify(water.snapshot()))))
	assert(water.enable_gerstner())
	var before := JSON.stringify(water.snapshot())
	var bad: Array = water.waves.duplicate(true)
	bad[0]["steepness"] = 100.0
	assert(not water.enable_gerstner(bad))
	assert(JSON.stringify(water.snapshot()) == before)
	water.register_float("raft", Vector3.ZERO, 1.05)
	assert(water.advance(10.0)["ok"])
	var restored := Water.new()
	assert(restored.restore(JSON.parse_string(JSON.stringify(water.snapshot()))))
	assert(restored.model_version == 2)
	for i in range(60):
		water.advance(0.25)
		restored.advance(0.25)
		assert(water.float_pose("raft").distance_to(restored.float_pose("raft")) < 0.000001)
	var legacy := Water.new()
	assert(restored.restore(legacy.snapshot()) and restored.model_version == 1)
	assert(await _actual_scene())
	print("ARK_GERSTNER_WATER_TEST_OK: forward/inverse samples1323 max_height_error=", maximum, " phase/save/legacy=PASS; rendered validation separate")
	quit()

func _actual_scene() -> bool:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_gerstner_water")
	assert(preload("res://tests/ark_test_paths.gd").is_safe_save_root(save_root))
	var helper = preload("res://scripts/ark_greybox_save.gd").new(save_root)
	helper.clear_for_test()
	var scene := load("res://scenes/ark_greybox.tscn") as PackedScene
	var game = scene.instantiate()
	game.save_root_override = save_root
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	assert(game.water.enable_gerstner())
	game.sailing_mode = true
	var body: CharacterBody3D = game.player
	var ark: Node3D = game.ark_root
	body.global_position = ark.to_global(Vector3(0, 0.3, 0))
	# Sample both crest/trough while physically airborne; SPACE cannot stack impulses.
	for phase in [PI * 0.5, PI * 1.5]:
		game.water.waves[0]["phase"] = phase
		game.water.waves[1]["phase"] = phase
		var location := Vector3(0, 0, 80)
		var surface: Dictionary = game.water.query(location)
		body.global_position = Vector3(location.x, surface["height"] - 0.45, location.z)
		body.velocity = Vector3.ZERO
		body.move_and_slide()
		assert(not body.is_on_floor())
		game._jump_player()
		var impulse := body.velocity.y
		assert(impulse >= 8.6 - 0.00001 and impulse <= sqrt(8.6 * 8.6 + 22.0) + 0.00001)
		for repeat in range(10):
			game._jump_player()
			assert(body.velocity.y == impulse)
		var apex := body.global_position.y
		for step in range(40):
			body.velocity.y -= 22.0 / 60.0
			body.move_and_slide()
			apex = maxf(apex, body.global_position.y)
			await physics_frame
		assert(apex >= game.water.mean_height - 0.45 + 8.6 * 8.6 / 44.0 - 0.10)
	body.global_position = ark.to_global(Vector3(0, 0.3, 0))
	body.velocity = Vector3.ZERO
	var start := ark.global_position
	var contacts := 0
	for frame in range(90):
		assert(game._sail_step(1.0 / 60.0, 0.2, 0.0))
		game._step_water(1.0 / 60.0)
		body.velocity.y -= 18.0 / 60.0
		body.move_and_slide()
		if body.is_on_floor():
			contacts += 1
		await physics_frame
	assert(contacts > 30, "actual CharacterBody must contact actual deck during heave")
	assert(ark.global_position.distance_to(start) > 0.2)
	assert(game._save_progress())
	var phases: Array = game.water.snapshot()["waves"]
	var economy: Dictionary = game.economy.snapshot()
	game.queue_free()
	await process_frame
	game = scene.instantiate()
	game.save_root_override = save_root
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	assert(game.water.model_version == 2, "real game save must restore model2")
	# _ready/first physics can advance once; bounded circular phase difference only.
	for i in range(2):
		assert(absf(wrapf(game.water.waves[i]["phase"] - phases[i]["phase"], -PI, PI)) < 0.05)
	assert(JSON.parse_string(JSON.stringify(game.economy.snapshot())) == JSON.parse_string(JSON.stringify(economy)), "water restore must preserve material ledger")
	print("GERSTNER_ACTUAL_SCENE sailing/deck_contacts=", contacts, " save/free/recreate/ledger=PASS")
	game.queue_free()
	await process_frame
	return true
