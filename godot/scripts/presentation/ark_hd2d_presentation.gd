extends Node
## First migration slice: opt out with ARK_HD2D=0. No persistent game fields.
const Art = preload("res://scripts/presentation/ark_hd2d_art.gd")
const Look = preload("res://scripts/presentation/ark_hd2d_look.gd")
# Bounded oblique world view. Do not inherit Camera3D's 4000 m general-purpose range.
# Orthographic directional shadows use camera far, not the light's max distance.
const ORTHOGRAPHIC_FAR := 256.0
var look = Look.new()
var far_reef_art = preload("res://scripts/presentation/ark_far_reef_art.gd").new()
const Actor = preload("res://scripts/presentation/ark_hd2d_actor.gd")
var tiles: Dictionary = {}
var paper_materials: Array[WeakRef] = []
var game: Node3D
var actors: Array[Node3D] = []
var enabled := true
var enhanced := false
var styled: Dictionary = {}
var style_clock := 0.0
var material_cache: Dictionary = {}
var material_sources: Dictionary = {}

func setup(controller: Node3D) -> void:
	# Release only this local candidate before a controller change or early return.
	far_reef_art.restore()
	# Restore optional light ownership before re-setup or HD2D opt-out.
	if is_instance_valid(game): look.atmosphere.clear(game)
	name = "HD2DPresentation"
	game = controller
	enabled = OS.get_environment("ARK_HD2D") != "0"
	if not enabled: return
	for tile in ["dock_planks", "roof_shingles", "cabin_boards"]: tiles[tile] = Art.texture(tile + ".png")
	if Art.detailed():
		for tile in ["canvas_seagreen", "stone_blocks", "rock_pixel"]: tiles[tile] = Art.texture(tile + ".png")
	var old_trial: Node = game.player.get_node_or_null("PixelProtagonistTrial")
	if old_trial:
		old_trial.set_enabled(false)
		old_trial.set_process_unhandled_key_input(false)
		old_trial.set_physics_process(false)
	game.avatar_visual.set_physics_process(false)
	enhanced = RenderingServer.get_current_rendering_method() == "forward_plus"
	game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game.camera.far = ORTHOGRAPHIC_FAR
	game.camera.size = 12.5
	var attributes := CameraAttributesPractical.new()
	game.camera.attributes = attributes
	if enhanced:
		game.weather_environment.ssao_enabled = true
		game.weather_environment.ssao_radius = .65
		game.weather_environment.ssao_intensity = .35
		game.weather_environment.glow_enabled = true
		game.weather_environment.glow_intensity = .22
	look.preset = "neutral" if OS.get_environment("ARK_HD2D_LOOK") == "neutral" else "coastal"
	look.capture(game)
	# The very first frame already needs the oblique basis (orthographic rays
	# are parallel); paused/menu-owned physics must not leave a horizontal ray.
	game._update_follow_camera()
	look.update_focus(game, enhanced)
	_attach(game.player, game.avatar_visual, "player")
	_attach(game.traveler_marker, game.traveler_body, "tidekeeper")
	_attach(game.sailmaker_marker, game.sailmaker_body, "sailmaker")
	_attach(game.jade_sail_keeper_marker, game.jade_sail_keeper_body, "keeper")
	_style_world(game)
	far_reef_art.apply(game)

func _attach(body: Node3D, legacy: Node3D, id: String) -> void:
	if not is_instance_valid(legacy): return
	if not is_instance_valid(body):
		body = legacy.get_parent_node_3d()
		if body.name == "CoastVisualGroundOffset": body = body.get_parent_node_3d()
	if legacy.has_node("HD2DPixelActor"): return
	var visual := Actor.new()
	legacy.add_child(visual)
	visual.setup(body, legacy, game.camera, game, id)
	actors.append(visual)

func _process(delta: float) -> void:
	if not enabled or not is_instance_valid(game): return
	# Preserve wheel zoom/right-drag accessibility and camera-relative controls.
	# Default is a stable oblique view; only deliberate input changes the rig.
	game.camera.size = clampf(game.orbit_camera.distance * .9253, 6.0, 24.0)
	look.update_focus(game, enhanced)
	style_clock += delta
	if style_clock >= .5:
		style_clock = 0.0
		_prune_caches()
		_update_paper_emission()
		_style_world(game.ark_root)
		_attach(game.traveler_marker, game.traveler_body, "tidekeeper")
		_attach(game.sailmaker_marker, game.sailmaker_body, "sailmaker")

func weather_changed() -> void:
	if enabled:
		look.capture(game)
		_update_paper_emission()

func _unhandled_key_input(event: InputEvent) -> void:
	if enabled and event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_F9 or event.physical_keycode == KEY_F9):
		look.set_preset(game, "neutral" if look.preset == "coastal" else "coastal")
		look.update_focus(game, enhanced)
		_update_paper_emission()
		print("ARK_HD2D_LOOK: " + look.preset)
		get_viewport().set_input_as_handled()

func _update_paper_emission() -> void:
	for index in range(paper_materials.size()-1,-1,-1):
		var material := paper_materials[index].get_ref() as ShaderMaterial
		if material == null: paper_materials.remove_at(index)
		else: material.set_shader_parameter("window_energy", look.window_energy)

func _prune_caches() -> void:
	for node in styled.keys():
		if not is_instance_valid(node): styled.erase(node)
	actors = actors.filter(func(actor): return is_instance_valid(actor))
	# Reversible home-art rebuilds create new source resources. Keep only a weak
	# source reference so repeated comparison toggles cannot retain dead clones.
	for key in material_sources.keys():
		if material_sources[key].get_ref() == null:
			material_sources.erase(key)
			material_cache.erase(key)

func refresh_materials() -> void:
	far_reef_art.restore()
	if enabled:
		_style_world(game)
		far_reef_art.apply(game)
		_prune_caches()
		_update_paper_emission()

func _detail_surface(node: MeshInstance3D) -> String:
	# Explicit authored part roles, not broad searches across gameplay props.
	var part := str(node.name)
	var parent_part := str(node.get_parent().name)
	if Art.identities():
		if parent_part == "Top" and str(node.get_parent().get_parent().name) == "BuiltWorkbench": return "workbench_top_112x78"
		if part == "Bedroll" and parent_part == "Berth" and str(node.get_parent().get_parent().name) == "BuiltRaftExtension": return "bedroll_top_96x68"
	if part in ["RoofCanvasPatchSeam", "RoofRidgeBinding", "CanvasSeamBindings"]: return "preserve"
	if part in ["RoofCanvasPatch", "CanvasPatch"]: return "canvas_patch"
	if part in ["PatchedCanvas", "EntranceCanvas", "CanvasAwning"]: return "canvas_seagreen"
	if parent_part in ["ShoreRockA", "ShoreRockB", "FarReefRockA", "FarReefRockB"]: return "rock_pixel"
	if parent_part == "HearthStone": return "stone_blocks"
	return ""

func _style_world(node: Node) -> void:
	# Placement ghosts own their validity colors/transparency; never restyle them.
	if "preview" in str(node.name).to_lower(): return
	if node is MeshInstance3D and not far_reef_art.owns_material(node) and styled.get(node) != node.material_override:
		var mat: Material = node.material_override
		var path := str(node.get_path()).to_lower()
		var tile := ""
		if "rafttop" in path or "floorplank" in path or "gangplank" in path: tile = "dock_planks"
		elif "roof" in path and not "collision" in path: tile = "roof_shingles"
		elif "wall" in path and not "collision" in path: tile = "cabin_boards"
		var detail := _detail_surface(node) if Art.detailed() else ""
		if detail == "preserve": tile = ""
		elif detail != "": tile = detail
		var furniture_top := tile in ["workbench_top_112x78", "bedroll_top_96x68"]
		if furniture_top and (not mat is ShaderMaterial or mat.shader.resource_path not in ["res://shaders/ark_home_joinery.gdshader","res://shaders/ark_home_canvas.gdshader"]):
			# Other base material/unknown imported UVs: leave it alone, don't fake sides.
			tile = ""
			furniture_top = false
		var paper_window := Art.refined() and "/builtshelter/back/" in path
		if "/builtshelter/back/" in path or "/builtshelter/left/" in path or "/builtshelter/right/" in path: tile = "cabin_boards"
		var terrain: bool = mat is ShaderMaterial and mat.shader.resource_path in ["res://shaders/ark_coast_textured.gdshader", "res://shaders/ark_coast_home_sample.gdshader"]
		# Home-art duplicates coast resources then replaces their shader; inherited
		# metadata alone cannot prove that a terrain resource is still HD2D.
		var role := "terrain" if terrain else "paper_window" if paper_window else tile
		if mat and (tile != "" or terrain) and (terrain or mat.get_meta("ark_hd2d_role", "") != role):
			var key := str(mat.get_instance_id()) + ":" + role
			if role == "canvas_patch" or furniture_top: key += str(node.mesh.get_aabb())
			if not material_cache.has(key):
				material_sources[key] = weakref(mat)
				if terrain:
					var copy := ShaderMaterial.new()
					copy.shader = preload("res://shaders/ark_hd2d_terrain.gdshader")
					copy.set_shader_parameter("grass", Art.texture("grass_pixel.png"))
					copy.set_shader_parameter("sand", Art.texture("sand_pixel.png"))
					copy.set_shader_parameter("rock", Art.texture("rock_pixel.png"))
					copy.set_meta("ark_hd2d_role", role)
					material_cache[key] = copy
				elif furniture_top:
					var copy := mat.duplicate() as ShaderMaterial
					var bounds: AABB = node.mesh.get_aabb()
					copy.set_shader_parameter("hd2d_top_enabled", true)
					copy.set_shader_parameter("hd2d_top", Art.texture(role + ".png"))
					copy.set_shader_parameter("hd2d_min", bounds.position)
					copy.set_shader_parameter("hd2d_size", bounds.size)
					copy.set_meta("ark_hd2d_role", role)
					material_cache[key] = copy
				elif role == "canvas_patch":
					var copy := ShaderMaterial.new()
					copy.shader = preload("res://shaders/ark_hd2d_canvas_patch.gdshader")
					copy.set_shader_parameter("cloth", tiles.canvas_seagreen)
					copy.set_shader_parameter("repair", Art.texture("canvas_seagreen_repaired.png"))
					copy.set_shader_parameter("bounds", node.mesh.get_aabb().size)
					copy.set_meta("ark_hd2d_role", role)
					material_cache[key] = copy
				elif paper_window:
					var copy := ShaderMaterial.new()
					copy.shader = preload("res://shaders/ark_hd2d_paper_wall.gdshader")
					copy.set_shader_parameter("boards", tiles.cabin_boards)
					copy.set_shader_parameter("paper_window", Art.texture("cabin_window_warm.png"))
					copy.set_shader_parameter("window_energy", look.window_energy)
					copy.set_meta("ark_hd2d_role", role)
					paper_materials.append(weakref(copy))
					material_cache[key] = copy
				else:
					var copy := mat.duplicate() as StandardMaterial3D if mat is StandardMaterial3D else StandardMaterial3D.new()
					copy.albedo_texture = tiles[tile]
					copy.albedo_color = Color.WHITE
					copy.uv1_triplanar = true
					copy.uv1_world_triplanar = false
					copy.uv1_scale = Vector3.ONE / (.8 if tile == "canvas_seagreen" else 1.8)
					copy.roughness = .98 if tile == "canvas_seagreen" else .9
					if tile == "canvas_seagreen": copy.metallic_specular = .08
					copy.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
					copy.set_meta("ark_hd2d_role", role)
					material_cache[key] = copy
			node.material_override = material_cache[key]
		styled[node] = node.material_override
	for child in node.get_children(): _style_world(child)
