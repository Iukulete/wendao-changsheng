extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
    var game=load("res://scenes/ark_greybox.tscn").instantiate()
    game.save_root_override=ProjectSettings.globalize_path("res://../.local/test_route_leg_probe").simplify_path()
    root.add_child(game)
    game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
    await physics_frame
    var figure: Node3D=game.find_child("TidekeeperFigure",true,false)
    var low:=INF
    var high:=-INF
    var radius:=0.0
    for name_ in ["LegLeft","LegRight"]:
        var leg: MeshInstance3D=figure.find_child(name_,true,false)
        for vertex in leg.mesh.get_faces():
            var p: Vector3=figure.to_local(leg.to_global(vertex))
            low=minf(low,p.y);high=maxf(high,p.y);radius=maxf(radius,Vector2(p.x,p.z).length())
    var shape:=CylinderShape3D.new()
    shape.radius=radius
    shape.height=high-low
    var inputs:=[
        ["home",Vector3(-1,.12,.85),Vector3(-1,.12,.85)],
        ["frozen_start",Vector3(1.517934,.15,-1.6),Vector3(1.517934,.15,-1.6)],
        ["shell",Vector3(8.4,.1,-6.1),Vector3(8.4,.1,-6.1)],
        ["under_rail",Vector3(-3.2,.12,0),Vector3(-2.7,.12,0)],
        ["frozen_first",Vector3(-3.052693,.15,2.2196),Vector3(-3,.15,2.25)],
        ["frozen_second",Vector3(-3,.15,2.25),Vector3(-2.857287,.16665,2.142965)]]
    var rows:=[]
    for row in inputs:
        var query:=PhysicsShapeQueryParameters3D.new()
        query.shape=shape;query.collision_mask=1;query.margin=0.0
        query.transform=Transform3D(Basis.IDENTITY,row[1]+Vector3.UP*(low+high)*.5)
        var overlaps: Array=game.get_world_3d().direct_space_state.intersect_shape(query,32)
        var names:=[]
        for hit in overlaps: names.append(str(game.get_path_to(hit.collider)))
        query.motion=row[2]-row[1]
        var cast: PackedFloat32Array=game.get_world_3d().direct_space_state.cast_motion(query)
        rows.append({"case":row[0],"start":var_to_str(row[1]),"end":var_to_str(row[2]),"initial_colliders":names,"cast":var_to_str(cast)})
    print("LEG_CLEARANCE_PROBE: ",JSON.stringify({"neutral_min_y":low,"neutral_max_y":high,"radius":radius,"rows":rows,"scope":"neutral yaw-invariant leg cylinder, no collision exclusions, not whole body or animated foot support"}))
    game.save_service=null;game.queue_free();await process_frame;quit()
