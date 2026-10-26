extends SceneTree

## Independent geometry/interaction acceptance for the finite starter refuge.
## Mesh footprints are measured from the instantiated scene, not layout constants.
const Paths = preload("res://tests/ark_test_paths.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
const NPC_RADIUS := 0.23
const PLAYER_RADIUS := 0.38
var game: Node3D
var save_root: String
var saves: RefCounted


func _initialize() -> void:
	_run.call_deferred()


func _spawn() -> void:
	game = load("res://scenes/ark_greybox.tscn").instantiate() as Node3D
	game.set("save_root_override", save_root)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	(game.get("player") as Node).set_physics_process(false)
	await physics_frame


func _drop() -> void:
	game.queue_free()
	await process_frame


func _key(code: Key, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	game.call("_unhandled_key_input", event)


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _events(id: String) -> int:
	var count := 0
	for event in game.get("world_events") as Array:
		if str(event.get("id", "")) == id:
			count += 1
	return count


func _ark() -> Node3D:
	return game.get_node("ArkRoot") as Node3D


func _shelter() -> Node3D:
	return game.get_node("ArkRoot/BuiltShelter") as Node3D


func _residents() -> Array[Node3D]:
	return [game.get("traveler_marker") as Node3D, game.get("sailmaker_marker") as Node3D]


func _mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	return node.get_child(0) as MeshInstance3D


func _footprint(node: Node) -> Rect2:
	var visual := _mesh(node)
	var box := visual.get_aabb()
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for x in [box.position.x, box.end.x]:
		for y in [box.position.y, box.end.y]:
			for z in [box.position.z, box.end.z]:
				var point := _ark().to_local(visual.to_global(Vector3(x, y, z)))
				minimum = minimum.min(Vector2(point.x, point.z))
				maximum = maximum.max(Vector2(point.x, point.z))
	return Rect2(minimum, maximum - minimum)


func _circle_clear(point: Vector2, radius: float, rect: Rect2) -> bool:
	var nearest := point.clamp(rect.position, rect.end)
	return point.distance_to(nearest) >= radius - 0.0001


func _furniture_clear(point: Vector2, radius: float) -> bool:
	for id in ["Cot", "HearthStone"]:
		if not _circle_clear(point, radius, _footprint(_shelter().get_node(id))):
			return false
	return true


func _assert_geometry() -> void:
	var shelter := _shelter()
	var mat := shelter.get_node("SharedMealSetting/WovenMat") as MeshInstance3D
	var cot := _mesh(shelter.get_node("Cot"))
	var floor_mesh := _mesh(shelter.get_node("Floor"))
	assert((mat.mesh as BoxMesh).size.is_equal_approx(Vector3(1.35, 0.035, 0.55)) and mat.scale.is_equal_approx(Vector3.ONE), "do not hide the collision by shrinking the real meal mat")
	assert((cot.mesh as BoxMesh).size.is_equal_approx(Vector3(1.8, 0.34, 0.8)) and cot.scale.is_equal_approx(Vector3.ONE), "keep the actual adult-sized bed, not a shrunken model or navigation footprint")
	assert((floor_mesh.mesh as BoxMesh).size.is_equal_approx(Vector3(3.0, 0.14, 2.4)), "fit the meal inside the existing refuge, without silently enlarging it")
	var mat_rect := _footprint(mat)
	assert(mat_rect.size.is_equal_approx(Vector2(1.35, 0.55)) and _footprint(cot).size.is_equal_approx(Vector2(1.8, 0.8)), "parent transforms must not secretly shrink the physical mat or cot")
	assert(_footprint(floor_mesh).size.is_equal_approx(Vector2(3.0, 2.4)), "parent transforms must not enlarge the refuge floor")
	assert(not mat_rect.intersects(_footprint(cot)), "visible WovenMat must not overlap the player's actual Cot footprint")
	assert(not mat_rect.intersects(_footprint(shelter.get_node("HearthStone"))), "meal mat must not be inside the fire basin")
	assert(_footprint(floor_mesh).encloses(mat_rect), "the complete unchanged mat must remain on existing shelter floor")
	for index in range(3):
		var bowl := shelter.get_node("SharedMealSetting/Bowl%d" % index) as MeshInstance3D
		assert(mat_rect.encloses(_footprint(bowl)), "all three real bowls must move together with the meal mat")
	var setting := shelter.get_node("SharedMealSetting")
	assert(setting.find_children("*", "CollisionObject3D", true, false).is_empty() and setting.find_children("*", "Light3D", true, false).is_empty(), "dining decoration must not add invisible blockers or lights")
	assert(not bool(game.get("raft_extension_built")) and not bool(game.get("guest_cabin_built")))
	assert(int(game.call("_resident_capacity")) == 2 and int(game.call("_resident_berth_capacity")) == 0, "a meal does not manufacture resident beds or expand refuge admission")


func _assert_targets() -> void:
	var targets: Array[Vector3] = [game.get("traveler_target_position"), game.get("sailmaker_target_position")]
	var floor_rect := _footprint(_shelter().get_node("Floor")).grow(-NPC_RADIUS)
	var mat_rect := _footprint(_shelter().get_node("SharedMealSetting/WovenMat") as MeshInstance3D)
	for target in targets:
		var point := Vector2(target.x, target.z)
		assert(floor_rect.has_point(point), "meal destination must fit a whole resident body inside the existing floor")
		assert(_furniture_clear(point, NPC_RADIUS), "meal destination must not occupy the player's cot or the hearth")
		assert(_circle_clear(point, NPC_RADIUS, mat_rect), "diners stand beside their bowls, not on the meal mat")
		assert(not bool(game.call("_ark_local_walk_cell_blocked", point)), "meal destination must also clear real scene collision")
	assert(Vector2(targets[0].x, targets[0].z).distance_to(Vector2(targets[1].x, targets[1].z)) >= NPC_RADIUS * 2, "two diners need separate body-sized places")


func _nearest_id(position: Vector3) -> String:
	var nearest := ""
	var distance := 2.8
	for entry in game.get("interactables") as Array:
		var marker := entry.get("node") as Node3D
		if marker == null or not is_instance_valid(marker):
			continue
		var candidate := position.distance_to(marker.global_position)
		if candidate < distance:
			nearest = str(entry.get("id", ""))
			distance = candidate
	return nearest


func _player_clear(point: Vector2) -> bool:
	var excluded: Array[RID] = []
	if not _furniture_clear(point, PLAYER_RADIUS) or bool(game.call("_ark_local_walk_cell_blocked", point, excluded, PLAYER_RADIUS)):
		return false
	for resident in _residents():
		if resident.get_parent() == _ark() and point.distance_to(Vector2(resident.position.x, resident.position.z)) < PLAYER_RADIUS + NPC_RADIUS - 0.0001:
			return false
	return true


func _approach(ids: Array[String], table: bool = false) -> Vector3:
	# A player-radius graph includes real scene colliders, real Cot/Hearth meshes
	# (which are intentionally non-solid), and both residents' occupied bodies.
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, 101, 81)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var minimum := Vector2(-2.5, -2.0)
	var step := 0.05
	for z in range(81):
		for x in range(101):
			grid.set_point_solid(Vector2i(x, z), not _player_clear(minimum + Vector2(x, z) * step))
	var start := Vector2i(50, 75) # Existing entry deck at (0, 1.75).
	assert(not grid.is_point_solid(start))
	var player := game.get("player") as Node3D
	var before := player.global_position
	for z in range(81):
		for x in range(101):
			var cell := Vector2i(x, z)
			if grid.is_point_solid(cell):
				continue
			var point := minimum + Vector2(x, z) * step
			var candidate := Vector3(point.x, _shelter().position.y + 0.19, point.y)
			if not ids.has(_nearest_id(_ark().to_global(candidate))):
				continue
			player.global_position = _ark().to_global(candidate)
			if table and not bool(game.call("_player_at_shared_table")):
				continue
			var path := grid.get_id_path(start, cell)
			if path.is_empty():
				continue
			var path_clear := true
			for index in range(1, path.size()):
				var midpoint := minimum + (Vector2(path[index - 1]) + Vector2(path[index])) * step * 0.5
				path_clear = path_clear and _player_clear(midpoint)
			if not path_clear:
				continue
			player.global_position = before
			return candidate
	player.global_position = before
	print("APPROACH_DIAGNOSTIC origin=", _shelter().position, " residents=", _residents()[0].position, " / ", _residents()[1].position, " requested=", ids, " table=", table)
	assert(false, "no connected body-sized player approach selects %s without standing in furniture or diners" % [ids])
	return Vector3.INF


func _stand(position: Vector3) -> void:
	(game.get("player") as Node3D).global_position = _ark().to_global(position)
	game.call("_update_interaction_hint")


func _walk(check_initial_overlap: bool = false) -> void:
	var escaped: Array[bool] = [false, false]
	var escaped_wall: Array[bool] = [false, false]
	var residents := _residents()
	for index in range(2):
		escaped[index] = _furniture_clear(Vector2(residents[index].position.x, residents[index].position.z), NPC_RADIUS)
		assert(escaped[index] or check_initial_overlap, "fresh residents must begin outside furniture")
		escaped_wall[index] = not bool(game.call("_ark_local_walk_cell_blocked", Vector2(residents[index].position.x, residents[index].position.z)))
	for step in range(280):
		var before: Array[Vector3] = [residents[0].position, residents[1].position]
		game.call("_process", 0.05)
		assert(Vector2(residents[0].position.x, residents[0].position.z).distance_to(Vector2(residents[1].position.x, residents[1].position.z)) >= NPC_RADIUS * 2, "actual diners must not walk through each other")
		for index in range(2):
			var current := residents[index].position
			assert(current.distance_to(before[index]) <= 0.1, "normal meal movement must not teleport a saved resident")
			# Trace segments too: a legal waypoint cannot hide clipping on approach.
			for sample in range(1, 5):
				var position := before[index].lerp(current, sample / 4.0)
				var point := Vector2(position.x, position.z)
				var clear := _furniture_clear(point, NPC_RADIUS)
				assert(not escaped[index] or clear, "real meal movement crossed Cot/Hearth: %s at %s step %d" % [residents[index].name, position, step])
				escaped[index] = escaped[index] or clear
				var wall_clear := not bool(game.call("_ark_local_walk_cell_blocked", point))
				assert(not escaped_wall[index] or wall_clear, "meal walking must not cross a wall or unsupported water: %s at %s step %d" % [residents[index].name, position, step])
				escaped_wall[index] = escaped_wall[index] or wall_clear
	assert(escaped[0] and escaped[1] and escaped_wall[0] and escaped_wall[1], "legacy/boarding overlapping positions must escape through ordinary movement")
	var targets: Array[Vector3] = [game.get("traveler_target_position"), game.get("sailmaker_target_position")]
	for index in range(2):
		assert(residents[index].position.distance_to(targets[index]) < 0.07, "independent arrival check must agree with actual scene positions")
	assert(bool(game.call("_shared_table_ready")), "both residents must actually reach the distinct meal destinations")
	assert(int(game.get("shared_meal_count")) == 0 and _events("resident_meal_shared") == 0, "physical arrival is not consent to consume the meal")


func _assert_owners(before: Dictionary, after: Dictionary) -> void:
	for field in ["economy", "construction", "construction_sequence"]:
		assert(_json(before[field]) == _json(after[field]), "layout/reload must not mutate ownership or receipts: " + field)


func _reload_unchanged() -> void:
	assert(bool(game.call("_save_progress")))
	var before: Dictionary = game.call("_build_save_state")
	await _drop()
	await _spawn()
	var after: Dictionary = game.call("_build_save_state")
	assert(_json(before.world_events) == _json(after.world_events) and before.event_sequence == after.event_sequence, "loading the layout must never rewrite historical gathering positions or invent events")
	_assert_owners(before.modules, after.modules)
	assert(_json(before.modules.memories) == _json(after.modules.memories), "reloading must preserve durable history as well as the visible event log")
	for field in ["day_count", "day_period", "shared_meal_day", "shared_meal_count", "stew_servings", "raw_shellfish", "player_health", "traveler_position", "sailmaker_position"]:
		assert(_json(before[field]) == _json(after[field]), "reload must preserve saved facts, not teleport or replay: " + field)
	assert(int(after.schema_version) == 43, "layout and legacy meal state survive current schema 43")
	_assert_geometry()


func _fixture(origin: Vector3) -> void:
	await _spawn()
	game.set("wood", 10)
	(game.get("player") as Node3D).position = Vector3(0, 1.1, 1.75)
	assert(bool(game.call("_try_place_shelter", origin)))
	assert(int(game.get("wood")) == 7, "unchanged starter shelter costs three wood")
	game.set("weather_phase", 2)
	game.set("day_count", 2)
	game.set("day_period", 2)
	game.set("resident_met", true)
	game.set("traveler_choice_pending", true)
	_key(KEY_ESCAPE)
	assert(not bool(game.get("traveler_boarded")), "cancelled refuge invitation must not be mistaken for consent")
	game.set("traveler_choice_pending", true)
	_key(KEY_1)
	game.set("sailmaker_met", true)
	game.set("sailmaker_choice_pending", true)
	_key(KEY_ESCAPE)
	assert(not bool(game.get("sailmaker_boarded")))
	game.set("sailmaker_choice_pending", true)
	_key(KEY_1)
	assert(bool(game.get("traveler_boarded")) and bool(game.get("sailmaker_boarded")))
	game.set("raw_shellfish", 1)
	await physics_frame
	_assert_geometry()
	_stand(_approach(["hearth"]))
	assert((game.get("interaction_hint") as Label).text == "E  ·  使用火盆煮汤")
	_key(KEY_E)
	assert(int(game.get("raw_shellfish")) == 0 and int(game.get("stew_servings")) == 1 and _events("meal_prepared") == 1, "actual E must still cook one serving at the hearth")
	game.set("player_health", 2)
	_stand(_approach(["resident"], true))
	_key(KEY_E, true)
	assert(not bool(game.get("shared_meal_gathering_pending")) and int(game.get("stew_servings")) == 1, "held E must not accept a meal")
	_key(KEY_E)
	assert(bool(game.get("shared_meal_gathering_pending")) and int(game.get("stew_servings")) == 0)
	_assert_targets()


func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/test_shared_meal_clearance").simplify_path()
	assert(Paths.is_safe_save_root(save_root))
	saves = Save.new(save_root)
	saves.clear_for_test()
	var legacy: Dictionary
	for origin in [Vector3.ZERO, Vector3(-0.5, 0.12, 0)]:
		await _fixture(origin)
		var receipt_state: Dictionary = (game.call("_build_save_state") as Dictionary).modules
		_stand(_approach(["resident", "sailmaker", "hearth"], true))
		_walk()
		_assert_targets()
		_approach(["hearth"], true) # Stationary diners leave a usable hearth approach.
		# Cot must win its own E dispatch while a meal is still pending.
		_stand(_approach(["cot"]))
		assert((game.get("interaction_hint") as Label).text == "E  ·  在自己的床铺休息")
		_key(KEY_E)
		assert(int(game.get("day_period")) == 3 and int(game.get("player_health")) == 4 and bool(game.get("shared_meal_paused")), "a pending meal must not steal rest from the player's real cot")
		game.set("player_health", 2)
		# Leaving/cancelling participation retains the already reserved single meal.
		_stand(Vector3(2.5, 0.19, 1.75))
		game.call("_process", 0.05)
		assert(bool(game.get("shared_meal_paused")) and int(game.get("stew_servings")) == 0 and _events("resident_meal_shared") == 0)
		await _reload_unchanged()
		await _reload_unchanged()
		_stand(_approach(["resident", "sailmaker", "hearth"], true))
		game.call("_process", 0.05)
		assert(bool(game.get("shared_meal_paused")), "walking back is not permission to resume")
		_key(KEY_E)
		assert(not bool(game.get("shared_meal_paused")) and int(game.get("shared_meal_count")) == 0, "E at a reachable meal marker resumes rather than cooking/consuming twice")
		_assert_targets()
		_walk()
		await _reload_unchanged()
		assert(bool(game.call("_shared_table_ready")))
		_stand(_approach(["hearth"], true))
		if origin == Vector3.ZERO:
			legacy = game.call("_build_save_state")
		_key(KEY_E, true)
		assert(int(game.get("shared_meal_count")) == 0)
		_key(KEY_E)
		assert(int(game.get("shared_meal_count")) == 1 and int(game.get("player_health")) == 3)
		assert(_events("resident_meal_gathering_started") == 1 and _events("resident_meal_shared") == 1 and _events("resident_keepsake_placed") == 1)
		var completed: Dictionary = game.call("_build_save_state")
		game.call("_complete_shared_table_meal")
		game.call("_begin_shared_table_meal")
		assert(int(game.get("shared_meal_count")) == 1 and int(game.get("stew_servings")) == 0)
		_assert_owners(receipt_state, completed.modules)
		await _reload_unchanged()
		await _reload_unchanged()
		assert(_events("resident_meal_shared") == 1 and int(game.get("player_health")) == 3)
		await _drop()
		saves.clear_for_test()

	# Recreate actual old active-meal coordinates and factual historical positions.
	# Old saves preserve both positions initially; ordinary walking must recover.
	for scenario in [{"schema": 34, "cooking": false}, {"schema": 35, "cooking": false}, {"schema": 35, "cooking": true}]:
		var old := legacy.duplicate(true)
		old.schema_version = scenario.schema
		old.traveler_position = {"x": -0.35, "y": 0.24, "z": -0.12}
		old.sailmaker_position = {"x": 0.42, "y": 0.24, "z": -0.12}
		for event in old.world_events:
			if str(event.get("id", "")) == "resident_meal_gathering_started":
				event.facts.gathering_positions = {"tidekeeper": old.traveler_position.duplicate(), "sailmaker": old.sailmaker_position.duplicate()}
				old.modules.memories.durable.resident_meal_gathering_started = event.duplicate(true)
		old.modules.memories.events = old.world_events.duplicate(true)
		if scenario.cooking:
			old.traveler_position = {"x": -1.05, "y": 0.24, "z": -0.75}
		assert(bool(saves.save_state(old).get("ok", false)))
		await _spawn()
		var loaded: Dictionary = game.call("_build_save_state")
		assert(not bool(game.get_meta("save_load_blocked", false)))
		assert(_json(loaded.modules.memories) == _json(old.modules.memories), "legacy durable history must remain factual and unchanged")
		assert(_json(loaded.world_events) == _json(old.world_events), "legacy start facts describe history; never rewrite them to the new coordinates")
		_assert_owners(old.modules, loaded.modules)
		for field in ["traveler_position", "sailmaker_position"]:
			var before_position: Dictionary = old[field]
			var after_position: Dictionary = loaded[field]
			assert(Vector3(after_position.x, after_position.y, after_position.z).is_equal_approx(Vector3(before_position.x, before_position.y, before_position.z)), "legacy positions must be preserved until movement: " + field)
		_assert_geometry()
		_assert_targets()
		# Moving and rotating the Ark must not confuse shelter-local furniture tests.
		_ark().position = Vector3(-8, 0, 3)
		_ark().rotation.y = 0.65
		await physics_frame
		_stand(_approach(["hearth", "resident", "sailmaker"], true))
		_walk(true)
		await _reload_unchanged()
		_key(KEY_E)
		assert(int(game.get("shared_meal_count")) == 1 and _events("resident_meal_shared") == 1 and int(game.get("stew_servings")) == 0)
		await _reload_unchanged()
		await _drop()
		saves.clear_for_test()
	print("ARK_SHARED_MEAL_CLEARANCE_TEST_OK: unchanged real mesh sizes; mat/Cot/hearth separation; body-sized resident routes and reachable E cot/hearth; consent/pause/arrival; repeated saves/history/receipts; shifted shelter/mobile Ark; schema34/35 active meals")
	quit()
