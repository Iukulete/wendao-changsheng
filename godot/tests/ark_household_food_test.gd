extends SceneTree
## A real finite island source -> actual return walk -> pantry -> fetching -> pot
## -> carried soup -> pantry -> G withdrawal -> actual two-resident shared table.
## Building material, boarding/date and player repositioning are explicit fixtures.
const Scene = preload("res://scenes/ark_greybox.tscn")
const Save = preload("res://scripts/ark_greybox_save.gd")
const Food = preload("res://scripts/modules/rooms/ark_food_storage.gd")
var game: Node3D
var failures := 0
var save_root: String
var calls: Array[int] = []
func _initialize() -> void: _run.call_deferred()
func _check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error("HOUSEHOLD_FOOD: "+message)
func _events(id: String) -> int:
	return game.world_events.filter(func(row: Dictionary) -> bool: return row.id==id).size()
func _key(key: int) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	game._unhandled_key_input(event)
func _tick() -> void:
	var before: Vector3 = game.traveler_marker.global_position
	var clock := Time.get_ticks_usec()
	game._process(.05)
	calls.append(Time.get_ticks_usec()-clock)
	_check(before.distance_to(game.traveler_marker.global_position)<=.0361,"normal cooking movement spends its real walking budget")
	await physics_frame
func _capture(_stage: String) -> void: pass
func _load_exact(label: String) -> void:
	var work: Dictionary = game.kitchen.snapshot()
	var stock: Dictionary = game.economy.snapshot()
	_check(game._save_progress(),"save "+label)
	game._load_progress()
	await physics_frame
	_check(not game.get_meta("save_load_blocked",false) and game.kitchen.snapshot()==work and game.MemoryScript.facts_equal(game.economy.snapshot(),stock),"load exact work/stock with no offline meal: "+label)
func _pause(label: String) -> void:
	var work: Dictionary = game.kitchen.snapshot()
	var stock: Dictionary = game.economy.snapshot()
	game.resident_kitchen.reconcile(game)
	game.resident_kitchen.step(game,.1)
	_check(game.kitchen.snapshot()==work and game.economy.snapshot()==stock,"pause retains raw/cooked food: "+label)
func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/household_food_test_%d" % OS.get_process_id())
	var service := Save.new(save_root)
	service.clear_for_test()
	game = Scene.instantiate()
	game.save_root_override = save_root
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	await physics_frame
	game.wood = 5 # Declared building fixture; food below must come from the island.
	game.player.position = Vector3(0,1.1,1.75)
	_check(game._try_place_shelter(Vector3.ZERO) and game._try_place_storage(Vector3(2,.12,.5)),"actual starter shelter/chest with unchanged costs")
	game.resident_met = true
	game.traveler_boarded = true
	game._set_traveler_boarded()
	game.day_count = 2
	game.day_period = game.DayPeriod.MORNING
	game.weather_phase = game.WeatherPhase.AFTER
	game.resident_gather_policy = "shellfish_first"
	_check(game.raw_shellfish==0 and game.stew_servings==0 and Food.stock(game.economy)==0,"no food fixture or starting gift")
	_check(game._begin_resident_daily_gather() and game.resident_gather_resource=="shellfish","autonomous worker selects a real nearby food source")
	var source_id: String = game.resident_gather_target_id
	var source: Dictionary = game.economy.source(source_id)
	var amount: int = int(source.get("remaining",0))
	_check(amount>0,"selected source was finite and nonempty")
	for i in 1200:
		game._process_resident_gathering(.1)
		await physics_frame
		if not game.resident_gather_pending: break
	_check(not game.resident_gather_pending and game.economy.source(source_id).remaining==0,"actually harvested once and walked back to the chest")
	_check(game.raw_shellfish==0 and game.economy.inventory(Food.OWNER,"shellfish")==amount and game.economy.audit().ok,"resident harvest belongs to household storage, not a fabricated player backpack credit")
	var delivered: Array = game.world_events.filter(func(row: Dictionary) -> bool: return row.id=="resident_gather_delivered")
	_check(delivered.size()==1 and delivered[0].facts.inventory_owner==Food.OWNER and delivered[0].facts.delivery_mode=="ark_return","delivery event names the real owner and normal return")
	await _load_exact("harvest returned")
	# Rotation is a real furniture-edit command, not a fixture teleport.
	_check(game._start_fixture_edit("storage") and game._try_move_fixture(game.storage_position,1),"rotate the real box without changing stock")
	await physics_frame
	game.day_period = game.DayPeriod.EVENING
	game._set_weather_visuals()
	for i in 700:
		await _tick()
		if game.kitchen.carrying_raw(): break
	_check(game.kitchen.carrying_raw() and game.kitchen.order.phase=="cook" and game.economy.inventory(Food.CARRY,"shellfish")==1 and game.raw_shellfish==0,"worker really reaches rotated chest and picks one item into her tote")
	game.resident_kitchen.present(game)
	_check(game.traveler_body.has_node("HouseholdFoodTote/FreshShell"),"raw ingredient has a distinct, reversible carried prop")
	await _capture("01_fetch_raw")
	await _load_exact("raw food in transit")
	game.player.global_position = game._ark_node("BuiltStorage").global_position+Vector3(0,.3,1)
	_key(KEY_G)
	_check(game.food_storage.pending and game._hud_choice_view().id=="pantry","G opens the real chest modal with native choice controls")
	_pause("food modal")
	_key(KEY_ESCAPE)
	_check(not game.food_storage.pending,"Esc closes without moving supplies")
	for i in 700:
		await _tick()
		if game.kitchen.active() and int(game.kitchen.order.elapsed_usec)>=1000000: break
	_check(game.resident_kitchen.arrived(game) and game.kitchen.order.elapsed_usec>=1000000 and _events("resident_meal_cooked")==0,"actual pot arrival and partial work produce no soup")
	await _load_exact("partly cooked")
	for i in 100:
		await _tick()
		if game.kitchen.delivering(): break
	_check(game.kitchen.delivering() and game.kitchen.completed==1 and game.economy.inventory(Food.CARRY,"stew_servings")==1,"work transforms real carried ingredient into carried soup")
	_check(game.economy.inventory(Food.OWNER,"stew_servings")==0 and game.stew_servings==0 and _events("resident_meal_cooked")==1 and _events("resident_meal_prepared")==0,"cooked is not falsely reported as already delivered")
	game.resident_kitchen.present(game)
	_check(game.traveler_body.has_node("HouseholdFoodTote/CoveredSoupBowl") and not game.traveler_body.has_node("HouseholdFoodTote/FreshShell"),"visual contents change only after real cooking")
	await _capture("02_cooked_in_transit")
	await _load_exact("soup in transit")
	game.kitchen.enabled = false # Completed food still must return, even after policy pause.
	game.hud_drawer.show()
	_pause("drawer with finished soup")
	game.hud_drawer.hide()
	for i in 700:
		await _tick()
		if not game.kitchen.active(): break
	_check(not game.kitchen.active() and game.economy.inventory(Food.OWNER,"stew_servings")==1 and game.economy.inventory(Food.CARRY,"stew_servings")==0 and _events("resident_meal_prepared")==1,"worker walks soup back and stores it exactly once; policy pause never strands already cooked dinner")
	_check(game.resident_kitchen._at(game,game.food_storage.station(game)) and not game.traveler_body.has_node("HouseholdFoodTote"),"delivery occurs at the real box face and removes only temporary tote")
	await _load_exact("dinner stored")
	game.player.global_position = game._ark_node("BuiltStorage").global_position+Vector3(0,.3,1)
	_key(KEY_G)
	await _capture("03_pantry_menu")
	_key(KEY_2)
	_check(game.stew_servings==1 and game.economy.inventory(Food.OWNER,"stew_servings")==0 and _events("household_food_withdrawn")==1,"actual G/2 withdraws one serving to the player")
	var withdrawn: Dictionary = game.economy.snapshot()
	_key(KEY_2)
	_check(game.economy.snapshot()==withdrawn,"stale choice cannot repeat a withdrawal")
	game.sailmaker_met = true
	game.sailmaker_boarded = true
	game.sailmaker_joined_day = game.day_count
	game._set_sailmaker_boarded()
	game.player.global_position = game.ark_root.to_global(game.shelter_position+Vector3(game.SHARED_MEAL_MAT_OFFSET.x,.19,game.SHARED_MEAL_MAT_OFFSET.z)+Vector3(0,0,.8))
	game._begin_shared_table_meal()
	_check(game.shared_meal_gathering_pending and game.stew_servings==0,"one real serving is reserved for the existing shared table")
	for i in 700:
		await _tick()
		if game._shared_table_ready(): break
	_check(game._shared_table_ready(),"both residents actually reach their table positions")
	await _capture("04_shared_table")
	game._complete_shared_table_meal()
	_check(game.shared_meal_count==1 and _events("resident_meal_shared")==1 and game.raw_shellfish==0 and game.economy.inventory(Food.OWNER,"shellfish")==amount-1 and game.economy.audit().ok,"finite island food supported one real shared meal, with the rest still stored")
	await _load_exact("after shared meal")
	var current: Dictionary = game._build_save_state()
	_check(int(current.schema_version)==43 and service.save_state(current).ok,"new schema saves the entire food chain")
	for kind in ["held_food","fake_delivery","downgrade","wrong_capacity"]:
		var bad := current.duplicate(true)
		match kind:
			"held_food": bad.modules.economy.inventories[Food.CARRY]["stew_servings"] = 1
			"fake_delivery": bad.kitchen.pantry_stored = 0
			"downgrade": bad.schema_version = 42
			"wrong_capacity": bad.modules.economy.capacities[Food.OWNER] = 999
		_check(not service.save_state(bad).ok and not game._prepare_module_restore(bad,false),"both save boundaries reject "+kind)
	# Distinct capacity fixture after the earned-food chain above. Fill the box
	# while another real source is in flight, then free exactly enough room.
	game.day_count = 3
	game.day_period = game.DayPeriod.MORNING
	_check(game._replenish_shore_supplies()>0,"existing next-morning tide renewal restores the depleted real source once")
	_check(game._begin_resident_daily_gather() and game.resident_gather_resource=="shellfish","next actual finite food gather begins before the pantry is full")
	var second_amount: int = game.economy.source(game.resident_gather_target_id).remaining
	game.raw_shellfish = 8 # Explicit competing-player load, not earned island food.
	game.player.global_position = game._ark_node("BuiltStorage").global_position+Vector3(0,.3,1)
	_key(KEY_G)
	var gather_before: Dictionary = game.gathering.snapshot()
	var position_before: Vector3 = game.traveler_marker.global_position
	game._process_resident_gathering(.1)
	_check(game.gathering.snapshot()==gather_before and game.traveler_marker.global_position==position_before,"food modal pauses an actual in-flight gather too")
	_key(KEY_1)
	_check(Food.stock(game.economy)==8,"competing player fills the finite pantry")
	for i in 1200:
		game._process_resident_gathering(.1)
		await physics_frame
		if game.resident_gather_phase=="returning" and game.traveler_marker.global_position.distance_to(game.ark_root.to_global(game.food_storage.station(game).target))<=.09: break
	_check(game.resident_gather_pending and game.resident_gather_payload==second_amount and Food.stock(game.economy)==8,"full destination retains the actual collected payload at the chest, rather than dropping or crediting it remotely")
	await _load_exact("full pantry with real gather cargo")
	for i in second_amount:
		_key(KEY_G)
		_key(KEY_3)
	for i in 40:
		game._process_resident_gathering(.1)
		await physics_frame
		if not game.resident_gather_pending: break
	_check(not game.resident_gather_pending and game.economy.carried(game.resident_task_id).is_empty() and Food.stock(game.economy)==8 and game.economy.audit().ok,"freeing exactly enough slots completes the same pending delivery without duplicate harvest")
	await _load_exact("capacity wait resolved")
	calls.sort()
	print("FOOD_CHAIN_SCENE_CPU usec p50=",calls[calls.size()/2]," p95=",calls[int(calls.size()*.95)]," max=",calls[-1]," headless controller-only; not FPS/GPU")
	game.save_service = null
	game.free()
	service.clear_for_test()
	if failures==0: print("ARK_HOUSEHOLD_FOOD_TEST_OK: actual source/gather/chest/raw tote/pot/soup tote/chest/G withdrawal/shared table, phase reloads and conserved economy")
	quit(1 if failures else 0)
