@echo off
setlocal

set "SCRIPT=%~dp0ai_engine\setup_portable_ai.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
if errorlevel 1 (
    echo.
    echo Portable local AI setup failed. Check network access to Hugging Face and GitHub,
    echo or place the model and llama.cpp runtime manually.
    pause
    exit /b 1
)

echo.
echo Portable AI is ready. You can run the game launcher now.
pause
exit /b 0
