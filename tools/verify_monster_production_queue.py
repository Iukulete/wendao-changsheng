# -*- coding: utf-8 -*-
"""Validate the monster production queue against runtime sprite data.

This is a queue/contract audit, not a substitute for visual identity review.
It catches missing files, broken PNG grids, rank/frame-count mismatches, and
drift between the v1 encounter target list and the v2 production queue.
"""

from __future__ import annotations

import json
import struct
import sys
from pathlib import Path, PurePosixPath
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
QUEUE = ROOT / "godot" / "data" / "monsters" / "monster_production_queue_v2.json"
LEGACY_QUEUE = ROOT / "godot" / "data" / "monster_asset_queue_v1.json"
ANIMATIONS = ROOT / "godot" / "data" / "combat_sprite_animations_v1.json"
TARGETS = ROOT / "godot" / "data" / "combat_sprite_targets_v1.json"
ART_ROOT = ROOT / "godot" / "art"

BODY_PLANS = {
    "HUM_L",
    "HUM_H",
    "GIANT",
    "QUAD_L",
    "QUAD_H",
    "FLOAT",
    "AMORPH",
    "SERPENT",
    "INSECT",
    "MULTI_LIMB",
    "CONSTRUCT",
    "AVIAN",
    "BURROW",
}
COMBAT_ROLES = {
    "bruiser",
    "tank",
    "skirmisher",
    "ranged",
    "caster",
    "controller",
    "assassin",
    "support",
    "summoner",
    "boss",
}
RANK_FRAME_RANGES = {
    "normal": (16, 20),
    "elite": (20, 28),
    "boss": (24, 48),
}
REQUIRED_CLIPS = {"idle", "charge", "guard", "attack", "spell", "hit"}
ALLOWED_SOURCE_STATUSES = {
    "legacy_v1_runtime_qa_pending",
    "generated_web_pixelized_pending_runtime_qa",
}


def runtime_path(value: Any) -> Path | None:
    if not isinstance(value, str) or not value.startswith("res://art/"):
        return None
    relative = PurePosixPath(value.removeprefix("res://art/"))
    if not relative.parts or ".." in relative.parts:
        return None
    resolved = ART_ROOT.joinpath(*relative.parts).resolve()
    try:
        resolved.relative_to(ART_ROOT.resolve())
    except ValueError:
        return None
    return resolved


def png_info(path: Path) -> tuple[int, int, int]:
    payload = path.read_bytes()
    if len(payload) < 26 or payload[:8] != b"\x89PNG\r\n\x1a\n" or payload[12:16] != b"IHDR":
        raise ValueError(f"not a PNG with an IHDR chunk: {path}")
    width, height = struct.unpack(">II", payload[16:24])
    return width, height, payload[25]


def target_entries(data: dict[str, Any]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    named = data.get("named_characters", {})
    if isinstance(named, dict):
        for key, value in named.items():
            if isinstance(value, dict):
                entry = value.copy()
                entry.setdefault("id", key)
                result.append(entry)
    procedural = data.get("procedural_enemy_targets", [])
    if isinstance(procedural, list):
        result.extend(value for value in procedural if isinstance(value, dict))
    return result


def main() -> int:
    queue = json.loads(QUEUE.read_text(encoding="utf-8"))
    legacy = json.loads(LEGACY_QUEUE.read_text(encoding="utf-8"))
    animations = json.loads(ANIMATIONS.read_text(encoding="utf-8"))
    combat_targets = json.loads(TARGETS.read_text(encoding="utf-8"))

    failures: list[str] = []
    warnings: list[str] = []
    if queue.get("schema_version") != 2:
        failures.append("v2 queue schema_version must be 2")
    entries = queue.get("targets", [])
    if not isinstance(entries, list) or not entries:
        failures.append("v2 queue has no targets list")
        entries = []

    by_id: dict[str, dict[str, Any]] = {}
    for entry in entries:
        if not isinstance(entry, dict):
            failures.append("v2 queue contains a non-object target")
            continue
        monster_id = str(entry.get("monster_id", ""))
        if not monster_id:
            failures.append("v2 target is missing monster_id")
            continue
        if monster_id in by_id:
            failures.append(f"duplicate v2 monster_id: {monster_id}")
        by_id[monster_id] = entry
        missing = [
            key
            for key in (
                "era",
                "family_id",
                "body_plan",
                "combat_role",
                "rank",
                "signature_organs",
                "palette_profile",
                "animation_tier",
                "candidate_path",
                "source_status",
            )
            if key not in entry
        ]
        if missing:
            failures.append(f"{monster_id}: missing queue fields {missing}")
        if entry.get("body_plan") not in BODY_PLANS:
            failures.append(f"{monster_id}: invalid body_plan {entry.get('body_plan')!r}")
        if entry.get("combat_role") not in COMBAT_ROLES:
            failures.append(f"{monster_id}: invalid combat_role {entry.get('combat_role')!r}")
        if entry.get("rank") not in RANK_FRAME_RANGES:
            failures.append(f"{monster_id}: invalid rank {entry.get('rank')!r}")
        organs = entry.get("signature_organs")
        if not isinstance(organs, list) or len(organs) < 2 or any(not str(item).strip() for item in organs):
            failures.append(f"{monster_id}: signature_organs needs at least two readable anchors")
        if entry.get("source_status") not in ALLOWED_SOURCE_STATUSES:
            failures.append(f"{monster_id}: unrecognized source_status {entry.get('source_status')!r}")

    legacy_ids = {
        str(entry.get("id"))
        for entry in legacy.get("targets", [])
        if isinstance(entry, dict) and entry.get("id")
    }
    if legacy_ids != set(by_id):
        failures.append(
            "v1/v2 monster target IDs drift: "
            f"only_v1={sorted(legacy_ids - set(by_id))}, only_v2={sorted(set(by_id) - legacy_ids)}"
        )

    profiles = animations.get("characters", {})
    if not isinstance(profiles, dict):
        failures.append("combat animation data has no characters object")
        profiles = {}
    target_map = {
        str(entry.get("id")): entry
        for entry in target_entries(combat_targets)
        if entry.get("id")
    }

    checked = 0
    for monster_id, entry in by_id.items():
        candidate_path = entry.get("candidate_path")
        candidate_file = runtime_path(candidate_path)
        if candidate_file is None or "combat" not in candidate_file.parts:
            failures.append(f"{monster_id}: candidate_path must stay under res://art/combat/")
        elif not candidate_file.is_file():
            failures.append(f"{monster_id}: candidate sprite is missing: {candidate_path}")

        if monster_id not in profiles:
            failures.append(f"{monster_id}: no animation profile")
            continue
        profile = profiles[monster_id]
        if not isinstance(profile, dict):
            failures.append(f"{monster_id}: animation profile is not an object")
            continue
        profile_path = runtime_path(profile.get("sheet_path"))
        if profile_path != candidate_file:
            failures.append(f"{monster_id}: queue and animation sheet paths disagree")
        target = target_map.get(monster_id)
        if target is None:
            failures.append(f"{monster_id}: no combat target entry")
        elif target.get("sheet_path") != candidate_path:
            failures.append(f"{monster_id}: queue and combat target sheet paths disagree")

        try:
            if candidate_file is None or not candidate_file.is_file():
                continue
            width, height, color_type = png_info(candidate_file)
        except (OSError, ValueError) as exc:
            failures.append(f"{monster_id}: {exc}")
            continue
        columns = int(profile.get("columns", 0))
        rows = int(profile.get("rows", 0))
        frame_size = profile.get("frame_size", [])
        if columns <= 0 or rows <= 0 or width % columns or height % rows:
            failures.append(f"{monster_id}: invalid {width}x{height} grid {columns}x{rows}")
        elif frame_size != [width // columns, height // rows]:
            failures.append(f"{monster_id}: frame_size {frame_size} does not match PNG grid")
        if color_type not in (4, 6):
            failures.append(f"{monster_id}: sprite has no alpha channel (PNG color type {color_type})")
        frame_count = columns * rows
        minimum, maximum = RANK_FRAME_RANGES.get(str(entry.get("rank")), (0, -1))
        if not minimum <= frame_count <= maximum:
            failures.append(
                f"{monster_id}: {entry.get('rank')} requires {minimum}-{maximum} frames, found {frame_count}"
            )
        clips = profile.get("clips", {})
        if not isinstance(clips, dict):
            failures.append(f"{monster_id}: clips is not an object")
            continue
        missing_clips = REQUIRED_CLIPS - set(clips)
        if missing_clips:
            failures.append(f"{monster_id}: missing clips {sorted(missing_clips)}")
        if entry.get("rank") == "boss" and "phase_change" not in clips:
            failures.append(f"{monster_id}: boss profile needs phase_change clip")
        for clip_id, clip in clips.items():
            if not isinstance(clip, dict) or not isinstance(clip.get("frames"), list) or not clip["frames"]:
                failures.append(f"{monster_id}.{clip_id}: empty or invalid frames")
                continue
            invalid = [frame for frame in clip["frames"] if not isinstance(frame, int) or not 0 <= frame < frame_count]
            if invalid:
                failures.append(f"{monster_id}.{clip_id}: invalid frame indexes {invalid}")
            if float(clip.get("fps", 0)) <= 0:
                failures.append(f"{monster_id}.{clip_id}: non-positive fps")
        portrait_path = entry.get("portrait_path")
        if portrait_path and (runtime_path(portrait_path) is None or not runtime_path(portrait_path).is_file()):
            warnings.append(f"{monster_id}: declared narrative portrait is not present yet")
        checked += 1

    if failures:
        print("Monster production verification failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print(f"Monster production verified: {checked} targets, queue/runtime IDs and transparent frame grids aligned.")
    if warnings:
        print(f"WARNINGS {len(warnings)}")
        for warning in warnings:
            print(f"- {warning}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
