"""Normalize a web-generated combat sheet for the Godot art pipeline."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from PIL import Image, ImageEnhance


def pixelate_cells(
    image: Image.Image,
    columns: int,
    rows: int,
    base_width: int,
    base_height: int,
    palette_colors: int,
    alpha_threshold: int,
) -> Image.Image:
    """Reduce each atlas cell to a deliberate pixel-art base grid.

    The web generator may return a larger painted image even when a sprite
    sheet is requested.  Keeping the reduction cell-local prevents adjacent
    frames from bleeding into one another and makes the final nearest-neighbor
    scale reproducible for Godot.
    """
    cell_width = image.width // columns
    cell_height = image.height // rows
    result = Image.new("RGBA", image.size, (0, 0, 0, 0))
    for row in range(rows):
        for column in range(columns):
            left = column * cell_width
            top = row * cell_height
            box = (left, top, left + cell_width, top + cell_height)
            cell = image.crop(box)
            rgb_small = cell.convert("RGB").resize(
                (base_width, base_height), Image.Resampling.LANCZOS
            )
            rgb_small = rgb_small.quantize(
                colors=palette_colors,
                method=Image.Quantize.MEDIANCUT,
                dither=Image.Dither.NONE,
            ).convert("RGB")
            rgb_large = rgb_small.resize(
                (cell_width, cell_height), Image.Resampling.NEAREST
            )
            alpha_small = cell.getchannel("A").resize(
                (base_width, base_height), Image.Resampling.LANCZOS
            )
            alpha_small = alpha_small.point(
                lambda value: 255 if value >= alpha_threshold else 0
            )
            alpha_large = alpha_small.resize(
                (cell_width, cell_height), Image.Resampling.NEAREST
            )
            cell_result = Image.merge("RGBA", (*rgb_large.split(), alpha_large))
            result.paste(cell_result, (left, top))
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--columns", type=int, required=True)
    parser.add_argument("--rows", type=int, required=True)
    parser.add_argument("--width", type=int, required=True)
    parser.add_argument("--height", type=int, required=True)
    parser.add_argument("--saturation", type=float, default=0.58)
    parser.add_argument(
        "--pixel-base",
        default="",
        help="Optional WxH base grid per cell, e.g. 64x96, before nearest-neighbor upscaling",
    )
    parser.add_argument("--palette-colors", type=int, default=28)
    parser.add_argument("--alpha-threshold", type=int, default=32)
    args = parser.parse_args()

    if args.columns < 1 or args.rows < 1:
        raise SystemExit("columns and rows must be positive")
    if args.width % args.columns or args.height % args.rows:
        raise SystemExit("output dimensions must be divisible by the grid")
    if not 0.0 <= args.saturation <= 2.0:
        raise SystemExit("saturation must be between 0 and 2")
    if not 1 <= args.palette_colors <= 256:
        raise SystemExit("palette-colors must be between 1 and 256")
    if not 0 <= args.alpha_threshold <= 255:
        raise SystemExit("alpha-threshold must be between 0 and 255")

    image = Image.open(args.input).convert("RGBA")
    if image.size != (args.width, args.height):
        image = image.resize((args.width, args.height), Image.Resampling.NEAREST)
    image = ImageEnhance.Color(image).enhance(args.saturation)

    if args.pixel_base:
        try:
            base_width, base_height = (int(value) for value in args.pixel_base.lower().split("x"))
        except ValueError as exc:
            raise SystemExit("pixel-base must use WxH, for example 64x96") from exc
        if base_width <= 0 or base_height <= 0:
            raise SystemExit("pixel-base dimensions must be positive")
        image = pixelate_cells(
            image,
            args.columns,
            args.rows,
            base_width,
            base_height,
            args.palette_colors,
            args.alpha_threshold,
        )
    else:
        alpha = image.getchannel("A")
        alpha = alpha.point(lambda value: 0 if value < args.alpha_threshold else value)
        image.putalpha(alpha)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.output, format="PNG", optimize=True)
    payload = args.output.read_bytes()
    print(
        f"processed {args.output} {image.size[0]}x{image.size[1]} "
        f"bytes={len(payload)} sha256={hashlib.sha256(payload).hexdigest()}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
