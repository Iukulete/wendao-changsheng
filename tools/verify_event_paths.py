#!/usr/bin/env python3
"""Validate that every authored event choice drives the six-path system."""

from __future__ import annotations

from collections import Counter
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
EVENTS_PATH = ROOT / "godot" / "data" / "events_v014.json"
PATH_DIMENSIONS = {
    "compassion",
    "ambition",
    "defiance",
    "insight",
    "creation",
    "bonds",
}
MIN_DELTA = -4
MAX_DELTA = 4


def fail(message: str) -> None:
    raise ValueError(message)


def main() -> int:
    events = json.loads(EVENTS_PATH.read_text(encoding="utf-8"))
    if not isinstance(events, list) or not events:
        fail("event catalog must be a non-empty JSON array")

    event_ids: set[str] = set()
    positive_coverage: Counter[str] = Counter()
    negative_coverage: Counter[str] = Counter()
    choice_count = 0

    for event_index, event in enumerate(events):
        if not isinstance(event, dict):
            fail(f"event[{event_index}] must be an object")
        event_id = event.get("id")
        if not isinstance(event_id, str) or not event_id:
            fail(f"event[{event_index}] has no stable id")
        if event_id in event_ids:
            fail(f"duplicate event id: {event_id}")
        event_ids.add(event_id)

        choices = event.get("choices")
        if not isinstance(choices, list) or not choices:
            fail(f"{event_id}: choices must be a non-empty array")

        for choice_index, choice in enumerate(choices):
            choice_count += 1
            location = f"{event_id}.choices[{choice_index}]"
            if not isinstance(choice, dict):
                fail(f"{location} must be an object")
            path_deltas = choice.get("path_deltas")
            if not isinstance(path_deltas, dict) or not path_deltas:
                fail(f"{location} must define non-empty path_deltas")

            unknown_paths = set(path_deltas) - PATH_DIMENSIONS
            if unknown_paths:
                fail(f"{location} contains unknown paths: {sorted(unknown_paths)}")

            has_positive_delta = False
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
            if not has_positive_delta:
                fail(f"{location} must advance at least one path")

    missing_positive_paths = PATH_DIMENSIONS - set(positive_coverage)
    if missing_positive_paths:
        fail(f"paths never advanced by any choice: {sorted(missing_positive_paths)}")
    if not negative_coverage:
        fail("catalog must contain at least one consequential path trade-off")

    coverage = ", ".join(
        f"{path_id}=+{positive_coverage[path_id]}/-{negative_coverage[path_id]}"
        for path_id in sorted(PATH_DIMENSIONS)
    )
    print(
        f"Event path validation passed: {len(events)} events, "
        f"{choice_count} choices; {coverage}"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"Event path validation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
