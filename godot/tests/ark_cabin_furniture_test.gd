extends SceneTree
## Calendar, interaction travel and a single injury are explicit fixtures.
## Building/food inputs are real finite sources; no material or knowledge gifts.
const Scene = preload("res://scenes/ark_greybox.tscn")
const Save = preload("res://scripts/ark_greybox_save.gd")
var game: Node3D
func _initialize() -> void: _run.call_deferred()
func _capture(_stage: String) -> void: pass
func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game._unhandled_key_input(event)
func _visit(id: String) -> void:
	for entry in game.interactables:
		if entry.id==id:
			game.player.global_position = entry.node.global_position+Vector3.UP*.2
			game._interact()
			return
	assert(false,"Missing real interactable: "+id)
func _collisions() -> Dictionary:
	var result := {}
	for node in game.find_children("*","CollisionShape3D",true,false): result[str(game.get_path_to(node))] = [node.get_instance_id(),node.shape.get_instance_id(),node.global_transform,node.disabled]
	return result
func _lights() -> Dictionary:
	var result := {}
	for node in game.find_children("*","Light3D",true,false): result[str(game.get_path_to(node))] = [node.get_instance_id(),node.light_energy,node.light_color]
	return result
func _diff(a: Variant,b: Variant,path: String = "") -> void:
	if game.MemoryScript.facts_equal(a,b): return
	if a is Dictionary and b is Dictionary:
		for key in a:
			if not b.has(key): print("FURNITURE_SAVE_DIFF missing ",path,"/",key)
			else: _diff(a[key],b[key],path+"/"+str(key))
		for key in b:
			if not a.has(key): print("FURNITURE_SAVE_DIFF new ",path,"/",key)
	else: print("FURNITURE_SAVE_DIFF ",path," before=",a," after=",b)
func _disk_view(state: Dictionary) -> Dictionary:
	# Disk round trips normalize JSON numbers. Gathering.restore deliberately
	# advances its anti-stale-result generation; assert that increment separately.
	var result: Dictionary = JSON.parse_string(JSON.stringify(state))
	result.modules.gathering.generation = 0
	return result
func _visual(path: String) -> MeshInstance3D:
	var node: Node = game.get_node("ArkRoot/"+path)
	return node if node is MeshInstance3D else node.get_child(0) as MeshInstance3D
func _assert_model(id: String,size_: Vector3,triangles: int) -> void:
	var furniture = game.home_art_sample.furniture
	var holder: Node3D = furniture._instances[id].get_ref()
	var box: AABB = furniture._bounds(holder)
	assert(box.size.is_equal_approx(size_),"model stays within its reviewed visual footprint")
	var count := 0
	for mesh in holder.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			count += arrays[Mesh.ARRAY_INDEX].size()/3
			assert(mesh.get_active_material(surface).albedo_color==furniture.TINT)
	assert(count==triangles,"real imported geometry, not an empty or box-only stand-in")
	assert(holder.find_children("*","CollisionObject3D",true,false).is_empty() and holder.find_children("*","Light3D",true,false).is_empty())
func _run() -> void:
	var path := ProjectSettings.globalize_path("res://../.local/test_cabin_furniture_%d" % OS.get_process_id())
	var service := Save.new(path)
	service.clear_for_test()
	game = Scene.instantiate()
	game.save_root_override = path
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	await physics_frame
	assert(game.home_art_sample.furniture._instances.is_empty(),"no unbuilt home gets free furniture")
	for i in 3:
		_visit("wood")
		await process_frame
	assert(game.wood==8)
	game.player.position = Vector3(0,1.1,1.75)
	assert(game._try_place_workshop_home_template(Vector3.ZERO) and game.wood==1)
	var sample = game.home_art_sample
	var furniture = sample.furniture
	_assert_model("PlayerCotFurniture",Vector3(.92,.68,.52),534)
	_assert_model("PantryCabinetFurniture",Vector3(.98,.86,.86),322)
	_assert_model("CabinReadingBooks",Vector3(.26,.19,.105),196)
	assert(furniture._instances.size()==3 and furniture._hidden.size()==6)
	assert((_visual("BuiltShelter/Cot").mesh as BoxMesh).size==Vector3(.92,.34,.52) and not _visual("BuiltShelter/Cot").visible)
	await _capture("01_paid_starter_home")
	var before: Dictionary = game._build_save_state()
	var collisions := _collisions()
	var lights := _lights()
	for i in 100: sample.apply(game)
	assert(game.MemoryScript.facts_equal(before,game._build_save_state()) and collisions==_collisions() and lights==_lights())
	assert(furniture._instances.size()==3 and furniture._hidden.size()==6 and furniture._loaded.size()==3 and furniture._materials.size()==3)
	_key(KEY_F7)
	assert(not sample.enabled and furniture._instances.is_empty() and furniture._hidden.is_empty() and furniture._loaded.is_empty() and furniture._materials.is_empty())
	for name_ in ["BuiltShelter/Cot","BuiltShelter/Bedroll","BuiltShelter/QuiltFold","BuiltStorage/Body","BuiltStorage/Lid","BuiltStorage/FrontHandle"]: assert(_visual(name_).visible,"F7 restores real original visibility")
	_key(KEY_F7)
	var storage: Node3D = game._ark_node("BuiltStorage")
	game.ark_root.remove_child(storage)
	sample.apply(game)
	assert(storage.get_node("Body").get_child(0).visible and not furniture._instances.has("PantryCabinetFurniture"),"temporary detachment restores old mesh visibility and removes its floating skin")
	game.ark_root.add_child(storage)
	sample.apply(game)
	_assert_model("PantryCabinetFurniture",Vector3(.98,.86,.86),322)
	assert(collisions==_collisions() and game.MemoryScript.facts_equal(before,game._build_save_state()))
	_visit("shellfish")
	await process_frame
	var food: int = game.raw_shellfish
	assert(food>0)
	game.player.global_position = storage.global_position+Vector3(0,.3,1)
	_key(KEY_G)
	assert(game.food_storage.pending)
	_key(KEY_1)
	assert(game.raw_shellfish==0 and game.economy.inventory("storage_food","shellfish")==food)
	await _capture("02_real_pantry")
	_key(KEY_G)
	_key(KEY_3)
	assert(game.raw_shellfish==1 and game.economy.inventory("storage_food","shellfish")==food-1,"new visible cabinet still uses actual old pantry transfer commands")
	game.player_health = 2 # Declared injury fixture, not an earned event.
	var period: int = game.day_period
	_visit("cot")
	assert(game.player_health==game.PLAYER_MAX_HEALTH and game.day_period==(period+1)%4,"visible new bed retains actual rest/health/time interaction")
	await _capture("03_rest_after_use")
	for i in 3: game._advance_world_period("furniture_test_calendar")
	_visit("wood")
	await process_frame
	_visit("keel_wreck")
	game.player.position = Vector3(0,1.1,1.75)
	assert(game._try_place_raft_extension(Vector3(0,.12,-4.2)))
	_visit("jade_sail_ark")
	game.player.position = Vector3(0,1.1,1.75)
	assert(game._try_place_guest_cabin_template(Vector3(0,.12,-4.2)))
	sample.apply(game)
	_assert_model("GuestCotFurniture",Vector3(.9,.68,1.48),534)
	_assert_model("GuestCabinetFurniture",Vector3(.42,.52,.44),322)
	assert(furniture._instances.size()==5 and furniture._hidden.size()==10)
	var guest := game._ark_node("BuiltRaftExtension/GuestCabin") as Node3D
	var canopy := guest.get_node("CanvasAwning") as Node3D
	var view_state: Dictionary = game._build_save_state()
	var view_collisions := _collisions()
	var view_lights := _lights()
	var player_position: Vector3 = game.player.global_position
	game.player.global_position = guest.to_global(Vector3(0,.5,.3))
	game._update_shelter_roof_cutaway()
	assert(not canopy.visible and guest.is_visible_in_tree(),"the occupied room opens visually without hiding the gameplay room root")
	_key(KEY_F7)
	assert(canopy.visible and sample.room_view._hidden.is_empty(),"F7 restores the authentic canopy visibility")
	_key(KEY_F7)
	assert(not canopy.visible)
	game.player.global_position = player_position
	game._update_shelter_roof_cutaway()
	assert(canopy.visible and not sample.room_view._hidden.has(canopy.get_instance_id()),"leaving the guest room restores its canopy")
	assert(game.MemoryScript.facts_equal(view_state,game._build_save_state()) and view_collisions==_collisions() and view_lights==_lights(),"camera cutaway never changes stock, facts, collision or light ownership")
	await _capture("04_paid_guest_cabin")
	var saved: Dictionary = game._build_save_state()
	assert(saved.schema_version==43 and not saved.has("cabin_furniture") and game._save_progress())
	var changed := saved.duplicate(true)
	changed.wood += 1
	assert(not game.MemoryScript.facts_equal(_disk_view(saved),_disk_view(changed)),"only JSON representation and the separately checked generation are normalized")
	for i in 5:
		var generation: int = game.gathering.snapshot().generation
		game._load_progress()
		await physics_frame
		var restored: Dictionary = game._build_save_state()
		if not game.MemoryScript.facts_equal(_disk_view(saved),_disk_view(restored)): _diff(_disk_view(saved),_disk_view(restored))
		assert(not game.get_meta("save_load_blocked",false) and game.MemoryScript.facts_equal(_disk_view(saved),_disk_view(restored)))
		assert(game.gathering.snapshot().generation==generation+1,"old asynchronous route results remain invalid after restoration")
		assert(sample.furniture._instances.size()==5 and sample.furniture._hidden.size()==10)
		assert(sample._decor.size()==3,"no additional independent global decor roots or ever-growing node caches")
	var end_state: Dictionary = game._build_save_state()
	_key(KEY_F7)
	_key(KEY_F7)
	assert(game.MemoryScript.facts_equal(end_state,game._build_save_state()) and game.economy.audit().ok)
	game.save_service = null
	game.free()
	service.clear_for_test()
	print("ARK_CABIN_FURNITURE_TEST_OK: actual finite paid starter/guest homes, imported geometry, reversible visibility, no physics/lights/save owner changes, real pantry/rest, detached recovery and repeated reload")
	quit()
