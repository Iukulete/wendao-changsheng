# -*- coding: utf-8 -*-
"""Validate the self-contained art inventory for the Godot main edition."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path, PurePosixPath
import struct


ROOT = Path(__file__).resolve().parents[1]
ART_ROOT = ROOT / "godot" / "art"
MANIFEST = ART_ROOT / "art_manifest.json"
IMAGE_SUFFIXES = {
    ".bmp",
    ".gif",
    ".jpeg",
    ".jpg",
    ".png",
    ".svg",
    ".webp",
}
SUPPORTED_SOURCE_TYPES = {"generated", "curated"}
INTENT_ASSETS = {
    "scenes/lantern_river_spirit_bazaar.png",
    "scenes/void_threshold_temple.png",
}
JPEG_SOF_MARKERS = {
    0xC0,
    0xC1,
    0xC2,
    0xC3,
    0xC5,
    0xC6,
    0xC7,
    0xC9,
    0xCA,
    0xCB,
    0xCD,
    0xCE,
    0xCF,
}


def png_dimensions(payload: bytes) -> tuple[int, int]:
    if payload[:8] != b"\x89PNG\r\n\x1a\n" or payload[12:16] != b"IHDR":
        raise RuntimeError("invalid PNG header")
    return struct.unpack(">II", payload[16:24])


def jpeg_dimensions(payload: bytes) -> tuple[int, int]:
    if payload[:2] != b"\xff\xd8":
        raise RuntimeError("invalid JPEG header")

    offset = 2
    while offset < len(payload):
        if payload[offset] != 0xFF:
            raise RuntimeError("invalid JPEG marker stream")
        while offset < len(payload) and payload[offset] == 0xFF:
            offset += 1
        if offset >= len(payload):
            break

        marker = payload[offset]
        offset += 1
        if marker in {0x01, 0xD8, 0xD9} or 0xD0 <= marker <= 0xD7:
            continue
        if offset + 2 > len(payload):
            break

        segment_length = struct.unpack(">H", payload[offset : offset + 2])[0]
        if segment_length < 2 or offset + segment_length > len(payload):
            raise RuntimeError("invalid JPEG segment length")
        if marker in JPEG_SOF_MARKERS:
            if segment_length < 7:
                raise RuntimeError("invalid JPEG frame header")
            height, width = struct.unpack(">HH", payload[offset + 3 : offset + 7])
            return width, height
        if marker == 0xDA:
            break
        offset += segment_length

    raise RuntimeError("JPEG dimensions were not found")


def image_dimensions(payload: bytes, suffix: str) -> tuple[int, int]:
    if suffix == ".png":
        return png_dimensions(payload)
    if suffix in {".jpg", ".jpeg"}:
        return jpeg_dimensions(payload)
    raise RuntimeError(f"dimension reader does not support {suffix}")


def nonempty_text(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def main() -> int:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if manifest.get("manifest_version") != 1:
        raise RuntimeError("unexpected Godot art manifest version")
    if manifest.get("runtime_root") != "res://art":
        raise RuntimeError("Godot art runtime root must be res://art")
    if not nonempty_text(manifest.get("rights_notice")):
        raise RuntimeError("rights notice must not be empty")

    files = manifest.get("files")
    if not isinstance(files, list) or not files:
        raise RuntimeError("Godot art manifest contains no files")

    entries: dict[str, dict[str, object]] = {}
    casefold_paths: set[str] = set()
    for entry in files:
        if not isinstance(entry, dict) or not nonempty_text(entry.get("path")):
            raise RuntimeError("every manifest entry needs a path")
        path_text = str(entry["path"])
        relative = PurePosixPath(path_text)
        if (
            relative.is_absolute()
            or ".." in relative.parts
            or "\\" in path_text
            or str(relative) != path_text
        ):
            raise RuntimeError(f"unsafe or non-canonical art path: {path_text}")
        if path_text in entries or path_text.casefold() in casefold_paths:
            raise RuntimeError(f"duplicate art path: {path_text}")
        entries[path_text] = entry
        casefold_paths.add(path_text.casefold())

    registered_paths = set(entries)
    if list(entries) != sorted(entries):
        raise RuntimeError("manifest files must remain sorted by path")

    actual_paths = {
        path.relative_to(ART_ROOT).as_posix()
        for path in ART_ROOT.rglob("*")
        if path.is_file() and path.suffix.lower() in IMAGE_SUFFIXES
    }
    missing = sorted(registered_paths - actual_paths)
    unregistered = sorted(actual_paths - registered_paths)
    if missing:
        raise RuntimeError("missing registered Godot art: " + ", ".join(missing))
    if unregistered:
        raise RuntimeError("unregistered Godot art: " + ", ".join(unregistered))

    source_counts = {source_type: 0 for source_type in SUPPORTED_SOURCE_TYPES}
    for path_text, entry in entries.items():
        source_type = entry.get("source_type")
        if source_type not in SUPPORTED_SOURCE_TYPES:
            raise RuntimeError(f"invalid source_type for {path_text}: {source_type!r}")
        source_counts[str(source_type)] += 1

        eras = entry.get("eras")
        if (
            not isinstance(eras, list)
            or not eras
            or not all(nonempty_text(era) for era in eras)
        ):
            raise RuntimeError(f"eras must be a non-empty text list: {path_text}")
        if not nonempty_text(entry.get("purpose")):
            raise RuntimeError(f"purpose must not be empty: {path_text}")

        path = ART_ROOT.joinpath(*PurePosixPath(path_text).parts)
        payload = path.read_bytes()
        if len(payload) != int(entry.get("bytes", -1)):
            raise RuntimeError(f"byte-size mismatch: {path_text}")
        digest = hashlib.sha256(payload).hexdigest()
        if digest != entry.get("sha256"):
            raise RuntimeError(f"SHA-256 mismatch: {path_text}")
        dimensions = image_dimensions(payload, path.suffix.lower())
        expected_dimensions = (int(entry.get("width", -1)), int(entry.get("height", -1)))
        if dimensions != expected_dimensions:
            raise RuntimeError(
                f"dimension mismatch: {path_text} (actual {dimensions}, expected {expected_dimensions})"
            )

    for path_text in INTENT_ASSETS:
        entry = entries.get(path_text, {})
        intent = entry.get("generation_intent")
        if entry.get("source_type") != "generated":
            raise RuntimeError(f"new render asset must remain generated: {path_text}")
        if not isinstance(intent, dict) or not all(
            nonempty_text(intent.get(field)) for field in ("concept", "mood", "story_use")
        ):
            raise RuntimeError(f"generation intent is incomplete: {path_text}")

    print(
        "Godot art verified: "
        f"{len(entries)} registered images, {source_counts['generated']} generated, "
        f"{source_counts['curated']} curated, no missing or unregistered images."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
