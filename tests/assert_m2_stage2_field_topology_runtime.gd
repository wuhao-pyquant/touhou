extends SceneTree

const Stage2FieldTopologyRuntime := preload("res://scripts/runtime/stage2_field_topology_runtime.gd")
const MAX_CANONICAL_DEPTH := 32
const MAX_CANONICAL_COLLECTION := 8192

const FIELD_EVENTS := ["s2_b01", "s2_b02", "s2_b03", "s2_b04", "s2_b05", "s2_b12", "s2_b13", "s2_b15", "s2_b16"]
const FIRST_BURST_TICKS := {
	"s2_b01": 48,
	"s2_b02": 204,
	"s2_b03": 324,
	"s2_b04": 480,
	"s2_b05": 618,
	"s2_b12": 1710,
	"s2_b13": 1830,
	"s2_b15": 2130,
	"s2_b16": 2274,
}
const FIRST_BURST_COUNTS := {
	"s2_b01": 9,
	"s2_b02": 12,
	"s2_b03": 10,
	"s2_b04": 12,
	"s2_b05": 10,
	"s2_b12": 9,
	"s2_b13": 17,
	"s2_b15": 10,
	"s2_b16": 7,
}
const EXPECTED_FIELD_SPAWNS := [
	"s2_b01_abacus_left", "s2_b01_abacus_center", "s2_b01_abacus_right",
	"s2_b02_left_clerk", "s2_b02_center_clerk", "s2_b02_right_clerk",
	"s2_b03_red_ledger", "s2_b03_blue_ledger",
	"s2_b04_left_booth_edge", "s2_b04_right_booth_edge",
	"s2_b05_left_bead_seller", "s2_b05_right_bead_seller",
	"s2_b12_red_flag_runner", "s2_b12_blue_flag_runner", "s2_b12_yellow_flag_runner",
	"s2_b13_red_booth_master", "s2_b13_blue_booth_master", "s2_b13_yellow_booth_master",
	"s2_b15_left_mirror", "s2_b15_right_mirror", "s2_b16_abacus_keeper",
]

var failed := false
var _frozen_contract: Dictionary = {}

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)

func _check_equal(actual: Variant, expected: Variant, message: String) -> void:
	_check(actual == expected, "%s Expected %s, got %s" % [message, expected, actual])

func _load_contract() -> Dictionary:
	var file := FileAccess.open("res://content/runtime/m2_stage2_field_topology_contract.json", FileAccess.READ)
	_check(file != null, "Could not open the frozen Stage 2 field topology contract.")
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	_check(parsed is Dictionary, "Frozen Stage 2 field topology contract did not parse as a dictionary.")
	return parsed if parsed is Dictionary else {}

func _new_runtime(difficulty: String, stage_run_uid: String, contract: Dictionary = {}) -> RefCounted:
	var runtime := Stage2FieldTopologyRuntime.new()
	var selected_contract := _frozen_contract if contract.is_empty() else contract
	_check(runtime.configure(selected_contract, difficulty, stage_run_uid), "Runtime configuration failed: %s" % runtime.last_error())
	return runtime

func _find_bullet(records: Array, spawn_id: String, shot_index: int = -1, burst_index: int = -1) -> Dictionary:
	for record_value in records:
		var record: Dictionary = record_value
		if String(record.get("stage2_source_spawn_id", "")) != spawn_id:
			continue
		if shot_index >= 0 and int(record.get("shot_index", -1)) != shot_index:
			continue
		if burst_index >= 0 and int(record.get("burst_index", -1)) != burst_index:
			continue
		return record
	return {}

func _find_update(records: Array, bullet_uid: String, update_kind: String) -> Dictionary:
	for record_value in records:
		var record: Dictionary = record_value
		if String(record.get("stage2_bullet_uid", "")) == bullet_uid and String(record.get("update_kind", "")) == update_kind:
			return record
	return {}

func _records_for_spawn(records: Array, spawn_id: String) -> Array:
	var result: Array = []
	for record_value in records:
		var record: Dictionary = record_value
		if String(record.get("stage2_source_spawn_id", "")) == spawn_id:
			result.append(record)
	return result

func _records_for_event(records: Array, event_id: String) -> Array:
	var result: Array = []
	for record_value in records:
		var record: Dictionary = record_value
		if String(record.get("stage2_source_event_id", "")) == event_id:
			result.append(record)
	return result

func _behavior_signature(record: Dictionary) -> Dictionary:
	return {
		"topology_id": record.get("topology_id", ""),
		"topology_fingerprint": record.get("topology_fingerprint", ""),
		"motion_kind": record.get("motion_kind", ""),
		"route_id": record.get("route_id", ""),
		"route_points": record.get("route_points", []),
		"reflection_plan": record.get("reflection_plan", []),
		"edge_id": record.get("edge_id", ""),
		"lane_id": record.get("lane_id", ""),
		"seed_id": record.get("seed_id", ""),
		"activation_velocity_px_per_second": record.get("activation_velocity_px_per_second", []),
		"collision_delay_ticks": int(record.get("stage2_collision_enable_tick", 0)) - int(record.get("stage2_bullet_spawn_tick", 0)),
		"lifetime_ticks": int(record.get("stage2_lifetime_end_tick", 0)) - int(record.get("stage2_bullet_spawn_tick", 0)),
	}

func _opposite_mirror(selected_spawn_id: String) -> String:
	return "s2_b15_right_mirror" if selected_spawn_id == "s2_b15_left_mirror" else "s2_b15_left_mirror"

func _new_b16_runtime(difficulty: String, stage_run_uid: String, selected_spawn_id: String = "s2_b15_right_mirror") -> RefCounted:
	var runtime := _new_runtime(difficulty, stage_run_uid)
	_check(bool(runtime.activate_event("s2_b15", [], 2100, 0).ok), "%s s2_b16 fixture could not activate s2_b15." % difficulty)
	_check(bool(runtime.accept_defeat(selected_spawn_id, 2101, 0).ok), "%s s2_b16 fixture could not select %s." % [difficulty, selected_spawn_id])
	var survivor := _opposite_mirror(selected_spawn_id)
	_check(bool(runtime.activate_event("s2_b16", [survivor], 2250, 0).ok), "%s s2_b16 fixture rejected live survivor %s." % [difficulty, survivor])
	return runtime

func _assert_contract_coverage_and_difficulty_identity() -> void:
	var normal := _new_runtime("normal", "coverage_normal")
	var hard := _new_runtime("hard", "coverage_hard")
	var normal_summary: Dictionary = normal.contract_summary()
	var hard_summary: Dictionary = hard.contract_summary()
	_check_equal(int(normal_summary.get("spawn_row_count", -1)), 22, "Runtime did not cover all frozen spawn rows.")
	_check_equal(int(normal_summary.get("field_owned_spawn_count", -1)), 21, "Runtime field-owned row count drifted.")
	_check_equal(int(normal_summary.get("fingerprint_count", -1)), 44, "Runtime did not validate all unique structural fingerprints.")
	_check_equal(int(normal_summary.get("event_budget_count", -1)), 18, "Runtime did not validate all event budgets.")
	_check_equal(normal_summary.get("event_budget_ids", []), Stage2FieldTopologyRuntime.EVENT_IDS, "Event-budget ordering drifted from the frozen 18-event sequence.")
	_check_equal(int(normal_summary.get("stage_cap", -1)), 156, "Normal stage cap drifted.")
	_check_equal(int(hard_summary.get("stage_cap", -1)), 204, "Hard stage cap drifted.")
	var primitive_counts: Dictionary = normal_summary.get("primitive_counts", {})
	for primitive in Stage2FieldTopologyRuntime.PRIMITIVES:
		_check(int(primitive_counts.get(primitive, 0)) > 0, "Primitive %s has no covered row." % primitive)
	for spawn_id in Stage2FieldTopologyRuntime.EXPECTED_SPAWN_IDS:
		var normal_definition: Dictionary = normal.definition_for_spawn(spawn_id)
		var hard_definition: Dictionary = hard.definition_for_spawn(spawn_id)
		_check(not normal_definition.is_empty() and not hard_definition.is_empty(), "Missing selected definition for %s." % spawn_id)
		_check(String(normal_definition.profile.topology_id) != String(hard_definition.profile.topology_id), "%s reused a topology ID across difficulties." % spawn_id)
		_check(String(normal_definition.profile.topology_fingerprint) != String(hard_definition.profile.topology_fingerprint), "%s reused a structural fingerprint across difficulties." % spawn_id)

	var normal_b01 := _new_runtime("normal", "distinct_normal")
	var hard_b01 := _new_runtime("hard", "distinct_hard")
	_check(bool(normal_b01.activate_event("s2_b01", [], 0, 0).ok), "Normal s2_b01 activation failed.")
	_check(bool(hard_b01.activate_event("s2_b01", [], 0, 0).ok), "Hard s2_b01 activation failed.")
	var normal_output: Dictionary = normal_b01.advance(48, 1)
	var hard_output: Dictionary = hard_b01.advance(48, 1)
	var normal_first: Dictionary = _find_bullet(normal_output.bullet_constructions, "s2_b01_abacus_left", 0, 0)
	var hard_first: Dictionary = _find_bullet(hard_output.bullet_constructions, "s2_b01_abacus_left", 0, 0)
	_check(not normal_first.is_empty() and not hard_first.is_empty(), "Difficulty fixture did not emit the first left abacus bullet.")
	_check(String(normal_first.get("topology_id", "")) != String(hard_first.get("topology_id", "")), "Normal and Hard emitted the same selected topology.")
	_check(String(normal_first.get("route_id", "")) != String(hard_first.get("route_id", "")), "Normal and Hard emitted the same authored route.")
	_check(float((normal_first.route_points[1] as Array)[0]) != float((hard_first.route_points[1] as Array)[0]), "Hard s2_b01 did not move the first bound waypoint to the opposite booth side.")

func _assert_all_rows_and_primitives_execute() -> void:
	var observed_by_difficulty := {"normal": {}, "hard": {}}
	var primitives_by_difficulty := {"normal": {}, "hard": {}}
	var first_b01: Dictionary = {}
	var delegated_signatures := {}
	var executed_fingerprints := {}
	for difficulty in Stage2FieldTopologyRuntime.DIFFICULTIES:
		var difficulty_observed: Dictionary = observed_by_difficulty[difficulty]
		var difficulty_primitives: Dictionary = primitives_by_difficulty[difficulty]
		for event_id in FIELD_EVENTS:
			var runtime: RefCounted
			if event_id == "s2_b16":
				runtime = _new_b16_runtime(difficulty, "rows_%s_%s" % [difficulty, event_id])
			else:
				runtime = _new_runtime(difficulty, "rows_%s_%s" % [difficulty, event_id])
				var authored_tick := int(Stage2FieldTopologyRuntime.EVENT_TICKS[event_id])
				var activation: Dictionary = runtime.activate_event(event_id, [], authored_tick, 0)
				_check(bool(activation.get("ok", false)), "%s %s activation failed: %s" % [difficulty, event_id, activation.get("error", "")])
			var output: Dictionary = runtime.advance(int(FIRST_BURST_TICKS[event_id]), 1)
			_check(bool(output.get("ok", false)), "%s %s first-burst advance failed: %s" % [difficulty, event_id, output.get("error", "")])
			var event_records := _records_for_event(output.bullet_constructions, event_id)
			_check_equal(event_records.size(), int(FIRST_BURST_COUNTS[event_id]), "%s %s silently changed or truncated its first source bursts." % [difficulty, event_id])
			for record_value in event_records:
				var record: Dictionary = record_value
				var record_spawn_id := String(record.stage2_source_spawn_id)
				if not difficulty_observed.has(record_spawn_id):
					difficulty_observed[record_spawn_id] = record
				difficulty_primitives[String(record.stage2_primitive)] = true
				executed_fingerprints[String(record.topology_fingerprint)] = true
				if difficulty == "normal" and first_b01.is_empty() and record_spawn_id == "s2_b01_abacus_left":
					first_b01 = record
		var delegated := _new_runtime(difficulty, "delegated_phase_%s" % difficulty)
		var delegated_activation: Dictionary = delegated.activate_event("s2_b06", [], 750, 0)
		_check_equal((delegated_activation.source_activations as Array).size(), 1, "%s delegated phase source was not registered." % difficulty)
		var activation_record: Dictionary = delegated_activation.source_activations[0]
		var delegated_definition: Dictionary = delegated.definition_for_spawn("s2_midboss_abacus_tsukumogami")
		_check_equal(String(activation_record.get("execution_owner", "")), "phase_runtime", "%s delegated row lost its phase owner." % difficulty)
		_check_equal(String(activation_record.get("topology_id", "")), String(delegated_definition.profile.topology_id), "%s delegated activation did not select its frozen topology." % difficulty)
		_check_equal(String(activation_record.get("topology_fingerprint", "")), String(delegated_definition.profile.topology_fingerprint), "%s delegated activation did not select its frozen fingerprint." % difficulty)
		delegated_signatures[difficulty] = [activation_record.topology_id, activation_record.topology_fingerprint, activation_record.execution_owner]
		executed_fingerprints[String(activation_record.topology_fingerprint)] = true
		var delegated_output: Dictionary = delegated.advance(900, 1)
		_check((delegated_output.bullet_constructions as Array).is_empty(), "%s phase-owned s2_b06 emitted substitute field bullets." % difficulty)
		observed_by_difficulty[difficulty] = difficulty_observed
		primitives_by_difficulty[difficulty] = difficulty_primitives
	for expected_spawn_id in EXPECTED_FIELD_SPAWNS:
		var normal_record: Dictionary = (observed_by_difficulty.normal as Dictionary).get(expected_spawn_id, {})
		var hard_record: Dictionary = (observed_by_difficulty.hard as Dictionary).get(expected_spawn_id, {})
		_check(not normal_record.is_empty(), "No Normal construction behavior was observed for %s." % expected_spawn_id)
		_check(not hard_record.is_empty(), "No Hard construction behavior was observed for %s." % expected_spawn_id)
		if not normal_record.is_empty() and not hard_record.is_empty():
			_check(_behavior_signature(normal_record) != _behavior_signature(hard_record), "%s emitted no structural Normal/Hard behavior distinction." % expected_spawn_id)
	for difficulty in Stage2FieldTopologyRuntime.DIFFICULTIES:
		for primitive in Stage2FieldTopologyRuntime.PRIMITIVES:
			_check((primitives_by_difficulty[difficulty] as Dictionary).has(primitive), "%s construction output never exercised %s." % [difficulty, primitive])
	_check(delegated_signatures.normal != delegated_signatures.hard, "The executed phase-owned row did not expose distinct Normal/Hard topology selection.")
	_check_equal(executed_fingerprints.size(), 44, "Actual Normal/Hard row execution did not expose all 44 frozen structural fingerprints.")
	_assert_exact_metadata(first_b01)

func _assert_exact_metadata(record: Dictionary) -> void:
	_check(not record.is_empty(), "Exact metadata fixture is missing.")
	if record.is_empty():
		return
	var expected_uid := "rows_normal_s2_b01:s2_b01:s2_b01_abacus_left:b01_left_anchor:0:0"
	_check_equal(String(record.get("bullet_uid", "")), expected_uid, "Bullet UID algorithm drifted.")
	_check_equal(String(record.get("stage2_bullet_uid", "")), expected_uid, "Approved bullet UID seam drifted.")
	_check_equal(String(record.get("stage2_source_event_id", "")), "s2_b01", "Event seam drifted.")
	_check_equal(String(record.get("stage2_source_spawn_id", "")), "s2_b01_abacus_left", "Spawn seam drifted.")
	_check_equal(String(record.get("stage2_source_enemy_id", "")), "market_abacus_frame", "Enemy seam drifted.")
	_check_equal(String(record.get("stage2_primitive", "")), "rebound_bead", "Primitive seam drifted.")
	_check_equal(String(record.get("stage2_routing", "")), "outer_horizontal_bar_once", "Routing seam drifted.")
	_check_equal(int(record.get("stage2_reflection_count", -1)), 0, "Construction reflection count must begin at zero.")
	_check_equal(int(record.get("stage2_bullet_spawn_tick", -1)), 24, "Construction spawn tick drifted.")
	_check(record.get("stage2_first_reflection_tick") == null, "Construction prematurely latched a first reflection tick.")
	_check(record.get("stage2_last_reflection_surface_id") == null, "Construction prematurely latched a reflection surface.")
	_check_equal(int(record.get("stage2_collision_enable_tick", -1)), 24, "Immediate collision tick drifted.")
	_check_equal(int(record.get("stage2_lifetime_end_tick", -1)), 324, "Lifetime end tick drifted.")
	var runtime := _new_runtime("normal", "uid_validation")
	_check(runtime.validate_bullet_uid("uid_validation:s2_b01:s2_b01_abacus_left:b01_left_anchor:0:0"), "Runtime rejected an exact generated UID shape.")
	_check(not bool(runtime.make_bullet_uid("bad:event", "spawn", "emitter", 0, 0).ok), "Runtime accepted a colon-bearing UID component.")
	_check(not runtime.validate_bullet_uid("uid_validation:s2_b01:spawn:emitter:0"), "Runtime accepted a short forged UID.")

func _assert_primitive_motion_semantics() -> void:
	var grid := _new_runtime("hard", "grid_semantics")
	_check(bool(grid.activate_event("s2_b03", [], 300, 0).ok), "Hard grid event activation failed.")
	var grid_output: Dictionary = grid.advance(324, 1)
	var blue_grid: Dictionary = _find_bullet(grid_output.bullet_constructions, "s2_b03_blue_ledger", 0, 0)
	_check_equal(String(blue_grid.get("edge_id", "")), "blue_return_right_upper", "Grid execution ignored authored activation order.")
	_check_equal(String(blue_grid.get("motion_kind", "")), "authored_grid_edge_linear", "Grid execution collapsed to another primitive.")

	var lanes := _new_runtime("hard", "lane_semantics")
	_check(bool(lanes.activate_event("s2_b12", [], 1650, 0).ok), "Hard lane event activation failed.")
	var first_lane_output: Dictionary = lanes.advance(1710, 1)
	var red_first: Dictionary = _find_bullet(first_lane_output.bullet_constructions, "s2_b12_red_flag_runner", 0, 0)
	_check_equal(String(red_first.get("lane_id", "")), "lane_left", "Hard red flag did not start in its authored lane.")
	var second_lane_output: Dictionary = lanes.advance(1800, 2)
	var red_second: Dictionary = _find_bullet(second_lane_output.bullet_constructions, "s2_b12_red_flag_runner", 0, 1)
	_check_equal(String(red_second.get("lane_id", "")), "lane_right", "Hard lane fan did not preserve burst-parity interleaving.")

	var delayed := _new_runtime("hard", "delay_semantics")
	_check(bool(delayed.activate_event("s2_b15", [], 2100, 0).ok), "Hard delayed-seed event activation failed.")
	var delayed_output: Dictionary = delayed.advance(2130, 1)
	var seed: Dictionary = _find_bullet(delayed_output.bullet_constructions, "s2_b15_right_mirror", 0, 0)
	_check_equal(String(seed.get("seed_id", "")), "seed_far", "Hard delayed seed did not use far-to-near activation order.")
	_check_equal(seed.get("velocity_px_per_second", []), [0.0, 0.0], "Delayed seed did not begin dormant.")
	_check_equal(int(seed.get("stage2_collision_enable_tick", -1)), 2142, "Delayed seed collision activation tick drifted.")
	_check(seed.get("activation_velocity_px_per_second", []) != [0.0, 0.0], "Delayed seed did not lock its future launch vector at construction.")
	var activation_output: Dictionary = delayed.advance(2142, 2)
	var activation_update: Dictionary = _find_update(activation_output.bullet_updates, String(seed.stage2_bullet_uid), "seed_activation")
	_check(not activation_update.is_empty(), "Delayed seed did not activate on the exact stored tick.")

	var rebound := _new_runtime("hard", "rebound_semantics")
	_check(bool(rebound.activate_event("s2_b05", [], 600, 0).ok), "Hard bounded rebound event activation failed.")
	var rebound_output: Dictionary = rebound.advance(618, 1)
	var bead: Dictionary = _find_bullet(rebound_output.bullet_constructions, "s2_b05_left_bead_seller", 0, 0)
	_check_equal(String(bead.get("route_id", "")), "left_far_right_b", "Rebound execution ignored authored Hard activation order.")
	_check_equal(float((bead.route_points[1] as Array)[0]), 672.0, "s2_b05 did not use the bounded far opposite wall.")
	_check(int(bead.get("removal_tick", -1)) <= int(bead.get("stage2_lifetime_end_tick", -2)), "s2_b05 route exceeded its bounded lifetime.")
	var premature_graze: Dictionary = rebound.observe_graze(String(bead.stage2_bullet_uid), 618, 2)
	_check((premature_graze.score_route_callbacks as Array).is_empty(), "A rebound graze qualified before the first authored turn.")
	var reflection_tick := int((bead.reflection_plan[0] as Dictionary).tick)
	var reflected_output: Dictionary = rebound.advance(reflection_tick, 3)
	var reflection_update: Dictionary = _find_update(reflected_output.bullet_updates, String(bead.stage2_bullet_uid), "rebound_turn")
	_check(not reflection_update.is_empty(), "Authored rebound waypoint did not emit a turn update.")
	_check_equal(int(reflection_update.get("stage2_reflection_count", -1)), 1, "Rebound count did not latch exactly once.")
	_check_equal(int(reflection_update.get("stage2_first_reflection_tick", -1)), reflection_tick, "First reflection tick did not latch exactly.")
	_check_equal(String(reflection_update.get("stage2_last_reflection_surface_id", "")), "h_b05_far_right_wall", "Rebound surface latch used an alias or wrong wall.")
	var graze: Dictionary = rebound.observe_graze(String(bead.stage2_bullet_uid), reflection_tick, 4)
	_check_equal((graze.score_route_callbacks as Array).size(), 1, "Qualified post-turn graze did not emit exactly one score-route projection.")
	var projection: Dictionary = graze.score_route_callbacks[0]
	_check_equal(String(projection.get("stage_run_uid", "")), "rebound_semantics", "Graze projection lost stage-run identity.")
	_check_equal(int(projection.get("reflection_count_before_graze", 0)), 1, "Graze projection lost the exact pre-graze reflection count.")
	_check_equal(int(projection.get("first_reflection_tick", -1)), reflection_tick, "Graze projection lost the first reflection tick.")
	var duplicate_graze: Dictionary = rebound.observe_graze(String(bead.stage2_bullet_uid), reflection_tick + 1, 0)
	_check(bool(duplicate_graze.get("duplicate", false)) and (duplicate_graze.score_route_callbacks as Array).is_empty(), "Duplicate graze projection was not idempotent.")

func _assert_active_entity_carryover_and_removal() -> void:
	var runtime := _new_runtime("normal", "carryover")
	_check(bool(runtime.activate_event("s2_b04", [], 450, 0).ok), "Carryover fixture could not activate s2_b04.")
	_check(bool(runtime.advance(480, 1).ok), "Carryover fixture could not emit the first booth-edge burst.")
	var carryover_ids := ["s2_b04_left_booth_edge", "s2_b04_right_booth_edge"]
	var b05_activation: Dictionary = runtime.activate_event("s2_b05", carryover_ids, 600, 0)
	_check(bool(b05_activation.get("ok", false)), "Explicit active-entity carryover was rejected.")
	var telemetry: Dictionary = runtime.telemetry_snapshot()
	_check("s2_b04_left_booth_edge" in telemetry.active_source_ids and "s2_b05_left_bead_seller" in telemetry.active_source_ids, "Prior and new sources were not alive together.")
	var removal: Dictionary = runtime.remove_source("s2_b04_left_booth_edge", 601, 0, "test_despawn")
	_check_equal((removal.source_removals as Array).size(), 1, "Explicit source removal did not emit one record.")
	var after_removal: Dictionary = runtime.advance(624, 1)
	_check(_records_for_spawn(after_removal.bullet_constructions, "s2_b04_left_booth_edge").is_empty(), "Removed source emitted another scheduled burst.")
	_check_equal(_records_for_spawn(after_removal.bullet_constructions, "s2_b04_right_booth_edge").size(), 6, "Still-active carried source lost its exact scheduled burst.")
	var duplicate: Dictionary = runtime.remove_source("s2_b04_left_booth_edge", 625, 0, "test_despawn")
	_check(bool(duplicate.get("duplicate", false)) and (duplicate.source_removals as Array).is_empty(), "Duplicate source removal was not idempotent.")

func _assert_atomic_hard_state_transitions() -> void:
	var pre_red := _new_runtime("hard", "pre_red_order")
	_check(bool(pre_red.activate_event("s2_b13", [], 1800, 0).ok), "pre_red fixture activation failed.")
	_check(bool(pre_red.advance(1800, 1).ok), "pre_red warning advance failed.")
	var pre_output: Dictionary = pre_red.advance(1830, 5)
	var pre_blue: Dictionary = _find_bullet(pre_output.bullet_constructions, "s2_b13_blue_booth_master", 0, 0)
	_check_equal(String(pre_blue.get("route_id", "")), "blue_pre_red_right", "Lower-sequence burst did not use pre_red atomically.")
	var late_defeat: Dictionary = pre_red.accept_defeat("s2_b13_red_booth_master", 1830, 6)
	_check_equal((late_defeat.state_transitions as Array).size(), 1, "Later red defeat did not publish one atomic transition.")

	var post_red := _new_runtime("hard", "post_red_order")
	_check(bool(post_red.activate_event("s2_b13", [], 1800, 0).ok), "post_red fixture activation failed.")
	_check(bool(post_red.advance(1800, 1).ok), "post_red warning advance failed.")
	var early_defeat: Dictionary = post_red.accept_defeat("s2_b13_red_booth_master", 1830, 5)
	_check_equal(String(early_defeat.telemetry_snapshot.hard_state.blue_emission_state_id), "post_red", "Red defeat did not switch blue emission state.")
	var post_output: Dictionary = post_red.advance(1830, 6)
	var post_blue: Dictionary = _find_bullet(post_output.bullet_constructions, "s2_b13_blue_booth_master", 0, 0)
	_check_equal(String(post_blue.get("route_id", "")), "blue_revision_right", "Higher-sequence burst did not use post_red atomically.")
	_check_equal(String(post_blue.state_binding.stage_front_revision_id), "stage_front_after_red_neighbor_flip", "Post-red bullet omitted its frozen revision binding.")
	var duplicate_defeat: Dictionary = post_red.accept_defeat("s2_b13_red_booth_master", 1830, 7)
	_check(bool(duplicate_defeat.get("duplicate", false)) and (duplicate_defeat.state_transitions as Array).is_empty(), "Duplicate defeat re-applied an atomic transition.")
	_assert_snapshot_continuation(post_red, "post_red_order")

	var mirror := _new_runtime("hard", "mirror_atomic")
	_check(bool(mirror.activate_event("s2_b13", [], 1800, 0).ok), "Mirror fixture could not activate s2_b13.")
	_check(bool(mirror.advance(1830, 1).ok), "Mirror fixture could not emit s2_b13.")
	_check(bool(mirror.remove_source("s2_b13_red_booth_master", 1831, 0, "fixture_cleanup").ok), "Mirror fixture could not remove red source.")
	_check(bool(mirror.remove_source("s2_b13_blue_booth_master", 1832, 0, "fixture_cleanup").ok), "Mirror fixture could not remove blue source.")
	_check(bool(mirror.activate_event("s2_b15", [], 2100, 0).ok), "Mirror fixture could not activate s2_b15.")
	_check(bool(mirror.advance(2130, 1).ok), "Mirror fixture could not emit the mirror burst.")
	var selected: Dictionary = mirror.accept_defeat("s2_b15_right_mirror", 2142, 5)
	_check_equal(String(selected.telemetry_snapshot.hard_state.yellow_emission_state_id), "mapped_after_right_mirror", "Selected mirror did not atomically map yellow state.")
	_check_equal(int(selected.telemetry_snapshot.hard_state.mirror_activation_mask), 6, "Right selected mirror did not freeze mask 6.")
	var mapped_output: Dictionary = mirror.advance(2142, 6)
	var mapped_yellow: Dictionary = _find_bullet(mapped_output.bullet_constructions, "s2_b13_yellow_booth_master", 0, 4)
	_check_equal(String(mapped_yellow.state_binding.yellow_emission_state_id), "mapped_after_right_mirror", "Same-tick higher-sequence yellow burst observed a partial mirror state.")
	_check_equal(String(mapped_yellow.get("lane_id", "")), "lane_left", "Mapped right-mirror state did not select the authored left lane.")
	var b16_activation: Dictionary = mirror.activate_event("s2_b16", ["s2_b15_left_mirror"], 2250, 0)
	_check(bool(b16_activation.get("ok", false)), "s2_b16 rejected the explicit surviving mirror carryover.")
	var b16_output: Dictionary = mirror.advance(2274, 1)
	var b16_bullet: Dictionary = _find_bullet(b16_output.bullet_constructions, "s2_b16_abacus_keeper", 0, 0)
	_check_equal(String(b16_bullet.get("route_id", "")), "mask6_survivor_left_first", "s2_b16 mask 6 did not choose the surviving-left route first.")
	_check_equal(String((b16_bullet.reflection_plan[0] as Dictionary).surface_id), "h_b16_surviving_left", "s2_b16 did not bind the exact surviving mirror surface.")

func _assert_mirror_survivor_guards() -> void:
	var normal_left_selected := _new_b16_runtime("normal", "normal_mirror_left_route", "s2_b15_left_mirror")
	var normal_left_output: Dictionary = normal_left_selected.advance(2274, 1)
	var normal_left_bullet: Dictionary = _find_bullet(normal_left_output.bullet_constructions, "s2_b16_abacus_keeper", 0, 0)
	_check_equal(String(normal_left_bullet.get("route_id", "")), "abacus_via_right", "Normal mask 5 did not put the surviving-right recovery route first.")

	var left_selected := _new_b16_runtime("hard", "mirror_left_route", "s2_b15_left_mirror")
	_check_equal(int(left_selected.telemetry_snapshot().hard_state.mirror_activation_mask), 5, "Left selection did not expose mask 5 while the right survivor was alive.")
	var left_output: Dictionary = left_selected.advance(2274, 1)
	var left_bullet: Dictionary = _find_bullet(left_output.bullet_constructions, "s2_b16_abacus_keeper", 0, 0)
	_check_equal(String(left_bullet.get("route_id", "")), "mask5_survivor_right_first", "s2_b16 mask 5 did not select the surviving-right route first.")
	_check_equal(String((left_bullet.get("reflection_plan", [{}])[0] as Dictionary).get("surface_id", "")), "h_b16_surviving_right", "s2_b16 mask 5 did not bind the surviving-right surface.")

	var stale_carryover := _new_runtime("hard", "stale_carryover")
	_check(bool(stale_carryover.activate_event("s2_b15", [], 2100, 0).ok), "Stale-carryover fixture could not activate s2_b15.")
	_check(bool(stale_carryover.accept_defeat("s2_b15_right_mirror", 2101, 0).ok), "Stale-carryover fixture could not select the right mirror.")
	var stale_entry: Dictionary = stale_carryover.activate_event("s2_b16", [], 2250, 0)
	_check(not bool(stale_entry.get("ok", true)), "s2_b16 accepted a live survivor that was omitted from explicit carryover.")
	_check_equal(String(stale_carryover.hard_error_snapshot().get("code", "")), "s2_b16_recovery_state_invalid", "Stale carryover failed with the wrong stable error code.")

	var dead_survivor := _new_runtime("hard", "dead_survivor")
	_check(bool(dead_survivor.activate_event("s2_b15", [], 2100, 0).ok), "Dead-survivor fixture could not activate s2_b15.")
	_check(bool(dead_survivor.accept_defeat("s2_b15_right_mirror", 2101, 0).ok), "Dead-survivor fixture could not select the right mirror.")
	var survivor_defeat: Dictionary = dead_survivor.accept_defeat("s2_b15_left_mirror", 2200, 0)
	_check(bool(survivor_defeat.get("ok", false)), "Surviving mirror defeat failed.")
	_check_equal(int(survivor_defeat.telemetry_snapshot.hard_state.mirror_activation_mask), 2, "Defeating the left survivor did not atomically clear the survivor-alive bit.")
	var dead_baseline: Dictionary = dead_survivor.capture_snapshot()
	_check(dead_survivor.validate_snapshot(dead_baseline), "Runtime rejected the reachable dead-survivor baseline snapshot.")
	var stale_mask_snapshot: Dictionary = dead_baseline.duplicate(true)
	stale_mask_snapshot.payload.hard_state.mirror_activation_mask = 6
	_redigest_snapshot(stale_mask_snapshot)
	_check(not dead_survivor.restore_snapshot(stale_mask_snapshot), "Runtime accepted a recomputed-digest stale survivor mask.")
	_check_equal(dead_survivor.capture_snapshot(), dead_baseline, "Rejected stale-mask snapshot partially mutated runtime state.")
	var dead_entry: Dictionary = dead_survivor.activate_event("s2_b16", [], 2250, 0)
	_check(not bool(dead_entry.get("ok", true)), "s2_b16 selected a recovery route after the survivor died.")
	_check_equal(String(dead_survivor.hard_error_snapshot().get("code", "")), "s2_b16_recovery_state_invalid", "Dead-survivor entry failed with the wrong stable error code.")

	var dies_after_entry := _new_b16_runtime("hard", "dies_after_entry", "s2_b15_right_mirror")
	var post_entry_removal: Dictionary = dies_after_entry.remove_source("s2_b15_left_mirror", 2251, 0, "survivor_removed_after_entry")
	_check_equal(int(post_entry_removal.telemetry_snapshot.hard_state.mirror_activation_mask), 2, "Post-entry survivor removal left the alive bit set.")
	var blocked_burst: Dictionary = dies_after_entry.advance(2274, 1)
	_check(not bool(blocked_burst.get("ok", true)), "s2_b16 emitted after its entry survivor died.")
	_check(_records_for_spawn(blocked_burst.bullet_constructions, "s2_b16_abacus_keeper").is_empty(), "s2_b16 silently chose a fabricated route after survivor death.")
	_check_equal(String(dies_after_entry.hard_error_snapshot().get("code", "")), "s2_b16_recovery_state_invalid", "Post-entry survivor death failed with the wrong stable error code.")

func _redigest_snapshot(snapshot: Dictionary) -> void:
	snapshot.state_digest = _snapshot_canonical_value(snapshot.payload, 0).sha256_text()

func _snapshot_canonical_value(value: Variant, depth: int) -> String:
	if depth > MAX_CANONICAL_DEPTH:
		return ""
	match typeof(value):
		TYPE_NIL:
			return "n;"
		TYPE_BOOL:
			return "b1;" if bool(value) else "b0;"
		TYPE_INT, TYPE_FLOAT:
			var number := float(value)
			if is_nan(number) or is_inf(number):
				return ""
			return "x%.9f;" % number
		TYPE_STRING, TYPE_STRING_NAME:
			var text := String(value)
			return "s%d:%s;" % [text.length(), text]
		TYPE_ARRAY:
			var array: Array = value
			if array.size() > MAX_CANONICAL_COLLECTION:
				return ""
			var result := "a%d[" % array.size()
			for item in array:
				var encoded := _snapshot_canonical_value(item, depth + 1)
				if encoded.is_empty():
					return ""
				result += encoded
			return result + "]"
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			if dictionary.size() > MAX_CANONICAL_COLLECTION:
				return ""
			var keys: Array[String] = []
			for key in dictionary.keys():
				if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME]:
					return ""
				keys.append(String(key))
			keys.sort()
			var result := "d%d{" % keys.size()
			for key in keys:
				var encoded_key := _snapshot_canonical_value(key, depth + 1)
				var encoded_value := _snapshot_canonical_value(dictionary[key], depth + 1)
				if encoded_key.is_empty() or encoded_value.is_empty():
					return ""
				result += encoded_key + encoded_value
			return result + "}"
		_:
			return ""

func _assert_snapshot_continuation(runtime: RefCounted, stage_run_uid: String) -> void:
	var snapshot: Dictionary = runtime.capture_snapshot()
	_check_equal(String(snapshot.get("schema", "")), "stage2_field_topology_runtime_snapshot_v1", "Snapshot schema ID drifted.")
	_check_equal(int(snapshot.get("version", -1)), 1, "Snapshot version drifted.")
	_check(runtime.validate_snapshot(snapshot), "Runtime rejected its own snapshot.")
	var restored := _new_runtime("hard", stage_run_uid)
	_check(restored.restore_snapshot(snapshot), "Fresh runtime rejected a valid snapshot.")
	var baseline: Dictionary = restored.capture_snapshot()
	var forged: Dictionary = snapshot.duplicate(true)
	forged.payload.source_states.s2_b13_blue_booth_master.next_burst_index = 999
	_check(not restored.restore_snapshot(forged), "Runtime accepted a forged source cursor without a matching state digest.")
	_check_equal(restored.capture_snapshot(), baseline, "Rejected snapshot partially mutated runtime state.")
	var impossible_state: Dictionary = snapshot.duplicate(true)
	impossible_state.payload.hard_state.blue_emission_state_id = "pre_red"
	impossible_state.payload.hard_state.stage_front_revision_id = "stage_front_after_red_neighbor_flip"
	_redigest_snapshot(impossible_state)
	_check(not restored.restore_snapshot(impossible_state), "Runtime accepted a recomputed-digest unreachable Hard revision/state pair.")
	_check_equal(restored.capture_snapshot(), baseline, "Rejected impossible Hard state partially mutated runtime state.")
	var divergent_seam: Dictionary = snapshot.duplicate(true)
	var active_uids: Array = divergent_seam.payload.active_bullets.keys()
	active_uids.sort()
	_check(not active_uids.is_empty(), "Snapshot seam-forgery fixture had no active bullet.")
	if not active_uids.is_empty():
		var active_uid := String(active_uids[0])
		divergent_seam.payload.active_bullets[active_uid].stage2_routing = "forged_adapter_route"
		_redigest_snapshot(divergent_seam)
		_check(not restored.restore_snapshot(divergent_seam), "Runtime accepted a recomputed-digest divergent Stage 2 adapter seam.")
		_check_equal(restored.capture_snapshot(), baseline, "Rejected divergent seam partially mutated runtime state.")
	var forged_version: Dictionary = snapshot.duplicate(true)
	forged_version.version = 2
	_check(not restored.restore_snapshot(forged_version), "Runtime accepted an unknown snapshot version.")
	_check_equal(restored.capture_snapshot(), baseline, "Rejected version partially mutated runtime state.")
	var expected_next: Dictionary = runtime.advance(1884, 1)
	var restored_next: Dictionary = restored.advance(1884, 1)
	_check_equal(restored_next, expected_next, "Next output diverged after atomic snapshot restore.")
	var seeked := _new_runtime("hard", stage_run_uid)
	_check(seeked.seek_snapshot(snapshot), "Snapshot seek alias rejected a valid deterministic state.")
	_check_equal(seeked.advance(1884, 1), expected_next, "Seek continuation diverged from the original output.")

func _assert_coordinate_contract_rejected(contract: Dictionary, stage_run_uid: String, label: String) -> void:
	var runtime := Stage2FieldTopologyRuntime.new()
	_check(not runtime.configure(contract, "normal", stage_run_uid), "%s coordinate fixture was accepted." % label)
	var error: Dictionary = runtime.hard_error_snapshot()
	_check_equal(String(error.get("code", "")), "configuration_rejected", "%s used the wrong rejection code." % label)
	_check_equal(String(error.get("path", "")), "coordinate_contract", "%s used the wrong rejection path." % label)
	_check(runtime.capture_snapshot().is_empty(), "%s rejection exposed a snapshot." % label)

func _assert_fail_closed_contracts_caps_and_uids() -> void:
	var parsed_json_runtime := Stage2FieldTopologyRuntime.new()
	_check(parsed_json_runtime.configure(_frozen_contract, "normal", "parsed_json_bounds"), "Parsed JSON combat bounds were rejected: %s" % parsed_json_runtime.last_error())
	_check(not parsed_json_runtime.capture_snapshot().is_empty(), "Parsed JSON combat bounds did not produce a configured snapshot.")

	var integer_bounds: Dictionary = _frozen_contract.duplicate(true)
	integer_bounds.coordinate_contract.combat_bounds = [24, 48, 696, 936]
	var integer_bounds_runtime := Stage2FieldTopologyRuntime.new()
	_check(integer_bounds_runtime.configure(integer_bounds, "normal", "integer_bounds"), "Equivalent integer combat bounds were rejected: %s" % integer_bounds_runtime.last_error())
	_check(not integer_bounds_runtime.capture_snapshot().is_empty(), "Equivalent integer combat bounds did not produce a configured snapshot.")

	var wrong_length: Dictionary = _frozen_contract.duplicate(true)
	wrong_length.coordinate_contract.combat_bounds = [24.0, 48.0, 696.0]
	_assert_coordinate_contract_rejected(wrong_length, "bounds_wrong_length", "Wrong-length bounds")
	var numeric_string: Dictionary = _frozen_contract.duplicate(true)
	numeric_string.coordinate_contract.combat_bounds = ["24", 48.0, 696.0, 936.0]
	_assert_coordinate_contract_rejected(numeric_string, "bounds_numeric_string", "Numeric-looking String bound")
	var nan_bound: Dictionary = _frozen_contract.duplicate(true)
	nan_bound.coordinate_contract.combat_bounds = [NAN, 48.0, 696.0, 936.0]
	_assert_coordinate_contract_rejected(nan_bound, "bounds_nan", "NAN bound")
	var inf_bound: Dictionary = _frozen_contract.duplicate(true)
	inf_bound.coordinate_contract.combat_bounds = [24.0, INF, 696.0, 936.0]
	_assert_coordinate_contract_rejected(inf_bound, "bounds_inf", "INF bound")
	var incorrect_bound: Dictionary = _frozen_contract.duplicate(true)
	incorrect_bound.coordinate_contract.combat_bounds = [25.0, 48.0, 696.0, 936.0]
	_assert_coordinate_contract_rejected(incorrect_bound, "bounds_incorrect", "Incorrect finite bound")
	var reordered_bounds: Dictionary = _frozen_contract.duplicate(true)
	reordered_bounds.coordinate_contract.combat_bounds = [48.0, 24.0, 696.0, 936.0]
	_assert_coordinate_contract_rejected(reordered_bounds, "bounds_reordered", "Reordered finite bounds")
	var wrong_tick_rate: Dictionary = _frozen_contract.duplicate(true)
	wrong_tick_rate.coordinate_contract.tick_rate = 59
	_assert_coordinate_contract_rejected(wrong_tick_rate, "tick_rate_59", "tick_rate 59")

	var missing_row: Dictionary = _frozen_contract.duplicate(true)
	missing_row.spawn_topologies.pop_back()
	var missing_runtime := Stage2FieldTopologyRuntime.new()
	_check(not missing_runtime.configure(missing_row, "normal", "missing_row"), "Runtime accepted a 21-row partial contract.")
	_check(missing_runtime.has_hard_error() and missing_runtime.capture_snapshot().is_empty(), "Partial-contract rejection did not fail closed.")

	var forged_cap: Dictionary = _frozen_contract.duplicate(true)
	forged_cap.event_budgets[15].peak_active_bullets.hard = 205
	var cap_runtime := Stage2FieldTopologyRuntime.new()
	_check(not cap_runtime.configure(forged_cap, "hard", "forged_cap"), "Runtime accepted a stage/event cap above 204.")

	var malformed_route: Dictionary = _frozen_contract.duplicate(true)
	malformed_route.spawn_topologies[0].profiles.normal.geometry.ordered_routes[0].points = [[156, 232]]
	var route_runtime := Stage2FieldTopologyRuntime.new()
	_check(not route_runtime.configure(malformed_route, "normal", "malformed_route"), "Runtime accepted a deeply malformed authored route.")

	var alias_route: Dictionary = _frozen_contract.duplicate(true)
	alias_route.spawn_topologies[0].source.pattern.routing = "generic_alias"
	var alias_runtime := Stage2FieldTopologyRuntime.new()
	_check(not alias_runtime.configure(alias_route, "normal", "alias_route"), "Runtime accepted a generic routing substitution.")

	var uid_runtime := Stage2FieldTopologyRuntime.new()
	_check(not uid_runtime.configure(_frozen_contract, "normal", "bad:run"), "Runtime accepted a colon-bearing stage run UID.")
	var difficulty_runtime := Stage2FieldTopologyRuntime.new()
	_check(not difficulty_runtime.configure(_frozen_contract, "Normal", "bad_difficulty"), "Runtime accepted a non-exact difficulty selector.")

	var cap_guard := _new_runtime("normal", "runtime_cap_guard")
	_check(bool(cap_guard.activate_event("s2_b01", [], 0, 0).ok), "Runtime cap fixture could not activate s2_b01.")
	var cap_result: Dictionary = cap_guard.activate_event("s2_b02", [], 150, 0)
	if bool(cap_result.get("ok", false)):
		cap_result = cap_guard.activate_event("s2_b03", [], 300, 0)
	if bool(cap_result.get("ok", false)):
		cap_result = cap_guard.advance(444, 1)
	_check(not bool(cap_result.get("ok", true)), "Unbounded cross-event carryover never tripped a declared whole-burst cap.")
	_check_equal(String(cap_guard.hard_error_snapshot().get("code", "")), "active_bullet_cap_exceeded", "Runtime cap failure used the wrong stable error code.")
	_check_equal(int(cap_guard.telemetry_snapshot().get("active_bullet_count", -1)), 0, "Runtime cap fault did not clear all field-owned bullets.")

func _run() -> void:
	_frozen_contract = _load_contract()
	if _frozen_contract.is_empty():
		quit(1)
		return
	_assert_contract_coverage_and_difficulty_identity()
	_assert_all_rows_and_primitives_execute()
	_assert_primitive_motion_semantics()
	_assert_active_entity_carryover_and_removal()
	_assert_atomic_hard_state_transitions()
	_assert_mirror_survivor_guards()
	_assert_fail_closed_contracts_caps_and_uids()
	if failed:
		quit(1)
		return
	print("PASS: M2 Stage 2 field topology runtime validates 22 rows/44 fingerprints/18 budgets, executes four authored primitives, preserves exact seams and atomic deterministic state.")
	quit(0)

func _initialize() -> void:
	call_deferred("_run")
