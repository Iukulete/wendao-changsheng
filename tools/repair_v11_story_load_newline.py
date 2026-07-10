# -*- coding: utf-8 -*-
"""Repair the generated wide newline literal in the v0.11 STORY_STATE_V4 loader."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "wendao_enhanced.cpp"
MARKER = "V0_11_STORY_LOAD_NEWLINE_REPAIR"


def main() -> int:
    text = SRC.read_text(encoding="utf-8")
    if MARKER in text:
        print("v0.11 story-load newline repair already applied.")
        return 0
    broken = "file.ignore(numeric_limits<streamsize>::max(), L'\n');"
    fixed = "file.ignore(numeric_limits<streamsize>::max(), L'\\n'); // V0_11_STORY_LOAD_NEWLINE_REPAIR"
    if broken not in text:
        raise RuntimeError("Unable to repair v0.11 STORY_STATE_V4 newline literal")
    text = text.replace(broken, fixed, 1)
    SRC.write_text(text, encoding="utf-8")
    print("Repaired v0.11 STORY_STATE_V4 newline literal.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
