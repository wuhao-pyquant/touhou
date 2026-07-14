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
    return value


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


def _session_identity(thread_id: str | None) -> dict[str, Any]:
    identity: dict[str, Any] = {
        "thread_id": thread_id,
        "model": None,
        "model_reasoning_effort": None,
        "cli_version": None,
        "session_file": None,
        "verified": False,
    }
    if not thread_id:
        return identity
    codex_home = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
    sessions = codex_home / "sessions"
    candidates: list[Path] = []
    for _ in range(15):
        if sessions.exists():
            candidates = list(sessions.rglob(f"*{thread_id}*.jsonl"))
        if candidates:
            break
        time.sleep(0.2)
    if not candidates:
        return identity
    session_file = max(candidates, key=lambda path: path.stat().st_mtime)
    identity["session_file"] = str(session_file)
    try:
        with session_file.open("r", encoding="utf-8", errors="replace") as stream:
            for index, raw_line in enumerate(stream):
                if index > 200:
                    break
                try:
                    entry = json.loads(raw_line)
                except json.JSONDecodeError:
                    continue
                if entry.get("type") == "session_meta":
                    payload = entry.get("payload", {})
                    identity["cli_version"] = payload.get("cli_version")
                elif entry.get("type") == "turn_context":
                    payload = entry.get("payload", {})
                    if identity["model"] is None:
                        identity["model"] = payload.get("model")
                    if identity["model_reasoning_effort"] is None:
                        identity["model_reasoning_effort"] = payload.get(
                            "model_reasoning_effort", payload.get("effort")
                        )
                    if identity["model"] and identity["model_reasoning_effort"]:
                        break
    except OSError:
        return identity
    identity["verified"] = bool(
        identity["model"] and identity["model_reasoning_effort"]
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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path)
    parser.add_argument("--agent", required=True)
    parser.add_argument("--ticket", required=True, type=Path)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--keep-worktree", action="store_true")
    args = parser.parse_args()

    repo = (
        args.repo_root.resolve()
        if args.repo_root
        else Path(_git(Path.cwd(), "rev-parse", "--show-toplevel")).resolve()
    )
    if not (repo / ".git").exists():
        raise BridgeError(f"Not a repository root: {repo}")

    ticket_path = args.ticket
    if not ticket_path.is_absolute():
        ticket_path = (repo / ticket_path).resolve()
    ticket = _load_json(ticket_path)
    _validate_ticket(ticket)
    profile_path = repo / ".codex" / "agents" / f"{args.agent}.toml"
    profile = _load_profile(profile_path)

    base_commit = _git(
        repo,
        "rev-parse",
        "--verify",
        f"{ticket['dependency_commit']}^{{commit}}",
    )
    timestamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_suffix = uuid.uuid4().hex[:8]
    run_id = (
        f"{timestamp}-{_safe_segment(ticket['id'])}-{_safe_segment(args.agent)}-"
        f"{run_suffix}"
    )
    run_dir = repo / ".agent-runs" / run_id
    run_dir.mkdir(parents=True, exist_ok=False)
    prompt = _build_prompt(profile, ticket)
    (run_dir / "prompt.txt").write_text(prompt, encoding="utf-8")

    worktree: Path | None = None
    branch: str | None = None
    codex = shutil.which(os.environ.get("CODEX_CLI", "codex"))
    if not codex:
        raise BridgeError("Could not locate the Codex CLI executable")

    try:
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

        requested_sandbox = str(profile["sandbox_mode"])
        sandbox = "read-only" if ticket["mode"] == "read_only" else requested_sandbox
        if ticket["mode"] == "write" and sandbox != "workspace-write":
            raise BridgeError(
                f"Write ticket requires workspace-write profile, got {sandbox}"
            )

        final_path = run_dir / "final.json"
        events_path = run_dir / "events.jsonl"
        stderr_path = run_dir / "stderr.log"
        report_schema = repo / "tools" / "agents" / "report.schema.json"
        command = [
            codex,
            "exec",
            "--strict-config",
            "-C",
            str(worktree),
            "-m",
            str(profile["model"]),
            "-c",
            f'model_reasoning_effort="{profile["model_reasoning_effort"]}"',
            "-s",
            sandbox,
            "--json",
            "--output-schema",
            str(report_schema),
            "-o",
            str(final_path),
            "-",
        ]
        invocation = {
            "run_id": run_id,
            "created_at": _utc_now(),
            "agent": args.agent,
            "ticket_id": ticket["id"],
            "ticket_path": str(ticket_path),
            "ticket_sha256": _sha256_text(
                ticket_path.read_text(encoding="utf-8-sig")
            ),
            "base_commit": base_commit,
            "worktree": str(worktree),
            "branch": branch,
            "requested_model": profile["model"],
            "requested_model_reasoning_effort": profile[
                "model_reasoning_effort"
            ],
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
                    "worktree": str(worktree),
                    "branch": branch,
                    "requested_model": profile["model"],
                    "requested_model_reasoning_effort": profile[
                        "model_reasoning_effort"
                    ],
                },
            )
            print(str(run_dir))
            return 0

        assert worktree is not None
        with (
            events_path.open("w", encoding="utf-8", newline="\n") as events,
            stderr_path.open("w", encoding="utf-8", newline="\n") as errors,
        ):
            process = subprocess.Popen(
                command,
                cwd=repo,
                stdin=subprocess.PIPE,
                stdout=events,
                stderr=errors,
                text=True,
                encoding="utf-8",
                errors="replace",
            )
            process.communicate(prompt)
        exit_code = process.returncode

        thread_id = _event_thread_id(events_path)
        runtime = _session_identity(thread_id)
        changed = _changed_paths(worktree, base_commit)
        violations = _policy_violations(ticket, changed)
        if ticket["mode"] == "read_only" and changed:
            violations.extend(f"read-only task changed: {path}" for path in changed)

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

        identity_problems: list[str] = []
        require_identity = bool(ticket.get("require_runtime_identity", True))
        if require_identity and not runtime["verified"]:
            identity_problems.append("runtime model identity could not be verified")
        if runtime["verified"]:
            if runtime["model"] != profile["model"]:
                identity_problems.append(
                    f"runtime model {runtime['model']!r} != requested {profile['model']!r}"
                )
            if runtime["model_reasoning_effort"] != profile["model_reasoning_effort"]:
                identity_problems.append(
                    "runtime reasoning effort "
                    f"{runtime['model_reasoning_effort']!r} != requested "
                    f"{profile['model_reasoning_effort']!r}"
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
            "agent": args.agent,
            "ticket_id": ticket["id"],
            "worktree": str(worktree),
            "branch": branch,
            "requested": {
                "model": profile["model"],
                "model_reasoning_effort": profile["model_reasoning_effort"],
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
            "worktree": str(worktree) if worktree else None,
            "branch": branch,
        }
        _write_json(run_dir / "run-summary.json", failure)
        raise


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except BridgeError as exc:
        print(f"bridge error: {exc}", file=sys.stderr)
        raise SystemExit(2)
