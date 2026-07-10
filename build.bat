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
    echo.
    echo Required build environment:
    echo   - Windows 10/11
    echo   - MinGW-w64 g++ in PATH
    echo.
    echo One common install route:
    echo   1. winget install MSYS2.MSYS2
    echo   2. Open "MSYS2 UCRT64"
    echo   3. pacman -S --needed mingw-w64-ucrt-x86_64-gcc
    echo   4. Add C:\msys64\ucrt64\bin to PATH
    echo.
    echo If you already installed MinGW-w64, make sure its bin folder is in PATH.
    exit /b 1
)

if not exist "%SRC%" (
    echo Source file not found: %SRC%
    exit /b 1
)

where python >nul 2>nul
if errorlevel 1 (
    echo Python was not found. v0.6 gameplay patch cannot be applied.
    exit /b 1
)

if exist "%ROOT%tools\apply_v06_path_dimensions.py" (
    echo Applying v0.6 path dimensions and karma rebalance...
    python "%ROOT%tools\apply_v06_path_dimensions.py"
    if errorlevel 1 (
        echo.
        echo v0.6 path dimension patch failed.
        exit /b 1
    )
    echo.
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

if exist "%ROOT%assets\characters" (
    if not exist "%OUT_DIR%\characters" mkdir "%OUT_DIR%\characters"
    xcopy /E /I /Y "%ROOT%assets\characters" "%OUT_DIR%\characters" >nul
    echo Synced character assets.
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
