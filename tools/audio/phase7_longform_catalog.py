from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

from phase7_catalog import TRACK_KEYS, load_catalog as load_phase7a_catalog

ROOT = Path(__file__).resolve().parents[2]
PHASE7A_CATALOG_PATH = ROOT / "audio" / "production" / "phase7_bgm_jobs.json"

APPROVED_DEFAULTS = {
    "source_seconds": 188.0,
    "master_seconds": 180.0,
    "crossfade_seconds": 8.0,
    "guide_crossfade_seconds": 1.0,
    "steps": 8,
    "cfg": 2.0,
    "init_noise_level": 0.55,
    "dit": "medium",
    "decoder": "same-l",
    "free_models": True,
    "target_lufs": -16.0,
    "max_true_peak_dbtp": -1.0,
}

APPROVED_MACRO_SECTIONS = [
    {"key": "theme_establishment", "label": "theme establishment", "effective_seconds": 30.0},
    {"key": "first_variation", "label": "first variation", "effective_seconds": 30.0},
    {"key": "breathing_section", "label": "reduced-intensity breathing section", "effective_seconds": 30.0},
    {"key": "rebuild", "label": "rebuild and instrumentation expansion", "effective_seconds": 30.0},
    {"key": "climax", "label": "stage-appropriate climax", "effective_seconds": 38.0},
    {"key": "return_to_theme", "label": "return to the theme and loop preparation", "effective_seconds": 30.0},
]

APPROVED_STRUCTURE_PROMPT = (
    "Develop the selected 30-second motif into an exact 188-second evolving arrangement with six contiguous sections: "
    "theme establishment for 30 seconds, first variation for 30 seconds, reduced-intensity breathing section for 30 seconds, "
    "rebuild and instrumentation expansion for 30 seconds, stage-appropriate climax for 38 seconds, and return to the theme "
    "and loop preparation for 30 seconds. Preserve the exact BPM, melodic identity, approved voice policy, Japanese festival "
    "plus electronic rock palette, and gameplay readability of the selected motif. Create real sectional development rather "
    "than a simple six-times 30-second repeat, and do not add a cinematic intro, outro, fade-out, dialogue, or lyrics."
)

APPROVED_TRACK_DEVELOPMENT = {
    "stage1_mid": "Keep the shrine-approach warmth and lantern-procession lift, let the middle sections open slightly wider without crowding warning cues, and let the return settle naturally into the loop.",
    "stage1_boss": "Keep the fox-duel agility and shamisen-guitar call-and-response, make the climax sharper rather than louder, and leave clean spell-window breath between attacks.",
    "stage2_mid": "Keep the bustling yokai-market motion, let the variation sections feel more unstable and sly, and make the rebuild section tighten the groove without muddying the percussion.",
    "stage2_boss": "Keep the oni-merchant pressure and metallic abacus attack, make the rebuild and climax feel like escalating bargains, and preserve laser-warning space through the densest hits.",
    "stage3_mid": "Keep the dreamlike mist-corridor drift, make the breathing section feel suspended and hollow, and let the return reconnect the lost-path melody without a hard seam.",
    "stage3_boss": "Keep the moonlit illusionist tension and reversed-feeling phrases, let the breathing section briefly unmoor the harmony, and rebuild into a clean fast climax with readable spell windows.",
    "stage4_mid": "Keep the aerial-pursuit momentum and running flute lines, let the middle sections climb in altitude and propulsion, and return to the loop with forward motion instead of release.",
    "stage4_boss": "Keep the mountain-wind duel intensity, let the rebuild add pressure through rhythm and bass rather than extra clutter, and protect player-hit and laser-warning transients at the peak.",
    "stage5_mid": "Keep the dangerous banquet pulse and restrained low-mixed shouts, let the breathing section feel ominously spacious, and rebuild into a heavier dance groove without pulling the voices forward.",
    "stage5_boss": "Keep the intoxicated oni-princess weight and background festival calls, make the climax feel massive and unstable, and leave explicit cue windows for spell, hit, and laser warnings.",
    "stage6_mid": "Keep the sacred-river sweep and low-mixed choir restraint, let the middle sections widen the lantern procession into awe rather than noise, and prepare the loop as an unbroken final-stage current.",
    "stage6_boss": "Keep the final-divine confrontation breadth, let each section escalate the ritual scale without losing melodic focus, and make the return feel inevitable while preserving deathbomb, spell, and laser-warning clarity.",
}

CATALOG_ALLOWED_KEYS = {
    "schema_version",
    "defaults",
    "negative_prompt",
    "longform_structure_prompt",
    "macro_sections",
    "tracks",
}
DEFAULT_ALLOWED_KEYS = set(APPROVED_DEFAULTS.keys())
MACRO_SECTION_ALLOWED_KEYS = {"key", "label", "effective_seconds"}
TRACK_ALLOWED_KEYS = {
    "key",
    "stage",
    "phase",
    "title_zh",
    "bpm",
    "voice_policy",
    "prompt",
    "longform_development",
    "selected_variant",
    "selected_seed",
    "selected_sha256",
}


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def _is_lower_hex_sha256(value: Any) -> bool:
    return isinstance(value, str) and len(value) == 64 and all(ch in "0123456789abcdef" for ch in value)


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _require_exact_keys(obj: dict[str, Any], allowed_keys: set[str], subject: str) -> None:
    unknown_keys = sorted(set(obj.keys()) - allowed_keys)
    _require(not unknown_keys, f"{subject} contains unknown keys: {', '.join(unknown_keys)}")
    missing_keys = sorted(allowed_keys - set(obj.keys()))
    _require(not missing_keys, f"{subject} is missing keys: {', '.join(missing_keys)}")


def _normalized_path(path: Path) -> Path:
    return Path(path).resolve(strict=False)


def validate_longform_catalog(data: dict[str, Any]) -> None:
    _require(isinstance(data, dict), "catalog root must be an object")
    _require_exact_keys(data, CATALOG_ALLOWED_KEYS, "catalog")
    schema_version = data.get("schema_version")
    _require(type(schema_version) is int and schema_version == 1, "schema_version must be integer 1")

    defaults = data.get("defaults")
    _require(isinstance(defaults, dict), "defaults must be an object")
    _require_exact_keys(defaults, DEFAULT_ALLOWED_KEYS, "defaults")
    for key, expected in APPROVED_DEFAULTS.items():
        _require(defaults.get(key) == expected, f"defaults.{key} must be {expected}")

    phase7a_catalog = load_phase7a_catalog(PHASE7A_CATALOG_PATH)

    negative_prompt = data.get("negative_prompt")
    _require(
        isinstance(negative_prompt, str) and negative_prompt == phase7a_catalog["negative_prompt"],
        "negative_prompt must reuse the Phase 7A negative prompt exactly",
    )

    _require(data.get("longform_structure_prompt") == APPROVED_STRUCTURE_PROMPT, "longform_structure_prompt must match the approved six-section wording")

    macro_sections = data.get("macro_sections")
    _require(isinstance(macro_sections, list), "macro_sections must be an array")
    _require(len(macro_sections) == len(APPROVED_MACRO_SECTIONS), "macro_sections must contain six entries")
    for index, section in enumerate(macro_sections):
        _require(isinstance(section, dict), f"macro_sections[{index}] must be an object")
        _require_exact_keys(section, MACRO_SECTION_ALLOWED_KEYS, f"macro_sections[{index}]")
    _require(macro_sections == APPROVED_MACRO_SECTIONS, "macro_sections must match the approved six-section plan")

    tracks = data.get("tracks")
    _require(isinstance(tracks, list), "tracks must be an array")
    _require(len(tracks) == len(TRACK_KEYS), "tracks must contain twelve entries")
    _require([track.get("key") if isinstance(track, dict) else None for track in tracks] == TRACK_KEYS, "tracks must contain the twelve approved keys in stage order")

    phase7a_tracks = {track["key"]: track for track in phase7a_catalog["tracks"]}
    for index, track in enumerate(tracks):
        _require(isinstance(track, dict), f"tracks[{index}] must be an object")
        key = track["key"]
        _require_exact_keys(track, TRACK_ALLOWED_KEYS, key)
        phase7a_track = phase7a_tracks[key]
        _require(track.get("stage") == phase7a_track["stage"], f"{key}.stage must match Phase 7A")
        _require(track.get("phase") == phase7a_track["phase"], f"{key}.phase must match Phase 7A")
        _require(track.get("title_zh") == phase7a_track["title_zh"], f"{key}.title_zh must match Phase 7A")
        _require(track.get("bpm") == phase7a_track["bpm"], f"{key}.bpm must match Phase 7A")
        _require(track.get("voice_policy") == phase7a_track["voice_policy"], f"{key}.voice_policy must match Phase 7A")
        _require(track.get("prompt") == phase7a_track["prompt"], f"{key}.prompt must reuse the Phase 7A prompt exactly")

        _require(track.get("selected_variant") == "B", f"{key}.selected_variant must be B")
        seed = track.get("selected_seed")
        _require(type(seed) is int and seed > 0, f"tracks[{index}].selected_seed must be a positive integer")
        _require(_is_lower_hex_sha256(track.get("selected_sha256")), f"{key}.selected_sha256 must be 64 lowercase hex")
        _require(
            track.get("longform_development") == APPROVED_TRACK_DEVELOPMENT[key],
            f"{key}.longform_development must match the approved deterministic wording",
        )


def load_longform_catalog(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    validate_longform_catalog(data)
    return data


def validate_external_selection(catalog: dict[str, Any], selection_path: Path, staging_root: Path) -> dict[str, Any]:
    validate_longform_catalog(catalog)

    expected_selection_path = staging_root / "reports" / "bgm_candidate_selection.json"
    _require(Path(selection_path) == expected_selection_path, f"selection_path must match {expected_selection_path}")

    with selection_path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)

    _require(isinstance(data, dict), "selection root must be an object")
    _require(type(data.get("schema_version")) is int and data["schema_version"] == 1, "selection.schema_version must be integer 1")
    _require(data.get("selection_source") == "human", "selection.selection_source must be human")
    _require(data.get("selection_complete") is True, "selection.selection_complete must be true")

    tracks = data.get("tracks")
    _require(isinstance(tracks, list), "selection.tracks must be an array")
    _require(len(tracks) == len(catalog["tracks"]), "selection.tracks must contain twelve entries")

    track_keys: list[str] = []
    for index, track in enumerate(tracks):
        _require(isinstance(track, dict), f"selection.tracks[{index}] must be an object")
        track_key = track.get("track_key")
        _require(isinstance(track_key, str) and track_key.strip(), f"selection.tracks[{index}].track_key must be a non-empty string")
        track_keys.append(track_key)
    _require(track_keys == [track["key"] for track in catalog["tracks"]], "selection.tracks must follow catalog track order")

    for job, record in zip(catalog["tracks"], tracks):
        key = job["key"]
        _require(record.get("variant") == job["selected_variant"], f"selection.{key}.variant must be {job['selected_variant']}")
        seed = record.get("seed")
        _require(type(seed) is int and seed > 0, f"selection.{key}.seed must be a positive integer")
        _require(seed == job["selected_seed"], f"selection.{key}.seed does not match catalog selected_seed")
        sha256 = record.get("sha256")
        _require(_is_lower_hex_sha256(sha256), f"selection.{key}.sha256 must be 64 lowercase hex")
        _require(sha256 == job["selected_sha256"], f"selection.{key}.sha256 does not match catalog selected_sha256")
        _require(record.get("qa_status") == "pass", f"selection.{key}.qa_status must be pass")
        _require(record.get("status") == "selected", f"selection.{key}.status must be selected")
        expected_candidate_filename = f"bgm_{key}_B_seed-{seed}.wav"
        expected_candidate_path = staging_root / "bgm_candidates" / key / expected_candidate_filename
        expected_candidate_path_macos = f"/Volumes/personal_folder/temp/godot_touhou_phase7/bgm_candidates/{key}/{expected_candidate_filename}"
        candidate_path_macos = record.get("candidate_path_macos")
        _require(
            isinstance(candidate_path_macos, str) and candidate_path_macos == expected_candidate_path_macos,
            f"selection.{key}.candidate_path_macos must be {expected_candidate_path_macos}",
        )

        candidate_path_windows = record.get("candidate_path_windows")
        _require(
            isinstance(candidate_path_windows, str) and _normalized_path(Path(candidate_path_windows)) == _normalized_path(expected_candidate_path),
            f"selection.{key}.candidate_path_windows must be {expected_candidate_path}",
        )
        _require(expected_candidate_path.is_file(), f"selection.{key}.candidate_path_windows file is missing")
        actual_sha256 = _sha256_file(expected_candidate_path)
        _require(actual_sha256 == sha256, f"selection.{key}.candidate bytes do not match sha256")

    return data
