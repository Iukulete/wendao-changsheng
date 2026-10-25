extends SceneTree
const Scene = preload("res://scenes/ark_greybox.tscn")
var game: Node3D
var coast: RefCounted

func _initialize() -> void: _run.call_deferred()

# Deliberately retains the pre-optimization arithmetic and first-hit ordering.
func _reference(world_position: Vector3) -> Variant:
	var p: Vector3 = coast.island.to_local(world_position)
	for i in coast.ground_grid.get(Vector2i(int(floor(p.x)),int(floor(p.z))), []):
		var a: Vector3 = coast.top_faces_local[i]
		var b: Vector3 = coast.top_faces_local[i+1]
		var c: Vector3 = coast.top_faces_local[i+2]
		var ab := Vector2(b.x-a.x,b.z-a.z)
		var ac := Vector2(c.x-a.x,c.z-a.z)
		var ap := Vector2(p.x-a.x,p.z-a.z)
		var determinant := ab.cross(ac)
		if absf(determinant) < .0000001: continue
		var u := ap.cross(ac) / determinant
		var v := ab.cross(ap) / determinant
		if u >= -.00001 and v >= -.00001 and u+v <= 1.00001:
			return a.y + u*(b.y-a.y) + v*(c.y-a.y) + coast.island.global_position.y
	return null

func _run() -> void:
	game = Scene.instantiate()
	game.save_root_override = ProjectSettings.globalize_path("res://../.local/test_height_cache_%d" % OS.get_process_id()).simplify_path()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	coast = game.opening_coast
	var points := PackedVector3Array()
	# Dense cells, exact grid edges and both sides of triangle vertices/edges.
	for z in range(-24, 25):
		for x in range(-32, 33): points.append(Vector3(x * .5, 0, z * .5))
	for i in range(0, coast.top_faces_local.size() - 2, 87):
		var a: Vector3 = coast.top_faces_local[i]
		var b: Vector3 = coast.top_faces_local[i+1]
		for point in [a, a.lerp(b, .5), a.lerp(b, .25)]:
			for delta in [Vector3.ZERO, Vector3(.00001,0,0), Vector3(-.00001,0,0), Vector3(0,0,.00001), Vector3(0,0,-.00001)]:
				points.append(point + delta)
	var original: Transform3D = coast.island.global_transform
	var checked := 0
	for transform in [original, Transform3D(Basis.from_euler(Vector3(.04,.17,-.03)).scaled(Vector3(1.03,.97,1.01)), original.origin + Vector3(.2,.35,-.1))]:
		coast.island.global_transform = transform
		for point in points:
			var world: Vector3 = coast.island.to_global(point)
			var expected: Variant = _reference(world)
			var actual: Variant = coast.sample_height(world)
			assert(actual == expected, "height cache changed exact first-hit result at %s: %s / %s" % [point, actual, expected])
			checked += 1
	coast.island.global_transform = original
	var before: Dictionary = coast.ground_grid.duplicate(true)
	coast._build_height_index()
	assert(coast.ground_grid == before)
	for point in points: assert(coast.sample_height(coast.island.to_global(point)) == _reference(coast.island.to_global(point)))
	print("ARK_COAST_HEIGHT_CACHE_TEST_OK: ", checked, " exact original arithmetic comparisons; dense cells, shared-edge +/- tolerance, transformed island, ordered index rebuild")
	game.save_service = null
	game.free()
	quit(0)
