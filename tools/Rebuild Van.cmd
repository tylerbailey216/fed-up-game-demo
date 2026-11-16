@echo off
cd /d "%~dp0.."
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python tools/build_van.py
if errorlevel 1 exit /b 1
"tools\Godot_v4.5.1-stable_win64_console.exe" --headless --path . --editor --import --quit
pause
