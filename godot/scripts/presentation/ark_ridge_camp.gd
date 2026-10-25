extends RefCounted
## One physical landmark. Reward ownership stays in the game/economy, not meshes.
const Profile = preload("res://scripts/terrain/ark_coast_profile_v2.gd")
const ROOT := "RidgeOldCamp"
const BLUEPRINT := "storm_raft_fenders"
const COST := 4

static func _material(color: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = .9
	return material

static func _piece(root: Node3D, name_: String, mesh: Mesh, at: Vector3, color: String) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = name_
	piece.mesh = mesh
	piece.position = at
	piece.material_override = _material(color)
	root.add_child(piece)
	return piece

static func build(game: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = ROOT
	root.position = Profile.CAMP
	var actual: Variant = game.opening_coast.sample_height(root.position)
	assert(actual != null)
	root.position.y = float(actual)
	game.add_child(root)
	var mast := CylinderMesh.new()
	mast.top_radius = .035
	mast.bottom_radius = .05
	mast.height = 2.6
	_piece(root, "WeatheredMast", mast, Vector3(-.7,1.3,-.45), "706451")
	var sail := PrismMesh.new()
	sail.size = Vector3(1.15,.75,.045)
	var flag := _piece(root, "OchreSignal", sail, Vector3(-.12,2.18,-.45), "c79656")
	flag.rotation.z = PI * .5
	for index in 5:
		var board := BoxMesh.new()
		board.size = Vector3(1.4,.055,.19)
		_piece(root, "OldDeck%02d" % index, board, Vector3(.0,.04,index*.22-.44), "85745c")
	var crate := BoxMesh.new()
	crate.size = Vector3(.62,.38,.43)
	_piece(root, "ChartBox", crate, Vector3(.2,.26,.03), "5f5749")
	var chart := BoxMesh.new()
	chart.size = Vector3(.48,.015,.35)
	_piece(root, "FenderDrawing", chart, Vector3(.2,.465,.03), "dfd0a1")
	for index in 3:
		var line := BoxMesh.new()
		line.size = Vector3(.32,.009,.018)
		_piece(root, "Drawing%02d" % index, line, Vector3(.2,.477,index*.08-.05), "6b786d")
	var ring := TorusMesh.new()
	ring.inner_radius = .14
	ring.outer_radius = .20
	_piece(root, "DiscardedRope", ring, Vector3(-.4,.11,.12), "a28b61")
	var label := Label3D.new()
	label.name = "Name"
	label.text = "岩脊旧营地 · E 查看"
	label.font = game.UI_FONT
	label.font_size = 22
	label.pixel_size = .003
	label.position = Vector3(0,1.1,0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.modulate = Color("e5d4a9")
	game._style_nearby_world_label(label)
	root.add_child(label)
	game.interactables.append({"id":"ridge_camp", "node":root, "amount":0})
	return root

static func add_fenders(ark: Node3D) -> void:
	if ark.get_node_or_null("RaftStormFenders") != null: return
	var root := Node3D.new()
	root.name = "RaftStormFenders"
	ark.add_child(root)
	for side in [-1, 1]:
		for index in 3:
			var log := CylinderMesh.new()
			log.top_radius = .12
			log.bottom_radius = .15
			log.height = 1.18
			log.radial_segments = 10
			var piece := _piece(root, "Fender_%d_%d" % [side,index], log, Vector3(side*3.06,-.13,(index-1)*1.24), "78654a")
			piece.rotation.x = PI*.5
			for offset in [-.36,.36]:
				var ring := TorusMesh.new()
				ring.inner_radius = .14
				ring.outer_radius = .165
				var tie := _piece(root,"Rope_%d_%d_%d" % [side,index,int(offset*100)],ring,Vector3(side*3.06,-.13,(index-1)*1.24+offset),"b7a47a")
				tie.rotation.x = PI*.5
