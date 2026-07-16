extends SceneTree

const StageDirector := preload("res://scripts/runtime/stage_director.gd")
const Stage2EncounterController := preload("res://scripts/runtime/stage2_encounter_controller.gd")

const PHASE_IDS := [
	"stage_2_midboss_nonspell_1", "stage_2_midboss_spell_1",
	"stage_2_boss_nonspell_1", "stage_2_boss_spell_1", "stage_2_boss_spell_2", "stage_2_boss_spell_3",
]
const POSITION := Vector2(360.0, 720.0)
const INITIAL_SNAPSHOT_KEYS := [
	"version", "stage_id", "artifact_id", "difficulty", "gameplay_seed", "encounter_kind",
	"active_phase_index", "resolved_phase_ids", "stage_runtime", "phase_runtime",
]

var failed := false

func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	failed = true
	push_error("M2_STAGE2_PHASE_PRACTICE_FAIL: %s" % message)
	return false

func _equal(actual: Variant, expected: Variant, message: String) -> void:
	_check(actual == expected, "%s Expected %s, got %s" % [message, expected, actual])

func _new_controller(difficulty: String, seed: int) -> RefCounted:
	var controller: RefCounted = Stage2EncounterController.new()
	_check(controller.configure(StageDirector.new().stage2_package(), difficulty, seed), "Approved package failed to configure: %s" % controller.last_error())
	return controller

func _sorted_keys(value: Dictionary) -> Array:
	var keys := value.keys()
	keys.sort()
	return keys

func _assert_atomic_rejection() -> void:
	var unconfigured: RefCounted = Stage2EncounterController.new()
	var empty_snapshot: Dictionary = unconfigured.capture_snapshot()
	_check(not unconfigured.start_phase_practice(PHASE_IDS[0]), "Unconfigured controller accepted practice.")
	_equal(unconfigured.last_error(), "phase practice requires a configured controller", "Unconfigured error changed.")
	_equal(unconfigured.capture_snapshot(), empty_snapshot, "Unconfigured rejection mutated state.")

	var controller := _new_controller("normal", 9101)
	var before: Dictionary = controller.capture_snapshot()
	_check(not controller.start_phase_practice("stage_2_unknown_phase"), "Unknown phase was accepted.")
	_equal(controller.last_error(), "phase practice phase id is not approved", "Unknown phase error changed.")
	_equal(controller.capture_snapshot(), before, "Unknown phase rejection mutated state.")
	_check(bool(controller.advance(POSITION).get("ok", false)), "Ordinary stage could not advance.")
	before = controller.capture_snapshot()
	_check(not controller.start_phase_practice(PHASE_IDS[0]), "Late practice transition was accepted.")
	_equal(controller.last_error(), "phase practice requires the configured initial stage state", "Late-transition error changed.")
	_equal(controller.capture_snapshot(), before, "Late transition rejection mutated state.")

func _assert_phase(phase_id: String, difficulty: String, seed: int) -> void:
	var index := PHASE_IDS.find(phase_id)
	var controller := _new_controller(difficulty, seed)
	_check(controller.start_phase_practice(phase_id), "%s/%s direct start failed: %s" % [phase_id, difficulty, controller.last_error()])
	_equal(controller.encounter_kind(), "midboss" if index < 2 else "boss", "%s encounter owner changed." % phase_id)
	_equal(controller.active_phase_id(), phase_id, "%s active identity changed." % phase_id)
	_equal(controller.active_phase_tick(), 0, "%s did not begin at tick zero." % phase_id)
	_equal(controller.resolved_phase_ids(), [], "%s inherited ordinary resolutions." % phase_id)
	var snapshot: Dictionary = controller.capture_snapshot()
	_check(bool(snapshot.get("phase_practice", false)), "%s snapshot omitted practice marker." % phase_id)
	_equal(String(snapshot.get("phase_practice_phase_id", "")), phase_id, "%s snapshot phase identity changed." % phase_id)
	_check(controller.validate_snapshot(snapshot), "%s practice snapshot rejected itself." % phase_id)
	for _tick in range(18):
		_check(bool(controller.advance(POSITION).get("ok", false)), "%s failed during deterministic advance." % phase_id)
	var continuation: Dictionary = controller.capture_snapshot()
	var expected_output: Dictionary = controller.advance(POSITION)
	var expected_final: Dictionary = controller.capture_snapshot()
	var restored := _new_controller(difficulty, seed)
	_check(restored.restore_snapshot(continuation), "%s snapshot restore failed." % phase_id)
	_equal(restored.advance(POSITION), expected_output, "%s deterministic continuation output changed." % phase_id)
	_equal(restored.capture_snapshot(), expected_final, "%s deterministic continuation state changed." % phase_id)
	var resolution: Dictionary = restored.resolve_active_phase("clear")
	_check(bool(resolution.get("ok", false)), "%s clear resolution failed." % phase_id)
	_equal(String(resolution.get("phase_resolutions", [{}])[0].get("phase_id", "")), phase_id, "%s clear resolved another phase." % phase_id)
	_check((resolution.get("phase_started", {}) as Dictionary).is_empty(), "%s clear started a sequential phase." % phase_id)
	_check((resolution.get("gate_completion", {}) as Dictionary).is_empty(), "%s clear completed an ordinary gate." % phase_id)
	_check(bool(resolution.get("complete", false)), "%s clear did not complete practice." % phase_id)
	_equal(restored.resolved_phase_ids(), [phase_id], "%s clear resolution was not isolated." % phase_id)
	_check(restored.validate_snapshot(restored.capture_snapshot()), "%s completed practice snapshot is invalid." % phase_id)

func _assert_timeout_isolation() -> void:
	var controller := _new_controller("hard", 9301)
	var phase_id: String = PHASE_IDS[4]
	_check(controller.start_phase_practice(phase_id), "Timeout fixture could not start.")
	var cap := int(controller.active_phase_definition().get("timeout_ticks", 0))
	for _tick in range(cap):
		_check(bool(controller.advance(POSITION).get("ok", false)), "Timeout fixture failed before cap.")
	var result: Dictionary = controller.advance(POSITION)
	_equal(String(result.get("phase_resolutions", [{}])[0].get("outcome", "")), "timeout", "Practice timeout did not resolve as timeout.")
	_check((result.get("phase_started", {}) as Dictionary).is_empty(), "Practice timeout started a sequential phase.")
	_check((result.get("gate_completion", {}) as Dictionary).is_empty(), "Practice timeout completed an ordinary gate.")
	_check(bool(result.get("complete", false)), "Practice timeout did not finish.")

func _assert_ordinary_compatibility() -> void:
	var controller := _new_controller("normal", 9401)
	var initial: Dictionary = controller.capture_snapshot()
	_equal(_sorted_keys(initial), _sorted_keys({"version": 0, "stage_id": "", "artifact_id": "", "difficulty": "", "gameplay_seed": 0, "encounter_kind": "", "active_phase_index": 0, "resolved_phase_ids": [], "stage_runtime": {}, "phase_runtime": {}}), "Ordinary snapshot shape changed.")
	_check(not initial.has("phase_practice"), "Ordinary snapshot acquired practice state.")
	_check(controller.validate_snapshot(initial), "Ordinary v1 snapshot no longer validates.")

func _run() -> void:
	_assert_atomic_rejection()
	var seed := 9200
	for difficulty in ["normal", "hard"]:
		for phase_id in PHASE_IDS:
			seed += 1
			_assert_phase(phase_id, difficulty, seed)
	_assert_timeout_isolation()
	_assert_ordinary_compatibility()
	if failed:
		quit(1)
		return
	print("PASS: M2 Stage 2 phase-practice controller covers all six phases, atomic entry rejection, isolated completion, deterministic snapshots, and ordinary compatibility.")
	quit(0)

func _initialize() -> void:
	call_deferred("_run")
