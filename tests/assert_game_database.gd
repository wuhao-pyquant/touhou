extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

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
		if p.shot_types.size() != 2:
			_fail("Protagonist %s must have exactly 2 shot types" % p.id)

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

	var bullet_families: Array = db.bullet_families()
	if bullet_families.size() != 8:
		_fail("Expected 8 enemy bullet families, got %d" % bullet_families.size())

	var item_types: Array = db.item_types()
	if item_types.size() != 6:
		_fail("Expected 6 item types, got %d" % item_types.size())

	quit(0)
