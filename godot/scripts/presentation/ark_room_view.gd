extends RefCounted
## Camera-only cutaway. Never change physical walls, damage, routes or saves.
const PRIMARY := ["Back", "Left", "Right", "Roof/CenterFace", "Roof/RoofRidgeBinding", "Roof/RoofCanvasPatch", "Roof/RoofCanvasPatchSeam", "Roof/EaveFront", "Roof/EaveBack", "Roof/EaveLeft", "Roof/EaveRight", "CabinFrameDetails/EntranceCanvas", "CabinFrameDetails/CanvasEdgeBinding", "CabinFrameDetails/CanvasPatch", "CabinFrameDetails/FrontLintel", "CabinFrameDetails/RearLintel"]
const GUEST := ["BackWall", "PortWall", "StarboardWall", "CanvasAwning", "AwningBinding", "CarvedLintel", "PrivacyCurtain"]
const WALLS := ["Back", "Left", "Right", "BackWall", "PortWall", "StarboardWall"]
var _hidden := {}
var _caps := {}
var _rooms := {}
var _wanted := {}
var _guest_open := false
var _wall_material: Material
var _trim_material: Material

func update(world: Node3D, wall_material: Material, trim_material: Material) -> void:
	_wall_material = wall_material
	_trim_material = trim_material
	_wanted.clear()
	var player := world.get("player") as CharacterBody3D
	var camera := world.get("camera") as Camera3D
	var shelter := world.get_node_or_null("ArkRoot/BuiltShelter") as Node3D
	var guest := world.get_node_or_null("ArkRoot/BuiltRaftExtension/GuestCabin") as Node3D
	var roof := shelter.get_node_or_null("Roof") as Node3D if is_instance_valid(shelter) else null
	var active := is_instance_valid(player) and not bool(world.get("is_swimming"))
	var primary_open := active and is_instance_valid(roof) and shelter.is_visible_in_tree() and bool(roof.get_meta("cutaway_active", false))
	var inside := false
	if active and is_instance_valid(guest) and guest.is_visible_in_tree():
		var point := guest.to_local(player.global_position)
		var deck: Vector3 = world.get_node("ArkRoot").to_local(player.global_position)
		var margin := .12 if _guest_open else 0.0
		inside = absf(point.x) <= 1.05 + margin and point.z >= -1.12 - margin and point.z <= 1.30 + margin and point.y >= -.25 and point.y <= (1.85 if _guest_open else .85)
		inside = inside and bool(world.call("_ark_local_walk_position_supported", Vector2(deck.x, deck.z), 0.0 if _guest_open else .38))
	_guest_open = inside
	var targets := []
	if primary_open:
		targets = [player.global_position + Vector3.UP * .9, shelter.to_global(Vector3(.65,.7,.2)), shelter.to_global(Vector3(-.55,.5,.4))]
	if inside:
		targets = [player.global_position + Vector3.UP * .9, guest.to_global(Vector3(.45,.65,-.34)), guest.to_global(Vector3(-.76,.6,-.72))]
		# No separate central face on this awning. Also works during fresh load.
		_request(_visual(guest.get_node_or_null("CanvasAwning")))
	if not targets.is_empty():
		# A foreground cabin must not cover an occupied neighbouring cabin either.
		if is_instance_valid(shelter) and shelter.is_visible_in_tree(): _observe(shelter, PRIMARY, camera, targets)
		if is_instance_valid(guest) and guest.is_visible_in_tree(): _observe(guest, GUEST, camera, targets)
	_reconcile()
	for id in _rooms.keys():
		var node: Node = _rooms[id].node.get_ref()
		if not is_instance_valid(node) or not node.is_inside_tree(): _rooms.erase(id)

func _observe(room: Node3D, paths: Array, camera: Camera3D, targets: Array) -> void:
	if not is_instance_valid(camera) or not camera.is_inside_tree(): return
	var id := room.get_instance_id()
	if not _rooms.has(id):
		var parts: Array = []
		for path in paths:
			var visual := _visual(room.get_node_or_null(path))
			if visual != null: parts.append({"node":weakref(visual), "wall": str(path) in WALLS})
		_rooms[id] = {"node":weakref(room), "parts":parts}
	for part in _rooms[id].parts:
		var visual: MeshInstance3D = part.node.get_ref()
		if not _eligible(visual): continue
		for target in targets:
			if _occludes(visual, camera, target):
				_request(visual)
				if part.wall: _cap(visual)
				break

func _visual(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	if is_instance_valid(node) and node.get_child_count() > 0: return node.get_child(0) as MeshInstance3D
	return null

func _eligible(visual: MeshInstance3D) -> bool:
	if not is_instance_valid(visual) or not visual.is_inside_tree() or visual.mesh == null: return false
	var parent := visual.get_parent() as Node3D
	if parent != null and not parent.is_visible_in_tree(): return false
	var entry: Dictionary = _hidden.get(visual.get_instance_id(), {})
	return _baseline(entry) if not entry.is_empty() else visual.visible

func _baseline(entry: Dictionary) -> bool:
	# Legacy central faces are reset by the core cutaway before every update.
	# Resolve their CURRENT baseline, never restore a stale captured open/closed bit.
	var roof: Node = entry.owner.get_ref() if entry.has("owner") else null
	return not bool(roof.get_meta("cutaway_active", false)) if is_instance_valid(roof) else bool(entry.visible)

func _occludes(visual: MeshInstance3D, camera: Camera3D, target: Vector3) -> bool:
	if camera.is_position_behind(target): return false
	var screen := camera.unproject_position(target)
	if not camera.get_viewport().get_visible_rect().grow(2).has_point(screen): return false
	# Correct per-pixel origin for both perspective and orthogonal cameras.
	var inverse := visual.global_transform.affine_inverse()
	var start := inverse * camera.project_ray_origin(screen)
	var finish := inverse * target
	var box := visual.get_aabb().grow(.045)
	var direction := finish - start
	var near := 0.0
	var far := 0.985 # Do not remove a wall behind the target.
	for axis in 3:
		if absf(direction[axis]) < .000001:
			if start[axis] < box.position[axis] or start[axis] > box.end[axis]: return false
		else:
			var a := (box.position[axis] - start[axis]) / direction[axis]
			var b := (box.end[axis] - start[axis]) / direction[axis]
			near = maxf(near, minf(a,b))
			far = minf(far, maxf(a,b))
			if near > far: return false
	return near <= far

func _request(visual: MeshInstance3D) -> void:
	if not _eligible(visual): return
	var id := visual.get_instance_id()
	_wanted[id] = true
	if not _hidden.has(id): _hidden[id] = {"node":weakref(visual), "visible":visual.visible}
	if visual.get_parent().name == "Roof" and visual.name in ["CenterFace", "RoofRidgeBinding", "RoofCanvasPatch", "RoofCanvasPatchSeam"]:
		_hidden[id].owner = weakref(visual.get_parent())
	visual.visible = false

func _cap(visual: MeshInstance3D) -> void:
	var id := visual.get_instance_id()
	var cap: Node3D = _caps[id].node.get_ref() if _caps.has(id) else null
	if not is_instance_valid(cap):
		cap = Node3D.new()
		cap.name = "HomeArtCandidate"
		cap.set_meta("ark_room_skirting", true)
		visual.get_parent().add_child(cap)
		cap.transform = visual.transform
		var box := visual.get_aabb()
		var height := minf(.40, box.size.y)
		var panel := MeshInstance3D.new()
		panel.name = "LowWall"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(box.size.x, height, box.size.z)
		panel.mesh = mesh
		panel.position = box.position + Vector3(box.size.x*.5, height*.5, box.size.z*.5)
		panel.material_override = _wall_material
		cap.add_child(panel)
		var trim := MeshInstance3D.new()
		trim.name = "SectionBinding"
		var edge := BoxMesh.new()
		edge.size = Vector3(box.size.x+.018, .025, box.size.z+.018)
		trim.mesh = edge
		trim.position = panel.position + Vector3.UP*(height*.5)
		trim.material_override = _trim_material
		cap.add_child(trim)
		_caps[id] = {"node":weakref(cap), "source":weakref(visual)}
	cap.visible = true

func _reconcile() -> void:
	for id in _hidden.keys():
		var node: Node = _hidden[id].node.get_ref()
		if not is_instance_valid(node): _hidden.erase(id)
		elif not _wanted.has(id) or not node.is_inside_tree():
			node.visible = _baseline(_hidden[id])
			_hidden.erase(id)
	for id in _caps.keys():
		var source: Node = _caps[id].source.get_ref()
		var cap: Node3D = _caps[id].node.get_ref()
		if not is_instance_valid(source) or not source.is_inside_tree() or not is_instance_valid(cap):
			if is_instance_valid(cap): cap.free()
			_caps.erase(id)
		else: cap.visible = _wanted.has(id)

func restore() -> void:
	for entry in _hidden.values():
		var node: Node = entry.node.get_ref()
		if is_instance_valid(node): node.visible = _baseline(entry)
	for entry in _caps.values():
		var node: Node = entry.node.get_ref()
		if is_instance_valid(node): node.free()
	_hidden.clear()
	_caps.clear()
	_rooms.clear()
	_wanted.clear()
	_guest_open = false
	_wall_material = null
	_trim_material = null
