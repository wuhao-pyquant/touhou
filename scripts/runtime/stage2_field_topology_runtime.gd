extends RefCounted
class_name Stage2FieldTopologyRuntime

const SNAPSHOT_VERSION := 1
const SNAPSHOT_SCHEMA := "stage2_field_topology_runtime_snapshot_v1"
const CONTRACT_SCHEMA_VERSION := 1
const CONTRACT_ARTIFACT_ID := "m2_stage2_field_topology_contract_v1"
const CONTRACT_DIGEST := "36f580e039b81f3b62cf1535cd527a8913e3dfb59d9f93ea15080f32824ab31d"
const EXPECTED_SPAWN_COUNT := 22
const EXPECTED_FINGERPRINT_COUNT := 44
const EXPECTED_EVENT_BUDGET_COUNT := 18
const TICK_RATE := 60
const MAX_LIFETIME_TICKS := 360
const MAX_STAGE_TICK := 216000
const MAX_CANONICAL_DEPTH := 32
const MAX_CANONICAL_COLLECTION := 8192
const DIFFICULTIES := ["normal", "hard"]
const PRIMITIVES := ["rebound_bead", "grid_edge", "lane_fan", "delayed_seed"]
const FIELD_EVENT_IDS := ["s2_b01", "s2_b02", "s2_b03", "s2_b04", "s2_b05", "s2_b12", "s2_b13", "s2_b15", "s2_b16"]
const EVENT_IDS := [
	"s2_b01", "s2_b02", "s2_b03", "s2_b04", "s2_b05", "s2_b06",
	"s2_b07", "s2_b08", "s2_b09", "s2_b10", "s2_b11", "s2_b12",
	"s2_b13", "s2_b14", "s2_b15", "s2_b16", "s2_b17", "s2_b18",
]
const EVENT_TICKS := {
	"s2_b01": 0, "s2_b02": 150, "s2_b03": 300, "s2_b04": 450, "s2_b05": 600, "s2_b06": 750,
	"s2_b07": 900, "s2_b08": 1050, "s2_b09": 1200, "s2_b10": 1350, "s2_b11": 1500, "s2_b12": 1650,
	"s2_b13": 1800, "s2_b14": 1950, "s2_b15": 2100, "s2_b16": 2250, "s2_b17": 2400, "s2_b18": 2550,
}
const EXPECTED_SPAWN_IDS := [
	"s2_b01_abacus_left", "s2_b01_abacus_center", "s2_b01_abacus_right",
	"s2_b02_left_clerk", "s2_b02_center_clerk", "s2_b02_right_clerk",
	"s2_b03_red_ledger", "s2_b03_blue_ledger",
	"s2_b04_left_booth_edge", "s2_b04_right_booth_edge",
	"s2_b05_left_bead_seller", "s2_b05_right_bead_seller",
	"s2_midboss_abacus_tsukumogami",
	"s2_b12_red_flag_runner", "s2_b12_blue_flag_runner", "s2_b12_yellow_flag_runner",
	"s2_b13_red_booth_master", "s2_b13_blue_booth_master", "s2_b13_yellow_booth_master",
	"s2_b15_left_mirror", "s2_b15_right_mirror", "s2_b16_abacus_keeper",
]
const ROW_KEYS := ["event_id", "segment_id", "spawn_id", "enemy_id", "source", "profiles"]
const PROFILE_KEYS := ["topology_id", "topology_fingerprint", "warning_lead_ticks", "lifetime_ticks", "geometry"]
const OUTPUT_ARRAY_KEYS := [
	"warnings", "bullet_constructions", "bullet_updates", "bullet_removals",
	"source_activations", "source_removals", "state_transitions", "score_route_callbacks", "telemetry",
]
const SNAPSHOT_PAYLOAD_KEYS := [
	"contract_digest", "difficulty", "stage_run_uid", "stage_cap", "schedule_cursor_tick",
	"last_stage_tick", "last_event_sequence", "current_event_id", "source_states", "active_bullets", "used_uids",
	"processed_callbacks", "activated_events", "defeated_sources", "grazed_uids", "hard_state", "telemetry_counts",
]
const SOURCE_STATE_KEYS := ["activated", "alive", "activated_tick", "removed_tick", "next_warning_index", "next_burst_index"]
const TELEMETRY_COUNT_KEYS := [
	"warnings", "bursts", "bullets_constructed", "bullet_updates", "bullet_removals",
	"source_activations", "source_removals", "state_transitions", "grazes_projected", "duplicates",
]
const HARD_STATE_KEYS := [
	"stage_front_revision_id", "blue_emission_state_id", "yellow_emission_state_id",
	"selected_mirror_spawn_id", "surviving_mirror_spawn_id", "mirror_activation_mask",
]
const BULLET_SEAM_KEYS := [
	"stage2_bullet_uid", "stage2_source_event_id", "stage2_source_spawn_id",
	"stage2_source_enemy_id", "stage2_primitive", "stage2_routing",
	"stage2_reflection_count", "stage2_bullet_spawn_tick", "stage2_first_reflection_tick",
	"stage2_last_reflection_surface_id", "stage2_collision_enable_tick", "stage2_lifetime_end_tick",
]
const BULLET_RECORD_KEYS := [
	"stage_run_uid", "difficulty", "event_id", "bullet_source_spawn_id", "bullet_source_enemy_id",
	"source_primitive", "source_routing_id", "topology_id", "topology_fingerprint", "emitter_id",
	"burst_index", "shot_index", "bullet_uid", "bullet_spawn_tick", "collision_enable_tick",
	"lifetime_end_tick", "reflection_count", "first_reflection_tick", "last_reflection_surface_id",
	"graze_tick", "speed_px_per_second",
	"stage2_bullet_uid", "stage2_source_event_id", "stage2_source_spawn_id", "stage2_source_enemy_id",
	"stage2_primitive", "stage2_routing", "stage2_reflection_count", "stage2_bullet_spawn_tick",
	"stage2_first_reflection_tick", "stage2_last_reflection_surface_id", "stage2_collision_enable_tick",
	"stage2_lifetime_end_tick", "position", "velocity_px_per_second", "activation_velocity_px_per_second",
	"motion_kind", "route_id", "route_points", "reflection_plan", "next_reflection_index", "removal_tick",
	"edge_id", "lane_id", "seed_id", "state_binding",
]
const BULLET_RECONSTRUCTED_KEYS := [
	"stage_run_uid", "difficulty", "event_id", "bullet_source_spawn_id", "bullet_source_enemy_id",
	"source_primitive", "source_routing_id", "topology_id", "topology_fingerprint", "emitter_id",
	"burst_index", "shot_index", "bullet_uid", "bullet_spawn_tick", "collision_enable_tick",
	"lifetime_end_tick", "speed_px_per_second", "stage2_bullet_uid", "stage2_source_event_id",
	"stage2_source_spawn_id", "stage2_source_enemy_id", "stage2_primitive", "stage2_routing",
	"stage2_bullet_spawn_tick", "stage2_collision_enable_tick", "stage2_lifetime_end_tick",
	"activation_velocity_px_per_second", "motion_kind", "route_id", "route_points", "reflection_plan",
	"removal_tick", "edge_id", "lane_id", "seed_id", "state_binding",
]
const STATE_BINDING_KEYS := [
	"stage_front_revision_id", "blue_emission_state_id", "yellow_emission_state_id",
	"selected_mirror_spawn_id", "mirror_activation_mask",
]
const CALLBACK_KINDS := [
	"activate_event", "remove_source", "accept_defeat", "clear_field_bullets",
	"observe_graze", "advance",
]
const LANE_CENTERS := {"lane_left": 136.0, "lane_center": 360.0, "lane_right": 584.0}
const COMBAT_BOUNDS := [24.0, 48.0, 696.0, 936.0]

var _contract: Dictionary = {}
var _rows: Array = []
var _row_by_spawn: Dictionary = {}
var _rows_by_event: Dictionary = {}
var _budget_by_event: Dictionary = {}
var _difficulty := ""
var _stage_run_uid := ""
var _stage_cap := 0
var _configured_contract_digest := ""
var _configured := false
var _validation_errors: Array[String] = []
var _hard_error_code := ""
var _hard_error_path := ""
var _hard_error_message := ""

var _schedule_cursor_tick := -1
var _last_stage_tick := -1
var _last_event_sequence := -1
var _current_event_id := ""
var _source_states: Dictionary = {}
var _active_bullets: Dictionary = {}
var _used_uids: Dictionary = {}
var _processed_callbacks: Dictionary = {}
var _activated_events: Dictionary = {}
var _defeated_sources: Dictionary = {}
var _grazed_uids: Dictionary = {}
var _hard_state: Dictionary = {}
var _telemetry_counts: Dictionary = {}
var _configure_generation := 0
var _update_in_progress := false

func configure(contract: Dictionary, difficulty: String, stage_run_uid: String) -> bool:
	_clear_configuration()
	_difficulty = difficulty
	_stage_run_uid = stage_run_uid
	_validation_errors = _validate_contract(contract)
	if difficulty not in DIFFICULTIES:
		_validation_errors.append("difficulty: expected exactly normal or hard")
	if not _valid_uid_component(stage_run_uid):
		_validation_errors.append("stage_run_uid: expected a nonempty colon-free string")
	if not _validation_errors.is_empty():
		_set_hard_error("configuration_rejected", _first_error_path(_validation_errors[0]), "; ".join(PackedStringArray(_validation_errors)))
		return false
	_contract = contract.duplicate(true)
	_rows = _contract.spawn_topologies.duplicate(true)
	for row_value in _rows:
		var row: Dictionary = row_value
		var spawn_id := String(row.spawn_id)
		var event_id := String(row.event_id)
		_row_by_spawn[spawn_id] = row
		if not _rows_by_event.has(event_id):
			_rows_by_event[event_id] = []
		(_rows_by_event[event_id] as Array).append(row)
	for budget_value in _contract.event_budgets:
		var budget: Dictionary = budget_value
		_budget_by_event[String(budget.event_id)] = budget
	_stage_cap = _maximum_stage_cap()
	_configured_contract_digest = CONTRACT_DIGEST
	_configured = true
	_configure_generation += 1
	return reset()

func is_configured() -> bool:
	return _configured

func has_hard_error() -> bool:
	return not _hard_error_code.is_empty()

func last_error() -> String:
	if _hard_error_code.is_empty():
		return ""
	return "%s at %s: %s" % [_hard_error_code, _hard_error_path, _hard_error_message]

func hard_error_snapshot() -> Dictionary:
	return {
		"code": _hard_error_code,
		"path": _hard_error_path,
		"message": _hard_error_message,
	}

func validation_errors() -> Array[String]:
	return _validation_errors.duplicate()

func is_trusted_copy_compatible_with(source) -> bool:
	return (
		source is RefCounted
		and is_instance_valid(source)
		and source != self
		and source.get_script() == get_script()
		and _configured
		and bool(source._configured)
		and _configured_contract_digest == CONTRACT_DIGEST
		and _configured_contract_digest == String(source._configured_contract_digest)
		and _difficulty == String(source._difficulty)
		and _stage_run_uid == String(source._stage_run_uid)
		and _stage_cap == int(source._stage_cap)
	)

func trusted_copy_mutable_state_from(source) -> bool:
	# This is an internal owner-to-owner transfer. Configuration was already
	# validated when each owner was built; persistence must continue to use the
	# public validate_snapshot/restore_snapshot path below.
	if not is_trusted_copy_compatible_with(source) or _update_in_progress or bool(source._update_in_progress):
		return false
	_hard_error_code = String(source._hard_error_code)
	_hard_error_path = String(source._hard_error_path)
	_hard_error_message = String(source._hard_error_message)
	_schedule_cursor_tick = int(source._schedule_cursor_tick)
	_last_stage_tick = int(source._last_stage_tick)
	_last_event_sequence = int(source._last_event_sequence)
	_current_event_id = String(source._current_event_id)
	_source_states = (source._source_states as Dictionary).duplicate(true)
	_active_bullets = (source._active_bullets as Dictionary).duplicate(true)
	# These ledgers contain primitive values only. Their dictionaries still need
	# independent containers for candidate mutation, but recursive duplication
	# allocates no additional isolation and creates fixed-tick variance.
	_used_uids = (source._used_uids as Dictionary).duplicate()
	_processed_callbacks = (source._processed_callbacks as Dictionary).duplicate()
	_activated_events = (source._activated_events as Dictionary).duplicate()
	_defeated_sources = (source._defeated_sources as Dictionary).duplicate()
	_grazed_uids = (source._grazed_uids as Dictionary).duplicate()
	_hard_state = (source._hard_state as Dictionary).duplicate()
	_telemetry_counts = (source._telemetry_counts as Dictionary).duplicate()
	return true

func reset() -> bool:
	if not _configured:
		return false
	_update_in_progress = false
	_schedule_cursor_tick = -1
	_last_stage_tick = -1
	_last_event_sequence = -1
	_current_event_id = ""
	_source_states.clear()
	_active_bullets.clear()
	_used_uids.clear()
	_processed_callbacks.clear()
	_activated_events.clear()
	_defeated_sources.clear()
	_grazed_uids.clear()
	_hard_state = {
		"stage_front_revision_id": "stage_front_initial",
		"blue_emission_state_id": "pre_red",
		"yellow_emission_state_id": "pre_mirror",
		"selected_mirror_spawn_id": "",
		"surviving_mirror_spawn_id": "",
		"mirror_activation_mask": 0,
	}
	_telemetry_counts = {}
	for key in TELEMETRY_COUNT_KEYS:
		_telemetry_counts[key] = 0
	for row_value in _rows:
		var spawn_id := String((row_value as Dictionary).spawn_id)
		_source_states[spawn_id] = {
			"activated": false,
			"alive": false,
			"activated_tick": -1,
			"removed_tick": -1,
			"next_warning_index": 0,
			"next_burst_index": 0,
		}
	_hard_error_code = ""
	_hard_error_path = ""
	_hard_error_message = ""
	return true

func contract_summary() -> Dictionary:
	if not _configured:
		return {}
	var primitive_counts := {}
	for primitive in PRIMITIVES:
		primitive_counts[primitive] = 0
	var topology_ids: Array[String] = []
	var fingerprints: Array[String] = []
	var event_budget_ids: Array[String] = []
	for row_value in _rows:
		var row: Dictionary = row_value
		var primitive := String(row.source.pattern.primitive)
		primitive_counts[primitive] = int(primitive_counts.get(primitive, 0)) + 1
		for difficulty in DIFFICULTIES:
			var profile: Dictionary = row.profiles[difficulty]
			topology_ids.append(String(profile.topology_id))
			fingerprints.append(String(profile.topology_fingerprint))
	topology_ids.sort()
	fingerprints.sort()
	for event_id in EVENT_IDS:
		event_budget_ids.append(event_id)
	return {
		"artifact_id": String(_contract.artifact_id),
		"contract_digest": CONTRACT_DIGEST,
		"difficulty": _difficulty,
		"spawn_row_count": _rows.size(),
		"field_owned_spawn_count": _rows.size() - 1,
		"fingerprint_count": fingerprints.size(),
		"event_budget_count": _budget_by_event.size(),
		"primitive_counts": primitive_counts,
		"topology_ids": topology_ids,
		"fingerprints": fingerprints,
		"event_budget_ids": event_budget_ids,
		"stage_cap": _stage_cap,
	}

func definition_for_spawn(spawn_id: String) -> Dictionary:
	if not _configured or not _row_by_spawn.has(spawn_id):
		return {}
	var row: Dictionary = _row_by_spawn[spawn_id]
	return {
		"event_id": String(row.event_id),
		"spawn_id": spawn_id,
		"enemy_id": String(row.enemy_id),
		"source": row.source.duplicate(true),
		"profile": (row.profiles[_difficulty] as Dictionary).duplicate(true),
	}

func bullet_state(bullet_uid: String) -> Dictionary:
	return (_active_bullets[bullet_uid] as Dictionary).duplicate(true) if _active_bullets.has(bullet_uid) else {}

func trusted_active_bullet_count() -> int:
	return _active_bullets.size()

func trusted_bullet_state_readonly(bullet_uid: String) -> Dictionary:
	# Main uses this only while validating an unpublished aggregate. Callers must
	# not retain or mutate the returned internal record.
	return _active_bullets[bullet_uid] if _active_bullets.has(bullet_uid) else {}

func trusted_callback_cursor_matches(stage_tick: int, event_sequence: int) -> bool:
	return _last_stage_tick == stage_tick and _last_event_sequence == event_sequence

func make_bullet_uid(event_id: String, spawn_id: String, emitter_id: String, burst_index: int, shot_index: int) -> Dictionary:
	for value in [_stage_run_uid, event_id, spawn_id, emitter_id]:
		if not _valid_uid_component(String(value)):
			return {"ok": false, "bullet_uid": "", "error": "uid_component_invalid"}
	if burst_index < 0 or shot_index < 0:
		return {"ok": false, "bullet_uid": "", "error": "uid_index_invalid"}
	return {
		"ok": true,
		"bullet_uid": "%s:%s:%s:%s:%d:%d" % [_stage_run_uid, event_id, spawn_id, emitter_id, burst_index, shot_index],
		"error": "",
	}

func validate_bullet_uid(bullet_uid: String) -> bool:
	var parts := bullet_uid.split(":", false)
	if parts.size() != 6 or parts[0] != _stage_run_uid:
		return false
	for index in range(4):
		if not _valid_uid_component(parts[index]):
			return false
	if not parts[4].is_valid_int() or not parts[5].is_valid_int():
		return false
	return int(parts[4]) >= 0 and int(parts[5]) >= 0

func activate_event(event_id: String, active_entity_ids: Array, stage_tick: int, event_sequence: int) -> Dictionary:
	var output := _empty_output(stage_tick, event_sequence)
	var begin := _begin_callback("activate_event", stage_tick, event_sequence, {"event_id": event_id, "active_entity_ids": active_entity_ids}, output)
	if not bool(begin.ok):
		return _finalize_output(output)
	if bool(begin.duplicate):
		output["duplicate"] = true
		return _finalize_output(output)
	if event_id not in EVENT_IDS:
		_runtime_fail("unknown_event", "event.%s" % event_id, "event is outside the frozen 18-budget sequence", output)
		return _finalize_output(output)
	if stage_tick != int(EVENT_TICKS[event_id]):
		_runtime_fail("event_tick_mismatch", "event.%s.authored_tick" % event_id, "expected %d, got %d" % [EVENT_TICKS[event_id], stage_tick], output)
		return _finalize_output(output)
	if _schedule_cursor_tick >= stage_tick:
		_runtime_fail("late_event_activation", "event.%s" % event_id, "the schedule cursor already consumed this event tick", output)
		return _finalize_output(output)
	if _activated_events.has(event_id):
		_note_duplicate(output, "event_activation", event_id)
		return _finalize_output(output)
	var seen_active := {}
	for active_value in active_entity_ids:
		if typeof(active_value) != TYPE_STRING:
			_runtime_fail("active_entity_id_invalid", "event.%s.active_entity_ids" % event_id, "active entity IDs must be strings", output)
			return _finalize_output(output)
		var active_id := String(active_value)
		if seen_active.has(active_id) or not _source_states.has(active_id) or not bool((_source_states[active_id] as Dictionary).alive):
			_runtime_fail("active_entity_carryover_invalid", "event.%s.active_entity_ids.%s" % [event_id, active_id], "carryover must name one unique currently alive source", output)
			return _finalize_output(output)
		seen_active[active_id] = true
	if event_id == "s2_b16" and not _s2_b16_entry_is_valid(seen_active):
		_runtime_fail("s2_b16_recovery_state_invalid", "event.s2_b16.active_entity_ids", "selected mirror, live survivor, mask, and explicit carryover must agree at entry", output)
		return _finalize_output(output)
	_activated_events[event_id] = true
	_current_event_id = event_id
	var current_cap := int(((_budget_by_event[event_id] as Dictionary).peak_active_bullets as Dictionary)[_difficulty])
	if _active_bullets.size() > mini(current_cap, _stage_cap):
		_runtime_fail("active_bullet_cap_exceeded", "event.%s.activation" % event_id, "carryover already exceeds the newly active event/stage cap", output)
		return _finalize_output(output)
	for row_value in _rows_by_event.get(event_id, []):
		var row: Dictionary = row_value
		var spawn_id := String(row.spawn_id)
		var state: Dictionary = _source_states[spawn_id]
		if bool(state.activated):
			continue
		state.activated = true
		state.alive = true
		state.activated_tick = stage_tick
		_source_states[spawn_id] = state
		output.source_activations.append({
			"stage_tick": stage_tick,
			"event_sequence": event_sequence,
			"event_id": event_id,
			"spawn_id": spawn_id,
			"enemy_id": String(row.enemy_id),
			"execution_owner": _execution_owner(row),
			"topology_id": String((row.profiles[_difficulty] as Dictionary).topology_id),
			"topology_fingerprint": String((row.profiles[_difficulty] as Dictionary).topology_fingerprint),
		})
		_increment_count("source_activations", 1)
	return _finalize_output(output)

func remove_source(spawn_id: String, stage_tick: int, event_sequence: int, reason: String = "despawn") -> Dictionary:
	var output := _empty_output(stage_tick, event_sequence)
	var begin := _begin_callback("remove_source", stage_tick, event_sequence, {"spawn_id": spawn_id, "reason": reason}, output)
	if not bool(begin.ok):
		return _finalize_output(output)
	if bool(begin.duplicate):
		output["duplicate"] = true
		return _finalize_output(output)
	_remove_source_internal(spawn_id, stage_tick, event_sequence, reason, output, false)
	return _finalize_output(output)

func accept_defeat(spawn_id: String, stage_tick: int, event_sequence: int) -> Dictionary:
	var output := _empty_output(stage_tick, event_sequence)
	var begin := _begin_callback("accept_defeat", stage_tick, event_sequence, {"spawn_id": spawn_id}, output)
	if not bool(begin.ok):
		return _finalize_output(output)
	if bool(begin.duplicate):
		output["duplicate"] = true
		return _finalize_output(output)
	if _defeated_sources.has(spawn_id):
		_note_duplicate(output, "defeat", spawn_id)
		return _finalize_output(output)
	if not _source_states.has(spawn_id) or not bool((_source_states[spawn_id] as Dictionary).alive):
		_runtime_fail("defeat_source_not_alive", "source.%s" % spawn_id, "defeat must name a currently alive source", output)
		return _finalize_output(output)
	_defeated_sources[spawn_id] = true
	_apply_defeat_transition(spawn_id, stage_tick, event_sequence, output)
	if has_hard_error():
		return _finalize_output(output)
	_remove_source_internal(spawn_id, stage_tick, event_sequence, "defeat", output, true)
	return _finalize_output(output)

func clear_field_bullets(stage_tick: int, event_sequence: int, reason: String = "explicit_clear") -> Dictionary:
	var output := _empty_output(stage_tick, event_sequence)
	var begin := _begin_callback("clear_field_bullets", stage_tick, event_sequence, {"reason": reason}, output)
	if not bool(begin.ok):
		return _finalize_output(output)
	if bool(begin.duplicate):
		output["duplicate"] = true
		return _finalize_output(output)
	_clear_active_bullets(stage_tick, event_sequence, reason, output)
	return _finalize_output(output)

func observe_graze(bullet_uid: String, stage_tick: int, event_sequence: int) -> Dictionary:
	var output := _empty_output(stage_tick, event_sequence)
	var begin := _begin_callback("observe_graze", stage_tick, event_sequence, {"bullet_uid": bullet_uid}, output)
	if not bool(begin.ok):
		return _finalize_output(output)
	if bool(begin.duplicate):
		output["duplicate"] = true
		return _finalize_output(output)
	if _grazed_uids.has(bullet_uid):
		_note_duplicate(output, "graze", bullet_uid)
		return _finalize_output(output)
	if not _active_bullets.has(bullet_uid):
		output.telemetry.append({"kind": "graze_rejected", "bullet_uid": bullet_uid, "reason": "bullet_not_active"})
		return _finalize_output(output)
	var bullet: Dictionary = _active_bullets[bullet_uid]
	var row: Dictionary = _row_by_spawn.get(String(bullet.bullet_source_spawn_id), {})
	var hooks: Array = row.get("source", {}).get("score_route_hooks", [])
	if String(bullet.source_primitive) != "rebound_bead" or "rebound_graze_uid" not in hooks:
		output.telemetry.append({"kind": "graze_rejected", "bullet_uid": bullet_uid, "reason": "source_not_qualifying"})
		return _finalize_output(output)
	if int(bullet.reflection_count) < 1 or bullet.first_reflection_tick == null or stage_tick < int(bullet.first_reflection_tick):
		output.telemetry.append({"kind": "graze_rejected", "bullet_uid": bullet_uid, "reason": "reflection_not_latched"})
		return _finalize_output(output)
	_grazed_uids[bullet_uid] = true
	bullet["graze_tick"] = stage_tick
	_active_bullets[bullet_uid] = bullet
	output.score_route_callbacks.append({
		"stage_run_uid": _stage_run_uid,
		"difficulty": _difficulty,
		"stage_tick": stage_tick,
		"event_sequence": event_sequence,
		"event_id": String(bullet.event_id),
		"bullet_uid": bullet_uid,
		"bullet_source_spawn_id": String(bullet.bullet_source_spawn_id),
		"bullet_spawn_tick": int(bullet.bullet_spawn_tick),
		"first_reflection_tick": int(bullet.first_reflection_tick),
		"reflection_count_before_graze": int(bullet.reflection_count),
		"graze_tick": stage_tick,
	})
	_increment_count("grazes_projected", 1)
	return _finalize_output(output)

func advance(stage_tick: int, event_sequence: int) -> Dictionary:
	var output := _empty_output(stage_tick, event_sequence)
	var begin := _begin_callback("advance", stage_tick, event_sequence, {}, output)
	if not bool(begin.ok):
		return _finalize_output(output)
	if bool(begin.duplicate):
		output["duplicate"] = true
		return _finalize_output(output)
	if _schedule_cursor_tick < stage_tick:
		if not _emit_due_tick(stage_tick, event_sequence, output):
			return _finalize_output(output)
		_schedule_cursor_tick = stage_tick
	return _finalize_output(output)

func telemetry_snapshot() -> Dictionary:
	if not _configured:
		return {}
	var active_source_ids: Array[String] = []
	for spawn_id in EXPECTED_SPAWN_IDS:
		if bool((_source_states.get(spawn_id, {}) as Dictionary).get("alive", false)):
			active_source_ids.append(spawn_id)
	var active_bullet_uids: Array[String] = []
	for uid in _active_bullets.keys():
		active_bullet_uids.append(String(uid))
	active_bullet_uids.sort()
	var defeated: Array[String] = []
	for spawn_id in _defeated_sources.keys():
		defeated.append(String(spawn_id))
	defeated.sort()
	var grazed_uids: Array[String] = []
	for uid in _grazed_uids.keys():
		grazed_uids.append(String(uid))
	grazed_uids.sort()
	return {
		"configured": _configured,
		"configure_generation": _configure_generation,
		"hard_error": hard_error_snapshot(),
		"difficulty": _difficulty,
		"stage_run_uid": _stage_run_uid,
		"schedule_cursor_tick": _schedule_cursor_tick,
		"last_callback_key": [_last_stage_tick, _last_event_sequence],
		"current_event_id": _current_event_id,
		"active_source_ids": active_source_ids,
		"active_bullet_count": active_bullet_uids.size(),
		"active_bullet_uids": active_bullet_uids,
		"used_uid_count": _used_uids.size(),
		"grazed_bullet_uids": grazed_uids,
		"defeated_source_ids": defeated,
		"hard_state": _hard_state.duplicate(),
		"counts": _telemetry_counts.duplicate(),
	}

func capture_snapshot() -> Dictionary:
	if not _configured or has_hard_error():
		return {}
	var used_uids: Array[String] = []
	for uid in _used_uids.keys():
		used_uids.append(String(uid))
	used_uids.sort()
	var callbacks: Array[String] = []
	for callback_id in _processed_callbacks.keys():
		callbacks.append(String(callback_id))
	callbacks.sort()
	var activated: Array[String] = []
	for event_id in _activated_events.keys():
		activated.append(String(event_id))
	activated.sort()
	var defeated: Array[String] = []
	for spawn_id in _defeated_sources.keys():
		defeated.append(String(spawn_id))
	defeated.sort()
	var grazed_uids: Array[String] = []
	for uid in _grazed_uids.keys():
		grazed_uids.append(String(uid))
	grazed_uids.sort()
	var payload := {
		"contract_digest": CONTRACT_DIGEST,
		"difficulty": _difficulty,
		"stage_run_uid": _stage_run_uid,
		"stage_cap": _stage_cap,
		"schedule_cursor_tick": _schedule_cursor_tick,
		"last_stage_tick": _last_stage_tick,
		"last_event_sequence": _last_event_sequence,
		"current_event_id": _current_event_id,
		"source_states": _source_states.duplicate(true),
		"active_bullets": _active_bullets.duplicate(true),
		"used_uids": used_uids,
		"processed_callbacks": callbacks,
		"activated_events": activated,
		"defeated_sources": defeated,
		"grazed_uids": grazed_uids,
		"hard_state": _hard_state.duplicate(true),
		"telemetry_counts": _telemetry_counts.duplicate(true),
	}
	return {
		"schema": SNAPSHOT_SCHEMA,
		"version": SNAPSHOT_VERSION,
		"payload": payload,
		"state_digest": _stable_digest(payload),
	}

func validate_snapshot(snapshot: Dictionary) -> bool:
	if not _configured or has_hard_error() or not _has_exact_keys(snapshot, ["schema", "version", "payload", "state_digest"]):
		return false
	if String(snapshot.schema) != SNAPSHOT_SCHEMA or typeof(snapshot.version) != TYPE_INT or int(snapshot.version) != SNAPSHOT_VERSION:
		return false
	if not (snapshot.payload is Dictionary) or typeof(snapshot.state_digest) != TYPE_STRING:
		return false
	var payload: Dictionary = snapshot.payload
	if not _has_exact_keys(payload, SNAPSHOT_PAYLOAD_KEYS):
		return false
	var computed_digest := _stable_digest(payload)
	if computed_digest.is_empty() or String(snapshot.state_digest) != computed_digest:
		return false
	if String(payload.contract_digest) != CONTRACT_DIGEST or String(payload.difficulty) != _difficulty or String(payload.stage_run_uid) != _stage_run_uid:
		return false
	if typeof(payload.stage_cap) != TYPE_INT or int(payload.stage_cap) != _stage_cap:
		return false
	for key in ["schedule_cursor_tick", "last_stage_tick", "last_event_sequence"]:
		if typeof(payload[key]) != TYPE_INT:
			return false
	if int(payload.schedule_cursor_tick) < -1 or int(payload.schedule_cursor_tick) > MAX_STAGE_TICK:
		return false
	if int(payload.last_stage_tick) < -1 or int(payload.last_stage_tick) > MAX_STAGE_TICK or int(payload.last_event_sequence) < -1:
		return false
	if typeof(payload.current_event_id) != TYPE_STRING or (not String(payload.current_event_id).is_empty() and String(payload.current_event_id) not in EVENT_IDS):
		return false
	if not (payload.source_states is Dictionary) or not (payload.active_bullets is Dictionary):
		return false
	if not (payload.used_uids is Array) or not (payload.processed_callbacks is Array) or not (payload.activated_events is Array) or not (payload.defeated_sources is Array):
		return false
	if not (payload.grazed_uids is Array):
		return false
	if not (payload.hard_state is Dictionary) or not (payload.telemetry_counts is Dictionary):
		return false
	if not _validate_snapshot_sources(payload.source_states):
		return false
	if not _validate_snapshot_string_set(payload.used_uids) or not _validate_snapshot_string_set(payload.processed_callbacks):
		return false
	if not _validate_snapshot_string_set(payload.activated_events) or not _validate_snapshot_string_set(payload.defeated_sources):
		return false
	if not _validate_snapshot_string_set(payload.grazed_uids):
		return false
	for event_id in payload.activated_events:
		if String(event_id) not in EVENT_IDS:
			return false
	for spawn_id in payload.defeated_sources:
		if not _row_by_spawn.has(String(spawn_id)):
			return false
	if not _has_exact_keys(payload.hard_state, HARD_STATE_KEYS):
		return false
	if not _has_exact_keys(payload.telemetry_counts, TELEMETRY_COUNT_KEYS):
		return false
	for key in TELEMETRY_COUNT_KEYS:
		if typeof(payload.telemetry_counts[key]) != TYPE_INT or int(payload.telemetry_counts[key]) < 0:
			return false
	var used_lookup := {}
	for uid_value in payload.used_uids:
		var uid := String(uid_value)
		if not validate_bullet_uid(uid):
			return false
		used_lookup[uid] = true
	for uid_value in payload.grazed_uids:
		if not used_lookup.has(String(uid_value)):
			return false
	if not _validate_snapshot_cross_fields(payload):
		return false
	var active_cap := _stage_cap
	if not String(payload.current_event_id).is_empty():
		active_cap = mini(active_cap, int(((_budget_by_event[String(payload.current_event_id)] as Dictionary).peak_active_bullets as Dictionary)[_difficulty]))
	if payload.active_bullets.size() > active_cap:
		return false
	for uid_value in payload.active_bullets.keys():
		var uid := String(uid_value)
		if not used_lookup.has(uid) or not (payload.active_bullets[uid] is Dictionary):
			return false
		if not _validate_bullet_snapshot(uid, payload.active_bullets[uid], payload):
			return false
	return true

func restore_snapshot(snapshot: Dictionary) -> bool:
	if not validate_snapshot(snapshot):
		return false
	var payload: Dictionary = snapshot.payload
	var restored_used := {}
	for uid in payload.used_uids:
		restored_used[String(uid)] = true
	var restored_callbacks := {}
	for callback_id in payload.processed_callbacks:
		restored_callbacks[String(callback_id)] = true
	var restored_events := {}
	for event_id in payload.activated_events:
		restored_events[String(event_id)] = true
	var restored_defeated := {}
	for spawn_id in payload.defeated_sources:
		restored_defeated[String(spawn_id)] = true
	var restored_grazed := {}
	for uid in payload.grazed_uids:
		restored_grazed[String(uid)] = true
	_schedule_cursor_tick = int(payload.schedule_cursor_tick)
	_last_stage_tick = int(payload.last_stage_tick)
	_last_event_sequence = int(payload.last_event_sequence)
	_current_event_id = String(payload.current_event_id)
	_source_states = (payload.source_states as Dictionary).duplicate(true)
	_active_bullets = (payload.active_bullets as Dictionary).duplicate(true)
	_used_uids = restored_used
	_processed_callbacks = restored_callbacks
	_activated_events = restored_events
	_defeated_sources = restored_defeated
	_grazed_uids = restored_grazed
	_hard_state = (payload.hard_state as Dictionary).duplicate(true)
	_telemetry_counts = (payload.telemetry_counts as Dictionary).duplicate(true)
	return true

func seek_snapshot(snapshot: Dictionary) -> bool:
	return restore_snapshot(snapshot)

func _validate_contract(contract: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if int(contract.get("schema_version", -1)) != CONTRACT_SCHEMA_VERSION:
		errors.append("schema_version: expected 1")
	if String(contract.get("artifact_id", "")) != CONTRACT_ARTIFACT_ID:
		errors.append("artifact_id: unexpected field topology artifact")
	if String(contract.get("stage_id", "")) != "yokai_market":
		errors.append("stage_id: expected yokai_market")
	if contract.get("difficulty_scope") != DIFFICULTIES:
		errors.append("difficulty_scope: expected exact normal, hard order")
	if not (contract.get("spawn_topologies") is Array) or (contract.spawn_topologies as Array).size() != EXPECTED_SPAWN_COUNT:
		errors.append("spawn_topologies: expected exactly 22 rows")
		return errors
	if not (contract.get("event_budgets") is Array) or (contract.event_budgets as Array).size() != EXPECTED_EVENT_BUDGET_COUNT:
		errors.append("event_budgets: expected exactly 18 budgets")
		return errors
	if not (contract.get("primitive_contracts") is Dictionary):
		errors.append("primitive_contracts: expected dictionary")
		return errors
	var primitive_keys: Array = (contract.primitive_contracts as Dictionary).keys()
	primitive_keys.sort()
	var expected_primitive_keys: Array = PRIMITIVES.duplicate()
	expected_primitive_keys.sort()
	if primitive_keys != expected_primitive_keys:
		errors.append("primitive_contracts: expected exact four primitives")
	var scope: Dictionary = contract.get("contract_scope", {})
	if int(scope.get("covered_spawn_count", -1)) != EXPECTED_SPAWN_COUNT or int(scope.get("field_owned_spawn_count", -1)) != 21:
		errors.append("contract_scope.coverage: expected 22 total and 21 field-owned rows")
	var coordinate: Dictionary = contract.get("coordinate_contract", {})
	if int(coordinate.get("tick_rate", -1)) != TICK_RATE or not _valid_combat_bounds(coordinate.get("combat_bounds")):
		errors.append("coordinate_contract: tick rate or combat bounds mismatch")
	var seen_spawns := {}
	var seen_topologies := {}
	var seen_fingerprints := {}
	for index in range(EXPECTED_SPAWN_COUNT):
		var row_value = contract.spawn_topologies[index]
		var path := "spawn_topologies[%d]" % index
		if not (row_value is Dictionary):
			errors.append("%s: expected dictionary" % path)
			continue
		var row: Dictionary = row_value
		if not _has_exact_keys(row, ROW_KEYS):
			errors.append("%s: row keys mismatch" % path)
			continue
		var spawn_id := String(row.spawn_id)
		if spawn_id != EXPECTED_SPAWN_IDS[index] or seen_spawns.has(spawn_id) or not _valid_machine_id(spawn_id):
			errors.append("%s.spawn_id: missing, reordered, duplicate, or malformed" % path)
		seen_spawns[spawn_id] = true
		var event_id := String(row.event_id)
		if event_id not in EVENT_IDS:
			errors.append("%s.event_id: unknown event" % path)
		if not (row.source is Dictionary) or not (row.profiles is Dictionary):
			errors.append("%s: source and profiles must be dictionaries" % path)
			continue
		_validate_source_row(row, path, errors)
		var profile_keys: Array = row.profiles.keys()
		profile_keys.sort()
		var expected_profile_keys: Array = DIFFICULTIES.duplicate()
		expected_profile_keys.sort()
		if profile_keys != expected_profile_keys:
			errors.append("%s.profiles: expected exactly normal and hard" % path)
			continue
		var normal_fingerprint := ""
		for difficulty in DIFFICULTIES:
			var profile_value = row.profiles[difficulty]
			var profile_path := "%s.profiles.%s" % [path, difficulty]
			if not (profile_value is Dictionary):
				errors.append("%s: expected dictionary" % profile_path)
				continue
			var profile: Dictionary = profile_value
			var phase_owned := String(row.source.pattern.routing) == "phase_owned"
			if not phase_owned and not _has_exact_keys(profile, PROFILE_KEYS):
				errors.append("%s: profile keys mismatch" % profile_path)
			if phase_owned and not _has_required_keys(profile, PROFILE_KEYS + ["execution_owner"]):
				errors.append("%s: delegated profile keys mismatch" % profile_path)
			var topology_id := String(profile.get("topology_id", ""))
			var fingerprint := String(profile.get("topology_fingerprint", ""))
			if not _valid_machine_id(topology_id) or seen_topologies.has(topology_id):
				errors.append("%s.topology_id: malformed or duplicate" % profile_path)
			seen_topologies[topology_id] = true
			if not _valid_fingerprint(fingerprint, String(row.source.pattern.primitive)) or seen_fingerprints.has(fingerprint):
				errors.append("%s.topology_fingerprint: malformed or duplicate" % profile_path)
			seen_fingerprints[fingerprint] = true
			if difficulty == "normal":
				normal_fingerprint = fingerprint
			elif fingerprint == normal_fingerprint:
				errors.append("%s.topology_fingerprint: hard must be structurally distinct" % profile_path)
			_validate_profile(row, profile, difficulty, profile_path, contract, errors)
	if seen_fingerprints.size() != EXPECTED_FINGERPRINT_COUNT or seen_topologies.size() != EXPECTED_FINGERPRINT_COUNT:
		errors.append("spawn_topologies.profiles: expected 44 unique fingerprints and topology IDs")
	_validate_budgets(contract.event_budgets, errors)
	_validate_conservative_event_schedules(contract, errors)
	var digest := _stable_digest(contract)
	if digest != CONTRACT_DIGEST:
		errors.append("contract_digest: frozen v1 content mismatch (%s)" % digest)
	return errors

func _valid_combat_bounds(value: Variant) -> bool:
	if not (value is Array) or (value as Array).size() != COMBAT_BOUNDS.size():
		return false
	var bounds: Array = value
	for index in range(COMBAT_BOUNDS.size()):
		if not _finite_number(bounds[index]) or float(bounds[index]) != float(COMBAT_BOUNDS[index]):
			return false
	return true

func _validate_source_row(row: Dictionary, path: String, errors: Array[String]) -> void:
	var source: Dictionary = row.source
	var pattern: Dictionary = source.get("pattern", {})
	var event_id := String(row.event_id)
	if int(source.get("authored_tick", -1)) != int(EVENT_TICKS.get(event_id, -2)):
		errors.append("%s.source.authored_tick: source event tick mismatch" % path)
	if int(source.get("deadline_tick", -1)) < int(source.get("authored_tick", 0)):
		errors.append("%s.source.deadline_tick: precedes authored tick" % path)
	if String(row.get("enemy_id", "")) == "" or not _valid_machine_id(String(row.enemy_id)):
		errors.append("%s.enemy_id: malformed" % path)
	if not _valid_numeric_pair(source.get("position")) or not (source.get("movement") is Dictionary):
		errors.append("%s.source: position or movement malformed" % path)
	if not (source.get("drop_item_ids") is Array) or not (source.get("score_route_hooks") is Array):
		errors.append("%s.source: drops or score hooks malformed" % path)
	var primitive := String(pattern.get("primitive", ""))
	if primitive not in PRIMITIVES or not _valid_machine_id(String(pattern.get("routing", ""))):
		errors.append("%s.source.pattern: primitive or routing malformed" % path)
	if int(pattern.get("start_delay_ticks", -1)) < 0 or int(pattern.get("interval_ticks", 0)) <= 0 or int(pattern.get("shots_per_burst", 0)) <= 0:
		errors.append("%s.source.pattern: schedule must be positive and bounded" % path)
	var phase_owned := String(pattern.get("routing", "")) == "phase_owned"
	if (phase_owned and float(pattern.get("speed", -1.0)) != 0.0) or (not phase_owned and float(pattern.get("speed", 0.0)) <= 0.0):
		errors.append("%s.source.pattern.speed: execution-owner mismatch" % path)
	for uid_value in [row.event_id, row.spawn_id, row.enemy_id, pattern.get("routing", "")]:
		if not _valid_uid_component(String(uid_value)):
			errors.append("%s.source: UID component contains a colon or is empty" % path)

func _validate_profile(row: Dictionary, profile: Dictionary, difficulty: String, path: String, contract: Dictionary, errors: Array[String]) -> void:
	var source: Dictionary = row.source
	var pattern: Dictionary = source.pattern
	var primitive := String(pattern.primitive)
	var phase_owned := String(pattern.routing) == "phase_owned"
	var lifetime := int(profile.get("lifetime_ticks", -1))
	if int(profile.get("warning_lead_ticks", -1)) != int(source.get("warning_lead_ticks", -2)):
		errors.append("%s.warning_lead_ticks: must retain exact source lead" % path)
	if phase_owned:
		if lifetime != 0 or String(profile.get("execution_owner", "")) != "phase_runtime":
			errors.append("%s: delegated row must have zero field lifetime" % path)
		return
	if lifetime <= 0 or lifetime > MAX_LIFETIME_TICKS:
		errors.append("%s.lifetime_ticks: outside the bounded field lifetime" % path)
	if primitive in ["grid_edge", "lane_fan"] and lifetime > 300:
		errors.append("%s.lifetime_ticks: exceeds primitive cap" % path)
	if not (profile.get("geometry") is Dictionary):
		errors.append("%s.geometry: expected dictionary" % path)
		return
	var geometry: Dictionary = profile.geometry
	var primitive_contract: Dictionary = contract.primitive_contracts.get(primitive, {})
	for required_key in primitive_contract.get("required_profile_geometry", []):
		if not geometry.has(String(required_key)):
			errors.append("%s.geometry.%s: required field missing" % [path, required_key])
	_validate_geometry(row, profile, difficulty, path, contract, errors)

func _validate_geometry(row: Dictionary, profile: Dictionary, difficulty: String, path: String, contract: Dictionary, errors: Array[String]) -> void:
	var geometry: Dictionary = profile.geometry
	var pattern: Dictionary = row.source.pattern
	var primitive := String(pattern.primitive)
	var emitters = geometry.get("emitter_anchors")
	if not (emitters is Array) or (emitters as Array).is_empty():
		errors.append("%s.geometry.emitter_anchors: expected nonempty array" % path)
		return
	var emitter_ids := {}
	for emitter_value in emitters:
		if not (emitter_value is Dictionary):
			errors.append("%s.geometry.emitter_anchors: malformed emitter" % path)
			continue
		var emitter: Dictionary = emitter_value
		var emitter_id := String(emitter.get("emitter_id", ""))
		if not _valid_machine_id(emitter_id) or emitter_ids.has(emitter_id) or not _valid_point(emitter.get("position")):
			errors.append("%s.geometry.emitter_anchors.%s: invalid ID, duplicate, or position" % [path, emitter_id])
		emitter_ids[emitter_id] = true
	var safe_route: Dictionary = geometry.get("safe_route", {})
	var budget: Dictionary = _budget_for_validation(contract, String(row.event_id))
	var required_width := int((budget.get("minimum_safe_route_width_px", {}) as Dictionary).get(difficulty, 0))
	if int(safe_route.get("minimum_width_px", 0)) < required_width:
		errors.append("%s.geometry.safe_route.minimum_width_px: below event floor" % path)
	if not _validate_gap_values(safe_route):
		errors.append("%s.geometry.safe_route: gap center outside combat bounds" % path)
	var collision: Dictionary = geometry.get("collision_activation", {})
	if not bool(collision.get("warning_preview_only", false)):
		errors.append("%s.geometry.collision_activation: warning preview must be noncolliding" % path)
	match primitive:
		"rebound_bead":
			_validate_rebound_geometry(row, profile, path, errors)
		"grid_edge":
			_validate_grid_geometry(profile, path, errors)
		"lane_fan":
			_validate_lane_geometry(row, profile, path, errors)
		"delayed_seed":
			_validate_delayed_geometry(row, profile, path, errors)

func _validate_rebound_geometry(row: Dictionary, profile: Dictionary, path: String, errors: Array[String]) -> void:
	var geometry: Dictionary = profile.geometry
	if String(geometry.collision_activation.get("enable_at", "")) != "bullet_spawn_tick":
		errors.append("%s.geometry.collision_activation: rebound must enable on spawn" % path)
	var routes = geometry.get("ordered_routes")
	var surfaces = geometry.get("reflection_surfaces")
	if not (routes is Array) or (routes as Array).is_empty() or not (surfaces is Array):
		errors.append("%s.geometry: rebound routes or surfaces malformed" % path)
		return
	var surface_ids := {}
	for surface_value in surfaces:
		if not (surface_value is Dictionary):
			errors.append("%s.geometry.reflection_surfaces: malformed surface" % path)
			continue
		var surface: Dictionary = surface_value
		var surface_id := String(surface.get("surface_id", ""))
		if not _valid_machine_id(surface_id) or surface_ids.has(surface_id) or not _valid_segment(surface.get("segment")):
			errors.append("%s.geometry.reflection_surfaces.%s: malformed or duplicate" % [path, surface_id])
		surface_ids[surface_id] = true
	var greatest_turns := 0
	var speed := float(row.source.pattern.speed)
	for route_value in routes:
		if not (route_value is Dictionary):
			errors.append("%s.geometry.ordered_routes: malformed route" % path)
			continue
		var route: Dictionary = route_value
		var points = route.get("points")
		var reflection_ids = route.get("reflection_surface_ids")
		if not (points is Array) or (points as Array).size() < 2 or not (reflection_ids is Array):
			errors.append("%s.geometry.ordered_routes.%s: points or surface bindings malformed" % [path, route.get("route_id", "")])
			continue
		if (reflection_ids as Array).size() != (points as Array).size() - 2:
			errors.append("%s.geometry.ordered_routes.%s: reflection binding count mismatch" % [path, route.get("route_id", "")])
		greatest_turns = maxi(greatest_turns, (reflection_ids as Array).size())
		var distance := 0.0
		for point_index in range((points as Array).size()):
			if not _valid_point(points[point_index]):
				errors.append("%s.geometry.ordered_routes.%s.points[%d]: outside combat bounds" % [path, route.get("route_id", ""), point_index])
			if point_index > 0:
				distance += _point_distance(points[point_index - 1], points[point_index])
		for surface_id_value in reflection_ids:
			if not surface_ids.has(String(surface_id_value)):
				errors.append("%s.geometry.ordered_routes.%s: unknown reflection surface" % [path, route.get("route_id", "")])
		if distance * float(TICK_RATE) / speed >= float(profile.lifetime_ticks):
			errors.append("%s.geometry.ordered_routes.%s: route cannot finish inside lifetime" % [path, route.get("route_id", "")])
	if int(geometry.get("max_reflections", -1)) != greatest_turns:
		errors.append("%s.geometry.max_reflections: must equal greatest authored bound-turn count" % path)

func _validate_grid_geometry(profile: Dictionary, path: String, errors: Array[String]) -> void:
	var geometry: Dictionary = profile.geometry
	if String(geometry.collision_activation.get("enable_at", "")) != "bullet_spawn_tick":
		errors.append("%s.geometry.collision_activation: grid bullets must enable on spawn" % path)
	var edges = geometry.get("edge_segments")
	if not (edges is Array) or (edges as Array).is_empty():
		errors.append("%s.geometry.edge_segments: expected nonempty array" % path)
		return
	var edge_ids := {}
	for edge_value in edges:
		if not (edge_value is Dictionary):
			errors.append("%s.geometry.edge_segments: malformed edge" % path)
			continue
		var edge: Dictionary = edge_value
		var edge_id := String(edge.get("edge_id", ""))
		if not _valid_machine_id(edge_id) or edge_ids.has(edge_id) or not _valid_point(edge.get("from")) or not _valid_point(edge.get("to")) or not _finite_number(edge.get("travel_angle_deg")):
			errors.append("%s.geometry.edge_segments.%s: malformed or duplicate" % [path, edge_id])
		edge_ids[edge_id] = true

func _validate_lane_geometry(row: Dictionary, profile: Dictionary, path: String, errors: Array[String]) -> void:
	var geometry: Dictionary = profile.geometry
	if String(geometry.collision_activation.get("enable_at", "")) != "bullet_spawn_tick":
		errors.append("%s.geometry.collision_activation: lane fan must enable on spawn" % path)
	var offsets = geometry.get("fan_offsets_deg")
	var lanes = geometry.get("lane_sequence")
	if not (offsets is Array) or (offsets as Array).size() != int(row.source.pattern.shots_per_burst):
		errors.append("%s.geometry.fan_offsets_deg: must match exact shot count" % path)
	if not _valid_lane_array(lanes):
		errors.append("%s.geometry.lane_sequence: malformed lane sequence" % path)
	if geometry.get("lane_sequence_by_state") is Dictionary:
		for lane_value in (geometry.lane_sequence_by_state as Dictionary).values():
			if not _valid_lane_array(lane_value):
				errors.append("%s.geometry.lane_sequence_by_state: malformed state lane sequence" % path)

func _validate_delayed_geometry(row: Dictionary, profile: Dictionary, path: String, errors: Array[String]) -> void:
	var geometry: Dictionary = profile.geometry
	var delay := int(geometry.get("activation_delay_ticks", 0))
	if delay <= 0 or delay >= int(profile.lifetime_ticks):
		errors.append("%s.geometry.activation_delay_ticks: must be positive and inside lifetime" % path)
	if String(geometry.collision_activation.get("enable_at", "")) != "bullet_spawn_tick_plus_activation_delay_ticks":
		errors.append("%s.geometry.collision_activation: delayed seed activation expression mismatch" % path)
	var seeds = geometry.get("seed_positions")
	var seed_order = geometry.get("seed_activation_order")
	var routes = geometry.get("ordered_routes")
	if not (seeds is Array) or (seeds as Array).is_empty() or not (seed_order is Array) or not (routes is Array) or (routes as Array).is_empty():
		errors.append("%s.geometry: delayed seed schema malformed" % path)
		return
	var seed_ids := {}
	for seed_value in seeds:
		if not (seed_value is Dictionary):
			errors.append("%s.geometry.seed_positions: malformed seed" % path)
			continue
		var seed: Dictionary = seed_value
		var seed_id := String(seed.get("seed_id", ""))
		if not _valid_machine_id(seed_id) or seed_ids.has(seed_id) or not _valid_point(seed.get("position")):
			errors.append("%s.geometry.seed_positions.%s: malformed or duplicate" % [path, seed_id])
		seed_ids[seed_id] = true
	var ordered_ids := {}
	for seed_id_value in seed_order:
		var seed_id := String(seed_id_value)
		if not seed_ids.has(seed_id) or ordered_ids.has(seed_id):
			errors.append("%s.geometry.seed_activation_order: unknown or duplicate slot" % path)
		ordered_ids[seed_id] = true
	for route_value in routes:
		if not (route_value is Dictionary) or not ((route_value as Dictionary).get("points") is Array) or ((route_value as Dictionary).points as Array).size() < 2:
			errors.append("%s.geometry.ordered_routes: malformed delayed route" % path)
			continue
		for point in (route_value as Dictionary).points:
			if not _valid_point(point):
				errors.append("%s.geometry.ordered_routes: point outside combat bounds" % path)

func _validate_budgets(budgets: Array, errors: Array[String]) -> void:
	var seen := {}
	for index in range(budgets.size()):
		if not (budgets[index] is Dictionary):
			errors.append("event_budgets[%d]: expected dictionary" % index)
			continue
		var budget: Dictionary = budgets[index]
		var event_id := String(budget.get("event_id", ""))
		if event_id != EVENT_IDS[index] or seen.has(event_id):
			errors.append("event_budgets[%d].event_id: missing, reordered, or duplicate" % index)
		seen[event_id] = true
		var owner := String(budget.get("field_execution_owner", ""))
		if event_id in FIELD_EVENT_IDS and owner != "field_topology_contract":
			errors.append("event_budgets[%d].field_execution_owner: field event owner mismatch" % index)
		if event_id not in FIELD_EVENT_IDS and owner == "field_topology_contract":
			errors.append("event_budgets[%d].field_execution_owner: delegated event cannot emit field bullets" % index)
		for difficulty in DIFFICULTIES:
			var cap := int((budget.get("peak_active_bullets", {}) as Dictionary).get(difficulty, -1))
			if cap < 0 or cap > (156 if difficulty == "normal" else 204):
				errors.append("event_budgets[%d].peak_active_bullets.%s: outside stage cap" % [index, difficulty])
			if owner != "field_topology_contract" and int((budget.get("field_owned_emission_cap", {}) as Dictionary).get(difficulty, -1)) != 0:
				errors.append("event_budgets[%d].field_owned_emission_cap.%s: delegated event must be zero" % [index, difficulty])

func _validate_conservative_event_schedules(contract: Dictionary, errors: Array[String]) -> void:
	for event_id in FIELD_EVENT_IDS:
		var event_rows: Array = []
		for row_value in contract.spawn_topologies:
			var row: Dictionary = row_value
			if String(row.event_id) == event_id:
				event_rows.append(row)
		var budget := _budget_for_validation(contract, event_id)
		for difficulty in DIFFICULTIES:
			var conservative_bullets := 0
			for row_value in event_rows:
				var row: Dictionary = row_value
				var pattern: Dictionary = row.source.pattern
				var first_tick := int(row.source.authored_tick) + int(pattern.start_delay_ticks)
				var deadline := int(row.source.deadline_tick)
				var burst_count := 0
				if first_tick <= deadline:
					burst_count = (deadline - first_tick) / int(pattern.interval_ticks) + 1
				conservative_bullets += burst_count * int(pattern.shots_per_burst)
			var cap := int((budget.get("peak_active_bullets", {}) as Dictionary).get(difficulty, -1))
			if conservative_bullets > cap:
				errors.append("event_budgets.%s.%s: conservative source schedule exceeds active cap" % [event_id, difficulty])

func _budget_for_validation(contract: Dictionary, event_id: String) -> Dictionary:
	if not (contract.get("event_budgets") is Array):
		return {}
	for budget_value in contract.event_budgets:
		if budget_value is Dictionary and String((budget_value as Dictionary).get("event_id", "")) == event_id:
			return budget_value
	return {}

func _maximum_stage_cap() -> int:
	var result := 0
	for budget_value in _contract.event_budgets:
		var budget: Dictionary = budget_value
		result = maxi(result, int((budget.peak_active_bullets as Dictionary)[_difficulty]))
	return result

func _execution_owner(row: Dictionary) -> String:
	return "phase_runtime" if String(row.source.pattern.routing) == "phase_owned" else "field_topology_contract"

func _begin_callback(kind: String, stage_tick: int, event_sequence: int, payload: Dictionary, output: Dictionary) -> Dictionary:
	if not _configured:
		output.error = "runtime_not_configured"
		return {"ok": false, "duplicate": false}
	if has_hard_error():
		output.error = last_error()
		return {"ok": false, "duplicate": false}
	if _update_in_progress:
		output.error = "runtime_update_in_progress"
		return {"ok": false, "duplicate": false}
	_update_in_progress = true
	if stage_tick < 0 or stage_tick > MAX_STAGE_TICK or event_sequence < 0:
		_runtime_fail("callback_key_invalid", "callback.%s" % kind, "tick or event sequence is outside the supported range", output)
		return {"ok": false, "duplicate": false}
	var callback_id := "%s:%d:%d:%s" % [kind, stage_tick, event_sequence, _stable_digest(payload)]
	if _processed_callbacks.has(callback_id):
		_note_duplicate(output, kind, callback_id)
		return {"ok": true, "duplicate": true}
	if stage_tick < _last_stage_tick or (stage_tick == _last_stage_tick and event_sequence <= _last_event_sequence):
		_runtime_fail("callback_order_invalid", "callback.%s" % kind, "callbacks must be strictly ordered by (stage_tick,event_sequence)", output)
		return {"ok": false, "duplicate": false}
	if not _drain_ticks_before(stage_tick, output):
		return {"ok": false, "duplicate": false}
	_last_stage_tick = stage_tick
	_last_event_sequence = event_sequence
	_processed_callbacks[callback_id] = true
	return {"ok": true, "duplicate": false}

func _drain_ticks_before(stage_tick: int, output: Dictionary) -> bool:
	var tick := _schedule_cursor_tick + 1
	while tick < stage_tick:
		if not _emit_due_tick(tick, 0, output):
			return false
		_schedule_cursor_tick = tick
		tick += 1
	return true

func _emit_due_tick(stage_tick: int, event_sequence: int, output: Dictionary) -> bool:
	_process_bullet_lifecycle(stage_tick, event_sequence, output)
	for row_value in _rows:
		var row: Dictionary = row_value
		var spawn_id := String(row.spawn_id)
		var state: Dictionary = _source_states[spawn_id]
		if not bool(state.alive) or _execution_owner(row) != "field_topology_contract":
			continue
		var pattern: Dictionary = row.source.pattern
		var profile: Dictionary = row.profiles[_difficulty]
		var first_burst := int(row.source.authored_tick) + int(pattern.start_delay_ticks)
		var interval := int(pattern.interval_ticks)
		var warning_index := int(state.next_warning_index)
		var warning_tick := first_burst + warning_index * interval - int(profile.warning_lead_ticks)
		if warning_tick < stage_tick:
			return _runtime_fail("warning_schedule_skipped", "source.%s.warning.%d" % [spawn_id, warning_index], "an active source warning tick was skipped", output)
		if warning_tick == stage_tick:
			output.warnings.append(_warning_record(row, profile, warning_index, stage_tick, event_sequence))
			state.next_warning_index = warning_index + 1
			_increment_count("warnings", 1)
		var burst_index := int(state.next_burst_index)
		var burst_tick := first_burst + burst_index * interval
		if burst_tick < stage_tick:
			return _runtime_fail("burst_schedule_skipped", "source.%s.burst.%d" % [spawn_id, burst_index], "an active source burst tick was skipped", output)
		if burst_tick == stage_tick:
			if not _emit_burst(row, profile, burst_index, stage_tick, event_sequence, output):
				return false
			state.next_burst_index = burst_index + 1
		_source_states[spawn_id] = state
	return true

func _warning_record(row: Dictionary, profile: Dictionary, burst_index: int, stage_tick: int, event_sequence: int) -> Dictionary:
	var state_binding := _state_binding_for(row, burst_index)
	return {
		"stage_tick": stage_tick,
		"event_sequence": event_sequence,
		"bullet_spawn_tick": int(row.source.authored_tick) + int(row.source.pattern.start_delay_ticks) + burst_index * int(row.source.pattern.interval_ticks),
		"event_id": String(row.event_id),
		"spawn_id": String(row.spawn_id),
		"primitive": String(row.source.pattern.primitive),
		"routing": String(row.source.pattern.routing),
		"topology_id": String(profile.topology_id),
		"topology_fingerprint": String(profile.topology_fingerprint),
		"burst_index": burst_index,
		"collision_enabled": false,
		"activation_order": (profile.geometry.activation_order as Array).duplicate(true),
		"geometry": (profile.geometry as Dictionary).duplicate(true),
		"state_binding": state_binding,
	}

func _emit_burst(row: Dictionary, profile: Dictionary, burst_index: int, stage_tick: int, event_sequence: int, output: Dictionary) -> bool:
	var shot_count := int(row.source.pattern.shots_per_burst)
	var event_id := String(row.event_id)
	if String(row.spawn_id) == "s2_b16_abacus_keeper" and not _s2_b16_recovery_is_live():
		return _runtime_fail("s2_b16_recovery_state_invalid", "source.s2_b16_abacus_keeper.burst.%d" % burst_index, "recovery route cannot be selected after the survivor-alive bit becomes stale", output)
	var cap_event_id := _current_event_id if not _current_event_id.is_empty() else event_id
	var event_cap := int(((_budget_by_event[cap_event_id] as Dictionary).peak_active_bullets as Dictionary)[_difficulty])
	var cap := mini(event_cap, _stage_cap)
	if _active_bullets.size() + shot_count > cap:
		return _runtime_fail("active_bullet_cap_exceeded", "event.%s.burst.%d" % [event_id, burst_index], "whole burst would exceed event/stage cap; no shot was emitted", output)
	var constructions: Array = []
	for shot_index in range(shot_count):
		var record := _construct_bullet(row, profile, burst_index, shot_index, stage_tick)
		if record.is_empty():
			return _runtime_fail("bullet_construction_failed", "source.%s.burst.%d.shot.%d" % [row.spawn_id, burst_index, shot_index], "authored primitive could not be resolved", output)
		var uid := String(record.stage2_bullet_uid)
		if _used_uids.has(uid):
			return _runtime_fail("bullet_uid_reuse", "bullet.%s" % uid, "bullet UID was already used in this stage run", output)
		constructions.append(record)
	for record_value in constructions:
		var record: Dictionary = record_value
		var uid := String(record.stage2_bullet_uid)
		_used_uids[uid] = true
		_active_bullets[uid] = record.duplicate(true)
		output.bullet_constructions.append(record.duplicate(true))
	_increment_count("bursts", 1)
	_increment_count("bullets_constructed", constructions.size())
	return true

func _construct_bullet(row: Dictionary, profile: Dictionary, burst_index: int, shot_index: int, spawn_tick: int, state_override: Dictionary = {}) -> Dictionary:
	var geometry: Dictionary = profile.geometry
	var emitters: Array = geometry.emitter_anchors
	var emitter: Dictionary = emitters[shot_index % emitters.size()]
	var emitter_id := String(emitter.emitter_id)
	var uid_result := make_bullet_uid(String(row.event_id), String(row.spawn_id), emitter_id, burst_index, shot_index)
	if not bool(uid_result.ok):
		return {}
	var collision_tick := spawn_tick
	if String(row.source.pattern.primitive) == "delayed_seed":
		collision_tick += int(geometry.activation_delay_ticks)
	var record := {
		"stage_run_uid": _stage_run_uid,
		"difficulty": _difficulty,
		"event_id": String(row.event_id),
		"bullet_source_spawn_id": String(row.spawn_id),
		"bullet_source_enemy_id": String(row.enemy_id),
		"source_primitive": String(row.source.pattern.primitive),
		"source_routing_id": String(row.source.pattern.routing),
		"topology_id": String(profile.topology_id),
		"topology_fingerprint": String(profile.topology_fingerprint),
		"emitter_id": emitter_id,
		"burst_index": burst_index,
		"shot_index": shot_index,
		"bullet_uid": String(uid_result.bullet_uid),
		"bullet_spawn_tick": spawn_tick,
		"collision_enable_tick": collision_tick,
		"lifetime_end_tick": spawn_tick + int(profile.lifetime_ticks),
		"reflection_count": 0,
		"first_reflection_tick": null,
		"last_reflection_surface_id": null,
		"graze_tick": null,
		"speed_px_per_second": float(row.source.pattern.speed),
		"stage2_bullet_uid": String(uid_result.bullet_uid),
		"stage2_source_event_id": String(row.event_id),
		"stage2_source_spawn_id": String(row.spawn_id),
		"stage2_source_enemy_id": String(row.enemy_id),
		"stage2_primitive": String(row.source.pattern.primitive),
		"stage2_routing": String(row.source.pattern.routing),
		"stage2_reflection_count": 0,
		"stage2_bullet_spawn_tick": spawn_tick,
		"stage2_first_reflection_tick": null,
		"stage2_last_reflection_surface_id": null,
		"stage2_collision_enable_tick": collision_tick,
		"stage2_lifetime_end_tick": spawn_tick + int(profile.lifetime_ticks),
		"position": [],
		"velocity_px_per_second": [0.0, 0.0],
		"activation_velocity_px_per_second": [0.0, 0.0],
		"motion_kind": "",
		"route_id": "",
		"route_points": [],
		"reflection_plan": [],
		"next_reflection_index": 0,
		"removal_tick": spawn_tick + int(profile.lifetime_ticks),
		"edge_id": "",
		"lane_id": "",
		"seed_id": "",
		"state_binding": _state_binding_for(row, burst_index, state_override),
	}
	match String(row.source.pattern.primitive):
		"rebound_bead":
			if not _populate_rebound_record(record, row, profile, shot_index, state_override):
				return {}
		"grid_edge":
			if not _populate_grid_record(record, row, profile, shot_index):
				return {}
		"lane_fan":
			if not _populate_lane_record(record, row, profile, burst_index, shot_index, state_override):
				return {}
		"delayed_seed":
			if not _populate_delayed_record(record, row, profile, shot_index):
				return {}
		_:
			return {}
	return record

func _populate_rebound_record(record: Dictionary, row: Dictionary, profile: Dictionary, shot_index: int, state_override: Dictionary = {}) -> bool:
	var eligible_by_id := {}
	var authored_eligible: Array = []
	for route_value in profile.geometry.ordered_routes:
		var candidate_route: Dictionary = route_value
		if _route_is_eligible(candidate_route, state_override):
			authored_eligible.append(candidate_route)
			eligible_by_id[String(candidate_route.route_id)] = candidate_route
	var routes: Array = []
	var selected_ids := {}
	for activation_value in profile.geometry.activation_order:
		var activation_id := String(activation_value)
		if eligible_by_id.has(activation_id):
			routes.append(eligible_by_id[activation_id])
			selected_ids[activation_id] = true
	for route_value in authored_eligible:
		var eligible_route: Dictionary = route_value
		if not selected_ids.has(String(eligible_route.route_id)):
			routes.append(eligible_route)
	if String(row.spawn_id) == "s2_b16_abacus_keeper" and _difficulty == "normal":
		var state := _hard_state if state_override.is_empty() else state_override
		var survivor_route_id := "abacus_via_right" if int(state.mirror_activation_mask) == 5 else "abacus_via_left"
		for route_index in range(routes.size()):
			if String((routes[route_index] as Dictionary).route_id) == survivor_route_id:
				var survivor_route: Dictionary = routes[route_index]
				routes.remove_at(route_index)
				routes.push_front(survivor_route)
				break
	if routes.is_empty():
		return false
	var selected_route: Dictionary = routes[shot_index % routes.size()]
	var points: Array = selected_route.points.duplicate(true)
	var speed := float(row.source.pattern.speed)
	var first_velocity := _velocity_between(points[0], points[1], speed)
	var reflection_plan: Array = []
	var cumulative_ticks := 0
	var reflection_ids: Array = selected_route.reflection_surface_ids
	for segment_index in range(1, points.size()):
		cumulative_ticks += _segment_ticks(points[segment_index - 1], points[segment_index], speed)
		if segment_index < points.size() - 1:
			reflection_plan.append({
				"tick": int(record.bullet_spawn_tick) + cumulative_ticks,
				"surface_id": String(reflection_ids[segment_index - 1]),
				"waypoint": (points[segment_index] as Array).duplicate(),
				"velocity_after_px_per_second": _velocity_between(points[segment_index], points[segment_index + 1], speed),
			})
	record.position = (points[0] as Array).duplicate()
	record.velocity_px_per_second = first_velocity
	record.activation_velocity_px_per_second = first_velocity.duplicate()
	record.motion_kind = "authored_piecewise_turns_non_specular"
	record.route_id = String(selected_route.route_id)
	record.route_points = points
	record.reflection_plan = reflection_plan
	record.removal_tick = mini(int(record.lifetime_end_tick), int(record.bullet_spawn_tick) + cumulative_ticks)
	return true

func _populate_grid_record(record: Dictionary, row: Dictionary, profile: Dictionary, shot_index: int) -> bool:
	var authored_segments: Array = profile.geometry.edge_segments
	var segment_by_id := {}
	for segment_value in authored_segments:
		var indexed_segment: Dictionary = segment_value
		segment_by_id[String(indexed_segment.edge_id)] = indexed_segment
	var segments: Array = []
	var selected_ids := {}
	for activation_value in profile.geometry.activation_order:
		var activation_id := String(activation_value)
		if segment_by_id.has(activation_id):
			segments.append(segment_by_id[activation_id])
			selected_ids[activation_id] = true
	for segment_value in authored_segments:
		var remaining_segment: Dictionary = segment_value
		if not selected_ids.has(String(remaining_segment.edge_id)):
			segments.append(remaining_segment)
	if segments.is_empty():
		return false
	var segment_count := segments.size()
	var segment: Dictionary = segments[shot_index % segment_count]
	var group_index := shot_index / segment_count
	var group_count := ceili(float(row.source.pattern.shots_per_burst) / float(segment_count))
	var fraction := float(group_index + 1) / float(group_count + 1)
	var position := _point_lerp(segment.get("from"), segment.get("to"), fraction)
	var velocity := _velocity_from_angle(float(segment.travel_angle_deg), float(row.source.pattern.speed))
	record.position = position
	record.velocity_px_per_second = velocity
	record.activation_velocity_px_per_second = velocity.duplicate()
	record.motion_kind = "authored_grid_edge_linear"
	record.edge_id = String(segment.edge_id)
	record.route_id = String(segment.edge_id)
	record.route_points = [position]
	record.removal_tick = mini(int(record.lifetime_end_tick), _linear_exit_tick(position, velocity, int(record.bullet_spawn_tick)))
	return true

func _populate_lane_record(record: Dictionary, row: Dictionary, profile: Dictionary, burst_index: int, shot_index: int, state_override: Dictionary = {}) -> bool:
	var geometry: Dictionary = profile.geometry
	var lanes: Array = _lane_sequence_for(row, geometry, state_override)
	if lanes.is_empty():
		return false
	var lane_id := String(lanes[burst_index % lanes.size()])
	if not LANE_CENTERS.has(lane_id):
		return false
	var emitter: Array = geometry.emitter_anchors[shot_index % geometry.emitter_anchors.size()].position
	var target := [float(LANE_CENTERS[lane_id]), COMBAT_BOUNDS[3]]
	var base_angle := rad_to_deg(atan2(float(target[1]) - float(emitter[1]), float(target[0]) - float(emitter[0])))
	var angle := base_angle + float(geometry.fan_offsets_deg[shot_index])
	var velocity := _velocity_from_angle(angle, float(row.source.pattern.speed))
	record.position = emitter.duplicate()
	record.velocity_px_per_second = velocity
	record.activation_velocity_px_per_second = velocity.duplicate()
	record.motion_kind = "authored_lane_fan"
	record.lane_id = lane_id
	record.route_id = lane_id
	record.route_points = [emitter.duplicate(), target]
	record.removal_tick = mini(int(record.lifetime_end_tick), _linear_exit_tick(emitter, velocity, int(record.bullet_spawn_tick)))
	return true

func _populate_delayed_record(record: Dictionary, row: Dictionary, profile: Dictionary, shot_index: int) -> bool:
	var geometry: Dictionary = profile.geometry
	var seed_order: Array = geometry.seed_activation_order
	var seed_id := String(seed_order[shot_index % seed_order.size()])
	var seed_position: Array = []
	for seed_value in geometry.seed_positions:
		var seed: Dictionary = seed_value
		if String(seed.seed_id) == seed_id:
			seed_position = seed.position.duplicate()
			break
	if seed_position.is_empty():
		return false
	var routes: Array = geometry.ordered_routes
	var route: Dictionary = routes[shot_index % routes.size()]
	var points: Array = route.points.duplicate(true)
	points[0] = seed_position.duplicate()
	var speed := float(row.source.pattern.speed)
	var launch_velocity := _velocity_between(points[0], points[1], speed)
	var travel_ticks := 0
	for point_index in range(1, points.size()):
		travel_ticks += _segment_ticks(points[point_index - 1], points[point_index], speed)
	record.position = seed_position
	record.velocity_px_per_second = [0.0, 0.0]
	record.activation_velocity_px_per_second = launch_velocity
	record.motion_kind = "authored_delayed_seed"
	record.seed_id = seed_id
	record.route_id = String(route.route_id)
	record.route_points = points
	record.removal_tick = mini(int(record.lifetime_end_tick), int(record.collision_enable_tick) + travel_ticks)
	return true

func _process_bullet_lifecycle(stage_tick: int, event_sequence: int, output: Dictionary) -> void:
	var uids: Array = _active_bullets.keys()
	uids.sort()
	var remove_uids: Array[String] = []
	for uid_value in uids:
		var uid := String(uid_value)
		var bullet: Dictionary = _active_bullets[uid]
		if stage_tick == int(bullet.collision_enable_tick) and String(bullet.source_primitive) == "delayed_seed":
			bullet.velocity_px_per_second = (bullet.activation_velocity_px_per_second as Array).duplicate()
			output.bullet_updates.append(_bullet_update_record(bullet, stage_tick, event_sequence, "seed_activation"))
			_increment_count("bullet_updates", 1)
		var next_reflection := int(bullet.next_reflection_index)
		var plan: Array = bullet.reflection_plan
		while next_reflection < plan.size() and int((plan[next_reflection] as Dictionary).tick) == stage_tick:
			var turn: Dictionary = plan[next_reflection]
			bullet.reflection_count = int(bullet.reflection_count) + 1
			bullet.stage2_reflection_count = int(bullet.reflection_count)
			if bullet.first_reflection_tick == null:
				bullet.first_reflection_tick = stage_tick
				bullet.stage2_first_reflection_tick = stage_tick
			bullet.last_reflection_surface_id = String(turn.surface_id)
			bullet.stage2_last_reflection_surface_id = String(turn.surface_id)
			bullet.position = (turn.waypoint as Array).duplicate()
			bullet.velocity_px_per_second = (turn.velocity_after_px_per_second as Array).duplicate()
			next_reflection += 1
			bullet.next_reflection_index = next_reflection
			output.bullet_updates.append(_bullet_update_record(bullet, stage_tick, event_sequence, "rebound_turn"))
			_increment_count("bullet_updates", 1)
		_active_bullets[uid] = bullet
		if stage_tick >= int(bullet.removal_tick):
			output.bullet_removals.append({
				"stage_tick": stage_tick,
				"event_sequence": event_sequence,
				"bullet_uid": uid,
				"reason": "authored_terminus" if int(bullet.removal_tick) < int(bullet.lifetime_end_tick) else "lifetime_end",
			})
			remove_uids.append(uid)
	for uid in remove_uids:
		_active_bullets.erase(uid)
	_increment_count("bullet_removals", remove_uids.size())

func _bullet_update_record(bullet: Dictionary, stage_tick: int, event_sequence: int, update_kind: String) -> Dictionary:
	var result := {
		"stage_tick": stage_tick,
		"event_sequence": event_sequence,
		"update_kind": update_kind,
		"position": (bullet.position as Array).duplicate(),
		"velocity_px_per_second": (bullet.velocity_px_per_second as Array).duplicate(),
	}
	for key in BULLET_SEAM_KEYS:
		result[key] = bullet[key]
	return result

func _remove_source_internal(spawn_id: String, stage_tick: int, event_sequence: int, reason: String, output: Dictionary, defeat: bool) -> void:
	if not _source_states.has(spawn_id):
		_runtime_fail("unknown_source", "source.%s" % spawn_id, "source is outside the frozen 22-row coverage", output)
		return
	var state: Dictionary = _source_states[spawn_id]
	if not bool(state.alive):
		_note_duplicate(output, "source_removal", spawn_id)
		return
	state.alive = false
	state.removed_tick = stage_tick
	_source_states[spawn_id] = state
	if spawn_id == String(_hard_state.surviving_mirror_spawn_id):
		var previous_mask := int(_hard_state.mirror_activation_mask)
		_recompute_mirror_activation_mask()
		if int(_hard_state.mirror_activation_mask) != previous_mask:
			_append_transition(output, stage_tick, event_sequence, "surviving_mirror_removal_clears_alive_bit", "mirror_activation_mask_%d" % previous_mask, "mirror_activation_mask_%d" % int(_hard_state.mirror_activation_mask))
	output.source_removals.append({
		"stage_tick": stage_tick,
		"event_sequence": event_sequence,
		"spawn_id": spawn_id,
		"reason": reason,
		"defeat": defeat,
	})
	_increment_count("source_removals", 1)

func _apply_defeat_transition(spawn_id: String, stage_tick: int, event_sequence: int, output: Dictionary) -> void:
	if spawn_id == "s2_b13_red_booth_master" and _difficulty == "hard" and String(_hard_state.blue_emission_state_id) == "pre_red":
		_hard_state.stage_front_revision_id = "stage_front_after_red_neighbor_flip"
		_hard_state.blue_emission_state_id = "post_red"
		_append_transition(output, stage_tick, event_sequence, "red_defeat_commits_blue_post_red", "pre_red", "post_red")
	elif spawn_id == "s2_b13_blue_booth_master" and _difficulty == "hard" and String(_hard_state.blue_emission_state_id) == "post_red":
		_hard_state.stage_front_revision_id = "stage_front_after_blue_neighbor_flip"
		_append_transition(output, stage_tick, event_sequence, "blue_defeat_commits_stage_front_revision", "stage_front_after_red_neighbor_flip", "stage_front_after_blue_neighbor_flip")
	if spawn_id in ["s2_b15_left_mirror", "s2_b15_right_mirror"] and String(_hard_state.selected_mirror_spawn_id).is_empty():
		var surviving := "s2_b15_right_mirror" if spawn_id == "s2_b15_left_mirror" else "s2_b15_left_mirror"
		var mapped_state := "mapped_after_left_mirror" if spawn_id == "s2_b15_left_mirror" else "mapped_after_right_mirror"
		var revision := "stage_front_after_left_horizontal_transform" if spawn_id == "s2_b15_left_mirror" else "stage_front_after_right_diagonal_transform"
		_hard_state.selected_mirror_spawn_id = spawn_id
		_hard_state.surviving_mirror_spawn_id = surviving
		_recompute_mirror_activation_mask()
		if _difficulty == "hard":
			_hard_state.yellow_emission_state_id = mapped_state
			_hard_state.stage_front_revision_id = revision
		_append_transition(output, stage_tick, event_sequence, "selected_mirror_commits_yellow_mapping", "pre_mirror", mapped_state)

func _append_transition(output: Dictionary, stage_tick: int, event_sequence: int, transition_id: String, from_state: String, to_state: String) -> void:
	output.state_transitions.append({
		"stage_tick": stage_tick,
		"event_sequence": event_sequence,
		"transition_id": transition_id,
		"from_state_id": from_state,
		"to_state_id": to_state,
		"hard_state": _hard_state.duplicate(true),
	})
	_increment_count("state_transitions", 1)

func _route_is_eligible(route: Dictionary, state_override: Dictionary = {}) -> bool:
	var state := _hard_state if state_override.is_empty() else state_override
	if route.has("state_id") and String(route.state_id) != String(state.blue_emission_state_id):
		return false
	if route.has("condition"):
		var condition := String(route.condition)
		var mask := int(state.mirror_activation_mask)
		if condition == "mirror_activation_mask == 5":
			return mask == 5
		if condition == "mirror_activation_mask == 6":
			return mask == 6
		return false
	return true

func _mirror_base_mask(selected_spawn_id: String) -> int:
	if selected_spawn_id == "s2_b15_left_mirror":
		return 1
	if selected_spawn_id == "s2_b15_right_mirror":
		return 2
	return 0

func _opposite_mirror_spawn_id(selected_spawn_id: String) -> String:
	if selected_spawn_id == "s2_b15_left_mirror":
		return "s2_b15_right_mirror"
	if selected_spawn_id == "s2_b15_right_mirror":
		return "s2_b15_left_mirror"
	return ""

func _recompute_mirror_activation_mask() -> void:
	var selected := String(_hard_state.selected_mirror_spawn_id)
	var surviving := String(_hard_state.surviving_mirror_spawn_id)
	var mask := _mirror_base_mask(selected)
	if mask > 0 and _source_states.has(surviving) and bool((_source_states[surviving] as Dictionary).alive):
		mask = mask | 4
	_hard_state.mirror_activation_mask = mask

func _s2_b16_entry_is_valid(explicit_active_ids: Dictionary) -> bool:
	if not _activated_events.has("s2_b15"):
		return false
	var selected := String(_hard_state.selected_mirror_spawn_id)
	var surviving := String(_hard_state.surviving_mirror_spawn_id)
	if _mirror_base_mask(selected) == 0 or surviving.is_empty() or selected == surviving:
		return false
	if not _defeated_sources.has(selected) or not _source_states.has(selected) or bool((_source_states[selected] as Dictionary).alive):
		return false
	if _defeated_sources.has(surviving) or not _source_states.has(surviving) or not bool((_source_states[surviving] as Dictionary).alive):
		return false
	if explicit_active_ids.size() != 1 or not explicit_active_ids.has(surviving) or explicit_active_ids.has(selected):
		return false
	return int(_hard_state.mirror_activation_mask) == (_mirror_base_mask(selected) | 4)

func _s2_b16_recovery_is_live() -> bool:
	var selected := String(_hard_state.selected_mirror_spawn_id)
	var surviving := String(_hard_state.surviving_mirror_spawn_id)
	if _mirror_base_mask(selected) == 0 or not _source_states.has(surviving):
		return false
	return bool((_source_states[surviving] as Dictionary).alive) and int(_hard_state.mirror_activation_mask) == (_mirror_base_mask(selected) | 4)

func _lane_sequence_for(row: Dictionary, geometry: Dictionary, state_override: Dictionary = {}) -> Array:
	var state := _hard_state if state_override.is_empty() else state_override
	if geometry.get("lane_sequence_by_state") is Dictionary:
		var state_id := String(state.yellow_emission_state_id)
		var by_state: Dictionary = geometry.lane_sequence_by_state
		if by_state.has(state_id):
			return (by_state[state_id] as Array).duplicate()
	return (geometry.lane_sequence as Array).duplicate()

func _state_binding_for(row: Dictionary, burst_index: int, state_override: Dictionary = {}) -> Dictionary:
	var state := _hard_state if state_override.is_empty() else state_override
	var binding := {
		"stage_front_revision_id": String(state.stage_front_revision_id),
		"blue_emission_state_id": String(state.blue_emission_state_id),
		"yellow_emission_state_id": String(state.yellow_emission_state_id),
		"selected_mirror_spawn_id": String(state.selected_mirror_spawn_id),
		"mirror_activation_mask": int(state.mirror_activation_mask),
	}
	if String(row.source.pattern.primitive) == "lane_fan":
		var lanes := _lane_sequence_for(row, row.profiles[_difficulty].geometry, state)
		if not lanes.is_empty():
			binding["selected_lane_id"] = String(lanes[burst_index % lanes.size()])
	return binding

func _clear_active_bullets(stage_tick: int, event_sequence: int, reason: String, output: Dictionary) -> void:
	var uids: Array = _active_bullets.keys()
	uids.sort()
	for uid in uids:
		output.bullet_removals.append({
			"stage_tick": stage_tick,
			"event_sequence": event_sequence,
			"bullet_uid": String(uid),
			"reason": reason,
		})
	_active_bullets.clear()
	_increment_count("bullet_removals", uids.size())

func _runtime_fail(code: String, path: String, message: String, output: Dictionary) -> bool:
	_set_hard_error(code, path, message)
	_clear_active_bullets(int(output.stage_tick), int(output.event_sequence), "runtime_fault", output)
	for spawn_id in _source_states.keys():
		var state: Dictionary = _source_states[spawn_id]
		state.alive = false
		_source_states[spawn_id] = state
	output.ok = false
	output.error = last_error()
	return false

func _set_hard_error(code: String, path: String, message: String) -> void:
	_hard_error_code = code
	_hard_error_path = path
	_hard_error_message = message

func _empty_output(stage_tick: int, event_sequence: int) -> Dictionary:
	var output := {
		"ok": true,
		"error": "",
		"stage_tick": stage_tick,
		"event_sequence": event_sequence,
		"duplicate": false,
	}
	for key in OUTPUT_ARRAY_KEYS:
		output[key] = []
	return output

func _finalize_output(output: Dictionary) -> Dictionary:
	if has_hard_error():
		output.ok = false
		output.error = last_error()
	output["telemetry_snapshot"] = telemetry_snapshot()
	_update_in_progress = false
	return output

func _note_duplicate(output: Dictionary, kind: String, identity: String) -> void:
	output["duplicate"] = true
	output.telemetry.append({"kind": "duplicate", "callback_kind": kind, "identity": identity})
	_increment_count("duplicates", 1)

func _increment_count(key: String, amount: int) -> void:
	_telemetry_counts[key] = int(_telemetry_counts.get(key, 0)) + amount

func _validate_snapshot_sources(states: Dictionary) -> bool:
	var keys: Array = states.keys()
	keys.sort()
	var expected: Array = EXPECTED_SPAWN_IDS.duplicate()
	expected.sort()
	if keys != expected:
		return false
	for spawn_id in EXPECTED_SPAWN_IDS:
		if not (states[spawn_id] is Dictionary) or not _has_exact_keys(states[spawn_id], SOURCE_STATE_KEYS):
			return false
		var state: Dictionary = states[spawn_id]
		if typeof(state.activated) != TYPE_BOOL or typeof(state.alive) != TYPE_BOOL:
			return false
		for key in ["activated_tick", "removed_tick", "next_warning_index", "next_burst_index"]:
			if typeof(state[key]) != TYPE_INT:
				return false
		if bool(state.alive) and not bool(state.activated):
			return false
		if int(state.next_warning_index) < 0 or int(state.next_burst_index) < 0:
			return false
	return true

func _validate_snapshot_string_set(values: Array) -> bool:
	var seen := {}
	var previous := ""
	for index in range(values.size()):
		if typeof(values[index]) != TYPE_STRING:
			return false
		var value := String(values[index])
		if value.is_empty() or seen.has(value) or (index > 0 and value < previous):
			return false
		seen[value] = true
		previous = value
	return true

func _validate_snapshot_cross_fields(payload: Dictionary) -> bool:
	var activated_lookup := {}
	for event_id_value in payload.activated_events:
		activated_lookup[String(event_id_value)] = true
	var defeated_lookup := {}
	for spawn_id_value in payload.defeated_sources:
		defeated_lookup[String(spawn_id_value)] = true
	if not _validate_snapshot_callback_cursor(payload):
		return false
	if not _validate_snapshot_current_event(payload, activated_lookup):
		return false
	if not _validate_snapshot_source_reachability(payload, activated_lookup, defeated_lookup):
		return false
	if not _validate_snapshot_hard_state(payload, activated_lookup, defeated_lookup):
		return false
	if not _validate_snapshot_used_uid_coverage(payload):
		return false
	return _validate_snapshot_telemetry(payload)

func _validate_snapshot_callback_cursor(payload: Dictionary) -> bool:
	var schedule_cursor := int(payload.schedule_cursor_tick)
	var last_tick := int(payload.last_stage_tick)
	if schedule_cursor > last_tick:
		return false
	if payload.processed_callbacks.is_empty():
		return schedule_cursor == -1 and last_tick == -1 and int(payload.last_event_sequence) == -1
	if last_tick < 0 or int(payload.last_event_sequence) < 0 or schedule_cursor < last_tick - 1:
		return false
	var maximum_tick := -1
	var maximum_sequence := -1
	var callback_keys := {}
	for callback_id_value in payload.processed_callbacks:
		var parts := String(callback_id_value).split(":", false)
		if parts.size() != 4 or parts[0] not in CALLBACK_KINDS or not parts[1].is_valid_int() or not parts[2].is_valid_int() or not _valid_hex_digest(parts[3]):
			return false
		var tick := int(parts[1])
		var sequence := int(parts[2])
		if tick < 0 or tick > MAX_STAGE_TICK or sequence < 0:
			return false
		var callback_key := "%d:%d" % [tick, sequence]
		if callback_keys.has(callback_key):
			return false
		callback_keys[callback_key] = true
		if tick > maximum_tick or (tick == maximum_tick and sequence > maximum_sequence):
			maximum_tick = tick
			maximum_sequence = sequence
	if maximum_tick != last_tick or maximum_sequence != int(payload.last_event_sequence):
		return false
	for event_id_value in payload.activated_events:
		var event_id := String(event_id_value)
		if not _snapshot_has_callback(payload.processed_callbacks, "activate_event", int(EVENT_TICKS[event_id])):
			return false
	for spawn_id_value in payload.defeated_sources:
		var spawn_id := String(spawn_id_value)
		var removed_tick := int((payload.source_states[spawn_id] as Dictionary).removed_tick)
		if not _snapshot_has_callback_payload(payload.processed_callbacks, "accept_defeat", removed_tick, {"spawn_id": spawn_id}):
			return false
	for spawn_id in EXPECTED_SPAWN_IDS:
		var source_state: Dictionary = payload.source_states[spawn_id]
		if bool(source_state.activated) and not bool(source_state.alive) and spawn_id not in payload.defeated_sources:
			if not _snapshot_has_callback(payload.processed_callbacks, "remove_source", int(source_state.removed_tick)):
				return false
	return true

func _snapshot_has_callback(callback_ids: Array, kind: String, stage_tick: int) -> bool:
	for callback_id_value in callback_ids:
		var parts := String(callback_id_value).split(":", false)
		if parts.size() == 4 and parts[0] == kind and int(parts[1]) == stage_tick:
			return true
	return false

func _snapshot_has_callback_payload(callback_ids: Array, kind: String, stage_tick: int, callback_payload: Dictionary) -> bool:
	return not _snapshot_callback_key(callback_ids, kind, stage_tick, callback_payload).is_empty()

func _snapshot_callback_key(callback_ids: Array, kind: String, stage_tick: int, callback_payload: Dictionary) -> Array:
	var expected_digest := _stable_digest(callback_payload)
	for callback_id_value in callback_ids:
		var parts := String(callback_id_value).split(":", false)
		if parts.size() == 4 and parts[0] == kind and int(parts[1]) == stage_tick and parts[3] == expected_digest:
			return [stage_tick, int(parts[2])]
	return []

func _callback_key_precedes(left: Array, right: Array) -> bool:
	return int(left[0]) < int(right[0]) or (int(left[0]) == int(right[0]) and int(left[1]) < int(right[1]))

func _snapshot_callback_sequences(callback_ids: Array, kind: String, stage_tick: int) -> Array:
	var result: Array = []
	for callback_id_value in callback_ids:
		var parts := String(callback_id_value).split(":", false)
		if parts.size() == 4 and parts[0] == kind and int(parts[1]) == stage_tick:
			result.append(int(parts[2]))
	result.sort()
	return result

func _validate_snapshot_current_event(payload: Dictionary, activated_lookup: Dictionary) -> bool:
	var expected_current := ""
	var greatest_tick := -1
	for event_id_value in payload.activated_events:
		var event_id := String(event_id_value)
		var event_tick := int(EVENT_TICKS[event_id])
		if event_tick > int(payload.last_stage_tick):
			return false
		if event_tick > greatest_tick:
			greatest_tick = event_tick
			expected_current = event_id
	if String(payload.current_event_id) != expected_current:
		return false
	return expected_current.is_empty() or activated_lookup.has(expected_current)

func _validate_snapshot_source_reachability(payload: Dictionary, activated_lookup: Dictionary, defeated_lookup: Dictionary) -> bool:
	var states: Dictionary = payload.source_states
	for spawn_id in EXPECTED_SPAWN_IDS:
		var row: Dictionary = _row_by_spawn[spawn_id]
		var state: Dictionary = states[spawn_id]
		var event_was_activated := activated_lookup.has(String(row.event_id))
		if bool(state.activated) != event_was_activated:
			return false
		if not event_was_activated:
			if bool(state.alive) or int(state.activated_tick) != -1 or int(state.removed_tick) != -1 or int(state.next_warning_index) != 0 or int(state.next_burst_index) != 0:
				return false
			continue
		if int(state.activated_tick) != int(EVENT_TICKS[String(row.event_id)]):
			return false
		if bool(state.alive):
			if int(state.removed_tick) != -1 or defeated_lookup.has(spawn_id):
				return false
		else:
			if int(state.removed_tick) < int(state.activated_tick) or int(state.removed_tick) > int(payload.last_stage_tick):
				return false
		if _execution_owner(row) == "phase_runtime":
			if int(state.next_warning_index) != 0 or int(state.next_burst_index) != 0:
				return false
			continue
		var profile: Dictionary = row.profiles[_difficulty]
		var pattern: Dictionary = row.source.pattern
		var first_burst := int(row.source.authored_tick) + int(pattern.start_delay_ticks)
		var first_warning := first_burst - int(profile.warning_lead_ticks)
		var through_tick := int(payload.schedule_cursor_tick)
		var minimum_tick := through_tick
		var maximum_tick := through_tick
		if not bool(state.alive) and int(state.removed_tick) <= through_tick:
			minimum_tick = int(state.removed_tick) - 1
			maximum_tick = int(state.removed_tick)
		var minimum_warnings := _due_schedule_count(first_warning, int(pattern.interval_ticks), minimum_tick)
		var maximum_warnings := _due_schedule_count(first_warning, int(pattern.interval_ticks), maximum_tick)
		var minimum_bursts := _due_schedule_count(first_burst, int(pattern.interval_ticks), minimum_tick)
		var maximum_bursts := _due_schedule_count(first_burst, int(pattern.interval_ticks), maximum_tick)
		var matches_before_removal := int(state.next_warning_index) == minimum_warnings and int(state.next_burst_index) == minimum_bursts
		var matches_after_removal := int(state.next_warning_index) == maximum_warnings and int(state.next_burst_index) == maximum_bursts
		if not matches_before_removal and not matches_after_removal:
			return false
	return true

func _due_schedule_count(first_tick: int, interval_ticks: int, through_tick: int) -> int:
	if through_tick < first_tick:
		return 0
	return floori(float(through_tick - first_tick) / float(interval_ticks)) + 1

func _validate_snapshot_hard_state(payload: Dictionary, activated_lookup: Dictionary, defeated_lookup: Dictionary) -> bool:
	var state: Dictionary = payload.hard_state
	for key in ["stage_front_revision_id", "blue_emission_state_id", "yellow_emission_state_id", "selected_mirror_spawn_id", "surviving_mirror_spawn_id"]:
		if typeof(state[key]) != TYPE_STRING:
			return false
	if typeof(state.mirror_activation_mask) != TYPE_INT:
		return false
	var blue_state := String(state.blue_emission_state_id)
	var yellow_state := String(state.yellow_emission_state_id)
	var revision := String(state.stage_front_revision_id)
	var selected := String(state.selected_mirror_spawn_id)
	var surviving := String(state.surviving_mirror_spawn_id)
	var mask := int(state.mirror_activation_mask)
	if blue_state not in ["pre_red", "post_red"] or yellow_state not in ["pre_mirror", "mapped_after_left_mirror", "mapped_after_right_mirror"]:
		return false
	if mask not in [0, 1, 2, 5, 6]:
		return false
	var red_defeated := defeated_lookup.has("s2_b13_red_booth_master")
	var blue_defeated := defeated_lookup.has("s2_b13_blue_booth_master")
	if _difficulty == "normal":
		if blue_state != "pre_red" or revision != "stage_front_initial":
			return false
	else:
		var expected_blue := "post_red" if red_defeated else "pre_red"
		if blue_state != expected_blue:
			return false
	if selected.is_empty():
		if not surviving.is_empty() or mask != 0 or yellow_state != "pre_mirror":
			return false
		if _difficulty == "hard":
			if blue_state == "pre_red" and revision != "stage_front_initial":
				return false
			if blue_state == "post_red":
				var expected_revisions := ["stage_front_after_red_neighbor_flip"]
				if blue_defeated:
					var red_tick := int((payload.source_states["s2_b13_red_booth_master"] as Dictionary).removed_tick)
					var blue_tick := int((payload.source_states["s2_b13_blue_booth_master"] as Dictionary).removed_tick)
					var red_key := _snapshot_callback_key(payload.processed_callbacks, "accept_defeat", red_tick, {"spawn_id": "s2_b13_red_booth_master"})
					var blue_key := _snapshot_callback_key(payload.processed_callbacks, "accept_defeat", blue_tick, {"spawn_id": "s2_b13_blue_booth_master"})
					if _callback_key_precedes(red_key, blue_key):
						expected_revisions = ["stage_front_after_blue_neighbor_flip"]
				if revision not in expected_revisions:
					return false
	else:
		if not activated_lookup.has("s2_b15") or not defeated_lookup.has(selected):
			return false
		var expected_survivor := _opposite_mirror_spawn_id(selected)
		if expected_survivor.is_empty() or surviving != expected_survivor:
			return false
		if bool((payload.source_states[selected] as Dictionary).alive) or not bool((payload.source_states[selected] as Dictionary).activated):
			return false
		if not bool((payload.source_states[surviving] as Dictionary).activated):
			return false
		if defeated_lookup.has(surviving):
			var selected_tick := int((payload.source_states[selected] as Dictionary).removed_tick)
			var survivor_tick := int((payload.source_states[surviving] as Dictionary).removed_tick)
			var selected_key := _snapshot_callback_key(payload.processed_callbacks, "accept_defeat", selected_tick, {"spawn_id": selected})
			var survivor_key := _snapshot_callback_key(payload.processed_callbacks, "accept_defeat", survivor_tick, {"spawn_id": surviving})
			if _callback_key_precedes(survivor_key, selected_key):
				return false
		var survivor_alive := bool((payload.source_states[surviving] as Dictionary).alive)
		var expected_mask := _mirror_base_mask(selected) | (4 if survivor_alive else 0)
		if mask != expected_mask:
			return false
		if _difficulty == "hard":
			var expected_yellow := "mapped_after_left_mirror" if selected == "s2_b15_left_mirror" else "mapped_after_right_mirror"
			var expected_revision := "stage_front_after_left_horizontal_transform" if selected == "s2_b15_left_mirror" else "stage_front_after_right_diagonal_transform"
			if yellow_state != expected_yellow or revision != expected_revision:
				return false
		elif yellow_state != "pre_mirror":
			return false
	if activated_lookup.has("s2_b16"):
		var b16_state: Dictionary = payload.source_states["s2_b16_abacus_keeper"]
		if selected.is_empty() or not bool(b16_state.activated):
			return false
		var selected_state: Dictionary = payload.source_states[selected]
		var survivor_state: Dictionary = payload.source_states[surviving]
		var entry_tick := int(EVENT_TICKS.s2_b16)
		var entry_activation_key := _snapshot_callback_key(payload.processed_callbacks, "activate_event", entry_tick, {"event_id": "s2_b16", "active_entity_ids": [surviving]})
		if entry_activation_key.is_empty():
			return false
		if int(selected_state.removed_tick) > entry_tick:
			return false
		if int(survivor_state.removed_tick) >= 0 and int(survivor_state.removed_tick) < entry_tick:
			return false
		var minimum_entry_sequence := -1
		if int(selected_state.removed_tick) == entry_tick:
			var selected_entry_key := _snapshot_callback_key(payload.processed_callbacks, "accept_defeat", entry_tick, {"spawn_id": selected})
			minimum_entry_sequence = int(selected_entry_key[1])
		var maximum_entry_sequence := 2147483647
		if int(survivor_state.removed_tick) == entry_tick:
			var survivor_removal_sequences: Array = []
			if defeated_lookup.has(surviving):
				var survivor_entry_key := _snapshot_callback_key(payload.processed_callbacks, "accept_defeat", entry_tick, {"spawn_id": surviving})
				survivor_removal_sequences = [int(survivor_entry_key[1])]
			else:
				survivor_removal_sequences = _snapshot_callback_sequences(payload.processed_callbacks, "remove_source", entry_tick)
			if survivor_removal_sequences.is_empty():
				return false
			maximum_entry_sequence = int(survivor_removal_sequences[survivor_removal_sequences.size() - 1])
		var entry_sequence := int(entry_activation_key[1])
		if entry_sequence <= minimum_entry_sequence or entry_sequence >= maximum_entry_sequence:
			return false
		if int(b16_state.next_burst_index) > 0 and int(survivor_state.removed_tick) >= 0:
			var b16_row: Dictionary = _row_by_spawn["s2_b16_abacus_keeper"]
			var b16_pattern: Dictionary = b16_row.source.pattern
			var last_burst_tick := int(b16_row.source.authored_tick) + int(b16_pattern.start_delay_ticks) + (int(b16_state.next_burst_index) - 1) * int(b16_pattern.interval_ticks)
			if int(survivor_state.removed_tick) < last_burst_tick:
				return false
	return true

func _validate_snapshot_used_uid_coverage(payload: Dictionary) -> bool:
	var used_lookup := {}
	for uid_value in payload.used_uids:
		used_lookup[String(uid_value)] = true
	var expected_count := 0
	for spawn_id in EXPECTED_SPAWN_IDS:
		var row: Dictionary = _row_by_spawn[spawn_id]
		var state: Dictionary = payload.source_states[spawn_id]
		if _execution_owner(row) != "field_topology_contract":
			continue
		var emitters: Array = (row.profiles[_difficulty] as Dictionary).geometry.emitter_anchors
		var shot_count := int(row.source.pattern.shots_per_burst)
		for burst_index in range(int(state.next_burst_index)):
			for shot_index in range(shot_count):
				var emitter: Dictionary = emitters[shot_index % emitters.size()]
				var uid_result := make_bullet_uid(String(row.event_id), spawn_id, String(emitter.emitter_id), burst_index, shot_index)
				if not bool(uid_result.ok) or not used_lookup.has(String(uid_result.bullet_uid)):
					return false
				expected_count += 1
	return expected_count == used_lookup.size()

func _validate_snapshot_telemetry(payload: Dictionary) -> bool:
	var expected_activations := 0
	var expected_removals := 0
	var expected_warnings := 0
	var expected_bursts := 0
	for spawn_id in EXPECTED_SPAWN_IDS:
		var state: Dictionary = payload.source_states[spawn_id]
		if bool(state.activated):
			expected_activations += 1
		if int(state.removed_tick) >= 0:
			expected_removals += 1
		expected_warnings += int(state.next_warning_index)
		expected_bursts += int(state.next_burst_index)
	var counts: Dictionary = payload.telemetry_counts
	if int(counts.source_activations) != expected_activations or int(counts.source_removals) != expected_removals:
		return false
	if int(counts.warnings) != expected_warnings or int(counts.bursts) != expected_bursts:
		return false
	if int(counts.bullets_constructed) != payload.used_uids.size():
		return false
	if int(counts.bullet_removals) != payload.used_uids.size() - payload.active_bullets.size():
		return false
	return int(counts.grazes_projected) == payload.grazed_uids.size()

func _validate_bullet_snapshot(uid: String, bullet: Dictionary, payload: Dictionary) -> bool:
	if not _has_exact_keys(bullet, BULLET_RECORD_KEYS) or not _is_canonical_value(bullet):
		return false
	for key in ["stage_run_uid", "difficulty", "event_id", "bullet_source_spawn_id", "bullet_source_enemy_id", "source_primitive", "source_routing_id", "topology_id", "topology_fingerprint", "emitter_id", "bullet_uid", "motion_kind", "route_id", "edge_id", "lane_id", "seed_id", "stage2_bullet_uid", "stage2_source_event_id", "stage2_source_spawn_id", "stage2_source_enemy_id", "stage2_primitive", "stage2_routing"]:
		if typeof(bullet[key]) != TYPE_STRING:
			return false
	for key in ["burst_index", "shot_index", "bullet_spawn_tick", "collision_enable_tick", "lifetime_end_tick", "reflection_count", "next_reflection_index", "removal_tick", "stage2_reflection_count", "stage2_bullet_spawn_tick", "stage2_collision_enable_tick", "stage2_lifetime_end_tick"]:
		if typeof(bullet[key]) != TYPE_INT:
			return false
	for key in ["first_reflection_tick", "stage2_first_reflection_tick", "graze_tick"]:
		if bullet[key] != null and typeof(bullet[key]) != TYPE_INT:
			return false
	for key in ["last_reflection_surface_id", "stage2_last_reflection_surface_id"]:
		if bullet[key] != null and typeof(bullet[key]) != TYPE_STRING:
			return false
	if typeof(bullet.speed_px_per_second) != TYPE_FLOAT or not (bullet.state_binding is Dictionary):
		return false
	for key in ["position", "velocity_px_per_second", "activation_velocity_px_per_second", "route_points", "reflection_plan"]:
		if not (bullet[key] is Array):
			return false
	var spawn_id := String(bullet.bullet_source_spawn_id)
	if not _row_by_spawn.has(spawn_id):
		return false
	var row: Dictionary = _row_by_spawn[spawn_id]
	var profile: Dictionary = row.profiles[_difficulty]
	var source_state: Dictionary = payload.source_states[spawn_id]
	if not bool(source_state.activated) or int(bullet.burst_index) < 0 or int(bullet.burst_index) >= int(source_state.next_burst_index):
		return false
	if int(bullet.shot_index) < 0 or int(bullet.shot_index) >= int(row.source.pattern.shots_per_burst):
		return false
	var expected_spawn_tick := int(row.source.authored_tick) + int(row.source.pattern.start_delay_ticks) + int(bullet.burst_index) * int(row.source.pattern.interval_ticks)
	if expected_spawn_tick > int(payload.schedule_cursor_tick):
		return false
	if expected_spawn_tick < int(source_state.activated_tick) or (int(source_state.removed_tick) >= 0 and expected_spawn_tick > int(source_state.removed_tick)):
		return false
	var binding_state := _state_from_snapshot_binding(bullet.state_binding)
	if binding_state.is_empty() or not _historical_binding_reachable(bullet.state_binding, payload, spawn_id, expected_spawn_tick):
		return false
	var expected := _construct_bullet(row, profile, int(bullet.burst_index), int(bullet.shot_index), expected_spawn_tick, binding_state)
	if expected.is_empty():
		return false
	for key in BULLET_RECONSTRUCTED_KEYS:
		if bullet[key] != expected[key]:
			return false
	var uid_parts := uid.split(":", false)
	if uid_parts.size() != 6 or uid_parts[0] != _stage_run_uid or uid_parts[1] != String(row.event_id) or uid_parts[2] != spawn_id or uid_parts[3] != String(bullet.emitter_id) or int(uid_parts[4]) != int(bullet.burst_index) or int(uid_parts[5]) != int(bullet.shot_index):
		return false
	if bullet.stage2_bullet_uid != uid or bullet.stage2_source_event_id != String(row.event_id) or bullet.stage2_source_spawn_id != spawn_id or bullet.stage2_source_enemy_id != String(row.enemy_id):
		return false
	if bullet.stage2_primitive != String(row.source.pattern.primitive) or bullet.stage2_routing != String(row.source.pattern.routing):
		return false
	if bullet.stage2_bullet_spawn_tick != bullet.bullet_spawn_tick or bullet.stage2_collision_enable_tick != bullet.collision_enable_tick or bullet.stage2_lifetime_end_tick != bullet.lifetime_end_tick:
		return false
	if int(bullet.removal_tick) <= int(payload.schedule_cursor_tick):
		return false
	var expected_reflections := 0
	for turn_value in bullet.reflection_plan:
		if int((turn_value as Dictionary).tick) <= int(payload.schedule_cursor_tick):
			expected_reflections += 1
	if bullet.reflection_count != expected_reflections or bullet.next_reflection_index != expected_reflections or bullet.stage2_reflection_count != expected_reflections:
		return false
	var expected_position: Array = expected.position.duplicate()
	var expected_velocity: Array = expected.velocity_px_per_second.duplicate()
	var expected_first: Variant = null
	var expected_last: Variant = null
	if expected_reflections > 0:
		var last_turn: Dictionary = bullet.reflection_plan[expected_reflections - 1]
		expected_position = (last_turn.waypoint as Array).duplicate()
		expected_velocity = (last_turn.velocity_after_px_per_second as Array).duplicate()
		expected_first = int((bullet.reflection_plan[0] as Dictionary).tick)
		expected_last = String(last_turn.surface_id)
	elif String(bullet.source_primitive) == "delayed_seed" and int(payload.schedule_cursor_tick) >= int(bullet.collision_enable_tick):
		expected_velocity = (bullet.activation_velocity_px_per_second as Array).duplicate()
	if bullet.position != expected_position or bullet.velocity_px_per_second != expected_velocity:
		return false
	if bullet.first_reflection_tick != expected_first or bullet.stage2_first_reflection_tick != expected_first or bullet.last_reflection_surface_id != expected_last or bullet.stage2_last_reflection_surface_id != expected_last:
		return false
	var was_grazed: bool = uid in payload.grazed_uids
	if was_grazed:
		if typeof(bullet.graze_tick) != TYPE_INT or expected_reflections < 1 or int(bullet.graze_tick) < int(expected_first) or int(bullet.graze_tick) > int(payload.last_stage_tick):
			return false
		if String(row.source.pattern.primitive) != "rebound_bead" or "rebound_graze_uid" not in (row.source.score_route_hooks as Array):
			return false
		if not _snapshot_has_callback_payload(payload.processed_callbacks, "observe_graze", int(bullet.graze_tick), {"bullet_uid": uid}):
			return false
	elif bullet.graze_tick != null:
		return false
	return true

func _state_from_snapshot_binding(binding: Dictionary) -> Dictionary:
	var expected_keys: Array = STATE_BINDING_KEYS.duplicate()
	if binding.has("selected_lane_id"):
		expected_keys.append("selected_lane_id")
	if not _has_exact_keys(binding, expected_keys):
		return {}
	for key in ["stage_front_revision_id", "blue_emission_state_id", "yellow_emission_state_id", "selected_mirror_spawn_id"]:
		if typeof(binding[key]) != TYPE_STRING:
			return {}
	if typeof(binding.mirror_activation_mask) != TYPE_INT:
		return {}
	if binding.has("selected_lane_id") and (typeof(binding.selected_lane_id) != TYPE_STRING or not LANE_CENTERS.has(String(binding.selected_lane_id))):
		return {}
	var selected := String(binding.selected_mirror_spawn_id)
	var mask := int(binding.mirror_activation_mask)
	if selected.is_empty() and mask != 0:
		return {}
	if not selected.is_empty() and (selected not in ["s2_b15_left_mirror", "s2_b15_right_mirror"] or mask not in [_mirror_base_mask(selected), _mirror_base_mask(selected) | 4]):
		return {}
	if _difficulty == "normal":
		if String(binding.blue_emission_state_id) != "pre_red" or String(binding.yellow_emission_state_id) != "pre_mirror" or String(binding.stage_front_revision_id) != "stage_front_initial":
			return {}
	else:
		if String(binding.blue_emission_state_id) not in ["pre_red", "post_red"]:
			return {}
		if selected.is_empty():
			if String(binding.yellow_emission_state_id) != "pre_mirror":
				return {}
			if String(binding.stage_front_revision_id) not in (["stage_front_initial"] if String(binding.blue_emission_state_id) == "pre_red" else ["stage_front_after_red_neighbor_flip", "stage_front_after_blue_neighbor_flip"]):
				return {}
		else:
			var expected_yellow := "mapped_after_left_mirror" if selected == "s2_b15_left_mirror" else "mapped_after_right_mirror"
			var expected_revision := "stage_front_after_left_horizontal_transform" if selected == "s2_b15_left_mirror" else "stage_front_after_right_diagonal_transform"
			if String(binding.yellow_emission_state_id) != expected_yellow or String(binding.stage_front_revision_id) != expected_revision:
				return {}
	var surviving := _opposite_mirror_spawn_id(selected)
	return {
		"stage_front_revision_id": String(binding.stage_front_revision_id),
		"blue_emission_state_id": String(binding.blue_emission_state_id),
		"yellow_emission_state_id": String(binding.yellow_emission_state_id),
		"selected_mirror_spawn_id": selected,
		"surviving_mirror_spawn_id": surviving,
		"mirror_activation_mask": mask,
	}

func _historical_binding_reachable(binding: Dictionary, payload: Dictionary, spawn_id: String, spawn_tick: int) -> bool:
	var current_state: Dictionary = payload.hard_state
	var historical_selected := String(binding.selected_mirror_spawn_id)
	var current_selected := String(current_state.selected_mirror_spawn_id)
	if not historical_selected.is_empty() and historical_selected != current_selected:
		return false
	var red_defeated: bool = "s2_b13_red_booth_master" in payload.defeated_sources
	var red_tick := int((payload.source_states["s2_b13_red_booth_master"] as Dictionary).removed_tick)
	var blue_defeated: bool = "s2_b13_blue_booth_master" in payload.defeated_sources
	var blue_tick := int((payload.source_states["s2_b13_blue_booth_master"] as Dictionary).removed_tick)
	if String(binding.blue_emission_state_id) == "post_red":
		if _difficulty != "hard" or not red_defeated or red_tick > spawn_tick:
			return false
	elif _difficulty == "hard" and red_defeated and red_tick < spawn_tick:
		return false
	var revision := String(binding.stage_front_revision_id)
	var red_transition_key: Array = []
	var blue_transition_key: Array = []
	if red_defeated:
		red_transition_key = _snapshot_callback_key(payload.processed_callbacks, "accept_defeat", red_tick, {"spawn_id": "s2_b13_red_booth_master"})
	if blue_defeated:
		blue_transition_key = _snapshot_callback_key(payload.processed_callbacks, "accept_defeat", blue_tick, {"spawn_id": "s2_b13_blue_booth_master"})
	if revision == "stage_front_after_blue_neighbor_flip":
		if not blue_defeated or not red_defeated or blue_tick > spawn_tick:
			return false
		if not _callback_key_precedes(red_transition_key, blue_transition_key):
			return false
	elif revision == "stage_front_after_red_neighbor_flip":
		if not red_defeated or red_tick > spawn_tick:
			return false
		if blue_defeated:
			if _callback_key_precedes(red_transition_key, blue_transition_key) and blue_tick < spawn_tick:
				return false
	if historical_selected.is_empty():
		if not current_selected.is_empty():
			var current_selection_tick := int((payload.source_states[current_selected] as Dictionary).removed_tick)
			if current_selection_tick < spawn_tick:
				return false
	else:
		var historical_selection_tick := int((payload.source_states[historical_selected] as Dictionary).removed_tick)
		if historical_selection_tick > spawn_tick:
			return false
		var surviving := _opposite_mirror_spawn_id(historical_selected)
		var survivor_tick := int((payload.source_states[surviving] as Dictionary).removed_tick)
		var base_mask := _mirror_base_mask(historical_selected)
		var historical_mask := int(binding.mirror_activation_mask)
		if survivor_tick < 0 or survivor_tick > spawn_tick:
			if historical_mask != (base_mask | 4):
				return false
		elif survivor_tick < spawn_tick and historical_mask != base_mask:
			return false
	if spawn_id == "s2_b16_abacus_keeper" and int(binding.mirror_activation_mask) not in [5, 6]:
		return false
	return true

func _valid_hex_digest(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102):
			return false
	return true

func _valid_fingerprint(value: String, primitive: String) -> bool:
	var parts := value.split("|", true)
	if parts.size() != 7 or parts[0] != primitive:
		return false
	for part in parts:
		if not _valid_machine_id(part):
			return false
	return true

func _valid_machine_id(value: String) -> bool:
	if value.is_empty():
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 97 and code <= 122) and not (code >= 48 and code <= 57) and code != 95:
			return false
	return true

func _valid_uid_component(value: String) -> bool:
	return not value.is_empty() and not value.contains(":")

func _finite_number(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number)

func _valid_point(value: Variant) -> bool:
	if not _valid_numeric_pair(value):
		return false
	var x := float(value[0])
	var y := float(value[1])
	return x >= COMBAT_BOUNDS[0] and x <= COMBAT_BOUNDS[2] and y >= COMBAT_BOUNDS[1] and y <= COMBAT_BOUNDS[3]

func _valid_numeric_pair(value: Variant) -> bool:
	return value is Array and (value as Array).size() == 2 and _finite_number(value[0]) and _finite_number(value[1])

func _valid_segment(value: Variant) -> bool:
	return value is Array and (value as Array).size() == 2 and _valid_point(value[0]) and _valid_point(value[1])

func _valid_lane_array(value: Variant) -> bool:
	if not (value is Array) or (value as Array).is_empty():
		return false
	for lane in value:
		if typeof(lane) != TYPE_STRING or not LANE_CENTERS.has(String(lane)):
			return false
	return true

func _validate_gap_values(safe_route: Dictionary) -> bool:
	for key in ["gap_center_x_order"]:
		if safe_route.has(key) and not _valid_gap_array(safe_route[key]):
			return false
	for key in ["gap_center_x_order_by_state", "conditional_gap_center_x_order"]:
		if safe_route.has(key):
			if not (safe_route[key] is Dictionary):
				return false
			for value in (safe_route[key] as Dictionary).values():
				if not _valid_gap_array(value):
					return false
	return true

func _valid_gap_array(value: Variant) -> bool:
	if not (value is Array) or (value as Array).is_empty():
		return false
	for x_value in value:
		if not _finite_number(x_value) or float(x_value) < COMBAT_BOUNDS[0] or float(x_value) > COMBAT_BOUNDS[2]:
			return false
	return true

func _point_distance(a: Array, b: Array) -> float:
	var dx := float(b[0]) - float(a[0])
	var dy := float(b[1]) - float(a[1])
	return sqrt(dx * dx + dy * dy)

func _point_lerp(a: Array, b: Array, weight: float) -> Array:
	return [float(a[0]) + (float(b[0]) - float(a[0])) * weight, float(a[1]) + (float(b[1]) - float(a[1])) * weight]

func _velocity_between(a: Array, b: Array, speed: float) -> Array:
	var distance := _point_distance(a, b)
	if distance <= 0.0:
		return [0.0, 0.0]
	return [(float(b[0]) - float(a[0])) * speed / distance, (float(b[1]) - float(a[1])) * speed / distance]

func _velocity_from_angle(angle_degrees: float, speed: float) -> Array:
	var radians := deg_to_rad(angle_degrees)
	return [cos(radians) * speed, sin(radians) * speed]

func _segment_ticks(a: Array, b: Array, speed: float) -> int:
	return maxi(1, ceili(_point_distance(a, b) * float(TICK_RATE) / speed))

func _linear_exit_tick(position: Array, velocity: Array, spawn_tick: int) -> int:
	var seconds: Array[float] = []
	var vx := float(velocity[0])
	var vy := float(velocity[1])
	if vx > 0.0:
		seconds.append((COMBAT_BOUNDS[2] - float(position[0])) / vx)
	elif vx < 0.0:
		seconds.append((COMBAT_BOUNDS[0] - float(position[0])) / vx)
	if vy > 0.0:
		seconds.append((COMBAT_BOUNDS[3] - float(position[1])) / vy)
	elif vy < 0.0:
		seconds.append((COMBAT_BOUNDS[1] - float(position[1])) / vy)
	var positive_seconds := 999999.0
	for value in seconds:
		if value >= 0.0:
			positive_seconds = minf(positive_seconds, value)
	return spawn_tick + maxi(1, ceili(positive_seconds * float(TICK_RATE)))

func _has_exact_keys(value: Dictionary, expected_keys: Array) -> bool:
	var actual: Array = value.keys()
	actual.sort()
	var expected: Array = expected_keys.duplicate()
	expected.sort()
	return actual == expected

func _has_required_keys(value: Dictionary, required_keys: Array) -> bool:
	for key in required_keys:
		if not value.has(key):
			return false
	return true

func _first_error_path(error: String) -> String:
	var delimiter := error.find(":")
	return error.substr(0, delimiter) if delimiter >= 0 else "contract"

func _stable_digest(value: Variant) -> String:
	var canonical := _canonical_value(value, 0)
	return canonical.sha256_text() if not canonical.is_empty() else ""

func _canonical_value(value: Variant, depth: int) -> String:
	if depth > MAX_CANONICAL_DEPTH:
		return ""
	match typeof(value):
		TYPE_NIL:
			return "n;"
		TYPE_BOOL:
			return "b1;" if bool(value) else "b0;"
		TYPE_INT, TYPE_FLOAT:
			if not _finite_number(value):
				return ""
			return "x%.9f;" % float(value)
		TYPE_STRING, TYPE_STRING_NAME:
			var text := String(value)
			return "s%d:%s;" % [text.length(), text]
		TYPE_ARRAY:
			var array: Array = value
			if array.size() > MAX_CANONICAL_COLLECTION:
				return ""
			var result := "a%d[" % array.size()
			for item in array:
				var encoded := _canonical_value(item, depth + 1)
				if encoded.is_empty():
					return ""
				result += encoded
			return result + "]"
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			if dictionary.size() > MAX_CANONICAL_COLLECTION:
				return ""
			var keys: Array[String] = []
			for key in dictionary.keys():
				if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME]:
					return ""
				keys.append(String(key))
			keys.sort()
			var result := "d%d{" % keys.size()
			for key in keys:
				var encoded_key := _canonical_value(key, depth + 1)
				var encoded_value := _canonical_value(dictionary[key], depth + 1)
				if encoded_key.is_empty() or encoded_value.is_empty():
					return ""
				result += encoded_key + encoded_value
			return result + "}"
		_:
			return ""

func _is_canonical_value(value: Variant) -> bool:
	return not _canonical_value(value, 0).is_empty()

func _clear_configuration() -> void:
	_contract.clear()
	_rows.clear()
	_row_by_spawn.clear()
	_rows_by_event.clear()
	_budget_by_event.clear()
	_difficulty = ""
	_stage_run_uid = ""
	_stage_cap = 0
	_configured_contract_digest = ""
	_configured = false
	_validation_errors.clear()
	_hard_error_code = ""
	_hard_error_path = ""
	_hard_error_message = ""
	_update_in_progress = false
