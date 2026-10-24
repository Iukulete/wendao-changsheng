extends SceneTree
const Save=preload("res://scripts/ark_greybox_save.gd")
func _initialize()->void: _run.call_deferred()
func _run()->void:
	await _actual_scaled_workload()
	print("SCALED_TRIAL_OK")
	quit()
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
				var result: Dictionary = gathering.tick(ids[index], 0.1, actors[index].global_position, targets[index], home, Callable(game, "_build_resident_walk_route"), 2.4, true)
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
		print("RESOURCE_ACTUAL_WORKLOAD: ", JSON.stringify({"tasks": count, "active_task_peak": count, "moving_task_peak": moving_peak, "allocated_actor_proxies": count, "rendered_visible": 0, "workload_visible_proxies": 0, "added_finite_sources": count, "total_registered_sources": economy.snapshot().sources.size(), "actual_node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "simulation_tick_p50_ms": timings[int(timings.size() * 0.5)], "simulation_tick_p95_ms": timings[mini(timings.size() - 1, int(timings.size() * 0.95))], "simulation_tick_max_ms": timings.back(), "scope": "real scene path query plus opt-in single-edge gathering.tick; Node3D proxies, no crowd collision/render capacity claim"}))
		game.queue_free()
		await process_frame

