extends SceneTree

var failed := false

class FakeBgmPlayer:
	var volume_db: float = 0.0
	var playing: bool = false
	var stream_paused: bool = false

	func play() -> void:
		playing = true

	func stop() -> void:
		playing = false

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

func _assert_equal(actual, expected, message: String) -> bool:
	if actual != expected:
		_fail("%s Expected %s, got %s" % [message, expected, actual])
		return false
	return true

func _assert_approx(actual: float, expected: float, message: String, tolerance: float = 0.01) -> bool:
	if absf(actual - expected) > tolerance:
		_fail("%s Expected %.3f, got %.3f" % [message, expected, actual])
		return false
	return true

func _volume_db(value: float) -> float:
	if value <= 0.0:
		return -80.0
	return linear_to_db(value)

func _phase2_settings() -> Dictionary:
	return {
		"master_volume": 0.5,
		"bgm_volume": 0.25,
		"sfx_volume": 0.4,
		"fullscreen": true,
		"bullet_brightness": 1.35,
		"always_show_focus_hitbox": true,
		"show_performance_hud": true,
		"show_input_guide": false,
	}

func _free_audio_fixture(audio: Node, players: Array) -> void:
	if audio:
		if audio._bgm_fade_tween and audio._bgm_fade_tween.is_valid():
			audio._bgm_fade_tween.kill()
		audio.bgm_players = []
		audio.free()
	for player in players:
		if player is Node:
			player.free()

func _free_main_fixture(main_shell: Node, gm: Node, audio: Node = null, players: Array = []) -> void:
	if main_shell:
		main_shell.free()
	if gm:
		gm.free()
	_free_audio_fixture(audio, players)

func _verify_audio_manager_contract() -> void:
	var audio_script = load("res://autoload/audio_manager.gd")
	if not _assert(audio_script != null, "Could not load audio_manager.gd"):
		return
	var audio = audio_script.new()
	for method in ["apply_settings", "set_pause_ducked", "effective_sfx_volume_db", "configured_bgm_volume_db"]:
		if not _assert(audio.has_method(method), "AudioManager missing method %s" % method):
			_free_audio_fixture(audio, [])
			return

	var bgm_player := AudioStreamPlayer.new()
	var inactive_bgm_player := AudioStreamPlayer.new()
	var players := [bgm_player, inactive_bgm_player]
	get_root().add_child(bgm_player)
	get_root().add_child(inactive_bgm_player)
	bgm_player.stream = AudioStreamGenerator.new()
	bgm_player.play()
	audio.bgm_players = players
	audio._bgm_active_idx = 0
	audio.apply_settings(_phase2_settings())
	if not _assert_approx(audio.configured_bgm_volume_db(), _volume_db(0.25), "BGM volume setting should configure BGM dB."):
		_free_audio_fixture(audio, players)
		return
	if not _assert_approx(bgm_player.volume_db, _volume_db(0.25), "Applying settings should update the active BGM player."):
		_free_audio_fixture(audio, players)
		return
	if not _assert_approx(audio.effective_sfx_volume_db(-6.0), _volume_db(0.4) - 6.0, "SFX volume should be applied to future play_sfx calls."):
		_free_audio_fixture(audio, players)
		return

	audio.set_pause_ducked(true)
	if not _assert(bgm_player.volume_db < _volume_db(0.25), "Pause ducking should lower active BGM volume."):
		_free_audio_fixture(audio, players)
		return
	if not _assert(bgm_player.stream_paused, "Pausing gameplay should pause the active BGM stream position."):
		_free_audio_fixture(audio, players)
		return
	audio.set_pause_ducked(false)
	if not _assert_approx(bgm_player.volume_db, _volume_db(0.25), "Resuming should restore configured BGM volume."):
		_free_audio_fixture(audio, players)
		return
	if not _assert(not bgm_player.stream_paused, "Resuming gameplay should resume the active BGM stream."):
		_free_audio_fixture(audio, players)
		return
	_free_audio_fixture(audio, players)

func _verify_inactive_bgm_players_are_silenced_on_pause_duck() -> void:
	var audio_script = load("res://autoload/audio_manager.gd")
	if not _assert(audio_script != null, "Could not load audio_manager.gd for BGM fade cancellation check."):
		return
	var audio = audio_script.new()
	var old_bgm_player := FakeBgmPlayer.new()
	var active_bgm_player := FakeBgmPlayer.new()
	var players := [old_bgm_player, active_bgm_player]
	audio.bgm_players = players
	audio._bgm_active_idx = 1
	audio.apply_settings(_phase2_settings())
	old_bgm_player.volume_db = -6.0
	active_bgm_player.volume_db = audio.configured_bgm_volume_db()
	old_bgm_player.play()
	active_bgm_player.play()
	if not _assert(old_bgm_player.playing and active_bgm_player.playing, "BGM fade cancellation fixture should start with both players playing."):
		_free_audio_fixture(audio, players)
		return

	audio.set_pause_ducked(true)
	if not _assert(old_bgm_player.volume_db <= -79.0 or not old_bgm_player.playing, "Pause ducking during a cancelled BGM crossfade should silence the inactive old BGM player."):
		_free_audio_fixture(audio, players)
		return
	_free_audio_fixture(audio, players)

func _verify_fade_bgm_silences_inactive_cancelled_crossfade() -> void:
	var audio_script = load("res://autoload/audio_manager.gd")
	if not _assert(audio_script != null, "Could not load audio_manager.gd for fade_bgm cancellation check."):
		return
	var audio = audio_script.new()
	get_root().add_child(audio)
	var old_bgm_player := FakeBgmPlayer.new()
	var active_bgm_player := FakeBgmPlayer.new()
	var players := [old_bgm_player, active_bgm_player]
	audio.bgm_players = players
	audio._bgm_active_idx = 1
	audio.apply_settings(_phase2_settings())
	old_bgm_player.volume_db = -6.0
	active_bgm_player.volume_db = audio.configured_bgm_volume_db()
	old_bgm_player.play()
	active_bgm_player.play()
	audio._bgm_fade_tween = audio.create_tween()
	audio._bgm_fade_tween.tween_interval(1.0)
	if not _assert(audio._bgm_fade_tween.is_valid(), "fade_bgm cancellation fixture should start with a valid tween."):
		_free_audio_fixture(audio, players)
		return

	audio.fade_bgm(-30.0, 0.1)
	if not _assert(old_bgm_player.volume_db <= -79.0 or not old_bgm_player.playing, "fade_bgm() cancelling a crossfade should silence the inactive old BGM player."):
		_free_audio_fixture(audio, players)
		return
	_free_audio_fixture(audio, players)

func _verify_fade_bgm_respects_effective_bgm_volume_cap() -> void:
	var audio_script = load("res://autoload/audio_manager.gd")
	if not _assert(audio_script != null, "Could not load audio_manager.gd for fade_bgm volume cap check."):
		return
	var cases := [
		{"bgm_volume": 0.0, "target_db": -12.0, "pause_ducked": false},
		{"bgm_volume": 0.01, "target_db": -30.0, "pause_ducked": false},
		{"bgm_volume": 0.25, "target_db": -12.0, "pause_ducked": true},
	]
	for case in cases:
		var audio = audio_script.new()
		get_root().add_child(audio)
		var active_bgm_player := AudioStreamPlayer.new()
		var inactive_bgm_player := AudioStreamPlayer.new()
		var players := [active_bgm_player, inactive_bgm_player]
		audio.bgm_players = players
		audio._bgm_active_idx = 0
		var settings := _phase2_settings()
		settings["bgm_volume"] = case.bgm_volume
		audio.apply_settings(settings)
		audio.set_pause_ducked(case.pause_ducked)
		var effective_cap: float = active_bgm_player.volume_db
		audio.fade_bgm(case.target_db, 0.1)
		if not _assert(audio._bgm_fade_tween.is_valid(), "fade_bgm volume cap check should create a valid tween."):
			_free_audio_fixture(audio, players)
			return
		audio._bgm_fade_tween.custom_step(1.0)
		if not _assert(active_bgm_player.volume_db <= effective_cap + 0.01, "fade_bgm() should not raise active BGM above the configured/effective cap."):
			_free_audio_fixture(audio, players)
			return
		_free_audio_fixture(audio, players)

func _verify_main_settings_contract() -> void:
	var gm_script = load("res://autoload/game_manager.gd")
	var main_script = load("res://scripts/main.gd")
	if not _assert(gm_script != null, "Could not load game_manager.gd"):
		return
	if not _assert(main_script != null, "Could not load main.gd"):
		return
	var gm = gm_script.new()
	var main_shell = main_script.new()
	main_shell.game_manager_ref = gm
	for method in [
		"_apply_runtime_settings",
		"_apply_fullscreen_setting",
		"_bullet_draw_color",
		"_should_show_focus_hitbox",
		"_should_show_performance_hud",
		"_should_show_input_guide",
		"_pause_gameplay",
		"_resume_gameplay",
	]:
		if not _assert(main_shell.has_method(method), "Main scene missing settings side-effect hook %s" % method):
			main_shell.free()
			gm.free()
			return

	gm.settings = _phase2_settings()
	main_shell._apply_runtime_settings()
	if not _assert_equal(main_shell._should_show_focus_hitbox(), true, "Always-show hitbox setting should affect hitbox visibility contract."):
		main_shell.free()
		gm.free()
		return
	if not _assert_equal(main_shell._should_show_performance_hud(), true, "Performance HUD setting should affect draw contract."):
		main_shell.free()
		gm.free()
		return
	if not _assert_equal(main_shell._should_show_input_guide(), false, "Input guide setting should affect hint draw contract."):
		main_shell.free()
		gm.free()
		return

	var dimmed: Color = main_shell._bullet_draw_color(Color(0.4, 0.2, 0.1), 0.5)
	if not _assert_approx(dimmed.a, 0.5, "Bullet brightness helper should preserve requested alpha."):
		main_shell.free()
		gm.free()
		return
	if not _assert(dimmed.r > 0.4 and dimmed.g > 0.2 and dimmed.b > 0.1, "Bullet brightness setting should brighten bullet draw colors."):
		main_shell.free()
		gm.free()
		return

	gm.settings["fullscreen"] = true
	if not _assert_equal(main_shell._apply_fullscreen_setting(true), false, "Fullscreen apply should be headless-safe and report no window change under headless."):
		main_shell.free()
		gm.free()
		return

	var audio_script = load("res://autoload/audio_manager.gd")
	if not _assert(audio_script != null, "Could not load audio_manager.gd for main pause route check."):
		main_shell.free()
		gm.free()
		return
	var audio = audio_script.new()
	var bgm_player := AudioStreamPlayer.new()
	var inactive_bgm_player := AudioStreamPlayer.new()
	var players := [bgm_player, inactive_bgm_player]
	audio.bgm_players = players
	audio._bgm_active_idx = 0
	main_shell.audio_manager_ref = audio
	gm.settings = _phase2_settings()
	main_shell._apply_runtime_settings()
	var configured_bgm_db: float = audio.configured_bgm_volume_db()
	gm.state = gm.STATE_STAGE
	main_shell._pause_gameplay(gm.STATE_STAGE)
	if not _assert_equal(gm.state, gm.STATE_PAUSED, "Main pause route should enter paused state."):
		_free_main_fixture(main_shell, gm, audio, players)
		return
	if not _assert(bgm_player.volume_db < configured_bgm_db, "Main pause route should lower active BGM volume."):
		_free_main_fixture(main_shell, gm, audio, players)
		return
	main_shell._resume_gameplay()
	if not _assert_equal(gm.state, gm.STATE_STAGE, "Main resume route should return to gameplay state."):
		_free_main_fixture(main_shell, gm, audio, players)
		return
	if not _assert_approx(bgm_player.volume_db, configured_bgm_db, "Main resume route should restore configured BGM volume."):
		_free_main_fixture(main_shell, gm, audio, players)
		return
	_free_main_fixture(main_shell, gm, audio, players)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_verify_audio_manager_contract()
	if failed:
		return
	_verify_inactive_bgm_players_are_silenced_on_pause_duck()
	if failed:
		return
	_verify_fade_bgm_silences_inactive_cancelled_crossfade()
	if failed:
		return
	_verify_fade_bgm_respects_effective_bgm_volume_cap()
	if failed:
		return
	_verify_main_settings_contract()
	if failed:
		return
	quit(0)
