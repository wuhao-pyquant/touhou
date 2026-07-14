extends SceneTree

const FixedTickClock := preload("res://scripts/runtime/fixed_tick_clock.gd")
const DeterministicRng := preload("res://scripts/runtime/deterministic_rng.gd")
const SimulationStateHasher := preload("res://scripts/runtime/simulation_state_hasher.gd")
const BulletWorld := preload("res://scripts/runtime/bullet_world.gd")
const BossStateMachine := preload("res://scripts/runtime/boss_state_machine.gd")
const GameplayInputBuffer := preload("res://scripts/runtime/gameplay_input_buffer.gd")

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
	clock.reset()
	_check(clock.push_frame_delta(0.2) == 3, "Long frame must accept the explicit per-render tick budget.")
	_check(clock.dropped_ticks == 9, "Long frame elapsed time was not explicitly accounted as dropped ticks.")
	_check(is_equal_approx(clock.total_frame_seconds, 0.2), "Long frame elapsed seconds were silently clamped.")

func _verify_input_buffer() -> void:
	var input := GameplayInputBuffer.new()
	input.sample_frame({"move_x": 0.5, "move_y": -0.25, "shoot": true, "focus": true, "bomb": true, "pause": true})
	_check(input.pending_edges == {"bomb": 1, "pause": 1}, "Just-pressed edges were not buffered before a simulation tick.")
	var first: Dictionary = input.consume_tick(1)
	_check(first.move_x == 16384 and first.move_y == -8192, "Analog axes were not deterministically quantized with sub-unit precision.")
	_check(first.bomb and first.pause, "Buffered edges were not delivered to the next simulation tick.")
	var second: Dictionary = input.consume_tick(2)
	_check(second.shoot and second.focus, "Held input was not preserved across simulation ticks.")
	_check(not second.bomb and not second.pause, "A buffered edge was consumed by more than one simulation tick.")
	_check(input.consumed_edges == {"bomb": 1, "pause": 1}, "Consumed edge accounting is incorrect.")

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
	_check(restored.active_indices == [1, 0], "BulletWorld must preserve authoritative active processing order.")
	_check(world.laser_state(restored_pool[1]) == BulletWorld.LASER_WARNING, "BulletWorld lost laser warning state.")
	_check(world.circles_overlap(Vector2.ZERO, 2.0, Vector2(3.0, 0.0), 2.0), "Strict circle collision should overlap within the summed radius.")
	_check(not world.circles_overlap(Vector2.ZERO, 2.0, Vector2(4.0, 0.0), 2.0), "Strict circle collision should not overlap at exact tangency.")

	var machine := BossStateMachine.new()
	var boss: Dictionary = machine.create_initial_state(360.0, -60.0, 4.0)
	_check(machine.transition(boss, BossStateMachine.PHASE_ACTIVE), "Boss entering-to-active transition failed.")
	_check(machine.transition(boss, BossStateMachine.PHASE_SWITCHING, true), "Boss active-to-switching transition failed.")
	_check(not machine.transition(boss, BossStateMachine.PHASE_ENTERING), "Boss state machine accepted an invalid reverse transition.")
	_check(not machine.restore_state({"version": 999, "state": boss}), "Boss state machine accepted an unsupported snapshot version.")

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
	_verify_input_buffer()
	_verify_rng_and_hashing()
	_verify_state_boundaries()
	_verify_main_integration()
	if failed:
		quit(1)
	else:
		print("PASS: M0 fixed tick, quantized input buffering, RNG snapshots, and authoritative state boundaries.")
		quit(0)

func _initialize() -> void:
	call_deferred("_run")
