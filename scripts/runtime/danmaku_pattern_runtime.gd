extends RefCounted
class_name DanmakuPatternRuntime

const DeterministicRng := preload("res://scripts/runtime/deterministic_rng.gd")

const SCHEMA_VERSION := 1
const SNAPSHOT_VERSION := 1
const TICKS_PER_SECOND := 60
const NORMAL_WARNING_FLOOR := 12
const HARD_WARNING_FLOOR := 8
const MAX_EMITTERS := 32
const MAX_BURSTS_PER_EMITTER := 64
const MAX_SHOTS_PER_BURST := 64
const MAX_BULLETS_PER_TICK := 512
const MAX_BULLETS_PER_LOOP := 4096
const MAX_RECORDS_PER_TICK := 1024
const MAX_LOOP_TICKS := 36000
const MAX_SEEK_TICKS := 216000
const PERMITTED_PRIMITIVES := [
	"rebound_bead",
	"grid_edge",
	"lane_fan",
	"rhythm_pulse",
	"delayed_seed",
]

var _phase: Dictionary = {}
var _profile: Dictionary = {}
var _difficulty := ""
var _run_seed := 0
var _phase_seed := 1
var _tick := 0
var _rng = DeterministicRng.new(1)
var _configured := false
var _validation_errors: Array[String] = []
var _hard_error := ""
var _locked_angles: Dictionary = {}
var _emitter_counts: Dictionary = {}
var _warning_count := 0
var _event_count := 0
var _boss_movement_count := 0
var _bullet_count := 0
var _last_tick_counts := {
	"warnings": 0,
	"events": 0,
	"boss_movements": 0,
	"bullet_specs": 0,
}

func configure(phase: Dictionary, difficulty: String, run_seed: int) -> bool:
	_phase = {}
	_profile = {}
	_difficulty = difficulty.to_lower()
	_run_seed = run_seed
	_configured = false
	_validation_errors = _validate_phase(phase)
	if _difficulty not in ["normal", "hard"]:
		_validation_errors.append("difficulty must be normal or hard")
	if not _validation_errors.is_empty():
		_hard_error = "configuration rejected: %s" % "; ".join(PackedStringArray(_validation_errors))
		return false
	_phase = phase.duplicate(true)
	_profile = _phase.difficulties[_difficulty].duplicate(true)
	_phase_seed = derive_phase_local_seed(_run_seed, String(_phase.deterministic_random_stream_id))
	if _phase_seed == 0:
		_validation_errors.append("phase-local seed derivation failed")
		_hard_error = "configuration rejected: phase-local seed derivation failed"
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
	_tick = 0
	_rng.reseed(_phase_seed)
	_locked_angles.clear()
	_emitter_counts.clear()
	for emitter_value in _profile.emitters:
		var emitter: Dictionary = emitter_value
		_emitter_counts[String(emitter.id)] = 0
	_warning_count = 0
	_event_count = 0
	_boss_movement_count = 0
	_bullet_count = 0
	_last_tick_counts = {
		"warnings": 0,
		"events": 0,
		"boss_movements": 0,
		"bullet_specs": 0,
	}
	_hard_error = ""
	return true

func advance(player_position: Vector2 = Vector2.ZERO) -> Dictionary:
	if not _configured:
		return _failure_result("runtime is not configured")
	if has_hard_error():
		return _failure_result(_hard_error)
	var loop_ticks := int(_phase.loop_ticks)
	var loop_tick := _tick % loop_ticks
	var loop_index := _tick / loop_ticks
	var output := {
		"ok": true,
		"tick": _tick,
		"loop_index": loop_index,
		"loop_tick": loop_tick,
		"phase_id": String(_phase.id),
		"difficulty": _difficulty,
		"topology_id": String(_profile.topology_id),
		"warnings": [],
		"events": [],
		"boss_movements": [],
		"bullet_specs": [],
	}
	_emit_boss_movements(loop_tick, loop_index, output.boss_movements)
	_emit_timeline_events(loop_tick, loop_index, output.events)
	_commit_explicit_aim_locks(loop_tick, loop_index, player_position, output.events)
	_emit_warnings(loop_tick, loop_index, output.warnings)
	_emit_bursts(loop_tick, loop_index, output.events, output.bullet_specs)
	var record_count: int = output.warnings.size() + output.events.size() + output.boss_movements.size() + output.bullet_specs.size()
	if output.bullet_specs.size() > MAX_BULLETS_PER_TICK or record_count > MAX_RECORDS_PER_TICK:
		return _hard_fail("runtime output cap exceeded at tick %d" % _tick)
	_last_tick_counts = {
		"warnings": output.warnings.size(),
		"events": output.events.size(),
		"boss_movements": output.boss_movements.size(),
		"bullet_specs": output.bullet_specs.size(),
	}
	_warning_count += output.warnings.size()
	_event_count += output.events.size()
	_boss_movement_count += output.boss_movements.size()
	_bullet_count += output.bullet_specs.size()
	_tick += 1
	return output

func seek(target_tick: int, player_positions: Variant = {}) -> Dictionary:
	if not _configured:
		return _failure_result("runtime is not configured")
	if target_tick < 0 or target_tick > MAX_SEEK_TICKS:
		return _hard_fail("seek tick is outside the supported range")
	reset()
	while _tick < target_tick:
		var result := advance(_player_position_for_tick(player_positions, _tick))
		if not bool(result.get("ok", false)):
			return result
	return {
		"ok": true,
		"tick": _tick,
		"telemetry": telemetry_snapshot(),
	}

func capture_snapshot() -> Dictionary:
	if not _configured or has_hard_error():
		return {}
	return {
		"version": SNAPSHOT_VERSION,
		"phase_id": String(_phase.id),
		"phase_signature": _phase_signature(),
		"difficulty": _difficulty,
		"topology_id": String(_profile.topology_id),
		"run_seed": _run_seed,
		"phase_seed": _phase_seed,
		"tick": _tick,
		"rng": _rng.snapshot(),
		"locked_angles": _locked_angles.duplicate(true),
		"emitter_counts": _emitter_counts.duplicate(true),
		"warning_count": _warning_count,
		"event_count": _event_count,
		"boss_movement_count": _boss_movement_count,
		"bullet_count": _bullet_count,
		"last_tick_counts": _last_tick_counts.duplicate(true),
	}

func validate_snapshot(snapshot: Dictionary) -> bool:
	if not _configured or int(snapshot.get("version", -1)) != SNAPSHOT_VERSION:
		return false
	if String(snapshot.get("phase_id", "")) != String(_phase.id):
		return false
	if String(snapshot.get("phase_signature", "")) != _phase_signature():
		return false
	if String(snapshot.get("difficulty", "")) != _difficulty or String(snapshot.get("topology_id", "")) != String(_profile.topology_id):
		return false
	if typeof(snapshot.get("run_seed")) != TYPE_INT or int(snapshot.run_seed) != _run_seed:
		return false
	if typeof(snapshot.get("phase_seed")) != TYPE_INT or int(snapshot.phase_seed) != _phase_seed:
		return false
	if typeof(snapshot.get("tick")) != TYPE_INT or int(snapshot.tick) < 0 or int(snapshot.tick) > MAX_SEEK_TICKS:
		return false
	if not (snapshot.get("rng") is Dictionary):
		return false
	var rng_probe = DeterministicRng.new(1)
	if not rng_probe.validate_snapshot(snapshot.rng) or int(snapshot.rng.get("initial_seed", 0)) != _phase_seed:
		return false
	if not (snapshot.get("locked_angles") is Dictionary) or not _validate_locked_angles(snapshot.locked_angles, int(snapshot.tick)):
		return false
	if not (snapshot.get("emitter_counts") is Dictionary) or not _validate_emitter_counts(snapshot.emitter_counts):
		return false
	for count_key in ["warning_count", "event_count", "boss_movement_count", "bullet_count"]:
		if typeof(snapshot.get(count_key)) != TYPE_INT or int(snapshot[count_key]) < 0:
			return false
	if not (snapshot.get("last_tick_counts") is Dictionary):
		return false
	for count_key in ["warnings", "events", "boss_movements", "bullet_specs"]:
		if typeof(snapshot.last_tick_counts.get(count_key)) != TYPE_INT or int(snapshot.last_tick_counts[count_key]) < 0:
			return false
	return int(snapshot.last_tick_counts.bullet_specs) <= MAX_BULLETS_PER_TICK

func restore_snapshot(snapshot: Dictionary) -> bool:
	if not validate_snapshot(snapshot):
		return false
	if not _rng.restore(snapshot.rng):
		return false
	_tick = int(snapshot.tick)
	_locked_angles = snapshot.locked_angles.duplicate(true)
	_emitter_counts = snapshot.emitter_counts.duplicate(true)
	_warning_count = int(snapshot.warning_count)
	_event_count = int(snapshot.event_count)
	_boss_movement_count = int(snapshot.boss_movement_count)
	_bullet_count = int(snapshot.bullet_count)
	_last_tick_counts = snapshot.last_tick_counts.duplicate(true)
	_hard_error = ""
	return true

func telemetry_snapshot() -> Dictionary:
	return {
		"version": SNAPSHOT_VERSION,
		"configured": _configured,
		"phase_id": String(_phase.get("id", "")),
		"phase_signature": _phase_signature(),
		"difficulty": _difficulty,
		"topology_id": String(_profile.get("topology_id", "")),
		"topology_signature": _topology_signature(_profile),
		"run_seed": _run_seed,
		"phase_seed": _phase_seed,
		"tick": _tick,
		"loop_index": 0 if _phase.is_empty() else _tick / int(_phase.loop_ticks),
		"loop_tick": 0 if _phase.is_empty() else _tick % int(_phase.loop_ticks),
		"rng_draw_count": int(_rng.draw_count),
		"locked_angles": _locked_angles.duplicate(true),
		"emitter_counts": _emitter_counts.duplicate(true),
		"totals": {
			"warnings": _warning_count,
			"events": _event_count,
			"boss_movements": _boss_movement_count,
			"bullet_specs": _bullet_count,
		},
		"last_tick_counts": _last_tick_counts.duplicate(true),
		"hard_error": _hard_error,
	}

static func derive_phase_local_seed(run_seed: int, stream_id: String) -> int:
	if stream_id.is_empty():
		return 0
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return 0
	var material := "danmaku-pattern-runtime-v1|%d|%s" % [run_seed, stream_id]
	if context.update(material.to_utf8_buffer()) != OK:
		return 0
	var digest := context.finish()
	var derived := 0
	for index in range(8):
		var byte_value := int(digest[index])
		if index == 0:
			byte_value &= 0x7f
		derived = (derived << 8) | byte_value
	return derived if derived != 0 else 1

func _validate_phase(phase: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if typeof(phase.get("schema_version")) != TYPE_INT or int(phase.schema_version) != SCHEMA_VERSION:
		errors.append("schema_version must be integer 1")
	for key in ["id", "deterministic_random_stream_id"]:
		if String(phase.get(key, "")).is_empty():
			errors.append("%s is required" % key)
	if typeof(phase.get("loop_ticks")) != TYPE_INT or int(phase.get("loop_ticks", 0)) <= 0 or int(phase.get("loop_ticks", 0)) > MAX_LOOP_TICKS:
		errors.append("loop_ticks must be within 1..%d" % MAX_LOOP_TICKS)
	if not (phase.get("warning_ticks") is Dictionary):
		errors.append("warning_ticks must be a Dictionary")
	else:
		_validate_warning_floor(phase.warning_ticks, "normal", NORMAL_WARNING_FLOOR, errors)
		_validate_warning_floor(phase.warning_ticks, "hard", HARD_WARNING_FLOOR, errors)
	_validate_ordered_records(phase.get("boss_movement"), "boss_movement", 3, true, int(phase.get("loop_ticks", 0)), errors)
	_validate_ordered_records(phase.get("timeline"), "timeline", 4, false, int(phase.get("loop_ticks", 0)), errors)
	if not (phase.get("difficulties") is Dictionary):
		errors.append("difficulties must be a Dictionary")
		return errors
	var profiles: Dictionary = phase.difficulties
	for difficulty in ["normal", "hard"]:
		if not (profiles.get(difficulty) is Dictionary):
			errors.append("difficulties.%s must be a Dictionary" % difficulty)
			continue
		_validate_profile(profiles[difficulty], difficulty, phase, errors)
	if profiles.get("normal") is Dictionary and profiles.get("hard") is Dictionary:
		var normal_id := String(profiles.normal.get("topology_id", ""))
		var hard_id := String(profiles.hard.get("topology_id", ""))
		if normal_id == hard_id:
			errors.append("normal and hard topology_id must differ")
		if _is_numeric_identifier(normal_id) or _is_numeric_identifier(hard_id):
			errors.append("topology_id must describe a non-numeric structural topology")
		if _topology_shape_signature(profiles.normal) == _topology_shape_signature(profiles.hard):
			errors.append("normal and hard emitters must differ structurally, not only numerically")
	return errors

func _validate_warning_floor(values: Dictionary, difficulty: String, floor_ticks: int, errors: Array[String]) -> void:
	if typeof(values.get(difficulty)) != TYPE_INT or int(values.get(difficulty, 0)) < floor_ticks:
		errors.append("warning_ticks.%s must be at least %d" % [difficulty, floor_ticks])

func _validate_ordered_records(value: Variant, label: String, expected_size: int, require_position: bool, loop_ticks: int, errors: Array[String]) -> void:
	if not (value is Array) or value.size() != expected_size:
		errors.append("%s must contain exactly %d records" % [label, expected_size])
		return
	var ids := {}
	var previous_tick := -1
	for index in range(value.size()):
		if not (value[index] is Dictionary):
			errors.append("%s[%d] must be a Dictionary" % [label, index])
			continue
		var record: Dictionary = value[index]
		var record_id := String(record.get("id", ""))
		if record_id.is_empty() or ids.has(record_id):
			errors.append("%s[%d] has a missing or duplicate id" % [label, index])
		ids[record_id] = true
		if typeof(record.get("tick")) != TYPE_INT or int(record.get("tick", -1)) < previous_tick or int(record.get("tick", -1)) < 0 or int(record.get("tick", -1)) >= loop_ticks:
			errors.append("%s[%d].tick must be ordered inside loop_ticks" % [label, index])
		else:
			previous_tick = int(record.tick)
		if require_position and not _is_vector2_value(record.get("position")):
			errors.append("%s[%d].position must be a finite Vector2 value" % [label, index])

func _validate_profile(profile: Dictionary, difficulty: String, phase: Dictionary, errors: Array[String]) -> void:
	var topology_id := String(profile.get("topology_id", ""))
	if topology_id.is_empty() or _is_numeric_identifier(topology_id):
		errors.append("difficulties.%s.topology_id must be a non-numeric identifier" % difficulty)
	if not (profile.get("emitters") is Array):
		errors.append("difficulties.%s.emitters must be an Array" % difficulty)
		return
	var emitters: Array = profile.emitters
	if emitters.is_empty() or emitters.size() > MAX_EMITTERS:
		errors.append("difficulties.%s.emitters must contain 1..%d entries" % [difficulty, MAX_EMITTERS])
		return
	var seen_ids := {}
	var bullet_counts := {}
	var record_counts := {}
	var loop_total := 0
	var warning_floor := int(phase.warning_ticks.get(difficulty, 0)) if phase.get("warning_ticks") is Dictionary else 0
	for index in range(emitters.size()):
		if not (emitters[index] is Dictionary):
			errors.append("difficulties.%s.emitters[%d] must be a Dictionary" % [difficulty, index])
			continue
		var emitter: Dictionary = emitters[index]
		_validate_emitter(emitter, difficulty, index, int(phase.get("loop_ticks", 0)), warning_floor, errors)
		var emitter_id := String(emitter.get("id", ""))
		if not emitter_id.is_empty() and seen_ids.has(emitter_id):
			errors.append("difficulties.%s has duplicate emitter id %s" % [difficulty, emitter_id])
		seen_ids[emitter_id] = true
		if (
			not _emitter_schedule_shape_is_valid(emitter, int(phase.get("loop_ticks", 0)))
			or not (emitter.get("warning") is Dictionary)
			or typeof(emitter.warning.get("lead_ticks")) != TYPE_INT
		):
			continue
		var bursts := int(emitter.bursts_per_loop)
		var shots := int(emitter.shots_per_burst)
		loop_total += bursts * shots
		for burst_index in range(bursts):
			var burst_tick := int(emitter.start_tick) + burst_index * int(emitter.interval_ticks)
			var warning_tick := posmod(burst_tick - int(emitter.warning.lead_ticks), int(phase.loop_ticks))
			bullet_counts[burst_tick] = int(bullet_counts.get(burst_tick, 0)) + shots
			record_counts[burst_tick] = int(record_counts.get(burst_tick, 0)) + shots + 1
			record_counts[warning_tick] = int(record_counts.get(warning_tick, 0)) + 1
		for lock_tick in _aim_lock_ticks(emitter):
			record_counts[lock_tick] = int(record_counts.get(lock_tick, 0)) + 1
	if loop_total > MAX_BULLETS_PER_LOOP:
		errors.append("difficulties.%s exceeds the %d bullet-per-loop cap" % [difficulty, MAX_BULLETS_PER_LOOP])
	for count in bullet_counts.values():
		if int(count) > MAX_BULLETS_PER_TICK:
			errors.append("difficulties.%s exceeds the %d bullet-per-tick cap" % [difficulty, MAX_BULLETS_PER_TICK])
			break
	for count in record_counts.values():
		if int(count) > MAX_RECORDS_PER_TICK:
			errors.append("difficulties.%s exceeds the %d record-per-tick cap" % [difficulty, MAX_RECORDS_PER_TICK])
			break

func _validate_emitter(emitter: Dictionary, difficulty: String, index: int, loop_ticks: int, warning_floor: int, errors: Array[String]) -> void:
	var label := "difficulties.%s.emitters[%d]" % [difficulty, index]
	for key in ["id", "family"]:
		if String(emitter.get(key, "")).is_empty():
			errors.append("%s.%s is required" % [label, key])
	var primitive := String(emitter.get("primitive", ""))
	if primitive not in PERMITTED_PRIMITIVES:
		errors.append("%s.primitive is unsupported" % label)
	for key in ["start_tick", "interval_ticks", "bursts_per_loop", "shots_per_burst", "lifetime_ticks"]:
		if typeof(emitter.get(key)) != TYPE_INT:
			errors.append("%s.%s must be an integer" % [label, key])
	if not _emitter_schedule_shape_is_valid(emitter, loop_ticks):
		errors.append("%s schedule is outside loop/caps" % label)
	if not _is_vector2_value(emitter.get("anchor")):
		errors.append("%s.anchor must be a finite Vector2 value" % label)
	if not _is_color_value(emitter.get("color_rgba")):
		errors.append("%s.color_rgba must be Color or four finite channels" % label)
	for key in ["radius", "speed", "angle_degrees"]:
		if not _is_finite_number(emitter.get(key)):
			errors.append("%s.%s must be finite numeric data" % [label, key])
	if _is_finite_number(emitter.get("radius")) and float(emitter.radius) <= 0.0:
		errors.append("%s.radius must be positive" % label)
	if _is_finite_number(emitter.get("speed")) and float(emitter.speed) < 0.0:
		errors.append("%s.speed must be non-negative" % label)
	if not (emitter.get("warning") is Dictionary) or typeof(emitter.warning.get("lead_ticks")) != TYPE_INT:
		errors.append("%s.warning.lead_ticks must be an integer" % label)
	elif int(emitter.warning.lead_ticks) < warning_floor or int(emitter.warning.lead_ticks) > loop_ticks:
		errors.append("%s.warning.lead_ticks violates the difficulty warning contract" % label)
	var aim_mode := String(emitter.get("aim_mode", "fixed"))
	if aim_mode not in ["fixed", "player_locked"]:
		errors.append("%s.aim_mode must be fixed or player_locked" % label)
	if aim_mode == "player_locked":
		var lock_ticks := _aim_lock_ticks(emitter)
		if lock_ticks.is_empty():
			errors.append("%s player aim requires explicit aim_lock_ticks" % label)
		for lock_tick in lock_ticks:
			if lock_tick < 0 or lock_tick >= loop_ticks:
				errors.append("%s has an aim lock outside loop_ticks" % label)
		if _emitter_schedule_shape_is_valid(emitter, loop_ticks):
			for burst_index in range(int(emitter.bursts_per_loop)):
				var burst_tick := int(emitter.start_tick) + burst_index * int(emitter.interval_ticks)
				var has_prior_lock := false
				for lock_tick in lock_ticks:
					if lock_tick <= burst_tick:
						has_prior_lock = true
				if not has_prior_lock:
					errors.append("%s has a player-aimed burst before any explicit lock" % label)
	match primitive:
		"rebound_bead":
			if not (emitter.get("reflection") is Dictionary):
				errors.append("%s.reflection must encode rebound behavior" % label)
			else:
				var axes := String(emitter.reflection.get("axes", ""))
				if axes not in ["x", "y", "xy"] or typeof(emitter.reflection.get("max_reflections")) != TYPE_INT or int(emitter.reflection.max_reflections) < 1:
					errors.append("%s.reflection is malformed" % label)
		"grid_edge":
			if String(emitter.get("routing", "")) not in ["down", "up", "left", "right"] or not _is_positive_number(emitter.get("spacing")):
				errors.append("%s grid routing/spacing is malformed" % label)
		"lane_fan":
			if not _is_finite_number(emitter.get("spread_degrees")) or float(emitter.get("spread_degrees", -1.0)) < 0.0:
				errors.append("%s.spread_degrees is malformed" % label)
		"rhythm_pulse":
			if not _is_finite_number(emitter.get("turn_rate")):
				errors.append("%s.turn_rate is required for curve motion" % label)
		"delayed_seed":
			if typeof(emitter.get("delay_ticks")) != TYPE_INT or int(emitter.get("delay_ticks", 0)) <= 0 or not _is_finite_number(emitter.get("turn_rate", 0.0)):
				errors.append("%s delay/curve motion is malformed" % label)

func _emitter_schedule_shape_is_valid(emitter: Dictionary, loop_ticks: int) -> bool:
	for key in ["start_tick", "interval_ticks", "bursts_per_loop", "shots_per_burst", "lifetime_ticks"]:
		if typeof(emitter.get(key)) != TYPE_INT:
			return false
	var start_tick := int(emitter.start_tick)
	var interval := int(emitter.interval_ticks)
	var bursts := int(emitter.bursts_per_loop)
	var shots := int(emitter.shots_per_burst)
	if start_tick < 0 or start_tick >= loop_ticks or interval <= 0:
		return false
	if bursts <= 0 or bursts > MAX_BURSTS_PER_EMITTER or shots <= 0 or shots > MAX_SHOTS_PER_BURST or int(emitter.lifetime_ticks) <= 0:
		return false
	return start_tick + (bursts - 1) * interval < loop_ticks

func _emit_boss_movements(loop_tick: int, loop_index: int, destination: Array) -> void:
	for value in _phase.boss_movement:
		var record: Dictionary = value
		if int(record.tick) != loop_tick:
			continue
		var normalized := record.duplicate(true)
		normalized["kind"] = "boss_movement"
		normalized["phase_id"] = String(_phase.id)
		normalized["loop_index"] = loop_index
		normalized["position"] = _as_vector2(record.position)
		destination.append(normalized)

func _emit_timeline_events(loop_tick: int, loop_index: int, destination: Array) -> void:
	for value in _phase.timeline:
		var record: Dictionary = value
		if int(record.tick) != loop_tick:
			continue
		var normalized := record.duplicate(true)
		normalized["phase_id"] = String(_phase.id)
		normalized["loop_index"] = loop_index
		normalized["source"] = "timeline"
		destination.append(normalized)

func _commit_explicit_aim_locks(loop_tick: int, loop_index: int, player_position: Vector2, destination: Array) -> void:
	for emitter_value in _profile.emitters:
		var emitter: Dictionary = emitter_value
		if String(emitter.get("aim_mode", "fixed")) != "player_locked" or loop_tick not in _aim_lock_ticks(emitter):
			continue
		var emitter_id := String(emitter.id)
		var anchor := _as_vector2(emitter.anchor)
		var angle := (player_position - anchor).angle()
		_locked_angles[emitter_id] = angle
		destination.append({
			"kind": "aim_lock",
			"phase_id": String(_phase.id),
			"topology_id": String(_profile.topology_id),
			"emitter_id": emitter_id,
			"loop_index": loop_index,
			"loop_tick": loop_tick,
			"angle_radians": angle,
		})

func _emit_warnings(loop_tick: int, loop_index: int, destination: Array) -> void:
	var loop_ticks := int(_phase.loop_ticks)
	for emitter_value in _profile.emitters:
		var emitter: Dictionary = emitter_value
		for burst_index in range(int(emitter.bursts_per_loop)):
			var burst_tick := int(emitter.start_tick) + burst_index * int(emitter.interval_ticks)
			var warning_tick := posmod(burst_tick - int(emitter.warning.lead_ticks), loop_ticks)
			if warning_tick != loop_tick:
				continue
			destination.append({
				"kind": "emitter_warning",
				"phase_id": String(_phase.id),
				"topology_id": String(_profile.topology_id),
				"emitter_id": String(emitter.id),
				"primitive": String(emitter.primitive),
				"loop_index": loop_index,
				"loop_tick": loop_tick,
				"burst_index": burst_index,
				"fire_loop_tick": burst_tick,
				"lead_ticks": int(emitter.warning.lead_ticks),
				"anchor": _as_vector2(emitter.anchor),
			})

func _emit_bursts(loop_tick: int, loop_index: int, events: Array, bullet_specs: Array) -> void:
	for emitter_value in _profile.emitters:
		var emitter: Dictionary = emitter_value
		for burst_index in range(int(emitter.bursts_per_loop)):
			var burst_tick := int(emitter.start_tick) + burst_index * int(emitter.interval_ticks)
			if burst_tick != loop_tick:
				continue
			var emitter_id := String(emitter.id)
			events.append({
				"kind": "emitter_burst",
				"phase_id": String(_phase.id),
				"topology_id": String(_profile.topology_id),
				"emitter_id": emitter_id,
				"primitive": String(emitter.primitive),
				"loop_index": loop_index,
				"loop_tick": loop_tick,
				"burst_index": burst_index,
			})
			var specs := _bullet_specs_for_burst(emitter, burst_index, loop_index)
			bullet_specs.append_array(specs)
			_emitter_counts[emitter_id] = int(_emitter_counts.get(emitter_id, 0)) + specs.size()

func _bullet_specs_for_burst(emitter: Dictionary, burst_index: int, loop_index: int) -> Array:
	var result: Array = []
	var primitive := String(emitter.primitive)
	var shots := int(emitter.shots_per_burst)
	var anchor := _as_vector2(emitter.anchor)
	var base_angle := deg_to_rad(float(emitter.angle_degrees) + float(emitter.get("burst_angle_step_degrees", 0.0)) * burst_index)
	if String(emitter.get("aim_mode", "fixed")) == "player_locked":
		base_angle += float(_locked_angles.get(String(emitter.id), 0.0))
	var jitter_degrees := absf(float(emitter.get("random_angle_degrees", 0.0)))
	for shot_index in range(shots):
		var angle := base_angle
		var position := anchor
		match primitive:
			"rebound_bead":
				angle += deg_to_rad(_fan_offset(shot_index, shots, float(emitter.get("spread_degrees", 0.0))))
			"grid_edge":
				var centered := float(shot_index) - float(shots - 1) * 0.5
				var spacing := float(emitter.spacing)
				if String(emitter.routing) in ["down", "up"]:
					position.x += centered * spacing
				else:
					position.y += centered * spacing
			"lane_fan":
				angle += deg_to_rad(_fan_offset(shot_index, shots, float(emitter.spread_degrees)))
			"rhythm_pulse":
				angle += TAU * float(shot_index) / float(shots)
			"delayed_seed":
				angle += deg_to_rad(_fan_offset(shot_index, shots, float(emitter.get("spread_degrees", 0.0))))
		if jitter_degrees > 0.0:
			angle += deg_to_rad(_rng.range_float(-jitter_degrees, jitter_degrees))
		var launch_velocity := Vector2(cos(angle), sin(angle)) * float(emitter.speed)
		var motion := _motion_for(emitter, launch_velocity, burst_index, shot_index)
		result.append({
			"position": position,
			"velocity": Vector2.ZERO if primitive == "delayed_seed" else launch_velocity,
			"radius": float(emitter.radius),
			"color": _as_color(emitter.color_rgba),
			"family_id": String(emitter.family),
			"lifetime": float(emitter.lifetime_ticks),
			"motion": motion,
			"phase_id": String(_phase.id),
			"topology_id": String(_profile.topology_id),
			"emitter_id": String(emitter.id),
			"primitive": primitive,
			"loop_index": loop_index,
			"burst_index": burst_index,
			"shot_index": shot_index,
		})
	return result

func _motion_for(emitter: Dictionary, launch_velocity: Vector2, burst_index: int, shot_index: int) -> Dictionary:
	match String(emitter.primitive):
		"rebound_bead":
			return {
				"kind": "reflect",
				"axes": String(emitter.reflection.axes),
				"max_reflections": int(emitter.reflection.max_reflections),
				"bounce_count": int(emitter.reflection.max_reflections),
				"bounds": emitter.reflection.get("bounds", Rect2(24.0, 48.0, 672.0, 888.0)),
			}
		"grid_edge":
			return {"kind": "linear_route", "routing": String(emitter.routing)}
		"lane_fan":
			return {"kind": "lane_fan", "aim_locked": String(emitter.get("aim_mode", "fixed")) == "player_locked"}
		"rhythm_pulse":
			return {"kind": "curve", "turn_rate": float(emitter.turn_rate), "pulse_index": burst_index}
		"delayed_seed":
			return {
				"kind": "delayed_aim",
				"delay_ticks": int(emitter.delay_ticks),
				"trigger_age": float(emitter.delay_ticks),
				"launch_velocity": launch_velocity,
				"heading": launch_velocity.angle(),
				"target_speed": launch_velocity.length(),
				"aim_on_trigger": false,
				"turn_rate": float(emitter.get("turn_rate", 0.0)),
				"seed_index": shot_index,
			}
	return {}

func _validate_locked_angles(values: Dictionary, snapshot_tick: int) -> bool:
	var expected_ids := {}
	for emitter_value in _profile.emitters:
		var emitter: Dictionary = emitter_value
		if String(emitter.get("aim_mode", "fixed")) != "player_locked":
			continue
		for lock_tick in _aim_lock_ticks(emitter):
			if snapshot_tick > lock_tick:
				expected_ids[String(emitter.id)] = true
				break
	if values.size() != expected_ids.size():
		return false
	for key in values.keys():
		if not expected_ids.has(String(key)) or not _is_finite_number(values[key]):
			return false
	return true

func _validate_emitter_counts(values: Dictionary) -> bool:
	if values.size() != _profile.emitters.size():
		return false
	for emitter_value in _profile.emitters:
		var emitter: Dictionary = emitter_value
		var emitter_id := String(emitter.id)
		if typeof(values.get(emitter_id)) != TYPE_INT or int(values[emitter_id]) < 0:
			return false
	return true

func _aim_lock_ticks(emitter: Dictionary) -> Array[int]:
	var result: Array[int] = []
	var source = emitter.get("aim_lock_ticks", [])
	if source is Array:
		for value in source:
			if typeof(value) == TYPE_INT and int(value) not in result:
				result.append(int(value))
	result.sort()
	return result

func _player_position_for_tick(source: Variant, tick: int) -> Vector2:
	if source is Dictionary:
		return _as_vector2(source.get(tick, Vector2.ZERO))
	if source is Array and tick < source.size():
		return _as_vector2(source[tick])
	return Vector2.ZERO

func _topology_signature(profile: Dictionary) -> String:
	if profile.is_empty():
		return ""
	var parts := PackedStringArray([String(profile.get("topology_id", ""))])
	var emitters = profile.get("emitters", [])
	if emitters is Array:
		for emitter_value in emitters:
			if emitter_value is Dictionary:
				parts.append("%s:%s:%s" % [String(emitter_value.get("id", "")), String(emitter_value.get("primitive", "")), String(emitter_value.get("routing", emitter_value.get("aim_mode", "fixed")))])
	return "|".join(parts)

func _topology_shape_signature(profile: Dictionary) -> String:
	var parts := PackedStringArray()
	var emitters = profile.get("emitters", [])
	if emitters is Array:
		for emitter_value in emitters:
			if not (emitter_value is Dictionary):
				continue
			var emitter: Dictionary = emitter_value
			var reflection_axes := ""
			if emitter.get("reflection") is Dictionary:
				reflection_axes = String(emitter.reflection.get("axes", ""))
			parts.append("%s:%s:%s:%s:%s" % [
				String(emitter.get("id", "")),
				String(emitter.get("primitive", "")),
				String(emitter.get("routing", "")),
				String(emitter.get("aim_mode", "fixed")),
				reflection_axes,
			])
	return "|".join(parts)

func _phase_signature() -> String:
	if _phase.is_empty():
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(var_to_bytes(_phase)) != OK:
		return ""
	return context.finish().hex_encode()

func _failure_result(message: String) -> Dictionary:
	return {"ok": false, "tick": _tick, "error": message}

func _hard_fail(message: String) -> Dictionary:
	_hard_error = message
	return _failure_result(message)

func _fan_offset(index: int, count: int, spread_degrees: float) -> float:
	if count <= 1:
		return 0.0
	return -spread_degrees * 0.5 + spread_degrees * float(index) / float(count - 1)

func _is_numeric_identifier(value: String) -> bool:
	return value.is_valid_int() or value.is_valid_float()

func _is_positive_number(value: Variant) -> bool:
	return _is_finite_number(value) and float(value) > 0.0

func _is_finite_number(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var numeric := float(value)
	return not is_nan(numeric) and not is_inf(numeric)

func _is_vector2_value(value: Variant) -> bool:
	if value is Vector2:
		return _is_finite_number(value.x) and _is_finite_number(value.y)
	if value is Array and value.size() == 2:
		return _is_finite_number(value[0]) and _is_finite_number(value[1])
	if value is Dictionary:
		return _is_finite_number(value.get("x")) and _is_finite_number(value.get("y"))
	return false

func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO

func _is_color_value(value: Variant) -> bool:
	if value is Color:
		return _is_finite_number(value.r) and _is_finite_number(value.g) and _is_finite_number(value.b) and _is_finite_number(value.a)
	if value is Array and value.size() == 4:
		for channel in value:
			if not _is_finite_number(channel) or float(channel) < 0.0 or float(channel) > 1.0:
				return false
		return true
	return false

func _as_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
