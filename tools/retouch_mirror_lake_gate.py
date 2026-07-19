#!/usr/bin/env python3
"""Create a restrained, same-canvas water-reflection layer for the Mirror Lake storyboard."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageOps


def build_reflection(source: Image.Image) -> Image.Image:
    width, height = source.size
    # The waterline sits just below the protagonist's hand/pendant in the approved base.
    waterline = 535
    crop_box = (20, 245, 600, waterline)
    crop = source.crop(crop_box).convert("RGBA")

    # Keep the reflection tied to the cloak silhouette rather than copying the room/sky.
    mask = Image.new("L", crop.size, 255)
    polygon = [
        (230, 0),
        (330, 0),
        (395, 62),
        (460, 130),
        (500, 205),
        (505, crop.height),
        (45, crop.height),
        (65, 235),
        (105, 180),
        (150, 120),
    ]
    polygon_mask = Image.new("L", crop.size, 0)
    ImageDraw.Draw(polygon_mask).polygon(polygon, fill=255)
    mask = ImageChops.multiply(mask, polygon_mask)

    reflected = ImageOps.flip(crop)
    reflected_mask = ImageOps.flip(mask)
    # A shallow water plane compresses the vertical reflection and softens its lower edge.
    reflected_height = int(reflected.height * 0.86)
    reflected = reflected.resize((reflected.width, reflected_height), Image.Resampling.LANCZOS)
    reflected_mask = reflected_mask.resize((reflected_mask.width, reflected_height), Image.Resampling.LANCZOS)
    # Feather the silhouette boundary so the reflection dissolves into existing ripples.
    reflected_mask = reflected_mask.filter(ImageFilter.GaussianBlur(9.0))
    reflected = ImageEnhance.Color(reflected).enhance(0.62)
    reflected = ImageEnhance.Contrast(reflected).enhance(0.92)
    reflected = reflected.filter(ImageFilter.GaussianBlur(0.9))

    # Fade with depth; the reflection is a cue, never a second character.
    gradient = Image.new("L", reflected_mask.size)
    gradient_px = gradient.load()
    for y in range(reflected_mask.height):
        depth_fade = max(0.0, 1.0 - y / max(1, reflected_mask.height - 1)) ** 1.25
        waterline_feather = min(1.0, y / 14.0)
        alpha = int(142 * depth_fade * waterline_feather)
        for x in range(reflected_mask.width):
            gradient_px[x, y] = alpha
    reflected_mask = ImageChops.multiply(reflected_mask, gradient)

    layer = Image.new("RGBA", source.size, (0, 0, 0, 0))
    layer.paste(reflected, (crop_box[0], waterline), reflected_mask)
    return layer


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--overlay", type=Path, required=True)
    args = parser.parse_args()

    base = Image.open(args.input).convert("RGBA")
    overlay = build_reflection(base)
    args.overlay.parent.mkdir(parents=True, exist_ok=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    overlay.save(args.overlay, format="PNG")
    Image.alpha_composite(base, overlay).convert("RGB").save(args.output, format="PNG", optimize=True)
    print(f"MIRROR_LAKE_RETOUCH_OK: {args.output}")


if __name__ == "__main__":
    main()
