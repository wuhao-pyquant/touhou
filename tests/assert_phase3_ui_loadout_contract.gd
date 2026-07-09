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

func _verify_ui_detail_contract() -> void:
	var ui = load("res://scripts/ui/ui_model.gd").new()
	for entry in ui.protagonist_entries():
		_assert(entry.has("detail_lines"), "Protagonist entry missing detail_lines: %s" % [entry])
		var joined := " ".join(entry.detail_lines)
		_assert(joined.find("Speed") >= 0, "Protagonist detail should include speed: %s" % joined)
		_assert(joined.find("Bomb") >= 0, "Protagonist detail should include bomb: %s" % joined)
	for shot in ui.shot_entries("magician"):
		_assert(shot.has("detail_lines"), "Shot entry missing detail_lines: %s" % [shot])
		var joined := " ".join(shot.detail_lines)
		_assert(joined.find("Coverage") >= 0, "Shot detail should include coverage: %s" % joined)
		_assert(joined.find("Focused damage") >= 0, "Shot detail should include focused damage: %s" % joined)

func _verify_main_fixed_loadout_contract() -> void:
	var gm = load("res://autoload/game_manager.gd").new()
	var main_script = load("res://scripts/main.gd")
	if not _assert(main_script != null, "Could not load main.gd"):
		gm.free()
		return
	var main_shell = main_script.new()
	main_shell.game_manager_ref = gm
	for method in ["_gameplay_shot_label", "_gameplay_protagonist_label", "_gameplay_bomb_label"]:
		if not _assert(main_shell.has_method(method), "Main missing HUD helper %s" % method):
			main_shell.free()
			gm.free()
			return
	gm.selected_protagonist_id = "swordswoman"
	gm.selected_shot_id = "returning_spirit_blades"
	gm.apply_selected_shot()
	_assert(main_shell._gameplay_protagonist_label().length() > 0, "HUD protagonist label should not be empty.")
	_assert(main_shell._gameplay_shot_label().find("Spirit") >= 0 or main_shell._gameplay_shot_label().find("Blade") >= 0, "HUD shot label should use selected shot hud_name.")
	_assert(main_shell._gameplay_bomb_label().find("Slash") >= 0 or main_shell._gameplay_bomb_label().find("Boundary") >= 0, "HUD bomb label should use selected bomb hud_name.")
	var original_bullet_type: int = gm.bullet_type
	var legacy_item := {"alive": true, "collected": false, "type": "bullet_linear", "x": 0.0, "y": 0.0}
	main_shell._collect_item(legacy_item)
	_assert_equal(gm.bullet_type, original_bullet_type, "Legacy bullet-switch item should not change fixed selected shot.")
	_assert_equal(gm.selected_shot_id, "returning_spirit_blades", "Legacy bullet-switch item should not change selected_shot_id.")
	main_shell.items = []
	for i in range(80):
		main_shell._drop_item(200.0, 120.0, i % 5 == 0)
	for item in main_shell.items:
		var item_type := String(item.get("type", ""))
		_assert(not item_type.begins_with("bullet_"), "Phase 3 drops should not include weapon-switch item %s" % item_type)
	main_shell.free()
	gm.free()

func _init() -> void:
	_verify_ui_detail_contract()
	if failed:
		return
	_verify_main_fixed_loadout_contract()
	if failed:
		return
	quit(0)
