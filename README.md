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
- 可选的镜湖秘境构筑玩法。进入副本时，当前境界、主次道途、人物羁绊强度、装备、玉兵、前世记忆、四条主线定局与心魔会即时投影成带来源的能力牌组；续章会深化已有定局能力，而非增加外部收藏。六个时代拥有不同路线事件、压力临界心魔、精英被动和不能被爆发跳过的半血首领第二相，并以程序化施法轨迹、精英与首领显形、受击光痕、破相扩散环及击破结算反馈真实战斗结果。它不是独立卡包，也不替代主线修仙循环。
- 秘境岔路拥有可存档的四层因果路线图：已选道标会保留名称、类型与层数，当前分岔直接预示战斗风险、恢复、压力、强化与结算收益，旧存档缺少路线历史时可无损补齐。
- 六个纪元各有独立的探索、压力、决战三态配乐，以及世界/秘境两地点的底床和天气点声双层声景；所有长循环均为 64 秒流式 Ogg，战斗、首领、地点和纪元切换通过独立双声部按当前相位平滑过渡。施法、命中与护体各有四套可轮换时代材质，压力、觉醒/轮回、精英、首领、破相、胜利和失败也都使用纪元专属终稿；只有不承载世界身份的 UI 语义保持公共素材。
- 产品标题使用随包分发的 Noto Serif SC，正文、按钮、数值与能力说明使用 Noto Sans SC；720p 不缩小关键文字，短屏通过响应式布局和独立滚动保持清晰。
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

# 仅在重新生成原创音频时：准备哈希锁定的本地 FFmpeg，并固定 NumPy 版本
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\prepare_audio_encoder.ps1
python -m pip install -r .\tools\audio-requirements.txt
python -X utf8 .\tools\generate_audio_assets.py

# 美术/音频清单、资源导入、主场景和全部确定性回归
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\verify_godot.ps1 -NoPrepare

# 屏幕外真实 GL 截图验收，不打开前台窗口
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\verify_render.ps1

# 验证、导出，并执行无设备与屏幕外静音真实音频后端冒烟
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_godot.ps1 -NoPrepare

# 最终替换 main 前的产品发布构建；任何 prototype 或 production_candidate 都会使其失败
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_godot.ps1 -NoPrepare -ProductRelease
```

GitHub Actions 对 `agent/**` 推送执行完整 Godot 回归、真实渲染、Windows 导出和音频设备冒烟，但允许产品美术仍在制作；`main`、面向 `main` 的拉取请求及手动发布任务会额外强制最终音频与产品美术闸门。开发验证不能把缺失美术误标为产品发布，最终发布也不能绕过 12 项身份/分镜检查。

全量回归包含字体文件与授权哈希、164 个六纪元原创音频素材的格式/哈希/响度/循环/跨纪元差异与变体门禁（含 18 条流式三态配乐、24 条双地点分层声景和 42 条六纪元低频语义终稿）、音乐/声景上下文映射与独立双声部相位切换、音频设置与独立随机游标、存档损坏恢复、旧六槽只读导入、本地 AI 四路径、物品、战斗、剧情、角色能力牌组、秘境和确定性十世长局。渲染验收覆盖 `1280x720`、`1440x900`、`1920x1080`，以及音频设置、普通战斗、秘境路线和秘境战斗画面。

## 项目结构

```text
godot/                    唯一游戏工程、数据、美术、脚本和测试
ai_engine/                新版本地 AI 运行、模型准备与评测工具
docs/                     产品边界、迁移记录与后续方向
tools/                    Godot 准备、验证、渲染和构建工具
.github/workflows/        唯一 Godot Windows CI
```

## 开源协议

项目除另有说明外采用 GNU Affero General Public License v3.0，详见 [LICENSE](LICENSE)。随包字体采用 SIL Open Font License 1.1，许可证与来源哈希位于 `godot/art/fonts/`。美术、音频、模型和第三方运行时仍须分别完成权利与许可证审查。
