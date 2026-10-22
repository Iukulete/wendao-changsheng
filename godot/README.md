# 归舟 Godot 3D 工程

固定 Godot 4.7.1 Stable 标准 GDScript。

- `scenes/main.tscn` / `scripts/main.gd`：仅面向仙舟的菜单、续接与入口。
- `scenes/ark_greybox.tscn`：连续3D原型。
- `scripts/ark_greybox.gd`：当前玩法编排。
- `ark_fixture_placement.gd`、`ark_greybox_save.gd`、`ark_landmass_builder.gd`、
  `ark_world_chart.gd`：放置、独立存档、岛岸几何与地图。
- `shaders/ark_ocean.gdshader`：临时海面。
- `art/fonts`：复用中文字体及OFL许可。
- `tests/ark_*`：新原型的逻辑、持久化、菜单与真实渲染验证。

不再含旧卡片战斗或六纪元运行时。旧源资产在工程外 `archive/source_assets`，
不会被Godot打包；源资产库不是新原型的已接入内容。详见根目录README。
