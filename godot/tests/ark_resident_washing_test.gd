extends SceneTree
const Scene = preload("res://scenes/ark_greybox.tscn")
const Save = preload("res://scripts/ark_greybox_save.gd")
var game: Node3D
var saver: RefCounted
var save_root: String
var pose_checks := 0
var movement_checks := 0
var captures := {}

func _initialize() -> void:
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_MINIMIZED
		root.unfocusable = true
	_run.call_deferred()

func _spawn() -> void:
	game = Scene.instantiate()
	game.save_root_override = save_root
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await physics_frame
	assert(game.home_art_sample.enabled,"washing integration uses the production home presentation")

func _stock() -> int: return game.economy.inventory("utilities_tank","fresh_water")

func _step() -> void:
	var tide: Vector3 = game.traveler_marker.position
	var sail: Vector3 = game.sailmaker_marker.position
	game._process(.05)
	assert(game.traveler_marker.position.distance_to(tide) <= .72*.05+.00001,"washing may not teleport a traveler")
	assert(game.sailmaker_marker.position.distance_to(sail) <= .64*.05+.00001,"washing may not teleport a sailmaker")
	movement_checks += 2
	var pose = game.resident_washing.pose
	if pose.actor != "":
		assert(game.resident_washing.using_station(game))
		assert(pose.root.get_child_count() == 8 and pose.limbs.size() == 2)
		for entry in pose.entries: assert(not entry.node.visible,"original arms and personal belongings remain hidden on every washing frame")
		for limb in pose.limbs:
			var body: Node3D = game.traveler_body if pose.actor == "tidekeeper" else game.sailmaker_body
			var shoulder: Vector3 = body.to_global(limb.shoulder)
			assert((limb.upper.global_transform*Vector3(0,-.5,0)).distance_to(shoulder) < .0001)
			assert((limb.fore.global_transform*Vector3(0,.5,0)).distance_to(limb.hand.global_position) < .0001)
			var local_hand: Vector3 = game.ark_root.to_local(limb.hand.global_position)-game.ModernUtilityProps.AT
			assert(absf(local_hand.y-.87) < .013 and absf(local_hand.z-.31) < .001 and absf(local_hand.x+.07) < .14,"actual hands reach the current basin, not empty air")
			pose_checks += 1
		if not captures.has(pose.actor):
			captures[pose.actor] = true
			await _capture(pose.actor)
			var actor: String = pose.actor
			var original: Array = pose.entries.duplicate()
			var marker: Node3D = pose.facing_marker
			var yaw: float = pose.original_yaw
			pose.clear()
			assert(is_equal_approx(marker.rotation.y,yaw),"temporary facing restores its original yaw")
			for entry in original: assert(entry.node.transform == entry.transform and entry.node.visible == entry.visible,"every original arm/prop transform and visibility is restored")
			pose.apply(game,actor,game.resident_washing.routine.elapsed_us)
	await physics_frame

func _until_washing(actor: String) -> void:
	for index in 800:
		await _step()
		if game.resident_washing.routine.owner == actor and game.resident_washing.routine.phase == "washing": return
	push_error("resident never physically reached wash station: "+actor+" actual="+str(game.resident_washing.routine.view()))
	quit(1)

func _finish_day(day: int) -> void:
	for index in 2200:
		await _step()
		if game.modern_utilities.washes.get("tidekeeper",{}).get("day",0) == day and game.modern_utilities.washes.get("sailmaker",{}).get("day",0) == day: return
	push_error("both actual residents must finish day "+str(day)+" routine="+str(game.resident_washing.routine.view()))
	quit(1)

func _assert_interrupted() -> void:
	game.resident_washing.reconcile(game)
	game.resident_washing.step(game,.25)
	game.resident_washing.present(game)
	assert(game.resident_washing.routine.owner.is_empty() and game.resident_washing.pose.actor.is_empty() and _stock() == 6 and game.modern_utilities.washes.is_empty())

func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/test_resident_washing_%d" % OS.get_process_id())
	saver = Save.new(save_root)
	saver.clear_for_test()
	await _spawn()
	assert(game.resident_washing.reflection(game,"tidekeeper").is_empty())
	# Declared late-game construction/travel fixture. Gathering, blueprint
	# exploration and consent already have independent played-route regressions.
	game.player.global_position = game.get_node("PressureWreckInteractable").global_position
	game._interact()
	game.player.global_position = game.ark_root.to_global(Vector3(0,1.1,1.75))
	game.wood = 15
	assert(game._try_place_workshop_home_template(Vector3(0,.12,0)))
	game.keel_beams = 1
	game.keel_wreck_searched = true
	game._learn_blueprint("keel_deck_expansion","resident_wash_fixture")
	assert(game._try_place_raft_extension(Vector3(0,.12,-4.2)))
	game._install_modern_utilities()
	assert(game.modern_utilities.installed and game.wood == 0)
	for actor in ["tidekeeper","sailmaker"]:
		var marker: Node3D = game.get_node("residentMarker" if actor == "tidekeeper" else "sailmakerMarker")
		game.player.global_position = marker.global_position
		game._interact()
		game._interact()
		if actor == "tidekeeper":
			assert(game.traveler_choice_pending)
			game._choose_traveler_boarding(true)
		else:
			assert(game.sailmaker_choice_pending)
			game._choose_sailmaker_boarding(true)
	assert(game.traveler_boarded and game.sailmaker_boarded)
	game.day_period = 1
	game.weather_phase = 2
	game.player.global_position = game.ark_root.to_global(Vector3(0,1.1,1.75))
	game._advance_modern_utilities(180.0)
	assert(_stock() == 6)
	var initial_charge: int = game.modern_utilities.power.charge
	game.resident_washing.reconcile(game)
	game.resident_washing.step(game,100.0)
	assert(_stock() == 6 and game.resident_washing.routine.elapsed_us == 0 and game.modern_utilities.washes.is_empty(),"elapsed time while far away cannot consume or invent a wash")
	var unchanged: Dictionary = game.resident_washing.routine.view()
	for bad in [NAN,INF,-1.0]: game.resident_washing.step(game,bad)
	assert(game.resident_washing.routine.view() == unchanged)
	game.traveler_routine_route.clear()
	game.traveler_routine_route_target_set = true
	game.resident_washing.route_retry = .5
	game.resident_washing.step(game,.25)
	assert(game.traveler_routine_route_target_set and is_equal_approx(game.resident_washing.route_retry,.25),"an empty blocked route is not replanned on every frame")
	game.resident_washing.step(game,.25)
	assert(not game.traveler_routine_route_target_set and is_equal_approx(game.resident_washing.route_retry,.5),"route retry becomes available only after its bounded interval")
	await _until_washing("tidekeeper")
	assert(_stock() == 6)
	var wash_before_art: Dictionary = game.resident_washing.routine.view()
	game._toggle_home_art_sample()
	game._toggle_home_art_sample()
	assert(game.home_art_sample.enabled and game.resident_washing.routine.view() == wash_before_art and game.resident_washing.pose.actor == "tidekeeper")
	for entry in game.resident_washing.pose.entries: assert(not entry.node.visible,"F7 does not restore original arms through the currently active washing pose")
	var before: Dictionary = game.economy.snapshot()
	game.player.global_position = game.ark_root.to_global(game.ModernUtilityProps.APPROACH+Vector3(0,.5,0))
	game._use_modern_wash()
	assert(game.economy.snapshot() == before and not game.modern_utilities.washes.has("player"),"manual player does not double-book the occupied station")
	game.player.global_position = game.ark_root.to_global(Vector3(0,1.1,1.75))
	for flag in ["sailing_mode","building_mode"]:
		game.set(flag,true)
		_assert_interrupted()
		game.set(flag,false)
		await _until_washing("tidekeeper")
	game.day_period = 3
	_assert_interrupted()
	game.day_period = 1
	await _until_washing("tidekeeper")
	game.hud_drawer.visible = true
	_assert_interrupted()
	game.hud_drawer.visible = false
	await _until_washing("tidekeeper")
	game.shared_meal_gathering_pending = true
	game.shared_meal_paused = false
	assert(not game.resident_washing.eligible(game,"tidekeeper") and not game.resident_washing.eligible(game,"sailmaker"),"an active shared meal takes priority; no synthetic meal is recorded")
	game.shared_meal_gathering_pending = false
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	blocker.position = game.ModernUtilityProps.APPROACH+Vector3(0,1,0)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.3,1.5,.3)
	collision.shape = box
	blocker.add_child(collision)
	game.ark_root.add_child(blocker)
	await physics_frame
	await physics_frame
	game.resident_washing.reconcile(game)
	game.resident_washing.step(game,.25)
	game.resident_washing.present(game)
	assert(game.resident_washing.routine.phase == "walking" and game.resident_washing.routine.elapsed_us == 0 and game.resident_washing.pose.actor.is_empty() and _stock() == 6,"a physically blocked basin never earns an action")
	blocker.free()
	await physics_frame
	await physics_frame
	await _until_washing("tidekeeper")
	game.weather_phase = 1
	await _step()
	assert(game.resident_washing.routine.owner.is_empty() and game.resident_washing.pose.actor.is_empty() and _stock() == 6)
	assert(game.traveler_body.get_node("ArmLeft").visible and game.traveler_body.get_node_or_null("TemporaryWashLimbPose") == null)
	game.weather_phase = 2
	await _until_washing("tidekeeper")
	for index in 12: await _step()
	assert(game.resident_washing.routine.elapsed_us < 2000000 and _stock() == 6)
	assert(game._save_progress())
	game._load_progress()
	assert(not game.get_meta("save_load_blocked",false) and game.modern_utilities.washes.is_empty() and _stock() == 6)
	assert(game.resident_washing.routine.phase == "idle" and game.resident_washing.pose.actor.is_empty(),"unfinished two-second action reloads unpaid, never silently completed")
	# Real movement remains the only way back to the station after load.
	await _finish_day(1)
	assert(_stock() == 4 and game.modern_utilities.power.charge == initial_charge-1000)
	assert(game.modern_utilities.washes.tidekeeper.count == 1 and game.modern_utilities.washes.sailmaker.count == 1)
	assert(game.resident_washing.reflection(game,"tidekeeper").contains("今天"))
	assert(game.resident_washing.reflection(game,"sailmaker").contains("今天"))
	for index in 100: await _step()
	assert(_stock() == 4 and game.economy.audit().ok)
	# Calendar fixtures test daily reuse without pretending T/offline catch-up
	# performed a physical action. Day-two awning work must finish first.
	for day in [2,3]:
		game.day_count = day
		assert(game.resident_washing.reflection(game,"tidekeeper").contains("上回") and not game.resident_washing.reflection(game,"tidekeeper").contains("今天"))
		if day == 2: assert(not game.resident_washing.eligible(game,"sailmaker"),"personal awning work wins before daily washing")
		await _finish_day(day)
		assert(_stock() == 6-day*2 and game.modern_utilities.power.charge == initial_charge-day*1000)
	assert(game.sailmaker_awning_raised and game.modern_utilities.washes.sailmaker.count == 3)
	assert(game.economy.snapshot().streams.size() == 3,"producer + two resident streams stay bounded across days")
	game.day_count = 4
	assert(not game.resident_washing.eligible(game,"tidekeeper") and not game.resident_washing.eligible(game,"sailmaker"),"empty tank prevents any phantom daily action")
	for index in 20: await _step()
	assert(game.modern_utilities.washes.tidekeeper.count == 3 and _stock() == 0)
	assert(game._save_progress())
	var saved_power: Dictionary = game.modern_utilities.power.snapshot()
	game.free()
	await process_frame
	await _spawn()
	assert(not game.get_meta("save_load_blocked",false) and game.modern_utilities.washes.tidekeeper.count == 3 and _stock() == 0)
	assert(game.MemoryScript.facts_equal(saved_power,game.modern_utilities.power.snapshot()))
	assert(game.ark_root.find_children("ModernWaterCorner","",true,false).size() == 1 and game.find_children("TemporaryWashLimbPose","",true,false).is_empty())
	var recorded := 0
	for event in game.world_events:
		if event.id == "resident_washed" and event.facts.resident_id in ["tidekeeper","sailmaker"]:
			recorded += 1
			var at: Dictionary = event.facts.actual_position
			assert(Vector3(at.x,at.y,at.z).distance_to(game.ModernUtilityProps.APPROACH) <= .12)
	assert(recorded == 6 and pose_checks > 20 and movement_checks > 100)
	game.free()
	saver.clear_for_test()
	print("ARK_RESIDENT_WASHING_TEST_OK: real walk/arrival/two-second action, one station, interruption/unpaid reload, true water/power/history, daily bounded streams, work priority and restored original props/arms; calendar/travel/stock fixtures declared; pose_checks=",pose_checks," movement_checks=",movement_checks)
	quit()

func _capture(actor: String) -> void:
	var output := OS.get_environment("ARK_RESIDENT_WASH_CAPTURE_ROOT")
	if DisplayServer.get_name() == "headless" or output.is_empty(): return
	assert(output.to_lower().begins_with("d:/"))
	DirAccess.make_dir_recursive_absolute(output)
	game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game.camera.size = 4.6
	var target: Vector3 = game.ark_root.to_global(game.ModernUtilityProps.AT+Vector3(-.2,.9,.25))
	game.camera.global_position = target+Vector3(4,3,3)
	game.camera.look_at(target)
	for layer in game.find_children("*","CanvasLayer",true,false): layer.visible = false
	for index in 4:
		RenderingServer.force_draw(false)
		await process_frame
	root.get_texture().get_image().save_png(output.path_join(actor+"_washing.png"))
