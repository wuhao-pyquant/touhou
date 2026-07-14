#!/usr/bin/env python3
"""Fail-closed bridge from project agent profiles to independent Codex CLI runs."""

from __future__ import annotations

import argparse
import datetime as dt
import fnmatch
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
import tomllib
import uuid
from collections.abc import Iterator
from pathlib import Path
from typing import Any


TICKET_REQUIRED = {
    "id": str,
    "objective": str,
    "mode": str,
    "allowed_paths": list,
    "forbidden_paths": list,
    "dependency_commit": str,
    "acceptance_commands": list,
    "output_requirements": list,
    "max_repair_rounds": int,
}
REPORT_REQUIRED = {
    "status": str,
    "summary": str,
    "changed_files": list,
    "commands": list,
    "tests": list,
    "failures": list,
    "residual_risks": list,
}
PROFILE_REQUIRED = {
    "name": str,
    "description": str,
    "developer_instructions": str,
    "model": str,
    "model_reasoning_effort": str,
    "sandbox_mode": str,
}


class BridgeError(RuntimeError):
    pass


def _run(
    command: list[str],
    *,
    cwd: Path,
    check: bool = True,
    text: bool = True,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=cwd,
        capture_output=True,
        text=text,
        encoding="utf-8" if text else None,
        errors="replace" if text else None,
    )
    if check and result.returncode != 0:
        rendered = subprocess.list2cmdline(command)
        raise BridgeError(
            f"Command failed ({result.returncode}): {rendered}\n{result.stderr.strip()}"
        )
    return result


def _git(repo: Path, *args: str, check: bool = True) -> str:
    return _run(["git", *args], cwd=repo, check=check).stdout.strip()


def _load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise BridgeError(f"Could not read JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise BridgeError(f"Expected JSON object in {path}")
    return value


def _load_profile(path: Path) -> dict[str, Any]:
    try:
        with path.open("rb") as stream:
            value = tomllib.load(stream)
    except (OSError, tomllib.TOMLDecodeError) as exc:
        raise BridgeError(f"Could not read agent profile {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise BridgeError(f"Expected TOML table in {path}")
    _validate_required(value, PROFILE_REQUIRED, f"profile {path.name}")
    if value["name"] != path.stem:
        raise BridgeError(
            f"Profile name {value['name']!r} must match filename {path.stem!r}"
        )
    if value["sandbox_mode"] not in {"read-only", "workspace-write"}:
        raise BridgeError("Agent profiles may only use read-only or workspace-write")
    escalations = value.get("repair_escalations", [])
    if not isinstance(escalations, list):
        raise BridgeError(f"profile {path.name}.repair_escalations must be an array")
    previous_identity = (value["model"], value["model_reasoning_effort"])
    for index, escalation in enumerate(escalations, start=1):
        if not isinstance(escalation, dict):
            raise BridgeError(
                f"profile {path.name}.repair_escalations[{index - 1}] must be a table"
            )
        if set(escalation) != {"round", "model", "model_reasoning_effort"}:
            raise BridgeError(
                f"profile {path.name}.repair_escalations[{index - 1}] must contain "
                "round, model, and model_reasoning_effort only"
            )
        if (
            not isinstance(escalation["round"], int)
            or isinstance(escalation["round"], bool)
            or escalation["round"] != index
        ):
            raise BridgeError(
                f"profile {path.name} repair escalation rounds must be contiguous "
                "and start at 1"
            )
        for key in ("model", "model_reasoning_effort"):
            if not isinstance(escalation[key], str) or not escalation[key].strip():
                raise BridgeError(
                    f"profile {path.name}.repair_escalations[{index - 1}].{key} "
                    "must be a non-empty string"
                )
        current_identity = (
            escalation["model"],
            escalation["model_reasoning_effort"],
        )
        if current_identity == previous_identity:
            raise BridgeError(
                f"profile {path.name} repair escalation round {index} must change "
                "the model or reasoning effort"
            )
        previous_identity = current_identity
    return value


def _profile_identity(profile: dict[str, Any], repair_round: int) -> dict[str, str]:
    if repair_round == 0:
        return {
            "model": str(profile["model"]),
            "model_reasoning_effort": str(profile["model_reasoning_effort"]),
        }
    for escalation in profile.get("repair_escalations", []):
        if escalation["round"] == repair_round:
            return {
                "model": str(escalation["model"]),
                "model_reasoning_effort": str(
                    escalation["model_reasoning_effort"]
                ),
            }
    raise BridgeError(
        f"Agent profile {profile['name']!r} has no repair escalation for round "
        f"{repair_round}"
    )


def _repair_identity(
    profile: dict[str, Any],
    ticket: dict[str, Any],
    *,
    prior_round: int,
    escalation_level: int,
) -> dict[str, str]:
    expected_round = prior_round + 1
    if escalation_level != expected_round:
        raise BridgeError(
            f"EscalationLevel must be the next contiguous round {expected_round}, "
            f"got {escalation_level}"
        )
    if escalation_level > ticket["max_repair_rounds"]:
        raise BridgeError(
            f"Ticket permits {ticket['max_repair_rounds']} repair round(s); "
            f"round {escalation_level} is forbidden"
        )
    return _profile_identity(profile, escalation_level)


def _validate_required(
    value: dict[str, Any], required: dict[str, type], label: str
) -> None:
    for key, expected_type in required.items():
        if key not in value:
            raise BridgeError(f"{label} is missing required field {key!r}")
        if not isinstance(value[key], expected_type):
            raise BridgeError(
                f"{label}.{key} must be {expected_type.__name__}, "
                f"got {type(value[key]).__name__}"
            )


def _validate_ticket(ticket: dict[str, Any]) -> None:
    _validate_required(ticket, TICKET_REQUIRED, "ticket")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", ticket["id"]):
        raise BridgeError("ticket.id contains unsupported characters")
    if ticket["mode"] not in {"read_only", "write"}:
        raise BridgeError("ticket.mode must be read_only or write")
    if ticket["mode"] == "write" and not ticket["allowed_paths"]:
        raise BridgeError("write tickets require at least one allowed path")
    if not 0 <= ticket["max_repair_rounds"] <= 2:
        raise BridgeError("ticket.max_repair_rounds must be between 0 and 2")
    for key in (
        "allowed_paths",
        "forbidden_paths",
        "acceptance_commands",
        "output_requirements",
        "context",
    ):
        if key in ticket and not all(isinstance(item, str) for item in ticket[key]):
            raise BridgeError(f"ticket.{key} must contain only strings")


def _validate_report(report: dict[str, Any]) -> list[str]:
    problems: list[str] = []
    try:
        _validate_required(report, REPORT_REQUIRED, "report")
    except BridgeError as exc:
        return [str(exc)]
    if report["status"] not in {"completed", "blocked", "failed"}:
        problems.append("report.status must be completed, blocked, or failed")
    for key in ("changed_files", "commands", "failures", "residual_risks"):
        if not all(isinstance(item, str) for item in report[key]):
            problems.append(f"report.{key} must contain only strings")
    for index, test in enumerate(report["tests"]):
        if not isinstance(test, dict):
            problems.append(f"report.tests[{index}] must be an object")
            continue
        if set(test) != {"name", "status", "evidence"}:
            problems.append(
                f"report.tests[{index}] must contain name, status, and evidence only"
            )
            continue
        if test["status"] not in {"passed", "failed", "not_run"}:
            problems.append(f"report.tests[{index}].status is invalid")
    return problems


def _sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def _safe_segment(value: str, max_length: int = 48) -> str:
    sanitized = re.sub(r"[^A-Za-z0-9._-]+", "-", value).strip("-.")
    return (sanitized or "run")[:max_length]


def _changed_paths(worktree: Path, base_commit: str) -> list[str]:
    changed: set[str] = set()
    diff = _git(worktree, "diff", "--name-only", base_commit, "--")
    if diff:
        changed.update(line.replace("\\", "/") for line in diff.splitlines())
    untracked = _git(worktree, "ls-files", "--others", "--exclude-standard")
    if untracked:
        changed.update(line.replace("\\", "/") for line in untracked.splitlines())
    return sorted(path for path in changed if path)


def _matches(path: str, pattern: str) -> bool:
    normalized_path = path.replace("\\", "/")
    normalized_pattern = pattern.replace("\\", "/").lstrip("./")
    if normalized_pattern.endswith("/"):
        return normalized_path.startswith(normalized_pattern)
    return fnmatch.fnmatchcase(normalized_path, normalized_pattern)


def _policy_violations(ticket: dict[str, Any], changed: list[str]) -> list[str]:
    violations: list[str] = []
    allowed = ticket["allowed_paths"]
    forbidden = ticket["forbidden_paths"]
    for path in changed:
        if any(_matches(path, pattern) for pattern in forbidden):
            violations.append(f"forbidden path changed: {path}")
        elif not any(_matches(path, pattern) for pattern in allowed):
            violations.append(f"path outside allowed_paths changed: {path}")
    return violations


def _event_thread_id(events_path: Path) -> str | None:
    if not events_path.exists():
        return None
    for raw_line in events_path.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            event = json.loads(raw_line)
        except json.JSONDecodeError:
            continue
        if not isinstance(event, dict):
            continue
        if event.get("type") == "thread.started":
            for key in ("thread_id", "id"):
                value = event.get(key)
                if isinstance(value, str) and value:
                    return value
        for key in ("thread_id", "session_id"):
            value = event.get(key)
            if isinstance(value, str) and re.fullmatch(r"[0-9a-f-]{20,}", value):
                return value
    return None


def _session_files(thread_id: str | None) -> list[Path]:
    if not thread_id:
        return []
    codex_home = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
    sessions = codex_home / "sessions"
    candidates: list[Path] = []
    for _ in range(15):
        if sessions.exists():
            candidates = list(sessions.rglob(f"*{thread_id}*.jsonl"))
        if candidates:
            break
        time.sleep(0.2)
    return candidates


def _session_snapshot(thread_id: str | None) -> dict[str, int]:
    snapshot: dict[str, int] = {}
    for path in _session_files(thread_id):
        try:
            snapshot[str(path.resolve())] = path.stat().st_size
        except OSError:
            continue
    return snapshot


def _iter_jsonl_segment(path: Path, offset: int = 0) -> Iterator[dict[str, Any]]:
    try:
        with path.open("rb") as stream:
            stream.seek(max(0, offset))
            for raw_line in stream:
                try:
                    entry = json.loads(raw_line.decode("utf-8", errors="replace"))
                except json.JSONDecodeError:
                    continue
                if isinstance(entry, dict):
                    yield entry
    except OSError:
        return


def _session_identity(
    thread_id: str | None,
    *,
    previous_snapshot: dict[str, int] | None = None,
    require_new_turn: bool = False,
) -> dict[str, Any]:
    identity: dict[str, Any] = {
        "thread_id": thread_id,
        "model": None,
        "model_reasoning_effort": None,
        "cli_version": None,
        "session_file": None,
        "new_turn_verified": False,
        "verified": False,
    }
    if not thread_id:
        return identity
    candidates = _session_files(thread_id)
    if not candidates:
        return identity
    previous_snapshot = previous_snapshot or {}
    candidates.sort(key=lambda path: path.stat().st_mtime, reverse=True)
    for session_file in candidates:
        resolved = str(session_file.resolve())
        cli_version = None
        for entry in _iter_jsonl_segment(session_file):
            if entry.get("type") == "session_meta":
                payload = entry.get("payload", {})
                if isinstance(payload, dict):
                    cli_version = payload.get("cli_version")
                break

        if require_new_turn:
            previous_size = previous_snapshot.get(resolved)
            if previous_size is None:
                candidate_entries = _iter_jsonl_segment(session_file)
            else:
                try:
                    current_size = session_file.stat().st_size
                except OSError:
                    continue
                if current_size <= previous_size:
                    continue
                candidate_entries = _iter_jsonl_segment(session_file, previous_size)
        else:
            candidate_entries = _iter_jsonl_segment(session_file)

        latest_context: dict[str, Any] | None = None
        for entry in candidate_entries:
            if entry.get("type") != "turn_context":
                continue
            payload = entry.get("payload", {})
            if isinstance(payload, dict):
                latest_context = payload
        if latest_context is None:
            continue
        identity["session_file"] = str(session_file)
        identity["cli_version"] = cli_version
        identity["model"] = latest_context.get("model")
        identity["model_reasoning_effort"] = latest_context.get(
            "model_reasoning_effort", latest_context.get("effort")
        )
        identity["new_turn_verified"] = require_new_turn
        break

    identity["verified"] = bool(
        identity["model"]
        and identity["model_reasoning_effort"]
        and (not require_new_turn or identity["new_turn_verified"])
    )
    return identity


def _build_prompt(profile: dict[str, Any], ticket: dict[str, Any]) -> str:
    ticket_json = json.dumps(ticket, ensure_ascii=False, indent=2, sort_keys=True)
    return f"""<agent_profile name={json.dumps(profile['name'])}>
{profile['developer_instructions'].strip()}
</agent_profile>

<execution_contract>
You are a leaf worker launched by the project's independent Codex CLI bridge.
Do not spawn subagents. Do not create or rewrite a project plan. Do not commit,
merge, rebase, push, remove worktrees, or touch paths outside allowed_paths.
Treat forbidden_paths as immutable even if they are already dirty elsewhere.
Run only the focused acceptance commands required by this ticket.
Your final response must be a single JSON object matching report.schema.json.
</execution_contract>

<ticket>
{ticket_json}
</ticket>
"""


def _load_optional_report(run_dir: Path) -> dict[str, Any] | None:
    for name in ("validated-report.json", "final.json"):
        path = run_dir / name
        if not path.exists():
            continue
        try:
            value = _load_json(path)
        except BridgeError:
            continue
        if name == "validated-report.json":
            value = value.get("report", {})
        if isinstance(value, dict):
            return value
    return None


def _bounded_strings(values: Any, *, limit: int = 8) -> list[str]:
    if not isinstance(values, list):
        return []
    bounded: list[str] = []
    for value in values[:limit]:
        if isinstance(value, str) and value.strip():
            bounded.append(value.strip()[:2000])
    return bounded


def _failure_context(run_dir: Path, summary: dict[str, Any]) -> dict[str, Any]:
    report = _load_optional_report(run_dir) or {}
    failed_tests: list[dict[str, str]] = []
    tests = report.get("tests", [])
    if isinstance(tests, list):
        for test in tests:
            if not isinstance(test, dict) or test.get("status") != "failed":
                continue
            failed_tests.append(
                {
                    "name": str(test.get("name", "unnamed"))[:300],
                    "evidence": str(test.get("evidence", ""))[:2000],
                }
            )
            if len(failed_tests) >= 8:
                break
    return {
        "previous_exit_code": summary.get("exit_code"),
        "previous_report_status": report.get("status"),
        "failures": _bounded_strings(report.get("failures")),
        "failed_tests": failed_tests,
        "policy_violations": _bounded_strings(summary.get("policy_violations")),
        "report_problems": _bounded_strings(summary.get("report_problems")),
        "identity_problems": _bounded_strings(summary.get("identity_problems")),
        "residual_risks": _bounded_strings(report.get("residual_risks")),
    }


def _build_repair_prompt(
    profile: dict[str, Any],
    ticket: dict[str, Any],
    *,
    parent_run_id: str,
    repair_round: int,
    failure_context: dict[str, Any],
    repair_instruction: str | None,
) -> str:
    continuation = {
        "agent": profile["name"],
        "ticket_id": ticket["id"],
        "repair_round": repair_round,
        "parent_run_id": parent_run_id,
        "objective": ticket["objective"],
        "allowed_paths": ticket["allowed_paths"],
        "forbidden_paths": ticket["forbidden_paths"],
        "failure_context": failure_context,
        "directed_repair": (repair_instruction or "").strip()[:4000],
    }
    continuation_json = json.dumps(
        continuation, ensure_ascii=False, indent=2, sort_keys=True
    )
    return f"""<repair_continuation>
Continue the same ticket in the same Codex session and existing worktree.
Your agent identity and responsibility remain {profile['name']!r}; only this
repair turn's model routing is temporarily overridden by the bridge.

Do not restart the task, rewrite the project plan, discard valid uncommitted
work, create a new worktree or branch, or broaden the ticket. Address only the
bounded failure evidence below. Run only the directly affected acceptance
commands and one relevant smoke check. Your final response must again be one
JSON object matching report.schema.json.

{continuation_json}
</repair_continuation>
"""


def _build_transport_retry_prompt(
    profile: dict[str, Any],
    ticket: dict[str, Any],
    *,
    parent_run_id: str,
) -> str:
    continuation = {
        "agent": profile["name"],
        "ticket_id": ticket["id"],
        "parent_run_id": parent_run_id,
        "objective": ticket["objective"],
        "allowed_paths": ticket["allowed_paths"],
        "forbidden_paths": ticket["forbidden_paths"],
    }
    continuation_json = json.dumps(
        continuation, ensure_ascii=False, indent=2, sort_keys=True
    )
    return f"""<transport_retry_continuation>
Continue the same ticket in the same Codex session and existing worktree. The
previous CLI turn ended without a valid final report and made no workspace
changes. This is a transport retry, not a repair round: keep the same agent,
model tier, reasoning effort, ticket scope, and task state.

Do not restart or re-plan the task, create a new worktree or branch, or broaden
the ticket. Finish the pending work from the existing conversation context.
Your final response must be one JSON object matching report.schema.json.

{continuation_json}
</transport_retry_continuation>
"""


def _canonical_json_sha256(value: dict[str, Any]) -> str:
    rendered = json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    )
    return _sha256_text(rendered)


def _resolve_run_dir(repo: Path, run_id: str) -> Path:
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", run_id):
        raise BridgeError("resume run id contains unsupported characters")
    runs_root = (repo / ".agent-runs").resolve()
    run_dir = (runs_root / run_id).resolve()
    if run_dir.parent != runs_root or not run_dir.is_dir():
        raise BridgeError(f"Could not find prior run {run_id!r}")
    return run_dir


def _load_ticket_snapshot(
    repo: Path,
    run_dir: Path,
    invocation: dict[str, Any],
) -> tuple[dict[str, Any], str, str]:
    root_run_id = invocation.get("root_run_id")
    candidates: list[Path] = [run_dir / "ticket.snapshot.json"]
    if isinstance(root_run_id, str) and root_run_id:
        root_dir = _resolve_run_dir(repo, root_run_id)
        candidates.insert(0, root_dir / "ticket.snapshot.json")
    for path in candidates:
        if path.exists():
            ticket = _load_json(path)
            _validate_ticket(ticket)
            return ticket, str(path), _canonical_json_sha256(ticket)

    ticket_path_value = invocation.get("ticket_path")
    expected_sha = invocation.get("ticket_sha256")
    if not isinstance(ticket_path_value, str) or not isinstance(expected_sha, str):
        raise BridgeError(
            "Prior run predates ticket snapshots and has no verifiable ticket path"
        )
    ticket_path = Path(ticket_path_value)
    if not ticket_path.is_absolute():
        ticket_path = (repo / ticket_path).resolve()
    try:
        raw_ticket = ticket_path.read_text(encoding="utf-8-sig")
    except OSError as exc:
        raise BridgeError(f"Could not recover prior ticket {ticket_path}: {exc}") from exc
    if _sha256_text(raw_ticket) != expected_sha:
        raise BridgeError(
            "Prior run predates ticket snapshots and its ticket file has changed; "
            "refusing to resume a mutable contract"
        )
    ticket = _load_json(ticket_path)
    _validate_ticket(ticket)
    return ticket, str(ticket_path), _canonical_json_sha256(ticket)


def _non_dry_run_children(repo: Path, parent_run_id: str) -> list[str]:
    children: list[str] = []
    runs_root = repo / ".agent-runs"
    if not runs_root.exists():
        return children
    for invocation_path in runs_root.glob("*/invocation.json"):
        try:
            invocation = _load_json(invocation_path)
        except BridgeError:
            continue
        if invocation.get("parent_run_id") != parent_run_id:
            continue
        if invocation.get("dry_run") is True:
            continue
        children.append(invocation_path.parent.name)
    return sorted(children)


def _normalized_path(path: Path) -> str:
    return os.path.normcase(str(path.resolve()))


def _registered_worktrees(repo: Path) -> set[str]:
    registered: set[str] = set()
    output = _git(repo, "worktree", "list", "--porcelain")
    for line in output.splitlines():
        if line.startswith("worktree "):
            registered.add(_normalized_path(Path(line.removeprefix("worktree "))))
    return registered


def _validate_resume_worktree(
    repo: Path,
    worktree: Path,
    *,
    base_commit: str,
    branch: str | None,
    ticket: dict[str, Any],
) -> list[str]:
    worktrees_root = (repo / ".worktrees").resolve()
    resolved = worktree.resolve()
    try:
        resolved.relative_to(worktrees_root)
    except ValueError as exc:
        raise BridgeError(f"Prior worktree is outside .worktrees: {resolved}") from exc
    if not resolved.is_dir():
        raise BridgeError(f"Prior worktree no longer exists: {resolved}")
    if _normalized_path(resolved) not in _registered_worktrees(repo):
        raise BridgeError(f"Prior path is not a registered Git worktree: {resolved}")
    actual_root = Path(_git(resolved, "rev-parse", "--show-toplevel"))
    if _normalized_path(actual_root) != _normalized_path(resolved):
        raise BridgeError(f"Git worktree root mismatch for {resolved}")
    actual_head = _git(resolved, "rev-parse", "HEAD")
    if actual_head != base_commit:
        raise BridgeError(
            "The leaf Agent committed or moved the worktree HEAD; resume requires "
            f"the original base {base_commit}, found {actual_head}"
        )
    actual_branch = _git(resolved, "branch", "--show-current") or None
    if actual_branch != branch:
        raise BridgeError(
            f"Prior worktree branch changed: expected {branch!r}, found "
            f"{actual_branch!r}"
        )
    changed = _changed_paths(resolved, base_commit)
    violations = _policy_violations(ticket, changed)
    if ticket["mode"] == "read_only" and changed:
        violations.extend(f"read-only task changed: {path}" for path in changed)
    if violations:
        raise BridgeError(
            "Prior worktree violates the frozen ticket before resume:\n"
            + "\n".join(violations)
        )
    return changed


def _build_fresh_command(
    codex: str,
    *,
    worktree: Path,
    identity: dict[str, str],
    sandbox: str,
    report_schema: Path,
    final_path: Path,
) -> list[str]:
    return [
        codex,
        "exec",
        "--strict-config",
        "-C",
        str(worktree),
        "-m",
        identity["model"],
        "-c",
        f'model_reasoning_effort="{identity["model_reasoning_effort"]}"',
        "-s",
        sandbox,
        "--json",
        "--output-schema",
        str(report_schema),
        "-o",
        str(final_path),
        "-",
    ]


def _build_resume_command(
    codex: str,
    *,
    thread_id: str,
    identity: dict[str, str],
    report_schema: Path,
    final_path: Path,
) -> list[str]:
    return [
        codex,
        "exec",
        "resume",
        "--strict-config",
        "-m",
        identity["model"],
        "-c",
        f'model_reasoning_effort="{identity["model_reasoning_effort"]}"',
        "--json",
        "--output-schema",
        str(report_schema),
        "-o",
        str(final_path),
        thread_id,
        "-",
    ]


def _codex_version(codex: str, repo: Path) -> str:
    result = _run([codex, "--version"], cwd=repo)
    return result.stdout.strip()


def _write_json(path: Path, value: Any) -> None:
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def _create_worktree(
    repo: Path,
    ticket: dict[str, Any],
    agent: str,
    base_commit: str,
    run_suffix: str,
) -> tuple[Path, str | None]:
    stem = f"{_safe_segment(ticket['id'])}-{_safe_segment(agent)}-{run_suffix}"
    worktree = repo / ".worktrees" / stem
    worktree.parent.mkdir(parents=True, exist_ok=True)
    if ticket["mode"] == "write":
        branch = f"codex/{_safe_segment(ticket['id'], 32)}-{_safe_segment(agent, 24)}-{run_suffix}"
        _git(repo, "worktree", "add", "-b", branch, str(worktree), base_commit)
        return worktree, branch
    _git(repo, "worktree", "add", "--detach", str(worktree), base_commit)
    return worktree, None


def _new_run_id(ticket_id: str, agent: str, repair_round: int) -> tuple[str, str]:
    timestamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_suffix = uuid.uuid4().hex[:8]
    repair_segment = f"-r{repair_round}" if repair_round else ""
    run_id = (
        f"{timestamp}-{_safe_segment(ticket_id)}-{_safe_segment(agent)}"
        f"{repair_segment}-{run_suffix}"
    )
    return run_id, run_suffix


def _load_resume_context(
    repo: Path,
    *,
    agent: str,
    resume_run: str,
    escalation_level: int | None,
    transport_retry: bool,
    profile: dict[str, Any],
) -> dict[str, Any]:
    parent_dir = _resolve_run_dir(repo, resume_run)
    invocation = _load_json(parent_dir / "invocation.json")
    summary = _load_json(parent_dir / "run-summary.json")
    if summary.get("status") not in {"failed", "bridge_error"}:
        raise BridgeError(
            f"Run {resume_run!r} is {summary.get('status')!r}, not resumable"
        )
    if invocation.get("dry_run") is True:
        raise BridgeError("Dry-run records cannot be resumed")
    if invocation.get("agent") != agent:
        raise BridgeError(
            f"Resume must keep the same Agent: prior {invocation.get('agent')!r}, "
            f"requested {agent!r}"
        )
    children = _non_dry_run_children(repo, resume_run)
    if children:
        raise BridgeError(
            f"Run {resume_run!r} already has continuation {children[0]!r}; "
            "resume the latest failed child instead"
        )

    prior_round = invocation.get("repair_round", 0)
    if not isinstance(prior_round, int) or isinstance(prior_round, bool):
        raise BridgeError("Prior invocation has an invalid repair_round")
    ticket, ticket_source, ticket_sha256 = _load_ticket_snapshot(
        repo, parent_dir, invocation
    )
    if transport_retry:
        if _load_optional_report(parent_dir) is not None:
            raise BridgeError(
                "Transport retry is only allowed when the prior run wrote no report"
            )
        if summary.get("changed_paths"):
            raise BridgeError(
                "Transport retry is forbidden after workspace changes; use a repair round"
            )
        if summary.get("policy_violations") or summary.get("identity_problems"):
            raise BridgeError(
                "Transport retry is forbidden after policy or identity failure"
            )
        requested_identity = _profile_identity(profile, prior_round)
        prior_requested = {
            "model": invocation.get("requested_model"),
            "model_reasoning_effort": invocation.get(
                "requested_model_reasoning_effort"
            ),
        }
        if prior_requested != requested_identity:
            raise BridgeError(
                "Prior invocation identity no longer matches the frozen profile route"
            )
        repair_round = prior_round
    else:
        assert escalation_level is not None
        requested_identity = _repair_identity(
            profile,
            ticket,
            prior_round=prior_round,
            escalation_level=escalation_level,
        )
        repair_round = escalation_level

    runtime = summary.get("runtime", {})
    if not isinstance(runtime, dict):
        runtime = {}
    thread_id = runtime.get("thread_id") or invocation.get("thread_id")
    if not isinstance(thread_id, str) or not thread_id:
        raise BridgeError(
            "Prior run has no persisted Codex thread_id; the same session cannot resume"
        )
    base_commit = invocation.get("base_commit")
    if not isinstance(base_commit, str) or not base_commit:
        raise BridgeError("Prior invocation has no base_commit")
    verified_base = _git(repo, "rev-parse", "--verify", f"{base_commit}^{{commit}}")
    if verified_base != base_commit:
        raise BridgeError(
            f"Prior base commit no longer resolves exactly: {base_commit!r}"
        )
    worktree_value = invocation.get("worktree") or summary.get("worktree")
    if not isinstance(worktree_value, str) or not worktree_value:
        raise BridgeError("Prior invocation has no worktree")
    branch = invocation.get("branch")
    if branch is not None and not isinstance(branch, str):
        raise BridgeError("Prior invocation has an invalid branch")
    worktree = Path(worktree_value)
    preexisting_changed_paths = _validate_resume_worktree(
        repo,
        worktree,
        base_commit=base_commit,
        branch=branch,
        ticket=ticket,
    )

    requested_sandbox = str(profile["sandbox_mode"])
    sandbox = "read-only" if ticket["mode"] == "read_only" else requested_sandbox
    if ticket["mode"] == "write" and sandbox != "workspace-write":
        raise BridgeError(
            f"Write ticket requires workspace-write profile, got {sandbox}"
        )
    prior_sandbox = invocation.get("sandbox")
    if prior_sandbox != sandbox:
        raise BridgeError(
            "Resume cannot change sandbox because codex exec resume has no sandbox "
            f"override in this CLI version: prior {prior_sandbox!r}, current {sandbox!r}"
        )

    root_run_id = invocation.get("root_run_id")
    if not isinstance(root_run_id, str) or not root_run_id:
        root_run_id = resume_run
    return {
        "parent_run_id": resume_run,
        "root_run_id": root_run_id,
        "parent_dir": parent_dir,
        "parent_invocation": invocation,
        "parent_summary": summary,
        "repair_round": repair_round,
        "continuation_kind": "transport_retry" if transport_retry else "repair",
        "ticket": ticket,
        "ticket_source": ticket_source,
        "ticket_sha256": ticket_sha256,
        "requested_identity": requested_identity,
        "thread_id": thread_id,
        "base_commit": base_commit,
        "worktree": worktree.resolve(),
        "branch": branch,
        "sandbox": sandbox,
        "preexisting_changed_paths": preexisting_changed_paths,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path)
    parser.add_argument("--agent", required=True)
    parser.add_argument("--ticket", type=Path)
    parser.add_argument("--resume-run")
    parser.add_argument("--escalation-level", type=int)
    parser.add_argument("--transport-retry", action="store_true")
    parser.add_argument("--repair-instruction")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--keep-worktree", action="store_true")
    args = parser.parse_args()

    is_resume = bool(args.resume_run)
    if is_resume == bool(args.ticket):
        raise BridgeError("Specify exactly one of --ticket or --resume-run")
    if is_resume:
        if args.transport_retry:
            if args.escalation_level is not None or args.repair_instruction:
                raise BridgeError(
                    "--transport-retry cannot be combined with escalation or repair input"
                )
        else:
            if args.escalation_level is None:
                raise BridgeError(
                    "--resume-run requires --escalation-level or --transport-retry"
                )
            if args.escalation_level < 1:
                raise BridgeError("--escalation-level must be at least 1")
    elif (
        args.escalation_level is not None
        or args.transport_retry
        or args.repair_instruction
    ):
        raise BridgeError(
            "continuation options require --resume-run"
        )

    repo = (
        args.repo_root.resolve()
        if args.repo_root
        else Path(_git(Path.cwd(), "rev-parse", "--show-toplevel")).resolve()
    )
    if not (repo / ".git").exists():
        raise BridgeError(f"Not a repository root: {repo}")

    profile_path = repo / ".codex" / "agents" / f"{args.agent}.toml"
    profile = _load_profile(profile_path)
    default_identity = _profile_identity(profile, 0)

    resume_context: dict[str, Any] | None = None
    if is_resume:
        assert args.resume_run is not None
        resume_context = _load_resume_context(
            repo,
            agent=args.agent,
            resume_run=args.resume_run,
            escalation_level=args.escalation_level,
            transport_retry=args.transport_retry,
            profile=profile,
        )
        ticket = resume_context["ticket"]
        ticket_source = resume_context["ticket_source"]
        ticket_sha256 = resume_context["ticket_sha256"]
        base_commit = resume_context["base_commit"]
        requested_identity = resume_context["requested_identity"]
        repair_round = resume_context["repair_round"]
        parent_run_id = resume_context["parent_run_id"]
        root_run_id = resume_context["root_run_id"]
        thread_id = resume_context["thread_id"]
        sandbox = resume_context["sandbox"]
    else:
        assert args.ticket is not None
        ticket_path = args.ticket
        if not ticket_path.is_absolute():
            ticket_path = (repo / ticket_path).resolve()
        ticket = _load_json(ticket_path)
        _validate_ticket(ticket)
        ticket_source = str(ticket_path)
        ticket_sha256 = _canonical_json_sha256(ticket)
        base_commit = _git(
            repo,
            "rev-parse",
            "--verify",
            f"{ticket['dependency_commit']}^{{commit}}",
        )
        requested_identity = default_identity
        repair_round = 0
        parent_run_id = None
        root_run_id = None
        thread_id = None
        requested_sandbox = str(profile["sandbox_mode"])
        sandbox = (
            "read-only" if ticket["mode"] == "read_only" else requested_sandbox
        )
        if ticket["mode"] == "write" and sandbox != "workspace-write":
            raise BridgeError(
                f"Write ticket requires workspace-write profile, got {sandbox}"
            )

    run_id, run_suffix = _new_run_id(ticket["id"], args.agent, repair_round)
    if root_run_id is None:
        root_run_id = run_id
    run_dir = repo / ".agent-runs" / run_id
    run_dir.mkdir(parents=True, exist_ok=False)

    worktree: Path | None = None
    branch: str | None = None

    try:
        if resume_context is not None:
            worktree = resume_context["worktree"]
            branch = resume_context["branch"]
            if resume_context["continuation_kind"] == "transport_retry":
                prompt = _build_transport_retry_prompt(
                    profile,
                    ticket,
                    parent_run_id=parent_run_id,
                )
            else:
                prompt = _build_repair_prompt(
                    profile,
                    ticket,
                    parent_run_id=parent_run_id,
                    repair_round=repair_round,
                    failure_context=_failure_context(
                        resume_context["parent_dir"],
                        resume_context["parent_summary"],
                    ),
                    repair_instruction=args.repair_instruction,
                )
        else:
            prompt = _build_prompt(profile, ticket)
            if args.dry_run:
                worktree = repo / ".worktrees" / (
                    f"{_safe_segment(ticket['id'])}-{_safe_segment(args.agent)}-DRYRUN"
                )
                if ticket["mode"] == "write":
                    branch = (
                        f"codex/{_safe_segment(ticket['id'], 32)}-"
                        f"{_safe_segment(args.agent, 24)}-DRYRUN"
                    )
            else:
                worktree, branch = _create_worktree(
                    repo, ticket, args.agent, base_commit, run_suffix
                )

        (run_dir / "prompt.txt").write_text(prompt, encoding="utf-8")
        _write_json(run_dir / "ticket.snapshot.json", ticket)
        _write_json(run_dir / "profile.snapshot.json", profile)

        codex = shutil.which(os.environ.get("CODEX_CLI", "codex"))
        if not codex:
            raise BridgeError("Could not locate the Codex CLI executable")

        final_path = run_dir / "final.json"
        events_path = run_dir / "events.jsonl"
        stderr_path = run_dir / "stderr.log"
        report_schema = repo / "tools" / "agents" / "report.schema.json"
        assert worktree is not None
        if is_resume:
            assert thread_id is not None
            command = _build_resume_command(
                codex,
                thread_id=thread_id,
                identity=requested_identity,
                report_schema=report_schema,
                final_path=final_path,
            )
        else:
            command = _build_fresh_command(
                codex,
                worktree=worktree,
                identity=requested_identity,
                sandbox=sandbox,
                report_schema=report_schema,
                final_path=final_path,
            )
        invocation = {
            "run_id": run_id,
            "created_at": _utc_now(),
            "mode": "resume" if is_resume else "fresh",
            "agent": args.agent,
            "ticket_id": ticket["id"],
            "ticket_path": ticket_source,
            "ticket_sha256": ticket_sha256,
            "base_commit": base_commit,
            "worktree": str(worktree),
            "branch": branch,
            "parent_run_id": parent_run_id,
            "root_run_id": root_run_id,
            "repair_round": repair_round,
            "continuation_kind": (
                resume_context["continuation_kind"]
                if resume_context is not None
                else "fresh"
            ),
            "thread_id": thread_id,
            "profile_default": default_identity,
            "requested_model": requested_identity["model"],
            "requested_model_reasoning_effort": requested_identity[
                "model_reasoning_effort"
            ],
            "routing_scope": "single_invocation",
            "sandbox": sandbox,
            "codex_cli": codex,
            "codex_cli_version": _codex_version(codex, repo),
            "command": command[:-1] + ["<prompt-from-stdin>"],
            "prompt_sha256": _sha256_text(prompt),
            "dry_run": args.dry_run,
        }
        _write_json(run_dir / "invocation.json", invocation)

        if args.dry_run:
            _write_json(
                run_dir / "run-summary.json",
                {
                    "status": "dry_run",
                    "run_id": run_id,
                    "mode": "resume" if is_resume else "fresh",
                    "worktree": str(worktree),
                    "branch": branch,
                    "parent_run_id": parent_run_id,
                    "root_run_id": root_run_id,
                    "repair_round": repair_round,
                    "requested": requested_identity,
                    "profile_default": default_identity,
                },
            )
            print(str(run_dir))
            return 0

        previous_session_snapshot = (
            _session_snapshot(thread_id) if is_resume else None
        )
        with (
            events_path.open("w", encoding="utf-8", newline="\n") as events,
            stderr_path.open("w", encoding="utf-8", newline="\n") as errors,
        ):
            process = subprocess.Popen(
                command,
                cwd=worktree,
                stdin=subprocess.PIPE,
                stdout=events,
                stderr=errors,
                text=True,
                encoding="utf-8",
                errors="replace",
            )
            process.communicate(prompt)
        exit_code = process.returncode

        event_thread_id = _event_thread_id(events_path)
        identity_problems: list[str] = []
        if is_resume:
            if event_thread_id and event_thread_id != thread_id:
                identity_problems.append(
                    f"resume event thread {event_thread_id!r} != prior "
                    f"thread {thread_id!r}"
                )
            runtime_thread_id = thread_id
        else:
            runtime_thread_id = event_thread_id
        runtime = _session_identity(
            runtime_thread_id,
            previous_snapshot=previous_session_snapshot,
            require_new_turn=is_resume,
        )
        changed = _changed_paths(worktree, base_commit)
        violations = _policy_violations(ticket, changed)
        if ticket["mode"] == "read_only" and changed:
            violations.extend(f"read-only task changed: {path}" for path in changed)
        actual_head = _git(worktree, "rev-parse", "HEAD")
        if actual_head != base_commit:
            violations.append(
                f"leaf Agent moved worktree HEAD: {actual_head} != {base_commit}"
            )
        actual_branch = _git(worktree, "branch", "--show-current") or None
        if actual_branch != branch:
            violations.append(
                f"leaf Agent changed branch: {actual_branch!r} != {branch!r}"
            )

        report: dict[str, Any] | None = None
        report_problems: list[str] = []
        if final_path.exists():
            try:
                report = _load_json(final_path)
                report_problems = _validate_report(report)
            except BridgeError as exc:
                report_problems = [str(exc)]
        else:
            report_problems = ["Codex did not write final.json"]

        require_identity = bool(ticket.get("require_runtime_identity", True))
        if require_identity and not runtime["verified"]:
            identity_problems.append(
                "runtime model identity for this turn could not be verified"
            )
        if runtime["verified"]:
            if runtime["model"] != requested_identity["model"]:
                identity_problems.append(
                    f"runtime model {runtime['model']!r} != requested "
                    f"{requested_identity['model']!r}"
                )
            if (
                runtime["model_reasoning_effort"]
                != requested_identity["model_reasoning_effort"]
            ):
                identity_problems.append(
                    "runtime reasoning effort "
                    f"{runtime['model_reasoning_effort']!r} != requested "
                    f"{requested_identity['model_reasoning_effort']!r}"
                )

        failed = bool(
            exit_code != 0
            or violations
            or report_problems
            or identity_problems
            or report is None
            or report.get("status") != "completed"
        )
        summary = {
            "status": "failed" if failed else "completed",
            "run_id": run_id,
            "exit_code": exit_code,
            "mode": "resume" if is_resume else "fresh",
            "agent": args.agent,
            "ticket_id": ticket["id"],
            "worktree": str(worktree),
            "branch": branch,
            "parent_run_id": parent_run_id,
            "root_run_id": root_run_id,
            "repair_round": repair_round,
            "requested": requested_identity,
            "routing": {
                "scope": "single_invocation",
                "profile_default_unchanged": True,
                "next_fresh_run": default_identity,
                "lineage_closed": not failed,
            },
            "runtime": runtime,
            "changed_paths": changed,
            "policy_violations": violations,
            "report_problems": report_problems,
            "identity_problems": identity_problems,
        }
        _write_json(run_dir / "run-summary.json", summary)
        if report is not None:
            _write_json(
                run_dir / "validated-report.json",
                {"runtime": runtime, "report": report},
            )

        keep_worktree = bool(ticket.get("keep_worktree", False)) or args.keep_worktree
        if (
            ticket["mode"] == "read_only"
            and not keep_worktree
            and not failed
            and not changed
            and worktree.exists()
        ):
            _git(repo, "worktree", "remove", str(worktree))

        print(json.dumps(summary, ensure_ascii=False, indent=2))
        return 1 if failed else 0
    except Exception:
        failure = {
            "status": "bridge_error",
            "run_id": run_id,
            "mode": "resume" if is_resume else "fresh",
            "worktree": str(worktree) if worktree else None,
            "branch": branch,
            "parent_run_id": parent_run_id,
            "root_run_id": root_run_id,
            "repair_round": repair_round,
        }
        _write_json(run_dir / "run-summary.json", failure)
        raise


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except BridgeError as exc:
        print(f"bridge error: {exc}", file=sys.stderr)
        raise SystemExit(2)
