@echo off
setlocal

set "ROOT=%~dp0"
set "ENGINE=%ROOT%tools\godot\4.7.1\Godot_v4.7.1-stable_win64.exe"
set "PROJECT=%ROOT%godot"
set "TEMP=%ROOT%.tmp\godot"
set "TMP=%ROOT%.tmp\godot"

if not exist "%TEMP%" mkdir "%TEMP%"

if not exist "%ENGINE%" (
    echo Godot 4.7.1 was not found on D drive:
    echo %ENGINE%
    echo.
    echo Reinstall the portable engine under tools\godot\4.7.1.
    pause
    exit /b 1
)

if not exist "%PROJECT%\project.godot" (
    echo Godot project was not found: %PROJECT%
    pause
    exit /b 1
)

start "Wendao Godot" /D "%PROJECT%" "%ENGINE%" --path "%PROJECT%"
exit /b 0
