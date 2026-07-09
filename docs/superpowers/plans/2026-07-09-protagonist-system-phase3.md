# Protagonist System Phase 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the original production plan's third milestone: three playable protagonists, six fixed shot types, and three protagonist-specific bombs that affect actual gameplay.

**Architecture:** Keep Phase 3 focused on player loadout behavior, not art generation or enemy/stage expansion. Extend the existing data dictionaries into stable runtime profiles, add small player shot and bomb executor scripts, then adapt `scripts/main.gd` to consume the selected protagonist/shot/bomb profiles. Preserve the current single-scene playable loop while moving player-specific logic out of ad hoc `bullet_type` branches.

**Tech Stack:** Godot 4.7 GDScript, headless SceneTree tests under `tests/`, existing autoloads (`GameManager`, `AudioManager`, `AssetRegistry`, `PerformanceMonitor`).

## Global Constraints

- Original total spec file: `docs/superpowers/specs/2026-07-09-touhou-full-production-design.md`.
- This is phase 3 only: `Protagonist system with three characters, six shot types, and three bombs`.
- Do not generate or import the full hand-painted art asset library in this phase; that remains phase 6 in the approved total specification.
- Do not add existing Touhou Project characters, music, names, or art.
- Preserve 720x960 viewport behavior.
- Preserve Phase 2 UI shell, settings, pause, restart-stage, and title/character/shot flow.
- Shot type is selected before a run and remains fixed during the run.
- Weapon-switch item drops are removed from core gameplay; drops should be standard resources.
- Each protagonist has exactly two shot types and one dedicated bomb.
- Character/shot selection should display speed, shot coverage, focused damage, bomb behavior, and difficulty hints.
- Runtime gameplay must use selected protagonist speed, selected shot behavior, and selected bomb behavior.

---

## File Structure

- `scripts/data/game_database.gd`: source of truth for protagonist, shot, and bomb runtime profile data.
- `autoload/game_manager.gd`: selected loadout state and helpers that expose the active protagonist, shot, bomb, speed, hitbox, graze, and fire interval.
- `scripts/ui/ui_model.gd`: menu-facing projection of protagonist and shot profile details.
- `scripts/player/player_shot_executor.gd`: pure helper that converts a shot profile, power level, focus state, and origin into player bullet spawn specs.
- `scripts/player/player_bomb_executor.gd`: pure helper that converts a bomb profile and runtime state into bomb bullet specs and enemy-bullet clear rules.
- `scripts/main.gd`: gameplay integration only: movement speed, shooting, bomb start/update, HUD labels, and fixed-loadout item handling.
- `tests/assert_phase3_protagonist_profiles.gd`: profile data and `GameManager` helper contract.
- `tests/assert_phase3_shot_patterns.gd`: six-shot executor and main-scene shooting contract.
- `tests/assert_phase3_bomb_contract.gd`: three-bomb executor and main-scene bomb contract.
- `tests/assert_phase3_ui_loadout_contract.gd`: fixed loadout, UI detail, HUD label, and no weapon-switch drop contract.

---

### Task 1: Runtime Loadout Profiles

**Files:**
- Create: `tests/assert_phase3_protagonist_profiles.gd`
- Modify: `scripts/data/game_database.gd`
- Modify: `autoload/game_manager.gd`
- Modify: `scripts/ui/ui_model.gd`

**Interfaces:**
- Consumes: existing `GameDatabase.protagonists()`, `GameDatabase.protagonist_by_id(id)`, `UiModel.protagonist_entries()`, `UiModel.shot_entries(protagonist_id)`.
- Produces:
  - `GameDatabase.shot_profile_by_id(shot_id: String) -> Dictionary`
  - `GameDatabase.bomb_profile_for_protagonist(protagonist_id: String) -> Dictionary`
  - `GameManager.protagonist_profile() -> Dictionary`
  - `GameManager.selected_shot_profile() -> Dictionary`
  - `GameManager.selected_bomb_profile() -> Dictionary`
  - `GameManager.selected_speed_high() -> float`
  - `GameManager.selected_speed_low() -> float`
  - `GameManager.selected_hitbox_radius() -> float`
  - `GameManager.selected_graze_radius() -> float`
  - `GameManager.selected_fire_interval_frames() -> int`
  - `GameManager.apply_selected_shot() -> void`
  - `UiModel.protagonist_entries()` entries include `detail_lines: Array[String]`.
  - `UiModel.shot_entries(protagonist_id)` entries include `detail_lines: Array[String]`.

- [ ] **Step 1: Write the failing profile contract test**

Create `tests/assert_phase3_protagonist_profiles.gd` with this structure:

```gdscript
extends SceneTree

var failed := false

func _fail(message: String) -> void:
	if failed:
		return
	failed = true
	push_error(message)
	quit(1)

func _assert(condition: bool, message: String) -> bool:
	if not condition:
		_fail(message)
		return false
	return true

func _assert_equal(actual, expected, message: String) -> bool:
	if actual != expected:
		_fail("%s Expected %s, got %s" % [message, expected, actual])
		return false
	return true

func _assert_has_keys(value: Dictionary, keys: Array, context: String) -> void:
	for key in keys:
		_assert(value.has(key), "%s missing %s: %s" % [context, key, value])

func _ids(entries: Array) -> Array:
	var result: Array = []
	for entry in entries:
		result.append(String(entry.get("id", "")))
	return result

func _verify_database_profiles() -> void:
	var db_script = load("res://scripts/data/game_database.gd")
	if not _assert(db_script != null, "Could not load game_database.gd"):
		return
	var db = db_script.new()
	var protagonists: Array = db.protagonists()
	_assert_equal(_ids(protagonists), ["miko", "magician", "swordswoman"], "Protagonist ids mismatch.")
	var expected_shots := {
		"miko": ["ofuda_trace", "yin_yang_focus"],
		"magician": ["stardust_spread", "magic_laser"],
		"swordswoman": ["sword_wave_fan", "returning_spirit_blades"],
	}
	var expected_bombs := {
		"miko": "great_boundary_bloom",
		"magician": "festival_master_spark",
		"swordswoman": "instant_slash_boundary",
	}
	var seen_shots: Dictionary = {}
	for protagonist in protagonists:
		var pid := String(protagonist.id)
		_assert_has_keys(protagonist, ["id", "display_name", "role", "speed_high", "speed_low", "hitbox", "graze_radius", "difficulty_hint", "shot_types", "bomb"], "protagonist %s" % pid)
		_assert(float(protagonist.speed_high) > float(protagonist.speed_low), "%s high speed should exceed low speed" % pid)
		_assert(float(protagonist.hitbox) > 0.0, "%s hitbox should be positive" % pid)
		_assert(float(protagonist.graze_radius) > float(protagonist.hitbox), "%s graze should exceed hitbox" % pid)
		_assert_equal(_ids(protagonist.shot_types), expected_shots[pid], "%s shot ids mismatch." % pid)
		for shot in protagonist.shot_types:
			var sid := String(shot.id)
			seen_shots[sid] = true
			_assert_has_keys(shot, ["id", "display_name", "hud_name", "type_label", "style", "pattern_id", "bullet_type", "fire_interval_frames", "base_damage", "bullet_speed", "coverage", "focused_damage", "difficulty_hint", "color"], "shot %s" % sid)
			_assert(int(shot.fire_interval_frames) >= 2, "%s fire interval should be at least 2 frames" % sid)
			_assert(float(shot.base_damage) > 0.0, "%s base damage should be positive" % sid)
			_assert(float(shot.bullet_speed) > 0.0, "%s bullet speed should be positive" % sid)
		_assert_has_keys(protagonist.bomb, ["id", "display_name", "hud_name", "behavior_id", "duration_frames", "waves", "clear_radius", "damage", "bullet_count", "speed", "color", "description"], "bomb for %s" % pid)
		_assert_equal(String(protagonist.bomb.id), expected_bombs[pid], "%s bomb id mismatch." % pid)
		_assert(int(protagonist.bomb.duration_frames) > 0, "%s bomb duration should be positive" % pid)
		_assert(int(protagonist.bomb.waves) > 0, "%s bomb waves should be positive" % pid)
		_assert(float(protagonist.bomb.clear_radius) > 0.0, "%s bomb clear radius should be positive" % pid)
	for shot_id in ["ofuda_trace", "yin_yang_focus", "stardust_spread", "magic_laser", "sword_wave_fan", "returning_spirit_blades"]:
		_assert(seen_shots.has(shot_id), "Expected shot id %s in protagonist data" % shot_id)
		_assert_equal(String(db.shot_profile_by_id(shot_id).id), shot_id, "shot_profile_by_id should find %s." % shot_id)
	_assert_equal(db.shot_profile_by_id("missing"), {}, "Unknown shot id should return empty Dictionary.")
	_assert_equal(String(db.bomb_profile_for_protagonist("magician").id), "festival_master_spark", "Magician bomb lookup mismatch.")
	_assert_equal(db.bomb_profile_for_protagonist("missing"), {}, "Unknown protagonist bomb should return empty Dictionary.")

func _verify_game_manager_helpers() -> void:
	var gm_script = load("res://autoload/game_manager.gd")
	if not _assert(gm_script != null, "Could not load game_manager.gd"):
		return
	var gm = gm_script.new()
	for method in ["protagonist_profile", "selected_shot_profile", "selected_bomb_profile", "selected_speed_high", "selected_speed_low", "selected_hitbox_radius", "selected_graze_radius", "selected_fire_interval_frames", "apply_selected_shot"]:
		if not _assert(gm.has_method(method), "GameManager missing method %s" % method):
			gm.free()
			return
	gm.selected_protagonist_id = "magician"
	gm.selected_shot_id = "magic_laser"
	gm.apply_selected_shot()
	_assert_equal(String(gm.protagonist_profile().id), "magician", "Selected protagonist profile mismatch.")
	_assert_equal(String(gm.selected_shot_profile().id), "magic_laser", "Selected shot profile mismatch.")
	_assert_equal(String(gm.selected_bomb_profile().id), "festival_master_spark", "Selected bomb profile mismatch.")
	_assert(gm.selected_speed_high() > gm.selected_speed_low(), "Selected high speed should exceed low speed.")
	_assert(gm.selected_fire_interval_frames() >= 2, "Selected fire interval should be usable.")
	_assert_equal(gm.bullet_type, gm.BulletType.LINEAR, "apply_selected_shot should sync legacy bullet_type for HUD/backward compatibility.")
	gm.free()

func _verify_ui_details() -> void:
	var ui_script = load("res://scripts/ui/ui_model.gd")
	if not _assert(ui_script != null, "Could not load ui_model.gd"):
		return
	var ui = ui_script.new()
	for entry in ui.protagonist_entries():
		_assert(entry.has("detail_lines"), "Protagonist UI entry missing detail_lines: %s" % [entry])
		_assert(entry.detail_lines.size() >= 3, "Protagonist UI detail_lines should show speed, bomb, and hint.")
	for shot in ui.shot_entries("swordswoman"):
		_assert(shot.has("detail_lines"), "Shot UI entry missing detail_lines: %s" % [shot])
		_assert(shot.detail_lines.size() >= 3, "Shot UI detail_lines should show coverage, focused damage, and hint.")

func _init() -> void:
	_verify_database_profiles()
	if failed:
		return
	_verify_game_manager_helpers()
	if failed:
		return
	_verify_ui_details()
	if failed:
		return
	quit(0)
```

- [ ] **Step 2: Run the profile test and verify it fails**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase3_protagonist_profiles.gd'
```

Expected: FAIL because the new helper methods and profile keys do not exist yet.

- [ ] **Step 3: Extend protagonist profile data**

Modify `scripts/data/game_database.gd` so each protagonist has:

```gdscript
"hitbox": 2.0,
"graze_radius": 10.0,
"difficulty_hint": "balanced starter",
```

Use protagonist-specific values:

```gdscript
miko: speed_high 5.7, speed_low 2.4, hitbox 2.0, graze_radius 10.0, difficulty_hint "safe route learning"
magician: speed_high 5.2, speed_low 2.0, hitbox 2.1, graze_radius 10.5, difficulty_hint "high boss damage"
swordswoman: speed_high 6.2, speed_low 2.7, hitbox 1.9, graze_radius 9.5, difficulty_hint "aggressive routing"
```

Each shot dictionary must include these keys with phase-3 values:

```gdscript
{
	"id": "ofuda_trace",
	"display_name": "...",
	"hud_name": "Ofuda Trace",
	"type_label": "Type A",
	"style": "low_damage_tracking",
	"pattern_id": "miko_tracking_ofuda",
	"bullet_type": "homing",
	"fire_interval_frames": 3,
	"base_damage": 1.15,
	"bullet_speed": 5.4,
	"coverage": "wide tracking",
	"focused_damage": "low",
	"difficulty_hint": "safe learning shot",
	"color": Color(0.31, 1.0, 0.55),
}
```

Use this exact shot mapping:

```text
ofuda_trace: bullet_type homing, pattern_id miko_tracking_ofuda, fire 3, damage 1.15, speed 5.4
yin_yang_focus: bullet_type linear, pattern_id miko_yinyang_focus, fire 4, damage 2.8, speed 9.2
stardust_spread: bullet_type spread, pattern_id magician_stardust_spread, fire 3, damage 1.55, speed 7.4
magic_laser: bullet_type linear, pattern_id magician_magic_laser, fire 5, damage 4.6, speed 11.0
sword_wave_fan: bullet_type spread, pattern_id swordswoman_wave_fan, fire 3, damage 1.95, speed 8.0
returning_spirit_blades: bullet_type homing, pattern_id swordswoman_returning_blades, fire 4, damage 2.25, speed 6.4
```

Each bomb dictionary must include:

```gdscript
{
	"id": "great_boundary_bloom",
	"display_name": "...",
	"hud_name": "Great Boundary Bloom",
	"behavior_id": "boundary_bloom",
	"duration_frames": 150,
	"waves": 6,
	"clear_radius": 220.0,
	"damage": 1.1,
	"bullet_count": 36,
	"speed": 4.2,
	"color": Color(0.78, 0.39, 1.0),
	"description": "clear then sustained boundary pulses",
}
```

Use this exact bomb mapping:

```text
miko great_boundary_bloom: behavior boundary_bloom, duration 150, waves 6, clear_radius 220, damage 1.1, bullet_count 36, speed 4.2
magician festival_master_spark: behavior master_spark, duration 78, waves 5, clear_radius 120, damage 3.4, bullet_count 9, speed 11.0
swordswoman instant_slash_boundary: behavior instant_slash, duration 96, waves 8, clear_radius 145, damage 2.4, bullet_count 7, speed 9.0
```

- [ ] **Step 4: Add lookup helpers**

Add these methods to `GameDatabase`:

```gdscript
func shot_profile_by_id(shot_id: String) -> Dictionary:
	for protagonist in PROTAGONISTS:
		for shot in protagonist.get("shot_types", []):
			if String(shot.get("id", "")) == shot_id:
				return shot.duplicate(true)
	return {}

func bomb_profile_for_protagonist(protagonist_id: String) -> Dictionary:
	var protagonist := protagonist_by_id(protagonist_id)
	if protagonist.is_empty():
		return {}
	return protagonist.get("bomb", {}).duplicate(true)
```

- [ ] **Step 5: Add `GameManager` loadout helpers**

Add a private database instance and helpers to `autoload/game_manager.gd`. Keep the existing `bullet_type` variable for backward compatibility:

```gdscript
var _database = load("res://scripts/data/game_database.gd").new()

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
```

- [ ] **Step 6: Add UI detail lines**

Update `UiModel.protagonist_entries()` and `UiModel.shot_entries()` so each entry keeps existing `id`, `label`, `description`, and adds `detail_lines`.

Protagonist detail lines:

```gdscript
[
	"Speed %.1f / %.1f" % [float(protagonist.speed_high), float(protagonist.speed_low)],
	"Bomb: %s" % String(protagonist.bomb.get("hud_name", protagonist.bomb.get("display_name", ""))),
	"Hint: %s" % String(protagonist.get("difficulty_hint", "")),
]
```

Shot detail lines:

```gdscript
[
	"%s  Coverage: %s" % [String(shot.get("type_label", "")), String(shot.get("coverage", ""))],
	"Focused damage: %s" % String(shot.get("focused_damage", "")),
	"Hint: %s" % String(shot.get("difficulty_hint", "")),
]
```

- [ ] **Step 7: Run the profile test and verify it passes**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase3_protagonist_profiles.gd'
```

Expected: PASS, exit code 0.

- [ ] **Step 8: Run existing UI/database tests**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_game_database.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_ui_shell_model.gd'
```

Expected: both PASS, exit code 0.

- [ ] **Step 9: Commit**

```powershell
git add scripts/data/game_database.gd autoload/game_manager.gd scripts/ui/ui_model.gd tests/assert_phase3_protagonist_profiles.gd
git commit -m "feat: add phase 3 loadout profiles"
```

---

### Task 2: Six Shot Types In Gameplay

**Files:**
- Create: `scripts/player/player_shot_executor.gd`
- Create: `tests/assert_phase3_shot_patterns.gd`
- Modify: `scripts/main.gd`

**Interfaces:**
- Consumes: `GameManager.selected_shot_profile()`, `GameManager.selected_speed_high()`, `GameManager.selected_speed_low()`, `GameManager.selected_fire_interval_frames()`.
- Produces:
  - `PlayerShotExecutor.bullet_type_for_shot(shot_profile: Dictionary, game_manager_ref: Object) -> int`
  - `PlayerShotExecutor.fire_pattern(shot_profile: Dictionary, power_level: int, focused: bool, origin: Vector2) -> Array`
  - `scripts/main.gd` method `_selected_shot_profile() -> Dictionary`
  - `scripts/main.gd` method `_spawn_player_bullet_spec(spec: Dictionary) -> void`
  - `scripts/main.gd` method `_shot_executor_fire_pattern(shot_profile: Dictionary, level: int, focused: bool, origin: Vector2) -> Array`

- [ ] **Step 1: Write the failing shot-pattern test**

Create `tests/assert_phase3_shot_patterns.gd` with this structure:

```gdscript
extends SceneTree

var failed := false

func _fail(message: String) -> void:
	if failed:
		return
	failed = true
	push_error(message)
	quit(1)

func _assert(condition: bool, message: String) -> bool:
	if not condition:
		_fail(message)
		return false
	return true

func _assert_equal(actual, expected, message: String) -> bool:
	if actual != expected:
		_fail("%s Expected %s, got %s" % [message, expected, actual])
		return false
	return true

func _active_player_bullets(main_shell: Node) -> Array:
	var result: Array = []
	for bullet in main_shell.bullet_pool:
		if bullet.get("active", false) and bullet.get("type", "") == "player":
			result.append(bullet)
	return result

func _verify_executor_patterns() -> void:
	var db = load("res://scripts/data/game_database.gd").new()
	var gm = load("res://autoload/game_manager.gd").new()
	var executor_script = load("res://scripts/player/player_shot_executor.gd")
	if not _assert(executor_script != null, "Could not load player_shot_executor.gd"):
		gm.free()
		return
	var executor = executor_script.new()
	var expected := {
		"ofuda_trace": {"type": gm.BulletType.HOMING, "homing": true, "min_count": 3},
		"yin_yang_focus": {"type": gm.BulletType.LINEAR, "homing": false, "min_count": 1},
		"stardust_spread": {"type": gm.BulletType.SPREAD, "homing": false, "min_count": 5},
		"magic_laser": {"type": gm.BulletType.LINEAR, "homing": false, "min_count": 1},
		"sword_wave_fan": {"type": gm.BulletType.SPREAD, "homing": false, "min_count": 5},
		"returning_spirit_blades": {"type": gm.BulletType.HOMING, "homing": true, "min_count": 3},
	}
	for shot_id in expected.keys():
		var shot := db.shot_profile_by_id(shot_id)
		var specs: Array = executor.fire_pattern(shot, 5, false, Vector2(360, 540))
		_assert(specs.size() >= int(expected[shot_id].min_count), "%s should spawn enough bullets at full power" % shot_id)
		_assert_equal(executor.bullet_type_for_shot(shot, gm), int(expected[shot_id].type), "%s bullet type mismatch." % shot_id)
		var saw_homing := false
		var saw_damage := false
		for spec in specs:
			_assert(spec.has("position") and spec.has("velocity") and spec.has("radius") and spec.has("color") and spec.has("damage") and spec.has("homing") and spec.has("btype") and spec.has("lifetime"), "%s spec missing required keys: %s" % [shot_id, spec])
			if bool(spec.homing):
				saw_homing = true
			if float(spec.damage) >= float(shot.base_damage):
				saw_damage = true
		_assert_equal(saw_homing, bool(expected[shot_id].homing), "%s homing contract mismatch." % shot_id)
		_assert(saw_damage, "%s should use profile damage." % shot_id)
	var laser_specs: Array = executor.fire_pattern(db.shot_profile_by_id("magic_laser"), 5, true, Vector2(360, 540))
	var spread_specs: Array = executor.fire_pattern(db.shot_profile_by_id("stardust_spread"), 5, false, Vector2(360, 540))
	_assert(float(laser_specs[0].damage) > float(spread_specs[0].damage), "Magic laser should out-damage stardust spread per bullet.")
	gm.free()

func _verify_main_uses_selected_shot() -> void:
	var gm = load("res://autoload/game_manager.gd").new()
	var main_script = load("res://scripts/main.gd")
	if not _assert(main_script != null, "Could not load main.gd"):
		gm.free()
		return
	var main_shell = main_script.new()
	main_shell.game_manager_ref = gm
	main_shell._resolve_singletons()
	for method in ["_selected_shot_profile", "_spawn_player_bullet_spec", "_shot_executor_fire_pattern"]:
		if not _assert(main_shell.has_method(method), "Main missing method %s" % method):
			main_shell.free()
			gm.free()
			return
	main_shell.bullet_pool = []
	for i in range(96):
		main_shell.bullet_pool.append(main_shell._make_bullet())
	main_shell.player_x = 360.0
	main_shell.player_y = 540.0
	gm.shared_power = 50
	gm.selected_protagonist_id = "magician"
	gm.selected_shot_id = "magic_laser"
	gm.apply_selected_shot()
	main_shell._shoot()
	var laser_bullets := _active_player_bullets(main_shell)
	_assert(laser_bullets.size() > 0, "Main should spawn selected magic_laser bullets.")
	var laser_damage := float(laser_bullets[0].damage)
	for bullet in laser_bullets:
		bullet.active = false
	gm.selected_protagonist_id = "miko"
	gm.selected_shot_id = "ofuda_trace"
	gm.apply_selected_shot()
	main_shell._shoot()
	var ofuda_bullets := _active_player_bullets(main_shell)
	_assert(ofuda_bullets.size() > laser_bullets.size(), "Ofuda tracking shot should spawn wider coverage than magic laser.")
	_assert(float(ofuda_bullets[0].damage) < laser_damage, "Ofuda tracking shot should have lower per-bullet damage than magic laser.")
	main_shell.free()
	gm.free()

func _init() -> void:
	_verify_executor_patterns()
	if failed:
		return
	_verify_main_uses_selected_shot()
	if failed:
		return
	quit(0)
```

- [ ] **Step 2: Run the shot-pattern test and verify it fails**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase3_shot_patterns.gd'
```

Expected: FAIL because `player_shot_executor.gd` and main helpers do not exist yet.

- [ ] **Step 3: Add the pure shot executor**

Create `scripts/player/player_shot_executor.gd`:

```gdscript
extends RefCounted
class_name PlayerShotExecutor

func bullet_type_for_shot(shot_profile: Dictionary, game_manager_ref: Object) -> int:
	var bullet_type_name := String(shot_profile.get("bullet_type", "spread"))
	match bullet_type_name:
		"linear":
			return game_manager_ref.BulletType.LINEAR
		"homing":
			return game_manager_ref.BulletType.HOMING
		_:
			return game_manager_ref.BulletType.SPREAD

func fire_pattern(shot_profile: Dictionary, power_level: int, focused: bool, origin: Vector2) -> Array:
	var pattern_id := String(shot_profile.get("pattern_id", ""))
	var level := clampi(power_level, 0, 5)
	match pattern_id:
		"miko_tracking_ofuda":
			return _miko_tracking_ofuda(shot_profile, level, focused, origin)
		"miko_yinyang_focus":
			return _miko_yinyang_focus(shot_profile, level, focused, origin)
		"magician_stardust_spread":
			return _magician_stardust_spread(shot_profile, level, focused, origin)
		"magician_magic_laser":
			return _magician_magic_laser(shot_profile, level, focused, origin)
		"swordswoman_wave_fan":
			return _swordswoman_wave_fan(shot_profile, level, focused, origin)
		"swordswoman_returning_blades":
			return _swordswoman_returning_blades(shot_profile, level, focused, origin)
		_:
			return _magician_stardust_spread(shot_profile, level, focused, origin)
```

Add private helpers that return an Array of dictionaries with:

```gdscript
{
	"position": Vector2,
	"velocity": Vector2,
	"radius": float,
	"color": Color,
	"damage": float,
	"homing": bool,
	"btype": int,
	"persist": false,
	"lifetime": float,
}
```

Pattern requirements:

```text
miko_tracking_ofuda: homing true, btype 2, many small bullets, lower damage, wider x offsets.
miko_yinyang_focus: homing false, btype 1, one to three central bullets, high forward damage.
magician_stardust_spread: homing false, btype 0, wide cone, closer-range stage-wave coverage.
magician_magic_laser: homing false, btype 1, thick fast central shots, highest per-bullet damage.
swordswoman_wave_fan: homing false, btype 0, five to nine medium-speed fan bullets.
swordswoman_returning_blades: homing true, btype 2, three to five blade bullets with longer lifetime and side offsets.
```

- [ ] **Step 4: Integrate selected speeds and shots in main**

Modify `scripts/main.gd`:

```gdscript
var shot_executor: Object = load("res://scripts/player/player_shot_executor.gd").new()

func _selected_shot_profile() -> Dictionary:
	_resolve_singletons()
	if game_manager_ref and game_manager_ref.has_method("selected_shot_profile"):
		return game_manager_ref.selected_shot_profile()
	return {}

func _spawn_player_bullet_spec(spec: Dictionary) -> void:
	_spawn_bullet_player(
		float(spec.position.x),
		float(spec.position.y),
		float(spec.velocity.x),
		float(spec.velocity.y),
		float(spec.radius),
		spec.color,
		float(spec.damage),
		bool(spec.homing),
		int(spec.btype),
		bool(spec.get("persist", false)),
		float(spec.lifetime)
	)

func _shot_executor_fire_pattern(shot_profile: Dictionary, level: int, focused: bool, origin: Vector2) -> Array:
	return shot_executor.fire_pattern(shot_profile, level, focused, origin)
```

Replace player movement speed in `_update_player()`:

```gdscript
var speed: float = game_manager_ref.selected_speed_low() if focus else game_manager_ref.selected_speed_high()
```

Replace fire interval in `_update_player()`:

```gdscript
player_fire_cooldown = game_manager_ref.selected_fire_interval_frames() / 60.0
```

Replace `_shoot()` body so it uses the selected shot profile:

```gdscript
func _shoot():
	var shot_profile := _selected_shot_profile()
	var level: int = game_manager_ref.power_level()
	var focused := Input.is_key_pressed(KEY_SHIFT)
	var specs: Array = _shot_executor_fire_pattern(shot_profile, level, focused, Vector2(player_x, player_y))
	for spec in specs:
		_spawn_player_bullet_spec(spec)
	_sfx_shoot_skip = (_sfx_shoot_skip + 1) % 2
	if _sfx_shoot_skip == 0 and audio_manager_ref:
		audio_manager_ref.play_sfx("shoot", -12.0)
```

Keep `_shoot_spread()`, `_shoot_linear()`, and `_shoot_homing()` only if older tests still call them; otherwise leave them unused for now to reduce risky cleanup.

- [ ] **Step 5: Update selected shot sync**

Replace direct `_bullet_type_for_shot_id()` use after shot selection/start with:

```gdscript
game_manager_ref.apply_selected_shot()
```

Keep `_bullet_type_for_shot_id(shot_id)` for Phase 2 tests, but implement it using database shot profiles and the executor.

- [ ] **Step 6: Run the shot-pattern test and verify it passes**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase3_shot_patterns.gd'
```

Expected: PASS, exit code 0.

- [ ] **Step 7: Run affected regression tests**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_ui_shell_model.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_pause_contract.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --scene 'res://scenes/main.tscn' --quit-after 5
```

Expected: all PASS, exit code 0.

- [ ] **Step 8: Commit**

```powershell
git add scripts/player/player_shot_executor.gd scripts/main.gd tests/assert_phase3_shot_patterns.gd
git commit -m "feat: add six selected shot types"
```

---

### Task 3: Three Dedicated Bombs

**Files:**
- Create: `scripts/player/player_bomb_executor.gd`
- Create: `tests/assert_phase3_bomb_contract.gd`
- Modify: `scripts/main.gd`

**Interfaces:**
- Consumes: `GameManager.selected_bomb_profile()`.
- Produces:
  - `PlayerBombExecutor.start_state(bomb_profile: Dictionary, origin: Vector2, direction: Vector2) -> Dictionary`
  - `PlayerBombExecutor.wave_specs(state: Dictionary, phase: int) -> Array`
  - `PlayerBombExecutor.should_clear_enemy_bullet(state: Dictionary, bullet: Dictionary, player_position: Vector2) -> bool`
  - `scripts/main.gd` method `_selected_bomb_profile() -> Dictionary`
  - `scripts/main.gd` method `_start_bomb()` uses selected protagonist bomb.
  - `scripts/main.gd` method `_update_bomb(delta)` uses bomb executor behavior instead of `BOMB_CONFIG[bullet_type]`.

- [ ] **Step 1: Write the failing bomb contract test**

Create `tests/assert_phase3_bomb_contract.gd` with this structure:

```gdscript
extends SceneTree

var failed := false

func _fail(message: String) -> void:
	if failed:
		return
	failed = true
	push_error(message)
	quit(1)

func _assert(condition: bool, message: String) -> bool:
	if not condition:
		_fail(message)
		return false
	return true

func _assert_equal(actual, expected, message: String) -> bool:
	if actual != expected:
		_fail("%s Expected %s, got %s" % [message, expected, actual])
		return false
	return true

func _enemy_bullet(x: float, y: float) -> Dictionary:
	return {"active": true, "type": "circle", "x": x, "y": y, "radius": 4.0}

func _verify_bomb_executor() -> void:
	var db = load("res://scripts/data/game_database.gd").new()
	var executor_script = load("res://scripts/player/player_bomb_executor.gd")
	if not _assert(executor_script != null, "Could not load player_bomb_executor.gd"):
		return
	var executor = executor_script.new()
	var origin := Vector2(360, 540)
	var direction := Vector2(0, -1)
	var miko_state: Dictionary = executor.start_state(db.bomb_profile_for_protagonist("miko"), origin, direction)
	var magician_state: Dictionary = executor.start_state(db.bomb_profile_for_protagonist("magician"), origin, direction)
	var sword_state: Dictionary = executor.start_state(db.bomb_profile_for_protagonist("swordswoman"), origin, Vector2(1, -1).normalized())
	_assert_equal(String(miko_state.behavior_id), "boundary_bloom", "Miko bomb behavior mismatch.")
	_assert_equal(String(magician_state.behavior_id), "master_spark", "Magician bomb behavior mismatch.")
	_assert_equal(String(sword_state.behavior_id), "instant_slash", "Swordswoman bomb behavior mismatch.")
	_assert(executor.wave_specs(miko_state, 0).size() > executor.wave_specs(magician_state, 0).size(), "Boundary Bloom should have more radial bullets than Master Spark.")
	_assert(executor.wave_specs(magician_state, 0).size() >= 1, "Master Spark should emit lane bullets.")
	_assert(executor.wave_specs(sword_state, 0).size() >= 3, "Instant Slash should emit multi-hit slash bullets.")
	_assert(executor.should_clear_enemy_bullet(miko_state, _enemy_bullet(360, 420), origin), "Boundary Bloom should clear nearby bullets.")
	_assert(executor.should_clear_enemy_bullet(magician_state, _enemy_bullet(360, 260), origin), "Master Spark should clear the forward lane.")
	_assert(not executor.should_clear_enemy_bullet(magician_state, _enemy_bullet(140, 540), origin), "Master Spark should not clear far side bullets.")
	_assert(executor.should_clear_enemy_bullet(sword_state, _enemy_bullet(460, 440), origin), "Instant Slash should clear along slash direction.")
	_assert(not executor.should_clear_enemy_bullet(sword_state, _enemy_bullet(220, 560), origin), "Instant Slash should not clear the whole screen.")

func _active_bomb_bullets(main_shell: Node) -> Array:
	var result: Array = []
	for bullet in main_shell.bullet_pool:
		if bullet.get("active", false) and bullet.get("type", "") == "bomb":
			result.append(bullet)
	return result

func _verify_main_uses_selected_bomb() -> void:
	var gm = load("res://autoload/game_manager.gd").new()
	var main_script = load("res://scripts/main.gd")
	if not _assert(main_script != null, "Could not load main.gd"):
		gm.free()
		return
	var main_shell = main_script.new()
	main_shell.game_manager_ref = gm
	for method in ["_selected_bomb_profile", "_start_bomb"]:
		if not _assert(main_shell.has_method(method), "Main missing method %s" % method):
			main_shell.free()
			gm.free()
			return
	main_shell.bullet_pool = []
	for i in range(128):
		main_shell.bullet_pool.append(main_shell._make_bullet())
	main_shell.player_x = 360.0
	main_shell.player_y = 540.0
	gm.bombs = 3
	gm.selected_protagonist_id = "magician"
	gm.selected_shot_id = "magic_laser"
	main_shell._start_bomb()
	_assert_equal(gm.bombs, 2, "Starting selected bomb should consume one bomb.")
	_assert_equal(String(main_shell.player_bomb_config.behavior_id), "master_spark", "Main should use magician bomb config.")
	main_shell._update_bomb(1.0 / 60.0)
	_assert(_active_bomb_bullets(main_shell).size() > 0, "Updating selected bomb should spawn bomb bullets.")
	main_shell.free()
	gm.free()

func _init() -> void:
	_verify_bomb_executor()
	if failed:
		return
	_verify_main_uses_selected_bomb()
	if failed:
		return
	quit(0)
```

- [ ] **Step 2: Run the bomb contract test and verify it fails**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase3_bomb_contract.gd'
```

Expected: FAIL because `player_bomb_executor.gd` and selected-bomb integration do not exist yet.

- [ ] **Step 3: Add the pure bomb executor**

Create `scripts/player/player_bomb_executor.gd`:

```gdscript
extends RefCounted
class_name PlayerBombExecutor

func start_state(bomb_profile: Dictionary, origin: Vector2, direction: Vector2) -> Dictionary:
	var normalized_dir := direction.normalized()
	if normalized_dir == Vector2.ZERO:
		normalized_dir = Vector2(0, -1)
	var state := bomb_profile.duplicate(true)
	state["origin"] = origin
	state["direction"] = normalized_dir
	state["behavior_id"] = String(bomb_profile.get("behavior_id", "boundary_bloom"))
	state["duration"] = int(bomb_profile.get("duration_frames", 120))
	state["waves"] = int(bomb_profile.get("waves", 4))
	state["clear_radius"] = float(bomb_profile.get("clear_radius", 160.0))
	state["damage"] = float(bomb_profile.get("damage", 1.0))
	state["bullet_count"] = int(bomb_profile.get("bullet_count", 12))
	state["speed"] = float(bomb_profile.get("speed", 4.0))
	state["color"] = bomb_profile.get("color", Color.WHITE)
	return state
```

Implement `wave_specs(state, phase)`:

```text
boundary_bloom: radial ring of `bullet_count` persistent bomb bullets, radius 7, btype -1, lifetime 90.
master_spark: forward lane of `bullet_count` persistent red/white bullets spread across a narrow lane, radius 14, btype 1, lifetime 72.
instant_slash: slash fan along `direction`, `bullet_count` persistent blade bullets with angled offsets, radius 10, btype 0, lifetime 58.
```

Each returned spec must match `_spawn_player_bullet_spec` keys.

Implement `should_clear_enemy_bullet(state, bullet, player_position)`:

```text
boundary_bloom: clear by distance from player_position <= clear_radius.
master_spark: clear bullets in front of player_position, within a lane width of 90 px, up to 520 px forward.
instant_slash: clear bullets near the slash direction segment, max forward distance 360 px, lane width 82 px.
```

- [ ] **Step 4: Track last movement direction in main**

Modify `scripts/main.gd`:

```gdscript
var bomb_executor: Object = load("res://scripts/player/player_bomb_executor.gd").new()
var player_last_move_dir: Vector2 = Vector2(0, -1)
```

In `_update_player(delta)`, after reading `dx`/`dy` and diagonal normalization:

```gdscript
if dx != 0.0 or dy != 0.0:
	player_last_move_dir = Vector2(dx, dy).normalized()
```

In `_reset_player()`, reset:

```gdscript
player_last_move_dir = Vector2(0, -1)
```

- [ ] **Step 5: Integrate selected bomb profile in main**

Add:

```gdscript
func _selected_bomb_profile() -> Dictionary:
	_resolve_singletons()
	if game_manager_ref and game_manager_ref.has_method("selected_bomb_profile"):
		return game_manager_ref.selected_bomb_profile()
	return {}
```

Replace `_start_bomb()` config selection:

```gdscript
player_bomb_config = bomb_executor.start_state(_selected_bomb_profile(), Vector2(player_x, player_y), player_last_move_dir)
player_bombing = true
player_bomb_timer = int(player_bomb_config.duration) / 60.0
player_bomb_phase = 0
player_bomb_wave_timer = 0.0
player_bomb_radius = 0.0
player_invincible = true
player_invincible_timer = int(player_bomb_config.duration) / 60.0
```

Replace `_update_bomb(delta)` wave spawning with:

```gdscript
var total_waves: int = max(1, int(bc.get("waves", 1)))
var wave_int: float = float(bc.get("duration", 60)) / float(total_waves) / 60.0
if player_bomb_wave_timer <= 0.0 and player_bomb_phase < total_waves:
	player_bomb_wave_timer = wave_int
	for spec in bomb_executor.wave_specs(bc, player_bomb_phase):
		_spawn_player_bullet_spec(spec)
	player_bomb_phase += 1
```

Replace enemy-bullet clearing in `_update_bomb(delta)`:

```gdscript
for b in bullet_pool:
	if b.active and b.type in ["circle", "rice", "arrow", "laser"]:
		if bomb_executor.should_clear_enemy_bullet(bc, b, Vector2(player_x, player_y)):
			b.active = false
```

- [ ] **Step 6: Update bomb draw radius safely**

Set:

```gdscript
player_bomb_radius += float(bc.get("clear_radius", 160.0)) / float(bc.get("duration", 120)) * 2.0 * delta * 60.0
player_bomb_radius = min(player_bomb_radius, float(bc.get("clear_radius", 160.0)))
```

The draw code can continue using `player_bomb_config.color`.

- [ ] **Step 7: Run the bomb contract test and verify it passes**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase3_bomb_contract.gd'
```

Expected: PASS, exit code 0.

- [ ] **Step 8: Run affected regression tests**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_pause_contract.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --scene 'res://scenes/main.tscn' --quit-after 5
```

Expected: both PASS, exit code 0.

- [ ] **Step 9: Commit**

```powershell
git add scripts/player/player_bomb_executor.gd scripts/main.gd tests/assert_phase3_bomb_contract.gd
git commit -m "feat: add protagonist-specific bombs"
```

---

### Task 4: Fixed Loadout UI And Item Contract

**Files:**
- Create: `tests/assert_phase3_ui_loadout_contract.gd`
- Modify: `scripts/main.gd`
- Modify: `scripts/ui/ui_model.gd`

**Interfaces:**
- Consumes: `UiModel` detail lines from Task 1, `GameManager.selected_shot_profile()`, `GameManager.selected_bomb_profile()`.
- Produces:
  - `scripts/main.gd` method `_gameplay_shot_label() -> String`
  - `scripts/main.gd` method `_gameplay_protagonist_label() -> String`
  - `scripts/main.gd` method `_gameplay_bomb_label() -> String`
  - `scripts/main.gd` `_drop_item()` no longer spawns `bullet_spread`, `bullet_linear`, or `bullet_homing`.
  - `scripts/main.gd` `_collect_item()` no longer changes shot type for legacy bullet-switch items.
  - `scripts/main.gd` character/shot menu drawing shows `detail_lines`.

- [ ] **Step 1: Write the failing fixed-loadout UI test**

Create `tests/assert_phase3_ui_loadout_contract.gd` with this structure:

```gdscript
extends SceneTree

var failed := false

func _fail(message: String) -> void:
	if failed:
		return
	failed = true
	push_error(message)
	quit(1)

func _assert(condition: bool, message: String) -> bool:
	if not condition:
		_fail(message)
		return false
	return true

func _assert_equal(actual, expected, message: String) -> bool:
	if actual != expected:
		_fail("%s Expected %s, got %s" % [message, expected, actual])
		return false
	return true

func _verify_ui_detail_contract() -> void:
	var ui = load("res://scripts/ui/ui_model.gd").new()
	for entry in ui.protagonist_entries():
		_assert(entry.has("detail_lines"), "Protagonist entry missing detail_lines: %s" % [entry])
		var joined := " ".join(entry.detail_lines)
		_assert(joined.find("Speed") >= 0, "Protagonist detail should include speed: %s" % joined)
		_assert(joined.find("Bomb") >= 0, "Protagonist detail should include bomb: %s" % joined)
	for shot in ui.shot_entries("magician"):
		_assert(shot.has("detail_lines"), "Shot entry missing detail_lines: %s" % [shot])
		var joined := " ".join(shot.detail_lines)
		_assert(joined.find("Coverage") >= 0, "Shot detail should include coverage: %s" % joined)
		_assert(joined.find("Focused damage") >= 0, "Shot detail should include focused damage: %s" % joined)

func _verify_main_fixed_loadout_contract() -> void:
	var gm = load("res://autoload/game_manager.gd").new()
	var main_script = load("res://scripts/main.gd")
	if not _assert(main_script != null, "Could not load main.gd"):
		gm.free()
		return
	var main_shell = main_script.new()
	main_shell.game_manager_ref = gm
	for method in ["_gameplay_shot_label", "_gameplay_protagonist_label", "_gameplay_bomb_label"]:
		if not _assert(main_shell.has_method(method), "Main missing HUD helper %s" % method):
			main_shell.free()
			gm.free()
			return
	gm.selected_protagonist_id = "swordswoman"
	gm.selected_shot_id = "returning_spirit_blades"
	gm.apply_selected_shot()
	_assert(main_shell._gameplay_protagonist_label().length() > 0, "HUD protagonist label should not be empty.")
	_assert(main_shell._gameplay_shot_label().find("Spirit") >= 0 or main_shell._gameplay_shot_label().find("Blade") >= 0, "HUD shot label should use selected shot hud_name.")
	_assert(main_shell._gameplay_bomb_label().find("Slash") >= 0 or main_shell._gameplay_bomb_label().find("Boundary") >= 0, "HUD bomb label should use selected bomb hud_name.")
	var original_bullet_type: int = gm.bullet_type
	var legacy_item := {"alive": true, "collected": false, "type": "bullet_linear", "x": 0.0, "y": 0.0}
	main_shell._collect_item(legacy_item)
	_assert_equal(gm.bullet_type, original_bullet_type, "Legacy bullet-switch item should not change fixed selected shot.")
	_assert_equal(gm.selected_shot_id, "returning_spirit_blades", "Legacy bullet-switch item should not change selected_shot_id.")
	main_shell.items = []
	for i in range(80):
		main_shell._drop_item(200.0, 120.0, i % 5 == 0)
	for item in main_shell.items:
		var item_type := String(item.get("type", ""))
		_assert(not item_type.begins_with("bullet_"), "Phase 3 drops should not include weapon-switch item %s" % item_type)
	main_shell.free()
	gm.free()

func _init() -> void:
	_verify_ui_detail_contract()
	if failed:
		return
	_verify_main_fixed_loadout_contract()
	if failed:
		return
	quit(0)
```

- [ ] **Step 2: Run the fixed-loadout UI test and verify it fails**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase3_ui_loadout_contract.gd'
```

Expected: FAIL because HUD helpers and fixed-loadout item behavior do not exist yet.

- [ ] **Step 3: Add HUD label helpers**

Add to `scripts/main.gd`:

```gdscript
func _gameplay_shot_label() -> String:
	var shot := _selected_shot_profile()
	return String(shot.get("hud_name", shot.get("display_name", SHOT_NAMES_ZH[game_manager_ref.bullet_type])))

func _gameplay_protagonist_label() -> String:
	if game_manager_ref and game_manager_ref.has_method("protagonist_profile"):
		return String(game_manager_ref.protagonist_profile().get("display_name", ""))
	return ""

func _gameplay_bomb_label() -> String:
	var bomb := _selected_bomb_profile()
	return String(bomb.get("hud_name", bomb.get("display_name", "")))
```

Update HUD draw text:

```gdscript
draw_string(font, Vector2(10, 50), "Shot: %s Lv.%d" % [_gameplay_shot_label(), gm.power_level()])
draw_string(font, Vector2(10, 65), "Pilot: %s  Bomb: %s" % [_gameplay_protagonist_label(), _gameplay_bomb_label()])
```

Keep line spacing within 720x960 and do not overlap life/bomb counters.

- [ ] **Step 4: Remove weapon-switch drops**

Modify `_drop_item()` so random drops use only:

```text
power
point
bomb_refill
life_fragment
full_power
```

Strong drops may still include `bomb_refill`, but no branch should emit `bullet_spread`, `bullet_linear`, or `bullet_homing`.

- [ ] **Step 5: Make legacy bullet-switch pickups non-switching**

Modify `_collect_item(it)`:

```gdscript
"bullet_spread", "bullet_linear", "bullet_homing":
	game_manager_ref.add_power(2)
	game_manager_ref.score += 120
```

Do not call `game_manager_ref.switch_bullet_type()` for these legacy item ids.

- [ ] **Step 6: Draw detail lines in selection menus**

Add helper:

```gdscript
func _draw_entry_detail_lines(font: Font, entries: Array, cursor: int, start_y: float, row_height: float) -> void:
	if entries.is_empty():
		return
	var entry: Dictionary = entries[clampi(cursor, 0, entries.size() - 1)]
	var detail_lines: Array = entry.get("detail_lines", [])
	var y := start_y + entries.size() * row_height + 22.0
	for i in range(min(detail_lines.size(), 4)):
		draw_string(font, Vector2(78, y + i * 22.0), String(detail_lines[i]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.78, 0.82, 0.88))
```

Call it from `_draw_character_select_screen()` and `_draw_shot_select_screen()` after `_draw_menu_entries(...)`.

- [ ] **Step 7: Run the fixed-loadout UI test and verify it passes**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase3_ui_loadout_contract.gd'
```

Expected: PASS, exit code 0.

- [ ] **Step 8: Run affected regression tests**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_ui_shell_model.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase3_protagonist_profiles.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --scene 'res://scenes/main.tscn' --quit-after 5
```

Expected: all PASS, exit code 0.

- [ ] **Step 9: Commit**

```powershell
git add scripts/main.gd scripts/ui/ui_model.gd tests/assert_phase3_ui_loadout_contract.gd
git commit -m "feat: lock gameplay to selected loadout"
```

---

### Task 5: Phase 3 Verification

**Files:**
- Modify: `docs/superpowers/plans/2026-07-09-protagonist-system-phase3.md` only if checkboxes are updated by the controller.

**Interfaces:**
- Consumes: all Task 1-4 changes.
- Produces: a clean Phase 3 branch ready for final code review and integration.

- [ ] **Step 1: Run the full focused verification set**

Run:

```powershell
$godot = 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe'
$tests = @(
  'res://tests/assert_viewport_config.gd',
  'res://tests/assert_game_database.gd',
  'res://tests/assert_asset_registry.gd',
  'res://tests/assert_bullet_manager.gd',
  'res://tests/assert_performance_monitor.gd',
  'res://tests/assert_ui_shell_model.gd',
  'res://tests/assert_pause_contract.gd',
  'res://tests/assert_phase2_settings_effects.gd',
  'res://tests/assert_phase3_protagonist_profiles.gd',
  'res://tests/assert_phase3_shot_patterns.gd',
  'res://tests/assert_phase3_bomb_contract.gd',
  'res://tests/assert_phase3_ui_loadout_contract.gd'
)
foreach ($test in $tests) {
  & $godot --headless --path 'H:\claude code\godot_touhou' --script $test
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
& $godot --headless --path 'H:\claude code\godot_touhou' --scene 'res://scenes/main.tscn' --quit-after 5
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
git diff --check
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Output 'PHASE3_FINAL_CHECKS_PASS'
```

Expected: `PHASE3_FINAL_CHECKS_PASS`, exit code 0. Non-fatal Godot shutdown resource diagnostics may still print after successful headless runs; do not count them as failures unless the command exits non-zero.

- [ ] **Step 2: Commit plan/progress bookkeeping if needed**

Only tracked docs should be committed. `.superpowers/**` files are scratch and must remain untracked.

```powershell
git status -sb
git ls-files .superpowers
```

Expected: no tracked `.superpowers` files.

- [ ] **Step 3: Controller final code review**

Use `superpowers:requesting-code-review` final whole-branch review with base `master`/`origin/master` at branch start and HEAD after Task 4. Fix Critical/Important findings before merging.

- [ ] **Step 4: Merge and push only after final review and verification**

If the user's active integration instruction remains "merge to master and push", run:

```powershell
git switch master
git merge --ff-only feature/protagonist-system-phase3
git push origin master
```

Expected: `origin/master` advances to the Phase 3 commits.

---

## Self-Review

- Spec coverage: This plan covers the approved Phase 3 item: three protagonists, two fixed shot types per protagonist, one dedicated bomb per protagonist, gameplay use of selected loadout, and fixed-loadout item behavior.
- Out of scope by design: enemy families, bullet family expansion, item fragment economy, six-stage content pass, full hand-painted art generation, and music expansion remain later phases in the original total specification.
- Placeholder scan: no unresolved placeholder markers or unspecified test command remains.
- Type consistency: profile helper names are consistent across `GameDatabase`, `GameManager`, `UiModel`, shot executor, bomb executor, and main-scene integration.
