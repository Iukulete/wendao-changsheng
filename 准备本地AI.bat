@echo off
chcp 65001 >nul
setlocal

set "SCRIPT=%~dp0ai_engine\setup_portable_ai.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
if errorlevel 1 (
    echo.
    echo 便携本地 AI 准备失败。请确认网络可访问 Hugging Face 和 GitHub，或手动放入模型与 llama.cpp 运行时。
    pause
    exit /b 1
)

echo.
echo 便携本地 AI 已准备完成，可以双击 启动游戏.bat。
pause
exit /b 0
