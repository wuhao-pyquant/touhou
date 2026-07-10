from __future__ import annotations

import json
import sys
import tempfile
import unittest
import wave
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "audio"))

import phase7_candidate_runner as runner
from phase7_catalog import load_catalog
from phase7_candidate_runner import build_command, candidate_filename, validate_wave


def write_silence(path: Path, seconds: float = 30.0) -> None:
    frames = int(44_100 * seconds)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(44_100)
        handle.writeframes(b"\x00\x00\x00\x00" * frames)


def mini_catalog() -> dict:
    return {
        "schema_version": 1,
        "defaults": {
            "seconds": 30.0,
            "steps": 8,
            "cfg": 2.0,
            "dit": "medium",
            "decoder": "same-l",
            "free_models": True,
        },
        "negative_prompt": "no lyrics",
        "tracks": [{
            "key": "stage1_mid",
            "title_zh": "鐏伀鍒濆弬閬?",
            "prompt": "original test prompt",
            "candidates": [{"variant": "A", "seed": 2026071101}],
        }],
    }


class Phase7CandidateRunnerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.catalog = load_catalog(ROOT / "audio" / "production" / "phase7_bgm_jobs.json")
        self.track = self.catalog["tracks"][0]
        self.candidate = self.track["candidates"][0]

    def test_candidate_filename_is_stable(self) -> None:
        self.assertEqual(
            "bgm_stage1_mid_A_seed-2026071101.wav",
            candidate_filename("stage1_mid", "A", 2026071101),
        )

    def test_command_contains_approved_arguments(self) -> None:
        command = build_command(
            ["/tmp/stable-audio-3-medium.sh"],
            self.catalog["defaults"],
            self.track,
            self.candidate,
            Path("/tmp/out.partial.wav"),
            self.catalog["negative_prompt"],
        )
        self.assertEqual("/tmp/stable-audio-3-medium.sh", command[0])
        self.assertEqual("medium", command[command.index("--dit") + 1])
        self.assertEqual("same-l", command[command.index("--decoder") + 1])
        self.assertEqual("30.0", command[command.index("--seconds") + 1])
        self.assertEqual("8", command[command.index("--steps") + 1])
        self.assertEqual("2.0", command[command.index("--cfg") + 1])
        self.assertEqual("2026071101", command[command.index("--seed") + 1])
        self.assertEqual(self.track["prompt"], command[command.index("--prompt") + 1])

    def test_wave_validation_accepts_exact_contract(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "candidate.wav"
            write_silence(path)
            report = validate_wave(path, 30.0)
            self.assertEqual(44_100, report["sample_rate"])
            self.assertEqual(2, report["channels"])
            self.assertEqual(16, report["bits_per_sample"])
            self.assertAlmostEqual(30.0, report["duration_seconds"], places=3)

    def test_wave_validation_rejects_wrong_channel_count(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "mono.wav"
            with wave.open(str(path), "wb") as handle:
                handle.setnchannels(1)
                handle.setsampwidth(2)
                handle.setframerate(44_100)
                handle.writeframes(b"\x00\x00" * 44_100)
            with self.assertRaisesRegex(ValueError, "stereo"):
                validate_wave(path, 1.0)

    def test_wave_validation_rejects_corrupt_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "corrupt.wav"
            path.write_bytes(b"not-a-wave-file")
            with self.assertRaisesRegex(ValueError, "invalid WAV output"):
                validate_wave(path, 30.0)

    def test_wave_validation_rejects_empty_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "empty.wav"
            path.write_bytes(b"")
            with self.assertRaisesRegex(ValueError, "invalid WAV output"):
                validate_wave(path, 30.0)

    def test_run_catalog_skips_existing_valid_candidate(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            staging = Path(temp_dir)
            track_dir = staging / "bgm_candidates" / "stage1_mid"
            track_dir.mkdir(parents=True)
            final_path = track_dir / candidate_filename("stage1_mid", "A", 2026071101)
            write_silence(final_path)
            with mock.patch.object(runner, "load_catalog", return_value=mini_catalog()):
                exit_code = runner.run_catalog(
                    Path("unused.json"), staging,
                    [sys.executable, "-c", "raise SystemExit(99)"], False,
                )
            self.assertEqual(0, exit_code)
            manifest = json.loads((staging / "reports" / "generation_manifest.json").read_text(encoding="utf-8"))
            self.assertEqual("skipped_valid", manifest["jobs"][0]["status"])

    def test_failed_generation_does_not_publish_final_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            staging = Path(temp_dir)
            with mock.patch.object(runner, "load_catalog", return_value=mini_catalog()):
                exit_code = runner.run_catalog(
                    Path("unused.json"), staging,
                    [sys.executable, "-c", "raise SystemExit(7)"], False,
                )
            final_path = staging / "bgm_candidates" / "stage1_mid" / candidate_filename(
                "stage1_mid", "A", 2026071101
            )
            self.assertEqual(1, exit_code)
            self.assertFalse(final_path.exists())
            manifest = json.loads((staging / "reports" / "generation_manifest.json").read_text(encoding="utf-8"))
            self.assertEqual("generation_failed", manifest["jobs"][0]["status"])

    def test_run_catalog_marks_corrupt_existing_final_invalid(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            staging = Path(temp_dir)
            track_dir = staging / "bgm_candidates" / "stage1_mid"
            track_dir.mkdir(parents=True)
            final_path = track_dir / candidate_filename("stage1_mid", "A", 2026071101)
            final_path.write_bytes(b"corrupt-existing-final")
            with mock.patch.object(runner, "load_catalog", return_value=mini_catalog()):
                exit_code = runner.run_catalog(
                    Path("unused.json"), staging,
                    [sys.executable, "-c", "raise SystemExit(99)"], False,
                )
            self.assertEqual(1, exit_code)
            manifest = json.loads((staging / "reports" / "generation_manifest.json").read_text(encoding="utf-8"))
            self.assertEqual("existing_invalid", manifest["jobs"][0]["status"])
            self.assertEqual(1, manifest["failure_count"])

    def test_run_catalog_marks_empty_existing_final_invalid(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            staging = Path(temp_dir)
            track_dir = staging / "bgm_candidates" / "stage1_mid"
            track_dir.mkdir(parents=True)
            final_path = track_dir / candidate_filename("stage1_mid", "A", 2026071101)
            final_path.write_bytes(b"")
            with mock.patch.object(runner, "load_catalog", return_value=mini_catalog()):
                exit_code = runner.run_catalog(
                    Path("unused.json"), staging,
                    [sys.executable, "-c", "raise SystemExit(99)"], False,
                )
            self.assertEqual(1, exit_code)
            self.assertEqual(b"", final_path.read_bytes())
            partial_path = final_path.with_name(final_path.stem + ".partial.wav")
            self.assertFalse(partial_path.exists())
            manifest = json.loads((staging / "reports" / "generation_manifest.json").read_text(encoding="utf-8"))
            self.assertEqual("existing_invalid", manifest["jobs"][0]["status"])
            self.assertEqual(1, manifest["failure_count"])
            self.assertIn("completed_at_unix", manifest)

    def test_run_catalog_marks_corrupt_generated_partial_validation_failed(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            staging = Path(temp_dir)
            fake_generator = staging / "fake_generator.py"
            fake_generator.write_text(
                "import sys\n"
                "out=sys.argv[sys.argv.index('--out')+1]\n"
                "open(out,'wb').write(b'corrupt-partial-output')\n",
                encoding="utf-8",
            )
            with mock.patch.object(runner, "load_catalog", return_value=mini_catalog()):
                exit_code = runner.run_catalog(
                    Path("unused.json"), staging,
                    [sys.executable, str(fake_generator)], False,
                )
            final_path = staging / "bgm_candidates" / "stage1_mid" / candidate_filename(
                "stage1_mid", "A", 2026071101
            )
            self.assertEqual(1, exit_code)
            self.assertFalse(final_path.exists())
            manifest = json.loads((staging / "reports" / "generation_manifest.json").read_text(encoding="utf-8"))
            self.assertEqual("validation_failed", manifest["jobs"][0]["status"])
            self.assertIn("invalid WAV output", manifest["jobs"][0]["error"])
            self.assertEqual(1, manifest["failure_count"])

    def test_run_catalog_marks_truncated_generated_partial_validation_failed(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            staging = Path(temp_dir)
            fake_generator = staging / "fake_generator.py"
            fake_generator.write_text(
                "import sys\n"
                "out=sys.argv[sys.argv.index('--out')+1]\n"
                "open(out,'wb').write(b'RIFF')\n",
                encoding="utf-8",
            )
            with mock.patch.object(runner, "load_catalog", return_value=mini_catalog()):
                exit_code = runner.run_catalog(
                    Path("unused.json"), staging,
                    [sys.executable, str(fake_generator)], False,
                )
            final_path = staging / "bgm_candidates" / "stage1_mid" / candidate_filename(
                "stage1_mid", "A", 2026071101
            )
            partial_path = final_path.with_name(final_path.stem + ".partial.wav")
            self.assertEqual(1, exit_code)
            self.assertFalse(final_path.exists())
            self.assertTrue(partial_path.exists())
            manifest = json.loads((staging / "reports" / "generation_manifest.json").read_text(encoding="utf-8"))
            self.assertEqual("validation_failed", manifest["jobs"][0]["status"])
            self.assertIn("invalid WAV output", manifest["jobs"][0]["error"])
            self.assertEqual(1, manifest["failure_count"])
            self.assertIn("completed_at_unix", manifest)

    def test_run_catalog_records_generator_oserror_as_generation_failed(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            staging = Path(temp_dir)
            with mock.patch.object(runner, "load_catalog", return_value=mini_catalog()):
                with mock.patch.object(runner.subprocess, "run", side_effect=OSError("generator missing")):
                    exit_code = runner.run_catalog(
                        Path("unused.json"), staging,
                        [sys.executable, "-c", "print('unused')"], False,
                    )
            self.assertEqual(1, exit_code)
            manifest = json.loads((staging / "reports" / "generation_manifest.json").read_text(encoding="utf-8"))
            self.assertEqual("generation_failed", manifest["jobs"][0]["status"])
            self.assertIn("generator missing", manifest["jobs"][0]["error"])
            self.assertIn("finished_at_unix", manifest["jobs"][0])
            self.assertEqual(1, manifest["failure_count"])

    def test_successful_generation_atomically_publishes_final_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            staging = Path(temp_dir)
            fake_generator = staging / "fake_generator.py"
            fake_generator.write_text(
                "import sys,wave\n"
                "out=sys.argv[sys.argv.index('--out')+1]\n"
                "w=wave.open(out,'wb'); w.setnchannels(2); w.setsampwidth(2); "
                "w.setframerate(44100); w.writeframes(b'\\0\\0\\0\\0'*44100*30); w.close()\n",
                encoding="utf-8",
            )
            with mock.patch.object(runner, "load_catalog", return_value=mini_catalog()):
                exit_code = runner.run_catalog(
                    Path("unused.json"), staging,
                    [sys.executable, str(fake_generator)], False,
                )
            final_path = staging / "bgm_candidates" / "stage1_mid" / candidate_filename(
                "stage1_mid", "A", 2026071101
            )
            partial_path = final_path.with_name(final_path.stem + ".partial.wav")
            self.assertEqual(0, exit_code)
            self.assertTrue(final_path.is_file())
            self.assertFalse(partial_path.exists())
            manifest = json.loads((staging / "reports" / "generation_manifest.json").read_text(encoding="utf-8"))
            self.assertEqual("generated", manifest["jobs"][0]["status"])


if __name__ == "__main__":
    unittest.main()
