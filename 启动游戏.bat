@echo off
chcp 65001 >nul
setlocal

set "ROOT=%~dp0"
set "RUN_DIR=%ROOT%release"
set "GAME=%ROOT%release\wendao_enhanced.exe"

cls
echo.
echo ============================================================
echo   The Immortal Path - AI Enhanced Edition
echo ============================================================
echo.
echo Current build:
echo.
echo [2] Adventure:
echo   - 70%% hand-written events
echo   - 30%% local AI dynamic events
echo.
echo Living world:
echo   - 15 NPCs cultivate on their own
echo   - Press [W] in game to view world state
echo   - The world evolves with your choices
echo.
echo ============================================================
echo.

if not exist "%GAME%" (
    echo Game executable not found:
    echo %GAME%
    echo.
    echo Please run build.bat first.
    pause
    exit /b 1
)

echo Press any key to start...
pause >nul
start "" /D "%RUN_DIR%" "%GAME%"

echo.
echo Game launched.
timeout /t 2 >nul
exit /b 0
