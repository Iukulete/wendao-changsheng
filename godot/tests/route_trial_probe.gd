extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
    var game = load("res://scenes/ark_greybox.tscn").instantiate()
    game.save_root_override=ProjectSettings.globalize_path("res://../.local/test_route_probe").simplify_path()
    root.add_child(game)
    game.set_process(false)
    game.set_physics_process(false)
    game.player.set_physics_process(false)
    await physics_frame
    var queries := [[Vector3(-1,.12,.85),Vector3(8.4,.1,-6.1)],[Vector3(1.517934,.15,-1.6),Vector3(8.4,.1,-6.1)],[Vector3(2,.12,-7),Vector3(8,.12,-7)],[Vector3(0,.5,0),Vector3(-4,.15,1.5)]]
    var failed := false
    for pair in queries:
        var route: PackedVector3Array=game._build_resident_walk_route(pair[0],pair[1])
        print("ROUTE_TRIAL_PROBE: ",JSON.stringify({"start":var_to_str(pair[0]),"end":var_to_str(pair[1]),"route":var_to_str(route),"stats":game.get_meta("route_trial_last_stats",{})}))
        if route.is_empty(): failed=true
    var figure:Node3D=game.find_child("TidekeeperFigure",true,false)
    var saved:Transform3D=figure.transform
    var guard=preload("res://scripts/modules/residents/ark_shore_route_trial.gd").new()
    figure.scale=Vector3(1.1,1,1)
    if guard.configure(game):failed=true
    figure.transform=saved;figure.rotate_x(.1)
    if guard.configure(game):failed=true
    figure.transform=saved
    if not guard.configure(game):failed=true
    print("ROUTE_TRANSFORM_GUARD: scaled rejected, tilted rejected, restored accepted; aggregate_failed=",failed)
    game.save_service=null
    game.queue_free()
    await process_frame
    print("ROUTE_TRIAL_PROBE_OK" if not failed else "ROUTE_TRIAL_PROBE_FAILED")
    quit(1 if failed else 0)
