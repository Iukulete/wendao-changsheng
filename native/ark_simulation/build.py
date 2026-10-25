#!/usr/bin/env python3
"""Build the pinned, minimal Flecs simulation extension, entirely on D: on Windows."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
import sys

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).resolve().parent
PIN = "fb55f3c25660425cfe1bc4cf5e6bff8b3f18a9b8"

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--godot", type=Path, required=True)
    p.add_argument("--out", type=Path, default=ROOT / ".local/native/ark_simulation")
    local_bin = Path("D:/msys64/ucrt64/bin")
    p.add_argument("--cxx", default=os.environ.get("CXX", str(local_bin / "g++.exe") if os.name == "nt" and local_bin.is_dir() else "g++"))
    p.add_argument("--cc", default=os.environ.get("CC", str(local_bin / "gcc.exe") if os.name == "nt" and local_bin.is_dir() else "gcc"))
    a = p.parse_args()
    out, godot = a.out.resolve(), a.godot.resolve(strict=True)
    if platform.machine().lower() not in ("amd64", "x86_64"):
        p.error("Only standard x86_64 ABI is reviewed")
    if os.name == "nt" and (out.drive.lower() != "d:" or ROOT.drive.lower() != "d:"):
        p.error("Project, dependency and build data must stay on D:")
    cxx, cc = shutil.which(a.cxx), shutil.which(a.cc)
    if not cxx or not cc:
        p.error("GCC C/C++ compilers required; no environment is silently installed")
    out.mkdir(parents=True, exist_ok=True)
    env = {**os.environ, "TEMP": str(out), "TMP": str(out), "TMPDIR": str(out),
           "PATH": str(Path(cxx).parent) + os.pathsep + os.environ.get("PATH", "")}
    version = subprocess.check_output([str(godot), "--version"], env=env, text=True).strip()
    if version != "4.7.1.stable.official.a13da4feb":
        p.error("Exact official standard Godot 4.7.1 required: " + version)
    vendor = SOURCE / "third_party/flecs"
    sys.path.insert(0, str(ROOT / "tools"))
    from verify_native_simulation import verify_sources
    verify_sources(ROOT)
    provenance = json.loads((vendor / "manifest.json").read_text(encoding="utf-8"))
    if provenance["commit"] != PIN:
        p.error("Unexpected Flecs version")
    for name, expected in provenance["sha256"].items():
        if hashlib.sha256((vendor / name).read_bytes()).hexdigest() != expected:
            p.error("Flecs source/license checksum differs: " + name)
    with tempfile.TemporaryDirectory(prefix=".build-", dir=out) as temporary:
        stage = Path(temporary)
        for flag in ("--dump-gdextension-interface", "--dump-extension-api"):
            subprocess.run([str(godot), "--headless", "--log-file", str(stage / "engine.log"), flag], cwd=stage, env=env, check=True)
        api = json.loads((stage / "extension_api.json").read_text(encoding="utf-8"))
        sizes = next(r["sizes"] for r in api["builtin_class_sizes"] if r["build_configuration"] == "float_64")
        used = {r["name"]: r["size"] for r in sizes if r["name"] in ("String", "StringName", "Variant", "PackedFloat64Array")}
        if used != {"String": 8, "StringName": 8, "Variant": 24, "PackedFloat64Array": 16}:
            p.error("Unexpected Godot ABI sizes")
        methods = {m["name"]: m["hash"] for c in api["builtin_classes"] if c["name"] == "PackedFloat64Array" for m in c["methods"]}
        notification = next(m["hash"] for c in api["classes"] if c["name"] == "Object" for m in c["methods"] if m["name"] == "notification")
        if methods["size"] != 3173160232 or methods["resize"] != 848867239 or notification != 4023243586:
            p.error("Unexpected Godot method ABI")
        (stage / "ark_abi_sizes.h").write_text("#define ARK_ABI_STORAGE_BYTES 24\n", encoding="utf-8")
        windows = os.name == "nt"
        library_name = "ark_simulation.dll" if windows else "libark_simulation.so"
        defines = ["-DFLECS_CUSTOM_BUILD", "-DFLECS_SYSTEM", "-DFLECS_OS_API_IMPL"]
        common = ["-O2", "-DNDEBUG", *defines]
        c_command = [cc, "-std=c99", *common, "-c", str(vendor / "flecs.c"), "-o", str(stage / "flecs.o")]
        if not windows:
            c_command.append("-fPIC")
        command = [cxx, "-std=c++17", *common, "-shared", "-pthread", "-Wall", "-Wextra", "-Werror",
                   "-I", str(stage), "-I", str(SOURCE), str(SOURCE / "ark_simulation.cpp"), str(stage / "flecs.o"), "-o", str(stage / library_name)]
        command.extend(["-static-libgcc", "-static-libstdc++", "-Wl,-Bstatic", "-lwinpthread", "-Wl,-Bdynamic", "-lws2_32", "-ldbghelp"] if windows else ["-fPIC", "-fvisibility=hidden"])
        for cmd in (c_command, command):
            subprocess.run(cmd, cwd=stage, env=env, check=True)
        descriptor = stage / "ark_simulation.gdextension"
        descriptor.write_text('[configuration]\nentry_symbol="ark_simulation_library_init"\ncompatibility_minimum="4.7"\nreloadable=false\n[libraries]\n' + ("windows.x86_64" if windows else "linux.x86_64") + '="./' + library_name + '"\n', encoding="utf-8")
        manifest = {"godot": version, "flecs_commit": PIN, "platform": platform.system(), "architecture": "x86_64", "commands": [c_command, command],
                    "sha256": {f.name: hashlib.sha256(f.read_bytes()).hexdigest() for f in (SOURCE / "ark_simulation.cpp", stage / "gdextension_interface.h", stage / library_name, descriptor)}}
        (stage / "build-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        # Never truncate a loaded DLL. Locked-file failures leave old binary intact.
        for name in (library_name, descriptor.name, "build-manifest.json"):
            os.replace(stage / name, out / name)
    shutil.copyfile(vendor / "LICENSE", out / "Flecs-LICENSE.txt")
    shutil.copyfile(vendor / "manifest.json", out / "Flecs-manifest.json")
    print("ARK_SIMULATION_EXTENSION=" + str(out / "ark_simulation.gdextension"), flush=True)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
