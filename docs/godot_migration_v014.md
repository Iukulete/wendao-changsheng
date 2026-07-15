# v0.14 Godot 主版本迁移路线

## 决策

新主版本采用 Godot 4.7.1 stable、标准版与 GDScript。Godot 是唯一面向玩家的运行时；旧 Win32/GDI+ 文件只在功能迁移期作为规则和历史行为参考，不再提供游戏入口，也不进入新版发布包。

选择标准版的原因：当前核心是 2D 叙事界面、动画、数据驱动事件和本地进程通讯，不需要额外的 .NET 运行环境。Godot 的 Control、2D 渲染、粒子、Tween、Shader 与资源导入可以直接承接本项目最薄弱的表现层。

## 不是整体重写

迁移拆成五层，每层都保持可运行：

1. **表现层**：菜单、主界面、事件界面、时代主题、动态立绘。
2. **数据层**：事件 ID、时代 ID、场景 ID、人物 ID、选项与数值变化改为 JSON。
3. **玩法层**：修炼、突破、寿元、五行、因果、世界演进和轮回。
4. **基础设施**：版本化存档、旧档迁移、本地 AI HTTP 桥接、错误回退。
5. **发布层**：Godot 唯一入口、Windows 导出、CI 校验与旧实现退役。

## 当前完成的垂直切片

- `godot/scripts/main.gd`：三态界面、玩法样例与事件选择。
- `godot/data/events_v014.json`：首批显式资源路由事件。
- `godot/scripts/ambient_layer.gd`：不同纪元的微粒语言。
- `godot/scripts/dao_compass.gd`：五行与因果的实时命途罗盘。
- `godot/shaders/vignette.gdshader`：暗角、时代色与旧玉脉冲。
- `godot/scripts/save_service.gd`：D 盘便携存档、版本校验、原子写入、备份恢复与坏档隔离。

## 下一批迁移

1. 给原 C++ 的全部静态事件分配稳定 `event_id`，导出为 JSON。
2. 在现有版本化玩家存档上补齐世界、轮回与人情状态，并实现旧存档只读导入。
3. 把 `llama-server` 改为 Godot `HTTPRequest`/本地桥接调用，沿用现有超时和模板兜底。
4. 持续执行人物美术质量门槛，避免命名角色共脸与低质量生成资产混入。
5. 完成 Windows 导出模板、自动化 UI 截图与长局模拟。

## 已建立的发布链路

- `tools/prepare_godot.ps1` 从 Godot 官方下载路由与 `godotengine/godot-builds` 固定 4.7.1 发布源获取编辑器和导出模板，并校验写死的 SHA-256。
- Godot `_sc_` 自包含模式把编辑器数据和导出模板保存在 `D:\Games\wendao\tools\godot\4.7.1`，不写入 C 盘用户目录。
- `tools/verify_godot.ps1` 执行资源导入、GDScript 检查和主场景无窗口冒烟。
- `tools/build_godot.ps1` 只导出 `release/godot/windows` 下的 Windows x86_64 新版。
- `.github/workflows/godot-windows.yml` 复用相同脚本并只上传 Godot 产物。

## GitHub 切换条件

Godot 已经是唯一主入口；在覆盖 GitHub `main` 上旧版展示和发布前，还需满足：

- 新游戏、修炼、历练、突破、保存、读取、轮回可闭环；
- 旧存档至少能导入关键玩家/世界/轮回字段；
- 本地 AI 成功、超时、禁用三条路径均通过；
- 主要分辨率与无独显环境通过；
- 自动化长局不存在阻断性错误。
