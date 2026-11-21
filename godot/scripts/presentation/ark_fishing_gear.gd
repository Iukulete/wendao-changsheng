extends RefCounted
## Presentation only: handmade bamboo/hemp tackle. No inventory, RNG, timing or save access.
const LENGTH := 1.6
const SEGMENTS := 4
const FLOAT_TIP := Vector3(0,0.32,0)
var rod: Node3D
var bob: Node3D
var line: MeshInstance3D
var float_lower_parts: Array[MeshInstance3D] = []
var hanging: Node3D
var hanger_line: MeshInstance3D
var shafts: Array[MeshInstance3D] = []
var joints: Array[MeshInstance3D] = []
var guides: Array[Node3D] = []
var guide_locations := [0.38, 0.68, 0.94]
var tip_local := Vector3(0, 0.8, 0)
var line_start := Vector3.ZERO
var line_end := Vector3.ZERO
var profile_id := "basic"
var reinforcement: Node3D

func _material(color: String) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(color); result.roughness = 0.94
	return result

func _cylinder(parent: Node3D, label: String, height: float, radius: float, material: Material, top: float = -1.0) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.name = label
	var shape := CylinderMesh.new(); shape.height = height; shape.bottom_radius = radius
	shape.top_radius = radius if top < 0 else top; shape.radial_segments = 6; shape.rings = 1
	node.mesh = shape; node.material_override = material; parent.add_child(node)
	return node

func _wire(parent: Node3D, label: String, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.name = label; node.mesh = ImmediateMesh.new()
	node.material_override = material; parent.add_child(node); return node

func _draw_wire(node: MeshInstance3D, points: PackedVector3Array) -> void:
	var mesh := node.mesh as ImmediateMesh; mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for point in points: mesh.surface_add_vertex(point)
	mesh.surface_end()

func attach(world: Node3D, marker: Node3D) -> void:
	var bamboo := _material("b99a58"); var nodes := _material("786b3c")
	var dark_wood := _material("574332"); var hemp := _material("b9ac83")
	var line_mat := _material("c4b998")
	rod = Node3D.new(); rod.name = "HandmadeBambooRod"; rod.position = Vector3(0.15, 0.35, 0)
	rod.rotation.z = -0.65; marker.add_child(rod)
	for i in SEGMENTS:
		var radius := lerpf(0.035, 0.018, float(i) / SEGMENTS)
		shafts.append(_cylinder(rod, "BambooSection%d" % i, LENGTH / SEGMENTS, radius, bamboo, radius - 0.004))
	for i in 3:
		joints.append(_cylinder(rod, "BambooJoint%d" % i, 0.035, lerpf(0.038,0.024,float(i)/2), nodes))
	var grip := _cylinder(rod,"WoodGrip",0.36,0.047,dark_wood); grip.position.y = -0.62
	for i in 3:
		var wrap := _cylinder(rod,"HempWrap%d" % i,0.025,0.049,hemp); wrap.position.y = -0.73 + i * 0.105
	reinforcement=Node3D.new();reinforcement.name="ReinforcedLashing";rod.add_child(reinforcement)
	for direction in [-1,1]:
		var binding:=_cylinder(reinforcement,"CrossBinding"+str(direction),0.16,0.012,hemp)
		binding.position=Vector3(0.0,-0.20,0.04);binding.rotation.z=direction*.6
	reinforcement.hide()
	# A small hand-wound wooden spool, not an advanced metal/geared reel.
	var axle := _cylinder(rod,"SpoolAxle",0.12,0.025,dark_wood); axle.position = Vector3(-0.09,-0.43,0); axle.rotation.z = PI / 2
	for side in [-1.0,1.0]:
		var cheek := _cylinder(rod,"WoodSpoolBack" if side<0 else "WoodSpoolFront",0.018,0.075,dark_wood)
		cheek.position = Vector3(-0.1,-0.43,side*0.045); cheek.rotation.x=PI/2
	var thread := _cylinder(rod,"WoundHemp",0.07,0.052,hemp); thread.position=Vector3(-0.1,-0.43,0); thread.rotation.x=PI/2
	for i in guide_locations.size():
		var guide := Node3D.new(); guide.name="LineGuide%d"%i; rod.add_child(guide); guides.append(guide)
		var ring := MeshInstance3D.new(); var shape := TorusMesh.new()
		shape.inner_radius=0.022; shape.outer_radius=0.034; shape.rings=6; shape.ring_segments=4
		ring.mesh=shape; ring.material_override=dark_wood; guide.add_child(ring)
	bob=Node3D.new(); bob.name="TwoToneFloat"; world.add_child(bob)
	var float_wood:=_material("bb763e");var float_tip:=_material("dc6b45");var pale:=_material("d5c8a5")
	var belly:=_cylinder(bob,"FloatWoodBelly",0.17,0.035,float_wood,0.062);belly.position.y=0.035
	var shoulder:=_cylinder(bob,"FloatPaleShoulder",0.07,0.062,pale,0.025);shoulder.position.y=0.155
	var stem:=_cylinder(bob,"FloatStem",0.13,0.019,pale);stem.position.y=0.245
	var tip:=_cylinder(bob,"FloatOrangeTip",0.07,0.025,float_tip);tip.position=FLOAT_TIP
	var foot:=_cylinder(bob,"FloatFoot",0.10,0.014,dark_wood);foot.position.y=-0.09
	float_lower_parts=[belly,shoulder,stem,foot]
	line=_wire(world,"FishingCastLine",line_mat)
	hanging=Node3D.new();hanging.name="StowedHookAndBait";rod.add_child(hanging)
	var hook:=_wire(hanging,"BentBoneHook",pale)
	_draw_wire(hook,PackedVector3Array([Vector3(0,0.03,0),Vector3(0,-0.04,0),Vector3(0.02,-0.065,0),Vector3(0.05,-0.05,0),Vector3(0.05,-0.025,0)]))
	var bait:=_cylinder(hanging,"SmallBait",0.07,0.026,_material("8e6747"));bait.position=Vector3(0.025,-0.035,0)
	hanger_line=_wire(rod,"StowedShortLine",line_mat)
	update_visual("idle",0,0,0,0,Transform3D.IDENTITY)

func _point(t: float, bend: float) -> Vector3:
	return Vector3(0.18*bend*t*t, -0.8+LENGTH*t-0.045*bend*t*t, 0)

func tip_world() -> Vector3:
	return rod.to_global(tip_local)

func update_visual(phase: String, tension: float, distance: float, elapsed: float, wind: float, ark_transform: Transform3D) -> void:
	var casting := phase in ["waiting","bite","fighting"]
	var bend := clampf(tension,0.0,1.0) if phase=="fighting" else 0.0
	rod.rotation.z=-0.65+(sin(elapsed*2.0)*0.012*(0.2+wind) if casting else 0.0)
	for i in SEGMENTS:
		var a:=_point(float(i)/SEGMENTS,bend);var b:=_point(float(i+1)/SEGMENTS,bend)
		shafts[i].position=(a+b)*0.5;shafts[i].quaternion=Quaternion(Vector3.UP,(b-a).normalized())
		(shafts[i].mesh as CylinderMesh).height=a.distance_to(b)
	for i in joints.size(): joints[i].position=_point(float(i+1)/SEGMENTS,bend)
	for i in guides.size(): guides[i].position=_point(guide_locations[i],bend)+Vector3(0.045,0,0)
	tip_local=_point(1.0,bend)
	bob.visible=casting;line.visible=casting;hanging.visible=not casting;hanger_line.visible=not casting
	# The stylized water does not depth-occlude small props. Show only the bright
	# tip once the visual bite dip completes, rather than drawing an underwater float.
	for part in float_lower_parts: part.visible=phase!="bite" or elapsed<0.12
	# The hook/bait stays legible only while stowed, never as an underwater icon.
	var hang_end:Vector3=tip_local+rod.basis.inverse()*Vector3(0,-0.34,0)
	hanging.position=hang_end
	_draw_wire(hanger_line,PackedVector3Array([tip_local,hang_end]))
	if not casting:return
	var wave:=sin(elapsed*2.6)*(0.025+wind*0.035)
	var sink:float=lerpf(0.0,0.27,clampf(elapsed/0.18,0,1)) if phase=="bite" else 0.0
	bob.global_position=ark_transform*Vector3(4.5+distance*1.5,0.025+wave-sink,-0.65)
	bob.rotation.z=sin(elapsed*2.6)*(.06+wind*.07)
	line_start=tip_world()
	line_end=bob.to_global(FLOAT_TIP if phase=="bite" and elapsed>=0.12 else Vector3(0,-0.015,0))
	var middle:Vector3=line_start.lerp(line_end,0.5)
	middle.y-=0.025 if phase=="fighting" else 0.10
	_draw_wire(line,PackedVector3Array([line.to_local(line_start),line.to_local(middle),line.to_local(line_end)]))

func set_profile(id: String) -> void:
	if id not in ["basic","light","resilient"] or not is_instance_valid(rod): return
	if profile_id==id: return
	profile_id=id
	var thickness:=0.80 if id=="light" else 1.18 if id=="resilient" else 1.0
	for i in SEGMENTS:
		var radius:=lerpf(0.035,0.018,float(i)/SEGMENTS)
		(shafts[i].mesh as CylinderMesh).bottom_radius=radius*thickness
		(shafts[i].mesh as CylinderMesh).top_radius=(radius-0.004)*thickness
	for i in joints.size():
		(joints[i].mesh as CylinderMesh).bottom_radius=lerpf(0.038,0.024,float(i)/2)*thickness
		(joints[i].mesh as CylinderMesh).top_radius=(joints[i].mesh as CylinderMesh).bottom_radius
	rod.get_node("HempWrap1").visible=id!="light"
	reinforcement.visible=id=="resilient"
