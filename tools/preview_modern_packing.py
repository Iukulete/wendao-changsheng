"""Capture actual packing UI/workflow in an isolated, minimized D: viewport."""
import argparse
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CAPTURE = '''extends "res://tests/ark_modern_packing_test.gd"
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
    var output := OS.get_environment("ARK_PACKING_CAPTURE_ROOT")
    assert(output.to_lower().begins_with("d:/"))
    var drawer: bool = game.hud_drawer.visible
    game.hud_drawer.visible = stage != "01_pack_confirmation"
    game._update_hud()
    var target: Vector3 = game.ark_root.to_global(Vector3(.4,.8,-3.4))
    game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    game.camera.size = 10
    for index in 6:
        await process_frame
        if stage != "01_pack_confirmation" and index >= 2:
            var scroll := game.hud_drawer.find_child("ArkHelpScroll",true,false) as ScrollContainer
            assert(scroll != null)
            scroll.ensure_control_visible(game.modern_action_button)
        game.camera.global_position = target+Vector3(5,4,6)
        game.camera.look_at(target)
        game.camera.make_current()
        RenderingServer.force_draw(false)
    var picture := view.get_texture().get_image()
    if stage != "01_pack_confirmation":
        var scroll := game.hud_drawer.find_child("ArkHelpScroll",true,false) as ScrollContainer
        assert(scroll.get_global_rect().encloses(game.modern_action_button.get_global_rect()))
        assert(scroll.get_global_rect().encloses(game.modern_status.get_global_rect()))
    assert(picture != null and picture.get_size() == Vector2i(1280,720))
    var colors := {}
    for y in range(0,720,23):
        for x in range(0,1280,23): colors[picture.get_pixel(x,y).to_html()] = true
    assert(colors.size() > 30)
    assert(picture.save_png(output.path_join(stage+".png")) == OK)
    game.hud_drawer.visible = drawer
    game._update_hud()
    print("ARK_PACKING_CAPTURE_OK: ",stage," palette=",colors.size())
'''

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',type=Path,required=True)
    engine = parser.parse_args().godot.resolve(strict=True)
    assert ROOT.drive.lower() == 'd:'
    work = ROOT/'.tmp/modern-packing-preview'
    project = work/'project/godot'
    captures = work/'captures'
    captures.mkdir(parents=True,exist_ok=True)
    names = ['01_pack_confirmation','02_stowed_status','03_reinstalled']
    for name in names: (captures/(name+'.png')).unlink(missing_ok=True)
    shutil.copytree(ROOT/'godot',project,dirs_exist_ok=True,ignore=shutil.ignore_patterns('.godot'))
    config = project/'project.godot'
    text = re.sub(r'(?m)^window/(?:size/mode|flags/no_focus)=.*\n','',config.read_text(encoding='utf-8'))
    config.write_text(text.replace('[display]','[display]\nwindow/size/mode=1\nwindow/flags/no_focus=true',1),encoding='utf-8')
    script = work/'packing_capture.gd'
    script.write_text(CAPTURE,encoding='utf-8')
    env = os.environ.copy()
    env.update(TEMP=str(work),TMP=str(work),APPDATA=str(work/'appdata'),LOCALAPPDATA=str(work/'appdata'),ARK_PACKING_CAPTURE_ROOT=captures.as_posix(),ARK_SIMULATION_EXTENSION=(ROOT/'.local/native/ark_simulation/ark_simulation.gdextension').as_posix())
    for name,options in [('import',['--headless','--import']),('render',['--rendering-method','gl_compatibility','--resolution','1280x720','--fixed-fps','60','--quit-after','8000','--script',str(script)])]:
        result = subprocess.run([str(engine),'--audio-driver','Dummy','--path',str(project),'--log-file',str(work/(name+'-engine.log')),*options],cwd=ROOT,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=600,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        output = result.stdout+result.stderr
        (work/(name+'.log')).write_text(output,encoding='utf-8')
        assert result.returncode == 0 and not re.search(r'^\s*(?:SCRIPT ERROR|ERROR|FATAL ERROR|USER ERROR):',output,re.M),output[-5000:]
        if name == 'render':
            assert 'ARK_MODERN_PACKING_TEST_OK:' in output
            for stage in names: assert 'ARK_PACKING_CAPTURE_OK: '+stage in output
        print('MODERN_PACKING_'+name.upper()+'_OK',flush=True)
    for name in names:
        data = (captures/(name+'.png')).read_bytes()
        assert data[:8] == b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',data[16:24]) == (1280,720) and len(data) > 10000
    print('MODERN_PACKING_PREVIEW_OK: actual offscreen workflow; review camera; '+str(captures),flush=True)
    return 0

if __name__ == '__main__': raise SystemExit(main())
