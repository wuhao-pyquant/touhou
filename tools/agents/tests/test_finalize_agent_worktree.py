from __future__ import annotations

import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "finalize_agent_worktree.py"
SPEC = importlib.util.spec_from_file_location("finalize_agent_worktree", MODULE_PATH)
assert SPEC and SPEC.loader
FINALIZER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(FINALIZER)


class FinalizeAgentWorktreeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.repo = Path(self.temporary.name) / "repo"
        self.repo.mkdir()
        self._git(self.repo, "init", "-b", "master")
        self._git(self.repo, "config", "user.name", "Test")
        self._git(self.repo, "config", "user.email", "test@example.com")
        (self.repo / ".gitignore").write_text(".worktrees/\n.agent-runs/\n", encoding="utf-8")
        (self.repo / "base.txt").write_text("base\n", encoding="utf-8")
        self._git(self.repo, "add", ".")
        self._git(self.repo, "commit", "-m", "base")

    def tearDown(self) -> None:
        self.temporary.cleanup()

    @staticmethod
    def _git(repo: Path, *args: str) -> str:
        process = subprocess.run(
            ["git", "-C", str(repo), *args],
            check=True,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        return process.stdout.strip()

    def _ticket_worktree(self, name: str = "ticket") -> tuple[Path, str]:
        worktree = self.repo / ".worktrees" / name
        branch = f"codex/{name}"
        self._git(self.repo, "worktree", "add", "-b", branch, str(worktree), "master")
        (worktree / "base.txt").write_text(f"{name}\n", encoding="utf-8")
        self._git(worktree, "add", "base.txt")
        self._git(worktree, "commit", "-m", name)
        return worktree, branch

    def test_finalizes_patch_equivalent_ticket_branch(self) -> None:
        worktree, branch = self._ticket_worktree()
        candidate = self._git(worktree, "rev-parse", "HEAD")
        self._git(self.repo, "cherry-pick", candidate)

        preview = FINALIZER.finalize_worktree(self.repo, worktree)
        self.assertEqual(preview["disposition"], "integrated")
        self.assertFalse(preview["applied"])
        result = FINALIZER.finalize_worktree(self.repo, worktree, apply=True)

        self.assertEqual(result["status"], "finalized")
        self.assertFalse(worktree.exists())
        branch_check = subprocess.run(
            ["git", "-C", str(self.repo), "show-ref", "--verify", f"refs/heads/{branch}"],
            capture_output=True,
        )
        self.assertNotEqual(branch_check.returncode, 0)

    def test_refuses_patch_unique_ticket_without_adjudication(self) -> None:
        worktree, _ = self._ticket_worktree()
        with self.assertRaisesRegex(FINALIZER.FinalizeError, "patch-unique"):
            FINALIZER.finalize_worktree(self.repo, worktree)

    def test_accepts_explicit_superseding_commit_on_target(self) -> None:
        worktree, _ = self._ticket_worktree()
        (self.repo / "replacement.txt").write_text("replacement\n", encoding="utf-8")
        self._git(self.repo, "add", "replacement.txt")
        self._git(self.repo, "commit", "-m", "replacement")
        replacement = self._git(self.repo, "rev-parse", "HEAD")

        result = FINALIZER.finalize_worktree(
            self.repo,
            worktree,
            superseded_by=replacement,
            superseded_reason="replacement implementation passed the milestone gate",
        )

        self.assertEqual(result["disposition"], "superseded")
        self.assertEqual(result["superseded_by"], replacement)

    def test_refuses_dirty_worktree(self) -> None:
        worktree, _ = self._ticket_worktree()
        (worktree / "untracked.log").write_text("keep\n", encoding="utf-8")
        with self.assertRaisesRegex(FINALIZER.FinalizeError, "dirty"):
            FINALIZER.finalize_worktree(
                self.repo,
                worktree,
                superseded_by=self._git(self.repo, "rev-parse", "master"),
                superseded_reason="explicit test override",
            )


if __name__ == "__main__":
    unittest.main()
