extends SceneTree

const StageDirector := preload("res://scripts/runtime/stage_director.gd")
const Stage2EncounterController := preload("res://scripts/runtime/stage2_encounter_controller.gd")
const DanmakuPatternRuntime := preload("res://scripts/runtime/danmaku_pattern_runtime.gd")
const GameplayInputBuffer := preload("res://scripts/runtime/gameplay_input_buffer.gd")
const MainScript := preload("res://scripts/main.gd")

const EVENT_IDS := [
	"s2_b01", "s2_b02", "s2_b03", "s2_b04", "s2_b05", "s2_b06",
	"s2_b07", "s2_b08", "s2_b09", "s2_b10", "s2_b11", "s2_b12",
	"s2_b13", "s2_b14", "s2_b15", "s2_b16", "s2_b17", "s2_b18",
]
const PHASE_IDS := [
	"stage_2_midboss_nonspell_1", "stage_2_midboss_spell_1",
	"stage_2_boss_nonspell_1", "stage_2_boss_spell_1", "stage_2_boss_spell_2", "stage_2_boss_spell_3",
]
const FIXED_PLAYER_POSITION := Vector2(360.0, 720.0)
const LEGACY_SNAPSHOT_KEYS := [
	"version", "tick", "gameplay_seed", "gameplay_difficulty", "clock", "rng", "input", "manager",
	"current_stage_local", "stage_timer", "stage_controller", "player", "boss_alive", "boss", "bullets",
	"enemies", "items", "combat_effects", "replay",
]

class LegacyReplayStageDirector:
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
	push_error("M2_STAGE2_MAIN_FLOW_FAIL: %s" % message)
	return false

func _check_equal(actual, expected, message: String) -> bool:
	return _check(actual == expected, "%s Expected %s, got %s" % [message, expected, actual])

func _package() -> Dictionary:
	return StageDirector.new().stage2_package()

func _new_controller(difficulty: String = "normal", seed: int = 424242) -> RefCounted:
	var controller := Stage2EncounterController.new()
	_check(controller.configure(_package(), difficulty, seed), "Stage 2 controller rejected the approved package for %s: %s" % [difficulty, controller.validation_errors()])
	return controller

func _expected_topology(phase_index: int, difficulty: String) -> String:
	var phase_specs: Array = _package().get("phase_specs", [])
	return String(phase_specs[phase_index].get("difficulties", {}).get(difficulty, {}).get("topology_id", ""))

func _append_stage_ids(output: Dictionary, destination: Array) -> void:
	for event_value in output.get("stage_events", []):
		destination.append(String(event_value.get("id", "")))

func _advance_until_encounter(controller: RefCounted, encounter_kind: String, stage_ids: Array, maximum_steps: int = 3000) -> Dictionary:
	var last_output: Dictionary = {}
	var steps := 0
	while controller.encounter_kind() != encounter_kind and steps < maximum_steps:
		last_output = controller.advance(FIXED_PLAYER_POSITION)
		_check(bool(last_output.get("ok", false)), "Controller advance failed before %s: %s" % [encounter_kind, last_output])
		if not bool(last_output.get("ok", false)):
			return last_output
		_append_stage_ids(last_output, stage_ids)
		steps += 1
	_check(steps < maximum_steps, "Controller did not reach %s within the bounded fixed-tick trace." % encounter_kind)
	return last_output

func _resolve_current_phase(controller: RefCounted, outcome: String = "clear") -> Dictionary:
	var result: Dictionary = controller.resolve_active_phase(outcome)
	_check(bool(result.get("ok", false)), "Controller rejected %s for %s: %s" % [outcome, controller.active_phase_id(), result])
	return result

func _advance_trace(controller: RefCounted, count: int) -> Array:
	var trace: Array = []
	for _index in range(count):
		var output: Dictionary = controller.advance(FIXED_PLAYER_POSITION)
		_check(bool(output.get("ok", false)), "Continuation trace hit a hard error: %s" % output)
		trace.append(output.duplicate(true))
	return trace

func _assert_director_package_and_legacy_isolation() -> void:
	var director := StageDirector.new()
	var legacy_before := {}
	for stage_index in [1, 3, 4, 5, 6]:
		legacy_before[stage_index] = {
			"controller": director.stage_controller(stage_index),
			"boss_cards": director.boss_cards(stage_index),
			"boss": director.boss_definition(stage_index),
			"midboss": director.midboss_definition(stage_index),
		}
	var package: Dictionary = director.stage2_package()
	_check(not package.is_empty(), "StageDirector failed to load the approved Stage 2 package.")
	_check_equal(String(package.get("stage_spec", {}).get("stage_id", "")), "stage_2_yokai_market", "Stage 2 package identity drifted.")
	_check_equal((package.get("stage_spec", {}).get("events", []) as Array).size(), 18, "Stage 2 package event count drifted.")
	_check_equal((package.get("phase_specs", []) as Array).map(func(phase): return String(phase.get("id", ""))), PHASE_IDS, "Stage 2 package phase order drifted.")
	for stage_index in [1, 3, 4, 5, 6]:
		var before: Dictionary = legacy_before[stage_index]
		_check_equal(director.stage_controller(stage_index), before.controller, "Stage 2 package loading mutated legacy stage %d controller." % stage_index)
		_check_equal(director.boss_cards(stage_index), before.boss_cards, "Stage 2 package loading mutated legacy stage %d cards." % stage_index)
		_check_equal(director.boss_definition(stage_index), before.boss, "Stage 2 package loading mutated legacy stage %d boss." % stage_index)
		_check_equal(director.midboss_definition(stage_index), before.midboss, "Stage 2 package loading mutated legacy stage %d midboss." % stage_index)

func _assert_exact_flow_and_outputs() -> void:
	var controller := _new_controller("normal", 90210)
	var stage_ids: Array = []
	var midboss_gate := _advance_until_encounter(controller, "midboss", stage_ids, 800)
	_check_equal(stage_ids, EVENT_IDS.slice(0, 6), "Stage front or midboss gate event order drifted.")
	_check_equal(String(midboss_gate.get("encounter_started", {}).get("owner_id", "")), "abacus_tsukumogami", "Midboss owner was not sourced from the approved phase.")
	_check_equal(controller.active_phase_id(), PHASE_IDS[0], "First approved midboss phase did not become active.")
	_check_equal(String(controller.active_phase_definition().topology_id), _expected_topology(0, "normal"), "First midboss phase did not select its authored Normal topology.")
	_check_equal(int(controller.telemetry_snapshot().stage_runtime.stage_tick), 751, "Stage clock did not pause at the exact midboss gate tick.")
	_check(bool(controller.telemetry_snapshot().stage_runtime.paused), "StageEncounterRuntime was not paused at s2_b06.")
	var expected_seed := DanmakuPatternRuntime.derive_phase_local_seed(90210, "danmaku.m1.s2.midboss.nonspell.1.v1")
	_check_equal(int(controller.telemetry_snapshot().phase_runtime.phase_seed), expected_seed, "Phase-local seed was not derived from gameplay seed plus stream identity.")

	var saw_movement := false
	var saw_warning := false
	var saw_event := false
	var saw_bullets := false
	for _tick in range(240):
		var output: Dictionary = controller.advance(FIXED_PLAYER_POSITION)
		_check(bool(output.get("ok", false)), "Midboss phase output trace failed.")
		saw_movement = saw_movement or not (output.get("boss_movements", []) as Array).is_empty()
		saw_warning = saw_warning or not (output.get("warnings", []) as Array).is_empty()
		saw_event = saw_event or not (output.get("events", []) as Array).is_empty()
		saw_bullets = saw_bullets or not (output.get("bullet_specs", []) as Array).is_empty()
	_check(saw_movement and saw_warning and saw_event and saw_bullets, "Approved phase movement/warning/event/bullet outputs were not all observable.")

	var phase_order: Array = []
	phase_order.append(controller.active_phase_id())
	var first_resolution := _resolve_current_phase(controller)
	_check_equal(String(first_resolution.get("phase_started", {}).get("id", "")), PHASE_IDS[1], "Second midboss phase did not start after the first clear.")
	_check_equal(String(controller.active_phase_definition().topology_id), _expected_topology(1, "normal"), "Second midboss phase did not select its authored Normal topology.")
	phase_order.append(controller.active_phase_id())
	var midboss_clear := _resolve_current_phase(controller)
	_check_equal(String(midboss_clear.get("gate_completion", {}).get("completion_token", "")), "stage2_midboss_cleared", "Midboss gate token drifted.")
	_check_equal(controller.encounter_kind(), "stage", "Stage did not resume after exactly two midboss phases.")
	var resume_output := controller.advance(FIXED_PLAYER_POSITION)
	_append_stage_ids(resume_output, stage_ids)
	_check_equal((resume_output.get("stage_events", []) as Array).map(func(event): return String(event.get("id", ""))), EVENT_IDS.slice(6, 12), "Stage did not resume with s2_b07..s2_b12 together at runtime tick 751.")
	_check_equal(int(resume_output.get("stage_tick", -1)), 751, "Midboss resume output tick drifted.")

	var boss_gate := _advance_until_encounter(controller, "boss", stage_ids, 1200)
	_check_equal(stage_ids, EVENT_IDS, "All 18 Stage 2 events were not emitted in exact order.")
	_check_equal(String(boss_gate.get("encounter_started", {}).get("owner_id", "")), "oni_market_leader", "Boss owner was not sourced from the approved phase.")
	for phase_index in range(2, PHASE_IDS.size()):
		_check_equal(controller.active_phase_id(), PHASE_IDS[phase_index], "Approved boss phase order drifted at index %d." % phase_index)
		_check_equal(String(controller.active_phase_definition().topology_id), _expected_topology(phase_index, "normal"), "Boss phase %d did not select its authored Normal topology." % phase_index)
		phase_order.append(controller.active_phase_id())
		var result := _resolve_current_phase(controller)
		if phase_index < PHASE_IDS.size() - 1:
			_check_equal(String(result.get("phase_started", {}).get("id", "")), PHASE_IDS[phase_index + 1], "Next approved boss phase did not start.")
		else:
			_check_equal(String(result.get("gate_completion", {}).get("completion_token", "")), "stage2_boss_cleared", "Boss gate token drifted.")
	_check_equal(phase_order, PHASE_IDS, "Resolved phase order was not exactly two midboss plus four boss phases.")
	_check_equal(controller.resolved_phase_ids(), PHASE_IDS, "Controller did not preserve the exact resolved phase prefix.")
	_check_equal(controller.encounter_kind(), "complete", "Stage 2 completed before or after the exact four-phase boss sequence.")

func _assert_timeout_and_topology_selection() -> void:
	var normal := _new_controller("normal", 77)
	var hard := _new_controller("hard", 77)
	_advance_until_encounter(normal, "midboss", [], 800)
	_advance_until_encounter(hard, "midboss", [], 800)
	_check(String(normal.active_phase_definition().topology_id) != String(hard.active_phase_definition().topology_id), "Normal and Hard selected the same authored topology.")
	_check_equal(String(hard.active_phase_definition().topology_id), _expected_topology(0, "hard"), "Controller did not select the authored Hard topology.")
	_check(int(normal.telemetry_snapshot().phase_runtime.phase_seed) == int(hard.telemetry_snapshot().phase_runtime.phase_seed), "Difficulty selection incorrectly changed the phase stream identity.")
	var timeout_ticks := int(normal.active_phase_definition().timeout_ticks)
	for _tick in range(timeout_ticks):
		var output: Dictionary = normal.advance(FIXED_PLAYER_POSITION)
		_check(bool(output.get("ok", false)), "Timeout fixture phase advance failed.")
	var timeout_result: Dictionary = normal.advance(FIXED_PLAYER_POSITION)
	_check_equal(String(timeout_result.get("phase_resolutions", [{}])[0].get("outcome", "")), "timeout", "Phase timeout did not resolve through the controller.")
	_check_equal(normal.active_phase_id(), PHASE_IDS[1], "Timeout did not advance to the next approved phase.")

func _assert_controller_snapshot_context(controller: RefCounted, label: String) -> void:
	var snapshot: Dictionary = controller.capture_snapshot()
	_check(controller.validate_snapshot(snapshot), "%s controller rejected its own snapshot." % label)
	var expected_trace := _advance_trace(controller, 24)
	var expected_final := controller.capture_snapshot()
	var restored := _new_controller(String(snapshot.difficulty), int(snapshot.gameplay_seed))
	_check(restored.restore_snapshot(snapshot), "%s controller snapshot restore failed." % label)
	_check_equal(_advance_trace(restored, 24), expected_trace, "%s continuation outputs diverged after restore." % label)
	_check_equal(restored.capture_snapshot(), expected_final, "%s continuation state diverged after restore." % label)
	var baseline := restored.capture_snapshot()
	var malformed := snapshot.duplicate(true)
	malformed.active_phase_index = 5
	_check(not restored.restore_snapshot(malformed), "%s accepted a malformed active phase cursor." % label)
	_check_equal(restored.capture_snapshot(), baseline, "%s malformed snapshot partially mutated controller state." % label)

func _assert_controller_snapshots() -> void:
	var ordinary := _new_controller("normal", 1101)
	_advance_trace(ordinary, 320)
	_assert_controller_snapshot_context(ordinary, "ordinary-stage")

	var midboss := _new_controller("normal", 1102)
	_advance_until_encounter(midboss, "midboss", [], 800)
	_advance_trace(midboss, 75)
	_assert_controller_snapshot_context(midboss, "midboss")

	var boss := _new_controller("hard", 1103)
	_advance_until_encounter(boss, "midboss", [], 800)
	_resolve_current_phase(boss)
	_resolve_current_phase(boss)
	_advance_until_encounter(boss, "boss", [], 1200)
	_advance_trace(boss, 75)
	_assert_controller_snapshot_context(boss, "boss")

func _new_main(difficulty: String = "normal", seed: int = 31337) -> Node:
	var main = MainScript.new()
	main.game_manager_ref = load("res://autoload/game_manager.gd").new()
	main.audio_manager_ref = null
	main.gameplay_difficulty = difficulty
	main.set_gameplay_seed(seed)
	main.fixed_tick_clock.reset()
	main.gameplay_input_buffer.reset()
	main.simulation_tick_index = 0
	main.current_tick_input = GameplayInputBuffer.empty_tick_frame(0)
	main.bullet_world.configure(4096, 8192, 512)
	main._sync_bullet_world_compatibility_views()
	main._set_active_stage(2)
	main._load_stage(2)
	main.game_manager_ref.state = "stage"
	return main

func _free_main(main: Node) -> void:
	if main == null:
		return
	var manager: Object = main.game_manager_ref
	main.free()
	if is_instance_valid(manager):
		manager.free()

func _sorted_snapshot_keys(snapshot: Dictionary) -> Array:
	var keys: Array = snapshot.keys()
	keys.sort()
	return keys

func _expected_legacy_snapshot_keys() -> Array:
	var keys: Array = LEGACY_SNAPSHOT_KEYS.duplicate()
	keys.sort()
	return keys

func _new_legacy_replay_main() -> Node:
	var main = MainScript.new()
	main.stage_director = LegacyReplayStageDirector.new()
	main.audio_manager_ref = null
	main.bullet_world.configure(64, 128, 16)
	main._sync_bullet_world_compatibility_views()
	return main

func _configure_legacy_replay_interaction(main: Node) -> void:
	main.stage_controller = {"boss_time": 999999.0, "boss_spawned": false, "triggered_waves": {}}
	main._spawn_enemy(360.0, 450.0, 2.0, "aimed", "straight", 0.0, 0.0)
	main.enemies[0].shoot_timer = 99999.0

func _assert_legacy_snapshot_and_replay_hash() -> void:
	var main := _new_main("normal", 7001)
	main._set_active_stage(1)
	main._load_stage(1)
	main.game_manager_ref.state = "stage"
	var snapshot: Dictionary = main.capture_simulation_state()
	_check_equal(int(snapshot.get("version", -1)), 2, "Legacy stage snapshot version drifted from v2.")
	_check(not snapshot.has("stage2_controller"), "Legacy stage snapshot gained a Stage 2 field.")
	_check_equal(_sorted_snapshot_keys(snapshot), _expected_legacy_snapshot_keys(), "Legacy stage snapshot field shape changed.")
	_check(main.validate_simulation_state(snapshot), "Legacy v2 snapshot no longer validates.")
	var legacy_hash := main.simulation_state_hash()
	var before_rejection := legacy_hash
	var forged_extension := snapshot.duplicate(true)
	forged_extension["stage2_controller"] = {}
	_check(not main.restore_simulation_state(forged_extension), "Legacy v2 restore accepted a forged Stage 2 extension.")
	_check_equal(main.simulation_state_hash(), before_rejection, "Rejected legacy extension partially mutated Main.")
	var forged_version := snapshot.duplicate(true)
	forged_version.version = 3
	_check(not main.restore_simulation_state(forged_version), "Legacy stage accepted the Stage 2 aggregate version.")
	_check_equal(main.simulation_state_hash(), before_rejection, "Rejected legacy version partially mutated Main.")
	_check(main.restore_simulation_state(snapshot), "Existing legacy v2 snapshot failed to restore.")
	_check_equal(main.simulation_state_hash(), legacy_hash, "Legacy v2 hash changed across restore.")
	var reference := _new_main("normal", 7001)
	_check(reference.restore_simulation_state(snapshot), "Fresh Main rejected an existing legacy v2 snapshot.")
	var input := {"move_x": 0.0, "move_y": 0.0, "shoot": false, "focus": false, "bomb": false, "pause": false}
	main._advance_gameplay_clock(1.0 / 60.0, input)
	reference._advance_gameplay_clock(1.0 / 60.0, input)
	_check_equal(main.simulation_state_hash(), reference.simulation_state_hash(), "Legacy v2 continuation hash diverged after restore.")
	_free_main(reference)
	_free_main(main)

	var fixture_file := FileAccess.open("res://tests/fixtures/m0/baseline_replay.json", FileAccess.READ)
	_check(fixture_file != null, "Could not open the committed M0 replay hash fixture.")
	if fixture_file == null:
		return
	var fixture_value = JSON.parse_string(fixture_file.get_as_text())
	_check(fixture_value is Dictionary, "Committed M0 replay hash fixture is malformed.")
	if not (fixture_value is Dictionary):
		return
	var fixture: Dictionary = fixture_value
	var replay_main := _new_legacy_replay_main()
	var expected_identity := {"build_version": "1.0.0-m0", "content_hash": "m0-baseline-content-v1"}
	_check(replay_main.start_replay_playback(fixture, expected_identity), "Focused assertion could not play the committed legacy replay.")
	_configure_legacy_replay_interaction(replay_main)
	var render_frames := 0
	while replay_main.replay_data.has_next_frame() and render_frames < 1000:
		replay_main._advance_gameplay_clock(1.0 / 60.0)
		render_frames += 1
	_check(render_frames < 1000, "Committed legacy replay did not finish in the bounded smoke trace.")
	var replay_snapshot: Dictionary = replay_main.capture_simulation_state()
	_check_equal(int(replay_snapshot.get("version", -1)), 2, "Committed legacy replay no longer captures v2.")
	_check(not replay_snapshot.has("stage2_controller"), "Committed legacy replay hash input gained Stage 2 fields.")
	_check_equal(_sorted_snapshot_keys(replay_snapshot), _expected_legacy_snapshot_keys(), "Committed replay snapshot field shape changed.")
	var committed_hash := String(fixture.get("expected_runtime_hash", ""))
	_check(not committed_hash.is_empty() and committed_hash != "PENDING", "Committed legacy replay hash evidence is unavailable.")
	_check_equal(replay_main.simulation_state_hash(), committed_hash, "Committed production replay hash changed.")
	_free_main(replay_main)

func _assert_main_binding() -> void:
	var main := _new_main("hard", 5150)
	_check(bool(main.stage_controller.get("stage2_bound", false)), "Main did not bind Stage 2 to the deterministic controller.")
	var rng_before: Dictionary = main.gameplay_rng.snapshot()
	var first_output: Dictionary = main.stage2_encounter_controller.advance(Vector2(main.player_x, main.player_y))
	main._consume_stage2_controller_output(first_output)
	_check_equal(main.gameplay_rng.snapshot(), rng_before, "Authored Stage 2 spawn timers consumed shared gameplay RNG.")
	_check_equal(main.enemies.size(), 3, "s2_b01 authored formation was not materialized.")
	var first_enemy: Dictionary = main.enemies[0]
	_check_equal(String(first_enemy.get("stage2_spawn_id", "")), "s2_b01_abacus_left", "Authored deterministic spawn ID was not preserved.")
	_check_equal(String(first_enemy.get("move_data", {}).get("path", "")), "vertical_settle", "Authored semantic movement path was not preserved.")
	_check_equal(String(first_enemy.get("authored_pattern", {}).get("primitive", "")), "rebound_bead", "Authored primitive was not preserved on the enemy dictionary.")
	_check(first_enemy.get("drop_item_ids") is Array, "Authored deterministic drops were not attached to the enemy dictionary.")

	var gate_output: Dictionary = {}
	var guard := 0
	while main.stage2_encounter_controller.encounter_kind() == "stage" and guard < 800:
		gate_output = main.stage2_encounter_controller.advance(Vector2(main.player_x, main.player_y))
		guard += 1
	main._consume_stage2_controller_output(gate_output)
	_check(main.boss_alive and String(main.boss.get("stage2_owner_id", "")) == "abacus_tsukumogami", "Main did not create the real Stage 2 midboss owner.")
	_check_equal(String(main.boss.get("stage2_phase_id", "")), PHASE_IDS[0], "Main boss seam did not mirror the controller phase ID.")
	_check_equal(String(main.game_manager_ref.state), "boss", "Main did not route the midboss through boss collision state.")
	main._clear_hostile_bullets()
	var hp_before := float(main.boss.hp)
	main._spawn_bullet_player(float(main.boss.x), float(main.boss.y), 0.0, 0.0, 5.0, Color.WHITE, 25.0)
	main._check_collisions(true)
	_check(float(main.boss.hp) < hp_before, "Existing player-shot/boss collision seam did not damage the Stage 2 owner.")
	var saw_main_movement := false
	var saw_main_bullets := false
	for _tick in range(240):
		var phase_output: Dictionary = main.stage2_encounter_controller.advance(Vector2(main.player_x, main.player_y))
		saw_main_movement = saw_main_movement or not (phase_output.get("boss_movements", []) as Array).is_empty()
		saw_main_bullets = saw_main_bullets or not (phase_output.get("bullet_specs", []) as Array).is_empty()
		main._consume_stage2_controller_output(phase_output)
	_check(saw_main_movement and saw_main_bullets, "Main did not consume phase movement and bullet-spec outputs.")
	_check(not (main.stage_controller.get("stage2_boss_movement_records", []) as Array).is_empty(), "Main did not retain boss movement telemetry records.")
	_check(not (main.stage_controller.get("stage2_warning_records", []) as Array).is_empty(), "Main did not retain phase warning records.")
	var first_clear := main.stage2_encounter_controller.resolve_active_phase("clear")
	main._consume_stage2_controller_output(first_clear)
	_check_equal(String(main.boss.get("stage2_phase_id", "")), PHASE_IDS[1], "Main did not transfer ownership to the second approved midboss phase.")
	var second_clear := main.stage2_encounter_controller.resolve_active_phase("clear")
	main._consume_stage2_controller_output(second_clear)
	_check(not main.boss_alive and String(main.game_manager_ref.state) == "stage", "Main did not release midboss ownership and resume stage state.")
	main._consume_stage2_controller_output(main.stage2_encounter_controller.advance(Vector2(main.player_x, main.player_y)))
	var boss_gate: Dictionary = {}
	guard = 0
	while main.stage2_encounter_controller.encounter_kind() == "stage" and guard < 1200:
		boss_gate = main.stage2_encounter_controller.advance(Vector2(main.player_x, main.player_y))
		guard += 1
	main._consume_stage2_controller_output(boss_gate)
	_check(main.boss_alive and String(main.boss.get("stage2_owner_id", "")) == "oni_market_leader", "Main did not create the real four-phase Stage 2 boss owner.")
	_check_equal(String(main.boss.get("stage2_phase_id", "")), PHASE_IDS[2], "Main boss ownership started on the wrong approved phase.")
	for phase_index in range(2, PHASE_IDS.size()):
		var boss_clear := main.stage2_encounter_controller.resolve_active_phase("clear")
		main._consume_stage2_controller_output(boss_clear)
		if phase_index < PHASE_IDS.size() - 1:
			_check_equal(String(main.boss.get("stage2_phase_id", "")), PHASE_IDS[phase_index + 1], "Main skipped an approved boss phase.")
	main._update_boss(1.0 / 60.0)
	_check_equal(String(main.game_manager_ref.state), "stage_clear", "Main finished Stage 2 anywhere other than after all four boss phases.")
	_free_main(main)

func _assert_legacy_main_routes() -> void:
	var main := _new_main()
	for stage_index in [1, 3, 4, 5, 6]:
		main._set_active_stage(stage_index)
		main._load_stage(stage_index)
		_check(not main.stage2_encounter_controller.is_configured(), "Legacy stage %d was routed through the Stage 2 controller." % stage_index)
		_check_equal(int(main.stage_controller.get("stage_index", -1)), stage_index, "Legacy stage %d controller route drifted." % stage_index)
		_check(not (main.stage_controller.get("waves", []) as Array).is_empty(), "Legacy stage %d lost its wave schedule." % stage_index)
		var snapshot: Dictionary = main.capture_simulation_state()
		_check_equal(int(snapshot.get("version", -1)), 2, "Legacy stage %d snapshot version drifted." % stage_index)
		_check(not snapshot.has("stage2_controller"), "Legacy stage %d snapshot gained Stage 2 state." % stage_index)
		_check_equal(_sorted_snapshot_keys(snapshot), _expected_legacy_snapshot_keys(), "Legacy stage %d snapshot field shape drifted." % stage_index)
	_free_main(main)

func _prepare_main_snapshot_context(kind: String, difficulty: String, seed: int) -> Node:
	var main := _new_main(difficulty, seed)
	match kind:
		"ordinary-stage":
			_advance_trace(main.stage2_encounter_controller, 320)
		"midboss":
			_advance_until_encounter(main.stage2_encounter_controller, "midboss", [], 800)
			_advance_trace(main.stage2_encounter_controller, 75)
			main._sync_stage2_phase_boss()
		"boss":
			_advance_until_encounter(main.stage2_encounter_controller, "midboss", [], 800)
			_resolve_current_phase(main.stage2_encounter_controller)
			_resolve_current_phase(main.stage2_encounter_controller)
			_advance_until_encounter(main.stage2_encounter_controller, "boss", [], 1200)
			_advance_trace(main.stage2_encounter_controller, 75)
			main._sync_stage2_phase_boss()
	main.stage_timer = float(main.stage2_encounter_controller.telemetry_snapshot().stage_runtime.stage_tick)
	return main

func _assert_aggregate_snapshot_context(kind: String, difficulty: String, seed: int) -> void:
	var main := _prepare_main_snapshot_context(kind, difficulty, seed)
	var snapshot: Dictionary = main.capture_simulation_state()
	_check_equal(int(snapshot.get("version", -1)), 3, "%s Stage 2 aggregate snapshot did not use the extended version." % kind)
	_check(not snapshot.stage2_controller.is_empty(), "%s aggregate snapshot omitted the Stage 2 controller." % kind)
	_check(main.validate_simulation_state(snapshot), "%s aggregate snapshot rejected its own Stage 2 state." % kind)
	var before_rejection := main.simulation_state_hash()
	var missing_controller := snapshot.duplicate(true)
	missing_controller.erase("stage2_controller")
	_check(not main.restore_simulation_state(missing_controller), "%s aggregate restore accepted a missing Stage 2 controller." % kind)
	_check_equal(main.simulation_state_hash(), before_rejection, "%s missing-controller snapshot partially mutated Main." % kind)
	var legacy_version := snapshot.duplicate(true)
	legacy_version.version = 2
	_check(not main.restore_simulation_state(legacy_version), "%s Stage 2 aggregate restore accepted legacy v2." % kind)
	_check_equal(main.simulation_state_hash(), before_rejection, "%s wrong-version Stage 2 snapshot partially mutated Main." % kind)
	var malformed := snapshot.duplicate(true)
	malformed.stage2_controller.version = 999
	_check(not main.restore_simulation_state(malformed), "%s aggregate restore accepted a malformed nested controller snapshot." % kind)
	_check_equal(main.simulation_state_hash(), before_rejection, "%s malformed aggregate snapshot partially mutated Main." % kind)
	var reference := _new_main(difficulty, seed)
	_check(main.restore_simulation_state(snapshot), "%s valid aggregate restore failed on source Main." % kind)
	_check(reference.restore_simulation_state(snapshot), "%s valid aggregate restore failed on reference Main." % kind)
	var input := {"move_x": 0.125, "move_y": 0.0, "shoot": false, "focus": true, "bomb": false, "pause": false}
	main._advance_gameplay_clock(1.0 / 60.0, input)
	reference._advance_gameplay_clock(1.0 / 60.0, input)
	_check_equal(main.simulation_state_hash(), reference.simulation_state_hash(), "%s aggregate continuation hash diverged after restore." % kind)
	_free_main(reference)
	_free_main(main)

func _assert_aggregate_snapshots() -> void:
	_assert_aggregate_snapshot_context("ordinary-stage", "normal", 6101)
	_assert_aggregate_snapshot_context("midboss", "normal", 6102)
	_assert_aggregate_snapshot_context("boss", "hard", 6103)

func _assert_fail_closed_configuration() -> void:
	var malformed := _package()
	malformed.phase_specs = (malformed.phase_specs as Array).duplicate(true)
	malformed.phase_specs.reverse()
	var rejected := Stage2EncounterController.new()
	_check(not rejected.configure(malformed, "normal", 1), "Controller accepted a reordered phase package.")
	_check(rejected.has_hard_error() and rejected.capture_snapshot().is_empty(), "Rejected configuration did not fail closed.")
	_check(not bool(rejected.advance(FIXED_PLAYER_POSITION).get("ok", true)), "Rejected controller still advanced.")

func _run() -> void:
	_assert_director_package_and_legacy_isolation()
	_assert_fail_closed_configuration()
	_assert_exact_flow_and_outputs()
	_assert_timeout_and_topology_selection()
	_assert_controller_snapshots()
	_assert_main_binding()
	_assert_legacy_main_routes()
	_assert_legacy_snapshot_and_replay_hash()
	_assert_aggregate_snapshots()
	if failed:
		quit(1)
		return
	print("PASS: M2 Stage 2 fixed-tick main flow, exact gates/phases, output plumbing, topology selection, and atomic snapshots.")
	quit(0)

func _initialize() -> void:
	call_deferred("_run")
