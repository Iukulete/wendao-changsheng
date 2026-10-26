extends SceneTree
## Real scene movement/work/transactions, declared stock/calendar/travel fixtures.
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
		push_error("RESIDENT_KITCHEN: "+message)
func _events(id: String) -> int:
	return game.world_events.filter(func(row: Dictionary) -> bool: return row.id == id).size()
func _spawn() -> void:
	game = Scene.instantiate()
	game.save_root_override = save_root
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await physics_frame
	_check(game.home_art_sample.enabled,"cooking integration uses the real production art default")
func _capture(_stage: String) -> void: pass
func _assert_paused(label: String) -> void:
	var state: Dictionary = game.kitchen.snapshot()
	var ledger: Dictionary = game.economy.snapshot()
	game.resident_kitchen.reconcile(game)
	game.resident_kitchen.step(game,.1)
	game.resident_kitchen.present(game)
	_check(game.kitchen.snapshot() == state and game.economy.snapshot() == ledger,"paused work cannot advance or charge: "+label)
	_check(not game.traveler_body.has_node("TemporaryKitchenWorkPose"),"paused work clears temporary pose: "+label)
func _tick(delta: float = .05) -> void:
	var before: Vector3 = game.traveler_marker.position
	var clock := Time.get_ticks_usec()
	game._process(delta)
	calls.append(Time.get_ticks_usec()-clock)
	_check(before.distance_to(game.traveler_marker.position) <= minf(delta,.1)*.72+.0001,"cooking movement never exceeds actual walking budget")
	await physics_frame
func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/kitchen_scene_test_%d" % OS.get_process_id())
	var service := Save.new(save_root)
	service.clear_for_test()
	await _spawn()
	game.wood = 3
	_check(game._try_place_shelter(Vector3.ZERO),"actual shelter fixture")
	game.resident_met = true
	game.traveler_boarded = true
	game._set_traveler_boarded()
	game.day_count = 2
	game.day_period = 2
	game.weather_phase = 2
	game.raw_shellfish = 3 # Explicit ingredient fixture, never gameplay generation.
	game.stew_servings = 0
	game._set_weather_visuals()
	await physics_frame
	_check(game.RoomRoles.available("galley",game._room_role_facts()),"actual template has a usable galley capability")
	var legacy: Dictionary = game._build_save_state().duplicate(true)
	legacy.schema_version = 41
	legacy.erase("kitchen")
	_check(service.save_state(legacy).ok,"genuine old-format fixture needs no new kitchen data")
	game._load_progress()
	_check(not game.kitchen.active() and game.kitchen.completed == 0 and game.raw_shellfish == 3 and game.stew_servings == 0 and _events("resident_meal_prepared") == 0,"old load grants no dinner, progress or invented cooking history")
	var body: Node3D = game.traveler_body
	var arm: MeshInstance3D = body.get_node("ArmRight")
	var arm_transform := arm.transform
	var pot: Node3D = game._ark_node("BuiltShelter/HearthPot")
	var lid: Node3D = pot.get_node("PotLid")
	var lid_transform := lid.transform
	# A single stalled update may move/work only its bounded slice.
	await _tick(100)
	_check(game.kitchen.active() and game.kitchen.order.elapsed_usec == 0 and game.raw_shellfish == 3,"distant worker and a huge delta cannot complete dinner")
	for i in 600:
		await _tick()
		if game.kitchen.active() and int(game.kitchen.order.elapsed_usec) >= 1000000: break
	_check(game.kitchen.active() and game.kitchen.order.elapsed_usec >= 1000000 and game.resident_kitchen.arrived(game),"real worker reaches the real pot and actually starts work")
	_check(game.raw_shellfish == 3 and game.stew_servings == 0 and not arm.visible and not lid.visible and body.has_node("TemporaryKitchenWorkPose"),"partial work has visible reversible pose but no early debit/output")
	var kitchen_before_art: Dictionary = game.kitchen.snapshot()
	game._toggle_home_art_sample()
	game._toggle_home_art_sample()
	_check(game.home_art_sample.enabled and game.kitchen.snapshot() == kitchen_before_art and not arm.visible and not lid.visible and arm.transform == arm_transform,"F7 during real cooking preserves work, original arm transforms and hidden pot lid")
	await _capture("01_hearth_work")
	for facility in [pot,game._ark_node("BuiltShelter")]:
		facility.hide()
		_assert_paused("hidden actual kitchen facility")
		facility.show()
		var original_mode: int = facility.process_mode
		facility.process_mode = Node.PROCESS_MODE_DISABLED
		_assert_paused("disabled actual kitchen facility")
		facility.process_mode = original_mode
	for flag in ["sailing_mode","building_mode","resident_repair_pending"]:
		game.set(flag,true)
		_assert_paused(flag)
		game.set(flag,false)
	game.weather_phase = game.WeatherPhase.STORM
	_assert_paused("storm")
	game.weather_phase = game.WeatherPhase.AFTER
	game.day_period = game.DayPeriod.NIGHT
	_assert_paused("night")
	game.day_period = game.DayPeriod.EVENING
	game.shared_meal_gathering_pending = true
	game.shared_meal_paused = false
	_assert_paused("shared meal takes priority")
	game.shared_meal_gathering_pending = false
	game.raw_shellfish = 0 # Explicit player-used-last-ingredient fixture.
	_assert_paused("no remaining ingredient")
	game.raw_shellfish = 3
	game.stew_servings = 2 # Explicit full-food-stock fixture.
	_assert_paused("two servings already stocked")
	game.stew_servings = 0
	var blocker := StaticBody3D.new()
	blocker.name = "KitchenClearanceTestBlocker"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2,2,2)
	shape.shape = box
	blocker.add_child(shape)
	game.ark_root.add_child(blocker)
	blocker.global_position = pot.global_position+Vector3.UP*.4
	await physics_frame
	await physics_frame
	_assert_paused("actual solid station obstruction")
	_check(game.resident_kitchen.station(game).is_empty(),"all cooking faces genuinely blocked by solid geometry")
	blocker.free()
	await physics_frame
	await physics_frame
	var displaced_progress: int = game.kitchen.order.elapsed_usec
	game.traveler_marker.position = Vector3(0,.12,1.6) # Explicit displacement, not a gameplay teleport.
	game.resident_kitchen.step(game,.1)
	_check(not game.resident_kitchen.arrived(game) and game.kitchen.order.elapsed_usec == displaced_progress,"displaced worker must walk back, never work remotely")
	var elapsed: int = game.kitchen.order.elapsed_usec
	game.hud_drawer.show()
	await _tick()
	_check(game.kitchen.order.elapsed_usec == elapsed and arm.visible and lid.visible and arm.transform == arm_transform and lid.transform == lid_transform,"drawer pause restores original meshes and preserves uncharged progress")
	game._toggle_kitchen_policy()
	_check(not game.kitchen.enabled and game.raw_shellfish == 3,"explicit kitchen policy pauses without prepayment")
	_check(game._save_progress(),"in-flight work and paused policy save")
	game._load_progress()
	_check(not game.kitchen.enabled and game.kitchen.order.elapsed_usec == elapsed and game.raw_shellfish == 3 and _events("resident_meal_prepared") == 0,"load resumes exact unfinished work, not offline food")
	game.hud_drawer.hide()
	game._toggle_kitchen_policy()
	for i in 600:
		await _tick()
		if game.kitchen.completed == 1: break
	_check(game.kitchen.completed == 1 and not game.kitchen.active() and game.raw_shellfish == 2 and game.stew_servings == 1,"actual remaining work converts exactly one finite shell into one serving")
	_check(_events("resident_meal_prepared") == 1 and game.economy.audit().ok,"successful recipe has exactly one factual event and conserved ledger")
	for i in 100: await _tick()
	_check(game.raw_shellfish == 2 and game.stew_servings == 1,"same evening cannot repeatedly cook")
	for idle_period in [game.DayPeriod.DAY,game.DayPeriod.EVENING]:
		game.day_period = idle_period # Explicit calendar fixture; no elapsed work.
		game._update_traveler_schedule()
		_check(game.resident_washing.walk_step_clear(game,game.traveler_target_position,game.traveler_target_position),"day/evening idle target stays outside actual cot, hearth and walls")
	game.day_period = game.DayPeriod.EVENING
	game._update_traveler_schedule()
	_check(game._save_progress(),"completed work saves")
	game._load_progress()
	_check(game.kitchen.completed == 1 and game.stew_servings == 1 and _events("resident_meal_prepared") == 1,"completed reload cannot duplicate dinner or history")
	# Actual salvage/install commands; travel, wood and date are explicit fixtures.
	game.player.global_position = game.get_node("PressureWreckInteractable").global_position+Vector3.UP
	game._interact()
	game.player.position = Vector3(0,1.1,1.2)
	game.wood = 5
	_check(game._try_place_workbench(Vector3(2,.12,1.5)),"real workbench for pressure equipment")
	game._interact_workbench()
	_check(game.pressure_galley_choice_pending,"existing discovered upgrade offered")
	game._build_pressure_galley()
	_check(game.pressure_galley_built and game._ark_node("BuiltShelter/PressureGalley") != null,"actual pressure pot replaces old cookware")
	# A genuine old idle coordinate is now inside the larger cot's footprint.
	# Preserve it on disk/load; ordinary budgeted walking must recover it.
	var legacy_idle := Vector3(.8,.12,-.35)
	game.traveler_marker.position = legacy_idle
	_check(game._save_progress(),"legacy full-size-cot overlap fixture saves")
	game._load_progress()
	_check(game.traveler_marker.position.is_equal_approx(legacy_idle),"load must not teleport a resident out of old furniture overlap")
	game.day_count = 3
	game.day_period = 2
	game.stew_servings = 0 # Declared meal-consumption fixture.
	game._set_weather_visuals()
	for i in 600:
		await _tick()
		if game.kitchen.active() and game.resident_kitchen.arrived(game): break
	_check(game.kitchen.active() and game.resident_kitchen.arrived(game),"worker returns to actual upgraded station")
	var elapsed_before: int = game.kitchen.order.elapsed_usec
	for i in 10: await _tick(.1)
	_check(game.kitchen.completed == 1 and game.kitchen.order.elapsed_usec == elapsed_before+2000000,"pressure tool still requires real work, at twice the effective rate")
	await _capture("02_pressure_work")
	for i in 20:
		await _tick(.1)
		if game.kitchen.completed == 2: break
	_check(game.kitchen.completed == 2 and game.raw_shellfish == 1 and game.stew_servings == 1 and _events("resident_meal_prepared") == 2,"upgraded station delivers only after its actual shorter work")
	var current: Dictionary = game._build_save_state()
	_check(service.save_state(current).ok,"new schema43 has consistent module/ledger")
	var bad := current.duplicate(true)
	bad.kitchen.completed += 1
	_check(not service.save_state(bad).ok and not game._prepare_module_restore(bad,false),"both file boundary and staged loader reject fabricated kitchen completion")
	var unbalanced := current.duplicate(true)
	unbalanced.modules.economy.totals.shellfish.consumed += 1
	_check(game.KitchenScript.matches_save(unbalanced) and not service.save_state(unbalanced).ok and not game._prepare_module_restore(unbalanced,false),"matching domestic counters cannot hide an unconserved economy at either boundary")
	game.day_count = 4
	game.stew_servings = 0 # Declared next-day meal-consumption fixture.
	game.resident_kitchen.reconcile(game)
	_check(game.kitchen.active(),"next evening can start another real order")
	var pressure_pot: Node3D = game._ark_node("BuiltShelter/PressureGalley")
	var parent := pressure_pot.get_parent()
	parent.remove_child(pressure_pot)
	game.resident_kitchen.check_dependencies(game)
	_check(not game.kitchen.active() and game.raw_shellfish == 1 and _events("resident_kitchen_order_cancelled") == 1,"removing the actual station cancels unpaid work without spending ingredients")
	parent.add_child(pressure_pot)
	_check(game.ark_root.find_children("PressureGalley","",true,false).size() == 1,"restoring station has one physical instance")
	# Write a checksummed but semantically invalid file, with no valid backup.
	# The live scene must survive rejection, not only a direct validator call.
	service.clear_for_test()
	var payload := JSON.stringify(bad)
	var corrupt_file := FileAccess.open(save_root.path_join(Save.FILE_NAME),FileAccess.WRITE)
	_check(corrupt_file != null,"isolated malformed-file fixture opens")
	corrupt_file.store_string(JSON.stringify({"format":Save.FORMAT,"version":Save.VERSION,"payload":payload,"sha256":payload.sha256_text()}))
	corrupt_file.close()
	var live_order: Dictionary = game.kitchen.snapshot()
	var live_economy: Dictionary = game.economy.snapshot()
	var live_body_id: int = game.traveler_body.get_instance_id()
	game._load_progress()
	_check(game.get_meta("save_load_blocked",false) and game.kitchen.snapshot() == live_order and game.economy.snapshot() == live_economy and game.traveler_body.get_instance_id() == live_body_id,"malformed real file leaves the current world, work and economy intact")
	calls.sort()
	print("KITCHEN_SCENE_CPU usec p50=",calls[calls.size()/2]," p95=",calls[int(calls.size()*.95)]," max=",calls[-1]," calls=",calls.size()," headless controller-only; not frame/GPU/FPS")
	game.save_service = null
	game.free()
	service.clear_for_test()
	if failures == 0: print("ARK_RESIDENT_KITCHEN_TEST_OK:")
	quit(1 if failures else 0)
