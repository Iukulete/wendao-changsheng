extends RefCounted
## Bounded, reversible FarReef presentation. No game state, physics, or input.
const GROUND_SHADER = preload("res://shaders/ark_far_reef_ground.gdshader")
const WOOD_SHADER = preload("res://shaders/ark_home_joinery.gdshader")
const SAND = preload("res://art/coast/sand_03/sand_03_diff_1k.jpg")
const ROCK = preload("res://art/coast/rock_boulder_dry/rock_boulder_dry_diff_1k.jpg")
const ROCK_NORMAL = preload("res://art/coast/rock_boulder_dry/rock_boulder_dry_nor_gl_1k.jpg")
const ROCK_ROUGH = preload("res://art/coast/rock_boulder_dry/rock_boulder_dry_rough_1k.jpg")
const TIMBER = preload("res://art/home_sample/home_timber_albedo_v1.png")
const ROOT_NAME := "FarReefArtCandidate"
var _originals: Dictionary = {}
var _decor: WeakRef
var _world: WeakRef
var _materials: Dictionary = {}

func owns_material(node: MeshInstance3D) -> bool:
	var row: Dictionary = _originals.get(node.get_instance_id(), {})
	return not row.is_empty() and row.node.get_ref() == node and node.material_override == row.replacement

func restore() -> void:
	# Nodes may disappear; original Materials must remain strongly held until here.
	for row in _originals.values():
		var node: MeshInstance3D = row.node.get_ref() as MeshInstance3D
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.material_override = row.material
	_originals.clear()
	var decor: Node = _decor.get_ref() if _decor != null else null
	if is_instance_valid(decor): decor.free()
	_decor = null
	_world = null
	_materials.clear()

func _still_applied(world: Node3D) -> bool:
	if _world == null or _world.get_ref() != world or _originals.size() != 7: return false
	var decor: Node = _decor.get_ref() if _decor != null else null
	if not is_instance_valid(decor) or decor.get_parent() != world.get_node_or_null("KeelWreck"): return false
	for row in _originals.values():
		var node: MeshInstance3D = row.node.get_ref() as MeshInstance3D
		if not is_instance_valid(node) or not node.is_inside_tree() or not owns_material(node): return false
	return true

func _rock_mesh(world: Node3D, id: String, size: Vector3) -> MeshInstance3D:
	var parent := world.get_node_or_null(id) as StaticBody3D
	if parent == null: return null
	var found: MeshInstance3D
	for child in parent.get_children():
		if child is MeshInstance3D:
			if found != null: return null
			found = child as MeshInstance3D
	if found == null or not found.mesh is ArrayMesh or not found.mesh.get_aabb().size.is_equal_approx(size) or found.transform != Transform3D.IDENTITY: return null
	# World construction owns both geometry and collision, regardless of presentation mode.
	if str(found.name) != "RockVisual" or parent.get_meta("far_reef_world_shape", "") != id: return null
	return found

func _rib_meshes(wreck: Node3D) -> Array[MeshInstance3D]:
	var ribs: Array[MeshInstance3D] = []
	if wreck == null: return ribs
	for index in range(3):
		var found: MeshInstance3D
		var size := Vector3(0.18, 1.2 + 0.2 * float(index % 2), 3.2)
		var position := Vector3(-1.1 + float(index) * 1.1, 0.52, 0)
		var basis := Basis.from_euler(Vector3(0.0, 0.12 * float(index), -0.18 + 0.08 * float(index)))
		for child in wreck.get_children():
			if not child is MeshInstance3D or str(child.name) == "SalvageBeam": continue
			var mesh := child as MeshInstance3D
			if mesh.mesh is BoxMesh and (mesh.mesh as BoxMesh).size == size and mesh.position == position and mesh.basis.is_equal_approx(basis):
				if found != null: return []
				found = mesh
		if found == null: return []
		ribs.append(found)
	return ribs

func _paint(node: MeshInstance3D, material: Material) -> void:
	_originals[node.get_instance_id()] = {"node": weakref(node), "material": node.material_override, "replacement": material}
	node.material_override = material

func _ground() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("sand_map", SAND)
	material.set_shader_parameter("rock_map", ROCK)
	material.set_shader_parameter("sample_offset", Vector3.ZERO)
	material.set_shader_parameter("use_outcrop_mask", false)
	return material

func _rock(offset: Vector3) -> ShaderMaterial:
	var material := _ground()
	material.set_shader_parameter("sample_offset", offset)
	material.set_shader_parameter("use_outcrop_mask", true)
	return material

func _wood() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WOOD_SHADER
	material.set_shader_parameter("timber_albedo", TIMBER)
	material.set_shader_parameter("dark_tone", Vector3(0.17, 0.16, 0.13))
	material.set_shader_parameter("light_tone", Vector3(0.47, 0.39, 0.27))
	material.set_shader_parameter("deck_seams", 0.0)
	return material

func _plank(parent: Node3D, id: String, size: Vector3, position: Vector3, material: Material) -> void:
	var plank := MeshInstance3D.new()
	plank.name = id
	var mesh := BoxMesh.new()
	mesh.size = size
	plank.mesh = mesh
	plank.position = position
	plank.material_override = material
	parent.add_child(plank)

func apply(world: Node3D) -> void:
	if world == null or OS.get_environment("ARK_FAR_REEF_ART") == "0":
		restore()
		return
	if _still_applied(world): return
	restore()
	var grass := world.get_node_or_null("FarReefLandmass/Grassland") as MeshInstance3D
	var shore := world.get_node_or_null("FarReefLandmass/Shoreline") as MeshInstance3D
	var rock_a := _rock_mesh(world, "FarReefRockA", Vector3(2.47, .73, 2.4))
	var rock_b := _rock_mesh(world, "FarReefRockB", Vector3(3.2, .67, 2.4))
	var wreck := world.get_node_or_null("KeelWreck") as Node3D
	var ribs: Array[MeshInstance3D] = _rib_meshes(wreck)
	if grass == null or shore == null or rock_a == null or rock_b == null or ribs.size() != 3:
		push_error("FarReefArt: exact original visual targets missing")
		return
	var targets: Array[MeshInstance3D] = [grass, shore, rock_a, rock_b]
	targets.append_array(ribs)
	for node in targets:
		if not node.material_override is StandardMaterial3D:
			push_error("FarReefArt: original target material is not standard")
			return
	if wreck.has_node(ROOT_NAME):
		push_error("FarReefArt: unowned candidate root already exists")
		return
	_world = weakref(world)
	_materials = {"grass": _ground(), "shore": _ground(), "rock_a": _rock(Vector3(-5, .95, 1)), "rock_b": _rock(Vector3(5, .8, -3)), "wood": _wood()}
	_paint(grass, _materials.grass)
	_paint(shore, _materials.shore)
	_paint(rock_a, _materials.rock_a)
	_paint(rock_b, _materials.rock_b)
	for rib in ribs: _paint(rib, _materials.wood)
	var decor := Node3D.new()
	decor.name = ROOT_NAME
	wreck.add_child(decor)
	_decor = weakref(decor)
	_plank(decor, "RearCrossPlank", Vector3(2.55, 0.18, 0.30), Vector3(0.06, 0.30, -1.10), _materials.wood)
	_plank(decor, "ForeBrokenPlankLeft", Vector3(1.65, 0.18, 0.28), Vector3(-0.45, 0.30, 1.36), _materials.wood)
	_plank(decor, "ForeBrokenPlankRight", Vector3(1.04, 0.18, 0.28), Vector3(0.95, 0.30, 1.36), _materials.wood)
