"""Review the real default home presentation without showing/focusing a window.

The first six frames keep the ordinary orbit camera, HUD, character and real roof
cutaway. The device close-ups are explicitly review cameras. Stock, travel and
calendar are declared fixtures; they are not an earned opening playthrough.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
STAGES = [f'{view}_{weather}' for view in ('outside','inside','device') for weather in ('day','night','storm')]
CAPTURE = '''extends SceneTree
const Scene = preload("res://scenes/ark_greybox.tscn")
const Save = preload("res://scripts/ark_greybox_save.gd")
var game: Node3D
var view: SubViewport
func _initialize() -> void:
    root.mode = Window.MODE_MINIMIZED
    root.unfocusable = true
    _run.call_deferred()
func _run() -> void:
    view = SubViewport.new()
    view.size = Vector2i(1280,720)
    view.own_world_3d = true
    view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(view)
    var save_root := ProjectSettings.globalize_path("res://../.local/test_home_presentation_review")
    var service := Save.new(save_root)
    service.clear_for_test()
    game = Scene.instantiate()
    game.save_root_override = save_root
    view.add_child(game)
    game.set_process(false)
    game.set_physics_process(false)
    game.player.set_physics_process(false)
    await physics_frame
    assert(game.home_art_sample.enabled)
    game.player.global_position = game.get_node("PressureWreckInteractable").global_position
    game._interact()
    game.player.position = Vector3(0,1.1,1.75)
    game.wood = 15 # Declared construction stock, never claimed as collected.
    assert(game._try_place_workshop_home_template(Vector3(0,.12,0)))
    game.keel_beams = 1
    game.keel_wreck_searched = true
    game._learn_blueprint("keel_deck_expansion","presentation_review_fixture")
    assert(game._try_place_raft_extension(Vector3(0,.12,-4.2)))
    game._install_modern_utilities()
    assert(game.modern_utilities.installed)
    game.day_period = 1
    game.weather_phase = 2
    game._advance_modern_utilities(180.0)
    # Ordinary resident acceptance, no fabricated remembered experiences.
    for actor in ["tidekeeper","sailmaker"]:
        var marker: Node3D = game.get_node("residentMarker" if actor == "tidekeeper" else "sailmakerMarker")
        game.player.global_position = marker.global_position
        game._interact()
        game._interact()
        if actor == "tidekeeper": game._choose_traveler_boarding(true)
        else: game._choose_sailmaker_boarding(true)
    assert(game.traveler_boarded and game.sailmaker_boarded)
    for kind in ["outside","inside","device"]:
        for weather in [["day",1,2],["night",3,2],["storm",3,1]]:
            game.day_period = weather[1]
            game.weather_phase = weather[2]
            game.player.position = Vector3(0,.35,2.12) if kind == "outside" else Vector3(0,.35,.7)
            game._set_weather_visuals()
            game._update_hud()
            game._update_shelter_roof_cutaway()
            for layer in game.find_children("*","CanvasLayer",true,false): layer.visible = kind != "device"
            if kind == "device":
                game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
                game.camera.size = 4.6
                var target: Vector3 = game.ark_root.to_global(game.ModernUtilityProps.AT+Vector3(0,.9,0))
                game.camera.global_position = target+Vector3(4,3,3)
                game.camera.look_at(target)
            else: game._update_follow_camera()
            game.camera.make_current()
            for frame in 8:
                await process_frame
                RenderingServer.force_draw(false)
                RenderingServer.force_sync()
            var picture := view.get_texture().get_image()
            assert(picture != null and picture.get_size() == Vector2i(1280,720))
            var output := OS.get_environment("ARK_HOME_PRESENTATION_CAPTURE_ROOT")
            assert(output.to_lower().begins_with("d:/"))
            var stage: String = kind+"_"+weather[0]
            assert(picture.save_png(output.path_join(stage+".png")) == OK)
            print("ARK_HOME_PRESENTATION_CAPTURE_OK: ",stage," roof_cutaway=",game._ark_node("BuiltShelter/Roof").get_meta("cutaway_active",false))
    game.save_service = null
    game.free()
    service.clear_for_test()
    print("ARK_HOME_PRESENTATION_PREVIEW_OK:")
    quit()
'''

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--tag',default='development-01')
    args = parser.parse_args()
    engine = args.godot.resolve(strict=True)
    assert ROOT.drive.lower() == 'd:'
    work = ROOT/'.tmp/home-presentation-preview'/args.tag
    work.mkdir(parents=True,exist_ok=False)
    project = work/'project/godot'
    captures = work/'captures'
    captures.mkdir()
    shutil.copytree(ROOT/'godot',project,ignore=shutil.ignore_patterns('.godot'))
    config = project/'project.godot'
    text = re.sub(r'(?m)^window/(?:size/mode|flags/no_focus)=.*\n','',config.read_text(encoding='utf-8'))
    config.write_text(text.replace('[display]','[display]\nwindow/size/mode=1\nwindow/flags/no_focus=true',1),encoding='utf-8')
    script = work/'capture.gd'
    script.write_text(CAPTURE,encoding='utf-8')
    env = os.environ.copy()
    env.update(TEMP=str(work),TMP=str(work),APPDATA=str(work/'appdata'),LOCALAPPDATA=str(work/'appdata'),ARK_HOME_PRESENTATION_CAPTURE_ROOT=captures.as_posix(),ARK_SIMULATION_EXTENSION=(ROOT/'.local/native/ark_simulation/ark_simulation.gdextension').as_posix())
    for name,options in [('import',['--headless','--import']),('render',['--rendering-method','gl_compatibility','--resolution','1280x720','--fixed-fps','60','--quit-after','4000','--script',str(script)])]:
        result = subprocess.run([str(engine),'--audio-driver','Dummy','--path',str(project),'--log-file',str(work/(name+'-engine.log')),*options],cwd=ROOT,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=600,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        output = result.stdout+result.stderr
        (work/(name+'.log')).write_text(output,encoding='utf-8')
        assert result.returncode == 0 and not re.search(r'^\s*(?:SCRIPT ERROR|ERROR|FATAL ERROR|USER ERROR):',output,re.M),output[-5000:]
        if name == 'render':
            assert 'ARK_HOME_PRESENTATION_PREVIEW_OK:' in output
            for stage in STAGES: assert 'ARK_HOME_PRESENTATION_CAPTURE_OK: '+stage in output
        print('HOME_PRESENTATION_'+name.upper()+'_OK',flush=True)
    images = {}
    for stage in STAGES:
        data = (captures/(stage+'.png')).read_bytes()
        assert data[:8] == b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',data[16:24]) == (1280,720) and len(data) > 10000
        images[stage] = hashlib.sha256(data).hexdigest()
    (work/'captures.json').write_text(json.dumps({'images':images,'normal_camera':['outside','inside'],'review_camera':['device'],'fixture':'construction stock, salvage travel, blueprint and calendar; not earned playthrough'},indent=2),encoding='utf-8')
    print('HOME_PRESENTATION_PREVIEW_OK: '+str(captures),flush=True)
    return 0

if __name__ == '__main__': raise SystemExit(main())
