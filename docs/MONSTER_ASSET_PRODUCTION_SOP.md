# Monster asset production SOP

## Production model

The project uses a character-centered pipeline for named story characters and a family-centered pipeline for monsters:

`family master -> variant identity card -> combat template -> batch technical QA -> in-game QA`

Ordinary monsters do not require a separate 1024×1536 narrative portrait. Elite monsters may add one when they appear in a story shot. Bosses require a full concept portrait, an identity card, a Combat Core sheet, and separate Skill/Phase sheets.

## Identity card

Every monster keeps at least three silhouette anchors: head or attack-organ outline, body/back structure, and limb/tail/weapon termination. The card also fixes the era, family, body archetype, role, tier, palette, unique texture, and forbidden features.

Within one family, share roughly 70% of the structure and vary roughly 30%. Change at least three silhouette fields and two material fields for a variant. Bosses may reverse that ratio.

## Body archetypes

Use the archetype in `godot/data/monster_asset_queue_v1.json` to fix leg count, body length, head scale, pivot behavior, and combat template before prompting the web image generator. Children and giants use separate proportion contracts; never create them by scaling an adult sprite.

## Combat templates

- Humanoid melee: Idle / Guard / Attack / Hit-Recover.
- Humanoid ranged: Idle / Aim / Fire / Hit-Recover.
- Four-legged: Idle / Prepare / Attack / Hit-Recover.
- Caster or floating: Idle / Channel / Cast / Recover.
- Boss: Combat Core plus Skill A, Skill B, Phase Change, and Death sheets.

The standard cell remains 256×384 and the atlas remains 1024×1536 when the template fits. Giant and boss sheets may use additional rows, but every frame still needs a stable pivot, explicit alpha, and safe bounds.

## Web consultation checkpoint (2026-08)

Before generating a new family or boss, ask the web-side art advisor to review the identity card and prompt. Record its hard anchors, frame allocation, and failure corrections in the queue or this SOP, then generate the narrative portrait first. Do not derive combat pixels from an unapproved portrait.

For a HUM_L boss caster with several persistent props, the recommended first Combat Core is a 4×6, 24-frame sheet at 256×384 per cell. A practical allocation is:

- 1–4 Idle: breath, prop sway, back-structure vibration, weapon lowered.
- 5–8 Charge: open the book, raise the weapon, expand bindings, unlock the back structure.
- 9–14 Attack: wind-up, impact, line/weapon sweep, recoil and recovery.
- 15–18 Spell: prop-driven skill, binding/marking, and effect release.
- 19–22 Hit: stagger, prop scatter, guard-the-core response, recovery.
- 23–24 Phase: phase-change reveal and stable phase stance.

The first hard gate is that the identity props remain present and readable in every relevant frame. For the fate registrar specifically, the oversized jade brush, tall back scroll, and seal ribbons are mandatory; if any become a normal brush, small book, backpack, or disappear, regenerate from the portrait anchor.

Batch order for a large roster: one Boss, then remaining elite/boss HUM variants, then ordinary HUM templates, then QUAD variants, then giant bodies, then FLOAT/AMORPH and special-proportion children. Each batch must pass silhouette, archetype, prop presence, alpha, frame continuity, and Godot slicing before the next family is expanded.

For HUM_H heavy humanoids, use a separate proportion contract rather than scaling HUM_L: approximately 5.5–6.5 heads high, small head, shoulder width around 1.8–2× a normal male, heavy upper torso, low center of gravity, and legs still long enough to avoid a Q版 dwarf silhouette. The hard silhouette test at 128px height must still show the shoulder module, back machinery, primary weapon, and feet. A heavy Boss with hammer/boiler/shoulder systems uses the same 24-frame row layout as the caster Boss, with a dedicated defense row and an overload/phase row.

## Acceptance gates

Hard gates are silhouette, body archetype, attack organ or weapon, frame bounds, alpha, and in-game readability. Palette micro-tuning and secondary particles are soft gates. A failed hard gate returns to the family/variant prompt; it is not repaired by stacking more effects on the same image.

Before runtime review, run both inventory checks from the repository root:

```text
python tools/verify_combat_sprite_assets.py
python tools/verify_godot_art.py
```

The combat-sprite check validates the actual PNG grid, RGBA alpha, frame indexes,
clip timing, and target-to-animation references. A web-generated sheet is not
ready for Godot just because it looks correct in the browser; it must pass these
checks and then be exercised in the combat scene.
