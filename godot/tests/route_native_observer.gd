extends SceneTree
## Isolated synthetic setup using actual pickup/shelter/boarding/dispatch APIs.
## Thereafter native gameplay, F5/Escape/menu input unchanged. No default saves.
var game:Node3D
var previous:=Vector3.ZERO
var last_index:=-1
var ticks:=0
var ready_to_observe:=false
var held_this_scene:=false
func _initialize()->void:_setup.call_deferred()
func scene_added(node:Node)->void:
    if node.scene_file_path=="res://scenes/ark_greybox.tscn":node.ready.connect(loaded.bind(node),CONNECT_ONE_SHOT)
func loaded(node:Node)->void:
    game=node
    if ready_to_observe:
        print("NATIVE_CONTINUE_BEFORE_FIRST_FRAME: ",JSON.stringify({"position":var_to_str(game.traveler_marker.global_position),"phase":game.resident_gather_phase,"pending":game.resident_gather_pending,"task":game.resident_task_id}))
        previous=game.traveler_marker.global_position
        last_index=-1
        held_this_scene=false
func _setup()->void:
    var path:=ProjectSettings.globalize_path("res://../.local/test_native_route").simplify_path()
    preload("res://scripts/ark_greybox_save.gd").new(path).clear_for_test()
    node_added.connect(scene_added)
    game=load("res://scenes/ark_greybox.tscn").instantiate()
    game.save_root_override=path;root.add_child(game);current_scene=game
    game.set_process(false);game.player.set_physics_process(false)
    await physics_frame
    for entry in game.interactables.duplicate():
        if entry.id=="wood":game.player.global_position=entry.node.global_position;game._interact();break
    assert(game._try_place_shelter(Vector3.ZERO))
    game.resident_met=true;game.traveler_choice_pending=true;game._choose_traveler_boarding(true)
    game.weather_phase=2;game.resident_gather_policy="shellfish_first"
    await physics_frame
    assert(game._begin_resident_daily_gather())
    previous=game.traveler_marker.global_position
    game.set_process(true);game.player.set_physics_process(true);ready_to_observe=true
    print("NATIVE_FIXTURE_READY: isolated ordinary shellfish task; F5 saves, Escape opens ordinary menu; no key injection")
func _process(_delta:float)->bool:
    if not ready_to_observe or not is_instance_valid(game) or current_scene!=game:return false
    if game.traveler_marker==null:return false
    var pos:Vector3=game.traveler_marker.global_position
    var index:int=game.resident_gather_route_index
    if index!=last_index or ticks%30==0:
        print("NATIVE_ROUTE_FRAME: ",JSON.stringify({"before":var_to_str(previous),"after":var_to_str(pos),"index":index,"phase":game.resident_gather_phase,"pending":game.resident_gather_pending,"task":game.resident_task_id,"abort_count":get_meta("route_trial_abort_count",0)}))
    if not held_this_scene and last_index>=1 and index>last_index and index<game.resident_gather_route.size() and game.resident_gather_pending:
        held_this_scene=true
        capture_corner.call_deferred()
        game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
        print("NATIVE_PAUSED_FOR_F5: ",JSON.stringify({"controlled_fixture":"simulation held at genuine intermediate corner; rendering and ordinary F5/Escape input remain active", "position":var_to_str(pos),"phase":game.resident_gather_phase,"task":game.resident_task_id,"economy":game._build_save_state().modules.economy}))
    previous=pos;last_index=index;ticks+=1
    return false

func capture_corner()->void:
    var directory:=OS.get_environment("ROUTE_NATIVE_OUT")
    if directory.is_empty() or DisplayServer.get_name()=="headless":return
    if not directory.begins_with("/workspace/scratch/a811abac2e5b/qa-live-route/"):return
    DirAccess.make_dir_recursive_absolute(directory)
    await RenderingServer.frame_post_draw
    var path:=directory.path_join("normal-camera-corner-%d.png" % Time.get_ticks_msec())
    var result:=root.get_texture().get_image().save_png(path)
    print("NATIVE_VIEWPORT_CAPTURE: ",path," error=",result)
