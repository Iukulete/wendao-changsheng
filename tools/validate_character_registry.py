#!/usr/bin/env python3
"""Validate the v2 authored-character registry and its art-safety gates."""

from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CHARACTER_DIR = ROOT / "godot" / "data" / "characters"
GODOT_DIR = ROOT / "godot"
ID_PATTERN = re.compile(r"^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$")
ALLOWED_AGE_GROUPS = {"adult", "adult_ensemble", "adult_unconfirmed", "unknown", "minor"}
ALLOWED_STATUSES = {"ready", "planned", "curated", "blocked", "deprecated"}
ALLOWED_SENSUALITY = {0, 1, 2, 3}


def load(name: str) -> Any:
    return json.loads((CHARACTER_DIR / name).read_text(encoding="utf-8-sig"))


def normalize(value: str) -> str:
    value = unicodedata.normalize("NFKC", value)
    return "".join(value.split()).casefold()


def resolve_res_path(path: str) -> Path | None:
    if not isinstance(path, str) or not path.startswith("res://"):
        return None
    return GODOT_DIR / path.removeprefix("res://")


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []

    registry = load("character_registry_v2.json")
    aliases = load("character_aliases_v1.json")
    groups = load("character_groups_v1.json")
    procedural = load("procedural_npc_archetypes_v1.json")

    if registry.get("schema_version") != 2:
        errors.append("registry schema_version must be 2")
    characters = registry.get("characters")
    if not isinstance(characters, dict) or not characters:
        errors.append("registry.characters must be a non-empty object")
        characters = {}

    character_ids = set(characters)
    for character_id, character in characters.items():
        if not isinstance(character_id, str) or not ID_PATTERN.fullmatch(character_id):
            errors.append(f"invalid character id: {character_id!r}")
        if not isinstance(character, dict):
            errors.append(f"{character_id}: entry must be an object")
            continue

        identity = character.get("identity", {})
        presentation = character.get("presentation_profile", {})
        visual = character.get("visual_identity", {})
        assets = character.get("assets", {})
        required_identity = ("display_name", "age_group", "narrative_tier")
        for field in required_identity:
            if not identity.get(field):
                errors.append(f"{character_id}: missing identity.{field}")
        age_group = identity.get("age_group")
        if age_group not in ALLOWED_AGE_GROUPS:
            errors.append(f"{character_id}: invalid age_group {age_group!r}")
        if not visual.get("body_type") or not visual.get("height_class"):
            errors.append(f"{character_id}: visual identity needs body_type and height_class")

        adult_only = presentation.get("adult_only")
        default = presentation.get("sensuality_default")
        maximum = presentation.get("sensuality_max")
        if not isinstance(adult_only, bool):
            errors.append(f"{character_id}: presentation_profile.adult_only must be boolean")
        if default not in ALLOWED_SENSUALITY or maximum not in ALLOWED_SENSUALITY:
            errors.append(f"{character_id}: sensuality must be an integer from 0 to 3")
        elif default > maximum:
            errors.append(f"{character_id}: sensuality_default exceeds sensuality_max")

        unsafe_age = age_group in {"unknown", "minor", "adult_unconfirmed"} or adult_only is False
        if unsafe_age and (default != 0 or maximum != 0):
            errors.append(f"{character_id}: unknown/minor/unconfirmed character must have sensuality 0")
        if age_group == "adult_unconfirmed" and adult_only is not False:
            errors.append(f"{character_id}: adult_unconfirmed must not be adult_only=true")

        master = assets.get("portrait_master", {})
        master_path = master.get("path")
        status = master.get("status")
        if status not in ALLOWED_STATUSES:
            errors.append(f"{character_id}: invalid portrait_master status {status!r}")
        resolved_master = resolve_res_path(master_path)
        if resolved_master is None or resolved_master.suffix.lower() != ".png":
            errors.append(f"{character_id}: portrait_master path must be res:// and .png")
        if status in {"ready", "curated"} and resolved_master is not None and not resolved_master.exists():
            errors.append(f"{character_id}: ready portrait does not exist: {master_path}")
        if status == "planned" and resolved_master is not None and resolved_master.exists():
            warnings.append(f"{character_id}: planned portrait already exists; update status after QA")

        outfits = assets.get("outfits", [])
        if not isinstance(outfits, list) or not outfits:
            errors.append(f"{character_id}: assets.outfits must be a non-empty list")
        for outfit in outfits if isinstance(outfits, list) else []:
            outfit_id = outfit.get("id", "<missing>")
            outfit_sensuality = outfit.get("sensuality")
            if outfit_sensuality not in ALLOWED_SENSUALITY:
                errors.append(f"{character_id}/{outfit_id}: invalid outfit sensuality")
            elif isinstance(maximum, int) and outfit_sensuality > maximum:
                errors.append(f"{character_id}/{outfit_id}: outfit sensuality exceeds character maximum")
            outfit_status = outfit.get("status")
            if outfit_status not in ALLOWED_STATUSES:
                errors.append(f"{character_id}/{outfit_id}: invalid outfit status {outfit_status!r}")

    group_data = groups.get("groups")
    group_ids = set(group_data) if isinstance(group_data, dict) else set()
    if groups.get("schema_version") != 1 or not isinstance(group_data, dict):
        errors.append("character_groups_v1 must have schema_version 1 and groups object")
    else:
        for group_id, group in group_data.items():
            if not ID_PATTERN.fullmatch(group_id):
                errors.append(f"invalid group id: {group_id!r}")
            members = group.get("members", [])
            if not isinstance(members, list) or not members:
                errors.append(f"{group_id}: members must be a non-empty list")
            for member in members if isinstance(members, list) else []:
                if member not in character_ids:
                    errors.append(f"{group_id}: unknown member {member!r}")

    if aliases.get("schema_version") != 1 or not isinstance(aliases.get("aliases"), dict):
        errors.append("character_aliases_v1 must have schema_version 1 and aliases object")
    else:
        seen_aliases: dict[str, str] = {}
        for alias, target in aliases["aliases"].items():
            key = normalize(alias)
            if key in seen_aliases and seen_aliases[key] != target:
                errors.append(f"alias collision: {alias!r} maps to both {seen_aliases[key]!r} and {target!r}")
            seen_aliases[key] = target
            if target not in character_ids | group_ids:
                errors.append(f"alias {alias!r} points to unknown target {target!r}")
        for scoped in aliases.get("scoped_aliases", []):
            target = scoped.get("character_id")
            if target not in character_ids:
                errors.append(f"scoped alias points to unknown character: {target!r}")

    if procedural.get("schema_version") != 1 or not procedural.get("archetypes"):
        errors.append("procedural_npc_archetypes_v1 must contain archetypes")

    ready_count = sum(
        1
        for character in characters.values()
        if character.get("assets", {}).get("portrait_master", {}).get("status") in {"ready", "curated"}
    )
    planned_count = len(characters) - ready_count
    print("CHARACTER REGISTRY", "PASS" if not errors else "FAIL")
    print(f"AUTHORED CHARACTERS {len(characters)}")
    print(f"GROUPS {len(group_ids)}")
    print(f"READY MASTERS {ready_count}")
    print(f"PLANNED MASTERS {planned_count}")
    print(f"SAFETY WARNINGS {len(warnings)}")
    for warning in warnings:
        print(f"WARNING {warning}")
    for error in errors:
        print(f"ERROR {error}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
