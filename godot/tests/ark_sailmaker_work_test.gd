extends SceneTree

## Independent work-causality regression. Only negative/interruption fixtures
## set work positions; the positive chain walks, sews, carries and installs.
const Paths = preload("res://tests/ark_test_paths.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
const PHASE := "sailmaker_awning_phase"
const SEW := "sailmaker_awning_sewing_elapsed"
const INSTALL := "sailmaker_awning_install_elapsed"
const EVENT := "resident_sail_awning_raised"
var game: Node3D
var saver: RefCounted
var save_root: String
var eligible: Dictionary
var escaped_furniture := false
var escaped_wall := false
var work_update_usec: Array[int] = []
var installation_facing_samples: Array[Dictionary] = []
var observed_front_frames := 0
var observed_forward_steps := 0
var observed_completion_clearance_checks := 0
var observed_postgift_clearance_checks := 0
var observed_postgift_arrivals := 0
var resting_arm_transforms: Dictionary = {}
var completed_awning_shape: Dictionary = {}


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
	game.set("save_service", null)
	game.queue_free()
	await process_frame


func _load_state(state: Dictionary) -> void:
	await _drop()
	saver.clear_for_test()
	assert(bool(saver.save_state(state).get("ok", false)), "valid fixture must remain saveable")
	await _spawn()
	assert(not bool(game.get_meta("save_load_blocked", false)), "fixture must preserve all modular save mirrors")


func _ark() -> Node3D:
	return game.get_node("ArkRoot") as Node3D


func _resident() -> Node3D:
	return game.get("sailmaker_marker") as Node3D


func _target(installing: bool = false) -> Vector3:
	return game.call("_sailmaker_awning_work_target", installing)


func _events(id: String = EVENT) -> int:
	var count := 0
	for event in game.get("world_events") as Array:
		if str(event.get("id", "")) == id:
			count += 1
	return count


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _economic_state() -> Dictionary:
	var state: Dictionary = game.call("_build_save_state")
	var result: Dictionary = {}
	for key in ["wood", "stored_wood", "raw_shellfish", "stew_servings", "day_count", "day_period"]:
		result[key] = state[key]
	for key in ["economy", "construction", "construction_sequence"]:
		result[key] = state.modules[key]
	return _json(result)


func _progress() -> Array:
	return [game.get(PHASE), snappedf(float(game.get(SEW)), 0.00000001), snappedf(float(game.get(INSTALL)), 0.00000001), game.get("sailmaker_awning_raised"), _events()]


func _normal_conditions() -> void:
	game.set("weather_phase", 2)
	game.set("day_period", 0)
	game.set("sailing_mode", false)
	game.set("building_mode", false)
	game.set("shared_meal_gathering_pending", false)
	game.set("shared_meal_paused", false)
	(game.get("shared_meal_participants") as Array).clear()
	game.set("raft_edge_damaged", false)
	game.set("shelter_roof_damaged", false)


func _stage(phase: String) -> void:
	_normal_conditions()
	game.set(PHASE, phase)
	game.set(SEW, 3.0 if phase in ["carrying", "installing"] else 0.6 if phase == "sewing" else 0.0)
	game.set(INSTALL, 0.4 if phase == "installing" else 0.0)
	game.set("sailmaker_awning_raised", false)
	_resident().position = _target(phase == "installing") if phase in ["sewing", "installing"] else Vector3(1.15, 0.12, 0.75)
	game.set("sailmaker_routine_route", PackedVector3Array())
	game.set("sailmaker_routine_route_target_set", false)
	game.set("sailmaker_awning_route_retry_remaining", 0.0)
	game.call("_update_sailmaker_schedule")


func _guarded_ticks(count: int = 40, delta: float = 0.1) -> void:
	for _step in range(count):
		game.call("_process_sailmaker_awning_work", delta)


func _footprint(node: Node) -> Rect2:
	var mesh := (node if node is MeshInstance3D else node.get_child(0)) as MeshInstance3D
	var box := mesh.get_aabb()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for x in [box.position.x, box.end.x]:
		for y in [box.position.y, box.end.y]:
			for z in [box.position.z, box.end.z]:
				var point := _ark().to_local(mesh.to_global(Vector3(x, y, z)))
				lo = lo.min(Vector2(point.x, point.z))
				hi = hi.max(Vector2(point.x, point.z))
	return Rect2(lo, hi - lo)


func _furniture_clear(point: Vector2) -> bool:
	for name in ["Cot", "HearthStone"]:
		var bounds := _footprint(game.get_node("ArkRoot/BuiltShelter/" + name))
		if point.distance_to(point.clamp(bounds.position, bounds.end)) < 0.23 - 0.0001:
			return false
	return true


func _reset_geometry_guard() -> void:
	var position := _resident().position
	var point := Vector2(position.x, position.z)
	escaped_furniture = _furniture_clear(point)
	escaped_wall = not bool(game.call("_ark_local_walk_cell_blocked", point))


func _face_front() -> Vector3:
	# Derive forward from the actual rendered face/body, not a presumed model
	# axis or the runtime yaw formula that this independent test is checking.
	var face := _resident().get_node("SailmakerFigure/Face") as Node3D
	var torso := _resident().get_node("SailmakerFigure/Body") as Node3D
	var front := face.global_position - torso.global_position
	front.y = 0.0
	assert(front.length() > 0.1, "graybox face must visibly establish a body-front direction")
	return front.normalized()


func _assert_active_work_geometry() -> void:
	var phase := str(game.get(PHASE))
	var sewing := phase == "sewing" and _resident().position.distance_to(_target()) <= 0.06001
	var prepared := phase in ["carrying", "installing"]
	if not sewing and not prepared:
		return
	assert(bool(game.call("_sailmaker_awning_work_can_run")))
	var front := _face_front()
	var torso := _resident().get_node("SailmakerFigure/Body") as Node3D
	var cloth := _resident().get_node("OldSailBundle") as MeshInstance3D
	assert((cloth.global_position - torso.global_position).dot(front) > 0.1, "active cloth must be in front of the actual face/body, not behind her back")
	for name in ["ArmLeft", "ArmRight"]:
		var arm := _resident().get_node("SailmakerFigure/" + name) as MeshInstance3D
		# The distal end is the lower local-Y end of the real capsule mesh.
		# World conversion includes actual arm rotation, mesh scale and body bob.
		var bounds := arm.get_aabb()
		var hand := arm.to_global(Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z))
		assert((hand - torso.global_position).dot(front) > 0.1, "working hands must reach into the same front half-plane as the cloth")
		assert(hand.distance_to(cloth.global_position) < 0.65 and absf(hand.y - cloth.global_position.y) < 0.25, "graybox raised hands must broadly reach the held cloth at its height, not pose on the opposite side")
		var cloth_bounds := cloth.get_aabb()
		var hand_in_cloth := cloth.to_local(hand)
		var closest := hand_in_cloth.clamp(cloth_bounds.position, cloth_bounds.end)
		assert(hand.distance_to(cloth.to_global(closest)) <= 0.08, "each real capsule hand tip must contact or nearly contact the actual transformed cloth bounds")
		if phase == "installing" and _resident().position.distance_to(_target(true)) <= 0.06001:
			var upper_tip := Vector3(bounds.get_center().x, bounds.end.y, bounds.get_center().z)
			var original: Transform3D = resting_arm_transforms[name]
			var shoulder := (game.get("sailmaker_body") as Node3D).to_global(original * upper_tip)
			assert(arm.to_global(upper_tip).distance_to(shoulder) < 0.0001, "raised installation arms must rotate around their actual original shoulders, not slide the whole limb upward")
	if sewing:
		var spool := _resident().get_node("ThreadSpool") as Node3D
		assert((spool.global_position - torso.global_position).dot(front) > 0.1, "active sewing spool must share the front workspace")
	if phase == "installing" and _resident().position.distance_to(_target(true)) <= 0.06001:
		installation_facing_samples.append({"origin": _resident().global_position, "front": front, "cloth_corners": _mesh_box_vertices(cloth)})
	observed_front_frames += 1


func _mesh_box_vertices(part: MeshInstance3D, shift: Vector3 = Vector3.ZERO) -> PackedVector3Array:
	var vertices := PackedVector3Array()
	var bounds := part.get_aabb()
	for corner in range(8):
		vertices.append(part.to_global(bounds.get_endpoint(corner)) + shift)
	return vertices


func _mesh_boxes_separated(first: MeshInstance3D, second: MeshInstance3D, first_shift: Vector3 = Vector3.ZERO, first_padding: float = 0.0) -> bool:
	# Mesh-local AABBs become oriented boxes in world space. A world-axis AABB
	# comparison would invent intersections when the ark is yawed or cloth tilted.
	var first_axes: Array[Vector3] = [first.global_basis.x.normalized(), first.global_basis.y.normalized(), first.global_basis.z.normalized()]
	var second_axes: Array[Vector3] = [second.global_basis.x.normalized(), second.global_basis.y.normalized(), second.global_basis.z.normalized()]
	var axes: Array[Vector3] = []
	axes.append_array(first_axes)
	axes.append_array(second_axes)
	for first_axis in first_axes:
		for second_axis in second_axes:
			var cross_axis := first_axis.cross(second_axis)
			if cross_axis.length() > 0.00001:
				axes.append(cross_axis.normalized())
	var first_vertices := _mesh_box_vertices(first, first_shift)
	var second_vertices := _mesh_box_vertices(second)
	for axis in axes:
		var first_min := INF
		var first_max := -INF
		var second_min := INF
		var second_max := -INF
		for vertex in first_vertices:
			first_min = minf(first_min, vertex.dot(axis))
			first_max = maxf(first_max, vertex.dot(axis))
		for vertex in second_vertices:
			second_min = minf(second_min, vertex.dot(axis))
			second_max = maxf(second_max, vertex.dot(axis))
		if first_max + first_padding < second_min - 0.000001 or second_max < first_min - first_padding - 0.000001:
			return true
	return false


func _assert_completed_canvas_clearance(canvas: MeshInstance3D) -> void:
	assert(_resident().position.distance_to(_target(true)) <= 0.06001, "completion clearance must inspect the real arrived installer, before ordinary-life motion")
	assert(not _mesh_boxes_separated(canvas, canvas), "separating-axis oracle must reject an exactly overlapping box")
	var centre_shift := _ark().to_global(_target(true)) - _resident().global_position
	for name in ["Head", "Hair", "HairTail", "Face"]:
		var part := _resident().get_node("SailmakerFigure/" + name) as MeshInstance3D
		assert(_mesh_boxes_separated(part, canvas), "completed canvas intersects actual installer " + name + " at the genuine arrival position")
		# A spherical 6cm expansion is conservative: actual allowed vertical error
		# is only 2.5cm. No actor teleport or production target helper is substituted
		# for the first real-completion check above.
		assert(_mesh_boxes_separated(part, canvas, centre_shift, 0.06001), "completed canvas must also clear " + name + " throughout the current arrival-tolerance neighborhood")
		observed_completion_clearance_checks += 2


func _assert_arms_fully_restored() -> void:
	for name in ["ArmLeft", "ArmRight"]:
		var arm := _resident().get_node("SailmakerFigure/" + name) as Node3D
		assert(arm.transform.is_equal_approx(resting_arm_transforms[name]), "pause/completion must restore the full original arm transform, not only its angle")


func _awning_shape() -> Dictionary:
	var canvas := game.get_node("ArkRoot/BuiltShelter/SailmakerAwning/PatchedCanvas") as MeshInstance3D
	var supports: Array = []
	for child in canvas.get_parent().get_children():
		if child is MeshInstance3D and child.mesh is CylinderMesh:
			supports.append([child.position, child.mesh.height])
	return {"position": canvas.position, "rotation": canvas.rotation, "size": (canvas.mesh as BoxMesh).size, "supports": supports}


func _assert_awning_supports() -> void:
	var canvas := game.get_node("ArkRoot/BuiltShelter/SailmakerAwning/PatchedCanvas") as MeshInstance3D
	assert((canvas.mesh as BoxMesh).size.is_equal_approx(Vector3(1.7, 0.07, 1.08)), "headroom fix must retain the existing gift mesh dimensions")
	var count := 0
	for child in canvas.get_parent().get_children():
		if not child is MeshInstance3D or not child.mesh is CylinderMesh:
			continue
		var support := child as MeshInstance3D
		var bounds := support.get_aabb()
		var top := support.to_global(Vector3(0, bounds.end.y, 0))
		var bottom := (canvas.get_parent() as Node3D).to_local(support.to_global(Vector3(0, bounds.position.y, 0)))
		var canvas_bounds := canvas.get_aabb()
		var closest := canvas.to_local(top).clamp(canvas_bounds.position, canvas_bounds.end)
		assert(top.distance_to(canvas.to_global(closest)) <= 0.02 and absf(bottom.y - 0.8) < 0.00001, "existing supports must reach the actual raised canvas while preserving their original lower anchors")
		count += 1
	assert(count == 2)


func _assert_postgift_head_clearance(context: String) -> void:
	var canvas := game.get_node("ArkRoot/BuiltShelter/SailmakerAwning/PatchedCanvas") as MeshInstance3D
	for figure in [game.get("traveler_body") as Node3D, game.get("sailmaker_body") as Node3D]:
		for name in ["Head", "Hair", "HairTail", "Face"]:
			var part := figure.get_node(name) as MeshInstance3D
			assert(_mesh_boxes_separated(part, canvas), "post-gift canvas intersects actual %s/%s during %s" % [figure.name, name, context])
			observed_postgift_clearance_checks += 1
	_assert_arms_fully_restored()


func _walk_postgift_targets(context: String, expected: Array[Vector3], require_both_to_walk: bool = true) -> void:
	var residents: Array[Node3D] = [game.get("traveler_marker") as Node3D, _resident()]
	var traveled := [0.0, 0.0]
	assert((game.get("traveler_target_position") as Vector3).distance_to(expected[0]) < 0.001 and (game.get("sailmaker_target_position") as Vector3).distance_to(expected[1]) < 0.001, "real refuge/meal targets must not silently use a safe fallback")
	var settled := 0
	for _step in range(500):
		var previous: Array[Vector3] = [residents[0].position, residents[1].position]
		game.call("_process", 0.05)
		_assert_postgift_head_clearance(context)
		var arrived := true
		for index in range(2):
			assert(residents[index].get_parent() == _ark())
			var distance := residents[index].position.distance_to(previous[index])
			# The legacy walker may finish its <=6cm waypoint remainder then
			# spend this frame's <=3.6cm travel budget on the next segment.
			assert(distance <= 0.11, "positive post-gift life must walk, never teleport: context=%s resident=%s from=%s to=%s distance=%s" % [context, index, previous[index], residents[index].position, distance])
			traveled[index] += distance
			arrived = arrived and residents[index].position.distance_to(expected[index]) <= 0.06001
		settled = settled + 1 if arrived else 0
		if settled >= 20:
			break
	assert(settled >= 20 and (not require_both_to_walk or (traveled[0] > 0.1 and traveled[1] > 0.1)), "both residents must genuinely arrive and remain clear through idle bob: context=%s settled=%s traveled=%s actual=%s/%s expected=%s" % [context, settled, traveled, residents[0].position, residents[1].position, expected])
	if require_both_to_walk:
		observed_postgift_arrivals += 2


func _test_postgift_life(context: String) -> void:
	var original_gift: Variant = _json(game.get("memories").latest(EVENT).event)
	var shelter := game.get_node("ArkRoot/BuiltShelter") as Node3D
	var refuge: Array[Vector3] = [_ark().to_local(shelter.to_global(Vector3(0.5, 0.12, -0.5))), _ark().to_local(shelter.to_global(Vector3(-0.72, 0.12, 0.25)))]
	_normal_conditions()
	# A storm-paused reload may have already walked the first resident into
	# refuge. Walk everyone back out normally before testing a new night entry;
	# an actor already at its daytime point need not pretend to travel again.
	game.call("_update_traveler_schedule")
	game.call("_update_sailmaker_schedule")
	var initial_ordinary: Array[Vector3] = [game.get("traveler_target_position"), game.get("sailmaker_target_position")]
	_walk_postgift_targets(context + "/initial daytime departure", initial_ordinary, false)
	game.set("day_period", 3)
	game.call("_update_traveler_schedule")
	game.call("_update_sailmaker_schedule")
	_walk_postgift_targets(context + "/night", refuge)
	_normal_conditions()
	game.call("_update_traveler_schedule")
	game.call("_update_sailmaker_schedule")
	var ordinary: Array[Vector3] = [game.get("traveler_target_position"), game.get("sailmaker_target_position")]
	_walk_postgift_targets(context + "/daytime return", ordinary)
	game.set("weather_phase", 1)
	game.call("_update_traveler_schedule")
	game.call("_update_sailmaker_schedule")
	_walk_postgift_targets(context + "/storm", refuge)
	_normal_conditions()
	var found := false
	for entry in (game.get("interactables") as Array).duplicate():
		if str(entry.get("id", "")) == "shellfish":
			(game.get("player") as Node3D).global_position = (entry.node as Node3D).global_position
			game.call("_interact")
			found = true
			break
	assert(found and int(game.get("raw_shellfish")) > 0)
	game.call("_interact_hearth")
	assert(int(game.get("stew_servings")) == 1)
	(game.get("player") as Node3D).global_position = shelter.to_global(Vector3(0.15, 0.19, 0.9))
	game.call("_begin_shared_table_meal")
	assert(bool(game.get("shared_meal_gathering_pending")) and not bool(game.get("shared_meal_paused")))
	var meal: Array[Vector3] = [_ark().to_local(shelter.to_global(Vector3(-0.95, 0.12, -0.15))), _ark().to_local(shelter.to_global(Vector3(0.05, 0.12, 0.95)))]
	_walk_postgift_targets(context + "/shared meal", meal)
	assert(bool(game.call("_shared_table_ready")))
	var eat := InputEventKey.new()
	eat.pressed = true
	eat.keycode = KEY_E
	game.call("_unhandled_key_input", eat)
	assert(not bool(game.get("shared_meal_gathering_pending")) and int(game.get("shared_meal_count")) == 1)
	assert(_events() == 1 and _json(game.get("memories").latest(EVENT).event) == original_gift, "post-gift life cannot replay or rewrite the original contribution")
	_assert_awning_supports()


func _observed_step() -> void:
	var before := _resident().position
	var previous_sewing: float = game.get(SEW)
	var previous_install: float = game.get(INSTALL)
	var started := Time.get_ticks_usec()
	game.call("_process", 0.05)
	work_update_usec.append(Time.get_ticks_usec() - started)
	var after := _resident().position
	var movement := _ark().to_global(after) - _ark().to_global(before)
	movement.y = 0.0
	# The last approach step may enter the real arrival tolerance and adopt its
	# stationary work-facing pose in this same update. That is not backward
	# travel; only physically arrived stations get this narrow exception.
	var phase := str(game.get(PHASE))
	var station := _target(phase == "installing")
	var stationed := phase in ["sewing", "installing"] and after.distance_to(station) <= 0.06001 and absf(after.y - station.y) <= 0.02501
	if movement.length() > 0.00001 and not stationed:
		var alignment := _face_front().dot(movement.normalized())
		assert(alignment > 0.05, "real work travel must face its actual displacement instead of walking backward: phase=%s before=%s after=%s sew_dist=%s install_dist=%s front=%s movement=%s dot=%s" % [game.get(PHASE), before, after, after.distance_to(_target()), after.distance_to(_target(true)), _face_front(), movement, alignment])
		observed_forward_steps += 1
	_assert_active_work_geometry()
	assert(_resident().get_parent() == _ark(), "work must remain in the actual ark frame")
	assert(after.distance_to(before) <= 0.11, "real work may not teleport between stations")
	for index in range(1, 5):
		var sample := before.lerp(after, index / 4.0)
		var point := Vector2(sample.x, sample.z)
		assert(bool(game.call("_ark_local_walk_position_supported", point)), "work route cannot cross unsupported sea")
		var clear := _furniture_clear(point)
		assert(not escaped_furniture or clear, "actual sewing/carry route crossed the non-solid Cot or Hearth: " + str(sample))
		escaped_furniture = escaped_furniture or clear
		var wall_clear := not bool(game.call("_ark_local_walk_cell_blocked", point))
		assert(not escaped_wall or wall_clear, "actual work route crossed a wall: " + str(sample))
		escaped_wall = escaped_wall or wall_clear
	if float(game.get(SEW)) > previous_sewing:
		assert(after.distance_to(_target()) <= 0.06001 and absf(after.y - _target().y) <= 0.02501, "sewing credit requires real workstation arrival")
	if float(game.get(INSTALL)) > previous_install:
		assert(after.distance_to(_target(true)) <= 0.06001 and absf(after.y - _target(true).y) <= 0.02501, "installation credit requires real shelter arrival")
	if str(game.get(PHASE)) in ["carrying", "installing"]:
		var cloth := _resident().get_node("OldSailBundle") as MeshInstance3D
		assert(cloth.is_visible_in_tree() and cloth.mesh != null and cloth.position.y > 0.6 and cloth.scale.x > 1.0, "prepared scrap must visibly travel in her hands, not only in an action label")
		assert(cloth.get_parent() == _resident() and cloth.global_position.is_equal_approx(_resident().to_global(cloth.position)))


func _reload_exact() -> void:
	assert(bool(game.call("_save_progress")))
	var before: Dictionary = game.call("_build_save_state")
	var economics := _economic_state()
	# In-place restores must discard runtime-only cached routes as well as fresh
	# scene creation does, without teleporting or duplicating completion facts.
	for _repeat in range(2):
		game.set("sailmaker_routine_route", PackedVector3Array([_resident().position, Vector3(2.4, 0.12, -1.75)]))
		game.set("sailmaker_routine_route_target_set", true)
		game.call("_load_progress")
		assert(not bool(game.get_meta("save_load_blocked", false)))
		assert((game.get("sailmaker_routine_route") as PackedVector3Array).is_empty() and not bool(game.get("sailmaker_routine_route_target_set")), "same-scene load must discard stale route cache")
		var inplace: Dictionary = game.call("_build_save_state")
		for field in [PHASE, SEW, INSTALL, "sailmaker_position", "world_events", "event_sequence"]:
			assert(_json(before[field]) == _json(inplace[field]), "in-place reload must preserve earned work and history: " + field)
	await _drop()
	await _spawn()
	var after: Dictionary = game.call("_build_save_state")
	for field in [PHASE, SEW, INSTALL, "sailmaker_awning_raised", "sailmaker_position", "ark_position", "ark_yaw", "world_events", "event_sequence"]:
		assert(_json(before[field]) == _json(after[field]), "reload must preserve real work and local position without replay: " + field)
	assert(_economic_state() == economics and _json(before.modules.memories) == _json(after.modules.memories))


func _test_interruptions() -> void:
	# Efficient negative cross-matrix: none of these synthetic positions are used
	# as evidence that the positive walking chain works.
	for phase in ["to_sew", "sewing", "carrying", "installing"]:
		for blocker in ["storm", "sailing", "meal", "night", "edit", "damage"]:
			_stage(phase)
			match blocker:
				"storm": game.set("weather_phase", 1)
				"sailing": game.set("sailing_mode", true)
				"meal":
					game.set("shared_meal_gathering_pending", true)
					(game.get("shared_meal_participants") as Array).assign(["player", "sailmaker"])
					assert((game.get("shared_meal_participants") as Array).has("sailmaker"), "typed meal fixture must actually include sailmaker")
				"night": game.set("day_period", 3)
				"edit": game.set("building_mode", true)
				"damage": game.set("shelter_roof_damaged", true)
			game.call("_update_sailmaker_schedule")
			game.call("_update_sailmaker_work_visuals")
			var cloth := _resident().get_node("OldSailBundle") as Node3D
			assert(cloth.visible and cloth.position.y < 0.6, "interrupted work must visibly stow the cloth, not keep installing")
			for arm in ["ArmLeft", "ArmRight"]:
				var resting_arm := _resident().get_node("SailmakerFigure/" + arm) as Node3D
				var torso := _resident().get_node("SailmakerFigure/Body") as Node3D
				assert(absf(resting_arm.rotation.x) < 0.01 and absf(resting_arm.position.y - torso.position.y) < 0.05, "paused resident arms must lower from installation and return to ordinary life")
			_assert_arms_fully_restored()
			var before := _progress()
			_guarded_ticks()
			assert(_progress() == before, "interruption must preserve phase and earned work: %s/%s" % [phase, blocker])
			assert(not bool(game.call("_sailmaker_awning_work_can_run")))
			if blocker == "night":
				assert(str(game.get("sailmaker_action")) == "棚下临时歇脚")
			if blocker == "meal":
				assert(str(game.get("sailmaker_action")) == "收起针线赴饭")
			_normal_conditions()
			assert(bool(game.call("_sailmaker_awning_work_can_run")))
			game.call("_process_sailmaker_awning_work", 0.05)
			assert(_progress() != before or phase in ["to_sew", "carrying"], "unblocked stationed work resumes earned progress")
	_stage("installing")
	game.set("weather_phase", 1)
	game.set("sailing_mode", true)
	var both := _progress()
	_guarded_ticks()
	game.set("weather_phase", 2)
	_guarded_ticks()
	assert(_progress() == both, "removing one blocker cannot bypass another")
	_normal_conditions()


func _test_guarded_arrival_and_time() -> void:
	for phase in ["sewing", "installing"]:
		_stage(phase)
		var before := _progress()
		for delta in [0.0, -1.0, NAN, INF, -INF]:
			game.call("_process_sailmaker_awning_work", delta)
		assert(_progress() == before, "invalid and zero delta cannot poison or credit work")
		game.call("_process_sailmaker_awning_work", 86400.0)
		var timer := SEW if phase == "sewing" else INSTALL
		assert(is_equal_approx(float(game.get(timer)), float(before[1 if phase == "sewing" else 2]) + 0.1), "suspended frame must be capped at 0.1 active seconds")
		_stage(phase)
		before = _progress()
		var true_position := _resident().position
		_resident().reparent(game, false)
		_guarded_ticks()
		assert(_progress() == before, "foreign-parent local coordinates cannot mean arrival")
		_resident().reparent(_ark(), false)
		for offset in [Vector3(0, -1, 0), Vector3(0, 3, 0), Vector3(15, 0, 0)]:
			_resident().position = true_position + offset
			_guarded_ticks()
			assert(_progress() == before, "wrong height or unsupported water cannot mean arrival")
		_resident().position = Vector3(0.0, true_position.y, 1.55)
		game.set("sailmaker_target_position", _resident().position)
		game.set("sailmaker_routine_route", PackedVector3Array())
		game.set("sailmaker_routine_route_target_set", true)
		game.set("sailmaker_routine_route_target", _resident().position)
		game.call("_process_sailmaker_awning_work", 0.05)
		assert(_progress() == before, "safe routine fallback is not the real work facility")
		_resident().position = true_position
		var shelter := game.get_node("ArkRoot/BuiltShelter") as Node3D
		shelter.hide()
		_guarded_ticks()
		assert(_progress() == before, "absent/disabled real structure cannot accept installation")
		shelter.show()
	_stage("installing")
	game.set(INSTALL, 1.95)
	_resident().position = _target() # Completed sewing point is not installation.
	assert(not bool(game.call("_raise_sailmaker_awning")), "direct completion helper must not bypass real work")
	assert(not bool(game.get("sailmaker_awning_raised")) and _events() == 0)


func _blocker(position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_ark().add_child(body)
	body.position = position
	return body


func _test_blocked_routes() -> void:
	_stage("to_sew")
	var position := _resident().position
	# A closed four-wall enclosure excludes any route, without covering the
	# actual station. It tests empty-route false != arrival and bounded retry.
	var walls: Array[StaticBody3D] = []
	for side in [-1.0, 1.0]:
		walls.append(_blocker(position + Vector3(side * 0.42, 0.9, 0), Vector3(0.12, 2.0, 1.05)))
		walls.append(_blocker(position + Vector3(0, 0.9, side * 0.42), Vector3(1.05, 2.0, 0.12)))
	await physics_frame
	await physics_frame
	var route: PackedVector3Array = game.call("_build_ark_local_walk_route", position, _target())
	assert(route.is_empty(), "negative route fixture must really be unreachable")
	var before := _progress()
	var retry_arms := 0
	var countdown_steps := 0
	for _step in range(80):
		var retry_before: float = game.get("sailmaker_awning_route_retry_remaining")
		game.call("_process_sailmaker_awning_work", 0.05)
		var retry_after: float = game.get("sailmaker_awning_route_retry_remaining")
		if retry_after > retry_before:
			retry_arms += 1
		elif retry_before > 0.06:
			assert(is_equal_approx(retry_before - retry_after, 0.05), "unreachable routes must count down instead of rebuilding each frame")
			countdown_steps += 1
	assert(retry_arms >= 2 and retry_arms <= 9 and countdown_steps > 40, "route retries must be bounded around the half-second cadence, not per frame")
	print("SAILMAKER_RETRY_DIAGNOSTIC: 80 guarded 0.05s updates, retries=", retry_arms, " countdown-only=", countdown_steps)
	assert(_progress() == before and _resident().position.is_equal_approx(position), "empty routes cannot sew remotely")
	for wall in walls:
		wall.queue_free()
	await physics_frame
	await physics_frame
	# Deliberately do NOT clear the cached empty path. Runtime must retry.
	_guarded_ticks(15)
	assert(_resident().position.distance_to(position) > 0.02, "temporary obstruction must recover by bounded retry without external cache reset")
	for phase in ["sewing", "installing"]:
		_stage(phase)
		var endpoint := _target(phase == "installing")
		var body := _blocker(endpoint + Vector3(0, 0.9, 0), Vector3(0.35, 2, 0.35))
		await physics_frame
		await physics_frame
		before = _progress()
		assert(not bool(game.call("_sailmaker_at_awning_work_target", endpoint)))
		_guarded_ticks()
		assert(_progress() == before, "grid's forced clear end-cell cannot make a physically blocked station valid")
		body.queue_free()
		await physics_frame
		await physics_frame
		game.call("_process_sailmaker_awning_work", 0.05)
		assert(_progress() != before, "cleared endpoint must resume without losing earned work")


func _test_save_rejection() -> void:
	_stage("sewing")
	assert(bool(game.call("_save_progress")))
	var valid: Dictionary = game.call("_build_save_state")
	var path: String = saver.get_save_path()
	var primary := FileAccess.get_file_as_string(path)
	var backup := FileAccess.get_file_as_string(path + ".backup") if FileAccess.file_exists(path + ".backup") else ""
	var malformed: Array[Dictionary] = []
	for field in [SEW, INSTALL]:
		for bad in [-0.1, 9.0, NAN, INF, "0.4", true, null]:
			var state := valid.duplicate(true)
			state[field] = bad
			malformed.append(state)
	for phase in ["unknown", "complete", "carrying", "to_sew", "unstarted", 1, null]:
		var state := valid.duplicate(true)
		state[PHASE] = phase
		malformed.append(state)
	for field in [PHASE, SEW, INSTALL]:
		var missing := valid.duplicate(true)
		missing.erase(field)
		malformed.append(missing)
	for field in ["sailmaker_met", "sailmaker_boarded", "shelter_built"]:
		var invalid := valid.duplicate(true)
		invalid[field] = false
		malformed.append(invalid)
	var premature := valid.duplicate(true)
	premature.sailmaker_joined_day = premature.day_count
	malformed.append(premature)
	var forged := valid.duplicate(true)
	forged.sailmaker_awning_raised = true
	malformed.append(forged)
	for bad in malformed:
		assert(not bool(saver.save_state(bad).get("ok", true)), "malformed progress must be rejected atomically: " + str(bad.get(PHASE)))
		assert(FileAccess.get_file_as_string(path) == primary, "rejected progress cannot replace good primary")
		assert((FileAccess.get_file_as_string(path + ".backup") if FileAccess.file_exists(path + ".backup") else "") == backup, "rejected progress cannot rotate good backup")
	assert(int(valid.schema_version) == 36 and Save.MAX_SCHEMA_VERSION == 36 and Save.VERSION == 1)


func _test_real_meal_interrupt() -> void:
	_stage("sewing")
	# Existing finite shellfish -> existing cooking -> one reserved serving.
	var found := false
	for entry in (game.get("interactables") as Array).duplicate():
		if str(entry.get("id", "")) == "shellfish":
			(game.get("player") as Node3D).global_position = (entry.node as Node3D).global_position
			game.call("_interact")
			found = true
			break
	assert(found and int(game.get("raw_shellfish")) > 0)
	game.call("_interact_hearth")
	assert(int(game.get("stew_servings")) == 1)
	var shelter: Vector3 = game.get("shelter_position")
	(game.get("player") as Node3D).global_position = _ark().to_global(shelter + Vector3(0.15, 0.19, 0.9))
	game.call("_begin_shared_table_meal")
	assert(bool(game.get("shared_meal_gathering_pending")) and not bool(game.get("shared_meal_paused")))
	var before := _progress()
	for _step in range(400):
		game.call("_process", 0.05)
		assert(_progress() == before, "a real reserved meal must take priority over stationed sewing")
	assert(bool(game.call("_shared_table_ready")) and int(game.get("stew_servings")) == 0)
	await _reload_exact()
	assert(bool(game.call("_shared_table_ready")) and _progress() == before)
	var eat := InputEventKey.new()
	eat.pressed = true
	eat.keycode = KEY_E
	game.call("_unhandled_key_input", eat)
	assert(int(game.get("shared_meal_count")) == 1 and _events("resident_meal_shared") == 1 and not bool(game.get("shared_meal_gathering_pending")))
	assert(bool(game.call("_sailmaker_awning_work_can_run")))
	for _step in range(80):
		game.call("_process", 0.05)
	assert(float(game.get(SEW)) > float(before[1]) or str(game.get(PHASE)) in ["carrying", "installing", "complete"], "after actual eating the interrupted work must resume")


func _observed_chain(reload_phases: bool) -> void:
	installation_facing_samples.clear()
	_reset_geometry_guard()
	var economy := _economic_state()
	var phases: Array[String] = []
	var reloaded: Array[String] = []
	var carrying_distance := 0.0
	for step in range(850):
		var phase := str(game.get(PHASE))
		if not phases.has(phase):
			phases.append(phase)
		if bool(game.get("sailmaker_awning_raised")):
			break
		var before := _resident().position
		_observed_step()
		if phase == "carrying":
			carrying_distance += _resident().position.distance_to(before)
		if reload_phases and not reloaded.has(phase) and ((phase == "sewing" and float(game.get(SEW)) > 0.5) or (phase == "carrying" and carrying_distance > 0.2) or (phase == "installing" and float(game.get(INSTALL)) > 0.4)):
			reloaded.append(phase)
			# Interrupt genuinely earned progress, persist it while paused, and
			# confirm actual scene processing remains paused after reconstruction.
			game.set("weather_phase", 1)
			var paused := _progress()
			for _pause_step in range(5):
				game.call("_process", 0.05)
			assert(_progress() == paused)
			await _reload_exact()
			for _pause_step in range(5):
				game.call("_process", 0.05)
			assert(_progress() == paused and (_resident().get_node("OldSailBundle") as Node3D).position.y < 0.6, "paused restore changed progress/pose: before=%s after=%s weather=%s cloth_y=%s" % [paused, _progress(), game.get("weather_phase"), (_resident().get_node("OldSailBundle") as Node3D).position.y])
			game.set("weather_phase", 2)
			game.call("_update_sailmaker_schedule")
			_reset_geometry_guard()
	assert(bool(game.get("sailmaker_awning_raised")), "bounded ordinary ticks must finish real sewing/carry/install; phase=%s position=%s target=%s" % [game.get(PHASE), _resident().position, game.get("sailmaker_target_position")])
	assert(phases.has("sewing") and phases.has("carrying") and phases.has("installing") and carrying_distance > 0.5, "completed mesh alone is not evidence of a physical work chain")
	assert(not reload_phases or reloaded.size() == 3, "all three genuinely reached active phases must survive save/reload")
	assert(escaped_furniture and escaped_wall and _economic_state() == economy)
	assert(game.get(PHASE) == "complete" and game.get(SEW) == 0.0 and game.get(INSTALL) == 0.0)
	assert(_events() == 1 and game.get_node_or_null("ArkRoot/BuiltShelter/SailmakerAwning/PatchedCanvas") is MeshInstance3D)
	var installed := game.get_node("ArkRoot/BuiltShelter/SailmakerAwning/PatchedCanvas") as MeshInstance3D
	_assert_completed_canvas_clearance(installed)
	_assert_arms_fully_restored()
	_assert_awning_supports()
	if completed_awning_shape.is_empty():
		completed_awning_shape = _awning_shape()
	else:
		assert(_awning_shape() == completed_awning_shape)
	assert(installation_facing_samples.size() > 10, "installation orientation needs actual multi-frame evidence")
	for sample in installation_facing_samples:
		var toward_actual_awning := installed.global_position - (sample.origin as Vector3)
		toward_actual_awning.y = 0.0
		assert(toward_actual_awning.length() > 0.05 and (sample.front as Vector3).dot(toward_actual_awning.normalized()) > 0.95, "installation must face the actual transformed awning mesh, not a hardcoded world direction or inherited travel yaw")
		var nearest_cloth_gap := INF
		var canvas_bounds := installed.get_aabb()
		for corner in sample.cloth_corners as PackedVector3Array:
			var closest := installed.to_local(corner).clamp(canvas_bounds.position, canvas_bounds.end)
			nearest_cloth_gap = minf(nearest_cloth_gap, corner.distance_to(installed.to_global(closest)))
		assert(nearest_cloth_gap <= 0.08, "held installation cloth must actually reach the final raised canvas, not float far below it")
	assert(not (_resident().get_node("OldSailBundle") as Node3D).visible, "prepared cloth becomes the single installed gift")
	var event: Dictionary = game.get("memories").latest(EVENT).event
	assert(event.facts.resident_id == "sailmaker" and event.facts.source_material == "personal_sail_scrap" and int(event.facts.wood_spent) == 0)
	for _step in range(80):
		game.call("_process", 0.05)
	assert(_events() == 1 and _economic_state() == economy and str(game.get("sailmaker_action")) == "缝补旧帆")
	if reload_phases:
		await _reload_exact()
		await _reload_exact()
	assert(_events() == 1 and game.find_children("SailmakerAwning", "Node3D", true, false).size() == 1 and game.find_children("SailmakerAwningInteractable", "Node3D", true, false).size() == 1)
	var interactions := 0
	for entry in game.get("interactables") as Array:
		if str(entry.get("id", "")) == "sailmaker_awning":
			interactions += 1
	assert(interactions == 1 and bool(game.get("economy").audit().ok))


func _test_migration(completed: Dictionary) -> void:
	for original in [eligible, completed]:
		var legacy: Dictionary = original.duplicate(true)
		legacy.schema_version = 35
		for field in [PHASE, SEW, INSTALL]:
			legacy.erase(field)
		var before_events: Variant = _json(legacy.world_events)
		await _load_state(legacy)
		assert(_json(game.get("world_events")) == before_events, "migration cannot invent historical sewing, carrying or completion")
		assert(game.get(PHASE) == ("complete" if bool(legacy.sailmaker_awning_raised) else "unstarted"))
		assert(game.get(SEW) == 0.0 and game.get(INSTALL) == 0.0)
		assert((game.get_node_or_null("ArkRoot/BuiltShelter/SailmakerAwning") != null) == bool(legacy.sailmaker_awning_raised))
		if bool(legacy.sailmaker_awning_raised):
			assert(_awning_shape() == completed_awning_shape, "legacy completed saves must reconstruct current safe geometry without rewriting the contribution event")
			_test_postgift_life("legacy completed rebuild")
		await _reload_exact()
	var ancient := eligible.duplicate(true)
	ancient.schema_version = 14
	for field in [PHASE, SEW, INSTALL, "sailmaker_met", "sailmaker_boarded", "sailmaker_joined_day", "sailmaker_awning_raised", "sailmaker_position"]:
		ancient.erase(field)
	ancient.world_events = []
	ancient.event_sequence = 0
	await _load_state(ancient)
	_guarded_ticks(100)
	assert(not bool(game.get("sailmaker_boarded")) and not bool(game.get("sailmaker_awning_raised")) and game.get(PHASE) == "unstarted" and _events() == 0)


func _prepare_eligible(origin: Vector3) -> void:
	# Genuine finite source and paid shelter; never seed awning materials.
	var source := game.get_node("DriftwoodNear") as Node3D
	(game.get("player") as Node3D).global_position = source.global_position
	game.call("_interact")
	assert("DriftwoodNear" in game.get("collected_ids") and int(game.get("wood")) >= 3)
	(game.get("player") as Node3D).global_position = _ark().to_global(Vector3(0, 1.1, 1.75))
	assert(bool(game.call("_try_place_shelter", origin)))
	game.set("sailmaker_met", true)
	game.set("sailmaker_choice_pending", true)
	game.call("_choose_sailmaker_boarding", false)
	_guarded_ticks()
	assert(not bool(game.get("sailmaker_boarded")) and _events() == 0)
	game.set("sailmaker_choice_pending", true)
	game.call("_choose_sailmaker_boarding", true)
	for name in ["ArmLeft", "ArmRight"]:
		resting_arm_transforms[name] = (_resident().get_node("SailmakerFigure/" + name) as Node3D).transform
	game.set("weather_phase", 2)
	_guarded_ticks(100)
	assert(game.get(PHASE) == "unstarted" and _events() == 0, "joining day is not next-day eligibility")
	for _period in range(4):
		var key := InputEventKey.new()
		key.pressed = true
		key.keycode = KEY_T
		game.call("_unhandled_key_input", key)
	assert(int(game.get("day_count")) == 2 and not bool(game.get("sailmaker_awning_raised")) and _events() == 0)
	assert(game.get_node_or_null("ArkRoot/BuiltShelter/SailmakerAwning") == null and game.get(SEW) == 0.0 and game.get(INSTALL) == 0.0, "dawn alone does no physical work")
	# Admit the existing first resident after dawn, avoiding a synthetic gather
	# reservation while still benchmarking the true two-resident scene process.
	game.set("resident_met", true)
	game.set("traveler_choice_pending", true)
	game.call("_choose_traveler_boarding", true)
	assert(bool(game.get("traveler_boarded")) and bool(game.get("sailmaker_boarded")))


func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/test_sailmaker_work_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]).simplify_path()
	assert(Paths.is_safe_save_root(save_root))
	print("SAILMAKER_SAVE_ROOT: ", save_root)
	saver = Save.new(save_root)
	await _spawn()
	_prepare_eligible(Vector3.ZERO)
	eligible = game.call("_build_save_state")
	await physics_frame
	_test_interruptions()
	_test_guarded_arrival_and_time()
	await _test_blocked_routes()
	_test_save_rejection()
	await _load_state(eligible)
	await _test_real_meal_interrupt()
	await _load_state(eligible)
	# Player away, moved/turned ark, explicit phase reloads: no proximity gate.
	_ark().position = Vector3(16, 0, 9)
	_ark().rotation.y = 0.65
	(game.get("player") as Node3D).global_position = Vector3(35, 1.1, 35)
	await physics_frame
	await _observed_chain(true)
	var completed: Dictionary = game.call("_build_save_state")
	_test_postgift_life("default")
	await _test_migration(completed)
	await _drop()
	saver.clear_for_test()
	await _spawn()
	# Construct the shifted layout through the real finite-resource build path;
	# no geometry-only edits or contradictory construction mirrors.
	_prepare_eligible(Vector3(-0.5, 0.12, 0))
	_ark().position = Vector3(-12, 0, 6)
	_ark().rotation.y = -0.45
	await physics_frame
	await _observed_chain(true)
	_test_postgift_life("shifted")
	assert(observed_postgift_arrivals == 24 and observed_postgift_clearance_checks > 1000)
	print("SAILMAKER_POSTGIFT_CLEARANCE: ", observed_postgift_arrivals, " real resident arrivals; ", observed_postgift_clearance_checks, " moving/settled head checks; night/day/storm/shared meal on default/legacy-completed/shifted builds")
	assert(observed_front_frames > 100 and observed_forward_steps > 100, "visual orientation checks must observe genuine work, not a single posed frame")
	print("SAILMAKER_FRONT_GEOMETRY: active front/hand frames=", observed_front_frames, " forward-facing travel steps=", observed_forward_steps, "; actual Face/Body/Arm/cloth/spool and final awning transforms")
	assert(observed_completion_clearance_checks == 16, "default and shifted fixtures must both inspect four head/face volumes at real completion and across arrival tolerance")
	print("SAILMAKER_COMPLETION_CLEARANCE: ", observed_completion_clearance_checks, " actual and tolerance-expanded head/hair/face versus transformed final canvas checks")
	work_update_usec.sort()
	assert(not work_update_usec.is_empty())
	print("SAILMAKER_UPDATE_TIMING: headless two-resident scene _process updates only; samples=%d p50_ms=%.3f p95_ms=%.3f max_ms=%.3f; includes phase-save/I-O cost; not FPS or rendered performance" % [work_update_usec.size(), work_update_usec[work_update_usec.size() / 2] / 1000.0, work_update_usec[int((work_update_usec.size() - 1) * 0.95)] / 1000.0, work_update_usec.back() / 1000.0])
	await _drop()
	saver.clear_for_test()
	print("ARK_SAILMAKER_WORK_TEST_OK: real finite setup/dawn-only eligibility; observed sewing/carry/install and three-phase storm-paused fresh/in-place reloads; real meal priority/E/resume; 24 interruption fixtures; guarded arrival/parent/height/endpoint/no-path/retry; Cot/Hearth sampled routes; actual face/cloth/hands/travel/install orientation, fixed shoulders, completion and both-resident post-gift head clearance; bounded time; atomic schema36 rejection; legacy14/35; one gift/mesh/interaction and unchanged economy")
	quit(0)
