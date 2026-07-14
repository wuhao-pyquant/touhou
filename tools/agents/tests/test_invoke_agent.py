from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "invoke_agent.py"
SPEC = importlib.util.spec_from_file_location("invoke_agent", MODULE_PATH)
assert SPEC and SPEC.loader
BRIDGE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BRIDGE)


class InvokeAgentTests(unittest.TestCase):
    def test_all_project_profiles_are_bridge_compatible(self) -> None:
        repo_root = Path(__file__).parents[3]
        profiles = sorted((repo_root / ".codex" / "agents").glob("*.toml"))
        self.assertGreaterEqual(len(profiles), 13)
        loaded_names = [BRIDGE._load_profile(path)["name"] for path in profiles]
        self.assertEqual(len(loaded_names), len(set(loaded_names)))

    def test_ticket_contract_accepts_complete_ticket(self) -> None:
        ticket = {
            "id": "B0-probe",
            "objective": "Read metadata only.",
            "mode": "read_only",
            "allowed_paths": [],
            "forbidden_paths": ["audio/**"],
            "dependency_commit": "HEAD",
            "acceptance_commands": [],
            "output_requirements": ["Report version."],
            "max_repair_rounds": 0,
        }
        BRIDGE._validate_ticket(ticket)

    def test_write_ticket_requires_allowed_paths(self) -> None:
        ticket = {
            "id": "write-probe",
            "objective": "Write one file.",
            "mode": "write",
            "allowed_paths": [],
            "forbidden_paths": [],
            "dependency_commit": "HEAD",
            "acceptance_commands": [],
            "output_requirements": [],
            "max_repair_rounds": 0,
        }
        with self.assertRaises(BRIDGE.BridgeError):
            BRIDGE._validate_ticket(ticket)

    def test_policy_checks_allowed_and_forbidden_globs(self) -> None:
        ticket = {
            "allowed_paths": ["docs/**", "tests/example.gd"],
            "forbidden_paths": ["audio/**"],
        }
        violations = BRIDGE._policy_violations(
            ticket,
            ["docs/result.md", "tests/example.gd", "audio/bgm/test.import", "main.gd"],
        )
        self.assertEqual(
            violations,
            [
                "forbidden path changed: audio/bgm/test.import",
                "path outside allowed_paths changed: main.gd",
            ],
        )

    def test_report_validation_rejects_incomplete_report(self) -> None:
        self.assertTrue(BRIDGE._validate_report({"status": "completed"}))

    def test_report_validation_accepts_expected_shape(self) -> None:
        report = {
            "status": "completed",
            "summary": "done",
            "changed_files": [],
            "commands": ["git status --short"],
            "tests": [{"name": "probe", "status": "passed", "evidence": "read-only"}],
            "failures": [],
            "residual_risks": [],
        }
        self.assertEqual(BRIDGE._validate_report(report), [])


if __name__ == "__main__":
    unittest.main()
