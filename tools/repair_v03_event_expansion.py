# -*- coding: utf-8 -*-
"""Move v0.3 injected events inside AddOpeningLocalEvents().

The first v0.3 patch appended the new AddEvent calls after the closing brace of
AddOpeningLocalEvents(), which makes C++ parse them as invalid member
declarations. This repair script is intentionally small and idempotent: it
removes the v0.3 block wherever it is and reinserts it just before the closing
brace followed by the v0.2 end marker.
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "wendao_enhanced.cpp"
BEGIN = "        // V0_3_EVENT_EXPANSION_BEGIN"
END = "        // V0_3_EVENT_EXPANSION_END"
TAIL = "    }\n    // V0_2_OPENING_EVENTS_END"


def main() -> int:
    if not SRC.exists():
        raise FileNotFoundError(f"Source file not found: {SRC}")

    content = SRC.read_text(encoding="utf-8")
    start = content.find(BEGIN)
    if start < 0:
        print("No v0.3 event expansion block found; nothing to repair.")
        return 0

    end = content.find(END, start)
    if end < 0:
        raise RuntimeError("v0.3 block begin marker found but end marker is missing.")
    end += len(END)

    # Include the trailing newline after the end marker when present.
    if end < len(content) and content[end:end + 2] == "\r\n":
        end += 2
    elif end < len(content) and content[end] == "\n":
        end += 1

    block = content[start:end].strip("\r\n")
    without = content[:start] + content[end:]

    # Clean up extra blank lines left by the removal.
    while "\n\n\n    // V0_2_OPENING_EVENTS_END" in without:
        without = without.replace("\n\n\n    // V0_2_OPENING_EVENTS_END", "\n\n    // V0_2_OPENING_EVENTS_END")

    if TAIL not in without:
        raise RuntimeError("Unable to find AddOpeningLocalEvents closing brace before v0.2 end marker.")

    repaired = without.replace(TAIL, block + "\n" + TAIL, 1)
    SRC.write_text(repaired, encoding="utf-8")
    print("Repaired v0.3 event expansion insertion location.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
