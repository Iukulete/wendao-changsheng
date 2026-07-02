@echo off
setlocal

set "SCRIPT=%~dp0setup_portable_ai.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
if errorlevel 1 (
    echo.
    echo Portable local AI setup failed. Check the error above.
    exit /b 1
)

echo.
echo Portable local AI is ready.
exit /b 0
