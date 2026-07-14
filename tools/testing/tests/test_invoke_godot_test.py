from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import time
import unittest
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
RUNNER = ROOT / "tools" / "testing" / "invoke_godot_test.ps1"
FAKE_BUILDER = Path(__file__).with_name("fake_engine.py")
POWERSHELL = os.environ.get("POWERSHELL_EXE", "powershell.exe")
RUN_EXPRESSION = (
    "& $env:GTR_RUNNER -GodotPath $env:GTR_ENGINE -ProjectPath $env:GTR_PROJECT "
    "-GodotArgumentJson $env:GTR_ARGS -TimeoutSeconds ([int]$env:GTR_TIMEOUT) "
    "-PollMilliseconds 25 -LogFile $env:GTR_LOG -WorkerFault $env:GTR_FAULT "
    "-CleanupExisting:([bool]::Parse($env:GTR_CLEANUP)) "
    "-AbiCheckOnly:([bool]::Parse($env:GTR_ABI)); exit $LASTEXITCODE"
)


class InvokeGodotTestTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.class_temp = Path(__file__).parent / f".invoke_godot_test_{uuid.uuid4().hex}"
        cls.class_temp.mkdir()
        cls.engine = cls.class_temp / "fake-godot.exe"
        subprocess.run([sys.executable, str(FAKE_BUILDER), "--build", str(cls.engine)], check=True)

    @classmethod
    def tearDownClass(cls) -> None:
        shutil.rmtree(cls.class_temp, ignore_errors=True)

    def setUp(self) -> None:
        self.temp = self.class_temp / uuid.uuid4().hex
        self.temp.mkdir()
        self.project = self.temp / "project with spaces"
        self.project.mkdir()
        (self.project / "project.godot").write_text("[application]\n", encoding="utf-8")
        self.processes: list[subprocess.Popen[str]] = []
        self.logs: list[Path] = []

    def tearDown(self) -> None:
        for process in self.processes:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=5)
        for log in self.logs:
            for candidate in (log, Path(str(log) + ".stdout"), Path(str(log) + ".stderr")):
                candidate.unlink(missing_ok=True)
        shutil.rmtree(self.temp, ignore_errors=True)

    def invocation(
        self,
        *engine_args: str,
        timeout: int = 5,
        fault: str = "",
        cleanup: bool = False,
        abi: bool = False,
        powershell: str = POWERSHELL,
        engine: Path | None = None,
    ) -> tuple[list[str], dict[str, str]]:
        env = os.environ.copy()
        log = Path(env.get("TEMP", str(self.temp))) / f"gtr-{uuid.uuid4().hex}.log"
        self.logs.append(log)
        env.update(
            GTR_RUNNER=str(RUNNER),
            GTR_ENGINE=str(engine or self.engine),
            GTR_PROJECT=str(self.project),
            GTR_ARGS=json.dumps(list(engine_args) or ["--mode", "success"]),
            GTR_TIMEOUT=str(timeout),
            GTR_LOG=str(log),
            GTR_FAULT=fault,
            GTR_CLEANUP=str(cleanup),
            GTR_ABI=str(abi),
        )
        return [powershell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", RUN_EXPRESSION], env

    def execute(self, *engine_args: str, **options: object) -> tuple[subprocess.CompletedProcess[str], dict]:
        command, env = self.invocation(*engine_args, **options)
        completed = subprocess.run(command, env=env, text=True, capture_output=True, timeout=20)
        lines = [line for line in completed.stdout.splitlines() if line.startswith("{")]
        self.assertEqual(len(lines), 1, f"stdout={completed.stdout}\nstderr={completed.stderr}")
        return completed, json.loads(lines[0])

    def assert_category(self, expected_code: int, expected: str, *args: str, **options: object) -> dict:
        completed, summary = self.execute(*args, **options)
        self.assertEqual((completed.returncode, summary["category"]), (expected_code, expected), completed.stderr)
        return summary

    def assert_recorded_processes_gone(self, summary: dict) -> None:
        capture = Path(str(summary["logPath"]) + ".stdout")
        pids = [int(value) for value in re.findall(r"(?:ROOT|CHILD|GRANDCHILD)_PID=(\d+)", capture.read_text(errors="replace"))]
        self.assertTrue(pids, "fake engine never reached executable code")
        time.sleep(0.1)
        for pid in pids:
            result = subprocess.run(
                [POWERSHELL, "-NoProfile", "-Command", f"[bool](Get-Process -Id {pid} -ErrorAction SilentlyContinue)"],
                text=True,
                capture_output=True,
                check=True,
            )
            self.assertEqual(result.stdout.strip().lower(), "false", f"surviving contained PID {pid}")

    # Frozen blocker matrix 01: supervisor deadline includes a post-READY worker hang,
    # kills the worker, and releases the held Global mutex for the next invocation.
    def test_01_supervisor_bounds_hang_and_releases_mutex(self) -> None:
        self.assert_category(2, "Timeout", fault="hang-after-go", timeout=1)
        self.assert_category(0, "Success", abi=True)

    # 02: malformed/partial protocol can produce only the public JSON result.
    def test_02_partial_protocol_yields_one_json(self) -> None:
        completed, _ = self.execute(fault="partial", timeout=1)
        self.assertNotEqual(completed.returncode, 0)
        self.assertEqual(len([line for line in completed.stdout.splitlines() if line.startswith("{")]), 1)

    # 03: denial, contention, and abandonment are fail-closed LockContention paths.
    def test_03_global_mutex_denial_contention_abandonment(self) -> None:
        for fault in ("global-denied", "global-abandoned"):
            with self.subTest(fault=fault):
                self.assert_category(4, "LockContention", fault=fault)
        command, env = self.invocation("--mode", "sleep", "--duration", "2", timeout=8)
        first = subprocess.Popen(command, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            time.sleep(0.5)
            self.assert_category(4, "LockContention")
        finally:
            first.communicate(timeout=12)

    # 04: a JOB_LIST setup failure is LaunchFailure and never starts the fake engine.
    def test_04_job_attribute_failure_never_resumes(self) -> None:
        summary = self.assert_category(8, "LaunchFailure", fault="job-attribute")
        self.assertIsNone(summary["processExitCode"])

    # 05: failure immediately after atomic create is classified and contained.
    def test_05_atomic_create_pre_resume_failure_is_contained(self) -> None:
        summary = self.assert_category(8, "LaunchFailure", fault="post-create-kill")
        self.assertIsNone(summary["processExitCode"])
        self.assertFalse(Path(str(summary["logPath"]) + ".stdout").read_text(errors="replace").strip())

    # 06: post-create identity failure follows the suspended-job cleanup path.
    def test_06_post_create_identity_failure_is_contained(self) -> None:
        summary = self.assert_category(8, "LaunchFailure", fault="post-create-identity")
        self.assertIsNone(summary["processExitCode"])
        self.assertFalse(Path(str(summary["logPath"]) + ".stdout").read_text(errors="replace").strip())

    # 07: an inherited-stream orphan cannot extend the one watchdog budget.
    def test_07_inherited_stream_orphan_is_bounded(self) -> None:
        summary = self.assert_category(2, "Timeout", "--mode", "success", "--spawn-child", "--duration", "30", timeout=3)
        self.assert_recorded_processes_gone(summary)

    # 08: a child/grandchild tree is killed by closing/terminating the sole job.
    def test_08_child_grandchild_job_tree_cleanup(self) -> None:
        summary = self.assert_category(2, "Timeout", "--mode", "sleep", "--spawn-grandchild", "--duration", "30", timeout=3)
        self.assert_recorded_processes_gone(summary)

    # 09: inaccessible or otherwise unverifiable same-basename inventory blocks launch.
    def test_09_unverifiable_same_basename_is_cleanup_failure(self) -> None:
        self.assert_category(7, "CleanupFailure", fault="inventory-denied")

    # 10: both Toolhelp enumeration failure points fail closed.
    def test_10_toolhelp_first_and_next_errors_fail_closed(self) -> None:
        for fault in ("toolhelp-first", "toolhelp-next"):
            with self.subTest(fault=fault):
                self.assert_category(7, "CleanupFailure", fault=fault)

    # 11: Windows quoting preserves spaces; a duplicate caller-owned path is rejected.
    def test_11_windows_quoting_and_duplicate_path(self) -> None:
        self.assert_category(0, "Success", "--mode", "success")
        self.assert_category(6, "InvalidInput", "--path", str(self.project))

    # 12: an exact-image process for another canonical project is collateral and survives.
    def test_12_canonical_project_and_exact_image_preserve_collateral(self) -> None:
        other = self.temp / "other"
        other.mkdir()
        (other / "project.godot").write_text("[application]\n", encoding="utf-8")
        collateral = subprocess.Popen(
            [str(self.engine), "--mode", "sleep", "--duration", "30", "--headless", "--path", str(other)],
            text=True,
        )
        self.processes.append(collateral)
        time.sleep(0.2)
        self.assert_category(0, "Success", cleanup=True)
        self.assertIsNone(collateral.poll())

    # 13: a retained identity mismatch is CleanupFailure, never PID-authorized killing.
    def test_13_retained_handle_identity_blocks_pid_reuse(self) -> None:
        existing = subprocess.Popen(
            [str(self.engine), "--mode", "sleep", "--duration", "30", "--headless", "--path", str(self.project)],
            text=True,
        )
        self.processes.append(existing)
        time.sleep(0.2)
        self.assert_category(7, "CleanupFailure", fault="retained-identity", cleanup=True)
        self.assertIsNone(existing.poll())

    # 14: private failure seams cannot authorize cleanup of a collateral process.
    def test_14_fault_seams_cannot_authorize_kill(self) -> None:
        collateral = subprocess.Popen([str(self.engine), "--mode", "sleep", "--duration", "30"], text=True)
        self.processes.append(collateral)
        time.sleep(0.2)
        self.assert_category(7, "CleanupFailure", fault="inventory-denied", cleanup=True)
        self.assertIsNone(collateral.poll())

    # 15: public invalid input and native create/resume failures have exact categories.
    def test_15_invalid_create_and_resume_categories(self) -> None:
        self.assert_category(6, "InvalidInput", engine=self.temp / "missing.exe")
        for fault in ("create-failure", "resume-failure"):
            with self.subTest(fault=fault):
                self.assert_category(8, "LaunchFailure", fault=fault)

    # 16: compile and execute the native ABI assertions under both Windows bitnesses.
    def test_16_x86_x64_native_abi_layouts(self) -> None:
        helpers = [
            Path(os.environ["WINDIR"]) / "System32" / "WindowsPowerShell" / "v1.0" / "powershell.exe",
            Path(os.environ["WINDIR"]) / "SysWOW64" / "WindowsPowerShell" / "v1.0" / "powershell.exe",
        ]
        for helper in helpers:
            self.assertTrue(helper.is_file(), f"required configured ABI helper unavailable: {helper}")
            with self.subTest(helper=str(helper)):
                self.assert_category(0, "Success", abi=True, powershell=str(helper))

    # 17: cleanup proof failure has precedence over timeout/fatal/nonzero outcomes.
    def test_17_cleanup_failure_precedence(self) -> None:
        for mode in ("sleep", "fatal", "nonzero"):
            with self.subTest(mode=mode):
                self.assert_category(7, "CleanupFailure", "--mode", mode, fault="cleanup-overrides", timeout=3 if mode == "sleep" else 5)

    # 18: success needs root zero/job empty/complete output; fatal beats nonzero.
    def test_18_success_and_fatal_over_nonzero(self) -> None:
        summary = self.assert_category(0, "Success", "--mode", "success")
        self.assertEqual(summary["status"], "passed")
        self.assert_category(3, "FatalOutput", "--mode", "fatal-nonzero")


if __name__ == "__main__":
    unittest.main()
