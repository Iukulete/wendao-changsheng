#!/usr/bin/env python3
"""Verify the template EXE's native preflight without editor-only --script."""
from __future__ import annotations
import argparse
import os
from pathlib import Path
from verify_godot import ROOT, run
from verify_native_simulation import verify_bundle

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--executable", type=Path, required=True)
    a = parser.parse_args()
    exe = a.executable.resolve(strict=True)
    verify_bundle(exe.parent / "native")
    temp = ROOT / ".tmp/native-release"
    temp.mkdir(parents=True, exist_ok=True)
    appdata = temp / "appdata"
    localdata = temp / "localappdata"
    appdata.mkdir(exist_ok=True)
    localdata.mkdir(exist_ok=True)
    env = {**os.environ, "TEMP": str(temp), "TMP": str(temp), "TMPDIR": str(temp),
           "APPDATA": str(appdata), "LOCALAPPDATA": str(localdata)}
    env.pop("ARK_SIMULATION_EXTENSION", None)
    output = run([str(exe), "--headless", "--audio-driver", "Dummy", "--log-file", str(temp / "native_release-engine.log"), "--quit-after", "5"],
                 "native_release", temp, env, 120, "ARK_SIMULATION_PREFLIGHT_OK:", cwd=exe.parent)
    if "ARK_MENU_READY_OK:" not in output:
        raise RuntimeError("Actual EXE menu did not initialize")
    print("ARK_NATIVE_RELEASE_OK: actual template EXE native preflight; default relative library path; gameplay separately verified by actual PCK scene smoke")
    return 0

if __name__ == "__main__": raise SystemExit(main())
