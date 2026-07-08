# Touhou Architecture Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first production foundation for the Godot danmaku project: 720x960 constants, automated smoke checks, data definitions, asset registry, pooled bullet backend, and performance counters while keeping the current game scene runnable.

**Architecture:** This plan does not build all six stages or final assets. It establishes the data and runtime boundaries that later plans will use: stable game database, asset registry, bullet manager, and performance monitor. Existing gameplay in `scripts/main.gd` remains the playable adapter during this phase.

**Tech Stack:** Godot 4.7, GDScript, Windows PowerShell, PNG atlas-oriented asset paths, Godot headless checks.

## Global Constraints

- Internal viewport is `720x960`.
- Runtime target is Windows PC, stable `60 FPS` on AMD 5800X + RTX 3070 + 64 GB RAM.
- Visual quality target is full hand-painted production grade.
- Asset runtime format is PNG atlases, spritesheets, layered backgrounds, and limited shader effects.
- Theme is original Japanese Touhou-style fantasy; do not use existing Touhou Project characters, names, music, art, or protected assets.
- The workspace is initialized as a local Git repository for implementation checkpoints and task review packages.
- The current main scene must remain runnable after every task: `Godot_v4.7-stable_win64_console.exe --headless --path . --scene res://scenes/main.tscn --quit-after 5`.

---

## File Structure

- Modify `project.godot`: viewport settings and new autoloads.
- Modify `autoload/game_manager.gd`: production constants, stage count, and state helpers.
- Create `autoload/asset_registry.gd`: centralized stable paths for future art/audio assets.
- Create `autoload/performance_monitor.gd`: runtime counters for debug HUD and performance checks.
- Create `scripts/data/game_database.gd`: protagonists, shot types, bombs, stages, bullet families, items, and difficulty metadata.
- Create `scripts/runtime/bullet_manager.gd`: array-backed pooled bullet simulation unit for later integration.
- Modify `scripts/main.gd`: keep existing scene playable while reading updated constants and reporting performance counters.
- Create `tests/assert_viewport_config.gd`: headless assertion for viewport and GameManager constants.
- Create `tests/assert_game_database.gd`: headless assertion for protagonist, stage, bullet, and item data shape.
- Create `tests/assert_asset_registry.gd`: headless assertion for asset registry shape and paths.
- Create `tests/assert_bullet_manager.gd`: headless assertion for pooled bullet spawn, update, clear, and lifetime behavior.
- Create `tests/assert_performance_monitor.gd`: headless assertion for performance counter snapshots.

---

### Task 1: Viewport Constants And Smoke Checks

**Files:**
- Modify: `project.godot`
- Modify: `autoload/game_manager.gd`
- Modify: `scripts/main.gd`
- Create: `tests/assert_viewport_config.gd`

**Interfaces:**
- Produces: `GameManager.SCREEN_W == 720`, `GameManager.SCREEN_H == 960`, `GameManager.playfield_rect() -> Rect2`, `GameManager.stage_count() -> int`.
- Consumes: existing `main.gd` logic and Godot project settings.

- [ ] **Step 1: Write the failing viewport test**

Create `tests/assert_viewport_config.gd`:

```gdscript
extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _init() -> void:
	var width := int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var height := int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	if width != 720:
		_fail("Expected viewport_width 720, got %d" % width)
	if height != 960:
		_fail("Expected viewport_height 960, got %d" % height)

	var gm_script = load("res://autoload/game_manager.gd")
	if gm_script == null:
		_fail("Could not load GameManager script")
	var gm = gm_script.new()
	if gm.SCREEN_W != 720:
		_fail("Expected GameManager.SCREEN_W 720, got %d" % gm.SCREEN_W)
	if gm.SCREEN_H != 960:
		_fail("Expected GameManager.SCREEN_H 960, got %d" % gm.SCREEN_H)
	var rect: Rect2 = gm.playfield_rect()
	if rect.position != Vector2.ZERO:
		_fail("Expected playfield origin Vector2.ZERO, got %s" % [rect.position])
	if rect.size != Vector2(720, 960):
		_fail("Expected playfield size 720x960, got %s" % [rect.size])
	if gm.stage_count() != 6:
		_fail("Expected six configured stage names, got %d" % gm.stage_count())
	quit(0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_viewport_config.gd'
```

Expected: FAIL with a message that the viewport is still `480x640`, `playfield_rect()` is missing, or only three stage names exist.

- [ ] **Step 3: Update project viewport settings**

In `project.godot`, change the display section values to:

```ini
[display]

window/size/viewport_width=720
window/size/viewport_height=960
window/size/window_width_override=720
window/size/window_height_override=960
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
```

- [ ] **Step 4: Update GameManager production constants**

In `autoload/game_manager.gd`, replace the screen constants and stage arrays with:

```gdscript
const SCREEN_W := 720
const SCREEN_H := 960
const MAX_BULLETS := 12000

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

func playfield_rect() -> Rect2:
	return Rect2(0, 0, SCREEN_W, SCREEN_H)

func stage_count() -> int:
	return STAGE_NAMES.size()
```

- [ ] **Step 5: Update main.gd constants and boundary usage**

In `scripts/main.gd`, change the local constants near the top to:

```gdscript
var MAX_BULLETS: int = GameManager.MAX_BULLETS
var SCREEN_W: int = GameManager.SCREEN_W
var SCREEN_H: int = GameManager.SCREEN_H
const PLAYFIELD_MARGIN := 16.0
```

Then update the player clamp in `_update_player` to:

```gdscript
player_x = clampf(player_x, PLAYFIELD_MARGIN, SCREEN_W - PLAYFIELD_MARGIN)
player_y = clampf(player_y, PLAYFIELD_MARGIN, SCREEN_H - PLAYFIELD_MARGIN)
```

Update bullet culling in `_update_bullets` to:

```gdscript
if b.age > b.lifetime or b.x < -60 or b.x > SCREEN_W + 60 or b.y < -60 or b.y > SCREEN_H + 60:
	b.active = false
```

Update enemy horizontal clamp and bottom cull in `_update_enemies` to:

```gdscript
e.x = clampf(e.x, 24, SCREEN_W - 24)
if e.y > SCREEN_H + 40:
	e.alive = false
```

Update the enemy on-screen check to:

```gdscript
var on_screen: bool = e.y >= -2.0 and e.y <= SCREEN_H and e.x >= -2.0 and e.x <= SCREEN_W + 2
```

Update item clamps and bottom cull in `_update_items` to:

```gdscript
it.x = clampf(it.x, 11, SCREEN_W - 11)
if it.y > SCREEN_H + 30:
	it.alive = false
```

Update stage completion logic in `_update_boss` to:

```gdscript
if GameManager.current_stage >= GameManager.stage_count():
	GameManager.state = "final_clear"
	if AudioManager: AudioManager.fade_bgm(-30.0, 1.0)
else:
	GameManager.state = "stage_clear"
	if AudioManager: AudioManager.fade_bgm(-12.0, 0.6)
```

Update the bottom stage-name draw call to use the new height:

```gdscript
draw_string(font, Vector2(10, SCREEN_H - 15), gm.STAGE_NAMES[gm.current_stage - 1])
```

- [ ] **Step 6: Run the viewport test and scene smoke check**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_viewport_config.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --scene 'res://scenes/main.tscn' --quit-after 5
```

Expected: first command exits `0`; second command prints the Godot version and exits `0`.

- [ ] **Step 7: Record checkpoint**

Run:

```powershell
git add project.godot autoload/game_manager.gd scripts/main.gd tests/assert_viewport_config.gd
git commit -m "chore: set production viewport constants"
```

Expected: Git creates a checkpoint commit for Task 1.

---

### Task 2: Production Game Database

**Files:**
- Create: `scripts/data/game_database.gd`
- Create: `tests/assert_game_database.gd`

**Interfaces:**
- Produces: `GameDatabase.protagonists() -> Array`, `GameDatabase.stages() -> Array`, `GameDatabase.bullet_families() -> Array`, `GameDatabase.item_types() -> Array`.
- Consumes: confirmed full-production design.

- [ ] **Step 1: Write the failing game database test**

Create `tests/assert_game_database.gd`:

```gdscript
extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _init() -> void:
	var db_script = load("res://scripts/data/game_database.gd")
	if db_script == null:
		_fail("Could not load game_database.gd")
	var db = db_script.new()

	var protagonists: Array = db.protagonists()
	if protagonists.size() != 3:
		_fail("Expected 3 protagonists, got %d" % protagonists.size())
	for p in protagonists:
		if not p.has("id") or not p.has("display_name") or not p.has("shot_types") or not p.has("bomb"):
			_fail("Protagonist entry missing required keys: %s" % [p])
		if p.shot_types.size() != 2:
			_fail("Protagonist %s must have exactly 2 shot types" % p.id)

	var stages: Array = db.stages()
	if stages.size() != 6:
		_fail("Expected 6 stages, got %d" % stages.size())
	for i in range(stages.size()):
		var s: Dictionary = stages[i]
		if int(s.index) != i + 1:
			_fail("Stage index mismatch at entry %d: %s" % [i, s])
		for key in ["id", "display_name", "midboss_id", "boss_id", "theme"]:
			if not s.has(key):
				_fail("Stage %d missing %s" % [i + 1, key])

	var bullet_families: Array = db.bullet_families()
	if bullet_families.size() != 8:
		_fail("Expected 8 enemy bullet families, got %d" % bullet_families.size())

	var item_types: Array = db.item_types()
	if item_types.size() != 6:
		_fail("Expected 6 item types, got %d" % item_types.size())

	quit(0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_game_database.gd'
```

Expected: FAIL because `scripts/data/game_database.gd` does not exist.

- [ ] **Step 3: Implement GameDatabase**

Create `scripts/data/game_database.gd`:

```gdscript
extends RefCounted
class_name GameDatabase

const PROTAGONISTS := [
	{
		"id": "miko",
		"display_name": "结界巫女",
		"role": "均衡、诱导、结界清场",
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
		"role": "高火力、直线、资源爆发",
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
		"role": "机动、近中距离、高风险回报",
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
	{"id": "bomb_fragment", "display_name": "Bomb碎片", "role": "three_make_bomb"},
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
```

- [ ] **Step 4: Run the data test and scene smoke check**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_game_database.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --scene 'res://scenes/main.tscn' --quit-after 5
```

Expected: both commands exit `0`.

- [ ] **Step 5: Record checkpoint**

Run:

```powershell
git add scripts/data/game_database.gd tests/assert_game_database.gd
git commit -m "feat: add production game database"
```

Expected: Git creates a checkpoint commit for Task 2.

---

### Task 3: Asset Registry Autoload

**Files:**
- Create: `autoload/asset_registry.gd`
- Modify: `project.godot`
- Create: `tests/assert_asset_registry.gd`

**Interfaces:**
- Produces: autoload singleton `AssetRegistry`; functions `stage_background_layers(stage_id: String) -> Dictionary`, `protagonist_assets(id: String) -> Dictionary`, `boss_assets(id: String) -> Dictionary`, `audio_key(stage_id: String, phase: String) -> String`.
- Consumes: stable ids from `GameDatabase`.

- [ ] **Step 1: Write the failing asset registry test**

Create `tests/assert_asset_registry.gd`:

```gdscript
extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _path_ok(path_value: String) -> bool:
	return path_value.begins_with("res://")

func _init() -> void:
	var registry_script = load("res://autoload/asset_registry.gd")
	if registry_script == null:
		_fail("Could not load asset_registry.gd")
	var registry = registry_script.new()

	var shrine_layers: Dictionary = registry.stage_background_layers("shrine_approach")
	for key in ["far", "mid", "front", "atmosphere"]:
		if not shrine_layers.has(key):
			_fail("shrine_approach missing background layer %s" % key)
		if not _path_ok(String(shrine_layers[key])):
			_fail("Layer %s path must start with res://, got %s" % [key, shrine_layers[key]])

	var miko_assets: Dictionary = registry.protagonist_assets("miko")
	for key in ["portrait", "sprite", "shot_atlas", "bomb_atlas", "ending"]:
		if not miko_assets.has(key):
			_fail("miko assets missing %s" % key)
		if not _path_ok(String(miko_assets[key])):
			_fail("miko asset %s must start with res://, got %s" % [key, miko_assets[key]])

	var boss_assets: Dictionary = registry.boss_assets("hyakki_night_festival_god")
	for key in ["portrait", "sprite", "spell_background"]:
		if not boss_assets.has(key):
			_fail("final boss assets missing %s" % key)

	if registry.audio_key("shrine_approach", "stage") != "stage1_mid":
		_fail("Expected shrine_approach stage audio key stage1_mid")
	if registry.audio_key("night_festival_divine_realm", "boss") != "stage6_boss":
		_fail("Expected final boss audio key stage6_boss")

	quit(0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_asset_registry.gd'
```

Expected: FAIL because `autoload/asset_registry.gd` does not exist.

- [ ] **Step 3: Implement AssetRegistry**

Create `autoload/asset_registry.gd`:

```gdscript
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
```

- [ ] **Step 4: Register the autoload**

In `project.godot`, update `[autoload]` to include:

```ini
[autoload]

GameManager="*res://autoload/game_manager.gd"
AudioManager="*res://autoload/audio_manager.gd"
AssetRegistry="*res://autoload/asset_registry.gd"
```

- [ ] **Step 5: Run the registry test and scene smoke check**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_asset_registry.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --scene 'res://scenes/main.tscn' --quit-after 5
```

Expected: both commands exit `0`.

- [ ] **Step 6: Record checkpoint**

Run:

```powershell
git add project.godot autoload/asset_registry.gd tests/assert_asset_registry.gd
git commit -m "feat: add asset registry"
```

Expected: Git creates a checkpoint commit for Task 3.

---

### Task 4: Array-Backed Bullet Manager

**Files:**
- Create: `scripts/runtime/bullet_manager.gd`
- Create: `tests/assert_bullet_manager.gd`

**Interfaces:**
- Produces: `BulletManager.configure(capacity: int)`, `spawn(owner: int, kind: int, position: Vector2, velocity: Vector2, radius: float, lifetime: float, damage: float, color_index: int) -> int`, `update(delta_frames: float)`, `clear_owner(owner: int)`, `count_active() -> int`, `snapshot_active_indices() -> Array`.
- Consumes: no scene nodes; pure data runtime unit.

- [ ] **Step 1: Write the failing bullet manager test**

Create `tests/assert_bullet_manager.gd`:

```gdscript
extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _init() -> void:
	var manager_script = load("res://scripts/runtime/bullet_manager.gd")
	if manager_script == null:
		_fail("Could not load bullet_manager.gd")
	var manager = manager_script.new()
	manager.configure(4)
	if manager.count_active() != 0:
		_fail("Fresh pool must have zero active bullets")

	var first: int = manager.spawn(manager.OWNER_ENEMY, manager.KIND_CIRCLE, Vector2(10, 20), Vector2(2, 3), 5.0, 10.0, 1.0, 2)
	if first != 0:
		_fail("Expected first spawn index 0, got %d" % first)
	if manager.count_active() != 1:
		_fail("Expected one active bullet after spawn")

	manager.update(2.0)
	if abs(manager.x[first] - 14.0) > 0.001:
		_fail("Expected x 14 after update, got %f" % manager.x[first])
	if abs(manager.y[first] - 26.0) > 0.001:
		_fail("Expected y 26 after update, got %f" % manager.y[first])

	manager.update(9.0)
	if manager.count_active() != 0:
		_fail("Bullet should expire after lifetime")

	manager.spawn(manager.OWNER_PLAYER, manager.KIND_PLAYER, Vector2.ZERO, Vector2(0, -5), 4.0, 20.0, 2.0, 1)
	manager.spawn(manager.OWNER_ENEMY, manager.KIND_RICE, Vector2.ONE, Vector2(0, 5), 4.0, 20.0, 1.0, 3)
	manager.clear_owner(manager.OWNER_ENEMY)
	if manager.count_active() != 1:
		_fail("clear_owner(OWNER_ENEMY) should leave one player bullet active")
	manager.clear()
	if manager.count_active() != 0:
		_fail("clear should deactivate every bullet")

	quit(0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_bullet_manager.gd'
```

Expected: FAIL because `scripts/runtime/bullet_manager.gd` does not exist.

- [ ] **Step 3: Implement BulletManager**

Create `scripts/runtime/bullet_manager.gd`:

```gdscript
extends RefCounted
class_name BulletManager

const OWNER_PLAYER := 0
const OWNER_ENEMY := 1

const KIND_PLAYER := 0
const KIND_CIRCLE := 1
const KIND_RICE := 2
const KIND_BUTTERFLY := 3
const KIND_NEEDLE := 4
const KIND_TALISMAN := 5
const KIND_STAR := 6
const KIND_LASER := 7
const KIND_LARGE_ORB := 8

var capacity: int = 0
var active := PackedByteArray()
var owner := PackedInt32Array()
var kind := PackedInt32Array()
var color_index := PackedInt32Array()
var x := PackedFloat32Array()
var y := PackedFloat32Array()
var vx := PackedFloat32Array()
var vy := PackedFloat32Array()
var radius := PackedFloat32Array()
var lifetime := PackedFloat32Array()
var age := PackedFloat32Array()
var damage := PackedFloat32Array()
var _active_count: int = 0
var _cursor: int = 0

func configure(new_capacity: int) -> void:
	capacity = max(0, new_capacity)
	active.resize(capacity)
	owner.resize(capacity)
	kind.resize(capacity)
	color_index.resize(capacity)
	x.resize(capacity)
	y.resize(capacity)
	vx.resize(capacity)
	vy.resize(capacity)
	radius.resize(capacity)
	lifetime.resize(capacity)
	age.resize(capacity)
	damage.resize(capacity)
	clear()

func clear() -> void:
	for i in range(capacity):
		active[i] = 0
		owner[i] = OWNER_ENEMY
		kind[i] = KIND_CIRCLE
		color_index[i] = 0
		x[i] = 0.0
		y[i] = 0.0
		vx[i] = 0.0
		vy[i] = 0.0
		radius[i] = 0.0
		lifetime[i] = 0.0
		age[i] = 0.0
		damage[i] = 0.0
	_active_count = 0
	_cursor = 0

func spawn(new_owner: int, new_kind: int, position: Vector2, velocity: Vector2, new_radius: float, new_lifetime: float, new_damage: float, new_color_index: int) -> int:
	if capacity <= 0:
		return -1
	for offset in range(capacity):
		var idx := (_cursor + offset) % capacity
		if active[idx] == 0:
			active[idx] = 1
			owner[idx] = new_owner
			kind[idx] = new_kind
			color_index[idx] = new_color_index
			x[idx] = position.x
			y[idx] = position.y
			vx[idx] = velocity.x
			vy[idx] = velocity.y
			radius[idx] = new_radius
			lifetime[idx] = new_lifetime
			age[idx] = 0.0
			damage[idx] = new_damage
			_active_count += 1
			_cursor = (idx + 1) % capacity
			return idx
	return -1

func update(delta_frames: float) -> void:
	for i in range(capacity):
		if active[i] == 0:
			continue
		x[i] += vx[i] * delta_frames
		y[i] += vy[i] * delta_frames
		age[i] += delta_frames
		if age[i] > lifetime[i]:
			active[i] = 0
			_active_count -= 1

func clear_owner(target_owner: int) -> void:
	for i in range(capacity):
		if active[i] == 1 and owner[i] == target_owner:
			active[i] = 0
			_active_count -= 1

func count_active() -> int:
	return _active_count

func snapshot_active_indices() -> Array:
	var out: Array = []
	for i in range(capacity):
		if active[i] == 1:
			out.append(i)
	return out
```

- [ ] **Step 4: Run the bullet manager test and scene smoke check**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_bullet_manager.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --scene 'res://scenes/main.tscn' --quit-after 5
```

Expected: both commands exit `0`.

- [ ] **Step 5: Record checkpoint**

Run:

```powershell
git add scripts/runtime/bullet_manager.gd tests/assert_bullet_manager.gd
git commit -m "feat: add pooled bullet manager"
```

Expected: Git creates a checkpoint commit for Task 4.

---

### Task 5: Performance Monitor Autoload

**Files:**
- Create: `autoload/performance_monitor.gd`
- Modify: `project.godot`
- Modify: `scripts/main.gd`
- Create: `tests/assert_performance_monitor.gd`

**Interfaces:**
- Produces: autoload singleton `PerformanceMonitor`; functions `set_counter(name: String, value: int)`, `increment(name: String, amount: int = 1)`, `snapshot() -> Dictionary`, `reset_frame()`.
- Consumes: existing `main.gd` arrays and bullet pool.

- [ ] **Step 1: Write the failing performance monitor test**

Create `tests/assert_performance_monitor.gd`:

```gdscript
extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _init() -> void:
	var monitor_script = load("res://autoload/performance_monitor.gd")
	if monitor_script == null:
		_fail("Could not load performance_monitor.gd")
	var monitor = monitor_script.new()
	monitor.set_counter("enemy_bullets", 12)
	monitor.increment("enemy_bullets", 3)
	monitor.set_counter("fps", 60)
	var snap: Dictionary = monitor.snapshot()
	if int(snap.enemy_bullets) != 15:
		_fail("Expected enemy_bullets 15, got %s" % [snap.enemy_bullets])
	if int(snap.fps) != 60:
		_fail("Expected fps 60, got %s" % [snap.fps])
	monitor.reset_frame()
	var reset_snap: Dictionary = monitor.snapshot()
	if int(reset_snap.enemy_bullets) != 0:
		_fail("Expected enemy_bullets reset to 0")
	if int(reset_snap.fps) != 0:
		_fail("Expected fps reset to 0")
	quit(0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_performance_monitor.gd'
```

Expected: FAIL because `autoload/performance_monitor.gd` does not exist.

- [ ] **Step 3: Implement PerformanceMonitor**

Create `autoload/performance_monitor.gd`:

```gdscript
extends Node

var counters: Dictionary = {}

func set_counter(name: String, value: int) -> void:
	counters[name] = value

func increment(name: String, amount: int = 1) -> void:
	counters[name] = int(counters.get(name, 0)) + amount

func snapshot() -> Dictionary:
	return counters.duplicate(true)

func reset_frame() -> void:
	counters.clear()
```

- [ ] **Step 4: Register the autoload**

In `project.godot`, update `[autoload]` to include:

```ini
[autoload]

GameManager="*res://autoload/game_manager.gd"
AudioManager="*res://autoload/audio_manager.gd"
AssetRegistry="*res://autoload/asset_registry.gd"
PerformanceMonitor="*res://autoload/performance_monitor.gd"
```

- [ ] **Step 5: Report runtime counters from main.gd**

Add this helper to `scripts/main.gd` after `_count_alive_enemies()`:

```gdscript
func _count_active_bullets_by_owner() -> Dictionary:
	var player_count: int = 0
	var enemy_count: int = 0
	for b in bullet_pool:
		if not b.active:
			continue
		if b.type == "player" or b.type == "bomb":
			player_count += 1
		elif b.type in ["circle", "rice", "arrow", "laser"]:
			enemy_count += 1
	return {"player": player_count, "enemy": enemy_count}

func _update_performance_counters() -> void:
	if not has_node("/root/PerformanceMonitor"):
		return
	var counts: Dictionary = _count_active_bullets_by_owner()
	PerformanceMonitor.reset_frame()
	PerformanceMonitor.set_counter("fps", int(Engine.get_frames_per_second()))
	PerformanceMonitor.set_counter("player_bullets", int(counts.player))
	PerformanceMonitor.set_counter("enemy_bullets", int(counts.enemy))
	PerformanceMonitor.set_counter("enemies", _count_alive_enemies())
	PerformanceMonitor.set_counter("items", items.size())
	PerformanceMonitor.set_counter("boss_alive", 1 if boss_alive else 0)
```

At the end of `_process(delta)`, before `queue_redraw()`, call:

```gdscript
_update_performance_counters()
queue_redraw()
```

- [ ] **Step 6: Run the monitor test and scene smoke check**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_performance_monitor.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --scene 'res://scenes/main.tscn' --quit-after 5
```

Expected: both commands exit `0`.

- [ ] **Step 7: Record checkpoint**

Run:

```powershell
git add project.godot autoload/performance_monitor.gd scripts/main.gd tests/assert_performance_monitor.gd
git commit -m "feat: add performance monitor"
```

Expected: Git creates a checkpoint commit for Task 5.

---

### Task 6: Foundation Verification Batch

**Files:**
- Modify only if previous tasks left script parse errors.

**Interfaces:**
- Consumes: all tests from Tasks 1-5.
- Produces: a repeatable verification command group for future implementation plans.

- [ ] **Step 1: Run every foundation assertion**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_viewport_config.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_game_database.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_asset_registry.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_bullet_manager.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_performance_monitor.gd'
```

Expected: all five commands exit `0`.

- [ ] **Step 2: Run the main scene smoke check**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --scene 'res://scenes/main.tscn' --quit-after 5
```

Expected: command exits `0` and prints the Godot version.

- [ ] **Step 3: Record final foundation checkpoint**

Run:

```powershell
git status --short
git add project.godot autoload scripts tests
git commit -m "feat: establish touhou production foundation"
if ($LASTEXITCODE -ne 0) {
	Write-Host "No final commit needed; previous task commits are current."
}
```

Expected: Git creates a final checkpoint commit when there are remaining staged changes, or prints that no final commit is needed.

---

## Self-Review Checklist

- Spec coverage: this plan covers the first implementation slice from the design document: architecture and performance foundation, viewport, data definitions, asset registry, pooled bullet backend, and performance counters.
- Excluded design scope: protagonist gameplay implementation, full UI shell, six-stage wave content, final art generation, and music expansion are intentionally separate plans because the approved design contains multiple independent subsystems.
- Type consistency: all produced interfaces use exact names referenced by subsequent tasks: `GameDatabase`, `AssetRegistry`, `BulletManager`, and `PerformanceMonitor`.
- Verification: each task includes a failing assertion, implementation target, passing assertion, scene smoke check, and conditional checkpoint command.
