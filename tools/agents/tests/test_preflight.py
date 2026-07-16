from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tools.agents import preflight


class PreflightTests(unittest.TestCase):
    def temporary_directory(self, prefix: str = "preflight-") -> tempfile.TemporaryDirectory[str]:
        root = Path.cwd() / ".tmp-preflight-tests"
        root.mkdir(exist_ok=True)
        return tempfile.TemporaryDirectory(prefix=prefix, dir=root)

    def test_cache_reuses_the_same_environment_fingerprint(self) -> None:
        with self.temporary_directory(prefix="preflight space ") as temporary:
            repo = Path(temporary)
            (repo / ".worktrees").mkdir()
            codex = repo / "codex.exe"
            godot = repo / "godot.exe"
            codex.write_text("", encoding="utf-8")
            godot.write_text("", encoding="utf-8")
            calls = {"probe": 0}
            def version(command: list[str], _: Path) -> str:
                return "codex-cli 0.144.4" if command[0] == str(codex) else "4.7"
            def probe(_: Path, __: Path) -> None:
                calls["probe"] += 1
            with mock.patch.object(preflight, "_resolve_executable", side_effect=[codex, godot, codex, godot]):
                first = preflight.run_session_preflight(repo, temp_root=repo, version_runner=version, process_probe=lambda _: [], mutex_probe=lambda _: True, codex_probe=probe)
                second = preflight.run_session_preflight(repo, temp_root=repo, version_runner=version, process_probe=lambda _: [], mutex_probe=lambda _: True, codex_probe=probe)
            self.assertFalse(first["cached"])
            self.assertTrue(second["cached"])
            self.assertEqual(calls["probe"], 1)

    def test_preflight_rejects_mutex_contention_without_running_probe(self) -> None:
        with self.temporary_directory() as temporary:
            repo = Path(temporary)
            (repo / ".worktrees").mkdir()
            binary = repo / "tool.exe"
            binary.write_text("", encoding="utf-8")
            with mock.patch.object(preflight, "_resolve_executable", return_value=binary):
                with self.assertRaisesRegex(preflight.PreflightError, "contended"):
                    preflight.run_session_preflight(repo, temp_root=repo, version_runner=lambda *_: "v", process_probe=lambda _: [], mutex_probe=lambda _: False, codex_probe=lambda *_: self.fail("probe ran"))


if __name__ == "__main__":
    unittest.main()
