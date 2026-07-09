extends SceneTree

var failed := false
const EXPECTED_FAMILIES := ["circle", "rice", "butterfly", "needle", "talisman", "star", "laser", "large_orb"]

class FakeGameDatabase:
	extends RefCounted

	var graze_value: int
	var family_ids: Array

	func _init(custom_graze: int, custom_family_ids: Array) -> void:
		graze_value = custom_graze
		family_ids = custom_family_ids.duplicate(true)

	func bullet_families() -> Array:
		var result: Array = []
		for family_id in family_ids:
			result.append({"id": String(family_id)})
		return result

	func scoring_rules() -> Dictionary:
		return {"graze": graze_value, "enemy_defeat": 50}

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

func _new_main_with_pool() -> Node:
	var gm = load("res://autoload/game_manager.gd").new()
	var main_shell = load("res://scripts/main.gd").new()
	main_shell.game_manager_ref = gm
	main_shell.audio_manager_ref = null
	main_shell.items = []
	main_shell.enemies = []
	main_shell.game_database_ref = FakeGameDatabase.new(37, EXPECTED_FAMILIES)
	main_shell.game_database = main_shell.game_database_ref
	main_shell.bullet_pool = []
	for i in range(32):
		main_shell.bullet_pool.append(main_shell._make_bullet())
	return main_shell

func _activate_bullet(main_shell: Node, idx: int, type_id: String, x: float, y: float, radius: float = 5.0) -> void:
	var bullet: Dictionary = main_shell.bullet_pool[idx]
	bullet.active = true
	bullet.type = type_id
	bullet.x = x
	bullet.y = y
	bullet.vx = 0.0
	bullet.vy = 0.0
	bullet.radius = radius
	bullet.age = 0.0
	bullet.lifetime = 120.0
	main_shell.bullet_pool[idx] = bullet

func _free_main(main_shell: Node) -> void:
	var gm = main_shell.game_manager_ref
	main_shell.free()
	if gm:
		gm.free()

func _verify_bullet_family_contract() -> void:
	var main_shell = _new_main_with_pool()
	for method in ["_enemy_bullet_types", "_is_enemy_bullet_type", "_count_active_bullets_by_owner", "_check_collisions"]:
		if not _assert(main_shell.has_method(method), "Main missing method %s" % method):
			_free_main(main_shell)
			return

	var type_ids: Array = main_shell._enemy_bullet_types()
	for type_id in EXPECTED_FAMILIES:
		_assert(type_ids.has(type_id), "Enemy bullet type list missing %s" % type_id)
		_assert(main_shell._is_enemy_bullet_type(type_id), "%s should be classified as enemy bullet." % type_id)
	_assert(main_shell._is_enemy_bullet_type("arrow"), "Legacy arrow should remain an enemy bullet.")
	_assert(not main_shell._is_enemy_bullet_type("player"), "player should not be classified as enemy bullet.")
	_assert(not main_shell._is_enemy_bullet_type("bomb"), "bomb should not be classified as enemy bullet.")

	for i in range(EXPECTED_FAMILIES.size()):
		_activate_bullet(main_shell, i, EXPECTED_FAMILIES[i], 200.0 + i, 200.0)
	_activate_bullet(main_shell, EXPECTED_FAMILIES.size(), "arrow", 300.0, 200.0)
	var counts: Dictionary = main_shell._count_active_bullets_by_owner()
	_assert_equal(int(counts.enemy), 9, "All Phase 4 enemy bullet families plus arrow should count as enemy bullets.")
	_assert_equal(int(counts.player), 0, "No player bullets should be active.")
	_free_main(main_shell)

func _verify_collision_uses_all_enemy_bullet_families() -> void:
	var main_shell = _new_main_with_pool()
	var gm = main_shell.game_manager_ref
	main_shell.player_x = 360.0
	main_shell.player_y = 540.0
	main_shell.player_invincible = false
	main_shell.player_deathbomb_primed = false
	_activate_bullet(main_shell, 0, "needle", 360.0, 540.0)
	main_shell._check_collisions(false)
	_assert(main_shell.player_deathbomb_primed, "Needle bullet should trigger player hit collision.")
	_assert(not main_shell.bullet_pool[0].active, "Colliding needle bullet should deactivate.")

	main_shell.player_deathbomb_primed = false
	main_shell.player_just_hit = false
	main_shell.player_invincible = true
	gm.graze = 0
	gm.score = 0
	_activate_bullet(main_shell, 1, "large_orb", 360.0 + gm.PLAYER_GRAZE + 7.5, 540.0, 8.0)
	main_shell._check_collisions(false)
	_assert_equal(gm.graze, 1, "Large orb should be eligible for graze.")
	_assert_equal(gm.score, 37, "Graze should use scoring data for large orb bullets.")
	_free_main(main_shell)

func _init() -> void:
	_verify_bullet_family_contract()
	if failed:
		return
	_verify_collision_uses_all_enemy_bullet_families()
	if failed:
		return
	quit(0)
