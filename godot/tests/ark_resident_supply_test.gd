extends SceneTree
## Explicit initial workshop/calendar/foreign-stock/travel/injury fixtures.
## All subsequent repair/food/modern wood loads come from actual finite sources.
const Scene = preload("res://scenes/ark_greybox.tscn")
const Save = preload("res://scripts/ark_greybox_save.gd")
var game: Node3D
var failures := 0
var save_root: String
var calls: Array[int] = []
func _initialize() -> void: _run.call_deferred()
func _check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error("RESIDENT_SUPPLY: "+message)
func _events(id: String) -> Array:
	return game.world_events.filter(func(row: Dictionary) -> bool: return row.id==id)
func _capture(_stage: String) -> void: pass
func _key(key: int) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	game._unhandled_key_input(event)
func _tick() -> void:
	var before: Vector3 = game.traveler_marker.global_position
	var speed: float = game.RESIDENT_AUTO_GATHER_SPEED if game.resident_gather_pending else .72
	var clock := Time.get_ticks_usec()
	game._process(.05)
	calls.append(Time.get_ticks_usec()-clock)
	if game.resident_gather_pending: speed = game.RESIDENT_AUTO_GATHER_SPEED
	_check(before.distance_to(game.traveler_marker.global_position)<=speed*.05+.0002,"normal gather/kitchen walking spends its real movement budget")
	await physics_frame
func _until(predicate: Callable,label: String,limit: int = 1400) -> void:
	for i in limit:
		if predicate.call(): return
		await _tick()
	print("SUPPLY_WAIT_DIAGNOSTIC ",label," work=",game.household_work.snapshot()," stock=",game.economy.snapshot().inventories," gather=",game.resident_gather_phase," cargo=",game.resident_gather_payload," resident=",game.traveler_marker.global_position," maker=",game.sailmaker_marker.position," target=",game._household_work_target()," can_run=",game._household_work_can_run()," action=",game.sailmaker_action)
	_check(bool(predicate.call()),label)
func _reload(label: String) -> void:
	var stock: Dictionary = game.economy.snapshot()
	var work: Dictionary = game.household_work.snapshot()
	_check(game._save_progress(),"save "+label)
	game._load_progress()
	await physics_frame
	_check(not game.get_meta("save_load_blocked",false) and game.MemoryScript.facts_equal(stock,game.economy.snapshot()) and game.MemoryScript.facts_equal(work,game.household_work.snapshot()),"load preserves real stock, permission and work: "+label)
func _dawn() -> void:
	# Use the actual four period transitions, not an offline production shortcut.
	for i in 4: game._advance_world_period("supply_test_calendar_fixture")
	await physics_frame
func _visit(id: String) -> void:
	for entry in game.interactables:
		if entry.get("id")==id:
			game.player.global_position = entry.node.global_position+Vector3.UP*.5
			game._interact()
			return
	assert(false,"missing actual interactable "+id)
func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/resident_supply_test_%d" % OS.get_process_id())
	var service := Save.new(save_root)
	service.clear_for_test()
	game = Scene.instantiate()
	game.save_root_override = save_root
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	await physics_frame
	game.wood = 7 # Only the initial home is a material fixture, not later supplies.
	game.player.position = Vector3(0,1.1,1.75)
	_check(game._try_place_workshop_home_template(Vector3(0,.12,0)),"actual paid starter workshop")
	game.resident_met = true
	game.traveler_choice_pending = true
	_key(KEY_1)
	game.sailmaker_met = true
	game.sailmaker_choice_pending = true
	_key(KEY_1)
	_check(game.traveler_boarded and game.sailmaker_boarded and game.wood==0 and game.stored_wood==0,"actual invitations, finite construction and no stocked repair fixture")
	game.day_count = 2
	game.day_period = game.DayPeriod.MORNING
	game.economy.seed_inventory("other_ark",{"wood":100,"shellfish":100}) # Explicit unrelated-owner exclusion fixture.
	game._open_household_work_board()
	_check(game.household_work_choice_pending,"real work authorization prompt")
	_key(KEY_1)
	_check(game.household_work.enabled,"player explicitly authorizes repair; gathering itself never grants this permission")
	game._advance_weather()
	_check(game.weather_phase==game.WeatherPhase.STORM,"real storm phase")
	for i in 30: await _tick()
	_check(not game.resident_gather_pending and _events("resident_gather_started").is_empty(),"autonomy never dispatches in a storm")
	game._advance_weather()
	_check(game.shelter_roof_damaged and game.raft_edge_damaged,"real post-storm damage, not free completed repair facts")
	var demand: Dictionary = game.home_demand.review(game)
	_check(demand.reason=="repair_wood" and demand.repair_need==2 and demand.wood_available==0 and demand.food_available==0,"foreign stock cannot fund the household's missing repair material or food")
	game.hud_drawer.show()
	for i in 30: await _tick()
	_check(not game.resident_gather_pending,"reading the actual drawer cannot dispatch or consume a daily shift")
	game.hud_drawer.hide()
	await _capture("01_actual_shortage")
	var review_before: float = game.home_demand.review_remaining
	for invalid_step in [0.0,-.1,NAN,INF]: game.home_demand.step(game,invalid_step)
	_check(not game.resident_gather_pending and game.home_demand.review_remaining==review_before,"local zero/negative/nonfinite steps cannot advance its timer or dispatch a shift")
	await _until(func() -> bool: return game.resident_gather_pending,"automatic safe-morning repair-supply dispatch")
	_check(game.resident_gather_resource=="wood" and _events("resident_gather_started")[-1].facts.need_id=="repair_wood","shortage drives wood first even with no pantry food")
	await _until(func() -> bool: return game.resident_gather_payload>0,"real source harvested")
	demand = game.home_demand.review(game)
	_check(demand.wood_available==0 and demand.repair_need==2 and not game.economy.carried(game.resident_task_id).is_empty(),"harvested in-flight cargo is not available repair stock")
	await _reload("repair wood in flight")
	await _until(func() -> bool: return game.household_work.completed==2,"collector delivers, authorized craftswoman walks/works and repairs both parts")
	if game.household_work.completed!=2:
		game.save_service = null
		game.free()
		service.clear_for_test()
		quit(1)
		return
	_check(not game.shelter_roof_damaged and not game.raft_edge_damaged and game.stored_wood==0 and game.wood==0,"exactly the two genuinely gathered planks pay for two real repairs")
	_check(_events("resident_household_repair_completed").size()==2 and game.economy.inventory("other_ark","wood")==100,"no borrowed foreign resources or invented work")
	await _capture("02_repairs_completed")
	await _reload("automatic repair supply chain")
	var shift_count := _events("resident_gather_started").size()
	for i in 30: await _tick()
	_check(_events("resident_gather_started").size()==shift_count,"stock changes cannot bypass one actual shift per day")
	await _dawn()
	await _until(func() -> bool: return game.resident_gather_pending,"next actual dawn dispatch")
	_check(game.resident_gather_resource=="shellfish" and _events("resident_gather_started")[-1].facts.need_id=="food_reserve","missing food beats the nearer remaining driftwood under balanced policy")
	await _until(func() -> bool: return not game.resident_gather_pending,"first real pantry food return")
	_check(game.raw_shellfish==0 and game.economy.inventory("storage_food","shellfish")==1,"one actual source enters the pantry")
	await _dawn()
	await _until(func() -> bool: return game.resident_gather_pending,"second food shift after real daily renewal")
	await _until(func() -> bool: return not game.resident_gather_pending,"second real pantry food return")
	_check(game.economy.inventory("storage_food","shellfish")==2,"two daily finite food loads meet the target, not an infinite generator")
	await _dawn()
	await _until(func() -> bool: return game.resident_gather_pending,"wood reserve shift")
	_check(game.resident_gather_resource=="wood" and _events("resident_gather_started")[-1].facts.need_id=="wood_reserve","once food is stocked, the next shift maintains a small wood buffer")
	await _until(func() -> bool: return not game.resident_gather_pending,"reserve delivered")
	_check(game.stored_wood==2 and game.home_demand.review(game).reason=="stocked","real two-food/two-wood target reached")
	await _dawn()
	shift_count = _events("resident_gather_started").size()
	var stock: Dictionary = game.economy.snapshot()
	for i in 50: await _tick()
	_check(not game.resident_gather_pending and _events("resident_gather_started").size()==shift_count and game.economy.snapshot()==stock,"a stocked home rests and leaves finite world sources alone")
	await _capture("03_stocked_home")
	# Existing exploration commands supply the unique hull/modern components;
	# travel is a declared fixture, not a claim of earned sailing or combat.
	_visit("keel_wreck")
	_check(game.keel_beams==1 and game.wood==4,"actual unique wreck reward")
	game.player.position = Vector3(0,1.1,1.75)
	_check(game._try_place_raft_extension(Vector3(0,.12,-4.2)),"actual expansion spends wreck planks, leaving the household's two reserve planks")
	_check(game.stored_wood==2 and game.home_demand.review(game).wood_target==2,"a deck alone cannot fabricate a modern construction demand")
	_visit("pressure_wreck")
	_check(game.modern_utilities.salvaged and game.economy.inventory("player","utility_core")==1,"actual one-time equipment salvage and blueprint")
	game.player.position = Vector3(0,1.1,1.75)
	demand = game.home_demand.review(game)
	_check(demand.reason=="modern_install" and demand.wood_target==4 and demand.wood_need==2,"only now is modern installation genuinely within reach")
	await _capture("04_modern_material_need")
	await _until(func() -> bool: return game.resident_gather_pending,"stock review notices a new within-morning need without waiting another whole day")
	_check(_events("resident_gather_started")[-1].facts.need_id=="modern_install","new trip explains its real buildable modern need")
	await _until(func() -> bool: return not game.resident_gather_pending,"modern supply wood delivered")
	_check(game.stored_wood==4 and game.wood==0,"four usable household planks are genuinely delivered before installation")
	game._install_modern_utilities()
	_check(game.modern_utilities.installed and game.stored_wood==0 and game.economy.inventory("player","utility_core")==0,"player chooses installation; exact finite household wood and unique component pay once")
	game.day_period = game.DayPeriod.DAY
	game._advance_modern_utilities(30)
	_check(game.economy.inventory(game.ModernUtilitiesScript.TANK,"fresh_water")>0,"installed solar/filter chain actually produces limited drinking water")
	game.player_health = 2 # Explicit injury fixture to observe the existing benefit.
	game.player.global_position = game._ark_node(game.ModernUtilityProps.ROOT).global_position+Vector3(.4,.2,.4)
	var water_before: int = game.economy.inventory(game.ModernUtilitiesScript.TANK,"fresh_water")
	game._use_modern_wash()
	_check(game.player_health==3 and game.economy.inventory(game.ModernUtilitiesScript.TANK,"fresh_water")==water_before-1,"resident-supplied modern construction yields a real paid survival/comfort use")
	await _capture("05_modern_life_ready")
	await _reload("optional modern benefit")
	var saved: Dictionary = game._build_save_state()
	_check(saved.schema_version==43 and not saved.has("home_demand") and game.resident_gather_policy=="balanced" and game.economy.audit().ok,"demand is a derived projection, not a new parallel saved stock/planner owner")
	var saved_before: Dictionary = game._build_save_state()
	for i in 100: game.home_demand.summary(game)
	_check(game.MemoryScript.facts_equal(saved_before,game._build_save_state()),"UI demand queries never mutate progress, inventory or narrative")
	calls.sort()
	print("RESIDENT_SUPPLY_CPU usec p50=",calls[calls.size()/2]," p95=",calls[int(calls.size()*.95)]," max=",calls[-1]," calls=",calls.size()," headless controller-only; not FPS/GPU")
	game.save_service = null
	game.free()
	service.clear_for_test()
	if failures==0: print("ARK_RESIDENT_SUPPLY_TEST_OK: real storm shortage -> gather -> two authorized repairs -> food -> reserve -> rest -> actual optional modern upgrade and paid wash, persisted finite resources")
	quit(1 if failures else 0)
