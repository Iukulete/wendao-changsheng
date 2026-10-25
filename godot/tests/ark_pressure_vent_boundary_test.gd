extends SceneTree

## Independent fairness oracle: actual transformed mesh vertices and actual
## player health, not the runtime's center helper or a visible flag alone.
const Paths = preload("res://tests/ark_test_paths.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
const RADIUS := 2.9
const WINDUP := 1.4
const COOLDOWN := 5.5
const EDGE_MARGIN := 0.05
var game: Node3D
var saver: RefCounted
var save_root: String
var geometry_samples := 0
var damage_samples := 0


func _initialize() -> void:
	_run.call_deferred()


func _spawn() -> void:
	game = load("res://scenes/ark_greybox.tscn").instantiate() as Node3D
	game.set("save_root_override", save_root)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	# Boundary fixtures do not need repeated disk writes. The existing pressure
	# galley integration separately verifies the real salvage/save/reload chain.
	game.set("save_service", null)
	await physics_frame


func _drop() -> void:
	game.queue_free()
	await process_frame
	saver.clear_for_test()


func _player() -> CharacterBody3D:
	return game.get("player") as CharacterBody3D


func _source() -> Node3D:
	return game.get_node("PressureWreck/BentVent") as Node3D


func _xz(value: Vector3) -> Vector2:
	return Vector2(value.x, value.z)


func _events(id: String) -> int:
	var count := 0
	for event in game.get("world_events") as Array:
		if str(event.get("id", "")) == id:
			count += 1
	return count


func _last_event(id: String) -> Dictionary:
	var events: Array = game.get("world_events")
	for index in range(events.size() - 1, -1, -1):
		if str(events[index].get("id", "")) == id:
			return events[index]
	return {}


func _inventory() -> Dictionary:
	# Whole conservation ledger: all finite sources, player/storage inventories,
	# carried payloads and receipts must remain unchanged by a vent hit.
	return game.get("economy").snapshot()


func _reset_vent() -> void:
	game.set("pressure_vent_warning_active", false)
	game.set("pressure_vent_warning_remaining", 0.0)
	game.set("pressure_vent_cooldown_remaining", 0.0)
	game.set("pressure_vent_burst_remaining", 0.0)
	game.set("is_swimming", false)
	game.set("sailing_mode", false)
	game.set("player_health", 4)
	game.call("_clear_player_knockback")
	_player().velocity = Vector3.ZERO


func _world_ring_vertices() -> PackedVector3Array:
	var ring := game.get_node("PressureWreck/VentWarningRing") as MeshInstance3D
	assert(ring.mesh != null and ring.mesh.get_surface_count() > 0, "the warning must contain actual renderable boundary geometry")
	var world := PackedVector3Array()
	for surface in range(ring.mesh.get_surface_count()):
		var vertices: PackedVector3Array = ring.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			world.append(ring.global_transform * vertex)
	assert(world.size() >= 32, "the warning must have a complete world-space boundary, not only a light or visibility flag")
	return world


func _assert_boundary(check_ground: bool = true) -> PackedVector3Array:
	var center := _xz(_source().global_position)
	var vertices := _world_ring_vertices()
	var minimum_radius := INF
	var maximum_radius := 0.0
	for vertex in vertices:
		var distance := _xz(vertex).distance_to(center)
		minimum_radius = minf(minimum_radius, distance)
		maximum_radius = maxf(maximum_radius, distance)
		if check_ground:
			assert(vertex.y <= 0.25, "the warning must mark the ground rather than float up on the boiler")
			if distance >= RADIUS - 0.01:
				assert(vertex.y >= 0.041, "the actual outer danger edge must sit visibly above the island plateau; the torus underside may be embedded")
	assert(minimum_radius >= 2.65 and maximum_radius <= RADIUS + 0.015, "actual geometry must form a thin inward band around the 2.9m danger edge")
	for index in range(8):
		var direction := Vector2.from_angle(TAU * float(index) / 8.0)
		var support := -INF
		var opposite := -INF
		for vertex in vertices:
			var offset := _xz(vertex) - center
			support = maxf(support, offset.dot(direction))
			opposite = maxf(opposite, offset.dot(-direction))
		assert(absf(support - RADIUS) <= 0.025 and absf(opposite - RADIUS) <= 0.025, "all cardinal/diagonal visible edges must match the actual source-centered 2.9m damage circle")
		assert(absf(support - opposite) <= 0.015, "opposed visible edges must be centered on the actual transformed BentVent")
	geometry_samples += 1
	return vertices


func _pulse_geometry() -> void:
	_reset_vent()
	# Explicit setup for geometry observation, not traversal evidence.
	_player().global_position = _source().global_position + Vector3(3.3, -1.0, 0.0)
	game.call("_process_pressure_vent", 0.0)
	var ring := game.get_node("PressureWreck/VentWarningRing") as MeshInstance3D
	assert(ring.is_visible_in_tree() and bool(game.get("pressure_vent_warning_active")), "the full ring must become visible during the warning")
	var reference := _assert_boundary()
	var low_brightness := INF
	var high_brightness := -INF
	for remaining in [1.4, 1.27, 1.12, 0.91, 0.66, 0.39, 0.14]:
		game.set("pressure_vent_warning_remaining", remaining)
		game.call("_refresh_pressure_vent_visual")
		var current := _assert_boundary()
		assert(current.size() == reference.size(), "warning pulse must not replace or reduce the boundary")
		for index in range(current.size()):
			assert(current[index].distance_to(reference[index]) < 0.0001, "brightness pulse must never move the promised safe/danger boundary")
		var material := ring.get_active_material(0) as StandardMaterial3D
		assert(material != null, "the visible danger ring needs an actual material")
		var brightness := material.emission_energy_multiplier * material.emission.get_luminance() + material.albedo_color.get_luminance()
		low_brightness = minf(low_brightness, brightness)
		high_brightness = maxf(high_brightness, brightness)
	assert(high_brightness - low_brightness > 0.1, "warning urgency must pulse actual material brightness without changing radius")


func _damage_matrix() -> void:
	var center := _source().global_position
	for index in range(8):
		var direction := Vector2.from_angle(TAU * float(index) / 8.0)
		for inside in [true, false]:
			_reset_vent()
			var distance := RADIUS - EDGE_MARGIN if inside else RADIUS + EDGE_MARGIN
			# Explicit negative/boundary fixture placement. Positive retreat below
			# uses actual WASD physics and never assigns positions during the dodge.
			_player().global_position = Vector3(center.x + direction.x * distance, 1.1, center.z + direction.y * distance)
			var inventory_before := _inventory()
			var hits_before := _events("pressure_vent_hit")
			var bursts_before := _events("pressure_vent_burst")
			game.call("_process_pressure_vent", 0.0)
			var warning_facts: Dictionary = _last_event("pressure_vent_warning").get("facts", {})
			var observer: Dictionary = warning_facts.get("position", {})
			var warning_source: Dictionary = warning_facts.get("source_position", {})
			assert(Vector2(float(observer.get("x", -999.0)), float(observer.get("z", -999.0))).distance_to(_xz(_player().global_position)) < 0.015, "warning position must preserve its historical player-position meaning")
			assert(Vector2(float(warning_source.get("x", -999.0)), float(warning_source.get("z", -999.0))).distance_to(_xz(center)) < 0.015, "warning source evidence must identify the separately named real vent")
			_assert_boundary(false)
			game.call("_process_pressure_vent", WINDUP - 0.01)
			assert(int(game.get("player_health")) == 4 and _events("pressure_vent_burst") == bursts_before, "no direction may deal damage before the full 1.4s warning")
			game.call("_process_pressure_vent", 0.02)
			assert(int(game.get("player_health")) == (3 if inside else 4), "actual damage must agree with the visible circle on both sides of all eight directions")
			assert(_events("pressure_vent_hit") == hits_before + (1 if inside else 0) and _events("pressure_vent_burst") == bursts_before + 1, "each burst must produce exactly the expected hit, not just a visual warning")
			assert(_inventory() == inventory_before and bool(game.get("economy").audit().get("ok", false)), "recoverable vent contact must preserve the entire finite-resource economy, including inventory and unique stock")
			if inside:
				var hit_facts: Dictionary = _last_event("pressure_vent_hit").get("facts", {})
				var hit_position: Dictionary = hit_facts.get("position", {})
				var hit_source: Dictionary = hit_facts.get("source_position", {})
				assert(int(hit_facts.get("damage", 0)) == 1 and not bool(hit_facts.get("inventory_lost", true)), "hit facts must retain exactly one recoverable damage without inventory loss")
				assert(Vector2(float(hit_position.get("x", -999.0)), float(hit_position.get("z", -999.0))).distance_to(_xz(_player().global_position)) < 0.015, "hit position must identify the player that was actually hit")
				assert(Vector2(float(hit_source.get("x", -999.0)), float(hit_source.get("z", -999.0))).distance_to(_xz(center)) < 0.015, "hit source_position must identify the separate actual vent")
			var facts: Dictionary = _last_event("pressure_vent_burst").get("facts", {})
			var position: Dictionary = facts.get("position", {})
			assert(_xz(Vector3(float(position.get("x", -999.0)), 0.0, float(position.get("z", -999.0)))).distance_to(_xz(center)) < 0.015, "burst evidence must identify the actual transformed physical source, not the old constant center")
			assert(is_equal_approx(float(facts.get("radius", 0.0)), RADIUS), "burst evidence must retain the fixed 2.9m world radius")
			damage_samples += 1


func _cooldown_and_push() -> void:
	_reset_vent()
	var center := _source().global_position
	_player().global_position = Vector3(center.x + 2.0, 0.12, center.z)
	game.call("_process_pressure_vent", 0.0)
	game.call("_process_pressure_vent", WINDUP)
	assert(int(game.get("player_health")) == 3 and is_equal_approx(float(game.get("pressure_vent_cooldown_remaining")), COOLDOWN), "one hit must retain the 5.5s cooldown")
	var before := _player().global_position
	var bursts := _events("pressure_vent_burst")
	for _step in range(10):
		await physics_frame
		game.call("_physics_process", 1.0 / 60.0)
	assert(_player().global_position.x - before.x > 0.25, "a surviving vent hit must physically push the player away over subsequent movement frames")
	var warnings := _events("pressure_vent_warning")
	var remaining := float(game.get("pressure_vent_cooldown_remaining"))
	game.call("_process_pressure_vent", remaining - 0.01)
	assert(not bool(game.get("pressure_vent_warning_active")) and _events("pressure_vent_warning") == warnings and _events("pressure_vent_burst") == bursts and int(game.get("player_health")) == 3, "cooldown must prevent duplicate warning, damage or burst")
	game.call("_process_pressure_vent", 0.02)
	assert(bool(game.get("pressure_vent_warning_active")) and is_equal_approx(float(game.get("pressure_vent_warning_remaining")), WINDUP), "cooldown expiry must start a fresh full warning instead of an immediate hit")


func _set_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _physical_retreat() -> void:
	_reset_vent()
	game.set("cold_exposure_level", 0)
	game.set("cold_exposure", false)
	var center := _xz(_source().global_position)
	# Setup starts outside the danger circle. From here through the burst all
	# player displacement is real input -> _physics_process -> move_and_slide.
	_player().global_position = Vector3(center.x + 3.25, 0.12, center.y)
	var start := _player().global_position
	var hits := _events("pressure_vent_hit")
	var bursts := _events("pressure_vent_burst")
	_set_key(KEY_SHIFT, false)
	_set_key(KEY_A, true)
	game.set_physics_process(true)
	var inward_frames := 0
	while inward_frames < 50 and _xz(_player().global_position).distance_to(center) > 2.80:
		await physics_frame
		inward_frames += 1
	_set_key(KEY_A, false)
	assert(inward_frames < 50 and start.x - _player().global_position.x >= 0.4, "ordinary walking must physically cross from outside to inside the visible danger boundary")
	assert(bool(game.get("pressure_vent_warning_active")) and float(game.get("pressure_vent_warning_remaining")) > 0.65 and int(game.get("player_health")) == 4, "a walking player must still have a meaningful part of the original windup left to react")
	var turn_position := _player().global_position
	_set_key(KEY_D, true)
	var retreat_frames := 0
	while retreat_frames < 50 and _xz(_player().global_position).distance_to(center) < 3.25:
		await physics_frame
		retreat_frames += 1
	_set_key(KEY_D, false)
	assert(retreat_frames < 50 and _player().global_position.x - turn_position.x >= 0.4, "ordinary reverse input must physically retreat beyond the unchanged circle")
	assert(bool(game.get("pressure_vent_warning_active")) and float(game.get("pressure_vent_warning_remaining")) > 0.0, "the player must cross into safety before the warning expires, not be rescued after damage")
	var waited := 0
	while waited < 100 and _events("pressure_vent_burst") == bursts:
		await physics_frame
		waited += 1
	game.set_physics_process(false)
	assert(waited < 100 and _events("pressure_vent_burst") == bursts + 1 and _events("pressure_vent_hit") == hits and int(game.get("player_health")) == 4, "a physically walked retreat beyond the visible boundary must avoid the real burst")
	assert(_xz(_player().global_position).distance_to(center) > RADIUS, "the successful dodge must end at an actually safe position")
	print("STEAM_PHYSICAL_RETREAT: inward_frames=%d retreat_frames=%d wait_frames=%d start=%s turn=%s end=%s" % [inward_frames, retreat_frames, waited, start, turn_position, _player().global_position])


func _missing_source(node_path: String, queued: bool, during_burst: bool = false) -> void:
	_reset_vent()
	_player().global_position = _source().global_position
	game.call("_process_pressure_vent", 0.0)
	if during_burst:
		game.call("_process_pressure_vent", WINDUP)
	var source := game.get_node(node_path) as Node3D
	var parent := source.get_parent()
	var ring := game.get_node("PressureWreck/VentWarningRing") as MeshInstance3D
	var steam := game.get_node("PressureWreck/SteamBurst") as GPUParticles3D
	var health := int(game.get("player_health"))
	var economy_before := _inventory()
	var events := [_events("pressure_vent_warning"), _events("pressure_vent_burst"), _events("pressure_vent_hit")]
	if queued:
		source.queue_free()
	else:
		parent.remove_child(source)
	# A queued node still exists this frame. The hazard must reject it now,
	# before deferred deletion, and not merely recover next frame.
	game.call("_process_pressure_vent", WINDUP)
	assert(not bool(game.get("pressure_vent_warning_active")) and float(game.get("pressure_vent_warning_remaining")) == 0.0 and float(game.get("pressure_vent_burst_remaining")) == 0.0, "absent/queued real sources must cancel all transient vent effects immediately")
	assert(not ring.is_inside_tree() or (not ring.visible and not steam.emitting), "invalid source must remove its effects from the render tree or hide its retained warning and stop existing particles")
	game.call("_process_pressure_vent", 20.0)
	assert(int(game.get("player_health")) == health and [_events("pressure_vent_warning"), _events("pressure_vent_burst"), _events("pressure_vent_hit")] == events, "missing or queued physical source must never cause phantom warning, damage or burst")
	assert(_inventory() == economy_before, "missing hazard source must not change finite stock, unique reward or player inventory")
	if not queued:
		parent.add_child(source)
	else:
		await process_frame
	print("STEAM_SOURCE_FAIL_CLOSED: path=%s queued=%s during_burst=%s" % [node_path, queued, during_burst])


func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/test_pressure_vent_boundary_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]).simplify_path()
	assert(Paths.is_safe_save_root(save_root), "boundary acceptance must use a unique repository-local throwaway save")
	saver = Save.new(save_root)
	saver.clear_for_test()
	await _spawn()
	assert(Save.MAX_SCHEMA_VERSION == 43 and str(ProjectSettings.get_setting("application/config/version")) == "0.1.003", "warning fairness remains compatible with kitchen schema43 and the unchanged game version")
	_pulse_geometry()
	_damage_matrix()
	await _cooldown_and_push()
	await _physical_retreat()
	var wreck := game.get_node("PressureWreck") as Node3D
	# Explicit transform fixtures: these are not claimed as normal travel.
	wreck.position = Vector3(46.0, 0.2, 41.0)
	wreck.rotation.y = 1.08
	wreck.scale = Vector3(1.6, 0.75, 0.65)
	_source().position += Vector3(0.7, 0.2, -0.45)
	_reset_vent()
	_player().global_position = Vector3(93.65, 1.1, 85.88)
	var warnings := _events("pressure_vent_warning")
	game.call("_process_pressure_vent", 20.0)
	assert(not bool(game.get("pressure_vent_warning_active")) and _events("pressure_vent_warning") == warnings, "the old constant center must stop being hazardous when the actual source moves")
	_damage_matrix()
	await _drop()
	for node_path in ["PressureWreck/BentVent", "PressureWreck"]:
		for queued in [false, true]:
			await _spawn()
			await _missing_source(node_path, queued)
			await _drop()
	await _spawn()
	await _missing_source("PressureWreck/BentVent", false, true)
	await _drop()
	DirAccess.remove_absolute(save_root)
	print("ARK_PRESSURE_VENT_BOUNDARY_TEST_OK: geometry_samples=%d damage_samples=%d actual-mesh actual-health physical-retreat transformed-source missing-and-queued-fail-closed" % [geometry_samples, damage_samples])
	quit(0)
