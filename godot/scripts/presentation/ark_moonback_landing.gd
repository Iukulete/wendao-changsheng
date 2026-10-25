extends RefCounted
## Static regional dressing and physical landing. No reward or stock ownership.
const ROOT := "MoonbackOldLanding"
const SOURCES := ["MoonbackDriftwood", "MoonbackTidalShells"]
const NATURE := {
	"Pine_1": [[-23,22,.48,.6],[-25,28,.46,2.2],[-29,30,.43,4.1],[-36,25,.42,1.5]],
	"Bush_Common": [[-21,21,.4,.7],[-24,25,.43,2],[-27,29,.45,1],[-36,27,.38,3],[-36,21,.4,.5],[-29,19,.4,2]],
	"Fern_1": [[-22,20,.3,1],[-23,25,.32,0],[-25,26,.3,2],[-27,30,.31,3],[-30,29,.28,1],[-35,27,.3,2],[-37,24,.26,3],[-36,22,.27,1],[-28,20,.29,2],[-25,18,.28,0]],
	"Rock_Medium_1": [[-20.7,24,.3,1],[-35.5,18,.27,2.4],[-33.7,30,.32,.3],[-24,29,.28,3]],
}
var timber: ShaderMaterial
var stone: StandardMaterial3D

func build(world: Node3D, sampler: RefCounted) -> void:
	timber = ShaderMaterial.new()
	timber.shader = preload("res://shaders/ark_home_timber.gdshader")
	timber.set_shader_parameter("timber_albedo",load("res://art/home_sample/home_timber_albedo_v1.png"))
	stone = StandardMaterial3D.new()
	stone.albedo_color = Color("89918c")
	stone.roughness = .95
	stone.albedo_texture = load("res://art/coast/rock_boulder_dry/rock_boulder_dry_diff_1k.jpg")
	stone.uv1_triplanar = true
	stone.uv1_scale = Vector3.ONE*.7
	var root := Node3D.new()
	root.name = ROOT
	world.add_child(root)
	# One continuous physical deck; the planks are a single instanced draw batch.
	var deck := StaticBody3D.new()
	deck.name = "PierDeck"
	deck.position = Vector3(-17,-.02,15.75)
	root.add_child(deck)
	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(1.6,.24,5.2)
	collider.shape = box
	deck.add_child(collider)
	var planks := MultiMeshInstance3D.new()
	planks.name = "SaltWornPlanks"
	planks.multimesh = MultiMesh.new()
	planks.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.6,.24,.20)
	planks.multimesh.mesh = mesh
	planks.material_override = timber
	planks.multimesh.instance_count = 24
	var transforms: Array[Transform3D] = []
	for i in 24:
		var t := Transform3D(Basis.IDENTITY,Vector3(0,0,-2.5+5.*i/23.))
		transforms.append(t)
		planks.multimesh.set_instance_transform(i,t)
	planks.set_meta("coast_instances",transforms)
	deck.add_child(planks)
	var approach := StaticBody3D.new()
	approach.name = "ShoreApproach"
	approach.position = Vector3(-18.7,-.09,17.8)
	approach.rotation.z = .09
	root.add_child(approach)
	var approach_mesh := BoxMesh.new()
	approach_mesh.size = Vector3(2.0,.2,1.1)
	_piece(approach,"Timber",approach_mesh,Vector3.ZERO,timber)
	var approach_shape := CollisionShape3D.new()
	approach_shape.name = "CollisionShape3D"
	# A box is deliberately retained as the navigable deck support contract.
	var approach_box := BoxShape3D.new()
	approach_box.size = approach_mesh.size
	approach_shape.shape = approach_box
	approach.add_child(approach_shape)
	for side in [-1,1]:
		for i in 3:
			var point := Vector3(-17+side*.67,-.68,13.5+i*2.1)
			var post := CylinderMesh.new()
			post.top_radius = .08
			post.bottom_radius = .105
			post.height = 1.65
			post.radial_segments = 8
			_piece(root,"MoorPost%d_%d" % [side,i],post,point,timber)
			var tie := TorusMesh.new()
			tie.inner_radius = .085
			tie.outer_radius = .115
			_piece(root,"PostRope%d_%d" % [side,i],tie,point+Vector3.UP*.76,_mat("b7a47c"))
	# A quiet directional cue, not a new interactable or an unexplained reward.
	var mast := CylinderMesh.new()
	mast.top_radius = .035
	mast.bottom_radius = .06
	mast.height = 2.6
	mast.radial_segments = 8
	_piece(root,"SignalMast",mast,Vector3(-17.7,1.1,17.7),timber)
	var flag := PrismMesh.new()
	flag.size = Vector3(.72,.42,.025)
	_piece(root,"SeaGreenPennant",flag,Vector3(-17.36,2.21,17.7),_mat("7caaa1")).rotation.z = PI*.5
	for i in 3:
		var p := Vector3(-18.1-i*.85,0,19.25+i*.25)
		p.y = float(sampler.sample_height(p))+.045
		var slab := BoxMesh.new()
		slab.size = Vector3(.64,.09,.42)
		_piece(root,"LandingStone%d" % i,slab,p,stone).rotation.y = -.2+i*.18
	# Broken former observatory foundation outside the working station footprint.
	for i in 3:
		var p := Vector3(-35.7+i*.9,0,26.8)
		p.y = float(sampler.sample_height(p))+.14
		var block := BoxMesh.new()
		block.size = Vector3(.72,.28,.55)
		_piece(root,"WeatheredFoundation%d" % i,block,p,stone).rotation.y = -.12+i*.08
	preload("res://scripts/presentation/ark_coast_nature.gd").new().build(world,sampler,"MoonbackNature",NATURE)
	ground_sources(world,sampler)

func _mat(color: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = .9
	return material

func _piece(root: Node3D, name_: String, mesh: Mesh, position: Vector3, material: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = name_
	piece.mesh = mesh
	piece.position = position
	piece.material_override = material
	root.add_child(piece)
	return piece

func ground_sources(world: Node3D, sampler: RefCounted) -> void:
	for id in SOURCES: ground_source(world.get_node_or_null(id),sampler)

func ground_source(node: Node3D, sampler: RefCounted) -> void:
	if not is_instance_valid(node) or str(node.name) not in SOURCES: return
	var ground: Variant = sampler.sample_height(node.global_position)
	if ground == null: return
	# Meshes and interaction target share the supported root. No reward is added.
	node.global_position.y = float(ground)+(.055 if str(node.name) == "MoonbackDriftwood" else -.0372)
