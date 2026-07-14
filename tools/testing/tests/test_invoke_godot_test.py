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
import ctypes
from ctypes import wintypes
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
RUNNER = ROOT / "tools" / "testing" / "invoke_godot_test.ps1"
FAKE_BUILDER = Path(__file__).with_name("fake_engine.py")
POWERSHELL = os.environ.get("POWERSHELL_EXE", "powershell.exe")
TH32CS_SNAPPROCESS = 0x00000002
SYNCHRONIZE = 0x00100000
WAIT_TIMEOUT = 258


class ProcessEntry32W(ctypes.Structure):
    _fields_ = [
        ("dwSize", wintypes.DWORD),
        ("cntUsage", wintypes.DWORD),
        ("th32ProcessID", wintypes.DWORD),
        ("th32DefaultHeapID", ctypes.c_size_t),
        ("th32ModuleID", wintypes.DWORD),
        ("cntThreads", wintypes.DWORD),
        ("th32ParentProcessID", wintypes.DWORD),
        ("pcPriClassBase", wintypes.LONG),
        ("dwFlags", wintypes.DWORD),
        ("szExeFile", wintypes.WCHAR * 260),
    ]
RUN_EXPRESSION = (
    "& $env:GTR_RUNNER -GodotPath $env:GTR_ENGINE -ProjectPath $env:GTR_PROJECT "
    "-GodotArgumentJson $env:GTR_ARGS -TimeoutSeconds ([int]$env:GTR_TIMEOUT) "
    "-PollMilliseconds 25 -LogFile $env:GTR_LOG -WorkerFault $env:GTR_FAULT "
    "-CleanupExisting:([bool]::Parse($env:GTR_CLEANUP)); exit $LASTEXITCODE"
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
                descendants = self.child_pids(process.pid)
                process.kill()
                process.wait(timeout=5)
                deadline = time.monotonic() + 5
                while any(self.pid_alive(pid) for pid in descendants) and time.monotonic() < deadline:
                    time.sleep(0.02)
        for log in self.logs:
            for candidate in (log, Path(str(log) + ".stdout"), Path(str(log) + ".stderr")):
                deadline = time.monotonic() + 2
                while True:
                    try:
                        candidate.unlink(missing_ok=True)
                        break
                    except PermissionError:
                        if time.monotonic() >= deadline:
                            raise
                        time.sleep(0.02)
        shutil.rmtree(self.temp, ignore_errors=True)

    def invocation(
        self,
        *engine_args: str,
        timeout: int = 5,
        fault: str = "",
        cleanup: bool = False,
        powershell: str = POWERSHELL,
        engine: Path | None = None,
        project: Path | None = None,
    ) -> tuple[list[str], dict[str, str]]:
        env = os.environ.copy()
        log = Path(env.get("TEMP", str(self.temp))) / f"gtr-{uuid.uuid4().hex}.log"
        self.logs.append(log)
        env.update(
            GTR_RUNNER=str(RUNNER),
            GTR_ENGINE=str(engine or self.engine),
            GTR_PROJECT=str(project or self.project),
            GTR_ARGS=json.dumps(list(engine_args) or ["--mode", "success"]),
            GTR_TIMEOUT=str(timeout),
            GTR_LOG=str(log),
            GTR_FAULT=fault,
            GTR_CLEANUP=str(cleanup),
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

    @staticmethod
    def child_pids(parent_pid: int, executable: str | None = None) -> list[int]:
        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel32.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
        snapshot = kernel32.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
        invalid = wintypes.HANDLE(-1).value
        if snapshot == invalid:
            raise ctypes.WinError(ctypes.get_last_error())
        entry = ProcessEntry32W()
        entry.dwSize = ctypes.sizeof(entry)
        children: list[int] = []
        try:
            if kernel32.Process32FirstW(snapshot, ctypes.byref(entry)):
                while True:
                    if entry.th32ParentProcessID == parent_pid and (
                        executable is None or entry.szExeFile.casefold() == executable.casefold()
                    ):
                        children.append(int(entry.th32ProcessID))
                    entry.dwSize = ctypes.sizeof(entry)
                    if not kernel32.Process32NextW(snapshot, ctypes.byref(entry)):
                        break
        finally:
            if not kernel32.CloseHandle(snapshot):
                raise ctypes.WinError(ctypes.get_last_error())
        return children

    @staticmethod
    def pid_alive(pid: int) -> bool:
        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel32.OpenProcess.restype = wintypes.HANDLE
        handle = kernel32.OpenProcess(SYNCHRONIZE, False, pid)
        if not handle:
            return False
        try:
            return kernel32.WaitForSingleObject(handle, 0) == WAIT_TIMEOUT
        finally:
            if not kernel32.CloseHandle(handle):
                raise ctypes.WinError(ctypes.get_last_error())

    def wait_for_child(self, parent_pid: int, executable: str | None = None, timeout: float = 8.0) -> int:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            children = self.child_pids(parent_pid, executable)
            if children:
                return children[0]
            time.sleep(0.02)
        self.fail(f"no child observed for PID {parent_pid}")

    def assert_pid_gone(self, pid: int, timeout: float = 5.0) -> None:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if not self.pid_alive(pid):
                return
            time.sleep(0.02)
        self.fail(f"PID {pid} survived its containment deadline")

    # Frozen blocker matrix 01: supervisor deadline includes a post-READY worker hang,
    # kills the worker, and releases the held Global mutex for the next invocation.
    def test_01_supervisor_bounds_hang_and_releases_mutex(self) -> None:
        self.assert_category(2, "Timeout", fault="hang-after-go", timeout=1)
        self.assert_category(0, "Success")

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

    # 16: both bitnesses compile ABI checks and execute the normal fake-engine path.
    def test_16_x86_x64_native_abi_layouts(self) -> None:
        helpers = [
            Path(os.environ["WINDIR"]) / "System32" / "WindowsPowerShell" / "v1.0" / "powershell.exe",
            Path(os.environ["WINDIR"]) / "SysWOW64" / "WindowsPowerShell" / "v1.0" / "powershell.exe",
        ]
        for helper in helpers:
            self.assertTrue(helper.is_file(), f"required configured ABI helper unavailable: {helper}")
            with self.subTest(helper=str(helper)):
                self.assert_category(0, "Success", "--mode", "success", powershell=str(helper))

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

    # 19: watcher initialization is synchronous and cannot authorize inventory or resume.
    def test_19_supervisor_watch_failure_fails_closed(self) -> None:
        self.assert_category(7, "CleanupFailure", fault="watcher-failure")

    # 20: a cap+1 capture is a bounded CleanupFailure, never a success/timeout.
    def test_20_capture_cap_plus_one_fails_closed(self) -> None:
        self.assert_category(7, "CleanupFailure", "--mode", "capture-overflow")
        self.assert_category(7, "CleanupFailure", fault="capture-read-failure")
        self.assert_category(0, "Success", "--mode", "success")

    # 21: kill the real supervisor only after its mutex proves the worker reached
    # the pre-inventory pause.  The retained watcher must exit the worker before
    # it can terminate the verified preexisting target.
    def test_21_supervisor_death_before_inventory_prevents_cleanup(self) -> None:
        existing = subprocess.Popen(
            [str(self.engine), "--mode", "sleep", "--duration", "30", "--headless", "--path", str(self.project)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        self.processes.append(existing)
        command, env = self.invocation(fault="pause-before-inventory", cleanup=True, timeout=15)
        supervisor = subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.processes.append(supervisor)
        worker_pid = self.wait_for_child(supervisor.pid, Path(command[0]).name)
        self.assert_category(4, "LockContention", timeout=5)
        supervisor.kill()
        supervisor.communicate(timeout=5)
        self.assert_pid_gone(worker_pid)
        self.assertIsNone(existing.poll(), "preexisting target mutated after supervisor death")

    # 22: observe the real suspended fake engine as the worker child, then kill
    # the real supervisor.  The watcher exits the worker and sole job closure
    # contains the never-resumed engine.
    def test_22_supervisor_death_before_resume_contains_suspended_engine(self) -> None:
        command, env = self.invocation(fault="pause-before-resume", timeout=15)
        supervisor = subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.processes.append(supervisor)
        worker_pid = self.wait_for_child(supervisor.pid, Path(command[0]).name)
        engine_pid = self.wait_for_child(worker_pid, self.engine.name)
        capture = Path(env["GTR_LOG"] + ".stdout")
        self.assertTrue(capture.is_file(), "retained capture was not created")
        self.assertEqual(capture.read_bytes(), b"", "suspended engine executed before ResumeThread")
        supervisor.kill()
        supervisor.communicate(timeout=5)
        self.assert_pid_gone(worker_pid)
        self.assert_pid_gone(engine_pid)
        self.assertEqual(capture.read_bytes(), b"", "suspended engine executed during containment")

    # 23: executable hardlink and project junction spellings still identify the
    # same underlying file/directory, so cleanup targets only the verified process.
    def test_23_file_identity_authorizes_canonical_aliases(self) -> None:
        alias_root = self.temp / "alias root"
        alias_root.mkdir()
        engine_alias = alias_root / self.engine.name
        os.link(self.engine, engine_alias)
        project_alias = self.temp / "project junction"
        created = subprocess.run(
            f'mklink /J "{project_alias}" "{self.project}"',
            shell=True,
            text=True,
            capture_output=True,
        )
        self.assertEqual(created.returncode, 0, created.stderr)
        try:
            existing = subprocess.Popen(
                [str(self.engine), "--mode", "sleep", "--duration", "30", "--headless", "--path", str(self.project)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            self.processes.append(existing)
            time.sleep(0.2)
            summary = self.assert_category(0, "Success", cleanup=True, engine=engine_alias, project=project_alias)
            existing.wait(timeout=5)
            self.assertIn(existing.pid, summary["cleanedPids"])
        finally:
            if project_alias.exists():
                os.rmdir(project_alias)

    # 24: replace the executable pathname only after the worker retained the
    # expected file identity.  The replacement may be created suspended but
    # cannot pass post-create identity verification or reach executable code.
    def test_24_replacement_identity_never_resumes(self) -> None:
        replace_root = self.temp / "replacement"
        replace_root.mkdir()
        target = replace_root / self.engine.name
        replacement = replace_root / "replacement.exe"
        shutil.copy2(self.engine, target)
        shutil.copy2(self.engine, replacement)
        command, env = self.invocation(fault="pause-before-create", timeout=15, engine=target)
        supervisor = subprocess.Popen(command, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.processes.append(supervisor)
        worker_pid = self.wait_for_child(supervisor.pid, Path(command[0]).name)
        capture = Path(env["GTR_LOG"] + ".stdout")
        deadline = time.monotonic() + 8
        while not capture.exists() and time.monotonic() < deadline:
            time.sleep(0.02)
        self.assertTrue(capture.exists(), "worker never retained the capture/expected identity")
        original = replace_root / "original-open.exe"
        os.rename(target, original)
        os.rename(replacement, target)
        stdout, stderr = supervisor.communicate(timeout=20)
        lines = [line for line in stdout.splitlines() if line.startswith("{")]
        self.assertEqual(len(lines), 1, f"stdout={stdout}\nstderr={stderr}")
        summary = json.loads(lines[0])
        self.assertEqual((supervisor.returncode, summary["category"]), (8, "LaunchFailure"), stderr)
        self.assert_pid_gone(worker_pid)
        self.assertEqual(capture.read_bytes(), b"", "replacement executable reached user code")

    # 25: if the project pathname is replaced after W1 but before ResumeThread,
    # the retained directory handle is revalidated and the suspended child never runs.
    def test_25_project_replacement_is_blocked_through_resume(self) -> None:
        command, env = self.invocation(fault="pause-before-resume", timeout=15)
        supervisor = subprocess.Popen(command, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.processes.append(supervisor)
        worker_pid = self.wait_for_child(supervisor.pid, Path(command[0]).name)
        engine_pid = self.wait_for_child(worker_pid, self.engine.name)
        relocated = self.temp / "replaced-project"
        os.rename(self.project, relocated)
        stdout, stderr = supervisor.communicate(timeout=20)
        lines = [line for line in stdout.splitlines() if line.startswith("{")]
        self.assertEqual(len(lines), 1, f"stdout={stdout}\nstderr={stderr}")
        summary = json.loads(lines[0])
        self.assertEqual((supervisor.returncode, summary["category"]), (7, "CleanupFailure"), stderr)
        self.assert_pid_gone(engine_pid)
        capture = Path(env["GTR_LOG"] + ".stdout")
        self.assertEqual(capture.read_bytes(), b"", "replaced project reached executable code")

    # 26: command classification reads every pre-- path before deciding that a
    # process is collateral.  An other-project path preceding a duplicate target
    # path is ambiguous and remains untouched.
    def test_26_other_project_before_duplicate_path_is_ambiguous(self) -> None:
        other = self.temp / "other"
        other.mkdir()
        (other / "project.godot").write_text("[application]\n", encoding="utf-8")
        existing = subprocess.Popen(
            [str(self.engine), "--mode", "sleep", "--duration", "30", "--headless", "--path", str(other), "--path", str(self.project)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        self.processes.append(existing)
        time.sleep(0.2)
        self.assert_category(7, "CleanupFailure", cleanup=True)
        self.assertIsNone(existing.poll(), "ambiguous duplicate process was mutated")

    # 27: partial and malformed authenticated frames before the deadline have
    # one public result and are classified as LaunchFailure, not Timeout/Input.
    def test_27_predeadline_protocol_schema_failures_are_launch_failures(self) -> None:
        for fault in ("partial", "malformed-ready", "malformed-final", "final-duplicate"):
            with self.subTest(fault=fault):
                self.assert_category(8, "LaunchFailure", fault=fault, timeout=5)

    # 28: W0 cannot proceed until the watcher has observed the supervisor once.
    def test_28_watcher_ready_deadline_fails_closed(self) -> None:
        summary = self.assert_category(7, "CleanupFailure", fault="watcher-ready-timeout", timeout=1)
        self.assertLess(summary["elapsedSeconds"], 2.5)

    # 29: bounded aggregate argument transport and a retained project.godot are
    # validated before any engine authority is granted.
    def test_29_aggregate_arguments_and_project_marker_are_required(self) -> None:
        self.assert_category(6, "InvalidInput", *(["x"] * 257))
        markerless = self.temp / "markerless"
        markerless.mkdir()
        self.assert_category(6, "InvalidInput", project=markerless)


if __name__ == "__main__":
    unittest.main()
