extends SceneTree

const Runtime := preload("res://scripts/runtime/stage2_score_route_runtime.gd")
const CONTRACT_PATH := "res://content/runtime/m2_stage2_score_route_contract.json"

var failed := false

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("M2_STAGE2_SCORE_ROUTE_RUNTIME_FAIL: %s" % message)

func _equal(actual: Variant, expected: Variant, message: String) -> void:
	_check(actual == expected, "%s Expected %s, got %s." % [message, expected, actual])

func _new_runtime(difficulty: String, uid: String) -> RefCounted:
	var runtime := Runtime.new()
	_check(runtime.load_contract(CONTRACT_PATH, difficulty, uid), "Approved contract did not load: %s" % runtime.last_error())
	return runtime

func _ok(result: Dictionary, message: String) -> void:
	_check(bool(result.get("ok", false)), "%s: %s" % [message, result.get("error", "")])

func _enter_route(runtime: RefCounted, sequence := 0) -> int:
	_ok(runtime.on_stage_event_entry("s2_b01", 0, sequence), "teaching entry failed")
	sequence += 1
	_ok(runtime.on_reflected_bullet_graze("s2_b01", "teach_uid", "s2_b01_abacus_left", 1, 0, 2, 1, 3, sequence), "teaching graze failed")
	sequence += 1
	_ok(runtime.on_stage_event_entry("s2_b06", 750, sequence), "teaching exit failed")
	sequence += 1
	_ok(runtime.on_stage_event_entry("s2_b12", 1794, sequence, {"publication_complete": true, "prices": {"red": 3, "blue": 2, "yellow": 1}}), "publication failed")
	return sequence + 1

func _graze(runtime: RefCounted, group: int, uid: String, tick: int, sequence: int) -> Dictionary:
	var event_id: String = ["", "s2_b13", "s2_b14", "s2_b16"][group]
	var source: String = "s2_b16_abacus_keeper" if group == 3 else "s2_b13_blue_booth_master"
	_ok(runtime.on_required_bullet_emitted(event_id, uid, source, tick, 0, tick, sequence), "required bullet emission failed")
	return runtime.on_reflected_bullet_graze(event_id, uid, source, tick, 0, tick, 1, tick, sequence + 1)

func _settle_first_two(runtime: RefCounted, sequence: int, hard := false) -> int:
	_ok(_graze(runtime, 1, "%s_g1" % runtime.stage_run_uid(), 1801, sequence), "group 1 graze failed"); sequence += 2
	_ok(runtime.on_enemy_defeat("s2_b13", "s2_b13_red_booth_master", "booth_master_red", 100.0, 1802, sequence), "red defeat failed"); sequence += 1
	_ok(_graze(runtime, 2, "%s_g2" % runtime.stage_run_uid(), 1951, sequence), "group 2 graze failed"); sequence += 2
	var blue_x := 360.0 if hard else 100.0
	_ok(runtime.on_enemy_defeat("s2_b14", "s2_b13_blue_booth_master", "booth_master_blue", blue_x, 1952, sequence), "blue defeat failed")
	return sequence + 1

func _complete(runtime: RefCounted, sequence: int, select_left := true, hard := false) -> int:
	sequence = _settle_first_two(runtime, sequence, hard)
	var mirror := "s2_b15_left_mirror" if select_left else "s2_b15_right_mirror"
	var survivor := "s2_b15_right_mirror" if select_left else "s2_b15_left_mirror"
	var mirror_x := 100.0 if select_left else 600.0
	_ok(runtime.on_mirror_choice(mirror, mirror_x, 2100, sequence), "mirror choice failed"); sequence += 1
	_ok(runtime.on_stage_event_entry("s2_b16", 2250, sequence), "abacus activation entry failed"); sequence += 1
	_ok(runtime.on_enemy_defeat("s2_b16", survivor, "water_mirror_yokai", 360.0, 2251, sequence), "surviving mirror defeat failed"); sequence += 1
	_ok(_graze(runtime, 3, "%s_g3" % runtime.stage_run_uid(), 2252, sequence), "group 3 graze failed"); sequence += 2
	_ok(runtime.on_enemy_defeat("s2_b16", "s2_b16_abacus_keeper", "closing_abacus_keeper", 360.0, 2253, sequence), "abacus defeat failed"); sequence += 1
	var yellow_x := 600.0 if select_left else 100.0
	_ok(runtime.on_enemy_defeat("s2_b17", "s2_b13_yellow_booth_master", "booth_master_yellow", yellow_x, 2400, sequence), "yellow defeat failed"); sequence += 1
	_ok(runtime.on_final_lane_crossing("s2_b18", yellow_x, 2550, 2550, sequence), "final crossing failed")
	return sequence + 1

func _run() -> void:
	_assert_configuration_contract_and_aliases()
	_assert_contract_nested_fail_closed()
	_assert_normal_and_hard_success()
	_assert_order_and_topology_failures()
	_assert_tick_local_callback_ordering()
	_assert_graze_deadline_and_final_failures()
	_assert_emission_registry_and_uid_rules()
	_assert_publication_mirror_and_price_deadlines()
	_assert_mirror_recovery_and_gameplay_fallback()
	_assert_teaching_duplicates_and_unstated_actions()
	_assert_target_before_graze_snapshot_round_trips()
	_assert_snapshot_continuation_and_atomic_rejection()
	if failed:
		quit(1)
	else:
		print("PASS: deterministic Stage 2 score-route state, topology, recovery, rewards, aliases, ordering, and snapshots")
		quit(0)

func _assert_configuration_contract_and_aliases() -> void:
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
	var runtime := Runtime.new()
	_check(not runtime.configure(contract, "easy", "run"), "Easy was accepted.")
	_check(not runtime.configure(contract, "normal", ""), "Empty run UID was accepted.")
	var malformed := contract.duplicate(true); malformed["tick_rate"] = 30
	_check(not runtime.configure(malformed, "normal", "run"), "Malformed contract was accepted.")
	_check(runtime.configure(contract, "normal", "aliases"), "Approved contract was rejected.")
	var expected := {
		"point_large": ["canonical_item_batch", "point", 4], "point_small": ["canonical_item_batch", "point", 1],
		"power_large": ["canonical_item_batch", "power", 4], "power_small": ["canonical_item_batch", "power", 1],
	}
	for alias_id in expected:
		var resolved: Dictionary = runtime.resolve_drop_alias(alias_id)
		_equal([resolved.get("behavior"), resolved.get("canonical_item_id"), resolved.get("count")], expected[alias_id], "Resource alias drifted.")
	for alias_id in ["price_token_1", "price_token_2", "price_token_3", "mirror_token_left", "mirror_token_right"]:
		var resolved: Dictionary = runtime.resolve_drop_alias(alias_id)
		_equal(resolved.get("behavior"), "route_token", "Route alias became a resource.")
		_equal(resolved.get("emits_resource_item"), false, "Route alias emits inventory.")
	_check(not bool(runtime.resolve_drop_alias("bomb_fragment").get("ok", true)), "Unknown resource alias was accepted.")
	_equal(Runtime.lane_id_for_x(-100.0), "lane_left", "Left clamp failed.")
	_equal(Runtime.lane_id_for_x(248.0), "lane_center", "Center partition failed.")
	_equal(Runtime.lane_id_for_x(900.0), "lane_right", "Right clamp failed.")

func _assert_contract_nested_fail_closed() -> void:
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
	var mutations: Array = []
	var ordering := contract.duplicate(true); ordering["event_ordering"]["total_order"] = ["event_sequence ascending"] ; mutations.append([ordering, "event ordering"])
	var teaching := contract.duplicate(true); teaching["teaching_sequence"]["post_midboss_effect"]["seal_spawn_count"] = 1; mutations.append([teaching, "teaching isolation"])
	var teaching_type := contract.duplicate(true); teaching_type["teaching_sequence"]["resolved_hooks"][0]["spawn_ids"] = "not-an-array"; mutations.append([teaching_type, "teaching nested type"])
	var teaching_hook := contract.duplicate(true); teaching_hook["teaching_sequence"]["resolved_hooks"][1]["hooks"][1] = "score_route_cross"; mutations.append([teaching_hook, "teaching hook text"])
	var teaching_resolution := contract.duplicate(true); teaching_resolution["teaching_sequence"]["resolved_hooks"][4]["resolution"] = "Keep teaching markers."; mutations.append([teaching_resolution, "teaching resolution text"])
	var teaching_reason := contract.duplicate(true); teaching_reason["teaching_sequence"]["isolation_reason"] = "Teaching can settle."; mutations.append([teaching_reason, "teaching isolation reason"])
	var publication := contract.duplicate(true); publication["published_order"]["arm_no_later_than_tick"] = 1795; mutations.append([publication, "publication deadline"])
	var publication_shape := contract.duplicate(true); publication_shape["published_order"]["entries"][0] = "not-a-dictionary"; mutations.append([publication_shape, "publication nested type"])
	var group_window := contract.duplicate(true); group_window["groups"][2]["window"]["recovery_deadline_tick"] = 2395; mutations.append([group_window, "recovery window"])
	var group_shape := contract.duplicate(true); group_shape["groups"][0]["expected_target"] = []; mutations.append([group_shape, "group nested type"])
	var topology_shape := contract.duplicate(true); topology_shape["stage_front_topology"] = []; mutations.append([topology_shape, "topology nested type"])
	var mirror_output := contract.duplicate(true); mirror_output["stage_front_topology"]["mirror_graph_transform"]["output_by_selected_spawn_id"]["s2_b15_left_mirror"]["directed_edges"][0] = ["lane_left", "lane_center"]; mutations.append([mirror_output, "mirror graph output"])
	var final_output := contract.duplicate(true); final_output["stage_front_topology"]["final_open_lane_algorithm"]["result_by_selected_spawn_id"]["s2_b15_right_mirror"]["final_open_lane_id"] = "lane_right"; mutations.append([final_output, "final graph output"])
	var hard_predicate := contract.duplicate(true); hard_predicate["groups"][1]["difficulty_topology_predicates"]["hard"]["predicate_id"] = "numeric_shortcut"; mutations.append([hard_predicate, "Hard topology predicate"])
	for group_index in range(3):
		var hard_text := contract.duplicate(true)
		hard_text["groups"][group_index]["difficulty_topology_predicates"]["hard"]["non_numeric_topology_test"] = String(hard_text["groups"][group_index]["difficulty_topology_predicates"]["hard"]["non_numeric_topology_test"]) + " Numeric shortcut."
		mutations.append([hard_text, "Hard non-numeric topology text %d" % (group_index + 1)])
	var transition := contract.duplicate(true); transition["state_transitions"][5]["to"] = "complete"; mutations.append([transition, "state transition"])
	var transition_condition := contract.duplicate(true); transition_condition["state_transitions"][6]["condition"] = "any lane crosses"; mutations.append([transition_condition, "state transition condition"])
	var state_meaning := contract.duplicate(true); state_meaning["route_states"][6]["meaning"] = "May settle immediately."; mutations.append([state_meaning, "state meaning"])
	var reason_condition := contract.duplicate(true); reason_condition["invalidation_reasons"][9]["condition"] = "any crossing"; mutations.append([reason_condition, "invalidation condition"])
	var reason_reward := contract.duplicate(true); reason_reward["invalidation_reasons"][6]["reward_behavior"] = "spawn the seal"; mutations.append([reason_reward, "invalidation reward behavior"])
	var invariant_rule := contract.duplicate(true); invariant_rule["invariants"][11]["rule"] = "Hard may use a numeric shortcut."; mutations.append([invariant_rule, "non-bomb invariant rule"])
	var bomb_rule := contract.duplicate(true); bomb_rule["invariants"][16]["rule"] = "Bombs invalidate."; mutations.append([bomb_rule, "bomb/miss invariant"])
	var telemetry_rule := contract.duplicate(true); telemetry_rule["telemetry_fields"]["boss_gate_open_tick"]["required"] = "optional"; mutations.append([telemetry_rule, "telemetry field semantics"])
	var telemetry_extra := contract.duplicate(true); telemetry_extra["telemetry_fields"]["event_sequence"]["global_monotonic"] = true; mutations.append([telemetry_extra, "extra telemetry key"])
	var extra_nested := contract.duplicate(true); extra_nested["groups"][0]["difficulty_topology_predicates"]["hard"]["numeric_threshold"] = 3; mutations.append([extra_nested, "extra nested contract key"])
	for fixture_value in mutations:
		var fixture: Array = fixture_value
		var runtime := Runtime.new()
		_check(not runtime.configure(fixture[0], "normal", "nested_contract"), "Contradictory %s contract was accepted." % fixture[1])
	var configured := Runtime.new()
	_check(configured.configure(contract, "normal", "atomic_contract"), "Atomic contract fixture did not configure.")
	var configured_before: Dictionary = configured.capture_snapshot()
	_check(not configured.configure(mutations[0][0], "normal", "replacement"), "Malformed reconfiguration was accepted.")
	_equal(configured.capture_snapshot(), configured_before, "Malformed contract reconfiguration mutated active state.")

func _assert_normal_and_hard_success() -> void:
	for fixture in [["normal", true], ["normal", false], ["hard", true], ["hard", false]]:
		var runtime := _new_runtime(fixture[0], "%s_%s" % [fixture[0], fixture[1]])
		var sequence := _enter_route(runtime)
		_complete(runtime, sequence, fixture[1], fixture[0] == "hard")
		_equal(runtime.route_state(), "complete", "%s route did not complete." % [fixture])
		_equal(runtime.settled_group_count(), 3, "Successful route settled wrong group count.")
		_equal(runtime.point_value_multiplier(), 1.75, "Additive multiplier progression drifted.")
		var records: Array = runtime.settlement_records()
		_equal(records.size(), 3, "Successful route emitted wrong settlement count.")
		_equal([records[0].seal_spawn_count, records[1].seal_spawn_count, records[2].seal_spawn_count], [0, 0, 1], "Seal settlement is not exactly-once at group 3.")
		_equal(runtime.final_open_lane_id(), "lane_right" if fixture[1] else "lane_left", "Mirror-mapped final lane drifted.")
		var crossing_x := 600.0 if fixture[1] else 100.0
		var duplicate_final: Dictionary = runtime.on_final_lane_crossing("s2_b18", crossing_x, 2550, 2551, 0)
		_equal(duplicate_final.get("ignored"), true, "Duplicate final settlement callback was not ignored.")
		_equal(runtime.settlement_records().size(), 3, "Duplicate final crossing emitted another settlement.")

func _assert_order_and_topology_failures() -> void:
	var wrong_order := _new_runtime("normal", "wrong_order"); var sequence := _enter_route(wrong_order)
	_ok(wrong_order.on_enemy_defeat("s2_b14", "s2_b13_blue_booth_master", "booth_master_blue", 360.0, 1800, sequence), "wrong-order callback rejected structurally")
	_equal(wrong_order.route_state(), "invalidated", "Wrong booth order did not invalidate.")
	_assert_terminal_snapshot(wrong_order, "wrong_booth_order")
	var hard_topology := _new_runtime("hard", "hard_topology"); sequence = _enter_route(hard_topology)
	sequence = _settle_first_two_until_blue(hard_topology, sequence)
	_ok(hard_topology.on_enemy_defeat("s2_b14", "s2_b13_blue_booth_master", "booth_master_blue", 100.0, 1952, sequence), "Hard topology callback failed structurally")
	_equal(hard_topology.route_state(), "invalidated", "Hard directed topology failure did not invalidate.")
	_assert_terminal_snapshot(hard_topology, "topology_predicate_failed")
	var hard_mirror := _new_runtime("hard", "hard_mirror"); sequence = _enter_route(hard_mirror); sequence = _settle_first_two(hard_mirror, sequence, true)
	_ok(hard_mirror.on_mirror_choice("s2_b15_right_mirror", 100.0, 2100, sequence), "Hard mirror topology callback failed structurally")
	_equal(hard_mirror.route_state(), "invalidated", "Unreachable Hard mirror did not invalidate.")
	_assert_terminal_snapshot(hard_mirror, "topology_predicate_failed")

func _assert_tick_local_callback_ordering() -> void:
	var runtime := _new_runtime("normal", "tick_local_order")
	_ok(runtime.on_stage_event_entry("s2_b01", 0, 9), "Initial high sequence failed")
	_ok(runtime.on_enemy_defeat("s2_b01", "s2_b01_abacus_left", "market_abacus_frame", 156.0, 0, 10), "Same-tick higher sequence failed")
	_ok(runtime.on_enemy_defeat("s2_b02", "s2_b02_left_clerk", "abacus_clerk", 180.0, 150, 0), "New-tick sequence reset was rejected")
	var before: Dictionary = runtime.capture_snapshot()
	_check(not bool(runtime.on_enemy_defeat("s2_b02", "s2_b02_center_clerk", "abacus_clerk", 360.0, 150, 0).get("ok", true)), "Same-tick duplicate sequence was accepted.")
	_equal(runtime.capture_snapshot(), before, "Same-tick contradictory callback mutated state.")
	_ok(runtime.on_enemy_defeat("s2_b02", "s2_b02_center_clerk", "abacus_clerk", 360.0, 150, 1), "Same-tick increasing sequence was rejected")

func _settle_first_two_until_blue(runtime: RefCounted, sequence: int) -> int:
	_ok(_graze(runtime, 1, "hard_fail_g1", 1801, sequence), "fixture g1 graze failed"); sequence += 2
	_ok(runtime.on_enemy_defeat("s2_b13", "s2_b13_red_booth_master", "booth_master_red", 100.0, 1802, sequence), "fixture red failed"); sequence += 1
	_ok(_graze(runtime, 2, "hard_fail_g2", 1951, sequence), "fixture g2 graze failed")
	return sequence + 2

func _assert_graze_deadline_and_final_failures() -> void:
	var no_graze := _new_runtime("normal", "no_graze"); var sequence := _enter_route(no_graze)
	_ok(no_graze.on_enemy_defeat("s2_b13", "s2_b13_red_booth_master", "booth_master_red", 100.0, 1802, sequence), "red fixture failed"); sequence += 1
	_ok(no_graze.on_topology_checkpoint("s2_b14", 360.0, 1945, sequence), "deadline checkpoint failed")
	_equal(no_graze.route_state(), "expired", "Missing rebound did not expire.")
	_assert_terminal_snapshot(no_graze, "required_rebound_graze_missing")
	var bad_reflection := _new_runtime("normal", "bad_reflection"); sequence = _enter_route(bad_reflection); var before: Dictionary = bad_reflection.capture_snapshot()
	_check(not bool(bad_reflection.on_reflected_bullet_graze("s2_b13", "bad", "s2_b13_blue_booth_master", 1800, 0, 1801, 0, 1802, sequence).get("ok", true)), "Zero-reflection graze was accepted.")
	_equal(bad_reflection.capture_snapshot(), before, "Malformed graze mutated state.")
	var selection := _new_runtime("normal", "first_emitted"); sequence = _enter_route(selection)
	_ok(selection.on_required_bullet_emitted("s2_b13", "first_uid", "s2_b13_blue_booth_master", 1801, 0, 1801, sequence), "First bullet emission failed"); sequence += 1
	_ok(selection.on_required_bullet_emitted("s2_b13", "second_uid", "s2_b13_blue_booth_master", 1802, 0, 1802, sequence), "Second bullet emission failed structurally"); sequence += 1
	var wrong_uid: Dictionary = selection.on_reflected_bullet_graze("s2_b13", "second_uid", "s2_b13_blue_booth_master", 1802, 0, 1802, 1, 1802, sequence); sequence += 1
	_equal(wrong_uid.get("ignored"), true, "A later emitted bullet incorrectly replaced the frozen first UID.")
	_ok(selection.on_reflected_bullet_graze("s2_b13", "first_uid", "s2_b13_blue_booth_master", 1801, 0, 1802, 1, 1803, sequence), "Frozen first bullet did not qualify.")
	var wrong_lane := _new_runtime("normal", "wrong_lane"); sequence = _enter_route(wrong_lane); sequence = _prepare_pending_final(wrong_lane, sequence)
	_ok(wrong_lane.on_final_lane_crossing("s2_b18", 100.0, 2550, 2550, sequence), "Wrong final lane callback failed structurally")
	_equal(wrong_lane.route_state(), "invalidated", "Wrong final lane did not invalidate.")
	_assert_terminal_snapshot(wrong_lane, "wrong_final_lane_cross")
	var late := _new_runtime("normal", "late_final"); sequence = _enter_route(late); sequence = _prepare_pending_final(late, sequence)
	_ok(late.on_topology_checkpoint("s2_b18", 600.0, 2701, sequence), "Late checkpoint failed")
	_equal(late.route_state(), "expired", "Final lane deadline did not expire.")
	_assert_terminal_snapshot(late, "final_lane_cross_expired")

func _assert_emission_registry_and_uid_rules() -> void:
	var runtime := _new_runtime("normal", "emission_registry")
	_enter_route(runtime)
	_ok(runtime.on_required_bullet_emitted("s2_b13", "uid_z", "s2_b13_blue_booth_master", 1801, 7, 1801, 0), "First same-order emission failed")
	_ok(runtime.on_required_bullet_emitted("s2_b13", "uid_a", "s2_b13_blue_booth_master", 1801, 7, 1801, 1), "Lexically earlier same-order emission failed")
	_ok(runtime.on_required_bullet_emitted("s2_b13", "uid_m", "s2_b13_blue_booth_master", 1801, 8, 1801, 2), "Later emission sequence failed")
	var nonselected: Dictionary = runtime.on_reflected_bullet_graze("s2_b13", "uid_z", "s2_b13_blue_booth_master", 1801, 7, 1801, 1, 1801, 3)
	_equal(nonselected.get("ignored"), true, "UID tertiary sorting did not select uid_a.")
	var before_forged: Dictionary = runtime.capture_snapshot()
	_check(not bool(runtime.on_reflected_bullet_graze("s2_b13", "uid_a", "s2_b13_blue_booth_master", 1801, 8, 1801, 1, 1801, 4).get("ok", true)), "Forged emission sequence was accepted by graze.")
	_equal(runtime.capture_snapshot(), before_forged, "Forged graze metadata mutated registry/order state.")
	_ok(runtime.on_reflected_bullet_graze("s2_b13", "uid_a", "s2_b13_blue_booth_master", 1801, 7, 1801, 1, 1801, 4), "Canonical selected UID graze failed")
	var before_reuse: Dictionary = runtime.capture_snapshot()
	_check(not bool(runtime.on_required_bullet_emitted("s2_b13", "uid_a", "s2_b13_blue_booth_master", 1802, 9, 1802, 0).get("ok", true)), "Contradictory duplicate UID emission was accepted.")
	_equal(runtime.capture_snapshot(), before_reuse, "Duplicate UID rejection mutated state.")
	_ok(runtime.on_enemy_defeat("s2_b13", "s2_b13_red_booth_master", "booth_master_red", 100.0, 1802, 0), "Registry fixture red defeat failed")
	var before_cross_group: Dictionary = runtime.capture_snapshot()
	_check(not bool(runtime.on_required_bullet_emitted("s2_b14", "uid_a", "s2_b13_blue_booth_master", 1950, 0, 1950, 0).get("ok", true)), "Cross-group UID reuse was accepted.")
	_equal(runtime.capture_snapshot(), before_cross_group, "Cross-group UID rejection mutated state.")
	var before_unknown: Dictionary = runtime.capture_snapshot()
	_check(not bool(runtime.on_reflected_bullet_graze("s2_b14", "unregistered", "s2_b13_blue_booth_master", 1950, 0, 1950, 1, 1950, 0).get("ok", true)), "Unregistered graze UID was accepted.")
	_equal(runtime.capture_snapshot(), before_unknown, "Unregistered graze rejection mutated state.")

func _assert_publication_mirror_and_price_deadlines() -> void:
	var publication := _new_runtime("normal", "publication_fail")
	_ok(publication.on_stage_event_entry("s2_b01", 0, 0), "publication fixture teaching entry failed")
	_ok(publication.on_stage_event_entry("s2_b06", 750, 1), "publication fixture teaching exit failed")
	_ok(publication.on_stage_event_entry("s2_b12", 1794, 2, {"publication_complete": true, "prices": {"red": 2, "blue": 3, "yellow": 1}}), "publication mismatch failed structurally")
	_equal(publication.route_state(), "expired", "Publication mismatch did not expire.")
	_assert_terminal_snapshot(publication, "publication_mismatch")
	var mirror := _new_runtime("normal", "mirror_deadline"); var sequence := _enter_route(mirror); sequence = _settle_first_two(mirror, sequence)
	_ok(mirror.on_topology_checkpoint("s2_b16", 360.0, 2245, sequence), "mirror deadline checkpoint failed")
	_equal(mirror.route_state(), "expired", "Mirror deadline did not expire.")
	_assert_terminal_snapshot(mirror, "mirror_choice_expired")
	var recovery := _new_runtime("normal", "recovery_deadline"); sequence = _enter_route(recovery); sequence = _settle_first_two(recovery, sequence)
	_ok(recovery.on_mirror_choice("s2_b15_left_mirror", 100.0, 2100, sequence), "recovery deadline mirror failed"); sequence += 1
	_ok(recovery.on_topology_checkpoint("s2_b17", 360.0, 2395, sequence), "recovery deadline checkpoint failed")
	_equal(recovery.route_state(), "expired", "Recovery deadline did not expire.")
	_assert_terminal_snapshot(recovery, "price_countdown_expired")
	var price := _new_runtime("normal", "price_deadline"); sequence = _enter_route(price); sequence = _settle_first_two(price, sequence)
	_ok(price.on_mirror_choice("s2_b15_left_mirror", 100.0, 2100, sequence), "price deadline mirror failed"); sequence += 1
	_ok(price.on_enemy_defeat("s2_b16", "s2_b15_right_mirror", "water_mirror_yokai", 360.0, 2251, sequence), "price deadline survivor failed"); sequence += 1
	_ok(price.on_enemy_defeat("s2_b16", "s2_b16_abacus_keeper", "closing_abacus_keeper", 360.0, 2252, sequence), "price deadline abacus failed"); sequence += 1
	_ok(_graze(price, 3, "price_deadline_g3", 2253, sequence), "price deadline graze failed"); sequence += 2
	_ok(price.on_topology_checkpoint("s2_b18", 600.0, 2545, sequence), "price deadline checkpoint failed")
	_equal(price.route_state(), "expired", "Yellow/precommit deadline did not expire.")
	_assert_terminal_snapshot(price, "price_countdown_expired")

func _prepare_pending_final(runtime: RefCounted, sequence: int) -> int:
	sequence = _settle_first_two(runtime, sequence)
	_ok(runtime.on_mirror_choice("s2_b15_left_mirror", 100.0, 2100, sequence), "fixture mirror failed"); sequence += 1
	_ok(runtime.on_stage_event_entry("s2_b16", 2250, sequence), "fixture abacus entry failed"); sequence += 1
	_ok(runtime.on_enemy_defeat("s2_b16", "s2_b15_right_mirror", "water_mirror_yokai", 360.0, 2251, sequence), "fixture survivor failed"); sequence += 1
	_ok(_graze(runtime, 3, "%s_pending_g3" % runtime.stage_run_uid(), 2252, sequence), "fixture g3 graze failed"); sequence += 2
	_ok(runtime.on_enemy_defeat("s2_b16", "s2_b16_abacus_keeper", "closing_abacus_keeper", 360.0, 2253, sequence), "fixture abacus failed"); sequence += 1
	_ok(runtime.on_enemy_defeat("s2_b17", "s2_b13_yellow_booth_master", "booth_master_yellow", 600.0, 2400, sequence), "fixture yellow failed")
	_equal(runtime.route_state(), "group_3_pending_final_cross", "Fixture did not precommit.")
	return sequence + 1

func _assert_mirror_recovery_and_gameplay_fallback() -> void:
	var fallback := _new_runtime("normal", "fallback"); var sequence := _enter_route(fallback); sequence = _settle_first_two(fallback, sequence)
	_ok(fallback.on_mirror_choice("s2_b15_left_mirror", 100.0, 2100, sequence), "fallback mirror failed"); sequence += 1
	_ok(fallback.on_stage_event_entry("s2_b16", 2250, sequence), "fallback abacus entry failed"); sequence += 1
	var result: Dictionary = fallback.on_enemy_defeat("s2_b16", "s2_b16_abacus_keeper", "closing_abacus_keeper", 360.0, 2251, sequence)
	_ok(result, "abacus-first fallback callback failed structurally")
	_equal(result.get("gameplay_fallback"), true, "Abacus-first failure was not marked gameplay-only fallback.")
	_equal(fallback.route_state(), "invalidated", "Abacus-first did not invalidate score route.")
	_equal(fallback.settled_group_count(), 2, "Fallback rolled back earned groups.")
	_assert_terminal_snapshot(fallback, "abacus_before_surviving_mirror")
	var ambiguous := _new_runtime("normal", "ambiguous"); sequence = _enter_route(ambiguous); sequence = _settle_first_two(ambiguous, sequence)
	_ok(ambiguous.on_mirror_choice("s2_b15_left_mirror", 100.0, 2100, sequence), "ambiguous first mirror failed"); sequence += 1
	var duplicate_mirror: Dictionary = ambiguous.on_mirror_choice("s2_b15_left_mirror", 100.0, 2101, 0)
	_equal(duplicate_mirror.get("ignored"), true, "Duplicate selected mirror callback was not ignored.")
	_equal(ambiguous.route_state(), "group_3_armed", "Duplicate selected mirror changed route state.")
	_ok(ambiguous.on_mirror_choice("s2_b15_right_mirror", 600.0, 2102, 0), "ambiguous second mirror failed structurally")
	_equal(ambiguous.route_state(), "invalidated", "Contradictory mirror choice did not invalidate.")
	_assert_terminal_snapshot(ambiguous, "mirror_choice_ambiguous")

func _assert_terminal_snapshot(runtime: RefCounted, expected_reason: String) -> void:
	var snapshot: Dictionary = runtime.capture_snapshot()
	_equal(snapshot.get("terminal_reason"), expected_reason, "Terminal reason drifted.")
	_equal((snapshot.get("terminal_cause_record", {}) as Dictionary).get("reason"), expected_reason, "Terminal cause reason drifted.")
	_check(runtime.validate_snapshot(snapshot), "Runtime rejected its %s terminal provenance snapshot." % expected_reason)

func _assert_teaching_duplicates_and_unstated_actions() -> void:
	var teaching := _new_runtime("normal", "teaching_defeats")
	_ok(teaching.on_stage_event_entry("s2_b01", 0, 0), "Teaching defeat fixture entry failed")
	var teaching_rows := [
		["s2_b01", 0, [["s2_b01_abacus_left", "market_abacus_frame"], ["s2_b01_abacus_center", "market_abacus_frame"], ["s2_b01_abacus_right", "market_abacus_frame"]]],
		["s2_b02", 150, [["s2_b02_left_clerk", "abacus_clerk"], ["s2_b02_center_clerk", "abacus_clerk"], ["s2_b02_right_clerk", "abacus_clerk"]]],
		["s2_b03", 300, [["s2_b03_red_ledger", "price_tag_yokai_red"], ["s2_b03_blue_ledger", "price_tag_yokai_blue"]]],
		["s2_b04", 450, [["s2_b04_left_booth_edge", "booth_edge_keeper"], ["s2_b04_right_booth_edge", "booth_edge_keeper"]]],
		["s2_b05", 600, [["s2_b05_left_bead_seller", "bead_seller"], ["s2_b05_right_bead_seller", "bead_seller"]]],
	]
	for row_value in teaching_rows:
		var row: Array = row_value
		var local_sequence := 1 if int(row[1]) == 0 else 0
		for target_value in row[2]:
			var target: Array = target_value
			_ok(teaching.on_enemy_defeat(String(row[0]), String(target[0]), String(target[1]), 360.0, int(row[1]), local_sequence), "Teaching defeat callback was unreachable")
			local_sequence += 1
	var teaching_snapshot: Dictionary = teaching.capture_snapshot()
	_equal(teaching_snapshot.get("teaching_markers", []).size(), 12, "Teaching defeats were not recorded.")
	_equal(teaching.settled_group_count(), 0, "Teaching defeats settled a route group.")
	_equal(teaching.point_value_multiplier(), 1.0, "Teaching defeats changed point multiplier.")
	_equal(teaching.settlement_records(), [], "Teaching defeats emitted rewards.")
	_ok(teaching.on_stage_event_entry("s2_b06", 750, 0), "Teaching defeat fixture exit failed")
	_equal(teaching.capture_snapshot().get("teaching_markers"), [], "Teaching markers survived s2_b06.")
	var runtime := _new_runtime("normal", "isolation"); var sequence := _enter_route(runtime)
	_equal(runtime.settled_group_count(), 0, "Teaching callbacks leaked score progress.")
	_ok(runtime.on_player_bomb("s2_b13", 1800, sequence), "Bomb callback failed"); sequence += 1
	_ok(runtime.on_player_miss("s2_b13", 1800, sequence), "Miss callback failed"); sequence += 1
	_equal(runtime.route_state(), "group_1_armed", "Bomb or miss invalidated the route.")
	var original_emission_sequence := sequence
	var graze: Dictionary = _graze(runtime, 1, "unique_g1", 1801, sequence); _ok(graze, "unique graze failed"); sequence += 2
	var duplicate_emission: Dictionary = runtime.on_required_bullet_emitted("s2_b13", "unique_g1", "s2_b13_blue_booth_master", 1801, 0, 1801, original_emission_sequence)
	_equal(duplicate_emission.get("ignored"), true, "Exact duplicate emission was not idempotently ignored.")
	var duplicate: Dictionary = runtime.on_reflected_bullet_graze("s2_b13", "unique_g1", "s2_b13_blue_booth_master", 1801, 0, 1801, 1, 1802, sequence); _ok(duplicate, "duplicate graze failed structurally"); sequence += 1
	_equal(duplicate.get("duplicate_graze_ignored"), true, "Duplicate UID was not telemetry-only.")
	var red: Dictionary = runtime.on_enemy_defeat("s2_b13", "s2_b13_red_booth_master", "booth_master_red", 100.0, 1803, sequence); _ok(red, "red settlement failed"); sequence += 1
	var exact_duplicate: Dictionary = runtime.on_enemy_defeat("s2_b13", "s2_b13_red_booth_master", "booth_master_red", 100.0, 1803, sequence - 1)
	_equal(exact_duplicate.get("ignored"), true, "Exact callback replay was not idempotently ignored.")
	var later_duplicate: Dictionary = runtime.on_enemy_defeat("s2_b13", "s2_b13_red_booth_master", "booth_master_red", 100.0, 1804, 0)
	_equal(later_duplicate.get("ignored"), true, "Later duplicate settlement callback was not ignored.")
	_equal(runtime.settlement_records().size(), 1, "Duplicate callback duplicated reward.")
	var stale_before: Dictionary = runtime.capture_snapshot()
	_check(not bool(runtime.on_topology_checkpoint("s2_b14", 360.0, 1802, sequence).get("ok", true)), "Stale tick was accepted.")
	_equal(runtime.capture_snapshot(), stale_before, "Stale rejection mutated runtime state.")

func _assert_snapshot_continuation_and_atomic_rejection() -> void:
	var source := _new_runtime("hard", "snapshot"); var sequence := _enter_route(source); sequence = _settle_first_two(source, sequence, true)
	_ok(source.on_mirror_choice("s2_b15_right_mirror", 600.0, 2100, sequence), "snapshot mirror failed"); sequence += 1
	_ok(source.on_stage_event_entry("s2_b16", 2250, sequence), "snapshot abacus entry failed"); sequence += 1
	_ok(source.on_enemy_defeat("s2_b16", "s2_b15_left_mirror", "water_mirror_yokai", 360.0, 2251, sequence), "snapshot survivor failed"); sequence += 1
	var snapshot: Dictionary = source.capture_snapshot()
	var graze_sequence := sequence
	var expected_result: Dictionary = _graze(source, 3, "snapshot_g3", 2252, graze_sequence)
	var expected_hash: int = source.deterministic_hash({"result": expected_result, "snapshot": source.capture_snapshot()})
	var restored := _new_runtime("hard", "snapshot")
	_check(restored.restore_snapshot(snapshot), "Valid snapshot restore failed: %s" % restored.last_error())
	var actual_result: Dictionary = _graze(restored, 3, "snapshot_g3", 2252, graze_sequence)
	_equal(restored.deterministic_hash({"result": actual_result, "snapshot": restored.capture_snapshot()}), expected_hash, "Restored next callback/result hash diverged.")
	sequence = graze_sequence + 2
	var continuation: Dictionary = restored.capture_snapshot()
	var forged_window: Dictionary = continuation.duplicate(true)
	forged_window["last_stage_tick"] = 2600
	forged_window["last_event_sequence"] = 0
	forged_window["last_callback_record"]["stage_tick"] = 2600
	forged_window["last_callback_record"]["event_sequence"] = 0
	forged_window["last_callback_signature"] = JSON.stringify(forged_window["last_callback_record"], "", true, true)
	_check(not restored.restore_snapshot(forged_window), "Group-3 armed snapshot beyond its deadline was accepted.")
	_equal(restored.capture_snapshot(), continuation, "Window-forged snapshot rejection mutated state.")
	_finish_restored_snapshot_route(restored, sequence)
	var expected_complete_hash: int = restored.deterministic_hash(restored.capture_snapshot())
	var completed := _new_runtime("hard", "snapshot")
	_check(completed.restore_snapshot(continuation), "Continuation snapshot restore failed.")
	_finish_restored_snapshot_route(completed, sequence)
	_equal(completed.deterministic_hash(completed.capture_snapshot()), expected_complete_hash, "Restore-to-completion result diverged.")
	_equal(completed.route_state(), "complete", "Restored route did not reach complete.")
	var terminal_cause_before: Dictionary = completed.capture_snapshot()["terminal_cause_record"]
	var ignored_after_terminal: Dictionary = completed.on_stage_event_entry("s2_b18", 2551, 0)
	_equal(ignored_after_terminal.get("ignored"), true, "Post-terminal callback was not ignored.")
	_equal(completed.capture_snapshot()["terminal_cause_record"], terminal_cause_before, "Ignored callback overwrote immutable terminal cause.")
	var baseline: Dictionary = completed.capture_snapshot()
	_check(completed.validate_snapshot(baseline), "Runtime rejected its completed snapshot.")
	for mutation in ["missing", "multiplier", "mirror", "uid", "terminal", "expired", "duplicate_settlement", "settlement_window", "settlement_type", "reward", "graph", "signature", "callback_record", "callback_kind", "missing_latch", "emission_tuple", "required_latch", "resigned_gate_tick", "settlement_mismatch", "extra_payload", "terminal_history", "missing_terminal_cause", "terminal_cause_signature", "misattributed_terminal_payload"]:
		var malformed: Dictionary = baseline.duplicate(true)
		if mutation == "missing": malformed.erase("route_state")
		elif mutation == "multiplier": malformed["point_value_multiplier"] = 9.0
		elif mutation == "mirror": malformed["selected_mirror"]["mapped_lane_id"] = "lane_center"
		elif mutation == "uid": malformed["accepted_graze_uids"].append("not_selected")
		elif mutation == "terminal": malformed["route_state"] = "invalidated"; malformed["terminal_reason"] = "wrong_final_lane_cross"
		elif mutation == "expired": malformed["route_state"] = "expired"; malformed["terminal_reason"] = "final_lane_cross_expired"
		elif mutation == "duplicate_settlement": malformed["settlement_records"].append(malformed["settlement_records"][2].duplicate(true))
		elif mutation == "settlement_window": malformed["settlement_records"][0]["stage_tick"] = 1799
		elif mutation == "settlement_type": malformed["settlement_records"][0]["stage_tick"] = "1802"
		elif mutation == "reward": malformed["settlement_records"][2]["seal_spawn_count"] = 0
		elif mutation == "graph": malformed["topology_revision_id"] = "stage_front_after_blue_neighbor_flip"
		elif mutation == "signature": malformed["last_callback_signature"] = "forged"
		elif mutation == "callback_record": malformed["last_callback_record"]["event_sequence"] = 99
		elif mutation == "callback_kind": malformed["last_callback_record"]["kind"] = "forged_callback"; malformed["last_callback_signature"] = JSON.stringify(malformed["last_callback_record"], "", true, true)
		elif mutation == "missing_latch": malformed["group_latches"].erase("3")
		elif mutation == "emission_tuple": malformed["emission_registry"]["snapshot_g3"]["bullet_spawn_tick"] = 2251
		elif mutation == "required_latch": malformed["required_bullet_by_group"].erase("3")
		elif mutation == "resigned_gate_tick":
			malformed["terminal_cause_record"]["callback_record"]["payload"]["boss_gate_open_tick"] = 2551
			malformed["terminal_cause_record"]["callback_signature"] = JSON.stringify(malformed["terminal_cause_record"]["callback_record"], "", true, true)
		elif mutation == "settlement_mismatch": malformed["settlement_records"][2]["boss_gate_open_tick"] = 2549; malformed["terminal_cause_record"]["history"]["settlement_records"][2]["boss_gate_open_tick"] = 2549
		elif mutation == "extra_payload": malformed["last_callback_record"]["payload"]["extra"] = true; malformed["last_callback_signature"] = JSON.stringify(malformed["last_callback_record"], "", true, true)
		elif mutation == "terminal_history": malformed["terminal_cause_record"]["history"]["settled_group_count"] = 2
		elif mutation == "missing_terminal_cause": malformed["terminal_cause_record"] = {}
		elif mutation == "terminal_cause_signature": malformed["terminal_cause_record"]["callback_signature"] = "forged"
		else:
			malformed["terminal_cause_record"]["callback_record"]["payload"]["player_center_x"] = 600.0
			malformed["terminal_cause_record"]["callback_signature"] = JSON.stringify(malformed["terminal_cause_record"]["callback_record"], "", true, true)
		_check(not completed.restore_snapshot(malformed), "Malformed %s snapshot was accepted." % mutation)
		_equal(completed.capture_snapshot(), baseline, "Malformed %s restore partially mutated state." % mutation)
	var forged_precommit: Dictionary = baseline.duplicate(true)
	forged_precommit["precommit_tick"] = 2544
	forged_precommit["precommit_event_sequence"] = 0
	forged_precommit["terminal_cause_record"]["history"]["precommit_tick"] = 2544
	forged_precommit["terminal_cause_record"]["history"]["precommit_event_sequence"] = 0
	_check(not completed.restore_snapshot(forged_precommit), "Consistent two-copy forged precommit provenance was accepted.")
	_equal(completed.capture_snapshot(), baseline, "Forged precommit rejection partially mutated state.")

func _assert_target_before_graze_snapshot_round_trips() -> void:
	var source := _new_runtime("normal", "target_before_graze")
	var sequence := _enter_route(source)
	_ok(source.on_enemy_defeat("s2_b13", "s2_b13_red_booth_master", "booth_master_red", 100.0, 1801, sequence), "Group-1 target-before-graze defeat failed")
	sequence += 1
	var group_1_snapshot: Dictionary = source.capture_snapshot()
	_check(source.validate_snapshot(group_1_snapshot), "Group-1 target-before-graze snapshot did not validate.")
	var group_1_restored := _new_runtime("normal", "target_before_graze")
	_check(group_1_restored.restore_snapshot(group_1_snapshot), "Group-1 target-before-graze snapshot restore failed: %s" % group_1_restored.last_error())
	var expected_group_1: Dictionary = _graze(source, 1, "target_before_graze_g1", 1802, sequence)
	var actual_group_1: Dictionary = _graze(group_1_restored, 1, "target_before_graze_g1", 1802, sequence)
	_equal(group_1_restored.deterministic_hash({"result": actual_group_1, "snapshot": group_1_restored.capture_snapshot()}), source.deterministic_hash({"result": expected_group_1, "snapshot": source.capture_snapshot()}), "Group-1 target-before-graze continuation diverged after restore.")
	_equal(group_1_restored.route_state(), "group_2_armed", "Group-1 target-before-graze continuation did not settle.")
	sequence += 2
	_ok(group_1_restored.on_enemy_defeat("s2_b14", "s2_b13_blue_booth_master", "booth_master_blue", 100.0, 1951, sequence), "Group-2 target-before-graze defeat failed")
	sequence += 1
	var group_2_snapshot: Dictionary = group_1_restored.capture_snapshot()
	_check(group_1_restored.validate_snapshot(group_2_snapshot), "Group-2 target-before-graze snapshot did not validate.")
	var group_2_restored := _new_runtime("normal", "target_before_graze")
	_check(group_2_restored.restore_snapshot(group_2_snapshot), "Group-2 target-before-graze snapshot restore failed: %s" % group_2_restored.last_error())
	var expected_group_2: Dictionary = _graze(group_1_restored, 2, "target_before_graze_g2", 1952, sequence)
	var actual_group_2: Dictionary = _graze(group_2_restored, 2, "target_before_graze_g2", 1952, sequence)
	_equal(group_2_restored.deterministic_hash({"result": actual_group_2, "snapshot": group_2_restored.capture_snapshot()}), group_1_restored.deterministic_hash({"result": expected_group_2, "snapshot": group_1_restored.capture_snapshot()}), "Group-2 target-before-graze continuation diverged after restore.")
	_equal(group_2_restored.route_state(), "group_3_armed", "Group-2 target-before-graze continuation did not settle.")
	_equal(group_2_restored.settled_group_count(), 2, "Target-before-graze round trips settled the wrong group count.")

func _finish_restored_snapshot_route(runtime: RefCounted, sequence: int) -> void:
	_ok(runtime.on_enemy_defeat("s2_b16", "s2_b16_abacus_keeper", "closing_abacus_keeper", 360.0, 2253, sequence), "Restored abacus defeat failed")
	_ok(runtime.on_enemy_defeat("s2_b17", "s2_b13_yellow_booth_master", "booth_master_yellow", 100.0, 2400, 0), "Restored yellow defeat failed")
	_ok(runtime.on_final_lane_crossing("s2_b18", 100.0, 2550, 2550, 0), "Restored final crossing failed")

func _initialize() -> void:
	call_deferred("_run")
