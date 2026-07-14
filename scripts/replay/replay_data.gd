extends RefCounted

const FORMAT_VERSION := 2
const ReplayHeader := preload("res://scripts/replay/replay_header.gd")
const ReplayFrameInput := preload("res://scripts/replay/replay_frame_input.gd")

var header: RefCounted = null
var frames: Array[Dictionary] = []
var playback_cursor: int = 0
var last_error: String = ""

func start_recording(replay_header: RefCounted) -> bool:
	if replay_header == null or not replay_header.has_method("is_valid") or not replay_header.is_valid():
		last_error = "invalid replay header"
		return false
	var owned_header = ReplayHeader.from_dict(replay_header.to_dict().duplicate(true))
	if owned_header == null or not owned_header.is_valid():
		last_error = "unsupported replay header"
		return false
	header = owned_header
	frames.clear()
	playback_cursor = 0
	last_error = ""
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

func _validated_document(document: Dictionary, expected: Dictionary = {}) -> Dictionary:
	if int(document.get("format_version", -1)) != FORMAT_VERSION:
		last_error = "unsupported replay document version"
		return {}
	var loaded_header = ReplayHeader.from_dict(document.get("header", {}))
	if loaded_header == null or not loaded_header.is_valid():
		last_error = "invalid or unsupported replay header"
		return {}
	for identity_key in ["build_version", "content_hash", "mode", "starting_stage", "phase_id"]:
		if expected.has(identity_key) and loaded_header.get(identity_key) != expected[identity_key]:
			last_error = "replay %s mismatch" % identity_key
			return {}
	var loaded_frames: Array[Dictionary] = []
	var source_value = document.get("frames", null)
	if not (source_value is Array):
		last_error = "replay frames must be an array"
		return {}
	var source_frames: Array = source_value
	for index in range(source_frames.size()):
		var frame_value = source_frames[index]
		if not (frame_value is Dictionary):
			last_error = "replay frame %d is not a dictionary" % index
			return {}
		var frame: Dictionary = frame_value
		if not ReplayFrameInput.is_valid(frame, index):
			last_error = "invalid replay frame %d" % index
			return {}
		loaded_frames.append(ReplayFrameInput.normalize(index, frame))
	return {"header": loaded_header, "frames": loaded_frames}

func start_playback(document: Dictionary, expected: Dictionary = {}) -> bool:
	var validated := _validated_document(document, expected)
	if validated.is_empty():
		return false
	header = validated.header
	frames = validated.frames
	playback_cursor = 0
	last_error = ""
	return true

func load_dict(document: Dictionary, expected: Dictionary = {}) -> bool:
	return start_playback(document, expected)

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

func capture_runtime_state() -> Dictionary:
	return {
		"version": FORMAT_VERSION,
		"document": to_dict().duplicate(true),
		"playback_cursor": playback_cursor,
	}

func validate_runtime_state(state: Dictionary) -> bool:
	if int(state.get("version", -1)) != FORMAT_VERSION:
		return false
	var cursor = state.get("playback_cursor", null)
	var document = state.get("document", null)
	if typeof(cursor) != TYPE_INT or not (document is Dictionary):
		return false
	var probe := new()
	if not probe.load_dict(document):
		return false
	return int(cursor) >= 0 and int(cursor) <= probe.frames.size()

func restore_runtime_state(state: Dictionary) -> bool:
	if not validate_runtime_state(state):
		return false
	var validated := _validated_document(state.document)
	if validated.is_empty():
		return false
	header = validated.header
	frames = validated.frames
	playback_cursor = int(state.playback_cursor)
	last_error = ""
	return true
