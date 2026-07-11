extends SceneTree

var failed := false

func _fail(message: String) -> void:
	if failed:
		return
	failed = true
	push_error(message)
	quit(1)

func _assert(condition: bool, message: String) -> bool:
	if not condition:
		_fail(message)
		return false
	return true

func _init() -> void:
	var audio_script = load("res://autoload/audio_manager.gd")
	if not _assert(audio_script != null, "Could not load AudioManager script."):
		return
	var constants: Dictionary = audio_script.get_script_constant_map()
	var paths: Dictionary = constants.get("BGM_PATHS", {})
	var audio_loader = audio_script.new()
	if not _assert(paths.size() == 12, "AudioManager must expose exactly 12 Phase 7 BGM paths."):
		return

	for stage in range(1, 7):
		for phase in ["mid", "boss"]:
			var key := "stage%d_%s" % [stage, phase]
			var expected_path := "res://audio/bgm/bgm_%s.ogg" % key
			if not _assert(String(paths.get(key, "")) == expected_path, "BGM path mismatch for %s." % key):
				return
			if not _assert(ResourceLoader.exists(expected_path), "Missing runtime BGM: %s" % expected_path):
				return
			var stream = audio_loader._load_audio_stream(expected_path)
			if not _assert(stream is AudioStreamOggVorbis, "Runtime BGM must import as Ogg Vorbis: %s" % key):
				return
			if not _assert(stream.loop, "Runtime BGM must loop: %s" % key):
				return
			if not _assert(absf(stream.get_length() - 180.0) <= 0.05, "Runtime BGM must be 180 seconds: %s" % key):
				return

	audio_loader.free()
	quit(0)
