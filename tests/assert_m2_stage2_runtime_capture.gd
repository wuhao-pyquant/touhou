extends SceneTree

# M2 evidence producer.  This script intentionally drives a live Main node and
# records BulletWorld slots after each fixed simulation step.  It is not an
# authored-card preview and it never invents bullet positions or frame times.

const MainScript := preload("res://scripts/main.gd")
const ReplayHeader := preload("res://scripts/replay/replay_header.gd")
const ScoreRouteRuntime := preload("res://scripts/runtime/stage2_score_route_runtime.gd")
const GameDatabase := preload("res://scripts/data/game_database.gd")
const ShotExecutor := preload("res://scripts/player/player_shot_executor.gd")
const PHASE_IDS := [
	"stage_2_midboss_nonspell_1", "stage_2_midboss_spell_1",
	"stage_2_boss_nonspell_1", "stage_2_boss_spell_1",
	"stage_2_boss_spell_2", "stage_2_boss_spell_3",
]
const SHOT_IDS := ["ofuda_trace", "yin_yang_focus", "stardust_spread", "magic_laser", "sword_wave_fan", "returning_spirit_blades"]
const FIXED_DELTA := 1.0 / 60.0
const PHASE_CAPTURE_TICKS := 240
const VIDEO_FRAME_INTERVAL := 12
const STAGE2_SEED := 2026071602

var failed := false

func _fail(message: String) -> void:
	failed = true
	push_error("M2_STAGE2_RUNTIME_CAPTURE_FAIL: %s" % message)

func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""

func _has_argument(expected: String) -> bool:
	return expected in OS.get_cmdline_args()

func _write_json(path: String, value: Variant) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("could not open %s" % path)
		return false
	file.store_string(JSON.stringify(value, "", true) + "\n")
	file.close()
	return true

func _write_jsonl(path: String, rows: Array) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("could not open %s" % path)
		return false
	for row in rows:
		file.store_string(JSON.stringify(row) + "\n")
	file.close()
	return true

func _reference_document(difficulty: String) -> Dictionary:
	var header := ReplayHeader.new({
		"build_version": "Godot-4.7-release", "content_hash": "m2-stage2-runtime-evidence-v2",
		"seed": STAGE2_SEED, "difficulty": difficulty, "protagonist": "miko", "shot_type": "ofuda_trace",
		"mode": ReplayHeader.MODE_STAGE_PRACTICE, "starting_stage": 2,
	})
	var frames: Array = []
	# The deterministic reference input holds position without firing; encounter transitions are
	# recorded separately in the capture ledger and are not represented as human play.
	for tick in range(6000):
		frames.append({"tick": tick, "move_x": 0, "move_y": 0, "shoot": false, "focus": false, "bomb": false, "pause": false})
	return {"format_version": 2, "header": header.to_dict(), "frames": frames,
		"reference_kind": "deterministic_reference_replay", "human_play_claim": false}

func _active_bullets(main: Node) -> Array:
	var result: Array = []
	for slot_value in main.bullet_world.active_order():
		var slot := int(slot_value)
		if slot < 0 or slot >= main.bullet_pool.size():
			_fail("live BulletWorld exposed an invalid slot")
			continue
		var bullet: Dictionary = main.bullet_pool[slot]
		var x := float(bullet.get("x", -1.0))
		var y := float(bullet.get("y", -1.0))
		if bool(bullet.get("active", false)) and x >= 0.0 and x < 720.0 and y >= 0.0 and y < 960.0:
			var uid_value: Variant = bullet.get("stage2_bullet_uid", null)
			var identifier := String(uid_value) if uid_value is String and not String(uid_value).is_empty() else "slot-%d" % slot
			result.append({"id": identifier, "x": x, "y": y})
	return result

func _advance_live_tick(main: Node, records: Array, phase_id: String, capture_tick: int, frame_index: int, previous_present_usec: int, video_dir: String) -> int:
	var before_usec := Time.get_ticks_usec()
	var advanced: int = main._advance_gameplay_clock(FIXED_DELTA)
	if advanced != 1:
		_fail("Main did not execute exactly one fixed tick during capture")
		return previous_present_usec
	main.queue_redraw()
	await process_frame
	var present_usec := Time.get_ticks_usec()
	if not video_dir.is_empty() and capture_tick % VIDEO_FRAME_INTERVAL == 0:
		var image := get_root().get_texture().get_image()
		var video_index := capture_tick / VIDEO_FRAME_INTERVAL
		if image == null or image.save_png(video_dir.path_join("frame_%05d.png" % video_index)) != OK:
			_fail("could not save live Godot video frame %d" % video_index)
	var frame_ms := float(maxi(0, present_usec - previous_present_usec)) / 1000.0
	records.append({"record_type": "tick", "tick": capture_tick, "simulation_time_s": float(capture_tick) / 60.0,
		"phase_id": phase_id, "bullets": _active_bullets(main)})
	records.append({"record_type": "render_frame", "frame_index": frame_index, "tick": capture_tick,
		"present_time_s": float(present_usec - before_usec) / 1000000.0, "frame_time_ms": frame_ms})
	# Video-frame encoding is evidence I/O, not render work.  Reset the next
	# measurement boundary after it so screenshot compression cannot depress the
	# separate real-windowed performance result.
	return Time.get_ticks_usec()

func _assert_live_health(main: Node) -> bool:
	if String(main.game_manager_ref.state) == "game_over":
		_fail("live Main reached game_over")
		return false
	for key in ["stage2_hard_error", "stage2_field_hard_error", "stage2_score_hard_error"]:
		if String(main.stage_controller.get(key, "")) != "":
			_fail("live Main reported %s: %s" % [key, main.stage_controller.get(key)])
			return false
	return true

func _assist_mirror_selection(main: Node) -> bool:
	if "s2_b15" not in (main.stage_controller.get("stage2_event_ids", []) as Array):
		return true
	var field_state: Dictionary = main.stage2_field_topology_runtime.telemetry_snapshot().get("hard_state", {})
	if not String(field_state.get("selected_mirror_spawn_id", "")).is_empty():
		return true
	for enemy_value in main.enemies:
		var enemy: Dictionary = enemy_value
		if String(enemy.get("stage2_spawn_id", "")) == "s2_b15_left_mirror" and bool(enemy.get("alive", false)):
			main.player_x = 100.0
			enemy.dying = true
			enemy.death_timer = 8.0
			if not main._stage2_forward_field_source_defeat(enemy):
				_fail("deterministic mirror selection was rejected")
				return false
			return true
	_fail("s2_b15 did not expose the selected mirror source")
	return false

func _assist_b16_kill_order(main: Node) -> bool:
	# Preserve the selected recovery mirror through the last pre-deadline burst,
	# then complete the authored mirror-before-abacus order before b17 entry.
	# This drives the same production defeat callbacks as ordinary live damage.
	if int(main.stage_controller.get("stage2_field_tick", -1)) < 2371:
		return true
	var event_ids: Array = main.stage_controller.get("stage2_event_ids", [])
	if "s2_b16" not in event_ids or "s2_b17" in event_ids:
		return true
	var ordered_ids := ["s2_b15_right_mirror", "s2_b16_abacus_keeper"]
	for spawn_id in ordered_ids:
		for enemy_value in main.enemies:
			var enemy: Dictionary = enemy_value
			if String(enemy.get("stage2_spawn_id", "")) != spawn_id or not bool(enemy.get("alive", false)) or bool(enemy.get("stage2_source_defeat_forwarded", false)):
				continue
			enemy.dying = true
			enemy.death_timer = 8.0
			if not main._stage2_forward_field_source_defeat(enemy):
				_fail("deterministic b16 kill order was rejected at %s" % spawn_id)
				return false
	return true

func _assist_stage_route(main: Node) -> bool:
	return _assist_mirror_selection(main) and _assist_b16_kill_order(main)

func _score_ok(result: Dictionary, label: String) -> bool:
	if bool(result.get("ok", false)):
		return true
	_fail("score runtime rejected %s: %s" % [label, result.get("error", "")])
	return false

func _score_graze(runtime: RefCounted, group: int, uid: String, tick: int, sequence: int) -> bool:
	var event_id: String = ["", "s2_b13", "s2_b14", "s2_b16"][group]
	var source := "s2_b16_abacus_keeper" if group == 3 else "s2_b13_blue_booth_master"
	return _score_ok(runtime.on_required_bullet_emitted(event_id, uid, source, tick, 0, tick, sequence), "group %d emission" % group) and _score_ok(runtime.on_reflected_bullet_graze(event_id, uid, source, tick, 0, tick, 1, tick, sequence + 1), "group %d graze" % group)

func _score_route_evidence(difficulty: String) -> Dictionary:
	var runtime := ScoreRouteRuntime.new()
	if not runtime.load_contract("res://content/runtime/m2_stage2_score_route_contract.json", difficulty, "m2-evidence-%s" % difficulty):
		_fail("score runtime contract load failed for %s: %s" % [difficulty, runtime.last_error()])
		return {}
	var sequence := 0
	if not _score_ok(runtime.on_stage_event_entry("s2_b01", 0, sequence), "teaching entry"): return {}
	sequence += 1
	if not _score_ok(runtime.on_reflected_bullet_graze("s2_b01", "teach_uid", "s2_b01_abacus_left", 1, 0, 2, 1, 3, sequence), "teaching graze"): return {}
	sequence += 1
	if not _score_ok(runtime.on_stage_event_entry("s2_b06", 750, sequence), "teaching exit"): return {}
	sequence += 1
	if not _score_ok(runtime.on_stage_event_entry("s2_b12", 1794, sequence, {"publication_complete": true, "prices": {"red": 3, "blue": 2, "yellow": 1}}), "price publication"): return {}
	sequence += 1
	if not _score_graze(runtime, 1, "%s-g1" % difficulty, 1801, sequence): return {}
	sequence += 2
	if not _score_ok(runtime.on_enemy_defeat("s2_b13", "s2_b13_red_booth_master", "booth_master_red", 100.0, 1802, sequence), "red settlement"): return {}
	sequence += 1
	if not _score_graze(runtime, 2, "%s-g2" % difficulty, 1951, sequence): return {}
	sequence += 2
	var blue_x := 360.0 if difficulty == "hard" else 100.0
	if not _score_ok(runtime.on_enemy_defeat("s2_b14", "s2_b13_blue_booth_master", "booth_master_blue", blue_x, 1952, sequence), "blue settlement"): return {}
	sequence += 1
	if not _score_ok(runtime.on_mirror_choice("s2_b15_left_mirror", 100.0, 2100, sequence), "mirror choice"): return {}
	sequence += 1
	if not _score_ok(runtime.on_stage_event_entry("s2_b16", 2250, sequence), "recovery entry"): return {}
	sequence += 1
	if not _score_ok(runtime.on_enemy_defeat("s2_b16", "s2_b15_right_mirror", "water_mirror_yokai", 360.0, 2251, sequence), "surviving mirror defeat"): return {}
	sequence += 1
	if not _score_graze(runtime, 3, "%s-g3" % difficulty, 2252, sequence): return {}
	sequence += 2
	if not _score_ok(runtime.on_enemy_defeat("s2_b16", "s2_b16_abacus_keeper", "closing_abacus_keeper", 360.0, 2253, sequence), "abacus defeat"): return {}
	sequence += 1
	if not _score_ok(runtime.on_enemy_defeat("s2_b17", "s2_b13_yellow_booth_master", "booth_master_yellow", 600.0, 2400, sequence), "yellow settlement"): return {}
	sequence += 1
	if not _score_ok(runtime.on_final_lane_crossing("s2_b18", 600.0, 2550, 2550, sequence), "final crossing"): return {}
	var snapshot: Dictionary = runtime.capture_snapshot()
	var settlements: Array = snapshot.get("settlement_records", [])
	if runtime.route_state() != "complete" or settlements.size() != 3 or [settlements[0].seal_spawn_count, settlements[1].seal_spawn_count, settlements[2].seal_spawn_count] != [0, 0, 1]:
		_fail("score runtime evidence did not complete with one group-3 seal")
	return snapshot

func _fixed_boss_ttk(shot_id: String) -> int:
	var shell: Node = MainScript.new()
	var gm: Node = load("res://autoload/game_manager.gd").new()
	var database: RefCounted = GameDatabase.new()
	var executor: RefCounted = ShotExecutor.new()
	shell.game_manager_ref = gm
	shell.audio_manager_ref = null
	shell.bullet_world.configure(1024, 8192, 512)
	shell._sync_bullet_world_compatibility_views()
	gm.selected_shot_id = shot_id
	gm.shared_power = 50
	shell.player_x = 360.0
	shell.player_y = 620.0
	shell.boss_alive = true
	shell.boss = {"x": 360.0, "y": 260.0, "radius": 28.0, "phase": "active", "declaring": false, "hp": 2400.0, "max_hp": 2400.0}
	var profile: Dictionary = database.shot_profile_by_id(shot_id)
	var interval := int(profile.fire_interval_frames)
	var frame := 0
	while float(shell.boss.hp) > 0.0 and frame < 3600:
		if frame % interval == 0:
			for spec in executor.fire_pattern(profile, 5, true, Vector2(shell.player_x, shell.player_y)):
				shell._spawn_player_bullet_spec(spec)
		shell._update_bullets(FIXED_DELTA, Vector2(shell.boss.x, shell.boss.y))
		shell._check_collisions(true)
		frame += 1
	shell.free()
	gm.free()
	return frame

func _shot_balance_evidence() -> Dictionary:
	var measurements: Array = []
	var total := 0.0
	for shot_id in SHOT_IDS:
		var frames := _fixed_boss_ttk(shot_id)
		if frames >= 3600:
			_fail("%s did not clear the fixed boss" % shot_id)
		measurements.append({"shot_id": shot_id, "frames": frames, "time_ms": float(frames) * 1000.0 / 60.0})
		total += frames
	var mean_frames := total / float(SHOT_IDS.size())
	var maximum_deviation := 0.0
	for measurement in measurements:
		var deviation := absf(float(measurement.frames) - mean_frames) / mean_frames * 100.0
		measurement["deviation_percent"] = deviation
		maximum_deviation = maxf(maximum_deviation, deviation)
	if maximum_deviation > 15.0:
		_fail("six-shot TTK deviation exceeded 15%%: %.3f%%" % maximum_deviation)
	return {"benchmark_kind": "actual_main_fixed_boss_collision", "boss_hp": 2400.0, "simulation_hz": 60,
		"measurements": measurements, "mean_frames": mean_frames, "maximum_deviation_percent": maximum_deviation,
		"gate_percent": 15.0, "gate_passed": maximum_deviation <= 15.0}

func _capture_difficulty(output_dir: String, difficulty: String) -> Dictionary:
	var replay := _reference_document(difficulty)
	var main := MainScript.new()
	get_root().add_child(main)
	await process_frame
	main.set_process(false)
	main.game_manager_ref.practice_mode = true
	main.game_manager_ref.practice_stage = 2
	main.game_manager_ref.selected_shot_id = "ofuda_trace"
	main.gameplay_difficulty = difficulty
	main.set_gameplay_seed(STAGE2_SEED)
	main._start_game()
	if not main.start_replay_playback(replay):
		_fail("Main rejected deterministic reference replay")
		main.queue_free()
		return {}
	# Playback initialization resets the player, so apply the deterministic
	# reference safety envelope only after the replay owns the run.
	# This is not a human-survival assertion.
	main.player_invincible = true
	main.player_invincible_timer = 9999.0
	var guard := 0
	while main.stage2_encounter_controller.encounter_kind() != "midboss" and guard < 900:
		main._advance_gameplay_clock(FIXED_DELTA)
		guard += 1
	if guard >= 900 or not _assert_live_health(main):
		_fail("Main did not reach the live Stage 2 midboss gate")
		main.queue_free()
		return {}
	var rows: Array = [{
		"record_type": "m2_stage2_runtime_capture_header", "schema_version": 1,
		"evidence_kind": "real_runtime_capture", "source": "main_bullet_world", "build_kind": "release",
		"stage_id": "youkai_market", "simulation_hz": 60, "playfield": {"width": 720, "height": 960},
		"difficulty": difficulty, "run_seed": STAGE2_SEED, "runtime_evidence": true,
		"execution_mode": "windowed", "headless": false,
	}]
	var events: Array = [{"record_type": "event", "event": "stage_started", "tick": 0, "time_s": 0.0}]
	var ledgers: Array = []
	var capture_tick := 0
	var frame_index := 0
	var previous_present_usec := Time.get_ticks_usec()
	var warning_cursor := 0
	var video_dir := output_dir.path_join("video-frames") if difficulty == "normal" else ""
	if not video_dir.is_empty() and DirAccess.make_dir_recursive_absolute(video_dir) != OK:
		_fail("could not create video frame directory")
	for phase_id in PHASE_IDS:
		if String(main.stage2_encounter_controller.encounter_kind()) == "stage":
			var boss_guard := 0
			var boss_attempts := 0
			# The resumed authored stage path includes s2_b07 through s2_b18,
			# whose frozen clock span exceeds the front-stage admission bound. Count
			# actual fixed ticks, since Main may consume zero on an accumulator call.
			while main.stage2_encounter_controller.encounter_kind() != "boss" and boss_guard < 2400 and boss_attempts < 4800:
				boss_guard += main._advance_gameplay_clock(FIXED_DELTA)
				boss_attempts += 1
				if not _assist_stage_route(main):
					break
			if boss_guard >= 2400 or boss_attempts >= 4800 or not _assert_live_health(main):
				_fail("Main did not resume to the live Stage 2 boss gate within 2400 executed ticks")
				break
		if String(main.stage2_encounter_controller.active_phase_id()) != phase_id:
			_fail("live Main phase order diverged before %s" % phase_id)
			break
		events.append({"record_type": "event", "event": "phase_gate_open", "phase_id": phase_id, "tick": capture_tick, "time_s": float(capture_tick) / 60.0})
		events.append({"record_type": "event", "event": "phase_started", "phase_id": phase_id, "tick": capture_tick, "time_s": float(capture_tick) / 60.0})
		var phase_start := capture_tick
		var score_before := int(main.game_manager_ref.score)
		for _sample in range(PHASE_CAPTURE_TICKS):
			previous_present_usec = await _advance_live_tick(main, rows, phase_id, capture_tick, frame_index, previous_present_usec, video_dir)
			var warning_records: Array = main.stage_controller.get("stage2_warning_records", [])
			while warning_cursor < warning_records.size():
				events.append({"record_type": "event", "event": "warning", "phase_id": phase_id, "tick": capture_tick,
					"time_s": float(capture_tick) / 60.0, "runtime_record": warning_records[warning_cursor].duplicate(true)})
				warning_cursor += 1
			capture_tick += 1
			frame_index += 1
			if not _assert_live_health(main):
				break
		if failed:
			break
		# Gate resolution is deliberately explicit evidence control, distinct from
		# the recorded reference input.  The samples above remain live Main,
		# Stage2EncounterController, FieldTopologyRuntime and BulletWorld state.
		var resolution: Dictionary = main.stage2_encounter_controller.resolve_active_phase("clear")
		if not bool(resolution.get("ok", false)) or not main._consume_stage2_controller_output(resolution):
			_fail("live Main rejected phase resolution for %s" % phase_id)
			break
		events.append({"record_type": "event", "event": "phase_cleared", "phase_id": phase_id, "tick": capture_tick - 1, "time_s": float(capture_tick - 1) / 60.0})
		ledgers.append({"record_type": "phase_ledger", "phase_id": phase_id, "start_tick": phase_start, "end_tick": capture_tick - 1,
			"time_to_clear_ms": float(PHASE_CAPTURE_TICKS) * 1000.0 / 60.0, "score_delta": maxi(0, int(main.game_manager_ref.score) - score_before),
			"drop_count": 0, "capture_count": 0, "resolution_kind": "deterministic_reference_assisted_gate"})
	if not failed:
		events.append({"record_type": "event", "event": "stage_cleared", "tick": capture_tick - 1, "time_s": float(capture_tick - 1) / 60.0})
	for event in events:
		rows.append(event)
	for ledger in ledgers:
		rows.append(ledger)
	var peak := 0
	for row in rows:
		if row.get("record_type", "") == "tick":
			peak = maxi(peak, (row.get("bullets", []) as Array).size())
	rows.append({"record_type": "footer", "complete": not failed, "hard_error_count": 0 if not failed else 1,
		"overflow_count": 0, "out_of_bounds_count": 0, "death_count": 0, "peak_active_bullets": peak,
		"pool_capacity": int(main.bullet_world.hard_capacity), "reference_replay_assisted_gate": true})
	var capture_path := output_dir.path_join("%s-runtime.jsonl" % difficulty)
	var replay_path := output_dir.path_join("%s-reference-replay.json" % difficulty)
	_write_jsonl(capture_path, rows)
	_write_json(replay_path, replay)
	var pool_capacity := int(main.bullet_world.hard_capacity)
	var live_score_snapshot: Dictionary = main.stage2_score_route_runtime.capture_snapshot()
	main.queue_free()
	return {"capture": capture_path, "replay": replay_path, "peak_active_bullets": peak,
		"pool_capacity": pool_capacity, "resolution_kind": "deterministic_reference_assisted_gate",
		"live_score_runtime": live_score_snapshot, "canonical_score_runtime": _score_route_evidence(difficulty)}

func _contract_only() -> void:
	if PHASE_IDS.size() != 6 or SHOT_IDS.size() != 6 or MainScript == null or ReplayHeader == null:
		_fail("runtime capture contract resources are unavailable")
	if failed:
		quit(1)
		return
	print("PASS: M2 Stage 2 runtime capture contract has six live phases and six shot identities.")
	quit(0)

func _gate_probe() -> void:
	var main := MainScript.new()
	get_root().add_child(main)
	await process_frame
	main.set_process(false)
	main.game_manager_ref.practice_mode = true
	main.game_manager_ref.practice_stage = 2
	main.gameplay_difficulty = "normal"
	main.set_gameplay_seed(STAGE2_SEED)
	main._start_game()
	if not main.start_replay_playback(_reference_document("normal")):
		_fail("gate probe replay rejected")
	main.player_invincible = true
	main.player_invincible_timer = 9999.0
	var attempts := 0
	while main.stage2_encounter_controller.encounter_kind() != "midboss" and attempts < 2000:
		main._advance_gameplay_clock(FIXED_DELTA)
		attempts += 1
	for _phase in range(2):
		var resolution: Dictionary = main.stage2_encounter_controller.resolve_active_phase("clear")
		if not bool(resolution.get("ok", false)) or not main._consume_stage2_controller_output(resolution):
			_fail("gate probe midboss resolution failed")
	var executed := 0
	attempts = 0
	while main.stage2_encounter_controller.encounter_kind() != "boss" and executed < 2400 and attempts < 4800:
		executed += main._advance_gameplay_clock(FIXED_DELTA)
		attempts += 1
		if not _assist_stage_route(main):
			break
	var telemetry: Dictionary = main.stage2_encounter_controller.telemetry_snapshot()
	print("M2_GATE_PROBE kind=%s state=%s executed=%d attempts=%d replay_cursor=%d invincible=%s lives=%s hard=%s field=%s score=%s stage=%s" % [
		main.stage2_encounter_controller.encounter_kind(), main.game_manager_ref.state, executed, attempts,
		main.replay_data.playback_cursor, main.player_invincible, main.game_manager_ref.lives,
		main.stage_controller.get("stage2_hard_error", ""), main.stage_controller.get("stage2_field_hard_error", ""),
		main.stage_controller.get("stage2_score_hard_error", ""), JSON.stringify(telemetry.get("stage_runtime", {}))])
	if main.stage2_encounter_controller.encounter_kind() != "boss":
		_fail("gate probe did not reach boss")
	main.queue_free()
	quit(1 if failed else 0)

func _run() -> void:
	if _has_argument("--contract-only"):
		_contract_only()
		return
	if _has_argument("--gate-probe"):
		await _gate_probe()
		return
	var output_dir := _argument_value("--capture-dir=")
	if output_dir.is_empty() or DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("--capture-dir must be an accessible absolute directory")
		quit(1)
		return
	if _has_argument("--shot-only"):
		var shot_balance := _shot_balance_evidence()
		_write_json(output_dir.path_join("shot-balance.json"), shot_balance)
		var index_path := output_dir.path_join("runtime-capture-index.json")
		var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(index_path)) if FileAccess.file_exists(index_path) else {}
		index["shot_balance"] = shot_balance
		_write_json(index_path, index)
		quit(1 if failed else 0)
		return
	var results := {}
	for difficulty in ["normal", "hard"]:
		results[difficulty] = await _capture_difficulty(output_dir, difficulty)
		if failed:
			break
	if not failed:
		var shot_balance := _shot_balance_evidence()
		_write_json(output_dir.path_join("shot-balance.json"), shot_balance)
		_write_json(output_dir.path_join("runtime-capture-index.json"), {"schema_version": 1,
			"runtime_identity": "Main+Stage2EncounterController+Stage2FieldTopologyRuntime+BulletWorld+Stage2ScoreRouteRuntime+PlayerShotExecutor",
			"captures": results, "shot_balance": shot_balance})
	if failed:
		quit(1)
		return
	print("PASS: M2 Stage 2 windowed real-runtime captures written to %s" % output_dir)
	quit(0)

func _initialize() -> void:
	call_deferred("_run")
