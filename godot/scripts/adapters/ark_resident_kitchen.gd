extends RefCounted
## Scene adapter: proves the physical station/route, schedules an existing
## resident, and presents work. Pure Kitchen owns progress; Economy owns food.
const Roles = preload("res://scripts/modules/rooms/ark_room_roles.gd")
const Pose = preload("res://scripts/presentation/ark_resident_cook_pose.gd")
const Food = preload("res://scripts/modules/rooms/ark_food_storage.gd")
const Tote = preload("res://scripts/presentation/ark_food_tote.gd")
var pose = Pose.new()
var tote = Tote.new()
var route_retry := 0.0
var cached := {}

func clear() -> void:
	pose.clear()
	tote.clear()
	route_retry = 0.0
	cached.clear()

func station(game: Node3D) -> Dictionary:
	var shelter := game._ark_node("BuiltShelter") as Node3D
	var pot := game._ark_node("BuiltShelter/PressureGalley" if game.pressure_galley_built else "BuiltShelter/HearthPot") as Node3D
	if not is_instance_valid(shelter) or not is_instance_valid(pot) or shelter.is_queued_for_deletion() or pot.is_queued_for_deletion(): return {}
	for node in [shelter,pot]:
		if not node.is_inside_tree() or not node.is_visible_in_tree() or node.process_mode == Node.PROCESS_MODE_DISABLED: return {}
	var signature := [Engine.get_physics_frames(),shelter.get_instance_id(),shelter.global_transform,pot.get_instance_id(),pot.global_transform]
	if cached.get("signature") == signature: return cached.result
	var result := {}
	# Station-relative use faces, not a hardcoded world point. The actual pot and
	# every furniture footprint remain obstacles; never stand inside the fire.
	for offset in [Vector3(.62,-.41,.10),Vector3(.58,-.41,.34),Vector3(.08,-.41,.60)]:
		var target: Vector3 = game.ark_root.to_local(pot.to_global(offset))
		if game.resident_washing.walk_step_clear(game,target,target):
			result = {"node":pot,"target":target,"room":"starter.galley","pressure":game.pressure_galley_built}
			break
	cached = {"signature":signature,"result":result}
	return result

func environment_ready(game: Node3D) -> bool:
	if game.kitchen.returning() or game.kitchen.delivering():
		return not game._life_clock_paused() and not game.sailing_mode and game.weather_phase!=game.WeatherPhase.STORM and game.traveler_boarded and is_instance_valid(game.traveler_marker) and game.traveler_marker.get_parent()==game.ark_root and not game.resident_gather_pending and not game.resident_repair_pending and not (game.shared_meal_gathering_pending and not game.shared_meal_paused) and not game.food_storage.station(game).is_empty()
	if not game.kitchen.enabled or game._life_clock_paused() or game.sailing_mode or game.weather_phase == game.WeatherPhase.STORM or game.day_period != game.DayPeriod.EVENING: return false
	if not game.traveler_boarded or game.resident_gather_pending or game.resident_repair_pending or game.raft_edge_damaged or game.shelter_roof_damaged: return false
	if game.shared_meal_day == game.day_count or (game.shared_meal_gathering_pending and not game.shared_meal_paused): return false
	if not Roles.available("galley",game._room_role_facts()): return false
	var marker: Variant = game.traveler_marker
	if not is_instance_valid(marker) or marker.get_parent() != game.ark_root: return false
	if game.stew_servings+game.economy.inventory(Food.OWNER,"stew_servings")>=2 or station(game).is_empty(): return false
	if game.kitchen.active():
		if game.kitchen.order.supply=="player": return game.raw_shellfish>0
		if game.kitchen.order.phase=="fetch": return game.economy.inventory(Food.OWNER,"shellfish")>0 and not game.food_storage.station(game).is_empty()
		return game.kitchen.carrying() and game.economy.inventory(Food.CARRY,"shellfish")==1
	return game.raw_shellfish>0 or (game.economy.inventory(Food.OWNER,"shellfish")>0 and not game.food_storage.station(game).is_empty())

func destination(game: Node3D) -> Dictionary:
	if game.kitchen.active() and game.kitchen.order.phase in ["fetch","return","deliver"]: return game.food_storage.station(game)
	return station(game)

func action(game: Node3D) -> String:
	if game.kitchen.returning(): return "把未加工鲜贝送回储箱"
	if game.kitchen.delivering(): return "把刚盛好的热汤送回储粮格"
	if game.kitchen.active() and game.kitchen.order.phase=="fetch": return "到储粮格取晚饭食材"
	return "照看鲜贝汤" if game.kitchen.active() and int(game.kitchen.order.elapsed_usec)>0 else "准备潮滩晚饭"

func selected(game: Node3D) -> bool:
	return game.kitchen.active() and environment_ready(game)

func check_dependencies(game: Node3D) -> bool:
	var changed := false
	if game.kitchen.active() and not game.kitchen.returning() and not game.kitchen.delivering() and (not game.traveler_boarded or not Roles.available("galley",game._room_role_facts())):
		var attempt: int = game.kitchen.order.attempt
		game.kitchen.cancel()
		clear()
		changed = true
		game._record_world_event("resident_kitchen_order_cancelled",{"resident_id":"tidekeeper","attempt":attempt,"ingredients_spent":0,"return_pending":game.kitchen.carrying(),"reason":"station_or_resident_removed"})
	if game.kitchen.carrying() and (not game.traveler_boarded or not is_instance_valid(game.traveler_marker) or not game.storage_built):
		# Explicit emergency ownership recovery, not a claimed physical walk.
		var cooked: bool = game.kitchen.delivering()
		var result: Dictionary = game.kitchen.deliver_food(game.economy,"player") if cooked else game.kitchen.return_food(game.economy,"player")
		if result.ok:
			changed = true
			tote.clear()
			game._record_world_event("resident_kitchen_food_recovered" if cooked else "resident_kitchen_ingredient_returned",{"resident_id":"tidekeeper","attempt":result.attempt,"destination":"player","resource":"stew_servings" if cooked else "shellfish","amount":1,"physical_walk":false,"reason":"carrier_or_storage_removed"})
	return changed

func reconcile(game: Node3D) -> void:
	if check_dependencies(game): game._save_progress()
	if not game.kitchen.active() and game.kitchen.can_begin(game.day_count) and environment_ready(game):
		var supply := "storage" if game.economy.inventory(Food.OWNER,"shellfish")>0 and not game.food_storage.station(game).is_empty() else "player"
		if game.kitchen.begin(game.day_count,supply):
			route_retry = 0.0
			game.traveler_routine_route_target_set = false
			game._record_world_event("resident_kitchen_order_started",{"resident_id":"tidekeeper","room_id":"starter.galley","recipe_id":"tidal_shellfish_stew","attempt":game.kitchen.order.attempt,"supply":supply,"ingredients_spent":0,"day":game.day_count})
			game._save_progress()
	if not selected(game): pose.clear()
	if game.kitchen.active(): game._update_traveler_schedule()

func arrived(game: Node3D) -> bool:
	var current := station(game)
	return _at(game,current)

func _at(game: Node3D,current: Dictionary) -> bool:
	if current.is_empty(): return false
	var marker: Node3D = game.traveler_marker
	return is_instance_valid(marker) and marker.get_parent() == game.ark_root and marker.position.distance_to(current.target) <= .06 and game.resident_washing.walk_step_clear(game,marker.position,marker.position)

func step(game: Node3D,delta: float) -> bool:
	if not selected(game) or not is_finite(delta) or delta <= 0: return false
	var duration := minf(delta,.1)
	var current := destination(game)
	if current.is_empty(): return false
	if not _at(game,current):
		pose.clear()
		route_retry = maxf(0,route_retry-duration)
		if game.traveler_routine_route.is_empty() and game.traveler_routine_route_target_set:
			if route_retry > 0: return false
			game.traveler_routine_route_target_set = false
		var moving: bool = game._move_ark_resident_toward(game.traveler_marker,current.target,duration,.72,"tidekeeper")
		if game.traveler_routine_route.is_empty(): route_retry = .5
		return moving
	if game.kitchen.order.phase=="fetch":
		var result: Dictionary = game.kitchen.fetch(game.economy)
		if result.ok:
			game._record_world_event("resident_kitchen_ingredient_taken",{"resident_id":"tidekeeper","attempt":result.attempt,"from":Food.OWNER,"to":Food.CARRY,"resource":"shellfish","amount":1,"actual_position":game._position_facts(game.traveler_marker.position)})
			game.traveler_routine_route_target_set = false
			game._save_progress()
			game._update_hud()
		return false
	if game.kitchen.returning():
		var result: Dictionary = game.kitchen.return_food(game.economy)
		if result.ok:
			game._record_world_event("resident_kitchen_ingredient_returned",{"resident_id":"tidekeeper","attempt":result.attempt,"destination":Food.OWNER,"amount":1,"physical_walk":true,"actual_position":game._position_facts(game.traveler_marker.position)})
			tote.clear()
			game._save_progress()
			game._update_hud()
		return false
	if game.kitchen.delivering():
		var result: Dictionary = game.kitchen.deliver_food(game.economy)
		if result.ok:
			tote.clear()
			game._record_world_event("resident_meal_prepared",{"resident_id":"tidekeeper","meal_id":result.recipe,"room_id":result.room,"attempt":result.attempt,"day":game.day_count,"supply":"storage","destination":Food.OWNER,"servings_added":1,"physical_walk":true,"worker_position":game._position_facts(game.traveler_marker.position)})
			game.message = "守潮人把一份热汤送回储粮格：‘回来就有吃的。’靠近储箱按 G 可取用，再带到桌边一起喝。"
			game._update_traveler_schedule()
			game._save_progress()
			game._update_hud()
		return false
	game.kitchen.advance(int(round(duration*1000000.0)),true,current.pressure)
	if game.kitchen.ready(): complete(game)
	return false

func complete(game: Node3D) -> bool:
	if not selected(game) or not arrived(game) or not game.kitchen.ready(): return false
	var position: Vector3 = game.traveler_marker.position
	var result: Dictionary = game.kitchen.complete(game.day_count,game.economy)
	if not result.ok: return false
	pose.clear()
	game._record_world_event("resident_meal_cooked" if result.delivery_pending else "resident_meal_prepared",{"resident_id":"tidekeeper","meal_id":result.recipe,"room_id":result.room,"attempt":result.attempt,"day":game.day_count,"supply":result.supply,"destination":result.destination,"raw_shellfish_spent":1,"servings_added":1,"tool_id":"pressure_galley" if game.pressure_galley_built else "hearth_pot","work_completed":true,"effective_work_usec":4000000,"worker_position":[position.x,position.y,position.z]})
	if result.delivery_pending:
		game.traveler_routine_route_target_set = false
		game.message = "汤已盛好，守潮人提着食篮往储箱走；送到以后，家里才有可取用的晚饭。"
	else:
		tote.clear()
		game.message = "锅边传来一声轻响，守潮人把鲜贝汤盛好：‘留了一碗，回来趁热喝。’"
	game._update_traveler_schedule()
	game._save_progress()
	game._update_hud()
	return true

func present(game: Node3D) -> void:
	tote.present(game)
	if selected(game) and not game.kitchen.returning() and game.kitchen.order.phase=="cook" and arrived(game) and int(game.kitchen.order.elapsed_usec) > 0:
		pose.apply(game,station(game),int(game.kitchen.order.elapsed_usec))
	else: pose.clear()

func status(game: Node3D) -> String:
	if game.kitchen.returning(): return "未加工鲜贝仍在随身食材篮，等待走回储箱归还"
	if game.kitchen.delivering(): return "已做好 1 份热汤，正在送回储粮格（满箱时保留在食篮）"
	if not game.kitchen.enabled: return "已暂停自动备餐（保留进度）"
	if game.kitchen.active():
		if game.kitchen.order.phase=="fetch": return "去家庭储粮格取 1 份鲜贝（尚未扣料）"
		return "锅边备餐 %d%%" % (int(game.kitchen.order.elapsed_usec)*100/4000000) if selected(game) and arrived(game) else "等待到锅边或恢复工作条件"
	if game.kitchen.last_completed_day == game.day_count: return "今日已备好一锅，等人回来"
	if game.stew_servings >= 2: return "已有两份热汤，不继续囤做"
	return "傍晚自动备一锅，完工才用 1 鲜贝"
