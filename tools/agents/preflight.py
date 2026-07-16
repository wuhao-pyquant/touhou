#!/usr/bin/env python3
"""Session admission checks for the independent Codex bridge.

The checks are deliberately small and serializable: a caller can persist their
fingerprint once for a batch, while unit tests can inject every external probe.
No Godot scene is ever started by this module.
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Callable


class PreflightError(RuntimeError):
    """The execution environment is not safe to admit a new ticket."""


def _run(command: list[str], cwd: Path) -> str:
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if result.returncode:
        raise PreflightError(f"preflight command failed ({result.returncode}): {' '.join(command)}")
    return result.stdout.strip()


def _resolve_executable(value: str | None, label: str) -> Path:
    candidate = shutil.which(value) if value else None
    if not candidate:
        raise PreflightError(f"could not resolve {label} executable")
    path = Path(candidate).resolve()
    if not path.is_file():
        raise PreflightError(f"resolved {label} executable is not a file: {path}")
    return path


def _writable_root(path: Path, label: str, *, create: bool = False) -> Path:
    resolved = path.resolve()
    if create:
        resolved.mkdir(parents=True, exist_ok=True)
    if not resolved.is_dir():
        raise PreflightError(f"{label} root is not a directory: {resolved}")
    try:
        with tempfile.NamedTemporaryFile(prefix=".preflight-", dir=resolved, delete=True):
            pass
    except OSError as exc:
        raise PreflightError(f"{label} root is not writable: {resolved}: {exc}") from exc
    return resolved


def _disk_ok(path: Path) -> dict[str, int]:
    usage = shutil.disk_usage(path)
    if usage.free <= 0:
        raise PreflightError(f"no free disk space at {path}")
    return {"free": usage.free, "total": usage.total}


def _residual_processes(project: Path) -> list[str]:
    """Return only project-scoped Godot/Codex processes; never terminates them."""
    if os.name != "nt":
        return []
    script = (
        "$p=" + repr(str(project)) + ";"
        "Get-CimInstance Win32_Process | Where-Object { "
        "$_.Name -match '^(godot|codex)(\\.exe)?$' -and $_.CommandLine -like ('*'+$p+'*') "
        "} | ForEach-Object { $_.ProcessId }"
    )
    output = _run(["powershell", "-NoProfile", "-Command", script], project)
    return [line.strip() for line in output.splitlines() if line.strip()]


def _mutex_available(project: Path) -> bool:
    """The supervisor derives this name from project identity at runtime.

    Preflight can only ensure its one repository-wide admission sentinel is
    free; the actual supervisor remains sole owner of its Global mutex.
    """
    lock = project / ".agent-runs" / ".godot-admission.lock"
    try:
        lock.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        os.close(fd)
        lock.unlink()
        return True
    except FileExistsError:
        return False
    except OSError as exc:
        raise PreflightError(f"could not check Godot admission mutex: {exc}") from exc


def build_fingerprint(
    *,
    repo: Path,
    codex: Path,
    codex_version: str,
    godot: Path,
    godot_version: str,
    temp_root: Path,
) -> tuple[str, dict[str, Any]]:
    payload = {
        "repo": str(repo.resolve()),
        "codex": str(codex.resolve()),
        "codex_version": codex_version,
        "godot": str(godot.resolve()),
        "godot_version": godot_version,
        "temp_root": str(temp_root.resolve()),
    }
    rendered = json.dumps(payload, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(rendered.encode("utf-8")).hexdigest(), payload


def run_session_preflight(
    repo: Path,
    *,
    codex_cli: str | None = None,
    godot_cli: str | None = None,
    temp_root: Path | None = None,
    version_runner: Callable[[list[str], Path], str] = _run,
    process_probe: Callable[[Path], list[str]] = _residual_processes,
    mutex_probe: Callable[[Path], bool] = _mutex_available,
    codex_probe: Callable[[Path, Path], None] | None = None,
) -> dict[str, Any]:
    """Perform or reuse the one-per-fingerprint session admission check.

    ``codex_probe`` is intentionally injectable because it writes a temporary
    schema/final file. Production callers supply the minimal CLI final.json
    probe; unit tests prove its contract without contacting a model service.
    """
    repo = _writable_root(repo, "project")
    worktrees = _writable_root(repo / ".worktrees", "worktree", create=True)
    temp = _writable_root(temp_root or Path(tempfile.gettempdir()), "temporary")
    codex = _resolve_executable(codex_cli or os.environ.get("CODEX_CLI", "codex"), "Codex")
    godot_name = godot_cli or os.environ.get("GODOT_CLI") or os.environ.get("GODOT_PATH")
    godot = _resolve_executable(godot_name, "Godot")
    codex_version = version_runner([str(codex), "--version"], repo)
    godot_version = version_runner([str(godot), "--version"], repo)
    fingerprint, fingerprint_input = build_fingerprint(
        repo=repo, codex=codex, codex_version=codex_version,
        godot=godot, godot_version=godot_version, temp_root=temp,
    )
    cache_path = repo / ".agent-runs" / "preflight-cache.json"
    if cache_path.exists():
        try:
            cached = json.loads(cache_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            cached = {}
        if cached.get("fingerprint") == fingerprint and cached.get("status") == "passed":
            return {**cached, "cached": True}
    residual = process_probe(repo)
    if residual:
        raise PreflightError("residual project Codex/Godot process(es): " + ", ".join(residual))
    if not mutex_probe(repo):
        raise PreflightError("Godot admission mutex is contended")
    if codex_probe is not None:
        codex_probe(codex, temp)
    evidence = {
        "status": "passed",
        "cached": False,
        "fingerprint": fingerprint,
        "fingerprint_input": fingerprint_input,
        "roots": {"project": str(repo), "worktrees": str(worktrees), "temp": str(temp)},
        "disk": {"project": _disk_ok(repo), "temp": _disk_ok(temp)},
        "profile_loader": "leaf CLI disables use_agent_identity",
    }
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    cache_path.write_text(json.dumps(evidence, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return evidence
