extends RefCounted
## Owns only the handbook's safe read-only focus entry. No input injection,
## command activation, gameplay state, save access or action focus changes.
var _drawer: WeakRef
var _scroll: WeakRef
var _tabs: Array[WeakRef] = []
var _records: Array[Dictionary] = []
var _prior_focus: WeakRef
var _last_open := false
var _pending_entry := false
var _last_internal_focus := false
var _old_follow_focus := false
var _attached := false

func attach(drawer: Control, tabs: Array, mode: Button, details: Button, close: Button, scroll: ScrollContainer) -> bool:
	if _attached or not is_instance_valid(drawer) or not is_instance_valid(scroll) or tabs.is_empty():
		return false
	_drawer = weakref(drawer)
	_scroll = weakref(scroll)
	_old_follow_focus = scroll.follow_focus
	scroll.follow_focus = true
	var controls: Array[Control] = []
	for tab: Button in tabs:
		_tabs.append(weakref(tab))
		controls.append(tab)
	controls.append_array([mode, details, close])
	for control: Control in controls:
		if not is_instance_valid(control) or not drawer.is_ancestor_of(control):
			detach()
			return false
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color.TRANSPARENT
		frame.draw_center = false
		frame.border_color = Color("d1b780")
		frame.set_border_width_all(1)
		frame.set_corner_radius_all(0)
		var had := control.has_theme_stylebox_override("focus")
		_records.append({"node": weakref(control), "mode": control.focus_mode,
			"had_focus_style": had, "focus_style": control.get_theme_stylebox("focus") if had else null,
			"applied_focus_style": frame})
		control.focus_mode = Control.FOCUS_ALL
		control.add_theme_stylebox_override("focus", frame)
	_attached = true
	return true

func update(open: bool, competing_modal: bool, selected: int) -> void:
	var drawer := _live(_drawer)
	if not _attached or drawer == null:
		return
	var viewport := drawer.get_viewport()
	var owner := viewport.gui_get_focus_owner()
	if open and not _last_open:
		_prior_focus = weakref(owner) if owner != null and not _inside(drawer, owner) else null
		_pending_entry = not competing_modal
		# H now owns the modal read-only surface. Cancel only the old external
		# keyboard receiver on this opening edge, so its later accept release
		# cannot activate a command behind H. Preserve it for normal close.
		if not competing_modal and Input.is_action_pressed(&"ui_accept") and owner != null and not _inside(drawer, owner):
			owner.release_focus()
		if _activation_held() and owner != null and _inside(drawer, owner):
			owner.release_focus() # Never deliver a later release to a new action.
	if not open and _last_open:
		_pending_entry = false
		_restore_on_close(drawer, competing_modal)
	if competing_modal:
		_pending_entry = false
	if open and _pending_entry and not competing_modal and not _activation_held():
		owner = viewport.gui_get_focus_owner()
		var previous := _live(_prior_focus)
		# A different external modal/control acquiring focus wins over pending H.
		if owner != null and (_inside(drawer, owner) or owner != previous):
			_pending_entry = false
		else:
			var tab := _live(_tabs[clampi(selected, 0, _tabs.size() - 1)])
			if tab != null and tab.is_visible_in_tree() and tab.focus_mode == Control.FOCUS_ALL:
				tab.grab_focus() # Only an existing read-only category can be seeded.
			_pending_entry = false
	_last_open = open
	owner = viewport.gui_get_focus_owner()
	_last_internal_focus = open and owner != null and _inside(drawer, owner)

func _restore_on_close(drawer: Control, competing_modal: bool) -> void:
	var viewport := drawer.get_viewport()
	var owner := viewport.gui_get_focus_owner()
	var was_ours := owner != null and _inside(drawer, owner)
	# Hiding an ancestor may already clear native focus before this observer runs.
	var cleared_by_hide := owner == null and _last_internal_focus
	if was_ours:
		owner.release_focus()
	if (was_ours or cleared_by_hide) and not competing_modal and not _activation_held():
		var previous := _live(_prior_focus)
		if previous != null and previous.is_visible_in_tree() and previous.focus_mode != Control.FOCUS_NONE \
			and previous.get_viewport() == viewport and not (previous is BaseButton and previous.disabled) \
			and not _inside(drawer, previous) and viewport.gui_get_focus_owner() == null:
			previous.grab_focus()
	_prior_focus = null
	_last_internal_focus = false

func _activation_held() -> bool:
	return Input.is_action_pressed(&"ui_accept") \
		or (Input.get_mouse_button_mask() & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)) != 0

func _inside(drawer: Control, control: Control) -> bool:
	return control == drawer or drawer.is_ancestor_of(control)

func _live(reference: WeakRef) -> Control:
	if reference == null:
		return null
	var control := reference.get_ref() as Control
	if not is_instance_valid(control) or not control.is_inside_tree():
		return null
	var node: Node = control
	while node != null:
		if node.is_queued_for_deletion():
			return null
		node = node.get_parent()
	return control

func detach() -> void:
	var drawer := _live(_drawer)
	if drawer != null:
		# Detach can occur before a new competing modal is observed. Never restore
		# external focus here; only a normal close may do so with live modal state.
		var owner := drawer.get_viewport().gui_get_focus_owner()
		if owner != null and _inside(drawer, owner):
			owner.release_focus()
	_pending_entry = false
	for record: Dictionary in _records:
		var control := _live(record.node)
		if control == null:
			continue
		if control.focus_mode == Control.FOCUS_ALL:
			control.focus_mode = int(record.mode)
		if control.get_theme_stylebox("focus") == record.applied_focus_style:
			if record.had_focus_style:
				control.add_theme_stylebox_override("focus", record.focus_style)
			else:
				control.remove_theme_stylebox_override("focus")
	var scroll := _live(_scroll) as ScrollContainer
	if scroll != null and scroll.follow_focus:
		scroll.follow_focus = _old_follow_focus
	_records.clear()
	_tabs.clear()
	_drawer = null
	_scroll = null
	_prior_focus = null
	_last_open = false
	_last_internal_focus = false
	_attached = false
