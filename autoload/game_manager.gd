extends Node

# Global game state and constants, accessible everywhere

const SCREEN_W := 720
const SCREEN_H := 960
const MAX_BULLETS := 12000

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
	"绁炵ぞ鍙傞亾",
	"濡栨€競闆?",
	"杩烽浘绔规灄",
	"澶╃嫍灞遍亾",
	"楝间箣瀹村巺",
	"澶滅キ绁炲煙",
]
const STAGE_MULTS := [
	{"enemy_hp":1.0, "boss_hp":1.0, "bullet_speed":1.0},
	{"enemy_hp":1.25, "boss_hp":1.18, "bullet_speed":1.08},
	{"enemy_hp":1.5, "boss_hp":1.36, "bullet_speed":1.16},
	{"enemy_hp":1.8, "boss_hp":1.58, "bullet_speed":1.25},
	{"enemy_hp":2.15, "boss_hp":1.85, "bullet_speed":1.34},
	{"enemy_hp":2.55, "boss_hp":2.15, "bullet_speed":1.45},
]

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
var current_stage: int = 1
var state: String = "title"  # title, stage, boss, stage_clear, final_clear, game_over, paused

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

func reset():
	score = 0; graze = 0; shared_power = 0
	bullet_type = BulletType.SPREAD
	lives = PLAYER_INITIAL_LIVES; bombs = PLAYER_INITIAL_BOMBS
	current_stage = 1; state = "title"
