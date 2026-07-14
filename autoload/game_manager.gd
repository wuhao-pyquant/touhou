extends Node

# Global game state and constants, accessible everywhere

const SCREEN_W := 720
const SCREEN_H := 960
const MAX_BULLETS := 12000

const STATE_TITLE := "title"
const STATE_CHARACTER_SELECT := "character_select"
const STATE_SHOT_SELECT := "shot_select"
const STATE_PRACTICE_SELECT := "practice_select"
const STATE_SETTINGS := "settings"
const STATE_PAUSED := "paused"
const STATE_STAGE := "stage"
const STATE_BOSS := "boss"
const STATE_STAGE_CLEAR := "stage_clear"
const STATE_FINAL_CLEAR := "final_clear"
const STATE_GAME_OVER := "game_over"

# Player
const PLAYER_SPEED_HIGH := 5.5
const PLAYER_SPEED_LOW := 2.2
const PLAYER_HITBOX := 2.0
const PLAYER_GRAZE := 10.0
const PLAYER_FIRE_INTERVAL := 3
const PLAYER_INITIAL_LIVES := 3
const PLAYER_INITIAL_BOMBS := 3
const DEATHBOMB_WINDOW := 9
const INVINCIBLE_DURATION := 180
const DEATH_POWER_DROP := 0.1
const ITEM_TOP_RATIO := 0.2

# Bullet types
enum BulletType { SPREAD, LINEAR, HOMING }
const BULLET_NAMES := ["Spread", "Pierce", "Seeker"]
const BULLET_COLORS := [
	Color(0.71, 0.31, 1.0),   # purple
	Color(1.0, 0.31, 0.31),   # red
	Color(0.31, 1.0, 0.47),   # green
]
const BULLET_DMG := [2.1, 6.0, 1.5]
const POWER_THRESHOLDS := [1, 5, 15, 30, 50]

# Bomb configs per bullet type
const BOMB_CONFIG := [
	{"radius":180, "dmg":0.8, "duration":140, "waves":8, "bullets":42, "speed":4.5, "color":Color(0.78,0.39,1.0)},
	{"radius":100, "dmg":2.0, "duration":80,  "waves":4, "bullets":16, "speed":7.0, "color":Color(1.0,0.31,0.31)},
	{"radius":140, "dmg":0.6, "duration":200, "waves":6, "bullets":24, "speed":3.5, "color":Color(0.31,1.0,0.55)},
]

# Stages
const STAGE_NAMES := [
	"神社参道",
	"妖怪市集",
	"迷雾竹林",
	"天狗山道",
	"鬼之宴厅",
	"夜祭神域",
]
const STAGE_MULTS := [
	{"enemy_hp":1.0, "boss_hp":1.0, "bullet_speed":1.0},
	{"enemy_hp":1.05, "boss_hp":1.0, "bullet_speed":1.05},
	{"enemy_hp":1.10, "boss_hp":1.0, "bullet_speed":1.10},
	{"enemy_hp":1.15, "boss_hp":1.0, "bullet_speed":1.16},
	{"enemy_hp":1.20, "boss_hp":1.0, "bullet_speed":1.22},
	{"enemy_hp":1.25, "boss_hp":1.0, "bullet_speed":1.28},
]
const BOSS_HP_PER_SECOND := [42.0, 46.0, 50.0, 54.0, 58.0, 62.0]

const DEFAULT_PROTAGONIST_ID := "miko"
const DEFAULT_SHOT_ID := "ofuda_trace"
const DEFAULT_SETTINGS := {
	"master_volume": 1.0,
	"bgm_volume": 0.8,
	"sfx_volume": 0.8,
	"fullscreen": false,
	"bullet_brightness": 1.0,
	"always_show_focus_hitbox": false,
	"show_performance_hud": false,
	"show_input_guide": true,
}

func playfield_rect() -> Rect2:
	return Rect2(0, 0, SCREEN_W, SCREEN_H)

func stage_count() -> int:
	return STAGE_NAMES.size()

func balanced_boss_card_hp(stage: int, time_seconds: float, kind: String) -> float:
	var index := clampi(stage - 1, 0, BOSS_HP_PER_SECOND.size() - 1)
	var kind_multiplier := 0.88 if kind == "nonspell" else 1.0
	return maxf(1.0, time_seconds * BOSS_HP_PER_SECOND[index] * kind_multiplier)

# --- Runtime state ---
var score: int = 0
var graze: int = 0
var shared_power: int = 0
var bullet_type: int = BulletType.SPREAD
var lives: int = PLAYER_INITIAL_LIVES
var bombs: int = PLAYER_INITIAL_BOMBS
var life_fragments: int = 0
var bomb_fragments: int = 0
var night_festival_seals: int = 0
var night_festival_multiplier: float = 1.0
var highest_night_festival_multiplier: float = 1.0
var spell_capture_active: bool = false
var spell_capture_invalidated: bool = false
var spell_capture_invalid_reason: String = ""
var spell_capture_card_id: String = ""
var spell_capture_base_value: int = 0
var spell_capture_total_frames: float = 1.0
var last_capture_result: Dictionary = {}
var run_spell_attempts: int = 0
var run_spell_captures: int = 0
var continues_used: int = 0
var current_stage: int = 1
var state: String = STATE_TITLE
var selected_protagonist_id: String = DEFAULT_PROTAGONIST_ID
var selected_shot_id: String = DEFAULT_SHOT_ID
var practice_mode: bool = false
var practice_stage: int = 1
var highest_reached_stage: int = 1
var pause_return_state: String = STATE_STAGE
var settings_return_state: String = STATE_TITLE
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var _database = load("res://scripts/data/game_database.gd").new()
var _score_system = load("res://scripts/runtime/gameplay_score_system.gd").new()

func power_level() -> int:
	for i in range(POWER_THRESHOLDS.size()):
		if shared_power < POWER_THRESHOLDS[i]:
			return i
	return 5

func add_power(amount: int = 1):
	var old: int = power_level()
	shared_power = min(50, shared_power + amount)
	return power_level() > old

func switch_bullet_type(bt: int):
	bullet_type = clampi(bt, 0, 2)

func protagonist_profile() -> Dictionary:
	var profile: Dictionary = _database.protagonist_by_id(selected_protagonist_id)
	if profile.is_empty():
		return _database.protagonist_by_id(DEFAULT_PROTAGONIST_ID)
	return profile

func selected_shot_profile() -> Dictionary:
	var profile: Dictionary = _database.shot_profile_by_id(selected_shot_id)
	if profile.is_empty():
		return _database.shot_profile_by_id(DEFAULT_SHOT_ID)
	return profile

func selected_bomb_profile() -> Dictionary:
	var profile: Dictionary = _database.bomb_profile_for_protagonist(selected_protagonist_id)
	if profile.is_empty():
		return _database.bomb_profile_for_protagonist(DEFAULT_PROTAGONIST_ID)
	return profile

func selected_speed_high() -> float:
	return float(protagonist_profile().get("speed_high", PLAYER_SPEED_HIGH))

func selected_speed_low() -> float:
	return float(protagonist_profile().get("speed_low", PLAYER_SPEED_LOW))

func selected_hitbox_radius() -> float:
	return float(protagonist_profile().get("hitbox", PLAYER_HITBOX))

func selected_graze_radius() -> float:
	return float(protagonist_profile().get("graze_radius", PLAYER_GRAZE))

func selected_fire_interval_frames() -> int:
	return int(selected_shot_profile().get("fire_interval_frames", PLAYER_FIRE_INTERVAL))

func apply_selected_shot() -> void:
	var bullet_type_name := String(selected_shot_profile().get("bullet_type", "spread"))
	match bullet_type_name:
		"linear":
			bullet_type = BulletType.LINEAR
		"homing":
			bullet_type = BulletType.HOMING
		_:
			bullet_type = BulletType.SPREAD

func reset_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)

func reset_run_config() -> void:
	selected_protagonist_id = DEFAULT_PROTAGONIST_ID
	selected_shot_id = DEFAULT_SHOT_ID
	practice_mode = false
	practice_stage = 1
	pause_return_state = STATE_STAGE
	settings_return_state = STATE_TITLE

func unlock_stage(stage: int) -> void:
	highest_reached_stage = maxi(highest_reached_stage, clampi(stage, 1, stage_count()))

func add_night_festival_seal() -> float:
	return _score_system.apply_night_festival_seal(self)

func begin_spell_capture(card_id: String, base_value: int, total_frames: float) -> void:
	_score_system.begin_spell(self, card_id, base_value, total_frames)

func invalidate_spell_capture(reason: String) -> void:
	_score_system.invalidate_spell(self, reason)

func record_bomb_used() -> void:
	_score_system.record_bomb(self)

func record_actual_miss() -> void:
	_score_system.record_actual_miss(self)

func finish_spell_capture(remaining_frames: float, timed_out: bool = false) -> Dictionary:
	return _score_system.finish_spell(self, remaining_frames, timed_out)

func record_continue() -> void:
	continues_used += 1

func clear_classification() -> String:
	return "practice" if practice_mode else ("1cc" if continues_used == 0 else "continued")

func enter_pause(from_state: String) -> void:
	pause_return_state = from_state
	state = STATE_PAUSED

func resume_from_pause() -> void:
	state = pause_return_state if pause_return_state != "" else STATE_STAGE

func open_settings(return_state: String) -> void:
	settings_return_state = return_state
	state = STATE_SETTINGS

func reset():
	reset_settings()
	reset_run_config()
	score = 0; graze = 0; shared_power = 0
	bullet_type = BulletType.SPREAD
	lives = PLAYER_INITIAL_LIVES; bombs = PLAYER_INITIAL_BOMBS
	life_fragments = 0; bomb_fragments = 0
	night_festival_seals = 0
	night_festival_multiplier = 1.0
	highest_night_festival_multiplier = 1.0
	spell_capture_active = false; spell_capture_invalidated = false
	spell_capture_invalid_reason = ""; spell_capture_card_id = ""
	spell_capture_base_value = 0; spell_capture_total_frames = 1.0
	last_capture_result = {}; run_spell_attempts = 0; run_spell_captures = 0
	continues_used = 0
	current_stage = 1; state = STATE_TITLE
