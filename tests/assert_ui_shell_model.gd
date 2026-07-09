extends SceneTree

const EXPECTED_STAGE_NAMES := [
	"神社参道",
	"妖怪市集",
	"迷雾竹林",
	"天狗山道",
	"鬼之宴厅",
	"夜祭神域",
]

const EXPECTED_DEFAULT_SETTINGS := {
	"master_volume": 1.0,
	"bgm_volume": 0.8,
	"sfx_volume": 0.8,
	"fullscreen": false,
	"bullet_brightness": 1.0,
	"always_show_focus_hitbox": false,
	"show_performance_hud": false,
	"show_input_guide": true,
}

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

func _script_constants(script: Script) -> Dictionary:
	if script == null:
		_fail("Expected script to be loaded before reading constants")
	return script.get_script_constant_map()

func _require_constant(constants: Dictionary, name: String, expected: String) -> bool:
	if not _assert(constants.has(name), "GameManager missing constant %s" % name):
		return false
	return _assert_equal(constants[name], expected, "GameManager.%s mismatch." % name)

func _has_property(object: Object, name: String) -> bool:
	for property in object.get_property_list():
		if String(property.get("name", "")) == name:
			return true
	return false

func _ids(entries: Array) -> Array:
	var result: Array = []
	for entry in entries:
		result.append(String(entry.get("id", "")))
	return result

func _labels(entries: Array) -> Array:
	var result: Array = []
	for entry in entries:
		result.append(String(entry.get("label", "")))
	return result

func _assert_entry_shape(entries: Array, context: String) -> void:
	for entry in entries:
		_assert(entry is Dictionary, "%s entry should be a Dictionary: %s" % [context, entry])
		_assert(entry.has("id"), "%s entry missing id: %s" % [context, entry])
		_assert(entry.has("label"), "%s entry missing label: %s" % [context, entry])
		_assert(String(entry.id) != "", "%s entry id should not be empty: %s" % [context, entry])
		_assert(String(entry.label) != "", "%s entry label should not be empty: %s" % [context, entry])

func _assert_settings_entry(settings_entries: Array, id: String, label: String, value) -> void:
	for entry in settings_entries:
		if String(entry.get("id", "")) == id:
			_assert_equal(String(entry.get("label", "")), label, "Settings label for %s mismatch." % id)
			_assert_equal(entry.get("value"), value, "Settings value for %s mismatch." % id)
			return
	_fail("Settings entries missing %s" % id)

func _assert_shot_mapping(main_shell: Node, shot_id: String, expected_bullet_type: int) -> void:
	_assert_equal(main_shell._bullet_type_for_shot_id(shot_id), expected_bullet_type, "Shot id %s should map to compatible bullet type." % shot_id)

func _init() -> void:
	var gm_script = load("res://autoload/game_manager.gd")
	if gm_script == null:
		_fail("Could not load game_manager.gd")
		return
	var gm = gm_script.new()

	if not _assert_equal(gm.STAGE_NAMES, EXPECTED_STAGE_NAMES, "GameManager.STAGE_NAMES should expose readable Chinese stage labels."):
		return

	var constants := _script_constants(gm_script)
	if not _require_constant(constants, "STATE_TITLE", "title"):
		return
	if not _require_constant(constants, "STATE_CHARACTER_SELECT", "character_select"):
		return
	if not _require_constant(constants, "STATE_SHOT_SELECT", "shot_select"):
		return
	if not _require_constant(constants, "STATE_SETTINGS", "settings"):
		return
	if not _require_constant(constants, "STATE_PAUSED", "paused"):
		return
	if not _require_constant(constants, "STATE_STAGE", "stage"):
		return
	if not _require_constant(constants, "STATE_BOSS", "boss"):
		return
	if not _require_constant(constants, "STATE_STAGE_CLEAR", "stage_clear"):
		return
	if not _require_constant(constants, "STATE_FINAL_CLEAR", "final_clear"):
		return
	if not _require_constant(constants, "STATE_GAME_OVER", "game_over"):
		return

	for property in ["selected_protagonist_id", "selected_shot_id", "practice_mode", "pause_return_state", "settings_return_state", "settings"]:
		if not _assert(_has_property(gm, property), "GameManager missing property %s" % property):
			return

	gm.state = "boss"
	gm.selected_protagonist_id = "magician"
	gm.selected_shot_id = "magic_laser"
	gm.practice_mode = true
	gm.pause_return_state = "boss"
	gm.settings_return_state = "paused"
	gm.settings = {
		"master_volume": 0.2,
		"bgm_volume": 0.3,
		"sfx_volume": 0.4,
		"fullscreen": true,
		"bullet_brightness": 0.6,
		"always_show_focus_hitbox": true,
		"show_performance_hud": true,
		"show_input_guide": false,
	}
	gm.reset()
	if not _assert_equal(gm.state, "title", "GameManager.reset() should restore title state."):
		return
	if not _assert_equal(gm.selected_protagonist_id, "miko", "GameManager.reset() should restore shrine maiden protagonist."):
		return
	if not _assert_equal(gm.selected_shot_id, "ofuda_trace", "GameManager.reset() should restore miko shot A."):
		return
	if not _assert_equal(gm.practice_mode, false, "GameManager.reset() should restore story mode."):
		return
	if not _assert_equal(gm.pause_return_state, "stage", "GameManager.reset() should restore pause return state."):
		return
	if not _assert_equal(gm.settings_return_state, "title", "GameManager.reset() should restore settings return state."):
		return
	if not _assert_equal(gm.settings, EXPECTED_DEFAULT_SETTINGS, "GameManager.reset() should restore default settings."):
		return

	var ui_model_script = load("res://scripts/ui/ui_model.gd")
	if ui_model_script == null:
		_fail("Could not load ui_model.gd")
		return
	var ui_model = ui_model_script.new()

	var main_entries: Array = ui_model.main_menu_entries()
	_assert_entry_shape(main_entries, "main menu")
	_assert_equal(_ids(main_entries), ["start", "practice", "settings", "exit"], "Main menu ids mismatch.")
	_assert_equal(_labels(main_entries), ["开始游戏", "练习模式", "设置", "退出游戏"], "Main menu labels mismatch.")

	var pause_entries: Array = ui_model.pause_menu_entries()
	_assert_entry_shape(pause_entries, "pause menu")
	_assert_equal(_ids(pause_entries), ["continue", "restart_stage", "settings", "return_to_main_menu", "exit_game"], "Pause menu ids mismatch.")
	_assert_equal(_labels(pause_entries), ["继续", "重新开始本关", "设置", "返回标题", "退出游戏"], "Pause menu labels mismatch.")

	var settings_entries: Array = ui_model.settings_entries(gm.settings)
	_assert_entry_shape(settings_entries, "settings")
	_assert_equal(_ids(settings_entries), ["master_volume", "bgm_volume", "sfx_volume", "fullscreen", "bullet_brightness", "always_show_focus_hitbox", "show_performance_hud", "show_input_guide"], "Settings entry ids mismatch.")
	_assert_settings_entry(settings_entries, "master_volume", "主音量", 1.0)
	_assert_settings_entry(settings_entries, "bgm_volume", "音乐音量", 0.8)
	_assert_settings_entry(settings_entries, "sfx_volume", "音效音量", 0.8)
	_assert_settings_entry(settings_entries, "fullscreen", "全屏显示", false)
	_assert_settings_entry(settings_entries, "bullet_brightness", "弹幕亮度", 1.0)
	_assert_settings_entry(settings_entries, "always_show_focus_hitbox", "始终显示判定点", false)
	_assert_settings_entry(settings_entries, "show_performance_hud", "显示性能信息", false)
	_assert_settings_entry(settings_entries, "show_input_guide", "显示操作提示", true)

	var protagonist_entries: Array = ui_model.protagonist_entries()
	_assert_entry_shape(protagonist_entries, "protagonist")
	_assert_equal(protagonist_entries.size(), 3, "UiModel.protagonist_entries() should expose three protagonists.")
	_assert_equal(_ids(protagonist_entries), ["miko", "magician", "swordswoman"], "Protagonist ids mismatch.")
	_assert_equal(_labels(protagonist_entries), ["结界巫女", "星尘魔法使", "半妖剑士"], "Protagonist labels mismatch.")

	var shot_entries: Array = ui_model.shot_entries("miko")
	_assert_entry_shape(shot_entries, "miko shot")
	_assert_equal(shot_entries.size(), 2, "UiModel.shot_entries(\"miko\") should expose two shots.")
	_assert_equal(_ids(shot_entries), ["ofuda_trace", "yin_yang_focus"], "Miko shot ids mismatch.")
	_assert_equal(_labels(shot_entries), ["追踪御札", "阴阳玉集中"], "Miko shot labels mismatch.")

	var main_script = load("res://scripts/main.gd")
	if main_script == null:
		_fail("Could not load main.gd")
		return
	var main_shell: Node = main_script.new()
	_assert_shot_mapping(main_shell, "ofuda_trace", gm.BulletType.HOMING)
	_assert_shot_mapping(main_shell, "yin_yang_focus", gm.BulletType.LINEAR)
	_assert_shot_mapping(main_shell, "stardust_spread", gm.BulletType.SPREAD)
	_assert_shot_mapping(main_shell, "magic_laser", gm.BulletType.LINEAR)
	_assert_shot_mapping(main_shell, "sword_wave_fan", gm.BulletType.SPREAD)
	_assert_shot_mapping(main_shell, "returning_spirit_blades", gm.BulletType.HOMING)
	main_shell.free()

	_assert_equal(ui_model.move_cursor(0, -1, 4), 3, "Cursor should wrap upward.")
	_assert_equal(ui_model.move_cursor(3, 1, 4), 0, "Cursor should wrap downward.")
	_assert_equal(ui_model.move_cursor(2, 1, 0), 0, "Cursor should stay at zero when there are no entries.")

	quit(0)
