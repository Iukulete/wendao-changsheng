extends RefCounted
## Authored coast look, not a replacement for time/weather simulation.
## Warm paper/cabin accents; optional advanced atmosphere never changes geometry.
const Atmosphere = preload("res://scripts/presentation/ark_hd2d_atmosphere.gd")
var atmosphere = Atmosphere.new()
const PROFILES := [
	{"fill": Color("8faeb6"), "fog": Color("aebcb1"), "sun": Color("ffd6a4"), "density": .004, "paper": .12},
	{"fill": Color("91adb5"), "fog": Color("b1c3bc"), "sun": Color("ffe7bd"), "density": .0025, "paper": .04},
	{"fill": Color("86979e"), "fog": Color("b6aaa0"), "sun": Color("f3bb83"), "density": .005, "paper": .72},
	{"fill": Color("748ba3"), "fog": Color("435b70"), "sun": Color("8aa4c1"), "density": .006, "paper": 1.0}]
var preset := "coastal"
var base_ambient := Color.WHITE
var base_sun := Color.WHITE
var captured := false
var window_energy := 0.0
var focus_distance := 0.0

func capture(world: Node3D) -> void:
	# Called only after the existing game owner has produced its current weather.
	# Never capture our own graded result: repeated refreshes cannot compound tint.
	atmosphere.capture(world) # Release only our previous DAY values before sampling.
	base_ambient = world.weather_environment.ambient_light_color
	base_sun = world.sun_light.light_color
	captured = true
	apply(world)

func set_preset(world: Node3D, value: String) -> void:
	preset = value if value in ["coastal", "neutral"] else "coastal"
	apply(world)

func apply(world: Node3D) -> void:
	if not captured: return
	var profile: Dictionary = PROFILES[clampi(world.day_period,0,3)]
	var storm: bool = world.weather_phase == world.WeatherPhase.STORM
	var forecast: bool = world.weather_phase == world.WeatherPhase.FORECAST
	var env: Environment = world.weather_environment
	var neutral := preset == "neutral"
	# Preserve exact existing light energy and sun direction, including storm/night.
	env.ambient_light_color = base_ambient if neutral else base_ambient.lerp(profile.fill,.18)
	world.sun_light.light_color = base_sun if neutral else base_sun.lerp(profile.sun,.05 if storm else .10)
	env.fog_enabled = true
	env.fog_light_color = Color("b9ccc6") if neutral else base_ambient.lerp(profile.fog,.70)
	env.fog_density = .003 if neutral else float(profile.density) * (1.35 if storm else 1.12 if forecast else 1.0)
	env.fog_light_energy = .65 if neutral else .38 if world.day_period == world.DayPeriod.NIGHT else .55
	env.fog_sky_affect = .16
	atmosphere.apply(world, not neutral)
	window_energy = maxf(float(profile.paper),.68 if storm else 0.0)

func update_focus(world: Node3D, enhanced: bool) -> void:
	atmosphere.update_geometry(world)
	var attributes := world.camera.attributes as CameraAttributesPractical
	if attributes == null: return
	var target: Vector3 = world.player.global_position + Vector3.UP
	focus_distance = maxf(.1,(target-world.camera.global_position).dot(-world.camera.global_basis.z))
	# All nearby interaction space stays sharp. No foreground blur, no HUD shader.
	attributes.dof_blur_near_enabled = false
	attributes.dof_blur_far_distance = focus_distance + 8.0
	attributes.dof_blur_far_transition = 12.0
	attributes.dof_blur_amount = .12
	attributes.dof_blur_far_enabled = enhanced and preset == "coastal" and not world.building_mode and OS.get_environment("ARK_HD2D_DOF") != "0"
