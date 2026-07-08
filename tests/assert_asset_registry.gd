extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _path_ok(path_value: String) -> bool:
	return path_value.begins_with("res://")

func _init() -> void:
	var registry_script = load("res://autoload/asset_registry.gd")
	if registry_script == null:
		_fail("Could not load asset_registry.gd")
	var registry = registry_script.new()
	var database_script = load("res://scripts/data/game_database.gd")
	if database_script == null:
		_fail("Could not load game_database.gd")
	var db = database_script.new()

	var shrine_layers: Dictionary = registry.stage_background_layers("shrine_approach")
	for key in ["far", "mid", "front", "atmosphere"]:
		if not shrine_layers.has(key):
			_fail("shrine_approach missing background layer %s" % key)
		if not _path_ok(String(shrine_layers[key])):
			_fail("Layer %s path must start with res://, got %s" % [key, shrine_layers[key]])

	var miko_assets: Dictionary = registry.protagonist_assets("miko")
	for key in ["portrait", "sprite", "shot_atlas", "bomb_atlas", "ending"]:
		if not miko_assets.has(key):
			_fail("miko assets missing %s" % key)
		if not _path_ok(String(miko_assets[key])):
			_fail("miko asset %s must start with res://, got %s" % [key, miko_assets[key]])

	var boss_assets: Dictionary = registry.boss_assets("hyakki_night_festival_god")
	for key in ["portrait", "sprite", "spell_background"]:
		if not boss_assets.has(key):
			_fail("final boss assets missing %s" % key)

	for protagonist in db.protagonists():
		var protagonist_assets: Dictionary = registry.protagonist_assets(String(protagonist.id))
		for key in ["portrait", "sprite", "shot_atlas", "bomb_atlas", "ending"]:
			if not protagonist_assets.has(key):
				_fail("%s assets missing %s" % [protagonist.id, key])
			if not _path_ok(String(protagonist_assets[key])):
				_fail("%s asset %s must start with res://, got %s" % [protagonist.id, key, protagonist_assets[key]])

	for stage in db.stages():
		var stage_layers: Dictionary = registry.stage_background_layers(String(stage.id))
		for key in ["far", "mid", "front", "atmosphere"]:
			if not stage_layers.has(key):
				_fail("%s missing background layer %s" % [stage.id, key])
			if not _path_ok(String(stage_layers[key])):
				_fail("%s layer %s must start with res://, got %s" % [stage.id, key, stage_layers[key]])
		for boss_id in [String(stage.midboss_id), String(stage.boss_id)]:
			var stage_boss_assets: Dictionary = registry.boss_assets(boss_id)
			for key in ["portrait", "sprite", "spell_background"]:
				if not stage_boss_assets.has(key):
					_fail("%s assets missing %s" % [boss_id, key])
				if not _path_ok(String(stage_boss_assets[key])):
					_fail("%s asset %s must start with res://, got %s" % [boss_id, key, stage_boss_assets[key]])

	if registry.audio_key("shrine_approach", "stage") != "stage1_mid":
		_fail("Expected shrine_approach stage audio key stage1_mid")
	if registry.audio_key("night_festival_divine_realm", "boss") != "stage6_boss":
		_fail("Expected final boss audio key stage6_boss")

	quit(0)
