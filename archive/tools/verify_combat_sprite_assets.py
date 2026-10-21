# -*- coding: utf-8 -*-
"""Validate data-driven combat sprite atlases and their target registry."""

from __future__ import annotations

import json
import struct
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
ANIMATIONS = ROOT / "godot" / "data" / "combat_sprite_animations_v1.json"
TARGETS = ROOT / "godot" / "data" / "combat_sprite_targets_v1.json"
ART_ROOT = ROOT / "godot" / "art"


def runtime_path(value: Any) -> Path:
    if not isinstance(value, str) or not value.startswith("res://art/"):
        raise ValueError(f"invalid runtime art path: {value!r}")
    return ART_ROOT / value.removeprefix("res://art/")


def png_info(path: Path) -> tuple[int, int, int]:
    payload = path.read_bytes()
    if payload[:8] != b"\x89PNG\r\n\x1a\n" or payload[12:16] != b"IHDR":
        raise ValueError(f"not a PNG with an IHDR chunk: {path}")
    width, height = struct.unpack(">II", payload[16:24])
    color_type = payload[25]
    return width, height, color_type


def all_targets(data: dict[str, Any]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for group in ("named_characters", "procedural_enemy_targets"):
        values = data.get(group, {}) if group == "named_characters" else data.get(group, [])
        if isinstance(values, dict):
            for key, value in values.items():
                if isinstance(value, dict):
                    entry = value.copy()
                    entry.setdefault("id", key)
                    result.append(entry)
        elif isinstance(values, list):
            result.extend(value for value in values if isinstance(value, dict))
    return result


def main() -> int:
    animations = json.loads(ANIMATIONS.read_text(encoding="utf-8"))
    targets = json.loads(TARGETS.read_text(encoding="utf-8"))
    profiles = animations.get("characters", {})
    if not isinstance(profiles, dict) or not profiles:
        raise ValueError("combat animation data has no characters object")

    failures: list[str] = []
    checked = 0
    for profile_id, profile in profiles.items():
        if not isinstance(profile, dict):
            failures.append(f"{profile_id}: profile is not an object")
            continue
        try:
            sheet = runtime_path(profile.get("sheet_path"))
        except ValueError as exc:
            failures.append(f"{profile_id}: {exc}")
            continue
        if not sheet.is_file():
            failures.append(f"{profile_id}: missing sheet {sheet}")
            continue
        try:
            width, height, color_type = png_info(sheet)
        except (OSError, ValueError) as exc:
            failures.append(f"{profile_id}: {exc}")
            continue
        columns = int(profile.get("columns", 0))
        rows = int(profile.get("rows", 0))
        frame_size = profile.get("frame_size", [])
        if columns <= 0 or rows <= 0:
            failures.append(f"{profile_id}: invalid grid {columns}x{rows}")
            continue
        if width % columns or height % rows:
            failures.append(f"{profile_id}: {width}x{height} is not divisible by {columns}x{rows}")
        actual_frame_size = [width // columns, height // rows]
        if frame_size != actual_frame_size:
            failures.append(f"{profile_id}: frame_size {frame_size} != {actual_frame_size}")
        if color_type not in (4, 6):
            failures.append(f"{profile_id}: PNG has no alpha channel (color type {color_type})")
        clips = profile.get("clips", {})
        if not isinstance(clips, dict) or not clips:
            failures.append(f"{profile_id}: no clips")
        else:
            for clip_id, clip in clips.items():
                if not isinstance(clip, dict):
                    failures.append(f"{profile_id}.{clip_id}: clip is not an object")
                    continue
                frames = clip.get("frames", [])
                if not isinstance(frames, list) or not frames:
                    failures.append(f"{profile_id}.{clip_id}: empty frames")
                    continue
                invalid = [frame for frame in frames if not isinstance(frame, int) or frame < 0 or frame >= columns * rows]
                if invalid:
                    failures.append(f"{profile_id}.{clip_id}: invalid frame indexes {invalid}")
                if float(clip.get("fps", 0)) <= 0:
                    failures.append(f"{profile_id}.{clip_id}: non-positive fps")
        technique_clips = profile.get("technique_clips", {})
        if technique_clips is not None and not isinstance(technique_clips, dict):
            failures.append(f"{profile_id}: technique_clips is not an object")
        elif isinstance(technique_clips, dict):
            for technique_id, clip_id in technique_clips.items():
                if not isinstance(technique_id, str) or not technique_id.strip():
                    failures.append(f"{profile_id}: technique mapping has an empty id")
                if not isinstance(clip_id, str) or clip_id not in clips:
                    failures.append(
                        f"{profile_id}.{technique_id}: technique maps to missing clip {clip_id!r}"
                    )
        checked += 1

    target_count = 0
    for target in all_targets(targets):
        target_id = str(target.get("id", "<missing-id>"))
        sheet_path = target.get("sheet_path")
        status = str(target.get("status", ""))
        if not sheet_path:
            continue
        target_count += 1
        if target_id not in profiles:
            failures.append(f"target {target_id}: sheet exists but has no animation profile")
            continue
        try:
            target_file = runtime_path(sheet_path)
            profile_file = runtime_path(profiles[target_id].get("sheet_path"))
        except ValueError as exc:
            failures.append(f"target {target_id}: {exc}")
            continue
        if target_file != profile_file:
            failures.append(f"target {target_id}: target sheet and animation sheet disagree")
        if status == "generated_web_pending_runtime_qa" and not target_file.is_file():
            failures.append(f"target {target_id}: runtime-QA asset is missing")

    if failures:
        print("Combat sprite verification failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print(f"Combat sprites verified: {checked} animation profiles, {target_count} registered target sheets, RGBA grids and clip indexes valid.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
