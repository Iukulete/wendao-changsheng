"""Reviewed CC0 nature assets cannot self-authorize new source or pack files."""
import json
from pathlib import Path
import shutil
import tempfile
import unittest
import verify_nature_assets as nature
import verify_migration_surface as surface
from test_verify_migration_surface import minimal_pack

class NatureAssetsTests(unittest.TestCase):
    def test_reviewed_source_and_imports_pass(self):
        nature.verify_nature_assets(surface.ROOT)

    def test_manifest_cannot_self_authorize_license_or_models(self):
        original = json.loads((surface.ROOT / 'godot/art/coast_nature/asset_manifest.json').read_bytes())
        for field, value in [('license','unknown'),('models',['Paid_Source_Model']),('archive_sha256','0'*64)]:
            with self.subTest(field=field):
                candidate = dict(original)
                candidate[field] = value
                with self.assertRaises(RuntimeError): nature.manifest(json.dumps(candidate).encode())

    def test_every_model_and_texture_import_is_required(self):
        complete = minimal_pack()
        nature.verify_nature_pack(complete)
        for name, target in nature.IMPORTED.items():
            for missing in ('art/coast_nature/'+name+'.import',target):
                with self.subTest(missing=missing):
                    changed = dict(complete)
                    del changed[missing]
                    with self.assertRaises(RuntimeError): nature.verify_nature_pack(changed)

    def test_pack_import_cannot_escape_or_replace_license(self):
        complete = minimal_pack()
        name = 'Pine_1.gltf'
        changed = dict(complete)
        changed['art/coast_nature/'+name+'.import'] = b'[remap]\npath="res://../outside.scn"\n'
        with self.assertRaises(RuntimeError): nature.verify_nature_pack(changed)
        changed = dict(complete)
        changed['art/coast_nature/License_Standard.txt'] = b'unknown'
        with self.assertRaises(RuntimeError): nature.verify_nature_pack(changed)

    def test_modified_source_or_texture_budget_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            directory = root / 'godot/art/coast_nature'
            shutil.copytree(surface.ROOT / 'godot/art/coast_nature',directory)
            source = directory / 'Pine_1.bin'
            original = source.read_bytes()
            source.write_bytes(original+b'changed')
            with self.assertRaises(RuntimeError): nature.verify_nature_assets(root)
            source.write_bytes(original)
            imports = directory / 'Leaves.png.import'
            imports.write_text(imports.read_text().replace('process/size_limit=1024','process/size_limit=0'))
            with self.assertRaises(RuntimeError): nature.verify_nature_assets(root)

if __name__ == '__main__': unittest.main()
