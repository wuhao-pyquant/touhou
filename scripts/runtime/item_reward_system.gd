extends RefCounted
class_name ItemRewardSystem

var _database = load("res://scripts/data/game_database.gd").new()

func choose_drop(tier: String, roll: float) -> String:
	var table: Array = _database.drop_table_for_tier(tier)
	var threshold := clampf(roll, 0.0, 0.999999)
	var running := 0.0
	for entry in table:
		running += float(entry.get("weight", 0.0))
		if threshold < running:
			return String(entry.get("id", "power"))
	return "power"

func apply_collection(item_type: String, game_manager_ref: Object, collection_y: float, top_collection_y: float) -> Dictionary:
	var rules: Dictionary = _database.scoring_rules()
	var item_data: Dictionary = _database.item_type_by_id(item_type) if _database and _database.has_method("item_type_by_id") else {}
	var behavior: String = String(item_data.get("collect_behavior", item_type))
	var has_base_score := item_data.has("base_score")
	var base_score: int = int(item_data.get("base_score", 0))
	var score_delta := 0
	var resource_delta := {}
	match behavior:
		"bullet_spread", "bullet_linear", "bullet_homing":
			var before_power: int = int(game_manager_ref.shared_power)
			game_manager_ref.add_power(2)
			score_delta = base_score if has_base_score else 120
			resource_delta["shared_power"] = int(game_manager_ref.shared_power) - before_power
		"power":
			var before_power: int = int(game_manager_ref.shared_power)
			game_manager_ref.add_power(1)
			score_delta = base_score if has_base_score else 10
			resource_delta["shared_power"] = int(game_manager_ref.shared_power) - before_power
		"point":
			var point_base: int = base_score if has_base_score else int(rules.get("point_base", 10))
			score_delta = point_base * (1 + int(game_manager_ref.shared_power))
			if collection_y <= top_collection_y:
				score_delta = int(score_delta * float(rules.get("top_collection_multiplier", 2.0)))
		"bomb_refill":
			var before_bombs: int = int(game_manager_ref.bombs)
			game_manager_ref.bombs = min(before_bombs + 1, 5)
			score_delta = base_score if has_base_score else 100
			resource_delta["bombs"] = int(game_manager_ref.bombs) - before_bombs
		"bomb_fragment":
			var before_bombs: int = int(game_manager_ref.bombs)
			var before_fragments: int = int(game_manager_ref.bomb_fragments)
			game_manager_ref.bomb_fragments += 1
			var fragment_goal: int = int(item_data.get("fragment_goal", 3))
			if game_manager_ref.bomb_fragments >= fragment_goal:
				game_manager_ref.bombs = min(int(game_manager_ref.bombs) + 1, 5)
				game_manager_ref.bomb_fragments -= fragment_goal
			score_delta = base_score if has_base_score else 100
			resource_delta["bombs"] = int(game_manager_ref.bombs) - before_bombs
			resource_delta["bomb_fragments"] = int(game_manager_ref.bomb_fragments) - before_fragments
		"life":
			var before_lives: int = int(game_manager_ref.lives)
			game_manager_ref.lives = min(before_lives + 1, 6)
			score_delta = base_score if has_base_score else 500
			resource_delta["lives"] = int(game_manager_ref.lives) - before_lives
		"life_fragment":
			var before_lives: int = int(game_manager_ref.lives)
			var before_fragments: int = int(game_manager_ref.life_fragments)
			game_manager_ref.life_fragments += 1
			var fragment_goal: int = int(item_data.get("fragment_goal", 5))
			if game_manager_ref.life_fragments >= fragment_goal:
				game_manager_ref.lives = min(int(game_manager_ref.lives) + 1, 6)
				game_manager_ref.life_fragments -= fragment_goal
			score_delta = base_score if has_base_score else 500
			resource_delta["lives"] = int(game_manager_ref.lives) - before_lives
			resource_delta["life_fragments"] = int(game_manager_ref.life_fragments) - before_fragments
		"night_festival_seal":
			var multiplier: float = float(game_manager_ref.add_night_festival_seal()) if game_manager_ref.has_method("add_night_festival_seal") else 1.0
			var seal_base: int = base_score if has_base_score else int(rules.get("night_festival_seal_base", 1000))
			score_delta = int(seal_base * multiplier)
			resource_delta["night_festival_seals"] = 1
		"full_power":
			var before_power: int = int(game_manager_ref.shared_power)
			game_manager_ref.shared_power = 50
			score_delta = base_score if has_base_score else 300
			resource_delta["shared_power"] = int(game_manager_ref.shared_power) - before_power
		_:
			return {"type": item_type, "score_delta": 0, "resource_delta": {}}
	game_manager_ref.score += score_delta
	return {"type": item_type, "score_delta": score_delta, "resource_delta": resource_delta}
