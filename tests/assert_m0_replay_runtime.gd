extends SceneTree

const MainScript := preload("res://scripts/main.gd")
const ReplayData := preload("res://scripts/replay/replay_data.gd")
const ReplayHeader := preload("res://scripts/replay/replay_header.gd")
const StateHasher := preload("res://scripts/runtime/simulation_state_hasher.gd")
const BossStateMachine := preload("res://scripts/runtime/boss_state_machine.gd")

class FixtureStageDirector:
	extends RefCounted

	func stage_controller(_stage_index: int) -> Dictionary:
		return {"boss_time": 999999.0, "boss_spawned": false, "triggered_waves": {}}

	func due_wave_events(_stage_index: int, _timer: int, _triggered: Dictionary) -> Array:
		return []

	func boss_cards(_stage_index: int) -> Array:
		return [{"id": "fixture_phase", "name": "Fixture Phase", "hp": 500.0, "time": 30.0, "kind": "spell", "pattern": "moonlight"}]

	func boss_definition(_stage_index: int) -> Dictionary:
		return {"id": "fixture_boss"}

	func pattern_aliases() -> Dictionary:
		return {}

var failed := false

func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	failed = true
	push_error("M0_FAIL: %s" % message)
	return false

func _fixture() -> Dictionary:
	var file := FileAccess.open("res://tests/fixtures/m0/baseline_replay.json", FileAccess.READ)
	if not _check(file != null, "Could not open committed replay fixture."):
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not _check(parsed is Dictionary, "Committed replay fixture is not a JSON object."):
		return {}
	return parsed

func _new_main() -> Node:
	var main = MainScript.new()
	main.stage_director = FixtureStageDirector.new()
	main.audio_manager_ref = null
	main.bullet_world.configure(64, 128, 16)
	main._sync_bullet_world_compatibility_views()
	return main

func _free_main(main: Node) -> void:
	if main == null:
		return
	var owned_manager: Object = main.game_manager_ref
	var owned_registry: Object = main.asset_registry_ref
	main.game_manager_ref = null
	main.asset_registry_ref = null
	main.free()
	if is_instance_valid(owned_manager):
		owned_manager.free()
	if is_instance_valid(owned_registry):
		owned_registry.free()

func _configure_interaction(main: Node) -> void:
	main.stage_controller = {"boss_time": 999999.0, "boss_spawned": false, "triggered_waves": {}}
	main._spawn_enemy(360.0, 450.0, 2.0, "aimed", "straight", 0.0, 0.0)
	main.enemies[0].shoot_timer = 99999.0

func _record_fixture(document: Dictionary) -> Dictionary:
	var header = ReplayHeader.from_dict(document.header)
	var main := _new_main()
	if not _check(header != null and main.start_replay_recording(header), "Production runtime recorder rejected the committed header."):
		_free_main(main)
		return {}
	_configure_interaction(main)
	for source_frame in document.frames:
		main._advance_gameplay_clock(1.0 / 60.0, source_frame)
	var produced: Dictionary = main.stop_replay_recording()
	var normalized_fixture := ReplayData.new()
	_check(normalized_fixture.load_dict(document), "Committed replay fixture failed ReplayData validation.")
	_check(produced == normalized_fixture.to_dict(), "Committed fixture is not the document produced by the production recorder.")
	_check(main.game_manager_ref.score > 0 or bool(main.enemies[0].get("dying", false)), "Recorded run did not exercise a real enemy collision.")
	_check(main.game_manager_ref.bombs == 2, "Recorded bomb edge did not execute through the production bomb path.")
	_free_main(main)
	return produced

func _play_schedule(document: Dictionary, hz: int, long_frame: bool = false) -> Dictionary:
	var main := _new_main()
	var expected := {"build_version": "1.0.0-m0", "content_hash": "m0-baseline-content-v1"}
	if not _check(main.start_replay_playback(document, expected), "Production playback rejected a valid replay at %d Hz." % hz):
		_free_main(main)
		return {}
	_configure_interaction(main)
	var render_frames := 0
	while main.replay_data.has_next_frame() and render_frames < 1000:
		var delta := 0.2 if long_frame and render_frames == 0 else 1.0 / float(hz)
		main._advance_gameplay_clock(delta)
		render_frames += 1
	_check(render_frames < 1000, "Playback schedule failed to consume the committed replay.")
	var evidence := {
		"hash": main.simulation_state_hash(),
		"tick": main.simulation_tick_index,
		"bomb_edges": int(main.gameplay_input_buffer.consumed_edges.bomb),
		"pause_edges": int(main.gameplay_input_buffer.consumed_edges.pause),
		"dropped_ticks": int(main.fixed_tick_clock.dropped_ticks),
		"accepted_ticks": int(main.fixed_tick_clock.accepted_ticks),
		"render_frames": render_frames,
		"score": int(main.game_manager_ref.score),
		"bombs": int(main.game_manager_ref.bombs),
		"enemy_interaction": int(main.game_manager_ref.score) > 0 or bool(main.enemies[0].get("dying", false)),
	}
	_free_main(main)
	return evidence

func _verify_runtime_schedules(document: Dictionary, fixture: Dictionary) -> Dictionary:
	var results := {
		"30": _play_schedule(document, 30),
		"60": _play_schedule(document, 60),
		"120": _play_schedule(document, 120),
		"long": _play_schedule(document, 60, true),
	}
	var normal_hash := String(results["60"].get("hash", ""))
	_check(not normal_hash.is_empty(), "Real-runtime replay did not produce a state hash.")
	_check(results["30"].hash == normal_hash and results["120"].hash == normal_hash, "30/60/120 Hz production playback hashes diverged: %s" % [results])
	for rate in ["30", "60", "120"]:
		_check(int(results[rate].bomb_edges) == 1 and int(results[rate].pause_edges) == 0, "%s Hz replay edge consumption mismatch." % rate)
		_check(int(results[rate].dropped_ticks) == 0, "%s Hz replay unexpectedly dropped simulation ticks." % rate)
		_check(bool(results[rate].enemy_interaction), "%s Hz replay did not exercise the enemy interaction." % rate)
		_check(int(results[rate].bombs) == 2, "%s Hz replay bomb state diverged." % rate)
	_check(int(results.long.dropped_ticks) == 9, "Long-frame path did not explicitly account for all nine dropped ticks.")
	_check(int(results.long.bomb_edges) == 1, "Long-frame replay consumed the bomb edge incorrectly.")
	var expected_hash := String(fixture.get("expected_runtime_hash", ""))
	if expected_hash == "PENDING":
		print("M0_RUNTIME_HASH=%s" % normal_hash)
	else:
		_check(normal_hash == expected_hash, "Committed production runtime hash changed: %s expected %s." % [normal_hash, expected_hash])
	print("M0_RUNTIME_SCHEDULES=%s" % JSON.stringify(results))
	return results

func _header_values(mode: String, stage: int, phase_id: String = "") -> Dictionary:
	return {
		"build_version": "1.0.0-m0",
		"content_hash": "m0-baseline-content-v1",
		"seed": 20260714,
		"difficulty": "normal",
		"protagonist": "miko",
		"shot_type": "ofuda_trace",
		"mode": mode,
		"starting_stage": stage,
		"phase_id": phase_id,
	}

func _verify_replay_identity_and_rejection(document: Dictionary) -> void:
	for values in [
		_header_values("story", 1),
		_header_values("stage_practice", 3),
		_header_values("spell_practice", 4, "fixture_phase"),
	]:
		var source_header := ReplayHeader.new(values)
		var data := ReplayData.new()
		_check(data.start_recording(source_header), "Replay identity failed to start recording: %s" % [values])
		data.record_tick({"move_x": 12345, "move_y": -23456, "shoot": true, "focus": true, "bomb": true, "pause": false})
		var round_trip := ReplayData.new()
		_check(round_trip.load_dict(data.to_dict()), "Replay identity failed to round trip: %s" % [values])
		_check(round_trip.header.mode == values.mode and round_trip.header.starting_stage == values.starting_stage and round_trip.header.phase_id == values.phase_id, "Replay identity fields changed during round trip: %s" % [values])

	var caller_header := ReplayHeader.new(_header_values("stage_practice", 2))
	var isolated := ReplayData.new()
	_check(isolated.start_recording(caller_header), "Header isolation setup failed.")
	caller_header.mode = "unsupported_after_start"
	caller_header.starting_stage = 99
	_check(isolated.header.mode == "stage_practice" and isolated.header.starting_stage == 2, "ReplayData retained the caller's mutable header alias.")

	var loaded := ReplayData.new()
	_check(loaded.load_dict(document), "Replay rejection setup failed to load the fixture.")
	loaded.next_frame()
	var state_before := loaded.capture_runtime_state()
	_check(not loaded.start_playback(document, {"build_version": "wrong-build"}), "Playback accepted a build mismatch.")
	_check(loaded.capture_runtime_state() == state_before, "Build mismatch mutated playback state.")
	_check(not loaded.start_playback(document, {"content_hash": "wrong-content"}), "Playback accepted a content mismatch.")
	_check(loaded.capture_runtime_state() == state_before, "Content mismatch mutated playback state.")
	var bad_version := document.duplicate(true)
	bad_version.format_version = 999
	_check(not loaded.start_playback(bad_version), "Playback accepted an unsupported document version.")
	_check(loaded.capture_runtime_state() == state_before, "Version rejection mutated playback state.")
	var bad_mode := document.duplicate(true)
	bad_mode.header.mode = "extra"
	_check(not loaded.start_playback(bad_mode), "Playback accepted an unsupported mode.")
	_check(loaded.capture_runtime_state() == state_before, "Mode rejection mutated playback state.")
	var caller_document := document.duplicate(true)
	var caller_isolated := ReplayData.new()
	_check(caller_isolated.load_dict(caller_document), "Caller document isolation setup failed.")
	caller_document.frames[0].move_x = 32767
	caller_document.header.mode = "extra"
	_check(int(caller_isolated.frames[0].move_x) != 32767 and caller_isolated.header.mode == "story", "ReplayData retained caller-owned document aliases.")

	var main := _new_main()
	main.game_manager_ref.score = 77
	_check(not main.start_replay_playback(document, {"content_hash": "mismatch"}), "Main runtime accepted an incompatible replay.")
	_check(main.game_manager_ref.score == 77 and main.replay_runtime_mode == "none", "Rejected playback mutated live main runtime state.")
	_free_main(main)
	print("M0_REPLAY_IDENTITIES=story,stage_practice,spell_practice; isolation=pass; rejection=version,build,content,mode")

func _verify_tick_pause_path() -> void:
	var main := _new_main()
	main.game_manager_ref.practice_mode = false
	main._start_game()
	_check(main._advance_gameplay_clock(1.0 / 120.0, {"pause": true}) == 0, "Half tick unexpectedly executed simulation.")
	_check(main.game_manager_ref.state == "stage", "Pause edge acted before a simulation tick consumed it.")
	_check(main._advance_gameplay_clock(1.0 / 120.0, {"pause": false}) == 1, "Buffered pause tick did not execute.")
	_check(main.game_manager_ref.state == "paused", "Stage pause did not consume the authoritative tick snapshot.")
	_check(int(main.gameplay_input_buffer.consumed_edges.pause) == 1, "Pause edge was not consumed exactly once.")
	_free_main(main)

func _verify_aggregate_restore() -> void:
	var main := _new_main()
	main.game_manager_ref.practice_mode = false
	main._start_game()
	main.bullet_world.configure(4, 8, 4)
	main._sync_bullet_world_compatibility_views()
	_configure_interaction(main)
	main._init_boss()
	main.boss_state_machine.transition(main.boss, BossStateMachine.PHASE_ACTIVE)
	main.boss.entered = true
	main.boss.declaring = false
	main.game_manager_ref.score = 1234
	main.game_manager_ref.graze = 89
	main.game_manager_ref.shared_power = 17
	main.game_manager_ref.life_fragments = 2
	main.game_manager_ref.bomb_fragments = 1
	main._start_bomb()
	for offset in [0.0, 8.0, 16.0, 24.0]:
		main._spawn_bullet_player(340.0 + offset, 500.0, 0.0, -8.0)
	main.bullet_world.retire_slot(1)
	main._spawn_bullet_enemy(360.0, 200.0, 0.0, 1.0)
	_check(main.bullet_world.active_order() == [0, 2, 3, 1], "Fixture did not establish reused-slot active processing order.")
	main.fixed_tick_clock.push_frame_delta(1.0 / 120.0)
	var snapshot: Dictionary = main.capture_simulation_state()
	var restore_source: Dictionary = snapshot.duplicate(true)
	var immediate_hash: String = main.simulation_state_hash()
	_check(float(snapshot.clock.accumulator_seconds) > 0.0 and main.player_bombing and main.boss_alive and not main.enemies.is_empty(), "Aggregate fixture is missing partial clock, active bomb, Boss, or enemy state.")
	_check(snapshot.player.bomb_config is Dictionary and not snapshot.player.bomb_config.is_empty(), "Aggregate capture omitted player bomb configuration.")
	_check(int(snapshot.bullets.capacity) == 4 and snapshot.bullets.active_order == [0, 2, 3, 1], "Aggregate capture lost exact BulletWorld capacity/order/reuse state.")
	snapshot.manager.score = -1
	snapshot.player.bomb_config.clear()
	snapshot.bullets.active_bullets[0].state.x = -999.0
	_check(main.game_manager_ref.score == 1234 and not main.player_bomb_config.is_empty() and float(main.bullet_pool[0].x) != -999.0, "Capture aliases leaked caller mutation into live state.")

	main.player_x = 18.0
	main.game_manager_ref.score = 999999
	main.boss.hp = 1.0
	main._clear_bullets()
	var malformed: Dictionary = restore_source.duplicate(true)
	malformed.bullets.spawn_cursor = 999
	var before_rejection_hash: String = main.simulation_state_hash()
	_check(not main.restore_simulation_state(malformed), "Aggregate restore accepted a malformed BulletWorld cursor.")
	_check(main.simulation_state_hash() == before_rejection_hash, "Malformed aggregate snapshot partially mutated live state.")
	_check(main.restore_simulation_state(restore_source), "Valid aggregate simulation restore failed.")
	var restored_hash: String = main.simulation_state_hash()
	_check(restored_hash == immediate_hash, "Immediate hash changed across capture-mutate-restore.")

	var reference := _new_main()
	_check(reference.restore_simulation_state(restore_source), "Reference aggregate restore failed.")
	for tick in range(8):
		var input := {"move_x": 0.125 if tick < 4 else -0.25, "move_y": 0.0, "shoot": tick % 2 == 0, "focus": tick >= 4, "bomb": false, "pause": false}
		main._advance_gameplay_clock(1.0 / 60.0, input)
		reference._advance_gameplay_clock(1.0 / 60.0, input)
	var continued_hash: String = main.simulation_state_hash()
	_check(continued_hash == reference.simulation_state_hash(), "Continued simulation diverged after aggregate restore.")
	print("M0_RESTORE_HASHES=immediate:%s,restored:%s,continued:%s; accumulator=%s; bullet_order=%s; capacity=%d" % [immediate_hash, restored_hash, continued_hash, restore_source.clock.accumulator_seconds, restore_source.bullets.active_order, restore_source.bullets.capacity])
	_free_main(reference)
	_free_main(main)

func _run() -> void:
	var fixture := _fixture()
	if fixture.is_empty():
		quit(1)
		return
	var produced := _record_fixture(fixture)
	if produced.is_empty():
		quit(1)
		return
	_verify_runtime_schedules(produced, fixture)
	_verify_replay_identity_and_rejection(produced)
	_verify_tick_pause_path()
	_verify_aggregate_restore()
	if failed:
		quit(1)
	else:
		print("PASS: M0 production replay schedules, identities, rejection, input edges, and aggregate restore.")
		quit(0)

func _initialize() -> void:
	call_deferred("_run")
