extends Node
const InventoryArtwork = preload("res://scripts/presentation/ark_inventory_panel.gd")
const UiType = preload("res://scripts/presentation/ark_ui_type.gd")
const HelpKeyboard = preload("res://scripts/presentation/ark_help_keyboard_navigation.gd")
const ManagementActions = preload("res://scripts/presentation/ark_management_actions.gd")
const VoyageSkin = preload("res://scripts/presentation/ark_voyage_skin.gd")
signal choice_requested(code: int, choice_id: String)
## Reversible presentation adapter for the active Ark scene.
## This owns no input, gameplay timers, save service or resource ledger.
## Attach AFTER the real scene's _ready; see README.md for observer integration.

const BuildCard = preload("res://scripts/presentation/ark_build_card.gd")
const TEXT := Color("e5dfcb")
const MUTED := Color("acb1a3")
const CYAN := Color("a8b9a2")
const AMBER := Color("edc487")
const RED := Color("f0ada2")
const FILL := Color(0.075, 0.102, 0.112, 0.94)
const EDGE := Color(0.34, 0.43, 0.44, 0.72)
const HOUSE_ICON = preload("res://art/ui_icons/house.svg")
const HAMMER_ICON = preload("res://art/ui_icons/hammer.svg")
const PALETTE_ICON = preload("res://art/ui_icons/palette.svg")
const ALERT_ICON = preload("res://art/ui_icons/triangle-alert.svg")
const SAFE_NAME_IDS := ["home", "helm", "storage", "workbench", "cot", "hearth", "resident", "sailmaker", "tidekeeper_box", "sailmaker_awning", "resident_keepsake", "wood", "shellfish", "guest_cabin"]
# Only these ordinary home fixtures lose repeated action/status prose.
const FURNITURE_NAME_IDS := ["home", "helm", "storage", "workbench", "cot", "hearth", "tidekeeper_box", "sailmaker_awning", "resident_keepsake", "guest_cabin"]
const NPC_NAME_MIN_PIXELS := 14.0
const NPC_NAME_MAX_PIXELS := 16.0
const MANUAL_SAVE_SUCCESS_TEXT := "这一刻已经记在旧玉里。"
const MANAGEMENT_HELP_GAP := 4
const REQUIRED_METHODS := ["_opening_objective_hint", "_day_period_label", "_storm_forecast_due", "_effective_cold_exposure_level", "_hud_choice_open", "_hud_choice_view", "_nearest_interactable", "_maintenance_target"]
const REQUIRED_PROPERTIES := ["inventory_ui", "hud_panel", "hud_drawer", "hud_toggle", "hud_details", "note_panel", "note_scroll", "note", "interaction_hint", "save_status_notice", "world_chart", "player", "interactables", "day_count", "player_health", "wood", "stored_wood", "raw_shellfish", "stew_servings", "weather_phase", "is_swimming", "shelter_roof_damaged", "raft_edge_damaged", "building_mode", "editing_fixture_id", "preview_valid", "sailing_mode"]

var _save_error_style: StyleBoxFlat
var _save_success_style: StyleBoxFlat
var _help_keyboard: RefCounted
var _management_actions: Node
var management_help_panel: PanelContainer
var management_help_title: Label
var management_help_body: Label
var management_help_scroll: ScrollContainer
var _help_source_id: int = 0
var game: Node
var overlay: Control
var status_panel: PanelContainer
var objective_panel: PanelContainer
var alert_panel: Panel
var alert_icon: TextureRect
var build_panel: PanelContainer
var build_label: Label
var construction_card: Control
var clock_label: Label
var health_label: Label
var weather_label: Label
var resource_label: Label
var shell_count: Label
var soup_count: Label
var resource_glyphs: Dictionary = {}
var objective_label: Label
var alert_label: Label
var keys_label: Label
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
var _interaction_compact: PanelContainer
var _interaction_compact_title: Label
var _interaction_raw_modulate := Color.WHITE
var _interaction_measured_title := ""
var _interaction_natural_width := 0.0
var _metrics_enabled := false
var _metrics_next_msec := 0
var _metrics_text := ""
var choice_panel: PanelContainer
var choice_buttons: Array[Button] = []
var _choice_id := ""
var _choice_keys: Array[int] = []

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
		"fishing_open": game.has_method("_fishing_active") and game.call("_fishing_active"),
		"choice": game.call("_hud_choice_view"),
		"building": bool(game.get("building_mode")), "editing": str(game.get("editing_fixture_id")),
		"preview_valid": bool(game.get("preview_valid")), "sailing": bool(game.get("sailing_mode")),
		"construction": game.call("_build_presentation_state") if game.has_method("_build_presentation_state") else {},
		"build_feedback": str(game.call("_build_preview_feedback")) if game.has_method("_build_preview_feedback") else "",
		"chart_open": chart != null and chart.visible, "drawer_open": drawer != null and drawer.visible,
		"inventory_open": game.inventory_ui.active(),
		"save_warning": str(game.get_meta("save_warning", "")),
		"beast_windup": game.has_method("_reef_beast_windup_visible") and bool(game.call("_reef_beast_windup_visible")),
		"storm_forecast": bool(game.call("_storm_forecast_due")),
	}

## Observer may call this after a deterministic input step, then await one frame.
func refresh() -> void:
	if not _attached:
		return
	var state := snapshot()
	if _help_keyboard != null:
		_help_keyboard.update(bool(state.drawer_open), bool(state.inventory_open) or bool(state.chart_open) or bool(state.choice_open) or bool(state.fishing_open), int(game.player_guide.selected))
	_set_property(game.get("hud_panel"), "visible", false)
	overlay.visible = not bool(state.chart_open)
	if state != _last_snapshot:
		_update_content(state)
		_last_snapshot = state.duplicate()
	_layout(state)
	if bool(_options.get("compact_world_names", true)):
		_update_world_names(state)
	else:
		_restore_world_names()
	if _metrics_enabled:
		var now := Time.get_ticks_msec()
		if now >= _metrics_next_msec:
			_metrics_next_msec = now + 500
			var fps := Engine.get_frames_per_second()
			var process_ms := maxf(0.0, Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
			var calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			_metrics_text = "FPS %d · 帧均值约 %.1f ms · Process %.2f ms · 绘制 %d" % [fps, 1000.0 / fps, process_ms, calls] if fps > 0 else "FPS -- · 采样中"
		keys_label.text = _metrics_text

func toggle_metrics() -> void:
	_metrics_enabled = not _metrics_enabled
	_metrics_next_msec = 0
	_last_snapshot.clear()
	refresh()

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
	construction_card = BuildCard.new()
	construction_card.name = "ConstructionCard"
	overlay.add_child(construction_card)
	construction_card.setup(_font)
	status_panel = _panel("SurvivalStatus", overlay)
	status_panel.add_theme_stylebox_override("panel", VoyageSkin.panel(14))
	var status := _vbox(status_panel, 7)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(row)
	clock_label = _label(row, "Clock", 14, TEXT)
	clock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weather_label = _label(row, "Weather", 13, MUTED)
	health_label = _label(row, "Health", 14, TEXT)
	var separator := HSeparator.new()
	separator.add_theme_stylebox_override("separator", _rule())
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(separator)
	var supplies := HBoxContainer.new()
	supplies.add_theme_constant_override("separation", 12)
	status.add_child(supplies)
	resource_label = _supply(supplies, "wood", "木料", 138)
	shell_count = _supply(supplies, "shellfish", "鲜贝", 68)
	soup_count = _supply(supplies, "stew_servings", "热汤", 68)
	_build_management_help()
	objective_panel = _panel("CurrentObjective", overlay)
	objective_panel.add_theme_stylebox_override("panel", VoyageSkin.panel(14))
	var objective := _vbox(objective_panel, 8)
	var objective_caption := _label(objective, "ObjectiveCaption", 14, VoyageSkin.MUTED)
	objective_caption.text = "当前目标"
	objective_caption.add_theme_font_override("font", UiType.face(400))
	objective_label = _label(objective, "Objective", 16, TEXT)
	objective_label.add_theme_font_override("font", UiType.face(400))
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_panel = _panel("BuildValidity", overlay, AMBER)
	build_label = _label(build_panel, "BuildValidityText", 15, AMBER)
	build_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A manually measured alert card avoids a Container/auto-wrapped Label
	# minimum-size feedback loop producing a huge empty warning rectangle.
	alert_panel = Panel.new()
	alert_panel.name = "CriticalConditions"
	alert_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var alert_style := _box(Color(0.13, 0.12, 0.10, 0.95), Color("8a7454"), 0)
	alert_style.border_width_left = 3
	alert_panel.add_theme_stylebox_override("panel", alert_style)
	overlay.add_child(alert_panel)
	alert_icon = TextureRect.new()
	alert_icon.name = "ConditionIcon"
	alert_icon.texture = ALERT_ICON
	alert_icon.modulate = AMBER
	alert_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	alert_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	alert_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alert_panel.add_child(alert_icon)
	alert_label = _label(alert_panel, "Conditions", 15, AMBER)
	alert_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys_label = _label(overlay, "KeyHints", 13, MUTED)
	keys_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	keys_label.add_theme_color_override("font_shadow_color", Color("142126"))
	keys_label.add_theme_constant_override("shadow_offset_y", 1)
	choice_panel = _panel("PinnedDialogueChoices", overlay, CYAN)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	choice_panel.add_child(grid)
	for index in range(4):
		var button := Button.new()
		button.name = "DialogueChoice%d" % index
		button.custom_minimum_size.y = 38
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_stylebox_override("normal", _box(Color("263f41"), EDGE, 8))
		button.add_theme_stylebox_override("hover", _box(Color("355b5a"), CYAN, 8))
		button.add_theme_stylebox_override("pressed", _box(Color("1b3031"), CYAN, 8))
		button.add_theme_color_override("font_color", TEXT)
		button.pressed.connect(_choice_clicked.bind(index))
		grid.add_child(button)
		choice_buttons.append(button)
	choice_panel.hide()

func _choice_clicked(index: int) -> void:
	if choice_panel.visible and index < _choice_keys.size():
		choice_requested.emit(_choice_keys[index], _choice_id)

func _update_content(state: Dictionary) -> void:
	var choice: Dictionary = state.choice
	_choice_id = str(choice.get("id", ""))
	_choice_keys.clear()
	var options: Array = choice.get("options", [])
	for index in range(choice_buttons.size()):
		choice_buttons[index].visible = index < options.size()
		if index < options.size():
			choice_buttons[index].text = str(options[index].label)
			_choice_keys.append(int(options[index].key))
	choice_panel.visible = not options.is_empty()
	clock_label.text = "第%d天 · %s" % [state.day, state.period]
	health_label.text = "生命 %d/%d" % [state.health, state.health_max]
	health_label.add_theme_color_override("font_color", RED if int(state.health) <= 1 else TEXT)
	weather_label.text = str(state.weather_text) + ("  ·  游泳" if state.swimming else "") + ("  ·  航行中" if state.sailing else "")
	weather_label.add_theme_color_override("font_color", AMBER if int(state.weather) == 1 else CYAN)
	resource_label.text = "随身 %d / 储存 %d" % [state.wood_carried, state.wood_stored]
	shell_count.text = str(state.shellfish)
	soup_count.text = str(state.stew)
	resource_glyphs.wood.show_resource("wood", int(state.wood_carried)+int(state.wood_stored))
	resource_glyphs.shellfish.show_resource("shellfish", int(state.shellfish))
	resource_glyphs.stew_servings.show_resource("stew_servings", int(state.stew))
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
	if alerts.is_empty() and _beast_alert_fallback(state):
		alerts.append("礁背兽蓄势 · 拉开距离／近身 Q")
	alert_label.text = "\n".join(alerts)
	alert_panel.visible = not alerts.is_empty()
	# Existing controls remain unchanged, and complete help stays in native H.
	keys_label.text = "B 背包 · V 营造 · M 海图 · F5 保存 · F8 帧率" if not state.building else "左键  确认    右键 / Esc  取消 · F8 帧率"
	keys_label.visible = not state.choice_open and not state.drawer_open and (not state.building or _metrics_enabled)
	objective_panel.visible = not state.drawer_open and not state.choice_open and (not state.building or state.construction.is_empty())
	build_panel.visible = bool(state.building) and state.construction.is_empty() and not state.drawer_open and not state.choice_open
	construction_card.present(state.construction)
	construction_card.visible = bool(state.building) and not state.drawer_open and not state.choice_open and not state.construction.is_empty()
	var valid := bool(state.preview_valid)
	build_label.text = ("可确认布置" if valid else "暂不可确认布置 · 请调整落点") if not str(state.editing).is_empty() else ("可放置 · 左键确认" if valid else "位置不合适 · 请在甲板承重区内选择位置")
	if not valid and str(state.editing).is_empty() and not str(state.build_feedback).is_empty():
		build_label.text = str(state.build_feedback)
	build_label.add_theme_color_override("font_color", CYAN if valid else AMBER)
	build_panel.add_theme_stylebox_override("panel", _box(FILL, CYAN if valid else AMBER, 14))

func _build_management_help() -> void:
	# A stable contextual reading surface, separate from the original message.
	# It never rewrites that message, its scroll position, or gameplay state.
	management_help_panel = PanelContainer.new()
	management_help_panel.name = "ArkManagementContextHelp"
	management_help_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	management_help_panel.add_theme_stylebox_override("panel", VoyageSkin.panel(12))
	overlay.add_child(management_help_panel)
	var stack := _vbox(management_help_panel, MANAGEMENT_HELP_GAP)
	management_help_title = _label(stack, "ContextHelpTitle", 14, VoyageSkin.ACCENT)
	management_help_title.add_theme_font_override("font", UiType.face(500))
	management_help_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	management_help_title.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	management_help_scroll = ScrollContainer.new()
	management_help_scroll.name = "ContextHelpScroll"
	management_help_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	management_help_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	management_help_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	management_help_scroll.focus_mode = Control.FOCUS_NONE
	stack.add_child(management_help_scroll)
	management_help_body = _label(management_help_scroll, "ContextHelpBody", 15, TEXT)
	management_help_body.add_theme_font_override("font", UiType.face(400))
	management_help_body.add_theme_constant_override("line_spacing", 0)
	management_help_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	management_help_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	management_help_body.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	management_help_panel.hide()

func _layout_management_help(state: Dictionary, note_bottom: float, occupied_bottom: float, message_width: float, margin: float) -> void:
	var help: Dictionary = _management_actions.context_help() if is_instance_valid(_management_actions) else {}
	var eligible: bool = bool(state.drawer_open) and game.player_guide.more.is_visible_in_tree() \
		and not bool(state.choice_open) and not bool(state.chart_open) and not bool(state.fishing_open) and not bool(state.inventory_open)
	var active: bool = eligible and bool(help.get("active", false)) and not str(help.get("text", "")).is_empty()
	management_help_panel.set_meta("layout_blocked", "")
	if not active:
		management_help_panel.hide()
		_help_source_id = 0
		return
	var source_id := int(help.get("source_id", 0))
	management_help_title.text = str(help.get("title", "当前项")) + " · 说明"
	management_help_body.text = str(help.text)
	if source_id != _help_source_id:
		management_help_scroll.scroll_vertical = 0
		_help_source_id = source_id
	# The geometry is independent of the hovered row and its text length.
	# Critical conditions and save feedback always retain their own surfaces.
	var save := game.get("save_status_notice") as Control
	var reading_bottom := save.get_global_rect().position.y - 8.0 if save.visible else note_bottom
	var reading_limit := 160.0 if get_viewport().get_visible_rect().size.x <= 1000.0 else 136.0
	var height := minf(reading_limit, maxf(0.0, reading_bottom - occupied_bottom - 8.0))
	management_help_panel.position = Vector2(margin, reading_bottom - height)
	management_help_title.size.x = maxf(1.0, message_width - 24.0)
	var body_line := ceilf(management_help_body.get_theme_font("font").get_height(15))
	var minimum_readable := management_help_title.get_minimum_size().y + body_line + 24.0 + MANAGEMENT_HELP_GAP
	minimum_readable = maxf(minimum_readable, management_help_panel.get_combined_minimum_size().y)
	if height < minimum_readable:
		management_help_panel.hide()
		management_help_panel.set_meta("layout_blocked", "insufficient space for title and a complete body line")
		return # Keep the original message visible; never replace it with an empty view.
	management_help_panel.size = Vector2(message_width, height)
	if management_help_panel.size.y > height + 0.5:
		management_help_panel.hide()
		management_help_panel.set_meta("layout_blocked", "container minimum exceeds protected reading slot")
		return
	management_help_panel.visible = true

func _build_interaction_compact(hint: Label) -> void:
	_interaction_compact = PanelContainer.new()
	_interaction_compact.name = "CompactInteraction"
	_interaction_compact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interaction_compact.add_theme_stylebox_override("panel", VoyageSkin.panel(11))
	hint.add_child(_interaction_compact)
	_interaction_compact.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interaction_compact.add_child(row)
	var key := _label(row, "Key", 16, TEXT)
	var cap := VoyageSkin.key()
	cap.content_margin_left = 6
	cap.content_margin_right = 6
	cap.content_margin_top = 1
	cap.content_margin_bottom = 1
	key.add_theme_stylebox_override("normal", cap)
	key.add_theme_font_override("font", UiType.face(500))
	key.text = "E"
	key.custom_minimum_size.x = 26
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_interaction_compact_title = _label(row, "Action", 18, TEXT)
	_interaction_compact_title.add_theme_font_override("font", UiType.face(500))
	_interaction_compact_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interaction_compact_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_interaction_compact_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_interaction_compact.hide()


func _interaction_width(hint: Label, limit: float, fishing_open: bool) -> float:
	var action: String = game.interaction_primary_title
	if action != _interaction_measured_title:
		_interaction_measured_title = action
		_interaction_compact_title.text = action
		# Panel 22 + key 26 + gap 8 + a little air around the title.
		var font := _interaction_compact_title.get_theme_font("font")
		_interaction_natural_width = ceilf(font.get_string_size(action, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x) + 66.0
	var compact := hint.visible and not fishing_open and not action.is_empty() and _interaction_natural_width <= limit
	_interaction_compact.visible = compact
	var tint := _interaction_raw_modulate
	if compact or fishing_open:
		tint.a = 0.0
	if hint.self_modulate != tint:
		hint.self_modulate = tint
	return minf(limit, maxf(160.0, _interaction_natural_width)) if compact else limit


func _style_native_nodes() -> void:
	var note_panel := game.get("note_panel") as Control
	var note := game.get("note") as Label
	_override(note_panel, "stylebox", "panel", VoyageSkin.panel(14))
	_override(note, "font", "font", UiType.face(400))
	_override(note, "font_size", "font_size", 16)
	_override(note, "color", "font_color", TEXT)
	_set_property(note, "custom_minimum_size", Vector2.ZERO)
	var hint := game.get("interaction_hint") as Label
	# Capture the original rectangle BEFORE changing anchors later.
	_set_property(hint, "position", hint.position)
	_set_property(hint, "size", hint.size)
	_override(hint, "stylebox", "normal", VoyageSkin.panel(11))
	_override(hint, "font", "font", UiType.face(500))
	_override(hint, "font_size", "font_size", 18)
	_override(hint, "color", "font_color", TEXT)
	_override(hint, "constant", "outline_size", 0)
	_set_property(hint, "mouse_filter", Control.MOUSE_FILTER_IGNORE)
	_set_property(hint, "vertical_alignment", VERTICAL_ALIGNMENT_CENTER)
	_interaction_raw_modulate = hint.self_modulate
	_set_property(hint, "self_modulate", _interaction_raw_modulate)
	_build_interaction_compact(hint)
	var save := game.get("save_status_notice") as Label
	_save_error_style = _box(Color("292d24"), AMBER, 11)
	_save_error_style.set_corner_radius_all(0)
	_save_success_style = _box(Color("202b27"), Color("4b5549"), 11)
	_save_success_style.set_corner_radius_all(0)
	_override(save, "stylebox", "normal", _save_error_style)
	_override(save, "font", "font", UiType.face(400))
	_override(save, "font_size", "font_size", 16)
	_override(save, "color", "font_color", AMBER)
	_override(save, "constant", "shadow_offset_x", 0)
	_override(save, "constant", "shadow_offset_y", 0)
	_set_property(save, "vertical_alignment", VERTICAL_ALIGNMENT_CENTER)
	var drawer := game.get("hud_drawer") as Control
	_override(drawer, "stylebox", "panel", VoyageSkin.panel(12))
	for button in drawer.find_children("*", "Button", true, false):
		if not button.has_meta("quiet_help"):
			_style_button(button as Button)
	_style_button(game.get("hud_toggle"))
	for state in ["normal", "disabled", "hover", "pressed"]:
		_override(game.get("hud_toggle"), "stylebox", state, VoyageSkin.panel(8))
	_override(game.get("hud_toggle"), "color", "font_disabled_color", VoyageSkin.MUTED)
	_override(game.get("hud_toggle"), "color", "icon_normal_color", VoyageSkin.ACCENT)
	for binding in [["ArkHomeArtCandidateButton", PALETTE_ICON], ["ArkHouseholdWorkButton", HAMMER_ICON]]:
		var button := drawer.find_child(binding[0], true, false) as Button
		if button:
			_set_property(button, "icon", binding[1])
			_set_property(button, "expand_icon", true)
			_set_property(button, "icon_max_width", 20)
			_set_property(button, "alignment", HORIZONTAL_ALIGNMENT_LEFT)
	_set_property(game.get("hud_toggle"), "icon", HOUSE_ICON)
	_set_property(game.get("hud_toggle"), "icon_max_width", 18)
	_set_property(game.get("hud_toggle"), "expand_icon", true)
	_override(game.get("hud_details"), "color", "font_color", TEXT)
	var controls := drawer.find_child("ArkControlsHelp", true, false) as Control
	if controls:
		_override(controls, "color", "font_color", MUTED)
	_management_actions = ManagementActions.new()
	if not _management_actions.attach(game.player_guide.actions):
		push_error("Management presentation could not attach to original actions.")
	_management_actions.set_help_surface(management_help_panel)
	_help_keyboard = HelpKeyboard.new()
	if not _help_keyboard.attach(drawer, game.player_guide.tabs, game.player_guide.more_toggle, game.player_guide.details_toggle, drawer.find_child("ArkHelpCloseButton", true, false), drawer.find_child("ArkHelpScroll", true, false)):
		push_error("Handbook keyboard entry could not attach to read-only controls.")

func _style_button(button: Button) -> void:
	_override(button, "stylebox", "normal", _box(Color("263236"), EDGE, 8))
	_override(button, "stylebox", "hover", _box(Color("34464a"), CYAN, 8))
	_override(button, "stylebox", "pressed", _box(Color("1b2b30"), CYAN, 8))
	_override(button, "stylebox", "disabled", _box(Color("20292c"), Color("3a4548"), 8))
	_override(button, "stylebox", "focus", _box(Color.TRANSPARENT, CYAN, 8))
	_override(button, "color", "font_color", TEXT)
	_override(button, "color", "font_hover_color", Color.WHITE)
	_override(button, "color", "font_disabled_color", Color("8e999a"))
	_override(button, "color", "icon_normal_color", CYAN)
	_override(button, "color", "icon_hover_color", Color.WHITE)

func _layout(state: Dictionary) -> void:
	var screen := get_viewport().get_visible_rect().size
	var margin := 24.0
	var left_width := minf(348.0, screen.x * 0.38)
	status_panel.position = Vector2(margin, margin)
	status_panel.size = Vector2(left_width, 0)
	alert_panel.position = Vector2(margin, margin + status_panel.get_combined_minimum_size().y + 12)
	var alert_text_width := left_width - 64.0
	var alert_height := ceilf(_font.get_multiline_string_size(alert_label.text, HORIZONTAL_ALIGNMENT_LEFT, alert_text_width, 15).y) + 28.0
	alert_panel.size = Vector2(left_width, maxf(54.0, alert_height))
	alert_icon.position = Vector2(15, 15)
	alert_icon.size = Vector2(22, 22)
	alert_label.position = Vector2(48, 13)
	alert_label.size = Vector2(alert_text_width, alert_panel.size.y - 26)
	var objective_width := minf(348.0, screen.x * 0.34)
	objective_panel.position = Vector2(screen.x - margin - objective_width, 78)
	objective_panel.size = Vector2(objective_width, 0)
	build_panel.position = objective_panel.position + Vector2(0, objective_panel.get_combined_minimum_size().y + 8)
	build_panel.size = Vector2(objective_width, 0)
	var toggle := game.get("hud_toggle") as Control
	_set_property(toggle, "position", Vector2(screen.x - margin - 184, margin))
	_set_property(toggle, "size", Vector2(184, 38))
	var drawer := game.get("hud_drawer") as Control
	_set_property(drawer, "position", Vector2(screen.x - margin - 480, 78))
	var management_open: bool = game.player_guide.more.visible
	var drawer_limit := 390.0 if management_open else 312.0
	_set_property(drawer, "size", Vector2(480, clampf(screen.y - 228, 260, drawer_limit)))
	# Preserve native scroll, source message, choice keys and build-validity text.
	var note := game.get("note") as Label
	var note_panel := game.get("note_panel") as Control
	var message_visible: bool = not state.fishing_open and not state.chart_open and (state.choice_open or ((not state.building or state.construction.is_empty()) and not note.text.strip_edges().is_empty()))
	var message_width := minf(620.0, screen.x - margin * 2)
	if state.drawer_open:
		message_width = minf(message_width, screen.x - 480 - margin * 3)
	elif objective_panel.visible:
		message_width = minf(message_width, screen.x - objective_width - margin * 3)
	var note_bottom := screen.y - (150.0 if (game.get("save_status_notice") as Control).visible else 84.0)
	if choice_panel.visible:
		var choice_height := 106.0 if _choice_keys.size() > 2 else 60.0
		choice_panel.position = Vector2(margin, note_bottom - choice_height)
		choice_panel.size = Vector2(message_width, choice_height)
		note_bottom -= choice_height + 8.0
	var occupied_bottom := alert_panel.position.y + alert_panel.size.y if alert_panel.visible else status_panel.position.y + status_panel.get_combined_minimum_size().y
	var maximum_height := maxf(68.0, minf(272.0 if state.choice_open else 200.0, note_bottom - occupied_bottom - 12.0))
	var measured_height := ceilf(_font.get_multiline_string_size(note.text, HORIZONTAL_ALIGNMENT_LEFT, message_width - 32.0, 16).y) + 28.0
	if state.drawer_open:
		# The open handbook is the primary reading surface. Keep contextual
		# messages as complete readable lines, with their original scroll/text,
		# and leave stable space between HUD and message for full tooltips.
		# This policy depends on visible alerts, never hover or mouse state.
		var visible_lines := 2 if alert_panel.visible else 3
		var note_font := note.get_theme_font("font")
		var note_size := note.get_theme_font_size("font_size")
		var content_height := ceilf(note_font.get_height(note_size)) * visible_lines + note.get_theme_constant("line_spacing") * (visible_lines - 1)
		maximum_height = minf(maximum_height, content_height + 28.0)
		measured_height = maxf(measured_height, note.get_minimum_size().y + 28.0)
	if state.building and not state.preview_valid and not str(state.build_feedback).is_empty():
		# Placement ignores scroll input; include the Label's actual line spacing
		# so this obstruction plus the original cost/cancel text is not clipped.
		measured_height = maxf(measured_height, note.get_minimum_size().y + 28.0)
	if str(state.choice.get("id", "")).begins_with("gear_"):
		# Gear choice feedback uses the same Label line spacing as build feedback.
		measured_height = maxf(measured_height, note.get_minimum_size().y + 28.0)
	var message_height := clampf(measured_height, 54.0, maximum_height)
	_set_property(note_panel, "position", Vector2(margin, note_bottom - message_height))
	_set_property(note_panel, "size", Vector2(message_width, message_height))
	var hint := game.get("interaction_hint") as Label
	var hint_width := _interaction_width(hint, maxf(1.0, minf(590.0, screen.x - margin * 2)), bool(state.fishing_open))
	_set_property(hint, "anchor_left", 0.0)
	_set_property(hint, "anchor_right", 0.0)
	_set_property(hint, "anchor_top", 0.0)
	_set_property(hint, "anchor_bottom", 0.0)
	_set_property(hint, "position", Vector2((screen.x - hint_width) / 2, screen.y - 66))
	_set_property(hint, "size", Vector2(hint_width, 42))
	var save := game.get("save_status_notice") as Control
	var save_failed: bool = not str(state.save_warning).is_empty()
	_override(save, "stylebox", "normal", _save_error_style if save_failed else _save_success_style)
	_override(save, "color", "font_color", AMBER if save_failed else TEXT)
	_set_property(save, "position", Vector2(margin, screen.y - (76 if state.chart_open else 138)))
	_set_property(save, "size", Vector2(screen.x - margin * 2, 62))
	var keys_width := minf(620, screen.x - margin * 2)
	keys_label.position = Vector2(screen.x - margin - keys_width, screen.y - 24)
	keys_label.size = Vector2(keys_width, 22)
	if construction_card.visible and save.visible:
		# During construction only, keep the same authoritative warning on the
		# left, instead of pushing the drafting card up over the boat/ghost.
		var card_width := minf(480.0 if screen.x <= 1000 else 540.0, screen.x - 48.0)
		var warning_width := screen.x - card_width - margin * 3.0
		_set_property(save, "size", Vector2(warning_width, 0))
		var warning_height := maxf(save.get_minimum_size().y, ceilf(_font.get_multiline_string_size((save as Label).text,HORIZONTAL_ALIGNMENT_LEFT,warning_width-22,16).y)+22)
		_set_property(save, "size", Vector2(warning_width, warning_height))
		_set_property(save, "position", Vector2(margin, screen.y-40-warning_height))
	_layout_management_help(state, note_bottom, occupied_bottom, message_width, margin)
	# Only the canonical confirmed-success duplicate loses its second surface.
	# Leave the original Label and scroll untouched, and fail open for warnings,
	# choices, changed/unknown prose, or a notice hidden by any ancestor.
	var repeated_save_success: bool = state.drawer_open and not state.choice_open and not save_failed \
		and not bool(game.get_meta("save_load_blocked", false)) \
		and save.is_visible_in_tree() \
		and str(game.get_meta("manual_save_notice", "")) == MANUAL_SAVE_SUCCESS_TEXT \
		and (save as Label).text == MANUAL_SAVE_SUCCESS_TEXT \
		and note.text == MANUAL_SAVE_SUCCESS_TEXT
	_set_property(note_panel, "visible", message_visible and not management_help_panel.visible and not repeated_save_success)
	var obstacles: Array[Rect2] = [status_panel.get_global_rect()]
	if save.visible: obstacles.append(save.get_global_rect())
	if alert_panel.visible: obstacles.append(alert_panel.get_global_rect())
	construction_card.arrange(screen, game.get("camera") as Camera3D, obstacles, save.visible)

## Only a narrow whitelist of ordinary Name labels is reduced. Danger signs,
## reef/vent markers, unknown labels, meshes and the real focus ring are untouched.
## At most the focused short household identity + nearby residents/supplies remain.
## The original 2D focus hint/ring retains actions; modal interfaces hide furniture.
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
	# Match the game's E authority, including unaffordable maintenance targets.
	# A cancelled hold is still maintenance focus while its target remains valid.
	var ordinary: Dictionary = game.call("_nearest_interactable")
	var maintenance: Dictionary = game.call("_maintenance_target", ordinary)
	var focus: Node3D = null
	if maintenance.is_empty():
		var reference: Variant = ordinary.get("node")
		if typeof(reference) == TYPE_OBJECT and is_instance_valid(reference) and reference is Node3D:
			focus = reference as Node3D
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
			_world_signs[key] = {"node": weakref(sign), "visible": sign.visible, "pixel_size": sign.pixel_size, "applied_visible": sign.visible}
			if id in FURNITURE_NAME_IDS:
				_world_signs[key]["text"] = sign.text
				_world_signs[key]["applied_text"] = sign.text
		var record: Dictionary = _world_signs[key]
		_observe_world_name_owner(sign, record)
		var originally_visible := bool(record.visible)
		var distance := actor.global_position.distance_to(target.global_position)
		var nearby_identity := (id in ["resident", "sailmaker"] and distance <= 7.0) or (id in ["wood", "shellfish"] and distance <= 4.0)
		sign.visible = originally_visible and (target == focus or nearby_identity) and not state.chart_open
		if id in FURNITURE_NAME_IDS:
			# Canonical prose remains owned by the game, including later upgrades.
			sign.text = str(record.text).get_slice("\n", 0).get_slice(" · ", 0).strip_edges()
			record.applied_text = sign.text
			if state.drawer_open or state.choice_open or state.inventory_open or state.building or state.sailing:
				sign.visible = false
		record.applied_visible = sign.visible
		# Resident action lines should identify someone, not cover their face or
		# become a banner in a close camera. Focus actions remain in the 2D hint;
		# NPC identity text, danger/unknown signs and fonts stay canonical.
		if id in ["resident", "sailmaker"]:
			sign.pixel_size = _resident_name_pixel_size(sign, float(_world_signs[key].pixel_size))

# Detect owner writes relative to our last projection, never promote our own
# shortened text/hidden state to the restore value. Also called before detach.
func _observe_world_name_owner(sign: Label3D, record: Dictionary) -> void:
	if record.has("applied_text") and sign.text != str(record.applied_text):
		record.text = sign.text
	if record.has("applied_visible") and sign.visible != bool(record.applied_visible):
		record.visible = sign.visible

func _restore_world_names() -> void:
	for record in _world_signs.values():
		var sign := record.node.get_ref() as Label3D
		if not is_instance_valid(sign): continue
		_observe_world_name_owner(sign, record)
		if record.has("text"): sign.text = str(record.text)
		sign.visible = bool(record.visible)
		if record.has("pixel_size"): sign.pixel_size = float(record.pixel_size)
	_world_signs.clear()

## Bound only existing resident identity text, not visibility or world geometry.
## A world-size multiplier alone shrinks Chinese names into dots at normal zoom.
func _resident_name_pixel_size(sign: Label3D, original_size: float) -> float:
	var baseline := original_size * .45
	var camera := game.get("camera") as Camera3D
	if camera == null or camera.is_position_behind(sign.global_position): return baseline
	var origin := camera.unproject_position(sign.global_position)
	var world_em := camera.global_basis.y * sign.font_size * baseline * sign.global_basis.get_scale().y
	var projected_em := origin.distance_to(camera.unproject_position(sign.global_position + world_em))
	if not is_finite(projected_em) or projected_em <= 0.001: return baseline
	return baseline * clampf(projected_em, NPC_NAME_MIN_PIXELS, NPC_NAME_MAX_PIXELS) / projected_em

## Reversible disposal: re-enable original UI/layout, do NOT reset world state.
func detach() -> void:
	if not _attached:
		return
	set_process(false)
	_attached = false
	if _help_keyboard != null:
		_help_keyboard.detach()
	_help_keyboard = null
	if is_instance_valid(_management_actions):
		_management_actions.detach()
		_management_actions.queue_free()
	_management_actions = null
	_restore_world_names()
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
	if is_instance_valid(_interaction_compact):
		_interaction_compact.hide()
		_interaction_compact.queue_free()
	_interaction_compact = null
	_interaction_compact_title = null
	_interaction_measured_title = ""
	_interaction_natural_width = 0.0
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
	choice_buttons.clear()
	_choice_keys.clear()
	_choice_id = ""
	choice_panel = null
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
	line.color = Color("625f4c")
	line.thickness = 1
	return line

func _supply(parent: Control, id: String, caption: String, width: float) -> Label:
	var row := HBoxContainer.new()
	row.custom_minimum_size.x = width
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)
	var glyph := InventoryArtwork.InventoryGlyph.new()
	glyph.custom_minimum_size = Vector2(32,32)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)
	resource_glyphs[id] = glyph
	var labels := VBoxContainer.new()
	labels.add_theme_constant_override("separation", 0)
	row.add_child(labels)
	_label(labels, id+"Caption", 12, MUTED).text = caption
	return _label(labels, id+"Value", 13 if id=="wood" else 16, TEXT)


static func _beast_alert_fallback(state: Dictionary) -> bool:
	# Existing danger/save/weather retain priority. Message text is not a gate:
	# an out-of-range Q notice must not erase an ongoing windup cue.
	return int(state.get("health", 0)) > 1 and int(state.get("cold", 0)) == 0 and not bool(state.get("roof_damaged", false)) and not bool(state.get("edge_damaged", false)) and bool(state.get("beast_windup", false)) and str(state.get("save_warning", "")).is_empty() and int(state.get("weather", -1)) != 1 and not bool(state.get("storm_forecast", false))
