from __future__ import annotations

import copy
import hashlib
import math
import sys
import tempfile
import unittest
import wave
from array import array
from pathlib import Path
from typing import Callable
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "audio"))

try:
    from phase7_longform_audio import (
        WaveData,
        analyze_loop_edges,
        build_macro_guide,
        build_transition_preview,
        read_pcm16_wave,
        render_circular_loop,
        write_pcm16_wave,
    )
    MODULE_IMPORT_ERROR = None
except Exception as exc:  # pragma: no cover - exercised during RED before implementation
    WaveData = None
    analyze_loop_edges = None
    build_macro_guide = None
    build_transition_preview = None
    read_pcm16_wave = None
    render_circular_loop = None
    write_pcm16_wave = None
    MODULE_IMPORT_ERROR = exc


SAMPLE_RATE = 44_100
CHANNELS = 2
BITS_PER_SAMPLE = 16
CANDIDATE_SECONDS = 30.0
GUIDE_SECONDS = 188.0
MASTER_SECONDS = 180.0
GUIDE_FRAMES = int(round(GUIDE_SECONDS * SAMPLE_RATE))
MASTER_FRAMES = int(round(MASTER_SECONDS * SAMPLE_RATE))
PREVIEW_FRAMES = int(round(30.0 * SAMPLE_RATE))
CROSSFADE_SECONDS = 8.0
CROSSFADE_FRAMES = int(round(CROSSFADE_SECONDS * SAMPLE_RATE))
GUIDE_CROSSFADE_SECONDS = 1.0
GUIDE_CROSSFADE_FRAMES = int(round(GUIDE_CROSSFADE_SECONDS * SAMPLE_RATE))
SECTION_STARTS_SECONDS = [0.0, 30.0, 60.0, 90.0, 120.0, 158.0]
SECTION_STARTS_FRAMES = [int(round(seconds * SAMPLE_RATE)) for seconds in SECTION_STARTS_SECONDS]
SECTION_NOMINAL_SECONDS = [31.0, 31.0, 31.0, 31.0, 39.0, 30.0]
SECTION_NOMINAL_FRAMES = [int(round(seconds * SAMPLE_RATE)) for seconds in SECTION_NOMINAL_SECONDS]
SECTION_EFFECTIVE_SECONDS = [30.0, 30.0, 30.0, 30.0, 38.0, 30.0]
SECTION_EFFECTIVE_FRAMES = [int(round(seconds * SAMPLE_RATE)) for seconds in SECTION_EFFECTIVE_SECONDS]
SECTION_ROTATIONS_SECONDS = [0.0, 5.0, 10.0, 15.0, 20.0, 0.0]
SECTION_ROTATION_FRAMES = [int(round(seconds * SAMPLE_RATE)) for seconds in SECTION_ROTATIONS_SECONDS]
CANDIDATE_FRAMES = int(round(CANDIDATE_SECONDS * SAMPLE_RATE))
INT16_MIN = -32_768
INT16_MAX = 32_767
def clamp_pcm16(value: float) -> int:
    integer = int(round(value))
    if integer < INT16_MIN:
        return INT16_MIN
    if integer > INT16_MAX:
        return INT16_MAX
    return integer


def candidate_sample(frame_index: int, channel: int) -> int:
    time_seconds = frame_index / SAMPLE_RATE
    base = (
        0.12 * math.sin((2.0 * math.pi * ((2.0 + channel) / 30.0) * time_seconds) + (0.23 * (channel + 1)))
        + 0.08 * math.sin((2.0 * math.pi * ((4.0 + channel) / 30.0) * time_seconds) + (0.41 * (channel + 1)))
    )
    low = 0.16 * math.sin((2.0 * math.pi * (2.7 + (0.3 * channel)) * time_seconds) + (0.2 * channel))
    mid = 0.06 * math.sin((2.0 * math.pi * (11.0 + (0.5 * channel)) * time_seconds) + (0.35 * (channel + 1)))
    high = 0.035 * math.sin((2.0 * math.pi * (1_800.0 + (200.0 * channel)) * time_seconds) + (0.13 * (channel + 1)))
    return clamp_pcm16((base + low + mid + high) * INT16_MAX)


def source_sample(frame_index: int, channel: int) -> int:
    time_seconds = frame_index / SAMPLE_RATE
    phase = 0.37 * (channel + 1)
    value = (
        0.24 * math.sin((2.0 * math.pi * 0.41 * time_seconds) + phase)
        + 0.11 * math.sin((2.0 * math.pi * 3.3 * time_seconds) + (0.8 * phase))
        + 0.05 * math.sin((2.0 * math.pi * 221.0 * time_seconds) + (1.1 * phase))
        + 0.03 * math.sin((2.0 * math.pi * 601.0 * time_seconds) + (1.6 * phase))
    )
    return clamp_pcm16(value * INT16_MAX)


def guide_gain_for_section(section_index: int, local_frame_index: int) -> float:
    frame_count = SECTION_NOMINAL_FRAMES[section_index]
    if section_index == 0:
        return 1.0
    if section_index == 1:
        return 0.95
    if section_index == 2:
        return 0.72
    if section_index == 3:
        if frame_count <= 1:
            return 1.0
        return 0.82 + ((1.0 - 0.82) * (local_frame_index / (frame_count - 1)))
    if section_index == 4:
        return 1.0
    if frame_count <= 1:
        return 1.0
    return 0.95 + ((1.0 - 0.95) * (local_frame_index / (frame_count - 1)))


def expected_unfiltered_guide_sample(section_index: int, local_frame_index: int, channel: int) -> int:
    source_frame_index = (SECTION_ROTATION_FRAMES[section_index] + local_frame_index) % CANDIDATE_FRAMES
    return clamp_pcm16(candidate_sample(source_frame_index, channel) * guide_gain_for_section(section_index, local_frame_index))


def adjacent_diff_metric(values: array) -> float:
    if len(values) <= CHANNELS:
        return 0.0
    deltas = 0
    comparisons = 0
    frame_count = len(values) // CHANNELS
    for frame_index in range(frame_count - 1):
        base = frame_index * CHANNELS
        next_base = base + CHANNELS
        for channel in range(CHANNELS):
            deltas += abs(values[next_base + channel] - values[base + channel])
            comparisons += 1
    return (deltas / comparisons) / 32_768.0


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_generated_wave(path: Path, frame_count: int, sample_function: Callable[[int, int], int], *, sample_rate: int = SAMPLE_RATE, channels: int = CHANNELS, sample_width: int = 2) -> None:
    chunk_frames = 16_384
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(channels)
        handle.setsampwidth(sample_width)
        handle.setframerate(sample_rate)
        for frame_start in range(0, frame_count, chunk_frames):
            frame_stop = min(frame_count, frame_start + chunk_frames)
            samples = array("h")
            for frame_index in range(frame_start, frame_stop):
                for channel in range(channels):
                    samples.append(sample_function(frame_index, channel))
            handle.writeframes(samples.tobytes())


def frame_slice(interleaved: array, frame_start: int, frame_count: int) -> array:
    sample_start = frame_start * CHANNELS
    sample_stop = (frame_start + frame_count) * CHANNELS
    return interleaved[sample_start:sample_stop]


class Phase7LongformAudioTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.temp_dir = tempfile.TemporaryDirectory()
        cls.temp_root = Path(cls.temp_dir.name)
        cls.candidate_path = cls.temp_root / "candidate30.wav"
        cls.source_path = cls.temp_root / "source188.wav"
        cls.bad_master_path = cls.temp_root / "bad_master180.wav"
        write_generated_wave(cls.candidate_path, CANDIDATE_FRAMES, candidate_sample)
        write_generated_wave(cls.source_path, GUIDE_FRAMES, source_sample)
        write_generated_wave(
            cls.bad_master_path,
            MASTER_FRAMES,
            lambda frame_index, channel: -16_000 if frame_index < CROSSFADE_FRAMES else 16_000,
        )

    @classmethod
    def tearDownClass(cls) -> None:
        cls.temp_dir.cleanup()

    def require_audio_api(self) -> None:
        if MODULE_IMPORT_ERROR is not None:
            self.fail(f"phase7_longform_audio import failed: {MODULE_IMPORT_ERROR}")
        self.assertTrue(callable(read_pcm16_wave), "read_pcm16_wave must be callable")
        self.assertTrue(callable(write_pcm16_wave), "write_pcm16_wave must be callable")
        self.assertTrue(callable(build_macro_guide), "build_macro_guide must be callable")
        self.assertTrue(callable(render_circular_loop), "render_circular_loop must be callable")
        self.assertTrue(callable(build_transition_preview), "build_transition_preview must be callable")
        self.assertTrue(callable(analyze_loop_edges), "analyze_loop_edges must be callable")
        self.assertIsNotNone(WaveData, "WaveData must be defined")

    def build_guide(self, output_name: str = "guide188.wav") -> tuple[dict, Path]:
        self.require_audio_api()
        output_path = self.temp_root / output_name
        report = build_macro_guide(self.candidate_path, output_path, GUIDE_SECONDS, GUIDE_CROSSFADE_SECONDS)
        self.assertTrue(output_path.exists(), f"guide output missing: {output_path}")
        return report, output_path

    def build_master(self, output_name: str = "loop180.wav") -> tuple[dict, Path]:
        self.require_audio_api()
        output_path = self.temp_root / output_name
        report = render_circular_loop(self.source_path, output_path, GUIDE_SECONDS, MASTER_SECONDS, CROSSFADE_SECONDS)
        self.assertTrue(output_path.exists(), f"master output missing: {output_path}")
        return report, output_path

    def test_api_is_available(self) -> None:
        self.require_audio_api()

    def test_read_write_roundtrip_preserves_pcm16_stereo_frames(self) -> None:
        self.require_audio_api()
        original = read_pcm16_wave(self.candidate_path)
        roundtrip_path = self.temp_root / "roundtrip.wav"
        write_pcm16_wave(roundtrip_path, original)
        reread = read_pcm16_wave(roundtrip_path)

        self.assertEqual(SAMPLE_RATE, original.sample_rate)
        self.assertEqual(CHANNELS, original.channels)
        self.assertEqual(BITS_PER_SAMPLE, original.bits_per_sample)
        self.assertEqual(CANDIDATE_FRAMES, original.frame_count)
        self.assertIsInstance(original.samples, array)
        self.assertEqual(original.samples, reread.samples)

    def test_build_macro_guide_has_exact_length_section_map_and_deterministic_bytes(self) -> None:
        report_a, path_a = self.build_guide("guide_a.wav")
        report_b, path_b = self.build_guide("guide_b.wav")

        self.assertEqual(GUIDE_FRAMES, report_a["frame_count"])
        self.assertEqual(SAMPLE_RATE, report_a["sample_rate"])
        self.assertEqual(CHANNELS, report_a["channels"])
        self.assertEqual(BITS_PER_SAMPLE, report_a["bits_per_sample"])
        self.assertEqual(SECTION_STARTS_SECONDS, report_a["section_starts_seconds"])
        self.assertEqual(SECTION_ROTATIONS_SECONDS, report_a["section_rotation_seconds"])
        self.assertEqual(SECTION_NOMINAL_SECONDS, report_a["section_nominal_seconds"])
        self.assertEqual(sha256_file(path_a), sha256_file(path_b))

        report_copy = copy.deepcopy(report_a)
        report_copy["path"] = report_b["path"]
        self.assertEqual(report_copy, report_b)

        guide_data = read_pcm16_wave(path_a)
        self.assertEqual(GUIDE_FRAMES, guide_data.frame_count)

    def test_build_macro_guide_uses_rotations_gain_shapes_and_breathing_filter(self) -> None:
        _, guide_path = self.build_guide("guide_sections.wav")
        guide_data = read_pcm16_wave(guide_path)

        probes = [
            (0, 5.0),
            (1, 35.0),
            (3, 100.0),
            (4, 130.0),
            (5, 170.0),
        ]
        for section_index, seconds in probes:
            with self.subTest(section_index=section_index, seconds=seconds):
                start_frame = int(round(seconds * SAMPLE_RATE))
                actual = frame_slice(guide_data.samples, start_frame, 256)
                expected = array("h")
                local_start = start_frame - SECTION_STARTS_FRAMES[section_index]
                for local_frame_index in range(local_start, local_start + 256):
                    for channel in range(CHANNELS):
                        expected.append(expected_unfiltered_guide_sample(section_index, local_frame_index, channel))
                self.assertEqual(expected, actual)

        breathing_probe_frame = int(round(75.0 * SAMPLE_RATE))
        breathing_actual = frame_slice(guide_data.samples, breathing_probe_frame, 2_048)
        breathing_expected_unfiltered = array("h")
        local_start = breathing_probe_frame - SECTION_STARTS_FRAMES[2]
        for local_frame_index in range(local_start, local_start + 2_048):
            for channel in range(CHANNELS):
                breathing_expected_unfiltered.append(expected_unfiltered_guide_sample(2, local_frame_index, channel))
        self.assertLess(adjacent_diff_metric(breathing_actual), adjacent_diff_metric(breathing_expected_unfiltered) * 0.8)

    def test_build_macro_guide_smooths_section_joins_without_hard_clicks(self) -> None:
        _, guide_path = self.build_guide("guide_joins.wav")
        guide_data = read_pcm16_wave(guide_path)

        for section_index, boundary_frame in enumerate(SECTION_STARTS_FRAMES[1:], start=1):
            with self.subTest(boundary_seconds=boundary_frame / SAMPLE_RATE):
                actual_jump = 0.0
                previous_frame = frame_slice(guide_data.samples, boundary_frame - 1, 1)
                next_frame = frame_slice(guide_data.samples, boundary_frame, 1)
                for channel in range(CHANNELS):
                    actual_jump = max(actual_jump, abs(next_frame[channel] - previous_frame[channel]) / 32_768.0)

                previous_section_index = section_index - 1
                previous_local_frame = SECTION_EFFECTIVE_FRAMES[previous_section_index] - 1
                next_local_frame = 0
                raw_jump = 0.0
                for channel in range(CHANNELS):
                    raw_previous = expected_unfiltered_guide_sample(previous_section_index, previous_local_frame, channel)
                    raw_next = expected_unfiltered_guide_sample(section_index, next_local_frame, channel)
                    raw_jump = max(raw_jump, abs(raw_next - raw_previous) / 32_768.0)
                self.assertLess(actual_jump, raw_jump * 0.65)
                self.assertLess(actual_jump, 0.2)

    def test_render_circular_loop_has_exact_length_crossfade_orientation_and_internal_join(self) -> None:
        report, master_path = self.build_master("loop_orientation.wav")
        self.assertEqual(MASTER_FRAMES, report["frame_count"])
        self.assertEqual(CROSSFADE_FRAMES, report["crossfade_frames"])

        source_data = read_pcm16_wave(self.source_path)
        master_data = read_pcm16_wave(master_path)
        self.assertEqual(MASTER_FRAMES, master_data.frame_count)

        first_master_frame = frame_slice(master_data.samples, 0, 1)
        tail_start_frame = frame_slice(source_data.samples, int(round(180.0 * SAMPLE_RATE)), 1)
        self.assertEqual(tail_start_frame, first_master_frame)

        last_crossfade_frame = frame_slice(master_data.samples, CROSSFADE_FRAMES - 1, 1)
        head_last_frame = frame_slice(source_data.samples, CROSSFADE_FRAMES - 1, 1)
        self.assertEqual(head_last_frame, last_crossfade_frame)

        first_body_frame = frame_slice(master_data.samples, CROSSFADE_FRAMES, 1)
        source_body_frame = frame_slice(source_data.samples, CROSSFADE_FRAMES, 1)
        self.assertEqual(source_body_frame, first_body_frame)

        blend_midpoint = CROSSFADE_FRAMES // 2
        tail_mid = frame_slice(source_data.samples, int(round(180.0 * SAMPLE_RATE)) + blend_midpoint, 1)
        head_mid = frame_slice(source_data.samples, blend_midpoint, 1)
        expected_mid = array("h")
        angle = (math.pi / 2.0) * (blend_midpoint / (CROSSFADE_FRAMES - 1))
        tail_gain = math.cos(angle)
        head_gain = math.sin(angle)
        for channel in range(CHANNELS):
            expected_mid.append(clamp_pcm16((tail_mid[channel] * tail_gain) + (head_mid[channel] * head_gain)))
        self.assertEqual(expected_mid, frame_slice(master_data.samples, blend_midpoint, 1))

    def test_analyze_loop_edges_reports_passing_actual_seam_internal_join_and_nine_wraps(self) -> None:
        _, master_path = self.build_master("loop_metrics.wav")
        analysis = analyze_loop_edges(master_path, repeat_count=10)

        self.assertEqual("pass", analysis["status"])
        self.assertEqual(MASTER_FRAMES, analysis["frame_count"])
        self.assertEqual(10, analysis["repeat_count"])
        self.assertEqual(9, len(analysis["wrap_transitions"]))
        self.assertTrue(analysis["seam"]["passes"])
        self.assertTrue(analysis["internal_join"]["passes"])
        self.assertTrue(all(item["passes"] for item in analysis["wrap_transitions"]))

        for key in ("seam", "internal_join"):
            for channel_report in analysis[key]["channels"]:
                self.assertLessEqual(channel_report["join_jump"], channel_report["join_jump_limit"] + 1e-12)
                self.assertLessEqual(channel_report["rms_delta_db"], 3.0 + 1e-12)

    def test_analyze_loop_edges_fails_large_jumps_against_thresholds(self) -> None:
        self.require_audio_api()
        analysis = analyze_loop_edges(self.bad_master_path, repeat_count=10)
        self.assertEqual("fail", analysis["status"])
        self.assertFalse(analysis["seam"]["passes"])
        self.assertFalse(analysis["internal_join"]["passes"])
        self.assertTrue(any(not item["passes"] for item in analysis["wrap_transitions"]))

    def test_build_transition_preview_uses_final_and_initial_windows_exactly(self) -> None:
        _, master_path = self.build_master("loop_preview_source.wav")
        preview_path = self.temp_root / "loop_transition.wav"
        preview_report = build_transition_preview(master_path, preview_path)
        self.assertEqual(PREVIEW_FRAMES, preview_report["frame_count"])
        self.assertEqual(15.0, preview_report["window_seconds"])

        master_data = read_pcm16_wave(master_path)
        preview_data = read_pcm16_wave(preview_path)
        self.assertEqual(PREVIEW_FRAMES, preview_data.frame_count)
        self.assertEqual(frame_slice(master_data.samples, MASTER_FRAMES - (15 * SAMPLE_RATE), 15 * SAMPLE_RATE), frame_slice(preview_data.samples, 0, 15 * SAMPLE_RATE))
        self.assertEqual(frame_slice(master_data.samples, 0, 15 * SAMPLE_RATE), frame_slice(preview_data.samples, 15 * SAMPLE_RATE, 15 * SAMPLE_RATE))

    def test_build_transition_preview_rejects_non_exact_window_arguments_before_reading_master(self) -> None:
        self.require_audio_api()
        preview_path = self.temp_root / "invalid_preview.wav"
        invalid_cases = [
            ("int", 15),
            ("different float", 10.0),
            ("bool", True),
            ("nan", float("nan")),
            ("inf", float("inf")),
            ("neg_inf", float("-inf")),
        ]
        for label, invalid_value in invalid_cases:
            with self.subTest(case=label):
                with mock.patch("phase7_longform_audio.read_pcm16_wave") as mocked_read:
                    with self.assertRaisesRegex(ValueError, r"window_seconds must be 15\.0"):
                        build_transition_preview(self.source_path, preview_path, invalid_value)
                    mocked_read.assert_not_called()

    def test_invalid_metadata_and_contract_values_raise_value_error(self) -> None:
        self.require_audio_api()
        mono_path = self.temp_root / "mono.wav"
        write_generated_wave(mono_path, CANDIDATE_FRAMES, lambda frame_index, channel: candidate_sample(frame_index, 0), channels=1)
        with self.assertRaisesRegex(ValueError, r"stereo"):
            read_pcm16_wave(mono_path)

        wrong_rate_path = self.temp_root / "wrong_rate.wav"
        write_generated_wave(wrong_rate_path, CANDIDATE_FRAMES, candidate_sample, sample_rate=48_000)
        with self.assertRaisesRegex(ValueError, r"44100"):
            build_macro_guide(wrong_rate_path, self.temp_root / "wrong_rate_out.wav", GUIDE_SECONDS, GUIDE_CROSSFADE_SECONDS)

        with self.assertRaisesRegex(ValueError, r"guide_crossfade_seconds must be 1\.0"):
            build_macro_guide(self.candidate_path, self.temp_root / "bad_guide.wav", GUIDE_SECONDS, 0.5)

        with self.assertRaisesRegex(ValueError, r"source_seconds must be 188\.0"):
            render_circular_loop(self.source_path, self.temp_root / "bad_loop.wav", 187.0, MASTER_SECONDS, CROSSFADE_SECONDS)

        with self.assertRaisesRegex(ValueError, r"crossfade_seconds must be 8\.0"):
            render_circular_loop(self.source_path, self.temp_root / "bad_loop.wav", GUIDE_SECONDS, MASTER_SECONDS, 4.0)

        short_master_path = self.temp_root / "short_master.wav"
        write_generated_wave(short_master_path, MASTER_FRAMES - 1, source_sample)
        with self.assertRaisesRegex(ValueError, r"exactly 180 seconds"):
            build_transition_preview(short_master_path, self.temp_root / "bad_preview.wav")

    def test_render_and_preview_are_deterministic(self) -> None:
        _, master_path_a = self.build_master("loop_a.wav")
        _, master_path_b = self.build_master("loop_b.wav")
        preview_path_a = self.temp_root / "preview_a.wav"
        preview_path_b = self.temp_root / "preview_b.wav"
        preview_report_a = build_transition_preview(master_path_a, preview_path_a)
        preview_report_b = build_transition_preview(master_path_b, preview_path_b)

        self.assertEqual(sha256_file(master_path_a), sha256_file(master_path_b))
        self.assertEqual(sha256_file(preview_path_a), sha256_file(preview_path_b))
        preview_report_copy = copy.deepcopy(preview_report_a)
        preview_report_copy["path"] = preview_report_b["path"]
        self.assertEqual(preview_report_copy, preview_report_b)


if __name__ == "__main__":
    unittest.main()
