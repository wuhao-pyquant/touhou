extends SceneTree

const StageDirector := preload("res://scripts/runtime/stage_director.gd")
const Stage2EncounterController := preload("res://scripts/runtime/stage2_encounter_controller.gd")
const DanmakuPatternRuntime := preload("res://scripts/runtime/danmaku_pattern_runtime.gd")

const PHASE_IDS := [
	"stage_2_midboss_nonspell_1", "stage_2_midboss_spell_1",
	"stage_2_boss_nonspell_1", "stage_2_boss_spell_1", "stage_2_boss_spell_2", "stage_2_boss_spell_3",
]
const DIFFICULTIES := ["normal", "hard"]
const FIXED_PLAYER_POSITION := Vector2(360.0, 720.0)
const ORDINARY_SNAPSHOT_KEYS := [
	"version", "stage_id", "artifact_id", "difficulty", "gameplay_seed", "encounter_kind",
	"active_phase_index", "resolved_phase_ids", "stage_runtime", "phase_runtime",
]
const NOT_CONFIGURED_ERROR := "phase practice requires a configured controller"
const UNKNOWN_ID_ERROR := "phase practice phase id is not approved"
const INVALID_STATE_ERROR := "phase practice requires the configured initial stage state"

var failed := false

func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	failed = true
	push_error("M2_STAGE2_PHASE_PRACTICE_FAIL: %s" % message)
	return false

func _check_equal(actual, expected, message: String) -> bool:
	return _check(actual == expected, "%s Expected %s, got %s" % [message, expected, actual])

func _package() -> Dictionary:
	return StageDirector.new().stage2_package()

func _new_controller(difficulty: String, seed: int) -> RefCounted:
	var controller: RefCounted = Stage2EncounterController.new()
	_check(controller.configure(_package(), difficulty, seed), "Controller rejected the approved %s package: %s" % [difficulty, controller.last_error()])
	return controller

func _sorted_keys(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys

func _expected_ordinary_keys() -> Array:
	var keys: Array = ORDINARY_SNAPSHOT_KEYS.duplicate()
	keys.sort()
	return keys

func _expected_encounter_kind(phase_index: int) -> String:
	return "midboss" if phase_index < 2 else "boss"

func _assert_phase_payload_matches(actual: Dictionary, expected: Dictionary, label: String) -> void:
	for key in ["warnings", "events", "boss_movements", "bullet_specs"]:
		_check_equal(actual.get(key, []), expected.get(key, []), "%s %s output diverged from the authored phase runtime." % [label, key])

func _assert_rejections_are_atomic() -> void:
	var unconfigured: RefCounted = Stage2EncounterController.new()
	var unconfigured_before: Dictionary = unconfigured.capture_snapshot()
	_check(not unconfigured.start_phase_practice(PHASE_IDS[0]), "Unconfigured controller accepted phase practice.")
	_check_equal(unconfigured.last_error(), NOT_CONFIGURED_ERROR, "Unconfigured rejection error drifted.")
	_check_equal(unconfigured.capture_snapshot(), unconfigured_before, "Unconfigured rejection mutated the controller snapshot.")

	var controller: RefCounted = _new_controller("normal", 12001)
	var before_unknown: Dictionary = controller.capture_snapshot()
	_check(not controller.start_phase_practice("stage_2_unknown_phase"), "Controller accepted an unknown practice phase ID.")
	_check_equal(controller.last_error(), UNKNOWN_ID_ERROR, "Unknown-ID rejection error drifted.")
	_check_equal(controller.capture_snapshot(), before_unknown, "Unknown-ID rejection partially mutated controller state.")
	_check(not controller.start_phase_practice("stage_2_unknown_phase"), "Repeated unknown practice phase ID was accepted.")
	_check_equal(controller.last_error(), UNKNOWN_ID_ERROR, "Repeated unknown-ID rejection was not stable.")
	_check_equal(controller.capture_snapshot(), before_unknown, "Repeated unknown-ID rejection mutated controller state.")

	var advanced: Dictionary = controller.advance(FIXED_PLAYER_POSITION)
	_check(bool(advanced.get("ok", false)), "Ordinary controller could not advance for invalid-state fixture.")
	var before_invalid: Dictionary = controller.capture_snapshot()
	_check(not controller.start_phase_practice(PHASE_IDS[0]), "Advanced ordinary stage accepted a late phase-practice transition.")
	_check_equal(controller.last_error(), INVALID_STATE_ERROR, "Invalid-state rejection error drifted.")
	_check_equal(controller.capture_snapshot(), before_invalid, "Invalid-state rejection partially mutated controller state.")

	var active: RefCounted = _new_controller("normal", 12002)
	_check(active.start_phase_practice(PHASE_IDS[0]), "Could not prepare active-practice rejection fixture.")
	var before_reentry: Dictionary = active.capture_snapshot()
	_check(not active.start_phase_practice(PHASE_IDS[1]), "Active practice allowed a second direct phase transition.")
	_check_equal(active.last_error(), INVALID_STATE_ERROR, "Practice re-entry rejection error drifted.")
	_check_equal(active.capture_snapshot(), before_reentry, "Practice re-entry rejection partially mutated controller state.")

func _assert_entry_and_snapshot_continuation(phase_index: int, difficulty: String, seed: int) -> void:
	var package: Dictionary = _package()
	var phase_specs: Array = package.get("phase_specs", [])
	var phase_spec: Dictionary = phase_specs[phase_index]
	var phase_id: String = PHASE_IDS[phase_index]
	var source_phase: Dictionary = package.get("metadata", {}).get("phase_metadata", {}).get(phase_id, {}).get("source_phase", {})
	var owner: Dictionary = source_phase.get("owner", {})
	var label := "%s/%s" % [phase_id, difficulty]
	var controller: RefCounted = _new_controller(difficulty, seed)
	_check(controller.start_phase_practice(phase_id), "%s direct start failed: %s" % [label, controller.last_error()])
	_check(controller.is_phase_practice(), "%s did not enter phase-practice mode." % label)
	_check_equal(controller.encounter_kind(), _expected_encounter_kind(phase_index), "%s encounter owner kind drifted." % label)
	_check_equal(controller.active_phase_id(), phase_id, "%s activated the wrong phase." % label)
	_check_equal(controller.active_phase_index(), phase_index, "%s activated the wrong phase index." % label)
	_check_equal(controller.active_phase_tick(), 0, "%s did not start at phase tick zero." % label)
	_check_equal(controller.resolved_phase_ids(), [], "%s inherited resolved phases from ordinary flow." % label)

	var definition: Dictionary = controller.active_phase_definition()
	var expected_topology := String(phase_spec.get("difficulties", {}).get(difficulty, {}).get("topology_id", ""))
	_check_equal(String(definition.get("id", "")), phase_id, "%s phase definition ID drifted." % label)
	_check_equal(String(definition.get("kind", "")), String(source_phase.get("kind", "")), "%s spell/nonspell kind drifted." % label)
	_check_equal(String(definition.get("encounter_kind", "")), _expected_encounter_kind(phase_index), "%s definition encounter kind drifted." % label)
	_check_equal(String(definition.get("owner_id", "")), String(owner.get("id", "")), "%s owner ID drifted." % label)
	_check_equal(String(definition.get("owner_display_name", "")), String(owner.get("display_name", "")), "%s owner display name drifted." % label)
	_check_equal(float(definition.get("base_hp", 0.0)), float(source_phase.get("base_hp", 0.0)), "%s HP drifted." % label)
	_check_equal(int(definition.get("timeout_ticks", 0)), int(source_phase.get("timeout_ticks", 0)), "%s timeout drifted." % label)
	_check_equal(String(definition.get("topology_id", "")), expected_topology, "%s topology selection drifted." % label)

	var telemetry: Dictionary = controller.telemetry_snapshot()
	var runtime_telemetry: Dictionary = telemetry.get("phase_runtime", {})
	var expected_seed := DanmakuPatternRuntime.derive_phase_local_seed(seed, String(phase_spec.get("deterministic_random_stream_id", "")))
	_check_equal(bool(telemetry.get("phase_practice", false)), true, "%s telemetry omitted phase-practice mode." % label)
	_check_equal(String(telemetry.get("phase_practice_phase_id", "")), phase_id, "%s telemetry practice phase ID drifted." % label)
	_check_equal(int(telemetry.get("stage_runtime", {}).get("stage_tick", -1)), 0, "%s advanced the ordinary stage clock." % label)
	_check_equal(int(runtime_telemetry.get("phase_seed", 0)), expected_seed, "%s used the wrong deterministic seed stream." % label)
	_check_equal(int(runtime_telemetry.get("tick", -1)), 0, "%s runtime did not remain at phase tick zero after entry." % label)
	_check_equal(int(runtime_telemetry.get("rng_draw_count", -1)), 0, "%s consumed RNG during entry." % label)
	_check_equal(runtime_telemetry.get("totals", {}), {"warnings": 0, "events": 0, "boss_movements": 0, "bullet_specs": 0}, "%s inherited warning/event output totals." % label)
	_check_equal(runtime_telemetry.get("last_tick_counts", {}), {"warnings": 0, "events": 0, "boss_movements": 0, "bullet_specs": 0}, "%s inherited last-tick output state." % label)

	var snapshot: Dictionary = controller.capture_snapshot()
	_check_equal(bool(snapshot.get("phase_practice", false)), true, "%s snapshot omitted phase-practice mode." % label)
	_check_equal(String(snapshot.get("phase_practice_phase_id", "")), phase_id, "%s snapshot practice phase ID drifted." % label)
	_check(controller.validate_snapshot(snapshot), "%s controller rejected its phase-practice snapshot." % label)
	var direct_runtime: RefCounted = DanmakuPatternRuntime.new()
	_check(direct_runtime.configure(phase_spec, difficulty, seed), "%s direct runtime fixture rejected approved phase data." % label)
	_check_equal(snapshot.get("phase_runtime", {}), direct_runtime.capture_snapshot(), "%s entry did not preserve pristine warning/event/RNG state." % label)

	for tick in range(18):
		var expected_output: Dictionary = direct_runtime.advance(FIXED_PLAYER_POSITION)
		var actual_output: Dictionary = controller.advance(FIXED_PLAYER_POSITION)
		_check(bool(actual_output.get("ok", false)), "%s continuation failed at tick %d." % [label, tick])
		_assert_phase_payload_matches(actual_output, expected_output, "%s tick %d" % [label, tick])
	_check_equal(controller.capture_snapshot().get("phase_runtime", {}), direct_runtime.capture_snapshot(), "%s runtime state diverged before snapshot continuation." % label)

	var continuation_snapshot: Dictionary = controller.capture_snapshot()
	var expected_next: Dictionary = controller.advance(FIXED_PLAYER_POSITION)
	var expected_final: Dictionary = controller.capture_snapshot()
	var restored: RefCounted = _new_controller(difficulty, seed)
	_check(restored.restore_snapshot(continuation_snapshot), "%s phase-practice snapshot restore failed." % label)
	_check(restored.is_phase_practice(), "%s restore lost phase-practice mode." % label)
	_check_equal(restored.active_phase_id(), phase_id, "%s restore selected the wrong phase." % label)
	_check_equal(restored.advance(FIXED_PLAYER_POSITION), expected_next, "%s one-tick continuation output diverged after restore." % label)
	_check_equal(restored.capture_snapshot(), expected_final, "%s one-tick continuation state diverged after restore." % label)

	var clear_result: Dictionary = restored.resolve_active_phase("clear")
	_check(bool(clear_result.get("ok", false)), "%s clear resolution failed." % label)
	_check_equal(String(clear_result.get("phase_resolutions", [{}])[0].get("phase_id", "")), phase_id, "%s clear resolved the wrong phase." % label)
	_check_equal(String(clear_result.get("phase_resolutions", [{}])[0].get("outcome", "")), "clear", "%s clear outcome drifted." % label)
	_check((clear_result.get("phase_started", {}) as Dictionary).is_empty(), "%s clear advanced into another phase." % label)
	_check((clear_result.get("gate_completion", {}) as Dictionary).is_empty(), "%s clear touched an ordinary stage gate." % label)
	_check(bool(clear_result.get("complete", false)), "%s clear did not end the practice encounter." % label)
	_check_equal(restored.encounter_kind(), "complete", "%s clear did not enter the terminal encounter state." % label)
	_check_equal(restored.active_phase_id(), "", "%s clear retained an active phase." % label)
	_check_equal(restored.resolved_phase_ids(), [phase_id], "%s clear did not isolate the practiced phase resolution." % label)
	var complete_snapshot: Dictionary = restored.capture_snapshot()
	_check(restored.validate_snapshot(complete_snapshot), "%s completed practice snapshot was incoherent." % label)
	_check_equal(String(complete_snapshot.get("phase_practice_phase_id", "")), phase_id, "%s completed snapshot lost practice identity." % label)

func _assert_snapshot_rejection_is_atomic() -> void:
	var controller: RefCounted = _new_controller("normal", 13001)
	_check(controller.start_phase_practice(PHASE_IDS[0]), "Could not prepare malformed practice snapshot fixture.")
	for _tick in range(9):
		controller.advance(FIXED_PLAYER_POSITION)
	var baseline: Dictionary = controller.capture_snapshot()
	var missing_mode: Dictionary = baseline.duplicate(true)
	missing_mode.erase("phase_practice")
	_check(not controller.restore_snapshot(missing_mode), "Practice snapshot without its mode marker was accepted.")
	_check_equal(controller.capture_snapshot(), baseline, "Missing-mode snapshot rejection partially mutated practice state.")
	var mismatched_id: Dictionary = baseline.duplicate(true)
	mismatched_id.phase_practice_phase_id = PHASE_IDS[1]
	_check(not controller.restore_snapshot(mismatched_id), "Practice snapshot with mismatched phase identity was accepted.")
	_check_equal(controller.capture_snapshot(), baseline, "Mismatched-ID snapshot rejection partially mutated practice state.")

func _assert_timeout_isolation() -> void:
	var phase_id: String = PHASE_IDS[4]
	var controller: RefCounted = _new_controller("hard", 14001)
	_check(controller.start_phase_practice(phase_id), "Could not start timeout isolation fixture.")
	var timeout_ticks := int(controller.active_phase_definition().get("timeout_ticks", 0))
	for tick in range(timeout_ticks):
		var output: Dictionary = controller.advance(FIXED_PLAYER_POSITION)
		_check(bool(output.get("ok", false)), "Timeout fixture failed before declared cap at tick %d." % tick)
	var timeout_result: Dictionary = controller.advance(FIXED_PLAYER_POSITION)
	_check(bool(timeout_result.get("ok", false)), "Practice timeout resolution failed.")
	_check_equal(String(timeout_result.get("phase_resolutions", [{}])[0].get("phase_id", "")), phase_id, "Timeout resolved the wrong practice phase.")
	_check_equal(String(timeout_result.get("phase_resolutions", [{}])[0].get("outcome", "")), "timeout", "Practice timeout outcome drifted.")
	_check_equal(int(timeout_result.get("phase_resolutions", [{}])[0].get("phase_tick", -1)), timeout_ticks, "Practice timeout resolved away from the declared cap.")
	_check((timeout_result.get("phase_started", {}) as Dictionary).is_empty(), "Practice timeout advanced into another phase.")
	_check((timeout_result.get("gate_completion", {}) as Dictionary).is_empty(), "Practice timeout touched an ordinary stage gate.")
	_check(bool(timeout_result.get("complete", false)), "Practice timeout did not end the encounter.")
	_check_equal(controller.resolved_phase_ids(), [phase_id], "Practice timeout resolution was not isolated.")
	_check(controller.validate_snapshot(controller.capture_snapshot()), "Completed timeout practice snapshot was incoherent.")

func _assert_ordinary_flow_and_snapshot_compatibility() -> void:
	var controller: RefCounted = _new_controller("normal", 15001)
	var initial: Dictionary = controller.capture_snapshot()
	_check_equal(_sorted_keys(initial), _expected_ordinary_keys(), "Ordinary v1 snapshot shape changed.")
	_check(not initial.has("phase_practice") and not initial.has("phase_practice_phase_id"), "Ordinary snapshot gained practice-only fields.")
	_check(not controller.telemetry_snapshot().has("phase_practice"), "Ordinary telemetry gained practice-only fields.")
	_check(controller.validate_snapshot(initial), "Controller rejected an ordinary v1 snapshot.")
	for _tick in range(31):
		controller.advance(FIXED_PLAYER_POSITION)
	var ordinary_snapshot: Dictionary = controller.capture_snapshot()
	var expected_next: Dictionary = controller.advance(FIXED_PLAYER_POSITION)
	var expected_final: Dictionary = controller.capture_snapshot()
	var restored: RefCounted = _new_controller("normal", 15001)
	_check(restored.restore_snapshot(ordinary_snapshot), "Ordinary v1 snapshot restore failed.")
	_check(not restored.is_phase_practice(), "Ordinary restore entered phase-practice mode.")
	_check_equal(restored.advance(FIXED_PLAYER_POSITION), expected_next, "Ordinary one-tick continuation output changed.")
	_check_equal(restored.capture_snapshot(), expected_final, "Ordinary one-tick continuation state changed.")

	var sequential: RefCounted = _new_controller("hard", 15002)
	var guard := 0
	while sequential.encounter_kind() == "stage" and guard < 800:
		sequential.advance(FIXED_PLAYER_POSITION)
		guard += 1
	_check(guard < 800, "Ordinary sequential flow did not reach the midboss gate.")
	_check(not sequential.is_phase_practice(), "Ordinary midboss gate entered phase-practice mode.")
	_check_equal(sequential.active_phase_id(), PHASE_IDS[0], "Ordinary midboss started on the wrong phase.")
	var first_clear: Dictionary = sequential.resolve_active_phase("clear")
	_check_equal(String(first_clear.get("phase_started", {}).get("id", "")), PHASE_IDS[1], "Ordinary clear no longer advances to the next approved phase.")
	_check(not bool(first_clear.get("complete", false)), "Ordinary first midboss clear incorrectly ended the encounter.")
	var sequential_snapshot: Dictionary = sequential.capture_snapshot()
	_check(not sequential_snapshot.has("phase_practice"), "Ordinary encounter snapshot gained practice-only fields.")
	_check(sequential.validate_snapshot(sequential_snapshot), "Ordinary encounter snapshot no longer validates.")

func _run() -> void:
	_assert_rejections_are_atomic()
	var seed := 16000
	for difficulty in DIFFICULTIES:
		for phase_index in range(PHASE_IDS.size()):
			seed += 1
			_assert_entry_and_snapshot_continuation(phase_index, difficulty, seed)
	_assert_snapshot_rejection_is_atomic()
	_assert_timeout_isolation()
	_assert_ordinary_flow_and_snapshot_compatibility()
	if failed:
		quit(1)
		return
	print("PASS: M2 Stage 2 phase-practice contract covers six phases, both difficulties, atomic rejection, isolated clear/timeout, snapshots, and ordinary compatibility.")
	quit(0)

func _initialize() -> void:
	call_deferred("_run")
