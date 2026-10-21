from __future__ import annotations

import json
from pathlib import Path

import pytest
from PIL import Image

from promote_character_art_v2 import promote, sha256


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_png(path: Path, size: tuple[int, int], color: tuple[int, int, int, int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.new("RGBA", size, color).save(path, format="PNG")


def write_review(path: Path, kind: str, candidate: Path) -> None:
    write_json(
        path,
        {
            "schema_version": 1,
            "kind": kind,
            "automated_pass": True,
            "visual_review_required": True,
            "candidates": [
                {
                    "path": str(candidate.resolve()),
                    "sha256": sha256(candidate),
                    "automated_pass": True,
                }
            ],
        },
    )


def test_promote_planned_character_updates_all_runtime_surfaces(tmp_path: Path) -> None:
    root = tmp_path
    write_json(
        root / "godot/data/characters/character_registry_v2.json",
        {
            "schema_version": 2,
            "characters": {
                "fixture": {
                    "identity": {"display_name": "测试角色"},
                    "assets": {
                        "portrait_master": {"path": "res://art/portraits/fixture_v1.png", "status": "planned"},
                        "dialogue_bust": {"path": "res://art/dialogue/fixture/default_bust.png", "status": "planned"},
                        "avatar": {"path": "res://art/dialogue/fixture/avatar.png", "status": "planned"},
                    },
                }
            },
        },
    )
    write_json(
        root / "godot/data/characters/art_production_queue_v2.json",
        {
            "active_target_id": "fixture",
            "single_character_at_a_time": True,
            "targets": [
                {"character_id": "fixture", "stage": "portrait_master", "status": "queued"},
                {"character_id": "next", "stage": "identity_card", "status": "queued", "blocked_by": "fixture"},
            ],
        },
    )
    write_json(root / "godot/data/characters/identity_cards_v1.json", {"cards": {"fixture": {}}})
    write_json(root / "godot/art/art_manifest.json", {"files": []})

    candidate = root / ".tmp/fixture/portrait.png"
    bust = root / ".tmp/fixture/bust.png"
    avatar = root / ".tmp/fixture/avatar.png"
    portrait_report = root / ".tmp/fixture/portrait-report.json"
    bust_report = root / ".tmp/fixture/bust-report.json"
    write_png(candidate, (1024, 1536), (25, 50, 65, 255))
    write_png(bust, (1024, 1024), (25, 50, 65, 255))
    write_png(avatar, (512, 512), (25, 50, 65, 255))
    write_review(portrait_report, "portrait", candidate)
    write_review(bust_report, "dialogue_bust", bust)

    queue_path = root / "godot/data/characters/art_production_queue_v2.json"
    queue_fixture = json.loads(queue_path.read_text(encoding="utf-8"))
    queue_fixture["targets"][0]["stage"] = "identity_card"
    queue_path.write_text(json.dumps(queue_fixture, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    with pytest.raises(RuntimeError, match="promotion requires the queued portrait_master stage"):
        promote(root, "fixture", candidate, portrait_report, bust, bust_report, avatar)
    queue_fixture["targets"][0]["stage"] = "portrait_master"
    queue_path.write_text(json.dumps(queue_fixture, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    promote(root, "fixture", candidate, portrait_report, bust, bust_report, avatar)

    registry = json.loads((root / "godot/data/characters/character_registry_v2.json").read_text(encoding="utf-8"))
    assets = registry["characters"]["fixture"]["assets"]
    assert all(asset["status"] == "ready" for asset in assets.values())
    assert (root / "godot/art/portraits/fixture_v1.png").is_file()
    assert (root / "godot/art/dialogue/fixture/default_bust.png").is_file()
    assert (root / "godot/art/dialogue/fixture/avatar.png").is_file()

    queue = json.loads((root / "godot/data/characters/art_production_queue_v2.json").read_text(encoding="utf-8"))
    assert queue["targets"][0]["stage"] == "runtime_gate"
    assert queue["targets"][0]["status"] == "ready"
    assert queue["active_target_id"] == "next"
    assert queue["targets"][1]["stage"] == "portrait_master"
    assert "blocked_by" not in queue["targets"][1]
    cards = json.loads((root / "godot/data/characters/identity_cards_v1.json").read_text(encoding="utf-8"))
    assert cards["cards"]["fixture"]["portrait_prompt_status"] == "runtime_ready"
    manifest = json.loads((root / "godot/art/art_manifest.json").read_text(encoding="utf-8"))
    assert {entry["path"] for entry in manifest["files"]} == {
        "dialogue/fixture/avatar.png",
        "dialogue/fixture/default_bust.png",
        "portraits/fixture_v1.png",
    }

    runtime_master = root / "godot/art/portraits/fixture_v1.png"
    master_hash = sha256(runtime_master)
    queue["active_target_id"] = "fixture"
    write_json(root / "godot/data/characters/art_production_queue_v2.json", queue)
    with pytest.raises(RuntimeError, match="refusing to overwrite ready portrait_master"):
        promote(root, "fixture", candidate, portrait_report, bust, bust_report, avatar)
    assert sha256(runtime_master) == master_hash
