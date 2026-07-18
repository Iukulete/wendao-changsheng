#!/usr/bin/env python3
"""Verify the Godot migration surface and its executable regression coverage."""

from __future__ import annotations

import re
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot" / "project.godot"
VERIFY_SCRIPT = ROOT / "tools" / "verify_godot.ps1"

RUNTIME_DOMAINS = {
    "game_state": "GameStateSchema",
    "save_service": "SaveService",
    "legacy_save_importer": "LegacySaveImporter",
    "cultivation_system": "CultivationSystem",
    "reincarnation_system": "ReincarnationSystem",
    "world_simulation": "WorldSimulation",
    "event_catalog": "EventCatalog",
    "story_system": "StorySystem",
    "item_system": "ItemSystem",
    "combat_system": "CombatSystem",
    "achievement_system": "AchievementSystem",
    "dungeon_system": "DungeonSystem",
    "local_ai_bridge": "LocalAIBridge",
}

REGRESSION_SCRIPTS = (
    "typography_system_test.gd",
    "audio_system_test.gd",
    "character_art_catalog_test.gd",
    "game_state_test.gd",
    "world_simulation_test.gd",
    "story_system_test.gd",
    "achievement_system_test.gd",
    "dungeon_system_test.gd",
    "event_catalog_test.gd",
    "local_ai_bridge_test.gd",
    "item_system_test.gd",
    "combat_system_test.gd",
    "save_service_test.gd",
    "legacy_save_importer_test.gd",
    "main_save_integration_test.gd",
    "ten_life_long_run_test.gd",
)


def read(path: Path) -> str:
    if not path.is_file():
        raise RuntimeError(f"missing migration surface file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def tracked_files() -> list[str]:
    result = subprocess.run(
        ["git", "ls-files"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return [line for line in result.stdout.splitlines() if line]


def verify() -> None:
    project_text = read(PROJECT)
    if not re.search(r'(?m)^run/main_scene="res://scenes/main\.tscn"$', project_text):
        raise RuntimeError("Godot project does not point at the single main scene")

    for stem, class_name in RUNTIME_DOMAINS.items():
        script = ROOT / "godot" / "scripts" / f"{stem}.gd"
        script_text = read(script)
        if not re.search(rf"(?m)^class_name\s+{re.escape(class_name)}\s*$", script_text):
            raise RuntimeError(f"{script.relative_to(ROOT)} has no {class_name} class_name")

    verifier_text = read(VERIFY_SCRIPT)
    for test_name in REGRESSION_SCRIPTS:
        test_path = ROOT / "godot" / "tests" / test_name
        read(test_path)
        if test_name not in verifier_text:
            raise RuntimeError(f"{test_name} is not executed by verify_godot.ps1")

    legacy_patterns = (
        re.compile(r"(?i)(^|/)(CMakeLists\.txt|Makefile|.*\.(c|cc|cpp|cxx|h|hh|hpp|hxx|rc))$"),
        re.compile(r"(?i)^\.github/workflows/(story-art-validation|windows-build(-v06)?)\.yml$"),
    )
    legacy_files = [
        path for path in tracked_files() if any(pattern.search(path) for pattern in legacy_patterns)
    ]
    if legacy_files:
        raise RuntimeError("legacy Win32/C++ files remain tracked: " + ", ".join(legacy_files))


def main() -> int:
    verify()
    print(
        "MIGRATION_SURFACE_OK: "
        f"{len(RUNTIME_DOMAINS)} runtime domains, {len(REGRESSION_SCRIPTS)} regression entrypoints, "
        "single Godot main scene, no tracked Win32/C++ source or retired CI"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"MIGRATION_SURFACE_FAILED: {error}")
        raise SystemExit(2) from error
