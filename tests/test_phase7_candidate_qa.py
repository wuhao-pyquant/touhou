from __future__ import annotations

import json
import math
import struct
import sys
import tempfile
import unittest
import wave
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "audio"))

from phase7_candidate_qa import analyze_wave, build_review_html, run_qa


def write_tone(path: Path, seconds: float = 30.0, amplitude: float = 0.25) -> None:
    frames = int(44_100 * seconds)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(44_100)
        chunks = bytearray()
        for index in range(frames):
            value = int(32_767 * amplitude * math.sin(2.0 * math.pi * 440.0 * index / 44_100))
            chunks.extend(struct.pack("<hh", value, value))
        handle.writeframes(bytes(chunks))


def mini_catalog() -> dict:
    return {
        "schema_version": 1,
        "defaults": {
            "seconds": 30.0,
        },
        "tracks": [{
            "key": "stage1_mid",
            "stage": 1,
            "phase": "mid",
            "title_zh": "灯火初参道",
            "bpm": 150,
            "candidates": [
                {"variant": "B", "seed": 2026071102},
                {"variant": "A", "seed": 2026071101},
            ],
        }],
    }


class Phase7CandidateQaTests(unittest.TestCase):
    def test_tone_passes_candidate_qa(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "tone.wav"
            write_tone(path)
            report = analyze_wave(path, 30.0)
            self.assertEqual("pass", report["status"])
            self.assertLess(report["peak_dbfs"], 0.0)
            self.assertLess(report["silence_ratio"], 0.98)

    def test_silence_fails_candidate_qa(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "silence.wav"
            write_tone(path, amplitude=0.0)
            report = analyze_wave(path, 30.0)
            self.assertEqual("fail", report["status"])
            self.assertIn("silent", " ".join(report["errors"]))

    def test_empty_file_is_reported_as_unreadable_wav(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "empty.wav"
            path.write_bytes(b"")
            report = analyze_wave(path, 30.0)
            self.assertEqual("fail", report["status"])
            self.assertIn("unreadable WAV", report["errors"][0])

    def test_truncated_file_is_reported_as_unreadable_wav(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "truncated.wav"
            path.write_bytes(b"RIFF")
            report = analyze_wave(path, 30.0)
            self.assertEqual("fail", report["status"])
            self.assertIn("unreadable WAV", report["errors"][0])

    def test_review_page_contains_audio_controls_and_titles(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            output = Path(temp_dir) / "review.html"
            catalog = {
                "tracks": [{
                    "key": "stage1_mid",
                    "stage": 1,
                    "phase": "mid",
                    "title_zh": "灯火初参道",
                    "bpm": 150,
                }],
            }
            report = {"candidates": [{
                "track_key": "stage1_mid",
                "variant": "A",
                "status": "pass",
                "relative_audio_path": "../bgm_candidates/stage1_mid/test.wav",
                "peak_dbfs": -12.0,
                "silence_ratio": 0.01,
            }]}
            build_review_html(catalog, report, output)
            html = output.read_text(encoding="utf-8")
            self.assertIn("灯火初参道", html)
            self.assertIn("<audio controls", html)
            self.assertIn("test.wav", html)

    def test_run_qa_writes_json_and_deterministic_review_order(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            staging = Path(temp_dir)
            candidates_dir = staging / "bgm_candidates" / "stage1_mid"
            candidates_dir.mkdir(parents=True)
            write_tone(candidates_dir / "bgm_stage1_mid_A_seed-2026071101.wav")
            write_tone(candidates_dir / "bgm_stage1_mid_B_seed-2026071102.wav", amplitude=0.0)
            with mock.patch("phase7_candidate_qa.load_catalog", return_value=mini_catalog()):
                exit_code = run_qa(Path("unused.json"), staging)
            self.assertEqual(1, exit_code)
            qa_report = json.loads((staging / "reports" / "candidate_qa.json").read_text(encoding="utf-8"))
            self.assertEqual(2, qa_report["expected_candidate_count"])
            self.assertEqual(1, qa_report["pass_count"])
            self.assertEqual(1, qa_report["fail_count"])
            self.assertEqual(["B", "A"], [item["variant"] for item in qa_report["candidates"]])
            html = (staging / "reports" / "bgm_candidate_review.html").read_text(encoding="utf-8")
            self.assertLess(html.index("候选 A"), html.index("候选 B"))


if __name__ == "__main__":
    unittest.main()
