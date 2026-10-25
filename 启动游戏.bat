@echo off
chcp 65001 >nul
setlocal

set "ROOT=%~dp0"
set "GAME_DIR=%ROOT%release\godot\windows"
set "GAME=%GAME_DIR%\wendao-changsheng.exe"
set "ARK_MARKER=%GAME_DIR%\wendao-ark.txt"
set "ENGINE=%ROOT%tools\godot\4.7.1\Godot_v4.7.1-stable_win64.exe"
rem Also accept the official editor downloaded manually beside this launcher.
if not exist "%ENGINE%" set "ENGINE=%ROOT%Godot_v4.7.1-stable_win64.exe"
set "PROJECT=%ROOT%godot"
set "TEMP=%ROOT%.tmp\godot"
set "TMP=%ROOT%.tmp\godot"
set "APPDATA=%ROOT%.local\runtime\appdata"
set "LOCALAPPDATA=%ROOT%.local\runtime\localappdata"
if not exist "%TEMP%" mkdir "%TEMP%"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"

rem Never launch an old card/six-era executable left in the release directory.
if exist "%GAME%" if exist "%ARK_MARKER%" (
    findstr /x /c:"WENDAO_ARK_3D_PRODUCT_V1" "%ARK_MARKER%" >nul
    if not errorlevel 1 (
        start "Wendao Ark" /D "%GAME_DIR%" "%GAME%" --log-file "%TEMP%\game.log"
        exit /b 0
    )
)

if not exist "%ENGINE%" (
    echo Godot 4.7.1 or a verified game export was not found.
    echo Place Godot_v4.7.1-stable_win64.exe beside this launcher.
    echo Or run powershell -NoProfile -ExecutionPolicy Bypass -File tools\prepare_godot.ps1 -SkipTemplates
    pause
    exit /b 1
)

if not exist "%PROJECT%\project.godot" (
    echo Godot project was not found: "%PROJECT%"
    pause
    exit /b 1
)

if not exist "%TEMP%" mkdir "%TEMP%"
start "Wendao Ark" /D "%PROJECT%" "%ENGINE%" --path "%PROJECT%" --log-file "%TEMP%\game.log"
exit /b 0
