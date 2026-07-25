# 问道长生

《问道长生》是一款 2D 修仙 Roguelike。你会在一世又一世的修行中做出选择，经历境界突破、人物相遇、势力更替与生死轮回；这一世没有走完的路，会以另一种方式回到后世。

游戏不追求把所有内容塞进一条固定路线。每次开局，世界会从当前纪元继续向前，人物会成长、老去或离场，关系和选择会留下可以追溯的因果。你可以专注修炼，也可以介入山河纷争，或者走进镜湖秘境，看看前世留下的东西会把这一局带向哪里。

## 游戏内容

- 21 个境界、每境九层，包含突破代价、寿元、自然死亡、战斗死亡与飞升。
- 六个风格不同的纪元，每个纪元都有自己的场景、势力、人物和探索节奏。
- 36 个历练事件、108 个三选一结果，选择会改变六条道途，也会在后世留下回响。
- 普通战斗包含敌方意图、招式、状态、破势进度、奖励和中途存档恢复。
- 镜湖秘境提供四层因果路线和来源明确的能力牌组，能力来自角色经历、装备、羁绊与前世记忆。
- 物品、装备、锻造、成就和 16 件永久玉兵，都会在轮回中留下可继承的部分。
- 六个纪元各有独立的环境、探索和决战声景，战斗与剧情会随场景自然切换。

## 开始游戏

Windows 10/11 下双击：

```bat
启动游戏.bat
```

启动器会优先运行已经导出的版本：

```text
release\godot\windows\wendao-changsheng.exe
```

也可以直接用仓库内的 Godot 4.7.1 打开 `godot/project.godot`。

## 存档迁移

新版可以只读导入旧 Win32 版本的 `SAVE_V4` 和 `SAVE_V5` 六槽存档。角色、境界、世界年份、人物关系、轮回记录、剧情进度、成就和玉兵成长都会尽量保留。

把 `slot_1.txt` 至 `slot_6.txt` 放在游戏同级的 `save` 目录中，主菜单会显示可导入的旧存档。导入只创建新版存档，不会修改原始文本文件；已有新版主档会先备份。

## 开发与验证

项目使用 Godot 4.7.1，依赖、缓存、导出和测试文件都放在仓库所在磁盘。

```powershell
# 准备固定版本的 Godot 与 Windows 导出模板
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\prepare_godot.ps1

# 运行完整回归
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\verify_godot.ps1 -NoPrepare

# 验收桌面与窄屏界面
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\verify_render.ps1

# 导出 Windows 版本
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_godot.ps1 -NoPrepare
```

## 项目结构

```text
godot/                    游戏工程、数据、美术、脚本和测试
docs/                     设计说明、迁移记录与制作规范
tools/                    准备、验证、渲染和构建工具
.github/workflows/        Godot Windows CI
```

## 开源协议

项目除另有说明外采用 GNU Affero General Public License v3.0，详见 [LICENSE](LICENSE)。字体采用 SIL Open Font License 1.1；美术、音频和第三方运行时的授权信息见各自目录中的说明文件。
