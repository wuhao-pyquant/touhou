from __future__ import annotations

import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock


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
        loaded = [BRIDGE._load_profile(path) for path in profiles]
        loaded_names = [profile["name"] for profile in loaded]
        self.assertEqual(len(loaded_names), len(set(loaded_names)))
        for profile in loaded:
            if profile["name"] == "deep_reviewer":
                self.assertEqual(profile.get("repair_escalations", []), [])
            else:
                self.assertGreaterEqual(len(profile.get("repair_escalations", [])), 1)

    def test_repair_identity_is_temporary_and_default_remains_unchanged(self) -> None:
        repo_root = Path(__file__).parents[3]
        profile = BRIDGE._load_profile(
            repo_root / ".codex" / "agents" / "content_runtime.toml"
        )
        default_before = BRIDGE._profile_identity(profile, 0)
        repair = BRIDGE._profile_identity(profile, 1)
        default_after = BRIDGE._profile_identity(profile, 0)
        self.assertEqual(
            default_before,
            {
                "model": "gpt-5.6-terra",
                "model_reasoning_effort": "high",
            },
        )
        self.assertEqual(
            repair,
            {"model": "gpt-5.6-sol", "model_reasoning_effort": "high"},
        )
        self.assertEqual(default_after, default_before)

    def test_profile_rejects_non_contiguous_repair_rounds(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            profile_path = Path(temporary) / "worker.toml"
            profile_path.write_text(
                """name = "worker"
description = "probe"
model = "gpt-5.6-terra"
model_reasoning_effort = "medium"
sandbox_mode = "workspace-write"
developer_instructions = "bounded"

[[repair_escalations]]
round = 2
model = "gpt-5.6-sol"
model_reasoning_effort = "high"
""",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(BRIDGE.BridgeError, "contiguous"):
                BRIDGE._load_profile(profile_path)

    def test_repair_round_must_be_next_and_within_ticket_limit(self) -> None:
        repo_root = Path(__file__).parents[3]
        profile = BRIDGE._load_profile(
            repo_root / ".codex" / "agents" / "build_release.toml"
        )
        ticket = {"max_repair_rounds": 1}
        self.assertEqual(
            BRIDGE._repair_identity(
                profile, ticket, prior_round=0, escalation_level=1
            ),
            {"model": "gpt-5.6-sol", "model_reasoning_effort": "high"},
        )
        with self.assertRaisesRegex(BRIDGE.BridgeError, "next contiguous"):
            BRIDGE._repair_identity(
                profile, ticket, prior_round=0, escalation_level=2
            )
        with self.assertRaisesRegex(BRIDGE.BridgeError, "permits 0"):
            BRIDGE._repair_identity(
                profile,
                {"max_repair_rounds": 0},
                prior_round=0,
                escalation_level=1,
            )

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

    def test_resume_command_uses_resume_contract_without_fresh_only_flags(self) -> None:
        command = BRIDGE._build_resume_command(
            "codex",
            thread_id="019f0000-0000-7000-8000-000000000000",
            identity={
                "model": "gpt-5.6-sol",
                "model_reasoning_effort": "xhigh",
            },
            report_schema=Path("report.schema.json"),
            final_path=Path("final.json"),
        )
        self.assertEqual(command[:3], ["codex", "exec", "resume"])
        self.assertNotIn("-C", command)
        self.assertNotIn("-s", command)
        self.assertIn("gpt-5.6-sol", command)
        self.assertIn('model_reasoning_effort="xhigh"', command)
        self.assertEqual(command[-2:], ["019f0000-0000-7000-8000-000000000000", "-"])

    def test_resume_identity_is_read_from_only_the_appended_turn(self) -> None:
        thread_id = "019f0000-0000-7000-8000-000000000001"
        with tempfile.TemporaryDirectory() as temporary:
            codex_home = Path(temporary)
            session_dir = codex_home / "sessions" / "2026" / "07" / "14"
            session_dir.mkdir(parents=True)
            session_file = session_dir / f"rollout-{thread_id}.jsonl"
            initial_entries = [
                {
                    "type": "session_meta",
                    "payload": {"cli_version": "0.144.4"},
                },
                {
                    "type": "turn_context",
                    "payload": {
                        "model": "gpt-5.6-terra",
                        "model_reasoning_effort": "medium",
                    },
                },
            ]
            session_file.write_text(
                "".join(json.dumps(entry) + "\n" for entry in initial_entries),
                encoding="utf-8",
            )
            with mock.patch.dict(os.environ, {"CODEX_HOME": str(codex_home)}):
                snapshot = BRIDGE._session_snapshot(thread_id)
                missing = BRIDGE._session_identity(
                    thread_id,
                    previous_snapshot=snapshot,
                    require_new_turn=True,
                )
                self.assertFalse(missing["verified"])
                with session_file.open("a", encoding="utf-8") as stream:
                    stream.write(
                        json.dumps(
                            {
                                "type": "turn_context",
                                "payload": {
                                    "model": "gpt-5.6-sol",
                                    "model_reasoning_effort": "high",
                                },
                            }
                        )
                        + "\n"
                    )
                resumed = BRIDGE._session_identity(
                    thread_id,
                    previous_snapshot=snapshot,
                    require_new_turn=True,
                )
        self.assertTrue(resumed["verified"])
        self.assertTrue(resumed["new_turn_verified"])
        self.assertEqual(resumed["model"], "gpt-5.6-sol")
        self.assertEqual(resumed["model_reasoning_effort"], "high")


if __name__ == "__main__":
    unittest.main()
