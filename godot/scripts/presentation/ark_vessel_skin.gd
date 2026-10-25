extends RefCounted
## Earned silhouette: lashed starter timbers become a shallow keel hull only
## after the real expansion is built. Original deck/rail/support physics remain.
var _hidden := {}
var _root: WeakRef
var _key := ""

func apply(world: Node3D, parent: Node3D, materials: Dictionary) -> void:
	var ark := world.get_node_or_null("ArkRoot") as Node3D
	if ark == null or parent == null:
		restore()
		return
	var base := ark.get_node_or_null("RaftBase") as Node3D
	var visual := base.get_child(0) as MeshInstance3D if base != null and base.get_child_count() > 0 else null
	if visual == null: return
	var expanded := ark.get_node_or_null("BuiltRaftExtension") as Node3D
	var bow := ark.get_node_or_null("RaftBow") as Node3D
	var front := bow.position.z - .05 if bow != null else -2.25
	var key := "%d:%d:%.4f" % [parent.get_instance_id(),expanded.get_instance_id() if expanded != null else 0,front]
	var node: Node3D = _root.get_ref() if _root != null else null
	if key != _key or not is_instance_valid(node):
		restore()
		node = Node3D.new()
		node.name = "VesselSilhouette"
		parent.add_child(node)
		_root = weakref(node)
		_key = key
		if expanded == null: _starter(node,materials)
		else: _keel(node,front,materials)
	_hide(visual)
	if expanded != null:
		for path in ["RaftBow","RaftPort","RaftStarboard","RaftSternPort","RaftSternStarboard"]:
			var rail := ark.get_node_or_null(path)
			if rail != null and rail.get_child_count() > 0: _hide(rail.get_child(0) as MeshInstance3D)
	_update_rail_caps(ark,parent)

func _hide(visual: MeshInstance3D) -> void:
	if visual == null: return
	var id := visual.get_instance_id()
	if not _hidden.has(id): _hidden[id] = {"node":weakref(visual),"visible":visual.visible}
	visual.visible = false

func _batch(parent: Node3D, name_: String, mesh: Mesh, material: Material, poses: Array[Transform3D]) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = poses.size()
	for index in poses.size(): multi.set_instance_transform(index,poses[index])
	var visual := MultiMeshInstance3D.new()
	visual.name = name_
	visual.multimesh = multi
	visual.material_override = material
	parent.add_child(visual)
	return visual

func _starter(parent: Node3D, materials: Dictionary) -> void:
	parent.set_meta("vessel_stage","lashed_timbers")
	var log := CylinderMesh.new()
	log.top_radius = .58
	log.bottom_radius = .60
	log.height = 4.42
	log.radial_segments = 16
	log.rings = 1
	var poses: Array[Transform3D] = []
	for x in [-2.1,0.0,2.1]: poses.append(Transform3D(Basis.IDENTITY,Vector3(x,0,0)))
	var pontoons := _batch(parent,"BuoyancyTimbers",log,materials.timber,poses)
	pontoons.rotation.x = PI*.5
	pontoons.position.y = -.60
	var beams: Array[Transform3D] = []
	for z in [-1.65,1.65]: beams.append(Transform3D(Basis.from_scale(Vector3(5.85,.14,.15)),Vector3(0,-.04,z)))
	_batch(parent,"CrossBraces",BoxMesh.new(),materials.dark,beams)
	var lashings: Array[Transform3D] = []
	for x in [-2.67,2.67]:
		for z in [-1.65,1.65]:
			for offset in [-.055,0.0,.055]:
				lashings.append(Transform3D(Basis.from_scale(Vector3(.40,.035,.022)),Vector3(x,.103,z+offset)))
	_batch(parent,"DeckLashings",BoxMesh.new(),materials.rope,lashings)

func _keel(parent: Node3D, front: float, materials: Dictionary) -> void:
	parent.set_meta("vessel_stage","shallow_keel")
	var back := 2.24
	var center := (front+back)*.5
	# Above-water freeboard follows the existing physical rail envelope. The
	# central stern opening stays open down to deck level for the real gangplank.
	var rim: Array[Vector3] = [Vector3(-2.52,.57,front),Vector3(2.52,.57,front),Vector3(2.94,.57,front+.42),Vector3(2.99,.57,back-.38),Vector3(2.60,.57,back),Vector3(.56,.57,back),Vector3(-.56,.57,back),Vector3(-2.60,.57,back),Vector3(-2.99,.57,back-.38),Vector3(-2.94,.57,front+.42)]
	var rings: Array = [rim]
	for profile in [Vector3(.965,.02,.97),Vector3(.79,-1.20,.89)]:
		var ring: Array[Vector3] = []
		for point in rim: ring.append(Vector3(point.x*profile.x,profile.y,center+(point.z-center)*profile.z))
		rings.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 2:
		for index in rim.size():
			if row == 0 and index == 5: continue
			var next := (index+1)%rim.size()
			var normal: Vector3 = ((rings[row][index]+rings[row][next])*.5-Vector3(0,0,center))
			normal.y = .35
			_quad(st,rings[row][index],rings[row][next],rings[row+1][next],rings[row+1][index],normal.normalized())
	for index in rim.size(): _triangle(st,Vector3(0,-1.20,center),rings[2][index],rings[2][(index+1)%rim.size()],Vector3.DOWN)
	var hull := MeshInstance3D.new()
	hull.name = "ShapedHull"
	hull.mesh = st.commit()
	hull.material_override = materials.timber
	parent.add_child(hull)
	# A narrow teal wale follows the faceted hull, not an oversized solid block.
	var belt := SurfaceTool.new()
	belt.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in rim.size():
		if index == 5: continue
		var next := (index+1)%rim.size()
		var a: Vector3 = rim[index].lerp(rings[1][index],.30)
		var b: Vector3 = rim[next].lerp(rings[1][next],.30)
		var c: Vector3 = rim[next].lerp(rings[1][next],.51)
		var d: Vector3 = rim[index].lerp(rings[1][index],.51)
		var normal := Vector3((a.x+b.x)*.5,0,(a.z+b.z)*.5-center).normalized()
		_quad(belt,a+normal*.006,b+normal*.006,c+normal*.006,d+normal*.006,normal)
	var wale := MeshInstance3D.new()
	wale.name = "PaintedWale"
	wale.mesh = belt.commit()
	wale.material_override = materials.trim
	parent.add_child(wale)
	var keel := BoxMesh.new()
	keel.size = Vector3(.20,.12,(back-front)*.82)
	var spine := MeshInstance3D.new()
	spine.name = "ProtectedKeel"
	spine.mesh = keel
	spine.position = Vector3(0,-1.24,center)
	spine.material_override = materials.dark
	parent.add_child(spine)

func _triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,normal: Vector3) -> void:
	if (b-a).cross(c-a).dot(normal) > 0:
		var swap := b
		b = c
		c = swap
	for point in [a,b,c]:
		st.set_normal(normal)
		st.add_vertex(point)

func _quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,normal: Vector3) -> void:
	var face := (b-a).cross(d-a).normalized()
	if face.dot(normal) < 0: face = -face
	_triangle(st,a,b,c,face)
	_triangle(st,a,c,d,face)

func _update_rail_caps(ark: Node3D,parent: Node3D) -> void:
	var caps := parent.get_node_or_null("CappedGunwales") as MultiMeshInstance3D
	var straps := parent.get_node_or_null("HullStraps") as MultiMeshInstance3D
	if caps == null or caps.multimesh.instance_count != 2: return
	for index in 2:
		var rail := ark.get_node_or_null("RaftPort" if index==0 else "RaftStarboard") as Node3D
		if rail == null: continue
		var box := rail.get_child(0) as MeshInstance3D
		if box == null or not box.mesh is BoxMesh: continue
		var length: float = box.mesh.size.z
		caps.multimesh.set_instance_transform(index,Transform3D(Basis.from_scale(Vector3(.19,.06,length-.05)),rail.position+Vector3.UP*.25))
		if straps != null and straps.multimesh.instance_count == 4:
			for end_ in 2:
				var z := rail.position.z+(length*.5-.35)*(1 if end_==0 else -1)
				straps.multimesh.set_instance_transform(index*2+end_,Transform3D(Basis.from_scale(Vector3(.18,.40,.065)),Vector3(rail.position.x,.35,z)))

func restore() -> void:
	for entry in _hidden.values():
		var base: Node = entry.node.get_ref()
		if is_instance_valid(base): base.visible = entry.visible
	var node: Node = _root.get_ref() if _root != null else null
	if is_instance_valid(node): node.free()
	_hidden.clear()
	_root = null
	_key = ""
