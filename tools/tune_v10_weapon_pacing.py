# -*- coding: utf-8 -*-
"""Tune v0.10 mastery thresholds for normal early-game pacing."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEGACY = ROOT / "legacy_system" / "legacy_system.h"
MARKER = "V0_10_WEAPON_PACING"


def main() -> int:
    text = LEGACY.read_text(encoding="utf-8")
    if MARKER in text:
        print("v0.10 weapon pacing already tuned.")
        return 0
    if "V0_10_JADE_WEAPON_AWAKENING" not in text:
        raise RuntimeError("v0.10 awakening patch must run first")

    replacements = [
        ("if (resonance >= 320) return 3;", "if (resonance >= 300) return 3; // V0_10_WEAPON_PACING"),
        ("if (resonance >= 140) return 2;", "if (resonance >= 120) return 2;"),
        ("if (resonance >= 45) return 1;", "if (resonance >= 30) return 1;"),
        ("weapon.charge = min(100, weapon.charge + max(1, amount * 2));",
         "weapon.charge = min(100, weapon.charge + max(1, amount * 4));"),
    ]
    for old, new in replacements:
        if old not in text:
            raise RuntimeError(f"Unable to tune v0.10 anchor: {old}")
        text = text.replace(old, new, 1)

    LEGACY.write_text(text, encoding="utf-8")
    print("Tuned v0.10 weapon pacing: awakenings 30/120/300 and faster technique charge.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
