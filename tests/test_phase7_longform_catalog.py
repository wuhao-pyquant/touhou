from __future__ import annotations

import copy
import hashlib
import json
import shutil
import sys
import tempfile
import unittest
import wave
from array import array
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "audio"))

CANONICAL_WINDOWS_ROOT = r"Z:\temp\godot_touhou_phase7"
CANONICAL_MACOS_ROOT = "/Volumes/personal_folder/temp/godot_touhou_phase7"

from phase7_catalog import load_catalog as load_phase7a_catalog

try:
    import phase7_longform_catalog as longform_catalog_module
    from phase7_longform_catalog import (
        load_longform_catalog,
        validate_external_selection,
        validate_longform_catalog,
    )
    MODULE_IMPORT_ERROR = None
except Exception as exc:  # pragma: no cover - exercised during RED before implementation
    load_longform_catalog = None
    validate_external_selection = None
    validate_longform_catalog = None
    longform_catalog_module = None
    MODULE_IMPORT_ERROR = exc


SAMPLE_RATE = 44_100
CANDIDATE_SECONDS = 30.0
CANDIDATE_FRAMES = int(round(SAMPLE_RATE * CANDIDATE_SECONDS))


EXPECTED_TRACK_ORDER = [
    "stage1_mid",
    "stage1_boss",
    "stage2_mid",
    "stage2_boss",
    "stage3_mid",
    "stage3_boss",
    "stage4_mid",
    "stage4_boss",
    "stage5_mid",
    "stage5_boss",
    "stage6_mid",
    "stage6_boss",
]

EXPECTED_SELECTIONS = {
    "stage1_mid": {
        "selected_variant": "B",
        "selected_seed": 2026071102,
        "selected_sha256": "24c4f41974ce6a44cabdd5d57706597e81acd6233acc6c88184ebd62e206b616",
    },
    "stage1_boss": {
        "selected_variant": "B",
        "selected_seed": 2026071112,
        "selected_sha256": "1c8847fb4b58bedc5c0e3811f9de5d1fbf4be1ea0b6adf8d10383b8019260a3c",
    },
    "stage2_mid": {
        "selected_variant": "B",
        "selected_seed": 2026071202,
        "selected_sha256": "592e2c15630f6672ba5535e8b4c42d8e83187b28253214c0f8410e43a2bb424a",
    },
    "stage2_boss": {
        "selected_variant": "B",
        "selected_seed": 2026071212,
        "selected_sha256": "bd5583970e437933ad90dd89b8b1c652a5b040ad251552caecad1542e3dab735",
    },
    "stage3_mid": {
        "selected_variant": "B",
        "selected_seed": 2026071302,
        "selected_sha256": "02aa4ac9710a7ceb6529855c83cd10f32354d1cf59b4888ccbccc53e50ed93ad",
    },
    "stage3_boss": {
        "selected_variant": "B",
        "selected_seed": 2026071312,
        "selected_sha256": "22386f83c91812a071c29a2b8bae44c05b7d6b562c77deb1ed899276fd5af206",
    },
    "stage4_mid": {
        "selected_variant": "B",
        "selected_seed": 2026071402,
        "selected_sha256": "de711de96adfcf0708d1f5854b61d0583a10032e629949cc5a9e28f93332ed13",
    },
    "stage4_boss": {
        "selected_variant": "B",
        "selected_seed": 2026071412,
        "selected_sha256": "db3eca0242c4cd066dbbabe271d0e51a50cc2d80ef9316615db715c4dbe1b117",
    },
    "stage5_mid": {
        "selected_variant": "B",
        "selected_seed": 2026071502,
        "selected_sha256": "bcd5e02e95c1e75e0d0dd7b20d1883f8943130984b3980b057e2e73ef56791e7",
    },
    "stage5_boss": {
        "selected_variant": "B",
        "selected_seed": 2026071512,
        "selected_sha256": "1f4ffdbb9c901b3c106023c010c39ade8b9d2c5f5123b746f09646a1bba04e64",
    },
    "stage6_mid": {
        "selected_variant": "B",
        "selected_seed": 2026071602,
        "selected_sha256": "3b7f671f85ec28a2184cb08376c8932443721a25ac245ae78ea480dc0610444d",
    },
    "stage6_boss": {
        "selected_variant": "B",
        "selected_seed": 2026071612,
        "selected_sha256": "89d31925101e6ef45a3abadcebfc985361882e7de8303025e3707f7e3e9d17be",
    },
}

EXPECTED_DEFAULTS = {
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

EXPECTED_MACRO_SECTIONS = [
    {"key": "theme_establishment", "label": "theme establishment", "effective_seconds": 30.0},
    {"key": "first_variation", "label": "first variation", "effective_seconds": 30.0},
    {"key": "breathing_section", "label": "reduced-intensity breathing section", "effective_seconds": 30.0},
    {"key": "rebuild", "label": "rebuild and instrumentation expansion", "effective_seconds": 30.0},
    {"key": "climax", "label": "stage-appropriate climax", "effective_seconds": 38.0},
    {"key": "return_to_theme", "label": "return to the theme and loop preparation", "effective_seconds": 30.0},
]

EXPECTED_STRUCTURE_PROMPT = (
    "Develop the selected 30-second motif into an exact 188-second evolving arrangement with six contiguous sections: "
    "theme establishment for 30 seconds, first variation for 30 seconds, reduced-intensity breathing section for 30 seconds, "
    "rebuild and instrumentation expansion for 30 seconds, stage-appropriate climax for 38 seconds, and return to the theme "
    "and loop preparation for 30 seconds. Preserve the exact BPM, melodic identity, approved voice policy, Japanese festival "
    "plus electronic rock palette, and gameplay readability of the selected motif. Create real sectional development rather "
    "than a simple six-times 30-second repeat, and do not add a cinematic intro, outro, fade-out, dialogue, or lyrics."
)

EXPECTED_TRACK_DEVELOPMENT = {
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


class Phase7LongformCatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.phase7a_path = ROOT / "audio" / "production" / "phase7_bgm_jobs.json"
        cls.longform_path = ROOT / "audio" / "production" / "phase7_bgm_longform_jobs.json"
        cls.selection_path = Path(r"Z:\temp\godot_touhou_phase7\reports\bgm_candidate_selection.json")
        cls.staging_root = Path(r"Z:\temp\godot_touhou_phase7")
        cls.phase7a = load_phase7a_catalog(cls.phase7a_path)

    def require_longform_api(self) -> None:
        if MODULE_IMPORT_ERROR is not None:
            self.fail(f"phase7_longform_catalog import failed: {MODULE_IMPORT_ERROR}")
        self.assertTrue(callable(load_longform_catalog), "load_longform_catalog must be callable")
        self.assertTrue(callable(validate_longform_catalog), "validate_longform_catalog must be callable")
        self.assertTrue(callable(validate_external_selection), "validate_external_selection must be callable")

    def require_catalog_file(self) -> None:
        self.assertTrue(self.longform_path.exists(), f"missing catalog file: {self.longform_path}")

    def load_catalog(self) -> dict:
        self.require_longform_api()
        self.require_catalog_file()
        return load_longform_catalog(self.longform_path)

    def clone_data(self, data: dict | None = None) -> dict:
        source = self.load_catalog() if data is None else data
        return copy.deepcopy(source)

    def validate_selection(self, catalog: dict, selection_path: Path, staging_root: Path, phase7a_path: Path | None = None) -> dict:
        with mock.patch.dict(
            longform_catalog_module.APPROVED_SELECTED_SHA256,
            {track["key"]: track["selected_sha256"] for track in catalog["tracks"]},
            clear=False,
        ):
            return validate_external_selection(
                catalog,
                selection_path,
                staging_root,
                self.phase7a_path if phase7a_path is None else phase7a_path,
            )

    def write_synthetic_candidate(self, path: Path) -> str:
        path.parent.mkdir(parents=True, exist_ok=True)
        chunk_frames = 16_384
        with wave.open(str(path), "wb") as handle:
            handle.setnchannels(2)
            handle.setsampwidth(2)
            handle.setframerate(SAMPLE_RATE)
            for frame_start in range(0, CANDIDATE_FRAMES, chunk_frames):
                frame_stop = min(CANDIDATE_FRAMES, frame_start + chunk_frames)
                samples = array("h")
                for frame_index in range(frame_start, frame_stop):
                    left = 1024 if frame_index % 2 == 0 else -1024
                    right = 768 if frame_index % 3 == 0 else -768
                    samples.append(left)
                    samples.append(right)
                handle.writeframes(samples.tobytes())
        return hashlib.sha256(path.read_bytes()).hexdigest()

    def build_flat_control_catalog_pair(self) -> tuple[Path, Path, tempfile.TemporaryDirectory]:
        temp_dir = tempfile.TemporaryDirectory()
        control_root = Path(temp_dir.name) / "control"
        control_root.mkdir(parents=True, exist_ok=True)
        longform_path = control_root / "phase7_bgm_longform_jobs.json"
        phase7a_path = control_root / "phase7_bgm_jobs.json"
        longform_data = self.clone_data()
        phase7a_data = load_phase7a_catalog(self.phase7a_path)
        phase7a_data["negative_prompt"] = phase7a_data["negative_prompt"] + " flat-control-only"
        longform_data["negative_prompt"] = phase7a_data["negative_prompt"]
        longform_path.write_text(json.dumps(longform_data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        phase7a_path.write_text(json.dumps(phase7a_data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        return longform_path, phase7a_path, temp_dir

    def build_temp_selection_fixture(self) -> tuple[dict, Path, Path, tempfile.TemporaryDirectory]:
        temp_dir = tempfile.TemporaryDirectory()
        staging_root = Path(temp_dir.name)
        catalog = self.clone_data()
        selection_tracks = []
        for track in catalog["tracks"]:
            key = track["key"]
            seed = track["selected_seed"]
            candidate_dir = staging_root / "bgm_candidates" / key
            candidate_dir.mkdir(parents=True, exist_ok=True)
            candidate_path = candidate_dir / f"bgm_{key}_B_seed-{seed}.wav"
            synthetic_sha256 = self.write_synthetic_candidate(candidate_path)
            track["selected_sha256"] = synthetic_sha256
            selection_tracks.append(
                {
                    "track_key": key,
                    "title_zh": track["title_zh"],
                    "variant": "B",
                    "seed": seed,
                    "candidate_path_windows": rf"{CANONICAL_WINDOWS_ROOT}\bgm_candidates\{key}\bgm_{key}_B_seed-{seed}.wav",
                    "candidate_path_macos": f"{CANONICAL_MACOS_ROOT}/bgm_candidates/{key}/bgm_{key}_B_seed-{seed}.wav",
                    "sha256": synthetic_sha256,
                    "qa_status": "pass",
                    "status": "selected",
                }
            )
        selection_path = staging_root / "reports" / "bgm_candidate_selection.json"
        selection_path.parent.mkdir(parents=True, exist_ok=True)
        selection_path.write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "selection_source": "human",
                    "user_decision": "synthetic-test-selection",
                    "recorded_at_utc": "2026-07-10T12:00:00Z",
                    "selection_complete": True,
                    "tracks": selection_tracks,
                },
                ensure_ascii=False,
                indent=2,
            ),
            encoding="utf-8",
        )
        return catalog, selection_path, staging_root, temp_dir

    def test_api_is_available(self) -> None:
        self.require_longform_api()

    def test_catalog_freezes_exact_b_selection_seed_and_sha_order(self) -> None:
        data = self.load_catalog()
        self.assertEqual(EXPECTED_TRACK_ORDER, [track["key"] for track in data["tracks"]])
        frozen = {
            track["key"]: {
                "selected_variant": track["selected_variant"],
                "selected_seed": track["selected_seed"],
                "selected_sha256": track["selected_sha256"],
            }
            for track in data["tracks"]
        }
        self.assertEqual(EXPECTED_SELECTIONS, frozen)

    def test_defaults_and_macro_sections_match_the_approved_plan(self) -> None:
        data = self.load_catalog()
        self.assertEqual(EXPECTED_DEFAULTS, data["defaults"])
        self.assertEqual(EXPECTED_MACRO_SECTIONS, data["macro_sections"])
        self.assertEqual(EXPECTED_STRUCTURE_PROMPT, data["longform_structure_prompt"])

    def test_catalog_reuses_authoritative_phase7a_prompts_and_voice_policy(self) -> None:
        data = self.load_catalog()
        phase7a_tracks = {track["key"]: track for track in self.phase7a["tracks"]}
        self.assertEqual(self.phase7a["negative_prompt"], data["negative_prompt"])
        for track in data["tracks"]:
            base = phase7a_tracks[track["key"]]
            self.assertEqual(base["prompt"], track["prompt"])
            self.assertEqual(base["voice_policy"], track["voice_policy"])
            self.assertEqual(base["title_zh"], track["title_zh"])
            self.assertEqual(base["bpm"], track["bpm"])
            self.assertEqual(EXPECTED_TRACK_DEVELOPMENT[track["key"]], track["longform_development"])

    def test_validate_external_selection_accepts_real_external_record(self) -> None:
        if not self.selection_path.exists():
            self.skipTest(f"missing external selection record: {self.selection_path}")
        data = self.load_catalog()
        selection_data = json.loads(self.selection_path.read_text(encoding="utf-8"))
        missing_candidates = [
            track["track_key"]
            for track in selection_data["tracks"]
            if not (self.staging_root / "bgm_candidates" / track["track_key"] / f"bgm_{track['track_key']}_B_seed-{track['seed']}.wav").is_file()
        ]
        if missing_candidates:
            self.skipTest(f"missing NAS candidates for: {', '.join(missing_candidates)}")
        validated = self.validate_selection(data, self.selection_path, self.staging_root)
        self.assertTrue(validated["selection_complete"])
        self.assertEqual(EXPECTED_TRACK_ORDER, [track["track_key"] for track in validated["tracks"]])

    def test_validate_longform_catalog_accepts_explicit_phase7a_dependency(self) -> None:
        longform_path, phase7a_path, temp_dir = self.build_flat_control_catalog_pair()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(longform_path.read_text(encoding="utf-8"))
        validate_longform_catalog(data, phase7a_path)

    def test_load_longform_catalog_prefers_sibling_phase7a_catalog_for_flat_control(self) -> None:
        longform_path, _phase7a_path, temp_dir = self.build_flat_control_catalog_pair()
        self.addCleanup(temp_dir.cleanup)
        loaded = load_longform_catalog(longform_path)
        self.assertTrue(loaded["negative_prompt"].endswith("flat-control-only"))

    def test_validate_external_selection_accepts_canonical_serialized_paths_with_temp_local_staging_bytes(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        validated = self.validate_selection(catalog, selection_path, staging_root)
        self.assertEqual(
            rf"{CANONICAL_WINDOWS_ROOT}\bgm_candidates\stage1_mid\bgm_stage1_mid_B_seed-2026071102.wav",
            validated["tracks"][0]["candidate_path_windows"],
        )
        self.assertEqual(
            f"{CANONICAL_MACOS_ROOT}/bgm_candidates/stage1_mid/bgm_stage1_mid_B_seed-2026071102.wav",
            validated["tracks"][0]["candidate_path_macos"],
        )

    def test_synthetic_selection_fixture_does_not_touch_real_selection_path(self) -> None:
        original_read_text = Path.read_text

        def guarded_read_text(path: Path, *args: object, **kwargs: object) -> str:
            if Path(path) == self.selection_path:
                raise AssertionError("synthetic fixture must not read REAL_SELECTION_PATH")
            return original_read_text(path, *args, **kwargs)

        with mock.patch.object(Path, "read_text", autospec=True, side_effect=guarded_read_text):
            catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
            self.addCleanup(temp_dir.cleanup)
            validated = self.validate_selection(catalog, selection_path, staging_root)
        self.assertTrue(validated["selection_complete"])

    def test_validate_longform_catalog_rejects_wrong_selected_variant(self) -> None:
        data = self.clone_data()
        data["tracks"][0]["selected_variant"] = "A"
        with self.assertRaisesRegex(ValueError, r"stage1_mid\.selected_variant must be B"):
            validate_longform_catalog(data)

    def test_validate_longform_catalog_rejects_unexpected_root_key(self) -> None:
        data = self.clone_data()
        data["unexpected_root"] = True
        with self.assertRaisesRegex(ValueError, r"catalog contains unknown keys: unexpected_root"):
            validate_longform_catalog(data)

    def test_validate_longform_catalog_rejects_wrong_source_seconds_default(self) -> None:
        data = self.clone_data()
        data["defaults"]["source_seconds"] = 187.0
        with self.assertRaisesRegex(ValueError, r"defaults\.source_seconds must be 188\.0"):
            validate_longform_catalog(data)

    def test_validate_longform_catalog_rejects_unexpected_defaults_key(self) -> None:
        data = self.clone_data()
        data["defaults"]["unexpected_default"] = "value"
        with self.assertRaisesRegex(ValueError, r"defaults contains unknown keys: unexpected_default"):
            validate_longform_catalog(data)

    def test_validate_longform_catalog_rejects_wrong_macro_section_duration(self) -> None:
        data = self.clone_data()
        data["macro_sections"][4]["effective_seconds"] = 30.0
        with self.assertRaisesRegex(ValueError, r"macro_sections must match the approved six-section plan"):
            validate_longform_catalog(data)

    def test_validate_longform_catalog_rejects_unexpected_macro_section_key(self) -> None:
        data = self.clone_data()
        data["macro_sections"][0]["unexpected_section"] = True
        with self.assertRaisesRegex(ValueError, r"macro_sections\[0\] contains unknown keys: unexpected_section"):
            validate_longform_catalog(data)

    def test_validate_longform_catalog_rejects_prompt_drift_from_phase7a(self) -> None:
        data = self.clone_data()
        data["tracks"][0]["prompt"] = data["tracks"][0]["prompt"] + " extra drift"
        with self.assertRaisesRegex(ValueError, r"stage1_mid\.prompt must reuse the Phase 7A prompt exactly"):
            validate_longform_catalog(data)

    def test_validate_longform_catalog_rejects_unexpected_track_key(self) -> None:
        data = self.clone_data()
        data["tracks"][0]["protected_reference"] = "external"
        with self.assertRaisesRegex(ValueError, r"stage1_mid contains unknown keys: protected_reference"):
            validate_longform_catalog(data)

    def test_validate_longform_catalog_rejects_invalid_selected_sha(self) -> None:
        data = self.clone_data()
        data["tracks"][0]["selected_sha256"] = "xyz"
        with self.assertRaisesRegex(ValueError, r"stage1_mid\.selected_sha256 must be 64 lowercase hex"):
            validate_longform_catalog(data)

    def test_validate_longform_catalog_rejects_wrong_but_well_formed_selected_sha_for_every_track(self) -> None:
        wrong_sha_by_key = {}
        keys = list(EXPECTED_SELECTIONS.keys())
        for index, key in enumerate(keys):
            wrong_sha_by_key[key] = EXPECTED_SELECTIONS[keys[(index + 1) % len(keys)]]["selected_sha256"]

        for index, key in enumerate(keys):
            with self.subTest(track_key=key):
                data = self.clone_data()
                data["tracks"][index]["selected_sha256"] = wrong_sha_by_key[key]
                with self.assertRaisesRegex(ValueError, rf"{key}\.selected_sha256 must match the frozen Task 1 selection"):
                    validate_longform_catalog(data)

    def test_validate_longform_catalog_rejects_scalar_type_coercions(self) -> None:
        cases = [
            ("schema_version bool", lambda data: data.__setitem__("schema_version", True), r"schema_version must be integer 1"),
            ("defaults.source_seconds int", lambda data: data["defaults"].__setitem__("source_seconds", 188), r"defaults\.source_seconds must be float 188\.0"),
            ("defaults.master_seconds bool", lambda data: data["defaults"].__setitem__("master_seconds", True), r"defaults\.master_seconds must be float 180\.0"),
            ("defaults.steps bool", lambda data: data["defaults"].__setitem__("steps", True), r"defaults\.steps must be integer 8"),
            ("defaults.cfg int", lambda data: data["defaults"].__setitem__("cfg", 2), r"defaults\.cfg must be float 2\.0"),
            ("defaults.init_noise_level int", lambda data: data["defaults"].__setitem__("init_noise_level", 0), r"defaults\.init_noise_level must be float 0\.55"),
            ("defaults.dit int", lambda data: data["defaults"].__setitem__("dit", 9), r"defaults\.dit must be string medium"),
            ("defaults.free_models int", lambda data: data["defaults"].__setitem__("free_models", 1), r"defaults\.free_models must be boolean True"),
            ("defaults.target_lufs int", lambda data: data["defaults"].__setitem__("target_lufs", -16), r"defaults\.target_lufs must be float -16\.0"),
            ("macro key int", lambda data: data["macro_sections"][0].__setitem__("key", 7), r"macro_sections\[0\]\.key must be string theme_establishment"),
            ("macro label bool", lambda data: data["macro_sections"][0].__setitem__("label", False), r"macro_sections\[0\]\.label must be string theme establishment"),
            ("macro effective_seconds int", lambda data: data["macro_sections"][0].__setitem__("effective_seconds", 30), r"macro_sections\[0\]\.effective_seconds must be float 30\.0"),
            ("track stage bool", lambda data: data["tracks"][0].__setitem__("stage", False), r"stage1_mid\.stage must be integer 1"),
            ("track phase int", lambda data: data["tracks"][0].__setitem__("phase", 3), r"stage1_mid\.phase must be string mid"),
            ("track title_zh int", lambda data: data["tracks"][0].__setitem__("title_zh", 5), r"stage1_mid\.title_zh must be string .+"),
            ("track bpm bool", lambda data: data["tracks"][0].__setitem__("bpm", True), r"stage1_mid\.bpm must be integer 150"),
            ("track voice_policy bool", lambda data: data["tracks"][0].__setitem__("voice_policy", True), r"stage1_mid\.voice_policy must be string instrumental_only"),
            ("track prompt int", lambda data: data["tracks"][0].__setitem__("prompt", 5), r"stage1_mid\.prompt must be string .+"),
            ("track longform_development bool", lambda data: data["tracks"][0].__setitem__("longform_development", True), r"stage1_mid\.longform_development must be string .+"),
            ("track selected_variant bool", lambda data: data["tracks"][0].__setitem__("selected_variant", False), r"stage1_mid\.selected_variant must be string B"),
            ("track selected_seed bool", lambda data: data["tracks"][0].__setitem__("selected_seed", True), r"tracks\[0\]\.selected_seed must be a positive integer"),
            ("track selected_sha256 int", lambda data: data["tracks"][0].__setitem__("selected_sha256", 9), r"stage1_mid\.selected_sha256 must be 64 lowercase hex"),
        ]

        for label, mutate, pattern in cases:
            with self.subTest(label=label):
                data = self.clone_data()
                mutate(data)
                with self.assertRaisesRegex(ValueError, pattern):
                    validate_longform_catalog(data)

    def test_validate_external_selection_rejects_wrong_selection_path(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        wrong_path = staging_root / "reports" / "wrong.json"
        wrong_path.write_text(selection_path.read_text(encoding="utf-8"), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection_path must match .*bgm_candidate_selection\.json"):
            self.validate_selection(catalog, wrong_path, staging_root)

    def test_validate_external_selection_rejects_unexpected_root_key(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["unexpected_root"] = True
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection contains unknown keys: unexpected_root"):
            self.validate_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_blank_selection_source(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["selection_source"] = ""
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection\.selection_source must be a non-empty string"):
            self.validate_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_blank_user_decision(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["user_decision"] = ""
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection\.user_decision must be a non-empty string"):
            self.validate_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_blank_recorded_at_utc(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["recorded_at_utc"] = ""
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection\.recorded_at_utc must be a non-empty string"):
            self.validate_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_track_order_mismatch(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["tracks"][0], data["tracks"][1] = data["tracks"][1], data["tracks"][0]
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection\.tracks must follow catalog track order"):
            self.validate_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_variant_mismatch(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["tracks"][0]["variant"] = "A"
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection\.stage1_mid\.variant must be B"):
            self.validate_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_unexpected_track_key(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["tracks"][0]["unexpected_track"] = True
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection\.stage1_mid contains unknown keys: unexpected_track"):
            self.validate_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_blank_title_zh(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["tracks"][0]["title_zh"] = ""
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection\.stage1_mid\.title_zh must be a non-empty string"):
            self.validate_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_seed_mismatch(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["tracks"][0]["seed"] += 1
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection\.stage1_mid\.seed does not match catalog selected_seed"):
            self.validate_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_sha_mismatch(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["tracks"][0]["sha256"] = "0" * 64
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection\.stage1_mid\.sha256 does not match catalog selected_sha256"):
            self.validate_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_candidate_path_mismatch(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["tracks"][0]["candidate_path_windows"] = rf"{CANONICAL_WINDOWS_ROOT}\wrong\candidate.wav"
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection\.stage1_mid\.candidate_path_windows must be .*bgm_stage1_mid_B_seed-2026071102\.wav"):
            self.validate_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_forward_slash_windows_path(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["tracks"][0]["candidate_path_windows"] = f"{CANONICAL_WINDOWS_ROOT}/bgm_candidates/stage1_mid/bgm_stage1_mid_B_seed-2026071102.wav"
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection\.stage1_mid\.candidate_path_windows must be .*bgm_stage1_mid_B_seed-2026071102\.wav"):
            self.validate_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_candidate_path_macos_mismatch(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["tracks"][0]["candidate_path_macos"] = f"{CANONICAL_MACOS_ROOT}/wrong/stage1_mid.wav"
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(
            ValueError,
            r"selection\.stage1_mid\.candidate_path_macos must be /Volumes/personal_folder/temp/godot_touhou_phase7/bgm_candidates/stage1_mid/bgm_stage1_mid_B_seed-2026071102\.wav",
        ):
            self.validate_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_qa_status_mismatch(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["tracks"][0]["qa_status"] = "fail"
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection\.stage1_mid\.qa_status must be pass"):
            self.validate_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_status_mismatch(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["tracks"][0]["status"] = "planned"
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection\.stage1_mid\.status must be selected"):
            self.validate_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_candidate_byte_mismatch(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        candidate_path = staging_root / "bgm_candidates" / "stage1_mid" / "bgm_stage1_mid_B_seed-2026071102.wav"
        candidate_path.write_bytes(b"tampered")
        with self.assertRaisesRegex(ValueError, r"selection\.stage1_mid\.candidate bytes do not match sha256"):
            self.validate_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_missing_track_key_field(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["tracks"][0].pop("track_key")
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection\.tracks\[0\]\.track_key must be a non-empty string"):
            self.validate_selection(catalog, selection_path, staging_root)


if __name__ == "__main__":
    unittest.main()
