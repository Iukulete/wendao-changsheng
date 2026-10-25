extends SceneTree
## Real supported movement/transactions in declared mooring + household fixtures.
## Not a claim of sailing the whole journey or physically walking emergency recall.
const Scene = preload("res://scenes/ark_greybox.tscn")
const Save = preload("res://scripts/ark_greybox_save.gd")
const Route = preload("res://scripts/adapters/ark_regional_walk_route.gd")
var game: Node3D
var failures := 0
var save_root: String
var costs: Array[int] = []
var keys := {}
class ContractProbe:
	extends RefCounted
	var rejected := false
	func _check(ok: bool,_message: String) -> void:
		if not ok: rejected = true

func _initialize() -> void: _run.call_deferred()
func _check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error("MOONBACK_LANDING: "+message)
func _spawn() -> void:
	game = Scene.instantiate()
	game.save_root_override = save_root
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await physics_frame
func _fixture() -> void:
	game.wood = 3 # Declared material fixture, not a free gameplay reward.
	_check(game._try_place_shelter(Vector3.ZERO),"fixture builds actual shelter")
	game.resident_met = true
	game.traveler_boarded = true
	game._set_traveler_boarded()
	game.ark_root.global_position = Vector3(-17,0,9.65)
	game.traveler_marker.position = game.RESIDENT_DECK_POSITION
	game.weather_phase = 2
	game.day_period = 0
	game.day_count = 2
	game._set_weather_visuals()
func _begin() -> bool:
	for frame in 2200:
		var clock := Time.get_ticks_usec()
		game._process(0.0) # Real automatic morning retry, not a manual dispatch loop.
		var started: bool = game.resident_gather_pending
		costs.append(Time.get_ticks_usec()-clock)
		if started: return true
		await physics_frame
	return false
func _tick() -> void:
	var before: Vector3 = game.traveler_marker.global_position
	var clock := Time.get_ticks_usec()
	game._process_resident_gathering(.1)
	costs.append(Time.get_ticks_usec()-clock)
	var after: Vector3 = game.traveler_marker.global_position
	_check(before.distance_to(after) <= .1801,"all task motion respects real 1.8m/s speed budget")
	if game.resident_gather_pending:
		var planner := Route.new()
		planner.configure(game)
		var h: Variant = planner.support(after)
		_check(h != null and absf(after.y-(float(h)+.12)) < .17,"actual resident has installed dry physical support")
	await physics_frame
func _key(code: Key,pressed: bool) -> void:
	if keys.get(code,false) == pressed: return
	keys[code] = pressed
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func _release() -> void:
	for code in [KEY_A,KEY_D,KEY_W,KEY_S]: _key(code,false)
func _walk(target: Vector3) -> bool:
	for frame in 1200:
		var p: Vector3 = game.player.global_position
		var delta := Vector2(target.x-p.x,target.z-p.z)
		if delta.length() < .14:
			_release()
			return true
		_key(KEY_A,delta.x < -.06)
		_key(KEY_D,delta.x > .06)
		_key(KEY_W,delta.y < -.06)
		_key(KEY_S,delta.y > .06)
		await physics_frame
	_release()
	print("LANDING_WALK_STALL target=",target," actual=",game.player.global_position," floor=",game.player.is_on_floor())
	return false
func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/moonback_landing_test_%d" % OS.get_process_id())
	var service := Save.new(save_root)
	service.clear_for_test()
	await _spawn()
	var contract := preload("res://tests/support/moonback_landing_contract.gd").new()
	contract.validate(game,self)
	# Actual mutations, not just positive same-object comparisons.
	var shape: BoxShape3D = game.get_node("MoonbackOldLanding/PierDeck/CollisionShape3D").shape
	var size := shape.size
	shape.size.x += .02
	var negative := ContractProbe.new()
	contract.validate(game,negative)
	_check(negative.rejected,"addition contract rejects an actual pier collider edit")
	shape.size = size
	var batch: MultiMeshInstance3D = game.get_node("MoonbackNature/Pine_1")
	var transforms: Array = batch.get_meta("coast_instances").duplicate()
	var altered: Transform3D = transforms[0]
	altered.origin.x += .02
	var changed: Array = transforms.duplicate()
	changed[0] = altered
	batch.set_meta("coast_instances",changed)
	negative = ContractProbe.new()
	contract.validate(game,negative)
	_check(negative.rejected,"addition contract rejects an actual nature placement edit")
	batch.set_meta("coast_instances",transforms)
	contract.validate(game,self)
	_fixture()
	await physics_frame
	_check(game._is_ark_position_navigable(game.ark_root.global_position),"actual mooring clears shore and new pier")
	# Bad mooring may not walk through open sea or spend today's shift.
	game.ark_root.position.x = -22
	game.resident_gather_policy = "shellfish_first"
	for i in 200:
		game._begin_resident_daily_gather()
		await physics_frame
	_check(not game.resident_gather_pending and game.resident_gather_last_day == 0 and game.economy.snapshot().reservations.is_empty(),"disconnected boat cannot reserve or remotely harvest regional supplies")
	game.ark_root.position.x = -17
	game.resident_regional_route_jobs.clear()
	# Actual player's capsule crosses the real deck seam, without jump/teleport.
	game.player.global_position = game.ark_root.to_global(Vector3(0,.15,1.2))
	game.player.velocity = Vector3.ZERO
	game.set_physics_process(true)
	for i in 20: await physics_frame
	for p in [Vector3(-17,0,14),Vector3(-17,0,17.8),Vector3(-19.4,0,17.8),Vector3(-20,0,18)]:
		_check(await _walk(p),"real no-jump landing "+str(p))
	_check(game.player.is_on_floor() and not game.is_swimming,"player arrives dry on the coast")
	for p in [Vector3(-19.4,0,17.8),Vector3(-17,0,17.8),Vector3(-17,0,14),game.ark_root.to_global(Vector3(0,0,1.2))]:
		_check(await _walk(p),"real no-jump return "+str(p))
	game.set_physics_process(false)
	# Normal worker trip: no inventory change until the actual return is complete.
	_check(await _begin(),"reachable morning source starts after budgeted preflight")
	_check(game.resident_gather_target_id == "MoonbackTidalShells","shell policy uses the low coast, not the former highland coordinate")
	var stock: int = game.raw_shellfish
	for i in 2400:
		await _tick()
		if game.resident_gather_phase == "returning": break
	_check(game.resident_gather_phase == "returning" and game.raw_shellfish == stock and game.resident_gather_payload == 2,"finite harvest becomes carried cargo, not remote food credit")
	var task: String = game.resident_task_id
	# Persist real in-flight cargo, then block the pier. Replanning may wait but
	# cannot use the legacy abort path to immediately deposit carried resources.
	_check(game._save_progress(),"actual in-flight regional task saves")
	game._load_progress()
	_check(game.resident_task_id == task and game.resident_gather_payload == 2,"exact carried task restores")
	game._add_box("LandingTestBlock",Vector3(-17,1.1,15.5),Vector3(2.4,2.2,.65),Color.GRAY,true)
	await physics_frame
	for i in 800: await _tick()
	_check(game.resident_gather_pending and game.raw_shellfish == stock and game.resident_gather_payload == 2,"blocked return keeps cargo with the waiting resident")
	game.get_node("LandingTestBlock").free()
	game.resident_regional_route_jobs.clear()
	game.resident_regional_route_retry_at = 0
	await physics_frame
	for i in 2400:
		await _tick()
		if not game.resident_gather_pending: break
	_check(not game.resident_gather_pending and game.raw_shellfish == stock+2,"unblocked worker actually returns before finite food is credited")
	_check(game.traveler_marker.get_parent() == game.ark_root and game.economy.audit().ok,"returned worker and economic conservation")
	_check(not game._begin_resident_daily_gather(),"one completed shift cannot repeat that morning")
	_check(game._save_progress(),"completed regional shift saves")
	game._load_progress()
	_check(game.raw_shellfish == stock+2 and not game.resident_gather_pending,"reloading completed trip adds no duplicate resources")
	# Same stable source and bounded dawn renewal, not a newly invented stock pool.
	game.day_count += 1
	_check(game._replenish_shore_supplies() == 1,"next dawn renews only the actually depleted original source")
	await physics_frame
	var shell: Node3D = game.get_node("MoonbackTidalShells")
	_check(Vector2(shell.position.x,shell.position.z) == Vector2(-23,14) and absf(shell.position.y-(float(game._ground_height_at(shell.position))-.0372)) < .0001,"renewed source stays on its supported low-coast position")
	_check(game.economy.source("MoonbackTidalShells").remaining == 2,"renewal preserves the original finite two-shell stock")
	# A real schema41 file with an old collecting location: no XZ teleport, no
	# resource grant, upward support repair only, then approach the relocated source.
	var dispatched: Dictionary = game.gathering.dispatch("tidekeeper","MoonbackTidalShells","player")
	_check(dispatched.ok and game.gathering.mark_collecting(dispatched.task_id),"legacy task fixture reserves the actual renewed source")
	game.resident_task_id = dispatched.task_id
	game.resident_gather_pending = true
	game.resident_gather_phase = "collecting"
	game.resident_gather_target_id = "MoonbackTidalShells"
	game.resident_gather_resource = "shellfish"
	game.resident_gather_target_position = Vector3(-31,.12,27)
	game.resident_gather_pickup_remaining = .65
	game.resident_gather_payload = 0
	game.traveler_marker.reparent(game,true)
	game.traveler_marker.global_position = Vector3(-31,.12,27)
	_check(game._save_progress(),"legacy regional collecting fixture writes through actual save service")
	var old_collecting_state: Dictionary = service.load_state().state.duplicate(true)
	old_collecting_state.schema_version = 41
	old_collecting_state.erase("kitchen")
	_check(service.save_state(old_collecting_state).ok,"collecting migration uses a real pre-kitchen schema-41 file")
	game._load_progress()
	_check(game.resident_gather_phase == "outbound" and game.gathering.task(game.resident_task_id).phase == "outbound","old remote collecting pose must approach again")
	_check(Vector2(game.traveler_marker.global_position.x,game.traveler_marker.global_position.z) == Vector2(-31,27) and game.traveler_marker.global_position.y > 2.9,"old buried worker is only raised to support, never teleported across the island")
	_check(game.resident_gather_target_position.is_equal_approx(game.get_node("MoonbackTidalShells").global_position) and game.raw_shellfish == stock+2 and game.resident_gather_payload == 0 and game.economy.source("MoonbackTidalShells").remaining == 2,"restored source position is factual without early harvest or duplicate stock")
	_check(game._save_progress(),"migrated in-flight approach remains strictly saveable")
	costs.sort()
	print("MOONBACK_ROUTE_CPU usec p50=",costs[costs.size()/2]," p95=",costs[int(costs.size()*.95)]," max=",costs[-1]," samples=",costs.size()," headless controller calls; not frame/GPU/FPS")
	game.save_service = null
	game.free()
	service.clear_for_test()
	if failures == 0: print("ARK_MOONBACK_LANDING_TEST_OK:")
	quit(1 if failures else 0)
