extends RefCounted
class_name StageEncounterRuntime

const SNAPSHOT_VERSION := 1
const REQUIRED_EVENT_COUNT := 18
const MAX_EVENTS_PER_TICK := 8
const MAX_STAGE_TICK := 216000
const MAX_CANONICAL_DEPTH := 32
const MAX_CANONICAL_COLLECTION := 4096
const STAGE_SPEC_KEYS := ["schema_version", "stage_id", "id", "events"]
const GATE_KEYS := ["encounter_role", "phase_cursor", "completion_token"]

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
var _event_signature_cache := ""

func configure(stage_spec: Dictionary) -> bool:
	_stage_spec = {}
	_events = []
	_stage_id = ""
	_configured = false
	_event_signature_cache = ""
	_validation_errors = _validate_stage_spec(stage_spec)
	if not _validation_errors.is_empty():
		_hard_error = "configuration rejected: %s" % "; ".join(PackedStringArray(_validation_errors))
		return false
	_stage_spec = stage_spec.duplicate(true)
	_stage_id = _stage_identity(_stage_spec)
	_events = _stage_spec.events.duplicate(true)
	_event_signature_cache = _canonical_digest("stage-encounter-events-schema-v1", {
		"stage_id": _stage_id,
		"events": _events,
	})
	if _event_signature().is_empty():
		_validation_errors.append("canonical event signature generation failed")
		_hard_error = "configuration rejected: canonical event signature generation failed"
		_stage_spec = {}
		_events = []
		_stage_id = ""
		_event_signature_cache = ""
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
	if _stage_tick >= MAX_STAGE_TICK:
		return _hard_fail("stage tick cap exceeded")
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
	if typeof(snapshot.get("next_event_index")) != TYPE_INT or not (snapshot.get("emitted_event_ids") is Array):
		return false
	if typeof(snapshot.get("paused")) != TYPE_BOOL or not (snapshot.get("active_gate") is Dictionary):
		return false
	if typeof(snapshot.get("encounter_role")) != TYPE_STRING or typeof(snapshot.get("phase_cursor")) != TYPE_INT:
		return false
	if typeof(snapshot.get("event_count")) != TYPE_INT or not (snapshot.get("completed_gate_ids") is Array):
		return false
	for event_id in snapshot.emitted_event_ids:
		if typeof(event_id) != TYPE_STRING:
			return false
	for gate_id in snapshot.completed_gate_ids:
		if typeof(gate_id) != TYPE_STRING:
			return false
	if not _is_canonical_value(snapshot.active_gate):
		return false
	var expected := _replay_state_to_tick(int(snapshot.stage_tick), snapshot.completed_gate_ids)
	if expected.is_empty():
		return false
	if int(snapshot.next_event_index) != int(expected.next_event_index):
		return false
	if snapshot.emitted_event_ids != expected.emitted_event_ids:
		return false
	if bool(snapshot.paused) != bool(expected.paused) or snapshot.active_gate != expected.active_gate:
		return false
	if String(snapshot.encounter_role) != String(expected.encounter_role) or int(snapshot.phase_cursor) != int(expected.phase_cursor):
		return false
	if snapshot.completed_gate_ids != expected.completed_gate_ids:
		return false
	return int(snapshot.event_count) == int(expected.next_event_index)

func restore_snapshot(snapshot: Dictionary) -> bool:
	if not validate_snapshot(snapshot):
		return false
	var restored_emitted: Array[String] = []
	for event_id in snapshot.emitted_event_ids:
		restored_emitted.append(String(event_id))
	var restored_completed: Array[String] = []
	for gate_id in snapshot.completed_gate_ids:
		restored_completed.append(String(gate_id))
	var restored_active_gate: Dictionary = snapshot.active_gate.duplicate(true)
	var restored_stage_tick := int(snapshot.stage_tick)
	var restored_next_event_index := int(snapshot.next_event_index)
	var restored_paused := bool(snapshot.paused)
	var restored_encounter_role := String(snapshot.encounter_role)
	var restored_phase_cursor := int(snapshot.phase_cursor)
	var restored_event_count := int(snapshot.event_count)
	_stage_tick = restored_stage_tick
	_next_event_index = restored_next_event_index
	_emitted_event_ids = restored_emitted
	_paused = restored_paused
	_active_gate = restored_active_gate
	_encounter_role = restored_encounter_role
	_phase_cursor = restored_phase_cursor
	_event_count = restored_event_count
	_completed_gate_ids = restored_completed
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
	_validate_dictionary_keys(stage_spec, STAGE_SPEC_KEYS, "stage_spec", errors)
	if stage_spec.has("schema_version") and (typeof(stage_spec.schema_version) != TYPE_INT or int(stage_spec.schema_version) != 1):
		errors.append("schema_version must be integer 1 when present")
	if stage_spec.has("stage_id") and stage_spec.has("id") and String(stage_spec.stage_id) != String(stage_spec.id):
		errors.append("stage_id and id must match when both are present")
	for identity_key in ["stage_id", "id"]:
		if stage_spec.has(identity_key) and typeof(stage_spec[identity_key]) != TYPE_STRING:
			errors.append("%s must be a String" % identity_key)
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
		if typeof(event.get("id")) != TYPE_STRING or event_id.is_empty() or seen_ids.has(event_id):
			errors.append("events[%d] has a missing or duplicate id" % index)
		seen_ids[event_id] = true
		if typeof(event.get("kind")) != TYPE_STRING or String(event.get("kind", "")).is_empty():
			errors.append("events[%d].kind is required" % index)
		if typeof(event.get("tick")) != TYPE_INT or int(event.get("tick", -1)) < previous_tick or int(event.get("tick", -1)) < 0 or int(event.get("tick", -1)) >= MAX_STAGE_TICK:
			errors.append("events[%d].tick must be an ordered non-negative integer" % index)
			continue
		var event_tick := int(event.tick)
		previous_tick = event_tick
		tick_counts[event_tick] = int(tick_counts.get(event_tick, 0)) + 1
		if event.has("encounter_role") and (typeof(event.encounter_role) != TYPE_STRING or String(event.encounter_role) not in ["stage", "midboss", "boss"]):
			errors.append("events[%d].encounter_role is unsupported" % index)
		if event.has("phase_cursor") and (typeof(event.phase_cursor) != TYPE_INT or int(event.phase_cursor) < 0):
			errors.append("events[%d].phase_cursor must be a non-negative integer" % index)
		if event.has("gate"):
			if not (event.gate is Dictionary):
				errors.append("events[%d].gate must be a Dictionary" % index)
				continue
			var gate: Dictionary = event.gate
			_validate_dictionary_keys(gate, GATE_KEYS, "events[%d].gate" % index, errors)
			var role := String(gate.get("encounter_role", ""))
			var token := String(gate.get("completion_token", ""))
			if typeof(gate.get("encounter_role")) != TYPE_STRING or role not in ["midboss", "boss"]:
				errors.append("events[%d] gate role must be midboss or boss" % index)
			else:
				gate_roles[role] = int(gate_roles[role]) + 1
			if typeof(gate.get("completion_token")) != TYPE_STRING or token.is_empty() or seen_tokens.has(token):
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
	if not _is_canonical_value(stage_spec):
		errors.append("stage spec contains a key type or Variant outside the canonical schema value set")
	return errors

func _replay_state_to_tick(target_tick: int, requested_completed: Array) -> Dictionary:
	var replay_tick := 0
	var replay_cursor := 0
	var replay_emitted: Array[String] = []
	var replay_completed: Array[String] = []
	var replay_paused := false
	var replay_active_gate: Dictionary = {}
	var replay_role := "stage"
	var replay_phase_cursor := -1
	var completion_cursor := 0
	while replay_tick < target_tick:
		if replay_paused:
			if completion_cursor >= requested_completed.size() or String(requested_completed[completion_cursor]) != String(replay_active_gate.event_id):
				return {}
			replay_completed.append(String(replay_active_gate.event_id))
			completion_cursor += 1
			replay_paused = false
			replay_active_gate.clear()
			continue
		while replay_cursor < _events.size():
			var event: Dictionary = _events[replay_cursor]
			if int(event.tick) > replay_tick:
				break
			replay_emitted.append(String(event.id))
			replay_cursor += 1
			if event.get("gate") is Dictionary:
				var gate: Dictionary = event.gate
				replay_role = String(gate.encounter_role)
				replay_phase_cursor = int(gate.phase_cursor)
				replay_active_gate = _normalized_gate(event)
				replay_paused = true
				break
			if event.has("encounter_role"):
				replay_role = String(event.encounter_role)
			if event.has("phase_cursor"):
				replay_phase_cursor = int(event.phase_cursor)
		replay_tick += 1
	if replay_paused and completion_cursor < requested_completed.size() and String(requested_completed[completion_cursor]) == String(replay_active_gate.event_id):
		replay_completed.append(String(replay_active_gate.event_id))
		completion_cursor += 1
		replay_paused = false
		replay_active_gate.clear()
	if completion_cursor != requested_completed.size():
		return {}
	return {
		"stage_tick": replay_tick,
		"next_event_index": replay_cursor,
		"emitted_event_ids": replay_emitted,
		"paused": replay_paused,
		"active_gate": replay_active_gate.duplicate(true),
		"encounter_role": replay_role,
		"phase_cursor": replay_phase_cursor,
		"completed_gate_ids": replay_completed,
	}

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
	return _event_signature_cache

func _canonical_digest(contract: String, value: Variant) -> String:
	var encoded := _canonical_encode(value)
	if encoded.is_empty():
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update((contract + "|" + encoded).to_utf8_buffer()) != OK:
		return ""
	return context.finish().hex_encode()

func _canonical_encode(value: Variant, depth: int = 0) -> String:
	if depth > MAX_CANONICAL_DEPTH:
		return ""
	match typeof(value):
		TYPE_NIL:
			return "n"
		TYPE_BOOL:
			return "b1" if bool(value) else "b0"
		TYPE_INT:
			return "i%d" % int(value)
		TYPE_FLOAT:
			return "f" + var_to_bytes(float(value)).hex_encode()
		TYPE_STRING:
			return "s" + String(value).to_utf8_buffer().hex_encode()
		TYPE_VECTOR2:
			return "v2" + var_to_bytes(value).hex_encode()
		TYPE_COLOR:
			return "c" + var_to_bytes(value).hex_encode()
		TYPE_RECT2:
			return "r2" + var_to_bytes(value).hex_encode()
		TYPE_ARRAY:
			if value.size() > MAX_CANONICAL_COLLECTION:
				return ""
			var array_parts := PackedStringArray()
			for entry in value:
				var encoded_entry := _canonical_encode(entry, depth + 1)
				if encoded_entry.is_empty():
					return ""
				array_parts.append(encoded_entry)
			return "a%d[%s]" % [value.size(), ";".join(array_parts)]
		TYPE_DICTIONARY:
			if value.size() > MAX_CANONICAL_COLLECTION:
				return ""
			var sorted_keys := PackedStringArray()
			for key in value.keys():
				if typeof(key) != TYPE_STRING:
					return ""
				sorted_keys.append(String(key))
			sorted_keys.sort()
			var dictionary_parts := PackedStringArray()
			for key in sorted_keys:
				var encoded_value := _canonical_encode(value[key], depth + 1)
				if encoded_value.is_empty():
					return ""
				dictionary_parts.append(String(key).to_utf8_buffer().hex_encode() + "=" + encoded_value)
			return "d%d{%s}" % [sorted_keys.size(), ";".join(dictionary_parts)]
	return ""

func _is_canonical_value(value: Variant, depth: int = 0) -> bool:
	if depth > MAX_CANONICAL_DEPTH:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return _is_finite_number(value)
		TYPE_VECTOR2:
			return _is_finite_number(value.x) and _is_finite_number(value.y)
		TYPE_COLOR:
			return _is_finite_number(value.r) and _is_finite_number(value.g) and _is_finite_number(value.b) and _is_finite_number(value.a)
		TYPE_RECT2:
			return _is_finite_number(value.position.x) and _is_finite_number(value.position.y) and _is_finite_number(value.size.x) and _is_finite_number(value.size.y)
		TYPE_ARRAY:
			if value.size() > MAX_CANONICAL_COLLECTION:
				return false
			for entry in value:
				if not _is_canonical_value(entry, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			if value.size() > MAX_CANONICAL_COLLECTION:
				return false
			for key in value.keys():
				if typeof(key) != TYPE_STRING or not _is_canonical_value(value[key], depth + 1):
					return false
			return true
	return false

func _validate_dictionary_keys(values: Dictionary, allowed_keys: Array, label: String, errors: Array[String]) -> void:
	for key in values.keys():
		if typeof(key) != TYPE_STRING or String(key) not in allowed_keys:
			errors.append("%s contains unsupported key %s" % [label, String(key)])

func _is_finite_number(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var numeric := float(value)
	return not is_nan(numeric) and not is_inf(numeric)

func _stage_identity(stage_spec: Dictionary) -> String:
	var stage_id := String(stage_spec.get("stage_id", ""))
	return stage_id if not stage_id.is_empty() else String(stage_spec.get("id", ""))

func _failure_result(message: String) -> Dictionary:
	return {"ok": false, "tick": _stage_tick, "error": message}

func _hard_fail(message: String) -> Dictionary:
	_hard_error = message
	return _failure_result(message)
