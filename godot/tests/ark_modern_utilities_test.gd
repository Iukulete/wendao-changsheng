extends SceneTree
const Economy = preload("res://scripts/modules/economy/ark_economy.gd")
const Utilities = preload("res://scripts/modules/modern/ark_modern_utilities.gd")
const Power = preload("res://scripts/modules/modern/ark_power.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
const Scene = preload("res://scenes/ark_greybox.tscn")
var game: Node3D
var saver: RefCounted
var save_root: String

func _initialize() -> void:
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_MINIMIZED
		root.unfocusable = true
	_run.call_deferred()

func _module_tests() -> void:
	var a = Power.new()
	var b = Power.new()
	a.install()
	b.install()
	for index in 100: assert(a.advance(100000,1,2).ok)
	for index in 10: assert(b.advance(1000000,1,2).ok)
	assert(a.snapshot() == b.snapshot(),"integer time partition does not create charge")
	assert(a.debit("wash",1,500).ok)
	var before: Dictionary = a.snapshot()
	assert(a.debit("wash",1,500).get("duplicate"))
	assert(not a.debit("wash",1,501).ok and not a.debit("wash",3,500).ok)
	assert(before == a.snapshot())
	var restored = Power.new()
	assert(restored.restore(JSON.parse_string(JSON.stringify(before))))
	before.charge += 1
	assert(not restored.restore(before))
	var economy = Economy.new()
	economy.seed_inventory("player",{"wood":1})
	economy.seed_inventory("storage",{"wood":3})
	economy.seed_inventory(Utilities.TANK,{})
	economy.set_capacity(Utilities.TANK,6)
	var utility = Utilities.new()
	utility.salvaged = true
	before = economy.snapshot()
	assert(not utility.install(economy,{"wood":["storage"]}).ok)
	assert(before == economy.snapshot(),"missing rare component spends no common wood")
	economy.seed_source(Utilities.SOURCE,"utility_core",1,"pressure_wreck")
	assert(economy.collect_direct(Utilities.SOURCE,"player").ok)
	assert(utility.install(economy,{"wood":["storage"]}).ok)
	assert(utility.power.charge == 0 and economy.inventory(Utilities.TANK,"fresh_water") == 0)
	assert(utility.advance(180000000,3,2,true,economy).produced == 0,"no solar production at night")
	assert(utility.advance(180000000,1,2,false,economy).produced == 0,"moving/dry intake cannot produce water")
	assert(utility.power.charge == Power.CAPACITY)
	assert(utility.advance(180000000,1,2,true,economy).produced == 6)
	assert(economy.inventory(Utilities.TANK,"fresh_water") == 6 and economy.audit().ok)
	before = economy.snapshot()
	assert(utility.advance(180000000,1,2,true,economy).produced == 0)
	assert(economy.snapshot() == before,"full tank creates no input receipts")
	assert(utility.wash("player",1,economy).ok)
	before = economy.snapshot()
	assert(not utility.wash("player",1,economy).ok and before == economy.snapshot())
	assert(utility.wash("tidekeeper",1,economy).ok)
	assert(utility.wash("sailmaker",1,economy).ok)
	assert(economy.inventory(Utilities.TANK,"fresh_water") == 3)
	assert(economy.snapshot().streams.size() == 4)
	var other = Utilities.new()
	assert(other.restore(JSON.parse_string(JSON.stringify(utility.snapshot()))))
	assert(Utilities.valid(other.snapshot()))
	var bad: Dictionary = other.snapshot()
	bad.produced += 1
	assert(not other.restore(bad))
	before = economy.snapshot()
	assert(economy.process_stream(Utilities.TANK,"ark_purifier",6,{}, {"fresh_water":1}).get("duplicate"))
	assert(not economy.process_stream(Utilities.TANK,"ark_purifier",6,{}, {"fresh_water":2}).ok)
	assert(not economy.process_stream(Utilities.TANK,"ark_purifier",8,{}, {"fresh_water":1}).ok)
	assert(before == economy.snapshot())
	assert(economy.restore(JSON.parse_string(JSON.stringify(before))))
	assert(economy.process_stream(Utilities.TANK,"ark_purifier",6,{}, {"fresh_water":1}).get("duplicate"),"JSON replay has identical numeric intent")
	var receipt_count: int = economy.snapshot().receipts.size()
	for sequence in range(1,201):
		assert(economy.process_stream("player","test_machine",sequence,{}, {"wood":1}).ok)
	assert(economy.snapshot().streams.size() == 5 and economy.snapshot().receipts.size() == receipt_count,"continuous production uses bounded stable streams")
	var legacy: Dictionary = economy.snapshot()
	legacy.erase("streams")
	assert(Economy.new().restore(legacy),"old seven-map saves remain supported")
	# Water command failure rolls back the paired power debit.
	var power_before: Dictionary = utility.power.snapshot()
	economy.process_stream(Utilities.TANK,"wash:player",2,{"fresh_water":1},{})
	assert(not utility.wash("player",2,economy).ok)
	assert(utility.power.snapshot() == power_before)
	before = economy.snapshot()
	assert(not economy.process_stream("absent","zero",1,{"wood":0},{}).ok)
	assert(before == economy.snapshot())
	# A restored lifetime counter near its explicit ceiling rejects the whole
	# interval before any substep/time/resource mutation, not halfway through it.
	utility.power.generated = Power.MAX_TOTAL-100
	utility.power.curtailed = utility.power.generated-utility.power.consumed-utility.power.charge
	var utility_before: Dictionary = utility.snapshot()
	assert(not utility.advance(2000000,1,2,true,economy).ok)
	assert(utility.snapshot() == utility_before and economy.snapshot() == before)

func _spawn() -> void:
	game = Scene.instantiate()
	game.save_root_override = save_root
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await physics_frame

func _run() -> void:
	_module_tests()
	save_root = ProjectSettings.globalize_path("res://../.local/test_modern_utilities_%d" % OS.get_process_id())
	saver = Save.new(save_root)
	saver.clear_for_test()
	await _spawn()
	assert(game.economy.source(Utilities.SOURCE).remaining == 1)
	var legacy_state: Dictionary = game._build_save_state()
	legacy_state.schema_version = 39
	legacy_state.erase("modern_utilities")
	legacy_state.modules.economy.erase("streams")
	legacy_state.modules.economy.sources.erase(Utilities.SOURCE)
	legacy_state.modules.economy.totals.erase("utility_core")
	legacy_state.modules.economy.inventories.erase(Utilities.TANK)
	legacy_state.modules.economy.capacities.erase(Utilities.TANK)
	assert(saver.save_state(legacy_state).ok)
	game._load_progress()
	assert(not game.get_meta("save_load_blocked",false) and not game.modern_utilities.salvaged and not game.modern_utilities.installed)
	assert(not game._has_blueprint(Utilities.BLUEPRINT) and game.economy.source(Utilities.SOURCE).remaining == 1,"schema39 migration adds a finite unexplored source, never free equipment")
	# Declared late-game fixture: this test checks real interaction/payment/save,
	# not that a player sailed from the opening island to the far wreck.
	game.player.global_position = game.get_node("PressureWreckInteractable").global_position
	game._interact()
	assert(game.modern_utilities.salvaged and game.economy.inventory("player","utility_core") == 1)
	var before: Dictionary = game.economy.snapshot()
	game._interact()
	assert(before == game.economy.snapshot(),"wreck component is finite")
	game.player.global_position = game.ark_root.to_global(Vector3(0,1.1,1.5))
	game.wood = 13
	assert(game._try_place_shelter(Vector3.ZERO))
	assert(game._try_place_workbench(Vector3(2,.12,-.5)))
	game.keel_beams = 1
	game.keel_wreck_searched = true
	game._learn_blueprint("keel_deck_expansion","modern_test_fixture")
	assert(game._try_place_raft_extension(Vector3(0,.12,-4.2)))
	game._install_modern_utilities()
	assert(game.modern_utilities.installed and game.wood == 0)
	assert(game.ark_root.has_node("ModernWaterCorner/SolarCanopy"))
	assert(not game._dismantle_raft_extension(),"connected machinery cannot lose support")
	game.day_period = 1
	game.weather_phase = 2
	assert(game._modern_intake_ready())
	game._advance_modern_utilities(180.0)
	assert(game.economy.inventory(Utilities.TANK,"fresh_water") > 0)
	await physics_frame
	var route: PackedVector3Array = game._build_ark_local_walk_route(Vector3(.8,.12,-1.3),game.ModernUtilityProps.APPROACH)
	assert(not route.is_empty() and route[-1].distance_to(game.ModernUtilityProps.APPROACH) < .1,"wash approach is supported and reachable around the fixture")
	game.player.global_position = game.ark_root.to_global(Vector3(.8,.6,-3.05))
	game.is_swimming = false
	game.player_health = 2
	game._use_modern_wash()
	assert(game.player_health == 3 and game.modern_utilities.washes.player.count == 1)
	before = game.economy.snapshot()
	game._use_modern_wash()
	assert(before == game.economy.snapshot() and game.player_health == 3)
	var clock_copy = Utilities.new()
	var clock_economy = Economy.new()
	assert(clock_copy.restore(game.modern_utilities.snapshot()) and clock_economy.restore(game.economy.snapshot()))
	assert(clock_copy.advance(180000000,game.day_period,game.weather_phase,game._modern_intake_ready(),clock_economy).ok)
	game._tick_life_clock(.5)
	game._advance_world_period("modern_test")
	assert(game.modern_utilities.snapshot() == clock_copy.snapshot(),"half second plus period remainder produces exactly one old-light interval")
	assert(Economy.Memory.facts_equal(game.economy.snapshot(),clock_economy.snapshot()))
	assert(game._save_progress())
	var saved: Dictionary = game._build_save_state()
	assert(Utilities.matches_save(saved))
	var charge: int = game.modern_utilities.power.charge
	game.free()
	await process_frame
	await _spawn()
	assert(not game.get_meta("save_load_blocked",false))
	assert(game.modern_utilities.installed and game.modern_utilities.power.charge == charge)
	assert(game.modern_utilities.washes.player.count == 1)
	await _capture()
	game._load_progress()
	assert(game.ark_root.find_children("ModernWaterCorner","",true,false).size() == 1)
	assert(game.economy.audit().ok)
	var valid_state: Dictionary = game._build_save_state()
	for kind in ["charge","water","blueprint","source","wash_day","support","power_cost","output_sequence"]:
		var bad := valid_state.duplicate(true)
		match kind:
			"charge": bad.modern_utilities.power.charge += 1
			"water": bad.modules.economy.inventories[Utilities.TANK].fresh_water += 1
			"blueprint": bad.learned_blueprint_ids.erase(Utilities.BLUEPRINT)
			"source": bad.modules.economy.sources[Utilities.SOURCE].remaining = 1
			"wash_day": bad.modern_utilities.washes.player.day = bad.day_count+1
			"support": bad.raft_extension_built = false
			"power_cost": bad.modern_utilities.power.consumed -= 1
			"output_sequence": bad.modules.economy.streams.ark_purifier.sequence += 1
		assert(not game._prepare_module_restore(bad,false),"tampered modern state rejected: "+kind)
		assert(not saver._validate_state(bad).ok)
	assert(saver._validate_state(valid_state).ok)
	for kind in ["inventory_shape","cargo_shape","reservations_shape","day_type"]:
		var malformed := valid_state.duplicate(true)
		match kind:
			"inventory_shape": malformed.modules.economy.inventories.player = 7
			"cargo_shape": malformed.modules.economy.cargo.bad = false
			"reservations_shape": malformed.modules.economy.reservations = []
			"day_type": malformed.day_count = "tomorrow"
		assert(not Utilities.matches_save(malformed),"malformed nested shape rejects without runtime error: "+kind)
		assert(not saver._validate_state(malformed).ok)
	var overfull := valid_state.duplicate(true)
	var extra: int = 7-int(overfull.modules.economy.inventories[Utilities.TANK].fresh_water)
	overfull.modern_utilities.produced += extra
	overfull.modern_utilities.power.generated += extra*Utilities.FILTER_COST
	overfull.modern_utilities.power.consumed += extra*Utilities.FILTER_COST
	overfull.modern_utilities.power.consumers.purifier.sequence += extra
	overfull.modules.economy.streams.ark_purifier.sequence += extra
	overfull.modules.economy.inventories[Utilities.TANK].fresh_water += extra
	overfull.modules.economy.totals.fresh_water.input += extra
	assert(Utilities.valid(overfull.modern_utilities),"individually consistent counters")
	assert(Economy.new().restore(overfull.modules.economy),"conservation alone does not prove tank capacity")
	assert(not Utilities.matches_save(overfull),"reject a seven-unit forged tank even when ledgers conserve")
	game.free()
	saver.clear_for_test()
	print("ARK_MODERN_UTILITIES_TEST_OK: finite salvage, shared payment, solar/storage/purifier/wash, bounded ledger, rollback, schema41 reload and tamper checks")
	quit()

func _capture() -> void:
	var output := OS.get_environment("ARK_MODERN_CAPTURE_ROOT")
	if DisplayServer.get_name() == "headless" or output.is_empty(): return
	assert(output.to_lower().begins_with("d:/"))
	DirAccess.make_dir_recursive_absolute(output)
	game._set_weather_visuals()
	game.home_art_sample.set_enabled(game,true)
	game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game.camera.size = 7.4
	var target: Vector3 = game.ark_root.to_global(Vector3(.4,.8,-3.4))
	game.camera.global_position = target+Vector3(5,4,-6)
	game.camera.look_at(target)
	for layer in game.find_children("*","CanvasLayer",true,false): layer.visible = false
	for index in 5:
		RenderingServer.force_draw(false)
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("01_solar_water_corner.png"))
	for label in game.find_children("*","Label3D",true,false): label.visible = false
	target = game.ark_root.to_global(game.ModernUtilityProps.AT+Vector3(0,.9,0))
	game.camera.size = 3.7
	game.camera.global_position = target+Vector3(4,2.8,-4)
	game.camera.look_at(target)
	for index in 5:
		RenderingServer.force_draw(false)
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("02_device_detail.png"))
