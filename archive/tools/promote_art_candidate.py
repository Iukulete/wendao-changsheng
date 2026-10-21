#!/usr/bin/env python3
"""Promote a reviewed product-art candidate into the Godot runtime inventory.

The command deliberately requires both a passing candidate-review report and an
explicit visual approval flag. It then updates the image, identity/storyboard
catalog, active story/event bindings, and the integrity manifest together.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
from typing import Any

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SPECS = {
    "portrait": (1024, 1536),
    "storyboard": (1536, 1024),
}
MANIFEST_REL = Path("godot/art/art_manifest.json")
CHARACTER_REL = Path("godot/data/character_art_v1.json")
EVENTS_REL = Path("godot/data/events_v014.json")
STORY_REL = Path("godot/data/story_arcs_v1.json")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value: Any) -> None:
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def runtime_relative(runtime_path: str, expected_folder: str) -> str:
    prefix = f"res://art/{expected_folder}/"
    if not runtime_path.startswith(prefix) or not runtime_path.endswith(".png"):
        raise RuntimeError(f"invalid product-art target: {runtime_path}")
    return runtime_path.removeprefix("res://art/")


def verify_review_report(candidate: Path, report_path: Path, kind: str) -> dict[str, Any]:
    report = read_json(report_path)
    if not isinstance(report, dict) or report.get("schema_version") != 1 or report.get("kind") != kind:
        raise RuntimeError("review report schema or kind does not match this promotion")
    if not bool(report.get("automated_pass", False)):
        failures = report.get("selection_failures", [])
        raise RuntimeError("candidate review did not pass: " + "; ".join(map(str, failures)))
    if not bool(report.get("visual_review_required", False)):
        raise RuntimeError("review report is missing the visual-review gate")
    resolved_candidate = str(candidate.resolve())
    candidate_report = next(
        (
            entry
            for entry in report.get("candidates", [])
            if isinstance(entry, dict) and entry.get("path") == resolved_candidate
        ),
        None,
    )
    if not isinstance(candidate_report, dict):
        raise RuntimeError("candidate is not present in the supplied review report")
    if not bool(candidate_report.get("automated_pass", False)):
        raise RuntimeError("selected candidate is marked as automated-fail")
    if candidate_report.get("sha256") != sha256(candidate):
        raise RuntimeError("candidate changed after its review report was generated")
    return candidate_report


def image_metadata(candidate: Path, kind: str) -> tuple[int, int, int, str]:
    expected_size = SPECS[kind]
    with Image.open(candidate) as image:
        image.load()
        if image.format != "PNG":
            raise RuntimeError("product-art promotion requires a PNG candidate")
        if image.size != expected_size:
            raise RuntimeError(
                f"candidate must be exactly {expected_size[0]}x{expected_size[1]}, "
                f"got {image.size[0]}x{image.size[1]}"
            )
    return expected_size[0], expected_size[1], candidate.stat().st_size, sha256(candidate)


def find_character(catalog: dict[str, Any], identity: str) -> dict[str, Any]:
    for value in catalog.get("characters", []):
        if isinstance(value, dict) and value.get("id") == identity:
            return value
    raise RuntimeError(f"unknown character identity: {identity}")


def find_storyboard(catalog: dict[str, Any], storyboard_id: str) -> dict[str, Any]:
    for value in catalog.get("storyboards", []):
        if isinstance(value, dict) and value.get("id") == storyboard_id:
            return value
    raise RuntimeError(f"unknown storyboard: {storyboard_id}")


def manifest_eras(manifest: dict[str, Any], previous_runtime_path: str) -> list[str]:
    for value in manifest.get("files", []):
        if isinstance(value, dict) and value.get("path") == previous_runtime_path:
            eras = value.get("eras")
            if isinstance(eras, list) and eras:
                return [str(era) for era in eras]
    return ["全时代"]


def upsert_manifest_entry(
    manifest: dict[str, Any],
    target_rel: str,
    candidate: Path,
    kind: str,
    purpose: str,
    eras: list[str],
    width: int,
    height: int,
    bytes_count: int,
    digest: str,
) -> None:
    files = [value for value in manifest.get("files", []) if isinstance(value, dict)]
    files = [value for value in files if value.get("path") != target_rel]
    folder = "portraits" if kind == "portrait" else "scenes"
    entry: dict[str, Any] = {
        "path": target_rel,
        "sha256": digest,
        "width": width,
        "height": height,
        "bytes": bytes_count,
        "purpose": purpose,
        "eras": eras,
        "source_type": "generated",
        "generation_intent": {
            "concept": purpose,
            "mood": "经过候选筛选的产品级叙事美术",
            "story_use": f"Godot {folder} 运行时资产",
        },
    }
    files.append(entry)
    manifest["files"] = sorted(files, key=lambda value: str(value.get("path", "")))


def replace_bindings(value: Any, identity: str, target_runtime_path: str) -> None:
    if isinstance(value, list):
        for child in value:
            replace_bindings(child, identity, target_runtime_path)
        return
    if not isinstance(value, dict):
        return
    if value.get("character_id") == identity and value.get("portrait_mode", "focus") != "scene_only":
        value["portrait"] = target_runtime_path
    for child in value.values():
        replace_bindings(child, identity, target_runtime_path)


def update_storyboard_binding(story: dict[str, Any], storyboard: dict[str, Any], target: str) -> None:
    binding = storyboard.get("story_binding")
    if not isinstance(binding, dict):
        raise RuntimeError("storyboard has no story_binding metadata")
    arc_id = str(binding.get("arc_id", ""))
    phase = str(binding.get("phase", ""))
    stage = int(binding.get("stage", -1))
    for arc in story.get("arcs", []):
        if not isinstance(arc, dict) or arc.get("id") != arc_id:
            continue
        nodes = arc.get(phase)
        if not isinstance(nodes, list) or stage < 0 or stage >= len(nodes):
            raise RuntimeError(f"storyboard binding points outside {arc_id}.{phase}")
        node = nodes[stage]
        if not isinstance(node, dict):
            raise RuntimeError("storyboard binding points to an invalid story node")
        art = node.setdefault("art", {})
        if not isinstance(art, dict):
            raise RuntimeError("story node art override is not an object")
        art["scene"] = target
        art["portrait_mode"] = "scene_only"
        art["portrait"] = ""
        return
    raise RuntimeError(f"storyboard binding arc does not exist: {arc_id}.{phase}[{stage}]")


def promote_character(root: Path, identity: str, candidate: Path, report: Path) -> str:
    manifest_path = root / MANIFEST_REL
    catalog_path = root / CHARACTER_REL
    events_path = root / EVENTS_REL
    story_path = root / STORY_REL
    manifest = read_json(manifest_path)
    catalog = read_json(catalog_path)
    if not isinstance(manifest, dict) or not isinstance(catalog, dict):
        raise RuntimeError("art manifest and character catalog must be JSON objects")
    character = find_character(catalog, identity)
    target_runtime = str(character.get("replacement_target", ""))
    target_rel = runtime_relative(target_runtime, "portraits")
    previous_runtime = str(character.get("current_portrait", ""))
    eras = manifest_eras(manifest, previous_runtime.removeprefix("res://art/"))
    width, height, bytes_count, digest = image_metadata(candidate, "portrait")
    target_path = root / "godot" / "art" / Path(*target_rel.split("/"))
    target_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(candidate, target_path)
    upsert_manifest_entry(
        manifest,
        target_rel,
        candidate,
        "portrait",
        f"{character.get('display_name', identity)}产品级身份锚点立绘",
        eras,
        width,
        height,
        bytes_count,
        digest,
    )
    character["current_portrait"] = target_runtime
    character["release_status"] = "approved"
    events = read_json(events_path)
    story = read_json(story_path)
    if not isinstance(story, dict):
        raise RuntimeError("story catalog must be a JSON object")
    replace_bindings(events, identity, target_runtime)
    replace_bindings(story, identity, target_runtime)
    write_json(manifest_path, manifest)
    write_json(catalog_path, catalog)
    write_json(events_path, events)
    write_json(story_path, story)
    return target_runtime


def promote_storyboard(root: Path, storyboard_id: str, candidate: Path, report: Path) -> str:
    manifest_path = root / MANIFEST_REL
    catalog_path = root / CHARACTER_REL
    story_path = root / STORY_REL
    manifest = read_json(manifest_path)
    catalog = read_json(catalog_path)
    if not isinstance(manifest, dict) or not isinstance(catalog, dict):
        raise RuntimeError("art manifest and character catalog must be JSON objects")
    storyboard = find_storyboard(catalog, storyboard_id)
    target_runtime = str(storyboard.get("target", ""))
    target_rel = runtime_relative(target_runtime, "scenes")
    width, height, bytes_count, digest = image_metadata(candidate, "storyboard")
    target_path = root / "godot" / "art" / Path(*target_rel.split("/"))
    target_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(candidate, target_path)
    upsert_manifest_entry(
        manifest,
        target_rel,
        candidate,
        "storyboard",
        f"{storyboard.get('display_name', storyboard_id)}产品级关键剧情分镜",
        ["古典修仙纪"],
        width,
        height,
        bytes_count,
        digest,
    )
    storyboard["status"] = "approved"
    story = read_json(story_path)
    if not isinstance(story, dict):
        raise RuntimeError("story catalog must be a JSON object")
    update_storyboard_binding(story, storyboard, target_runtime)
    write_json(manifest_path, manifest)
    write_json(catalog_path, catalog)
    write_json(story_path, story)
    return target_runtime


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--identity", help="character identity id from character_art_v1.json")
    group.add_argument("--storyboard", help="storyboard id from character_art_v1.json")
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--review-report", type=Path, required=True)
    parser.add_argument("--visual-approved", action="store_true")
    parser.add_argument("--root", type=Path, default=ROOT)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.visual_approved:
        raise RuntimeError("promotion requires --visual-approved after visual screening")
    root = args.root.resolve()
    candidate = args.candidate.resolve()
    report = args.review_report.resolve()
    kind = "portrait" if args.identity else "storyboard"
    if not candidate.is_file() or not report.is_file():
        raise RuntimeError("candidate and review report must both exist")
    verify_review_report(candidate, report, kind)
    target = (
        promote_character(root, str(args.identity), candidate, report)
        if args.identity
        else promote_storyboard(root, str(args.storyboard), candidate, report)
    )
    print(f"ART_PROMOTION_OK: {kind} {target}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, RuntimeError) as error:
        print(f"ART_PROMOTION_FAILED: {error}")
        raise SystemExit(2) from error
