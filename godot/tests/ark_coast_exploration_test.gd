extends SceneTree
const Scene = preload("res://scenes/ark_greybox.tscn")
const Save = preload("res://scripts/ark_greybox_save.gd")
const Profile = preload("res://scripts/terrain/ark_coast_profile_v2.gd")
const History = preload("res://tests/support/coast_historical_projection.gd")
const V1 = preload("res://tests/support/ark_opening_coast_reference.gd")
var game: Node3D
var service: RefCounted
var save_root: String
var failures := 0
var route_frames := 0
var keys := {}

func _initialize() -> void:
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_MINIMIZED
		root.unfocusable = true
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("COAST_EXPLORATION: " + message)

func _key(code: Key, pressed: bool) -> void:
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
	var previous: Vector3 = game.player.position
	for frame in 900:
		var difference := Vector2(target.x-game.player.position.x,target.z-game.player.position.z)
		if difference.length() < .13:
			_release()
			return true
		_key(KEY_A,difference.x < -.06)
		_key(KEY_D,difference.x > .06)
		_key(KEY_W,difference.y < -.06)
		_key(KEY_S,difference.y > .06)
		await physics_frame
		route_frames += 1
		if frame > 0 and frame%180 == 0:
			if game.player.position.distance_to(previous) < .18:
				print("RIDGE_STALL ",target," actual=",game.player.position," floor=",game.player.is_on_floor()," velocity=",game.player.velocity)
				_release()
				return false
			previous = game.player.position
	_release()
	return false

func _spawn() -> void:
	game = Scene.instantiate()
	game.save_root_override = save_root
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await physics_frame

func _capture(name_: String, at: Vector3, target: Vector3, size: float) -> void:
	if DisplayServer.get_name() == "headless": return
	var output := OS.get_environment("ARK_COAST_CAPTURE_ROOT")
	assert(output.to_lower().begins_with("d:/"))
	DirAccess.make_dir_recursive_absolute(output)
	game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game.camera.size = size
	game.camera.position = at
	game.camera.look_at(target)
	for layer in game.find_children("*","CanvasLayer",true,false): layer.visible = false
	for index in 4:
		RenderingServer.force_draw(false)
		await process_frame
	root.get_texture().get_image().save_png(output.path_join(name_+".png"))

func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/coast_exploration_test_%d" % OS.get_process_id()).simplify_path()
	service = Save.new(save_root)
	service.clear_for_test()
	await _spawn()
	_check(game.opening_coast_result.ok,"production terrain initialized")
	var history = History.new()
	history.configure(game,self)
	history.validate_geometry()
	var legacy_state: Dictionary = game._build_save_state().duplicate(true)
	legacy_state.schema_version = 38
	legacy_state.erase("ridge_camp_searched")
	legacy_state.erase("raft_fenders_installed")
	_check(game.get_node("CoastNatureV2").get_child_count() == 12,"four batches and eight physical obstructions, no per-leaf nodes")
	_check(game.get_node("CoastNatureV2/Pine_1").multimesh.instance_count == 4,"bounded four trees")
	_check(game.get_node("CoastNatureV2/Fern_1").multimesh.instance_count == 12,"bounded fern batch")
	var camp: Node3D = game.get_node("RidgeOldCamp")
	_check(camp.position.y > 2.7,"camp stands on actual raised collision mesh")
	game.player.position = Vector3(10.6,.15,-18.5)
	game._search_ridge_camp()
	_check(not game.ridge_camp_searched,"cannot discover through ridge from below")
	# One declared initial fixture at the existing shore, then real production
	# input for every leg; no jump, speed/angle change or mid-route teleport.
	game.player.position = Vector3(8.4,.22,-6.1)
	game.player.velocity = Vector3.ZERO
	game.set_physics_process(true)
	for index in 30: await physics_frame
	_check(await _walk(Profile.TRAIL[0]),"shore approach reaches trail")
	for waypoint in Profile.TRAIL.slice(1):
		_check(await _walk(waypoint),"no-jump switchback leg " + str(waypoint))
	_release()
	for index in 20: await physics_frame
	game.set_physics_process(false)
	_check(game.player.is_on_floor() and not game.is_swimming,"camp arrival is dry and grounded")
	game._interact()
	_check(game.ridge_camp_searched and game.learned_blueprint_ids.has("storm_raft_fenders"),"real camp interaction permanently learns blueprint")
	var count: int = game.learned_blueprint_ids.size()
	game._interact()
	_check(game.learned_blueprint_ids.size() == count,"one-time knowledge, no inventory item or duplicate reward")
	await _capture("01_coast_ridge",Vector3(28,22,10),Vector3(11,.6,-13),34)
	await _capture("02_old_camp",Vector3(17,11,-10),camp.position,12)
	# Explicit synthetic stock tests the transaction, not earning enough wood.
	game.player.position = Vector3(0,.18,1.2)
	game.wood = 0
	game._install_raft_fenders()
	_check(not game.raft_fenders_installed,"insufficient wood cannot craft")
	game.wood = 12
	_check(game._try_place_workshop_home_template(Vector3(0,.12,0)),"synthetic workshop fixture built through production command")
	game.wood = 1
	game.stored_wood = 3
	game._install_raft_fenders()
	_check(game.raft_fenders_installed and game.wood == 0 and game.stored_wood == 0,"exact four wood consumed across real shared inventories")
	var receipts: int = game.economy.snapshot().receipts.size()
	game._install_raft_fenders()
	_check(game.economy.snapshot().receipts.size() == receipts,"duplicate craft cannot charge again")
	game.rope_use = ""
	game.raft_edge_damaged = false
	game.shelter_roof_damaged = false
	game._apply_storm_damage()
	_check(not game.raft_edge_damaged and game.shelter_roof_damaged,"fenders protect only raft; roof remains independent")
	await _capture("03_home_fenders",Vector3(10,8,11),Vector3(0,.5,0),13)
	var saved: Dictionary = game._build_save_state()
	_check(Save.valid_coast_exploration(saved),"schema41 durable facts and payment receipt agree")
	_check(service.save_state(saved).ok,"new progress serializes")
	var invalid := saved.duplicate(true)
	invalid.ridge_camp_searched = false
	_check(not service.save_state(invalid).ok,"reject installed/discovery/knowledge contradiction atomically")
	invalid = saved.duplicate(true)
	invalid.modules.economy.receipts.clear()
	_check(not Save.valid_coast_exploration(invalid),"installed upgrade requires matching payment receipt")
	game.save_service = null
	game.free()
	await _spawn()
	_check(game.ridge_camp_searched and game.raft_fenders_installed and game.learned_blueprint_ids.has("storm_raft_fenders"),"discover/craft/load round trip")
	_check(game.ark_root.get_node_or_null("RaftStormFenders") != null,"physical fenders restored once")
	game.save_service = null
	game.free()
	# A declared V38 fixture stands on the independently frozen V1 terrain.
	# New land must lift only Y; old progress must not invent discoveries.
	var old = V1.new()
	var old_data: Dictionary = old._refined_topology()
	var old_surface := SurfaceTool.new()
	old_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in old_data.faces:
		old._triangle(old_surface,old._from_parameter(old_data.vertices[face[0]]),old._from_parameter(old_data.vertices[face[1]]),old._from_parameter(old_data.vertices[face[2]]))
	old.top_faces_local = old_surface.commit().get_faces()
	old._build_height_index()
	old.island = StaticBody3D.new()
	old.island.position = Vector3(11,0,-14)
	root.add_child(old.island)
	var point := Vector3(12.5,0,-18.6)
	point.y = float(old.sample_height(point)) + .005
	legacy_state.player_position = {"x":point.x,"y":point.y,"z":point.z}
	legacy_state.vessel_navigation.actors.player.position = legacy_state.player_position.duplicate()
	legacy_state.vessel_navigation.actors.player.space = "world"
	legacy_state.vessel_navigation.actors.player.vessel_id = ""
	legacy_state.vessel_navigation.actors.player.floor_id = ""
	_check(service.save_state(legacy_state).ok,"valid V38 fixture is accepted")
	await _spawn()
	_check(not game.ridge_camp_searched and not game.raft_fenders_installed and not game.learned_blueprint_ids.has("storm_raft_fenders"),"old saves never receive free discovery or upgrade")
	print("V38_RECONCILIATION: old=",point," current=",game.player.global_position," decision=",game.opening_coast.position_correction," blocked=",game.get_meta("save_load_blocked",false))
	_check(game.player.global_position.y > point.y+.1 and is_equal_approx(game.player.global_position.x,point.x) and is_equal_approx(game.player.global_position.z,point.z),"V1 grounded player reconciles upward only on raised V2 land")
	var before: Vector3 = game.player.global_position
	game.is_swimming = true
	game.opening_coast.reconcile_loaded_player()
	_check(game.player.global_position == before,"swimming exclusion preserved")
	game.save_service = null
	game.free()
	old.island.free()
	service.clear_for_test()
	if failures == 0: print("ARK_COAST_EXPLORATION_TEST_OK: real no-jump shore/ridge/camp route, one-time knowledge, shared-stock craft, roof-independent storm protection and save validation; route_frames=",route_frames)
	quit(0 if failures == 0 else 1)
