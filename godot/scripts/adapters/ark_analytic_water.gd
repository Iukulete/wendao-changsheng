extends RefCounted
## Authoritative analytic water and controlled vertical response. No scene ownership.
## This is not a rigid-body hull or a hydrodynamic simulation.

const TIME_PERIOD := TAU * 100.0
const MAX_DELTA := 10.0
const STEP := 1.0 / 60.0
const MAX_SPEED := 0.35
var mean_height := -1.05
var time_seconds := 0.0
var revision := 0
var floats: Dictionary = {}
var model_version := 1
var waves: Array = []
var backend := "gdscript"
var _kernel: Object
var _owner_thread := OS.get_thread_caller_id()
var generation := 0

func enable_gerstner(value: Array = []) -> bool:
	if OS.get_thread_caller_id() != _owner_thread:
		return false
	var candidate := value.duplicate(true)
	if candidate.is_empty():
		candidate = [{"dx": 1.0, "dz": 0.0, "k": 0.21, "amplitude": 0.12, "steepness": 1.0, "phase": 0.0, "omega": 0.42}, {"dx": 0.6, "dz": 0.8, "k": 0.16, "amplitude": 0.07, "steepness": 1.0, "phase": 0.0, "omega": -0.31}]
	if not _valid_waves(candidate):
		return false
	waves = candidate
	model_version = 2
	generation += 1
	return true

func _valid_waves(candidate: Variant) -> bool:
	if not candidate is Array or candidate.size() != 2:
		return false
	var bound := 0.0
	for w in candidate:
		if not w is Dictionary or w.size() != 7:
			return false
		for key in w:
			if not key is String:
				return false
		for key in ["dx", "dz", "k", "amplitude", "steepness", "phase", "omega"]:
			if not _number(w.get(key)):
				return false
		if absf(w["dx"] * w["dx"] + w["dz"] * w["dz"] - 1.0) > 0.000001 or w["k"] <= 0.0 or w["amplitude"] < 0.0 or w["steepness"] < 0.0 or w["phase"] < 0.0 or w["phase"] >= TAU or w["k"] > 2.0 or w["amplitude"] > 0.25 or w["steepness"] > 10.0 or absf(w["omega"]) > 5.0:
			return false
		bound += absf(w["steepness"] * w["amplitude"] * w["k"])
	return bound <= 0.5

func forward(parameter: Vector2) -> Dictionary:
	return _forward_xy(parameter.x, parameter.y)

func _forward_xy(qx: float, qz: float) -> Dictionary:
	var x := qx
	var z := qz
	var y := mean_height
	var jxx := 1.0
	var jxz := 0.0
	var jzz := 1.0
	var yx := 0.0
	var yz := 0.0
	var velocity := Vector3.ZERO
	for w in waves:
		var theta: float = w["k"] * (w["dx"] * qx + w["dz"] * qz) + w["phase"]
		var h: float = w["steepness"] * w["amplitude"]
		x += h * w["dx"] * cos(theta)
		z += h * w["dz"] * cos(theta)
		y += w["amplitude"] * sin(theta)
		var slope: float = -h * w["k"] * sin(theta)
		jxx += slope * w["dx"] * w["dx"]
		jxz += slope * w["dx"] * w["dz"]
		jzz += slope * w["dz"] * w["dz"]
		yx += w["amplitude"] * w["k"] * w["dx"] * cos(theta)
		yz += w["amplitude"] * w["k"] * w["dz"] * cos(theta)
		velocity += Vector3(-h * w["dx"] * w["omega"] * sin(theta), w["amplitude"] * w["omega"] * cos(theta), -h * w["dz"] * w["omega"] * sin(theta))
	return {"x": x, "y": y, "z": z, "position": Vector3(x, y, z), "normal": Vector3(jxz, yz, jzz).cross(Vector3(jxx, yx, jxz)).normalized(), "jxx": jxx, "jxz": jxz, "jzz": jzz, "current": velocity}

func _gerstner_query(world: Vector3) -> Dictionary:
	var qx := float(world.x)
	var qz := float(world.z)
	var sample: Dictionary
	var residual := INF
	for i in range(8):
		sample = _forward_xy(qx, qz)
		var ox: float = sample["x"] - world.x
		var oz: float = sample["z"] - world.z
		residual = sqrt(ox * ox + oz * oz)
		if residual <= 0.000000001:
			break
		var determinant: float = sample["jxx"] * sample["jzz"] - sample["jxz"] * sample["jxz"]
		qx -= (sample["jzz"] * ox - sample["jxz"] * oz) / determinant
		qz -= (-sample["jxz"] * ox + sample["jxx"] * oz) / determinant
	sample = _forward_xy(qx, qz)
	residual = sqrt(pow(sample["x"] - world.x, 2) + pow(sample["z"] - world.z, 2))
	return {"height": sample["y"], "normal": sample["normal"], "current": sample["current"], "mean_height": mean_height, "time": time_seconds, "revision": revision, "ok": residual <= 0.00001, "residual": residual, "parameter": Vector2(qx, qz)}

func query(world: Vector3) -> Dictionary:
	if model_version == 2:
		return _gerstner_query(world)
	var a := world.x * 0.21 + time_seconds * 0.42
	var b := world.z * 0.16 - time_seconds * 0.31
	var c := (world.x + world.z) * 0.11 + time_seconds * 0.23
	var height := mean_height + 0.035 * sin(a) * cos(b) + 0.018 * sin(c)
	var dx := 0.035 * 0.21 * cos(a) * cos(b) + 0.018 * 0.11 * cos(c)
	var dz := -0.035 * 0.16 * sin(a) * sin(b) + 0.018 * 0.11 * cos(c)
	var vertical := 0.035 * (0.42 * cos(a) * cos(b) + 0.31 * sin(a) * sin(b)) + 0.018 * 0.23 * cos(c)
	return {"height": height, "mean_height": mean_height, "normal": Vector3(-dx, 1.0, -dz).normalized(), "current": Vector3(0.0, vertical, 0.0), "time": time_seconds, "revision": revision}

func register_float(id: String, position: Vector3, draft_offset: float) -> bool:
	if OS.get_thread_caller_id() != _owner_thread:
		return false
	if id.is_empty() or not position.is_finite() or not is_finite(draft_offset) or absf(draft_offset) > 10000.0 or absf(position.x) > 1000000.0 or absf(position.z) > 1000000.0 or absf(position.y) > 10000.0:
		return false
	# Rebinding after restore must not discard saved vertical response.
	if floats.has(id):
		return true
	if floats.size() >= 10000:
		return false
	floats[id] = {"position": position, "draft_offset": draft_offset, "velocity_y": 0.0, "sleeping": false}
	return true

func unregister_float(id: String) -> bool:
	if OS.get_thread_caller_id() != _owner_thread:
		return false
	return floats.erase(id)

func set_sleeping(id: String, sleeping: bool) -> bool:
	if OS.get_thread_caller_id() != _owner_thread:
		return false
	if not floats.has(id):
		return false
	floats[id]["sleeping"] = sleeping
	if sleeping:
		floats[id]["velocity_y"] = 0.0
	return true

func sync_horizontal(id: String, position: Vector3) -> bool:
	if OS.get_thread_caller_id() != _owner_thread:
		return false
	if not floats.has(id) or not position.is_finite() or absf(position.x) > 1000000.0 or absf(position.z) > 1000000.0:
		return false
	var previous: Vector3 = floats[id]["position"]
	floats[id]["position"] = Vector3(position.x, previous.y, position.z)
	return true

func float_pose(id: String) -> Vector3:
	return floats.get(id, {}).get("position", Vector3.ZERO)

func configure_backend(mode: String, extension_path: String = "") -> bool:
	if OS.get_thread_caller_id() != _owner_thread or mode not in ["gdscript", "native_single", "native_multi"]:
		return false
	if mode == "gdscript":
		shutdown()
		return true
	if extension_path.is_empty() or not FileAccess.file_exists(extension_path):
		return false
	if not GDExtensionManager.is_extension_loaded(extension_path):
		if GDExtensionManager.load_extension(extension_path) != OK:
			return false
	if not ClassDB.class_exists("ArkWaterBatch"):
		return false
	var candidate: Object = ClassDB.instantiate("ArkWaterBatch")
	if candidate == null or not candidate.has_method("compute") or not candidate.has_method("compute_gerstner"):
		candidate = null
		return false
	_kernel = candidate
	backend = mode
	generation += 1
	return _kernel != null

func shutdown() -> void:
	if OS.get_thread_caller_id() != _owner_thread:
		return
	_kernel = null
	backend = "gdscript"
	generation += 1

func _advance_native(delta: float) -> Dictionary:
	var ticket := generation
	var packet := PackedFloat64Array([time_seconds, delta, mean_height])
	if model_version == 2:
		for w in waves:
			for key in ["dx", "dz", "k", "amplitude", "steepness", "phase", "omega"]:
				packet.append(w[key])
	var ids: Array = []
	for id in floats:
		var state: Dictionary = floats[id]
		if state["sleeping"]:
			continue
		ids.append(id)
		var p: Vector3 = state["position"]
		packet.append_array(PackedFloat64Array([p.x, p.y, p.z, state["draft_offset"], state["velocity_y"]]))
	var output: Variant = _kernel.call("compute_gerstner" if model_version == 2 else "compute", packet, 1 if backend == "native_multi" else 0)
	var prefix := 4 if model_version == 2 else 2
	if not output is PackedFloat64Array or output.size() != prefix + ids.size() * 2 or generation != ticket:
		return {"ok": false, "steps": 0}
	for value in output:
		if not is_finite(value):
			return {"ok": false, "steps": 0}
	if output[0] < 0.0 or output[0] >= TIME_PERIOD or output[1] < 0.0 or output[1] > 601 or output[1] != floorf(output[1]):
		return {"ok": false, "steps": 0}
	if model_version == 2 and (output[2] < 0.0 or output[2] >= TAU or output[3] < 0.0 or output[3] >= TAU):
		return {"ok": false, "steps": 0}
	for i in range(ids.size()):
		if absf(output[prefix + i * 2]) > 10000.0 or absf(output[prefix + i * 2 + 1]) > MAX_SPEED:
			return {"ok": false, "steps": 0}
	# Commit only after validating the complete immutable result.
	time_seconds = output[0]
	if model_version == 2:
		waves[0]["phase"] = output[2]
		waves[1]["phase"] = output[3]
	for i in range(ids.size()):
		var state: Dictionary = floats[ids[i]]
		var p: Vector3 = state["position"]
		p.y = output[prefix + i * 2]
		state["position"] = p
		state["velocity_y"] = output[prefix + i * 2 + 1]
	if delta > 0.0:
		revision += 1
	return {"ok": true, "steps": int(output[1]), "revision": revision, "time": time_seconds}

func _valid_runtime() -> bool:
	if not is_finite(mean_height) or absf(mean_height) > 10000.0 or not is_finite(time_seconds) or time_seconds < 0.0 or time_seconds >= TIME_PERIOD or floats.size() > 10000:
		return false
	if model_version == 2 and not _valid_waves(waves):
		return false
	for state in floats.values():
		var p: Vector3 = state["position"]
		if not p.is_finite() or absf(p.x) > 1000000.0 or absf(p.z) > 1000000.0 or absf(p.y) > 10000.0 or not _number(state["draft_offset"]) or absf(state["draft_offset"]) > 10000.0 or not _number(state["velocity_y"]) or absf(state["velocity_y"]) > MAX_SPEED:
			return false
	return true

func advance(delta: float) -> Dictionary:
	if OS.get_thread_caller_id() != _owner_thread:
		return {"ok": false, "steps": 0}
	if not _valid_runtime() or not is_finite(delta) or delta < 0.0 or delta > MAX_DELTA:
		return {"ok": false, "steps": 0, "revision": revision, "time": time_seconds}
	if backend != "gdscript":
		var result := _advance_native(delta)
		if result.get("ok", false):
			return result
		shutdown() # Atomic native rejection; perform this same timestep on reference below.
	var remaining := delta
	var steps := 0
	while remaining > 0.000000001:
		var dt := minf(STEP, remaining)
		time_seconds = fposmod(time_seconds + dt, TIME_PERIOD)
		if model_version == 2:
			for w in waves:
				w["phase"] = fposmod(w["phase"] + w["omega"] * dt, TAU)
		steps += 1
		for id in floats:
			var state: Dictionary = floats[id]
			if state["sleeping"]:
				continue
			var position: Vector3 = state["position"]
			var target: float = query(position)["height"] + state["draft_offset"]
			# Damped, speed-bounded heave; horizontal sailing remains the caller's authority.
			var velocity: float = state["velocity_y"]
			velocity = clampf(velocity + ((target - position.y) * 9.0 - velocity * 6.0) * dt, -MAX_SPEED, MAX_SPEED)
			position.y += velocity * dt
			state["position"] = position
			state["velocity_y"] = velocity
		remaining -= dt
	if delta > 0.0:
		revision += 1
	return {"ok": true, "steps": steps, "revision": revision, "time": time_seconds}

func apply_visual(material: ShaderMaterial) -> void:
	if material != null:
		material.set_shader_parameter("water_time", time_seconds)
		material.set_shader_parameter("mean_height", mean_height)
		material.set_shader_parameter("water_model", model_version)
		if model_version == 2:
			for i in range(2):
				var w: Dictionary = waves[i]
				material.set_shader_parameter("gerstner_wave_a" if i == 0 else "gerstner_wave_b", Vector4(w["dx"], w["dz"], w["k"], w["amplitude"]))
			material.set_shader_parameter("gerstner_motion", Vector4(waves[0]["steepness"], waves[0]["phase"], waves[1]["steepness"], waves[1]["phase"]))

func snapshot() -> Dictionary:
	var saved_floats: Dictionary = {}
	for id in floats:
		var state: Dictionary = floats[id]
		var position: Vector3 = state["position"]
		saved_floats[String(id)] = {"position": {"x": position.x, "y": position.y, "z": position.z}, "draft_offset": state["draft_offset"], "velocity_y": state["velocity_y"], "sleeping": state["sleeping"]}
	var saved := {"model_version": model_version, "mean_height": mean_height, "time_seconds": time_seconds, "revision": revision, "floats": saved_floats}
	if model_version == 2:
		saved["waves"] = waves.duplicate(true)
	return saved

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func restore(saved: Dictionary) -> bool:
	if OS.get_thread_caller_id() != _owner_thread:
		return false
	# Validate into a temporary dictionary; bad saves never partially mutate authority.
	if (saved.get("model_version") != 1 and saved.get("model_version") != 2) or not _number(saved.get("mean_height")) or not _number(saved.get("time_seconds")) or not _number(saved.get("revision")):
		return false
	if float(saved["time_seconds"]) < 0.0 or float(saved["revision"]) < 0.0 or float(saved["revision"]) != floorf(float(saved["revision"])) or not saved.get("floats") is Dictionary:
		return false
	var saved_waves: Variant = saved.get("waves", []).duplicate(true) if saved.get("waves", []) is Array else null
	if saved_waves is Array:
		for w in saved_waves:
			if w is Dictionary and _number(w.get("phase")) and w["phase"] >= TAU and w["phase"] <= TAU + 0.000000000001:
				w["phase"] = 0.0
	if absf(float(saved["mean_height"])) > 10000.0 or float(saved["revision"]) > 9007199254740991.0 or saved["floats"].size() > 10000:
		return false
	if saved["model_version"] == 2 and not _valid_waves(saved_waves):
		return false
	var restored: Dictionary = {}
	for id in saved["floats"]:
		if not id is String or id.is_empty() or not saved["floats"][id] is Dictionary:
			return false
		var state: Dictionary = saved["floats"][id]
		var p: Variant = state.get("position")
		if not p is Dictionary or not _number(p.get("x")) or not _number(p.get("y")) or not _number(p.get("z")):
			return false
		if not _number(state.get("draft_offset")) or not _number(state.get("velocity_y")) or not state.get("sleeping") is bool:
			return false
		if absf(float(state["velocity_y"])) > MAX_SPEED or absf(float(state["draft_offset"])) > 10000.0:
			return false
		var position := Vector3(p["x"], p["y"], p["z"])
		if not position.is_finite() or absf(position.x) > 1000000.0 or absf(position.z) > 1000000.0 or absf(position.y) > 10000.0:
			return false
		restored[id] = {"position": position, "draft_offset": float(state["draft_offset"]), "velocity_y": float(state["velocity_y"]), "sleeping": state["sleeping"]}
	mean_height = float(saved["mean_height"])
	time_seconds = fposmod(float(saved["time_seconds"]), TIME_PERIOD)
	revision = int(saved["revision"])
	floats = restored
	model_version = int(saved["model_version"])
	waves = saved_waves if model_version == 2 else []
	generation += 1
	return true
