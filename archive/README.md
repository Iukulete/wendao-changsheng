# 历史源资产档案（不是运行时）

旧卡片战斗、六纪元界面及本地 AI 事件生成已退休。这里保留可复用的创作，
**不表示这些内容已接入当前 3D 仙舟原型，也不恢复旧玩法或旧存档。**
档案位于 `godot/` 项目根之外，不属于 Godot 的 `res://`，不得打包到游戏。

## 保存了什么

`source_manifest.json` 是确定性、按 `original_path` 排序的保存清单：每项给出
原路径、档案路径、SHA-256、字节数和用途分类；JSON/JSONL 另有稳定 ID 指纹。
基线提交：`3d9903b71c45560e631db96d2f2dd79f52b891d1`。

| 分类 | 保存位置与使用边界 |
| --- | --- |
| 剧情和对白 | `source_assets/godot/data/`：六卷 144 章、89 段对白及索引、事件和剧情弧；未来逐段改编，不自动导入新居民或首岛 |
| 人物身份 | 同目录的 `characters/`：122 个正式人物、3 个群组、别名和设定；稳定 ID、原文、年龄与呈现限制不改写 |
| 2D 视觉参考 | `source_assets/godot/art/`：肖像、场景、概念、战斗图；候选稿和分层稿单独标为 staging；不是 3D 模型、骨骼或动画 |
| 声音候选 | `source_assets/godot/audio/`：35 个音频及原始来源、许可、署名记录；需重新适配新场景、混音、循环和触发 |
| 已退休机制数据 | 卡片、回合战斗、怪物队列、旧玉武库等 JSON 与旧总线配置：仅作资料，不是当前动作战斗规范 |
| 历史内容工具 | `tools/`：35 个原路径依赖的内容制作/校验脚本和旧测试，按原字节保留，**不可作为当前构建或验证入口** |
| AI 创作文稿 | `source_assets/ai_engine/`：3 份原始事件示例数据和 2 份说明；旧下载、推理、训练、评估入口已移除，历史说明中的操作步骤不再适用 |

另外，`extracted_narrative/ai_embedded_authored_text.json` 是**数据化摘录，不是原文件
搬迁**：从 4 个已移除 AI 脚本静态提取 579 个中文字符串，包含额外 38 个完整
创作样例及时代/家庭/NPC 常量。解码原文、原始源码片段、行列位置、源提交和
源 SHA-256 均有记录；没有导入或执行旧脚本。此摘录在清单的
`extracted_documents` 单独列出并校验，不能冒称与原 `.py` 文件整字节相同。

`source_assets/` 下镜像原仓库相对路径，例如
`godot/data/dialogue/qingheng_first_meeting_v1.json` 对应
`archive/source_assets/godot/data/dialogue/qingheng_first_meeting_v1.json`。
原文中的 `res://`、工具相对路径和历史发布状态均未重写，只是来源记录，
不是当前可加载路径或当前验收结论。历史工具映射为 `tools/x` → `archive/tools/x`。

458 个旧资源的 `.import` 是退休导入配置，未当作创作源文件重复归档；原路径和
哈希留在清单，完整版本可从基线 Git 提交取回。两套仍在用的字体连同各自
`.import` 配置、OFL 许可和 `font_manifest.json` 留在 `godot/art/fonts/`。
项目根 `LICENSE`（AGPL）保持不变。此操作不扫描、迁移或删除本地模型、缓存、凭据或存档。

## 权利与新呈现复用门槛

1. **先查权利。** 原美术清单只记录技术来源，不授予版权或许可。清单中 208 项
   `generated` 不是自动授权；未登记的候选/分层稿也必须审查来源。
   三项 `curated`：`jade_healer.jpg`、`protagonist_hooded_close.jpg`、
   `qingyun_sword_heroine.jpg` 明确标为 **权利未核实、仅供参考，不可直接发包**。
   音频沿用每项的实际许可与署名义务，不将 CC-BY/CC-BY-SA 误称为 CC0；
   原始 `LICENSE-AUDIO.txt`、`audio/licenses/`、音频清单、字体 OFL 和项目 AGPL 均保留。
2. **再查叙事。** 核对新地点、时代、人物事实、年龄、语境与后果。保留来源 ID，
   在新适配层记录映射；旧六纪元数值、战斗效果和结局不能直接成为新世界事实。
3. **另建 3D 呈现。** 2D 图只能作为经许可的身份/色彩/构图参考；可用的 3D 模型、
   材质、绑定、动作和场景适配需要另行制作及验收，不能把肖像归档说成建模完成。
4. **只提升审过的副本。** 将选中内容适配到新的活跃目录，记录来源路径、SHA-256、
   许可、稳定 ID 映射与验收证据。不要修改不可变的原档案或重新启用旧数据加载器。
5. **通过新功能测试后再发布。** 在新呈现中验证交互、可读性、性能、保存/读档及
   署名展示；未通过的内容继续留在项目外档案，不进入导出。

## 直接验证（不需要旧运行时）

```sh
python tools/verify_source_archive.py
python -m unittest discover -s tools -p 'test_verify_source_archive.py'
```

从仓库根运行。成功打印 `SOURCE_ARCHIVE_OK:`。检查包括每个实际文件的字节数/
SHA-256、完整目录清单、严格 JSON/JSONL 解析、ID 字段/注册表键/对白连线指纹、
人物与群组/别名关系、对白节点唯一性/可达性、章节 ID，以及原图和音频来源哈希、
音频许可文本存在性。完整文件哈希保护全部作者原文；ID 指纹提供额外诊断，
不是重新生成 ID。检查不会执行档案脚本，也不会重写清单。

恢复旧版本只用于隔离取证或人工比对：在另一个临时 worktree 检出上述基线，
不要覆盖当前仙舟分支、用户存档或把旧运行时混回发布目录。当前边界和后续计划见
[`docs/ARK_RETIRED_SYSTEMS.md`](../docs/ARK_RETIRED_SYSTEMS.md)。
