extends SceneTree

## Native production integration contract. Uses only repository resources and
## unique test saves; never loads the frozen external QA helper or personal slots.
## The old-floor shoulder case is a SYNTHETIC legacy-geometry-supported save made
## through the real serializer, not a recovered historical/user save. Historical
## actual-save evidence and the raw outer-lip traversal exit42 remain unchanged.
const Paths = preload("res://tests/ark_test_paths.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
const LegacyLandmass = preload("res://scripts/ark_landmass_builder.gd")
const Scene = preload("res://scenes/ark_greybox.tscn")
# Synthetic support-height seam: execute the actual production refresh method
# with native nodes and the unchanged real water authority, not a copied method.
class BoundaryWorld:
	extends Node3D
	var water: RefCounted

class BoundaryCoast:
	extends "res://scripts/terrain/ark_opening_coast.gd"
	var supplied_heights: Array = []
	var sample_index := 0
	func sample_height(_world_position: Vector3) -> Variant:
		var result: Variant = supplied_heights[sample_index % supplied_heights.size()]
		sample_index += 1
		return result

const RESOURCE_NAMES := ["DriftwoodShore", "DriftwoodRidge", "TidalShellsNear", "TidalShellsCove"]
var game: Node3D
var coast: RefCounted
var saves: RefCounted
var save_root: String
var failures := 0
var checks := 0
var keys: Dictionary = {}
var observations: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error("OPENING_COAST_LIFECYCLE: " + label)
	return ok

func _player() -> CharacterBody3D:
	return game.get("player") as CharacterBody3D

func _freeze() -> void:
	game.set_process(false)
	game.set_physics_process(false)
	_player().set_physics_process(false)

func _resume() -> void:
	game.set_process(true)
	game.set_physics_process(true)

func _settle() -> void:
	await process_frame
	await physics_frame
	await process_frame

func _step(frames: int) -> void:
	for _index in range(frames):
		await physics_frame

func _spawn() -> void:
	# Deliberately synchronous: callers inspect immediately after _ready, BEFORE
	# this SceneTree yields its first player physics frame.
	game = Scene.instantiate() as Node3D
	game.set("save_root_override", save_root)
	root.add_child(game)
	_freeze()
	coast = game.get("opening_coast") as RefCounted
	_check(coast != null, "normal scene owns its production coast module")
	_check(not game.get_meta("save_load_blocked", false), "valid fresh/test save loads without a blocker")

func _drop() -> void:
	_release()
	if is_instance_valid(game):
		game.set("save_service", null)
		if current_scene == game:
			current_scene = null
		game.queue_free()
	game = null
	coast = null
	await _settle()

func _key(code: Key, pressed: bool) -> void:
	if keys.get(code, false) == pressed:
		return
	keys[code] = pressed
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _tap(code: Key) -> void:
	_key(code, true)
	_key(code, false)

func _release() -> void:
	for code in [KEY_A, KEY_D, KEY_W, KEY_S, KEY_SHIFT, KEY_SPACE, KEY_E]:
		_key(code, false)

func _state() -> Dictionary:
	return game.call("_build_save_state").duplicate(true)

func _load_semantics(state: Dictionary) -> Dictionary:
	# Existing gathering restore invalidates route-token generations. This is the
	# only known load-token projection. No schema, message, positions, inventory,
	# clocks, water, ID lists, history or new fields are discarded here.
	var result: Dictionary = JSON.parse_string(JSON.stringify(state))
	result.modules.gathering.erase("generation")
	return result

func _semantic_diff(expected: Dictionary, label: String) -> bool:
	var actual := _load_semantics(_state())
	var wanted := _load_semantics(expected)
	for key in actual:
		if actual[key] != wanted.get(key):
			print("COAST_LOAD_FIELD_DIFF ",label," field=",key," actual=",JSON.stringify(actual[key])," expected=",JSON.stringify(wanted.get(key)))
	return actual == wanted

func _same_except_support_y(before: Dictionary, after: Dictionary, correction: Dictionary) -> bool:
	var a := _load_semantics(before)
	var b := _load_semantics(after)
	var pa: Dictionary = a.player_position
	var pb: Dictionary = b.player_position
	var na: Dictionary = a.vessel_navigation.actors.player.position
	var nb: Dictionary = b.vessel_navigation.actors.player.position
	if pa.x != pb.x or pa.z != pb.z or na.x != nb.x or na.z != nb.z:
		return false
	var delta := float(correction.get("delta_y", 0.0)) if correction.get("applied", false) else 0.0
	if correction.get("applied", false) and (delta <= 0.0 or not correction.get("xz_unchanged", false)):
		return false
	if absf(float(pb.y) - float(pa.y) - delta) > 0.00001 or absf(float(nb.y) - float(na.y) - delta) > 0.00001:
		return false
	# Assert the exact permitted delta, then restore only those two Y values for
	# an equality check of the ENTIRE state and its full key set.
	pb.y = pa.y
	nb.y = na.y
	return a == b

func _static_ids() -> Dictionary:
	var result := {}
	var land := game.get_node("IslandLandmass")
	var roots: Array[Node] = [land]
	for body in coast.get("rock_bodies"):
		roots.append(body)
	for root_node in roots:
		var nodes: Array[Node] = [root_node]
		nodes.append_array(root_node.find_children("*", "", true, false))
		for node in nodes:
			var row: Array = [node.get_instance_id()]
			if node is MeshInstance3D:
				row.append(node.mesh.get_instance_id())
				row.append(node.material_override.get_instance_id())
			if node is CollisionShape3D:
				row.append(node.shape.get_instance_id())
			result[str(game.get_path_to(node))] = row
	var sea: MeshInstance3D = game.get_node("Sea")
	var material := sea.material_override as ShaderMaterial
	var height_texture: Texture2D = material.get_shader_parameter("opening_heights")
	result["Sea resources"] = [sea.mesh.get_instance_id(), material.get_instance_id(), material.shader.get_instance_id(), height_texture.get_instance_id() if height_texture else 0]
	return result

func _collect(id: String) -> void:
	var source := game.get_node_or_null(NodePath(id)) as Node3D
	if not _check(source != null, "actual collection source exists: " + id):
		return
	_player().global_position = source.global_position + Vector3(0, 0.5, 0)
	_player().velocity = Vector3.ZERO
	game.call("_interact")
	_check(id in game.get("collected_ids"), "normal interaction consumes exact resource ID: " + id)

func _refresh_ok(label: String) -> void:
	var before := _state()
	var ids := _static_ids()
	var result: Dictionary = coast.call("refresh_loaded_visuals")
	_check(result.get("ok", false), label + " visual refresh passes")
	_check(_state() == before, label + " visual refresh preserves exact full state")
	_check(_static_ids() == ids, label + " refresh retains static node/mesh/material/collider/raster identities")

func _collected_save() -> void:
	saves.clear_for_test()
	_spawn()
	_collect("DriftwoodShore")
	var queued := game.get_node_or_null("DriftwoodShore")
	_check(queued != null and queued.is_queued_for_deletion(), "real collection initially leaves only canonical queued deletion")
	_refresh_ok("collected same-frame")
	await _settle()
	_check(game.get_node_or_null("DriftwoodShore") == null, "collected visual disappears after canonical deletion")
	_player().position = Vector3(0, 1.1, 1.2)
	_check(bool(game.call("_save_progress")), "collected state uses real save service")
	var saved: Dictionary = saves.load_state().get("state", {})
	var bytes := FileAccess.get_file_as_string(saves.get_save_path())
	_check(int(saved.wood) == 3 and saved.collected_ids.has("DriftwoodShore"), "earned collection fixture has exactly three wood")
	await _drop()
	for recreation in range(2):
		_spawn()
		_check(_load_semantics(_state()) == _load_semantics(saved), "collection restores full saved semantics before first physics")
		_refresh_ok("collected fresh %d" % recreation)
		await _settle()
		var static_ids := _static_ids()
		for repeat in range(3):
			game.call("_load_progress")
			_refresh_ok("collected repeat %d" % repeat)
			await _settle()
			_check(game.get_node_or_null("DriftwoodShore") == null and int(game.get("wood")) == 3, "repeat load never respawns/refunds collected supply")
			_check(_load_semantics(_state()) == _load_semantics(saved), "repeat load retains all saved semantics")
			_check(_static_ids() == static_ids, "repeat load does not reconstruct static coast/raster")
			_check(FileAccess.get_file_as_string(saves.get_save_path()) == bytes, "read/reconcile does not rewrite the source save")
		await _drop()

func _legacy_height(point: Vector3) -> Variant:
	# Independent old builder, not the coast module's cached support or profile.
	var old: StaticBody3D = LegacyLandmass.new().build_island("OldSupportWitness", Vector3(11, 0, -14), Vector2(12, 10), 1.2)
	var best: Variant = null
	for part in ["ShorelineCollision", "GrasslandCollision"]:
		var shape: ConcavePolygonShape3D = old.get_node(part).shape
		var faces := shape.get_faces()
		for index in range(0, faces.size(), 3):
			var a: Vector3 = old.transform * faces[index]
			var b: Vector3 = old.transform * faces[index + 1]
			var c: Vector3 = old.transform * faces[index + 2]
			var ab := Vector2(b.x - a.x, b.z - a.z)
			var ac := Vector2(c.x - a.x, c.z - a.z)
			var ap := Vector2(point.x - a.x, point.z - a.z)
			var determinant := ab.cross(ac)
			if absf(determinant) < 0.0000001:
				continue
			var u := ap.cross(ac) / determinant
			var v := ab.cross(ap) / determinant
			if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
				var height := a.y + u * (b.y - a.y) + v * (c.y - a.y)
				if best == null or height > float(best):
					best = height
	old.free()
	return best

func _foot_offset() -> float:
	var shape: CollisionShape3D = _player().get_child(0)
	return shape.global_position.y - _player().global_position.y - (shape.shape as CapsuleShape3D).height * 0.5

func _feet() -> Dictionary:
	var player := _player()
	return {"position": player.global_position, "velocity": player.velocity, "foot": player.global_position.y + _foot_offset(), "terrain": coast.call("sample_height", player.global_position), "floor": player.is_on_floor(), "swimming": game.get("is_swimming")}

func _legacy_shoulder() -> void:
	saves.clear_for_test()
	_spawn()
	var point := Vector3(16.2, 0, -18.1)
	var old_height: Variant = _legacy_height(point)
	if not _check(old_height != null, "independent old collider supports shoulder fixture"):
		await _drop()
		return
	point.y = float(old_height) - _foot_offset() + 0.001
	_player().global_position = point
	_player().velocity = Vector3.ZERO
	_check(bool(game.call("_save_progress")), "synthetic old-supported position saved through normal service")
	var saved: Dictionary = saves.load_state().get("state", {})
	var bytes := FileAccess.get_file_as_string(saves.get_save_path())
	await _drop()
	for cycle in range(2):
		_spawn()
		var correction: Dictionary = coast.get("position_correction")
		_check(correction.get("applied", false), "old shoulder correction already applies in _ready, before first physics")
		_check(_same_except_support_y(saved, _state(), correction), "old shoulder changes only upward player Y and its navigation mirror")
		var before := _state()
		var position := _player().global_position
		var velocity := _player().velocity
		if cycle == 1:
			await _step(2)
			_check(_state() == before, "two frozen startup physics frames do not postpone or repeat correction")
		coast.call("reconcile_loaded_player")
		_check(_state() == before and _player().global_position == position and _player().velocity == velocity, "reconciliation is idempotent on corrected ground")
		_check(not coast.get("position_correction").get("applied", true), "second reconciliation records no correction")
		_resume()
		await _step(90)
		var feet := _feet()
		_check(feet.floor and feet.terrain != null and absf(float(feet.foot) - float(feet.terrain)) < 0.15, "old shoulder settles on real terrain collider")
		_check(_player().global_position.x == point.x and _player().global_position.z == point.z, "settling preserves saved XZ exactly")
		var start := _player().global_position
		_key(KEY_A, true)
		await _step(90)
		_release()
		_check(_player().global_position.distance_to(start) > 0.5, "original controller walks away from reconciled shoulder")
		_freeze()
		_check(FileAccess.get_file_as_string(saves.get_save_path()) == bytes, "shoulder compatibility does not rewrite old supported save")
		observations.append({"case": "old_supported_shoulder", "cycle": cycle, "correction": correction, "settled": feet, "walk_distance": _player().global_position.distance_to(start)})
		await _drop()

func _guard_unchanged(label: String) -> void:
	_freeze()
	var before := _state()
	var position := _player().global_position
	var velocity := _player().velocity
	var swimming: bool = game.get("is_swimming")
	coast.call("reconcile_loaded_player")
	_check(not coast.get("position_correction").get("applied", true), label + " gets no support correction")
	_check(_state() == before and _player().global_position == position and _player().velocity == velocity and game.get("is_swimming") == swimming, label + " preserves full state, XYZ, velocity and swim policy")
	_refresh_ok(label)

func _valid_states() -> void:
	for kind in ["fresh_prephysics", "boat", "jump", "swim"]:
		saves.clear_for_test()
		_spawn()
		if kind != "fresh_prephysics":
			_resume()
			await _step(90)
		if kind == "jump":
			_check(_player().is_on_floor(), "jump starts on actual raft floor")
			_tap(KEY_SPACE)
			await _step(12)
			_check(_player().velocity.y > 0.0, "normal Space produces actual upward jump trajectory")
		elif kind == "swim":
			_key(KEY_S, true)
			await _step(220)
			_release()
			_check(bool(game.get("is_swimming")), "normal stern departure reaches actual swimming")
		_guard_unchanged(kind)
		await _drop()

func _missing_dependencies() -> void:
	for path in ["DriftwoodShore", "IslandLandmass/Shoreline", "ShoreRockA"]:
		saves.clear_for_test()
		_spawn()
		_check(bool(game.call("_save_progress")), "dependency fixture is a normally validated saved session")
		game.get_node(path).free()
		var before := _state()
		var child_count := game.find_children("*", "", true, false).size()
		var result: Dictionary = coast.call("refresh_loaded_visuals")
		_check(not result.get("ok", true), "missing required dependency is rejected: " + path)
		_check(_state() == before and game.find_children("*", "", true, false).size() == child_count, "dependency rejection does not reset state or spawn replacements: " + path)
		_check(game.get_node_or_null(path) == null, "missing dependency is not silently recreated: " + path)
		var module_state := _module_identity_state()
		var bytes := FileAccess.get_file_as_bytes(saves.get_save_path())
		game.call("_load_progress")
		_check(game.get_meta("save_load_blocked", false) and _module_identity_state() == module_state, "actual dependency rejection keeps every module identity and snapshot: " + path)
		_check(FileAccess.get_file_as_bytes(saves.get_save_path()) == bytes, "actual dependency rejection leaves original save bytes untouched")
		# The real presentation loop must safely skip the now-invalid interaction
		# reference, rather than casting a freed object before validating it.
		game.get("nearfuture_hud").refresh()
		var notice := game.get("save_status_notice") as Label
		_check(notice.visible and notice.text.contains("返回主界面后继续"), "dependency rejection exposes existing fresh-scene-needed warning immediately")
		await _settle()
		await _drop()

func _missing_dependency_menu() -> void:
	saves.clear_for_test()
	_spawn()
	_check(bool(game.call("_save_progress")), "missing-scene menu fixture saves normally")
	var saved: Dictionary = saves.load_state().state
	var saved_bytes := FileAccess.get_file_as_bytes(saves.get_save_path())
	game.get_node("ShoreRockA").free()
	game.call("_load_progress")
	var notice := game.get("save_status_notice") as Label
	_check(game.get_meta("save_load_blocked", false) and notice.visible and notice.text.contains("返回主界面后继续"), "strict dependency block is visible and explains fresh scene")
	current_scene = game
	game.call("_return_to_main_menu")
	await _settle()
	game = null
	coast = null
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/main.tscn", "blocked scene can return through existing menu action")
	_check(FileAccess.get_file_as_bytes(saves.get_save_path()) == saved_bytes, "blocked exit does not overwrite original valid save")
	paused = true
	(current_scene.get("enter_button") as Button).pressed.emit()
	for _frame in range(4):
		await process_frame
		if current_scene is Node3D:
			game = current_scene
			_freeze()
	paused = false
	if not _check(game != null, "normal Continue recreates missing scene dependency"):
		return
	coast = game.get("opening_coast")
	_check(game.get_node_or_null("ShoreRockA") != null and not game.get_meta("save_load_blocked", false), "only fresh world construction restores missing static geometry")
	_check(_semantic_diff(saved, "dependency fresh Continue"), "fresh dependency recovery preserves full saved state")
	await _drop()
	if has_meta("ark_menu_save_root_override"):
		remove_meta("ark_menu_save_root_override")

func _module_identity_state() -> Dictionary:
	var result := {}
	for field in ["water", "economy", "construction", "gathering", "memories", "vessel_navigation"]:
		var module: RefCounted = game.get(field)
		result[field] = {"id": module.get_instance_id(), "snapshot": module.call("snapshot").duplicate(true)}
	return result

func _write_raw_save(raw: String) -> void:
	# Avoid backup recovery making a corrupt-primary fixture accidentally valid.
	saves.clear_for_test()
	DirAccess.make_dir_recursive_absolute(save_root)
	var file := FileAccess.open(saves.get_save_path(), FileAccess.WRITE)
	_check(file != null, "test-only malformed payload file opens")
	if file:
		file.store_string(raw)
		file.close()

func _rejected_loads() -> void:
	for kind in ["earlier_uncollected", "corrupt", "module_inconsistent"]:
		saves.clear_for_test()
		_spawn()
		var earlier := _state()
		_collect("DriftwoodShore")
		await _settle()
		_player().position = Vector3(0, 1.1, 1.2)
		_check(bool(game.call("_save_progress")), "rejected-load setup saves earned current state")
		var current := _state()
		if kind == "earlier_uncollected":
			_check(bool(saves.save_state(earlier).get("ok", false)), "earlier pristine state is individually valid")
		elif kind == "corrupt":
			_write_raw_save("intentionally malformed lifecycle-test bytes; never a personal slot")
		else:
			var inconsistent := current.duplicate(true)
			inconsistent.storage_built = true
			var payload := JSON.stringify(inconsistent)
			_write_raw_save(JSON.stringify({"format": Save.FORMAT, "version": Save.VERSION, "payload": payload, "sha256": payload.sha256_text()}))
		var source_bytes := FileAccess.get_file_as_string(saves.get_save_path())
		var before := _state()
		var modules := _module_identity_state()
		var static_ids := _static_ids()
		var node_count := game.find_children("*", "", true, false).size()
		game.call("_load_progress")
		var after := _state()
		_check(game.get_meta("save_load_blocked", false), kind + " rejected load visibly protects source save")
		_check(not str(game.get_meta("save_warning", "")).is_empty(), kind + " rejection has visible warning text")
		if kind == "earlier_uncollected":
			_check(str(game.get_meta("save_warning", "")).contains("返回主界面"), "in-place rollback blocker explains fresh-scene recovery")
		# Rejection may update only user-facing feedback. No token generation,
		# positions, water phase, modules, inventory, IDs, history or clock changes.
		before.erase("message")
		after.erase("message")
		_check(before == after, kind + " rejects before all state mutation except visible feedback")
		_check(_module_identity_state() == modules, kind + " retains exact water/economy/construction/gathering/memory/navigation instances AND snapshots")
		_check(_static_ids() == static_ids and game.find_children("*", "", true, false).size() == node_count, kind + " preserves entire coast/resource graph cardinality and static identities")
		_check(game.get_node_or_null("DriftwoodShore") == null and int(game.get("wood")) == 3, kind + " does not respawn/refund an absent resource")
		_check(FileAccess.get_file_as_string(saves.get_save_path()) == source_bytes, kind + " preserves rejected source bytes")
		await _settle()
		_check(_module_identity_state() == modules, kind + " rejection remains stable after frozen frame settlement")
		await _drop()
		if kind == "earlier_uncollected":
			_spawn()
			_check(game.get_node_or_null("DriftwoodShore") != null and int(game.get("wood")) == 1, "same earlier valid save loads in a fresh scene with canonical resources")
			_check(_load_semantics(_state()) == _load_semantics(earlier), "fresh-scene rollback restores full earlier semantics rather than stale current state")
			await _drop()

func _visual_gap(target: Node3D) -> float:
	var low := INF
	var points := PackedVector3Array()
	for node in target.find_children("*", "MeshInstance3D", true, false):
		if not node.is_visible_in_tree() or node.mesh == null:
			continue
		for vertex in node.mesh.get_faces():
			var point: Vector3 = node.to_global(vertex)
			points.append(point)
			low = minf(low, point.y)
	var gap := INF
	for point in points:
		if point.y > low + 0.035:
			continue
		var height: Variant = coast.call("sample_height", point)
		if height != null:
			gap = minf(gap, point.y - float(height))
	return gap

func _dawn_supply() -> void:
	saves.clear_for_test()
	_spawn()
	_collect("DriftwoodShore")
	await _settle()
	var wood_before: int = game.get("wood")
	var static_ids := _static_ids()
	for _period in range(4):
		game.call("_advance_world_period", "opening_coast_lifecycle_test")
	var supply := game.get_node_or_null("DriftwoodShore") as Node3D
	_check(supply != null and not game.get("collected_ids").has("DriftwoodShore"), "only existing next-dawn policy replenishes depleted resource")
	_check(int(game.get("wood")) == wood_before, "dawn grounding grants no inventory")
	if supply:
		_check(supply.position == Vector3(9, 0.22, -4), "dawn leaves interaction root/ID at existing position")
		_check(is_finite(_visual_gap(supply)) and absf(_visual_gap(supply) + 0.012) < 0.006, "newly authorized supply visual contacts actual new terrain")
	var before := _state()
	_check(int(game.call("_replenish_shore_supplies")) == 0, "repeat same-dawn replenish remains no-op")
	_check(_state() == before, "repeat dawn hook preserves complete state")
	for _repeat in range(8):
		_refresh_ok("replenished resource")
	_check(_static_ids() == static_ids, "dawn never rebuilds static coast")
	_collect("DriftwoodShore")
	_check(int(game.get("wood")) == wood_before + 2, "replenished real supply gives only its original batch")
	await _drop()

func _pivot(target: Node3D) -> Node3D:
	var constants: Dictionary = coast.get_script().get_script_constant_map()
	return target.get_node_or_null(NodePath(str(constants.get("VISUAL_PIVOT", "CoastVisualGroundOffset")))) as Node3D

func _talk_to(id: String) -> void:
	for entry in game.get("interactables"):
		if str(entry.id) == id:
			_player().global_position = (entry.node as Node3D).global_position + Vector3.UP * 0.5
			game.call("_interact")
			return
	_check(false, "required interaction exists: " + id)

func _aboard_offsets(label: String) -> void:
	for field in ["traveler_marker", "sailmaker_marker", "tidekeeper_box_marker"]:
		var target := game.get(field) as Node3D
		_check(target != null and target.get_parent() == game.get("ark_root"), label + " existing boarding owns " + field)
		if target:
			var pivot := _pivot(target)
			_check(pivot == null or is_zero_approx(pivot.position.y), label + " shore-only visual offset does not follow aboard: " + field)

func _fixture_counts(label: String) -> void:
	for path in ["ArkRoot/BuiltShelter", "ArkRoot/BuiltStorage", "ArkRoot/BuiltWorkbench"]:
		_check(game.get_node_or_null(path) != null, label + " expected fixture exists: " + path)
		_check(game.find_children(path.get_file() + "*", "", true, false).size() == 1, label + " fixture is not duplicated: " + path)
	for id in ["cot", "hearth", "storage", "workbench"]:
		var count := 0
		for entry in game.get("interactables"):
			if str(entry.id) == id:
				count += 1
		_check(count == 1, label + " fixture interaction unique: " + id)

func _neutral_feet(marker: Node3D, body: Node3D) -> PackedVector3Array:
	# Independent immutable witness from the real figure, not production cache.
	# Remove only its current bob/pivot translation while retaining actual shape.
	var pivot := _pivot(marker)
	var current_offset := (pivot.position.y if pivot else 0.0) + body.position.y
	var points := PackedVector3Array()
	var low := INF
	for node in body.find_children("*", "MeshInstance3D", true, false):
		for vertex in node.mesh.get_faces():
			var local: Vector3 = marker.to_local(node.to_global(vertex)) - Vector3.UP * current_offset
			points.append(local)
			low = minf(low, local.y)
	var feet := PackedVector3Array()
	for point in points:
		if point.y <= low + 0.035:
			feet.append(point)
	return feet

func _independent_support_weight(height: float, mean: float) -> float:
	# Independent cubic expression, not a call to the production smoothstep.
	var t := clampf((height - mean) / .35, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _actor_support_boundaries() -> void:
	var before := _state()
	var authority: RefCounted = game.get("water")
	var water_before: Dictionary = authority.call("snapshot").duplicate(true)
	var mean: float = authority.get("mean_height")
	_check(mean == -1.05, "moving visual safety retains original mean water height")
	var world := BoundaryWorld.new()
	world.water = authority
	root.add_child(world)
	var actor := Node3D.new()
	world.add_child(actor)
	var pivot := Node3D.new()
	pivot.name = "CoastVisualGroundOffset"
	actor.add_child(pivot)
	var sign := Label3D.new()
	sign.name = "Name"
	sign.position.y = 2.7
	actor.add_child(sign)
	var probe := BoundaryCoast.new()
	probe.scene = world
	probe.initialized = true
	probe.actor_contacts.append({"node": weakref(actor), "name": "SyntheticBoundaryActor", "feet": PackedVector3Array([Vector3(-.1, 0, 0), Vector3(.1, 0, 0)])})
	var specifications: Array = []
	for h in [mean - .00001, mean, mean + .00001]:
		specifications.append({"id": "lower_boundary", "heights": [h, h], "support": h, "raw": h - .012})
	for index in range(1, 20):
		var h := mean + .35 * float(index) / 20.0
		specifications.append({"id": "band_%02d" % index, "heights": [h, h], "support": h, "raw": h - .012})
	for h in [mean + .35 - .00001, mean + .35, mean + .35 + .00001, .045]:
		specifications.append({"id": "upper_boundary_or_initial_pose", "heights": [h, h], "support": h, "raw": h - .012})
	specifications.append({"id": "mixed_submerged_exposed", "heights": [mean - .2, .1], "support": .1, "raw": .1 - .012})
	specifications.append({"id": "absent", "heights": [null, null], "support": null, "raw": 0.0})
	var rows: Array = []
	var previous := 0.0
	for index in range(specifications.size()):
		var row: Dictionary = specifications[index]
		var weight := _independent_support_weight(float(row.support), mean) if row.support != null else 0.0
		var expected: float = float(row.raw) * weight
		probe.supplied_heights = row.heights
		probe.sample_index = 0
		var root_transform := actor.transform
		var sign_visible := sign.visible
		probe.refresh_moving_actors()
		_check(absf(pivot.position.y - expected) < .000001, "production position-only support blend: " + str(row.id))
		_check(actor.transform == root_transform and sign.visible == sign_visible, "blend affects only visual Y, never actor root/HUD visibility")
		_check(absf(sign.position.y - (2.7 + expected)) < .000001, "blended label shares actual visual offset")
		if index in [1, 2]:
			_check(absf(pivot.position.y - previous) < .0000001, "lower exposed boundary has no hard-threshold jump")
		if index in [23, 24]:
			_check(absf(pivot.position.y - previous) < .0001, "upper blend boundary joins the original contact continuously")
		if index >= 3 and index <= 21:
			_check(absf(pivot.position.y - previous) < .1, "dense 20-step band witness has bounded continuous changes")
		previous = pivot.position.y
		rows.append({"case": row.id, "heights": row.heights, "weight": weight, "actual_offset": pivot.position.y})
	var vessel := Node3D.new()
	world.add_child(vessel)
	actor.reparent(vessel, true)
	pivot.position.y = .5
	probe.refresh_moving_actors()
	_check(is_zero_approx(pivot.position.y) and is_equal_approx(sign.position.y, 2.7), "actual production aboard reset ignores shore support")
	_check(authority.call("snapshot") == water_before and _state() == before, "blend calibration changes no real water/AI/economy/state")
	observations.append({"case": "moving_support_continuous_band", "mean_height": mean, "band_height": .35, "samples": rows,
		"limitation": "blend only adjusts presentation; existing NPC route is unchanged and partial-band feet are not exact terrain contact"})
	world.free()

func _neutral_offset(marker: Node3D, neutral: PackedVector3Array) -> Dictionary:
	var mean: float = game.get("water").mean_height
	var result := {"sampled": false, "offset": 0.0, "raw_offset": 0.0, "weight": 0.0,
		"support_height": null, "exposed_samples": 0, "submerged_samples": 0,
		"missing_samples": 0, "submerged_only": false, "mean_height": mean}
	if marker.get_parent() != game:
		return result
	var raw_offset := -INF
	var support_height := -INF
	for local in neutral:
		var world := marker.to_global(local)
		var height: Variant = coast.call("sample_height", world)
		if height == null:
			result.missing_samples += 1
			continue
		if float(height) <= mean:
			result.submerged_samples += 1
		else:
			result.exposed_samples += 1
		support_height = maxf(support_height, float(height))
		raw_offset = maxf(raw_offset, float(height) - world.y - 0.012)
	if is_finite(raw_offset):
		result.support_height = support_height
		result.raw_offset = raw_offset
		result.weight = _independent_support_weight(support_height, mean)
		result.sampled = float(result.weight) > 0.0
		result.offset = raw_offset * float(result.weight)
	result.submerged_only = result.submerged_samples > 0 and result.exposed_samples == 0
	return result

func _moving_resident_contact(marker: Node3D, body: Node3D, neutral: PackedVector3Array, label: String) -> Dictionary:
	var expected := _neutral_offset(marker, neutral)
	var pivot := _pivot(marker)
	if not _check(pivot != null, label + " uses one existing visual pivot"):
		return expected
	var before := _state()
	var root_transform := marker.global_transform
	var body_transform := body.transform
	var sign := marker.get_node("Name") as Label3D
	var visible := sign.visible
	coast.call("refresh_moving_actors")
	_check(marker.global_transform == root_transform and body.transform == body_transform and _state() == before, label + " visual follow preserves actor route root, actual bob and full state")
	_check(absf(pivot.position.y - float(expected.offset)) < 0.0001, label + " pivot follows immutable neutral feet with the independent position-only support blend, never current animated bob")
	_check(sign.visible == visible, label + " terrain grounding does not override HUD visibility policy")
	if expected.submerged_only:
		_check(is_zero_approx(pivot.position.y), label + " native submerged segment uses original visual baseline, not seabed")
	if marker.get_parent() == game:
		_check(absf(sign.position.y - (2.7 + float(expected.offset))) < 0.0001 and is_zero_approx(sign.position.x) and is_zero_approx(sign.position.z), label + " world nameplate follows terrain-only Y offset at unchanged XZ")
	else:
		_check(is_zero_approx(pivot.position.y) and is_equal_approx(sign.position.y, 2.7), label + " aboard actor resets pivot and label baseline outside cutaway")
	return expected

func _moving_residents() -> void:
	# The paid-home fixture already depleted the three wood sources. The normal
	# dispatcher therefore reserves nearby real TidalShellsNear, without adding a
	# source, changing the 11m policy, teleporting the NPC, or fabricating receipts.
	_player().global_position = Vector3(11, 0.31, -7)
	game.call("_update_shelter_roof_cutaway")
	var marker := game.get("traveler_marker") as Node3D
	var body := game.get("traveler_body") as Node3D
	var neutral := _neutral_feet(marker, body)
	_check(not neutral.is_empty(), "independent neutral foot witness has actual figure vertices")
	var shellfish_before: int = game.get("raw_shellfish")
	var stored_food_before: int = game.get("economy").inventory("storage_food","shellfish")
	if not _check(bool(game.call("_begin_resident_daily_gather")), "normal dispatcher starts existing nearshore shift"):
		return
	_check(str(game.get("resident_gather_target_id")) == "TidalShellsNear", "real nearest remaining source is authored-coast shellfish")
	_actor_support_boundaries()
	var water_before: Dictionary = game.get("water").snapshot().duplicate(true)
	var samples := 0
	var outbound_samples := 0
	var return_samples := 0
	var submerged_outbound := 0
	var submerged_return := 0
	var bob_samples := 0
	var heights: Array[float] = []
	var offsets: Array[float] = []
	var transitions: Array = []
	var previous: Dictionary = {}
	var maximum_visual_step := 0.0
	for step in range(1000):
		if not game.get("resident_gather_pending"):
			break
		var old_position := marker.global_position
		var old_phase: String = game.get("resident_gather_phase")
		game.call("_process", 0.1)
		await physics_frame
		var phase: String = game.get("resident_gather_phase")
		if marker.get_parent() == game and phase == "outbound" and old_phase == "outbound" and marker.global_position.distance_to(old_position) > 0.01:
			var expected_bob := sin(float(game.get("traveler_motion_clock")) * 9.0) * 0.035
			_check(absf(body.position.y - expected_bob) < 0.00001, "actual outbound animation retains original sinusoidal bob")
			bob_samples += 1
		# Every actual 0.1-second native step is observed, not just sparse poses;
		# no actor teleports or route/ground/water-policy changes are used.
		var contact := _moving_resident_contact(marker, body, neutral, "native gather %d" % step)
		_check(float(contact.mean_height) == -1.05, "moving correction never changes the authority mean height")
		if not previous.is_empty():
			var delta := absf(float(contact.offset) - float(previous.offset))
			maximum_visual_step = maxf(maximum_visual_step, delta)
			if bool(previous.sampled) != bool(contact.sampled):
				transitions.append({"step": step, "phase": phase, "root": marker.global_position,
					"from": previous, "to": contact.duplicate(true), "visual_y_step": delta})
		previous = contact.duplicate(true)
		if contact.submerged_only:
			if phase == "outbound":
				submerged_outbound += 1
			if phase == "returning":
				submerged_return += 1
		if contact.sampled:
			samples += 1
			offsets.append(float(contact.offset))
			var height: Variant = coast.call("sample_height", marker.global_position)
			if height != null:
				heights.append(float(height))
			if phase == "outbound":
				outbound_samples += 1
			if phase == "returning":
				return_samples += 1
	_check(not game.get("resident_gather_pending") and marker.get_parent() == game.get("ark_root"), "actual gather walks back and transfers aboard")
	_check(game.get("collected_ids").has("TidalShellsNear") and int(game.get("raw_shellfish")) == shellfish_before and game.get("economy").inventory("storage_food","shellfish") == stored_food_before+1, "native task delivers exactly its real finite shellfish to the physical home pantry, not the player")
	_check(outbound_samples > 0 and return_samples > 0 and bob_samples > 0 and samples > 3, "both native gather legs sample exposed authored terrain while bob remains active")
	_check(submerged_outbound > 0 and submerged_return > 0, "both native gather legs independently verify submerged support uses baseline zero")
	_check(not transitions.is_empty(), "native route actually crosses exposed-support boundary; actual adjacent-step size is reported, not inferred from formula")
	_check(game.get("water").snapshot() == water_before, "controlled native process route leaves actual water authority fixed")
	if not heights.is_empty():
		_check(heights.max() - heights.min() > 0.02, "native gather actually traverses variable-height coast, not only flat deck")
	_moving_resident_contact(marker, body, neutral, "native return aboard")
	observations.append({"case": "native_resident_gather", "coast_samples": samples,
		"outbound_samples": outbound_samples, "return_samples": return_samples,
		"submerged_outbound": submerged_outbound, "submerged_return": submerged_return,
		"bob_samples": bob_samples, "terrain_heights": heights, "pivot_offsets": offsets,
		"support_blend_transitions": transitions, "maximum_visual_step": maximum_visual_step, "native_process_delta": .1,
		"limitation": "continuous support blend changes no NPC route; partial-band feet are not exact terrain contact"})
	# Normal next morning makes the existing personal awning gift eligible. Let
	# its real route/work state machine earn sewing/carry/install progress; this
	# catches accessory lookup breakage caused by the new visual pivot.
	for _period in range(4):
		game.call("_advance_world_period", "opening_coast_accessory_test")
	var sailmaker := game.get("sailmaker_marker") as Node3D
	var bundle := coast.call("visual_child", sailmaker, "OldSailBundle") as MeshInstance3D
	var spool := coast.call("visual_child", sailmaker, "ThreadSpool") as Node3D
	var figure := coast.call("visual_child", sailmaker, "SailmakerFigure") as Node3D
	if not _check(bundle != null and spool != null and figure == game.get("sailmaker_body"), "production visual-child accessor resolves all real pivoted work parts"):
		return
	var seen := {}
	for _step_index in range(1000):
		game.call("_process", 0.1)
		await physics_frame
		var phase: String = game.get("sailmaker_awning_phase")
		if phase == "sewing" and bool(game.call("_sailmaker_at_awning_work_target", game.call("_sailmaker_awning_work_target", false))):
			seen.sewing = true
			_check(bundle.position == Vector3(0, 0.66, 0.3) and spool.position == Vector3(-0.25, 0.7, 0.25), "actual sewing still updates existing bundle/spool beneath pivot")
		elif phase == "carrying":
			seen.carrying = true
			_check(bundle.position == Vector3(0, 0.78, 0.32), "actual carry still holds original cloth at existing pose")
		elif phase == "installing" and bool(game.call("_sailmaker_at_awning_work_target", game.call("_sailmaker_awning_work_target", true))):
			seen.installing = true
			_check(bundle.position == Vector3(0, 1.81, 0.6), "actual installation still raises original cloth")
		if game.get("sailmaker_awning_raised") and not game.get("resident_gather_pending"):
			break
	_check(seen.has("sewing") and seen.has("carrying") and seen.has("installing") and game.get("sailmaker_awning_raised"), "normal work route reaches all three visible phases after coast integration")
	_check(not bundle.visible, "completed gift hides carried bundle rather than leaving a stale pivoted prop")
	_aboard_offsets("post-work actual residents")

func _boarding_fixture_menu() -> void:
	saves.clear_for_test()
	_spawn()
	for id in ["DriftwoodNear", "DriftwoodShore", "DriftwoodRidge"]:
		_collect(id)
		await _settle()
	_check(int(game.get("wood")) == 8, "home funding comes from actual three finite collections")
	_player().position = Vector3(0, 1.1, 1.75)
	_check(bool(game.call("_try_place_workshop_home_template", Vector3(0, 0.12, 0))), "existing paid workshop-home transaction succeeds")
	for id in ["resident", "sailmaker"]:
		_talk_to(id)
		_talk_to(id)
		var pending := "traveler_choice_pending" if id == "resident" else "sailmaker_choice_pending"
		_check(bool(game.get(pending)), "normal conversation opens invitation: " + id)
		game.call("_choose_traveler_boarding" if id == "resident" else "_choose_sailmaker_boarding", true)
	_aboard_offsets("actual invitation")
	await _moving_residents()
	_player().position = Vector3(0.25, 1.1, 1.2)
	_check(bool(game.call("_save_progress")), "built and boarded state saves normally")
	var saved: Dictionary = saves.load_state().get("state", {})
	# Existing loader derives the active task ID from the restored module. A
	# delivered historical task remains in history, but is no longer active.
	var completed_id := str(saved.resident_task_id)
	_check(not completed_id.is_empty() and not saved.resident_gather_pending, "earned task fixture is completed, never pending")
	_check(saved.modules.gathering.tasks[completed_id].phase == "delivered" and not saved.modules.gathering.active.has("tidekeeper"), "only an explicitly delivered inactive task ID gets the canonical empty projection")
	saved = saved.duplicate(true)
	saved.resident_task_id = ""
	var static_ids := _static_ids()
	for repeat in range(3):
		game.call("_load_progress")
		await _settle()
		_refresh_ok("boarded fixture load")
		_aboard_offsets("boarded reload")
		_fixture_counts("boarded reload")
		_check(_static_ids() == static_ids, "fixture reload keeps existing coast/static raster identities")
		_check(_semantic_diff(saved, "boarded reload"), "boarded reload preserves full save semantics")
	for id in ["storage", "workbench"]:
		var before := _state()
		game.call("_build_" + id + "_at", game.get(id + "_position"))
		_check(_static_ids() == static_ids, "direct fixture rebuild does not rebuild coast")
		_check(_load_semantics(_state()) == _load_semantics(before), "direct fixture rebuild preserves state")
		_fixture_counts("direct fixture rebuild")
	current_scene = game
	game.call("_return_to_main_menu")
	await _settle()
	game = null
	coast = null
	var menu := current_scene
	if not _check(menu != null and menu.scene_file_path == "res://scenes/main.tscn", "normal return reaches menu"):
		return
	_check(str(menu.get("save_root_override")) == save_root, "normal return retains test-only save root")
	var enter := menu.find_child("ArkEnterButton", true, false) as Button
	if not _check(enter != null and enter.text == "继续归舟", "normal menu recognizes actual saved integration state"):
		return
	# Pause ONLY the test tree while the menu creates the fresh scene. _ready and
	# the full loader still run, but no simulation tick can precede our snapshot.
	paused = true
	enter.pressed.emit()
	enter.pressed.emit()
	for _frame in range(4):
		await process_frame
		if current_scene is Node3D:
			game = current_scene
			_freeze()
	if not _check(game != null, "normal continue recreates actual Ark scene"):
		return
	coast = game.get("opening_coast")
	paused = false
	await _settle()
	_check(str(game.get("save_root_override")) == save_root, "menu recreate keeps isolated save destination")
	_aboard_offsets("menu recreate")
	_fixture_counts("menu recreate")
	_refresh_ok("menu recreate")
	_check(_semantic_diff(saved, "menu recreate"), "save/return/recreate preserves full integration state")
	var scenes := 0
	for node in root.get_children():
		if node.scene_file_path == "res://scenes/ark_greybox.tscn":
			scenes += 1
	_check(scenes == 1, "rapid continue creates one coast-owning game, not duplicate worlds")
	await _drop()
	if has_meta("ark_menu_save_root_override"):
		remove_meta("ark_menu_save_root_override")

func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/test_opening_coast_lifecycle_%d_%d" % [OS.get_process_id(), int(Time.get_unix_time_from_system() * 1000000)]).simplify_path()
	if not _check(Paths.is_safe_save_root(save_root), "all test saves are unique repository-local test paths"):
		quit(1)
		return
	saves = Save.new(save_root)
	await _collected_save()
	await _legacy_shoulder()
	await _valid_states()
	await _missing_dependencies()
	await _missing_dependency_menu()
	await _rejected_loads()
	await _dawn_supply()
	await _boarding_fixture_menu()
	saves.clear_for_test()
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.1.003", "integration does not bump the current game version")
	print("OPENING_COAST_LIFECYCLE_OBSERVATIONS: ", JSON.stringify(observations))
	if failures == 0:
		print("ARK_OPENING_COAST_LIFECYCLE_TEST_OK: ", checks, " checks; collection/reload/support/guards/dawn/boarding/fixtures/menu")
	else:
		print("ARK_OPENING_COAST_LIFECYCLE_TEST_FAILED: ", failures, " / ", checks)
	quit(0 if failures == 0 else 1)
