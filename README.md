# 问道长生

《问道长生》是一款以轮回、动态世界、人物关系和跨世叙事为核心的 2D 修仙 Roguelike。

项目现已完成 Godot 4.7.1 迁移。Godot 是仓库中唯一的游戏引擎和玩家运行时；旧 Win32/C++ 源码、构建链、启动入口与 CI 已退役。

## 开始游戏

Windows 10/11 下双击：

```bat
启动游戏.bat
```

启动器会优先运行已经导出的版本：

```text
release\godot\windows\wendao-changsheng.exe
```

若尚未导出，但仓库内已有便携 Godot 4.7.1，则直接启动 `godot/project.godot`。

## 当前玩法

- 21 个稳定境界、每境九层、突破代价、寿元、自然死亡、战斗死亡、飞升、道祖与天道闭环。
- 六种纪元，各自拥有场景、氛围、资源偏向、势力和人物生态。
- 势力、NPC、关系、灵潮、稳定度与纪元压力按年确定性演化，轮回后世界继续前进。
- 四条四阶段主线与四条三阶段跨世续章，选择会留下未竟因果和后世定局。
- 物品、消耗品、装备、锻造、16 项成就、16 件永久玉兵、觉醒、蓄能与显圣。
- 可复现的普通战斗，包含敌方意图、招式、状态、奖励和中途存档恢复。
- 可选的镜湖秘境构筑玩法。进入副本时，当前境界、主次道途、人物羁绊、装备、玉兵、前世记忆与心魔会即时投影成带来源的能力牌组；六个时代拥有不同路线事件和公开首领法则。它不是独立卡包，也不替代主线修仙循环。
- 本地 AI 事件桥只调用本机进程，输出经过结构与内容校验；禁用、超时和非法输出都会回退到内置事件。

## 旧版存档

Godot 新版可只读导入旧 Win32 版的 `SAVE_V4` 与 `SAVE_V5` 六槽存档，迁移：

- 角色、境界、五行、家世与成长资源；
- 当前纪元、世界年份、动态人物、关系与世界史；
- 轮回世数、前世记录、传承、未竟因果与旧玉；
- 连续剧情进度、成就、玉兵成长与当前装备。

把原有 `slot_1.txt` 至 `slot_6.txt` 保留在游戏同级 `save` 目录，主菜单会显示最近一份可导入旧录。导入只会创建新版校验存档，原始 `.txt` 文件不会被修改；已有新版主档会先进入备份。

## 开发与验证

所有依赖、缓存、导出和测试文件都留在仓库所在磁盘，不使用 Godot 的用户目录作为项目存档位置。

```powershell
# 首次准备固定版本的便携 Godot 与官方 Windows 导出模板
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\prepare_godot.ps1

# 美术清单、资源导入、主场景和全部确定性回归
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\verify_godot.ps1 -NoPrepare

# 屏幕外真实 GL 截图验收，不打开前台窗口
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\verify_render.ps1

# 验证、导出并后台运行导出包冒烟测试
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_godot.ps1 -NoPrepare
```

全量回归包含存档损坏恢复、旧六槽只读导入、本地 AI 四路径、物品、战斗、剧情、角色能力牌组、秘境和确定性十世长局。渲染验收覆盖 `1280x720`、`1440x900`、`1920x1080`，以及普通战斗、秘境路线和秘境战斗画面。

## 项目结构

```text
godot/                    唯一游戏工程、数据、美术、脚本和测试
ai_engine/                新版本地 AI 运行、模型准备与评测工具
docs/                     产品边界、迁移记录与后续方向
tools/                    Godot 准备、验证、渲染和构建工具
.github/workflows/        唯一 Godot Windows CI
```

## 开源协议

项目除另有说明外采用 GNU Affero General Public License v3.0，详见 [LICENSE](LICENSE)。美术、模型和第三方运行时仍须分别完成权利与许可证审查。
