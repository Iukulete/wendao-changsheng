"""Normalize a web-generated combat sheet for the Godot art pipeline."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from PIL import Image, ImageEnhance


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--columns", type=int, required=True)
    parser.add_argument("--rows", type=int, required=True)
    parser.add_argument("--width", type=int, required=True)
    parser.add_argument("--height", type=int, required=True)
    parser.add_argument("--saturation", type=float, default=0.58)
    args = parser.parse_args()

    if args.columns < 1 or args.rows < 1:
        raise SystemExit("columns and rows must be positive")
    if args.width % args.columns or args.height % args.rows:
        raise SystemExit("output dimensions must be divisible by the grid")
    if not 0.0 <= args.saturation <= 2.0:
        raise SystemExit("saturation must be between 0 and 2")

    image = Image.open(args.input).convert("RGBA")
    if image.size != (args.width, args.height):
        image = image.resize((args.width, args.height), Image.Resampling.NEAREST)
    image = ImageEnhance.Color(image).enhance(args.saturation)

    alpha = image.getchannel("A")
    alpha = alpha.point(lambda value: 0 if value < 32 else value)
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
