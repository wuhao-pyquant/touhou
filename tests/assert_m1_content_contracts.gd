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
		_check_equal(phase.timeline.size(), 4, "Phase %s ordered timeline length drifted." % phase.id)
		_check_equal(phase.boss_movement.size(), 3, "Phase %s Boss movement trace length drifted." % phase.id)
		_check(not phase.capture_condition.is_empty(), "Phase %s lacks capture conditions." % phase.id)
		_check(not phase.failure_condition.is_empty(), "Phase %s lacks failure conditions." % phase.id)
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
	_check_equal(actual_phase_ids, EXPECTED_PHASE_IDS, "Phase identities or encounter order drifted.")
	_check_equal(actual_legacy_ids, EXPECTED_LEGACY_PATTERN_IDS, "Legacy pattern encounter mapping drifted.")
	_check_equal(spell_count, 26, "M1 spell count drifted.")
	_check_equal(nonspell_count, 14, "M1 nonspell count drifted.")
	_check_equal(warning_normal, 18, "Authored Normal warning minimum drifted.")
	_check_equal(warning_hard, 12, "Authored Hard warning minimum drifted.")
	_check_equal(seen_fingerprints.size(), 40, "Canonical fingerprints are not unique across all phases.")

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
	_check_equal(director.m1_stage_segments(1).size(), 3, "StageDirector M1 segment query drifted.")
	_check_equal(director.m1_stage_beats(1).size(), 18, "StageDirector M1 beat query drifted.")
	_check_equal(director.m1_phase_definitions(1).size(), 6, "StageDirector M1 phase query drifted.")
	_check_equal(director.m1_phase_definition(EXPECTED_PHASE_IDS[0]).id, EXPECTED_PHASE_IDS[0], "StageDirector M1 phase identity query drifted.")
	_check_equal(
		director.m1_phase_local_seed(41, EXPECTED_PHASE_IDS[0]),
		catalog.phase_local_seed(41, EXPECTED_PHASE_IDS[0]),
		"StageDirector M1 phase-local seed query drifted."
	)

func _initialize() -> void:
	call_deferred("_run")
