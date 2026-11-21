extends RefCounted
## Optional Forward+ atmosphere: a common daylight key and distant thin air.
## No spotlight/cone is invented where the scene has no plausible opening.
var owned_root: Node3D
var mist: FogVolume
var environment: Environment
var saved_environment: Dictionary = {}
var day_overrides: Array[Dictionary] = []
var base_sun_volume := 1.0
var lantern: OmniLight3D
var base_lantern_volume := 1.0
var base_lantern_shadow := false
var active := false
var actor_fill: DirectionalLight3D
var actor_layer := 0
var actor_masks: Dictionary = {}

func capture(_world: Node3D) -> void:
	# The weather owner may already have assigned the next phase. Do not put
	# yesterday's daylight back over a new moon/ambient value.
	_release_day_overrides()

func _release_day_overrides() -> void:
	for record in day_overrides:
		var target: Object = record.target.get_ref()
		if is_instance_valid(target) and target.get(record.property) == record.authored:
			target.set(record.property, record.original)
	day_overrides.clear()

func _own_day_value(target: Object, property: String, value: Variant) -> void:
	var original: Variant = target.get(property)
	target.set(property, value)
	# Read back native float/Color representation for exact ownership checks.
	day_overrides.append({"target": weakref(target), "property": property,
		"original": original, "authored": target.get(property)})

func apply(world: Node3D, coastal: bool) -> void:
	_release_day_overrides()
	var requested := OS.get_environment("ARK_HD2D_ATMOSPHERE") == "1"
	var supported := RenderingServer.get_current_rendering_method() == "forward_plus"
	if not requested or not supported or not coastal:
		clear(world)
		return
	var day: bool = world.day_period == world.DayPeriod.DAY
	var night: bool = world.day_period == world.DayPeriod.NIGHT
	var storm: bool = world.weather_phase == world.WeatherPhase.STORM
	# This authored pass covers day/night only; dawn/dusk keep their base look.
	if (not day and not night) or (day and storm):
		clear(world)
		return
	if not active:
		environment = world.weather_environment
		for key in ["glow_enabled", "volumetric_fog_enabled", "volumetric_fog_density", "volumetric_fog_albedo", "volumetric_fog_emission_energy", "volumetric_fog_ambient_inject", "volumetric_fog_gi_inject", "volumetric_fog_anisotropy", "volumetric_fog_length", "volumetric_fog_detail_spread", "volumetric_fog_sky_affect", "volumetric_fog_temporal_reprojection_enabled"]:
			saved_environment[key] = environment.get(key)
		base_sun_volume = world.sun_light.light_volumetric_fog_energy
		active = true
	if not is_instance_valid(owned_root):
		owned_root = Node3D.new(); owned_root.name = "HD2DAtmosphere"
		world.ark_root.add_child(owned_root)
		mist = FogVolume.new(); mist.name = "LocalScattering"
		mist.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		mist.material = FogMaterial.new()
		owned_root.add_child(mist)
	environment.glow_enabled = false
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.0
	environment.volumetric_fog_albedo = Color(.95,.96,.94)
	environment.volumetric_fog_emission_energy = 0.0
	environment.volumetric_fog_ambient_inject = 0.0
	environment.volumetric_fog_gi_inject = 0.0
	environment.volumetric_fog_anisotropy = .25 if night else .15
	environment.volumetric_fog_length = 36.0
	environment.volumetric_fog_detail_spread = 2.0
	environment.volumetric_fog_sky_affect = .15
	# Avoid temporal trails on moving boats and lanterns; no camera blur added.
	environment.volumetric_fog_temporal_reprojection_enabled = false
	world.sun_light.light_volumetric_fog_energy = 0.0 if night else 4.0
	if day:
		# Keep the authoritative sun direction and weather energy ratio. One
		# brighter warm-white sun lights sea, roof and deck together.
		_own_day_value(world.sun_light, "light_energy", world.sun_light.light_energy * 2.65)
		_own_day_value(world.sun_light, "light_color", Color("fff3dc"))
		_own_day_value(world.sun_light, "shadow_opacity", .82)
		_own_day_value(environment, "ambient_light_energy", maxf(environment.ambient_light_energy, .40))
	mist.material.density = .008 if storm else .012 if night else .003
	mist.material.albedo = Color(.93,.96,1.0) if night else Color(.91,.95,1.0)
	mist.material.edge_fade = .3 if night else .6
	var current := world.ark_root.get_node_or_null("LanternMarker/RaftLanternLight") as OmniLight3D
	if current != lantern:
		if is_instance_valid(lantern):
			lantern.light_volumetric_fog_energy = base_lantern_volume
			lantern.shadow_enabled = base_lantern_shadow
		lantern = current
		if is_instance_valid(lantern):
			base_lantern_volume = lantern.light_volumetric_fog_energy
			base_lantern_shadow = lantern.shadow_enabled
	if is_instance_valid(lantern):
		lantern.light_volumetric_fog_energy = 8.0 if night else base_lantern_volume
		lantern.shadow_enabled = true if night else base_lantern_shadow
	update_geometry(world)

func update_geometry(world: Node3D) -> void:
	if not active or not is_instance_valid(owned_root): return
	var night: bool = world.day_period == world.DayPeriod.NIGHT
	if night: _clear_actor_fill()
	else: _update_actor_fill(world)
	if night and is_instance_valid(lantern):
		mist.global_position = lantern.global_position
		mist.size = Vector3(3.5,2.5,3.5)
		return
	# Broad, faint air behind the subject rather than a cloud over the player.
	# Local coordinates follow the vessel, never the camera or a spot source.
	mist.position = Vector3(0,1.5,-8)
	mist.size = Vector3(18,4,20)

func clear(world: Node3D) -> void:
	_clear_actor_fill()
	_release_day_overrides()
	if not active: return
	if is_instance_valid(owned_root): owned_root.free()
	owned_root = null; mist = null
	if is_instance_valid(environment):
		for key in saved_environment: environment.set(key, saved_environment[key])
	if is_instance_valid(world.sun_light):
		world.sun_light.light_volumetric_fog_energy = base_sun_volume
	if is_instance_valid(lantern):
		lantern.light_volumetric_fog_energy = base_lantern_volume
		lantern.shadow_enabled = base_lantern_shadow
	lantern = null; saved_environment.clear(); active = false

func _update_actor_fill(world: Node3D) -> void:
	# A free render bit is added, never substituted for an actor's own layers.
	# This light affects only pixel sprites; all geometry still casts shadows.
	if is_instance_valid(actor_fill):
		for node in world.find_children("*", "GeometryInstance3D", true, false):
			if node.layers & actor_layer and not actor_masks.has(node.get_instance_id()):
				_clear_actor_fill() # A new owner claimed the bit; reserve another.
				break
	if not is_instance_valid(actor_fill):
		var occupied := 0
		for node in world.find_children("*", "GeometryInstance3D", true, false):
			occupied |= node.layers
		actor_layer = 0
		for bit in range(19, -1, -1):
			if occupied & (1 << bit) == 0:
				actor_layer = 1 << bit
				break
		if actor_layer == 0: return # No reserved bit: do not illuminate scenery.
		actor_fill = DirectionalLight3D.new()
		actor_fill.name = "PixelSkyFill"
		actor_fill.light_cull_mask = actor_layer
		actor_fill.shadow_caster_mask = 0xffffffff
		actor_fill.shadow_enabled = true
		actor_fill.light_color = Color("cbd8e5")
		actor_fill.light_volumetric_fog_energy = 0.0
		actor_fill.light_indirect_energy = 0.0
		owned_root.add_child(actor_fill)
	for visual in world.hd2d_presentation.actors:
		if not is_instance_valid(visual) or not is_instance_valid(visual.sprite): continue
		var sprite: Sprite3D = visual.sprite
		var id := sprite.get_instance_id()
		if sprite.layers == 0 or not visual.enabled: continue
		if not actor_masks.has(id):
			var original: int = sprite.layers
			if visual._set_legacy_layers(sprite, original | actor_layer):
				actor_masks[id] = {"visual": weakref(visual), "sprite": weakref(sprite), "original": original, "authored": original | actor_layer}
	for id in actor_masks.keys():
		if not is_instance_valid(actor_masks[id].sprite.get_ref()): actor_masks.erase(id)
	# Fixed-Y billboards share this facing. Fill only the missing front light,
	# fading continuously to zero as the authoritative sun lights their face.
	var facing := Vector3(world.camera.global_basis.z.x, 0.0, world.camera.global_basis.z.z).normalized()
	var incidence: float = facing.dot(world.sun_light.global_basis.z.normalized())
	actor_fill.light_energy = .65 * (1.0 - smoothstep(0.0, .5, incidence))
	actor_fill.global_basis = Basis.looking_at(-facing + Vector3.DOWN * .7, Vector3.UP)

func _clear_actor_fill() -> void:
	if is_instance_valid(actor_fill): actor_fill.free()
	actor_fill = null
	for record in actor_masks.values():
		var visual = record.visual.get_ref()
		var sprite = record.sprite.get_ref()
		if is_instance_valid(visual) and is_instance_valid(sprite):
			# Preserve a later owner's changes, but always remove our reserved bit.
			var restored: int = record.original if sprite.layers == record.authored else sprite.layers & ~actor_layer
			visual._set_legacy_layers(sprite, restored)
	actor_masks.clear()
	actor_layer = 0
