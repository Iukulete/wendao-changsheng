extends Control

const AmbientLayerScript = preload("res://scripts/ambient_layer.gd")
const DaoCompassScript = preload("res://scripts/dao_compass.gd")
const SaveServiceScript = preload("res://scripts/save_service.gd")
const GameStateScript = preload("res://scripts/game_state.gd")
const CultivationScript = preload("res://scripts/cultivation_system.gd")
const ReincarnationScript = preload("res://scripts/reincarnation_system.gd")
const WorldSimulationScript = preload("res://scripts/world_simulation.gd")
const LocalAIBridgeScript = preload("res://scripts/local_ai_bridge.gd")
const ItemSystemScript = preload("res://scripts/item_system.gd")
const CombatSystemScript = preload("res://scripts/combat_system.gd")
const CombatStageScript = preload("res://scripts/combat_stage.gd")
const DungeonFeedbackLayerScript = preload("res://scripts/dungeon_feedback_layer.gd")
const StorySystemScript = preload("res://scripts/story_system.gd")
const AchievementSystemScript = preload("res://scripts/achievement_system.gd")
const DungeonSystemScript = preload("res://scripts/dungeon_system.gd")
const EventCatalogScript = preload("res://scripts/event_catalog.gd")

const ERA_ORDER := [
	"古典修仙纪",
	"灵机蒸汽纪",
	"星穹道网纪",
	"废土返道纪",
	"末法裂变纪",
	"仙朝鼎盛纪",
]

const ERA_SCENES := {
	"古典修仙纪": "res://art/scenes/lantern_river_spirit_bazaar.png",
	"灵机蒸汽纪": "res://art/scenes/steam_forge_city.png",
	"星穹道网纪": "res://art/scenes/star_dao_network.png",
	"废土返道纪": "res://art/scenes/wasteland_black_rain.png",
	"末法裂变纪": "res://art/scenes/final_age_spirit_station.png",
	"仙朝鼎盛纪": "res://art/scenes/immortal_dynasty_skycourt.png",
}

const MENU_SCENE := "res://art/scenes/void_threshold_temple.png"
const PROTAGONIST := "res://art/portraits/protagonist_hooded_close.jpg"
const EVENTS_PATH := "res://data/events_v014.json"

const DEFAULT_PLAYER := {
	"name": "无名",
	"realm": "凡人",
	"level": 1,
	"exp": 0,
	"hp": 100,
	"max_hp": 100,
	"mp": 42,
	"max_mp": 42,
	"age": 16,
	"lifespan": 88,
	"spirit_stones": 12,
	"pills": 0,
	"karma": 0,
	"dao_heart": 4,
	"reputation": 0,
	"enmity": 0,
	"roots": [7, 4, 8, 5, 6],
}

enum ScreenState {
	MENU, GAME, EVENT, REINCARNATION, AI_PENDING, INVENTORY, COMBAT, ARMORY,
	DUNGEON_ROUTE, DUNGEON_COMBAT,
}

var state: ScreenState = ScreenState.MENU
var current_era: String = "古典修仙纪"
var current_event: Dictionary = {}
var events: Array = []
var recent_memories: Array[String] = []
var feedback: String = "旧玉仍温，今生尚未落笔。"
var save_notice: String = "尚未封存"
var menu_notice: String = ""

var run_state: Dictionary = {}
var player: Dictionary = {}
var save_service: RefCounted = SaveServiceScript.new()
var ai_bridge: Node

var background: TextureRect
var vignette: ColorRect
var ambient: Control
var screen_host: MarginContainer
var animated_portrait: TextureRect
var background_time: float = 0.0
var era_accent: Color = Color("e4be4c")
var base_theme: Theme
var achievement_notice_queue: Array[Dictionary] = []
var achievement_toast: Control
var dungeon_action_feedback: Dictionary = {}


func _ready() -> void:
	ai_bridge = LocalAIBridgeScript.new()
	add_child(ai_bridge)
	ai_bridge.connect("event_ready", _on_ai_event_ready)
	if run_state.is_empty():
		run_state = GameStateScript.create_new_game("无名", 1, DEFAULT_PLAYER.roots)
	_sync_state_views()
	_build_theme()
	_build_stage()
	_load_events()
	_show_menu()


func _process(delta: float) -> void:
	background_time += delta
	if is_instance_valid(background):
		var viewport_size := get_viewport_rect().size
		var mouse := get_viewport().get_mouse_position()
		var normalized := Vector2.ZERO
		if viewport_size.x > 1.0 and viewport_size.y > 1.0:
			normalized = mouse / viewport_size - Vector2(0.5, 0.5)
		var drift := Vector2(sin(background_time * 0.11), cos(background_time * 0.09)) * 3.5
		var parallax := -normalized * Vector2(18.0, 12.0) + drift
		background.offset_left = -34.0 + parallax.x
		background.offset_top = -28.0 + parallax.y
		background.offset_right = 34.0 + parallax.x
		background.offset_bottom = 28.0 + parallax.y
	if is_instance_valid(animated_portrait):
		animated_portrait.pivot_offset = animated_portrait.size * 0.5
		var breath := (sin(background_time * 1.55) + 1.0) * 0.5
		var scale_value := 1.0 + breath * 0.014
		animated_portrait.scale = Vector2.ONE * scale_value
		animated_portrait.rotation = sin(background_time * 0.52) * 0.0035
	if is_instance_valid(vignette) and vignette.material is ShaderMaterial:
		vignette.material.set_shader_parameter("pulse", (sin(background_time * 1.1) + 1.0) * 0.5)
	if not achievement_notice_queue.is_empty() and not is_instance_valid(achievement_toast):
		_show_next_achievement_notice()


func _build_theme() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI",
		"Microsoft YaHei",
		"Noto Sans CJK SC",
		"Source Han Sans SC",
	])
	font.font_weight = 480
	base_theme = Theme.new()
	base_theme.default_font = font
	base_theme.default_font_size = 18
	theme = base_theme


func _build_stage() -> void:
	background = TextureRect.new()
	background.name = "WorldBackdrop"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(background)

	vignette = ColorRect.new()
	vignette.name = "CinematicVignette"
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color.WHITE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette_material := ShaderMaterial.new()
	vignette_material.shader = load("res://shaders/vignette.gdshader")
	vignette.material = vignette_material
	add_child(vignette)

	ambient = AmbientLayerScript.new()
	ambient.name = "EraParticles"
	ambient.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ambient)

	screen_host = MarginContainer.new()
	screen_host.name = "ScreenHost"
	screen_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		screen_host.add_theme_constant_override(side, 34)
	add_child(screen_host)


func _load_events() -> void:
	var validation: Dictionary = EventCatalogScript.validate_catalog()
	if bool(validation.get("ok", false)):
		events = EventCatalogScript.load_events()
	else:
		push_error("无法读取事件数据：%s" % EVENTS_PATH)
		events = []


func _clear_screen() -> void:
	animated_portrait = null
	for child in screen_host.get_children():
		screen_host.remove_child(child)
		child.queue_free()


func _era_style(era: String) -> Dictionary:
	match era:
		"灵机蒸汽纪":
			return {"accent": Color("d9a652"), "soft": Color("55d0d5"), "mode": "steam"}
		"星穹道网纪":
			return {"accent": Color("60dcff"), "soft": Color("a174ff"), "mode": "stars"}
		"废土返道纪":
			return {"accent": Color("d38f4c"), "soft": Color("7ea475"), "mode": "rain"}
		"末法裂变纪":
			return {"accent": Color("e76860"), "soft": Color("69bec9"), "mode": "embers"}
		"仙朝鼎盛纪":
			return {"accent": Color("f5cc5c"), "soft": Color("70dbce"), "mode": "motes"}
		_:
			return {"accent": Color("e4be4c"), "soft": Color("69c5b1"), "mode": "motes"}


func _apply_era_visuals(scene_path: String = "") -> void:
	var style := _era_style(current_era)
	era_accent = style.accent
	var target_scene := scene_path if not scene_path.is_empty() else str(ERA_SCENES.get(current_era, MENU_SCENE))
	_set_background(target_scene)
	ambient.call("configure", style.mode, style.soft)
	if vignette.material is ShaderMaterial:
		vignette.material.set_shader_parameter("accent", era_accent)
		vignette.material.set_shader_parameter("tint", Color(0.02, 0.035, 0.065, 0.20))


func _set_background(path: String) -> void:
	var texture = load(path)
	if texture is Texture2D:
		background.texture = texture
		background.modulate = Color(0.72, 0.79, 0.90, 0.0)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(background, "modulate", Color.WHITE, 0.72)


func _show_menu() -> void:
	state = ScreenState.MENU
	_clear_screen()
	_set_background(MENU_SCENE)
	var style := _era_style("古典修仙纪")
	era_accent = style.accent
	ambient.call("configure", "motes", style.soft)
	if vignette.material is ShaderMaterial:
		vignette.material.set_shader_parameter("accent", era_accent)
		vignette.material.set_shader_parameter("tint", Color(0.014, 0.025, 0.045, 0.14))

	# Keep the title card centered whenever it fits, while retaining a real
	# vertical overflow path on short displays (or with larger system fonts).
	var scroll := ScrollContainer.new()
	scroll.name = "MenuScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen_host.add_child(scroll)

	var center := CenterContainer.new()
	center.name = "MenuCenter"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var menu_panel := _panel(0.84, era_accent)
	menu_panel.name = "MenuPanel"
	menu_panel.custom_minimum_size = Vector2(590, 0)
	center.add_child(menu_panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	menu_panel.add_child(column)

	column.add_child(_spacer(2))
	var eyebrow := _label("旧玉纪事 · 神游新篇", 15, Color(era_accent, 0.92), HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(eyebrow)
	var title := _label("问 道 长 生", 62, Color("f4e5b7"), HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override("outline_size", 9)
	title.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.72))
	column.add_child(title)
	column.add_child(_label("山河会老，名字会被误传；只有选择仍在轮回里发光。", 18,
		Color(0.86, 0.88, 0.87, 0.86), HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_spacer(8))

	var seal := DaoCompassScript.new()
	seal.custom_minimum_size = Vector2(230, 142)
	seal.call("set_stats", player.roots, 0, 4, era_accent)
	column.add_child(seal)
	column.add_child(_label("请写下此世道号", 18, Color(era_accent, 0.95), HORIZONTAL_ALIGNMENT_CENTER))
	var name_input := LineEdit.new()
	name_input.name = "DaoNameInput"
	name_input.placeholder_text = "旧玉会记住这个名字"
	name_input.text = "云归客" if player.name == "无名" else str(player.name)
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input.custom_minimum_size = Vector2(430, 48)
	_style_line_edit(name_input)
	column.add_child(name_input)

	var save_probe: Dictionary = save_service.call("inspect_save")
	var can_continue := bool(save_probe.get("ok", false))
	var continue_text := "续接旧玉 · 继续游戏"
	if can_continue:
		var saved_state: Dictionary = save_probe.get("state", {})
		var saved_player: Dictionary = saved_state.get("player", {})
		continue_text = "续接旧玉 · %s · %s" % [
			str(saved_player.get("name", "旧日之我")),
			str(saved_state.get("current_era", "未知纪元")),
		]
	var continue_button := _button(continue_text, _continue_game, true)
	continue_button.name = "ContinueButton"
	continue_button.custom_minimum_size = Vector2(430, 52)
	continue_button.disabled = not can_continue
	continue_button.tooltip_text = str(save_probe.get("message", "尚无可继续的旧档。"))
	column.add_child(continue_button)

	var start_label := "另开新生 · 覆写当前档" if can_continue else "入世 · 开始新生"
	var start_button := _button(start_label, _start_new_game.bind(name_input), not can_continue)
	start_button.custom_minimum_size = Vector2(430, 52)
	column.add_child(start_button)
	var legacy_probe: Dictionary = save_service.call("inspect_legacy_saves")
	var can_import_legacy := bool(legacy_probe.get("ok", false))
	if can_import_legacy:
		var legacy_latest: Dictionary = legacy_probe.get("latest", {})
		var import_text := "承接旧版六槽 · %s · %s" % [
			str(legacy_latest.get("player_name", "旧日之我")),
			str(legacy_latest.get("era", "未知纪元")),
		]
		if can_continue:
			import_text = "导入旧版六槽并备份当前档 · %s" % str(legacy_latest.get("player_name", "旧日之我"))
		var import_button := _button(import_text, _import_legacy_game, false)
		import_button.name = "LegacyImportButton"
		import_button.custom_minimum_size = Vector2(430, 48)
		import_button.tooltip_text = "只读导入最近的旧版 slot_*.txt；源文件不会被修改。"
		column.add_child(import_button)
	var save_status := menu_notice if not menu_notice.is_empty() else str(save_probe.get("message", ""))
	column.add_child(_label(save_status, 14,
		Color("e9c67a") if not can_continue and save_probe.get("code", "") == "corrupt_save" else Color(0.72, 0.76, 0.78, 0.84),
		HORIZONTAL_ALIGNMENT_CENTER))
	var shortcut_text := "Enter 开始新生  ·  C 续接旧档"
	if can_import_legacy:
		shortcut_text += "  ·  I 导入旧版"
	column.add_child(_label(shortcut_text, 14,
		Color(0.72, 0.76, 0.78, 0.78), HORIZONTAL_ALIGNMENT_CENTER))
	name_input.grab_focus()


func _start_new_game(name_input: LineEdit) -> void:
	var dao_name := name_input.text.strip_edges()
	if dao_name.is_empty():
		dao_name = "无名客"
	run_state = GameStateScript.create_new_game(dao_name)
	_sync_state_views()
	menu_notice = ""
	_save_current_state("新生命途已立档")
	_show_game()


func _continue_game() -> void:
	var load_result: Dictionary = save_service.call("load_game")
	if not bool(load_result.get("ok", false)):
		menu_notice = str(load_result.get("message", "旧档无法读取。"))
		_show_menu()
		return
	var loaded_state: Dictionary = GameStateScript.ensure_v2(load_result.get("state", {}))
	var loaded_era := str(loaded_state.get("current_era", ""))
	if not ERA_ORDER.has(loaded_era):
		menu_notice = "旧档记载了当前版本不认识的时代，未载入任何状态。"
		_show_menu()
		return
	run_state = loaded_state
	_sync_state_views()
	save_notice = str(load_result.get("message", "旧玉已续接上一次命途。"))
	menu_notice = ""
	current_event = {}
	if DungeonSystemScript.has_active_run(run_state):
		_show_dungeon()
	elif CombatSystemScript.has_active_combat(run_state):
		_show_combat()
	else:
		_show_game()


func _import_legacy_game() -> void:
	var import_result: Dictionary = save_service.call("import_legacy_save")
	if not bool(import_result.get("ok", false)):
		menu_notice = str(import_result.get("message", "旧版存档无法导入。"))
		_show_menu()
		return
	run_state = GameStateScript.ensure_v2(import_result.get("state", {}))
	_sync_state_views()
	save_notice = str(import_result.get("message", "旧版命途已迁入。"))
	menu_notice = ""
	current_event = {}
	_show_game()


func _sync_state_views() -> void:
	run_state = GameStateScript.ensure_v2(run_state)
	WorldSimulationScript.initialize(run_state)
	ItemSystemScript.normalize(run_state)
	CombatSystemScript.normalize(run_state)
	DungeonSystemScript.normalize(run_state)
	StorySystemScript.normalize(run_state)
	AchievementSystemScript.normalize(run_state)
	AchievementSystemScript.check_progress(run_state)
	_collect_achievement_notices()
	current_era = str(run_state.get("current_era", "古典修仙纪"))
	player = run_state.get("player", {})
	recent_memories.clear()
	recent_memories.assign(run_state.get("recent_memories", []))
	feedback = str(run_state.get("feedback", "旧玉从沉眠中醒来。"))


func _commit_state_views() -> void:
	run_state["current_era"] = current_era
	run_state["current_era_id"] = GameStateScript.era_id_for_name(current_era)
	run_state["player"] = player
	run_state["recent_memories"] = recent_memories.duplicate()
	run_state["feedback"] = feedback


func _show_game() -> void:
	if DungeonSystemScript.has_active_run(run_state):
		_show_dungeon()
		return
	if CombatSystemScript.has_active_combat(run_state):
		_show_combat()
		return
	if bool(run_state.get("life_closed", false)):
		_show_reincarnation()
		return
	if CultivationScript.is_dead(run_state):
		_end_current_life(_current_death_cause())
		return
	state = ScreenState.GAME
	_clear_screen()
	_apply_era_visuals()

	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 18)
	screen_host.add_child(page)
	page.add_child(_build_header())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	page.add_child(body)
	body.add_child(_build_player_panel())
	body.add_child(_build_world_panel())
	body.add_child(_build_action_panel())

	var footer := _panel(0.72, era_accent)
	footer.custom_minimum_size.y = 48
	var footer_text := _label("[1] 修炼  [2] 历练  [3] 突破  [4] 迎战  [M] 秘境  [I] 行囊  [A] 玉兵  [J] 显圣",
		15, Color(0.86, 0.89, 0.89, 0.86), HORIZONTAL_ALIGNMENT_CENTER)
	footer_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(footer_text)
	page.add_child(footer)


func _build_header() -> Control:
	var header := _panel(0.78, era_accent)
	header.custom_minimum_size.y = 82
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	header.add_child(row)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_box)
	title_box.add_child(_label("问道长生 · %s" % player.name, 28, Color("f4e5b7")))
	title_box.add_child(_label("第%d世 · %s · 世界第 %d 年" % [
		int(run_state.get("generation", 1)), current_era,
		int((run_state.get("world", {}) as Dictionary).get("year", 1))], 15,
		Color(era_accent, 0.92)))
	var ai_ready := _local_model_ready()
	var ai_text := "本地天机已就绪" if ai_ready else "规则事件运行中"
	var status_box := VBoxContainer.new()
	status_box.custom_minimum_size.x = 280
	status_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(status_box)
	status_box.add_child(_label(ai_text, 15, Color("9ad8c7") if ai_ready else Color("c9c2a8"),
		HORIZONTAL_ALIGNMENT_RIGHT))
	status_box.add_child(_label(save_notice, 13,
		Color("df776c") if save_notice.begins_with("保存失败") else Color(era_accent, 0.88),
		HORIZONTAL_ALIGNMENT_RIGHT))
	return header


func _build_player_panel() -> Control:
	var panel := _panel(0.83, era_accent)
	panel.custom_minimum_size.x = 320
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	column.add_child(_section_title("此世照影"))

	var portrait_frame := _panel(0.34, era_accent)
	portrait_frame.custom_minimum_size = Vector2(282, 245)
	column.add_child(portrait_frame)
	var portrait := TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = load(PROTAGONIST)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait)
	animated_portrait = portrait

	column.add_child(_label("%s · %s %d层" % [player.name, player.realm, int(player.level)], 20,
		Color("f1e5c5"), HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_progress_row("修为", int(player.exp), CultivationScript.exp_needed(player), era_accent))
	column.add_child(_progress_row("气血", int(player.hp), int(player.max_hp), Color("c95858")))
	column.add_child(_progress_row("灵力", int(player.mp), int(player.max_mp), Color("538fc2")))

	var compass := DaoCompassScript.new()
	compass.custom_minimum_size = Vector2(280, 178)
	compass.call("set_stats", player.roots, int(player.karma), int(player.dao_heart), era_accent)
	column.add_child(compass)
	column.add_child(_label("命途罗盘 · 五行在选择中偏转", 13,
		Color(era_accent, 0.82), HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_label("因果 %+d   道心 %d   名望 %+d   仇怨 %d" % [
		int(player.karma), int(player.dao_heart), int(player.reputation), int(player.enmity)],
		15, Color(0.85, 0.87, 0.88, 0.92), HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_label("寿元 %d/%d   灵石 %d   丹药 %d" % [
		int(player.age), int(player.lifespan), int(player.spirit_stones),
		int(player.pills) + ItemSystemScript.count(run_state, "healing_pill")],
		15, Color(0.72, 0.78, 0.80, 0.90), HORIZONTAL_ALIGNMENT_CENTER))
	var effective_stats: Dictionary = ItemSystemScript.effective_stats(run_state)
	column.add_child(_label("实战属性 · 攻%d  守%d  气血上限%d" % [
		int(effective_stats.attack), int(effective_stats.defense), int(effective_stats.max_hp)],
		13, Color(0.76, 0.82, 0.82), HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_label("寿元势态 · %s   旧玉共鸣 · %d" % [
		CultivationScript.lifespan_pressure(player),
		int(((run_state.get("legacy", {}) as Dictionary).get("relic", {}) as Dictionary).get("resonance", 0))],
		13, Color(era_accent, 0.78), HORIZONTAL_ALIGNMENT_CENTER))
	var jade_weapon: Dictionary = AchievementSystemScript.current_weapon(run_state)
	column.add_child(_label("玉兵 · %s" % ("尚未显化" if jade_weapon.is_empty() else "%s·%s  共鸣%d  蓄能%d/100" % [
		str(jade_weapon.name), str(jade_weapon.stage_name), int(jade_weapon.resonance), int(jade_weapon.charge)]),
		13, Color("e8c87f"), HORIZONTAL_ALIGNMENT_CENTER))
	return panel


func _build_world_panel() -> Control:
	var panel := _panel(0.78, era_accent)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(_section_title("山河正在发生"))

	var pulse_card := _panel(0.44, era_accent)
	pulse_card.custom_minimum_size.y = 78
	var pulse := _label(feedback, 18, Color("f0e7d2"))
	pulse.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pulse.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pulse_card.add_child(pulse)
	column.add_child(pulse_card)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var narrative := RichTextLabel.new()
	narrative.bbcode_enabled = true
	narrative.fit_content = true
	narrative.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	narrative.add_theme_font_size_override("normal_font_size", 18)
	narrative.add_theme_font_size_override("bold_font_size", 20)
	narrative.text = _world_digest()
	scroll.add_child(narrative)
	return panel


func _build_action_panel() -> Control:
	var panel := _panel(0.84, era_accent)
	panel.custom_minimum_size.x = 300
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 11)
	panel.add_child(column)
	column.add_child(_section_title("此刻可行"))
	column.add_child(_button("壹 · 打坐修炼", _meditate, true))
	column.add_child(_button("贰 · 外出历练", _open_adventure, true))
	column.add_child(_button("叁 · 叩问瓶颈", _breakthrough, false))
	var combat_button := _button("肆 · 踏入凶地迎战", _start_combat, false)
	combat_button.name = "CombatButton"
	column.add_child(combat_button)
	var ai_button := _button("伍 · 求问本地天机", _request_ai_event, false)
	ai_button.name = "LocalAIButton"
	ai_button.disabled = not _local_model_ready() or ai_bridge.call("is_busy")
	ai_button.tooltip_text = "本地模型与 llama.cpp 运行时尚未就绪。" if ai_button.disabled else ""
	column.add_child(ai_button)
	var inventory_button := _button("陆 · 行囊与炼器", _show_inventory, false)
	inventory_button.name = "InventoryButton"
	column.add_child(inventory_button)
	var armory_button := _button("柒 · 成就与轮回玉兵", _show_armory, false)
	armory_button.name = "ArmoryButton"
	column.add_child(armory_button)
	var dungeon_button := _button("捌 · 镜湖空阙秘境", _enter_dungeon, false)
	dungeon_button.name = "DungeonButton"
	column.add_child(dungeon_button)
	if int(player.get("realm_index", 0)) >= 19:
		var transcend_button := _button("证道圆满 · 自择轮回", _transcend_life, true)
		transcend_button.name = "TranscendLifeButton"
		column.add_child(transcend_button)
	column.add_child(_button("封存此世 · 保存进度", _manual_save, false))
	column.add_child(_spacer(10))
	column.add_child(_section_title("天机镜"))
	column.add_child(_button("观测下一纪元", _cycle_era, false))
	column.add_child(_spacer(10))
	var note := _label("时代不是皮肤：事件池、色彩、微粒与命途反馈会一起改变。", 14,
		Color(0.76, 0.80, 0.81, 0.82))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	return panel


func _world_digest() -> String:
	var era_line: String = str({
		"古典修仙纪": "灯河灵市沿镜湖开张，宗门与散修都在追查一座不被测灵台承认的空阙。",
		"灵机蒸汽纪": "黄铜灵轨贯穿云海，灵气成为燃料，也成为工坊垄断的新秩序。",
		"星穹道网纪": "修士的神识接入星穹道网，旧人格与未来演算在公共云海中同时醒来。",
		"废土返道纪": "黑雨压过盐碱荒原，移动祖庭带着最后的药种与返道火种向东迁徙。",
		"末法裂变纪": "灵息按份配给，寿元被写进契票；凡人正以合成灵根争夺一次入道机会。",
		"仙朝鼎盛纪": "浮空仙城照耀诸州，巡天司却在镜湖发现一扇命籍无法编号的古门。",
	}.get(current_era, "天下无声，因果仍在暗处流动。"))
	var memory_lines := ""
	if recent_memories.is_empty():
		memory_lines = "- 今生尚无足以被旧玉铭记的大事。"
	else:
		for memory in recent_memories.slice(maxi(0, recent_memories.size() - 5)):
			memory_lines += "- %s\n" % memory
	var world: Dictionary = run_state.get("world", {})
	var last_summary: Dictionary = world.get("last_year_summary", {})
	var annual_line := str(last_summary.get("detail", "各方势力刚刚落下第一枚棋子，新的年史尚未写成。"))
	var faction_lines := ""
	var factions: Array = world.get("factions", [])
	for faction_value in factions.slice(0, 3):
		var faction: Dictionary = faction_value
		faction_lines += "- %s · 势%d 资%d 心%d\n" % [
			str(faction.get("name", "无名势力")), int(faction.get("influence", 0)),
			int(faction.get("resources", 0)), int(faction.get("cohesion", 0))]
	if faction_lines.is_empty():
		faction_lines = "- 山门旗号尚未被年史认出。\n"
	var npc_lines := ""
	var npcs: Array = world.get("npcs", [])
	var visible_npcs := 0
	for npc_value in npcs:
		var npc: Dictionary = npc_value
		if not bool(npc.get("alive", true)):
			continue
		var imported_relation := int(npc.get("player_relation", 0))
		var relation_suffix := " · 旧谊%+d" % imported_relation if imported_relation != 0 else ""
		npc_lines += "- %s · %s · %d岁 · %s%s\n" % [
			str(npc.get("name", "无名客")), str(npc.get("realm", "凡人")),
			int(npc.get("age", 0)), _faction_name(str(npc.get("faction_id", "")), factions),
			relation_suffix]
		visible_npcs += 1
		if visible_npcs >= 4:
			break
	if npc_lines.is_empty():
		npc_lines = "- 旧人皆已隐入年史。\n"
	return "[color=#%s][font_size=22][b]%s[/b][/font_size][/color]\n\n%s\n\n" % [
		era_accent.to_html(false), current_era, era_line] + \
		"[color=#d9c98f][b]天地脉象[/b][/color]\n" + \
		"世界第%d年 · 灵潮%d · 稳定%d · 纪元压力%d\n%s\n\n" % [
			int(world.get("year", 1)), int(world.get("qi_tide", 50)),
			int(world.get("stability", 65)), int(world.get("era_pressure", 0)), annual_line] + \
		"[color=#d9c98f][b]势力消长[/b][/color]\n" + faction_lines + "\n" + \
		"[color=#d9c98f][b]同世之人[/b][/color]\n" + npc_lines + "\n" + \
		"[color=#d9c98f][b]命途长卷[/b][/color]\n" + StorySystemScript.digest(run_state) + "\n\n" + \
		"[color=#d9c98f][b]旧玉近录[/b][/color]\n" + memory_lines + \
		"\n[color=#8fbfb7][b]因果不会清零[/b][/color]\n" + \
		"你闭关的一年也是众生的一年；旧人会老去，盟约会变质，前世留下的缺口仍在山河中。"


func _faction_name(faction_id: String, factions: Array) -> String:
	for faction_value in factions:
		var faction: Dictionary = faction_value
		if str(faction.get("id", "")) == faction_id:
			return str(faction.get("name", "无所属"))
	return "无所属"


func _meditate() -> void:
	var result: Dictionary = CultivationScript.meditate(run_state)
	if not bool(result.get("ok", false)):
		if str(result.get("code", "")) == "life_ended":
			_end_current_life(_current_death_cause())
			return
		feedback = str(result.get("message", "此刻无法运转周天。"))
		_show_game()
		return
	_sync_state_views()
	var gain := int(result.get("gain", 0))
	var level_note := "，连破%d层" % int(result.get("levels_gained", 0)) if int(result.get("levels_gained", 0)) > 0 else ""
	feedback = "你在%s的灵机中运转周天，修为 +%d%s。" % [current_era, gain, level_note]
	_add_memory("第%d年，你在%s打坐，命途罗盘的%s位微微发亮。" % [
		int((run_state.world as Dictionary).get("year", 1)), current_era,
		["火", "水", "木", "金", "土"][int(run_state.rng_cursor) % 5]])
	if bool(result.get("dead", false)):
		_end_current_life("寿元耗尽")
		return
	AchievementSystemScript.add_resonance(run_state,
		2 + int(result.get("levels_gained", 0)) * 2, "周天修炼")
	_sync_state_views()
	_save_current_state("周天已自动封存")
	_show_game()


func _breakthrough() -> void:
	var result: Dictionary = CultivationScript.attempt_breakthrough(run_state)
	if not bool(result.get("ok", false)):
		if str(result.get("code", "")) == "life_ended":
			_end_current_life(_current_death_cause())
			return
		feedback = str(result.get("message", "瓶颈尚未真正显形。"))
	else:
		_sync_state_views()
		if bool(result.get("success", false)):
			feedback = "旧玉映出五道流光，你踏入%s。" % str(result.get("realm", player.realm))
			_add_memory("一次大境突破改变了五行流向，道心与寿元一同重铸。")
		else:
			feedback = "破境失败。经脉受创，修为散去一半；天命从不保证努力必有回报。"
			_add_memory("一次破境失败留下了真实伤势，也让你看清当前道途的缺口。")
		AchievementSystemScript.add_resonance(run_state,
			8 if bool(result.get("success", false)) else 2, "叩问瓶颈")
		_sync_state_views()
		if bool(result.get("dead", false)):
			_end_current_life("破境反噬")
			return
		_save_current_state("破境结果已自动封存")
	_show_game()


func _open_adventure() -> void:
	if bool(run_state.get("life_closed", false)) or CultivationScript.is_dead(run_state):
		_end_current_life(_current_death_cause())
		return
	var story_event: Dictionary = StorySystemScript.next_event(run_state)
	if not story_event.is_empty():
		current_event = story_event
		_show_event()
		return
	current_event = EventCatalogScript.select_event(run_state, current_era)
	if current_event.is_empty():
		feedback = "事件数据尚未显形。"
		_show_game()
		return
	_show_event()


func _start_combat() -> void:
	if bool(run_state.get("life_closed", false)) or CultivationScript.is_dead(run_state):
		_end_current_life(_current_death_cause())
		return
	var result: Dictionary = CombatSystemScript.start_combat(run_state)
	if not bool(result.get("ok", false)):
		feedback = "山道上的杀机没有凝成可辨认的战局。"
		_show_game()
		return
	feedback = "%s拦住去路，你已看清它的第一道意图。" % str((result.battle as Dictionary).enemy_name)
	_save_current_state("战局已自动封存")
	_show_combat()


func _show_combat() -> void:
	if not CombatSystemScript.has_active_combat(run_state):
		_show_game()
		return
	state = ScreenState.COMBAT
	_clear_screen()
	_apply_era_visuals()
	var battle: Dictionary = run_state.combat.current
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 16)
	screen_host.add_child(page)

	var header := _panel(0.80, era_accent)
	header.custom_minimum_size.y = 76
	header.add_child(_label("生死战 · 第%d回合 · %s" % [int(battle.turn), current_era], 27,
		Color("f5e7bd"), HORIZONTAL_ALIGNMENT_CENTER))
	page.add_child(header)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	page.add_child(body)
	body.add_child(_build_combatant_panel("此世之我", int(battle.player_hp), int(battle.player_max_hp),
		int(battle.player_mp), int(battle.player_max_mp), int(battle.player_attack),
		int(battle.player_defense), battle.player_statuses, false))
	body.add_child(_build_combat_log(battle))
	body.add_child(_build_enemy_panel(battle))

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	page.add_child(actions)
	var attack_button := _button("斩击 [1]", _resolve_combat_action.bind("attack"), true)
	attack_button.name = "CombatAttackButton"
	attack_button.tooltip_text = "以攻势对敌，并有机会留下流血。"
	actions.add_child(attack_button)
	var guard_button := _button("守势 [2]", _resolve_combat_action.bind("guard"), false)
	guard_button.name = "CombatGuardButton"
	guard_button.tooltip_text = "根据护体强度凝成护盾。"
	actions.add_child(guard_button)
	var spell_button := _button("术法 [3]", _resolve_combat_action.bind("spell"), false)
	spell_button.name = "CombatSpellButton"
	spell_button.disabled = int(battle.player_mp) < CombatSystemScript.SPELL_COST
	spell_button.tooltip_text = "灵力不足。" if spell_button.disabled else "消耗%d点灵力。" % CombatSystemScript.SPELL_COST
	actions.add_child(spell_button)
	var pill_button := _button("服丹 [4]", _resolve_combat_action.bind("pill"), false)
	pill_button.name = "CombatPillButton"
	pill_button.disabled = ItemSystemScript.count(run_state, "healing_pill") <= 0 and int(player.get("pills", 0)) <= 0
	pill_button.tooltip_text = "行囊中没有疗伤丹。" if pill_button.disabled else "恢复四成气血。"
	actions.add_child(pill_button)
	var flee_button := _button("脱战 [5]", _resolve_combat_action.bind("flee"), false)
	flee_button.name = "CombatFleeButton"
	flee_button.tooltip_text = "尝试退出战圈；拖得越久，成功率越低。"
	actions.add_child(flee_button)


func _build_combatant_panel(title: String, hp: int, max_hp: int, mp: int, max_mp: int,
		attack: int, defense: int, statuses: Dictionary, enemy_side: bool) -> Control:
	var panel := _panel(0.82, Color("d46b61") if enemy_side else era_accent)
	panel.custom_minimum_size.x = 255
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(_section_title(title))
	column.add_child(_progress_row("气血", hp, max_hp, Color("c95858")))
	if not enemy_side:
		column.add_child(_progress_row("灵力", mp, max_mp, Color("538fc2")))
	column.add_child(_label("攻势 %d  ·  护体 %d" % [attack, defense], 15,
		Color(0.82, 0.85, 0.84)))
	column.add_child(_label(_combat_status_text(statuses), 15, Color(0.82, 0.84, 0.82)))
	return panel


func _build_enemy_panel(battle: Dictionary) -> Control:
	var panel := _build_combatant_panel(str(battle.enemy_name), int(battle.enemy_hp),
		int(battle.enemy_max_hp), 0, 0, int(battle.enemy_attack), int(battle.enemy_defense),
		battle.enemy_statuses, true)
	var column := panel.get_child(0) as VBoxContainer
	column.add_child(_divider())
	column.add_child(_label("下一意图", 14, Color(0.72, 0.76, 0.76)))
	column.add_child(_label(CombatSystemScript.intent_label(battle), 22, Color("ef9a78"),
		HORIZONTAL_ALIGNMENT_CENTER))
	var detail := _label(CombatSystemScript.intent_description(battle), 14, Color(0.82, 0.80, 0.76))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(detail)
	return panel


func _build_combat_log(battle: Dictionary) -> Control:
	var panel := _panel(0.76, era_accent)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var combat_stage: Control = CombatStageScript.new()
	combat_stage.name = "CombatStage"
	combat_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combat_stage.call("configure", battle, era_accent)
	column.add_child(combat_stage)
	column.add_child(_divider())
	column.add_child(_section_title("交锋实录"))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var log_label := _label("\n".join((battle.log as Array).slice(-12)), 17, Color("eee8da"))
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(log_label)
	return panel


func _combat_status_text(statuses: Dictionary) -> String:
	var parts: Array[String] = []
	if int(statuses.get("shield", 0)) > 0:
		parts.append("护盾 %d" % int(statuses.shield))
	if int(statuses.get("bleed", 0)) > 0:
		parts.append("流血 %d回合" % int(statuses.bleed))
	if int(statuses.get("weak", 0)) > 0:
		parts.append("虚弱 %d回合" % int(statuses.weak))
	return " · ".join(parts) if not parts.is_empty() else "气机平稳"


func _resolve_combat_action(action: String) -> void:
	var result: Dictionary = CombatSystemScript.perform_action(run_state, action)
	if not bool(result.get("ok", false)):
		feedback = str({
			"insufficient_mp": "灵力不足，术式未能成形。",
			"no_healing_pill": "行囊中已无疗伤丹。",
		}.get(str(result.get("code", "")), "这一行动未能落入战局。"))
		_show_combat()
		return
	_sync_state_views()
	if str(result.get("code", "")) != "combat_finished":
		_save_current_state("战斗回合已自动封存")
		_show_combat()
		return
	var outcome := str(result.get("outcome", "escaped"))
	var battle: Dictionary = result.get("battle", {})
	if outcome == "victory":
		var rewards: Dictionary = result.get("rewards", {})
		AchievementSystemScript.add_resonance(run_state, 6, "正面胜战")
		CultivationScript.advance_time(run_state, 1)
		_sync_state_views()
		feedback = "你击败%s，修为 +%d、灵石 +%d，并取得一份战利材料。" % [
			str(battle.get("enemy_name", "强敌")), int(rewards.get("exp", 0)),
			int(rewards.get("spirit_stones", 0))]
		_add_memory("第%d年，你看穿%s的意图并在正面交锋中取胜。" % [
			int((run_state.world as Dictionary).get("year", 1)), str(battle.get("enemy_name", "强敌"))])
		if CultivationScript.is_dead(run_state):
			_end_current_life("胜战后寿元耗尽")
			return
		_save_current_state("胜战与年史已自动封存")
		_show_game()
		return
	if outcome == "defeat":
		feedback = "你败于%s，此世气血归零。" % str(battle.get("enemy_name", "强敌"))
		_end_current_life("战败身陨：%s" % str(battle.get("enemy_name", "强敌")))
		return
	feedback = "你脱离了与%s的战圈，未分胜负。" % str(battle.get("enemy_name", "强敌"))
	_save_current_state("脱战结果已自动封存")
	_show_game()


func _enter_dungeon() -> void:
	if bool(run_state.get("life_closed", false)) or CultivationScript.is_dead(run_state):
		_end_current_life(_current_death_cause())
		return
	var result: Dictionary = DungeonSystemScript.start(run_state, "mirror_lake")
	if not bool(result.get("ok", false)):
		feedback = "镜湖空阙没有形成稳定入口。"
		_show_game()
		return
	feedback = "无字古门在镜湖中央开启，你的功法化为一组可调度的临时灵诀。"
	_save_current_state("秘境入口已自动封存")
	_show_dungeon()


func _show_dungeon() -> void:
	if not DungeonSystemScript.has_active_run(run_state):
		_show_game()
		return
	var run: Dictionary = run_state.dungeon.run
	if not (run.get("battle", {}) as Dictionary).is_empty():
		_show_dungeon_combat()
		return
	_show_dungeon_route()


func _show_dungeon_route() -> void:
	state = ScreenState.DUNGEON_ROUTE
	dungeon_action_feedback = {}
	_clear_screen()
	var run: Dictionary = run_state.dungeon.run
	_apply_era_visuals(_dungeon_scene_path(str(run.dungeon_id)))
	_apply_dungeon_stress_visuals(int(run.stress))
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 14)
	screen_host.add_child(page)
	page.add_child(_build_dungeon_header(run, "秘境岔路"))

	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 14)
	page.add_child(status)
	var stress_color := _dungeon_stress_color(int(run.stress))
	var vitality := _panel(0.80, stress_color if int(run.stress) >= 60 else era_accent)
	vitality.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vitality_column := VBoxContainer.new()
	vitality_column.add_theme_constant_override("separation", 7)
	vitality.add_child(vitality_column)
	vitality_column.add_child(_progress_row("秘境气血", int(run.hp), int(run.max_hp), Color("c95858")))
	vitality_column.add_child(_progress_row("心魔压力", int(run.stress), 100, stress_color))
	var route_stress_label := _label(_dungeon_stress_status(run), 13, Color(stress_color, 0.94))
	route_stress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vitality_column.add_child(route_stress_label)
	status.add_child(vitality)
	var depth_panel := _panel(0.80, era_accent)
	depth_panel.custom_minimum_size.x = 310
	var depth_column := VBoxContainer.new()
	depth_column.alignment = BoxContainer.ALIGNMENT_CENTER
	depth_panel.add_child(depth_column)
	depth_column.add_child(_label("第 %d / %d 层" % [int(run.depth) + 1, int(run.max_depth)], 22,
		Color("f1d79a"), HORIZONTAL_ALIGNMENT_CENTER))
	depth_column.add_child(_label("能力 %d式 · 心障随压力入组" % (run.deck as Array).size(), 14,
		Color(0.76, 0.81, 0.81), HORIZONTAL_ALIGNMENT_CENTER))
	depth_column.add_child(_label("器诀 +%d · 护诀 +%d" % [int(run.get("attack_power", 0)),
		int(run.get("guard_power", 0))], 13, Color(era_accent, 0.86), HORIZONTAL_ALIGNMENT_CENTER))
	status.add_child(depth_panel)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	page.add_child(body)
	body.add_child(_build_dungeon_log(run))
	var route_panel := _panel(0.86, Color("d5a957"))
	route_panel.custom_minimum_size.x = 440
	var route_column := VBoxContainer.new()
	route_column.add_theme_constant_override("separation", 12)
	route_panel.add_child(route_column)
	route_column.add_child(_section_title("选择下一处道标"))
	var routes: Array = run.route_choices
	for index in range(routes.size()):
		var node: Dictionary = routes[index]
		var route_button := _button("%d · %s\n%s · %s" % [index + 1, str(node.name), str(node.danger),
			str(node.get("description", "前路因果未明。"))],
			_choose_dungeon_route.bind(index), index == 0)
		route_button.name = "DungeonRouteButton%d" % index
		route_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		route_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		route_button.custom_minimum_size.y = 104
		route_column.add_child(route_button)
	route_column.add_child(_spacer(6))
	var abandon_button := _button("撤出秘境", _abandon_dungeon, false)
	abandon_button.name = "DungeonAbandonButton"
	route_column.add_child(abandon_button)
	body.add_child(route_panel)
	page.add_child(_label("数字键选择道标 · Esc 撤离", 14, Color(0.76, 0.80, 0.81, 0.82),
		HORIZONTAL_ALIGNMENT_CENTER))


func _show_dungeon_combat() -> void:
	state = ScreenState.DUNGEON_COMBAT
	_clear_screen()
	var run: Dictionary = run_state.dungeon.run
	var battle: Dictionary = run.battle
	_apply_era_visuals(_dungeon_scene_path(str(run.dungeon_id)))
	_apply_dungeon_stress_visuals(int(run.stress))
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 12)
	screen_host.add_child(page)
	page.add_child(_build_dungeon_header(run, "能力交锋 · 第%d回合" % int(battle.turn)))

	var combat_row := HBoxContainer.new()
	combat_row.custom_minimum_size.y = 270
	combat_row.add_theme_constant_override("separation", 14)
	page.add_child(combat_row)
	var stress_color := _dungeon_stress_color(int(run.stress))
	var self_panel := _panel(0.84, stress_color if int(run.stress) >= 60 else era_accent)
	self_panel.custom_minimum_size.x = 260
	var self_column := VBoxContainer.new()
	self_column.add_theme_constant_override("separation", 8)
	self_panel.add_child(self_column)
	self_column.add_child(_section_title(str(player.name)))
	self_column.add_child(_progress_row("秘境气血", int(run.hp), int(run.max_hp), Color("c95858")))
	self_column.add_child(_progress_row("心魔压力", int(run.stress), 100, stress_color))
	var combat_stress_label := _label(_dungeon_stress_status(run), 12, Color(stress_color, 0.96))
	combat_stress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	self_column.add_child(combat_stress_label)
	self_column.add_child(_label("灵力 %d · 回合基础 %d · 护体 %d" % [int(battle.energy),
		DungeonSystemScript.energy_cap(battle), int(battle.player_block)], 15, Color("b9d5e8")))
	self_column.add_child(_label("器诀 +%d · 护诀 +%d" % [int(run.get("attack_power", 0)),
		int(run.get("guard_power", 0))], 14, Color(era_accent, 0.88)))
	combat_row.add_child(self_panel)
	combat_row.add_child(_build_dungeon_log(run))
	var enemy_panel := _panel(0.84, Color("d46b61"))
	enemy_panel.custom_minimum_size.x = 330
	var enemy_column := VBoxContainer.new()
	enemy_column.add_theme_constant_override("separation", 8)
	enemy_panel.add_child(enemy_column)
	enemy_column.add_child(_section_title(str(battle.enemy_name)))
	enemy_column.add_child(_progress_row("气血", int(battle.enemy_hp), int(battle.enemy_max_hp), Color("d35f58")))
	enemy_column.add_child(_label("护体 %d · 虚弱 %d回合" % [int(battle.enemy_block), int(battle.enemy_weak)],
		14, Color(0.78, 0.81, 0.81)))
	enemy_column.add_child(_label("下一意图", 13, Color(0.68, 0.72, 0.73)))
	enemy_column.add_child(_label(DungeonSystemScript.intent_label(str(battle.intent)), 21,
		Color("ef9a78"), HORIZONTAL_ALIGNMENT_CENTER))
	var rule_value: Variant = battle.get("trait", {})
	if rule_value is Dictionary and not (rule_value as Dictionary).is_empty():
		var rule: Dictionary = rule_value
		enemy_column.add_child(_divider())
		enemy_column.add_child(_label("%s · %s" % [DungeonSystemScript.combat_rule_title(battle),
			str(rule.get("name", "未知法则"))], 14,
			Color("efbd72"), HORIZONTAL_ALIGNMENT_CENTER))
		var trait_description := _label(str(rule.get("description", "")), 12, Color(0.84, 0.80, 0.73))
		trait_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		enemy_column.add_child(trait_description)
	var phase_value: Variant = battle.get("phase", {})
	if phase_value is Dictionary and not (phase_value as Dictionary).is_empty():
		var phase: Dictionary = phase_value
		var phase_active := bool(battle.get("phase_active", false))
		enemy_column.add_child(_divider())
		enemy_column.add_child(_label("%s · %s" % ["第二相已显" if phase_active else "未显之相",
			str(phase.get("name", "未知形态"))], 13,
			Color("f08b72") if phase_active else Color("b9a780"), HORIZONTAL_ALIGNMENT_CENTER))
		var phase_description := _label(str(phase.get("description", "")), 11,
			Color(0.88, 0.76, 0.69) if phase_active else Color(0.68, 0.68, 0.65))
		phase_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		enemy_column.add_child(phase_description)
	combat_row.add_child(enemy_panel)

	var hand_scroll := ScrollContainer.new()
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(hand_scroll)
	var hand_grid := GridContainer.new()
	hand_grid.name = "DungeonHandGrid"
	hand_grid.columns = 5
	hand_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_grid.add_theme_constant_override("h_separation", 10)
	hand_grid.add_theme_constant_override("v_separation", 10)
	hand_scroll.add_child(hand_grid)
	var hand: Array = battle.hand
	for index in range(hand.size()):
		var card: Dictionary = hand[index]
		var definition: Dictionary = DungeonSystemScript.card_definition(str(card.card_id))
		var upgrade := int(card.get("upgrade", 0))
		var source_name := str(card.get("source_name", "既有功法"))
		var source_kind := str(card.get("source_kind", "foundation"))
		var card_button := _button("%d  %s%s\n源·%s  ·  灵力 %d\n%s" % [index + 1, str(definition.name),
			" +%d" % upgrade if upgrade > 0 else "", source_name, int(definition.cost),
			str(definition.description)],
			_play_dungeon_card.bind(index), false)
		card_button.name = "DungeonCardButton%d" % index
		card_button.custom_minimum_size = Vector2(194, 116)
		card_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_button.add_theme_font_size_override("font_size", 14)
		var source_color := _ability_source_color(source_kind)
		card_button.add_theme_stylebox_override("normal", _button_style(0.22, source_color, 0.56))
		card_button.add_theme_stylebox_override("hover", _button_style(0.38, source_color, 0.94))
		card_button.add_theme_stylebox_override("focus", _button_style(0.38, source_color, 0.94))
		card_button.add_theme_stylebox_override("pressed", _button_style(0.52, source_color, 1.0))
		card_button.disabled = int(definition.cost) > int(battle.energy)
		card_button.tooltip_text = "当前灵力不足。" if card_button.disabled else \
			"能力来源：%s\n%s" % [source_name, str(definition.description)]
		hand_grid.add_child(card_button)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	page.add_child(actions)
	var end_button := _button("结束回合 [E]", _end_dungeon_turn, true)
	end_button.name = "DungeonEndTurnButton"
	actions.add_child(end_button)
	actions.add_child(_button("撤出秘境", _abandon_dungeon, false))
	_show_dungeon_action_feedback()


func _build_dungeon_header(run: Dictionary, subtitle: String) -> Control:
	var header := _panel(0.82, era_accent)
	header.custom_minimum_size.y = 86
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	header.add_child(row)
	var title := VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	title.add_child(_label(str(run.name), 26, Color("f5e7bd")))
	title.add_child(_label(subtitle, 14, Color(era_accent, 0.90)))
	var profile_label := _label(DungeonSystemScript.ability_profile_label(run), 13,
		Color(0.77, 0.83, 0.82))
	profile_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_child(profile_label)
	var rewards: Dictionary = run.rewards
	row.add_child(_label("暂存修为 %d · 灵石 %d" % [int(rewards.exp), int(rewards.spirit_stones)],
		15, Color("e7c778"), HORIZONTAL_ALIGNMENT_RIGHT))
	return header


func _build_dungeon_log(run: Dictionary) -> Control:
	var panel := _panel(0.78, era_accent)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	column.add_child(_section_title("空阙回声"))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var log_label := _label("\n".join((run.log as Array).slice(-10)), 15, Color("eee8da"))
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(log_label)
	return panel


func _dungeon_stress_color(stress: int) -> Color:
	if stress >= 85: return Color("df5f6d")
	if stress >= 60: return Color("d6a04f")
	return Color("6fbea0")


func _dungeon_stress_status(run: Dictionary) -> String:
	var heart := DungeonSystemScript.heart_demon_for_era(str(run.get("era_id", "classical")))
	var heart_card := DungeonSystemScript.card_definition(str(heart.get("card_id", "heart_demon")))
	var heart_name := str(heart_card.get("name", "心障残页"))
	var stress := int(run.get("stress", 0))
	if stress >= 85: return "心魔临界 · 越限将显化「%s」" % heart_name
	if stress >= 60: return "心念躁动 · 「%s」正在成形" % heart_name
	return "心境平稳 · 「%s」尚未成形" % heart_name


func _apply_dungeon_stress_visuals(stress: int) -> void:
	if not is_instance_valid(vignette) or not (vignette.material is ShaderMaterial):
		return
	if stress >= 85:
		vignette.material.set_shader_parameter("accent", Color("df5f6d"))
		vignette.material.set_shader_parameter("tint", Color(0.15, 0.012, 0.025, 0.30))
	elif stress >= 60:
		vignette.material.set_shader_parameter("accent", Color("d6a04f"))
		vignette.material.set_shader_parameter("tint", Color(0.09, 0.045, 0.018, 0.24))


func _show_dungeon_action_feedback() -> void:
	if dungeon_action_feedback.is_empty():
		return
	var action_feedback := dungeon_action_feedback.duplicate(true)
	dungeon_action_feedback = {}
	var kind := str(action_feedback.get("kind", "card"))
	var feedback_color := _ability_source_color(str(action_feedback.get("source_kind", "foundation"))) \
		if kind == "card" else Color("ef665e")
	if bool(action_feedback.get("phase_shifted", false)):
		feedback_color = Color("f0a06d")
	elif bool(action_feedback.get("heart_awakened", false)):
		feedback_color = Color("df5f79")
	var layer: Control = DungeonFeedbackLayerScript.new()
	layer.name = "DungeonFeedbackLayer"
	layer.z_index = 120
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen_host.add_child(layer)
	layer.call("configure", action_feedback, feedback_color)
	var summary := _dungeon_feedback_summary(action_feedback)
	if summary.is_empty():
		return
	var label := _label(summary, 23, Color(feedback_color, 0.98), HORIZONTAL_ALIGNMENT_CENTER)
	label.name = "DungeonFeedbackSummary"
	label.add_theme_constant_override("outline_size", 7)
	label.add_theme_color_override("font_outline_color", Color(0.015, 0.02, 0.03, 0.94))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.anchor_left = 0.30
	label.anchor_right = 0.70
	label.anchor_top = 0.70
	label.anchor_bottom = 0.70
	label.offset_top = -26
	label.offset_bottom = 48
	layer.add_child(label)


func _dungeon_feedback_summary(action_feedback: Dictionary) -> String:
	var parts: Array[String] = []
	if str(action_feedback.get("kind", "")) == "card":
		parts.append(str(action_feedback.get("card_name", "能力显化")))
		if int(action_feedback.get("damage", 0)) > 0:
			parts.append("敌方气血 -%d" % int(action_feedback.damage))
		if int(action_feedback.get("block", 0)) > 0:
			parts.append("护体 +%d" % int(action_feedback.block))
	else:
		parts.append(str(action_feedback.get("intent_name", "敌方行动")))
		if int(action_feedback.get("damage", 0)) > 0:
			parts.append("气血 -%d" % int(action_feedback.damage))
		if int(action_feedback.get("enemy_block_delta", 0)) > 0:
			parts.append("敌方护体 +%d" % int(action_feedback.enemy_block_delta))
	var stress_delta := int(action_feedback.get("stress_delta", 0))
	if stress_delta != 0:
		parts.append("压力 %s%d" % ["+" if stress_delta > 0 else "", stress_delta])
	if bool(action_feedback.get("heart_awakened", false)):
		parts.append("心魔显化 · %s" % str(action_feedback.get("heart_name", "心障")))
	if bool(action_feedback.get("phase_shifted", false)):
		parts.append("破相 · %s" % str(action_feedback.get("phase_name", "第二相")))
	return "  ·  ".join(parts)


func _ability_source_color(source_kind: String) -> Color:
	return {
		"weapon": Color("dc8b55"),
		"armor": Color("62b4c5"),
		"realm": Color("9b7ed0"),
		"path": Color("67b98d"),
		"relic": Color("d6b45c"),
		"jade": Color("e2786c"),
		"memory": Color("a58bc9"),
		"story": Color("d989b5"),
		"heart": Color("bd5364"),
	}.get(source_kind, era_accent)


func _choose_dungeon_route(index: int) -> void:
	var result: Dictionary = DungeonSystemScript.choose_route(run_state, index)
	_handle_dungeon_action(result, "秘境道标已自动封存")


func _play_dungeon_card(index: int) -> void:
	var result: Dictionary = DungeonSystemScript.play_card(run_state, index)
	_handle_dungeon_action(result, "秘境灵诀已自动封存")


func _end_dungeon_turn() -> void:
	var result: Dictionary = DungeonSystemScript.end_turn(run_state)
	_handle_dungeon_action(result, "秘境回合已自动封存")


func _abandon_dungeon() -> void:
	var result: Dictionary = DungeonSystemScript.abandon(run_state)
	_handle_dungeon_action(result, "秘境撤离已自动封存")


func _handle_dungeon_action(result: Dictionary, save_reason: String) -> void:
	if not bool(result.get("ok", false)):
		dungeon_action_feedback = {}
		feedback = str({
			"insufficient_energy": "当前灵力不足，无法施展这式能力。",
			"invalid_route_choice": "这条秘境道路已经消散。",
		}.get(str(result.get("code", "")), "秘境没有接受这一行动。"))
		_show_dungeon()
		return
	var action_feedback_value: Variant = result.get("feedback", {})
	dungeon_action_feedback = (action_feedback_value as Dictionary).duplicate(true) \
		if action_feedback_value is Dictionary else {}
	if str(result.get("code", "")) == "dungeon_finished":
		dungeon_action_feedback = {}
		_finalize_dungeon_exit(result, save_reason)
		return
	_sync_state_views()
	_save_current_state(save_reason)
	_show_dungeon()


func _finalize_dungeon_exit(result: Dictionary, save_reason: String) -> void:
	dungeon_action_feedback = {}
	var outcome := str(result.get("outcome", "abandoned"))
	var run: Dictionary = result.get("run", {})
	var rewards: Dictionary = result.get("rewards", {})
	var years := maxi(1, int(ceil(float(run.get("depth", 1)) / 2.0)))
	CultivationScript.advance_time(run_state, years)
	_sync_state_views()
	if outcome == "completed":
		feedback = "你走出%s，带回修为%d、灵石%d与一缕因果丝。" % [str(run.get("name", "镜湖秘境")),
			int(rewards.get("exp", 0)), int(rewards.get("spirit_stones", 0))]
	elif outcome == "defeat":
		feedback = "秘境将你逐出空阙，今生留下了一道需要慢慢化解的心创。"
	else:
		feedback = "你主动退出空阙，秘境中的临时能力牌随门影散去。"
	_add_memory("第%d年，你从%s归来：%s。" % [int((run_state.world as Dictionary).get("year", 1)),
		str(run.get("name", "镜湖秘境")), outcome])
	if CultivationScript.is_dead(run_state):
		_end_current_life("秘境归来后寿元耗尽")
		return
	_save_current_state(save_reason)
	_show_game()


func _dungeon_scene_path(dungeon_id: String) -> String:
	for value in (DungeonSystemScript.load_definitions().get("dungeons", []) as Array):
		var definition: Dictionary = value
		if str(definition.id) == dungeon_id:
			return str(definition.scene)
	return MENU_SCENE


func _request_ai_event() -> void:
	if bool(run_state.get("life_closed", false)) or CultivationScript.is_dead(run_state):
		_end_current_life(_current_death_cause())
		return
	var request: Dictionary = ai_bridge.call("request_event", run_state)
	var ai_state: Dictionary = run_state.get("ai", {})
	ai_state["request_count"] = int(ai_state.get("request_count", 0)) + 1
	if bool(request.get("pending", false)):
		ai_state["last_status"] = "pending"
		run_state["ai"] = ai_state
		_show_ai_pending()
		return
	ai_state["last_status"] = str(request.get("code", "runtime_unavailable"))
	ai_state["fallback_count"] = int(ai_state.get("fallback_count", 0)) + 1
	run_state["ai"] = ai_state
	current_event = request.get("event", ai_bridge.call("fallback_event", run_state, "本地天机不可用"))
	feedback = "本地天机未能启动，规则因果已无缝接管。"
	_show_event()


func _show_ai_pending() -> void:
	state = ScreenState.AI_PENDING
	_clear_screen()
	_apply_era_visuals()
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 18)
	screen_host.add_child(page)
	var panel := _panel(0.86, era_accent)
	panel.custom_minimum_size = Vector2(640, 310)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 20)
	panel.add_child(column)
	column.add_child(_label("本地天机正在推演", 30, Color("f0d99c"), HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_label("旧玉正把此世人物、山河年史与未竟因果送入本机模型。",
		17, Color(0.82, 0.84, 0.82), HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_button("收回神识", _cancel_ai_request, false))


func _cancel_ai_request() -> void:
	ai_bridge.call("cancel")
	var ai_state: Dictionary = run_state.get("ai", {})
	ai_state["last_status"] = "cancelled"
	run_state["ai"] = ai_state
	feedback = "你收回神识，本地推演没有改变任何因果。"
	_show_game()


func _on_ai_event_ready(event_data: Dictionary, metadata: Dictionary) -> void:
	var ai_state: Dictionary = run_state.get("ai", {})
	ai_state["last_status"] = str(metadata.get("code", "completed"))
	ai_state["last_backend"] = str(metadata.get("backend", "portable-local"))
	if bool(metadata.get("fallback", false)):
		ai_state["fallback_count"] = int(ai_state.get("fallback_count", 0)) + 1
	run_state["ai"] = ai_state
	current_event = event_data
	feedback = "本地天机已落成一段可选择的因果。" if not bool(metadata.get("fallback", false)) else \
		"本地天机未通过校验，规则因果已无缝接管。"
	_show_event()


func _show_event() -> void:
	state = ScreenState.EVENT
	_clear_screen()
	var scene_path := str(current_event.get("scene", ERA_SCENES.get(current_era, MENU_SCENE)))
	_apply_era_visuals(scene_path)

	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 16)
	screen_host.add_child(page)

	var header := _panel(0.78, era_accent)
	header.custom_minimum_size.y = 76
	var header_label := _label(str(current_event.get("title", "无名因果")), 29,
		Color("f5e7bd"), HORIZONTAL_ALIGNMENT_CENTER)
	header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(header_label)
	page.add_child(header)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	page.add_child(body)
	body.add_child(_build_event_stage())
	body.add_child(_build_event_choices())

	var footer := _label("数字键选择  ·  ESC 暂离此事", 15,
		Color(0.78, 0.82, 0.82, 0.82), HORIZONTAL_ALIGNMENT_CENTER)
	page.add_child(footer)


func _build_event_stage() -> Control:
	var frame := _panel(0.38, era_accent)
	frame.custom_minimum_size.x = 515
	var stage := Control.new()
	stage.clip_contents = true
	frame.add_child(stage)

	var scene := TextureRect.new()
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scene.texture = load(str(current_event.get("scene", MENU_SCENE)))
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(scene)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.025, 0.045, 0.24)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(shade)

	var portrait_path := str(current_event.get("portrait", ""))
	if not portrait_path.is_empty():
		var portrait := TextureRect.new()
		portrait.anchor_left = 0.39
		portrait.anchor_top = 0.08
		portrait.anchor_right = 0.98
		portrait.anchor_bottom = 0.90
		portrait.offset_left = 0
		portrait.offset_top = 0
		portrait.offset_right = 0
		portrait.offset_bottom = 0
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture = load(portrait_path)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(portrait)
		animated_portrait = portrait

	var caption_panel := ColorRect.new()
	caption_panel.anchor_left = 0.0
	caption_panel.anchor_top = 0.79
	caption_panel.anchor_right = 1.0
	caption_panel.anchor_bottom = 1.0
	caption_panel.color = Color(0.015, 0.025, 0.04, 0.84)
	caption_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(caption_panel)
	var caption := VBoxContainer.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.offset_left = 24
	caption.offset_top = 18
	caption.offset_right = -24
	caption.offset_bottom = -14
	caption_panel.add_child(caption)
	caption.add_child(_label(str(current_event.get("portrait_name", current_era)), 21, Color(era_accent, 0.98)))
	caption.add_child(_label(str(current_event.get("portrait_title", "因果入局者")), 14,
		Color(0.82, 0.86, 0.86, 0.86)))
	return frame


func _build_event_choices() -> Control:
	var panel := _panel(0.84, era_accent)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	column.add_child(_label(current_era + " · 因果抉择", 15, Color(era_accent, 0.92)))
	var description := _label(str(current_event.get("description", "")), 20, Color("f1eee5"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.y = 150
	column.add_child(description)
	column.add_child(_divider())

	var choices: Array = current_event.get("choices", [])
	for index in range(choices.size()):
		var choice: Dictionary = choices[index]
		var delta_hint := _format_delta_hint(choice.get("deltas", {}))
		var unavailable_reason := _choice_unavailable_reason(choice)
		var choice_button := _button("%d  %s\n     %s" % [index + 1, str(choice.get("text", "沉默")), delta_hint],
			_resolve_choice.bind(index), false)
		choice_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choice_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice_button.custom_minimum_size.y = 88
		choice_button.disabled = not unavailable_reason.is_empty()
		choice_button.tooltip_text = unavailable_reason
		column.add_child(choice_button)
	return panel


func _resolve_choice(index: int) -> void:
	var choices: Array = current_event.get("choices", [])
	if index < 0 or index >= choices.size():
		return
	var choice: Dictionary = choices[index]
	var unavailable_reason := _choice_unavailable_reason(choice)
	if not unavailable_reason.is_empty():
		feedback = unavailable_reason
		_show_event()
		return
	var deltas: Dictionary = choice.get("deltas", {})
	for key in deltas.keys():
		if player.has(key):
			player[key] = int(player[key]) + int(deltas[key])
	var path_deltas: Dictionary = choice.get("path_deltas", {})
	var path: Dictionary = player.get("path", {})
	for path_id in path_deltas.keys():
		if path.has(path_id):
			path[path_id] = int(path[path_id]) + int(path_deltas[path_id])
	player["path"] = path
	player.hp = clamp(int(player.hp), 0, int(player.max_hp))
	player.exp = max(0, int(player.exp))
	player.total_events = int(player.get("total_events", 0)) + 1
	feedback = str(choice.get("outcome", "因果落定，旧玉没有给出解释。"))
	_add_memory("%s：%s" % [str(current_event.get("title", "无名事件")), str(choice.get("text", "沉默"))])
	run_state["player"] = player
	EventCatalogScript.record_resolution(run_state, current_event)
	var story_resolution: Dictionary = StorySystemScript.resolve_choice(run_state, current_event, index)
	if bool(story_resolution.get("ok", false)):
		feedback += "\n\n" + str(story_resolution.get("message", "命途长卷又落下一笔。"))
		if bool(story_resolution.get("terminal", false)):
			_add_memory(str(story_resolution.get("message", "一条跨世因果已经定局。")))
	AchievementSystemScript.add_resonance(run_state, 3, "历练抉择")
	CultivationScript.advance_time(run_state, 1)
	_sync_state_views()
	current_event = {}
	if CultivationScript.is_dead(run_state):
		_end_current_life("因果事件中的重创")
		return
	_save_current_state("因果抉择已自动封存")
	_show_game()


func _format_delta_hint(deltas: Dictionary) -> String:
	var names := {
		"exp": "修为", "hp": "气血", "mp": "灵力", "karma": "因果",
		"dao_heart": "道心", "reputation": "名望", "enmity": "仇怨",
		"spirit_stones": "灵石", "pills": "丹药",
	}
	var parts: Array[String] = []
	for key in deltas.keys():
		var value := int(deltas[key])
		parts.append("%s%+d" % [str(names.get(key, key)), value])
	return "可能回响 · " + "  ".join(parts) if not parts.is_empty() else "结果不会立刻显形"


func _choice_unavailable_reason(choice: Dictionary) -> String:
	var deltas: Dictionary = choice.get("deltas", {})
	var resource_names := {"spirit_stones": "灵石", "pills": "丹药"}
	for resource_id in resource_names.keys():
		var delta := int(deltas.get(resource_id, 0))
		if delta < 0 and int(player.get(resource_id, 0)) + delta < 0:
			return "%s不足，无法作出这个选择。" % str(resource_names[resource_id])
	return ""


func _cycle_era() -> void:
	var index := ERA_ORDER.find(current_era)
	var next_era: String = str(ERA_ORDER[(index + 1) % ERA_ORDER.size()])
	var transition: Dictionary = WorldSimulationScript.transition_era(
		run_state, GameStateScript.era_id_for_name(next_era))
	if not bool(transition.get("ok", false)):
		feedback = "天机镜中的纪元裂隙没有稳定下来。"
		_show_game()
		return
	_sync_state_views()
	feedback = "天机镜越过一层纪元尘埃：%s覆盖旧日山河，旧人与新势力同时留在年史中。" % current_era
	_add_memory("旧玉观测到%s的一段可能未来。" % current_era)
	_save_current_state("纪元变化已自动封存")
	_show_game()


func _manual_save() -> void:
	_save_current_state("手动封存")
	_show_game()


func _save_current_state(reason: String) -> bool:
	_commit_state_views()
	var save_result: Dictionary = save_service.call("save_game", run_state)
	if bool(save_result.get("ok", false)):
		save_notice = "%s · %s" % [reason, str(save_result.get("message", "已保存"))]
		return true
	save_notice = "保存失败 · %s" % str(save_result.get("message", "未知原因"))
	return false


func _add_memory(text: String) -> void:
	recent_memories.append(text)
	while recent_memories.size() > 12:
		recent_memories.pop_front()
	run_state["recent_memories"] = recent_memories.duplicate()


func _end_current_life(cause: String) -> void:
	_commit_state_views()
	var result: Dictionary = ReincarnationScript.close_life(run_state, cause)
	if not bool(result.get("ok", false)) and str(result.get("code", "")) != "already_closed":
		feedback = "旧玉无法封存此世，轮回暂时停在门外。"
		_show_game()
		return
	_sync_state_views()
	_save_current_state("此世终章已封存")
	_show_reincarnation()


func _transcend_life() -> void:
	if int(player.get("realm_index", 0)) < 19:
		feedback = "此世大道尚未圆满，轮回玉不会提前收束命途。"
		_show_game()
		return
	_add_memory("你在%s留下完整道痕，并主动让今身归入轮回。" % str(player.realm))
	_end_current_life("证道圆满，自择轮回")


func _current_death_cause() -> String:
	if int(player.get("hp", 0)) <= 0:
		return "重伤不治"
	return "寿元耗尽"


func _show_reincarnation() -> void:
	state = ScreenState.REINCARNATION
	_clear_screen()
	_set_background(MENU_SCENE)
	var legacy: Dictionary = run_state.get("legacy", {})
	var lives: Array = legacy.get("past_lives", [])
	if lives.is_empty():
		if bool(run_state.get("life_closed", false)):
			run_state["life_closed"] = false
			_end_current_life("旧档终章补录")
			return
		_show_menu()
		return
	var last_life: Dictionary = lives[-1]
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 16)
	screen_host.add_child(page)
	var card := _panel(0.86, Color("d7bd75"))
	card.custom_minimum_size = Vector2(760, 560)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)
	column.add_child(_label("此世已尽，道痕未灭", 34, Color("f0d99c"), HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_label("第%d世 · %s · %s %d层 · 享年%d" % [
		int(last_life.get("generation", 1)), str(last_life.get("name", "无名")),
		str(last_life.get("realm", "凡人")), int(last_life.get("level", 1)),
		int(last_life.get("age_at_death", 16))],
		18, Color(0.86, 0.87, 0.85), HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_label("死因 · %s\n道途归结 · %s" % [
		str(last_life.get("cause_of_death", "命数已尽")), str(last_life.get("dao_name", "本我大道"))],
		17, Color(0.78, 0.82, 0.82), HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_divider())
	column.add_child(_section_title("将被下一世听见的回响"))
	var echoes: Array = last_life.get("echoes", [])
	if echoes.is_empty():
		column.add_child(_label("这一世没有留下显眼遗产，但世界仍记得你曾来过。", 16,
			Color(0.75, 0.78, 0.79), HORIZONTAL_ALIGNMENT_CENTER))
	else:
		for echo in echoes.slice(0, 4):
			var echo_data: Dictionary = echo
			var echo_label := _label("• %s · %s" % [echo_data.get("name", "无名回响"), echo_data.get("description", "")],
				16, Color("d9d2bb"))
			echo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			column.add_child(echo_label)
	column.add_child(_spacer(6))
	var name_input := LineEdit.new()
	name_input.name = "NextLifeNameInput"
	name_input.placeholder_text = "为第%d世写下道号" % (int(run_state.get("generation", 1)) + 1)
	name_input.max_length = 32
	name_input.custom_minimum_size.y = 48
	_style_line_edit(name_input)
	column.add_child(name_input)
	column.add_child(_button("步入下一世", _begin_next_life.bind(name_input), true))
	column.add_child(_label("世界不会重置：旧人会老去，宗门会兴衰，未竟因果会换一副面孔回来。",
		14, Color(0.72, 0.76, 0.77), HORIZONTAL_ALIGNMENT_CENTER))
	name_input.grab_focus()


func _begin_next_life(name_input: LineEdit) -> void:
	var result: Dictionary = ReincarnationScript.begin_next_life(run_state, name_input.text)
	if not bool(result.get("ok", false)):
		feedback = "轮回尚未准备好：%s" % str(result.get("code", "unknown"))
		_show_reincarnation()
		return
	_sync_state_views()
	current_event = {}
	_save_current_state("新一世已立档")
	_show_game()


func _show_inventory() -> void:
	state = ScreenState.INVENTORY
	_sync_state_views()
	_clear_screen()
	_apply_era_visuals()
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 16)
	screen_host.add_child(page)
	page.add_child(_label("行囊与炼器", 30, Color("f0d99c"), HORIZONTAL_ALIGNMENT_CENTER))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	page.add_child(body)
	body.add_child(_build_inventory_list())
	body.add_child(_build_forge_panel())
	var back_button := _button("返回山河", _show_game, true)
	back_button.name = "InventoryBackButton"
	page.add_child(back_button)


func _build_inventory_list() -> Control:
	var panel := _panel(0.84, era_accent)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(_section_title("所持器物"))
	var inventory: Dictionary = run_state.inventory
	var equipped: Dictionary = inventory.equipped
	column.add_child(_label("当前 · 兵器 %s  护甲 %s  灵物 %s" % [
		_equipped_name(str(equipped.weapon_id)), _equipped_name(str(equipped.armor_id)),
		_equipped_name(str(equipped.relic_id))], 15, Color(0.78, 0.84, 0.83)))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for entry_value in inventory.items:
		var entry: Dictionary = entry_value
		var row := HBoxContainer.new()
		var name_text := "%s ×%d" % [ItemSystemScript.display_name(entry), int(entry.quantity)]
		var item_label := _label(name_text, 16, Color(0.86, 0.87, 0.84))
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(item_label)
		var item_id := str(entry.item_id)
		var definition: Dictionary = ItemSystemScript.ITEMS.get(item_id, {})
		if str(definition.get("category", "")) == "consumable":
			row.add_child(_button("服用", _use_inventory_item.bind(item_id), false))
		elif definition.has("slot") or entry.has("slot"):
			row.add_child(_button("装备", _equip_inventory_item.bind(str(entry.instance_id)), false))
		list.add_child(row)
	list.add_child(_divider())
	list.add_child(_section_title("材料"))
	var material_names: Array[String] = []
	for material_id in (inventory.materials as Dictionary).keys():
		var material_definition: Dictionary = ItemSystemScript.ITEMS.get(str(material_id), {})
		material_names.append("%s ×%d" % [str(material_definition.get("name", material_id)),
			int(inventory.materials[material_id])])
	list.add_child(_label("  ·  ".join(material_names) if not material_names.is_empty() else "炉中尚无材料。",
		15, Color(0.73, 0.78, 0.78)))
	return panel


func _build_forge_panel() -> Control:
	var panel := _panel(0.84, era_accent)
	panel.custom_minimum_size.x = 390
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(_section_title("当世炼器"))
	for recipe_id_value in ItemSystemScript.RECIPES.keys():
		var recipe_id := str(recipe_id_value)
		var recipe: Dictionary = ItemSystemScript.RECIPES[recipe_id]
		var cost_parts: Array[String] = []
		for material_id in (recipe.cost as Dictionary).keys():
			var material: Dictionary = ItemSystemScript.ITEMS.get(str(material_id), {})
			cost_parts.append("%s%d" % [str(material.get("name", material_id)), int(recipe.cost[material_id])])
		cost_parts.append("灵石%d" % int(recipe.spirit_stones))
		var button := _button("%s\n%s" % [str(recipe.name), " · ".join(cost_parts)],
			_forge_inventory_item.bind(recipe_id), false)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 72
		var readiness: Dictionary = ItemSystemScript.can_forge(run_state, recipe_id)
		button.disabled = not bool(readiness.ok)
		button.tooltip_text = "材料或灵石不足。" if button.disabled else ""
		column.add_child(button)
	column.add_child(_spacer(8))
	column.add_child(_label("品质由造化道途、当前境界与此世随机游标共同决定。道品虚痕佩可随轮回保留。",
		14, Color(0.72, 0.77, 0.78)))
	return panel


func _use_inventory_item(item_id: String) -> void:
	var result: Dictionary = ItemSystemScript.use_consumable(run_state, item_id)
	feedback = "你服下%s，药力已经进入此世经脉。" % str((ItemSystemScript.ITEMS[item_id] as Dictionary).name) \
		if bool(result.ok) else "此刻无法服用这件物品。"
	_sync_state_views()
	if bool(result.ok):
		_save_current_state("行囊变化已封存")
	_show_inventory()


func _equip_inventory_item(reference_id: String) -> void:
	var result: Dictionary = ItemSystemScript.equip(run_state, reference_id)
	feedback = "器物与气机完成共鸣。" if bool(result.ok) else "这件器物无法装备。"
	_sync_state_views()
	if bool(result.ok):
		_save_current_state("装备变化已封存")
	_show_inventory()


func _forge_inventory_item(recipe_id: String) -> void:
	var result: Dictionary = ItemSystemScript.forge(run_state, recipe_id)
	if bool(result.ok):
		feedback = "炉火收束，你炼成%s%s。" % [str(result.quality_name), str((ItemSystemScript.RECIPES[recipe_id] as Dictionary).item_name)]
		_add_memory("第%d年，一件%s器物在你的炉火中留下稳定器痕。" % [
			int((run_state.world as Dictionary).get("year", 1)), str(result.quality_name)])
		AchievementSystemScript.add_resonance(run_state, 4, "当世炼器")
		_sync_state_views()
		_save_current_state("炼器结果已封存")
	else:
		feedback = "炉中材料尚不足，器胚没有成形。"
	_sync_state_views()
	_show_inventory()


func _show_armory() -> void:
	state = ScreenState.ARMORY
	_sync_state_views()
	_clear_screen()
	_apply_era_visuals(MENU_SCENE)
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 16)
	screen_host.add_child(page)
	page.add_child(_label("成就与轮回玉藏兵", 30, Color("f1d79a"), HORIZONTAL_ALIGNMENT_CENTER))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	page.add_child(body)
	body.add_child(_build_achievement_list())
	body.add_child(_build_jade_armory_list())
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	page.add_child(actions)
	actions.add_child(_button("切换下一件 [Y]", _cycle_jade_weapon, false))
	var invoke_button := _button("玉兵显圣 [J]", _invoke_jade_weapon, true)
	var current := AchievementSystemScript.current_weapon(run_state)
	invoke_button.disabled = current.is_empty() or int(current.get("charge", 0)) < 100
	invoke_button.tooltip_text = "显圣蓄能尚未达到100。" if invoke_button.disabled else "释放当前玉兵道法。"
	actions.add_child(invoke_button)
	var back_button := _button("返回山河", _show_game, false)
	back_button.name = "ArmoryBackButton"
	actions.add_child(back_button)


func _build_achievement_list() -> Control:
	var panel := _panel(0.84, era_accent)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(_section_title("成就 %d/16" % AchievementSystemScript.unlocked_count(run_state)))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 9)
	scroll.add_child(list)
	var armory: Dictionary = run_state.legacy.armory
	for value in (AchievementSystemScript.load_definitions().get("achievements", []) as Array):
		var achievement: Dictionary = value
		var unlocked := bool((armory.achievements as Dictionary).get(str(achievement.id), false))
		var tier_color := _achievement_tier_color(int(achievement.tier))
		var label := _label("%s [%s] %s\n%s" % ["已成" if unlocked else "未成",
			AchievementSystemScript.TIER_NAMES[int(achievement.tier)], str(achievement.name), str(achievement.description)],
			15, tier_color if unlocked else Color(0.58, 0.61, 0.62))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(label)
	return panel


func _build_jade_armory_list() -> Control:
	var panel := _panel(0.84, Color("d5a957"))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(_section_title("轮回玉藏兵"))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var armory: Dictionary = run_state.legacy.armory
	for value in (AchievementSystemScript.load_definitions().get("weapons", []) as Array):
		var definition: Dictionary = value
		var weapon: Dictionary = armory.weapons[str(definition.id)]
		if not bool(weapon.unlocked):
			list.add_child(_label("◇ %s · 尚未显化" % str(definition.name), 15, Color(0.55, 0.58, 0.59)))
			continue
		var equipped := str(armory.equipped_id) == str(definition.id)
		var text_value := "%s [%s] %s · %s\n共鸣%d · 蓄能%d/100 · 显圣%d次" % [
			"◆" if equipped else "◇", AchievementSystemScript.TIER_NAMES[int(definition.tier)],
			str(definition.name), AchievementSystemScript.stage_name(int(weapon.stage)),
			int(weapon.resonance), int(weapon.charge), int(weapon.invocations)]
		var button := _button(text_value, _equip_jade_weapon.bind(str(definition.id)), equipped)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 76
		button.disabled = equipped
		list.add_child(button)
	return panel


func _equip_jade_weapon(weapon_id: String) -> void:
	var result: Dictionary = AchievementSystemScript.equip_weapon(run_state, weapon_id)
	feedback = "%s与今生气机完成共鸣。" % str(result.get("name", "轮回玉兵")) if bool(result.ok) else "这件玉兵尚未显化。"
	_sync_state_views()
	if bool(result.ok):
		_save_current_state("玉兵切换已封存")
	_show_armory()


func _cycle_jade_weapon() -> void:
	var return_to_armory := state == ScreenState.ARMORY
	var result: Dictionary = AchievementSystemScript.cycle_weapon(run_state)
	feedback = "当前共鸣切换为%s。" % str(result.get("name", "轮回玉兵")) if bool(result.ok) else "轮回玉中尚无可切换的兵器。"
	_sync_state_views()
	if bool(result.ok):
		_save_current_state("玉兵切换已封存")
	if return_to_armory: _show_armory()
	else: _show_game()


func _invoke_jade_weapon() -> void:
	var return_to_armory := state == ScreenState.ARMORY
	var result: Dictionary = AchievementSystemScript.invoke(run_state)
	if bool(result.get("ok", false)):
		feedback = "%s显圣：修为 +%d，气血 +%d，道心 +%d，灵石 +%d。" % [
			str(result.name), int(result.exp), int(result.heal), int(result.dao_heart), int(result.spirit_stones)]
		_add_memory("%s在此世第%d年显圣，道法流派为%s。" % [str(result.name),
			int((run_state.world as Dictionary).get("year", 1)), str(result.style)])
		_sync_state_views()
		_save_current_state("玉兵显圣已封存")
	else:
		feedback = "当前玉兵显圣蓄能不足。"
	if return_to_armory: _show_armory()
	else: _show_game()


func _equipped_name(reference_id: String) -> String:
	if reference_id.is_empty():
		return "无"
	if reference_id == "black_white_jade":
		return "黑白轮回玉"
	for entry_value in (run_state.inventory.items as Array):
		var entry: Dictionary = entry_value
		if str(entry.instance_id) == reference_id:
			return ItemSystemScript.display_name(entry)
	return "失落"


func _local_model_ready() -> bool:
	if not is_instance_valid(ai_bridge):
		return false
	var probe: Dictionary = ai_bridge.call("probe_runtime")
	return bool(probe.get("ready", false))


func _collect_achievement_notices() -> void:
	for notice_value in AchievementSystemScript.consume_notices(run_state):
		if notice_value is Dictionary:
			achievement_notice_queue.append((notice_value as Dictionary).duplicate(true))


func _show_next_achievement_notice() -> void:
	if achievement_notice_queue.is_empty() or is_instance_valid(achievement_toast):
		return
	var notice: Dictionary = achievement_notice_queue.pop_front()
	var tier := clampi(int(notice.get("tier", 0)), 0, 2)
	var panel := _panel(1.0, _achievement_tier_color(tier))
	panel.name = "AchievementToast"
	panel.z_index = 200
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -470
	panel.offset_right = -28
	panel.offset_top = 28
	panel.offset_bottom = 150
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	column.add_child(_label("%s · %s" % ["玉兵觉醒" if str(notice.get("kind", "")) == "awakening" else "成就达成",
		AchievementSystemScript.TIER_NAMES[tier]], 14, _achievement_tier_color(tier), HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_label(str(notice.get("name", "无名道痕")), 23, Color("fff4d6"), HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_label("轮回玉显化 · %s" % str(notice.get("reward_weapon", "旧玉回响")), 15,
		Color(0.84, 0.86, 0.82), HORIZONTAL_ALIGNMENT_CENTER))
	add_child(panel)
	achievement_toast = panel
	panel.position.x += 28
	var enter := create_tween()
	enter.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	enter.tween_property(panel, "position:x", panel.position.x - 28, 0.52)
	await enter.finished
	await get_tree().create_timer(float([4.8, 5.6, 6.5][tier])).timeout
	if not is_instance_valid(panel):
		return
	var exit_tween := create_tween()
	exit_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit_tween.tween_property(panel, "position:x", panel.position.x + 28, 0.52)
	await exit_tween.finished
	if is_instance_valid(panel):
		panel.queue_free()
	achievement_toast = null


func _achievement_tier_color(tier: int) -> Color:
	return [Color("68c9bb"), Color("c695e8"), Color("efb04d")][clampi(tier, 0, 2)]


func _panel(alpha: float, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.078, alpha)
	style.border_color = Color(accent, 0.58)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _button(text_value: String, callback: Callable, primary: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 50
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("f4eee0"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	var normal := _button_style(0.18 if not primary else 0.31, era_accent, 0.44)
	var hover := _button_style(0.34 if not primary else 0.48, era_accent, 0.92)
	var pressed := _button_style(0.50, era_accent, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.pressed.connect(callback)
	return button


func _button_style(alpha: float, accent: Color, border_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.darkened(0.68), alpha)
	style.border_color = Color(accent, border_alpha)
	style.set_border_width_all(1)
	style.border_width_left = 4
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _style_line_edit(edit: LineEdit) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.02, 0.035, 0.055, 0.92)
	normal.border_color = Color(era_accent, 0.64)
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	edit.add_theme_stylebox_override("normal", normal)
	edit.add_theme_stylebox_override("focus", normal.duplicate())
	edit.add_theme_color_override("font_color", Color("f3ede0"))
	edit.add_theme_color_override("font_placeholder_color", Color(0.68, 0.71, 0.72, 0.72))
	edit.add_theme_font_size_override("font_size", 19)


func _label(text_value: String, font_size: int = 18, color: Color = Color.WHITE,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	return label


func _section_title(text_value: String) -> Label:
	var label := _label(text_value, 20, Color(era_accent, 0.98))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.74))
	return label


func _progress_row(title: String, value: int, maximum: int, color: Color) -> Control:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	stack.add_child(_label("%s  %d / %d" % [title, value, maximum], 14,
		Color(0.84, 0.87, 0.87, 0.92)))
	var bar := ProgressBar.new()
	bar.max_value = max(1, maximum)
	bar.value = clamp(value, 0, maximum)
	bar.show_percentage = false
	bar.custom_minimum_size.y = 9
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color(0.10, 0.12, 0.15, 0.78)
	background_style.corner_radius_top_left = 4
	background_style.corner_radius_top_right = 4
	background_style.corner_radius_bottom_left = 4
	background_style.corner_radius_bottom_right = 4
	var fill_style := background_style.duplicate()
	fill_style.bg_color = Color(color, 0.88)
	bar.add_theme_stylebox_override("background", background_style)
	bar.add_theme_stylebox_override("fill", fill_style)
	stack.add_child(bar)
	return stack


func _divider() -> HSeparator:
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 12)
	return separator


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	match state:
		ScreenState.MENU:
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_1]:
				var input := screen_host.find_child("DaoNameInput", true, false) as LineEdit
				if input:
					_start_new_game(input)
			elif event.keycode == KEY_C:
				_continue_game()
			elif event.keycode == KEY_I:
				_import_legacy_game()
		ScreenState.GAME:
			match event.keycode:
				KEY_1: _meditate()
				KEY_2: _open_adventure()
				KEY_3: _breakthrough()
				KEY_4: _start_combat()
				KEY_M: _enter_dungeon()
				KEY_I: _show_inventory()
				KEY_A: _show_armory()
				KEY_Y: _cycle_jade_weapon()
				KEY_J: _invoke_jade_weapon()
				KEY_R:
					if int(player.get("realm_index", 0)) >= 19:
						_transcend_life()
				KEY_TAB: _cycle_era()
				KEY_S: _manual_save()
				KEY_ESCAPE: _show_menu()
		ScreenState.EVENT:
			if event.keycode >= KEY_1 and event.keycode <= KEY_9:
				_resolve_choice(int(event.keycode - KEY_1))
			elif event.keycode == KEY_ESCAPE:
				feedback = "你暂时离开这段因果，但它没有真正结束。"
				current_event = {}
				_show_game()
		ScreenState.REINCARNATION:
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
				var input := screen_host.find_child("NextLifeNameInput", true, false) as LineEdit
				if input:
					_begin_next_life(input)
		ScreenState.AI_PENDING:
			if event.keycode == KEY_ESCAPE:
				_cancel_ai_request()
		ScreenState.INVENTORY:
			if event.keycode in [KEY_ESCAPE, KEY_I]:
				_show_game()
		ScreenState.ARMORY:
			match event.keycode:
				KEY_ESCAPE, KEY_A: _show_game()
				KEY_Y: _cycle_jade_weapon()
				KEY_J: _invoke_jade_weapon()
		ScreenState.COMBAT:
			match event.keycode:
				KEY_1: _resolve_combat_action("attack")
				KEY_2: _resolve_combat_action("guard")
				KEY_3: _resolve_combat_action("spell")
				KEY_4: _resolve_combat_action("pill")
				KEY_5, KEY_ESCAPE: _resolve_combat_action("flee")
		ScreenState.DUNGEON_ROUTE:
			if event.keycode >= KEY_1 and event.keycode <= KEY_3:
				_choose_dungeon_route(int(event.keycode - KEY_1))
			elif event.keycode == KEY_ESCAPE:
				_abandon_dungeon()
		ScreenState.DUNGEON_COMBAT:
			if event.keycode >= KEY_1 and event.keycode <= KEY_9:
				_play_dungeon_card(int(event.keycode - KEY_1))
			elif event.keycode == KEY_0:
				_play_dungeon_card(9)
			elif event.keycode in [KEY_E, KEY_SPACE]:
				_end_dungeon_turn()
			elif event.keycode == KEY_ESCAPE:
				_abandon_dungeon()
