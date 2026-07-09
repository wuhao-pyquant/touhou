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

func _assert_dict_value(dict_value: Dictionary, key: String, expected, message: String) -> bool:
	if not _assert(dict_value.has(key), "%s Missing key %s." % [message, key]):
		return false
	return _assert_equal(dict_value[key], expected, message)

func _verify_reward_system() -> void:
	var reward_script = load("res://scripts/runtime/item_reward_system.gd")
	if not _assert(reward_script != null, "Could not load item_reward_system.gd"):
		return
	var rewards = reward_script.new()
	for method in ["choose_drop", "apply_collection"]:
		if not _assert(rewards.has_method(method), "ItemRewardSystem missing method %s" % method):
			return

	_assert_equal(rewards.choose_drop("light", 0.01), "power", "light low roll mismatch.")
	_assert_equal(rewards.choose_drop("light", 0.60), "bomb_fragment", "light bomb fragment roll mismatch.")
	_assert_equal(rewards.choose_drop("light", 0.75), "life_fragment", "light life fragment boundary mismatch.")
	_assert_equal(rewards.choose_drop("light", 0.80), "night_festival_seal", "light seal boundary mismatch.")
	_assert_equal(rewards.choose_drop("light", 0.95), "full_power", "light full power boundary mismatch.")
	_assert_equal(rewards.choose_drop("rich", 0.05), "point", "rich low roll mismatch.")
	_assert_equal(rewards.choose_drop("rich", 0.30), "bomb_refill", "rich bomb refill roll mismatch.")

	var gm = load("res://autoload/game_manager.gd").new()
	_assert(gm.has_method("reset"), "GameManager should have reset.")
	_assert(gm.get("night_festival_seals") != null, "GameManager should expose night_festival_seals.")
	gm.score = 0
	gm.shared_power = 10
	var point_result: Dictionary = rewards.apply_collection("point", gm, 64.0, 128.0)
	_assert_equal(String(point_result.type), "point", "Point result type mismatch.")
	_assert_equal(int(gm.score), 220, "Top-collected point item should use power scaling and top multiplier.")

	gm.bombs = 0
	gm.bomb_fragments = 2
	rewards.apply_collection("bomb_fragment", gm, 400.0, 128.0)
	_assert_equal(gm.bombs, 1, "Third bomb fragment should grant one bomb.")
	_assert_equal(gm.bomb_fragments, 0, "Third bomb fragment should consume fragments.")

	gm.bombs = 4
	var bomb_refill_result: Dictionary = rewards.apply_collection("bomb_refill", gm, 400.0, 128.0)
	_assert_equal(gm.bombs, 5, "Bomb refill should grant one bomb up to cap.")
	_assert_equal(int(bomb_refill_result.score_delta), 100, "Bomb refill score mismatch.")
	_assert_dict_value(bomb_refill_result.resource_delta, "bombs", 1, "Bomb refill delta mismatch.")
	var bomb_cap_result: Dictionary = rewards.apply_collection("bomb_refill", gm, 400.0, 128.0)
	_assert_equal(gm.bombs, 5, "Bomb refill should respect bomb cap.")
	_assert_dict_value(bomb_cap_result.resource_delta, "bombs", 0, "Bomb refill cap delta mismatch.")

	gm.lives = 3
	gm.life_fragments = 4
	rewards.apply_collection("life_fragment", gm, 400.0, 128.0)
	_assert_equal(gm.lives, 4, "Fifth life fragment should grant one life.")
	_assert_equal(gm.life_fragments, 0, "Fifth life fragment should consume fragments.")

	gm.lives = 5
	var life_result: Dictionary = rewards.apply_collection("life", gm, 400.0, 128.0)
	_assert_equal(gm.lives, 6, "Life should grant one stock up to cap.")
	_assert_equal(int(life_result.score_delta), 500, "Life score mismatch.")
	_assert_dict_value(life_result.resource_delta, "lives", 1, "Life delta mismatch.")
	var life_cap_result: Dictionary = rewards.apply_collection("life", gm, 400.0, 128.0)
	_assert_equal(gm.lives, 6, "Life should respect life cap.")
	_assert_dict_value(life_cap_result.resource_delta, "lives", 0, "Life cap delta mismatch.")

	gm.shared_power = 49
	var legacy_bullet_result: Dictionary = rewards.apply_collection("bullet_linear", gm, 400.0, 128.0)
	_assert_equal(gm.shared_power, 50, "Legacy bullet item should add power and clamp to cap.")
	_assert_equal(int(legacy_bullet_result.score_delta), 120, "Legacy bullet item score mismatch.")
	_assert_dict_value(legacy_bullet_result.resource_delta, "shared_power", 1, "Legacy bullet item power delta mismatch.")

	gm.score = 0
	gm.night_festival_seals = 0
	rewards.apply_collection("night_festival_seal", gm, 420.0, 128.0)
	_assert_equal(gm.night_festival_seals, 1, "Night Festival Seal should increment seal counter.")
	_assert(int(gm.score) >= 1000, "Night Festival Seal should grant a high score bonus.")

	gm.shared_power = 12
	var full_power_result: Dictionary = rewards.apply_collection("full_power", gm, 420.0, 128.0)
	_assert_equal(gm.shared_power, 50, "Full power should refill power to max.")
	_assert_equal(int(full_power_result.score_delta), 300, "Full power score mismatch.")
	_assert_dict_value(full_power_result.resource_delta, "shared_power", 38, "Full power delta mismatch.")
	gm.reset()
	_assert_equal(gm.night_festival_seals, 0, "GameManager reset should clear Night Festival Seals.")
	gm.free()

func _verify_main_item_contract() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_assert(main_source.contains('"Seals: %d" % gm.night_festival_seals'), "Gameplay HUD should show Night Festival Seal count.")

	var gm = load("res://autoload/game_manager.gd").new()
	var main_script = load("res://scripts/main.gd")
	if not _assert(main_script != null, "Could not load main.gd"):
		gm.free()
		return
	var main_shell = main_script.new()
	main_shell.game_manager_ref = gm
	for method in ["_drop_item", "_drop_item_type", "_collect_item"]:
		if not _assert(main_shell.has_method(method), "Main missing method %s" % method):
			main_shell.free()
			gm.free()
			return
	_assert_equal(main_shell._drop_item_type(false, 0.80, "light"), "night_festival_seal", "Main drop helper should use database light table.")
	_assert_equal(main_shell._drop_item_type(true, 0.30, "rich"), "bomb_refill", "Main drop helper should use rich table.")
	main_shell.items.clear()
	main_shell._drop_item(10.0, 20.0, false, "light", 0.80)
	_assert_equal(main_shell.items.size(), 1, "Main drop helper should append one item.")
	_assert_equal(String(main_shell.items[0].type), "night_festival_seal", "Main drop item should respect explicit tier and roll.")
	main_shell._collect_item({"alive": true, "collected": false, "type": "night_festival_seal", "x": 0.0, "y": 420.0})
	_assert_equal(gm.night_festival_seals, 1, "Main collection should apply Night Festival Seal reward.")
	main_shell.free()
	gm.free()

func _init() -> void:
	_verify_reward_system()
	if failed:
		return
	_verify_main_item_contract()
	if failed:
		return
	quit(0)
