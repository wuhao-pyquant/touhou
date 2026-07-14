extends RefCounted

const VERSION := 2
const TICKS_PER_SECOND := 60
const FIXED_DELTA_SECONDS := 1.0 / float(TICKS_PER_SECOND)
const MAX_TICKS_PER_FRAME := 3
const ACCUMULATOR_EPSILON := 0.000000001

var tick_index: int = 0
var accumulator_seconds: float = 0.0
var pending_ticks: int = 0
var dropped_ticks: int = 0
var accepted_ticks: int = 0
var total_frame_seconds: float = 0.0
var invalid_frame_delta_count: int = 0
var cancelled_pending_ticks: int = 0
var cancelled_accumulator_seconds: float = 0.0

func reset(start_tick: int = 0) -> void:
	tick_index = maxi(start_tick, 0)
	accumulator_seconds = 0.0
	pending_ticks = 0
	dropped_ticks = 0
	accepted_ticks = tick_index
	total_frame_seconds = 0.0
	invalid_frame_delta_count = 0
	cancelled_pending_ticks = 0
	cancelled_accumulator_seconds = 0.0

func push_frame_delta(frame_delta: float) -> int:
	if is_nan(frame_delta) or is_inf(frame_delta) or frame_delta < 0.0:
		invalid_frame_delta_count += 1
		return 0
	total_frame_seconds += frame_delta
	accumulator_seconds += frame_delta
	var available := int(floor((accumulator_seconds + ACCUMULATOR_EPSILON) / FIXED_DELTA_SECONDS))
	if available <= 0:
		return 0
	var accepted := mini(available, maxi(MAX_TICKS_PER_FRAME - pending_ticks, 0))
	pending_ticks += accepted
	accepted_ticks += accepted
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
	cancelled_pending_ticks += pending_ticks
	cancelled_accumulator_seconds += accumulator_seconds
	accumulator_seconds = 0.0
	pending_ticks = 0

func snapshot() -> Dictionary:
	return {
		"version": VERSION,
		"tick_index": tick_index,
		"accumulator_seconds": accumulator_seconds,
		"pending_ticks": pending_ticks,
		"dropped_ticks": dropped_ticks,
		"accepted_ticks": accepted_ticks,
		"total_frame_seconds": total_frame_seconds,
		"invalid_frame_delta_count": invalid_frame_delta_count,
		"cancelled_pending_ticks": cancelled_pending_ticks,
		"cancelled_accumulator_seconds": cancelled_accumulator_seconds,
	}

func validate_snapshot(state: Dictionary) -> bool:
	if int(state.get("version", -1)) != VERSION:
		return false
	for key in ["tick_index", "pending_ticks", "dropped_ticks", "accepted_ticks", "invalid_frame_delta_count", "cancelled_pending_ticks"]:
		if typeof(state.get(key)) != TYPE_INT or int(state[key]) < 0:
			return false
	for key in ["accumulator_seconds", "total_frame_seconds", "cancelled_accumulator_seconds"]:
		if typeof(state.get(key)) not in [TYPE_FLOAT, TYPE_INT]:
			return false
		var value := float(state[key])
		if is_nan(value) or is_inf(value) or value < 0.0:
			return false
	if float(state.accumulator_seconds) >= FIXED_DELTA_SECONDS + ACCUMULATOR_EPSILON:
		return false
	if int(state.pending_ticks) > MAX_TICKS_PER_FRAME:
		return false
	if int(state.tick_index) + int(state.pending_ticks) + int(state.cancelled_pending_ticks) != int(state.accepted_ticks):
		return false
	return true

func restore(state: Dictionary) -> bool:
	if not validate_snapshot(state):
		return false
	tick_index = int(state.tick_index)
	accumulator_seconds = float(state.accumulator_seconds)
	pending_ticks = int(state.pending_ticks)
	dropped_ticks = int(state.dropped_ticks)
	accepted_ticks = int(state.accepted_ticks)
	total_frame_seconds = float(state.total_frame_seconds)
	invalid_frame_delta_count = int(state.invalid_frame_delta_count)
	cancelled_pending_ticks = int(state.cancelled_pending_ticks)
	cancelled_accumulator_seconds = float(state.cancelled_accumulator_seconds)
	return true
