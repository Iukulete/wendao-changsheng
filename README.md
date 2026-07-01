# 问道长生 The Immortal Path

文本修仙 Roguelike，从凡人修炼到道祖，再到掌尽诸道的道祖-天道境。

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

- **21 个境界**：凡人 -> 道祖 -> 道祖-天道境
- **事件系统**：34 个手写事件 + 30% 概率动态事件
- **活的世界**：15 个 NPC 自主修炼、战斗、飞升
- **时代化修士**：活跃修士的名号、目标和资源争夺会随纪元变化
- **天下大事入记忆**：NPC 突破、坐化、复仇和世界事件会进入道途记忆，并作为下一次 AI 事件上下文
- **五行系统**：灵根影响修炼，飞升需五行均衡
- **因果系统**：选择会影响事件倾向和突破成功率
- **道途记忆**：关键选择、突破、死亡和转世会沉淀为可查看记忆
- **轮回传承**：死亡或证道会生成前世记录，下一世会想起部分具体道途碎片
- **玉意梦兆**：黑白伴生玉佩会在每世开局把前世未竟、旧梦、旧世残响或鸿蒙天象压成可追的主线线索，并在历练中触发一次玉意追兆事件
- **继承传承入局**：前世留下的功法、记忆、战斗本能、名声和灵宝器痕会在下一世历练中被点名触发
- **主动留传承**：本世历练中可刻下功法、写因果札或封存器痕，死亡后进入前世记录，下一世可作为前世遗响想起
- **传承扰动出身**：强记忆、善恶名声、战斗本能、通天灵宝残印和大道旧痕会改变下一世家世隐情与早期关注者
- **传承牵动人脉**：前世功法会被懂行者认作失传古法，善恶旧名和器痕会生成旧名仰慕者/追债人、器阁执事等本世关注者
- **传承命名**：前世功法会按杀伐、护生、血煞、因果、长生、众生等经历生成斩劫真名、青灯登仙经等可被后世认出的名字
- **时代解读旧法**：同一份失传古法会被仙朝定品、道网比对、灵机拆解、末法抢夺或废土残宗当作重建法统火种
- **本世继承重置**：每次转世的直接传承以上一世为主，远世影响沉淀在通天灵宝、纪元年表和前世记录中
- **未竟因果**：每世死亡会整理未完成的主线、人情债和旧世残响，下一世可继续追索
- **前世未竟事件**：上一世留下的旧债会提高历练中前世回响的触发率，并生成可抉择的追索事件
- **时代演化**：每一世会生成对应时代的宗门、地点和世界大事，不只是更换背景名
- **纪元转折因由**：下一世纪元会受上一世境界、因果、杀伐、传承、未竟因果影响，并写入 AI 上下文
- **纪元年表**：跨世记录每一世的纪元变迁，AI 可把前几世历史当成今生事件压力
- **旧世残响**：转世后上一纪元会留下遗址、制度、器物或断代线索，供本世主线和 AI 事件续写
- **本世主线**：每次转世生成本世主题和持续线索，AI 动态事件会优先围绕这些线索续写
- **本世主线阶段事件**：外出历练会推进每世最多三段主线阶段，让线索从显露、转折走向此世取舍
- **动态线索推进**：历练选择会把前世、势力、人脉、旧世残响、器物、大道和鸿蒙余波写回本世持续线索，后续 AI 事件可继续接上
- **剧情状态补丁**：每次事件会把近期摘要、未收束线头、关系压力和 NPC 近况写回统一剧情状态；稳定设定如鸿蒙至宝规则、伴生玉佩规则不会被模型输出覆盖
- **本世势力牵连**：每世根据时代、家世和资质生成宗门/仙朝/工坊/道网/残宗关系，形成可续写的旧债和身份
- **本世人脉**：父母、养育者、同辈、欺压者和时代联系人会形成持续关系线，并进入 AI 上下文
- **人脉历练事件**：外出历练可能直接触发父母认可、同辈嫉妒、欺压试探、势力递帖等本世关系事件
- **人情回响**：历练和 AI 抉择会反过来改变人脉关系、势力牵连值，并写入道途记忆
- **情绪余波**：关系变化会生成近日风声，让长辈护短、同辈嫉妒、势力审查或 NPC 记恩记仇继续发酵
- **情绪脉动**：闭关和历练推进世界后，父母、同辈、欺压者、执事等会因资质、家世、时代压力和风声自然改变态度
- **关系数值入 AI**：持续人脉和活跃修士的亲疏/敌意会写入模型提示词，方便事件续写旧怨与善缘
- **AI 抉择回响**：本地 AI 事件的选择结果会结合事件文本、旧世残响、人脉和灵宝状态写入道途记忆
- **传承后果结算**：AI 回退事件会针对失传古法、旧名追债和器痕识别生成专属选项与成败文本
- **大道与灵宝**：普通兵刃无法跨世，通天灵宝留下道痕，道祖与所掌大道共生
- **寿元压力**：仙帝以下仍受寿数追赶，寿元临近会进入 AI 上下文并触发延寿、闭死关或证道取舍；道祖才不再被寿元逼迫
- **本世器物**：今生得到的兵刃和普通法宝会进入本世记录，死亡后本体失散；若曾留下器痕，只会沉淀为通天灵宝共鸣
- **器物历练事件**：本世兵刃或法宝会在历练中应劫、破局、温养或封存器痕，强调本体不可跨世
- **灵宝觉醒**：通天灵宝共鸣达到阈值会进入器鸣初醒、认主残印、道胚成形等阶段，并沉淀进记忆
- **大道特性**：道祖掌握的不同大道会影响修炼、历练抉择和破境，不再只是境界数值
- **大道问心事件**：杀伐、护生、血煞、因果、长生、众生、本我、万道归一会触发不同试炼并推进掌道深度
- **纪元余波事件**：当前时代的大势、世界事件和旧世残响会在历练中主动触发制度、资源、灾变或道网压力
- **九大鸿蒙至宝**：九件创世级恒在之物，各有固定权柄、显化和禁忌；道祖不可毁灭，道祖-天道境才具备理论毁灭力，但毁灭没有必要
- **鸿蒙参悟**：玩家只能留下至宝投影、线索、拒绝和因果记忆；参悟过的至宝会有限推动道祖-天道境进度，但本体永不进入装备栏
- **世界反馈**：灵气暴动、宗门大战等世界事件会影响修炼和历练风险
- **本地模型桥**：动态事件会写出 `release/ai_prompt.txt`，优先尝试便携 Gemma 4 + `llama.cpp`，失败后回退到 Ollama 或内置模板
- **非阻塞 AI 等待**：触发本地模型事件时会显示“天机推演中”，窗口不会像卡死一样等待 CPU 生成
- **NPC 情绪代理**：本世人脉会带情绪标签、口吻示例、想要、忌惮和下一步倾向，让长辈护短、同辈嫉妒、执事卡资源、旧怨追债等关系进入事件文本
- **回退焦点轮换**：内置动态事件会在前世未竟、天下大事、旧世残响、大道、器物、人脉和势力之间轮换取材
- **上下文回退**：即使本地模型不可用，内置动态事件也会主动续写本世持续线索、势力牵连、本世器物、人脉和前世未竟因果
- **结构化解析闸门**：本地模型或未来 API 若输出 JSON，会先被解析为标题、描述、选项与场景数据；失败时仍回退到 5 行文本解析和模板修复

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
│   ├── setup_portable_ai.ps1
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

- **AI 事件概率**：修改 `src/wendao_enhanced.cpp` 中 `GetEraAiEventChance()` 或各纪元权重
- **NPC 数量**：修改 `world_system/dynamic_world.h` 的 `InitNPCs`
- **背景图**：替换 `assets/background.png` 后重新运行 `build.bat`

## 本地模型桥

触发动态事件时，游戏会在运行目录 `release/` 写出：

```text
ai_prompt.txt
ai_prompt_runtime.txt
ai_event.txt
ai_event_raw.txt
ai_scene.json
ai_backend.txt
ai_status.txt
ai_llama.log
ai_ollama.log
```

项目支持便携 AI 后端：

```text
ai_engine/models/gemma-4-E4B_q4_0-it.gguf
ai_engine/runtime/llama.cpp/
```

触发 AI 动态事件时，游戏会优先调用项目内的 `llama.cpp` 和 Gemma 4 GGUF 模型，不要求玩家安装 Ollama。开源仓库不会提交 `models/` 和 `runtime/` 这类大文件；拉仓库后可运行：

```bat
准备本地AI.bat
```

或：

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File ai_engine\setup_portable_ai.ps1
```

已有模型和运行时时，脚本会跳过重复下载；如脚本内填入 SHA256，会同时做哈希校验。

当前模型桥行为：

- 优先尝试便携 `llama.cpp`
- 默认 GGUF：`google/gemma-4-E4B-it-qat-q4_0-gguf` 的 `gemma-4-E4B_q4_0-it.gguf`
- 可通过 `WENDAO_GGUF_MODEL` 或 `ai_engine/model_path.txt` 指向其他 GGUF
- 可通过 `WENDAO_LORA_PATH` 或 `ai_engine/lora_path.txt` 挂载 llama.cpp 兼容 LoRA 适配器
- 如果没有显式配置 LoRA，脚本会自动发现 `ai_engine/lora/*.gguf`，优先使用 `wendao*` 适配器
- 便携脚本超时默认 75 秒；游戏内异步等待上限约 100 秒
- 若便携失败，会自动尝试 Ollama
- Ollama 超时默认 20 秒
- 两者都失败时，游戏自动回退到内置动态模板
- 主界面左侧会显示当前动态事件后端与最近一次状态
- 兼容两种模型输出：传统 5 行文本，以及包含 `title`、`description`、`choices`、`beats`、`storyStatePatch` 的 JSON；最终都会被清洗成游戏可用事件

如果想强制手动测试便携后端：

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File ai_engine\generate_event.ps1 -ReleaseDir release -Backend portable
```

如果想跑 7 组事件质量压测：

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File ai_engine\evaluate_ai_quality.ps1 -Backend portable -TimeoutSec 120
```

压测会写出 `release/ai_eval/ai_eval_report.txt` 和机器可读的 `release/ai_eval/ai_eval_summary.json`，方便比较不同模型或 LoRA 的 native/repaired/failed 比例。

如果想强制测试 Ollama：

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File ai_engine\generate_event.ps1 -ReleaseDir release -Backend ollama
```

Ollama 仍可作为备用后端。如果想用 Ollama，可以创建同名模型：

```bat
ollama pull gemma4:e4b
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
ai_engine/setup_portable_ai.ps1
ai_engine/models/gemma-4-E4B_q4_0-it.gguf
ai_engine/runtime/llama.cpp/
准备本地AI.bat
启动游戏.bat
```

便携 AI 文件约 5GB 以上；如果删掉 `ai_engine/models` 或 `ai_engine/runtime`，游戏仍能运行，只是 AI 动态事件会回退到 Ollama 或上下文模板。重新运行 `准备本地AI.bat` 可以补齐便携后端。

## LoRA 训练实验

`ai_engine/lora/` 中放了当前的 Gemma 4 LoRA 实验脚本：

- `build_wendao_lora_dataset.py`：生成原创修仙事件微调样本
- `train_gemma4_lora.py`：PEFT QLoRA 训练入口
- `run_remote_gemma4_lora.sh`：远端 x86 + NVIDIA Docker 训练启动脚本

训练产物、模型缓存和 GGUF/adapter 文件不进入仓库；训练完成后可通过 `WENDAO_LORA_PATH` 或 `ai_engine/lora_path.txt` 指向转换后的 llama.cpp LoRA。

## 开源项目借鉴边界

已参考 `zonghaoyuan/infiplot` 的高层数据流思想：`Session/Context -> Scene -> StatePatch`、稳定剧情设定与活动剧情状态分层、模型输出先解析/校验/修复再进入游戏。该项目使用 AGPL-3.0，本仓库没有直接复制其源码；这里只按同类架构重新实现适合本游戏的 C++/PowerShell 版本。

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
4. 继续给动态事件增加更明确的结果类型，逐步减少对文本奖励解析的依赖。
