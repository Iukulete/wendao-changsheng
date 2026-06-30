@echo off
chcp 65001 >nul
setlocal

set "SCRIPT=%~dp0generate_event.ps1"
set "ROOT=%~dp0.."
set "RELEASE=%ROOT%\release"

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -ReleaseDir "%RELEASE%" -Model "wendao-xiuxian"
if errorlevel 1 (
    echo 本地模型生成失败。可先运行 ..\准备本地AI.bat 检查便携后端，或确认 Ollama 已启动并已创建 wendao-xiuxian。
    exit /b 1
)

exit /b 0
