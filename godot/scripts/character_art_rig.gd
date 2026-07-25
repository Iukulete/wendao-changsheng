class_name CharacterArtRig
extends Control

const ALLOWED_LAYER_IDS := [
	"hair_back",
	"hair_front",
	"tassel_or_ribbon",
	"outer_cloth",
	"local_fx",
]

var base_portrait: TextureRect
var layer_nodes: Dictionary = {}
var layer_specs: Array[Dictionary] = []
var profile: Dictionary = {}
var canvas_size := Vector2(1024.0, 1536.0)
var wind_axis := Vector2(1.0, 0.0)
var elapsed := 0.0
var phase := 0.0
var configured := false
var _last_size := Vector2.ZERO
var base_position := Vector2.ZERO
var offset_motion_enabled := true


func configure(base_texture: Texture2D, layers_value: Variant,
		motion_profile: Dictionary, seed_text: String = "",
		canonical_canvas_size: Vector2 = Vector2.ZERO,
		wind_axis_value: Vector2 = Vector2(1.0, 0.0)) -> void:
	_clear_art_nodes()
	profile = motion_profile.duplicate(true)
	if canonical_canvas_size.x > 0.0 and canonical_canvas_size.y > 0.0:
		canvas_size = canonical_canvas_size
	wind_axis = wind_axis_value.normalized() if wind_axis_value.length() > 0.01 else Vector2.RIGHT
	phase = float(absi(seed_text.hash()) % 6283) / 1000.0
	offset_motion_enabled = not get_parent() is Container
	if base_texture == null:
		configured = false
		return

	base_portrait = _create_texture_layer("BasePortrait", base_texture)
	base_portrait.z_index = 0
	_add_layer_specs(layers_value)
	_resize_layers()
	configured = true
	set_process(true)


func set_layout_rect(rect_position: Vector2, rect_size: Vector2) -> void:
	base_position = rect_position
	position = rect_position
	size = rect_size
	_resize_layers()


func layer_count() -> int:
	return layer_nodes.size()


func has_layer(layer_id: String) -> bool:
	return layer_nodes.has(layer_id)


func _clear_art_nodes() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	base_portrait = null
	layer_nodes.clear()
	layer_specs.clear()
	configured = false


func _create_texture_layer(layer_name: String, texture: Texture2D) -> TextureRect:
	var layer := TextureRect.new()
	layer.name = layer_name
	layer.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	layer.texture = texture
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	return layer


func _add_layer_specs(layers_value: Variant) -> void:
	if not layers_value is Array:
		return
	for value in layers_value as Array:
		if not value is Dictionary:
			continue
		var spec: Dictionary = (value as Dictionary).duplicate(true)
		var layer_id := str(spec.get("id", ""))
		var path := str(spec.get("path", ""))
		if not ALLOWED_LAYER_IDS.has(layer_id) or path.is_empty() or not ResourceLoader.exists(path):
			continue
		var texture := load(path) as Texture2D
		if texture == null:
			continue
		var layer_name := "ArtLayer_%s" % layer_id
		var layer := _create_texture_layer(layer_name, texture)
		layer.z_index = int(spec.get("z_index", 1))
		if layer_id == "local_fx":
			layer.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		layer_nodes[layer_id] = layer
		spec["id"] = layer_id
		layer_specs.append(spec)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and size != _last_size:
		_last_size = size
		_resize_layers()


func _resize_layers() -> void:
	for child in get_children():
		if child is TextureRect:
			var layer := child as TextureRect
			layer.position = Vector2.ZERO
			layer.size = size
			layer.pivot_offset = size * Vector2(0.5, 0.72)


func _process(delta: float) -> void:
	if not configured or not is_visible_in_tree() or base_portrait == null:
		return
	elapsed += delta * clampf(float(profile.get("speed", 1.0)), 0.25, 2.0)
	var breath := (sin(elapsed * 1.52 + phase) + 1.0) * 0.5
	var breath_x := clampf(float(profile.get("breath_x", 0.0015)), 0.0, 0.003)
	var breath_y := clampf(float(profile.get("breath_y", 0.004)), 0.0, 0.006)
	var sway := clampf(float(profile.get("sway_radians", 0.0012)), 0.0, 0.0018)
	var pointer := _pointer_normalized()
	var parallax := clampf(float(profile.get("portrait_parallax_px", 2.0)), 0.0, 3.0)
	var display_scale := clampf(minf(size.x / maxf(canvas_size.x, 1.0),
		size.y / maxf(canvas_size.y, 1.0)), 0.08, 1.2)
	# Keep the complete base artwork coherent; only registered transparent layers
	# receive independent wind motion below.
	pivot_offset = size * Vector2(0.5, 0.88)
	scale = Vector2(1.0 + breath * breath_x, 1.0 + breath * breath_y)
	rotation = sin(elapsed * 0.43 + phase) * sway
	if get_parent() is Container:
		offset_motion_enabled = false
	if offset_motion_enabled:
		position = base_position - pointer * parallax * 2.0 * display_scale
	else:
		position = base_position
	_apply_registered_layers(display_scale)


func _pointer_normalized() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return Vector2.ZERO
	var pointer := get_viewport().get_mouse_position() / viewport_size - Vector2(0.5, 0.5)
	return Vector2(clampf(pointer.x, -0.5, 0.5), clampf(pointer.y, -0.5, 0.5))


func _apply_registered_layers(display_scale: float) -> void:
	var axis := wind_axis.normalized()
	for spec in layer_specs:
		var layer_id := str(spec.get("id", ""))
		var layer := layer_nodes.get(layer_id) as TextureRect
		if layer == null:
			continue
		var frequency := clampf(float(spec.get("frequency", 0.72)), 0.25, 1.8)
		var layer_phase := float(spec.get("phase", 0.0))
		var wave := sin(elapsed * frequency + phase + layer_phase)
		var amplitude := clampf(float(spec.get("amplitude_px", 1.5)), 0.0, 4.0) * display_scale
		var tangent := Vector2(-axis.y, axis.x)
		var tangent_amount := clampf(float(spec.get("tangent_px", 0.35)), 0.0, 2.0) * display_scale
		layer.position = axis * wave * amplitude + tangent * cos(elapsed * frequency * 0.83 + phase + layer_phase) * tangent_amount
		var rotation_degrees := clampf(float(spec.get("rotation_deg", 0.15)), -0.6, 0.6)
		layer.rotation = sin(elapsed * frequency * 0.91 + phase + layer_phase) * deg_to_rad(rotation_degrees) * display_scale
		if layer_id == "local_fx":
			var alpha_min := clampf(float(spec.get("alpha_min", 0.02)), 0.0, 0.2)
			var alpha_max := clampf(float(spec.get("alpha_max", 0.06)), alpha_min, 0.25)
			layer.self_modulate.a = lerpf(alpha_min, alpha_max, (wave + 1.0) * 0.5)
