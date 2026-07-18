# 产品美术生产简报 V1

本简报用于生成、筛选和验收首批角色身份锚点与剧情分镜。它不是占位素材清单。任何候选图只有在通过身份一致性、叙事准确性、构图适配和技术检查后，才能写入 `godot/art/art_manifest.json` 并把角色状态改为 `approved`。

## 统一美术方向

- 电影感写实中国修仙，保留真实皮肤、布料、金属、木石和使用痕迹。
- 超自然元素是局部光效和世界机制，不把人物做成霓虹偶像或通用仙侠海报。
- 服装可穿着、可行动，角色气质来自姿态、目光和处境，不来自无叙事理由的裸露。
- 同一角色跨立绘与分镜锁定脸型、五官比例、发际线、基准发型和核心饰物。
- 禁止日式和服、日系校服、塑料皮肤、通用大眼、夸张胸腰、文字、水印、签名和伪造汉字。
- 画面必须在游戏内 104x154 小头像和约 515x360 事件舞台上仍有清楚轮廓。

## P1-01 男主身份锚点

目标路径：`res://art/portraits/protagonist_canonical_v1.png`

```text
Use case: stylized-concept
Asset type: canonical game character portrait and identity anchor
Primary request: create the definitive male protagonist for a cinematic realistic Chinese xianxia role-playing game
Scene/backdrop: quiet stone terrace beside Mirror Lake before dawn, distant architecture soft and secondary
Subject: Chinese man in his mid twenties, lean with practical strength, restrained alert expression, clearly visible face, tied black hair with a few natural loose strands, dark charcoal and weathered off-white layered cultivation clothing built for travel, a small black-and-white reincarnation jade pendant as the only supernatural identity marker
Style/medium: cinematic realistic character photography blended with high-end game concept art, believable anatomy and skin texture
Composition/framing: vertical three-quarter portrait from head to below waist, readable silhouette, hands natural and secondary, face unobstructed, enough breathing room around hair and shoulders
Lighting/mood: cold predawn ambient light with a narrow warm reflection from the jade, introspective rather than heroic posing
Color palette: charcoal, worn off-white, muted jade, restrained cool lake tones
Materials/textures: woven cloth, worn leather ties, natural hair, subtle pores and fabric wear
Constraints: stable reproducible identity; practical Chinese-inspired clothing; no text; no watermark; no logo; no mask; no hood covering the face; no ornate crown; no glowing eyes
Avoid: generic brooding assassin, Japanese clothing, anime face, beauty-filter skin, bodybuilder proportions, excessive jewelry, theatrical fog hiding the silhouette
```

## P1-02 江照雪女主身份锚点

目标路径：`res://art/portraits/jiang_zhaoxue_v1.png`

```text
Use case: stylized-concept
Asset type: canonical female-lead game character portrait and identity anchor
Primary request: create Jiang Zhaoxue, the recurring rival and female lead of a cinematic realistic Chinese xianxia role-playing game
Scene/backdrop: austere mountain sword court after light snow, architecture subdued and out of focus
Subject: Chinese woman in her mid twenties, calm direct gaze, sharp but natural facial structure, practical tied black hair, pale gray-blue narrow-sleeved sword clothing with reinforced shoulders and weathered cuffs, plain long sword and folded old challenge letter as identity props
Style/medium: cinematic realistic character photography blended with high-end game concept art, believable anatomy and real skin texture
Composition/framing: vertical three-quarter portrait from head to below waist, balanced grounded stance, sword held safely at rest, face and hands anatomically clear
Lighting/mood: crisp winter daylight, controlled tension, self-possession rather than glamour
Color palette: pale gray-blue, charcoal, aged paper, small cold silver accents
Materials/textures: matte woven cloth, practical leather grip, lightly worn steel, natural hair and skin
Constraints: stable reproducible identity; adult professional fighter; nonsexual pose and wardrobe; no text; no watermark; no logo; no tiara; no forehead sigil
Avoid: shared face with Ning Zhaoxue, exaggerated breasts or waist, translucent clothing, bridal styling, anime princess, ornate fantasy armor, flower-petal beauty shot
```

## P1-03 主反派身份锚点

目标路径：`res://art/portraits/siming_antagonist_v1.png`

```text
Use case: stylized-concept
Asset type: canonical primary-antagonist game character portrait and identity anchor
Primary request: create Siming Zhibi, a recurring institutional antagonist who edits mortal fate records
Scene/backdrop: severe archive hall with suspended blank jade registers, architecture symmetrical and restrained
Subject: Chinese man in his early forties, composed authoritative face, controlled expression of absolute certainty, black formal Daoist-official robe with narrow sleeves and subtle ink-wash weave, a plain white-jade fate brush held like an administrative tool, no mask
Style/medium: cinematic realistic character photography blended with high-end game concept art, grounded historical-fantasy materials
Composition/framing: vertical three-quarter portrait, upright still posture, visible face and hands, strong readable silhouette without oversized armor
Lighting/mood: cool archive light with one hard side highlight, quiet threat rooted in institutional power
Color palette: ink black, bone white, oxidized bronze, faint desaturated jade
Materials/textures: dense woven robe, matte jade, old bronze fittings, realistic skin with age detail
Constraints: stable reproducible identity; intimidating without monstrosity; no text; no watermark; no logo; no mask; no glowing eyes; no skull decoration
Avoid: generic evil sorcerer, sneering villain, demonic horns, black smoke covering the body, Japanese onmyoji styling, anime face, fashion-editorial pose
```

## P2-01 宁照雪独立身份锚点

目标路径：`res://art/portraits/ning_zhaoxue_v1.png`

```text
Use case: stylized-concept
Asset type: canonical female-supporting game character portrait
Primary request: create Ning Zhaoxue, the last disciple of a mountain-guarding lineage, clearly distinct from Jiang Zhaoxue
Scene/backdrop: weathered mountain gate and old oath stones under overcast daylight
Subject: Chinese woman in her early twenties, steady guarded expression, broader cheekbones and softer brows than Jiang Zhaoxue, compact practical braid, deep teal shoulder guard, dark narrow-sleeved travel clothing, worn oath cord tied at the wrist, utilitarian sword
Style/medium: cinematic realistic character photography blended with high-end game concept art
Composition/framing: vertical three-quarter portrait, grounded defensive posture, readable face and hands
Lighting/mood: subdued mountain daylight, resilient and duty-bound
Color palette: deep teal, weathered black, stone gray, faded red oath cord
Constraints: independent face, hairstyle and silhouette; practical clothing; no text; no watermark; nonsexual presentation
Avoid: resemblance to Jiang Zhaoxue, white bridal robes, flower crown, glamour pose, anime face, ornate silver fantasy armor
```

## P2-02 迟药青独立身份锚点

目标路径：`res://art/portraits/chi_yaoqing_v1.png`

```text
Use case: stylized-concept
Asset type: canonical female-supporting game character portrait
Primary request: create Chi Yaoqing, an unlicensed traveling healer who refuses to hide treatment costs and moral consequences
Scene/backdrop: working herbal clinic beside a river market, shelves and tools soft and secondary, no readable labels
Subject: Chinese woman around thirty, attentive but firm expression, realistic adult face with small signs of fatigue, practical tied hair, durable muted green-gray narrow-sleeved clothing, worn medicine case and cloth-wrapped diagnostic tools
Style/medium: cinematic realistic character photography blended with high-end game concept art
Composition/framing: vertical three-quarter portrait, clear face and natural working hands, professional grounded posture
Lighting/mood: soft window daylight, humane but unsentimental
Color palette: muted herb green, gray linen, dark wood, small aged-jade accent
Materials/textures: worn cloth, scratched wood, dried herbs, realistic skin and hands
Constraints: stable adult identity; practical healer wardrobe; no text; no watermark; no logo; nonsexual presentation
Avoid: teenage beauty idol, flower-crown fairy, revealing neckline, porcelain skin, smiling advertisement pose, fake Chinese labels
```

## P2-03 闻星渡身份与性别对齐锚点

目标路径：`res://art/portraits/wen_xingdu_v1.png`

```text
Use case: stylized-concept
Asset type: canonical female-supporting game character portrait
Primary request: create Wen Xingdu, a female patrol cultivator responsible for identity and memory disputes in the Star Dao Network era
Scene/backdrop: restrained orbital Dao-network observatory with physical consoles and distant star paths, no interface text
Subject: Chinese woman in her early thirties, short tied black hair, observant tired eyes, practical dark robe-jacket reinforced with ceramic interface nodes, subtle cyan-white meridian light at the collar and wrist, fully human recognizable face
Style/medium: cinematic realistic science-fantasy character photography blended with high-end game concept art
Composition/framing: vertical three-quarter portrait, clear face and hands, interface elements secondary to identity
Lighting/mood: cool operational light, lucid and ethically burdened rather than glamorous
Color palette: charcoal, ceramic white, restrained cyan, small violet status light
Materials/textures: matte technical cloth, ceramic nodes, brushed dark metal, realistic skin
Constraints: stable female identity; Chinese xianxia technology language; no text; no watermark; no logo; no holographic mask; nonsexual presentation
Avoid: male face, cyberpunk nightclub, neon bodysuit, anime pilot, floating UI text, glowing eyes, plastic skin
```

## P2-04 韩玄素身份与性别对齐锚点

目标路径：`res://art/portraits/han_xuansu_v1.png`

```text
Use case: stylized-concept
Asset type: canonical female-supporting game character portrait
Primary request: create Han Xuansu, a mature female meridian-contract physician working in the resource-starved Final Dharma era
Scene/backdrop: dim clinical contract station with physical diagnostic vessels and sealed document cases, no readable labels
Subject: Chinese woman in her early forties, composed professional face with visible fatigue and age detail, practical tied hair, layered dark medical robe with reinforced sleeves, compact contract folder and a faint anatomical meridian projection held as a diagnostic tool
Style/medium: cinematic realistic character photography blended with high-end game concept art
Composition/framing: vertical three-quarter portrait, clear female identity, readable face and natural hands, professional posture rather than combat pose
Lighting/mood: low cool clinical light with a restrained warm work lamp, ethically burdened but dependable
Color palette: charcoal, desaturated teal, old paper, small amber instrument light
Materials/textures: worn medical cloth, scratched glass, aged paper, realistic skin and hand detail
Constraints: stable mature female identity; practical physician clothing; no text; no watermark; no logo; no glamour retouching
Avoid: male face, teenage healer, seductive doctor costume, cyberpunk bodysuit, anime face, floating interface text, plastic skin
```

## P3-01 两代执律人群像锚点

目标路径：`res://art/portraits/sect_lawkeepers_v1.png`

```text
Use case: stylized-concept
Asset type: canonical supporting-ensemble game portrait
Primary request: create the two generations of sect lawkeepers who embody an old rule and its contested modern interpretation
Scene/backdrop: austere sect archive threshold, blank bamboo and jade registers without readable writing
Subject: two Chinese adults with clearly different faces and ages, an older woman in a worn dark formal robe and a younger man in a restrained gray-blue duty robe, both holding different ends of the same plain law tablet, neither posed as a villain
Style/medium: cinematic realistic ensemble character photography blended with high-end game concept art
Composition/framing: vertical two-person portrait, both faces readable at small size, simple triangular grouping, hands and shared tablet anatomically clear
Lighting/mood: cool institutional daylight with a thin warm edge, formal tension
Color palette: charcoal, gray-blue, old bamboo, muted brass
Constraints: two stable independent identities; functional formal clothing; blank tablet; no text; no watermark; no logo
Avoid: single glamorous sword heroine, cloned faces, courtroom cosplay, imperial emperor styling, anime group poster
```

## P3-02 祖契持有人群像锚点

目标路径：`res://art/portraits/family_covenant_holders_v1.png`

```text
Use case: stylized-concept
Asset type: canonical supporting-ensemble game portrait
Primary request: create the witnesses who carry the protagonist's family covenant, balancing bloodline evidence against the people who raised him
Scene/backdrop: old family courtyard room with repaired wood and sealed storage, no readable calligraphy
Subject: two Chinese adults with distinct identities, an elderly former household retainer with weathered hands and a middle-aged foster mother in durable everyday clothing, together presenting a sealed blank jade register and an old folded letter
Style/medium: cinematic realistic ensemble character photography blended with high-end game concept art
Composition/framing: vertical two-person portrait, both faces and evidence props readable, intimate documentary grouping rather than ceremonial pose
Lighting/mood: overcast window light, guarded affection and accumulated debt
Color palette: worn umber wood, gray linen, faded indigo, muted jade
Materials/textures: repaired cloth, aged paper, scratched jade, realistic age and hand detail
Constraints: two stable independent adult identities; no text; no watermark; no logo; no aristocratic glamour
Avoid: young healer reused as both people, family advertisement, fantasy royalty, cloned faces, fake writing, melodramatic crying
```

## S1-01 男主分镜：旧玉初醒

目标路径：`res://art/scenes/story_jade_first_warmth_v1.png`

```text
Use case: illustration-story
Asset type: cinematic landscape game storyboard
Input images: Image 1: approved male-protagonist identity anchor
Primary request: the same protagonist wakes at midnight as the black-and-white reincarnation jade becomes warm without being touched
Scene/backdrop: modest Chinese cultivation-era room, paper window, low wooden table, rain-muted courtyard outside
Subject: same protagonist from Image 1 seated at the bedside in simple inner travel layers, face clearly recognizable; two incompatible shadows fall across the paper window, one matching him and one suggesting a future fatal stance
Style/medium: cinematic realistic narrative frame matching Image 1
Composition/framing: 3:2 landscape, medium-wide eye-level shot, protagonist on the lower central third, jade and two shadows readable at game scale, clean lower band for the game caption overlay
Lighting/mood: cold moonlight and one restrained warm pulse from the jade, intimate unease
Constraints: preserve the protagonist's face, proportions, hair and jade pendant; no text; no watermark; no extra people; no horror distortion
Avoid: action pose, floating meditation, explosive magic, face hidden in darkness, generic bedroom glamour
```

## S1-02 男主分镜：镜湖无字门

目标路径：`res://art/scenes/story_mirror_lake_gate_v1.png`

```text
Use case: illustration-story
Asset type: cinematic landscape game storyboard
Input images: Image 1: approved male-protagonist identity anchor
Primary request: the same protagonist stands at Mirror Lake before a monumental blank ancient gate that is absent from every fate register
Scene/backdrop: mirror-still lake, broken jade stepping path, austere Chinese xianxia architecture suspended beyond the water, no written inscriptions
Subject: same protagonist from Image 1 seen in clear three-quarter profile, face still identifiable, one hand near but not touching the jade pendant, the blank gate reflecting a slightly different version of his stance
Style/medium: cinematic realistic narrative frame matching Image 1 and the established world
Composition/framing: 3:2 landscape wide shot, protagonist large enough to retain identity, gate dominates upper center, clear lower band for caption overlay
Lighting/mood: predawn silver light, solemn threshold, restrained surrealism
Constraints: preserve identity and outfit; gate contains no characters or symbols; no text; no watermark; no extra people
Avoid: tiny anonymous silhouette, fantasy portal ring, Western cathedral, Japanese torii, neon sci-fi gate, excessive fog
```

## S1-03 双主角分镜：照雪初帖

目标路径：`res://art/scenes/story_zhaoxue_first_challenge_v1.png`

```text
Use case: illustration-story
Asset type: cinematic landscape game storyboard
Input images: Image 1: approved male-protagonist identity anchor; Image 2: approved Jiang Zhaoxue identity anchor
Primary request: Jiang Zhaoxue formally delivers her first challenge letter to the protagonist without hostility or ceremony
Scene/backdrop: spare mountain sword court at late winter dusk, training marks and wind-worn stone visible
Subject: same Jiang Zhaoxue from Image 2 extends a folded blank challenge letter; same protagonist from Image 1 receives it without drawing his weapon; both faces identifiable and anatomically consistent
Style/medium: cinematic realistic narrative frame matching both anchors
Composition/framing: 3:2 landscape two-shot at eye level, balanced distance and equal visual agency, hands and letter clear, lower band reserved for caption overlay
Lighting/mood: cold dusk, mutual appraisal, controlled tension
Constraints: preserve both identities, outfits and proportions; letter has no visible writing; no text; no watermark; no romantic pose; no crowd
Avoid: duel already in progress, bridal framing, sexualized tension, one character dominating the frame, anime poster composition
```

## 验收顺序

1. 每个身份锚点至少比较两张候选，但只保留通过者进入运行时目录。
2. 先验收男主、江照雪和主反派的正面身份锚点，再以锚点作为分镜输入，禁止用纯文字重新猜脸。
3. 检查五官、手指、武器握法、衣物结构、背景伪字、画面水印和不合理高光。
4. 将候选缩放到 104x154 与 515x360 检查轮廓、面部和关键道具是否仍可读。
5. 对同一角色的所有成片并排检查脸型、发型、年龄和核心饰物；对不同角色检查是否串脸。
6. 只有通过视觉检查、清单哈希校验、真实渲染截图和产品发布门禁的资产才能标记为 `approved`。

候选图先放在运行时目录之外，再执行自动预检和联系表生成：

```powershell
python -X utf8 tools/review_art_candidates.py --kind portrait `
  --reference godot/art/portraits/protagonist_canonical_v1.png `
  candidate-a.png candidate-b.png
```

工具会在 `.tmp/art-candidate-review` 生成 JSON 指标报告、并排联系表，以及身份卡 `104x154`、宽屏事件舞台 `515x360`、窄屏事件舞台 `680x360` 等实际运行尺寸预览。人物预览使用运行时相同的上偏 `focus_y=0.18` 裁切，不再用与游戏不一致的整图缩放。`--kind environment` 用于 4:3 常规场景，`--kind storyboard` 用于 3:2 关键剧情分镜。自动检查只负责淘汰尺寸、比例、压黑、过曝、模糊、低动态、异常透明度和候选间近重复问题，最终仍由本任务中的视觉检查决定是否入库。

通过视觉检查后，用同一份报告执行晋级。命令会校验报告中的 SHA-256、再次检查 PNG 与目标尺寸，并同步更新角色/分镜目录、事件与剧情绑定、`art_manifest.json`；没有显式 `--visual-approved` 不会写入运行时：

```powershell
python -X utf8 tools/promote_art_candidate.py `
  --identity protagonist `
  --candidate .tmp/art-candidates/protagonist_a.png `
  --review-report .tmp/art-candidate-review/portrait-report.json `
  --visual-approved
```

关键分镜将 `--identity` 换成 `--storyboard jade_first_warmth`，并使用 `--kind storyboard` 生成的报告。角色和分镜目标路径由 `character_art_v1.json` 唯一决定，不在命令行重复输入，避免资源登记与剧情绑定漂移。

## 动效原则

- 默认使用 0.3% 至 0.8% 的呼吸缩放、最多 4px 人物视差和最多 12px 场景视差。
- 人脸区域不做局部扭曲，不做明显整图上下浮动，不让衣发摆动改变角色轮廓。
- 全幅分镜使用 `portrait_mode: scene_only`，避免场景里已有角色时再叠一张重复立绘。
- 若未来取得分层源文件，只对发梢、衣摆、粒子和局部光源做独立动画，脸、手和身份饰物保持稳定。
