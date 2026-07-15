extends SceneTree

const StageTimeline := preload("res://scripts/content/stage_timeline.gd")
const PatternDefinition := preload("res://scripts/content/pattern_definition.gd")
const BossPhaseDefinition := preload("res://scripts/content/boss_phase_definition.gd")
const DifficultyProfile := preload("res://scripts/content/difficulty_profile.gd")
const M1ContentCatalog := preload("res://scripts/content/m1_content_catalog.gd")
const StageDirector := preload("res://scripts/runtime/stage_director.gd")

const EXPECTED_STAGE_IDS := [
	"shrine_approach",
	"yokai_market",
	"mist_bamboo_grove",
	"tengu_mountain_path",
	"oni_banquet_hall",
	"night_festival_divine_realm",
]

const EXPECTED_PHASE_IDS := [
	"stage_1_midboss_nonspell_1",
	"stage_1_midboss_spell_1",
	"stage_1_boss_nonspell_1",
	"stage_1_boss_spell_1",
	"stage_1_boss_spell_2",
	"stage_1_boss_spell_3",
	"stage_2_midboss_nonspell_1",
	"stage_2_midboss_spell_1",
	"stage_2_boss_nonspell_1",
	"stage_2_boss_spell_1",
	"stage_2_boss_spell_2",
	"stage_2_boss_spell_3",
	"stage_3_midboss_nonspell_1",
	"stage_3_midboss_spell_1",
	"stage_3_boss_nonspell_1",
	"stage_3_boss_spell_1",
	"stage_3_boss_spell_2",
	"stage_3_boss_spell_3",
	"stage_4_midboss_nonspell_1",
	"stage_4_midboss_spell_1",
	"stage_4_boss_nonspell_1",
	"stage_4_boss_spell_1",
	"stage_4_boss_spell_2",
	"stage_4_boss_spell_3",
	"stage_5_midboss_nonspell_1",
	"stage_5_midboss_spell_1",
	"stage_5_boss_nonspell_1",
	"stage_5_boss_spell_1",
	"stage_5_boss_spell_2",
	"stage_5_boss_spell_3",
	"stage_5_boss_spell_4",
	"stage_5_boss_nonspell_2",
	"stage_6_midboss_nonspell_1",
	"stage_6_midboss_spell_1",
	"stage_6_boss_nonspell_1",
	"stage_6_boss_spell_1",
	"stage_6_boss_spell_2",
	"stage_6_boss_spell_3",
	"stage_6_boss_spell_4",
	"stage_6_boss_nonspell_2",
]

const EXPECTED_LEGACY_PATTERN_IDS := [
	"s1_lantern_nonspell",
	"s1_star_procession",
	"s1_lantern_nonspell",
	"s1_star_procession",
	"s1_fox_butterfly",
	"s1_boundary_finale",
	"s2_market_nonspell",
	"s2_coin_bubble",
	"s2_market_nonspell",
	"s2_coin_bubble",
	"s2_object_mist",
	"s2_abacus_mirror",
	"s3_mist_nonspell",
	"s3_bamboo_blade",
	"s3_mist_nonspell",
	"s3_bamboo_blade",
	"s3_memory_vortex",
	"s3_dark_path",
	"s4_wind_nonspell",
	"s4_newspaper_lattice",
	"s4_wind_nonspell",
	"s4_tengu_gale",
	"s4_newspaper_lattice",
	"s4_sky_report",
	"s5_rhythm_nonspell",
	"s5_drum_vortex",
	"s5_rhythm_nonspell",
	"s5_oni_fire",
	"s5_large_orb_spell",
	"s5_drum_vortex",
	"s5_banquet_darkness",
	"s5_rhythm_nonspell",
	"s6_faith_nonspell",
	"s6_final_lantern_spell",
	"s6_faith_nonspell",
	"s6_lantern_rain",
	"s6_final_lantern_spell",
	"s6_hyakki_gate",
	"s6_festival_darkness",
	"s6_faith_nonspell",
]

const EXPECTED_LEGACY_HP := [
	320, 420, 600, 900, 1300, 1600,
	420, 520, 900, 1300, 1800, 2400,
	520, 650, 1200, 1700, 2300, 3000,
	650, 820, 1600, 2200, 2700, 3300,
	780, 980, 1900, 2300, 2900, 3300, 3800, 2100,
	900, 1150, 2400, 3000, 3600, 4200, 5000, 2700,
]

const EXPECTED_LEGACY_SECONDS := [
	16, 18, 28, 32, 30, 25,
	17, 19, 28, 32, 30, 25,
	18, 20, 28, 30, 32, 28,
	18, 21, 29, 31, 31, 28,
	19, 22, 29, 31, 32, 31, 29, 24,
	20, 23, 30, 32, 34, 32, 30, 25,
]

var failed := false

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)

func _check_equal(actual, expected, message: String) -> void:
	_check(actual == expected, "%s Expected %s, got %s" % [message, expected, actual])

func _run() -> void:
	var catalog := M1ContentCatalog.new()
	_check(catalog.is_valid(), "The real M1 catalog was rejected: %s" % [catalog.validation_errors()])
	if not catalog.is_valid():
		quit(1)
		return

	_assert_stage_contracts(catalog)
	_assert_phase_contracts(catalog)
	_assert_phase_seed_contract(catalog)
	_assert_catalog_fail_closed_contracts()
	_assert_m0_constructor_compatibility()
	_assert_stage_director_queries(catalog)

	if failed:
		quit(1)
	else:
		print("PASS: M1 frozen content contracts expose 6 stages, 108 beats, and 40 deterministic phase definitions.")
		quit(0)

func _assert_stage_contracts(catalog) -> void:
	_check_equal(catalog.stage_count(), 6, "M1 stage count drifted.")
	_check_equal(catalog.beat_count(), 108, "M1 beat count drifted.")
	var timelines: Array = catalog.stage_timelines()
	var actual_stage_ids: Array[String] = []
	var fought_midbosses := 0
	var boss_front_climaxes := 0
	for timeline_index in range(timelines.size()):
		var timeline = timelines[timeline_index]
		actual_stage_ids.append(timeline.stage_id)
		_check_equal(timeline.stage_index, timeline_index + 1, "Stage authored order drifted.")
		_check_equal(timeline.segment_count(), 3, "Stage %d segment count drifted." % timeline.stage_index)
		_check_equal(timeline.beat_count(), 18, "Stage %d beat count drifted." % timeline.stage_index)
		_check(timeline.is_valid(), "Stage %d timeline is invalid: %s" % [timeline.stage_index, timeline.validation_errors()])
		for segment in timeline.segments:
			_check_equal(
				timeline.beats_for_segment(String(segment.get("id", ""))).size(),
				6,
				"Stage %d segment beat grouping drifted." % timeline.stage_index
			)
		_check(timeline.max_non_transition_gap() <= 180, "Stage %d exceeds the 180-frame combat gap limit." % timeline.stage_index)
		for key in ["decision", "reward", "risk", "evidence"]:
			_check(not String(timeline.score_route.get(key, "")).is_empty(), "Stage %d score_route.%s is missing." % [timeline.stage_index, key])
		if bool(timeline.midboss.get("fought", false)):
			fought_midbosses += 1
		if bool(timeline.preboss_climax.get("boss_front", false)):
			boss_front_climaxes += 1
	_check_equal(actual_stage_ids, EXPECTED_STAGE_IDS, "Stage identities/order drifted.")
	_check_equal(fought_midbosses, 6, "Every M1 stage must fight its midboss.")
	_check_equal(boss_front_climaxes, 6, "Every M1 stage must end its beats with a boss-front climax.")

func _assert_phase_contracts(catalog) -> void:
	_check_equal(catalog.phase_count(), 40, "M1 phase count drifted.")
	var phases: Array = catalog.phase_definitions()
	var actual_phase_ids: Array[String] = []
	var actual_legacy_ids: Array[String] = []
	var spell_count := 0
	var nonspell_count := 0
	var warning_normal := 999999
	var warning_hard := 999999
	var seen_fingerprints := {}
	var seen_streams := {}
	var seen_legacy_bindings := {}
	var seen_dialogue_hooks := {}
	var seen_performance_hooks := {}
	for phase_index in range(phases.size()):
		var phase = phases[phase_index]
		actual_phase_ids.append(phase.id)
		actual_legacy_ids.append(String(phase.source_identity.get("legacy_pattern_id", "")))
		if phase.kind == "spell":
			spell_count += 1
		elif phase.kind == "nonspell":
			nonspell_count += 1
		_check(phase.is_valid(), "Phase %s is invalid: %s" % [phase.id, phase.validation_errors()])
		_check(phase.pattern_definition != null and phase.pattern_definition.is_valid(), "Phase %s has no valid public PatternDefinition." % phase.id)
		_check_equal(phase.hit_points, float(EXPECTED_LEGACY_HP[phase_index]), "Phase %s legacy HP binding drifted." % phase.id)
		_check_equal(phase.timeout_ticks, int(EXPECTED_LEGACY_SECONDS[phase_index]) * 60, "Phase %s legacy timeout conversion drifted." % phase.id)
		_check_equal(phase.pattern_id, phase.id, "Phase %s pattern_id must identify its M1 PatternDefinition." % phase.id)
		_check_equal(phase.pattern_id, phase.pattern_definition.id, "Phase %s attached PatternDefinition identity drifted." % phase.id)
		var binding_key := "%d:%s:%s" % [phase.stage_index, phase.encounter_role, phase.encounter_slot]
		_check(not seen_legacy_bindings.has(binding_key), "Phase %s reused a legacy encounter card binding." % phase.id)
		seen_legacy_bindings[binding_key] = true
		_check_equal(float(phase.legacy_card_binding.get("hit_points", 0.0)), phase.hit_points, "Phase %s legacy binding HP drifted." % phase.id)
		_check_equal(int(phase.legacy_card_binding.get("timeout_seconds", 0)) * 60, phase.timeout_ticks, "Phase %s legacy binding seconds drifted." % phase.id)
		_check_equal(String(phase.legacy_card_binding.get("legacy_pattern_id", "")), EXPECTED_LEGACY_PATTERN_IDS[phase_index], "Phase %s legacy alias binding drifted." % phase.id)
		_check_equal(phase.timeline.size(), 4, "Phase %s ordered timeline length drifted." % phase.id)
		_check_equal(phase.boss_movement.size(), 3, "Phase %s Boss movement trace length drifted." % phase.id)
		_check(not phase.capture_condition.is_empty(), "Phase %s lacks capture conditions." % phase.id)
		_check(not phase.failure_condition.is_empty(), "Phase %s lacks failure conditions." % phase.id)
		for key in ["decision", "reward", "risk", "evidence"]:
			_check(not String(phase.score_route.get(key, "")).is_empty(), "Phase %s score_route.%s is missing." % [phase.id, key])
		_check_equal(phase.dialogue_hook_id, BossPhaseDefinition.expected_dialogue_hook_id(phase.id), "Phase %s dialogue hook drifted." % phase.id)
		_check_equal(phase.performance_hook_id, BossPhaseDefinition.expected_performance_hook_id(phase.id), "Phase %s performance hook drifted." % phase.id)
		_check(not seen_dialogue_hooks.has(phase.dialogue_hook_id), "Phase %s reused a dialogue hook." % phase.id)
		_check(not seen_performance_hooks.has(phase.performance_hook_id), "Phase %s reused a performance hook." % phase.id)
		seen_dialogue_hooks[phase.dialogue_hook_id] = true
		seen_performance_hooks[phase.performance_hook_id] = true
		_check(phase.has_authored_hard_topology_change(), "Phase %s Hard mode is not an authored topology change." % phase.id)
		_check(
			String(phase.hard_topology_change.get("type", "")) not in ["speed", "count", "speed_and_count"],
			"Phase %s Hard change may not be represented by numeric scaling." % phase.id
		)
		var hard := DifficultyProfile.new()
		hard.configure_for_phase("hard", phase.normal_structure, phase.hard_topology_change)
		_check(hard.is_valid() and hard.has_topology_change(), "Phase %s could not produce a Hard topology profile." % phase.id)
		warning_normal = mini(warning_normal, int(phase.warning_contract.get("normal", 0)))
		warning_hard = mini(warning_hard, int(phase.warning_contract.get("hard", 0)))
		_check(int(phase.warning_contract.get("normal", 0)) >= 12, "Phase %s violates the Normal warning floor." % phase.id)
		_check(int(phase.warning_contract.get("hard", 0)) >= 8, "Phase %s violates the Hard warning floor." % phase.id)
		_assert_pattern_contract(phase)
		var recomputed := BossPhaseDefinition.canonical_structure_fingerprint(phase.structure_fingerprint_input)
		_check_equal(phase.structure_fingerprint, recomputed, "Phase %s canonical fingerprint drifted." % phase.id)
		_check_equal(
			phase.source_structure_fingerprint,
			BossPhaseDefinition.legacy_source_fingerprint(phase.structure_fingerprint_input),
			"Phase %s immutable v1 source fingerprint drifted." % phase.id
		)
		_check(not seen_fingerprints.has(recomputed), "Phase %s duplicates a canonical structure fingerprint." % phase.id)
		seen_fingerprints[recomputed] = true
		_check(not seen_streams.has(phase.deterministic_random_stream_id), "Phase %s duplicates a deterministic stream ID." % phase.id)
		seen_streams[phase.deterministic_random_stream_id] = true
		var expected_role := "midboss" if phase.encounter_slot.begins_with("midboss_card_") else "boss"
		_check_equal(phase.encounter_role, expected_role, "Phase %s encounter role/slot mapping drifted." % phase.id)
		var round_trip := BossPhaseDefinition.new(phase.to_dict())
		round_trip.attach_pattern_definition(phase.pattern_definition)
		_check(round_trip.is_valid(), "Phase %s did not survive public definition round-trip: %s" % [phase.id, round_trip.validation_errors()])
		_check_equal(round_trip.dialogue_hook_id, phase.dialogue_hook_id, "Phase %s dialogue hook did not round-trip." % phase.id)
		_check_equal(round_trip.performance_hook_id, phase.performance_hook_id, "Phase %s performance hook did not round-trip." % phase.id)
		_check_equal(round_trip.score_route, phase.score_route, "Phase %s score route did not round-trip." % phase.id)
	_check_equal(actual_phase_ids, EXPECTED_PHASE_IDS, "Phase identities or encounter order drifted.")
	_check_equal(actual_legacy_ids, EXPECTED_LEGACY_PATTERN_IDS, "Legacy pattern encounter mapping drifted.")
	_check_equal(spell_count, 26, "M1 spell count drifted.")
	_check_equal(nonspell_count, 14, "M1 nonspell count drifted.")
	_check_equal(warning_normal, 18, "Authored Normal warning minimum drifted.")
	_check_equal(warning_hard, 12, "Authored Hard warning minimum drifted.")
	_check_equal(seen_fingerprints.size(), 40, "Canonical fingerprints are not unique across all phases.")
	_check_equal(seen_legacy_bindings.size(), 40, "Legacy encounter cards are not mapped one-to-one.")
	_check_equal(seen_dialogue_hooks.size(), 40, "Dialogue binding seams are not unique.")
	_check_equal(seen_performance_hooks.size(), 40, "Performance binding seams are not unique.")

func _assert_pattern_contract(phase) -> void:
	var pattern = phase.pattern_definition
	_check_equal(pattern.warning_floor, {"normal": 12, "hard": 8}, "Phase %s warning floor drifted." % phase.id)
	_check_equal(pattern.bullet_metadata_source, "GameDatabase.bullet_family_by_id", "Phase %s bullet metadata resolver drifted." % phase.id)
	for emitter_index in range(pattern.emitters.size()):
		var emitter: Dictionary = pattern.emitters[emitter_index]
		var family_id := String(emitter.get("bullet_family", ""))
		_check(not family_id.is_empty(), "Phase %s emitter %d lacks bullet_family." % [phase.id, emitter_index])
		_check(emitter.get("schedule") is Dictionary, "Phase %s emitter %d lacks a schedule Dictionary." % [phase.id, emitter_index])
		_check(not String(emitter.get("visible_warning", "")).is_empty(), "Phase %s emitter %d lacks visible_warning." % [phase.id, emitter_index])
		var metadata = pattern.bullet_family_metadata.get(family_id, {})
		_check(metadata is Dictionary and not metadata.is_empty(), "Phase %s emitter %d bullet family did not resolve." % [phase.id, emitter_index])
		if metadata is Dictionary:
			_check_equal(String(metadata.get("id", "")), family_id, "Phase %s emitter %d bullet metadata ID drifted." % [phase.id, emitter_index])
			_check_equal(typeof(metadata.get("color")), TYPE_COLOR, "Phase %s emitter %d bullet metadata lacks Color." % [phase.id, emitter_index])
	for rule_index in range(pattern.bullet_motion_rules.size()):
		var rule: Dictionary = pattern.bullet_motion_rules[rule_index]
		for key in ["primitive", "applies_to", "rule", "visible_warning"]:
			_check(not String(rule.get(key, "")).is_empty(), "Phase %s motion rule %d lacks %s." % [phase.id, rule_index, key])
	var pattern_round_trip := PatternDefinition.new(pattern.to_dict())
	_check(pattern_round_trip.is_valid(), "Phase %s PatternDefinition did not round-trip: %s" % [phase.id, pattern_round_trip.validation_errors()])

func _assert_phase_seed_contract(catalog) -> void:
	var first_id := String(EXPECTED_PHASE_IDS[0])
	var second_id := String(EXPECTED_PHASE_IDS[1])
	var seed_a := catalog.phase_local_seed(0x12345678, first_id)
	var seed_a_repeat := catalog.phase_local_seed(0x12345678, first_id)
	var seed_other_stream := catalog.phase_local_seed(0x12345678, second_id)
	var seed_other_run := catalog.phase_local_seed(0x12345679, first_id)
	_check(seed_a != 0, "Phase-local seed derivation returned its invalid sentinel.")
	_check_equal(seed_a, seed_a_repeat, "Phase-local seed derivation is not stable.")
	_check(seed_a != seed_other_stream, "Distinct deterministic stream IDs derived the same test seed.")
	_check(seed_a != seed_other_run, "Distinct run seeds derived the same phase-local test seed.")

	var shared := RandomNumberGenerator.new()
	var control := RandomNumberGenerator.new()
	shared.seed = 987654321
	control.seed = 987654321
	_check_equal(shared.randi(), control.randi(), "Shared RNG controls did not start in the same state.")
	catalog.phase_local_seed(77, first_id)
	_check_equal(shared.randi(), control.randi(), "Phase-local seed derivation consumed or mutated an unrelated gameplay RNG.")

func _assert_catalog_fail_closed_contracts() -> void:
	var empty_catalog := M1ContentCatalog.new()
	empty_catalog.reload_from_roots({}, {})
	_check(not empty_catalog.is_valid(), "Catalog accepted empty JSON roots.")
	_check(not empty_catalog.validation_errors().is_empty(), "Empty JSON roots produced no validation evidence.")

	var stage_root = JSON.parse_string(FileAccess.get_file_as_string(M1ContentCatalog.STAGE_SOURCE_PATH))
	var phase_root = JSON.parse_string(FileAccess.get_file_as_string(M1ContentCatalog.PHASE_SOURCE_PATH))
	_check(stage_root is Dictionary and phase_root is Dictionary, "Negative catalog fixtures could not load frozen roots.")
	if not (stage_root is Dictionary) or not (phase_root is Dictionary):
		return

	var malformed_stage: Dictionary = stage_root.duplicate(true)
	malformed_stage.stages[0]["segments"] = {"wrong": "shape"}
	var malformed_stage_catalog := M1ContentCatalog.new()
	malformed_stage_catalog.reload_from_roots(malformed_stage, phase_root)
	_check(not malformed_stage_catalog.is_valid(), "Catalog accepted a wrong-shaped nested stage array.")

	var malformed_phase: Dictionary = phase_root.duplicate(true)
	malformed_phase.phases[0]["emitters"] = {"wrong": "shape"}
	malformed_phase.phases[0]["score_route"] = []
	var malformed_phase_catalog := M1ContentCatalog.new()
	malformed_phase_catalog.reload_from_roots(stage_root, malformed_phase)
	_check(not malformed_phase_catalog.is_valid(), "Catalog accepted wrong-shaped nested phase contracts.")

func _assert_m0_constructor_compatibility() -> void:
	var timeline := StageTimeline.new("stage_1", [
		{"id": "second", "tick": 120, "kind": "wave"},
		{"id": "first", "tick": 60, "kind": "wave"},
	])
	_check(timeline.is_valid(), "Original M0 StageTimeline constructor is no longer valid: %s" % [timeline.validation_errors()])
	_check_equal(String(timeline.events[0].id), "first", "M0 StageTimeline deterministic ordering changed.")

	var pattern := PatternDefinition.new({
		"id": "baseline_ring",
		"duration_ticks": 180,
		"emitters": [{"id": "center", "topology": "radial_ring"}],
		"tags": ["boss", "baseline"],
	})
	_check(pattern.is_valid(), "Original M0 PatternDefinition constructor is no longer valid: %s" % [pattern.validation_errors()])

	var phase := BossPhaseDefinition.new({
		"id": "stage_1_spell_1",
		"display_name": "Baseline Spell",
		"kind": "spell",
		"hit_points": 600.0,
		"timeout_ticks": 1800,
		"pattern_id": "baseline_ring",
		"next_phase_id": "stage_1_spell_2",
	})
	_check(phase.is_valid(), "Original M0 BossPhaseDefinition constructor is no longer valid: %s" % [phase.validation_errors()])

	var normal := DifficultyProfile.new("normal")
	var hard := DifficultyProfile.new("hard")
	_check(normal.is_valid(), "Original M0 Normal DifficultyProfile is no longer valid.")
	_check(hard.is_valid() and hard.has_topology_change(), "Original M0 Hard DifficultyProfile is no longer valid.")

func _assert_stage_director_queries(catalog) -> void:
	var director := StageDirector.new()
	for method in [
		"stage_controller",
		"due_wave_events",
		"boss_cards",
		"boss_definition",
		"midboss_definition",
		"pattern_aliases",
		"m1_content_catalog",
		"m1_stage_timeline",
		"m1_stage_segments",
		"m1_stage_beats",
		"m1_phase_definitions",
		"m1_phase_definition",
		"m1_phase_local_seed",
	]:
		_check(director.has_method(method), "StageDirector is missing additive query %s." % method)
	var legacy_aliases_before: Dictionary = director.pattern_aliases()
	var legacy_stage_snapshots: Array[Dictionary] = []
	for stage_index in range(1, 7):
		var controller_before: Dictionary = director.stage_controller(stage_index)
		var first_wave_timer := int(controller_before.waves[0].time)
		legacy_stage_snapshots.append({
			"controller": controller_before,
			"boss_cards": director.boss_cards(stage_index),
			"boss": director.boss_definition(stage_index),
			"midboss": director.midboss_definition(stage_index),
			"first_wave_timer": first_wave_timer,
			"due_wave_events": director.due_wave_events(stage_index, first_wave_timer, {}),
		})
	_check_equal(director.m1_stage_segments(1).size(), 3, "StageDirector M1 segment query drifted.")
	_check_equal(director.m1_stage_beats(1).size(), 18, "StageDirector M1 beat query drifted.")
	_check_equal(director.m1_phase_definitions(1).size(), 6, "StageDirector M1 phase query drifted.")
	_check_equal(director.m1_phase_definition(EXPECTED_PHASE_IDS[0]).id, EXPECTED_PHASE_IDS[0], "StageDirector M1 phase identity query drifted.")
	_check_equal(
		director.m1_phase_local_seed(41, EXPECTED_PHASE_IDS[0]),
		catalog.phase_local_seed(41, EXPECTED_PHASE_IDS[0]),
		"StageDirector M1 phase-local seed query drifted."
	)
	_check_equal(director.pattern_aliases(), legacy_aliases_before, "M1 queries mutated legacy pattern aliases.")
	for stage_index in range(1, 7):
		var before: Dictionary = legacy_stage_snapshots[stage_index - 1]
		_check_equal(director.stage_controller(stage_index), before.controller, "M1 queries mutated stage %d legacy controller." % stage_index)
		_check_equal(director.boss_cards(stage_index), before.boss_cards, "M1 queries mutated stage %d legacy boss cards." % stage_index)
		_check_equal(director.boss_definition(stage_index), before.boss, "M1 queries mutated stage %d legacy boss definition." % stage_index)
		_check_equal(director.midboss_definition(stage_index), before.midboss, "M1 queries mutated stage %d legacy midboss definition." % stage_index)
		_check_equal(director.due_wave_events(stage_index, int(before.first_wave_timer), {}), before.due_wave_events, "M1 queries mutated stage %d legacy wave expansion." % stage_index)

func _initialize() -> void:
	call_deferred("_run")
