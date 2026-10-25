extends RefCounted
## Original code-native modular prop, no downloaded or generated bitmap assets.
const ROOT := "ModernWaterCorner"
const AT := Vector3(1.9,0.12,-3.2)
const APPROACH := Vector3(1.83,.12,-2.38)

static func clear(game: Node3D) -> void:
	for index in range(game.interactables.size()-1,-1,-1):
		if game.interactables[index].get("id") == "modern_wash": game.interactables.remove_at(index)
	var old: Node = game.ark_root.get_node_or_null(ROOT)
	if old:
		game.ark_root.remove_child(old)
		old.queue_free()

static func box(parent: Node3D, id: String, at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = id
	node.position = at
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = .68
	node.material_override = material
	parent.add_child(node)
	return node

static func refresh(game: Node3D) -> void:
	if game.ark_root == null: return
	var root: Node3D = game.ark_root.get_node_or_null(ROOT)
	if root == null: return
	var water: int = game.economy.inventory("utilities_tank","fresh_water")
	var gauge := root.get_node("TankGaugeWater") as MeshInstance3D
	gauge.scale.y = maxf(.01,float(water)/6.0)
	gauge.position.y = .25+.22*float(water)/6.0
	root.get_node("BasinWater").visible = water > 0
	var indicator := root.get_node("BatteryIndicator") as MeshInstance3D
	(indicator.material_override as StandardMaterial3D).albedo_color = Color("79cbb3") if game.modern_utilities.power.charge >= 500 else Color("b98365")

static func build(game: Node3D) -> Node3D:
	var existing := game.ark_root.get_node_or_null(ROOT) as Node3D
	if existing: return existing
	var root := StaticBody3D.new()
	root.name = ROOT
	root.position = AT
	root.collision_layer = 1
	root.collision_mask = 0
	game.ark_root.add_child(root)
	box(root,"TimberPlinth",Vector3(0,.08,0),Vector3(1.35,.16,1.05),"8b7755")
	box(root,"Battery",Vector3(-.35,.4,-.13),Vector3(.48,.55,.66),"2b4144")
	box(root,"BatteryStrap",Vector3(-.35,.4,-.13),Vector3(.12,.58,.68),"9a8b70")
	box(root,"BatteryIndicator",Vector3(-.35,.58,.211),Vector3(.2,.045,.015),"79cbb3")
	box(root,"CleanWaterTank",Vector3(.3,.43,-.15),Vector3(.48,.56,.58),"768f88")
	box(root,"TankGaugeBacking",Vector3(.3,.47,.15),Vector3(.09,.46,.035),"d6d5bd")
	box(root,"TankGaugeWater",Vector3(.3,.47,.173),Vector3(.05,.44,.014),"69b4b5")
	box(root,"PurifierHousing",Vector3(.3,.85,-.15),Vector3(.48,.25,.58),"d2d4be")
	box(root,"PurifierControl",Vector3(.3,.85,.15),Vector3(.3,.12,.035),"2e575e")
	box(root,"FilterCartridge",Vector3(.6,.66,-.1),Vector3(.15,.49,.27),"658e89")
	box(root,"IntakeArm",Vector3(1.0,-.08,-.32),Vector3(1.0,.045,.045),"405b58")
	box(root,"IntakeHose",Vector3(1.5,-.62,-.32),Vector3(.045,1.12,.045),"405b58")
	box(root,"BasinStand",Vector3(-.07,.45,.31),Vector3(.6,.63,.25),"6d8276")
	box(root,"Basin",Vector3(-.07,.8,.31),Vector3(.65,.13,.37),"e0daca")
	box(root,"BasinWater",Vector3(-.07,.87,.31),Vector3(.5,.012,.24),"72aaa9")
	box(root,"TapUpright",Vector3(.17,1.02,.19),Vector3(.035,.32,.035),"a5b7af")
	box(root,"TapSpout",Vector3(.08,1.17,.19),Vector3(.22,.035,.035),"a5b7af")
	for x in [-.57,.57]:
		box(root,"CanopyPost",Vector3(x,.94,-.42),Vector3(.045,1.72,.045),"536d67")
	var panel := Node3D.new()
	panel.name = "SolarCanopy"
	panel.position = Vector3(0,1.84,-.05)
	panel.rotation_degrees.x = -16
	root.add_child(panel)
	box(panel,"Frame",Vector3.ZERO,Vector3(1.45,.065,1.13),"b6baa7")
	box(panel,"CellBed",Vector3(0,.04,0),Vector3(1.35,.018,1.03),"203e52")
	for x in range(4):
		for z in range(3):
			box(panel,"Cell_%d_%d" % [x,z],Vector3((x-1.5)*.33,.055,(z-1)*.33),Vector3(.31,.012,.31),"315b70" if (x+z)%2 else "2a5066")
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(1.35,1.55,1.05)
	shape.shape = bounds
	shape.position.y = .8
	root.add_child(shape)
	var label := Label3D.new()
	label.name = "Name"
	label.text = "日照净水角 · E 洗漱"
	label.font = game.UI_FONT
	label.font_size = 22
	label.pixel_size = .003
	label.position = Vector3(0,2.25,0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	game._style_nearby_world_label(label)
	label.font_size = 24
	label.pixel_size = .005
	label.width = 320
	root.add_child(label)
	game.interactables.append({"id":"modern_wash","node":root,"amount":0})
	game._invalidate_committed_layout()
	refresh(game)
	return root
