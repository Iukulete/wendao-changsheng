# -*- coding: utf-8 -*-
"""Install the curated story-art bundle into assets/story_art and release/story_art.

The payload is stored as one or more base64 fragments under assets/story_art_b64.
Run this script directly after cloning, or call install_story_art.bat.
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
PAYLOAD_DIR = ROOT / "assets" / "story_art_b64"
TARGET = ROOT / "assets" / "story_art"
RELEASE_TARGET = ROOT / "release" / "story_art"


def _safe_member(name: str) -> bool:
    path = PurePosixPath(name)
    return (
        not path.is_absolute()
        and ".." not in path.parts
        and bool(path.parts)
        and path.parts[0] == "story_art"
    )


def _validate_manifest(root: Path) -> int:
    manifest_path = root / "story_art_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    files = manifest.get("files", [])
    if not files:
        raise RuntimeError("story-art manifest contains no files")

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
    return len(files)


def main() -> int:
    parts = sorted(PAYLOAD_DIR.glob("story_art_bundle_part_*.b64"))
    if not parts:
        raise RuntimeError(f"story-art payload not found in {PAYLOAD_DIR}")

    encoded = "".join(part.read_text(encoding="ascii").strip() for part in parts)
    payload = base64.b64decode(encoded, validate=True)

    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        unsafe = [name for name in archive.namelist() if not _safe_member(name)]
        if unsafe:
            raise RuntimeError(f"unsafe story-art archive member: {unsafe[0]}")

        staging = ROOT / "assets" / ".story_art_staging"
        if staging.exists():
            shutil.rmtree(staging)
        staging.mkdir(parents=True)
        archive.extractall(staging)

    extracted = staging / "story_art"
    count = _validate_manifest(extracted)

    if TARGET.exists():
        shutil.rmtree(TARGET)
    shutil.move(str(extracted), str(TARGET))
    shutil.rmtree(staging, ignore_errors=True)

    if RELEASE_TARGET.exists():
        shutil.rmtree(RELEASE_TARGET)
    RELEASE_TARGET.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(TARGET, RELEASE_TARGET)

    print(f"Installed and validated {count} curated story-art assets.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
