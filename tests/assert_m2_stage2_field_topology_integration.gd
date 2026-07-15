extends SceneTree

const StageDirector := preload("res://scripts/runtime/stage_director.gd")
const GameplayInputBuffer := preload("res://scripts/runtime/gameplay_input_buffer.gd")
const MainScript := preload("res://scripts/main.gd")
const BulletWorld := preload("res://scripts/runtime/bullet_world.gd")
const Stage2FieldTopologyRuntime := preload("res://scripts/runtime/stage2_field_topology_runtime.gd")

const EVENT_IDS := [
	"s2_b01", "s2_b02", "s2_b03", "s2_b04", "s2_b05", "s2_b06",
	"s2_b07", "s2_b08", "s2_b09", "s2_b10", "s2_b11", "s2_b12",
	"s2_b13", "s2_b14", "s2_b15", "s2_b16", "s2_b17", "s2_b18",
]

var failed := false

func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	failed = true
	push_error("M2_STAGE2_FIELD_INTEGRATION_FAIL: %s" % message)
	return false

func _check_equal(actual, expected, message: String) -> bool:
	return _check(actual == expected, "%s Expected %s, got %s" % [message, expected, actual])

func _check_vector_close(actual: Vector2, expected: Vector2, message: String) -> bool:
	return _check(actual.distance_to(expected) <= 0.00001, "%s Expected %s, got %s" % [message, expected, actual])

func _new_main(difficulty: String = "normal", seed: int = 73001) -> Node:
	var main = MainScript.new()
	main.game_manager_ref = load("res://autoload/game_manager.gd").new()
	main.audio_manager_ref = null
	main.gameplay_difficulty = difficulty
	main.set_gameplay_seed(seed)
	main.fixed_tick_clock.reset()
	main.gameplay_input_buffer.reset()
	main.simulation_tick_index = 0
	main.current_tick_input = GameplayInputBuffer.empty_tick_frame(0)
	main.bullet_world.configure(512, 512, 64)
	main._sync_bullet_world_compatibility_views()
	main._set_active_stage(2)
	main._load_stage(2)
	main.game_manager_ref.state = "stage"
	_check(bool(main.stage_controller.get("stage2_bound", false)), "Main rejected the approved Stage 2 controller/field pair: %s" % main.stage_controller.get("stage2_hard_error", ""))
	return main

func _free_main(main: Node) -> void:
	if main == null:
		return
	var manager: Object = main.game_manager_ref
	main.free()
	if is_instance_valid(manager):
		manager.free()

func _source_event(main: Node, event_id: String) -> Dictionary:
	var package: Dictionary = main.stage_director.stage2_package()
	var stage_spec: Dictionary = package.get("stage_spec", {})
	for event_value in stage_spec.get("events", []):
		var event: Dictionary = event_value
		if String(event.get("id", "")) == event_id:
			return (event.get("payload", {}) as Dictionary).duplicate(true)
	return {}

func _stage_event(main: Node, event_id: String) -> Dictionary:
	return {"id": event_id, "payload": _source_event(main, event_id)}

func _genuinely_live_main_sources(main: Node) -> Array:
	var result: Array = []
	for enemy_value in main.enemies:
		var enemy: Dictionary = enemy_value
		if bool(enemy.get("stage2_field_owned", false)) and bool(enemy.get("alive", false)) and not bool(enemy.get("dying", false)) and not bool(enemy.get("stage2_source_defeat_forwarded", false)) and not bool(enemy.get("stage2_source_removal_forwarded", false)):
			result.append(String(enemy.get("stage2_spawn_id", "")))
	return result

func _activate_direct_event(main: Node, event_id: String) -> bool:
	var event: Dictionary = _source_event(main, event_id)
	if not _check(not event.is_empty(), "Missing source metadata for %s." % event_id):
		return false
	var tick := int(event.get("authored_tick", -1))
	if not _check(main._stage2_field_callback("activate_event", tick, {"event_id": event_id, "active_entity_ids": []}), "Direct %s activation failed." % event_id):
		return false
	for spawn_value in event.get("spawns", []):
		if not _check(main._spawn_stage2_authored_enemy(event_id, spawn_value), "Main rejected %s source materialization." % event_id):
			return false
	return _check(main._stage2_field_callback("advance", tick), "Direct %s authored tick failed." % event_id)

func _advance_field_to(main: Node, tick: int) -> bool:
	return _check(main._stage2_field_callback("advance", tick), "Field clock failed at authored tick %d: %s" % [tick, main.stage_controller.get("stage2_field_hard_error", "")])

func _first_field_uid(main: Node, primitive: String = "") -> String:
	var bindings: Dictionary = main.stage_controller.get("stage2_field_uid_to_slot", {})
	var uids: Array = bindings.keys()
	uids.sort()
	for uid_value in uids:
		var uid := String(uid_value)
		var slot := int(bindings[uid])
		var bullet: Dictionary = main.bullet_pool[slot]
		if primitive == "" or String(bullet.get("stage2_primitive", "")) == primitive:
			return uid
	return ""

func _bullet_for_uid(main: Node, uid: String) -> Dictionary:
	var bindings: Dictionary = main.stage_controller.get("stage2_field_uid_to_slot", {})
	if not bindings.has(uid):
		return {}
	var slot := int(bindings[uid])
	return main.bullet_pool[slot] if slot >= 0 and slot < main.bullet_pool.size() else {}

func _remove_sources(main: Node, spawn_ids: Array, tick: int) -> bool:
	for spawn_value in spawn_ids:
		if not _check(main._stage2_field_callback("remove_source", tick, {"spawn_id": String(spawn_value), "reason": "focused_fixture"}), "Could not stop fixture source %s." % spawn_value):
			return false
	return true

func _field_transaction_state(main: Node) -> Dictionary:
	return {
		"runtime": main.stage2_field_topology_runtime.capture_snapshot(),
		"world": main.capture_bullet_world_state(),
		"tick": int(main.stage_controller.get("stage2_field_tick", -1)),
		"sequence": int(main.stage_controller.get("stage2_field_event_sequence", -1)),
		"bindings": (main.stage_controller.get("stage2_field_uid_to_slot", {}) as Dictionary).duplicate(true),
		"live_runtime_id": main.stage2_field_topology_runtime.get_instance_id(),
		"scratch_runtime_id": main.stage2_field_topology_scratch_runtime.get_instance_id(),
		"live_world_id": main.bullet_world.get_instance_id(),
		"scratch_world_id": main.stage2_field_scratch_bullet_world.get_instance_id(),
	}

func _assert_clock_rejection(main: Node, output: Dictionary, label: String) -> void:
	var before := _field_transaction_state(main)
	_check(not main._consume_stage2_controller_output(output), "%s clock evidence was accepted." % label)
	var after := _field_transaction_state(main)
	_check_equal(after, before, "%s clock rejection changed runtime/world/cursor/sequence/bindings or owner identity." % label)
	_check(String(main.stage_controller.get("stage2_field_hard_error", "")) != "", "%s clock rejection did not latch a stable error." % label)

func _assert_clock_discriminator_and_scratch_performance() -> void:
	var frozen: Node = _new_main("normal", 73021)
	var frozen_before := _field_transaction_state(frozen)
	_check(frozen._consume_stage2_controller_output({"stage_events": []}), "Absent no-event stage_tick evidence did not leave the field frozen.")
	_check_equal(_field_transaction_state(frozen), frozen_before, "Absent no-event stage_tick evidence changed the frozen field aggregate.")
	_free_main(frozen)

	var missing: Node = _new_main("normal", 73022)
	var missing_output: Dictionary = missing.stage2_encounter_controller.advance(Vector2(missing.player_x, missing.player_y))
	missing_output.erase("stage_tick")
	_assert_clock_rejection(missing, missing_output, "Missing event")
	_free_main(missing)

	var malformed: Node = _new_main("normal", 73023)
	var malformed_output: Dictionary = malformed.stage2_encounter_controller.advance(Vector2(malformed.player_x, malformed.player_y))
	malformed_output.stage_tick = "0"
	_assert_clock_rejection(malformed, malformed_output, "Malformed")
	_free_main(malformed)

	var duplicate_event: Node = _new_main("normal", 73024)
	var duplicate_event_output: Dictionary = duplicate_event.stage2_encounter_controller.advance(Vector2(duplicate_event.player_x, duplicate_event.player_y))
	duplicate_event_output.stage_events.append((duplicate_event_output.stage_events[0] as Dictionary).duplicate(true))
	_assert_clock_rejection(duplicate_event, duplicate_event_output, "Duplicate authored event")
	_free_main(duplicate_event)

	var contradictory: Node = _new_main("normal", 73025)
	var contradictory_output: Dictionary = contradictory.stage2_encounter_controller.advance(Vector2(contradictory.player_x, contradictory.player_y))
	contradictory_output.stage_tick = int(contradictory_output.stage_tick) + 1
	_assert_clock_rejection(contradictory, contradictory_output, "Contradictory")
	_free_main(contradictory)

	for case_value in [{"label": "Duplicate", "delta": 0}, {"label": "Skipped", "delta": 2}]:
		var rejected: Node = _new_main("normal", 73026 + int(case_value.delta))
		var entry_output: Dictionary = rejected.stage2_encounter_controller.advance(Vector2(rejected.player_x, rejected.player_y))
		_check(rejected._consume_stage2_controller_output(entry_output), "%s fixture rejected its first authored event." % case_value.label)
		var ordinary_output: Dictionary = rejected.stage2_encounter_controller.advance(Vector2(rejected.player_x, rejected.player_y))
		ordinary_output.stage_tick = int(rejected.stage_controller.stage2_field_tick) + int(case_value.delta)
		_assert_clock_rejection(rejected, ordinary_output, String(case_value.label))
		_free_main(rejected)

	var unavailable: Node = _new_main("normal", 73030)
	var unavailable_live_runtime_id := unavailable.stage2_field_topology_runtime.get_instance_id()
	var unavailable_live_world_id := unavailable.bullet_world.get_instance_id()
	var unavailable_scratch_world_id := unavailable.stage2_field_scratch_bullet_world.get_instance_id()
	var unavailable_runtime_before := unavailable.stage2_field_topology_runtime.capture_snapshot()
	var unavailable_world_before := unavailable.capture_bullet_world_state()
	var unavailable_tick_before := int(unavailable.stage_controller.stage2_field_tick)
	var unavailable_sequence_before := int(unavailable.stage_controller.stage2_field_event_sequence)
	var unavailable_bindings_before: Dictionary = unavailable.stage_controller.stage2_field_uid_to_slot.duplicate(true)
	var unavailable_generation_before := int(unavailable.stage2_field_topology_runtime.telemetry_snapshot().get("configure_generation", -1))
	unavailable.stage2_field_topology_scratch_runtime = null
	_check(not unavailable._stage2_field_callback("advance", 0), "Ordinary callback rebuilt and accepted a missing scratch runtime.")
	_check(unavailable.stage2_field_topology_scratch_runtime == null, "Ordinary callback constructed a replacement scratch runtime.")
	_check_equal(unavailable.stage2_field_topology_runtime.get_instance_id(), unavailable_live_runtime_id, "Missing-scratch rejection replaced the live runtime owner.")
	_check_equal(unavailable.bullet_world.get_instance_id(), unavailable_live_world_id, "Missing-scratch rejection replaced the live BulletWorld owner.")
	_check_equal(unavailable.stage2_field_scratch_bullet_world.get_instance_id(), unavailable_scratch_world_id, "Missing-scratch rejection reconstructed the scratch BulletWorld.")
	_check_equal(unavailable.stage2_field_topology_runtime.capture_snapshot(), unavailable_runtime_before, "Missing-scratch rejection mutated the live runtime.")
	_check_equal(unavailable.capture_bullet_world_state(), unavailable_world_before, "Missing-scratch rejection mutated the live BulletWorld.")
	_check_equal(int(unavailable.stage_controller.stage2_field_tick), unavailable_tick_before, "Missing-scratch rejection advanced the live cursor.")
	_check_equal(int(unavailable.stage_controller.stage2_field_event_sequence), unavailable_sequence_before, "Missing-scratch rejection consumed a live sequence.")
	_check_equal(unavailable.stage_controller.stage2_field_uid_to_slot, unavailable_bindings_before, "Missing-scratch rejection changed live bindings.")
	_check_equal(int(unavailable.stage2_field_topology_runtime.telemetry_snapshot().get("configure_generation", -1)), unavailable_generation_before, "Missing-scratch rejection configured the live runtime.")
	_free_main(unavailable)

	var timed: Node = _new_main("normal", 73029)
	var initial_output: Dictionary = timed.stage2_encounter_controller.advance(Vector2(timed.player_x, timed.player_y))
	_check(timed._consume_stage2_controller_output(initial_output), "Timing fixture rejected its first authored event.")
	_check(timed.stage2_field_topology_runtime != timed.stage2_field_topology_scratch_runtime, "Runtime live/scratch owners alias after event entry.")
	_check(timed.bullet_world != timed.stage2_field_scratch_bullet_world, "BulletWorld live/scratch owners alias after event entry.")
	_check(not timed.stage2_field_topology_scratch_runtime.trusted_copy_mutable_state_from(timed.bullet_world), "Runtime trusted copy accepted a different script identity.")
	var incompatible_runtime := Stage2FieldTopologyRuntime.new()
	_check(incompatible_runtime.configure(timed.stage_director.stage2_field_topology_contract(), "normal", "incompatible_run"), "Incompatible runtime identity fixture did not configure.")
	_check(not timed.stage2_field_topology_scratch_runtime.trusted_copy_mutable_state_from(incompatible_runtime), "Runtime trusted copy accepted a different run UID.")
	var incompatible_world := BulletWorld.new()
	_check(incompatible_world.configure(1, 1, 1), "Incompatible BulletWorld identity fixture did not configure.")
	_check(not timed.stage2_field_scratch_bullet_world.trusted_copy_mutable_state_from(incompatible_world), "BulletWorld trusted copy accepted different cap/growth identity.")
	var live_world_before_busy_copy := timed.capture_bullet_world_state()
	timed.stage2_field_scratch_bullet_world.begin_update()
	_check(not timed.bullet_world.trusted_copy_mutable_state_from(timed.stage2_field_scratch_bullet_world), "BulletWorld trusted copy accepted an update-in-progress owner.")
	timed.stage2_field_scratch_bullet_world.end_update()
	_check_equal(timed.capture_bullet_world_state(), live_world_before_busy_copy, "Rejected update-in-progress copy changed the live BulletWorld.")
	var live_runtime_before_alias := timed.stage2_field_topology_runtime.capture_snapshot()
	var scratch_sequence := int(timed.stage_controller.stage2_field_event_sequence) + 1
	var isolated_candidate_controller: Dictionary = timed.stage_controller.duplicate(true)
	isolated_candidate_controller["stage2_field_event_sequence"] = scratch_sequence
	_check(timed.stage2_field_scratch_bullet_world.trusted_copy_mutable_state_from(timed.bullet_world), "Isolated candidate BulletWorld could not copy live state.")
	var scratch_output: Dictionary = timed.stage2_field_topology_scratch_runtime.advance(1, scratch_sequence)
	_check(bool(scratch_output.get("ok", false)), "Scratch runtime alias probe could not mutate its isolated owner.")
	_check(timed._stage2_preflight_field_output(scratch_output, 1, scratch_sequence, timed.stage2_field_topology_scratch_runtime, timed.stage2_field_scratch_bullet_world, isolated_candidate_controller), "Explicit scratch candidate failed preflight.")
	var live_aggregate_before_candidate_apply := _field_transaction_state(timed)
	_check(timed._consume_stage2_field_output(scratch_output, timed.stage2_field_topology_scratch_runtime, timed.stage2_field_scratch_bullet_world, isolated_candidate_controller), "Explicit scratch candidate output could not be consumed while live owners stayed unpublished.")
	isolated_candidate_controller["stage2_field_tick"] = 1
	_check(timed._stage2_validate_field_candidate_aggregate(timed.stage2_field_topology_scratch_runtime, timed.stage2_field_scratch_bullet_world, isolated_candidate_controller, 1, scratch_sequence, 1), "Fully applied explicit scratch aggregate did not validate.")
	_check_equal(_field_transaction_state(timed), live_aggregate_before_candidate_apply, "Explicit candidate application published or mutated a live owner before swap.")
	_check_equal(timed.stage2_field_topology_runtime.capture_snapshot(), live_runtime_before_alias, "Scratch runtime mutation aliased the live runtime.")
	_check(timed.stage2_field_topology_scratch_runtime.trusted_copy_mutable_state_from(timed.stage2_field_topology_runtime), "Scratch runtime could not be reset by trusted copy after alias probe.")
	_check(timed.stage2_field_scratch_bullet_world.trusted_copy_mutable_state_from(timed.bullet_world), "Scratch BulletWorld could not be reset before alias probe.")
	(timed.stage2_field_scratch_bullet_world.pool[0].motion as Dictionary)["alias_probe"] = true
	_check(not bool((timed.bullet_world.pool[0].motion as Dictionary).get("alias_probe", false)), "Scratch BulletWorld nested Dictionary aliased the live pool.")
	_check(timed.stage2_field_scratch_bullet_world.trusted_copy_mutable_state_from(timed.bullet_world), "Scratch BulletWorld could not be reset after alias probe.")
	var runtime_generations := {}
	for runtime in [timed.stage2_field_topology_runtime, timed.stage2_field_topology_scratch_runtime]:
		runtime_generations[runtime.get_instance_id()] = int(runtime.telemetry_snapshot().get("configure_generation", -1))
	var runtime_owner_ids: Array = runtime_generations.keys()
	var world_owner_ids := {
		timed.bullet_world.get_instance_id(): true,
		timed.stage2_field_scratch_bullet_world.get_instance_id(): true,
	}
	var timings_us: Array[int] = []
	var first_ordinary_tick := int(timed.stage_controller.stage2_field_tick) + 1
	while timings_us.size() < 120:
		var output: Dictionary = timed.stage2_encounter_controller.advance(Vector2(timed.player_x, timed.player_y))
		if not _check((output.get("stage_events", []) as Array).is_empty(), "Timing sample unexpectedly crossed an authored event boundary."):
			break
		var started_us := Time.get_ticks_usec()
		if not _check(timed._consume_stage2_controller_output(output), "Ordinary Main clock consumption failed during timing sample %d." % timings_us.size()):
			break
		timings_us.append(Time.get_ticks_usec() - started_us)
		_check_equal(int(timed.stage_controller.stage2_field_tick), int(output.stage_tick), "Ordinary no-event output did not advance to the exact controller tick.")
		_check(timed.stage2_field_topology_runtime != timed.stage2_field_topology_scratch_runtime and timed.bullet_world != timed.stage2_field_scratch_bullet_world, "Ordinary swap aliased live and scratch owners.")
		for runtime in [timed.stage2_field_topology_runtime, timed.stage2_field_topology_scratch_runtime]:
			var owner_id := runtime.get_instance_id()
			_check(owner_id in runtime_owner_ids, "Ordinary callback created an unbounded runtime owner.")
			_check_equal(int(runtime.telemetry_snapshot().get("configure_generation", -1)), int(runtime_generations.get(owner_id, -2)), "Ordinary callback increased runtime configure generation.")
		_check(world_owner_ids.has(timed.bullet_world.get_instance_id()) and world_owner_ids.has(timed.stage2_field_scratch_bullet_world.get_instance_id()), "Ordinary callback created an unbounded BulletWorld owner.")
	_check_equal(int(timed.stage_controller.stage2_field_tick), first_ordinary_tick + timings_us.size() - 1, "Ordinary no-event outputs did not advance exactly once each.")
	if not timings_us.is_empty():
		timings_us.sort()
		var p50_us := timings_us[int(floor(float(timings_us.size() - 1) * 0.50))]
		var p95_us := timings_us[maxi(0, int(ceil(float(timings_us.size()) * 0.95)) - 1)]
		var max_us := timings_us[timings_us.size() - 1]
		print("STAGE2_FIELD_CALLBACK_TIMING count=%d p50_us=%d p95_us=%d max_us=%d" % [timings_us.size(), p50_us, p95_us, max_us])
		_check(max_us < 16667, "Ordinary Main callback exceeded the 16.667 ms ceiling: %d us." % max_us)
	_free_main(timed)

func _assert_contract_loading_and_first_construction() -> void:
	var director := StageDirector.new()
	var contract: Dictionary = director.stage2_field_topology_contract()
	_check_equal(String(contract.get("artifact_id", "")), "m2_stage2_field_topology_contract_v1", "StageDirector field contract identity drifted.")
	_check_equal((contract.get("spawn_topologies", []) as Array).size(), 22, "StageDirector field contract coverage drifted.")
	var normal: Node = _new_main("normal", 73011)
	var hard: Node = _new_main("hard", 73011)
	var normal_output: Dictionary = normal.stage2_encounter_controller.advance(Vector2(normal.player_x, normal.player_y))
	var hard_output: Dictionary = hard.stage2_encounter_controller.advance(Vector2(hard.player_x, hard.player_y))
	_check(normal._consume_stage2_controller_output(normal_output), "Normal first stage event was rejected.")
	_check(hard._consume_stage2_controller_output(hard_output), "Hard first stage event was rejected.")
	_check_equal(normal.stage_controller.get("stage2_field_run_uid"), "stage2_normal_73011", "Normal deterministic stage-run UID drifted.")
	_check_equal(hard.stage_controller.get("stage2_field_run_uid"), "stage2_hard_73011", "Hard deterministic stage-run UID drifted.")
	_check(bool(normal.enemies[0].get("stage2_field_owned", false)), "Authored ordinary source lacks its explicit field-owned marker.")
	normal._update_enemies(1.0 / 60.0)
	_check_equal(normal.stage_controller.get("stage2_field_uid_to_slot", {}).size(), 0, "Field-owned enemy emitted a legacy substitute before its authored burst.")
	var pre_construction_runtime_id := normal.stage2_field_topology_runtime.get_instance_id()
	var pre_construction_world_id := normal.bullet_world.get_instance_id()
	var pre_construction_runtime := normal.stage2_field_topology_runtime.capture_snapshot()
	var pre_construction_world := normal.capture_bullet_world_state()
	var pre_construction_controller: Dictionary = normal.stage_controller
	_check(_advance_field_to(normal, 24), "Normal first authored construction did not materialize.")
	_check(_advance_field_to(hard, 24), "Hard first authored construction did not materialize.")
	_check_equal(normal.stage2_field_topology_scratch_runtime.get_instance_id(), pre_construction_runtime_id, "Validated construction did not swap the previous live runtime into scratch.")
	_check_equal(normal.stage2_field_scratch_bullet_world.get_instance_id(), pre_construction_world_id, "Validated construction did not swap the previous live BulletWorld into scratch.")
	_check_equal(normal.stage2_field_topology_scratch_runtime.capture_snapshot(), pre_construction_runtime, "Candidate application mutated the previous live runtime before swap.")
	_check_equal(normal.stage2_field_scratch_bullet_world.capture_state(), pre_construction_world, "Candidate application mutated the previous live BulletWorld before swap.")
	_check_equal(int(pre_construction_controller.stage2_field_tick), 0, "Candidate application mutated the previous live controller tick before swap.")
	_check_equal((pre_construction_controller.stage2_field_uid_to_slot as Dictionary).size(), 0, "Candidate application exposed construction bindings through the previous live controller.")
	var bindings: Dictionary = normal.stage_controller.stage2_field_uid_to_slot
	_check_equal(bindings.size(), int(normal.stage2_field_topology_runtime.telemetry_snapshot().get("active_bullet_count", -1)), "Legacy emission duplicated or hid the first authored burst.")
	var uid := _first_field_uid(normal)
	var bullet := _bullet_for_uid(normal, uid)
	var runtime_bullet: Dictionary = normal.stage2_field_topology_runtime.bullet_state(uid)
	_check(typeof(bullet.get("stage2_bullet_uid")) == TYPE_STRING, "Field bullet UID is not in the exact string domain.")
	_check_equal(Vector2(float(bullet.vx), float(bullet.vy)), Vector2(float(runtime_bullet.velocity_px_per_second[0]), float(runtime_bullet.velocity_px_per_second[1])) / 60.0, "Authored px/s velocity was not converted exactly to px/tick.")
	for seam_field in MainScript.STAGE2_FIELD_SEAM_FIELDS:
		_check(bullet.has(seam_field), "Field bullet lost seam field %s." % seam_field)
	var authored_anchor := Vector2(float(runtime_bullet.position[0]), float(runtime_bullet.position[1]))
	var authored_velocity := Vector2(float(bullet.vx), float(bullet.vy))
	normal._update_bullets(1.0 / 60.0, Vector2.ZERO)
	bullet = _bullet_for_uid(normal, uid)
	_check_vector_close(Vector2(float(bullet.x), float(bullet.y)), authored_anchor, "First construction moved before its authored-tick collision pass.")
	normal.player_x = authored_anchor.x
	normal.player_y = authored_anchor.y
	normal.player_invincible = false
	normal.player_just_hit = false
	normal.player_deathbomb_primed = false
	normal._check_collisions(false)
	_check(normal.player_just_hit, "Real BulletWorld collision path missed an enabled field construction at its authored anchor.")
	_check(normal.stage_controller.stage2_field_uid_to_slot.has(uid) and bool(_bullet_for_uid(normal, uid).get("active", false)), "Player collision incorrectly retired a runtime-owned field bullet.")
	normal.player_just_hit = false
	normal.player_deathbomb_primed = false
	normal.player_deathbomb_timer = 0.0
	_check(_advance_field_to(normal, 25), "First construction continuation tick failed.")
	normal._update_bullets(1.0 / 60.0, Vector2.ZERO)
	bullet = _bullet_for_uid(normal, uid)
	_check_vector_close(Vector2(float(bullet.x), float(bullet.y)), authored_anchor + authored_velocity, "Field construction did not begin linear BulletWorld movement on the next tick.")
	_check(normal._spawn_bullet_player(360.0, 700.0, 0.0, -8.0), "Compatibility player bullet fixture failed.")
	var saw_integer_uid := false
	for bullet_index in normal.bullet_world.active_order():
		var candidate: Dictionary = normal.bullet_pool[bullet_index]
		if String(candidate.get("type", "")) == "player":
			saw_integer_uid = typeof(candidate.get("stage2_bullet_uid")) == TYPE_INT and int(candidate.stage2_bullet_uid) > 0
	_check(saw_integer_uid, "Player/phase compatibility UID domain is not positive integer.")
	var normal_warning: Dictionary = normal.stage_controller.stage2_field_warning_records[0]
	var hard_warning: Dictionary = hard.stage_controller.stage2_field_warning_records[0]
	_check(String(normal_warning.get("topology_id", "")) != String(hard_warning.get("topology_id", "")), "Normal and Hard selected the same field structure.")
	_free_main(normal)
	_free_main(hard)

func _assert_delayed_seed_rebound_removal_and_projection() -> void:
	var delayed: Node = _new_main("normal", 73021)
	_check(_activate_direct_event(delayed, "s2_b15"), "Delayed-seed fixture activation failed.")
	_check(_advance_field_to(delayed, 2130), "Delayed-seed burst failed.")
	var delayed_uid := _first_field_uid(delayed, "delayed_seed")
	var delayed_bullet := _bullet_for_uid(delayed, delayed_uid)
	_check(delayed_uid != "" and not delayed._stage2_field_collision_enabled(delayed_bullet), "Delayed seed collided before its authored activation.")
	_check_equal(Vector2(float(delayed_bullet.vx), float(delayed_bullet.vy)), Vector2.ZERO, "Delayed seed moved before activation.")
	var delayed_anchor := Vector2(float(delayed_bullet.x), float(delayed_bullet.y))
	delayed._update_bullets(1.0 / 60.0, Vector2.ZERO)
	delayed_bullet = _bullet_for_uid(delayed, delayed_uid)
	_check_vector_close(Vector2(float(delayed_bullet.x), float(delayed_bullet.y)), delayed_anchor, "Delayed-seed construction moved on its authored tick.")
	delayed.player_x = delayed_anchor.x
	delayed.player_y = delayed_anchor.y
	delayed.player_invincible = false
	delayed.player_just_hit = false
	delayed._check_collisions(false)
	_check(not delayed.player_just_hit, "Real collision path ignored delayed-seed collision gating.")
	_check(_advance_field_to(delayed, 2147), "Delayed seed pre-activation trace failed.")
	_check(not delayed._stage2_field_collision_enabled(_bullet_for_uid(delayed, delayed_uid)), "Delayed seed collision opened one tick early.")
	_check(_advance_field_to(delayed, 2148), "Delayed seed activation tick failed.")
	delayed_bullet = _bullet_for_uid(delayed, delayed_uid)
	_check(delayed._stage2_field_collision_enabled(delayed_bullet), "Delayed seed collision did not open at the authored tick.")
	_check(Vector2(float(delayed_bullet.vx), float(delayed_bullet.vy)) != Vector2.ZERO, "Delayed seed activation did not atomically install velocity.")
	var delayed_velocity := Vector2(float(delayed_bullet.vx), float(delayed_bullet.vy))
	delayed._update_bullets(1.0 / 60.0, Vector2.ZERO)
	delayed_bullet = _bullet_for_uid(delayed, delayed_uid)
	_check_vector_close(Vector2(float(delayed_bullet.x), float(delayed_bullet.y)), delayed_anchor, "Delayed seed left its authored activation anchor before collision.")
	delayed.player_x = delayed_anchor.x
	delayed.player_y = delayed_anchor.y
	delayed.player_just_hit = false
	delayed.player_deathbomb_primed = false
	delayed._check_collisions(false)
	_check(delayed.player_just_hit, "Real collision path did not open on the delayed-seed activation tick.")
	_check(delayed.stage_controller.stage2_field_uid_to_slot.has(delayed_uid), "Delayed-seed hit retired the runtime-owned slot.")
	delayed.player_just_hit = false
	delayed.player_deathbomb_primed = false
	delayed.player_deathbomb_timer = 0.0
	_check(_remove_sources(delayed, ["s2_b15_left_mirror", "s2_b15_right_mirror"], 2148), "Delayed fixture sources were not removed.")
	_check(_advance_field_to(delayed, 2149), "Delayed seed post-activation continuation failed.")
	delayed._update_bullets(1.0 / 60.0, Vector2.ZERO)
	delayed_bullet = _bullet_for_uid(delayed, delayed_uid)
	_check_vector_close(Vector2(float(delayed_bullet.x), float(delayed_bullet.y)), delayed_anchor + delayed_velocity, "Delayed seed did not begin moving on the tick after activation.")
	var delayed_state: Dictionary = delayed.stage2_field_topology_runtime.bullet_state(delayed_uid)
	var delayed_removal_tick := int(delayed_state.get("removal_tick", -1))
	_check(delayed_removal_tick > 2149 and _advance_field_to(delayed, delayed_removal_tick), "Delayed seed exact removal tick failed.")
	_check(not delayed.stage_controller.stage2_field_uid_to_slot.has(delayed_uid), "Authored delayed-seed removal left a UID/slot binding.")
	_free_main(delayed)

	var rebound: Node = _new_main("normal", 73022)
	_check(_activate_direct_event(rebound, "s2_b01"), "Rebound fixture activation failed.")
	_check(_advance_field_to(rebound, 24), "Rebound first burst failed.")
	var rebound_uid := _first_field_uid(rebound, "rebound_bead")
	var rebound_state: Dictionary = rebound.stage2_field_topology_runtime.bullet_state(rebound_uid)
	var plan: Array = rebound_state.get("reflection_plan", [])
	_check(not plan.is_empty(), "Rebound fixture has no authored turn.")
	_check(_remove_sources(rebound, ["s2_b01_abacus_left", "s2_b01_abacus_center", "s2_b01_abacus_right"], 24), "Rebound fixture sources were not removed.")
	var reflection_tick := int((plan[0] as Dictionary).get("tick", -1))
	_check(_advance_field_to(rebound, reflection_tick), "Authored rebound turn failed.")
	var rebound_bullet := _bullet_for_uid(rebound, rebound_uid)
	_check_equal(int(rebound_bullet.get("stage2_reflection_count", -1)), 1, "Authored rebound metadata did not latch exactly once.")
	_check_equal(rebound_bullet.get("stage2_last_reflection_surface_id"), (plan[0] as Dictionary).get("surface_id"), "Authored rebound surface metadata drifted.")
	var rebound_anchor := Vector2(float((plan[0] as Dictionary).waypoint[0]), float((plan[0] as Dictionary).waypoint[1]))
	var velocity_before := Vector2(float(rebound_bullet.vx), float(rebound_bullet.vy))
	rebound._update_bullets(1.0 / 60.0, Vector2.ZERO)
	rebound_bullet = _bullet_for_uid(rebound, rebound_uid)
	_check_vector_close(Vector2(float(rebound_bullet.x), float(rebound_bullet.y)), rebound_anchor, "Authored rebound left its waypoint before the turn-tick collision pass.")
	_check_vector_close(Vector2(float(rebound_bullet.vx), float(rebound_bullet.vy)), velocity_before, "Turn-tick BulletWorld update changed the authored rebound velocity.")
	_check(_advance_field_to(rebound, reflection_tick + 1), "Authored rebound continuation tick failed.")
	rebound._update_bullets(1.0 / 60.0, Vector2.ZERO)
	rebound_bullet = _bullet_for_uid(rebound, rebound_uid)
	_check_vector_close(Vector2(float(rebound_bullet.x), float(rebound_bullet.y)), rebound_anchor + velocity_before, "Authored rebound did not move on the tick after its waypoint turn.")
	rebound_bullet.x = 8.0
	rebound_bullet.vx = -absf(float(rebound_bullet.vx)) if not is_zero_approx(float(rebound_bullet.vx)) else -1.0
	rebound_bullet.has_motion = true
	rebound_bullet.motion = {"kind": "linear", "bounce_count": 1}
	var non_bounce_velocity := float(rebound_bullet.vx)
	rebound._update_bullets(1.0 / 60.0, Vector2.ZERO)
	rebound_bullet = _bullet_for_uid(rebound, rebound_uid)
	_check(is_equal_approx(float(rebound_bullet.vx), non_bounce_velocity) and int(rebound_bullet.motion.get("bounce_count", -1)) == 1, "Real BulletWorld update applied generic bounce to a field-owned bullet.")
	_check_equal(int(rebound_bullet.get("stage2_reflection_count", -1)), 1, "Generic update fabricated a second authored reflection.")
	var score_before := int(rebound.game_manager_ref.score)
	var graze_before := int(rebound.game_manager_ref.graze)
	var multiplier_before := float(rebound.game_manager_ref.night_festival_multiplier)
	var seals_before := int(rebound.game_manager_ref.night_festival_seals)
	var items_before: Array = rebound.items.duplicate(true)
	rebound.player_x = float(rebound_bullet.x)
	rebound.player_y = float(rebound_bullet.y)
	rebound.player_invincible = true
	rebound._check_collisions(false)
	rebound.player_invincible = false
	_check_equal(int(rebound.game_manager_ref.graze), graze_before + 1, "Real collision path did not award exactly one reflected field graze.")
	_check(bool(_bullet_for_uid(rebound, rebound_uid).get("grazed", false)), "Transactional graze commit did not mark the live BulletWorld slot.")
	_check(not (rebound.stage_controller.get("stage2_field_score_projections", []) as Array).is_empty(), "Qualifying graze projection was not retained as evidence.")
	_check_equal(int(rebound.game_manager_ref.score), score_before + rebound._score_value("graze", 10), "Projection changed score beyond the existing ordinary graze award.")
	_check_equal(float(rebound.game_manager_ref.night_festival_multiplier), multiplier_before, "Projection callback directly mutated multiplier.")
	_check_equal(int(rebound.game_manager_ref.night_festival_seals), seals_before, "Projection callback directly mutated seals.")
	_check_equal(rebound.items, items_before, "Projection callback directly mutated drops.")
	_free_main(rebound)

func _assert_source_callbacks_and_gate_catchup() -> void:
	var sources: Node = _new_main("normal", 73031)
	_check(_activate_direct_event(sources, "s2_b03"), "Source callback fixture activation failed.")
	var red: Dictionary = sources.enemies[0]
	var blue: Dictionary = sources.enemies[1]
	red.dying = true
	red.death_timer = 8.0
	_check(sources._stage2_forward_field_source_defeat(red), "Alive-to-dying defeat was not forwarded.")
	_check(sources._stage2_forward_field_source_defeat(red), "Duplicate defeat guard was not idempotent.")
	_check(sources._stage2_forward_field_source_removal(blue, "focused_despawn"), "Alive-to-removed despawn was not forwarded.")
	var removals: Array = sources.stage_controller.stage2_field_source_removals
	_check_equal(removals.size(), 2, "Defeat/despawn callbacks were not forwarded exactly once each.")
	_check(bool(removals[0].get("defeat", false)) and not bool(removals[1].get("defeat", true)), "Defeat/despawn ownership was not preserved.")
	_free_main(sources)

	var gate: Node = _new_main("normal", 73032)
	var guard := 0
	while gate.stage2_encounter_controller.encounter_kind() == "stage" and guard < 800:
		var output: Dictionary = gate.stage2_encounter_controller.advance(Vector2(gate.player_x, gate.player_y))
		if not _check(gate._consume_stage2_controller_output(output), "Main rejected pre-midboss field output at step %d." % guard):
			_free_main(gate)
			return
		guard += 1
	_check(guard < 800 and gate.stage2_encounter_controller.encounter_kind() == "midboss", "Real Main path did not reach the midboss gate.")
	_check_equal(int(gate.stage_controller.get("stage2_field_tick", -1)), 750, "Field clock did not freeze at the midboss gate.")
	_check_equal(gate.stage_controller.get("stage2_field_uid_to_slot", {}).size(), 0, "Midboss gate did not clear field bullets.")
	_check(not (gate.stage_controller.get("stage2_field_source_removals", []) as Array).is_empty(), "Midboss gate did not clear field sources.")
	var first_phase_advance: Dictionary = gate.stage2_encounter_controller.advance(Vector2(gate.player_x, gate.player_y))
	_check(not first_phase_advance.has("stage_tick") and gate._consume_stage2_controller_output(first_phase_advance), "First active midboss phase advance carried stage_tick or failed consumption.")
	_check_equal(int(gate.stage_controller.get("stage2_field_tick", -1)), 750, "First active midboss phase advance moved the frozen field clock.")
	var first_resolution: Dictionary = gate.stage2_encounter_controller.resolve_active_phase("clear")
	_check(not first_resolution.has("stage_tick") and gate._consume_stage2_controller_output(first_resolution), "First midboss phase resolution carried stage_tick or failed.")
	_check_equal(int(gate.stage_controller.get("stage2_field_tick", -1)), 750, "First midboss phase resolution moved the frozen field clock.")
	var second_phase_advance: Dictionary = gate.stage2_encounter_controller.advance(Vector2(gate.player_x, gate.player_y))
	_check(not second_phase_advance.has("stage_tick") and gate._consume_stage2_controller_output(second_phase_advance), "Second active midboss phase advance carried stage_tick or failed consumption.")
	_check_equal(int(gate.stage_controller.get("stage2_field_tick", -1)), 750, "Second active midboss phase advance moved the frozen field clock.")
	var second_resolution: Dictionary = gate.stage2_encounter_controller.resolve_active_phase("clear")
	_check(String(second_resolution.get("encounter_kind", "")) == "stage" and not second_resolution.has("stage_tick") and gate._consume_stage2_controller_output(second_resolution), "Final midboss resolution did not return to stage while withholding stage_tick.")
	_check_equal(int(gate.stage_controller.get("stage2_field_tick", -1)), 750, "Active midboss advanced the frozen field clock.")
	var resume: Dictionary = gate.stage2_encounter_controller.advance(Vector2(gate.player_x, gate.player_y))
	_check(gate._consume_stage2_controller_output(resume), "Compressed post-midboss authored catch-up failed.")
	_check_equal((resume.get("stage_events", []) as Array).map(func(event): return String(event.get("id", ""))), EVENT_IDS.slice(6, 12), "Compressed resume event order drifted.")
	_check_equal(int(gate.stage_controller.get("stage2_field_tick", -1)), 1650, "Compressed resume did not consume exact authored intervals.")
	_check_equal((gate.stage_controller.get("stage2_field_activated_event_ids", []) as Array).slice(0, 12), EVENT_IDS.slice(0, 12), "First twelve field activations were not exact and ordered.")
	_check_equal(gate.stage_controller.get("stage2_field_uid_to_slot", {}).size(), 0, "Catch-up fabricated a field-owned emission inside phase-owned empty intervals.")
	var midboss_removals: Array = []
	for removal_value in gate.stage_controller.get("stage2_field_source_removals", []):
		var removal: Dictionary = removal_value
		if String(removal.get("spawn_id", "")) == "s2_midboss_abacus_tsukumogami":
			midboss_removals.append(removal)
	_check_equal(midboss_removals.size(), 1, "Phase-owned midboss was not carried exactly across s2_b07-s2_b11.")
	if not midboss_removals.is_empty():
		_check_equal(String((midboss_removals[0] as Dictionary).get("reason", "")), "midboss_gate_exit", "Phase-owned midboss lost its explicit s2_b12 removal boundary.")
	_free_main(gate)

func _assert_event_entry_source_reconciliation() -> void:
	var production: Node = _new_main("normal", 73033)
	var guard := 0
	var b01_bullets_before: Array = []
	var b01_used_uids_before: Array = []
	var b01_burst_indices_before: Dictionary = {}
	while "s2_b02" not in (production.stage_controller.get("stage2_field_activated_event_ids", []) as Array) and guard < 200:
		var current_b01_bullets: Array = []
		for uid_value in production.stage2_field_topology_runtime.telemetry_snapshot().get("active_bullet_uids", []):
			var uid := String(uid_value)
			var bullet: Dictionary = production.stage2_field_topology_runtime.bullet_state(uid)
			if String(bullet.get("stage2_source_event_id", "")) == "s2_b01":
				current_b01_bullets.append(uid)
		if not current_b01_bullets.is_empty():
			b01_bullets_before = current_b01_bullets
		if "s2_b01" in (production.stage_controller.get("stage2_field_activated_event_ids", []) as Array):
			var pre_entry_snapshot: Dictionary = production.stage2_field_topology_runtime.capture_snapshot()
			var pre_entry_payload: Dictionary = pre_entry_snapshot.get("payload", {})
			b01_used_uids_before = []
			for uid_value in pre_entry_payload.get("used_uids", []):
				var uid_parts := String(uid_value).split(":", false)
				if uid_parts.size() == 6 and uid_parts[1] == "s2_b01":
					b01_used_uids_before.append(String(uid_value))
			b01_burst_indices_before = {}
			var source_states: Dictionary = pre_entry_payload.get("source_states", {})
			for source_id in ["s2_b01_abacus_left", "s2_b01_abacus_center", "s2_b01_abacus_right"]:
				b01_burst_indices_before[source_id] = int((source_states.get(source_id, {}) as Dictionary).get("next_burst_index", -1))
		var output: Dictionary = production.stage2_encounter_controller.advance(Vector2(production.player_x, production.player_y))
		if not _check(bool(output.get("ok", false)) and production._consume_stage2_controller_output(output), "Production no-shot path rejected before s2_b02 entry at step %d." % guard):
			_free_main(production)
			return
		guard += 1
	if not _check(guard < 200 and "s2_b02" in (production.stage_controller.get("stage2_field_activated_event_ids", []) as Array), "Production no-shot path did not reach s2_b02 entry."):
		_free_main(production)
		return
	var expected_b02 := ["s2_b02_left_clerk", "s2_b02_center_clerk", "s2_b02_right_clerk"]
	_check_equal(production.stage2_field_topology_runtime.telemetry_snapshot().get("active_source_ids", []), expected_b02, "s2_b02 entry did not reconcile runtime sources to the exact data-declared set.")
	_check_equal(_genuinely_live_main_sources(production), expected_b02, "s2_b02 entry left Main source flags out of sync with runtime sources.")
	var b01_enemy_count := 0
	for enemy_value in production.enemies:
		var enemy: Dictionary = enemy_value
		if String(enemy.get("stage2_event_id", "")) != "s2_b01":
			continue
		b01_enemy_count += 1
		_check(not bool(enemy.get("alive", true)) and bool(enemy.get("stage2_source_removal_forwarded", false)), "s2_b02 entry did not retire and forward one stale b01 Main source.")
	_check_equal(b01_enemy_count, 3, "Production source reconciliation did not inspect all three b01 enemies.")
	var reconciliation_order: Array = []
	for removal_value in production.stage_controller.get("stage2_field_source_removals", []):
		var removal: Dictionary = removal_value
		if String(removal.get("reason", "")) == "s2_b02_event_entry_reconciliation":
			reconciliation_order.append(String(removal.get("spawn_id", "")))
	_check_equal(reconciliation_order, ["s2_b01_abacus_left", "s2_b01_abacus_center", "s2_b01_abacus_right"], "s2_b02 stale-source callbacks did not preserve frozen source-row order.")
	_check(not b01_bullets_before.is_empty(), "Production fixture had no pre-existing b01 bullets to preserve.")
	for uid_value in b01_bullets_before:
		var uid := String(uid_value)
		_check(not production.stage2_field_topology_runtime.bullet_state(uid).is_empty() and production.stage_controller.stage2_field_uid_to_slot.has(uid), "Source reconciliation cleared a previously emitted b01 bullet: %s" % uid)
	var continuation_guard := 0
	while int(production.stage_controller.get("stage2_field_tick", -1)) < 288 and continuation_guard < 200:
		var output: Dictionary = production.stage2_encounter_controller.advance(Vector2(production.player_x, production.player_y))
		if not _check(bool(output.get("ok", false)) and production._consume_stage2_controller_output(output), "Production s2_b02 continuation rejected before authored tick 288 at step %d." % continuation_guard):
			_free_main(production)
			return
		continuation_guard += 1
	if not _check_equal(int(production.stage_controller.get("stage2_field_tick", -1)), 288, "Production s2_b02 continuation did not reach the historical cap tick."):
		_free_main(production)
		return
	_check_equal(String(production.stage_controller.get("stage2_field_hard_error", "")), "", "Production s2_b02 continuation latched a field hard error by tick 288.")
	var tick_288_telemetry: Dictionary = production.stage2_field_topology_runtime.telemetry_snapshot()
	var active_b01_at_288: Array = []
	var active_b02_at_288: Array = []
	for uid_value in tick_288_telemetry.get("active_bullet_uids", []):
		var uid := String(uid_value)
		var bullet: Dictionary = production.stage2_field_topology_runtime.bullet_state(uid)
		var source_event_id := String(bullet.get("stage2_source_event_id", ""))
		if source_event_id == "s2_b01":
			active_b01_at_288.append(uid)
			_check(uid in b01_bullets_before, "Tick 288 exposed a post-entry b01 UID instead of a preserved bullet: %s" % uid)
		elif source_event_id == "s2_b02":
			active_b02_at_288.append(uid)
	_check(not active_b01_at_288.is_empty(), "Tick 288 no longer retained any pre-entry b01 bullet evidence.")
	_check(not active_b02_at_288.is_empty(), "Tick 288 did not contain an authored b02 bullet.")
	var tick_288_snapshot: Dictionary = production.stage2_field_topology_runtime.capture_snapshot()
	var tick_288_payload: Dictionary = tick_288_snapshot.get("payload", {})
	var b01_used_uids_at_288: Array = []
	for uid_value in tick_288_payload.get("used_uids", []):
		var uid_parts := String(uid_value).split(":", false)
		if uid_parts.size() == 6 and uid_parts[1] == "s2_b01":
			b01_used_uids_at_288.append(String(uid_value))
	_check_equal(b01_used_uids_at_288, b01_used_uids_before, "s2_b01 created a new UID after s2_b02 entry.")
	var b01_burst_indices_at_288: Dictionary = {}
	var tick_288_source_states: Dictionary = tick_288_payload.get("source_states", {})
	for source_id in ["s2_b01_abacus_left", "s2_b01_abacus_center", "s2_b01_abacus_right"]:
		b01_burst_indices_at_288[source_id] = int((tick_288_source_states.get(source_id, {}) as Dictionary).get("next_burst_index", -1))
	_check_equal(b01_burst_indices_at_288, b01_burst_indices_before, "s2_b01 advanced a burst index after s2_b02 entry.")
	var field_contract: Dictionary = production.stage_director.stage2_field_topology_contract()
	var b02_budget: Dictionary = {}
	for budget_value in field_contract.get("event_budgets", []):
		var budget: Dictionary = budget_value
		if String(budget.get("event_id", "")) == "s2_b02":
			b02_budget = budget
			break
	var normal_b02_cap := int((b02_budget.get("peak_active_bullets", {}) as Dictionary).get("normal", -1))
	if not _check_equal(normal_b02_cap, 60, "Frozen contract Normal s2_b02 cap drifted."):
		_free_main(production)
		return
	var active_bullet_count_at_288 := int(tick_288_telemetry.get("active_bullet_count", -1))
	_check(active_bullet_count_at_288 >= 0 and active_bullet_count_at_288 <= normal_b02_cap, "Tick 288 exceeded the frozen Normal s2_b02 active-bullet cap: %d > %d" % [active_bullet_count_at_288, normal_b02_cap])
	_free_main(production)

	var carryover: Node = _new_main("normal", 73034)
	_check(_activate_direct_event(carryover, "s2_b04"), "b04-to-b05 carryover fixture activation failed.")
	_check(carryover._stage2_begin_field_event(_stage_event(carryover, "s2_b05")), "b05 rejected its declared live b04 booth edges.")
	_check_equal(carryover.stage2_field_topology_runtime.telemetry_snapshot().get("active_source_ids", []), ["s2_b04_left_booth_edge", "s2_b04_right_booth_edge", "s2_b05_left_bead_seller", "s2_b05_right_bead_seller"], "b04-to-b05 declared carryover was not preserved exactly.")
	_check_equal(_genuinely_live_main_sources(carryover), ["s2_b04_left_booth_edge", "s2_b04_right_booth_edge"], "b04 carryover Main flags changed before b05 materialization.")
	_free_main(carryover)

	var mirror: Node = _new_main("hard", 73035)
	_check(_activate_direct_event(mirror, "s2_b15"), "b15-to-b16 carryover fixture activation failed.")
	var selected: Dictionary = mirror.enemies[1]
	selected.dying = true
	selected.death_timer = 8.0
	_check(mirror._stage2_forward_field_source_defeat(selected), "b15 selected-mirror defeat was not forwarded.")
	_check(mirror._stage2_begin_field_event(_stage_event(mirror, "s2_b16")), "b16 rejected the exact genuinely live mirror survivor.")
	_check_equal(mirror.stage2_field_topology_runtime.telemetry_snapshot().get("active_source_ids", []), ["s2_b15_left_mirror", "s2_b16_abacus_keeper"], "b16 did not retain exactly the surviving b15 mirror plus its own source.")
	_check_equal(int(mirror.stage2_field_topology_runtime.telemetry_snapshot().get("hard_state", {}).get("mirror_activation_mask", -1)), 6, "b16 source reconciliation changed the selected-right/surviving-left mask.")
	_check(bool(selected.get("stage2_source_defeat_forwarded", false)) and bool(selected.get("stage2_source_removal_forwarded", false)), "b16 carryover lost the selected mirror forwarding flags.")
	_free_main(mirror)

func _assert_event_entry_rollback() -> void:
	var rollback: Node = _new_main("normal", 73043)
	_check(_activate_direct_event(rollback, "s2_b01") and _advance_field_to(rollback, 24), "Event-entry rollback fixture did not create stale sources and bullets.")
	_check_equal(rollback.stage2_field_topology_runtime.telemetry_snapshot().get("active_source_ids", []), ["s2_b01_abacus_left", "s2_b01_abacus_center", "s2_b01_abacus_right"], "Rollback fixture did not begin with the three stale b01 sources.")
	var runtime_before: Dictionary = rollback.stage2_field_topology_runtime.capture_snapshot()
	var world_before: Dictionary = rollback.capture_bullet_world_state()
	var bindings_before: Dictionary = rollback.stage_controller.stage2_field_uid_to_slot.duplicate(true)
	var enemies_before: Array = rollback.enemies.duplicate(true)
	var controller_before: Dictionary = rollback.stage_controller.duplicate(true)
	var sequence_before := int(rollback.stage_controller.stage2_field_event_sequence)
	var tick_before := int(rollback.stage_controller.stage2_field_tick)
	var live_runtime_id_before := rollback.stage2_field_topology_runtime.get_instance_id()
	var scratch_runtime_id_before := rollback.stage2_field_topology_scratch_runtime.get_instance_id()
	var live_world_id_before := rollback.bullet_world.get_instance_id()
	var scratch_world_id_before := rollback.stage2_field_scratch_bullet_world.get_instance_id()
	var rejected_event: Dictionary = _stage_event(rollback, "s2_b02")
	rejected_event.payload.authored_tick = 151
	_check(not rollback._stage2_begin_field_event(rejected_event), "Event entry accepted an activation with the wrong canonical tick.")
	_check(String(rollback.stage_controller.get("stage2_field_hard_error", "")) != "" and String(rollback.game_manager_ref.state) == "game_over", "Rejected event entry did not latch the final Main error state.")
	_check_equal(rollback.stage2_field_topology_runtime.capture_snapshot(), runtime_before, "Rejected whole entry exposed candidate stale-source removals in the live runtime.")
	_check_equal(rollback.capture_bullet_world_state(), world_before, "Rejected whole entry changed live BulletWorld slots or cursor.")
	_check_equal(rollback.stage_controller.get("stage2_field_uid_to_slot", {}), bindings_before, "Rejected whole entry changed live UID bindings.")
	_check_equal(rollback.enemies, enemies_before, "Rejected whole entry exposed candidate Main enemy flag changes.")
	_check_equal(int(rollback.stage_controller.stage2_field_event_sequence), sequence_before, "Rejected whole entry consumed live callback sequences.")
	_check_equal(int(rollback.stage_controller.stage2_field_tick), tick_before, "Rejected whole entry advanced the live field tick.")
	_check_equal(rollback.stage2_field_topology_runtime.get_instance_id(), live_runtime_id_before, "Rejected whole entry replaced the live runtime owner.")
	_check_equal(rollback.stage2_field_topology_scratch_runtime.get_instance_id(), scratch_runtime_id_before, "Rejected whole entry replaced the scratch runtime owner.")
	_check_equal(rollback.bullet_world.get_instance_id(), live_world_id_before, "Rejected whole entry replaced the live BulletWorld owner.")
	_check_equal(rollback.stage2_field_scratch_bullet_world.get_instance_id(), scratch_world_id_before, "Rejected whole entry replaced the scratch BulletWorld owner.")
	_check(live_runtime_id_before != scratch_runtime_id_before and live_world_id_before != scratch_world_id_before, "Rollback fixture began with aliased live/scratch owners.")
	var controller_without_latched_error: Dictionary = rollback.stage_controller.duplicate(true)
	for key in ["stage2_hard_error", "stage2_field_hard_error"]:
		if controller_before.has(key):
			controller_without_latched_error[key] = controller_before[key]
		else:
			controller_without_latched_error.erase(key)
	_check_equal(controller_without_latched_error, controller_before, "Rejected whole entry changed stage_controller beyond the final latched error fields.")
	_free_main(rollback)

func _assert_fail_closed_paths() -> void:
	var exhausted: Node = _new_main("normal", 73041)
	exhausted.bullet_world.configure(0, 0, 1)
	exhausted._sync_bullet_world_compatibility_views()
	var first: Dictionary = exhausted.stage2_encounter_controller.advance(Vector2(exhausted.player_x, exhausted.player_y))
	_check(exhausted._consume_stage2_controller_output(first), "Pool fixture rejected activation before construction.")
	var exhausted_runtime_before: Dictionary = exhausted.stage2_field_topology_runtime.capture_snapshot()
	var exhausted_world_before: Dictionary = exhausted.capture_bullet_world_state()
	var exhausted_bindings_before: Dictionary = exhausted.stage_controller.stage2_field_uid_to_slot.duplicate(true)
	var exhausted_sequence_before := int(exhausted.stage_controller.stage2_field_event_sequence)
	var exhausted_tick_before := int(exhausted.stage_controller.stage2_field_tick)
	_check(not exhausted._stage2_field_callback("advance", 24), "Pool exhaustion did not fail closed.")
	_check(String(exhausted.stage_controller.get("stage2_field_hard_error", "")) != "" and String(exhausted.game_manager_ref.state) == "game_over", "Pool exhaustion did not latch Main failure state.")
	_check_equal(exhausted.stage2_field_topology_runtime.capture_snapshot(), exhausted_runtime_before, "Pool rejection changed the live cursor, active bullets, or used UID ledger.")
	_check_equal(exhausted.capture_bullet_world_state(), exhausted_world_before, "Pool rejection changed live BulletWorld slots or spawn cursor.")
	_check_equal(exhausted.stage_controller.get("stage2_field_uid_to_slot", {}), exhausted_bindings_before, "Pool rejection exposed a partial UID binding.")
	_check_equal(int(exhausted.stage_controller.stage2_field_event_sequence), exhausted_sequence_before, "Pool rejection consumed a live callback sequence.")
	_check_equal(int(exhausted.stage_controller.stage2_field_tick), exhausted_tick_before, "Pool rejection advanced the live field tick.")
	_free_main(exhausted)

	var hard_error: Node = _new_main("normal", 73042)
	_check(_activate_direct_event(hard_error, "s2_b01") and _advance_field_to(hard_error, 24), "Runtime-hard-error fixture did not create live field state.")
	var hard_runtime_before: Dictionary = hard_error.stage2_field_topology_runtime.capture_snapshot()
	var hard_world_before: Dictionary = hard_error.capture_bullet_world_state()
	var hard_bindings_before: Dictionary = hard_error.stage_controller.stage2_field_uid_to_slot.duplicate(true)
	var hard_sequence_before := int(hard_error.stage_controller.stage2_field_event_sequence)
	var hard_tick_before := int(hard_error.stage_controller.stage2_field_tick)
	_check(not hard_error._stage2_field_callback("activate_event", 24, {"event_id": "s2_unknown", "active_entity_ids": []}), "Runtime hard error was accepted.")
	_check(String(hard_error.stage_controller.get("stage2_field_hard_error", "")) != "" and String(hard_error.game_manager_ref.state) == "game_over", "Runtime hard error did not fail Main closed.")
	_check_equal(hard_error.stage2_field_topology_runtime.capture_snapshot(), hard_runtime_before, "Rejected runtime hard error contaminated the live runtime state.")
	_check_equal(hard_error.capture_bullet_world_state(), hard_world_before, "Rejected runtime hard error changed live BulletWorld state.")
	_check_equal(hard_error.stage_controller.get("stage2_field_uid_to_slot", {}), hard_bindings_before, "Rejected runtime hard error changed live UID bindings.")
	_check_equal(int(hard_error.stage_controller.stage2_field_event_sequence), hard_sequence_before, "Rejected runtime hard error consumed a live sequence.")
	_check_equal(int(hard_error.stage_controller.stage2_field_tick), hard_tick_before, "Rejected runtime hard error moved the live cursor.")
	_free_main(hard_error)

func _advance_real_ticks(main: Node, count: int) -> bool:
	for _index in range(count):
		var output: Dictionary = main.stage2_encounter_controller.advance(Vector2(main.player_x, main.player_y))
		if not _check(bool(output.get("ok", false)) and main._consume_stage2_controller_output(output), "Real controller/field continuation failed."):
			return false
	return true

func _assert_aggregate_snapshot_and_legacy_shape() -> void:
	var main: Node = _new_main("normal", 73051)
	_check(_advance_real_ticks(main, 25), "Snapshot fixture did not reach the first construction.")
	var snapshot: Dictionary = main.capture_simulation_state()
	_check_equal(int(snapshot.get("version", -1)), 4, "Stage 2 aggregate snapshot version did not advance.")
	_check(snapshot.get("stage2_field_runtime") is Dictionary and main.validate_simulation_state(snapshot), "Main rejected its own field aggregate snapshot.")
	_check(not snapshot.has("stage2_field_topology_scratch_runtime") and not snapshot.has("stage2_field_scratch_bullet_world"), "Ephemeral scratch owners leaked into the persistence schema.")
	var before_rejection: String = main.simulation_state_hash()
	var forged_binding: Dictionary = snapshot.duplicate(true)
	var binding_uids: Array = forged_binding.stage_controller.stage2_field_uid_to_slot.keys()
	var forged_uid := String(binding_uids[0])
	forged_binding.stage_controller.stage2_field_uid_to_slot[forged_uid] = int(forged_binding.stage_controller.stage2_field_uid_to_slot[forged_uid]) + 1
	_check(not main.restore_simulation_state(forged_binding), "Aggregate restore accepted a forged UID/slot binding.")
	_check_equal(main.simulation_state_hash(), before_rejection, "Rejected binding forgery partially mutated Main.")
	var forged_seam: Dictionary = snapshot.duplicate(true)
	for entry_value in forged_seam.bullets.active_bullets:
		var entry: Dictionary = entry_value
		if bool(entry.state.get("stage2_field_owned", false)):
			entry.state.stage2_collision_enable_tick = int(entry.state.stage2_collision_enable_tick) + 1
			break
	_check(not main.restore_simulation_state(forged_seam), "Aggregate restore accepted a forged field seam.")
	_check_equal(main.simulation_state_hash(), before_rejection, "Rejected seam forgery partially mutated Main.")
	var reference: Node = _new_main("normal", 73051)
	_check(main.restore_simulation_state(snapshot), "Source Main rejected the valid aggregate snapshot.")
	_check(reference.restore_simulation_state(snapshot), "Disposable field/controller owners rejected valid aggregate restore.")
	_check(main.stage2_field_topology_runtime != main.stage2_field_topology_scratch_runtime and main.bullet_world != main.stage2_field_scratch_bullet_world, "Aggregate restore did not rebuild distinct scratch owners.")
	_check(_advance_real_ticks(main, 1) and _advance_real_ticks(reference, 1), "Post-restore next output failed.")
	_check_equal(main.simulation_state_hash(), reference.simulation_state_hash(), "Post-restore next-output/state-hash equivalence diverged.")
	_free_main(reference)
	_free_main(main)

	var legacy: Node = _new_main("normal", 73052)
	legacy._set_active_stage(1)
	legacy._load_stage(1)
	legacy.game_manager_ref.state = "stage"
	var legacy_snapshot: Dictionary = legacy.capture_simulation_state()
	_check_equal(int(legacy_snapshot.get("version", -1)), 2, "Legacy aggregate version changed.")
	_check(not legacy_snapshot.has("stage2_controller") and not legacy_snapshot.has("stage2_field_runtime"), "Legacy snapshot gained Stage 2 ownership fields.")
	_check(legacy.validate_simulation_state(legacy_snapshot), "Legacy stage snapshot shape no longer validates.")
	_free_main(legacy)

func _run() -> void:
	_assert_contract_loading_and_first_construction()
	_assert_clock_discriminator_and_scratch_performance()
	_assert_delayed_seed_rebound_removal_and_projection()
	_assert_source_callbacks_and_gate_catchup()
	_assert_event_entry_source_reconciliation()
	_assert_fail_closed_paths()
	_assert_event_entry_rollback()
	_assert_aggregate_snapshot_and_legacy_shape()
	if failed:
		quit(1)
		return
	print("PASS: M2 Stage 2 field topology Main/BulletWorld integration, callbacks, gates, domains, and atomic snapshots.")
	quit(0)

func _initialize() -> void:
	call_deferred("_run")
