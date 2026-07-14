# -*- coding: utf-8 -*-
"""Expose v0.7 narrative arc progress in background trace logs."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "wendao_enhanced.cpp"
MARKER = '<< L" | 分线 " << BuildNarrativeArcDigest()'
TRACE_PREFIX = '       << L" | 历练 " << g_player.totalEvents'


def main() -> int:
    content = SRC.read_text(encoding="utf-8")
    if "V0_7_NARRATIVE_ARCS" not in content:
        raise RuntimeError("v0.7 narrative arc patch must run first")
    if MARKER in content:
        print("v0.7 trace arc digest already present.")
        return 0

    terminated = TRACE_PREFIX + ";"
    chained = TRACE_PREFIX + "\n"
    if terminated in content:
        replacement = (
            TRACE_PREFIX + "\n"
            '       << L" | 分线 " << BuildNarrativeArcDigest();'
        )
        content = content.replace(terminated, replacement, 1)
    elif chained in content:
        replacement = (
            chained +
            '       << L" | 分线 " << BuildNarrativeArcDigest()\n'
        )
        content = content.replace(chained, replacement, 1)
    else:
        raise RuntimeError("Unable to patch trace arc digest: anchor not found")

    SRC.write_text(content, encoding="utf-8")
    print("Added narrative arc digest to trace logs.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
