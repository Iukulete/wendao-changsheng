@echo off
chcp 65001 >nul
setlocal

set "ROOT=%~dp0"
set "GAME_DIR=%ROOT%release\godot\windows"
set "GAME=%GAME_DIR%\wendao-changsheng.exe"
set "ENGINE=%ROOT%tools\godot\4.7.1\Godot_v4.7.1-stable_win64.exe"
set "PROJECT=%ROOT%godot"
set "TEMP=%ROOT%.tmp\godot"
set "TMP=%ROOT%.tmp\godot"

if exist "%GAME%" (
    start "问道长生" /D "%GAME_DIR%" "%GAME%"
    exit /b 0
)

if not exist "%ENGINE%" (
    echo 未找到已导出的游戏或便携 Godot 4.7.1。
    echo 请先运行 构建Godot版.bat，或执行 tools\prepare_godot.ps1。
    pause
    exit /b 1
)

if not exist "%PROJECT%\project.godot" (
    echo Godot 项目不存在：%PROJECT%
    pause
    exit /b 1
)

if not exist "%TEMP%" mkdir "%TEMP%"
start "问道长生" /D "%PROJECT%" "%ENGINE%" --path "%PROJECT%"
exit /b 0
