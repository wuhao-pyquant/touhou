extends RefCounted

const FORMAT_VERSION := 1
const ReplayHeader := preload("res://scripts/replay/replay_header.gd")
const ReplayFrameInput := preload("res://scripts/replay/replay_frame_input.gd")

var header: RefCounted = null
var frames: Array[Dictionary] = []
var playback_cursor: int = 0

func start_recording(replay_header: RefCounted) -> bool:
	if replay_header == null or not replay_header.has_method("is_valid") or not replay_header.is_valid():
		return false
	header = replay_header
	frames.clear()
	playback_cursor = 0
	return true

func record_tick(input_values: Dictionary) -> Dictionary:
	if header == null:
		return {}
	var frame := ReplayFrameInput.normalize(frames.size(), input_values)
	frames.append(frame)
	return frame

func to_dict() -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"header": header.to_dict() if header != null else {},
		"frames": frames.duplicate(true),
	}

func load_dict(document: Dictionary) -> bool:
	if int(document.get("format_version", -1)) != FORMAT_VERSION:
		return false
	var loaded_header = ReplayHeader.from_dict(document.get("header", {}))
	if loaded_header == null or not loaded_header.is_valid():
		return false
	var loaded_frames: Array[Dictionary] = []
	var source_frames: Array = document.get("frames", [])
	for index in range(source_frames.size()):
		var frame_value = source_frames[index]
		if not (frame_value is Dictionary):
			return false
		var frame: Dictionary = frame_value
		if not ReplayFrameInput.is_valid(frame, index):
			return false
		loaded_frames.append(ReplayFrameInput.normalize(index, frame))
	header = loaded_header
	frames = loaded_frames
	playback_cursor = 0
	return true

func reset_playback() -> void:
	playback_cursor = 0

func has_next_frame() -> bool:
	return playback_cursor < frames.size()

func next_frame() -> Dictionary:
	if not has_next_frame():
		return {}
	var frame: Dictionary = frames[playback_cursor].duplicate(true)
	playback_cursor += 1
	return frame
