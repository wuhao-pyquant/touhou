extends Node

# Centralized audio manager (autoload singleton `AudioManager`).
# Handles BGM (looping 3-min music tracks) and pooled SFX playback.

const SFX_POOL_SIZE := 8
const MIN_VOLUME_DB := -80.0
const PAUSE_BGM_DUCK_DB := -12.0
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
var _sfx_pool: Array = []
var _sfx_cursor: int = 0
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
	# Preload SFX streams (one-shot).
	var sfx_paths := {
		"shoot": "res://audio/sfx/sfx_shoot.wav",
		"bomb":  "res://audio/sfx/sfx_bomb.wav",
		"kill":  "res://audio/sfx/sfx_kill.wav",
		"hit":   "res://audio/sfx/sfx_hit.wav",
		"powerup": "res://audio/sfx/sfx_hit.wav",
	}
	for key in sfx_paths.keys():
		_sfx_streams[key] = load(sfx_paths[key])
	for i in range(SFX_POOL_SIZE):
		var pl = AudioStreamPlayer.new()
		pl.bus = "Master"
		add_child(pl)
		_sfx_pool.append(pl)
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

func play_sfx(name: String, volume_db: float = 0.0) -> void:
	var stream = _sfx_streams.get(name, null)
	if stream == null:
		return
	var pl = _sfx_pool[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % SFX_POOL_SIZE
	pl.stream = stream
	pl.volume_db = effective_sfx_volume_db(volume_db)
	pl.stop()
	pl.play()

func bgm_stage_mid(stage: int) -> void:
	play_bgm("stage%d_mid" % stage)

func bgm_stage_boss(stage: int) -> void:
	play_bgm("stage%d_boss" % stage)
