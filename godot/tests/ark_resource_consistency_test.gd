extends SceneTree
const Save = preload("res://scripts/ark_greybox_save.gd")
const Economy = preload("res://scripts/modules/economy/ark_economy.gd")
const Gathering = preload("res://scripts/modules/residents/ark_gathering.gd")
const Construction = preload("res://scripts/modules/construction/ark_construction.gd")
const Memory = preload("res://scripts/modules/memory/ark_memory.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var economy := Economy.new()
	assert(economy.seed_inventory("player",{"wood":8}))
	assert(economy.seed_source("pile:one","wood",3))
	var tasks := Gathering.new()
	tasks.configure(economy)
	var dispatched: Dictionary = tasks.dispatch("resident:a","pile:one","player")
	assert(dispatched.ok)
	var id := str(dispatched.task_id)
	var layout_stale: Dictionary = tasks.token(id)
	tasks.invalidate_routes()
	assert(not tasks.accept_result(layout_stale))
	var stale: Dictionary = tasks.token(id)
	assert(not tasks.dispatch("resident:b","pile:one","player").ok)
	assert(tasks.mark_collecting(id))
	assert(absf(float(tasks.collection_tick(id,0.2).remaining) - 0.45) < 0.000001)
	var collecting := JSON.parse_string(JSON.stringify(tasks.snapshot())) as Dictionary
	assert(tasks.restore(collecting))
	assert(absf(float(tasks.collection_tick(id,0.0).remaining) - 0.45) < 0.000001)
	assert(tasks.collection_tick(id,0.45).complete)
	assert(tasks.harvest(id).ok and tasks.harvest(id).duplicate)
	assert(economy.inventory("player","wood") == 8 and economy.carried(id).amount == 3)
	var es: Dictionary = JSON.parse_string(JSON.stringify(economy.snapshot()))
	var ts: Dictionary = JSON.parse_string(JSON.stringify(tasks.snapshot()))
	var settled_corrupt := es.duplicate(true)
	settled_corrupt.receipts["deliver:" + id] = true
	assert(not economy.restore(settled_corrupt))
	assert(economy.carried(id).amount == 3)
	assert(economy.restore(es) and tasks.restore(ts))
	assert(not tasks.accept_result(stale))
	assert(tasks.deliver(id).ok and tasks.deliver(id).duplicate)
	assert(economy.inventory("player","wood") == 11 and economy.audit().ok)
	assert(economy.seed_source("pile:two","wood",2))
	var takeover: Dictionary = tasks.dispatch("resident:a","pile:two","player")
	var collected: Dictionary = economy.collect_direct("pile:two","player")
	assert(collected.ok and collected.displaced_task_id == takeover.task_id)
	assert(tasks.cancel(takeover.task_id).ok and economy.audit().ok)
	assert(not economy.collect_direct("pile:two","player").ok)
	assert(economy.seed_source("pile:three","wood",4,"region:test"))
	var blocked: Dictionary = tasks.dispatch("resident:a","pile:three","player","region:test")
	assert(tasks.harvest(blocked.task_id).ok)
	assert(economy.set_capacity("player",13))
	assert(not tasks.cancel(blocked.task_id).ok)
	assert(economy.carried(blocked.task_id).amount == 4 and economy.audit().ok)
	assert(economy.set_capacity("player",100))
	assert(tasks.cancel(blocked.task_id).ok and economy.inventory("player","wood") == 17)
	assert(economy.seed_source("pile:region","wood",2,"region:test"))
	var regional: Dictionary = tasks.dispatch("resident:a","pile:region","player","region:test")
	assert(regional.ok)
	tasks.unload_region("region:test")
	assert(not tasks.dispatch("resident:a","pile:region","player","region:test").ok)
	tasks.reload_region("region:test")
	assert(tasks.dispatch("resident:a","pile:region","player","region:test").ok)
	var before := economy.snapshot()
	var corrupt := before.duplicate(true)
	corrupt.sources["pile:one"] = "invalid"
	assert(not economy.restore(corrupt) and economy.snapshot() == before)
	var task_before := tasks.snapshot()
	var corrupt_tasks := task_before.duplicate(true)
	corrupt_tasks.active["ghost"] = id
	assert(not tasks.restore(corrupt_tasks) and tasks.snapshot() == task_before)
	var construction := Construction.new()
	construction.configure(economy)
	assert(construction.commit("build:one","player",{"wood":3},func():return true,{"type":"storage"}).ok)
	assert(construction.commit("build:one","player",{"wood":3},func():return false,{"type":"storage"}).duplicate)
	assert(not construction.commit("build:one","player",{"wood":4},func():return true,{"type":"storage"}).ok)
	assert(economy.set_capacity("player",14))
	assert(not construction.refund("remove:one","player",{"wood":3},func():return true).ok)
	assert(economy.set_capacity("player",17))
	assert(construction.refund("remove:one","player",{"wood":3},func():return true).ok)
	assert(construction.refund("remove:one","player",{"wood":3},func():return true).duplicate)
	assert(economy.input("player","wood",0,"zero").ok)
	assert(economy.input("player","wood",0,"zero").duplicate)
	assert(economy.audit().ok)
	var memory := Memory.new()
	assert(not memory.latest("unobserved").known)
	assert(not memory.record("meal",{"participant_ids":["player","tidekeeper"]},1,0).is_empty())
	assert(memory.restore(JSON.parse_string(JSON.stringify(memory.snapshot()))))
	assert(memory.latest("meal").known and not memory.latest("unobserved").known)
	var memory_before := memory.snapshot()
	assert(not memory.restore({"version":1,"sequence":0,"events":memory.events()}))
	assert(memory.snapshot() == memory_before)
	for index in range(300):
		assert(not memory.record("other",{"index":index},2,0).is_empty())
	assert(memory.events().size() == 256 and memory.latest("meal").known)
	assert(memory.restore(JSON.parse_string(JSON.stringify(memory.snapshot()))))
	assert(memory.latest("meal").known and not memory.latest("unobserved").known)
	for index in range(12):
		assert(construction.move("move:%d" % index,func():return true,{"structures":{"storage":{"built":true,"position":{"x":index,"y":0.12,"z":0}}}}).ok)
	var construction_copy := Construction.new()
	construction_copy.configure(economy)
	assert(construction_copy.restore(JSON.parse_string(JSON.stringify(construction.snapshot()))))
	assert(construction_copy.structure("storage").position.x == 11)
	var bad_projection := construction.snapshot()
	bad_projection.structures.storage.position.x = 77
	assert(not construction_copy.restore(bad_projection) and construction_copy.structure("storage").position.x == 11)

	await _actual_chain()
	await _actual_path_failure()
	await _actual_scaled_workload()
	await _actual_region_unload_reload()
	print("ARK_RESOURCE_CONSISTENCY_TEST_OK: finite stock, contention, payload save/reload, idempotence, cancellation capacity, region flags, malformed atomic rollback, construction refund and factual memory")
	quit()

func _new_game(scene: PackedScene, save_root: String) -> Node3D:
	var game := scene.instantiate() as Node3D
	game.set("save_root_override",save_root)
	game.set_process(false)
	game.set_physics_process(false)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await physics_frame
	return game

func _actual_chain() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.tmp/recovery-round/resource_actual_save")
	var save = load("res://scripts/ark_greybox_save.gd").new(save_root)
	save.clear_for_test()
	var scene := load("res://scenes/ark_greybox.tscn") as PackedScene
	var game := await _new_game(scene,save_root)
	# A resident needs a real, paid-for home and an accepted invitation before
	# production gathering; do not bypass that invariant with a boarded flag.
	var player := game.get("player") as CharacterBody3D
	player.global_position = (game.get_node("DriftwoodNear") as Node3D).global_position + Vector3.UP
	game.call("_interact")
	assert(int(game.get("wood")) == 3 and int(game.get("economy").source("DriftwoodNear").remaining) == 0)
	assert(game.call("_try_place_shelter", Vector3.ZERO) and int(game.get("wood")) == 0, "the real starting plank and two collected planks should pay for a shelter")
	player.global_position = (game.get_node("residentMarker") as Node3D).global_position + Vector3.UP
	game.call("_interact")
	game.call("_interact")
	assert(bool(game.get("resident_met")) and bool(game.get("traveler_choice_pending")) and not bool(game.get("traveler_boarded")))
	game.call("_choose_traveler_boarding", true)
	assert(bool(game.get("traveler_boarded")) and bool(game.get("economy").audit().ok), "a consenting resident may now gather for the real household")
	game.set("weather_phase",2)
	game.set("day_count",2)
	game.set("day_period",0)
	assert(game.call("_begin_resident_daily_gather"))
	var economy: RefCounted = game.get("economy")
	var tasks: RefCounted = game.get("gathering")
	var id := str(game.get("resident_task_id"))
	var target := str(game.get("resident_gather_target_id"))
	var start_stock: int = economy.inventory("player","wood")
	var token: Dictionary = tasks.token(id)
	var marker := game.get("traveler_marker") as Node3D
	var initial := marker.global_position
	for _step in range(600):
		game.call("_process_resident_gathering",0.1)
		if str(game.get("resident_gather_phase")) == "collecting": break
	assert(tasks.task(id).phase == "collecting")
	game.call("_process_resident_gathering",0.2)
	var remaining := float(game.get("resident_gather_pickup_remaining"))
	assert(absf(remaining - 0.45) < 0.000001)
	assert(game.call("_save_progress"))
	game.queue_free()
	await process_frame
	game = await _new_game(scene,save_root)
	economy = game.get("economy")
	tasks = game.get("gathering")
	marker = game.get("traveler_marker") as Node3D
	assert(str(game.get("resident_gather_phase")) == "collecting" and tasks.task(id).phase == "collecting")
	assert(absf(float(game.get("resident_gather_pickup_remaining")) - remaining) < 0.000001)
	for _step in range(600):
		game.call("_process_resident_gathering",0.1)
		if int(game.get("resident_gather_payload")) > 0: break
	assert(marker.global_position.distance_to(initial) > 0.1)
	var carried := int(game.get("resident_gather_payload"))
	assert(carried > 0 and economy.carried(id).amount == carried and economy.source(target).remaining == 0)
	assert(economy.inventory("player","wood") == start_stock and economy.audit().ok)
	assert(game.call("_save_progress"))
	game.queue_free()
	await process_frame
	game = await _new_game(scene,save_root)
	economy = game.get("economy")
	tasks = game.get("gathering")
	assert(not tasks.accept_result(token))
	if int(game.get("resident_gather_payload")) != carried:
		print("RESOURCE_RELOAD_DIAGNOSTIC: ",game.get_meta("save_load_blocked",false)," ",game.get_meta("save_warning","")," payload=",game.get("resident_gather_payload"))
	assert(int(game.get("resident_gather_payload")) == carried and economy.carried(id).amount == carried)
	for _step in range(600):
		game.call("_process_resident_gathering",0.1)
		if not game.get("resident_gather_pending"): break
	assert(not game.get("resident_gather_pending"))
	assert(economy.inventory("player","wood") == start_stock + carried and economy.audit().ok)
	assert(tasks.deliver(id).duplicate and economy.inventory("player","wood") == start_stock + carried)
	assert(game.call("_save_progress"))
	game.queue_free()
	await process_frame
	game = await _new_game(scene,save_root)
	assert(int(game.get("wood")) == start_stock + carried and game.get("economy").audit().ok)
	game.queue_free()
	await process_frame
	save.clear_for_test()
	print("RESOURCE_ACTUAL_CHAIN_OK: production dispatch/path/harvest, carried save/free/recreate, delivery exactly once")

# Helpers for SceneTree resource consistency test. Requires Save preload.
# These are actual finite-source scene nodes and production gathering ticks,
# not CharacterBody NPCs, rendered crowd capacity, or a production region streamer.
func _workload_game(label: String) -> Node3D:
	var save_root := ProjectSettings.globalize_path("res://../.tmp/recovery-round/resource_" + label)
	var save := Save.new(save_root)
	save.clear_for_test()
	var scene := load("res://scenes/ark_greybox.tscn") as PackedScene
	var game := scene.instantiate() as Node3D
	game.set("save_root_override", save_root)
	game.set_process(false)
	game.set_physics_process(false)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await physics_frame
	return game

func _remove_fixture_source(game: Node3D, source_id: String) -> void:
	var entries: Array = game.get("interactables")
	for index in range(entries.size() - 1, -1, -1):
		if str(entries[index].get("item_id", "")) == source_id:
			var node: Node = entries[index].get("node")
			if is_instance_valid(node):
				node.queue_free()
			entries.remove_at(index)

func _fixture_source(game: Node3D, source_id: String, position: Vector3, amount: int, region: String) -> Node3D:
	game.call("_add_pile", source_id, position, amount)
	var economy: RefCounted = game.get("economy")
	# Explicitly declared finite test input; duplicate seed must preserve its stock.
	if economy.source(source_id).is_empty():
		assert(economy.seed_source(source_id, "wood", amount, region))
	return game.get_node(NodePath(source_id)) as Node3D

func _actual_scaled_workload() -> void:
	for count in [4, 12, 24]:
		var game := await _workload_game("scale_%d" % count)
		var economy: RefCounted = game.get("economy")
		var gathering: RefCounted = game.get("gathering")
		var initial: int = economy.inventory("workload", "wood")
		var home := Vector3(0, 0.5, 0)
		var actors: Array[Node3D] = []
		var targets: Array[Vector3] = []
		var ids: Array[String] = []
		for index in range(count):
			var source_id := "WorkloadSource%d" % index
			var target := Vector3(-4.0 - float(index % 4) * 0.1, 0.15, 1.5 + float(index / 4) * 0.1)
			_fixture_source(game, source_id, target, 1, "workload_region")
			var actor := Node3D.new()
			actor.name = "WorkloadActor%d" % index
			game.add_child(actor)
			actor.global_position = home
			actors.append(actor)
			targets.append(target)
			var dispatched: Dictionary = gathering.dispatch("workload:%d" % index, source_id, "workload", "workload_region")
			assert(dispatched.ok)
			ids.append(dispatched.task_id)
		await physics_frame
		var timings: Array[float] = []
		var completed := 0
		var moving_peak := 0
		for frame in range(600):
			var started := Time.get_ticks_usec()
			completed = 0
			var moving := 0
			for index in range(count):
				var phase := str(gathering.task(ids[index]).phase)
				if phase == "delivered":
					completed += 1
					continue
				if phase in ["outbound", "returning"]:
					moving += 1
				var result: Dictionary = gathering.tick(ids[index], 0.1, actors[index].global_position, targets[index], home, Callable(game, "_build_resident_walk_route"))
				assert(result.ok)
				actors[index].global_position = result.position
			moving_peak = maxi(moving_peak, moving)
			timings.append(float(Time.get_ticks_usec() - started) / 1000.0)
			assert(economy.audit().ok)
			if completed == count:
				break
		assert(completed == count and economy.inventory("workload", "wood") == initial + count)
		for id in ids:
			assert(economy.carried(id).is_empty())
		assert(economy.snapshot().reservations.is_empty())
		timings.sort()
		print("RESOURCE_ACTUAL_WORKLOAD: ", JSON.stringify({"tasks": count, "active_task_peak": count, "moving_task_peak": moving_peak, "allocated_actor_proxies": count, "rendered_visible": 0, "workload_visible_proxies": 0, "added_finite_sources": count, "total_registered_sources": economy.snapshot().sources.size(), "actual_node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "simulation_tick_p50_ms": timings[int(timings.size() * 0.5)], "simulation_tick_p95_ms": timings[mini(timings.size() - 1, int(timings.size() * 0.95))], "simulation_tick_max_ms": timings.back(), "scope": "real scene path query plus production gathering.tick; Node3D proxies, no crowd collision/render capacity claim"}))
		game.queue_free()
		await process_frame

func _actual_region_unload_reload() -> void:
	var game := await _workload_game("region")
	var economy: RefCounted = game.get("economy")
	var gathering: RefCounted = game.get("gathering")
	var source_id := "ReloadStableFiniteSource"
	var target := Vector3(-4, 0.15, 1.5)
	var home := Vector3(0, 0.5, 0)
	var source := _fixture_source(game, source_id, target, 3, "reload_fixture")
	var actor := Node3D.new()
	game.add_child(actor)
	actor.global_position = home
	var initial: int = economy.inventory("region_fixture", "wood")
	var dispatched: Dictionary = gathering.dispatch("region_actor", source_id, "region_fixture", "reload_fixture")
	assert(dispatched.ok)
	var old_id := str(dispatched.task_id)
	var old_token: Dictionary = gathering.token(old_id)
	await physics_frame
	for frame in range(300):
		var result: Dictionary = gathering.tick(old_id, 0.1, actor.global_position, target, home, Callable(game, "_build_resident_walk_route"))
		assert(result.ok)
		actor.global_position = result.position
		if gathering.task(old_id).phase == "collecting":
			break
	assert(gathering.task(old_id).phase == "collecting")
	actor.global_position = home # Region controller evacuates the proxy before teardown.
	gathering.unload_region("reload_fixture")
	assert(not gathering.accept_result(old_token))
	assert(economy.source(source_id).remaining == 3 and economy.carried(old_id).is_empty())
	_remove_fixture_source(game, source_id)
	await process_frame
	assert(not is_instance_valid(source))
	assert(not gathering.dispatch("region_actor", source_id, "region_fixture", "reload_fixture").ok)
	assert(economy.audit().ok and economy.snapshot().reservations.is_empty())
	var opening_totals: Dictionary = economy.snapshot().totals
	gathering.reload_region("reload_fixture")
	source = _fixture_source(game, source_id, target, int(economy.source(source_id).remaining), "reload_fixture")
	assert(economy.snapshot().totals == opening_totals, "same stable source reload must not add supply")
	dispatched = gathering.dispatch("region_actor", source_id, "region_fixture", "reload_fixture")
	assert(dispatched.ok and dispatched.task_id != old_id)
	await physics_frame
	for frame in range(600):
		var result: Dictionary = gathering.tick(dispatched.task_id, 0.1, actor.global_position, target, home, Callable(game, "_build_resident_walk_route"))
		assert(result.ok)
		actor.global_position = result.position
		assert(economy.audit().ok)
		if gathering.task(dispatched.task_id).phase == "delivered":
			break
	assert(gathering.task(dispatched.task_id).phase == "delivered")
	assert(economy.source(source_id).remaining == 0 and economy.inventory("region_fixture", "wood") == initial + 3)
	assert(economy.carried(dispatched.task_id).is_empty() and economy.snapshot().reservations.is_empty())
	assert(not gathering.accept_result(old_token))
	_remove_fixture_source(game, source_id)
	game.queue_free()
	await process_frame
	print("RESOURCE_ACTUAL_REGION_OK: physical finite-source teardown/recreate, production path/harvest/delivery, stable stock, stale callback rejected; not a full production streamer")

func _actual_path_failure() -> void:
	var game := await _workload_game("unreachable")
	var economy: RefCounted = game.get("economy")
	var gathering: RefCounted = game.get("gathering")
	# Actual planner rejects a finite target beyond its world bounds; no fake route provider.
	var target := Vector3(float(game.get_script().get_script_constant_map()["PLAYER_WORLD_EDGE_LIMIT"]) + 1.0, 0.15, 0.0)
	var source_id := "BoundedUnreachableFiniteSource"
	_fixture_source(game, source_id, target, 2, "unreachable_fixture")
	var opening: int = economy.inventory("unreachable_fixture", "wood")
	var job: Dictionary = gathering.dispatch("unreachable_actor", source_id, "unreachable_fixture", "unreachable_fixture")
	assert(job.ok)
	var token: Dictionary = gathering.token(job.task_id)
	var result: Dictionary = gathering.tick(job.task_id, 0.1, Vector3.ZERO, target, Vector3.ZERO, Callable(game, "_build_resident_walk_route"))
	assert(not result.ok and result.code == "no_path")
	assert(gathering.task(job.task_id).phase == "cancelled" and not gathering.accept_result(token))
	assert(economy.source(source_id).remaining == 2 and economy.carried(job.task_id).is_empty())
	assert(economy.inventory("unreachable_fixture", "wood") == opening and economy.snapshot().reservations.is_empty())
	assert(economy.audit().ok)
	_remove_fixture_source(game, source_id)
	game.queue_free()
	await process_frame
	print("RESOURCE_ACTUAL_PATH_FAILURE_OK: production bounded planner rejection, cancellation, no credits/lost stock/stale callback")
