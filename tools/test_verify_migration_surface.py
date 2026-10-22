#!/usr/bin/env python3
"""Positive and adversarial checks for the active Ark/export boundary."""
from __future__ import annotations

import hashlib
from pathlib import Path, PurePosixPath, PureWindowsPath
import struct
import tempfile
import unittest
from unittest import mock

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
    files = {"project.binary": b"project", "shaders/ark_ocean.gdshader": b"shader"}
    files.update({"scripts/" + name: b"script" for name in surface.RUNTIME_SCRIPTS})
    files.update({"scenes/" + name: b"scene" for name in surface.SCENES})
    files.update({"art/fonts/" + name: b"font" for name in surface.FONT_FILES})
    files.update({"art/player_emma/" + name: b"model" for name in surface.EMMA_FILES})
    files.update({"art/player_pixel/" + name: b"pixel" for name in surface.PIXEL_FILES})
    return files


class MigrationSurfaceTests(unittest.TestCase):
    def test_current_checkout_has_only_the_complete_ark_surface(self) -> None:
        surface.verify()

    def test_all_ark_regressions_are_wired(self) -> None:
        tests = surface.canonical_tests()
        self.assertEqual(len(tests), len(set(tests)))
        self.assertIn("res://tests/ark_menu_integration_test.gd", tests)
        self.assertNotIn("res://tests/ark_test_paths.gd", tests)
        self.assertNotIn("res://tests/ark_render_capture_test.gd", tests)

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
                     "audio/music.wav", "archive/source_assets/art.png", ".godot/imported/old_portrait.ctex"):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temp:
                path = Path(temp) / "ark.pck"
                write_pack(path, {**minimal_pack(), name: b"retired"})
                with self.assertRaisesRegex(RuntimeError, "non-Ark"):
                    surface.verify_pack(path)

    def test_successfully_exported_pack_still_requires_dynamic_dependencies(self) -> None:
        # A selected-scenes export can exit 0 yet omit script-loaded resources.
        dynamic = ["scripts/" + name for name in surface.RUNTIME_SCRIPTS - {"main.gd", "ark_greybox.gd"}]
        dynamic += ["shaders/ark_ocean.gdshader", "art/fonts/ark_ui_font.tres"]
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


if __name__ == "__main__":
    unittest.main()
