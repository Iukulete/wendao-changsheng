extends SceneTree
const Economy = preload("res://scripts/modules/economy/ark_economy.gd")
const Construction = preload("res://scripts/modules/construction/ark_construction.gd")
const Paths = preload("res://tests/ark_test_paths.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
var game: Node3D
var save_root: String

func _initialize() -> void:
	_run.call_deferred()

func _modules() -> void:
	var economy = Economy.new()
	assert(economy.seed_inventory("player", {"wood": 1, "keel": 0}))
	assert(economy.seed_inventory("storage", {"wood": 5}))
	assert(economy.seed_inventory("other_ship", {"wood": 90}))
	var construction = Construction.new()
	construction.configure(economy)
	var shared := {"wood": ["storage"]}
	var before: Dictionary = economy.snapshot()
	assert(not construction.commit_shared("missing_part", "player", {"wood": 4, "keel": 1}, shared, func(): return true).ok)
	assert(Economy.Memory.facts_equal(before, economy.snapshot()), "all costs preflight before either owner is debited")
	assert(not construction.commit_shared("invalid_space", "player", {"wood": 2}, shared, func(): return false).ok)
	assert(Economy.Memory.facts_equal(before, economy.snapshot()), "placement rejection spends nothing")
	assert(not construction.commit_shared("duplicate_owner", "player", {"wood": 2}, {"wood": ["storage", "storage"]}, func(): return true).ok)
	assert(construction.commit_shared("bench", "player", {"wood": 2}, shared, func(): return true).ok)
	assert(economy.inventory("player", "wood") == 0 and economy.inventory("storage", "wood") == 4)
	assert(economy.inventory("other_ship", "wood") == 90 and economy.audit().ok)
	var paid: Dictionary = economy.snapshot()
	assert(construction.commit_shared("bench", "player", {"wood": 2}, shared, func(): assert(false)).duplicate)
	assert(Economy.Memory.facts_equal(paid, economy.snapshot()), "replay is exact once even after primary inventory changed")
	assert(not construction.commit_shared("bench", "player", {"wood": 2}, {}, func(): return true).ok, "reusing an operation with different sources conflicts")
	var restored_economy = Economy.new()
	assert(restored_economy.restore(JSON.parse_string(JSON.stringify(paid))))
	var restored_construction = Construction.new()
	restored_construction.configure(restored_economy)
	assert(restored_construction.restore(JSON.parse_string(JSON.stringify(construction.snapshot()))))
	assert(restored_construction.audit().ok)
	assert(not economy.consume_shared("player", {"wood": 7}, "too_much", shared).ok)
	assert(Economy.Memory.facts_equal(paid, economy.snapshot()), "foreign cargo is not a fallback")

func _spawn() -> void:
	game = load("res://scenes/ark_greybox.tscn").instantiate()
	game.set("save_root_override", save_root)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	(game.get("player") as Node).set_physics_process(false)
	await physics_frame

func _collect(item_id: String) -> void:
	for entry in game.get("interactables") as Array:
		if str(entry.get("item_id", "")) == item_id:
			(game.get("player") as Node3D).global_position = (entry.node as Node3D).global_position
			game.call("_interact")
			return
	assert(false, "missing finite source " + item_id)

func _run() -> void:
	_modules()
	save_root = ProjectSettings.globalize_path("res://../.local/test_home_supply").simplify_path()
	assert(Paths.is_safe_save_root(save_root))
	var saver = Save.new(save_root)
	saver.clear_for_test()
	await _spawn()
	await _collect("DriftwoodNear")
	await _collect("DriftwoodRidge")
	(game.get("player") as Node3D).position = Vector3(0, 1.1, 1.75)
	assert(game.call("_try_place_shelter", Vector3.ZERO))
	assert(game.call("_try_place_storage", Vector3(2, 0.12, 0.5)))
	game.call("_interact_storage")
	assert(game.get("wood") == 0 and game.get("stored_wood") == 1)
	game.set("resident_met", true)
	game.set("traveler_boarded", true)
	game.call("_set_traveler_boarded")
	game.set("weather_phase", 2)
	game.set("resident_gather_policy", "wood_first")
	game.set("day_count", 2)
	game.set("day_period", 0)
	assert(game.call("_begin_resident_daily_gather"))
	assert(game.get("resident_gather_target_id") == "DriftwoodShore")
	assert(game.call("_available_build_wood") == 1, "reserved/outbound wood cannot fund a build")
	for step in range(500):
		if not game.get("resident_gather_pending"): break
		game.call("_process_resident_gathering", 0.1)
		await physics_frame
	assert(not game.get("resident_gather_pending"))
	assert(game.get("wood") == 0 and game.get("stored_wood") == 3, "real resident delivery reaches the chest")
	game.call("_update_hud")
	assert(str((game.get("hud_details") as Label).text).contains("本舟储箱 3"))
	var before: Dictionary = game.get("economy").snapshot()
	assert(not game.call("_try_place_workbench", Vector3(20, 0.12, 20)))
	assert(Economy.Memory.facts_equal(before, game.get("economy").snapshot()))
	assert(game.call("_try_place_workbench", Vector3(-2, 0.12, 1.5)), "no manual chest withdrawal is required")
	assert(game.get("wood") == 0 and game.get("stored_wood") == 1)
	assert(game.get("economy").audit().ok)
	assert(game.call("_save_progress"))
	game.free()
	await process_frame
	await _spawn()
	assert(not game.get_meta("save_load_blocked", false) and game.get("workbench_built"))
	assert(game.get("wood") == 0 and game.get("stored_wood") == 1)
	game.call("_load_progress")
	assert(game.get("wood") == 0 and game.get("stored_wood") == 1 and game.get("economy").audit().ok)
	# Repair also uses actual chest stock, without a second debit on repeated E.
	game.set("shelter_roof_damaged", true)
	game.set("repair_choice_pending", true)
	game.call("_repair_damaged_part", "shelter")
	assert(not game.get("shelter_roof_damaged") and game.get("stored_wood") == 0 and game.get("wood") == 0)
	game.call("_repair_damaged_part", "shelter")
	assert(game.get("stored_wood") == 0 and game.get("economy").audit().ok)
	# Bounded setup for late construction, not a claim that this test explored
	# the far reef. The first half above earned every plank from world sources.
	game.set("stored_wood", 4)
	game.call("_learn_blueprint", "keel_deck_expansion", "home_supply_test_fixture")
	before = game.get("economy").snapshot()
	assert(not game.call("_try_place_raft_extension", Vector3(0, .12, -4.2)))
	assert(Economy.Memory.facts_equal(before, game.get("economy").snapshot()), "missing keel preserves all shared wood")
	game.set("keel_beams", 1)
	assert(game.call("_try_place_raft_extension", Vector3(0, .12, -4.2)))
	assert(game.get("wood") == 0 and game.get("stored_wood") == 0 and game.get("keel_beams") == 0)
	assert(game.call("_dismantle_raft_extension"))
	assert(game.get("wood") == 4 and game.get("stored_wood") == 0 and game.get("keel_beams") == 1)
	assert(not game.call("_dismantle_raft_extension"), "one actual structure refunds only once")
	assert(game.get("economy").audit().ok and game.call("_save_progress"))
	game.free()
	saver.clear_for_test()
	print("ARK_HOME_SUPPLY_TEST_OK: real finite gather -> chest -> build; atomic rejection, source scope, replay and reload")
	quit()
