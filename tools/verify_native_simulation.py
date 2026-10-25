#!/usr/bin/env python3
"""Fail-closed provenance and external native simulation bundle validation."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[1]
PIN = "fb55f3c25660425cfe1bc4cf5e6bff8b3f18a9b8"
IDENTITIES = {
    "flecs.c": "6005392eb13c0f3c7abdecb2f85271e50934f63919afebf0bbe85f6dfc7320d6",
    "flecs.h": "526036a5a41678e2a43a3cb835e9eaa70fd1993868b1978950c0d275752f69b1",
    "LICENSE": "5f89f3edd5d1e458cd48509818e23b57d85869f7d57d0ebe31bcfd3a73e5dd60",
}

def verify_sources(root: Path = ROOT) -> None:
    directory = root / "native/ark_simulation/third_party/flecs"
    if {p.name for p in directory.iterdir()} != {*IDENTITIES, "manifest.json"}:
        raise RuntimeError("Unexpected Flecs vendor file set")
    manifest = json.loads((directory / "manifest.json").read_text(encoding="utf-8"))
    if manifest.get("commit") != PIN or manifest.get("version") != "4.1.6" or manifest.get("license") != "MIT" or manifest.get("sha256") != IDENTITIES:
        raise RuntimeError("Flecs manifest cannot authorize a new version or license")
    for name, expected in IDENTITIES.items():
        if hashlib.sha256((directory / name).read_bytes()).hexdigest() != expected:
            raise RuntimeError("Flecs source/license identity differs: " + name)

def pe_dependencies(data: bytes) -> set[str]:
    """Read imports without loading an untrusted DLL or depending on dumpbin."""
    if data[:2] != b"MZ": raise RuntimeError("Native library is not PE")
    pe = struct.unpack_from("<I", data, 0x3c)[0]
    if data[pe:pe+4] != b"PE\0\0" or struct.unpack_from("<H", data, pe+4)[0] != 0x8664:
        raise RuntimeError("Native library must be Windows x86_64")
    sections = struct.unpack_from("<H", data, pe+6)[0]
    optional_size = struct.unpack_from("<H", data, pe+20)[0]
    opt = pe + 24
    if struct.unpack_from("<H", data, opt)[0] != 0x20b:
        raise RuntimeError("Native library must use PE32+")
    table = opt + optional_size
    def offset(rva: int) -> int:
        for i in range(sections):
            size, va, raw_size, raw = struct.unpack_from("<IIII", data, table+i*40+8)
            if va <= rva < va+max(size, raw_size):
                result = raw+rva-va
                if result < len(data): return result
        raise RuntimeError("Invalid native PE RVA")
    import_rva, import_size = struct.unpack_from("<II", data, opt+120)
    if not import_rva or import_size < 20: raise RuntimeError("Missing native PE import directory")
    position = offset(import_rva)
    names: set[str] = set()
    for _ in range(min(import_size//20, 512)):
        record = struct.unpack_from("<IIIII", data, position)
        if not any(record): return names
        start = offset(record[3]); end = data.find(b"\0", start, start+256)
        if end < 0: raise RuntimeError("Invalid native PE import name")
        names.add(data[start:end].decode("ascii").lower()); position += 20
    raise RuntimeError("Unterminated native PE import directory")

def verify_bundle(directory: Path, root: Path = ROOT) -> None:
    verify_sources(root)
    manifest = json.loads((directory / "build-manifest.json").read_text(encoding="utf-8"))
    platform = manifest.get("platform")
    if platform not in ("Windows", "Linux") or manifest.get("architecture") != "x86_64" or manifest.get("godot") != "4.7.1.stable.official.a13da4feb" or manifest.get("flecs_commit") != PIN:
        raise RuntimeError("Native bundle platform/engine/Flecs identity differs")
    library = "ark_simulation.dll" if platform == "Windows" else "libark_simulation.so"
    expected = {library, "ark_simulation.gdextension", "build-manifest.json", "Flecs-LICENSE.txt", "Flecs-manifest.json"}
    children = list(directory.iterdir())
    if {p.name for p in children} != expected or any(not p.is_file() or p.is_symlink() for p in children):
        raise RuntimeError("Native bundle file set differs")
    hashes = manifest.get("sha256", {})
    if set(hashes) != {"ark_simulation.cpp", "gdextension_interface.h", library, "ark_simulation.gdextension"} or any(not re.fullmatch(r"[0-9a-f]{64}", str(v)) for v in hashes.values()):
        raise RuntimeError("Native build hash contract differs")
    for name in (library, "ark_simulation.gdextension"):
        if hashlib.sha256((directory / name).read_bytes()).hexdigest() != hashes[name]:
            raise RuntimeError("Native bundle checksum differs: " + name)
    source = root / "native/ark_simulation/ark_simulation.cpp"
    if hashlib.sha256(source.read_bytes()).hexdigest() != hashes["ark_simulation.cpp"]:
        raise RuntimeError("Native binary was built from a different simulation source")
    descriptor = '[configuration]\nentry_symbol="ark_simulation_library_init"\ncompatibility_minimum="4.7"\nreloadable=false\n[libraries]\n' + ("windows.x86_64" if platform == "Windows" else "linux.x86_64") + '="./' + library + '"\n'
    if (directory / "ark_simulation.gdextension").read_text(encoding="utf-8") != descriptor:
        raise RuntimeError("Native descriptor is not the reviewed relative-path contract")
    vendor = root / "native/ark_simulation/third_party/flecs"
    for bundled, original in (("Flecs-LICENSE.txt", "LICENSE"), ("Flecs-manifest.json", "manifest.json")):
        if (directory / bundled).read_bytes() != (vendor / original).read_bytes():
            raise RuntimeError("Native license/provenance differs")
    data = (directory / library).read_bytes()
    if platform == "Windows":
        imports = pe_dependencies(data)
        unexpected = {n for n in imports if n not in {"kernel32.dll", "msvcrt.dll", "ucrtbase.dll", "ws2_32.dll", "advapi32.dll", "dbghelp.dll"} and not n.startswith("api-ms-win-crt-")}
        if unexpected: raise RuntimeError("Native bundle has unshipped non-system DLL dependencies: " + str(sorted(unexpected)))
    elif data[:4] != b"\x7fELF" or data[4] != 2 or struct.unpack_from("<H", data, 18)[0] != 62:
        raise RuntimeError("Native bundle must be Linux x86_64 ELF")

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--bundle", type=Path)
    a = p.parse_args()
    verify_bundle(a.bundle.resolve()) if a.bundle else verify_sources()
    print("ARK_NATIVE_SIMULATION_BOUNDARY_OK: pinned MIT sources" + ("; external binary, relative descriptor, license and hashes" if a.bundle else ""))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
