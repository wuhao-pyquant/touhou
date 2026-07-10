#!/usr/bin/env python3
"""Build Phase 6 review contact sheets from accepted manifest assets."""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from textwrap import shorten
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "assets" / "manifest" / "phase6_asset_manifest.json"
REVIEW_DIR = ROOT / "docs" / "art" / "review"
SHEET_NAMES = ("style", "protagonists", "bosses", "backgrounds", "gameplay_readability")


def project_path(path: str) -> Path:
    if path.startswith("res://"):
        return ROOT / path.removeprefix("res://")
    return Path(path)


def load_manifest() -> dict[str, Any]:
    with MANIFEST_PATH.open("r", encoding="utf-8") as manifest_file:
        manifest = json.load(manifest_file)
    if not isinstance(manifest, dict) or not isinstance(manifest.get("assets"), list):
        raise ValueError("Manifest must contain an assets array")
    return manifest


def accepted_assets(manifest: dict[str, Any]) -> list[dict[str, Any]]:
    assets: list[dict[str, Any]] = []
    for asset in manifest["assets"]:
        if isinstance(asset, dict) and asset.get("status") == "accepted":
            assets.append(asset)
    return assets


def sheet_filters() -> dict[str, Callable[[dict[str, Any]], bool]]:
    return {
        "style": lambda asset: asset.get("category") == "style",
        "protagonists": lambda asset: asset.get("category") == "protagonist",
        "bosses": lambda asset: asset.get("category") == "boss",
        "backgrounds": lambda asset: asset.get("category") == "background",
        "gameplay_readability": lambda asset: asset.get("category")
        in {"protagonist", "boss", "enemy", "bullet", "item", "bomb", "background", "ui"},
    }


def load_pillow():
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError as exc:
        raise RuntimeError("Pillow is required to build contact sheets") from exc
    return Image, ImageDraw, ImageFont


def fit_size(width: int, height: int, max_width: int, max_height: int) -> tuple[int, int]:
    scale = min(max_width / max(width, 1), max_height / max(height, 1), 1.0)
    return max(1, int(width * scale)), max(1, int(height * scale))


def draw_wrapped(draw: Any, text: str, xy: tuple[int, int], width: int, fill: tuple[int, int, int]) -> None:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = ("%s %s" % (current, word)).strip()
        if len(candidate) > max(12, width // 7) and current:
            lines.append(current)
            current = word
        else:
            current = candidate
    if current:
        lines.append(current)
    x, y = xy
    for line in lines[:3]:
        draw.text((x, y), line, fill=fill)
        y += 14


def placeholder_sheet(sheet_name: str, output_path: Path, reason: str) -> None:
    Image, ImageDraw, _ImageFont = load_pillow()
    image = Image.new("RGB", (960, 320), (246, 242, 232))
    draw = ImageDraw.Draw(image)
    draw.rectangle((24, 24, 936, 296), outline=(70, 74, 82), width=2)
    draw.text((48, 52), "Phase 6 %s contact sheet" % sheet_name.replace("_", " "), fill=(20, 24, 32))
    draw.text((48, 92), reason, fill=(90, 70, 40))
    draw.text((48, 132), "No asset art is embedded in this scaffold.", fill=(90, 70, 40))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(output_path)


def build_sheet(sheet_name: str, assets: list[dict[str, Any]], output_path: Path) -> None:
    Image, ImageDraw, _ImageFont = load_pillow()
    cell_w = 260
    art_h = 190
    label_h = 88
    padding = 18
    columns = min(4, max(1, len(assets)))
    rows = max(1, math.ceil(len(assets) / columns))
    width = columns * cell_w + padding * 2
    height = rows * (art_h + label_h) + padding * 2 + 42
    sheet = Image.new("RGB", (width, height), (245, 244, 238))
    draw = ImageDraw.Draw(sheet)
    draw.text((padding, padding), "Phase 6 %s" % sheet_name.replace("_", " "), fill=(20, 24, 32))

    for index, asset in enumerate(assets):
        row = index // columns
        column = index % columns
        x = padding + column * cell_w
        y = padding + 42 + row * (art_h + label_h)
        draw.rectangle((x, y, x + cell_w - 12, y + art_h + label_h - 10), outline=(162, 160, 150))
        art_box = (x + 10, y + 10, x + cell_w - 22, y + art_h - 6)
        image_path = project_path(str(asset["final_path"]))
        with Image.open(image_path) as source:
            source = source.convert("RGBA")
            fitted = fit_size(source.width, source.height, art_box[2] - art_box[0], art_box[3] - art_box[1])
            source.thumbnail(fitted)
            canvas = Image.new("RGBA", (art_box[2] - art_box[0], art_box[3] - art_box[1]), (255, 255, 255, 0))
            paste_xy = ((canvas.width - source.width) // 2, (canvas.height - source.height) // 2)
            canvas.alpha_composite(source, paste_xy)
            checker = Image.new("RGB", canvas.size, (228, 228, 220))
            sheet.paste(checker, art_box[:2])
            sheet.paste(canvas.convert("RGB"), art_box[:2], canvas)
        label_y = y + art_h + 4
        draw.text((x + 10, label_y), str(asset["id"]), fill=(20, 24, 32))
        draw.text((x + 10, label_y + 16), "%s / %s" % (asset.get("category"), asset.get("role")), fill=(70, 74, 82))
        draw_wrapped(
            draw,
            shorten(str(asset.get("readability_role", "")), width=96, placeholder="..."),
            (x + 10, label_y + 34),
            cell_w - 32,
            (86, 68, 42),
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path)


def write_index(results: list[tuple[str, Path, int, str]]) -> None:
    REVIEW_DIR.mkdir(parents=True, exist_ok=True)
    index_path = REVIEW_DIR / "phase6_contact_sheets.md"
    lines = [
        "# Phase 6 Contact Sheets",
        "",
        "| Sheet | Accepted assets | Output | Notes |",
        "| --- | ---: | --- | --- |",
    ]
    for sheet_name, path, count, note in results:
        relative = path.relative_to(REVIEW_DIR).as_posix()
        lines.append("| %s | %d | `%s` | %s |" % (sheet_name, count, relative, note))
    index_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-partial", action="store_true", help="write placeholder scaffolds for sheets with no accepted assets")
    parser.add_argument("--sheet", choices=SHEET_NAMES, action="append", help="build only the named sheet; may be repeated")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        manifest = load_manifest()
        load_pillow()
    except (OSError, json.JSONDecodeError, ValueError, RuntimeError) as exc:
        print("Phase 6 contact sheet generation failed: %s" % exc, file=sys.stderr)
        return 1

    filters = sheet_filters()
    sheet_names = args.sheet or list(SHEET_NAMES)
    accepted = accepted_assets(manifest)
    results: list[tuple[str, Path, int, str]] = []
    failures: list[str] = []

    for sheet_name in sheet_names:
        sheet_assets = [asset for asset in accepted if filters[sheet_name](asset)]
        output_path = REVIEW_DIR / ("phase6_contact_sheet_%s.png" % sheet_name)
        missing_files = [asset for asset in sheet_assets if not project_path(str(asset["final_path"])).exists()]
        if missing_files:
            failures.append(
                "%s has missing accepted files: %s"
                % (sheet_name, ", ".join(str(asset["id"]) for asset in missing_files))
            )
            continue
        if not sheet_assets:
            if args.allow_partial:
                placeholder_sheet(sheet_name, output_path, "No accepted assets are available for this sheet yet.")
                results.append((sheet_name, output_path, 0, "partial scaffold"))
            else:
                failures.append("%s has no accepted assets" % sheet_name)
            continue
        build_sheet(sheet_name, sheet_assets, output_path)
        results.append((sheet_name, output_path, len(sheet_assets), "ready for review"))

    if results:
        write_index(results)
    for sheet_name, path, count, note in results:
        print("%s: %s (%d accepted assets, %s)" % (sheet_name, path.relative_to(ROOT), count, note))
    for failure in failures:
        print("ERROR: %s" % failure, file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
