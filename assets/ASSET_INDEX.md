# Asset Index

当前项目内已落盘的美术资源与生成脚本索引。

## 背景与界面

- `background.png`
  - 主菜单背景图
- `title.png`
  - 标题图草案
- `icon_fire.png`
  - 五行图标：火
- `icon_water.png`
  - 五行图标：水
- `icon_wood.png`
  - 五行图标：木
- `icon_metal.png`
  - 五行图标：金
- `icon_earth.png`
  - 五行图标：土

## 物品资源

目录：`items/`

预览总览：

- `previews/item_atlas_v4.png`
  - 当前物品资源总览图
  - 便于快速审查风格一致性与类别覆盖度

### Weapons

当前版本：`v4` 扩展版

- `items/weapons/weapon_sword_astral.png`
  - 星辉飞剑
- `items/weapons/weapon_sword_crimson.png`
  - 赤魄灵剑
- `items/weapons/weapon_spear_storm.png`
  - 惊霆长枪
- `items/weapons/weapon_bow_windchase.png`
  - 逐风弓
- `items/weapons/weapon_ringblade_frost.png`
  - 寒魄环刃
- `items/weapons/weapon_dagger_shadowfang.png`
  - 影牙短匕

### Artifacts

当前版本：`v4` 扩展版

- `items/artifacts/artifact_spirit_gourd.png`
  - 养灵葫芦
- `items/artifacts/artifact_jade_slip_ancient.png`
  - 古修玉简
- `items/artifacts/artifact_bronze_mirror.png`
  - 镇魂铜镜
- `items/artifacts/artifact_seal_tower.png`
  - 镇狱小塔
- `items/artifacts/artifact_sigil_disk.png`
  - 青冥阵盘
- `items/artifacts/artifact_orb_tideheart.png`
  - 潮心灵珠
- `items/artifacts/artifact_crimson_seal.png`
  - 赤霄印
- `items/artifacts/artifact_soul_banner.png`
  - 摄魂幡

### Consumables

当前版本：`v4` 扩展版

- `items/consumables/consumable_pill_bottle_emerald.png`
  - 翠灵丹瓶
- `items/consumables/consumable_talisman_blinkstep.png`
  - 瞬影符

### Materials

当前版本：`v4` 扩展版

- `items/materials/material_ling_stone.png`
  - 灵石
- `items/materials/material_moon_grass.png`
  - 月华草
- `items/materials/material_blackiron_ore.png`
  - 玄铁矿
- `items/materials/material_demon_core.png`
  - 妖丹

## 生成脚本

- `scripts/generate_item_assets.ps1`
  - 首批原型批量生成脚本
- `scripts/generate_item_assets.py`
  - 当前主用的高质量批量生成脚本
  - 当前输出风格：
    - 外环 + 灵气光晕 + 异形底板
    - 512x512 PNG
    - 更接近成熟游戏物品栏资源
    - 已具备批量扩充武器、法宝、材料、消耗品的能力
    - 当前已进入 `v4` 扩展阶段

## 物品设定数据

- `item_lore.json`
  - 当前首批物品的名字、类型、品阶、元素、背景设定、用途说明
  - 可直接作为后续事件、商人、掉落、传承系统的数据基础
  - 已开始进入本地 AI 事件上下文
- `item_catalog.json`
  - 当前物品类别清单
  - 可用于商人池、掉落池、图录分组与后续数据驱动事件
- 当前规模
  - 武器 6 件
  - 法宝 8 件
  - 消耗品 3 件
  - 材料 4 件
- 游戏内查看入口
  - 运行游戏后按 `I`
  - 可打开 `灵物图录`

## 角色立绘

目录：`characters/`

- `characters/taoist_antagonist.png`
  - 玄衡子，太上玄衡观掌律真人
  - 用作主界面左下角的首个 NPC 立绘占位
  - 原图脚部已裁切，避免 UI 中露脚出戏

## 下一轮建议

优先级从高到低：

1. 扩充武器分支
   - 飞剑
   - 重剑
   - 长枪
   - 短刃
   - 拂尘
   - 斧
   - 双环
   - 锁链钩
   - 匕首
2. 扩充法宝分支
   - 玉佩
   - 印玺
   - 幡旗
   - 宝珠
   - 棺灯
3. 扩充丹药与材料
   - 筑基丹
   - 回气丹
   - 卷轴
   - 炼器胚料
   - 妖丹
   - 魂砂
4. 后续可按品阶补色
   - 凡阶
   - 灵阶
   - 地阶
   - 天阶
   - 仙阶
5. 下一阶段提升方向
   - 增加材质细节、刻痕、宝石切面、符纹层
   - 做同一物品的多品阶变体
   - 补充事件系统、商人系统、传承系统对这些物品的实际引用
