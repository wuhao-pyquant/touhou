from __future__ import annotations

import copy
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "audio"))

from phase7_catalog import load_catalog as load_phase7a_catalog

try:
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
    MODULE_IMPORT_ERROR = exc


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
            payload = f"{key}:{seed}".encode("ascii")
            candidate_path.write_bytes(payload)
            sha256 = hashlib.sha256(payload).hexdigest()
            track["selected_sha256"] = sha256
            selection_tracks.append(
                {
                    "track_key": key,
                    "title_zh": track["title_zh"],
                    "variant": "B",
                    "seed": seed,
                    "candidate_path_windows": str(candidate_path),
                    "candidate_path_macos": f"/Volumes/personal_folder/temp/godot_touhou_phase7/bgm_candidates/{key}/bgm_{key}_B_seed-{seed}.wav",
                    "sha256": sha256,
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
        data = self.load_catalog()
        self.assertTrue(self.selection_path.exists(), f"missing external selection record: {self.selection_path}")
        validated = validate_external_selection(data, self.selection_path, self.staging_root)
        self.assertTrue(validated["selection_complete"])
        self.assertEqual(EXPECTED_TRACK_ORDER, [track["track_key"] for track in validated["tracks"]])

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

    def test_validate_external_selection_rejects_wrong_selection_path(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        wrong_path = staging_root / "reports" / "wrong.json"
        wrong_path.write_text(selection_path.read_text(encoding="utf-8"), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection_path must match .*bgm_candidate_selection\.json"):
            validate_external_selection(catalog, wrong_path, staging_root)

    def test_validate_external_selection_rejects_track_order_mismatch(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["tracks"][0], data["tracks"][1] = data["tracks"][1], data["tracks"][0]
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection\.tracks must follow catalog track order"):
            validate_external_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_variant_mismatch(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["tracks"][0]["variant"] = "A"
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection\.stage1_mid\.variant must be B"):
            validate_external_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_seed_mismatch(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["tracks"][0]["seed"] += 1
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection\.stage1_mid\.seed does not match catalog selected_seed"):
            validate_external_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_sha_mismatch(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["tracks"][0]["sha256"] = "0" * 64
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection\.stage1_mid\.sha256 does not match catalog selected_sha256"):
            validate_external_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_candidate_path_mismatch(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["tracks"][0]["candidate_path_windows"] = str(staging_root / "wrong" / "candidate.wav")
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection\.stage1_mid\.candidate_path_windows must be .*bgm_stage1_mid_B_seed-2026071102\.wav"):
            validate_external_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_candidate_path_macos_mismatch(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["tracks"][0]["candidate_path_macos"] = "/Volumes/personal_folder/temp/godot_touhou_phase7/wrong/stage1_mid.wav"
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(
            ValueError,
            r"selection\.stage1_mid\.candidate_path_macos must be /Volumes/personal_folder/temp/godot_touhou_phase7/bgm_candidates/stage1_mid/bgm_stage1_mid_B_seed-2026071102\.wav",
        ):
            validate_external_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_qa_status_mismatch(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["tracks"][0]["qa_status"] = "fail"
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection\.stage1_mid\.qa_status must be pass"):
            validate_external_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_status_mismatch(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["tracks"][0]["status"] = "planned"
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection\.stage1_mid\.status must be selected"):
            validate_external_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_candidate_byte_mismatch(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        candidate_path = staging_root / "bgm_candidates" / "stage1_mid" / "bgm_stage1_mid_B_seed-2026071102.wav"
        candidate_path.write_bytes(b"tampered")
        with self.assertRaisesRegex(ValueError, r"selection\.stage1_mid\.candidate bytes do not match sha256"):
            validate_external_selection(catalog, selection_path, staging_root)

    def test_validate_external_selection_rejects_missing_track_key_field(self) -> None:
        catalog, selection_path, staging_root, temp_dir = self.build_temp_selection_fixture()
        self.addCleanup(temp_dir.cleanup)
        data = json.loads(selection_path.read_text(encoding="utf-8"))
        data["tracks"][0].pop("track_key")
        selection_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, r"selection\.tracks\[0\]\.track_key must be a non-empty string"):
            validate_external_selection(catalog, selection_path, staging_root)


if __name__ == "__main__":
    unittest.main()
