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

func _active_player_bullets(main_shell: Node) -> Array:
	var result: Array = []
	for bullet in main_shell.bullet_pool:
		if bullet.get("active", false) and bullet.get("type", "") == "player":
			result.append(bullet)
	return result

func _verify_executor_patterns() -> void:
	var db = load("res://scripts/data/game_database.gd").new()
	var gm = load("res://autoload/game_manager.gd").new()
	var executor_script = load("res://scripts/player/player_shot_executor.gd")
	if not _assert(executor_script != null, "Could not load player_shot_executor.gd"):
		gm.free()
		return
	var executor = executor_script.new()
	var expected := {
		"ofuda_trace": {"type": gm.BulletType.HOMING, "homing": true, "min_count": 3},
		"yin_yang_focus": {"type": gm.BulletType.LINEAR, "homing": false, "min_count": 1},
		"stardust_spread": {"type": gm.BulletType.SPREAD, "homing": false, "min_count": 5},
		"magic_laser": {"type": gm.BulletType.LINEAR, "homing": false, "min_count": 1},
		"sword_wave_fan": {"type": gm.BulletType.SPREAD, "homing": false, "min_count": 5},
		"returning_spirit_blades": {"type": gm.BulletType.HOMING, "homing": true, "min_count": 3},
	}
	for shot_id in expected.keys():
		var shot: Dictionary = db.shot_profile_by_id(shot_id)
		var specs: Array = executor.fire_pattern(shot, 5, false, Vector2(360, 540))
		_assert(specs.size() >= int(expected[shot_id].min_count), "%s should spawn enough bullets at full power" % shot_id)
		_assert_equal(executor.bullet_type_for_shot(shot, gm), int(expected[shot_id].type), "%s bullet type mismatch." % shot_id)
		var saw_homing := false
		var saw_damage := false
		for spec in specs:
			_assert(spec.has("position") and spec.has("velocity") and spec.has("radius") and spec.has("color") and spec.has("damage") and spec.has("homing") and spec.has("btype") and spec.has("lifetime"), "%s spec missing required keys: %s" % [shot_id, spec])
			if bool(spec.homing):
				saw_homing = true
			if float(spec.damage) >= float(shot.base_damage):
				saw_damage = true
		_assert_equal(saw_homing, bool(expected[shot_id].homing), "%s homing contract mismatch." % shot_id)
		_assert(saw_damage, "%s should use profile damage." % shot_id)
	var laser_specs: Array = executor.fire_pattern(db.shot_profile_by_id("magic_laser"), 5, true, Vector2(360, 540))
	var spread_specs: Array = executor.fire_pattern(db.shot_profile_by_id("stardust_spread"), 5, false, Vector2(360, 540))
	_assert(float(laser_specs[0].damage) > float(spread_specs[0].damage), "Magic laser should out-damage stardust spread per bullet.")
	gm.free()

func _verify_main_uses_selected_shot() -> void:
	var gm = load("res://autoload/game_manager.gd").new()
	var main_script = load("res://scripts/main.gd")
	if not _assert(main_script != null, "Could not load main.gd"):
		gm.free()
		return
	var main_shell = main_script.new()
	main_shell.game_manager_ref = gm
	main_shell._resolve_singletons()
	for method in ["_selected_shot_profile", "_spawn_player_bullet_spec", "_shot_executor_fire_pattern"]:
		if not _assert(main_shell.has_method(method), "Main missing method %s" % method):
			main_shell.free()
			gm.free()
			return
	main_shell.bullet_pool = []
	for i in range(96):
		main_shell.bullet_pool.append(main_shell._make_bullet())
	main_shell.player_x = 360.0
	main_shell.player_y = 540.0
	gm.shared_power = 50
	gm.selected_protagonist_id = "magician"
	gm.selected_shot_id = "magic_laser"
	gm.apply_selected_shot()
	main_shell._shoot()
	var laser_bullets := _active_player_bullets(main_shell)
	_assert(laser_bullets.size() > 0, "Main should spawn selected magic_laser bullets.")
	var laser_damage := float(laser_bullets[0].damage)
	for bullet in laser_bullets:
		bullet.active = false
	gm.selected_protagonist_id = "miko"
	gm.selected_shot_id = "ofuda_trace"
	gm.apply_selected_shot()
	main_shell._shoot()
	var ofuda_bullets := _active_player_bullets(main_shell)
	_assert(ofuda_bullets.size() > laser_bullets.size(), "Ofuda tracking shot should spawn wider coverage than magic laser.")
	_assert(float(ofuda_bullets[0].damage) < laser_damage, "Ofuda tracking shot should have lower per-bullet damage than magic laser.")
	main_shell.free()
	gm.free()

func _init() -> void:
	_verify_executor_patterns()
	if failed:
		return
	_verify_main_uses_selected_shot()
	if failed:
		return
	quit(0)
