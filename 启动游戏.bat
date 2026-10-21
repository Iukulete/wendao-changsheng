@echo off
chcp 65001 >nul
setlocal

set "ROOT=%~dp0"
set "GAME_DIR=%ROOT%release\godot\windows"
set "GAME=%GAME_DIR%\wendao-changsheng.exe"
set "ARK_MARKER=%GAME_DIR%\wendao-ark.txt"
set "ENGINE=%ROOT%tools\godot\4.7.1\Godot_v4.7.1-stable_win64.exe"
set "PROJECT=%ROOT%godot"
set "TEMP=%ROOT%.tmp\godot"
set "TMP=%ROOT%.tmp\godot"

rem Never launch an old card/six-era executable left in the release directory.
if exist "%GAME%" if exist "%ARK_MARKER%" (
    findstr /x /c:"WENDAO_ARK_3D_PRODUCT_V1" "%ARK_MARKER%" >nul
    if not errorlevel 1 (
        start "问道：归舟" /D "%GAME_DIR%" "%GAME%"
        exit /b 0
    )
)

if not exist "%ENGINE%" (
    echo 未找到已验证的三维归舟导出包或便携 Godot 4.7.1。
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
start "问道：归舟" /D "%PROJECT%" "%ENGINE%" --path "%PROJECT%"
exit /b 0
