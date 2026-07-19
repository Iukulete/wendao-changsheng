#!/usr/bin/env python3
"""Create restrained, transparent FX plates for the approved portrait canvas.

The runtime rig translates a complete transparent plate by a very small amount.
The five named presets below therefore draw only in background margins and then
apply a hard safety mask around the identity regions of each portrait.  They do
not alter, retouch, or replace the source portrait.
"""

from __future__ import annotations

import argparse
import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


CANVAS_SIZE = (1024, 1536)
RUNTIME_PRESETS = (
    "chi_yaoqing",
    "han_xuansu",
    "pei_zhaowei",
    "sect_lawkeepers",
    "family_covenant_holder",
)
PRESET_OUTPUTS = {
    "chi_yaoqing": "chi_yaoqing_local_fx.png",
    "han_xuansu": "han_xuansu_local_fx.png",
    "pei_zhaowei": "pei_zhaowei_local_fx.png",
    "sect_lawkeepers": "sect_lawkeepers_local_fx.png",
    "family_covenant_holder": "family_covenant_holder_local_fx.png",
}


def _shape(kind: str, value: object) -> tuple[str, object]:
    return kind, value


def _draw_shapes(mask: Image.Image, shapes: list[tuple[str, object]], fill: int) -> None:
    draw = ImageDraw.Draw(mask)
    for kind, value in shapes:
        if kind == "ellipse":
            draw.ellipse(value, fill=fill)
        elif kind == "polygon":
            draw.polygon(value, fill=fill)
        else:
            draw.rectangle(value, fill=fill)


def _edge_mask(size: tuple[int, int], band: int,
               extra_allowed: list[tuple[str, object]]) -> Image.Image:
    width, height = size
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    edge = max(1, min(int(band), min(width, height) // 2))
    draw.rectangle((0, 0, width - 1, edge - 1), fill=255)
    draw.rectangle((0, height - edge, width - 1, height - 1), fill=255)
    draw.rectangle((0, 0, edge - 1, height - 1), fill=255)
    draw.rectangle((width - edge, 0, width - 1, height - 1), fill=255)
    _draw_shapes(mask, extra_allowed, 255)
    return mask


def _apply_safety_mask(image: Image.Image, size: tuple[int, int], band: int,
                       extra_allowed: list[tuple[str, object]],
                       locked_regions: list[tuple[str, object]]) -> Image.Image:
    """Keep effects in the margins and erase a generous identity/prop guard."""
    allowed = _edge_mask(size, band, extra_allowed)
    locked = Image.new("L", size, 0)
    _draw_shapes(locked, locked_regions, 255)
    locked = locked.filter(ImageFilter.MaxFilter(17))
    allowed = ImageChops.subtract(allowed, locked)
    alpha = ImageChops.multiply(image.getchannel("A"), allowed)
    image.putalpha(alpha)
    visible = alpha.point(lambda value: 255 if value > 0 else 0)
    clean = Image.new("RGBA", size, (0, 0, 0, 0))
    clean.paste(image, (0, 0), visible)
    clean.putalpha(alpha)
    return clean


def _cubic_points(start: tuple[float, float], control_a: tuple[float, float],
                  control_b: tuple[float, float], end: tuple[float, float],
                  steps: int = 28) -> list[tuple[float, float]]:
    points: list[tuple[float, float]] = []
    for index in range(steps + 1):
        t = index / float(steps)
        inverse = 1.0 - t
        x = (inverse ** 3) * start[0] + 3.0 * (inverse ** 2) * t * control_a[0]
        x += 3.0 * inverse * (t ** 2) * control_b[0] + (t ** 3) * end[0]
        y = (inverse ** 3) * start[1] + 3.0 * (inverse ** 2) * t * control_a[1]
        y += 3.0 * inverse * (t ** 2) * control_b[1] + (t ** 3) * end[1]
        points.append((x, y))
    return points


def _draw_vapor(base: Image.Image, rng: random.Random,
                anchors: list[tuple[tuple[float, float], tuple[float, float]]],
                color: tuple[int, int, int], count: int = 4) -> Image.Image:
    soft = Image.new("RGBA", base.size, (0, 0, 0, 0))
    core = Image.new("RGBA", base.size, (0, 0, 0, 0))
    soft_draw = ImageDraw.Draw(soft)
    core_draw = ImageDraw.Draw(core)
    for anchor_index in range(count):
        start, end = anchors[anchor_index % len(anchors)]
        jitter = (rng.uniform(-18.0, 18.0), rng.uniform(-14.0, 14.0))
        start = (start[0] + jitter[0], start[1] + jitter[1])
        end = (end[0] + jitter[0] * 0.35, end[1] + jitter[1] * 0.35)
        bend = rng.uniform(-110.0, 110.0)
        control_a = ((start[0] + end[0]) * 0.5 + bend, start[1] - 90.0)
        control_b = ((start[0] + end[0]) * 0.5 - bend * 0.55, end[1] + 80.0)
        points = _cubic_points(start, control_a, control_b, end, 32)
        alpha = rng.randint(44, 86)
        soft_draw.line(points, fill=(*color, alpha), width=rng.randint(13, 22), joint="curve")
        core_draw.line(points, fill=(*color, min(125, alpha + 28)), width=rng.randint(2, 4), joint="curve")
        for point in points[::8]:
            radius = rng.uniform(3.0, 7.0)
            soft_draw.ellipse(
                (point[0] - radius, point[1] - radius,
                 point[0] + radius, point[1] + radius),
                fill=(*color, rng.randint(18, 40)),
            )
    soft = soft.filter(ImageFilter.GaussianBlur(12.0))
    return Image.alpha_composite(Image.alpha_composite(base, soft), core)


def _draw_particles(base: Image.Image, rng: random.Random,
                    zones: list[tuple[int, int, int, int]], count: int,
                    color: tuple[int, int, int], radius: tuple[int, int] = (1, 4),
                    alpha: tuple[int, int] = (26, 82)) -> Image.Image:
    soft = Image.new("RGBA", base.size, (0, 0, 0, 0))
    crisp = Image.new("RGBA", base.size, (0, 0, 0, 0))
    soft_draw = ImageDraw.Draw(soft)
    crisp_draw = ImageDraw.Draw(crisp)
    for index in range(count):
        x0, y0, x1, y1 = zones[index % len(zones)]
        x = rng.uniform(x0, x1)
        y = rng.uniform(y0, y1)
        r = rng.randint(radius[0], radius[1])
        a = rng.randint(alpha[0], alpha[1])
        soft_draw.ellipse((x - r * 2.2, y - r * 2.2, x + r * 2.2, y + r * 2.2),
                          fill=(*color, max(8, a // 3)))
        crisp_draw.ellipse((x - r, y - r, x + r, y + r), fill=(*color, a))
    soft = soft.filter(ImageFilter.GaussianBlur(4.0))
    return Image.alpha_composite(Image.alpha_composite(base, soft), crisp)


def _draw_rain(base: Image.Image, rng: random.Random,
               zones: list[tuple[int, int, int, int]], count: int,
               color: tuple[int, int, int]) -> Image.Image:
    soft = Image.new("RGBA", base.size, (0, 0, 0, 0))
    crisp = Image.new("RGBA", base.size, (0, 0, 0, 0))
    soft_draw = ImageDraw.Draw(soft)
    crisp_draw = ImageDraw.Draw(crisp)
    for index in range(count):
        x0, y0, x1, y1 = zones[index % len(zones)]
        x = rng.uniform(x0, x1)
        y = rng.uniform(y0, y1)
        length = rng.uniform(18.0, 48.0)
        drift = rng.uniform(-12.0, -3.0)
        a = rng.randint(28, 76)
        end = (x + drift, y + length)
        soft_draw.line((x, y, *end), fill=(*color, max(10, a // 2)), width=4)
        crisp_draw.line((x, y, *end), fill=(*color, a), width=1)
    soft = soft.filter(ImageFilter.GaussianBlur(3.0))
    return Image.alpha_composite(Image.alpha_composite(base, soft), crisp)


def _draw_ribbon(base: Image.Image, rng: random.Random,
                 curves: list[tuple[tuple[float, float], tuple[float, float]]],
                 color: tuple[int, int, int]) -> Image.Image:
    soft = Image.new("RGBA", base.size, (0, 0, 0, 0))
    core = Image.new("RGBA", base.size, (0, 0, 0, 0))
    soft_draw = ImageDraw.Draw(soft)
    core_draw = ImageDraw.Draw(core)
    for start, end in curves:
        sway = rng.uniform(-45.0, 45.0)
        points = _cubic_points(
            start,
            (start[0] + sway, (start[1] + end[1]) * 0.35),
            (end[0] - sway * 0.5, (start[1] + end[1]) * 0.72),
            end,
            36,
        )
        soft_draw.line(points, fill=(*color, 38), width=25, joint="curve")
        core_draw.line(points, fill=(*color, 75), width=5, joint="curve")
        highlight = [(x + 5.0, y) for x, y in points]
        core_draw.line(highlight, fill=(230, 215, 176, 34), width=2, joint="curve")
    soft = soft.filter(ImageFilter.GaussianBlur(10.0))
    return Image.alpha_composite(Image.alpha_composite(base, soft), core)


def _draw_cloud_light(base: Image.Image, glows: list[tuple[int, int, int, tuple[int, int, int], int]],
                      arcs: list[tuple[int, int, int, tuple[int, int, int]]]) -> Image.Image:
    soft = Image.new("RGBA", base.size, (0, 0, 0, 0))
    glint = Image.new("RGBA", base.size, (0, 0, 0, 0))
    soft_draw = ImageDraw.Draw(soft)
    glint_draw = ImageDraw.Draw(glint)
    for x, y, radius, color, alpha in glows:
        soft_draw.ellipse((x - radius, y - radius, x + radius, y + radius),
                          fill=(*color, alpha))
    for x, y, radius, color in arcs:
        glint_draw.arc((x - radius, y - radius, x + radius, y + radius),
                       195, 330, fill=(*color, 72), width=3)
    soft = soft.filter(ImageFilter.GaussianBlur(32.0))
    glint = glint.filter(ImageFilter.GaussianBlur(1.6))
    return Image.alpha_composite(Image.alpha_composite(base, soft), glint)


def _preset_spec(name: str) -> dict[str, object]:
    """Return edge and identity guards for a runtime portrait."""
    specs: dict[str, dict[str, object]] = {
        "chi_yaoqing": {
            "band": 188,
            "extra": [_shape("rect", (0, 90, 165, 1330)), _shape("rect", (870, 90, 1023, 1080))],
            "locked": [
                _shape("ellipse", (285, 115, 735, 610)),  # face and asymmetric crop
                _shape("polygon", [(120, 500), (370, 500), (420, 1040), (125, 1080)]),
                _shape("ellipse", (420, 760, 750, 1095)),  # bowl hand and medicine bowl
                _shape("rect", (245, 955, 885, 1535)),  # cross-body medicine chest
                _shape("polygon", [(675, 160), (1023, 160), (1023, 930), (720, 850)]),
            ],
        },
        "han_xuansu": {
            "band": 176,
            "extra": [_shape("rect", (0, 60, 150, 1230)), _shape("rect", (900, 60, 1023, 1320))],
            "locked": [
                _shape("ellipse", (270, 145, 640, 590)),  # face and geometric bob
                _shape("polygon", [(320, 535), (620, 535), (665, 990), (315, 1010)]),
                _shape("polygon", [(560, 620), (980, 620), (1023, 1290), (520, 1350)]),
                _shape("rect", (170, 405, 760, 1535)),  # structured coat and contract board
            ],
        },
        "pei_zhaowei": {
            "band": 210,
            "extra": [_shape("rect", (0, 0, 300, 360)), _shape("rect", (760, 0, 1023, 360))],
            "locked": [
                _shape("ellipse", (280, 115, 670, 560)),
                _shape("polygon", [(0, 420), (390, 420), (410, 940), (0, 980)]),
                _shape("polygon", [(650, 520), (1023, 520), (1023, 980), (680, 960)]),
                _shape("rect", (280, 980, 900, 1535)),
            ],
        },
        "sect_lawkeepers": {
            "band": 178,
            "extra": [_shape("rect", (430, 120, 610, 710))],
            "locked": [
                _shape("ellipse", (35, 235, 465, 700)),
                _shape("ellipse", (575, 135, 970, 650)),
                _shape("polygon", [(190, 680), (820, 680), (850, 1110), (160, 1110)]),
                _shape("rect", (0, 1110, 470, 1535)),
                _shape("rect", (620, 1110, 1023, 1535)),
            ],
        },
        "family_covenant_holder": {
            "band": 182,
            "extra": [_shape("rect", (785, 0, 1023, 650))],
            "locked": [
                _shape("ellipse", (65, 210, 485, 690)),
                _shape("ellipse", (495, 270, 930, 760)),
                _shape("polygon", [(180, 760), (850, 760), (900, 1270), (120, 1270)]),
                _shape("rect", (0, 1190, 1023, 1535)),
            ],
        },
    }
    return specs[name]


def _render_runtime_preset(name: str, size: tuple[int, int], seed: int) -> Image.Image:
    if size != CANVAS_SIZE:
        raise ValueError(f"runtime preset {name} requires a 1024x1536 canvas")
    rng = random.Random(seed)
    output = Image.new("RGBA", size, (0, 0, 0, 0))

    if name == "chi_yaoqing":
        output = _draw_vapor(
            output,
            rng,
            [((44, 1320), (74, 970)), ((979, 1190), (957, 730)), ((985, 1420), (930, 1040))],
            (188, 214, 190),
            count=6,
        )
        output = _draw_particles(
            output, rng,
            [(0, 720, 150, 1260), (875, 640, 1023, 1120), (0, 1180, 175, 1290)],
            42, (207, 184, 121), (1, 3), (22, 66),
        )
    elif name == "han_xuansu":
        output = _draw_vapor(
            output,
            rng,
            [((48, 1380), (86, 1040)), ((976, 1350), (935, 1010))],
            (188, 210, 202),
            count=5,
        )
        output = _draw_particles(
            output, rng,
            [(0, 480, 145, 1230), (900, 470, 1023, 1260), (40, 1180, 180, 1450)],
            36, (183, 196, 173), (1, 3), (20, 58),
        )
    elif name == "pei_zhaowei":
        output = _draw_cloud_light(
            output,
            [(80, 110, 180, (216, 235, 255), 78), (955, 130, 200, (205, 226, 255), 64),
             (90, 390, 125, (248, 227, 177), 35), (970, 410, 145, (223, 240, 255), 30)],
            [(52, 190, 160, (205, 229, 255)), (975, 225, 190, (247, 228, 180))],
        )
        output = _draw_particles(
            output, rng,
            [(0, 160, 155, 690), (870, 160, 1023, 700)],
            34, (229, 232, 206), (1, 3), (18, 56),
        )
    elif name == "sect_lawkeepers":
        output = _draw_rain(
            output, rng,
            [(435, 135, 515, 700), (520, 135, 605, 700), (0, 130, 145, 800),
             (890, 120, 1023, 850)],
            64, (150, 181, 201),
        )
        output = _draw_particles(
            output, rng,
            [(0, 820, 150, 1090), (875, 820, 1023, 1110)],
            28, (182, 170, 132), (1, 3), (18, 54),
        )
    elif name == "family_covenant_holder":
        output = _draw_rain(
            output, rng,
            [(820, 90, 1023, 620), (30, 70, 145, 650)],
            42, (128, 160, 171),
        )
        output = _draw_ribbon(
            output, rng,
            [((935, -20), (970, 500)), ((85, -30), (55, 470))],
            (102, 111, 106),
        )
        output = _draw_particles(
            output, rng,
            [(0, 690, 150, 1120), (875, 680, 1023, 1110), (0, 1000, 170, 1190)],
            46, (193, 166, 116), (1, 3), (20, 62),
        )

    spec = _preset_spec(name)
    return _apply_safety_mask(
        output,
        size,
        int(spec["band"]),
        spec["extra"],
        spec["locked"],
    )


def male_overlay(size: tuple[int, int], seed: int) -> Image.Image:
    width, height = size
    rng = random.Random(seed)
    output = Image.new("RGBA", size, (0, 0, 0, 0))
    rain = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(rain)
    for _ in range(58):
        x = rng.randint(-40, width + 40)
        y = rng.randint(-40, height)
        length = rng.randint(12, 34)
        drift = rng.randint(-5, 3)
        alpha = rng.randint(18, 46)
        draw.line((x, y, x + drift, y + length), fill=(132, 176, 197, alpha), width=1)
    output = Image.alpha_composite(output, rain)

    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    jade_x, jade_y = int(width * 0.745), int(height * 0.53)
    glow_draw.ellipse(
        (jade_x - 34, jade_y - 34, jade_x + 34, jade_y + 34),
        fill=(31, 157, 184, 34),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(18))
    output = Image.alpha_composite(output, glow)
    return output


def female_overlay(size: tuple[int, int], seed: int) -> Image.Image:
    width, height = size
    rng = random.Random(seed)
    output = Image.new("RGBA", size, (0, 0, 0, 0))
    petals = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(petals)
    for _ in range(28):
        # Keep the face and hands quiet; motion belongs to the margins and hem.
        side = rng.choice(("left", "right", "top", "bottom"))
        if side == "left":
            x, y = rng.randint(12, 230), rng.randint(80, height - 30)
        elif side == "right":
            x, y = rng.randint(width - 220, width - 12), rng.randint(80, height - 30)
        elif side == "top":
            x, y = rng.randint(20, width - 20), rng.randint(20, 190)
        else:
            x, y = rng.randint(20, width - 20), rng.randint(height - 230, height - 20)
        rx = rng.randint(4, 10)
        ry = max(2, rx // 2)
        angle = rng.random() * math.tau
        points = []
        for i in range(8):
            theta = angle + i * math.tau / 8.0
            radius = rx if i % 2 == 0 else ry
            points.append((x + math.cos(theta) * radius, y + math.sin(theta) * radius))
        draw.polygon(points, fill=(245, 225, 236, rng.randint(22, 58)))
    output = Image.alpha_composite(output, petals.filter(ImageFilter.GaussianBlur(0.35)))

    glints = Image.new("RGBA", size, (0, 0, 0, 0))
    glint_draw = ImageDraw.Draw(glints)
    for x, y in ((520, 160), (650, 230), (300, 420), (820, 560)):
        if x < width and y < height:
            glint_draw.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(198, 235, 255, 66))
    output = Image.alpha_composite(output, glints.filter(ImageFilter.GaussianBlur(1.2)))
    return output


def main() -> None:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--kind", choices=("male", "female"),
                      help="legacy generic overlay preset")
    mode.add_argument("--preset", choices=RUNTIME_PRESETS,
                      help="portrait-specific edge FX with identity guards")
    mode.add_argument("--batch-runtime-five", action="store_true",
                      help="render all five portrait-specific overlays")
    parser.add_argument("--size", nargs=2, type=int, default=CANVAS_SIZE)
    parser.add_argument("--seed", type=int, default=20260719)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--out-dir", type=Path)
    args = parser.parse_args()
    size = (int(args.size[0]), int(args.size[1]))

    if args.batch_runtime_five:
        if args.out_dir is None or args.out is not None:
            parser.error("--batch-runtime-five requires --out-dir and does not accept --out")
        for index, preset in enumerate(RUNTIME_PRESETS):
            image = _render_runtime_preset(preset, size, args.seed + index * 1009)
            output = args.out_dir / PRESET_OUTPUTS[preset]
            output.parent.mkdir(parents=True, exist_ok=True)
            image.save(output, "PNG", optimize=True)
            print(
                f"ART_FX_OVERLAY: preset={preset} size={size[0]}x{size[1]} "
                f"mode={image.mode} path={output}"
            )
        return

    if args.out is None or args.out_dir is not None:
        parser.error("--kind/--preset requires --out and does not accept --out-dir")
    if args.preset:
        image = _render_runtime_preset(args.preset, size, args.seed)
        label = f"preset={args.preset}"
    else:
        image = male_overlay(size, args.seed) if args.kind == "male" else female_overlay(size, args.seed)
        label = f"kind={args.kind}"
    args.out.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.out, "PNG", optimize=True)
    print(
        f"ART_FX_OVERLAY: {label} size={size[0]}x{size[1]} "
        f"mode={image.mode} path={args.out}"
    )


if __name__ == "__main__":
    main()
