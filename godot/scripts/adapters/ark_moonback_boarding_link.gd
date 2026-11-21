extends RefCounted
## A bounded physical boarding leaf, derived from the two original supports.
## No actor, vessel, water, inventory, or saved-state ownership.
const WIDTH := .85
const THICKNESS := .025
const LAP := .008
const TOP_CLEARANCE := .002
const MAX_SLOPE := deg_to_rad(25.0)
const BODY_NAME := "MoonbackBoardingLink"
var body: StaticBody3D
var shapes: Array[CollisionShape3D] = []
var meshes: Array[MeshInstance3D] = []
var active := false
var revision := 0
var diagnostic := {}
var _key: Array = []
var _held_notice := false

func navigation_exclusion() -> RID:
	# Only this adapter's actual body, never an arbitrary matching node name.
	return body.get_rid() if active and is_instance_valid(body) else RID()

func _box(node: Node) -> CollisionShape3D:
	if not is_instance_valid(node): return null
	for child in node.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D: return child
	return null

func _valid_box(shape: CollisionShape3D) -> bool:
	if not is_instance_valid(shape) or not shape.shape is BoxShape3D or shape.disabled: return false
	var size: Vector3 = shape.shape.size
	return size.is_finite() and size.x > 0 and size.y > 0 and size.z > 0 and shape.global_transform.is_finite() and shape.global_basis.is_equal_approx(shape.global_basis.orthonormalized()) and is_equal_approx(shape.global_basis.determinant(),1.0)

func _corners(shape: CollisionShape3D) -> PackedVector2Array:
	var half: Vector3 = shape.shape.size*.5
	var result := PackedVector2Array()
	for p in [Vector3(-half.x,half.y,-half.z),Vector3(half.x,half.y,-half.z),Vector3(half.x,half.y,half.z),Vector3(-half.x,half.y,half.z)]:
		var q := shape.to_global(p)
		result.append(Vector2(q.x,q.z))
	return result

func _cross(a: Vector2,b: Vector2) -> float: return a.x*b.y-a.y*b.x
func _area(poly: PackedVector2Array) -> float:
	if poly.size() < 3: return 0.0
	var value := 0.0
	for i in poly.size(): value += _cross(poly[i],poly[(i+1)%poly.size()])
	return absf(value)*.5

func _clip(poly: PackedVector2Array,bounds: PackedVector2Array) -> PackedVector2Array:
	var result := poly
	for i in bounds.size():
		var a := bounds[i]
		var edge := bounds[(i+1)%bounds.size()]-a
		var next := PackedVector2Array()
		for j in result.size():
			var p := result[j]
			var q := result[(j+1)%result.size()]
			var fp := _cross(edge,p-a)
			var fq := _cross(edge,q-a)
			if fp >= -0.0000001: next.append(p)
			if (fp >= 0) != (fq >= 0) and absf(fp-fq) > 0.0000001: next.append(p+(q-p)*(fp/(fp-fq)))
		result = next
		if result.is_empty(): break
	return result

func _point_segment(p: Vector2,a: Vector2,b: Vector2) -> float:
	var edge := b-a
	if edge.length_squared() < 0.0000001: return p.distance_to(a)
	return p.distance_to(a+edge*clampf((p-a).dot(edge)/edge.length_squared(),0,1))

func _gap(a: PackedVector2Array,b: PackedVector2Array) -> float:
	if _area(_clip(a,b)) > 0.0000001: return 0.0
	var result := INF
	for p in a:
		for i in b.size(): result = minf(result,_point_segment(p,b[i],b[(i+1)%b.size()]))
	for p in b:
		for i in a.size(): result = minf(result,_point_segment(p,a[i],a[(i+1)%a.size()]))
	return result

func _inside(p: Vector2,poly: PackedVector2Array,margin: float) -> bool:
	for i in poly.size():
		var edge := poly[(i+1)%poly.size()]-poly[i]
		if edge.length_squared() < .0000001 or _cross(edge,p-poly[i]) < margin*edge.length()-.000001: return false
	return true

func _point_polygon(p: Vector2,poly: PackedVector2Array) -> float:
	if _inside(p,poly,0): return 0.0
	var distance := INF
	for i in poly.size(): distance = minf(distance,_point_segment(p,poly[i],poly[(i+1)%poly.size()]))
	return distance

func _rectangle(a: Vector2,b: Vector2,c: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a-c*WIDTH*.5,a+c*WIDTH*.5,b+c*WIDTH*.5,b-c*WIDTH*.5])

func plan(world: Node3D) -> Dictionary:
	var boat := _box(world.get_node_or_null("ArkRoot/RaftBoardingGangplank"))
	var pier := _box(world.get_node_or_null("MoonbackOldLanding/PierDeck"))
	if not _valid_box(boat) or not _valid_box(pier): return {"ok":false,"reason":"missing_or_invalid_support"}
	if not boat.shape.size.is_equal_approx(Vector3(1,.12,1.2)) or not pier.shape.size.is_equal_approx(Vector3(1.6,.24,5.2)): return {"ok":false,"reason":"support_contract"}
	if not pier.global_basis.is_equal_approx(Basis.IDENTITY) or not pier.global_position.is_equal_approx(Vector3(-17,-.02,15.75)): return {"ok":false,"reason":"pier_transform"}
	if not world.ark_root.global_transform.is_finite() or not boat.global_transform.is_equal_approx(world.ark_root.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,.04,2.72))) or not boat.global_basis.y.is_equal_approx(Vector3.UP): return {"ok":false,"reason":"boat_transform"}
	var yaw: float = wrapf(world.ark_root.global_rotation.y,-PI,PI)
	if not is_finite(yaw) or absf(yaw) > .12: return {"ok":false,"reason":"yaw"}
	var p := _corners(boat)
	var q := _corners(pier)
	var start3 := boat.to_global(Vector3(0,boat.shape.size.y*.5,boat.shape.size.z*.5-.42))
	var end3 := pier.to_global(Vector3(0,pier.shape.size.y*.5,-pier.shape.size.z*.5+.40))
	if not start3.is_finite() or not end3.is_finite(): return {"ok":false,"reason":"nonfinite_anchor"}
	var a := Vector2(start3.x,start3.z)
	var b := Vector2(end3.x,end3.z)
	var length := a.distance_to(b)
	if not is_finite(length) or length < .0001: return {"ok":false,"reason":"degenerate_span"}
	var d := (b-a)/length
	var c := Vector2(d.y,-d.x)
	var height := start3.y-end3.y
	var gap := _gap(p,q)
	var state := {"ok":false,"reason":"bounds","gap":gap,"height":height,"span":length+.24,"yaw":yaw}
	if d.y <= .6 or absf(height) > .22 or length+.24 > 1.65 or not is_finite(gap) or gap > .45: return state
	for side in [-1,1]:
		if not _inside(a+c*WIDTH*.5*side,p,.005) or not _inside(b+c*WIDTH*.5*side,q,.005):
			state.reason = "anchor_width"
			return state
	var slope_start := a
	var slope_end := b
	if height < -.000001:
		var north := q[0].y
		var cut := (b.y-(north-LAP-absf(c.y)*WIDTH*.5))/d.y
		slope_end = b-d*cut
	elif height > .000001:
		var limit := -INF
		for corner in p: limit = maxf(limit,(corner-a).dot(d))
		slope_start = a+d*(limit+LAP)
	var run := (slope_end-slope_start).dot(d)
	var angle := atan2(absf(height),run)
	state.merge({"run":run,"angle":angle})
	if not is_finite(run) or not is_finite(angle) or run < .20 or angle > MAX_SLOPE:
		state.reason = "slope"
		return state
	var first := _rectangle(a-d*.12,slope_start+d*LAP,c)
	var last := _rectangle(slope_end-d*LAP,b+d*.12,c)
	var first_area := _area(_clip(first,p))
	var last_area := _area(_clip(last,q))
	state.merge({"boat_overlap":first_area,"pier_overlap":last_area})
	if first_area < .08 or last_area < .08:
		state.reason = "support_area"
		return state
	# Keep the original pier/shore in the original hull query; only our own
	# currently active leaf may be excluded by the caller's explicit RID hook.
	if not world._is_ark_position_navigable(world.ark_root.global_position):
		state.reason = "original_hull_blocked"
		return state
	state.merge({"ok":true,"reason":"connected","a":a,"b":b,"c":slope_start,"d":slope_end,"direction":d,"boat_y":start3.y+TOP_CLEARANCE,"pier_y":end3.y+TOP_CLEARANCE},true)
	return state

func _ensure(world: Node3D) -> bool:
	if is_instance_valid(body): return true
	# An unexpected same-name object is not adopted or excluded from navigation.
	if world.has_node(BODY_NAME): return false
	body = StaticBody3D.new()
	body.name = BODY_NAME
	world.add_child(body)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/ark_home_timber.gdshader")
	material.set_shader_parameter("timber_albedo",load("res://art/home_sample/home_timber_albedo_v1.png"))
	for i in 3:
		var shape := CollisionShape3D.new()
		shape.name = "LeafCollision%d" % i
		shape.shape = BoxShape3D.new()
		shape.disabled = true
		body.add_child(shape)
		shapes.append(shape)
		var mesh := MeshInstance3D.new()
		mesh.name = "TimberLeaf%d" % i
		mesh.mesh = BoxMesh.new()
		mesh.material_override = material
		mesh.visible = false
		body.add_child(mesh)
		meshes.append(mesh)
	return true

func _piece(index: int,a: Vector2,b: Vector2,ay: float,by: float) -> void:
	var start := Vector3(a.x,ay,a.y)
	var end := Vector3(b.x,by,b.y)
	var z := (end-start).normalized()
	var x := Vector3(z.z,0,-z.x).normalized()
	var y := z.cross(x).normalized()
	var transform := Transform3D(Basis(x,y,z),(start+end)*.5-y*THICKNESS*.5)
	var size := Vector3(WIDTH,THICKNESS,start.distance_to(end))
	shapes[index].shape.size = size
	shapes[index].global_transform = transform
	meshes[index].mesh.size = size
	meshes[index].global_transform = transform
	shapes[index].disabled = false
	meshes[index].visible = true

func deactivate() -> bool:
	# Called outside query-flush callbacks; verify real shape state, not a flag.
	if active and (not is_instance_valid(body) or shapes.size() != 3): return false
	var changed := active
	for shape in shapes:
		if not is_instance_valid(shape): return false
		changed = changed or not shape.disabled
		shape.disabled = true
	for shape in shapes:
		if not shape.disabled: return false
	for mesh in meshes:
		if is_instance_valid(mesh): mesh.visible = false
	active = false
	_key.clear()
	if changed: revision += 1
	return true

func _stable_original(world: Node3D,foot: Vector3,radius: float) -> bool:
	for path in ["ArkRoot/RaftBase","ArkRoot/RaftBoardingGangplank","MoonbackOldLanding/PierDeck"]:
		var shape := _box(world.get_node_or_null(path))
		if not _valid_box(shape): continue
		var normal := shape.global_basis.y.normalized()
		if normal.dot(Vector3.UP) < cos(world.player.floor_max_angle): continue
		var half: Vector3 = shape.shape.size*.5
		var top := shape.to_global(Vector3(0,half.y,0))
		var height := top.y-(normal.x*(foot.x-top.x)+normal.z*(foot.z-top.z))/normal.y
		if _inside(Vector2(foot.x,foot.z),_corners(shape),radius+.02) and absf(foot.y-height) <= .025: return true
	return false

func occupants(world: Node3D) -> Array[String]:
	var result: Array[String] = []
	if not active: return result
	for spec in [[world.player,.38,-.005,"你"],[world.traveler_marker,.18,-.12,"守岸人"],[world.sailmaker_marker,.18,-.12,"缝帆人"]]:
		var actor: Node3D = spec[0]
		if not is_instance_valid(actor): continue
		var foot := actor.global_position+Vector3.UP*float(spec[2])
		if not foot.is_finite():
			result.append(str(spec[3])+"的位置异常")
			continue
		var radius: float = spec[1]
		var on_leaf := false
		for shape in shapes:
			if not is_instance_valid(shape) or shape.disabled: continue
			var normal := shape.global_basis.y.normalized()
			var half: Vector3 = shape.shape.size*.5
			var top := shape.to_global(Vector3(0,half.y,0))
			var height := top.y-(normal.x*(foot.x-top.x)+normal.z*(foot.z-top.z))/normal.y
			var outside := _point_polygon(Vector2(foot.x,foot.z),_corners(shape))
			if outside <= radius and foot.y >= height-.05 and foot.y <= height+2.0: on_leaf = true
		if not on_leaf: continue
		var resting: bool = actor != world.player or (world.player.is_on_floor() and world.player.velocity.y <= .1)
		if resting and _stable_original(world,foot,radius): continue
		result.append(str(spec[3]))
	return result

func refresh(world: Node3D) -> Dictionary:
	if not world._modules_ready or not is_instance_valid(world.ark_root): return {}
	var key: Array = [world.ark_root.global_transform,world.sailing_mode]
	var boat := _box(world.get_node_or_null("ArkRoot/RaftBoardingGangplank"))
	var pier := _box(world.get_node_or_null("MoonbackOldLanding/PierDeck"))
	for shape in [boat,pier]:
		key.append([shape.global_transform,shape.shape.size,shape.disabled] if is_instance_valid(shape) else null)
	if key == _key: return {}
	if active and not occupants(world).is_empty():
		# Preserve the last real support instead of moving/removing it under feet.
		if _held_notice: return {}
		_held_notice = true
		return {"notice":"接驳状态有变化，请先走到原甲板或栈桥的稳固位置，再调整泊位。"}
	_held_notice = false
	if world.sailing_mode:
		if not deactivate(): return {"notice":"接驳板状态异常，请先保持停船。"}
		_key = key
		return {}
	var next := plan(world)
	diagnostic = next.duplicate()
	if not next.ok:
		if not deactivate(): return {"notice":"接驳板状态异常，请先保持停船。"}
		_key = key
		return {}
	if not _ensure(world):
		diagnostic = {"ok":false,"reason":"unexpected_body_identity"}
		return {}
	var direction: Vector2 = next.direction
	_piece(0,next.a-direction*.12,next.c+direction*LAP,next.boat_y,next.boat_y)
	_piece(1,next.c,next.d,next.boat_y,next.pier_y)
	_piece(2,next.d-direction*LAP,next.b+direction*.12,next.pier_y,next.pier_y)
	active = true
	revision += 1
	_key = key
	return {}
