extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_save_landmass_physics").simplify_path()
	var save_helper := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	save_helper.clear_for_test()
	var scene := load("res://scenes/ark_greybox.tscn") as PackedScene
	assert(scene != null, "the terrain fixture should load")
	var game := scene.instantiate()
	game.set("save_root_override", save_root)
	root.add_child(game)
	await process_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var island := game.get_node("FarReefLandmass") as StaticBody3D
	assert(island != null, "the distant reef should be a dedicated generated landmass")
	var moonback := game.get_node("MoonbackIsland") as StaticBody3D
	assert(moonback != null, "the second mooring should sit on a dedicated generated island")
	var grassland := island.get_node("Grassland") as MeshInstance3D
	var shoreline := island.get_node("Shoreline") as MeshInstance3D
	assert(grassland.mesh.get_faces().size() >= 1000, "the walkable island interior should use generated triangulated geometry, not a single box")
	assert(shoreline.mesh.get_faces().size() >= 900, "the shore should be a traversable irregular sloped mesh")
	for point in [Vector3(39.0, 0.0, -29.0), Vector3(36.0, 0.0, -32.0), Vector3(33.0, 0.0, -32.0)]:
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 4.0, point + Vector3.DOWN * 2.0)
		var hit: Dictionary = space.intersect_ray(query)
		assert(hit.get("collider") == island, "generated grass and irregular shoreline must both provide walkable collision at %s; got %s" % [point, hit])
		assert(float(hit.get("normal", Vector3.ZERO).y) > 0.0, "the land surface should face upward for ground movement")
	var moonback_grass := moonback.get_node("Grassland") as MeshInstance3D
	var moonback_shore := moonback.get_node("Shoreline") as MeshInstance3D
	assert(moonback_grass.mesh.get_faces().size() >= 1000 and moonback_shore.mesh.get_faces().size() >= 900, "the new mooring island should use the same triangulated walkable terrain and sloped shore")
	for point in [Vector3(-28.0, 0.0, 23.0), Vector3(-28.0, 0.0, 11.0), Vector3(-14.0, 0.0, 23.0)]:
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 5.0, point + Vector3.DOWN * 3.0)
		var hit: Dictionary = space.intersect_ray(query)
		assert(hit.get("collider") == moonback, "the second mooring interior and coast must provide walkable collision at %s; got %s" % [point, hit])
		assert(float(hit.get("normal", Vector3.ZERO).y) > 0.0, "the second island surface should face upward for ground movement")
	print("ARK_LANDMASS_PHYSICS_OK")
	game.queue_free()
	await process_frame
	save_helper.clear_for_test()
	quit(0)
