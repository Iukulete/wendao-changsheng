class_name CinematicArtMotion
extends Node

enum LayerMode { PORTRAIT, SCENE }

var target: Control
var mode := LayerMode.PORTRAIT
var profile: Dictionary = {}
var elapsed := 0.0
var phase := 0.0
var base_offsets := Vector4.ZERO
var offset_motion_enabled := true


func configure(control: Control, motion_profile: Dictionary, layer_mode: LayerMode,
		seed_text: String = "", allow_offset_motion: bool = true) -> void:
	target = control
	profile = motion_profile.duplicate(true)
	mode = layer_mode
	base_offsets = Vector4(target.offset_left, target.offset_top, target.offset_right, target.offset_bottom)
	offset_motion_enabled = allow_offset_motion and not target.get_parent() is Container
	phase = float(absi(seed_text.hash()) % 6283) / 1000.0
	target.pivot_offset = target.size * Vector2(0.5, 0.88 if mode == LayerMode.PORTRAIT else 0.5)
	set_process(true)


func _process(delta: float) -> void:
	if not is_instance_valid(target) or not target.is_visible_in_tree():
		return
	elapsed += delta * clampf(float(profile.get("speed", 1.0)), 0.25, 2.0)
	var viewport_size := target.get_viewport_rect().size
	var pointer := Vector2.ZERO
	if viewport_size.x > 1.0 and viewport_size.y > 1.0:
		pointer = target.get_viewport().get_mouse_position() / viewport_size - Vector2(0.5, 0.5)
	pointer.x = clampf(pointer.x, -0.5, 0.5)
	pointer.y = clampf(pointer.y, -0.5, 0.5)
	if mode == LayerMode.SCENE:
		_apply_scene_motion(pointer)
	else:
		_apply_portrait_motion(pointer)


func _apply_scene_motion(pointer: Vector2) -> void:
	var parallax := clampf(float(profile.get("scene_parallax_px", 5.0)), 0.0, 12.0)
	var overscan := clampf(float(profile.get("scene_overscan_px", 10.0)), parallax + 2.0, 18.0)
	var drift_amount := clampf(float(profile.get("drift_px", 1.0)), 0.0, 3.0)
	var drift := Vector2(sin(elapsed * 0.19 + phase), cos(elapsed * 0.16 + phase)) * drift_amount
	var offset := -pointer * parallax * 2.0 + drift
	target.offset_left = base_offsets.x - overscan + offset.x
	target.offset_top = base_offsets.y - overscan + offset.y
	target.offset_right = base_offsets.z + overscan + offset.x
	target.offset_bottom = base_offsets.w + overscan + offset.y


func _apply_portrait_motion(pointer: Vector2) -> void:
	var breath := (sin(elapsed * 1.52 + phase) + 1.0) * 0.5
	var breath_x := clampf(float(profile.get("breath_x", 0.0015)), 0.0, 0.004)
	var breath_y := clampf(float(profile.get("breath_y", 0.004)), 0.0, 0.008)
	var sway := clampf(float(profile.get("sway_radians", 0.0012)), 0.0, 0.0025)
	var parallax := clampf(float(profile.get("portrait_parallax_px", 2.0)), 0.0, 4.0)
	var offset := -pointer * parallax * 2.0
	target.pivot_offset = target.size * Vector2(0.5, 0.88)
	target.scale = Vector2(1.0 + breath * breath_x, 1.0 + breath * breath_y)
	target.rotation = sin(elapsed * 0.43 + phase) * sway
	if offset_motion_enabled:
		target.offset_left = base_offsets.x + offset.x
		target.offset_top = base_offsets.y + offset.y
		target.offset_right = base_offsets.z + offset.x
		target.offset_bottom = base_offsets.w + offset.y
