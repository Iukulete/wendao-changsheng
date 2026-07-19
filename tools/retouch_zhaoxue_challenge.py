#!/usr/bin/env python3
"""Move the protagonist's jade from his back to his front without redrawing the frame."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


def ellipse_mask(size: tuple[int, int], feather: float, inset: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).ellipse(
        (inset, inset, size[0] - inset - 1, size[1] - inset - 1), fill=255
    )
    return mask.filter(ImageFilter.GaussianBlur(feather))


def build_retouch_layer(base: Image.Image) -> Image.Image:
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))

    # Clone same-cloak brocade over the misplaced back pendant. The mask is broad enough
    # to remove its hard circular rim, but feathered so surrounding tassels remain natural.
    repair_source = (370, 500, 490, 640)
    repair_target = (85, 500)
    repair = base.crop(repair_source).convert("RGBA")
    repair_mask = Image.new("L", repair.size, 0)
    ImageDraw.Draw(repair_mask).rounded_rectangle(
        (1, 1, repair.width - 2, repair.height - 2), radius=16, fill=255
    )
    repair_mask = repair_mask.filter(ImageFilter.GaussianBlur(6.0))
    layer.paste(repair, repair_target, repair_mask)

    # Reuse the complete jade from this frame. The earlier crop clipped its pale lower
    # half and right rim, making the relocated identity anchor read as a dark button.
    jade_box = (117, 538, 199, 630)
    jade = base.crop(jade_box).convert("RGBA")
    jade_mask = ellipse_mask(jade.size, 1.5, 5)
    jade_size = (60, 67)
    jade = jade.resize(jade_size, Image.Resampling.LANCZOS)
    jade_mask = jade_mask.resize(jade_size, Image.Resampling.LANCZOS)
    jade_xy = (442, 472)

    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    shadow_mask = Image.new("L", base.size, 0)
    ImageDraw.Draw(shadow_mask).ellipse((440, 470, 506, 543), fill=92)
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(4.0))
    shadow.paste((0, 5, 10, 120), (0, 0, base.width, base.height), shadow_mask)
    layer = Image.alpha_composite(layer, shadow)

    # A restrained fine chain tucks under the hood and follows the front plane of the torso.
    chain = Image.new("RGBA", base.size, (0, 0, 0, 0))
    chain_draw = ImageDraw.Draw(chain)
    chain_points = [(458, 387), (462, 418), (466, 442), (470, 466), (472, 480)]
    chain_draw.line(chain_points, fill=(151, 169, 178, 125), width=1, joint="curve")
    for x, y in chain_points[1:-1]:
        chain_draw.ellipse((x - 1, y - 1, x + 1, y + 1), fill=(171, 191, 200, 135))
    layer = Image.alpha_composite(layer, chain)
    layer.paste(jade, jade_xy, jade_mask)
    return layer


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--overlay", type=Path, required=True)
    args = parser.parse_args()

    base = Image.open(args.input).convert("RGBA")
    overlay = build_retouch_layer(base)
    result = Image.alpha_composite(base, overlay)
    args.overlay.parent.mkdir(parents=True, exist_ok=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    overlay.save(args.overlay, format="PNG")
    result.convert("RGB").save(args.output, format="PNG", optimize=True)
    changed = ImageChops.difference(base.convert("RGB"), result.convert("RGB")).getbbox()
    print(f"ZHAOXUE_CHALLENGE_RETOUCH_OK: changed={changed}")


if __name__ == "__main__":
    main()
