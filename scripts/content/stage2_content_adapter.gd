extends RefCounted
class_name Stage2ContentAdapter

const StageEncounterRuntime := preload("res://scripts/runtime/stage_encounter_runtime.gd")
const DanmakuPatternRuntime := preload("res://scripts/runtime/danmaku_pattern_runtime.gd")

const ARTIFACT_PATH := "res://content/runtime/m2_stage2_choreography.json"
const STAGE_EVENT_IDS := [
	"s2_b01", "s2_b02", "s2_b03", "s2_b04", "s2_b05", "s2_b06",
	"s2_b07", "s2_b08", "s2_b09", "s2_b10", "s2_b11", "s2_b12",
	"s2_b13", "s2_b14", "s2_b15", "s2_b16", "s2_b17", "s2_b18",
]
const PHASE_IDS := [
	"stage_2_midboss_nonspell_1", "stage_2_midboss_spell_1",
	"stage_2_boss_nonspell_1", "stage_2_boss_spell_1", "stage_2_boss_spell_2", "stage_2_boss_spell_3",
]
const AUTHORED_TICKS := [0, 150, 300, 450, 600, 750, 900, 1050, 1200, 1350, 1500, 1650, 1800, 1950, 2100, 2250, 2400, 2550]
const RUNTIME_TICKS := [0, 150, 300, 450, 600, 750, 751, 751, 751, 751, 751, 751, 901, 1051, 1201, 1351, 1501, 1651]
const ANCHORS := {
	"arena_top_edge": Vector2(360.0, 48.0),
	"boss_center": Vector2(360.0, 176.0),
	"boss_left_satellite": Vector2(264.0, 208.0),
	"boss_right_satellite": Vector2(456.0, 208.0),
	"shared_gate_nodes": Vector2(360.0, 312.0),
}
const COMBAT_BOUNDS := Rect2(24.0, 48.0, 672.0, 888.0)
const MAX_SOURCE_TICK := 216000

var _stage_spec: Dictionary = {}
var _phase_specs: Dictionary = {}
var _metadata: Dictionary = {}
var _source_content: Dictionary = {}
var _validation_errors: Array[String] = []

func load_artifact(path: String = ARTIFACT_PATH) -> bool:
	_clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("unable to read choreography artifact %s" % path)
		return false
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not (parser.data is Dictionary):
		_fail("choreography artifact is not a JSON Dictionary")
		return false
	return configure_from_content(parser.data)

func configure_from_content(content: Dictionary) -> bool:
	_clear()
	_source_content = content.duplicate(true)
	if not _validate_source(_source_content):
		return false
	var source_stage: Dictionary = _source_content.stage
	_stage_spec = _project_stage(source_stage)
	for source_phase_value in _source_content.phases:
		var source_phase: Dictionary = source_phase_value
		var phase: Dictionary = _project_phase(source_phase)
		_phase_specs[String(phase.id)] = phase
	if not _validate_projected_runtime_contracts():
		return false
	_metadata = _build_metadata(source_stage)
	return true

func is_valid() -> bool:
	return _validation_errors.is_empty() and not _stage_spec.is_empty() and _phase_specs.size() == PHASE_IDS.size()

func validation_errors() -> Array[String]:
	return _validation_errors.duplicate()

func stage_spec() -> Dictionary:
	return _stage_spec.duplicate(true)

func phase_spec(phase_id: String) -> Dictionary:
	return (_phase_specs.get(phase_id, {}) as Dictionary).duplicate(true)

func phase_specs() -> Array:
	var result: Array = []
	if _phase_specs.is_empty():
		return result
	for phase_id in PHASE_IDS:
		result.append(phase_spec(phase_id))
	return result

func content_metadata() -> Dictionary:
	return _metadata.duplicate(true)

func source_content() -> Dictionary:
	return _source_content.duplicate(true)

func _clear() -> void:
	_stage_spec.clear()
	_phase_specs.clear()
	_metadata.clear()
	_source_content.clear()
	_validation_errors.clear()

func _clear_runtime_outputs() -> void:
	_stage_spec.clear()
	_phase_specs.clear()
	_metadata.clear()

func _fail(message: String) -> void:
	_validation_errors.append(message)
	_clear_runtime_outputs()

func _validate_source(content: Dictionary) -> bool:
	if not _is_integral_number(content.get("schema_version"), 1, 1):
		_fail("schema_version must be exactly integer 1")
		return false
	if typeof(content.get("artifact_id")) != TYPE_STRING or String(content.artifact_id).is_empty():
		_fail("artifact_id is required")
		return false
	if not _validate_source_bindings(content.get("source_bindings")):
		_fail("source_bindings are malformed")
		return false
	if not (content.get("stage") is Dictionary) or not (content.get("phases") is Array):
		_fail("stage and phases are required")
		return false
	if not _validate_stage_source(content.stage):
		return false
	if content.phases.size() != PHASE_IDS.size():
		_fail("Stage 2 requires exactly six phases")
		return false
	var seen_emitters := {}
	for index in range(PHASE_IDS.size()):
		if not (content.phases[index] is Dictionary):
			_fail("phase %d is not a Dictionary" % index)
			return false
		if not _validate_phase_source(content.phases[index], index, seen_emitters):
			return false
	return true

func _validate_source_bindings(value: Variant) -> bool:
	if not (value is Array) or value.is_empty():
		return false
	for binding_value in value:
		if not (binding_value is Dictionary):
			return false
		var binding: Dictionary = binding_value
		if typeof(binding.get("path")) != TYPE_STRING or String(binding.path).is_empty():
			return false
		if typeof(binding.get("hash_algorithm")) != TYPE_STRING or typeof(binding.get("raw_sha256")) != TYPE_STRING or String(binding.raw_sha256).length() != 64:
			return false
	return true

func _validate_stage_source(stage: Dictionary) -> bool:
	if String(stage.get("stage_id", "")) != "yokai_market" or not (stage.get("events") is Array):
		_fail("Stage 2 identity or events are missing")
		return false
	if not (stage.get("playfield") is Dictionary):
		_fail("Stage 2 playfield is missing")
		return false
	var playfield: Dictionary = stage.playfield
	if not _is_integral_number(playfield.get("width"), 720, 720) or not _is_integral_number(playfield.get("height"), 960, 960) or not _is_finite_number_array(playfield.get("combat_bounds"), 4):
		_fail("Stage 2 playfield contract is malformed")
		return false
	if stage.events.size() != STAGE_EVENT_IDS.size():
		_fail("Stage 2 requires exactly 18 authored events")
		return false
	var seen_spawns := {}
	for index in range(STAGE_EVENT_IDS.size()):
		if not (stage.events[index] is Dictionary):
			_fail("stage event %d is not a Dictionary" % index)
			return false
		if not _validate_stage_event(stage.events[index], index, seen_spawns):
			return false
	return true

func _validate_stage_event(event: Dictionary, index: int, seen_spawns: Dictionary) -> bool:
	var event_id := String(event.get("id", ""))
	if event_id != STAGE_EVENT_IDS[index] or not _is_integral_number(event.get("authored_tick"), AUTHORED_TICKS[index], AUTHORED_TICKS[index]):
		_fail("stage event order, identity, or authored tick is malformed at %d" % index)
		return false
	if typeof(event.get("segment_id")) != TYPE_STRING or typeof(event.get("event_type")) != TYPE_STRING or String(event.event_type).is_empty():
		_fail("stage event %s identity fields are incomplete" % event_id)
		return false
	if not _validate_stage_warning(event.get("warning")) or not _validate_formation(event.get("formation")):
		_fail("stage event %s warning or formation is malformed" % event_id)
		return false
	if not (event.get("spawns") is Array):
		_fail("stage event %s spawns must be an Array" % event_id)
		return false
	for spawn_value in event.spawns:
		if not (spawn_value is Dictionary) or not _validate_spawn(spawn_value, seen_spawns):
			_fail("stage event %s contains a malformed or duplicate spawn" % event_id)
			return false
	if not (event.get("completion") is Dictionary):
		_fail("stage event %s completion is missing" % event_id)
		return false
	var completion: Dictionary = event.completion
	if typeof(completion.get("condition")) != TYPE_STRING or String(completion.condition).is_empty() or typeof(completion.get("clear_hostile_bullets")) != TYPE_BOOL:
		_fail("stage event %s completion is malformed" % event_id)
		return false
	if event.has("deadline_tick") and not _is_integral_number(event.deadline_tick, 0, MAX_SOURCE_TICK):
		_fail("stage event %s deadline_tick is malformed" % event_id)
		return false
	if not _is_string_array(event.get("score_route_hooks"), false) or not _is_string_array(event.get("telemetry_hooks"), false):
		_fail("stage event %s hooks are malformed" % event_id)
		return false
	if event_id in ["s2_b06", "s2_b18"]:
		if not _validate_encounter_gate(event.get("encounter_gate")):
			_fail("source encounter gate %s is malformed" % event_id)
			return false
		var gate: Dictionary = event.encounter_gate
		var expected_phases: Array = PHASE_IDS.slice(0, 2) if event_id == "s2_b06" else PHASE_IDS.slice(2, 6)
		if gate.phase_ids != expected_phases:
			_fail("source encounter gate %s phase sequence is malformed" % event_id)
			return false
	if event_id == "s2_b12" and not _validate_encounter_resume(event.get("encounter_resume")):
		_fail("midboss source resume is malformed")
		return false
	if event_id == "s2_b12" and event.encounter_resume.required_phase_ids != PHASE_IDS.slice(0, 2):
		_fail("midboss source resume phase sequence is malformed")
		return false
	return true

func _validate_encounter_gate(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var gate: Dictionary = value
	return (
		typeof(gate.get("action")) == TYPE_STRING
		and not String(gate.action).is_empty()
		and typeof(gate.get("owner_id")) == TYPE_STRING
		and not String(gate.owner_id).is_empty()
		and _is_string_array(gate.get("phase_ids"), false)
	)

func _validate_encounter_resume(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var resume: Dictionary = value
	return (
		typeof(resume.get("action")) == TYPE_STRING
		and not String(resume.action).is_empty()
		and typeof(resume.get("from_gate_event_id")) == TYPE_STRING
		and String(resume.from_gate_event_id) == "s2_b06"
		and _is_string_array(resume.get("required_phase_ids"), false)
		and _is_integral_number(resume.get("resume_tick"), 0, MAX_SOURCE_TICK)
	)

func _validate_stage_warning(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var warning: Dictionary = value
	return (
		_is_integral_number(warning.get("lead_ticks"), 0, MAX_SOURCE_TICK)
		and typeof(warning.get("visual")) == TYPE_STRING
		and _is_integral_number(warning.get("future_path_px"), 0, 10000)
	)

func _validate_formation(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var formation: Dictionary = value
	return typeof(formation.get("id")) == TYPE_STRING and not String(formation.id).is_empty() and _is_string_array(formation.get("active_entity_ids"), true)

func _validate_spawn(spawn: Dictionary, seen_spawns: Dictionary) -> bool:
	var spawn_id := String(spawn.get("id", ""))
	if typeof(spawn.get("id")) != TYPE_STRING or spawn_id.is_empty() or seen_spawns.has(spawn_id):
		return false
	seen_spawns[spawn_id] = true
	if typeof(spawn.get("enemy_id")) != TYPE_STRING or String(spawn.enemy_id).is_empty() or not _is_vector_array(spawn.get("position")):
		return false
	if not (spawn.get("movement") is Dictionary):
		return false
	var movement: Dictionary = spawn.movement
	if typeof(movement.get("path")) != TYPE_STRING or String(movement.path).is_empty() or not _is_vector_array(movement.get("to")) or not _is_integral_number(movement.get("duration_ticks"), 1, MAX_SOURCE_TICK):
		return false
	if not (spawn.get("pattern") is Dictionary):
		return false
	var pattern: Dictionary = spawn.pattern
	if typeof(pattern.get("primitive")) != TYPE_STRING or String(pattern.primitive).is_empty() or typeof(pattern.get("routing")) != TYPE_STRING or String(pattern.routing).is_empty():
		return false
	for key in ["start_delay_ticks", "interval_ticks", "shots_per_burst"]:
		if not _is_integral_number(pattern.get(key), 0 if key == "start_delay_ticks" else 1, MAX_SOURCE_TICK):
			return false
	if not _is_finite_number(pattern.get("speed")) or float(pattern.speed) < 0.0:
		return false
	return _is_string_array(spawn.get("drop_item_ids"), true)

func _validate_phase_source(phase: Dictionary, index: int, seen_emitters: Dictionary) -> bool:
	var phase_id := String(phase.get("id", ""))
	if phase_id != PHASE_IDS[index]:
		_fail("phase order or identity is malformed at %d" % index)
		return false
	if typeof(phase.get("deterministic_random_stream_id")) != TYPE_STRING or String(phase.deterministic_random_stream_id).is_empty():
		_fail("phase %s deterministic stream is missing" % phase_id)
		return false
	var expected_role := "midboss" if index < 2 else "boss"
	if typeof(phase.get("encounter_role")) != TYPE_STRING or String(phase.encounter_role) != expected_role:
		_fail("phase %s encounter ownership is malformed" % phase_id)
		return false
	if not _is_integral_number(phase.get("loop_ticks"), 1, DanmakuPatternRuntime.MAX_LOOP_TICKS):
		_fail("phase %s loop_ticks is malformed" % phase_id)
		return false
	var loop_ticks := _as_int(phase.loop_ticks)
	if not (phase.get("warning_ticks") is Dictionary):
		_fail("phase %s warning floors are missing" % phase_id)
		return false
	var warning_ticks: Dictionary = phase.warning_ticks
	if not _is_integral_number(warning_ticks.get("normal"), DanmakuPatternRuntime.NORMAL_WARNING_FLOOR, loop_ticks) or not _is_integral_number(warning_ticks.get("hard"), DanmakuPatternRuntime.HARD_WARNING_FLOOR, loop_ticks):
		_fail("phase %s warning floors are malformed" % phase_id)
		return false
	if not _validate_phase_records(phase.get("boss_movement"), 3, loop_ticks, true) or not _validate_phase_records(phase.get("timeline"), 4, loop_ticks, false):
		_fail("phase %s movement or timeline records are malformed" % phase_id)
		return false
	if not (phase.get("difficulties") is Dictionary):
		_fail("phase %s difficulties are missing" % phase_id)
		return false
	for difficulty in ["normal", "hard"]:
		if not (phase.difficulties.get(difficulty) is Dictionary) or not _validate_profile_source(phase, phase.difficulties[difficulty], difficulty, seen_emitters):
			return false
	var normal_profile: Dictionary = phase.difficulties.normal
	var hard_profile: Dictionary = phase.difficulties.hard
	if String(normal_profile.topology_id) == String(hard_profile.topology_id) or normal_profile.route_graph == hard_profile.route_graph:
		_fail("phase %s Normal/Hard route topology must differ structurally" % phase_id)
		return false
	return true

func _validate_phase_records(value: Variant, expected_count: int, loop_ticks: int, movement: bool) -> bool:
	if not (value is Array) or value.size() != expected_count:
		return false
	var seen := {}
	var previous_tick := -1
	for record_value in value:
		if not (record_value is Dictionary):
			return false
		var record: Dictionary = record_value
		var record_id := String(record.get("event", ""))
		if typeof(record.get("event")) != TYPE_STRING or record_id.is_empty() or seen.has(record_id):
			return false
		seen[record_id] = true
		var maximum_tick := loop_ticks - 1 if movement else loop_ticks
		if not _is_integral_number(record.get("tick"), previous_tick, maximum_tick):
			return false
		previous_tick = _as_int(record.tick)
		if movement:
			if (
				not _is_vector_array(record.get("from"))
				or not _is_vector_array(record.get("to"))
				or not _is_integral_number(record.get("duration_ticks"), 1, loop_ticks)
				or typeof(record.get("easing")) != TYPE_STRING
				or String(record.easing).is_empty()
				or not _is_integral_number(record.get("warning_lead_ticks"), 0, loop_ticks)
			):
				return false
		else:
			if typeof(record.get("action")) != TYPE_STRING or String(record.action).is_empty() or typeof(record.get("warning")) != TYPE_STRING:
				return false
	return true

func _validate_profile_source(phase: Dictionary, profile: Dictionary, difficulty: String, seen_emitters: Dictionary) -> bool:
	var phase_id := String(phase.id)
	if typeof(profile.get("topology_id")) != TYPE_STRING or String(profile.topology_id).is_empty() or not _validate_route_graph(profile.get("route_graph")):
		_fail("phase %s %s topology or route graph is malformed" % [phase_id, difficulty])
		return false
	if not _is_finite_number(profile.get("safe_route_width_px")) or float(profile.safe_route_width_px) <= 0.0 or not _is_integral_number(profile.get("peak_active_bullets"), 1, DanmakuPatternRuntime.MAX_BULLETS_PER_LOOP):
		_fail("phase %s %s authored budgets are malformed" % [phase_id, difficulty])
		return false
	if not (profile.get("emitters") is Array) or profile.emitters.is_empty() or profile.emitters.size() > DanmakuPatternRuntime.MAX_EMITTERS:
		_fail("phase %s %s emitters are missing or exceed caps" % [phase_id, difficulty])
		return false
	var loop_total := 0
	for emitter_value in profile.emitters:
		if not (emitter_value is Dictionary) or not _validate_emitter_source(phase, profile, emitter_value, difficulty, seen_emitters):
			return false
		var emitter: Dictionary = emitter_value
		loop_total += _as_int(emitter.bursts_per_loop) * _as_int(emitter.shots_per_burst)
	if loop_total > DanmakuPatternRuntime.MAX_BULLETS_PER_LOOP:
		_fail("phase %s %s exceeds the bullet-per-loop cap" % [phase_id, difficulty])
		return false
	return true

func _validate_route_graph(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var graph: Dictionary = value
	if not _is_string_array(graph.get("nodes"), false) or not _array_has_unique_strings(graph.nodes):
		return false
	if not (graph.get("directed_edges") is Array) or graph.directed_edges.is_empty():
		return false
	for edge in graph.directed_edges:
		if not (edge is Array) or edge.size() != 2 or not _is_string_array(edge, false):
			return false
	return _is_source_tree_valid(graph)

func _validate_emitter_source(phase: Dictionary, profile: Dictionary, source: Dictionary, difficulty: String, seen_emitters: Dictionary) -> bool:
	var phase_id := String(phase.id)
	var emitter_id := String(source.get("id", ""))
	if typeof(source.get("id")) != TYPE_STRING or emitter_id.is_empty() or seen_emitters.has(emitter_id):
		_fail("phase %s contains a missing or duplicate emitter ID" % phase_id)
		return false
	seen_emitters[emitter_id] = true
	var primitive := String(source.get("primitive", ""))
	if primitive not in DanmakuPatternRuntime.PERMITTED_PRIMITIVES or String(source.get("anchor", "")) not in ANCHORS:
		_fail("phase %s emitter %s has an unknown primitive or anchor" % [phase_id, emitter_id])
		return false
	if typeof(source.get("family")) != TYPE_STRING or String(source.family).is_empty() or not _is_color_array(source.get("color_rgba")):
		_fail("phase %s emitter %s family or color is malformed" % [phase_id, emitter_id])
		return false
	for key in ["radius", "speed", "angle_deg", "angle_step_deg", "spread_deg"]:
		if not _is_finite_number(source.get(key)):
			_fail("phase %s emitter %s has malformed %s" % [phase_id, emitter_id, key])
			return false
	if float(source.radius) <= 0.0 or float(source.speed) < 0.0 or float(source.spread_deg) < 0.0:
		_fail("phase %s emitter %s has invalid radius, speed, or spread" % [phase_id, emitter_id])
		return false
	var loop_ticks := _as_int(phase.loop_ticks)
	for key in ["start_tick", "interval_ticks", "bursts_per_loop", "shots_per_burst", "lifetime_ticks"]:
		var minimum := 0 if key == "start_tick" else 1
		var maximum := loop_ticks
		if key == "bursts_per_loop":
			maximum = DanmakuPatternRuntime.MAX_BURSTS_PER_EMITTER
		elif key == "shots_per_burst":
			maximum = DanmakuPatternRuntime.MAX_SHOTS_PER_BURST
		if not _is_integral_number(source.get(key), minimum, maximum):
			_fail("phase %s emitter %s has malformed schedule field %s" % [phase_id, emitter_id, key])
			return false
	var final_burst := _as_int(source.start_tick) + (_as_int(source.bursts_per_loop) - 1) * _as_int(source.interval_ticks)
	if final_burst >= loop_ticks:
		_fail("phase %s emitter %s schedule exceeds loop_ticks" % [phase_id, emitter_id])
		return false
	if not (source.get("warning") is Dictionary):
		_fail("phase %s emitter %s warning is missing" % [phase_id, emitter_id])
		return false
	var warning: Dictionary = source.warning
	if not _is_integral_number(warning.get("lead_ticks"), 0, loop_ticks) or typeof(warning.get("visual")) != TYPE_STRING or typeof(warning.get("collision_disabled_during_warning")) != TYPE_BOOL:
		_fail("phase %s emitter %s warning is malformed" % [phase_id, emitter_id])
		return false
	if not (source.get("motion") is Dictionary) or typeof(source.motion.get("type")) != TYPE_STRING or String(source.motion.type).is_empty() or not _is_finite_number(source.motion.get("acceleration")) or not _is_source_tree_valid(source.motion):
		_fail("phase %s emitter %s motion is malformed" % [phase_id, emitter_id])
		return false
	if not (source.get("routing") is Dictionary) or typeof(source.routing.get("mode")) != TYPE_STRING or String(source.routing.mode).is_empty() or not _is_source_tree_valid(source.routing):
		_fail("phase %s emitter %s routing is malformed" % [phase_id, emitter_id])
		return false
	var routing: Dictionary = source.routing
	match primitive:
		"rebound_bead":
			if not _is_integral_number(routing.get("max_reflections"), 1, DanmakuPatternRuntime.MAX_REFLECTIONS) or not _is_finite_number(routing.get("turn_angle_deg")):
				_fail("phase %s emitter %s rebound routing is malformed" % [phase_id, emitter_id])
				return false
		"grid_edge":
			var has_lanes := routing.get("lane_x") is Array and _is_finite_number_array(routing.lane_x, -1) and routing.lane_x.size() >= 2
			var has_grid := _is_integral_number(routing.get("grid_columns"), 1, 128)
			if not has_lanes and not has_grid:
				_fail("phase %s emitter %s grid geometry is malformed" % [phase_id, emitter_id])
				return false
		"rhythm_pulse":
			if not _is_integral_number(routing.get("beat_ticks"), 1, loop_ticks):
				_fail("phase %s emitter %s rhythm routing is malformed" % [phase_id, emitter_id])
				return false
		"delayed_seed":
			if not _is_integral_number(routing.get("activation_delay_ticks"), 1, _as_int(source.lifetime_ticks) - 1):
				_fail("phase %s emitter %s delayed routing is malformed" % [phase_id, emitter_id])
				return false
	return true

func _validate_projected_runtime_contracts() -> bool:
	var stage_probe := StageEncounterRuntime.new()
	if not stage_probe.configure(_stage_spec):
		_fail("projected stage rejected by frozen runtime: %s" % [stage_probe.validation_errors()])
		return false
	for phase_id in PHASE_IDS:
		var phase: Dictionary = _phase_specs[phase_id]
		for difficulty in ["normal", "hard"]:
			var phase_probe := DanmakuPatternRuntime.new()
			if not phase_probe.configure(phase, difficulty, 1):
				_fail("projected phase %s %s rejected by frozen runtime: %s" % [phase_id, difficulty, phase_probe.validation_errors()])
				return false
	return true

func _project_stage(source_stage: Dictionary) -> Dictionary:
	var events: Array = []
	for index in range(STAGE_EVENT_IDS.size()):
		var source_event: Dictionary = source_stage.events[index]
		var event_id := String(source_event.id)
		var event := {
			"id": event_id,
			"tick": RUNTIME_TICKS[index],
			"kind": "encounter_gate" if event_id in ["s2_b06", "s2_b18"] else String(source_event.event_type),
			"encounter_role": "midboss" if index >= 6 and index <= 10 else "stage",
			"phase_cursor": index,
			"payload": _project_event_payload(source_event, index),
		}
		if event_id == "s2_b06":
			event["gate"] = {"encounter_role": "midboss", "phase_cursor": 0, "completion_token": "stage2_midboss_cleared"}
		elif event_id == "s2_b18":
			event["gate"] = {"encounter_role": "boss", "phase_cursor": 0, "completion_token": "stage2_boss_cleared"}
		events.append(event)
	return {"schema_version": 1, "stage_id": "stage_2_yokai_market", "events": events}

func _project_event_payload(source_event: Dictionary, index: int) -> Dictionary:
	var warning: Dictionary = source_event.warning
	var formation: Dictionary = source_event.formation
	var payload := {
		"authored_tick": _as_int(source_event.authored_tick),
		"segment_id": String(source_event.segment_id),
		"event_type": String(source_event.event_type),
		"formation_id": String(formation.id),
		"warning": {"lead_ticks": _as_int(warning.lead_ticks), "visual": String(warning.visual), "future_path_px": _as_int(warning.future_path_px)},
		"spawns": _project_spawns(source_event.spawns),
		"completion": (source_event.completion as Dictionary).duplicate(true),
		"score_route_hooks": (source_event.score_route_hooks as Array).duplicate(true),
		"telemetry_hooks": (source_event.telemetry_hooks as Array).duplicate(true),
		"dispatch_scope": "encounter_evidence" if index >= 6 and index <= 10 else "stage",
	}
	if index == 11:
		payload["dispatch_scope"] = "stage_resume"
	return payload

func _project_spawns(source_spawns: Array) -> Array:
	var result: Array = []
	for source_spawn_value in source_spawns:
		var source_spawn: Dictionary = source_spawn_value
		var movement: Dictionary = source_spawn.movement
		result.append({
			"id": String(source_spawn.id),
			"enemy_id": String(source_spawn.enemy_id),
			"position": _vector2(source_spawn.position),
			"movement": {"path": String(movement.path), "to": _vector2(movement.to), "duration_ticks": _as_int(movement.duration_ticks)},
			"pattern": _project_stage_pattern(source_spawn.pattern),
			"drop_item_ids": (source_spawn.drop_item_ids as Array).duplicate(true),
		})
	return result

func _project_stage_pattern(source: Dictionary) -> Dictionary:
	return {
		"primitive": String(source.primitive),
		"start_delay_ticks": _as_int(source.start_delay_ticks),
		"interval_ticks": _as_int(source.interval_ticks),
		"shots_per_burst": _as_int(source.shots_per_burst),
		"speed": float(source.speed),
		"routing": String(source.routing),
	}

func _project_phase(source_phase: Dictionary) -> Dictionary:
	var result := {
		"schema_version": 1,
		"id": String(source_phase.id),
		"deterministic_random_stream_id": String(source_phase.deterministic_random_stream_id),
		"loop_ticks": _as_int(source_phase.loop_ticks),
		"warning_ticks": {"normal": _as_int(source_phase.warning_ticks.normal), "hard": _as_int(source_phase.warning_ticks.hard)},
		"boss_movement": _project_boss_movement(source_phase),
		"timeline": _project_timeline(source_phase),
		"difficulties": {},
	}
	for difficulty in ["normal", "hard"]:
		result.difficulties[difficulty] = _project_profile(source_phase, source_phase.difficulties[difficulty], difficulty)
	return result

func _project_boss_movement(source_phase: Dictionary) -> Array:
	var result: Array = []
	for source_value in source_phase.boss_movement:
		var source: Dictionary = source_value
		result.append({"id": String(source.event), "tick": _as_int(source.tick), "position": _vector2(source.to)})
	return result

func _project_timeline(source_phase: Dictionary) -> Array:
	var result: Array = []
	var loop_ticks := _as_int(source_phase.loop_ticks)
	for index in range(source_phase.timeline.size()):
		var source: Dictionary = source_phase.timeline[index]
		result.append({"id": "%s_timeline_%d" % [String(source_phase.id), index], "tick": mini(_as_int(source.tick), loop_ticks - 1), "tag": String(source.event), "action": String(source.action)})
	return result

func _project_profile(source_phase: Dictionary, source_profile: Dictionary, difficulty: String) -> Dictionary:
	var emitters: Array = []
	for source_emitter_value in source_profile.emitters:
		emitters.append(_project_emitter(source_phase, source_profile, source_emitter_value, difficulty))
	return {"topology_id": String(source_profile.topology_id), "emitters": emitters}

func _project_emitter(source_phase: Dictionary, source_profile: Dictionary, source: Dictionary, difficulty: String) -> Dictionary:
	var primitive := String(source.primitive)
	var routing: Dictionary = source.routing
	var warning_floor := _as_int(source_phase.warning_ticks[difficulty])
	var result := {
		"id": String(source.id),
		"primitive": primitive,
		"start_tick": _as_int(source.start_tick),
		"interval_ticks": _as_int(source.interval_ticks),
		"bursts_per_loop": _as_int(source.bursts_per_loop),
		"shots_per_burst": _as_int(source.shots_per_burst),
		"anchor": ANCHORS[String(source.anchor)],
		"family": String(source.family),
		"color_rgba": _color(source.color_rgba),
		"radius": float(source.radius),
		"lifetime_ticks": _as_int(source.lifetime_ticks),
		"speed": float(source.speed),
		"warning": {"lead_ticks": maxi(_as_int(source.warning.lead_ticks), warning_floor)},
		"angle_degrees": float(source.angle_deg),
		"burst_angle_step_degrees": float(source.angle_step_deg),
		"spread_degrees": float(source.spread_deg),
	}
	match primitive:
		"rebound_bead":
			result["reflection"] = {"axes": _reflection_axes(source_phase, difficulty), "max_reflections": _as_int(routing.max_reflections), "bounds": COMBAT_BOUNDS}
		"grid_edge":
			result["routing"] = _grid_direction(source_profile, source, difficulty)
			result["spacing"] = _grid_spacing(source_profile, source)
		"lane_fan":
			result["aim_mode"] = "fixed"
		"rhythm_pulse":
			result["turn_rate"] = _turn_rate(routing)
		"delayed_seed":
			result["delay_ticks"] = _as_int(routing.activation_delay_ticks)
			result["turn_rate"] = _delayed_turn_rate(source, routing)
	return result

func _reflection_axes(source_phase: Dictionary, difficulty: String) -> String:
	if difficulty == "hard" and source_phase.difficulties.normal.route_graph != source_phase.difficulties.hard.route_graph:
		return "xy"
	return "x"

func _grid_direction(profile: Dictionary, source: Dictionary, difficulty: String) -> String:
	var routing: Dictionary = source.routing
	var mode := String(routing.mode)
	if mode.contains("rotate"):
		return "left" if difficulty == "hard" else "right"
	if String(source.anchor) == "boss_left_satellite":
		return "right"
	if _graph_edge_count(profile) > 3:
		return "left" if difficulty == "hard" else "down"
	return "down"

func _grid_spacing(profile: Dictionary, source: Dictionary) -> float:
	var routing: Dictionary = source.routing
	if routing.get("lane_x") is Array and routing.lane_x.size() >= 2:
		return absf(float(routing.lane_x[1]) - float(routing.lane_x[0]))
	if routing.has("grid_columns"):
		return COMBAT_BOUNDS.size.x / float(_as_int(routing.grid_columns))
	return float(profile.safe_route_width_px) / float(_as_int(source.shots_per_burst))

func _turn_rate(routing: Dictionary) -> float:
	return 360.0 / float(_as_int(routing.beat_ticks))

func _delayed_turn_rate(source: Dictionary, routing: Dictionary) -> float:
	var delay := float(_as_int(routing.activation_delay_ticks))
	if _is_finite_number(routing.get("rotation_deg")):
		return float(routing.rotation_deg) / delay
	if _is_finite_number(routing.get("axis_deg")):
		return float(routing.axis_deg) / delay
	if routing.get("axis_options_deg") is Array and not routing.axis_options_deg.is_empty() and _is_finite_number(routing.axis_options_deg[routing.axis_options_deg.size() - 1]):
		return float(routing.axis_options_deg[routing.axis_options_deg.size() - 1]) / delay
	return float(source.angle_step_deg) / delay

func _graph_edge_count(profile: Dictionary) -> int:
	return (profile.route_graph.directed_edges as Array).size()

func _vector2(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

func _color(value: Array) -> Color:
	return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]))

func _build_metadata(source_stage: Dictionary) -> Dictionary:
	var event_metadata := {}
	for index in range(STAGE_EVENT_IDS.size()):
		var source_event: Dictionary = source_stage.events[index]
		event_metadata[String(source_event.id)] = {
			"authored_tick": _as_int(source_event.authored_tick),
			"runtime_tick": RUNTIME_TICKS[index],
			"dispatch_scope": "encounter_evidence" if index >= 6 and index <= 10 else ("stage_resume" if index == 11 else "stage"),
			"encounter_role": "midboss" if index >= 6 and index <= 10 else "stage",
			"source_event": source_event.duplicate(true),
		}
	var phase_metadata := {}
	for source_phase_value in _source_content.phases:
		var source_phase: Dictionary = source_phase_value
		phase_metadata[String(source_phase.id)] = {
			"encounter_role": String(source_phase.encounter_role),
			"source_phase": source_phase.duplicate(true),
			"normal_route_graph": (source_phase.difficulties.normal.route_graph as Dictionary).duplicate(true),
			"hard_route_graph": (source_phase.difficulties.hard.route_graph as Dictionary).duplicate(true),
			"normal_topology_id": String(source_phase.difficulties.normal.topology_id),
			"hard_topology_id": String(source_phase.difficulties.hard.topology_id),
		}
	return {
		"artifact_id": String(_source_content.artifact_id),
		"source_bindings": (_source_content.source_bindings as Array).duplicate(true),
		"anchor_positions": ANCHORS.duplicate(true),
		"event_metadata": event_metadata,
		"phase_metadata": phase_metadata,
		"phase_sequences": {"midboss": PHASE_IDS.slice(0, 2), "boss": PHASE_IDS.slice(2, 6)},
		"completion_tokens": {"midboss": "stage2_midboss_cleared", "boss": "stage2_boss_cleared"},
	}

func _is_integral_number(value: Variant, minimum: int, maximum: int) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not _is_finite_number(value):
		return false
	var numeric := float(value)
	return floor(numeric) == numeric and numeric >= float(minimum) and numeric <= float(maximum)

func _as_int(value: Variant) -> int:
	return int(float(value))

func _is_finite_number(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var numeric := float(value)
	return not is_nan(numeric) and not is_inf(numeric)

func _is_vector_array(value: Variant) -> bool:
	return _is_finite_number_array(value, 2)

func _is_color_array(value: Variant) -> bool:
	if not _is_finite_number_array(value, 4):
		return false
	for channel in value:
		if float(channel) < 0.0 or float(channel) > 1.0:
			return false
	return true

func _is_finite_number_array(value: Variant, exact_size: int) -> bool:
	if not (value is Array) or (exact_size >= 0 and value.size() != exact_size) or value.is_empty():
		return false
	for entry in value:
		if not _is_finite_number(entry):
			return false
	return true

func _is_string_array(value: Variant, allow_empty: bool) -> bool:
	if not (value is Array) or (not allow_empty and value.is_empty()):
		return false
	for entry in value:
		if typeof(entry) != TYPE_STRING or String(entry).is_empty():
			return false
	return true

func _array_has_unique_strings(value: Array) -> bool:
	var seen := {}
	for entry in value:
		if seen.has(String(entry)):
			return false
		seen[String(entry)] = true
	return true

func _is_source_tree_valid(value: Variant, depth: int = 0) -> bool:
	if depth > 24:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return true
		TYPE_INT, TYPE_FLOAT:
			return _is_finite_number(value)
		TYPE_ARRAY:
			for entry in value:
				if not _is_source_tree_valid(entry, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if typeof(key) != TYPE_STRING or not _is_source_tree_valid(value[key], depth + 1):
					return false
			return true
	return false
