from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageChops, ImageColor, ImageDraw, ImageFilter


ROOT = Path(r"C:\Users\jame\Desktop\3dyou\assets")
ITEMS_DIR = ROOT / "items"
WEAPONS_DIR = ITEMS_DIR / "weapons"
ARTIFACTS_DIR = ITEMS_DIR / "artifacts"
CONSUMABLES_DIR = ITEMS_DIR / "consumables"
MATERIALS_DIR = ITEMS_DIR / "materials"
PREVIEW_DIR = ROOT / "previews"
DB_PATH = ROOT / "item_db.tsv"

SIZE = 512
CENTER = SIZE // 2


def ensure_dirs() -> None:
    for path in (WEAPONS_DIR, ARTIFACTS_DIR, CONSUMABLES_DIR, MATERIALS_DIR, PREVIEW_DIR):
        path.mkdir(parents=True, exist_ok=True)


def rgba(hex_value: str, alpha: int = 255) -> tuple[int, int, int, int]:
    r, g, b = ImageColor.getrgb(hex_value)
    return (r, g, b, alpha)


def lerp_color(a: tuple[int, int, int, int], b: tuple[int, int, int, int], t: float) -> tuple[int, int, int, int]:
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))


def vertical_gradient(size: tuple[int, int], top: tuple[int, int, int, int], bottom: tuple[int, int, int, int]) -> Image.Image:
    w, h = size
    img = Image.new("RGBA", size)
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        color = lerp_color(top, bottom, t)
        for x in range(w):
            px[x, y] = color
    return img


def polygon_mask(points: Iterable[tuple[float, float]]) -> Image.Image:
    mask = Image.new("L", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(mask)
    draw.polygon(list(points), fill=255)
    return mask


def ellipse_mask(box: tuple[int, int, int, int]) -> Image.Image:
    mask = Image.new("L", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse(box, fill=255)
    return mask


def rounded_rect_mask(box: tuple[int, int, int, int], radius: int) -> Image.Image:
    mask = Image.new("L", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(box, radius=radius, fill=255)
    return mask


def compose_gradient_shape(base: Image.Image, mask: Image.Image, top: tuple[int, int, int, int], bottom: tuple[int, int, int, int]) -> None:
    grad = vertical_gradient((SIZE, SIZE), top, bottom)
    base.alpha_composite(Image.composite(grad, Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0)), mask))


def add_outline(base: Image.Image, mask: Image.Image, color: tuple[int, int, int, int], width: int) -> None:
    edge = mask.filter(ImageFilter.MaxFilter(width * 2 + 1))
    rim = ImageChops.subtract(edge, mask)
    overlay = Image.new("RGBA", (SIZE, SIZE), color)
    base.alpha_composite(Image.composite(overlay, Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0)), rim))


def add_soft_shadow(base: Image.Image, mask: Image.Image, offset: tuple[int, int], blur: int, color: tuple[int, int, int, int]) -> None:
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    alpha = mask.filter(ImageFilter.GaussianBlur(blur))
    tinted = Image.new("RGBA", (SIZE, SIZE), color)
    shadow.alpha_composite(Image.composite(tinted, Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0)), alpha), dest=offset)
    base.alpha_composite(shadow)


def add_highlight(base: Image.Image, box: tuple[int, int, int, int], color: tuple[int, int, int, int], blur: int = 0) -> None:
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.ellipse(box, fill=color)
    if blur:
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(layer)


def draw_backdrop(base: Image.Image, glow_a: str, glow_b: str) -> None:
    draw = ImageDraw.Draw(base)
    for radius, alpha in ((188, 165), (154, 110), (122, 70)):
        ring = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        ring_draw = ImageDraw.Draw(ring)
        ring_draw.ellipse((CENTER - radius, CENTER - radius, CENTER + radius, CENTER + radius), fill=rgba(glow_a, alpha))
        ring = ring.filter(ImageFilter.GaussianBlur(28))
        base.alpha_composite(ring)

    core = vertical_gradient((SIZE, SIZE), rgba(glow_a, 230), rgba(glow_b, 210))
    mask = ellipse_mask((86, 86, 426, 426))
    blurred = mask.filter(ImageFilter.GaussianBlur(14))
    base.alpha_composite(Image.composite(core, Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0)), blurred))

    draw.ellipse((32, 32, 480, 480), outline=rgba("#d5b25f", 235), width=7)
    draw.ellipse((52, 52, 460, 460), outline=rgba("#fff2c8", 50), width=2)


def draw_plate(base: Image.Image, kind: str, accent: str) -> None:
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    if kind == "weapon":
        pts = [(120, 124), (392, 124), (438, 256), (392, 388), (120, 388), (74, 256)]
        draw.polygon(pts, fill=rgba("#1c242d", 140))
        draw.line(pts + [pts[0]], fill=rgba(accent, 185), width=4)
    elif kind == "artifact":
        pts = [(256, 90), (412, 170), (412, 342), (256, 422), (100, 342), (100, 170)]
        draw.polygon(pts, fill=rgba("#221d28", 132))
        draw.line(pts + [pts[0]], fill=rgba(accent, 175), width=4)
    elif kind == "material":
        pts = [(138, 112), (374, 112), (420, 180), (374, 400), (138, 400), (92, 180)]
        draw.rounded_rectangle((108, 120, 404, 392), radius=44, outline=rgba(accent, 165), width=4, fill=rgba("#19232a", 118))
        draw.line(pts + [pts[0]], fill=rgba("#f2dfb6", 95), width=2)
    else:
        draw.rounded_rectangle((108, 118, 404, 394), radius=42, outline=rgba(accent, 175), width=4, fill=rgba("#202329", 126))

    layer = layer.filter(ImageFilter.GaussianBlur(0.6))
    base.alpha_composite(layer)


def save_asset(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)


def write_item_data(items: list[dict]) -> None:
    (ROOT / "item_lore.json").write_text(json.dumps(items, ensure_ascii=False, indent=2), encoding="utf-8")

    by_cat = {"weapons": [], "artifacts": [], "consumables": [], "materials": []}
    for item in items:
        by_cat[item["category"]].append({
            "id": item["id"],
            "name": item["name"],
            "tier": item["tier"],
            "asset": item["asset"],
        })
    (ROOT / "item_catalog.json").write_text(json.dumps(by_cat, ensure_ascii=False, indent=2), encoding="utf-8")

    lines = ["id\tname\tcategory\ttype\ttier\telement\tasset\tuse\tlore"]
    for item in items:
        values = [
            item["id"], item["name"], item["category"], item["type"], item["tier"],
            item["element"], item["asset"], item["use"], item["lore"]
        ]
        safe = [str(v).replace("\t", " ").replace("\n", " ") for v in values]
        lines.append("\t".join(safe))
    DB_PATH.write_text("\n".join(lines), encoding="utf-8")


def build_preview_sheet() -> None:
    categories = [
        ("Weapons", sorted(WEAPONS_DIR.glob("*.png"))),
        ("Artifacts", sorted(ARTIFACTS_DIR.glob("*.png"))),
        ("Consumables", sorted(CONSUMABLES_DIR.glob("*.png"))),
        ("Materials", sorted(MATERIALS_DIR.glob("*.png"))),
    ]

    card_w = 220
    card_h = 250
    margin = 36
    cols = 4
    rows = sum(max(1, (len(paths) + cols - 1) // cols) + 1 for _, paths in categories)
    sheet_w = margin * 2 + cols * card_w
    sheet_h = margin * 2 + rows * card_h
    sheet = Image.new("RGBA", (sheet_w, sheet_h), rgba("#0c1117"))
    draw = ImageDraw.Draw(sheet)

    y = margin
    for title, paths in categories:
        draw.text((margin, y), title, fill=rgba("#f2d798"))
        y += 42
        for idx, path in enumerate(paths):
            row = idx // cols
            col = idx % cols
            x0 = margin + col * card_w
            y0 = y + row * card_h
            draw.rounded_rectangle((x0, y0, x0 + 184, y0 + 210), radius=24, outline=rgba("#d4b46c", 180), width=3, fill=rgba("#111922", 220))
            icon = Image.open(path).convert("RGBA").resize((160, 160))
            sheet.alpha_composite(icon, (x0 + 12, y0 + 18))
            label = path.stem.replace("weapon_", "").replace("artifact_", "").replace("consumable_", "").replace("material_", "")
            draw.text((x0 + 14, y0 + 186), label, fill=rgba("#dbe6f2"))
        y += max(1, (len(paths) + cols - 1) // cols) * card_h + 26

    save_asset(sheet, PREVIEW_DIR / "item_atlas_v4.png")


@dataclass
class Palette:
    glow_a: str
    glow_b: str
    metal_a: str
    metal_b: str
    accent: str
    dark: str
    wood: str = "#5e422d"


def make_base(glow_a: str, glow_b: str) -> Image.Image:
    base = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw_backdrop(base, glow_a, glow_b)
    return base


def render_sword(path: Path, palette: Palette, broken: bool = False) -> None:
    base = make_base(palette.glow_a, palette.glow_b)
    draw_plate(base, "weapon", palette.accent)

    blade_points = [(256, 74), (292, 126), (278, 344), (256, 408), (234, 344), (220, 126)]
    if broken:
        blade_points = [(256, 84), (294, 138), (278, 280), (290, 312), (256, 346), (232, 290), (220, 138)]
    blade = polygon_mask(blade_points)
    add_soft_shadow(base, blade, (8, 8), 18, rgba("#000000", 90))
    compose_gradient_shape(base, blade, rgba(palette.metal_a), rgba(palette.metal_b))
    add_outline(base, blade, rgba("#241a17", 230), 5)
    add_highlight(base, (236, 92, 270, 210), rgba("#ffffff", 72), 6)

    guard = polygon_mask([(176, 286), (224, 250), (288, 250), (338, 286), (286, 312), (226, 312)])
    compose_gradient_shape(base, guard, rgba("#d9b15e"), rgba("#85561c"))
    add_outline(base, guard, rgba("#2a1d15", 220), 5)

    hilt = polygon_mask([(236, 302), (276, 302), (288, 410), (256, 448), (224, 410)])
    compose_gradient_shape(base, hilt, rgba(palette.dark), rgba("#2a211f"))
    add_outline(base, hilt, rgba("#241a17", 220), 5)

    pommel = ellipse_mask((240, 264, 272, 296))
    compose_gradient_shape(base, pommel, rgba(palette.accent), rgba("#ffffff"))
    add_outline(base, pommel, rgba("#2d1f19", 200), 4)

    save_asset(base, path)


def render_spear(path: Path, palette: Palette) -> None:
    base = make_base(palette.glow_a, palette.glow_b)
    draw_plate(base, "weapon", palette.accent)
    draw = ImageDraw.Draw(base)

    shaft = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shaft_draw = ImageDraw.Draw(shaft)
    shaft_draw.line((148, 408, 336, 122), fill=rgba(palette.wood), width=12)
    shaft_draw.line((148, 408, 336, 122), fill=rgba("#2b1f19", 145), width=4)
    shaft = shaft.filter(ImageFilter.GaussianBlur(0))
    base.alpha_composite(shaft)

    blade = polygon_mask([(322, 86), (364, 128), (310, 198), (278, 146)])
    add_soft_shadow(base, blade, (7, 7), 16, rgba("#000000", 85))
    compose_gradient_shape(base, blade, rgba(palette.metal_a), rgba(palette.metal_b))
    add_outline(base, blade, rgba("#241a17", 225), 5)

    tassel = polygon_mask([(244, 178), (204, 192), (180, 240), (204, 264), (242, 236), (256, 206)])
    compose_gradient_shape(base, tassel, rgba("#69a7ff"), rgba("#2450a9"))
    add_outline(base, tassel, rgba("#1f1720", 220), 4)

    draw.arc((178, 150, 430, 282), start=212, end=286, fill=rgba("#b9e8ff", 95), width=3)
    save_asset(base, path)


def render_gourd(path: Path, palette: Palette) -> None:
    base = make_base("#6b34e4", "#2a143a")
    draw_plate(base, "artifact", "#cda86d")

    top = ellipse_mask((186, 112, 330, 248))
    bottom = ellipse_mask((146, 206, 366, 394))
    body_mask = ImageChops.lighter(top, bottom)
    add_soft_shadow(base, body_mask, (10, 10), 22, rgba("#000000", 88))
    compose_gradient_shape(base, body_mask, rgba("#8f67d8"), rgba("#4a2a82"))
    add_outline(base, body_mask, rgba("#2a1a21", 225), 5)

    neck = rounded_rect_mask((226, 88, 286, 140), 6)
    compose_gradient_shape(base, neck, rgba("#7b5637"), rgba("#4f3521"))
    add_outline(base, neck, rgba("#2a1b15", 215), 4)

    seal = ellipse_mask((214, 246, 300, 330))
    compose_gradient_shape(base, seal, rgba("#e2c169"), rgba("#8f5d20"))
    add_outline(base, seal, rgba("#2a1d14", 210), 4)

    add_highlight(base, (196, 132, 254, 190), rgba("#ffffff", 44), 10)
    save_asset(base, path)


def render_pill_bottle(path: Path) -> None:
    base = make_base("#6fecc1", "#173e31")
    draw_plate(base, "consumable", "#d7c07c")

    bottle = rounded_rect_mask((182, 118, 332, 396), 18)
    add_soft_shadow(base, bottle, (8, 10), 20, rgba("#000000", 86))
    compose_gradient_shape(base, bottle, rgba("#d9fff2", 215), rgba("#7ab89e", 205))
    add_outline(base, bottle, rgba("#2a201a", 220), 5)

    liquid = rounded_rect_mask((198, 276, 316, 356), 6)
    compose_gradient_shape(base, liquid, rgba("#74d393", 220), rgba("#3f9d64", 210))

    label = rounded_rect_mask((202, 196, 312, 254), 8)
    compose_gradient_shape(base, label, rgba("#ece5be", 215), rgba("#bdb28d", 205))
    add_outline(base, label, rgba("#66543b", 70), 2)

    cap = rounded_rect_mask((206, 88, 308, 138), 6)
    compose_gradient_shape(base, cap, rgba("#91663f"), rgba("#5c3c20"))
    add_outline(base, cap, rgba("#2a1b14", 220), 4)

    add_highlight(base, (204, 130, 232, 360), rgba("#ffffff", 48), 12)
    save_asset(base, path)


def render_jade_slip(path: Path) -> None:
    base = make_base("#8ef0d1", "#1c4e3b")
    draw_plate(base, "artifact", "#9ce9c3")

    slip = polygon_mask([(186, 118), (344, 144), (320, 398), (164, 370)])
    add_soft_shadow(base, slip, (9, 10), 18, rgba("#000000", 84))
    compose_gradient_shape(base, slip, rgba("#d7f8ea"), rgba("#6aa58f"))
    add_outline(base, slip, rgba("#25201b", 225), 5)

    draw = ImageDraw.Draw(base)
    for idx, y in enumerate((174, 216, 258, 300)):
        x1 = 214 - idx * 5
        x2 = 296 - idx * 6
        draw.line((x1, y, x2, y + 12), fill=rgba("#f5ffe8", 185), width=5)

    add_highlight(base, (214, 134, 286, 182), rgba("#ffffff", 42), 12)
    save_asset(base, path)


def render_ling_stone(path: Path) -> None:
    base = make_base("#88cfff", "#16344d")
    draw_plate(base, "material", "#9fe9ff")

    crystal = polygon_mask([(256, 92), (326, 172), (294, 356), (256, 422), (210, 352), (182, 178)])
    add_soft_shadow(base, crystal, (8, 10), 18, rgba("#000000", 86))
    compose_gradient_shape(base, crystal, rgba("#dff8ff"), rgba("#5aaed4"))
    add_outline(base, crystal, rgba("#1c2028", 220), 5)

    draw = ImageDraw.Draw(base)
    draw.line((256, 102, 244, 350), fill=rgba("#ffffff", 88), width=3)
    draw.line((290, 166, 246, 278), fill=rgba("#bff3ff", 90), width=3)
    add_highlight(base, (232, 126, 286, 194), rgba("#ffffff", 42), 10)
    save_asset(base, path)


def render_herb(path: Path) -> None:
    base = make_base("#7deb99", "#173a24")
    draw_plate(base, "material", "#a6ef98")
    draw = ImageDraw.Draw(base)

    stem = polygon_mask([(248, 378), (268, 378), (280, 204), (256, 122), (232, 204)])
    compose_gradient_shape(base, stem, rgba("#98e586"), rgba("#3f7a37"))
    add_outline(base, stem, rgba("#23301d", 210), 4)

    leaves = [
        [(258, 184), (342, 150), (314, 220), (270, 218)],
        [(246, 218), (170, 178), (200, 256), (240, 242)],
        [(258, 260), (334, 252), (296, 328), (260, 306)],
        [(242, 286), (170, 314), (214, 368), (246, 324)],
    ]
    for idx, pts in enumerate(leaves):
        leaf = polygon_mask(pts)
        compose_gradient_shape(base, leaf, rgba("#d7ffd2"), rgba("#53a353" if idx % 2 == 0 else "#3d8348"))
        add_outline(base, leaf, rgba("#22331f", 200), 4)

    add_highlight(base, (212, 108, 286, 166), rgba("#fff8b8", 46), 10)
    save_asset(base, path)


def render_mirror(path: Path) -> None:
    base = make_base("#96d3ff", "#1c314f")
    draw_plate(base, "artifact", "#d2af68")

    outer = ellipse_mask((142, 110, 370, 338))
    add_soft_shadow(base, outer, (8, 9), 18, rgba("#000000", 84))
    compose_gradient_shape(base, outer, rgba("#d8bf74"), rgba("#84541d"))
    add_outline(base, outer, rgba("#2a1c14", 225), 5)

    inner = ellipse_mask((176, 144, 336, 304))
    compose_gradient_shape(base, inner, rgba("#eefcff"), rgba("#81b5df"))
    add_outline(base, inner, rgba("#6c8ba5", 85), 2)
    handle = rounded_rect_mask((228, 322, 284, 420), 10)
    compose_gradient_shape(base, handle, rgba("#7e5735"), rgba("#53341f"))
    add_outline(base, handle, rgba("#251912", 215), 4)

    add_highlight(base, (194, 160, 252, 220), rgba("#ffffff", 58), 12)
    save_asset(base, path)


def render_bow(path: Path) -> None:
    base = make_base("#f0b37d", "#40241d")
    draw_plate(base, "weapon", "#efb47b")
    draw = ImageDraw.Draw(base)

    bow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    bdraw = ImageDraw.Draw(bow)
    bdraw.arc((132, 108, 356, 404), start=280, end=80, fill=rgba("#6c4329"), width=16)
    bdraw.arc((150, 126, 338, 386), start=280, end=80, fill=rgba("#9a6a42"), width=6)
    bdraw.line((278, 122, 248, 390), fill=rgba("#dcecff", 220), width=4)
    bdraw.line((250, 196, 208, 256), fill=rgba("#dcecff", 220), width=4)
    bdraw.polygon([(196, 252), (222, 242), (212, 276)], fill=rgba("#b9dafc"))
    base.alpha_composite(bow)
    save_asset(base, path)


def render_talisman(path: Path) -> None:
    base = make_base("#f2ca77", "#4a2e1c")
    draw_plate(base, "consumable", "#f0d284")
    talisman = polygon_mask([(206, 116), (314, 116), (334, 316), (256, 404), (178, 316)])
    add_soft_shadow(base, talisman, (7, 8), 16, rgba("#000000", 80))
    compose_gradient_shape(base, talisman, rgba("#f6e9bb"), rgba("#caa061"))
    add_outline(base, talisman, rgba("#35261b", 210), 4)
    draw = ImageDraw.Draw(base)
    draw.line((242, 166, 270, 214), fill=rgba("#b33522"), width=7)
    draw.line((262, 184, 228, 236), fill=rgba("#b33522"), width=7)
    draw.line((244, 244, 282, 290), fill=rgba("#b33522"), width=7)
    save_asset(base, path)


def render_ore(path: Path) -> None:
    base = make_base("#b9c4da", "#283140")
    draw_plate(base, "material", "#cfdaf1")
    ore = polygon_mask([(166, 324), (192, 196), (254, 134), (356, 174), (372, 286), (304, 376), (212, 390)])
    add_soft_shadow(base, ore, (8, 9), 18, rgba("#000000", 84))
    compose_gradient_shape(base, ore, rgba("#dde5f4"), rgba("#79849d"))
    add_outline(base, ore, rgba("#22262d", 220), 5)
    draw = ImageDraw.Draw(base)
    draw.line((214, 198, 304, 354), fill=rgba("#ffffff", 86), width=4)
    draw.line((286, 162, 246, 286), fill=rgba("#9fd0ff", 82), width=3)
    save_asset(base, path)


def render_ring_blade(path: Path) -> None:
    base = make_base("#7bc7ff", "#182f48")
    draw_plate(base, "weapon", "#a0dbff")
    blade = ellipse_mask((154, 120, 358, 324))
    add_soft_shadow(base, blade, (7, 7), 16, rgba("#000000", 84))
    compose_gradient_shape(base, blade, rgba("#eff9ff"), rgba("#7ba5cf"))
    inner = ellipse_mask((206, 172, 306, 272))
    base.alpha_composite(Image.composite(Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0)), Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0)), inner))
    hole = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    hole_draw = ImageDraw.Draw(hole)
    hole_draw.ellipse((204, 170, 308, 274), fill=(0, 0, 0, 0))
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).ellipse((154, 120, 358, 324), fill=255)
    ImageDraw.Draw(mask).ellipse((204, 170, 308, 274), fill=0)
    base.alpha_composite(Image.composite(vertical_gradient((SIZE, SIZE), rgba("#f3fbff"), rgba("#7dadd3")), Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0)), mask))
    add_outline(base, mask, rgba("#1d2128", 220), 5)
    ribbon = polygon_mask([(314, 236), (382, 212), (360, 286), (304, 280)])
    compose_gradient_shape(base, ribbon, rgba("#8bd8ff"), rgba("#2f6eab"))
    add_outline(base, ribbon, rgba("#1b1d24", 210), 4)
    save_asset(base, path)


def render_tower(path: Path) -> None:
    base = make_base("#bca0ff", "#24163d")
    draw_plate(base, "artifact", "#d0b96f")
    levels = [
        (214, 304, 298, 372),
        (202, 238, 310, 314),
        (190, 176, 322, 248),
        (210, 126, 302, 184),
    ]
    for idx, box in enumerate(levels):
        mask = rounded_rect_mask(box, 8)
        compose_gradient_shape(base, mask, rgba("#d8c17a"), rgba("#8c6329"))
        add_outline(base, mask, rgba("#281c16", 220), 4)
        if idx < len(levels) - 1:
            roof = polygon_mask([(box[0] - 12, box[1] + 8), (box[2] + 12, box[1] + 8), (box[2] - 8, box[1] - 18), (box[0] + 8, box[1] - 18)])
            compose_gradient_shape(base, roof, rgba("#6c4e8f"), rgba("#40255d"))
            add_outline(base, roof, rgba("#201724", 200), 3)
    add_highlight(base, (220, 132, 286, 190), rgba("#fff0bb", 40), 10)
    save_asset(base, path)


def render_sigil(path: Path) -> None:
    base = make_base("#8affdc", "#183f3b")
    draw_plate(base, "artifact", "#9ef2d3")
    draw = ImageDraw.Draw(base)
    draw.polygon([(256, 134), (344, 194), (344, 316), (256, 378), (168, 316), (168, 194)], outline=rgba("#d9ffd5", 210), width=6)
    draw.ellipse((204, 204, 308, 308), outline=rgba("#d9ffd5", 195), width=5)
    draw.line((256, 154, 256, 358), fill=rgba("#d9ffd5", 195), width=4)
    draw.line((194, 256, 318, 256), fill=rgba("#d9ffd5", 195), width=4)
    draw.line((214, 188, 298, 324), fill=rgba("#8be9ff", 150), width=3)
    draw.line((298, 188, 214, 324), fill=rgba("#8be9ff", 150), width=3)
    save_asset(base, path)


def render_dagger(path: Path) -> None:
    base = make_base("#f4aba7", "#3b1a1c")
    draw_plate(base, "weapon", "#f0b8aa")
    blade = polygon_mask([(252, 108), (304, 184), (276, 316), (252, 368), (228, 314), (200, 182)])
    add_soft_shadow(base, blade, (7, 8), 16, rgba("#000000", 80))
    compose_gradient_shape(base, blade, rgba("#fff1ef"), rgba("#cf8c86"))
    add_outline(base, blade, rgba("#26191a", 220), 4)
    hilt = polygon_mask([(212, 292), (292, 292), (300, 320), (204, 320)])
    compose_gradient_shape(base, hilt, rgba("#9b7446"), rgba("#5e3f25"))
    add_outline(base, hilt, rgba("#261b14", 215), 4)
    pommel = ellipse_mask((236, 320, 272, 356))
    compose_gradient_shape(base, pommel, rgba("#ffd8c1"), rgba("#a66a49"))
    add_outline(base, pommel, rgba("#2b1b15", 200), 3)
    save_asset(base, path)


def render_orb(path: Path) -> None:
    base = make_base("#a2d5ff", "#182a45")
    draw_plate(base, "artifact", "#d7b96f")
    orb = ellipse_mask((170, 132, 342, 304))
    add_soft_shadow(base, orb, (8, 9), 18, rgba("#000000", 82))
    compose_gradient_shape(base, orb, rgba("#e5f7ff"), rgba("#80bbf1"))
    add_outline(base, orb, rgba("#25303d", 210), 4)
    stand = polygon_mask([(214, 320), (298, 320), (320, 382), (192, 382)])
    compose_gradient_shape(base, stand, rgba("#8a6139"), rgba("#4f3019"))
    add_outline(base, stand, rgba("#241911", 210), 4)
    add_highlight(base, (202, 150, 254, 202), rgba("#ffffff", 64), 10)
    save_asset(base, path)


def render_scroll(path: Path) -> None:
    base = make_base("#f1d395", "#42311d")
    draw_plate(base, "consumable", "#e7cb8b")
    page = rounded_rect_mask((188, 142, 324, 342), 18)
    compose_gradient_shape(base, page, rgba("#f7edcf"), rgba("#d9ba7e"))
    add_outline(base, page, rgba("#36281c", 210), 4)
    roller_top = rounded_rect_mask((200, 120, 312, 156), 10)
    roller_bottom = rounded_rect_mask((200, 328, 312, 364), 10)
    compose_gradient_shape(base, roller_top, rgba("#956944"), rgba("#5f3f26"))
    compose_gradient_shape(base, roller_bottom, rgba("#956944"), rgba("#5f3f26"))
    add_outline(base, roller_top, rgba("#281c14", 205), 3)
    add_outline(base, roller_bottom, rgba("#281c14", 205), 3)
    draw = ImageDraw.Draw(base)
    draw.line((224, 196, 288, 196), fill=rgba("#b3412a"), width=5)
    draw.line((214, 236, 292, 236), fill=rgba("#b3412a"), width=5)
    draw.line((222, 274, 284, 274), fill=rgba("#b3412a"), width=5)
    save_asset(base, path)


def render_seal(path: Path) -> None:
    base = make_base("#f0c37b", "#3e2518")
    draw_plate(base, "artifact", "#e8c87f")
    body = rounded_rect_mask((196, 150, 316, 314), 14)
    compose_gradient_shape(base, body, rgba("#c74438"), rgba("#6e1f18"))
    add_outline(base, body, rgba("#321816", 220), 5)
    knob = ellipse_mask((220, 110, 292, 176))
    compose_gradient_shape(base, knob, rgba("#f0d29d"), rgba("#8c683d"))
    add_outline(base, knob, rgba("#34241a", 210), 4)
    draw = ImageDraw.Draw(base)
    draw.rectangle((228, 238, 284, 278), outline=rgba("#f3d4a4", 170), width=4)
    save_asset(base, path)


def render_banner(path: Path) -> None:
    base = make_base("#9f8aff", "#22163d")
    draw_plate(base, "artifact", "#c3b27f")
    pole = polygon_mask([(244, 114), (268, 114), (278, 396), (254, 430), (230, 396)])
    compose_gradient_shape(base, pole, rgba("#9f7748"), rgba("#5d3d1f"))
    add_outline(base, pole, rgba("#251913", 210), 4)
    cloth = polygon_mask([(270, 128), (356, 146), (334, 314), (254, 292)])
    compose_gradient_shape(base, cloth, rgba("#9d83ff"), rgba("#5334a5"))
    add_outline(base, cloth, rgba("#23192b", 210), 4)
    draw = ImageDraw.Draw(base)
    draw.line((290, 174, 326, 204), fill=rgba("#efe7ff", 170), width=5)
    draw.line((286, 232, 322, 250), fill=rgba("#efe7ff", 150), width=4)
    save_asset(base, path)


def render_demon_core(path: Path) -> None:
    base = make_base("#f29c7f", "#3f1f1a")
    draw_plate(base, "material", "#f0b08e")
    core = ellipse_mask((188, 154, 324, 290))
    add_soft_shadow(base, core, (8, 10), 18, rgba("#000000", 82))
    compose_gradient_shape(base, core, rgba("#ffd1aa"), rgba("#b64d38"))
    add_outline(base, core, rgba("#311d1b", 220), 4)
    add_highlight(base, (214, 172, 264, 218), rgba("#fff5d6", 60), 10)
    save_asset(base, path)


def main() -> None:
    ensure_dirs()

    render_sword(WEAPONS_DIR / "weapon_sword_astral.png", Palette("#7de8ff", "#19465f", "#edf8ff", "#78abd6", "#73e8ff", "#483736"))
    render_sword(WEAPONS_DIR / "weapon_sword_crimson.png", Palette("#ff9f7a", "#481e1b", "#fff0ea", "#c66a57", "#ffd09a", "#54302e"), broken=True)
    render_spear(WEAPONS_DIR / "weapon_spear_storm.png", Palette("#89d0ff", "#17324c", "#e9f6ff", "#6ea9d8", "#63b3ff", "#40312c"))
    render_bow(WEAPONS_DIR / "weapon_bow_windchase.png")
    render_ring_blade(WEAPONS_DIR / "weapon_ringblade_frost.png")
    render_dagger(WEAPONS_DIR / "weapon_dagger_shadowfang.png")
    render_gourd(ARTIFACTS_DIR / "artifact_spirit_gourd.png", Palette("#9d7cff", "#2d1745", "#f5edff", "#6f4fb2", "#d5b06a", "#51352a"))
    render_jade_slip(ARTIFACTS_DIR / "artifact_jade_slip_ancient.png")
    render_mirror(ARTIFACTS_DIR / "artifact_bronze_mirror.png")
    render_tower(ARTIFACTS_DIR / "artifact_seal_tower.png")
    render_sigil(ARTIFACTS_DIR / "artifact_sigil_disk.png")
    render_orb(ARTIFACTS_DIR / "artifact_orb_tideheart.png")
    render_seal(ARTIFACTS_DIR / "artifact_crimson_seal.png")
    render_banner(ARTIFACTS_DIR / "artifact_soul_banner.png")
    render_pill_bottle(CONSUMABLES_DIR / "consumable_pill_bottle_emerald.png")
    render_talisman(CONSUMABLES_DIR / "consumable_talisman_blinkstep.png")
    render_scroll(CONSUMABLES_DIR / "consumable_scroll_flameward.png")
    render_ling_stone(MATERIALS_DIR / "material_ling_stone.png")
    render_herb(MATERIALS_DIR / "material_moon_grass.png")
    render_ore(MATERIALS_DIR / "material_blackiron_ore.png")
    render_demon_core(MATERIALS_DIR / "material_demon_core.png")
    build_preview_sheet()

    items = [
        {"id": "weapon_sword_astral", "name": "星辉飞剑", "type": "weapon", "category": "weapons", "tier": "灵阶", "element": "water", "asset": "items/weapons/weapon_sword_astral.png", "preview": "previews/item_atlas_v4.png", "use": "偏向身法与御剑流的中期武器。", "lore": "据说取自坠入北冥的星铁残片，夜深时剑脊会浮出细微星纹。", "tags": ["灵阶", "water", "weapon"]},
        {"id": "weapon_sword_crimson", "name": "赤魄灵剑", "type": "weapon", "category": "weapons", "tier": "地阶", "element": "fire", "asset": "items/weapons/weapon_sword_crimson.png", "preview": "previews/item_atlas_v4.png", "use": "高爆发近战武器，适合因果偏激与杀伐路线。", "lore": "曾在宗门大战中折断半寸，后由炼器师以妖火重铸，故剑锋常带余温。", "tags": ["地阶", "fire", "weapon"]},
        {"id": "weapon_spear_storm", "name": "惊霆长枪", "type": "weapon", "category": "weapons", "tier": "灵阶", "element": "metal", "asset": "items/weapons/weapon_spear_storm.png", "preview": "previews/item_atlas_v4.png", "use": "适合正面对决与破阵事件。", "lore": "枪缨不是布，而是雷蚕丝炼成的导灵束，暴雨天尤为凶厉。", "tags": ["灵阶", "metal", "weapon"]},
        {"id": "weapon_bow_windchase", "name": "逐风弓", "type": "weapon", "category": "weapons", "tier": "灵阶", "element": "wood", "asset": "items/weapons/weapon_bow_windchase.png", "preview": "previews/item_atlas_v4.png", "use": "适合远程袭杀、猎妖与侦察类剧情。", "lore": "弓臂取自百年风雷木，拉满时会发出如雁鸣般的轻响。", "tags": ["灵阶", "wood", "weapon"]},
        {"id": "weapon_ringblade_frost", "name": "寒魄环刃", "type": "weapon", "category": "weapons", "tier": "地阶", "element": "water", "asset": "items/weapons/weapon_ringblade_frost.png", "preview": "previews/item_atlas_v4.png", "use": "适合刺杀、伏击、断敌退路类战斗。", "lore": "刃环内圈常结一层薄霜，出手无声，最适合近身夺命。", "tags": ["地阶", "water", "weapon"]},
        {"id": "weapon_dagger_shadowfang", "name": "影牙短匕", "type": "weapon", "category": "weapons", "tier": "灵阶", "element": "dark", "asset": "items/weapons/weapon_dagger_shadowfang.png", "preview": "previews/item_atlas_v4.png", "use": "适合偷袭、潜行、暗杀类剧情。", "lore": "匕刃极短，却能在夜色里吃尽灵光，最适合一击定生死。", "tags": ["灵阶", "dark", "weapon"]},
        {"id": "artifact_spirit_gourd", "name": "养灵葫芦", "type": "artifact", "category": "artifacts", "tier": "地阶", "element": "wood", "asset": "items/artifacts/artifact_spirit_gourd.png", "preview": "previews/item_atlas_v4.png", "use": "可用于传承、收纳灵气、强化轮回记忆类事件。", "lore": "可温养剑意与残魂，一些散修会把它当作最后的归宿。", "tags": ["地阶", "wood", "artifact"]},
        {"id": "artifact_jade_slip_ancient", "name": "古修玉简", "type": "artifact", "category": "artifacts", "tier": "灵阶", "element": "earth", "asset": "items/artifacts/artifact_jade_slip_ancient.png", "preview": "previews/item_atlas_v4.png", "use": "可解锁功法、秘闻、身世线索。", "lore": "玉简内封有残篇，不同灵根之人听见的第一句箴言各不相同。", "tags": ["灵阶", "earth", "artifact"]},
        {"id": "artifact_bronze_mirror", "name": "镇魂铜镜", "type": "artifact", "category": "artifacts", "tier": "地阶", "element": "water", "asset": "items/artifacts/artifact_bronze_mirror.png", "preview": "previews/item_atlas_v4.png", "use": "适合幻境、轮回、心魔相关剧情。", "lore": "镜面不照今生容貌，只映出最重的一段旧因果。", "tags": ["地阶", "water", "artifact"]},
        {"id": "artifact_seal_tower", "name": "镇狱小塔", "type": "artifact", "category": "artifacts", "tier": "天阶", "element": "earth", "asset": "items/artifacts/artifact_seal_tower.png", "preview": "previews/item_atlas_v4.png", "use": "适合高危封印事件、护道与宗门剧情。", "lore": "塔身每一层都刻着古篆封印，传闻可镇妖、镇魂、镇运。", "tags": ["天阶", "earth", "artifact"]},
        {"id": "artifact_sigil_disk", "name": "青冥阵盘", "type": "artifact", "category": "artifacts", "tier": "地阶", "element": "metal", "asset": "items/artifacts/artifact_sigil_disk.png", "preview": "previews/item_atlas_v4.png", "use": "适合布阵、破阵、镇守洞府类剧情。", "lore": "阵盘一旦展开，周边灵气会沿刻痕流转，显出肉眼可见的星线。", "tags": ["地阶", "metal", "artifact"]},
        {"id": "artifact_orb_tideheart", "name": "潮心灵珠", "type": "artifact", "category": "artifacts", "tier": "地阶", "element": "water", "asset": "items/artifacts/artifact_orb_tideheart.png", "preview": "previews/item_atlas_v4.png", "use": "适合治愈、护体、灵海感应类剧情。", "lore": "珠中似封着一缕潮汐，静置时也会缓缓映出水纹。", "tags": ["地阶", "water", "artifact"]},
        {"id": "artifact_crimson_seal", "name": "赤霄印", "type": "artifact", "category": "artifacts", "tier": "地阶", "element": "fire", "asset": "items/artifacts/artifact_crimson_seal.png", "preview": "previews/item_atlas_v4.png", "use": "适合镇压、破邪、宗门执法类剧情。", "lore": "印底刻有灼痕古篆，祭出时常伴随炽热气浪，专克阴邪。", "tags": ["地阶", "fire", "artifact"]},
        {"id": "artifact_soul_banner", "name": "摄魂幡", "type": "artifact", "category": "artifacts", "tier": "地阶", "element": "dark", "asset": "items/artifacts/artifact_soul_banner.png", "preview": "previews/item_atlas_v4.png", "use": "适合邪修、拘魂、死斗或禁术相关剧情。", "lore": "幡面轻动时会传出极细的哭鸣，寻常修士不敢久视。", "tags": ["地阶", "dark", "artifact"]},
        {"id": "consumable_pill_bottle_emerald", "name": "翠灵丹瓶", "type": "consumable", "category": "consumables", "tier": "凡阶", "element": "wood", "asset": "items/consumables/consumable_pill_bottle_emerald.png", "preview": "previews/item_atlas_v4.png", "use": "基础恢复型消耗品。", "lore": "瓶中丹药多为回气与疗伤用途，是坊市中最常见也最容易被掺假的货物。", "tags": ["凡阶", "wood", "consumable"]},
        {"id": "consumable_talisman_blinkstep", "name": "瞬影符", "type": "consumable", "category": "consumables", "tier": "灵阶", "element": "wind", "asset": "items/consumables/consumable_talisman_blinkstep.png", "preview": "previews/item_atlas_v4.png", "use": "逃遁、追击、秘境位移类消耗品。", "lore": "点燃后可借一缕遁风脱离险地，但若心神不稳，也可能一步踏进更深的局。", "tags": ["灵阶", "wind", "consumable"]},
        {"id": "consumable_scroll_flameward", "name": "炎障卷轴", "type": "consumable", "category": "consumables", "tier": "灵阶", "element": "fire", "asset": "items/consumables/consumable_scroll_flameward.png", "preview": "previews/item_atlas_v4.png", "use": "防御、护体、抵御火煞或守关类剧情。", "lore": "撕开卷轴后可在身前结成一道赤焰壁障，但灵力不足时也可能反噬自身。", "tags": ["灵阶", "fire", "consumable"]},
        {"id": "material_ling_stone", "name": "灵石", "type": "material", "category": "materials", "tier": "凡阶", "element": "neutral", "asset": "items/materials/material_ling_stone.png", "preview": "previews/item_atlas_v4.png", "use": "交易、闭关、阵法与炼器通用材料。", "lore": "最基础的修真硬通货，灵气越纯，切面越清透。", "tags": ["凡阶", "neutral", "material"]},
        {"id": "material_moon_grass", "name": "月华草", "type": "material", "category": "materials", "tier": "灵阶", "element": "wood", "asset": "items/materials/material_moon_grass.png", "preview": "previews/item_atlas_v4.png", "use": "炼丹材料，亦可用于安神与心魔线。", "lore": "只在月明而风止之夜舒展叶片，药性温和，最适合调和躁烈丹方。", "tags": ["灵阶", "wood", "material"]},
        {"id": "material_blackiron_ore", "name": "玄铁矿", "type": "material", "category": "materials", "tier": "灵阶", "element": "metal", "asset": "items/materials/material_blackiron_ore.png", "preview": "previews/item_atlas_v4.png", "use": "炼器、修补兵刃、打造护具。", "lore": "矿脉往往埋在灵气枯竭之地深处，外黑内青，是重器最常见的胚料。", "tags": ["灵阶", "metal", "material"]},
        {"id": "material_demon_core", "name": "妖丹", "type": "material", "category": "materials", "tier": "灵阶", "element": "fire", "asset": "items/materials/material_demon_core.png", "preview": "previews/item_atlas_v4.png", "use": "炼丹、炼器、献祭或危险机缘类剧情。", "lore": "多数出自高阶妖兽体内，色泽越艳，蕴藏的狂暴妖气越重。", "tags": ["灵阶", "fire", "material"]},
    ]
    write_item_data(items)


if __name__ == "__main__":
    main()
