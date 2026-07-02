@echo off
setlocal

set "ROOT=%~dp0"
set "RUN_DIR=%ROOT%release"
set "GAME=%ROOT%release\wendao_enhanced.exe"

cls
echo.
echo ============================================================
echo   Wendao Changsheng
echo ============================================================
echo.
echo Startup:
echo.
echo [2] Adventure:
echo   - Hand-written events
echo   - Optional local AI events
echo.
echo Living world:
echo   - Cultivators act on their own
echo   - Press [W] in game to view world state
echo   - The world reacts to your choices
echo.
echo ============================================================
echo.

if not exist "%GAME%" (
    echo Game executable not found. Building now...
    echo.
    call "%ROOT%build.bat"
    if errorlevel 1 (
        echo.
        echo Build failed. Please install g++ / MinGW and check the error above.
        pause
        exit /b 1
    )
)

echo Press any key to start...
pause >nul
start "" /D "%RUN_DIR%" "%GAME%"

echo.
echo Game launched.
exit /b 0
