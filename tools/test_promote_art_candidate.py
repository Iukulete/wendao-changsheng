#!/usr/bin/env python3
"""Regression checks for product-art catalog promotion behavior."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image

try:
    from . import promote_art_candidate as promote
except ImportError:
    import promote_art_candidate as promote


class ArtPromotionTests(unittest.TestCase):
    def test_character_promotion_updates_inventory_and_live_bindings(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            data = root / "godot" / "data"
            art = root / "godot" / "art"
            data.mkdir(parents=True)
            art.mkdir(parents=True)
            candidate = root / "candidate.png"
            Image.new("RGB", (1024, 1536), "#49687a").save(candidate)
            self._write(
                art / "art_manifest.json",
                {
                    "files": [
                        {
                            "path": "portraits/old.png",
                            "eras": ["古典修仙纪"],
                        }
                    ]
                },
            )
            self._write(
                data / "character_art_v1.json",
                {
                    "characters": [
                        {
                            "id": "hero",
                            "display_name": "问道人",
                            "current_portrait": "res://art/portraits/old.png",
                            "replacement_target": "res://art/portraits/hero_v1.png",
                            "release_status": "identity_anchor_required",
                        }
                    ],
                    "storyboards": [],
                },
            )
            self._write(
                data / "events_v014.json",
                [
                    {
                        "id": "hero_event",
                        "character_id": "hero",
                        "portrait": "res://art/portraits/old.png",
                        "portrait_mode": "focus",
                    }
                ],
            )
            self._write(
                data / "story_arcs_v1.json",
                {
                    "arcs": [
                        {
                            "id": "hero_arc",
                            "character_id": "hero",
                            "portrait": "res://art/portraits/old.png",
                            "portrait_mode": "focus",
                        }
                    ]
                },
            )
            report = root / "review.json"
            self._write(
                report,
                {
                    "schema_version": 1,
                    "kind": "portrait",
                    "automated_pass": True,
                    "visual_review_required": True,
                    "selection_failures": [],
                    "candidates": [
                        {
                            "path": str(candidate.resolve()),
                            "sha256": promote.sha256(candidate),
                            "automated_pass": True,
                        }
                    ],
                },
            )

            promote.verify_review_report(candidate, report, "portrait")
            target = promote.promote_character(root, "hero", candidate, report)

            self.assertEqual(target, "res://art/portraits/hero_v1.png")
            self.assertTrue((art / "portraits" / "hero_v1.png").is_file())
            manifest = json.loads((art / "art_manifest.json").read_text(encoding="utf-8"))
            self.assertIn(
                "portraits/hero_v1.png",
                [entry["path"] for entry in manifest["files"]],
            )
            character = json.loads(
                (data / "character_art_v1.json").read_text(encoding="utf-8")
            )["characters"][0]
            self.assertEqual(character["release_status"], "approved")
            self.assertEqual(character["current_portrait"], target)
            event = json.loads((data / "events_v014.json").read_text(encoding="utf-8"))[0]
            self.assertEqual(event["portrait"], target)
            arc = json.loads((data / "story_arcs_v1.json").read_text(encoding="utf-8"))["arcs"][0]
            self.assertEqual(arc["portrait"], target)

    def test_storyboard_promotion_binds_the_selected_stage(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            data = root / "godot" / "data"
            art = root / "godot" / "art"
            data.mkdir(parents=True)
            art.mkdir(parents=True)
            candidate = root / "storyboard.png"
            Image.new("RGB", (1536, 1024), "#53606a").save(candidate)
            self._write(art / "art_manifest.json", {"files": []})
            self._write(
                data / "character_art_v1.json",
                {
                    "characters": [],
                    "storyboards": [
                        {
                            "id": "jade_first_warmth",
                            "display_name": "旧玉初醒",
                            "target": "res://art/scenes/story_jade_first_warmth_v1.png",
                            "status": "asset_required",
                            "story_binding": {"arc_id": "jade", "phase": "main", "stage": 0},
                        }
                    ],
                },
            )
            self._write(
                data / "story_arcs_v1.json",
                {
                    "arcs": [
                        {
                            "id": "jade",
                            "main": [{"id": "jade_main_1", "art": {"motion_profile": "spectral"}}],
                        }
                    ]
                },
            )
            report = root / "review.json"
            self._write(
                report,
                {
                    "schema_version": 1,
                    "kind": "storyboard",
                    "automated_pass": True,
                    "visual_review_required": True,
                    "selection_failures": [],
                    "candidates": [
                        {
                            "path": str(candidate.resolve()),
                            "sha256": promote.sha256(candidate),
                            "automated_pass": True,
                        }
                    ],
                },
            )

            target = promote.promote_storyboard(root, "jade_first_warmth", candidate, report)

            self.assertEqual(target, "res://art/scenes/story_jade_first_warmth_v1.png")
            storyboard = json.loads(
                (data / "character_art_v1.json").read_text(encoding="utf-8")
            )["storyboards"][0]
            self.assertEqual(storyboard["status"], "approved")
            node = json.loads((data / "story_arcs_v1.json").read_text(encoding="utf-8"))["arcs"][0]["main"][0]
            self.assertEqual(node["art"]["scene"], target)
            self.assertEqual(node["art"]["portrait_mode"], "scene_only")

    @staticmethod
    def _write(path: Path, value: object) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value, ensure_ascii=False), encoding="utf-8")


if __name__ == "__main__":
    unittest.main()
