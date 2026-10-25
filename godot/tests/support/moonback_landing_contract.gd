extends RefCounted
## Separate reviewed addition fingerprint; original historical fixture is untouched.
const ROOTS := ["MoonbackOldLanding","MoonbackNature"]
const EXPECTED_SHA := "2a929b18da455b6d3b623759433b9869008d16ea5bb15a397ef404159f4b7c4e"
const EXPECTED_NODES := 48
const EXPECTED_MESHES := 26
const EXPECTED_MATERIAL_ROWS := 21 # Legacy observer visits MeshInstance3D, not five MultiMesh batches.
var allowed := {}
var meshes := {}

func _plain(value: Variant) -> Variant:
	if value is Texture2D:
		return {"class":value.get_class(),"path":value.resource_path,"bytes":FileAccess.get_sha256(value.resource_path)}
	if value is Shader: return {"class":"Shader","code":value.code}
	if value is Resource:
		var row := {"class":value.get_class()}
		for property in value.get_property_list():
			var id := str(property.name)
			if int(property.usage)&PROPERTY_USAGE_STORAGE and id not in ["resource_name","resource_path","resource_local_to_scene","script"]:
				row[id] = _plain(value.get(id))
		return row
	if value is Array:
		var rows := []
		for item in value: rows.append(_plain(item))
		return rows
	if value is Dictionary:
		var row := {}
		for key in value: row[str(key)] = _plain(value[key])
		return row
	return value

func fingerprint(world: Node3D) -> String:
	allowed.clear()
	meshes.clear()
	var rows := []
	for name_ in ROOTS:
		var root := world.get_node_or_null(name_)
		if root == null: return "missing:"+name_
		var nodes: Array[Node] = [root]
		nodes.append_array(root.find_children("*","",true,false))
		for node in nodes:
			var path := str(world.get_path_to(node))
			allowed[path] = node.get_class()
			var row := {"path":path,"class":node.get_class()}
			if node is Node3D: row.merge({"transform":node.transform,"visible":node.visible,"top_level":node.top_level})
			if node is CollisionObject3D: row.merge({"layer":node.collision_layer,"mask":node.collision_mask})
			if node is CollisionShape3D: row.merge({"shape":_plain(node.shape),"disabled":node.disabled})
			if node is MeshInstance3D or node is MultiMeshInstance3D:
				meshes[path] = true
				row.merge({"override":_plain(node.material_override),"overlay":_plain(node.material_overlay),"shadows":node.cast_shadow,"layers":node.layers})
				var mesh: Mesh = node.mesh if node is MeshInstance3D else node.multimesh.mesh
				var surfaces := []
				for i in mesh.get_surface_count():
					var arrays: Array = mesh.get_mesh_arrays() if mesh is PrimitiveMesh else mesh.surface_get_arrays(i)
					var primitive: int = Mesh.PRIMITIVE_TRIANGLES if mesh is PrimitiveMesh else mesh.surface_get_primitive_type(i)
					surfaces.append([primitive,arrays,_plain(mesh.surface_get_material(i))])
				row["surfaces"] = surfaces
				if node is MultiMeshInstance3D: row.merge({"instances":node.get_meta("coast_instances"),"count":node.multimesh.instance_count,"format":node.multimesh.transform_format,"visible_count":node.multimesh.visible_instance_count})
			rows.append(row)
	return var_to_bytes(rows).hex_encode().sha256_text()

func validate(world: Node3D,observer: Object) -> void:
	var sha := fingerprint(world)
	observer.call("_check",sha == EXPECTED_SHA and allowed.size() == EXPECTED_NODES and meshes.size() == EXPECTED_MESHES,"MOONBACK_LANDING_CONTRACT: exact reviewed static geometry/materials/collision/placements: "+sha+" nodes="+str(allowed.size())+" meshes="+str(meshes.size()))
	for id in ["MoonbackDriftwood","MoonbackTidalShells"]:
		var node := world.get_node_or_null(id) as Node3D
		if node == null or node.is_queued_for_deletion(): continue
		var xz := Vector2(-20,18) if id == "MoonbackDriftwood" else Vector2(-23,14)
		var y: float = float(world._ground_height_at(Vector3(xz.x,0,xz.y)))+(.055 if id == "MoonbackDriftwood" else -.0372)
		observer.call("_check",node.transform.is_equal_approx(Transform3D(Basis.IDENTITY,Vector3(xz.x,y,xz.y))),"MOONBACK_LANDING_CONTRACT: supported original stable supply root "+id)
	if DisplayServer.get_name() != "headless":
		for root in ROOTS:
			for batch in world.get_node(root).find_children("*","MultiMeshInstance3D",true,false):
				var transforms: Array = batch.get_meta("coast_instances")
				for i in transforms.size(): observer.call("_check",batch.multimesh.get_instance_transform(i).is_equal_approx(transforms[i]),"MOONBACK_LANDING_CONTRACT: actual rendered instance "+str(batch.name)+str(i))
