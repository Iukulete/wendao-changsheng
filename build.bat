@echo off
setlocal

set "ROOT=%~dp0"
set "SRC=%ROOT%src\wendao_enhanced.cpp"
set "OUT_DIR=%ROOT%release"
set "OUT=%OUT_DIR%\wendao_enhanced.exe"

echo Building The Immortal Path...
echo.

if not exist "%SRC%" (
    echo Source file not found: %SRC%
    exit /b 1
)

if not exist "%OUT_DIR%" (
    mkdir "%OUT_DIR%"
)

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

if exist "%ROOT%assets\item_lore.json" (
    copy /Y "%ROOT%assets\item_lore.json" "%OUT_DIR%\item_lore.json" >nul
)

if exist "%ROOT%assets\item_catalog.json" (
    copy /Y "%ROOT%assets\item_catalog.json" "%OUT_DIR%\item_catalog.json" >nul
)
if exist "%ROOT%assets\item_db.tsv" (
    copy /Y "%ROOT%assets\item_db.tsv" "%OUT_DIR%\item_db.tsv" >nul
)

echo.
echo Done.
exit /b 0
