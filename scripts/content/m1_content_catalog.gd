extends RefCounted
class_name M1ContentCatalog

const StageTimeline := preload("res://scripts/content/stage_timeline.gd")
const PatternDefinition := preload("res://scripts/content/pattern_definition.gd")
const BossPhaseDefinition := preload("res://scripts/content/boss_phase_definition.gd")

const STAGE_SOURCE_PATH := "res://content/design/m1_stage_beats.json"
const PHASE_SOURCE_PATH := "res://content/design/m1_phase_cards.json"
const STAGE_SCHEMA := "m1-stage-beats-v1"
const PHASE_SCHEMA := "m1-phase-cards-v1"
const EXPECTED_STAGE_COUNT := 6
const EXPECTED_BEAT_COUNT := 108
const EXPECTED_PHASE_COUNT := 40
const EXPECTED_SPELL_COUNT := 26
const EXPECTED_NONSPELL_COUNT := 14
const EXPECTED_SEGMENTS_PER_STAGE := 3
const PRODUCT_WARNING_MINIMUM := {"normal": 12, "hard": 8}
const AUTHORED_WARNING_MINIMUM := {"normal": 18, "hard": 12}

var _load_errors: Array[String] = []
var _stage_timelines: Array = []
var _stage_by_index: Dictionary = {}
var _stage_by_id: Dictionary = {}
var _phase_definitions: Array = []
var _phase_by_id: Dictionary = {}

func _init() -> void:
	_load_frozen_contracts()

func is_valid() -> bool:
	return _load_errors.is_empty()

func validation_errors() -> Array[String]:
	return _load_errors.duplicate()

func stage_count() -> int:
	return _stage_timelines.size()

func beat_count() -> int:
	var total := 0
	for timeline in _stage_timelines:
		total += timeline.beat_count()
	return total

func phase_count() -> int:
	return _phase_definitions.size()

func stage_timelines() -> Array:
	return _stage_timelines.duplicate()

func phase_definitions() -> Array:
	return _phase_definitions.duplicate()

func stage_timeline(stage_index: int):
	return _stage_by_index.get(stage_index)

func stage_timeline_by_id(stage_id: String):
	return _stage_by_id.get(stage_id)

func phase_definition(phase_id: String):
	return _phase_by_id.get(phase_id)

func phase_definitions_for_stage(stage_index: int, encounter_role: String = "") -> Array:
	var result: Array = []
	for phase in _phase_definitions:
		if phase.stage_index != stage_index:
			continue
		if not encounter_role.is_empty() and phase.encounter_role != encounter_role:
			continue
		result.append(phase)
	return result

func phase_local_seed(run_seed: int, phase_id: String) -> int:
	var phase = phase_definition(phase_id)
	return 0 if phase == null else phase.derive_local_seed(run_seed)

func stream_local_seed(run_seed: int, deterministic_stream_id: String) -> int:
	return BossPhaseDefinition.derive_phase_local_seed(run_seed, deterministic_stream_id)

func canonical_structure_fingerprint(values: Dictionary) -> String:
	return BossPhaseDefinition.canonical_structure_fingerprint(values)

func reload_from_roots(
	stage_root: Variant,
	phase_root: Variant,
	legacy_content: Object = null,
	game_database: Object = null
) -> void:
	_reset_catalog()
	var resolved_legacy = legacy_content if legacy_content != null else _legacy_content_database()
	var resolved_game_database = game_database if game_database != null else _game_database()
	_load_contract_roots(stage_root, phase_root, resolved_legacy, resolved_game_database)

func _load_frozen_contracts() -> void:
	var stage_root = _load_json_root(STAGE_SOURCE_PATH, "stage beats")
	var phase_root = _load_json_root(PHASE_SOURCE_PATH, "phase cards")
	_load_contract_roots(stage_root, phase_root, _legacy_content_database(), _game_database())

func _load_contract_roots(
	stage_root: Variant,
	phase_root: Variant,
	legacy_content: Object,
	game_database: Object
) -> void:
	var roots_valid := true
	if not (stage_root is Dictionary):
		_load_errors.append("stage beats root must be a non-empty Dictionary")
		roots_valid = false
	elif stage_root.is_empty():
		_load_errors.append("stage beats root must not be empty")
		roots_valid = false
	if not (phase_root is Dictionary):
		_load_errors.append("phase cards root must be a non-empty Dictionary")
		roots_valid = false
	elif phase_root.is_empty():
		_load_errors.append("phase cards root must not be empty")
		roots_valid = false
	if legacy_content == null or not legacy_content.has_method("midboss_definition") or not legacy_content.has_method("boss_definition"):
		_load_errors.append("legacy stage content resolver is required")
		roots_valid = false
	if game_database == null or not game_database.has_method("bullet_family_by_id"):
		_load_errors.append("GameDatabase bullet-family resolver is required")
		roots_valid = false
	if not roots_valid:
		return
	var stage_values: Dictionary = stage_root
	var phase_values: Dictionary = phase_root
	if String(stage_values.get("schema_version", "")) != STAGE_SCHEMA:
		_load_errors.append("stage beats schema_version must be %s" % STAGE_SCHEMA)
	if String(phase_values.get("schema_version", "")) != PHASE_SCHEMA:
		_load_errors.append("phase cards schema_version must be %s" % PHASE_SCHEMA)
	if int(stage_values.get("simulation_hz", 0)) != 60 or int(phase_values.get("simulation_hz", 0)) != 60:
		_load_errors.append("M1 frozen sources must use the 60 Hz simulation clock")
	_validate_difficulty_scope(stage_values, "stage beats")
	_validate_difficulty_scope(phase_values, "phase cards")
	if int(phase_values.get("phase_count", -1)) != EXPECTED_PHASE_COUNT:
		_load_errors.append("phase cards phase_count must remain exactly %d" % EXPECTED_PHASE_COUNT)
	_load_stages(stage_values)
	_load_phases(phase_values, legacy_content, game_database)
	_validate_catalog_totals(phase_values)

func _load_json_root(path: String, label: String) -> Variant:
	if not FileAccess.file_exists(path):
		_load_errors.append("Missing frozen %s source: %s" % [label, path])
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		_load_errors.append("Frozen %s source is not a JSON object: %s" % [label, path])
		return null
	return parsed

func _legacy_content_database() -> Object:
	var script = load("res://scripts/data/stage_content_database.gd")
	return null if script == null else script.new()

func _game_database() -> Object:
	var script = load("res://scripts/data/game_database.gd")
	return null if script == null else script.new()

func _reset_catalog() -> void:
	_load_errors.clear()
	_stage_timelines.clear()
	_stage_by_index.clear()
	_stage_by_id.clear()
	_phase_definitions.clear()
	_phase_by_id.clear()

func _load_stages(root: Dictionary) -> void:
	var source_stages = root.get("stages", [])
	if not (source_stages is Array):
		_load_errors.append("stage beats stages must be an Array")
		return
	if source_stages.size() != EXPECTED_STAGE_COUNT:
		_load_errors.append("M1 must contain exactly %d stages" % EXPECTED_STAGE_COUNT)
	var seen_ids := {}
	var seen_beat_ids := {}
	for source_index in range(source_stages.size()):
		var source = source_stages[source_index]
		if not (source is Dictionary):
			_load_errors.append("stages[%d] must be a Dictionary" % source_index)
			continue
		var stage_context := "stages[%d]" % source_index
		_validate_array_field(source, "segments", stage_context)
		_validate_array_field(source, "beats", stage_context)
		_validate_dictionary_field(source, "midboss", stage_context)
		_validate_dictionary_field(source, "preboss_climax", stage_context)
		_validate_dictionary_field(source, "score_route", stage_context)
		var source_segments = source.get("segments", [])
		if source_segments is Array:
			for segment_index in range(source_segments.size()):
				if not (source_segments[segment_index] is Dictionary):
					_load_errors.append("%s.segments[%d] must be a Dictionary" % [stage_context, segment_index])
		var source_beats = source.get("beats", [])
		if source_beats is Array:
			for beat_index in range(source_beats.size()):
				if not (source_beats[beat_index] is Dictionary):
					_load_errors.append("%s.beats[%d] must be a Dictionary" % [stage_context, beat_index])
		var timeline = StageTimeline.new()
		timeline.configure_m1(source)
		for error in timeline.validation_errors():
			_load_errors.append("stage %d: %s" % [source_index + 1, error])
		var expected_index := source_index + 1
		if timeline.stage_index != expected_index:
			_load_errors.append("stages[%d] must retain authored stage_index %d" % [source_index, expected_index])
		if seen_ids.has(timeline.stage_id):
			_load_errors.append("duplicate stage_id: %s" % timeline.stage_id)
		seen_ids[timeline.stage_id] = true
		if timeline.beat_count() != 18:
			_load_errors.append("stage %d must contain exactly 18 beats" % expected_index)
		if timeline.segment_count() != EXPECTED_SEGMENTS_PER_STAGE:
			_load_errors.append("stage %d must contain exactly three segments" % expected_index)
		_validate_stage_choreography(timeline, seen_beat_ids)
		_stage_timelines.append(timeline)
		_stage_by_index[timeline.stage_index] = timeline
		_stage_by_id[timeline.stage_id] = timeline

func _validate_stage_choreography(timeline, seen_beat_ids: Dictionary) -> void:
	var segment_ids := {}
	for segment in timeline.segments:
		var segment_id := String(segment.get("id", ""))
		segment_ids[segment_id] = true
		if timeline.beats_for_segment(segment_id).size() != 6:
			_load_errors.append("stage %d segment %s must contain exactly six beats" % [timeline.stage_index, segment_id])
	for event in timeline.events:
		var beat_id := String(event.get("id", ""))
		if seen_beat_ids.has(beat_id):
			_load_errors.append("duplicate beat id: %s" % beat_id)
		seen_beat_ids[beat_id] = true
		var payload: Dictionary = event.get("payload", {})
		if not segment_ids.has(String(payload.get("segment", ""))):
			_load_errors.append("beat %s is not grouped into an authored segment" % beat_id)
		if String(event.get("kind", "")) != "transition" and int(payload.get("max_gap_after_frames", 999999)) > 180:
			_load_errors.append("beat %s exceeds the 180-frame non-transition gap limit" % beat_id)
	if not bool(timeline.midboss.get("fought", false)):
		_load_errors.append("stage %d must contain a fought midboss" % timeline.stage_index)
	if not bool(timeline.preboss_climax.get("boss_front", false)):
		_load_errors.append("stage %d must contain a boss-front climax" % timeline.stage_index)
	var climax_id := String(timeline.preboss_climax.get("beat_id", ""))
	var climax_found := false
	for event in timeline.events:
		if String(event.get("id", "")) == climax_id and String(event.get("kind", "")) == "climax":
			climax_found = true
			break
	if not climax_found:
		_load_errors.append("stage %d boss-front climax must reference its climax beat" % timeline.stage_index)

func _load_phases(root: Dictionary, legacy_content: Object, game_database: Object) -> void:
	var source_phases = root.get("phases", [])
	if not (source_phases is Array):
		_load_errors.append("phase cards phases must be an Array")
		return
	if source_phases.size() != EXPECTED_PHASE_COUNT:
		_load_errors.append("M1 must contain exactly %d phases" % EXPECTED_PHASE_COUNT)
	var seen_ids := {}
	var seen_streams := {}
	var seen_fingerprints := {}
	var seen_legacy_bindings := {}
	var previous_stage_index := 0
	var role_counts_by_stage := {}
	for source_index in range(source_phases.size()):
		var source = source_phases[source_index]
		if not (source is Dictionary):
			_load_errors.append("phases[%d] must be a Dictionary" % source_index)
			continue
		var phase_context := "phases[%d]" % source_index
		for key in ["emitters", "timeline", "bullet_motion_rules", "boss_movement"]:
			_validate_array_field(source, key, phase_context)
		for key in [
			"source_identity",
			"owner",
			"normal_structure",
			"hard_topology_change",
			"score_route",
			"telegraph_frames",
			"structure_fingerprint_input",
		]:
			_validate_dictionary_field(source, key, phase_context)
		var values: Dictionary = source.duplicate(true)
		var fingerprint_input: Dictionary = _dictionary_copy(source.get("structure_fingerprint_input", {}))
		var source_fingerprint := String(source.get("structure_fingerprint", ""))
		if source_fingerprint != BossPhaseDefinition.legacy_source_fingerprint(fingerprint_input):
			_load_errors.append("phase %s frozen v1 source fingerprint drifted" % String(source.get("id", "")))
		var canonical_fingerprint := BossPhaseDefinition.canonical_structure_fingerprint(fingerprint_input)
		values["source_structure_fingerprint"] = source_fingerprint
		values["structure_fingerprint"] = canonical_fingerprint
		var legacy_binding := _resolve_legacy_card_binding(source, legacy_content)
		values["legacy_card_binding"] = legacy_binding
		values["hit_points"] = float(legacy_binding.get("hit_points", 0.0))
		values["timeout_ticks"] = int(legacy_binding.get("timeout_seconds", 0)) * 60
		values["pattern_id"] = String(source.get("id", ""))
		values["dialogue_hook_id"] = BossPhaseDefinition.expected_dialogue_hook_id(String(source.get("id", "")))
		values["performance_hook_id"] = BossPhaseDefinition.expected_performance_hook_id(String(source.get("id", "")))
		var phase = BossPhaseDefinition.new(values)
		var pattern := _build_pattern_definition(source, game_database)
		phase.attach_pattern_definition(pattern)
		for error in phase.validation_errors():
			_load_errors.append("phase %s: %s" % [phase.id, error])
		_validate_phase_order_and_identity(phase, source_index, previous_stage_index, role_counts_by_stage)
		previous_stage_index = phase.stage_index
		_validate_emitter_fingerprint_input(phase)
		_validate_warning_contract(phase)
		_register_unique("phase id", phase.id, seen_ids)
		_register_unique("deterministic stream", phase.deterministic_random_stream_id, seen_streams)
		_register_unique("canonical structure fingerprint", phase.structure_fingerprint, seen_fingerprints)
		_register_unique("legacy card binding", _legacy_binding_key(legacy_binding), seen_legacy_bindings)
		_phase_definitions.append(phase)
		_phase_by_id[phase.id] = phase
	if seen_legacy_bindings.size() != EXPECTED_PHASE_COUNT:
		_load_errors.append("all 40 M1 phases must map one-to-one onto legacy encounter cards")

func _build_pattern_definition(source: Dictionary, game_database: Object):
	var normal: Dictionary = _dictionary_copy(source.get("normal_structure", {}))
	var source_emitters := _dictionary_array_copy(source.get("emitters", []))
	var bullet_family_metadata := {}
	for emitter in source_emitters:
		var bullet_family := String(emitter.get("bullet_family", ""))
		if bullet_family.is_empty() or bullet_family_metadata.has(bullet_family):
			continue
		var metadata: Dictionary = game_database.bullet_family_by_id(bullet_family)
		if not metadata.is_empty():
			bullet_family_metadata[bullet_family] = metadata
	var values := {
		"id": String(source.get("id", "")),
		"duration_ticks": int(normal.get("loop_frames", 0)),
		"emitters": source_emitters,
		"tags": [String(source.get("encounter_role", "")), String(source.get("kind", "")), "m1_contract"],
		"deterministic_random_stream_id": String(source.get("deterministic_random_stream_id", "")),
		"timeline": _dictionary_array_copy(source.get("timeline", [])),
		"bullet_motion_rules": _dictionary_array_copy(source.get("bullet_motion_rules", [])),
		"boss_movement": _dictionary_array_copy(source.get("boss_movement", [])),
		"normal_structure": normal,
		"hard_topology_change": _dictionary_copy(source.get("hard_topology_change", {})),
		"telegraph_frames": _dictionary_copy(source.get("telegraph_frames", {})),
		"warning_floor": PRODUCT_WARNING_MINIMUM.duplicate(true),
		"bullet_family_metadata": bullet_family_metadata,
		"bullet_metadata_source": "GameDatabase.bullet_family_by_id",
	}
	return PatternDefinition.new(values)

func _validate_phase_order_and_identity(
	phase,
	source_index: int,
	previous_stage_index: int,
	role_counts_by_stage: Dictionary
) -> void:
	if phase.stage_index < previous_stage_index:
		_load_errors.append("phase %s breaks authored stage encounter order" % phase.id)
	var stage = stage_timeline(phase.stage_index)
	if stage == null:
		_load_errors.append("phase %s references unknown stage %d" % [phase.id, phase.stage_index])
		return
	var role_key := "%d:%s" % [phase.stage_index, phase.encounter_role]
	var role_ordinal := int(role_counts_by_stage.get(role_key, 0)) + 1
	role_counts_by_stage[role_key] = role_ordinal
	var expected_slot := "%s_card_%d" % [phase.encounter_role, role_ordinal]
	if phase.encounter_slot != expected_slot:
		_load_errors.append("phase %s encounter slot must be %s at source index %d" % [phase.id, expected_slot, source_index])
	var expected_owner := stage.midboss_id if phase.encounter_role == "midboss" else stage.boss_id
	if String(phase.owner.get("id", "")) != expected_owner:
		_load_errors.append("phase %s owner does not match its stage encounter role" % phase.id)
	if String(phase.source_identity.get("source_owner_id", "")) != expected_owner:
		_load_errors.append("phase %s source owner does not match its encounter mapping" % phase.id)

func _validate_emitter_fingerprint_input(phase) -> void:
	var actual := PackedStringArray()
	for emitter in phase.emitters:
		actual.append("%s:%s" % [
			String(emitter.get("primitive", "")),
			String(emitter.get("composition_role", "")),
		])
	var frozen := PackedStringArray()
	var frozen_entries = phase.structure_fingerprint_input.get("emitter_composition", [])
	if frozen_entries is Array:
		for entry in frozen_entries:
			frozen.append(String(entry))
	if actual != frozen:
		_load_errors.append("phase %s role-qualified emitter composition drifted" % phase.id)

func _validate_warning_contract(phase) -> void:
	var normal_frames := int(phase.warning_contract.get("normal", 0))
	var hard_frames := int(phase.warning_contract.get("hard", 0))
	if normal_frames < int(PRODUCT_WARNING_MINIMUM.normal):
		_load_errors.append("phase %s violates the Normal warning product floor" % phase.id)
	if hard_frames < int(PRODUCT_WARNING_MINIMUM.hard):
		_load_errors.append("phase %s violates the Hard warning product floor" % phase.id)

func _resolve_legacy_card_binding(source: Dictionary, legacy_content: Object) -> Dictionary:
	var phase_id := String(source.get("id", ""))
	var stage_index := int(source.get("stage_index", 0))
	var encounter_role := String(source.get("encounter_role", ""))
	var source_identity := _dictionary_copy(source.get("source_identity", {}))
	var encounter_slot := String(source_identity.get("encounter_slot", ""))
	var slot_parts := encounter_slot.split("_", false)
	if slot_parts.size() != 3 or String(slot_parts[0]) != encounter_role or String(slot_parts[1]) != "card":
		_load_errors.append("phase %s has an invalid legacy encounter slot" % phase_id)
		return {}
	var card_ordinal := int(slot_parts[2])
	if card_ordinal <= 0:
		_load_errors.append("phase %s legacy encounter slot must be one-based" % phase_id)
		return {}
	var encounter = (
		legacy_content.midboss_definition(stage_index)
		if encounter_role == "midboss"
		else legacy_content.boss_definition(stage_index)
	)
	if not (encounter is Dictionary):
		_load_errors.append("phase %s legacy encounter must resolve to a Dictionary" % phase_id)
		return {}
	var cards = encounter.get("cards", [])
	if not (cards is Array) or card_ordinal > cards.size():
		_load_errors.append("phase %s legacy encounter card is missing" % phase_id)
		return {}
	var card = cards[card_ordinal - 1]
	if not (card is Dictionary):
		_load_errors.append("phase %s legacy encounter card must be a Dictionary" % phase_id)
		return {}
	var legacy_pattern_id := String(source_identity.get("legacy_pattern_id", ""))
	if String(card.get("name", "")) != String(source.get("display_name", "")):
		_load_errors.append("phase %s display_name does not match its legacy card" % phase_id)
	if String(card.get("kind", "")) != String(source.get("kind", "")):
		_load_errors.append("phase %s kind does not match its legacy card" % phase_id)
	if String(card.get("pattern", "")) != legacy_pattern_id:
		_load_errors.append("phase %s legacy pattern alias drifted" % phase_id)
	if float(card.get("hp", 0.0)) <= 0.0 or int(card.get("time", 0)) <= 0:
		_load_errors.append("phase %s legacy HP/time must be positive" % phase_id)
	return {
		"stage_index": stage_index,
		"encounter_role": encounter_role,
		"encounter_slot": encounter_slot,
		"legacy_pattern_id": legacy_pattern_id,
		"display_name": String(card.get("name", "")),
		"kind": String(card.get("kind", "")),
		"hit_points": float(card.get("hp", 0.0)),
		"timeout_seconds": int(card.get("time", 0)),
	}

func _legacy_binding_key(binding: Dictionary) -> String:
	if binding.is_empty():
		return ""
	return "%d:%s:%s" % [
		int(binding.get("stage_index", 0)),
		String(binding.get("encounter_role", "")),
		String(binding.get("encounter_slot", "")),
	]

func _validate_catalog_totals(phase_root: Dictionary) -> void:
	if stage_count() != EXPECTED_STAGE_COUNT:
		_load_errors.append("loaded stage count must be %d" % EXPECTED_STAGE_COUNT)
	if beat_count() != EXPECTED_BEAT_COUNT:
		_load_errors.append("loaded beat count must be %d" % EXPECTED_BEAT_COUNT)
	if phase_count() != EXPECTED_PHASE_COUNT:
		_load_errors.append("loaded phase count must be %d" % EXPECTED_PHASE_COUNT)
	var spell_count := 0
	var nonspell_count := 0
	var minimum_normal := 999999
	var minimum_hard := 999999
	for phase in _phase_definitions:
		if phase.kind == "spell":
			spell_count += 1
		elif phase.kind == "nonspell":
			nonspell_count += 1
		minimum_normal = mini(minimum_normal, int(phase.warning_contract.get("normal", 0)))
		minimum_hard = mini(minimum_hard, int(phase.warning_contract.get("hard", 0)))
	if spell_count != EXPECTED_SPELL_COUNT or nonspell_count != EXPECTED_NONSPELL_COUNT:
		_load_errors.append("loaded phase split must be exactly 26 spell / 14 nonspell")
	var expected_split: Dictionary = _dictionary_copy(phase_root.get("expected_split", {}))
	if int(expected_split.get("spell", -1)) != spell_count or int(expected_split.get("nonspell", -1)) != nonspell_count:
		_load_errors.append("phase source expected_split drifted from authored phases")
	if minimum_normal != int(AUTHORED_WARNING_MINIMUM.normal) or minimum_hard != int(AUTHORED_WARNING_MINIMUM.hard):
		_load_errors.append("authored warning minima must remain exactly Normal 18 / Hard 12")

func _register_unique(label: String, value: String, seen: Dictionary) -> void:
	if value.is_empty():
		_load_errors.append("%s is required" % label)
	elif seen.has(value):
		_load_errors.append("duplicate %s: %s" % [label, value])
	seen[value] = true

func _validate_difficulty_scope(root: Dictionary, label: String) -> void:
	var scope = root.get("difficulty_scope", [])
	if not (scope is Array) or scope != ["Normal", "Hard"]:
		_load_errors.append("%s difficulty_scope must remain exactly Normal, Hard" % label)

func _validate_array_field(source: Dictionary, key: String, context: String) -> void:
	if not (source.get(key) is Array):
		_load_errors.append("%s.%s must be an Array" % [context, key])

func _validate_dictionary_field(source: Dictionary, key: String, context: String) -> void:
	if not (source.get(key) is Dictionary):
		_load_errors.append("%s.%s must be a Dictionary" % [context, key])

func _dictionary_copy(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

func _dictionary_array_copy(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry in value:
			if entry is Dictionary:
				result.append(entry.duplicate(true))
	return result
