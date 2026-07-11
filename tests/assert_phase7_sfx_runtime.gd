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

func _load_manifest() -> Dictionary:
	var file := FileAccess.open("res://audio/production/phase7_sfx_runtime_manifest.json", FileAccess.READ)
	if not _assert(file != null, "Phase 7 SFX runtime manifest is missing."):
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not _assert(parsed is Dictionary, "Phase 7 SFX runtime manifest is invalid JSON."):
		return {}
	return parsed

func _verify_assets(manifest: Dictionary) -> void:
	var audio_loader = load("res://autoload/audio_manager.gd").new()
	var cues: Array = manifest.get("cues", [])
	_assert(int(manifest.get("cue_count", 0)) == 32, "Phase 7 must expose exactly 32 accepted SFX cues.")
	_assert(cues.size() == 32, "Phase 7 SFX manifest cue array must contain 32 entries.")
	var keys := {}
	var loop_count := 0
	for cue_value in cues:
		var cue: Dictionary = cue_value
		var key := String(cue.get("key", ""))
		var path := String(cue.get("path", ""))
		_assert(key != "" and not keys.has(key), "SFX cue keys must be non-empty and unique: %s" % key)
		keys[key] = true
		_assert(ResourceLoader.exists(path), "SFX resource is missing: %s" % path)
		var stream = audio_loader._load_audio_stream(path)
		_assert(stream is AudioStreamWAV, "SFX resource must import as AudioStreamWAV: %s" % path)
		if stream is AudioStreamWAV:
			_assert(stream.mix_rate == 44100, "SFX sample rate must be 44.1 kHz: %s" % path)
			_assert(stream.stereo, "SFX must be stereo: %s" % path)
		if bool(cue.get("loop", false)):
			loop_count += 1
	_assert(loop_count == 3, "Exactly three bomb sustain cues must loop.")
	audio_loader.free()

func _verify_runtime(manifest: Dictionary) -> void:
	var audio = root.get_node_or_null("AudioManager")
	if not _assert(audio != null, "AudioManager autoload is unavailable."):
		return
	_assert(audio._sfx_cues.size() == 32, "AudioManager must load all 32 accepted cues.")
	var pool_sizes: Dictionary = manifest.get("pool_sizes", {})
	for priority in ["critical", "gameplay", "ambient"]:
		_assert(audio._sfx_pools[priority].size() == int(pool_sizes.get(priority, 0)), "SFX pool size mismatch for %s." % priority)
	_assert(audio._sfx_allowed_priorities("critical") == ["critical", "gameplay", "ambient"], "Critical cues must be able to preempt lower-priority pools.")
	_assert(audio._sfx_allowed_priorities("ambient") == ["ambient"], "Ambient cues must never consume protected pools.")
	_assert(audio.play_sfx("graze"), "First graze cue should play.")
	_assert(not audio.play_sfx("graze"), "Immediate duplicate graze cue should be rate-limited.")
	audio.stop_sfx("graze")
	_assert(audio.play_sfx("bomb_miko_loop"), "Bomb sustain cue should play.")
	var loop_stream = audio._sfx_streams.get("bomb_miko_loop")
	_assert(loop_stream is AudioStreamWAV and loop_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Bomb sustain cue must use forward looping at runtime.")
	audio.stop_sfx("bomb_miko_loop")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := _load_manifest()
	if manifest.is_empty():
		return
	_verify_assets(manifest)
	if failed:
		return
	_verify_runtime(manifest)
	if not failed:
		call_deferred("_finish_success")

func _finish_success() -> void:
	print("PASS: Phase 7 accepted SFX assets and priority runtime are valid.")
	quit(0)
