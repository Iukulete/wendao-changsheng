@echo off
setlocal
set "ROOT=%~dp0"
where python >nul 2>nul
if errorlevel 1 (
    echo Python was not found.
    exit /b 1
)
python "%ROOT%tools\install_story_art.py"
exit /b %ERRORLEVEL%
