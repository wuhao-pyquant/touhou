extends SceneTree

func _init() -> void:
	var registry := preload("res://autoload/asset_registry.gd").new()
	assert(registry.has_method("stage_background_layers"))
	assert(registry.has_method("protagonist_assets"))
	assert(registry.has_method("boss_assets"))
	assert(registry.has_method("enemy_family_assets"))
	assert(registry.has_method("bullet_family_assets"))
	assert(registry.has_method("bomb_assets"))
	assert(registry.has_method("item_assets"))
	assert(registry.has_method("ui_assets"))

	var stage_layers: Dictionary = registry.stage_background_layers(1)
	assert(stage_layers.has("far"))
	assert(stage_layers.has("mid"))
	assert(stage_layers.has("near"))
	assert(stage_layers.has("spell"))
	assert(str(stage_layers["far"]).ends_with("assets/backgrounds/stage_01/far.png"))

	var bullets: Dictionary = registry.bullet_family_assets()
	assert(bullets.has("enemy_bullet_lotus_core"))
	assert(bullets.has("player_bullet_focus_lance"))
	quit(0)
