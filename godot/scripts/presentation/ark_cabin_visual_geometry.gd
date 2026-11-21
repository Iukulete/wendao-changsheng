extends RefCounted
## Stateless furniture geometry. Callers own holder placement, visibility,
## materials and lifetime. This helper never enters world-owner caches.

const NODE_TYPES := ["Node3D", "MeshInstance3D"]
const INT_PROPERTIES := ["layers", "cast_shadow", "gi_mode", "rotation_order", "rotation_edit_mode", "visibility_range_fade_mode"]
const FLOAT_PROPERTIES := ["extra_cull_margin", "lod_bias", "sorting_offset", "transparency", "visibility_range_begin", "visibility_range_end", "visibility_range_begin_margin", "visibility_range_end_margin"]
const BOOL_PROPERTIES := ["visible", "sorting_use_aabb_center", "ignore_occlusion_culling"]

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "fit": null, "model": null, "error": message}

static func _finite_transform(value: Transform3D) -> bool:
	return value.origin.is_finite() and value.basis.x.is_finite() and value.basis.y.is_finite() and value.basis.z.is_finite()

static func _plain_resource(value: Resource) -> bool:
	return value == null or value.get_script() == null

## Inspect the packed node definitions BEFORE instantiate: no scripts, inherited
## or nested scene instances, active nodes, skins, or unknown stored properties.
## Asset failure is independent; callers retain the corresponding original skin.
static func scene_error(packed: PackedScene) -> String:
	if packed == null: return "missing PackedScene"
	if packed.get_script() != null: return "scripted PackedScene"
	var state: SceneState = packed.get_state()
	if state == null or state.get_node_count() == 0: return "empty PackedScene"
	if state.get_connection_count() != 0: return "PackedScene has signal connections"
	for index in range(state.get_node_count()):
		var type_name: String = str(state.get_node_type(index))
		var location: String = str(state.get_node_path(index))
		if not state.get_node_groups(index).is_empty(): return "node groups at %s" % location
		if type_name not in NODE_TYPES: return "unsupported node type %s at %s" % [type_name, location]
		if state.get_node_instance(index) != null or not state.get_node_instance_placeholder(index).is_empty():
			return "nested or inherited scene at %s" % location
		for property_index in range(state.get_node_property_count(index)):
			var key: String = str(state.get_node_property_name(index, property_index))
			var value: Variant = state.get_node_property_value(index, property_index)
			if key == "script":
				if value != null: return "script at %s" % location
			elif key == "transform":
				if not value is Transform3D or not _finite_transform(value): return "invalid transform at %s" % location
			elif key == "top_level":
				if not value is bool or value: return "top-level transform at %s" % location
			elif key == "mesh":
				if type_name != "MeshInstance3D" or not value is Mesh or not _plain_resource(value): return "invalid mesh at %s" % location
			elif key in ["material_override", "material_overlay"]:
				if type_name != "MeshInstance3D" or (value != null and not value is Material) or not _plain_resource(value):
					return "invalid material at %s" % location
			elif key == "skin":
				if value != null: return "skinned geometry at %s" % location
			elif key == "skeleton":
				if not value is NodePath or str(value) not in ["", ".."]: return "external skeleton at %s" % location
			elif key == "visibility_parent":
				if not value is NodePath or not str(value).is_empty(): return "external visibility parent at %s" % location
			elif key == "editor_description":
				if not value is String: return "invalid editor description at %s" % location
			elif key in INT_PROPERTIES:
				if not value is int: return "invalid integer property %s at %s" % [key, location]
			elif key in FLOAT_PROPERTIES:
				if not value is float or not is_finite(value): return "invalid scalar property %s at %s" % [key, location]
			elif key in BOOL_PROPERTIES:
				if not value is bool: return "invalid boolean property %s at %s" % [key, location]
			else:
				return "unsupported property %s at %s" % [key, location]
	return ""

## The caller must supply a fresh holder. Attached callers retain the original
## global inverse * global bounds expression below, without changing its order.
## Detached callers MUST supply the holder's intended global Transform3D; there
## is no invented identity/world transform fallback. The explicit-frame result
## still needs the same-version attached/detached differential acceptance gate.
static func populate_fitted(holder: Node3D, packed: PackedScene, target: AABB, angle: float = 0.0, detached_holder_frame: Variant = null) -> Dictionary:
	if not is_instance_valid(holder) or holder.is_queued_for_deletion(): return _failure("invalid holder")
	if holder.get_child_count() != 0: return _failure("holder is not empty")
	if not target.position.is_finite() or not target.size.is_finite() or not target.has_volume() or not is_finite(angle):
		return _failure("invalid fit target or angle")
	var attached: bool = holder.is_inside_tree()
	if attached:
		if detached_holder_frame != null: return _failure("detached frame supplied for attached holder")
		if not _finite_transform(holder.global_transform) or holder.global_transform.basis.determinant() == 0.0:
			return _failure("invalid attached holder frame")
	else:
		if not detached_holder_frame is Transform3D: return _failure("detached holder requires explicit global frame")
		if not _finite_transform(detached_holder_frame) or detached_holder_frame.basis.determinant() == 0.0:
			return _failure("invalid detached holder frame")
	var error: String = scene_error(packed)
	if not error.is_empty(): return _failure(error)
	var fit := Node3D.new()
	fit.name = "FittedVisual"
	holder.add_child(fit)
	var turn := Node3D.new()
	turn.name = "AuthoredOrientation"
	turn.rotation.y = angle
	fit.add_child(turn)
	var model := packed.instantiate() as Node3D
	if model == null:
		fit.free()
		return _failure("PackedScene did not instantiate Node3D")
	turn.add_child(model)
	var bounds: AABB = bounds_in_tree(fit) if attached else bounds_with_frame(fit, holder, detached_holder_frame)
	if bounds.size.x<=0 or bounds.size.y<=0 or bounds.size.z<=0:
		fit.free()
		return _failure("empty fitted bounds")
	if not bounds.position.is_finite() or not bounds.size.is_finite():
		fit.free()
		return _failure("non-finite fitted bounds")
	fit.scale = target.size/bounds.size
	fit.position = target.position-bounds.position*fit.scale
	return {"ok": true, "fit": fit, "model": model, "error": ""}

## This body intentionally preserves the original furniture _bounds algorithm.
static func bounds_in_tree(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var meshes := root.find_children("*","MeshInstance3D",true,false)
	if root is MeshInstance3D: meshes.push_front(root)
	for visual in meshes:
		var box: AABB = root.global_transform.affine_inverse()*visual.global_transform*visual.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

## Internal geometry contains only safe Node3D descendants. Reproduce each
## ancestor multiplication from the explicit holder frame, then use the same
## inverse/multiply/AABB order as the attached expression, not a local shortcut.
static func _virtual_global(node: Node3D, holder: Node3D, holder_frame: Transform3D) -> Transform3D:
	var chain: Array[Node3D] = []
	var cursor: Node3D = node
	while cursor != holder:
		chain.push_front(cursor)
		cursor = cursor.get_parent() as Node3D
	var result: Transform3D = holder_frame
	for part in chain: result = result * part.transform
	return result

static func bounds_with_frame(root: Node3D, holder: Node3D, holder_frame: Transform3D) -> AABB:
	var result := AABB()
	var first := true
	var root_global: Transform3D = _virtual_global(root, holder, holder_frame)
	var meshes := root.find_children("*","MeshInstance3D",true,false)
	if root is MeshInstance3D: meshes.push_front(root)
	for visual in meshes:
		var visual_global: Transform3D = _virtual_global(visual, holder, holder_frame)
		var box: AABB = root_global.affine_inverse()*visual_global*visual.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result
