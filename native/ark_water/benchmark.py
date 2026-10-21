"""Run only after the coordinator releases the final quiet measurement slot."""
import argparse, hashlib, json, os, pathlib, shutil, subprocess
SOURCE_DIR=pathlib.Path(__file__).resolve().parent
ROOT=SOURCE_DIR.parents[1]
p=argparse.ArgumentParser()
p.add_argument('--quiet-approved',action='store_true')
p.add_argument('--out',type=pathlib.Path,default=ROOT/'.tmp/native-benchmark')
p.add_argument('--build-dir',type=pathlib.Path,default=ROOT/'.tmp/recovery-native/build')
a=p.parse_args()
if not a.quiet_approved:
 p.error('Coordinator must release final quiet slot before this benchmark runs.')
out=a.out.resolve()
out.mkdir(parents=True,exist_ok=True)
build=a.build_dir.resolve()
build_manifest=json.loads((build/'build-manifest.json').read_text())
cpp=ROOT/'native/ark_water/ark_water.cpp'
if build_manifest['sha256']['ark_water.cpp']!=hashlib.sha256(cpp.read_bytes()).hexdigest():
 raise SystemExit('Native build does not match current C++ source; rebuild in a separate output directory.')
if build_manifest['sha256']['libark_water.so']!=hashlib.sha256((build/'libark_water.so').read_bytes()).hexdigest():
 raise SystemExit('Native binary does not match its build manifest.')
project=out/'frozen-project'
(project/'scripts/adapters').mkdir(parents=True,exist_ok=True)
(project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Native wrapper benchmark"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
adapter=ROOT/'godot/scripts/adapters/ark_analytic_water.gd'
shutil.copy2(adapter,project/'scripts/adapters/ark_analytic_water.gd')
shutil.copy2(SOURCE_DIR/'benchmark.gd',project/'benchmark.gd')
lib=out/'frozen-native';lib.mkdir(exist_ok=True)
for name in ['libark_water.so','ark_water.gdextension','build-manifest.json']:
 shutil.copy2(build/name,lib/name)
shutil.copy2(ROOT/'native/ark_water/ark_water.cpp',lib/'ark_water.cpp')
files=[project/'scripts/adapters/ark_analytic_water.gd',project/'benchmark.gd',lib/'libark_water.so',lib/'ark_water.cpp']
manifest={str(f.relative_to(out)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
(out/'source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
env=os.environ.copy()
for key,name in [('HOME','home'),('XDG_CACHE_HOME','cache'),('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config')]:
 d=out/name;d.mkdir(exist_ok=True);env[key]=str(d)
env['ARK_WATER_EXTENSION']=str(lib/'ark_water.gdextension');env['ARK_BENCHMARK_JSON']=str(out/'results.json')
with (out/'run.log').open('w') as log:
 result=subprocess.run([str(ROOT/'tools/godot/4.7.1-linux/Godot_v4.7.1-stable_linux.x86_64'),'--headless','--path',str(project),'--script',str(project/'benchmark.gd')],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=600)
text=(out/'run.log').read_text()
print(text)
if result.returncode != 0 or any(marker in text for marker in ('SCRIPT ERROR:', 'ERROR:', 'Assertion failed')):
 raise SystemExit(result.returncode or 1)
if 'NATIVE_WRAPPER_BENCHMARK_FINISHED parity=true rows=48' not in text:
 raise SystemExit('Missing benchmark completion marker')
report=json.loads((out/'results.json').read_text())
if not report['parity_all_ok'] or len(report['rows']) != 48:
 raise SystemExit('Parity/row-count failure')
if any(len(row['samples_ms']) != 30 or not row['parity_to_gdscript']['ok'] for row in report['rows']):
 raise SystemExit('Incomplete measured row or parity failure')
current={str(f.relative_to(out)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
if current != manifest:
 raise SystemExit('Frozen measured source changed during run')
if hashlib.sha256(adapter.read_bytes()).hexdigest()!=manifest['frozen-project/scripts/adapters/ark_analytic_water.gd']:
 raise SystemExit('Production adapter diverged from measured snapshot')
print('STRICT_BENCHMARK_VALIDATION_PASS')
