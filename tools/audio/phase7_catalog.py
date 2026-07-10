from __future__ import annotations

import json
from pathlib import Path
from typing import Any

TRACK_KEYS = [
    "stage1_mid", "stage1_boss",
    "stage2_mid", "stage2_boss",
    "stage3_mid", "stage3_boss",
    "stage4_mid", "stage4_boss",
    "stage5_mid", "stage5_boss",
    "stage6_mid", "stage6_boss",
]
VOICE_POLICIES = {"instrumental_only", "restrained_wordless_only"}


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def validate_catalog(data: dict[str, Any]) -> None:
    _require(data.get("schema_version") == 1, "schema_version must be 1")
    defaults = data.get("defaults")
    _require(isinstance(defaults, dict), "defaults must be an object")
    _require(defaults.get("seconds") == 30.0, "defaults.seconds must be 30.0")
    _require(defaults.get("steps") == 8, "defaults.steps must be 8")
    _require(defaults.get("cfg") == 2.0, "defaults.cfg must be 2.0")
    _require(defaults.get("dit") == "medium", "defaults.dit must be medium")
    _require(defaults.get("decoder") == "same-l", "defaults.decoder must be same-l")
    _require(
        isinstance(data.get("negative_prompt"), str) and data["negative_prompt"].strip(),
        "negative_prompt must be a non-empty string",
    )

    tracks = data.get("tracks")
    _require(isinstance(tracks, list), "tracks must be an array")
    _require(
        [track.get("key") for track in tracks] == TRACK_KEYS,
        "tracks must contain the twelve approved keys in stage order",
    )

    all_seeds: set[int] = set()
    for track in tracks:
        key = track["key"]
        stage = track.get("stage")
        phase = track.get("phase")
        _require(isinstance(stage, int) and 1 <= stage <= 6, f"{key}.stage must be 1..6")
        _require(phase in {"mid", "boss"}, f"{key}.phase must be mid or boss")
        _require(key == f"stage{stage}_{phase}", f"{key} does not match stage/phase")
        _require(
            isinstance(track.get("title_zh"), str) and track["title_zh"].strip(),
            f"{key}.title_zh must be non-empty",
        )
        _require(
            isinstance(track.get("bpm"), int) and 120 <= track["bpm"] <= 220,
            f"{key}.bpm must be 120..220",
        )
        _require(track.get("voice_policy") in VOICE_POLICIES, f"{key}.voice_policy is invalid")
        expected_voice = "instrumental_only" if stage <= 4 else "restrained_wordless_only"
        _require(track["voice_policy"] == expected_voice, f"{key}.voice_policy must be {expected_voice}")
        _require(
            isinstance(track.get("prompt"), str) and len(track["prompt"]) >= 120,
            f"{key}.prompt is too short",
        )
        candidates = track.get("candidates")
        _require(
            isinstance(candidates, list) and len(candidates) == 2,
            f"{key}.candidates must contain A and B",
        )
        _require(
            [item.get("variant") for item in candidates] == ["A", "B"],
            f"{key}.candidates must be ordered A, B",
        )
        for item in candidates:
            seed = item.get("seed")
            _require(
                isinstance(seed, int) and 0 < seed < 2_147_483_647,
                f"{key}.{item.get('variant')}.seed is invalid",
            )
            _require(seed not in all_seeds, f"duplicate seed {seed}")
            all_seeds.add(seed)


def load_catalog(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    _require(isinstance(data, dict), "catalog root must be an object")
    validate_catalog(data)
    return data
