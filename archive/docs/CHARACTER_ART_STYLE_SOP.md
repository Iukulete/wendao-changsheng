# Character Art Style Bible and Production SOP

This SOP records the web-side art-direction review for the two user-provided
anime game illustrations. The references define a rendering language, not a
character to copy.

## Three separate contracts

1. Global style: clean contour hierarchy, polished adult anime faces, large-to-
   small hair masses, layered clothing, dynamic contrapposto, controlled
   material highlights, and readable action silhouettes.
2. Story identity: age, face, body type, hair, clothing, colors, weapon,
   personality, and at least five non-negotiable anchors for each character.
3. Runtime asset: transparent canvas, facing direction, frame layout, timing,
   pivot, display scale, and Godot integration.

The global style may not rewrite story identity. A pixel atlas may not invent a
new face, costume, weapon, or body type merely to make an action pose easier.

## Required order

`identity card -> high-resolution portrait -> identity gate -> neutral/guard/attack poses -> pixel atlas -> runtime gate`

Do not ask one generation to solve identity, portrait rendering, pixelation,
16 actions, effects, and engine import at the same time.

### Portrait identity gate

Before deriving a sprite, verify:

- age, gender presentation, face shape, eye shape, hair silhouette, body type;
- main clothing layers, unique ornaments, weapon and palette;
- five identity anchors remain visible in a silhouette or small thumbnail;
- the character is distinct from every already-approved character;
- full feet, hands, weapon, and adult proportions are present;
- the portrait uses the shared rendering language without copying the reference
  character's exact identity or composition.

Portrait masters target 2048 x 3072, with 1536 x 2048 as the minimum. Keep a
clean transparent character PNG and optional character/FX/background layers.
Reference images supplied by the user are style inputs only and are not
runtime assets.

## Body and silhouette families

- Elegant adult woman: 7.5–8 heads, long legs, clear waist/hip rhythm.
- Practical adult woman: still adult and long-limbed, but stronger shoulder,
  lower center of gravity, wider stance, and functional clothing.
- Thin adult man: 7.5–8 heads, narrower hips, long ribcage, restrained motion.
- Giant adult: broad skeleton, thick torso, large hands/forearms, weight-bearing
  legs; never an adult body scaled by 130%.
- Teen: approximately 6.5–7 heads, lighter frame and less mature proportions.
- Child: approximately 5–6 heads, narrow shoulders, short limbs; never reuse
  an adult woman's chest/waist template.
- Monster: non-human anatomy is allowed, but edge language, value grouping,
  material treatment, and pixel density remain in the same world.

Adult women may have a naturally fuller bust and an attractive waistline when
the story supports it. Use two deliberate adult-design tiers instead of forcing
the whole cast into one level of restraint:

- Story-canonical/ restrained: Jiang Zhaoxue, the protagonist's allies, and
  characters whose appeal is dignity or discipline use practical layered
  clothing and controlled exposure.
- Adult fanservice: clearly adult villains and selected side characters may
  use deep V or asymmetrical open fronts, large exposed upper-chest/shoulder
  lines, open backs or side waists, high slits, close-fitting straps, and
  deliberate pose/leg-line emphasis as a selling point. Keep the materials
  opaque and the presentation within a non-explicit commercial-game frame;
  do not use sexual acts, explicit genital detail, or childlike proportions as
  the appeal.

The fanservice tier is a story and market-positioning choice, not a requirement
for every adult woman. Keep each costume grounded by gravity and occupation,
and make sure the character's identity anchors remain readable. Children
always use an independent child proportion and costume contract and never
inherit an adult woman's chest or waist template.

## Jiang Zhaoxue lock

Jiang is an adult sword cultivator with blue-black long hair/high ponytail,
silver-blue ornaments, cyan forehead mark, jade-white/ice-blue layered sword
dress, and a slim silver-blue sword. Her approved palette is cold-only:
blue-black, deep navy, cold gray, jade white, silver-blue, ice blue, and muted
cyan. No red, crimson, burgundy, pink, orange, warm red, or warm-gold
decoration is allowed. Her portrait and pixel atlas must preserve the same
face, mature proportion, long legs, and weapon.

## Reusable web prompt skeleton

```text
Use the attached portrait as the sole story-identity anchor. Use the attached
global references only for rendering language: clean anime game linework,
layered costume construction, mature face design, dynamic contrapposto,
controlled highlights, and readable action silhouette. Do not copy the
reference character's face, costume, weapon, ornaments, or composition.

Generate [CHARACTER] as a full-body adult/teen/child/giant/monster portrait.
Lock these identity anchors: [five or more anchors]. Body family: [family].
Allowed palette: [colors]. Forbidden drift: [colors, faces, clothes, props].
Show [pose and personality]. Keep hands, feet, weapon, and silhouette visible.
Output a high-resolution game character portrait, no text, watermark, UI, or
unrequested background treatment.
```

Only after the portrait passes the identity gate, use a second prompt for the
pixel atlas. Request a 4 x 4 sheet with 16 equal cells as the default: row 1
idle, row 2 charge/draw/guard, row 3 four-hit attack chain, row 4 spell/dash/
hit/recover. Keep the frame count open for techniques that genuinely need 32,
64, or 128 frames.

## Pixel saturation audit update (web review)

The web-side review of Jiang Zhaoxue's first atlas found that the problem was
not simply "too much blue": saturated blue clothing, blue-tinted jade-white
cloth, bright-blue hair and armor edges, oversized sword arcs, and low-alpha
blue haze were all competing at once. For the low-saturation game-pixel
contract, use these measurable gates:

- body-pixel saturation median: 22%–32%; keep most pixels below 45%;
- pixels above 55% saturation: at most 8%–12% of character-plus-effect area;
- use a 26–28 color character palette plus transparency, rather than many
  near-identical blue gradients;
- jade-white cloth must read as white first, silver armor as gray first, and
  the highest-saturation color may appear only in a small spell core;
- idle/guard frames have almost no glow; attack uses a short thin gray-cyan
  trail; spell effects use jade-white, silver-gray, and muted cyan rather than
  large pure-blue shapes;
- opaque body pixels use alpha 255; effects may use only a few fixed alpha
  levels (for example 96/160/224/255); all gaps and non-requested haze are
  alpha 0.

For Jiang specifically, the web review's practical ranges are: deep navy
S20%–35%, hair highlights S22%–38%, ice-blue cloth S18%–32%, jade white
S3%–12%, silver armor S5%–18%, and the small spell peak S35%–55%. These are
  art-direction gates, not a substitute for visual identity review.

## Runtime acceptance

Confirm the portrait, pixel atlas, and story event all identify the same person;
check at 1280 x 720 and 2560 x 1440; verify that the atlas is true RGBA with
transparent gaps and no gradients, fog, ground glow, grid, text, watermark, or
cropped feet; then register dimensions, hash, source category, and rights
review in `godot/art/art_manifest.json`.
