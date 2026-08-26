#!/usr/bin/env python3
"""Validate pilot dialogue graphs before they are loaded by Godot."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "godot" / "data"
DIALOGUE = DATA / "dialogue"
CHARACTERS = DATA / "characters"
ALLOWED_TYPES = {"line", "choice", "condition", "check", "effect", "combat", "end"}
EFFECT_TYPES = {
    "relation_delta",
    "reputation_delta",
    "karma_delta",
    "set_flag",
    "character_outfit",
    "character_expression",
    "set_variable",
}


def load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def combat_ids() -> set[str]:
    result: set[str] = set()
    target_path = DATA / "combat_sprite_targets_v1.json"
    if target_path.exists():
        data = load(target_path)
        result.update(data.get("named_characters", {}).keys())
        result.update(item.get("id") for item in data.get("procedural_enemy_targets", []) if isinstance(item, dict))
    event_path = DATA / "events_v014.json"
    if event_path.exists():
        def walk(value: Any) -> None:
            if isinstance(value, dict):
                if isinstance(value.get("encounter"), dict):
                    enemy_id = value["encounter"].get("enemy_id")
                    if isinstance(enemy_id, str):
                        result.add(enemy_id)
                for child in value.values():
                    walk(child)
            elif isinstance(value, list):
                for child in value:
                    walk(child)
        walk(load(event_path))
    return result


def targets(node: dict[str, Any]) -> list[str]:
    result = [str(node[field]) for field in ("next", "if_true", "if_false", "success", "failure") if node.get(field)]
    if node.get("type") == "choice":
        result.extend(str(choice["next"]) for choice in node.get("choices", []) if isinstance(choice, dict) and choice.get("next"))
    if node.get("type") == "combat":
        result.extend(str(target) for target in node.get("return_routes", {}).values() if target)
    return result


def condition_ok(value: Any) -> bool:
    if value is None:
        return True
    if not isinstance(value, dict):
        return False
    op = value.get("op")
    if op in {"all", "any"}:
        return isinstance(value.get("args"), list) and all(condition_ok(child) for child in value["args"])
    if op == "not":
        return condition_ok(value.get("arg"))
    if op in {"flag", "relation", "reputation", "karma", "stat", "variable", "generation"}:
        return isinstance(value.get("operator", "=="), str) and "value" in value
    return False


def main() -> int:
    errors: list[str] = []
    index = load(DIALOGUE / "dialogue_index_v1.json")
    registry = load(CHARACTERS / "character_registry_v2.json")
    character_ids = set(registry.get("characters", {})) | {"narrator", "player"}
    encounter_ids = combat_ids()
    scenes: dict[str, dict[str, Any]] = {}
    for entry in index.get("scenes", []):
        if not isinstance(entry, dict):
            errors.append("invalid index entry")
            continue
        scene_id = str(entry.get("scene_id", ""))
        path_text = str(entry.get("path", ""))
        if not path_text.startswith("res://"):
            errors.append(f"{scene_id}: path must use res://")
            continue
        path = ROOT / "godot" / path_text.removeprefix("res://")
        if not path.exists():
            errors.append(f"{scene_id}: missing scene file")
            continue
        scene = load(path)
        scenes[scene_id] = scene
        if scene.get("scene_id") != scene_id or scene.get("schema_version") != 1:
            errors.append(f"{scene_id}: header mismatch")
        nodes = scene.get("nodes", [])
        ids = {str(node.get("id")) for node in nodes if isinstance(node, dict)}
        if scene.get("entry_node") not in ids:
            errors.append(f"{scene_id}: entry node missing")
        for node in nodes:
            if not isinstance(node, dict):
                errors.append(f"{scene_id}: non-object node")
                continue
            node_id = str(node.get("id", ""))
            node_type = node.get("type")
            if not node_id or node_type not in ALLOWED_TYPES:
                errors.append(f"{scene_id}/{node_id}: invalid node header")
            if node_type == "line" and node.get("speaker_id") not in character_ids:
                errors.append(f"{scene_id}/{node_id}: unknown speaker {node.get('speaker_id')!r}")
            if node_type == "choice":
                if not isinstance(node.get("choices"), list) or not node["choices"]:
                    errors.append(f"{scene_id}/{node_id}: empty choice node")
                for choice in node.get("choices", []):
                    if not isinstance(choice, dict) or not choice.get("id") or not choice.get("next"):
                        errors.append(f"{scene_id}/{node_id}: malformed choice")
                    if isinstance(choice, dict) and not condition_ok(choice.get("condition")):
                        errors.append(f"{scene_id}/{node_id}/{choice.get('id')}: invalid condition")
                    for effect in choice.get("effects", []) if isinstance(choice, dict) else []:
                        if not isinstance(effect, dict) or effect.get("type") not in EFFECT_TYPES:
                            errors.append(f"{scene_id}/{node_id}: invalid choice effect")
            if node_type == "condition" and not condition_ok(node.get("condition")):
                errors.append(f"{scene_id}/{node_id}: invalid condition")
            if node_type == "check":
                check = node.get("check", {})
                if not isinstance(check, dict) or not check.get("check_id") or not node.get("success") or not node.get("failure"):
                    errors.append(f"{scene_id}/{node_id}: malformed check")
            if node_type == "combat" and node.get("encounter_id") not in encounter_ids:
                errors.append(f"{scene_id}/{node_id}: unknown encounter {node.get('encounter_id')!r}")
            for effect in node.get("effects", []):
                if not isinstance(effect, dict) or effect.get("type") not in EFFECT_TYPES:
                    errors.append(f"{scene_id}/{node_id}: invalid node effect")
                elif effect.get("type") in {"relation_delta", "character_outfit", "character_expression"} and effect.get("character_id") not in character_ids:
                    errors.append(f"{scene_id}/{node_id}: effect references unknown character")
            for target in targets(node):
                if target not in ids:
                    errors.append(f"{scene_id}/{node_id}: broken target {target}")
        reachable = set()
        todo = [scene.get("entry_node", "")]
        by_id = {str(node.get("id")): node for node in nodes if isinstance(node, dict)}
        while todo:
            current = todo.pop()
            if current in reachable or current not in by_id:
                continue
            reachable.add(current)
            todo.extend(targets(by_id[current]))
        if reachable != ids:
            errors.append(f"{scene_id}: unreachable nodes {sorted(ids - reachable)}")

    required_shapes = {
        "qingheng_first_meeting": {"choice", "effect"},
        "xuanheng_first_inquiry": {"condition", "check"},
        "shuangya_first_intercept": {"combat"},
    }
    for scene_id, expected in required_shapes.items():
        actual = {node.get("type") for node in scenes.get(scene_id, {}).get("nodes", []) if isinstance(node, dict)}
        if not expected.issubset(actual):
            errors.append(f"{scene_id}: missing pilot node types {sorted(expected - actual)}")

    print("DIALOGUE GRAPH", "PASS" if not errors else "FAIL")
    print(f"SCENES {len(scenes)}")
    print(f"BROKEN NODES {sum('broken target' in error for error in errors)}")
    print(f"ERRORS {len(errors)}")
    for error in errors:
        print(f"ERROR {error}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
