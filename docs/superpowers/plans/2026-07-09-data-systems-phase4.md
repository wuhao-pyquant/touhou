# Data Systems Phase 4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved total plan's fourth milestone: data-driven bullet, enemy, item, and scoring systems that the current gameplay loop actually consumes.

**Architecture:** Keep Phase 4 focused on gameplay data contracts and runtime rule helpers, not six-stage content, boss spell expansion, art, or music. Extend `GameDatabase` into the source of truth for enemy families, enemy bullet families, item rewards, drop tables, and scoring constants; add small pure runtime helpers for enemy bullet emission and item rewards; then wire `scripts/main.gd` to those helpers while preserving the current single-scene game loop.

**Tech Stack:** Godot 4.7 GDScript, headless SceneTree tests under `tests/`, existing autoloads (`GameManager`, `AudioManager`, `AssetRegistry`, `PerformanceMonitor`).

## Global Constraints

- Original total spec file: `docs/superpowers/specs/2026-07-09-touhou-full-production-design.md`.
- This is phase 4 only: `Bullet, enemy, item, and scoring data systems`.
- Do not generate or import the full hand-painted art asset library in this phase; that remains phase 6 in the approved total specification.
- Do not add existing Touhou Project characters, music, names, or art.
- Preserve 720x960 viewport behavior.
- Preserve Phase 2 UI shell, settings, pause, restart-stage, and title/character/shot flow.
- Preserve Phase 3 selected-protagonist, selected-shot, and selected-bomb runtime behavior.
- Weapon-switch item drops remain removed from core gameplay; drops are standard danmaku resources.
- Implement exactly five regular enemy behavior families: `low_yokai`, `fast_attacker`, `formation_shooter`, `elite_yokai`, and `mechanism`.
- Implement exactly eight enemy bullet families: `circle`, `rice`, `butterfly`, `needle`, `talisman`, `star`, `laser`, and `large_orb`.
- Implement the standard resource loop: `power`, `point`, `bomb_fragment`, `life_fragment`, `night_festival_seal`, and `full_power`, while keeping `bomb_refill` and `life` as backwards-compatible runtime collection ids.
- Bomb fragments make one bomb every 3 fragments; life fragments make one life every 5 fragments.
- Night Festival Seals are a high-risk score resource and must be reachable through data-driven drop tables.

---

## File Structure

- `scripts/data/game_database.gd`: source of truth for enemy families, bullet families, item types, drop tables, and scoring rules.
- `autoload/game_manager.gd`: global counters for Night Festival Seals and reset behavior.
- `scripts/runtime/enemy_pattern_executor.gd`: pure helper that maps enemy families and pattern ids to bullet spawn specs.
- `scripts/runtime/item_reward_system.gd`: pure helper that chooses drops and applies item collection rewards.
- `scripts/main.gd`: integration only: enemy spawn metadata, enemy firing, item drop/collection, enemy bullet classification, collision checks, counters, and HUD line for seals.
- `tests/assert_phase4_data_systems.gd`: database schema and lookup contract.
- `tests/assert_phase4_enemy_pattern_executor.gd`: enemy-family pattern emission and main spawn contract.
- `tests/assert_phase4_item_reward_system.gd`: item reward, drop table, seal, and fragment economy contract.
- `tests/assert_phase4_main_data_integration.gd`: main-loop bullet-family classification, counters, collision, and UI contract.

---

### Task 1: Phase 4 Database Contracts

**Files:**
- Create: `tests/assert_phase4_data_systems.gd`
- Modify: `scripts/data/game_database.gd`

**Interfaces:**
- Consumes: existing `GameDatabase.bullet_families()` and `GameDatabase.item_types()`.
- Produces:
  - `GameDatabase.enemy_families() -> Array`
  - `GameDatabase.enemy_family_by_id(id: String) -> Dictionary`
  - `GameDatabase.bullet_family_by_id(id: String) -> Dictionary`
  - `GameDatabase.item_type_by_id(id: String) -> Dictionary`
  - `GameDatabase.drop_table_for_tier(tier: String) -> Array`
  - `GameDatabase.scoring_rules() -> Dictionary`

- [ ] **Step 1: Write the failing database contract test**

Create `tests/assert_phase4_data_systems.gd`:

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

func _ids(entries: Array) -> Array:
	var result: Array = []
	for entry in entries:
		result.append(String(entry.get("id", "")))
	return result

func _assert_keys(value: Dictionary, keys: Array, context: String) -> void:
	for key in keys:
		_assert(value.has(key), "%s missing %s: %s" % [context, key, value])

func _assert_drop_table(table: Array, tier: String) -> void:
	_assert(table.size() >= 4, "%s drop table should have at least 4 weighted entries." % tier)
	var total := 0.0
	var has_bomb_fragment := false
	var has_life_fragment := false
	var has_seal := false
	for entry in table:
		_assert_keys(entry, ["id", "weight"], "%s drop entry" % tier)
		total += float(entry.weight)
		if String(entry.id) == "bomb_fragment":
			has_bomb_fragment = true
		if String(entry.id) == "life_fragment":
			has_life_fragment = true
		if String(entry.id) == "night_festival_seal":
			has_seal = true
	_assert(abs(total - 1.0) <= 0.001, "%s drop table weights should sum to 1.0, got %f" % [tier, total])
	_assert(has_bomb_fragment, "%s drop table should include bomb_fragment." % tier)
	_assert(has_life_fragment, "%s drop table should include life_fragment." % tier)
	_assert(has_seal, "%s drop table should include night_festival_seal." % tier)

func _init() -> void:
	var db_script = load("res://scripts/data/game_database.gd")
	if not _assert(db_script != null, "Could not load game_database.gd"):
		return
	var db = db_script.new()

	for method in ["enemy_families", "enemy_family_by_id", "bullet_family_by_id", "item_type_by_id", "drop_table_for_tier", "scoring_rules"]:
		if not _assert(db.has_method(method), "GameDatabase missing method %s" % method):
			return

	var expected_enemy_ids := ["low_yokai", "fast_attacker", "formation_shooter", "elite_yokai", "mechanism"]
	_assert_equal(_ids(db.enemy_families()), expected_enemy_ids, "Enemy family ids mismatch.")
	for family in db.enemy_families():
		_assert_keys(family, ["id", "display_name", "role", "base_hp", "radius", "shoot_interval", "default_pattern", "bullet_family", "drop_tier", "density"], "enemy family %s" % String(family.get("id", "")))
		_assert(float(family.base_hp) > 0.0, "Enemy family base_hp should be positive.")
		_assert(float(family.radius) >= 10.0, "Enemy family radius should be readable.")
		_assert(float(family.shoot_interval) >= 24.0, "Enemy family shoot interval should be fair.")
		_assert(float(family.density) > 0.0 and float(family.density) <= 1.5, "Enemy density should stay bounded.")

	var expected_bullet_ids := ["circle", "rice", "butterfly", "needle", "talisman", "star", "laser", "large_orb"]
	_assert_equal(_ids(db.bullet_families()), expected_bullet_ids, "Enemy bullet family ids mismatch.")
	for family in db.bullet_families():
		_assert_keys(family, ["id", "display_name", "collision", "role", "radius", "speed_multiplier", "collision_radius", "color", "draw_group"], "bullet family %s" % String(family.get("id", "")))
		_assert(float(family.radius) >= float(family.collision_radius), "Bullet visual radius should be >= collision radius.")
		_assert(float(family.speed_multiplier) > 0.0, "Bullet speed multiplier should be positive.")
	_assert_equal(String(db.bullet_family_by_id("needle").collision), "thin", "Needle collision schema mismatch.")
	_assert_equal(db.bullet_family_by_id("missing"), {}, "Unknown bullet family should return empty Dictionary.")

	var expected_item_ids := ["power", "point", "bomb_fragment", "life_fragment", "night_festival_seal", "full_power"]
	_assert_equal(_ids(db.item_types()), expected_item_ids, "Item type ids mismatch.")
	for item in db.item_types():
		_assert_keys(item, ["id", "display_name", "role", "base_score", "collect_behavior"], "item %s" % String(item.get("id", "")))
		_assert(int(item.base_score) >= 0, "Item base_score should be non-negative.")
	_assert_equal(int(db.item_type_by_id("bomb_fragment").fragment_goal), 3, "Bomb fragment goal should be 3.")
	_assert_equal(int(db.item_type_by_id("life_fragment").fragment_goal), 5, "Life fragment goal should be 5.")
	_assert_equal(db.item_type_by_id("missing"), {}, "Unknown item type should return empty Dictionary.")

	_assert_drop_table(db.drop_table_for_tier("light"), "light")
	_assert_drop_table(db.drop_table_for_tier("standard"), "standard")
	_assert_drop_table(db.drop_table_for_tier("rich"), "rich")
	_assert_drop_table(db.drop_table_for_tier("mechanism"), "mechanism")

	var scoring: Dictionary = db.scoring_rules()
	_assert_keys(scoring, ["enemy_defeat", "graze", "point_base", "top_collection_multiplier", "night_festival_seal_base", "night_festival_seal_step", "spell_card_no_miss_bonus", "spell_card_no_bomb_bonus"], "scoring rules")
	_assert_equal(int(scoring.enemy_defeat), 50, "Enemy defeat score should preserve existing reward.")
	_assert_equal(int(scoring.graze), 10, "Graze score should preserve existing reward.")
	_assert(float(scoring.top_collection_multiplier) > 1.0, "Top collection should reward high collection.")
	_assert(int(scoring.night_festival_seal_base) >= 1000, "Night Festival Seal should be a high-value bonus.")

	quit(0)
```

- [ ] **Step 2: Run the data contract test and verify it fails**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase4_data_systems.gd'
```

Expected: FAIL because the Phase 4 database methods and required schema fields do not exist yet.

- [ ] **Step 3: Add enemy family data**

Add `ENEMY_FAMILIES` to `scripts/data/game_database.gd`:

```gdscript
const ENEMY_FAMILIES := [
	{"id": "low_yokai", "display_name": "Low Yokai", "role": "tutorial pressure", "base_hp": 8.0, "radius": 14.0, "shoot_interval": 72.0, "default_pattern": "aimed", "bullet_family": "circle", "drop_tier": "light", "density": 0.65},
	{"id": "fast_attacker", "display_name": "Fast Attacker", "role": "lane route check", "base_hp": 9.0, "radius": 13.0, "shoot_interval": 84.0, "default_pattern": "downward", "bullet_family": "needle", "drop_tier": "light", "density": 0.75},
	{"id": "formation_shooter", "display_name": "Formation Shooter", "role": "synchronized rings and spreads", "base_hp": 14.0, "radius": 15.0, "shoot_interval": 66.0, "default_pattern": "ring", "bullet_family": "star", "drop_tier": "standard", "density": 1.0},
	{"id": "elite_yokai", "display_name": "Elite Yokai", "role": "durable pressure source", "base_hp": 24.0, "radius": 18.0, "shoot_interval": 48.0, "default_pattern": "double_spread", "bullet_family": "talisman", "drop_tier": "rich", "density": 1.2},
	{"id": "mechanism", "display_name": "Mechanism Enemy", "role": "stage object behavior", "base_hp": 18.0, "radius": 16.0, "shoot_interval": 60.0, "default_pattern": "wave", "bullet_family": "rice", "drop_tier": "mechanism", "density": 0.95},
]
```

- [ ] **Step 4: Extend enemy bullet family data**

Replace the current `BULLET_FAMILIES` dictionaries with the same eight ids and these additional fields:

```gdscript
{"id": "circle", "display_name": "Circle Bullet", "collision": "round", "role": "baseline_pressure", "radius": 5.0, "speed_multiplier": 1.0, "collision_radius": 5.0, "color": Color(0.78, 0.36, 1.0), "draw_group": "round_small"}
{"id": "rice", "display_name": "Rice Bullet", "collision": "round", "role": "woven_paths", "radius": 4.5, "speed_multiplier": 0.95, "collision_radius": 4.0, "color": Color(0.16, 0.86, 0.94), "draw_group": "rice_small"}
{"id": "butterfly", "display_name": "Butterfly Bullet", "collision": "round", "role": "decorative_spread", "radius": 5.5, "speed_multiplier": 0.9, "collision_radius": 4.5, "color": Color(1.0, 0.35, 0.78), "draw_group": "butterfly"}
{"id": "needle", "display_name": "Needle Bullet", "collision": "thin", "role": "fast_aimed_pressure", "radius": 4.0, "speed_multiplier": 1.35, "collision_radius": 3.0, "color": Color(1.0, 0.72, 0.2), "draw_group": "needle"}
{"id": "talisman", "display_name": "Talisman Bullet", "collision": "round", "role": "spell_theme", "radius": 5.0, "speed_multiplier": 1.05, "collision_radius": 4.5, "color": Color(0.95, 0.22, 0.25), "draw_group": "talisman"}
{"id": "star", "display_name": "Star Bullet", "collision": "round", "role": "magical_spread", "radius": 5.0, "speed_multiplier": 1.0, "collision_radius": 4.5, "color": Color(0.45, 0.66, 1.0), "draw_group": "star"}
{"id": "laser", "display_name": "Laser", "collision": "line", "role": "lane_denial", "radius": 6.0, "speed_multiplier": 1.2, "collision_radius": 5.0, "color": Color(1.0, 0.42, 0.18), "draw_group": "laser_warning"}
{"id": "large_orb", "display_name": "Large Orb", "collision": "round", "role": "space_control", "radius": 10.0, "speed_multiplier": 0.65, "collision_radius": 8.0, "color": Color(0.62, 0.38, 1.0), "draw_group": "orb_large"}
```

- [ ] **Step 5: Extend item and scoring data**

Replace the current `ITEM_TYPES` dictionaries with the same six core ids and these additional fields:

```gdscript
{"id": "power", "display_name": "Power", "role": "shot_power", "base_score": 10, "collect_behavior": "power"}
{"id": "point", "display_name": "Point Item", "role": "score", "base_score": 10, "collect_behavior": "point"}
{"id": "bomb_fragment", "display_name": "Bomb Fragment", "role": "three_make_bomb", "base_score": 100, "collect_behavior": "bomb_fragment", "fragment_goal": 3}
{"id": "life_fragment", "display_name": "Life Fragment", "role": "five_make_life", "base_score": 500, "collect_behavior": "life_fragment", "fragment_goal": 5}
{"id": "night_festival_seal", "display_name": "Night Festival Seal", "role": "risk_score_bonus", "base_score": 1000, "collect_behavior": "night_festival_seal"}
{"id": "full_power", "display_name": "Full Power", "role": "recovery", "base_score": 300, "collect_behavior": "full_power"}
```

Add:

```gdscript
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
```

- [ ] **Step 6: Add lookup helpers**

Add:

```gdscript
func enemy_families() -> Array:
	return ENEMY_FAMILIES.duplicate(true)

func enemy_family_by_id(id: String) -> Dictionary:
	for family in ENEMY_FAMILIES:
		if String(family.id) == id:
			return family.duplicate(true)
	return {}

func bullet_family_by_id(id: String) -> Dictionary:
	for family in BULLET_FAMILIES:
		if String(family.id) == id:
			return family.duplicate(true)
	return {}

func item_type_by_id(id: String) -> Dictionary:
	for item in ITEM_TYPES:
		if String(item.id) == id:
			return item.duplicate(true)
	return {}

func drop_table_for_tier(tier: String) -> Array:
	if DROP_TABLES.has(tier):
		return DROP_TABLES[tier].duplicate(true)
	return DROP_TABLES["standard"].duplicate(true)

func scoring_rules() -> Dictionary:
	return SCORING_RULES.duplicate(true)
```

- [ ] **Step 7: Run the data contract test and verify it passes**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase4_data_systems.gd'
```

Expected: PASS, exit code 0.

- [ ] **Step 8: Run existing database regression tests**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_game_database.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase3_protagonist_profiles.gd'
```

Expected: both PASS, exit code 0.

- [ ] **Step 9: Commit**

```powershell
git add scripts/data/game_database.gd tests/assert_phase4_data_systems.gd
git commit -m "feat: add phase 4 gameplay data contracts"
```

---

### Task 2: Enemy Family Pattern Executor

**Files:**
- Create: `scripts/runtime/enemy_pattern_executor.gd`
- Create: `tests/assert_phase4_enemy_pattern_executor.gd`
- Modify: `scripts/main.gd`

**Interfaces:**
- Consumes: `GameDatabase.enemy_family_by_id(id)`, `GameDatabase.bullet_family_by_id(id)`, `GameDatabase.scoring_rules()`.
- Produces:
  - `EnemyPatternExecutor.family_id_for_pattern(pattern: String, strong: bool = false) -> String`
  - `EnemyPatternExecutor.spawn_config(pattern: String, base_hp: float, stage_hp_mult: float, strong: bool = false) -> Dictionary`
  - `EnemyPatternExecutor.bullet_specs(enemy: Dictionary, player_position: Vector2, stage_bullet_speed: float) -> Array`
  - `scripts/main.gd` method `_spawn_enemy_bullet_spec(spec: Dictionary) -> void`
  - `scripts/main.gd` spawned enemies include `family_id`, `drop_tier`, and `shoot_interval`.

- [ ] **Step 1: Write the failing enemy executor test**

Create `tests/assert_phase4_enemy_pattern_executor.gd`:

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

func _assert_spec(spec: Dictionary, family_id: String) -> void:
	for key in ["position", "velocity", "radius", "color", "family_id", "lifetime"]:
		_assert(spec.has(key), "Bullet spec missing %s: %s" % [key, spec])
	_assert_equal(String(spec.family_id), family_id, "Bullet spec family mismatch.")
	_assert(spec.position is Vector2, "Bullet spec position should be Vector2.")
	_assert(spec.velocity is Vector2, "Bullet spec velocity should be Vector2.")
	_assert(float(spec.radius) >= 3.0, "Bullet radius should be readable.")
	_assert(float(spec.lifetime) > 0.0, "Bullet lifetime should be positive.")

func _verify_executor() -> void:
	var executor_script = load("res://scripts/runtime/enemy_pattern_executor.gd")
	if not _assert(executor_script != null, "Could not load enemy_pattern_executor.gd"):
		return
	var executor = executor_script.new()
	for method in ["family_id_for_pattern", "spawn_config", "bullet_specs"]:
		if not _assert(executor.has_method(method), "EnemyPatternExecutor missing method %s" % method):
			return

	_assert_equal(executor.family_id_for_pattern("aimed"), "low_yokai", "aimed family mismatch.")
	_assert_equal(executor.family_id_for_pattern("downward"), "fast_attacker", "downward family mismatch.")
	_assert_equal(executor.family_id_for_pattern("ring"), "formation_shooter", "ring family mismatch.")
	_assert_equal(executor.family_id_for_pattern("double_spread"), "elite_yokai", "double_spread family mismatch.")
	_assert_equal(executor.family_id_for_pattern("wave"), "mechanism", "wave family mismatch.")
	_assert_equal(executor.family_id_for_pattern("aimed", true), "elite_yokai", "strong aimed enemies should use elite family metadata.")

	var cfg: Dictionary = executor.spawn_config("ring", 10.0, 1.5, false)
	_assert_equal(String(cfg.family_id), "formation_shooter", "Spawn config family mismatch.")
	_assert(abs(float(cfg.hp) - 30.0) <= 0.001, "Spawn config should preserve existing 2x HP and apply stage hp mult, got %f" % float(cfg.hp))
	_assert_equal(String(cfg.drop_tier), "standard", "Formation shooter drop tier mismatch.")
	_assert(float(cfg.shoot_interval) >= 24.0, "Spawn config shoot interval should be bounded.")

	var enemy := {"x": 200.0, "y": 120.0, "pattern": "aimed", "shoot_phase": 1}
	var aimed: Array = executor.bullet_specs(enemy, Vector2(360.0, 540.0), 1.0)
	_assert_equal(aimed.size(), 1, "aimed should emit one bullet.")
	_assert_spec(aimed[0], "circle")

	enemy.pattern = "downward"
	var downward: Array = executor.bullet_specs(enemy, Vector2(360.0, 540.0), 1.0)
	_assert_equal(downward.size(), 1, "downward should emit one bullet.")
	_assert_spec(downward[0], "needle")
	_assert(float(downward[0].velocity.y) > 0.0, "downward bullet should move down.")

	enemy.pattern = "ring"
	var ring: Array = executor.bullet_specs(enemy, Vector2(360.0, 540.0), 1.0)
	_assert_equal(ring.size(), 12, "ring should emit 12 bullets.")
	_assert_spec(ring[0], "star")

	enemy.pattern = "double_spread"
	var double_spread: Array = executor.bullet_specs(enemy, Vector2(360.0, 540.0), 1.0)
	_assert_equal(double_spread.size(), 5, "double_spread should emit 5 bullets.")
	_assert_spec(double_spread[0], "talisman")

	enemy.pattern = "wave"
	var wave: Array = executor.bullet_specs(enemy, Vector2(360.0, 540.0), 1.0)
	_assert_equal(wave.size(), 5, "wave should emit 5 bullets.")
	_assert_spec(wave[0], "rice")

	enemy.pattern = "spiral"
	var spiral: Array = executor.bullet_specs(enemy, Vector2(360.0, 540.0), 1.0)
	_assert_equal(spiral.size(), 8, "spiral should emit 8 bullets.")
	_assert_spec(spiral[0], "butterfly")

func _verify_main_spawn_contract() -> void:
	var gm = load("res://autoload/game_manager.gd").new()
	var main_script = load("res://scripts/main.gd")
	if not _assert(main_script != null, "Could not load main.gd"):
		gm.free()
		return
	var main_shell = main_script.new()
	main_shell.game_manager_ref = gm
	gm.current_stage = 6
	main_shell.enemies = []
	for method in ["_spawn_enemy", "_spawn_enemy_bullet_spec"]:
		if not _assert(main_shell.has_method(method), "Main missing method %s" % method):
			main_shell.free()
			gm.free()
			return
	main_shell._spawn_enemy(100.0, 20.0, 10.0, "ring", "straight", 0.0, 1.0, {}, false)
	_assert_equal(main_shell.enemies.size(), 1, "Main should spawn one enemy.")
	var enemy: Dictionary = main_shell.enemies[0]
	_assert_equal(String(enemy.family_id), "formation_shooter", "Main enemy should include family_id.")
	_assert_equal(String(enemy.drop_tier), "standard", "Main enemy should include drop_tier.")
	_assert(float(enemy.hp) > 20.0, "Stage 6 enemy HP should apply stage hp multiplier after existing 2x baseline.")
	_assert(float(enemy.shoot_interval) >= 24.0, "Main enemy should include bounded shoot_interval.")
	main_shell.bullet_pool = []
	for i in range(8):
		main_shell.bullet_pool.append(main_shell._make_bullet())
	main_shell._spawn_enemy_bullet_spec({"position": Vector2(10, 10), "velocity": Vector2(1, 2), "radius": 4.0, "color": Color.YELLOW, "family_id": "needle", "lifetime": 120.0})
	_assert_equal(String(main_shell.bullet_pool[0].type), "needle", "Main should spawn enemy bullet by data family id.")
	main_shell.free()
	gm.free()

func _init() -> void:
	_verify_executor()
	if failed:
		return
	_verify_main_spawn_contract()
	if failed:
		return
	quit(0)
```

- [ ] **Step 2: Run the enemy executor test and verify it fails**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase4_enemy_pattern_executor.gd'
```

Expected: FAIL because `enemy_pattern_executor.gd` and main integration do not exist yet.

- [ ] **Step 3: Add the pure enemy pattern executor**

Create `scripts/runtime/enemy_pattern_executor.gd`:

```gdscript
extends RefCounted
class_name EnemyPatternExecutor

var _database = load("res://scripts/data/game_database.gd").new()

func family_id_for_pattern(pattern: String, strong: bool = false) -> String:
	if strong:
		return "elite_yokai"
	match pattern:
		"downward":
			return "fast_attacker"
		"spread", "ring":
			return "formation_shooter"
		"double_spread":
			return "elite_yokai"
		"wave":
			return "mechanism"
		"spiral":
			return "elite_yokai"
		_:
			return "low_yokai"

func spawn_config(pattern: String, base_hp: float, stage_hp_mult: float, strong: bool = false) -> Dictionary:
	var family_id := family_id_for_pattern(pattern, strong)
	var family: Dictionary = _database.enemy_family_by_id(family_id)
	if family.is_empty():
		family = _database.enemy_family_by_id("low_yokai")
	var hp := base_hp * 2.0 * maxf(0.1, stage_hp_mult)
	var shoot_interval := maxf(24.0, float(family.get("shoot_interval", 60.0)) * (0.8 if strong else 1.0))
	return {
		"family_id": family_id,
		"hp": hp,
		"radius": float(family.get("radius", 14.0)),
		"drop_tier": String(family.get("drop_tier", "standard")),
		"shoot_interval": shoot_interval,
	}
```

Implement `bullet_specs(enemy, player_position, stage_bullet_speed)` with the existing enemy pattern shapes:

```text
aimed: 1 circle bullet toward player, base speed 2.5.
spread: 3 circle bullets at offsets -0.3, 0, 0.3, base speed 2.5.
ring: 12 star bullets, rotating by shoot_phase * 0.3, base speed 2.0.
double_spread: 5 talisman bullets at offsets -0.5, -0.25, 0, 0.25, 0.5, base speed 2.2.
downward: 1 needle bullet, velocity (0, 3.5).
wave: 5 rice bullets with the current sine wave angles.
spiral: 8 butterfly bullets, rotating by shoot_phase * 0.12, base speed 2.5.
```

Each returned dictionary must contain:

```gdscript
{
	"position": Vector2,
	"velocity": Vector2,
	"radius": float,
	"color": Color,
	"family_id": String,
	"lifetime": 350.0,
}
```

Use `GameDatabase.bullet_family_by_id(family_id)` for `radius`, `color`, and `speed_multiplier`; final speed is `base_speed * stage_bullet_speed * speed_multiplier`.

- [ ] **Step 4: Wire enemy spawn metadata into main**

Modify `scripts/main.gd` near the other runtime helpers:

```gdscript
var enemy_pattern_executor: Object = load("res://scripts/runtime/enemy_pattern_executor.gd").new()
```

Add:

```gdscript
func _stage_enemy_hp_mult() -> float:
	_resolve_singletons()
	if game_manager_ref and game_manager_ref.current_stage >= 1 and game_manager_ref.current_stage <= game_manager_ref.STAGE_MULTS.size():
		return float(game_manager_ref.STAGE_MULTS[game_manager_ref.current_stage - 1].enemy_hp)
	return 1.0

func _spawn_enemy_bullet_spec(spec: Dictionary) -> void:
	_spawn_bullet_enemy(
		float(spec.position.x),
		float(spec.position.y),
		float(spec.velocity.x),
		float(spec.velocity.y),
		float(spec.radius),
		spec.get("color", Color.RED),
		String(spec.family_id),
		float(spec.get("lifetime", 350.0))
	)
```

Modify `_spawn_enemy` so it calls:

```gdscript
var cfg: Dictionary = enemy_pattern_executor.spawn_config(pattern, hp, _stage_enemy_hp_mult(), strong)
var ehp: float = float(cfg.hp)
```

The appended enemy dictionary must include:

```gdscript
"family_id": String(cfg.family_id),
"drop_tier": String(cfg.drop_tier),
"shoot_interval": float(cfg.shoot_interval),
"radius": float(cfg.radius),
```

- [ ] **Step 5: Replace inline enemy firing with the executor**

Inside `_update_enemies(delta)`, replace the existing `match e.pattern:` firing block with:

```gdscript
e.shoot_timer = float(e.get("shoot_interval", 60.0))
e.shoot_phase += 1
var mult: float = game_manager_ref.STAGE_MULTS[game_manager_ref.current_stage - 1].bullet_speed
for spec in enemy_pattern_executor.bullet_specs(e, Vector2(player_x, player_y), mult):
	_spawn_enemy_bullet_spec(spec)
```

Keep the existing on-screen gating and dying checks.

- [ ] **Step 6: Run the enemy executor test and verify it passes**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase4_enemy_pattern_executor.gd'
```

Expected: PASS, exit code 0.

- [ ] **Step 7: Run affected regression tests**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase3_shot_patterns.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase3_bomb_contract.gd'
```

Expected: both PASS, exit code 0.

- [ ] **Step 8: Commit**

```powershell
git add scripts/main.gd scripts/runtime/enemy_pattern_executor.gd tests/assert_phase4_enemy_pattern_executor.gd
git commit -m "feat: drive enemies from phase 4 data"
```

---

### Task 3: Item Reward And Scoring System

**Files:**
- Create: `scripts/runtime/item_reward_system.gd`
- Create: `tests/assert_phase4_item_reward_system.gd`
- Modify: `autoload/game_manager.gd`
- Modify: `scripts/main.gd`

**Interfaces:**
- Consumes: `GameDatabase.item_type_by_id(id)`, `GameDatabase.drop_table_for_tier(tier)`, `GameDatabase.scoring_rules()`.
- Produces:
  - `GameManager.night_festival_seals: int`
  - `ItemRewardSystem.choose_drop(tier: String, roll: float) -> String`
  - `ItemRewardSystem.apply_collection(item_type: String, game_manager_ref: Object, collection_y: float, top_collection_y: float) -> Dictionary`
  - `scripts/main.gd` method `_drop_item_type(strong: bool, roll: float, drop_tier: String = "") -> String`
  - `scripts/main.gd` `_drop_item()` and `_collect_item()` use `ItemRewardSystem`.

- [ ] **Step 1: Write the failing item reward test**

Create `tests/assert_phase4_item_reward_system.gd`:

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

func _verify_reward_system() -> void:
	var reward_script = load("res://scripts/runtime/item_reward_system.gd")
	if not _assert(reward_script != null, "Could not load item_reward_system.gd"):
		return
	var rewards = reward_script.new()
	for method in ["choose_drop", "apply_collection"]:
		if not _assert(rewards.has_method(method), "ItemRewardSystem missing method %s" % method):
			return

	_assert_equal(rewards.choose_drop("light", 0.01), "power", "light low roll mismatch.")
	_assert_equal(rewards.choose_drop("light", 0.60), "bomb_fragment", "light bomb fragment roll mismatch.")
	_assert_equal(rewards.choose_drop("light", 0.80), "life_fragment", "light life fragment roll mismatch.")
	_assert_equal(rewards.choose_drop("light", 0.90), "night_festival_seal", "light seal roll mismatch.")
	_assert_equal(rewards.choose_drop("rich", 0.05), "point", "rich low roll mismatch.")
	_assert_equal(rewards.choose_drop("rich", 0.30), "bomb_refill", "rich bomb refill roll mismatch.")

	var gm = load("res://autoload/game_manager.gd").new()
	_assert(gm.has_method("reset"), "GameManager should have reset.")
	_assert(gm.get("night_festival_seals") != null, "GameManager should expose night_festival_seals.")
	gm.score = 0
	gm.shared_power = 10
	var point_result: Dictionary = rewards.apply_collection("point", gm, 64.0, 128.0)
	_assert_equal(String(point_result.type), "point", "Point result type mismatch.")
	_assert_equal(int(gm.score), 220, "Top-collected point item should use power scaling and top multiplier.")

	gm.bombs = 0
	gm.bomb_fragments = 2
	rewards.apply_collection("bomb_fragment", gm, 400.0, 128.0)
	_assert_equal(gm.bombs, 1, "Third bomb fragment should grant one bomb.")
	_assert_equal(gm.bomb_fragments, 0, "Third bomb fragment should consume fragments.")

	gm.lives = 3
	gm.life_fragments = 4
	rewards.apply_collection("life_fragment", gm, 400.0, 128.0)
	_assert_equal(gm.lives, 4, "Fifth life fragment should grant one life.")
	_assert_equal(gm.life_fragments, 0, "Fifth life fragment should consume fragments.")

	gm.score = 0
	gm.night_festival_seals = 0
	rewards.apply_collection("night_festival_seal", gm, 420.0, 128.0)
	_assert_equal(gm.night_festival_seals, 1, "Night Festival Seal should increment seal counter.")
	_assert(int(gm.score) >= 1000, "Night Festival Seal should grant a high score bonus.")
	gm.reset()
	_assert_equal(gm.night_festival_seals, 0, "GameManager reset should clear Night Festival Seals.")
	gm.free()

func _verify_main_item_contract() -> void:
	var gm = load("res://autoload/game_manager.gd").new()
	var main_script = load("res://scripts/main.gd")
	if not _assert(main_script != null, "Could not load main.gd"):
		gm.free()
		return
	var main_shell = main_script.new()
	main_shell.game_manager_ref = gm
	for method in ["_drop_item_type", "_collect_item"]:
		if not _assert(main_shell.has_method(method), "Main missing method %s" % method):
			main_shell.free()
			gm.free()
			return
	_assert_equal(main_shell._drop_item_type(false, 0.90, "light"), "night_festival_seal", "Main drop helper should use database light table.")
	_assert_equal(main_shell._drop_item_type(true, 0.30, "rich"), "bomb_refill", "Main drop helper should use rich table.")
	main_shell._collect_item({"alive": true, "collected": false, "type": "night_festival_seal", "x": 0.0, "y": 420.0})
	_assert_equal(gm.night_festival_seals, 1, "Main collection should apply Night Festival Seal reward.")
	main_shell.free()
	gm.free()

func _init() -> void:
	_verify_reward_system()
	if failed:
		return
	_verify_main_item_contract()
	if failed:
		return
	quit(0)
```

- [ ] **Step 2: Run the item reward test and verify it fails**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase4_item_reward_system.gd'
```

Expected: FAIL because `item_reward_system.gd`, `night_festival_seals`, and main item integration do not exist yet.

- [ ] **Step 3: Add Night Festival Seal state**

Modify `autoload/game_manager.gd`:

```gdscript
var night_festival_seals: int = 0
```

In `reset()` set:

```gdscript
night_festival_seals = 0
```

- [ ] **Step 4: Add the pure item reward helper**

Create `scripts/runtime/item_reward_system.gd`:

```gdscript
extends RefCounted
class_name ItemRewardSystem

var _database = load("res://scripts/data/game_database.gd").new()

func choose_drop(tier: String, roll: float) -> String:
	var table: Array = _database.drop_table_for_tier(tier)
	var threshold := clampf(roll, 0.0, 0.999999)
	var running := 0.0
	for entry in table:
		running += float(entry.get("weight", 0.0))
		if threshold < running:
			return String(entry.get("id", "power"))
	return "power"
```

Implement `apply_collection(item_type, game_manager_ref, collection_y, top_collection_y)` so it mutates `game_manager_ref` and returns a summary dictionary with `type`, `score_delta`, and `resource_delta`.

Exact reward rules:

```text
bullet_spread/bullet_linear/bullet_homing: add_power(2), score +120, no shot switching.
power: add_power(1), score +10.
point: score += 10 * (1 + shared_power), doubled when collection_y <= top_collection_y.
bomb_refill: bombs +1 capped at 5, score +100.
bomb_fragment: bomb_fragments +1, every 3 fragments grants bombs +1 capped at 5 and subtracts 3 fragments, score +100.
life: lives +1 capped at 6, score +500.
life_fragment: life_fragments +1, every 5 fragments grants lives +1 capped at 6 and subtracts 5 fragments, score +500.
night_festival_seal: night_festival_seals +1, score += int(1000 * (1.0 + night_festival_seals * 0.05)).
full_power: shared_power = 50, score +300.
unknown item: score_delta 0, no state changes.
```

- [ ] **Step 5: Wire item rewards into main**

Modify `scripts/main.gd` near runtime helpers:

```gdscript
var item_reward_system: Object = load("res://scripts/runtime/item_reward_system.gd").new()
```

Add:

```gdscript
func _drop_item_type(strong: bool, roll: float, drop_tier: String = "") -> String:
	var tier := drop_tier
	if tier == "":
		tier = "rich" if strong else "light"
	return item_reward_system.choose_drop(tier, roll)
```

Modify `_drop_item(x, y, strong)`:

```gdscript
func _drop_item(x: float, y: float, strong: bool, drop_tier: String = ""):
	var t: String = _drop_item_type(strong, randf(), drop_tier)
	items.append({
		"alive": true,
		"collected": false,
		"x": x,
		"y": y,
		"type": t,
		"radius": 9.0,
		"vy": -2.5,
		"vx": randf_range(-0.3, 0.3),
		"floating": true,
		"target_y": 128.0,
		"drift_dir": 0.0,
		"sway": randf_range(0, TAU),
		"birth": 15.0,
		"anim": randf_range(0, TAU),
	})
```

Modify the enemy death call from:

```gdscript
_drop_item(e.x, e.y, e.strong)
game_manager_ref.score += 50
```

to:

```gdscript
_drop_item(e.x, e.y, e.strong, String(e.get("drop_tier", "")))
game_manager_ref.score += int(game_database_ref.scoring_rules().enemy_defeat) if game_database_ref else 50
```

If `main.gd` does not already have a database reference, add:

```gdscript
var game_database_ref = load("res://scripts/data/game_database.gd").new()
```

Modify `_collect_item(it)`:

```gdscript
it.collected = true
it.alive = false
item_reward_system.apply_collection(String(it.type), game_manager_ref, float(it.get("y", player_y)), game_manager_ref.SCREEN_H * game_manager_ref.ITEM_TOP_RATIO)
```

- [ ] **Step 6: Draw Night Festival Seal items and HUD**

In item drawing, add a `night_festival_seal` case:

```gdscript
"night_festival_seal":
	var seal_pts: PackedVector2Array = PackedVector2Array([Vector2(ix, iy - 11), Vector2(ix + 8, iy - 3), Vector2(ix + 7, iy + 8), Vector2(ix - 7, iy + 8), Vector2(ix - 8, iy - 3)])
	draw_colored_polygon(seal_pts, Color(0.85, 0.18, 0.34))
	draw_polyline(seal_pts, Color.WHITE, 1, true)
	draw_line(Vector2(ix - 4, iy), Vector2(ix + 4, iy), Color(1.0, 0.86, 0.42), 2)
```

In the HUD area near score/graze, add:

```gdscript
draw_string(font, Vector2(10, 80), "Seals: %d" % gm.night_festival_seals)
```

Keep existing life/bomb/shot lines readable and do not overlap them.

- [ ] **Step 7: Run the item reward test and verify it passes**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase4_item_reward_system.gd'
```

Expected: PASS, exit code 0.

- [ ] **Step 8: Run affected regression tests**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase3_ui_loadout_contract.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_pause_contract.gd'
```

Expected: both PASS, exit code 0.

- [ ] **Step 9: Commit**

```powershell
git add autoload/game_manager.gd scripts/main.gd scripts/runtime/item_reward_system.gd tests/assert_phase4_item_reward_system.gd
git commit -m "feat: add item reward data system"
```

---

### Task 4: Main Bullet-Family Integration

**Files:**
- Create: `tests/assert_phase4_main_data_integration.gd`
- Modify: `scripts/main.gd`

**Interfaces:**
- Consumes: `GameDatabase.bullet_families()`, `EnemyPatternExecutor`, and `ItemRewardSystem`.
- Produces:
  - `scripts/main.gd` method `_enemy_bullet_types() -> Array`
  - `scripts/main.gd` method `_is_enemy_bullet_type(type_id: String) -> bool`
  - All eight Phase 4 bullet families count as enemy bullets for counters, player collision, graze, and bomb clearing.
  - Legacy boss `arrow` bullets remain enemy bullets for backwards compatibility.

- [ ] **Step 1: Write the failing main integration test**

Create `tests/assert_phase4_main_data_integration.gd`:

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

func _new_main_with_pool() -> Node:
	var gm = load("res://autoload/game_manager.gd").new()
	var main_shell = load("res://scripts/main.gd").new()
	main_shell.game_manager_ref = gm
	main_shell.bullet_pool = []
	for i in range(32):
		main_shell.bullet_pool.append(main_shell._make_bullet())
	return main_shell

func _activate_bullet(main_shell: Node, idx: int, type_id: String, x: float, y: float) -> void:
	var bullet: Dictionary = main_shell.bullet_pool[idx]
	bullet.active = true
	bullet.type = type_id
	bullet.x = x
	bullet.y = y
	bullet.vx = 0.0
	bullet.vy = 0.0
	bullet.radius = 5.0
	bullet.age = 0.0
	bullet.lifetime = 120.0
	main_shell.bullet_pool[idx] = bullet

func _verify_bullet_family_contract() -> void:
	var main_shell = _new_main_with_pool()
	for method in ["_enemy_bullet_types", "_is_enemy_bullet_type", "_count_active_bullets_by_owner", "_check_collisions"]:
		if not _assert(main_shell.has_method(method), "Main missing method %s" % method):
			main_shell.game_manager_ref.free()
			main_shell.free()
			return

	var expected := ["circle", "rice", "butterfly", "needle", "talisman", "star", "laser", "large_orb"]
	for type_id in expected:
		_assert(main_shell._enemy_bullet_types().has(type_id), "Enemy bullet type list missing %s" % type_id)
		_assert(main_shell._is_enemy_bullet_type(type_id), "%s should be classified as enemy bullet." % type_id)
	_assert(main_shell._is_enemy_bullet_type("arrow"), "Legacy arrow should remain an enemy bullet.")
	_assert(not main_shell._is_enemy_bullet_type("player"), "player should not be classified as enemy bullet.")
	_assert(not main_shell._is_enemy_bullet_type("bomb"), "bomb should not be classified as enemy bullet.")

	for i in range(expected.size()):
		_activate_bullet(main_shell, i, expected[i], 200.0 + i, 200.0)
	_activate_bullet(main_shell, expected.size(), "arrow", 300.0, 200.0)
	var counts: Dictionary = main_shell._count_active_bullets_by_owner()
	_assert_equal(int(counts.enemy), 9, "All Phase 4 enemy bullet families plus arrow should count as enemy bullets.")
	_assert_equal(int(counts.player), 0, "No player bullets should be active.")
	main_shell.game_manager_ref.free()
	main_shell.free()

func _verify_collision_uses_all_enemy_bullet_families() -> void:
	var main_shell = _new_main_with_pool()
	var gm = main_shell.game_manager_ref
	main_shell.player_x = 360.0
	main_shell.player_y = 540.0
	main_shell.player_invincible = false
	main_shell.player_deathbomb_primed = false
	_activate_bullet(main_shell, 0, "needle", 360.0, 540.0)
	main_shell._check_collisions(false)
	_assert(main_shell.player_deathbomb_primed, "Needle bullet should trigger player hit collision.")
	_assert(not main_shell.bullet_pool[0].active, "Colliding needle bullet should deactivate.")
	main_shell.player_deathbomb_primed = false
	main_shell.player_just_hit = false
	main_shell.player_invincible = true
	gm.graze = 0
	gm.score = 0
	_activate_bullet(main_shell, 1, "large_orb", 360.0 + gm.PLAYER_GRAZE + 8.0, 540.0)
	main_shell._check_collisions(false)
	_assert_equal(gm.graze, 1, "Large orb should be eligible for graze.")
	_assert_equal(gm.score, 10, "Graze score should still use scoring rule value 10.")
	main_shell.game_manager_ref.free()
	main_shell.free()

func _init() -> void:
	_verify_bullet_family_contract()
	if failed:
		return
	_verify_collision_uses_all_enemy_bullet_families()
	if failed:
		return
	quit(0)
```

- [ ] **Step 2: Run the main integration test and verify it fails**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase4_main_data_integration.gd'
```

Expected: FAIL because `main.gd` does not classify all Phase 4 enemy bullet families yet.

- [ ] **Step 3: Add bullet family classification helpers**

Add to `scripts/main.gd`:

```gdscript
func _enemy_bullet_types() -> Array:
	var result: Array = []
	if game_database_ref:
		for family in game_database_ref.bullet_families():
			result.append(String(family.get("id", "")))
	if not result.has("arrow"):
		result.append("arrow")
	return result

func _is_enemy_bullet_type(type_id: String) -> bool:
	return _enemy_bullet_types().has(type_id)
```

- [ ] **Step 4: Replace hard-coded enemy bullet lists**

In `scripts/main.gd`, replace every collision/counter/bomb-clear condition shaped like:

```gdscript
b.type in ["circle","rice","arrow","laser"]
```

or:

```gdscript
b.type in ["circle", "rice", "arrow", "laser"]
```

with:

```gdscript
_is_enemy_bullet_type(String(b.type))
```

Do this in:

```text
Boss bullet clearing around existing lines 671, 790, 803, and 1103.
_count_active_bullets_by_owner().
_check_collisions() hit branch.
_check_collisions() graze branch.
```

- [ ] **Step 5: Use scoring data for graze**

Add:

```gdscript
func _score_value(rule_id: String, fallback: int) -> int:
	if game_database_ref:
		return int(game_database_ref.scoring_rules().get(rule_id, fallback))
	return fallback
```

Replace graze score addition:

```gdscript
game_manager_ref.graze += 1
game_manager_ref.score += _score_value("graze", 10)
```

- [ ] **Step 6: Run the main integration test and verify it passes**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase4_main_data_integration.gd'
```

Expected: PASS, exit code 0.

- [ ] **Step 7: Run affected regression tests**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_bullet_manager.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_performance_monitor.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase3_bomb_contract.gd'
```

Expected: all PASS, exit code 0.

- [ ] **Step 8: Commit**

```powershell
git add scripts/main.gd tests/assert_phase4_main_data_integration.gd
git commit -m "feat: classify phase 4 bullet families in main loop"
```

---

### Task 5: Phase 4 Verification

**Files:**
- Modify: `docs/superpowers/plans/2026-07-09-data-systems-phase4.md` only if checkboxes are updated by the controller.

**Interfaces:**
- Consumes: all Task 1-4 changes.
- Produces: a clean Phase 4 branch ready for final code review and integration.

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
  'res://tests/assert_phase3_ui_loadout_contract.gd',
  'res://tests/assert_phase4_data_systems.gd',
  'res://tests/assert_phase4_enemy_pattern_executor.gd',
  'res://tests/assert_phase4_item_reward_system.gd',
  'res://tests/assert_phase4_main_data_integration.gd'
)
foreach ($test in $tests) {
  & $godot --headless --path 'H:\claude code\godot_touhou' --script $test
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
& $godot --headless --path 'H:\claude code\godot_touhou' --scene 'res://scenes/main.tscn' --quit-after 5
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
git diff --check
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Output 'PHASE4_FINAL_CHECKS_PASS'
```

Expected: `PHASE4_FINAL_CHECKS_PASS`, exit code 0. Non-fatal Godot shutdown resource diagnostics may still print after successful headless runs; do not count them as failures unless the command exits non-zero.

- [ ] **Step 2: Check scratch files and git status**

Run:

```powershell
git status -sb
git ls-files .superpowers
```

Expected: no tracked `.superpowers` files.

- [ ] **Step 3: Controller final code review**

Use `superpowers:requesting-code-review` final whole-branch review with base `master`/`origin/master` at branch start and HEAD after Task 4. Fix Critical/Important findings before merging.

- [ ] **Step 4: Merge and push after final review and verification**

The user's active integration instruction is "merge to master and push"; after final review and verification:

```powershell
git switch master
git merge --ff-only feature/data-systems-phase4
git push origin master
```

Expected: `origin/master` advances to the Phase 4 commits.

---

## Self-Review

- Spec coverage: This plan covers the approved Phase 4 item: data-driven enemy families, enemy bullet families, item resources, scoring rules, and main-loop integration for the current playable loop.
- Out of scope by design: six-stage wave/boss content pass, boss spell-card sequencing, full hand-painted art generation/import, and music expansion remain later phases in the original total specification.
- Placeholder scan: no unresolved placeholder markers or unspecified test command remains.
- Type consistency: helper names are consistent across `GameDatabase`, `EnemyPatternExecutor`, `ItemRewardSystem`, `GameManager`, `main.gd`, and the new tests.
