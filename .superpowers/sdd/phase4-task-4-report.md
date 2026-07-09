# Phase 4 Task 4 Report

## RED
- Command:
  - `& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase4_main_data_integration.gd'`
- Result:
  - Exit code `1`
  - Failed with `Main missing method _enemy_bullet_types`
  - After tightening the test to inject a fake database, the same command still failed red on the missing helper, which confirmed the production gap before any `main.gd` change.

## GREEN
- Command:
  - `& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase4_main_data_integration.gd'`
- Result:
  - Exit code `0`
  - Verified:
    - `_enemy_bullet_types()` exists
    - all eight Phase 4 bullet families plus legacy `arrow` classify as enemy bullets
    - `_count_active_bullets_by_owner()` counts them as enemy bullets
    - `needle` collisions arm deathbomb state
    - `large_orb` graze uses the injected scoring rule value from the database rather than a hard-coded literal
  - Headless Godot still printed ObjectDB/resource leak warnings on exit.

## Regression
- Command:
  - `& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_bullet_manager.gd'`
- Result:
  - Exit code `0`
  - Headless Godot printed ObjectDB/resource leak warnings on exit.

- Command:
  - `& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_performance_monitor.gd'`
- Result:
  - Exit code `0`
  - Headless Godot printed ObjectDB/resource leak warnings on exit.

- Command:
  - `& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase3_bomb_contract.gd'`
- Result:
  - Exit code `0`
  - Headless Godot printed ObjectDB/resource leak warnings on exit.

## Files Changed
- `scripts/main.gd`
- `tests/assert_phase4_main_data_integration.gd`
- `.superpowers/sdd/phase4-task-4-report.md`

## Commit SHA
- `b1724d2`

## Self-Review Notes
- Kept the production edit scoped to `scripts/main.gd`.
- Preserved the existing `_enemy_bullet_type_ids()` helper as a compatibility wrapper and added the brief-required `_enemy_bullet_types()` entrypoint.
- Switched enemy bullet family lookup to `game_database_ref` so tests can verify data-driven behavior through dependency replacement.
- Added graze score lookup through scoring data because the injected-database test makes that contract observable.
- The new test originally used a generic bullet radius for `large_orb`; corrected the fixture to match the intended family-size contract instead of loosening production logic.
