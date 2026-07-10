#!/usr/bin/env python3
"""Validate accepted Phase 6 art assets against the manifest."""

from __future__ import annotations

import json
import struct
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "assets" / "manifest" / "phase6_asset_manifest.json"
REQUIRED_FIELDS = {
    "id": str,
    "category": str,
    "role": str,
    "final_path": str,
    "source_path": str,
    "width": int,
    "height": int,
    "transparent": bool,
    "readability_role": str,
    "status": str,
    "prompt_id": str,
}
VALID_STATUSES = {"pending_generation", "generated_needs_review", "accepted", "rejected"}
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def is_integer(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def project_path(path: str) -> Path:
    if path.startswith("res://"):
        return ROOT / path.removeprefix("res://")
    return Path(path)


def load_manifest() -> dict[str, Any]:
    with MANIFEST_PATH.open("r", encoding="utf-8") as manifest_file:
        manifest = json.load(manifest_file)
    if not isinstance(manifest, dict):
        raise ValueError("Manifest root must be an object")
    return manifest


def validate_schema(manifest: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if not is_integer(manifest.get("version")):
        errors.append("version must be an integer")

    assets = manifest.get("assets")
    if not isinstance(assets, list):
        return errors + ["assets must be an array"]

    seen_ids: set[str] = set()
    for index, asset in enumerate(assets):
        if not isinstance(asset, dict):
            errors.append("assets[%d] must be an object" % index)
            continue
        asset_id = str(asset.get("id", "assets[%d]" % index))
        for field, expected_type in REQUIRED_FIELDS.items():
            if field not in asset:
                errors.append("%s missing required field %s" % (asset_id, field))
                continue
            if expected_type is int:
                valid_type = is_integer(asset[field])
            else:
                valid_type = isinstance(asset[field], expected_type)
            if not valid_type:
                errors.append("%s field %s must be %s" % (asset_id, field, expected_type.__name__))
        if isinstance(asset.get("id"), str):
            if asset["id"] in seen_ids:
                errors.append("%s duplicates an earlier asset id" % asset_id)
            seen_ids.add(asset["id"])
        if asset.get("status") not in VALID_STATUSES:
            errors.append("%s has invalid status %r" % (asset_id, asset.get("status")))
        if isinstance(asset.get("final_path"), str) and not asset["final_path"].startswith("res://assets/"):
            errors.append("%s final_path must start with res://assets/" % asset_id)
        if is_integer(asset.get("width")) and asset["width"] <= 0:
            errors.append("%s width must be positive" % asset_id)
        if is_integer(asset.get("height")) and asset["height"] <= 0:
            errors.append("%s height must be positive" % asset_id)
    return errors


def read_png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as png_file:
        header = png_file.read(24)
    if len(header) < 24 or not header.startswith(PNG_SIGNATURE) or header[12:16] != b"IHDR":
        raise ValueError("not a valid PNG")
    return struct.unpack(">II", header[16:24])


def image_has_alpha(path: Path) -> bool | None:
    try:
        from PIL import Image
    except ImportError:
        return None

    with Image.open(path) as image:
        if image.mode in ("RGBA", "LA"):
            return image.getextrema()[-1][0] < 255
        if image.mode == "P":
            return "transparency" in image.info
    return False


def validate_accepted_assets(assets: list[dict[str, Any]]) -> tuple[list[str], dict[str, int]]:
    errors: list[str] = []
    counts = {
        "total": len(assets),
        "accepted": 0,
        "missing": 0,
        "dimension_mismatches": 0,
        "alpha_warnings": 0,
        "alpha_failures": 0,
    }

    for asset in assets:
        if asset.get("status") != "accepted":
            continue
        counts["accepted"] += 1
        asset_id = str(asset["id"])
        image_path = project_path(str(asset["final_path"]))
        if not image_path.exists():
            counts["missing"] += 1
            errors.append("%s missing accepted file: %s" % (asset_id, asset["final_path"]))
            continue
        try:
            width, height = read_png_size(image_path)
        except ValueError as exc:
            counts["dimension_mismatches"] += 1
            errors.append("%s cannot read PNG dimensions: %s" % (asset_id, exc))
            continue
        expected_size = (int(asset["width"]), int(asset["height"]))
        if (width, height) != expected_size:
            counts["dimension_mismatches"] += 1
            errors.append(
                "%s dimension mismatch: expected %dx%d, found %dx%d"
                % (asset_id, expected_size[0], expected_size[1], width, height)
            )
        if bool(asset["transparent"]):
            has_alpha = image_has_alpha(image_path)
            if has_alpha is None:
                counts["alpha_warnings"] += 1
                print("WARNING: Pillow unavailable; alpha check skipped for %s" % asset_id)
            elif not has_alpha:
                counts["alpha_failures"] += 1
                errors.append("%s requires transparency but has no transparent pixels" % asset_id)
    return errors, counts


def main() -> int:
    try:
        manifest = load_manifest()
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print("Phase 6 asset validation failed: %s" % exc, file=sys.stderr)
        return 1

    schema_errors = validate_schema(manifest)
    raw_assets = manifest.get("assets", [])
    assets = [asset for asset in raw_assets if isinstance(asset, dict)]
    asset_errors, counts = validate_accepted_assets(assets)

    print("Phase 6 asset validation summary")
    print("  total assets: %d" % counts["total"])
    print("  accepted assets: %d" % counts["accepted"])
    print("  missing accepted files: %d" % counts["missing"])
    print("  dimension mismatches: %d" % counts["dimension_mismatches"])
    if counts["alpha_warnings"]:
        print("  alpha warnings: %d" % counts["alpha_warnings"])
    if counts["alpha_failures"]:
        print("  alpha failures: %d" % counts["alpha_failures"])

    errors = schema_errors + asset_errors
    for error in errors:
        print("ERROR: %s" % error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
