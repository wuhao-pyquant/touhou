extends SceneTree

const MainScript := preload("res://scripts/main.gd")
const Stage2EncounterController := preload("res://scripts/runtime/stage2_encounter_controller.gd")
const GameplayInputBuffer := preload("res://scripts/runtime/gameplay_input_buffer.gd")

const MIDBOSS_PHASE_ID := "stage_2_midboss_nonspell_1"
const BOSS_PHASE_ID := "stage_2_boss_nonspell_1"
const STAGE_SOURCE_FIELDS := ["stage2_source_event_id", "stage2_source_spawn_id", "stage2_source_enemy_id", "stage2_primitive", "stage2_routing"]
const LEGACY_SNAPSHOT_KEYS := [
	"version", "tick", "gameplay_seed", "gameplay_difficulty", "clock", "rng", "input", "manager",
	"current_stage_local", "stage_timer", "stage_controller", "player", "boss_alive", "boss", "bullets",
	"enemies", "items", "combat_effects", "replay",
]

var failed := false

func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	failed = true
	push_error("M2_STAGE2_BULLET_OBSERVABILITY_FAIL: %s" % message)
	return false

func _check_equal(actual, expected, message: String) -> bool:
	return _check(actual == expected, "%s Expected %s, got %s" % [message, expected, actual])

func _sorted_keys(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys

func _new_main(stage_index: int = 2, seed: int = 22002, capacity: int = 8) -> Node:
	var main = MainScript.new()
	main.game_manager_ref = load("res://autoload/game_manager.gd").new()
	main.audio_manager_ref = null
	main.gameplay_difficulty = "normal"
	main.set_gameplay_seed(seed)
	main.fixed_tick_clock.reset()
	main.gameplay_input_buffer.reset()
	main.simulation_tick_index = 0
	main.current_tick_input = GameplayInputBuffer.empty_tick_frame(0)
	main.bullet_world.configure(capacity, capacity, 1)
	main._sync_bullet_world_compatibility_views()
	main._set_active_stage(stage_index)
	main._load_stage(stage_index)
	main.game_manager_ref.state = "stage"
	return main

func _free_main(main: Node) -> void:
	if main == null:
		return
	var manager: Object = main.game_manager_ref
	main.free()
	if is_instance_valid(manager):
		manager.free()

func _only_active_entry(main: Node, label: String) -> Dictionary:
	var order: Array = main.bullet_world.active_order()
	_check_equal(order.size(), 1, "%s did not leave exactly one active bullet." % label)
	if order.size() != 1:
		return {}
	return {"slot": int(order[0]), "bullet": main.bullet_pool[int(order[0])]}

func _retire_only_bullet(main: Node, label: String) -> void:
	var entry := _only_active_entry(main, label)
	if entry.is_empty():
		return
	_check(main.bullet_world.retire_slot(int(entry.slot)), "%s active bullet could not be retired." % label)
	main._sync_bullet_world_compatibility_views()

func _phase_bullet_spec(phase_id: String) -> Dictionary:
	return {
		"position": Vector2(360.0, 160.0),
		"velocity": Vector2(0.0, 2.0),
		"radius": 6.0,
		"color": Color(0.2, 0.8, 0.9),
		"family_id": "circle",
		"lifetime": 360.0,
		"motion": {"kind": "reflect", "bounce_count": 1},
		"primitive": "rebound_bead",
		"phase_id": phase_id,
	}

func _install_practice_controller(main: Node, phase_id: String) -> Dictionary:
	var controller: RefCounted = Stage2EncounterController.new()
	_check(controller.configure(main.stage_director.stage2_package(), main.gameplay_difficulty, main.gameplay_seed), "%s fixture controller rejected the approved package." % phase_id)
	_check(controller.start_phase_practice(phase_id), "%s fixture controller rejected direct phase entry: %s" % [phase_id, controller.last_error()])
	main.stage2_encounter_controller = controller
	return controller.active_phase_definition()

func _assert_uid_sources_failure_and_reflection() -> void:
	var main: Node = _new_main(2, 22101, 1)
	_check_equal(int(main.stage_controller.get("stage2_next_bullet_uid", -1)), 1, "Stage 2 did not initialize its positive UID counter.")
	var observed_uids: Array = []
	var observed_slots: Array = []

	_check(main._spawn_bullet_player(360.0, 700.0, 0.0, -8.0), "Stage 2 player bullet allocation failed.")
	var player_entry := _only_active_entry(main, "player source")
	var player_bullet: Dictionary = player_entry.get("bullet", {})
	observed_uids.append(int(player_bullet.get("stage2_bullet_uid", -1)))
	observed_slots.append(int(player_entry.get("slot", -1)))
	_check_equal(String(player_bullet.get("type", "")), "player", "Player source class drifted.")
	_check(not player_bullet.has("stage2_reflection_count"), "Player bullet gained enemy reflection state.")
	var failed_counter := int(main.stage_controller.stage2_next_bullet_uid)
	_check(not main._spawn_bullet_player(380.0, 700.0, 0.0, -8.0), "Full BulletWorld accepted an extra player bullet.")
	_check_equal(int(main.stage_controller.stage2_next_bullet_uid), failed_counter, "Failed allocation consumed a Stage 2 UID.")
	_check_equal(int(_only_active_entry(main, "failed allocation survivor").bullet.stage2_bullet_uid), observed_uids[0], "Failed allocation replaced the active bullet.")
	_retire_only_bullet(main, "player source")

	_check(main._spawn_bullet_player(360.0, 700.0, 0.0, -1.0, 12.0, Color.WHITE, 1.0, false, -1, true), "Stage 2 bomb bullet allocation failed.")
	var bomb_entry := _only_active_entry(main, "bomb source")
	var bomb_bullet: Dictionary = bomb_entry.bullet
	observed_uids.append(int(bomb_bullet.stage2_bullet_uid))
	observed_slots.append(int(bomb_entry.slot))
	_check_equal(String(bomb_bullet.type), "bomb", "Bomb source class drifted.")
	_check(not bomb_bullet.has("stage2_reflection_count"), "Bomb bullet gained enemy reflection state.")
	_retire_only_bullet(main, "bomb source")

	main._spawn_stage2_authored_enemy("s2_fixture_event", {
		"id": "s2_fixture_spawn",
		"enemy_id": "fixture_yokai",
		"position": Vector2(360.0, 120.0),
		"movement": {"path": "fixture_hold", "to": Vector2(360.0, 120.0), "duration_ticks": 1},
		"pattern": {"primitive": "lane_fan", "start_delay_ticks": 0, "interval_ticks": 60, "routing": "fixture_lane_down"},
		"drop_item_ids": [],
	})
	main._update_enemies(1.0 / 60.0)
	var stage_entry := _only_active_entry(main, "authored stage-enemy source")
	var stage_bullet: Dictionary = stage_entry.bullet
	observed_uids.append(int(stage_bullet.stage2_bullet_uid))
	observed_slots.append(int(stage_entry.slot))
	_check_equal(String(stage_bullet.get("stage2_source_event_id", "")), "s2_fixture_event", "Stage-enemy event source was not propagated.")
	_check_equal(String(stage_bullet.get("stage2_source_spawn_id", "")), "s2_fixture_spawn", "Stage-enemy spawn source was not propagated.")
	_check_equal(String(stage_bullet.get("stage2_source_enemy_id", "")), "fixture_yokai", "Stage-enemy owner source was not propagated.")
	_check_equal(String(stage_bullet.get("stage2_primitive", "")), "lane_fan", "Stage-enemy primitive was not propagated.")
	_check_equal(String(stage_bullet.get("stage2_routing", "")), "fixture_lane_down", "Stage-enemy routing was not propagated.")
	_check_equal(int(stage_bullet.get("stage2_reflection_count", -1)), 0, "Stage 2 enemy bullet did not initialize reflection state.")
	stage_bullet.motion = {"kind": "reflect", "bounce_count": 2}
	stage_bullet.has_motion = true
	stage_bullet.x = 4.0
	stage_bullet.y = 300.0
	stage_bullet.vx = -2.0
	main._apply_enemy_bullet_bounce(stage_bullet)
	_check_equal(int(stage_bullet.stage2_reflection_count), 1, "Physical bounce did not increment the top-level reflection count once.")
	_check_equal(int(stage_bullet.motion.bounce_count), 1, "Physical bounce did not consume one motion bounce.")
	stage_bullet.x = 300.0
	stage_bullet.y = 300.0
	main._apply_enemy_bullet_bounce(stage_bullet)
	_check_equal(int(stage_bullet.stage2_reflection_count), 1, "Non-bounce motion incremented the reflection count.")
	_check_equal(int(stage_bullet.motion.bounce_count), 1, "Non-bounce motion consumed a bounce.")
	stage_bullet.x = float(main.SCREEN_W)
	main._apply_enemy_bullet_bounce(stage_bullet)
	_check_equal(int(stage_bullet.stage2_reflection_count), 2, "Second physical bounce did not produce exactly one reflection increment.")
	_check_equal(int(stage_bullet.motion.bounce_count), 0, "Second physical bounce did not exhaust the authored bounce budget.")
	_retire_only_bullet(main, "authored stage-enemy source")

	var midboss_definition := _install_practice_controller(main, MIDBOSS_PHASE_ID)
	main._consume_stage2_controller_output({"bullet_specs": [_phase_bullet_spec(MIDBOSS_PHASE_ID)]})
	var midboss_entry := _only_active_entry(main, "midboss phase source")
	var midboss_bullet: Dictionary = midboss_entry.bullet
	observed_uids.append(int(midboss_bullet.stage2_bullet_uid))
	observed_slots.append(int(midboss_entry.slot))
	_check_equal(String(midboss_bullet.get("stage2_source_phase_id", "")), MIDBOSS_PHASE_ID, "Midboss bullet lost its phase source.")
	_check_equal(String(midboss_bullet.get("stage2_source_owner_id", "")), String(midboss_definition.get("owner_id", "")), "Midboss bullet lost its owner source.")
	_check_equal(int(midboss_bullet.get("stage2_reflection_count", -1)), 0, "Reused pool slot leaked the prior reflection count into a midboss bullet.")
	_retire_only_bullet(main, "midboss phase source")

	var boss_definition := _install_practice_controller(main, BOSS_PHASE_ID)
	main._consume_stage2_controller_output({"bullet_specs": [_phase_bullet_spec(BOSS_PHASE_ID)]})
	var boss_entry := _only_active_entry(main, "boss phase source")
	var boss_bullet: Dictionary = boss_entry.bullet
	observed_uids.append(int(boss_bullet.stage2_bullet_uid))
	observed_slots.append(int(boss_entry.slot))
	_check_equal(String(boss_bullet.get("stage2_source_phase_id", "")), BOSS_PHASE_ID, "Boss bullet lost its phase source.")
	_check_equal(String(boss_bullet.get("stage2_source_owner_id", "")), String(boss_definition.get("owner_id", "")), "Boss bullet lost its owner source.")
	_check_equal(observed_uids, [1, 2, 3, 4, 5], "UIDs were not unique and monotonically increasing across all Stage 2 source classes.")
	_check_equal(observed_slots, [0, 0, 0, 0, 0], "One-slot fixture did not prove identity independence from pool-slot reuse.")
	_check_equal(int(main.stage_controller.stage2_next_bullet_uid), 6, "Stage 2 UID continuation did not point past all successful allocations.")
	_free_main(main)

func _assert_controller_producer_mismatch_fails_closed() -> void:
	var main: Node = _new_main(2, 22102, 2)
	_install_practice_controller(main, MIDBOSS_PHASE_ID)
	var counter_before := int(main.stage_controller.stage2_next_bullet_uid)
	main._consume_stage2_controller_output({"bullet_specs": [_phase_bullet_spec(MIDBOSS_PHASE_ID), _phase_bullet_spec(BOSS_PHASE_ID)]})
	_check_equal(main.bullet_world.active_order(), [], "Mismatched producer phase partially spawned its controller bullet batch.")
	_check_equal(int(main.stage_controller.stage2_next_bullet_uid), counter_before, "Mismatched producer phase consumed a UID.")
	_check_equal(String(main.game_manager_ref.state), "game_over", "Mismatched producer phase did not fail closed.")
	_check(not String(main.stage_controller.get("stage2_hard_error", "")).is_empty(), "Mismatched producer phase did not record a hard error.")
	_free_main(main)

func _stage_source_fixture() -> Dictionary:
	return {
		"stage2_source_event_id": "s2_snapshot_event",
		"stage2_source_spawn_id": "s2_snapshot_spawn",
		"stage2_source_enemy_id": "snapshot_yokai",
		"stage2_primitive": "rebound_bead",
		"stage2_routing": "snapshot_outer_bar_once",
	}

func _assert_snapshot_rejected_atomically(main: Node, malformed: Dictionary, label: String) -> void:
	var baseline_hash: String = main.simulation_state_hash()
	_check(not main.validate_simulation_state(malformed), "%s was accepted by aggregate validation." % label)
	_check_equal(main.simulation_state_hash(), baseline_hash, "%s validation mutated live Main." % label)
	_check(not main.restore_simulation_state(malformed), "%s was accepted by aggregate restore." % label)
	_check_equal(main.simulation_state_hash(), baseline_hash, "%s restore partially mutated live Main." % label)

func _erase_stage_source_tuple(bullet: Dictionary) -> void:
	for field in STAGE_SOURCE_FIELDS:
		bullet.erase(field)

func _assert_snapshot_continuation_and_atomic_rejection() -> void:
	var main: Node = _new_main(2, 22202, 4)
	_check(main._spawn_bullet_enemy(4.0, 240.0, -2.0, 0.0, 6.0, Color.CYAN, "circle", 360.0, {"kind": "reflect", "bounce_count": 1}, _stage_source_fixture()), "Snapshot fixture enemy bullet allocation failed.")
	var source_entry := _only_active_entry(main, "snapshot source")
	main._apply_enemy_bullet_bounce(source_entry.bullet)
	var snapshot: Dictionary = main.capture_simulation_state()
	_check(main.validate_simulation_state(snapshot), "Stage 2 aggregate rejected its own bullet-observability snapshot.")
	_check_equal(int(snapshot.stage_controller.stage2_next_bullet_uid), 2, "Snapshot lost the next Stage 2 UID.")
	var snapshot_bullet: Dictionary = snapshot.bullets.active_bullets[0].state
	_check_equal(int(snapshot_bullet.stage2_bullet_uid), 1, "Snapshot lost the active bullet UID.")
	_check_equal(int(snapshot_bullet.stage2_reflection_count), 1, "Snapshot lost the active bullet reflection count.")
	_check_equal(String(snapshot_bullet.stage2_source_spawn_id), "s2_snapshot_spawn", "Snapshot lost authored bullet source metadata.")

	var restored: Node = _new_main(2, 22202, 4)
	_check(restored.restore_simulation_state(snapshot), "Valid Stage 2 bullet-observability snapshot failed to restore.")
	_check_equal(restored.capture_simulation_state(), snapshot, "Aggregate restore did not reproduce exact Stage 2 bullet/source/counter state.")
	_check(main._spawn_bullet_player(340.0, 700.0, 0.0, -8.0), "Source continuation player bullet allocation failed.")
	_check(restored._spawn_bullet_player(340.0, 700.0, 0.0, -8.0), "Restored continuation player bullet allocation failed.")
	_check_equal(int(main.bullet_pool[main.bullet_world.active_order()[-1]].stage2_bullet_uid), 2, "Source continuation assigned the wrong next UID.")
	_check_equal(int(restored.bullet_pool[restored.bullet_world.active_order()[-1]].stage2_bullet_uid), 2, "Restored continuation assigned a divergent next UID.")
	_check_equal(restored.capture_simulation_state(), main.capture_simulation_state(), "Restored continuation diverged from the source aggregate state.")

	var valid_continuation: Dictionary = main.capture_simulation_state()
	_check(main.validate_simulation_state(valid_continuation), "Continuation fixture was not valid before malformed snapshot checks.")

	var malformed_counter_zero: Dictionary = valid_continuation.duplicate(true)
	malformed_counter_zero.stage_controller.stage2_next_bullet_uid = 0
	_assert_snapshot_rejected_atomically(main, malformed_counter_zero, "Non-positive Stage 2 UID counter")
	var malformed_counter_type: Dictionary = valid_continuation.duplicate(true)
	malformed_counter_type.stage_controller.stage2_next_bullet_uid = "3"
	_assert_snapshot_rejected_atomically(main, malformed_counter_type, "Non-integer Stage 2 UID counter")

	var duplicate_uid: Dictionary = valid_continuation.duplicate(true)
	duplicate_uid.bullets.active_bullets[1].state.stage2_bullet_uid = int(duplicate_uid.bullets.active_bullets[0].state.stage2_bullet_uid)
	_assert_snapshot_rejected_atomically(main, duplicate_uid, "Duplicate active Stage 2 bullet UID")
	var zero_uid: Dictionary = valid_continuation.duplicate(true)
	zero_uid.bullets.active_bullets[0].state.stage2_bullet_uid = 0
	_assert_snapshot_rejected_atomically(main, zero_uid, "Zero active Stage 2 bullet UID")
	var out_of_range_uid: Dictionary = valid_continuation.duplicate(true)
	out_of_range_uid.bullets.active_bullets[0].state.stage2_bullet_uid = int(out_of_range_uid.stage_controller.stage2_next_bullet_uid)
	_assert_snapshot_rejected_atomically(main, out_of_range_uid, "Out-of-range active Stage 2 bullet UID")

	var partial_stage_tuple: Dictionary = valid_continuation.duplicate(true)
	partial_stage_tuple.bullets.active_bullets[0].state.erase("stage2_routing")
	_assert_snapshot_rejected_atomically(main, partial_stage_tuple, "Partial authored-stage source tuple")
	var missing_enemy_source: Dictionary = valid_continuation.duplicate(true)
	_erase_stage_source_tuple(missing_enemy_source.bullets.active_bullets[0].state)
	_assert_snapshot_rejected_atomically(main, missing_enemy_source, "Enemy bullet without a source tuple")
	var partial_phase_tuple: Dictionary = valid_continuation.duplicate(true)
	_erase_stage_source_tuple(partial_phase_tuple.bullets.active_bullets[0].state)
	partial_phase_tuple.bullets.active_bullets[0].state["stage2_source_phase_id"] = MIDBOSS_PHASE_ID
	_assert_snapshot_rejected_atomically(main, partial_phase_tuple, "Partial controller-phase source tuple")
	var mixed_complete_tuples: Dictionary = valid_continuation.duplicate(true)
	mixed_complete_tuples.bullets.active_bullets[0].state["stage2_source_phase_id"] = MIDBOSS_PHASE_ID
	mixed_complete_tuples.bullets.active_bullets[0].state["stage2_source_owner_id"] = "abacus_tsukumogami"
	_assert_snapshot_rejected_atomically(main, mixed_complete_tuples, "Enemy bullet with both complete source tuples")
	var negative_reflection: Dictionary = valid_continuation.duplicate(true)
	negative_reflection.bullets.active_bullets[0].state.stage2_reflection_count = -1
	_assert_snapshot_rejected_atomically(main, negative_reflection, "Negative Stage 2 reflection count")
	_free_main(restored)
	_free_main(main)

func _assert_stage1_legacy_shape() -> void:
	var main: Node = _new_main(1, 22303, 4)
	_check(not main.stage_controller.has("stage2_next_bullet_uid"), "Stage 1 controller gained the Stage 2 UID counter.")
	_check(main._spawn_bullet_enemy(360.0, 180.0, 0.0, 2.0), "Stage 1 enemy bullet allocation failed.")
	_check(main._spawn_bullet_player(360.0, 700.0, 0.0, -8.0), "Stage 1 player bullet allocation failed.")
	var legacy_bullet_keys := _sorted_keys(main.bullet_world.make_bullet_state())
	for bullet_index in main.bullet_world.active_order():
		var bullet: Dictionary = main.bullet_pool[bullet_index]
		_check_equal(_sorted_keys(bullet), legacy_bullet_keys, "Representative Stage 1 bullet changed its exact legacy field shape.")
		for field in bullet:
			_check(not String(field).begins_with("stage2_"), "Stage 1 bullet gained Stage 2 field %s." % field)
	var snapshot: Dictionary = main.capture_simulation_state()
	var expected_snapshot_keys: Array = LEGACY_SNAPSHOT_KEYS.duplicate()
	expected_snapshot_keys.sort()
	_check_equal(int(snapshot.get("version", -1)), 2, "Stage 1 aggregate snapshot version changed.")
	_check_equal(_sorted_keys(snapshot), expected_snapshot_keys, "Stage 1 aggregate snapshot changed its exact legacy field shape.")
	_check(not snapshot.has("stage2_controller"), "Stage 1 aggregate snapshot gained a Stage 2 controller section.")
	_check(main.validate_simulation_state(snapshot), "Representative Stage 1 bullet snapshot no longer validates.")
	_free_main(main)

func _run() -> void:
	_assert_uid_sources_failure_and_reflection()
	_assert_controller_producer_mismatch_fails_closed()
	_assert_snapshot_continuation_and_atomic_rejection()
	_assert_stage1_legacy_shape()
	if failed:
		quit(1)
		return
	print("PASS: M2 Stage 2 bullet UID, source observability, reflection accounting, snapshot continuation, and legacy isolation.")
	quit(0)

func _initialize() -> void:
	call_deferred("_run")
