# 可商用开放美术候选审计

审计日期：2026-07-22
适用仓库：`wendao-changsheng` / Godot renovation branch
审计范围：角色身份锚点、剧情分镜、章节过场、UI 图标、战斗/灵力特效、材质输入。

## 结论先行

- **没有发现可以直接替换男主、江照雪、司命执笔或其他核心角色身份锚点的现成开放角色立绘。** 现有产品方向要求电影感写实、成人身份稳定、跨章节脸型和服饰一致；公开角色包普遍是像素画、动漫立绘、非商业授权或来源不清。核心角色继续走定制/人工美术流程。
- **可以进入下一轮运行时筛选的候选**：Game Icons（UI/状态图标）、Kenney Particle Pack（粒子叠加）、OpenGameArt 70 Animated 2D Game Effects（战斗冲击帧）、Met Open Access 与 Wikimedia Commons 公版中国山水（章节记忆卡/卷轴过场）、Poly Haven CC0 材质（极低不透明度材质叠加）。这些候选均不在本次审计中接入运行时。
- **许可证合格不等于风格合格。** Kenney RPG UI 和 OpenGameArt 中国寺庙像素瓦片许可干净，但与当前“电影感写实中国修仙”不匹配，列为不入库；itch.io 的仙侠背景/角色页明确写有非商业限制，也不入库。
- 不改动现有 `godot/art` 资源，也不改动用户已有的 17 个 `.import` 文件。`.tmp/art-candidates` 仅为本地审计缓存，发布前应清理。

## 当前缺口与适配边界

来自 [`godot/data/character_art_v1.json`](../godot/data/character_art_v1.json) 与 [`docs/ART_PRODUCTION_BRIEF_V1.md`](ART_PRODUCTION_BRIEF_V1.md)：

| 缺口 | 目标 | 本次开放素材结论 |
| --- | --- | --- |
| 男主 `protagonist` | `protagonist_canonical_v1.png`，写实身份锚点 | 无可直接采用候选；不能用通用男性立绘冒充 |
| 女主 `jiang_zhaoxue` | `jiang_zhaoxue_v1.png`，独立脸型和剑修服饰 | 无可直接采用候选；现成包多为动漫/非商业 |
| 主反派 `recurring_antagonist` | `siming_antagonist_v1.png`，制度型反派 | 无可直接采用候选 |
| 三张关键分镜 | `story_jade_first_warmth_v1.png` 等 | 公版山水可做过场底图，但不能代替含角色的身份分镜 |
| UI/状态图标 | 关系、承诺、债务、战斗状态 | Game Icons 可用；需统一颜色、描边和尺寸 |
| 战斗/灵力反馈 | 受击、闪光、剑痕、灵力脉冲 | Kenney/OGA 特效可用；需在 Godot 中做色调和混合模式适配 |
| 材质质感 | 石、木、旧纸等 | Poly Haven 可作为蒙版/材质输入，不应直接铺满界面 |

## 待二次筛选候选

### A1. Game Icons（优先：UI 与状态图标）

- **作者/来源**：Lorc、Delapouite 等贡献者；本次选取的图标来自 `lorc` 与 `delapouite` 子目录。
- **原始项目页**：<https://game-icons.net/about.html>；仓库：<https://github.com/game-icons/icons>
- **直接下载方式**：仓库中的 SVG 原文件，例如：
  - <https://raw.githubusercontent.com/game-icons/icons/master/delapouite/yin-yang.svg>
  - <https://raw.githubusercontent.com/game-icons/icons/master/lorc/tied-scroll.svg>
  - <https://raw.githubusercontent.com/game-icons/icons/master/lorc/meditation.svg>
  - <https://raw.githubusercontent.com/game-icons/icons/master/delapouite/pagoda.svg>
  - <https://raw.githubusercontent.com/game-icons/icons/master/lorc/crossed-swords.svg>
  - <https://raw.githubusercontent.com/game-icons/icons/master/delapouite/contract.svg>
- **许可证**：Creative Commons Attribution 3.0（CC BY 3.0）。项目页明确允许自由使用和在线编辑；无 ShareAlike 条款。
- **署名要求**：发布物中保留类似 `Icons made by Lorc/Delapouite. Available on https://game-icons.net` 的署名。仓库 `license.txt` 还列出了各贡献者来源，不能只写“Game Icons”。
- **适配位置**：关系七维、承诺/债务、秘境线索、战斗阶段、轮回结算和菜单中的图标；优先 SVG 或统一光栅化为 32/48/64 px。
- **质量判断**：矢量边缘清晰、单色轮廓在 104x154 身份卡和窄屏按钮中可读，且有 `yin-yang`、`meditation`、`pagoda`、`contract` 等与修仙叙事直接相关的语义。不能用于角色立绘或大面积背景；应改成当前冷灰、旧玉、朱砂三色体系，禁止把图标堆成装饰墙。
- **本地审计版本**：仓库浅克隆 commit `82d948812bfe3f269ef8f731dcdb07b08160edc4`。选取文件 SHA-256：
  - `delapouite/yin-yang.svg` `5DEEE4E46947B73BA9A290A9D86AE95370E2869F684AACC883E328DC6E577BC7`
  - `lorc/tied-scroll.svg` `8DEC10D48E8C0012A30D7146B4187E8ED9AA016029DE5F87CC254C129DC3C1D6`
  - `lorc/meditation.svg` `41AA384A5AE8505533E25E40F7E75B6B34A0B0C2062C11E70EC0F7094FC04959`
  - `delapouite/pagoda.svg` `C0CF15B1252323D74081BF28CD8903BB980B60D6801C7D9A109CBA420A06A29A`
  - `lorc/crossed-swords.svg` `D977DE17AA347C15A311E96EE4C7194837E47D119D2B5A06BC1DBBD2CD1A92F2`
  - `delapouite/contract.svg` `17178C93F868ADF3E5E68A2141B717C25D0F764D6260AD43A6B89DE65D2EF1D4`
- **门禁**：接入前将完整 `license.txt` 和贡献者署名写入项目许可证清单；不要把整个仓库无筛选复制进运行时。

### A2. Kenney Particle Pack 1.1（优先：灵力、剑痕、受击叠加）

- **作者**：Kenney Vleugels；滤镜模板贡献者在包内 `License.txt` 中列明。
- **原始页**：<https://kenney.nl/assets/particle-pack>
- **直接下载**：<https://kenney.nl/media/pages/assets/particle-pack/f8fe0f8cb8-1677578741/kenney_particle-pack.zip>
- **许可证**：CC0 1.0。包内许可证明确允许个人和商业项目使用；署名（Kenney 或 `www.kenney.nl`）是欢迎但非强制。
- **适配位置**：`magic_*`、`spark_*`、`slash_*`、`star_*`、`smoke_*` 的透明 PNG；用作灵力脉冲、剑气擦过、黑雨中的微光、战斗命中反馈。优先透明目录，不使用预览图中的 Kenney 标识。
- **质量判断**：512x512、透明版本完整、轮廓干净，作为低不透明度叠加足够产品级；原始色调偏通用 fantasy，需要在 Godot 中重着色为冷白/旧玉/朱砂并限制粒子数量，否则会破坏写实方向。不是角色或场景素材。
- **本地审计缓存**：`.tmp/art-candidates/kenney_particle-pack.zip`，SHA-256 `B631D4B07F7002549FDCF155F01141AD482F79F3440E4E301EED49CE5F1D8958`。已展开检查包内 `License.txt` 和透明 PNG，未接入运行时。
- **门禁**：只复制透明帧和许可证，不复制 `Preview.png`、Unity 示例包或带品牌标识的图。导入后需做一次 alpha、混合模式和帧率回归。

### A3. 70 Animated 2D Game Effects（优先：战斗冲击帧）

- **作者**：IndieDevs（OpenGameArt 页面作者）。
- **原始页**：<https://opengameart.org/content/70-animated-2d-game-effects>
- **直接下载**：<https://opengameart.org/sites/default/files/70_Effects_0.zip>
- **许可证**：页面标注 CC0，并写明可按任何方式使用；页面建议链接作者项目但不是许可义务。压缩包本身没有许可证文件，因此发布前必须把原始页面 URL、审计日期和 SHA-256 留在项目清单中。
- **适配位置**：70 张 1024x1024 PNG 冲击/爆炸序列，可筛选为受击闪白、剑气撞击、灵脉崩裂的小尺寸遮罩；不能整张当作章节背景。
- **质量判断**：边缘和光晕比当前程序生成的占位特效更有层次，战斗反馈价值高；颜色集中在金黄/白色，需减饱和、改色和缩小，避免“火球打天下”。命名和帧序不表达修仙语义，接入时要建立本地映射表。
- **本地审计缓存**：`.tmp/art-candidates/70_Effects_0.zip`，SHA-256 `D55E4814D8412DDB9AACA0624E7EA2E990BFD6BD46AB46A4481B8001CE2A7191`；已检查 70 个 PNG 和预览动画，未接入运行时。
- **门禁**：发布前将 CC0 页面快照/来源记录纳入许可证审计；检查每个序列是否为透明 alpha（不要误用黑底版本），并在 515x360 战斗舞台做视觉回归。

### A4. The Metropolitan Museum of Art Open Access（优先：章节记忆卡、卷轴过场）

- **许可总则**：Met 的 Open Access 说明页 <https://www.metmuseum.org/hubs/open-access> 与图像资源政策 <https://www.metmuseum.org/policies/image-resources> 明确，带 Open Access 标识的公版图像可免费下载、修改和再分发，包括商业用途；无需署名，但应保留对象编号和来源记录。
- **直接检索接口**：<https://collectionapi.metmuseum.org/public/collection/v1/search?hasImages=true&isPublicDomain=true&q=Chinese%20landscape>。对象 API 返回 `isPublicDomain=true` 和 `primaryImage`，接入前仍需逐对象复核页面上的 OA 标识。
- **候选 1：Ye Xin，《Landscape》**
  - 对象页：<https://www.metmuseum.org/art/collection/search/65625>
  - 原图：<https://images.metmuseum.org/CRDImages/as/original/DP332056.jpg>
  - 作者/年代：Ye Xin，约 1645–55；公版，API `isPublicDomain=true`。
  - 适配：旧玉回声、家契记忆、静室回想的横向卷轴裁片；保留山石和水面，裁掉左上题字与印章。
  - 质量：墨色层次和留白很适合文字舞台，但原图不是电影写实，必须作为“记忆媒介”而非主场景。
- **候选 2：Gong Xian，《Landscapes with poems》**
  - 对象页：<https://www.metmuseum.org/art/collection/search/36131>
  - 原图：<https://images.metmuseum.org/CRDImages/as/original/1981_4_1a.jpg>
  - 作者/年代：Gong Xian，1688；公版，API `isPublicDomain=true`。
  - 适配：宗门旧档、失踪卷宗、轮回结算的灰阶背景。裁去题诗和印章，或把其作为明确的“历史卷轴”而不是 UI 文本。
  - 质量：高对比笔墨和山谷结构在小尺寸仍可读，适合做章节转场；不适合直接替换 3:2 关键分镜。
- **候选 3：Monk Jie，《Landscape》**
  - 对象页：<https://www.metmuseum.org/art/collection/search/72710>
  - 原图：<https://images.metmuseum.org/CRDImages/as/original/2004_557_1_O.jpg>
  - 作者/年代：Monk Jie，标注 1599（或 1659）；公版，API `isPublicDomain=true`。
  - 适配：孤行、闭关、败战后的纵向记忆卡；裁切为 3:2 时只取山路和桥，不取题字。
  - 质量：纵向山势和人物尺度能提供叙事方向感，但原始分辨率/构图不宜直接铺满舞台。
- **候选 4：Table screen with landscape**
  - 对象页：<https://www.metmuseum.org/art/collection/search/856282>
  - 原图：<https://images.metmuseum.org/CRDImages/as/original/DP-24553-001.jpg>
  - 许可：API `isPublicDomain=true`；对象照片本身应按 OA 页面说明使用，不能把网页缩略图当源文件。
  - 适配：宗门陈列、旧物调查或“卷中卷”界面，不作为全屏场景。
  - 质量：蓝绿山水与木质屏座有很强的古典修仙辨识度，但屏座会占据画面；需要裁出屏内画面并保留对象来源记录。
- **门禁**：不得把现代网页截图、题字或印章当作游戏 UI 文本；先做无文字裁片，再做 3:2、515x360 和 104x154 的可读性检查。公版摄影复制在不同司法辖区仍可能有 PD-Art 例外，发布清单要保留对象页、API 返回值和下载日期。

### A5. Wikimedia Commons 公版中国山水（优先：长卷过场，不是角色分镜）

- **候选 1：王希孟《千里江山图》**
  - 原始页：<https://commons.wikimedia.org/wiki/File:Wang_Ximeng._A_Thousand_Li_of_Rivers_and_Mountains._(Complete,_51,3x1191,5_cm)._1113._Palace_museum,_Beijing.jpg>
  - 原图：<https://upload.wikimedia.org/wikipedia/commons/3/37/Wang_Ximeng._A_Thousand_Li_of_Rivers_and_Mountains._%28Complete%2C_51%2C3x1191%2C5_cm%29._1113._Palace_museum%2C_Beijing.jpg>
  - 作者/年代：王希孟，1113；页面标注作者于 1119 年去世，作品及二维公版复制为 Public Domain。
  - 适配：卷首/卷尾、轮回计数、世界观地图式横向过场。按段裁切为 3:2，绝不能直接当“镜湖”写实场景。
  - 质量：原图细节极高、青绿山水辨识度强，是目前最适合作为“卷轴媒介”的公版候选；颜色应压低饱和度以匹配现有界面。
- **候选 2：黄公望《富春山居图》（第二段）**
  - 原始页：<https://commons.wikimedia.org/wiki/File:Dwelling_in_the_Fuchun_Mountains_(second_half).jpg>
  - 原图：<https://upload.wikimedia.org/wikipedia/commons/7/7e/Dwelling_in_the_Fuchun_Mountains_%28second_half%29.jpg>
  - 作者/年代：黄公望（1269–1354）；页面按二维公版作品标注 Public Domain。
  - 适配：闭关、远行和“多年后再见”的时间跳转；使用山水裁片，不使用整幅长卷缩放成一条模糊背景。
  - 质量：灰墨留白克制，适合文字叙事和创伤后章节；不适合替代人物立绘或战斗舞台。
- **门禁**：Wikimedia 的 PD-Art 页面提醒不同司法辖区可能存在例外；保留原始页面、原图 URL、作者、作品年代与下载哈希。当前审计因 Wikimedia 触发 429 未把原图复制到缓存，但来源已核验，不能把这项写成“已下载”。

### A6. Poly Haven CC0 材质（辅助：材质蒙版/微纹理）

- **许可页**：<https://polyhaven.com/license>。Poly Haven 明确所有 HDRI、纹理和 3D 模型为 CC0，可商业使用、修改和再分发且不强制署名。
- **候选**：
  - Dark Rock：<https://polyhaven.com/a/dark_rock>，作者 Amal Kumar；适合石台、山门和战斗舞台暗部。
  - Fine Grained Wood：<https://polyhaven.com/a/fine_grained_wood>，作者 Rob Tuytel；适合旧桌、卷轴框和界面底纹。
  - Monastery Stone Floor：<https://polyhaven.com/a/monastery_stone_floor>，作者 Amal Kumar；适合石阶/遗迹的局部蒙版。
- **直接下载**：资产页的“Download”或官方 API，例如 <https://api.polyhaven.com/files/fine_grained_wood>；运行时应下载 1K/2K 的 `col`、`rough`、`nor_gl` 等地图，不要使用站点缩略图。
- **质量判断**：纹理质量和材质信息达到产品级，但它们是球体预览/材质输入，不是可直接铺满的剧情背景。建议只在场景或面板中以 3–8% 不透明度、遮罩和轻微色调叠加使用，避免 UI 变成棕色纹理墙。
- **本地审计缓存**：`.tmp/art-candidates/polyhaven-*.png` 仅为 512px 缩略图视觉参考，**不允许复制进运行时或发布物**；缩略图和示例渲染不在 CC0 资产许可范围内。

## 已排除候选

| 候选 | 页面/作者 | 许可核验 | 排除理由 |
| --- | --- | --- | --- |
| VN Backgrounds: Chinese Gardens (Xianxia Wuxia) | [LinXueLian itch.io](https://linxuelian.itch.io/bgres-xxwx-cngarden-photoedited) | 页面说明底图来自 Unsplash，并明确“不建议付费/商业项目”，要求联系摄影师 | 商业授权冲突；不能因页面写 Free 就接入 |
| VN Sprites: Murong Yi 700px (Xianxia) | [LinXueLian itch.io](https://linxuelian.itch.io/charres-xxwx-murongyi) | 页面明确 `This is a non-commercial project`；站点 CC BY 标签与正文冲突 | 非商业限制，且动漫立绘与写实身份锚点不匹配 |
| Minimalist Chinese Temple tileset | [bart / OpenGameArt](https://opengameart.org/content/minimalist-chinese-temple-tileset) | CC BY 3.0 | 许可可用但为低分辨率像素瓦片，不能替代电影感场景；若用于原型也必须署名 |
| Kenney UI Pack (RPG Expansion) | [Kenney](https://kenney.nl/assets/ui-pack-rpg-expansion) | CC0，包内 `license.txt` | 法律上可用，但预览显示为高饱和卡通 RPG UI，与当前克制写实界面明显冲突；暂不入库 |
| Meshy Xianxia 3D models | [Meshy Xianxia gallery](https://www.meshy.ai/tags/xianxia) | 页面写“免费商用”，模型为平台 AI 生成/用户上传，具体模型条款和训练来源不统一 | 来源、再分发边界和身份一致性不足；按产品级要求排除，不把 AI 生成结果当已审计美术 |
| 任何来源不明的“AI 仙侠人物/场景包” | 各类聚合站、社交媒体下载 | 无法核验原始作者、训练数据、商业授权和再分发权 | 直接排除；不能只凭图片质量或“免版权”文案入库 |

## 本地缓存与哈希

以下均位于被 `.gitignore` 忽略的 `.tmp/art-candidates`，只用于本次审计，不是运行时资源：

| 路径 | 来源 | SHA-256 |
| --- | --- | --- |
| `kenney_particle-pack.zip` | Kenney Particle Pack 1.1 | `B631D4B07F7002549FDCF155F01141AD482F79F3440E4E301EED49CE5F1D8958` |
| `kenney_ui-pack-rpg-expansion.zip` | Kenney UI Pack RPG Expansion（仅作许可/风格对照） | `C69C30C09D74DF542842E4EC811735B6D260CD6C9E2EE261D7B894D259A6ADB4` |
| `70_Effects_0.zip` | OpenGameArt 70 Animated 2D Game Effects | `D55E4814D8412DDB9AACA0624E7EA2E990BFD6BD46AB46A4481B8001CE2A7191` |
| `game-icons/` | Game Icons 仓库浅克隆 | commit `82d948812bfe3f269ef8f731dcdb07b08160edc4` |
| `polyhaven-dark-rock.png`、`polyhaven-fine-wood.png`、`polyhaven-monastery-stone.png` | Poly Haven 缩略图，仅视觉参考 | 不得发布或接入 |

## 下一轮接入门禁

1. 只从本清单的原始页/直接下载页重新取得文件，记录下载日期、版本、哈希和许可证文本；不从 `.tmp` 直接晋级。
2. UI 图标先做 32/48/64 px 联系表，确认笔画粗细与现有字体、按钮状态一致；Game Icons 的 CC BY 署名写入项目许可证清单。
3. 特效先验证 alpha、混合模式、帧率和颜色，不把整包导入；Kenney/OGA 只作为叠加反馈，不改变战斗逻辑。
4. 公版山水先裁掉题字、印章、网页边框和博物馆对象照片；只作为章节过场/记忆媒介，不能冒充角色身份锚点或关键分镜。
5. Poly Haven 只使用官方材质地图，禁止使用网站缩略图/示例渲染；导入后做体积、显存和重复纹理检查。
6. 任何角色候选必须至少两张独立候选通过身份一致性、手部/服饰检查、104x154 与 515x360 缩放检查后，才可使用 `tools/promote_art_candidate.py` 晋级。
7. 发布前清理 `.tmp/art-candidates`、浏览器下载和解压目录；本文件保留来源与哈希作为审计记录，不把临时产物提交到 GitHub。
