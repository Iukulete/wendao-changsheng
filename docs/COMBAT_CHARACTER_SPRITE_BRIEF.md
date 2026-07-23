# Combat Character Sprite Brief

## Product Direction

Combat characters use original full-body anime sprites with a compact,
appealing silhouette. The target feeling is light, readable, and expressive:
slightly enlarged head and hands, narrow full-body proportions, clear facial
direction, an oversized weapon silhouette, and restrained supernatural light.
This direction is inspired by polished mobile RPG battle cutouts, but no
existing character, costume, pose, weapon, halo, or line work may be copied.

Programmatic pixel figures are a development fallback only. They must never be
presented as final character art in a product release.

## Deliverables Per Named Character

- One canonical transparent PNG, 1536 x 2048 or larger, full body visible.
- One neutral three-quarter battle stance facing inward.
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
