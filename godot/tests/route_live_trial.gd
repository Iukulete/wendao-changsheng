extends SceneTree
const Planner=preload("res://scripts/modules/residents/ark_shore_route_trial.gd")
var game: Node3D
var failures: Array[String]=[]
var frames:=0
var distance:=0.0
var reloads:=0
var root_path: String
func _initialize()->void: _run.call_deferred()
func check(ok:bool,note:String)->void:
    if not ok: failures.append(note);printerr("LIVE_TRIAL_FAIL: ",note)
func freeze(node:Node)->void:
    if node.scene_file_path=="res://scenes/ark_greybox.tscn":
        node.set_process(false);node.set_physics_process(false)
        if node.get("player")!=null: node.player.set_physics_process(false)
func added(node:Node)->void:
    if node.scene_file_path=="res://scenes/ark_greybox.tscn": node.ready.connect(freeze.bind(node),CONNECT_ONE_SHOT)
func settle()->void:
    await process_frame
    await physics_frame
    await process_frame
func count(id:String)->int:
    var n:=0
    for e in game.world_events:
        if e.id==id:n+=1
    return n
func continued(label:String)->void:
    var before:Vector3=game.traveler_marker.global_position
    var phase:String=game.resident_gather_phase
    var task:String=game.resident_task_id
    var owners=JSON.parse_string(JSON.stringify(game._build_save_state().modules.economy))
    check(game._save_progress(),label+" save")
    game.find_child("ArkReturnToMainButton",true,false).pressed.emit()
    await settle()
    check(current_scene.scene_file_path=="res://scenes/main.tscn",label+" real menu")
    current_scene.find_child("ArkEnterButton",true,false).pressed.emit()
    await settle()
    game=current_scene
    check(game.traveler_marker.global_position.distance_to(before)<0.00001,label+" exact pre-first-frame position")
    check(game.resident_gather_phase==phase and game.resident_task_id==task,label+" phase/task")
    var after_owners=JSON.parse_string(JSON.stringify(game._build_save_state().modules.economy))
    if after_owners!=owners:print("OWNER_DIFF: ",JSON.stringify({"before":owners,"after":after_owners}))
    check(after_owners==owners,label+" economy ownership")
    check(game.resident_gather_pending,label+" still pending")
    print("LIVE_CONTINUE: ",label," position=",before," phase=",phase," task=",task)
    reloads+=1
func run_case(policy:String)->void:
    var saver=preload("res://scripts/ark_greybox_save.gd").new(root_path)
    saver.clear_for_test()
    game=load("res://scenes/ark_greybox.tscn").instantiate()
    game.save_root_override=root_path
    root.add_child(game);current_scene=game
    await settle()
    for entry in game.interactables.duplicate():
        if entry.id=="wood":
            game.player.global_position=entry.node.global_position;game._interact();break
    check(game._try_place_shelter(Vector3.ZERO),policy+" shelter")
    game.resident_met=true;game.traveler_choice_pending=true;game._choose_traveler_boarding(true)
    game.weather_phase=2;game.resident_gather_policy=policy
    await physics_frame
    game._module_seed_sources()
    var source_id: String="DriftwoodShore" if policy=="wood_first" else "TidalShellsNear"
    var source_before:Dictionary=game.economy.source(source_id)
    var resource:String=source_before.resource
    var inventory_before:int=game.economy.inventory("player",resource)
    check(game._begin_resident_daily_gather(),policy+" dispatch")
    check(game.resident_gather_target_id==source_id,policy+" unchanged ordinary target")
    var task:String=game.resident_task_id
    var milestones:Dictionary={}
    var ticks:=0
    var validator=Planner.new()
    check(validator.configure(game),"configure")
    # Frozen witnesses must not be accepted as lateral clearance.
    check(not validator.edge_clear(Vector3(-3.2,.12,0),Vector3(-2.7,.12,0)),"reject under-rail")
    check(not validator.edge_clear(Vector3(-3.052693,.15,2.2196),Vector3(-3,.15,2.25)),"reject unchanged corner")
    while game.resident_gather_pending and ticks<2000 and failures.is_empty():
        var phase:String=game.resident_gather_phase
        var before:Vector3=game.traveler_marker.global_position
        if game.resident_gather_route.is_empty():game._process_resident_gathering(0.0)
        var index:int=game.resident_gather_route_index
        game._process_resident_gathering(0.1)
        var after:Vector3=game.traveler_marker.global_position
        check(after.distance_to(before)<=.18001,"distance budget")
        check(validator.edge_clear(before,after),"actual frame chord "+str(before)+" -> "+str(after))
        distance+=before.distance_to(after);frames+=1;ticks+=1
        var corner:bool=game.resident_gather_route_index>index
        var label:=phase+("_corner" if corner else "_interior")
        if phase in ["outbound","returning"] and not milestones.has(label) and before.distance_to(after)>0.00001:
            milestones[label]=true
            await continued(policy+"_"+label)
            validator=Planner.new();check(validator.configure(game),"reload configure")
    check(not game.resident_gather_pending,policy+" completed within 2000 ticks")
    check(count("resident_gather_started")==1 and count("resident_gather_harvested")==1,policy+" start/harvest once")
    check(int(get_meta("route_trial_abort_count",0))==0,policy+" no abort call")
    check(game.economy.audit().ok,policy+" economy audit")
    check(int(game.economy.source(source_id).remaining)==0,policy+" source depleted once")
    check(game.economy.inventory("player",resource)-inventory_before==int(source_before.remaining),policy+" exact inventory delta")
    print("LIVE_ECONOMY: ",JSON.stringify({"policy":policy,"source":source_id,"remaining_before":source_before.remaining,"remaining_after":game.economy.source(source_id).remaining,"inventory_delta":game.economy.inventory("player",resource)-inventory_before,"abort_calls":get_meta("route_trial_abort_count",0)}))
    check(count("resident_gather_delivered")==1,policy+" delivery once")
    check(game.gathering.task(task).phase=="delivered",policy+" task delivered")
    check(game.economy.carried(task).is_empty(),policy+" cargo cleared")
    check(milestones.size()==4,policy+" all four save points")
    for e in game.world_events:
        if str(e.id).contains("gather"):
            print("LIVE_EVENT: ",JSON.stringify(e))
            check(not str(e.id).contains("abort"),policy+" no abort event")
            if e.id=="resident_gather_delivered":check(str(e).contains("ark_return"),policy+" ordinary delivery reason")
    print("LIVE_CASE: ",policy," ticks=",ticks," milestones=",milestones)
    game.save_service=null;game.queue_free();await process_frame
func _run()->void:
    root_path=ProjectSettings.globalize_path("res://../.local/test_live_route").simplify_path()
    node_added.connect(added)
    var began:=Time.get_ticks_usec()
    for policy in ["wood_first","shellfish_first"]:
        await run_case(policy)
        if not failures.is_empty():break
    print("LIVE_TRIAL_RESULT: ",JSON.stringify({"failures":failures,"frames":frames,"travel_m":distance,"reloads":reloads,"wall_usec":Time.get_ticks_usec()-began,"scope":"manual .1s actual gathering ticks; real menu button signals, not native inputs or render FPS"}))
    quit(0 if failures.is_empty() else 1)
