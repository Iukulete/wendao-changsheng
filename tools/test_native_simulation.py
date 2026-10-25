import json
from pathlib import Path
import shutil
import tempfile
import unittest
import verify_native_simulation as native

class NativeSourceTests(unittest.TestCase):
    def test_pinned_sources(self):
        native.verify_sources()

    def test_tampered_source_and_self_authorized_manifest_rejected(self):
        with tempfile.TemporaryDirectory(dir=native.ROOT / ".tmp") as temporary:
            root = Path(temporary)
            target = root / "native/ark_simulation/third_party/flecs"
            shutil.copytree(native.ROOT / "native/ark_simulation/third_party/flecs", target)
            (target / "flecs.c").write_bytes(b"changed")
            with self.assertRaisesRegex(RuntimeError, "identity differs"):
                native.verify_sources(root)
            manifest = json.loads((target / "manifest.json").read_text(encoding="utf-8"))
            manifest["sha256"]["flecs.c"] = "0"*64
            (target / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "cannot authorize"):
                native.verify_sources(root)

    def test_pe_parser_rejects_non_binary(self):
        with self.assertRaises(RuntimeError): native.pe_dependencies(b"not a library")

    def test_runtime_port_exported_but_native_sources_not_in_res(self):
        project = native.ROOT / "godot"
        self.assertFalse(list(project.rglob("*.cpp")))
        preset = (project / "export_presets.cfg").read_text(encoding="utf-8")
        self.assertIn("res://scripts/adapters/ark_household_simulation.gd", preset)
        self.assertNotIn("ark_simulation.dll", preset)

if __name__ == "__main__": unittest.main()
