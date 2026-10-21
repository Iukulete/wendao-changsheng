extends SceneTree
const Paths = preload("res://tests/ark_test_paths.gd")
var game: Node3D
var save_root: String
func _initialize() -> void:
	_run.call_deferred()
func _new_game() -> void:
	game = load("res://scenes/ark_greybox.tscn").instantiate() as Node3D
	game.set("save_root_override", save_root)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await physics_frame
func _player(position: Vector3) -> void:
	(game.get("player") as Node3D).global_position = (game.get("ark_root") as Node3D).to_global(position)
func _key(code: Key, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
func _walk() -> void:
	for step in range(200):
		game.call("_process", 0.1)
		await physics_frame
func _reload() -> void:
	assert(game.call("_save_progress"))
	game.queue_free()
	await process_frame
	await _new_game()
func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/test_home_meal").simplify_path()
	assert(Paths.is_safe_save_root(save_root))
	var saver := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	saver.clear_for_test()
	await _new_game()
	# Existing finite world sources -> actual player interaction -> real shelter/pot.
	for resource in ["wood", "wood", "shellfish"]:
		var found := false
		for entry in (game.get("interactables") as Array).duplicate():
			if entry.get("id") != resource: continue
			(game.get("player") as Node3D).global_position = (entry.node as Node3D).global_position
			game.call("_interact")
			found = true
			break
		assert(found)
	assert(int(game.get("wood")) >= 3 and int(game.get("raw_shellfish")) >= 1)
	assert(game.call("_try_place_shelter", Vector3.ZERO))
	game.call("_interact_hearth")
	assert(game.get("stew_servings") == 1)
	game.set("weather_phase", 2)
	game.set("day_count", 2)
	game.set("day_period", 2)
	game.set("traveler_boarded", true)
	game.set("resident_met", true)
	game.set("sailmaker_boarded", true)
	game.set("sailmaker_met", true)
	game.set("player_health", 2)
	game.call("_set_traveler_boarded")
	game.call("_set_sailmaker_boarded")
	var setting := game.get_node("ArkRoot/BuiltShelter/SharedMealSetting") as Node3D
	assert(not setting.visible)
	assert(setting.find_children("*", "CollisionObject3D", true, false).is_empty())
	assert(setting.find_children("*", "Light3D", true, false).is_empty())
	_player(Vector3(-0.65, 0.19, -0.35))
	game.call("_begin_shared_table_meal")
	game.call("_update_hud")
	assert(game.get("shared_meal_gathering_pending") and game.get("stew_servings") == 0)
	assert(setting.visible and (setting.get_node("Soup0") as Node3D).visible)
	_player(Vector3(12, 0.19, 0))
	await _walk()
	assert(game.get("shared_meal_paused") and game.get("shared_meal_count") == 0 and game.get("player_health") == 2)
	assert((setting.get_node("CoveredPot") as Node3D).visible and not (setting.get_node("Soup0") as Node3D).visible)
	(game.get("ark_root") as Node3D).position = Vector3(10, 0, 4)
	(game.get("ark_root") as Node3D).rotation.y = 0.4
	await _reload()
	assert(game.get("shared_meal_paused") and game.get("stew_servings") == 0)
	for height in [-1.0, -0.3, 3.0]:
		_player(Vector3(-0.65, height, -0.35))
		_key(KEY_E)
		game.call("_complete_shared_table_meal")
		assert(not game.call("_player_at_shared_table") and game.get("shared_meal_count") == 0)
	_player(Vector3(-0.65, 0.19, -0.35))
	await _walk()
	assert(game.get("shared_meal_paused"), "return alone must not resume")
	_key(KEY_E)
	assert(not game.get("shared_meal_paused") and game.get("shared_meal_count") == 0)
	await _walk()
	assert(game.call("_shared_table_ready") and game.get("shared_meal_count") == 0)
	var resident := game.get("traveler_marker") as Node3D
	var old_position := resident.position
	resident.reparent(game, false)
	game.call("_complete_shared_table_meal")
	assert(game.get("shared_meal_count") == 0, "foreign-parent local coordinates cannot count as seated")
	resident.reparent(game.get("ark_root"), false)
	resident.position = old_position
	_key(KEY_E, true)
	assert(game.get("shared_meal_count") == 0, "held key echo is not participation")
	game.set("weather_phase", 1)
	game.call("_process", 0.1)
	assert(game.get("shared_meal_paused") and not game.call("_shared_table_ready"))
	assert(str(game.get("traveler_action")) == "棚下避雨")
	game.set("weather_phase", 2)
	_key(KEY_E)
	await _walk()
	game.call("_toggle_sailing")
	assert(game.get("sailing_mode") and game.get("shared_meal_paused"))
	_key(KEY_E)
	assert(not game.get("sailing_mode"), "dinner must not steal helm exit")
	await _reload()
	assert(game.get("shared_meal_paused") and game.get("stew_servings") == 0)
	_player(Vector3(-0.65, 0.19, -0.35))
	game.set("day_period", 3)
	game.call("_advance_world_period", "meal_test")
	assert(game.get("day_count") == 3 and game.get("shared_meal_paused"))
	# Dawn may legitimately schedule work: never interrupt it to resume a meal.
	if game.get("resident_gather_pending"):
		var task := str(game.get("resident_gather_target_id"))
		_key(KEY_E)
		assert(game.get("resident_gather_pending") and game.get("resident_gather_target_id") == task and game.get("shared_meal_paused"))
		game.call("_recall_resident_gatherer", "test_cleanup")
	game.set("weather_phase", 2)
	_key(KEY_E)
	await _walk()
	_key(KEY_E)
	assert(game.get("shared_meal_count") == 1 and game.get("shared_meal_day") == 3 and game.get("player_health") == 3)
	game.call("_complete_shared_table_meal")
	_key(KEY_E, true)
	assert(game.get("shared_meal_count") == 1 and game.get("stew_servings") == 0)
	var event: Dictionary = game.get("memories").latest("resident_meal_shared").event
	assert(event.facts.day == 3 and event.facts.reserved_day == 2 and event.facts.participant_count == 3)
	await _reload()
	assert(game.get("shared_meal_count") == 1 and not game.get("shared_meal_gathering_pending"))
	setting = game.get_node("ArkRoot/BuiltShelter/SharedMealSetting")
	assert(setting.visible and not (setting.get_node("Soup0") as Node3D).visible and not (setting.get_node("CoveredPot") as Node3D).visible)
	game.queue_free()
	await process_frame
	saver.clear_for_test()
	print("ARK_HOME_MEAL_TEST_OK: finite source/cook, presence/E, pause/restore/storm/sailing/day, exact once")
	quit()
