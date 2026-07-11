extends SceneTree

var failed := false

class FakeItemRewardDatabase:
	extends RefCounted

	var _items := {
		"bomb_fragment": {"id": "bomb_fragment", "base_score": 777, "fragment_goal": 2, "collect_behavior": "bomb_fragment"},
		"point": {"id": "point", "base_score": 10, "collect_behavior": "point"},
		"power": {"id": "power", "base_score": 10, "collect_behavior": "power"},
		"bomb_refill": {"id": "bomb_refill", "base_score": 100, "collect_behavior": "bomb_refill"},
		"life": {"id": "life", "base_score": 500, "collect_behavior": "life"},
		"life_fragment": {"id": "life_fragment", "base_score": 500, "fragment_goal": 5, "collect_behavior": "life_fragment"},
		"night_festival_seal": {"id": "night_festival_seal", "base_score": 1000, "collect_behavior": "night_festival_seal"},
		"full_power": {"id": "full_power", "base_score": 300, "collect_behavior": "full_power"},
		"bullet_linear": {"id": "bullet_linear", "base_score": 120, "collect_behavior": "bullet_linear"},
		"bullet_spread": {"id": "bullet_spread", "base_score": 120, "collect_behavior": "bullet_spread"},
		"bullet_homing": {"id": "bullet_homing", "base_score": 120, "collect_behavior": "bullet_homing"},
	}

	func drop_table_for_tier(tier: String) -> Array:
		var db = load("res://scripts/data/game_database.gd").new()
		return db.drop_table_for_tier(tier)

	func scoring_rules() -> Dictionary:
		var db = load("res://scripts/data/game_database.gd").new()
		return db.scoring_rules()

	func item_type_by_id(id: String) -> Dictionary:
		return _items.get(id, {})

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
	_assert_equal(rewards.choose_drop("light", 0.60), "point", "light point roll mismatch.")
	_assert_equal(rewards.choose_drop("light", 0.80), "bomb_fragment", "light bomb fragment roll mismatch.")
	_assert_equal(rewards.choose_drop("light", 0.88), "life_fragment", "light life fragment boundary mismatch.")
	_assert_equal(rewards.choose_drop("light", 0.95), "night_festival_seal", "light seal boundary mismatch.")
	_assert_equal(rewards.choose_drop("light", 0.995), "full_power", "light full power boundary mismatch.")
	_assert_equal(rewards.choose_drop("rich", 0.05), "point", "rich low roll mismatch.")
	_assert_equal(rewards.choose_drop("rich", 0.315), "bomb_refill", "rich bomb refill roll mismatch.")

	var gm = load("res://autoload/game_manager.gd").new()
	_assert(gm.has_method("reset"), "GameManager should have reset.")
	_assert(gm.get("night_festival_seals") != null, "GameManager should expose night_festival_seals.")
	gm.score = 0
	gm.shared_power = 10
	var point_result: Dictionary = rewards.apply_collection("point", gm, 64.0, 128.0)
	_assert_equal(String(point_result.type), "point", "Point result type mismatch.")
	_assert_equal(int(gm.score), 220, "Top-collected point item should use power scaling and top multiplier.")

	var fake_database := FakeItemRewardDatabase.new()
	rewards._database = fake_database
	gm.bombs = 0
	gm.bomb_fragments = 1
	var custom_bomb_fragment_result: Dictionary = rewards.apply_collection("bomb_fragment", gm, 400.0, 128.0)
	_assert_equal(gm.bombs, 1, "Custom fragment goal should grant one bomb once reached.")
	_assert_equal(gm.bomb_fragments, 0, "Custom fragment goal should consume fragments once reached.")
	_assert_equal(int(custom_bomb_fragment_result.score_delta), 777, "Bomb fragment should use database base_score when provided.")
	fake_database._items["point"]["base_score"] = 0
	gm.score = 0
	gm.shared_power = 10
	var zero_base_point_result: Dictionary = rewards.apply_collection("point", gm, 400.0, 128.0)
	_assert_equal(int(zero_base_point_result.score_delta), 0, "Point item should honor a present zero base_score from data.")
	_assert_equal(int(gm.score), 0, "Point item with zero base_score should not fall back to default scoring.")

	rewards._database = load("res://scripts/data/game_database.gd").new()

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
	_assert(main_source.contains('"%s  |  夜祭印 %d" % [gm.STAGE_NAMES[gm.current_stage - 1], gm.night_festival_seals]'), "Gameplay HUD should show Night Festival Seal count.")

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
	_assert_equal(main_shell._drop_item_type(false, 0.95, "light"), "night_festival_seal", "Main drop helper should use database light table.")
	_assert_equal(main_shell._drop_item_type(true, 0.315, "rich"), "bomb_refill", "Main drop helper should use rich table.")
	main_shell.items.clear()
	main_shell._drop_item(10.0, 20.0, false, "light", 0.95)
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
