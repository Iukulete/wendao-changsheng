extends SceneTree
const Scene = preload("res://scenes/ark_greybox.tscn")
const Terrain = preload("res://scripts/terrain/ark_moonback_terrain.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
const UtilityProps = preload("res://scripts/presentation/ark_modern_utility_props.gd")
var failures := 0
var game: Node3D
var keys := {}
var route_frames := 0
var save_root: String

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("MOONBACK_EXPLORATION: "+message)

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
		var offset := Vector2(target.x-game.player.position.x,target.z-game.player.position.z)
		if offset.length() < .14:
			_release()
			return true
		_key(KEY_A,offset.x < -.06)
		_key(KEY_D,offset.x > .06)
		_key(KEY_W,offset.y < -.06)
		_key(KEY_S,offset.y > .06)
		await physics_frame
		route_frames += 1
		if frame > 0 and frame%180 == 0:
			if game.player.position.distance_to(previous) < .18:
				print("MOONBACK_STALL target=",target," actual=",game.player.position," floor=",game.player.is_on_floor())
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

func _capture(_name_: String, _target: Vector3, _offset: Vector3, _size: float) -> void:
	pass # Display-backed helper overrides this; headless is never visual evidence.

func _physics_oracle() -> void:
	var exclude: Array[RID] = []
	var land_names := ["IslandLandmass","FarReefLandmass","MoonbackIsland","JadeSailShoal","SteamWreckIslet"]
	for body in game.find_children("*","CollisionObject3D",true,false):
		if not str(body.name) in land_names: exclude.append(body.get_rid())
	var count := 0
	var dry := 0
	for name_ in land_names:
		var center: Vector3 = game.get_node(name_).position
		for x in range(-16,17,2):
			for z in range(-16,17,2):
				var p := center+Vector3(x+.173,0,z+.219)
				var query := PhysicsRayQueryParameters3D.create(p+Vector3.UP*20,p-Vector3.UP*3,1,exclude)
				var hit := game.get_world_3d().direct_space_state.intersect_ray(query)
				var height: Variant = game._ground_height_at(p)
				_check((height == null) == hit.is_empty(),"real collider coverage "+name_+str(p))
				if height != null and not hit.is_empty():
					_check(absf(float(height)-hit.position.y) < .0001,"real collider height "+name_+str(p))
					if float(height) > -.9: dry += 1
				count += 1
	_check(dry > 250,"oracle contains dry ground, not just empty sea")
	print("MOONBACK_GROUND_ORACLE samples=",count," dry=",dry)

func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/moonback_test_%d" % OS.get_process_id())
	var service := Save.new(save_root)
	service.clear_for_test()
	await _spawn()
	_check(game.moonback_terrain_result.ok,"regional terrain installed")
	preload("res://tests/support/moonback_terrain_contract.gd").new().validate(game,self)
	preload("res://tests/support/moonback_landing_contract.gd").new().validate(game,self)
	var legacy_state: Dictionary = game._build_save_state().duplicate(true)
	legacy_state.schema_version = 41
	legacy_state.erase("kitchen")
	await _capture("01_moonback_highland",Vector3(-28,1,23),Vector3(22,24,26),37)
	await _capture("03_old_landing",Vector3(-20,0,17),Vector3(12,9,-13),18)
	_physics_oracle()
	var island: StaticBody3D = game.get_node("MoonbackIsland")
	var mesh: Mesh = island.get_node("Grassland").mesh
	print("MOONBACK_ARRAY_SHA ",var_to_bytes(mesh.surface_get_arrays(0)).hex_encode().sha256_text())
	_check(mesh.get_faces().size()/3 == 5664,"bounded highland geometry")
	_check(var_to_bytes(mesh.get_faces()) == var_to_bytes(island.get_node("GrasslandCollision").shape.get_faces()),"visible and solid terrain share exact faces")
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for i in vertices.size():
		_check(normals[i].is_finite() and absf(normals[i].length()-1) < .001 and normals[i].y > 0,"upward finite smooth terrain normal")
		_check(uvs[i].is_equal_approx(Vector2(vertices[i].x,vertices[i].z)),"meter-aligned terrain UV")
	var builder := preload("res://scripts/ark_landmass_builder.gd").new()
	var outer_start := 96*3+28*96*6
	for segment in 96:
		var old_edge := floori(float(segment)/3)
		var a: Vector3 = builder._point_on_island(Vector2(14,12),.76,TAU*old_edge/32.,5.4,.04)
		var b: Vector3 = builder._point_on_island(Vector2(14,12),.76,TAU*(old_edge+1)/32.,5.4,.04)
		_check(vertices[outer_start+segment*6+1].distance_to(a.lerp(b,float(segment%3)/3)) < .000003,"high-detail grass edge exactly subdivides legacy shore, no cracks")
	for x in [-1.7,0,1.7]:
		for z in [-1.4,0,1.4]:
			_check(absf(float(game._ground_height_at(Vector3(-32+x,0,25+z)))-2.8) < .04,"station footing remains supported within four centimeters")
	var high := 0.0
	for point in mesh.get_faces(): high = maxf(high,point.y)
	_check(high > 2.6,"island has real vertical relief")
	# Declared landing fixture, then only actual game input; no jumping/teleports
	# between path legs. End-to-end vessel trip remains the mooring regression.
	game.player.position = Vector3(-28,.2,13)
	game.player.velocity = Vector3.ZERO
	game.set_physics_process(true)
	for i in 25: await physics_frame
	for point in Terrain.TRAIL:
		_check(await _walk(point),"no-jump ascending trail "+str(point))
	_release()
	for i in 20: await physics_frame
	game.set_physics_process(false)
	_check(game.player.is_on_floor() and not game.is_swimming and game.player.position.y > 2.5,"actual dry highland arrival")
	game._interact()
	_check(game.tide_station_searched and game.tide_relay_cores == 1 and game.learned_blueprint_ids.has("tide_compass"),"real station interaction earns unique existing progression")
	await _capture("02_station_arrival",Terrain.STATION,Vector3(9,7,10),12)
	game._interact()
	_check(game.tide_relay_cores == 1 and game.learned_blueprint_ids.count("tide_compass") == 1,"no duplicate core/knowledge")
	_check(game._world_chart_destinations().any(func(row: Dictionary) -> bool: return row.id == "moonback" and "已经取走" in row.description),"map description reflects actual searched state")
	# Each far island used to be misclassified as water by the opening-only query.
	var ark_before: Transform3D = game.ark_root.transform
	for name_ in ["MoonbackIsland","FarReefLandmass","JadeSailShoal","SteamWreckIslet"]:
		game.ark_root.rotation = Vector3.ZERO
		game.ark_root.position = game.get_node(name_).position-UtilityProps.AT-Vector3(1.5,0,0)
		_check(not game._modern_intake_ready(),"dry-ground intake refuses water on "+name_)
	game.ark_root.position = Vector3(60,0,10)
	_check(game._modern_intake_ready(),"open sea remains usable")
	game.ark_root.transform = ark_before
	var saved: Dictionary = game._build_save_state()
	_check(service.save_state(saved).ok,"new terrain does not change the save schema")
	game.save_service = null
	game.free()
	await _spawn()
	_check(game.tide_station_searched and game.tide_relay_cores == 1,"unique progression restores without regrant")
	game.save_service = null
	game.free()
	var original := Vector3(-34,.045,23.1)
	var old_position := {"x":original.x,"y":original.y,"z":original.z}
	legacy_state.player_position = old_position.duplicate()
	legacy_state.vessel_navigation.actors.player.position = old_position.duplicate()
	legacy_state.vessel_navigation.actors.player.space = "world"
	legacy_state.vessel_navigation.actors.player.vessel_id = ""
	legacy_state.vessel_navigation.actors.player.floor_id = ""
	_check(service.save_state(legacy_state).ok,"synthetic pre-relief schema41 save is valid")
	await _spawn()
	_check(game.moonback_terrain.position_correction.applied and game.player.position.y > 1 and game.player.position.x == original.x and game.player.position.z == original.z,"actual save/load performs upward-only legacy correction")
	_check(not game.tide_station_searched and game.tide_relay_cores == 0 and not game.learned_blueprint_ids.has("tide_compass"),"terrain migration never grants exploration progress")
	# Old flat-island save: grounded player can only be lifted vertically, never
	# moved to the station or granted its rewards. Airborne/swimming are excluded.
	game.player.position = original
	game.player.velocity = Vector3.ZERO
	var correction: Dictionary = game.moonback_terrain.reconcile_loaded_player(game,game.ground_sampler)
	_check(correction.applied and game.player.position.y > 1 and game.player.position.x == original.x and game.player.position.z == original.z,"legacy contact corrected upward only")
	game.player.position = original
	game.is_swimming = true
	_check(not game.moonback_terrain.reconcile_loaded_player(game,game.ground_sampler).applied and game.player.position == original,"swimming is never lifted")
	game.is_swimming = false
	game.player.velocity.y = 2
	_check(not game.moonback_terrain.reconcile_loaded_player(game,game.ground_sampler).applied,"airborne trajectory preserved")
	game.save_service = null
	game.free()
	service.clear_for_test()
	if failures == 0: print("ARK_MOONBACK_EXPLORATION_TEST_OK: collider oracle, real no-jump route, unique existing progression, dry intake and legacy support; frames=",route_frames)
	quit(0 if failures == 0 else 1)
