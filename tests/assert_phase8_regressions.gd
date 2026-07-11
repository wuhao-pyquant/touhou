extends SceneTree

var failed := false

func _assert(condition: bool, message: String) -> void:
	if condition or failed:
		return
	failed = true
	push_error(message)
	quit(1)

func _run() -> void:
	var main_script = load("res://scripts/main.gd")
	_assert(main_script != null, "Could not load main.gd.")
	if failed:
		return
	var main_shell = main_script.new()
	_assert(main_shell._desired_window_mode(false, DisplayServer.WINDOW_MODE_MAXIMIZED) == DisplayServer.WINDOW_MODE_MAXIMIZED, "Disabling fullscreen must preserve a maximized window.")
	_assert(main_shell._desired_window_mode(false, DisplayServer.WINDOW_MODE_FULLSCREEN) == DisplayServer.WINDOW_MODE_WINDOWED, "Disabling fullscreen must leave fullscreen mode.")
	_assert(main_shell._desired_window_mode(true, DisplayServer.WINDOW_MODE_MAXIMIZED) == DisplayServer.WINDOW_MODE_FULLSCREEN, "Enabling fullscreen must enter fullscreen mode.")

	main_shell.bullet_pool = [{"active": false, "homing": true, "btype": 2}]
	main_shell._spawn_bullet_enemy(100.0, 80.0, 0.0, 2.0, 5.0, Color.RED, "circle", 120.0)
	var bullet: Dictionary = main_shell.bullet_pool[0]
	_assert(not bool(bullet.homing), "Enemy bullets must clear pooled player homing state.")
	_assert(int(bullet.btype) == -1, "Enemy bullets must clear pooled player bullet type state.")

	var gm_script = load("res://autoload/game_manager.gd")
	var ui_script = load("res://scripts/ui/ui_model.gd")
	var gm = gm_script.new()
	gm.unlock_stage(4)
	_assert(gm.highest_reached_stage == 4, "Reached stages must unlock practice entries.")
	gm.reset()
	_assert(gm.highest_reached_stage == 4, "Run reset must preserve practice unlock progress.")
	var ui = ui_script.new()
	var practice_entries: Array = ui.practice_stage_entries(gm.STAGE_NAMES, gm.highest_reached_stage)
	_assert(practice_entries.size() == 4 and int(practice_entries[3].stage) == 4, "Practice menu must expose every unlocked stage.")

	var db = load("res://scripts/data/game_database.gd").new()
	var shot_executor = load("res://scripts/player/player_shot_executor.gd").new()
	var hit_factors := {
		"ofuda_trace": 0.88, "yin_yang_focus": 0.98, "stardust_spread": 0.75,
		"magic_laser": 0.98, "sword_wave_fan": 0.80, "returning_spirit_blades": 0.90,
	}
	var minimum_dps := INF
	var maximum_dps := 0.0
	for shot_id in hit_factors:
		var profile: Dictionary = db.shot_profile_by_id(shot_id)
		var specs: Array = shot_executor.fire_pattern(profile, 5, true, Vector2(360, 800))
		var salvo_damage := 0.0
		for spec in specs:
			salvo_damage += float(spec.damage)
		var effective_dps: float = salvo_damage * 60.0 / float(profile.fire_interval_frames) * float(hit_factors[shot_id])
		minimum_dps = minf(minimum_dps, effective_dps)
		maximum_dps = maxf(maximum_dps, effective_dps)
	_assert(minimum_dps >= 115.0 and maximum_dps <= 150.0, "Six-shot effective DPS must remain in the 115-150 balance envelope.")
	_assert(maximum_dps / minimum_dps <= 1.25, "No shot type may exceed another by more than 25% effective DPS.")
	for stage in range(1, 7):
		var spell_hp: float = gm.balanced_boss_card_hp(stage, 30.0, "spell")
		var required_dps: float = spell_hp / 30.0
		_assert(is_equal_approx(required_dps, float(gm.BOSS_HP_PER_SECOND[stage - 1])), "Boss HP must follow the stage DPS curve.")
	var bomb_totals := []
	for protagonist_id in ["miko", "magician", "swordswoman"]:
		var bomb: Dictionary = db.bomb_profile_for_protagonist(protagonist_id)
		bomb_totals.append(float(bomb.boss_damage_per_wave) * float(bomb.waves))
	for total in bomb_totals:
		_assert(float(total) >= 220.0 and float(total) <= 300.0, "Bomb guaranteed Boss damage must stay in the 220-300 range.")
	main_shell.boss = {"radius": 28.0, "card_timer": 301.0, "card_shot": 0.0, "move_mode": "sweep"}
	_assert(is_equal_approx(main_shell._boss_collision_radius(), 45.0), "Boss collision radius must cover the visible sprite core generously.")
	_assert(main_shell._boss_timer_seconds() == 6, "Boss countdown must round remaining partial seconds upward.")
	main_shell._update_boss_movement_target()
	var first_target := Vector2(main_shell.boss.target_x, main_shell.boss.target_y)
	main_shell.boss.card_shot = 120.0
	main_shell._update_boss_movement_target()
	var second_target := Vector2(main_shell.boss.target_x, main_shell.boss.target_y)
	_assert(first_target.distance_to(second_target) > 20.0, "Boss movement modes must produce meaningful pattern-coupled displacement.")
	for i in range(main_shell.MAX_COMBAT_EFFECTS + 8):
		main_shell._spawn_combat_effect("enemy_defeat", Vector2(i, i), 14.0, Color.WHITE)
	_assert(main_shell.combat_effects.size() == main_shell.MAX_COMBAT_EFFECTS, "Combat effects must remain strictly capped.")
	main_shell._update_combat_effects(2.0)
	_assert(main_shell.combat_effects.is_empty(), "Expired combat effects must be reclaimed.")
	gm.free()
	main_shell.free()
	if not failed:
		print("PASS: Phase 8 gameplay, balance, HUD, effects, and performance regressions.")
		call_deferred("_finish")

func _finish() -> void:
	quit(0)

func _initialize() -> void:
	call_deferred("_run")
