extends RefCounted
class_name GameDatabase

const PROTAGONISTS := [
	{
		"id": "miko",
		"display_name": "结界巫女",
		"role": "balanced_support",
		"speed_high": 5.7,
		"speed_low": 2.4,
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
	return PROTAGONISTS.duplicate(true)

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
	for protagonist in PROTAGONISTS:
		if String(protagonist.id) == id:
			return protagonist.duplicate(true)
	return {}
