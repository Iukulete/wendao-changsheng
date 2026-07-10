# -*- coding: utf-8 -*-
"""Compile-order repairs for v0.10 jade weapon awakening."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "wendao_enhanced.cpp"
LEGACY = ROOT / "legacy_system" / "legacy_system.h"
MARKER = "V0_10_COMPILE_REPAIR"


def main() -> int:
    source = SRC.read_text(encoding="utf-8")
    header = LEGACY.read_text(encoding="utf-8")
    if MARKER in source and MARKER in header:
        print("v0.10 compile repair already applied.")
        return 0
    if "V0_10_JADE_WEAPON_AWAKENING" not in source or "V0_10_JADE_WEAPON_AWAKENING" not in header:
        raise RuntimeError("v0.10 awakening patch must run first")

    old_tier = "notice.tier = min(ACHIEVEMENT_TIER_HEAVEN, max(weapon.tier, weapon.awakeningStage - 1));"
    new_tier = "notice.tier = min((int)ACHIEVEMENT_TIER_HEAVEN, max(weapon.tier, weapon.awakeningStage - 1)); // V0_10_COMPILE_REPAIR"
    if old_tier not in header:
        raise RuntimeError("Unable to find achievement tier cast anchor")
    header = header.replace(old_tier, new_tier, 1)

    anchor = "void ResetJadeWeaponAppliedBonuses();\nvoid SyncJadeWeaponBonuses();"
    replacement = (
        "int GetJadeWeaponBreakthroughBonus(); // V0_10_COMPILE_REPAIR\n"
        "int GetJadeWeaponAdventureSuccessBonus();\n"
        "void ResetJadeWeaponAppliedBonuses();\n"
        "void SyncJadeWeaponBonuses();"
    )
    if anchor not in source:
        raise RuntimeError("Unable to find jade weapon declaration anchor")
    source = source.replace(anchor, replacement, 1)

    LEGACY.write_text(header, encoding="utf-8")
    SRC.write_text(source, encoding="utf-8")
    print("Applied v0.10 compile repair: enum cast and modifier declarations.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
