extends RefCounted
## Immutable land-shape specification. Geometry, physics and water raster all
## consume the same resulting triangles; this never displaces a render mesh.
const VERSION := 2
const CAMP := Vector3(10.6, 3.1, -18.5)
const TRAIL := [
	Vector3(7.4, .08, -10.8), Vector3(6.2, .25, -13.6),
	Vector3(5.9, .65, -16.2), Vector3(7.2, 1.25, -18.7),
	Vector3(9.6, 2.35, -20.0), Vector3(11.4, 2.75, -19.5), CAMP,
]
const PROTECTED := [
	Vector2(11,-7), Vector2(13,-6), Vector2(14.25,-6.45),
	Vector2(16,-10), Vector2(13.8,-11.8), Vector2(8.4,-6.1),
	Vector2(9,-4), Vector2(19,-5.5), Vector2(5,-7), Vector2(18,-13),
]

static func trail_sample(world: Vector2) -> Dictionary:
	var nearest := INF
	var height := 0.0
	var segment_index := -1
	for index in range(TRAIL.size() - 1):
		var a := Vector2(TRAIL[index].x, TRAIL[index].z)
		var b := Vector2(TRAIL[index + 1].x, TRAIL[index + 1].z)
		var delta := b - a
		var t := clampf((world - a).dot(delta) / delta.length_squared(), 0, 1)
		var distance := world.distance_to(a + delta * t)
		if distance < nearest:
			nearest = distance
			height = lerpf(TRAIL[index].y, TRAIL[index + 1].y, t)
			segment_index = index
	return {"distance": nearest, "height": height, "segment": segment_index}

static func height(local: Vector2, radius: float, legacy: float) -> float:
	var world := local + Vector2(11, -14)
	var edge := 1.0 - smoothstep(.72, .96, radius)
	var permission := edge
	for anchor in PROTECTED:
		permission *= smoothstep(1.45, 2.4, world.distance_to(anchor))
	var ridge := 2.8 * exp(-((world - Vector2(9.4, -18.8)) / Vector2(3.7, 2.5)).length_squared())
	ridge += .7 * exp(-((world - Vector2(13.0, -20.1)) / Vector2(3.2, 1.45)).length_squared())
	var result := legacy + ridge * permission
	var camp_weight := (1.0 - smoothstep(.85, 1.7, world.distance_to(Vector2(CAMP.x, CAMP.z)))) * permission
	result = lerpf(result, CAMP.y, camp_weight)
	var path := trail_sample(world)
	var path_weight := (1.0 - smoothstep(.78, 1.5, float(path.distance))) * edge
	return lerpf(result, float(path.height), path_weight)
