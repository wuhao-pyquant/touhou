extends SceneTree

var failed := false

class QuitRequestProbe:
	extends RefCounted
	var requested: bool = false

	func quit(_exit_code: int = 0) -> void:
		requested = true

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
	var behavior_kinds := {}
	for shot_id in ["ofuda_trace", "yin_yang_focus", "stardust_spread", "magic_laser", "sword_wave_fan", "returning_spirit_blades"]:
		var profile: Dictionary = db.shot_profile_by_id(shot_id)
		var specs: Array = shot_executor.fire_pattern(profile, 5, true, Vector2(360, 800))
		_assert(not specs.is_empty(), "%s must emit a focused behavior pattern." % shot_id)
		for spec in specs:
			var kind := String(spec.get("behavior", {}).get("kind", "direct"))
			behavior_kinds[kind] = true
	_assert(behavior_kinds.has("tracking_ofuda") and behavior_kinds.has("distance_damage") and behavior_kinds.has("sustained_laser") and behavior_kinds.has("returning_blade"), "Six-shot profiles must retain distinct runtime behavior families; balance is verified by the M1 collision TTK benchmark.")
	for stage in range(1, 7):
		var spell_hp: float = gm.balanced_boss_card_hp(stage, 30.0, "spell")
		var required_dps: float = spell_hp / 30.0
		_assert(is_equal_approx(required_dps, float(gm.BOSS_HP_PER_SECOND[stage - 1])), "Boss HP must follow the stage DPS curve.")
	var bomb_ratios := []
	for protagonist_id in ["miko", "magician", "swordswoman"]:
		var bomb: Dictionary = db.bomb_profile_for_protagonist(protagonist_id)
		bomb_ratios.append(float(bomb.boss_damage_ratio))
	for ratio in bomb_ratios:
		_assert(float(ratio) >= 0.12 and float(ratio) <= 0.18, "Bomb guaranteed Boss damage must stay in the 12-18 percent range.")
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
	var lifecycle_manager = gm_script.new()
	_assert(lifecycle_manager._database != null and lifecycle_manager._score_system != null, "GameManager must begin with its M0 database and M1 score-system owners.")
	lifecycle_manager.shutdown_runtime()
	lifecycle_manager.shutdown_runtime()
	_assert(lifecycle_manager._database == null and lifecycle_manager._score_system == null, "GameManager shutdown must idempotently release both runtime owners.")
	lifecycle_manager.free()
	var shutdown_shell = main_script.new()
	var owned_manager = shutdown_shell.game_manager_ref
	var owned_registry = shutdown_shell.asset_registry_ref
	shutdown_shell.asset_texture_cache["fixture"] = ImageTexture.new()
	shutdown_shell._stage_background_path_cache[1] = {"far":"fixture"}
	var live_bullet_world = shutdown_shell.bullet_world
	var live_item_reward_system = shutdown_shell.item_reward_system
	var quit_probe := QuitRequestProbe.new()
	shutdown_shell._quit_runtime_safe(quit_probe)
	_assert(quit_probe.requested and not shutdown_shell._runtime_shutdown_complete and shutdown_shell.bullet_world == live_bullet_world and shutdown_shell.item_reward_system == live_item_reward_system, "A submitted quit request must preserve runtime ownership until tree teardown.")
	shutdown_shell.shutdown_runtime()
	shutdown_shell.shutdown_runtime()
	_assert(not is_instance_valid(owned_manager) and not is_instance_valid(owned_registry), "Standalone Main shutdown must release its fallback Node owners.")
	_assert(shutdown_shell.fixed_tick_clock == null and shutdown_shell.bullet_world == null and shutdown_shell.item_reward_system == null, "Main shutdown must release script-owned runtime references.")
	_assert(shutdown_shell.asset_texture_cache.is_empty() and shutdown_shell._stage_background_path_cache.is_empty(), "Main shutdown must clear resource and path caches before deletion.")
	shutdown_shell.free()
	gm.free()
	main_shell.free()
	if not failed:
		print("PASS: Phase 8 gameplay, balance, HUD, effects, and performance regressions.")
		call_deferred("_finish")

func _finish() -> void:
	quit(0)

func _initialize() -> void:
	call_deferred("_run")
