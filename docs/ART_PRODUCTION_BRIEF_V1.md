# 产品美术生产简报 V1

本简报用于生成、筛选和验收首批角色身份锚点与剧情分镜。它不是占位素材清单。任何候选图只有在通过身份一致性、叙事准确性、构图适配和技术检查后，才能写入 `godot/art/art_manifest.json` 并把角色状态改为 `approved`。

## 统一美术方向

- 现有 `protagonist_hooded_close.jpg` 与 `qingyun_sword_heroine.jpg` 是主角不可降级的视觉母版；新图只提高精度、材质、光影和构图适配，不重新设计角色。
- 主角采用顶尖画师级仙侠游戏 CG：精致幻想数字绘画、可信材质与电影级光影并存，不做粗糙纪实摄影或低成本真人古装剧质感。
- 地域审美采用开放调色板。中、日、韩及其他地域的服饰、纹样、发型、建筑和构图语言都可以使用，前提是经过研究、与角色身份及故事时代协调，并且不是对已知 IP 的复刻。
- 修仙者的视觉年龄由境界、修行状态、种族特征和当前剧情共同决定，不能把实际岁数机械换算成衰老程度；数百岁的高境界角色可以保持年轻外貌，年龄阅历应通过眼神、姿态、气场、细节与身份物件表达。
- 服装可穿着、可行动；地域影响不因来源被排除。低胸、贴身剪裁、胸腰强调与诱惑性设计不是统一禁区：当角色明确为成年人，且妖族、魔女、魅惑者等身份或剧情需要这种视觉语言时可以主动使用；教廷、监察、医修、执律等角色则按职责选择端庄、克制或功能性轮廓。拒绝依据仅限身份冲突、时代错置、无动机拼贴、技术违和、未成年性化或已知 IP 复刻，不以国籍、地域或性感程度本身作为负向词。
- 同一角色跨立绘与分镜锁定视觉身份。露脸角色锁定脸型、五官、发型和核心饰物；兜帽男主锁定兜帽遮眼比例、侧背轮廓、墨黑织锦披风、深青流苏与黑白轮回玉，不重新猜测其正脸。
- 每个具名角色和群像成员都必须具备主角级的可辨识度。不同角色不能只靠年龄、左右位置或换色区分；至少在脸型与五官比例、发式或头部轮廓、服装大轮廓、主色块、姿态与核心道具六项中明确区分四项，并在 104x154 小头像下仍能一眼认出。群像成员不得使用“同一模板换年龄/性别”的脸。
- 禁止塑料皮肤、廉价模板脸、畸形肢体、身份或时代不协调的服装拼贴、文字、水印、签名和伪造汉字。
- 单一连贯成片是默认交付方式；双层人物或合成并非地域或形式黑名单，但只有在叙事需要、素材同源且光线、透视、尺度、景深、风向和边缘完全一致时才可接受，任何可见接缝、重影或身份冲突都按技术违和拒绝。
- 画面必须在游戏内 104x154 小头像和约 515x360 事件舞台上仍能读出脸部或兜帽识别区、人物轮廓与关键道具。

## P1-01 男主身份锚点

目标路径：`res://art/portraits/protagonist_canonical_v1.png`

```text
Use case: stylized-concept
Asset type: canonical game character portrait and identity anchor
Input image: Image 1 is res://art/portraits/protagonist_hooded_close.jpg and is the binding identity/style reference
Primary request: create a higher-quality image of the same hooded male protagonist without redesigning him
Scene/backdrop: rain-misted mountain gate or a quiet Mirror Lake terrace before dawn, architecture atmospheric and secondary
Subject: lean Chinese man in his mid twenties, head lowered in a three-quarter side or back view; a broad dark ink-black and deep-teal hood projects forward so its shadow and damp black strands completely hide both eyes and most of the upper face; preserve the near-black scale-pattern brocade cloak, silver edging, fine chains, deep-teal beads and tassels, layered wind-torn hems, and the black-and-white reincarnation jade as the clearest identity marker
Style/medium: top-tier stylized xianxia game CG and refined fantasy digital painting, product-quality material detail, not documentary photography
Composition/framing: vertical three-quarter portrait, hood recognition area in the upper 25-32 percent, readable side/back silhouette, jade and tassels visible at game scale, lower area safe for captions
Lighting/mood: cold silver-blue rim light, restrained cyan reflections, fine rain and mist that add narrative atmosphere without swallowing the silhouette
Color palette: ink black, dark teal, cold silver, black-and-white jade, restrained mist gray
Materials/textures: intricate brocade, silver thread, chains, beads, tassels, damp hair, jade and rain-wet surfaces
Constraints: the hood is mandatory; both eyes remain invisible; never reveal or invent a complete front face; preserve the reference silhouette, cloak design, tassels and jade; regional influences are allowed when coherent with this identity; no text; no watermark; no logo
Avoid: pushed-back hood, visible eyes, full-face hero portrait, plain gray-white workwear, generic travel clothes, bodybuilder proportions, generic leather-assassin template, copied IP costume or iconography, lighting or fog that erases the silhouette
```

## P1-02 江照雪女主身份锚点

目标路径：`res://art/portraits/jiang_zhaoxue_v1.png`

```text
Use case: stylized-concept
Asset type: canonical female-lead game character portrait and identity anchor
Input image: Image 1 is res://art/portraits/qingyun_sword_heroine.jpg and defines the minimum beauty, finish and visual-language bar; do not copy a known IP identity
Primary request: create Jiang Zhaoxue, a recurring rival and female lead, as an original higher-quality continuation of the established heroine style
Scene/backdrop: mountain sword court after light snow, with optional pale petals, fine mist and subdued architecture
Subject: beautiful Chinese woman in her early-to-mid twenties, refined original oval or heart-shaped face, luminous cool-fair skin with subtle natural texture, focused gray-blue eyes, long blue-black hair in an ornate half-up style, original silver-blue ice-crystal or leaf-like hair ornaments and a small cyan forehead ornament; layered jade-white, silver and ice-blue sword dress with embroidered waist, flowing sleeves and detailed shoulder ornament; an original ornate silver-blue sword and a folded blank challenge letter
Style/medium: top-tier stylized 3D/CG and refined fantasy digital painting, commercial key-art finish rather than live-action photography
Composition/framing: vertical three-quarter portrait, graceful but action-capable stance, face and hands clear, hair and garments moving in one coherent wind direction, lower area safe for captions
Lighting/mood: crisp winter light with ice-blue or moon-violet rim light, alive and emotionally specific rather than a static cold-face pose
Color palette: jade white, silver, ice blue, blue-black hair, restrained cyan and pale-petal accents
Materials/textures: fine hair, natural luminous skin, layered gauze, embroidered cloth, silverwork, jade and polished steel
Constraints: original adult identity; beautiful, youthful and vivid without becoming underage or sexualized; preserve the established long-hair, silver-blue ornament and white/ice-blue sword-dress language; researched regional influences are welcome when coordinated; no text; no watermark; no logo; no known-IP replica
Avoid: middle-aged or masculinized identity drift, generic passerby face, practical topknot and rough gray-blue workwear redesign, low-cost live-action costume texture, copied face or costume, anatomy errors, unrelated props or inconsistent wind direction
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
Constraints: stable reproducible identity; intimidating without monstrosity; researched regional ceremonial influences are allowed when they support his institutional role; no text; no watermark; no logo; no mask; no glowing eyes; no skull decoration
Avoid: generic evil sorcerer, sneering villain, demonic horns, black smoke covering the body, copied occult or religious iconography, role-incoherent ritual props, low-detail template face, fashion-editorial pose
```

## P2-01 宁照雪独立身份锚点

目标路径：`res://art/portraits/ning_zhaoxue_v1.png`

```text
Use case: stylized-concept
Asset type: canonical female-supporting game portrait and regional identity anchor
Primary request: create Ning Zhaoxue, the last disciple of a mountain-guarding lineage, clearly distinct from Jiang Zhaoxue and visually alive in a commercial-quality CG frame
Scene/backdrop: rain-cleared Sea-Fog Pass on an island cliff, wet stone steps, an unmarked timber watchtower, distant islands and sea pines in one continuous atmosphere
Subject: beautiful adult woman in her early twenties, original face with broader youthful cheekbones and softer but resolute brows than Jiang Zhaoxue, high tied hair with a long side braid, deep teal and smoke-black overlapping short combat layers, practical split skirt-trouser proportions, light dark lacquer shoulder guards, aged silver fittings, faded red oath cords and a narrow sea-pattern guardian sword
Regional design rationale: the pass grew through contact between the East Sea islands, inland mountain sects and peninsula trade routes. Reinterpreted Japanese-island craft structures such as crossed fronts, lacquered wood, knot work and maritime weave motifs may appear when they support the guard's function; they are not a costume replica, cosplay or IP quotation.
Style/medium: top-tier stylized xianxia game CG and refined fantasy digital painting, premium skin, hair, woven cloth, lacquer, metal and wet-air detail; product key-art finish rather than live-action photography
Composition/framing: vertical three-quarter portrait, body turning toward an off-screen sound with believable weight, face in the upper 25-32 percent, hands and sword grip readable, lower area safe for captions
Lighting/mood: bright cool silver daylight after rain, soft cyan sea rim light and restrained warm reflections on copper and oath cords; alert curiosity and protective concern rather than a static ID pose
Color palette: deep teal, smoke black, cold sea silver, aged bronze and controlled oath-red accents
Constraints: independent face, hairstyle, silhouette and sword language; coherent wind direction across braid, ribbons and skirt panels; no text; no watermark; nonsexual presentation; no known-IP replica
Avoid: resemblance to Jiang Zhaoxue, identity-confusing reuse of her white-and-ice-blue costume language, unresearched or unmodified real-world costume copied without narrative/function support (including ready-made kimono or hanbok), idol styling, glamour pose that erases Ning's guarded role, low-detail template face, copied IP armor, rough cutout or visible seam
```

## P2-02 迟药青独立身份锚点

目标路径：`res://art/portraits/chi_yaoqing_v1.png`

```text
Use case: stylized-concept
Asset type: canonical female-supporting game character portrait
Primary request: create Chi Yaoqing, an unlicensed traveling healer who refuses to hide treatment costs and moral consequences
Scene/backdrop: open traveling medicine stall beside the rainy Lantern River market, awning edge, river lights and steam separated for parallax, no readable labels
Subject: adult Chinese woman with a short round-heart face, broad soft cheekbones, warm sun-touched skin and light freckles; asymmetric cropped hair with no bun or crown; rust-red short healer jacket, mustard stand collar, peacock-green rain cape, cross-body medicine chest, ceramic bottles and folding copper scale
Style/medium: top-tier painted 2D xianxia key art with disciplined shape design, finished with credible 3D/PBR skin, cloth, leather, wood and hammered-copper materials; never a live-action still
Composition/framing: vertical three-quarter portrait, leaning into a weighing action with the scale and bowl readable, face in the upper 25-30 percent, clear subtitle safe area
Lighting/mood: warm market rim light against cool river fill, lively, humane and slightly unruly
Color palette: rust red, mustard, peacock green, warm brown and hammered copper
Materials/textures: weathered short cloth, waxed leather, scratched wood, ceramic glaze, dried herbs and believable working hands
Constraints: stable adult identity; short asymmetric silhouette; functional traveling-healer wardrobe; separable hair tips, cape, pouches, steam and awning edge; no text; no watermark; no logo
Avoid: resemblance to Han Xuansu; narrow oval template face; center-parted bun; gray-black teal cross-collar robe; indoor bottle-filled pharmacy; teenage idol; flower-crown fairy; advertising smile; fake Chinese labels
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
Avoid: male identity drift, cyberpunk nightclub, neon bodysuit, role-incoherent generic pilot template, floating UI text, glowing eyes, plastic skin
```

## P2-04 韩玄素身份与性别对齐锚点

目标路径：`res://art/portraits/han_xuansu_v1.png`

```text
Use case: stylized-concept
Asset type: canonical female-supporting game character portrait
Primary request: create Han Xuansu, a mature female meridian-contract physician working in the resource-starved Final Dharma era
Scene/backdrop: stone-and-metal contract audit room in a Final Dharma ration station, vertical cold skylight, sealed cabinets, pressure pipes and one red inspection lamp, no readable labels
Subject: adult Chinese woman whose cultivation preserves a thirty-six-to-forty apparent age; long diamond face, high narrow cheekbones, long straight nose, controlled thin lips, faint night-shift fatigue and a small brow scar; geometric jaw-length straight bob with one silver meridian-damaged streak and a low-profile ceramic ear calibrator; bone-white medical shoulder panel over a black high collar and long gray-violet structured coat, rust-red contract belt
Style/medium: top-tier painted 2D xianxia science-fantasy key art with disciplined vertical shape design, finished with credible 3D/PBR ceramic, felt, lacquer, glass, brass and waxed-paper materials; never a live-action still
Composition/framing: vertical three-quarter portrait, stable audit posture, one hand using an ivory probe to expose a red hidden contract thread while the other controls a black lacquer contract board; face in the upper 25-30 percent
Lighting/mood: cold institutional skylight with a single red diagnostic accent, precise, burdened and dependable
Color palette: bone white, ink black, gray violet, rust red and cold silver; no herb-green dominant scheme
Materials/textures: highland felt, matte ceramic, black lacquer, frosted glass, oxidized brass, waxed contract paper and believable hands
Constraints: stable adult identity without mechanical aging; short geometric hair; strong vertical physician silhouette; separable hair streak, coat hem, paper corner, red thread, instrument rings and cold dust; no text; no watermark; no logo
Avoid: resemblance to Chi Yaoqing; round-heart face; freckles and warm smile; hair bun; gray-green cross-collar medical robe; herbal pharmacy; glowing magic gyroscope; teenage healer; seductive doctor costume; generic cyberpunk bodysuit; plastic skin
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
Avoid: single glamorous sword heroine, cloned faces, courtroom cosplay, role-incoherent imperial styling, generic group-poster composition
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
Subject: same protagonist from Image 1 seated at the bedside, hood still hiding both eyes; identity remains readable through the hood angle, lower-face sliver, hands, black brocade cloak, deep-teal tassels and reincarnation jade; two incompatible shadows fall across the paper window, one matching him and one suggesting a future fatal stance
Style/medium: top-tier stylized xianxia game CG matching Image 1
Composition/framing: 3:2 landscape, medium-wide eye-level shot, protagonist on the lower central third, jade and two shadows readable at game scale, clean lower band for the game caption overlay
Lighting/mood: cold moonlight and one restrained warm pulse from the jade, intimate unease
Constraints: preserve hood-concealed eyes, proportions, silhouette, cloak, tassels and jade pendant; do not invent a face; no text; no watermark; no extra people; no horror distortion
Avoid: action pose, floating meditation, explosive magic, crushed darkness that erases the hood silhouette, generic bedroom glamour
```

## S1-02 男主分镜：镜湖无字门

目标路径：`res://art/scenes/story_mirror_lake_gate_v1.png`

```text
Use case: illustration-story
Asset type: cinematic landscape game storyboard
Input images: Image 1: approved male-protagonist identity anchor
Primary request: the same protagonist stands at Mirror Lake before a monumental blank ancient gate that is absent from every fate register
Scene/backdrop: mirror-still lake, broken jade stepping path, austere Chinese xianxia architecture suspended beyond the water, no written inscriptions
Subject: same protagonist from Image 1 seen in a clear three-quarter side/back view, hood still hiding both eyes, one hand near but not touching the jade pendant; identity is readable through hood, cloak, tassels and silhouette, while the blank gate reflects a slightly different version of his stance
Style/medium: top-tier stylized xianxia game CG matching Image 1 and the established world
Composition/framing: 3:2 landscape wide shot, protagonist large enough to retain identity, gate dominates upper center, clear lower band for caption overlay
Lighting/mood: predawn silver light, solemn threshold, restrained surrealism
Constraints: preserve the hooded identity and outfit; regional architectural influences are allowed when integrated into Mirror Lake rather than used as an unrelated landmark; gate contains no characters or symbols; no text; no watermark; no extra people
Avoid: tiny anonymous silhouette, generic portal ring, unrelated real-world religious landmark, architecture that overwhelms the established blank-gate design, neon sci-fi gate, excessive fog
```

## S1-03 双主角分镜：照雪初帖

目标路径：`res://art/scenes/story_zhaoxue_first_challenge_v1.png`

```text
Use case: illustration-story
Asset type: cinematic landscape game storyboard
Input images: Image 1: approved male-protagonist identity anchor; Image 2: approved Jiang Zhaoxue identity anchor
Primary request: Jiang Zhaoxue formally delivers her first challenge letter to the protagonist without hostility or ceremony
Scene/backdrop: spare mountain sword court at late winter dusk, training marks and wind-worn stone visible
Subject: same Jiang Zhaoxue from Image 2 extends a folded blank challenge letter, preserving her original refined face, long hair, silver-blue ornaments, jade-white and ice-blue sword dress and ornate sword; same protagonist from Image 1 receives it without drawing a weapon, hood still hiding both eyes; her face and his hooded silhouette are both identifiable and anatomically consistent
Style/medium: top-tier stylized xianxia game CG matching both anchors
Composition/framing: 3:2 landscape two-shot at eye level, balanced distance and equal visual agency, hands and letter clear, lower band reserved for caption overlay
Lighting/mood: cold dusk, mutual appraisal, controlled tension
Constraints: preserve both identities, outfits and proportions; letter has no visible writing; no text; no watermark; no romantic pose; no crowd
Avoid: duel already in progress, bridal framing, sexualized tension, one character dominating the frame, generic poster composition, identity or costume drift
```

## 验收顺序

1. 每个身份锚点至少比较两张候选，但只保留通过者进入运行时目录。
2. 先验收男主、江照雪和主反派的身份锚点，再以锚点作为分镜输入。男主不得用纯文字重新猜脸；江照雪不得离开旧图的美型、长发、银蓝饰物与白冰蓝服装语言。
3. 男主检查兜帽是否始终遮住双眼、兜帽与侧背轮廓是否匹配、流苏与轮回玉是否完整；其他角色检查五官、手指、武器握法、衣物结构、背景伪字、画面水印和不合理高光。
4. 将候选缩放到 104x154 与 515x360，检查露脸角色的面部或男主的兜帽识别区、人物轮廓和关键道具是否仍可读。
5. 对同一角色的所有成片并排检查身份契约。男主比较兜帽、侧背轮廓、织锦、流苏和玉佩；江照雪比较脸型、长发、银蓝饰物、白冰蓝剑裙与华丽长剑；对不同角色检查是否串脸。
6. 只有通过视觉检查、清单哈希校验、真实渲染截图和产品发布门禁的资产才能标记为 `approved`。

候选图先放在运行时目录之外，再执行自动预检和联系表生成：

```powershell
python -X utf8 tools/review_art_candidates.py --kind portrait `
  --reference godot/art/portraits/protagonist_hooded_close.jpg `
  candidate-a.png candidate-b.png
```

工具会在 `.tmp/art-candidate-review` 生成 JSON 指标报告、并排联系表，以及身份卡 `104x154`、宽屏事件舞台 `515x360`、窄屏事件舞台 `680x360` 等实际运行尺寸预览。江照雪评审时把 `--reference` 换为 `godot/art/portraits/qingyun_sword_heroine.jpg`。人物预览使用运行时相同的上偏 `focus_y=0.18` 裁切，不再用与游戏不一致的整图缩放。`--kind environment` 用于 4:3 常规场景，`--kind storyboard` 用于 3:2 关键剧情分镜。自动检查只负责淘汰尺寸、比例、压黑、过曝、模糊、低动态、异常透明度和候选间近重复问题；它不能判断兜帽、脸、美型或风格是否一致，最终必须逐张对照母版进行视觉检查。

通过视觉检查后，用同一份报告执行晋级。`--visual-approved` 表示审核者已逐项确认对应角色的 `visual_contract` 与母版一致，不只是认为图片“好看”。命令会校验报告中的 SHA-256、再次检查 PNG 与目标尺寸，并同步更新角色/分镜目录、事件与剧情绑定、`art_manifest.json`；没有显式 `--visual-approved` 不会写入运行时：

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
- 人脸或男主兜帽识别区不做局部扭曲，不做明显整图上下浮动，不让衣发摆动改变角色轮廓。
- 全幅分镜使用 `portrait_mode: scene_only`，避免场景里已有角色时再叠一张重复立绘。
- 若未来取得分层源文件，只对发梢、衣摆、流苏、粒子和局部光源做独立动画，脸、兜帽、手和身份饰物保持稳定。
