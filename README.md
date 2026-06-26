# 问道长生 The Immortal Path

文本修仙 Roguelike，从凡人修炼到道祖。

当前主版本是 **AI增强版**：

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

- **20个境界**：凡人 -> 道祖
- **事件系统**：24个手写事件 + 30%概率动态模板事件
- **活的世界**：15个NPC自主修炼、战斗、飞升
- **五行系统**：灵根影响修炼，飞升需五行均衡
- **因果系统**：选择会影响事件倾向和突破成功率
- **道途记忆**：关键选择、突破、死亡和转世会沉淀为可查看记忆
- **轮回传承**：死亡或证道会生成前世记录，下一世继承余韵
- **世界反馈**：灵气暴动、宗门大战等世界事件会影响修炼和历练风险
- **本地模型桥**：动态事件会写出 `release/ai_prompt.txt`，并尝试用 Ollama 生成 `release/ai_event.txt`

## 操作

```text
[1] 打坐修炼
[2] 外出历练  - 可能触发动态事件
[3] 突破境界
[4] 服用丹药
[5] 灵石闭关
[W] 查看世界  - 看NPC状态
[H] 道途记忆
[G] 前世传承/成就
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
│   └── ai_core.h
├── world_system/
│   └── dynamic_world.h
├── procedural_gen/
│   └── procedural_gen.h
├── legacy_system/
│   └── legacy_system.h
├── battle_system/
├── assets/
│   └── background.png
├── release/
│   └── wendao_enhanced.exe
├── build.bat
├── 启动游戏.bat
└── README.md
```

## 自定义

- **AI事件概率**：修改 `src/wendao_enhanced.cpp` 中 `Random(1, 100) <= 30` 的 `30`
- **NPC数量**：修改 `world_system/dynamic_world.h` 的 `InitNPCs`
- **背景图**：替换 `assets/background.png` 后重新运行 `build.bat`

## 本地模型桥

触发动态事件时，游戏会在运行目录 `release/` 写出：

```text
ai_prompt.txt
```

项目已内置便携 AI 后端：

```text
ai_engine/models/Qwen_Qwen3-0.6B-Q4_K_M.gguf
ai_engine/runtime/llama.cpp/
```

触发 AI 动态事件时，游戏会优先调用项目内的 `llama.cpp` 和 GGUF 模型，不要求玩家安装 Ollama。模型输出会先保存在 `release/ai_event_raw.txt`，清洗后的 5 行事件写入 `release/ai_event.txt`，使用的后端写入 `release/ai_backend.txt`。

如果想强制手动测试便携后端：

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File ai_engine\generate_event.ps1 -ReleaseDir release -Backend portable
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

没有 `ai_event.txt`、便携模型缺失、或本地模型生成失败时，游戏自动回退到内置动态模板。

### 打包分发

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

### 小说语料边界

网上的优质小说适合拆成“叙事结构、事件模板、意象词库、取舍模式”来借鉴，不适合直接复制段落进游戏事件。当前本地模型提示词要求原创输出；如果后续使用公开小说数据集做训练、微调或检索，请先确认数据授权和许可证，并保留来源记录。

## 下一步建议

1. 给项目初始化 Git，并提交当前可玩纵切版本。
2. 把事件数据迁移到外部 JSON/CSV，继续扩展内容而不频繁改 C++。
3. 给本地模型桥增加超时和更友好的失败提示。
4. 后续补美术资源和更完整的窗口布局。
