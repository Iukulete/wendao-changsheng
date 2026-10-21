#!/usr/bin/env python3
"""Promote one reviewed v2 character portrait and its dialogue derivatives.

The command is intentionally transactional in spirit: it validates the
portrait report, bust report, all three PNGs, the planned registry entry, and
the queue target before copying or writing any project metadata. Ready assets
are never overwritten by this tool.
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
REGISTRY_REL = Path("godot/data/characters/character_registry_v2.json")
QUEUE_REL = Path("godot/data/characters/art_production_queue_v2.json")
IDENTITY_CARDS_REL = Path("godot/data/characters/identity_cards_v1.json")
MANIFEST_REL = Path("godot/art/art_manifest.json")
SIZES = {
    "portrait": (1024, 1536),
    "dialogue_bust": (1024, 1024),
    "avatar": (512, 512),
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def resolve_res_path(root: Path, path: object) -> Path | None:
    if not isinstance(path, str) or not path.startswith("res://"):
        return None
    return root / "godot" / path.removeprefix("res://")


def runtime_relative(path: object, folder: str) -> str:
    prefix = f"res://art/{folder}/"
    if not isinstance(path, str) or not path.startswith(prefix) or not path.endswith(".png"):
        raise RuntimeError(f"runtime asset path must be res://art/{folder}/*.png: {path!r}")
    return path.removeprefix("res://art/")


def verify_png(path: Path, kind: str) -> dict[str, object]:
    expected = SIZES[kind]
    with Image.open(path) as image:
        image.load()
        if image.format != "PNG":
            raise RuntimeError(f"{kind} must be a PNG: {path}")
        if image.size != expected:
            raise RuntimeError(
                f"{kind} must be {expected[0]}x{expected[1]}, got {image.width}x{image.height}"
            )
        rgba = image.convert("RGBA")
        if rgba.getchannel("A").getbbox() is None:
            raise RuntimeError(f"{kind} has no visible alpha pixels: {path}")
    return {
        "sha256": sha256(path),
        "width": expected[0],
        "height": expected[1],
        "bytes": path.stat().st_size,
    }


def verify_review_report(candidate: Path, report_path: Path, kind: str) -> dict[str, object]:
    report = read_json(report_path)
    if not isinstance(report, dict) or report.get("schema_version") != 1 or report.get("kind") != kind:
        raise RuntimeError(f"{kind} review report schema or kind does not match")
    if not bool(report.get("automated_pass", False)):
        failures = report.get("selection_failures", [])
        raise RuntimeError(f"{kind} review did not pass: {'; '.join(map(str, failures))}")
    if not bool(report.get("visual_review_required", False)):
        raise RuntimeError(f"{kind} review report is missing its visual-review gate")
    resolved = str(candidate.resolve())
    selected = next(
        (
            entry
            for entry in report.get("candidates", [])
            if isinstance(entry, dict) and entry.get("path") == resolved
        ),
        None,
    )
    if not isinstance(selected, dict):
        raise RuntimeError(f"candidate is absent from {kind} review report")
    if not bool(selected.get("automated_pass", False)):
        raise RuntimeError(f"selected {kind} candidate is marked automated-fail")
    if selected.get("sha256") != sha256(candidate):
        raise RuntimeError(f"selected {kind} candidate changed after review")
    return selected


def find_character(registry: dict[str, Any], character_id: str) -> dict[str, Any]:
    characters = registry.get("characters", {})
    character = characters.get(character_id) if isinstance(characters, dict) else None
    if not isinstance(character, dict):
        raise RuntimeError(f"unknown v2 character: {character_id}")
    return character


def find_queue_target(queue: dict[str, Any], character_id: str) -> dict[str, Any]:
    for target in queue.get("targets", []):
        if isinstance(target, dict) and target.get("character_id") == character_id:
            return target
    raise RuntimeError(f"character is absent from v2 art queue: {character_id}")


def find_manifest_eras(manifest: dict[str, Any], target_rel: str) -> list[str]:
    for entry in manifest.get("files", []):
        if isinstance(entry, dict) and entry.get("path") == target_rel:
            eras = entry.get("eras")
            if isinstance(eras, list) and eras:
                return [str(value) for value in eras]
    return ["全时代"]


def upsert_manifest_entry(
    manifest: dict[str, Any],
    target_rel: str,
    metadata: dict[str, object],
    purpose: str,
    eras: list[str],
    source_note: str,
) -> None:
    files = [entry for entry in manifest.get("files", []) if isinstance(entry, dict)]
    files = [entry for entry in files if entry.get("path") != target_rel]
    files.append(
        {
            "path": target_rel,
            "sha256": metadata["sha256"],
            "width": metadata["width"],
            "height": metadata["height"],
            "bytes": metadata["bytes"],
            "purpose": purpose,
            "eras": eras,
            "source_type": "generated",
            "generation_intent": {
                "concept": purpose,
                "mood": "单角色身份门通过后的低饱和叙事美术",
                "story_use": "Godot RPG 运行时角色资产",
                "source_note": source_note,
            },
        }
    )
    manifest["files"] = sorted(files, key=lambda entry: str(entry.get("path", "")))


def promote(
    root: Path,
    character_id: str,
    candidate: Path,
    portrait_report: Path,
    bust: Path,
    bust_report: Path,
    avatar: Path,
) -> None:
    registry_path = root / REGISTRY_REL
    queue_path = root / QUEUE_REL
    cards_path = root / IDENTITY_CARDS_REL
    manifest_path = root / MANIFEST_REL
    registry = read_json(registry_path)
    queue = read_json(queue_path)
    manifest = read_json(manifest_path)
    cards = read_json(cards_path) if cards_path.exists() else {}
    if not all(isinstance(value, dict) for value in (registry, queue, manifest, cards)):
        raise RuntimeError("v2 registry, queue, manifest, and cards must be JSON objects")

    character = find_character(registry, character_id)
    target = find_queue_target(queue, character_id)
    if bool(queue.get("single_character_at_a_time", False)):
        active_target_id = str(queue.get("active_target_id", ""))
        if active_target_id and active_target_id != character_id:
            raise RuntimeError(
                f"single-character queue is active on {active_target_id}; "
                f"cannot promote {character_id} yet"
            )
        if target.get("blocked_by"):
            raise RuntimeError(f"{character_id}: queue target is blocked by {target['blocked_by']}")
    assets = character.get("assets", {})
    if not isinstance(assets, dict):
        raise RuntimeError(f"{character_id}: registry assets are not an object")
    required_assets = ("portrait_master", "dialogue_bust", "avatar")
    for asset_name in required_assets:
        asset = assets.get(asset_name, {})
        status = asset.get("status") if isinstance(asset, dict) else None
        if status in {"ready", "curated"}:
            raise RuntimeError(f"{character_id}: refusing to overwrite ready {asset_name}")
        if status != "planned":
            raise RuntimeError(f"{character_id}: {asset_name} must be planned before promotion")
    if bool(queue.get("single_character_at_a_time", False)) and (
        target.get("stage") != "portrait_master" or target.get("status") != "queued"
    ):
        raise RuntimeError(f"{character_id}: promotion requires the queued portrait_master stage")

    verify_review_report(candidate, portrait_report, "portrait")
    verify_review_report(bust, bust_report, "dialogue_bust")
    master_metadata = verify_png(candidate, "portrait")
    bust_metadata = verify_png(bust, "dialogue_bust")
    avatar_metadata = verify_png(avatar, "avatar")

    target_specs = (
        ("portrait_master", "portraits", candidate, master_metadata),
        ("dialogue_bust", "dialogue", bust, bust_metadata),
        ("avatar", "dialogue", avatar, avatar_metadata),
    )
    destinations: list[tuple[str, Path, Path, dict[str, object]]] = []
    for asset_name, folder, source, metadata in target_specs:
        asset = assets[asset_name]
        runtime_path = asset.get("path")
        destination = resolve_res_path(root, runtime_path)
        if destination is None or destination.suffix.lower() != ".png":
            raise RuntimeError(f"{character_id}: invalid {asset_name} runtime path")
        if source.resolve() == destination.resolve():
            raise RuntimeError(f"{character_id}: candidate must not equal runtime destination")
        destinations.append((asset_name, destination, source, metadata))

    display_name = str(character.get("identity", {}).get("display_name", character_id))
    source_note = (
        "网页端单角色生成；本地仅做透明度、尺寸、候选报告与身份门校验，"
        "再派生对话 Bust/Avatar"
    )
    for asset_name, destination, source, _metadata in destinations:
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
        asset = assets[asset_name]
        target_rel = runtime_relative(asset.get("path"), "portraits" if asset_name == "portrait_master" else "dialogue")
        purpose = f"{display_name} {asset_name} v2 身份锚点"
        upsert_manifest_entry(
            manifest,
            target_rel,
            _metadata,
            purpose,
            find_manifest_eras(manifest, target_rel),
            source_note,
        )
        asset["status"] = "ready"

    card_set = cards.get("cards", {})
    card = card_set.get(character_id) if isinstance(card_set, dict) else None
    if isinstance(card, dict):
        card["portrait_prompt_status"] = "runtime_ready"
        card["promotion_sha256"] = master_metadata["sha256"]

    target["stage"] = "runtime_gate"
    target["status"] = "ready"
    target["source_status"] = "promoted_after_identity_and_technical_qa"
    if bool(queue.get("single_character_at_a_time", False)):
        next_target = next(
            (
                candidate_target
                for candidate_target in queue.get("targets", [])
                if isinstance(candidate_target, dict)
                and candidate_target.get("blocked_by") == character_id
                and candidate_target.get("status") == "queued"
            ),
            None,
        )
        if isinstance(next_target, dict):
            next_target["stage"] = "portrait_master"
            next_target.pop("blocked_by", None)
            queue["active_target_id"] = next_target.get("character_id", "")
        else:
            queue["active_target_id"] = ""
    write_json(registry_path, registry)
    write_json(queue_path, queue)
    if isinstance(cards, dict) and isinstance(card_set, dict):
        write_json(cards_path, cards)
    write_json(manifest_path, manifest)
    print(
        "CHARACTER_ART_V2_PROMOTION_OK:"
        f" {character_id} portrait={master_metadata['sha256']}"
        f" bust={bust_metadata['sha256']} avatar={avatar_metadata['sha256']}"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--character-id", required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--review-report", type=Path, required=True)
    parser.add_argument("--bust", type=Path, required=True)
    parser.add_argument("--bust-review-report", type=Path, required=True)
    parser.add_argument("--avatar", type=Path, required=True)
    parser.add_argument("--visual-approved", action="store_true")
    parser.add_argument("--root", type=Path, default=ROOT)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.visual_approved:
        raise RuntimeError("promotion requires --visual-approved after visual identity QA")
    paths = [args.candidate, args.review_report, args.bust, args.bust_review_report, args.avatar]
    if not all(path.is_file() for path in paths):
        raise RuntimeError("candidate, reports, bust, and avatar must all exist")
    promote(
        args.root.resolve(),
        args.character_id,
        args.candidate.resolve(),
        args.review_report.resolve(),
        args.bust.resolve(),
        args.bust_review_report.resolve(),
        args.avatar.resolve(),
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, ValueError) as error:
        print(f"CHARACTER_ART_V2_PROMOTION_FAILED: {error}")
        raise SystemExit(2) from error
