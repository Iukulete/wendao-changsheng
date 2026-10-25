extends RefCounted
## Narrow approval contract, not a replacement for physics/input exploration.
## Old world fixture bytes remain unchanged. Only these exact deltas may project.
const ARRAY_SHA := "35815a48973348bd8b940cca63a11b314a6114f821600c252135238d76908a36"
const SHADER_SHA := "92c1d728d53363f0d96e88a327855ffcf7be801e0fe6b347a99754702f00f9c1"
const SHADER := "res://shaders/ark_moonback_terrain.gdshader"

func material_spec() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(SHADER)
	for pair in [["grass","sparse_grass"],["sand","sand_03"],["rock","rock_boulder_dry"]]:
		for role in [["diff","diff"],["normal","nor_gl"],["rough","rough"]]:
			material.set_shader_parameter(pair[0]+"_"+role[0],load("res://art/coast/%s/%s_%s_1k.jpg" % [pair[1],pair[1],role[1]]))
	return material

func _bytes(value: Variant) -> String:
	return var_to_bytes(value).hex_encode().sha256_text()

func legacy_geometry(observer: Object) -> Dictionary:
	# This unchanged builder is separately checked against the ORIGINAL Moonback
	# golden in ark_landmass_surface_test. No candidate geometry is used here.
	var legacy := load("res://scripts/ark_landmass_builder.gd").new().build_island("MoonbackIsland",Vector3(-28,0,23),Vector2(14,12),5.4,Color("4e615a"),Color("87928a")) as StaticBody3D
	var mesh: ArrayMesh = legacy.get_node("Grassland").mesh
	var observed_arrays: Variant = observer.call("_geometry_plain",mesh.surface_get_arrays(0))
	var old_shape: Dictionary = observer.call("_resource",legacy.get_node("GrasslandCollision").shape)
	var row := {"surface":{"primitive":Mesh.PRIMITIVE_TRIANGLES,"arrays":JSON.stringify(observed_arrays,"",true).sha256_text()},"data":old_shape.data}
	legacy.free()
	return row

func _plain(value: Variant) -> Variant:
	if value is Shader: return {"class":value.get_class(),"code":value.code}
	if value is Texture2D:
		var image: Image = value.get_image()
		return {"path":value.resource_path,"class":value.get_class(),"size":value.get_size(),"bytes":_bytes(image.get_data())}
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
	return value

func validate(world: Node3D, observer: Object) -> Dictionary:
	var island := world.get_node("MoonbackIsland") as StaticBody3D
	var check := func(ok: bool,message: String) -> void: observer.call("_check",ok,"MOONBACK_CONTRACT: "+message)
	check.call(island.get_child_count() == 4 and island.transform == Transform3D(Basis.IDENTITY,Vector3(-28,0,23)) and island.visible and island.collision_layer == 1 and island.collision_mask == 1,"original root policy/cardinality")
	var legacy := load("res://scripts/ark_landmass_builder.gd").new().build_island("MoonbackIsland",Vector3(-28,0,23),Vector2(14,12),5.4,Color("4e615a"),Color("87928a")) as StaticBody3D
	var expected_material := _bytes(_plain(material_spec()))
	check.call(FileAccess.get_sha256(SHADER) == SHADER_SHA,"approved new shader bytes")
	var snapshot := {}
	for part in ["Grassland","Shoreline"]:
		var visual := island.get_node(part) as MeshInstance3D
		var collision := island.get_node(part+"Collision") as CollisionShape3D
		var mesh := visual.mesh as ArrayMesh
		var actual_material := visual.material_override as ShaderMaterial
		check.call(actual_material != null and actual_material.shader != null and actual_material.shader.code.sha256_text() == SHADER_SHA,"approved Moonback runtime shader bytes, independently of cached material-spec shader identity")
		check.call(mesh != null and mesh.get_surface_count() == 1 and mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES,"single triangle surface "+part)
		check.call(visual.transform == Transform3D.IDENTITY and visual.visible and visual.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON and visual.layers == 1 and visual.material_overlay == null,"unaltered local visual policy "+part)
		check.call(collision.transform == Transform3D.IDENTITY and not collision.disabled and collision.shape is ConcavePolygonShape3D and collision.shape.backface_collision,"enabled local collision "+part)
		check.call(_bytes(mesh.get_faces()) == _bytes(collision.shape.get_faces()),"exact physical mesh faces "+part)
		check.call(_bytes(_plain(visual.material_override)) == expected_material and _bytes(_plain(visual.get_active_material(0))) == expected_material,"complete independently specified material "+part)
		var arrays: Array = mesh.surface_get_arrays(0)
		if part == "Grassland":
			check.call(_bytes(arrays) == ARRAY_SHA and mesh.get_faces().size() == 5664*3,"approved highland vertex/normal/UV/tangent bytes")
		else:
			check.call(_bytes(arrays) == _bytes(legacy.get_node(part).mesh.surface_get_arrays(0)),"shoreline footprint/slope arrays retained exactly")
		snapshot[part] = _bytes([arrays,collision.shape.get_faces(),_plain(visual.material_override),visual.transform,collision.transform])
	legacy.free()
	var station := world.get_node("MoonbackTideStation") as Node3D
	check.call(station.transform == Transform3D(Basis.IDENTITY,Vector3(-32,3.03,25)),"station actually stands on the authored highland; no hidden pivot/XZ inverse")
	snapshot.station = station.transform
	return snapshot
