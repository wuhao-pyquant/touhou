extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _init() -> void:
	var main_script = load("res://scripts/main.gd")
	if main_script == null:
		_fail("Could not load main.gd")
	var main = main_script.new()
	if not main.has_method("get_asset_texture"):
		_fail("main.gd must expose get_asset_texture")
		return

	var missing_path := "res://assets/__missing_phase6_runtime_probe.png"
	if main.get_asset_texture(missing_path) != null:
		_fail("Missing texture path should return null")
	var cache = main.get("asset_texture_cache")
	if typeof(cache) != TYPE_DICTIONARY:
		_fail("main.gd must expose asset_texture_cache Dictionary")
	if not cache.has(missing_path):
		_fail("Missing texture path should be cached")
	if cache[missing_path] != null:
		_fail("Missing texture cache entry should be null")

	var bullet_path := "res://assets/effects/bullets/enemy_bullet_lotus_core.png"
	var first_texture = main.get_asset_texture(bullet_path)
	if first_texture == null:
		_fail("Expected Phase 6 bullet texture to load")
	var second_texture = main.get_asset_texture(bullet_path)
	if first_texture != second_texture:
		_fail("Expected get_asset_texture to return cached texture instance")
	cache = main.get("asset_texture_cache")
	if not cache.has(bullet_path):
		_fail("Loaded texture path should be cached")
	if cache[bullet_path] != first_texture:
		_fail("Loaded texture cache entry should match returned texture")

	if main.get_asset_texture("") != null:
		_fail("Empty texture path should return null")

	main.asset_texture_cache.clear()
	main.free()
	quit(0)
