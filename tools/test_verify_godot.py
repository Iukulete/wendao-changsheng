"""Regression checks for the portable runner's false-success protections."""
from __future__ import annotations

import contextlib
import io
import os
from pathlib import Path
import sys
import tempfile
import unittest

import verify_godot


class VerifyGodotTests(unittest.TestCase):
    def setUp(self) -> None:
        parent = verify_godot.ROOT / ".tmp"
        parent.mkdir(exist_ok=True)
        self.directory = tempfile.TemporaryDirectory(prefix="verify-runner-", dir=parent)
        self.logs = Path(self.directory.name)

    def tearDown(self) -> None:
        self.directory.cleanup()

    def execute(self, code: str, *, marker: str | None = "PASS_OK:", timeout: int = 10) -> str:
        with contextlib.redirect_stdout(io.StringIO()):
            return verify_godot.run([sys.executable, "-c", code], "case", self.logs,
                                    os.environ.copy(), timeout, marker)

    def test_canonical_suite_contains_fixture_and_guard(self) -> None:
        tests = verify_godot.regression_scripts()
        self.assertIn("res://tests/ark_fixture_edit_test.gd", tests)
        self.assertIn("res://tests/ark_test_paths_test.gd", tests)
        self.assertIn("res://tests/ark_world_travel_test.gd", tests)

    def test_version_is_exact(self) -> None:
        self.assertRegex("4.7.1.stable.official.a13da4feb", verify_godot.VERSION_PATTERN)
        for version in ("4.6.3.stable.official.hash", "4.7.1.beta.official.hash", "4.7.1.stable.custom"):
            self.assertIsNone(verify_godot.VERSION_PATTERN.match(version))

    def test_success_retains_log(self) -> None:
        self.assertIn("PASS_OK:", self.execute("print('PASS_OK:')"))
        self.assertIn("PASS_OK:", (self.logs / "case.log").read_text())

    def test_zero_exit_without_marker_is_failure(self) -> None:
        with self.assertRaises(RuntimeError):
            self.execute("print('finished')")

    def test_error_even_with_marker_and_zero_exit_is_failure(self) -> None:
        for text in ("SCRIPT ERROR: assertion failed", "ERROR: failed load", "  ERROR: indented"):
            with self.subTest(text=text), self.assertRaises(RuntimeError):
                self.execute(f"print({text!r}); print('PASS_OK:')")

    def test_nonzero_exit_is_failure(self) -> None:
        with self.assertRaises(RuntimeError):
            self.execute("print('PASS_OK:'); raise SystemExit(1)")

    def test_timeout_is_failure(self) -> None:
        with self.assertRaisesRegex(RuntimeError, "exceeded"):
            self.execute("import time; time.sleep(10)", timeout=1)
        self.assertTrue((self.logs / "case.log").exists())


if __name__ == "__main__":
    unittest.main()
