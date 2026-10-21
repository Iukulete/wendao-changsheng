"""Regression checks for the portable runner's false-success protections."""
from __future__ import annotations

import contextlib
import io
import os
from pathlib import Path, PureWindowsPath
import sys
import tempfile
import unittest
from unittest import mock

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
        for version in ("4.6.3.stable.official.hash", "4.7.1.beta.official.hash", "4.7.1.stable.custom", "4.7.1.stable.official.hash", "4.7.1.stable.official.a13da4feb.extra"):
            self.assertIsNone(verify_godot.VERSION_PATTERN.match(version))

    def test_render_environment_uses_godot_paths_on_windows(self) -> None:
        # Exercise the real render branch with Windows path semantics on any OS.
        # No engine, filesystem copy or display is used by this runner unit test.
        class WindowsFixturePath(PureWindowsPath):
            def resolve(self):
                return self

            def is_file(self):
                return True

            def mkdir(self, *args, **kwargs):
                pass

            def unlink(self, *args, **kwargs):
                pass

            def read_text(self, *args, **kwargs):
                return "[display]\n"

            def write_text(self, *args, **kwargs):
                pass

        captured = {}

        def record(command, name, logs, env, *args, **kwargs):
            captured[name] = (list(command), dict(env))
            return "4.7.1.stable.official.a13da4feb" if name == "version" else ""

        with mock.patch.object(verify_godot, "ROOT", WindowsFixturePath("D:/ark")), \
                mock.patch.object(verify_godot, "Path", WindowsFixturePath), \
                mock.patch.object(verify_godot.shutil, "copytree"), \
                mock.patch.object(verify_godot, "verify_captures"), \
                mock.patch.object(verify_godot, "run", side_effect=record), \
                mock.patch.object(sys, "argv", ["verify_godot.py", "--godot", "D:/godot.exe",
                                                "--render-only", "--display-driver", "windows"]), \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(verify_godot.main(), 0)
        for name, variable, destination in (
                ("ark_render_capture_test", "ARK_RENDER_CAPTURE_ROOT", "ark-render-captures"),
                ("ark_gerstner_render_test", "ARK_GERSTNER_ARTIFACT_ROOT", "gerstner-render"),
                ("ark_pixel_protagonist_render_test", "ARK_PIXEL_ARTIFACT_ROOT", "pixel-render")):
            with self.subTest(script=name):
                command, env = captured[name]
                self.assertEqual(env[variable], "D:/ark/.tmp/" + destination)
                self.assertNotIn("--headless", command)

    def test_success_retains_log(self) -> None:
        self.assertIn("PASS_OK:", self.execute("print('PASS_OK:')"))
        self.assertIn("PASS_OK:", (self.logs / "case.log").read_text())

    def test_zero_exit_without_marker_is_failure(self) -> None:
        with self.assertRaises(RuntimeError):
            self.execute("print('finished')")

    def test_error_even_with_marker_and_zero_exit_is_failure(self) -> None:
        for text in ("SCRIPT ERROR: assertion failed", "ERROR: failed load", "  ERROR: indented", "\x1b[31mERROR: colored\x1b[0m", "FATAL ERROR: crash"):
            with self.subTest(text=text), self.assertRaises(RuntimeError):
                self.execute(f"print({text!r}); print('PASS_OK:')")

    def test_marker_inside_other_text_is_failure(self) -> None:
        for text in ("NOT_PASS_OK:", "expected PASS_OK:", "'PASS_OK:'"):
            with self.subTest(text=text), self.assertRaises(RuntimeError):
                self.execute(f"print({text!r})")

    def test_nonzero_exit_is_failure(self) -> None:
        with self.assertRaises(RuntimeError):
            self.execute("print('PASS_OK:'); raise SystemExit(1)")

    def test_timeout_is_failure(self) -> None:
        with self.assertRaisesRegex(RuntimeError, "exceeded"):
            self.execute("import time; time.sleep(10)", timeout=1)
        self.assertTrue((self.logs / "case.log").exists())


if __name__ == "__main__":
    unittest.main()
