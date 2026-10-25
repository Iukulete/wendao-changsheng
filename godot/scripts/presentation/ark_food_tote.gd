extends RefCounted
## Reversible belt basket. It does not alter original limbs or own any supplies.
var root: Node3D
var owner: WeakRef
var soup := false

func clear() -> void:
	if is_instance_valid(root): root.free()
	root = null
	owner = null
	soup = false

func present(game: Node3D) -> void:
	var body: Node3D = game.traveler_body
	if not game.kitchen.carrying() or not is_instance_valid(body):
		clear()
		return
	if is_instance_valid(root) and owner!=null and owner.get_ref()==body and soup==game.kitchen.carrying_stew(): return
	clear()
	soup = game.kitchen.carrying_stew()
	root = Node3D.new()
	root.name = "HouseholdFoodTote"
	root.position = Vector3(.32,.50,.19)
	body.add_child(root)
	owner = weakref(body)
	var basket := MeshInstance3D.new()
	basket.name = "WovenBasket"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = .115
	cylinder.bottom_radius = .085
	cylinder.height = .18
	cylinder.radial_segments = 12
	basket.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("a98b61")
	material.roughness = .96
	basket.material_override = material
	root.add_child(basket)
	var handle := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = .095
	ring.outer_radius = .108
	ring.rings = 16
	ring.ring_segments = 6
	handle.mesh = ring
	handle.position.y = .10
	handle.rotation.z = PI/2
	handle.material_override = material
	root.add_child(handle)
	var shell := MeshInstance3D.new()
	shell.name = "CoveredSoupBowl" if soup else "FreshShell"
	var sphere := SphereMesh.new()
	sphere.radius = .065 if soup else .042
	sphere.height = .052 if soup else .045
	sphere.radial_segments = 12
	sphere.rings = 6
	shell.mesh = sphere
	shell.position.y = .095
	var pearl := StandardMaterial3D.new()
	pearl.albedo_color = Color("bd774d") if soup else Color("c9d5ca")
	pearl.roughness = .78
	shell.material_override = pearl
	root.add_child(shell)
