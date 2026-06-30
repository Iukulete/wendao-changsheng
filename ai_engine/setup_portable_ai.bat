@echo off
chcp 65001 >nul
setlocal

set "SCRIPT=%~dp0setup_portable_ai.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
if errorlevel 1 (
    echo.
    echo 便携本地 AI 准备失败。请查看上面的错误信息。
    exit /b 1
)

echo.
echo 便携本地 AI 已准备完成。
exit /b 0
