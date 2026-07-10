# -*- coding: utf-8 -*-
"""Decode the generated scene/character art stored as text-safe base64 files.

The repository connector writes text files reliably but does not upload binary
assets directly. Keeping the compressed JPEG payloads in generated_b64 allows
Windows CI and local builds to recreate the real assets before compilation.
"""

from __future__ import annotations

import base64
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = ROOT / "assets" / "generated_b64"

FILES = {
    "menu_celestial_sect.b64": "scenes/menu_celestial_sect.jpg",
    "event_spirit_test.b64": "scenes/event_spirit_test.jpg",
    "market_twilight.b64": "scenes/market_twilight.jpg",
    "event_nine_steps.b64": "scenes/event_nine_steps.jpg",
    "event_jade_reflection.b64": "scenes/event_jade_reflection.jpg",
    "lecture_hall.b64": "scenes/lecture_hall.jpg",
    "scripture_pavilion.b64": "scenes/scripture_pavilion.jpg",
    "ancestral_hall.b64": "scenes/ancestral_hall.jpg",
    "law_hall.b64": "scenes/law_hall.jpg",
    "heavenly_gate.b64": "scenes/heavenly_gate.jpg",
    "old_retainer.b64": "characters/old_retainer.jpg",
    "rival_sword_cultivator.b64": "characters/rival_sword_cultivator.jpg",
}


def main() -> int:
    missing: list[str] = []
    for bundle_name, output_name in FILES.items():
        source = BUNDLE / bundle_name
        if not source.exists():
            missing.append(bundle_name)
            continue
        payload = base64.b64decode(source.read_text(encoding="ascii"))
        output = ROOT / "assets" / output_name
        output.parent.mkdir(parents=True, exist_ok=True)
        if not output.exists() or output.read_bytes() != payload:
            output.write_bytes(payload)
        digest = hashlib.sha256(payload).hexdigest()[:12]
        print(f"installed art: {output_name} ({len(payload)} bytes, sha256 {digest})")

    if missing:
        raise RuntimeError("Missing generated art bundles: " + ", ".join(missing))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
