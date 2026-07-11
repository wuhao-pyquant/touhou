extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run() -> void:
	var main_script = load("res://scripts/main.gd")
	var gm_script = load("res://autoload/game_manager.gd")
	if main_script == null or gm_script == null:
		_fail("Could not load Phase 8 performance fixtures.")
		return
	var main_shell = main_script.new()
	var gm = gm_script.new()
	main_shell.game_manager_ref = gm
	main_shell.audio_manager_ref = null
	main_shell.player_x = 360.0
	main_shell.player_y = 850.0
	main_shell.bullet_pool = []
	var active_density := 3000
	for i in range(gm.MAX_BULLETS):
		var bullet: Dictionary = main_shell._make_bullet()
		bullet.active = i < active_density
		bullet.type = "circle"
		bullet.x = 20.0 + float(i % 170) * 4.0
		bullet.y = 110.0 + float((i / 170) % 120) * 4.0
		bullet.radius = 3.0
		main_shell.bullet_pool.append(bullet)
	main_shell._rebuild_active_bullet_indices()
	var frame_count := 30
	var started_usec := Time.get_ticks_usec()
	for _frame in range(frame_count):
		main_shell._update_bullets(1.0 / 60.0, Vector2.ZERO)
		main_shell._check_collisions(false)
	var elapsed_usec := Time.get_ticks_usec() - started_usec
	var average_msec := float(elapsed_usec) / 1000.0 / float(frame_count)
	if average_msec >= 16.67:
		_fail("3000-active/12000-capacity bullet update/collision exceeded the 60 FPS CPU budget: %.3f ms" % average_msec)
		return
	print("PASS: 3000 active bullets in a 12000-capacity pool average %.3f ms (budget 16.67 ms)." % average_msec)
	main_shell.free()
	gm.free()
	call_deferred("_finish")

func _finish() -> void:
	quit(0)

func _initialize() -> void:
	call_deferred("_run")
