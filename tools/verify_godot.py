#!/usr/bin/env python3
"""Run the full Godot verification pipeline on Windows or a cloud POSIX host.

Uses the PowerShell runner's regression list as the single source of truth.
Provide a verified Godot 4.7.1 standard binary with --godot; never downloads or
silently substitutes another engine version. Logs/caches remain in the repo.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
ERROR_PATTERN = re.compile(r"(?m)^\s*(?:SCRIPT ERROR|ERROR):")
VERSION_PATTERN = re.compile(r"^4\.7\.1\.stable\.official\.")


def regression_scripts() -> list[str]:
    source = (ROOT / "tools/verify_godot.ps1").read_text(encoding="utf-8")
    match = re.search(r"\$testScripts\s*=\s*@\((.*?)\n\)", source, re.S)
    if match is None:
        raise RuntimeError("Cannot read the canonical PowerShell regression list")
    scripts = re.findall(r'"(res://tests/[^"\n]+\.gd)"', match.group(1))
    if not scripts or len(scripts) != len(set(scripts)):
        raise RuntimeError("Regression list is empty or contains duplicates")
    return scripts


def run(command: list[str], name: str, log_dir: Path, env: dict[str, str],
        timeout: int, marker: str | None = None) -> str:
    print(f"Running {name}...", flush=True)
    try:
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, encoding="utf-8",
                                errors="replace", timeout=timeout)
    except subprocess.TimeoutExpired as error:
        output = error.stdout or b""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        (log_dir / f"{name}.log").write_text(output, encoding="utf-8")
        raise RuntimeError(f"{name} exceeded {timeout}s; process terminated") from error
    output = result.stdout
    (log_dir / f"{name}.log").write_text(output, encoding="utf-8")
    print(output, end="" if output.endswith("\n") else "\n", flush=True)
    if result.returncode or ERROR_PATTERN.search(output) or (marker and marker not in output):
        raise RuntimeError(f"{name} failed: exit={result.returncode}, expected marker={marker!r}; "
                           f"see {log_dir / (name + '.log')}")
    return output


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True, help="Verified official Godot 4.7.1 binary")
    parser.add_argument("--require-final-audio", action="store_true")
    parser.add_argument("--require-product-art", action="store_true")
    args = parser.parse_args()
    engine = args.godot.resolve()
    if not engine.is_file():
        raise RuntimeError(f"Godot binary not found: {engine}")
    # Keep Windows' owner-requested D: constraint, without inventing a D: drive
    # on POSIX cloud hosts. The GDScript guards also require isolated repo saves.
    if os.name == "nt" and ROOT.drive.lower() != "d:":
        raise RuntimeError("Windows project and validation data must remain on D:")
    temp = ROOT / ".tmp/godot-verify"
    logs = temp / "logs"
    logs.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.update(TEMP=str(temp), TMP=str(temp), TMPDIR=str(temp),
               XDG_CACHE_HOME=str(temp / "cache"), XDG_CONFIG_HOME=str(temp / "config"),
               XDG_DATA_HOME=str(temp / "data"), PYTHONUTF8="1")
    for directory in ("cache", "config", "data"):
        (temp / directory).mkdir(exist_ok=True)
    version = run([str(engine), "--version"], "version", logs, env, 30).strip()
    if not VERSION_PATTERN.match(version):
        raise RuntimeError(f"Godot version drift detected: {version}")
    checks = [
        ("verify_migration_surface.py", [], "MIGRATION_SURFACE_OK:"),
        ("verify_chronicle_content.py", [], None),
        ("verify_godot_art.py", ["--release"] if args.require_product_art else [], None),
        ("verify_event_paths.py", [], None),
        ("verify_audio_assets.py", ["--require-final"] if args.require_final_audio else [], None),
    ]
    for script, extra, marker in checks:
        run([sys.executable, "-X", "utf8", str(ROOT / "tools" / script), *extra],
            Path(script).stem, logs, env, 600, marker)
    common = [str(engine), "--headless", "--audio-driver", "Dummy", "--path", str(ROOT / "godot")]
    run([*common, "--import"], "import", logs, env, 1200)
    run([*common, "--quit-after", "5"], "main_smoke", logs, env, 120)
    scripts = regression_scripts()
    for script in scripts:
        name = Path(script).stem
        frames = 30000 if name == "ark_world_travel_test" else 10000 if name == "ark_mooring_test" else 600
        # Frame caps are identical to the canonical runner; wall-time caps catch
        # assertions/hangs that can otherwise leave SceneTree tests running.
        timeout = 900 if frames > 600 else 180
        run([*common, "--quit-after", str(frames), "--script", script], name,
            logs, env, timeout, name.upper() + "_OK:")
    print(f"GODOT_VALIDATION_OK: {version}; {len(scripts)} regressions; logs: {logs}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"GODOT_VALIDATION_FAILED: {error}", file=sys.stderr)
        raise SystemExit(2) from error
