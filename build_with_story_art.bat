@echo off
setlocal
set "ROOT=%~dp0"
call "%ROOT%build.bat"
if errorlevel 1 exit /b 1
where python >nul 2>nul
if errorlevel 1 (
    echo Python was not found. Curated story art cannot be installed.
    exit /b 1
)
python "%ROOT%tools\install_curated_story_art.py"
if errorlevel 1 exit /b 1
echo.
echo Build and curated story-art installation completed.
exit /b 0
