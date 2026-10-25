"""Reviewed static furniture must retain source/license/import/export boundaries."""
import json
from pathlib import Path
import shutil
import tempfile
import unittest
import verify_furniture_assets as furniture
import verify_migration_surface as surface
from test_verify_migration_surface import minimal_pack

class FurnitureAssetsTests(unittest.TestCase):
    def test_reviewed_source_passes(self):
        furniture.verify_furniture_assets(surface.ROOT)

    def test_manifest_cannot_self_authorize(self):
        source = json.loads((surface.ROOT/'godot/art/cabin_furniture/asset_manifest.json').read_bytes())
        for key,value in [('license','unknown'),('revision','main'),('models',['Paid_Extra'])]:
            with self.subTest(key=key):
                changed = dict(source)
                changed[key] = value
                with self.assertRaises(RuntimeError): furniture.manifest(json.dumps(changed).encode())

    def test_missing_model_or_texture_payload_is_rejected(self):
        complete = minimal_pack()
        furniture.verify_furniture_pack(complete)
        for name,target in furniture.IMPORTED.items():
            for missing in ('art/cabin_furniture/'+name+'.import',target):
                with self.subTest(missing=missing):
                    changed = dict(complete)
                    del changed[missing]
                    with self.assertRaises(RuntimeError): furniture.verify_furniture_pack(changed)

    def test_pack_cannot_change_license_or_import_target(self):
        complete = minimal_pack()
        for path,data in [('art/cabin_furniture/LICENSE.txt',b'unknown'),('art/cabin_furniture/bed_single_B.gltf.import',b'[remap]\npath="res://../other.scn"\n')]:
            changed = dict(complete)
            changed[path] = data
            with self.assertRaises(RuntimeError): furniture.verify_furniture_pack(changed)

    def test_source_modification_and_import_script_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            target = root/'godot/art/cabin_furniture'
            shutil.copytree(surface.ROOT/'godot/art/cabin_furniture',target)
            source = target/'cabinet_small.bin'
            original = source.read_bytes()
            source.write_bytes(original+b'changed')
            with self.assertRaises(RuntimeError): furniture.verify_furniture_assets(root)
            source.write_bytes(original)
            sidecar = target/'bed_single_B.gltf.import'
            sidecar.write_text(sidecar.read_text().replace('import_script/path=""','import_script/path="res://unreviewed.gd"'))
            with self.assertRaises(RuntimeError): furniture.verify_furniture_assets(root)

if __name__=='__main__': unittest.main()
