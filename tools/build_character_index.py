#!/usr/bin/env python3
"""Build a canonical character mention/index set from authored story sources.

This is intentionally a read-only extractor from the point of view of the
game runtime.  It produces generated reports; it does not rewrite story data
or replace the existing v1 event/catalog loaders.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from pathlib import Path
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "godot" / "data"
CHARACTER_DIR = DATA_DIR / "characters"
GENERATED_DIR = DATA_DIR / "generated"

STORY_SOURCES = (
    DATA_DIR / "story_arcs_v1.json",
    DATA_DIR / "events_v014.json",
)
CPP_SOURCE = ROOT / "src" / "wendao_enhanced.cpp"

STRUCTURED_KEYS = {
    "speaker",
    "speaker_id",
    "character",
    "character_id",
    "actor",
    "actor_id",
    "npc",
    "npc_id",
    "target",
    "target_id",
    "participants",
    "members",
    "companions",
    "relationship_target",
    "relationship_target_id",
    "combatants",
    "enemy",
    "enemy_id",
    "ally",
    "ally_id",
}

COMBAT_KEYS = {
    "combatants",
    "enemy",
    "enemy_id",
    "ally",
    "ally_id",
    "combat_character_id",
    "combatant_id",
}

TEXT_KEYS = {
    "text",
    "content",
    "description",
    "title",
    "label",
    "body",
    "narrative",
    "speaker_name",
    "display_name",
    "name",
}

SPECIAL_ALIASES = {
    "player": "protagonist",
    "主角": "protagonist",
    "玩家": "protagonist",
}


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def normalize(value: str) -> str:
    value = unicodedata.normalize("NFKC", value)
    return "".join(value.split()).casefold()


def display_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2) + "\n"


def iter_strings(value: Any) -> Iterable[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for item in value:
            yield from iter_strings(item)
    elif isinstance(value, dict):
        for item in value.values():
            yield from iter_strings(item)


def load_identity_maps() -> tuple[dict[str, str], set[str], set[str], set[str]]:
    registry = load_json(CHARACTER_DIR / "character_registry_v2.json")
    groups = load_json(CHARACTER_DIR / "character_groups_v1.json")
    aliases = load_json(CHARACTER_DIR / "character_aliases_v1.json")

    character_ids = set(registry.get("characters", {}))
    group_ids = set(groups.get("groups", {}))
    lookup: dict[str, str] = {}

    def add(raw: Any, target: str) -> None:
        if isinstance(raw, str) and raw.strip():
            lookup[normalize(raw)] = target

    for character_id, character in registry.get("characters", {}).items():
        add(character_id, character_id)
        identity = character.get("identity", {})
        add(identity.get("display_name"), character_id)
        for alias in identity.get("aliases", []):
            add(alias, character_id)

    for group_id in group_ids:
        add(group_id, group_id)
    for alias, target in aliases.get("aliases", {}).items():
        add(alias, target)
    for scoped in aliases.get("scoped_aliases", []):
        add(scoped.get("alias"), scoped.get("character_id", ""))
    for alias, target in SPECIAL_ALIASES.items():
        add(alias, target)

    combat_ids: set[str] = set()
    combat_targets = DATA_DIR / "combat_sprite_targets_v1.json"
    if combat_targets.exists():
        combat_data = load_json(combat_targets)
        combat_ids.update(combat_data.get("named_characters", {}).keys())
        combat_ids.update(
            item.get("id")
            for item in combat_data.get("procedural_enemy_targets", [])
            if isinstance(item, dict) and isinstance(item.get("id"), str)
        )
    monster_queue = DATA_DIR / "monster_asset_queue_v1.json"
    if monster_queue.exists():
        queue_data = load_json(monster_queue)
        combat_ids.update(
            item.get("id")
            for item in queue_data.get("targets", [])
            if isinstance(item, dict) and isinstance(item.get("id"), str)
        )

    valid_targets = character_ids | group_ids
    lookup = {key: value for key, value in lookup.items() if value in valid_targets}
    return lookup, character_ids, group_ids, combat_ids


def resolve(raw_value: Any, lookup: dict[str, str]) -> str | None:
    if not isinstance(raw_value, str):
        return None
    raw = raw_value.strip()
    if not raw:
        return None
    return lookup.get(normalize(raw))


def make_mention(
    *,
    source: str,
    source_path: str,
    path: str,
    key: str,
    raw_name: str,
    resolved_id: str | None,
    confidence: float,
    kind: str,
) -> dict[str, Any]:
    return {
        "source": source,
        "source_path": source_path,
        "path": path,
        "field": key,
        "raw_name": raw_name,
        "resolved_id": resolved_id,
        "confidence": confidence,
        "kind": kind,
    }


def record_structured_value(
    value: Any,
    *,
    source: str,
    source_path: str,
    path: str,
    key: str,
    lookup: dict[str, str],
    combat_ids: set[str],
    mentions: list[dict[str, Any]],
    unresolved: list[dict[str, Any]],
    story_refs: list[dict[str, Any]],
    combat_refs: list[dict[str, Any]],
) -> None:
    if isinstance(value, dict):
        # Support a future structured participant such as {"character_id": "..."}.
        for nested_key, nested_value in value.items():
            if nested_key in STRUCTURED_KEYS:
                record_structured_value(
                    nested_value,
                    source=source,
                    source_path=source_path,
                    path=f"{path}/{nested_key}",
                    key=nested_key,
                    lookup=lookup,
                    combat_ids=combat_ids,
                    mentions=mentions,
                    unresolved=unresolved,
                    story_refs=story_refs,
                    combat_refs=combat_refs,
                )
        return

    values = value if isinstance(value, list) else [value]
    for index, raw in enumerate(values):
        if not isinstance(raw, str):
            continue
        item_path = f"{path}/{index}" if isinstance(value, list) else path
        resolved_id = resolve(raw, lookup)
        is_combat_reference = key in COMBAT_KEYS or "combat" in path.casefold() or "/encounter/" in path
        if resolved_id is None and is_combat_reference and raw in combat_ids:
            resolved_id = raw
            kind = "combat_asset_reference"
        else:
            kind = "combat_reference" if is_combat_reference else "structured_reference"
        mention = make_mention(
            source=source,
            source_path=source_path,
            path=item_path,
            key=key,
            raw_name=raw,
            resolved_id=resolved_id,
            confidence=1.0 if resolved_id else 0.0,
            kind=kind,
        )
        mentions.append(mention)
        if resolved_id:
            story_refs.append(mention)
            if kind in {"combat_reference", "combat_asset_reference"}:
                combat_refs.append(mention)
        else:
            unresolved.append(mention)


def walk_authored_source(
    value: Any,
    *,
    source: str,
    source_path: str,
    path: str,
    lookup: dict[str, str],
    combat_ids: set[str],
    known_text_aliases: list[tuple[str, str]],
    mentions: list[dict[str, Any]],
    unresolved: list[dict[str, Any]],
    story_refs: list[dict[str, Any]],
    combat_refs: list[dict[str, Any]],
) -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            child_path = f"{path}/{key}"
            if key in STRUCTURED_KEYS:
                record_structured_value(
                    child,
                    source=source,
                    source_path=source_path,
                    path=child_path,
                    key=key,
                    lookup=lookup,
                    combat_ids=combat_ids,
                    mentions=mentions,
                    unresolved=unresolved,
                    story_refs=story_refs,
                    combat_refs=combat_refs,
                )
            if key in TEXT_KEYS and isinstance(child, str):
                normalized_child = normalize(child)
                for alias, target in known_text_aliases:
                    if normalize(alias) in normalized_child:
                        mentions.append(
                            make_mention(
                                source=source,
                                source_path=source_path,
                                path=child_path,
                                key=key,
                                raw_name=alias,
                                resolved_id=target,
                                confidence=0.6,
                                kind="text_mention",
                            )
                        )
            walk_authored_source(
                child,
                source=source,
                source_path=source_path,
                path=child_path,
                lookup=lookup,
                combat_ids=combat_ids,
                known_text_aliases=known_text_aliases,
                mentions=mentions,
                unresolved=unresolved,
                story_refs=story_refs,
                combat_refs=combat_refs,
            )
    elif isinstance(value, list):
        for index, child in enumerate(value):
            walk_authored_source(
                child,
                source=source,
                source_path=source_path,
                path=f"{path}/{index}",
                lookup=lookup,
                combat_ids=combat_ids,
                known_text_aliases=known_text_aliases,
                mentions=mentions,
                unresolved=unresolved,
                story_refs=story_refs,
                combat_refs=combat_refs,
            )


def scan_cpp(
    *,
    lookup: dict[str, str],
    known_text_aliases: list[tuple[str, str]],
    mentions: list[dict[str, Any]],
    unresolved: list[dict[str, Any]],
) -> None:
    if not CPP_SOURCE.exists():
        return
    source_text = CPP_SOURCE.read_text(encoding="utf-8", errors="replace")
    source_label = str(CPP_SOURCE.relative_to(ROOT)).replace("\\", "/")
    add_thread_pattern = re.compile(r"\b(Add[A-Za-z0-9_]+Thread)\s*\(\s*L\"([^\"]+)\"")
    for match in add_thread_pattern.finditer(source_text):
        function_name, raw_name = match.groups()
        line = source_text.count("\n", 0, match.start()) + 1
        resolved_id = resolve(raw_name, lookup)
        mention = make_mention(
            source="wendao_enhanced.cpp",
            source_path=source_label,
            path=f"line:{line}",
            key=function_name,
            raw_name=raw_name,
            resolved_id=resolved_id,
            confidence=1.0 if resolved_id else 0.0,
            kind="cpp_social_definition",
        )
        mentions.append(mention)
        if not resolved_id:
            unresolved.append(mention)

    # Keep literal-name hits useful for review, but deduplicate exact aliases.
    seen: set[tuple[str, int]] = set()
    for alias, target in known_text_aliases:
        if len(alias) < 2:
            continue
        start = 0
        while True:
            position = source_text.find(alias, start)
            if position < 0:
                break
            key = (alias, position)
            if key not in seen:
                seen.add(key)
                line = source_text.count("\n", 0, position) + 1
                mentions.append(
                    make_mention(
                        source="wendao_enhanced.cpp",
                        source_path=source_label,
                        path=f"line:{line}",
                        key="literal",
                        raw_name=alias,
                        resolved_id=target,
                        confidence=0.6,
                        kind="cpp_alias_literal",
                    )
                )
            start = position + len(alias)


def sort_mentions(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(
        items,
        key=lambda item: (
            item.get("source", ""),
            item.get("path", ""),
            item.get("field", ""),
            item.get("raw_name", ""),
            item.get("kind", ""),
        ),
    )


def build() -> tuple[dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any]]:
    lookup, character_ids, group_ids, combat_ids = load_identity_maps()
    known_text_aliases = sorted(
        ((alias, target) for alias, target in lookup.items() if len(alias) >= 2),
        key=lambda pair: len(pair[0]),
        reverse=True,
    )
    # lookup keys are normalized; use the authored alias text for text scans
    alias_file = load_json(CHARACTER_DIR / "character_aliases_v1.json")
    known_text_aliases = sorted(
        (
            (alias, target)
            for alias, target in alias_file.get("aliases", {}).items()
            if target in character_ids | group_ids and len(alias) >= 2
        ),
        key=lambda pair: len(pair[0]),
        reverse=True,
    )

    mentions: list[dict[str, Any]] = []
    unresolved: list[dict[str, Any]] = []
    story_refs: list[dict[str, Any]] = []
    combat_refs: list[dict[str, Any]] = []

    for source_path in STORY_SOURCES:
        if not source_path.exists():
            continue
        source_name = source_path.name
        authored = load_json(source_path)
        walk_authored_source(
            authored,
            source=source_name,
            source_path=str(source_path.relative_to(ROOT)).replace("\\", "/"),
            path="",
            lookup=lookup,
            combat_ids=combat_ids,
            known_text_aliases=known_text_aliases,
            mentions=mentions,
            unresolved=unresolved,
            story_refs=story_refs,
            combat_refs=combat_refs,
        )

    scan_cpp(
        lookup=lookup,
        known_text_aliases=known_text_aliases,
        mentions=mentions,
        unresolved=unresolved,
    )

    mentions = sort_mentions(mentions)
    unresolved = sort_mentions(unresolved)
    story_refs = sort_mentions(story_refs)
    combat_refs = sort_mentions(combat_refs)
    metadata = {
        "schema_version": 1,
        "generated_by": "tools/build_character_index.py",
        "registry": "godot/data/characters/character_registry_v2.json",
        "groups": "godot/data/characters/character_groups_v1.json",
        "source_files": [str(path.relative_to(ROOT)).replace("\\", "/") for path in STORY_SOURCES if path.exists()]
        + ([str(CPP_SOURCE.relative_to(ROOT)).replace("\\", "/")] if CPP_SOURCE.exists() else []),
        "summary": {
            "canonical_characters": len(character_ids),
            "canonical_groups": len(group_ids),
            "mentions": len(mentions),
            "structured_mentions": sum(item["kind"] in {"structured_reference", "combat_reference", "combat_asset_reference"} for item in mentions),
            "text_mentions": sum(item["kind"] == "text_mention" for item in mentions),
            "cpp_mentions": sum(item["source"] == "wendao_enhanced.cpp" for item in mentions),
            "unresolved_structured": sum(item["kind"] in {"structured_reference", "combat_reference", "cpp_social_definition"} for item in unresolved),
        },
    }
    return (
        {**metadata, "mentions": mentions},
        {**metadata, "mentions": unresolved},
        {**metadata, "references": story_refs},
        {**metadata, "references": combat_refs},
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check-unresolved",
        action="store_true",
        help="fail when a structured source reference cannot resolve to a character or group",
    )
    args = parser.parse_args()

    outputs = build()
    GENERATED_DIR.mkdir(parents=True, exist_ok=True)
    names = (
        "character_mentions_v1.json",
        "unresolved_character_mentions_v1.json",
        "story_event_refs_v1.json",
        "combat_character_refs_v1.json",
    )
    for name, payload in zip(names, outputs):
        (GENERATED_DIR / name).write_text(display_json(payload), encoding="utf-8")

    unresolved_structured = [
        item
        for item in outputs[1]["mentions"]
        if item["kind"] in {"structured_reference", "combat_reference", "cpp_social_definition"}
    ]
    summary = outputs[0]["summary"]
    print(
        "CHARACTER INDEX "
        f"mentions={summary['mentions']} "
        f"structured={summary['structured_mentions']} "
        f"text={summary['text_mentions']} "
        f"cpp={summary['cpp_mentions']} "
        f"unresolved_structured={len(unresolved_structured)}"
    )
    if unresolved_structured:
        for item in unresolved_structured[:20]:
            print(
                f"UNRESOLVED {item['source']} {item['path']} "
                f"{item['field']}={item['raw_name']!r}"
            )
    return 2 if args.check_unresolved and unresolved_structured else 0


if __name__ == "__main__":
    sys.exit(main())
