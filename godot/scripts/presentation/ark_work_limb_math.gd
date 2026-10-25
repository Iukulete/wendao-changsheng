extends RefCounted
## Shared tiny pose math; transient presentation, never navigation or resources.
static func segment(node: MeshInstance3D,a: Vector3,b: Vector3) -> void:
	var direction := b-a
	var y := direction.normalized()
	var x := Vector3.FORWARD.cross(y).normalized()
	if x.is_zero_approx(): x = Vector3.RIGHT.cross(y).normalized()
	node.transform = Transform3D(Basis(x,y,x.cross(y)),(a+b)*.5)
	node.scale = Vector3(1,direction.length(),1)

static func elbow(shoulder: Vector3,target: Vector3,rest_length: float,side: float) -> Vector3:
	var offset := target-shoulder
	var distance := offset.length()
	var direction := offset.normalized()
	var bend := Vector3(side,0,0)
	bend = (bend-direction*bend.dot(direction)).normalized()
	var length: float = maxf(rest_length,distance*.501)
	return (shoulder+target)*.5+bend*sqrt(maxf(0,length*length-distance*distance*.25))
