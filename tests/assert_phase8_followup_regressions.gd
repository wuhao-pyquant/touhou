extends SceneTree

var failed := false

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

	main_shell._spawn_enemy(120.0, -20.0, 5.0, "ring", "circle", 0.0, 0.0, {"center_x": 120.0, "center_y": 70.0, "radius": 55.0})
	var enemy: Dictionary = main_shell.enemies[0]
	_assert(float(enemy.y) > main_shell.GAMEPLAY_TOP, "Enemies must spawn below the top HUD.")
	_assert(float(enemy.move_data.center_y) - float(enemy.move_data.radius) > main_shell.GAMEPLAY_TOP, "Circular enemy routes must stay below the top HUD.")
	_assert(main_shell._boss_anchor_y() - 64.0 > main_shell.HUD_HEIGHT, "Boss artwork must not overlap the top HUD.")

	main_shell.player_bombing = true
	_assert(main_shell._item_magnetize_requested(true), "Shift collection must remain enabled while a bomb is active.")
	main_shell._spawn_item(200.0, 300.0, "power")
	Input.action_press("focus")
	main_shell._update_items(1.0 / 60.0)
	Input.action_release("focus")
	_assert(bool(main_shell.items[0].get("magnetized", false)), "A floating drop must magnetize when Shift is held during a bomb.")
	_assert(not bool(main_shell.items[0].get("floating", true)), "Magnetized drops must immediately leave the floating phase.")
	for type_id in ["power", "point", "bomb_fragment", "life_fragment", "night_festival_seal", "full_power"]:
		var marker: Dictionary = main_shell._item_effect_marker(type_id)
		_assert(String(marker.get("label", "")) != "?", "Item %s needs an explicit effect marker." % type_id)

	audio.queue_free()
	main_shell.free()
	gm.free()
	if not failed:
		print("PASS: Phase 8 follow-up audio, playfield, bullet pool, collection, and item icon regressions.")
		call_deferred("_finish")

func _finish() -> void:
	quit(0)
