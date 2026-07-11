extends SceneTree

var failed := false

class FakeAudio:
	var calls: Array = []

	func play_sfx(name: String, volume_db: float = 0.0) -> bool:
		calls.append({"name": name, "volume_db": volume_db})
		return true

func _fail(message: String) -> void:
	failed = true
	push_error(message)
	quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition and not failed:
		_fail(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var audio = load("res://autoload/audio_manager.gd").new()
	root.add_child(audio)
	await process_frame
	_assert(audio._bgm_cache.size() == 12, "All BGM sources must load without relying on stale import cache.")
	_assert(not audio._sfx_streams.is_empty(), "SFX sources must load without relying on stale import cache.")
	audio.bgm_stage_mid(1)
	await create_timer(0.5).timeout
	_assert(audio.bgm_players[audio._bgm_active_idx].playing, "Selected stage BGM must actually enter playing state.")
	_assert(audio.bgm_players[audio._bgm_active_idx].volume_db > audio.MIN_VOLUME_DB, "BGM fade-in must leave the player audible.")

	var gm = load("res://autoload/game_manager.gd").new()
	var main_shell = load("res://scripts/main.gd").new()
	main_shell.game_manager_ref = gm
	main_shell.bullet_pool_hard_capacity = 8
	for i in range(4):
		var bullet: Dictionary = main_shell._make_bullet()
		bullet.active = true
		bullet.x = 100.0 + i
		main_shell.bullet_pool.append(bullet)
	main_shell._rebuild_active_bullet_indices()
	var original_positions: Array = main_shell.bullet_pool.map(func(b): return b.x)
	_assert(main_shell._spawn_bullet_enemy(300, 200, 0, 2), "A saturated initial pool must expand for a new boss bullet.")
	_assert(main_shell.bullet_pool.size() == 8, "Bullet pool should grow only up to its configured hard capacity.")
	for i in range(4):
		_assert(main_shell.bullet_pool[i].active and main_shell.bullet_pool[i].x == original_positions[i], "Pool expansion must never overwrite an active bullet.")
	for i in range(5, 8):
		main_shell.bullet_pool[i].active = true
	main_shell._active_index_initialized = false
	_assert(not main_shell._spawn_bullet_enemy(400, 200, 0, 2), "A pool at hard capacity must reject new bullets instead of evicting old ones.")
	main_shell._clear_bullets()
	_assert(main_shell._spawn_bullet_enemy(360.0, main_shell.SCREEN_H - 2.0, 0.0, 0.0, 5.0, Color.RED, "circle", 1.0), "Lifetime regression setup must spawn an enemy bullet.")
	main_shell.bullet_pool[0].age = 2.0
	main_shell._update_bullets(0.0, Vector2.ZERO)
	_assert(bool(main_shell.bullet_pool[0].active), "Enemy bullets must not expire while still visible on screen.")
	main_shell.bullet_pool[0].y = main_shell.SCREEN_H + 61.0
	main_shell._update_bullets(0.0, Vector2.ZERO)
	_assert(not bool(main_shell.bullet_pool[0].active), "Enemy bullets should be reclaimed after leaving the bottom retention boundary.")

	main_shell._spawn_enemy(120.0, -20.0, 5.0, "ring", "circle", 0.0, 0.0, {"center_x": 120.0, "center_y": 70.0, "radius": 55.0})
	var enemy: Dictionary = main_shell.enemies[0]
	_assert(is_equal_approx(float(enemy.y), -20.0), "HUD overlay must not shift authored enemy spawn coordinates.")
	_assert(is_equal_approx(float(enemy.move_data.center_y), 70.0), "HUD overlay must not shift authored enemy routes.")
	_assert(is_equal_approx(main_shell._boss_anchor_y(), 130.0), "HUD overlay must not reserve vertical playfield space from the boss.")
	_assert(main_shell.has_method("_draw_gameplay_hud_background"), "HUD needs a separate underlay so gameplay sprites render above it.")
	_assert(is_equal_approx(main_shell._display_rect().size.y, 1038.0), "Display must add a dedicated 78 px HUD outside the 960 px playfield.")
	main_shell._sync_canvas_origin("stage")
	_assert(is_equal_approx(main_shell.position.y, main_shell.HUD_HEIGHT), "Gameplay canvas must shift below the external HUD without changing playfield coordinates.")
	main_shell._sync_canvas_origin("title")
	_assert(is_zero_approx(main_shell.position.y), "Menu canvas must use the full display origin.")
	_assert(main_shell.has_method("_draw_settings_screen"), "Settings must retain a dedicated themed renderer.")

	main_shell.player_bombing = true
	main_shell.player_y = main_shell.SCREEN_H * 0.5
	_assert(not main_shell._item_magnetize_requested(true), "Shift collection must not trigger below the top fifth of the screen.")
	main_shell.player_y = main_shell.SCREEN_H * gm.ITEM_TOP_RATIO
	_assert(main_shell._item_magnetize_requested(true), "Shift collection must trigger in the top fifth even while a bomb is active.")
	main_shell._spawn_item(200.0, 300.0, "power")
	Input.action_press("focus")
	main_shell._update_items(1.0 / 60.0)
	Input.action_release("focus")
	_assert(bool(main_shell.items[0].get("magnetized", false)), "A floating drop must magnetize when Shift is held during a bomb.")
	_assert(not bool(main_shell.items[0].get("floating", true)), "Magnetized drops must immediately leave the floating phase.")
	for type_id in ["power", "point", "bomb_fragment", "life_fragment", "night_festival_seal", "full_power"]:
		var marker: Dictionary = main_shell._item_effect_marker(type_id)
		_assert(String(marker.get("label", "")) != "?", "Item %s needs an explicit effect marker." % type_id)
	_assert(main_shell.SHOT_SELECTION_ART_BY_ID.size() == 6, "Every selectable shot needs a Phase 6 hand-painted icon mapping.")
	_assert(main_shell.has_method("_draw_character_choice_cards") and main_shell.has_method("_draw_shot_choice_cards"), "Character and shot selection must use illustrated card renderers.")

	gm.bomb_fragments = 0
	gm.life_fragments = 0
	main_shell._settle_realtime_graze_rewards(89)
	_assert(gm.bomb_fragments == 0, "Graze fragments must not settle before their live threshold.")
	main_shell._settle_realtime_graze_rewards(90)
	_assert(gm.bomb_fragments == 1, "Bomb graze fragment must settle immediately at 90 graze.")
	main_shell._settle_realtime_graze_rewards(300)
	_assert(gm.life_fragments == 1, "Life graze fragment must settle immediately at 300 graze.")

	var fake_audio := FakeAudio.new()
	main_shell.audio_manager_ref = fake_audio
	main_shell.boss = {"card_timer": 300.0, "last_countdown_second": -1}
	main_shell._update_boss_countdown_cue()
	_assert(fake_audio.calls.size() == 1 and fake_audio.calls[0].name == "menu_move", "Every timed boss card should use the quiet five-second countdown cue.")
	main_shell._update_boss_countdown_cue()
	_assert(fake_audio.calls.size() == 1, "Boss countdown cue must play only once per second.")

	audio.queue_free()
	main_shell.free()
	gm.free()
	if not failed:
		print("PASS: Phase 8 follow-up audio, playfield, bullet pool, collection, and item icon regressions.")
		call_deferred("_finish")

func _finish() -> void:
	quit(0)
