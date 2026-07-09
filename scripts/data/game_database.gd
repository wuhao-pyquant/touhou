extends RefCounted
class_name GameDatabase

const SHOT_PROFILE_FIELDS := {
	"ofuda_trace": {"hud_name": "Ofuda Trace", "type_label": "Type A", "pattern_id": "miko_tracking_ofuda", "bullet_type": "homing", "fire_interval_frames": 3, "base_damage": 1.15, "bullet_speed": 5.4, "coverage": "wide tracking", "focused_damage": "low", "difficulty_hint": "safe learning shot", "color": Color(0.31, 1.0, 0.55)},
	"yin_yang_focus": {"hud_name": "Yin-Yang Focus", "type_label": "Type B", "pattern_id": "miko_yinyang_focus", "bullet_type": "linear", "fire_interval_frames": 4, "base_damage": 2.8, "bullet_speed": 9.2, "coverage": "narrow forward", "focused_damage": "medium", "difficulty_hint": "focused boss route", "color": Color(1.0, 0.31, 0.31)},
	"stardust_spread": {"hud_name": "Stardust Spread", "type_label": "Type A", "pattern_id": "magician_stardust_spread", "bullet_type": "spread", "fire_interval_frames": 3, "base_damage": 1.55, "bullet_speed": 7.4, "coverage": "wide close range", "focused_damage": "medium", "difficulty_hint": "screen coverage route", "color": Color(0.71, 0.31, 1.0)},
	"magic_laser": {"hud_name": "Magic Laser", "type_label": "Type B", "pattern_id": "magician_magic_laser", "bullet_type": "linear", "fire_interval_frames": 5, "base_damage": 4.6, "bullet_speed": 11.0, "coverage": "straight piercing", "focused_damage": "high", "difficulty_hint": "boss damage route", "color": Color(1.0, 0.31, 0.31)},
	"sword_wave_fan": {"hud_name": "Sword Wave Fan", "type_label": "Type A", "pattern_id": "swordswoman_wave_fan", "bullet_type": "spread", "fire_interval_frames": 3, "base_damage": 1.95, "bullet_speed": 8.0, "coverage": "midrange fan", "focused_damage": "medium", "difficulty_hint": "aggressive screen control", "color": Color(0.71, 0.31, 1.0)},
	"returning_spirit_blades": {"hud_name": "Returning Spirit Blades", "type_label": "Type B", "pattern_id": "swordswoman_returning_blades", "bullet_type": "homing", "fire_interval_frames": 4, "base_damage": 2.25, "bullet_speed": 6.4, "coverage": "returning homing blades", "focused_damage": "medium", "difficulty_hint": "mobile routing shot", "color": Color(0.31, 1.0, 0.55)},
}

const BOMB_PROFILE_FIELDS := {
	"miko": {"hud_name": "Great Boundary Bloom", "behavior_id": "boundary_bloom", "duration_frames": 150, "waves": 6, "clear_radius": 220.0, "damage": 1.1, "bullet_count": 36, "speed": 4.2, "color": Color(0.78, 0.39, 1.0), "description": "clear then sustained boundary pulses"},
	"magician": {"hud_name": "Festival Master Spark", "behavior_id": "master_spark", "duration_frames": 78, "waves": 5, "clear_radius": 120.0, "damage": 3.4, "bullet_count": 9, "speed": 11.0, "color": Color(1.0, 0.31, 0.31), "description": "directional high damage laser burst"},
	"swordswoman": {"hud_name": "Instant Slash Boundary", "behavior_id": "instant_slash", "duration_frames": 96, "waves": 8, "clear_radius": 145.0, "damage": 2.4, "bullet_count": 7, "speed": 9.0, "color": Color(0.31, 1.0, 0.55), "description": "instant path clear slashes"},
}

const PROTAGONISTS := [
	{
		"id": "miko",
		"display_name": "结界巫女",
		"role": "balanced_support",
		"speed_high": 5.7,
		"speed_low": 2.4,
		"hitbox": 2.0,
		"graze_radius": 10.0,
		"difficulty_hint": "safe route learning",
		"shot_types": [
			{"id": "ofuda_trace", "display_name": "追踪御札", "style": "low_damage_tracking"},
			{"id": "yin_yang_focus", "display_name": "阴阳玉集中", "style": "focused_forward"},
		],
		"bomb": {"id": "great_boundary_bloom", "display_name": "大结界展开", "style": "clear_then_sustain"},
	},
	{
		"id": "magician",
		"display_name": "星尘魔法使",
		"role": "range_spellcaster",
		"speed_high": 5.2,
		"speed_low": 2.0,
		"hitbox": 2.1,
		"graze_radius": 10.5,
		"difficulty_hint": "high boss damage",
		"shot_types": [
			{"id": "stardust_spread", "display_name": "星屑散射", "style": "wide_close_damage"},
			{"id": "magic_laser", "display_name": "魔导激光", "style": "high_forward_dps"},
		],
		"bomb": {"id": "festival_master_spark", "display_name": "祭典魔炮", "style": "directional_burst"},
	},
	{
		"id": "swordswoman",
		"display_name": "半妖剑士",
		"role": "close_combat_striker",
		"speed_high": 6.2,
		"speed_low": 2.7,
		"hitbox": 1.9,
		"graze_radius": 9.5,
		"difficulty_hint": "aggressive routing",
		"shot_types": [
			{"id": "sword_wave_fan", "display_name": "剑气扇形", "style": "midrange_fan"},
			{"id": "returning_spirit_blades", "display_name": "灵刃回旋", "style": "returning_blades"},
		],
		"bomb": {"id": "instant_slash_boundary", "display_name": "瞬斩结界", "style": "path_clear_slashes"},
	},
]

const STAGES := [
	{"index": 1, "id": "shrine_approach", "display_name": "神社参道", "theme": "bright_festival_opening", "midboss_id": "lantern_tsukumogami", "boss_id": "festival_guide_fox"},
	{"index": 2, "id": "yokai_market", "display_name": "妖怪市集", "theme": "tools_and_trade", "midboss_id": "abacus_tsukumogami", "boss_id": "oni_market_leader"},
	{"index": 3, "id": "mist_bamboo_grove", "display_name": "迷雾竹林", "theme": "fog_and_wrong_paths", "midboss_id": "lost_rabbit_yokai", "boss_id": "bamboo_illusionist"},
	{"index": 4, "id": "tengu_mountain_path", "display_name": "天狗山道", "theme": "wind_and_news", "midboss_id": "rookie_crow_tengu", "boss_id": "mountain_wind_tengu"},
	{"index": 5, "id": "oni_banquet_hall", "display_name": "鬼之宴厅", "theme": "drums_and_oni_fire", "midboss_id": "little_oni_drummer", "boss_id": "banquet_oni_princess"},
	{"index": 6, "id": "night_festival_divine_realm", "display_name": "夜祭神域", "theme": "lantern_faith_domain", "midboss_id": "festival_fox_miko", "boss_id": "hyakki_night_festival_god"},
]

const BULLET_FAMILIES := [
	{"id": "circle", "display_name": "圆弹", "collision": "round", "role": "baseline_pressure"},
	{"id": "rice", "display_name": "米弹", "collision": "round", "role": "woven_paths"},
	{"id": "butterfly", "display_name": "蝶弹", "collision": "round", "role": "decorative_spread"},
	{"id": "needle", "display_name": "针弹", "collision": "thin", "role": "fast_aimed_pressure"},
	{"id": "talisman", "display_name": "札弹", "collision": "round", "role": "spell_theme"},
	{"id": "star", "display_name": "星弹", "collision": "round", "role": "magical_spread"},
	{"id": "laser", "display_name": "激光", "collision": "line", "role": "lane_denial"},
	{"id": "large_orb", "display_name": "大玉", "collision": "round", "role": "space_control"},
]

const ITEM_TYPES := [
	{"id": "power", "display_name": "灵力", "role": "shot_power"},
	{"id": "point", "display_name": "得点物", "role": "score"},
	{"id": "bomb_fragment", "display_name": "炸弹碎片", "role": "three_make_bomb"},
	{"id": "life_fragment", "display_name": "残机碎片", "role": "five_make_life"},
	{"id": "night_festival_seal", "display_name": "夜祭符", "role": "risk_score_bonus"},
	{"id": "full_power", "display_name": "满火力", "role": "recovery"},
]

func protagonists() -> Array:
	return _protagonists_with_profiles()

func stages() -> Array:
	return STAGES.duplicate(true)

func bullet_families() -> Array:
	return BULLET_FAMILIES.duplicate(true)

func item_types() -> Array:
	return ITEM_TYPES.duplicate(true)

func stage_by_index(index: int) -> Dictionary:
	for stage in STAGES:
		if int(stage.index) == index:
			return stage.duplicate(true)
	return {}

func protagonist_by_id(id: String) -> Dictionary:
	for protagonist in _protagonists_with_profiles():
		if String(protagonist.id) == id:
			return protagonist.duplicate(true)
	return {}

func shot_profile_by_id(shot_id: String) -> Dictionary:
	for protagonist in _protagonists_with_profiles():
		for shot in protagonist.get("shot_types", []):
			if String(shot.get("id", "")) == shot_id:
				return shot.duplicate(true)
	return {}

func bomb_profile_for_protagonist(protagonist_id: String) -> Dictionary:
	var protagonist := protagonist_by_id(protagonist_id)
	if protagonist.is_empty():
		return {}
	return protagonist.get("bomb", {}).duplicate(true)

func _protagonists_with_profiles() -> Array:
	var result: Array = PROTAGONISTS.duplicate(true)
	for protagonist in result:
		var protagonist_id := String(protagonist.get("id", ""))
		var shots: Array = protagonist.get("shot_types", [])
		for i in range(shots.size()):
			var shot: Dictionary = shots[i]
			var shot_id := String(shot.get("id", ""))
			if SHOT_PROFILE_FIELDS.has(shot_id):
				shot.merge(SHOT_PROFILE_FIELDS[shot_id], false)
			shots[i] = shot
		var bomb: Dictionary = protagonist.get("bomb", {})
		if BOMB_PROFILE_FIELDS.has(protagonist_id):
			bomb.merge(BOMB_PROFILE_FIELDS[protagonist_id], false)
		protagonist["bomb"] = bomb
	return result
