from __future__ import annotations

import argparse
import html
import json
import math
import os
import shutil
import subprocess
from pathlib import Path
from typing import Any

from phase7_longform_audio import (
    MASTER_FRAMES,
    PREVIEW_FRAMES,
    SAMPLE_RATE,
    analyze_loop_edges,
    build_transition_preview,
    read_pcm16_wave,
    render_circular_loop,
)
from phase7_longform_catalog import load_longform_catalog

LOUDNORM_TARGET_LUFS = -16.0
LOUDNORM_MAX_TRUE_PEAK = -1.0
REPEAT_WINDOW_SECONDS = [0, 30, 60, 90, 120, 150]
REPEAT_WINDOW_FRAMES = 30 * SAMPLE_RATE
ENVELOPE_BUCKET_FRAMES = SAMPLE_RATE // 100
REPEAT_CORRELATION_THRESHOLD = 0.985
REPEAT_DIFFERENCE_THRESHOLD = 0.02
FORBIDDEN_APPLY_TOKENS = {
    "loudnorm",
    "alimiter",
    "acompressor",
    "compand",
    "afade",
    "atempo",
    "aresample",
    "-ar",
    "-ac",
    "-t",
    "-ss",
}


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def _round_metric(value: float, digits: int = 6) -> float:
    return round(float(value), digits)


def _resolve_ffmpeg_path(ffmpeg: Path) -> Path:
    candidate = Path(ffmpeg)
    if candidate.exists():
        return candidate.resolve()
    which_path = shutil.which(str(ffmpeg))
    if which_path is None:
        raise ValueError(f"ffmpeg executable could not be resolved: {ffmpeg}")
    return Path(which_path).resolve()


def _json_objects_from_text(text: str) -> list[dict[str, Any]]:
    decoder = json.JSONDecoder()
    objects: list[dict[str, Any]] = []
    for index, character in enumerate(text):
        if character != "{":
            continue
        try:
            parsed, _end = decoder.raw_decode(text, index)
        except json.JSONDecodeError:
            continue
        if isinstance(parsed, dict):
            objects.append(parsed)
    return objects


def _coerce_float(raw: Any, key: str) -> float:
    if isinstance(raw, (int, float)):
        return float(raw)
    if isinstance(raw, str):
        try:
            return float(raw.strip())
        except ValueError as exc:
            raise ValueError(f"loudnorm JSON field {key} is not a float: {raw}") from exc
    raise ValueError(f"loudnorm JSON field {key} is not a float: {raw!r}")


def _relative_path(base_dir: Path, target: Path) -> str:
    return os.path.relpath(target, base_dir).replace("\\", "/")


def _write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def _cleanup_paths(*paths: Path) -> None:
    for path in paths:
        if path.exists():
            path.unlink()


def _mean(values: list[float]) -> float:
    return sum(values) / len(values) if values else 0.0


def _pearson(left: list[float], right: list[float]) -> float:
    _require(len(left) == len(right) and bool(left), "repeat windows must be equal non-empty sequences")
    left_mean = _mean(left)
    right_mean = _mean(right)
    left_variance = 0.0
    right_variance = 0.0
    covariance = 0.0
    for left_value, right_value in zip(left, right):
        left_delta = left_value - left_mean
        right_delta = right_value - right_mean
        covariance += left_delta * right_delta
        left_variance += left_delta * left_delta
        right_variance += right_delta * right_delta
    if left_variance == 0.0 or right_variance == 0.0:
        if left == right:
            return 1.0
        return 0.0
    return covariance / math.sqrt(left_variance * right_variance)


def _normalized_mean_difference(left: list[float], right: list[float]) -> float:
    denominator = max(_mean(left), _mean(right), 1e-12)
    return sum(abs(left_value - right_value) for left_value, right_value in zip(left, right)) / (len(left) * denominator)


def _window_rms_envelope(samples: Any, frame_start: int, frame_count: int) -> list[float]:
    envelope: list[float] = []
    sample_start = frame_start * 2
    sample_stop = (frame_start + frame_count) * 2
    bucket_samples = ENVELOPE_BUCKET_FRAMES * 2
    for bucket_start in range(sample_start, sample_stop, bucket_samples):
        bucket_stop = min(sample_stop, bucket_start + bucket_samples)
        total = 0.0
        sample_count = bucket_stop - bucket_start
        for sample_index in range(bucket_start, bucket_stop):
            normalized = samples[sample_index] / 32_768.0
            total += normalized * normalized
        envelope.append(math.sqrt(total / sample_count) if sample_count else 0.0)
    return envelope


def _detect_possible_six_repeat_structure(windows: list[list[float]]) -> dict[str, Any]:
    _require(len(windows) == len(REPEAT_WINDOW_SECONDS), "repeat analysis requires six windows")
    pairs: list[dict[str, Any]] = []
    for left_index in range(len(windows)):
        for right_index in range(left_index + 1, len(windows)):
            correlation = _pearson(windows[left_index], windows[right_index])
            difference = _normalized_mean_difference(windows[left_index], windows[right_index])
            if correlation >= REPEAT_CORRELATION_THRESHOLD and difference <= REPEAT_DIFFERENCE_THRESHOLD:
                pairs.append({
                    "left_start_seconds": REPEAT_WINDOW_SECONDS[left_index],
                    "right_start_seconds": REPEAT_WINDOW_SECONDS[right_index],
                    "correlation": _round_metric(correlation),
                    "normalized_mean_difference": _round_metric(difference),
                })
    return {
        "possible_six_repeat_structure": bool(pairs),
        "pairs": pairs,
    }


def _analyze_repeat_structure(master_path: Path) -> dict[str, Any]:
    data = read_pcm16_wave(master_path)
    _require(data.frame_count == MASTER_FRAMES, f"master frame count must be exactly {MASTER_FRAMES}")
    windows = [
        _window_rms_envelope(data.samples, start_seconds * SAMPLE_RATE, REPEAT_WINDOW_FRAMES)
        for start_seconds in REPEAT_WINDOW_SECONDS
    ]
    return _detect_possible_six_repeat_structure(windows)


def measure_loudness(ffmpeg: Path, source: Path) -> dict[str, Any]:
    resolved_ffmpeg = _resolve_ffmpeg_path(ffmpeg)
    command = [
        str(resolved_ffmpeg),
        "-hide_banner",
        "-nostdin",
        "-i",
        str(source),
        "-af",
        f"loudnorm=I={LOUDNORM_TARGET_LUFS}:TP={LOUDNORM_MAX_TRUE_PEAK}:print_format=json",
        "-f",
        "null",
        "-",
    ]
    completed = subprocess.run(command, check=False, capture_output=True, text=True)
    if completed.returncode != 0:
        raise ValueError(f"ffmpeg loudness measurement failed: {completed.stderr.strip()}")

    objects = _json_objects_from_text(completed.stderr)
    for payload in reversed(objects):
        if "input_i" in payload and "input_tp" in payload:
            integrated_lufs = _coerce_float(payload["input_i"], "input_i")
            true_peak_dbtp = _coerce_float(payload["input_tp"], "input_tp")
            normalized_payload = {
                key: (_coerce_float(value, key) if key.startswith("input_") and key != "input_thresh" else value)
                for key, value in payload.items()
            }
            return {
                "integrated_lufs": integrated_lufs,
                "true_peak_dbtp": true_peak_dbtp,
                "raw": normalized_payload,
                "stderr": completed.stderr,
            }
    raise ValueError("ffmpeg loudness measurement did not produce loudnorm JSON")


def calculate_constant_gain(measurement: dict[str, Any], target_lufs: float, max_true_peak: float) -> float:
    integrated_lufs = float(measurement["integrated_lufs"])
    true_peak_dbtp = float(measurement["true_peak_dbtp"])
    target_gain = target_lufs - integrated_lufs
    peak_capped_gain = max_true_peak - true_peak_dbtp
    return min(target_gain, peak_capped_gain)


def _validate_apply_command(command: list[str]) -> None:
    _require("-af" in command, "apply command must include -af")
    filter_value = command[command.index("-af") + 1]
    _require(filter_value.startswith("volume=") and filter_value.endswith("dB"), "apply command must use only a constant volume filter")
    _require("-c:a" in command, "apply command must include -c:a pcm_s16le")
    _require(command[command.index("-c:a") + 1] == "pcm_s16le", "apply command must encode pcm_s16le")
    for token in FORBIDDEN_APPLY_TOKENS:
        _require(token not in command, f"apply command must not contain {token}")
        _require(token not in filter_value, f"apply filter must not contain {token}")


def apply_constant_gain(ffmpeg: Path, source: Path, output: Path, gain_db: float) -> None:
    resolved_ffmpeg = _resolve_ffmpeg_path(ffmpeg)
    source_data = read_pcm16_wave(source)
    command = [
        str(resolved_ffmpeg),
        "-hide_banner",
        "-nostdin",
        "-y",
        "-i",
        str(source),
        "-af",
        f"volume={gain_db:.6f}dB",
        "-c:a",
        "pcm_s16le",
        str(output),
    ]
    _validate_apply_command(command)
    completed = subprocess.run(command, check=False, capture_output=True, text=True)
    if completed.returncode != 0:
        raise ValueError(f"ffmpeg constant-gain apply failed: {completed.stderr.strip()}")
    output_data = read_pcm16_wave(output)
    if output_data.frame_count != source_data.frame_count:
        raise ValueError("master apply pass must preserve exact frame count")


def _measurement_failures(measurement: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    integrated_lufs = float(measurement["integrated_lufs"])
    true_peak_dbtp = float(measurement["true_peak_dbtp"])
    if integrated_lufs < -17.0 or integrated_lufs > -15.0:
        errors.append(f"master loudness out of range: {integrated_lufs:.6f} LUFS")
    if true_peak_dbtp > -1.0:
        errors.append(f"master true peak exceeds limit: {true_peak_dbtp:.6f} dBTP")
    return errors


def _track_paths(track: dict[str, Any], staging_root: Path) -> dict[str, Path]:
    variant = track.get("selected_variant", "B")
    track_root = staging_root / "bgm_longform" / track["key"]
    return {
        "source": track_root / f"bgm_{track['key']}_{variant}_source188.wav",
        "master": track_root / f"bgm_{track['key']}_{variant}_loop180_review.wav",
        "preview": track_root / f"bgm_{track['key']}_{variant}_loop_transition.wav",
    }


def master_and_analyze(catalog: dict[str, Any], staging_root: Path, ffmpeg: Path) -> dict[str, Any]:
    staging_root = Path(staging_root)
    reports_dir = staging_root / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)
    resolved_ffmpeg = _resolve_ffmpeg_path(ffmpeg)
    defaults = catalog["defaults"]
    tracks_report: list[dict[str, Any]] = []

    for track in catalog["tracks"]:
        paths = _track_paths(track, staging_root)
        master_temp = paths["master"].with_suffix(".tmp.wav")
        preview_temp = paths["preview"].with_suffix(".tmp.wav")
        raw_temp = paths["master"].with_suffix(".raw.tmp.wav")
        _cleanup_paths(master_temp, preview_temp, raw_temp)

        track_report: dict[str, Any] = {
            "track_key": track["key"],
            "stage": track["stage"],
            "phase": track["phase"],
            "title_zh": track["title_zh"],
            "status": "fail",
            "gain_db": None,
            "integrated_lufs": None,
            "true_peak_dbtp": None,
            "possible_six_repeat_structure": False,
            "repeat_pairs": [],
            "errors": [],
            "relative_master_path": _relative_path(reports_dir, paths["master"]),
            "relative_preview_path": _relative_path(reports_dir, paths["preview"]),
        }

        try:
            raw_report = render_circular_loop(
                paths["source"],
                raw_temp,
                defaults["source_seconds"],
                defaults["master_seconds"],
                defaults["crossfade_seconds"],
            )
            initial_measurement = measure_loudness(resolved_ffmpeg, raw_temp)
            gain_db = calculate_constant_gain(
                initial_measurement,
                defaults["target_lufs"],
                defaults["max_true_peak_dbtp"],
            )
            apply_constant_gain(resolved_ffmpeg, raw_temp, master_temp, gain_db)
            final_measurement = measure_loudness(resolved_ffmpeg, master_temp)
            edge_report = analyze_loop_edges(master_temp, repeat_count=10)
            preview_report = build_transition_preview(master_temp, preview_temp)
            repeat_report = _analyze_repeat_structure(master_temp)

            errors = _measurement_failures(final_measurement)
            if edge_report.get("status") != "pass":
                errors.append("master loop edge analysis failed")
            if edge_report.get("frame_count") != MASTER_FRAMES:
                errors.append(f"master frame count must be exactly {MASTER_FRAMES}")
            if preview_report.get("frame_count") not in (None, PREVIEW_FRAMES):
                errors.append(f"transition preview frame count must be exactly {PREVIEW_FRAMES}")

            track_report["gain_db"] = _round_metric(gain_db)
            track_report["integrated_lufs"] = _round_metric(final_measurement["integrated_lufs"])
            track_report["true_peak_dbtp"] = _round_metric(final_measurement["true_peak_dbtp"])
            track_report["initial_integrated_lufs"] = _round_metric(initial_measurement["integrated_lufs"])
            track_report["initial_true_peak_dbtp"] = _round_metric(initial_measurement["true_peak_dbtp"])
            track_report["raw_loop"] = raw_report
            track_report["edge_analysis"] = edge_report
            track_report["possible_six_repeat_structure"] = repeat_report["possible_six_repeat_structure"]
            track_report["repeat_pairs"] = repeat_report["pairs"]
            track_report["errors"] = errors

            if errors:
                _cleanup_paths(master_temp, preview_temp)
            else:
                paths["master"].parent.mkdir(parents=True, exist_ok=True)
                os.replace(master_temp, paths["master"])
                os.replace(preview_temp, paths["preview"])
                track_report["status"] = "pass"
        except Exception as exc:
            track_report["errors"] = [str(exc)]
            _cleanup_paths(master_temp, preview_temp)
        finally:
            _cleanup_paths(raw_temp)

        tracks_report.append(track_report)

    pass_count = sum(1 for item in tracks_report if item["status"] == "pass")
    fail_count = sum(1 for item in tracks_report if item["status"] == "fail")
    warning_count = sum(1 for item in tracks_report if item["possible_six_repeat_structure"])
    report = {
        "schema_version": 1,
        "expected_track_count": len(tracks_report),
        "pass_count": pass_count,
        "fail_count": fail_count,
        "warning_count": warning_count,
        "tracks": tracks_report,
    }
    report_path = reports_dir / "longform_qa.json"
    html_path = reports_dir / "bgm_longform_review.html"
    _write_json(report_path, report)
    build_longform_review_html(catalog, report, html_path)
    return report


def build_longform_review_html(catalog: dict[str, Any], report: dict[str, Any], output_path: Path) -> None:
    track_reports = {
        item["track_key"]: item
        for item in report.get("tracks", [])
        if isinstance(item, dict) and isinstance(item.get("track_key"), str)
    }
    sections: list[str] = []
    for track in catalog.get("tracks", []):
        item = track_reports.get(track["key"], {})
        phase_label = "Boss" if track.get("phase") == "boss" else "道中"
        master_src = html.escape(str(item.get("relative_master_path", "")), quote=True)
        preview_src = html.escape(str(item.get("relative_preview_path", "")), quote=True)
        errors = "".join(f"<li>{html.escape(error)}</li>" for error in item.get("errors", []))
        repeat_pairs = "".join([
            f"<li>{pair['left_start_seconds']}s / {pair['right_start_seconds']}s: "
            f"corr {pair['correlation']}, diff {pair['normalized_mean_difference']}</li>"
            for pair in item.get("repeat_pairs", [])
        ])
        warning_html = ""
        if item.get("possible_six_repeat_structure"):
            warning_html = "".join([
                '<div class="warning">',
                "<strong>可能存在六段重复结构</strong>",
                f"<ul>{repeat_pairs}</ul>",
                "</div>",
            ])
        sections.append(
            "".join([
                "<section>",
                f"<h2>Stage {track['stage']} {phase_label} {html.escape(track['title_zh'])}</h2>",
                '<div class="players">',
                '<article class="player-card">',
                "<h3>180秒评审母带</h3>",
                f'<audio controls preload="metadata" src="{master_src}"></audio>',
                "</article>",
                '<article class="player-card">',
                "<h3>循环过渡预览</h3>",
                f'<audio controls preload="metadata" src="{preview_src}"></audio>',
                "</article>",
                "</div>",
                '<dl class="stats">',
                f"<div><dt>状态</dt><dd>{html.escape(str(item.get('status', 'missing')))}</dd></div>",
                f"<div><dt>LUFS</dt><dd>{html.escape(str(item.get('integrated_lufs', '')))}</dd></div>",
                f"<div><dt>True Peak</dt><dd>{html.escape(str(item.get('true_peak_dbtp', '')))} dBTP</dd></div>",
                "</dl>",
                warning_html,
                '<div class="notes"><ul>',
                errors,
                "</ul></div>",
                "</section>",
            ])
        )

    document = "\n".join([
        "<!doctype html>",
        '<html lang="zh-CN">',
        "<head>",
        '<meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
        "<title>Phase 7 长曲评审页</title>",
        "<style>",
        "body{margin:24px;background:#101214;color:#f4f4f4;font-family:system-ui,sans-serif;letter-spacing:0}",
        "main{max-width:1180px;margin:0 auto}",
        "h1{margin:0 0 20px;font-size:30px}",
        "section{padding:18px 0;border-top:1px solid #32363a}",
        "h2{margin:0 0 12px;font-size:22px}",
        ".players{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:12px}",
        ".player-card{border:1px solid #32363a;border-radius:6px;background:#181b1f;padding:12px}",
        ".player-card h3{margin:0 0 10px;font-size:16px}",
        "audio{width:100%}",
        ".stats{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;margin:12px 0}",
        ".stats div{border:1px solid #32363a;border-radius:6px;padding:8px;background:#14171a}",
        "dt{color:#b7bcc2;font-size:12px}",
        "dd{margin:4px 0 0;font-size:14px}",
        ".warning{margin:12px 0;border:1px solid #7a6325;border-radius:6px;background:#2e2510;padding:10px}",
        ".notes ul,.warning ul{margin:8px 0 0 18px}",
        "</style>",
        "</head>",
        "<body>",
        "<main>",
        "<h1>Phase 7 长曲评审页</h1>",
        *sections,
        "</main>",
        "</body>",
        "</html>",
        "",
    ])
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(document, encoding="utf-8", newline="\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Master and QA Phase 7 long-form BGM loops")
    parser.add_argument("--catalog", required=True, type=Path)
    parser.add_argument("--staging-root", required=True, type=Path)
    parser.add_argument("--ffmpeg", default="ffmpeg", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    catalog = load_longform_catalog(args.catalog)
    report = master_and_analyze(catalog, args.staging_root, args.ffmpeg)
    return 0 if report["fail_count"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
