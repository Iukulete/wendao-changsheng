# 0.1.003 navigation experiment backup — NOT a release

This branch preserves the isolated 2026-10-24 route experiment against
`70302e8ef49dd29ce91ef37ddca416fc985e3d51`. It does not replace the stable
`codex/ark-mobile-home-loop` branch. Game version remains **0.1.003**.

## Changes

- Stable world-grid route planning with exact endpoint connectors and native
  root-segment checks plus authored rock/rail lateral-clearance checks.
- Opt-in single-edge-per-update movement, avoiding shortcut chords at corners.
- Isolated route, save/Continue, proxy-load and native-observation probes.
- No HUD, resource-refresh policy, save schema, asset or model changes.

## Archived validation of these exact nine code/test files

Godot 4.7.1 stable, official build a13da4feb:

- 355 controlled movement updates, eight actual menu/Continue scene transitions,
  two ordinary resource deliveries, zero task abort calls.
- One controlled native F5, return-to-menu and Continue sequence preserved the
  task, position and economy before the first resumed simulation frame.
- Original 4/12/24 proxy workloads completed their delivery assertions.

These are narrow experiments, not full production or natural-play acceptance.
The earlier 6,182-check movement proof is separate from live scene validation.

## Known blockers — do not treat this branch as release-ready

- NPC water-walking/floating is still visibly present. Full-body collision,
  ground support, animation clearance and dynamic crowd avoidance are unproven.
- Synchronous planning spikes remain: final archived 24-proxy p95 19.630 ms,
  maximum 151.987 ms. These proxies are not 24 fully rendered residents.
- The production runtime boundary allowlist has not been expanded for the two
  experimental modules. Fresh publication-time Python tests report 74 run,
  one failure and one error due to these unregistered runtime modules.
  The allowlist was not weakened just to publish a backup.
- Full candidate Godot regression, packed-resource gate, legacy-save migration,
  Windows export and hardware frame-rate acceptance have NOT been completed.
- Native capture probe output is guarded to the original isolated cloud
  experiment directory; it is not a portable screenshot/export workflow.
- Existing GitHub Actions push filters do not include this backup branch.
  An absent workflow run is not a CI pass.

## Publication-time checks

The archived ZIP checksum, all 63 payload checksums and all nine restored
code/test file checksums were verified before publication. The patch applied
to the exact stable commit and tree without conflict. The seven new files are
included explicitly; no saves, caches, binaries, screenshots, source models,
private handoff material or raw evidence archive are added by this commit.
The exact archived proxy test retains one extra blank line at EOF, reported
by Git's whitespace check; it was not silently edited during restoration.

Only the available Python suite was rerun during publication; the pinned
Godot executable was not present in the reset environment, so the archived
engine results above are not described as a new run.

Next engineering gate: reduce planning spikes and resolve traversal/support
presentation before considering integration, then register reviewed modules
and run the complete production verification workflow.
