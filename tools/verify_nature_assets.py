"""Strict source/import/export boundary for four reviewed free CC0 nature models."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import re

MANIFEST_SHA = 'b2c228529f33d825091e5f7f9ce3d5b75ed745b216682e24517f1d8f251aa459'
MODELS = frozenset({'Pine_1', 'Bush_Common', 'Fern_1', 'Rock_Medium_1'})
TEXTURES = frozenset({'Bark_NormalTree.png', 'Bark_NormalTree_Normal.png', 'Leaf_Pine_C.png', 'Leaves.png', 'Leaves_TwistedTree_C.png', 'Rocks_Diffuse.png'})
DOCUMENTS = frozenset({'asset_manifest.json', 'License_Standard.txt'})
FILES = TEXTURES | DOCUMENTS | {name + suffix for name in MODELS for suffix in ('.gltf', '.bin')}
RUNTIME = FILES - {name + '.bin' for name in MODELS}
IMPORTED = {
    name: '.godot/imported/' + name + '-' + hashlib.md5(('res://art/coast_nature/' + name).encode(), usedforsecurity=False).hexdigest() + ('.ctex' if name.endswith('.png') else '.scn')
    for name in TEXTURES | {name + '.gltf' for name in MODELS}
}

def manifest(data: bytes) -> dict:
    if hashlib.sha256(data).hexdigest() != MANIFEST_SHA:
        raise RuntimeError('Nature manifest differs from separately reviewed identity')
    document = json.loads(data)
    if document['license'] != 'CC0-1.0' or set(document['models']) != MODELS:
        raise RuntimeError('Nature provenance/license mismatch')
    return document

def verify_nature_assets(root: Path) -> None:
    directory = root / 'godot/art/coast_nature'
    expected = FILES | {name + '.import' for name in IMPORTED}
    actual = {p.relative_to(directory).as_posix() for p in directory.rglob('*') if p.is_file()}
    if actual != expected or directory.is_symlink() or any(p.is_symlink() for p in directory.rglob('*')):
        raise RuntimeError('Nature source boundary is not the exact reviewed dependency closure')
    document = manifest((directory / 'asset_manifest.json').read_bytes())
    for entry in document['files']:
        data = (directory / entry['file']).read_bytes()
        if len(data) != entry['bytes'] or hashlib.sha256(data).hexdigest() != entry['sha256']:
            raise RuntimeError('Nature source identity mismatch: ' + entry['file'])
    for model in MODELS:
        data = json.loads((directory / (model + '.gltf')).read_text())
        deps = [item['uri'] for key in ('buffers', 'images') for item in data.get(key, []) if 'uri' in item]
        if not set(deps) <= FILES or any('/' in name or '\\' in name for name in deps):
            raise RuntimeError('Nature model dependency escape')
    for name, target in IMPORTED.items():
        imports = (directory / (name + '.import')).read_text()
        required = {'path': '"res://' + target + '"', 'source_file': '"res://art/coast_nature/' + name + '"'}
        if name in TEXTURES:
            required.update({'mipmaps/generate':'true', 'process/size_limit':'1024', 'detect_3d/compress_to':'0'})
        else:
            required.update({'import_script/path':'""', 'materials/extract':'0'})
        for key, value in required.items():
            if re.findall(r'(?m)^' + re.escape(key) + '=(.*)$', imports) != [value]:
                raise RuntimeError('Nature import policy mismatch: ' + name + ':' + key)

def verify_nature_pack(files: dict[str, bytes]) -> None:
    document = manifest(files.get('art/coast_nature/asset_manifest.json', b''))
    for entry in document['files']:
        path = 'art/coast_nature/' + entry['file']
        if entry['file'] in DOCUMENTS or path in files:
            payload = files.get(path, b'')
            if hashlib.sha256(payload).hexdigest() != entry['sha256']:
                raise RuntimeError('Packed nature identity mismatch: ' + path)
    for name, target in IMPORTED.items():
        path = 'art/coast_nature/' + name + '.import'
        if not files.get(target) or path not in files:
            raise RuntimeError('Missing imported nature payload: ' + name)
        text = files[path].decode('utf-8').replace('\r\n','\n').rstrip('\0')
        if re.findall(r'(?m)^path="([^"\n]+)"$',text) != ['res://' + target]:
            raise RuntimeError('Packed nature import escape: ' + name)
