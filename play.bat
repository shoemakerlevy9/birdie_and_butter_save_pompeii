@echo off
setlocal
cd /d "%~dp0"

set "GODOT="
if exist "%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe" (
	set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe"
)
if not defined GODOT if exist "%USERPROFILE%\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe" (
	set "GODOT=%USERPROFILE%\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe"
)
if not defined GODOT (
	where Godot_v4.7.1-stable_win64.exe >nul 2>&1 && for /f "delims=" %%I in ('where Godot_v4.7.1-stable_win64.exe') do set "GODOT=%%I"
)

if not defined GODOT (
	echo Could not find Godot 4.7.1. Install it with: winget install GodotEngine.GodotEngine
	pause
	exit /b 1
)

start "" "%GODOT%" --path "%cd%"
