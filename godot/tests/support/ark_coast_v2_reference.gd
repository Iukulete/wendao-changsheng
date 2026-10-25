extends "res://tests/support/ark_opening_coast_reference.gd"
## Frozen V2 geometry oracle over the byte-pinned V1 generator. Do not import
## the live profile. The authored trail/plateau specification is repeated here
## intentionally so a production mutation cannot redefine its own acceptance.
const RIDGE_TRAIL := [Vector3(7.4,.08,-10.8), Vector3(6.2,.25,-13.6), Vector3(5.9,.65,-16.2), Vector3(7.2,1.25,-18.7), Vector3(9.6,2.35,-20), Vector3(11.4,2.75,-19.5), Vector3(10.6,3.1,-18.5)]
func height_profile(local: Vector2, radius_fraction: float) -> float:
	var old: float = super.height_profile(local, radius_fraction)
	var world := local + Vector2(11,-14)
	var edge := 1.0 - smoothstep(.72,.96,radius_fraction)
	var permission := edge
	for anchor in [Vector2(11,-7),Vector2(13,-6),Vector2(14.25,-6.45),Vector2(16,-10),Vector2(13.8,-11.8),Vector2(8.4,-6.1),Vector2(9,-4),Vector2(19,-5.5),Vector2(5,-7),Vector2(18,-13)]:
		permission *= smoothstep(1.45,2.4,world.distance_to(anchor))
	var ridge := 2.8 * exp(-((world-Vector2(9.4,-18.8))/Vector2(3.7,2.5)).length_squared())
	ridge += .7 * exp(-((world-Vector2(13,-20.1))/Vector2(3.2,1.45)).length_squared())
	var y := old + ridge * permission
	var camp := (1.0-smoothstep(.85,1.7,world.distance_to(Vector2(10.6,-18.5))))*permission
	y = lerpf(y,Vector3(10.6,3.1,-18.5).y,camp)
	var nearest := INF
	var path_y := 0.0
	for index in range(RIDGE_TRAIL.size()-1):
		var a := Vector2(RIDGE_TRAIL[index].x,RIDGE_TRAIL[index].z)
		var b := Vector2(RIDGE_TRAIL[index+1].x,RIDGE_TRAIL[index+1].z)
		var delta := b-a
		var t := clampf((world-a).dot(delta)/delta.length_squared(),0,1)
		var distance := world.distance_to(a+delta*t)
		if distance < nearest:
			nearest = distance
			path_y = lerpf(RIDGE_TRAIL[index].y,RIDGE_TRAIL[index+1].y,t)
	return lerpf(y,path_y,(1.0-smoothstep(.78,1.5,nearest))*edge)
