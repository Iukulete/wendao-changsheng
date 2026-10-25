@echo off
chcp 65001 >nul
setlocal
set "ROOT=%~dp0"
set "TEMP=%ROOT%.local\temp"
set "TMP=%TEMP%"
set "APPDATA=%ROOT%.local\appdata"
set "LOCALAPPDATA=%ROOT%.local\localappdata"
if not exist "%TEMP%" mkdir "%TEMP%"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
start "Wendao Ark" /D "%ROOT%" "%ROOT%wendao-changsheng.exe" --log-file "%TEMP%\game.log"
