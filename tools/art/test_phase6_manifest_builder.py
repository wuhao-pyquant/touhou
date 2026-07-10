#!/usr/bin/env python3
"""Regression test for Phase 6 manifest builder status preservation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BUILDER_PATH = ROOT / "tools" / "art" / "phase6_asset_manifest_builder.py"


def load_builder():
    spec = importlib.util.spec_from_file_location("phase6_asset_manifest_builder", BUILDER_PATH)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> None:
    builder = load_builder()
    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_manifest = Path(tmp_dir) / "phase6_asset_manifest.json"
        tmp_manifest.write_text(
            json.dumps(
                {
                    "version": 1,
                    "assets": [
                        {"id": "style_reference_night_festival", "status": "accepted"},
                        {"id": "enemy_bullet_lotus_core", "status": "rejected"},
                    ],
                }
            ),
            encoding="utf-8",
        )
        builder.MANIFEST_PATH = tmp_manifest
        rebuilt = builder.build_manifest()
        statuses = {asset["id"]: asset["status"] for asset in rebuilt["assets"]}
        assert statuses["style_reference_night_festival"] == "accepted"
        assert statuses["enemy_bullet_lotus_core"] == "rejected"
        assert statuses["stage_01_background_far"] == "pending_generation"

        builder.main()
        persisted = json.loads(tmp_manifest.read_text(encoding="utf-8"))
        persisted_statuses = {asset["id"]: asset["status"] for asset in persisted["assets"]}
        assert persisted_statuses["style_reference_night_festival"] == "accepted"
        assert persisted_statuses["enemy_bullet_lotus_core"] == "rejected"


if __name__ == "__main__":
    main()
