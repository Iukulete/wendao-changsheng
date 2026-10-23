extends SceneTree

const Paths = preload("res://tests/ark_test_paths.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
const Scene = preload("res://scenes/ark_greybox.tscn")

func _initialize() -> void:
	_run.call_deferred()

func _new_game(save_root: String) -> Node:
	var game := Scene.instantiate()
	game.set("save_root_override", save_root)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await physics_frame
	return game

func _discard(game: Node) -> void:
	game.set("save_service", null)
	game.queue_free()
	await process_frame

func _collect(game: Node, id: String) -> void:
	var source := game.get_node(NodePath(id)) as Node3D
	(game.get("player") as Node3D).global_position = source.global_position + Vector3(0, 0.5, 0)
	game.call("_interact")
	assert(id in game.get("collected_ids"), "ordinary E pickup must consume the actual world source")

func _next_morning(game: Node) -> void:
	for _period in range(4):
		game.call("_advance_world_period", "life_cycle_regression")

func _talk(game: Node) -> void:
	(game.get("player") as Node3D).global_position = (game.get_node("JadeSailKeeper") as Node3D).global_position + Vector3(0, 1, 0)
	game.call("_interact")

func _finish_delivery(game: Node) -> void:
	for _step in range(1000):
		if not game.get("jade_sail_industry_pending"):
			break
		game.call("_process_jade_sail_industry_gathering", 0.1)
	assert(not game.get("jade_sail_industry_pending"), "physical route must return to the actual vessel hold")
	assert(game.get("economy").audit().ok)

func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_life_cycle_save").simplify_path()
	assert(Paths.is_safe_save_root(save_root))
	var helper := Save.new(save_root)
	helper.clear_for_test()
	var game := await _new_game(save_root)
	game.set("life_period_elapsed", 0.0)
	# Real physics entry advances the life clock; separate direct ticks avoid moving
	# the player for 180 seconds in this focused test.
	game.call("_physics_process", 0.5)
	assert(is_equal_approx(game.get("life_period_elapsed"), 0.5))
	for _second in range(179):
		game.call("_tick_life_clock", 1.0)
	assert(game.get("day_period") == 0)
	game.call("_tick_life_clock", 0.5)
	assert(game.get("day_period") == 1 and game.get("life_period_elapsed") == 0.0)
	for key in ["building_mode", "traveler_choice_pending"]:
		game.set(key, true)
		game.call("_tick_life_clock", 1.0)
		assert(game.get("life_period_elapsed") == 0.0)
		game.set(key, false)
	for key in ["hud_drawer", "world_chart"]:
		(game.get(key) as Control).show()
		game.call("_tick_life_clock", 1.0)
		assert(game.get("life_period_elapsed") == 0.0)
		(game.get(key) as Control).hide()
	game.call("_tick_life_clock", 86400.0)
	assert(game.get("life_period_elapsed") == 1.0, "suspend cannot grant offline days or production")
	game.call("_tick_life_clock", -1.0)
	game.call("_tick_life_clock", INF)
	assert(game.get("life_period_elapsed") == 1.0)
	game.call("_wait_one_period")
	assert(game.get("day_period") == 2 and game.get("life_period_elapsed") == 0.0)
	game.set("life_period_elapsed", 45.5)
	assert(game.call("_save_progress"))
	await _discard(game)
	game = await _new_game(save_root)
	assert(game.get("life_period_elapsed") == 45.5 and game.get("day_period") == 2)
	# schema 34 has no renewal/clock fields: retain all gameplay, wait until next dawn.
	var legacy: Dictionary = game.call("_build_save_state")
	legacy.schema_version = 34
	legacy.erase("life_period_elapsed")
	legacy.erase("last_shore_replenish_day")
	assert(helper.save_state(legacy).ok)
	await _discard(game)
	game = await _new_game(save_root)
	assert(game.get("life_period_elapsed") == 0.0 and game.get("last_shore_replenish_day") == game.get("day_count"))
	game.call("_advance_world_period", "test")
	game.call("_advance_world_period", "test")
	assert(game.get("day_period") == 0)
	# The formerly permanent softlock: loot all trial patches before contracting.
	for id in ["JadeSailTidalShells", "JadeSailTidalShellsWest", "JadeSailTidalShellsNorth"]:
		_collect(game, id)
	_collect(game, "DriftwoodNear")
	assert(game.get("wood") == 3)
	(game.get("player") as Node3D).global_position = Vector3(-53, 1.3, -45)
	game.call("_interact")
	_talk(game)
	_talk(game)
	assert(game.get("jade_sail_industry_choice_pending"))
	game.call("_choose_jade_sail_industry_contract", true)
	assert(game.get("wood") == 0 and game.get("jade_sail_industry_active"))
	assert(not game.call("_begin_jade_sail_industry_daily_gather"))
	game.set("weather_phase", 2)
	var before_stock: int = game.get("raw_shellfish")
	_next_morning(game)
	assert(game.get("raw_shellfish") == before_stock, "tide renewal must not grant player inventory")
	assert(game.get("jade_sail_industry_pending"), "preharvested trial must recover at dawn")
	var task_id: String = game.get("jade_task_id")
	var source_id: String = game.get("jade_sail_industry_target_id")
	var economy = game.get("economy")
	var sources_before: Dictionary = economy.snapshot().sources
	assert(game.call("_replenish_shore_supplies") == 0 and economy.snapshot().sources == sources_before)
	assert(not economy.replenish_source(source_id, "shellfish", 1, "test_reserved").ok)
	assert(game.call("_save_progress"))
	await _discard(game)
	game = await _new_game(save_root)
	assert(game.get("jade_task_id") == task_id and game.get("gathering").source_in_use(source_id))
	_next_morning(game)
	assert(game.get("jade_task_id") == task_id, "dawn cannot overwrite an outbound reservation")
	for _step in range(1000):
		if game.get("jade_sail_industry_phase") == "returning":
			break
		game.call("_process_jade_sail_industry_gathering", 0.1)
	assert(game.get("jade_sail_industry_phase") == "returning")
	var cargo: Dictionary = game.get("economy").carried(task_id)
	_next_morning(game)
	assert(source_id in game.get("collected_ids") and game.get("economy").source(source_id).remaining == 0, "in-flight cargo must keep its consumed source depleted")
	assert(int(game.get("economy").carried(task_id).get("amount", -1)) == int(cargo.amount) and game.get("economy").carried(task_id).get("resource") == cargo.resource)
	assert(game.call("_save_progress"))
	await _discard(game)
	game = await _new_game(save_root)
	assert(not game.get_meta("save_load_blocked", false), "active cargo and depletion mirrors remain loadable after dawn")
	assert(int(game.get("economy").carried(task_id).get("amount", -1)) == int(cargo.amount) and game.get("economy").carried(task_id).get("resource") == cargo.resource)
	_finish_delivery(game)
	assert(game.get("jade_sail_industry_deliveries") == 1)
	_next_morning(game)
	assert(not source_id in game.get("collected_ids"))
	_finish_delivery(game)
	assert(game.get("jade_sail_industry_deliveries") == 2)
	_collect(game, "JadeSailDriftwood")
	_talk(game)
	assert(game.get("jade_sail_industry_choice_kind") == "affiliation")
	game.call("_choose_jade_sail_industry_contract", true)
	assert(game.get("jade_sail_industry_acquired"), "previously stuck contract can now reach real operating rights without injected materials")
	_next_morning(game)
	assert(game.get("jade_sail_industry_resource") == "wood", "renewing nearby shellfish must not starve the wood enterprise")
	_finish_delivery(game)
	_next_morning(game)
	assert(game.get("jade_sail_industry_resource") == "shellfish", "completed deliveries alternate resources with availability fallback")
	_finish_delivery(game)
	# Same-ID direct pickups remain collectable after a new dawn; no stock stacks.
	_collect(game, "DriftwoodNear")
	var wood_before: int = game.get("wood")
	_next_morning(game)
	_collect(game, "DriftwoodNear")
	assert(game.get("wood") == wood_before + 2)
	assert(game.call("_replenish_shore_supplies") == 0)
	assert(game.get("economy").audit().ok)
	var state: Dictionary = game.call("_build_save_state")
	assert(helper.save_state(state).ok)
	for invalid in [-0.1, 180.0, "45", true]:
		var bad := state.duplicate(true)
		bad.life_period_elapsed = invalid
		assert(not helper.save_state(bad).ok, "invalid clock cannot replace the good save")
	var bad_guard := state.duplicate(true)
	bad_guard.last_shore_replenish_day = int(state.day_count) + 1
	assert(not helper.save_state(bad_guard).ok)
	await _discard(game)
	# An unsupported on-disk save must survive automatic ticks and save attempts.
	helper.clear_for_test()
	state.schema_version = Save.MAX_SCHEMA_VERSION + 1
	var payload := JSON.stringify(state)
	var encoded := JSON.stringify({"format":Save.FORMAT,"version":Save.VERSION,"payload":payload,"sha256":helper._sha256(payload)})
	var path := save_root.path_join(Save.FILE_NAME)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(encoded)
	file.close()
	game = await _new_game(save_root)
	assert(game.get_meta("save_load_blocked", false))
	game.set("life_period_elapsed", 179.5)
	game.call("_tick_life_clock", 0.5)
	assert(not game.call("_save_progress") and FileAccess.get_file_as_string(path) == encoded)
	await _discard(game)
	helper.clear_for_test()
	print("ARK_LIFE_CYCLE_TEST_OK:")
	quit(0)
