"""Pinned Lucide subset: exact identity, attribution, adaptation and packed deps."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import re

REVISION = "7faf87628a1ad6175975bc595344337ce14a7db4"
LICENSE_HASH = "b495047bd93a9b06913511076f504daba17d5bbeb3e0650f3bb53a4220329c57"
ICONS = {
    "hammer.svg": (478, "27360834be385f0081ca357b95f9a78c28f344a4e3f99dd8e0fdb6f39bd2b243", "db75caf31bd080726be0c2dab09372498b999cbdcf10c756f44636831f9529f5"),
    "house.svg": (378, "acde7e4d79864b7e347e592054a802b1c4f89e33e4987f4dfdb53da340b682da", "28216c479005731ef5e382e7d8627eda2b129b019eb1f3d9de9f5915576d448e"),
    "palette.svg": (546, "cc1d74035ec655083ba184cdcbbd065f6ff4c58081c9c7094713bd2669371796", "8e7d3fde990cffd10469ba351f27c50202b057a9bb9af5626322e53fd3abc78c"),
    "triangle-alert.svg": (340, "aae55b7164593268d234bc04336c1572f80e0852bc6443d0912ee8a0359b8384", "4866f38b8560d410f21e3226413e0b77997b6dfbb6931fadfe0a0d5aef9ffeb4"),
}
UI_FILES = frozenset({*ICONS, "Lucide-LICENSE.txt", "asset_manifest.json"})
UI_IMPORTED = {name: ".godot/imported/" + name + "-" + hashlib.md5(("res://art/ui_icons/"+name).encode(), usedforsecurity=False).hexdigest() + ".ctex" for name in ICONS}

def expected_manifest() -> dict:
    return {"provider": "Lucide Icons and Contributors", "repository": "https://github.com/lucide-icons/lucide", "revision": REVISION,
            "license": "ISC; complete upstream license including Feather MIT notice retained", "license_file": "Lucide-LICENSE.txt",
            "adaptation": "Only currentColor replaced by #ffffff for Godot texture tinting; paths/viewBox/strokes otherwise unchanged.",
            "files": [{"name": name, "bytes": size, "sha256": digest, "source_sha256": original,
                       "source_url": f"https://raw.githubusercontent.com/lucide-icons/lucide/{REVISION}/icons/{name}"}
                      for name, (size, digest, original) in ICONS.items()]}

def verify_ui_manifest(data: bytes) -> None:
    if json.loads(data) != expected_manifest():
        raise RuntimeError("UI icon provenance/revision/adaptation mismatch")

def verify_ui_import(data: bytes, name: str) -> str:
    text = data.decode("utf-8").replace("\r\n", "\n").rstrip("\0")
    if re.findall(r'(?m)^path="([^"\n]+)"$', text) != ["res://" + UI_IMPORTED[name]]:
        raise RuntimeError("UI icon import escapes pinned texture: " + name)
    return UI_IMPORTED[name]

def verify_ui_assets(root: Path) -> None:
    directory = root / "godot/art/ui_icons"
    expected = set(UI_FILES) | {name + ".import" for name in ICONS}
    if {p.name for p in directory.iterdir()} != expected:
        raise RuntimeError("UI icon source set is not exact")
    verify_ui_manifest((directory / "asset_manifest.json").read_bytes())
    if hashlib.sha256((directory / "Lucide-LICENSE.txt").read_bytes()).hexdigest() != LICENSE_HASH:
        raise RuntimeError("UI icon upstream license changed")
    for name, (size, digest, _) in ICONS.items():
        data = (directory/name).read_bytes()
        if len(data) != size or hashlib.sha256(data).hexdigest() != digest:
            raise RuntimeError("UI icon source identity mismatch: " + name)
        verify_ui_import((directory/(name+".import")).read_bytes(), name)

def verify_ui_pack(files: dict[str, bytes]) -> None:
    prefix = "art/ui_icons/"
    verify_ui_manifest(files.get(prefix+"asset_manifest.json", b"{}"))
    if hashlib.sha256(files.get(prefix+"Lucide-LICENSE.txt", b"")).hexdigest() != LICENSE_HASH:
        raise RuntimeError("PCK omits UI icon license")
    for name, (size, digest, _) in ICONS.items():
        path = prefix+name
        if path in files:
            if len(files[path]) != size or hashlib.sha256(files[path]).hexdigest() != digest:
                raise RuntimeError("PCK UI icon identity mismatch")
        elif path+".import" not in files:
            raise RuntimeError("PCK omits UI icon: " + name)
        if path+".import" in files and not files.get(verify_ui_import(files[path+".import"], name)):
            raise RuntimeError("PCK omits imported UI icon: " + name)
