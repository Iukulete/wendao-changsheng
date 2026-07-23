#!/usr/bin/env python3
"""Verify the Godot migration surface and its executable regression coverage."""

from __future__ import annotations

import re
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot" / "project.godot"
VERIFY_SCRIPT = ROOT / "tools" / "verify_godot.ps1"
BUILD_SCRIPT = ROOT / "tools" / "build_godot.ps1"
RELEASE_VERIFY_SCRIPT = ROOT / "tools" / "verify_release_bundle.ps1"
WORKFLOW = ROOT / ".github" / "workflows" / "godot-windows.yml"

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

DEVELOPMENT_SUPPORT_FILES = (
    "docs/WINDOWS_RELEASE_README.md",
    "setup-local-ai.bat",
    "ai_engine/setup_portable_ai.ps1",
    "ai_engine/generate_event.ps1",
    "ai_engine/test_local_ai.ps1",
    "ai_engine/THIRD_PARTY_AI.md",
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

    build_text = read(BUILD_SCRIPT)
    release_verifier_text = read(RELEASE_VERIFY_SCRIPT)
    workflow_text = read(WORKFLOW)
    for relative_path in DEVELOPMENT_SUPPORT_FILES:
        read(ROOT / relative_path)
    for required_bundle_name in (
        "AGPL-3.0.txt",
        "WINDOWS_RELEASE_README.md",
        "checksums.sha256",
    ):
        if required_bundle_name not in build_text:
            raise RuntimeError(f"release build omits product support file: {required_bundle_name}")
    if "verify_release_bundle.ps1" not in build_text or "verify_release_bundle.ps1" not in workflow_text:
        raise RuntimeError("release bundle verifier is not enforced locally and in CI")
    for forbidden_suffix in ("gguf", "safetensors", "zip"):
        if forbidden_suffix not in release_verifier_text:
            raise RuntimeError(f"release verifier does not reject on-demand payloads: {forbidden_suffix}")

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
        "standalone release support, single Godot main scene, no tracked Win32/C++ source or retired CI"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"MIGRATION_SURFACE_FAILED: {error}")
        raise SystemExit(2) from error
