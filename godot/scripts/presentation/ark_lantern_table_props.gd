extends RefCounted
## Temporary, non-colliding tabletop dressing. No inventory or navigation owner.
const CLOTH_PATH := "res://art/lantern_table/cloth_albedo_v1.png"
var root: Node3D
var _poses: Array[Dictionary] = []

func open(game: Node3D, resident: Node3D, body: Node3D) -> void:
	close()
	var shelter := game.get_node_or_null("ArkRoot/BuiltShelter") as Node3D
	if shelter == null: return
	root = Node3D.new()
	root.name = "LanternTableProps"
	root.position = Vector3(-.55, .03, .4)
	shelter.add_child(root)
	var timber := _material(Color("745035"))
	_box("TrayTop", Vector3(0, .28, 0), Vector3(.82, .045, .54), timber)
	for x in [-.31, .31]:
		for z in [-.18, .18]: _box("Leg", Vector3(x, .14, z), Vector3(.045, .25, .045), timber)
	var fabric := _material(Color.WHITE)
	fabric.albedo_texture = load(CLOTH_PATH)
	fabric.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(.78, .5)
	var cloth := MeshInstance3D.new()
	cloth.name = "TableCloth"
	cloth.mesh = mesh
	cloth.material_override = fabric
	cloth.position.y = .305
	root.add_child(cloth)
	var paper := _material(Color("f4e7cd"))
	for position in [Vector3(-.09, .312, -.09), Vector3(.04, .314, -.08), Vector3(-.07, .313, .11), Vector3(.06, .315, .10)]:
		var card := _box("PlayingCard", position, Vector3(.09, .003, .13), paper)
		card.rotation.y = .12 if position.x < 0 else -.08
	var bronze := _material(Color("ad8954"))
	for x in [-.31, .31]:
		var cup := MeshInstance3D.new()
		cup.name = "TeaCup"
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = .037
		cylinder.bottom_radius = .029
		cylinder.height = .057
		cylinder.radial_segments = 12
		cup.mesh = cylinder
		cup.material_override = bronze
		cup.position = Vector3(x, .335, 0)
		root.add_child(cup)
	# Give the small warm source a visible fixture instead of an unexplained
	# floating point light. Shared materials, tiny bounded mesh count, no physics.
	var lamp_position := Vector3(.23, .32, -.16)
	_cylinder("LanternFoot", lamp_position + Vector3(0, .015, 0), .065, .065, .025, bronze)
	var glow := _material(Color("f8c779"))
	glow.emission_enabled = true
	glow.emission = Color("ffce83")
	glow.emission_energy_multiplier = .7
	_cylinder("LanternPaper", lamp_position + Vector3(0, .085, 0), .044, .044, .12, glow)
	_cylinder("LanternCap", lamp_position + Vector3(0, .16, 0), .025, .065, .035, bronze)
	for x in [-.045, .045]:
		_box("LanternRib", lamp_position + Vector3(x, .085, 0), Vector3(.007, .13, .007), bronze)
	var light := OmniLight3D.new()
	light.name = "LanternTableWarmth"
	light.position = lamp_position + Vector3(0, .13, 0)
	light.light_color = Color("ffcf8b")
	light.light_energy = .55
	light.omni_range = 2.5
	light.shadow_enabled = false
	root.add_child(light)
	if is_instance_valid(resident):
		_remember(resident)
		var direction: Vector3 = root.position - resident.position + shelter.position
		resident.rotation.y = atan2(direction.x, direction.z)
	if is_instance_valid(body):
		for name_ in ["ArmLeft", "ArmRight"]:
			var arm := body.get_node_or_null(name_) as Node3D
			if arm:
				_remember(arm)
				arm.rotation.x = -.72

func _remember(node: Node3D) -> void:
	_poses.append({"node": weakref(node), "rotation": node.rotation})

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .78
	return material

func _box(name_: String, position: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name_
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	root.add_child(instance)
	return instance

func _cylinder(name_: String, position: Vector3, top: float, bottom: float, height: float, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = name_
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 12
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	root.add_child(instance)

func close() -> void:
	for pose in _poses:
		var node := pose.node.get_ref() as Node3D
		if is_instance_valid(node) and node.is_inside_tree(): node.rotation = pose.rotation
	_poses.clear()
	if is_instance_valid(root) and root.is_inside_tree():
		if root.get_parent(): root.get_parent().remove_child(root)
		root.queue_free()
	root = null
