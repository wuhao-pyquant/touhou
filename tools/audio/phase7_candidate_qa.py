from __future__ import annotations

import argparse
import hashlib
import html
import json
import math
import struct
import wave
from pathlib import Path
from typing import Any

from phase7_candidate_runner import candidate_filename
from phase7_catalog import load_catalog

PCM_FULL_SCALE = 32_768.0
SILENCE_THRESHOLD = max(1, int(PCM_FULL_SCALE * (10.0 ** (-60.0 / 20.0))))
DURATION_TOLERANCE_SECONDS = 0.05


def _unreadable_report(path: Path, message: str) -> dict[str, Any]:
    return {
        "path": str(path),
        "status": "fail",
        "errors": [message],
    }


def analyze_wave(path: Path, expected_seconds: float) -> dict[str, Any]:
    errors: list[str] = []
    try:
        with wave.open(str(path), "rb") as handle:
            channels = handle.getnchannels()
            sample_width = handle.getsampwidth()
            sample_rate = handle.getframerate()
            frame_count = handle.getnframes()
            raw = handle.readframes(frame_count)
    except (FileNotFoundError, EOFError, wave.Error) as exc:
        return _unreadable_report(path, f"unreadable WAV: {exc}")

    if not path.is_file():
        return _unreadable_report(path, f"unreadable WAV: missing file: {path}")

    frame_bytes = channels * sample_width
    expected_bytes = frame_count * frame_bytes
    if frame_bytes <= 0 or len(raw) != expected_bytes or len(raw) % 2 != 0:
        return _unreadable_report(path, "unreadable WAV: truncated PCM payload")

    duration = frame_count / sample_rate if sample_rate else 0.0
    if channels != 2:
        errors.append(f"expected stereo, got {channels} channels")
    if sample_width != 2:
        errors.append(f"expected 16-bit PCM, got {sample_width * 8} bits")
    if sample_rate != 44_100:
        errors.append(f"expected 44100 Hz, got {sample_rate}")
    if sample_rate:
        expected_frames = int(round(expected_seconds * sample_rate))
        tolerance_frames = int(round(DURATION_TOLERANCE_SECONDS * sample_rate))
        if abs(frame_count - expected_frames) > tolerance_frames:
            errors.append(f"expected {expected_seconds}s +/- {DURATION_TOLERANCE_SECONDS:.2f}s, got {duration:.6f}s")
    else:
        errors.append(f"expected {expected_seconds}s +/- {DURATION_TOLERANCE_SECONDS:.2f}s, got {duration:.6f}s")

    try:
        samples = struct.unpack(f"<{len(raw) // 2}h", raw) if raw else ()
    except struct.error as exc:
        return _unreadable_report(path, f"unreadable WAV: {exc}")

    peak = max((abs(value) for value in samples), default=0)
    silence_samples = sum(1 for value in samples if abs(value) <= SILENCE_THRESHOLD)
    silence_ratio = silence_samples / len(samples) if samples else 1.0
    if peak == 0:
        errors.append("candidate is silent")
        peak_dbfs: float | str = "-inf"
    else:
        peak_dbfs_value = 20.0 * math.log10(peak / PCM_FULL_SCALE)
        peak_dbfs = round(peak_dbfs_value, 3)
        if peak_dbfs_value > 0.0:
            errors.append(f"peak exceeds 0 dBFS: {peak_dbfs_value:.3f} dBFS")
    if silence_ratio >= 0.98:
        errors.append(f"candidate silence ratio is {silence_ratio:.6f}")

    report: dict[str, Any] = {
        "path": str(path),
        "status": "pass" if not errors else "fail",
        "errors": errors,
        "sample_rate": sample_rate,
        "channels": channels,
        "bits_per_sample": sample_width * 8,
        "duration_seconds": round(duration, 6),
        "peak_dbfs": peak_dbfs,
        "silence_ratio": round(silence_ratio, 6),
        "pcm_sha256": hashlib.sha256(raw).hexdigest(),
        "size_bytes": path.stat().st_size,
    }
    return report


def build_review_html(catalog: dict[str, Any], qa_report: dict[str, Any], output_path: Path) -> None:
    candidates_by_key: dict[str, list[dict[str, Any]]] = {}
    for candidate in qa_report.get("candidates", []):
        candidates_by_key.setdefault(candidate["track_key"], []).append(candidate)

    sections: list[str] = []
    for track in catalog.get("tracks", []):
        cards: list[str] = []
        for candidate in sorted(candidates_by_key.get(track["key"], []), key=lambda item: item["variant"]):
            audio_path = html.escape(candidate["relative_audio_path"], quote=True)
            cards.append(
                "".join([
                    '<article class="candidate">',
                    f'<h3>候选 {html.escape(candidate["variant"])}</h3>',
                    f'<audio controls preload="metadata" src="{audio_path}"></audio>',
                    '<dl class="stats">',
                    f'<div><dt>状态</dt><dd>{html.escape(candidate["status"])}</dd></div>',
                    f'<div><dt>Peak</dt><dd>{html.escape(str(candidate.get("peak_dbfs", "")))} dBFS</dd></div>',
                    f'<div><dt>Silence</dt><dd>{html.escape(str(candidate.get("silence_ratio", "")))}</dd></div>',
                    "</dl>",
                    "</article>",
                ])
            )
        phase_label = "Boss" if track.get("phase") == "boss" else "道中"
        sections.append(
            "".join([
                "<section>",
                f'<h2>Stage {track.get("stage")} {phase_label} {html.escape(track["title_zh"])} '
                f'<small>{track.get("bpm")} BPM</small></h2>',
                f'<div class="grid">{"".join(cards)}</div>',
                "</section>",
            ])
        )

    document = "\n".join([
        "<!doctype html>",
        '<html lang="zh-CN">',
        "<head>",
        '<meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
        "<title>Phase 7 BGM 候选试听</title>",
        "<style>",
        "body{margin:24px;background:#121212;color:#f3f3f3;font-family:system-ui,sans-serif;letter-spacing:0}",
        "main{max-width:1120px;margin:0 auto}",
        "h1{margin:0 0 24px;font-size:32px}",
        "section{padding:18px 0;border-top:1px solid #353535}",
        "h2{margin:0 0 12px;font-size:22px;font-weight:700}",
        "small{color:#b8b8b8;font-size:14px}",
        ".grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:12px}",
        ".candidate{border:1px solid #353535;border-radius:6px;background:#1d1d1d;padding:14px}",
        ".candidate h3{margin:0 0 10px;font-size:18px}",
        "audio{width:100%}",
        ".stats{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;margin:12px 0 0}",
        ".stats div{background:#171717;border:1px solid #2b2b2b;border-radius:6px;padding:8px}",
        "dt{color:#b8b8b8;font-size:12px}",
        "dd{margin:4px 0 0;font-size:14px}",
        "</style>",
        "</head>",
        "<body>",
        "<main>",
        "<h1>Phase 7 BGM 候选试听</h1>",
        *sections,
        "</main>",
        "</body>",
        "</html>",
        "",
    ])
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(document, encoding="utf-8", newline="\n")


def run_qa(catalog_path: Path, staging_root: Path) -> int:
    catalog = load_catalog(catalog_path)
    expected_seconds = catalog["defaults"]["seconds"]
    candidates: list[dict[str, Any]] = []
    for track in catalog["tracks"]:
        for item in track["candidates"]:
            filename = candidate_filename(track["key"], item["variant"], item["seed"])
            path = staging_root / "bgm_candidates" / track["key"] / filename
            report = analyze_wave(path, expected_seconds)
            report.update({
                "track_key": track["key"],
                "title_zh": track["title_zh"],
                "variant": item["variant"],
                "seed": item["seed"],
                "relative_audio_path": f"../bgm_candidates/{track['key']}/{filename}",
            })
            candidates.append(report)

    pass_count = sum(1 for item in candidates if item["status"] == "pass")
    fail_count = sum(1 for item in candidates if item["status"] == "fail")
    qa_report = {
        "schema_version": 1,
        "expected_candidate_count": len(candidates),
        "pass_count": pass_count,
        "fail_count": fail_count,
        "candidates": candidates,
    }

    reports_dir = staging_root / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)
    (reports_dir / "candidate_qa.json").write_text(
        json.dumps(qa_report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    build_review_html(catalog, qa_report, reports_dir / "bgm_candidate_review.html")
    return 0 if fail_count == 0 and pass_count == len(candidates) else 1


def main() -> int:
    parser = argparse.ArgumentParser(description="QA Phase 7 BGM candidates")
    parser.add_argument("--catalog", required=True, type=Path)
    parser.add_argument("--staging-root", required=True, type=Path)
    args = parser.parse_args()
    return run_qa(args.catalog, args.staging_root)


if __name__ == "__main__":
    raise SystemExit(main())
