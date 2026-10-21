# 全量角色审计 v2

这份审计把“运行时已注册角色”和“原作中出现、但还没有身份卡的候选”分开。候选不等于正式角色，也不会自动进入立绘生成队列；每个候选都要经过剧情证据、别名合并、年龄和身份复核。

## 当前覆盖范围

- `godot/data/chronicles/*.json`：六条编年线，覆盖古典、末法、灵机蒸汽、星穹道网、废土返道、永恒仙朝内容。
- `godot/data/story_arcs_v1.json`
- `godot/data/events_v014.json`
- `src/wendao_enhanced.cpp`

运行：

```text
python tools/build_character_census.py
```

报告写入 `godot/data/generated/character_census_v2.json`。报告中的 `candidates` 只代表需要人工审核的名字证据，`category_guess` 只是启发式分类。
美术待办写入 `godot/data/generated/character_art_backlog_v2.json`：`candidates` 是可进入身份卡/出图流程的高置信名字，`story_review_pool` 则保留普查发现的全部命名、角色群体和待语义复核项，任何候选都不会因未达到美术门槛而静默丢失。

## 生成规则

1. 先收集结构化 `character_id`、`speaker_id`、`participants`、战斗引用等，并与现有注册表、别名表合并。
2. 再从叙事文本中收集“名叫/自称/名为”等显式命名证据，以及带人物动作、称谓的人名形态。
3. 每个候选保留来源文件、路径、证据类型和上下文片段，避免只凭名字猜角色。
4. 职位、家族、队伍、机关、代号和叙述短语先留在审核队列，不生成正式立绘。
5. 年龄未确认或属于未成年人时，呈现尺度默认锁定为 0；只有身份卡通过后才能进入 Portrait Master 阶段。
6. 仅由泛称构成的误识别（例如“高阶修士”“高阶护道”）转入角色/群体审阅池，不伪造独立姓名、身份卡或立绘；确有独立个体证据后再提升。

## 当前决策门

```text
候选名 → 剧情身份卡 → 别名/同人合并 → 年龄与呈现审核
       → 非战斗立绘或战斗规格 → 网页端风格审核 → 资源生成
```

现有已经通过的资产继续作为反向对照样本；新风格校准图只有通过身份门后，才会替换正式引用。
