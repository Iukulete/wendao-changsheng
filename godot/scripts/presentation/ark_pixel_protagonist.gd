extends Node3D
## Presentation-only recovered trial. F8 compares retained 3D placeholder.
## Original PNG bytes stay unchanged; left mirrors the only supplied side sheet.
const HEIGHT := 1.65
const FPS := 7.0
const SOURCES := {
	"idle": preload("res://art/player_pixel/image(20261021-085642).png"),
	"front": preload("res://art/player_pixel/image(20261021-085643).png"),
	"back": preload("res://art/player_pixel/image(20261021-085646).png"),
	"side": preload("res://art/player_pixel/image(20261021-085645).png")}
# Explicit transparent gutters: standing thirds and back-walk 512 cells would clip sleeves.
const REGIONS := {
	"idle_front": [Rect2(0, 0, 690, 836)],
	"idle_side": [Rect2(690, 0, 490, 836)],
	"idle_back": [Rect2(1180, 0, 701, 836)],
	"front": [Rect2(0, 0, 512, 682), Rect2(512, 0, 512, 682), Rect2(1024, 0, 512, 682), Rect2(1536, 0, 512, 682)],
	"side": [Rect2(0, 0, 512, 682), Rect2(512, 0, 512, 682), Rect2(1024, 0, 512, 682), Rect2(1536, 0, 512, 682)],
	"back": [Rect2(0, 0, 540, 715), Rect2(540, 0, 505, 715), Rect2(1045, 0, 505, 715), Rect2(1550, 0, 498, 715)]}
const ANCHORS := {"idle_front": [Vector2(370, 832)], "idle_side": [Vector2(260, 832)], "idle_back": [Vector2(340, 832)],
	"front": [Vector2(250, 674), Vector2(250, 674), Vector2(255, 674), Vector2(250, 675)],
	"back": [Vector2(270, 701), Vector2(260, 701), Vector2(265, 701), Vector2(265, 701)],
	"side": [Vector2(320, 668), Vector2(305, 668), Vector2(295, 669), Vector2(290, 668)]}
const ART_HEIGHT := {"idle_front": 821.0, "idle_side": 821.0, "idle_back": 821.0, "front": 664.0, "back": 679.0, "side": 652.0}
var sprite: Sprite3D
var legacy: Node3D
var actor: CharacterBody3D
var view_camera: Camera3D
var enabled := true
var facing := "front"
var frame_index := 0
var pose_key := "idle_front"
var mirrored := false
var animation_clock := 0.0
var previous_position := Vector3.ZERO
var atlases: Dictionary = {}

func setup(body: CharacterBody3D, old_visual: Node3D, camera: Camera3D) -> void:
	actor = body
	legacy = old_visual
	view_camera = camera
	previous_position = actor.position
	name = "PixelProtagonistTrial"
	sprite = Sprite3D.new()
	sprite.name = "AuthorPixelSprite"
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.5
	sprite.no_depth_test = false
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	for direction in REGIONS:
		var frames: Array[AtlasTexture] = []
		for index in range(REGIONS[direction].size()):
			var atlas := AtlasTexture.new()
			atlas.atlas = SOURCES["idle" if direction.begins_with("idle_") else direction]
			atlas.region = REGIONS[direction][index]
			atlas.filter_clip = true
			frames.append(atlas)
		atlases[direction] = frames
	set_enabled(true)
	show_pose("idle", 0, false)

func set_enabled(value: bool) -> void:
	enabled = value
	if sprite: sprite.visible = value
	if legacy: legacy.visible = not value

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F8:
		set_enabled(not enabled)
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if actor == null or view_camera == null: return
	var displacement := actor.position - previous_position
	previous_position = actor.position
	# Physics-only sampling: intervening render frames must not reset the walk clock.
	# Local displacement excludes hull transport but includes navigation/swimming.
	update_motion(actor.get_parent_node_3d().global_basis * displacement / maxf(delta, 0.0001), delta)

func update_motion(motion: Vector3, delta: float) -> void:
	motion.y = 0.0
	if motion.length() < 0.08:
		animation_clock = 0.0
		show_pose("idle_" + facing, 0, mirrored)
		return
	var right := view_camera.global_basis.x
	var toward := view_camera.global_basis.z
	right.y = 0.0
	toward.y = 0.0
	var x := motion.dot(right.normalized())
	var y := motion.dot(toward.normalized())
	var direction := "side" if absf(x) > absf(y) else ("front" if y >= 0.0 else "back")
	if direction != facing: animation_clock = 0.0
	facing = direction
	mirrored = direction == "side" and x < 0.0
	animation_clock += delta
	show_pose(direction, int(animation_clock * FPS) % 4, mirrored)

func show_pose(direction: String, index: int, flip: bool) -> void:
	if direction == "idle": direction = "idle_" + facing
	pose_key = direction
	frame_index = index
	var atlas: AtlasTexture = atlases[direction][index]
	var anchor: Vector2 = ANCHORS[direction][index]
	sprite.texture = atlas
	sprite.pixel_size = HEIGHT / float(ART_HEIGHT[direction])
	sprite.flip_h = flip
	# Offset +Y is up. Keep authored lowest shoe at body origin; ignore tail-biased bounds.
	sprite.offset = Vector2((atlas.region.size.x * 0.5 - anchor.x) * (-1.0 if flip else 1.0), anchor.y - atlas.region.size.y * 0.5)
