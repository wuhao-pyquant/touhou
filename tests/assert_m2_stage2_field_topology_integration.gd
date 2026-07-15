extends SceneTree

const StageDirector := preload("res://scripts/runtime/stage_director.gd")
const GameplayInputBuffer := preload("res://scripts/runtime/gameplay_input_buffer.gd")
const MainScript := preload("res://scripts/main.gd")

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
	_check(_advance_field_to(normal, 24), "Normal first authored construction did not materialize.")
	_check(_advance_field_to(hard, 24), "Hard first authored construction did not materialize.")
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
	var items_before := rebound.items.duplicate(true)
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
		_check(gate._consume_stage2_controller_output(output), "Main rejected pre-midboss field output at step %d." % guard)
		guard += 1
	_check(guard < 800 and gate.stage2_encounter_controller.encounter_kind() == "midboss", "Real Main path did not reach the midboss gate.")
	_check_equal(int(gate.stage_controller.get("stage2_field_tick", -1)), 750, "Field clock did not freeze at the midboss gate.")
	_check_equal(gate.stage_controller.get("stage2_field_uid_to_slot", {}).size(), 0, "Midboss gate did not clear field bullets.")
	_check(not (gate.stage_controller.get("stage2_field_source_removals", []) as Array).is_empty(), "Midboss gate did not clear field sources.")
	var first_resolution: Dictionary = gate.stage2_encounter_controller.resolve_active_phase("clear")
	_check(gate._consume_stage2_controller_output(first_resolution), "First midboss phase resolution failed.")
	var second_resolution: Dictionary = gate.stage2_encounter_controller.resolve_active_phase("clear")
	_check(gate._consume_stage2_controller_output(second_resolution), "Second midboss phase resolution failed.")
	_check_equal(int(gate.stage_controller.get("stage2_field_tick", -1)), 750, "Active midboss advanced the frozen field clock.")
	var resume: Dictionary = gate.stage2_encounter_controller.advance(Vector2(gate.player_x, gate.player_y))
	_check(gate._consume_stage2_controller_output(resume), "Compressed post-midboss authored catch-up failed.")
	_check_equal((resume.get("stage_events", []) as Array).map(func(event): return String(event.get("id", ""))), EVENT_IDS.slice(6, 12), "Compressed resume event order drifted.")
	_check_equal(int(gate.stage_controller.get("stage2_field_tick", -1)), 1650, "Compressed resume did not consume exact authored intervals.")
	_check_equal((gate.stage_controller.get("stage2_field_activated_event_ids", []) as Array).slice(0, 12), EVENT_IDS.slice(0, 12), "First twelve field activations were not exact and ordered.")
	_check_equal(gate.stage_controller.get("stage2_field_uid_to_slot", {}).size(), 0, "Catch-up fabricated a field-owned emission inside phase-owned empty intervals.")
	_free_main(gate)

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
	var before_rejection := main.simulation_state_hash()
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
	_assert_delayed_seed_rebound_removal_and_projection()
	_assert_source_callbacks_and_gate_catchup()
	_assert_fail_closed_paths()
	_assert_aggregate_snapshot_and_legacy_shape()
	if failed:
		quit(1)
		return
	print("PASS: M2 Stage 2 field topology Main/BulletWorld integration, callbacks, gates, domains, and atomic snapshots.")
	quit(0)

func _initialize() -> void:
	call_deferred("_run")
