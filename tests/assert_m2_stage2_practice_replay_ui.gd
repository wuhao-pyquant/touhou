extends SceneTree

const MainScript := preload("res://scripts/main.gd")
const ReplayData := preload("res://scripts/replay/replay_data.gd")
const ReplayHeader := preload("res://scripts/replay/replay_header.gd")
const UiModel := preload("res://scripts/ui/ui_model.gd")

const PHASE_IDS := [
	"stage_2_midboss_nonspell_1", "stage_2_midboss_spell_1",
	"stage_2_boss_nonspell_1", "stage_2_boss_spell_1", "stage_2_boss_spell_2", "stage_2_boss_spell_3",
]

var failed := false

func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	failed = true
	push_error("M2_STAGE2_PRACTICE_REPLAY_UI_FAIL: %s" % message)
	return false

func _equal(actual: Variant, expected: Variant, message: String) -> void:
	_check(actual == expected, "%s Expected %s, got %s" % [message, expected, actual])

func _new_main() -> Node:
	var main := MainScript.new()
	main.game_manager_ref = load("res://autoload/game_manager.gd").new()
	main.audio_manager_ref = null
	main.bullet_world.configure(4096, 8192, 512)
	main._sync_bullet_world_compatibility_views()
	return main

func _free_main(main: Node) -> void:
	if main == null:
		return
	var manager: Object = main.game_manager_ref
	main.free()
	if is_instance_valid(manager):
		manager.free()

func _header(phase_id: String) -> RefCounted:
	return ReplayHeader.new({
		"build_version": "m2-practice-test",
		"content_hash": "m2-stage2-practice-test",
		"seed": 24680,
		"difficulty": "hard",
		"protagonist": "miko",
		"shot_type": "ofuda_trace",
		"mode": ReplayHeader.MODE_SPELL_PRACTICE,
		"starting_stage": 2,
		"phase_id": phase_id,
	})

func _assert_menu_reachability() -> void:
	var ui := UiModel.new()
	var stage_entries := ui.practice_stage_entries(["第一关", "第二关", "第三关"], 2)
	var found_phase_entry := false
	for entry_value in stage_entries:
		var entry: Dictionary = entry_value
		found_phase_entry = found_phase_entry or String(entry.get("id", "")) == "stage_2_phase_practice"
	_check(found_phase_entry, "Stage Practice did not expose the reachable Stage 2 phase-practice entry.")
	var phase_entries := ui.stage2_phase_practice_entries()
	_equal(phase_entries.size(), PHASE_IDS.size(), "Stage 2 phase menu count changed.")
	for index in range(PHASE_IDS.size()):
		var entry: Dictionary = phase_entries[index]
		_equal(String(entry.get("id", "")), PHASE_IDS[index], "Phase menu identity/order changed at %d." % index)
		_check(not String(entry.get("label", "")).is_empty(), "Phase menu label is missing at %d." % index)

func _assert_menu_start_and_snapshot() -> void:
	for phase_id in PHASE_IDS:
		var main := _new_main()
		_check(main._start_stage2_phase_practice(phase_id), "Menu start failed for %s." % phase_id)
		_equal(main.game_manager_ref.current_stage, 2, "%s did not start Stage 2." % phase_id)
		_equal(String(main.game_manager_ref.state), "boss", "%s did not enter the real controller boss state." % phase_id)
		_equal(main.stage2_encounter_controller.active_phase_id(), phase_id, "%s did not enter the selected controller phase." % phase_id)
		_equal(main.stage2_encounter_controller.active_phase_tick(), 0, "%s did not enter at tick zero." % phase_id)
		var snapshot: Dictionary = main.capture_simulation_state()
		_check(main.validate_simulation_state(snapshot), "%s phase-practice Main snapshot failed validation." % phase_id)
		_equal(String(snapshot.get("stage2_controller", {}).get("phase_practice_phase_id", "")), phase_id, "%s snapshot lost phase identity." % phase_id)
		_free_main(main)

func _assert_replay_identity_and_rejection() -> void:
	var phase_id: String = PHASE_IDS[3]
	var header := _header(phase_id)
	_check(header.is_valid(), "Approved Stage 2 replay header was rejected: %s" % [header.validation_errors()])
	var recorder := _new_main()
	_check(recorder.start_replay_recording(header), "Stage 2 practice replay recording did not initialize.")
	var document: Dictionary = recorder.stop_replay_recording()
	_equal(String(document.get("header", {}).get("mode", "")), ReplayHeader.MODE_SPELL_PRACTICE, "Replay document mode changed.")
	_equal(int(document.get("header", {}).get("starting_stage", 0)), 2, "Replay document starting stage changed.")
	_equal(String(document.get("header", {}).get("phase_id", "")), phase_id, "Replay document phase identity changed.")
	_free_main(recorder)

	var playback := _new_main()
	var expected := {"build_version": "m2-practice-test", "content_hash": "m2-stage2-practice-test", "mode": ReplayHeader.MODE_SPELL_PRACTICE, "starting_stage": 2, "phase_id": phase_id}
	_check(playback.start_replay_playback(document, expected), "Exact Stage 2 practice replay playback was rejected.")
	_equal(playback.stage2_encounter_controller.active_phase_id(), phase_id, "Playback did not start the exact Stage 2 controller phase.")
	_free_main(playback)

	var mismatch := _new_main()
	mismatch.game_manager_ref.score = 77
	var before_state: String = String(mismatch.game_manager_ref.state)
	var before_identity: Dictionary = mismatch.replay_identity.duplicate(true)
	_check(not mismatch.start_replay_playback(document, {"phase_id": PHASE_IDS[4]}), "Mismatched Stage 2 phase identity was accepted.")
	_equal(mismatch.game_manager_ref.score, 77, "Mismatched replay mutated live game state.")
	_equal(String(mismatch.game_manager_ref.state), before_state, "Mismatched replay changed live UI state.")
	_equal(mismatch.replay_identity, before_identity, "Mismatched replay changed live replay identity.")
	_equal(mismatch.replay_runtime_mode, "none", "Mismatched replay entered playback mode.")
	_free_main(mismatch)

	var malformed: Dictionary = document.duplicate(true)
	malformed.header.phase_id = "stage_2_unknown_phase"
	var unknown_target := _new_main()
	unknown_target.game_manager_ref.score = 91
	_check(not unknown_target.start_replay_playback(malformed), "Unknown Stage 2 phase identity was accepted.")
	_equal(unknown_target.game_manager_ref.score, 91, "Unknown replay mutated live game state.")
	_equal(unknown_target.replay_runtime_mode, "none", "Unknown replay entered playback mode.")
	_free_main(unknown_target)

func _assert_legacy_compatibility() -> void:
	var legacy_header := ReplayHeader.new({
		"build_version": "legacy-test", "content_hash": "legacy-content", "seed": 1,
		"difficulty": "normal", "protagonist": "miko", "shot_type": "ofuda_trace",
		"mode": ReplayHeader.MODE_SPELL_PRACTICE, "starting_stage": 4, "phase_id": "fixture_phase",
	})
	_check(legacy_header.is_valid(), "Legacy non-Stage-2 spell-practice header lost compatibility.")
	var legacy := ReplayData.new()
	_check(legacy.start_recording(legacy_header), "Legacy spell-practice replay document no longer records.")
	_check(ReplayHeader.new({"build_version": "story", "content_hash": "story", "seed": 1, "difficulty": "normal", "protagonist": "miko", "shot_type": "ofuda_trace", "mode": ReplayHeader.MODE_STORY, "starting_stage": 1}).is_valid(), "Story replay compatibility changed.")
	_check(ReplayHeader.new({"build_version": "stage", "content_hash": "stage", "seed": 1, "difficulty": "normal", "protagonist": "miko", "shot_type": "ofuda_trace", "mode": ReplayHeader.MODE_STAGE_PRACTICE, "starting_stage": 2}).is_valid(), "Ordinary Stage Practice replay compatibility changed.")

func _run() -> void:
	_assert_menu_reachability()
	_assert_menu_start_and_snapshot()
	_assert_replay_identity_and_rejection()
	_assert_legacy_compatibility()
	if failed:
		quit(1)
		return
	print("PASS: M2 Stage 2 phase-practice menu, controller entry, replay identity/rejection, snapshot, and legacy compatibility are covered.")
	quit(0)

func _initialize() -> void:
	call_deferred("_run")
