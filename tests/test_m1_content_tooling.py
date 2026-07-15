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

    def stage2_contract_fixture_rows(self, **header_changes):
        """Temporary contract fixture only; this is never M2 runtime evidence."""
        header = {
            "record_type": "m2_stage2_runtime_capture_header", "schema_version": 1,
            "evidence_kind": "real_runtime_capture", "source": "main_bullet_world", "build_kind": "release",
            "stage_id": "youkai_market", "simulation_hz": 60, "playfield": {"width": 720, "height": 960},
            "difficulty": "Normal", "run_seed": 20260715, "runtime_evidence": True,
            "execution_mode": "windowed", "headless": False,
        }
        header.update(header_changes)
        rows = [header]
        for tick, phase_id in enumerate(tool.STAGE2_PHASE_ORDER):
            rows.append({"record_type": "tick", "tick": tick, "simulation_time_s": tick / 60,
                         "phase_id": phase_id,
                         "bullets": [{"id": "bullet-%d" % tick, "x": float(tick * 10), "y": float(tick * 10)}]})
            rows.append({"record_type": "render_frame", "frame_index": tick, "tick": tick,
                         "present_time_s": tick / 60, "frame_time_ms": float((tick + 1) * 2)})
        rows.append({"record_type": "event", "event": "stage_started", "tick": 0, "time_s": 0.0})
        for tick, phase_id in enumerate(tool.STAGE2_PHASE_ORDER):
            for event in ("phase_gate_open", "phase_started", "phase_cleared"):
                rows.append({"record_type": "event", "event": event, "phase_id": phase_id,
                             "tick": tick, "time_s": tick / 60})
        rows.append({"record_type": "event", "event": "stage_cleared", "tick": 5, "time_s": 5 / 60})
        for tick, phase_id in enumerate(tool.STAGE2_PHASE_ORDER):
            rows.append({"record_type": "phase_ledger", "phase_id": phase_id, "start_tick": tick, "end_tick": tick,
                         "time_to_clear_ms": float((tick + 1) * 1000), "score_delta": (tick + 1) * 100,
                         "drop_count": tick, "capture_count": 1})
        rows.append({"record_type": "footer", "complete": True, "hard_error_count": 0, "overflow_count": 0,
                     "out_of_bounds_count": 0, "death_count": 0})
        return rows

    def read_stage2_contract_fixture(self, rows):
        # In-memory temporary contract fixture: it is never a runtime artifact.
        with mock.patch.object(tool, "_read_jsonl", return_value=rows):
            return tool.read_stage2_capture(Path("temporary-stage2-contract-fixture.jsonl"))

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

    def test_stage2_analyze_contract_fixture_writes_deterministic_artifacts(self):
        # This in-memory contract fixture validates v1 parsing/writing; it is not M2 runtime evidence.
        rows = self.stage2_contract_fixture_rows()
        header, ticks, renders, events, ledgers = self.read_stage2_contract_fixture(rows)
        summary, artifacts = tool.analyze_stage2_capture(header, ticks, renders, events, ledgers)
        self.assertEqual(summary["capture_identity"]["difficulty"], "normal")
        self.assertEqual(summary["sample_counts"], {"ticks": 6, "render_frames": 6})
        self.assertEqual(summary["whole_stage"]["peak_active_bullets"], 1)
        self.assertEqual(summary["render_frame_time_ms"],
                         {"percentile_method": "nearest_rank", "p50": 6.0, "p95": 12.0, "p99": 12.0})
        self.assertEqual([item["phase_id"] for item in summary["per_phase"]], list(tool.STAGE2_PHASE_ORDER))
        self.assertEqual(len(summary["event_order"]["gates"]), 6)
        self.assertEqual(len(summary["score_drop_capture_ledgers"]), 6)
        self.assertIn('width="720" height="960"', artifacts["whole_stage_heatmap.svg"])
        self.assertIn("polyline", artifacts["stage_2_boss_spell_3_active_bullets.svg"])
        self.assertEqual(tool._json(summary), tool._json(tool.analyze_stage2_capture(header, ticks, renders, events, ledgers)[0]))
        written = {}
        with mock.patch.object(tool, "_read_jsonl", return_value=rows), mock.patch.object(Path, "mkdir"), \
             mock.patch.object(tool, "_write", side_effect=lambda path, text: written.setdefault(path.name, text)):
            persisted = tool.stage2_analyze(Path("temporary-stage2-contract-fixture.jsonl"), Path("temporary-output"))
        self.assertEqual(persisted, summary)
        self.assertEqual(json.loads(written["summary.json"]), summary)
        self.assertEqual(set(written), set(summary["artifacts"]))

    def test_stage2_analyze_rejects_non_runtime_and_incomplete_contract_fixtures(self):
        # Negative temporary contract fixtures only; no fixture is M2 runtime evidence.
        mutations = [
            ("authored preview", lambda rows: rows[0].update({"evidence_kind": "authored_schedule_preview", "runtime_evidence": False})),
            ("synthetic", lambda rows: rows[0].update({"source": "synthetic"})),
            ("debug build", lambda rows: rows[0].update({"build_kind": "debug"})),
            ("headless claim", lambda rows: rows[0].update({"headless": True})),
            ("duplicate active id", lambda rows: rows[1]["bullets"].append({"id": "bullet-0", "x": 1.0, "y": 1.0})),
            ("nonfinite coordinate", lambda rows: rows[1]["bullets"][0].update({"x": float("inf")})),
            ("nonfinite frame time", lambda rows: rows[2].update({"frame_time_ms": float("inf")})),
            ("missing frame", lambda rows: rows.pop(2)),
            ("hard error counter", lambda rows: rows[-1].update({"hard_error_count": 1})),
            ("overflow counter", lambda rows: rows[-1].update({"overflow_count": 1})),
            ("out of bounds counter", lambda rows: rows[-1].update({"out_of_bounds_count": 1})),
            ("death counter", lambda rows: rows[-1].update({"death_count": 1})),
            ("ledger order", lambda rows: rows[-7].update({"phase_id": "stage_2_boss_spell_3"})),
        ]
        for _label, mutate in mutations:
            rows = self.stage2_contract_fixture_rows()
            mutate(rows)
            with self.assertRaises(tool.ToolError):
                self.read_stage2_contract_fixture(rows)
        # A non-JSONL, non-header input must make the stage2 CLI return nonzero.
        completed = self.run_tool("stage2-analyze", "--capture", CARDS, "--output-dir", ROOT / "not-written", expected=2)
        self.assertIn("m1_content_tool:", completed.stderr)


if __name__ == "__main__":
    unittest.main()
