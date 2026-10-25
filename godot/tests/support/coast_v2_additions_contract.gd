extends RefCounted
## Independent narrow world-graph specification. Never ignores an arbitrary root.
const PLACEMENTS := {
	"Pine_1": [[3.9,-14.5,.52,.3],[5.0,-18.7,.48,1.7],[14.0,-21.0,.57,2.2],[19.2,-16.8,.54,4.2]],
	"Bush_Common": [[4.5,-12.0,.42,.2],[3.3,-16.0,.48,2.0],[7.0,-21.1,.38,1.4],[13.8,-19.1,.45,.9],[15.0,-20.2,.48,3.4],[17.0,-17.0,.5,2.0],[19.8,-15.2,.4,3.1],[20.4,-11.0,.42,.7]],
	"Fern_1": [[5.5,-11.9,.26,0],[4.6,-13.2,.35,1],[3.4,-14.7,.3,2],[4.1,-17.6,.36,3],[6.1,-20.4,.3,1],[8.0,-21.5,.34,0],[13.5,-18.5,.36,2],[14.5,-19.0,.33,1],[15.3,-20.6,.3,2],[17.2,-16.6,.35,0],[18.5,-17.9,.4,2],[20.3,-14.8,.32,1]],
	"Rock_Medium_1": [[4.1,-16.9,.35,1.0],[8.5,-21.5,.28,2.4],[13.9,-20.5,.4,.6],[20.5,-14.2,.32,3.0]],
}
var observer: Object
var allowed := {}
var meshes := {}

func _check(ok: bool, message: String) -> void:
	observer.call("_check",ok,"V2 additions: " + message)

func _node(root: Node, path: String, type: String) -> Node:
	var node := root if path.is_empty() else root.get_node_or_null(path)
	_check(node != null and node.is_class(type),path + " has exact approved class")
	allowed[str(root.name) + ("/" + path if not path.is_empty() else "")] = true
	return node

func validate(game: Node3D, reference: RefCounted, test: Object) -> void:
	observer = test
	allowed.clear()
	meshes.clear()
	var nature := game.get_node("CoastNatureV2")
	_node(nature,"","Node3D")
	_check(nature.transform == Transform3D.IDENTITY,"nature root cannot move")
	for model in PLACEMENTS:
		var source: Node3D = load("res://art/coast_nature/" + model + ".gltf").instantiate()
		var mesh: Mesh = source.find_children("*","MeshInstance3D",true,false)[0].mesh
		var bounds := mesh.get_aabb()
		var batch := _node(nature,model,"MultiMeshInstance3D") as MultiMeshInstance3D
		_check(batch.transform == Transform3D.IDENTITY and batch.multimesh.instance_count == PLACEMENTS[model].size(),model + " exact batch size and root")
		_check(var_to_bytes(batch.multimesh.mesh.get_faces()) == var_to_bytes(mesh.get_faces()),model + " original imported mesh bytes")
		for index in PLACEMENTS[model].size():
			var p: Array = PLACEMENTS[model][index]
			var point := Vector3(p[0],0,p[1])
			var height := float(reference.sample_height(point))
			point.y = height - bounds.position.y * float(p[2]) - .025
			var expected := Transform3D(Basis(Vector3.UP,float(p[3])).scaled(Vector3.ONE*float(p[2])),point)
			_check(batch.get_meta("coast_instances")[index].is_equal_approx(expected),model + " exact CPU placement %d" % index)
			if DisplayServer.get_name() != "headless":
				_check(batch.multimesh.get_instance_transform(index).is_equal_approx(expected),model + " actual renderer placement %d" % index)
			if model in ["Pine_1","Rock_Medium_1"]:
				var name_ := ("PineTrunk" if model == "Pine_1" else "NatureRock") + "%02d" % (index+1)
				var body := _node(nature,name_,"StaticBody3D") as StaticBody3D
				var shape := _node(nature,name_+"/CollisionShape3D","CollisionShape3D") as CollisionShape3D
				_check(body.collision_layer == 1 and body.collision_mask == 1 and not shape.disabled,"physical obstruction keeps canonical collision policy")
				if model == "Pine_1":
					_check(body.position.is_equal_approx(Vector3(point.x,height+.65,point.z)) and body.basis == Basis.IDENTITY,"trunk aligned with tree")
					_check(shape.shape is CapsuleShape3D and is_equal_approx(shape.shape.radius,.12) and is_equal_approx(shape.shape.height,1.3),"trunk only, no foliage wall")
				else:
					_check(body.transform.is_equal_approx(expected) and shape.shape is ConcavePolygonShape3D and var_to_bytes(shape.shape.get_faces()) == var_to_bytes(mesh.get_faces()),"rock collision is the actual rendered mesh")
		_check(batch.cast_shadow == (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if model in ["Pine_1","Rock_Medium_1"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),"bounded shadow policy")
		source.free()
	var camp := game.get_node("RidgeOldCamp")
	_node(camp,"","Node3D")
	_check(camp.position.is_equal_approx(Vector3(10.6,float(reference.sample_height(Vector3(10.6,0,-18.5))),-18.5)) and camp.basis == Basis.IDENTITY,"camp on independently sampled V2 ground")
	var expected := {
		"WeatheredMast":["CylinderMesh",Vector3(-.7,1.3,-.45),"706451"],
		"OchreSignal":["PrismMesh",Vector3(-.12,2.18,-.45),"c79656"],
		"ChartBox":["BoxMesh",Vector3(.2,.26,.03),"5f5749"],
		"FenderDrawing":["BoxMesh",Vector3(.2,.465,.03),"dfd0a1"],
		"DiscardedRope":["TorusMesh",Vector3(-.4,.11,.12),"a28b61"],
	}
	for index in 5: expected["OldDeck%02d"%index] = ["BoxMesh",Vector3(0,.04,index*.22-.44),"85745c"]
	for index in 3: expected["Drawing%02d"%index] = ["BoxMesh",Vector3(.2,.477,index*.08-.05),"6b786d"]
	for name_ in expected:
		var piece := _node(camp,name_,"MeshInstance3D") as MeshInstance3D
		var spec: Array = expected[name_]
		_check(piece.mesh.is_class(spec[0]) and piece.position.is_equal_approx(spec[1]) and piece.scale.is_equal_approx(Vector3.ONE),"camp explicit primitive and placement " + name_)
		_check(piece.material_override is StandardMaterial3D and piece.material_override.albedo_color.is_equal_approx(Color(spec[2])) and is_equal_approx(piece.material_override.roughness,.9),"camp explicit worn palette " + name_)
		if piece.mesh is BoxMesh:
			var size := Vector3(1.4,.055,.19) if name_.begins_with("OldDeck") else Vector3(.32,.009,.018) if name_.begins_with("Drawing") else Vector3(.62,.38,.43) if name_ == "ChartBox" else Vector3(.48,.015,.35)
			_check(piece.mesh.size.is_equal_approx(size) and piece.rotation.is_zero_approx(),"camp exact box dimensions and rotation " + name_)
		elif piece.mesh is CylinderMesh:
			_check(is_equal_approx(piece.mesh.height,2.6) and is_equal_approx(piece.mesh.top_radius,.035) and is_equal_approx(piece.mesh.bottom_radius,.05),"exact mast dimensions")
		elif piece.mesh is PrismMesh:
			_check(piece.mesh.size.is_equal_approx(Vector3(1.15,.75,.045)) and piece.rotation.is_equal_approx(Vector3(0,0,PI*.5)),"exact signal silhouette")
		elif piece.mesh is TorusMesh:
			_check(is_equal_approx(piece.mesh.inner_radius,.14) and is_equal_approx(piece.mesh.outer_radius,.20),"exact discarded rope ring")
		meshes["RidgeOldCamp/"+name_] = true
	_node(camp,"Name","Label3D")
	var actual := {}
	for root in [nature,camp]:
		actual[str(root.name)] = true
		for child in root.find_children("*","",true,false): actual[str(root.name)+"/"+str(root.get_path_to(child))] = true
	_check(actual == allowed and allowed.size() == 36,"only the exact 36 reviewed new nodes; no broad subtree exclusion")
