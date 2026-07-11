from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

from phase7_catalog import TRACK_KEYS, load_catalog as load_phase7a_catalog

ROOT = Path(__file__).resolve().parents[2]
PHASE7A_CATALOG_PATH = ROOT / "audio" / "production" / "phase7_bgm_jobs.json"
CANONICAL_WINDOWS_ROOT = r"Z:\temp\godot_touhou_phase7"
CANONICAL_MACOS_ROOT = "/Volumes/personal_folder/temp/godot_touhou_phase7"

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
APPROVED_SELECTED_SHA256 = {
    "stage1_mid": "24c4f41974ce6a44cabdd5d57706597e81acd6233acc6c88184ebd62e206b616",
    "stage1_boss": "1c8847fb4b58bedc5c0e3811f9de5d1fbf4be1ea0b6adf8d10383b8019260a3c",
    "stage2_mid": "592e2c15630f6672ba5535e8b4c42d8e83187b28253214c0f8410e43a2bb424a",
    "stage2_boss": "bd5583970e437933ad90dd89b8b1c652a5b040ad251552caecad1542e3dab735",
    "stage3_mid": "02aa4ac9710a7ceb6529855c83cd10f32354d1cf59b4888ccbccc53e50ed93ad",
    "stage3_boss": "22386f83c91812a071c29a2b8bae44c05b7d6b562c77deb1ed899276fd5af206",
    "stage4_mid": "de711de96adfcf0708d1f5854b61d0583a10032e629949cc5a9e28f93332ed13",
    "stage4_boss": "db3eca0242c4cd066dbbabe271d0e51a50cc2d80ef9316615db715c4dbe1b117",
    "stage5_mid": "bcd5e02e95c1e75e0d0dd7b20d1883f8943130984b3980b057e2e73ef56791e7",
    "stage5_boss": "1f4ffdbb9c901b3c106023c010c39ade8b9d2c5f5123b746f09646a1bba04e64",
    "stage6_mid": "3b7f671f85ec28a2184cb08376c8932443721a25ac245ae78ea480dc0610444d",
    "stage6_boss": "89d31925101e6ef45a3abadcebfc985361882e7de8303025e3707f7e3e9d17be",
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
SELECTION_ALLOWED_KEYS = {
    "schema_version",
    "selection_source",
    "user_decision",
    "recorded_at_utc",
    "selection_complete",
    "tracks",
}
SELECTION_TRACK_ALLOWED_KEYS = {
    "track_key",
    "title_zh",
    "variant",
    "seed",
    "candidate_path_windows",
    "candidate_path_macos",
    "sha256",
    "qa_status",
    "status",
}


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def _require_nonempty_string(value: Any, message: str) -> str:
    _require(type(value) is str and bool(value.strip()), message)
    return value


def _require_exact_string(value: Any, expected: str, type_message: str, value_message: str) -> str:
    actual = _require_nonempty_string(value, type_message)
    _require(actual == expected, value_message)
    return actual


def _require_exact_int(value: Any, expected: int, type_message: str, value_message: str | None = None) -> int:
    _require(type(value) is int, type_message)
    if value_message is None:
        value_message = type_message
    _require(value == expected, value_message)
    return value


def _require_positive_int(value: Any, message: str) -> int:
    _require(type(value) is int and value > 0, message)
    return value


def _require_exact_float(value: Any, expected: float, type_message: str, value_message: str | None = None) -> float:
    _require(type(value) is float, type_message)
    if value_message is None:
        value_message = type_message
    _require(value == expected, value_message)
    return value


def _require_exact_bool(value: Any, expected: bool, type_message: str, value_message: str | None = None) -> bool:
    _require(type(value) is bool, type_message)
    if value_message is None:
        value_message = type_message
    _require(value is expected, value_message)
    return value


def _is_lower_hex_sha256(value: Any) -> bool:
    return isinstance(value, str) and len(value) == 64 and all(ch in "0123456789abcdef" for ch in value)


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def serialized_candidate_paths(track_key: str, seed: int) -> tuple[str, str]:
    filename = f"bgm_{track_key}_B_seed-{seed}.wav"
    windows_path = rf"{CANONICAL_WINDOWS_ROOT}\bgm_candidates\{track_key}\{filename}"
    macos_path = f"{CANONICAL_MACOS_ROOT}/bgm_candidates/{track_key}/{filename}"
    return windows_path, macos_path


def local_candidate_path(staging_root: Path, track_key: str, seed: int) -> Path:
    return staging_root / "bgm_candidates" / track_key / f"bgm_{track_key}_B_seed-{seed}.wav"


def phase7a_catalog_path_for_longform_catalog(longform_catalog_path: Path) -> Path:
    return Path(longform_catalog_path).with_name("phase7_bgm_jobs.json")


def _require_exact_keys(obj: dict[str, Any], allowed_keys: set[str], subject: str) -> None:
    unknown_keys = sorted(set(obj.keys()) - allowed_keys)
    _require(not unknown_keys, f"{subject} contains unknown keys: {', '.join(unknown_keys)}")
    missing_keys = sorted(allowed_keys - set(obj.keys()))
    _require(not missing_keys, f"{subject} is missing keys: {', '.join(missing_keys)}")


def validate_longform_catalog(data: dict[str, Any], phase7a_catalog_path: Path = PHASE7A_CATALOG_PATH) -> None:
    _require(isinstance(data, dict), "catalog root must be an object")
    _require_exact_keys(data, CATALOG_ALLOWED_KEYS, "catalog")
    _require_exact_int(data.get("schema_version"), 1, "schema_version must be integer 1")

    defaults = data.get("defaults")
    _require(isinstance(defaults, dict), "defaults must be an object")
    _require_exact_keys(defaults, DEFAULT_ALLOWED_KEYS, "defaults")
    _require_exact_float(defaults.get("source_seconds"), 188.0, "defaults.source_seconds must be float 188.0", "defaults.source_seconds must be 188.0")
    _require_exact_float(defaults.get("master_seconds"), 180.0, "defaults.master_seconds must be float 180.0", "defaults.master_seconds must be 180.0")
    _require_exact_float(defaults.get("crossfade_seconds"), 8.0, "defaults.crossfade_seconds must be float 8.0", "defaults.crossfade_seconds must be 8.0")
    _require_exact_float(defaults.get("guide_crossfade_seconds"), 1.0, "defaults.guide_crossfade_seconds must be float 1.0", "defaults.guide_crossfade_seconds must be 1.0")
    _require_exact_int(defaults.get("steps"), 8, "defaults.steps must be integer 8", "defaults.steps must be 8")
    _require_exact_float(defaults.get("cfg"), 2.0, "defaults.cfg must be float 2.0", "defaults.cfg must be 2.0")
    _require_exact_float(defaults.get("init_noise_level"), 0.55, "defaults.init_noise_level must be float 0.55", "defaults.init_noise_level must be 0.55")
    _require_exact_string(defaults.get("dit"), "medium", "defaults.dit must be string medium", "defaults.dit must be medium")
    _require_exact_string(defaults.get("decoder"), "same-l", "defaults.decoder must be string same-l", "defaults.decoder must be same-l")
    _require_exact_bool(defaults.get("free_models"), True, "defaults.free_models must be boolean True", "defaults.free_models must be true")
    _require_exact_float(defaults.get("target_lufs"), -16.0, "defaults.target_lufs must be float -16.0", "defaults.target_lufs must be -16.0")
    _require_exact_float(defaults.get("max_true_peak_dbtp"), -1.0, "defaults.max_true_peak_dbtp must be float -1.0", "defaults.max_true_peak_dbtp must be -1.0")

    phase7a_catalog = load_phase7a_catalog(Path(phase7a_catalog_path))

    _require_exact_string(
        data.get("negative_prompt"),
        phase7a_catalog["negative_prompt"],
        "negative_prompt must be a non-empty string",
        "negative_prompt must reuse the Phase 7A negative prompt exactly",
    )

    _require_exact_string(
        data.get("longform_structure_prompt"),
        APPROVED_STRUCTURE_PROMPT,
        "longform_structure_prompt must be a non-empty string",
        "longform_structure_prompt must match the approved six-section wording",
    )

    macro_sections = data.get("macro_sections")
    _require(isinstance(macro_sections, list), "macro_sections must be an array")
    _require(len(macro_sections) == len(APPROVED_MACRO_SECTIONS), "macro_sections must contain six entries")
    for index, section in enumerate(macro_sections):
        _require(isinstance(section, dict), f"macro_sections[{index}] must be an object")
        _require_exact_keys(section, MACRO_SECTION_ALLOWED_KEYS, f"macro_sections[{index}]")
        approved_section = APPROVED_MACRO_SECTIONS[index]
        _require_exact_string(
            section.get("key"),
            approved_section["key"],
            f"macro_sections[{index}].key must be string {approved_section['key']}",
            "macro_sections must match the approved six-section plan",
        )
        _require_exact_string(
            section.get("label"),
            approved_section["label"],
            f"macro_sections[{index}].label must be string {approved_section['label']}",
            "macro_sections must match the approved six-section plan",
        )
        _require_exact_float(
            section.get("effective_seconds"),
            approved_section["effective_seconds"],
            f"macro_sections[{index}].effective_seconds must be float {approved_section['effective_seconds']}",
            "macro_sections must match the approved six-section plan",
        )

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
        _require_exact_string(track.get("key"), key, f"{key}.key must be string {key}", "tracks must contain the twelve approved keys in stage order")
        _require_exact_int(track.get("stage"), phase7a_track["stage"], f"{key}.stage must be integer {phase7a_track['stage']}", f"{key}.stage must match Phase 7A")
        _require_exact_string(track.get("phase"), phase7a_track["phase"], f"{key}.phase must be string {phase7a_track['phase']}", f"{key}.phase must match Phase 7A")
        _require_exact_string(track.get("title_zh"), phase7a_track["title_zh"], f"{key}.title_zh must be string {phase7a_track['title_zh']}", f"{key}.title_zh must match Phase 7A")
        _require_exact_int(track.get("bpm"), phase7a_track["bpm"], f"{key}.bpm must be integer {phase7a_track['bpm']}", f"{key}.bpm must match Phase 7A")
        _require_exact_string(
            track.get("voice_policy"),
            phase7a_track["voice_policy"],
            f"{key}.voice_policy must be string {phase7a_track['voice_policy']}",
            f"{key}.voice_policy must match Phase 7A",
        )
        _require_exact_string(
            track.get("prompt"),
            phase7a_track["prompt"],
            f"{key}.prompt must be string {phase7a_track['prompt']}",
            f"{key}.prompt must reuse the Phase 7A prompt exactly",
        )
        _require_exact_string(
            track.get("longform_development"),
            APPROVED_TRACK_DEVELOPMENT[key],
            f"{key}.longform_development must be string {APPROVED_TRACK_DEVELOPMENT[key]}",
            f"{key}.longform_development must match the approved deterministic wording",
        )
        _require_exact_string(track.get("selected_variant"), "B", f"{key}.selected_variant must be string B", f"{key}.selected_variant must be B")
        seed = _require_positive_int(track.get("selected_seed"), f"tracks[{index}].selected_seed must be a positive integer")
        selected_sha256 = track.get("selected_sha256")
        _require(isinstance(selected_sha256, str), f"{key}.selected_sha256 must be 64 lowercase hex")
        _require(_is_lower_hex_sha256(selected_sha256), f"{key}.selected_sha256 must be 64 lowercase hex")
        _require(selected_sha256 == APPROVED_SELECTED_SHA256[key], f"{key}.selected_sha256 must match the frozen Task 1 selection")
        _require(
            seed == phase7a_track["candidates"][1]["seed"],
            f"{key}.selected_seed must match the approved B seed",
        )


def load_longform_catalog(path: Path) -> dict[str, Any]:
    path = Path(path)
    phase7a_catalog_path = phase7a_catalog_path_for_longform_catalog(path)
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    validate_longform_catalog(data, phase7a_catalog_path)
    return data


def validate_external_selection(catalog: dict[str, Any], selection_path: Path, staging_root: Path, phase7a_catalog_path: Path) -> dict[str, Any]:
    validate_longform_catalog(catalog, phase7a_catalog_path)

    expected_selection_path = staging_root / "reports" / "bgm_candidate_selection.json"
    _require(Path(selection_path) == expected_selection_path, f"selection_path must match {expected_selection_path}")

    with selection_path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)

    _require(isinstance(data, dict), "selection root must be an object")
    _require_exact_keys(data, SELECTION_ALLOWED_KEYS, "selection")
    _require(type(data.get("schema_version")) is int and data["schema_version"] == 1, "selection.schema_version must be integer 1")
    selection_source = data.get("selection_source")
    _require(isinstance(selection_source, str) and selection_source.strip(), "selection.selection_source must be a non-empty string")
    _require(selection_source == "human", "selection.selection_source must be human")
    _require(
        isinstance(data.get("user_decision"), str) and data["user_decision"].strip(),
        "selection.user_decision must be a non-empty string",
    )
    _require(
        isinstance(data.get("recorded_at_utc"), str) and data["recorded_at_utc"].strip(),
        "selection.recorded_at_utc must be a non-empty string",
    )
    _require(type(data.get("selection_complete")) is bool, "selection.selection_complete must be a boolean")
    _require(data.get("selection_complete") is True, "selection.selection_complete must be true")

    tracks = data.get("tracks")
    _require(isinstance(tracks, list), "selection.tracks must be an array")
    _require(len(tracks) == len(catalog["tracks"]), "selection.tracks must contain twelve entries")

    track_keys: list[str] = []
    for index, track in enumerate(tracks):
        _require(isinstance(track, dict), f"selection.tracks[{index}] must be an object")
        track_key = track.get("track_key")
        _require(isinstance(track_key, str) and track_key.strip(), f"selection.tracks[{index}].track_key must be a non-empty string")
        _require_exact_keys(track, SELECTION_TRACK_ALLOWED_KEYS, f"selection.{track_key}")
        track_keys.append(track_key)
    _require(track_keys == [track["key"] for track in catalog["tracks"]], "selection.tracks must follow catalog track order")

    for job, record in zip(catalog["tracks"], tracks):
        key = job["key"]
        _require(
            isinstance(record.get("title_zh"), str) and record["title_zh"].strip(),
            f"selection.{key}.title_zh must be a non-empty string",
        )
        variant = record.get("variant")
        _require(isinstance(variant, str) and variant.strip(), f"selection.{key}.variant must be a non-empty string")
        _require(variant == job["selected_variant"], f"selection.{key}.variant must be {job['selected_variant']}")
        seed = record.get("seed")
        _require(type(seed) is int and seed > 0, f"selection.{key}.seed must be a positive integer")
        _require(seed == job["selected_seed"], f"selection.{key}.seed does not match catalog selected_seed")
        sha256 = record.get("sha256")
        _require(isinstance(sha256, str) and sha256.strip(), f"selection.{key}.sha256 must be a non-empty string")
        _require(_is_lower_hex_sha256(sha256), f"selection.{key}.sha256 must be 64 lowercase hex")
        _require(sha256 == job["selected_sha256"], f"selection.{key}.sha256 does not match catalog selected_sha256")
        qa_status = record.get("qa_status")
        _require(isinstance(qa_status, str) and qa_status.strip(), f"selection.{key}.qa_status must be a non-empty string")
        _require(qa_status == "pass", f"selection.{key}.qa_status must be pass")
        status = record.get("status")
        _require(isinstance(status, str) and status.strip(), f"selection.{key}.status must be a non-empty string")
        _require(status == "selected", f"selection.{key}.status must be selected")
        expected_candidate_path_windows, expected_candidate_path_macos = serialized_candidate_paths(key, seed)
        candidate_local_path = local_candidate_path(staging_root, key, seed)
        candidate_path_macos = record.get("candidate_path_macos")
        _require(
            isinstance(candidate_path_macos, str) and candidate_path_macos.strip(),
            f"selection.{key}.candidate_path_macos must be a non-empty string",
        )
        _require(
            candidate_path_macos == expected_candidate_path_macos,
            f"selection.{key}.candidate_path_macos must be {expected_candidate_path_macos}",
        )

        candidate_path_windows = record.get("candidate_path_windows")
        _require(
            isinstance(candidate_path_windows, str) and candidate_path_windows.strip(),
            f"selection.{key}.candidate_path_windows must be a non-empty string",
        )
        _require(
            candidate_path_windows == expected_candidate_path_windows,
            f"selection.{key}.candidate_path_windows must be {expected_candidate_path_windows}",
        )
        _require(candidate_local_path.is_file(), f"selection.{key}.candidate local file is missing")
        actual_sha256 = _sha256_file(candidate_local_path)
        _require(actual_sha256 == sha256, f"selection.{key}.candidate bytes do not match sha256")

    return data
