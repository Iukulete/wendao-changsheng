@echo off
chcp 65001 >nul
setlocal

set "SCRIPT=%~dp0generate_event.ps1"
set "ROOT=%~dp0.."
set "RELEASE=%ROOT%\release"

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -ReleaseDir "%RELEASE%" -Model "gpt-oss:120b-cloud"
if errorlevel 1 (
    echo 动态事件生成失败。请确认 Ollama 已启动，且可以使用 gpt-oss:120b-cloud；离线时可先运行 ..\准备本地AI.bat 检查便携后端。
    exit /b 1
)

exit /b 0
