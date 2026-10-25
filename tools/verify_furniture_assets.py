"""Exact reviewed CC0 furniture closure; no plugins, paid extras or self-approval."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import re
import struct

REVISION = '96d5930a8dbdb363409bbc2d3341718b00e17c9c'
MANIFEST_SHA = 'a4f3a22e8430bb64df27ec2dcde40b2f8ea9dd3f483da00ec936f35bce995a11'
MODELS = frozenset({'bed_single_B','cabinet_small','book_set'})
TRIANGLES = {'bed_single_B':534,'cabinet_small':322,'book_set':196}
DOCUMENTS = frozenset({'asset_manifest.json','LICENSE.txt'})
IDENTITIES = {
    'bed_single_B.bin':(25348,'a1b26c1848d104381b311cae4dbd4b6d574a3d79e6c9fe88087405f3a99bb918'),
    'bed_single_B.gltf':(3009,'f702283107f35fe400aa55775baa9515cbd9adaf9e2003b3441fd5cbedb9a07c'),
    'book_set.bin':(11576,'3aa3fcc774b46c7ffe2b1a3109bf006749163bbb392cfca930b34bfba4b67853'),
    'book_set.gltf':(3051,'437bfaba3f3413a0b825627a1cb905765a191f4708be51838c9b60c8132cbe61'),
    'cabinet_small.bin':(19468,'b29dfd659c0b0f7b5a97377e42b52ebcd8245780bcbf024b383f45ec0e59641d'),
    'cabinet_small.gltf':(3001,'06ce4ee6232ee68e791927e838bb8e77c11391b7de9ba3141374626a910772e5'),
    'furniturebits_texture.png':(15605,'de62db37a80d1801c3d9eb674890ae04b04469e0c149481a51fa250562c628dc'),
    'LICENSE.txt':(827,'cd675f2adc31eb5fedaedc1072d8ddc27b917f523682f0561837c03dc56393cb')}
FILES = frozenset(IDENTITIES)|{'asset_manifest.json'}
RUNTIME = FILES-{name+'.bin' for name in MODELS}
IMPORTED = {name:'.godot/imported/'+name+'-'+hashlib.md5(('res://art/cabin_furniture/'+name).encode(),usedforsecurity=False).hexdigest()+('.ctex' if name.endswith('.png') else '.scn') for name in {'furniturebits_texture.png',*(name+'.gltf' for name in MODELS)}}

def manifest(data: bytes) -> dict:
    if hashlib.sha256(data).hexdigest()!=MANIFEST_SHA: raise RuntimeError('Furniture manifest differs from reviewed identity')
    document = json.loads(data)
    if document.get('revision')!=REVISION or document.get('license')!='CC0-1.0' or set(document.get('models',[]))!=MODELS: raise RuntimeError('Furniture source/license differs')
    entries = document.get('files',[])
    if len(entries)!=len(IDENTITIES) or {entry['file'] for entry in entries}!=set(IDENTITIES): raise RuntimeError('Furniture manifest closure differs')
    for entry in entries:
        if (entry['bytes'],entry['sha256'])!=IDENTITIES[entry['file']]: raise RuntimeError('Furniture manifest cannot self-authorize source bytes')
    return document

def verify_furniture_assets(root: Path) -> None:
    directory = root/'godot/art/cabin_furniture'
    expected = FILES|{name+'.import' for name in IMPORTED}
    if directory.is_symlink() or any(path.is_symlink() for path in directory.rglob('*')) or {path.relative_to(directory).as_posix() for path in directory.rglob('*') if path.is_file()}!=expected: raise RuntimeError('Furniture source boundary differs')
    manifest((directory/'asset_manifest.json').read_bytes())
    for name,(size,sha) in IDENTITIES.items():
        data = (directory/name).read_bytes()
        if len(data)!=size or hashlib.sha256(data).hexdigest()!=sha: raise RuntimeError('Furniture source identity differs: '+name)
    if struct.unpack_from('>II',(directory/'furniturebits_texture.png').read_bytes(),16)!=(1024,1024): raise RuntimeError('Furniture atlas size differs')
    for name in MODELS:
        model = json.loads((directory/(name+'.gltf')).read_bytes())
        if model.get('asset',{}).get('version')!='2.0' or model.get('animations') or model.get('skins') or model.get('extensionsUsed'): raise RuntimeError('Furniture must remain static standard glTF')
        dependencies = [row['uri'] for key in ('buffers','images') for row in model.get(key,[])]
        if set(dependencies)!={name+'.bin','furniturebits_texture.png'} or len(dependencies)!=2: raise RuntimeError('Furniture dependency escape')
        primitive = model['meshes'][0]['primitives'][0]
        if model['accessors'][primitive['indices']]['count']!=TRIANGLES[name]*3: raise RuntimeError('Furniture triangle budget differs')
    for name,target in IMPORTED.items():
        source = (directory/(name+'.import')).read_text(encoding='utf-8')
        required = {'path':'"res://'+target+'"','source_file':'"res://art/cabin_furniture/'+name+'"'}
        required.update({'mipmaps/generate':'true','process/size_limit':'1024','compress/mode':'0','detect_3d/compress_to':'0'} if name.endswith('.png') else {'import_script/path':'""','materials/extract':'0'})
        for key,value in required.items():
            if re.findall(r'(?m)^'+re.escape(key)+'=(.*)$',source)!=[value]: raise RuntimeError('Furniture import policy differs: '+name+':'+key)

def verify_furniture_pack(files: dict[str,bytes]) -> None:
    manifest(files.get('art/cabin_furniture/asset_manifest.json',b''))
    for name,(size,sha) in IDENTITIES.items():
        path = 'art/cabin_furniture/'+name
        if name in DOCUMENTS or path in files:
            payload = files.get(path,b'')
            if len(payload)!=size or hashlib.sha256(payload).hexdigest()!=sha: raise RuntimeError('Packed furniture source identity differs: '+name)
    for name,target in IMPORTED.items():
        sidecar = files.get('art/cabin_furniture/'+name+'.import',b'')
        if not files.get(target) or not sidecar: raise RuntimeError('Missing imported furniture: '+name)
        text = sidecar.decode('utf-8').replace('\r\n','\n').rstrip('\0')
        if re.findall(r'(?m)^path="([^"\n]+)"$',text)!=['res://'+target]: raise RuntimeError('Packed furniture import escape: '+name)
