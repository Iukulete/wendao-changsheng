#!/usr/bin/env python3
"""Verify retired source bytes and identities without importing the retired game.

The manifest is a reviewable preservation baseline, not a license grant or a
regenerator. This command never modifies files or invokes historical tools.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path, PurePosixPath
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = "archive/source_manifest.json"
ROLES = {
    "narrative_source", "character_identity_source", "visual_reference_2d",
    "visual_staging_2d", "audio_candidate", "retired_mechanics_data",
    "provenance_and_rights", "historical_content_tool", "historical_ai_docs",
    "authored_event_examples",
}
ID_MAPS = {"characters", "groups", "named_characters", "archetypes", "aliases"}
ID_LINKS = {"entry_node", "next", "if_true", "if_false", "success", "failure", "return_routes"}
ACTIVE_FILES = {
    "LICENSE", "godot/art/fonts/font_manifest.json",
    *{f"godot/art/fonts/Noto{face}SC-{suffix}"
      for face in ("Sans", "Serif")
      for suffix in ("OFL.txt", "Variable.ttf", "Variable.ttf.import")},
}
REQUIRED_CONTENT = {
    "godot/data/characters/character_registry_v2.json",
    "godot/data/characters/character_groups_v1.json",
    "godot/data/characters/character_aliases_v1.json",
    "godot/data/dialogue/dialogue_index_v1.json",
    "godot/art/art_manifest.json", "godot/audio/audio_manifest_v2.json",
    "godot/default_bus_layout.tres",
    "ai_engine/lora/codex_gold_events.json",
    "ai_engine/lora/codex_gold_events_final.jsonl",
    "ai_engine/lora/codex_gold_events_teacher_expansion.jsonl",
    "ai_engine/THIRD_PARTY_AI.md", "ai_engine/lora/TEACHER_DATA.md",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _invalid_number(value: str) -> None:
    raise ValueError(f"non-finite JSON number: {value}")


def loads(text: str) -> Any:
    return json.loads(text, object_pairs_hook=_object, parse_constant=_invalid_number)


def read_documents(path: Path) -> list[Any]:
    text = path.read_text(encoding="utf-8-sig")
    if path.suffix == ".jsonl":
        result = [loads(line) for line in text.splitlines() if line.strip()]
        if not result:
            raise ValueError("empty JSONL document")
        return result
    return [loads(text)]


def identity_summary(documents: list[Any]) -> dict[str, Any]:
    """Fingerprint ID fields, registry-map keys and dialogue target links.

    JSON-pointer locations disambiguate repeated IDs in independent scenes.
    Byte hashes additionally protect every authored word and unselected field.
    """
    records: list[list[Any]] = []

    def walk(value: Any, pointer: str) -> None:
        if isinstance(value, dict):
            for key in sorted(value):
                child = value[key]
                child_pointer = pointer + "/" + key.replace("~", "~0").replace("/", "~1")
                if key == "id" or key.endswith(("_id", "_ids")) or key in ID_LINKS:
                    records.append([child_pointer, child])
                if key in ID_MAPS and isinstance(child, dict):
                    records.append([child_pointer + "/@keys", sorted(child)])
                    if key == "aliases":
                        records.append([child_pointer + "/@targets", child])
                walk(child, child_pointer)
        elif isinstance(value, list):
            for index, child in enumerate(value):
                walk(child, f"{pointer}/{index}")

    for index, document in enumerate(documents):
        walk(document, f"/{index}")
    encoded = json.dumps(records, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return {"documents": len(documents), "identity_records": len(records),
            "identity_sha256": hashlib.sha256(encoded).hexdigest()}


def safe_path(root: Path, relative: str) -> Path:
    if not isinstance(relative, str) or not relative or "\\" in relative:
        raise ValueError(f"invalid relative path: {relative!r}")
    path = PurePosixPath(relative)
    if path.is_absolute() or ".." in path.parts or str(path) != relative:
        raise ValueError(f"unsafe relative path: {relative!r}")
    result = root / relative
    if not result.resolve().is_relative_to(root.resolve()):
        raise ValueError(f"path escapes repository: {relative}")
    return result


def archive_path(original: str) -> str:
    return "archive/" + original if original.startswith("tools/") else "archive/source_assets/" + original


def verify_entries(root: Path, entries: list[dict[str, Any]]) -> tuple[list[str], dict[str, Any]]:
    errors: list[str] = []
    parsed: dict[str, Any] = {}
    originals: list[str] = []
    destinations: set[str] = set()
    for entry in entries:
        try:
            original = entry["original_path"]
            destination = entry["archive_path"]
            old_path, path = safe_path(root, original), safe_path(root, destination)
            if not original.startswith(("godot/", "tools/", "ai_engine/")):
                raise ValueError(f"unexpected source namespace: {original}")
            if destination != archive_path(original):
                raise ValueError(f"archive mapping mismatch: {original}")
            if destination in destinations or original in originals:
                raise ValueError(f"duplicate archive entry: {original}")
            destinations.add(destination)
            originals.append(original)
            if entry.get("role") not in ROLES:
                errors.append(f"unknown role: {original}")
            if path.suffix == ".import":
                errors.append(f"retired importer metadata must not be archived: {original}")
            if old_path.exists():
                errors.append(f"retired source still on active/old path: {original}")
            if not path.is_file() or path.is_symlink():
                errors.append(f"missing or symlinked source: {destination}")
                continue
            if path.stat().st_size != entry.get("bytes") or sha256(path) != entry.get("sha256"):
                errors.append(f"byte/hash mismatch: {destination}")
            if path.suffix in {".json", ".jsonl"}:
                documents = read_documents(path)
                if identity_summary(documents) != entry.get("json"):
                    errors.append(f"JSON identity fingerprint mismatch: {destination}")
                parsed[original] = documents[0] if path.suffix == ".json" else documents
        except (KeyError, TypeError, ValueError, OSError, UnicodeError) as error:
            errors.append(f"invalid archive entry: {error}")
    if originals != sorted(originals):
        errors.append("manifest files must be sorted by original_path")
    return errors, parsed


def node_targets(node: dict[str, Any]) -> list[str]:
    result = [node[key] for key in ("next", "if_true", "if_false", "success", "failure") if node.get(key)]
    result.extend(choice["next"] for choice in node.get("choices", []) if choice.get("next"))
    result.extend(value for value in node.get("return_routes", {}).values() if value)
    return result


def verify_content(parsed: dict[str, Any]) -> list[str]:
    """Check preserved data identities, not retired gameplay implementations."""
    errors: list[str] = []
    registry = parsed["godot/data/characters/character_registry_v2.json"]["characters"]
    groups = parsed["godot/data/characters/character_groups_v1.json"]["groups"]
    known = set(registry) | set(groups)
    for identifier in known:
        if not re.fullmatch(r"[a-z][a-z0-9]*(?:_[a-z0-9]+)*", identifier):
            errors.append(f"invalid stable character/group ID: {identifier}")
    for group_id, group in groups.items():
        if any(member not in registry for member in group["members"]):
            errors.append(f"unknown member in group: {group_id}")
    aliases = parsed["godot/data/characters/character_aliases_v1.json"]
    for target in list(aliases["aliases"].values()) + [item["character_id"] for item in aliases["scoped_aliases"]]:
        if target not in known:
            errors.append(f"alias targets unknown character/group: {target}")
    index = parsed["godot/data/dialogue/dialogue_index_v1.json"]["scenes"]
    seen: set[str] = set()
    indexed_paths: set[str] = set()
    for entry in index:
        scene_id = entry["scene_id"]
        path = entry["path"]
        if not path.startswith("res://data/dialogue/") or ".." in PurePosixPath(path).parts:
            errors.append(f"invalid original dialogue path: {path}")
            continue
        original = "godot/" + path.removeprefix("res://")
        indexed_paths.add(original)
        if scene_id in seen:
            errors.append(f"duplicate dialogue scene ID: {scene_id}")
        seen.add(scene_id)
        if original not in parsed:
            errors.append(f"missing archived dialogue: {original}")
            continue
        scene = parsed[original]
        if scene["scene_id"] != scene_id:
            errors.append(f"dialogue scene ID mismatch: {original}")
        nodes = scene["nodes"]
        ids = [node["id"] for node in nodes]
        if len(ids) != len(set(ids)) or any(not isinstance(value, str) or not value for value in ids):
            errors.append(f"duplicate/empty dialogue node ID: {scene_id}")
        by_id = {node["id"]: node for node in nodes}
        if scene["entry_node"] not in by_id:
            errors.append(f"missing dialogue entry node: {scene_id}")
        for participant in scene.get("participants", []):
            if participant not in known | {"narrator", "player"}:
                errors.append(f"unknown dialogue participant: {scene_id}/{participant}")
        for node in nodes:
            if "speaker_id" in node and node["speaker_id"] not in known | {"narrator", "player"}:
                errors.append(f"unknown dialogue speaker: {scene_id}/{node['id']}")
            choice_ids = [choice["id"] for choice in node.get("choices", [])]
            if len(choice_ids) != len(set(choice_ids)):
                errors.append(f"duplicate dialogue choice ID: {scene_id}/{node['id']}")
            for target in node_targets(node):
                if target not in by_id:
                    errors.append(f"broken dialogue target: {scene_id}/{target}")
        reachable: set[str] = set()
        pending = [scene["entry_node"]]
        while pending:
            current = pending.pop()
            if current in reachable or current not in by_id:
                continue
            reachable.add(current)
            pending.extend(node_targets(by_id[current]))
        if reachable != set(ids):
            errors.append(f"unreachable dialogue nodes: {scene_id}")
    all_dialogues = {path for path in parsed if path.startswith("godot/data/dialogue/") and not path.endswith("/dialogue_index_v1.json")}
    if indexed_paths != all_dialogues:
        errors.append("dialogue index does not cover all archived scene files")
    for path, document in parsed.items():
        if path.startswith("godot/data/chronicles/"):
            chapters = [chapter["id"] for chapter in document["chapters"]]
            if len(chapters) != len(set(chapters)) or document["entry_chapter_id"] not in chapters:
                errors.append(f"invalid chronicle chapter IDs: {path}")
    return errors



def verify_extractions(root: Path, manifest: dict[str, Any]) -> list[str]:
    """Check explicitly derived prose separately from byte-identical originals."""
    errors: list[str] = []
    entries = manifest["extracted_documents"]
    indexed = {entry["path"] for entry in entries}
    expected = {"archive/extracted_narrative/ai_embedded_authored_text.json"}
    actual = {path.relative_to(root).as_posix()
              for path in (root / "archive/extracted_narrative").rglob("*") if path.is_file()}
    if indexed != expected or actual != indexed:
        errors.append("extracted narrative inventory mismatch")
    retired = {entry["original_path"]: entry["sha256"] for entry in manifest["retired_ai_runtime_files"]}
    for entry in entries:
        path = safe_path(root, entry["path"])
        if entry["path"] not in expected or not path.is_file() or path.is_symlink():
            errors.append(f"invalid extracted narrative path: {entry['path']}")
            continue
        if path.stat().st_size != entry["bytes"] or sha256(path) != entry["sha256"]:
            errors.append(f"extracted narrative byte/hash mismatch: {entry['path']}")
        documents = read_documents(path)
        if identity_summary(documents) != entry["json"]:
            errors.append(f"extracted narrative identity mismatch: {entry['path']}")
        sources = documents[0]["sources"]
        if [source["original_path"] for source in sources] != entry["source_paths"]:
            errors.append("extracted narrative source inventory mismatch")
        for source in sources:
            original = source["original_path"]
            if source["source_sha256"] != retired.get(original) or source["source_revision"] != manifest["source_revision"]:
                errors.append(f"extracted narrative provenance mismatch: {original}")
            for literal in source["chinese_string_literals"]:
                if not isinstance(literal["text"], str) or not literal["source_excerpt"] or literal["start_line"] > literal["end_line"]:
                    errors.append(f"invalid preserved literal: {original}")
            if "gold_samples" in source:
                kinds = [sample["kind"] for sample in source["gold_samples"]]
                if not kinds or len(kinds) != len(set(kinds)):
                    errors.append(f"duplicate/empty extracted sample ID: {original}")
    return errors


def verify(root: Path = ROOT) -> list[str]:
    manifest = read_documents(root / MANIFEST)[0]
    errors: list[str] = []
    if manifest.get("schema_version") != 1:
        errors.append("unsupported source manifest schema")
    entries = manifest["files"]
    entry_errors, parsed = verify_entries(root, entries)
    errors.extend(entry_errors)
    errors.extend(verify_extractions(root, manifest))
    by_original = {entry["original_path"]: entry for entry in entries}
    missing = REQUIRED_CONTENT - set(by_original)
    if missing:
        errors.append(f"missing required source entries: {sorted(missing)}")
    indexed = {entry["archive_path"] for entry in entries}
    actual = {path.relative_to(root).as_posix()
              for directory in (root / "archive/source_assets", root / "archive/tools")
              for path in directory.rglob("*") if path.is_file() and "__pycache__" not in path.parts}
    if actual != indexed:
        errors.append(f"archive file inventory mismatch; unlisted={sorted(actual-indexed)}, missing={sorted(indexed-actual)}")
    active = manifest["active_preserved"]
    if {entry["path"] for entry in active} != ACTIVE_FILES:
        errors.append("active font/license preservation inventory mismatch")
    for entry in active:
        path = safe_path(root, entry["path"])
        if not path.is_file() or path.is_symlink() or path.stat().st_size != entry["bytes"] or sha256(path) != entry["sha256"]:
            errors.append(f"active font/license changed: {entry['path']}")
    for entry in manifest["retired_generated_imports"] + manifest["retired_ai_runtime_files"]:
        if safe_path(root, entry["original_path"]).exists():
            errors.append(f"retired file still present: {entry['original_path']}")
    if not errors:
        try:
            errors.extend(verify_content(parsed))
            art = parsed["godot/art/art_manifest.json"]
            for item in art["files"]:
                original = "godot/art/" + item["path"]
                if original not in by_original or by_original[original]["sha256"].lower() != item["sha256"].lower():
                    errors.append(f"original art provenance hash mismatch: {original}")
            audio = parsed["godot/audio/audio_manifest_v2.json"]
            audio_ids = [item["id"] for item in audio["assets"]]
            if len(audio_ids) != len(set(audio_ids)):
                errors.append("duplicate audio asset ID")
            for item in audio["assets"]:
                original = "godot/audio/" + item["file"]
                license_path = "godot/" + item["license_file"].removeprefix("res://")
                if original not in by_original or by_original[original]["sha256"].lower() != item["sha256"].lower():
                    errors.append(f"original audio provenance hash mismatch: {original}")
                if not item.get("license_spdx") or not item.get("attribution_text") or license_path not in by_original:
                    errors.append(f"missing preserved audio rights record: {item['id']}")
        except (KeyError, TypeError, ValueError) as error:
            errors.append(f"invalid preserved content structure: {error}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT, help="repository root (default: script's parent repository)")
    args = parser.parse_args()
    try:
        errors = verify(args.root.resolve())
    except (KeyError, TypeError, ValueError, OSError, UnicodeError) as error:
        errors = [f"cannot verify source archive: {error}"]
    for error in errors:
        print(f"ERROR {error}")
    print("SOURCE ARCHIVE", "FAIL" if errors else "PASS")
    if not errors:
        print("SOURCE_ARCHIVE_OK: preserved bytes, JSON identities, rights records and dialogue graphs")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
