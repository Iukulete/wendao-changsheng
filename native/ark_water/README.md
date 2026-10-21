# Optional native water batches

C++17 GDExtension using the official Godot 4.7 public C ABI; not an engine fork.
No godot-cpp, network fetch, SDK install, or package-manager dependency. The build
extracts MIT-licensed interface headers and ABI JSON from the installed pinned
Godot 4.7.1 standard binary, validates opaque sizes/method hashes and builds only
outside `res://`. Our sources retain the project AGPL-3.0 code license (see LICENSE); generated
Godot ABI headers retain their separate MIT attribution.

```sh
python native/ark_water/build.py --out .tmp/recovery-native/build
```

Use the printed descriptor path explicitly with `ArkAnalyticWater.configure_backend`.
Backend names are `gdscript`, `native_single`, `native_multi`; the default remains
GDScript. No automatic native extension import or missing-library startup errors.
Delete the output directory and select GDScript to remove the native dependency.
The parent gameplay adapter owns opt-in integration and fallback policy.

Windows recipe exists but is **not compiled or runtime verified**. From an MSVC
Developer Shell with Python and the exact official Windows Godot 4.7.1 binary:

```powershell
python native/ark_water/build.py --godot D:\Tools\Godot_v4.7.1-stable_win64.exe --cxx cl --out .tmp/native-win
```

The descriptor names only the platform actually built. Compilation uses unique
same-filesystem staging, then atomic replacement, never truncating a loaded
library. POSIX preserves existing mappings; Windows locked-DLL replacement can
fail, leaving the old DLL intact. Stop the old process or use another output
directory. Descriptor/manifest replacement is individually atomic; staging is
cleaned on failure. Use distinct output directories for concurrent builds. This
is not hot reloading; restart the game to load a new binary.

## Methods and data layout

Instantiate `ArkWaterBatch` through ClassDB after explicitly loading its descriptor.
`compute(input: PackedFloat64Array, mode: int)` implements model 1:

- Input: `[time,delta,mean, x,y,z,draft,velocity_y, ...]`.
- Output: `[new_time,steps, y,velocity_y, ...]`.
- Model 1 height: `mean + .035*sin(.21*x+.42*t)*cos(.16*z-.31*t)
  + .018*sin(.11*(x+z)+.23*t)`.

`compute_gerstner(input, mode)` implements model 2:

- Input header17: `[time,delta,mean, A.dx,A.dz,A.k,A.amp,A.Q,A.phase,A.omega,
  B.dx,B.dz,B.k,B.amp,B.Q,B.phase,B.omega]`, followed by the same five-scalar floats.
- Output: `[new_time,steps,new_phase_A,new_phase_B, y,velocity_y,...]`.
- Wave direction squared norm within1e-6 of1; k in(0,2], amp[0,.25], Q[0,10],
  phase[0,TAU), abs(omega)<=5 and sum(abs(Q*amp*k))<=.5 (no foldover).
- Inverse horizontal Gerstner mapping uses double scalar Newton coordinates,
  eight updates maximum, residual early-stop1e-9/final acceptance1e-5. Each
  object's query is at its actual world X/Z, not undisplaced material coordinates.

Both modes use the reconstructed authoritative damped heave:
`v=clamp(v+((height+draft-y)*9-v*6)*dt,-.35,.35); y=float32(y+v*dt)`.
Substeps use `while remaining>1e-9: dt=min(1/60,remaining)`; the auxiliary time
wraps at TAU*100 each actual substep. Gerstner phases independently wrap positively
at TAU including negative angular speed. Delta zero performs zero steps.

All input must be finite; delta[0,10], time>=0, abs(mean/y/draft)<=10000,
abs(x/z)<=1e6, abs(velocity)<=.35, at most10,000 awake objects. Invalid input or
failed inverse solve returns an empty array, never a partial batch. The adapter
filters sleeping floats and performs all persistent state/scene updates.

## Threads and limitations

Mode0 is native single-thread; mode1 lazily creates exactly two persistent workers
per instance. Input is copied on the main thread into immutable standard C++
memory. Workers touch no Godot APIs, Nodes, resources, physics or save data, and
write disjoint output spans. There is one bounded in-flight batch and no backlog.
The main thread waits at the commit boundary; this is parallel computation, not
asynchronous gameplay. Worker generation guards wakeups; adapter session/generation
checks guard committing results. Snapshots and cancellation occur between complete
batches. Destructor signals stop and joins both workers. Allocation/thread errors
are caught at the ABI and return empty for fallback; the ABI is main-thread only.

Small batches can be slower with workers. Measure adapter packing/dispatch/wait/
unpacking, not just a C++ inner loop. This does not imply full fluid physics,
multithreaded scene access, or demonstrated Windows/GPU performance.

## Reproducible end-to-end benchmark (Linux headless)

The source harness is retained alongside the implementation; results stay ignored
under `.tmp`. Wait for all other game/test/preview processes to finish, then:

```sh
python native/ark_water/benchmark.py --quiet-approved \
  --build-dir .tmp/recovery-native/build --out .tmp/native-benchmark
```

Without `--quiet-approved` it refuses to run. It freezes and hashes the exact
production adapter, native library/C++ and harness; verifies the build manifest;
then measures 48 rows: models1/2 × awake floats1/2/256/2048 × delta1/60 or.25 ×
GDScript/native-single/native-two-worker. Each backend starts from identical state
and runs12 warmups followed by30 measured production `advance` calls, including
validation, packing, worker dispatch/wait and state commit. Execution order rotates.
Raw samples and terminal parity checks are in `results.json`; errors, incomplete
rows, failed parity or changed sources fail the run. Nearest-rank p99 is simply
max at30 samples, not strong tail characterization. RSS/HWM are cumulative whole
process memory, not isolated backend allocations. These are numeric water batches,
not rendered game FPS, whole gameplay frame budgets or Windows measurements.
