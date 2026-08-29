#!/usr/bin/env python3
"""Remove a generated portrait's painted background with a reproducible GrabCut pass.

This is deliberately a candidate-stage tool. It never overwrites the source and
does not promote an image into the runtime catalog. Visual review and the
existing art-candidate checks remain mandatory after the alpha pass.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


def build_initial_mask(width: int, height: int, border: int) -> np.ndarray:
    mask = np.full((height, width), cv2.GC_PR_FGD, dtype=np.uint8)
    mask[:border, :] = cv2.GC_BGD
    mask[-border:, :] = cv2.GC_BGD
    mask[:, :border] = cv2.GC_BGD
    mask[:, -border:] = cv2.GC_BGD
    # A thin probable-background rim helps GrabCut learn the painted gradient
    # without erasing the long hair and robe that approach the canvas edge.
    rim = max(border * 3, 24)
    mask[border:rim, border:-border] = cv2.GC_PR_BGD
    mask[-rim:-border, border:-border] = cv2.GC_PR_BGD
    mask[border:-border, border:rim] = cv2.GC_PR_BGD
    mask[border:-border, -rim:-border] = cv2.GC_PR_BGD
    return mask


def add_foreground_seeds(mask: np.ndarray, bgr: np.ndarray) -> None:
    """Add conservative sure-foreground seeds from skin, jade, and robe pixels."""
    blue, green, red = (bgr[..., i].astype(np.int16) for i in range(3))
    brightness = (blue + green + red) / 3.0
    chroma = np.maximum.reduce([blue, green, red]) - np.minimum.reduce([blue, green, red])

    # Skin and warm metal are rare in the gray-green backdrop and make useful
    # anchors around the face, fingers, gold trim, and shoe hardware.
    skin_or_warm = (red > green + 8) & (red > blue + 12) & (brightness > 45)
    # Jade/teal cloth and ornaments are also distinct from the neutral backdrop.
    jade = (green > red + 4) & (blue > red + 2) & (chroma > 12) & (brightness > 35)
    warm_gold = (red > blue + 20) & (green > blue + 5) & (brightness > 65)
    seeds = skin_or_warm | jade | warm_gold
    mask[seeds] = cv2.GC_FGD

    # Large, central clothing cores are deliberately broad but inset from the
    # boundary so they do not turn the outer fog into foreground.
    h, w = mask.shape
    y0, y1 = int(h * 0.20), int(h * 0.91)
    x0, x1 = int(w * 0.24), int(w * 0.78)
    mask[y0:y1, x0:x1] = np.where(
        mask[y0:y1, x0:x1] == cv2.GC_BGD,
        cv2.GC_BGD,
        cv2.GC_PR_FGD,
    )


def remove_background(source: Path, destination: Path, iterations: int, border: int) -> None:
    bgr = cv2.imread(str(source), cv2.IMREAD_COLOR)
    if bgr is None:
        raise SystemExit(f"cannot read source image: {source}")
    height, width = bgr.shape[:2]
    if width != 1024 or height != 1536:
        raise SystemExit(f"expected 1024x1536 portrait, got {width}x{height}")

    mask = build_initial_mask(width, height, border)
    add_foreground_seeds(mask, bgr)
    background_model = np.zeros((1, 65), np.float64)
    foreground_model = np.zeros((1, 65), np.float64)
    cv2.grabCut(
        bgr,
        mask,
        None,
        background_model,
        foreground_model,
        iterations,
        cv2.GC_INIT_WITH_MASK,
    )

    foreground = np.where(
        (mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD), 255, 0
    ).astype(np.uint8)
    # Keep a narrow anti-aliased transition while making the generated asset's
    # solid interior fully opaque. The later QA report measures the result.
    alpha = cv2.GaussianBlur(foreground, (0, 0), 0.7)
    alpha[foreground == 255] = 255
    alpha[foreground == 0] = 0

    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    rgba = np.dstack([rgb, alpha]).astype(np.uint8)
    destination.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, mode="RGBA").save(destination, format="PNG", optimize=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--iterations", type=int, default=8)
    parser.add_argument("--border", type=int, default=8)
    args = parser.parse_args()
    remove_background(args.source.resolve(), args.destination.resolve(), args.iterations, args.border)
    print(f"PORTRAIT_ALPHA_CANDIDATE: {args.destination.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
