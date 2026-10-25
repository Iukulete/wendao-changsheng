import json
from pathlib import Path
import shutil
import tempfile
import unittest
from verify_ui_assets import ICONS, UI_FILES, UI_IMPORTED, expected_manifest, verify_ui_assets, verify_ui_manifest, verify_ui_pack

ROOT = Path(__file__).resolve().parents[1]

class UiAssetsTests(unittest.TestCase):
    def test_reviewed_source_subset(self):
        verify_ui_assets(ROOT)

    def test_manifest_cannot_change_provider_revision_or_adaptation(self):
        for key, value in [("revision", "main"), ("license_file", ""), ("adaptation", "unmodified")]:
            manifest = expected_manifest()
            manifest[key] = value
            with self.assertRaisesRegex(RuntimeError, "provenance"):
                verify_ui_manifest(json.dumps(manifest).encode())

    def test_license_and_icon_identity_are_enforced(self):
        with tempfile.TemporaryDirectory(dir=ROOT/".tmp") as folder:
            base = Path(folder)
            dest = base/"godot/art/ui_icons"
            shutil.copytree(ROOT/"godot/art/ui_icons", dest)
            for name in ["Lucide-LICENSE.txt", "hammer.svg"]:
                original = (dest/name).read_bytes()
                (dest/name).write_bytes(b"unreviewed")
                with self.assertRaises(RuntimeError):
                    verify_ui_assets(base)
                (dest/name).write_bytes(original)

    def test_packed_raw_and_imported_dependencies(self):
        prefix = "art/ui_icons/"
        files = {prefix+name: (ROOT/"godot"/prefix/name).read_bytes() for name in UI_FILES}
        verify_ui_pack(files)
        for name, target in UI_IMPORTED.items():
            del files[prefix+name]
            files[prefix+name+".import"] = ('[remap]\npath="res://'+target+'"\n').encode()
            files[target] = b"synthetic-imported-texture"
        verify_ui_pack(files)
        for key in [prefix+"Lucide-LICENSE.txt", UI_IMPORTED["house.svg"]]:
            broken = {name: value for name, value in files.items() if name != key}
            with self.assertRaises(RuntimeError):
                verify_ui_pack(broken)

if __name__ == "__main__":
    unittest.main()
