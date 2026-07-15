#!/usr/bin/env python3
"""Deterministic, stdlib-only evidence tooling for frozen M1 phase cards.

This tool intentionally reads authored data and recorded trace files only.  It
does not import Godot and an authored schedule preview is never bullet evidence.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
from typing import Any, Iterable


TOOL_SCHEMA_VERSION = 1
TRACE_SCHEMA_VERSION = 1
PLAYFIELD_WIDTH = 720
PLAYFIELD_HEIGHT = 960

# This is deliberately independent of the authored M1 card contract above.  The
# Stage 2 producer is not available yet; these constants define the narrow v1
# capture contract that its Release build must satisfy.
STAGE2_CAPTURE_SCHEMA_VERSION = 1
STAGE2_PHASE_ORDER = (
    "stage_2_midboss_nonspell_1",
    "stage_2_midboss_spell_1",
    "stage_2_boss_nonspell_1",
    "stage_2_boss_spell_1",
    "stage_2_boss_spell_2",
    "stage_2_boss_spell_3",
)
STAGE2_HEADER = {
    "record_type": "m2_stage2_runtime_capture_header",
    "schema_version": STAGE2_CAPTURE_SCHEMA_VERSION,
    "evidence_kind": "real_runtime_capture",
    "source": "main_bullet_world",
    "build_kind": "release",
    "stage_id": "youkai_market",
    "simulation_hz": 60,
}


class ToolError(ValueError):
    """An input-contract error that must produce a nonzero CLI exit code."""


def _json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)


def _load_cards(path: Path) -> tuple[dict[str, Any], str]:
    try:
        raw = path.read_bytes()
        root = json.loads(raw.decode("utf-8-sig"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ToolError("could not load cards: %s" % error) from error
    if not isinstance(root, dict) or root.get("schema_version") != "m1-phase-cards-v1":
        raise ToolError("cards must be a m1-phase-cards-v1 object")
    if root.get("simulation_hz") != 60 or not isinstance(root.get("phases"), list):
        raise ToolError("cards are missing the frozen 60 Hz phase list")
    return root, hashlib.sha256(raw).hexdigest()


def _phase_index(cards: dict[str, Any]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for phase in cards["phases"]:
        if not isinstance(phase, dict) or not isinstance(phase.get("id"), str) or phase["id"] in result:
            raise ToolError("cards contain a malformed or duplicate phase id")
        result[phase["id"]] = phase
    return result


def phase_local_seed(run_seed: int, stream_id: str) -> int:
    """Match BossPhaseDefinition.derive_phase_local_seed exactly."""
    if not stream_id:
        return 0
    digest = hashlib.sha256(("m1-phase-local-seed-v1|%d|%s" % (run_seed, stream_id)).encode("utf-8")).digest()
    value = int.from_bytes(bytes([digest[0] & 0x7F]) + digest[1:8], "big")
    return value or 1


def _fingerprint_input(phase: dict[str, Any]) -> dict[str, Any]:
    value = phase.get("structure_fingerprint_input")
    if not isinstance(value, dict):
        raise ToolError("phase %s has no structure_fingerprint_input" % phase.get("id", "<unknown>"))
    return value


def canonical_fingerprint(values: dict[str, Any]) -> str:
    """Runtime grammar: grammar|E:roles|T:events|M:graph|N:topology|H:change|W:warnings."""
    emitters = values.get("emitter_composition", [])
    events = values.get("ordered_events", [])
    if not isinstance(emitters, list) or not isinstance(events, list):
        raise ToolError("fingerprint composition and events must be lists")
    return "%s|E:%s|T:%s|M:%s|N:%s|H:%s|W:%s" % (
        str(values.get("grammar", "")), ">".join(map(str, emitters)), ">".join(map(str, events)),
        str(values.get("movement_graph", "")), str(values.get("normal_topology", "")),
        str(values.get("hard_transformation", "")), str(values.get("warning_contract", "")),
    )


def legacy_source_fingerprint(values: dict[str, Any]) -> str:
    events = values.get("ordered_events", [])
    if not isinstance(events, list):
        raise ToolError("fingerprint events must be a list")
    return "%s|%s|%s|N:%s|H:%s|W:%s" % (
        str(values.get("grammar", "")), ">".join(map(str, events)), str(values.get("movement_graph", "")),
        str(values.get("normal_topology", "")), str(values.get("hard_transformation", "")),
        str(values.get("warning_contract", "")),
    )


def fingerprints(cards: dict[str, Any], content_hash: str) -> dict[str, Any]:
    phases = cards["phases"]
    seen: set[str] = set()
    records: list[dict[str, Any]] = []
    spells = nonspells = drift = 0
    for phase in phases:
        if not isinstance(phase, dict):
            raise ToolError("phase record is not an object")
        values = _fingerprint_input(phase)
        runtime = canonical_fingerprint(values)
        legacy = legacy_source_fingerprint(values)
        duplicate = runtime in seen
        seen.add(runtime)
        if phase.get("kind") == "spell":
            spells += 1
        elif phase.get("kind") == "nonspell":
            nonspells += 1
        else:
            drift += 1
        valid = runtime == phase.get("runtime_structure_fingerprint", runtime) and legacy == phase.get("structure_fingerprint")
        if not valid or duplicate:
            drift += 1
        records.append({"phase_id": phase.get("id"), "runtime_canonical_fingerprint": runtime,
                        "legacy_source_fingerprint": legacy, "stored_legacy_matches": legacy == phase.get("structure_fingerprint"),
                        "duplicate": duplicate})
    report = {"schema_version": TOOL_SCHEMA_VERSION, "command": "fingerprints", "content_sha256": content_hash,
              "phase_count": len(phases), "spell_count": spells, "nonspell_count": nonspells,
              "unique_fingerprint_count": len(seen), "drift_count": drift, "fingerprints": records}
    if len(phases) != 40 or spells != 26 or nonspells != 14 or len(seen) != 40 or drift:
        raise ToolError("frozen M1 fingerprint contract drifted: %s" % _json(report))
    return report


def _events_in_window(events: Iterable[dict[str, Any]], start: int, end: int, loop: int) -> list[dict[str, Any]]:
    selected: list[dict[str, Any]] = []
    if loop <= 0:
        raise ToolError("authored schedule has no positive loop length")
    for iteration in range(start // loop, end // loop + 1):
        for authored_order, event in enumerate(events):
            if not isinstance(event, dict) or not isinstance(event.get("frame"), int):
                raise ToolError("authored event lacks an integer frame")
            absolute = iteration * loop + event["frame"]
            if start <= absolute <= end:
                selected.append({"frame": absolute, "loop_iteration": iteration, "authored_order": authored_order,
                                 "event": event.get("event", ""), "action": event.get("action", ""),
                                 "warning": event.get("warning", "")})
    ordered = sorted(selected, key=lambda value: (value["frame"], value["authored_order"]))
    for event in ordered:
        del event["authored_order"]
    return ordered


def sandbox(cards: dict[str, Any], content_hash: str, phase_id: str, difficulty: str, run_seed: int, seek_frame: int,
            window: int) -> dict[str, Any]:
    phases = _phase_index(cards)
    if phase_id not in phases:
        raise ToolError("unknown frozen phase id: %s" % phase_id)
    if difficulty not in {"normal", "hard"}:
        raise ToolError("difficulty must be normal or hard")
    if seek_frame < 0 or window < 0:
        raise ToolError("seek frame and window must be nonnegative")
    phase = phases[phase_id]
    normal = phase.get("normal_structure", {})
    if not isinstance(normal, dict):
        raise ToolError("phase normal_structure is malformed")
    loop = normal.get("loop_frames")
    if not isinstance(loop, int):
        raise ToolError("phase normal_structure has no loop_frames")
    end = seek_frame + window
    emitters = phase.get("emitters", [])
    if not isinstance(emitters, list):
        raise ToolError("phase emitters are malformed")
    return {"schema_version": TOOL_SCHEMA_VERSION, "command": "sandbox", "evidence_kind": "authored_schedule_preview",
            "runtime_evidence": False, "content_sha256": content_hash, "phase_id": phase_id, "difficulty": difficulty,
            "run_seed": run_seed, "phase_local_seed": phase_local_seed(run_seed, str(phase.get("deterministic_random_stream_id", ""))),
            "seek_frame": seek_frame, "window": {"start_frame": seek_frame, "end_frame": end},
            "warnings": ["Authored schedule only: no runtime capture was supplied.",
                         "No projectile positions, collisions, or playability are asserted."],
            "ordered_events": _events_in_window(phase.get("timeline", []), seek_frame, end, loop),
            "emitter_schedules": emitters, "movement": phase.get("boss_movement", []),
            "topology": {"normal": phase.get("normal_structure"), "hard": phase.get("hard_topology_change"),
                         "selected": phase.get("hard_topology_change") if difficulty == "hard" else phase.get("normal_structure")}}


def _finite_number(value: Any, name: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise ToolError("%s must be a finite number" % name)
    return float(value)


def _read_jsonl(path: Path) -> list[dict[str, Any]]:
    try:
        lines = path.read_text(encoding="utf-8-sig").splitlines()
    except OSError as error:
        raise ToolError("could not read trace: %s" % error) from error
    if not lines:
        raise ToolError("trace is empty")
    rows: list[dict[str, Any]] = []
    for line_number, line in enumerate(lines, 1):
        try:
            row = json.loads(line)
        except json.JSONDecodeError as error:
            raise ToolError("trace line %d is not JSON: %s" % (line_number, error.msg)) from error
        if not isinstance(row, dict):
            raise ToolError("trace line %d must be an object" % line_number)
        rows.append(row)
    return rows


def read_trace(trace_path: Path, cards: dict[str, Any], cards_hash: str, phase_id: str | None = None,
               difficulty: str | None = None) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    rows = _read_jsonl(trace_path)
    header, frames = rows[0], rows[1:]
    required = {"record_type": "m1_runtime_trace_header", "schema_version": TRACE_SCHEMA_VERSION, "simulation_hz": 60}
    for key, value in required.items():
        if header.get(key) != value:
            raise ToolError("trace header %s must equal %r" % (key, value))
    if header.get("content_sha256") != cards_hash:
        raise ToolError("trace content_sha256 does not bind to supplied cards")
    if header.get("source") not in {"runtime_capture", "synthetic"}:
        raise ToolError("trace source must be runtime_capture or synthetic")
    if header.get("difficulty") not in {"normal", "hard"}:
        raise ToolError("trace header difficulty is invalid")
    if phase_id is not None and header.get("phase_id") != phase_id:
        raise ToolError("trace phase_id mismatches requested phase")
    if difficulty is not None and header.get("difficulty") != difficulty:
        raise ToolError("trace difficulty mismatches requested difficulty")
    playfield = header.get("playfield")
    if playfield != {"width": PLAYFIELD_WIDTH, "height": PLAYFIELD_HEIGHT}:
        raise ToolError("trace playfield must be exactly 720x960")
    if not isinstance(header.get("run_seed"), int) or not isinstance(header.get("phase_id"), str):
        raise ToolError("trace header run_seed and phase_id are required")
    if not isinstance(header.get("phase_local_seed"), int):
        raise ToolError("trace header phase_local_seed is required")
    phase = _phase_index(cards).get(header["phase_id"])
    if phase is None:
        raise ToolError("trace phase_id is not a frozen M1 phase")
    expected_seed = phase_local_seed(header["run_seed"], str(phase.get("deterministic_random_stream_id", "")))
    if header["phase_local_seed"] != expected_seed:
        raise ToolError("trace phase_local_seed does not match its run seed and frozen stream")
    strict = header.get("strict_bounds")
    if not isinstance(strict, bool):
        raise ToolError("trace header strict_bounds must be boolean")
    previous = -1
    normalized: list[dict[str, Any]] = []
    for row in frames:
        if row.get("record_type") != "frame" or not isinstance(row.get("frame"), int):
            raise ToolError("trace frame records require record_type=frame and integer frame")
        frame = row["frame"]
        if frame != previous + 1:
            raise ToolError("trace frames must begin at 0 and advance one 60 Hz tick at a time")
        previous = frame
        frame_time = _finite_number(row.get("frame_time_ms"), "frame_time_ms")
        bullets = row.get("bullets")
        if not isinstance(bullets, list):
            raise ToolError("frame %d bullets must be a list" % frame)
        identifiers: set[str] = set()
        normalized_bullets = []
        for bullet in bullets:
            if not isinstance(bullet, dict) or "id" not in bullet:
                raise ToolError("frame %d has a malformed bullet" % frame)
            identifier = str(bullet["id"])
            if identifier in identifiers:
                raise ToolError("frame %d contains duplicate bullet id %s" % (frame, identifier))
            identifiers.add(identifier)
            x, y = _finite_number(bullet.get("x"), "bullet.x"), _finite_number(bullet.get("y"), "bullet.y")
            in_bounds = 0 <= x < PLAYFIELD_WIDTH and 0 <= y < PLAYFIELD_HEIGHT
            if strict and not in_bounds:
                raise ToolError("frame %d contains out-of-bounds bullet under strict_bounds" % frame)
            normalized_bullets.append({"id": identifier, "x": x, "y": y, "in_bounds": in_bounds})
        normalized.append({"frame": frame, "frame_time_ms": frame_time, "bullets": normalized_bullets})
    if not normalized:
        raise ToolError("trace contains no frame records")
    return header, normalized


def _normalized_state(frame: dict[str, Any]) -> dict[str, Any]:
    return {"frame": frame["frame"], "bullets": sorted(
        [{"id": bullet["id"], "x": bullet["x"], "y": bullet["y"]} for bullet in frame["bullets"]], key=lambda item: item["id"])}


def trace_seek(header: dict[str, Any], frames: list[dict[str, Any]], seek_frame: int) -> dict[str, Any]:
    if seek_frame < 0 or seek_frame >= len(frames):
        raise ToolError("seek frame is outside recorded trace")
    sequential = None
    for frame in frames:
        if frame["frame"] == seek_frame:
            sequential = _normalized_state(frame)
            break
    direct = _normalized_state(frames[seek_frame])
    if sequential != direct:
        raise ToolError("direct trace seek differs from sequential scan")
    return {"schema_version": TOOL_SCHEMA_VERSION, "command": "trace-seek", "evidence_kind": "runtime_trace" if header["source"] == "runtime_capture" else "synthetic_trace",
            "runtime_evidence": header["source"] == "runtime_capture", "phase_id": header["phase_id"], "difficulty": header["difficulty"],
            "seek_frame": seek_frame, "sequential_equals_direct": True, "frame_state": direct}


def _percentile(values: list[float], fraction: float) -> float:
    # Nearest-rank percentile: index ceil(p*n)-1, deterministic without interpolation.
    if not values:
        raise ToolError("cannot calculate percentile of no values")
    ordered = sorted(values)
    return ordered[max(0, math.ceil(fraction * len(ordered)) - 1)]


def _heatmap_svg(grid: list[list[int]], cell_width: int, cell_height: int, maximum: int,
                 title: str = "M1 trace occupancy heatmap") -> str:
    rectangles = []
    for row_index, row in enumerate(grid):
        for column_index, count in enumerate(row):
            shade = 255 if maximum == 0 else 255 - round(220 * count / maximum)
            rectangles.append('<rect x="%d" y="%d" width="%d" height="%d" fill="rgb(255,%d,%d)"/>' %
                              (column_index * cell_width, row_index * cell_height, cell_width, cell_height, shade, shade))
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="720" height="960" viewBox="0 0 720 960">'
            '<title>%s</title><rect width="720" height="960" fill="rgb(255,255,255)"/>' % title +
            "".join(rectangles) + "</svg>\n")


def analyze(header: dict[str, Any], frames: list[dict[str, Any]], start: int, end: int, columns: int, rows: int) -> tuple[dict[str, Any], str]:
    if start < 0 or end < start or end >= len(frames) or columns <= 0 or rows <= 0:
        raise ToolError("invalid analysis window or heatmap grid")
    if PLAYFIELD_WIDTH % columns or PLAYFIELD_HEIGHT % rows:
        raise ToolError("heatmap grid must divide the 720x960 playfield exactly")
    cell_width, cell_height = PLAYFIELD_WIDTH // columns, PLAYFIELD_HEIGHT // rows
    grid = [[0 for _ in range(columns)] for _ in range(rows)]
    curve, times = [], []
    out_of_bounds = 0
    for frame in frames[start:end + 1]:
        curve.append({"frame": frame["frame"], "active_bullets": len(frame["bullets"])})
        times.append(frame["frame_time_ms"])
        for bullet in frame["bullets"]:
            if not bullet["in_bounds"]:
                out_of_bounds += 1
                continue
            grid[int(bullet["y"] // cell_height)][int(bullet["x"] // cell_width)] += 1
    maximum = max((max(row) for row in grid), default=0)
    result = {"schema_version": TOOL_SCHEMA_VERSION, "command": "analyze", "evidence_kind": "runtime_trace" if header["source"] == "runtime_capture" else "synthetic_trace",
              "runtime_evidence": header["source"] == "runtime_capture", "source": header["source"], "phase_id": header["phase_id"],
              "difficulty": header["difficulty"], "content_sha256": header["content_sha256"], "window": {"start_frame": start, "end_frame": end},
              "active_bullet_curve": curve, "peak_active_bullets": max(item["active_bullets"] for item in curve),
              "out_of_bounds_bullet_samples": out_of_bounds, "heatmap": {"playfield": {"width": 720, "height": 960}, "columns": columns,
              "rows": rows, "cell_width": cell_width, "cell_height": cell_height, "occupancy": grid},
              "frame_time_ms": {"percentile_method": "nearest_rank", "p50": _percentile(times, .50), "p95": _percentile(times, .95), "p99": _percentile(times, .99)}}
    return result, _heatmap_svg(grid, cell_width, cell_height, maximum)


def _nonnegative_int(value: Any, name: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise ToolError("%s must be a nonnegative integer" % name)
    return value


def _stage2_header(header: dict[str, Any]) -> dict[str, Any]:
    """Validate the identity claim before accepting any capture sample.

    The v1 contract is JSONL with one header, contiguous `tick` samples and one
    `render_frame` for every tick, event/phase-ledger records, then one complete
    footer.  A tick contains `tick`, `simulation_time_s`, `phase_id`, and a
    `bullets` list of `{id, x, y}`.  A render frame contains `frame_index`,
    `tick`, `present_time_s`, and `frame_time_ms`.  Events contain `event`,
    `tick`, and `time_s`; phase ledgers contain `phase_id`, `start_tick`,
    `end_tick`, `time_to_clear_ms`, `score_delta`, `drop_count`, and
    `capture_count`.

    This intentionally rejects an authored preview, synthetic source, debug
    build, missing windowed identity, or a headless claim.  Unknown record types
    also fail closed so a partial/new producer cannot be misreported as v1
    runtime evidence.
    """
    for key, expected in STAGE2_HEADER.items():
        if header.get(key) != expected:
            raise ToolError("stage2 header %s must equal %r" % (key, expected))
    if header.get("playfield") != {"width": PLAYFIELD_WIDTH, "height": PLAYFIELD_HEIGHT}:
        raise ToolError("stage2 header playfield must be exactly 720x960")
    difficulty = header.get("difficulty")
    if not isinstance(difficulty, str) or difficulty.lower() not in {"normal", "hard"}:
        raise ToolError("stage2 header difficulty must identify Normal or Hard")
    if not isinstance(header.get("run_seed"), int) or isinstance(header.get("run_seed"), bool):
        raise ToolError("stage2 header run_seed must be an integer")
    if header.get("runtime_evidence") is not True:
        raise ToolError("stage2 header runtime_evidence must be true")
    if header.get("execution_mode") != "windowed" or header.get("headless") is not False:
        raise ToolError("stage2 header must declare execution_mode=windowed and headless=false")
    normalized = dict(header)
    normalized["difficulty"] = difficulty.lower()
    return normalized


def _stage2_bullet_samples(row: dict[str, Any], tick: int) -> list[dict[str, Any]]:
    bullets = row.get("bullets")
    if not isinstance(bullets, list):
        raise ToolError("stage2 tick %d bullets must be a list" % tick)
    identifiers: set[str] = set()
    normalized: list[dict[str, Any]] = []
    for bullet in bullets:
        if not isinstance(bullet, dict) or not isinstance(bullet.get("id"), str) or not bullet["id"]:
            raise ToolError("stage2 tick %d contains a bullet without a stable string id" % tick)
        identifier = bullet["id"]
        if identifier in identifiers:
            raise ToolError("stage2 tick %d contains duplicate active bullet id %s" % (tick, identifier))
        identifiers.add(identifier)
        x = _finite_number(bullet.get("x"), "stage2 bullet.x")
        y = _finite_number(bullet.get("y"), "stage2 bullet.y")
        if not (0 <= x < PLAYFIELD_WIDTH and 0 <= y < PLAYFIELD_HEIGHT):
            raise ToolError("stage2 tick %d contains an out-of-bounds active bullet" % tick)
        normalized.append({"id": identifier, "x": x, "y": y})
    return normalized


def _stage2_expected_events() -> list[tuple[str, str | None]]:
    expected: list[tuple[str, str | None]] = [("stage_started", None)]
    for phase_id in STAGE2_PHASE_ORDER:
        expected.extend((("phase_gate_open", phase_id), ("phase_started", phase_id), ("phase_cleared", phase_id)))
    expected.append(("stage_cleared", None))
    return expected


def _stage2_curve_svg(curve: list[dict[str, int]], title: str) -> str:
    maximum = max((sample["active_bullets"] for sample in curve), default=0)
    denominator = max(1, len(curve) - 1)
    points = " ".join("%d,%d" % (round(720 * index / denominator),
                                  220 if maximum == 0 else 220 - round(200 * sample["active_bullets"] / maximum))
                      for index, sample in enumerate(curve))
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="720" height="240" viewBox="0 0 720 240">'
            '<title>%s</title><rect width="720" height="240" fill="rgb(255,255,255)"/>'
            '<line x1="0" y1="220" x2="720" y2="220" stroke="rgb(100,100,100)"/>'
            '<polyline fill="none" stroke="rgb(180,0,0)" stroke-width="2" points="%s"/></svg>\n' % (title, points))


def read_stage2_capture(capture_path: Path) -> tuple[dict[str, Any], list[dict[str, Any]], list[dict[str, Any]],
                                                       list[dict[str, Any]], list[dict[str, Any]]]:
    """Read the strict Stage 2 v1 real-runtime JSONL contract.

    Return header, normalized ticks, normalized render frames, events, and
    ordered phase ledgers.  Every violation raises ToolError for a nonzero CLI
    exit; callers must not treat a returned report as actual game evidence.
    """
    records = _read_jsonl(capture_path)
    if len(records) < 3 or records[0].get("record_type") != STAGE2_HEADER["record_type"]:
        raise ToolError("stage2 capture must begin with its v1 runtime header")
    header = _stage2_header(records[0])
    if records[-1].get("record_type") != "footer":
        raise ToolError("stage2 capture must end with one complete footer")
    allowed_types = {STAGE2_HEADER["record_type"], "tick", "render_frame", "event", "phase_ledger", "footer"}
    for index, record in enumerate(records):
        record_type = record.get("record_type")
        if record_type not in allowed_types:
            raise ToolError("stage2 capture record %d has unknown record_type" % index)
        if index and record_type == STAGE2_HEADER["record_type"]:
            raise ToolError("stage2 capture contains a duplicate header")
        if index != len(records) - 1 and record_type == "footer":
            raise ToolError("stage2 capture footer must be the final record")
        for key, required in (("evidence_kind", "real_runtime_capture"), ("source", "main_bullet_world"),
                              ("build_kind", "release")):
            if key in record and record[key] != required:
                raise ToolError("stage2 capture record %d has a non-runtime %s claim" % (index, key))
        if record.get("runtime_evidence") is False:
            raise ToolError("stage2 capture record %d denies runtime evidence" % index)
        if record.get("headless") is True or record.get("execution_mode") == "headless":
            raise ToolError("stage2 capture record %d contains a headless claim" % index)

    footer = records[-1]
    if footer.get("complete") is not True:
        raise ToolError("stage2 footer complete must be true")
    for key in ("hard_error_count", "overflow_count", "out_of_bounds_count", "death_count"):
        if _nonnegative_int(footer.get(key), "stage2 footer %s" % key) != 0:
            raise ToolError("stage2 footer %s must be zero" % key)

    ticks: list[dict[str, Any]] = []
    renders: list[dict[str, Any]] = []
    events: list[dict[str, Any]] = []
    ledgers: list[dict[str, Any]] = []
    for record in records[1:-1]:
        record_type = record["record_type"]
        if record_type == "tick":
            tick = _nonnegative_int(record.get("tick"), "stage2 tick")
            if tick != len(ticks):
                raise ToolError("stage2 ticks must begin at 0 and advance exactly once per simulation step")
            phase_id = record.get("phase_id")
            if phase_id not in STAGE2_PHASE_ORDER:
                raise ToolError("stage2 tick %d has an unapproved phase_id" % tick)
            simulation_time = _finite_number(record.get("simulation_time_s"), "stage2 simulation_time_s")
            if simulation_time < 0 or not math.isclose(simulation_time, tick / 60, abs_tol=1e-9):
                raise ToolError("stage2 tick %d has mismatched simulation_time_s" % tick)
            ticks.append({"tick": tick, "phase_id": phase_id, "simulation_time_s": simulation_time,
                          "bullets": _stage2_bullet_samples(record, tick)})
        elif record_type == "render_frame":
            frame_index = _nonnegative_int(record.get("frame_index"), "stage2 render frame_index")
            if frame_index != len(renders):
                raise ToolError("stage2 render frames must begin at 0 and advance exactly once")
            tick = _nonnegative_int(record.get("tick"), "stage2 render tick")
            present_time = _finite_number(record.get("present_time_s"), "stage2 present_time_s")
            frame_time = _finite_number(record.get("frame_time_ms"), "stage2 frame_time_ms")
            if present_time < 0 or frame_time < 0:
                raise ToolError("stage2 render times must be nonnegative")
            renders.append({"frame_index": frame_index, "tick": tick, "present_time_s": present_time,
                            "frame_time_ms": frame_time})
        elif record_type == "event":
            event = record.get("event")
            if not isinstance(event, str) or not event:
                raise ToolError("stage2 event requires a nonempty event name")
            tick = _nonnegative_int(record.get("tick"), "stage2 event tick")
            time_s = _finite_number(record.get("time_s"), "stage2 event time_s")
            if time_s < 0:
                raise ToolError("stage2 event time_s must be nonnegative")
            events.append({"event": event, "tick": tick, "time_s": time_s, "phase_id": record.get("phase_id")})
        elif record_type == "phase_ledger":
            phase_id = record.get("phase_id")
            if phase_id not in STAGE2_PHASE_ORDER:
                raise ToolError("stage2 phase ledger has an unapproved phase_id")
            start_tick = _nonnegative_int(record.get("start_tick"), "stage2 phase ledger start_tick")
            end_tick = _nonnegative_int(record.get("end_tick"), "stage2 phase ledger end_tick")
            if end_tick < start_tick:
                raise ToolError("stage2 phase ledger end_tick precedes start_tick")
            time_to_clear = _finite_number(record.get("time_to_clear_ms"), "stage2 time_to_clear_ms")
            if time_to_clear < 0:
                raise ToolError("stage2 time_to_clear_ms must be nonnegative")
            ledgers.append({"phase_id": phase_id, "start_tick": start_tick, "end_tick": end_tick,
                            "time_to_clear_ms": time_to_clear,
                            "score_delta": _nonnegative_int(record.get("score_delta"), "stage2 score_delta"),
                            "drop_count": _nonnegative_int(record.get("drop_count"), "stage2 drop_count"),
                            "capture_count": _nonnegative_int(record.get("capture_count"), "stage2 capture_count")})

    if not ticks or not renders:
        raise ToolError("stage2 capture requires tick and render-frame samples")
    if len(renders) != len(ticks) or [frame["tick"] for frame in renders] != [tick["tick"] for tick in ticks]:
        raise ToolError("stage2 capture requires exactly one render-frame sample for every tick")
    if [ledger["phase_id"] for ledger in ledgers] != list(STAGE2_PHASE_ORDER):
        raise ToolError("stage2 capture requires six ordered approved phase-ledger rows")
    phase_runs: list[str] = []
    for sample in ticks:
        if not phase_runs or phase_runs[-1] != sample["phase_id"]:
            phase_runs.append(sample["phase_id"])
    if tuple(phase_runs) != STAGE2_PHASE_ORDER:
        raise ToolError("stage2 tick samples must cover each approved phase exactly once in order")
    for ledger in ledgers:
        phase_ticks = [sample["tick"] for sample in ticks if sample["phase_id"] == ledger["phase_id"]]
        if not phase_ticks or ledger["start_tick"] != phase_ticks[0] or ledger["end_tick"] != phase_ticks[-1]:
            raise ToolError("stage2 phase ledger boundaries must match its captured tick samples")
    tick_set = {sample["tick"] for sample in ticks}
    if any(event["tick"] not in tick_set for event in events):
        raise ToolError("stage2 event tick is not represented by a capture sample")
    required_events = _stage2_expected_events()
    observed_events = [(event["event"], event["phase_id"]) for event in events
                       if event["event"] in {name for name, _phase_id in required_events}]
    if observed_events != required_events:
        raise ToolError("stage2 required stage/gate/phase events are missing, duplicated, or out of order")
    return header, ticks, renders, events, ledgers


def analyze_stage2_capture(header: dict[str, Any], ticks: list[dict[str, Any]], renders: list[dict[str, Any]],
                           events: list[dict[str, Any]], ledgers: list[dict[str, Any]]) -> tuple[dict[str, Any], dict[str, str]]:
    """Produce deterministic v1 summary and 12x16 whole-stage/per-phase SVGs."""
    def phase_analysis(samples: list[dict[str, Any]], title: str) -> tuple[dict[str, Any], str, str]:
        grid = [[0 for _ in range(12)] for _ in range(16)]
        curve: list[dict[str, int]] = []
        for sample in samples:
            curve.append({"tick": sample["tick"], "active_bullets": len(sample["bullets"])})
            for bullet in sample["bullets"]:
                grid[int(bullet["y"] // 60)][int(bullet["x"] // 60)] += 1
        maximum = max(max(row) for row in grid)
        return ({"active_bullet_curve": curve, "peak_active_bullets": max(item["active_bullets"] for item in curve),
                 "heatmap": {"columns": 12, "rows": 16, "cell_width": 60, "cell_height": 60, "occupancy": grid}},
                _heatmap_svg(grid, 60, 60, maximum, "%s occupancy heatmap" % title),
                _stage2_curve_svg(curve, "%s active bullets" % title))

    whole, whole_heatmap, whole_curve = phase_analysis(ticks, "M2 Stage 2 whole stage")
    per_phase: list[dict[str, Any]] = []
    artifacts = {"whole_stage_heatmap.svg": whole_heatmap, "whole_stage_active_bullets.svg": whole_curve}
    for phase_id in STAGE2_PHASE_ORDER:
        result, heatmap, curve = phase_analysis([sample for sample in ticks if sample["phase_id"] == phase_id], phase_id)
        result["phase_id"] = phase_id
        per_phase.append(result)
        artifacts["%s_heatmap.svg" % phase_id] = heatmap
        artifacts["%s_active_bullets.svg" % phase_id] = curve
    frame_times = [frame["frame_time_ms"] for frame in renders]
    warning_order = [{"tick": event["tick"], "event": event["event"], "phase_id": event["phase_id"]}
                     for event in events if event["event"] == "warning"]
    gate_order = [{"tick": event["tick"], "phase_id": event["phase_id"]}
                  for event in events if event["event"] == "phase_gate_open"]
    phase_event_order = [{"tick": event["tick"], "event": event["event"], "phase_id": event["phase_id"]}
                         for event in events if event["event"] in {"phase_started", "phase_cleared"}]
    summary = {"schema_version": STAGE2_CAPTURE_SCHEMA_VERSION, "command": "stage2-analyze",
               "evidence_kind": "real_runtime_capture", "runtime_evidence": True,
               "capture_identity": {key: header[key] for key in ("source", "build_kind", "stage_id", "simulation_hz", "playfield", "difficulty", "run_seed", "execution_mode", "headless")},
               "sample_counts": {"ticks": len(ticks), "render_frames": len(renders)},
               "whole_stage": whole, "per_phase": per_phase,
               "render_frame_time_ms": {"percentile_method": "nearest_rank", "p50": _percentile(frame_times, .50),
                                        "p95": _percentile(frame_times, .95), "p99": _percentile(frame_times, .99)},
               "event_order": {"warnings": warning_order, "gates": gate_order, "phase_events": phase_event_order},
               "time_to_clear_ms": [{"phase_id": ledger["phase_id"], "time_to_clear_ms": ledger["time_to_clear_ms"]} for ledger in ledgers],
               "score_drop_capture_ledgers": ledgers,
               "artifacts": ["summary.json", *sorted(artifacts)]}
    return summary, artifacts


def stage2_analyze(capture_path: Path, output_dir: Path) -> dict[str, Any]:
    header, ticks, renders, events, ledgers = read_stage2_capture(capture_path)
    summary, artifacts = analyze_stage2_capture(header, ticks, renders, events, ledgers)
    try:
        output_dir.mkdir(parents=True, exist_ok=True)
    except OSError as error:
        raise ToolError("could not create stage2 output directory: %s" % error) from error
    _write(output_dir / "summary.json", _json(summary) + "\n")
    for filename in sorted(artifacts):
        _write(output_dir / filename, artifacts[filename])
    return summary


def _write(path: Path, text: str) -> None:
    try:
        path.write_text(text, encoding="utf-8", newline="\n")
    except OSError as error:
        raise ToolError("could not write %s: %s" % (path, error)) from error


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("fingerprints", "sandbox"):
        command = commands.add_parser(name)
        command.add_argument("--cards", required=True, type=Path)
    sandbox_parser = commands.choices["sandbox"]
    sandbox_parser.add_argument("--phase-id", required=True)
    sandbox_parser.add_argument("--difficulty", required=True, type=str.lower)
    sandbox_parser.add_argument("--run-seed", required=True, type=int)
    sandbox_parser.add_argument("--seek-frame", required=True, type=int)
    sandbox_parser.add_argument("--window", type=int, default=180)
    for name in ("trace-seek", "analyze"):
        command = commands.add_parser(name)
        command.add_argument("--cards", required=True, type=Path)
        command.add_argument("--trace", required=True, type=Path)
        command.add_argument("--phase-id")
        command.add_argument("--difficulty", type=str.lower)
    seek_parser = commands.choices["trace-seek"]
    seek_parser.add_argument("--seek-frame", required=True, type=int)
    analyze_parser = commands.choices["analyze"]
    analyze_parser.add_argument("--start-frame", type=int, default=0)
    analyze_parser.add_argument("--end-frame", type=int)
    analyze_parser.add_argument("--columns", type=int, default=12)
    analyze_parser.add_argument("--rows", type=int, default=16)
    analyze_parser.add_argument("--output-json", required=True, type=Path,
                                help="stable JSON telemetry destination")
    analyze_parser.add_argument("--output-svg", required=True, type=Path,
                                help="deterministic 720x960 occupancy heatmap destination")
    stage2_parser = commands.add_parser(
        "stage2-analyze",
        help="fail-closed analyzer for real Main/BulletWorld Release JSONL v1 captures",
        description=("Accepts only the m2_stage2_runtime_capture_header v1 contract: real_runtime_capture, "
                     "main_bullet_world, release, windowed/non-headless, 60 Hz, and 720x960. "
                     "Writes deterministic summary.json plus whole-stage and per-phase 12x16 heatmaps and curves."))
    stage2_parser.add_argument("--capture", required=True, type=Path,
                               help="real-runtime JSONL capture; authored/synthetic inputs are rejected")
    stage2_parser.add_argument("--output-dir", required=True, type=Path,
                               help="directory for deterministic analysis artifacts")
    args = parser.parse_args(argv)
    try:
        if args.command == "stage2-analyze":
            result = stage2_analyze(args.capture, args.output_dir)
        else:
            cards, content_hash = _load_cards(args.cards)
            if args.command == "fingerprints":
                result = fingerprints(cards, content_hash)
            elif args.command == "sandbox":
                result = sandbox(cards, content_hash, args.phase_id, args.difficulty, args.run_seed, args.seek_frame, args.window)
            else:
                header, frames = read_trace(args.trace, cards, content_hash, args.phase_id, args.difficulty)
                if args.command == "trace-seek":
                    result = trace_seek(header, frames, args.seek_frame)
                else:
                    end = len(frames) - 1 if args.end_frame is None else args.end_frame
                    result, svg = analyze(header, frames, args.start_frame, end, args.columns, args.rows)
                    _write(args.output_json, _json(result) + "\n")
                    _write(args.output_svg, svg)
        print(_json(result))
        return 0
    except ToolError as error:
        print("m1_content_tool: %s" % error, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
