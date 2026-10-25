extends "res://tests/ark_cabin_furniture_test.gd"
## Reuse finite collection and paid builds; compare presentation to actual stage.
func _capture(stage: String) -> void:
	if stage == "01_paid_starter_home":
		var node := game.get_node("ArkRoot/HomeArtCandidate/VesselSilhouette")
		assert(node.get_meta("vessel_stage")=="lashed_timbers")
		var logs := node.get_node("BuoyancyTimbers") as MultiMeshInstance3D
		assert(logs.multimesh.instance_count==3)
		assert(logs.position.y-(logs.multimesh.mesh as CylinderMesh).bottom_radius<game.water.mean_height,"buoyancy logs meet the actual analytic waterline, not an assumed y=0 ocean")
		assert(not node.has_node("ShapedHull"),"no unearned keel hull at the beginning")
		_assert_reversible()
	elif stage == "04_paid_guest_cabin":
		var node := game.get_node("ArkRoot/HomeArtCandidate/VesselSilhouette")
		assert(node.get_meta("vessel_stage")=="shallow_keel" and node.has_node("ShapedHull"))
		var mesh: Mesh = node.get_node("ShapedHull").mesh
		assert(mesh.get_faces().size()==144 and mesh.get_aabb().size.z>8)
		assert(mesh.get_aabb().position.y<game.water.mean_height)
		var faces := mesh.get_faces()
		for x in [-.4,0.0,.4]:
			for y in [.14,.4,.7]:
				for triangle in range(0,faces.size(),3):
					assert(Geometry3D.segment_intersects_triangle(Vector3(x,y,3.0),Vector3(x,y,1.3),faces[triangle],faces[triangle+1],faces[triangle+2])==null,"actual visible hull preserves the stern boarding opening")
		_assert_reversible()
		var saved: Dictionary = game._build_save_state()
		var wood: int = game.wood
		var keel: int = game.keel_beams
		var frames: int = game.guest_cabin_frames
		assert(game._dismantle_raft_extension())
		assert(game.wood==wood+7 and game.keel_beams==keel+1 and game.guest_cabin_frames==frames+1,"real demolition refunds the actual earned construction inputs")
		assert(game.get_node("ArkRoot/HomeArtCandidate/VesselSilhouette").get_meta("vessel_stage")=="lashed_timbers")
		assert(game.save_service.save_state(saved).ok)
		game._load_progress()
		assert(game.MemoryScript.facts_equal(_disk_view(saved),_disk_view(game._build_save_state())))
		assert(game.get_node("ArkRoot/HomeArtCandidate/VesselSilhouette").get_meta("vessel_stage")=="shallow_keel")
		print("ARK_VESSEL_SKIN_TEST_OK: buoyant starter timbers, earned shaped hull, open stern, full-size rail caps, real demolition/reload, unchanged support/stock/history and reversible helm")

func _assert_reversible() -> void:
	var sample = game.home_art_sample
	var state: Dictionary = game._build_save_state()
	var collisions := _collisions()
	var lights := _lights()
	var visual: MeshInstance3D = game.get_node("ArkRoot/RaftBase").get_child(0)
	var geometry := visual.mesh
	var helm: MeshInstance3D = game.get_node("ArkRoot/helmMarker").get_child(0)
	assert(not visual.visible and not helm.visible and geometry is BoxMesh)
	var root := game.get_node("ArkRoot/HomeArtCandidate")
	assert(root.get_node("HandcraftedHelm").get_node("WheelRim").mesh is TorusMesh)
	assert(root.find_children("*","CollisionObject3D",true,false).is_empty())
	var id: int = root.get_node("VesselSilhouette").get_instance_id()
	for repeat in 100: sample.apply(game)
	assert(root.get_node("VesselSilhouette").get_instance_id()==id,"reapplication does not rebuild the hull")
	var caps: MultiMesh = root.get_node("CappedGunwales").multimesh
	var rail: MeshInstance3D = game.get_node("ArkRoot/RaftPort").get_child(0)
	if DisplayServer.get_name() != "headless":
		assert(is_equal_approx(caps.get_instance_transform(0).basis.z.length(),rail.mesh.size.z-.05))
	else: print("VESSEL_CAP_READBACK_SKIP: dummy renderer does not retain MultiMesh transforms; requires the separate GL capture")
	_key(KEY_F7)
	assert(visual.visible and helm.visible and visual.mesh==geometry)
	assert(not game.has_node("ArkRoot/HomeArtCandidate"))
	_key(KEY_F7)
	assert(not visual.visible and not helm.visible)
	assert(collisions==_collisions() and lights==_lights() and game.MemoryScript.facts_equal(state,game._build_save_state()))
