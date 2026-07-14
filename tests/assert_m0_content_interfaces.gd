extends SceneTree

const StageTimeline := preload("res://scripts/content/stage_timeline.gd")
const PatternDefinition := preload("res://scripts/content/pattern_definition.gd")
const BossPhaseDefinition := preload("res://scripts/content/boss_phase_definition.gd")
const DifficultyProfile := preload("res://scripts/content/difficulty_profile.gd")
const ReplayHeader := preload("res://scripts/replay/replay_header.gd")
const ReplayData := preload("res://scripts/replay/replay_data.gd")

var failed := false

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)

func _run() -> void:
	var timeline := StageTimeline.new("stage_1", [
		{"id": "second", "tick": 120, "kind": "wave", "payload": {"wave_id": "b"}},
		{"id": "first", "tick": 60, "kind": "wave", "payload": {"wave_id": "a"}},
	])
	_check(timeline.is_valid(), "A valid StageTimeline was rejected: %s" % [timeline.validation_errors()])
	_check(String(timeline.events[0].id) == "first", "StageTimeline events were not put in deterministic tick order.")
	_check(timeline.pop_events_through(59).is_empty(), "StageTimeline emitted an event before its tick.")
	_check(timeline.pop_events_through(60).size() == 1, "StageTimeline did not emit its due event exactly once.")

	var pattern := PatternDefinition.new({
		"id": "baseline_ring",
		"duration_ticks": 180,
		"emitters": [{"id": "center", "topology": "radial_ring"}],
		"tags": ["boss", "baseline"],
	})
	_check(pattern.is_valid(), "A valid PatternDefinition was rejected: %s" % [pattern.validation_errors()])

	var phase := BossPhaseDefinition.new({
		"id": "stage_1_spell_1",
		"display_name": "Baseline Spell",
		"kind": "spell",
		"hit_points": 600.0,
		"timeout_ticks": 1800,
		"pattern_id": "baseline_ring",
		"next_phase_id": "stage_1_spell_2",
	})
	_check(phase.is_valid(), "A valid BossPhaseDefinition was rejected: %s" % [phase.validation_errors()])

	var normal := DifficultyProfile.new("normal")
	var hard := DifficultyProfile.new("hard")
	var unsupported := DifficultyProfile.new("easy")
	_check(normal.is_valid(), "Normal DifficultyProfile must be accepted.")
	_check(hard.is_valid(), "Hard DifficultyProfile must be accepted: %s" % [hard.validation_errors()])
	_check(hard.has_topology_change(), "Hard DifficultyProfile must expose a topology-changing field.")
	_check(String(hard.topology_variant) != String(normal.topology_variant), "Hard topology cannot be represented only by speed/count scaling.")
	_check(not unsupported.is_valid(), "DifficultyProfile accepted Easy, which is outside the frozen 1.0 scope.")

	var header := ReplayHeader.new({
		"build_version": "1.0.0-m0",
		"content_hash": "content-v1",
		"seed": 42,
		"difficulty": "hard",
		"protagonist": "miko",
		"shot_type": "ofuda_trace",
	})
	_check(header.is_valid(), "Valid replay identity header was rejected: %s" % [header.validation_errors()])
	var unsupported_header := ReplayHeader.new(header.to_dict())
	unsupported_header.difficulty = "easy"
	_check(not unsupported_header.is_valid(), "Replay identity accepted Easy, which is outside the frozen 1.0 scope.")
	var replay := ReplayData.new()
	_check(replay.start_recording(header), "Replay recorder rejected a valid header.")
	replay.record_tick({"move_x": 1, "move_y": -1, "shoot": true, "focus": false, "bomb": false, "pause": false})
	replay.record_tick({"move_x": 0, "move_y": 0, "shoot": false, "focus": true, "bomb": true, "pause": false})
	var playback := ReplayData.new()
	_check(playback.load_dict(replay.to_dict()), "Replay playback rejected recorder output.")
	_check(int(playback.next_frame().tick) == 0 and int(playback.next_frame().tick) == 1, "Replay playback did not preserve per-tick input order.")

	if failed:
		quit(1)
	else:
		print("PASS: M0 content and replay interfaces validate frozen Normal/Hard runtime contracts.")
		quit(0)

func _initialize() -> void:
	call_deferred("_run")
