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
import zlib

from verify_coast_assets import COAST_TEXTURES, COAST_DOCUMENTS, COAST_IMPORTED, verify_coast_assets, verify_coast_pack

ROOT = Path(__file__).resolve().parents[1]
RUNTIME_SCRIPTS = frozenset({"main.gd", "ark_fixture_placement.gd", "ark_greybox.gd",
                             "ark_greybox_save.gd", "ark_landmass_builder.gd", "ark_world_chart.gd"})
RUNTIME_SCRIPTS |= frozenset(['modules/economy/ark_economy.gd', 'modules/construction/ark_construction.gd', 'modules/memory/ark_memory.gd', 'modules/residents/ark_gathering.gd', 'adapters/ark_analytic_water.gd', 'adapters/ark_vessel_navigation.gd', 'presentation/ark_pixel_protagonist.gd', 'presentation/ark_emma_protagonist.gd'])
RUNTIME_SCRIPTS |= frozenset({"presentation/ark_surface_sample.gd", "presentation/ark_nearfuture_hud.gd"})
RUNTIME_SCRIPTS |= frozenset({"terrain/ark_opening_coast.gd", "presentation/ark_coast_materials.gd"})
EMMA_FILES = frozenset({"emma.glb", "emma_locomotion.tres", "Quaternius-CC0.txt"})
PIXEL_FILES = frozenset(['image(20261021-085642).png', 'image(20261021-085643).png', 'image(20261021-085645).png', 'image(20261021-085646).png'])
SCENES = frozenset({"main.tscn", "ark_greybox.tscn"})
SHADERS = frozenset({"ark_ocean.gdshader", "ark_coast_textured.gdshader"})
FONT_FILES = frozenset({"NotoSansSC-Variable.ttf", "NotoSerifSC-Variable.ttf",
                       "NotoSansSC-OFL.txt", "NotoSerifSC-OFL.txt", "font_manifest.json", "ark_ui_font.tres"})
# Independent reviewed identities, not hashes trusted from an asset's own manifest.
# A rebake requires reviewing and intentionally updating this bounded allowlist.
SURFACE_TEXTURES = {
    "terrain_detail.png": (5358, "04e687230183356bfe450f06d81f6003767d3fb4c266328cd66c9c887a46c59a"),
    "wood_grain.png": (9944, "967ee279dc5d8180e669976ad04795cd0791c13a0957892c8b8f3bfe2fda45fa"),
    "deck_planks.png": (10160, "f6ace5d7a780b03f0dabdc0356a07937a1270a03e2964ee5e5d2459a476a4f0d"),
}
SURFACE_GENERATOR = "tools/generate_surface_sample.py"
SURFACE_GENERATOR_SHA256 = "6d1fc9c2d336bccd6a9298a93c01b1cda29160dacec9f3a1a3b1c7c7560ca299"
SURFACE_MANIFEST_SHA256 = "ce3ac268697a16bb67d7470af9f1bac7f62bf8f3f66fdb59aa980acab56fac68"
SURFACE_MANIFEST = "art/surface_sample/asset_manifest.json"
SURFACE_SOURCE_FILES = frozenset({*SURFACE_TEXTURES, "asset_manifest.json", "README.md",
                                 *(name + ".import" for name in SURFACE_TEXTURES)})
SURFACE_IMPORTED = {
    name: ".godot/imported/" + name + "-" + hashlib.md5(
        ("res://art/surface_sample/" + name).encode(), usedforsecurity=False).hexdigest() + ".ctex"
    for name in SURFACE_TEXTURES
}
EXPORT_INCLUDE_FILTERS = frozenset({"art/player_emma/*.txt", "art/fonts/*.ttf", "art/fonts/*.txt",
                                    "art/fonts/font_manifest.json", SURFACE_MANIFEST})
EXPORT_INCLUDE_FILTERS |= frozenset("art/coast/" + name for name in COAST_DOCUMENTS)
EXPORT_EXCLUDE_FILTERS = frozenset({"tests/*", "archive/*", "data/*", "audio/*"})
NON_HEADLESS_TESTS = frozenset({"ark_test_paths.gd", "ark_render_capture_test.gd", "ark_pixel_protagonist_render_test.gd", "ark_gerstner_render_test.gd"})
REQUIRED_TESTS = frozenset({"ark_menu_integration_test.gd", "ark_test_paths_test.gd",
                           "ark_fixture_edit_test.gd", "ark_world_travel_test.gd",
                           "ark_save_integrity_audit_test.gd", "ark_chart_layout_audit_test.gd",
                           "ark_nearfuture_hud_test.gd"})


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
    actual = {path.relative_to(directory).as_posix() for path in directory.rglob("*") if path.is_file()}
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


def verify_surface_manifest(data: bytes) -> None:
    def unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
        result: dict[str, object] = {}
        for key, value in pairs:
            if key in result:
                raise RuntimeError(f"Duplicate surface manifest key: {key}")
            result[key] = value
        return result

    manifest = json.loads(data, object_pairs_hook=unique_object)
    provenance = {
        "source": "original deterministic procedural bake", "external_assets": False,
        "runtime_generation": False, "generator": SURFACE_GENERATOR,
        "generator_sha256": SURFACE_GENERATOR_SHA256, "dependencies": "Python standard library only",
        "license": "AGPL-3.0, repository LICENSE",
    }
    if not isinstance(manifest, dict) or type(manifest.get("schema")) is not int or manifest["schema"] != 1:
        raise RuntimeError("Surface sample manifest schema is invalid")
    if manifest.get("provenance") != provenance:
        raise RuntimeError("Surface sample manifest provenance/generator identity mismatch")
    entries = manifest.get("textures")
    expected = {"godot/art/surface_sample/" + name for name in SURFACE_TEXTURES}
    if (not isinstance(entries, list) or len(entries) != len(expected) or
            any(not isinstance(entry, dict) or not isinstance(entry.get("path"), str) for entry in entries) or
            {entry["path"] for entry in entries} != expected):
        raise RuntimeError("Surface sample manifest must declare exactly the three approved texture paths")
    for entry in entries:
        name = entry["path"].removeprefix("godot/art/surface_sample/")
        size, digest = SURFACE_TEXTURES[name]
        if type(entry.get("bytes")) is not int or entry["bytes"] != size or entry.get("sha256") != digest:
            raise RuntimeError(f"Surface sample manifest reviewed byte/hash mismatch: {name}")
    # Pins recipe, statistics, status and all other fields too; neither new fields
    # nor a self-consistent replacement manifest can silently expand provenance.
    if hashlib.sha256(data).hexdigest() != SURFACE_MANIFEST_SHA256:
        raise RuntimeError("Surface sample manifest reviewed checksum mismatch")


def verify_surface_png(data: bytes, name: str) -> None:
    """Validate our deliberately minimal RGB8 PNG encoding, not arbitrary imagery."""
    if name not in SURFACE_TEXTURES or not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise RuntimeError(f"Invalid surface PNG signature/name: {name}")
    position, chunks = 8, []
    while position < len(data):
        if position + 12 > len(data):
            raise RuntimeError(f"Truncated surface PNG: {name}")
        size = struct.unpack_from(">I", data, position)[0]
        end = position + 12 + size
        if end > len(data):
            raise RuntimeError(f"Truncated surface PNG chunk: {name}")
        kind, payload = data[position + 4:position + 8], data[position + 8:end - 4]
        if zlib.crc32(kind + payload) & 0xFFFFFFFF != struct.unpack_from(">I", data, end - 4)[0]:
            raise RuntimeError(f"Surface PNG CRC mismatch: {name}")
        chunks.append((kind, payload))
        position = end
    if [kind for kind, _ in chunks] != [b"IHDR", b"IDAT", b"IEND"] or chunks[-1][1]:
        raise RuntimeError(f"Surface PNG format/chunk layout mismatch: {name}")
    if chunks[0][1] != struct.pack(">IIBBBBB", 256, 256, 8, 2, 0, 0, 0):
        raise RuntimeError(f"Surface PNG must be 256x256 opaque RGB8: {name}")
    # Bound decompression even for a corrupted replacement; our bake uses filter 0.
    decoder = zlib.decompressobj()
    try:
        pixels = decoder.decompress(chunks[1][1], 256 * 769 + 1)
    except zlib.error as error:
        raise RuntimeError(f"Surface PNG compressed data is invalid: {name}") from error
    if (len(pixels) != 256 * 769 or not decoder.eof or decoder.unused_data or
            decoder.unconsumed_tail or any(pixels[row * 769] != 0 for row in range(256))):
        raise RuntimeError(f"Surface PNG decoded size/encoding mismatch: {name}")
    size, digest = SURFACE_TEXTURES[name]
    if len(data) != size or hashlib.sha256(data).hexdigest() != digest:
        raise RuntimeError(f"Surface PNG reviewed byte/hash mismatch: {name}")


def verify_surface_import(data: bytes, name: str, *, packed: bool = False) -> str:
    source = "res://art/surface_sample/" + name
    target = "res://" + SURFACE_IMPORTED[name]
    text = data.decode("utf-8").replace("\r\n", "\n").rstrip("\0")
    required = {"importer": '"texture"', "type": '"CompressedTexture2D"', "path": '"' + target + '"'}
    if not packed:
        required.update({"source_file": '"' + source + '"', "dest_files": '["' + target + '"]',
                         "compress/mode": "0", "mipmaps/generate": "true", "process/size_limit": "0",
                         "detect_3d/compress_to": "0"})
    for key, value in required.items():
        if re.findall(r"(?m)^" + re.escape(key) + r"=(.*)$", text) != [value]:
            raise RuntimeError(f"Surface texture import contract mismatch: {name}/{key}")
    refs = set(re.findall(r'"(res://[^"\n]+)"', text))
    if refs != ({target} if packed else {source, target}):
        raise RuntimeError(f"Surface texture import escapes approved dependencies: {name}")
    return SURFACE_IMPORTED[name]


def verify_surface_assets(root: Path) -> None:
    directory = root / "godot/art/surface_sample"
    if directory.is_symlink() or any(path.is_symlink() for path in directory.rglob("*")):
        raise RuntimeError("Surface sample must not contain symlinked assets")
    check_exact_files(directory, SURFACE_SOURCE_FILES)
    verify_surface_manifest((directory / "asset_manifest.json").read_bytes())
    generator = root / SURFACE_GENERATOR
    if (generator.is_symlink() or not generator.is_file() or
            hashlib.sha256(generator.read_bytes()).hexdigest() != SURFACE_GENERATOR_SHA256):
        raise RuntimeError("Surface sample generator reviewed checksum mismatch")
    for name in SURFACE_TEXTURES:
        verify_surface_png((directory / name).read_bytes(), name)
        verify_surface_import((directory / (name + ".import")).read_bytes(), name)


def verify_export_preset(preset: str, resources: set[str]) -> None:
    selected = re.findall(r'(?m)^export_files=PackedStringArray\(([^\n]*)\)$', preset)
    expected_exports = {"res://" + resource for resource in resources if not resource.endswith((".txt", ".json", ".md"))}
    if (re.findall(r'(?m)^export_filter="([^"\n]*)"$', preset) != ["resources"] or len(selected) != 1 or
            set(re.findall(r'"([^"\n]+)"', selected[0])) != expected_exports):
        raise RuntimeError("Export must explicitly select all and only Ark runtime/font/surface resources")
    for key, expected in (("include_filter", EXPORT_INCLUDE_FILTERS), ("exclude_filter", EXPORT_EXCLUDE_FILTERS)):
        values = re.findall(r'(?m)^' + key + r'="([^"\n]*)"$', preset)
        if len(values) != 1 or set(values[0].split(",")) != expected:
            raise RuntimeError(f"Export {key} must preserve exact runtime provenance and archive/test exclusions")


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
    if unexpected or {item.name for item in (project / "art").iterdir()} != {"fonts", "player_pixel", "player_emma", "surface_sample", "coast"}:
        raise RuntimeError(f"Retired data/audio/art remains inside res://: {sorted(unexpected)}")
    check_exact_files(project / "art/player_pixel", PIXEL_FILES, (".import",))
    check_exact_files(project / "art/player_emma", EMMA_FILES, (".import",))
    verify_fonts(root)
    verify_surface_assets(root)
    verify_coast_assets(root)
    resources = {f"art/player_emma/{name}" for name in EMMA_FILES} | {f"art/player_pixel/{name}" for name in PIXEL_FILES} | {f"scripts/{name}" for name in RUNTIME_SCRIPTS} | {f"scenes/{name}" for name in SCENES} | {f"shaders/{name}" for name in SHADERS} | {f"art/fonts/{name}" for name in FONT_FILES}
    resources |= {f"art/surface_sample/{name}" for name in SURFACE_TEXTURES} | {SURFACE_MANIFEST}
    resources |= {"art/coast/" + name for name in [*COAST_TEXTURES, *COAST_DOCUMENTS]}
    for relative in sorted(resources):
        if not relative.endswith((".gd", ".tscn", ".gdshader", ".tres")):
            continue
        for target in re.findall(r'["\']res://([^"\']*)["\']', read(project / relative)):
            # The save service intentionally computes a repo-local save path.
            if target in ("", "../.local/save"):
                continue
            if relative == "scripts/presentation/ark_coast_materials.gd" and target == "art/coast":
                continue  # Exact reviewed nine-map directory, dynamically joined by the material module.
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
    verify_export_preset(preset, resources)
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
    forbidden = [path for path in listed if (root / path).is_file() and path != "native/ark_water/ark_water.cpp" and
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
    allowed |= {f"art/player_emma/{name}" + suffix for name in EMMA_FILES for suffix in ("", ".import", ".remap")}
    allowed |= {f"art/player_pixel/{name}" + suffix for name in PIXEL_FILES for suffix in ("", ".import", ".remap")}
    allowed |= {f"art/surface_sample/{name}" + suffix for name in SURFACE_TEXTURES for suffix in ("", ".import")}
    allowed |= {SURFACE_MANIFEST, *SURFACE_IMPORTED.values()}
    allowed |= {"art/coast/"+name+suffix for name in COAST_TEXTURES for suffix in ("", ".import")}
    allowed |= {"art/coast/"+name for name in COAST_DOCUMENTS} | set(COAST_IMPORTED.values())
    generated = re.compile(r"^\.godot/(?:imported/emma\.glb-[0-9a-f]+\.scn|imported/image\(20261021-(?:085642|085643|085645|085646)\)\.png-[0-9a-f]+\.ctex|imported/Noto(?:Sans|Serif)SC-Variable\.ttf-[0-9a-f]+\.fontdata|exported/[^/]+/export-[0-9a-f]+-(?:(?:main|ark_greybox)\.scn|(?:ark_ui_font|emma_locomotion)\.res))$")
    extra = sorted(name for name in files if name not in allowed and not generated.fullmatch(name))
    if extra:
        raise RuntimeError("PCK contains non-Ark or unapproved resources: " + ", ".join(extra))
    required = {"project.binary", "art/fonts/font_manifest.json", SURFACE_MANIFEST}
    required |= {"shaders/" + name for name in SHADERS}
    required |= {f"art/fonts/{name}" for name in FONT_FILES if name.endswith(".txt")}
    if not required <= files.keys():
        raise RuntimeError("PCK omits required runtime/font-license resources: " + ", ".join(sorted(required-files.keys())))
    verify_surface_manifest(files[SURFACE_MANIFEST])
    verify_coast_pack(files)
    for name in SURFACE_TEXTURES:
        relative = "art/surface_sample/" + name
        if relative in files:
            verify_surface_png(files[relative], name)
        elif relative + ".import" not in files:
            raise RuntimeError(f"PCK omits required surface dependency: {relative}")
        if relative + ".import" in files:
            target = verify_surface_import(files[relative + ".import"], name, packed=True)
            if not files.get(target):
                raise RuntimeError(f"PCK omits required imported surface texture: {target}")
    for relative in [*scripts, *(f"art/player_emma/{name}" for name in EMMA_FILES), *(f"art/player_pixel/{name}" for name in PIXEL_FILES), *(f"scenes/{name}" for name in SCENES), *(f"art/fonts/{name}" for name in FONT_FILES if name.endswith((".ttf", ".tres")))]:
        if relative not in files and relative + ".remap" not in files and relative + ".import" not in files:
            raise RuntimeError(f"PCK omits required Ark dependency: {relative}")
    return len(files)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pack", type=Path, help="Validate an actual exported PCK instead of the source checkout")
    args = parser.parse_args()
    if args.pack:
        count = verify_pack(args.pack)
        print(f"ARK_PACK_BOUNDARY_OK: {count} verified resource entries; approved Ark runtime, retained fonts, supplied Emma model/pixel images and three retained procedural surface textures and nine provenance-pinned CC0 coast maps only")
    else:
        verify()
        print(f"MIGRATION_SURFACE_OK: approved Ark scripts, two scenes, licensed fonts, supplied Emma model/pixel images and three retained procedural surface textures and nine provenance-pinned CC0 coast maps, {len(canonical_tests())} headless regressions; retired product excluded")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, RuntimeError, struct.error, subprocess.SubprocessError) as error:
        print(f"MIGRATION_SURFACE_FAILED: {error}")
        raise SystemExit(2) from error
