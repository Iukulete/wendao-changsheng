extends SceneTree

const Scene = preload("res://scenes/ark_greybox.tscn")
const Save = preload("res://scripts/ark_greybox_save.gd")
var game: Node3D
var coast: RefCounted

func _initialize() -> void:
	_run.call_deferred()

func _uncached(actor: Dictionary) -> Dictionary:
	var target := actor.node.get_ref() as Node3D
	var gap := INF
	var support := -INF
	# Repeat identical probes to independently exercise the old face-list result.
	for point in actor.feet:
		for duplicate in range(7):
			var world: Vector3 = target.to_global(point)
			var height: Variant = coast.sample_height(world)
			if height != null:
				gap = minf(gap, world.y - float(height))
				support = maxf(support, float(height))
	var mean_height: float = game.water.mean_height
	var weight := smoothstep(mean_height, mean_height + coast.ACTOR_SHORE_BLEND_HEIGHT, support) if is_finite(support) else 0.0
	return {"gap": gap, "support_height": support, "offset": (-gap - .012) * weight if is_finite(gap) else 0.0}

func _exact_results() -> void:
	for actor in coast.actor_contacts:
		var target := actor.node.get_ref() as Node3D
		if target.get_parent() != game: continue
		var expected := _uncached(actor)
		assert(actor.gap == expected.gap and actor.support_height == expected.support_height)
		var pivot := target.get_node(coast.VISUAL_PIVOT) as Node3D
		# Node3D stores Vector3 components at the engine's real_t precision.
		assert(pivot.position.y == Vector3(0, expected.offset, 0).y, "cache must preserve the old exact support reduction")

func _refresh_changed(label: String) -> void:
	var before: int = coast.actor_support_sample_count
	coast.refresh_moving_actors()
	assert(coast.actor_support_sample_count > before, label + " must invalidate cached terrain support")
	_exact_results()
	before = coast.actor_support_sample_count
	coast.refresh_moving_actors()
	assert(coast.actor_support_sample_count == before, label + " must settle to zero new queries")

func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_contact_cache_%d" % OS.get_process_id()).simplify_path()
	var service = Save.new(save_root)
	service.clear_for_test()
	game = Scene.instantiate()
	game.save_root_override = save_root
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	coast = game.opening_coast
	assert(coast.initialized and coast.actor_contacts.size() == 2)
	# Check exact deduplication against a new neutral-pose mesh, not an already
	# grounded/animated production body. The original repeated order is retained.
	var fixture := Node3D.new()
	fixture.name = "CacheNeutralFixture"
	game.add_child(fixture)
	var mesh := MeshInstance3D.new()
	mesh.mesh = CapsuleMesh.new()
	fixture.add_child(mesh)
	var raw: PackedVector3Array = mesh.mesh.get_faces()
	var low := INF
	for p in raw: low = minf(low, p.y)
	var expected := PackedVector3Array()
	var seen: Dictionary = {}
	var repeated := 0
	for p in raw:
		if p.y <= low + .035:
			repeated += 1
			if not seen.has(p):
				seen[p] = true
				expected.append(p)
	coast._cache_actor_contact(fixture)
	assert(coast.actor_contacts.back().feet == expected and repeated > expected.size())
	coast.actor_contacts.pop_back()
	fixture.free()
	for actor in coast.actor_contacts: actor.support_valid = false
	_refresh_changed("first refresh")
	var actor: Dictionary = coast.actor_contacts[0]
	var target := actor.node.get_ref() as Node3D
	var original: Transform3D = target.global_transform
	target.position.x += .03
	_refresh_changed("root position")
	target.rotation.y += .07
	_refresh_changed("root rotation")
	target.scale *= 1.01
	_refresh_changed("root scale")
	target.global_transform = original
	_refresh_changed("root restoration")
	var old_mean: float = game.water.mean_height
	game.water.mean_height += .01
	_refresh_changed("mean water")
	game.water.mean_height = old_mean
	_refresh_changed("mean water restoration")
	var old_terrain: Transform3D = coast.island.global_transform
	coast.island.position.y += .01
	_refresh_changed("terrain transform")
	coast.island.global_transform = old_terrain
	_refresh_changed("terrain restoration")
	var cells: Dictionary = coast.ground_grid.duplicate(true)
	coast._build_height_index()
	assert(coast.ground_grid == cells, "rebuilding the index must not append duplicate triangles")
	_refresh_changed("height revision")
	var before: int = coast.actor_support_sample_count
	var pivot := target.get_node(coast.VISUAL_PIVOT) as Node3D
	var offset := pivot.position.y
	coast.reset_shore_offset(target)
	assert(pivot.position.y == 0.0)
	coast.refresh_moving_actors()
	assert(coast.actor_support_sample_count == before and pivot.position.y == offset)
	var sign := target.get_node("Name") as Label3D
	assert(sign.position == coast.label_bases[sign.get_instance_id()].position + Vector3.UP * offset)
	var body := pivot.get_child(0) as Node3D
	var old_body_y := body.position.y
	body.position.y += .123
	coast.refresh_moving_actors()
	assert(coast.actor_support_sample_count == before and pivot.position.y == offset)
	assert(body.position.y == Vector3(0, old_body_y + .123, 0).y, "neutral support must not cancel animated body bob")
	body.position.y = old_body_y
	target.reparent(game.ark_root)
	coast.refresh_moving_actors()
	assert(not actor.support_valid and pivot.position.y == 0.0)
	target.reparent(game)
	target.global_transform = original
	_refresh_changed("return from aboard")
	print("ARK_COAST_CONTACT_CACHE_TEST_OK: exact ordered dedup; static zero-query reuse; root/water/terrain/revision invalidation; index rebuild; visual/label reset; child bob; reparent; unchanged uncached support")
	game.save_service = null
	game.free()
	service.clear_for_test()
	quit(0)
