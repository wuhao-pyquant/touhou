# Phase 2 Crossfade Cancellation Fix Report

Date: 2026-07-09

## Finding

`AudioManager.apply_settings()` and `AudioManager.set_pause_ducked()` killed `_bgm_fade_tween` during a BGM crossfade, which also killed the fade callback that stops the outgoing player. `_sync_active_bgm_volume()` only retargeted the active player, so the inactive old player could remain audible.

## Red

Command:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase2_settings_effects.gd'
```

Result: failed with exit code 1 after adding the regression test.

Evidence:

```text
ERROR: Pause ducking during a cancelled BGM crossfade should silence the inactive old BGM player.
```

## Green

Fix:

- Added `_silence_inactive_bgm_players()` to mute and stop every non-active BGM player.
- Called it from `apply_settings()` and `set_pause_ducked()` after any fade tween cancellation and before syncing the active player.
- Left normal `play_bgm()` crossfade behavior unchanged.

Focused command:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_phase2_settings_effects.gd'
```

Result: passed with exit code 0.

Additional requested checks:

```powershell
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_ui_shell_model.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --script 'res://tests/assert_pause_contract.gd'
& 'C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'H:\claude code\godot_touhou' --scene 'res://scenes/main.tscn' --quit-after 5
git diff --check
```

Results:

- `assert_ui_shell_model.gd`: passed with exit code 0.
- `assert_pause_contract.gd`: passed with exit code 0.
- Main scene smoke: passed with exit code 0.
- `git diff --check`: passed with exit code 0; Git reported LF-to-CRLF working-copy warnings for edited `.gd` files.

Note: the Godot commands still emit shutdown ObjectDB/resource diagnostics even when they exit 0; these diagnostics were present on the successful requested checks and did not fail the processes.
