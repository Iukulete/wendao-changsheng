# Ark recovery checkpoints

This development branch reconstructs intended functionality after loss of an
unpublished workspace. It is not a byte-identical restoration, and historical
test outcomes do not validate newly reconstructed code.

## Starting point

- Baseline: `b28069e627e2bb90464f48923791b7024f00b19e`.
- Fresh source checks: 36 Python tests, migration boundary, and source archive
  integrity passed. The 24 original regressions also passed freshly under the
  pinned official Godot 4.7.1 engine before reconstruction.
- Existing schema 33 saves and retired source assets must remain compatible and
  preserved; retired runtime entry points must not be reactivated.

## Ordered gates

1. Fresh runtime baseline; resource ownership, construction/gathering lifecycle,
   durable facts, schema 34 bundle validation and historical compatibility.
2. Navigation and water boundaries with actual gameplay regression coverage.
3. Optional native single/worker backends, parity, lifecycle and honest costs.
4. Gerstner displacement, inverse queries, legacy water policy and real rendering.
5. Subsequent gameplay and presentation recovery, each with its own tests.

The entire restoration is one major version. No intermediate checkpoints are
published; one final source checkpoint follows all recovery gates and review.
Caches, saves, binaries and private inputs are excluded. Integration into the
stability branch waits for the complete recovery gates and review. Vessel hull
semantics remain unchanged until their intended design is resolved.
