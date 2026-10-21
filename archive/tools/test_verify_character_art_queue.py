from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "verify_character_art_queue.py"


def test_current_character_art_queue_passes_single_target_gate() -> None:
    result = subprocess.run(
        [sys.executable, str(SCRIPT)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=False,
    )
    output = result.stdout + result.stderr
    assert result.returncode == 0, output
    assert "TARGETS 122" in output
    assert "ACTIVE lu_xiao" in output
    assert "PORTRAIT_MASTER_PENDING 1" in output
