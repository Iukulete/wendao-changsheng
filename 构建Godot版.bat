@echo off
setlocal

set "ROOT=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%tools\build_godot.ps1"
if errorlevel 1 (
    echo.
    echo Godot build failed. See the error above.
    pause
    exit /b 1
)

echo.
echo Windows release is ready under release\godot\windows.
pause
exit /b 0
