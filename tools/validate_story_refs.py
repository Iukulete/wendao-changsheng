#!/usr/bin/env python3
"""Validate generated story-character references against authored registries."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "godot" / "data"
CHARACTERS = DATA / "characters"
GENERATED = DATA / "generated"


def load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def combat_ids() -> set[str]:
    result: set[str] = set()
    target_path = DATA / "combat_sprite_targets_v1.json"
    if target_path.exists():
        data = load(target_path)
        result.update(data.get("named_characters", {}).keys())
        result.update(
            item.get("id")
            for item in data.get("procedural_enemy_targets", [])
            if isinstance(item, dict) and isinstance(item.get("id"), str)
        )
    queue_path = DATA / "monster_asset_queue_v1.json"
    if queue_path.exists():
        data = load(queue_path)
        result.update(
            item.get("id")
            for item in data.get("targets", [])
            if isinstance(item, dict) and isinstance(item.get("id"), str)
        )
    return result


def main() -> int:
    errors: list[str] = []
    registry = load(CHARACTERS / "character_registry_v2.json")
    groups = load(CHARACTERS / "character_groups_v1.json")
    character_ids = set(registry.get("characters", {}))
    group_ids = set(groups.get("groups", {}))
    known_ids = character_ids | group_ids
    known_combat_ids = combat_ids()

    unresolved_path = GENERATED / "unresolved_character_mentions_v1.json"
    mentions_path = GENERATED / "character_mentions_v1.json"
    story_path = GENERATED / "story_event_refs_v1.json"
    combat_path = GENERATED / "combat_character_refs_v1.json"
    required = (unresolved_path, mentions_path, story_path, combat_path)
    for path in required:
        if not path.exists():
            errors.append(f"missing generated report: {path.relative_to(ROOT)}")
    if errors:
        for error in errors:
            print(f"ERROR {error}")
        return 1

    unresolved = load(unresolved_path).get("mentions", [])
    structured_unresolved = [
        item
        for item in unresolved
        if item.get("kind") in {"structured_reference", "combat_reference", "cpp_social_definition"}
    ]
    for item in structured_unresolved:
        errors.append(
            f"unresolved structured reference {item.get('source')} {item.get('path')} "
            f"{item.get('raw_name')!r}"
        )

    mentions = load(mentions_path).get("mentions", [])
    for item in mentions:
        resolved_id = item.get("resolved_id")
        if not resolved_id:
            continue
        kind = item.get("kind")
        if kind == "combat_asset_reference":
            if resolved_id not in known_combat_ids:
                errors.append(f"unknown combat asset {resolved_id!r} at {item.get('path')}")
        elif kind in {"structured_reference", "combat_reference", "cpp_social_definition", "text_mention", "cpp_alias_literal"}:
            if resolved_id not in known_ids:
                errors.append(f"unknown authored target {resolved_id!r} at {item.get('path')}")

    story_refs = load(story_path).get("references", [])
    combat_refs = load(combat_path).get("references", [])
    for item in combat_refs:
        if item.get("resolved_id") not in known_ids | known_combat_ids:
            errors.append(f"combat ref outside registries: {item.get('resolved_id')!r}")
    if not story_refs:
        errors.append("story_event_refs_v1 contains no references")

    summary = load(mentions_path).get("summary", {})
    print("STORY REFERENCES", "PASS" if not errors else "FAIL")
    print(f"MENTIONS {summary.get('mentions', len(mentions))}")
    print(f"STRUCTURED REFERENCES {summary.get('structured_mentions', 0)}")
    print(f"UNRESOLVED CHARACTERS {len(structured_unresolved)}")
    print(f"COMBAT REFERENCES {len(combat_refs)}")
    print(f"TEXT CANDIDATES {summary.get('text_mentions', 0)}")
    for error in errors:
        print(f"ERROR {error}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
