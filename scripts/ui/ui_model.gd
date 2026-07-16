extends RefCounted
class_name UiModel

var _database

func _init() -> void:
	_database = load("res://scripts/data/game_database.gd").new()

func main_menu_entries() -> Array:
	return [
		{"id": "start", "label": "开始游戏", "description": "从第一关开始"},
		{"id": "practice", "label": "练习模式", "description": "进入练习入口"},
		{"id": "settings", "label": "设置", "description": "调整声音、画面与辅助显示"},
		{"id": "exit", "label": "退出游戏", "description": "关闭游戏"},
	]

func practice_stage_entries(stage_names: Array, highest_reached_stage: int) -> Array:
	var entries: Array = []
	var unlocked_count := clampi(highest_reached_stage, 1, stage_names.size())
	for i in range(unlocked_count):
		entries.append({
			"id": "stage_%d" % (i + 1),
			"stage": i + 1,
			"label": "第 %d 关  %s" % [i + 1, String(stage_names[i])],
			"description": "从本关开始练习，击破 Boss 后结束",
		})
	if highest_reached_stage >= 2:
		entries.append({
			"id": "stage_2_phase_practice",
			"stage": 2,
			"label": "第二关 符卡练习",
			"description": "从第二关已解锁的单个符卡直接开始",
		})
	return entries

func stage2_phase_practice_entries() -> Array:
	return [
		{"id": "stage_2_midboss_nonspell_1", "label": "算符「市集の横列」", "description": "第二关 中B 非符"},
		{"id": "stage_2_midboss_spell_1", "label": "珠符「跳ねるそろばん玉」", "description": "第二关 中B 符卡"},
		{"id": "stage_2_boss_nonspell_1", "label": "市符「妖市の値切り」", "description": "第二关 Boss 非符"},
		{"id": "stage_2_boss_spell_1", "label": "泡符「銅貨の泡涌き」", "description": "第二关 Boss 符卡 1"},
		{"id": "stage_2_boss_spell_2", "label": "道具「迷子の道具屋」", "description": "第二关 Boss 符卡 2"},
		{"id": "stage_2_boss_spell_3", "label": "鏡符「計り直しの水鏡」", "description": "第二关 Boss 符卡 3"},
	]

func pause_menu_entries() -> Array:
	return [
		{"id": "continue", "label": "继续", "description": "返回当前战斗"},
		{"id": "restart_stage", "label": "重新开始本关", "description": "从本关开头重来"},
		{"id": "settings", "label": "设置", "description": "调整声音、画面与辅助显示"},
		{"id": "return_to_main_menu", "label": "返回标题", "description": "回到标题菜单"},
		{"id": "exit_game", "label": "退出游戏", "description": "关闭游戏"},
	]

func settings_entries(settings: Dictionary) -> Array:
	return [
		_range_entry("master_volume", "主音量", "整体音量", settings.get("master_volume", 1.0), 0.0, 1.0, 0.05),
		_range_entry("bgm_volume", "音乐音量", "背景音乐音量", settings.get("bgm_volume", 0.8), 0.0, 1.0, 0.05),
		_range_entry("sfx_volume", "音效音量", "射击、命中与菜单音效", settings.get("sfx_volume", 0.8), 0.0, 1.0, 0.05),
		_toggle_entry("fullscreen", "全屏显示", "切换窗口与全屏", settings.get("fullscreen", false)),
		_range_entry("bullet_brightness", "弹幕亮度", "调整弹幕显示亮度", settings.get("bullet_brightness", 1.0), 0.5, 1.5, 0.05),
		_toggle_entry("always_show_focus_hitbox", "始终显示判定点", "低速移动外也显示判定点", settings.get("always_show_focus_hitbox", false)),
		_toggle_entry("show_performance_hud", "显示性能信息", "显示帧率与调试信息", settings.get("show_performance_hud", false)),
		_toggle_entry("show_input_guide", "显示操作提示", "显示基础按键提示", settings.get("show_input_guide", true)),
	]

func protagonist_entries() -> Array:
	var entries: Array = []
	for protagonist in _database.protagonists():
		entries.append({
			"id": String(protagonist.get("id", "")),
			"label": String(protagonist.get("display_name", "")),
			"description": _role_description(String(protagonist.get("role", ""))),
			"detail_lines": [
				"Speed %.1f / %.1f" % [float(protagonist.speed_high), float(protagonist.speed_low)],
				"Bomb: %s - %s" % [
					String(protagonist.bomb.get("hud_name", protagonist.bomb.get("display_name", ""))),
					String(protagonist.bomb.get("description", "")),
				],
				"Hint: %s" % String(protagonist.get("difficulty_hint", "")),
			],
		})
	return entries

func shot_entries(protagonist_id: String) -> Array:
	var protagonist: Dictionary = _database.protagonist_by_id(protagonist_id)
	if protagonist.is_empty():
		return []

	var entries: Array = []
	var shots: Array = protagonist.get("shot_types", [])
	for shot in shots:
		entries.append({
			"id": String(shot.get("id", "")),
			"label": String(shot.get("display_name", "")),
			"description": _shot_description(String(shot.get("style", ""))),
			"detail_lines": [
				"%s  Coverage: %s" % [String(shot.get("type_label", "")), String(shot.get("coverage", ""))],
				"Focused damage: %s" % String(shot.get("focused_damage", "")),
				"Hint: %s" % String(shot.get("difficulty_hint", "")),
			],
		})
	return entries

func move_cursor(cursor: int, delta: int, count: int) -> int:
	if count <= 0:
		return 0
	return posmod(cursor + delta, count)

func _range_entry(id: String, label: String, description: String, value, minimum: float, maximum: float, step: float) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"description": description,
		"type": "range",
		"value": value,
		"min": minimum,
		"max": maximum,
		"step": step,
	}

func _toggle_entry(id: String, label: String, description: String, value) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"description": description,
		"type": "toggle",
		"value": value,
	}

func _role_description(role: String) -> String:
	match role:
		"balanced_support":
			return "均衡支援型"
		"range_spellcaster":
			return "远程术式型"
		"close_combat_striker":
			return "近战突击型"
		_:
			return ""

func _shot_description(style: String) -> String:
	match style:
		"low_damage_tracking":
			return "低伤害追踪"
		"focused_forward":
			return "集中正面火力"
		"wide_close_damage":
			return "近距离广范围"
		"high_forward_dps":
			return "高输出直线火力"
		"midrange_fan":
			return "中距离扇形"
		"returning_blades":
			return "回旋灵刃"
		_:
			return ""
