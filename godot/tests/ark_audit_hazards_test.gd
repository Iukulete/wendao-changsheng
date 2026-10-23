extends SceneTree

const ArkTestPaths = preload("res://tests/ark_test_paths.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var game := (load("res://scenes/ark_greybox.tscn") as PackedScene).instantiate()
	var save_root := ProjectSettings.globalize_path("res://../.local/test_ark_audit_hazards").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(save_root), "hazard tests must use isolated repository-local saves")
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	save_helper.clear_for_test()
	game.set("save_root_override", save_root)
	root.add_child(game)
	await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	var player := game.get("player") as CharacterBody3D
	player.global_position = Vector3(35.0, -1.5, -35.5)
	player.velocity = Vector3.ZERO
	game.set("is_swimming", true)
	var before := player.global_position
	game.call("_apply_reef_surge", 1.0 / 60.0)
	for _step in range(10):
		game.call("_physics_process", 1.0 / 60.0)
	var delta := player.global_position - before
	assert(Vector2(delta.x, delta.z).dot(Vector2(-0.52, -0.85).normalized()) > 0.25, "the reef surge must actually displace a swimmer across subsequent physics frames")
	assert(int(game.get("player_health")) == 4, "the reef surge remains a non-damaging warning")
	game.call("_clear_player_knockback")
	# Explicit hit fixture measured from the live, rotated physical vent.
	var vent_position := (game.get_node("PressureWreck/BentVent") as Node3D).global_position
	player.global_position = Vector3(vent_position.x + 2.0, 1.1, vent_position.z)
	player.velocity = Vector3.ZERO
	game.set("is_swimming", false)
	game.call("_process_pressure_vent", 0.0)
	game.call("_process_pressure_vent", 1.4)
	before = player.global_position
	for _step in range(10):
		game.call("_physics_process", 1.0 / 60.0)
	delta = player.global_position - before
	assert(int(game.get("player_health")) == 3 and delta.x > 0.25, "a vent hit must both deduct one health and physically push the player away")
	game.set("reef_beast_knockback_remaining", 0.32)
	game.set("reef_beast_knockback_velocity", Vector3(6.5, 0, 0))
	game.call("_knock_out_player_from_reef_beast")
	assert(float(game.get("reef_beast_knockback_remaining")) == 0.0 and float(game.get("environment_push_remaining")) == 0.0, "knockout recovery must clear old shoves instead of launching the player off the rescue deck")
	game.call("_push_player_from_environment", Vector3(5.0, 0.0, 0.0))
	game.call("_knock_out_player_from_pressure_vent")
	assert(float(game.get("environment_push_remaining")) == 0.0, "steam knockout recovery must also clear its impulse")
	game.call("_push_player_from_environment", Vector3(5.0, 0.0, 0.0))
	game.set("weather_phase", 2)
	game.call("_toggle_sailing")
	assert(bool(game.get("sailing_mode")) and float(game.get("environment_push_remaining")) == 0.0, "taking the helm must not defer an old shove until the player disembarks")
	game.queue_free()
	await process_frame
	save_helper.clear_for_test()
	print("ARK_AUDIT_HAZARDS_TEST_OK:")
	quit()
