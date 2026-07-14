# -*- coding: utf-8 -*-
"""Install the curated v1.2 story-art archive.

Preferred source:
``assets/story_art_b64/story_art_v12_curated.zip``

Compatibility sources:
- concatenated ``assets/story_art_b64/story_art_bundle_part_*.b64`` files;
- the older ``assets/generated_b64/art_bundle_part_00.b64`` payload.

The installer never re-encodes image data. It validates every extracted file
against the manifest before copying the library into the release directory.
"""
from __future__ import annotations

import base64
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "assets" / "story_art"
RELEASE_TARGET = ROOT / "release" / "story_art"
DIRECT_PAYLOAD = ROOT / "assets" / "story_art_b64" / "story_art_v12_curated.zip"


def payload_bytes() -> tuple[bytes, str]:
    if DIRECT_PAYLOAD.is_file():
        return DIRECT_PAYLOAD.read_bytes(), str(DIRECT_PAYLOAD.relative_to(ROOT))

    preferred = sorted((ROOT / "assets" / "story_art_b64").glob("story_art_bundle_part_*.b64"))
    if preferred:
        encoded = "".join(part.read_text(encoding="ascii").strip() for part in preferred)
        return base64.b64decode(encoded, validate=True), f"{len(preferred)} Base64 parts"

    compatibility = ROOT / "assets" / "generated_b64" / "art_bundle_part_00.b64"
    if compatibility.is_file():
        encoded = compatibility.read_text(encoding="ascii").strip()
        return base64.b64decode(encoded, validate=True), str(compatibility.relative_to(ROOT))

    raise RuntimeError("curated story-art payload was not found")


def safe_member(name: str) -> bool:
    path = PurePosixPath(name)
    return (
        not path.is_absolute()
        and ".." not in path.parts
        and bool(path.parts)
        and path.parts[0] == "story_art"
    )


def validate_manifest(root: Path) -> tuple[str, int]:
    manifest_path = root / "story_art_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    version = str(manifest.get("version", "unknown"))
    files = manifest.get("files", [])
    if not files:
        raise RuntimeError("story-art manifest contains no files")

    protagonist = manifest.get("characters", {}).get("protagonist", {})
    if protagonist.get("eyes_visible") is not False:
        raise RuntimeError("protagonist art rule violated: eyes must remain hidden")

    seen_character_ids: set[str] = set()
    for identity in manifest.get("character_identities", []):
        character_id = str(identity.get("character_id", "")).strip()
        if not character_id or character_id in seen_character_ids:
            raise RuntimeError(f"invalid or duplicate character identity: {character_id!r}")
        seen_character_ids.add(character_id)

    for entry in files:
        relative = PurePosixPath(entry["path"])
        if relative.is_absolute() or ".." in relative.parts:
            raise RuntimeError(f"unsafe manifest path: {relative}")
        path = root.joinpath(*relative.parts)
        if not path.is_file():
            raise RuntimeError(f"missing story-art asset: {relative}")
        if path.stat().st_size != int(entry["bytes"]):
            raise RuntimeError(f"size mismatch for story-art asset: {relative}")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != entry["sha256"]:
            raise RuntimeError(f"sha256 mismatch for story-art asset: {relative}")
    return version, len(files)


def main() -> int:
    payload, source_name = payload_bytes()
    archive_digest = hashlib.sha256(payload).hexdigest()

    staging = ROOT / "assets" / ".story_art_staging"
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)

    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        unsafe = [name for name in archive.namelist() if not safe_member(name)]
        if unsafe:
            raise RuntimeError(f"unsafe story-art archive member: {unsafe[0]}")
        archive.extractall(staging)

    extracted = staging / "story_art"
    version, count = validate_manifest(extracted)

    if TARGET.exists():
        shutil.rmtree(TARGET)
    shutil.move(str(extracted), str(TARGET))
    shutil.rmtree(staging, ignore_errors=True)

    if RELEASE_TARGET.exists():
        shutil.rmtree(RELEASE_TARGET)
    RELEASE_TARGET.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(TARGET, RELEASE_TARGET)

    print(
        f"Installed curated story art {version}: {count} validated assets "
        f"from {source_name} (archive sha256 {archive_digest})."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
