#!/usr/bin/env python3
"""Derive transparent dialogue bust and avatar assets from a v2 portrait.

This is a candidate-stage helper. It never edits the portrait master and does
not update the registry or manifest. A visual identity gate is still required
before the generated bust/avatar are promoted into runtime paths.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


PORTRAIT_SIZE = (1024, 1536)
BUST_SIZE = (1024, 1024)
AVATAR_SIZE = (512, 512)


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError("portrait has no visible alpha pixels")
    return bbox


def crop_focus(
    image: Image.Image,
    bbox: tuple[int, int, int, int],
    *,
    focus_y: float,
    side_ratio: float,
    focus_x: float,
) -> Image.Image:
    left, top, right, bottom = bbox
    visible_width = right - left
    visible_height = bottom - top
    side = max(32, min(image.width, int(visible_height * side_ratio)))
    center_x = (left + right) / 2.0 + visible_width * focus_x
    center_y = top + visible_height * focus_y
    x0 = int(round(center_x - side / 2.0))
    y0 = int(round(center_y - side / 2.0))
    x0 = max(0, min(image.width - side, x0))
    y0 = max(0, min(image.height - side, y0))
    return image.crop((x0, y0, x0 + side, y0 + side))


def save_dialogue_asset(
    image: Image.Image,
    output: Path,
    size: tuple[int, int],
) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    resized = image.resize(size, Image.Resampling.LANCZOS)
    resized.save(output, format="PNG", optimize=True, compress_level=9)


def derive(
    source: Path,
    bust_output: Path,
    avatar_output: Path,
    *,
    bust_focus_y: float,
    avatar_focus_y: float,
    focus_x: float,
) -> None:
    with Image.open(source) as opened:
        opened.load()
        if opened.format != "PNG":
            raise RuntimeError("v2 dialogue derivation requires a PNG portrait")
        if opened.size != PORTRAIT_SIZE:
            raise RuntimeError(
                f"portrait must be {PORTRAIT_SIZE[0]}x{PORTRAIT_SIZE[1]}, got "
                f"{opened.width}x{opened.height}"
            )
        image = opened.convert("RGBA")

    bbox = alpha_bbox(image)
    bust = crop_focus(
        image,
        bbox,
        focus_y=bust_focus_y,
        side_ratio=0.66,
        focus_x=focus_x,
    )
    avatar = crop_focus(
        image,
        bbox,
        focus_y=avatar_focus_y,
        side_ratio=0.36,
        focus_x=focus_x,
    )
    save_dialogue_asset(bust, bust_output, BUST_SIZE)
    save_dialogue_asset(avatar, avatar_output, AVATAR_SIZE)
    print(
        "DIALOGUE_ASSETS_V2_OK:"
        f" source={source} bbox={bbox}"
        f" bust={bust_output} {BUST_SIZE[0]}x{BUST_SIZE[1]}"
        f" avatar={avatar_output} {AVATAR_SIZE[0]}x{AVATAR_SIZE[1]}"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--bust-output", type=Path, required=True)
    parser.add_argument("--avatar-output", type=Path, required=True)
    parser.add_argument("--bust-focus-y", type=float, default=0.36)
    parser.add_argument("--avatar-focus-y", type=float, default=0.16)
    parser.add_argument("--focus-x", type=float, default=0.0)
    args = parser.parse_args()
    for value, name in (
        (args.bust_focus_y, "bust-focus-y"),
        (args.avatar_focus_y, "avatar-focus-y"),
    ):
        if not 0.0 <= value <= 1.0:
            raise SystemExit(f"{name} must be between 0 and 1")
    if not -0.5 <= args.focus_x <= 0.5:
        raise SystemExit("focus-x must be between -0.5 and 0.5")
    derive(
        args.source.resolve(),
        args.bust_output.resolve(),
        args.avatar_output.resolve(),
        bust_focus_y=args.bust_focus_y,
        avatar_focus_y=args.avatar_focus_y,
        focus_x=args.focus_x,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
