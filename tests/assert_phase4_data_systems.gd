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

func _ids(entries: Array) -> Array:
	var result: Array = []
	for entry in entries:
		result.append(String(entry.get("id", "")))
	return result

func _assert_keys(value: Dictionary, keys: Array, context: String) -> void:
	for key in keys:
		_assert(value.has(key), "%s missing %s: %s" % [context, key, value])

func _assert_drop_table(table: Array, tier: String) -> void:
	_assert(table.size() >= 4, "%s drop table should have at least 4 weighted entries." % tier)
	var total := 0.0
	var has_bomb_fragment := false
	var has_life_fragment := false
	var has_seal := false
	for entry in table:
		_assert_keys(entry, ["id", "weight"], "%s drop entry" % tier)
		total += float(entry.weight)
		if String(entry.id) == "bomb_fragment":
			has_bomb_fragment = true
		if String(entry.id) == "life_fragment":
			has_life_fragment = true
		if String(entry.id) == "night_festival_seal":
			has_seal = true
	_assert(abs(total - 1.0) <= 0.001, "%s drop table weights should sum to 1.0, got %f" % [tier, total])
	_assert(has_bomb_fragment, "%s drop table should include bomb_fragment." % tier)
	_assert(has_life_fragment, "%s drop table should include life_fragment." % tier)
	_assert(has_seal, "%s drop table should include night_festival_seal." % tier)

func _init() -> void:
	var db_script = load("res://scripts/data/game_database.gd")
	if not _assert(db_script != null, "Could not load game_database.gd"):
		return
	var db = db_script.new()

	for method in ["enemy_families", "enemy_family_by_id", "bullet_family_by_id", "item_type_by_id", "drop_table_for_tier", "scoring_rules"]:
		if not _assert(db.has_method(method), "GameDatabase missing method %s" % method):
			return

	var expected_enemy_ids := ["low_yokai", "fast_attacker", "formation_shooter", "elite_yokai", "mechanism"]
	_assert_equal(_ids(db.enemy_families()), expected_enemy_ids, "Enemy family ids mismatch.")
	for family in db.enemy_families():
		_assert_keys(family, ["id", "display_name", "role", "base_hp", "radius", "shoot_interval", "default_pattern", "bullet_family", "drop_tier", "density"], "enemy family %s" % String(family.get("id", "")))
		_assert(float(family.base_hp) > 0.0, "Enemy family base_hp should be positive.")
		_assert(float(family.radius) >= 10.0, "Enemy family radius should be readable.")
		_assert(float(family.shoot_interval) >= 24.0, "Enemy family shoot interval should be fair.")
		_assert(float(family.density) > 0.0 and float(family.density) <= 1.5, "Enemy density should stay bounded.")

	var expected_bullet_ids := ["circle", "rice", "butterfly", "needle", "talisman", "star", "laser", "large_orb"]
	_assert_equal(_ids(db.bullet_families()), expected_bullet_ids, "Enemy bullet family ids mismatch.")
	for family in db.bullet_families():
		_assert_keys(family, ["id", "display_name", "collision", "role", "radius", "speed_multiplier", "collision_radius", "color", "draw_group"], "bullet family %s" % String(family.get("id", "")))
		_assert(float(family.radius) >= float(family.collision_radius), "Bullet visual radius should be >= collision radius.")
		_assert(float(family.speed_multiplier) > 0.0, "Bullet speed multiplier should be positive.")
	_assert_equal(String(db.bullet_family_by_id("needle").collision), "thin", "Needle collision schema mismatch.")
	_assert_equal(db.bullet_family_by_id("missing"), {}, "Unknown bullet family should return empty Dictionary.")

	var expected_item_ids := ["power", "point", "bomb_fragment", "life_fragment", "night_festival_seal", "full_power"]
	_assert_equal(_ids(db.item_types()), expected_item_ids, "Item type ids mismatch.")
	for item in db.item_types():
		_assert_keys(item, ["id", "display_name", "role", "base_score", "collect_behavior"], "item %s" % String(item.get("id", "")))
		_assert(int(item.base_score) >= 0, "Item base_score should be non-negative.")
	_assert_equal(int(db.item_type_by_id("bomb_fragment").fragment_goal), 3, "Bomb fragment goal should be 3.")
	_assert_equal(int(db.item_type_by_id("life_fragment").fragment_goal), 5, "Life fragment goal should be 5.")
	var bomb_refill: Dictionary = db.item_type_by_id("bomb_refill")
	if _assert(not bomb_refill.is_empty(), "item_type_by_id should preserve legacy bomb_refill lookups."):
		_assert_keys(bomb_refill, ["id", "display_name", "role", "base_score", "collect_behavior"], "legacy item bomb_refill")
		_assert_equal(String(bomb_refill.id), "bomb_refill", "bomb_refill compatibility id mismatch.")
		_assert_equal(String(bomb_refill.collect_behavior), "bomb_refill", "bomb_refill compatibility collect_behavior mismatch.")
		_assert_equal(int(bomb_refill.base_score), 100, "bomb_refill compatibility base_score mismatch.")
	var life: Dictionary = db.item_type_by_id("life")
	if _assert(not life.is_empty(), "item_type_by_id should preserve legacy life lookups."):
		_assert_keys(life, ["id", "display_name", "role", "base_score", "collect_behavior"], "legacy item life")
		_assert_equal(String(life.id), "life", "life compatibility id mismatch.")
		_assert_equal(String(life.collect_behavior), "life", "life compatibility collect_behavior mismatch.")
		_assert_equal(int(life.base_score), 500, "life compatibility base_score mismatch.")
	_assert_equal(db.item_type_by_id("missing"), {}, "Unknown item type should return empty Dictionary.")

	_assert_drop_table(db.drop_table_for_tier("light"), "light")
	_assert_drop_table(db.drop_table_for_tier("standard"), "standard")
	_assert_drop_table(db.drop_table_for_tier("rich"), "rich")
	_assert_drop_table(db.drop_table_for_tier("mechanism"), "mechanism")

	var scoring: Dictionary = db.scoring_rules()
	_assert_keys(scoring, ["enemy_defeat", "graze", "point_base", "top_collection_multiplier", "night_festival_seal_base", "night_festival_seal_step", "spell_card_no_miss_bonus", "spell_card_no_bomb_bonus"], "scoring rules")
	_assert_equal(int(scoring.enemy_defeat), 50, "Enemy defeat score should preserve existing reward.")
	_assert_equal(int(scoring.graze), 10, "Graze score should preserve existing reward.")
	_assert(float(scoring.top_collection_multiplier) > 1.0, "Top collection should reward high collection.")
	_assert(int(scoring.night_festival_seal_base) >= 1000, "Night Festival Seal should be a high-value bonus.")

	quit(0)
