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

func _has_property(object: Object, name: String) -> bool:
	for property in object.get_property_list():
		if String(property.get("name", "")) == name:
			return true
	return false

func _ids(entries: Array) -> Array:
	var result: Array = []
	for entry in entries:
		result.append(String(entry.get("id", "")))
	return result

func _assert_pause_labels_present(entries: Array) -> void:
	for entry in entries:
		if not _assert(entry is Dictionary, "Pause menu entry should be a Dictionary: %s" % [entry]):
			return
		if not _assert(String(entry.get("id", "")) != "", "Pause menu entry id should not be empty: %s" % [entry]):
			return
		if not _assert(String(entry.get("label", "")) != "", "Pause menu entry label should not be empty: %s" % [entry]):
			return

func _active_bullet_count(main_shell) -> int:
	var count := 0
	for bullet in main_shell.bullet_pool:
		if bullet.get("active", false):
			count += 1
	return count

func _verify_game_manager_pause_contract(gm: Object) -> void:
	for property in ["pause_return_state", "settings_return_state"]:
		if not _assert(_has_property(gm, property), "GameManager missing property %s" % property):
			return

	for method in ["enter_pause", "resume_from_pause", "open_settings"]:
		if not _assert(gm.has_method(method), "GameManager missing method %s" % method):
			return

	gm.state = gm.STATE_STAGE
	gm.enter_pause(gm.STATE_STAGE)
	if not _assert_equal(gm.state, gm.STATE_PAUSED, "enter_pause(stage) should move to paused state."):
		return
	if not _assert_equal(gm.pause_return_state, gm.STATE_STAGE, "enter_pause(stage) should remember stage return target."):
		return
	gm.resume_from_pause()
	if not _assert_equal(gm.state, gm.STATE_STAGE, "resume_from_pause() should return to stage."):
		return

	gm.enter_pause(gm.STATE_BOSS)
	if not _assert_equal(gm.pause_return_state, gm.STATE_BOSS, "enter_pause(boss) should remember boss return target."):
		return
	gm.resume_from_pause()
	if not _assert_equal(gm.state, gm.STATE_BOSS, "resume_from_pause() should return to boss."):
		return

	gm.open_settings(gm.STATE_PAUSED)
	if not _assert_equal(gm.state, gm.STATE_SETTINGS, "open_settings(paused) should open settings."):
		return
	if not _assert_equal(gm.settings_return_state, gm.STATE_PAUSED, "open_settings(paused) should return settings cancel to paused."):
		return

func _verify_pause_menu_entries() -> void:
	var ui_model_script = load("res://scripts/ui/ui_model.gd")
	if not _assert(ui_model_script != null, "Could not load ui_model.gd"):
		return
	var ui_model = ui_model_script.new()
	var pause_entries: Array = ui_model.pause_menu_entries()
	if not _assert_equal(_ids(pause_entries), ["continue", "restart_stage", "settings", "return_to_main_menu", "exit_game"], "Pause menu ids mismatch."):
		return
	_assert_pause_labels_present(pause_entries)

func _verify_main_restart_contract(gm: Object) -> void:
	var main_script = load("res://scripts/main.gd")
	if not _assert(main_script != null, "Could not load main.gd"):
		return
	var main_shell = main_script.new()
	main_shell.game_manager_ref = gm
	if not _assert(main_shell.has_method("_restart_current_stage"), "Main missing _restart_current_stage helper."):
		main_shell.free()
		return

	gm.state = gm.STATE_BOSS
	gm.current_stage = 3
	gm.score = 12345
	gm.graze = 67
	gm.shared_power = 12
	gm.bullet_type = gm.BulletType.HOMING
	gm.lives = 2
	gm.bombs = 1
	main_shell.current_stage_local = 3
	main_shell.stage_timer = 999.0
	main_shell.player_x = 120.0
	main_shell.player_y = 220.0
	main_shell.player_invincible = true
	main_shell.player_bombing = true
	main_shell.player_deathbomb_primed = true
	main_shell.enemies = [{"alive": true, "x": 10.0, "y": 20.0}]
	main_shell.items = [{"alive": true, "x": 30.0, "y": 40.0}]
	main_shell.boss = {"x": 300.0, "phase": "active"}
	main_shell.boss_alive = true
	var bullet: Dictionary = main_shell._make_bullet()
	bullet.active = true
	main_shell.bullet_pool = [bullet]

	main_shell._restart_current_stage()
	if not _assert_equal(gm.state, gm.STATE_STAGE, "Restart Stage should resume gameplay in stage state."):
		main_shell.free()
		return
	if not _assert_equal(gm.current_stage, 3, "Restart Stage should keep the current stage number."):
		main_shell.free()
		return
	if not _assert_equal(gm.score, 12345, "Restart Stage should not reset score."):
		main_shell.free()
		return
	if not _assert_equal(gm.graze, 67, "Restart Stage should not reset graze."):
		main_shell.free()
		return
	if not _assert_equal(gm.shared_power, 12, "Restart Stage should not reset shared power."):
		main_shell.free()
		return
	if not _assert_equal(gm.bullet_type, gm.BulletType.HOMING, "Restart Stage should not reset shot/bullet config."):
		main_shell.free()
		return
	if not _assert_equal(gm.lives, 2, "Restart Stage should not reset lives."):
		main_shell.free()
		return
	if not _assert_equal(gm.bombs, 1, "Restart Stage should not reset bombs."):
		main_shell.free()
		return
	if not _assert_equal(main_shell.stage_timer, 0.0, "Restart Stage should reset stage timer."):
		main_shell.free()
		return
	if not _assert_equal(main_shell.enemies.size(), 0, "Restart Stage should clear enemies."):
		main_shell.free()
		return
	if not _assert_equal(main_shell.items.size(), 0, "Restart Stage should clear items."):
		main_shell.free()
		return
	if not _assert_equal(main_shell.boss_alive, false, "Restart Stage should clear boss runtime state."):
		main_shell.free()
		return
	if not _assert_equal(main_shell.boss, {}, "Restart Stage should clear boss data."):
		main_shell.free()
		return
	if not _assert_equal(_active_bullet_count(main_shell), 0, "Restart Stage should clear active bullets."):
		main_shell.free()
		return
	if not _assert(is_equal_approx(main_shell.player_x, float(gm.SCREEN_W) * 0.5), "Restart Stage should reset player x."):
		main_shell.free()
		return
	if not _assert(is_equal_approx(main_shell.player_y, float(gm.SCREEN_H) * 0.5625), "Restart Stage should reset player y."):
		main_shell.free()
		return
	if not _assert_equal(main_shell.player_invincible, false, "Restart Stage should reset player invincibility."):
		main_shell.free()
		return
	if not _assert_equal(main_shell.player_bombing, false, "Restart Stage should reset player bomb state."):
		main_shell.free()
		return
	if not _assert_equal(main_shell.player_deathbomb_primed, false, "Restart Stage should reset deathbomb state."):
		main_shell.free()
		return
	if not _assert(main_shell.stage_controller.has("boss_spawned"), "Restart Stage should reload the stage controller."):
		main_shell.free()
		return
	main_shell.free()

func _init() -> void:
	var gm_script = load("res://autoload/game_manager.gd")
	if not _assert(gm_script != null, "Could not load game_manager.gd"):
		return
	var gm = gm_script.new()

	_verify_game_manager_pause_contract(gm)
	if failed:
		return
	_verify_pause_menu_entries()
	if failed:
		return
	_verify_main_restart_contract(gm)
	if failed:
		return
	gm.free()
	quit(0)
