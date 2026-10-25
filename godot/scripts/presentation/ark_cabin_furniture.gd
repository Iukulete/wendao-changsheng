extends RefCounted
## Reversible static furniture skins. Original logical boxes, use markers,
## collisions, capacity and all game-state owners remain untouched.
const BED := "res://art/cabin_furniture/bed_single_B.gltf"
const CABINET := "res://art/cabin_furniture/cabinet_small.gltf"
const BOOKS := "res://art/cabin_furniture/book_set.gltf"
const TINT := Color(.70,.76,.65,1)
var _hidden := {}
var _instances := {}
var _loaded := {}
var _materials := {}
var _active_hidden := {}
var _active_instances := {}

func apply(world: Node3D) -> void:
	_active_hidden.clear()
	_active_instances.clear()
	var ark := world.get_node_or_null("ArkRoot") as Node3D
	if ark == null:
		restore()
		return
	var deck := ark.get_node_or_null("HomeArtCandidate") as Node3D
	var shelter := ark.get_node_or_null("BuiltShelter") as Node3D
	if shelter != null:
		var cabin := shelter.get_node_or_null("HomeArtCandidate") as Node3D
		var cot := shelter.get_node_or_null("Cot") as Node3D
		if _ensure(cabin,"PlayerCotFurniture",cot,BED,AABB(Vector3(-.46,-.17,-.26),Vector3(.92,.68,.52)),-PI*.5):
			for id in ["Cot","Bedroll","QuiltFold"]: _hide_visual(shelter.get_node_or_null(id))
		_ensure(cabin,"CabinReadingBooks",shelter,BOOKS,AABB(Vector3(.13,1.435,-1.035),Vector3(.26,.19,.105)))
	var storage := ark.get_node_or_null("BuiltStorage") as Node3D
	if _ensure(deck,"PantryCabinetFurniture",storage,CABINET,AABB(Vector3(-.49,.02,-.43),Vector3(.98,.86,.86))):
		for id in ["Body","Lid","FrontHandle"]: _hide_visual(storage.get_node_or_null(id))
	var guest := ark.get_node_or_null("BuiltRaftExtension/GuestCabin") as Node3D
	if guest != null:
		var bed := guest.get_node_or_null("BedFrame") as Node3D
		if _ensure(deck,"GuestCotFurniture",bed,BED,AABB(Vector3(-.45,-.14,-.74),Vector3(.9,.68,1.48))):
			for id in ["BedFrame","Mattress","FoldedQuilt"]: _hide_visual(guest.get_node_or_null(id))
		var chest := guest.get_node_or_null("BedsideChest") as Node3D
		if _ensure(deck,"GuestCabinetFurniture",chest,CABINET,AABB(Vector3(-.21,-.26,-.22),Vector3(.42,.52,.44))):
			_hide_visual(chest)
	_cleanup()

func _source_visible(node: Node3D) -> bool:
	if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_inside_tree(): return false
	var parent := node.get_parent() as Node3D
	if parent != null and not parent.is_visible_in_tree(): return false
	var entry: Dictionary = _hidden.get(node.get_instance_id(),{})
	return bool(entry.visible) if not entry.is_empty() else node.visible

func _ensure(parent: Node3D,id: String,anchor: Node3D,asset: String,target: AABB,angle: float = 0) -> bool:
	if not is_instance_valid(parent) or not _source_visible(anchor): return false
	var holder: Node3D
	if _instances.has(id): holder = _instances[id].get_ref() as Node3D
	if is_instance_valid(holder) and holder.get_parent()!=parent:
		holder.free()
		holder = null
	if not is_instance_valid(holder):
		if parent.has_node(NodePath(id)): return false # Never adopt/free somebody else's decoration.
		if not _loaded.has(asset): _loaded[asset] = load(asset) as PackedScene
		var packed := _loaded[asset] as PackedScene
		if packed == null: return false # Keep the original working furniture visible.
		holder = Node3D.new()
		holder.name = id
		holder.set_meta("ark_cabin_visual",true)
		parent.add_child(holder)
		var fit := Node3D.new()
		fit.name = "FittedVisual"
		holder.add_child(fit)
		var turn := Node3D.new()
		turn.name = "AuthoredOrientation"
		turn.rotation.y = angle
		fit.add_child(turn)
		var model := packed.instantiate() as Node3D
		turn.add_child(model)
		var bounds := _bounds(fit)
		if bounds.size.x<=0 or bounds.size.y<=0 or bounds.size.z<=0:
			holder.free()
			return false
		fit.scale = target.size/bounds.size
		fit.position = target.position-bounds.position*fit.scale
		for mesh in model.find_children("*","MeshInstance3D",true,false): _style(mesh)
		if model is MeshInstance3D: _style(model)
		_instances[id] = weakref(holder)
	holder.transform = parent.global_transform.affine_inverse()*anchor.global_transform
	holder.visible = true
	_active_instances[id] = true
	return true

func _bounds(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var meshes := root.find_children("*","MeshInstance3D",true,false)
	if root is MeshInstance3D: meshes.push_front(root)
	for visual in meshes:
		var box: AABB = root.global_transform.affine_inverse()*visual.global_transform*visual.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

func _style(visual: MeshInstance3D) -> void:
	for surface in visual.mesh.get_surface_count():
		var original := visual.get_active_material(surface) as StandardMaterial3D
		if original == null: continue
		var id := original.get_instance_id()
		if not _materials.has(id):
			var material := original.duplicate() as StandardMaterial3D
			material.albedo_color = TINT
			material.roughness = .84
			material.metallic = 0
			material.metallic_specular = .22
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			_materials[id] = material
		visual.set_surface_override_material(surface,_materials[id])

func _hide_visual(node: Node) -> void:
	var visual := node as MeshInstance3D
	if visual == null and is_instance_valid(node) and node.get_child_count()>0:
		visual = node.get_child(0) as MeshInstance3D
	if visual == null: return
	var id := visual.get_instance_id()
	if not _hidden.has(id): _hidden[id] = {"node":weakref(visual),"visible":visual.visible}
	_active_hidden[id] = true
	visual.visible = false

func _cleanup() -> void:
	for id in _hidden.keys():
		var visual: Node = _hidden[id].node.get_ref()
		if not is_instance_valid(visual):
			_hidden.erase(id)
		elif not _active_hidden.has(id) or not visual.is_inside_tree():
			visual.visible = _hidden[id].visible
			_hidden.erase(id)
	for id in _instances.keys():
		var visual: Node = _instances[id].get_ref()
		if not is_instance_valid(visual):
			_instances.erase(id)
		elif not _active_instances.has(id) or not visual.is_inside_tree():
			visual.free()
			_instances.erase(id)

func restore() -> void:
	for entry in _hidden.values():
		var visual: Node = entry.node.get_ref()
		if is_instance_valid(visual): visual.visible = entry.visible
	for entry in _instances.values():
		var visual: Node = entry.get_ref()
		if is_instance_valid(visual): visual.free()
	_hidden.clear()
	_instances.clear()
	_loaded.clear()
	_materials.clear()
	_active_hidden.clear()
	_active_instances.clear()
