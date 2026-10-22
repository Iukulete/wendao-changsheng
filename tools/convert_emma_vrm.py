"""Convert the supplied VRM 0 avatar to an embedded Godot-compatible GLB.

Geometry, skins and textures are preserved. Godot uses glTF materials; VRM
spring bones, expressions and MToon-specific shading are not implemented.
The original VRM stays outside the project and is never modified.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct


def convert(source: Path, destination: Path) -> None:
    raw = source.read_bytes()
    magic, version, length = struct.unpack_from('<III', raw)
    if (magic, version, length) != (0x46546C67, 2, len(raw)):
        raise ValueError('Expected a complete VRM/glTF 2 binary')
    size, kind = struct.unpack_from('<II', raw, 12)
    if kind != 0x4E4F534A:
        raise ValueError('Missing glTF JSON chunk')
    document = json.loads(raw[20:20 + size])
    vrm = document.get('extensions', {}).pop('VRM')
    for key in ('extensionsUsed', 'extensionsRequired'):
        if key in document:
            document[key] = [name for name in document[key] if name != 'VRM']
            if not document[key]:
                del document[key]
    if not document.get('extensions'):
        document.pop('extensions', None)
    # Keep author and permission metadata with the derived asset.
    document.setdefault('asset', {}).setdefault('extras', {})['source_vrm_meta'] = vrm['meta']
    encoded = json.dumps(document, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
    encoded += b' ' * (-len(encoded) % 4)
    remainder = raw[20 + size:]
    result = struct.pack('<III', magic, version, 20 + len(encoded) + len(remainder))
    result += struct.pack('<II', len(encoded), kind) + encoded + remainder
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(result)
    print(f'Converted {source.name}: {len(result)} bytes; source SHA256 {hashlib.sha256(raw).hexdigest()}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    convert(args.source, args.destination)
