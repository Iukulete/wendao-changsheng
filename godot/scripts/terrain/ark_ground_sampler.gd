extends RefCounted
## Immutable contact index for non-opening land; opening coast owns its own cache.
## Samples the installed collider faces, not an independent analytic landscape.
const CELL := 2.0
var regions: Array[Dictionary] = []

func rebuild(world: Node3D) -> void:
	regions.clear()
	for name_ in ["FarReefLandmass","MoonbackIsland","JadeSailShoal","SteamWreckIslet"]:
		var island := world.get_node(name_) as StaticBody3D
		var triangles: Array[Dictionary] = []
		var grid := {}
		for part in ["ShorelineCollision","GrasslandCollision"]:
			var shape := island.get_node(part) as CollisionShape3D
			var faces: PackedVector3Array = shape.shape.get_faces()
			for i in range(0,faces.size(),3):
				var a := shape.global_transform*faces[i]
				var b := shape.global_transform*faces[i+1]
				var c := shape.global_transform*faces[i+2]
				var ab := Vector2(b.x-a.x,b.z-a.z)
				var ac := Vector2(c.x-a.x,c.z-a.z)
				var det := ab.cross(ac)
				if absf(det) < .0000001: continue
				var index := triangles.size()
				triangles.append({"a":a,"ab":ab,"ac":ac,"det":det,"by":b.y-a.y,"cy":c.y-a.y})
				for x in range(floori(minf(a.x,minf(b.x,c.x))/CELL),floori(maxf(a.x,maxf(b.x,c.x))/CELL)+1):
					for z in range(floori(minf(a.z,minf(b.z,c.z))/CELL),floori(maxf(a.z,maxf(b.z,c.z))/CELL)+1):
						var key := Vector2i(x,z)
						if not grid.has(key): grid[key] = PackedInt32Array()
						grid[key].append(index)
		regions.append({"node":weakref(island),"transform":island.global_transform,"triangles":triangles,"grid":grid})

func sample_height(point: Vector3) -> Variant:
	var result: Variant = null
	var key := Vector2i(floori(point.x/CELL),floori(point.z/CELL))
	for region in regions:
		var node := region.node.get_ref() as Node3D
		# Never return stale support after an unsupported runtime transform change.
		if node == null or node.global_transform != region.transform: continue
		for index in region.grid.get(key,PackedInt32Array()):
			var triangle: Dictionary = region.triangles[index]
			var a: Vector3 = triangle.a
			var ap := Vector2(point.x-a.x,point.z-a.z)
			var u := ap.cross(triangle.ac)/float(triangle.det)
			var v: float = (triangle.ab as Vector2).cross(ap)/float(triangle.det)
			if u >= -.00001 and v >= -.00001 and u+v <= 1.00001:
				var h: float = a.y+u*triangle.by+v*triangle.cy
				if result == null or h > float(result): result = h
	return result
