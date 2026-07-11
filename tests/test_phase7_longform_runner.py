from __future__ import annotations

import copy
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
import wave
from array import array
from pathlib import Path
from typing import Any
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "audio"))

try:
    import phase7_longform_runner as runner
    from phase7_longform_catalog import load_longform_catalog, validate_external_selection
    from phase7_longform_runner import (
        build_longform_command,
        guide_filename,
        run_longform_catalog,
        source_filename,
    )
    MODULE_IMPORT_ERROR = None
except Exception as exc:  # pragma: no cover - exercised during RED before implementation
    runner = None
    load_longform_catalog = None
    validate_external_selection = None
    build_longform_command = None
    guide_filename = None
    run_longform_catalog = None
    source_filename = None
    MODULE_IMPORT_ERROR = exc


SAMPLE_RATE = 44_100
SOURCE_SECONDS = 188.0
CANDIDATE_SECONDS = 30.0
SOURCE_FRAMES = int(round(SOURCE_SECONDS * SAMPLE_RATE))
CANDIDATE_FRAMES = int(round(CANDIDATE_SECONDS * SAMPLE_RATE))
REAL_STAGING_ROOT = Path(r"Z:\temp\godot_touhou_phase7")
REAL_SELECTION_PATH = REAL_STAGING_ROOT / "reports" / "bgm_candidate_selection.json"
REAL_CATALOG_PATH = ROOT / "audio" / "production" / "phase7_bgm_longform_jobs.json"
CANONICAL_WINDOWS_ROOT = r"Z:\temp\godot_touhou_phase7"
CANONICAL_MACOS_ROOT = "/Volumes/personal_folder/temp/godot_touhou_phase7"


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_pcm16_wave(path: Path, frame_count: int, left: int = 1_024, right: int = -1_024) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    chunk_frames = 16_384
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        for frame_start in range(0, frame_count, chunk_frames):
            frame_stop = min(frame_count, frame_start + chunk_frames)
            samples = array("h")
            for frame_index in range(frame_start, frame_stop):
                left_value = left if frame_index % 2 == 0 else -left
                right_value = right if frame_index % 3 == 0 else -right
                samples.append(left_value)
                samples.append(right_value)
            handle.writeframes(samples.tobytes())


def make_fixture_catalog(candidate_sha256: str) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "defaults": {
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
        },
        "negative_prompt": "lyrics, spoken words, dialogue",
        "longform_structure_prompt": "Develop the selected motif into a six-section 188-second arrangement.",
        "macro_sections": [],
        "tracks": [
            {
                "key": "stage1_mid",
                "stage": 1,
                "phase": "mid",
                "title_zh": "测试曲目",
                "bpm": 150,
                "voice_policy": "instrumental_only",
                "prompt": "Original 30-second motif at 150 BPM.",
                "longform_development": "Expand the theme without turning it into a literal six-times repeat.",
                "selected_variant": "B",
                "selected_seed": 2026071102,
                "selected_sha256": candidate_sha256,
            }
        ],
    }


def make_fixture_selection(candidate_path: Path, candidate_sha256: str) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "selection_source": "human",
        "user_decision": "accepted",
        "recorded_at_utc": "2026-07-10T12:00:00Z",
        "selection_complete": True,
        "tracks": [
            {
                "track_key": "stage1_mid",
                "title_zh": "测试曲目",
                "variant": "B",
                "seed": 2026071102,
                "candidate_path_windows": rf"{CANONICAL_WINDOWS_ROOT}\bgm_candidates\stage1_mid\bgm_stage1_mid_B_seed-2026071102.wav",
                "candidate_path_macos": f"{CANONICAL_MACOS_ROOT}/bgm_candidates/stage1_mid/bgm_stage1_mid_B_seed-2026071102.wav",
                "sha256": candidate_sha256,
                "qa_status": "pass",
                "status": "selected",
            }
        ],
    }


class Phase7LongformRunnerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.fixture_dir = tempfile.TemporaryDirectory()
        cls.fixture_root = Path(cls.fixture_dir.name)
        cls.candidate_fixture = cls.fixture_root / "candidate30.wav"
        cls.source_fixture = cls.fixture_root / "source188.wav"
        cls.guide_fixture = cls.fixture_root / "guide188.wav"
        write_pcm16_wave(cls.candidate_fixture, CANDIDATE_FRAMES, left=640, right=-960)
        write_pcm16_wave(cls.source_fixture, SOURCE_FRAMES, left=384, right=-512)
        write_pcm16_wave(cls.guide_fixture, SOURCE_FRAMES, left=256, right=-384)
        cls.candidate_sha256 = sha256_file(cls.candidate_fixture)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.fixture_dir.cleanup()

    def require_runner_api(self) -> None:
        if MODULE_IMPORT_ERROR is not None:
            self.fail(f"phase7_longform_runner import failed: {MODULE_IMPORT_ERROR}")
        self.assertTrue(callable(guide_filename), "guide_filename must be callable")
        self.assertTrue(callable(source_filename), "source_filename must be callable")
        self.assertTrue(callable(build_longform_command), "build_longform_command must be callable")
        self.assertTrue(callable(run_longform_catalog), "run_longform_catalog must be callable")

    def write_fake_generator(self, path: Path, body: str) -> Path:
        path.write_text(body, encoding="utf-8")
        return path

    def fake_build_macro_guide(self, candidate_path: Path, output_path: Path, source_seconds: float, guide_crossfade_seconds: float) -> dict[str, Any]:
        self.assertTrue(candidate_path.is_file(), f"candidate fixture missing: {candidate_path}")
        self.assertEqual(self.candidate_sha256, sha256_file(candidate_path))
        self.assertEqual(188.0, source_seconds)
        self.assertEqual(1.0, guide_crossfade_seconds)
        shutil.copyfile(self.guide_fixture, output_path)
        return {
            "path": str(output_path),
            "frame_count": SOURCE_FRAMES,
            "sample_rate": SAMPLE_RATE,
            "channels": 2,
            "bits_per_sample": 16,
            "sha256": sha256_file(output_path),
        }

    def make_patched_inputs(self, staging_root: Path) -> tuple[dict[str, Any], dict[str, Any]]:
        candidate_path = staging_root / "bgm_candidates" / "stage1_mid" / "bgm_stage1_mid_B_seed-2026071102.wav"
        candidate_path.parent.mkdir(parents=True, exist_ok=True)
        write_pcm16_wave(candidate_path, CANDIDATE_FRAMES, left=640, right=-960)
        catalog = make_fixture_catalog(self.candidate_sha256)
        selection = make_fixture_selection(candidate_path, self.candidate_sha256)
        return catalog, selection

    def make_two_track_fixture(self, staging_root: Path) -> tuple[dict[str, Any], dict[str, Any]]:
        catalog, selection = self.make_patched_inputs(staging_root)
        second_key = "stage1_boss"
        second_seed = 2026071112
        second_candidate_dir = staging_root / "bgm_candidates" / second_key
        second_candidate_dir.mkdir(parents=True, exist_ok=True)
        second_candidate_path = second_candidate_dir / f"bgm_{second_key}_B_seed-{second_seed}.wav"
        write_pcm16_wave(second_candidate_path, CANDIDATE_FRAMES, left=640, right=-960)
        catalog["tracks"].append({
            "key": second_key,
            "stage": 1,
            "phase": "boss",
            "title_zh": "测试二号",
            "bpm": 172,
            "voice_policy": "instrumental_only",
            "prompt": "Original 30-second boss motif at 172 BPM.",
            "longform_development": "Develop the boss motif across six sections.",
            "selected_variant": "B",
            "selected_seed": second_seed,
            "selected_sha256": self.candidate_sha256,
        })
        selection["tracks"].append({
            "track_key": second_key,
            "title_zh": "测试二号",
            "variant": "B",
            "seed": second_seed,
            "candidate_path_windows": rf"{CANONICAL_WINDOWS_ROOT}\bgm_candidates\{second_key}\bgm_{second_key}_B_seed-{second_seed}.wav",
            "candidate_path_macos": f"{CANONICAL_MACOS_ROOT}/bgm_candidates/{second_key}/bgm_{second_key}_B_seed-{second_seed}.wav",
            "sha256": self.candidate_sha256,
            "qa_status": "pass",
            "status": "selected",
        })
        return catalog, selection

    def make_full_catalog_fixture(self, staging_root: Path) -> tuple[dict[str, Any], dict[str, Any]]:
        del staging_root
        catalog = json.loads(REAL_CATALOG_PATH.read_text(encoding="utf-8"))
        selection_tracks = []
        for track in catalog["tracks"]:
            key = track["key"]
            seed = track["selected_seed"]
            selection_tracks.append({
                "track_key": key,
                "title_zh": track["title_zh"],
                "variant": "B",
                "seed": seed,
                "candidate_path_windows": rf"{CANONICAL_WINDOWS_ROOT}\bgm_candidates\{key}\bgm_{key}_B_seed-{seed}.wav",
                "candidate_path_macos": f"{CANONICAL_MACOS_ROOT}/bgm_candidates/{key}/bgm_{key}_B_seed-{seed}.wav",
                "sha256": track["selected_sha256"],
                "qa_status": "pass",
                "status": "selected",
            })
        selection = {
            "schema_version": 1,
            "selection_source": "synthetic",
            "user_decision": "approved",
            "recorded_at_utc": "2026-07-11T00:00:00Z",
            "selection_complete": True,
            "tracks": selection_tracks,
        }
        return catalog, selection

    def optional_integration_candidate_path(self, staging_root: Path, track_key: str, seed: int) -> Path:
        return staging_root / "bgm_candidates" / track_key / f"bgm_{track_key}_B_seed-{seed}.wav"

    def preflight_optional_external_selection(
        self,
        catalog: dict[str, Any],
        selection_path: Path,
        staging_root: Path,
    ) -> tuple[dict[str, Any], bytes]:
        if not selection_path.exists():
            self.skipTest(f"missing selection: {selection_path}")
        try:
            before_bytes = selection_path.read_bytes()
        except OSError as exc:
            self.skipTest(f"selection unavailable for read-only preflight: {selection_path} ({exc})")
        try:
            selection_data = json.loads(before_bytes.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            self.skipTest(f"selection malformed for integration preflight: {selection_path} ({exc})")

        tracks = selection_data.get("tracks")
        if not isinstance(tracks, list):
            self.skipTest(f"selection malformed for integration preflight: {selection_path} (tracks missing)")
        expected_count = len(catalog["tracks"])
        if len(tracks) != expected_count:
            self.skipTest(
                f"selection malformed for integration preflight: expected {expected_count} tracks, found {len(tracks)}"
            )

        missing_candidates: list[str] = []
        for index, track in enumerate(tracks):
            if not isinstance(track, dict):
                self.skipTest(f"selection malformed for integration preflight: tracks[{index}] is not an object")
            track_key = track.get("track_key")
            seed = track.get("seed")
            if not isinstance(track_key, str) or not track_key:
                self.skipTest(f"selection malformed for integration preflight: tracks[{index}].track_key missing")
            if not isinstance(seed, int):
                self.skipTest(f"selection malformed for integration preflight: tracks[{index}].seed missing")
            candidate_path = self.optional_integration_candidate_path(staging_root, track_key, seed)
            if not candidate_path.is_file():
                missing_candidates.append(str(candidate_path))

        if missing_candidates:
            self.skipTest("missing NAS candidates for: " + ", ".join(missing_candidates))
        return selection_data, before_bytes

    def load_optional_integration_selection(
        self,
        catalog_path: Path,
        selection_path: Path,
        staging_root: Path,
    ) -> tuple[dict[str, Any], dict[str, Any], bytes]:
        if not catalog_path.exists():
            self.skipTest(f"missing catalog: {catalog_path}")
        catalog = load_longform_catalog(catalog_path)
        _selection_data, before_bytes = self.preflight_optional_external_selection(catalog, selection_path, staging_root)
        selection = validate_external_selection(
            catalog,
            selection_path,
            staging_root,
            catalog_path.with_name("phase7_bgm_jobs.json"),
        )
        return catalog, selection, before_bytes

    def run_with_patches(
        self,
        staging_root: Path,
        generator: list[str],
        *,
        force: bool = False,
        subprocess_side_effect: Any | None = None,
        capture_manifest: bool = False,
        fixture_factory: Any | None = None,
        which_side_effect: Any | None = None,
    ) -> tuple[int, dict[str, Any], list[dict[str, Any]]]:
        factory = self.make_patched_inputs if fixture_factory is None else fixture_factory
        catalog, selection = factory(staging_root)
        manifest_snapshots: list[dict[str, Any]] = []
        original_writer = runner.write_json_atomic

        def capture_writer(path: Path, data: dict[str, Any]) -> None:
            manifest_snapshots.append(copy.deepcopy(data))
            original_writer(path, data)

        patchers = [
            mock.patch.object(runner, "load_longform_catalog", return_value=catalog),
            mock.patch.object(runner, "validate_external_selection", return_value=selection),
            mock.patch.object(runner, "build_macro_guide", side_effect=self.fake_build_macro_guide),
        ]
        if subprocess_side_effect is not None:
            patchers.append(mock.patch.object(runner.subprocess, "run", side_effect=subprocess_side_effect))
        if capture_manifest:
            patchers.append(mock.patch.object(runner, "write_json_atomic", side_effect=capture_writer))
        if which_side_effect is not None:
            patchers.append(mock.patch.object(runner.shutil, "which", side_effect=which_side_effect))

        catalog_path = staging_root / "phase7_bgm_longform_jobs.json"
        phase7a_catalog_path = staging_root / "phase7_bgm_jobs.json"
        selection_path = staging_root / "bgm_candidate_selection.json"
        catalog_path.write_text("{\"fixture\": true}\n", encoding="utf-8")
        phase7a_catalog_path.write_text("{\"fixture\": true}\n", encoding="utf-8")
        selection_path.write_text("{\"fixture\": true}\n", encoding="utf-8")

        with patchers[0], patchers[1], patchers[2]:
            if len(patchers) == 3:
                exit_code = run_longform_catalog(catalog_path, selection_path, staging_root, generator, force)
            elif len(patchers) == 4:
                with patchers[3]:
                    exit_code = run_longform_catalog(catalog_path, selection_path, staging_root, generator, force)
            elif len(patchers) == 5:
                with patchers[3], patchers[4]:
                    exit_code = run_longform_catalog(catalog_path, selection_path, staging_root, generator, force)
            else:
                with patchers[3], patchers[4], patchers[5]:
                    exit_code = run_longform_catalog(catalog_path, selection_path, staging_root, generator, force)

        manifest_path = staging_root / "reports" / "longform_generation_manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        return exit_code, manifest, manifest_snapshots

    def test_api_is_available(self) -> None:
        self.require_runner_api()

    def test_filename_helpers_are_stable(self) -> None:
        self.require_runner_api()
        self.assertEqual("bgm_stage1_mid_B_guide188.wav", guide_filename("stage1_mid"))
        self.assertEqual("bgm_stage1_mid_B_source188.wav", source_filename("stage1_mid"))

    def test_build_longform_command_matches_exact_stable_audio_contract(self) -> None:
        self.require_runner_api()
        generator = ["/Volumes/personal_folder/bin/stable-audio-3-medium.sh"]
        defaults = {
            "source_seconds": 188.0,
            "steps": 8,
            "cfg": 2.0,
            "init_noise_level": 0.55,
            "dit": "medium",
            "decoder": "same-l",
            "free_models": True,
        }
        job = {
            "longform_prompt": "Expanded motif prompt",
            "selected_seed": 2026071102,
        }
        guide_path = Path("/Volumes/personal_folder/temp/godot_touhou_phase7/bgm_guides/stage1_mid/bgm_stage1_mid_B_guide188.wav")
        partial_path = Path("/Volumes/personal_folder/temp/godot_touhou_phase7/bgm_longform/stage1_mid/bgm_stage1_mid_B_source188.partial.wav")
        command = build_longform_command(generator, defaults, job, guide_path, partial_path, "lyrics, dialogue")
        self.assertEqual(
            [
                "/Volumes/personal_folder/bin/stable-audio-3-medium.sh",
                "--prompt",
                "Expanded motif prompt",
                "--negative-prompt",
                "lyrics, dialogue",
                "--init-audio",
                str(guide_path),
                "--init-noise-level",
                "0.55",
                "--dit",
                "medium",
                "--decoder",
                "same-l",
                "--seconds",
                "188.0",
                "--steps",
                "8",
                "--cfg",
                "2.0",
                "--seed",
                "2026071102",
                "--out",
                str(partial_path),
                "--free-models",
            ],
            command,
        )

    def test_run_longform_catalog_generates_source_with_atomic_publish_manifest_durability_and_explicit_fingerprint(self) -> None:
        self.require_runner_api()
        with tempfile.TemporaryDirectory() as temp_dir:
            staging_root = Path(temp_dir)
            generator_path = self.write_fake_generator(
                staging_root / "fake_generator.py",
                "import shutil, sys\n"
                "out = sys.argv[sys.argv.index('--out') + 1]\n"
                f"shutil.copyfile(r'{self.source_fixture}', out)\n",
            )
            exit_code, manifest, snapshots = self.run_with_patches(
                staging_root,
                [sys.executable, str(generator_path)],
                capture_manifest=True,
            )

            self.assertEqual(0, exit_code)
            self.assertEqual(0, manifest["failure_count"])
            self.assertIn("completed_at_unix", manifest)
            self.assertEqual(1, len(manifest["jobs"]))

            job = manifest["jobs"][0]
            final_path = Path(job["output_path"])
            partial_path = Path(job["partial_output_path"])
            guide_path = Path(job["guide_path"])

            self.assertEqual("generated", job["status"])
            self.assertTrue(final_path.is_file())
            self.assertFalse(partial_path.exists())
            self.assertTrue(guide_path.is_file())
            self.assertEqual(sha256_file(final_path), job["source_sha256"])
            self.assertEqual(sha256_file(guide_path), job["guide_sha256"])
            self.assertEqual(SOURCE_FRAMES, job["wave"]["frame_count"])
            self.assertEqual(44_100, job["wave"]["sample_rate"])
            self.assertEqual(2, job["wave"]["channels"])
            self.assertEqual(16, job["wave"]["bits_per_sample"])
            self.assertEqual([str(Path(sys.executable).resolve()), str(generator_path.resolve())], job["generator"])
            self.assertEqual(
                [
                    "control/phase7_bgm_longform_jobs.json",
                    "control/phase7_bgm_jobs.json",
                    "control/phase7_longform_catalog.py",
                    "control/phase7_catalog.py",
                    "control/phase7_longform_audio.py",
                    "control/phase7_longform_runner.py",
                ],
                [entry["published_path"] for entry in job["fingerprint"]["control_files"]],
            )
            self.assertEqual(
                str((staging_root / "phase7_bgm_jobs.json").resolve()),
                job["fingerprint"]["control_files"][1]["source_path"],
            )

            statuses = [snapshot["jobs"][0]["status"] for snapshot in snapshots if snapshot["jobs"]]
            self.assertEqual(["planned", "guide_ready", "generating", "generated"], statuses[:4])
            self.assertTrue(all(snapshot["jobs"][0]["status"] for snapshot in snapshots if snapshot["jobs"]))

    def test_run_longform_catalog_uses_local_staging_candidate_not_serialized_windows_or_macos_paths(self) -> None:
        self.require_runner_api()
        with tempfile.TemporaryDirectory() as temp_dir:
            staging_root = Path(temp_dir)

            def fake_subprocess(command: list[str], check: bool = False) -> subprocess.CompletedProcess:
                out_path = Path(command[command.index("--out") + 1])
                shutil.copyfile(self.source_fixture, out_path)
                return subprocess.CompletedProcess(command, 0)

            exit_code, manifest, _ = self.run_with_patches(
                staging_root,
                [sys.executable, str(staging_root / "unused_generator.py")],
                subprocess_side_effect=fake_subprocess,
            )

            self.assertEqual(0, exit_code)
            self.assertEqual(
                str(staging_root / "bgm_candidates" / "stage1_mid" / "bgm_stage1_mid_B_seed-2026071102.wav"),
                manifest["jobs"][0]["candidate_path"],
            )

    def test_run_longform_catalog_resolves_path_only_generator_and_preserves_args(self) -> None:
        self.require_runner_api()
        with tempfile.TemporaryDirectory() as temp_dir:
            staging_root = Path(temp_dir)
            generator_path = self.write_fake_generator(
                staging_root / "stable-audio-3-medium.sh",
                "import shutil, sys\n"
                "out = sys.argv[sys.argv.index('--out') + 1]\n"
                f"shutil.copyfile(r'{self.source_fixture}', out)\n",
            )
            captured_commands: list[list[str]] = []

            def fake_subprocess(command: list[str], check: bool = False) -> subprocess.CompletedProcess:
                captured_commands.append(list(command))
                out_path = Path(command[command.index("--out") + 1])
                shutil.copyfile(self.source_fixture, out_path)
                return subprocess.CompletedProcess(command, 0)

            exit_code, manifest, _ = self.run_with_patches(
                staging_root,
                ["stable-audio-3-medium.sh", "--profile", "longform"],
                subprocess_side_effect=fake_subprocess,
                which_side_effect=lambda name: str(generator_path) if name == "stable-audio-3-medium.sh" else None,
            )

            self.assertEqual(0, exit_code)
            self.assertEqual(str(generator_path.resolve()), manifest["jobs"][0]["generator"][0])
            self.assertEqual("--profile", manifest["jobs"][0]["generator"][1])
            self.assertEqual("longform", manifest["jobs"][0]["generator"][2])
            self.assertEqual(str(generator_path.resolve()), manifest["jobs"][0]["fingerprint"]["generator"][0])
            self.assertEqual(str(generator_path.resolve()), manifest["jobs"][0]["fingerprint"]["generator_script_path"])
            self.assertEqual(str(generator_path.resolve()), captured_commands[0][0])

    def test_run_longform_catalog_records_unresolved_path_generator_as_durable_global_preflight_failure(self) -> None:
        self.require_runner_api()
        with tempfile.TemporaryDirectory() as temp_dir:
            staging_root = Path(temp_dir)
            exit_code, manifest, snapshots = self.run_with_patches(
                staging_root,
                ["stable-audio-3-medium.sh", "--profile", "longform"],
                capture_manifest=True,
                fixture_factory=self.make_full_catalog_fixture,
                which_side_effect=lambda _name: None,
            )

            self.assertEqual(1, exit_code)
            self.assertEqual(12, len(manifest["jobs"]))
            self.assertEqual(12, manifest["failure_count"])
            self.assertIn("completed_at_unix", manifest)
            self.assertEqual(12, len(snapshots[0]["jobs"]))
            self.assertTrue(all(job["status"] == "planned" for job in snapshots[0]["jobs"]))
            self.assertTrue(all(job["status"] == "generation_failed" for job in manifest["jobs"]))
            self.assertTrue(all(job.get("error") == "generator executable could not be resolved: stable-audio-3-medium.sh" for job in manifest["jobs"]))
            self.assertTrue(all("finished_at_unix" in job for job in manifest["jobs"]))
            self.assertFalse((staging_root / "bgm_guides").exists())
            self.assertFalse((staging_root / "bgm_longform").exists())
            self.assertTrue(all(not Path(job["guide_path"]).exists() for job in manifest["jobs"]))
            self.assertTrue(all(not Path(job["output_path"]).exists() for job in manifest["jobs"]))
            self.assertTrue(all(not Path(job["partial_output_path"]).exists() for job in manifest["jobs"]))

    def test_run_longform_catalog_records_missing_absolute_generator_as_durable_global_preflight_failure(self) -> None:
        self.require_runner_api()
        with tempfile.TemporaryDirectory() as temp_dir:
            staging_root = Path(temp_dir)
            missing_generator = staging_root / "missing_generator.py"
            exit_code, manifest, snapshots = self.run_with_patches(
                staging_root,
                [str(missing_generator)],
                capture_manifest=True,
                fixture_factory=self.make_full_catalog_fixture,
            )

            self.assertEqual(1, exit_code)
            self.assertEqual(12, len(manifest["jobs"]))
            self.assertEqual(12, manifest["failure_count"])
            self.assertIn("completed_at_unix", manifest)
            self.assertEqual(12, len(snapshots[0]["jobs"]))
            self.assertTrue(all(job["status"] == "planned" for job in snapshots[0]["jobs"]))
            self.assertTrue(all(job["status"] == "generation_failed" for job in manifest["jobs"]))
            self.assertTrue(all(job.get("error") == f"generator executable could not be resolved: {missing_generator}" for job in manifest["jobs"]))
            self.assertTrue(all("finished_at_unix" in job for job in manifest["jobs"]))
            self.assertFalse((staging_root / "bgm_guides").exists())
            self.assertFalse((staging_root / "bgm_longform").exists())
            self.assertTrue(all(not Path(job["guide_path"]).exists() for job in manifest["jobs"]))
            self.assertTrue(all(not Path(job["output_path"]).exists() for job in manifest["jobs"]))
            self.assertTrue(all(not Path(job["partial_output_path"]).exists() for job in manifest["jobs"]))

    def test_run_longform_catalog_handles_keyboard_interrupt_persists_failure_and_stops_remaining_jobs(self) -> None:
        self.require_runner_api()
        with tempfile.TemporaryDirectory() as temp_dir:
            staging_root = Path(temp_dir)
            retained_partial = staging_root / "bgm_longform" / "stage1_mid" / "bgm_stage1_mid_B_source188.partial.wav"

            def fake_subprocess(command: list[str], check: bool = False) -> subprocess.CompletedProcess:
                out_path = Path(command[command.index("--out") + 1])
                write_pcm16_wave(out_path, SOURCE_FRAMES, left=111, right=-222)
                raise KeyboardInterrupt()

            exit_code, manifest, _ = self.run_with_patches(
                staging_root,
                [sys.executable, str(staging_root / "unused_generator.py")],
                subprocess_side_effect=fake_subprocess,
                fixture_factory=self.make_two_track_fixture,
            )

            self.assertEqual(1, exit_code)
            self.assertEqual(1, manifest["failure_count"])
            self.assertIn("completed_at_unix", manifest)
            self.assertEqual(2, len(manifest["jobs"]))
            self.assertEqual("generation_failed", manifest["jobs"][0]["status"])
            self.assertIn("KeyboardInterrupt", manifest["jobs"][0]["error"])
            self.assertIn("finished_at_unix", manifest["jobs"][0])
            self.assertEqual("retained_for_next_cleanup", manifest["jobs"][0]["partial_cleanup"])
            self.assertEqual("planned", manifest["jobs"][1]["status"])
            self.assertTrue(retained_partial.exists())

    def test_flat_control_layout_uses_sibling_phase7a_and_control_scripts_without_repo_fallback(self) -> None:
        self.require_runner_api()
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_root = Path(temp_dir)
            control_root = temp_root / "control"
            staging_root = temp_root / "staging"
            control_root.mkdir(parents=True, exist_ok=True)
            staging_root.mkdir(parents=True, exist_ok=True)

            copied_longform_path = control_root / "phase7_bgm_longform_jobs.json"
            copied_phase7a_path = control_root / "phase7_bgm_jobs.json"
            copied_runner_path = control_root / "phase7_longform_runner.py"
            copied_longform_catalog_path = control_root / "phase7_longform_catalog.py"
            copied_phase7_catalog_path = control_root / "phase7_catalog.py"
            copied_longform_audio_path = control_root / "phase7_longform_audio.py"
            copied_selection_path = staging_root / "reports" / "bgm_candidate_selection.json"
            synthetic_candidate_sha256 = self.candidate_sha256

            shutil.copyfile(ROOT / "audio" / "production" / "phase7_bgm_longform_jobs.json", copied_longform_path)
            shutil.copyfile(ROOT / "audio" / "production" / "phase7_bgm_jobs.json", copied_phase7a_path)
            shutil.copyfile(ROOT / "tools" / "audio" / "phase7_longform_runner.py", copied_runner_path)
            shutil.copyfile(ROOT / "tools" / "audio" / "phase7_longform_catalog.py", copied_longform_catalog_path)
            shutil.copyfile(ROOT / "tools" / "audio" / "phase7_catalog.py", copied_phase7_catalog_path)
            shutil.copyfile(ROOT / "tools" / "audio" / "phase7_longform_audio.py", copied_longform_audio_path)

            longform_data = json.loads(copied_longform_path.read_text(encoding="utf-8"))
            phase7a_data = json.loads(copied_phase7a_path.read_text(encoding="utf-8"))
            copied_phase7a_path.write_text(json.dumps(phase7a_data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            for track in longform_data["tracks"]:
                track["selected_sha256"] = synthetic_candidate_sha256
            copied_longform_path.write_text(json.dumps(longform_data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

            selection_tracks = []
            for track in longform_data["tracks"]:
                key = track["key"]
                seed = track["selected_seed"]
                candidate_dir = staging_root / "bgm_candidates" / key
                candidate_dir.mkdir(parents=True, exist_ok=True)
                candidate_path = candidate_dir / f"bgm_{key}_B_seed-{seed}.wav"
                write_pcm16_wave(candidate_path, CANDIDATE_FRAMES, left=640, right=-960)
                selection_tracks.append({
                    "track_key": key,
                    "title_zh": track["title_zh"],
                    "variant": "B",
                    "seed": seed,
                    "candidate_path_windows": rf"{CANONICAL_WINDOWS_ROOT}\bgm_candidates\{key}\bgm_{key}_B_seed-{seed}.wav",
                    "candidate_path_macos": f"{CANONICAL_MACOS_ROOT}/bgm_candidates/{key}/bgm_{key}_B_seed-{seed}.wav",
                    "sha256": synthetic_candidate_sha256,
                    "qa_status": "pass",
                    "status": "selected",
                })
            copied_selection_path.parent.mkdir(parents=True, exist_ok=True)
            copied_selection_path.write_text(
                json.dumps(
                    {
                        "schema_version": 1,
                        "selection_source": "human",
                        "user_decision": "synthetic-flat-control",
                        "recorded_at_utc": "2026-07-10T12:00:00Z",
                        "selection_complete": True,
                        "tracks": selection_tracks,
                    },
                    ensure_ascii=False,
                    indent=2,
                ) + "\n",
                encoding="utf-8",
            )
            approved_sha_map_literal = "{" + ", ".join(
                [f"'{track['key']}': '{synthetic_candidate_sha256}'" for track in longform_data["tracks"]]
            ) + "}"

            generator_path = self.write_fake_generator(
                staging_root / "flat_generator.py",
                "import shutil, sys\n"
                "out = sys.argv[sys.argv.index('--out') + 1]\n"
                f"shutil.copyfile(r'{self.source_fixture}', out)\n",
            )

            script = (
                "import sys\n"
                "from pathlib import Path\n"
                f"sys.path.insert(0, r'{control_root}')\n"
                "import phase7_longform_catalog as catalog_module\n"
                "import phase7_longform_runner as runner\n"
                f"catalog_module.APPROVED_SELECTED_SHA256 = {approved_sha_map_literal}\n"
                f"raise SystemExit(runner.run_longform_catalog(Path(r'{copied_longform_path}'), Path(r'{copied_selection_path}'), Path(r'{staging_root}'), [r'{sys.executable}', r'{generator_path}'], False))\n"
            )
            completed = subprocess.run([sys.executable, "-c", script], check=False)
            self.assertEqual(0, completed.returncode)

            manifest_path = staging_root / "reports" / "longform_generation_manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            self.assertEqual(0, manifest["failure_count"])
            self.assertEqual("generated", manifest["jobs"][0]["status"])
            control_files = manifest["jobs"][0]["fingerprint"]["control_files"]
            self.assertEqual(str(copied_phase7a_path.resolve()), control_files[1]["source_path"])
            self.assertEqual(str(copied_longform_catalog_path.resolve()), control_files[2]["source_path"])
            self.assertEqual(str(copied_phase7_catalog_path.resolve()), control_files[3]["source_path"])
            self.assertEqual(str(copied_longform_audio_path.resolve()), control_files[4]["source_path"])
            self.assertEqual(str(copied_runner_path.resolve()), control_files[5]["source_path"])

    def test_synthetic_runner_helpers_do_not_touch_real_selection_path(self) -> None:
        self.require_runner_api()
        original_read_text = Path.read_text
        original_read_bytes = Path.read_bytes

        def guarded_read_text(path: Path, *args: object, **kwargs: object) -> str:
            if Path(path) == REAL_SELECTION_PATH:
                raise AssertionError("synthetic runner helpers must not read REAL_SELECTION_PATH")
            return original_read_text(path, *args, **kwargs)

        def guarded_read_bytes(path: Path, *args: object, **kwargs: object) -> bytes:
            if Path(path) == REAL_SELECTION_PATH:
                raise AssertionError("synthetic runner helpers must not read REAL_SELECTION_PATH")
            return original_read_bytes(path, *args, **kwargs)

        with tempfile.TemporaryDirectory() as temp_dir:
            staging_root = Path(temp_dir)

            def fake_subprocess(command: list[str], check: bool = False) -> subprocess.CompletedProcess:
                out_path = Path(command[command.index("--out") + 1])
                shutil.copyfile(self.source_fixture, out_path)
                return subprocess.CompletedProcess(command, 0)

            with mock.patch.object(Path, "read_text", autospec=True, side_effect=guarded_read_text):
                with mock.patch.object(Path, "read_bytes", autospec=True, side_effect=guarded_read_bytes):
                    exit_code, manifest, _ = self.run_with_patches(
                        staging_root,
                        [sys.executable, str(staging_root / "synthetic_generator.py")],
                        subprocess_side_effect=fake_subprocess,
                    )
        self.assertEqual(0, exit_code)
        self.assertEqual("generated", manifest["jobs"][0]["status"])

    def test_run_longform_catalog_skips_existing_valid_source_only_when_prior_fingerprint_matches_exactly(self) -> None:
        self.require_runner_api()
        with tempfile.TemporaryDirectory() as temp_dir:
            staging_root = Path(temp_dir)
            generator_path = self.write_fake_generator(
                staging_root / "copy_generator.py",
                "import shutil, sys\n"
                "out = sys.argv[sys.argv.index('--out') + 1]\n"
                f"shutil.copyfile(r'{self.source_fixture}', out)\n",
            )
            first_exit, _, _ = self.run_with_patches(staging_root, [sys.executable, str(generator_path)])
            self.assertEqual(0, first_exit)

            with mock.patch.object(runner.subprocess, "run", side_effect=AssertionError("generator should not run")):
                second_exit, second_manifest, _ = self.run_with_patches(
                    staging_root,
                    [sys.executable, str(generator_path)],
                )

            self.assertEqual(0, second_exit)
            self.assertEqual("skipped_valid", second_manifest["jobs"][0]["status"])
            self.assertEqual(SOURCE_FRAMES, second_manifest["jobs"][0]["wave"]["frame_count"])

    def test_run_longform_catalog_records_existing_stale_and_refuses_overwrite_without_force(self) -> None:
        self.require_runner_api()
        with tempfile.TemporaryDirectory() as temp_dir:
            staging_root = Path(temp_dir)
            generator_path = self.write_fake_generator(
                staging_root / "copy_generator.py",
                "import shutil, sys\n"
                "out = sys.argv[sys.argv.index('--out') + 1]\n"
                f"shutil.copyfile(r'{self.source_fixture}', out)\n",
            )
            first_exit, manifest, _ = self.run_with_patches(staging_root, [sys.executable, str(generator_path)])
            self.assertEqual(0, first_exit)

            manifest_path = staging_root / "reports" / "longform_generation_manifest.json"
            prior_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            prior_manifest["jobs"][0]["fingerprint"]["selected_sha256"] = "0" * 64
            manifest_path.write_text(json.dumps(prior_manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

            final_path = Path(manifest["jobs"][0]["output_path"])
            original_sha256 = sha256_file(final_path)

            with mock.patch.object(runner.subprocess, "run", side_effect=AssertionError("generator should not run")):
                second_exit, second_manifest, _ = self.run_with_patches(
                    staging_root,
                    [sys.executable, str(generator_path)],
                )

            self.assertEqual(1, second_exit)
            self.assertEqual("existing_stale", second_manifest["jobs"][0]["status"])
            self.assertEqual(original_sha256, sha256_file(final_path))
            self.assertIn("fingerprint", second_manifest["jobs"][0]["error"])

    def test_run_longform_catalog_cleans_stale_partial_before_generation(self) -> None:
        self.require_runner_api()
        with tempfile.TemporaryDirectory() as temp_dir:
            staging_root = Path(temp_dir)
            final_path = staging_root / "bgm_longform" / "stage1_mid" / source_filename("stage1_mid")
            partial_path = final_path.with_name(final_path.stem + ".partial.wav")
            partial_path.parent.mkdir(parents=True, exist_ok=True)
            partial_path.write_bytes(b"stale-partial")

            def fake_subprocess(command: list[str], check: bool = False) -> subprocess.CompletedProcess:
                self.assertFalse(partial_path.exists(), "stale partial must be removed before generation starts")
                shutil.copyfile(self.source_fixture, partial_path)
                return subprocess.CompletedProcess(command, 0)

            exit_code, manifest, _ = self.run_with_patches(
                staging_root,
                [sys.executable, str(staging_root / "unused_generator.py")],
                subprocess_side_effect=fake_subprocess,
            )

            self.assertEqual(0, exit_code)
            self.assertEqual("generated", manifest["jobs"][0]["status"])
            self.assertFalse(partial_path.exists())
            self.assertTrue(final_path.exists())

    def test_run_longform_catalog_records_generator_oserror_as_generation_failed(self) -> None:
        self.require_runner_api()
        with tempfile.TemporaryDirectory() as temp_dir:
            staging_root = Path(temp_dir)
            exit_code, manifest, _ = self.run_with_patches(
                staging_root,
                [sys.executable, str(staging_root / "missing_generator.py")],
                subprocess_side_effect=OSError("generator missing"),
            )

            self.assertEqual(1, exit_code)
            self.assertEqual("generation_failed", manifest["jobs"][0]["status"])
            self.assertIn("generator missing", manifest["jobs"][0]["error"])
            self.assertFalse(Path(manifest["jobs"][0]["output_path"]).exists())

    def test_run_longform_catalog_records_nonzero_exit_as_generation_failed(self) -> None:
        self.require_runner_api()
        with tempfile.TemporaryDirectory() as temp_dir:
            staging_root = Path(temp_dir)

            def fake_subprocess(command: list[str], check: bool = False) -> subprocess.CompletedProcess:
                return subprocess.CompletedProcess(command, 7)

            exit_code, manifest, _ = self.run_with_patches(
                staging_root,
                [sys.executable, str(staging_root / "nonzero_generator.py")],
                subprocess_side_effect=fake_subprocess,
            )

            self.assertEqual(1, exit_code)
            self.assertEqual("generation_failed", manifest["jobs"][0]["status"])
            self.assertEqual(7, manifest["jobs"][0]["exit_code"])
            self.assertFalse(Path(manifest["jobs"][0]["output_path"]).exists())

    def test_run_longform_catalog_rejects_malformed_empty_and_truncated_output_without_publish(self) -> None:
        self.require_runner_api()
        cases = [
            ("malformed", b"not-a-wave-file"),
            ("empty", b""),
            ("truncated", b"RIFF"),
        ]

        for label, payload in cases:
            with self.subTest(case=label):
                with tempfile.TemporaryDirectory() as temp_dir:
                    staging_root = Path(temp_dir)

                    def fake_subprocess(command: list[str], check: bool = False) -> subprocess.CompletedProcess:
                        out_path = Path(command[command.index("--out") + 1])
                        out_path.write_bytes(payload)
                        return subprocess.CompletedProcess(command, 0)

                    exit_code, manifest, _ = self.run_with_patches(
                        staging_root,
                        [sys.executable, str(staging_root / f"{label}_generator.py")],
                        subprocess_side_effect=fake_subprocess,
                    )

                    self.assertEqual(1, exit_code)
                    self.assertEqual("validation_failed", manifest["jobs"][0]["status"])
                    self.assertIn("WAV", manifest["jobs"][0]["error"])
                    self.assertFalse(Path(manifest["jobs"][0]["output_path"]).exists())

    def test_optional_integration_preflight_skips_before_validator_when_candidate_missing(self) -> None:
        self.require_runner_api()
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_root = Path(temp_dir)
            catalog_path = temp_root / "phase7_bgm_longform_jobs.json"
            phase7a_path = temp_root / "phase7_bgm_jobs.json"
            selection_path = temp_root / "reports" / "bgm_candidate_selection.json"
            catalog_path.write_text("{\"fixture\": true}\n", encoding="utf-8")
            phase7a_path.write_text("{\"fixture\": true}\n", encoding="utf-8")
            selection_path.parent.mkdir(parents=True, exist_ok=True)
            selection_path.write_text(
                json.dumps(
                    make_fixture_selection(Path("unused"), self.candidate_sha256),
                    ensure_ascii=False,
                    indent=2,
                ) + "\n",
                encoding="utf-8",
            )

            with mock.patch(__name__ + ".load_longform_catalog", return_value=make_fixture_catalog(self.candidate_sha256)):
                with mock.patch(__name__ + ".validate_external_selection", side_effect=AssertionError("validator should not run")):
                    with self.assertRaises(unittest.SkipTest) as skipped:
                        self.load_optional_integration_selection(catalog_path, selection_path, temp_root)

        self.assertIn("missing NAS candidates for:", str(skipped.exception))

    def test_real_catalog_and_real_selection_build_twelve_exact_commands_without_mutating_external_selection(self) -> None:
        self.require_runner_api()
        catalog, selection, before_bytes = self.load_optional_integration_selection(
            REAL_CATALOG_PATH,
            REAL_SELECTION_PATH,
            REAL_STAGING_ROOT,
        )

        generator_path = self.fixture_root / "stable-audio-3-medium.sh"
        generator_path.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        generator = [str(generator_path.resolve())]

        selection_by_key = {track["track_key"]: track for track in selection["tracks"]}
        commands: list[list[str]] = []
        for track in catalog["tracks"]:
            selection_track = selection_by_key[track["key"]]
            prompt = " ".join([
                track["prompt"],
                catalog["longform_structure_prompt"],
                track["longform_development"],
            ])
            guide_path = self.fixture_root / "dry" / track["key"] / guide_filename(track["key"])
            partial_path = self.fixture_root / "dry" / track["key"] / f"{Path(source_filename(track['key'])).stem}.partial.wav"
            job = {
                "longform_prompt": prompt,
                "selected_seed": selection_track["seed"],
            }
            commands.append(
                build_longform_command(
                    generator,
                    catalog["defaults"],
                    job,
                    guide_path,
                    partial_path,
                    catalog["negative_prompt"],
                )
            )

        after_bytes = REAL_SELECTION_PATH.read_bytes()
        self.assertEqual(before_bytes, after_bytes)
        self.assertEqual(12, len(commands))
        self.assertTrue(all(command[0] == str(generator_path.resolve()) for command in commands))
        self.assertTrue(all(command[command.index("--seconds") + 1] == "188.0" for command in commands))
        self.assertTrue(all(command[command.index("--steps") + 1] == "8" for command in commands))
        self.assertTrue(all(command[command.index("--cfg") + 1] == "2.0" for command in commands))
        self.assertTrue(all(command[command.index("--init-noise-level") + 1] == "0.55" for command in commands))
        self.assertEqual(
            [track["selected_seed"] for track in catalog["tracks"]],
            [int(command[command.index("--seed") + 1]) for command in commands],
        )


if __name__ == "__main__":
    unittest.main()
