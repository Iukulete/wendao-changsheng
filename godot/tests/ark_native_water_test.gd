extends SceneTree
const Water = preload("res://scripts/adapters/ark_analytic_water.gd")
class BadKernel extends RefCounted:
	func compute(_packet: PackedFloat64Array, _mode: int) -> PackedFloat64Array:
		return PackedFloat64Array([NAN, 1.0])
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var extension := OS.get_environment("ARK_WATER_EXTENSION")
	if extension.is_empty():
		var common := Water.new()
		assert(common.advance(0.25)["ok"])
		print("ARK_NATIVE_WATER_TEST_OK: native SKIP (explicit ARK_WATER_EXTENSION absent); reference PASS")
		quit()
		return
	var maximum := 0.0
	for model in [1, 2]:
		for count in [0, 1, 2, 32, 256]:
			var reference := Water.new()
			if model == 2:
				assert(reference.enable_gerstner())
			reference.time_seconds = Water.TIME_PERIOD - 0.1
			for i in range(count):
				reference.register_float(str(i), Vector3(i * 0.3, 0.0, i * -0.2), 1.05)
				if i % 7 == 0:
					reference.set_sleeping(str(i), true)
			var single := Water.new()
			var multi := Water.new()
			assert(single.restore(JSON.parse_string(JSON.stringify(reference.snapshot()))))
			assert(multi.restore(reference.snapshot()))
			assert(single.configure_backend("native_single", extension))
			assert(multi.configure_backend("native_multi", extension))
			for dt in [0.0, 1.0 / 60.0, 0.25, 10.0]:
				assert(reference.advance(dt)["ok"])
				assert(single.advance(dt)["ok"])
				assert(multi.advance(dt)["ok"])
				assert(absf(reference.time_seconds - single.time_seconds) < 0.00000001)
				for id in reference.floats:
					var error: float = reference.float_pose(id).distance_to(single.float_pose(id))
					maximum = maxf(maximum, error)
					assert(error < 0.00001)
					assert(single.float_pose(id) == multi.float_pose(id))
			if count > 0:
				single.set_sleeping("0", false)
				assert(single.advance(0.25)["ok"])
				assert(single.unregister_float("0"))
				assert(single.advance(0.25)["ok"])
			assert(single.restore(reference.snapshot()))
			assert(single.advance(0.0)["ok"])
			single.shutdown()
			single.shutdown()
			assert(single.advance(0.25)["ok"])
	var corrupt := Water.new()
	corrupt.backend = "native_single"
	corrupt._kernel = BadKernel.new()
	var fallback := Water.new()
	assert(fallback.restore(corrupt.snapshot()))
	assert(fallback.advance(0.25)["ok"])
	assert(corrupt.advance(0.25)["ok"])
	assert(corrupt.backend == "gdscript")
	assert(corrupt.snapshot() == fallback.snapshot())
	var unchanged := JSON.stringify(fallback.snapshot())
	for field in ["mean_height", "revision"]:
		var invalid: Dictionary = fallback.snapshot()
		invalid[field] = 10001.0 if field == "mean_height" else 9007199254740992.0
		assert(not fallback.restore(invalid))
		assert(JSON.stringify(fallback.snapshot()) == unchanged)
	var thread := Thread.new()
	thread.start(func() -> Dictionary: return fallback.advance(0.25))
	var denied: Dictionary = thread.wait_to_finish()
	assert(not denied["ok"])
	assert(JSON.stringify(fallback.snapshot()) == unchanged)
	print("ARK_NATIVE_WATER_TEST_OK: models1/2 counts0/1/2/32/256 deltas0/1over60/.25/10 max_pose_error=", maximum, " malformed_output/restore/wrap/sleep/remove/shutdown=PASS")
	quit()
