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
	for method in ["_gameplay_shot_label", "_gameplay_protagonist_label", "_gameplay_bomb_label", "_gameplay_loadout_hud_rect", "_performance_hud_rect"]:
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
	var loadout_rect: Rect2 = main_shell._gameplay_loadout_hud_rect()
	var performance_rect: Rect2 = main_shell._performance_hud_rect()
	_assert(not loadout_rect.intersects(performance_rect), "Loadout HUD line should not overlap performance HUD box. loadout=%s performance=%s" % [loadout_rect, performance_rect])
	var original_bullet_type: int = gm.bullet_type
	var legacy_item := {"alive": true, "collected": false, "type": "bullet_linear", "x": 0.0, "y": 0.0}
	main_shell._collect_item(legacy_item)
	_assert_equal(gm.bullet_type, original_bullet_type, "Legacy bullet-switch item should not change fixed selected shot.")
	_assert_equal(gm.selected_shot_id, "returning_spirit_blades", "Legacy bullet-switch item should not change selected_shot_id.")
	gm.lives = 3
	gm.bombs = 1
	gm.life_fragments = 0
	gm.bomb_fragments = 0
	var life_fragment := {"alive": true, "collected": false, "type": "life_fragment", "x": 0.0, "y": 0.0}
	main_shell._collect_item(life_fragment)
	_assert_equal(gm.lives, 3, "One life_fragment should not grant a full life.")
	_assert_equal(gm.life_fragments, 1, "One life_fragment should be tracked as one fragment.")
	for i in range(4):
		main_shell._collect_item({"alive": true, "collected": false, "type": "life_fragment", "x": 0.0, "y": 0.0})
	_assert_equal(gm.lives, 4, "Five life_fragments should grant one life.")
	_assert_equal(gm.life_fragments, 0, "Five life_fragments should consume the fragment counter.")
	var bomb_fragment := {"alive": true, "collected": false, "type": "bomb_fragment", "x": 0.0, "y": 0.0}
	main_shell._collect_item(bomb_fragment)
	_assert_equal(gm.bombs, 1, "One bomb_fragment should not grant a full bomb.")
	_assert_equal(gm.bomb_fragments, 1, "One bomb_fragment should be tracked as one fragment.")
	for i in range(2):
		main_shell._collect_item({"alive": true, "collected": false, "type": "bomb_fragment", "x": 0.0, "y": 0.0})
	_assert_equal(gm.bombs, 2, "Three bomb_fragments should grant one bomb.")
	_assert_equal(gm.bomb_fragments, 0, "Three bomb_fragments should consume the fragment counter.")
	main_shell.items = []
	seed(12345)
	for i in range(80):
		main_shell._drop_item(200.0, 120.0, i % 5 == 0)
	var saw_bomb_fragment := false
	for item in main_shell.items:
		var item_type := String(item.get("type", ""))
		_assert(not item_type.begins_with("bullet_"), "Phase 3 drops should not include weapon-switch item %s" % item_type)
		if item_type == "bomb_fragment":
			saw_bomb_fragment = true
	_assert(saw_bomb_fragment, "Phase 3 drops should include bomb_fragment so three-fragment bomb economy is reachable.")
	main_shell.items = []
	gm.lives = 3
	gm.bombs = 1
	gm.shared_power = 500
	main_shell.player_x = 360.0
	main_shell.player_y = 540.0
	main_shell._respawn()
	_assert(main_shell.items.size() > 0, "Respawn should create power-loss drops when shared_power is high enough.")
	for item in main_shell.items:
		var item_type := String(item.get("type", ""))
		_assert(not item_type.begins_with("bullet_"), "Respawn drops should not include weapon-switch item %s" % item_type)
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
