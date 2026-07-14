extends RefCounted

const VERSION := 1
const TICKS_PER_SECOND := 60
const FIXED_DELTA_SECONDS := 1.0 / float(TICKS_PER_SECOND)
const MAX_FRAME_DELTA_SECONDS := 0.05
const MAX_TICKS_PER_FRAME := 3
const ACCUMULATOR_EPSILON := 0.000000001

var tick_index: int = 0
var accumulator_seconds: float = 0.0
var pending_ticks: int = 0
var dropped_ticks: int = 0

func reset(start_tick: int = 0) -> void:
	tick_index = maxi(start_tick, 0)
	accumulator_seconds = 0.0
	pending_ticks = 0
	dropped_ticks = 0

func push_frame_delta(frame_delta: float) -> int:
	var safe_delta := clampf(frame_delta, 0.0, MAX_FRAME_DELTA_SECONDS)
	accumulator_seconds += safe_delta
	var available := int(floor((accumulator_seconds + ACCUMULATOR_EPSILON) / FIXED_DELTA_SECONDS))
	if available <= 0:
		return 0
	var accepted := mini(available, MAX_TICKS_PER_FRAME)
	pending_ticks += accepted
	accumulator_seconds -= float(available) * FIXED_DELTA_SECONDS
	if accumulator_seconds < 0.0 and accumulator_seconds > -ACCUMULATOR_EPSILON:
		accumulator_seconds = 0.0
	if available > accepted:
		dropped_ticks += available - accepted
	return accepted

func consume_tick() -> bool:
	if pending_ticks <= 0:
		return false
	pending_ticks -= 1
	tick_index += 1
	return true

func clear_accumulator() -> void:
	accumulator_seconds = 0.0
	pending_ticks = 0

func snapshot() -> Dictionary:
	return {
		"version": VERSION,
		"tick_index": tick_index,
		"accumulator_seconds": accumulator_seconds,
		"pending_ticks": pending_ticks,
		"dropped_ticks": dropped_ticks,
	}

func restore(state: Dictionary) -> bool:
	if int(state.get("version", -1)) != VERSION:
		return false
	tick_index = maxi(int(state.get("tick_index", 0)), 0)
	accumulator_seconds = clampf(float(state.get("accumulator_seconds", 0.0)), 0.0, FIXED_DELTA_SECONDS)
	pending_ticks = clampi(int(state.get("pending_ticks", 0)), 0, MAX_TICKS_PER_FRAME)
	dropped_ticks = maxi(int(state.get("dropped_ticks", 0)), 0)
	return true
