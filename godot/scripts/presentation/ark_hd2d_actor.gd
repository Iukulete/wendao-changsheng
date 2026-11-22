extends Node3D
## Original pixel visual only. The actor, collision, legacy pose rig and work props
## remain untouched; layer masking preserves their visibility/state semantics.
const Art = preload("res://scripts/presentation/ark_hd2d_art.gd")
var textures: Dictionary = {}
var sprite: Sprite3D
var actor: Node3D
var legacy: Node3D
var camera: Camera3D
var game: Node3D
var identity := "player"
var previous_position := Vector3.ZERO
var previous_parent := 0
var clock := 0.0
var direction := 0
var pose := "idle"
var frame := 0
var masks: Dictionary = {}
var enabled := true
var cached_motion := Vector3.ZERO
var authored_pose_source: Node3D
var last_walk_direction := -1
var hd2d_pixel_size := 0.0
var hd2d_offset := Vector2.ZERO
var blink_phase := 0.0

func setup(body: Node3D, old_visual: Node3D, view: Camera3D, controller: Node3D, id: String) -> void:
	name = "HD2DPixelActor"
	actor = body
	legacy = old_visual
	camera = view
	game = controller
	identity = id
	if identity == "player":
		# The hidden, non-processing original fallback already owns the exact
		# author atlases, authored feet anchors, and side mirroring.
		authored_pose_source = actor.get_node_or_null("PixelProtagonistTrial") as Node3D
	blink_phase = {"player":0.0,"tidekeeper":.9,"sailmaker":1.8,"keeper":2.7}.get(id,0.0)
	var prefix := "protagonist_" if id == "player" else "resident_moss_" if Art.detailed() and id == "sailmaker" else "resident_"
	if Art.identities() and id in ["tidekeeper", "sailmaker", "keeper"]: prefix = id + "_"
	for state in ["atlas", "work", "sit"]: textures[state] = Art.texture(prefix + state + ".png")
	if Art.detailed(): textures["idle"] = Art.texture(prefix + "idle.png")
	if id == "player":
		for state in ["swim", "swim_idle", "helm"]: textures[state] = Art.texture(prefix + state + ".png")
	previous_position = actor.position
	previous_parent = actor.get_parent().get_instance_id()
	sprite = Sprite3D.new()
	sprite.name = "OriginalPixelVisual"
	sprite.texture = textures.atlas
	sprite.hframes = 4
	sprite.vframes = 4
	# Both atlas resolutions occupy the same world canvas and foot/water anchor.
	# Layout derives from the selected atlas, not a stale 32-pixel assumption.
	var cell: Vector2 = sprite.texture.get_size() / Vector2(4, 4)
	assert(cell in [Vector2(32,48), Vector2(64,96)])
	for atlas in textures.values(): assert(atlas.get_size() == sprite.texture.get_size())
	sprite.pixel_size = 1.92 / cell.y
	sprite.offset = Vector2(0, 1.84 / sprite.pixel_size - cell.y * .5)
	hd2d_pixel_size = sprite.pixel_size
	hd2d_offset = sprite.offset
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.5
	sprite.shaded = true
	sprite.no_depth_test = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(sprite)
	if id == "sailmaker" and not Art.detailed(): sprite.modulate = Color("c9d9b5")
	elif id == "keeper" and not Art.identities(): sprite.modulate = Color("d9bfd0")
	set_enabled(true)
	if is_instance_valid(authored_pose_source): update_visual(legacy.global_basis.z, false, 0.0)

func set_enabled(value: bool) -> void:
	enabled = value
	if sprite: sprite.visible = value
	if identity == "player" and legacy: legacy.set_physics_process(not value)
	_mask_legacy(legacy)

func _mask_legacy(node: Node) -> void:
	if node == self or node.name in ["WoodenLadle", "LadleBowl"]: return
	if node is GeometryInstance3D:
		if not masks.has(node): masks[node] = node.layers
		_set_legacy_layers(node, 0 if enabled else masks[node])
	for child in node.get_children(): _mask_legacy(child)

# Preserve Node visibility ownership (cook/wash/state props). Godot Forward+
# needs old light pairs detached before changing a live instance layer mask.
func _set_legacy_layers(node: GeometryInstance3D, target: int) -> bool:
	if not is_instance_valid(node) or node.is_queued_for_deletion(): return false
	if node.layers == target: return true
	if RenderingServer.get_current_rendering_method() != "forward_plus" or not node.is_inside_tree():
		node.layers = target
		return true
	var world := node.get_world_3d()
	var instance := node.get_instance()
	if world == null or not instance.is_valid() or not world.scenario.is_valid():
		push_error("HD2D layer mask requires a valid current World3D scenario")
		return false
	# No await: use this node's current World, never a cached parent scenario.
	RenderingServer.instance_set_scenario(instance, RID())
	node.layers = target
	RenderingServer.instance_set_scenario(instance, world.scenario)
	return true

func _physics_process(delta: float) -> void:
	if identity == "player" and is_instance_valid(actor):
		cached_motion = _sample_motion(delta)

func _process(delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(camera): return
	if identity != "player":
		for node in masks.keys():
			if not is_instance_valid(node): masks.erase(node)
		_mask_legacy(legacy)
		cached_motion = _sample_motion(delta)
	var moving := cached_motion.length() > .04 and cached_motion.length() < 25.0
	var facing := cached_motion if moving else legacy.global_basis.z
	update_visual(facing, moving, delta)

func _sample_motion(delta: float) -> Vector3:
	# Parent-local sampling excludes moving/rotating hull transport, and resets
	# across boarding/reparent events instead of inventing a walking burst.
	var parent_id := actor.get_parent().get_instance_id()
	var motion := Vector3.ZERO
	if parent_id == previous_parent:
		motion = actor.get_parent_node_3d().global_basis * (actor.position - previous_position) / maxf(delta, .0001)
	previous_position = actor.position
	previous_parent = parent_id
	motion.y = 0
	return motion

func update_visual(facing: Vector3, moving: bool, delta: float) -> void:
	var next_pose := "walk" if moving else _stationary_pose()
	if identity == "player":
		if game.sailing_mode:
			next_pose = "helm"
			# The helm faces the vessel's bow, not the actor's last walking yaw.
			# Read only: never rotate the collider or the underlying control rig.
			facing = -game.ark_root.global_basis.z
		elif game.is_swimming:
			next_pose = "swim" if moving else "swim_idle"
	var right := camera.global_basis.x
	var toward := camera.global_basis.z
	right.y = 0
	toward.y = 0
	var x := facing.dot(right.normalized())
	var y := facing.dot(toward.normalized())
	direction = (2 if x >= 0 else 1) if absf(x) > absf(y) else (0 if y >= 0 else 3)
	if next_pose != pose: clock = 0.0
	pose = next_pose
	var animated := pose in ["walk", "work", "swim", "swim_idle", "helm"] or (pose == "idle" and textures.has("idle"))
	clock = clock + maxf(delta, 0.0) if animated else 0.0
	var fps := 3.0 if pose in ["swim_idle", "helm"] else 1.0 if pose == "idle" else 7.0 if pose == "walk" else 5.0 if Art.detailed() else 6.0
	frame = int(clock * fps) % 4 if animated else 0
	# The closed-eye cell is a brief blink, not a full second asleep.
	if pose == "idle" and textures.has("idle"):
		frame = 3 if fmod(clock + blink_phase,4.0) >= 3.88 else 0
	if is_instance_valid(authored_pose_source) and pose in ["idle", "walk"]:
		if pose == "walk" or last_walk_direction < 0:
			last_walk_direction = direction
		direction = last_walk_direction
		var authored_direction: String = ["front", "side", "side", "back"][direction]
		var authored_key := "idle_" + authored_direction if pose == "idle" else authored_direction
		if pose == "idle": frame = 0
		authored_pose_source.show_pose(authored_key, frame, direction == 1)
		var authored_sprite: Sprite3D = authored_pose_source.sprite
		# Only the selected frame/foot geometry changes. Keep this single
		# HD-2D sprite's lighting/shadows; never reveal the fallback sprite.
		sprite.hframes = 1
		sprite.vframes = 1
		sprite.texture = authored_sprite.texture
		sprite.pixel_size = authored_sprite.pixel_size
		sprite.offset = authored_sprite.offset
		sprite.flip_h = authored_sprite.flip_h
		sprite.position = to_local(actor.global_position)
		return
	if is_instance_valid(authored_pose_source):
		sprite.hframes = 4
		sprite.vframes = 4
		sprite.pixel_size = hd2d_pixel_size
		sprite.offset = hd2d_offset
		sprite.flip_h = false
	sprite.texture = textures.work if pose == "work" else textures.sit if pose == "sit" else textures.atlas
	if identity == "player":
		match pose:
			"swim": sprite.texture = textures.swim
			"swim_idle": sprite.texture = textures.swim_idle
			"helm": sprite.texture = textures.helm
			"work": sprite.texture = textures.work
			"sit": sprite.texture = textures.sit
			_: sprite.texture = textures.atlas
		var anchor := actor.global_position
		if pose in ["swim", "swim_idle"]:
			anchor.y = float(game.water.query(anchor).height)
		# This cancels only legacy model import offsets, never changes actor physics.
		# Swim artwork's foot anchor is its waterline; normal artwork uses feet.
		sprite.position = to_local(anchor)
	if pose == "idle" and textures.has("idle"): sprite.texture = textures.idle
	sprite.frame = direction * 4 + frame

func _stationary_pose() -> String:
	if identity == "player": return "sit" if game._lantern_table_open() else "idle"
	if game._lantern_table_open() and str(game.lantern_table.snapshot().opponent) == identity: return "sit"
	if identity == "keeper":
		return "work" if game.jade_sail_industry_pending and game.jade_sail_industry_phase == "collecting" else "idle"
	if identity == "tidekeeper" and game.resident_gather_pending and game.resident_gather_phase == "collecting": return "work"
	# These temporary rigs are authoritatively created/cleared by job adapters.
	for child in legacy.get_children():
		if child.name in ["TemporaryKitchenWorkPose", "TemporaryWashLimbPose"]: return "work"
	if game._shared_table_ready() and identity in ["tidekeeper", "sailmaker"]: return "sit"
	var action: String = game.traveler_action if identity == "tidekeeper" else game.sailmaker_action
	if action == game.TEMPORARY_REFUGE_ACTION:
		return "sit" if game._resident_at_temporary_refuge(actor, identity) else "idle"
	var target: Vector3 = game.traveler_target_position if identity == "tidekeeper" else game.sailmaker_target_position
	var arrived: bool = actor.get_parent() == game.ark_root and actor.position.distance_to(target) < .12
	if not arrived: return "idle"
	if "歇息" in action or "歇脚" in action: return "sit"
	# Actual posed arms, including cooking/washing temporary rig, are authoritative.
	for arm_name in ["ArmLeft", "ArmRight"]:
		var arm := legacy.get_node_or_null(arm_name) as Node3D
		if arm and absf(arm.rotation.x) > .35: return "work"
	return "idle"
