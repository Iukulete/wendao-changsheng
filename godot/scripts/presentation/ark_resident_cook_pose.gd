extends RefCounted
## Small reversible graybox work pose, not final character animation.
const Limb = preload("res://scripts/presentation/ark_work_limb_math.gd")
var root: Node3D
var steam_root: Node3D
var marker: Node3D
var pot: Node3D
var original_yaw := 0.0
var entries: Array[Dictionary] = []
var limbs: Array[Dictionary] = []
var steam: Array[MeshInstance3D] = []
var ladle: MeshInstance3D
var ladle_bowl: MeshInstance3D

func clear() -> void:
	if is_instance_valid(marker): marker.rotation.y = original_yaw
	for entry in entries:
		if is_instance_valid(entry.node):
			entry.node.transform = entry.transform
			entry.node.visible = entry.visible
	for node in [root,steam_root]:
		if is_instance_valid(node):
			if node.get_parent(): node.get_parent().remove_child(node)
			node.queue_free()
	root = null
	steam_root = null
	marker = null
	pot = null
	entries.clear()
	limbs.clear()
	steam.clear()
	ladle = null
	ladle_bowl = null

func _mesh(parent: Node3D,name_: String,mesh: Mesh,material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func _material(color: String) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(color)
	result.roughness = .86
	return result

func apply(game: Node3D,station: Dictionary,elapsed: int) -> void:
	var body: Node3D = game.traveler_body
	if not is_instance_valid(body) or station.is_empty():
		clear()
		return
	if not is_instance_valid(root) or root.get_parent() != body or not is_instance_valid(pot) or pot != station.node:
		clear()
		marker = game.traveler_marker
		original_yaw = marker.rotation.y
		pot = station.node
		root = Node3D.new()
		root.name = "TemporaryKitchenWorkPose"
		body.add_child(root)
		for i in 2:
			var arm := body.get_node("ArmLeft" if i == 0 else "ArmRight") as MeshInstance3D
			var rest := arm.transform
			var bounds := arm.get_aabb()
			var shoulder := rest*Vector3(bounds.get_center().x,bounds.end.y,bounds.get_center().z)
			var length := (rest*Vector3(0,bounds.end.y,0)).distance_to(rest*Vector3(0,bounds.position.y,0))*.5
			entries.append({"node":arm,"transform":rest,"visible":arm.visible})
			var cylinder := CylinderMesh.new()
			cylinder.height = 1
			cylinder.top_radius = .055
			cylinder.bottom_radius = .065
			cylinder.radial_segments = 8
			var sphere := SphereMesh.new()
			sphere.radius = .06
			sphere.height = .12
			sphere.radial_segments = 8
			sphere.rings = 4
			limbs.append({"shoulder":shoulder,"length":length,"upper":_mesh(root,"Upper%d" % i,cylinder,arm.material_override),"fore":_mesh(root,"Fore%d" % i,cylinder,arm.material_override),"elbow":_mesh(root,"Elbow%d" % i,sphere,arm.material_override),"hand":_mesh(root,"Hand%d" % i,sphere,body.get_node("Head").material_override)})
		steam_root = Node3D.new()
		steam_root.name = "TemporaryKitchenSteam"
		pot.add_child(steam_root)
		for i in 3:
			var puff := SphereMesh.new()
			puff.radius = .05+i*.01
			puff.height = .13+i*.03
			puff.radial_segments = 8
			puff.rings = 4
			var material := _material("d6dfd8")
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color.a = .22
			steam.append(_mesh(steam_root,"Steam%d" % i,puff,material))
		if not station.pressure:
			for name_ in ["PotLid","LidHandle"]:
				var lid := pot.get_node_or_null(name_) as Node3D
				if lid: entries.append({"node":lid,"transform":lid.transform,"visible":lid.visible})
			var shaft := CylinderMesh.new()
			shaft.height = 1
			shaft.top_radius = .018
			shaft.bottom_radius = .025
			shaft.radial_segments = 8
			ladle = _mesh(root,"WoodenLadle",shaft,_material("ac8658"))
			var bowl := SphereMesh.new()
			bowl.radius = .055
			bowl.height = .075
			bowl.radial_segments = 8
			bowl.rings = 4
			ladle_bowl = _mesh(root,"LadleBowl",bowl,_material("ac8658"))
			var soup := CylinderMesh.new()
			soup.top_radius = .17
			soup.bottom_radius = .17
			soup.height = .015
			soup.radial_segments = 16
			_mesh(steam_root,"WorkingSoup",soup,_material("d9c395")).position.y = .105
	for entry in entries:
		if is_instance_valid(entry.node): entry.node.visible = false
	var direction: Vector3 = game.ark_root.to_local(pot.global_position)-marker.position
	marker.rotation.y = atan2(direction.x,direction.z)
	var clock := float(elapsed)/1000000.0
	for i in 2:
		var local_target := Vector3(-.1 if i == 0 else .06,.35,.12)
		if station.pressure: local_target = Vector3(-.29,.23,.02) if i == 0 else Vector3(.05,.37,.02)
		else: local_target += Vector3(cos(clock*4+i)*.045,sin(clock*5)*.015,sin(clock*4+i)*.045)
		var target: Vector3 = body.to_local(pot.to_global(local_target))
		var limb: Dictionary = limbs[i]
		var elbow := Limb.elbow(limb.shoulder,target,limb.length,-1 if i == 0 else 1)
		Limb.segment(limb.upper,limb.shoulder,elbow)
		Limb.segment(limb.fore,elbow,target)
		limb.elbow.position = elbow
		limb.hand.position = target
		if i == 1 and is_instance_valid(ladle):
			var tip: Vector3 = body.to_local(pot.to_global(Vector3(cos(clock*4)*.06,.12,sin(clock*4)*.06)))
			Limb.segment(ladle,target,tip)
			ladle_bowl.position = tip
	for i in steam.size():
		steam[i].position = Vector3(sin(clock*2+i)*.055,.29+i*.14+fmod(clock*.1,.14),cos(clock*2+i)*.035)
