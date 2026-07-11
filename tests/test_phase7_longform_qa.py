from __future__ import annotations

import copy
import json
import math
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
    import phase7_longform_qa as qa
    from phase7_longform_qa import (
        apply_constant_gain,
        build_longform_review_html,
        calculate_constant_gain,
        master_and_analyze,
        measure_loudness,
    )
    MODULE_IMPORT_ERROR = None
except Exception as exc:  # pragma: no cover - exercised during RED before implementation
    qa = None
    apply_constant_gain = None
    build_longform_review_html = None
    calculate_constant_gain = None
    master_and_analyze = None
    measure_loudness = None
    MODULE_IMPORT_ERROR = exc


SAMPLE_RATE = 44_100
CHANNELS = 2
PCM_MAX = 32_767


def clamp_pcm16(value: float) -> int:
    integer = int(round(value))
    if integer < -32_768:
        return -32_768
    if integer > 32_767:
        return 32_767
    return integer


def write_tone(path: Path, seconds: float, *, amplitude: float = 0.25, frequency: float = 220.0) -> None:
    frame_count = int(round(seconds * SAMPLE_RATE))
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(CHANNELS)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        samples = array("h")
        for frame_index in range(frame_count):
            time_seconds = frame_index / SAMPLE_RATE
            left = clamp_pcm16(amplitude * math.sin(2.0 * math.pi * frequency * time_seconds) * PCM_MAX)
            right = clamp_pcm16(amplitude * math.sin(2.0 * math.pi * (frequency * 1.5) * time_seconds) * PCM_MAX)
            samples.append(left)
            samples.append(right)
        handle.writeframes(samples.tobytes())


def read_frame_count(path: Path) -> int:
    with wave.open(str(path), "rb") as handle:
        return handle.getnframes()


def make_catalog() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "defaults": {
            "source_seconds": 188.0,
            "master_seconds": 180.0,
            "crossfade_seconds": 8.0,
            "guide_crossfade_seconds": 1.0,
            "target_lufs": -16.0,
            "max_true_peak_dbtp": -1.0,
        },
        "tracks": [
            {
                "key": "stage1_mid",
                "stage": 1,
                "phase": "mid",
                "title_zh": "灯火初参道 <A>",
                "selected_variant": "B",
                "selected_seed": 101,
            },
            {
                "key": "stage1_boss",
                "stage": 1,
                "phase": "boss",
                "title_zh": "祭坛决斗 & 终幕",
                "selected_variant": "B",
                "selected_seed": 202,
            },
        ],
    }


class Phase7LongformQaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.temp_dir = tempfile.TemporaryDirectory()
        cls.temp_root = Path(cls.temp_dir.name)
        cls.short_source = cls.temp_root / "input.wav"
        cls.short_preview = cls.temp_root / "preview.wav"
        cls.changed_frames = cls.temp_root / "changed.wav"
        write_tone(cls.short_source, 1.0, amplitude=0.22)
        write_tone(cls.short_preview, 0.5, amplitude=0.18)
        write_tone(cls.changed_frames, 0.75, amplitude=0.2)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.temp_dir.cleanup()

    def require_api(self) -> None:
        if MODULE_IMPORT_ERROR is not None:
            self.fail(f"phase7_longform_qa import failed: {MODULE_IMPORT_ERROR}")
        self.assertTrue(callable(measure_loudness), "measure_loudness must be callable")
        self.assertTrue(callable(calculate_constant_gain), "calculate_constant_gain must be callable")
        self.assertTrue(callable(apply_constant_gain), "apply_constant_gain must be callable")
        self.assertTrue(callable(master_and_analyze), "master_and_analyze must be callable")
        self.assertTrue(callable(build_longform_review_html), "build_longform_review_html must be callable")

    def test_api_is_available(self) -> None:
        self.require_api()

    def test_measure_loudness_parses_loudnorm_json_from_noisy_stderr(self) -> None:
        self.require_api()
        stderr = "\n".join([
            "ffmpeg version n7.0-test",
            "[Parsed_loudnorm_0 @ 000001] summary follows",
            "{",
            '  "input_i" : "-19.84",',
            '  "input_tp" : "-2.43",',
            '  "input_lra" : "5.10"',
            "}",
            "video:0kB audio:12kB subtitle:0kB",
        ])
        completed = subprocess.CompletedProcess(["ffmpeg"], 0, stdout="", stderr=stderr)
        with mock.patch.object(qa.shutil, "which", return_value=r"C:\ffmpeg\bin\ffmpeg.exe"):
            with mock.patch.object(qa.subprocess, "run", return_value=completed) as mocked_run:
                report = measure_loudness(Path("ffmpeg"), self.short_source)

        self.assertAlmostEqual(-19.84, report["integrated_lufs"], places=6)
        self.assertAlmostEqual(-2.43, report["true_peak_dbtp"], places=6)
        self.assertEqual(-19.84, report["raw"]["input_i"])
        self.assertEqual(-2.43, report["raw"]["input_tp"])
        command = mocked_run.call_args.args[0]
        self.assertEqual(r"C:\ffmpeg\bin\ffmpeg.exe", command[0])
        self.assertIn("loudnorm", command[command.index("-af") + 1])

    def test_measure_loudness_rejects_missing_json(self) -> None:
        self.require_api()
        completed = subprocess.CompletedProcess(["ffmpeg"], 0, stdout="", stderr="no loudnorm block here")
        with mock.patch.object(qa.shutil, "which", return_value=r"C:\ffmpeg\bin\ffmpeg.exe"):
            with mock.patch.object(qa.subprocess, "run", return_value=completed):
                with self.assertRaisesRegex(ValueError, r"loudnorm JSON"):
                    measure_loudness(Path("ffmpeg"), self.short_source)

    def test_calculate_constant_gain_targets_lufs_but_caps_true_peak(self) -> None:
        self.require_api()
        capped = calculate_constant_gain(
            {"integrated_lufs": -20.0, "true_peak_dbtp": -3.0},
            -16.0,
            -1.0,
        )
        unchanged = calculate_constant_gain(
            {"integrated_lufs": -15.6, "true_peak_dbtp": -3.5},
            -16.0,
            -1.0,
        )
        self.assertAlmostEqual(2.0, capped, places=6)
        self.assertAlmostEqual(-0.4, unchanged, places=6)

    def test_apply_constant_gain_uses_only_volume_and_pcm16_and_preserves_frames(self) -> None:
        self.require_api()
        output_path = self.temp_root / "constant_gain.wav"

        def fake_run(command: list[str], check: bool, capture_output: bool, text: bool) -> subprocess.CompletedProcess:
            self.assertFalse(check)
            self.assertTrue(capture_output)
            self.assertTrue(text)
            self.assertEqual(r"C:\ffmpeg\bin\ffmpeg.exe", command[0])
            self.assertEqual("volume=1.500000dB", command[command.index("-af") + 1])
            self.assertEqual("pcm_s16le", command[command.index("-c:a") + 1])
            forbidden_tokens = {
                "loudnorm",
                "alimiter",
                "acompressor",
                "compand",
                "afade",
                "atempo",
                "aresample",
                "-ar",
                "-ac",
                "-t",
                "-ss",
            }
            self.assertTrue(forbidden_tokens.isdisjoint(command))
            shutil.copyfile(self.short_source, output_path)
            return subprocess.CompletedProcess(command, 0, stdout="", stderr="")

        with mock.patch.object(qa.shutil, "which", return_value=r"C:\ffmpeg\bin\ffmpeg.exe"):
            with mock.patch.object(qa.subprocess, "run", side_effect=fake_run):
                apply_constant_gain(Path("ffmpeg"), self.short_source, output_path, 1.5)

        self.assertTrue(output_path.exists())
        self.assertEqual(read_frame_count(self.short_source), read_frame_count(output_path))

    def test_apply_constant_gain_rejects_frame_count_changes(self) -> None:
        self.require_api()
        output_path = self.temp_root / "bad_frames.wav"

        def fake_run(command: list[str], check: bool, capture_output: bool, text: bool) -> subprocess.CompletedProcess:
            del command, check, capture_output, text
            shutil.copyfile(self.changed_frames, output_path)
            return subprocess.CompletedProcess(["ffmpeg"], 0, stdout="", stderr="")

        with mock.patch.object(qa.shutil, "which", return_value=r"C:\ffmpeg\bin\ffmpeg.exe"):
            with mock.patch.object(qa.subprocess, "run", side_effect=fake_run):
                with self.assertRaisesRegex(ValueError, r"frame count"):
                    apply_constant_gain(Path("ffmpeg"), self.short_source, output_path, 0.0)

    def test_master_and_analyze_writes_counts_publishes_passing_outputs_and_non_blocking_repeat_warning(self) -> None:
        self.require_api()
        catalog = make_catalog()
        raw_sources: dict[str, Path] = {}
        staged_dirs: dict[str, Path] = {}

        with tempfile.TemporaryDirectory() as temp_dir:
            staging_root = Path(temp_dir)
            for track in catalog["tracks"]:
                track_root = staging_root / "bgm_longform" / track["key"]
                track_root.mkdir(parents=True, exist_ok=True)
                source_path = track_root / f"bgm_{track['key']}_B_source188.wav"
                write_tone(source_path, 1.0, amplitude=0.21)
                raw_sources[track["key"]] = source_path
                staged_dirs[track["key"]] = track_root

            def fake_render(source_path: Path, output_path: Path, source_seconds: float, master_seconds: float, crossfade_seconds: float) -> dict[str, Any]:
                self.assertEqual(188.0, source_seconds)
                self.assertEqual(180.0, master_seconds)
                self.assertEqual(8.0, crossfade_seconds)
                shutil.copyfile(source_path, output_path)
                return {
                    "path": str(output_path),
                    "frame_count": read_frame_count(output_path),
                    "sample_rate": SAMPLE_RATE,
                    "channels": 2,
                    "bits_per_sample": 16,
                }

            measurements = iter([
                {"integrated_lufs": -19.0, "true_peak_dbtp": -3.0, "raw": {"input_i": -19.0, "input_tp": -3.0}},
                {"integrated_lufs": -16.1, "true_peak_dbtp": -1.1, "raw": {"input_i": -16.1, "input_tp": -1.1}},
                {"integrated_lufs": -18.5, "true_peak_dbtp": -2.0, "raw": {"input_i": -18.5, "input_tp": -2.0}},
                {"integrated_lufs": -14.4, "true_peak_dbtp": -1.2, "raw": {"input_i": -14.4, "input_tp": -1.2}},
            ])

            def fake_measure(ffmpeg: Path, source: Path) -> dict[str, Any]:
                self.assertEqual(r"C:\ffmpeg\bin\ffmpeg.exe", str(ffmpeg))
                self.assertTrue(source.exists())
                return next(measurements)

            def fake_apply(ffmpeg: Path, source: Path, output: Path, gain_db: float) -> None:
                self.assertEqual(r"C:\ffmpeg\bin\ffmpeg.exe", str(ffmpeg))
                self.assertTrue(math.isfinite(gain_db))
                shutil.copyfile(source, output)

            def fake_edges(master_path: Path, repeat_count: int = 10) -> dict[str, Any]:
                self.assertEqual(10, repeat_count)
                status = "pass" if "stage1_mid" in str(master_path) else "pass"
                return {
                    "path": str(master_path),
                    "status": status,
                    "frame_count": 180 * SAMPLE_RATE,
                    "sample_rate": SAMPLE_RATE,
                    "channels": 2,
                    "bits_per_sample": 16,
                    "repeat_count": repeat_count,
                    "silence_ratio": 0.01,
                    "max_contiguous_silence_seconds": 0.0,
                    "dc_offset": [0.0, 0.0],
                    "peak_dbfs": -3.0,
                    "seam": {"passes": True, "channels": []},
                    "internal_join": {"passes": True, "channels": []},
                    "wrap_transitions": [{"boundary_index": index + 1, "passes": True, "channels": []} for index in range(9)],
                }

            def fake_preview(master_path: Path, output_path: Path, window_seconds: float = 15.0) -> dict[str, Any]:
                self.assertEqual(15.0, window_seconds)
                shutil.copyfile(self.short_preview, output_path)
                return {
                    "path": str(output_path),
                    "frame_count": 30 * SAMPLE_RATE,
                    "sample_rate": SAMPLE_RATE,
                    "channels": 2,
                    "bits_per_sample": 16,
                    "window_seconds": 15.0,
                }

            def fake_repeat(master_path: Path) -> dict[str, Any]:
                if "stage1_mid" in str(master_path):
                    return {
                        "possible_six_repeat_structure": True,
                        "pairs": [{
                            "left_start_seconds": 0,
                            "right_start_seconds": 30,
                            "correlation": 0.992,
                            "normalized_mean_difference": 0.011,
                        }],
                    }
                return {
                    "possible_six_repeat_structure": False,
                    "pairs": [],
                }

            with mock.patch.object(qa, "render_circular_loop", side_effect=fake_render):
                with mock.patch.object(qa, "_resolve_ffmpeg_path", return_value=Path(r"C:\ffmpeg\bin\ffmpeg.exe")):
                    with mock.patch.object(qa, "measure_loudness", side_effect=fake_measure):
                        with mock.patch.object(qa, "apply_constant_gain", side_effect=fake_apply):
                            with mock.patch.object(qa, "analyze_loop_edges", side_effect=fake_edges):
                                with mock.patch.object(qa, "build_transition_preview", side_effect=fake_preview):
                                    with mock.patch.object(qa, "_analyze_repeat_structure", side_effect=fake_repeat):
                                        report = master_and_analyze(catalog, staging_root, Path(r"C:\ffmpeg\bin\ffmpeg.exe"))

            self.assertEqual(2, report["expected_track_count"])
            self.assertEqual(1, report["pass_count"])
            self.assertEqual(1, report["fail_count"])
            self.assertEqual(1, report["warning_count"])
            self.assertEqual(["pass", "fail"], [item["status"] for item in report["tracks"]])
            self.assertTrue(report["tracks"][0]["possible_six_repeat_structure"])
            self.assertFalse(report["tracks"][1]["possible_six_repeat_structure"])
            self.assertIn("loudness", " ".join(report["tracks"][1]["errors"]).lower())

            passing_master = staged_dirs["stage1_mid"] / "bgm_stage1_mid_B_loop180_review.wav"
            passing_preview = staged_dirs["stage1_mid"] / "bgm_stage1_mid_B_loop_transition.wav"
            failing_master = staged_dirs["stage1_boss"] / "bgm_stage1_boss_B_loop180_review.wav"
            failing_preview = staged_dirs["stage1_boss"] / "bgm_stage1_boss_B_loop_transition.wav"
            self.assertTrue(passing_master.exists())
            self.assertTrue(passing_preview.exists())
            self.assertFalse(failing_master.exists())
            self.assertFalse(failing_preview.exists())

            report_path = staging_root / "reports" / "longform_qa.json"
            html_path = staging_root / "reports" / "bgm_longform_review.html"
            self.assertTrue(report_path.exists())
            self.assertTrue(html_path.exists())
            persisted = json.loads(report_path.read_text(encoding="utf-8"))
            self.assertEqual(report, persisted)
            self.assertIn("可能存在六段重复结构", html_path.read_text(encoding="utf-8"))

    def test_master_and_analyze_failure_rerun_removes_previously_published_pair(self) -> None:
        self.require_api()
        catalog = make_catalog()
        catalog["tracks"] = [catalog["tracks"][0]]

        with tempfile.TemporaryDirectory() as temp_dir:
            staging_root = Path(temp_dir)
            track = catalog["tracks"][0]
            track_root = staging_root / "bgm_longform" / track["key"]
            track_root.mkdir(parents=True, exist_ok=True)
            source_path = track_root / f"bgm_{track['key']}_B_source188.wav"
            master_path = track_root / f"bgm_{track['key']}_B_loop180_review.wav"
            preview_path = track_root / f"bgm_{track['key']}_B_loop_transition.wav"
            master_temp = master_path.with_suffix(".tmp.wav")
            preview_temp = preview_path.with_suffix(".tmp.wav")
            write_tone(source_path, 1.0, amplitude=0.2)
            write_tone(master_path, 1.0, amplitude=0.19, frequency=330.0)
            write_tone(preview_path, 0.5, amplitude=0.17, frequency=440.0)

            measure_values = iter([
                {"integrated_lufs": -18.0, "true_peak_dbtp": -2.0, "raw": {"input_i": -18.0, "input_tp": -2.0}},
                {"integrated_lufs": -14.8, "true_peak_dbtp": -0.8, "raw": {"input_i": -14.8, "input_tp": -0.8}},
            ])

            def fake_render(source: Path, output: Path, *_args: Any) -> dict[str, Any]:
                shutil.copyfile(source, output)
                return {
                    "path": str(output),
                    "frame_count": read_frame_count(output),
                    "sample_rate": SAMPLE_RATE,
                    "channels": 2,
                    "bits_per_sample": 16,
                }

            def fake_apply(_ffmpeg: Path, source: Path, output: Path, _gain: float) -> None:
                shutil.copyfile(source, output)

            def fake_preview(master: Path, output: Path, window_seconds: float = 15.0) -> dict[str, Any]:
                self.assertEqual(15.0, window_seconds)
                shutil.copyfile(self.short_preview, output)
                return {
                    "path": str(output),
                    "frame_count": 30 * SAMPLE_RATE,
                    "sample_rate": SAMPLE_RATE,
                    "channels": 2,
                    "bits_per_sample": 16,
                    "window_seconds": 15.0,
                }

            with mock.patch.object(qa, "render_circular_loop", side_effect=fake_render):
                with mock.patch.object(qa, "_resolve_ffmpeg_path", return_value=Path(r"C:\ffmpeg\bin\ffmpeg.exe")):
                    with mock.patch.object(qa, "measure_loudness", side_effect=lambda _ffmpeg, _source: next(measure_values)):
                        with mock.patch.object(qa, "apply_constant_gain", side_effect=fake_apply):
                            with mock.patch.object(qa, "analyze_loop_edges", return_value={
                                "path": "",
                                "status": "pass",
                                "frame_count": 180 * SAMPLE_RATE,
                                "sample_rate": SAMPLE_RATE,
                                "channels": 2,
                                "bits_per_sample": 16,
                                "repeat_count": 10,
                                "silence_ratio": 0.01,
                                "max_contiguous_silence_seconds": 0.0,
                                "dc_offset": [0.0, 0.0],
                                "peak_dbfs": -3.0,
                                "seam": {"passes": True, "channels": []},
                                "internal_join": {"passes": True, "channels": []},
                                "wrap_transitions": [{"boundary_index": index + 1, "passes": True, "channels": []} for index in range(9)],
                            }):
                                with mock.patch.object(qa, "build_transition_preview", side_effect=fake_preview):
                                    with mock.patch.object(qa, "_analyze_repeat_structure", return_value={"possible_six_repeat_structure": False, "pairs": []}):
                                        report = master_and_analyze(catalog, staging_root, Path(r"C:\ffmpeg\bin\ffmpeg.exe"))

            self.assertEqual("fail", report["tracks"][0]["status"])
            self.assertFalse(master_path.exists())
            self.assertFalse(preview_path.exists())
            self.assertFalse(master_temp.exists())
            self.assertFalse(preview_temp.exists())
            self.assertIn("loudness", " ".join(report["tracks"][0]["errors"]).lower())

    def test_master_and_analyze_second_replace_failure_removes_formal_pair_and_temps(self) -> None:
        self.require_api()
        catalog = make_catalog()
        catalog["tracks"] = [catalog["tracks"][0]]

        with tempfile.TemporaryDirectory() as temp_dir:
            staging_root = Path(temp_dir)
            track = catalog["tracks"][0]
            track_root = staging_root / "bgm_longform" / track["key"]
            track_root.mkdir(parents=True, exist_ok=True)
            source_path = track_root / f"bgm_{track['key']}_B_source188.wav"
            master_path = track_root / f"bgm_{track['key']}_B_loop180_review.wav"
            preview_path = track_root / f"bgm_{track['key']}_B_loop_transition.wav"
            master_temp = master_path.with_suffix(".tmp.wav")
            preview_temp = preview_path.with_suffix(".tmp.wav")
            write_tone(source_path, 1.0, amplitude=0.2)
            write_tone(master_path, 1.0, amplitude=0.19, frequency=330.0)
            write_tone(preview_path, 0.5, amplitude=0.17, frequency=440.0)

            def fake_render(source: Path, output: Path, *_args: Any) -> dict[str, Any]:
                shutil.copyfile(source, output)
                return {
                    "path": str(output),
                    "frame_count": read_frame_count(output),
                    "sample_rate": SAMPLE_RATE,
                    "channels": 2,
                    "bits_per_sample": 16,
                }

            def fake_apply(_ffmpeg: Path, source: Path, output: Path, _gain: float) -> None:
                shutil.copyfile(source, output)

            def fake_preview(master: Path, output: Path, window_seconds: float = 15.0) -> dict[str, Any]:
                self.assertEqual(15.0, window_seconds)
                shutil.copyfile(self.short_preview, output)
                return {
                    "path": str(output),
                    "frame_count": 30 * SAMPLE_RATE,
                    "sample_rate": SAMPLE_RATE,
                    "channels": 2,
                    "bits_per_sample": 16,
                    "window_seconds": 15.0,
                }

            real_replace = qa.os.replace
            replace_call_count = 0

            def fail_on_second_replace(source: Path, destination: Path) -> None:
                nonlocal replace_call_count
                replace_call_count += 1
                if replace_call_count == 2:
                    raise OSError("preview replace failed")
                real_replace(source, destination)

            with mock.patch.object(qa, "render_circular_loop", side_effect=fake_render):
                with mock.patch.object(qa, "_resolve_ffmpeg_path", return_value=Path(r"C:\ffmpeg\bin\ffmpeg.exe")):
                    with mock.patch.object(qa, "measure_loudness", side_effect=[
                        {"integrated_lufs": -18.0, "true_peak_dbtp": -2.0, "raw": {"input_i": -18.0, "input_tp": -2.0}},
                        {"integrated_lufs": -16.0, "true_peak_dbtp": -1.0, "raw": {"input_i": -16.0, "input_tp": -1.0}},
                    ]):
                        with mock.patch.object(qa, "apply_constant_gain", side_effect=fake_apply):
                            with mock.patch.object(qa, "analyze_loop_edges", return_value={
                                "path": "",
                                "status": "pass",
                                "frame_count": 180 * SAMPLE_RATE,
                                "sample_rate": SAMPLE_RATE,
                                "channels": 2,
                                "bits_per_sample": 16,
                                "repeat_count": 10,
                                "silence_ratio": 0.01,
                                "max_contiguous_silence_seconds": 0.0,
                                "dc_offset": [0.0, 0.0],
                                "peak_dbfs": -3.0,
                                "seam": {"passes": True, "channels": []},
                                "internal_join": {"passes": True, "channels": []},
                                "wrap_transitions": [{"boundary_index": index + 1, "passes": True, "channels": []} for index in range(9)],
                            }):
                                with mock.patch.object(qa, "build_transition_preview", side_effect=fake_preview):
                                    with mock.patch.object(qa, "_analyze_repeat_structure", return_value={"possible_six_repeat_structure": False, "pairs": []}):
                                        with mock.patch.object(qa.os, "replace", side_effect=fail_on_second_replace):
                                            report = master_and_analyze(catalog, staging_root, Path(r"C:\ffmpeg\bin\ffmpeg.exe"))

            self.assertEqual("fail", report["tracks"][0]["status"])
            self.assertFalse(master_path.exists())
            self.assertFalse(preview_path.exists())
            self.assertFalse(master_temp.exists())
            self.assertFalse(preview_temp.exists())
            self.assertIn("preview replace failed", report["tracks"][0]["errors"][0])

    def test_master_and_analyze_enforces_loudness_and_true_peak_boundaries(self) -> None:
        self.require_api()
        catalog = make_catalog()
        catalog["tracks"] = [catalog["tracks"][0]]
        cases = [
            ("inclusive_low_lufs", -17.0, -1.0, "pass"),
            ("inclusive_high_lufs", -15.0, -1.0, "pass"),
            ("too_quiet", -17.01, -1.0, "fail"),
            ("too_loud", -14.99, -1.0, "fail"),
            ("peak_above_limit", -16.0, -0.99, "fail"),
        ]

        for label, final_lufs, final_peak, expected_status in cases:
            with self.subTest(case=label):
                with tempfile.TemporaryDirectory() as temp_dir:
                    staging_root = Path(temp_dir)
                    track = catalog["tracks"][0]
                    track_root = staging_root / "bgm_longform" / track["key"]
                    track_root.mkdir(parents=True, exist_ok=True)
                    source_path = track_root / f"bgm_{track['key']}_B_source188.wav"
                    write_tone(source_path, 1.0, amplitude=0.2)

                    measure_values = iter([
                        {"integrated_lufs": -18.0, "true_peak_dbtp": -2.0, "raw": {"input_i": -18.0, "input_tp": -2.0}},
                        {"integrated_lufs": final_lufs, "true_peak_dbtp": final_peak, "raw": {"input_i": final_lufs, "input_tp": final_peak}},
                    ])

                    def fake_render(source: Path, output: Path, *_args: Any) -> dict[str, Any]:
                        shutil.copyfile(source, output)
                        return {
                            "path": str(output),
                            "frame_count": read_frame_count(output),
                            "sample_rate": SAMPLE_RATE,
                            "channels": 2,
                            "bits_per_sample": 16,
                        }

                    def fake_preview(master: Path, output: Path, window_seconds: float = 15.0) -> dict[str, Any]:
                        shutil.copyfile(master, output)
                        return {
                            "path": str(output),
                            "frame_count": 30 * SAMPLE_RATE,
                            "sample_rate": SAMPLE_RATE,
                            "channels": 2,
                            "bits_per_sample": 16,
                            "window_seconds": window_seconds,
                        }

                    with mock.patch.object(qa, "render_circular_loop", side_effect=fake_render):
                        with mock.patch.object(qa, "_resolve_ffmpeg_path", return_value=Path(r"C:\ffmpeg\bin\ffmpeg.exe")):
                            with mock.patch.object(qa, "measure_loudness", side_effect=lambda _ffmpeg, _source: next(measure_values)):
                                with mock.patch.object(qa, "apply_constant_gain", side_effect=lambda _ffmpeg, source, output, _gain: shutil.copyfile(source, output)):
                                    with mock.patch.object(qa, "analyze_loop_edges", return_value={
                                        "path": "",
                                        "status": "pass",
                                        "frame_count": 180 * SAMPLE_RATE,
                                        "sample_rate": SAMPLE_RATE,
                                        "channels": 2,
                                        "bits_per_sample": 16,
                                        "repeat_count": 10,
                                        "silence_ratio": 0.01,
                                        "max_contiguous_silence_seconds": 0.0,
                                        "dc_offset": [0.0, 0.0],
                                        "peak_dbfs": -3.0,
                                        "seam": {"passes": True, "channels": []},
                                        "internal_join": {"passes": True, "channels": []},
                                        "wrap_transitions": [{"boundary_index": index + 1, "passes": True, "channels": []} for index in range(9)],
                                    }):
                                        with mock.patch.object(qa, "build_transition_preview", side_effect=fake_preview):
                                            with mock.patch.object(qa, "_analyze_repeat_structure", return_value={"possible_six_repeat_structure": False, "pairs": []}):
                                                report = master_and_analyze(catalog, staging_root, Path(r"C:\ffmpeg\bin\ffmpeg.exe"))

                    self.assertEqual(expected_status, report["tracks"][0]["status"])

    def test_detect_repeat_structure_warns_only_for_high_correlation_low_difference_pairs(self) -> None:
        self.require_api()
        base = [0.2 + (0.00005 * index) for index in range(3_000)]
        repeated = [value * 1.003 for value in base]
        distinct = [0.5 + (0.15 * math.sin(index / 17.0)) for index in range(3_000)]
        windows = [base, distinct, [0.4 for _ in range(3_000)], repeated, [0.05 + (0.02 * math.cos(index / 23.0)) for index in range(3_000)], [0.62 + (0.06 * math.sin(index / 11.0)) for index in range(3_000)]]

        warning = qa._detect_possible_six_repeat_structure(windows)

        self.assertTrue(warning["possible_six_repeat_structure"])
        self.assertEqual(1, len(warning["pairs"]))
        self.assertEqual(0, warning["pairs"][0]["left_start_seconds"])
        self.assertEqual(90, warning["pairs"][0]["right_start_seconds"])
        self.assertGreaterEqual(warning["pairs"][0]["correlation"], 0.985)
        self.assertLessEqual(warning["pairs"][0]["normalized_mean_difference"], 0.02)

    def test_build_longform_review_html_is_deterministic_escaped_and_catalog_ordered(self) -> None:
        self.require_api()
        catalog = make_catalog()
        report = {
            "expected_track_count": 2,
            "pass_count": 1,
            "fail_count": 1,
            "warning_count": 1,
            "tracks": [
                {
                    "track_key": "stage1_boss",
                    "status": "fail",
                    "title_zh": catalog["tracks"][1]["title_zh"],
                    "relative_master_path": "../bgm_longform/stage1_boss/bgm_stage1_boss_B_loop180_review.wav?x=1&y=2",
                    "relative_preview_path": "../bgm_longform/stage1_boss/bgm_stage1_boss_B_loop_transition.wav",
                    "integrated_lufs": -14.5,
                    "true_peak_dbtp": -1.3,
                    "possible_six_repeat_structure": False,
                    "repeat_pairs": [],
                    "errors": ["master loudness out of range <check>"],
                },
                {
                    "track_key": "stage1_mid",
                    "status": "pass",
                    "title_zh": catalog["tracks"][0]["title_zh"],
                    "relative_master_path": "../bgm_longform/stage1_mid/bgm_stage1_mid_B_loop180_review.wav?x=1&y=2",
                    "relative_preview_path": "../bgm_longform/stage1_mid/bgm_stage1_mid_B_loop_transition.wav",
                    "integrated_lufs": -16.0,
                    "true_peak_dbtp": -1.0,
                    "possible_six_repeat_structure": True,
                    "repeat_pairs": [{"left_start_seconds": 0, "right_start_seconds": 30, "correlation": 0.991, "normalized_mean_difference": 0.01}],
                    "errors": [],
                },
            ],
        }

        with tempfile.TemporaryDirectory() as temp_dir:
            output_a = Path(temp_dir) / "review_a.html"
            output_b = Path(temp_dir) / "review_b.html"
            build_longform_review_html(catalog, report, output_a)
            build_longform_review_html(catalog, copy.deepcopy(report), output_b)
            html_a = output_a.read_text(encoding="utf-8")
            html_b = output_b.read_text(encoding="utf-8")

        self.assertEqual(html_a, html_b)
        self.assertLess(html_a.index("灯火初参道 &lt;A&gt;"), html_a.index("祭坛决斗 &amp; 终幕"))
        self.assertIn("../bgm_longform/stage1_mid/bgm_stage1_mid_B_loop180_review.wav?x=1&amp;y=2", html_a)
        self.assertIn("Stage 1 道中", html_a)
        self.assertIn("Stage 1 Boss", html_a)
        self.assertIn("可能存在六段重复结构", html_a)
        self.assertNotIn("accept", html_a.lower())
        self.assertIn("<audio controls", html_a)

    def test_optional_ffmpeg_integration_parses_real_loudnorm_and_preserves_short_frames(self) -> None:
        self.require_api()
        ffmpeg_path = shutil.which("ffmpeg")
        if ffmpeg_path is None:
            self.skipTest("ffmpeg not available on PATH")

        with tempfile.TemporaryDirectory() as temp_dir:
            source_path = Path(temp_dir) / "real_input.wav"
            output_path = Path(temp_dir) / "real_output.wav"
            write_tone(source_path, 1.0, amplitude=0.2, frequency=330.0)

            measurement = measure_loudness(Path(ffmpeg_path), source_path)
            self.assertIn("integrated_lufs", measurement)
            self.assertIn("true_peak_dbtp", measurement)

            apply_constant_gain(Path(ffmpeg_path), source_path, output_path, 0.0)
            self.assertEqual(read_frame_count(source_path), read_frame_count(output_path))
            self.assertTrue(output_path.exists())


if __name__ == "__main__":
    unittest.main()
