extends Node3D
## Anchored visual rig. All timing comes from the encounter, not this node.
## The claws close at the territory impact; they are not a hitbox or a dash.

var _shell: Node3D
var _head: Node3D
var _arms: Array[Node3D] = []
var _pins: Array[Node3D] = []
var _edge: StandardMaterial3D
var _last_pose := Vector3(-1.0, -1.0, -1.0)


func build() -> void:
	scale = Vector3.ONE * 0.90 # Visual only; encounter radius remains authoritative.
	_shell = Node3D.new()
	_shell.name = "Carapace"
	add_child(_shell)
	_shell.position.y = 0.49
	_piece(_shell, "Body", Vector3.ZERO, Vector3(1.40, 0.66, 1.42), Color("343c3b"))
	_edge = _pigment(Color("7e8376"))
	for i in range(3):
		var ridge := _piece(_shell, "Ridge%d" % i, Vector3(0.0, 0.25 + 0.035 * float(i % 2), -0.39 + 0.36 * i), Vector3(1.13 - 0.12 * float(i % 2), 0.22, 0.30), Color("535e59"))
		ridge.rotation.z = 0.06 * float(i - 1)
	for side in [-1.0, 1.0]:
		_piece(_shell, "Edge", Vector3(side * 0.61, 0.11, -0.08), Vector3(0.22, 0.18, 0.88), Color("7e8376")).material_override = _edge
		for i in range(3):
			var z := -0.39 + 0.39 * i
			var knee := Vector3(side * (0.93 - 0.09 * i), 0.34, z + 0.13)
			_segment(self, Vector3(side * 0.48, 0.34, z), knee, 0.095, Color("414947"))
			_segment(self, knee, Vector3(side * (1.08 - 0.09 * i), 0.02, z + 0.29), 0.060, Color("969181") if i == 0 else Color("7b7d70"))
	_head = Node3D.new()
	_head.name = "Head"
	add_child(_head)
	_head.position = Vector3(0.0, 0.37, -0.61)
	_piece(_head, "Face", Vector3.ZERO, Vector3(0.65, 0.40, 0.45), Color("444c48"))
	for side in [-1.0, 1.0]:
		var eye := Vector3(side * 0.22, 0.095, -0.22)
		_piece(_head, "Eye", eye, Vector3(0.095, 0.055, 0.055), Color("a58a53"))
		var arm := Node3D.new()
		arm.name = "PincerLeft" if side < 0 else "PincerRight"
		add_child(arm)
		_arms.append(arm)
		arm.position = Vector3(side * 0.53, 0.30, -0.40)
		_segment(arm, Vector3.ZERO, Vector3(side * 0.33, 0.04, -0.45), 0.14, Color("414a46"))
		_piece(arm, "Palm", Vector3(side * 0.38, 0.08, -0.57), Vector3(0.51, 0.32, 0.52), Color("50594f"))
		_piece(arm, "ClawRim", Vector3(side * 0.46, 0.22, -0.59), Vector3(0.12, 0.055, 0.34), Color("a39b87"))
		_segment(arm, Vector3(side * 0.55, 0.08, -0.65), Vector3(side * 0.48, 0.09, -1.0), 0.115, Color("858678"))
		var pin := Node3D.new()
		arm.add_child(pin)
		_pins.append(pin)
		pin.position = Vector3(side * 0.19, 0.08, -0.65)
		_segment(pin, Vector3.ZERO, Vector3(side * 0.08, 0.0, -0.30), 0.085, Color("858678"))


func present(charge: float, recovery: float, hit: float, toward: Vector2) -> void:
	if charge > 0.0 and toward.length_squared() > 0.0001:
		rotation.y = atan2(-toward.x, -toward.y)
	elif recovery <= 0.0 and charge <= 0.0:
		rotation.y = 0.0
	var pose := Vector3(charge, recovery, hit)
	if pose == _last_pose:
		return
	_last_pose = pose
	# Ratios are the existing simulation's authoritative remaining times.
	var windup := 1.0 - charge if charge > 0.0 else 0.0
	var pressure := smoothstep(0.0, 1.0, windup)
	var open := 0.20 + 0.63 * pressure
	var lift := 0.15 - 0.90 * pressure
	var duck := pressure
	var edge_color := Color("7e8376").lerp(Color("b3a181"), pressure * 0.55)
	if recovery > 0.0:
		# First fifth of actual recovery: a rooted snap. Then lowered arms settle.
		var snap := smoothstep(0.80, 1.0, recovery)
		open = lerpf(0.20, 0.0, recovery)
		lift = 0.13 * recovery + 0.20 * snap
		duck = 0.44 * recovery
		edge_color = Color("7e8376")
	if hit > 0.0:
		lift += 0.29 * hit
		edge_color = edge_color.lerp(Color("c4c3ae"), hit)
	_shell.position.y = 0.49 - 0.16 * duck + 0.07 * hit
	_shell.rotation.x = 0.15 * duck - 0.12 * hit
	_head.position.y = 0.37 - 0.13 * duck + 0.07 * hit
	_head.rotation.x = -0.13 * pressure + 0.17 * hit
	_edge.albedo_color = edge_color
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		_arms[i].rotation.x = -lift
		_arms[i].rotation.y = -side * 0.21 * open
		_pins[i].rotation.y = side * 0.66 * open


func _pigment(color: Color) -> StandardMaterial3D:
	var pigment := StandardMaterial3D.new()
	pigment.albedo_color = color
	pigment.roughness = 0.96
	pigment.metallic_specular = 0.18
	return pigment


func _piece(parent: Node3D, part: String, center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh: Mesh = _stone_mesh()
	if part == "Eye":
		mesh = BoxMesh.new()
	var instance := MeshInstance3D.new()
	instance.name = part
	instance.mesh = mesh
	instance.position = center
	instance.scale = size
	instance.material_override = _pigment(color)
	parent.add_child(instance)
	return instance


func _segment(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 6
	mesh.rings = 1
	mesh.height = a.distance_to(b)
	mesh.bottom_radius = radius
	mesh.top_radius = radius * 0.55
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = (a + b) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	instance.material_override = _pigment(color)
	parent.add_child(instance)


func _stone_mesh() -> ArrayMesh:
	# Chipped, bevelled plates with face normals. No smooth toy-like lobes,
	# random state, textures, collision or encounter-state changes.
	var rim: Array[Vector2] = [Vector2(-0.34,-0.5),Vector2(0.28,-0.48),Vector2(0.5,-0.23),Vector2(0.46,0.32),Vector2(0.22,0.5),Vector2(-0.31,0.46),Vector2(-0.5,0.20),Vector2(-0.47,-0.29)]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(8):
		var j := (i + 1) % 8
		var a := Vector3(rim[i].x, -0.35, rim[i].y)
		var b := Vector3(rim[j].x, -0.35, rim[j].y)
		var c := Vector3(rim[j].x * 0.76, 0.27 + 0.055 * float(j % 3), rim[j].y * 0.78)
		var d := Vector3(rim[i].x * 0.76, 0.27 + 0.055 * float(i % 3), rim[i].y * 0.78)
		for tri: Array in [[a,b,c],[a,c,d],[d,c,Vector3(0.025,0.49,-0.035)],[a,Vector3(0,-0.35,0),b]]:
			var normal: Vector3 = (tri[2]-tri[0]).cross(tri[1]-tri[0]).normalized()
			for point: Vector3 in tri:
				vertices.append(point)
				normals.append(normal)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
