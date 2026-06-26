@echo off
chcp 65001 >nul
setlocal

set "ROOT=%~dp0"
set "SRC=%ROOT%src\wendao_enhanced.cpp"
set "OUT_DIR=%ROOT%release"
set "OUT=%OUT_DIR%\wendao_enhanced.exe"

echo 编译《问道长生》AI增强版...
echo.

if not exist "%SRC%" (
    echo 找不到源文件: %SRC%
    pause
    exit /b 1
)

if not exist "%OUT_DIR%" (
    mkdir "%OUT_DIR%"
)

g++ -std=c++17 -O2 -finput-charset=UTF-8 -fexec-charset=UTF-8 "%SRC%" -o "%OUT%" -lgdiplus -lgdi32 -mwindows -static-libgcc -static-libstdc++ -I"%ROOT%"
if errorlevel 1 (
    echo.
    echo 编译失败，请检查上面的错误信息。
    pause
    exit /b 1
)

echo.
echo 编译成功: %OUT%
if exist "%ROOT%assets\background.png" (
    copy /Y "%ROOT%assets\background.png" "%OUT_DIR%\background.png" >nul
    echo 已同步背景图: %OUT_DIR%\background.png
)
echo.
choice /m "现在启动游戏吗"
if errorlevel 2 exit /b 0

start "" /D "%OUT_DIR%" "%OUT%"
exit /b 0
