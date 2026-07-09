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

const ENEMY_FAMILIES := [
	{"id": "low_yokai", "display_name": "Low Yokai", "role": "tutorial pressure", "base_hp": 8.0, "radius": 14.0, "shoot_interval": 72.0, "default_pattern": "aimed", "bullet_family": "circle", "drop_tier": "light", "density": 0.65},
	{"id": "fast_attacker", "display_name": "Fast Attacker", "role": "lane route check", "base_hp": 9.0, "radius": 13.0, "shoot_interval": 84.0, "default_pattern": "downward", "bullet_family": "needle", "drop_tier": "light", "density": 0.75},
	{"id": "formation_shooter", "display_name": "Formation Shooter", "role": "synchronized rings and spreads", "base_hp": 14.0, "radius": 15.0, "shoot_interval": 66.0, "default_pattern": "ring", "bullet_family": "star", "drop_tier": "standard", "density": 1.0},
	{"id": "elite_yokai", "display_name": "Elite Yokai", "role": "durable pressure source", "base_hp": 24.0, "radius": 18.0, "shoot_interval": 48.0, "default_pattern": "double_spread", "bullet_family": "talisman", "drop_tier": "rich", "density": 1.2},
	{"id": "mechanism", "display_name": "Mechanism Enemy", "role": "stage object behavior", "base_hp": 18.0, "radius": 16.0, "shoot_interval": 60.0, "default_pattern": "wave", "bullet_family": "rice", "drop_tier": "mechanism", "density": 0.95},
]

const BULLET_FAMILY_FIELDS := {
	"circle": {"radius": 5.0, "speed_multiplier": 1.0, "collision_radius": 5.0, "color": Color(0.78, 0.36, 1.0), "draw_group": "round_small"},
	"rice": {"radius": 4.5, "speed_multiplier": 0.95, "collision_radius": 4.0, "color": Color(0.16, 0.86, 0.94), "draw_group": "rice_small"},
	"butterfly": {"radius": 5.5, "speed_multiplier": 0.9, "collision_radius": 4.5, "color": Color(1.0, 0.35, 0.78), "draw_group": "butterfly"},
	"needle": {"radius": 4.0, "speed_multiplier": 1.35, "collision_radius": 3.0, "color": Color(1.0, 0.72, 0.2), "draw_group": "needle"},
	"talisman": {"radius": 5.0, "speed_multiplier": 1.05, "collision_radius": 4.5, "color": Color(0.95, 0.22, 0.25), "draw_group": "talisman"},
	"star": {"radius": 5.0, "speed_multiplier": 1.0, "collision_radius": 4.5, "color": Color(0.45, 0.66, 1.0), "draw_group": "star"},
	"laser": {"radius": 6.0, "speed_multiplier": 1.2, "collision_radius": 5.0, "color": Color(1.0, 0.42, 0.18), "draw_group": "laser_warning"},
	"large_orb": {"radius": 10.0, "speed_multiplier": 0.65, "collision_radius": 8.0, "color": Color(0.62, 0.38, 1.0), "draw_group": "orb_large"},
}

const ITEM_TYPE_FIELDS := {
	"power": {"base_score": 10, "collect_behavior": "power"},
	"point": {"base_score": 10, "collect_behavior": "point"},
	"bomb_fragment": {"base_score": 100, "collect_behavior": "bomb_fragment", "fragment_goal": 3},
	"life_fragment": {"base_score": 500, "collect_behavior": "life_fragment", "fragment_goal": 5},
	"night_festival_seal": {"base_score": 1000, "collect_behavior": "night_festival_seal"},
	"full_power": {"base_score": 300, "collect_behavior": "full_power"},
}

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

const DROP_TABLES := {
	"light": [
		{"id": "power", "weight": 0.34},
		{"id": "point", "weight": 0.22},
		{"id": "bomb_fragment", "weight": 0.14},
		{"id": "life_fragment", "weight": 0.08},
		{"id": "night_festival_seal", "weight": 0.12},
		{"id": "full_power", "weight": 0.10},
	],
	"standard": [
		{"id": "power", "weight": 0.28},
		{"id": "point", "weight": 0.22},
		{"id": "bomb_fragment", "weight": 0.18},
		{"id": "life_fragment", "weight": 0.10},
		{"id": "night_festival_seal", "weight": 0.14},
		{"id": "full_power", "weight": 0.08},
	],
	"rich": [
		{"id": "point", "weight": 0.20},
		{"id": "bomb_refill", "weight": 0.20},
		{"id": "bomb_fragment", "weight": 0.22},
		{"id": "life_fragment", "weight": 0.14},
		{"id": "night_festival_seal", "weight": 0.16},
		{"id": "full_power", "weight": 0.08},
	],
	"mechanism": [
		{"id": "power", "weight": 0.24},
		{"id": "point", "weight": 0.18},
		{"id": "bomb_fragment", "weight": 0.18},
		{"id": "life_fragment", "weight": 0.10},
		{"id": "night_festival_seal", "weight": 0.20},
		{"id": "full_power", "weight": 0.10},
	],
}

const SCORING_RULES := {
	"enemy_defeat": 50,
	"graze": 10,
	"point_base": 10,
	"top_collection_multiplier": 2.0,
	"night_festival_seal_base": 1000,
	"night_festival_seal_step": 0.05,
	"spell_card_no_miss_bonus": 100000,
	"spell_card_no_bomb_bonus": 50000,
}

func protagonists() -> Array:
	return _protagonists_with_profiles()

func stages() -> Array:
	return STAGES.duplicate(true)

func enemy_families() -> Array:
	return ENEMY_FAMILIES.duplicate(true)

func bullet_families() -> Array:
	return _decorate_entries(BULLET_FAMILIES, BULLET_FAMILY_FIELDS)

func item_types() -> Array:
	return _decorate_entries(ITEM_TYPES, ITEM_TYPE_FIELDS)

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

func enemy_family_by_id(id: String) -> Dictionary:
	for family in ENEMY_FAMILIES:
		if String(family.id) == id:
			return family.duplicate(true)
	return {}

func bullet_family_by_id(id: String) -> Dictionary:
	for family in bullet_families():
		if String(family.id) == id:
			return family.duplicate(true)
	return {}

func item_type_by_id(id: String) -> Dictionary:
	for item in item_types():
		if String(item.id) == id:
			return item.duplicate(true)
	return {}

func drop_table_for_tier(tier: String) -> Array:
	if DROP_TABLES.has(tier):
		return DROP_TABLES[tier].duplicate(true)
	return DROP_TABLES["standard"].duplicate(true)

func scoring_rules() -> Dictionary:
	return SCORING_RULES.duplicate(true)

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

func _decorate_entries(base_entries: Array, extra_fields: Dictionary) -> Array:
	var result: Array = base_entries.duplicate(true)
	for i in range(result.size()):
		var entry: Dictionary = result[i]
		var entry_id := String(entry.get("id", ""))
		if extra_fields.has(entry_id):
			entry.merge(extra_fields[entry_id], false)
		result[i] = entry
	return result

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
