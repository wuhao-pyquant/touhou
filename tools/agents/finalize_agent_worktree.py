from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


class FinalizeError(RuntimeError):
    pass


def _git(repo: Path, *args: str, check: bool = True) -> str:
    process = subprocess.run(
        ["git", "-C", str(repo), *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if check and process.returncode != 0:
        detail = process.stderr.strip() or process.stdout.strip()
        raise FinalizeError(f"git {' '.join(args)} failed: {detail}")
    return process.stdout.strip()


def _normalized(path: Path) -> str:
    return str(path.resolve()).replace("\\", "/").casefold()


def _registered_worktrees(repo: Path) -> set[str]:
    registered: set[str] = set()
    for line in _git(repo, "worktree", "list", "--porcelain").splitlines():
        if line.startswith("worktree "):
            registered.add(_normalized(Path(line.removeprefix("worktree "))))
    return registered


def _active_worktrees(repo: Path) -> set[str]:
    active: set[str] = set()
    runs_root = repo / ".agent-runs"
    if not runs_root.exists():
        return active
    for marker in runs_root.glob("*/active.json"):
        invocation_path = marker.parent / "invocation.json"
        if not invocation_path.exists():
            raise FinalizeError(f"Active run has no invocation metadata: {marker.parent}")
        try:
            invocation = json.loads(invocation_path.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError) as exc:
            raise FinalizeError(f"Cannot read active invocation: {invocation_path}") from exc
        worktree = invocation.get("worktree")
        if not isinstance(worktree, str) or not worktree:
            raise FinalizeError(f"Active invocation has no worktree: {invocation_path}")
        active.add(_normalized(Path(worktree)))
    return active


def inspect_worktree(
    repo: Path,
    worktree: Path,
    *,
    target_branch: str = "master",
    superseded_by: str | None = None,
    superseded_reason: str | None = None,
) -> dict[str, Any]:
    repo = repo.resolve()
    worktree = worktree.resolve()
    worktrees_root = (repo / ".worktrees").resolve()
    try:
        worktree.relative_to(worktrees_root)
    except ValueError as exc:
        raise FinalizeError(f"Refusing path outside .worktrees: {worktree}") from exc
    if _normalized(worktree) not in _registered_worktrees(repo):
        raise FinalizeError(f"Not a registered Git worktree: {worktree}")
    if _normalized(worktree) in _active_worktrees(repo):
        raise FinalizeError(f"Worktree still belongs to an active Agent run: {worktree}")

    target_ref = f"refs/heads/{target_branch}"
    target_commit = _git(repo, "rev-parse", "--verify", f"{target_ref}^{{commit}}")
    status_lines = _git(worktree, "status", "--porcelain", "--untracked-files=all").splitlines()
    if status_lines:
        preview = "; ".join(status_lines[:5])
        raise FinalizeError(f"Worktree is dirty and requires release-lead disposition: {preview}")

    branch = _git(worktree, "branch", "--show-current") or None
    unique_commits: list[str] = []
    equivalent_commits: list[str] = []
    disposition = "detached_review"
    if branch is not None:
        if branch == target_branch:
            raise FinalizeError("Refusing to finalize the target branch worktree")
        if not branch.startswith("codex/"):
            raise FinalizeError(f"Refusing non-ticket branch: {branch}")
        for line in _git(repo, "cherry", target_branch, branch).splitlines():
            if line.startswith("+ "):
                unique_commits.append(line[2:])
            elif line.startswith("- "):
                equivalent_commits.append(line[2:])
        if unique_commits:
            if not superseded_by or not superseded_reason:
                raise FinalizeError(
                    "Ticket branch still has patch-unique commits; provide both "
                    "--superseded-by and --superseded-reason only after explicit adjudication"
                )
            replacement = _git(repo, "rev-parse", "--verify", f"{superseded_by}^{{commit}}")
            ancestor = subprocess.run(
                ["git", "-C", str(repo), "merge-base", "--is-ancestor", replacement, target_commit],
                capture_output=True,
            )
            if ancestor.returncode != 0:
                raise FinalizeError(
                    f"Superseding commit {replacement} is not contained in {target_branch}"
                )
            disposition = "superseded"
            superseded_by = replacement
        else:
            disposition = "integrated"

    return {
        "status": "eligible",
        "repo": str(repo),
        "worktree": str(worktree),
        "branch": branch,
        "target_branch": target_branch,
        "target_commit": target_commit,
        "disposition": disposition,
        "patch_unique_commits": unique_commits,
        "patch_equivalent_commits": equivalent_commits,
        "superseded_by": superseded_by,
        "superseded_reason": superseded_reason,
    }


def finalize_worktree(
    repo: Path,
    worktree: Path,
    *,
    target_branch: str = "master",
    superseded_by: str | None = None,
    superseded_reason: str | None = None,
    apply: bool = False,
) -> dict[str, Any]:
    result = inspect_worktree(
        repo,
        worktree,
        target_branch=target_branch,
        superseded_by=superseded_by,
        superseded_reason=superseded_reason,
    )
    result["applied"] = apply
    if not apply:
        return result

    resolved_repo = repo.resolve()
    resolved_worktree = worktree.resolve()
    branch = result["branch"]
    _git(resolved_repo, "worktree", "remove", str(resolved_worktree))
    if branch:
        _git(resolved_repo, "branch", "-D", branch)
    _git(resolved_repo, "worktree", "prune")
    result["status"] = "finalized"
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Safely retire a closed Agent worktree after integration."
    )
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--worktree", type=Path, required=True)
    parser.add_argument("--target-branch", default="master")
    parser.add_argument("--superseded-by")
    parser.add_argument("--superseded-reason")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args(argv)
    try:
        result = finalize_worktree(
            args.repo_root,
            args.worktree,
            target_branch=args.target_branch,
            superseded_by=args.superseded_by,
            superseded_reason=args.superseded_reason,
            apply=args.apply,
        )
        payload = json.dumps(result, ensure_ascii=False, indent=2)
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(payload + "\n", encoding="utf-8")
        print(payload)
        return 0
    except FinalizeError as exc:
        print(json.dumps({"status": "refused", "error": str(exc)}, ensure_ascii=False, indent=2))
        return 2


if __name__ == "__main__":
    sys.exit(main())
