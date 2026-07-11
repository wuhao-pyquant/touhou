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

class CountingGameDatabase:
	extends FakeGameDatabase

	var bullet_families_calls: int = 0

	func bullet_families() -> Array:
		bullet_families_calls += 1
		return super.bullet_families()

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
	main_shell._active_index_initialized = false
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

func _activate_enemy_family_set(main_shell: Node, start_idx: int, y: float = 200.0) -> void:
	for i in range(EXPECTED_FAMILIES.size()):
		_activate_bullet(main_shell, start_idx + i, EXPECTED_FAMILIES[i], 200.0 + i * 8.0, y, 8.0)
	_activate_bullet(main_shell, start_idx + EXPECTED_FAMILIES.size(), "arrow", 320.0, y, 8.0)

func _assert_enemy_family_set_cleared(main_shell: Node, start_idx: int, message_prefix: String) -> void:
	for i in range(EXPECTED_FAMILIES.size()):
		_assert(not main_shell.bullet_pool[start_idx + i].active, "%s should clear %s bullets." % [message_prefix, EXPECTED_FAMILIES[i]])
	_assert(not main_shell.bullet_pool[start_idx + EXPECTED_FAMILIES.size()].active, "%s should clear arrow bullets." % message_prefix)

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

func _verify_enemy_bullet_type_cache() -> void:
	var main_shell = _new_main_with_pool()
	var fake_db := CountingGameDatabase.new(37, EXPECTED_FAMILIES)
	main_shell.game_database_ref = fake_db
	main_shell.game_database = fake_db

	var type_ids: Array = main_shell._enemy_bullet_types()
	_assert_equal(fake_db.bullet_families_calls, 1, "Enemy bullet type cache should build from bullet_families once.")
	_assert(type_ids.has("arrow"), "Enemy bullet cache should include arrow.")
	for type_id in EXPECTED_FAMILIES:
		_assert(main_shell._is_enemy_bullet_type(type_id), "Cached enemy bullet lookup should recognize %s." % type_id)
	_assert(main_shell._is_enemy_bullet_type("arrow"), "Cached enemy bullet lookup should recognize arrow.")
	_assert(not main_shell._is_enemy_bullet_type("player"), "Cached enemy bullet lookup should reject player bullets.")
	_assert_equal(fake_db.bullet_families_calls, 1, "_is_enemy_bullet_type should not rebuild enemy bullet families after cache warmup.")
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

func _verify_clearing_paths_use_all_enemy_bullet_families() -> void:
	var boss_entry_shell = _new_main_with_pool()
	_activate_enemy_family_set(boss_entry_shell, 0, 180.0)
	_activate_bullet(boss_entry_shell, 12, "player", 400.0, 180.0, 6.0)
	boss_entry_shell._enter_boss()
	_assert_equal(boss_entry_shell.game_manager_ref.state, "boss", "Boss entry should switch main state to boss.")
	_assert_enemy_family_set_cleared(boss_entry_shell, 0, "Boss entry")
	_assert(boss_entry_shell.bullet_pool[12].active, "Boss entry should not clear player bullets.")
	_free_main(boss_entry_shell)

	var boss_card_clear_shell = _new_main_with_pool()
	_activate_enemy_family_set(boss_card_clear_shell, 0, 220.0)
	_activate_bullet(boss_card_clear_shell, 12, "bomb", 420.0, 220.0, 6.0)
	boss_card_clear_shell.boss = {"cards":[{"name":"test"}], "card_idx":0, "phase":"active", "timer":12.0}
	boss_card_clear_shell._boss_card_clear()
	_assert_enemy_family_set_cleared(boss_card_clear_shell, 0, "Boss card clear")
	_assert(boss_card_clear_shell.bullet_pool[12].active, "Boss card clear should not clear bomb bullets.")
	_assert_equal(String(boss_card_clear_shell.boss.phase), "defeated", "Last-card clear should move boss to defeated.")
	_free_main(boss_card_clear_shell)

	var boss_timeout_shell = _new_main_with_pool()
	_activate_enemy_family_set(boss_timeout_shell, 0, 260.0)
	_activate_bullet(boss_timeout_shell, 12, "player", 440.0, 260.0, 6.0)
	boss_timeout_shell.boss = {"cards":[{"name":"test"}], "card_idx":0, "phase":"active", "timer":6.0}
	boss_timeout_shell._boss_card_timeout()
	_assert_enemy_family_set_cleared(boss_timeout_shell, 0, "Boss timeout")
	_assert(boss_timeout_shell.bullet_pool[12].active, "Boss timeout should not clear player bullets.")
	_assert_equal(String(boss_timeout_shell.boss.phase), "defeated", "Last-card timeout should move boss to defeated.")
	_free_main(boss_timeout_shell)

	var bomb_clear_shell = _new_main_with_pool()
	bomb_clear_shell.player_x = 360.0
	bomb_clear_shell.player_y = 540.0
	bomb_clear_shell.player_bombing = true
	bomb_clear_shell.player_bomb_timer = 1.0
	bomb_clear_shell.player_bomb_wave_timer = 0.0
	bomb_clear_shell.player_bomb_phase = 0
	bomb_clear_shell.player_bomb_config = {"clear_radius": 200.0, "duration": 1, "waves": 1, "persist_waves": false, "color": Color.WHITE}
	for i in range(EXPECTED_FAMILIES.size()):
		_activate_bullet(bomb_clear_shell, i, EXPECTED_FAMILIES[i], 360.0 + float(i), 540.0, 8.0)
	_activate_bullet(bomb_clear_shell, EXPECTED_FAMILIES.size(), "arrow", 352.0, 540.0, 8.0)
	_activate_bullet(bomb_clear_shell, 12, "player", 360.0, 420.0, 6.0)
	bomb_clear_shell._update_bomb(1.0 / 60.0)
	_assert_enemy_family_set_cleared(bomb_clear_shell, 0, "Bomb clear")
	_assert(bomb_clear_shell.bullet_pool[12].active, "Bomb clear should not clear player bullets.")
	_free_main(bomb_clear_shell)

func _init() -> void:
	_verify_bullet_family_contract()
	if failed:
		return
	_verify_enemy_bullet_type_cache()
	if failed:
		return
	_verify_collision_uses_all_enemy_bullet_families()
	if failed:
		return
	_verify_clearing_paths_use_all_enemy_bullet_families()
	if failed:
		return
	quit(0)
