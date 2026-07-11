from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import time
from pathlib import Path
from typing import Any

import phase7_catalog
import phase7_longform_audio
import phase7_longform_catalog
from phase7_longform_audio import GUIDE_FRAMES, SAMPLE_RATE, read_pcm16_wave
from phase7_longform_audio import build_macro_guide
from phase7_longform_catalog import (
    load_longform_catalog,
    local_candidate_path,
    phase7a_catalog_path_for_longform_catalog,
    validate_external_selection,
)

ROOT = Path(__file__).resolve().parents[2]
CONTROL_FILES = [
    ("control/phase7_bgm_longform_jobs.json", lambda catalog_path: catalog_path.resolve()),
    ("control/phase7_bgm_jobs.json", lambda catalog_path: phase7a_catalog_path_for_longform_catalog(catalog_path).resolve()),
    ("control/phase7_longform_catalog.py", lambda _catalog_path: Path(phase7_longform_catalog.__file__).resolve()),
    ("control/phase7_catalog.py", lambda _catalog_path: Path(phase7_catalog.__file__).resolve()),
    ("control/phase7_longform_audio.py", lambda _catalog_path: Path(phase7_longform_audio.__file__).resolve()),
    ("control/phase7_longform_runner.py", lambda _catalog_path: Path(__file__).resolve()),
]
SUCCESS_STATUSES = {"generated", "skipped_valid"}


def guide_filename(track_key: str) -> str:
    return f"bgm_{track_key}_B_guide188.wav"


def source_filename(track_key: str) -> str:
    return f"bgm_{track_key}_B_source188.wav"


def build_longform_command(
    generator: list[str],
    defaults: dict[str, Any],
    job: dict[str, Any],
    guide_path: Path,
    partial_path: Path,
    negative_prompt: str,
) -> list[str]:
    command = list(generator)
    command.extend([
        "--prompt",
        job["longform_prompt"],
        "--negative-prompt",
        negative_prompt,
        "--init-audio",
        str(guide_path),
        "--init-noise-level",
        str(defaults["init_noise_level"]),
        "--dit",
        defaults["dit"],
        "--decoder",
        defaults["decoder"],
        "--seconds",
        str(defaults["source_seconds"]),
        "--steps",
        str(defaults["steps"]),
        "--cfg",
        str(defaults["cfg"]),
        "--seed",
        str(job["selected_seed"]),
        "--out",
        str(partial_path),
    ])
    if defaults.get("free_models", True):
        command.append("--free-models")
    return command


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def write_json_atomic(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = path.with_suffix(path.suffix + ".tmp")
    with temp_path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    os.replace(temp_path, path)


def _compose_longform_prompt(catalog: dict[str, Any], track: dict[str, Any]) -> str:
    return " ".join([
        track["prompt"],
        catalog["longform_structure_prompt"],
        track["longform_development"],
    ])


def _resolve_generator(generator: list[str]) -> list[str]:
    if not generator:
        raise ValueError("generator must not be empty")
    first = generator[0]
    first_path = Path(first)
    if first_path.exists() and first_path.is_file():
        resolved_first = str(first_path.resolve())
    else:
        which_path = shutil.which(first)
        if which_path is None:
            raise ValueError(f"generator executable could not be resolved: {first}")
        resolved_first = str(Path(which_path).resolve())
    return [resolved_first, *generator[1:]]


def _validate_exact_wave(path: Path, label: str) -> dict[str, Any]:
    if not path.is_file():
        raise ValueError(f"missing {label} WAV: {path}")
    try:
        data = read_pcm16_wave(path)
    except ValueError as exc:
        raise ValueError(f"invalid {label} WAV: {exc}") from exc
    if data.frame_count != GUIDE_FRAMES:
        raise ValueError(f"{label} WAV must be exactly 188.0 seconds")
    return {
        "sample_rate": data.sample_rate,
        "channels": data.channels,
        "bits_per_sample": data.bits_per_sample,
        "frame_count": data.frame_count,
        "duration_seconds": round(data.frame_count / SAMPLE_RATE, 6),
        "size_bytes": path.stat().st_size,
    }


def _build_and_publish_guide(candidate_path: Path, guide_path: Path, defaults: dict[str, Any]) -> dict[str, Any]:
    guide_path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = guide_path.with_name(guide_path.stem + ".tmp.wav")
    if temp_path.exists():
        temp_path.unlink()
    try:
        build_macro_guide(
            candidate_path,
            temp_path,
            defaults["source_seconds"],
            defaults["guide_crossfade_seconds"],
        )
        wave = _validate_exact_wave(temp_path, "guide")
        temp_sha256 = _sha256_file(temp_path)
        if guide_path.exists() and _sha256_file(guide_path) == temp_sha256:
            temp_path.unlink()
        else:
            os.replace(temp_path, guide_path)
        return {
            "path": str(guide_path),
            "sha256": _sha256_file(guide_path),
            "wave": wave,
        }
    finally:
        if temp_path.exists():
            temp_path.unlink()


def _control_file_fingerprint(catalog_path: Path) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    for published_path, resolver in CONTROL_FILES:
        source_path = resolver(catalog_path)
        entries.append({
            "published_path": published_path,
            "source_path": str(source_path),
            "sha256": _sha256_file(source_path),
        })
    return entries


def _build_fingerprint(
    catalog_path: Path,
    resolved_generator: list[str],
    defaults: dict[str, Any],
    track: dict[str, Any],
    selected_sha256: str,
    guide_sha256: str,
    negative_prompt: str,
    longform_prompt: str,
) -> dict[str, Any]:
    generator_script = Path(resolved_generator[0])
    return {
        "selected_sha256": selected_sha256,
        "guide_sha256": guide_sha256,
        "prompt_sha256": _sha256_text(longform_prompt),
        "negative_prompt_sha256": _sha256_text(negative_prompt),
        "selected_seed": track["selected_seed"],
        "init_noise_level": defaults["init_noise_level"],
        "steps": defaults["steps"],
        "cfg": defaults["cfg"],
        "source_seconds": defaults["source_seconds"],
        "dit": defaults["dit"],
        "decoder": defaults["decoder"],
        "generator": resolved_generator,
        "generator_script_path": str(generator_script),
        "generator_script_sha256": _sha256_file(generator_script),
        "control_files": _control_file_fingerprint(catalog_path),
    }


def _load_previous_manifest(path: Path) -> dict[str, Any] | None:
    if not path.is_file():
        return None
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except (json.JSONDecodeError, OSError):
        return None


def _find_previous_success(previous_manifest: dict[str, Any] | None, track_key: str) -> dict[str, Any] | None:
    if not isinstance(previous_manifest, dict):
        return None
    jobs = previous_manifest.get("jobs")
    if not isinstance(jobs, list):
        return None
    for job in reversed(jobs):
        if (
            isinstance(job, dict)
            and job.get("track_key") == track_key
            and job.get("status") in SUCCESS_STATUSES
        ):
            return job
    return None


def _selection_by_key(selection: dict[str, Any]) -> dict[str, dict[str, Any]]:
    tracks = selection.get("tracks", [])
    return {
        track["track_key"]: track
        for track in tracks
        if isinstance(track, dict) and isinstance(track.get("track_key"), str)
    }


def run_longform_catalog(
    catalog_path: Path,
    selection_path: Path,
    staging_root: Path,
    generator: list[str],
    force: bool,
) -> int:
    catalog_path = Path(catalog_path)
    selection_path = Path(selection_path)
    staging_root = Path(staging_root)
    catalog = load_longform_catalog(catalog_path)
    phase7a_catalog_path = phase7a_catalog_path_for_longform_catalog(catalog_path)
    reports_dir = staging_root / "reports"
    manifest_path = reports_dir / "longform_generation_manifest.json"
    previous_manifest = _load_previous_manifest(manifest_path)
    resolved_generator = _resolve_generator(generator)
    manifest: dict[str, Any] = {
        "schema_version": 1,
        "catalog_path": str(Path(catalog_path).resolve()),
        "selection_path": str(Path(selection_path).resolve()),
        "staging_root": str(Path(staging_root).resolve()),
        "generator": resolved_generator,
        "jobs": [],
    }
    failures = 0

    for track in catalog["tracks"]:
        track_key = track["key"]
        guide_path = staging_root / "bgm_guides" / track_key / guide_filename(track_key)
        output_path = staging_root / "bgm_longform" / track_key / source_filename(track_key)
        partial_path = output_path.with_name(output_path.stem + ".partial.wav")
        job: dict[str, Any] = {
            "track_key": track_key,
            "title_zh": track["title_zh"],
            "selected_variant": track["selected_variant"],
            "selected_seed": track["selected_seed"],
            "generator": resolved_generator,
            "guide_path": str(guide_path),
            "output_path": str(output_path),
            "partial_output_path": str(partial_path),
            "negative_prompt": catalog["negative_prompt"],
            "status": "planned",
        }
        manifest["jobs"].append(job)
        write_json_atomic(manifest_path, manifest)

        try:
            selection = validate_external_selection(catalog, selection_path, staging_root, phase7a_catalog_path)
            selection_track = _selection_by_key(selection)[track_key]
            candidate_path = local_candidate_path(staging_root, track_key, selection_track["seed"])
            longform_prompt = _compose_longform_prompt(catalog, track)
            job["longform_prompt"] = longform_prompt
            job["candidate_path"] = str(candidate_path)
            guide = _build_and_publish_guide(candidate_path, guide_path, catalog["defaults"])
            job["guide_sha256"] = guide["sha256"]
            job["guide_wave"] = guide["wave"]
            job["fingerprint"] = _build_fingerprint(
                Path(catalog_path),
                resolved_generator,
                catalog["defaults"],
                track,
                selection_track["sha256"],
                guide["sha256"],
                catalog["negative_prompt"],
                longform_prompt,
            )
            job["status"] = "guide_ready"
            write_json_atomic(manifest_path, manifest)
        except Exception as exc:
            job["status"] = "validation_failed"
            job["error"] = str(exc)
            failures += 1
            write_json_atomic(manifest_path, manifest)
            continue

        if output_path.exists() and not force:
            try:
                job["wave"] = _validate_exact_wave(output_path, "source")
                job["source_sha256"] = _sha256_file(output_path)
            except ValueError as exc:
                job["status"] = "validation_failed"
                job["error"] = str(exc)
                failures += 1
                write_json_atomic(manifest_path, manifest)
                continue
            previous_job = _find_previous_success(previous_manifest, track_key)
            if previous_job and previous_job.get("fingerprint") == job["fingerprint"]:
                job["status"] = "skipped_valid"
                write_json_atomic(manifest_path, manifest)
                continue
            job["status"] = "existing_stale"
            job["error"] = "existing source fingerprint does not match the current inputs"
            failures += 1
            write_json_atomic(manifest_path, manifest)
            continue

        if partial_path.exists():
            partial_path.unlink()

        output_path.parent.mkdir(parents=True, exist_ok=True)
        command = build_longform_command(
            resolved_generator,
            catalog["defaults"],
            job,
            guide_path,
            partial_path,
            catalog["negative_prompt"],
        )
        job["command"] = command
        job["status"] = "generating"
        job["started_at_unix"] = int(time.time())
        write_json_atomic(manifest_path, manifest)

        try:
            completed = subprocess.run(command, check=False)
            job["exit_code"] = completed.returncode
        except KeyboardInterrupt:
            job["finished_at_unix"] = int(time.time())
            job["status"] = "generation_failed"
            job["error"] = "KeyboardInterrupt: generation interrupted"
            if partial_path.exists():
                job["partial_cleanup"] = "retained_for_next_cleanup"
            else:
                job["partial_cleanup"] = "not_present"
            failures += 1
            manifest["completed_at_unix"] = int(time.time())
            manifest["failure_count"] = failures
            write_json_atomic(manifest_path, manifest)
            return 1
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
            _validate_exact_wave(partial_path, "source")
            os.replace(partial_path, output_path)
            job["wave"] = _validate_exact_wave(output_path, "source")
            job["source_sha256"] = _sha256_file(output_path)
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
    parser = argparse.ArgumentParser(description="Generate Phase 7 long-form BGM sources")
    parser.add_argument("--catalog", required=True, type=Path)
    parser.add_argument("--selection", required=True, type=Path)
    parser.add_argument("--staging-root", required=True, type=Path)
    parser.add_argument("--generator", required=True, nargs="+")
    parser.add_argument("--force", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    return run_longform_catalog(
        args.catalog,
        args.selection,
        args.staging_root,
        args.generator,
        args.force,
    )


if __name__ == "__main__":
    raise SystemExit(main())
