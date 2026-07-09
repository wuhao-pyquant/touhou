extends Node

const STAGE_BACKGROUNDS := {
	"shrine_approach": {
		"far": "res://assets/backgrounds/stage1_shrine_approach_far.png",
		"mid": "res://assets/backgrounds/stage1_shrine_approach_mid.png",
		"front": "res://assets/backgrounds/stage1_shrine_approach_front.png",
		"atmosphere": "res://assets/backgrounds/stage1_shrine_approach_atmosphere.png",
	},
	"yokai_market": {
		"far": "res://assets/backgrounds/stage2_yokai_market_far.png",
		"mid": "res://assets/backgrounds/stage2_yokai_market_mid.png",
		"front": "res://assets/backgrounds/stage2_yokai_market_front.png",
		"atmosphere": "res://assets/backgrounds/stage2_yokai_market_atmosphere.png",
	},
	"mist_bamboo_grove": {
		"far": "res://assets/backgrounds/stage3_mist_bamboo_grove_far.png",
		"mid": "res://assets/backgrounds/stage3_mist_bamboo_grove_mid.png",
		"front": "res://assets/backgrounds/stage3_mist_bamboo_grove_front.png",
		"atmosphere": "res://assets/backgrounds/stage3_mist_bamboo_grove_atmosphere.png",
	},
	"tengu_mountain_path": {
		"far": "res://assets/backgrounds/stage4_tengu_mountain_path_far.png",
		"mid": "res://assets/backgrounds/stage4_tengu_mountain_path_mid.png",
		"front": "res://assets/backgrounds/stage4_tengu_mountain_path_front.png",
		"atmosphere": "res://assets/backgrounds/stage4_tengu_mountain_path_atmosphere.png",
	},
	"oni_banquet_hall": {
		"far": "res://assets/backgrounds/stage5_oni_banquet_hall_far.png",
		"mid": "res://assets/backgrounds/stage5_oni_banquet_hall_mid.png",
		"front": "res://assets/backgrounds/stage5_oni_banquet_hall_front.png",
		"atmosphere": "res://assets/backgrounds/stage5_oni_banquet_hall_atmosphere.png",
	},
	"night_festival_divine_realm": {
		"far": "res://assets/backgrounds/stage6_night_festival_divine_realm_far.png",
		"mid": "res://assets/backgrounds/stage6_night_festival_divine_realm_mid.png",
		"front": "res://assets/backgrounds/stage6_night_festival_divine_realm_front.png",
		"atmosphere": "res://assets/backgrounds/stage6_night_festival_divine_realm_atmosphere.png",
	},
}

const PROTAGONIST_ASSETS := {
	"miko": {
		"portrait": "res://assets/characters/protagonists/miko_portrait.png",
		"sprite": "res://assets/characters/protagonists/miko_sprite_sheet.png",
		"shot_atlas": "res://assets/effects/player/miko_shots.png",
		"bomb_atlas": "res://assets/effects/bombs/great_boundary_bloom.png",
		"ending": "res://assets/endings/miko_ending.png",
	},
	"magician": {
		"portrait": "res://assets/characters/protagonists/magician_portrait.png",
		"sprite": "res://assets/characters/protagonists/magician_sprite_sheet.png",
		"shot_atlas": "res://assets/effects/player/magician_shots.png",
		"bomb_atlas": "res://assets/effects/bombs/festival_master_spark.png",
		"ending": "res://assets/endings/magician_ending.png",
	},
	"swordswoman": {
		"portrait": "res://assets/characters/protagonists/swordswoman_portrait.png",
		"sprite": "res://assets/characters/protagonists/swordswoman_sprite_sheet.png",
		"shot_atlas": "res://assets/effects/player/swordswoman_shots.png",
		"bomb_atlas": "res://assets/effects/bombs/instant_slash_boundary.png",
		"ending": "res://assets/endings/swordswoman_ending.png",
	},
}

const BOSS_ASSETS := {
	"lantern_tsukumogami": {"portrait": "res://assets/characters/bosses/lantern_tsukumogami_portrait.png", "sprite": "res://assets/characters/bosses/lantern_tsukumogami_sprite.png", "spell_background": "res://assets/ui/spell_backgrounds/lantern_tsukumogami.png"},
	"festival_guide_fox": {"portrait": "res://assets/characters/bosses/festival_guide_fox_portrait.png", "sprite": "res://assets/characters/bosses/festival_guide_fox_sprite.png", "spell_background": "res://assets/ui/spell_backgrounds/festival_guide_fox.png"},
	"abacus_tsukumogami": {"portrait": "res://assets/characters/bosses/abacus_tsukumogami_portrait.png", "sprite": "res://assets/characters/bosses/abacus_tsukumogami_sprite.png", "spell_background": "res://assets/ui/spell_backgrounds/abacus_tsukumogami.png"},
	"oni_market_leader": {"portrait": "res://assets/characters/bosses/oni_market_leader_portrait.png", "sprite": "res://assets/characters/bosses/oni_market_leader_sprite.png", "spell_background": "res://assets/ui/spell_backgrounds/oni_market_leader.png"},
	"lost_rabbit_yokai": {"portrait": "res://assets/characters/bosses/lost_rabbit_yokai_portrait.png", "sprite": "res://assets/characters/bosses/lost_rabbit_yokai_sprite.png", "spell_background": "res://assets/ui/spell_backgrounds/lost_rabbit_yokai.png"},
	"bamboo_illusionist": {"portrait": "res://assets/characters/bosses/bamboo_illusionist_portrait.png", "sprite": "res://assets/characters/bosses/bamboo_illusionist_sprite.png", "spell_background": "res://assets/ui/spell_backgrounds/bamboo_illusionist.png"},
	"rookie_crow_tengu": {"portrait": "res://assets/characters/bosses/rookie_crow_tengu_portrait.png", "sprite": "res://assets/characters/bosses/rookie_crow_tengu_sprite.png", "spell_background": "res://assets/ui/spell_backgrounds/rookie_crow_tengu.png"},
	"mountain_wind_tengu": {"portrait": "res://assets/characters/bosses/mountain_wind_tengu_portrait.png", "sprite": "res://assets/characters/bosses/mountain_wind_tengu_sprite.png", "spell_background": "res://assets/ui/spell_backgrounds/mountain_wind_tengu.png"},
	"little_oni_drummer": {"portrait": "res://assets/characters/bosses/little_oni_drummer_portrait.png", "sprite": "res://assets/characters/bosses/little_oni_drummer_sprite.png", "spell_background": "res://assets/ui/spell_backgrounds/little_oni_drummer.png"},
	"banquet_oni_princess": {"portrait": "res://assets/characters/bosses/banquet_oni_princess_portrait.png", "sprite": "res://assets/characters/bosses/banquet_oni_princess_sprite.png", "spell_background": "res://assets/ui/spell_backgrounds/banquet_oni_princess.png"},
	"festival_fox_miko": {"portrait": "res://assets/characters/bosses/festival_fox_miko_portrait.png", "sprite": "res://assets/characters/bosses/festival_fox_miko_sprite.png", "spell_background": "res://assets/ui/spell_backgrounds/festival_fox_miko.png"},
	"hyakki_night_festival_god": {"portrait": "res://assets/characters/bosses/hyakki_night_festival_god_portrait.png", "sprite": "res://assets/characters/bosses/hyakki_night_festival_god_sprite.png", "spell_background": "res://assets/ui/spell_backgrounds/hyakki_night_festival_god.png"},
}

const AUDIO_KEYS := {
	"shrine_approach": {"stage": "stage1_mid", "boss": "stage1_boss"},
	"yokai_market": {"stage": "stage2_mid", "boss": "stage2_boss"},
	"mist_bamboo_grove": {"stage": "stage3_mid", "boss": "stage3_boss"},
	"tengu_mountain_path": {"stage": "stage4_mid", "boss": "stage4_boss"},
	"oni_banquet_hall": {"stage": "stage5_mid", "boss": "stage5_boss"},
	"night_festival_divine_realm": {"stage": "stage6_mid", "boss": "stage6_boss"},
}

const PHASE6_STAGE_BACKGROUNDS := {
	1: {"far": "res://assets/backgrounds/stage_01/far.png", "mid": "res://assets/backgrounds/stage_01/mid.png", "near": "res://assets/backgrounds/stage_01/near.png", "spell": "res://assets/backgrounds/stage_01/spell.png"},
	2: {"far": "res://assets/backgrounds/stage_02/far.png", "mid": "res://assets/backgrounds/stage_02/mid.png", "near": "res://assets/backgrounds/stage_02/near.png", "spell": "res://assets/backgrounds/stage_02/spell.png"},
	3: {"far": "res://assets/backgrounds/stage_03/far.png", "mid": "res://assets/backgrounds/stage_03/mid.png", "near": "res://assets/backgrounds/stage_03/near.png", "spell": "res://assets/backgrounds/stage_03/spell.png"},
	4: {"far": "res://assets/backgrounds/stage_04/far.png", "mid": "res://assets/backgrounds/stage_04/mid.png", "near": "res://assets/backgrounds/stage_04/near.png", "spell": "res://assets/backgrounds/stage_04/spell.png"},
	5: {"far": "res://assets/backgrounds/stage_05/far.png", "mid": "res://assets/backgrounds/stage_05/mid.png", "near": "res://assets/backgrounds/stage_05/near.png", "spell": "res://assets/backgrounds/stage_05/spell.png"},
	6: {"far": "res://assets/backgrounds/stage_06/far.png", "mid": "res://assets/backgrounds/stage_06/mid.png", "near": "res://assets/backgrounds/stage_06/near.png", "spell": "res://assets/backgrounds/stage_06/spell.png"},
}

const PHASE6_PROTAGONIST_ASSETS := {
	"miko": {"sprite": "res://assets/characters/protagonists/miko_sprite_sheet.png", "portrait": "res://assets/characters/protagonists/miko_portrait.png", "focus_effects": "res://assets/effects/player/miko_focus_effects.png"},
	"magician": {"sprite": "res://assets/characters/protagonists/magician_sprite_sheet.png", "portrait": "res://assets/characters/protagonists/magician_portrait.png", "focus_effects": "res://assets/effects/player/magician_focus_effects.png"},
	"swordswoman": {"sprite": "res://assets/characters/protagonists/swordswoman_sprite_sheet.png", "portrait": "res://assets/characters/protagonists/swordswoman_portrait.png", "focus_effects": "res://assets/effects/player/swordswoman_focus_effects.png"},
}

const PHASE6_BOSS_ASSETS := {
	"lantern_tsukumogami": {"sprite": "res://assets/characters/bosses/lantern_tsukumogami_sprite.png", "portrait": "res://assets/characters/bosses/lantern_tsukumogami_portrait.png", "spell_aura": "res://assets/effects/boss/lantern_tsukumogami_spell_aura.png"},
	"festival_guide_fox": {"sprite": "res://assets/characters/bosses/festival_guide_fox_sprite.png", "portrait": "res://assets/characters/bosses/festival_guide_fox_portrait.png", "spell_aura": "res://assets/effects/boss/festival_guide_fox_spell_aura.png"},
	"abacus_tsukumogami": {"sprite": "res://assets/characters/bosses/abacus_tsukumogami_sprite.png", "portrait": "res://assets/characters/bosses/abacus_tsukumogami_portrait.png", "spell_aura": "res://assets/effects/boss/abacus_tsukumogami_spell_aura.png"},
	"oni_market_leader": {"sprite": "res://assets/characters/bosses/oni_market_leader_sprite.png", "portrait": "res://assets/characters/bosses/oni_market_leader_portrait.png", "spell_aura": "res://assets/effects/boss/oni_market_leader_spell_aura.png"},
	"lost_rabbit_yokai": {"sprite": "res://assets/characters/bosses/lost_rabbit_yokai_sprite.png", "portrait": "res://assets/characters/bosses/lost_rabbit_yokai_portrait.png", "spell_aura": "res://assets/effects/boss/lost_rabbit_yokai_spell_aura.png"},
	"bamboo_illusionist": {"sprite": "res://assets/characters/bosses/bamboo_illusionist_sprite.png", "portrait": "res://assets/characters/bosses/bamboo_illusionist_portrait.png", "spell_aura": "res://assets/effects/boss/bamboo_illusionist_spell_aura.png"},
	"rookie_crow_tengu": {"sprite": "res://assets/characters/bosses/rookie_crow_tengu_sprite.png", "portrait": "res://assets/characters/bosses/rookie_crow_tengu_portrait.png", "spell_aura": "res://assets/effects/boss/rookie_crow_tengu_spell_aura.png"},
	"mountain_wind_tengu": {"sprite": "res://assets/characters/bosses/mountain_wind_tengu_sprite.png", "portrait": "res://assets/characters/bosses/mountain_wind_tengu_portrait.png", "spell_aura": "res://assets/effects/boss/mountain_wind_tengu_spell_aura.png"},
	"little_oni_drummer": {"sprite": "res://assets/characters/bosses/little_oni_drummer_sprite.png", "portrait": "res://assets/characters/bosses/little_oni_drummer_portrait.png", "spell_aura": "res://assets/effects/boss/little_oni_drummer_spell_aura.png"},
	"banquet_oni_princess": {"sprite": "res://assets/characters/bosses/banquet_oni_princess_sprite.png", "portrait": "res://assets/characters/bosses/banquet_oni_princess_portrait.png", "spell_aura": "res://assets/effects/boss/banquet_oni_princess_spell_aura.png"},
	"festival_fox_miko": {"sprite": "res://assets/characters/bosses/festival_fox_miko_sprite.png", "portrait": "res://assets/characters/bosses/festival_fox_miko_portrait.png", "spell_aura": "res://assets/effects/boss/festival_fox_miko_spell_aura.png"},
	"hyakki_night_festival_god": {"sprite": "res://assets/characters/bosses/hyakki_night_festival_god_sprite.png", "portrait": "res://assets/characters/bosses/hyakki_night_festival_god_portrait.png", "spell_aura": "res://assets/effects/boss/hyakki_night_festival_god_spell_aura.png"},
}

const PHASE6_ENEMY_FAMILY_ASSETS := {
	"enemy_low_yokai": "res://assets/enemies/enemy_low_yokai.png",
	"enemy_fast_attacker": "res://assets/enemies/enemy_fast_attacker.png",
	"enemy_formation_shooter": "res://assets/enemies/enemy_formation_shooter.png",
	"enemy_elite_yokai": "res://assets/enemies/enemy_elite_yokai.png",
	"enemy_mechanism": "res://assets/enemies/enemy_mechanism.png",
	"enemy_lantern_wisp": "res://assets/enemies/enemy_lantern_wisp.png",
	"enemy_market_tool": "res://assets/enemies/enemy_market_tool.png",
	"enemy_festival_spirit": "res://assets/enemies/enemy_festival_spirit.png",
}

const PHASE6_BULLET_FAMILY_ASSETS := {
	"enemy_bullet_lotus_core": "res://assets/effects/bullets/enemy_bullet_lotus_core.png",
	"enemy_bullet_ember_needle": "res://assets/effects/bullets/enemy_bullet_ember_needle.png",
	"enemy_bullet_mirror_drop": "res://assets/effects/bullets/enemy_bullet_mirror_drop.png",
	"enemy_bullet_clock_gear": "res://assets/effects/bullets/enemy_bullet_clock_gear.png",
	"enemy_bullet_storm_arc": "res://assets/effects/bullets/enemy_bullet_storm_arc.png",
	"enemy_bullet_moon_wisp": "res://assets/effects/bullets/enemy_bullet_moon_wisp.png",
	"enemy_bullet_astral_star": "res://assets/effects/bullets/enemy_bullet_astral_star.png",
	"enemy_bullet_warning_ring": "res://assets/effects/bullets/enemy_bullet_warning_ring.png",
	"enemy_bullet_slow_orb": "res://assets/effects/bullets/enemy_bullet_slow_orb.png",
	"enemy_bullet_fast_shard": "res://assets/effects/bullets/enemy_bullet_fast_shard.png",
	"enemy_bullet_spiral_seed": "res://assets/effects/bullets/enemy_bullet_spiral_seed.png",
	"enemy_bullet_boss_sigil": "res://assets/effects/bullets/enemy_bullet_boss_sigil.png",
	"player_bullet_focus_lance": "res://assets/effects/bullets/player_bullet_focus_lance.png",
	"player_bullet_spread_petal": "res://assets/effects/bullets/player_bullet_spread_petal.png",
	"player_bullet_orbit_star": "res://assets/effects/bullets/player_bullet_orbit_star.png",
	"player_bullet_homing_charm": "res://assets/effects/bullets/player_bullet_homing_charm.png",
	"player_bullet_bomb_seed": "res://assets/effects/bullets/player_bullet_bomb_seed.png",
	"player_bullet_graze_spark": "res://assets/effects/bullets/player_bullet_graze_spark.png",
}

const PHASE6_BOMB_ASSETS := {
	"miko": {"start": "res://assets/effects/bombs/miko_start_plate.png", "sustain": "res://assets/effects/bombs/miko_sustain_plate.png", "finish": "res://assets/effects/bombs/miko_finish_plate.png"},
	"magician": {"start": "res://assets/effects/bombs/magician_start_plate.png", "sustain": "res://assets/effects/bombs/magician_sustain_plate.png", "finish": "res://assets/effects/bombs/magician_finish_plate.png"},
	"swordswoman": {"start": "res://assets/effects/bombs/swordswoman_start_plate.png", "sustain": "res://assets/effects/bombs/swordswoman_sustain_plate.png", "finish": "res://assets/effects/bombs/swordswoman_finish_plate.png"},
}

const PHASE6_ITEM_ASSETS := {
	"item_power_small": "res://assets/items/item_power_small.png",
	"item_power_large": "res://assets/items/item_power_large.png",
	"item_score_small": "res://assets/items/item_score_small.png",
	"item_score_large": "res://assets/items/item_score_large.png",
	"item_life_fragment": "res://assets/items/item_life_fragment.png",
	"item_bomb_fragment": "res://assets/items/item_bomb_fragment.png",
	"item_full_power": "res://assets/items/item_full_power.png",
	"item_story_token": "res://assets/items/item_story_token.png",
}

const PHASE6_UI_ASSETS := {
	"title_key_art": "res://assets/ui/title_key_art.png",
	"main_menu_frame": "res://assets/ui/main_menu_frame.png",
	"character_select_frame": "res://assets/ui/character_select_frame.png",
	"pause_panel": "res://assets/ui/pause_panel.png",
	"spell_banner": "res://assets/ui/spell_banner.png",
	"boss_nameplate": "res://assets/ui/boss_nameplate.png",
	"dialogue_panel": "res://assets/ui/dialogue_panel.png",
	"result_frame": "res://assets/ui/result_frame.png",
}

func stage_background_layers(stage_id: Variant) -> Dictionary:
	if typeof(stage_id) == TYPE_INT:
		return PHASE6_STAGE_BACKGROUNDS.get(stage_id, {}).duplicate(true)
	return STAGE_BACKGROUNDS.get(String(stage_id), {}).duplicate(true)

func protagonist_assets(id: String = "") -> Dictionary:
	if id == "":
		return PHASE6_PROTAGONIST_ASSETS.duplicate(true)
	return PROTAGONIST_ASSETS.get(id, PHASE6_PROTAGONIST_ASSETS.get(id, {})).duplicate(true)

func boss_assets(id: String = "") -> Dictionary:
	if id == "":
		return PHASE6_BOSS_ASSETS.duplicate(true)
	return BOSS_ASSETS.get(id, PHASE6_BOSS_ASSETS.get(id, {})).duplicate(true)

func enemy_family_assets() -> Dictionary:
	return PHASE6_ENEMY_FAMILY_ASSETS.duplicate(true)

func bullet_family_assets() -> Dictionary:
	return PHASE6_BULLET_FAMILY_ASSETS.duplicate(true)

func bomb_assets() -> Dictionary:
	return PHASE6_BOMB_ASSETS.duplicate(true)

func item_assets() -> Dictionary:
	return PHASE6_ITEM_ASSETS.duplicate(true)

func ui_assets() -> Dictionary:
	return PHASE6_UI_ASSETS.duplicate(true)

func audio_key(stage_id: String, phase: String) -> String:
	return String(AUDIO_KEYS.get(stage_id, {}).get(phase, ""))
