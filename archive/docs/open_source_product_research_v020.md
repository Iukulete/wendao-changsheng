# 成熟开源游戏产品研究 v0.20

更新日期：2026-07-22。

本文件记录可落实为原创系统的产品原则。它不是素材下载清单，也不授权复制其他项目的角色、卡牌、剧情、数值、界面、语音或美术。

## 研究方法：看固定源码，不看项目名气

凡形成 P0/P1 落地规格的核心项目都固定到一个提交，直接检查运行时源码、数据定义、测试和许可证；每项结论必须同时写出“源码证据、原创转化规格、反例、自动验收、许可边界”。Battle for Wesnoth 与 Mindustry 暂只保留为横向方向，不作为实现证据。项目受欢迎只能说明值得研究，不能证明每段实现都值得照搬，也不能证明仓库里的每件素材都可商用。

| 参考项目 | 本项目要回答的问题 | 不从它那里取得什么 |
| --- | --- | --- |
| 无名杀 | 一次行动怎样被规则、角色、装备、反馈和 AI 共同改写 | 三国杀角色、卡牌、UI、文案、数值、音频和美术 |
| Starpoint | 剧情触发的战斗怎样开始、恢复、结算并留下长期记录 | 原游戏 CDN、角色数据、关卡数据和不可信的服务端结算写法 |
| Shattered Pixel Dungeon | 敌人、首领、掉落和教学怎样持续提出可读但不重复的问题 | 原作职业、敌人、关卡、数值、文本和资产 |
| Endless Sky | 选择怎样真正通往不同节点，世界条件怎样让路线继续汇合与分叉 | 原作任务、世界观、对话、星图、音频和图像 |
| Battle for Wesnoth / Mindustry | 长战役内容包和高频数据定义怎样被工具长期维护 | 原作战役、单位、地图、科技树、数值和素材 |

## 无名杀：复杂度来自可组合规则

研究仓库：[libnoname/noname](https://github.com/libnoname/noname)，审计固定在提交
[`3987ed397ca7574f25b92b5ff9d688553f6864c1`](https://github.com/libnoname/noname/tree/3987ed397ca7574f25b92b5ff9d688553f6864c1)。
以下定位和数量均以该提交为准，避免后续上游改动令结论失真。

### 它为什么不像临时原型

- [`docs/game-event/lifecycle.md`](https://github.com/libnoname/noname/blob/3987ed397ca7574f25b92b5ff9d688553f6864c1/docs/game-event/lifecycle.md)、[`relationships.md`](https://github.com/libnoname/noname/blob/3987ed397ca7574f25b92b5ff9d688553f6864c1/docs/game-event/relationships.md) 和 [`trigger.md`](https://github.com/libnoname/noname/blob/3987ed397ca7574f25b92b5ff9d688553f6864c1/docs/game-event/trigger.md) 把行为组织为有父子关系和严格时序的事件树。Before、Begin、Content、End、After、Omitted、Skipped、Cancelled 各有语义，`next` / `after`、取消和结果对象可以组合而不会靠 UI 猜测当前状态。对应实现位于 [`apps/core/noname/library/element/GameEvent/`](https://github.com/libnoname/noname/tree/3987ed397ca7574f25b92b5ff9d688553f6864c1/apps/core/noname/library/element/GameEvent) 和 [`gameEvent.ts`](https://github.com/libnoname/noname/blob/3987ed397ca7574f25b92b5ff9d688553f6864c1/apps/core/noname/library/element/gameEvent.ts)。
- [`apps/core/character/standard/index.js`](https://github.com/libnoname/noname/blob/3987ed397ca7574f25b92b5ff9d688553f6864c1/apps/core/character/standard/index.js) 将角色、技能、卡牌、翻译、动态说明、语音、排序和人物介绍作为一个内容包装配；[`character.js`](https://github.com/libnoname/noname/blob/3987ed397ca7574f25b92b5ff9d688553f6864c1/apps/core/character/standard/character.js) 只声明角色和技能引用，[`skill.js`](https://github.com/libnoname/noname/blob/3987ed397ca7574f25b92b5ff9d688553f6864c1/apps/core/character/standard/skill.js) 再声明触发、条件、代价、目标、效果、展示和 AI。[`docs/lib-skill-format.md`](https://github.com/libnoname/noname/blob/3987ed397ca7574f25b92b5ff9d688553f6864c1/docs/lib-skill-format.md) 对这份契约有完整说明。
- [`apps/core/card/standard.js`](https://github.com/libnoname/noname/blob/3987ed397ca7574f25b92b5ff9d688553f6864c1/apps/core/card/standard.js) 的一张牌同时声明可用时机、次数、范围、目标、响应、效果和 AI 标签。玩家点的不是孤立按钮，而是会被角色技能、装备、状态、目标和响应窗口共同改写的规则对象。
- [`apps/core/noname/ai/basic.js`](https://github.com/libnoname/noname/blob/3987ed397ca7574f25b92b5ff9d688553f6864c1/apps/core/noname/ai/basic.js) 在真实候选按钮、牌和目标上调用同一套价值函数；牌和技能再提供局部 `ai` 评价。它不是高级搜索 AI，但自动玩家与真人共用合法性和效果契约，不另造一套演示逻辑。
- [`apps/core/noname/library/element/player.js`](https://github.com/libnoname/noname/blob/3987ed397ca7574f25b92b5ff9d688553f6864c1/apps/core/noname/library/element/player.js) 的 `logSkill`、`trySkillAnimate`、`$damagepop`、`$damage`、`line` 和 `markSkill`，配合 [`apps/core/noname/game/index.js`](https://github.com/libnoname/noname/blob/3987ed397ca7574f25b92b5ff9d688553f6864c1/apps/core/noname/game/index.js) 的 `log`、`logv`、`addVideo`，把同一规则变化同时投射为连线、跳字、状态标记、日志、历史条目和录像。一次点击因此有多层一致反馈。
- [`apps/core/noname/get/audio.ts`](https://github.com/libnoname/noname/blob/3987ed397ca7574f25b92b5ff9d688553f6864c1/apps/core/noname/get/audio.ts) 和 [`docs/audio-guide.md`](https://github.com/libnoname/noname/blob/3987ed397ca7574f25b92b5ff9d688553f6864c1/docs/audio-guide.md) 将技能、角色、皮肤和阵亡语音映射为可引用、可变体、可缓存的音频意图；规则层不直接散落硬编码文件路径。
- [`apps/core/mode/`](https://github.com/libnoname/noname/tree/3987ed397ca7574f25b92b5ff9d688553f6864c1/apps/core/mode)、[`apps/core/mode/brawl.js`](https://github.com/libnoname/noname/blob/3987ed397ca7574f25b92b5ff9d688553f6864c1/apps/core/mode/brawl.js) 和 [`scripts/extension-template/default/src/index.ts`](https://github.com/libnoname/noname/blob/3987ed397ca7574f25b92b5ff9d688553f6864c1/scripts/extension-template/default/src/index.ts) 让模式、场景、关卡和扩展通过稳定入口复用内核。该提交包含 15,122 个文件、26 个角色包、12 个模式和 9 个牌包；规模不是可复制的捷径，但说明接口经受过长期内容增长。
- 构建侧有 [`build.yml`](https://github.com/libnoname/noname/blob/3987ed397ca7574f25b92b5ff9d688553f6864c1/.github/workflows/build.yml)、[`lint-check.yml`](https://github.com/libnoname/noname/blob/3987ed397ca7574f25b92b5ff9d688553f6864c1/.github/workflows/lint-check.yml) 和 [`release.yml`](https://github.com/libnoname/noname/blob/3987ed397ca7574f25b92b5ff9d688553f6864c1/.github/workflows/release.yml)，但仓库树中没有实质性的游戏规则自动测试，只有 Android 模板示例测试。应借鉴其产品闭环和内容边界，不继承旧 step 语法、巨型脚本和测试欠账。

### P0：先补齐一次操作的完整闭环

| 优先级 | 无名杀证据 | 本项目的原创改造位置 | 自动验收门槛 |
| --- | --- | --- | --- |
| P0-1 事件内核 | `GameEvent` 生命周期、事件树、`next` / `after`、trigger 排序 | 将 `godot/scripts/combat_system.gd::perform_action()` 的单体流程拆成确定性的行动声明、支付、行动前、效果、受击、行动后、回合末、阶段变化和结算事件；`main.gd`、`combat_stage.gd`、`audio_director.gd` 只消费结构化结果 | 至少 1,000 个固定种子从事件记录重放后最终 state hash 100% 一致；非法相位 0；同一结算重复调用不二次加奖或写旗标 |
| P0-2 数据驱动招式 | 角色只引用技能；技能声明条件、代价、目标、效果、展示和 AI | 把 `ACTION_NAMES`、`COUNTER_ACTIONS` 和逐敌常量逐步迁入原创 `combat_techniques` / `combat_enemies` 定义；优先复用 `DungeonSystem` 与 `dungeon_cards_v1.json` 已有的效果原语和校验，主线界面称“招式”或“功法”，不建立另一套卡牌收藏 | 六条道途各至少 4 个可构筑招式；正常回合至少 3 个非同质合法行动；所有 ID、效果、文本和 cue 引用校验通过 |
| P0-3 响应与持续规则 | `trigger/filter/cost/content/mod`，`firstDo` / `lastDo` | 提供 `before_action`、`on_action`、`before_damage`、`after_damage`、`turn_end`、`phase_change`、`combat_end` 钩子；装备、道途、羁绊和敌人签名统一注册，不再各自在主函数插条件 | 同时触发时顺序完全确定；循环触发有硬上限并 fail-closed；存取档后顺序不变；每名敌人至少有一项真实改变决策的触发规则 |
| P0-4 反馈编排 | `logSkill` 同时驱动动画、连线、日志、音频、标记和录像 | 让一个 CombatEvent 生成语义 cue bundle，由 `combat_stage.gd`、`dungeon_feedback_layer.gd` 和 `audio_director.gd` 统一表现轨迹、命中停顿、受击位移、数值跳字、状态标记、一句战斗叙述和音乐重音；正式美术未到位时不用程序化小人冒充插画 | 每种事件的 cue ID 均能解析；动作后画布像素确有变化；临时节点全部自动清理；静音和低动态模式可完成全流程；多分辨率无重叠和布局跳动 |
| P0-5 结构化胜负余波 | `GameEvent.result`、`identity.js::checkResult/addRecord/showIdentity` | 接入现有 `EncounterSystem` 和 `NarrativeConsequenceSystem`；胜利、失败、脱战分别返回 typed outcome，夺回证据、击退追兵等成功事实只能在真实胜利后写入 | 所有会产生敌踪的剧情选择逐项跑胜、败、逃三结局；败/逃含胜利旗标数为 0；敌踪只消费一次；恢复存档后没有常亮入口 |
| P0-6 共用 AI 评价 | `ai/basic.js` 在真实合法候选上调用局部价值函数 | 自动试玩不再硬编码“推荐动作”，而使用与玩家预测相同的合法性、成本和效果评价，并提供进攻、稳健、节能、脱身等策略权重 | 非法选择率 0；预测与实际同公式；至少 4 种策略的行动分布不同；10,000 局报告动作熵、支配动作、阶段到达率和签名触发率，不只报告崩溃数 |

### P1：让构筑、敌人与模式持续产生新问题

| 优先级 | 无名杀证据 | 本项目的原创改造位置 | 自动验收门槛 |
| --- | --- | --- | --- |
| P1-1 敌人内容包 | 角色包把身份、技能、翻译、动态说明和语音分离；技能在事件时机改变规则 | 将 `combat_system.gd` 目前 12 个签名和第二相外置；第二相改变可用性、成本、状态或触发窗口，不只重排 intent | 12 名普通敌人各有唯一规则和唯一第二相决策差；每项签名在定向测试中真实改变状态，预测和实际一致 |
| P1-2 构筑改变决策 | 角色引用技能、技能 `mod` 改规则、牌和技能共享标签 | `ItemSystem`、六大道途、人物承诺、前世记忆向招式池和触发器注入或变形能力，不再只加攻防 | 同敌同基础属性下至少 4 个构筑产生不同合法行动集和行动分布；聚合模拟中没有单一行动超过 55%；不存在永久不可用招式 |
| P1-3 共用效果原语与模式 | `mode/*`、brawl 场景/阶段和 extension 包都复用事件内核 | 普通交锋、秘境、首领试炼共享伤害、护体、状态、支付、触发和结算原语；保留不同抽取/冷却/路线规则，禁止再造第三套战斗公式 | 同一效果契约测试在所有模式通过；任一模式都能保存、退出、恢复；规则包不直接操作 UI 节点 |
| P1-4 可重放战斗史与状态化表现 | `addVideo/logv` 记录行为；音频和皮肤支持角色上下文变体 | 保存有界的语义事件时间线，用于战史、问题复现和自动试玩；为未来正式角色图预留常态、受创、破势、第二相等表现槽，缺图时回退为排版和状态符号 | 每场战斗可从开局快照和事件时间线复现；历史上限有效；表现资源缺失时不报错、不重复错图，manifest 校验给出明确缺口 |

### 许可证与不可复制边界

1. 根 [`LICENSE`](https://github.com/libnoname/noname/blob/3987ed397ca7574f25b92b5ff9d688553f6864c1/LICENSE) 和 `apps/core/LICENSE` 均为 GPL-3.0。本项目是 AGPL-3.0；两种许可证有组合条款，但复制、翻译或改编其源码仍会产生来源声明、对应源码和许可证保留义务，不能把改写成 GDScript 当作“原创”。本项目采用独立设计和独立实现，不复制代码。
2. 上游 [`README.md`](https://github.com/libnoname/noname/blob/3987ed397ca7574f25b92b5ff9d688553f6864c1/README.md) 另外请求保留出处并“不要用于商业用途”。该请求与 GPL 正文之间存在解释张力；本项目不依赖这种张力取得许可，直接排除源码和仓库资产。
3. `apps/core/audio/`、`apps/core/image/`、`theme/` 和扩展目录含大量三国杀及其他作品相关角色、牌面、语音、音乐和皮肤；审计路径没有提供足以证明每件资产可商用再分发的逐文件来源。仓库公开或根目录带 GPL 都不能替代资产权利链，因此一律不下载、不转换、不打包。
4. 不复制角色/技能文案、台词、模式名称、数值表、牌组清单、界面构图、动效造型、商标或角色形象；也不使用近似命名暗示与无名杀或三国杀存在官方关系。
5. 可以借鉴的是抽象机制：事件生命周期、条件/代价/效果分离、响应窗口、共用 AI 评价、语义反馈和内容包边界。落地时必须使用本项目自己的修仙语义、数据结构、数值、文本和 Godot 实现。
6. 若未来发现合适开源美术或音频，只接受有独立原始来源、明确作者、明确版本、明确 CC0/CC BY/CC BY-SA 等商用条款且能写入本项目 manifest 的单项资源；不能以无名杀仓库作为二次来源完成许可审计。

## 逐项目证据与横向参考

### Battle for Wesnoth

[官方仓库](https://github.com/wesnoth/wesnoth) 以 GPLv2 发布。官方 README 明确强调多套战役各自拥有战术挑战、情绪剧情和难度，同时以 WML/Lua 支持场景、时代和完整战役扩展。

可转化原则：把章节、遭遇、敌人编队、胜败目标和回响做成可验证内容包；同一底层规则通过作者编排产生不同关卡问题。

### Starpoint：任务闭环值得学，结算信任边界必须重做

研究仓库：[Duosion/starpoint](https://github.com/Duosion/starpoint)，审计固定在提交
[`7a5a1a7f7cd3447cc6d5584e539384c3c4096232`](https://github.com/Duosion/starpoint/tree/7a5a1a7f7cd3447cc6d5584e539384c3c4096232)。它是已停服弹珠手游的服务端重实现，适合研究任务进度与长期记录，不是可以直接移植的完整战斗设计。

#### 源码证据

- [`singleBattleQuest.ts`](https://github.com/Duosion/starpoint/blob/7a5a1a7f7cd3447cc6d5584e539384c3c4096232/src/routes/api/singleBattleQuest.ts) 明确区分 `start`、`finish`、`abort` 和 `play_continue`，结算会记录首通、最佳时间、最高评价和最高分。这说明一场战斗不是常亮按钮，而是有来源、活动态、终态和历史回响的任务交易。
- [`storyQuest.ts`](https://github.com/Duosion/starpoint/blob/7a5a1a7f7cd3447cc6d5584e539384c3c4096232/src/routes/api/storyQuest.ts) 只在首次完成时发放清关奖励并写入进度，表现出幂等结算的正确意图。
- [`wdfpData.ts`](https://github.com/Duosion/starpoint/blob/7a5a1a7f7cd3447cc6d5584e539384c3c4096232/src/data/wdfpData.ts) 用 SQLite 保存任务进度、活动、队伍和玩家状态。长期体验依赖持久化事实，而不是 UI 临时变量。

#### 原创转化规格

1. 现有 `EncounterSystem.offer()` 拒绝第二个活动敌踪、`CombatSystem.start_combat()` 要求剧情敌踪、`NarrativeConsequenceSystem.resolve_combat_outcome()` 幂等结算，保留为最低基线；不得退回“战斗随时可进”的全局入口。
2. 将敌踪定义为可保存的状态机：`offered -> started -> won | lost | escaped | aborted`。每个转移携带唯一 encounter ID、来源 node ID、开始快照和结算 ID；只有活动敌踪可以进入战斗，终态不能再次开始或领奖。
3. 胜负、耗时、伤势、资源消耗和奖励均由本地权威规则从事件记录计算，UI 和自动试玩只能提交选择，不能提交“我已胜利”“我的得分”之类结论。
4. 在角色状态页用剧情内事实说明当前目标、未了之事、人物关系和已知线索；不显示“可预见后果”“未知风险”或系统推荐。玩家应从正文、人物态度和已有情报自行判断。
5. 每次终态写一条短回响并更新人物/地点事实，使战斗成为剧情句号或转折，而不是脱离小说主线的重复小游戏。

#### 上游反例：明确不照搬

- `activeQuests` 只是进程内字典；第二次 `start` 会静默删除旧活动任务再覆盖，服务重启也会丢失活动态。本项目必须持久化并拒绝非法覆盖。
- `finish` 信任客户端上报的 `elapsed_time_ms`、`score`、`is_accomplished` 和额外资源；部分首通、最高评级与积分奖励在 `is_accomplished` 分支之前发放。这是结算顺序和信任边界反例。
- [`mission.ts`](https://github.com/Duosion/starpoint/blob/7a5a1a7f7cd3447cc6d5584e539384c3c4096232/src/routes/api/mission.ts) 的任务进度接口基本返回空数组。固定提交约 245 个文件、52 个 `assets/*.json`，仓库树中没有测试路径；功能数量不能替代规则验证。

#### 自动验收

- 用至少 1,000 组固定种子覆盖 `offer/start/finish/abort/reload`；非法转移为 0，读档后活动态和 state hash 一致。
- 对同一 encounter 重复 `start`、重复结算、先败后报胜、先终止后继续；必须拒绝且奖励、旗标、敌踪消费次数均不超过 1。
- 篡改 UI 侧耗时、分数、血量和奖励字段不能改变权威事件记录计算出的结果。
- 所有可产生敌踪的剧情选择逐项跑赢、输、逃、退出、读档；非胜利结局不得写入胜利事实，终态后入口不常亮。
- 保存首通、最佳表现与重要失败，但历史记录有上限；升级旧存档后不能重开已完成敌踪或重复领取回响。

#### 许可边界

根 [`LICENSE`](https://github.com/Duosion/starpoint/blob/7a5a1a7f7cd3447cc6d5584e539384c3c4096232/LICENSE) 是 GPLv3，而 [`package.json`](https://github.com/Duosion/starpoint/blob/7a5a1a7f7cd3447cc6d5584e539384c3c4096232/package.json) 标为 ISC，元数据存在冲突；本项目不复制源码。上游 [`README.md`](https://github.com/Duosion/starpoint/blob/7a5a1a7f7cd3447cc6d5584e539384c3c4096232/README.md) 要求用户自行提供 `.cdn`，[`cdn-download.md`](https://github.com/Duosion/starpoint/blob/7a5a1a7f7cd3447cc6d5584e539384c3c4096232/docs/cdn-download.md) 明说其中含角色、音乐等原游戏文件且完整约 30 GB。`.cdn` 与 `assets/*.json` 不能因服务端仓库公开而被视作可商用素材或原创数据，一律不引入。

### Shattered Pixel Dungeon：敌人靠行为被记住

研究仓库：[00-Evan/shattered-pixel-dungeon](https://github.com/00-Evan/shattered-pixel-dungeon)，审计固定在提交
[`7b8b845a76fe76c6b7c031ae9e570852411f56db`](https://github.com/00-Evan/shattered-pixel-dungeon/tree/7b8b845a76fe76c6b7c031ae9e570852411f56db)。这里借鉴的是“玩家看到预兆、理解规则、作出反制”的设计闭环，不把小说流程改造成随机地牢。

#### 源码证据

- [`Mob.java`](https://github.com/00-Evan/shattered-pixel-dungeon/blob/7b8b845a76fe76c6b7c031ae9e570852411f56db/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/actors/mobs/Mob.java) 把敌人组织为睡眠、游荡、调查、追猎、逃跑和被动状态，并保存 `state` 与 `target`。敌人可预测但不等于只循环一次攻击。
- [`Snake.java`](https://github.com/00-Evan/shattered-pixel-dungeon/blob/7b8b845a76fe76c6b7c031ae9e570852411f56db/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/actors/mobs/Snake.java) 只在玩家连续未命中后出现针对性提示；教学由真实挫折触发，而不是界面常驻“推荐操作”。
- [`Necromancer.java`](https://github.com/00-Evan/shattered-pixel-dungeon/blob/7b8b845a76fe76c6b7c031ae9e570852411f56db/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/actors/mobs/Necromancer.java) 让召唤先预警并保存召唤位置、随从 ID，之后还能治疗、强化或传送随从。一个签名机制会持续改变战场关系。
- [`Goo.java`](https://github.com/00-Evan/shattered-pixel-dungeon/blob/7b8b845a76fe76c6b7c031ae9e570852411f56db/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/actors/mobs/Goo.java) 的重击先蓄力警告，水中会回血，半血后狂暴；[`DM300.java`](https://github.com/00-Evan/shattered-pixel-dungeon/blob/7b8b845a76fe76c6b7c031ae9e570852411f56db/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/actors/mobs/DM300.java) 依据可达性和目标状态选择毒气或落石，落石先标记危险区域，血量阈值触发无敌充能并要求处理场景目标；[`Tengu.java`](https://github.com/00-Evan/shattered-pixel-dungeon/blob/7b8b845a76fe76c6b7c031ae9e570852411f56db/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/actors/mobs/Tengu.java) 限制单次伤害跨越多个血量档位，并在跳跃后逐步提高陷阱和能力密度。首领阶段是决策变化，不是换皮加血。
- [`Generator.java`](https://github.com/00-Evan/shattered-pixel-dungeon/blob/7b8b845a76fe76c6b7c031ae9e570852411f56db/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/items/Generator.java) 使用耗尽后重置的权重牌库控制物品供给，神器牌库不重置所以不会重复；牌库状态与随机游标进入存档。随机性因此同时有变化、供给下限和可恢复性。
- [`Statistics.java`](https://github.com/00-Evan/shattered-pixel-dungeon/blob/7b8b845a76fe76c6b7c031ae9e570852411f56db/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/Statistics.java) 与 [`Bestiary.java`](https://github.com/00-Evan/shattered-pixel-dungeon/blob/7b8b845a76fe76c6b7c031ae9e570852411f56db/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/journal/Bestiary.java) 保存击杀、探索、首领表现以及见过/交锋次数，说明“是否有趣”要靠行为数据审计，不只看是否崩溃。

#### 原创转化规格

1. `combat_system.gd` 现有 12 个敌人签名和第二阶段是基线；每项签名继续升级为会改变合法行动、行动成本、目标优先级、资源价值或时机的规则，不能只改意图文本或伤害倍率。
2. 敌人的强行动至少提前一个完整玩家决策窗口，用动作、排版、状态标记、叙述和声音表达同一预兆；反制不直接写成“推荐按某按钮”，而由功法描述、敌人行为和此前经验让玩家推理。
3. 首领阶段阈值不可被一次爆发跳过；每阶段至少引入一个新问题并移除或改写一个旧问题，最终阶段改变节奏和音乐，但不靠无提示秒杀制造难度。
4. 只在玩家已用行为证明误解规则时触发一次短提示，并把提示写成角色观察或战斗叙述；已掌握的玩家不被教程打断，未知后果也不提前泄露。
5. 稀有事件、关键补给和救急资源使用可持久化权重牌库；保证给定窗口内的最低供给，同时保留不可预测的具体顺序。剧情主节点不进入随机牌库。
6. 装备、消耗品和六大道途必须提供改变局势的工具，例如截断蓄力、挪动时序、换取情报、承受代价或改变目标；不把所有构筑压缩成更大的攻防数字。

#### 反例与自动验收

- 不照搬“随机楼层就是耐玩”的表象。小说式主线由作者控制因果，随机系统只填充可替换的遭遇、补给和短回响，不能打断角色动机或让同一人物无缘无故反复出现。
- 不让所有敌人共用同一种红光蓄力，也不在选项旁显示未知风险、胜率或系统推荐；可读性来自一致的世界规则，不是 UI 剧透。
- 对每个签名至少跑 1,000 个固定种子，统计触发率、玩家反制率、最长重复行动串、阶段到达率、消耗品使用率和无解状态；签名必须在定向测试中真实改变最终状态。
- 对所有首领血量阈值做边界测试；任意单次伤害不能跳过规定阶段，预警出现到效果结算之间必须存在合法反制窗口，存取档不能消除预警或重置阶段。
- 权重牌库在 10,000 局中满足声明的供给窗口、唯一资源不重复、同种子可重放、读档后序列不变；连续坏运气上限必须可证明。
- 自适应提示仅在对应失败模式达到阈值后出现，单存档每条至多一次；关闭提示不影响规则，提示文本不能替玩家选择。

#### 许可边界

根 [`LICENSE.txt`](https://github.com/00-Evan/shattered-pixel-dungeon/blob/7b8b845a76fe76c6b7c031ae9e570852411f56db/LICENSE.txt) 与源码头为 GPL-3.0-or-later；[`recommended-changes.md`](https://github.com/00-Evan/shattered-pixel-dungeon/blob/7b8b845a76fe76c6b7c031ae9e570852411f56db/docs/recommended-changes.md) 要求衍生项目更换产品名和包名并保留既有署名，也建议更换图标和标题。仓库没有足以支持本项目逐资产引入的统一许可清单，因此不复制源码，不引入角色、敌人、美术、音频、文本、地图或数值；只把上述抽象闭环以原创修仙语义、数据和 Godot 代码重新实现。

### Endless Sky：分支不是多写三段文本，而是可验证的世界状态机

研究仓库：[endless-sky/endless-sky](https://github.com/endless-sky/endless-sky)，审计固定在提交
[`dfd1d3ae8908e7b3261626333982827c18183cae`](https://github.com/endless-sky/endless-sky/tree/dfd1d3ae8908e7b3261626333982827c18183cae)。
以下只借鉴抽象机制；源码、任务正文和素材均不进入本项目。

#### 源码层证据

- [`Conversation.h`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/Conversation.h#L103-L145) 明确定义“节点网络”，节点可以是正文、场景、选择、自动条件分支或动作；[`Conversation.cpp`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/Conversation.cpp#L39-L185) 负责标签和跳转解析，并检查悬空标签以及没有玩家决策的自动死循环。它不是“第 1/4 段、第 2/4 段”数组，而是有稳定目标的有向图。
- 显示和可选是两个不同契约。[`Conversation.cpp`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/Conversation.cpp#L395-L400) 用 `toActivate` 判定能否点击，[同文件](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/Conversation.cpp#L499-L509) 用 `toDisplay` 判定是否存在于界面，[解析处](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/Conversation.cpp#L539-L599) 也将两者分别保存。[`ConversationPanel.cpp`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/ConversationPanel.cpp#L228-L252) 会显示但置灰未激活项，[键盘处理](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/ConversationPanel.cpp#L351-L376) 和 [索引映射](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/ConversationPanel.cpp#L553-L562) 都不会把隐藏项误当成可选项；若所有作者选项都隐藏，[面板显式回退到 `DECLINE`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/ConversationPanel.cpp#L484-L496)。
- [`Mission.cpp`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/Mission.cpp#L128-L402) 把 offer、accept、defer、decline、complete、fail、abort、期限、重复次数、途经点、NPC、计时器、地点和触发动作装配到同一任务模板；[优先、非阻塞、次要任务的语义](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/Mission.cpp#L724-L754) 让主线锚点和小事件能共存，而不是每回合都抢占玩家。
- “能看见任务”不等于“能接受任务”，更不等于“已经完成”。[`CanOffer` 与 `CanAccept`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/Mission.cpp#L981-L1049) 分别检查出现条件、失败条件、重复上限、动作资源和空间；[`CanComplete`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/Mission.cpp#L1073-L1128) 还检查途经点、NPC、强制计时器、位置、货物和乘客。[状态写入](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/Mission.cpp#L1242-L1338) 维护 offered、active、declined、done、failed、aborted；ABORT 没有专属动作时才兼容性回退到 FAIL。
- [`GameAction.h`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/GameAction.h#L43-L77) 将“任务到达里程碑或对话进入动作节点后发生什么”定义为共用动作包。[`GameAction.cpp`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/GameAction.cpp#L137-L251) 可装配日志、物品、船只、付款、罚款、债务、延迟事件、音乐、标记、任务失败、消息和条件赋值；[执行时](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/GameAction.cpp#L414-L526) 先移除再添加资产，随后排期事件、处理任务状态、反馈和条件。
- 命名世界事件会自动留下“发生过”条件，[`GameEvent.cpp`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/GameEvent.cpp#L84-L129) 还能改变访问记录和世界定义；[应用时](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/GameEvent.cpp#L195-L254) 将玩家条件与世界数据变化分开，后者返回调用方批处理。这里可借鉴的是“选择留下世界事实”，不是其具体字段或语法。
- [`NPC.cpp`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/NPC.cpp#L81-L252) 把保护、击毁、登舰、救援、扫描、俘获、激怒、甩脱、护送做成目标组合；[生成和退场条件](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/NPC.cpp#L401-L417) 采用单向锁存，条件之后回落不会让 NPC “反生成”或“反退场”。[逐目标事件账本](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/NPC.cpp#L445-L617) 区分玩家发起的动作，必要目标未完成前被毁会永久失败；[动作触发](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/NPC.cpp#L729-L801) 防止重复 DESTROY 二次结算，并明确单目标触发、全目标触发及俘获/击毁的排斥关系。
- [`ConditionSet.cpp`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/ConditionSet.cpp#L35-L123) 支持算术、比较、`and` / `or`、`min` / `max`、括号和明确优先级；[`test_conditionSet.cpp`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/tests/unit/src/test_conditionSet.cpp#L135-L356) 覆盖变量、优先级、序列化往返和非法表达式。不能照搬其全部语义：[`Evaluate`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/ConditionSet.cpp#L385-L439) 的 `and` / `or` 返回相关非零值，除零返回 `int64 max`、模零返回左值；本项目应使用受限谓词 AST 并让非法运算 fail-closed。

#### 真实内容说明了什么

- [`Pact Recon 0`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/data/human/free%20worlds%200%20prologue.txt#L14-L83) 允许玩家以不同态度问话、质疑自己没有战舰、询问组织背景或直接拒绝；愿意继续的分支最终自然汇入同一侦察目标。大方向稳定，但过程、玩家自我表达和信息揭示顺序不同。
- [`FW Recon 3B`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/data/human/free%20worlds%200%20prologue.txt#L478-L585) 先让一次冒险选择写入“被发现”条件，随后生成追踪者；任务完成对话再根据“被发现”“明显遭跟踪”等旧事实自动选择不同开场。旧选择改变后文措辞、追兵和可继续工作的路径，而不是立刻把“未知风险”标签泄露给玩家。
- 集成测试覆盖了最容易让玩家不信任选项的边界：[`tests_conditional_choice.txt`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/tests/integration/config/plugins/integration-tests/data/tests/tests_conditional_choice.txt#L68-L228) 验证隐藏选项、隐藏路径跳转及键盘不能选中不可见项；[`tests_save_load.txt`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/tests/integration/config/plugins/integration-tests/data/tests/tests_save_load.txt#L71-L142) 验证对话未提交前重载会回滚临时动作；[`tests_to_accept.txt`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/tests/integration/config/plugins/integration-tests/data/tests/tests_to_accept.txt#L84-L115) 验证出现条件满足但接受条件不满足时不会误接任务。

#### 本项目的原创落地规格

| 优先级 | 当前差距 | 原创改造位置 | 自动验收门槛 |
| --- | --- | --- | --- |
| P0-N1 真正节点图 | `story_system.gd` 固定主线 4 节、回响 3 节，并要求每个节点恰好 3 个选择；`next` 字段存在但推进仍依赖阶段索引 | `story_arcs_v1.json` 升级为显式 `entry_node_id`、稳定 `node_id` / `choice_id`、每个选择自己的 `target_node_id` / `action_bundle` / 可选终点；`story_system.gd` 按节点游标推进，不按固定数组下标推进 | 全库重复 ID、悬空目标、不可达关键节点、无玩家决策的自动环均为 0；节点选择数允许 1 到内容上限，布局测试覆盖最长文本 |
| P0-N2 显示与可用分离 | 当前仅给三个选项统一附加 `available`，不能表达“玩家根本不应知道这条路”和“看得见但条件不足” | 选择分别支持内部 `visible_if` 与 `enabled_if`；隐藏项不进入显示索引，可见但不可用项保留作者写的情境理由；所有条件只影响叙事编排，界面不显示“未知风险/可预见后果”等全知标签 | 鼠标、键盘、数字键和伪造索引都不能选择隐藏或未激活项；全部隐藏时必须进入作者指定 `fallback_node_id`，禁止默默选第 0 项 |
| P0-N3 任务生命周期 | 当前主线故事主要是“生成一页 -> 选一项 -> 阶段加一”，遭遇另有一个 `active` 布尔值 | 建立原创 `QuestInstance` 状态机，持久状态为 `eligible / offered / deferred / active / completed / failed / aborted / expired / declined`；接受是 `offered -> active` 转移，不把所有分支串成一条假流程。分别声明出现、接受、完成、失败条件、期限、优先级、是否阻塞以及胜败动作 | 所有非法状态转移率为 0；能显示但不能接受、延期后重现、期限失败、主动放弃、完成后不复现都有定向测试；主线锚点不被次要事件长期饿死 |
| P0-N4 动作包事务 | `NarrativeConsequenceSystem` 已有旗标、关系、承诺、债务、延迟回响和战斗后果，但选择重放仍缺通用 `action_id` / `outcome_id` 幂等边界 | 每个动作包先在快照上预检余额、物品、状态转移、目标和引用，再一次提交；持久化 `executed_action_ids` / `resolved_outcome_ids`，日志、关系、世界、排期事件和音频 cue 从同一结果对象派生 | 同一 outcome 重放 100 次只结算一次；任一预检失败时完整 state hash 不变；中途保存/重载只能得到提交前或提交后状态，不得出现半写入 |
| P0-N5 遭遇目标账本 | `EncounterSystem` 已能拒绝覆盖活动遭遇、到期和 consume，但仅有单个活动布尔值和单敌人摘要 | 增加 `foreshadowed / active / resolved / failed / expired` 阶段、目标列表、单向 spawn/despawn 锁存、逐目标动作位集和来源选择；战斗胜、败、逃只写各自允许的世界事实 | 条件由真变假后已生成角色不消失；退场后不复活；重复毁灭事件不重播奖励/文本；未完成必要目标时目标永久损失会进入失败而非伪完成 |
| P0-N6 完整持久化 | `game_state.gd` 保存阶段进度和后果账本，但没有节点游标、通用动作幂等表、NPC 锁存与模板实例化随机结果 | 保存当前节点、可恢复的任务实例、执行过的动作/结果 ID、排期事件、NPC 阶段与目标记录，以及模板实例化后已经掷出的结果；加载时只规范化，不重新抽签 | 任意节点保存后恢复，当前正文、显示/可用选项、期限、排期事件、NPC 锁存、逐目标动作和 state hash 完全一致 |

属性测试至少生成 10,000 个随机小型故事图，再叠加真实内容定义做静态校验。测试失败必须输出种子、最小复现图、节点路径和状态 diff，不能只报“定义无效”。

#### 反例与许可证边界

1. [`MissionAction::CanBeDone`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/MissionAction.cpp#L216-L294) 会预检余额、物品、船只和位置，但 [`GameAction::Do`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/source/GameAction.cpp#L414-L526) 本身不是通用事务系统。上游在对话流程另有快照保护；本项目不能把“先检查后连续改字段”误称为原子提交。
2. 仓库没有以 Conversation、Mission、GameAction、GameEvent 或 NPC 命名的直接 C++ 单元测试；关键边界主要由集成测试保护。应借鉴其真实流程测试，同时为本项目的数据模型补纯逻辑单测和属性测试，不能继承这笔测试欠账。
3. [`copyright`](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/copyright#L6-L25) 规定 `Files: *` 默认 GPL-3+，所以源码、测试文件和上述任务文本都不能直接复制进原创实现。图片默认 CC-BY-SA-4.0，但 `images/land/*`、`images/scene/*` 及大量更具体路径会覆盖默认条款。
4. 音频目录也不能整包取用。[`sounds/*` 默认条款](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/copyright#L1313-L1336) 是 public domain，但紧随其后的具体文件已分别覆盖为 CC-BY-SA、public domain 等；[部分 Unsplash 图片](https://github.com/endless-sky/endless-sky/blob/dfd1d3ae8908e7b3261626333982827c18183cae/copyright#L4055-L4069) 还有不得出售未修改副本等限制。
5. 任一候选素材必须按固定提交和精确相对路径解析最具体的 `Files:` stanza，记录作者、原始来源、派生链、许可证、署名文本及 ShareAlike 义务。无法证明完整权利链就不下载、不转换、不入包；“仓库开源”“目录默认 public domain”都不是验收证据。

### Mindustry

[官方仓库](https://github.com/Anuken/Mindustry) 以 GPLv3 发布，并将实体、内容类型、声音、音乐、贴图和网络调用等从定义生成到运行时。

可转化原则：高频内容应有稳定定义和生成/验证工具；构建必须能够检查每个定义是否有运行时资源、反馈和测试覆盖。

## 当前基线与下一落地顺序

目前不是“除美术外已经完美”。代码里已经出现正确骨架，但离玩家能持续读下去、每次选择都有意义的产品闭环仍有明确差距：

- `combat_event_pipeline.gd` 已有有序阶段、结构化 step、校验与 `trace_hash`；尚需补跨存档重放、全部效果原语和 1,000 种子一致性门槛。
- `combat_system.gd` 已有十二种敌人签名、预判字段和第二阶段；尚需把强行动预警、阶段不可跳过、构筑反制和敌人级统计做成可证明的规则。
- `EncounterSystem` 已拒绝覆盖活动敌踪并限制战斗来源，`NarrativeConsequenceSystem` 已有战斗后果账本；尚需把单个 `active` 布尔值升级为可恢复的任务/遭遇状态机和事务结算。
- `story_arcs_v1.json` 虽有 `next`，`story_system.gd` 仍按数组 `stage + 1` 推进；当前路线主要是同一章节的文案变体和终局计分，不是真正的选择节点图。这是“点半天却不知道为何而点”的首要产品缺口。

下一轮按玩家体验而不是文件类型排序：

1. 先完成显式故事节点图、显示/可用分离、任务生命周期和图静态校验。玩家进入游戏后应立刻读懂“我是谁、正在处理什么、谁与我有关”，但未知后果继续留给玩家推断。
2. 再完成 action/outcome 幂等事务、节点游标、遭遇目标账本和完整存档恢复；确保选择、战斗和回响是同一条因果链，不会常亮、覆盖或重复领奖。
3. 复用秘境效果原语和现有事件管线建立原创招式/构筑入口；把十二种签名升级为可预警、可反制、不可跳阶段的敌人规则，不再扩写更多同质按钮。
4. 由同一语义事件统一驱动战术轨迹、命中停顿、跳字、状态、短叙述和音频重音；正式美术未补齐前使用可靠排版与符号，不用重复错图或伪插画填空。
5. 最后以进攻、稳健、节能、脱身、随机合法和不同构筑代理跑 10,000 局，并对随机故事图做属性测试；同时统计路线覆盖、死路、动作熵、支配动作、签名触发/反制、阶段到达、构筑差异、资源使用和结果分布。任何指标失败都要输出种子和最小复现，不以“没有崩溃”冒充有趣。

## 禁止事项

- 不复制其他项目的源码、专有规则文本、数值表、UI 构图或角色技能。
- 不从“开源游戏仓库”直接提取权利不明的音频、美术和品牌内容。
- 不把参考项目名称写进游戏内，也不以相似命名暗示官方关系。
- 不用一次自动测试通过或新增几行提示文案宣称达到产品级。
