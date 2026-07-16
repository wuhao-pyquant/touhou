extends SceneTree

const MainScript := preload("res://scripts/main.gd")

var failed := false

func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	failed = true
	push_error("M2_STAGE2_SCORE_MAIN_INTEGRATION_FAIL: %s" % message)
	return false

func _equal(actual: Variant, expected: Variant, message: String) -> void:
	_check(actual == expected, "%s Expected %s, got %s" % [message, expected, actual])

func _new_main(seed := 73021) -> Node:
	var main := MainScript.new()
	main.game_manager_ref = load("res://autoload/game_manager.gd").new()
	main.audio_manager_ref = null
	main.game_manager_ref.reset()
	main.set_gameplay_seed(seed)
	main.gameplay_difficulty = "normal"
	main._set_active_stage(2)
	main.bullet_world.configure(4096, 8192, 512)
	main._sync_bullet_world_compatibility_views()
	main._load_stage(2)
	_check(main.stage2_score_route_runtime.is_configured(), "Main did not configure the frozen score-route runtime.")
	return main

func _free_main(main: Node) -> void:
	if main == null:
		return
	var manager: Object = main.game_manager_ref
	main.free()
	if is_instance_valid(manager):
		manager.free()

func _event(main: Node, event_id: String, tick: int) -> void:
	_check(main._stage2_score_stage_event_entry(event_id, tick), "Main rejected authored event %s." % event_id)
	var ids: Array = main.stage_controller.get("stage2_event_ids", [])
	if event_id not in ids:
		ids.append(event_id)
		main.stage_controller["stage2_event_ids"] = ids

func _required_graze(main: Node, source_id: String, uid: String, tick: int, field_sequence: int) -> void:
	_check(main._stage2_score_required_emissions({
		"event_sequence": field_sequence,
		"bullet_constructions": [{
			"stage2_source_spawn_id": source_id,
			"stage2_bullet_uid": uid,
			"stage2_bullet_spawn_tick": tick,
		}],
	}), "Main rejected required field emission %s." % uid)
	_check(main._stage2_score_field_projections({
		"score_route_callbacks": [{
			"bullet_uid": uid,
			"bullet_source_spawn_id": source_id,
			"bullet_spawn_tick": tick,
			"first_reflection_tick": tick,
			"reflection_count_before_graze": 1,
			"stage_tick": tick,
		}],
	}), "Main rejected reflected graze %s." % uid)

func _defeat(main: Node, event_id: String, spawn_id: String, enemy_id: String, tick: int, player_x: float) -> void:
	main.stage_controller["stage2_field_tick"] = tick
	main.player_x = player_x
	_check(main._stage2_score_enemy_defeat({
		"stage2_event_id": event_id,
		"stage2_spawn_id": spawn_id,
		"source_enemy_id": enemy_id,
	}), "Main rejected defeat %s." % spawn_id)

func _assert_route_settlement_and_snapshot() -> void:
	var main := _new_main()
	_event(main, "s2_b01", 0)
	_event(main, "s2_b06", 750)
	_event(main, "s2_b12", 1650)
	main.player_x = 100.0
	_event(main, "s2_b13", 1800)
	_required_graze(main, "s2_b13_blue_booth_master", "main_g1", 1801, 41)
	_defeat(main, "s2_b13", "s2_b13_red_booth_master", "booth_master_red", 1802, 100.0)
	_equal(main.stage2_score_route_runtime.settled_group_count(), 1, "Group 1 did not settle once.")
	_check(is_equal_approx(float(main.game_manager_ref.night_festival_multiplier), 1.25), "Group 1 multiplier was not 1.25.")
	_event(main, "s2_b14", 1950)
	_required_graze(main, "s2_b13_blue_booth_master", "main_g2", 1951, 42)
	_defeat(main, "s2_b13", "s2_b13_blue_booth_master", "booth_master_blue", 1952, 100.0)
	_equal(main.stage2_score_route_runtime.settled_group_count(), 2, "Group 2 did not settle once.")
	_check(is_equal_approx(float(main.game_manager_ref.night_festival_multiplier), 1.50), "Group 2 multiplier was not 1.50.")
	_event(main, "s2_b15", 2100)
	_defeat(main, "s2_b15", "s2_b15_left_mirror", "water_mirror_yokai", 2101, 100.0)
	_event(main, "s2_b16", 2250)
	_defeat(main, "s2_b15", "s2_b15_right_mirror", "water_mirror_yokai", 2251, 360.0)
	_required_graze(main, "s2_b16_abacus_keeper", "main_g3", 2252, 43)
	_defeat(main, "s2_b16", "s2_b16_abacus_keeper", "closing_abacus_keeper", 2253, 360.0)
	_event(main, "s2_b17", 2400)
	_defeat(main, "s2_b13", "s2_b13_yellow_booth_master", "booth_master_yellow", 2401, 600.0)
	main.player_x = 600.0
	_event(main, "s2_b18", 2550)
	_equal(main.stage2_score_route_runtime.route_state(), "complete", "Main route did not complete.")
	_equal(main.stage2_score_route_runtime.settled_group_count(), 3, "Group 3 did not settle once.")
	_check(is_equal_approx(float(main.game_manager_ref.night_festival_multiplier), 1.75), "Group 3 multiplier was not 1.75.")
	_equal(main.game_manager_ref.night_festival_seals, 1, "Group 3 did not award exactly one seal.")
	_event(main, "s2_b18", 2550)
	_equal(main.stage2_score_route_runtime.settlement_records().size(), 3, "Duplicate final callbacks duplicated settlement.")
	_equal(main.game_manager_ref.night_festival_seals, 1, "Duplicate final callbacks duplicated the seal.")

	main.items.clear()
	main._emit_enemy_drops({"x": 360.0, "y": 300.0, "drop_item_ids": ["point_large", "power_small", "price_token_3"]})
	_equal(main.items.size(), 5, "Drop aliases did not expand to four point plus one power item.")
	for index in range(4):
		_equal(String(main.items[index].type), "point", "Point alias did not resolve canonically.")
	_equal(String(main.items[4].type), "power", "Power alias did not resolve canonically.")
	var score_before := int(main.game_manager_ref.score)
	main._collect_item(main.items[0])
	_equal(int(main.game_manager_ref.score) - score_before, 17, "Stage 2 point item did not use the 1.75 multiplier.")

	# The route callbacks above use the exact live payload shapes in isolation;
	# restore the untouched field owner's initial cursor before aggregate QA.
	main.stage_controller["stage2_field_tick"] = -1
	var snapshot: Dictionary = main.capture_simulation_state()
	_equal(int(snapshot.get("version", -1)), 5, "Stage 2 score snapshot version drifted.")
	_check(snapshot.get("stage2_score_runtime") is Dictionary, "Stage 2 snapshot omitted score runtime state.")
	_check(main.validate_simulation_state(snapshot), "Main rejected its score-bearing snapshot.")
	var restored := _new_main()
	_check(restored.restore_simulation_state(snapshot), "Fresh Main rejected score-bearing restore.")
	_equal(restored.simulation_state_hash(), main.simulation_state_hash(), "Score runtime diverged across restore.")
	_equal(restored.game_manager_ref.night_festival_seals, 1, "Restore lost the exact-once seal.")
	_free_main(restored)
	_free_main(main)

func _spell_fixture(outcome: String, invalidation := "") -> void:
	var main := _new_main(74000 + outcome.hash() + invalidation.hash())
	_check(main._activate_stage2_phase_practice("stage_2_boss_spell_1"), "Spell-practice fixture did not activate.")
	_check(bool(main.game_manager_ref.spell_capture_active), "Stage 2 spell did not begin capture.")
	if invalidation == "bomb":
		main._start_bomb()
	elif invalidation == "miss":
		main._respawn()
	var resolution: Dictionary = main.stage2_encounter_controller.resolve_active_phase(outcome)
	_check(bool(resolution.get("ok", false)), "Controller rejected %s spell resolution." % outcome)
	_check(main._consume_stage2_controller_output(resolution), "Main rejected %s spell resolution." % outcome)
	var result: Dictionary = main.game_manager_ref.last_capture_result
	if outcome == "timeout":
		_equal(String(result.get("reason", "")), "timeout", "Timeout did not settle as timeout.")
		_check(not bool(result.get("captured", true)), "Timeout incorrectly captured the spell.")
	elif invalidation != "":
		_equal(String(result.get("reason", "")), invalidation, "%s invalidation reason drifted." % invalidation)
		_check(not bool(result.get("captured", true)), "%s incorrectly captured the spell." % invalidation)
	else:
		_equal(String(result.get("reason", "")), "capture", "Clean clear did not settle as capture.")
		_check(bool(result.get("captured", false)), "Clean clear did not capture the spell.")
	_equal(main.game_manager_ref.run_spell_attempts, 1, "Spell attempt was not exact-once.")
	_free_main(main)

func _run() -> void:
	_assert_route_settlement_and_snapshot()
	_spell_fixture("clear")
	_spell_fixture("timeout")
	_spell_fixture("clear", "miss")
	_spell_fixture("clear", "bomb")
	if failed:
		quit(1)
	else:
		print("PASS: Stage 2 Main score bridge consumes real callback shapes, settles exactly once, restores deterministically, and covers spell outcomes.")
		quit(0)

func _initialize() -> void:
	call_deferred("_run")
