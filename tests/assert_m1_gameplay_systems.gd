extends SceneTree

var failed := false

func _fail(message: String) -> void:
	if failed: return
	failed = true
	push_error("M1_FAIL: %s" % message)
	quit(1)

func _assert(condition: bool, message: String) -> bool:
	if not condition: _fail(message)
	return condition

func _assert_equal(actual, expected, message: String) -> bool:
	return _assert(actual == expected, "%s Expected %s, got %s" % [message, expected, actual])

func _new_main(seed: int = 1) -> Node:
	var shell = load("res://scripts/main.gd").new()
	shell.game_manager_ref = load("res://autoload/game_manager.gd").new()
	shell.audio_manager_ref = null
	shell.set_gameplay_seed(seed)
	shell.bullet_world.configure(64, 512, 64)
	shell._sync_bullet_world_compatibility_views()
	return shell

func _free_main(shell: Node) -> void:
	var gm = shell.game_manager_ref
	shell.free()
	gm.free()

func _verify_score_and_capture_ledger() -> void:
	var gm = load("res://autoload/game_manager.gd").new()
	for _i in range(12): gm.add_night_festival_seal()
	_assert_equal(gm.night_festival_seals, 12, "Seal count must remain an inventory count.")
	_assert(is_equal_approx(gm.night_festival_multiplier, 2.0), "Seal multiplier must cap at 2.0.")
	_assert(is_equal_approx(gm.highest_night_festival_multiplier, 2.0), "Highest multiplier must retain the reached cap.")
	gm.begin_spell_capture("test-card", 100000, 1200.0)
	gm.record_bomb_used()
	var bomb_result: Dictionary = gm.finish_spell_capture(900.0)
	_assert_equal(String(bomb_result.reason), "bomb", "Bomb must invalidate the active capture.")
	_assert_equal(int(bomb_result.bonus), 0, "Invalid capture must not award a bonus.")
	_assert(is_equal_approx(gm.night_festival_multiplier, 2.0), "Bomb must not reset multiplier.")

	gm.begin_spell_capture("success-card", 100000, 1200.0)
	var capture_result: Dictionary = gm.finish_spell_capture(600.0)
	_assert(bool(capture_result.captured), "Clean spell clear must capture.")
	_assert_equal(int(capture_result.bonus), 100000, "Capture formula must be floor(base * remaining/total * multiplier).")
	_assert_equal(gm.run_spell_captures, 1, "Run capture count mismatch.")

	gm.begin_spell_capture("timeout-card", 100000, 1200.0)
	var timeout_result: Dictionary = gm.finish_spell_capture(0.0, true)
	_assert_equal(String(timeout_result.reason), "timeout", "Timeout must be recorded distinctly.")
	_assert(not bool(timeout_result.captured), "Timeout must never capture.")

	gm.begin_spell_capture("miss-card", 100000, 1200.0)
	gm.record_actual_miss()
	var miss_result: Dictionary = gm.finish_spell_capture(800.0)
	_assert_equal(String(miss_result.reason), "miss", "Actual miss must invalidate capture.")
	_assert(is_equal_approx(gm.night_festival_multiplier, 1.0), "Actual miss must reset multiplier.")
	_assert(is_equal_approx(gm.highest_night_festival_multiplier, 2.0), "Miss must not erase highest reached multiplier.")
	_assert_equal(gm.clear_classification(), "1cc", "Fresh non-practice run must classify as 1CC.")
	gm.record_continue()
	_assert_equal(gm.clear_classification(), "continued", "Continue must disqualify 1CC.")
	gm.practice_mode = true
	_assert_equal(gm.clear_classification(), "practice", "Practice must not classify as 1CC.")
	gm.free()

func _item_signature(items: Array) -> Array:
	var result: Array = []
	for item in items:
		result.append([String(item.type), float(item.x), float(item.y), float(item.vx), float(item.vy), float(item.drift_dir), float(item.sway), float(item.anim)])
	return result

func _verify_authored_drops() -> void:
	var expected := ["life_fragment", "point", "bomb_fragment"]
	var signatures: Array = []
	for seed in [3, 987654]:
		var shell = _new_main(seed)
		shell._spawn_enemy(200.0, 180.0, 1.0, "aimed", "straight", 0.0, 0.0, {}, false, expected)
		_assert_equal(shell.enemies[0].drop_item_ids, expected, "Enemy must store authored drops in stable order.")
		var before_rng: Dictionary = shell.gameplay_rng.snapshot()
		shell._emit_enemy_drops(shell.enemies[0])
		_assert_equal(shell.gameplay_rng.snapshot(), before_rng, "Authored drop emission must not consume gameplay RNG.")
		signatures.append(_item_signature(shell.items))
		_free_main(shell)
	_assert_equal(signatures[0], signatures[1], "Authored item types and initial trajectories must be seed-independent.")
	_assert_equal([signatures[0][0][0], signatures[0][1][0], signatures[0][2][0]], expected, "Authored drops must emit exactly in authored order.")
	var live = _new_main(12)
	live._spawn_enemy(240.0, 220.0, 1.0, "aimed", "straight", 0.0, 0.0, {}, false, expected)
	live._spawn_bullet_player(240.0, 220.0, 0.0, 0.0, 5.0, Color.WHITE, 10.0)
	live._check_collisions(false)
	_assert_equal([String(live.items[0].type), String(live.items[1].type), String(live.items[2].type)], expected, "Live enemy defeat must emit the authored list exactly.")
	_free_main(live)

	var legacy = _new_main(4)
	legacy._spawn_enemy(100.0, 100.0)
	_assert_equal(legacy.enemies[0].drop_item_ids, legacy.LEGACY_ENEMY_DROP_IDS, "Legacy wave call sites must receive the fixed compatibility list.")
	_free_main(legacy)

	var authored_event := {"x":180.0, "y":140.0, "hp":1.0, "drop_item_ids":expected}
	var authored = _new_main(21)
	authored._spawn_stage_wave_event(authored_event)
	var authored_rng_after_spawn: Dictionary = authored.gameplay_rng.snapshot()
	_assert_equal(authored.enemies[0].drop_item_ids, expected, "The real StageDirector wave path must forward authored drop IDs.")
	authored._emit_enemy_drops(authored.enemies[0])
	_assert_equal([String(authored.items[0].type), String(authored.items[1].type), String(authored.items[2].type)], expected, "The real wave path must emit the authored list in stable order.")
	_assert_equal(authored.gameplay_rng.snapshot(), authored_rng_after_spawn, "Authored drop trajectories must not consume gameplay RNG.")
	_free_main(authored)

	var explicit_empty = _new_main(21)
	explicit_empty._spawn_stage_wave_event({"x":180.0, "y":140.0, "hp":1.0, "drop_item_ids":[]})
	_assert_equal(explicit_empty.enemies[0].drop_item_ids, [], "An explicitly authored empty StageDirector drop list must mean no drops.")
	explicit_empty._emit_enemy_drops(explicit_empty.enemies[0])
	_assert(explicit_empty.items.is_empty(), "An explicitly empty authored drop list must emit no items.")
	_free_main(explicit_empty)

	var missing = _new_main(21)
	missing._spawn_stage_wave_event({"x":180.0, "y":140.0, "hp":1.0})
	_assert_equal(missing.enemies[0].drop_item_ids, missing.LEGACY_ENEMY_DROP_IDS, "A missing StageDirector drop field may use only the narrow compatibility fallback.")
	_assert_equal(missing.gameplay_rng.snapshot(), authored_rng_after_spawn, "Authored drop metadata must not alter the enemy-spawn RNG stream.")
	_free_main(missing)

func _verify_graze_and_deathbomb_rules() -> void:
	var shell = _new_main(9)
	var gm = shell.game_manager_ref
	shell.player_x = 300.0; shell.player_y = 500.0
	gm.graze = 89; gm.bomb_fragments = 1; gm.life_fragments = 2
	shell._spawn_bullet_enemy(300.0 + gm.selected_graze_radius() + 5.5, 500.0, 0.0, 0.0, 6.0)
	shell._check_collisions(false)
	_assert_equal(gm.graze, 90, "Graze setup must reach the former resource threshold.")
	_assert_equal(gm.bomb_fragments, 1, "Graze must never grant bomb fragments.")
	_assert_equal(gm.life_fragments, 2, "Graze must never grant life fragments.")

	gm.add_night_festival_seal()
	gm.begin_spell_capture("deathbomb", 1000, 600.0)
	shell._clear_bullets()
	shell.player_invincible = false
	shell._spawn_bullet_enemy(shell.player_x, shell.player_y, 0.0, 0.0, 4.0)
	shell._spawn_bullet_enemy(shell.player_x, shell.player_y, 0.0, 0.0, 4.0)
	shell._check_collisions(false)
	_assert(shell.player_deathbomb_primed and shell.player_just_hit, "Collision must open a deathbomb window without committing a miss.")
	var first_hit_timer: float = shell.player_deathbomb_timer
	_assert(is_equal_approx(first_hit_timer, gm.DEATHBOMB_WINDOW / 60.0), "The first collision must establish the one fixed deathbomb deadline.")
	shell.current_tick_input = {"bomb":false, "move_x":0, "move_y":0, "shoot":false}
	shell._update_player(1.0 / 60.0)
	var advanced_timer: float = shell.player_deathbomb_timer
	shell._spawn_bullet_enemy(shell.player_x, shell.player_y, 0.0, 0.0, 4.0)
	shell._check_collisions(false)
	_assert(is_equal_approx(shell.player_deathbomb_timer, advanced_timer), "Later bullets must not refresh an unresolved deathbomb window.")
	shell.current_tick_input = {"bomb":true, "move_x":0, "move_y":0, "shoot":false}
	shell._update_player(1.0 / 60.0)
	_assert(not shell.player_just_hit, "Deathbomb must rescue the pending miss.")
	_assert_equal(gm.spell_capture_invalid_reason, "bomb", "Deathbomb counts as Bomb for capture.")
	_assert(is_equal_approx(gm.night_festival_multiplier, 1.1), "Deathbomb must not reset multiplier.")

	shell.player_bombing = false; shell.player_invincible = false
	shell.current_tick_input = {"bomb":false, "move_x":0, "move_y":0, "shoot":false}
	shell.player_deathbomb_primed = true; shell.player_just_hit = true; shell.player_deathbomb_timer = 0.0
	shell._update_player(1.0 / 60.0)
	_assert(not shell.player_deathbomb_primed and shell.player_just_hit, "Expired window must leave an actual miss pending.")
	shell._spawn_bullet_enemy(shell.player_x, shell.player_y, 0.0, 0.0, 4.0)
	shell._check_collisions(false)
	_assert(not shell.player_deathbomb_primed and is_equal_approx(shell.player_deathbomb_timer, -1.0 / 60.0), "Later ticks must not reopen an expired unresolved deathbomb window.")
	shell._respawn()
	_assert(is_equal_approx(gm.night_festival_multiplier, 1.0), "Committed actual miss must reset multiplier.")
	_free_main(shell)

func _verify_ledger_snapshot_round_trip() -> void:
	var shell = _new_main(15)
	var gm = shell.game_manager_ref
	gm.add_night_festival_seal()
	gm.begin_spell_capture("snapshot-card", 42000, 900.0)
	var snapshot: Dictionary = shell.capture_simulation_state()
	_assert(snapshot.has("gameplay_ledger"), "Non-default M1 ledger must enter deterministic runtime snapshots.")
	gm.record_actual_miss()
	_assert(shell.restore_simulation_state(snapshot), "M1 ledger snapshot must restore through the aggregate runtime seam.")
	_assert(is_equal_approx(gm.night_festival_multiplier, 1.1), "Snapshot restore must recover active multiplier.")
	_assert(gm.spell_capture_active and String(gm.spell_capture_card_id) == "snapshot-card", "Snapshot restore must recover capture attempt state.")
	var live_hash: String = shell.simulation_state_hash()
	var malformed_ledgers: Array = []
	for mutation in [
		["night_festival_multiplier", 0.9],
		["highest_night_festival_multiplier", 2.1],
		["highest_night_festival_multiplier", 1.0],
		["spell_capture_total_frames", 0.5],
		["run_spell_captures", 2],
		["spell_capture_card_id", ""],
	]:
		var malformed: Dictionary = snapshot.duplicate(true)
		malformed.gameplay_ledger[mutation[0]] = mutation[1]
		malformed_ledgers.append(malformed)
	var malformed_result: Dictionary = snapshot.duplicate(true)
	malformed_result.gameplay_ledger.last_capture_result = {"captured":true}
	malformed_ledgers.append(malformed_result)
	for malformed in malformed_ledgers:
		_assert(not shell.restore_simulation_state(malformed), "Impossible gameplay ledgers must be rejected before aggregate restore.")
		_assert_equal(shell.simulation_state_hash(), live_hash, "Rejected gameplay ledgers must leave live state unchanged.")
	gm.finish_spell_capture(450.0)
	var completed_snapshot: Dictionary = shell.capture_simulation_state()
	_assert(shell.restore_simulation_state(completed_snapshot), "A coherent completed-capture result must pass aggregate validation.")
	var completed_hash: String = shell.simulation_state_hash()
	var impossible_bonus: Dictionary = completed_snapshot.duplicate(true)
	impossible_bonus.gameplay_ledger.last_capture_result.bonus += 1
	_assert(not shell.restore_simulation_state(impossible_bonus), "A capture-result bonus inconsistent with its deterministic shape must be rejected.")
	_assert_equal(shell.simulation_state_hash(), completed_hash, "Rejected capture-result shapes must leave live state unchanged.")
	_free_main(shell)

func _init() -> void:
	_verify_score_and_capture_ledger()
	if failed: return
	_verify_authored_drops()
	if failed: return
	_verify_graze_and_deathbomb_rules()
	if failed: return
	_verify_ledger_snapshot_round_trip()
	if failed: return
	print("PASS: M1 score/capture ledger, deterministic authored drops, graze, Continue, and deathbomb rules.")
	quit(0)
