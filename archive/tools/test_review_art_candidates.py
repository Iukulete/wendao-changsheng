#!/usr/bin/env python3
"""Regression checks for the product-art candidate review tool."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

import review_art_candidates as review


class CandidateReviewTests(unittest.TestCase):
    def test_product_portrait_passes_and_writes_previews(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            y, x = np.mgrid[0:1536, 0:1024]
            rng = np.random.default_rng(42)
            texture = rng.normal(0.0, 8.0, size=(1536, 1024))
            red = np.clip((x / 1023.0) * 180.0 + 35.0 + texture, 0, 255)
            green = np.clip((y / 1535.0) * 160.0 + 30.0 + texture, 0, 255)
            blue = np.clip(((x + y) / 2558.0) * 150.0 + 25.0 + texture, 0, 255)
            pixels = np.stack((red, green, blue), axis=2).astype(np.uint8)
            path = root / "portrait_a.png"
            Image.fromarray(pixels, "RGB").save(path)
            report = review.analyze_candidate(path, "portrait")
            self.assertTrue(report["automated_pass"], report["failures"])
            previews = review.write_runtime_previews(path, "portrait", root / "review")
            self.assertEqual(len(previews), 3)
            self.assertTrue(all(Path(preview).is_file() for preview in previews))

    def test_duplicate_candidates_are_not_distinct_product_choices(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            y, x = np.mgrid[0:1536, 0:1024]
            pixels = np.stack(
                (
                    np.mod(x, 256),
                    np.mod(y, 256),
                    np.mod(x + y, 256),
                ),
                axis=2,
            ).astype(np.uint8)
            first = root / "candidate_a.png"
            second = root / "candidate_b.png"
            Image.fromarray(pixels, "RGB").save(first)
            Image.fromarray(pixels, "RGB").save(second)
            comparison = review.compare_candidates(first, second)
            self.assertTrue(comparison["near_duplicate"])
            self.assertEqual(comparison["dhash_hamming"], 0)

    def test_small_flat_candidate_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "flat.png"
            Image.new("RGB", (256, 256), "#777777").save(path)
            report = review.analyze_candidate(path, "portrait")
            self.assertFalse(report["automated_pass"])
            self.assertGreaterEqual(len(report["failures"]), 3)

    def test_binary_cutout_uses_source_resolution_alpha_metrics(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            y, x = np.mgrid[0:1536, 0:1024]
            rgb = np.stack(
                (
                    40.0 + (x / 1023.0) * 130.0,
                    30.0 + (y / 1535.0) * 150.0,
                    70.0 + ((x + y) / 2558.0) * 120.0,
                ),
                axis=2,
            ).astype(np.uint8)
            alpha = (
                (x - 512) ** 2 / 360.0**2 + (y - 768) ** 2 / 650.0**2 <= 1.0
            ).astype(np.uint8) * 255
            path = root / "cutout.png"
            Image.fromarray(np.dstack((rgb, alpha)), "RGBA").save(path)
            report = review.analyze_candidate(path, "portrait", transparent_cutout=True)
            self.assertTrue(report["automated_pass"], report["failures"])
            self.assertEqual(report["opaque_nonzero_fraction"], 1.0)


if __name__ == "__main__":
    unittest.main()
