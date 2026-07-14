extends RefCounted

const VERSION := 2
const GameplayInputBuffer := preload("res://scripts/runtime/gameplay_input_buffer.gd")
const INPUT_KEYS := ["move_x", "move_y", "shoot", "focus", "bomb", "pause"]

static func normalize(tick: int, values: Dictionary) -> Dictionary:
	return GameplayInputBuffer.normalize_tick_frame(tick, values)

static func is_valid(frame: Dictionary, expected_tick: int = -1) -> bool:
	return GameplayInputBuffer.is_valid_tick_frame(frame, expected_tick)
