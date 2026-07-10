# -*- coding: utf-8 -*-
"""Expose v0.7 narrative arc progress in background trace logs."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "wendao_enhanced.cpp"
MARKER = '<< L" | 分线 " << BuildNarrativeArcDigest();'


def main() -> int:
    content = SRC.read_text(encoding="utf-8")
    if "V0_7_NARRATIVE_ARCS" not in content:
        raise RuntimeError("v0.7 narrative arc patch must run first")
    if MARKER in content:
        print("v0.7 trace arc digest already present.")
        return 0

    old = '       << L" | 历练 " << g_player.totalEvents;'
    new = (
        '       << L" | 历练 " << g_player.totalEvents\n'
        '       << L" | 分线 " << BuildNarrativeArcDigest();'
    )
    if old not in content:
        raise RuntimeError("Unable to patch trace arc digest: anchor not found")
    SRC.write_text(content.replace(old, new, 1), encoding="utf-8")
    print("Added narrative arc digest to trace logs.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
