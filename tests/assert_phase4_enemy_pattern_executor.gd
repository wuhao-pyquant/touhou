extends SceneTree

var failed := false

func _fail(message: String) -> void:
	if failed:
		return
	failed = true
	push_error(message)
	quit(1)

func _assert(condition: bool, message: String) -> bool:
	if not condition:
		_fail(message)
		return false
	return true

func _assert_equal(actual, expected, message: String) -> bool:
	if actual != expected:
		_fail("%s Expected %s, got %s" % [message, expected, actual])
		return false
	return true

func _assert_spec(spec: Dictionary, family_id: String) -> void:
	for key in ["position", "velocity", "radius", "color", "family_id", "lifetime"]:
		_assert(spec.has(key), "Bullet spec missing %s: %s" % [key, spec])
	_assert_equal(String(spec.family_id), family_id, "Bullet spec family mismatch.")
	_assert(spec.position is Vector2, "Bullet spec position should be Vector2.")
	_assert(spec.velocity is Vector2, "Bullet spec velocity should be Vector2.")
	_assert(float(spec.radius) >= 3.0, "Bullet radius should be readable.")
	_assert(float(spec.lifetime) > 0.0, "Bullet lifetime should be positive.")

func _verify_executor() -> void:
	var executor_script = load("res://scripts/runtime/enemy_pattern_executor.gd")
	if not _assert(executor_script != null, "Could not load enemy_pattern_executor.gd"):
		return
	var executor = executor_script.new()
	for method in ["family_id_for_pattern", "spawn_config", "bullet_specs"]:
		if not _assert(executor.has_method(method), "EnemyPatternExecutor missing method %s" % method):
			return

	_assert_equal(executor.family_id_for_pattern("aimed"), "low_yokai", "aimed family mismatch.")
	_assert_equal(executor.family_id_for_pattern("downward"), "fast_attacker", "downward family mismatch.")
	_assert_equal(executor.family_id_for_pattern("ring"), "formation_shooter", "ring family mismatch.")
	_assert_equal(executor.family_id_for_pattern("double_spread"), "elite_yokai", "double_spread family mismatch.")
	_assert_equal(executor.family_id_for_pattern("wave"), "mechanism", "wave family mismatch.")
	_assert_equal(executor.family_id_for_pattern("aimed", true), "elite_yokai", "strong aimed enemies should use elite family metadata.")

	var cfg: Dictionary = executor.spawn_config("ring", 10.0, 1.5, false)
	_assert_equal(String(cfg.family_id), "formation_shooter", "Spawn config family mismatch.")
	_assert(abs(float(cfg.hp) - 30.0) <= 0.001, "Spawn config should preserve existing 2x HP and apply stage hp mult, got %f" % float(cfg.hp))
	_assert_equal(String(cfg.drop_tier), "standard", "Formation shooter drop tier mismatch.")
	_assert(float(cfg.shoot_interval) >= 24.0, "Spawn config shoot interval should be bounded.")

	var enemy := {"x": 200.0, "y": 120.0, "pattern": "aimed", "shoot_phase": 1}
	var aimed: Array = executor.bullet_specs(enemy, Vector2(360.0, 540.0), 1.0)
	_assert_equal(aimed.size(), 1, "aimed should emit one bullet.")
	_assert_spec(aimed[0], "circle")

	enemy.pattern = "downward"
	var downward: Array = executor.bullet_specs(enemy, Vector2(360.0, 540.0), 1.0)
	_assert_equal(downward.size(), 1, "downward should emit one bullet.")
	_assert_spec(downward[0], "needle")
	_assert(float(downward[0].velocity.y) > 0.0, "downward bullet should move down.")

	enemy.pattern = "ring"
	var ring: Array = executor.bullet_specs(enemy, Vector2(360.0, 540.0), 1.0)
	_assert_equal(ring.size(), 12, "ring should emit 12 bullets.")
	_assert_spec(ring[0], "star")

	enemy.pattern = "double_spread"
	var double_spread: Array = executor.bullet_specs(enemy, Vector2(360.0, 540.0), 1.0)
	_assert_equal(double_spread.size(), 5, "double_spread should emit 5 bullets.")
	_assert_spec(double_spread[0], "talisman")

	enemy.pattern = "wave"
	var wave: Array = executor.bullet_specs(enemy, Vector2(360.0, 540.0), 1.0)
	_assert_equal(wave.size(), 5, "wave should emit 5 bullets.")
	_assert_spec(wave[0], "rice")

	enemy.pattern = "spiral"
	var spiral: Array = executor.bullet_specs(enemy, Vector2(360.0, 540.0), 1.0)
	_assert_equal(spiral.size(), 8, "spiral should emit 8 bullets.")
	_assert_spec(spiral[0], "butterfly")

func _verify_main_spawn_contract() -> void:
	var gm = load("res://autoload/game_manager.gd").new()
	var main_script = load("res://scripts/main.gd")
	if not _assert(main_script != null, "Could not load main.gd"):
		gm.free()
		return
	var main_shell = main_script.new()
	main_shell.game_manager_ref = gm
	gm.current_stage = 6
	main_shell.enemies = []
	for method in ["_spawn_enemy", "_spawn_enemy_bullet_spec"]:
		if not _assert(main_shell.has_method(method), "Main missing method %s" % method):
			main_shell.free()
			gm.free()
			return
	main_shell._spawn_enemy(100.0, 20.0, 10.0, "ring", "straight", 0.0, 1.0, {}, false)
	_assert_equal(main_shell.enemies.size(), 1, "Main should spawn one enemy.")
	var enemy: Dictionary = main_shell.enemies[0]
	_assert_equal(String(enemy.family_id), "formation_shooter", "Main enemy should include family_id.")
	_assert_equal(String(enemy.drop_tier), "standard", "Main enemy should include drop_tier.")
	_assert(float(enemy.hp) > 20.0, "Stage 6 enemy HP should apply stage hp multiplier after existing 2x baseline.")
	_assert(float(enemy.shoot_interval) >= 24.0, "Main enemy should include bounded shoot_interval.")
	main_shell.bullet_pool = []
	for i in range(8):
		main_shell.bullet_pool.append(main_shell._make_bullet())
	main_shell._spawn_enemy_bullet_spec({"position": Vector2(10, 10), "velocity": Vector2(1, 2), "radius": 4.0, "color": Color.YELLOW, "family_id": "needle", "lifetime": 120.0})
	_assert_equal(String(main_shell.bullet_pool[0].type), "needle", "Main should spawn enemy bullet by data family id.")
	main_shell.free()
	gm.free()

func _init() -> void:
	_verify_executor()
	if failed:
		return
	_verify_main_spawn_contract()
	if failed:
		return
	quit(0)
