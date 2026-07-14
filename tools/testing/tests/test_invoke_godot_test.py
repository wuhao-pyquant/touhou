from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
import unittest
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
RUNNER = ROOT / "tools" / "testing" / "invoke_godot_test.ps1"
FAKE = Path(__file__).with_name("fake_engine.py")
POWERSHELL = os.environ.get("POWERSHELL_EXE", "powershell.exe")


class InvokeGodotTestTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = Path(__file__).parent / f".invoke_godot_test_{uuid.uuid4().hex}"
        self.temp.mkdir()
        self.registry = self.temp / "processes.jsonl"
        self.registry.touch()
        self.old_registry = os.environ.get("FAKE_PROCESS_REGISTRY")
        os.environ["FAKE_PROCESS_REGISTRY"] = str(self.registry)
        self.project = self.temp / "project with spaces"
        self.project.mkdir()
        (self.project / "project.godot").write_text("[application]\nconfig/name=\"fake\"\n", encoding="utf-8")
        self.processes: list[subprocess.Popen[str]] = []

    def tearDown(self) -> None:
        for process in self.processes:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=5)
        if self.old_registry is None:
            os.environ.pop("FAKE_PROCESS_REGISTRY", None)
        else:
            os.environ["FAKE_PROCESS_REGISTRY"] = self.old_registry
        shutil.rmtree(self.temp)

    def run_runner(self, mode: str, *, timeout: int = 5, cleanup_existing: bool = False) -> tuple[subprocess.CompletedProcess[str], dict]:
        completed = subprocess.run(
            self.runner_command([str(FAKE), "--mode", mode], timeout=timeout, cleanup_existing=cleanup_existing),
            text=True, capture_output=True, timeout=20,
        )
        summaries = [line for line in completed.stdout.splitlines() if line.startswith("{")]
        self.assertTrue(summaries, msg=f"missing JSON summary\nstdout={completed.stdout}\nstderr={completed.stderr}")
        return completed, json.loads(summaries[-1])

    def runner_command(self, engine_args: list[str], *, timeout: int = 5, cleanup_existing: bool = False) -> list[str]:
        command = [
            POWERSHELL, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(RUNNER),
            "-GodotPath", sys.executable, "-ProjectPath", str(self.project),
            "-GodotArgumentJson", json.dumps(engine_args), "-TimeoutSeconds", str(timeout),
            "-PollMilliseconds", "50", "-LogFile", str(self.project / "runner.log"),
            "-ProcessInventoryFixture", str(self.registry),
        ]
        if cleanup_existing:
            command.append("-CleanupExisting")
        return command

    def start_existing(self, project: Path | None, *, headless: bool = True) -> subprocess.Popen[str]:
        command = [sys.executable, str(FAKE), "--mode", "sleep", "--duration", "30"]
        if headless:
            command.append("--headless")
        if project is not None:
            command.extend(["--path", str(project)])
        process = subprocess.Popen(command, text=True)
        self.processes.append(process)
        time.sleep(0.2)
        return process

    def test_success_writes_machine_summary(self) -> None:
        completed, summary = self.run_runner("success")
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(summary["category"], "Success")
        self.assertEqual(summary["status"], "passed")
        self.assertEqual(Path(summary["project"]), self.project.resolve())
        self.assertTrue(summary["logPath"])

    def test_nonzero_exit_is_failure(self) -> None:
        completed, summary = self.run_runner("nonzero")
        self.assertEqual(completed.returncode, 1)
        self.assertEqual(summary["category"], "ProcessFailure")
        self.assertEqual(summary["processExitCode"], 17)

    def test_fatal_pattern_with_zero_exit_is_failure(self) -> None:
        completed, summary = self.run_runner("fatal")
        self.assertEqual(completed.returncode, 3)
        self.assertEqual(summary["category"], "FatalOutput")
        self.assertEqual(summary["processExitCode"], 0)

    def test_timeout_kills_descendant(self) -> None:
        # The fake engine creates a child then keeps both processes alive.
        command = self.runner_command(
            [str(FAKE), "--mode", "sleep", "--spawn-child", "--duration", "30"], timeout=1
        )
        completed = subprocess.run(command, text=True, capture_output=True, timeout=20)
        summary = json.loads([line for line in completed.stdout.splitlines() if line.startswith("{")][-1])
        self.assertEqual(completed.returncode, 2, completed.stderr)
        self.assertEqual(summary["category"], "Timeout")
        self.assertGreaterEqual(len(summary["cleanedPids"]), 2)
        for pid in summary["cleanedPids"]:
            self.assertFalse(_pid_exists(pid), f"surviving invocation PID {pid}")

    def test_lock_contention_rejects_second_runner(self) -> None:
        command = self.runner_command([str(FAKE), "--mode", "sleep", "--duration", "3"], timeout=10)
        first = subprocess.Popen(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            time.sleep(0.5)
            completed, summary = self.run_runner("success")
            self.assertEqual(completed.returncode, 4)
            self.assertEqual(summary["category"], "LockContention")
        finally:
            stdout, stderr = first.communicate(timeout=15)
            self.assertEqual(first.returncode, 0, f"stdout={stdout}\nstderr={stderr}")

    def test_path_scoping_and_no_collateral_termination(self) -> None:
        same_project = self.start_existing(self.project, headless=True)
        other_project = self.temp / "other"
        other_project.mkdir()
        (other_project / "project.godot").write_text("[application]\n", encoding="utf-8")
        other_headless = self.start_existing(other_project, headless=True)
        same_project_not_headless = self.start_existing(self.project, headless=False)

        completed, summary = self.run_runner("success", cleanup_existing=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(summary["category"], "Success")
        self.assertIsNotNone(same_project.poll(), "scoped stale headless process was not removed")
        self.assertIsNone(other_headless.poll(), "other project process was killed")
        self.assertIsNone(same_project_not_headless.poll(), "non-headless process was killed")

    def test_preexisting_same_project_headless_fails_without_cleanup(self) -> None:
        existing = self.start_existing(self.project, headless=True)
        completed, summary = self.run_runner("success")
        self.assertEqual(completed.returncode, 5)
        self.assertEqual(summary["category"], "PreexistingHeadlessProcess")
        self.assertIsNone(existing.poll(), "default inventory must not kill existing processes")


def _pid_exists(pid: int) -> bool:
    completed = subprocess.run(
        [POWERSHELL, "-NoProfile", "-Command", f"[bool](Get-Process -Id {pid} -ErrorAction SilentlyContinue)"],
        text=True, capture_output=True, check=True,
    )
    return completed.stdout.strip().lower() == "true"


if __name__ == "__main__":
    unittest.main()
