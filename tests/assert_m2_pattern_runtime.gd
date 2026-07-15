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
			"reflection": {"axes": "y" if not hard else "xy", "max_reflections": 1 if not hard else 2},
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

func _advance_trace(runtime, tick_count: int, positions: Dictionary, from_tick: int = 0) -> Array:
	var result: Array = []
	for offset in range(tick_count):
		var tick := from_tick + offset
		var output: Dictionary = runtime.advance(positions.get(tick, Vector2.ZERO))
		_check(bool(output.get("ok", false)), "Pattern advance failed at tick %d: %s" % [tick, output.get("error", "")])
		result.append(output)
	return result

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

	var shared := RandomNumberGenerator.new()
	var control := RandomNumberGenerator.new()
	shared.seed = 123456789
	control.seed = 123456789
	_check_equal(shared.randi(), control.randi(), "Shared RNG controls did not begin equally.")
	var isolated := DanmakuPatternRuntime.new()
	isolated.configure(phase, "normal", 77)
	_advance_trace(isolated, 43, positions)
	_check_equal(shared.randi(), control.randi(), "Phase-local execution consumed an unrelated gameplay RNG stream.")

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
	numeric_only_change.difficulties.hard.emitters[0].speed = float(numeric_only_change.difficulties.hard.emitters[0].speed) + 1.0
	var numeric_only_runtime := DanmakuPatternRuntime.new()
	_check(not numeric_only_runtime.configure(numeric_only_change, "hard", 1), "Runtime accepted a Hard profile that changed only numeric tuning.")

func _stage_fixture() -> Dictionary:
	var events: Array = []
	for index in range(18):
		var event := {
			"id": "stage_event_%02d" % (index + 1),
			"tick": index * 2,
			"kind": "wave" if index not in [5, 14] else "encounter_gate",
			"encounter_role": "stage",
			"phase_cursor": index,
		}
		if index == 5:
			event["id"] = "midboss_gate"
			event["gate"] = {"encounter_role": "midboss", "phase_cursor": 0, "completion_token": "midboss-cleared"}
		elif index == 14:
			event["id"] = "boss_gate"
			event["gate"] = {"encounter_role": "boss", "phase_cursor": 0, "completion_token": "boss-cleared"}
		events.append(event)
	return {"stage_id": "m2_fixture_stage", "events": events}

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
				checked_paused_restore = true
			var gate_id := String(runtime.telemetry_snapshot().active_gate.event_id)
			var token := "midboss-cleared" if gate_id == "midboss_gate" else "boss-cleared"
			_check(runtime.complete_gate(token), "Gate did not resume with its matching completion token.")
			continue
		var output: Dictionary = runtime.advance()
		_check(bool(output.get("ok", false)), "Stage advance failed: %s" % output.get("error", ""))
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
