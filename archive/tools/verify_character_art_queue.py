#!/usr/bin/env python3
"""Validate the v2 character-art queue and its single-target generation gate."""

from __future__ import annotations

import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
CHARACTER_DIR = ROOT / "godot" / "data" / "characters"
ALLOWED_STAGES = {
    "identity_card",
    "portrait_master",
    "portrait_recalibration_candidate",
    "dialogue_assets",
    "calibration",
    "runtime_gate",
}
ALLOWED_STATUSES = {"queued", "ready"}


def resolve_res_path(value: object) -> Path | None:
    text = str(value or "")
    if not text.startswith("res://"):
        return None
    return ROOT / "godot" / text[6:]


def is_versioned_png(value: object) -> bool:
    path = resolve_res_path(value)
    return path is not None and path.suffix.lower() == ".png" and "_v" in path.stem


def load(name: str) -> dict:
    return json.loads((CHARACTER_DIR / name).read_text(encoding="utf-8-sig"))


def main() -> int:
    errors: list[str] = []
    registry = load("character_registry_v2.json")
    queue = load("art_production_queue_v2.json")
    cards_path = CHARACTER_DIR / "identity_cards_v1.json"
    cards = load("identity_cards_v1.json") if cards_path.exists() else {"cards": {}}
    characters = registry.get("characters", {})
    targets = queue.get("targets")
    if registry.get("schema_version") != 2:
        errors.append("character registry schema_version must be 2")
    if queue.get("schema_version") != 2 or not isinstance(targets, list) or not targets:
        errors.append("art production queue schema_version must be 2 with targets")
        targets = []
    if not isinstance(characters, dict):
        errors.append("registry.characters must be an object")
        characters = {}
    if not isinstance(cards.get("cards"), dict):
        errors.append("identity_cards_v1.cards must be an object")
        cards["cards"] = {}
    if queue.get("single_character_at_a_time") is not True:
        errors.append("art production queue must explicitly enable single_character_at_a_time")

    target_by_id: dict[str, dict] = {}
    for target in targets:
        if not isinstance(target, dict):
            errors.append("queue target must be an object")
            continue
        character_id = str(target.get("character_id", ""))
        if not character_id or character_id in target_by_id:
            errors.append(f"duplicate or missing queue character_id: {character_id!r}")
            continue
        target_by_id[character_id] = target
        if target.get("stage") not in ALLOWED_STAGES:
            errors.append(f"{character_id}: unsupported queue stage {target.get('stage')!r}")
        if target.get("status") not in ALLOWED_STATUSES:
            errors.append(f"{character_id}: unsupported queue status {target.get('status')!r}")
        character = characters.get(character_id)
        if not isinstance(character, dict):
            errors.append(f"queue target is absent from registry: {character_id}")
            continue
        identity = character.get("identity", {})
        presentation = character.get("presentation_profile", {})
        combat = character.get("combat", {})
        for field, source in (
            ("body_class", character.get("visual_identity", {}).get("height_class")),
            ("age_group", identity.get("age_group")),
            ("presentation_default", presentation.get("sensuality_default")),
            ("presentation_max", presentation.get("sensuality_max")),
        ):
            if target.get(field) != source:
                errors.append(f"{character_id}: queue {field} disagrees with registry")
        if target.get("combat") != bool(combat.get("enabled", False)):
            errors.append(f"{character_id}: queue combat flag disagrees with registry")
        master = character.get("assets", {}).get("portrait_master", {})
        master_status = master.get("status") if isinstance(master, dict) else None
        card_id = target.get("identity_card_id")
        if master_status == "planned":
            if card_id != character_id:
                errors.append(f"{character_id}: planned target must point to its own identity card")
            card = cards["cards"].get(character_id)
            if not isinstance(card, dict):
                errors.append(f"{character_id}: planned target is missing its identity card")
            else:
                prompt_path = resolve_res_path(card.get("portrait_prompt_path"))
                if prompt_path is None or prompt_path.suffix.lower() != ".md" or not prompt_path.is_file():
                    errors.append(f"{character_id}: identity card prompt must resolve to an existing .md")
                for field in ("candidate_path", "master_path"):
                    if not is_versioned_png(card.get(field)):
                        errors.append(f"{character_id}: identity card {field} must be a versioned res:// PNG")
                registry_master = str(master.get("path", "")) if isinstance(master, dict) else ""
                if str(card.get("master_path", "")) != registry_master:
                    errors.append(f"{character_id}: identity card master_path disagrees with registry")
        elif card_id and card_id not in cards["cards"]:
            errors.append(f"{character_id}: queue points to missing identity card {card_id}")

        blocked_by = str(target.get("blocked_by", ""))
        if blocked_by and blocked_by == character_id:
            errors.append(f"{character_id}: queue target cannot block itself")

    active_id = str(queue.get("active_target_id", ""))
    single = bool(queue.get("single_character_at_a_time", False))
    portrait_targets = [
        character_id
        for character_id, target in target_by_id.items()
        if target.get("stage") == "portrait_master" and target.get("status") != "ready"
    ]
    if single:
        if len(portrait_targets) > 1:
            errors.append("single-character queue has multiple portrait_master targets: " + ", ".join(portrait_targets))
        if active_id and active_id not in target_by_id:
            errors.append(f"active_target_id is absent from queue: {active_id}")
        if active_id and active_id not in portrait_targets:
            errors.append(f"active target must be the only portrait_master target: {active_id}")
        if portrait_targets and not active_id:
            errors.append("pending portrait_master target requires active_target_id")
        if not portrait_targets and active_id:
            errors.append("active_target_id must be empty when no portrait_master target is pending")
        for character_id, target in target_by_id.items():
            if character_id == active_id:
                if target.get("blocked_by"):
                    errors.append(f"active target is unexpectedly blocked: {character_id}")
            elif target.get("stage") == "portrait_master" and target.get("status") != "ready":
                errors.append(f"non-active target entered portrait_master: {character_id}")

    if set(target_by_id) != set(characters):
        missing = sorted(set(characters) - set(target_by_id))
        extra = sorted(set(target_by_id) - set(characters))
        if missing:
            errors.append("registry characters missing from queue: " + ", ".join(missing))
        if extra:
            errors.append("queue targets missing from registry: " + ", ".join(extra))
    for character_id, target in target_by_id.items():
        blocked_by = str(target.get("blocked_by", ""))
        if blocked_by and blocked_by not in target_by_id:
            errors.append(f"{character_id}: blocked_by target is absent from queue: {blocked_by}")

    if single:
        planned_ids = {
            character_id
            for character_id, character in characters.items()
            if isinstance(character, dict)
            and isinstance(character.get("assets", {}).get("portrait_master"), dict)
            and character["assets"]["portrait_master"].get("status") == "planned"
        }
        incoming: dict[str, list[str]] = {}
        for character_id in planned_ids:
            target = target_by_id.get(character_id, {})
            blocked_by = str(target.get("blocked_by", ""))
            if character_id == active_id:
                if blocked_by:
                    errors.append(f"active target must be the chain head: {character_id}")
            elif not blocked_by:
                errors.append(f"planned target is not linked into the single-character chain: {character_id}")
            else:
                incoming.setdefault(blocked_by, []).append(character_id)
        for blocker, children in incoming.items():
            if len(children) > 1:
                errors.append("single-character chain branches after %s: %s" % (blocker, ", ".join(sorted(children))))
        if active_id in planned_ids:
            seen_chain: set[str] = set()
            current = active_id
            while current:
                if current in seen_chain:
                    errors.append("single-character chain contains a cycle at " + current)
                    break
                seen_chain.add(current)
                children = incoming.get(current, [])
                current = children[0] if children else ""
            if seen_chain != planned_ids:
                missing = sorted(planned_ids - seen_chain)
                if missing:
                    errors.append("single-character chain does not reach planned targets: " + ", ".join(missing))

    ready_registry_targets = sum(
        isinstance(characters.get(character_id), dict)
        and characters[character_id].get("assets", {}).get("portrait_master", {}).get("status") in {"ready", "curated"}
        for character_id in target_by_id
    )
    ready_queue_targets = sum(target.get("status") == "ready" for target in target_by_id.values())
    print("CHARACTER ART QUEUE", "PASS" if not errors else "FAIL")
    print(f"TARGETS {len(target_by_id)}")
    print(f"ACTIVE {active_id or '<none>'}")
    print(f"PORTRAIT_MASTER_PENDING {len(portrait_targets)}")
    print(f"READY_TARGETS {ready_registry_targets}")
    print(f"QUEUE_ARCHIVED_READY {ready_queue_targets}")
    for error in errors:
        print(f"ERROR {error}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
