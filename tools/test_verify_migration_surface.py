#!/usr/bin/env python3
"""Smoke-test the migration surface verifier against the current checkout."""

from __future__ import annotations

import unittest

import verify_migration_surface as surface


class MigrationSurfaceTests(unittest.TestCase):
    def test_current_checkout_has_the_complete_godot_surface(self) -> None:
        surface.verify()


if __name__ == "__main__":
    unittest.main()
