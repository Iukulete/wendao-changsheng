# 问道长生 The Immortal Path

文本修仙 Roguelike，从凡人修炼到道祖，再到掌尽诸道的天道境。

当前主版本是 **AI 增强版**：

- 主源码：`src/wendao_enhanced.cpp`
- 主程序：`release/wendao_enhanced.exe`
- 启动入口：`启动游戏.bat`
- 构建入口：`build.bat`

当前工作树已经收口为主线版本；旧版和实验入口不参与默认构建。

## 快速开始

双击运行：

```bat
启动游戏.bat
```

如果 `release/wendao_enhanced.exe` 不存在，先运行：

```bat
build.bat
```

## 编译

项目根目录下执行：

```bat
build.bat
```

等价手动命令：

```bash
g++ -std=c++17 -O2 -finput-charset=UTF-8 -fexec-charset=UTF-8 src/wendao_enhanced.cpp -o release/wendao_enhanced.exe -lgdiplus -lgdi32 -mwindows -static-libgcc -static-libstdc++ -I.
```

构建脚本会把 `assets/background.png` 同步到 `release/background.png`。游戏运行目录固定为 `release/`，存档会写入 `release/save.txt`。

## 游戏特色

- **21 个境界**：凡人 -> 道祖 -> 天道境
- **事件系统**：24 个手写事件 + 30% 概率动态事件
- **活的世界**：15 个 NPC 自主修炼、战斗、飞升
- **时代化修士**：活跃修士的名号、目标和资源争夺会随纪元变化
- **五行系统**：灵根影响修炼，飞升需五行均衡
- **因果系统**：选择会影响事件倾向和突破成功率
- **道途记忆**：关键选择、突破、死亡和转世会沉淀为可查看记忆
- **轮回传承**：死亡或证道会生成前世记录，下一世会想起部分具体道途碎片
- **未竟因果**：每世死亡会整理未完成的主线、人情债和旧世残响，下一世可继续追索
- **时代演化**：每一世会生成对应时代的宗门、地点和世界大事，不只是更换背景名
- **纪元年表**：跨世记录每一世的纪元变迁，AI 可把前几世历史当成今生事件压力
- **旧世残响**：转世后上一纪元会留下遗址、制度、器物或断代线索，供本世主线和 AI 事件续写
- **本世主线**：每次转世生成本世主题和持续线索，AI 动态事件会优先围绕这些线索续写
- **本世势力牵连**：每世根据时代、家世和资质生成宗门/仙朝/工坊/道网/残宗关系，形成可续写的旧债和身份
- **本世人脉**：父母、养育者、同辈、欺压者和时代联系人会形成持续关系线，并进入 AI 上下文
- **AI 抉择回响**：本地 AI 事件的选择结果会结合事件文本、旧世残响、人脉和灵宝状态写入道途记忆
- **大道与灵宝**：普通兵刃无法跨世，通天灵宝留下道痕，道祖与所掌大道共生
- **本世器物**：今生得到的兵刃和普通法宝会进入本世记录，死亡后本体失散，只可能留下记忆、器痕或灵宝残印
- **灵宝觉醒**：通天灵宝共鸣达到阈值会进入器鸣初醒、认主残印、道胚成形等阶段，并沉淀进记忆
- **大道特性**：道祖掌握的不同大道会影响修炼、历练抉择和破境，不再只是境界数值
- **九大鸿蒙至宝**：九件创世级恒在之物，各有固定权柄、显化和禁忌；道祖不可毁灭，天道境才具备理论毁灭力，但毁灭没有必要
- **世界反馈**：灵气暴动、宗门大战等世界事件会影响修炼和历练风险
- **本地模型桥**：动态事件会写出 `release/ai_prompt.txt`，优先尝试便携 `llama.cpp`，失败后回退到 Ollama 或内置模板
- **上下文回退**：即使本地模型不可用，内置动态事件也会读取本世主线、势力牵连、本世器物、人脉和前世未竟因果

## 操作

```text
[1] 打坐修炼
[2] 外出历练  - 可能触发动态事件
[3] 突破境界
[4] 服用丹药
[5] 灵石闭关
[W] 查看世界  - 看 NPC 状态
[P] 本世主线
[F] 查看家世
[R] 查看人情风波
[T] 鸿蒙至宝
[H] 道途记忆
[G] 前世传承 / 成就
[S] 保存
[L] 读取
[N] 游戏结束后转世
[ESC] 退出
```

## 当前结构

```text
3dyou/
├── src/
│   └── wendao_enhanced.cpp
├── ai_engine/
│   ├── ai_core.h
│   ├── generate_event.ps1
│   ├── models/
│   └── runtime/llama.cpp/
├── world_system/
│   └── dynamic_world.h
├── procedural_gen/
│   └── procedural_gen.h
├── legacy_system/
│   └── legacy_system.h
├── assets/
│   └── background.png
├── release/
│   └── wendao_enhanced.exe
├── build.bat
├── 启动游戏.bat
└── README.md
```

## 自定义

- **AI 事件概率**：修改 `src/wendao_enhanced.cpp` 中 `Random(1, 100) <= 30` 的 `30`
- **NPC 数量**：修改 `world_system/dynamic_world.h` 的 `InitNPCs`
- **背景图**：替换 `assets/background.png` 后重新运行 `build.bat`

## 本地模型桥

触发动态事件时，游戏会在运行目录 `release/` 写出：

```text
ai_prompt.txt
ai_prompt_runtime.txt
ai_event.txt
ai_event_raw.txt
ai_backend.txt
ai_status.txt
ai_llama.log
ai_ollama.log
```

项目已内置便携 AI 后端：

```text
ai_engine/models/Qwen_Qwen3-0.6B-Q4_K_M.gguf
ai_engine/runtime/llama.cpp/
```

触发 AI 动态事件时，游戏会优先调用项目内的 `llama.cpp` 和 GGUF 模型，不要求玩家安装 Ollama。

当前模型桥行为：

- 优先尝试便携 `llama.cpp`
- 便携后端超时默认 25 秒
- 若便携失败，会自动尝试 Ollama
- Ollama 超时默认 20 秒
- 两者都失败时，游戏自动回退到内置动态模板
- 主界面左侧会显示当前动态事件后端与最近一次状态

如果想强制手动测试便携后端：

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File ai_engine\generate_event.ps1 -ReleaseDir release -Backend portable
```

如果想强制测试 Ollama：

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File ai_engine\generate_event.ps1 -ReleaseDir release -Backend ollama
```

Ollama 仍可作为备用后端。如果想用 Ollama，可以创建同名模型：

```bat
ollama pull qwen3:0.6b
ollama create wendao-xiuxian -f ai_engine/Modelfile.wendao
```

游戏会优先使用下面格式的事件：

```text
【机缘】雨夜古观
你在古观中听见前世的木鱼声，似乎有人在等你归来。
推门入观
绕行观察
叩问前世
```

没有 `ai_event.txt`、便携模型缺失、模型超时、或本地模型生成失败时，游戏会自动回退到内置动态模板。

## 打包分发

想让别人解压即玩，打包当前文件夹时保留这些内容：

```text
release/wendao_enhanced.exe
release/background.png
ai_engine/generate_event.ps1
ai_engine/models/Qwen_Qwen3-0.6B-Q4_K_M.gguf
ai_engine/runtime/llama.cpp/
启动游戏.bat
```

便携 AI 文件约 500MB；如果删掉 `ai_engine/models` 或 `ai_engine/runtime`，游戏仍能运行，只是 AI 动态事件会回退到模板或 Ollama。

## 小说语料边界

网上的优质小说适合拆成“叙事结构、事件模板、意象词库、取舍模式”来借鉴，不适合直接复制段落进游戏事件。当前本地模型提示词要求原创输出；如果后续使用公开小说数据集做训练、微调或检索，请先确认数据授权和许可证，并保留来源记录。

## 当前阶段

项目已经处于“可玩纵切版 / Alpha 原型”阶段：

- 核心玩法闭环已完成
- 动态世界、轮回传承、存档、动态事件桥均已接入主线
- 当前项目仍以文字修仙玩法剧情为主体，美术包装只服务第一眼吸引力
- 当前创新重点是本地 AI 动态事件、跨世记忆、传承回响与时代演化
- 目前仍有较多内容硬编码在 C++ 中
- 体验层和美术资源还有明显扩展空间

## 下一步建议

1. 把手写事件迁移到外部 JSON/CSV，降低后续扩展成本。
2. 拆分主程序中的大文件，逐步把 UI、事件、存档、战斗数值拆开。
3. 继续补 UI 反馈和美术资源，提升沉浸感与信息可读性。
4. 给动态事件增加更多结果类型，而不是主要依赖文本解析奖励。
