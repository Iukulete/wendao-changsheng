extends Node
## Presentation only. The original Button remains the sole action, focus,
## shortcut, disabled-state and tooltip owner; its text is the source of truth.
## Attach AFTER other button styling. Detach BEFORE those styles are restored.
const Tooltip = preload("res://scripts/presentation/ark_management_tooltip.gd")
const Type = preload("res://scripts/presentation/ark_ui_type.gd")
const TITLE_SIZE := 16
const DETAIL_SIZE := 15
const COST_SIZE := 16
const MIN_HEIGHT := 40.0
const INSET := 14.0
const VERTICAL_INSET := 8.0
const COLUMN_WIDTH := 112.0
const COLUMN_GAP := 14.0
const LINE_GAP := 3.0
const HELP_DWELL_MSEC := 500
const HELP_TRANSFER_MSEC := 250
const TEXT := Color("e6e0cc")
const DETAIL := Color("bbb9a5")
const DISABLED_TEXT := Color("a3afa2")
const DISABLED_DETAIL := Color("99a69a")
const FONT_COLORS := ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color", "font_focus_color", "font_outline_color", "font_shadow_color"]

var rows: Array[Dictionary] = []
var _root: Node
var _font: Font = Type.face(500)
var _detail_font: Font = Type.face(400)
var _restore: Array[Dictionary] = []
var _attached := false
var _help_surface: WeakRef
var _help_candidate: WeakRef
var _help_candidate_since := 0
var _help_last_valid_msec := 0
var _help_state: Dictionary = {"active": false, "title": "", "text": "", "source_id": 0}
var _help_buttons: Dictionary = {}
# Only confirmed pointer/source or pointer/surface observations set this origin.
var _help_from_pointer := false
var _help_pointer_focus_id := 0

## Does not reparent, replace, connect, disconnect or activate any Button.
func attach(action_root: Node) -> bool:
	if _attached:
		return _root == action_root
	if action_root == null:
		return false
	_root = action_root
	name = "ArkManagementActions"
	if get_parent() == null:
		action_root.add_child(self)
	_collect(action_root)
	_attached = true
	process_priority = 990 # Observe input before the HUD presentation pass (1000).
	refresh()
	set_process(true)
	return true

func _process(_delta: float) -> void:
	refresh()

## Useful immediately after _update_hud in deterministic UI tests. The regular
## observer also catches text/disabled updates without changing their writers.
func refresh() -> void:
	if not _attached:
		return
	for row in rows:
		if not is_instance_valid(row.button):
			continue
		var button := row.button as Button
		var state := [button.text, button.size, button.disabled, button.get_draw_mode()]
		if state == row.last:
			continue
		row.last = state
		_present(row)
	_update_context_help()

## Source-side help state only. HUD owns the independent visible description
## surface and original note visibility; neither note text nor scroll lives here.
func set_help_surface(surface: Control) -> void:
	_help_surface = weakref(surface) if is_instance_valid(surface) else null

func context_help() -> Dictionary:
	if not _help_scope_visible():
		return _empty_help()
	if _help_state.active and not _source_available(_candidate_button()):
		return _empty_help()
	return _help_state.duplicate() # Callers cannot mutate internal state.

func _empty_help() -> Dictionary:
	return {"active": false, "title": "", "text": "", "source_id": 0}

func _clear_context_help() -> void:
	_help_from_pointer = false
	_help_pointer_focus_id = 0
	_help_state = _empty_help()
	_help_candidate = null
	_help_candidate_since = 0
	_help_last_valid_msec = 0

func _help_scope_visible() -> bool:
	return _attached and is_instance_valid(_root) and _root.is_inside_tree() \
		and not _root.is_queued_for_deletion() and (not _root is CanvasItem or _root.is_visible_in_tree())

func _candidate_button() -> Button:
	var candidate := _help_candidate.get_ref() as Button if _help_candidate != null else null
	return candidate if is_instance_valid(candidate) else null

func _source_available(button: Button) -> bool:
	if not is_instance_valid(button) or not button.is_inside_tree() or button.is_queued_for_deletion() \
		or button.get_script() != Tooltip \
		or not button.is_visible_in_tree() or not _help_buttons.has(button.get_instance_id()) \
		or not is_instance_valid(_root) or not _root.is_ancestor_of(button):
		return false
	var visible_rect := button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, button.size)
	visible_rect = visible_rect.intersection(button.get_viewport().get_visible_rect())
	var ancestor := button.get_parent()
	while ancestor != null and ancestor != button.get_viewport():
		if ancestor is Control and ancestor.clip_contents:
			visible_rect = visible_rect.intersection(ancestor.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, ancestor.size))
		ancestor = ancestor.get_parent()
	return visible_rect.has_area() and not button.tooltip_text.strip_edges().is_empty()

func _managed_button(control: Control) -> Button:
	var node: Node = control
	while is_instance_valid(node):
		if node is Button and _help_buttons.has(node.get_instance_id()):
			return node if _source_available(node) else null
		if node == _root:
			break
		node = node.get_parent()
	return null

func _pointer_inside(control: Control, actual_hover: Control) -> bool:
	if not is_instance_valid(control) or not is_instance_valid(actual_hover) or not control.is_visible_in_tree() \
		or (actual_hover != control and not control.is_ancestor_of(actual_hover)):
		return false
	if not Rect2(Vector2.ZERO, control.size).has_point(control.get_local_mouse_position()):
		return false
	var node := control.get_parent()
	while node != null and node != control.get_viewport():
		if node is Control and node.clip_contents and not Rect2(Vector2.ZERO, node.size).has_point(node.get_local_mouse_position()):
			return false
		node = node.get_parent()
	return true

func _action_input_held() -> bool:
	if (Input.get_mouse_button_mask() & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)) != 0:
		return true
	if Input.is_action_pressed(&"ui_accept"):
		return true
	# Real Input covers toggle buttons. Ordinary Buttons additionally expose
	# their actual held draw state, including Viewport.push_input component QA.
	# A latched toggle is NOT a held gesture and must remain readable.
	for reference: WeakRef in _help_buttons.values():
		var button := reference.get_ref() as Button
		if is_instance_valid(button) and not button.toggle_mode and button.get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]:
			return true
	return false

func _publish_help(button: Button) -> void:
	_help_state = {"active": true, "title": split_source(button.text).title,
		"text": button.tooltip_text, "source_id": button.get_instance_id()}

func _dwell_on(button: Button, now: int) -> void:
	if button != _candidate_button():
		_help_candidate = weakref(button)
		_help_candidate_since = now
		_help_state = _empty_help()
	_help_last_valid_msec = now
	if now - _help_candidate_since >= HELP_DWELL_MSEC:
		_publish_help(button)

func _inert_transfer_hover(control: Control) -> bool:
	# This grants no new hit region. Only a short visibility grace period lets
	# the pointer traverse layout padding between the row and reading surface.
	if control == null:
		return true
	if control is ScrollContainer:
		return is_instance_valid(_root) and control.is_ancestor_of(_root)
	return control is Container or control is Panel

# Geometry is used only to withdraw an old explanation, never to establish
# a hover, focus, candidate, dwell or action. Scope is the original row registry.
func _pointer_over_other_registered_row(cached_hover: Control, viewport: Viewport) -> bool:
	var point := viewport.get_mouse_position()
	if not viewport.get_visible_rect().has_point(point):
		return false
	var current := _candidate_button()
	for reference: WeakRef in _help_buttons.values():
		var button := reference.get_ref() as Button
		if not is_instance_valid(button) or button == current or button == cached_hover \
			or button.is_ancestor_of(cached_hover) or not button.is_inside_tree() or button.is_queued_for_deletion() \
			or not button.is_visible_in_tree() or button.get_viewport() != viewport \
			or not _root.is_ancestor_of(button) or button.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		# Disabled and foreign-script original rows are deliberately included.
		# They can negate the old description without becoming help sources.
		var transform := button.get_global_transform_with_canvas()
		if is_zero_approx(transform.determinant()) or not Rect2(Vector2.ZERO, button.size).has_point(transform.affine_inverse() * point):
			continue
		var inside_clips := true
		var ancestor := button.get_parent()
		while ancestor != null and ancestor != viewport:
			if ancestor.is_queued_for_deletion():
				inside_clips = false
				break
			if ancestor is Control and ancestor.clip_contents:
				var clip_transform: Transform2D = ancestor.get_global_transform_with_canvas()
				if is_zero_approx(clip_transform.determinant()) or not Rect2(Vector2.ZERO, ancestor.size).has_point(clip_transform.affine_inverse() * point):
					inside_clips = false
					break
			ancestor = ancestor.get_parent()
		if inside_clips:
			return true
	return false

func _update_context_help() -> void:
	if not _help_scope_visible():
		_clear_context_help()
		return
	var viewport := _root.get_viewport()
	var hovered := viewport.gui_get_hovered_control()
	var focus_owner := viewport.gui_get_focus_owner()
	var now := Time.get_ticks_msec()
	var focus_id := focus_owner.get_instance_id() if is_instance_valid(focus_owner) else 0
	var mouse_source := _managed_button(hovered)
	if mouse_source != null and not _pointer_inside(mouse_source, hovered):
		mouse_source = null
	var surface := _help_surface.get_ref() as Control if _help_surface != null else null
	var retaining_surface: bool = _help_state.active and is_instance_valid(surface) \
		and surface.is_inside_tree() and not surface.is_queued_for_deletion() and _pointer_inside(surface, hovered)
	if _action_input_held() and not retaining_surface:
		_clear_context_help()
		return
	if mouse_source != null:
		_dwell_on(mouse_source, now)
		_help_from_pointer = true
		_help_pointer_focus_id = focus_id
		return
	if retaining_surface:
		var current := _candidate_button()
		if not _source_available(current):
			_clear_context_help()
		else:
			_publish_help(current)
			_help_last_valid_msec = now
			_help_from_pointer = true
			_help_pointer_focus_id = focus_id
		return
	# A registered other row is a conservative reason to withdraw stale help.
	# Continue this pure-negative return even while inactive, so unchanged old
	# native focus cannot restart a pending source during the same mismatch.
	# Real source/surface hits above always retain their original priority.
	if is_instance_valid(hovered) and hovered.is_inside_tree() and not hovered.is_queued_for_deletion() \
		and hovered.get_viewport() == viewport and not _pointer_inside(hovered, hovered) \
		and _pointer_over_other_registered_row(hovered, viewport):
		_clear_context_help()
		return
	# A cached GUI hover that no longer contains the actual pointer is not proof
	# of a new unrelated interactive target. This is negative classification
	# only: it never establishes a source or counts toward its positive dwell.
	if not _inert_transfer_hover(hovered) and _pointer_inside(hovered, hovered):
		_clear_context_help()
		return
	var focus_source := _managed_button(focus_owner)
	if _help_from_pointer:
		# A genuine new native focus target wins immediately once neither real
		# row hover nor real reading-surface hover has priority. Losing focus to
		# null is not a new keyboard target; the existing pointer bridge remains
		# bounded. Focus-origin help has no pointer bridge at all.
		if focus_id != 0 and focus_id != _help_pointer_focus_id:
			_clear_context_help()
			if focus_source != null:
				_dwell_on(focus_source, now)
			return
		# Preserve only a previously active, still-available pointer source.
		# Do not refresh last_valid here: repeated uncertainty cannot extend250ms.
		if _help_state.active and now - _help_last_valid_msec <= HELP_TRANSFER_MSEC and _source_available(_candidate_button()):
			_publish_help(_candidate_button())
			return
		_clear_context_help()
	if focus_source != null:
		_dwell_on(focus_source, now)
		return
	_clear_context_help()

func _collect(node: Node) -> void:
	for child in node.get_children():
		if child == self:
			continue
		if child is Button:
			_add_row(child)
		else:
			_collect(child)

func _add_row(button: Button) -> void:
	_help_buttons[button.get_instance_id()] = weakref(button)
	var original := {
		"node": weakref(button), "clip_text": button.clip_text,
		"alignment": button.alignment, "minimum": button.custom_minimum_size,
		"icon": button.icon, "installed_tooltip": button.get_script() == null,
	}
	_restore.append(original)
	if original.installed_tooltip:
		button.set_script(Tooltip)
	button.clip_text = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon = null
	button.custom_minimum_size.y = maxf(MIN_HEIGHT, button.custom_minimum_size.y)
	# Hide only the duplicate native glyph drawing, never the actual Button or
	# its text, hit area, focus, disabled flag, tooltip, shortcut or signal.
	for key in FONT_COLORS:
		_override(button, "color", key, Color.TRANSPARENT)
	_override(button, "constant", "outline_size", 0)
	# Static rows read as one quiet list, not a stack of equally loud capsules.
	_override(button, "stylebox", "normal", _box(Color(0.36, 0.33, 0.24, 0.06), Color(0.38, 0.37, 0.30, 0.65)))
	_override(button, "stylebox", "hover", _box(Color("303c2a"), Color("8e8269")))
	_override(button, "stylebox", "pressed", _box(Color("40462f"), Color("c5ab79")))
	_override(button, "stylebox", "hover_pressed", _box(Color("494e34"), Color("d8bd85")))
	_override(button, "stylebox", "disabled", _box(Color.TRANSPARENT, Color(0.29, 0.30, 0.24, 0.5)))
	var focus := _box(Color.TRANSPARENT, Color("d1b780"))
	focus.set_border_width_all(1)
	_override(button, "stylebox", "focus", focus)
	var title := _label("ArkActionTitle", _font, TITLE_SIZE, TEXT)
	var detail := _label("ArkActionDetail", _detail_font, DETAIL_SIZE, DETAIL)
	button.add_child(title)
	button.add_child(detail)
	rows.append({"button": button, "title": title, "detail": detail,
		"minimum_y": maxf(MIN_HEIGHT, original.minimum.y), "last": [],
		"source": "", "separator": "", "layout": ""})

## Split only a single, unambiguous title/detail boundary. The legacy HUD
## replaces the blueprints' middle dot with one newline, so both are supported.
## Unknown/multiple separators preserve the COMPLETE source in the title.
static func split_source(source: String) -> Dictionary:
	var separator := ""
	if source.count(" · ") == 1 and not source.contains("\n"):
		separator = " · "
	elif source.count("\n") == 1 and not source.contains(" · "):
		separator = "\n"
	if not separator.is_empty():
		var index := source.find(separator)
		var title := source.substr(0, index)
		var detail := source.substr(index + separator.length())
		if not title.strip_edges().is_empty() and not detail.strip_edges().is_empty():
			return {"title": title, "detail": detail, "separator": separator}
	return {"title": source, "detail": "", "separator": ""}

func _present(row: Dictionary) -> void:
	var button := row.button as Button
	var title := row.title as Label
	var detail := row.detail as Label
	var parts := split_source(button.text)
	title.text = parts.title
	detail.text = parts.detail
	detail.visible = not detail.text.is_empty()
	row.source = button.text
	row.separator = parts.separator
	# Costs retain the title's reading size, including long multi-material costs.
	# Only secondary instructions/unlock conditions use the 15 px body face.
	var detail_points := COST_SIZE if detail.text.strip_edges().left(1).is_valid_int() else DETAIL_SIZE
	detail.add_theme_font_size_override("font_size", detail_points)
	var pressed := button.get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]
	title.add_theme_color_override("font_color", DISABLED_TEXT if button.disabled else Color("fff0d2") if pressed else TEXT)
	detail.add_theme_color_override("font_color", DISABLED_DETAIL if button.disabled else Color("d9c49b") if pressed else DETAIL)
	var width := button.size.x - INSET * 2.0
	if width < 1.0:
		return # Wait for the native container's first actual width allocation.
	var name_width := _font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
	var detail_width := _detail_font.get_string_size(detail.text, HORIZONTAL_ALIGNMENT_LEFT, -1, detail_points).x
	var use_column := detail.visible and not detail.text.contains("解锁") \
		and detail_width <= COLUMN_WIDTH and name_width <= width - COLUMN_WIDTH - COLUMN_GAP
	var title_width := width - COLUMN_WIDTH - COLUMN_GAP if use_column else width
	var title_height := _height(title.text, _font, TITLE_SIZE, title_width)
	var detail_height := _height(detail.text, _detail_font, detail_points, COLUMN_WIDTH if use_column else width) if detail.visible else 0.0
	var content_height := maxf(title_height, detail_height) if use_column else title_height + (LINE_GAP + detail_height if detail.visible else 0.0)
	var minimum_height := maxf(float(row.minimum_y), content_height + VERTICAL_INSET * 2.0)
	button.custom_minimum_size.y = minimum_height
	# The parent may have a deliberately larger minimum; center within the real
	# row after its next container sort, never put a control outside its bounds.
	var height := maxf(minimum_height, button.size.y)
	var top := (height - content_height) * 0.5
	_set_label_rect(title, Vector2(INSET, (height - title_height) * 0.5 if use_column else top), title_width, title_height)
	if use_column:
		row.layout = "columns"
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_set_label_rect(detail, Vector2(button.size.x - INSET - COLUMN_WIDTH, (height - detail_height) * 0.5), COLUMN_WIDTH, detail_height)
	elif detail.visible:
		row.layout = "stacked"
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_set_label_rect(detail, Vector2(INSET, top + title_height + LINE_GAP), width, detail_height)
	else:
		row.layout = "full"

func _set_label_rect(label: Label, position: Vector2, width: float, height: float) -> void:
	# Label clamps a simultaneous Vector2 resize against its PREVIOUS wrap
	# width's minimum. At first layout that width is zero, so a one-line title
	# can retain one character per line's height even after it becomes wide.
	# Establish the real width and query its new natural minimum before height.
	label.size.x = width
	var natural_height := label.get_minimum_size().y
	label.size.y = maxf(height, natural_height)
	label.position = position

func _height(text: String, font: Font, points: int, width: float) -> float:
	return ceilf(font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, maxf(1.0, width), points, -1,
		TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE).y)

func _label(node_name: String, font: Font, points: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.focus_mode = Control.FOCUS_NONE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_constant_override("line_spacing", 0)
	return label

func _box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.border_width_bottom = 1
	box.set_corner_radius_all(0)
	box.content_margin_left = INSET
	box.content_margin_right = INSET
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	return box

func _override(control: Control, kind: String, key: String, value: Variant) -> void:
	var had := bool(control.call("has_theme_" + kind + "_override", key))
	_restore.append({"node": weakref(control), "kind": kind, "key": key,
		"had": had, "value": control.call("get_theme_" + kind, key) if had else null})
	control.call("add_theme_" + kind + "_override", key, value)

## Leaves current canonical text, disabled state, signals and game state alone.
## Safe to call twice. Call this BEFORE the surrounding skin's own detach().
func detach() -> void:
	set_process(false)
	_attached = false
	_clear_context_help()
	_help_surface = null
	_help_buttons.clear()
	for row in rows:
		for key in ["title", "detail"]:
			if not is_instance_valid(row[key]):
				continue
			var label := row[key] as Label
			if is_instance_valid(label):
				if label.get_parent() != null:
					label.get_parent().remove_child(label)
				label.queue_free()
	for record in _restore:
		var node: Object = record.node.get_ref()
		if not is_instance_valid(node):
			continue
		if record.has("kind"):
			if record.had:
				node.call("add_theme_" + record.kind + "_override", record.key, record.value)
			else:
				node.call("remove_theme_" + record.kind + "_override", record.key)
		else:
			node.set("clip_text", record.clip_text)
			node.set("alignment", record.alignment)
			node.set("custom_minimum_size", record.minimum)
			node.set("icon", record.icon)
			if record.installed_tooltip and node.get_script() == Tooltip:
				node.set_script(null)
	rows.clear()
	_restore.clear()
	_root = null

func _exit_tree() -> void:
	detach()
