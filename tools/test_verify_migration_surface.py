#!/usr/bin/env python3
"""Positive and adversarial checks for the active Ark/export boundary."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path, PurePosixPath, PureWindowsPath
import re
import shutil
import struct
import tempfile
import unittest
from unittest import mock
import zlib

import verify_migration_surface as surface


def write_pack(path: Path, files: dict[str, bytes], version: int = 3) -> None:
    """Small independent PCK fixture (directory before data, relative file base)."""
    directory = bytearray(struct.pack("<I", len(files)))
    payload = bytearray()
    for name, data in files.items():
        encoded = ("res://" + name).encode()
        encoded += b"\0" * (-len(encoded) % 4)
        directory += struct.pack("<I", len(encoded)) + encoded
        directory += struct.pack("<QQ", len(payload), len(data))
        directory += hashlib.md5(data, usedforsecurity=False).digest() + struct.pack("<I", 0)
        payload += data
    header_size = 40 if version >= 3 else 96
    header = b"GDPC" + struct.pack("<IIII", version, 4, 7, 1) + struct.pack("<IQ", 2, header_size + len(directory))
    header += struct.pack("<Q", header_size) if version >= 3 else b"\0" * 64
    path.write_bytes(header + directory + payload)


def minimal_pack() -> dict[str, bytes]:
    files = {"project.binary": b"project"}
    files.update({"shaders/" + name: b"shader" for name in surface.SHADERS})
    files.update({"scripts/" + name: b"script" for name in surface.RUNTIME_SCRIPTS})
    files.update({"scenes/" + name: b"scene" for name in surface.SCENES})
    files.update({"art/fonts/" + name: b"font" for name in surface.FONT_FILES})
    files.update({"art/player_emma/" + name: b"model" for name in surface.EMMA_FILES})
    files.update({"art/player_pixel/" + name: b"pixel" for name in surface.PIXEL_FILES})
    files.update({"art/surface_sample/" + name: (surface.ROOT / "godot/art/surface_sample" / name).read_bytes()
                  for name in surface.SURFACE_TEXTURES})
    files[surface.SURFACE_MANIFEST] = (surface.ROOT / "godot" / surface.SURFACE_MANIFEST).read_bytes()
    files.update({"art/home_sample/" + name: (surface.ROOT / "godot/art/home_sample" / name).read_bytes()
                  for name in surface.HOME_SAMPLE_FILES})
    files.update({"art/ui_icons/" + name: (surface.ROOT / "godot/art/ui_icons" / name).read_bytes()
                  for name in surface.UI_FILES})
    files.update({"art/lantern_table/" + name: (surface.ROOT / "godot/art/lantern_table" / name).read_bytes()
                  for name in surface.LANTERN_FILES})
    # A positive synthetic PCK must carry every newly required reviewed coast
    # document and packed import. The payload stubs test the boundary parser;
    # the separate actual Godot export gate validates native resource loading.
    files.update({"art/coast/" + name: (surface.ROOT / "godot/art/coast" / name).read_bytes()
                  for name in surface.COAST_DOCUMENTS})
    for name, target in surface.COAST_IMPORTED.items():
        files["art/coast/" + name + ".import"] = (
            '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n'
            'path="res://' + target + '"\n\0').encode()
        files[target] = b"imported-coast-texture-fixture"
    for name in ("asset_manifest.json", "License_Standard.txt"):
        files["art/coast_nature/" + name] = (surface.ROOT / "godot/art/coast_nature" / name).read_bytes()
    for name, target in surface.NATURE_IMPORTED.items():
        files["art/coast_nature/" + name + ".import"] = ('[remap]\npath="res://' + target + '"\n\0').encode()
        files[target] = b"imported-nature-payload-fixture"
    for name in ("asset_manifest.json", "LICENSE.txt"):
        files["art/cabin_furniture/" + name] = (surface.ROOT / "godot/art/cabin_furniture" / name).read_bytes()
    for name, target in surface.FURNITURE_IMPORTED.items():
        files["art/cabin_furniture/" + name + ".import"] = ('[remap]\npath="res://' + target + '"\n\0').encode()
        files[target] = b"imported-furniture-payload-fixture"
    return files


def imported_surface_pack() -> dict[str, bytes]:
    files = minimal_pack()
    for name, target in surface.SURFACE_IMPORTED.items():
        relative = "art/surface_sample/" + name
        del files[relative]
        files[relative + ".import"] = ('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n'
                                        'path="res://' + target + '"\n\0').encode()
        files[target] = b"imported-texture-fixture"
    return files


class SurfaceAssetTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.directory = self.root / "godot/art/surface_sample"
        shutil.copytree(surface.ROOT / "godot/art/surface_sample", self.directory)
        (self.root / "tools").mkdir()
        shutil.copyfile(surface.ROOT / surface.SURFACE_GENERATOR, self.root / surface.SURFACE_GENERATOR)

    def test_home_candidate_reviewed_asset_and_import_pass(self) -> None:
        surface.verify_home_assets(surface.ROOT)

    def test_lantern_reviewed_texture_import_and_provenance_pass(self) -> None:
        surface.verify_lantern_assets(surface.ROOT)

    def test_lantern_manifest_cannot_change_identity_or_mislabel_pbr(self) -> None:
        original = json.loads((surface.ROOT / "godot/art/lantern_table/asset_manifest.json").read_bytes())
        for key, value in (("file", "../outside.png"), ("sha256", "0" * 64),
                           ("source", "unknown"), ("usage", "seamless PBR normal map"),
                           ("prompt", ""), ("license", "unknown")):
            with self.subTest(key=key):
                changed = json.loads(json.dumps(original))
                changed["assets"][0][key] = value
                with self.assertRaises(RuntimeError):
                    surface.verify_lantern_manifest(json.dumps(changed).encode())

    def test_release_state_restoration_does_not_depend_on_debug_assertions(self) -> None:
        for path in (surface.ROOT / "godot/scripts").rglob("*.gd"):
            with self.subTest(path=path):
                self.assertNotRegex(path.read_text(encoding="utf-8"),
                                    r"assert\([^\n]*\.(?:restore|begin|commit|consume|transfer|advance)\(",
                                    "release builds may elide assert expressions; mutate explicitly before checking")

    def test_home_candidate_manifest_cannot_authorize_new_asset_or_source(self) -> None:
        path = surface.ROOT / "godot/art/home_sample/asset_manifest.json"
        original = json.loads(path.read_bytes())
        for key, value in (("sha256", "0" * 64), ("path", "../outside.png"),
                           ("external_reference_images", True), ("source", "unknown"), ("prompt", "")):
            with self.subTest(key=key):
                manifest = json.loads(json.dumps(original))
                manifest["files"][0][key] = value
                with self.assertRaisesRegex(RuntimeError, "provenance/identity"):
                    surface.verify_home_manifest(json.dumps(manifest).encode())
        for entries in ([], [original["files"][0], original["files"][0]], [None]):
            with self.assertRaisesRegex(RuntimeError, "exactly one"):
                surface.verify_home_manifest(json.dumps({**original, "files": entries}).encode())

    def write_manifest(self, manifest: dict) -> None:
        (self.directory / "asset_manifest.json").write_text(json.dumps(manifest), encoding="utf-8")

    def manifest(self) -> dict:
        return json.loads((self.directory / "asset_manifest.json").read_bytes())

    def test_reviewed_source_assets_and_generator_pass(self) -> None:
        surface.verify_surface_assets(self.root)

    def test_unapproved_asset_and_nontexture_import_sidecars_fail(self) -> None:
        for name in ("unapproved.png", "foreign.glb", "asset_manifest.json.import", "README.md.import"):
            with self.subTest(name=name):
                extra = self.directory / name
                extra.write_bytes(b"unapproved")
                with self.assertRaisesRegex(RuntimeError, "unapproved"):
                    surface.verify_surface_assets(self.root)
                extra.unlink()

    def test_missing_texture_or_import_metadata_fails(self) -> None:
        for name in surface.SURFACE_TEXTURES:
            for suffix in ("", ".import"):
                with self.subTest(name=name + suffix):
                    path = self.directory / (name + suffix)
                    data = path.read_bytes()
                    path.unlink()
                    with self.assertRaisesRegex(RuntimeError, "missing"):
                        surface.verify_surface_assets(self.root)
                    path.write_bytes(data)

    def test_manifest_path_traversal_and_duplicate_entries_fail_before_reading(self) -> None:
        original = self.manifest()
        for path in ("../outside.png", "/tmp/outside.png", "godot/art/surface_sample/../outside.png",
                     "godot\\art\\surface_sample\\terrain_detail.png", original["textures"][1]["path"]):
            with self.subTest(path=path):
                manifest = json.loads(json.dumps(original))
                manifest["textures"][0]["path"] = path
                self.write_manifest(manifest)
                with self.assertRaisesRegex(RuntimeError, "exactly the three approved texture paths"):
                    surface.verify_surface_assets(self.root)

    def test_manifest_cannot_redeclare_external_or_different_generator_provenance(self) -> None:
        original = self.manifest()
        for key, value in (("external_assets", True), ("runtime_generation", True), ("license", "CC0"),
                           ("generator", "../other.py"), ("generator_sha256", "0" * 64),
                           ("source", "downloaded imagery"), ("dependencies", "third-party package")):
            with self.subTest(key=key):
                manifest = json.loads(json.dumps(original))
                manifest["provenance"][key] = value
                self.write_manifest(manifest)
                with self.assertRaisesRegex(RuntimeError, "provenance/generator"):
                    surface.verify_surface_assets(self.root)

    def test_manifest_cannot_self_authorize_replacement_texture_hash(self) -> None:
        manifest = self.manifest()
        manifest["textures"][0]["sha256"] = "0" * 64
        self.write_manifest(manifest)
        with self.assertRaisesRegex(RuntimeError, "reviewed byte/hash mismatch"):
            surface.verify_surface_assets(self.root)

    def test_manifest_recipe_statistics_and_unregistered_fields_are_pinned(self) -> None:
        original = self.manifest()
        expected_mapping = {
            "terrain": "2 main-island surfaces: ordinary local-XZ UV; uv1_triplanar=false",
            "terrain_uv": "UV=(vertex.x, vertex.z) in local meters; +X to +U, +Z to +V; emitted during original mesh construction",
            "ship": "10 ship surfaces: unchanged local triplanar; uv1_triplanar=true",
            "world_triplanar": False,
        }
        self.assertEqual(original["recipe"]["mapping"], expected_mapping)
        for key, value in (("size", [512, 512]),
                           ("mapping", "StandardMaterial3D local triplanar; uv1_world_triplanar=false"),
                           ("mapping", {**expected_mapping, "terrain_uv": "UV=(-vertex.x, vertex.z)"}),
                           ("mapping", {**expected_mapping, "ship": "12 ship surfaces"}),
                           ("mapping", {**expected_mapping, "world_triplanar": True}),
                           ("unregistered_asset", "external.png")):
            with self.subTest(key=key, value=value):
                manifest = json.loads(json.dumps(original))
                manifest["recipe"][key] = value
                self.write_manifest(manifest)
                with self.assertRaisesRegex(RuntimeError, "manifest reviewed checksum mismatch"):
                    surface.verify_surface_assets(self.root)

    def test_duplicate_manifest_keys_fail(self) -> None:
        path = self.directory / "asset_manifest.json"
        path.write_bytes(path.read_bytes().replace(b'"schema": 1,', b'"schema": 1, "schema": 1,'))
        with self.assertRaisesRegex(RuntimeError, "Duplicate surface manifest key"):
            surface.verify_surface_assets(self.root)

    def test_generator_source_change_fails_without_running_it(self) -> None:
        with (self.root / surface.SURFACE_GENERATOR).open("ab") as stream:
            stream.write(b"\n# changed recipe\n")
        with self.assertRaisesRegex(RuntimeError, "generator reviewed checksum mismatch"):
            surface.verify_surface_assets(self.root)

    def test_texture_symlink_is_not_an_approved_asset(self) -> None:
        path = self.directory / "terrain_detail.png"
        outside = self.root / "outside.png"
        path.rename(outside)
        try:
            path.symlink_to(outside)
        except OSError as error:
            self.skipTest(f"symlinks unavailable on this platform: {error}")
        with self.assertRaisesRegex(RuntimeError, "symlinked assets"):
            surface.verify_surface_assets(self.root)

    def test_png_wrong_dimensions_and_rgba_format_fail_even_with_valid_crc(self) -> None:
        original = (self.directory / "terrain_detail.png").read_bytes()
        for width, color_type in ((128, 2), (256, 6)):
            with self.subTest(width=width, color_type=color_type):
                data = bytearray(original)
                data[16:29] = struct.pack(">IIBBBBB", width, 256, 8, color_type, 0, 0, 0)
                data[29:33] = struct.pack(">I", zlib.crc32(data[12:29]) & 0xFFFFFFFF)
                with self.assertRaisesRegex(RuntimeError, "256x256 opaque RGB8"):
                    surface.verify_surface_png(bytes(data), "terrain_detail.png")

    def test_png_corruption_and_valid_but_unreviewed_pixels_fail(self) -> None:
        data = bytearray((self.directory / "terrain_detail.png").read_bytes())
        data[45] ^= 1
        with self.assertRaisesRegex(RuntimeError, "CRC mismatch"):
            surface.verify_surface_png(bytes(data), "terrain_detail.png")
        def chunk(kind: bytes, payload: bytes) -> bytes:
            return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
        valid = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 256, 256, 8, 2, 0, 0, 0)) +
                 chunk(b"IDAT", zlib.compress((b"\0" + b"\xff" * 768) * 256)) + chunk(b"IEND", b""))
        with self.assertRaisesRegex(RuntimeError, "reviewed byte/hash mismatch"):
            surface.verify_surface_png(valid, "terrain_detail.png")

    def test_png_truncation_and_decompression_overflow_fail(self) -> None:
        data = (self.directory / "terrain_detail.png").read_bytes()
        with self.assertRaisesRegex(RuntimeError, "Truncated"):
            surface.verify_surface_png(data[:-3], "terrain_detail.png")
        payload = zlib.compress(b"\0" * (256 * 769 + 1))
        chunk = (struct.pack(">I", len(payload)) + b"IDAT" + payload +
                 struct.pack(">I", zlib.crc32(b"IDAT" + payload) & 0xFFFFFFFF))
        with self.assertRaisesRegex(RuntimeError, "decoded size/encoding mismatch"):
            surface.verify_surface_png(data[:33] + chunk + data[-12:], "terrain_detail.png")

    def test_import_path_and_lossless_mipmap_contract_fail_closed(self) -> None:
        path = self.directory / "terrain_detail.png.import"
        original = path.read_text(encoding="utf-8")
        for before, after in (("mipmaps/generate=true", "mipmaps/generate=false"),
                              ("compress/mode=0", "compress/mode=2"),
                              ("detect_3d/compress_to=0", "detect_3d/compress_to=1"),
                              ("res://.godot/imported/", "res://../outside/")):
            with self.subTest(before=before):
                self.assertIn(before, original)
                path.write_text(original.replace(before, after), encoding="utf-8")
                with self.assertRaisesRegex(RuntimeError, "import contract mismatch"):
                    surface.verify_surface_assets(self.root)

    def test_import_metadata_accepts_windows_newlines_without_loosening_paths(self) -> None:
        for name in surface.SURFACE_TEXTURES:
            path = self.directory / (name + ".import")
            path.write_bytes(path.read_bytes().replace(b"\n", b"\r\n"))
        surface.verify_surface_assets(self.root)


class MigrationSurfaceTests(unittest.TestCase):
    def test_current_checkout_has_only_the_complete_ark_surface(self) -> None:
        surface.verify()

    def test_all_ark_regressions_are_wired(self) -> None:
        tests = surface.canonical_tests()
        self.assertEqual(len(tests), len(set(tests)))
        self.assertIn("res://tests/ark_menu_integration_test.gd", tests)
        self.assertNotIn("res://tests/ark_test_paths.gd", tests)
        self.assertNotIn("res://tests/ark_render_capture_test.gd", tests)

    def test_surface_helper_cannot_reference_unregistered_runtime_assets(self) -> None:
        original_read = surface.read
        def changed_read(path: Path) -> str:
            text = original_read(path)
            if path == surface.ROOT / "godot/scripts/presentation/ark_surface_sample.gd":
                text += '\nconst UNAPPROVED = preload("res://art/surface_sample/unapproved.png")\n'
            return text
        with mock.patch.object(surface, "read", side_effect=changed_read), self.assertRaisesRegex(RuntimeError, "dependency escapes"):
            surface.verify()

    def test_duplicate_canonical_entry_fails(self) -> None:
        original = surface.read(surface.ROOT / "tools/verify_godot.ps1")
        original = original.replace("$testScripts = @(", '$testScripts = @(\n    "res://tests/ark_menu_integration_test.gd",')
        with mock.patch.object(surface, "read", return_value=original), self.assertRaisesRegex(RuntimeError, "duplicates"):
            surface.canonical_tests()

    def test_legacy_source_or_missing_source_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "main.gd").write_text("extends Control")
            surface.check_exact_files(root, frozenset({"main.gd"}), (".uid",))
            (root / "combat_system.gd").write_text("extends RefCounted")
            with self.assertRaisesRegex(RuntimeError, "unapproved"):
                surface.check_exact_files(root, frozenset({"main.gd"}))
            (root / "main.gd").unlink()
            with self.assertRaisesRegex(RuntimeError, "missing"):
                surface.check_exact_files(root, frozenset({"main.gd"}))

    def test_nested_runtime_paths_are_platform_independent(self) -> None:
        expected = frozenset({"main.gd", "modules/economy/ark_economy.gd"})
        names = expected | {name + ".uid" for name in expected}
        for path_type in (PurePosixPath, PureWindowsPath):
            with self.subTest(platform=path_type.__name__):
                directory = mock.Mock(spec=Path)
                directory.name = "scripts"
                files = []
                for name in sorted(names):
                    path = mock.Mock(spec=Path)
                    path.is_file.return_value = True
                    path.relative_to.return_value = path_type(name)
                    files.append(path)
                directory.rglob.return_value = files
                surface.check_exact_files(directory, expected, (".uid",))

    def test_normalized_nested_paths_still_reject_missing_and_unapproved_files(self) -> None:
        expected = frozenset({"modules/economy/ark_economy.gd"})
        for path_type in (PurePosixPath, PureWindowsPath):
            for name, error in (("modules/economy/ark_economy.gd.uid", "missing=\\['modules/economy/ark_economy.gd'\\]"),
                                ("modules/economy/retired.gd", "unapproved=\\['modules/economy/retired.gd'\\]")):
                with self.subTest(platform=path_type.__name__, name=name):
                    directory = mock.Mock(spec=Path)
                    directory.name = "scripts"
                    path = mock.Mock(spec=Path)
                    path.is_file.return_value = True
                    path.relative_to.return_value = path_type(name)
                    directory.rglob.return_value = [path]
                    with self.assertRaisesRegex(RuntimeError, error):
                        surface.check_exact_files(directory, expected, (".uid",))

    def test_pck_versions_and_actual_payload_checksums(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "ark.pck"
            for version in (2, 3, 4):
                with self.subTest(version=version):
                    write_pack(path, minimal_pack(), version)
                    self.assertEqual(surface.verify_pack(path), len(minimal_pack()))
            data = bytearray(path.read_bytes())
            data[-1] ^= 1
            path.write_bytes(data)
            with self.assertRaisesRegex(RuntimeError, "checksum mismatch"):
                surface.verify_pack(path)

    def test_pack_rejects_legacy_archives_and_tests(self) -> None:
        for name in ("tests/ark_menu_integration_test.gd", "scripts/combat_system.gdc", "data/events.json",
                     "audio/music.wav", "archive/source_assets/art.png", ".godot/imported/old_portrait.ctex",
                     "art/surface_sample/unapproved.png", "art/surface_sample/README.md",
                     "art/surface_sample/asset_manifest.json.import", "tools/generate_surface_sample.py",
                     ".godot/imported/terrain_detail.png-deadbeef.ctex"):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temp:
                path = Path(temp) / "ark.pck"
                write_pack(path, {**minimal_pack(), name: b"retired"})
                with self.assertRaisesRegex(RuntimeError, "non-Ark"):
                    surface.verify_pack(path)

    def test_successfully_exported_pack_still_requires_dynamic_dependencies(self) -> None:
        # A selected-scenes export can exit 0 yet omit script-loaded resources.
        dynamic = ["scripts/" + name for name in surface.RUNTIME_SCRIPTS - {"main.gd", "ark_greybox.gd"}]
        dynamic += [*("shaders/" + name for name in surface.SHADERS), "art/fonts/ark_ui_font.tres"]
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "ark.pck"
            for missing in dynamic:
                with self.subTest(missing=missing):
                    files = minimal_pack()
                    del files[missing]
                    write_pack(path, files)
                    with self.assertRaisesRegex(RuntimeError, "omits required"):
                        surface.verify_pack(path)

    def test_pack_rejects_traversal_truncation_and_missing_runtime(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "ark.pck"
            write_pack(path, {"../outside.gd": b"bad"})
            with self.assertRaisesRegex(RuntimeError, "Unsafe"):
                surface.verify_pack(path)
            path.write_bytes(b"GDPC")
            with self.assertRaisesRegex(RuntimeError, "Truncated"):
                surface.verify_pack(path)
            files = minimal_pack()
            del files["scripts/main.gd"]
            write_pack(path, files)
            with self.assertRaisesRegex(RuntimeError, "required Ark dependency"):
                surface.verify_pack(path)

    def test_pack_requires_manifest_and_every_surface_texture(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "ark.pck"
            for missing in (surface.SURFACE_MANIFEST, *("art/surface_sample/" + name for name in surface.SURFACE_TEXTURES)):
                with self.subTest(missing=missing):
                    files = minimal_pack()
                    del files[missing]
                    write_pack(path, files)
                    with self.assertRaisesRegex(RuntimeError, "omits required"):
                        surface.verify_pack(path)

    def test_pack_requires_home_candidate_and_its_exact_import_target(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "home.pck"
            relative = "art/home_sample/home_timber_albedo_v1.png"
            for missing in (relative, "art/home_sample/asset_manifest.json"):
                files = minimal_pack()
                del files[missing]
                write_pack(path, files)
                with self.assertRaises(RuntimeError):
                    surface.verify_pack(path)
            files = minimal_pack()
            del files[relative]
            files[relative + ".import"] = ('[remap]\npath="res://' + surface.HOME_SAMPLE_IMPORTED + '"\n').encode()
            files[surface.HOME_SAMPLE_IMPORTED] = b"imported-home-fixture"
            write_pack(path, files)
            self.assertEqual(surface.verify_pack(path), len(files))
            files[relative + ".import"] = b'[remap]\npath="res://art/fonts/font_manifest.json"\n'
            write_pack(path, files)
            with self.assertRaisesRegex(RuntimeError, "escapes reviewed target"):
                surface.verify_pack(path)

    def test_pack_checks_imported_surface_payload_presence_and_exact_path(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "ark.pck"
            files = imported_surface_pack()
            write_pack(path, files)
            self.assertEqual(surface.verify_pack(path), len(files))
            for name, target in surface.SURFACE_IMPORTED.items():
                with self.subTest(missing=target):
                    missing = dict(files)
                    del missing[target]
                    write_pack(path, missing)
                    with self.assertRaisesRegex(RuntimeError, "omits required imported surface texture"):
                        surface.verify_pack(path)
                with self.subTest(redirected=name):
                    redirected = dict(files)
                    relative = "art/surface_sample/" + name + ".import"
                    redirected[relative] = redirected[relative].replace(target.encode(), b"../outside.ctex")
                    write_pack(path, redirected)
                    with self.assertRaisesRegex(RuntimeError, "import contract mismatch"):
                        surface.verify_pack(path)

    def test_pack_rejects_self_consistent_but_unreviewed_surface_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "ark.pck"
            files = minimal_pack()
            manifest = json.loads(files[surface.SURFACE_MANIFEST])
            manifest["provenance"]["external_assets"] = True
            files[surface.SURFACE_MANIFEST] = json.dumps(manifest).encode()
            write_pack(path, files)
            with self.assertRaisesRegex(RuntimeError, "provenance/generator"):
                surface.verify_pack(path)

    def test_export_cannot_omit_surface_resources_or_broaden_include_filters(self) -> None:
        original = surface.read(surface.ROOT / "godot/export_presets.cfg")
        line = re.search(r'(?m)^export_files=PackedStringArray\(([^\n]*)\)$', original)
        self.assertIsNotNone(line)
        resources = {name.removeprefix("res://") for name in re.findall(r'"([^"\n]+)"', line.group(1))}
        surface.verify_export_preset(original, resources)
        for missing in ("scripts/presentation/ark_surface_sample.gd", *("art/surface_sample/" + name for name in surface.SURFACE_TEXTURES)):
            with self.subTest(missing=missing):
                changed = original.replace('"res://' + missing + '", ', "")
                self.assertNotEqual(changed, original)
                with self.assertRaisesRegex(RuntimeError, "explicitly select"):
                    surface.verify_export_preset(changed, resources)
        for before, after in (("," + surface.SURFACE_MANIFEST, ""),
                              (surface.SURFACE_MANIFEST, "art/surface_sample/*"),
                              ("tests/*,archive/*", "tests/*"),
                              ('exclude_filter="tests/*', 'exclude_filter="art/surface_sample/*,tests/*')):
            with self.subTest(before=before):
                changed = original.replace(before, after)
                self.assertNotEqual(changed, original)
                with self.assertRaisesRegex(RuntimeError, "Export (include|exclude)_filter"):
                    surface.verify_export_preset(changed, resources)
        for extra in ('export_filter="all_resources"\n', line.group(0) + "\n"):
            with self.subTest(duplicate_export_setting=extra):
                with self.assertRaisesRegex(RuntimeError, "explicitly select"):
                    surface.verify_export_preset(original + extra, resources)


if __name__ == "__main__":
    unittest.main()
