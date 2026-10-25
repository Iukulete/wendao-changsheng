extends RefCounted
const Limb = preload("res://scripts/presentation/ark_work_limb_math.gd")
## Temporary two-link game-piece arms reach the real basin. Original meshes,
## transforms and personal belongings are restored on completion/interruption.
var actor := ""
var entries: Array[Dictionary] = []
var root: Node3D
var limbs: Array[Dictionary] = []
var facing_marker: Node3D
var original_yaw := 0.0

func clear() -> void:
	if is_instance_valid(facing_marker): facing_marker.rotation.y = original_yaw
	facing_marker = null
	for entry in entries:
		var node: Variant = entry.node
		if is_instance_valid(node):
			node.transform = entry.transform
			node.visible = entry.visible
	entries.clear()
	limbs.clear()
	if is_instance_valid(root):
		if root.get_parent(): root.get_parent().remove_child(root)
		root.queue_free()
	root = null
	actor = ""

func _mesh(name_: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)
	return node

func _joint(name_: String, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = .065
	mesh.height = .13
	mesh.radial_segments = 8
	mesh.rings = 4
	return _mesh(name_,mesh,material)

func _segment(node: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	Limb.segment(node,a,b)

func apply(game: Node3D, resident_id: String, elapsed_us: int) -> void:
	var marker: Variant = game.traveler_marker if resident_id == "tidekeeper" else game.sailmaker_marker
	var body: Variant = game.traveler_body if resident_id == "tidekeeper" else game.sailmaker_body
	if not is_instance_valid(marker) or not is_instance_valid(body):
		clear()
		return
	if actor != resident_id or not is_instance_valid(root) or root.get_parent() != body: clear()
	if actor.is_empty():
		actor = resident_id
		facing_marker = marker
		original_yaw = marker.rotation.y
		root = Node3D.new()
		root.name = "TemporaryWashLimbPose"
		body.add_child(root)
		var skin: Material = body.get_node("Head").material_override
		for index in 2:
			var arm := body.get_node("ArmLeft" if index == 0 else "ArmRight") as MeshInstance3D
			var rest := arm.transform
			var bounds := arm.get_aabb()
			var shoulder := rest*Vector3(bounds.get_center().x,bounds.end.y,bounds.get_center().z)
			var length := (rest*Vector3(0,bounds.end.y,0)).distance_to(rest*Vector3(0,bounds.position.y,0))*.5
			entries.append({"node":arm,"transform":rest,"visible":arm.visible})
			arm.visible = false
			var cylinder := CylinderMesh.new()
			cylinder.height = 1
			cylinder.top_radius = .055
			cylinder.bottom_radius = .065
			cylinder.radial_segments = 8
			limbs.append({"shoulder":shoulder,"length":length,"upper":_mesh("Upper%d" % index,cylinder,arm.material_override),"fore":_mesh("Fore%d" % index,cylinder,arm.material_override),"elbow":_joint("Elbow%d" % index,arm.material_override),"hand":_joint("Hand%d" % index,skin)})
		if resident_id == "sailmaker":
			for name_ in ["OldSailBundle","ThreadSpool"]:
				var prop: Node3D = game.opening_coast.visual_child(marker,name_)
				if prop:
					entries.append({"node":prop,"transform":prop.transform,"visible":prop.visible})
					prop.visible = false
	# Base work/actor presentation runs every frame before this final overlay.
	# Keep cached original props hidden throughout, not just on the first frame.
	for entry in entries:
		if is_instance_valid(entry.node): entry.node.visible = false
	var facing: Vector3 = game.ModernUtilityProps.AT+Vector3(-.07,0,.31)-marker.position
	marker.rotation.y = atan2(facing.x,facing.z)
	var clock := float(elapsed_us)/1000000.0
	for index in limbs.size():
		var limb: Dictionary = limbs[index]
		var side := -1.0 if index == 0 else 1.0
		var target_world: Vector3 = game.ark_root.to_global(game.ModernUtilityProps.AT+Vector3(-.07+side*.12+sin(clock*8)*.015,.87+cos(clock*10)*.012,.31))
		var target: Vector3 = body.to_local(target_world)
		var shoulder: Vector3 = limb.shoulder
		var offset := target-shoulder
		var distance := offset.length()
		var direction := offset.normalized()
		var bend := Vector3(side,0,0)
		bend = (bend-direction*bend.dot(direction)).normalized()
		var length: float = maxf(limb.length,distance*.501)
		var elbow := (shoulder+target)*.5+bend*sqrt(maxf(0,length*length-distance*distance*.25))
		_segment(limb.upper,shoulder,elbow)
		_segment(limb.fore,elbow,target)
		limb.elbow.position = elbow
		limb.hand.position = target
