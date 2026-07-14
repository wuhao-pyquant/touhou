extends RefCounted

const VERSION := 1
const INPUT_KEYS := ["move_x", "move_y", "shoot", "focus", "bomb", "pause"]

static func normalize(tick: int, values: Dictionary) -> Dictionary:
	return {
		"tick": maxi(tick, 0),
		"move_x": clampi(int(values.get("move_x", 0)), -1, 1),
		"move_y": clampi(int(values.get("move_y", 0)), -1, 1),
		"shoot": bool(values.get("shoot", false)),
		"focus": bool(values.get("focus", false)),
		"bomb": bool(values.get("bomb", false)),
		"pause": bool(values.get("pause", false)),
	}

static func is_valid(frame: Dictionary, expected_tick: int = -1) -> bool:
	if expected_tick >= 0 and int(frame.get("tick", -1)) != expected_tick:
		return false
	for key in INPUT_KEYS:
		if not frame.has(key):
			return false
	if int(frame.get("move_x", 2)) not in [-1, 0, 1] or int(frame.get("move_y", 2)) not in [-1, 0, 1]:
		return false
	for key in ["shoot", "focus", "bomb", "pause"]:
		if typeof(frame.get(key)) != TYPE_BOOL:
			return false
	return true
