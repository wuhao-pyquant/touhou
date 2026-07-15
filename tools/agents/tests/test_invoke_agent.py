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

    def test_transport_retry_prompt_keeps_route_and_is_not_a_repair(self) -> None:
        prompt = BRIDGE._build_transport_retry_prompt(
            {"name": "deep_reviewer"},
            {
                "id": "M1-review",
                "objective": "Freeze one architecture.",
                "allowed_paths": [],
                "forbidden_paths": ["audio/**"],
            },
            parent_run_id="prior-run",
        )
        self.assertIn("transport retry, not a repair round", prompt)
        self.assertIn("same agent", prompt)
        self.assertNotIn("temporarily overridden", prompt)

    def test_review_repair_report_must_be_read_only_gate_repair_evidence(self) -> None:
        report = {
            "status": "completed",
            "summary": "GATE: REPAIR - zero Godot launches.",
            "changed_files": [],
            "commands": ["git diff --check"],
            "tests": [
                {
                    "name": "static review",
                    "status": "passed",
                    "evidence": "read-only",
                }
            ],
            "failures": ["one bounded blocker"],
            "residual_risks": [],
        }
        self.assertEqual(
            BRIDGE._validate_review_repair_report(
                report, reviewer_agent="danmaku_director"
            ),
            "review_repair",
        )
        self.assertEqual(
            BRIDGE._validate_review_repair_report(
                {
                    **report,
                    "summary": (
                        "Read-only review completed.\n"
                        "The prior report mentioned GATE: APPROVE inline.\n\n"
                        "GATE: REPAIR\n"
                    ),
                },
                reviewer_agent="danmaku_director",
            ),
            "review_repair",
        )
        with self.assertRaisesRegex(BRIDGE.BridgeError, "GATE: REPAIR"):
            BRIDGE._validate_review_repair_report(
                {**report, "summary": "GATE: APPROVE"},
                reviewer_agent="danmaku_director",
            )
        with self.assertRaisesRegex(BRIDGE.BridgeError, "exactly one standalone"):
            BRIDGE._validate_review_repair_report(
                {
                    **report,
                    "summary": "GATE: REPAIR\nDetails.\nGATE: REPAIR",
                },
                reviewer_agent="danmaku_director",
            )
        with self.assertRaisesRegex(BRIDGE.BridgeError, "exactly one standalone"):
            BRIDGE._validate_review_repair_report(
                {
                    **report,
                    "summary": "The review found an inline GATE: REPAIR blocker.",
                },
                reviewer_agent="danmaku_director",
            )
        with self.assertRaisesRegex(BRIDGE.BridgeError, "zero changed files"):
            BRIDGE._validate_review_repair_report(
                {**report, "changed_files": ["reviewer-edit.txt"]},
                reviewer_agent="danmaku_director",
            )
        deep_report = {**report, "summary": "GATE: REPAIR_AUTHORIZED"}
        self.assertEqual(
            BRIDGE._validate_review_repair_report(
                deep_report, reviewer_agent="deep_reviewer"
            ),
            "deep_review_repair",
        )
        self.assertEqual(
            BRIDGE._validate_review_repair_report(
                {
                    **deep_report,
                    "summary": "Deep review completed.\nGATE: REPAIR_AUTHORIZED",
                },
                reviewer_agent="deep_reviewer",
            ),
            "deep_review_repair",
        )
        with self.assertRaisesRegex(BRIDGE.BridgeError, "Only deep_reviewer"):
            BRIDGE._validate_review_repair_report(
                deep_report, reviewer_agent="danmaku_director"
            )

    def test_deep_review_can_authorize_one_bounded_extra_repair_round(self) -> None:
        repo_root = Path(__file__).parents[3]
        profile = BRIDGE._load_profile(
            repo_root / ".codex" / "agents" / "core_simulation.toml"
        )
        ticket = {"max_repair_rounds": 1}
        with self.assertRaisesRegex(BRIDGE.BridgeError, "permits 1"):
            BRIDGE._repair_identity(
                profile, ticket, prior_round=1, escalation_level=2
            )
        self.assertEqual(
            BRIDGE._repair_identity(
                profile,
                ticket,
                prior_round=1,
                escalation_level=2,
                deep_review_authorized=True,
            ),
            {"model": "gpt-5.6-sol", "model_reasoning_effort": "xhigh"},
        )

    def test_validation_retry_options_are_one_time_directed_continuation(self) -> None:
        BRIDGE._validate_continuation_options(
            is_resume=True,
            escalation_level=None,
            transport_retry=False,
            validation_retry=True,
            repair_instruction="Type the one proven parse boundary.",
            review_failure_run=None,
        )
        with self.assertRaisesRegex(BRIDGE.BridgeError, "repair-instruction"):
            BRIDGE._validate_continuation_options(
                is_resume=True,
                escalation_level=None,
                transport_retry=False,
                validation_retry=True,
                repair_instruction="  ",
                review_failure_run=None,
            )
        with self.assertRaisesRegex(BRIDGE.BridgeError, "exactly one"):
            BRIDGE._validate_continuation_options(
                is_resume=True,
                escalation_level=2,
                transport_retry=False,
                validation_retry=True,
                repair_instruction="bounded",
                review_failure_run=None,
            )

    def test_root_continuations_ignore_dry_runs_and_cap_real_retry(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repo = Path(temporary)
            runs = repo / ".agent-runs"
            for run_id, dry_run, kind in (
                ("dry", True, "validation_retry"),
                ("real", False, "validation_retry"),
                ("repair", False, "repair"),
            ):
                run_dir = runs / run_id
                run_dir.mkdir(parents=True)
                BRIDGE._write_json(
                    run_dir / "invocation.json",
                    {
                        "root_run_id": "root",
                        "continuation_kind": kind,
                        "dry_run": dry_run,
                    },
                )
            self.assertEqual(
                BRIDGE._root_continuations(repo, "root", "validation_retry"),
                ["real"],
            )

    def test_validation_retry_reuses_round_two_identity_without_profile_drift(
        self,
    ) -> None:
        repo_root = Path(__file__).parents[3]
        profile = BRIDGE._load_profile(
            repo_root / ".codex" / "agents" / "core_simulation.toml"
        )
        default_before = BRIDGE._profile_identity(profile, 0)
        invocation = {
            "continuation_kind": "deep_review_repair",
            "repair_round": 2,
            "review_failure_run_id": "deep-review",
            "resume_head_commit": "a" * 40,
            "requested_model": "gpt-5.6-sol",
            "requested_model_reasoning_effort": "xhigh",
        }
        summary = {
            "status": "completed",
            "runtime": {
                "verified": True,
                "model": "gpt-5.6-sol",
                "model_reasoning_effort": "xhigh",
            },
            "policy_violations": [],
            "report_problems": [],
            "identity_problems": [],
        }
        with (
            mock.patch.object(
                BRIDGE,
                "_load_review_failure_context",
                return_value={
                    "authorization_kind": "deep_review_repair",
                    "candidate_commit": "a" * 40,
                    "run_id": "deep-review",
                    "run_dir": Path("deep-review"),
                    "summary": {},
                },
            ),
            mock.patch.object(BRIDGE, "_root_continuations", return_value=[]),
        ):
            authorization = BRIDGE._load_validation_retry_authorization(
                repo_root,
                implementation_agent="core_simulation",
                resume_run="round-two",
                invocation=invocation,
                summary=summary,
                base_commit="b" * 40,
                profile=profile,
                root_run_id="root",
            )
        self.assertEqual(authorization["repair_round"], 2)
        self.assertEqual(authorization["requested_identity"], default_before)
        self.assertEqual(BRIDGE._profile_identity(profile, 0), default_before)

    def test_validation_retry_rejects_a_second_real_lineage_retry(self) -> None:
        repo_root = Path(__file__).parents[3]
        profile = BRIDGE._load_profile(
            repo_root / ".codex" / "agents" / "core_simulation.toml"
        )
        invocation = {
            "continuation_kind": "deep_review_repair",
            "repair_round": 2,
            "review_failure_run_id": "deep-review",
            "resume_head_commit": "a" * 40,
            "requested_model": "gpt-5.6-sol",
            "requested_model_reasoning_effort": "xhigh",
        }
        summary = {
            "status": "completed",
            "runtime": {
                "verified": True,
                "model": "gpt-5.6-sol",
                "model_reasoning_effort": "xhigh",
            },
            "policy_violations": [],
            "report_problems": [],
            "identity_problems": [],
        }
        with (
            mock.patch.object(
                BRIDGE,
                "_load_review_failure_context",
                return_value={
                    "authorization_kind": "deep_review_repair",
                    "candidate_commit": "a" * 40,
                },
            ),
            mock.patch.object(
                BRIDGE, "_root_continuations", return_value=["already-used"]
            ),
            self.assertRaisesRegex(BRIDGE.BridgeError, "already used"),
        ):
            BRIDGE._load_validation_retry_authorization(
                repo_root,
                implementation_agent="core_simulation",
                resume_run="round-two",
                invocation=invocation,
                summary=summary,
                base_commit="b" * 40,
                profile=profile,
                root_run_id="root",
            )

    def test_review_repair_resume_accepts_release_lead_candidate_head(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repo = Path(temporary)
            worktree = repo / ".worktrees" / "candidate"
            worktree.mkdir(parents=True)
            branch = "codex/candidate"
            base = "a" * 40
            candidate = "b" * 40

            def fake_git(_repo: Path, *args: str, check: bool = True) -> str:
                del check
                if args == ("rev-parse", "--show-toplevel"):
                    return str(worktree)
                if args == ("rev-parse", "HEAD"):
                    return candidate
                if args == ("branch", "--show-current"):
                    return branch
                raise AssertionError(f"Unexpected git args: {args}")

            with (
                mock.patch.object(
                    BRIDGE,
                    "_registered_worktrees",
                    return_value={BRIDGE._normalized_path(worktree)},
                ),
                mock.patch.object(BRIDGE, "_git", side_effect=fake_git),
                mock.patch.object(BRIDGE, "_changed_paths", return_value=[]),
            ):
                changed = BRIDGE._validate_resume_worktree(
                    repo,
                    worktree,
                    base_commit=base,
                    expected_head=candidate,
                    branch=branch,
                    ticket={"mode": "write", "allowed_paths": ["**"], "forbidden_paths": []},
                )
                self.assertEqual(changed, [])
                with self.assertRaisesRegex(BRIDGE.BridgeError, "resumable candidate"):
                    BRIDGE._validate_resume_worktree(
                        repo,
                        worktree,
                        base_commit=base,
                        expected_head=base,
                        branch=branch,
                        ticket={"mode": "write", "allowed_paths": ["**"], "forbidden_paths": []},
                    )

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
