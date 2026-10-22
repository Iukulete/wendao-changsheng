# 问道长生 Godot 工程

这是《问道长生》的唯一游戏工程，目标版本为 Godot 4.7.1 stable 标准版与 GDScript。

## 状态域

- `GameStateSchema`：统一 v2 运行状态和 v1 JSON 迁移。
- `SaveService`：校验、原子替换、备份恢复、坏档隔离和便携存档目录。
- `LegacySaveImporter`：只读导入 Win32 `SAVE_V4/SAVE_V5` 六槽旧录。
- `WorldSimulation`：势力、NPC、关系、世界事件和纪元连续性。
- `CultivationSystem` / `ReincarnationSystem`：21 境界、寿元、死亡和多世继承。
- `ItemSystem` / `CombatSystem`：背包、锻造、装备与普通战斗。
- `StorySystem` / `AchievementSystem`：剧情图、跨世续章、成就和永久玉兵。
- `DungeonSystem`：独立的可选秘境能力构筑，不替代普通战斗。
- `LocalAIBridge`：本地进程调用、隐私边界、输出校验和规则回退。

## 资源

- `art/`：运行时场景与人物资源，完整性由 `art_manifest.json` 管理。
- `data/`：事件、剧情、秘境能力和玉兵定义。
- `scenes/main.tscn`：唯一主场景。
- `tests/`：无窗口确定性回归与真实 GL 截图驱动。

项目根目录的 [README](../README.md) 包含启动、构建、旧档导入和完整验证命令。
