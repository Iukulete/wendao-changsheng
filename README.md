# 问道：归舟

Godot 4.7.1 标准版 GDScript 的 3D 开放世界仙舟家园原型。

从木板与旧灯起步，建造可进入的家，与居民生活、修理、采集、共餐；驾驶
仙舟停泊、扩建，探索浅滩、远礁与更远的海域。当前是有限手工海域切片，
不是已经完成的大型开放世界或最终美术版本。

## 游戏版本

当前游戏版本为 **0.1.002**；唯一机器可读来源是
`godot/project.godot` 的 `application/config/version` 字符串，菜单与构建元数据均读取它。
采用自定义 **S.X.Y**（不是 SemVer）：S 为 0 起不限上界的玩法/内容大版本；
X 为 0–9 阶段位（1 基础版本、3 基本玩法、5 主要玩法、7 Alpha、8 Beta、9 RC）；
Y 为 000–999 修复位，必须保留三位前导零。不据此推定已有历史发布。
游戏版本与 Godot 引擎版本、存档 schema、外层格式及产品识别标记分别管理。
Windows 构建生成 `game-version.json`，纳入校验和并与工程版本核对。

## 唯一产品入口

- 工程：`godot/project.godot`
- 默认主菜单：`godot/scenes/main.tscn`，仅进入/续接 3D 仙舟。
- 玩法场景：`godot/scenes/ark_greybox.tscn`
- 旧卡片战斗、六纪元界面及其专用运行逻辑已退出活跃工程。

旧故事、对话、角色资料、美术与音源保存在 [源资产库](archive/README.md)，
不随新游戏打包，也不代表已适配到新岛屿。字体及其授权在活跃工程中复用。
旧运行时代码可从 Git 历史恢复，不保留可启动的第二套游戏入口。

## 启动与验证

固定使用官方 **Godot 4.7.1 Stable 标准版**，不需要 .NET；验证需要 Python 3。
Windows 将项目、引擎与缓存放在可写的 D 盘工作目录：

```powershell
./tools/prepare_godot.ps1 -SkipTemplates
./tools/godot/4.7.1/Godot_v4.7.1-stable_win64.exe --path ./godot
./tools/verify_godot.ps1 -NoPrepare
```

跨平台验证使用已下载并核验的同版本引擎：

```sh
python tools/verify_godot.py --godot /absolute/path/to/Godot_v4.7.1-stable_linux.x86_64
```

`启动游戏.bat` 可启动本地构建或工程；`构建Godot版.bat` 构建 Windows 包。
最终资源和画面须分别进行真实渲染与导出包检查；headless 通过不代表美术
或硬件帧率验收通过。

## 基本操作

- WASD：行走/游泳；Space：跳跃。
- E：附近互动/舵位；Q：近身攻击。
- B：建造；F：附近储物箱/工作台编辑；编辑中 R：旋转。
- 鼠标左键确认施工；右键或 Esc 取消；M：潮痕图；F5：保存。
- 原型中 R（非编辑状态）控制天气阶段，T 推进时段；不是最终时间系统。

## 存档与兼容

3D 独立存档保持 `res://../.local/save/ark_greybox_v1.json` 的历史解析位置，
源码工程下即仓库根 `.local/save`，外层格式1、内层schema34。
不读取、不覆盖、不自动转换旧六纪元存档。请备份主档及 `.backup` 文件。
未来版本或不能安全读取的旧档会保留，并显示未保存会话提示，不静默重置。
测试必须使用独立路径，禁止指向真实 `.local/save`。

## 设计与迭代

1. [当前产品目标](docs/PRODUCT_TARGET_CURRENT.md)
2. [开局切片](docs/OPENING_SLICE_DESIGN_V1.md)
3. [开放世界与仙舟](docs/GAME_DESIGN_OPEN_WORLD_ARK_V1.md)
4. [建造编辑](docs/ARK_FIXTURE_EDITING.md)
5. [稳定性检查](docs/ARK_STABILITY_AUDIT.md)
6. [旧系统退休与资源留存](docs/ARK_RETIRED_SYSTEMS.md)
7. [架构方案评估（讨论稿）](docs/ARK_ARCHITECTURE_REVIEW.md)
8. [以体验与实测为门槛的混合架构提案（未实施）](docs/ARK_HYBRID_ARCHITECTURE_PROPOSAL.md)

协作基线为 `codex/island-survival-slice`；独立分支经 PR 交付，不自动合并。
AGPL-3.0 代码许可与各项资源的独立许可均须保留。

### 本轮恢复的可玩边界

- `H` 或右上角按钮展开帮助/建造抽屉，`Esc` 优先收起；关键状态和保存失败不会被隐藏。
- `F8` 切换提供的白色汉服像素角色外观；停步使用对应朝向的站立帧，保持最后行走方向；角色碰撞、移动和游泳仍使用真实三维角色控制器。
- 共餐需要实际食材、居民到桌和玩家在场按 `E`；离开、风暴、航行或时段变化会暂停，返回后需主动恢复。
- 新游戏使用 Gerstner 波；旧存档保留原解析波模型，避免读档时切换海面。船体仍沿用原有受控悬浮设定，不宣称真实排水船体模拟。
- 可选 C++/双工作线程水体批计算保留 GDScript 参考回退，默认不启用原生后端。构建步骤见 `native/ark_water/README.md`；Linux 验证不代表 Windows DLL 已验证。
- 建造、资源账本、采集任务和事实记忆已分离为增量模块；部分旧场景标量仍通过显式兼容命令同步，并非完整重写。
