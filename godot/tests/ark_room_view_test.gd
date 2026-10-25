extends "res://tests/ark_cabin_furniture_test.gd"
## Real finite paid builds from the furniture flow; only viewpoints are fixtures.
var covered := {}

func _capture(stage: String) -> void:
	if stage == "01_paid_starter_home":
		_exercise("BuiltShelter", false)
		_storm_cycle()
	elif stage == "04_paid_guest_cabin":
		_exercise("BuiltRaftExtension/GuestCabin", true)
		_neighbor_transition()
		assert(covered.size() == 2)
		print("ARK_ROOM_VIEW_TEST_OK: perspective/orthogonal 360 sight lines, low-wall silhouettes, no physical/economic edits, F7/leave/swim/detach restoration")

func _exercise(path: String, guest: bool) -> void:
	var room := game._ark_node(path) as Node3D
	var sample = game.home_art_sample
	var view = sample.room_view
	var player_pose: Transform3D = game.player.global_transform
	var camera_pose: Transform3D = game.camera.global_transform
	var projection: int = game.camera.projection
	var camera_size: float = game.camera.size
	var before: Dictionary = game._build_save_state()
	var collisions := _collisions()
	var lights := _lights()
	var inside := Vector3(0,.3,.3) if guest else Vector3(0,.2,0)
	game.player.global_position = room.to_global(inside)
	var inside_collisions := _collisions()
	var wall_ids := {}
	for mode in [Camera3D.PROJECTION_PERSPECTIVE, Camera3D.PROJECTION_ORTHOGONAL]:
		game.camera.projection = mode
		game.camera.size = 6.5
		for direction in [Vector3(0,3.5,5),Vector3(5,3.5,0),Vector3(0,3.5,-5),Vector3(-5,3.5,0)]:
			var target := room.to_global(Vector3(0,.8,0))
			game.camera.global_position = target + room.global_basis*direction
			game.camera.look_at(target)
			game._update_shelter_roof_cutaway()
			assert(room.is_visible_in_tree())
			for entry in view._hidden.values():
				var visual: MeshInstance3D = entry.node.get_ref()
				assert(not visual.visible)
				assert(visual.get_parent().visible, "only mesh visibility changes, not physical/work roots")
			for id in view._caps:
				var cap: Node3D = view._caps[id].node.get_ref()
				if cap.visible:
					wall_ids[id] = true
					assert(is_equal_approx(cap.get_node("LowWall").mesh.size.y, .40))
					assert(cap.find_children("*","CollisionObject3D",true,false).is_empty())
			assert(view._caps.size() <= 6 and view._rooms.size() <= 2)
	assert(wall_ids.size() >= 3, "actual camera angles must exercise all three enclosing walls")
	assert(inside_collisions == _collisions() and lights == _lights())
	var originals := []
	for entry in view._hidden.values(): originals.append(entry.duplicate())
	_key(KEY_F7)
	for entry in originals:
		assert(entry.node.get_ref().visible == view._baseline(entry))
	assert(view._hidden.is_empty() and view._caps.is_empty() and view._rooms.is_empty())
	_key(KEY_F7)
	game.is_swimming = true
	game._update_shelter_roof_cutaway()
	assert(view._hidden.is_empty(), "underwater/unsupported actors cannot open an occupied room")
	game.is_swimming = false
	game._update_shelter_roof_cutaway()
	var parent := room.get_parent()
	parent.remove_child(room)
	sample.apply(game)
	assert(view._hidden.is_empty() and view._caps.is_empty(), "detached architecture restores and drops its presentation ownership")
	parent.add_child(room)
	sample.apply(game)
	game.player.global_position = room.to_global(Vector3(0,.3,2.5))
	game._update_shelter_roof_cutaway()
	assert(view._hidden.is_empty(), "leaving restores complete room walls and canopy")
	game.player.global_transform = player_pose
	game.camera.projection = projection
	game.camera.size = camera_size
	game.camera.global_transform = camera_pose
	game._update_shelter_roof_cutaway()
	assert(game.MemoryScript.facts_equal(before, game._build_save_state()))
	assert(collisions == _collisions() and lights == _lights())
	covered[path] = true

func _neighbor_transition() -> void:
	var guest := game._ark_node("BuiltRaftExtension/GuestCabin") as Node3D
	var home := game._ark_node("BuiltShelter") as Node3D
	var face := home.get_node("Roof/CenterFace") as MeshInstance3D
	var player_pose: Transform3D = game.player.global_transform
	var camera_pose: Transform3D = game.camera.global_transform
	var projection: int = game.camera.projection
	game.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	var target := guest.to_global(Vector3(.45,.65,-.34))
	game.camera.global_position = target+Vector3(0,3,7)
	game.camera.look_at(target)
	game.player.global_position = guest.to_global(Vector3(0,.3,.3))
	game._update_shelter_roof_cutaway()
	assert(not face.visible and game.home_art_sample.room_view._hidden.has(face.get_instance_id()),"foreground primary roof must yield to the actual occupied guest cabin")
	game.player.global_position = home.to_global(Vector3(0,.2,0))
	game._update_shelter_roof_cutaway()
	assert(not face.visible and not game.home_art_sample.room_view._hidden.has(face.get_instance_id()),"entering the primary room restores its CURRENT core baseline, not the previously captured closed roof")
	game.player.global_position = home.to_global(Vector3(0,.2,2.3))
	game._update_shelter_roof_cutaway()
	assert(face.visible)
	game.player.global_transform = player_pose
	game.camera.global_transform = camera_pose
	game.camera.projection = projection
	game._update_shelter_roof_cutaway()

func _storm_cycle() -> void:
	var saved: Dictionary = game._build_save_state()
	var roof := game._ark_node("BuiltShelter/Roof") as Node3D
	var face := roof.get_node("CenterFace") as MeshInstance3D
	var wood: int = game.wood
	assert(wood >= 1)
	# Direct invocation of real storm damage; calendar/weather are not advanced.
	game._apply_storm_damage()
	assert(game.shelter_roof_damaged and not roof.visible)
	game.player.global_position = game._ark_node("BuiltShelter").to_global(Vector3(0,.2,0))
	for i in 8: game._update_shelter_roof_cutaway()
	_key(KEY_F7)
	assert(not roof.visible and not face.is_visible_in_tree(),"F7 cannot resurrect a storm-damaged roof")
	_key(KEY_F7)
	game.repair_choice_pending = true
	game._repair_damaged_part("shelter")
	assert(not game.shelter_roof_damaged and roof.visible and game.wood==wood-1,"real repair still spends exactly one earned wood")
	game._update_shelter_roof_cutaway()
	assert(not face.visible and not face.get_node("HomeArtCandidate").is_visible_in_tree(),"roof seam decorations inherit the actual cutaway face")
	var start := Time.get_ticks_usec()
	for i in 1000: game._update_shelter_roof_cutaway()
	print("ROOM_VIEW_CPU_OBSERVATION: 1000 calls average_usec=",float(Time.get_ticks_usec()-start)/1000.0," headless update-only; not FPS/GPU")
	assert(game.save_service.save_state(saved).ok)
	game._load_progress()
	assert(game.MemoryScript.facts_equal(_disk_view(saved),_disk_view(game._build_save_state())))
