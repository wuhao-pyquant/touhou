extends SceneTree

const Stage2ContentAdapter := preload("res://scripts/content/stage2_content_adapter.gd")
const StageEncounterRuntime := preload("res://scripts/runtime/stage_encounter_runtime.gd")
const DanmakuPatternRuntime := preload("res://scripts/runtime/danmaku_pattern_runtime.gd")

var failed := false

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func _check_equal(actual: Variant, expected: Variant, message: String) -> void:
	_check(actual == expected, "%s Expected %s, got %s." % [message, expected, actual])

func _run() -> void:
	var adapter := Stage2ContentAdapter.new()
	_check(adapter.load_artifact(), "Real Stage 2 choreography did not load: %s" % adapter.validation_errors())
	if adapter.is_valid():
		_assert_stage(adapter)
		_assert_phases(adapter)
		_assert_deep_copy_isolation(adapter)
		_assert_malformed_rejections(adapter)
	else:
		failed = true
	if failed:
		quit(1)
	else:
		print("PASS: Stage 2 adapter projects strict runtime specs, guarded gates, authored topology, and fail-closed content.")
		quit(0)

func _assert_stage(adapter) -> void:
	var stage: Dictionary = adapter.stage_spec()
	var expected_ids := ["s2_b01", "s2_b02", "s2_b03", "s2_b04", "s2_b05", "s2_b06", "s2_b07", "s2_b08", "s2_b09", "s2_b10", "s2_b11", "s2_b12", "s2_b13", "s2_b14", "s2_b15", "s2_b16", "s2_b17", "s2_b18"]
	var expected_ticks := [0, 150, 300, 450, 600, 750, 751, 751, 751, 751, 751, 751, 901, 1051, 1201, 1351, 1501, 1651]
	if not (stage.get("events") is Array) or stage.events.size() != 18:
		_check(false, "Stage spec must contain exactly 18 events.")
		return
	var gate_count := 0
	for index in range(expected_ids.size()):
		if not (stage.events[index] is Dictionary):
			_check(false, "Stage event %d is not a Dictionary." % index)
			continue
		var event: Dictionary = stage.events[index]
		_check_equal(String(event.get("id", "")), expected_ids[index], "Stage event ID order changed.")
		_check(typeof(event.get("tick")) == TYPE_INT, "Projected event %s tick is not integral." % expected_ids[index])
		_check_equal(int(event.get("tick", -1)), expected_ticks[index], "Stage event runtime tick changed.")
		_check_equal(int(event.get("phase_cursor", -1)), index, "Stage event phase cursor changed.")
		var expected_role := "midboss" if index >= 6 and index <= 10 else "stage"
		_check_equal(String(event.get("encounter_role", "")), expected_role, "Stage event encounter ownership changed.")
		if event.has("gate"):
			gate_count += 1
	_check_equal(gate_count, 2, "Stage spec gate count changed.")
	var runtime := StageEncounterRuntime.new()
	if not runtime.configure(stage):
		_check(false, "Strict StageEncounterRuntime rejected the adapter spec: %s" % runtime.validation_errors())
		return
	var gate_output: Dictionary = {}
	for _tick in range(751):
		gate_output = runtime.advance()
		if not bool(gate_output.get("ok", false)):
			_check(false, "Stage runtime failed before the midboss gate: %s" % gate_output.get("error", ""))
			return
	if not (gate_output.get("events") is Array) or gate_output.events.size() != 1 or not (gate_output.events[0] is Dictionary) or not (gate_output.get("active_gate") is Dictionary):
		_check(false, "Midboss gate output shape is malformed.")
		return
	_check_equal(String((gate_output.events[0] as Dictionary).get("id", "")), "s2_b06", "Midboss gate did not occur at tick 750.")
	_check(bool(gate_output.get("paused", false)), "Midboss gate did not pause StageEncounterRuntime.")
	_check_equal(String(gate_output.active_gate.get("completion_token", "")), "stage2_midboss_cleared", "Midboss completion token drifted.")
	if not runtime.complete_gate("stage2_midboss_cleared"):
		_check(false, "Midboss gate rejected its unique completion token.")
		return
	var collapsed: Dictionary = runtime.advance()
	if not bool(collapsed.get("ok", false)) or not (collapsed.get("events") is Array) or collapsed.events.size() != 6:
		_check(false, "Collapsed tick did not safely emit six records: %s" % collapsed)
		return
	var collapsed_ids: Array[String] = []
	for value in collapsed.events:
		if value is Dictionary:
			collapsed_ids.append(String((value as Dictionary).get("id", "")))
	_check_equal(collapsed_ids, ["s2_b07", "s2_b08", "s2_b09", "s2_b10", "s2_b11", "s2_b12"], "Gate collapse order changed.")
	_check_equal(int(collapsed.get("tick", -1)), 751, "Collapsed evidence did not emit at runtime tick 751.")
	_check(not bool(collapsed.get("paused", true)), "Collapsed encounter evidence opened another gate.")
	for index in range(5):
		if not (collapsed.events[index] is Dictionary) or not ((collapsed.events[index] as Dictionary).get("payload") is Dictionary):
			_check(false, "Collapsed evidence event %d has a malformed payload." % index)
			continue
		var evidence_event: Dictionary = collapsed.events[index]
		_check_equal(String(evidence_event.payload.get("dispatch_scope", "")), "encounter_evidence", "Midboss evidence lost its dispatch scope.")
	if not (collapsed.events[5] is Dictionary) or not ((collapsed.events[5] as Dictionary).get("payload") is Dictionary):
		_check(false, "s2_b12 collapsed output is malformed.")
		return
	_check_equal(String((collapsed.events[5] as Dictionary).payload.get("dispatch_scope", "")), "stage_resume", "s2_b12 did not resume ordinary content.")
	var next_event_output: Dictionary = {}
	for _step in range(150):
		var output: Dictionary = runtime.advance()
		if not bool(output.get("ok", false)):
			_check(false, "Stage runtime failed while checking the post-collapse gap.")
			return
		if output.get("events") is Array and not output.events.is_empty():
			next_event_output = output
			break
	if next_event_output.is_empty() or not (next_event_output.get("events") is Array) or next_event_output.events.size() != 1 or not (next_event_output.events[0] is Dictionary):
		_check(false, "s2_b13 was not reachable within the exact 150-tick authored gap.")
		return
	_check_equal(int(next_event_output.get("tick", -1)), 901, "Post-collapse gap changed.")
	_check_equal(String((next_event_output.events[0] as Dictionary).get("id", "")), "s2_b13", "Wrong event followed collapsed content.")
	var boss_token := ""
	for _step in range(800):
		var output: Dictionary = runtime.advance()
		if not bool(output.get("ok", false)):
			_check(false, "Stage runtime failed before boss reachability.")
			break
		if bool(output.get("paused", false)) and output.get("active_gate") is Dictionary:
			boss_token = String(output.active_gate.get("completion_token", ""))
			break
	_check_equal(boss_token, "stage2_boss_cleared", "Boss gate/token were not reachable in the bounded advance.")
	var metadata: Dictionary = adapter.content_metadata()
	if not _has_metadata_shape(metadata):
		_check(false, "Adapter metadata shape is incomplete.")
		return
	_check_equal(metadata.phase_sequences.midboss, ["stage_2_midboss_nonspell_1", "stage_2_midboss_spell_1"], "Midboss phase sequence drifted.")
	_check_equal(metadata.phase_sequences.boss, ["stage_2_boss_nonspell_1", "stage_2_boss_spell_1", "stage_2_boss_spell_2", "stage_2_boss_spell_3"], "Boss phase sequence drifted.")
	_check_equal(int(metadata.event_metadata.s2_b07.authored_tick), 900, "Encounter evidence lost its authored tick.")
	_check_equal(String(metadata.event_metadata.s2_b07.encounter_role), "midboss", "Encounter evidence lost ownership.")
	if metadata.event_metadata.get("s2_b01") is Dictionary and metadata.event_metadata.s2_b01.source_event.get("spawns") is Array and not metadata.event_metadata.s2_b01.source_event.spawns.is_empty():
		_check_equal(metadata.event_metadata.s2_b01.source_event.spawns[0].drop_item_ids, ["point_small", "point_small"], "Deterministic drops were not retained in metadata.")
	else:
		_check(false, "Deterministic drop metadata is missing.")
	_check(not metadata.source_bindings.is_empty(), "Source bindings were not retained.")

func _assert_phases(adapter) -> void:
	var metadata: Dictionary = adapter.content_metadata()
	var clamped_emitters := {
		"s2_mb_ns1_n_odd_beads": 30,
		"s2_mb_sp1_n_rung_end_fans": 30,
		"s2_boss_ns1_n_blue_coins": 30,
		"s2_boss_sp1_n_exchange_bell": 30,
	}
	var observed_clamps := 0
	var phases: Array = adapter.phase_specs()
	_check_equal(phases.size(), 6, "Projected phase count changed.")
	for phase_value in phases:
		if not (phase_value is Dictionary):
			_check(false, "Projected phase is not a Dictionary.")
			continue
		var phase: Dictionary = phase_value
		if not (phase.get("difficulties") is Dictionary) or not (phase.difficulties.get("normal") is Dictionary) or not (phase.difficulties.get("hard") is Dictionary):
			_check(false, "Phase %s difficulty shape is incomplete." % phase.get("id", ""))
			continue
		var phase_id := String(phase.id)
		var phase_meta: Dictionary = metadata.phase_metadata.get(phase_id, {})
		_check(not phase_meta.is_empty() and phase_meta.normal_route_graph != phase_meta.hard_route_graph, "Phase %s source route graphs do not prove structural divergence." % phase_id)
		_check(String(phase.difficulties.normal.topology_id) != String(phase.difficulties.hard.topology_id), "Phase %s topology IDs do not differ." % phase_id)
		if not phase.difficulties.normal.emitters.is_empty() and not phase.difficulties.hard.emitters.is_empty():
			var normal_first: Dictionary = phase.difficulties.normal.emitters[0]
			var hard_first: Dictionary = phase.difficulties.hard.emitters[0]
			_check(normal_first.get("reflection") is Dictionary and hard_first.get("reflection") is Dictionary and normal_first.reflection.axes != hard_first.reflection.axes, "Phase %s runtime topology shape is not derived into reflection structure." % phase_id)
		for difficulty in ["normal", "hard"]:
			var profile: Dictionary = phase.difficulties[difficulty]
			for emitter_value in profile.emitters:
				var emitter: Dictionary = emitter_value
				_check(typeof(emitter.start_tick) == TYPE_INT and typeof(emitter.interval_ticks) == TYPE_INT and typeof(emitter.bursts_per_loop) == TYPE_INT and typeof(emitter.shots_per_burst) == TYPE_INT and typeof(emitter.lifetime_ticks) == TYPE_INT, "Phase %s %s retained non-integral schedule Variants." % [phase_id, difficulty])
				if clamped_emitters.has(String(emitter.id)):
					observed_clamps += 1
					_check_equal(int(emitter.warning.lead_ticks), int(clamped_emitters[emitter.id]), "Emitter warning did not clamp to its phase floor.")
			var runtime := DanmakuPatternRuntime.new()
			if not runtime.configure(phase, difficulty, 20260715):
				_check(false, "Strict DanmakuPatternRuntime rejected %s %s: %s" % [phase_id, difficulty, runtime.validation_errors()])
				continue
			var saw_warning := false
			var saw_bullet := false
			for _tick in range(int(phase.loop_ticks)):
				var output: Dictionary = runtime.advance(Vector2(360.0, 720.0))
				if not bool(output.get("ok", false)):
					_check(false, "Pattern runtime hard-failed for %s %s: %s" % [phase_id, difficulty, output.get("error", "")])
					break
				saw_warning = saw_warning or (output.get("warnings") is Array and not output.warnings.is_empty())
				saw_bullet = saw_bullet or (output.get("bullet_specs") is Array and not output.bullet_specs.is_empty())
				if saw_warning and saw_bullet:
					break
			_check(saw_warning and saw_bullet, "Phase %s %s did not emit warning and bullet records." % [phase_id, difficulty])
	_check_equal(observed_clamps, 4, "The exact four authored Normal warning-floor clamps changed.")

func _assert_deep_copy_isolation(adapter) -> void:
	var stage: Dictionary = adapter.stage_spec()
	if stage.get("events") is Array and not stage.events.is_empty():
		stage.events[0].payload.authored_tick = -1
		_check_equal(int(adapter.stage_spec().events[0].payload.authored_tick), 0, "Stage output retained caller aliases.")
	var phase: Dictionary = adapter.phase_spec("stage_2_midboss_nonspell_1")
	if phase.get("difficulties") is Dictionary and not phase.difficulties.normal.emitters.is_empty():
		phase.difficulties.normal.emitters[0].anchor = Vector2.ZERO
		_check(adapter.phase_spec("stage_2_midboss_nonspell_1").difficulties.normal.emitters[0].anchor != Vector2.ZERO, "Phase output retained caller aliases.")
	var metadata: Dictionary = adapter.content_metadata()
	if _has_metadata_shape(metadata):
		metadata.event_metadata.s2_b07.source_event.warning.visual = "mutated"
		_check(String(adapter.content_metadata().event_metadata.s2_b07.source_event.warning.visual) != "mutated", "Metadata output retained caller aliases.")

func _assert_malformed_rejections(adapter) -> void:
	var cases := [
		"fractional_schema", "unknown_schema", "fractional_authored_tick", "string_authored_tick", "fractional_loop_tick",
		"fractional_schedule", "schedule_out_of_range", "fractional_warning_floor", "missing_phase_warning", "malformed_stage_warning", "malformed_spawn_vector",
		"malformed_spawn_movement", "malformed_emitter_color", "missing_emitter_warning",
		"nondictionary_spawn", "duplicate_spawn_id", "duplicate_emitter_id", "missing_route_graph",
		"empty_route_graph", "missing_phase_movement", "missing_phase_timeline", "malformed_rebound_routing", "delayed_out_of_range",
	]
	for case_name in cases:
		var malformed: Dictionary = adapter.source_content()
		_apply_malformed_mutation(malformed, case_name)
		var rejected := Stage2ContentAdapter.new()
		var accepted: bool = rejected.configure_from_content(malformed)
		_check(not accepted, "Malformed case %s did not fail closed." % case_name)
		_check(not rejected.validation_errors().is_empty() and rejected.stage_spec().is_empty() and rejected.phase_specs().is_empty(), "Malformed case %s exposed partial runtime output." % case_name)

func _apply_malformed_mutation(content: Dictionary, case_name: String) -> void:
	match case_name:
		"fractional_schema":
			content.schema_version = 1.5
		"unknown_schema":
			content.schema_version = 2
		"fractional_authored_tick":
			content.stage.events[0].authored_tick = 0.5
		"string_authored_tick":
			content.stage.events[0].authored_tick = "0"
		"fractional_loop_tick":
			content.phases[0].loop_ticks = 684.5
		"fractional_schedule":
			content.phases[0].difficulties.normal.emitters[0].start_tick = 66.5
		"schedule_out_of_range":
			content.phases[0].difficulties.normal.emitters[0].bursts_per_loop = 65
		"fractional_warning_floor":
			content.phases[0].warning_ticks.normal = 30.5
		"missing_phase_warning":
			content.phases[0].erase("warning_ticks")
		"malformed_stage_warning":
			content.stage.events[0].warning = "bad_warning"
		"malformed_spawn_vector":
			content.stage.events[0].spawns[0].position = [156]
		"malformed_spawn_movement":
			content.stage.events[0].spawns[0].movement.to = "bad_vector"
		"malformed_emitter_color":
			content.phases[0].difficulties.normal.emitters[0].color_rgba = [0.2, 0.8, 0.9]
		"missing_emitter_warning":
			content.phases[0].difficulties.normal.emitters[0].erase("warning")
		"nondictionary_spawn":
			content.stage.events[0].spawns[0] = "bad_spawn"
		"duplicate_spawn_id":
			content.stage.events[0].spawns[1].id = content.stage.events[0].spawns[0].id
		"duplicate_emitter_id":
			content.phases[0].difficulties.hard.emitters[0].id = content.phases[0].difficulties.normal.emitters[0].id
		"missing_route_graph":
			content.phases[0].difficulties.normal.erase("route_graph")
		"empty_route_graph":
			content.phases[0].difficulties.normal.route_graph.directed_edges = []
		"missing_phase_movement":
			content.phases[0].boss_movement = []
		"missing_phase_timeline":
			content.phases[0].timeline = []
		"malformed_rebound_routing":
			content.phases[0].difficulties.normal.emitters[0].routing.erase("max_reflections")
		"delayed_out_of_range":
			content.phases[4].difficulties.normal.emitters[1].routing.activation_delay_ticks = content.phases[4].difficulties.normal.emitters[1].lifetime_ticks

func _has_metadata_shape(metadata: Dictionary) -> bool:
	return (
		metadata.get("event_metadata") is Dictionary
		and metadata.event_metadata.get("s2_b07") is Dictionary
		and metadata.get("phase_metadata") is Dictionary
		and metadata.get("phase_sequences") is Dictionary
		and metadata.get("source_bindings") is Array
	)

func _initialize() -> void:
	call_deferred("_run")
