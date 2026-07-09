extends Node

# Global game state and constants, accessible everywhere

const SCREEN_W := 720
const SCREEN_H := 960
const MAX_BULLETS := 12000

const STATE_TITLE := "title"
const STATE_CHARACTER_SELECT := "character_select"
const STATE_SHOT_SELECT := "shot_select"
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
	{"enemy_hp":1.25, "boss_hp":1.18, "bullet_speed":1.08},
	{"enemy_hp":1.5, "boss_hp":1.36, "bullet_speed":1.16},
	{"enemy_hp":1.8, "boss_hp":1.58, "bullet_speed":1.25},
	{"enemy_hp":2.15, "boss_hp":1.85, "bullet_speed":1.34},
	{"enemy_hp":2.55, "boss_hp":2.15, "bullet_speed":1.45},
]

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
var current_stage: int = 1
var state: String = STATE_TITLE
var selected_protagonist_id: String = DEFAULT_PROTAGONIST_ID
var selected_shot_id: String = DEFAULT_SHOT_ID
var practice_mode: bool = false
var pause_return_state: String = STATE_STAGE
var settings_return_state: String = STATE_TITLE
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var _database = load("res://scripts/data/game_database.gd").new()

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
	pause_return_state = STATE_STAGE
	settings_return_state = STATE_TITLE

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
	current_stage = 1; state = STATE_TITLE
