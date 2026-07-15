extends SceneTree

const Stage2ContentAdapter := preload("res://scripts/content/stage2_content_adapter.gd")
const StageEncounterRuntime := preload("res://scripts/runtime/stage_encounter_runtime.gd")
const DanmakuPatternRuntime := preload("res://scripts/runtime/danmaku_pattern_runtime.gd")

const REBOUND_EMITTER_IDS := {
	"stage_2_midboss_nonspell_1": ["s2_mb_ns1_n_odd_beads", "s2_mb_ns1_h_swap_beads"],
	"stage_2_midboss_spell_1": ["s2_mb_sp1_n_three_rung_beads", "s2_mb_sp1_h_side_booth_beads"],
	"stage_2_boss_nonspell_1": ["s2_boss_ns1_n_blue_coins", "s2_boss_ns1_h_rerouted_blue_coins"],
	"stage_2_boss_spell_1": ["s2_boss_sp1_n_coin_bubbles", "s2_boss_sp1_h_three_node_coins"],
	"stage_2_boss_spell_3": ["s2_boss_sp3_n_source_beads", "s2_boss_sp3_h_axis_source_beads"],
}
const GRID_EXPECTATIONS := {
	"stage_2_midboss_nonspell_1": ["s2_mb_ns1_n_lane_borders", "s2_mb_ns1_h_cross_borders", "down", "down"],
	"stage_2_boss_nonspell_1": ["s2_boss_ns1_n_booth_edges", "s2_boss_ns1_h_flipping_booth_edges", "down", "down"],
	"stage_2_boss_spell_2": ["s2_boss_sp2_n_inventory_edges", "s2_boss_sp2_h_dependency_edges", "right", "left"],
}
const LANE_FAN_EMITTER_IDS := ["s2_mb_sp1_n_rung_end_fans", "s2_mb_sp1_h_branch_end_fans"]
const RHYTHM_EMITTER_IDS := ["s2_boss_sp1_n_exchange_bell", "s2_boss_sp1_h_cycle_bell"]
const DELAYED_EMITTER_IDS := {
	"stage_2_boss_spell_2": ["s2_boss_sp2_n_route_markers", "s2_boss_sp2_h_rotated_route_markers"],
	"stage_2_boss_spell_3": ["s2_boss_sp3_n_mirror_copy", "s2_boss_sp3_h_axis_copy"],
}

var failed := false

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func _check_equal(actual: Variant, expected: Variant, message: String) -> void:
	_check(actual == expected, "%s Expected %s, got %s." % [message, expected, actual])

func _run() -> void:
	var adapter := Stage2ContentAdapter.new()
	if not adapter.load_artifact():
		_check(false, "Real Stage 2 choreography did not load: %s" % adapter.validation_errors())
		quit(1)
		return
	if not adapter.is_valid():
		_check(false, "Adapter did not publish a valid real-artifact projection.")
		quit(1)
		return
	_assert_stage(adapter)
	if failed:
		quit(1)
		return
	_assert_phases(adapter)
	if failed:
		quit(1)
		return
	_assert_deep_copy_isolation(adapter)
	if failed:
		quit(1)
		return
	_assert_malformed_rejections(adapter)
	if failed:
		quit(1)
		return
	print("PASS: Stage 2 adapter projects guarded runtime specs, authored topology, deep-copy isolation, and fail-closed content.")
	quit(0)

func _assert_stage(adapter) -> void:
	var stage: Dictionary = adapter.stage_spec()
	var events_value: Variant = stage.get("events")
	if not (events_value is Array):
		_check(false, "Stage spec events are not an Array.")
		return
	var events: Array = events_value
	if events.size() != 18:
		_check(false, "Stage spec must contain exactly 18 events.")
		return
	var expected_ids := ["s2_b01", "s2_b02", "s2_b03", "s2_b04", "s2_b05", "s2_b06", "s2_b07", "s2_b08", "s2_b09", "s2_b10", "s2_b11", "s2_b12", "s2_b13", "s2_b14", "s2_b15", "s2_b16", "s2_b17", "s2_b18"]
	var expected_ticks := [0, 150, 300, 450, 600, 750, 751, 751, 751, 751, 751, 751, 901, 1051, 1201, 1351, 1501, 1651]
	var gate_count := 0
	for index in range(expected_ids.size()):
		var event_value: Variant = events[index]
		if not (event_value is Dictionary):
			_check(false, "Stage event %d is not a Dictionary." % index)
			return
		var event: Dictionary = event_value
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
	var gate_events_value: Variant = gate_output.get("events")
	if not (gate_events_value is Array):
		_check(false, "Midboss gate events are not an Array.")
		return
	var gate_events: Array = gate_events_value
	if gate_events.size() != 1:
		_check(false, "Midboss gate output does not contain one event.")
		return
	var gate_event_value: Variant = gate_events[0]
	if not (gate_event_value is Dictionary):
		_check(false, "Midboss gate event is not a Dictionary.")
		return
	var gate_event: Dictionary = gate_event_value
	var active_gate_value: Variant = gate_output.get("active_gate")
	if not (active_gate_value is Dictionary):
		_check(false, "Midboss active_gate is not a Dictionary.")
		return
	var active_gate: Dictionary = active_gate_value
	_check_equal(String(gate_event.get("id", "")), "s2_b06", "Midboss gate did not occur at tick 750.")
	_check(bool(gate_output.get("paused", false)), "Midboss gate did not pause StageEncounterRuntime.")
	_check_equal(String(active_gate.get("completion_token", "")), "stage2_midboss_cleared", "Midboss completion token drifted.")
	if not runtime.complete_gate("stage2_midboss_cleared"):
		_check(false, "Midboss gate rejected its unique completion token.")
		return
	var collapsed: Dictionary = runtime.advance()
	if not bool(collapsed.get("ok", false)):
		_check(false, "Collapsed stage tick failed: %s" % collapsed.get("error", ""))
		return
	var collapsed_events_value: Variant = collapsed.get("events")
	if not (collapsed_events_value is Array):
		_check(false, "Collapsed events are not an Array.")
		return
	var collapsed_events: Array = collapsed_events_value
	if collapsed_events.size() != 6:
		_check(false, "Collapsed tick did not emit exactly six records.")
		return
	var collapsed_ids: Array[String] = []
	for index in range(collapsed_events.size()):
		var collapsed_event_value: Variant = collapsed_events[index]
		if not (collapsed_event_value is Dictionary):
			_check(false, "Collapsed event %d is not a Dictionary." % index)
			return
		var collapsed_event: Dictionary = collapsed_event_value
		collapsed_ids.append(String(collapsed_event.get("id", "")))
		var payload_value: Variant = collapsed_event.get("payload")
		if not (payload_value is Dictionary):
			_check(false, "Collapsed event %d payload is not a Dictionary." % index)
			return
		var payload: Dictionary = payload_value
		var expected_scope := "encounter_evidence" if index < 5 else "stage_resume"
		_check_equal(String(payload.get("dispatch_scope", "")), expected_scope, "Collapsed event dispatch scope changed.")
	_check_equal(collapsed_ids, ["s2_b07", "s2_b08", "s2_b09", "s2_b10", "s2_b11", "s2_b12"], "Gate collapse order changed.")
	_check_equal(int(collapsed.get("tick", -1)), 751, "Collapsed evidence did not emit at runtime tick 751.")
	_check(not bool(collapsed.get("paused", true)), "Collapsed encounter evidence opened another gate.")
	var next_event_output: Dictionary = {}
	for _step in range(150):
		var output: Dictionary = runtime.advance()
		if not bool(output.get("ok", false)):
			_check(false, "Stage runtime failed while checking the post-collapse gap.")
			return
		var output_events_value: Variant = output.get("events")
		if not (output_events_value is Array):
			_check(false, "Stage runtime events changed type during the post-collapse gap.")
			return
		var output_events: Array = output_events_value
		if not output_events.is_empty():
			next_event_output = output
			break
	if next_event_output.is_empty():
		_check(false, "s2_b13 was not reachable within the exact 150-tick authored gap.")
		return
	var next_events_value: Variant = next_event_output.get("events")
	if not (next_events_value is Array):
		_check(false, "s2_b13 output events are not an Array.")
		return
	var next_events: Array = next_events_value
	if next_events.size() != 1:
		_check(false, "s2_b13 output event count changed.")
		return
	var next_event_value: Variant = next_events[0]
	if not (next_event_value is Dictionary):
		_check(false, "s2_b13 output event is not a Dictionary.")
		return
	var next_event: Dictionary = next_event_value
	_check_equal(int(next_event_output.get("tick", -1)), 901, "Post-collapse gap changed.")
	_check_equal(String(next_event.get("id", "")), "s2_b13", "Wrong event followed collapsed content.")
	var boss_token := ""
	for _step in range(800):
		var output: Dictionary = runtime.advance()
		if not bool(output.get("ok", false)):
			_check(false, "Stage runtime failed before boss reachability.")
			return
		if bool(output.get("paused", false)):
			var boss_gate_value: Variant = output.get("active_gate")
			if not (boss_gate_value is Dictionary):
				_check(false, "Boss active_gate is not a Dictionary.")
				return
			var boss_gate: Dictionary = boss_gate_value
			boss_token = String(boss_gate.get("completion_token", ""))
			break
	_check_equal(boss_token, "stage2_boss_cleared", "Boss gate/token were not reachable in the bounded advance.")
	_assert_stage_metadata(adapter)

func _assert_stage_metadata(adapter) -> void:
	var metadata: Dictionary = adapter.content_metadata()
	var phase_sequences_value: Variant = metadata.get("phase_sequences")
	if not (phase_sequences_value is Dictionary):
		_check(false, "Metadata phase_sequences is not a Dictionary.")
		return
	var phase_sequences: Dictionary = phase_sequences_value
	var midboss_sequence_value: Variant = phase_sequences.get("midboss")
	if not (midboss_sequence_value is Array):
		_check(false, "Metadata midboss sequence is not an Array.")
		return
	var midboss_sequence: Array = midboss_sequence_value
	var boss_sequence_value: Variant = phase_sequences.get("boss")
	if not (boss_sequence_value is Array):
		_check(false, "Metadata boss sequence is not an Array.")
		return
	var boss_sequence: Array = boss_sequence_value
	_check_equal(midboss_sequence, ["stage_2_midboss_nonspell_1", "stage_2_midboss_spell_1"], "Midboss phase sequence drifted.")
	_check_equal(boss_sequence, ["stage_2_boss_nonspell_1", "stage_2_boss_spell_1", "stage_2_boss_spell_2", "stage_2_boss_spell_3"], "Boss phase sequence drifted.")
	var event_metadata_value: Variant = metadata.get("event_metadata")
	if not (event_metadata_value is Dictionary):
		_check(false, "Metadata event_metadata is not a Dictionary.")
		return
	var event_metadata: Dictionary = event_metadata_value
	var b07_value: Variant = event_metadata.get("s2_b07")
	if not (b07_value is Dictionary):
		_check(false, "s2_b07 metadata is not a Dictionary.")
		return
	var b07: Dictionary = b07_value
	if typeof(b07.get("authored_tick")) != TYPE_INT:
		_check(false, "s2_b07 metadata authored_tick is not integral.")
		return
	_check_equal(int(b07.authored_tick), 900, "Encounter evidence lost its authored tick.")
	_check_equal(String(b07.get("encounter_role", "")), "midboss", "Encounter evidence lost ownership.")
	var b01_value: Variant = event_metadata.get("s2_b01")
	if not (b01_value is Dictionary):
		_check(false, "s2_b01 metadata is not a Dictionary.")
		return
	var b01: Dictionary = b01_value
	var source_event_value: Variant = b01.get("source_event")
	if not (source_event_value is Dictionary):
		_check(false, "s2_b01 source_event metadata is not a Dictionary.")
		return
	var source_event: Dictionary = source_event_value
	var spawns_value: Variant = source_event.get("spawns")
	if not (spawns_value is Array):
		_check(false, "s2_b01 source spawns are not an Array.")
		return
	var spawns: Array = spawns_value
	if spawns.is_empty():
		_check(false, "s2_b01 source spawns are empty.")
		return
	var first_spawn_value: Variant = spawns[0]
	if not (first_spawn_value is Dictionary):
		_check(false, "s2_b01 first source spawn is not a Dictionary.")
		return
	var first_spawn: Dictionary = first_spawn_value
	var drops_value: Variant = first_spawn.get("drop_item_ids")
	if not (drops_value is Array):
		_check(false, "s2_b01 deterministic drops are not an Array.")
		return
	var drops: Array = drops_value
	_check_equal(drops, ["point_small", "point_small"], "Deterministic drops were not retained in metadata.")
	var source_bindings_value: Variant = metadata.get("source_bindings")
	if not (source_bindings_value is Array):
		_check(false, "Metadata source_bindings is not an Array.")
		return
	var source_bindings: Array = source_bindings_value
	_check(not source_bindings.is_empty(), "Source bindings were not retained.")

func _assert_phases(adapter) -> void:
	var metadata: Dictionary = adapter.content_metadata()
	var phase_metadata_value: Variant = metadata.get("phase_metadata")
	if not (phase_metadata_value is Dictionary):
		_check(false, "Metadata phase_metadata is not a Dictionary.")
		return
	var phase_metadata: Dictionary = phase_metadata_value
	var source_content: Dictionary = adapter.source_content()
	var source_phases_value: Variant = source_content.get("phases")
	if not (source_phases_value is Array):
		_check(false, "Adapter source phases are not an Array.")
		return
	var source_phases: Array = source_phases_value
	var phases: Array = adapter.phase_specs()
	if phases.size() != 6:
		_check(false, "Projected phase count changed.")
		return
	var clamped_emitters := {
		"s2_mb_ns1_n_odd_beads": 30,
		"s2_mb_sp1_n_rung_end_fans": 30,
		"s2_boss_ns1_n_blue_coins": 30,
		"s2_boss_sp1_n_exchange_bell": 30,
	}
	var observed_clamps := 0
	for phase_value in phases:
		if not (phase_value is Dictionary):
			_check(false, "Projected phase is not a Dictionary.")
			return
		var phase: Dictionary = phase_value
		var phase_id_value: Variant = phase.get("id")
		if typeof(phase_id_value) != TYPE_STRING or String(phase_id_value).is_empty():
			_check(false, "Projected phase ID is missing.")
			return
		var phase_id := String(phase_id_value)
		var loop_ticks_value: Variant = phase.get("loop_ticks")
		if typeof(loop_ticks_value) != TYPE_INT or int(loop_ticks_value) <= 0:
			_check(false, "Phase %s loop_ticks is not a positive integer." % phase_id)
			return
		var loop_ticks := int(loop_ticks_value)
		var difficulties_value: Variant = phase.get("difficulties")
		if not (difficulties_value is Dictionary):
			_check(false, "Phase %s difficulties are not a Dictionary." % phase_id)
			return
		var difficulties: Dictionary = difficulties_value
		var normal_profile_value: Variant = difficulties.get("normal")
		if not (normal_profile_value is Dictionary):
			_check(false, "Phase %s Normal profile is not a Dictionary." % phase_id)
			return
		var normal_profile: Dictionary = normal_profile_value
		var hard_profile_value: Variant = difficulties.get("hard")
		if not (hard_profile_value is Dictionary):
			_check(false, "Phase %s Hard profile is not a Dictionary." % phase_id)
			return
		var hard_profile: Dictionary = hard_profile_value
		if not _profile_has_emitter_array(normal_profile) or not _profile_has_emitter_array(hard_profile):
			_check(false, "Phase %s projected emitter arrays are malformed." % phase_id)
			return
		var phase_meta_value: Variant = phase_metadata.get(phase_id)
		if not (phase_meta_value is Dictionary):
			_check(false, "Phase %s metadata is not a Dictionary." % phase_id)
			return
		var phase_meta: Dictionary = phase_meta_value
		var metadata_normal_graph_value: Variant = phase_meta.get("normal_route_graph")
		if not (metadata_normal_graph_value is Dictionary):
			_check(false, "Phase %s metadata Normal route graph is malformed." % phase_id)
			return
		var metadata_normal_graph: Dictionary = metadata_normal_graph_value
		var metadata_hard_graph_value: Variant = phase_meta.get("hard_route_graph")
		if not (metadata_hard_graph_value is Dictionary):
			_check(false, "Phase %s metadata Hard route graph is malformed." % phase_id)
			return
		var metadata_hard_graph: Dictionary = metadata_hard_graph_value
		var source_phase: Dictionary = _find_phase(source_phases, phase_id)
		if source_phase.is_empty():
			_check(false, "Phase %s is missing from adapter source content." % phase_id)
			return
		var source_difficulties_value: Variant = source_phase.get("difficulties")
		if not (source_difficulties_value is Dictionary):
			_check(false, "Phase %s source difficulties are malformed." % phase_id)
			return
		var source_difficulties: Dictionary = source_difficulties_value
		var source_normal_profile_value: Variant = source_difficulties.get("normal")
		if not (source_normal_profile_value is Dictionary):
			_check(false, "Phase %s source Normal profile is malformed." % phase_id)
			return
		var source_normal_profile: Dictionary = source_normal_profile_value
		var source_hard_profile_value: Variant = source_difficulties.get("hard")
		if not (source_hard_profile_value is Dictionary):
			_check(false, "Phase %s source Hard profile is malformed." % phase_id)
			return
		var source_hard_profile: Dictionary = source_hard_profile_value
		if not _profile_has_emitter_array(source_normal_profile) or not _profile_has_emitter_array(source_hard_profile):
			_check(false, "Phase %s source emitter arrays are malformed." % phase_id)
			return
		var source_normal_graph_value: Variant = source_normal_profile.get("route_graph")
		if not (source_normal_graph_value is Dictionary):
			_check(false, "Phase %s source Normal route graph is malformed." % phase_id)
			return
		var source_normal_graph: Dictionary = source_normal_graph_value
		var source_hard_graph_value: Variant = source_hard_profile.get("route_graph")
		if not (source_hard_graph_value is Dictionary):
			_check(false, "Phase %s source Hard route graph is malformed." % phase_id)
			return
		var source_hard_graph: Dictionary = source_hard_graph_value
		_check_equal(metadata_normal_graph, source_normal_graph, "Phase %s metadata Normal route graph changed." % phase_id)
		_check_equal(metadata_hard_graph, source_hard_graph, "Phase %s metadata Hard route graph changed." % phase_id)
		_check(metadata_normal_graph != metadata_hard_graph, "Phase %s Normal/Hard route graphs no longer differ." % phase_id)
		_check(String(normal_profile.get("topology_id", "")) != String(hard_profile.get("topology_id", "")), "Phase %s topology IDs do not differ." % phase_id)
		if not _assert_phase_primitive_projection(phase_id, normal_profile, hard_profile, source_normal_profile, source_hard_profile):
			return
		for difficulty in ["normal", "hard"]:
			var profile: Dictionary = normal_profile if difficulty == "normal" else hard_profile
			var emitters: Array = profile.emitters
			for emitter_value in emitters:
				if not (emitter_value is Dictionary):
					_check(false, "Phase %s %s emitter is not a Dictionary." % [phase_id, difficulty])
					return
				var emitter: Dictionary = emitter_value
				if not _emitter_has_integral_schedule(emitter):
					_check(false, "Phase %s %s emitter schedule is not integral." % [phase_id, difficulty])
					return
				var emitter_id := String(emitter.get("id", ""))
				if clamped_emitters.has(emitter_id):
					var warning_value: Variant = emitter.get("warning")
					if not (warning_value is Dictionary):
						_check(false, "Clamped emitter %s warning is malformed." % emitter_id)
						return
					var warning: Dictionary = warning_value
					if typeof(warning.get("lead_ticks")) != TYPE_INT:
						_check(false, "Clamped emitter %s warning lead is not integral." % emitter_id)
						return
					observed_clamps += 1
					_check_equal(int(warning.lead_ticks), int(clamped_emitters[emitter_id]), "Emitter warning did not clamp to its phase floor.")
			var runtime := DanmakuPatternRuntime.new()
			if not runtime.configure(phase, difficulty, 20260715):
				_check(false, "Strict DanmakuPatternRuntime rejected %s %s: %s" % [phase_id, difficulty, runtime.validation_errors()])
				return
			var saw_warning := false
			var saw_bullet := false
			for _tick in range(loop_ticks):
				var output: Dictionary = runtime.advance(Vector2(360.0, 720.0))
				if not bool(output.get("ok", false)):
					_check(false, "Pattern runtime hard-failed for %s %s: %s" % [phase_id, difficulty, output.get("error", "")])
					return
				var warnings_value: Variant = output.get("warnings")
				if not (warnings_value is Array):
					_check(false, "Pattern warnings output changed type for %s %s." % [phase_id, difficulty])
					return
				var warnings: Array = warnings_value
				var bullets_value: Variant = output.get("bullet_specs")
				if not (bullets_value is Array):
					_check(false, "Pattern bullets output changed type for %s %s." % [phase_id, difficulty])
					return
				var bullets: Array = bullets_value
				saw_warning = saw_warning or not warnings.is_empty()
				saw_bullet = saw_bullet or not bullets.is_empty()
				if saw_warning and saw_bullet:
					break
			_check(saw_warning and saw_bullet, "Phase %s %s did not emit warning and bullet records." % [phase_id, difficulty])
	_check_equal(observed_clamps, 4, "The exact four authored Normal warning-floor clamps changed.")

func _assert_phase_primitive_projection(phase_id: String, normal_profile: Dictionary, hard_profile: Dictionary, source_normal_profile: Dictionary, source_hard_profile: Dictionary) -> bool:
	if REBOUND_EMITTER_IDS.has(phase_id):
		var rebound_ids: Array = REBOUND_EMITTER_IDS[phase_id]
		var normal_rebound := _find_emitter(normal_profile, String(rebound_ids[0]))
		var hard_rebound := _find_emitter(hard_profile, String(rebound_ids[1]))
		if not _assert_rebound_axes(normal_rebound, "x", phase_id, "Normal") or not _assert_rebound_axes(hard_rebound, "xy", phase_id, "Hard"):
			return false
	if GRID_EXPECTATIONS.has(phase_id):
		var grid_expectation: Array = GRID_EXPECTATIONS[phase_id]
		var normal_grid := _find_emitter(normal_profile, String(grid_expectation[0]))
		var hard_grid := _find_emitter(hard_profile, String(grid_expectation[1]))
		var source_normal_grid := _find_emitter(source_normal_profile, String(grid_expectation[0]))
		var source_hard_grid := _find_emitter(source_hard_profile, String(grid_expectation[1]))
		if not _assert_grid_projection(normal_grid, source_normal_grid, source_normal_profile, String(grid_expectation[2]), phase_id, "Normal"):
			return false
		if not _assert_grid_projection(hard_grid, source_hard_grid, source_hard_profile, String(grid_expectation[3]), phase_id, "Hard"):
			return false
	if phase_id == "stage_2_midboss_spell_1":
		if not _assert_fixed_lane_fan(_find_emitter(normal_profile, String(LANE_FAN_EMITTER_IDS[0])), phase_id, "Normal"):
			return false
		if not _assert_fixed_lane_fan(_find_emitter(hard_profile, String(LANE_FAN_EMITTER_IDS[1])), phase_id, "Hard"):
			return false
	if phase_id == "stage_2_boss_spell_1":
		if not _assert_rhythm_projection(_find_emitter(normal_profile, String(RHYTHM_EMITTER_IDS[0])), _find_emitter(source_normal_profile, String(RHYTHM_EMITTER_IDS[0])), phase_id, "Normal"):
			return false
		if not _assert_rhythm_projection(_find_emitter(hard_profile, String(RHYTHM_EMITTER_IDS[1])), _find_emitter(source_hard_profile, String(RHYTHM_EMITTER_IDS[1])), phase_id, "Hard"):
			return false
	if DELAYED_EMITTER_IDS.has(phase_id):
		var delayed_ids: Array = DELAYED_EMITTER_IDS[phase_id]
		if not _assert_delayed_projection(_find_emitter(normal_profile, String(delayed_ids[0])), _find_emitter(source_normal_profile, String(delayed_ids[0])), phase_id, "Normal"):
			return false
		if not _assert_delayed_projection(_find_emitter(hard_profile, String(delayed_ids[1])), _find_emitter(source_hard_profile, String(delayed_ids[1])), phase_id, "Hard"):
			return false
	return true

func _assert_rebound_axes(emitter: Dictionary, expected_axes: String, phase_id: String, difficulty: String) -> bool:
	if emitter.is_empty() or String(emitter.get("primitive", "")) != "rebound_bead":
		_check(false, "%s %s rebound emitter is missing." % [phase_id, difficulty])
		return false
	var reflection_value: Variant = emitter.get("reflection")
	if not (reflection_value is Dictionary):
		_check(false, "%s %s rebound reflection is malformed." % [phase_id, difficulty])
		return false
	var reflection: Dictionary = reflection_value
	_check_equal(String(reflection.get("axes", "")), expected_axes, "%s %s rebound axes changed." % [phase_id, difficulty])
	return not failed

func _assert_grid_projection(emitter: Dictionary, source_emitter: Dictionary, source_profile: Dictionary, expected_routing: String, phase_id: String, difficulty: String) -> bool:
	if emitter.is_empty() or source_emitter.is_empty() or String(emitter.get("primitive", "")) != "grid_edge":
		_check(false, "%s %s grid emitter or source is missing." % [phase_id, difficulty])
		return false
	_check_equal(String(emitter.get("routing", "")), expected_routing, "%s %s grid routing changed." % [phase_id, difficulty])
	var spacing_value: Variant = emitter.get("spacing")
	if not _is_finite_number(spacing_value) or float(spacing_value) <= 0.0:
		_check(false, "%s %s grid spacing is not finite and positive." % [phase_id, difficulty])
		return false
	var expected_spacing := _expected_grid_spacing(source_emitter, source_profile)
	if not _is_finite_number(expected_spacing) or float(expected_spacing) <= 0.0:
		_check(false, "%s %s authored grid geometry cannot derive spacing." % [phase_id, difficulty])
		return false
	_check(is_equal_approx(float(spacing_value), float(expected_spacing)), "%s %s grid spacing is not source-derived." % [phase_id, difficulty])
	return not failed

func _assert_fixed_lane_fan(emitter: Dictionary, phase_id: String, difficulty: String) -> bool:
	if emitter.is_empty() or String(emitter.get("primitive", "")) != "lane_fan":
		_check(false, "%s %s lane_fan emitter is missing." % [phase_id, difficulty])
		return false
	_check_equal(String(emitter.get("aim_mode", "")), "fixed", "%s %s lane_fan aim mode changed." % [phase_id, difficulty])
	return not failed

func _assert_rhythm_projection(emitter: Dictionary, source_emitter: Dictionary, phase_id: String, difficulty: String) -> bool:
	if emitter.is_empty() or source_emitter.is_empty() or String(emitter.get("primitive", "")) != "rhythm_pulse":
		_check(false, "%s %s rhythm_pulse emitter or source is missing." % [phase_id, difficulty])
		return false
	var routing_value: Variant = source_emitter.get("routing")
	if not (routing_value is Dictionary):
		_check(false, "%s %s rhythm source routing is malformed." % [phase_id, difficulty])
		return false
	var routing: Dictionary = routing_value
	var beat_ticks_value: Variant = routing.get("beat_ticks")
	if not _is_integral_number(beat_ticks_value) or int(float(beat_ticks_value)) != 60:
		_check(false, "%s %s rhythm source beat_ticks is not 60." % [phase_id, difficulty])
		return false
	var turn_rate_value: Variant = emitter.get("turn_rate")
	if not _is_finite_number(turn_rate_value):
		_check(false, "%s %s rhythm turn_rate is not finite." % [phase_id, difficulty])
		return false
	var expected_turn_rate := 360.0 / float(beat_ticks_value)
	_check(is_equal_approx(float(turn_rate_value), expected_turn_rate), "%s %s rhythm turn_rate is not derived from 60 beat ticks." % [phase_id, difficulty])
	return not failed

func _assert_delayed_projection(emitter: Dictionary, source_emitter: Dictionary, phase_id: String, difficulty: String) -> bool:
	if emitter.is_empty() or source_emitter.is_empty() or String(emitter.get("primitive", "")) != "delayed_seed":
		_check(false, "%s %s delayed_seed emitter or source is missing." % [phase_id, difficulty])
		return false
	var routing_value: Variant = source_emitter.get("routing")
	if not (routing_value is Dictionary):
		_check(false, "%s %s delayed source routing is malformed." % [phase_id, difficulty])
		return false
	var routing: Dictionary = routing_value
	var source_delay_value: Variant = routing.get("activation_delay_ticks")
	var delay_value: Variant = emitter.get("delay_ticks")
	var lifetime_value: Variant = emitter.get("lifetime_ticks")
	if not _is_integral_number(source_delay_value) or typeof(delay_value) != TYPE_INT or typeof(lifetime_value) != TYPE_INT:
		_check(false, "%s %s delayed timing is not integral." % [phase_id, difficulty])
		return false
	var delay := int(delay_value)
	var lifetime := int(lifetime_value)
	_check_equal(delay, int(float(source_delay_value)), "%s %s delayed activation changed." % [phase_id, difficulty])
	_check(delay > 0 and delay < lifetime, "%s %s delayed activation is outside lifetime." % [phase_id, difficulty])
	var turn_rate_value: Variant = emitter.get("turn_rate")
	if not _is_finite_number(turn_rate_value):
		_check(false, "%s %s delayed turn_rate is not finite." % [phase_id, difficulty])
		return false
	var expected_turn_rate := _expected_delayed_turn_rate(source_emitter, routing)
	if not _is_finite_number(expected_turn_rate):
		_check(false, "%s %s delayed authored geometry cannot derive turn_rate." % [phase_id, difficulty])
		return false
	_check(is_equal_approx(float(turn_rate_value), float(expected_turn_rate)), "%s %s delayed turn_rate is not source-derived." % [phase_id, difficulty])
	return not failed

func _assert_deep_copy_isolation(adapter) -> void:
	var stage: Dictionary = adapter.stage_spec()
	var events_value: Variant = stage.get("events")
	if not (events_value is Array):
		_check(false, "Deep-copy stage events are not an Array.")
		return
	var events: Array = events_value
	if events.is_empty():
		_check(false, "Deep-copy stage events are empty.")
		return
	var event_value: Variant = events[0]
	if not (event_value is Dictionary):
		_check(false, "Deep-copy stage event is not a Dictionary.")
		return
	var event: Dictionary = event_value
	var payload_value: Variant = event.get("payload")
	if not (payload_value is Dictionary):
		_check(false, "Deep-copy stage payload is not a Dictionary.")
		return
	var payload: Dictionary = payload_value
	payload["authored_tick"] = -1
	var fresh_stage: Dictionary = adapter.stage_spec()
	var fresh_events_value: Variant = fresh_stage.get("events")
	if not (fresh_events_value is Array):
		_check(false, "Fresh stage events are not an Array.")
		return
	var fresh_events: Array = fresh_events_value
	if fresh_events.is_empty():
		_check(false, "Fresh stage events are empty.")
		return
	var fresh_event_value: Variant = fresh_events[0]
	if not (fresh_event_value is Dictionary):
		_check(false, "Fresh stage first event is not a Dictionary.")
		return
	var fresh_event: Dictionary = fresh_event_value
	var fresh_payload_value: Variant = fresh_event.get("payload")
	if not (fresh_payload_value is Dictionary):
		_check(false, "Fresh stage payload is malformed.")
		return
	var fresh_payload: Dictionary = fresh_payload_value
	_check_equal(int(fresh_payload.get("authored_tick", -1)), 0, "Stage output retained caller aliases.")

	var phase: Dictionary = adapter.phase_spec("stage_2_midboss_nonspell_1")
	var phase_emitter: Dictionary = _projected_emitter_from_phase(phase, "normal", "s2_mb_ns1_n_odd_beads")
	if phase_emitter.is_empty():
		_check(false, "Deep-copy phase emitter is missing.")
		return
	var phase_anchor_value: Variant = phase_emitter.get("anchor")
	if not (phase_anchor_value is Vector2):
		_check(false, "Deep-copy phase emitter anchor is not a Vector2.")
		return
	phase_emitter["anchor"] = Vector2.ZERO
	var fresh_phase: Dictionary = adapter.phase_spec("stage_2_midboss_nonspell_1")
	var fresh_phase_emitter: Dictionary = _projected_emitter_from_phase(fresh_phase, "normal", "s2_mb_ns1_n_odd_beads")
	if fresh_phase_emitter.is_empty():
		_check(false, "Fresh phase emitter is missing.")
		return
	var fresh_phase_anchor_value: Variant = fresh_phase_emitter.get("anchor")
	if not (fresh_phase_anchor_value is Vector2):
		_check(false, "Fresh phase emitter anchor is not a Vector2.")
		return
	_check(fresh_phase_anchor_value != Vector2.ZERO, "Phase output retained caller aliases.")

	var metadata: Dictionary = adapter.content_metadata()
	var event_metadata_value: Variant = metadata.get("event_metadata")
	if not (event_metadata_value is Dictionary):
		_check(false, "Deep-copy event metadata is malformed.")
		return
	var event_metadata: Dictionary = event_metadata_value
	var b07_value: Variant = event_metadata.get("s2_b07")
	if not (b07_value is Dictionary):
		_check(false, "Deep-copy s2_b07 metadata is malformed.")
		return
	var b07: Dictionary = b07_value
	var source_event_value: Variant = b07.get("source_event")
	if not (source_event_value is Dictionary):
		_check(false, "Deep-copy s2_b07 source event is malformed.")
		return
	var source_event: Dictionary = source_event_value
	var warning_value: Variant = source_event.get("warning")
	if not (warning_value is Dictionary):
		_check(false, "Deep-copy s2_b07 warning is malformed.")
		return
	var warning: Dictionary = warning_value
	warning["visual"] = "mutated"
	var fresh_metadata: Dictionary = adapter.content_metadata()
	var fresh_event_metadata_value: Variant = fresh_metadata.get("event_metadata")
	if not (fresh_event_metadata_value is Dictionary):
		_check(false, "Fresh event metadata is malformed.")
		return
	var fresh_event_metadata: Dictionary = fresh_event_metadata_value
	var fresh_b07_value: Variant = fresh_event_metadata.get("s2_b07")
	if not (fresh_b07_value is Dictionary):
		_check(false, "Fresh s2_b07 metadata is malformed.")
		return
	var fresh_b07: Dictionary = fresh_b07_value
	var fresh_source_event_value: Variant = fresh_b07.get("source_event")
	if not (fresh_source_event_value is Dictionary):
		_check(false, "Fresh s2_b07 source event is malformed.")
		return
	var fresh_source_event: Dictionary = fresh_source_event_value
	var fresh_warning_value: Variant = fresh_source_event.get("warning")
	if not (fresh_warning_value is Dictionary):
		_check(false, "Fresh s2_b07 warning is malformed.")
		return
	var fresh_warning: Dictionary = fresh_warning_value
	_check(String(fresh_warning.get("visual", "")) != "mutated", "Metadata output retained caller aliases.")

	_assert_route_graph_deep_copy(adapter)

func _assert_route_graph_deep_copy(adapter) -> void:
	var phase_id := "stage_2_midboss_nonspell_1"
	var metadata: Dictionary = adapter.content_metadata()
	var graph: Dictionary = _metadata_route_graph(metadata, phase_id, "normal")
	if graph.is_empty():
		_check(false, "Deep-copy metadata route graph is missing.")
		return
	var edges_value: Variant = graph.get("directed_edges")
	if not (edges_value is Array):
		_check(false, "Deep-copy route graph edges are not an Array.")
		return
	var edges: Array = edges_value
	if edges.is_empty():
		_check(false, "Deep-copy route graph edges are empty.")
		return
	var first_edge_value: Variant = edges[0]
	if not (first_edge_value is Array):
		_check(false, "Deep-copy route graph first edge is not an Array.")
		return
	var first_edge: Array = first_edge_value
	if first_edge.is_empty():
		_check(false, "Deep-copy route graph first edge is empty.")
		return
	var endpoint_value: Variant = first_edge[0]
	if typeof(endpoint_value) != TYPE_STRING:
		_check(false, "Deep-copy route graph endpoint is not a String.")
		return
	var structural_snapshot: Dictionary = graph.duplicate(true)
	first_edge[0] = "mutated_edge"
	var fresh_metadata: Dictionary = adapter.content_metadata()
	var fresh_graph: Dictionary = _metadata_route_graph(fresh_metadata, phase_id, "normal")
	if fresh_graph.is_empty():
		_check(false, "Fresh metadata route graph is missing.")
		return
	_check_equal(fresh_graph, structural_snapshot, "Metadata route graph retained a nested caller alias.")
	var fresh_source: Dictionary = adapter.source_content()
	var source_phases_value: Variant = fresh_source.get("phases")
	if not (source_phases_value is Array):
		_check(false, "Fresh source phase list is malformed after metadata mutation.")
		return
	var source_phases: Array = source_phases_value
	var source_phase: Dictionary = _find_phase(source_phases, phase_id)
	if source_phase.is_empty():
		_check(false, "Fresh source phase is missing after metadata mutation.")
		return
	var source_graph: Dictionary = _source_route_graph(source_phase, "normal")
	if source_graph.is_empty():
		_check(false, "Fresh source route graph is missing after metadata mutation.")
		return
	_check_equal(source_graph, structural_snapshot, "Metadata graph mutation leaked into adapter source content.")

func _assert_malformed_rejections(adapter) -> void:
	var cases := [
		"fractional_schema", "unknown_schema", "fractional_authored_tick", "string_authored_tick", "fractional_loop_tick",
		"fractional_schedule", "schedule_out_of_range", "fractional_warning_floor", "missing_phase_warning", "malformed_stage_warning", "malformed_spawn_vector",
		"malformed_spawn_movement", "malformed_emitter_color", "missing_emitter_warning",
		"nondictionary_spawn", "duplicate_spawn_id", "duplicate_emitter_id", "missing_route_graph",
		"empty_route_graph", "missing_phase_movement", "missing_phase_timeline", "malformed_rebound_routing", "delayed_out_of_range",
	]
	_check_equal(cases.size(), 23, "Malformed-content case count changed.")
	for case_name in cases:
		var malformed: Dictionary = adapter.source_content()
		_apply_malformed_mutation(malformed, case_name)
		var rejected := Stage2ContentAdapter.new()
		var accepted: bool = rejected.configure_from_content(malformed)
		_check(not accepted, "Malformed case %s did not return false." % case_name)
		_check(not rejected.is_valid(), "Malformed case %s reported is_valid=true." % case_name)
		var errors: Array[String] = rejected.validation_errors()
		_check(not errors.is_empty(), "Malformed case %s did not expose validation errors." % case_name)
		_check(rejected.stage_spec().is_empty(), "Malformed case %s exposed a stage spec." % case_name)
		_check(rejected.phase_specs().is_empty(), "Malformed case %s exposed phase specs." % case_name)
		_check(rejected.content_metadata().is_empty(), "Malformed case %s exposed content metadata." % case_name)

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

func _profile_has_emitter_array(profile: Dictionary) -> bool:
	var emitters_value: Variant = profile.get("emitters")
	if not (emitters_value is Array):
		return false
	var emitters: Array = emitters_value
	return not emitters.is_empty()

func _emitter_has_integral_schedule(emitter: Dictionary) -> bool:
	for key in ["start_tick", "interval_ticks", "bursts_per_loop", "shots_per_burst", "lifetime_ticks"]:
		if typeof(emitter.get(key)) != TYPE_INT:
			return false
	return true

func _find_phase(phases: Array, phase_id: String) -> Dictionary:
	for phase_value in phases:
		if phase_value is Dictionary:
			var phase: Dictionary = phase_value
			if String(phase.get("id", "")) == phase_id:
				return phase
	return {}

func _find_emitter(profile: Dictionary, emitter_id: String) -> Dictionary:
	var emitters_value: Variant = profile.get("emitters")
	if not (emitters_value is Array):
		return {}
	var emitters: Array = emitters_value
	for emitter_value in emitters:
		if emitter_value is Dictionary:
			var emitter: Dictionary = emitter_value
			if String(emitter.get("id", "")) == emitter_id:
				return emitter
	return {}

func _projected_emitter_from_phase(phase: Dictionary, difficulty: String, emitter_id: String) -> Dictionary:
	var difficulties_value: Variant = phase.get("difficulties")
	if not (difficulties_value is Dictionary):
		return {}
	var difficulties: Dictionary = difficulties_value
	var profile_value: Variant = difficulties.get(difficulty)
	if not (profile_value is Dictionary):
		return {}
	var profile: Dictionary = profile_value
	return _find_emitter(profile, emitter_id)

func _metadata_route_graph(metadata: Dictionary, phase_id: String, difficulty: String) -> Dictionary:
	var phase_metadata_value: Variant = metadata.get("phase_metadata")
	if not (phase_metadata_value is Dictionary):
		return {}
	var phase_metadata: Dictionary = phase_metadata_value
	var phase_meta_value: Variant = phase_metadata.get(phase_id)
	if not (phase_meta_value is Dictionary):
		return {}
	var phase_meta: Dictionary = phase_meta_value
	var graph_value: Variant = phase_meta.get("%s_route_graph" % difficulty)
	if not (graph_value is Dictionary):
		return {}
	var graph: Dictionary = graph_value
	return graph

func _source_route_graph(source_phase: Dictionary, difficulty: String) -> Dictionary:
	var difficulties_value: Variant = source_phase.get("difficulties")
	if not (difficulties_value is Dictionary):
		return {}
	var difficulties: Dictionary = difficulties_value
	var profile_value: Variant = difficulties.get(difficulty)
	if not (profile_value is Dictionary):
		return {}
	var profile: Dictionary = profile_value
	var graph_value: Variant = profile.get("route_graph")
	if not (graph_value is Dictionary):
		return {}
	var graph: Dictionary = graph_value
	return graph

func _expected_grid_spacing(source_emitter: Dictionary, source_profile: Dictionary) -> float:
	var routing_value: Variant = source_emitter.get("routing")
	if not (routing_value is Dictionary):
		return -1.0
	var routing: Dictionary = routing_value
	var lane_x_value: Variant = routing.get("lane_x")
	if lane_x_value is Array:
		var lane_x: Array = lane_x_value
		if lane_x.size() >= 2 and _is_finite_number(lane_x[0]) and _is_finite_number(lane_x[1]):
			return absf(float(lane_x[1]) - float(lane_x[0]))
	var columns_value: Variant = routing.get("grid_columns")
	if _is_integral_number(columns_value) and int(float(columns_value)) > 0:
		return 672.0 / float(columns_value)
	var safe_width_value: Variant = source_profile.get("safe_route_width_px")
	var shots_value: Variant = source_emitter.get("shots_per_burst")
	if _is_finite_number(safe_width_value) and _is_integral_number(shots_value) and int(float(shots_value)) > 0:
		return float(safe_width_value) / float(shots_value)
	return -1.0

func _expected_delayed_turn_rate(source_emitter: Dictionary, routing: Dictionary) -> float:
	var delay_value: Variant = routing.get("activation_delay_ticks")
	if not _is_integral_number(delay_value) or int(float(delay_value)) <= 0:
		return NAN
	var delay := float(delay_value)
	for angle_key in ["rotation_deg", "axis_deg"]:
		var angle_value: Variant = routing.get(angle_key)
		if _is_finite_number(angle_value):
			return float(angle_value) / delay
	var axis_options_value: Variant = routing.get("axis_options_deg")
	if axis_options_value is Array:
		var axis_options: Array = axis_options_value
		if not axis_options.is_empty() and _is_finite_number(axis_options[axis_options.size() - 1]):
			return float(axis_options[axis_options.size() - 1]) / delay
	var step_value: Variant = source_emitter.get("angle_step_deg")
	if _is_finite_number(step_value):
		return float(step_value) / delay
	return NAN

func _is_finite_number(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var numeric := float(value)
	return not is_nan(numeric) and not is_inf(numeric)

func _is_integral_number(value: Variant) -> bool:
	return _is_finite_number(value) and floor(float(value)) == float(value)

func _initialize() -> void:
	call_deferred("_run")
