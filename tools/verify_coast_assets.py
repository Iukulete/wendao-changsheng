#!/usr/bin/env python3
"""Exact reviewed coastal source/import/export boundary; no asset downloads."""
from __future__ import annotations
import hashlib
from pathlib import Path
import re

COAST_TEXTURES = {'rock_boulder_dry/rock_boulder_dry_diff_1k.jpg': (859211, '20f653a42fb24f42aa40641663070d578678da49af18cc1049dbdd4ed8679f3c'), 'rock_boulder_dry/rock_boulder_dry_nor_gl_1k.jpg': (802497, '5915fea28a97357c78a04fb31c2516f1f7ed1b3a9cef4ae25aa93e4655e6c595'), 'rock_boulder_dry/rock_boulder_dry_rough_1k.jpg': (668127, 'cc5229dd6bbdc4e817cb647e60242224b8e4f0237473ac018861ea243f2e8130'), 'sand_03/sand_03_diff_1k.jpg': (703132, 'e72144f9d7b81bdb7bbdb34222b53431738dcef79346dd89412d2abd541e4d30'), 'sand_03/sand_03_nor_gl_1k.jpg': (884706, '1bde5f49ea78f94bcad73592696bf3949711c4ac197133b710c0c8521b6e996b'), 'sand_03/sand_03_rough_1k.jpg': (291218, '5c9ead290a94913cfa2d0452a576ba527b50301fe208f2ffc4861e42a8fea45b'), 'sparse_grass/sparse_grass_diff_1k.jpg': (955945, 'ae94f2b34597b9108eefd88217f55eccaec6d6b382e858a478ee92df90e66617'), 'sparse_grass/sparse_grass_nor_gl_1k.jpg': (1440314, '1c840a24807346ddaaf94a5057aee4078fcec3a4cd84bfe45da7d3b480ef460b'), 'sparse_grass/sparse_grass_rough_1k.jpg': (463340, '9ebe6d03a9551c17d1802835c92c1442acb8f5d38d4874ee8c37770f11c4bed1')}
COAST_DOCUMENTS = {'LICENSE.txt': (314, '70c7e4de4e46536fefffa8245a5c1b40bb8fd6fcedde95ed82ad631f9615de91'), 'asset_manifest.json': (2086, '0f8fcc09391890c4dacdb9b6f5a99e8608b0e45b897bf38700258beea8cf03be'), 'provenance/README.md': (1579, '9e39a5717febee4e99a2a96ad170c2fe71a29c45da43f5d5e17c9b935f34c83f'), 'provenance/download-log.json': (5323, '23dbe49b101d203f4be7dcb1958ce88636de8056057f385c351c76d9c493b0da'), 'provenance/image-inspection.json': (3125, 'd3ad31841d2efa33f2154f164f934136485e9e4147854762ada3c938aba57977'), 'provenance/manifest.json': (10331, '8f54f8fb6d9ad1dc66b5ee4ed6caa7a0c8ddd2291dbfabe55000763e5d248e59'), 'provenance/metadata-fetch-log.json': (700, '58f51037122b5bf04ed70b8f4afa9900238c763d3ed260eaa31ed7fc03e6f117'), 'provenance/research-evidence.json': (1355, '2ecdb53ff02fde23d48277250e9f38bb0b5955b4cf3f7b16788cc15bd98aa739'), 'provenance/rock_boulder_dry.files.json': (34137, 'c413c5c8ceeed4e92f9456a8785f06c96123e21dcd8da0d1b782c50fb4432fe5'), 'provenance/sand_03.files.json': (24188, 'd75439136556011e5d09f3e39fd8041b79064af1abb3426e033e4b1a309e776f'), 'provenance/sparse_grass.files.json': (29490, '385455d28cb04effb36e7775527b88b1e637b3dbf228b0cf37474aa4ae05b54b')}
COAST_IMPORTED = {name: ".godot/imported/"+Path(name).name+"-"+hashlib.md5(("res://art/coast/"+name).encode(),usedforsecurity=False).hexdigest()+".ctex" for name in COAST_TEXTURES}


def _exact(data: bytes, name: str, identity: tuple[int,str]) -> None:
    if len(data) != identity[0] or hashlib.sha256(data).hexdigest() != identity[1]:
        raise RuntimeError("Reviewed coast bytes changed: "+name)


def verify_coast_import(data: bytes, name: str, *, packed: bool=False) -> str:
    source="res://art/coast/"+name
    target="res://"+COAST_IMPORTED[name]
    text=data.decode("utf-8").replace("\r\n","\n").rstrip("\0")
    required={"importer":'"texture"',"type":'"CompressedTexture2D"',"path":'"'+target+'"'}
    if not packed:
        required.update({"source_file":'"'+source+'"',"dest_files":'["'+target+'"]',"compress/mode":"0","compress/normal_map":"0","mipmaps/generate":"true","process/normal_map_invert_y":"false","process/size_limit":"0","detect_3d/compress_to":"0"})
    for key,value in required.items():
        if re.findall(r"(?m)^"+re.escape(key)+r"=(.*)$",text)!=[value]:
            raise RuntimeError("Coast import changed: "+name+"/"+key)
    refs=set(re.findall(r'"(res://[^"\n]+)"',text))
    if refs != ({target} if packed else {source,target}):
        raise RuntimeError("Coast import escapes reviewed resources: "+name)
    return COAST_IMPORTED[name]


def verify_coast_assets(root: Path) -> None:
    directory=root/"godot/art/coast"
    expected=set(COAST_TEXTURES)|set(COAST_DOCUMENTS)|{name+".import" for name in COAST_TEXTURES}
    actual={p.relative_to(directory).as_posix() for p in directory.rglob("*") if p.is_file()}
    if directory.is_symlink() or any(p.is_symlink() for p in directory.rglob("*")) or actual!=expected:
        raise RuntimeError(f"Coast asset boundary changed: missing={expected-actual},extra={actual-expected}")
    for name,identity in {**COAST_TEXTURES,**COAST_DOCUMENTS}.items():
        _exact((directory/name).read_bytes(),name,identity)
    for name in COAST_TEXTURES:
        verify_coast_import((directory/(name+".import")).read_bytes(),name)


def verify_coast_pack(files: dict[str,bytes]) -> None:
    for name,identity in COAST_DOCUMENTS.items():
        _exact(files.get("art/coast/"+name,b""),name,identity)
    for name,identity in COAST_TEXTURES.items():
        relative="art/coast/"+name
        if relative in files:
            _exact(files[relative],name,identity)
        if relative+".import" not in files:
            raise RuntimeError("PCK omits coast import: "+relative)
        target=verify_coast_import(files[relative+".import"],name,packed=True)
        if not files.get(target):
            raise RuntimeError("PCK omits actual imported coast map: "+target)
