extends SceneTree
## CPU authority/response test. Does not claim rendered shader or GPU validation.
const Water = preload("res://scripts/adapters/ark_analytic_water.gd")
const HEIGHT_TOLERANCE := 0.000001
const NORMAL_TOLERANCE := 0.0001

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var water := Water.new()
	var max_error := 0.0
	for t in [0.0, 0.5, 17.0, 123.0]:
		water.time_seconds = t
		for x in range(-100, 101, 10):
			for z in range(-100, 101, 10):
				var point := Vector3(x, 0, z)
				var expected: float = -1.05 + sin(x * 0.21 + t * 0.42) * cos(z * 0.16 - t * 0.31) * 0.035 + sin((x + z) * 0.11 + t * 0.23) * 0.018
				max_error = maxf(max_error, absf(water.query(point)["height"] - expected))
				var dx: float = (water.query(point + Vector3(0.01, 0, 0))["height"] - water.query(point - Vector3(0.01, 0, 0))["height"]) / 0.02
				var dz: float = (water.query(point + Vector3(0, 0, 0.01))["height"] - water.query(point - Vector3(0, 0, 0.01))["height"]) / 0.02
				assert(water.query(point)["normal"].distance_to(Vector3(-dx, 1, -dz).normalized()) < NORMAL_TOLERANCE)
	assert(max_error < HEIGHT_TOLERANCE)
	water.time_seconds = 0.0
	assert(water.register_float("starter_ark", Vector3.ZERO, 1.05))
	assert(water.register_float("crate", Vector3(5, 0, 3), 1.05))
	assert(water.set_sleeping("crate", true))
	var sleeping_pose: Vector3 = water.float_pose("crate")
	for dt in [1.0 / 120.0, 1.0 / 30.0, 0.5, 2.0, 10.0]:
		var old: Vector3 = water.float_pose("starter_ark")
		var result: Dictionary = water.advance(dt)
		assert(result["ok"] and result["steps"] <= ceili(dt * 60.0) + 1)
		assert(absf(water.float_pose("starter_ark").y - old.y) <= Water.MAX_SPEED * dt + HEIGHT_TOLERANCE)
		assert(water.float_pose("crate") == sleeping_pose)
	assert(water.set_sleeping("crate", false))
	assert(water.sync_horizontal("starter_ark", Vector3(12, 999, -8)))
	assert(water.float_pose("starter_ark").x == 12 and water.float_pose("starter_ark").z == -8)
	# JSON roundtrip exercises real serialization types (numbers become floats).
	var encoded := JSON.stringify(water.snapshot())
	var recreated := Water.new()
	assert(recreated.restore(JSON.parse_string(encoded)))
	assert(recreated.register_float("starter_ark", Vector3(99, 99, 99), 5.0))
	assert(recreated.float_pose("starter_ark") == water.float_pose("starter_ark"))
	for i in range(60):
		assert(water.advance(1.0 / 60.0)["ok"])
		assert(recreated.advance(1.0 / 60.0)["ok"])
		assert(recreated.float_pose("starter_ark").distance_to(water.float_pose("starter_ark")) < HEIGHT_TOLERANCE)
	assert(water.float_pose("crate") != sleeping_pose)
	var before := JSON.stringify(recreated.snapshot())
	assert(not recreated.advance(-1.0)["ok"])
	assert(not recreated.advance(INF)["ok"])
	assert(not recreated.advance(10.1)["ok"])
	var broken: Dictionary = recreated.snapshot()
	broken["floats"]["crate"]["velocity_y"] = INF
	assert(not recreated.restore(broken))
	assert(JSON.stringify(recreated.snapshot()) == before)
	assert(recreated.unregister_float("crate"))
	assert(not recreated.unregister_float("crate"))
	print("ARK_WATER_RISK_TEST_OK: samples=1764 max_height_error=", max_error, " normal_tolerance=", NORMAL_TOLERANCE, " bounded_heave/sleep/wake/remove/JSON-recreate=PASS; GPU not tested")
	quit(0)
