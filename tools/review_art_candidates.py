#!/usr/bin/env python3
"""Build measurable QA reports and contact sheets for product-art candidates."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / ".tmp" / "art-candidate-review"
SUPPORTED_FORMATS = {"PNG", "JPEG", "WEBP"}
SPECS = {
    "environment": {
        "min_width": 1440,
        "min_height": 1080,
        "aspect": 4.0 / 3.0,
        "min_chroma": 0.020,
        "contact_size": (576, 432),
        "previews": (
            ("event_wide", 515, 360, "cover", 0.5),
            ("event_narrow", 800, 360, "cover", 0.5),
        ),
    },
    "portrait": {
        "min_width": 1024,
        "min_height": 1536,
        "aspect": 2.0 / 3.0,
        "min_chroma": 0.035,
        "contact_size": (384, 576),
        # The first preview mirrors the compact identity card. The latter two
        # mirror the actual event stage, including its top-biased portrait crop.
        "previews": (
            ("identity_card", 104, 154, "contain", 0.5),
            ("event_wide", 515, 360, "focus_cover", 0.18),
            ("event_narrow", 680, 360, "focus_cover", 0.18),
        ),
    },
    "storyboard": {
        "min_width": 1536,
        "min_height": 1024,
        "aspect": 3.0 / 2.0,
        "min_chroma": 0.030,
        "contact_size": (576, 384),
        "previews": (
            ("event_wide", 515, 360, "cover", 0.5),
            ("event_narrow", 800, 360, "cover", 0.5),
        ),
    },
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def luminance(rgb: np.ndarray) -> np.ndarray:
    return rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722


def laplacian_variance(gray: np.ndarray) -> float:
    if min(gray.shape) < 3:
        return 0.0
    center = gray[1:-1, 1:-1]
    laplacian = (
        gray[:-2, 1:-1]
        + gray[2:, 1:-1]
        + gray[1:-1, :-2]
        + gray[1:-1, 2:]
        - 4.0 * center
    )
    return float(np.var(laplacian))


def histogram_entropy(gray: np.ndarray) -> float:
    counts, _ = np.histogram(gray, bins=256, range=(0.0, 1.0))
    probabilities = counts.astype(np.float64)
    probabilities /= max(1.0, float(probabilities.sum()))
    probabilities = probabilities[probabilities > 0.0]
    return float(-np.sum(probabilities * np.log2(probabilities)))


def analyze_candidate(path: Path, kind: str) -> dict[str, object]:
    spec = SPECS[kind]
    failures: list[str] = []
    with Image.open(path) as source:
        source.load()
        width, height = source.size
        image_format = source.format or "UNKNOWN"
        rgba = source.convert("RGBA")
    sample = rgba.copy()
    sample.thumbnail((768, 768), Image.Resampling.LANCZOS)
    pixels = np.asarray(sample, dtype=np.float32) / 255.0
    rgb = pixels[..., :3]
    alpha = pixels[..., 3]
    gray = luminance(rgb)
    low, median, high = (float(value) for value in np.percentile(gray, (1, 50, 99)))
    dynamic_range = high - low
    clipped_dark = float(np.mean(gray <= 0.01))
    clipped_light = float(np.mean(gray >= 0.99))
    sharpness = laplacian_variance(gray)
    entropy = histogram_entropy(gray)
    chroma = float(np.mean(np.max(rgb, axis=2) - np.min(rgb, axis=2)))
    opaque_fraction = float(np.mean(alpha >= 0.99))
    aspect = width / max(1, height)

    if image_format not in SUPPORTED_FORMATS:
        failures.append(f"unsupported format {image_format}")
    if image_format != "PNG":
        failures.append("final product candidates must be lossless PNG")
    if width < int(spec["min_width"]) or height < int(spec["min_height"]):
        failures.append(
            f"resolution {width}x{height} is below {spec['min_width']}x{spec['min_height']}"
        )
    if abs(aspect - float(spec["aspect"])) > 0.035:
        failures.append(f"aspect ratio {aspect:.3f} does not match {float(spec['aspect']):.3f}")
    if dynamic_range < 0.32:
        failures.append(f"luminance range is too flat ({dynamic_range:.3f})")
    if clipped_dark > 0.28:
        failures.append(f"too much crushed black ({clipped_dark:.1%})")
    if clipped_light > 0.18:
        failures.append(f"too much clipped white ({clipped_light:.1%})")
    if sharpness < 0.00016:
        failures.append(f"edge detail is unusually soft ({sharpness:.6f})")
    if entropy < 5.0:
        failures.append(f"tonal entropy is too low ({entropy:.2f} bits)")
    if chroma < float(spec["min_chroma"]):
        failures.append(
            f"color separation is too weak ({chroma:.3f} < {float(spec['min_chroma']):.3f})"
        )
    if opaque_fraction < 0.98:
        failures.append(f"unexpected transparency coverage ({opaque_fraction:.1%} opaque)")

    return {
        "path": str(path.resolve()),
        "filename": path.name,
        "sha256": sha256(path),
        "bytes": path.stat().st_size,
        "format": image_format,
        "width": width,
        "height": height,
        "aspect_ratio": round(aspect, 5),
        "luminance_p01": round(low, 5),
        "luminance_median": round(median, 5),
        "luminance_p99": round(high, 5),
        "dynamic_range": round(dynamic_range, 5),
        "clipped_dark_fraction": round(clipped_dark, 5),
        "clipped_light_fraction": round(clipped_light, 5),
        "sharpness": round(sharpness, 7),
        "entropy_bits": round(entropy, 4),
        "mean_chroma": round(chroma, 5),
        "opaque_fraction": round(opaque_fraction, 5),
        "automated_pass": not failures,
        "failures": failures,
    }


def framed_preview(
    image: Image.Image,
    size: tuple[int, int],
    mode: str,
    focus_y: float = 0.5,
) -> Image.Image:
    rgb = image.convert("RGB")
    if mode in {"cover", "focus_cover"}:
        return ImageOps.fit(
            rgb,
            size,
            method=Image.Resampling.LANCZOS,
            centering=(0.5, max(0.0, min(1.0, focus_y))),
        )
    contained = ImageOps.contain(rgb, size, method=Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", size, "#080d13")
    position = ((size[0] - contained.width) // 2, (size[1] - contained.height) // 2)
    canvas.paste(contained, position)
    return canvas


def write_runtime_previews(path: Path, kind: str, output_dir: Path) -> list[str]:
    preview_dir = output_dir / "runtime-previews"
    preview_dir.mkdir(parents=True, exist_ok=True)
    written: list[str] = []
    with Image.open(path) as image:
        for preview_id, width, height, mode, focus_y in SPECS[kind]["previews"]:
            preview = framed_preview(image, (width, height), mode, focus_y)
            output = preview_dir / f"{path.stem}__{preview_id}_{width}x{height}.png"
            preview.save(output, optimize=True)
            written.append(str(output.resolve()))
    return written


def contact_tile(path: Path, kind: str, report: dict[str, object], reference: bool) -> Image.Image:
    preview_size = SPECS[kind]["contact_size"]
    label_height = 92
    tile = Image.new("RGB", (preview_size[0], preview_size[1] + label_height), "#101720")
    with Image.open(path) as image:
        tile.paste(framed_preview(image, preview_size, "contain"), (0, 0))
    draw = ImageDraw.Draw(tile)
    font = ImageFont.load_default()
    status = "REFERENCE" if reference else ("AUTO PASS" if report["automated_pass"] else "AUTO FAIL")
    status_color = "#7ecf9b" if reference or report["automated_pass"] else "#ee8c78"
    draw.text((10, preview_size[1] + 8), path.name, fill="#f2eee4", font=font)
    draw.text((10, preview_size[1] + 28), status, fill=status_color, font=font)
    metrics = (
        f"{report['width']}x{report['height']}  range {report['dynamic_range']:.3f}  "
        f"sharp {report['sharpness']:.5f}"
    )
    draw.text((10, preview_size[1] + 48), metrics, fill="#aab6c2", font=font)
    if not reference and report["failures"]:
        summary = "; ".join(str(value) for value in report["failures"])
        draw.text((10, preview_size[1] + 68), summary[: math.floor(preview_size[0] / 6)],
                  fill="#ee8c78", font=font)
    return tile


def _comparison_signature(path: Path) -> tuple[np.ndarray, str]:
    """Return a normalized low-resolution image and a compact dHash."""
    with Image.open(path) as image:
        normalized = ImageOps.fit(
            image.convert("RGB"), (64, 64), method=Image.Resampling.BILINEAR
        )
        grayscale = ImageOps.grayscale(normalized).resize((9, 8), Image.Resampling.BILINEAR)
    pixels = np.asarray(normalized, dtype=np.float32) / 255.0
    gray = np.asarray(grayscale, dtype=np.uint8)
    differences = gray[:, 1:] >= gray[:, :-1]
    hash_bits = "".join("1" if value else "0" for value in differences.flat)
    return pixels, hash_bits


def compare_candidates(first: Path, second: Path) -> dict[str, object]:
    """Measure whether two candidates are materially distinct alternatives."""
    first_pixels, first_hash = _comparison_signature(first)
    second_pixels, second_hash = _comparison_signature(second)
    hamming_distance = sum(left != right for left, right in zip(first_hash, second_hash))
    first_luma = luminance(first_pixels).reshape(-1)
    second_luma = luminance(second_pixels).reshape(-1)
    first_centered = first_luma - float(first_luma.mean())
    second_centered = second_luma - float(second_luma.mean())
    denominator = float(np.linalg.norm(first_centered) * np.linalg.norm(second_centered))
    correlation = (
        float(np.dot(first_centered, second_centered) / denominator)
        if denominator > 1e-9
        else 1.0
    )
    rmse = float(np.sqrt(np.mean((first_pixels - second_pixels) ** 2)))
    duplicate = hamming_distance <= 4 and correlation >= 0.995
    return {
        "first": str(first.resolve()),
        "second": str(second.resolve()),
        "dhash_hamming": hamming_distance,
        "luminance_correlation": round(correlation, 6),
        "rgb_rmse": round(rmse, 6),
        "near_duplicate": duplicate,
    }


def write_contact_sheet(
    candidates: list[Path], references: list[Path], kind: str,
    reports: dict[Path, dict[str, object]], output_dir: Path,
) -> Path:
    tiles = [contact_tile(path, kind, reports[path], True) for path in references]
    tiles.extend(contact_tile(path, kind, reports[path], False) for path in candidates)
    columns = min(3, max(1, len(tiles)))
    rows = math.ceil(len(tiles) / columns)
    gap = 16
    width = columns * tiles[0].width + (columns + 1) * gap
    height = rows * tiles[0].height + (rows + 1) * gap
    sheet = Image.new("RGB", (width, height), "#060a0f")
    for index, tile in enumerate(tiles):
        x = gap + (index % columns) * (tile.width + gap)
        y = gap + (index // columns) * (tile.height + gap)
        sheet.paste(tile, (x, y))
    output = output_dir / f"{kind}-contact-sheet.png"
    sheet.save(output, optimize=True)
    return output


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kind", choices=sorted(SPECS), required=True)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--reference", type=Path, action="append", default=[])
    parser.add_argument("--allow-single", action="store_true")
    parser.add_argument("candidates", type=Path, nargs="+")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    candidates = [path.resolve() for path in args.candidates]
    references = [path.resolve() for path in args.reference]
    if len(candidates) < 2 and not args.allow_single:
        raise SystemExit("product-art selection requires at least two candidate images")
    for path in candidates + references:
        if not path.is_file():
            raise SystemExit(f"candidate image does not exist: {path}")
    output_dir = args.out_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    reports = {path: analyze_candidate(path, args.kind) for path in candidates + references}
    pairwise_comparisons = [
        compare_candidates(candidates[first], candidates[second])
        for first in range(len(candidates))
        for second in range(first + 1, len(candidates))
    ]
    selection_failures = [
        "candidate pair is a near-duplicate: %s vs %s"
        % (comparison["first"], comparison["second"])
        for comparison in pairwise_comparisons
        if comparison["near_duplicate"]
    ]
    preview_paths = {
        str(path): write_runtime_previews(path, args.kind, output_dir) for path in candidates
    }
    contact_sheet = write_contact_sheet(candidates, references, args.kind, reports, output_dir)
    payload = {
        "schema_version": 1,
        "kind": args.kind,
        "candidate_count": len(candidates),
        "reference_count": len(references),
        "automated_pass": (
            all(bool(reports[path]["automated_pass"]) for path in candidates)
            and not selection_failures
        ),
        "visual_review_required": True,
        "contact_sheet": str(contact_sheet.resolve()),
        "runtime_previews": preview_paths,
        "pairwise_comparisons": pairwise_comparisons,
        "selection_failures": selection_failures,
        "candidates": [reports[path] for path in candidates],
        "references": [reports[path] for path in references],
    }
    report_path = output_dir / f"{args.kind}-report.json"
    report_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        f"ART_CANDIDATE_REVIEW: {len(candidates)} {args.kind} candidates, "
        f"automated_pass={payload['automated_pass']}, report={report_path}, sheet={contact_sheet}"
    )
    return 0 if payload["automated_pass"] else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as error:
        print(f"ART_CANDIDATE_REVIEW_FAILED: {error}", file=sys.stderr)
        raise SystemExit(2) from error
