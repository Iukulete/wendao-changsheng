@echo off
chcp 65001 >nul
setlocal

set "SCRIPT=%~dp0generate_event.ps1"
set "ROOT=%~dp0.."
set "RELEASE=%ROOT%\release"

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -ReleaseDir "%RELEASE%" -Backend "portable"
if errorlevel 1 (
    echo 动态事件生成失败。请先运行 ..\准备本地AI.bat 检查本地模型与运行时；游戏内会自动回退到内置模板。
    exit /b 1
)

exit /b 0
