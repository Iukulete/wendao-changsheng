# Combat Character Sprite Brief

## Product Direction

Combat characters may use original, story-bound full-body pixel animation
sprites as a first-class battle presentation. The target feeling is readable,
expressive, and compact: a stable silhouette, clear facing direction,
recognizable costume anchors, readable weapon geometry, and restrained
supernatural light. Portraits and story scenes may remain high-resolution;
battle sprites translate the same identity into a deliberate pixel language.
This direction is inspired by polished 2D RPG battle animation, but no existing
character, costume, pose, weapon, halo, or line work may be copied.

Programmatic pixel figures remain a development fallback only. Final pixel
sprites must be authored or generated as identity-specific raster assets and
reviewed against the character's narrative visual contract.

## Unified Portrait Style Bible (v1.0)

The two user-provided anime game illustrations are global style references
only. They establish the rendering language—clean contour hierarchy, polished
adult anime faces, large-to-small hair masses, layered costume construction,
dynamic contrapposto, controlled material highlights, and readable action
silhouettes. They do not authorize copying the reference character's face,
hair, costume, weapon, ornaments, or exact composition.

The production order is deliberately portrait-first:

1. Build or upload the character's story identity card and reference portrait.
2. Generate a new high-resolution full-body portrait in the shared style.
3. Pass the identity gate: age, face, hair, body type, costume, weapon,
   palette, and five non-negotiable identity anchors.
4. Lock neutral, guard, and attack poses from that accepted identity.
5. Derive the transparent pixel atlas and run the animation gate.

Adult characters default to 7.5–8 heads tall with complete feet, clear
shoulder/waist/hip structure, and long readable legs. Adult women may have a
naturally fuller bust and a visible waist-to-hip rhythm when the story supports
it, while remaining tastefully clothed and anatomically grounded. Children,
teenagers, giant adults, and monsters use different skeletons and silhouettes;
they must not be made by scaling the same adult body.

The shared portrait language uses richer color than the battle atlas, but the
identity palette still wins over the style reference. Jiang Zhaoxue has a
strict cold palette: blue-black hair, silver-blue ornaments, cyan forehead
mark, jade white/ice blue sword dress, silver-blue sword, and no red, crimson,
burgundy, pink, orange, or warm-gold decoration. Other characters receive
their own allowed and forbidden colors from their identity cards.

Portrait masters should target 2048 x 3072 (1536 x 2048 minimum) with a clean
character PNG and optional character/FX/background layers. The reference
images remain user-provided style inputs and are not shipped as runtime art.

## Deliverables Per Named Character

- One canonical transparent PNG, 1536 x 2048 or larger, full body visible.
- One neutral three-quarter battle stance facing inward.
- One or more transparent animation atlases. There is no fixed frame-count
  ceiling: use the minimum readable count for idle and hit reactions, and add
  frames for complex sword techniques, spells, ultimates, or signature scenes
  when the motion needs them. A named character may use 16, 64, or 128 frames
  split across clips rather than one oversized sheet.
- Separate transparent layers for body, front arm/weapon, back equipment, and
  optional aura. Layer registration and canvas size must be identical.
- Three expression crops derived from the same identity anchor: neutral,
  determined, and wounded. Do not regenerate a different face for each crop.
- Weapon geometry must match the character loadout and remain identifiable at
  220 px display height.
- No text, watermark, signature, opaque background, cropped feet, or fake UI.

## Animation Contract

The runtime applies restrained motion to the supplied layers:

- idle: 2-4 px vertical float, 0.8-1.4 degree sway, subtle breathing scale;
- anticipation: body leans 3-5 degrees and weapon pulls back;
- attack: 80-140 ms directional travel plus weapon trail and impact pause;
- guard: short backward compression, shield/aura flare, no repeated shaking;
- hit: 6-12 px displacement and 60-90 ms color flash;
- defeat: controlled desaturation and downward settle, no ragdoll comedy.

The source art must remain still and clean. Motion, trails, particles, hit stop,
and camera response are authored in Godot so the same timing follows combat
events and accessibility settings.

For pixel animation atlases, each clip owns its own frame sequence, FPS, loop
flag, and optional technique mapping in
`res://data/combat_sprite_animations_v1.json`. Combat events select a specific
technique clip when one is registered, then fall back to the semantic
`attack`, `guard`, `spell`, `hit`, or `idle` clips. Effects remain reusable
Godot layers rather than being required in every character frame.

## Composition And Readability

- Player faces right; enemies face left. Both keep the face unobstructed.
- The silhouette must read against dark purple, ink black, warm paper, and
  muted teal environments without relying on bloom.
- Use a 2-4 px light outer keyline at 1080p; avoid heavy black sticker outlines.
- Keep the visual center near the upper torso so floating motion does not make
  the character appear detached from the combat floor.
- Bosses gain scale, framing, and environmental effects. Do not reuse the same
  body with only a palette swap for named antagonists.

## Integration Paths

Final character sprites go under `res://art/combat/characters/<character_id>/`.
Weapon layers go under `res://art/combat/weapons/`; reusable aura and impact
textures go under `res://art/combat/effects/`. Every asset must be registered in
the character art catalog with creator, source, license, identity anchor,
display scale, pivot, and layer paths. Missing or unapproved named-character
art falls back to text/event presentation instead of showing an unrelated
portrait or a duplicated character image.

The runtime battle payload accepts the following optional contract for each
side under `player_art` or `enemy_art`:

```json
{
  "body_path": "res://art/combat/characters/protagonist/battle_body.png",
  "back_path": "res://art/combat/characters/protagonist/battle_back.png",
  "weapon_path": "res://art/combat/characters/protagonist/battle_weapon.png",
  "aura_path": "res://art/combat/characters/protagonist/battle_aura.png",
  "display_height": 226,
  "pivot": [0.5, 0.96]
}
```

All paths are restricted to `res://art/combat/`. When only the canonical body
is supplied, the default path is
`res://art/combat/characters/<character_id>/battle_body.png`.

## Acceptance Gate

- Identity is stable across portrait, event scene, and battle sprite.
- No named character shares a face, body, costume, or weapon with another.
- At 1280 x 720 and 2560 x 1440, face, weapon, and pose remain readable.
- Idle, attack, guard, hit, and defeat motion produce visible pixel changes and
  leave no orphaned nodes after combat.
- Art provenance and commercial redistribution rights are recorded before the
  asset can be marked approved.
