extends RefCounted
## Projects actual owners/facilities into pure demand; schedules only the existing
## finite gather command. Regional preflight keeps its original per-frame budget.
const Rules = preload("res://scripts/modules/residents/ark_home_demand.gd")
var review_remaining := 1.0

func fixture_ready(game: Node3D,path: String) -> bool:
	var node := game._ark_node(path) as Node3D
	return is_instance_valid(node) and not node.is_queued_for_deletion() and node.is_inside_tree() and node.is_visible_in_tree() and node.process_mode!=Node.PROCESS_MODE_DISABLED

func review(game: Node3D) -> Dictionary:
	var storage: bool = game.storage_built and game.food_storage.fixture(game)!=null
	var modern: bool = game.modern_utilities.salvaged and not game.modern_utilities.installed and game._has_blueprint(game.ModernUtilitiesScript.BLUEPRINT) and game.economy.inventory("player","utility_core")>0 and game.raft_extension_built and fixture_ready(game,"BuiltRaftExtension")
	return Rules.plan({"storage_built":game.storage_built,"storage_ready":storage,"workbench_built":game.workbench_built,"modern_ready":modern,"wood_available":game.wood+(game.stored_wood if storage else 0),"stored_wood":game.stored_wood if storage else 0,"food_available":game.raw_shellfish+game.stew_servings+(game.FoodStorageRules.stock(game.economy) if storage else 0),"damage_count":int(game.raft_edge_damaged)+int(game.shelter_roof_damaged)})

func step(game: Node3D,delta: float) -> void:
	if not is_finite(delta) or delta<0: return
	var regional: bool = game.RegionalRouteScript.handles(game.ark_root.global_position)
	# Regional route preflight is bounded work, not simulated elapsed time. Keep
	# its established zero-delta query path without advancing local dispatch.
	if delta==0 and not regional: return
	review_remaining = maxf(0,review_remaining-minf(delta,.1))
	if not regional and (review_remaining>0 or not game.storage_built): return
	review_remaining = 1.0
	if game._life_clock_paused() or game.shared_meal_gathering_pending or game.resident_washing.selected(game,"tidekeeper"): return
	game._begin_resident_daily_gather()

func summary(game: Node3D) -> String:
	var current := review(game)
	if not current.ok: return "家中缺口暂不可用，未派工。"
	var title: String = Rules.TITLES[current.reason]
	if game.resident_gather_policy!="balanced" and current.damage_count==0 and not current.blocked: title = "按你指定的采集偏好安排"
	return "%s；口粮 %d/%d 份，可施工木料 %d/%d，修缮缺储木 %d。只算已到手的本家物资；在途货物和其他仙舟不算。" % [title,current.food_available,current.food_target,current.wood_available,current.wood_target,current.repair_need]
