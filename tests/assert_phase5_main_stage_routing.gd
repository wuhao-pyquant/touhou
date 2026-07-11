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

func _is_cjk_char(ch: String) -> bool:
	var codepoint := ord(ch)
	return (codepoint >= 0x3400 and codepoint <= 0x4DBF) or (codepoint >= 0x4E00 and codepoint <= 0x9FFF) or (codepoint >= 0xF900 and codepoint <= 0xFAFF)

func _assert_chinese_first(value: String, context: String) -> void:
	_assert(value.length() > 0, "%s should not be empty." % context)
	if value.length() > 0:
		_assert(_is_cjk_char(value[0]), "%s should be Chinese-first, got %s" % [context, value])

func _new_main() -> Node:
	var gm = load("res://autoload/game_manager.gd").new()
	var main_shell = load("res://scripts/main.gd").new()
	main_shell.game_manager_ref = gm
	main_shell.audio_manager_ref = null
	main_shell.items = []
	main_shell.enemies = []
	main_shell.bullet_pool = []
	for i in range(64):
		main_shell.bullet_pool.append(main_shell._make_bullet())
	return main_shell

func _free_main(main_shell: Node) -> void:
	var gm = main_shell.game_manager_ref
	main_shell.free()
	if gm:
		gm.free()

func _patterns(enemies: Array) -> Array:
	var result: Array = []
	for enemy in enemies:
		var pattern := String(enemy.get("pattern", ""))
		if pattern != "" and not result.has(pattern):
			result.append(pattern)
	return result

func _assert_stage_controller(main_shell: Node, stage_index: int) -> void:
	var gm = main_shell.game_manager_ref
	gm.current_stage = stage_index
	main_shell._load_stage(stage_index)
	var controller: Dictionary = main_shell.stage_controller
	for key in ["stage_index", "stage_id", "display_name", "curve_tag", "theme", "boss_time", "waves", "boss_spawned", "triggered_waves", "midboss", "boss"]:
		_assert(controller.has(key), "Stage %d controller missing %s: %s" % [stage_index, key, controller])
	_assert_equal(int(controller.stage_index), stage_index, "Loaded controller stage mismatch.")
	_assert(not controller.has("fallback_from"), "Stage %d should not use fallback_from after Phase 5." % stage_index)
	_assert((controller.waves as Array).size() >= 10, "Stage %d should load authored wave data." % stage_index)
	_assert_equal(bool(controller.boss_spawned), false, "Stage %d boss_spawned should reset false." % stage_index)

func _assert_invalid_stage_does_not_fallback(main_shell: Node, stage_index: int) -> void:
	main_shell._load_stage(stage_index)
	_assert_equal(main_shell.stage_controller, {}, "Invalid stage %d should not create a fallback controller." % stage_index)

func _assert_boss_cards(main_shell: Node, stage_index: int) -> void:
	var gm = main_shell.game_manager_ref
	gm.current_stage = stage_index
	main_shell._load_stage(stage_index)
	main_shell.boss = {}
	main_shell._load_boss_cards()
	var cards: Array = main_shell.boss.get("cards", [])
	var expected_count := 4 if stage_index <= 4 else 6
	_assert_equal(cards.size(), expected_count, "Stage %d main boss card count mismatch." % stage_index)
	var nonspells := 0
	var spells := 0
	for card in cards:
		for key in ["name", "hp", "time", "pattern", "kind", "stage_index", "boss_id", "base_hp"]:
			_assert(card.has(key), "Stage %d boss card missing %s: %s" % [stage_index, key, card])
		_assert_chinese_first(String(card.name), "stage %d boss card name" % stage_index)
		var expected_hp: float = gm.balanced_boss_card_hp(stage_index, float(card.time), String(card.kind))
		_assert(is_equal_approx(float(card.hp), expected_hp), "Stage %d card hp should use the Phase 8 time-to-clear curve." % stage_index)
		if String(card.kind) == "nonspell":
			nonspells += 1
		elif String(card.kind) == "spell":
			spells += 1
		else:
			_fail("Stage %d card has invalid kind: %s" % [stage_index, card])
	var expected_nonspells := 1 if stage_index <= 4 else 2
	var expected_spells := 3 if stage_index <= 4 else 4
	_assert_equal(nonspells, expected_nonspells, "Stage %d nonspell count mismatch." % stage_index)
	_assert_equal(spells, expected_spells, "Stage %d spell count mismatch." % stage_index)

func _assert_stage_wave_patterns(main_shell: Node, stage_index: int, event_time: int, expected_patterns: Array) -> void:
	var gm = main_shell.game_manager_ref
	gm.current_stage = stage_index
	main_shell._load_stage(stage_index)
	main_shell.enemies = []
	main_shell._stage_waves(event_time)
	var first_count: int = main_shell.enemies.size()
	_assert(first_count > 0, "Stage %d time %d should spawn enemies." % [stage_index, event_time])
	var patterns := _patterns(main_shell.enemies)
	for expected in expected_patterns:
		_assert(patterns.has(String(expected)), "Stage %d time %d should spawn pattern %s, got %s" % [stage_index, event_time, expected, patterns])
	main_shell._stage_waves(event_time)
	_assert_equal(main_shell.enemies.size(), first_count, "Stage %d time %d should not spawn duplicate wave events." % [stage_index, event_time])

func _assert_stage_wave_strong(main_shell: Node, stage_index: int, event_time: int, expected_pattern: String) -> void:
	var gm = main_shell.game_manager_ref
	gm.current_stage = stage_index
	main_shell._load_stage(stage_index)
	main_shell.enemies = []
	main_shell._stage_waves(event_time)
	var found := false
	var found_strong := false
	for enemy in main_shell.enemies:
		if String(enemy.get("pattern", "")) == expected_pattern:
			found = true
			if bool(enemy.get("strong", false)):
				found_strong = true
	_assert(found, "Stage %d time %d should spawn pattern %s." % [stage_index, event_time, expected_pattern])
	_assert(found_strong, "Stage %d time %d should include a strong %s wave." % [stage_index, event_time, expected_pattern])

func _init() -> void:
	var main_shell = _new_main()
	for method in ["_load_stage", "_stage_waves", "_spawn_stage_wave_event", "_load_boss_cards", "_resolve_boss_pattern_id"]:
		if not _assert(main_shell.has_method(method), "Main missing method %s" % method):
			_free_main(main_shell)
			return

	for stage_index in range(1, 7):
		_assert_stage_controller(main_shell, stage_index)
		_assert_boss_cards(main_shell, stage_index)
	_assert_invalid_stage_does_not_fallback(main_shell, 0)
	_assert_invalid_stage_does_not_fallback(main_shell, 7)

	_assert_stage_wave_patterns(main_shell, 4, 0, ["wind"])
	_assert_stage_wave_patterns(main_shell, 5, 0, ["rhythm"])
	_assert_stage_wave_patterns(main_shell, 5, 840, ["large_orb"])
	_assert_stage_wave_patterns(main_shell, 6, 0, ["final_dense"])
	_assert_stage_wave_strong(main_shell, 4, 1280, "wind_aimed")
	_assert_stage_wave_strong(main_shell, 5, 840, "large_orb")
	_assert_stage_wave_strong(main_shell, 6, 3000, "final_dense")

	_assert_equal(main_shell._resolve_boss_pattern_id("s4_wind_nonspell"), "wind_aimed", "Boss pattern alias should resolve wind nonspell.")
	_assert_equal(main_shell._resolve_boss_pattern_id("s5_large_orb_spell"), "large_orb_gate", "Boss pattern alias should resolve large orb spell.")
	_assert_equal(main_shell._resolve_boss_pattern_id("s6_final_lantern_spell"), "final_lantern", "Boss pattern alias should resolve final spell.")

	_free_main(main_shell)
	quit(0)
