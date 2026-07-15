extends RefCounted
class_name Stage2EncounterController

const StageEncounterRuntime := preload("res://scripts/runtime/stage_encounter_runtime.gd")
const DanmakuPatternRuntime := preload("res://scripts/runtime/danmaku_pattern_runtime.gd")

const SNAPSHOT_VERSION := 1
const STAGE_ID := "stage_2_yokai_market"
const STAGE_EVENT_IDS := [
	"s2_b01", "s2_b02", "s2_b03", "s2_b04", "s2_b05", "s2_b06",
	"s2_b07", "s2_b08", "s2_b09", "s2_b10", "s2_b11", "s2_b12",
	"s2_b13", "s2_b14", "s2_b15", "s2_b16", "s2_b17", "s2_b18",
]
const STAGE_RUNTIME_TICKS := [0, 150, 300, 450, 600, 750, 751, 751, 751, 751, 751, 751, 901, 1051, 1201, 1351, 1501, 1651]
const PHASE_IDS := [
	"stage_2_midboss_nonspell_1", "stage_2_midboss_spell_1",
	"stage_2_boss_nonspell_1", "stage_2_boss_spell_1", "stage_2_boss_spell_2", "stage_2_boss_spell_3",
]
const MIDBOSS_PHASE_IDS := ["stage_2_midboss_nonspell_1", "stage_2_midboss_spell_1"]
const BOSS_PHASE_IDS := ["stage_2_boss_nonspell_1", "stage_2_boss_spell_1", "stage_2_boss_spell_2", "stage_2_boss_spell_3"]
const COMPLETION_TOKENS := {
	"midboss": "stage2_midboss_cleared",
	"boss": "stage2_boss_cleared",
}
const GATE_EVENT_IDS := {
	"midboss": "s2_b06",
	"boss": "s2_b18",
}
const ENCOUNTER_KINDS := ["stage", "midboss", "boss", "complete"]
const RESOLUTION_OUTCOMES := ["clear", "timeout"]

var _package: Dictionary = {}
var _stage_spec: Dictionary = {}
var _phase_specs: Array = []
var _metadata: Dictionary = {}
var _difficulty := ""
var _gameplay_seed := 0
var _stage_runtime: RefCounted = null
var _phase_runtime: RefCounted = null
var _encounter_kind := "stage"
var _active_phase_index := -1
var _resolved_phase_ids: Array[String] = []
var _configured := false
var _validation_errors: Array[String] = []
var _hard_error := ""

func configure(stage2_package: Dictionary, difficulty: String, gameplay_seed: int) -> bool:
	_clear_configuration()
	_difficulty = difficulty.to_lower()
	_gameplay_seed = gameplay_seed
	_validation_errors = _validate_package(stage2_package)
	if _difficulty not in ["normal", "hard"]:
		_validation_errors.append("difficulty must be normal or hard")
	if not _validation_errors.is_empty():
		_hard_error = "configuration rejected: %s" % "; ".join(PackedStringArray(_validation_errors))
		return false
	_package = stage2_package.duplicate(true)
	_stage_spec = _package.stage_spec.duplicate(true)
	_phase_specs = _package.phase_specs.duplicate(true)
	_metadata = _package.metadata.duplicate(true)
	var stage_probe := StageEncounterRuntime.new()
	if not stage_probe.configure(_stage_spec):
		_validation_errors.append("StageEncounterRuntime rejected Stage 2 package: %s" % [stage_probe.validation_errors()])
		_hard_error = "configuration rejected: %s" % "; ".join(PackedStringArray(_validation_errors))
		_clear_runtime_owners()
		return false
	for phase_spec_value in _phase_specs:
		var phase_probe := DanmakuPatternRuntime.new()
		if not phase_probe.configure(phase_spec_value, _difficulty, _gameplay_seed):
			_validation_errors.append("DanmakuPatternRuntime rejected phase %s: %s" % [String(phase_spec_value.get("id", "")), phase_probe.validation_errors()])
			_hard_error = "configuration rejected: %s" % "; ".join(PackedStringArray(_validation_errors))
			_clear_runtime_owners()
			return false
	_configured = true
	return reset()

func is_configured() -> bool:
	return _configured

func validation_errors() -> Array[String]:
	return _validation_errors.duplicate()

func has_hard_error() -> bool:
	return not _hard_error.is_empty()

func last_error() -> String:
	return _hard_error

func reset() -> bool:
	if not _configured:
		return false
	var fresh_stage := StageEncounterRuntime.new()
	if not fresh_stage.configure(_stage_spec):
		_hard_error = "reset rejected by StageEncounterRuntime: %s" % [fresh_stage.validation_errors()]
		return false
	_stage_runtime = fresh_stage
	_phase_runtime = null
	_encounter_kind = "stage"
	_active_phase_index = -1
	_resolved_phase_ids.clear()
	_hard_error = ""
	return true

func advance(player_position: Vector2 = Vector2.ZERO) -> Dictionary:
	if not _configured:
		return _failure_result("controller is not configured")
	if has_hard_error():
		return _failure_result(_hard_error)
	var output := _empty_output()
	if _encounter_kind == "complete":
		output["complete"] = true
		return _finalize_output(output)
	if _encounter_kind in ["midboss", "boss"]:
		if _phase_runtime == null:
			return _hard_fail("active encounter has no phase runtime")
		var definition := active_phase_definition()
		var phase_tick := int(_phase_runtime.telemetry_snapshot().get("tick", 0))
		if phase_tick >= int(definition.get("timeout_ticks", -1)):
			return _resolve_active_phase_internal("timeout")
		var phase_output: Dictionary = _phase_runtime.advance(player_position)
		if not bool(phase_output.get("ok", false)):
			return _hard_fail("phase advance failed: %s" % String(phase_output.get("error", _phase_runtime.last_error())))
		output["phase_tick"] = int(phase_output.tick)
		output["warnings"] = phase_output.warnings.duplicate(true)
		output["events"] = phase_output.events.duplicate(true)
		output["boss_movements"] = phase_output.boss_movements.duplicate(true)
		output["bullet_specs"] = phase_output.bullet_specs.duplicate(true)
		return _finalize_output(output)
	var stage_output: Dictionary = _stage_runtime.advance()
	if not bool(stage_output.get("ok", false)):
		return _hard_fail("stage advance failed: %s" % String(stage_output.get("error", _stage_runtime.last_error())))
	output["stage_tick"] = int(stage_output.tick)
	output["stage_events"] = stage_output.events.duplicate(true)
	for event_value in stage_output.events:
		var event: Dictionary = event_value
		if event.get("gate") is Dictionary:
			var encounter_role := String(event.gate.get("encounter_role", ""))
			if not _begin_encounter(encounter_role):
				return _hard_fail("failed to enter %s encounter" % encounter_role)
			output["encounter_started"] = active_phase_definition()
			output["phase_started"] = active_phase_definition()
	return _finalize_output(output)

func resolve_active_phase(outcome: String) -> Dictionary:
	if not _configured:
		return _failure_result("controller is not configured")
	if has_hard_error():
		return _failure_result(_hard_error)
	if outcome not in RESOLUTION_OUTCOMES:
		return _failure_result("phase outcome must be clear or timeout")
	if _encounter_kind not in ["midboss", "boss"] or _phase_runtime == null:
		return _failure_result("no active phase can be resolved")
	return _resolve_active_phase_internal(outcome)

func encounter_kind() -> String:
	return _encounter_kind

func active_phase_id() -> String:
	return PHASE_IDS[_active_phase_index] if _active_phase_index >= 0 and _active_phase_index < PHASE_IDS.size() else ""

func active_phase_index() -> int:
	return _active_phase_index

func active_phase_tick() -> int:
	return int(_phase_runtime.telemetry_snapshot().get("tick", 0)) if _phase_runtime != null else 0

func active_phase_spec() -> Dictionary:
	return _phase_specs[_active_phase_index].duplicate(true) if _active_phase_index >= 0 and _active_phase_index < _phase_specs.size() else {}

func active_phase_definition() -> Dictionary:
	if _active_phase_index < 0 or _active_phase_index >= PHASE_IDS.size():
		return {}
	return _phase_definition_at(_active_phase_index, _encounter_kind)

func _phase_definition_at(index: int, kind: String) -> Dictionary:
	if index < 0 or index >= PHASE_IDS.size():
		return {}
	var phase_id := PHASE_IDS[index]
	var phase_metadata: Dictionary = _metadata.get("phase_metadata", {}).get(phase_id, {})
	var source_phase: Dictionary = phase_metadata.get("source_phase", {})
	var owner: Dictionary = source_phase.get("owner", {})
	var local_index := index if kind == "midboss" else index - MIDBOSS_PHASE_IDS.size()
	var topology_id := ""
	if index < _phase_specs.size():
		topology_id = String(_phase_specs[index].get("difficulties", {}).get(_difficulty, {}).get("topology_id", ""))
	return {
		"id": phase_id,
		"display_name": String(source_phase.get("display_name", phase_id)),
		"kind": String(source_phase.get("kind", "nonspell")),
		"encounter_kind": kind,
		"phase_index": index,
		"encounter_phase_index": local_index,
		"owner_id": String(owner.get("id", "")),
		"owner_display_name": String(owner.get("display_name", "")),
		"base_hp": float(source_phase.get("base_hp", 0.0)),
		"timeout_ticks": int(source_phase.get("timeout_ticks", 0)),
		"topology_id": topology_id,
	}

func resolved_phase_ids() -> Array[String]:
	return _resolved_phase_ids.duplicate()

func capture_snapshot() -> Dictionary:
	if not _configured or has_hard_error():
		return {}
	return {
		"version": SNAPSHOT_VERSION,
		"stage_id": STAGE_ID,
		"artifact_id": String(_metadata.get("artifact_id", "")),
		"difficulty": _difficulty,
		"gameplay_seed": _gameplay_seed,
		"encounter_kind": _encounter_kind,
		"active_phase_index": _active_phase_index,
		"resolved_phase_ids": _resolved_phase_ids.duplicate(),
		"stage_runtime": _stage_runtime.capture_snapshot(),
		"phase_runtime": _phase_runtime.capture_snapshot() if _phase_runtime != null else {},
	}

func validate_snapshot(snapshot: Dictionary) -> bool:
	if not _configured or int(snapshot.get("version", -1)) != SNAPSHOT_VERSION:
		return false
	if String(snapshot.get("stage_id", "")) != STAGE_ID or String(snapshot.get("artifact_id", "")) != String(_metadata.get("artifact_id", "")):
		return false
	if String(snapshot.get("difficulty", "")) != _difficulty or typeof(snapshot.get("gameplay_seed")) != TYPE_INT or int(snapshot.gameplay_seed) != _gameplay_seed:
		return false
	if String(snapshot.get("encounter_kind", "")) not in ENCOUNTER_KINDS or typeof(snapshot.get("active_phase_index")) != TYPE_INT:
		return false
	if not (snapshot.get("resolved_phase_ids") is Array) or not (snapshot.get("stage_runtime") is Dictionary) or not (snapshot.get("phase_runtime") is Dictionary):
		return false
	var resolved: Array = snapshot.resolved_phase_ids
	if resolved.size() > PHASE_IDS.size() or resolved != PHASE_IDS.slice(0, resolved.size()):
		return false
	var stage_probe := StageEncounterRuntime.new()
	if not stage_probe.configure(_stage_spec) or not stage_probe.validate_snapshot(snapshot.stage_runtime):
		return false
	var stage_state: Dictionary = snapshot.stage_runtime
	var kind := String(snapshot.encounter_kind)
	var phase_index := int(snapshot.active_phase_index)
	if not _snapshot_controller_state_is_coherent(kind, phase_index, resolved, stage_state):
		return false
	if kind in ["midboss", "boss"]:
		var phase_probe := DanmakuPatternRuntime.new()
		if not phase_probe.configure(_phase_specs[phase_index], _difficulty, _gameplay_seed) or not phase_probe.validate_snapshot(snapshot.phase_runtime):
			return false
		return int(snapshot.phase_runtime.get("tick", -1)) <= int(_phase_definition_for_index(phase_index).get("timeout_ticks", -1))
	return snapshot.phase_runtime.is_empty()

func restore_snapshot(snapshot: Dictionary) -> bool:
	if not validate_snapshot(snapshot):
		return false
	var restored_stage := StageEncounterRuntime.new()
	if not restored_stage.configure(_stage_spec) or not restored_stage.restore_snapshot(snapshot.stage_runtime):
		return false
	var restored_phase: RefCounted = null
	var restored_phase_index := int(snapshot.active_phase_index)
	if String(snapshot.encounter_kind) in ["midboss", "boss"]:
		restored_phase = DanmakuPatternRuntime.new()
		if not restored_phase.configure(_phase_specs[restored_phase_index], _difficulty, _gameplay_seed) or not restored_phase.restore_snapshot(snapshot.phase_runtime):
			return false
	var restored_ids: Array[String] = []
	for phase_id in snapshot.resolved_phase_ids:
		restored_ids.append(String(phase_id))
	_stage_runtime = restored_stage
	_phase_runtime = restored_phase
	_encounter_kind = String(snapshot.encounter_kind)
	_active_phase_index = restored_phase_index
	_resolved_phase_ids = restored_ids
	_hard_error = ""
	return true

func telemetry_snapshot() -> Dictionary:
	return {
		"version": SNAPSHOT_VERSION,
		"configured": _configured,
		"stage_id": STAGE_ID if _configured else "",
		"artifact_id": String(_metadata.get("artifact_id", "")),
		"difficulty": _difficulty,
		"gameplay_seed": _gameplay_seed,
		"encounter_kind": _encounter_kind,
		"active_phase_id": active_phase_id(),
		"active_phase_index": _active_phase_index,
		"active_phase_tick": active_phase_tick(),
		"active_phase_definition": active_phase_definition(),
		"resolved_phase_ids": _resolved_phase_ids.duplicate(),
		"stage_runtime": _stage_runtime.telemetry_snapshot() if _stage_runtime != null else {},
		"phase_runtime": _phase_runtime.telemetry_snapshot() if _phase_runtime != null else {},
		"hard_error": _hard_error,
	}

func _begin_encounter(kind: String) -> bool:
	if kind == "midboss" and _resolved_phase_ids.is_empty():
		_active_phase_index = 0
	elif kind == "boss" and _resolved_phase_ids == MIDBOSS_PHASE_IDS:
		_active_phase_index = MIDBOSS_PHASE_IDS.size()
	else:
		return false
	_encounter_kind = kind
	return _configure_active_phase_runtime()

func _configure_active_phase_runtime() -> bool:
	if _active_phase_index < 0 or _active_phase_index >= _phase_specs.size():
		return false
	var fresh_phase := DanmakuPatternRuntime.new()
	if not fresh_phase.configure(_phase_specs[_active_phase_index], _difficulty, _gameplay_seed):
		return false
	_phase_runtime = fresh_phase
	return true

func _resolve_active_phase_internal(outcome: String) -> Dictionary:
	var output := _empty_output()
	var resolved_definition := active_phase_definition()
	var resolved_id := active_phase_id()
	var resolved_tick := active_phase_tick()
	_resolved_phase_ids.append(resolved_id)
	output.phase_resolutions.append({
		"phase_id": resolved_id,
		"encounter_kind": _encounter_kind,
		"outcome": outcome,
		"phase_tick": resolved_tick,
		"owner_id": String(resolved_definition.get("owner_id", "")),
	})
	var encounter_end_index := MIDBOSS_PHASE_IDS.size() if _encounter_kind == "midboss" else PHASE_IDS.size()
	if _resolved_phase_ids.size() < encounter_end_index:
		_active_phase_index += 1
		if not _configure_active_phase_runtime():
			return _hard_fail("failed to configure next approved phase")
		output["phase_started"] = active_phase_definition()
		return _finalize_output(output)
	var completed_kind := _encounter_kind
	var token := String(COMPLETION_TOKENS[completed_kind])
	if not _stage_runtime.complete_gate(token):
		return _hard_fail("StageEncounterRuntime rejected completion token %s" % token)
	_phase_runtime = null
	_active_phase_index = -1
	_encounter_kind = "stage" if completed_kind == "midboss" else "complete"
	output["gate_completion"] = {
		"encounter_kind": completed_kind,
		"event_id": String(GATE_EVENT_IDS[completed_kind]),
		"completion_token": token,
	}
	output["complete"] = _encounter_kind == "complete"
	return _finalize_output(output)

func _phase_definition_for_index(index: int) -> Dictionary:
	return _phase_definition_at(index, "midboss" if index < MIDBOSS_PHASE_IDS.size() else "boss")

func _snapshot_controller_state_is_coherent(kind: String, phase_index: int, resolved: Array, stage_state: Dictionary) -> bool:
	var paused := bool(stage_state.get("paused", false))
	var active_gate: Dictionary = stage_state.get("active_gate", {})
	var completed_gates: Array = stage_state.get("completed_gate_ids", [])
	var next_event_index := int(stage_state.get("next_event_index", -1))
	match kind:
		"stage":
			if phase_index != -1 or paused:
				return false
			if resolved.is_empty():
				return completed_gates.is_empty() and next_event_index <= 5
			return resolved == MIDBOSS_PHASE_IDS and completed_gates == ["s2_b06"] and next_event_index >= 6 and next_event_index <= 17
		"midboss":
			return phase_index == resolved.size() and resolved.size() < MIDBOSS_PHASE_IDS.size() and paused and String(active_gate.get("event_id", "")) == "s2_b06" and completed_gates.is_empty()
		"boss":
			return phase_index == resolved.size() and resolved.size() >= MIDBOSS_PHASE_IDS.size() and resolved.size() < PHASE_IDS.size() and paused and String(active_gate.get("event_id", "")) == "s2_b18" and completed_gates == ["s2_b06"]
		"complete":
			return phase_index == -1 and resolved == PHASE_IDS and not paused and completed_gates == ["s2_b06", "s2_b18"] and next_event_index == 18
	return false

func _validate_package(stage2_package: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not (stage2_package.get("stage_spec") is Dictionary) or not (stage2_package.get("phase_specs") is Array) or not (stage2_package.get("metadata") is Dictionary):
		errors.append("stage_spec, phase_specs, and metadata are required")
		return errors
	var stage_spec: Dictionary = stage2_package.stage_spec
	var phase_specs: Array = stage2_package.phase_specs
	var metadata: Dictionary = stage2_package.metadata
	if String(stage_spec.get("stage_id", "")) != STAGE_ID:
		errors.append("Stage 2 stage identity is malformed")
	if not (stage_spec.get("events") is Array) or stage_spec.events.size() != STAGE_EVENT_IDS.size():
		errors.append("Stage 2 requires exactly 18 stage events")
	else:
		for index in range(STAGE_EVENT_IDS.size()):
			var event_value = stage_spec.events[index]
			if not (event_value is Dictionary) or String(event_value.get("id", "")) != STAGE_EVENT_IDS[index] or int(event_value.get("tick", -1)) != STAGE_RUNTIME_TICKS[index]:
				errors.append("Stage 2 event order or tick is malformed at %d" % index)
				break
			var expected_gate_kind := "midboss" if index == 5 else ("boss" if index == 17 else "")
			if expected_gate_kind.is_empty():
				if event_value.has("gate"):
					errors.append("Stage 2 has an unexpected gate at %s" % STAGE_EVENT_IDS[index])
					break
			else:
				var gate_value = event_value.get("gate")
				if not (gate_value is Dictionary) or String(gate_value.get("encounter_role", "")) != expected_gate_kind or String(gate_value.get("completion_token", "")) != String(COMPLETION_TOKENS[expected_gate_kind]):
					errors.append("Stage 2 %s gate is malformed" % expected_gate_kind)
					break
	if phase_specs.size() != PHASE_IDS.size():
		errors.append("Stage 2 requires exactly six phases")
	else:
		for index in range(PHASE_IDS.size()):
			if not (phase_specs[index] is Dictionary) or String(phase_specs[index].get("id", "")) != PHASE_IDS[index]:
				errors.append("Stage 2 phase order is malformed at %d" % index)
				break
	if typeof(metadata.get("artifact_id")) != TYPE_STRING or String(metadata.get("artifact_id", "")).is_empty():
		errors.append("Stage 2 artifact identity is missing")
	if not (metadata.get("phase_sequences") is Dictionary) or metadata.phase_sequences.get("midboss", []) != MIDBOSS_PHASE_IDS or metadata.phase_sequences.get("boss", []) != BOSS_PHASE_IDS:
		errors.append("Stage 2 encounter phase sequences are malformed")
	if not (metadata.get("completion_tokens") is Dictionary) or metadata.completion_tokens != COMPLETION_TOKENS:
		errors.append("Stage 2 completion tokens are malformed")
	if not (metadata.get("phase_metadata") is Dictionary):
		errors.append("Stage 2 phase metadata is missing")
	else:
		for index in range(PHASE_IDS.size()):
			var phase_id := PHASE_IDS[index]
			var entry_value = metadata.phase_metadata.get(phase_id)
			if not (entry_value is Dictionary) or not (entry_value.get("source_phase") is Dictionary):
				errors.append("Stage 2 phase metadata is missing for %s" % phase_id)
				continue
			var source_phase: Dictionary = entry_value.source_phase
			var expected_role := "midboss" if index < MIDBOSS_PHASE_IDS.size() else "boss"
			if String(source_phase.get("encounter_role", "")) != expected_role or not (source_phase.get("owner") is Dictionary):
				errors.append("Stage 2 phase ownership is malformed for %s" % phase_id)
			if not _is_positive_number(source_phase.get("base_hp")) or not _is_positive_integral_number(source_phase.get("timeout_ticks")):
				errors.append("Stage 2 phase HP or timeout is malformed for %s" % phase_id)
	return errors

func _is_positive_number(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number) and number > 0.0

func _is_positive_integral_number(value: Variant) -> bool:
	if not _is_positive_number(value):
		return false
	var number := float(value)
	return number == floor(number)

func _empty_output() -> Dictionary:
	return {
		"ok": true,
		"stage_tick": int(_stage_runtime.telemetry_snapshot().get("stage_tick", 0)) if _stage_runtime != null else 0,
		"phase_tick": active_phase_tick(),
		"encounter_kind": _encounter_kind,
		"active_phase_id": active_phase_id(),
		"stage_events": [],
		"warnings": [],
		"events": [],
		"boss_movements": [],
		"bullet_specs": [],
		"phase_resolutions": [],
		"encounter_started": {},
		"phase_started": {},
		"gate_completion": {},
		"complete": _encounter_kind == "complete",
	}

func _failure_result(message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message,
		"encounter_kind": _encounter_kind,
		"active_phase_id": active_phase_id(),
	}

func _finalize_output(output: Dictionary) -> Dictionary:
	output["encounter_kind"] = _encounter_kind
	output["active_phase_id"] = active_phase_id()
	output["phase_tick"] = active_phase_tick()
	output["complete"] = _encounter_kind == "complete"
	return output

func _hard_fail(message: String) -> Dictionary:
	_hard_error = message
	return _failure_result(message)

func _clear_runtime_owners() -> void:
	_stage_runtime = null
	_phase_runtime = null
	_configured = false

func _clear_configuration() -> void:
	_package.clear()
	_stage_spec.clear()
	_phase_specs.clear()
	_metadata.clear()
	_difficulty = ""
	_gameplay_seed = 0
	_stage_runtime = null
	_phase_runtime = null
	_encounter_kind = "stage"
	_active_phase_index = -1
	_resolved_phase_ids.clear()
	_configured = false
	_validation_errors.clear()
	_hard_error = ""
