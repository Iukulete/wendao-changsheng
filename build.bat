@echo off
setlocal

set "ROOT=%~dp0"
set "SRC=%ROOT%src\wendao_enhanced.cpp"
set "OUT_DIR=%ROOT%release"
set "OUT=%OUT_DIR%\wendao_enhanced.exe"

echo Building The Immortal Path...
echo.

where g++ >nul 2>nul
if errorlevel 1 (
    echo g++ was not found.
    exit /b 1
)

if not exist "%SRC%" (
    echo Source file not found: %SRC%
    exit /b 1
)

where python >nul 2>nul
if errorlevel 1 (
    echo Python was not found. Gameplay patches cannot be applied.
    exit /b 1
)

if exist "%ROOT%tools\apply_v06_path_dimensions.py" (
    echo Applying v0.6 path dimensions and karma rebalance...
    python "%ROOT%tools\apply_v06_path_dimensions.py"
    if errorlevel 1 exit /b 1
    echo.
)

if exist "%ROOT%tools\repair_v06_path_digest.py" (
    echo Repairing v0.6 path digest declaration order...
    python "%ROOT%tools\repair_v06_path_digest.py"
    if errorlevel 1 exit /b 1
    echo.
)

if exist "%ROOT%tools\apply_v07_story_arcs.py" (
    echo Applying v0.7 narrative arc progression...
    python "%ROOT%tools\apply_v07_story_arcs.py"
    if errorlevel 1 exit /b 1
    echo.
)

if exist "%ROOT%tools\repair_v07_trace_digest.py" (
    echo Exposing v0.7 narrative arcs in trace logs...
    python "%ROOT%tools\repair_v07_trace_digest.py"
    if errorlevel 1 exit /b 1
    echo.
)

if exist "%ROOT%tools\apply_v08_arc_legacies.py" (
    echo Applying v0.8 persistent arc legacies...
    python "%ROOT%tools\apply_v08_arc_legacies.py"
    if errorlevel 1 exit /b 1
    echo.
)

if exist "%ROOT%tools\apply_v09_achievement_toasts.py" (
    echo Applying v0.9 achievement toasts and reincarnation-jade weapons...
    python "%ROOT%tools\apply_v09_achievement_toasts.py"
    if errorlevel 1 (
        echo.
        echo v0.9 achievement patch failed.
        exit /b 1
    )
    echo.
)

if exist "%ROOT%tools\apply_v10_jade_weapon_awakening.py" (
    echo Applying v0.10 jade weapon resonance and signature techniques...
    python "%ROOT%tools\apply_v10_jade_weapon_awakening.py"
    if errorlevel 1 (
        echo.
        echo v0.10 jade weapon awakening patch failed.
        exit /b 1
    )
    echo.
)

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

g++ -std=c++17 -O2 -finput-charset=UTF-8 -fexec-charset=UTF-8 "%SRC%" -o "%OUT%" -lgdiplus -lgdi32 -mwindows -static-libgcc -static-libstdc++ -I"%ROOT%"
if errorlevel 1 (
    echo.
    echo Build failed.
    exit /b 1
)

echo.
echo Build complete: %OUT%

if exist "%ROOT%assets\background.png" (
    copy /Y "%ROOT%assets\background.png" "%OUT_DIR%\background.png" >nul
    echo Synced background.
)
if exist "%ROOT%assets\items" (
    if not exist "%OUT_DIR%\items" mkdir "%OUT_DIR%\items"
    xcopy /E /I /Y "%ROOT%assets\items" "%OUT_DIR%\items" >nul
    echo Synced item assets.
)
if exist "%ROOT%assets\previews" (
    if not exist "%OUT_DIR%\previews" mkdir "%OUT_DIR%\previews"
    xcopy /E /I /Y "%ROOT%assets\previews" "%OUT_DIR%\previews" >nul
    echo Synced preview assets.
)
if exist "%ROOT%assets\characters" (
    if not exist "%OUT_DIR%\characters" mkdir "%OUT_DIR%\characters"
    xcopy /E /I /Y "%ROOT%assets\characters" "%OUT_DIR%\characters" >nul
    echo Synced character assets.
)
if exist "%ROOT%assets\item_lore.json" copy /Y "%ROOT%assets\item_lore.json" "%OUT_DIR%\item_lore.json" >nul
if exist "%ROOT%assets\item_catalog.json" copy /Y "%ROOT%assets\item_catalog.json" "%OUT_DIR%\item_catalog.json" >nul
if exist "%ROOT%assets\item_db.tsv" copy /Y "%ROOT%assets\item_db.tsv" "%OUT_DIR%\item_db.tsv" >nul

echo.
echo Done.
exit /b 0
