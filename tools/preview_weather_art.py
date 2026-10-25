"""Capture the production GPU rain and real roof masking without foreground UI."""
import argparse, os, re, shutil, struct, subprocess
from pathlib import Path
from preview_cabin_furniture import CAPTURE, NAMES as CABIN_NAMES
ROOT=Path(__file__).resolve().parents[1]
WEATHER_NAMES=['06_storm_rain_off','07_storm_outside','08_storm_sheltered','09_storm_damaged','10_rain_after']
EXTRA='''
func _weather_views() -> void:
    var phase: int = game.weather_phase
    var period: int = game.day_period
    var damage: bool = game.shelter_roof_damaged
    var roof: Node3D = game._ark_node("BuiltShelter/Roof")
    var visible_: bool = roof.visible
    game.day_period = game.DayPeriod.DAY
    game.weather_phase = game.WeatherPhase.STORM
    game._set_weather_visuals()
    weather_fx = game.home_art_sample.weather
    for i in 90:
        await process_frame
        game._update_shelter_roof_cutaway(1.0/60.0)
        RenderingServer.force_draw(false)
        RenderingServer.force_sync()
    assert(weather_fx.rain.emitting and weather_fx.strength==1.0)
    await _picture("06_storm_rain_off","cabin")
    await _picture("07_storm_outside","vessel",true)
    await _picture("08_storm_sheltered","cabin")
    game.shelter_roof_damaged = true
    roof.visible = false
    await _picture("09_storm_damaged","cabin")
    assert(not weather_fx.material.get_shader_parameter("primary_active"))
    game.shelter_roof_damaged = damage
    roof.visible = visible_
    game.weather_phase = game.WeatherPhase.AFTER
    game._set_weather_visuals()
    for i in 60: game._update_shelter_roof_cutaway(1.0/60.0)
    await _picture("10_rain_after","vessel",true)
    assert(not weather_fx.rain.emitting and not weather_fx.root.visible)
    weather_fx = null
    game.weather_phase = phase
    game.day_period = period
    game._set_weather_visuals()
'''
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--tag',required=True)
    args=parser.parse_args()
    assert re.fullmatch(r'[A-Za-z0-9_-]+',args.tag)
    engine=args.godot.resolve(strict=True)
    work=ROOT/'.tmp/weather-art-preview'/args.tag
    assert ROOT.drive.lower()=='d:' and not work.exists()
    project,captures=work/'project/godot',work/'captures'
    captures.mkdir(parents=True)
    shutil.copytree(ROOT/'godot',project,ignore=shutil.ignore_patterns('.godot'))
    config=project/'project.godot'
    text=re.sub(r'(?m)^window/(?:size/mode|flags/no_focus)=.*\n','',config.read_text(encoding='utf-8'))
    config.write_text(text.replace('[display]','[display]\nwindow/size/mode=1\nwindow/flags/no_focus=true',1),encoding='utf-8')
    script=CAPTURE.replace('var view: SubViewport','var view: SubViewport\nvar weather_fx: RefCounted')
    script=script.replace('await _picture("01_starter_silhouette","vessel")','await _picture("01_starter_silhouette","vessel")\n        await _weather_views()')
    script=script.replace('game._update_shelter_roof_cutaway()','game._update_shelter_roof_cutaway(1.0/60.0)')
    script=script.replace('for entry in labels: entry.node.hide()','if id=="06_storm_rain_off" and weather_fx!=null: weather_fx.root.hide()\n        for entry in labels: entry.node.hide()')
    path=work/'capture.gd'
    path.write_text(script+EXTRA,encoding='utf-8')
    env=os.environ.copy()
    env.update(TEMP=str(work),TMP=str(work),APPDATA=str(work/'appdata'),LOCALAPPDATA=str(work/'appdata'),ARK_CABIN_CAPTURE_ROOT=captures.as_posix(),ARK_SIMULATION_EXTENSION=(ROOT/'.local/native/ark_simulation/ark_simulation.gdextension').as_posix())
    for name,options in [('import',['--headless','--import']),('render',['--rendering-method','gl_compatibility','--fixed-fps','60','--resolution','1280x720','--quit-after','5000','--script',str(path)])]:
        proc=subprocess.run([str(engine),'--audio-driver','Dummy','--path',str(project),'--log-file',str(work/(name+'-engine.log')),*options],cwd=ROOT,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=600,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        output=proc.stdout+proc.stderr
        (work/(name+'.log')).write_text(output,encoding='utf-8')
        assert proc.returncode==0 and not re.search(r'^\s*(?:SCRIPT ERROR|ERROR|FATAL ERROR|USER ERROR):',output,re.M),output[-6000:]
        if name=='render':
            assert 'ARK_CABIN_FURNITURE_TEST_OK:' in output
            for id in [*CABIN_NAMES,*WEATHER_NAMES]: assert 'ARK_CABIN_CAPTURE_OK: '+id in output
        print('WEATHER_'+name.upper()+'_OK',flush=True)
    for id in [*CABIN_NAMES,*WEATHER_NAMES]:
        data=(captures/(id+'.png')).read_bytes()
        assert data[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',data[16:24])==(1280,720) and len(data)>10000
    assert len(list(captures.glob('*.png')))==len(CABIN_NAMES)+len(WEATHER_NAMES)
    print('WEATHER_CAPTURE_OK: '+str(captures),flush=True)
if __name__=='__main__': main()
