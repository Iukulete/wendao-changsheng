"""Background-only display capture of the real regional exploration test on D:."""
from __future__ import annotations
import argparse
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CAPTURE_SCRIPT = '''extends "res://tests/ark_moonback_exploration_test.gd"
var capture_view: SubViewport
func _spawn() -> void:
    if not is_instance_valid(capture_view):
        capture_view = SubViewport.new()
        capture_view.size = Vector2i(1280,720)
        capture_view.own_world_3d = true
        capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        root.add_child(capture_view)
    game = Scene.instantiate()
    game.save_root_override = save_root
    capture_view.add_child(game)
    game.set_process(false)
    game.set_physics_process(false)
    await physics_frame
func _capture(name_: String, target: Vector3, offset: Vector3, size: float) -> void:
    var output := OS.get_environment("ARK_MOONBACK_CAPTURES")
    assert(output.to_lower().begins_with("d:/"))
    var period: int = game.day_period
    var weather: int = game.weather_phase
    game.day_period = 1
    game.weather_phase = 2
    game._set_weather_visuals()
    for layer in game.find_children("*","CanvasLayer",true,false): layer.visible = false
    game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    game.camera.size = size
    var picture: Image
    var palette := {}
    var land_pixels := 0
    for attempt in 3:
        for i in 8:
            game.camera.global_position = target+offset
            game.camera.look_at(target)
            game.camera.make_current()
            await process_frame
            RenderingServer.force_draw(false)
            # Capture-only CPU/GPU sync, never inserted into the game loop.
            RenderingServer.force_sync()
        assert(capture_view.get_camera_3d() == game.camera,"capture must use the actual review camera")
        picture = capture_view.get_texture().get_image()
        assert(picture != null and picture.get_size() == Vector2i(1280,720))
        palette.clear()
        land_pixels = 0
        for y in range(0,720,19):
            for x in range(0,1280,19):
                var color := picture.get_pixel(x,y)
                palette[color.to_html()] = true
                if color.r > color.b*.9 and color.r > color.g*.65 and color.g > .12: land_pixels += 1
        if land_pixels > 80: break
    assert(palette.size() > 30 and land_pixels > 80,"reject water-only/empty offscreen frames; human visual approval is still separate")
    assert(picture.save_png(output.path_join(name_+".png")) == OK)
    game.day_period = period
    game.weather_phase = weather
    game._set_weather_visuals()
    print("ARK_MOONBACK_CAPTURE_OK: ",name_," colors=",palette.size()," land_samples=",land_pixels," camera=",game.camera.global_transform," world=",game.get_world_3d().get_rid())
'''

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--workspace',type=Path,default=ROOT/'.tmp/moonback-preview')
    args = parser.parse_args()
    engine = args.godot.resolve(strict=True)
    if os.name == 'nt' and ROOT.drive.lower() != 'd:':
        raise RuntimeError('Project copies/captures must stay on D:')
    workspace = args.workspace.resolve()
    if (ROOT/'.tmp').resolve() not in workspace.parents:
        raise RuntimeError('Preview workspace must remain within this project .tmp on D:')
    project = workspace/'project/godot'
    captures = workspace/'captures'
    captures.mkdir(parents=True,exist_ok=True)
    shutil.copytree(ROOT/'godot',project,dirs_exist_ok=True,ignore=shutil.ignore_patterns('.godot'))
    config = project/'project.godot'
    source = re.sub(r'(?m)^window/(?:size/mode|flags/no_focus)=.*\n','',config.read_text(encoding='utf-8'))
    source = source.replace('[display]','[display]\nwindow/size/mode=1\nwindow/flags/no_focus=true',1)
    config.write_text(source,encoding='utf-8')
    script = workspace/'capture.gd'
    script.write_text(CAPTURE_SCRIPT,encoding='utf-8')
    env = os.environ.copy()
    env.update(TEMP=str(workspace),TMP=str(workspace),TMPDIR=str(workspace),APPDATA=str(workspace/'appdata'),LOCALAPPDATA=str(workspace/'appdata'),ARK_MOONBACK_CAPTURES=captures.as_posix(),ARK_SIMULATION_EXTENSION=(ROOT/'.local/native/ark_simulation/ark_simulation.gdextension').as_posix())
    for name, options in [('import',['--headless','--import']),('render',['--rendering-method','gl_compatibility','--resolution','1280x720','--fixed-fps','60','--quit-after','8000','--script',str(script)])]:
        result = subprocess.run([str(engine),'--audio-driver','Dummy','--path',str(project),'--log-file',str(workspace/(name+'-engine.log')),*options],cwd=ROOT,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=600,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        output = result.stdout+result.stderr
        (workspace/(name+'.log')).write_text(output,encoding='utf-8')
        if result.returncode or 'SCRIPT ERROR:' in output or 'ERROR:' in output:
            raise RuntimeError(name+' failed: '+output[-5000:])
        if name == 'render' and 'ARK_MOONBACK_EXPLORATION_TEST_OK:' not in output:
            raise RuntimeError('Render did not finish the actual exploration test')
    for name in ['01_moonback_highland','02_station_arrival','03_old_landing']:
        data = (captures/(name+'.png')).read_bytes()
        if data[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('>II',data[16:24]) != (1280,720) or len(data) < 10000:
            raise RuntimeError('Missing/invalid capture: '+name)
    print('MOONBACK_PREVIEW_OK: '+str(captures))
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
