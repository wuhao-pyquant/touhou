extends RefCounted

const VERSION := 1
const DEFAULT_WARNING_FLOOR := {"normal": 12, "hard": 8}

var id: String = ""
var duration_ticks: int = 0
var emitters: Array[Dictionary] = []
var tags: Array[String] = []

# Optional M1 structure fields. M0 callers may continue to provide only id,
# duration_ticks, emitters, and tags.
var deterministic_random_stream_id: String = ""
var ordered_timeline: Array[Dictionary] = []
var bullet_motion_rules: Array[Dictionary] = []
var boss_movement: Array[Dictionary] = []
var normal_structure: Dictionary = {}
var hard_topology_change: Dictionary = {}
var warning_contract: Dictionary = {}
var warning_floor: Dictionary = DEFAULT_WARNING_FLOOR.duplicate(true)
var bullet_family_metadata: Dictionary = {}
var bullet_metadata_source: String = ""

func _init(values: Dictionary = {}) -> void:
	configure(values)

func configure(values: Dictionary) -> void:
	id = String(values.get("id", id))
	duration_ticks = int(values.get("duration_ticks", duration_ticks))
	emitters.clear()
	var source_emitters = values.get("emitters", [])
	if source_emitters is Array:
		for emitter in source_emitters:
			if emitter is Dictionary:
				emitters.append(emitter.duplicate(true))
	tags.clear()
	var source_tags = values.get("tags", [])
	if source_tags is Array:
		for tag in source_tags:
			tags.append(String(tag))
	deterministic_random_stream_id = String(values.get("deterministic_random_stream_id", ""))
	ordered_timeline.clear()
	var source_timeline = values.get("timeline", values.get("ordered_timeline", []))
	if source_timeline is Array:
		for event in source_timeline:
			if event is Dictionary:
				ordered_timeline.append(event.duplicate(true))
	bullet_motion_rules.clear()
	var source_motion_rules = values.get("bullet_motion_rules", [])
	if source_motion_rules is Array:
		for rule in source_motion_rules:
			if rule is Dictionary:
				bullet_motion_rules.append(rule.duplicate(true))
	boss_movement.clear()
	var source_movement = values.get("boss_movement", [])
	if source_movement is Array:
		for movement in source_movement:
			if movement is Dictionary:
				boss_movement.append(movement.duplicate(true))
	normal_structure = _dictionary_copy(values.get("normal_structure", {}))
	hard_topology_change = _dictionary_copy(values.get("hard_topology_change", {}))
	warning_contract = _dictionary_copy(values.get("telegraph_frames", values.get("warning_contract", {})))
	warning_floor = DEFAULT_WARNING_FLOOR.duplicate(true)
	var source_warning_floor = values.get("warning_floor", {})
	if source_warning_floor is Dictionary:
		for key in source_warning_floor:
			warning_floor[key] = source_warning_floor[key]
	bullet_family_metadata = _dictionary_copy(values.get("bullet_family_metadata", {}))
	bullet_metadata_source = String(values.get("bullet_metadata_source", ""))

func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("id is required")
	if duration_ticks <= 0:
		errors.append("duration_ticks must be positive")
	if emitters.is_empty():
		errors.append("at least one emitter is required")
	var seen_emitter_ids := {}
	for index in range(emitters.size()):
		var emitter_id := String(emitters[index].get("id", ""))
		if emitter_id.is_empty():
			errors.append("emitters[%d].id is required" % index)
		elif seen_emitter_ids.has(emitter_id):
			errors.append("emitters[%d].id must be unique" % index)
		seen_emitter_ids[emitter_id] = true
		if String(emitters[index].get("topology", emitters[index].get("composition_role", ""))).is_empty():
			errors.append("emitters[%d].topology is required" % index)
	if is_m1_contract():
		if deterministic_random_stream_id.is_empty():
			errors.append("deterministic_random_stream_id is required for an M1 pattern")
		if ordered_timeline.size() != 4:
			errors.append("M1 pattern timeline must contain exactly four ordered events")
		if boss_movement.size() != 3:
			errors.append("M1 pattern boss_movement must contain exactly three entries")
		if bullet_motion_rules.is_empty():
			errors.append("M1 pattern bullet_motion_rules are required")
		if bullet_motion_rules.size() != emitters.size():
			errors.append("M1 pattern must expose one bullet motion rule per emitter role")
		if normal_structure.is_empty():
			errors.append("M1 pattern normal_structure is required")
		if not has_authored_hard_topology_change():
			errors.append("M1 pattern Hard mode must author a non-numeric topology change")
		if bullet_metadata_source != "GameDatabase.bullet_family_by_id":
			errors.append("M1 bullet metadata must resolve through GameDatabase.bullet_family_by_id")
		for difficulty in ["normal", "hard"]:
			var warning_frames := int(warning_contract.get(difficulty, 0))
			var minimum_frames := int(warning_floor.get(difficulty, 0))
			var catalog_floor := int(DEFAULT_WARNING_FLOOR.get(difficulty, 0))
			if warning_frames <= 0:
				errors.append("warning_contract.%s must be positive" % difficulty)
			elif minimum_frames < catalog_floor or warning_frames < catalog_floor or warning_frames < minimum_frames:
				errors.append("warning_contract.%s must meet the catalog floor" % difficulty)
		for index in range(emitters.size()):
			var bullet_family := String(emitters[index].get("bullet_family", ""))
			if bullet_family.is_empty():
				errors.append("emitters[%d].bullet_family is required" % index)
			var metadata = bullet_family_metadata.get(bullet_family, {})
			if not (metadata is Dictionary) or metadata.is_empty():
				errors.append("emitters[%d].bullet_family must resolve in GameDatabase" % index)
			elif String(metadata.get("id", "")) != bullet_family or typeof(metadata.get("color")) != TYPE_COLOR:
				errors.append("emitters[%d].bullet_family metadata must retain its ID and Color" % index)
			if String(emitters[index].get("visible_warning", "")).is_empty():
				errors.append("emitters[%d].visible_warning is required" % index)
			var schedule = emitters[index].get("schedule", {})
			if not (schedule is Dictionary) or schedule.is_empty():
				errors.append("emitters[%d].schedule is required for an M1 pattern" % index)
				continue
			if int(schedule.get("start_frame", -1)) < 0:
				errors.append("emitters[%d].schedule.start_frame must be non-negative" % index)
			if int(schedule.get("interval_frames", 0)) <= 0:
				errors.append("emitters[%d].schedule.interval_frames must be positive" % index)
			if int(schedule.get("loop_frames", 0)) <= 0:
				errors.append("emitters[%d].schedule.loop_frames must be positive" % index)
			if int(schedule.get("bursts_per_loop", 0)) <= 0 or int(schedule.get("shots_per_burst", 0)) <= 0:
				errors.append("emitters[%d].schedule burst and shot counts must be positive" % index)
		var previous_frame := -1
		for index in range(ordered_timeline.size()):
			var event_frame := int(ordered_timeline[index].get("frame", -1))
			if event_frame < 0 or event_frame < previous_frame:
				errors.append("ordered_timeline must remain in non-negative authored frame order")
			previous_frame = event_frame
		for index in range(boss_movement.size()):
			var movement := boss_movement[index]
			if not (movement.get("from", []) is Array) or movement.get("from", []).size() != 2:
				errors.append("boss_movement[%d].from must be a two-coordinate point" % index)
			if not (movement.get("to", []) is Array) or movement.get("to", []).size() != 2:
				errors.append("boss_movement[%d].to must be a two-coordinate point" % index)
			if int(movement.get("duration_frames", 0)) <= 0:
				errors.append("boss_movement[%d].duration_frames must be positive" % index)
		var motion_roles := {}
		for index in range(bullet_motion_rules.size()):
			var rule := bullet_motion_rules[index]
			for key in ["primitive", "applies_to", "rule", "visible_warning"]:
				if String(rule.get(key, "")).is_empty():
					errors.append("bullet_motion_rules[%d].%s is required" % [index, key])
			motion_roles["%s:%s" % [rule.get("primitive", ""), rule.get("applies_to", "")]] = true
		for index in range(emitters.size()):
			var emitter := emitters[index]
			var motion_key := "%s:%s" % [emitter.get("primitive", ""), emitter.get("composition_role", "")]
			if not motion_roles.has(motion_key):
				errors.append("emitters[%d] has no matching primitive/role bullet motion rule" % index)
	return errors

func is_valid() -> bool:
	return validation_errors().is_empty()

func is_m1_contract() -> bool:
	return not deterministic_random_stream_id.is_empty() or not ordered_timeline.is_empty()

func has_authored_hard_topology_change() -> bool:
	return (
		not String(hard_topology_change.get("type", "")).is_empty()
		and not String(hard_topology_change.get("graph_change", "")).is_empty()
	)

func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"id": id,
		"duration_ticks": duration_ticks,
		"emitters": emitters.duplicate(true),
		"tags": tags.duplicate(),
		"deterministic_random_stream_id": deterministic_random_stream_id,
		"timeline": ordered_timeline.duplicate(true),
		"bullet_motion_rules": bullet_motion_rules.duplicate(true),
		"boss_movement": boss_movement.duplicate(true),
		"normal_structure": normal_structure.duplicate(true),
		"hard_topology_change": hard_topology_change.duplicate(true),
		"warning_contract": warning_contract.duplicate(true),
		"warning_floor": warning_floor.duplicate(true),
		"bullet_family_metadata": bullet_family_metadata.duplicate(true),
		"bullet_metadata_source": bullet_metadata_source,
	}

func _dictionary_copy(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}
