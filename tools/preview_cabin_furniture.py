"""Capture actual paid furniture/pantry/rest/cabin flows in a no-focus D: copy."""
import argparse, os, re, shutil, struct, subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
NAMES = ['01_previous_home','01_furniture_home','01_starter_silhouette','02_pantry_menu','02_cabinet_close','03_bed_after_rest','04_guest_normal','04_guest_day','04_guest_night','05_keel_silhouette']
CAPTURE = '''extends "res://tests/ark_cabin_furniture_test.gd"
var view: SubViewport
func _initialize() -> void:
    root.mode = Window.MODE_MINIMIZED
    root.unfocusable = true
    _run.call_deferred()
func _capture(stage: String) -> void:
    if not is_instance_valid(view):
        view = SubViewport.new()
        view.size = Vector2i(1280,720)
        view.own_world_3d = true
        view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        root.add_child(view)
        game.reparent(view)
        await physics_frame
        await physics_frame
        assert(game._ensure_nearfuture_hud())
    if stage=="01_paid_starter_home":
        await _picture("01_previous_home","cabin",false,false,true)
        await _picture("01_furniture_home","cabin")
        await _picture("01_starter_silhouette","vessel")
    elif stage=="02_real_pantry":
        _key(KEY_G)
        assert(game.food_storage.pending)
        await _picture("02_pantry_menu","pantry",true)
        _key(KEY_ESCAPE)
        await _picture("02_cabinet_close","pantry")
    elif stage=="03_rest_after_use":
        await _picture("03_bed_after_rest","bed")
    elif stage=="04_paid_guest_cabin":
        await _picture("04_guest_normal","guest",true)
        await _picture("04_guest_day","guest")
        await _picture("04_guest_night","guest",false,true)
        await _picture("05_keel_silhouette","vessel")
func _picture(id: String,kind: String,normal: bool=false,night: bool=false,previous: bool=false) -> void:
    var camera_transform: Transform3D = game.camera.global_transform
    var projection: int = game.camera.projection
    var camera_size: float = game.camera.size
    var player_position: Vector3 = game.player.global_position
    var player_visible: bool = game.player.visible
    var day: int = game.day_period
    var weather: int = game.weather_phase
    var message: String = game.message
    var focus_visible: bool = game.interaction_focus_ring.visible if is_instance_valid(game.interaction_focus_ring) else false
    var layers := []
    var labels := []
    if kind=="vessel": game.player.global_position = game.ark_root.to_global(Vector3(0,.3,2.20))
    elif kind=="guest": game.player.global_position = game._ark_node("BuiltRaftExtension/GuestCabin").to_global(Vector3(0,.45,.6))
    elif not normal: game.player.global_position = game._ark_node("BuiltShelter").to_global(Vector3(.2,.4,.6))
    if night:
        game.day_period = game.DayPeriod.NIGHT
        game.weather_phase = game.WeatherPhase.AFTER
        game._set_weather_visuals()
    if normal:
        game._update_follow_camera()
        game._update_interaction_hint()
        game._update_hud()
    else:
        for layer in game.find_children("*","CanvasLayer",true,false):
            layers.append({"node":layer,"visible":layer.visible})
            layer.hide()
        for label in game.find_children("*","Label3D",true,false):
            labels.append({"node":label,"visible":label.visible})
            label.hide()
        game.player.hide()
        if is_instance_valid(game.interaction_focus_ring): game.interaction_focus_ring.hide()
        game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
        var target: Vector3 = game._ark_node("BuiltShelter").global_position+Vector3(.25,.6,.05)
        var offset := Vector3(.3,2.4,4.8)
        game.camera.size = 4.8
        if kind=="pantry":
            target = game._ark_node("BuiltStorage").global_position+Vector3(0,.45,0)
            offset = Vector3(1.9,2.4,3.1)
            game.camera.size = 2.2
        elif kind=="bed":
            target = game._ark_node("BuiltShelter/Cot").global_position+Vector3(0,.25,0)
            offset = Vector3(-.3,2.0,3.8)
            game.camera.size = 2.6
        elif kind=="guest":
            target = game._ark_node("BuiltRaftExtension/GuestCabin").to_global(Vector3(0,.65,-.2))
            offset = Vector3(-3.8,4.8,2.4)
            game.camera.size = 4.0
        elif kind=="vessel":
            var expanded: bool = game._ark_node("BuiltRaftExtension")!=null
            target = game.ark_root.to_global(Vector3(0,.35,-2.0 if expanded else 0.0))
            offset = Vector3(6,3.8,7)
            game.camera.size = 11.8 if expanded else 8.5
        game.camera.global_position = target+game.ark_root.global_basis*offset
        game.camera.look_at(target)
    if previous: game.home_art_sample.furniture.restore() # Prior warm home, not a misleading graybox comparison.
    for i in 12:
        await process_frame
        game.camera.make_current()
        game._update_shelter_roof_cutaway()
        for entry in labels: entry.node.hide()
        RenderingServer.force_draw(false)
        RenderingServer.force_sync()
    var caps: MultiMesh = game.get_node("ArkRoot/HomeArtCandidate/CappedGunwales").multimesh
    var rail: MeshInstance3D = game.get_node("ArkRoot/RaftPort").get_child(0)
    assert(is_equal_approx(caps.get_instance_transform(0).basis.z.length(),rail.mesh.size.z-.05),"GL renderer must retain the actual full-length rail-cap transforms")
    var picture := view.get_texture().get_image()
    assert(picture!=null and picture.get_size()==Vector2i(1280,720))
    var colors := {}
    for y in range(0,720,23):
        for x in range(0,1280,23): colors[picture.get_pixel(x,y).to_html()] = true
    assert(colors.size()>30)
    assert(picture.save_png(OS.get_environment("ARK_CABIN_CAPTURE_ROOT").path_join(id+".png"))==OK)
    print("ARK_CABIN_CAPTURE_OK: ",id," palette=",colors.size())
    if previous: game.home_art_sample.apply(game)
    for entry in layers: entry.node.visible = entry.visible
    for entry in labels: entry.node.visible = entry.visible
    game.camera.projection = projection
    game.camera.size = camera_size
    game.camera.global_transform = camera_transform
    game.player.global_position = player_position
    game.player.visible = player_visible
    if is_instance_valid(game.interaction_focus_ring): game.interaction_focus_ring.visible = focus_visible
    game.day_period = day
    game.weather_phase = weather
    game.message = message
    game._set_weather_visuals()
    game._update_shelter_roof_cutaway()
    game._update_interaction_hint()
'''
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--tag',required=True)
    args = parser.parse_args()
    assert re.fullmatch(r'[A-Za-z0-9_-]+',args.tag)
    engine = args.godot.resolve(strict=True)
    work = ROOT/'.tmp/cabin-furniture-preview'/args.tag
    assert ROOT.drive.lower()=='d:' and not work.exists()
    project,captures = work/'project/godot',work/'captures'
    captures.mkdir(parents=True)
    shutil.copytree(ROOT/'godot',project,ignore=shutil.ignore_patterns('.godot'))
    config = project/'project.godot'
    text = re.sub(r'(?m)^window/(?:size/mode|flags/no_focus)=.*\n','',config.read_text(encoding='utf-8'))
    config.write_text(text.replace('[display]','[display]\nwindow/size/mode=1\nwindow/flags/no_focus=true',1),encoding='utf-8')
    script = work/'cabin_capture.gd'
    script.write_text(CAPTURE,encoding='utf-8')
    env = os.environ.copy()
    env.update(TEMP=str(work),TMP=str(work),APPDATA=str(work/'appdata'),LOCALAPPDATA=str(work/'appdata'),ARK_CABIN_CAPTURE_ROOT=captures.as_posix(),ARK_SIMULATION_EXTENSION=(ROOT/'.local/native/ark_simulation/ark_simulation.gdextension').as_posix())
    for name,options in [('import',['--headless','--import']),('render',['--rendering-method','gl_compatibility','--fixed-fps','60','--resolution','1280x720','--quit-after','5000','--script',str(script)])]:
        proc = subprocess.run([str(engine),'--audio-driver','Dummy','--path',str(project),'--log-file',str(work/(name+'-engine.log')),*options],cwd=ROOT,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=600,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        output = proc.stdout+proc.stderr
        (work/(name+'.log')).write_text(output,encoding='utf-8')
        assert proc.returncode==0 and not re.search(r'^\s*(?:SCRIPT ERROR|ERROR|FATAL ERROR|USER ERROR):',output,re.M),output[-5000:]
        if name=='render':
            assert 'ARK_CABIN_FURNITURE_TEST_OK:' in output
            for id in NAMES: assert 'ARK_CABIN_CAPTURE_OK: '+id in output
        print('CABIN_'+name.upper()+'_OK',flush=True)
    for path in captures.glob('*.png'):
        data = path.read_bytes()
        assert data[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',data[16:24])==(1280,720) and len(data)>10000
    assert len(list(captures.glob('*.png')))==len(NAMES)
    print('CABIN_PREVIEW_OK: '+str(captures),flush=True)
    return 0
if __name__=='__main__': raise SystemExit(main())
