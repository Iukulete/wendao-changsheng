# -*- coding: utf-8 -*-
"""Move v0.3 injected events inside AddOpeningLocalEvents().

The first v0.3 patch appended the new AddEvent calls after the closing brace of
AddOpeningLocalEvents(), which makes C++ parse them as invalid member
declarations. This repair script is intentionally small and idempotent: it
removes the v0.3 block wherever it is and reinserts it immediately before the
closing brace of AddOpeningLocalEvents().
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "wendao_enhanced.cpp"
BEGIN = "        // V0_3_EVENT_EXPANSION_BEGIN"
END = "        // V0_3_EVENT_EXPANSION_END"
MARKER = "    // V0_2_OPENING_EVENTS_END"


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

    marker_pos = without.find(MARKER)
    if marker_pos < 0:
        raise RuntimeError("Unable to find v0.2 opening events end marker.")

    # Find the last line that is exactly the function closing brace before the
    # v0.2 end marker. This works with both CRLF and LF layouts.
    closing_matches = list(re.finditer(r"(?m)^    \}\s*$", without[:marker_pos]))
    if not closing_matches:
        raise RuntimeError("Unable to find AddOpeningLocalEvents closing brace before v0.2 end marker.")
    insert_pos = closing_matches[-1].start()

    repaired = without[:insert_pos] + block + "\n" + without[insert_pos:]
    SRC.write_text(repaired, encoding="utf-8")
    print("Repaired v0.3 event expansion insertion location.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
