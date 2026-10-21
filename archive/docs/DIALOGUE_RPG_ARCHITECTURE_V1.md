# 对话 RPG 化架构 v1

这份文档记录第一阶段的可运行骨架。旧版 `events_v014.json` 和现有
`EventCatalog` 仍然是默认运行路径；新对话图先以并行方式接入，按故事弧逐条迁移。

## 角色规则

- 所有具名角色先进入 `godot/data/characters/character_registry_v2.json`，再生成头像、对话胸像和战斗资源。
- 主要人物与次要人物都可以有普通、战斗、剧情或成人向风格的不同服装；是否强调身材由人物性格、场景和叙事功能决定，不由“主角/配角”标签决定。
- 成人向造型只对明确成年角色开放，且保持商业游戏可用的非露骨边界。年龄未知、未确认成年或未成年角色的卖肉上限固定为 0。
- 角色身份锚点必须跨服装保持一致：脸型、发型、体型、服装家族、核心道具和色彩语言至少保留其中的稳定组合。
- 江照雪以克制、修长、正经的视觉基准为主；男主保持修长而非矮胖的小人比例；没有明确形象的角色才使用身份卡中的自由发挥字段。

## 数据流

```text
剧情 JSON / C++ 社交逻辑
        ↓
character_mentions + story_event_refs
        ↓
character_registry_v2 + aliases + groups
        ↓
dialogue graph (Line / Choice / Condition / Check / Effect / Combat / End)
        ↓
DialogueDirector → PortraitController / CombatBridge / SaveAdapter
        ↓
DialogueUI
```

索引生成和校验命令：

```text
python tools/build_character_index.py --check-unresolved
python tools/validate_character_registry.py
python tools/validate_story_refs.py
python tools/validate_dialogue_data.py
```

## 运行时职责

- `DialogueRepository`：读取对话索引和场景图，校验节点及跳转，不改写旧事件。
- `DialogueDirector`：推进当前节点、检查选项、执行检定、记录光标，并发出战斗请求或结局信号。
- `DialogueConditionEvaluator`：只执行白名单数据条件，不执行脚本文本表达式。
- `DialogueEffectExecutor`：执行旗标、关系、声望、因果、服装和表情效果；事务 ID 防止读档后重复结算。
- `DialoguePortraitController`：按角色身份卡解析服装、表情和资源；对话胸像未完成时回退到已验收主立绘。
- `DialogueCombatBridge`：保存 encounter、当前节点和胜负返回路由，不把战斗逻辑复制进对话系统。
- `DialogueStorySaveAdapter`：持久化当前场景/节点、关系、旗标、声望、因果、表情/服装、程序 NPC 和战斗返回上下文。
- `LegacyEventAdapter`：把旧版三选一事件转换成临时对话图，供 UI 迁移期间使用。

## 试运行场景

1. `qingheng_first_meeting`：清蘅真人初见，选择会改变尊重/信任和旗标。
2. `xuanheng_first_inquiry`：玄衡子问询，展示旗标、声望隐藏选项和确定性检定。
3. `shuangya_first_intercept`：霜鸦截路，展示对话 → 战斗请求 → 胜负/撤退返回对话。

## 迁移顺序

1. 只生成身份库、别名、引用报告和验证器，不改变旧事件行为。
2. 用 `LegacyEventAdapter` 让旧事件先使用新的对话 UI。
3. 将试运行场景扩展成原生对话图，验证条件、关系、存档和战斗返回。
4. 按故事弧迁移；只有当旧事件覆盖数为 0 时，才退休 `events_v014.json` 的对应路径。
5. 运行时稳定后，按身份卡批量生成非战斗角色的头像/立绘，再补对话表情和成人场景服装变体。
