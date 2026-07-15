extends RefCounted
class_name StageEncounterRuntime

const SNAPSHOT_VERSION := 1
const REQUIRED_EVENT_COUNT := 18
const MAX_EVENTS_PER_TICK := 8
const MAX_STAGE_TICK := 216000

var _stage_spec: Dictionary = {}
var _events: Array = []
var _stage_id := ""
var _stage_tick := 0
var _next_event_index := 0
var _emitted_event_ids: Array[String] = []
var _paused := false
var _active_gate: Dictionary = {}
var _encounter_role := "stage"
var _phase_cursor := -1
var _event_count := 0
var _completed_gate_ids: Array[String] = []
var _configured := false
var _validation_errors: Array[String] = []
var _hard_error := ""

func configure(stage_spec: Dictionary) -> bool:
	_stage_spec = {}
	_events = []
	_stage_id = ""
	_configured = false
	_validation_errors = _validate_stage_spec(stage_spec)
	if not _validation_errors.is_empty():
		_hard_error = "configuration rejected: %s" % "; ".join(PackedStringArray(_validation_errors))
		return false
	_stage_spec = stage_spec.duplicate(true)
	_stage_id = _stage_identity(_stage_spec)
	_events = _stage_spec.events.duplicate(true)
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
	_stage_tick = 0
	_next_event_index = 0
	_emitted_event_ids.clear()
	_paused = false
	_active_gate.clear()
	_encounter_role = "stage"
	_phase_cursor = -1
	_event_count = 0
	_completed_gate_ids.clear()
	_hard_error = ""
	return true

func advance() -> Dictionary:
	if not _configured:
		return _failure_result("runtime is not configured")
	if has_hard_error():
		return _failure_result(_hard_error)
	if _paused:
		return {
			"ok": true,
			"tick": _stage_tick,
			"events": [],
			"paused": true,
			"active_gate": _active_gate.duplicate(true),
			"encounter_role": _encounter_role,
			"phase_cursor": _phase_cursor,
		}
	var output_tick := _stage_tick
	var due_events: Array = []
	while _next_event_index < _events.size():
		var source: Dictionary = _events[_next_event_index]
		if int(source.tick) > _stage_tick:
			break
		var record := source.duplicate(true)
		record["stage_id"] = _stage_id
		record["stage_tick"] = int(source.tick)
		record["sequence_index"] = _next_event_index
		due_events.append(record)
		var event_id := String(source.id)
		_emitted_event_ids.append(event_id)
		_next_event_index += 1
		_event_count += 1
		_update_encounter_cursor(source)
		if source.get("gate") is Dictionary:
			_activate_gate(source)
			break
	if due_events.size() > MAX_EVENTS_PER_TICK:
		return _hard_fail("stage event output cap exceeded at tick %d" % _stage_tick)
	_stage_tick += 1
	return {
		"ok": true,
		"tick": output_tick,
		"events": due_events,
		"paused": _paused,
		"active_gate": _active_gate.duplicate(true),
		"encounter_role": _encounter_role,
		"phase_cursor": _phase_cursor,
	}

func complete_gate(completion_token: String) -> bool:
	if not _configured or has_hard_error() or not _paused:
		return false
	if completion_token != String(_active_gate.get("completion_token", "")):
		return false
	_completed_gate_ids.append(String(_active_gate.event_id))
	_paused = false
	_active_gate.clear()
	return true

func seek(target_tick: int, completion_tokens: Dictionary = {}) -> Dictionary:
	if not _configured:
		return _failure_result("runtime is not configured")
	if target_tick < 0 or target_tick > MAX_STAGE_TICK:
		return _hard_fail("seek tick is outside the supported range")
	reset()
	while _stage_tick < target_tick:
		if _paused:
			var token := _completion_token_for_seek(completion_tokens)
			if token.is_empty() or not complete_gate(token):
				return _failure_result("seek requires the matching completion token for gate %s" % String(_active_gate.get("event_id", "")))
		var result := advance()
		if not bool(result.get("ok", false)):
			return result
	return {
		"ok": true,
		"tick": _stage_tick,
		"paused": _paused,
		"telemetry": telemetry_snapshot(),
	}

func capture_snapshot() -> Dictionary:
	if not _configured or has_hard_error():
		return {}
	return {
		"version": SNAPSHOT_VERSION,
		"stage_id": _stage_id,
		"event_signature": _event_signature(),
		"stage_tick": _stage_tick,
		"next_event_index": _next_event_index,
		"emitted_event_ids": _emitted_event_ids.duplicate(),
		"paused": _paused,
		"active_gate": _active_gate.duplicate(true),
		"encounter_role": _encounter_role,
		"phase_cursor": _phase_cursor,
		"event_count": _event_count,
		"completed_gate_ids": _completed_gate_ids.duplicate(),
	}

func validate_snapshot(snapshot: Dictionary) -> bool:
	if not _configured or int(snapshot.get("version", -1)) != SNAPSHOT_VERSION:
		return false
	if String(snapshot.get("stage_id", "")) != _stage_id or String(snapshot.get("event_signature", "")) != _event_signature():
		return false
	if typeof(snapshot.get("stage_tick")) != TYPE_INT or int(snapshot.stage_tick) < 0 or int(snapshot.stage_tick) > MAX_STAGE_TICK:
		return false
	if typeof(snapshot.get("next_event_index")) != TYPE_INT:
		return false
	var cursor := int(snapshot.next_event_index)
	if cursor < 0 or cursor > _events.size():
		return false
	if not (snapshot.get("emitted_event_ids") is Array) or snapshot.emitted_event_ids.size() != cursor:
		return false
	for index in range(cursor):
		if String(snapshot.emitted_event_ids[index]) != String(_events[index].id):
			return false
	if typeof(snapshot.get("paused")) != TYPE_BOOL or not (snapshot.get("active_gate") is Dictionary):
		return false
	var paused := bool(snapshot.paused)
	var active_gate: Dictionary = snapshot.active_gate
	if paused:
		if cursor <= 0 or active_gate.is_empty() or not (_events[cursor - 1].get("gate") is Dictionary):
			return false
		var expected_gate := _normalized_gate(_events[cursor - 1])
		if active_gate != expected_gate:
			return false
	elif not active_gate.is_empty():
		return false
	if String(snapshot.get("encounter_role", "")) not in ["stage", "midboss", "boss"]:
		return false
	if typeof(snapshot.get("phase_cursor")) != TYPE_INT or int(snapshot.phase_cursor) < -1:
		return false
	if typeof(snapshot.get("event_count")) != TYPE_INT or int(snapshot.event_count) != cursor:
		return false
	if not (snapshot.get("completed_gate_ids") is Array):
		return false
	var seen_completed := {}
	for value in snapshot.completed_gate_ids:
		var gate_id := String(value)
		if gate_id.is_empty() or seen_completed.has(gate_id) or gate_id not in snapshot.emitted_event_ids:
			return false
		var event_index := snapshot.emitted_event_ids.find(gate_id)
		if event_index < 0 or not (_events[event_index].get("gate") is Dictionary):
			return false
		seen_completed[gate_id] = true
	return true

func restore_snapshot(snapshot: Dictionary) -> bool:
	if not validate_snapshot(snapshot):
		return false
	_stage_tick = int(snapshot.stage_tick)
	_next_event_index = int(snapshot.next_event_index)
	_emitted_event_ids.assign(snapshot.emitted_event_ids)
	_paused = bool(snapshot.paused)
	_active_gate = snapshot.active_gate.duplicate(true)
	_encounter_role = String(snapshot.encounter_role)
	_phase_cursor = int(snapshot.phase_cursor)
	_event_count = int(snapshot.event_count)
	_completed_gate_ids.assign(snapshot.completed_gate_ids)
	_hard_error = ""
	return true

func telemetry_snapshot() -> Dictionary:
	return {
		"version": SNAPSHOT_VERSION,
		"configured": _configured,
		"stage_id": _stage_id,
		"event_signature": _event_signature(),
		"stage_tick": _stage_tick,
		"next_event_index": _next_event_index,
		"emitted_event_ids": _emitted_event_ids.duplicate(),
		"paused": _paused,
		"active_gate": _active_gate.duplicate(true),
		"encounter_role": _encounter_role,
		"phase_cursor": _phase_cursor,
		"event_count": _event_count,
		"completed_gate_ids": _completed_gate_ids.duplicate(),
		"hard_error": _hard_error,
	}

func _validate_stage_spec(stage_spec: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if _stage_identity(stage_spec).is_empty():
		errors.append("stage_id or id is required")
	if not (stage_spec.get("events") is Array) or stage_spec.events.size() != REQUIRED_EVENT_COUNT:
		errors.append("events must contain exactly %d records" % REQUIRED_EVENT_COUNT)
		return errors
	var seen_ids := {}
	var seen_tokens := {}
	var gate_roles := {"midboss": 0, "boss": 0}
	var tick_counts := {}
	var previous_tick := -1
	for index in range(stage_spec.events.size()):
		if not (stage_spec.events[index] is Dictionary):
			errors.append("events[%d] must be a Dictionary" % index)
			continue
		var event: Dictionary = stage_spec.events[index]
		var event_id := String(event.get("id", ""))
		if event_id.is_empty() or seen_ids.has(event_id):
			errors.append("events[%d] has a missing or duplicate id" % index)
		seen_ids[event_id] = true
		if String(event.get("kind", "")).is_empty():
			errors.append("events[%d].kind is required" % index)
		if typeof(event.get("tick")) != TYPE_INT or int(event.get("tick", -1)) < previous_tick or int(event.get("tick", -1)) < 0 or int(event.get("tick", -1)) > MAX_STAGE_TICK:
			errors.append("events[%d].tick must be an ordered non-negative integer" % index)
			continue
		var event_tick := int(event.tick)
		previous_tick = event_tick
		tick_counts[event_tick] = int(tick_counts.get(event_tick, 0)) + 1
		if event.has("encounter_role") and String(event.encounter_role) not in ["stage", "midboss", "boss"]:
			errors.append("events[%d].encounter_role is unsupported" % index)
		if event.has("phase_cursor") and (typeof(event.phase_cursor) != TYPE_INT or int(event.phase_cursor) < 0):
			errors.append("events[%d].phase_cursor must be a non-negative integer" % index)
		if event.has("gate"):
			if not (event.gate is Dictionary):
				errors.append("events[%d].gate must be a Dictionary" % index)
				continue
			var gate: Dictionary = event.gate
			var role := String(gate.get("encounter_role", ""))
			var token := String(gate.get("completion_token", ""))
			if role not in ["midboss", "boss"]:
				errors.append("events[%d] gate role must be midboss or boss" % index)
			else:
				gate_roles[role] = int(gate_roles[role]) + 1
			if token.is_empty() or seen_tokens.has(token):
				errors.append("events[%d] gate completion_token is missing or duplicate" % index)
			seen_tokens[token] = true
			if typeof(gate.get("phase_cursor")) != TYPE_INT or int(gate.get("phase_cursor", -1)) < 0:
				errors.append("events[%d] gate phase_cursor must be non-negative" % index)
	for role in ["midboss", "boss"]:
		if int(gate_roles[role]) != 1:
			errors.append("stage must declare exactly one explicit %s gate" % role)
	for count in tick_counts.values():
		if int(count) > MAX_EVENTS_PER_TICK:
			errors.append("stage exceeds the %d event-per-tick cap" % MAX_EVENTS_PER_TICK)
			break
	return errors

func _update_encounter_cursor(event: Dictionary) -> void:
	if event.get("gate") is Dictionary:
		var gate: Dictionary = event.gate
		_encounter_role = String(gate.encounter_role)
		_phase_cursor = int(gate.phase_cursor)
		return
	if event.has("encounter_role"):
		_encounter_role = String(event.encounter_role)
	if event.has("phase_cursor"):
		_phase_cursor = int(event.phase_cursor)

func _activate_gate(event: Dictionary) -> void:
	_active_gate = _normalized_gate(event)
	_paused = true

func _normalized_gate(event: Dictionary) -> Dictionary:
	var gate: Dictionary = event.gate
	return {
		"event_id": String(event.id),
		"encounter_role": String(gate.encounter_role),
		"phase_cursor": int(gate.phase_cursor),
		"completion_token": String(gate.completion_token),
	}

func _completion_token_for_seek(completion_tokens: Dictionary) -> String:
	var event_id := String(_active_gate.get("event_id", ""))
	var role := String(_active_gate.get("encounter_role", ""))
	var required := String(_active_gate.get("completion_token", ""))
	if completion_tokens.has(event_id):
		return String(completion_tokens[event_id])
	if completion_tokens.has(role):
		return String(completion_tokens[role])
	if completion_tokens.has(required):
		return String(completion_tokens[required])
	return ""

func _event_signature() -> String:
	if _events.is_empty():
		return ""
	var parts := PackedStringArray()
	for event_value in _events:
		var event: Dictionary = event_value
		var gate_role := ""
		var gate_cursor := -1
		var gate_token := ""
		if event.get("gate") is Dictionary:
			gate_role = String(event.gate.get("encounter_role", ""))
			gate_cursor = int(event.gate.get("phase_cursor", -1))
			gate_token = String(event.gate.get("completion_token", ""))
		parts.append("%s:%d:%s:%s:%d:%s:%s:%d" % [
			String(event.id),
			int(event.tick),
			String(event.kind),
			gate_role,
			gate_cursor,
			gate_token,
			String(event.get("encounter_role", "")),
			int(event.get("phase_cursor", -1)),
		])
	return "|".join(parts)

func _stage_identity(stage_spec: Dictionary) -> String:
	var stage_id := String(stage_spec.get("stage_id", ""))
	return stage_id if not stage_id.is_empty() else String(stage_spec.get("id", ""))

func _failure_result(message: String) -> Dictionary:
	return {"ok": false, "tick": _stage_tick, "error": message}

func _hard_fail(message: String) -> Dictionary:
	_hard_error = message
	return _failure_result(message)
