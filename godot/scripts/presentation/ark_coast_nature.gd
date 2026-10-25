extends RefCounted
## Static, bounded author-made CC0 props. Four shared meshes, not a Node per leaf.
const Profile = preload("res://scripts/terrain/ark_coast_profile_v2.gd")
const ROOT := "CoastNatureV2"
const ASSETS := "res://art/coast_nature/"
const GROUPS := {
	"Pine_1": [[3.9,-14.5,.52,.3],[5.0,-18.7,.48,1.7],[14.0,-21.0,.57,2.2],[19.2,-16.8,.54,4.2]],
	"Bush_Common": [[4.5,-12.0,.42,.2],[3.3,-16.0,.48,2.0],[7.0,-21.1,.38,1.4],[13.8,-19.1,.45,.9],[15.0,-20.2,.48,3.4],[17.0,-17.0,.5,2.0],[19.8,-15.2,.4,3.1],[20.4,-11.0,.42,.7]],
	"Fern_1": [[5.5,-11.9,.26,0],[4.6,-13.2,.35,1],[3.4,-14.7,.3,2],[4.1,-17.6,.36,3],[6.1,-20.4,.3,1],[8.0,-21.5,.34,0],[13.5,-18.5,.36,2],[14.5,-19.0,.33,1],[15.3,-20.6,.3,2],[17.2,-16.6,.35,0],[18.5,-17.9,.4,2],[20.3,-14.8,.32,1]],
	"Rock_Medium_1": [[4.1,-16.9,.35,1.0],[8.5,-21.5,.28,2.4],[13.9,-20.5,.4,.6],[20.5,-14.2,.32,3.0]],
}

func build(world: Node3D, coast: RefCounted, root_name: String = ROOT, groups: Dictionary = GROUPS) -> Node3D:
	assert(world.get_node_or_null(root_name) == null)
	var root := Node3D.new()
	root.name = root_name
	world.add_child(root)
	for model in groups:
		var source: Node3D = load(ASSETS + model + ".gltf").instantiate()
		var parts: Array[Node] = source.find_children("*", "MeshInstance3D", true, false)
		assert(parts.size() == 1 and parts[0].transform.is_equal_approx(Transform3D.IDENTITY))
		var mesh: Mesh = parts[0].mesh
		var bounds := mesh.get_aabb()
		var transforms: Array[Transform3D] = []
		for placement in groups[model]:
			var point := Vector3(placement[0], 0, placement[1])
			var height: Variant = coast.sample_height(point)
			assert(height != null, "Nature prop outside installed terrain")
			point.y = float(height) - bounds.position.y * float(placement[2]) - .025
			var basis := Basis(Vector3.UP, float(placement[3])).scaled(Vector3.ONE * float(placement[2]))
			var transform := Transform3D(basis, point)
			transforms.append(transform)
			if model == "Pine_1":
				# Actual trunk obstruction only; needles never form invisible walls.
				var body := StaticBody3D.new()
				body.name = "PineTrunk%02d" % transforms.size()
				body.position = Vector3(point.x, float(height) + .65, point.z)
				var collision := CollisionShape3D.new()
				collision.name = "CollisionShape3D"
				var shape := CapsuleShape3D.new()
				shape.radius = .12
				shape.height = 1.3
				collision.shape = shape
				body.add_child(collision)
				root.add_child(body)
			elif model == "Rock_Medium_1":
				var body := StaticBody3D.new()
				body.name = "NatureRock%02d" % transforms.size()
				body.transform = transform
				var collision := CollisionShape3D.new()
				collision.name = "CollisionShape3D"
				collision.shape = mesh.create_trimesh_shape()
				body.add_child(collision)
				root.add_child(body)
		var batch := MultiMeshInstance3D.new()
		batch.name = model
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh = mesh
		batch.multimesh.instance_count = transforms.size()
		# CPU audit survives the headless dummy renderer, whose MultiMesh getters
		# return identity. Display-backed acceptance also checks actual GPU data.
		batch.set_meta("coast_instances", transforms.duplicate())
		for index in transforms.size(): batch.multimesh.set_instance_transform(index, transforms[index])
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if model in ["Pine_1", "Rock_Medium_1"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(batch)
		source.free()
	return root
