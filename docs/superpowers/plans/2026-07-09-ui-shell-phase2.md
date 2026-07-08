# UI Shell Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the original production plan's second milestone: 720x960 UI shell, title menu, pause menu, settings, character select, and shot-type select while keeping the current game scene playable.

**Architecture:** Add a deterministic UI model script for menu entries and cursor behavior, extend `GameManager` with production UI states and selected run configuration, then adapt `scripts/main.gd` to route input through title, character, shot, settings, and pause menus. This phase intentionally does not generate or import the full art asset library; that remains phase 6 in the approved total specification.

**Tech Stack:** Godot 4.7, GDScript, headless SceneTree assertion scripts, existing `GameDatabase`, `GameManager`, and single-scene gameplay adapter.

## Global Constraints

- Follow the original implementation sequence from `docs/superpowers/specs/2026-07-09-touhou-full-production-design.md`.
- This is phase 2 only: `720x960 viewport, UI shell, title, pause, settings, and character select`.
- Do not implement phase 6 full art asset generation or import pipeline in this phase.
- Keep the game runnable from `res://scenes/main.tscn`.
- Keep Chinese-facing UI copy readable and not mojibake.
- Preserve the current 720x960 viewport and foundation tests from phase 1.
- Preserve the current gameplay adapter and existing stage/boss flow unless the UI transition requires a narrow hook.

---

## File Structure

- Create `scripts/ui/ui_model.gd`: deterministic menu entries, cursor movement helpers, settings metadata, and selectors.
- Create `tests/assert_ui_shell_model.gd`: headless checks for UI states, menu entries, Chinese labels, settings defaults, and character/shot selection data.
- Modify `autoload/game_manager.gd`: readable Chinese stage names, UI state constants, selected protagonist/shot fields, settings defaults, pause return state, and reset helpers.
- Modify `scripts/main.gd`: title menu, character select, shot select, settings screen, pause menu, menu input, and drawing.
- Modify `project.godot`: add input actions for menu confirm/cancel only if existing actions are insufficient.

---

### Task 1: UI Model And State Contract

**Files:**
- Create: `scripts/ui/ui_model.gd`
- Create: `tests/assert_ui_shell_model.gd`
- Modify: `autoload/game_manager.gd`

**Interfaces:**
- Consumes: `scripts/data/game_database.gd` data structure.
- Produces:
  - `UiModel.main_menu_entries() -> Array`
  - `UiModel.pause_menu_entries() -> Array`
  - `UiModel.settings_entries(settings: Dictionary) -> Array`
  - `UiModel.protagonist_entries() -> Array`
  - `UiModel.shot_entries(protagonist_id: String) -> Array`
  - `UiModel.move_cursor(cursor: int, delta: int, count: int) -> int`
  - `GameManager.STATE_TITLE`, `STATE_CHARACTER_SELECT`, `STATE_SHOT_SELECT`, `STATE_SETTINGS`, `STATE_PAUSED`
  - `GameManager.selected_protagonist_id`, `selected_shot_id`, `pause_return_state`, `settings`

- [ ] **Step 1: Write the failing UI shell model test**

Create `tests/assert_ui_shell_model.gd` with checks that:

- `GameManager.STAGE_NAMES` contains exactly the six readable Chinese labels: `神社参道`, `妖怪市集`, `迷雾竹林`, `天狗山道`, `鬼之宴厅`, `夜祭神域`.
- `GameManager` exposes state constants for title, character select, shot select, settings, paused, stage, boss, stage clear, final clear, and game over.
- `GameManager.reset()` restores title state, shrine maiden protagonist, default shot A, and default settings.
- `UiModel.main_menu_entries()` returns Start Game, Practice, Settings, Exit with Chinese labels.
- `UiModel.pause_menu_entries()` returns Continue, Restart Stage, Settings, Return To Main Menu, Exit Game with Chinese labels.
- `UiModel.protagonist_entries()` returns three protagonists from `GameDatabase`.
- `UiModel.shot_entries("miko")` returns two shot entries.
- `UiModel.move_cursor(0, -1, 4) == 3` and `UiModel.move_cursor(3, 1, 4) == 0`.

- [ ] **Step 2: Run the UI model test and verify it fails**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_ui_shell_model.gd'
```

Expected: FAIL because `scripts/ui/ui_model.gd` does not exist and `GameManager.STAGE_NAMES` is mojibake.

- [ ] **Step 3: Implement `scripts/ui/ui_model.gd`**

Use `load("res://scripts/data/game_database.gd").new()` inside the UI model. Return entries as dictionaries with stable `id`, `label`, and optional `description` keys.

- [ ] **Step 4: Extend `GameManager` UI state contract**

Add state string constants, readable Chinese stage names, selected run configuration, settings defaults, `reset_settings()`, `reset_run_config()`, and make `reset()` call both helpers.

- [ ] **Step 5: Run UI model test and foundation tests**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_ui_shell_model.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_viewport_config.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_game_database.gd'
```

Expected: all commands exit `0`.

- [ ] **Step 6: Commit Task 1**

```powershell
git add autoload/game_manager.gd scripts/ui/ui_model.gd tests/assert_ui_shell_model.gd
git commit -m "feat: add UI shell state model"
```

---

### Task 2: Title, Character Select, Shot Select, And Settings Screens

**Files:**
- Modify: `scripts/main.gd`
- Test: `tests/assert_ui_shell_model.gd`

**Interfaces:**
- Consumes: `UiModel` methods and `GameManager` UI state fields from Task 1.
- Produces:
  - Title menu with Start Game, Practice, Settings, Exit.
  - Start Game transitions to character select.
  - Character select transitions to shot select.
  - Shot select starts the stage with selected protagonist and shot.
  - Settings screen can be opened from title and returns to title with cancel.

- [ ] **Step 1: Add UI model instance and menu cursor fields**

In `scripts/main.gd`, add a `ui_model` instance and cursor fields for main menu, character menu, shot menu, settings menu, and pause menu.

- [ ] **Step 2: Add input helpers**

Add helper methods for:

- `_menu_vertical_delta() -> int` from `move_up` and `move_down`.
- `_menu_confirm_pressed() -> bool` using `shoot`.
- `_menu_cancel_pressed() -> bool` using `bomb` or `pause`.
- `_set_ui_state(next_state: String) -> void`.

- [ ] **Step 3: Replace direct title start with menu routing**

In the `title` state, move cursor with up/down, confirm selected entry, and route:

- `start` -> `character_select`
- `practice` -> `character_select` for now, with `GameManager.practice_mode = true`
- `settings` -> `settings`
- `exit` -> ignore in headless/runtime-safe mode or call `get_tree().quit()` only outside headless if needed

- [ ] **Step 4: Add character and shot select routing**

Character select:

- up/down moves between three protagonists.
- confirm stores `GameManager.selected_protagonist_id`.
- cancel returns to title.

Shot select:

- up/down moves between the selected protagonist's two shot types.
- confirm stores `GameManager.selected_shot_id`, maps to the existing `GameManager.bullet_type` compatibility value, and calls `_start_game()`.
- cancel returns to character select.

- [ ] **Step 5: Add settings routing**

Settings screen:

- up/down moves between settings.
- left/right changes volume/brightness values.
- confirm toggles boolean settings.
- cancel returns to title or paused depending on `GameManager.settings_return_state`.

- [ ] **Step 6: Draw title, character, shot, and settings screens**

Use clear Chinese-first text and 720x960 layout. Avoid nested cards. Keep the existing simple background for now; full art is phase 6.

- [ ] **Step 7: Run checks**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_ui_shell_model.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --scene 'res://scenes/main.tscn' --quit-after 5
```

Expected: both commands exit `0`.

- [ ] **Step 8: Commit Task 2**

```powershell
git add scripts/main.gd tests/assert_ui_shell_model.gd
git commit -m "feat: add title and selection UI flow"
```

---

### Task 3: Pause Menu And Restart/Return Flow

**Files:**
- Modify: `scripts/main.gd`
- Modify: `autoload/game_manager.gd`
- Create: `tests/assert_pause_contract.gd`

**Interfaces:**
- Consumes: `UiModel.pause_menu_entries()`.
- Produces:
  - Pausing from `stage` resumes to `stage`.
  - Pausing from `boss` resumes to `boss`.
  - Pause menu options: Continue, Restart Stage, Settings, Return To Main Menu, Exit Game.
  - Restart Stage reloads the current stage and resets player/enemy/bullet state.
  - Return To Main Menu calls `_show_title()`.

- [ ] **Step 1: Write pause contract test**

Create `tests/assert_pause_contract.gd` that instantiates `GameManager`, verifies pause return state fields exist, pause menu labels are present from `UiModel`, and settings can be opened with a paused return target.

- [ ] **Step 2: Run the pause contract test and verify it fails**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_pause_contract.gd'
```

Expected: FAIL until pause helpers exist.

- [ ] **Step 3: Add pause helpers**

Add `GameManager.enter_pause(from_state: String)`, `GameManager.resume_from_pause()`, and `GameManager.open_settings(return_state: String)`.

- [ ] **Step 4: Route pause menu in `scripts/main.gd`**

Pressing pause in stage/boss calls `enter_pause(current_state)`. In paused state:

- up/down moves cursor.
- confirm routes selected pause action.
- pause/cancel resumes.

- [ ] **Step 5: Draw pause overlay**

Draw a dim overlay and the five pause options with current cursor. Keep gameplay visible behind it.

- [ ] **Step 6: Run checks**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_pause_contract.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --scene 'res://scenes/main.tscn' --quit-after 5
```

Expected: both commands exit `0`.

- [ ] **Step 7: Commit Task 3**

```powershell
git add autoload/game_manager.gd scripts/main.gd tests/assert_pause_contract.gd
git commit -m "feat: add pause menu flow"
```

---

### Task 4: Phase 2 Verification, Merge, And Push

**Files:**
- All files changed by Tasks 1-3.

**Interfaces:**
- Consumes: phase 1 foundation tests plus phase 2 UI tests.
- Produces: verified `master` pushed to `origin/master`.

- [ ] **Step 1: Run full focused verification**

Run:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_viewport_config.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_game_database.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_asset_registry.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_bullet_manager.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_performance_monitor.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_ui_shell_model.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_pause_contract.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --scene 'res://scenes/main.tscn' --quit-after 5
```

Expected: all commands exit `0`. Godot may still emit known non-fatal ObjectDB cleanup warnings.

- [ ] **Step 2: Commit any final verification docs if needed**

Only commit if there are tracked file changes from verification.

- [ ] **Step 3: Merge to master**

Run:

```powershell
git checkout master
git merge --ff-only feature/ui-shell-phase2
```

- [ ] **Step 4: Push master**

Run:

```powershell
git push origin master
```

Expected: `origin/master` includes phase 2 UI shell.

---

## Self-Review

- Spec coverage: This plan covers only original sequence item 2 and does not skip ahead to full art generation.
- Known gap deferred by original spec: practice mode starts through the same character/shot path but full practice unlocks remain phase 8.
- Placeholder scan: no `TODO` or unspecified commands remain.
- Type consistency: `UiModel` entry arrays use dictionaries consumed by `scripts/main.gd`; `GameManager` state strings are constants used by tests and runtime.
