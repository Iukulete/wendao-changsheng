extends SceneTree
const Scene = preload("res://scenes/ark_greybox.tscn")
const Economy = preload("res://scripts/modules/economy/ark_economy.gd")
const Utilities = preload("res://scripts/modules/modern/ark_modern_utilities.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
var game: Node3D
var saver: RefCounted
var save_root: String

func _initialize() -> void: _run.call_deferred()

func _module_tests() -> void:
	var ledger = Economy.new()
	ledger.seed_inventory("player",{"wood":1})
	ledger.seed_inventory("storage",{"wood":3})
	ledger.set_capacity("player",2)
	var before: Dictionary = ledger.snapshot()
	assert(not ledger.process_shared_stream("player","mixed",1,{"wood":4},{"shellfish":3},{"wood":["storage"]}).ok)
	assert(before == ledger.snapshot(),"net capacity counts only primary-owner deductions, not borrowed stock")
	assert(ledger.process_shared_stream("player","mixed",1,{"wood":4},{"shellfish":2},{"wood":["storage"]}).ok)
	assert(ledger.inventory("player","shellfish") == 2 and ledger.inventory("storage","wood") == 0 and ledger.audit().ok)
	before = ledger.snapshot()
	assert(ledger.process_shared_stream("player","mixed",1,{"wood":4},{"shellfish":2},{"wood":["storage"]}).get("duplicate",false))
	assert(not ledger.process_shared_stream("player","mixed",1,{"wood":4},{"shellfish":2},{}).ok)
	assert(before == ledger.snapshot() and ledger.restore(JSON.parse_string(JSON.stringify(before))))
	assert(ledger.process_shared_stream("player","mixed",1,{"wood":4},{"shellfish":2},{"wood":["storage"]}).get("duplicate",false))
	before = ledger.snapshot()
	for bad in [{"wood":["storage","storage"]},{"wood":["player"]},{"utility_core":["storage"]}]:
		assert(not ledger.process_shared_stream("player","mixed",2,{"wood":1},{},bad).ok)
		assert(ledger.snapshot() == before)
	var malformed := before.duplicate(true)
	malformed.streams.mixed.shared = "storage"
	assert(not ledger.restore(malformed) and ledger.snapshot() == before)

	var economy = Economy.new()
	economy.seed_inventory("player",{"wood":2})
	economy.seed_inventory("storage",{"wood":2})
	economy.seed_inventory(Utilities.TANK,{})
	economy.set_capacity(Utilities.TANK,6)
	economy.seed_source(Utilities.SOURCE,"utility_core",1,"pressure_wreck")
	economy.collect_direct(Utilities.SOURCE,"player")
	var unit = Utilities.new()
	unit.salvaged = true
	assert(unit.install(economy,{"wood":["storage"]}).ok)
	assert(unit.advance(180000000,1,2,true,economy).produced == 6)
	assert(unit.wash("player",1,economy).ok)
	unit.advance(1150000,3,2,true,economy)
	assert(unit.filter_us > 0 and unit.carry_us > 0)
	var state: Dictionary = unit.snapshot()
	var power: Dictionary = unit.power.snapshot()
	var water: int = economy.inventory(Utilities.TANK,"fresh_water")
	assert(unit.pack(economy).ok and economy.inventory("player","wood") == 4 and economy.inventory("player","utility_core") == 1)
	assert(unit.power.snapshot() == power and unit.washes == state.washes and unit.filter_us == state.filter_us and unit.carry_us == state.carry_us)
	before = economy.snapshot()
	state = unit.snapshot()
	assert(not unit.pack(economy).ok and not unit.wash("player",2,economy).ok)
	assert(unit.advance(180000000,1,2,true,economy).produced == 0 and unit.snapshot() == state and economy.snapshot() == before)
	assert(economy.transfer("player","storage",{"wood":2},"fixture:shared_wood").ok)
	assert(unit.install(economy,{"wood":["storage"]}).ok)
	assert(economy.inventory("player","wood") == 0 and economy.inventory("storage","wood") == 0)
	economy.set_capacity("player",4)
	before = economy.snapshot()
	state = unit.snapshot()
	assert(not unit.pack(economy).ok and unit.snapshot() == state and economy.snapshot() == before)
	economy.set_capacity("player",1000000000)
	var receipts: int = economy.snapshot().receipts.size()
	for index in 200:
		assert(unit.pack(economy).ok)
		assert(unit.install(economy,{"wood":["storage"]}).ok)
		assert(unit.power.snapshot() == power and unit.washes.player.count == 1 and unit.filter_us == state.filter_us and unit.carry_us == state.carry_us)
	assert(economy.snapshot().receipts.size() == receipts and economy.snapshot().streams.size() == 4 and economy.audit().ok)
	assert(economy.inventory(Utilities.TANK,"fresh_water") == water and not unit.wash("player",1,economy).ok)
	assert(Utilities.valid(unit.snapshot()) and Utilities.new().restore(JSON.parse_string(JSON.stringify(unit.snapshot()))))
	for key in ["installations","removals"]:
		var bad: Dictionary = unit.snapshot()
		bad[key] += 1
		assert(not Utilities.valid(bad))
	for value in [null,{},true,"2",3,2.5]:
		var bad: Dictionary = unit.snapshot()
		bad.version = value
		assert(not Utilities.valid(bad),"malformed format version rejects without runtime error")
	# A full global stream table must not remove hardware before refund succeeds.
	var crowded = Economy.new()
	crowded.seed_inventory("player",{"wood":4,"utility_core":1})
	var fresh = Utilities.new()
	fresh.salvaged = true
	assert(fresh.install(crowded,{}).ok)
	for index in 64: assert(crowded.process_stream("player","fixture:"+str(index),1,{}, {"scrap":1}).ok)
	before = crowded.snapshot()
	state = fresh.snapshot()
	assert(not fresh.pack(crowded).ok and fresh.snapshot() == state and crowded.snapshot() == before)

func _spawn() -> void:
	game = Scene.instantiate()
	game.save_root_override = save_root
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await physics_frame
	assert(game.home_art_sample.enabled,"modern lifecycle uses the real production art default")

func _assert_modern_art() -> void:
	var unit: Node3D = game._ark_node(game.ModernUtilityProps.ROOT)
	assert(unit != null and game.home_art_sample.enabled)
	var plinth: MeshInstance3D = unit.get_node("TimberPlinth")
	var original: Dictionary = game.home_art_sample.get("_originals")[plinth.get_instance_id()]
	assert(plinth.mesh is ArrayMesh and plinth.material_override is ShaderMaterial,"fresh installation/reinstallation is painted immediately, not only after F7/load")
	var dynamic := {}
	for path in ["BatteryIndicator","TankGaugeWater","TankGaugeBacking","BasinWater","SolarCanopy/CellBed","SolarCanopy/Cell_0_0"]:
		var node: MeshInstance3D = unit.get_node(path)
		assert(node.mesh is BoxMesh and node.material_override is StandardMaterial3D)
		assert(not game.home_art_sample.get("_originals").has(node.get_instance_id()),"dynamic water/electrical cues retain their exact resource owner")
		dynamic[path] = {"mesh":node.mesh,"material":node.material_override}
	var state: Dictionary = game._build_save_state()
	for repeat in 5:
		game._toggle_home_art_sample()
		assert(not game.home_art_sample.enabled and plinth.mesh == original.mesh and plinth.material_override == original.material)
		game._toggle_home_art_sample()
		assert(game.home_art_sample.enabled and plinth.mesh is ArrayMesh)
		game.ModernUtilityProps.refresh(game)
		for path in dynamic:
			var node: MeshInstance3D = unit.get_node(path)
			assert(node.mesh == dynamic[path].mesh and node.material_override == dynamic[path].material)
	assert(game.MemoryScript.facts_equal(state,game._build_save_state()),"visual toggles never reset electricity, water, charge, ledger or remembered washes")
	var indicator: MeshInstance3D = unit.get_node("BatteryIndicator")
	var charge: int = game.modern_utilities.power.charge
	game.modern_utilities.power.charge = 0 # Explicit display fixture, restored before any simulation.
	game.ModernUtilityProps.refresh(game)
	assert(indicator.material_override.albedo_color == Color("b98365"))
	game.modern_utilities.power.charge = 500
	game.ModernUtilityProps.refresh(game)
	assert(indicator.material_override.albedo_color == Color("79cbb3"))
	game.modern_utilities.power.charge = charge
	game.ModernUtilityProps.refresh(game)
	assert(is_equal_approx(unit.get_node("TankGaugeWater").scale.y,maxf(.01,float(game.economy.inventory(Utilities.TANK,"fresh_water"))/6.0)))
	assert(unit.get_node("BasinWater").visible == (game.economy.inventory(Utilities.TANK,"fresh_water") > 0))

func _step() -> void:
	var old: Vector3 = game.traveler_marker.position
	game._process(.05)
	assert(game.traveler_marker.position.distance_to(old) <= .72*.05+.00001)
	await physics_frame

func _run() -> void:
	_module_tests()
	save_root = ProjectSettings.globalize_path("res://../.local/test_modern_packing_%d" % OS.get_process_id())
	saver = Save.new(save_root)
	saver.clear_for_test()
	await _spawn()
	# Declared construction/travel fixture, not a claim of a complete sailed route.
	game.player.global_position = game.get_node("PressureWreckInteractable").global_position
	game._interact()
	game.player.global_position = game.ark_root.to_global(Vector3(0,1.1,1.75))
	game.wood = 15
	assert(game._try_place_workshop_home_template(Vector3(0,.12,0)))
	game.keel_beams = 1
	game.keel_wreck_searched = true
	game._learn_blueprint("keel_deck_expansion","packing_fixture")
	assert(game._try_place_raft_extension(Vector3(0,.12,-4.2)))
	game._install_modern_utilities()
	_assert_modern_art()
	game.day_period = 1
	game.weather_phase = 2
	game._advance_modern_utilities(180.0)
	game.player.global_position = game.ark_root.to_global(game.ModernUtilityProps.APPROACH+Vector3(0,.5,0))
	game.is_swimming = false
	game._use_modern_wash()
	var power: Dictionary = game.modern_utilities.power.snapshot()
	var legacy: Dictionary = game._build_save_state()
	legacy.schema_version = 40
	legacy.modern_utilities.version = 1
	legacy.modern_utilities.erase("installations")
	legacy.modern_utilities.erase("removals")
	assert(Utilities.matches_save(legacy) and saver.save_state(legacy).ok)
	game._load_progress()
	assert(not game.get_meta("save_load_blocked",false) and game.modern_utilities.installations == 1 and game.modern_utilities.removals == 0)
	assert(game.modern_utilities.power.snapshot() == power and game.modern_utilities.washes.player.count == 1)
	assert(game._build_save_state().schema_version == 43 and game.modern_utilities.snapshot().version == 2)
	_assert_modern_art()
	game.player.global_position = game.get_node("residentMarker").global_position
	game._interact()
	game._interact()
	assert(game.traveler_choice_pending)
	game._choose_traveler_boarding(true)
	game.player.global_position = game.ark_root.to_global(game.ModernUtilityProps.APPROACH+Vector3(0,.5,0))
	for index in 1200:
		await _step()
		if game.resident_washing.using_station(game): break
	assert(game.resident_washing.using_station(game))
	var before: Dictionary = game.economy.snapshot()
	assert(not game._pack_modern_utilities() and game.economy.snapshot() == before,"occupied actual station is not removed mid-action")
	for index in 45: await _step()
	assert(game.modern_utilities.washes.tidekeeper.count == 1)
	power = game.modern_utilities.power.snapshot()
	var water: int = game.economy.inventory(Utilities.TANK,"fresh_water")
	var washes: Dictionary = game.modern_utilities.washes.duplicate(true)
	game.modern_action_button.pressed.emit()
	assert(game.modern_pack_choice_pending and game._hud_choice_view().id == "modern_pack" and game._hud_choice_view().options.size() == 2)
	await _capture("01_pack_confirmation")
	game._on_hud_choice_requested(KEY_2,"modern_pack")
	assert(not game.modern_pack_choice_pending and game.modern_utilities.installed)
	game.modern_action_button.pressed.emit()
	game.player.global_position += Vector3(30,0,0)
	game._on_hud_choice_requested(KEY_1,"modern_pack")
	assert(game.modern_utilities.installed and not game.modern_pack_choice_pending,"confirmation rechecks physical proximity")
	game.player.global_position = game.ark_root.to_global(game.ModernUtilityProps.APPROACH+Vector3(0,.5,0))
	game.modern_action_button.pressed.emit()
	game._on_hud_choice_requested(KEY_1,"modern_pack")
	assert(not game.modern_utilities.installed and game.wood == 4 and game.economy.inventory("player","utility_core") == 1)
	assert(game._ark_node(game.ModernUtilityProps.ROOT) == null and game.resident_washing.routine.owner.is_empty())
	var recalled: String = game.resident_washing.reflection(game,"tidekeeper")
	assert(recalled.contains("今天") and recalled.contains("那次洗漱") and not recalled.contains("看了看水台") and not recalled.contains("在这里"),"packed device is a genuine past experience, not a currently visible fixture")
	game.day_count = 2
	recalled = game.resident_washing.reflection(game,"tidekeeper")
	assert(recalled.contains("上回") and not recalled.contains("今天"))
	assert(game.resident_washing.reflection(game,"sailmaker").is_empty(),"a non-user does not acquire a synthetic washing memory")
	game.day_count = 1
	await _capture("02_stowed_status")
	before = game.economy.snapshot()
	game._on_hud_choice_requested(KEY_1,"modern_pack")
	assert(not game._pack_modern_utilities() and before == game.economy.snapshot())
	game._advance_modern_utilities(180.0)
	assert(game.modern_utilities.power.snapshot() == power and game.modern_utilities.washes == washes and game.economy.inventory(Utilities.TANK,"fresh_water") == water)
	assert(game._dismantle_raft_extension() and not game.raft_extension_built and game.wood == 8)
	assert(game._save_progress())
	game.free()
	await process_frame
	await _spawn()
	assert(not game.get_meta("save_load_blocked",false) and not game.modern_utilities.installed and not game.raft_extension_built and game.modern_utilities.removals == 1)
	assert(game.modern_utilities.power.snapshot() == power and game.modern_utilities.washes == washes and game.economy.inventory(Utilities.TANK,"fresh_water") == water)
	assert(game._try_place_raft_extension(Vector3(0,.12,-4.2)))
	game._install_modern_utilities()
	assert(game.modern_utilities.installed and game.modern_utilities.installations == 2 and game.wood == 0)
	_assert_modern_art()
	await _capture("03_reinstalled")
	assert(game.modern_utilities.power.snapshot() == power and game.modern_utilities.washes == washes and game.economy.inventory(Utilities.TANK,"fresh_water") == water)
	assert(not game.modern_utilities.wash("player",game.day_count,game.economy).ok and not game.modern_utilities.wash("tidekeeper",game.day_count,game.economy).ok)
	assert(game._save_progress())
	var valid: Dictionary = game._build_save_state()
	for kind in ["count","pack_output","reinstall_sequence","foreign_shared","extra_stream","core","downgrade"]:
		var bad := valid.duplicate(true)
		match kind:
			"count": bad.modern_utilities.removals += 1
			"pack_output": bad.modules.economy.streams[Utilities.PACK_STREAM].outputs.wood += 1
			"reinstall_sequence": bad.modules.economy.streams[Utilities.REINSTALL_STREAM].sequence += 1
			"foreign_shared": bad.modules.economy.streams[Utilities.REINSTALL_STREAM].shared = {"wood":["jade_sail_cargo"]}
			"extra_stream": bad.modules.economy.streams["modern_utilities:free"] = {"owner":"player","sequence":1,"costs":{},"outputs":{"wood":4}}
			"core": bad.modules.economy.inventories.player.utility_core = 1
			"downgrade": bad.schema_version = 40
		assert(not Utilities.matches_save(bad) and not saver._validate_state(bad).ok and not game._prepare_module_restore(bad,false),kind)
	assert(Utilities.matches_save(valid) and game.economy.audit().ok)
	game._load_progress()
	assert(game.ark_root.find_children("ModernWaterCorner","",true,false).size() == 1 and game.modern_utilities.washes == washes)
	_assert_modern_art()
	game.free()
	saver.clear_for_test()
	print("ARK_MODERN_PACKING_TEST_OK: atomic shared bounded streams, 200 no-reset pack/reinstall cycles, occupied station/proximity/confirmation/cancel, exact water/power/history, schema40 migration and schema41 tamper rejection, support removal/rebuild and actual reload; travel/stock fixtures declared")
	quit()

func _capture(_stage: String) -> void:
	if not OS.get_environment("ARK_PACKING_CAPTURE_ROOT").is_empty(): await process_frame
