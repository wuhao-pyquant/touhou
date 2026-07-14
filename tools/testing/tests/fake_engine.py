"""A deterministic stand-in for Godot used only by invoke_godot_test tests."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--mode", default="success")
    parser.add_argument("--duration", type=float, default=30.0)
    parser.add_argument("--spawn-child", action="store_true")
    parser.add_argument("--inherit-stream", action="store_true")
    parser.add_argument("--child", action="store_true")
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--path")
    parser.add_argument("--log-file")
    args, _ = parser.parse_known_args()

    registry = os.environ.get("FAKE_PROCESS_REGISTRY")
    if registry:
        with open(registry, "a", encoding="utf-8") as handle:
            handle.write(json.dumps({
                "ProcessId": os.getpid(), "ParentProcessId": os.getppid(),
                "ExecutablePath": sys.executable, "CommandLine": " ".join(sys.argv),
            }) + "\n")

    if args.child:
        time.sleep(args.duration)
        return 0
    if args.spawn_child:
        child = subprocess.Popen(
            [sys.executable, __file__, "--child", "--duration", str(args.duration)],
            stdout=None if args.inherit_stream else subprocess.DEVNULL,
            stderr=None if args.inherit_stream else subprocess.DEVNULL,
        )
        print(f"CHILD_PID={child.pid}", flush=True)
    if args.mode == "orphan":
        return 0
    if args.mode == "nonzero":
        print("ordinary test failure", file=sys.stderr, flush=True)
        return 17
    if args.mode == "fatal":
        print("Program crashed: fake native crash marker", flush=True)
        return 0
    if args.mode == "parser":
        print("Parser Error: fake parse failure", file=sys.stderr, flush=True)
        return 0
    if args.mode == "sleep":
        time.sleep(args.duration)
    if args.log_file:
        Path(args.log_file).write_text("fake engine log\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
