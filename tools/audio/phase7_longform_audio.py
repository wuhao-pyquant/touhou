from __future__ import annotations

import hashlib
import math
import sys
import wave
from array import array
from dataclasses import dataclass
from pathlib import Path
from typing import Any

SAMPLE_RATE = 44_100
CHANNELS = 2
BITS_PER_SAMPLE = 16
SAMPLE_WIDTH_BYTES = 2
PCM_FULL_SCALE = 32_768.0
INT16_MIN = -32_768
INT16_MAX = 32_767
SILENCE_THRESHOLD = max(1, int(round(PCM_FULL_SCALE * (10.0 ** (-60.0 / 20.0)))))
READ_CHUNK_FRAMES = 16_384
WRITE_CHUNK_FRAMES = 16_384
GUIDE_SECONDS = 188.0
MASTER_SECONDS = 180.0
CANDIDATE_SECONDS = 30.0
GUIDE_CROSSFADE_SECONDS = 1.0
LOOP_CROSSFADE_SECONDS = 8.0
GUIDE_FRAMES = int(round(GUIDE_SECONDS * SAMPLE_RATE))
MASTER_FRAMES = int(round(MASTER_SECONDS * SAMPLE_RATE))
CANDIDATE_FRAMES = int(round(CANDIDATE_SECONDS * SAMPLE_RATE))
GUIDE_CROSSFADE_FRAMES = int(round(GUIDE_CROSSFADE_SECONDS * SAMPLE_RATE))
LOOP_CROSSFADE_FRAMES = int(round(LOOP_CROSSFADE_SECONDS * SAMPLE_RATE))
SECTION_STARTS_SECONDS = [0.0, 30.0, 60.0, 90.0, 120.0, 158.0]
SECTION_NOMINAL_SECONDS = [31.0, 31.0, 31.0, 31.0, 39.0, 30.0]
SECTION_EFFECTIVE_SECONDS = [30.0, 30.0, 30.0, 30.0, 38.0, 30.0]
SECTION_ROTATION_SECONDS = [0.0, 5.0, 10.0, 15.0, 20.0, 0.0]
SECTION_KEYS = [
    "theme_establishment",
    "first_variation",
    "breathing_section",
    "rebuild",
    "climax",
    "return_to_theme",
]
SECTION_GAIN_RANGES = [
    (1.0, 1.0),
    (0.95, 0.95),
    (0.72, 0.72),
    (0.82, 1.0),
    (1.0, 1.0),
    (0.95, 1.0),
]
SECTION_LOW_PASS = [False, False, True, False, False, False]
LOW_PASS_ALPHA = 0.18


@dataclass(frozen=True)
class WaveData:
    sample_rate: int
    channels: int
    bits_per_sample: int
    samples: array

    @property
    def frame_count(self) -> int:
        return len(self.samples) // self.channels


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def _clamp_pcm16(value: float) -> int:
    integer = int(round(value))
    if integer < INT16_MIN:
        return INT16_MIN
    if integer > INT16_MAX:
        return INT16_MAX
    return integer


def _round_metric(value: float, digits: int = 6) -> float:
    return round(float(value), digits)


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _frame_slice(samples: array, frame_start: int, frame_count: int) -> array:
    sample_start = frame_start * CHANNELS
    sample_stop = (frame_start + frame_count) * CHANNELS
    return samples[sample_start:sample_stop]


def _normalized_rms(samples: array, frame_start: int, frame_count: int, channel: int) -> float:
    sample_start = frame_start * CHANNELS + channel
    total = 0.0
    for sample_index in range(sample_start, sample_start + (frame_count * CHANNELS), CHANNELS):
        normalized = samples[sample_index] / PCM_FULL_SCALE
        total += normalized * normalized
    return math.sqrt(total / frame_count) if frame_count else 0.0


def _adjacent_jumps(samples: array, frame_start: int, frame_count: int, channel: int) -> list[float]:
    jumps: list[float] = []
    if frame_count <= 1:
        return jumps
    sample_index = frame_start * CHANNELS + channel
    for _ in range(frame_count - 1):
        current_sample = samples[sample_index]
        next_sample = samples[sample_index + CHANNELS]
        jumps.append(abs(next_sample - current_sample) / PCM_FULL_SCALE)
        sample_index += CHANNELS
    return jumps


def _p99(values: list[float]) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = max(0, math.ceil(len(ordered) * 0.99) - 1)
    return ordered[index]


def _rms_delta_db(left_rms: float, right_rms: float) -> float:
    if left_rms == 0.0 and right_rms == 0.0:
        return 0.0
    if left_rms == 0.0 or right_rms == 0.0:
        return float("inf")
    return abs(20.0 * math.log10(left_rms / right_rms))


def _basic_wave_metrics(data: WaveData) -> dict[str, Any]:
    total_samples = len(data.samples)
    silence_samples = 0
    peak = 0
    dc_accumulators = [0, 0]
    max_silent_run_frames = 0
    current_silent_run_frames = 0

    for frame_index in range(data.frame_count):
        sample_index = frame_index * CHANNELS
        left = data.samples[sample_index]
        right = data.samples[sample_index + 1]
        peak = max(peak, abs(left), abs(right))
        dc_accumulators[0] += left
        dc_accumulators[1] += right
        if abs(left) <= SILENCE_THRESHOLD:
            silence_samples += 1
        if abs(right) <= SILENCE_THRESHOLD:
            silence_samples += 1
        if abs(left) <= SILENCE_THRESHOLD and abs(right) <= SILENCE_THRESHOLD:
            current_silent_run_frames += 1
            if current_silent_run_frames > max_silent_run_frames:
                max_silent_run_frames = current_silent_run_frames
        else:
            current_silent_run_frames = 0

    silence_ratio = (silence_samples / total_samples) if total_samples else 1.0
    dc_offset = [
        abs(dc_accumulators[0] / (data.frame_count * PCM_FULL_SCALE)) if data.frame_count else 0.0,
        abs(dc_accumulators[1] / (data.frame_count * PCM_FULL_SCALE)) if data.frame_count else 0.0,
    ]
    if peak == 0:
        peak_dbfs = float("-inf")
    else:
        peak_dbfs = 20.0 * math.log10(peak / PCM_FULL_SCALE)

    return {
        "silence_ratio": _round_metric(silence_ratio),
        "max_contiguous_silence_seconds": _round_metric(max_silent_run_frames / SAMPLE_RATE),
        "dc_offset": [_round_metric(dc_offset[0]), _round_metric(dc_offset[1])],
        "peak_dbfs": _round_metric(peak_dbfs),
    }


def _require_wave_metrics(data: WaveData, label: str) -> dict[str, Any]:
    metrics = _basic_wave_metrics(data)
    _require(metrics["silence_ratio"] < 0.98, f"{label} silence_ratio must be below 0.98")
    _require(metrics["max_contiguous_silence_seconds"] <= 2.0, f"{label} max_contiguous_silence_seconds must be at most 2.0")
    _require(metrics["dc_offset"][0] <= 0.01 and metrics["dc_offset"][1] <= 0.01, f"{label} dc_offset must be at most 0.01 per channel")
    _require(metrics["peak_dbfs"] <= 0.0, f"{label} peak must be at or below 0 dBFS")
    return metrics


def _validate_wave_data(data: WaveData, expected_frames: int | None = None, *, label: str) -> None:
    _require(data.sample_rate == SAMPLE_RATE, f"{label} must be 44100 Hz PCM16")
    _require(data.channels == CHANNELS, f"{label} must be stereo PCM16")
    _require(data.bits_per_sample == BITS_PER_SAMPLE, f"{label} must be 16-bit PCM")
    _require(len(data.samples) == data.frame_count * CHANNELS, f"{label} contains malformed sample data")
    if expected_frames is not None:
        _require(data.frame_count == expected_frames, f"{label} must be exactly {expected_frames / SAMPLE_RATE:.0f} seconds")


def read_pcm16_wave(path: Path) -> WaveData:
    try:
        with wave.open(str(path), "rb") as handle:
            channels = handle.getnchannels()
            sample_width = handle.getsampwidth()
            sample_rate = handle.getframerate()
            frame_count = handle.getnframes()
            _require(channels == CHANNELS, "WAV must be stereo 16-bit PCM at 44100 Hz")
            _require(sample_width == SAMPLE_WIDTH_BYTES, "WAV must be stereo 16-bit PCM at 44100 Hz")
            _require(sample_rate == SAMPLE_RATE, "WAV must be stereo 16-bit PCM at 44100 Hz")
            samples = array("h")
            while True:
                payload = handle.readframes(READ_CHUNK_FRAMES)
                if not payload:
                    break
                _require(len(payload) % SAMPLE_WIDTH_BYTES == 0, "WAV payload is truncated")
                chunk = array("h")
                chunk.frombytes(payload)
                if sys.byteorder != "little":
                    chunk.byteswap()
                samples.extend(chunk)
    except (FileNotFoundError, EOFError, wave.Error) as exc:
        raise ValueError(f"unable to read PCM16 WAV: {exc}") from exc

    _require(len(samples) == frame_count * channels, "WAV payload is truncated")
    return WaveData(
        sample_rate=sample_rate,
        channels=channels,
        bits_per_sample=BITS_PER_SAMPLE,
        samples=samples,
    )


def write_pcm16_wave(path: Path, data: WaveData) -> None:
    _validate_wave_data(data, label="output wave")
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(data.channels)
        handle.setsampwidth(SAMPLE_WIDTH_BYTES)
        handle.setframerate(data.sample_rate)
        chunk_sample_count = WRITE_CHUNK_FRAMES * data.channels
        for sample_start in range(0, len(data.samples), chunk_sample_count):
            chunk = array("h", data.samples[sample_start:sample_start + chunk_sample_count])
            if sys.byteorder != "little":
                chunk.byteswap()
            handle.writeframes(chunk.tobytes())


def _build_section(candidate: WaveData, section_index: int) -> array:
    rotation_frame = int(round(SECTION_ROTATION_SECONDS[section_index] * SAMPLE_RATE))
    section_frame_count = int(round(SECTION_NOMINAL_SECONDS[section_index] * SAMPLE_RATE))
    gain_start, gain_end = SECTION_GAIN_RANGES[section_index]
    apply_low_pass = SECTION_LOW_PASS[section_index]
    ramp_denominator = max(1, section_frame_count - 1)
    section = array("h")
    low_pass_state = [0.0, 0.0]

    for local_frame_index in range(section_frame_count):
        source_frame_index = (rotation_frame + local_frame_index) % candidate.frame_count
        if gain_start == gain_end:
            gain = gain_start
        else:
            gain = gain_start + ((gain_end - gain_start) * (local_frame_index / ramp_denominator))
        source_sample_index = source_frame_index * CHANNELS
        for channel in range(CHANNELS):
            value = candidate.samples[source_sample_index + channel] * gain
            if apply_low_pass:
                if local_frame_index == 0:
                    low_pass_state[channel] = value
                else:
                    low_pass_state[channel] += LOW_PASS_ALPHA * (value - low_pass_state[channel])
                value = low_pass_state[channel]
            section.append(_clamp_pcm16(value))
    return section


def _append_with_equal_power_overlap(destination: array, section: array, overlap_frames: int) -> array:
    if not destination:
        return array("h", section)

    overlap_sample_count = overlap_frames * CHANNELS
    _require(len(destination) >= overlap_sample_count, "destination overlap is out of range")
    _require(len(section) >= overlap_sample_count, "section overlap is out of range")

    combined = array("h", destination[:-overlap_sample_count])
    for frame_index in range(overlap_frames):
        angle = (math.pi / 2.0) * (frame_index / (overlap_frames - 1))
        fade_out = math.cos(angle)
        fade_in = math.sin(angle)
        destination_sample_index = len(destination) - overlap_sample_count + (frame_index * CHANNELS)
        section_sample_index = frame_index * CHANNELS
        for channel in range(CHANNELS):
            blended = (
                destination[destination_sample_index + channel] * fade_out
                + section[section_sample_index + channel] * fade_in
            )
            combined.append(_clamp_pcm16(blended))
    combined.extend(section[overlap_sample_count:])
    return combined


def build_macro_guide(candidate_path: Path, output_path: Path, source_seconds: float, guide_crossfade_seconds: float) -> dict[str, Any]:
    _require(type(source_seconds) is float and source_seconds == GUIDE_SECONDS, "source_seconds must be 188.0")
    _require(type(guide_crossfade_seconds) is float and guide_crossfade_seconds == GUIDE_CROSSFADE_SECONDS, "guide_crossfade_seconds must be 1.0")

    candidate = read_pcm16_wave(candidate_path)
    _validate_wave_data(candidate, CANDIDATE_FRAMES, label="candidate")
    _require_wave_metrics(candidate, "candidate")

    guide_samples = array("h")
    sections: list[dict[str, Any]] = []
    for section_index, section_key in enumerate(SECTION_KEYS):
        section = _build_section(candidate, section_index)
        guide_samples = _append_with_equal_power_overlap(guide_samples, section, GUIDE_CROSSFADE_FRAMES)
        sections.append(
            {
                "key": section_key,
                "start_seconds": SECTION_STARTS_SECONDS[section_index],
                "rotation_seconds": SECTION_ROTATION_SECONDS[section_index],
                "nominal_seconds": SECTION_NOMINAL_SECONDS[section_index],
                "effective_seconds": SECTION_EFFECTIVE_SECONDS[section_index],
                "gain_start": SECTION_GAIN_RANGES[section_index][0],
                "gain_end": SECTION_GAIN_RANGES[section_index][1],
                "low_pass": SECTION_LOW_PASS[section_index],
            }
        )

    guide = WaveData(
        sample_rate=SAMPLE_RATE,
        channels=CHANNELS,
        bits_per_sample=BITS_PER_SAMPLE,
        samples=guide_samples,
    )
    _validate_wave_data(guide, GUIDE_FRAMES, label="guide")
    metrics = _require_wave_metrics(guide, "guide")
    write_pcm16_wave(output_path, guide)

    return {
        "path": str(output_path),
        "frame_count": guide.frame_count,
        "sample_rate": guide.sample_rate,
        "channels": guide.channels,
        "bits_per_sample": guide.bits_per_sample,
        "guide_crossfade_seconds": guide_crossfade_seconds,
        "section_starts_seconds": list(SECTION_STARTS_SECONDS),
        "section_rotation_seconds": list(SECTION_ROTATION_SECONDS),
        "section_nominal_seconds": list(SECTION_NOMINAL_SECONDS),
        "sections": sections,
        "silence_ratio": metrics["silence_ratio"],
        "max_contiguous_silence_seconds": metrics["max_contiguous_silence_seconds"],
        "dc_offset": metrics["dc_offset"],
        "peak_dbfs": metrics["peak_dbfs"],
        "sha256": _sha256_file(output_path),
    }


def _join_report(samples: array, frame_count: int, *, left_end_frame: int, right_start_frame: int, label: str) -> dict[str, Any]:
    window_frames = SAMPLE_RATE
    left_window_start = left_end_frame - window_frames + 1
    right_window_start = right_start_frame
    _require(left_window_start >= 0, f"{label} left analysis window is out of range")
    _require(right_window_start + window_frames <= frame_count, f"{label} right analysis window is out of range")

    channel_reports: list[dict[str, Any]] = []
    passes = True
    for channel in range(CHANNELS):
        jump = abs(
            samples[(left_end_frame * CHANNELS) + channel]
            - samples[(right_start_frame * CHANNELS) + channel]
        ) / PCM_FULL_SCALE
        distribution = _adjacent_jumps(samples, left_window_start, window_frames, channel)
        distribution.extend(_adjacent_jumps(samples, right_window_start, window_frames, channel))
        local_p99 = _p99(distribution)
        limit = max(0.02, 4.0 * local_p99)
        left_rms = _normalized_rms(samples, left_window_start, window_frames, channel)
        right_rms = _normalized_rms(samples, right_window_start, window_frames, channel)
        rms_delta_db = _rms_delta_db(left_rms, right_rms)
        channel_passes = jump <= limit and rms_delta_db <= 3.0
        passes = passes and channel_passes
        channel_reports.append(
            {
                "channel": channel,
                "join_jump": _round_metric(jump),
                "local_p99_adjacent_jump": _round_metric(local_p99),
                "join_jump_limit": _round_metric(limit),
                "rms_delta_db": _round_metric(rms_delta_db),
                "passes": channel_passes,
            }
        )

    return {
        "label": label,
        "left_end_frame": left_end_frame,
        "right_start_frame": right_start_frame,
        "passes": passes,
        "channels": channel_reports,
    }


def _analyze_loop_edges_data(master: WaveData, repeat_count: int) -> dict[str, Any]:
    _validate_wave_data(master, MASTER_FRAMES, label="master")
    metrics = _basic_wave_metrics(master)

    seam = _join_report(
        master.samples,
        master.frame_count,
        left_end_frame=master.frame_count - 1,
        right_start_frame=0,
        label="playback_seam",
    )
    internal_join = _join_report(
        master.samples,
        master.frame_count,
        left_end_frame=LOOP_CROSSFADE_FRAMES - 1,
        right_start_frame=LOOP_CROSSFADE_FRAMES,
        label="internal_join",
    )

    wrap_transitions: list[dict[str, Any]] = []
    for boundary_index in range(repeat_count - 1):
        wrap_transitions.append(
            {
                "boundary_index": boundary_index + 1,
                "passes": seam["passes"],
                "channels": [
                    {
                        "channel": channel_report["channel"],
                        "join_jump": channel_report["join_jump"],
                        "local_p99_adjacent_jump": channel_report["local_p99_adjacent_jump"],
                        "join_jump_limit": channel_report["join_jump_limit"],
                        "rms_delta_db": channel_report["rms_delta_db"],
                        "passes": channel_report["passes"],
                    }
                    for channel_report in seam["channels"]
                ],
            }
        )

    status = "pass"
    if not seam["passes"] or not internal_join["passes"]:
        status = "fail"
    if metrics["silence_ratio"] >= 0.98 or metrics["max_contiguous_silence_seconds"] > 2.0:
        status = "fail"
    if metrics["dc_offset"][0] > 0.01 or metrics["dc_offset"][1] > 0.01:
        status = "fail"
    if metrics["peak_dbfs"] > 0.0:
        status = "fail"
    if any(not item["passes"] for item in wrap_transitions):
        status = "fail"

    return {
        "path": "",
        "status": status,
        "frame_count": master.frame_count,
        "sample_rate": master.sample_rate,
        "channels": master.channels,
        "bits_per_sample": master.bits_per_sample,
        "repeat_count": repeat_count,
        "crossfade_frames": LOOP_CROSSFADE_FRAMES,
        "silence_ratio": metrics["silence_ratio"],
        "max_contiguous_silence_seconds": metrics["max_contiguous_silence_seconds"],
        "dc_offset": metrics["dc_offset"],
        "peak_dbfs": metrics["peak_dbfs"],
        "seam": seam,
        "internal_join": internal_join,
        "wrap_transitions": wrap_transitions,
    }


def render_circular_loop(source_path: Path, output_path: Path, source_seconds: float, master_seconds: float, crossfade_seconds: float) -> dict[str, Any]:
    _require(type(source_seconds) is float and source_seconds == GUIDE_SECONDS, "source_seconds must be 188.0")
    _require(type(master_seconds) is float and master_seconds == MASTER_SECONDS, "master_seconds must be 180.0")
    _require(type(crossfade_seconds) is float and crossfade_seconds == LOOP_CROSSFADE_SECONDS, "crossfade_seconds must be 8.0")

    source = read_pcm16_wave(source_path)
    _validate_wave_data(source, GUIDE_FRAMES, label="source")
    _require_wave_metrics(source, "source")

    tail_start_frame = int(round(MASTER_SECONDS * SAMPLE_RATE))
    master_samples = array("h")
    for frame_index in range(LOOP_CROSSFADE_FRAMES):
        angle = (math.pi / 2.0) * (frame_index / (LOOP_CROSSFADE_FRAMES - 1))
        tail_gain = math.cos(angle)
        head_gain = math.sin(angle)
        tail_sample_index = (tail_start_frame + frame_index) * CHANNELS
        head_sample_index = frame_index * CHANNELS
        for channel in range(CHANNELS):
            blended = (
                source.samples[tail_sample_index + channel] * tail_gain
                + source.samples[head_sample_index + channel] * head_gain
            )
            master_samples.append(_clamp_pcm16(blended))

    body_sample_start = LOOP_CROSSFADE_FRAMES * CHANNELS
    body_sample_stop = tail_start_frame * CHANNELS
    master_samples.extend(source.samples[body_sample_start:body_sample_stop])

    master = WaveData(
        sample_rate=SAMPLE_RATE,
        channels=CHANNELS,
        bits_per_sample=BITS_PER_SAMPLE,
        samples=master_samples,
    )
    _validate_wave_data(master, MASTER_FRAMES, label="master")
    _require_wave_metrics(master, "master")
    analysis = _analyze_loop_edges_data(master, repeat_count=10)
    _require(analysis["status"] == "pass", "rendered master failed loop edge analysis")
    write_pcm16_wave(output_path, master)
    analysis["path"] = str(output_path)

    return {
        "path": str(output_path),
        "frame_count": master.frame_count,
        "sample_rate": master.sample_rate,
        "channels": master.channels,
        "bits_per_sample": master.bits_per_sample,
        "crossfade_frames": LOOP_CROSSFADE_FRAMES,
        "silence_ratio": analysis["silence_ratio"],
        "max_contiguous_silence_seconds": analysis["max_contiguous_silence_seconds"],
        "dc_offset": analysis["dc_offset"],
        "peak_dbfs": analysis["peak_dbfs"],
        "edge_analysis": analysis,
        "sha256": _sha256_file(output_path),
    }


def build_transition_preview(master_path: Path, output_path: Path, window_seconds: float = 15.0) -> dict[str, Any]:
    _require(type(window_seconds) is float and window_seconds > 0.0, "window_seconds must be a positive float")
    master = read_pcm16_wave(master_path)
    _validate_wave_data(master, MASTER_FRAMES, label="master")
    window_frames = int(round(window_seconds * SAMPLE_RATE))
    _require(window_frames * 2 <= master.frame_count, "master must be exactly 180 seconds for preview extraction")

    preview_samples = array("h")
    preview_samples.extend(master.samples[(master.frame_count - window_frames) * CHANNELS:])
    preview_samples.extend(master.samples[:window_frames * CHANNELS])
    preview = WaveData(
        sample_rate=SAMPLE_RATE,
        channels=CHANNELS,
        bits_per_sample=BITS_PER_SAMPLE,
        samples=preview_samples,
    )
    _validate_wave_data(preview, window_frames * 2, label="preview")
    _require_wave_metrics(preview, "preview")
    write_pcm16_wave(output_path, preview)

    return {
        "path": str(output_path),
        "frame_count": preview.frame_count,
        "sample_rate": preview.sample_rate,
        "channels": preview.channels,
        "bits_per_sample": preview.bits_per_sample,
        "window_seconds": window_seconds,
        "sha256": _sha256_file(output_path),
    }


def analyze_loop_edges(master_path: Path, repeat_count: int = 10) -> dict[str, Any]:
    _require(type(repeat_count) is int and repeat_count >= 2, "repeat_count must be an integer of at least 2")
    master = read_pcm16_wave(master_path)
    _validate_wave_data(master, MASTER_FRAMES, label="master")
    analysis = _analyze_loop_edges_data(master, repeat_count)
    analysis["path"] = str(master_path)
    return analysis
