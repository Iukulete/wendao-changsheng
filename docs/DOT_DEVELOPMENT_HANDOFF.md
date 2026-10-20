# WENDAO 开发交接：给没有本聊天记录的 Dot / 新协作者

更新日期：2026-10-20。本文按已发布代码基线 `1395bf925225c06732c828175acb2b56c22686ce` 编写，后续提交以实际分支为准。

## 1. 你接手的是什么

你正在接手一个已从旧 2D 修仙叙事游戏发展出独立 3D 原型的项目。接下来的主方向是**开放世界探索、移动仙舟家园、建造和居民共同生活**。项目已经选用 Godot，当前有可运行、可保存、有回归测试的玩法原型；正式画面、完整建造和长期生活模拟仍需制作。

体验目标：灵气衰退、物资稀缺的时代，玩家从几块木板和一盏旧灯起步，逐渐搭出可进入的小家。居民会吃饭、休息、修理、外出采集，并留下自己的物件和共同记忆。风雨来时，这个亲手建起的家确实能保护大家。之后家会成为能驾驶、停泊、扩建的仙舟，带着居民进入更远的海域。玩家的积累要体现为空间、便利、生活和关系的变化。

当前工作名是《问道：归舟》，不是最终定名。旧仓库名仍为 `wendao-changsheng`。

## 2. 怎么连接仓库、从哪条分支开始

| 项目 | 地址或值 |
| --- | --- |
| GitHub 仓库 | https://github.com/Iukulete/wendao-changsheng |
| 当前开放世界协作基线 | `codex/island-survival-slice` |
| 交接时基线提交 | `1395bf9`：开放世界仙舟切片及其测试 |
| 交接时远程 main | `5fa58ba`，尚未包含上述切片提交；开工应取协作分支 |
| Godot 工程 | 仓库内 `godot/project.godot` |
| 直接开发的 3D 场景 | `godot/scenes/ark_greybox.tscn` |

公开仓库可直接读取/克隆。需要推送时，用协作者自己的 GitHub 账号认证，并先接受仓库邀请。不要索取仓库主人的密码、令牌或 SSH 私钥。HTTPS 克隆不依赖主人电脑上的 SSH 配置；推送认证使用你自己环境已有的 GitHub 登录方式。

Dot 若只能读网页，先用 GitHub 的 Raw 视图读取本文；真正修改、运行和提交代码需要它所在会话具备终端/文件访问或等效的仓库开发能力。先打开自己克隆的项目目录作为工作区，再开始任务；仅在聊天里读到仓库链接不代表已获得本地代码。下面的准备/验证脚本按 Windows 编写，部分测试会检查 D 盘路径；在其他系统接手时先适配对应的运行路径，不把 Windows 命令原样当成跨平台方案。

Windows 示例（先确认装有 Git，且目标目录不存在）：

```powershell
git clone --branch codex/island-survival-slice --single-branch https://github.com/Iukulete/wendao-changsheng.git D:/Games/wendao-dot
Set-Location D:/Games/wendao-dot
git switch -c codex/dot-building-placement
git status --short --branch
git log -1 --oneline
```

`codex/dot-building-placement` 是本文推荐首项工作的示例分支；换任务时用相应名称。每项工作从协作分支建立自己的分支，PR 的 base 选 `codex/island-survival-slice`，head 选自己的分支。共享分支和 `main` 的合入由项目负责人协调；先以 PR 交付可检查的结果。

主人电脑已有以下目录，切勿覆盖：主工作区 `D:/Games/wendao`；当前隔离 worktree `D:/Games/wendao/.tmp/island-survival-slice`。如果就在主人电脑接手，应从这个 worktree 核对状态，再创建自己的隔离 worktree；不要把上面的 clone 命令改成覆盖现有项目路径。

## 3. 环境和启动

本项目固定使用 **Godot 4.7.1 Stable，标准版 GDScript**，无需 .NET。全套验证还使用 Python 3（命令名 `python`）。优先用仓库环境脚本，版本、下载校验和可携式目录已配置。

```powershell
# 在自己克隆的仓库根目录执行；只下载编辑器，先不下载导出模板
powershell -NoProfile -ExecutionPolicy Bypass -File ./tools/prepare_godot.ps1 -SkipTemplates

# 核对实际运行的引擎
& ./tools/godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe --version
python --version

# 后台导入资源，不打开游戏窗口
& ./tools/godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe --headless --audio-driver Dummy --path ./godot --import

# 快速验证 3D 切片
& ./tools/godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe --headless --audio-driver Dummy --path ./godot --quit-after 600 --script res://tests/ark_greybox_smoke.gd
```

只有需要导出 Windows 版本时，才运行不带 `-SkipTemplates` 的准备命令；导出入口是 `tools/build_godot.ps1`。准备脚本失败时保留诊断，不擅自换版本或关闭校验。

本人要看实机时，可用准备好的编辑器导入 `godot/project.godot`，打开 `ark_greybox.tscn` 运行当前场景。主菜单也有“登上仙舟 · 开放世界试航”按钮。仓库的默认启动仍是 `main.tscn`；按默认“开始新生”会进入旧的六纪元玩法，不能据此判断自己已经进入新原型。

主人明确要求：**项目、依赖、缓存、下载、模型、导出和测试数据放 D 盘；他工作时不要弹出前台窗口。** `prepare_godot.ps1` 会把引擎和便携式配置放在仓库内的 `tools/godot/`，临时文件放 `.tmp/godot/`；本机 Blender 在 `.tools/`，不随 Git 上传。直接调用引擎的当前 PowerShell 会话也可设置：

```powershell
New-Item -ItemType Directory -Force ./.tmp/godot | Out-Null
$env:TEMP = (Resolve-Path ./.tmp/godot).Path
$env:TMP = $env:TEMP
```

对主人电脑的日常验证使用 `--headless --audio-driver Dummy`。它只能验证逻辑与资源载入，不能证明画面好看；真实渲染评审需要另外取得截图并目视检查。不要为截图把编辑器或游戏抢到主人前台。

## 4. 产品要求：请把这些当成方向约束

- **连续世界与自由路线。** 地区靠地形、怪物、气候和距离体现危险；允许开局就冒险进入高危区。用兽迹、遗骸、风暴、声音等提示，不以等级/章节钥匙封锁地区。当前地图是有限灰盒，后续需要扩展，不能把现有边界宣称为完整大世界。
- **家能迁徙。** 仙舟提供可升级的庇护与补给范围，玩家在附近探索并随舟远行。长期要支持多层室内、不同形态和精致陈设；目前先做可靠的单层空间和成长回报。
- **模板是主要建造入口之一。** 新手能用完整、好看、已校验通路的模板安家；也能逐件自由调整。开局给基础方案，特色蓝图通过探险或 Boss 获得。学会后永久保留，不占背包、不要求携带图纸；未学图纸丢失须有可追索副本/来源恢复。
- **居民有自主生活。** 常规采集、修理等工作尽量自动安排，玩家设置优先方针即可。资源必须有来源，人物要实际出工、归来并被看见；人口受真实住处约束。之后再扩展分工、关系、来客和居民故事。
- **后期多仙舟社会。** 玩家可向更豪华的仙舟交付珍贵物品换客居权，也可经修复、谈判、交易或契约取得产业、共有权或船体资产。区分客居、经营和产权，保留各船独立库存、居民和责任。
- **生活值得停留。** 后期可有美食、扑克、21 点及其他社交活动。它们服务于居民关系与生活气氛；首轮不要把所有活动一次铺开。当前先让回家、吃饭、睡觉、建造有真实反馈。
- **修仙与跨时代内容可共存。** 舟上灵气稳定和庇护已是当前原型；修为与仙舟范围挂钩是候选长线设定，完整修为系统尚未设计定稿。现代、蒸汽、科技风可出现，但应有地区、人物或遗迹来源。
- **角色与美术。** 用户偏好有头部和身体体积的精致 Q 版/小比例角色，在 3D 地图中行走；喜欢《八方旅人》的光影和层次。此前僵硬的平面贴片及部分诡异造型已被否定。风旅式轮廓可作参考，但风格仍待实机候选确认。
- **人物多样与衣橱。** 成年女性居民可以多些，避免全员同脸。富足后可以有精致礼装、低领服饰、现代衣橱；服装适合人物与场景。角色暂时够用，近期优先玩法、建造、环境和生活反馈。
- **材质最终要高品质。** 当前低模、纯色材质和海面 shader 都是可替换占位。后续整体提升模型、材质、灯光、天气、动画和声景，并检查实机性能；“换成最大分辨率贴图”不能代替统一的美术设计。当前 GL Compatibility 是技术现状，后续高端渲染方案要通过样板与目标硬件评估。
- **旧文本保留价值。** 大量旧剧情是候选故事资产，须逐弧核对时代、地点、人物事实、路线及后果，再用于遗迹、地区故事或居民线。不能批量抹掉、重写，也不能因为题材类似就硬接到首岛。

## 5. 当前真实进度

以下是代码原型能力，不等于正式内容或画面验收：

| 部分 | 当前已有 | 继续开发的边界 |
| --- | --- | --- |
| 连续空间 | 3D 步行、游泳、跳跃；浅滩、远礁、月背、琼华舫、蒸潮机坞等固定地点 | 仍是小型手工海域；没有大型世界流式加载或丰富生态 |
| 移动家园 | 舵位航行、碰撞、停泊、同行居民与船上设施一起移动，船位/朝向保存 | 船型和扩建有限，多层、自由外形和舰队仍待做 |
| 建造 | 基础避风棚、含储物箱的起居模板、工作台、龙骨甲板、客舱、风撑/饭釜等 | 多数是专用函数与固定规则；通用搬移、旋转、家具编辑器仍待做 |
| 蓝图 | 基础方案、探索/战斗所得方案永久学习，材料与唯一奖励持久化 | 特色模板库仍少，通用数据配置需要完善 |
| 居民 | 两位原创同行居民独立邀请/拒绝、日程、实体移动、修理、采集、共餐和纪念物 | 仍是少量特设行为，正式动作、复杂关系与长线故事不足 |
| 资源 | 地图真实有限物件，采走后保存；采集途中可读档、启航可召回 | 无箱时居民木料进可直接建造的 `wood`，有箱时进 `stored_wood`，保持这项修复 |
| 生存危险 | 手动时段/风雨、绳索加固取舍、损坏维修、庇护与寒意、礁流、压力阀 | `R` 控天气与 `T` 控时段是原型分离控制，尚非成熟天气时间系统 |
| 战斗 | 单只礁背兽、近身攻击、生命与击退、回舟恢复、唯一材料与风撑蓝图 | 无区域敌群生态、完整动作战斗和成熟平衡 |
| 多仙舟 | 琼华舫一次客居；合作试营、经营权和可选船体资产移交，独立货舱 | 单船样板；未完成多船管理、贸易航线、常驻娱乐或可续约客居 |
| 地图 | 位置、风险颜色、距离、方向、点击地标 | 地点与岛形硬编码；点击不传送，尚无完整发现系统 |
| 美术 | 程序化几何人物/岛屿/物件、暖灯和临时海面 | 概念图与旧肖像不代表新游戏正式角色或最终材质 |
| 旧剧情 | 六卷、144 章、432 选择；当前审读初筛台账保留 | 没有一条因此被认定已合理接入新首岛，也未完成全部文学终审 |

## 6. 代码从哪里开始看和改

场景 `ark_greybox.tscn` 只有一个挂脚本的 `Node3D`，大多数对象由脚本生成。打开场景看不到完整手摆地图是正常的。

| 文件 | 从这些符号开始 | 职责 |
| --- | --- | --- |
| `godot/scripts/ark_greybox.gd` | `_ready()`、`_build_world()`、`_build_player()`、`_physics_process()`、`_process()` | 原型主控制器，约 5500 行；世界、人物、玩法编排 |
| 同上：建造 | `_start_build()`、`_start_basic_shelter_template()`、`_start_starter_home_template()`、`_update_build_preview()`、`_try_place_*()`、`_build_*_at()` | 预览、材料/位置校验、确认施工与生成设施 |
| 同上：居民 | `_begin_resident_daily_gather()`、`_process_resident_gathering()`、`_finish_resident_gathering()`、`_update_traveler_schedule()`、`_update_sailmaker_schedule()` | 采集与生活日程；另有甲板/岸上寻路与共餐流程 |
| 同上：移动家园/危险 | `_sail_step()`、`_toggle_sailing()`、`_advance_weather()`、`_process_reef_beast()`、`_process_pressure_vent()` | 航行、天气和特设遭遇 |
| 同上：交互/显示 | `_interact()`、`_interaction_hint_action()`、`_opening_objective_hint()`、`_update_hud()` | 最近目标互动、阶段提示、HUD |
| 同上：状态 | `_record_world_event()`、`_build_save_state()`、`_save_progress()`、`_load_progress()` | 事实事件、schema 与存档重建；当前状态 schema 为 32 |
| `godot/scripts/ark_greybox_save.gd` | `_init()`、`save_state()`、`load_state()` | 独立存档文件、SHA-256、临时写入、备份回退 |
| `godot/scripts/ark_landmass_builder.gd` | `build_island()` | 确定性的低模岛岸网格和碰撞 |
| `godot/scripts/ark_world_chart.gd` | `refresh()`、`_draw_map()`、`_gui_input()` | 地图显示和 `destination_selected(destination_id, title)` 信号 |
| `godot/scripts/main.gd` | `_enter_open_world_ark()` | 主菜单试航入口；另有 `_enter_ark_exploration()` 从旧管理页进入 |
| `godot/shaders/ark_ocean.gdshader` | 顶部占位说明 | 现有临时海面，可作为后续替换接入点 |
| `godot/tests/ark_*.gd` | 每个脚本的 `_run()` | 当前原型行为与持久化约束的回归例子 |

**容易走错的地方：** `godot/scripts/survival_system.gd`、`island_map_view.gd` 和 `main.gd` 的旧管理页属于“地图按钮/行动次数”原型；新方向的主开发入口是 `ark_greybox.gd`。`survival_system.gd` 是供别的脚本使用的逻辑类，不是 `SceneTree/MainLoop`，不能传给 Godot 的 `--script` 直接启动；此前用户遇到的相关报错就是这种启动方式造成的。

现有主控制器过大。为新系统引入清楚的小模块/资源目录，逐步提取规则；保留场景入口、稳定 ID 和现有调用面，再用测试证明行为一致。避免在首个 PR 重写整个工程。最常见的逻辑位置是：配置/规则 → 建造校验 → 实体生成 → 交互/HUD → 保存/恢复 → 测试；不能只补一个按钮。

## 7. 推荐 Dot 的第一项可交付任务

**把储物箱和工作台从“一次性放置”扩展为可预览、可取消的搬移/旋转。** 这是本文建议的首轮任务，尚未实现；它直接服务于用户希望玩家经营和布置自己的家，范围也适合独立 PR。

从 `ark_greybox.gd` 中 `_try_place_storage()` / `_try_place_workbench()`、相应位置校验与 `_build_storage_at()` / `_build_workbench_at()` 开始。先整理共用的放置数据与校验，再接入选择现有设施、搬移预览、旋转、确认/取消。新代码可放入职责明确的建造模块，主控制器保留编排；文件名与类设计由实现者依现状决定。

这个 PR 应交付：

1. 对已有储物箱/工作台提供可发现的编辑入口，预览是否合法，旋转和取消操作清楚。
2. 确认搬移更新设施、互动点、朝向与相关居民目标；取消保留原设施、原位置和原库存。搬移本身不重新收费、不返还建造材料，也不复制设施。
3. 合法性包含承重边界、与建筑/家具的空间冲突及必要通路；考虑旋转后的占地。原设施不能在预览时丢失存档或功能。
4. `wood` / `stored_wood`、工作台升级和已学蓝图保持；仙舟移动后设施仍以甲板局部位置跟随。
5. 保存并重载后位置和朝向一致。新增字段明确缺省值、schema 迁移与视觉重建；旧档继续按旧朝向读入。
6. 验证确认、取消、无效位置、材料不变、航行后局部坐标、旧档/新档读回和交互位置；再做一次实际布置与居民通行观察。

完成这一块后，再按以下顺序推进，每轮保持一段可玩的成长回报：

- **建造模板与房间用途**：更多经过通路校验的舱室/家具组合、自由调整、合理拆回、实际床位容量、居民使用；逐步把硬编码蓝图/设施变为稳定数据与场景。
- **居民独立生活**：第二位居民自己的自主工作与需求；沿用已有三人共餐，增加独立反应和玩家缺席时的可见成果，避免再做一套重复共餐。
- **探索与危险**：扩展连续地形、来源明确的地点/资源目录、发现与航路记忆；逐步形成可扩展的危险和敌人行为，保持绕行与撤退。
- **正式视觉样板**：先做一处海岸、一段甲板和一间居室，统一模型、材料、灯光、天气、音频与人物动作，实机评审通过后扩区。高端材质需求要在此兑现。
- **后期系统**：多层船舱、更多豪华仙舟与产业、餐饮/牌局、跨时代地区和经审阅的旧故事弧。

如果项目负责人已为你分配其他模块，以实际分工为准；你仍须先核对本文入口、存档和产品约束。多个开发者同时改 `ark_greybox.gd` 很容易冲突，开始前在 PR/任务说明里列出自己将改的函数与新模块。

## 8. 保存、资源与剧情的硬约束

- 新切片存档在**仓库根目录** `.local/save/ark_greybox_v1.json`（不是 `godot/.local`）；代码按 `res://../.local/save` 解析。测试使用独立的 `save_root_override`。文件外层版本 1 与内层 `schema_version = 32` 是两层概念。
- 旧六纪元的 `run_state` 与 3D 切片存档分开。旧管理页切换到 3D 场景不代表双方进度自动同步；不能用覆盖旧存档来“完成迁移”。
- 保存既要记录数据，也要重建模型、互动点、碰撞、居民站位和正在进行的任务。已取得的唯一奖励不能读档再生；不要从旧档的最终结果补造从未记录的事件。
- 注意世界坐标与 `ArkRoot` 局部坐标：同行居民、设施与玩家的船上位置需要随舟移动；岸上出工中的居民使用世界位置。保存/恢复不得混用。
- 用稳定的设施、居民、资源、蓝图和事件 ID。美术模型替换尽量不改这些 ID；角色概念图不能直接充当会走路、会坐下的角色模型。
- 现有资源有“玩家先取走、居民取消”“途中保存、归来入账”“启航召回”等行为，后续拆模块必须保留。居民没有采到东西时不能凭空产出。
- 美术授权、来源和可再分发条件需在资产登记里记录；保留现有字体/音频许可与项目 AGPL-3.0 许可。概念候选、旧角色肖像和正式新模型分清用途。
- 原文位于 `godot/data/chronicles/`。先读下列迁移规则与审阅台账；原文件保留，改编放独立呈现层。当前首岛与居民是原创开局，已有初筛并没有证明任何旧弧能直接挂上去。

## 9. 怎么验证、怎么交付

先跑目标模块测试，再在提交前运行仓库全套验证：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./tools/verify_godot.ps1 -NoPrepare
```

针对本轮建议的建造任务，现有基础测试包括 `ark_greybox_smoke.gd`、`ark_resident_gather_test.gd`、`ark_navigation_test.gd`；新增搬移行为应有针对性回归。长路实走还有 `ark_world_travel_test.gd` 与 `ark_mooring_test.gd`，帧数上限与全套脚本中一致。

**退出码 0 不足以认定 Godot 测试通过。** 还需检查没有 `SCRIPT ERROR:` / `ERROR:`，且出现对应的 `*_OK:` 标记。`verify_godot.ps1` 已做这些检查。`ark_landmass_physics_test.gd` 在交接基线中没有列入全套 `$testScripts`，修改地形碰撞时额外单独运行它。headless 成功不代替实机体验、画面和完整文学审校。

上一次开发回合记录了 Godot 4.7.1 全套验证通过；本文编写回合只做了交接相关代码/分支核对与文档检查，没有重新声称全套测试已在本日跑过。Dot 应在自己的环境建立一次基线，记录实际结果。

交付流程示例：

```powershell
git diff --check
git status --short
# 逐项核对后，仅暂存本轮相关文件；替换下面示例路径
git add godot/scripts/ark_greybox.gd
# 继续添加本轮新模块、测试、设计记录等明确路径
git commit -m "feat: support moving and rotating ark fixtures"
git push -u origin codex/dot-building-placement
```

GitHub 上创建 PR，base = `codex/island-survival-slice`。说明玩家现在能做什么、修改范围、测试、存档迁移、已知不足，并附必要的实机截图。不要提交 `.local/`、`.tmp/`、`.tools/`、`godot/.godot/`、引擎包、模型运行时、个人存档或令牌。不要强制推送或重写别人的工作。

## 10. 推荐阅读顺序与文档冲突

1. 本文：独立交接与开工路线。
2. [开局切片设计](OPENING_SLICE_DESIGN_V1.md)：开局事实、物资账、居民与当前样板。
3. [开放世界仙舟设计](GAME_DESIGN_OPEN_WORLD_ARK_V1.md)：长期系统与设计支柱。
4. [旧剧情迁移规则](OPEN_WORLD_NARRATIVE_MIGRATION.md) 与 [故事适配台账](OPEN_WORLD_STORY_ADAPTATION_LEDGER.md)：先审后接、当前证据边界。
5. [角色模型制作草案](CHARACTER_MODEL_PRODUCTION_BRIEF_V1.md)：历史方向与候选验收要求。
6. 对应源码与 `ark_*.gd` 测试：确认实际已实现的行为。

已知旧文档存在混合状态：根 README 主体描述旧 2D 玩法；长设计稿底部仍有 schema 27/“没有生命值”等早期描述，而基线代码已有 schema 32、生命/战斗和三人共餐；角色草案也同时保留过时的像素方案措辞。发生冲突时，以用户最新产品要求、实际代码、实际测试结果与本文交接说明核对，明确修正旧记录；不要因为一句旧描述把已完成能力删掉，也不要把计划当作已完成。

## 11. 可直接粘给 Dot 的开工说明

> 请接手 https://github.com/Iukulete/wendao-changsheng 的 `codex/island-survival-slice` 分支，完整阅读 `docs/DOT_DEVELOPMENT_HANDOFF.md`。你看不到原聊天，所需背景、环境、代码入口、产品目标、约束与推荐首项任务均在该文件。目标是开放世界里的移动仙舟家园：自由探索、模板加自由建造、居民自主生活、庇护与成长，后期扩展精致多层室内、多仙舟产业和高品质风格化 3D 美术。先核对仓库与代码状态，建立自己的开发分支和测试基线，再按文档第 7 节推进储物箱/工作台搬移与旋转，完成后向 `codex/island-survival-slice` 提 PR。主人电脑上的项目与依赖都放 D 盘，工作时不要弹出前台窗口。保留旧剧情、稳定 ID 和存档兼容；请以可运行行为与测试/实机证据报告进展。
