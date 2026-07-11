extends Node

# Centralized audio manager (autoload singleton `AudioManager`).
# Handles BGM (looping 3-min music tracks) and pooled SFX playback.

const MIN_VOLUME_DB := -80.0
const PAUSE_BGM_DUCK_DB := -12.0
const SFX_MANIFEST_PATH := "res://audio/production/phase7_sfx_runtime_manifest.json"
const SFX_PRIORITY_ORDER := ["critical", "gameplay", "ambient"]
const SFX_ALIASES := {
	"shoot": "shot_miko_ofuda",
	"bomb": "bomb_miko_start",
	"kill": "enemy_defeat",
	"hit": "player_hit",
	"powerup": "item_collect",
}
const BGM_PATHS := {
	"stage1_mid": "res://audio/bgm/bgm_stage1_mid.ogg",
	"stage1_boss": "res://audio/bgm/bgm_stage1_boss.ogg",
	"stage2_mid": "res://audio/bgm/bgm_stage2_mid.ogg",
	"stage2_boss": "res://audio/bgm/bgm_stage2_boss.ogg",
	"stage3_mid": "res://audio/bgm/bgm_stage3_mid.ogg",
	"stage3_boss": "res://audio/bgm/bgm_stage3_boss.ogg",
	"stage4_mid": "res://audio/bgm/bgm_stage4_mid.ogg",
	"stage4_boss": "res://audio/bgm/bgm_stage4_boss.ogg",
	"stage5_mid": "res://audio/bgm/bgm_stage5_mid.ogg",
	"stage5_boss": "res://audio/bgm/bgm_stage5_boss.ogg",
	"stage6_mid": "res://audio/bgm/bgm_stage6_mid.ogg",
	"stage6_boss": "res://audio/bgm/bgm_stage6_boss.ogg",
}

# Two BGM players are used for seamless crossfade between tracks. Swapping
# `stream` on the SAME player mid-play can cause a single-frame hiccup as
# the audio server tears down the old buffers and preloads the new ones. By
# routing the new stream through the inactive player, the hiccup is hidden
# behind the outgoing track's fade-out. This removes the "stage transition
# stutter" the player noticed.
var bgm_players: Array = [null, null]
var _bgm_active_idx: int = 0
var _bgm_cache: Dictionary = {}
var _sfx_streams: Dictionary = {}
var _sfx_cues: Dictionary = {}
var _sfx_pools: Dictionary = {"critical": [], "gameplay": [], "ambient": []}
var _sfx_last_played_msec: Dictionary = {}
var _bgm_fade_tween: Tween = null
var _bgm_volume_db: float = -3.0
var _sfx_volume_db: float = -3.0
var _master_volume: float = 1.0
var _bgm_volume: float = 0.8
var _sfx_volume: float = 0.8
var _pause_ducked: bool = false

func _ready() -> void:
	for i in range(2):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = MIN_VOLUME_DB  # silent until we use it
		add_child(p)
		bgm_players[i] = p
	# Preload and *prime* every BGM stream: assign it to a muted player, call
	# play() once and stop(). This forces the audio server to decode the
	# initial chunk of each track NOW (during level-load / initial boot) so
	# the first real play() call has zero latency and zero frame hitch later.
	for key in BGM_PATHS.keys():
		var s = load(BGM_PATHS[key])
		_bgm_cache[key] = s
		# Prime the stream to pre-decode (uses bgm_players[1] as scratch).
		bgm_players[1].stream = s
		bgm_players[1].volume_db = MIN_VOLUME_DB
		bgm_players[1].play()
		bgm_players[1].stop()
	bgm_players[1].stream = null
	bgm_players[1].volume_db = MIN_VOLUME_DB
	_load_sfx_manifest()
	apply_settings({
		"master_volume": _master_volume,
		"bgm_volume": _bgm_volume,
		"sfx_volume": _sfx_volume,
	})

func _volume_to_db(volume: float) -> float:
	if volume <= 0.0:
		return MIN_VOLUME_DB
	return linear_to_db(clampf(volume, 0.0, 1.0))

func _settings_volume(settings: Dictionary, id: String, fallback: float) -> float:
	return clampf(float(settings.get(id, fallback)), 0.0, 1.0)

func _effective_bgm_volume_db() -> float:
	if _bgm_volume_db <= MIN_VOLUME_DB:
		return MIN_VOLUME_DB
	if _pause_ducked:
		return maxf(MIN_VOLUME_DB, _bgm_volume_db + PAUSE_BGM_DUCK_DB)
	return _bgm_volume_db

func _sync_active_bgm_volume() -> void:
	if bgm_players.is_empty():
		return
	var idx: int = clampi(_bgm_active_idx, 0, bgm_players.size() - 1)
	var player = bgm_players[idx]
	if player:
		player.volume_db = _effective_bgm_volume_db()

func _silence_inactive_bgm_players() -> void:
	if bgm_players.is_empty():
		return
	var active_idx: int = clampi(_bgm_active_idx, 0, bgm_players.size() - 1)
	for i in range(bgm_players.size()):
		if i == active_idx:
			continue
		var player = bgm_players[i]
		if player:
			player.volume_db = MIN_VOLUME_DB
			if player.playing:
				player.stop()

func _apply_master_volume() -> void:
	var master_bus: int = AudioServer.get_bus_index("Master")
	if master_bus < 0:
		return
	AudioServer.set_bus_mute(master_bus, false)
	AudioServer.set_bus_volume_db(master_bus, _volume_to_db(_master_volume))

func apply_settings(settings: Dictionary) -> void:
	_master_volume = _settings_volume(settings, "master_volume", _master_volume)
	_bgm_volume = _settings_volume(settings, "bgm_volume", _bgm_volume)
	_sfx_volume = _settings_volume(settings, "sfx_volume", _sfx_volume)
	_bgm_volume_db = _volume_to_db(_bgm_volume)
	_sfx_volume_db = _volume_to_db(_sfx_volume)
	_apply_master_volume()
	if _bgm_fade_tween and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()
	_silence_inactive_bgm_players()
	_sync_active_bgm_volume()

func set_pause_ducked(ducked: bool) -> void:
	_pause_ducked = ducked
	if _bgm_fade_tween and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()
	_silence_inactive_bgm_players()
	_sync_active_bgm_volume()

func configured_bgm_volume_db() -> float:
	return _bgm_volume_db

func effective_sfx_volume_db(volume_db: float = 0.0) -> float:
	if _sfx_volume_db <= MIN_VOLUME_DB:
		return MIN_VOLUME_DB
	return maxf(MIN_VOLUME_DB, _sfx_volume_db + volume_db)

func _load_sfx_manifest() -> void:
	var file := FileAccess.open(SFX_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_error("AudioManager: missing SFX manifest: %s" % SFX_MANIFEST_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("AudioManager: invalid SFX manifest")
		return
	var manifest: Dictionary = parsed
	for cue_value in manifest.get("cues", []):
		var cue: Dictionary = cue_value
		var key := String(cue.get("key", ""))
		var path := String(cue.get("path", ""))
		var stream = load(path)
		if key == "" or stream == null:
			push_error("AudioManager: invalid SFX cue %s at %s" % [key, path])
			continue
		if bool(cue.get("loop", false)) and stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_sfx_cues[key] = cue
		_sfx_streams[key] = stream
	var pool_sizes: Dictionary = manifest.get("pool_sizes", {})
	for priority in SFX_PRIORITY_ORDER:
		var slots: Array = []
		for _index in range(int(pool_sizes.get(priority, 0))):
			var player := AudioStreamPlayer.new()
			player.bus = "Master"
			add_child(player)
			slots.append({"player": player, "cue_key": "", "started_msec": -1})
		_sfx_pools[priority] = slots

func _sfx_allowed_priorities(priority: String) -> Array:
	var start := SFX_PRIORITY_ORDER.find(priority)
	if start < 0:
		start = SFX_PRIORITY_ORDER.size() - 1
	return SFX_PRIORITY_ORDER.slice(start)

func _select_sfx_slot(priority: String) -> Dictionary:
	var allowed := _sfx_allowed_priorities(priority)
	for group in allowed:
		for slot in _sfx_pools.get(group, []):
			if not slot.player.playing:
				return slot
	var preemption_order := allowed.duplicate()
	preemption_order.reverse()
	for group in preemption_order:
		var oldest: Dictionary = {}
		for slot in _sfx_pools.get(group, []):
			if oldest.is_empty() or int(slot.started_msec) < int(oldest.started_msec):
				oldest = slot
		if not oldest.is_empty():
			return oldest
	return {}

func play_bgm(key: String) -> void:
	var stream = _bgm_cache.get(key, null)
	if stream == null:
		push_warning("AudioManager: unknown BGM key: %s" % key)
		return
	# If the requested track is already playing on the active player, keep it.
	var cur = bgm_players[_bgm_active_idx]
	if cur.stream == stream and cur.playing:
		return
	# Switch to the other player and crossfade so there is no audible swap
	# glitch and no single-frame hitch from pre-decoding.
	var next_idx = 1 - _bgm_active_idx
	var old = bgm_players[_bgm_active_idx]
	var new_p = bgm_players[next_idx]
	new_p.stream = stream
	new_p.volume_db = MIN_VOLUME_DB
	new_p.play()
	if _bgm_fade_tween and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()
	_bgm_fade_tween = create_tween()
	_bgm_fade_tween.set_parallel(true)
	_bgm_fade_tween.tween_property(new_p, "volume_db", _effective_bgm_volume_db(), 0.4)
	_bgm_fade_tween.tween_property(old, "volume_db", MIN_VOLUME_DB, 0.4)
	_bgm_fade_tween.chain().tween_callback(func(): old.stop())
	_bgm_active_idx = next_idx

func stop_bgm() -> void:
	if _bgm_fade_tween and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()
	for p in bgm_players:
		if p: p.stop()

func fade_bgm(target_db: float, time_sec: float = 0.6) -> void:
	if _bgm_fade_tween and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()
		_silence_inactive_bgm_players()
	var capped_target_db: float = minf(target_db, _effective_bgm_volume_db())
	_bgm_fade_tween = create_tween()
	_bgm_fade_tween.tween_property(bgm_players[_bgm_active_idx], "volume_db", capped_target_db, time_sec)

func play_sfx(name: String, volume_db: float = 0.0) -> bool:
	var resolved_name := String(SFX_ALIASES.get(name, name))
	var stream = _sfx_streams.get(resolved_name, null)
	if stream == null:
		return false
	var cue: Dictionary = _sfx_cues.get(resolved_name, {})
	var now := Time.get_ticks_msec()
	var minimum_interval := int(cue.get("min_interval_ms", 0))
	if now - int(_sfx_last_played_msec.get(resolved_name, -minimum_interval - 1)) < minimum_interval:
		return false
	var slot := _select_sfx_slot(String(cue.get("priority", "ambient")))
	if slot.is_empty():
		return false
	var player = slot.player
	player.stop()
	player.stream = stream
	player.volume_db = effective_sfx_volume_db(volume_db + float(cue.get("runtime_gain_db", 0.0)))
	player.play()
	slot.cue_key = resolved_name
	slot.started_msec = now
	_sfx_last_played_msec[resolved_name] = now
	return true

func stop_sfx(name: String) -> void:
	var resolved_name := String(SFX_ALIASES.get(name, name))
	for priority in SFX_PRIORITY_ORDER:
		for slot in _sfx_pools.get(priority, []):
			if String(slot.cue_key) == resolved_name:
				slot.player.stop()
				slot.cue_key = ""

func bgm_stage_mid(stage: int) -> void:
	play_bgm("stage%d_mid" % stage)

func bgm_stage_boss(stage: int) -> void:
	play_bgm("stage%d_boss" % stage)
