"""Render actual kitchen work in an isolated, minimized D: SubViewport."""
import argparse
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CAPTURE = '''extends "res://tests/ark_resident_kitchen_test.gd"
var view: SubViewport
func _initialize() -> void:
    root.mode = Window.MODE_MINIMIZED
    root.unfocusable = true
    _run.call_deferred()
func _spawn() -> void:
    if not is_instance_valid(view):
        view = SubViewport.new()
        view.size = Vector2i(1280,720)
        view.own_world_3d = true
        view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        root.add_child(view)
    game = Scene.instantiate()
    game.save_root_override = save_root
    view.add_child(game)
    game.set_process(false)
    game.set_physics_process(false)
    await physics_frame
func _capture(stage: String) -> void:
    var output := OS.get_environment("ARK_KITCHEN_CAPTURE_ROOT")
    assert(output.to_lower().begins_with("d:/"))
    var current: Dictionary = game.resident_kitchen.station(game)
    assert(not current.is_empty() and game.resident_kitchen.arrived(game))
    assert(game.traveler_body.has_node("TemporaryKitchenWorkPose"))
    var player_position: Vector3 = game.player.position
    var player_visible: bool = game.player.visible
    game.player.global_position = game.ark_root.to_global(Vector3(.6,.12,1.1))
    game.player.hide()
    var layers := []
    for layer in game.find_children("*","CanvasLayer",true,false):
        layers.append({"node":layer,"visible":layer.visible})
        layer.hide()
    var labels := []
    for label in game.find_children("*","Label3D",true,false):
        labels.append({"node":label,"visible":label.visible})
        label.hide()
    var target: Vector3 = current.node.global_position+Vector3(.25,.35,.3)
    game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    game.camera.size = 3.9
    for index in 8:
        await process_frame
        game.camera.global_position = target+Vector3(2.5,7.5,4.2)
        game.camera.look_at(target)
        game.camera.make_current()
        game._update_shelter_roof_cutaway()
        game.resident_kitchen.present(game)
        for entry in labels: entry.node.hide()
        RenderingServer.force_draw(false)
        RenderingServer.force_sync()
    await _write_picture(output,stage)
    if stage == "01_hearth_work":
        for entry in layers: entry.node.visible = entry.visible
        game.hud_drawer.show()
        game._update_hud()
        game.resident_kitchen.present(game) # Drawer is a real production pause.
        for index in 8:
            await process_frame
            var scroll := game.hud_drawer.find_child("ArkHelpScroll",true,false) as ScrollContainer
            assert(scroll != null)
            scroll.ensure_control_visible(game.kitchen_button)
            for entry in labels: entry.node.hide()
            RenderingServer.force_draw(false)
            RenderingServer.force_sync()
        var kitchen_scroll := game.hud_drawer.find_child("ArkHelpScroll",true,false) as ScrollContainer
        assert(kitchen_scroll.get_global_rect().encloses(game.kitchen_button.get_global_rect()))
        await _write_picture(output,"03_kitchen_policy")
        game.hud_drawer.hide()
    for entry in layers: entry.node.visible = entry.visible
    for entry in labels: entry.node.visible = entry.visible
    game.player.position = player_position
    game.player.visible = player_visible
    game._update_shelter_roof_cutaway()
func _write_picture(output: String,stage: String) -> void:
    var picture := view.get_texture().get_image()
    assert(picture != null and picture.get_size() == Vector2i(1280,720))
    var colors := {}
    for y in range(0,720,23):
        for x in range(0,1280,23): colors[picture.get_pixel(x,y).to_html()] = true
    assert(colors.size() > 30)
    assert(picture.save_png(output.path_join(stage+".png")) == OK)
    print("ARK_KITCHEN_CAPTURE_OK: ",stage," palette=",colors.size())
'''

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--tag',help='Preserve other review runs in a separate named subdirectory')
    args = parser.parse_args()
    engine = args.godot.resolve(strict=True)
    assert ROOT.drive.lower() == 'd:'
    work = ROOT/'.tmp/kitchen-preview'
    if args.tag:
        if not re.fullmatch(r'[A-Za-z0-9_-]+',args.tag): raise ValueError('Use a bounded review tag')
        work = work/args.tag
        if work.exists(): raise FileExistsError(work)
    project = work/'project/godot'
    captures = work/'captures'
    captures.mkdir(parents=True,exist_ok=True)
    names = ['01_hearth_work','02_pressure_work','03_kitchen_policy']
    for name in names: (captures/(name+'.png')).unlink(missing_ok=True)
    shutil.copytree(ROOT/'godot',project,dirs_exist_ok=True,ignore=shutil.ignore_patterns('.godot'))
    config = project/'project.godot'
    text = re.sub(r'(?m)^window/(?:size/mode|flags/no_focus)=.*\n','',config.read_text(encoding='utf-8'))
    config.write_text(text.replace('[display]','[display]\nwindow/size/mode=1\nwindow/flags/no_focus=true',1),encoding='utf-8')
    script = work/'kitchen_capture.gd'
    script.write_text(CAPTURE,encoding='utf-8')
    env = os.environ.copy()
    env.update(TEMP=str(work),TMP=str(work),APPDATA=str(work/'appdata'),LOCALAPPDATA=str(work/'appdata'),ARK_KITCHEN_CAPTURE_ROOT=captures.as_posix(),ARK_SIMULATION_EXTENSION=(ROOT/'.local/native/ark_simulation/ark_simulation.gdextension').as_posix())
    for name,options in [('import',['--headless','--import']),('render',['--rendering-method','gl_compatibility','--resolution','1280x720','--fixed-fps','60','--quit-after','8000','--script',str(script)])]:
        result = subprocess.run([str(engine),'--audio-driver','Dummy','--path',str(project),'--log-file',str(work/(name+'-engine.log')),*options],cwd=ROOT,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=600,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        output = result.stdout+result.stderr
        (work/(name+'.log')).write_text(output,encoding='utf-8')
        assert result.returncode == 0 and not re.search(r'^\s*(?:SCRIPT ERROR|ERROR|FATAL ERROR|USER ERROR):',output,re.M),output[-5000:]
        if name == 'render':
            assert 'ARK_RESIDENT_KITCHEN_TEST_OK:' in output
            for stage in names: assert 'ARK_KITCHEN_CAPTURE_OK: '+stage in output
        print('KITCHEN_'+name.upper()+'_OK',flush=True)
    for name in names:
        data = (captures/(name+'.png')).read_bytes()
        assert data[:8] == b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',data[16:24]) == (1280,720) and len(data) > 10000
    print('KITCHEN_PREVIEW_OK: actual offscreen kitchen workflow; '+str(captures),flush=True)
    return 0

if __name__ == '__main__': raise SystemExit(main())
