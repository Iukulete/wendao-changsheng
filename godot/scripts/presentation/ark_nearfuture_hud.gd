extends Node
## QA-only, reversible presentation adapter for the existing Ark scene.
## This owns no input, gameplay timers, save service or resource ledger.
## Attach AFTER the real scene's _ready; see README.md for observer integration.

const TEXT := Color("edece3")
const MUTED := Color("b6c2c1")
const CYAN := Color("96c9cb")
const AMBER := Color("edc487")
const RED := Color("f0ada2")
const FILL := Color(0.075, 0.102, 0.112, 0.94)
const EDGE := Color(0.34, 0.43, 0.44, 0.72)
const SAFE_NAME_IDS := ["home", "helm", "storage", "workbench", "cot", "hearth", "resident", "sailmaker", "tidekeeper_box", "sailmaker_awning", "resident_keepsake", "wood", "shellfish"]
const REQUIRED_METHODS := ["_opening_objective_hint", "_day_period_label", "_storm_forecast_due", "_effective_cold_exposure_level", "_hud_choice_open"]
const REQUIRED_PROPERTIES := ["hud_panel", "hud_drawer", "hud_toggle", "hud_details", "note_panel", "note_scroll", "note", "interaction_hint", "save_status_notice", "world_chart", "player", "interactables", "day_count", "player_health", "wood", "stored_wood", "raw_shellfish", "stew_servings", "weather_phase", "is_swimming", "shelter_roof_damaged", "raft_edge_damaged", "building_mode", "editing_fixture_id", "preview_valid", "sailing_mode"]

var game: Node
var overlay: Control
var status_panel: PanelContainer
var objective_panel: PanelContainer
var alert_panel: PanelContainer
var build_panel: PanelContainer
var build_label: Label
var clock_label: Label
var health_label: Label
var weather_label: Label
var resource_label: Label
var objective_label: Label
var alert_label: Label
var keys_label: Label
var health_cells: Array[ColorRect] = []
var _property_restore: Array[Dictionary] = []
var _theme_restore: Array[Dictionary] = []
var _property_keys: Dictionary = {}
var _theme_keys: Dictionary = {}
var _world_signs: Dictionary = {}
var _last_snapshot: Dictionary = {}
var _attached := false
var _font: Font
var _health_max := 0
var _options: Dictionary = {}

## Returns false WITHOUT hiding the original HUD if this scene is incompatible.
## `compact_world_names=false` leaves every world label fully canonical.
func attach(scene: Node, options: Dictionary = {}) -> bool:
	if _attached:
		return game == scene
	if scene == null or not scene.is_inside_tree():
		push_error("Nearfuture HUD requires a ready in-tree Ark scene.")
		return false
	for method in REQUIRED_METHODS:
		if not scene.has_method(method):
			push_error("Nearfuture HUD missing method: " + method)
			return false
	var properties: Dictionary = {}
	for entry in scene.get_property_list():
		properties[str(entry.name)] = true
	for property in REQUIRED_PROPERTIES:
		if not properties.has(property):
			push_error("Nearfuture HUD missing property: " + property)
			return false
	var original_panel := scene.get("hud_panel") as Control
	if original_panel == null or not original_panel.get_parent() is CanvasLayer:
		push_error("Nearfuture HUD cannot locate the original CanvasLayer.")
		return false
	var constants: Dictionary = scene.get_script().get_script_constant_map()
	_health_max = int(constants.get("PLAYER_MAX_HEALTH", 0))
	_font = constants.get("UI_FONT") as Font
	if _health_max <= 0 or _font == null:
		push_error("Nearfuture HUD requires the canonical health limit and licensed UI_FONT.")
		return false
	game = scene
	_options = options.duplicate()
	if get_parent() == null:
		game.add_child(self)
	name = "QANearfutureHudAdapter"
	process_priority = 1000
	_build_overlay(original_panel.get_parent())
	_style_native_nodes()
	_attached = true
	refresh()
	set_process(true)
	return true

func _process(_delta: float) -> void:
	if _attached and is_instance_valid(game):
		refresh()

## Real sources, not extraction/parsing of ArkCompactStatus.text.
## Query methods are the existing read-only UI selectors; no save snapshot call.
func snapshot() -> Dictionary:
	if not is_instance_valid(game):
		return {}
	var chart := game.get("world_chart") as Control
	var drawer := game.get("hud_drawer") as Control
	var weather := int(game.get("weather_phase"))
	var weather_names := ["风雨将至", "风雨正急", "雨后"]
	var weather_text := str(weather_names[weather]) if weather >= 0 and weather < weather_names.size() else "天气状态未知"
	if bool(game.call("_storm_forecast_due")):
		weather_text = "下一场风雨已预报"
	return {
		"day": int(game.get("day_count")), "period": str(game.call("_day_period_label")),
		"health": int(game.get("player_health")), "health_max": _health_max,
		"wood_carried": int(game.get("wood")), "wood_stored": int(game.get("stored_wood")),
		"shellfish": int(game.get("raw_shellfish")), "stew": int(game.get("stew_servings")),
		"weather": weather, "weather_text": weather_text,
		"cold": int(game.call("_effective_cold_exposure_level")),
		"swimming": bool(game.get("is_swimming")),
		"roof_damaged": bool(game.get("shelter_roof_damaged")), "edge_damaged": bool(game.get("raft_edge_damaged")),
		"objective": str(game.call("_opening_objective_hint")),
		"choice_open": bool(game.call("_hud_choice_open")),
		"building": bool(game.get("building_mode")), "editing": str(game.get("editing_fixture_id")),
		"preview_valid": bool(game.get("preview_valid")), "sailing": bool(game.get("sailing_mode")),
		"chart_open": chart != null and chart.visible, "drawer_open": drawer != null and drawer.visible,
		"save_warning": str(game.get_meta("save_warning", "")),
	}

## Observer may call this after a deterministic input step, then await one frame.
func refresh() -> void:
	if not _attached:
		return
	var state := snapshot()
	_set_property(game.get("hud_panel"), "visible", false)
	overlay.visible = not bool(state.chart_open)
	if state != _last_snapshot:
		_update_content(state)
		_last_snapshot = state.duplicate()
	_layout(state)
	if bool(_options.get("compact_world_names", true)):
		_update_world_names(state)

func _build_overlay(layer: Node) -> void:
	overlay = Control.new()
	overlay.name = "QANearfutureHud"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var presentation_theme := Theme.new()
	presentation_theme.default_font = _font
	presentation_theme.default_font_size = 16
	overlay.theme = presentation_theme
	layer.add_child(overlay)
	# Keep native drawers, map, messages and save failures above the new HUD.
	layer.move_child(overlay, (game.get("hud_panel") as Node).get_index() + 1)
	status_panel = _panel("SurvivalStatus", overlay)
	var status := _vbox(status_panel, 7)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(row)
	clock_label = _label(row, "Clock", 15, MUTED)
	clock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_label = _label(row, "Health", 15, TEXT)
	var cell_row := HBoxContainer.new()
	cell_row.add_theme_constant_override("separation", 3)
	cell_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cell_row)
	for index in range(_health_max):
		var cell := ColorRect.new()
		cell.name = "HealthCell%d" % index
		cell.custom_minimum_size = Vector2(5, 13)
		cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell_row.add_child(cell)
		health_cells.append(cell)
	weather_label = _label(status, "Weather", 15, CYAN)
	var separator := HSeparator.new()
	separator.add_theme_stylebox_override("separator", _rule())
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(separator)
	resource_label = _label(status, "Resources", 15, TEXT)
	resource_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_panel = _panel("CurrentObjective", overlay)
	var objective := _vbox(objective_panel, 8)
	_label(objective, "ObjectiveCaption", 13, CYAN).text = "当前目标"
	objective_label = _label(objective, "Objective", 16, TEXT)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_panel = _panel("BuildValidity", overlay, AMBER)
	build_label = _label(build_panel, "BuildValidityText", 15, AMBER)
	build_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	alert_panel = _panel("CriticalConditions", overlay, AMBER)
	alert_label = _label(alert_panel, "Conditions", 15, AMBER)
	alert_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys_label = _label(overlay, "KeyHints", 13, MUTED)
	keys_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	keys_label.add_theme_color_override("font_shadow_color", Color("142126"))
	keys_label.add_theme_constant_override("shadow_offset_y", 1)

func _update_content(state: Dictionary) -> void:
	clock_label.text = "第 %d 天  /  %s" % [state.day, state.period]
	health_label.text = "生命 %d/%d" % [state.health, state.health_max]
	health_label.add_theme_color_override("font_color", RED if int(state.health) <= 1 else TEXT)
	for index in range(health_cells.size()):
		health_cells[index].color = (RED if int(state.health) <= 1 else CYAN) if index < int(state.health) else Color("455357")
	weather_label.text = str(state.weather_text) + ("  ·  游泳" if state.swimming else "") + ("  ·  航行中" if state.sailing else "")
	weather_label.add_theme_color_override("font_color", AMBER if int(state.weather) == 1 else CYAN)
	resource_label.text = "木料  %d 随身  /  %d 储存\n鲜贝  %d     热汤  %d" % [state.wood_carried, state.wood_stored, state.shellfish, state.stew]
	objective_label.text = str(state.objective)
	var alerts: Array[String] = []
	if int(state.health) <= 1:
		alerts.append("生命危急 · 请尽快脱离危险")
	var cold := int(state.cold)
	if cold > 0:
		var names := ["", "轻寒", "重寒", "彻骨"]
		var speeds := [100, 62, 42, 28]
		if cold < names.size():
			alerts.append("%s %d/3 · 步速 %d%%" % [names[cold], cold, speeds[cold]])
		else:
			alerts.append("寒冷等级 %d · 请查看详细状态" % cold)
	var damage: Array[String] = []
	if state.roof_damaged:
		damage.append("棚顶松脱")
	if state.edge_damaged:
		damage.append("筏舷松动")
	if not damage.is_empty():
		alerts.append("家园受损 · " + " / ".join(damage))
	alert_label.text = "\n".join(alerts)
	alert_panel.visible = not alerts.is_empty()
	# Existing controls remain unchanged, and complete help stays in native H.
	keys_label.text = "M  海图    F5  保存" if not state.building else "左键  确认    右键 / Esc  取消"
	keys_label.visible = not state.choice_open and not state.drawer_open
	objective_panel.visible = not state.drawer_open and not state.choice_open
	build_panel.visible = bool(state.building) and not state.drawer_open and not state.choice_open
	var valid := bool(state.preview_valid)
	build_label.text = ("可确认布置" if valid else "暂不可确认布置 · 请调整落点") if not str(state.editing).is_empty() else ("可放置 · 左键确认" if valid else "位置不合适 · 请在甲板承重区内选择位置")
	build_label.add_theme_color_override("font_color", CYAN if valid else AMBER)
	build_panel.add_theme_stylebox_override("panel", _box(FILL, CYAN if valid else AMBER, 14))

func _style_native_nodes() -> void:
	var note_panel := game.get("note_panel") as Control
	var note := game.get("note") as Label
	_override(note_panel, "stylebox", "panel", _box(FILL, EDGE, 14))
	_override(note, "font_size", "font_size", 16)
	_override(note, "color", "font_color", TEXT)
	_set_property(note, "custom_minimum_size", Vector2.ZERO)
	var hint := game.get("interaction_hint") as Label
	# Capture the original rectangle BEFORE changing anchors later.
	_set_property(hint, "position", hint.position)
	_set_property(hint, "size", hint.size)
	_override(hint, "stylebox", "normal", _box(FILL, EDGE, 11))
	_override(hint, "font_size", "font_size", 18)
	_override(hint, "color", "font_color", TEXT)
	_override(hint, "constant", "outline_size", 0)
	_set_property(hint, "mouse_filter", Control.MOUSE_FILTER_IGNORE)
	_set_property(hint, "vertical_alignment", VERTICAL_ALIGNMENT_CENTER)
	var save := game.get("save_status_notice") as Label
	_override(save, "stylebox", "normal", _box(Color("242c2c"), AMBER, 11))
	_override(save, "font_size", "font_size", 16)
	_override(save, "color", "font_color", AMBER)
	_override(save, "constant", "shadow_offset_x", 0)
	_override(save, "constant", "shadow_offset_y", 0)
	_set_property(save, "vertical_alignment", VERTICAL_ALIGNMENT_CENTER)
	var drawer := game.get("hud_drawer") as Control
	_override(drawer, "stylebox", "panel", _box(Color("182124"), EDGE, 14))
	for button in drawer.find_children("*", "Button", true, false):
		_style_button(button as Button)
	_style_button(game.get("hud_toggle"))
	_override(game.get("hud_details"), "color", "font_color", TEXT)
	var controls := drawer.find_child("ArkControlsHelp", true, false) as Control
	if controls:
		_override(controls, "color", "font_color", MUTED)

func _style_button(button: Button) -> void:
	_override(button, "stylebox", "normal", _box(Color("263236"), EDGE, 8))
	_override(button, "stylebox", "hover", _box(Color("34464a"), CYAN, 8))
	_override(button, "stylebox", "pressed", _box(Color("1b2b30"), CYAN, 8))
	_override(button, "stylebox", "disabled", _box(Color("20292c"), Color("3a4548"), 8))
	_override(button, "stylebox", "focus", _box(Color.TRANSPARENT, CYAN, 8))
	_override(button, "color", "font_color", TEXT)
	_override(button, "color", "font_hover_color", Color.WHITE)
	_override(button, "color", "font_disabled_color", Color("8e999a"))

func _layout(state: Dictionary) -> void:
	var screen := get_viewport().get_visible_rect().size
	var margin := 24.0
	var left_width := minf(348.0, screen.x * 0.38)
	status_panel.position = Vector2(margin, margin)
	status_panel.size = Vector2(left_width, 0)
	alert_panel.position = Vector2(margin, margin + status_panel.get_combined_minimum_size().y + 12)
	alert_panel.size = Vector2(left_width, 0)
	var objective_width := minf(348.0, screen.x * 0.34)
	objective_panel.position = Vector2(screen.x - margin - objective_width, 78)
	objective_panel.size = Vector2(objective_width, 0)
	build_panel.position = objective_panel.position + Vector2(0, objective_panel.get_combined_minimum_size().y + 8)
	build_panel.size = Vector2(objective_width, 0)
	var toggle := game.get("hud_toggle") as Control
	_set_property(toggle, "position", Vector2(screen.x - margin - 184, margin))
	_set_property(toggle, "size", Vector2(184, 38))
	var drawer := game.get("hud_drawer") as Control
	_set_property(drawer, "position", Vector2(screen.x - margin - 440, 78))
	_set_property(drawer, "size", Vector2(440, maxf(260, screen.y - 240)))
	# Preserve native scroll, source message, choice keys and build-validity text.
	var note := game.get("note") as Label
	var note_panel := game.get("note_panel") as Control
	_set_property(note_panel, "visible", not state.chart_open and (state.choice_open or state.building or not note.text.strip_edges().is_empty()))
	var message_width := minf(620.0, screen.x - margin * 2)
	if state.drawer_open:
		message_width = minf(message_width, screen.x - 440 - margin * 3)
	var message_height := 224.0 if state.choice_open or note.text.length() > 140 else (112.0 if state.building else 78.0)
	_set_property(note_panel, "position", Vector2(margin, screen.y - 150 - message_height))
	_set_property(note_panel, "size", Vector2(message_width, message_height))
	var hint := game.get("interaction_hint") as Control
	var hint_width := minf(590.0, screen.x - margin * 2)
	_set_property(hint, "anchor_left", 0.0)
	_set_property(hint, "anchor_right", 0.0)
	_set_property(hint, "anchor_top", 0.0)
	_set_property(hint, "anchor_bottom", 0.0)
	_set_property(hint, "position", Vector2((screen.x - hint_width) / 2, screen.y - 66))
	_set_property(hint, "size", Vector2(hint_width, 42))
	var save := game.get("save_status_notice") as Control
	_set_property(save, "position", Vector2(margin, screen.y - (76 if state.chart_open else 138)))
	_set_property(save, "size", Vector2(screen.x - margin * 2, 62))
	keys_label.position = Vector2(screen.x - margin - 310, screen.y - 24)
	keys_label.size = Vector2(310, 22)

## Only a narrow whitelist of ordinary Name labels is reduced. Danger signs,
## reef/vent markers, unknown labels, meshes and the real focus ring are untouched.
## At most the focused household label + nearby residents/supplies remain.
func _update_world_names(state: Dictionary) -> void:
	# Rebuilt fixtures retire Name nodes. Keep live/off-tree restore records,
	# but do not accumulate expired weak-reference metadata across reloads.
	for key in _world_signs.keys():
		if not is_instance_valid(_world_signs[key].node.get_ref()):
			_world_signs.erase(key)
	var actor := game.get("player") as Node3D
	if actor == null:
		return
	var entries: Array = game.get("interactables")
	var focus: Node3D = null
	var nearest := 2.8
	for entry in entries:
		var reference: Variant = entry.get("node")
		if not is_instance_valid(reference) or not reference is Node3D:
			continue
		var target := reference as Node3D
		var distance := actor.global_position.distance_to(target.global_position)
		if distance < nearest:
			nearest = distance
			focus = target
	for entry in entries:
		var reference: Variant = entry.get("node")
		var id := str(entry.get("id", ""))
		if not is_instance_valid(reference) or not reference is Node3D or not id in SAFE_NAME_IDS:
			continue
		var target := reference as Node3D
		var sign := target.get_node_or_null("Name") as Label3D
		if sign == null:
			continue
		var key := sign.get_instance_id()
		if not _world_signs.has(key):
			_world_signs[key] = {"node": weakref(sign), "visible": sign.visible}
		var originally_visible := bool(_world_signs[key].visible)
		var distance := actor.global_position.distance_to(target.global_position)
		var nearby_identity := (id in ["resident", "sailmaker"] and distance <= 7.0) or (id in ["wood", "shellfish"] and distance <= 4.0)
		sign.visible = originally_visible and (target == focus or nearby_identity) and not state.chart_open

## Reversible disposal: re-enable original UI/layout, do NOT reset world state.
func detach() -> void:
	if not _attached:
		return
	set_process(false)
	_attached = false
	for record in _world_signs.values():
		var sign: Object = record.node.get_ref()
		if is_instance_valid(sign):
			sign.set("visible", record.visible)
	for record in _theme_restore:
		var control: Object = record.node.get_ref()
		if not is_instance_valid(control):
			continue
		if record.had:
			control.call("add_theme_" + record.kind + "_override", record.key, record.value)
		else:
			control.call("remove_theme_" + record.kind + "_override", record.key)
	for record in _property_restore:
		var node: Object = record.node.get_ref()
		if is_instance_valid(node) and record.key not in ["position", "size"]:
			node.set(record.key, record.value)
	for record in _property_restore:
		var node: Object = record.node.get_ref()
		if is_instance_valid(node) and record.key in ["position", "size"]:
			node.set(record.key, record.value)
	if is_instance_valid(overlay):
		overlay.queue_free()
	if is_instance_valid(game) and game.is_inside_tree() and not game.is_queued_for_deletion():
		game.call("_layout_hud_panels")
	_world_signs.clear()
	_property_restore.clear()
	_theme_restore.clear()
	_property_keys.clear()
	_theme_keys.clear()
	_last_snapshot.clear()
	health_cells.clear()
	game = null

func _exit_tree() -> void:
	detach()

func _set_property(node: Object, key: String, value: Variant) -> void:
	var id := "%d:%s" % [node.get_instance_id(), key]
	if not _property_keys.has(id):
		_property_keys[id] = true
		_property_restore.append({"node": weakref(node), "key": key, "value": node.get(key)})
	if node.get(key) != value:
		node.set(key, value)

func _override(control: Control, kind: String, key: String, value: Variant) -> void:
	var id := "%d:%s:%s" % [control.get_instance_id(), kind, key]
	if not _theme_keys.has(id):
		_theme_keys[id] = true
		var had := bool(control.call("has_theme_" + kind + "_override", key))
		var original: Variant = control.call("get_theme_" + kind, key) if had else null
		_theme_restore.append({"node": weakref(control), "kind": kind, "key": key, "had": had, "value": original})
	control.call("add_theme_" + kind + "_override", key, value)

func _panel(node_name: String, parent: Node, accent: Color = EDGE) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box(FILL, accent, 14))
	parent.add_child(panel)
	return panel

func _vbox(parent: Node, spacing: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", spacing)
	parent.add_child(box)
	return box

func _label(parent: Node, node_name: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _box(fill: Color, edge: Color, padding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box

func _rule() -> StyleBoxLine:
	var line := StyleBoxLine.new()
	line.color = EDGE
	line.thickness = 1
	return line
