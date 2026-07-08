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

func stage_background_layers(stage_id: String) -> Dictionary:
	return STAGE_BACKGROUNDS.get(stage_id, {}).duplicate(true)

func protagonist_assets(id: String) -> Dictionary:
	return PROTAGONIST_ASSETS.get(id, {}).duplicate(true)

func boss_assets(id: String) -> Dictionary:
	return BOSS_ASSETS.get(id, {}).duplicate(true)

func audio_key(stage_id: String, phase: String) -> String:
	return String(AUDIO_KEYS.get(stage_id, {}).get(phase, ""))
