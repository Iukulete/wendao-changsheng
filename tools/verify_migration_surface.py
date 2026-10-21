#!/usr/bin/env python3
"""Enforce the active 3D Ark runtime, regression, asset and release boundaries.

The retired card/six-era product is not an alternate entry point. Reusable
source material lives outside res:// and is never an export input.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
RUNTIME_SCRIPTS = frozenset({"main.gd", "ark_fixture_placement.gd", "ark_greybox.gd",
                             "ark_greybox_save.gd", "ark_landmass_builder.gd", "ark_world_chart.gd"})
SCENES = frozenset({"main.tscn", "ark_greybox.tscn"})
SHADERS = frozenset({"ark_ocean.gdshader"})
FONT_FILES = frozenset({"NotoSansSC-Variable.ttf", "NotoSerifSC-Variable.ttf",
                       "NotoSansSC-OFL.txt", "NotoSerifSC-OFL.txt", "font_manifest.json", "ark_ui_font.tres"})
NON_HEADLESS_TESTS = frozenset({"ark_test_paths.gd", "ark_render_capture_test.gd"})
REQUIRED_TESTS = frozenset({"ark_menu_integration_test.gd", "ark_test_paths_test.gd",
                           "ark_fixture_edit_test.gd", "ark_world_travel_test.gd",
                           "ark_save_integrity_audit_test.gd", "ark_chart_layout_audit_test.gd"})


def read(path: Path) -> str:
    if not path.is_file():
        raise RuntimeError(f"missing active surface file: {path}")
    return path.read_text(encoding="utf-8")


def canonical_tests(root: Path = ROOT) -> list[str]:
    source = read(root / "tools/verify_godot.ps1")
    match = re.search(r"\$testScripts\s*=\s*@\((.*?)\n\)", source, re.S)
    if match is None:
        raise RuntimeError("Cannot read the canonical PowerShell regression list")
    scripts = re.findall(r'"(res://tests/[^"\n]+\.gd)"', match.group(1))
    if not scripts or len(scripts) != len(set(scripts)):
        raise RuntimeError("Regression list is empty or contains duplicates")
    return scripts


def check_exact_files(directory: Path, expected: frozenset[str], sidecars: tuple[str, ...] = ()) -> None:
    actual = {str(path.relative_to(directory)) for path in directory.rglob("*") if path.is_file()}
    allowed = set(expected)
    allowed.update(name + suffix for name in expected for suffix in sidecars)
    missing, extra = expected - actual, actual - allowed
    if missing or extra:
        raise RuntimeError(f"Active boundary {directory.name}: missing={sorted(missing)}, unapproved={sorted(extra)}")


def verify_fonts(root: Path) -> None:
    font_dir = root / "godot/art/fonts"
    check_exact_files(font_dir, FONT_FILES, (".import",))
    manifest = json.loads(read(font_dir / "font_manifest.json"))
    entries = manifest.get("fonts", [])
    if {entry["file"] for entry in entries} != {name for name in FONT_FILES if name.endswith(".ttf")} or len(entries) != 2:
        raise RuntimeError("Font manifest must declare exactly both retained Noto fonts")
    for entry in entries:
        if entry["license"] != "OFL-1.1" or entry["license_file"] not in FONT_FILES:
            raise RuntimeError("Retained font license contract is invalid")
        if hashlib.sha256((font_dir / entry["file"]).read_bytes()).hexdigest() != entry["sha256"].lower():
            raise RuntimeError(f"Retained font checksum mismatch: {entry['file']}")
        if "SIL OPEN FONT LICENSE" not in read(font_dir / entry["license_file"]):
            raise RuntimeError(f"Retained font license text is invalid: {entry['license_file']}")


def verify(root: Path = ROOT) -> None:
    project = root / "godot"
    project_text = read(project / "project.godot")
    if not re.search(r'(?m)^run/main_scene="res://scenes/main\.tscn"$', project_text):
        raise RuntimeError("Godot project must use the single Ark menu main scene")
    for directory, expected, sidecars in (("scripts", RUNTIME_SCRIPTS, (".uid",)),
                                          ("scenes", SCENES, ()),
                                          ("shaders", SHADERS, (".uid",))):
        check_exact_files(project / directory, expected, sidecars)
    allowed_roots = {".godot", "art", "scripts", "scenes", "shaders", "tests", "project.godot", "export_presets.cfg", "README.md"}
    unexpected = {item.name for item in project.iterdir()} - allowed_roots
    if unexpected or {item.name for item in (project / "art").iterdir()} != {"fonts"}:
        raise RuntimeError(f"Retired data/audio/art remains inside res://: {sorted(unexpected)}")
    verify_fonts(root)
    resources = {f"scripts/{name}" for name in RUNTIME_SCRIPTS} | {f"scenes/{name}" for name in SCENES} | {f"shaders/{name}" for name in SHADERS} | {f"art/fonts/{name}" for name in FONT_FILES}
    for relative in sorted(resources):
        if not relative.endswith((".gd", ".tscn", ".gdshader", ".tres")):
            continue
        for target in re.findall(r'["\']res://([^"\']*)["\']', read(project / relative)):
            # The save service intentionally computes a repo-local save path.
            if target in ("", "../.local/save"):
                continue
            if target not in resources:
                raise RuntimeError(f"Runtime dependency escapes Ark/fonts: {relative} -> res://{target}")
    main_text = read(project / "scripts/main.gd")
    if 'res://scenes/ark_greybox.tscn' not in main_text or "ARK_MENU_READY_OK:" not in main_text:
        raise RuntimeError("Main menu is not wired to Ark with an observable readiness marker")
    tests = {path.name for path in (project / "tests").glob("*.gd")}
    if any(not name.startswith("ark_") for name in tests) or not REQUIRED_TESTS <= tests or not NON_HEADLESS_TESTS <= tests:
        raise RuntimeError("Ark regressions are incomplete or retired test entrypoints remain")
    expected = {f"res://tests/{name}" for name in tests - NON_HEADLESS_TESTS}
    executed = set(canonical_tests(root))
    if executed != expected:
        raise RuntimeError(f"Ark regression wiring mismatch: missing={sorted(expected-executed)}, unexpected={sorted(executed-expected)}")
    render = read(root / "tools/verify_render.ps1")
    if "ark_render_capture_test.gd" not in render or "ARK_RENDER_CAPTURE_TEST_OK:" not in render:
        raise RuntimeError("Separate display-backed Ark render gate is missing")
    preset = read(project / "export_presets.cfg")
    selected = re.search(r'(?m)^export_files=PackedStringArray\(([^\n]*)\)$', preset)
    expected_exports = {"res://" + resource for resource in resources if not resource.endswith((".txt", ".json"))}
    if 'export_filter="resources"' not in preset or selected is None or set(re.findall(r'"([^"\n]+)"', selected.group(1))) != expected_exports:
        raise RuntimeError("Export must explicitly select all and only Ark runtime/font resources")
    if not re.search(r'(?m)^exclude_filter="[^"\n]*tests/\*[^"\n]*archive/\*', preset):
        raise RuntimeError("Export exclusion must explicitly reject tests and archives")
    build = read(root / "tools/build_godot.ps1")
    release = read(root / "tools/verify_release_bundle.ps1")
    workflow = read(root / ".github/workflows/godot-windows.yml")
    read(root / "docs/WINDOWS_RELEASE_README.md")
    for name in ("AGPL-3.0.txt", "NotoSansSC-OFL.txt", "NotoSerifSC-OFL.txt", "WINDOWS_RELEASE_README.md", "checksums.sha256", "wendao-ark.txt", "verify_release_bundle.ps1"):
        if name not in build:
            raise RuntimeError(f"Release build omits safety/support contract: {name}")
    for token in ("verify_release_bundle.ps1", "verify_render.ps1", "verify_godot.ps1", "codex/island-survival-slice", "contents: read"):
        if token not in workflow:
            raise RuntimeError(f"CI is missing required Ark gate/scope: {token}")
    for token in ("VBCABLE", "vb-audio", "verify_export_audio", "verify_chronicle_content", "verify_godot_art", "RequireProductArt", "RequireFinalAudio"):
        if any(token in source for source in (workflow, build, read(root / "tools/verify_godot.ps1"), read(root / "tools/verify_godot.py"))):
            raise RuntimeError(f"Retired product/driver gate is still active: {token}")
    if "--pack" not in release or "verify_migration_surface.py" not in release:
        raise RuntimeError("Release bundle must validate its actual PCK directory")
    launcher = read(root / "启动游戏.bat")
    for token in ("wendao-ark.txt", "WENDAO_ARK_3D_PRODUCT_V1"):
        if token not in launcher or token not in release or token not in build:
            raise RuntimeError("Launcher/build/release must reject unmarked retired executables")
    # Preserve the original source-only boundary, including unstaged new files;
    # ignore deleted worktree entries until the migration is committed.
    listed = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard"], cwd=root,
                            check=True, capture_output=True, text=True, encoding="utf-8").stdout.splitlines()
    forbidden = [path for path in listed if (root / path).is_file() and
                 (re.search(r"(?i)(^|/)(CMakeLists\.txt|Makefile|.*\.(c|cc|cpp|cxx|h|hh|hpp|hxx|rc))$", path) or
                  re.search(r"(?i)^\.github/workflows/(story-art-validation|windows-build(-v06)?)\.yml$", path))]
    if forbidden:
        raise RuntimeError("Retired Win32/C++ source or CI returned: " + ", ".join(forbidden))


def pck_files(path: Path) -> dict[str, bytes]:
    """Read the unencrypted standalone PCK v2/v3/v4 directory and verify MD5s.

    Layout reference: Godot 4.7 core/io/file_access_pack.cpp,
    PackedSourcePCK::try_open_pack. Reject encrypted/sparse/delta packs rather
    than silently skipping a boundary check.
    """
    data = path.read_bytes()
    position = 0

    def take(size: int) -> bytes:
        nonlocal position
        if size < 0 or position + size > len(data):
            raise RuntimeError("Truncated PCK directory")
        value = data[position:position + size]
        position += size
        return value

    def number(fmt: str) -> int:
        return struct.unpack(fmt, take(struct.calcsize(fmt)))[0]

    if take(4) != b"GDPC":
        raise RuntimeError("Not a standalone Godot resource pack")
    version = number("<I")
    engine = tuple(number("<I") for _ in range(3))
    flags, base = number("<I"), number("<Q")
    if version not in (2, 3, 4) or engine != (4, 7, 1) or flags & ~2:
        raise RuntimeError(f"Unsupported PCK version/engine/flags: {version}/{engine}/{flags}")
    if version >= 3:
        position = number("<Q")
    else:
        take(64)
    count = number("<I")
    if not 1 <= count <= 10000:
        raise RuntimeError(f"Invalid PCK file count: {count}")
    files: dict[str, bytes] = {}
    for _ in range(count):
        length = number("<I")
        if not 1 <= length <= 4096:
            raise RuntimeError("Invalid PCK path length")
        name = take(length).rstrip(b"\0").decode("utf-8")
        name = name.removeprefix("res://")
        offset, size, checksum, file_flags = number("<Q"), number("<Q"), take(16), number("<I")
        if name in files or "\\" in name or name.startswith("/") or ".." in PurePosixPath(name).parts or file_flags:
            raise RuntimeError(f"Unsafe, duplicate or unsupported PCK entry: {name}")
        start = base + offset
        if start + size > len(data):
            raise RuntimeError(f"PCK file extends past pack: {name}")
        payload = data[start:start + size]
        if hashlib.md5(payload, usedforsecurity=False).digest() != checksum:
            raise RuntimeError(f"PCK payload checksum mismatch: {name}")
        files[name] = payload
    return files


def verify_pack(path: Path) -> int:
    files = pck_files(path)
    scripts = {f"scripts/{name}" for name in RUNTIME_SCRIPTS}
    allowed = {"project.binary", ".godot/global_script_class_cache.cfg", ".godot/uid_cache.bin"}
    allowed |= scripts | {name + suffix for name in scripts for suffix in (".remap", ".uid")}
    allowed |= {name[:-3] + ".gdc" for name in scripts}
    allowed |= {f"scenes/{name}" + suffix for name in SCENES for suffix in ("", ".remap")}
    allowed |= {f"shaders/{name}" + suffix for name in SHADERS for suffix in ("", ".uid")}
    allowed |= {f"art/fonts/{name}" + suffix for name in FONT_FILES for suffix in ("", ".import", ".remap")}
    generated = re.compile(r"^\.godot/(?:imported/Noto(?:Sans|Serif)SC-Variable\.ttf-[0-9a-f]+\.fontdata|exported/[^/]+/export-[0-9a-f]+-(?:(?:main|ark_greybox)\.scn|ark_ui_font\.res))$")
    extra = sorted(name for name in files if name not in allowed and not generated.fullmatch(name))
    if extra:
        raise RuntimeError("PCK contains non-Ark or unapproved resources: " + ", ".join(extra))
    required = {"project.binary", "shaders/ark_ocean.gdshader", "art/fonts/font_manifest.json"}
    required |= {f"art/fonts/{name}" for name in FONT_FILES if name.endswith(".txt")}
    if not required <= files.keys():
        raise RuntimeError("PCK omits required runtime/font-license resources: " + ", ".join(sorted(required-files.keys())))
    for relative in [*scripts, *(f"scenes/{name}" for name in SCENES), *(f"art/fonts/{name}" for name in FONT_FILES if name.endswith((".ttf", ".tres")))]:
        if relative not in files and relative + ".remap" not in files and relative + ".import" not in files:
            raise RuntimeError(f"PCK omits required Ark dependency: {relative}")
    return len(files)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pack", type=Path, help="Validate an actual exported PCK instead of the source checkout")
    args = parser.parse_args()
    if args.pack:
        count = verify_pack(args.pack)
        print(f"ARK_PACK_BOUNDARY_OK: {count} verified resource entries; Ark and retained fonts only")
    else:
        verify()
        print(f"MIGRATION_SURFACE_OK: six Ark scripts, two scenes, licensed fonts, {len(canonical_tests())} headless regressions; retired product excluded")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, RuntimeError, struct.error, subprocess.SubprocessError) as error:
        print(f"MIGRATION_SURFACE_FAILED: {error}")
        raise SystemExit(2) from error
