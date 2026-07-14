extends SceneTree

const FixedTickClock := preload("res://scripts/runtime/fixed_tick_clock.gd")
const DeterministicRng := preload("res://scripts/runtime/deterministic_rng.gd")
const SimulationStateHasher := preload("res://scripts/runtime/simulation_state_hasher.gd")
const BulletWorld := preload("res://scripts/runtime/bullet_world.gd")
const BossStateMachine := preload("res://scripts/runtime/boss_state_machine.gd")
const ReplayData := preload("res://scripts/replay/replay_data.gd")

class EmptyStageDirector:
	extends RefCounted

	func due_wave_events(_stage_index: int, _timer: int, _triggered: Dictionary) -> Array:
		return []

var failed := false

func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	failed = true
	push_error(message)
	return false

func _load_fixture() -> Dictionary:
	var file := FileAccess.open("res://tests/fixtures/m0/baseline_replay.json", FileAccess.READ)
	if not _check(file != null, "Could not open the M0 baseline replay fixture."):
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not _check(parsed is Dictionary, "M0 baseline replay fixture must contain a JSON object."):
		return {}
	return parsed

func _verify_clock() -> void:
	var clock := FixedTickClock.new()
	_check(clock.push_frame_delta(1.0 / 30.0) == 2, "A 30 Hz render frame must yield two fixed simulation ticks.")
	_check(clock.consume_tick(), "First fixed tick was not available.")
	_check(clock.consume_tick(), "Second fixed tick was not available.")
	_check(not clock.consume_tick(), "Fixed clock yielded an extra tick.")
	_check(clock.tick_index == 2, "Fixed clock tick index mismatch.")
	var snapshot: Dictionary = clock.snapshot()
	clock.reset()
	_check(clock.restore(snapshot), "Fixed clock snapshot restore failed.")
	_check(clock.tick_index == 2, "Fixed clock restore lost the tick index.")

func _verify_rng_and_hashing() -> void:
	var rng := DeterministicRng.new(314159)
	rng.next_float()
	var snapshot: Dictionary = rng.snapshot()
	var expected_a: float = rng.range_float(-3.0, 7.0)
	var expected_b: int = rng.range_int(2, 20)
	_check(rng.restore(snapshot), "Seeded RNG snapshot restore failed.")
	_check(rng.range_float(-3.0, 7.0) == expected_a, "Seeded RNG float stream diverged after restore.")
	_check(rng.range_int(2, 20) == expected_b, "Seeded RNG integer stream diverged after restore.")
	var hasher := SimulationStateHasher.new()
	var first := {"z": [1, 2.0, Vector2(3, 4)], "a": {"right": true, "left": false}}
	var second := {"a": {"left": false, "right": true}, "z": [1, 2.0, Vector2(3, 4)]}
	_check(hasher.hash_state(first) == hasher.hash_state(second), "Canonical hashing must ignore Dictionary insertion order.")

func _verify_state_boundaries() -> void:
	var world := BulletWorld.new()
	var pool: Array = [world.make_bullet_state(), world.make_bullet_state()]
	pool[0].active = true
	pool[0].x = 12.0
	pool[1].active = true
	pool[1].type = "laser"
	pool[1].laser_state = BulletWorld.LASER_WARNING
	var snapshot: Dictionary = world.capture_state(pool, [1, 0], 1)
	var restored_pool: Array = []
	var restored: Dictionary = world.restore_state(snapshot, restored_pool)
	_check(bool(restored.ok), "BulletWorld snapshot restore failed.")
	_check(restored.active_indices == [0, 1], "BulletWorld must restore active slots in canonical order.")
	_check(world.laser_state(restored_pool[1]) == BulletWorld.LASER_WARNING, "BulletWorld lost laser warning state.")
	_check(world.circles_overlap(Vector2.ZERO, 2.0, Vector2(3.0, 0.0), 2.0), "Strict circle collision should overlap within the summed radius.")
	_check(not world.circles_overlap(Vector2.ZERO, 2.0, Vector2(4.0, 0.0), 2.0), "Strict circle collision should not overlap at exact tangency.")

	var machine := BossStateMachine.new()
	var boss: Dictionary = machine.create_initial_state(360.0, -60.0, 4.0)
	_check(machine.transition(boss, BossStateMachine.PHASE_ACTIVE), "Boss entering-to-active transition failed.")
	_check(machine.transition(boss, BossStateMachine.PHASE_SWITCHING, true), "Boss active-to-switching transition failed.")
	_check(not machine.transition(boss, BossStateMachine.PHASE_ENTERING), "Boss state machine accepted an invalid reverse transition.")
	_check(not machine.restore_state({"version": 999, "state": boss}), "Boss state machine accepted an unsupported snapshot version.")

func _replay_once(document: Dictionary) -> String:
	var replay := ReplayData.new()
	if not _check(replay.load_dict(document), "Baseline replay data failed validation."):
		return ""
	var rng := DeterministicRng.new(int(replay.header.seed))
	var initial: Dictionary = document.get("initial_state", {})
	var player := Vector2(float(initial.get("player_x", 360.0)), float(initial.get("player_y", 840.0)))
	var score := int(initial.get("score", 0))
	var bullets: Array[Dictionary] = []
	var final_tick := -1
	while replay.has_next_frame():
		var frame: Dictionary = replay.next_frame()
		final_tick = int(frame.tick)
		var move := Vector2(float(frame.move_x), float(frame.move_y))
		if move.length_squared() > 1.0:
			move = move.normalized()
		player += move * (2.0 if bool(frame.focus) else 4.0)
		if bool(frame.shoot):
			bullets.append({
				"id": bullets.size(),
				"x": player.x,
				"y": player.y - 12.0,
				"vx": rng.range_float(-0.18, 0.18),
				"vy": -8.0,
				"age": 0,
			})
			score += 10
		for bullet in bullets:
			bullet.x = float(bullet.x) + float(bullet.vx)
			bullet.y = float(bullet.y) + float(bullet.vy)
			bullet.age = int(bullet.age) + 1
		if bool(frame.bomb):
			bullets.clear()
			score += 100
	var final_state := {
		"format_version": int(document.get("format_version", -1)),
		"header": replay.header.to_dict(),
		"final_tick": final_tick,
		"player": player,
		"score": score,
		"bullets": bullets,
		"rng": rng.snapshot(),
	}
	return SimulationStateHasher.new().hash_state(final_state)

func _verify_main_integration() -> void:
	var main_script = load("res://scripts/main.gd")
	if not _check(main_script != null and main_script.can_instantiate(), "Main runtime script did not parse or could not be instantiated."):
		return
	var main_shell = main_script.new()
	_check(main_shell.fixed_tick_clock != null, "Main runtime is missing the fixed-tick clock integration.")
	main_shell.set_gameplay_seed(77)
	var first: float = main_shell.gameplay_rng.next_float()
	main_shell.set_gameplay_seed(77)
	_check(main_shell.gameplay_rng.next_float() == first, "Main runtime gameplay seed does not reset its deterministic stream.")
	var bullet: Dictionary = main_shell._make_bullet()
	_check(bullet.has("laser_state"), "Main runtime bullet state is not sourced from BulletWorld.")
	main_shell.game_manager_ref.state = "stage"
	main_shell.stage_director = EmptyStageDirector.new()
	main_shell.stage_controller = {"boss_time": 999999, "boss_spawned": false, "triggered_waves": {}}
	main_shell.stage_timer = 0.0
	_check(main_shell._advance_gameplay_clock(1.0 / 30.0) == 2, "Main runtime did not execute two fixed ticks for a 30 Hz render frame.")
	_check(main_shell.stage_timer == 2.0, "Main runtime leaked render delta into stage simulation timing.")
	var owned_game_manager: Object = main_shell.game_manager_ref
	var owned_asset_registry: Object = main_shell.asset_registry_ref
	main_shell.game_manager_ref = null
	main_shell.asset_registry_ref = null
	main_shell.free()
	owned_game_manager.free()
	owned_asset_registry.free()

func _run() -> void:
	_verify_clock()
	_verify_rng_and_hashing()
	_verify_state_boundaries()
	_verify_main_integration()
	var fixture := _load_fixture()
	if fixture.is_empty():
		quit(1)
		return
	var observed: Array[String] = []
	for _run_index in range(3):
		observed.append(_replay_once(fixture))
	var expected := String(fixture.get("expected_state_hash", ""))
	if expected == "PENDING":
		print("M0_BASELINE_HASH=%s" % observed[0])
		expected = observed[0]
	_check(observed == [expected, expected, expected], "Baseline replay hashes diverged: %s (expected %s)" % [observed, expected])
	if failed:
		quit(1)
	else:
		print("PASS: M0 fixed tick, RNG snapshots, state boundaries, and replay determinism. hashes=%s" % [observed])
		quit(0)

func _initialize() -> void:
	call_deferred("_run")
