@echo off
chcp 65001 >nul
setlocal
set "GODOT=C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe"
if not exist "%GODOT%" (
    echo [ERROR] Godot not found at:
    echo   %GODOT%
    pause
    exit /b 1
)
title Eastern Barrage
echo Starting Eastern Barrage...
echo.
echo Close this console window to quit the game.
echo.
"%GODOT%" --path "%~dp0." res://scenes/main.tscn
endlocal