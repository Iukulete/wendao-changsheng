# 音频资源迁移清单 v0.19

> 状态：已完成。新版 v2 清单已接入运行时；本文件保留审计过程和删除旧生成资产的决策记录。2026-07-23 增补 Karmic Confluence、Views From Atop the Jade King's Throne 与独立世界环境床。

## 结论先行

旧音频技术框架已被保留并重接，但程序合成素材已移除。当前运行时固定为 35 条精选 Ogg（6 首音乐、2 条环境床、27 条音效），每条均有官方来源归档锁、逐资产哈希、客观测量和许可证记录；战斗核心语义类别禁止复用同一声源。探索、压力、决战播放列表分别至少保留 3、3、2 首长曲，世界与秘境使用不同环境床。

更重要的是，当前 `AudioDirector` 会把所有音乐和声景 OGG 强制打开循环，并在换曲时把新曲从旧曲的相同播放秒数开始。这只适用于同速度、同结构的同步层，不能用于完整的叙事曲目：非循环曲会被硬切，跨曲相位也没有音乐意义。

建议采用一套小而有辨识度的素材库：

1. 0 A.D. 官方音频作为主要长篇配乐和部分环境层（CC BY-SA 3.0）。
2. Kenney 的 Interface/RPG/Impact 三套 CC0 音效作为 UI、纸张、脚步、金属和战斗瞬态。
3. OpenGameArt 上有明确原作者、许可证、下载量或实际游戏采用记录的少量东方风格曲目和声景。
4. 所有 MP3 只作为来源格式，运行时统一转为 Ogg；每条资产记录来源哈希、处理哈希、变更说明和许可证，不把来源不明的文件混成“自制”。

## 已核实的候选

### 长篇音乐

| 资产 | 来源与质量信号 | 许可证 | 采样审计 | 建议场景 |
| --- | --- | --- | --- | --- |
| `Eastern_Dreams.ogg` | [0 A.D. 官方仓库](https://github.com/0ad/0ad/tree/master/binaries/data/mods/public/audio/music)，仓库当前提交 `61a3b9507d974084e6badb88a0826bd89a6d5b8b`；0 A.D. 仓库约 2.8k stars/536 forks | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/)；随仓库的 [audio/LICENSE.txt](https://raw.githubusercontent.com/0ad/0ad/master/binaries/data/mods/public/audio/LICENSE.txt) 要求署名 Wildfire Games、附许可证链接，修改版继续 CC BY-SA | 4.33 MiB，229.0 s，44.1 kHz，约 -13.3 LUFS-I，true peak +0.9 dBTP（需统一降峰） | 主界面、游历、初入宗门；长曲，不循环，尾部淡出 |
| `Karmic_Confluence.ogg` | 同上；[官方 OST 页面](https://play0ad.bandcamp.com/album/0-a-d-original-game-soundtrack)可核对编曲与制作团队 | CC BY-SA 3.0（运行文件以 Git 仓库许可证为准，Bandcamp 只作质量/作者佐证） | 1.86 MiB，106.0 s，约 -15.4 LUFS-I，+0.6 dBTP | 轮回、旧因果、神识/双修等内省段落 |
| `Tale_of_Warriors.ogg` | 0 A.D. OST；[曲目页](https://play0ad.bandcamp.com/track/tale-of-warriors)列出 Omri Lahav、Elizabeth Zharoff、Inbal-Rotem Sagiv 等制作/演唱信息 | CC BY-SA 3.0（同上） | 3.01 MiB，164.0 s，约 -16.2 LUFS-I，-0.1 dBTP | 普通战斗、关键敌踪、首领揭示；不循环 |
| `Calm_Before_the_Storm.ogg` | 0 A.D. 官方音频目录 | CC BY-SA 3.0 | 2.54 MiB，142.7 s，约 -13.2 LUFS-I，+0.4 dBTP | 选择后的危险逼近、压力上升 |
| `Dried_Tears.ogg` | 0 A.D. 官方音频目录 | CC BY-SA 3.0 | 1.55 MiB，83.6 s，约 -12.7 LUFS-I，-0.3 dBTP | 战败、关系破裂、创伤余波 |
| `Sunrise.ogg` | 0 A.D. OST；[曲目页](https://play0ad.bandcamp.com/track/sunrise)明确标为和平曲目 | CC BY-SA 3.0 | 2.55 MiB，141.5 s，约 -13.5 LUFS-I，-0.1 dBTP | 新章、清晨、脱离控制后的自主选择 |
| `Views From Atop the Jade King's Throne.ogg` | [OpenGameArt 页面](https://opengameart.org/content/views-from-atop-the-jade-kings-throne)，10 favorites；页面同时提供 Ogg/MP3 | CC BY 3.0；作者 HitCtrl，页面要求署名 `HitCtrl` | 3.26 MiB，237.5 s，约 -17.5 LUFS-I，-3.8 dBTP | 宗门/仙朝远景、长阅读段落；不循环 |
| `Asian String Suite.mp3` | [OpenGameArt 页面](https://opengameart.org/content/asian-string-suite)，7 favorites/194 downloads；评论记录用于 Steam 游戏 Tatsu 及其预告片 | CC BY 3.0；作者 BossLevelVGM，页面要求以其 screen name 署名 | 1.18 MiB，77.2 s，约 -17.5 LUFS-I，-1.2 dBTP；转 Ogg 后运行 | 关系、对话、灯河灵市；可做短播放列表曲，不强制循环 |
| `Liyan.mp3` | [OpenGameArt 页面](https://opengameart.org/content/liyan)，10 favorites/284 downloads；评论记录用于 Steam 游戏 Tatsu 和 Android 游戏 Kuno Combo | CC BY 3.0；作者 elerya | 1.10 MiB，59.2 s，约 -19.7 LUFS-I，-0.8 dBTP；转 Ogg 后运行 | 安静阅读、同行关系、夜间营地 |
| `Taiko drums (seamless loop)` | [OpenGameArt 页面](https://opengameart.org/content/taiko-drums-seamless-loop)，9 favorites/550 downloads；评论记录用于 Steam 游戏 Tatsu；页面注明用于开源格斗游戏 Jonga | CC BY 3.0；作者 jobro（页面注明由 congusbongus 提交） | 10.6 MiB，页面声明无缝循环；体积大，需试听后再决定是否纳入 | 仅用于高强度战斗/首领，不作为常驻背景 |
| `Asianoriental1.ogg` | [OpenGameArt 页面](https://opengameart.org/content/asianoriental1)，CC0，198 downloads；评论记录用于 Steam 游戏 Tatsu | CC0；作者 Tozan，署名可选 | 1.84 MiB，103.4 s，约 -20.8 LUFS-I，-8.8 dBTP | 低动态东方配器备用曲；需与主旋律 AB 试听 |
| `Kingdom of a Million Elephants under a White Parasol.ogg` | [OpenGameArt 页面](https://opengameart.org/content/kingdom-of-a-million-elephants-under-a-white-parasol)，11 favorites/223 downloads，CC0 | CC0；作者 Spring Spring，署名可选 | 2.15 MiB，92.6 s，约 -10.8 LUFS-I，true peak +1.1 dBTP；必须降峰后再评估 | 轻松市集/过场备选，不能未经试听直接进主线 |

0 A.D. OST 的 Bandcamp 页显示其是 2018 年完整游戏原声，并列出 Omri Lahav、Jeff Willet、Mike Skalandunas、Shlomi Nogay 等制作人员；法律依据仍以仓库中的 `binaries/data/mods/public/audio/LICENSE.txt` 为准，不能把 Bandcamp 的“some rights reserved”误当成运行时授权。

### 环境声

| 资产 | 许可证与质量信号 | 采样审计 | 建议场景 |
| --- | --- | --- | --- |
| `dungeon_ambient_1.ogg` | [OpenGameArt 页面](https://opengameart.org/content/loopable-dungeon-ambience)，CC0，69 favorites/7,828 downloads；评论有多个实际游戏采用记录 | 1.55 MiB，94.3 s，48 kHz，约 -27.7 LUFS-I，-3.1 dBFS；页面明确标注 loopable | 秘境底床，最优先候选 |
| 0 A.D. `day_temperate_gen_01.ogg` | 官方音频目录，CC BY-SA 3.0；适合作为低密度底床，不是旋律 | 1.29 MiB，100.0 s，48 kHz，约 -54.4 LUFS-I，-39.6 dBFS；需按层级增益使用 | 世界底床/远景，不直接当主环境音 |
| 0 A.D. `rain_12.ogg` | 官方音频目录，CC BY-SA 3.0 | 1.85 MiB，119.7 s，44.1 kHz，约 -21.6 LUFS-I，-7.3 dBFS | 雨天事件的 weather layer |
| 0 A.D. `river_slow_21.ogg` | 官方音频目录，CC BY-SA 3.0 | 0.37 MiB，23.7 s，约 -33.4 LUFS-I，-11.3 dBFS | 镜湖/灯河细节层 |
| 0 A.D. `windleaves_11.ogg` | 官方音频目录，CC BY-SA 3.0 | 0.08 MiB，4.7 s，约 -53.0 LUFS-I，-34.8 dBFS | 极低频率树叶点声；不要持续叠放 |

### UI、纸张和战斗音效

以下三套均来自 Kenney 官方页面，页面明确写明 CC0，并可直接下载压缩包；包内 `License.txt` 允许个人和商业项目使用，署名 Kenney/kenney.nl 非强制但建议保留。

| 套件 | 官方页 | 包体 | 适用内容 |
| --- | --- | ---: | --- |
| Interface Sounds | [kenney.nl/assets/interface-sounds](https://kenney.nl/assets/interface-sounds) | 834,536 bytes；页面标注 100 assets | `confirmation_*`、`back_*`、`open_*`、`close_*`、`pluck_*`、`scroll_*`、`question_*`；只挑 8 至 12 条，避免每个点击都发声 |
| RPG Audio | [kenney.nl/assets/rpg-audio](https://kenney.nl/assets/rpg-audio) | 964,837 bytes；页面标注 50 assets | `bookOpen`/`bookFlip*`/`bookClose`（章节阅读）、`handleCoins*`（资源反馈）、`doorOpen_*`/`doorClose_*`（进入/离开）、`drawKnife*`/`knifeSlice*`（战斗）、`footstep*`（移动） |
| Impact Sounds | [kenney.nl/assets/impact-sounds](https://kenney.nl/assets/impact-sounds) | 800,850 bytes；页面标注 130 assets | `impactPunch_*`、`impactMetal_*`、`impactWood_*`、`impactBell_*`；按材质映射命中、护体、破相、钟鸣，不把一个撞击声复制到六纪元 |

`Music Jingles` 页面虽为 CC0（1,239,525 bytes、85 assets），主体是 8-bit/合成器短 Jingle，不建议作为修仙主旋律；只有在试听确认某个短终局 stinger 不破坏气质时才保留。

### 候选源哈希（临时审计目录）

临时下载目录为 `D:\temp\wendao-audio-audit`，不属于仓库。以下哈希用于锁定来源版本，集成时须重新计算并写入 manifest：

```text
0ad/Eastern_Dreams.ogg       A09091FFCB3B9BC832D29D95C304034779AA8D4F8F5AC908BCFED1C4574D53B6
0ad/Karmic_Confluence.ogg    8D798980D6B1CB14C665F1AC73653ED80145AF5C2ADE328A32B049A40C4BB70A
0ad/Tale_of_Warriors.ogg     86D4F23A5001A254D48A163024AB711F4195D53DF3BE0E5050F3E974CC208C2B
0ad/Calm_Before_the_Storm.ogg A0887D85C6CC086AB5B46FC954CB24D10400F1DBCED5E66FB630EF4253A5BC41
0ad/Dried_Tears.ogg           EB582AF1937562437A94BBAC87EF50FE08A64BD8E3380D8025C578700E8889CB
0ad/Sunrise.ogg                5487816DCDE1B07CF019C43571FA26F5F264F4139185035BFD0E5AC9E6641B85
dungeon_ambient_1.ogg         DF491823E4877371C34DBDA4E9321CD83A4A14FA7573CEE0EBCA1AE423B70E6E
kenney_interface.zip          F2193D072726D6758A5F7871B2DCC54DCCE0D5C35C6F0A62F92549B327C81232
kenney_rpg.zip                6DBEAF8544DA958D8F2ADCB4A4A4B76C1ADE34A05F8AB9EDCCD327DA7375F38B
kenney_impact.zip             029D734AF1582474EDF3A694D1B0CEBC97C1C152F2F39FA34D4C2BAFC5DE77F8
```

## 许可证规则

- 允许进入运行时的许可证白名单：`CC0-1.0`、`CC-BY-3.0`、`CC-BY-4.0`、`CC-BY-SA-3.0`，以及项目自己确实拥有的 `LicenseRef-Project-Original`。
- 明确排除：`NC`、`ND`、来源不明、只允许个人使用、只允许在线播放、要求单独购买运行时再分发权、或无法确认原始层权利的素材。
- CC BY 资产必须在发布包中保留作者、来源页、许可证链接，并注明“converted/resampled/normalized”之类的修改。CC BY-SA 资产的修改版继续以 CC BY-SA 3.0 分发，不能被项目 AGPL 声明覆盖或重新标成项目原创。
- CC0 不强制署名，但仍在统一鸣谢中写出作者和来源，方便追溯。
- OpenGameArt 页面上的评论不能替代许可证。只采信页面显式许可证和文件本身的来源；`JC Sounds - Nature Ambient Pack Vol 1` 暂不采用，因为作者在评论中确认部分层来自购买的第三方库，页面虽标 CC BY 4.0，但再授权链没有足够可审计的库清单。

## 需要改的代码和数据契约

### `AudioDirector`

1. 将 `_resolve_audio_path()` 改成 manifest 查表，禁止依赖“纪元目录 + 固定文件名”的隐式回退。
2. 资产字段增加 `loop`、`loop_start_seconds`、`loop_end_seconds`、`sync_group`、`playlist_id`、`loudness_target_lufs`。只有 `loop=true` 的文件才设置 Godot loop。
3. 非循环音乐播放结束前 2 至 4 秒淡出并从同一 playlist 选择下一曲；上下文改变时从新曲的合法 cue point 开始，不复制旧曲的播放相位。只有同一 `sync_group` 的分层素材才允许相位对齐。
4. 保留当前双播放器交叉淡化和音频池，但增加 `music.finished` 生命周期、scope 清理和无音频设备降级测试。
5. 事件 ID 从通用 `card_cast/impact/guard` 扩展为叙事语义，例如 `narrative.page_turn`、`narrative.reveal`、`chapter.open`、`relationship.shift`、`cultivation.breakthrough`、`combat.hit.flesh`、`combat.guard.absorb`；页面不得按按钮文字猜测声音。
6. 音量目标以总线和场景为准：音乐约 -18 至 -16 LUFS-I，环境底床 -30 至 -24 LUFS-I，最终 true peak 不高于 -1 dBTP。源文件先修正，不用 Master 限幅器长期削峰。

### manifest / 验证器

`audio_manifest_v2.json` 是唯一运行时清单，每条资产至少保留：

```json
{
  "asset_id": "story_music_jade_throne",
  "runtime_path": "res://audio/music/story_music_jade_throne.ogg",
  "source_url": "https://opengameart.org/content/views-from-atop-the-jade-kings-throne",
  "source_file_sha256": "...",
  "processed_sha256": "...",
  "creator": "HitCtrl",
  "license_spdx": "CC-BY-3.0",
  "license_url": "https://creativecommons.org/licenses/by/3.0/",
  "attribution_text": "Views From Atop the Jade King's Throne by HitCtrl, CC BY 3.0.",
  "modifications": "converted Ogg, normalized to -18 LUFS-I, true peak -1 dBTP",
  "commercial_use": true,
  "redistribution_in_game": true,
  "loop": false,
  "playlist_ids": ["chapter_jade", "relationship_reflection"],
  "release_state": "final"
}
```

验证器应检查许可证白名单、来源 URL、两个哈希、实际音频格式、响度/峰值、路径闭包和 license 文本；不再要求所有曲目 64 秒、120 BPM、每个纪元 4 条独占声景，也不再要求每条资产的 `LicenseRef-Project-Original`。旧生成器和旧清单已删除，避免未来误把程序合成素材带回产品树。

### 资源目录与体积

- 已删除旧 `godot/audio/generated/` 中未被新 manifest 引用的程序合成文件和 `.import`，并删除 v1 清单与只服务于它的生成脚本；导出配置和验证器继续拒绝旧路径。
- 新目录分为 `godot/audio/music/`、`godot/audio/ambience/`、`godot/audio/sfx/`，运行时不保留 MP3、压缩包或供应商原始目录。
- 预计首批 6 至 10 条音乐、2 至 4 条环境层、25 至 40 条精选音效即可覆盖完整纵向切片，目标运行时音频体积低于当前 41 MiB；不要为了满足旧“六纪元全独占”契约而复制文件。
- `godot/audio/licenses/` 保存 0 A.D.、Kenney、OpenGameArt 的逐项许可证文本；发布包继续复制 manifest 和许可证，仓库根 AGPL 不替代第三方声明。

## 集成顺序与验收

1. 先在临时目录对候选做 AB 试听和响度处理，保留源哈希；不把未筛选素材直接放进 `res://audio/`。
2. 先接入一条古典纵向切片：标题/章节、阅读、选择回响、战斗、秘境、失败/轮回。确认音乐会自然结束或切歌，环境两层不会重复轰鸣。
3. 更新 `AudioDirector`、manifest 验证器和 `audio_system_test.gd`，测试非循环曲结束、循环点、播放列表确定性、scope 清理、静音/夜间模式和 Dummy 音频设备。
4. 运行离线 loudness/true-peak、Godot headless import、Windows 导出音频设备 smoke、10 分钟连续播放和 10,000 局回归。任何缺失授权、未登记文件、路径越界、MP3 运行时文件或削波都硬失败。
5. 通过后清理 `.tmp`、`.local` 和导出缓存再提交；不修改美术 `.import` 用户改动，不把临时审计目录带入提交。

## 暂不采用的来源

- `JC Sounds - Nature Ambient Pack Vol 1`：页面显示 CC BY 4.0，但作者确认混入购买的第三方库，公开页面没有逐库授权清单。除非补齐原始库授权证据，否则不进产品。
- 任何 Pixabay/YouTube “royalty free”链接：通常是平台条款或自定义许可，不属于本项目优先的可审计开放许可证白名单。
- 0 A.D. Bandcamp 购买页本身：用来确认制作质量、曲目和作者，不作为再分发授权来源；运行时授权只取官方仓库的 CC BY-SA 3.0 文件及其许可证。
- 当前程序生成的 64 秒配乐：可以保留在历史提交或开发工具中，但不再标作听感合格的产品终稿。
