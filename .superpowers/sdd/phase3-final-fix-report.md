# Phase 3 Final Fix Report

## Finding

Selected protagonist hitbox and graze radius helpers existed on `GameManager`, but `scripts/main.gd` still used the legacy `PLAYER_HITBOX` and `PLAYER_GRAZE` constants for player collision, graze scoring, and focus-hitbox drawing.

## Fix

- Added `scripts/main.gd` helpers `_player_hitbox_radius()` and `_player_graze_radius()`.
- Helpers call `GameManager.selected_hitbox_radius()` and `GameManager.selected_graze_radius()` when available, with legacy constant fallback.
- Updated enemy bullet collision, graze scoring, and focus-hitbox draw radii to use the helpers.
- Added a regression assertion in `tests/assert_phase3_protagonist_profiles.gd` that selects `swordswoman` and verifies `main.gd` returns the selected profile radii instead of the legacy defaults.

## TDD Evidence

RED:

```text
Godot --script res://tests/assert_phase3_protagonist_profiles.gd
Exit code: 1
ERROR: Main missing selected-radius helper _player_hitbox_radius
```

GREEN:

```text
Godot --script res://tests/assert_phase3_protagonist_profiles.gd
Exit code: 0
```

## Verification

All required commands exited 0:

```text
res://tests/assert_phase3_protagonist_profiles.gd
res://tests/assert_phase3_ui_loadout_contract.gd
res://tests/assert_phase3_shot_patterns.gd
res://tests/assert_phase3_bomb_contract.gd
res://scenes/main.tscn --quit-after 5
git diff --check
```

Godot emitted known shutdown ObjectDB/resource diagnostics after successful headless exits.
