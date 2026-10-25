extends SceneTree

## Numeric preservation/installation contract, NOT an aesthetic or exposure gate.
## OLD observations were captured in official 4.7.1 before the NIGHT-only edit:
## ark_greybox.gd SHA256 f2999b074d0c731a545c9e0daaf4b8ba97639a7bb221f854d6c0c7eae7bcdc92.
## Baseline preservation already passed. Real renderer review owns readability.
const Paths = preload("res://tests/ark_test_paths.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
# Renderer-reviewed bounded NIGHT terrain/light improvement; not universal
# NPC/storm readability, and not an independently proven old functional bug.
const NIGHT_AMBIENT := 0.85
const NIGHT_AMBIENT_COLOR := Color("8b9caf")
const NIGHT_SUN := 0.20
const NIGHT_PITCH := -35.0
const OLD_OUTPUT := {
	"0_0": "6d708244e91d022253e1344a60df1e01dedf109372178018d4c2c7d76cc9d2d3",
	"0_1": "cb1f34af1aa52836c8c433049593630e63ff90c3de68a2f775e13fa95ebc4d56",
	"0_2": "2494c1dd2e9f3e9392d316bf28b80e0f29650ec694dfbf6eaea806bbb95db8a0",
	"1_0": "a584c33b4279ae2ae4c204e12db7b5ff7e1bd45fb4b57ce052e58092615eea55",
	"1_1": "7a1930fed74d0d48d80f880e14e6acbbc373b9fb7ba2866655d48c2c411bf43d",
	"1_2": "341dfea87d2788f846ac42a01161b17449987a7ffa2a3d615091eac85e39649f",
	"2_0": "553f9508bbc07ca3ba49989567a7e55f75a7ad2df9746da751dfd63da6d7404d",
	"2_1": "822a04c2e1cec483f8155e12dd4759d06de8bfd470aedd6b48f63b5412b1bc46",
	"2_2": "279c581b40736802ab9bfa119825852e18c0d32906a8b0b82aadcb95158d4b33",
	"3_0": "5f9afdc41e3d37ec33f8dcbf25b0c96b630710a7fa9262c02854c47584519faa",
	"3_1": "fcadec6db54cd1bb8eb5be373e2d19d82ffde587cd7561269ff46189f545c734",
	"3_2": "cb33b09b91ab6cd8ae14d2b9ffc42fbe0e76e03410b51468aebffba2adbd9762"
}
const OLD_MATERIALS := {
	"0_0": "5cfab2b46d4503e6bd29cdface8abc82ccc1e21847e40221c5e76dbfc407bd41",
	"0_1": "52b22953577317111c7f33767d834fdc540f66e95410d37bbc497579f8cb2a6f",
	"0_2": "5cfab2b46d4503e6bd29cdface8abc82ccc1e21847e40221c5e76dbfc407bd41",
	"1_0": "84817f0a32f4abb75972ce65b8cb90e5f5242de04007afae01d5eead98489408",
	"1_1": "52b22953577317111c7f33767d834fdc540f66e95410d37bbc497579f8cb2a6f",
	"1_2": "84817f0a32f4abb75972ce65b8cb90e5f5242de04007afae01d5eead98489408",
	"2_0": "9be51cee413bc17713e3a9617203648b88fcf74d996fbea9d870d202b097e49c",
	"2_1": "9be51cee413bc17713e3a9617203648b88fcf74d996fbea9d870d202b097e49c",
	"2_2": "9be51cee413bc17713e3a9617203648b88fcf74d996fbea9d870d202b097e49c",
	"3_0": "05504be0def4161a346e12b6dbabf32159da4dc312eb4ed2e57daeb817958476",
	"3_1": "05504be0def4161a346e12b6dbabf32159da4dc312eb4ed2e57daeb817958476",
	"3_2": "05504be0def4161a346e12b6dbabf32159da4dc312eb4ed2e57daeb817958476"
}
var game: Node3D
var saves: RefCounted
var save_root: String
var failures := 0
const CoastHistory = preload("res://tests/support/coast_historical_projection.gd")
var _coast_history: RefCounted

func _history() -> RefCounted:
	if _coast_history == null or not is_instance_valid(_coast_history.get("game")) or _coast_history.get("game") != game:
		_coast_history = CoastHistory.new()
		_coast_history.configure(game, self)
	return _coast_history

func _historical_material_digest(materials: Array) -> String:
	return _material_digest(_history().materials(materials, true))



func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("NIGHT_LIGHTING: " + message)


func _spawn() -> void:
	game = load("res://scenes/ark_greybox.tscn").instantiate() as Node3D
	game.set("save_root_override", save_root)
	game.set("start_with_home_art", false) # Historical raw-material/lighting fixture, not production policy.
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	(game.get("player") as Node).set_physics_process(false)
	await physics_frame


func _drop() -> void:
	game.set("save_service", null)
	game.queue_free()
	await process_frame


func _plain(value: Variant) -> Variant:
	if value is Color:
		return [snappedf(value.r, 0.000001), snappedf(value.g, 0.000001), snappedf(value.b, 0.000001), snappedf(value.a, 0.000001)]
	if value is Vector3:
		return [snappedf(value.x, 0.000001), snappedf(value.y, 0.000001), snappedf(value.z, 0.000001)]
	if value is float:
		return snappedf(value, 0.000001)
	if value is Resource:
		if value is Material or value is Environment or value is ProceduralSkyMaterial or value is CameraAttributes:
			return _resource(value)
		if value is Shader:
			return {"class": value.get_class(), "code_sha256": value.code.sha256_text()}
		return {"class": value.get_class(), "path": value.resource_path}
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = _plain(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry in value:
			result.append(_plain(entry))
		return result
	if typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME]:
		return value
	return str(value)


func _resource(resource: Resource) -> Dictionary:
	var result := {"class": resource.get_class()}
	for item in resource.get_property_list():
		var id := str(item.name)
		if int(item.usage) & PROPERTY_USAGE_STORAGE and id not in ["resource_name", "resource_path", "resource_local_to_scene", "script"]:
			result[id] = _plain(resource.get(id))
	return result


# Independent exact-node recognition, not the production helper's cache/tags.
# These metadata are never part of the historical name-only material digest.
func _surface_sample_path(node: MeshInstance3D) -> String:
	var path := str(game.get_path_to(node))
	if path in ["IslandLandmass/Shoreline", "IslandLandmass/Grassland"]:
		return path
	for index in range(8):
		if path == "ArkRoot/BuiltShelter/CabinFloorboards/FloorPlank%d" % index:
			return path
	var parent_path := str(game.get_path_to(node.get_parent()))
	if parent_path in ["ArkRoot/RaftTop", "ArkRoot/RaftBoardingGangplank"]:
		var direct_meshes := 0
		for child in node.get_parent().get_children():
			if child is MeshInstance3D:
				direct_meshes += 1
		if direct_meshes == 1:
			return parent_path + "/MeshInstance3D#0"
	return ""


func _old_surface_fields(material: Variant) -> Variant:
	if not material is Dictionary or material.get("class") != "StandardMaterial3D":
		return material
	var result: Dictionary = material.duplicate(true)
	# Actual BEFORE observations (official 4.7.1, canonical verified47), not
	# regenerated goldens. Preserve EVERY other field, including albedo color,
	# roughness, cull/transparency, world anchoring, sharpness and filter.
	result.albedo_texture = "<Object#null>"
	result.uv1_triplanar = false
	result.uv1_scale = [1.0, 1.0, 1.0]
	return result


func _materials() -> Array:
	var result: Array = []
	for node in game.find_children("*", "MeshInstance3D", true, false):
		var entry := {"_history_path": _history().node_path(node), "_surface_sample_path": _surface_sample_path(node), "name": str(node.name), "override": _plain(node.material_override), "overlay": _plain(node.material_overlay), "surfaces": []}
		if node.mesh:
			for index in range(node.mesh.get_surface_count()):
				entry.surfaces.append(_plain(node.get_active_material(index)))
		result.append(entry)
	return result


func _lighting() -> Dictionary:
	var sun: DirectionalLight3D = game.get("sun_light")
	var env: Environment = game.get("weather_environment")
	var overlay: ColorRect = game.get("storm_overlay")
	var lights: Array = []
	for light in game.find_children("*", "Light3D", true, false):
		lights.append({"name": str(light.name) if not str(light.name).begins_with("@") else light.get_class(), "class": light.get_class(), "color": _plain(light.light_color), "energy": _plain(light.light_energy), "shadow": light.shadow_enabled, "position": _plain(light.position), "rotation": _plain(light.rotation_degrees), "range": light.omni_range if light is OmniLight3D else null})
	var camera: Camera3D = game.get("camera")
	return {"profile": _plain(game.call("_daylight_profile")), "environment": _resource(env), "sky": _resource(game.get("sky_material")), "lights": lights, "sun": {"color": _plain(sun.light_color), "energy": _plain(sun.light_energy), "rotation": _plain(sun.rotation_degrees), "shadow": sun.shadow_enabled}, "overlay": {"visible": overlay.visible, "color": _plain(overlay.color)}, "camera_attributes": _plain(camera.attributes) if camera else null, "materials": _materials()}


func _state() -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.call("_build_save_state")))


func _interact(id: String) -> void:
	for entry in game.get("interactables") as Array:
		if str(entry.get("id", "")) == id:
			(game.get("player") as Node3D).global_position = (entry.node as Node3D).global_position + Vector3.UP * 0.15
			game.call("_interact")
			return
	assert(false, "missing real interactable: " + id)


func _canonical(value: Variant) -> Variant:
	# Quantize the actual observed numeric properties to 1e-6, consistently across
	# JSON fixtures, engine single-precision vectors and Windows/Linux float text.
	if value is int or value is float:
		return roundi(float(value) * 1000000.0)
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = _canonical(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry in value:
			result.append(_canonical(entry))
		return result
	return value


func _digest(value: Variant) -> String:
	return JSON.stringify(_canonical(value), "", true).sha256_text()


func _material_digest(materials: Array) -> String:
	var rows: Array[String] = []
	for entry in materials:
		var record: Dictionary = entry.duplicate(true)
		if not str(record.get("_surface_sample_path", "")).is_empty():
			record.override = _old_surface_fields(record.override)
			for index in range(record.surfaces.size()):
				record.surfaces[index] = _old_surface_fields(record.surfaces[index])
		record.erase("_surface_sample_path")
		record.erase("_history_path")
		if str(record.name).begins_with("@"):
			record.name = "MeshInstance3D"
		rows.append(JSON.stringify(_canonical(record), "", true))
	rows.sort() # Reconstruction can reorder siblings, not change any material.
	return "\n".join(rows).sha256_text()


func _ambient_history(actual: Array, old_color: Color, expected_color: Color) -> Array:
	var old_values: Array = _plain(old_color)
	var expected_values: Array = _plain(expected_color)
	var result: Array = []
	for index in range(4):
		result.append(float(old_values[index]) + float(actual[index]) - float(expected_values[index]))
	return result


func _output_contract(observation: Dictionary, period: int) -> Dictionary:
	var result: Dictionary = _history().lighting(observation)
	result.erase("materials")
	if period == 3:
		# Historical blue ambient is projected with observed residuals preserved;
		# independently checked current NIGHT color/blend never replaces OLD hashes.
		var weather: int = game.get("weather_phase")
		var tint: Color = [Color("a8c1c7"),Color("566a7b"),Color("b8a68e")][weather]
		result.profile.ambient = _ambient_history(result.profile.ambient, Color("35445f"), NIGHT_AMBIENT_COLOR)
		result.environment.ambient_light_color = _ambient_history(result.environment.ambient_light_color, Color("35445f").lerp(tint,[0.22,0.72,0.14][weather]), NIGHT_AMBIENT_COLOR.lerp(tint,[0.22,0.40,0.14][weather]))
		# Existing three designed inputs are allowed to differ from OLD. Corresponding
		# installed values are checked independently against the approved contract.
		result.profile.erase("ambient_energy")
		result.profile.erase("sun_energy")
		result.profile.sun_rotation[0] = 0
		result.environment.erase("ambient_light_energy")
		result.sun.erase("energy")
		result.sun.rotation[0] = 0
		for light in result.lights:
			if light.class == "DirectionalLight3D":
				light.erase("energy")
				light.rotation[0] = 0
	var sorted_lights: Array[String] = []
	for light in result.lights:
		sorted_lights.append(JSON.stringify(_canonical(light), "", true))
	sorted_lights.sort()
	result.lights = sorted_lights
	return result


func _check_screen_policy(label: String) -> void:
	# Independently observed OLD screen policy: one unmodified WorldEnvironment,
	# one camera, one unshaded storm ColorRect; no compositor/exposure override.
	# Approved HUD health cells are bounded status widgets, not screen tints.
	var environments := game.find_children("*", "WorldEnvironment", true, false)
	var cameras := game.find_children("*", "Camera3D", true, false)
	var rectangles := game.find_children("*", "ColorRect", true, false)
	var hud: Node = game.get("nearfuture_hud")
	var cells: Array = hud.get("health_cells")
	_check(cells.size() == 4 and rectangles.size() == 5, label + " permits exactly four approved health cells plus the original storm overlay")
	_check(environments.size() == 1 and cameras.size() == 1, label + " must not add an environment or camera")
	for index in range(cells.size()):
		var cell := cells[index] as ColorRect
		_check(cell != null and (hud.get("status_panel") as Node).is_ancestor_of(cell) and str(cell.name) == "HealthCell%d" % index, label + " health cells stay inside their one approved HUD status panel")
		_check(cell.custom_minimum_size == Vector2(5, 13) and cell.size.x <= 5 and cell.size.y <= 13 and cell.mouse_filter == Control.MOUSE_FILTER_IGNORE, label + " health cells cannot become input-blocking or full-screen tint rectangles")
	for world_environment in environments:
		_check(world_environment.environment == game.get("weather_environment") and world_environment.camera_attributes == null and world_environment.compositor == null, label + " must not add world exposure/compositor compensation")
	for camera in cameras:
		_check(camera.environment == null and camera.attributes == null and camera.compositor == null, label + " must not override camera exposure/environment/compositor")
	for rectangle in rectangles:
		_check((rectangle == game.get("storm_overlay") or rectangle in cells) and rectangle.material == null, label + " permits only the original unshaded storm overlay and bounded unshaded health cells")
	for canvas in game.find_children("*", "CanvasItem", true, false):
		_check(canvas.material == null, label + " must not introduce a screen/UI shader")
	_check(game.find_children("*", "CanvasModulate", true, false).is_empty(), label + " must not introduce whole-canvas tinting")


func _calibrate_oracle(observation: Dictionary) -> void:
	# Synthetic mutations calibrate the preservation oracle, not a claimed old bug.
	var original := _digest(_output_contract(observation, 0))
	var changed := observation.duplicate(true)
	changed.environment.tonemap_exposure += 0.1
	_check(_digest(_output_contract(changed, 0)) != original, "oracle must detect whole-screen exposure compensation")
	changed = observation.duplicate(true)
	changed.lights.append(changed.lights[0].duplicate(true))
	_check(_digest(_output_contract(changed, 0)) != original, "oracle must detect an added light")
	changed = observation.duplicate(true)
	changed.overlay.color[3] += 0.01
	_check(_digest(_output_contract(changed, 0)) != original, "oracle must detect changed storm opacity")
	changed = observation.duplicate(true)
	var sea_row_found := false
	for row in changed.materials:
		if row.get("_history_path") == "Sea":
			row.override["shader_parameter/mean_height"] += 0.01
			sea_row_found = true
	_check(sea_row_found, "water mutation calibration requires the exact Sea row, never array order")
	_check(_material_digest(changed.materials) != _material_digest(observation.materials), "oracle must detect changed sea material authority parameters")
	# Mutate and restore ACTUAL scene resources: all must still trip preservation.
	# The selected grass's base color is deliberately NOT a normalized field.
	var baseline := _material_digest(_materials())
	for path in ["residentMarker/CoastVisualGroundOffset/TidekeeperFigure/Body", "FarReefLandmass/Grassland", "IslandLandmass/Grassland"]:
		var visual := game.get_node(path) as MeshInstance3D
		var material := visual.material_override as StandardMaterial3D
		var old_color := material.albedo_color
		material.albedo_color.r += 0.01
		_check(_material_digest(_materials()) != baseline, "oracle must reject actual NPC/other-island/selected-base-color mutation: " + path)
		material.albedo_color = old_color
		_check(_material_digest(_materials()) == baseline, "oracle mutation must restore actual material: " + path)
	var sea_material := (game.get_node("Sea") as MeshInstance3D).material_override as ShaderMaterial
	var old_height: Variant = sea_material.get_shader_parameter("mean_height")
	sea_material.set_shader_parameter("mean_height", float(old_height) + 0.01)
	_check(_material_digest(_materials()) != baseline, "oracle must reject actual water authority mutation")
	sea_material.set_shader_parameter("mean_height", old_height)
	_check(_material_digest(_materials()) == baseline, "oracle must restore actual water authority")


func _night_ambient_installed(profile: Dictionary, env: Environment, weather: int) -> bool:
	var tint: Color = [Color("a8c1c7"),Color("566a7b"),Color("b8a68e")][weather]
	return profile.ambient == NIGHT_AMBIENT_COLOR and is_equal_approx(float(profile.ambient_energy), NIGHT_AMBIENT) and env.ambient_light_color.is_equal_approx(NIGHT_AMBIENT_COLOR.lerp(tint,[0.22,0.40,0.14][weather])) and is_equal_approx(env.ambient_light_energy, NIGHT_AMBIENT * [0.88,0.88,0.94][weather])


func _inspect(label: String, compare_materials: bool = true) -> Dictionary:
	var period := int(game.get("day_period"))
	var weather := int(game.get("weather_phase"))
	var key := "%d_%d" % [period, weather]
	var before := _state()
	game.call("_set_weather_visuals")
	var observation := _lighting()
	game.call("_set_weather_visuals")
	_check(_lighting() == observation, label + " repeated visual application must be exactly idempotent")
	_history().validate_lighting()
	_check_screen_policy(label)
	if label == "initial" and period == 0 and weather == 0:
		_calibrate_oracle(observation)
	_check(_state() == before, label + " visual update must preserve the COMPLETE same-state save (economy/history/health/water/time/actors), without exclusions")
	_check(_digest(_output_contract(observation, period)) == OLD_OUTPUT.get(key, ""), label + " changed OLD output outside independently validated coast Sun and reviewed NIGHT-only calibration: " + key)
	if compare_materials:
		_check(_historical_material_digest(observation.materials) == OLD_MATERIALS.get(key, ""), label + " changed OLD terrain/NPC/Emma/sea/home material or shader parameters: " + key)
	if period == 3:
		var profile: Dictionary = game.call("_daylight_profile")
		_check(_night_ambient_installed(profile, game.get("weather_environment"), weather), label + " must install exact reviewed NIGHT ambient color/energy and storm-only blend")
		var sun: DirectionalLight3D = game.get("sun_light")
		var env: Environment = game.get("weather_environment")
		_check(is_equal_approx(float(profile.ambient_energy), NIGHT_AMBIENT) and is_equal_approx(float(profile.sun_energy), NIGHT_SUN) and (profile.sun_rotation as Vector3).is_equal_approx(Vector3(NIGHT_PITCH, 36, 0)), label + " must install exactly the renderer-reviewed NIGHT profile, not arbitrary brightness")
		_check(is_equal_approx(env.ambient_light_energy, NIGHT_AMBIENT * [0.88, 0.88, 0.94][weather]), label + " must install reviewed NIGHT ambient attenuation without altering other periods")
		_check(is_equal_approx(sun.light_energy, NIGHT_SUN * [0.76, 0.18, 0.82][weather] * 0.36453125) and sun.rotation_degrees.is_equal_approx(Vector3(NIGHT_PITCH, 36, 0)), label + " must preserve original directional attenuation/rotation application")
	if period == 3 and label == "initial":
		var env := game.get("weather_environment") as Environment
		var saved_color := env.ambient_light_color
		var saved_energy := env.ambient_light_energy
		env.ambient_light_color.r += 0.01
		_check(not _night_ambient_installed(game.call("_daylight_profile"),env,weather), "actual wrong NIGHT ambient color must fail installation oracle")
		_check(_digest(_output_contract(_lighting(),period)) != _digest(_output_contract(observation,period)), "actual wrong NIGHT ambient color must survive historical projection")
		env.ambient_light_color = saved_color
		env.ambient_light_energy += 0.01
		_check(not _night_ambient_installed(game.call("_daylight_profile"),env,weather), "actual wrong NIGHT ambient energy must fail installation oracle")
		env.ambient_light_energy = saved_energy
		_check(_lighting() == observation, "actual NIGHT oracle mutations must restore exact resources")
	if period == 3:
		var original_digest := _digest(_output_contract(observation, period))
		for field in ["profile", "environment"]:
			var mutated := observation.duplicate(true)
			var color_key := "ambient" if field == "profile" else "ambient_light_color"
			mutated[field][color_key][0] += 0.01
			_check(_digest(_output_contract(mutated, period)) != original_digest, label + " NIGHT ambient projection must preserve unexpected color deviation: " + field)
	print("NIGHT_LIGHTING_OBSERVATION: ", label, " matrix=", key, " complete_state_equal=", _state() == before, " sun=", observation.sun, " ambient=", observation.environment.ambient_light_energy)
	return observation


func _semantics(state: Dictionary) -> Dictionary:
	var result := state.duplicate(true)
	# Expected loader presentation/schema and stale-task invalidation only.
	# Unlike same-state checks above, repeated reconstruction increments this ID.
	result.erase("schema_version")
	result.erase("message")
	(result.modules.gathering as Dictionary).erase("generation")
	return result


func _reconstructed(expected: Dictionary, label: String) -> void:
	_check(not bool(game.get_meta("save_load_blocked", false)), label + " must reconstruct without migration block")
	var current := _semantics(_state())
	for field in expected:
		_check(current.has(field) and current[field] == expected[field], label + " changed saved field: " + field)
	var materials_before := _material_digest(_materials())
	_inspect(label, false)
	_check(_material_digest(_materials()) == materials_before, label + " visual reapplication must not alter same-period materials or water uniforms")
	_check(game.find_children("BuiltShelter", "Node3D", true, false).size() == 1, label + " must not duplicate the warm home on repeated load")


func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/test_night_lighting_%d_%d" % [OS.get_process_id(), int(Time.get_unix_time_from_system() * 1000000)]).simplify_path()
	assert(Paths.is_safe_save_root(save_root), "night regression requires unique test-only saves, never ordinary preview/user saves")
	saves = Save.new(save_root)
	saves.clear_for_test()
	await _spawn()
	# Match the independent OLD fixture: real finite collections, construction and
	# meeting. Only proximity is staged; no inventory, memories or rewards invented.
	for pile in range(3):
		_interact("wood")
		await process_frame
	_check(int(game.get("wood")) == 8, "fixture must really collect 2+2+3 finite wood piles")
	(game.get("player") as Node3D).position = Vector3(0, 1.1, 1.75)
	_check(bool(game.call("_try_place_workshop_home_template", Vector3(0, 0.12, 0))), "real seven-wood transaction must fund the home and its existing lamps")
	_interact("resident")
	_interact("shellfish")
	(game.get("player") as Node3D).position = Vector3(0.25, 1.1, 1.2)
	_check(bool(game.get("resident_met")) and not (game.get("world_events") as Array).is_empty() and not (game.get("collected_ids") as Array).is_empty(), "fixture must have actual earned acquisition/history")
	for period in range(4):
		for weather in range(3):
			game.set("day_period", period)
			game.set("weather_phase", weather)
			_inspect("initial")
	# Extra clearly synthetic nondefault health/timer fixture catches reset-to-default
	# side effects. Advance the actual water authority, never invent history records.
	game.set("player_health", 3)
	game.set("life_period_elapsed", 23.5)
	_check(bool(game.get("water").advance(0.125).get("ok", false)), "water fixture must advance through the existing authority")
	game.get("water").apply_visual((game.get_node("Sea") as MeshInstance3D).material_override)
	game.set("weather_phase", 1)
	_inspect("nondefault_night_storm", false)
	_check(bool(game.call("_save_progress")), "current fixture must use the normal checksum save service")
	var saved: Dictionary = saves.load_state().get("state", {})
	_check(int(saved.get("schema_version", 0)) == 43 and str(ProjectSettings.get_setting("application/config/version")) == "0.1.003", "readability remains compatible with kitchen schema43 and the unchanged game version")
	var expected := _semantics(saved)
	await _drop()
	await _spawn()
	_reconstructed(expected, "current36_fresh")
	for repeat in range(2):
		game.call("_load_progress")
		await process_frame
		_reconstructed(expected, "current36_repeat_%d" % repeat)
	# This is a synthetic schema-35-FORMAT fixture from actual test actions, not a
	# historical user save or fabricated historical meetings/harvests.
	var legacy := saved.duplicate(true)
	legacy.schema_version = 35
	for field in ["sailmaker_awning_phase", "sailmaker_awning_sewing_elapsed", "sailmaker_awning_install_elapsed"]:
		legacy.erase(field)
	_check(bool(saves.save_state(legacy).get("ok", false)), "old-format fixture must pass normal save validation")
	await _drop()
	await _spawn()
	_reconstructed(expected, "synthetic35_fresh")
	for repeat in range(2):
		game.call("_load_progress")
		await process_frame
		_reconstructed(expected, "synthetic35_repeat_%d" % repeat)
	await _drop()
	# Optional actual PRE-EDIT envelope captured under a unique test slot. Copy it
	# read-only into this test's throwaway slot; never mutate the input fixture.
	var old_fixture := OS.get_environment("ARK_NIGHT_OLD_TEST_SAVE")
	if not old_fixture.is_empty():
		saves.clear_for_test()
		var file := FileAccess.open(saves.get_save_path(), FileAccess.WRITE)
		assert(file != null)
		file.store_string(FileAccess.get_file_as_string(old_fixture))
		file.close()
		var loaded: Dictionary = saves.load_state()
		_check(bool(loaded.get("ok", false)), "actual pre-edit test save must pass checksum/schema validation")
		if loaded.get("ok", false):
			await _spawn()
			var old_expected := _semantics(loaded.state)
			_reconstructed(old_expected, "actual_pre_edit_fresh")
			for repeat in range(2):
				game.call("_load_progress")
				await process_frame
				_reconstructed(old_expected, "actual_pre_edit_repeat_%d" % repeat)
			await _drop()
	saves.clear_for_test()
	if failures == 0:
		print("ARK_NIGHT_LIGHTING_TEST_OK: 12 OLD output/material contracts; NIGHT profile and attenuation; unchanged home lamps/exposure; independently validated coast Sun shadows/calibration; complete same-state save preservation; current36/repeated/synthetic35 reconstruction. Readability requires separate renderer review.")
	else:
		print("ARK_NIGHT_LIGHTING_TEST_RED: failures=", failures)
	quit(1 if failures > 0 else 0)
