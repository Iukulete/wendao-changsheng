extends RefCounted
## Reversible home material/set dressing. No physics, economy, actor or save
## ownership. Every mutation is reversible; rebuilt nodes are discovered anew.
const TIMBER_PATH := "res://art/home_sample/home_timber_albedo_v1.png"
const COAST_SHADER = preload("res://shaders/ark_coast_home_sample.gdshader")
const TIMBER_SHADER = preload("res://shaders/ark_home_joinery.gdshader")
const CANVAS_SHADER = preload("res://shaders/ark_home_canvas.gdshader")
# Legacy rail resizing and the meal planner still inspect these BoxMesh objects.
# Preserve their resource/type identity while changing only their material.
const LOGIC_BOX_PARENTS := ["RaftBow", "RaftPort", "RaftStarboard", "Cot", "HearthStone"]
var enabled := false
var _originals: Dictionary = {}
var _decor: Array[WeakRef] = []
var _materials: Dictionary = {}
var _bevels: Dictionary = {}
var _marker_originals: Dictionary = {}
var _timber: Texture2D
var furniture := preload("res://scripts/presentation/ark_cabin_furniture.gd").new()
var room_view := preload("res://scripts/presentation/ark_room_view.gd").new()
var vessel := preload("res://scripts/presentation/ark_vessel_skin.gd").new()

func timber_texture() -> Texture2D:
	if _timber == null: _timber = load(TIMBER_PATH) as Texture2D
	return _timber

func set_enabled(world: Node3D, value: bool) -> void:
	if not value:
		restore()
		enabled = false
		return
	enabled = true
	apply(world)

func apply(world: Node3D) -> void:
	if not enabled or world == null: return
	for id in _marker_originals.keys():
		var marker: Node = _marker_originals[id].node.get_ref()
		if not is_instance_valid(marker): _marker_originals.erase(id)
		elif not marker.is_inside_tree():
			marker.visible = _marker_originals[id].visible
			_marker_originals.erase(id)
	for id in _originals.keys():
		var tracked: Node = _originals[id].node.get_ref()
		if tracked == null or tracked.is_queued_for_deletion(): _originals.erase(id)
		elif not tracked.is_inside_tree():
			# A temporarily detached/reparented part is not necessarily being freed.
			# Restore it before forgetting, so a later reattachment has a real baseline.
			tracked.material_override = _originals[id].material
			tracked.mesh = _originals[id].mesh
			_originals.erase(id)
	for index in range(_decor.size() - 1, -1, -1):
		var tracked: Node = _decor[index].get_ref()
		if tracked == null or tracked.is_queued_for_deletion(): _decor.remove_at(index)
		elif not tracked.is_inside_tree():
			tracked.free()
			_decor.remove_at(index)
	var ark := world.get_node_or_null("ArkRoot") as Node3D
	if ark == null: return
	for path in ["RaftBase", "RaftTop", "RaftBow", "RaftPort", "RaftStarboard", "RaftSternPort", "RaftSternStarboard", "RaftBoardingGangplank", "BuiltShelter", "BuiltStorage", "BuiltWorkbench", "BuiltRaftExtension", "ModernWaterCorner"]:
		var part := ark.get_node_or_null(path)
		if part == null: continue
		for node in part.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if _under_candidate(mesh): continue
			var relative: String = str(path) + "/" + str(part.get_path_to(mesh))
			var role := _role(relative)
			if not role.is_empty(): _paint(mesh, _material(role))
	var coast := world.get_node_or_null("IslandLandmass/Shoreline") as MeshInstance3D
	if coast != null and coast.material_override is ShaderMaterial:
		var id := coast.get_instance_id()
		_remember(coast)
		if not _materials.has("coast"):
			var original := _originals[id].material as ShaderMaterial
			var material := original.duplicate() as ShaderMaterial
			material.shader = COAST_SHADER
			_materials.coast = material
		_paint(coast, _materials.coast)
		var cap := world.get_node_or_null("IslandLandmass/SubmergedVisualCap") as MeshInstance3D
		if cap: _paint(cap, _materials.coast)
	if not ark.has_node("HomeArtCandidate"):
		_deck_details(_new_decor(ark))
	for path in ["homeMarker", "helmMarker"]:
		var marker := ark.get_node_or_null(path)
		if marker == null or marker.get_child_count() == 0: continue
		var pole := marker.get_child(0) as MeshInstance3D
		if pole == null or not pole.mesh is CylinderMesh: continue
		var id := pole.get_instance_id()
		if not _marker_originals.has(id): _marker_originals[id] = {"node":weakref(pole), "visible":pole.visible}
		pole.visible = false
	var shelter := ark.get_node_or_null("BuiltShelter") as Node3D
	if shelter != null and not shelter.has_node("HomeArtCandidate"):
		_cabin_details(_new_decor(shelter))
		var roof := shelter.get_node_or_null("Roof/CenterFace") as Node3D
		if roof != null: _roof_details(_new_decor(roof))
	furniture.apply(world)
	vessel.apply(world,ark.get_node_or_null("HomeArtCandidate"),{"timber":_material("timber"),"dark":_material("dark_timber"),"trim":_material("painted_timber"),"rope":_material("rope")})
	update_visibility(world)

func _under_candidate(node: Node) -> bool:
	var parent := node.get_parent()
	while parent != null:
		if parent.name == "HomeArtCandidate": return true
		parent = parent.get_parent()
	return false

func update_visibility(world: Node3D) -> void:
	if enabled: room_view.update(world, _material("wall_panel"), _material("painted_timber"))

func _role(path: String) -> String:
	var text := path.to_lower()
	if text.begins_with("modernwatercorner/"):
		# Explicit static-part allowlist. Live indicator/water/gauge materials stay
		# StandardMaterial3D and retain their resource identity and update owner.
		var part := text.get_file()
		if part == "timberplinth": return "timber"
		if part in ["batterystrap", "tapupright", "tapspout", "frame"]: return "metal"
		if part in ["battery", "purifiercontrol", "intakearm", "intakehose"]: return "equipment_dark"
		if part in ["cleanwatertank", "filtercartridge", "basinstand"] or part.begins_with("canopypost"): return "equipment_teal"
		if part in ["purifierhousing", "basin"]: return "ceramic"
		return ""
	# Preserve gameplay/emissive cues and resident gifts instead of painting every
	# mesh indiscriminately (food, hot coals, steam machinery and actors excluded).
	for excluded in ["hearth", "soup", "pressure", "lamp", "socket", "keepsake", "sharedmeal", "awninggift", "sailmakerawning", "name", "reef"]:
		if text.contains(excluded): return ""
	if text.contains("fronthandle"): return "brass"
	if text.contains("canvasedgebinding") or text.contains("canvaspatchseam"): return "rope"
	for cloth in ["canvas", "quilt", "bedroll", "mattress", "curtain"]:
		if text.contains(cloth): return "cloth" if text.contains("canvas") or text.contains("curtain") else "linen"
	for rope in ["lashing", "binding"]:
		if text.contains(rope): return "rope"
	if text.contains("roof/"): return "cloth"
	if text.contains("herb"): return ""
	if text.begins_with("builtshelter/back/") or text.begins_with("builtshelter/left/") or text.begins_with("builtshelter/right/"): return "wall_panel"
	if text.contains("guestcabin/backwall/") or text.contains("guestcabin/portwall/") or text.contains("guestcabin/starboardwall/"): return "wall_panel"
	if text.begins_with("rafttop/") or text.contains("builtraftextension/deck/") or text.begins_with("raftboardinggangplank/"): return "deck"
	if text.begins_with("raftbase/") or text.contains("postfoot") or text.contains("plankendgrain") or text.contains("deckseam"): return "dark_timber"
	for trim in ["raftbow/", "raftport/", "raftstarboard/", "raftsternport/", "raftsternstarboard/", "frontlintel", "rearlintel", "carvedlintel", "bedsidechest"]:
		if text.contains(trim): return "painted_timber"
	return "timber"

func _material(role: String) -> Material:
	if _materials.has(role): return _materials[role]
	if role in ["timber", "deck", "dark_timber", "painted_timber", "wall_panel"]:
		var timber := ShaderMaterial.new()
		timber.shader = TIMBER_SHADER
		timber.set_shader_parameter("timber_albedo", timber_texture())
		if role == "deck": timber.set_shader_parameter("deck_seams", 1.0)
		if role == "dark_timber":
			timber.set_shader_parameter("dark_tone", Vector3(.12,.08,.045))
			timber.set_shader_parameter("light_tone", Vector3(.30,.22,.135))
		if role == "painted_timber":
			timber.set_shader_parameter("dark_tone", Vector3(.08,.155,.14))
			timber.set_shader_parameter("light_tone", Vector3(.27,.39,.32))
		if role == "wall_panel":
			timber.set_shader_parameter("dark_tone", Vector3(.39,.40,.32))
			timber.set_shader_parameter("light_tone", Vector3(.58,.58,.47))
		_materials[role] = timber
		return timber
	if role in ["cloth", "linen"]:
		var fabric := ShaderMaterial.new()
		fabric.shader = CANVAS_SHADER
		fabric.set_shader_parameter("fabric_tone", Vector3(.40,.53,.46) if role == "cloth" else Vector3(.68,.60,.44))
		_materials[role] = fabric
		return fabric
	var material := StandardMaterial3D.new()
	material.roughness = .86
	material.metallic_specular = .26
	if role == "rope": material.albedo_color = Color("aa9069")
	elif role == "brass":
		material.albedo_color = Color("b59a68")
		material.metallic = .65
		material.roughness = .55
	elif role == "ceramic": material.albedo_color = Color("8aa9a2")
	elif role == "metal":
		material.albedo_color = Color("a9b9af")
		material.metallic = .7
		material.roughness = .46
	elif role == "equipment_dark": material.albedo_color = Color("304c50")
	elif role == "equipment_teal": material.albedo_color = Color("6d9388")
	material.vertex_color_use_as_albedo = true
	_materials[role] = material
	return material

func _remember(mesh: MeshInstance3D) -> void:
	var id := mesh.get_instance_id()
	if not _originals.has(id): _originals[id] = {"node": weakref(mesh), "material": mesh.material_override, "mesh": mesh.mesh}

func _paint(mesh: MeshInstance3D, material: Material) -> void:
	_remember(mesh)
	mesh.material_override = material
	if mesh.mesh is BoxMesh and _furniture_bevel_allowed(mesh):
		mesh.mesh = _beveled_box((mesh.mesh as BoxMesh).size)

func _furniture_bevel_allowed(mesh: MeshInstance3D) -> bool:
	if str(mesh.get_parent().name) in LOGIC_BOX_PARENTS: return false
	# Broad structural surfaces/roof coverage and resident gifts remain complete
	# authored meshes. Only isolated furniture and equipment housings get chamfers;
	# cutting every shared structural edge produced visible raster seams at noon.
	var parent := mesh.get_parent()
	while parent != null and parent.name != "ArkRoot":
		if parent.name in ["BuiltStorage", "BuiltWorkbench", "ModernWaterCorner"]: return true
		parent = parent.get_parent()
	return false

## Six inset faces, twelve chamfers and eight corners. Bounded by the original
## box, so existing conservative collision/support and layout remain untouched.
func _beveled_box(size: Vector3) -> ArrayMesh:
	var key := str(size)
	if _bevels.has(key): return _bevels[key]
	var h := size * .5
	var radius := minf(.035, minf(h.x, minf(h.y, h.z)) * .30)
	var inner := h - Vector3.ONE * radius
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in range(3):
		var a := (axis + 1) % 3
		var b := (axis + 2) % 3
		for sign_ in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = sign_
			var corners: Array[Vector3] = []
			for signs in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]:
				var p := Vector3.ZERO
				p[axis] = h[axis] * sign_
				p[a] = inner[a] * signs.x
				p[b] = inner[b] * signs.y
				corners.append(p)
			_quad(st, corners, normal)
	for c in range(3):
		var a := (c + 1) % 3
		var b := (c + 2) % 3
		for sa in [-1.0, 1.0]:
			for sb in [-1.0, 1.0]:
				var corners: Array[Vector3] = []
				for end_ in [-1.0, 1.0]:
					var p := Vector3.ZERO
					p[a] = h[a] * sa
					p[b] = inner[b] * sb
					p[c] = inner[c] * end_
					var q := p
					q[a] = inner[a] * sa
					q[b] = h[b] * sb
					if end_ < 0: corners.append_array([p,q])
					else: corners.append_array([q,p])
				var normal := Vector3.ZERO
				normal[a] = sa
				normal[b] = sb
				_quad(st, corners, normal.normalized())
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				var corner := Vector3(x,y,z)
				_triangle(st, Vector3(h.x*x,inner.y*y,inner.z*z), Vector3(inner.x*x,h.y*y,inner.z*z), Vector3(inner.x*x,inner.y*y,h.z*z), corner.normalized())
	var result := st.commit()
	_bevels[key] = result
	return result

func _quad(st: SurfaceTool, points: Array[Vector3], normal: Vector3) -> void:
	_triangle(st, points[0], points[1], points[2], normal)
	_triangle(st, points[0], points[2], points[3], normal)

func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	if (b-a).cross(c-a).dot(normal) > 0:
		var swap := b
		b = c
		c = swap
	for point in [a,b,c]:
		st.set_normal(normal)
		st.add_vertex(point)

func _new_decor(parent: Node3D) -> Node3D:
	var node := Node3D.new()
	node.name = "HomeArtCandidate"
	parent.add_child(node)
	_decor.append(weakref(node))
	return node

func _batch(parent: Node3D, name_: String, mesh: Mesh, role: String, pieces: Array) -> void:
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
	visual.material_override = _material(role)
	parent.add_child(visual)

func _deck_details(parent: Node3D) -> void:
	var trims: Array = []
	var brackets: Array = []
	for side in [-1.0, 1.0]:
		trims.append([Vector3(side * 2.95, .60, 0), Vector3(.19, .06, 4.25)])
		for z in [-1.72, 1.72]:
			brackets.append([Vector3(side * 2.95, .35, z), Vector3(.18, .40, .065)])
	_batch(parent, "CappedGunwales", BoxMesh.new(), "painted_timber", trims)
	_batch(parent, "HullStraps", BoxMesh.new(), "brass", brackets)
	var ring := TorusMesh.new()
	ring.inner_radius = .15
	ring.outer_radius = .185
	ring.rings = 24
	ring.ring_segments = 8
	_batch(parent, "MooringRopeCoil", ring, "rope", [[Vector3(-2.52, .15, 1.72), Vector3.ONE], [Vector3(-2.52, .165, 1.72), Vector3(.78, 1, .78)]])
	_helm_details(parent)

func _helm_details(parent: Node3D) -> void:
	var anchor := parent.get_parent().get_node_or_null("helmMarker") as Node3D
	if anchor == null: return
	var helm := Node3D.new()
	helm.name = "HandcraftedHelm"
	helm.transform = anchor.transform
	parent.add_child(helm)
	_batch(helm, "Pedestal", BoxMesh.new(), "painted_timber", [[Vector3(0,-.25,0),Vector3(.16,.60,.18)], [Vector3(0,-.50,0),Vector3(.44,.07,.34)]])
	var rim := TorusMesh.new()
	rim.inner_radius = .245
	rim.outer_radius = .295
	rim.rings = 32
	rim.ring_segments = 8
	var wheel := MeshInstance3D.new()
	wheel.name = "WheelRim"
	wheel.mesh = rim
	wheel.material_override = _material("timber")
	wheel.position = Vector3(0,.18,.06)
	wheel.rotation.x = PI*.5
	helm.add_child(wheel)
	for index in 6:
		var angle := index*TAU/6
		var spoke := MeshInstance3D.new()
		spoke.name = "Spoke%d" % index
		var mesh := CapsuleMesh.new()
		mesh.radius = .022
		mesh.height = .37
		mesh.radial_segments = 8
		mesh.rings = 2
		spoke.mesh = mesh
		spoke.material_override = _material("timber")
		spoke.position = Vector3(sin(angle)*.185,.18+cos(angle)*.185,.06)
		spoke.rotation.z = -angle
		helm.add_child(spoke)
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = .08
	hub_mesh.bottom_radius = .08
	hub_mesh.height = .12
	hub_mesh.radial_segments = 16
	hub.mesh = hub_mesh
	hub.material_override = _material("brass")
	hub.rotation.x = PI*.5
	hub.position = Vector3(0,.18,.06)
	helm.add_child(hub)

func _cabin_details(parent: Node3D) -> void:
	var woodwork: Array = [[Vector3(0, 1.37, -1.005), Vector3(.94, .055, .20)], [Vector3(0, 2.11, -1.01), Vector3(2.7, .10, .09)]]
	for x in [-1.27, 1.27]:
		woodwork.append([Vector3(x, 1.16, 1.05), Vector3(.11, 1.96, .12)])
	for index in range(8):
		woodwork.append([Vector3(-1.17 + index * .335, 1.18, -1.034), Vector3(.025, 1.70, .032)])
	_batch(parent, "JoineryAndShelf", BoxMesh.new(), "timber", woodwork)
	var fasteners: Array = []
	for x in [-1.27, 1.27]:
		for y in [.35, 1.90]: fasteners.append([Vector3(x, y, 1.119), Vector3(.14, .11, .018)])
	_batch(parent, "BrassCornerPlates", BoxMesh.new(), "brass", fasteners)
	var bottle := CylinderMesh.new()
	bottle.top_radius = .047
	bottle.bottom_radius = .061
	bottle.height = .20
	bottle.radial_segments = 12
	_batch(parent, "ShelfJars", bottle, "ceramic", [[Vector3(-.25, 1.50, -.98), Vector3.ONE], [Vector3(-.08, 1.485, -.98), Vector3(.8, .85, .8)]])
	_batch(parent, "FoldedTableLinen", BoxMesh.new(), "cloth", [[Vector3(.22, 1.415, -.98), Vector3(.25, .035, .15)]])

func _roof_details(parent: Node3D) -> void:
	var seams: Array = []
	for x in [-1.0, 0.0, 1.0]: seams.append([Vector3(x, .105, 0), Vector3(.025, .012, 2.14)])
	_batch(parent, "CanvasSeamBindings", BoxMesh.new(), "rope", seams)

func restore() -> void:
	room_view.restore()
	furniture.restore()
	vessel.restore()
	for entry in _marker_originals.values():
		var marker: Node = entry.node.get_ref()
		if is_instance_valid(marker): marker.visible = entry.visible
	_marker_originals.clear()
	for entry in _originals.values():
		var node = entry.node.get_ref()
		if is_instance_valid(node):
			node.material_override = entry.material
			node.mesh = entry.mesh
	for entry in _decor:
		var node = entry.get_ref()
		if is_instance_valid(node): node.free()
	_originals.clear()
	_decor.clear()
	_materials.clear()
	_bevels.clear()
	_timber = null
