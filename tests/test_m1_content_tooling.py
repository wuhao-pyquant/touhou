import hashlib
import importlib.util
import json
import subprocess
import sys
import unittest
from unittest import mock
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "content" / "m1_content_tool.py"
CARDS = ROOT / "content" / "design" / "m1_phase_cards.json"
SPEC = importlib.util.spec_from_file_location("m1_content_tool", TOOL)
tool = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
sys.modules[SPEC.name] = tool
SPEC.loader.exec_module(tool)


class M1ContentToolingTests(unittest.TestCase):
    def run_tool(self, *arguments, expected=0):
        completed = subprocess.run([sys.executable, str(TOOL), *map(str, arguments)], cwd=ROOT,
                                 text=True, capture_output=True, check=False)
        self.assertEqual(completed.returncode, expected, completed.stderr)
        return completed

    def trace_rows(self, *, source="runtime_capture", strict=False, frames=None, **header_changes):
        content_hash = hashlib.sha256(CARDS.read_bytes()).hexdigest()
        phase_seed = tool.phase_local_seed(20260715, "danmaku.m1.s2.midboss.nonspell.1.v1")
        header = {"record_type": "m1_runtime_trace_header", "schema_version": 1, "source": source,
                  "phase_id": "stage_2_midboss_nonspell_1", "difficulty": "hard", "run_seed": 20260715,
                  "phase_local_seed": phase_seed, "content_sha256": content_hash, "simulation_hz": 60,
                  "playfield": {"width": 720, "height": 960}, "strict_bounds": strict}
        header.update(header_changes)
        frames = frames or [
            {"record_type": "frame", "frame": 0, "frame_time_ms": 3.0, "bullets": [{"id": "a", "x": 0, "y": 0}]},
            {"record_type": "frame", "frame": 1, "frame_time_ms": 5.0, "bullets": [{"id": "a", "x": 60, "y": 60}, {"id": "b", "x": 719, "y": 959}]},
            {"record_type": "frame", "frame": 2, "frame_time_ms": 7.0, "bullets": []},
        ]
        return header, frames

    def read_rows(self, header, frames):
        cards, content_hash = tool._load_cards(CARDS)
        with mock.patch.object(tool, "_read_jsonl", return_value=[header, *frames]):
            return tool.read_trace(Path("in-memory.jsonl"), cards, content_hash)

    def test_fingerprints_and_authored_preview_are_deterministic(self):
        report = json.loads(self.run_tool("fingerprints", "--cards", CARDS).stdout)
        self.assertEqual((report["phase_count"], report["spell_count"], report["nonspell_count"], report["unique_fingerprint_count"], report["drift_count"]), (40, 26, 14, 40, 0))
        preview = json.loads(self.run_tool("sandbox", "--cards", CARDS, "--phase-id", "stage_2_midboss_nonspell_1",
                                           "--difficulty", "hard", "--run-seed", "20260715", "--seek-frame", "324").stdout)
        self.assertEqual(preview["evidence_kind"], "authored_schedule_preview")
        self.assertFalse(preview["runtime_evidence"])
        self.assertNotIn("bullets", preview)
        self.assertGreater(preview["phase_local_seed"], 0)

    def test_runtime_trace_seek_and_analysis(self):
        header, rows = self.trace_rows()
        trace_header, frames = self.read_rows(header, rows)
        seek = tool.trace_seek(trace_header, frames, 1)
        self.assertTrue(seek["sequential_equals_direct"])
        result, svg = tool.analyze(trace_header, frames, 0, 2, 12, 16)
        self.assertTrue(result["runtime_evidence"])
        self.assertEqual(result["peak_active_bullets"], 2)
        self.assertEqual(result["frame_time_ms"], {"percentile_method": "nearest_rank", "p50": 5.0, "p95": 7.0, "p99": 7.0})
        self.assertIn('width="720" height="960"', svg)

    def test_trace_contract_rejects_invalid_input_with_nonzero_exit(self):
        cases = [
            ([{"record_type": "frame", "frame": 0, "frame_time_ms": 1, "bullets": [{"id": "a", "x": 1, "y": 1}, {"id": "a", "x": 2, "y": 2}]}], {}, "duplicate bullet"),
            ([{"record_type": "frame", "frame": 0, "frame_time_ms": 1, "bullets": []}, {"record_type": "frame", "frame": 2, "frame_time_ms": 1, "bullets": []}], {}, "duplicate frame"),
            ([{"record_type": "frame", "frame": 0, "frame_time_ms": 1, "bullets": [{"id": "a", "x": 720, "y": 1}]}], {"strict": True}, "strict bounds"),
        ]
        for frames, options, _label in cases:
            header, rows = self.trace_rows(frames=frames, **options)
            with self.assertRaises(tool.ToolError):
                self.read_rows(header, rows)
        # Existing JSON cards are not JSONL trace records, so the CLI must return nonzero.
        completed = self.run_tool("trace-seek", "--cards", CARDS, "--trace", CARDS, "--seek-frame", "0", expected=2)
        self.assertIn("m1_content_tool:", completed.stderr)
        header, rows = self.trace_rows(content_sha256="bad")
        with self.assertRaises(tool.ToolError):
            self.read_rows(header, rows)

    def test_synthetic_trace_cannot_claim_runtime_evidence_and_oob_is_not_clamped(self):
        frames = [{"record_type": "frame", "frame": 0, "frame_time_ms": 1, "bullets": [{"id": "edge", "x": -1, "y": 1}, {"id": "ok", "x": 1, "y": 1}]}]
        header, rows = self.trace_rows(source="synthetic", frames=frames)
        trace_header, normalized = self.read_rows(header, rows)
        result, _svg = tool.analyze(trace_header, normalized, 0, 0, 12, 16)
        self.assertFalse(result["runtime_evidence"])
        self.assertEqual(result["out_of_bounds_bullet_samples"], 1)
        self.assertEqual(sum(map(sum, result["heatmap"]["occupancy"])), 1)


if __name__ == "__main__":
    unittest.main()
