# -*- coding: utf-8 -*-
"""Repair v0.11 loader output, then apply the final runtime integration stage."""
from pathlib import Path

from apply_v12_story_art_runtime import main as apply_v12_story_art_runtime

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "wendao_enhanced.cpp"
MARKER = "V0_11_STORY_LOAD_NEWLINE_REPAIR"


def main() -> int:
    text = SRC.read_text(encoding="utf-8")
    if MARKER in text:
        print("v0.11 story-load newline repair already applied.")
    else:
        broken = "file.ignore(numeric_limits<streamsize>::max(), L'\n');"
        fixed = "file.ignore(numeric_limits<streamsize>::max(), L'\\n'); // V0_11_STORY_LOAD_NEWLINE_REPAIR"
        if broken not in text:
            raise RuntimeError("Unable to repair v0.11 STORY_STATE_V4 newline literal")
        text = text.replace(broken, fixed, 1)
        SRC.write_text(text, encoding="utf-8")
        print("Repaired v0.11 STORY_STATE_V4 newline literal.")

    # build.bat already invokes this as the last source-patch stage. Keep the
    # v0.12 art binding here so both normal builds and CI idempotence checks
    # exercise the same final source and install the verified library.
    return apply_v12_story_art_runtime()


if __name__ == "__main__":
    raise SystemExit(main())
