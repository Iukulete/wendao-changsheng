#!/usr/bin/env python3
"""Build optional native water using only the installed pinned Godot and compiler."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--godot', type=Path, default=ROOT / 'tools/godot/4.7.1-linux/Godot_v4.7.1-stable_linux.x86_64')
p.add_argument('--out', type=Path, default=ROOT / '.tmp/native-round/build')
p.add_argument('--cxx', default=os.environ.get('CXX', 'cl' if os.name == 'nt' else 'g++'))
a = p.parse_args()
out, godot = a.out.resolve(), a.godot.resolve()
if platform.machine().lower() not in ('x86_64', 'amd64'):
    p.error('Only x86_64 standard ABI is supported.')
compiler = shutil.which(a.cxx)
if not compiler:
    p.error('Compiler unavailable; nothing installed: ' + a.cxx)
out.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
for key, directory in [('HOME','home'),('XDG_CACHE_HOME','cache'),('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config')]:
    folder = out / directory
    folder.mkdir(exist_ok=True)
    env[key] = str(folder)
version = subprocess.check_output([str(godot),'--version'], env=env, text=True).strip()
if version != '4.7.1.stable.official.a13da4feb':
    p.error('Exact official standard Godot 4.7.1 required: ' + version)
for flag in ['--dump-gdextension-interface','--dump-extension-api']:
    subprocess.run([str(godot),'--headless',flag], cwd=out, env=env, check=True)
api = json.loads((out/'extension_api.json').read_text())
sizes = next(r['sizes'] for r in api['builtin_class_sizes'] if r['build_configuration']=='float_64')
used = {r['name']:r['size'] for r in sizes if r['name'] in ('String','StringName','Variant','PackedFloat64Array')}
if used != {'String':8,'StringName':8,'Variant':24,'PackedFloat64Array':16}:
    p.error('Unexpected ABI sizes: '+str(used))
methods = {m['name']:m['hash'] for c in api['builtin_classes'] if c['name']=='PackedFloat64Array' for m in c['methods']}
notification = next(m['hash'] for c in api['classes'] if c['name']=='Object' for m in c['methods'] if m['name']=='notification')
if methods['size'] != 3173160232 or methods['resize'] != 848867239 or notification != 4023243586:
    p.error('Unexpected ABI method hashes')
(out/'ark_abi_sizes.h').write_text('// Generated from the pinned engine ABI JSON.\n#define ARK_ABI_STORAGE_BYTES 24\n')
source = Path(__file__).with_name('ark_water.cpp')
with tempfile.TemporaryDirectory(prefix='.ark-build-',dir=out) as temporary:
    stage = Path(temporary)
    if os.name == 'nt':
        library = out/'ark_water.dll'
        if Path(compiler).stem.lower() == 'cl':
            command = [compiler,'/nologo','/std:c++17','/O2','/EHsc','/LD','/W4','/I'+str(out),str(source),'/Fe:'+str(stage/library.name),'/Fo:'+str(stage/'ark_water.obj')]
        else:
            command = [compiler,'-std=c++17','-O2','-shared','-pthread','-Wall','-Wextra','-Werror','-I',str(out),str(source),'-o',str(stage/library.name)]
        key = 'windows.x86_64'
    elif platform.system() == 'Linux':
        library = out/'libark_water.so'
        command = [compiler,'-std=c++17','-O2','-fPIC','-fvisibility=hidden','-shared','-pthread','-Wall','-Wextra','-Werror','-I',str(out),str(source),'-o',str(stage/library.name)]
        key = 'linux.x86_64'
    else:
        p.error('Only Linux/Windows build recipes exist.')
    subprocess.run(command,cwd=stage,check=True)
    # Never truncate a library mapped by a running process. Windows locked-DLL
    # replacement may fail; leave old DLL intact and propagate the error.
    os.replace(stage/library.name,library)
    descriptor = out/'ark_water.gdextension'
    (stage/descriptor.name).write_text('[configuration]\nentry_symbol="ark_water_library_init"\ncompatibility_minimum="4.7"\nreloadable=false\n[libraries]\n'+key+'="./'+library.name+'"\n')
    os.replace(stage/descriptor.name,descriptor)
    manifest={'godot':version,'compiler':compiler,'platform':platform.platform(),'command':command,'sha256':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in [source,out/'gdextension_interface.h',library,descriptor]}}
    (stage/'build-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    os.replace(stage/'build-manifest.json',out/'build-manifest.json')
print('ARK_WATER_EXTENSION='+str(descriptor))
