#!/usr/bin/env python3
"""Positive and hostile source/PCK cases for the exact integrated CC0 maps."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

import verify_coast_assets as coast
import verify_migration_surface as surface
from test_verify_migration_surface import minimal_pack, write_pack


class CoastAssetTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.directory = self.root / "godot/art/coast"
        shutil.copytree(surface.ROOT / "godot/art/coast", self.directory)

    def test_exact_reviewed_source_maps_provenance_and_imports_pass(self) -> None:
        coast.verify_coast_assets(self.root)

    def test_reviewed_assets_and_fixtures_survive_autocrlf_checkout(self) -> None:
        checkout = self.root / "git-checkout"
        checkout.mkdir()
        shutil.copyfile(surface.ROOT / ".gitattributes", checkout / ".gitattributes")

        def git(*arguments: str) -> None:
            subprocess.run(["git", "-C", str(checkout), *arguments], check=True,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        git("init", "--quiet")
        git("config", "core.autocrlf", "true")
        paths = [*("godot/art/coast/" + name for name in coast.COAST_DOCUMENTS),
                 "godot/tests/support/coast_prechange_geometry.json",
                 "godot/tests/support/coast_prechange_focus_ring.json",
                 "godot/tests/support/ark_opening_coast_reference.gd",
                 "godot/shaders/ark_coast_textured.gdshader",
                 "godot/shaders/ark_ocean.gdshader"]
        documents = {}
        for relative in paths:
            payload = ("Reviewed original: " + relative + "\nPreserve these bytes.\n").encode("utf-8")
            path = checkout / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(payload)
            documents[relative] = payload
        git("add", "--", ".gitattributes", *documents)
        for relative in documents:
            (checkout / relative).unlink()
        git("checkout-index", "--force", "--", *documents)
        for relative, payload in documents.items():
            self.assertEqual((checkout / relative).read_bytes(), payload,
                             "Reviewed coast bytes must survive Windows checkout: " + relative)

    def test_source_missing_extra_and_symlink_fail_closed(self) -> None:
        name = next(iter(coast.COAST_TEXTURES))
        path = self.directory / name
        data = path.read_bytes()
        path.unlink()
        with self.assertRaisesRegex(RuntimeError, "boundary changed"):
            coast.verify_coast_assets(self.root)
        path.write_bytes(data)
        extra = self.directory / "unapproved.jpg"
        extra.write_bytes(data)
        with self.assertRaisesRegex(RuntimeError, "boundary changed"):
            coast.verify_coast_assets(self.root)
        extra.unlink()
        path.unlink()
        target = self.root / "same-bytes.jpg"
        target.write_bytes(data)
        try:
            path.symlink_to(target)
        except OSError as error:
            self.skipTest(f"symlinks unavailable on this platform: {error}")
        with self.assertRaisesRegex(RuntimeError, "boundary changed"):
            coast.verify_coast_assets(self.root)

    def test_replaced_map_or_self_authorizing_provenance_is_rejected(self) -> None:
        for name in [next(iter(coast.COAST_TEXTURES)), "provenance/manifest.json", "asset_manifest.json"]:
            with self.subTest(name=name):
                path = self.directory / name
                data = path.read_bytes()
                path.write_bytes(data + b" ")
                with self.assertRaisesRegex(RuntimeError, "Reviewed coast bytes changed"):
                    coast.verify_coast_assets(self.root)
                path.write_bytes(data)

    def test_source_import_flags_and_resource_escape_rejected(self) -> None:
        name = next(iter(coast.COAST_TEXTURES))
        path = self.directory / (name + ".import")
        original = path.read_text()
        for old, new in [("mipmaps/generate=true", "mipmaps/generate=false"),
                         ("compress/mode=0", "compress/mode=2"),
                         ("process/normal_map_invert_y=false", "process/normal_map_invert_y=true"),
                         ("res://.godot/imported/", "res://../outside/")]:
            with self.subTest(changed=old):
                self.assertIn(old, original)
                path.write_text(original.replace(old, new))
                with self.assertRaisesRegex(RuntimeError, "Coast import changed|escapes"):
                    coast.verify_coast_assets(self.root)
        path.write_text(original)
        coast.verify_coast_assets(self.root)

    def test_pck_requires_every_coast_document_import_and_payload(self) -> None:
        path = self.root / "coast.pck"
        complete = minimal_pack()
        write_pack(path, complete)
        self.assertEqual(surface.verify_pack(path), len(complete))
        required = [*("art/coast/" + name for name in coast.COAST_DOCUMENTS),
                    *("art/coast/" + name + ".import" for name in coast.COAST_TEXTURES),
                    *coast.COAST_IMPORTED.values()]
        for missing in required:
            with self.subTest(missing=missing):
                changed = dict(complete)
                del changed[missing]
                write_pack(path, changed)
                with self.assertRaisesRegex(RuntimeError, "Reviewed coast bytes changed|PCK omits"):
                    surface.verify_pack(path)
        name, target = next(iter(coast.COAST_IMPORTED.items()))
        changed = dict(complete)
        key = "art/coast/" + name + ".import"
        changed[key] = changed[key].replace(target.encode(), b"../outside.ctex")
        write_pack(path, changed)
        with self.assertRaisesRegex(RuntimeError, "Coast import changed|escapes"):
            surface.verify_pack(path)


if __name__ == "__main__":
    unittest.main()
