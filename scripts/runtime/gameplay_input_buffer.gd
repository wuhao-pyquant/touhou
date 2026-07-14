extends RefCounted

const VERSION := 1
const AXIS_SCALE := 32767
const EDGE_ACTIONS := ["bomb", "pause"]

var held_move_x: int = 0
var held_move_y: int = 0
var held_shoot: bool = false
var held_focus: bool = false
var pending_edges: Dictionary = {"bomb": 0, "pause": 0}
var consumed_edges: Dictionary = {"bomb": 0, "pause": 0}
var sampled_frame_count: int = 0
var current_tick_frame: Dictionary = empty_tick_frame(0)

static func quantize_axis(value: Variant) -> int:
	if typeof(value) == TYPE_INT and absi(int(value)) > 1:
		return clampi(int(value), -AXIS_SCALE, AXIS_SCALE)
	var normalized := clampf(float(value), -1.0, 1.0)
	return clampi(int(round(normalized * float(AXIS_SCALE))), -AXIS_SCALE, AXIS_SCALE)

static func axis_float(value: int) -> float:
	return float(clampi(value, -AXIS_SCALE, AXIS_SCALE)) / float(AXIS_SCALE)

static func empty_tick_frame(tick: int) -> Dictionary:
	return {
		"tick": maxi(tick, 0),
		"move_x": 0,
		"move_y": 0,
		"shoot": false,
		"focus": false,
		"bomb": false,
		"pause": false,
	}

static func normalize_tick_frame(tick: int, values: Dictionary) -> Dictionary:
	return {
		"tick": maxi(tick, 0),
		"move_x": quantize_axis(values.get("move_x", 0)),
		"move_y": quantize_axis(values.get("move_y", 0)),
		"shoot": bool(values.get("shoot", false)),
		"focus": bool(values.get("focus", false)),
		"bomb": bool(values.get("bomb_pressed", values.get("bomb", false))),
		"pause": bool(values.get("pause_pressed", values.get("pause", false))),
	}

static func is_valid_tick_frame(frame: Dictionary, expected_tick: int = -1) -> bool:
	if expected_tick >= 0 and int(frame.get("tick", -1)) != expected_tick:
		return false
	for key in ["tick", "move_x", "move_y", "shoot", "focus", "bomb", "pause"]:
		if not frame.has(key):
			return false
	if typeof(frame.tick) not in [TYPE_INT, TYPE_FLOAT] or float(frame.tick) != float(int(frame.tick)) or int(frame.tick) < 0:
		return false
	if typeof(frame.move_x) not in [TYPE_INT, TYPE_FLOAT] or typeof(frame.move_y) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	if float(frame.move_x) != float(int(frame.move_x)) or float(frame.move_y) != float(int(frame.move_y)):
		return false
	if absi(int(frame.move_x)) > AXIS_SCALE or absi(int(frame.move_y)) > AXIS_SCALE:
		return false
	for key in ["shoot", "focus", "bomb", "pause"]:
		if typeof(frame[key]) != TYPE_BOOL:
			return false
	return true

func reset() -> void:
	held_move_x = 0
	held_move_y = 0
	held_shoot = false
	held_focus = false
	pending_edges = {"bomb": 0, "pause": 0}
	consumed_edges = {"bomb": 0, "pause": 0}
	sampled_frame_count = 0
	current_tick_frame = empty_tick_frame(0)

func sample_live_frame() -> Dictionary:
	var sampled := {
		"move_x": Input.get_axis("move_left", "move_right"),
		"move_y": Input.get_axis("move_up", "move_down"),
		"shoot": Input.is_action_pressed("shoot"),
		"focus": Input.is_action_pressed("focus") or Input.is_key_pressed(KEY_SHIFT),
		"bomb_pressed": Input.is_action_just_pressed("bomb"),
		"pause_pressed": Input.is_action_just_pressed("pause"),
	}
	sample_frame(sampled)
	return sampled

func sample_frame(values: Dictionary) -> void:
	held_move_x = quantize_axis(values.get("move_x", held_move_x))
	held_move_y = quantize_axis(values.get("move_y", held_move_y))
	held_shoot = bool(values.get("shoot", held_shoot))
	held_focus = bool(values.get("focus", held_focus))
	for action in EDGE_ACTIONS:
		if bool(values.get("%s_pressed" % action, values.get(action, false))):
			pending_edges[action] = int(pending_edges[action]) + 1
	sampled_frame_count += 1

func consume_tick(tick: int) -> Dictionary:
	var frame := {
		"tick": maxi(tick, 0),
		"move_x": held_move_x,
		"move_y": held_move_y,
		"shoot": held_shoot,
		"focus": held_focus,
		"bomb": false,
		"pause": false,
	}
	for action in EDGE_ACTIONS:
		if int(pending_edges[action]) > 0:
			frame[action] = true
			pending_edges[action] = int(pending_edges[action]) - 1
			consumed_edges[action] = int(consumed_edges[action]) + 1
	current_tick_frame = frame.duplicate(true)
	return frame

func consume_injected_tick(tick: int, replay_frame: Dictionary) -> Dictionary:
	var frame := normalize_tick_frame(tick, replay_frame)
	held_move_x = int(frame.move_x)
	held_move_y = int(frame.move_y)
	held_shoot = bool(frame.shoot)
	held_focus = bool(frame.focus)
	for action in EDGE_ACTIONS:
		if bool(frame[action]):
			consumed_edges[action] = int(consumed_edges[action]) + 1
	current_tick_frame = frame.duplicate(true)
	return frame

func snapshot() -> Dictionary:
	return {
		"version": VERSION,
		"held": {
			"move_x": held_move_x,
			"move_y": held_move_y,
			"shoot": held_shoot,
			"focus": held_focus,
		},
		"pending_edges": pending_edges.duplicate(true),
		"consumed_edges": consumed_edges.duplicate(true),
		"sampled_frame_count": sampled_frame_count,
		"current_tick_frame": current_tick_frame.duplicate(true),
	}

func validate_snapshot(state: Dictionary) -> bool:
	if int(state.get("version", -1)) != VERSION:
		return false
	var held = state.get("held", null)
	var pending = state.get("pending_edges", null)
	var consumed = state.get("consumed_edges", null)
	var current = state.get("current_tick_frame", null)
	if not (held is Dictionary) or not (pending is Dictionary) or not (consumed is Dictionary) or not (current is Dictionary):
		return false
	if typeof(held.get("move_x")) != TYPE_INT or typeof(held.get("move_y")) != TYPE_INT:
		return false
	if absi(int(held.move_x)) > AXIS_SCALE or absi(int(held.move_y)) > AXIS_SCALE:
		return false
	if typeof(held.get("shoot")) != TYPE_BOOL or typeof(held.get("focus")) != TYPE_BOOL:
		return false
	for action in EDGE_ACTIONS:
		if typeof(pending.get(action)) != TYPE_INT or int(pending[action]) < 0:
			return false
		if typeof(consumed.get(action)) != TYPE_INT or int(consumed[action]) < 0:
			return false
	if typeof(state.get("sampled_frame_count")) != TYPE_INT or int(state.sampled_frame_count) < 0:
		return false
	return is_valid_tick_frame(current)

func restore(state: Dictionary) -> bool:
	if not validate_snapshot(state):
		return false
	var held: Dictionary = state.held
	held_move_x = int(held.move_x)
	held_move_y = int(held.move_y)
	held_shoot = bool(held.shoot)
	held_focus = bool(held.focus)
	pending_edges = state.pending_edges.duplicate(true)
	consumed_edges = state.consumed_edges.duplicate(true)
	sampled_frame_count = int(state.sampled_frame_count)
	current_tick_frame = state.current_tick_frame.duplicate(true)
	return true
