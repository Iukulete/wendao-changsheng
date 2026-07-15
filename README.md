# 问道长生 · 神游版

一款以轮回、因果与时代演化为核心的 2D 叙事修仙 Roguelike。项目现以 **Godot 4.7.1** 为唯一面向玩家的主版本：六种纪元拥有独立场景、色彩和氛围语言，修炼与抉择会改变角色命途，也会在世界中留下跨越轮回的回响。

旧 Win32/GDI+ 实现暂时保留在仓库中，仅用于迁移玩法规则和核对历史行为；它不再是游戏入口，也不会进入 Godot 新版发布包。

## 直接启动新版

Windows 10/11 下双击：

```bat
启动Godot版.bat
```

本机使用的便携 Godot 固定在 D 盘项目目录：

```text
D:\Games\wendao\tools\godot\4.7.1\Godot_v4.7.1-stable_win64.exe
```

引擎、导出模板、Godot 编辑器数据、临时目录和构建产物都留在 `D:\Games\wendao` 内。首次准备环境时会从 Godot 官方下载与发布源获取固定的 4.7.1 文件，并在解压前校验 SHA-256。

## 开发与构建

在项目根目录执行：

```powershell
# 准备便携编辑器和 Windows 导出模板（首次约需下载 1.3 GB）
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\prepare_godot.ps1

# 导入资源、检查脚本、加载主场景并运行存档回归
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\verify_godot.ps1

# 验证并导出 Windows 新版
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_godot.ps1
```

也可以双击 `构建Godot版.bat`。导出结果位于：

```text
release\godot\windows\wendao-changsheng.exe
release\godot\windows\wendao-changsheng.pck
```

`release/`、便携引擎、模板与 Godot 导入缓存均被 Git 忽略，不会污染仓库。GitHub Actions 会运行同一套验证与导出脚本，只上传 Godot Windows 产物。

## 当前内容

- 六种时代：古典、灵机蒸汽、星穹道网、废土返道、末法裂变、仙朝鼎盛。
- 修炼、历练、突破和时代观测的可玩闭环切片。
- 数据驱动的事件、场景和人物资源路由。
- 呼吸立绘、环境微粒、远近景视差、暗角与时代主题渲染。
- 随五行、因果和道心变化的原创“命途罗盘”。
- 带校验、备份恢复与坏档隔离的新版存档；导出后保存在 EXE 同目录 `save/`。
- D 盘本地 AI 模型与运行环境探测；通信桥仍在迁移，当前稳定使用内置事件。

完整的轮回、动态世界、本地 AI 通讯和旧档导入仍在持续迁移。Godot 新版会继续吸收旧实现中已经验证的规则，但不会恢复旧版入口。

## 项目结构

```text
godot/                       Godot 4.7.1 主项目
godot/art/                   新版场景与人物资源
godot/data/                  数据驱动事件
godot/scripts/               界面、玩法与动态渲染
godot/export_presets.cfg     Windows 导出预设
tools/prepare_godot.ps1      D 盘便携环境与哈希校验
tools/verify_godot.ps1       导入、脚本与主场景验证
tools/build_godot.ps1        Windows 新版导出
docs/godot_migration_v014.md 迁移和切换标准
```

## 开源协议

项目除另有说明外采用 GNU Affero General Public License v3.0，详见 [LICENSE](LICENSE)。第三方美术、模型、运行时与库仍遵循各自许可证。
