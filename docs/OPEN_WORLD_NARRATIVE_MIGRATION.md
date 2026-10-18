# Open-world home-life direction: narrative migration policy

## Preserve the authored writing

The six chronicle files under `godot/data/chronicles/` remain the authoritative source. The current repository records six volumes, 24 chapters per volume, 144 chapters total, 432 choices and 945,377 Chinese characters. Do not bulk-rewrite, delete, or convert this corpus into cards. Keep chapter IDs, route IDs, authored choice text, consequences, and existing editorial review records intact unless a later, chapter-specific review approves a change.

The chronicle files are already data-driven and contain summaries, era identity, chapter prose, route variants, three authored choices per chapter, state deltas, and inheritance material. Preserve that structure so existing narrative and save logic continue to work.

## Separate world freedom from story causality

- The world map is open from the start. Region danger is a forecast, not a level requirement; a player may enter a deadly area immediately.
- Individual authored story arcs may retain causal prerequisites. A clue, rescue, or relationship event can explain why a chapter appears, but it must not close the map or prevent unrelated exploration.
- Discoveries, residents, relationships, location history, and time can surface chapters naturally. Story chapters remain authored scenes with real choices and state consequences; they are not generic random text or forced daily chores.
- The ark/home loop owns daily material gathering, construction, shelter, meals, rest, and resident routines. Long-form chronicles should enrich that loop without turning every chapter into a building unlock.

## Content destinations

1. **Keep as authored chronicle** when a chapter has strong causality, distinctive characters, and consequential choices. Surface it as a world story/quest arc, preserving its existing route and consequence data.
2. **Reframe for the ark** only when a scene can become a resident memory, shipboard conversation, refuge request, communal disagreement, or response to a disaster without contradicting its original facts. Keep the original chapter and add a separately reviewed presentation/context layer; never silently overwrite canon.
3. **Archive for a later era or expedition** when the setting, cast, or scale does not belong in the opening survival phase. This is deferred content, not discarded content.
4. **Retire only after explicit review** if text is redundant, contradictory, or no longer publishable. Record the chapter ID, reason, and replacement/removal decision.

## Migration workflow

For each chapter or NPC scene, record: stable ID; era/location; required prior facts; characters present; current choice/consequence hooks; how it can be discovered in the open world; whether it should affect the ark/residents; and disposition (keep, reframe, defer, review). Review one arc at a time. Preserve the JSON source and current review ledger; perform schema/continuity/readability validation after any approved edit.

The first playable slice should use a small set of bespoke resident scenes and ambient interactions to prove the home-life loop. It should not rewrite all 144 chapters before players can walk aboard, meet someone, share a meal, and see the home improve.
