extends RefCounted

const VERSION := 1
const KINDS := ["nonspell", "spell"]

var id: String = ""
var display_name: String = ""
var kind: String = "nonspell"
var hit_points: float = 0.0
var timeout_ticks: int = 0
var pattern_id: String = ""
var next_phase_id: String = ""

# Optional M1 content-contract identity and authored structure. The original
# version-1 fields above remain unchanged for current callers.
var stage_index: int = 0
var source_identity: Dictionary = {}
var owner: Dictionary = {}
var encounter_role: String = ""
var encounter_slot: String = ""
var deterministic_random_stream_id: String = ""
var emitters: Array[Dictionary] = []
var timeline: Array[Dictionary] = []
var bullet_motion_rules: Array[Dictionary] = []
var boss_movement: Array[Dictionary] = []
var normal_structure: Dictionary = {}
var hard_topology_change: Dictionary = {}
var score_route: Dictionary = {}
var capture_condition: String = ""
var failure_condition: String = ""
var warning_contract: Dictionary = {}
var structure_fingerprint_input: Dictionary = {}
var structure_fingerprint: String = ""
var source_structure_fingerprint: String = ""
var pattern_definition: Object = null

func _init(values: Dictionary = {}) -> void:
	configure(values)

func configure(values: Dictionary) -> void:
	id = String(values.get("id", id))
	display_name = String(values.get("display_name", display_name))
	kind = String(values.get("kind", kind))
	hit_points = float(values.get("hit_points", hit_points))
	timeout_ticks = int(values.get("timeout_ticks", timeout_ticks))
	pattern_id = String(values.get("pattern_id", pattern_id))
	next_phase_id = String(values.get("next_phase_id", next_phase_id))
	stage_index = int(values.get("stage_index", 0))
	source_identity = _dictionary_copy(values.get("source_identity", {}))
	owner = _dictionary_copy(values.get("owner", {}))
	encounter_role = String(values.get("encounter_role", ""))
	encounter_slot = String(values.get("encounter_slot", source_identity.get("encounter_slot", "")))
	deterministic_random_stream_id = String(values.get("deterministic_random_stream_id", ""))
	emitters = _dictionary_array_copy(values.get("emitters", []))
	timeline = _dictionary_array_copy(values.get("timeline", []))
	bullet_motion_rules = _dictionary_array_copy(values.get("bullet_motion_rules", []))
	boss_movement = _dictionary_array_copy(values.get("boss_movement", []))
	normal_structure = _dictionary_copy(values.get("normal_structure", {}))
	hard_topology_change = _dictionary_copy(values.get("hard_topology_change", {}))
	score_route = _dictionary_copy(values.get("score_route", {}))
	capture_condition = String(values.get("capture_condition", ""))
	failure_condition = String(values.get("failure_condition", ""))
	warning_contract = _dictionary_copy(values.get("telegraph_frames", values.get("warning_contract", {})))
	structure_fingerprint_input = _dictionary_copy(values.get("structure_fingerprint_input", {}))
	structure_fingerprint = String(values.get("structure_fingerprint", ""))
	source_structure_fingerprint = String(values.get("source_structure_fingerprint", ""))
	pattern_definition = null

func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("id is required")
	if display_name.is_empty():
		errors.append("display_name is required")
	if kind not in KINDS:
		errors.append("kind must be nonspell or spell")
	if is_m1_contract():
		_validate_m1(errors)
	else:
		if hit_points <= 0.0:
			errors.append("hit_points must be positive")
		if timeout_ticks <= 0:
			errors.append("timeout_ticks must be positive")
		if pattern_id.is_empty():
			errors.append("pattern_id is required")
	return errors

func is_valid() -> bool:
	return validation_errors().is_empty()

func is_m1_contract() -> bool:
	return not deterministic_random_stream_id.is_empty() or not structure_fingerprint_input.is_empty()

func has_authored_hard_topology_change() -> bool:
	return (
		not String(hard_topology_change.get("type", "")).is_empty()
		and not String(hard_topology_change.get("graph_change", "")).is_empty()
		and String(structure_fingerprint_input.get("normal_topology", ""))
			!= String(structure_fingerprint_input.get("hard_transformation", ""))
	)

func recompute_structure_fingerprint() -> String:
	return canonical_structure_fingerprint(structure_fingerprint_input)

func derive_local_seed(run_seed: int) -> int:
	return derive_phase_local_seed(run_seed, deterministic_random_stream_id)

func attach_pattern_definition(definition: Object) -> void:
	pattern_definition = definition

static func derive_phase_local_seed(run_seed: int, stream_id: String) -> int:
	if stream_id.is_empty():
		return 0
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return 0
	var seed_material := "m1-phase-local-seed-v1|%d|%s" % [run_seed, stream_id]
	if context.update(seed_material.to_utf8_buffer()) != OK:
		return 0
	var digest := context.finish()
	var derived: int = 0
	for index in range(8):
		var byte_value := int(digest[index])
		if index == 0:
			byte_value &= 0x7f
		derived = (derived << 8) | byte_value
	return derived if derived != 0 else 1

static func canonical_structure_fingerprint(values: Dictionary) -> String:
	var emitter_parts := PackedStringArray()
	for value in values.get("emitter_composition", []):
		emitter_parts.append(String(value))
	var event_parts := PackedStringArray()
	for value in values.get("ordered_events", []):
		event_parts.append(String(value))
	return "%s|E:%s|T:%s|M:%s|N:%s|H:%s|W:%s" % [
		String(values.get("grammar", "")),
		">".join(emitter_parts),
		">".join(event_parts),
		String(values.get("movement_graph", "")),
		String(values.get("normal_topology", "")),
		String(values.get("hard_transformation", "")),
		String(values.get("warning_contract", "")),
	]

# Frozen m1-phase-cards-v1 predates emitter serialization in its display
# fingerprint. It is retained only to validate that immutable source artifact;
# runtime consumers receive canonical_structure_fingerprint() above.
static func legacy_source_fingerprint(values: Dictionary) -> String:
	var event_parts := PackedStringArray()
	for value in values.get("ordered_events", []):
		event_parts.append(String(value))
	return "%s|%s|%s|N:%s|H:%s|W:%s" % [
		String(values.get("grammar", "")),
		">".join(event_parts),
		String(values.get("movement_graph", "")),
		String(values.get("normal_topology", "")),
		String(values.get("hard_transformation", "")),
		String(values.get("warning_contract", "")),
	]

func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"id": id,
		"display_name": display_name,
		"kind": kind,
		"hit_points": hit_points,
		"timeout_ticks": timeout_ticks,
		"pattern_id": pattern_id,
		"next_phase_id": next_phase_id,
		"stage_index": stage_index,
		"source_identity": source_identity.duplicate(true),
		"owner": owner.duplicate(true),
		"encounter_role": encounter_role,
		"encounter_slot": encounter_slot,
		"deterministic_random_stream_id": deterministic_random_stream_id,
		"emitters": emitters.duplicate(true),
		"timeline": timeline.duplicate(true),
		"bullet_motion_rules": bullet_motion_rules.duplicate(true),
		"boss_movement": boss_movement.duplicate(true),
		"normal_structure": normal_structure.duplicate(true),
		"hard_topology_change": hard_topology_change.duplicate(true),
		"score_route": score_route.duplicate(true),
		"capture_condition": capture_condition,
		"failure_condition": failure_condition,
		"warning_contract": warning_contract.duplicate(true),
		"structure_fingerprint_input": structure_fingerprint_input.duplicate(true),
		"structure_fingerprint": structure_fingerprint,
		"source_structure_fingerprint": source_structure_fingerprint,
	}

func _validate_m1(errors: Array[String]) -> void:
	if stage_index < 1 or stage_index > 6:
		errors.append("stage_index must be in the M1 range 1..6")
	if String(owner.get("id", "")).is_empty():
		errors.append("owner.id is required for an M1 phase")
	if encounter_role not in ["midboss", "boss"]:
		errors.append("encounter_role must be midboss or boss")
	if encounter_slot.is_empty():
		errors.append("encounter_slot is required for an M1 phase")
	if deterministic_random_stream_id.is_empty():
		errors.append("deterministic_random_stream_id is required for an M1 phase")
	if emitters.is_empty():
		errors.append("emitters are required for an M1 phase")
	if timeline.size() != 4:
		errors.append("M1 phase timeline must contain exactly four ordered events")
	if boss_movement.size() != 3:
		errors.append("M1 phase boss_movement must contain exactly three entries")
	if bullet_motion_rules.is_empty():
		errors.append("bullet_motion_rules are required for an M1 phase")
	if normal_structure.is_empty():
		errors.append("normal_structure is required for an M1 phase")
	if not has_authored_hard_topology_change():
		errors.append("Hard must define a non-numeric topology transformation")
	if capture_condition.is_empty():
		errors.append("capture_condition is required for an M1 phase")
	if failure_condition.is_empty():
		errors.append("failure_condition is required for an M1 phase")
	if int(warning_contract.get("normal", 0)) <= 0 or int(warning_contract.get("hard", 0)) <= 0:
		errors.append("Normal and Hard warning frames are required")
	for key in [
		"grammar",
		"emitter_composition",
		"ordered_events",
		"movement_graph",
		"normal_topology",
		"hard_transformation",
		"warning_contract",
	]:
		if not structure_fingerprint_input.has(key):
			errors.append("structure_fingerprint_input.%s is required" % key)
	for key in ["grammar", "movement_graph", "normal_topology", "hard_transformation", "warning_contract"]:
		if String(structure_fingerprint_input.get(key, "")).is_empty():
			errors.append("structure_fingerprint_input.%s must not be empty" % key)
	if structure_fingerprint_input.get("emitter_composition", []).is_empty():
		errors.append("structure_fingerprint_input.emitter_composition must not be empty")
	if structure_fingerprint_input.get("ordered_events", []).size() != 4:
		errors.append("structure_fingerprint_input.ordered_events must contain four entries")
	for key in ["grammar", "movement_graph", "normal_topology", "hard_transformation", "warning_contract"]:
		var scalar := String(structure_fingerprint_input.get(key, ""))
		if not _is_ascii_nfc_machine_text(scalar) or scalar.contains("|"):
			errors.append("structure_fingerprint_input.%s must be unambiguous ASCII/NFC machine text" % key)
	for value in structure_fingerprint_input.get("emitter_composition", []):
		if not _is_ascii_nfc_machine_text(String(value)) or String(value).contains("|") or String(value).contains(">"):
			errors.append("emitter composition values must be unambiguous ASCII/NFC machine text")
	for value in structure_fingerprint_input.get("ordered_events", []):
		if not _is_ascii_nfc_machine_text(String(value)) or String(value).contains("|") or String(value).contains(">"):
			errors.append("ordered event values must be unambiguous ASCII/NFC machine text")
	if structure_fingerprint != recompute_structure_fingerprint():
		errors.append("structure_fingerprint drifted from canonical M1 input")
	if pattern_definition != null and pattern_definition.has_method("is_valid") and not pattern_definition.is_valid():
		errors.append("attached PatternDefinition is invalid")

func _dictionary_copy(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

func _dictionary_array_copy(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry in value:
			if entry is Dictionary:
				result.append(entry.duplicate(true))
	return result

func _is_ascii_nfc_machine_text(value: String) -> bool:
	if value.is_empty():
		return false
	for index in range(value.length()):
		if value.unicode_at(index) > 0x7f:
			return false
	return true
