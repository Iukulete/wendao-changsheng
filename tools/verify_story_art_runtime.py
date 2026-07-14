# -*- coding: utf-8 -*-
"""Verify that every curated v1.2 asset is wired into the native runtime.

This check runs in a disposable CI checkout. It applies the v0.12 patch twice
(to prove idempotence), verifies the installed library against the manifest,
and confirms that every manifest asset has a Windows runtime path in the
patched GDI+ source.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "wendao_enhanced.cpp"
MANIFEST = ROOT / "release" / "story_art" / "story_art_manifest.json"
APPLIER = ROOT / "tools" / "apply_v12_story_art_runtime.py"
REPAIR_STAGE = ROOT / "tools" / "repair_v11_story_load_newline.py"


def run_applier() -> None:
    subprocess.run(
        [sys.executable, "-X", "utf8", str(APPLIER)],
        cwd=ROOT,
        check=True,
    )


def main() -> int:
    run_applier()
    first = SRC.read_bytes()
    run_applier()
    second = SRC.read_bytes()
    if first != second:
        raise RuntimeError("v0.12 story-art runtime patch is not idempotent")

    source = first.decode("utf-8-sig")
    required_markers = (
        "V0_12_CURATED_STORY_ART_RUNTIME",
        "LoadCuratedStoryArtImage",
        "GetEventSceneImage",
        "activeBackground",
        "protagonist_hooded_close.jpg",
    )
    for marker in required_markers:
        if marker not in source:
            raise RuntimeError(f"missing runtime integration marker: {marker}")

    repair_text = REPAIR_STAGE.read_text(encoding="utf-8")
    if "apply_v12_story_art_runtime" not in repair_text:
        raise RuntimeError("normal build chain no longer invokes the v0.12 art stage")

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    files = manifest.get("files", [])
    if manifest.get("version") != "v1.2" or len(files) != 15:
        raise RuntimeError("unexpected curated story-art manifest")

    missing_routes: list[str] = []
    for entry in files:
        relative = str(entry["path"])
        asset = ROOT / "release" / "story_art" / Path(relative)
        if not asset.is_file():
            raise RuntimeError(f"installed runtime asset is missing: {relative}")
        if asset.stat().st_size != int(entry["bytes"]):
            raise RuntimeError(f"installed runtime asset size mismatch: {relative}")
        digest = hashlib.sha256(asset.read_bytes()).hexdigest()
        if digest != entry["sha256"]:
            raise RuntimeError(f"installed runtime asset hash mismatch: {relative}")

        runtime_path = "story_art\\\\" + relative.replace("/", "\\\\")
        if runtime_path not in source:
            missing_routes.append(relative)

    if missing_routes:
        raise RuntimeError(
            "curated assets are installed but not referenced by the runtime: "
            + ", ".join(missing_routes)
        )

    print(
        "Verified v0.12 runtime integration: 15/15 curated assets are byte-exact, "
        "routed in GDI+, and the patch is idempotent."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
