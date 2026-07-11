extends SceneTree

var failed := false

func _assert(condition: bool, message: String) -> void:
	if condition or failed:
		return
	failed = true
	push_error(message)
	quit(1)

func _new_main() -> Node:
	var main_shell = load("res://scripts/main.gd").new()
	main_shell.game_database_ref = load("res://scripts/data/game_database.gd").new()
	main_shell.game_manager_ref = load("res://autoload/game_manager.gd").new()
	main_shell.bullet_pool = []
	for i in range(32):
		main_shell.bullet_pool.append(main_shell._make_bullet())
	return main_shell

func _spawn_motion(main_shell: Node, motion: Dictionary) -> Dictionary:
	main_shell._spawn_bullet_enemy(360.0, 300.0, 2.0, 0.0, 5.0, Color.RED, "clock_gear", 300.0, motion)
	main_shell._update_bullets(1.0 / 60.0, Vector2.ZERO)
	return main_shell.bullet_pool[0]

func _run() -> void:
	var main_shell := _new_main()
	for family_id in ["arrow", "clock_gear", "storm_arc", "spiral_seed"]:
		_assert(main_shell._is_enemy_bullet_type(family_id), "%s must participate in collision, clearing, and pooling as an enemy bullet." % family_id)

	var curved := _spawn_motion(main_shell, {"kind":"curve", "turn_rate":0.1})
	_assert(float(curved.vy) > 0.0, "Curve motion must rotate an enemy bullet over time.")

	main_shell = _new_main()
	var accelerated := _spawn_motion(main_shell, {"kind":"accelerate", "accel":0.2, "max_speed":4.0})
	_assert(Vector2(float(accelerated.vx), float(accelerated.vy)).length() > 2.1, "Accelerate motion must increase bullet speed.")

	main_shell = _new_main()
	main_shell._spawn_bullet_enemy(360.0, 300.0, 2.0, 0.0, 5.0, Color.RED, "spiral_seed", 300.0, {"kind":"brake_restart", "trigger_age":10.0, "target_speed":3.0, "aim_on_trigger":true})
	main_shell.bullet_pool[0].age = 10.0
	main_shell.player_x = 360.0; main_shell.player_y = 700.0
	main_shell._update_bullets(1.0 / 60.0, Vector2.ZERO)
	_assert(float(main_shell.bullet_pool[0].vy) > 2.9, "Brake-restart bullets must be able to re-aim at the player after a readable delay.")

	main_shell = _new_main()
	main_shell._spawn_bullet_enemy(711.0, 300.0, 3.0, 0.0, 5.0, Color.RED, "clock_gear", 300.0, {"bounce_count":1})
	main_shell._update_bullets(1.0 / 60.0, Vector2.ZERO)
	_assert(float(main_shell.bullet_pool[0].vx) < 0.0, "Bounce motion must reflect at the playfield edge.")
	_assert(int(main_shell.bullet_pool[0].motion.get("bounce_count", -1)) == 0, "Bounce motion must consume its authored bounce count.")

	main_shell = _new_main()
	var bomb_profile: Dictionary = main_shell.game_database_ref.bomb_profile_for_protagonist("magician")
	main_shell.player_bomb_config = main_shell.bomb_executor.start_state(bomb_profile, Vector2(360, 800), Vector2.UP)
	main_shell.player_bomb_timer = 1.0; main_shell.player_bomb_wave_timer = 0.0; main_shell.player_bomb_phase = 0
	main_shell.boss_alive = true
	main_shell.boss = {"hp":1000.0, "max_hp":1000.0, "phase":"active", "declaring":false}
	main_shell._update_bomb(1.0 / 60.0)
	var expected_wave_damage := 1000.0 * float(bomb_profile.boss_damage_ratio) / float(bomb_profile.waves)
	_assert(is_equal_approx(float(main_shell.boss.hp), 1000.0 - expected_wave_damage), "Bomb guaranteed damage must scale from the current Boss card instead of a fixed stage-dependent value.")

	if not failed:
		print("PASS: enemy bullet motion, registration, and proportional bomb balance.")
		quit(0)

func _initialize() -> void:
	call_deferred("_run")
