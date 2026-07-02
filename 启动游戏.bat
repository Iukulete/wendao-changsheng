@echo off
chcp 65001 >nul
setlocal

set "ROOT=%~dp0"
set "RUN_DIR=%ROOT%release"
set "GAME=%ROOT%release\wendao_enhanced.exe"

cls
echo.
echo ============================================================
echo   问道长生
echo ============================================================
echo.
echo 当前版本：
echo.
echo [2] 外出历练：
echo   - 手写事件托底
echo   - 本地天机动态事件
echo.
echo 活着的修仙界：
echo   - 活跃修士会自行修行
echo   - 游戏内按 [W] 查看修仙界现状
echo   - 天下大势会随你的选择推进
echo.
echo ============================================================
echo.

if not exist "%GAME%" (
    echo 未找到游戏本体，正在自动构建...
    echo.
    call "%ROOT%build.bat"
    if errorlevel 1 (
        echo.
        echo 自动构建失败。请确认已经安装 g++ / MinGW，并查看上面的报错。
        pause
        exit /b 1
    )
)

echo 按任意键开始问道...
pause >nul
start "" /D "%RUN_DIR%" "%GAME%"

echo.
echo 游戏已启动。
timeout /t 2 >nul
exit /b 0
