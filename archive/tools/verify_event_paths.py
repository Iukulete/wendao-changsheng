#!/usr/bin/env python3
"""Validate that every authored event choice drives the six-path system."""

from __future__ import annotations

from collections import Counter
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
GODOT_ROOT = ROOT / "godot"
EVENTS_PATH = ROOT / "godot" / "data" / "events_v014.json"
SUPPORTED_ERAS = {
    "古典修仙纪",
    "灵机蒸汽纪",
    "星穹道网纪",
    "废土返道纪",
    "末法裂变纪",
    "仙朝鼎盛纪",
}
MIN_EVENTS_PER_ERA = 6
PATH_DIMENSIONS = {
    "compassion",
    "ambition",
    "defiance",
    "insight",
    "creation",
    "bonds",
}
PLAYER_DELTAS = {
    "exp",
    "hp",
    "mp",
    "karma",
    "dao_heart",
    "reputation",
    "enmity",
    "spirit_stones",
    "pills",
}
EVENT_TEXT_FIELDS = ("title", "description", "portrait_name", "portrait_title")
RESOURCE_FIELDS = ("scene", "portrait")
MIN_DELTA = -4
MAX_DELTA = 4
MAX_COSTLESS_CHOICES_PER_EVENT = 1
MIN_NEGATIVE_COVERAGE_PER_PATH = 2


def fail(message: str) -> None:
    raise ValueError(message)


def require_text(value: object, location: str) -> str:
    if not isinstance(value, str) or not value.strip():
        fail(f"{location} must be a non-empty string")
    return value


def validate_resource(value: object, location: str) -> None:
    resource_path = require_text(value, location)
    if not resource_path.startswith("res://"):
        fail(f"{location} must use a res:// path")
    relative = Path(resource_path.removeprefix("res://"))
    if relative.is_absolute() or ".." in relative.parts:
        fail(f"{location} escapes the Godot project: {resource_path}")
    disk_path = GODOT_ROOT / relative
    if not disk_path.is_file():
        fail(f"{location} does not exist: {resource_path}")


def main() -> int:
    events = json.loads(EVENTS_PATH.read_text(encoding="utf-8"))
    if not isinstance(events, list) or not events:
        fail("event catalog must be a non-empty JSON array")

    event_ids: set[str] = set()
    era_counts: Counter[str] = Counter()
    positive_coverage: Counter[str] = Counter()
    negative_coverage: Counter[str] = Counter()
    choice_count = 0
    costless_choice_count = 0

    for event_index, event in enumerate(events):
        if not isinstance(event, dict):
            fail(f"event[{event_index}] must be an object")
        event_id = require_text(event.get("id"), f"event[{event_index}].id")
        if event_id in event_ids:
            fail(f"duplicate event id: {event_id}")
        event_ids.add(event_id)

        era = require_text(event.get("era"), f"{event_id}.era")
        if era not in SUPPORTED_ERAS:
            fail(f"{event_id}.era is unsupported: {era}")
        era_counts[era] += 1
        for field in EVENT_TEXT_FIELDS:
            require_text(event.get(field), f"{event_id}.{field}")
        for field in RESOURCE_FIELDS:
            validate_resource(event.get(field), f"{event_id}.{field}")

        choices = event.get("choices")
        if not isinstance(choices, list) or len(choices) != 3:
            fail(f"{event_id}: choices must contain exactly three entries")

        event_costless_choices = 0
        for choice_index, choice in enumerate(choices):
            choice_count += 1
            location = f"{event_id}.choices[{choice_index}]"
            if not isinstance(choice, dict):
                fail(f"{location} must be an object")
            require_text(choice.get("text"), f"{location}.text")
            require_text(choice.get("outcome"), f"{location}.outcome")
            deltas = choice.get("deltas")
            if not isinstance(deltas, dict) or not deltas:
                fail(f"{location} must define non-empty deltas")
            unknown_deltas = set(deltas) - PLAYER_DELTAS
            if unknown_deltas:
                fail(f"{location} contains unknown player deltas: {sorted(unknown_deltas)}")
            for delta_id, delta in deltas.items():
                if isinstance(delta, bool) or not isinstance(delta, int):
                    fail(f"{location}.deltas.{delta_id} must be an integer")
            has_player_cost = any(
                (delta_id == "enmity" and delta > 0)
                or (delta_id != "enmity" and delta < 0)
                for delta_id, delta in deltas.items()
            )
            path_deltas = choice.get("path_deltas")
            if not isinstance(path_deltas, dict) or not path_deltas:
                fail(f"{location} must define non-empty path_deltas")

            unknown_paths = set(path_deltas) - PATH_DIMENSIONS
            if unknown_paths:
                fail(f"{location} contains unknown paths: {sorted(unknown_paths)}")

            has_positive_delta = False
            has_path_cost = False
            for path_id, delta in path_deltas.items():
                if isinstance(delta, bool) or not isinstance(delta, int):
                    fail(f"{location}.{path_id} must be an integer")
                if delta == 0 or not MIN_DELTA <= delta <= MAX_DELTA:
                    fail(
                        f"{location}.{path_id} must be a non-zero integer "
                        f"between {MIN_DELTA} and {MAX_DELTA}"
                    )
                if delta > 0:
                    has_positive_delta = True
                    positive_coverage[path_id] += 1
                else:
                    negative_coverage[path_id] += 1
                    has_path_cost = True
            if not has_positive_delta:
                fail(f"{location} must advance at least one path")
            if not has_player_cost and not has_path_cost:
                event_costless_choices += 1
                costless_choice_count += 1

        if event_costless_choices > MAX_COSTLESS_CHOICES_PER_EVENT:
            fail(
                f"{event_id} offers {event_costless_choices} costless choices; "
                f"at most {MAX_COSTLESS_CHOICES_PER_EVENT} may avoid an explicit trade-off"
            )

    missing_eras = SUPPORTED_ERAS - set(era_counts)
    if missing_eras:
        fail(f"catalog is missing eras: {sorted(missing_eras)}")
    undersized_eras = {
        era: era_counts[era]
        for era in sorted(SUPPORTED_ERAS)
        if era_counts[era] < MIN_EVENTS_PER_ERA
    }
    if undersized_eras:
        fail(
            f"each era needs at least {MIN_EVENTS_PER_ERA} events: "
            f"{undersized_eras}"
        )

    missing_positive_paths = PATH_DIMENSIONS - set(positive_coverage)
    if missing_positive_paths:
        fail(f"paths never advanced by any choice: {sorted(missing_positive_paths)}")
    if not negative_coverage:
        fail("catalog must contain at least one consequential path trade-off")
    weak_negative_paths = {
        path_id: negative_coverage[path_id]
        for path_id in sorted(PATH_DIMENSIONS)
        if negative_coverage[path_id] < MIN_NEGATIVE_COVERAGE_PER_PATH
    }
    if weak_negative_paths:
        fail(
            "every path needs recurring trade-offs, below minimum "
            f"{MIN_NEGATIVE_COVERAGE_PER_PATH}: {weak_negative_paths}"
        )

    coverage = ", ".join(
        f"{path_id}=+{positive_coverage[path_id]}/-{negative_coverage[path_id]}"
        for path_id in sorted(PATH_DIMENSIONS)
    )
    print(
        f"Event path validation passed: {len(events)} events, "
        f"{choice_count} choices ({costless_choice_count} costless), "
        f"six eras >= {MIN_EVENTS_PER_ERA}; {coverage}"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"Event path validation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
