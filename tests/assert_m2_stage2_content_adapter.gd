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
		_assert_malformed_rejection(adapter)
	if failed:
		quit(1)
	else:
		print("PASS: Stage 2 choreography adapter projects strict runtime specs, gates, topology, and fail-closed content.")
		quit(0)

func _assert_stage(adapter) -> void:
	var stage: Dictionary = adapter.stage_spec()
	var expected_ids := ["s2_b01", "s2_b02", "s2_b03", "s2_b04", "s2_b05", "s2_b06", "s2_b07", "s2_b08", "s2_b09", "s2_b10", "s2_b11", "s2_b12", "s2_b13", "s2_b14", "s2_b15", "s2_b16", "s2_b17", "s2_b18"]
	var expected_ticks := [0, 150, 300, 450, 600, 750, 751, 751, 751, 751, 751, 751, 901, 1051, 1201, 1351, 1501, 1651]
	_check_equal(stage.events.size(), 18, "Stage spec event count changed.")
	for index in range(expected_ids.size()):
		_check_equal(String(stage.events[index].id), expected_ids[index], "Stage event ID order changed.")
		_check_equal(int(stage.events[index].tick), expected_ticks[index], "Stage event runtime tick changed.")
	var runtime := StageEncounterRuntime.new()
	_check(runtime.configure(stage), "Strict StageEncounterRuntime rejected the adapter spec: %s" % runtime.validation_errors())
	if not runtime.is_configured():
		return
	var gate_output: Dictionary = {}
	for _tick in range(751):
		gate_output = runtime.advance()
	_check_equal(String(gate_output.events[0].id), "s2_b06", "Midboss gate did not occur at tick 750.")
	_check(bool(gate_output.paused), "Midboss gate did not pause StageEncounterRuntime.")
	_check_equal(String(gate_output.active_gate.completion_token), "stage2_midboss_cleared", "Midboss completion token drifted.")
	_check(runtime.complete_gate("stage2_midboss_cleared"), "Midboss gate rejected its unique completion token.")
	var collapsed: Dictionary = runtime.advance()
	var collapsed_ids: Array[String] = []
	for value in collapsed.events:
		collapsed_ids.append(String((value as Dictionary).id))
	_check_equal(collapsed_ids, ["s2_b07", "s2_b08", "s2_b09", "s2_b10", "s2_b11", "s2_b12"], "Gate collapse did not emit the six authored records together.")
	_check(not bool(collapsed.paused), "Collapsed encounter evidence incorrectly opened another gate.")
	for value in collapsed.events.slice(0, 5):
		_check_equal(String((value as Dictionary).payload.dispatch_scope), "encounter_evidence", "Midboss evidence lost its dispatch scope.")
	_check_equal(String((collapsed.events[5] as Dictionary).payload.dispatch_scope), "stage_resume", "s2_b12 did not resume ordinary Stage 2 content.")
	var boss_token := ""
	while runtime.telemetry_snapshot().stage_tick <= 1651 and boss_token.is_empty():
		var output: Dictionary = runtime.advance()
		if bool(output.paused):
			boss_token = String(output.active_gate.completion_token)
	_check_equal(boss_token, "stage2_boss_cleared", "Boss gate/token were not reachable after the authored 150-tick gap.")
	var metadata: Dictionary = adapter.content_metadata()
	_check_equal(metadata.phase_sequences.midboss, ["stage_2_midboss_nonspell_1", "stage_2_midboss_spell_1"], "Midboss phase sequence drifted.")
	_check_equal(metadata.phase_sequences.boss, ["stage_2_boss_nonspell_1", "stage_2_boss_spell_1", "stage_2_boss_spell_2", "stage_2_boss_spell_3"], "Boss phase sequence drifted.")

func _assert_phases(adapter) -> void:
	for phase in adapter.phase_specs():
		var phase_spec: Dictionary = phase
		_check(phase_spec.difficulties.normal.topology_id != phase_spec.difficulties.hard.topology_id, "Phase %s lost its authored topology IDs." % phase_spec.id)
		for difficulty in ["normal", "hard"]:
			var runtime := DanmakuPatternRuntime.new()
			_check(runtime.configure(phase_spec, difficulty, 20260715), "Strict DanmakuPatternRuntime rejected %s %s: %s" % [phase_spec.id, difficulty, runtime.validation_errors()])
			if not runtime.is_configured():
				continue
			var saw_warning := false
			var saw_bullet := false
			for _tick in range(int(phase_spec.loop_ticks)):
				var output: Dictionary = runtime.advance(Vector2(360.0, 720.0))
				_check(bool(output.ok), "Pattern runtime hard-failed while exercising %s %s." % [phase_spec.id, difficulty])
				saw_warning = saw_warning or not output.warnings.is_empty()
				saw_bullet = saw_bullet or not output.bullet_specs.is_empty()
				if saw_warning and saw_bullet:
					break
			_check(saw_warning and saw_bullet, "Phase %s %s did not emit both warning and bullet records." % [phase_spec.id, difficulty])

func _assert_deep_copy_isolation(adapter) -> void:
	var stage: Dictionary = adapter.stage_spec()
	stage.events[0].payload.authored_tick = -1
	_check_equal(int(adapter.stage_spec().events[0].payload.authored_tick), 0, "Stage output retained caller aliases.")
	var phase: Dictionary = adapter.phase_spec("stage_2_midboss_nonspell_1")
	phase.difficulties.normal.emitters[0].anchor = Vector2.ZERO
	_check(adapter.phase_spec("stage_2_midboss_nonspell_1").difficulties.normal.emitters[0].anchor != Vector2.ZERO, "Phase output retained caller aliases.")
	var metadata: Dictionary = adapter.content_metadata()
	metadata.event_metadata.s2_b07.source_event.warning.visual = "mutated"
	_check(String(adapter.content_metadata().event_metadata.s2_b07.source_event.warning.visual) != "mutated", "Metadata output retained caller aliases.")

func _assert_malformed_rejection(adapter) -> void:
	var malformed: Dictionary = adapter.source_content()
	malformed.phases[0].difficulties.normal.emitters[0].anchor = "unknown_anchor"
	var rejected := Stage2ContentAdapter.new()
	_check(not rejected.configure_from_content(malformed), "Malformed choreography did not fail closed.")
	_check(not rejected.validation_errors().is_empty() and rejected.stage_spec().is_empty() and rejected.phase_specs().is_empty(), "Malformed choreography exposed partial runtime output.")

func _initialize() -> void:
	call_deferred("_run")
