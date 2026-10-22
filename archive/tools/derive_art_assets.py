#!/usr/bin/env python3
"""Reproduce approved deterministic crops derived from existing project art."""

from __future__ import annotations

import hashlib
from pathlib import Path
import shutil

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
RECIPES = {
    "imperial_sky_inspector_legacy_alias": {
        "source": ROOT / "godot" / "art" / "portraits" / "imperial_sky_inspector_v2.png",
        "output": ROOT / "godot" / "art" / "portraits" / "imperial_sky_inspector.png",
        "expected_source_size": (1024, 1536),
        "output_size": (1024, 1536),
        "copy_exact": True,
    },
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    for recipe_id, recipe in RECIPES.items():
        source_path = recipe["source"]
        output_path = recipe["output"]
        with Image.open(source_path) as source:
            source.load()
            if source.size != recipe["expected_source_size"]:
                raise RuntimeError(
                    f"{recipe_id}: source size changed from {recipe['expected_source_size']} "
                    f"to {source.size}"
                )
            output_path.parent.mkdir(parents=True, exist_ok=True)
            if recipe.get("copy_exact", False):
                shutil.copyfile(source_path, output_path)
            else:
                derived = source.convert("RGB").crop(recipe["crop"])
                derived = derived.resize(recipe["output_size"], Image.Resampling.LANCZOS)
                derived.save(output_path, format="PNG", optimize=True, compress_level=9)
        print(
            f"DERIVED_ART_OK: {recipe_id} {recipe['output_size'][0]}x{recipe['output_size'][1]} "
            f"bytes={output_path.stat().st_size} sha256={sha256(output_path)}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
