extends SceneTree

const DanmakuPatternRuntime := preload("res://scripts/runtime/danmaku_pattern_runtime.gd")
const StageEncounterRuntime := preload("res://scripts/runtime/stage_encounter_runtime.gd")

var failed := false

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)

func _check_equal(actual: Variant, expected: Variant, message: String) -> void:
	_check(actual == expected, "%s Expected %s, got %s" % [message, expected, actual])

func _phase_fixture() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "m2_fixture_phase",
		"deterministic_random_stream_id": "danmaku.m2.fixture.phase.v1",
		"loop_ticks": 60,
		"warning_ticks": {"normal": 12, "hard": 8},
		"boss_movement": [
			{"id": "move_left", "tick": 0, "position": Vector2(240.0, 150.0), "duration_ticks": 20},
			{"id": "move_center", "tick": 20, "position": Vector2(360.0, 120.0), "duration_ticks": 20},
			{"id": "move_right", "tick": 40, "position": Vector2(480.0, 150.0), "duration_ticks": 20},
		],
		"timeline": [
			{"id": "phase_open", "tick": 0, "kind": "phase_event", "tag": "open"},
			{"id": "route_commit", "tick": 15, "kind": "phase_event", "tag": "route"},
			{"id": "route_cross", "tick": 30, "kind": "phase_event", "tag": "cross"},
			{"id": "phase_loop", "tick": 45, "kind": "phase_event", "tag": "loop"},
		],
		"difficulties": {
			"normal": {
				"topology_id": "market_parallel_lanes",
				"emitters": _emitters(false),
			},
			"hard": {
				"topology_id": "market_cross_linked_lanes",
				"emitters": _emitters(true),
			},
		},
	}

func _emitters(hard: bool) -> Array:
	var warning_lead := 8 if hard else 12
	var prefix := "hard_" if hard else "normal_"
	return [
		{
			"id": prefix + "rebound",
			"primitive": "rebound_bead",
			"start_tick": 12,
			"interval_ticks": 30,
			"bursts_per_loop": 2,
			"shots_per_burst": 3,
			"anchor": Vector2(360.0, 140.0),
			"family": "circle",
			"color_rgba": [0.3, 0.8, 1.0, 1.0],
			"radius": 6.0,
			"lifetime_ticks": 300,
			"speed": 2.4,
			"warning": {"lead_ticks": warning_lead},
			"angle_degrees": 90.0 if not hard else 45.0,
			"spread_degrees": 24.0,
			"random_angle_degrees": 1.25,
			"reflection": {
				"axes": "y" if not hard else "xy",
				"max_reflections": 1 if not hard else 2,
				"bounds": Rect2(24.0, 48.0, 672.0, 888.0),
			},
		},
		{
			"id": prefix + "grid",
			"primitive": "grid_edge",
			"start_tick": 18,
			"interval_ticks": 60,
			"bursts_per_loop": 1,
			"shots_per_burst": 4,
			"anchor": Vector2(300.0, 96.0) if not hard else Vector2(60.0, 240.0),
			"family": "rice",
			"color_rgba": Color(1.0, 0.75, 0.2, 1.0),
			"radius": 5.0,
			"lifetime_ticks": 280,
			"speed": 2.0,
			"warning": {"lead_ticks": warning_lead},
			"angle_degrees": 90.0 if not hard else 0.0,
			"random_angle_degrees": 0.5,
			"routing": "down" if not hard else "right",
			"spacing": 40.0,
		},
		{
			"id": prefix + ("lane_branch" if hard else "lane"),
			"primitive": "lane_fan",
			"start_tick": 24,
			"interval_ticks": 60,
			"bursts_per_loop": 1,
			"shots_per_burst": 5 if hard else 3,
			"anchor": Vector2(360.0, 160.0),
			"family": "talisman",
			"color_rgba": [1.0, 0.25, 0.35, 1.0],
			"radius": 5.5,
			"lifetime_ticks": 260,
			"speed": 2.8,
			"warning": {"lead_ticks": warning_lead},
			"angle_degrees": 0.0,
			"spread_degrees": 30.0 if not hard else 54.0,
			"random_angle_degrees": 0.75,
			"aim_mode": "player_locked",
			"aim_lock_ticks": [20],
		},
		{
			"id": prefix + "rhythm",
			"primitive": "rhythm_pulse",
			"start_tick": 30,
			"interval_ticks": 60,
			"bursts_per_loop": 1,
			"shots_per_burst": 6 if not hard else 8,
			"anchor": Vector2(360.0, 180.0),
			"family": "star",
			"color_rgba": [0.8, 0.3, 1.0, 1.0],
			"radius": 6.0,
			"lifetime_ticks": 320,
			"speed": 1.9,
			"warning": {"lead_ticks": warning_lead},
			"angle_degrees": 0.0,
			"burst_angle_step_degrees": 11.0,
			"random_angle_degrees": 0.6,
			"turn_rate": -0.008 if not hard else 0.011,
		},
		{
			"id": prefix + "delayed",
			"primitive": "delayed_seed",
			"start_tick": 42,
			"interval_ticks": 60,
			"bursts_per_loop": 1,
			"shots_per_burst": 3 if not hard else 4,
			"anchor": Vector2(360.0, 130.0),
			"family": "spiral_seed",
			"color_rgba": [0.7, 0.9, 1.0, 0.8],
			"radius": 4.5,
			"lifetime_ticks": 360,
			"speed": 2.2,
			"warning": {"lead_ticks": warning_lead},
			"angle_degrees": 0.0,
			"spread_degrees": 20.0,
			"random_angle_degrees": 1.0,
			"aim_mode": "player_locked",
			"aim_lock_ticks": [38],
			"delay_ticks": 24 if not hard else 16,
			"turn_rate": 0.004 if not hard else -0.006,
		},
	]

func _player_positions(tick_count: int) -> Dictionary:
	var result := {}
	for tick in range(tick_count):
		result[tick] = Vector2(120.0 + float((tick * 37) % 480), 760.0 - float((tick * 11) % 160))
	return result

func _reverse_dictionary_order(value: Variant) -> Variant:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		keys.reverse()
		var reordered := {}
		for key in keys:
			reordered[key] = _reverse_dictionary_order(value[key])
		return reordered
	if value is Array:
		var reordered_array: Array = []
		for entry in value:
			reordered_array.append(_reverse_dictionary_order(entry))
		return reordered_array
	return value

func _advance_trace(runtime, tick_count: int, positions: Dictionary, from_tick: int = 0) -> Array:
	var result: Array = []
	for offset in range(tick_count):
		var tick := from_tick + offset
		var output: Dictionary = runtime.advance(positions.get(tick, Vector2.ZERO))
		_check(bool(output.get("ok", false)), "Pattern advance failed at tick %d: %s" % [tick, output.get("error", "")])
		_check(typeof(output.get("tick")) == TYPE_INT and int(output.tick) == tick, "Pattern runtime did not advance one exact integer tick at %d." % tick)
		_check(typeof(output.get("loop_tick")) == TYPE_INT and typeof(output.get("loop_index")) == TYPE_INT, "Pattern loop counters were not integer tick state.")
		result.append(output)
	return result

func _assert_motion_contract(spec: Dictionary) -> void:
	_check(spec.position is Vector2 and spec.velocity is Vector2, "Motion spec position/velocity types are malformed.")
	_check(float(spec.radius) > 0.0 and float(spec.lifetime) > 0.0, "Motion spec radius/lifetime must be positive.")
	var motion: Dictionary = spec.motion
	match String(spec.primitive):
		"rebound_bead":
			_check_equal(String(motion.get("kind", "")), "reflect", "Rebound bead motion kind drifted.")
			_check(String(motion.get("axes", "")) in ["x", "y", "xy"], "Rebound bead omitted valid reflection axes.")
			_check(int(motion.get("max_reflections", 0)) >= 1 and int(motion.get("max_reflections", 0)) <= DanmakuPatternRuntime.MAX_REFLECTIONS, "Rebound count is outside its cap.")
			_check_equal(int(motion.get("bounce_count", -1)), int(motion.get("max_reflections", 0)), "Rebound compatibility count diverged from authored reflections.")
			_check(motion.get("bounds") is Rect2 and motion.bounds.size.x > 0.0 and motion.bounds.size.y > 0.0, "Rebound bounds are malformed.")
		"grid_edge":
			_check_equal(String(motion.get("kind", "")), "linear_route", "Grid-edge motion kind drifted.")
			_check(String(motion.get("routing", "")) in ["down", "up", "left", "right"], "Grid-edge routing is malformed.")
		"lane_fan":
			_check_equal(String(motion.get("kind", "")), "lane_fan", "Lane-fan motion kind drifted.")
			_check(typeof(motion.get("aim_locked")) == TYPE_BOOL and bool(motion.aim_locked), "Fixture lane fan did not preserve its explicit aim lock.")
		"rhythm_pulse":
			var turn_rate := float(motion.get("turn_rate", 0.0))
			_check_equal(String(motion.get("kind", "")), "curve", "Rhythm-pulse motion kind drifted.")
			_check(not is_zero_approx(turn_rate) and not is_nan(turn_rate) and not is_inf(turn_rate), "Rhythm-pulse curve rate is malformed.")
			_check(int(motion.get("pulse_index", -1)) >= 0, "Rhythm-pulse index is malformed.")
		"delayed_seed":
			var delay_ticks := int(motion.get("delay_ticks", 0))
			var launch_velocity_value = motion.get("launch_velocity", null)
			_check_equal(String(motion.get("kind", "")), "delayed_aim", "Delayed-seed motion kind drifted.")
			_check_equal(spec.velocity, Vector2.ZERO, "Delayed seed must begin inert.")
			_check(delay_ticks > 0 and delay_ticks < int(spec.lifetime), "Delayed seed cannot activate within its lifetime.")
			_check(is_equal_approx(float(motion.get("trigger_age", -1.0)), float(delay_ticks)), "Delayed seed trigger tick drifted from authored delay.")
			_check(launch_velocity_value is Vector2, "Delayed seed launch velocity type is malformed.")
			if launch_velocity_value is Vector2:
				var launch_velocity: Vector2 = launch_velocity_value
				_check(launch_velocity.length() > 0.0 and is_equal_approx(float(motion.get("target_speed", -1.0)), launch_velocity.length()), "Delayed seed launch velocity/speed are incoherent.")
				_check(is_equal_approx(float(motion.get("heading", 999.0)), launch_velocity.angle()), "Delayed seed heading does not encode the locked launch direction.")
			_check(not bool(motion.get("aim_on_trigger", true)), "Delayed seed would re-read player aim at activation.")

func _assert_pattern_determinism() -> void:
	var phase := _phase_fixture()
	var positions := _player_positions(90)
	var first := DanmakuPatternRuntime.new()
	var second := DanmakuPatternRuntime.new()
	_check(first.configure(phase, "normal", 20260715), "Normal fixture was rejected: %s" % [first.validation_errors()])
	_check(second.configure(phase, "normal", 20260715), "Repeated Normal fixture was rejected.")
	var first_trace := _advance_trace(first, 60, positions)
	var second_trace := _advance_trace(second, 60, positions)
	_check_equal(first_trace, second_trace, "Same phase seed and deterministic player inputs diverged.")
	_check_equal(first.telemetry_snapshot(), second.telemetry_snapshot(), "Same deterministic trace produced different telemetry.")

	var other_seed := DanmakuPatternRuntime.new()
	_check(other_seed.configure(phase, "normal", 20260716), "Different-seed fixture was rejected.")
	var other_trace := _advance_trace(other_seed, 60, positions)
	_check(first_trace != other_trace, "Changing the run seed did not change randomized bullet structure.")
	_check(first.telemetry_snapshot().phase_seed != other_seed.telemetry_snapshot().phase_seed, "Distinct run seeds derived the same phase-local seed.")

	var hard := DanmakuPatternRuntime.new()
	_check(hard.configure(phase, "hard", 20260715), "Hard fixture was rejected: %s" % [hard.validation_errors()])
	var hard_trace := _advance_trace(hard, 60, positions)
	_check(first.telemetry_snapshot().topology_id != hard.telemetry_snapshot().topology_id, "Normal and Hard topology IDs did not differ.")
	_check(first.telemetry_snapshot().topology_signature != hard.telemetry_snapshot().topology_signature, "Normal and Hard structural signatures did not differ.")
	_check(first_trace != hard_trace, "Hard topology did not alter emitted structure.")

	var seen_primitives := {}
	var seen_motion := {}
	var warning_count := 0
	var timeline_count := 0
	var movement_count := 0
	var aim_lock_ticks: Array[int] = []
	for output_value in first_trace:
		var output: Dictionary = output_value
		warning_count += output.warnings.size()
		movement_count += output.boss_movements.size()
		for event_value in output.events:
			var event: Dictionary = event_value
			if String(event.get("source", "")) == "timeline":
				timeline_count += 1
			if String(event.get("kind", "")) == "aim_lock":
				aim_lock_ticks.append(int(event.loop_tick))
		for spec_value in output.bullet_specs:
			var spec: Dictionary = spec_value
			_assert_motion_contract(spec)
			seen_primitives[String(spec.primitive)] = true
			seen_motion[String(spec.motion.get("kind", ""))] = true
			for key in ["position", "velocity", "radius", "color", "family_id", "lifetime", "motion", "emitter_id", "topology_id"]:
				_check(spec.has(key), "Bullet spec omitted required key %s." % key)
			if String(spec.primitive) == "delayed_seed":
				_check_equal(spec.velocity, Vector2.ZERO, "Delayed seed must remain inert until its encoded launch tick.")
				_check(spec.motion.get("launch_velocity") is Vector2, "Delayed seed omitted encoded launch velocity.")
				_check(not bool(spec.motion.get("aim_on_trigger", true)), "Delayed seed attempted to re-read player aim at activation.")
	_check_equal(seen_primitives.keys().size(), 5, "The fixture did not execute all five permitted primitives.")
	for primitive in DanmakuPatternRuntime.PERMITTED_PRIMITIVES:
		_check(seen_primitives.has(primitive), "Primitive %s produced no bullet specs." % primitive)
	for motion_kind in ["reflect", "linear_route", "lane_fan", "curve", "delayed_aim"]:
		_check(seen_motion.has(motion_kind), "Motion encoding %s was not exercised." % motion_kind)
	_check(warning_count > 0, "No stable warning records were emitted.")
	_check_equal(timeline_count, 4, "The ordered four-record timeline was not emitted once in one loop.")
	_check_equal(movement_count, 3, "The ordered three-record Boss movement trace was not emitted once in one loop.")
	_check_equal(aim_lock_ticks, [20, 38], "Player aim was not committed only at explicit lock ticks.")

	seed(123456789)
	var expected_global_first := randi()
	var expected_global_second := randi()
	seed(123456789)
	_check_equal(randi(), expected_global_first, "Global RNG boundary control did not reset deterministically.")
	var isolated := DanmakuPatternRuntime.new()
	isolated.configure(phase, "normal", 77)
	_advance_trace(isolated, 43, positions)
	_check_equal(randi(), expected_global_second, "Phase-local execution consumed the observable global/shared RNG sequence.")

func _assert_explicit_aim_lock() -> void:
	var phase := _phase_fixture()
	var first := DanmakuPatternRuntime.new()
	var second := DanmakuPatternRuntime.new()
	_check(first.configure(phase, "normal", 41) and second.configure(phase, "normal", 41), "Aim-lock fixture configuration failed.")
	var positions_a := _player_positions(25)
	var positions_b := positions_a.duplicate(true)
	positions_a[24] = Vector2(680.0, 900.0)
	positions_b[24] = Vector2(40.0, 500.0)
	var trace_a := _advance_trace(first, 25, positions_a)
	var trace_b := _advance_trace(second, 25, positions_b)
	_check_equal(trace_a[24].bullet_specs, trace_b[24].bullet_specs, "Player aim was re-read at fire time instead of the explicit lock tick.")

func _assert_pattern_snapshot_and_seek() -> void:
	var phase := _phase_fixture()
	var positions := _player_positions(90)
	var control := DanmakuPatternRuntime.new()
	_check(control.configure(phase, "hard", 9001), "Hard snapshot fixture configuration failed.")
	_advance_trace(control, 35, positions)
	var snapshot: Dictionary = control.capture_snapshot()
	_check(control.validate_snapshot(snapshot), "Runtime rejected its own snapshot.")
	var alias_source: Dictionary = snapshot.duplicate(true)
	var alias_target := DanmakuPatternRuntime.new()
	_check(alias_target.configure(phase, "hard", 9001) and alias_target.restore_snapshot(alias_source), "Pattern alias-safety target failed to restore.")
	var alias_baseline: Dictionary = alias_target.capture_snapshot()
	alias_source.locked_angles["hard_lane_branch"] = -999.0
	alias_source.emitter_counts["hard_rebound"] = 999999
	alias_source.rng.state = 1
	_check_equal(alias_target.capture_snapshot(), alias_baseline, "Pattern restore retained aliases into its source snapshot.")
	var exported_alias: Dictionary = alias_target.capture_snapshot()
	exported_alias.locked_angles.clear()
	exported_alias.emitter_counts.clear()
	_check_equal(alias_target.capture_snapshot(), alias_baseline, "Pattern capture exposed aliases into live state.")
	var expected_continuation := _advance_trace(control, 20, positions, 35)
	var expected_final := control.capture_snapshot()

	var restored := DanmakuPatternRuntime.new()
	_check(restored.configure(phase, "hard", 9001), "Restore target configuration failed.")
	_check(restored.restore_snapshot(snapshot), "Valid pattern snapshot restore failed.")
	var restored_continuation := _advance_trace(restored, 20, positions, 35)
	_check_equal(restored_continuation, expected_continuation, "Pattern continuation diverged after snapshot restore.")
	_check_equal(restored.capture_snapshot(), expected_final, "Pattern state diverged after restored continuation.")
	var before_rejection := restored.capture_snapshot()
	var malformed_snapshot := snapshot.duplicate(true)
	malformed_snapshot.version = 999
	_check(not restored.restore_snapshot(malformed_snapshot), "Pattern runtime accepted an unsupported snapshot version.")
	_check_equal(restored.capture_snapshot(), before_rejection, "Rejected snapshot partially mutated pattern state.")
	var missing_lock := snapshot.duplicate(true)
	missing_lock.locked_angles.erase("hard_lane_branch")
	_check(not restored.restore_snapshot(missing_lock), "Pattern runtime accepted a snapshot missing a committed aim lock.")
	_check_equal(restored.capture_snapshot(), before_rejection, "Missing-lock snapshot partially mutated pattern state.")

	var sequential := DanmakuPatternRuntime.new()
	var direct := DanmakuPatternRuntime.new()
	_check(sequential.configure(phase, "normal", 555) and direct.configure(phase, "normal", 555), "Seek fixtures failed to configure.")
	_advance_trace(sequential, 50, positions)
	var seek_result: Dictionary = direct.seek(50, positions)
	_check(bool(seek_result.get("ok", false)), "Direct pattern seek failed: %s" % seek_result.get("error", ""))
	_check_equal(direct.capture_snapshot(), sequential.capture_snapshot(), "Reset-and-replay seek did not equal sequential pattern state.")

	var sequential_snapshot: Dictionary = sequential.capture_snapshot()
	var reordered_phase: Dictionary = _reverse_dictionary_order(phase)
	var reordered_runtime := DanmakuPatternRuntime.new()
	_check(reordered_runtime.configure(reordered_phase, "normal", 555), "Equivalent reordered phase was rejected.")
	_check_equal(reordered_runtime.telemetry_snapshot().phase_signature, sequential.telemetry_snapshot().phase_signature, "Equivalent Dictionary insertion order changed phase_signature.")
	_check(reordered_runtime.restore_snapshot(sequential_snapshot), "Canonical phase signature rejected an equivalent reordered spec.")
	_check_equal(reordered_runtime.capture_snapshot(), sequential_snapshot, "Equivalent reordered phase did not restore identical state.")

	var semantic_phase := phase.duplicate(true)
	semantic_phase.timeline[0].tag = "semantically_changed"
	var semantic_runtime := DanmakuPatternRuntime.new()
	_check(semantic_runtime.configure(semantic_phase, "normal", 555), "Semantically changed but valid phase failed to configure.")
	_check(semantic_runtime.telemetry_snapshot().phase_signature != sequential.telemetry_snapshot().phase_signature, "Meaningful phase payload mutation did not change phase_signature.")
	var semantic_before: Dictionary = semantic_runtime.capture_snapshot()
	_check(not semantic_runtime.restore_snapshot(sequential_snapshot), "Cross-spec phase snapshot bypassed the canonical signature.")
	_check_equal(semantic_runtime.capture_snapshot(), semantic_before, "Rejected cross-spec phase snapshot partially mutated state.")

func _assert_pattern_rejections() -> void:
	var warning_violation := _phase_fixture()
	warning_violation.warning_ticks.normal = 11
	var warning_runtime := DanmakuPatternRuntime.new()
	_check(not warning_runtime.configure(warning_violation, "normal", 1), "Runtime accepted a phase warning below the Normal floor.")
	_check(warning_runtime.has_hard_error(), "Warning rejection was not exposed as a hard error.")

	var malformed := _phase_fixture()
	malformed.difficulties.normal.emitters[0].primitive = "unsupported_shape"
	var malformed_runtime := DanmakuPatternRuntime.new()
	_check(not malformed_runtime.configure(malformed, "normal", 1), "Runtime accepted an unsupported primitive.")
	_check(malformed_runtime.has_hard_error(), "Malformed emitter rejection was not fail-closed.")

	var overflow := _phase_fixture()
	overflow.difficulties.hard.emitters[0].shots_per_burst = DanmakuPatternRuntime.MAX_SHOTS_PER_BURST + 1
	var overflow_runtime := DanmakuPatternRuntime.new()
	_check(not overflow_runtime.configure(overflow, "hard", 1), "Runtime accepted an emitter above its declared shot cap.")
	_check(overflow_runtime.has_hard_error() and overflow_runtime.last_error().contains("cap"), "Overflow rejection did not expose hard cap evidence.")

	var topology_violation := _phase_fixture()
	topology_violation.difficulties.hard.topology_id = topology_violation.difficulties.normal.topology_id
	var topology_runtime := DanmakuPatternRuntime.new()
	_check(not topology_runtime.configure(topology_violation, "hard", 1), "Runtime accepted identical Normal/Hard topology IDs.")
	var numeric_topology := _phase_fixture()
	numeric_topology.difficulties.hard.topology_id = "2"
	var numeric_runtime := DanmakuPatternRuntime.new()
	_check(not numeric_runtime.configure(numeric_topology, "hard", 1), "Runtime accepted a numeric-only topology change.")
	var numeric_only_change := _phase_fixture()
	numeric_only_change.difficulties.hard.emitters = numeric_only_change.difficulties.normal.emitters.duplicate(true)
	for emitter_index in range(numeric_only_change.difficulties.hard.emitters.size()):
		var renamed_emitter: Dictionary = numeric_only_change.difficulties.hard.emitters[emitter_index]
		renamed_emitter.id = "renamed_hard_%d" % emitter_index
		renamed_emitter.speed = float(renamed_emitter.speed) + 0.25
		renamed_emitter.angle_degrees = float(renamed_emitter.angle_degrees) + 5.0
	var numeric_only_runtime := DanmakuPatternRuntime.new()
	_check(not numeric_only_runtime.configure(numeric_only_change, "hard", 1), "Runtime accepted a Hard profile that changed only labels and numeric tuning.")

	var structural_change := numeric_only_change.duplicate(true)
	structural_change.difficulties.hard.emitters[1].routing = "right"
	var structural_runtime := DanmakuPatternRuntime.new()
	_check(structural_runtime.configure(structural_change, "hard", 1), "Runtime rejected a real grid-route topology change: %s" % [structural_runtime.validation_errors()])

	var invalid_bounds := _phase_fixture()
	invalid_bounds.difficulties.normal.emitters[0].reflection.bounds = Rect2(24.0, 48.0, -1.0, 888.0)
	var bounds_runtime := DanmakuPatternRuntime.new()
	_check(not bounds_runtime.configure(invalid_bounds, "normal", 1), "Runtime accepted malformed optional reflection bounds.")
	var omitted_bounds := _phase_fixture()
	omitted_bounds.difficulties.normal.emitters[0].reflection.erase("bounds")
	omitted_bounds.difficulties.hard.emitters[0].reflection.erase("bounds")
	var omitted_bounds_runtime := DanmakuPatternRuntime.new()
	_check(omitted_bounds_runtime.configure(omitted_bounds, "normal", 1), "Runtime rejected omitted optional reflection bounds.")
	var omitted_bounds_trace := _advance_trace(omitted_bounds_runtime, 13, _player_positions(13))
	var saw_default_bounds := false
	for spec_value in omitted_bounds_trace[12].bullet_specs:
		var spec: Dictionary = spec_value
		if String(spec.primitive) == "rebound_bead":
			saw_default_bounds = spec.motion.get("bounds") is Rect2 and spec.motion.bounds.size.x > 0.0 and spec.motion.bounds.size.y > 0.0
	_check(saw_default_bounds, "Omitted reflection bounds did not resolve to a valid deterministic default.")
	var never_activates := _phase_fixture()
	never_activates.difficulties.normal.emitters[4].delay_ticks = int(never_activates.difficulties.normal.emitters[4].lifetime_ticks)
	var delayed_runtime := DanmakuPatternRuntime.new()
	_check(not delayed_runtime.configure(never_activates, "normal", 1), "Runtime accepted a delayed seed that cannot activate before expiry.")
	var unbound_schema_data := _phase_fixture()
	unbound_schema_data["unbound_extra"] = {"value": 1}
	var unbound_runtime := DanmakuPatternRuntime.new()
	_check(not unbound_runtime.configure(unbound_schema_data, "normal", 1), "Runtime accepted data outside the bound phase schema.")

func _stage_fixture() -> Dictionary:
	var events: Array = []
	for index in range(18):
		var event := {
			"id": "stage_event_%02d" % (index + 1),
			"tick": index * 2,
			"kind": "wave" if index not in [5, 14] else "encounter_gate",
			"encounter_role": "stage",
			"phase_cursor": index,
			"payload": {"route": "route_%02d" % (index + 1), "flags": [true, index % 2 == 0]},
		}
		if index == 5:
			event["id"] = "midboss_gate"
			event["gate"] = {"encounter_role": "midboss", "phase_cursor": 0, "completion_token": "midboss-cleared"}
		elif index == 14:
			event["id"] = "boss_gate"
			event["gate"] = {"encounter_role": "boss", "phase_cursor": 0, "completion_token": "boss-cleared"}
		events.append(event)
	return {"stage_id": "m2_fixture_stage", "events": events}

func _assert_stage_restore_rejected_unchanged(runtime, forged: Dictionary, baseline: Dictionary, message: String) -> void:
	_check(not runtime.restore_snapshot(forged), message)
	_check_equal(runtime.capture_snapshot(), baseline, "%s Rejection partially mutated stage state." % message)

func _assert_stage_snapshot_guards(stage: Dictionary, paused_snapshot: Dictionary) -> void:
	var guarded := StageEncounterRuntime.new()
	_check(guarded.configure(stage) and guarded.restore_snapshot(paused_snapshot), "Stage snapshot-guard fixture failed to restore.")
	var guarded_baseline: Dictionary = guarded.capture_snapshot()

	var gate_bypass := paused_snapshot.duplicate(true)
	gate_bypass.paused = false
	gate_bypass.active_gate = {}
	gate_bypass.completed_gate_ids = []
	_assert_stage_restore_rejected_unchanged(guarded, gate_bypass, guarded_baseline, "Snapshot crossed an emitted gate without its token.")
	var completed_source := StageEncounterRuntime.new()
	_check(completed_source.configure(stage) and completed_source.restore_snapshot(paused_snapshot), "Completed-gate snapshot fixture failed to restore.")
	_check(completed_source.complete_gate("midboss-cleared"), "Completed-gate snapshot fixture rejected the exact token.")
	var completed_snapshot: Dictionary = completed_source.capture_snapshot()
	var completed_target := StageEncounterRuntime.new()
	_check(completed_target.configure(stage) and completed_target.restore_snapshot(completed_snapshot), "Reachable non-paused completed-gate snapshot was rejected.")
	var completed_baseline: Dictionary = completed_target.capture_snapshot()
	var removed_completion := completed_snapshot.duplicate(true)
	removed_completion.completed_gate_ids.clear()
	_assert_stage_restore_rejected_unchanged(completed_target, removed_completion, completed_baseline, "Non-paused snapshot omitted an emitted gate completion.")

	var forged_tick := paused_snapshot.duplicate(true)
	forged_tick.stage_tick = int(forged_tick.stage_tick) + 1
	_assert_stage_restore_rejected_unchanged(guarded, forged_tick, guarded_baseline, "Snapshot advanced stage_tick through an active gate.")

	var forged_cursor := paused_snapshot.duplicate(true)
	var forged_index := int(forged_cursor.next_event_index)
	forged_cursor.next_event_index = forged_index + 1
	forged_cursor.event_count = forged_index + 1
	forged_cursor.emitted_event_ids.append(String(stage.events[forged_index].id))
	_assert_stage_restore_rejected_unchanged(guarded, forged_cursor, guarded_baseline, "Snapshot forged an unreachable emitted-event cursor.")

	var forged_role := paused_snapshot.duplicate(true)
	forged_role.encounter_role = "boss"
	forged_role.phase_cursor = 99
	_assert_stage_restore_rejected_unchanged(guarded, forged_role, guarded_baseline, "Snapshot forged encounter role/phase cursor state.")

	var forged_gate := paused_snapshot.duplicate(true)
	forged_gate.active_gate.completion_token = "forged-token"
	_assert_stage_restore_rejected_unchanged(guarded, forged_gate, guarded_baseline, "Snapshot forged active-gate identity/token data.")

	var forged_completion := paused_snapshot.duplicate(true)
	forged_completion.completed_gate_ids = ["boss_gate"]
	_assert_stage_restore_rejected_unchanged(guarded, forged_completion, guarded_baseline, "Snapshot forged gate completion order.")

	var forged_signature := paused_snapshot.duplicate(true)
	forged_signature.event_signature = "forged-signature"
	_assert_stage_restore_rejected_unchanged(guarded, forged_signature, guarded_baseline, "Snapshot forged its event specification signature.")

	var reordered_stage: Dictionary = _reverse_dictionary_order(stage)
	var reordered := StageEncounterRuntime.new()
	_check(reordered.configure(reordered_stage), "Equivalent reordered stage spec was rejected.")
	_check_equal(reordered.telemetry_snapshot().event_signature, guarded.telemetry_snapshot().event_signature, "Equivalent event Dictionary order changed event_signature.")
	_check(reordered.restore_snapshot(paused_snapshot), "Canonical event signature rejected an equivalent reordered stage spec.")

	var semantic_stage := stage.duplicate(true)
	semantic_stage.events[0].payload.route = "semantically_changed"
	var semantic := StageEncounterRuntime.new()
	_check(semantic.configure(semantic_stage), "Semantically changed stage fixture failed to configure.")
	_check(semantic.telemetry_snapshot().event_signature != guarded.telemetry_snapshot().event_signature, "Complete event payload mutation did not change event_signature.")
	var semantic_baseline: Dictionary = semantic.capture_snapshot()
	_assert_stage_restore_rejected_unchanged(semantic, paused_snapshot, semantic_baseline, "Cross-spec stage snapshot bypassed complete event signature binding.")

	var alias_source := paused_snapshot.duplicate(true)
	var alias_target := StageEncounterRuntime.new()
	_check(alias_target.configure(stage) and alias_target.restore_snapshot(alias_source), "Stage restore alias fixture failed.")
	var alias_baseline: Dictionary = alias_target.capture_snapshot()
	alias_source.emitted_event_ids[0] = "mutated-source"
	alias_source.active_gate.completion_token = "mutated-source-token"
	alias_source.completed_gate_ids.append("mutated-source-gate")
	_check_equal(alias_target.capture_snapshot(), alias_baseline, "Stage restore retained aliases into its source snapshot.")
	var exported_snapshot: Dictionary = alias_target.capture_snapshot()
	exported_snapshot.emitted_event_ids.clear()
	exported_snapshot.active_gate.clear()
	exported_snapshot.completed_gate_ids.append("mutated-export")
	_check_equal(alias_target.capture_snapshot(), alias_baseline, "Stage capture exposed aliases into live state.")
	var exported_telemetry: Dictionary = alias_target.telemetry_snapshot()
	exported_telemetry.emitted_event_ids.clear()
	exported_telemetry.active_gate.clear()
	exported_telemetry.completed_gate_ids.append("mutated-telemetry")
	_check_equal(alias_target.capture_snapshot(), alias_baseline, "Stage telemetry exposed aliases into live state.")

func _assert_stage_runtime() -> void:
	var stage := _stage_fixture()
	var runtime := StageEncounterRuntime.new()
	_check(runtime.configure(stage), "Valid 18-event stage fixture was rejected: %s" % [runtime.validation_errors()])
	var emitted_ids: Array[String] = []
	var checked_paused_restore := false
	while runtime.telemetry_snapshot().stage_tick < 36:
		if bool(runtime.telemetry_snapshot().paused):
			var paused_before: Dictionary = runtime.telemetry_snapshot()
			var paused_output: Dictionary = runtime.advance()
			_check(bool(paused_output.ok) and bool(paused_output.paused) and paused_output.events.is_empty(), "A paused gate emitted events.")
			_check_equal(runtime.telemetry_snapshot().stage_tick, paused_before.stage_tick, "Stage tick advanced while an encounter gate was paused.")
			_check(not runtime.complete_gate("wrong-token"), "Gate resumed with a mismatched completion token.")
			_check_equal(runtime.telemetry_snapshot(), paused_before, "Mismatched gate token mutated encounter state.")
			if not checked_paused_restore:
				var paused_snapshot: Dictionary = runtime.capture_snapshot()
				var restored := StageEncounterRuntime.new()
				_check(restored.configure(stage), "Paused restore target failed to configure.")
				_check(restored.restore_snapshot(paused_snapshot), "Paused encounter snapshot restore failed.")
				_check_equal(restored.telemetry_snapshot(), runtime.telemetry_snapshot(), "Paused encounter telemetry changed across restore.")
				_assert_stage_snapshot_guards(stage, paused_snapshot)
				checked_paused_restore = true
			var gate_id := String(runtime.telemetry_snapshot().active_gate.event_id)
			var token := "midboss-cleared" if gate_id == "midboss_gate" else "boss-cleared"
			_check(runtime.complete_gate(token), "Gate did not resume with its matching completion token.")
			continue
		var output: Dictionary = runtime.advance()
		_check(bool(output.get("ok", false)), "Stage advance failed: %s" % output.get("error", ""))
		_check(typeof(output.get("tick")) == TYPE_INT, "Stage runtime emitted a non-integer tick.")
		for event_value in output.events:
			emitted_ids.append(String(event_value.id))
	_check_equal(emitted_ids.size(), 18, "Stage runtime did not emit all 18 due events.")
	var unique_ids := {}
	for event_id in emitted_ids:
		_check(not unique_ids.has(event_id), "Stage event %s was emitted more than once." % event_id)
		unique_ids[event_id] = true
	_check_equal(unique_ids.size(), 18, "Stage event identities were not unique.")
	_check_equal(runtime.telemetry_snapshot().encounter_role, "stage", "Encounter role cursor did not follow the post-gate stage events.")
	_check_equal(runtime.telemetry_snapshot().phase_cursor, 17, "Phase cursor did not preserve the final emitted event cursor.")
	_check_equal(runtime.telemetry_snapshot().completed_gate_ids, ["midboss_gate", "boss_gate"], "Matching gate completions were not preserved in order.")
	var final_baseline: Dictionary = runtime.capture_snapshot()
	var reversed_completions := final_baseline.duplicate(true)
	reversed_completions.completed_gate_ids.reverse()
	_assert_stage_restore_rejected_unchanged(runtime, reversed_completions, final_baseline, "Final snapshot reordered completed gates.")

	var direct := StageEncounterRuntime.new()
	_check(direct.configure(stage), "Direct stage seek target failed to configure.")
	var seek_result: Dictionary = direct.seek(36, {"midboss_gate": "midboss-cleared", "boss_gate": "boss-cleared"})
	_check(bool(seek_result.get("ok", false)), "Direct stage seek failed: %s" % seek_result.get("error", ""))
	_check_equal(direct.capture_snapshot(), runtime.capture_snapshot(), "Direct stage seek did not equal sequential gate-aware state.")

	var missing_token := StageEncounterRuntime.new()
	_check(missing_token.configure(stage), "Missing-token seek fixture failed to configure.")
	var missing_result: Dictionary = missing_token.seek(36)
	_check(not bool(missing_result.get("ok", true)) and bool(missing_token.telemetry_snapshot().paused), "Stage seek crossed an explicit gate without a matching token.")

func _assert_stage_rejections() -> void:
	var wrong_count := _stage_fixture()
	wrong_count.events.pop_back()
	var wrong_count_runtime := StageEncounterRuntime.new()
	_check(not wrong_count_runtime.configure(wrong_count), "Stage runtime accepted fewer than 18 events.")
	_check(wrong_count_runtime.has_hard_error(), "Malformed stage count was not fail-closed.")

	var duplicate := _stage_fixture()
	duplicate.events[1].id = duplicate.events[0].id
	var duplicate_runtime := StageEncounterRuntime.new()
	_check(not duplicate_runtime.configure(duplicate), "Stage runtime accepted duplicate event IDs.")

	var overflow := _stage_fixture()
	for event in overflow.events:
		event.tick = 0
	var overflow_runtime := StageEncounterRuntime.new()
	_check(not overflow_runtime.configure(overflow), "Stage runtime accepted more than its event-per-tick cap.")
	_check(overflow_runtime.has_hard_error() and overflow_runtime.last_error().contains("cap"), "Stage overflow did not expose hard cap evidence.")

func _run() -> void:
	_check_equal(DanmakuPatternRuntime.TICKS_PER_SECOND, 60, "Pattern runtime tick frequency drifted.")
	_assert_pattern_determinism()
	_assert_explicit_aim_lock()
	_assert_pattern_snapshot_and_seek()
	_assert_pattern_rejections()
	_assert_stage_runtime()
	_assert_stage_rejections()
	if failed:
		quit(1)
	else:
		print("PASS: M2 deterministic pattern primitives, explicit aim locks, snapshots/seeks, stage gates, and fail-closed caps.")
		quit(0)

func _initialize() -> void:
	call_deferred("_run")
