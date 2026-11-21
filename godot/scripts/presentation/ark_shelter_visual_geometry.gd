extends RefCounted
## Stateless shelter geometry only. No world, collision, lights, interaction,
## save, actor, or final presentation ownership. Created nodes belong to caller.

static func shell_parts() -> Array:
	return [
		["Floor", Vector3(0, 0.12, 0), Vector3(3.0, 0.14, 2.4), Color("9b7650"), false],
		["Back", Vector3(0, 1.25, -1.12), Vector3(3.0, 2.2, 0.14), Color("76593f"), true],
		["Left", Vector3(-1.42, 1.25, 0), Vector3(0.14, 2.2, 2.2), Color("76593f"), true],
		["Right", Vector3(1.42, 1.25, 0), Vector3(0.14, 2.2, 2.2), Color("76593f"), true],
	]

static func cot_parts(cot_position: Vector3, cot_size: Vector3) -> Array:
	return [
		["Cot", cot_position, cot_size, Color("8a684c")],
		["Bedroll", cot_position + Vector3.UP * .20, Vector3(1.62, 0.08, 0.72), Color("c0a589")],
	]

static func hearth_parts() -> Array:
	return [
		["HearthStone", Vector3(-1.05, 0.21, -0.75), Vector3(0.62, 0.18, 0.52), Color("69645b")],
		["HearthEmbers", Vector3(-1.05, 0.34, -0.75), Vector3(0.34, 0.06, 0.32), Color("e08a4e")],
	]

static func visual_group(parent: Node3D, part: Array, material_for: Callable) -> Node3D:
	var group := Node3D.new()
	group.name = part[0]
	group.position = part[1]
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = part[2]
	visual.mesh = mesh
	visual.material_override = material_for.call(part[3]) as Material
	group.add_child(visual)
	parent.add_child(group)
	return group

static func add_roof(parent: Node3D, material_for: Callable) -> Node3D:
	var roof := Node3D.new()
	roof.name = "Roof"
	roof.position = Vector3(0, 2.38, 0)
	parent.add_child(roof)
	visual_box(roof, "CenterFace", Vector3.ZERO, Vector3(2.84, 0.18, 2.24), Color("a58b66"), material_for)
	for side in [-1.0, 1.0]:
		visual_box(roof, "EaveLeft" if side < 0.0 else "EaveRight", Vector3(side * 1.51, 0, 0), Vector3(0.18, 0.18, 2.24), Color("a58b66"), material_for)
		visual_box(roof, "EaveBack" if side < 0.0 else "EaveFront", Vector3(0, 0, side * 1.21), Vector3(3.2, 0.18, 0.18), Color("a58b66"), material_for)
	return roof

static func add_quilt(parent: Node3D, cot_position: Vector3, material_for: Callable) -> void:
	visual_box(parent, "QuiltFold", cot_position + Vector3(-.25, .27, 0), Vector3(1.15, 0.055, 0.74), Color("b88769"), material_for)

static func add_details(structure: Node3D, roof: Node3D, material_for: Callable) -> void:
	var floorboards := Node3D.new()
	floorboards.name = "CabinFloorboards"
	structure.add_child(floorboards)
	var plank_colors: Array[Color] = [Color("a17b54"), Color("ad855c"), Color("96704d"), Color("b18b62")]
	for index in range(8):
		var board_x := -1.3 + float(index) * 0.37
		visual_box(floorboards, "FloorPlank%d" % index, Vector3(board_x, 0.215, 0.0), Vector3(0.35, 0.045, 2.28), plank_colors[index % plank_colors.size()], material_for)
		visual_box(floorboards, "PlankEndGrain%d" % index, Vector3(board_x, 0.241, 1.1), Vector3(0.32, 0.012, 0.025), Color("74563d"), material_for)

	var frame := Node3D.new()
	frame.name = "CabinFrameDetails"
	structure.add_child(frame)
	for side in [-1.0, 1.0]:
		for depth in [-1.0, 1.0]:
			var post_x: float = float(side) * 1.31
			var post_z: float = float(depth) * 1.02
			visual_cylinder(frame, "FramePost_%d_%d" % [int(side), int(depth)], Vector3(post_x, 1.16, post_z), 0.075, 2.08, Color("6d4b34"), material_for)
			visual_box(frame, "PostLashing_%d_%d" % [int(side), int(depth)], Vector3(post_x, 1.43, post_z), Vector3(0.19, 0.045, 0.19), Color("b29a73"), material_for)
			visual_box(frame, "PostFoot_%d_%d" % [int(side), int(depth)], Vector3(post_x, 0.22, post_z), Vector3(0.23, 0.12, 0.23), Color("594232"), material_for)
	visual_box(frame, "FrontLintel", Vector3(0.0, 2.1, 1.06), Vector3(2.78, 0.14, 0.14), Color("805b3e"), material_for)
	visual_box(frame, "RearLintel", Vector3(0.0, 2.1, -1.03), Vector3(2.78, 0.14, 0.14), Color("805b3e"), material_for)
	visual_box(frame, "EntranceCanvas", Vector3(0.0, 2.36, 1.3), Vector3(2.14, 0.055, 0.6), Color("8b9b8b"), material_for)
	visual_box(frame, "CanvasEdgeBinding", Vector3(0.0, 2.34, 1.58), Vector3(2.17, 0.075, 0.08), Color("6e796e"), material_for)
	visual_box(frame, "CanvasPatch", Vector3(-0.63, 2.405, 1.38), Vector3(0.48, 0.018, 0.26), Color("b28d64"), material_for)
	visual_box(frame, "HangingHerbBundle", Vector3(-1.15, 1.73, 0.92), Vector3(0.16, 0.38, 0.12), Color("667a58"), material_for)
	visual_box(roof, "RoofRidgeBinding", Vector3(0.0, 0.115, 0.0), Vector3(3.12, 0.055, 0.12), Color("76583f"), material_for)
	visual_box(roof, "RoofCanvasPatch", Vector3(0.82, 0.115, -0.58), Vector3(0.56, 0.035, 0.48), Color("7c8d80"), material_for)
	visual_box(roof, "RoofCanvasPatchSeam", Vector3(0.82, 0.139, -0.58), Vector3(0.58, 0.018, 0.035), Color("c1a47b"), material_for)

static func add_pot(parent: Node3D, material_for: Callable) -> void:
	var pot := Node3D.new()
	pot.name = "HearthPot"
	pot.position = Vector3(-1.05, 0.53, -0.75)
	parent.add_child(pot)
	visual_cylinder(pot, "PotBody", Vector3.ZERO, 0.2, 0.25, Color("42494a"), material_for)
	visual_cylinder(pot, "PotRim", Vector3(0.0, 0.12, 0.0), 0.225, 0.045, Color("78807b"), material_for)
	visual_cylinder(pot, "PotLid", Vector3(0.0, 0.15, 0.0), 0.19, 0.025, Color("59635f"), material_for)
	visual_cylinder(pot, "LidHandle", Vector3(0.0, 0.19, 0.0), 0.045, 0.055, Color("b39667"), material_for)

static func add_lamp_visual(parent: Node3D, material_for: Callable) -> Node3D:
	var lamp := Node3D.new()
	lamp.name = "Lamp"
	lamp.position = Vector3(-0.18, 1.52, -0.48)
	parent.add_child(lamp)
	visual_box(lamp, "HangingCord", Vector3(0.0, 0.35, 0.0), Vector3(0.035, 0.28, 0.035), Color("76563d"), material_for)
	visual_cylinder(lamp, "Cap", Vector3(0.0, 0.19, 0.0), 0.1, 0.07, Color("98734e"), material_for)
	var glass := MeshInstance3D.new()
	glass.name = "WarmGlass"
	var glass_mesh := SphereMesh.new()
	glass_mesh.radius = 0.115
	glass_mesh.height = 0.31
	glass_mesh.radial_segments = 12
	glass_mesh.rings = 6
	glass.mesh = glass_mesh
	glass.position = Vector3(0.0, 0.0, 0.0)
	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color("ffd38a")
	glass_material.emission_enabled = true
	glass_material.emission = Color("ffb84e")
	glass_material.roughness = 0.32
	glass.material_override = glass_material
	lamp.add_child(glass)
	visual_cylinder(lamp, "Base", Vector3(0.0, -0.19, 0.0), 0.095, 0.055, Color("70523b"), material_for)
	return lamp

static func add_meal_visual(structure: Node3D, mat_offset: Vector3, material_for: Callable) -> Node3D:
	var setting := Node3D.new()
	setting.name = "SharedMealSetting"
	structure.add_child(setting)
	visual_box(setting, "WovenMat", mat_offset, Vector3(1.35, 0.035, 0.55), Color("896646"), material_for)
	for index in range(3):
		var x := mat_offset.x + float(index - 1) * 0.43
		visual_cylinder(setting, "Bowl%d" % index, Vector3(x, 0.30, 0.4), 0.15, 0.09, Color("8d958e"), material_for)
		visual_cylinder(setting, "Soup%d" % index, Vector3(x, 0.349, 0.4), 0.12, 0.008, Color("de9b4f"), material_for)
	visual_cylinder(setting, "CoveredPot", Vector3(-1.05, 0.70, -0.75), 0.21, 0.035, Color("b39667"), material_for)
	return setting

static func visual_box(parent: Node3D, id: String, position: Vector3, size: Vector3, color: Color, material_for: Callable) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = id
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = position
	visual.material_override = material_for.call(color) as Material
	parent.add_child(visual)
	return visual

static func visual_cylinder(parent: Node3D, id: String, position: Vector3, radius: float, height: float, color: Color, material_for: Callable) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = id
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.84
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	visual.mesh = mesh
	visual.position = position
	visual.material_override = material_for.call(color) as Material
	parent.add_child(visual)
	return visual

static func add_batch(parent: Node3D, name_: String, mesh: Mesh, role: String, pieces: Array, material_for: Callable) -> void:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = mesh
	instances.instance_count = pieces.size()
	for index in range(pieces.size()):
		var piece: Array = pieces[index]
		instances.set_instance_transform(index, Transform3D(Basis.from_scale(piece[1]), piece[0]))
		instances.set_instance_color(index, Color.WHITE.lerp(Color("d8d0bb"), float(index % 3) * .12))
	var visual := MultiMeshInstance3D.new()
	visual.name = name_
	visual.multimesh = instances
	visual.material_override = material_for.call(role) as Material
	parent.add_child(visual)

static func add_cabin_details(parent: Node3D, material_for: Callable) -> void:
	var woodwork: Array = [[Vector3(0, 1.37, -1.005), Vector3(.94, .055, .20)], [Vector3(0, 2.11, -1.01), Vector3(2.7, .10, .09)]]
	for x in [-1.27, 1.27]:
		woodwork.append([Vector3(x, 1.16, 1.05), Vector3(.11, 1.96, .12)])
	for index in range(8):
		woodwork.append([Vector3(-1.17 + index * .335, 1.18, -1.034), Vector3(.025, 1.70, .032)])
	add_batch(parent, "JoineryAndShelf", BoxMesh.new(), "timber", woodwork, material_for)
	var fasteners: Array = []
	for x in [-1.27, 1.27]:
		for y in [.35, 1.90]: fasteners.append([Vector3(x, y, 1.119), Vector3(.14, .11, .018)])
	add_batch(parent, "BrassCornerPlates", BoxMesh.new(), "brass", fasteners, material_for)
	var bottle := CylinderMesh.new()
	bottle.top_radius = .047
	bottle.bottom_radius = .061
	bottle.height = .20
	bottle.radial_segments = 12
	add_batch(parent, "ShelfJars", bottle, "ceramic", [[Vector3(-.25, 1.50, -.98), Vector3.ONE], [Vector3(-.08, 1.485, -.98), Vector3(.8, .85, .8)]], material_for)
	add_batch(parent, "FoldedTableLinen", BoxMesh.new(), "cloth", [[Vector3(.22, 1.415, -.98), Vector3(.25, .035, .15)]], material_for)

static func add_roof_details(parent: Node3D, material_for: Callable) -> void:
	var seams: Array = []
	for x in [-1.0, 0.0, 1.0]: seams.append([Vector3(x, .105, 0), Vector3(.025, .012, 2.14)])
	add_batch(parent, "CanvasSeamBindings", BoxMesh.new(), "rope", seams, material_for)

static func build_initial_visual(parent: Node3D, cot_position: Vector3, cot_size: Vector3, meal_offset: Vector3, material_for: Callable) -> void:
	for part in shell_parts(): visual_group(parent, part, material_for)
	var roof := add_roof(parent, material_for)
	add_details(parent, roof, material_for)
	for part in cot_parts(cot_position, cot_size): visual_group(parent, part, material_for)
	for part in hearth_parts(): visual_group(parent, part, material_for)
	add_pot(parent, material_for)
	add_quilt(parent, cot_position, material_for)
	add_lamp_visual(parent, material_for)
	var meal := add_meal_visual(parent, meal_offset, material_for)
	meal.visible = false
	for index in range(3): (meal.get_node("Soup%d" % index) as Node3D).visible = false
	(meal.get_node("CoveredPot") as Node3D).visible = false
