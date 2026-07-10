# 问道长生：Image2 美术资源补充计划

> 目标：用 AI 图像生成补齐开局体验需要的关键美术资源，但保持原创，不复刻任何已有小说、游戏、影视作品的角色造型、场景构图、服装细节或专有标识。

## 1. 当前已有资源

项目已经有基础资产：

- `assets/background.png`：主菜单背景图
- `assets/title.png`：标题图草案
- `assets/icon_fire.png` / `icon_water.png` / `icon_wood.png` / `icon_metal.png` / `icon_earth.png`：五行图标
- `assets/items/`：武器、法宝、消耗品、材料图标
- `assets/characters/`：已有角色立绘

本轮不推翻原风格，而是在开局内容上补：主菜单氛围、测灵台、黑白旧玉、外院/家族场景、早期 NPC 立绘。

## 2. 版权与风格边界

允许：

- 古典修仙、东方玄幻、卷轴 UI、灵气光晕、山门、测灵台、旧玉、残卷等通用题材。
- 自己的角色剪影、原创服饰、原创门派纹样、原创场景构图。
- 统一色彩：墨青、玉白、暗金、冷蓝、少量朱砂。

避免：

- 不生成任何已有小说角色或势力标志。
- 不使用“照着某本小说/某个角色”的提示词。
- 不复刻他人插画构图、服装、发饰、武器设计。
- 不把原小说专有名词写进图片提示词或文件名。

## 3. 第一批建议生成资源

### A. 主菜单背景

文件建议：`assets/background_opening.png`

用途：启动界面、主菜单、新生入口。

Image2 提示词：

```text
原创东方玄幻修仙游戏主菜单背景，远处云雾山门，近处一枚黑白旧玉悬浮在石案上，旧玉周围有细微灵气光环，背景有破旧测灵台轮廓，墨青和玉白为主色，暗金符纹点缀，沉静、神秘、命运感，2D digital painting, game background, no characters, no text, no logo, 16:9
```

负面提示：

```text
不要文字，不要水印，不要现代建筑，不要科幻机甲，不要已知小说角色，不要复制已有游戏 UI，不要过度艳丽
```

### B. 第一幕场景：测灵台前

文件建议：`assets/scenes/scene_spirit_trial_platform.png`

用途：第一幕开局弹窗、剧情页面。

Image2 提示词：

```text
原创东方玄幻外院测灵台场景，古石平台中央有暗淡的五行符阵，四周是朦胧少年修士剪影，主角位置留空或只显示背影，测灵台光芒刚刚熄灭，空气中残留微弱玉白灵光，压抑、安静、公开审视的氛围，2D illustration, cinematic composition, no text, no logo
```

### C. 关键道具：黑白旧玉

文件建议：`assets/items/artifacts/artifact_jade_blackwhite_old.png`

用途：物品图录、开局主线、轮回系统 UI。

Image2 提示词：

```text
原创修仙法宝图标，一枚半黑半白的古旧玉佩，边缘有细小裂纹，中心有若隐若现的阴阳云纹，但不是标准太极图，外环有淡金符纹和冷白灵气，512x512 PNG icon, transparent background, high detail, game item icon, no text
```

### D. 早期 NPC：清冷内院师姐

文件建议：`assets/characters/senior_sister_cold_sword.png`

用途：开局人情线，不绑定现有小说人物。

Image2 提示词：

```text
原创东方玄幻女性剑修角色立绘，清冷内院师姐，白青色简洁修士长袍，发饰朴素，手持未出鞘长剑，神情克制而锋利，站姿端正，背景透明或简洁水墨光晕，full body character art, 2D game portrait, no text, no logo, original character
```

### E. 早期 NPC：外院竞争者

文件建议：`assets/characters/outer_court_rival.png`

用途：演武场失手、名额风波、前期挑衅线。

Image2 提示词：

```text
原创东方玄幻男性少年修士角色立绘，外院竞争者，深蓝灰短打修士服，腰间木剑，表情骄傲带一点不服，年轻、锐利、尚未成熟，透明背景，2D game portrait, original character, no text, no logo
```

### F. 早期 NPC：旧账房/旧仆

文件建议：`assets/characters/old_account_keeper.png`

用途：家世旧账、旧契、家族压力线。

Image2 提示词：

```text
原创东方玄幻老账房角色立绘，年老但眼神清醒，灰褐色长衫，手持旧账册和算盘，身后有淡淡家族旧宅轮廓，温和、谨慎、藏着秘密，2D game portrait, transparent background, no text, no logo
```

## 4. UI 资源建议

### 主菜单按钮底纹

文件建议：`assets/ui/button_jade_dark.png`

```text
东方玄幻游戏 UI 按钮底纹，深墨青玉质长条按钮，边缘暗金细线，轻微符纹，适合文字菜单，无文字，transparent background, game UI asset
```

### 存档槽底纹

文件建议：`assets/ui/save_slot_scroll_panel.png`

```text
东方玄幻游戏存档槽面板，旧卷轴和玉简结合的横向卡片，暗色半透明底，边缘有细金线，适合显示存档文字，无文字，无图标，game UI panel, transparent background
```

### 第一幕章节牌

文件建议：`assets/ui/chapter_plate_opening.png`

```text
东方玄幻章节标题牌，古玉和卷轴结合，墨青色底，暗金边框，留出中间文字区域，无文字，game UI title plate, transparent background
```

## 5. 接入顺序

1. 先生成并确认 `background_opening.png`，替换或并存当前 `background.png`。
2. 生成 `artifact_jade_blackwhite_old.png`，加入物品图录与开局剧情。
3. 生成 `scene_spirit_trial_platform.png`，用于第一幕剧情页。
4. 生成 3 个早期 NPC 立绘，绑定本地事件反应。
5. 最后补 UI 面板，统一主菜单和存档页视觉。

## 6. 验收标准

- 玩家一进游戏，视觉上能马上知道这是“修仙 + 轮回 + 旧玉”的游戏。
- 开局场景和事件文本互相支撑，不是随便放一张背景。
- 图片不含文字，避免不同分辨率和字体问题。
- 所有角色与道具均为原创提示生成，不指向任何已有 IP。
