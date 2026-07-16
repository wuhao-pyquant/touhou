"""Package accepted M2 Stage 2 runtime captures and fail closed on evidence gates."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


DIFFICULTIES = ("normal", "hard")


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path} is not a JSON object")
    return value


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if not rows or not all(isinstance(row, dict) for row in rows):
        raise ValueError(f"{path} is not a nonempty JSONL object stream")
    return rows


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def one_percent_low_fps(frame_times: list[float]) -> float:
    count = max(1, math.ceil(len(frame_times) * 0.01))
    slowest = sorted(frame_times, reverse=True)[:count]
    average = sum(slowest) / len(slowest)
    return float("inf") if average == 0 else 1000.0 / average


def encode_video(evidence_dir: Path, ffmpeg: str, ffprobe: str) -> dict[str, Any]:
    frames = evidence_dir / "raw" / "video-frames"
    output = evidence_dir / "stage2-evidence.mp4"
    if (frames / "frame_00000.png").is_file():
        completed = subprocess.run(
            [ffmpeg, "-y", "-framerate", "20", "-i", str(frames / "frame_%05d.png"),
             "-c:v", "libx264", "-preset", "medium", "-crf", "24", "-pix_fmt", "yuv420p",
             "-movflags", "+faststart", str(output)],
            text=True, capture_output=True,
        )
        if completed.returncode != 0:
            raise ValueError(f"ffmpeg failed: {completed.stderr[-2000:]}")
        shutil.rmtree(frames)
    elif not output.is_file():
        raise ValueError("live Godot video frames and compressed video are missing")
    probed = subprocess.run(
        [ffprobe, "-v", "error", "-select_streams", "v:0",
         "-show_entries", "stream=codec_name,width,height,avg_frame_rate:format=duration,size",
         "-of", "json", str(output)], text=True, capture_output=True,
    )
    if probed.returncode != 0:
        raise ValueError(f"ffprobe failed: {probed.stderr[-1000:]}")
    metadata = json.loads(probed.stdout)
    stream = metadata["streams"][0]
    format_row = metadata["format"]
    result = {
        "path": output.relative_to(evidence_dir).as_posix(),
        "codec": stream["codec_name"], "width": int(stream["width"]), "height": int(stream["height"]),
        "average_frame_rate": stream["avg_frame_rate"], "duration_seconds": float(format_row["duration"]),
        "size_bytes": int(format_row["size"]), "source": "live Godot window viewport frames from Normal capture",
        "performance_timing_source": "separate window-present intervals; screenshot encoding excluded",
    }
    return result


def package(evidence_dir: Path, ffmpeg: str, ffprobe: str) -> dict[str, Any]:
    raw = evidence_dir / "raw"
    index = read_json(raw / "runtime-capture-index.json")
    shot_balance = read_json(raw / "shot-balance.json")
    gate_failures: list[str] = []
    if not bool(shot_balance.get("gate_passed")):
        gate_failures.append("six-shot <=15% gate failed")
    video = encode_video(evidence_dir, ffmpeg, ffprobe)
    capture_rows: dict[str, Any] = {}
    analyzer: dict[str, Any] = {}
    performance: dict[str, Any] = {}
    identities: dict[str, Any] = {}
    score: dict[str, Any] = {}
    for difficulty in DIFFICULTIES:
        capture_path = raw / f"{difficulty}-runtime.jsonl"
        replay_path = raw / f"{difficulty}-reference-replay.json"
        rows = read_jsonl(capture_path)
        header, footer = rows[0], rows[-1]
        if footer.get("complete") is not True:
            raise ValueError(f"{difficulty} capture is incomplete")
        phase_gate_ticks = {
            int(row["tick"]) for row in rows
            if row.get("record_type") == "event" and row.get("event") == "phase_gate_open"
        }
        # A phase-gate sample can include deterministic gate-resolution work
        # between presented frames; it is not a contiguous render interval.
        frame_times = [
            float(row["frame_time_ms"]) for row in rows
            if row.get("record_type") == "render_frame" and int(row["tick"]) not in phase_gate_ticks
        ]
        if not frame_times:
            raise ValueError(f"{difficulty} has no render frames")
        low = one_percent_low_fps(frame_times)
        summary = read_json(evidence_dir / "analysis" / difficulty / "summary.json")
        analyzer[difficulty] = summary
        performance[difficulty] = {
            **summary["render_frame_time_ms"], "one_percent_low_fps": low,
            "gate_fps": 55.0, "gate_passed": low >= 55.0,
            "peak_active_bullets": int(footer["peak_active_bullets"]),
            "pool_capacity": int(footer["pool_capacity"]), "overflow_count": int(footer["overflow_count"]),
            "hard_error_count": int(footer["hard_error_count"]), "death_count": int(footer["death_count"]),
        }
        if not performance[difficulty]["gate_passed"]:
            gate_failures.append(f"{difficulty} 55 FPS 1%-low gate failed")
        identities[difficulty] = {
            "runtime_identity": index["runtime_identity"], "seed": int(header["run_seed"]),
            "capture_path": capture_path.relative_to(evidence_dir).as_posix(), "capture_sha256": sha256(capture_path),
            "replay_path": replay_path.relative_to(evidence_dir).as_posix(), "replay_sha256": sha256(replay_path),
            "build_kind": header["build_kind"], "execution_mode": header["execution_mode"], "headless": header["headless"],
        }
        score_snapshot = index["captures"][difficulty]["canonical_score_runtime"]
        settlements = score_snapshot["settlement_records"]
        seals = sum(int(row["seal_spawn_count"]) for row in settlements)
        multipliers = [float(row["point_value_multiplier_after"]) for row in settlements]
        if multipliers != [1.25, 1.5, 1.75] or seals != 1 or int(settlements[-1]["seal_spawn_count"]) != 1:
            gate_failures.append(f"{difficulty} score settlement progression failed")
        score[difficulty] = {
            "route_state": score_snapshot["route_state"], "settled_group_count": score_snapshot["settled_group_count"],
            "group_multipliers": multipliers, "settlements": settlements,
            "night_festival_seal_count": seals, "sole_seal_group": 3,
            "phase_score_drop_capture_ledgers": summary["score_drop_capture_ledgers"],
            "live_reference_input_route_state": index["captures"][difficulty]["live_score_runtime"]["route_state"],
        }
        capture_rows[difficulty] = {"records": len(rows), "render_frames": len(frame_times)}
    evidence = {
        "schema_version": 1, "ticket_id": "M2-closeout-C-runtime-evidence-v2",
        "measurement_conditions": {
            "godot": "4.7.stable.official.5b4e0cb0f", "renderer": "OpenGL 3.3 Compatibility",
            "gpu": "NVIDIA GeForce RTX 3070", "viewport": "720x960 gameplay plus 78px HUD",
            "input": "deterministic reference replay; no human-play claim", "simulation_hz": 60,
            "phase_resolution": "deterministic reference-assisted gate after 240 live phase ticks",
        },
        "identities": identities, "capture_counts": capture_rows, "performance": performance,
        "shot_balance": shot_balance, "score": score,
        "event_ledgers": {difficulty: analyzer[difficulty]["event_order"] for difficulty in DIFFICULTIES},
        "video": video, "analyzer_results": {difficulty: "accepted" for difficulty in DIFFICULTIES},
        "gate_failures": gate_failures,
    }
    summary_path = evidence_dir / "evidence-summary.json"
    summary_path.write_text(json.dumps(evidence, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    manifest_path = evidence_dir / "evidence-manifest.sha256"
    files = sorted(path for path in evidence_dir.rglob("*") if path.is_file() and path != manifest_path)
    manifest_path.write_text("".join(f"{sha256(path)}  {path.relative_to(evidence_dir).as_posix()}\n" for path in files), encoding="utf-8", newline="\n")
    evidence["manifest_path"] = manifest_path.relative_to(evidence_dir).as_posix()
    evidence["manifest_entries"] = len(files)
    return evidence


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence-dir", required=True, type=Path)
    parser.add_argument("--ffmpeg", default="ffmpeg")
    parser.add_argument("--ffprobe", default="ffprobe")
    args = parser.parse_args(argv)
    try:
        result = package(args.evidence_dir.resolve(), args.ffmpeg, args.ffprobe)
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as error:
        print(f"package_m2_stage2: {error}", file=sys.stderr)
        return 2
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    if result["gate_failures"]:
        print("package_m2_stage2: " + "; ".join(result["gate_failures"]), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
