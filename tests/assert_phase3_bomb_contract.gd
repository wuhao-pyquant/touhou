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

func _assert_equal(actual, expected, message: String) -> bool:
	if actual != expected:
		_fail("%s Expected %s, got %s" % [message, expected, actual])
		return false
	return true

func _enemy_bullet(x: float, y: float) -> Dictionary:
	return {"active": true, "type": "circle", "x": x, "y": y, "radius": 4.0}

func _specs_have_color(specs: Array, expected: Color) -> bool:
	for spec in specs:
		var spec_color: Color = spec.get("color", Color.TRANSPARENT)
		if spec_color.is_equal_approx(expected):
			return true
	return false

func _verify_bomb_executor() -> void:
	var db = load("res://scripts/data/game_database.gd").new()
	var executor_script = load("res://scripts/player/player_bomb_executor.gd")
	if not _assert(executor_script != null, "Could not load player_bomb_executor.gd"):
		return
	var executor = executor_script.new()
	var origin := Vector2(360, 540)
	var direction := Vector2(0, -1)
	var miko_state: Dictionary = executor.start_state(db.bomb_profile_for_protagonist("miko"), origin, direction)
	var magician_state: Dictionary = executor.start_state(db.bomb_profile_for_protagonist("magician"), origin, direction)
	var sword_state: Dictionary = executor.start_state(db.bomb_profile_for_protagonist("swordswoman"), origin, Vector2(1, -1).normalized())
	_assert_equal(String(miko_state.behavior_id), "boundary_bloom", "Miko bomb behavior mismatch.")
	_assert_equal(String(magician_state.behavior_id), "master_spark", "Magician bomb behavior mismatch.")
	_assert_equal(String(sword_state.behavior_id), "instant_slash", "Swordswoman bomb behavior mismatch.")
	_assert(executor.wave_specs(miko_state, 0).size() > executor.wave_specs(magician_state, 0).size(), "Boundary Bloom should have more radial bullets than Master Spark.")
	_assert(executor.wave_specs(magician_state, 0).size() >= 1, "Master Spark should emit lane bullets.")
	var master_spark_specs: Array = executor.wave_specs(magician_state, 0)
	_assert(_specs_have_color(master_spark_specs, magician_state.color), "Master Spark should include red lane bullets.")
	_assert(_specs_have_color(master_spark_specs, Color.WHITE), "Master Spark should include white lane bullets.")
	_assert(executor.wave_specs(sword_state, 0).size() >= 3, "Instant Slash should emit multi-hit slash bullets.")
	_assert(executor.should_clear_enemy_bullet(miko_state, _enemy_bullet(360, 420), origin), "Boundary Bloom should clear nearby bullets.")
	_assert(executor.should_clear_enemy_bullet(magician_state, _enemy_bullet(360, 260), origin), "Master Spark should clear the forward lane.")
	_assert(not executor.should_clear_enemy_bullet(magician_state, _enemy_bullet(140, 540), origin), "Master Spark should not clear far side bullets.")
	_assert(executor.should_clear_enemy_bullet(sword_state, _enemy_bullet(460, 440), origin), "Instant Slash should clear along slash direction.")
	_assert(not executor.should_clear_enemy_bullet(sword_state, _enemy_bullet(220, 560), origin), "Instant Slash should not clear the whole screen.")

func _active_bomb_bullets(main_shell: Node) -> Array:
	var result: Array = []
	for bullet in main_shell.bullet_pool:
		if bullet.get("active", false) and bullet.get("type", "") == "bomb":
			result.append(bullet)
	return result

func _verify_main_uses_selected_bomb() -> void:
	var gm = load("res://autoload/game_manager.gd").new()
	var main_script = load("res://scripts/main.gd")
	if not _assert(main_script != null, "Could not load main.gd"):
		gm.free()
		return
	var main_shell = main_script.new()
	main_shell.game_manager_ref = gm
	for method in ["_selected_bomb_profile", "_start_bomb"]:
		if not _assert(main_shell.has_method(method), "Main missing method %s" % method):
			main_shell.free()
			gm.free()
			return
	main_shell.bullet_pool = []
	for i in range(128):
		main_shell.bullet_pool.append(main_shell._make_bullet())
	main_shell.player_x = 360.0
	main_shell.player_y = 540.0
	gm.bombs = 3
	gm.selected_protagonist_id = "magician"
	gm.selected_shot_id = "magic_laser"
	main_shell._start_bomb()
	_assert_equal(gm.bombs, 2, "Starting selected bomb should consume one bomb.")
	_assert_equal(String(main_shell.player_bomb_config.behavior_id), "master_spark", "Main should use magician bomb config.")
	main_shell._update_bomb(1.0 / 60.0)
	_assert(_active_bomb_bullets(main_shell).size() > 0, "Updating selected bomb should spawn bomb bullets.")
	main_shell.free()
	gm.free()

func _init() -> void:
	_verify_bomb_executor()
	if failed:
		return
	_verify_main_uses_selected_bomb()
	if failed:
		return
	quit(0)
