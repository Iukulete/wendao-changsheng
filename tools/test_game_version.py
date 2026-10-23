"""Version string, bounds and release-manifest regression tests."""
import json
from pathlib import Path
import tempfile
import unittest

import game_version


class GameVersionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.project = Path(self.temp.name) / "project.godot"
        self.manifest = Path(self.temp.name) / "game-version.json"

    def project_with(self, raw):
        self.project.write_text('config_version=5\n[application]\nconfig/version=' + raw + '\n', encoding='utf-8')

    def test_authority_and_leading_zeros(self):
        self.assertEqual(game_version.read_version(), "0.1.003")
        for version in ("0.0.000", "0.1.002", "12.9.999", "999999999999999999999.8.010"):
            with self.subTest(version=version):
                self.project_with(json.dumps(version))
                self.assertEqual(game_version.read_version(self.project), version)

    def test_invalid_versions_fail_closed(self):
        for raw in ('"0.1.2"', '"0.1.0002"', '"0.10.002"', '"-1.1.002"',
                    '"01.1.002"', '"0.1.002-beta"', '"0.1.002 "', '"０.1.002"',
                    '"0.1.002\\n"', '0.1', 'null', 'true'):
            with self.subTest(raw=raw):
                self.project_with(raw)
                with self.assertRaises(ValueError):
                    game_version.read_version(self.project)

    def test_manifest_matches_same_authority(self):
        self.project_with('"0.1.002"')
        self.manifest.write_text(json.dumps(game_version.metadata(self.project)), encoding='utf-8')
        game_version.verify_manifest(self.manifest, self.project)
        self.project_with('"0.1.003"')
        with self.assertRaises(ValueError):
            game_version.verify_manifest(self.manifest, self.project)

    def test_malformed_or_normalized_metadata_fails(self):
        self.project_with('"0.1.002"')
        for value in ({}, {"game_version": "0.1.2", "version_scheme": "S.X.Y"},
                      {"game_version": "0.1.002", "version_scheme": "SemVer"}):
            with self.subTest(value=value):
                self.manifest.write_text(json.dumps(value), encoding='utf-8')
                with self.assertRaises(ValueError):
                    game_version.verify_manifest(self.manifest, self.project)


if __name__ == '__main__':
    unittest.main()
