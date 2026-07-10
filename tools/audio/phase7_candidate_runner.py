from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import time
import wave
from pathlib import Path
from typing import Any

from phase7_catalog import load_catalog


def candidate_filename(track_key: str, variant: str, seed: int) -> str:
    return f"bgm_{track_key}_{variant}_seed-{seed}.wav"


def build_command(
    generator: list[str],
    defaults: dict[str, Any],
    track: dict[str, Any],
    candidate: dict[str, Any],
    out_path: Path,
    negative_prompt: str,
) -> list[str]:
    command = list(generator)
    command.extend([
        "--prompt", track["prompt"],
        "--negative-prompt", negative_prompt,
        "--dit", defaults["dit"],
        "--decoder", defaults["decoder"],
        "--seconds", str(defaults["seconds"]),
        "--steps", str(defaults["steps"]),
        "--cfg", str(defaults["cfg"]),
        "--seed", str(candidate["seed"]),
        "--out", str(out_path),
    ])
    if defaults.get("free_models", True):
        command.append("--free-models")
    return command


def validate_wave(path: Path, expected_seconds: float) -> dict[str, Any]:
    if not path.is_file():
        raise ValueError(f"missing WAV output: {path}")
    try:
        with wave.open(str(path), "rb") as handle:
            channels = handle.getnchannels()
            sample_width = handle.getsampwidth()
            sample_rate = handle.getframerate()
            frames = handle.getnframes()
    except (wave.Error, EOFError) as exc:
        raise ValueError(f"invalid WAV output: {path}") from exc
    duration = frames / sample_rate if sample_rate else 0.0
    if channels != 2:
        raise ValueError(f"WAV must be stereo, got {channels} channels")
    if sample_width != 2:
        raise ValueError(f"WAV must be 16-bit PCM, got {sample_width * 8} bits")
    if sample_rate != 44_100:
        raise ValueError(f"WAV must be 44100 Hz, got {sample_rate}")
    if abs(duration - expected_seconds) > 0.05:
        raise ValueError(f"WAV duration must be {expected_seconds}s, got {duration:.6f}s")
    return {
        "sample_rate": sample_rate,
        "channels": channels,
        "bits_per_sample": sample_width * 8,
        "frames": frames,
        "duration_seconds": round(duration, 6),
        "size_bytes": path.stat().st_size,
    }


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_json_atomic(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = path.with_suffix(path.suffix + ".tmp")
    with temp_path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    os.replace(temp_path, path)


def run_catalog(
    catalog_path: Path,
    staging_root: Path,
    generator: list[str],
    force: bool,
) -> int:
    catalog = load_catalog(catalog_path)
    reports_dir = staging_root / "reports"
    manifest_path = reports_dir / "generation_manifest.json"
    manifest: dict[str, Any] = {
        "schema_version": 1,
        "catalog": str(catalog_path),
        "staging_root": str(staging_root),
        "jobs": [],
    }
    failures = 0
    for track in catalog["tracks"]:
        track_dir = staging_root / "bgm_candidates" / track["key"]
        track_dir.mkdir(parents=True, exist_ok=True)
        for candidate in track["candidates"]:
            filename = candidate_filename(track["key"], candidate["variant"], candidate["seed"])
            final_path = track_dir / filename
            partial_path = final_path.with_name(final_path.stem + ".partial.wav")
            job: dict[str, Any] = {
                "track_key": track["key"],
                "title_zh": track["title_zh"],
                "variant": candidate["variant"],
                "seed": candidate["seed"],
                "prompt": track["prompt"],
                "negative_prompt": catalog["negative_prompt"],
                "output": str(final_path),
                "status": "planned",
            }
            manifest["jobs"].append(job)
            if final_path.exists() and not force:
                try:
                    job["wave"] = validate_wave(final_path, catalog["defaults"]["seconds"])
                    job["sha256"] = sha256_file(final_path)
                    job["status"] = "skipped_valid"
                    write_json_atomic(manifest_path, manifest)
                    continue
                except ValueError as exc:
                    job["status"] = "existing_invalid"
                    job["error"] = str(exc)
                    failures += 1
                    write_json_atomic(manifest_path, manifest)
                    continue
            if partial_path.exists():
                partial_path.unlink()
            job["status"] = "generating"
            job["started_at_unix"] = int(time.time())
            write_json_atomic(manifest_path, manifest)
            command = build_command(
                generator,
                catalog["defaults"],
                track,
                candidate,
                partial_path,
                catalog["negative_prompt"],
            )
            try:
                completed = subprocess.run(command, check=False)
                job["exit_code"] = completed.returncode
            except OSError as exc:
                job["finished_at_unix"] = int(time.time())
                job["status"] = "generation_failed"
                job["error"] = str(exc)
                failures += 1
                write_json_atomic(manifest_path, manifest)
                continue
            job["finished_at_unix"] = int(time.time())
            if completed.returncode != 0:
                job["status"] = "generation_failed"
                failures += 1
                write_json_atomic(manifest_path, manifest)
                continue
            try:
                job["wave"] = validate_wave(partial_path, catalog["defaults"]["seconds"])
                os.replace(partial_path, final_path)
                job["sha256"] = sha256_file(final_path)
                job["status"] = "generated"
            except ValueError as exc:
                job["status"] = "validation_failed"
                job["error"] = str(exc)
                failures += 1
            write_json_atomic(manifest_path, manifest)
    manifest["completed_at_unix"] = int(time.time())
    manifest["failure_count"] = failures
    write_json_atomic(manifest_path, manifest)
    return 0 if failures == 0 else 1


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate Phase 7 BGM candidates")
    parser.add_argument("--catalog", required=True, type=Path)
    parser.add_argument("--staging-root", required=True, type=Path)
    parser.add_argument("--generator", required=True, nargs="+")
    parser.add_argument("--force", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    return run_catalog(args.catalog, args.staging_root, args.generator, args.force)


if __name__ == "__main__":
    raise SystemExit(main())
