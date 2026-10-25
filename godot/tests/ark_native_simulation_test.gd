extends SceneTree

const Port = preload("res://scripts/adapters/ark_household_simulation.gd")
const Reference = preload("res://scripts/modules/residents/ark_household_work.gd")
class BrokenKernel extends RefCounted:
	var reply := PackedFloat64Array()
	func dispatch(_packet: PackedFloat64Array) -> PackedFloat64Array: return reply

func _initialize() -> void:
	_run.call_deferred()

func _same(a: Dictionary, b: Dictionary) -> bool:
	for key in a:
		if key in ["prepare_elapsed", "repair_elapsed"]:
			if absf(a[key] - b[key]) > 0.000000000001: return false
		elif a[key] != b[key]: return false
	return true

func _run() -> void:
	var missing = Port.new("auto", ProjectSettings.globalize_path("res://../.local/does-not-exist.gdextension"))
	assert(missing.backend_status().backend == "reference")
	missing.enabled = true
	assert(missing.begin("raft_edge") and missing.snapshot().phase == "prepare")
	var native = Port.new()
	assert(native.backend_status().backend == "native-flecs", "Build native/ark_simulation/build.py before the full gate; native validation must not silently skip")
	var reference = Reference.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 704137
	for iteration in range(3000):
		var op := rng.randi_range(0, 6)
		var actual: Variant
		var expected: Variant
		match op:
			0:
				var allow := rng.randi_range(0, 1) == 1
				native.enabled = allow
				reference.enabled = allow
			1:
				var part: String = ["", "raft_edge", "shelter_roof", "unknown"][rng.randi_range(0, 3)]
				actual = native.begin(part)
				expected = reference.begin(part)
			2:
				var dt: float = [0.0, -1.0, NAN, INF, 0.1, 10000.0, 0.05][rng.randi_range(0, 6)]
				actual = native.advance(dt)
				expected = reference.advance(dt)
			3:
				actual = native.finish()
				expected = reference.finish()
			4:
				native.cancel()
				reference.cancel()
			5:
				var saved: Dictionary = reference.snapshot()
				var change: Dictionary = [{"phase":"bad"}, {"enabled":1}, {"completed":1.5}, {"prepare_elapsed":4}, {"repair_elapsed":NAN}, {"extra":0}][rng.randi_range(0, 5)]
				saved.merge(change, true)
				var before: Dictionary = native.snapshot()
				actual = native.restore(saved)
				expected = reference.restore(saved)
				assert(not actual and _same(before, native.snapshot()))
			6:
				var saved: Dictionary = reference.snapshot()
				saved.enabled = true
				saved.phase = "repair"
				saved.part = "shelter_roof"
				saved.prepare_elapsed = 3.0
				saved.repair_elapsed = float(rng.randi_range(0, 3))
				actual = native.restore(saved)
				expected = reference.restore(saved)
		assert(actual == expected and _same(native.snapshot(), reference.snapshot()), "native/reference divergence at %d: %s / %s" % [iteration, native.snapshot(), reference.snapshot()])
	# Complete two precise jobs rather than depending on random coverage.
	for part in ["raft_edge", "shelter_roof"]:
		native.cancel()
		reference.cancel()
		native.enabled = true
		reference.enabled = true
		assert(native.begin(part) == reference.begin(part))
		for tick in range(61):
			assert(native.advance(0.1) == reference.advance(0.1))
			assert(_same(native.snapshot(), reference.snapshot()))
		assert(native.ready() and native.finish() == reference.finish())
		assert(native.last_part == part and native.operation_id() == reference.operation_id())
	# MAX_COMPLETIONS is bounded on both the restore and begin command paths.
	var maximum: Dictionary = reference.snapshot()
	maximum.completed = Reference.MAX_COMPLETIONS
	assert(native.restore(maximum) and reference.restore(maximum))
	assert(not native.begin("raft_edge") and not reference.begin("raft_edge"))
	maximum.completed += 1
	assert(not native.restore(maximum))
	# Safe, explicit prepare-phase load with fractional progress.
	var preparing := {"enabled":true,"phase":"prepare","part":"raft_edge","prepare_elapsed":1.25,"repair_elapsed":0.0,"completed":0,"last_part":""}
	assert(native.restore(preparing) and reference.restore(preparing))
	assert(_same(native.snapshot(), reference.snapshot()) and native.matches_economy({}))
	assert(not native.matches_economy({"home_work:repair:1":true}))
	for reply in [PackedFloat64Array(), PackedFloat64Array([1,1,0,1,999,1,0,0,0,0]), PackedFloat64Array([1,1,0,1,2,1,3,NAN,0,0]), PackedFloat64Array([1,1,0,1,0,0,0,0,0.5,0])]:
		var broken = Port.new("reference")
		assert(broken.restore(preparing))
		var stub := BrokenKernel.new()
		stub.reply = reply
		broken._kernel = stub
		var unchanged: Dictionary = broken.snapshot()
		assert(not broken.advance(0.1) and not broken.ready() and not broken.active())
		assert(not broken.backend_status().healthy and broken.snapshot() == unchanged)
		assert(not broken.finish(), "protocol errors must not reach the economy completion path")
	# Detached native world: test stable IDs and atomic, gated batch submission.
	var kernel: RefCounted = ClassDB.instantiate("ArkSimulationKernel")
	var population := 1000
	var packet := PackedFloat64Array([1, 7, 0, 0.05])
	for id in range(1, population + 1):
		assert(kernel.call("dispatch", PackedFloat64Array([1, 0, id])).size() == 10)
		assert(kernel.call("dispatch", PackedFloat64Array([1, 1, id, 1]))[1] == 1)
		assert(kernel.call("dispatch", PackedFloat64Array([1, 2, id, 1]))[1] == 1)
		packet.append(id)
		packet.append(1 if id % 2 == 0 else 0)
	var before: PackedFloat64Array = kernel.call("dispatch", PackedFloat64Array([1, 0, 2]))
	for invalid in [PackedFloat64Array(), PackedFloat64Array([1,7,0,0.1,2,1,2,1]), PackedFloat64Array([1,7,0,0.1,2,1,1001,1]), PackedFloat64Array([1,7,0,NAN,2,1]), PackedFloat64Array([1,6,2,1,2,1,3,4,0,0])]:
		var rejected: PackedFloat64Array = kernel.call("dispatch", invalid)
		assert(rejected.is_empty() or rejected[1] == 0)
		assert(kernel.call("dispatch", PackedFloat64Array([1, 0, 2])) == before)
	var started := Time.get_ticks_usec()
	for tick in range(120):
		var result: PackedFloat64Array = kernel.call("dispatch", packet)
		assert(result.size() == 3 + population * 9 and result[2] == population)
	var elapsed := Time.get_ticks_usec() - started
	for id in range(1, population + 1):
		var state: PackedFloat64Array = kernel.call("dispatch", PackedFloat64Array([1, 0, id]))
		assert(state[4] == (2 if id % 2 == 0 else 1))
		assert(state[6] == (3 if id % 2 == 0 else 0))
		assert(state[7] >= 2.9 if id % 2 == 0 else state[7] == 0)
	print("ARK_NATIVE_SIMULATION_TEST_OK: C++ Flecs loaded; 3000 seeded parity operations; fallback and atomic restore; 1000 stable-ID work records, gated batch ticks=120 elapsed_us=", elapsed, "; this is kernel-only, not navigation/render FPS")
	quit()
