# -*- coding: utf-8 -*-
"""Move GetPathDimensionDigest below the global player declaration.

The v0.6 patch needs GetEffectiveKarmaScore visible inside Player methods, but
GetPathDimensionDigest reads g_player and therefore must be defined only after
the global Player instance exists. This repair is idempotent and runs before
compilation.
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "wendao_enhanced.cpp"
FUNCTION_START = "wstring GetPathDimensionDigest() {"
GLOBAL_ANCHOR = "EventManager g_eventMgr;"
EVENT_MARKER = "// ==================== 事件系统 ===================="


def find_function_end(text: str, start: int) -> int:
    brace = text.find("{", start)
    if brace < 0:
        raise RuntimeError("GetPathDimensionDigest opening brace is missing.")
    depth = 0
    for index in range(brace, len(text)):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                end = index + 1
                while end < len(text) and text[end] in "\r\n":
                    end += 1
                return end
    raise RuntimeError("GetPathDimensionDigest closing brace is missing.")


def main() -> int:
    if not SRC.exists():
        raise FileNotFoundError(f"Source file not found: {SRC}")

    content = SRC.read_text(encoding="utf-8")
    function_pos = content.find(FUNCTION_START)
    global_pos = content.find(GLOBAL_ANCHOR)
    if function_pos < 0:
        raise RuntimeError("GetPathDimensionDigest was not injected by v0.6 patch.")
    if global_pos < 0:
        raise RuntimeError("Unable to find global EventManager declaration.")
    if function_pos > global_pos:
        print("v0.6 path digest declaration order already repaired.")
        return 0

    function_end = find_function_end(content, function_pos)
    block = content[function_pos:function_end].strip("\r\n")
    without = content[:function_pos] + content[function_end:]

    # Keep only normal spacing before the event-system marker after removal.
    without = without.replace("\n\n\n" + EVENT_MARKER, "\n\n" + EVENT_MARKER, 1)

    insert_anchor = without.find(GLOBAL_ANCHOR)
    if insert_anchor < 0:
        raise RuntimeError("Global EventManager declaration disappeared during repair.")
    insert_pos = insert_anchor + len(GLOBAL_ANCHOR)
    repaired = without[:insert_pos] + "\n\n" + block + without[insert_pos:]
    SRC.write_text(repaired, encoding="utf-8")
    print("Repaired v0.6 path digest declaration order.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
