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

func _assert_has_keys(value: Dictionary, keys: Array, context: String) -> void:
	for key in keys:
		_assert(value.has(key), "%s missing %s: %s" % [context, key, value])

func _ids(entries: Array) -> Array:
	var result: Array = []
	for entry in entries:
		result.append(String(entry.get("id", "")))
	return result

func _verify_database_profiles() -> void:
	var db_script = load("res://scripts/data/game_database.gd")
	if not _assert(db_script != null, "Could not load game_database.gd"):
		return
	var db = db_script.new()
	var protagonists: Array = db.protagonists()
	_assert_equal(_ids(protagonists), ["miko", "magician", "swordswoman"], "Protagonist ids mismatch.")
	var expected_shots := {
		"miko": ["ofuda_trace", "yin_yang_focus"],
		"magician": ["stardust_spread", "magic_laser"],
		"swordswoman": ["sword_wave_fan", "returning_spirit_blades"],
	}
	var expected_bombs := {
		"miko": "great_boundary_bloom",
		"magician": "festival_master_spark",
		"swordswoman": "instant_slash_boundary",
	}
	var seen_shots: Dictionary = {}
	for protagonist in protagonists:
		var pid := String(protagonist.id)
		_assert_has_keys(protagonist, ["id", "display_name", "role", "speed_high", "speed_low", "hitbox", "graze_radius", "difficulty_hint", "shot_types", "bomb"], "protagonist %s" % pid)
		_assert(float(protagonist.speed_high) > float(protagonist.speed_low), "%s high speed should exceed low speed" % pid)
		_assert(float(protagonist.hitbox) > 0.0, "%s hitbox should be positive" % pid)
		_assert(float(protagonist.graze_radius) > float(protagonist.hitbox), "%s graze should exceed hitbox" % pid)
		_assert_equal(_ids(protagonist.shot_types), expected_shots[pid], "%s shot ids mismatch." % pid)
		for shot in protagonist.shot_types:
			var sid := String(shot.id)
			seen_shots[sid] = true
			_assert_has_keys(shot, ["id", "display_name", "hud_name", "type_label", "style", "pattern_id", "bullet_type", "fire_interval_frames", "base_damage", "bullet_speed", "coverage", "focused_damage", "difficulty_hint", "color"], "shot %s" % sid)
			_assert(int(shot.fire_interval_frames) >= 2, "%s fire interval should be at least 2 frames" % sid)
			_assert(float(shot.base_damage) > 0.0, "%s base damage should be positive" % sid)
			_assert(float(shot.bullet_speed) > 0.0, "%s bullet speed should be positive" % sid)
		_assert_has_keys(protagonist.bomb, ["id", "display_name", "hud_name", "behavior_id", "duration_frames", "waves", "clear_radius", "damage", "bullet_count", "speed", "color", "description"], "bomb for %s" % pid)
		_assert_equal(String(protagonist.bomb.id), expected_bombs[pid], "%s bomb id mismatch." % pid)
		_assert(int(protagonist.bomb.duration_frames) > 0, "%s bomb duration should be positive" % pid)
		_assert(int(protagonist.bomb.waves) > 0, "%s bomb waves should be positive" % pid)
		_assert(float(protagonist.bomb.clear_radius) > 0.0, "%s bomb clear radius should be positive" % pid)
	for shot_id in ["ofuda_trace", "yin_yang_focus", "stardust_spread", "magic_laser", "sword_wave_fan", "returning_spirit_blades"]:
		_assert(seen_shots.has(shot_id), "Expected shot id %s in protagonist data" % shot_id)
		_assert_equal(String(db.shot_profile_by_id(shot_id).id), shot_id, "shot_profile_by_id should find %s." % shot_id)
	_assert_equal(db.shot_profile_by_id("missing"), {}, "Unknown shot id should return empty Dictionary.")
	_assert_equal(String(db.bomb_profile_for_protagonist("magician").id), "festival_master_spark", "Magician bomb lookup mismatch.")
	_assert_equal(db.bomb_profile_for_protagonist("missing"), {}, "Unknown protagonist bomb should return empty Dictionary.")

func _verify_game_manager_helpers() -> void:
	var gm_script = load("res://autoload/game_manager.gd")
	if not _assert(gm_script != null, "Could not load game_manager.gd"):
		return
	var gm = gm_script.new()
	for method in ["protagonist_profile", "selected_shot_profile", "selected_bomb_profile", "selected_speed_high", "selected_speed_low", "selected_hitbox_radius", "selected_graze_radius", "selected_fire_interval_frames", "apply_selected_shot"]:
		if not _assert(gm.has_method(method), "GameManager missing method %s" % method):
			gm.free()
			return
	gm.selected_protagonist_id = "magician"
	gm.selected_shot_id = "magic_laser"
	gm.apply_selected_shot()
	_assert_equal(String(gm.protagonist_profile().id), "magician", "Selected protagonist profile mismatch.")
	_assert_equal(String(gm.selected_shot_profile().id), "magic_laser", "Selected shot profile mismatch.")
	_assert_equal(String(gm.selected_bomb_profile().id), "festival_master_spark", "Selected bomb profile mismatch.")
	_assert(gm.selected_speed_high() > gm.selected_speed_low(), "Selected high speed should exceed low speed.")
	_assert(gm.selected_fire_interval_frames() >= 2, "Selected fire interval should be usable.")
	_assert_equal(gm.bullet_type, gm.BulletType.LINEAR, "apply_selected_shot should sync legacy bullet_type for HUD/backward compatibility.")
	gm.free()

func _verify_main_radius_helpers_use_selected_profile() -> void:
	var gm = load("res://autoload/game_manager.gd").new()
	var main_script = load("res://scripts/main.gd")
	if not _assert(main_script != null, "Could not load main.gd"):
		gm.free()
		return
	var main_shell = main_script.new()
	main_shell.game_manager_ref = gm
	for method in ["_player_hitbox_radius", "_player_graze_radius"]:
		if not _assert(main_shell.has_method(method), "Main missing selected-radius helper %s" % method):
			main_shell.free()
			gm.free()
			return
	gm.selected_protagonist_id = "swordswoman"
	var profile: Dictionary = gm.protagonist_profile()
	_assert_equal(main_shell._player_hitbox_radius(), float(profile.hitbox), "Main hitbox helper should use selected protagonist hitbox.")
	_assert_equal(main_shell._player_graze_radius(), float(profile.graze_radius), "Main graze helper should use selected protagonist graze radius.")
	_assert(main_shell._player_hitbox_radius() != gm.PLAYER_HITBOX, "Swordswoman hitbox regression should differ from legacy default constant.")
	_assert(main_shell._player_graze_radius() != gm.PLAYER_GRAZE, "Swordswoman graze regression should differ from legacy default constant.")
	main_shell.free()
	gm.free()

func _verify_ui_details() -> void:
	var ui_script = load("res://scripts/ui/ui_model.gd")
	if not _assert(ui_script != null, "Could not load ui_model.gd"):
		return
	var db_script = load("res://scripts/data/game_database.gd")
	if not _assert(db_script != null, "Could not load game_database.gd"):
		return
	var db = db_script.new()
	var ui = ui_script.new()
	for entry in ui.protagonist_entries():
		_assert(entry.has("detail_lines"), "Protagonist UI entry missing detail_lines: %s" % [entry])
		_assert(entry.detail_lines.size() >= 3, "Protagonist UI detail_lines should show speed, bomb behavior, and hint.")
		var profile: Dictionary = db.protagonist_by_id(String(entry.id))
		if not _assert(not profile.is_empty(), "Protagonist UI entry should map to a database profile: %s" % [entry]):
			continue
		var bomb: Dictionary = profile.get("bomb", {})
		var bomb_name := String(bomb.get("hud_name", bomb.get("display_name", "")))
		var bomb_description := String(bomb.get("description", ""))
		var detail_text := "\n".join(entry.detail_lines)
		_assert(detail_text.contains(bomb_name), "Protagonist UI detail_lines should include bomb name for %s: %s" % [String(entry.id), entry.detail_lines])
		_assert(detail_text.contains(bomb_description), "Protagonist UI detail_lines should include bomb behavior for %s: %s" % [String(entry.id), entry.detail_lines])
	for shot in ui.shot_entries("swordswoman"):
		_assert(shot.has("detail_lines"), "Shot UI entry missing detail_lines: %s" % [shot])
		_assert(shot.detail_lines.size() >= 3, "Shot UI detail_lines should show coverage, focused damage, and hint.")

func _init() -> void:
	_verify_database_profiles()
	if failed:
		return
	_verify_game_manager_helpers()
	if failed:
		return
	_verify_main_radius_helpers_use_selected_profile()
	if failed:
		return
	_verify_ui_details()
	if failed:
		return
	quit(0)
