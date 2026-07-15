extends RefCounted
class_name Stage2ContentAdapter

## Adapts the authored Stage 2 choreography into the two frozen runtime schemas.
## Rich choreography remains auditable in metadata; runtime dictionaries contain
## only the keys accepted by StageEncounterRuntime and DanmakuPatternRuntime.

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
		var phase := _project_phase(source_phase)
		if phase.is_empty():
			_clear_runtime_outputs()
			return false
		_phase_specs[String(phase.id)] = phase
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
	if int(content.get("schema_version", -1)) != 1:
		_fail("schema_version must be integer 1")
		return false
	if not (content.get("stage") is Dictionary) or not (content.get("phases") is Array):
		_fail("stage and phases are required")
		return false
	var stage: Dictionary = content.stage
	if String(stage.get("stage_id", "")) != "yokai_market" or not (stage.get("events") is Array):
		_fail("Stage 2 identity or events are missing")
		return false
	if stage.events.size() != STAGE_EVENT_IDS.size():
		_fail("Stage 2 requires exactly 18 authored events")
		return false
	for index in range(STAGE_EVENT_IDS.size()):
		if not (stage.events[index] is Dictionary):
			_fail("stage event %d is not a Dictionary" % index)
			return false
		var event: Dictionary = stage.events[index]
		if String(event.get("id", "")) != STAGE_EVENT_IDS[index] or typeof(event.get("authored_tick")) != TYPE_INT or int(event.authored_tick) != AUTHORED_TICKS[index]:
			_fail("stage event order, identity, or authored tick is malformed at %d" % index)
			return false
		if String(event.get("event_type", "")).is_empty() or not (event.get("spawns") is Array):
			_fail("stage event %s is incomplete" % String(event.get("id", "")))
			return false
	if content.phases.size() != PHASE_IDS.size():
		_fail("Stage 2 requires exactly six phases")
		return false
	for index in range(PHASE_IDS.size()):
		if not (content.phases[index] is Dictionary):
			_fail("phase %d is not a Dictionary" % index)
			return false
		var phase: Dictionary = content.phases[index]
		if String(phase.get("id", "")) != PHASE_IDS[index]:
			_fail("phase order or identity is malformed at %d" % index)
			return false
		if typeof(phase.get("loop_ticks")) != TYPE_INT or int(phase.loop_ticks) <= 0 or not (phase.get("difficulties") is Dictionary):
			_fail("phase %s is missing loop or difficulty data" % String(phase.get("id", "")))
			return false
		for difficulty in ["normal", "hard"]:
			if not (phase.difficulties.get(difficulty) is Dictionary):
				_fail("phase %s is missing %s" % [String(phase.id), difficulty])
				return false
			var profile: Dictionary = phase.difficulties[difficulty]
			if String(profile.get("topology_id", "")).is_empty() or not (profile.get("route_graph") is Dictionary) or not (profile.get("emitters") is Array) or profile.emitters.is_empty():
				_fail("phase %s %s profile is incomplete" % [String(phase.id), difficulty])
				return false
			for source_emitter_value in profile.emitters:
				if not (source_emitter_value is Dictionary):
					_fail("phase %s has a non-Dictionary emitter" % String(phase.id))
					return false
				var source_emitter: Dictionary = source_emitter_value
				if String(source_emitter.get("anchor", "")) not in ANCHORS or String(source_emitter.get("primitive", "")) not in ["rebound_bead", "grid_edge", "lane_fan", "rhythm_pulse", "delayed_seed"]:
					_fail("phase %s emitter %s has an unknown anchor or primitive" % [String(phase.id), String(source_emitter.get("id", ""))])
					return false
				for key in ["start_tick", "interval_ticks", "bursts_per_loop", "shots_per_burst", "lifetime_ticks"]:
					if typeof(source_emitter.get(key)) != TYPE_INT:
						_fail("phase %s emitter %s has non-integral %s" % [String(phase.id), String(source_emitter.get("id", "")), key])
						return false
	return true

func _project_stage(source_stage: Dictionary) -> Dictionary:
	var events: Array = []
	for index in range(STAGE_EVENT_IDS.size()):
		var source_event: Dictionary = source_stage.events[index]
		var event_id := String(source_event.id)
		var payload := _project_event_payload(source_event, index)
		var event := {
			"id": event_id,
			"tick": RUNTIME_TICKS[index],
			"kind": "encounter_gate" if event_id in ["s2_b06", "s2_b18"] else String(source_event.event_type),
			"encounter_role": "midboss" if index >= 6 and index <= 10 else "stage",
			"phase_cursor": index,
			"payload": payload,
		}
		if event_id == "s2_b06":
			event["gate"] = {"encounter_role": "midboss", "phase_cursor": 0, "completion_token": "stage2_midboss_cleared"}
		elif event_id == "s2_b18":
			event["gate"] = {"encounter_role": "boss", "phase_cursor": 0, "completion_token": "stage2_boss_cleared"}
		events.append(event)
	return {"schema_version": 1, "stage_id": "stage_2_yokai_market", "events": events}

func _project_event_payload(source_event: Dictionary, index: int) -> Dictionary:
	var warning: Dictionary = source_event.get("warning", {})
	var formation: Dictionary = source_event.get("formation", {})
	var payload := {
		"authored_tick": int(source_event.authored_tick),
		"segment_id": String(source_event.get("segment_id", "")),
		"event_type": String(source_event.event_type),
		"formation_id": String(formation.get("id", "")),
		"warning": {"lead_ticks": int(warning.get("lead_ticks", 0)), "visual": String(warning.get("visual", "")), "future_path_px": int(warning.get("future_path_px", 0))},
		"spawns": _project_spawns(source_event.spawns),
		"completion": (source_event.get("completion", {}) as Dictionary).duplicate(true),
		"score_route_hooks": (source_event.get("score_route_hooks", []) as Array).duplicate(true),
		"telemetry_hooks": (source_event.get("telemetry_hooks", []) as Array).duplicate(true),
		"dispatch_scope": "encounter_evidence" if index >= 6 and index <= 10 else "stage",
	}
	if index == 11:
		payload["dispatch_scope"] = "stage_resume"
	return payload

func _project_spawns(source_spawns: Array) -> Array:
	var result: Array = []
	for source_spawn_value in source_spawns:
		var source_spawn: Dictionary = source_spawn_value
		var movement: Dictionary = source_spawn.get("movement", {})
		result.append({
			"id": String(source_spawn.get("id", "")),
			"enemy_id": String(source_spawn.get("enemy_id", "")),
			"position": _vector2(source_spawn.get("position", [])),
			"movement": {"path": String(movement.get("path", "")), "to": _vector2(movement.get("to", [])), "duration_ticks": int(movement.get("duration_ticks", 0))},
			"pattern": (source_spawn.get("pattern", {}) as Dictionary).duplicate(true),
			"drop_item_ids": (source_spawn.get("drop_item_ids", []) as Array).duplicate(true),
		})
	return result

func _project_phase(source_phase: Dictionary) -> Dictionary:
	var result := {
		"schema_version": 1,
		"id": String(source_phase.id),
		"deterministic_random_stream_id": String(source_phase.deterministic_random_stream_id),
		"loop_ticks": int(source_phase.loop_ticks),
		"warning_ticks": {"normal": int(source_phase.warning_ticks.normal), "hard": int(source_phase.warning_ticks.hard)},
		"boss_movement": _project_boss_movement(source_phase),
		"timeline": _project_timeline(source_phase),
		"difficulties": {},
	}
	for difficulty in ["normal", "hard"]:
		var source_profile: Dictionary = source_phase.difficulties[difficulty]
		result.difficulties[difficulty] = _project_profile(source_phase, source_profile, difficulty)
	return result

func _project_boss_movement(source_phase: Dictionary) -> Array:
	var result: Array = []
	for source_value in source_phase.boss_movement:
		var source: Dictionary = source_value
		result.append({"id": String(source.event), "tick": int(source.tick), "position": _vector2(source.to)})
	return result

func _project_timeline(source_phase: Dictionary) -> Array:
	var result: Array = []
	for index in range(source_phase.timeline.size()):
		var source: Dictionary = source_phase.timeline[index]
		result.append({"id": "%s_timeline_%d" % [String(source_phase.id), index], "tick": min(int(source.tick), int(source_phase.loop_ticks) - 1), "tag": String(source.event), "action": String(source.action)})
	return result

func _project_profile(source_phase: Dictionary, source_profile: Dictionary, difficulty: String) -> Dictionary:
	var emitters: Array = []
	for source_emitter_value in source_profile.emitters:
		emitters.append(_project_emitter(source_phase, source_profile, source_emitter_value as Dictionary, difficulty))
	return {"topology_id": String(source_profile.topology_id), "emitters": emitters}

func _project_emitter(source_phase: Dictionary, source_profile: Dictionary, source: Dictionary, difficulty: String) -> Dictionary:
	var primitive := String(source.primitive)
	var routing: Dictionary = source.get("routing", {})
	var result := {
		"id": String(source.id),
		"primitive": primitive,
		"start_tick": int(source.start_tick),
		"interval_ticks": int(source.interval_ticks),
		"bursts_per_loop": int(source.bursts_per_loop),
		"shots_per_burst": int(source.shots_per_burst),
		"anchor": ANCHORS[String(source.anchor)],
		"family": String(source.family),
		"color_rgba": _color(source.color_rgba),
		"radius": float(source.radius),
		"lifetime_ticks": int(source.lifetime_ticks),
		"speed": float(source.speed),
		"warning": {"lead_ticks": int(source.warning.lead_ticks)},
		"angle_degrees": float(source.angle_deg),
		"burst_angle_step_degrees": float(source.get("angle_step_deg", 0.0)),
		"spread_degrees": float(source.get("spread_deg", 0.0)),
	}
	match primitive:
		"rebound_bead":
			result["reflection"] = {"axes": _reflection_axes(source_profile, difficulty), "max_reflections": max(1, int(routing.get("max_reflections", 1))), "bounds": COMBAT_BOUNDS}
		"grid_edge":
			result["routing"] = _grid_direction(source_profile, source, difficulty)
			result["spacing"] = _grid_spacing(source_profile, source)
		"lane_fan":
			result["aim_mode"] = "fixed"
		"rhythm_pulse":
			result["turn_rate"] = _turn_rate(routing)
		"delayed_seed":
			result["delay_ticks"] = _delay_ticks(routing, int(source.lifetime_ticks))
			result["turn_rate"] = _turn_rate(routing)
	return result

func _reflection_axes(profile: Dictionary, difficulty: String) -> String:
	# The authored hard profile declares topology_change and a different graph;
	# xy reflection is its strict-runtime projection, while normal retains x.
	if difficulty == "hard" and (profile.has("topology_change") or _graph_edge_count(profile) > 3):
		return "xy"
	return "x"

func _grid_direction(profile: Dictionary, source: Dictionary, difficulty: String) -> String:
	var routing: Dictionary = source.get("routing", {})
	var mode := String(routing.get("mode", ""))
	if mode.contains("rotate"):
		return "left" if difficulty == "hard" else "right"
	if source.get("anchor", "") == "boss_left_satellite":
		return "right"
	if _graph_edge_count(profile) > 3:
		return "left" if difficulty == "hard" else "down"
	return "down"

func _grid_spacing(profile: Dictionary, source: Dictionary) -> float:
	var routing: Dictionary = source.get("routing", {})
	if routing.get("lane_x") is Array and routing.lane_x.size() >= 2:
		return maxf(1.0, absf(float(routing.lane_x[1]) - float(routing.lane_x[0])))
	var columns := int(routing.get("grid_columns", 0))
	if columns > 0:
		return maxf(1.0, COMBAT_BOUNDS.size.x / float(columns))
	return maxf(1.0, float(profile.get("safe_route_width_px", 24)) / float(max(1, int(source.shots_per_burst))))

func _turn_rate(routing: Dictionary) -> float:
	var beat_ticks := max(1, int(routing.get("beat_ticks", 60)))
	return 360.0 / float(beat_ticks)

func _delay_ticks(routing: Dictionary, lifetime: int) -> int:
	return clampi(int(routing.get("activation_delay_ticks", 30)), 1, lifetime - 1)

func _graph_edge_count(profile: Dictionary) -> int:
	var graph: Dictionary = profile.get("route_graph", {})
	return (graph.get("directed_edges", []) as Array).size()

func _vector2(value: Variant) -> Vector2:
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO

func _color(value: Variant) -> Color:
	if value is Array and value.size() == 4:
		return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	return Color.WHITE

func _build_metadata(source_stage: Dictionary) -> Dictionary:
	var event_metadata := {}
	for index in range(STAGE_EVENT_IDS.size()):
		var source_event: Dictionary = source_stage.events[index]
		event_metadata[String(source_event.id)] = {
			"authored_tick": int(source_event.authored_tick),
			"runtime_tick": RUNTIME_TICKS[index],
			"dispatch_scope": "encounter_evidence" if index >= 6 and index <= 10 else ("stage_resume" if index == 11 else "stage"),
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
		"artifact_id": String(_source_content.get("artifact_id", "")),
		"source_bindings": (_source_content.get("source_bindings", []) as Array).duplicate(true),
		"anchor_positions": ANCHORS.duplicate(true),
		"event_metadata": event_metadata,
		"phase_metadata": phase_metadata,
		"phase_sequences": {"midboss": PHASE_IDS.slice(0, 2), "boss": PHASE_IDS.slice(2, 6)},
		"completion_tokens": {"midboss": "stage2_midboss_cleared", "boss": "stage2_boss_cleared"},
	}
