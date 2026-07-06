@echo off
chcp 65001 >nul
setlocal

set "SCRIPT=%~dp0ai_engine\setup_portable_ai.ps1"

echo.
echo 准备《问道长生》本地 AI
echo.
echo 需要环境：
echo   - Windows 10/11
echo   - PowerShell 5 或更新版本
echo   - 首次准备需要联网下载基础模型、问道 LoRA 和 llama.cpp 运行时
echo.
echo 说明：
echo   - 模型、LoRA 和运行时已存在时会直接复用，不会重复下载
echo   - 正常游玩不需要安装 g++；只有从源码重新编译时才需要 C++ 编译环境
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
if errorlevel 1 (
    echo.
    echo 本地 AI 准备失败。
    echo 请检查是否能访问 Hugging Face 和 GitHub，或手动放置模型、LoRA 与 llama.cpp 运行时。
    echo 即使本地 AI 不可用，游戏也可以运行，并会回退到内置事件。
    pause
    exit /b 1
)

echo.
echo 本地 AI 已准备好。现在可以运行 启动游戏.bat。
pause
exit /b 0
