"""Render the actual finite household-food workflow in a no-focus D: copy."""
import argparse, os, re, shutil, struct, subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
CAPTURE = '''extends "res://tests/ark_household_food_test.gd"
var view: SubViewport
func _initialize() -> void:
    root.mode = Window.MODE_MINIMIZED
    root.unfocusable = true
    _run.call_deferred()
func _capture(stage: String) -> void:
    var output := OS.get_environment("ARK_FOOD_CAPTURE_ROOT")
    assert(output.to_lower().begins_with("d:/"))
    if not is_instance_valid(view):
        view = SubViewport.new()
        view.size = Vector2i(1280,720)
        view.own_world_3d = true
        view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        root.add_child(view)
        game.reparent(view)
        await physics_frame
        await physics_frame
        assert(game._ensure_nearfuture_hud()) # Reparent exits the tree; restore the real reversible observer.
    var camera_transform: Transform3D = game.camera.global_transform
    var projection: int = game.camera.projection
    var camera_size: float = game.camera.size
    var player_position: Vector3 = game.player.global_position
    var player_visible: bool = game.player.visible
    var layers := []
    var labels := []
    if stage != "03_pantry_menu":
        for layer in game.find_children("*","CanvasLayer",true,false):
            layers.append({"node":layer,"visible":layer.visible})
            layer.hide()
        for label in game.find_children("*","Label3D",true,false):
            labels.append({"node":label,"visible":label.visible})
            label.hide()
        game.player.hide()
        game.player.global_position = game.ark_root.to_global(Vector3(.6,.3,1.1))
        var target: Vector3 = game.traveler_marker.global_position+Vector3(0,.65,0)
        if stage=="04_shared_table": target = game.ark_root.to_global(game.shelter_position+Vector3(.2,.6,.5))
        game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
        game.camera.size = 3.8 if stage!="04_shared_table" else 5.0
        if stage=="02_cooked_in_transit": game.camera.size = 3.0
        var offset := Vector3(1.8,10,2.4) if stage in ["02_cooked_in_transit","04_shared_table"] else Vector3(2.5,5.0,4.2)
        game.camera.global_position = target+game.traveler_marker.global_basis*offset
        game.camera.look_at(target)
    else:
        game._update_follow_camera()
        game._update_hud()
    for i in 10:
        await process_frame
        game.camera.make_current()
        game._update_shelter_roof_cutaway()
        game.resident_kitchen.present(game)
        for entry in labels: entry.node.hide()
        RenderingServer.force_draw(false)
        RenderingServer.force_sync()
    var picture := view.get_texture().get_image()
    assert(picture!=null and picture.get_size()==Vector2i(1280,720))
    var colors := {}
    for y in range(0,720,23):
        for x in range(0,1280,23): colors[picture.get_pixel(x,y).to_html()] = true
    assert(colors.size()>30)
    assert(picture.save_png(output.path_join(stage+".png"))==OK)
    print("ARK_FOOD_CAPTURE_OK: ",stage," palette=",colors.size())
    for entry in layers: entry.node.visible = entry.visible
    for entry in labels: entry.node.visible = entry.visible
    game.camera.projection = projection
    game.camera.size = camera_size
    game.camera.global_transform = camera_transform
    game.player.global_position = player_position
    game.player.visible = player_visible
    game._update_shelter_roof_cutaway()
'''
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--tag',required=True)
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]+',args.tag): raise ValueError('Bounded tag required')
    engine = args.godot.resolve(strict=True)
    work = ROOT/'.tmp/food-preview'/args.tag
    assert ROOT.drive.lower()=='d:' and not work.exists()
    project = work/'project/godot'
    captures = work/'captures'
    captures.mkdir(parents=True)
    shutil.copytree(ROOT/'godot',project,ignore=shutil.ignore_patterns('.godot'))
    config = project/'project.godot'
    text = re.sub(r'(?m)^window/(?:size/mode|flags/no_focus)=.*\n','',config.read_text(encoding='utf-8'))
    config.write_text(text.replace('[display]','[display]\nwindow/size/mode=1\nwindow/flags/no_focus=true',1),encoding='utf-8')
    script = work/'food_capture.gd'
    script.write_text(CAPTURE,encoding='utf-8')
    env = os.environ.copy()
    env.update(TEMP=str(work),TMP=str(work),APPDATA=str(work/'appdata'),LOCALAPPDATA=str(work/'appdata'),PYTHONUTF8='1',PYTHONDONTWRITEBYTECODE='1',ARK_FOOD_CAPTURE_ROOT=captures.as_posix(),ARK_SIMULATION_EXTENSION=(ROOT/'.local/native/ark_simulation/ark_simulation.gdextension').as_posix())
    for name,options in [('import',['--headless','--import']),('render',['--rendering-method','gl_compatibility','--resolution','1280x720','--fixed-fps','60','--quit-after','10000','--script',str(script)])]:
        proc = subprocess.run([str(engine),'--audio-driver','Dummy','--path',str(project),'--log-file',str(work/(name+'-engine.log')),*options],cwd=ROOT,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=600,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        output = proc.stdout+proc.stderr
        (work/(name+'.log')).write_text(output,encoding='utf-8')
        assert proc.returncode==0 and not re.search(r'^\s*(?:SCRIPT ERROR|ERROR|FATAL ERROR|USER ERROR):',output,re.M),output[-5000:]
        if name=='render':
            assert 'ARK_HOUSEHOLD_FOOD_TEST_OK:' in output
            for stage in ['01_fetch_raw','02_cooked_in_transit','03_pantry_menu','04_shared_table']: assert 'ARK_FOOD_CAPTURE_OK: '+stage in output
        print('FOOD_'+name.upper()+'_OK',flush=True)
    for file in captures.glob('*.png'):
        data = file.read_bytes()
        assert data[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',data[16:24])==(1280,720) and len(data)>10000
    assert len(list(captures.glob('*.png')))==4
    print('FOOD_PREVIEW_OK: actual source-to-shared-meal workflow; '+str(captures),flush=True)
    return 0
if __name__=='__main__': raise SystemExit(main())
