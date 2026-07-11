extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _has_cjk(value: String) -> bool:
	for i in range(value.length()):
		var codepoint := ord(value[i])
		if (codepoint >= 0x3400 and codepoint <= 0x4DBF) or (codepoint >= 0x4E00 and codepoint <= 0x9FFF) or (codepoint >= 0xF900 and codepoint <= 0xFAFF):
			return true
	return false

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _init() -> void:
	var db_script = load("res://scripts/data/game_database.gd")
	if db_script == null:
		_fail("Could not load game_database.gd")
	var db = db_script.new()

	var protagonists: Array = db.protagonists()
	if protagonists.size() != 3:
		_fail("Expected 3 protagonists, got %d" % protagonists.size())
	for p in protagonists:
		if not p.has("id") or not p.has("display_name") or not p.has("shot_types") or not p.has("bomb"):
			_fail("Protagonist entry missing required keys: %s" % [p])
		_assert(_has_cjk(String(p.display_name)), "Protagonist display_name should contain Chinese text: %s" % [p.display_name])
		if p.shot_types.size() != 2:
			_fail("Protagonist %s must have exactly 2 shot types" % p.id)
		for shot in p.shot_types:
			_assert(_has_cjk(String(shot.display_name)), "Protagonist %s shot display_name should contain Chinese text: %s" % [p.id, shot.display_name])
		_assert(_has_cjk(String(p.bomb.display_name)), "Protagonist %s bomb display_name should contain Chinese text: %s" % [p.id, p.bomb.display_name])

	var stages: Array = db.stages()
	if stages.size() != 6:
		_fail("Expected 6 stages, got %d" % stages.size())
	for i in range(stages.size()):
		var s: Dictionary = stages[i]
		if int(s.index) != i + 1:
			_fail("Stage index mismatch at entry %d: %s" % [i, s])
		for key in ["id", "display_name", "midboss_id", "boss_id", "theme"]:
			if not s.has(key):
				_fail("Stage %d missing %s" % [i + 1, key])
		_assert(_has_cjk(String(s.display_name)), "Stage display_name should contain Chinese text: %s" % [s.display_name])

	var bullet_families: Array = db.bullet_families()
	if bullet_families.size() != 12:
		_fail("Expected 12 enemy bullet families, got %d" % bullet_families.size())
	for f in bullet_families:
		_assert(_has_cjk(String(f.display_name)), "Bullet family display_name should contain Chinese text: %s" % [f.display_name])

	var item_types: Array = db.item_types()
	if item_types.size() != 6:
		_fail("Expected 6 item types, got %d" % item_types.size())
	for item in item_types:
		_assert(_has_cjk(String(item.display_name)), "Item display_name should contain Chinese text: %s" % [item.display_name])
		if String(item.id) == "bomb_fragment":
			_assert(String(item.display_name) == "炸弹碎片", "bomb_fragment display_name should be 炸弹碎片, got %s" % [item.display_name])

	quit(0)
