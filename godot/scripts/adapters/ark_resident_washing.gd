extends RefCounted
## Scene coordinator only. Policy owns transient station use; Utilities owns
## daily completed facts/power; Economy owns water; Memory records actual success.
const Routine = preload("res://scripts/modules/residents/ark_wash_routine.gd")
const Pose = preload("res://scripts/presentation/ark_resident_wash_pose.gd")
var routine = Routine.new()
var pose = Pose.new()
var route_retry := 0.0
var escape_legs: Dictionary = {}
var safe_targets: Dictionary = {}

func clear() -> void:
	pose.clear()
	routine.cancel()
	route_retry = 0.0
	escape_legs.clear()
	safe_targets.clear()

func marker(game: Node3D, actor: String) -> Variant:
	return game.traveler_marker if actor == "tidekeeper" else game.sailmaker_marker if actor == "sailmaker" else null

func eligible(game: Node3D, actor: String) -> bool:
	if not game.modern_utilities.installed or actor not in Routine.ACTORS: return false
	if game._life_clock_paused() or game.sailing_mode or game.weather_phase == game.WeatherPhase.STORM or game.day_period not in [game.DayPeriod.MORNING,game.DayPeriod.DAY]: return false
	if not game.raft_extension_built or game.raft_edge_damaged or game.shelter_roof_damaged: return false
	if game.shared_meal_gathering_pending and not game.shared_meal_paused: return false
	var station: Node = game._ark_node(game.ModernUtilityProps.ROOT)
	var deck: Node = game._ark_node("BuiltRaftExtension")
	if not is_instance_valid(station) or not is_instance_valid(deck) or station.is_queued_for_deletion() or deck.is_queued_for_deletion(): return false
	var actor_marker: Variant = marker(game,actor)
	if not is_instance_valid(actor_marker) or actor_marker.is_queued_for_deletion() or actor_marker.get_parent() != game.ark_root: return false
	if actor == "tidekeeper":
		if not game.traveler_boarded or game.resident_gather_pending or game.resident_repair_pending or game.kitchen.carrying(): return false
	else:
		if not game.sailmaker_boarded or game.household_work.active() or game._household_work_can_run() or game._sailmaker_awning_work_can_run(): return false
	return game.modern_utilities.wash_error(actor,game.day_count,game.economy).is_empty()

func eligible_actors(game: Node3D) -> Array:
	var actors: Array = []
	for actor in Routine.ACTORS:
		if eligible(game,actor): actors.append(actor)
	return actors

func selected(game: Node3D, actor: String) -> bool:
	return routine.owner == actor and eligible(game,actor)

func arrived(game: Node3D, actor: String) -> bool:
	var actor_marker: Variant = marker(game,actor)
	return is_instance_valid(actor_marker) and actor_marker.get_parent() == game.ark_root and actor_marker.position.distance_to(game.ModernUtilityProps.APPROACH) <= .12 and walk_step_clear(game,actor_marker.position,actor_marker.position)

func walk_step_clear(game: Node3D, from: Vector3, to: Vector3) -> bool:
	if not from.is_finite() or not to.is_finite(): return false
	var excluded: Array[RID] = []
	var obstacles: Array[Rect2] = game._home_routine_furniture_obstacles()
	for index in range(1,maxi(1,ceili(from.distance_to(to)/.04))+1):
		var point := from.lerp(to,float(index)/maxi(1,ceili(from.distance_to(to)/.04)))
		if game._ark_local_walk_cell_blocked(Vector2(point.x,point.z),excluded,.25) or game._shared_meal_route_point_blocked(Vector2(point.x,point.z),obstacles): return false
	return true

func prepare_route(game: Node3D, actor: String, route: PackedVector3Array) -> void:
	escape_legs.erase(actor)
	# Old boarding/saved positions can overlap a wall's capsule margin. Only a
	# short first planned leg ending in clear space may walk out of that margin.
	# This is movement-budgeted, not a snap, and ends permanently once clear.
	if route.size() <= 1:
		return
	var escape_limit := .5
	# The full-size cot's nearest grid-aligned exit can be 0.9 m away. Extend
	# only a visual-furniture overlap; a physical wall keeps its old 0.5 m cap.
	# The route planner has already sampled this first leg against real solids.
	var excluded: Array[RID] = []
	if not game._ark_local_walk_cell_blocked(Vector2(route[0].x,route[0].z),excluded,.25):
		escape_limit = 1.0
	if route[0].distance_to(route[1]) <= escape_limit and not walk_step_clear(game,route[0],route[0]) and walk_step_clear(game,route[1],route[1]):
		escape_legs[actor] = route[1]

func route_step_clear(game: Node3D, actor: String, from: Vector3, to: Vector3, route_index: int, destination: Vector3 = Vector3.INF) -> bool:
	if walk_step_clear(game,from,to):
		escape_legs.erase(actor)
		return true
	if route_index != 1 or not escape_legs.has(actor): return false
	var end: Vector3 = escape_legs[actor]
	if to.distance_to(end) >= from.distance_to(end): return false
	return game._sailmaker_awning_walk_step_clear(from,to,destination if destination.is_finite() else game.ModernUtilityProps.APPROACH,true)

func safe_idle_target(game: Node3D, target: Vector3) -> Vector3:
	if not game.modern_utilities.commissioned(): return target
	if safe_targets.has(target) and walk_step_clear(game,safe_targets[target],safe_targets[target]): return safe_targets[target]
	if walk_step_clear(game,target,target): return target
	var best := Vector3.INF
	for x in range(-4,5):
		for z in range(-4,5):
			var candidate := target+Vector3(x*.25,0,z*.25)
			if candidate.distance_squared_to(target) >= best.distance_squared_to(target) or not walk_step_clear(game,candidate,candidate): continue
			best = candidate
	if best.is_finite():
		if safe_targets.size() >= 16: safe_targets.clear()
		safe_targets[target] = best
		return best
	return target

func _schedules(game: Node3D) -> void:
	game._update_traveler_schedule()
	game._update_sailmaker_schedule()

func reconcile(game: Node3D) -> void:
	var selection: Dictionary = routine.reconcile(eligible_actors(game))
	if selection.changed: route_retry = 0.0
	if selection.changed or routine.phase != "washing" or not arrived(game,routine.owner): pose.clear()
	if selection.changed or not routine.owner.is_empty(): _schedules(game)

func step(game: Node3D, delta: float) -> void:
	if not is_finite(delta) or delta < 0: return
	route_retry = maxf(0,route_retry-minf(delta,.25))
	var before: Dictionary = routine.view()
	var result: Dictionary = routine.advance(int(round(minf(delta,.25)*1000000)),eligible_actors(game),arrived(game,routine.owner))
	if not result.ok: return
	if not routine.owner.is_empty() and routine.phase == "walking" and not arrived(game,routine.owner) and route_retry <= 0:
		var route: PackedVector3Array = game.traveler_routine_route if routine.owner == "tidekeeper" else game.sailmaker_routine_route
		if route.is_empty():
			if routine.owner == "tidekeeper": game.traveler_routine_route_target_set = false
			else: game.sailmaker_routine_route_target_set = false
			route_retry = .5
	if result.settle:
		var actor: String = result.owner
		var payment: Dictionary = game.modern_utilities.wash(actor,game.day_count,game.economy) if selected(game,actor) and arrived(game,actor) else {"ok":false}
		var acknowledged: Dictionary = routine.acknowledge(actor,payment.ok)
		assert(acknowledged.ok)
		pose.clear()
		if payment.ok:
			game._record_world_event("resident_washed",{"resident_id":actor,"day":game.day_count,"wash_count":payment.count,"fresh_water_spent":1,"charge_spent":500,"facility_id":"solar_water_corner","actual_position":game._position_exact(marker(game,actor).position),"completed_action_seconds":2})
			game._save_progress()
			game._update_hud()
	if before != routine.view(): _schedules(game)

func present(game: Node3D) -> void:
	if routine.phase == "washing" and selected(game,routine.owner) and arrived(game,routine.owner):
		pose.apply(game,routine.owner,routine.elapsed_us)
	else: pose.clear()

func using_station(game: Node3D) -> bool:
	return routine.phase == "washing" and selected(game,routine.owner) and arrived(game,routine.owner)

func status(game: Node3D) -> String:
	var names := {"player":"你","tidekeeper":"守潮人","sailmaker":"缝帆人"}
	var completed: Array[String] = []
	for actor in names:
		if game.modern_utilities.washes.get(actor,{}).get("day",0) == game.day_count: completed.append(names[actor])
	var line := "今日洗漱："+("、".join(completed) if not completed.is_empty() else "还没有人")
	if not routine.owner.is_empty() and eligible(game,routine.owner): line += "；"+names[routine.owner]+("正在净手" if using_station(game) else "走向水台")
	return line

func reflection(game: Node3D, actor: String) -> String:
	var record: Dictionary = game.modern_utilities.washes.get(actor,{})
	if record.is_empty(): return ""
	var when_ := "今天" if int(record.day) == game.day_count else "上回"
	if not game.modern_utilities.installed:
		if actor == "tidekeeper": return "守潮人说起%s的那次洗漱：‘温水把手上的盐洗掉，人也像跟着缓了口气。那样安稳的日子，我记得。’" % when_
		if actor == "sailmaker": return "缝帆人舒了舒手指，回想%s的洗漱：‘手洗干净的时候，连针线都好理一些。那点暖意，过了也留在心里。’" % when_
		return ""
	if actor == "tidekeeper": return "守潮人看了看水台：‘%s在这里净过手，手上的盐总算能用温水洗掉了。船上能安稳过这样的日子，出门也有个盼头。’" % when_
	if actor == "sailmaker": return "缝帆人把手指舒展开：‘%s在水台洗干净了手，再拿针线，连帆布都像好理一些。不是多金贵的东西，可有了就舍不得将就。’" % when_
	return ""
