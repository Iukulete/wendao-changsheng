extends Control

const AmbientLayerScript = preload("res://scripts/ambient_layer.gd")
const DaoCompassScript = preload("res://scripts/dao_compass.gd")
const SaveServiceScript = preload("res://scripts/save_service.gd")
const GameStateScript = preload("res://scripts/game_state.gd")
const CultivationScript = preload("res://scripts/cultivation_system.gd")
const ReincarnationScript = preload("res://scripts/reincarnation_system.gd")
const WorldSimulationScript = preload("res://scripts/world_simulation.gd")
const ItemSystemScript = preload("res://scripts/item_system.gd")
const CombatSystemScript = preload("res://scripts/combat_system.gd")
const CombatStageScript = preload("res://scripts/combat_stage.gd")
const DungeonDuelStageScript = preload("res://scripts/dungeon_duel_stage.gd")
const DungeonFeedbackLayerScript = preload("res://scripts/dungeon_feedback_layer.gd")
const StorySystemScript = preload("res://scripts/story_system.gd")
const ObjectiveSystemScript = preload("res://scripts/objective_system.gd")
const EncounterSystemScript = preload("res://scripts/encounter_system.gd")
const AchievementSystemScript = preload("res://scripts/achievement_system.gd")
const DungeonSystemScript = preload("res://scripts/dungeon_system.gd")
const EventCatalogScript = preload("res://scripts/event_catalog.gd")
const AudioDirectorScript = preload("res://scripts/audio_director.gd")
const CharacterArtCatalogScript = preload("res://scripts/character_art_catalog.gd")
const CinematicArtMotionScript = preload("res://scripts/cinematic_art_motion.gd")
const NarrativeConsequenceScript = preload("res://scripts/narrative_consequence_system.gd")

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
const BODY_FONT_PATH := "res://art/fonts/NotoSansSC-Variable.ttf"
const DISPLAY_FONT_PATH := "res://art/fonts/NotoSerifSC-Variable.ttf"

const DEFAULT_PLAYER := {
	"name": "无名",
	"realm": "凡人",
	"level": 1,
	"exp": 0,
	"hp": 100,
	"max_hp": 100,
	"mp": 42,
	"max_mp": 42,
	"age": 18,
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
	MENU, GAME, EVENT, EVENT_RESULT, JOURNAL, REINCARNATION, INVENTORY, COMBAT, ARMORY,
	DUNGEON_ROUTE, DUNGEON_COMBAT, AUDIO_SETTINGS, CULTIVATION, OBJECTIVE,
}

var state: ScreenState = ScreenState.MENU
var current_era: String = "古典修仙纪"
var current_event: Dictionary = {}
var current_event_result: Dictionary = {}
var events: Array = []
var recent_memories: Array[String] = []
var feedback: String = "旧玉仍温，今生尚未落笔。"
var save_notice: String = "尚未封存"
var menu_notice: String = ""
var inventory_notice: String = "器物、材料与装备变化会立即封存。"

var run_state: Dictionary = {}
var player: Dictionary = {}
var save_service: RefCounted = SaveServiceScript.new()
var audio_director: Node
var audio_return_state: ScreenState = ScreenState.MENU

var background: TextureRect
var vignette: ColorRect
var ambient: Control
var screen_host: MarginContainer
var background_time: float = 0.0
var era_accent: Color = Color("e4be4c")
var base_theme: Theme
var body_font: Font
var body_medium_font: Font
var body_semibold_font: Font
var display_font: Font
var achievement_notice_queue: Array[Dictionary] = []
var achievement_toast: Control
var dungeon_action_feedback: Dictionary = {}
var combat_input_locked: bool = false
var combat_feedback_sequence: int = 0


func _ready() -> void:
	var audio_smoke_requested := "--audio-smoke" in OS.get_cmdline_user_args()
	audio_director = AudioDirectorScript.new()
	audio_director.name = "AudioDirector"
	add_child(audio_director)
	if audio_smoke_requested:
		print("AUDIO_DEVICE_SMOKE_READY: driver=%s display=%s" % [
			AudioServer.get_driver_name(), DisplayServer.get_name()])
	if run_state.is_empty():
		run_state = GameStateScript.create_new_game("无名", 1, DEFAULT_PLAYER.roots)
	_sync_state_views()
	_build_theme()
	_build_stage()
	_load_events()
	_show_menu()
	if audio_smoke_requested:
		call_deferred("_run_audio_device_music_smoke")


func _refresh_screen_layout(expected_state: ScreenState) -> void:
	if state != expected_state:
		return
	match expected_state:
		ScreenState.GAME: _show_game()
		ScreenState.COMBAT: _show_combat()
		ScreenState.DUNGEON_ROUTE: _show_dungeon_route()
		ScreenState.DUNGEON_COMBAT: _show_dungeon_combat()
		ScreenState.EVENT: _show_event()
		ScreenState.EVENT_RESULT: _show_event_result()
		ScreenState.JOURNAL: _show_journal()
		ScreenState.REINCARNATION: _show_reincarnation()
		ScreenState.AUDIO_SETTINGS: _show_audio_settings()
		ScreenState.INVENTORY: _show_inventory()


func _run_audio_device_music_smoke() -> void:
	# The exported-product smoke uses the real Windows audio backend while the
	# persisted Master bus is muted.  Exercise both context and era transitions
	# so release validation proves that Ogg decoding and dual-player playback
	# work outside the editor, without producing audible automation noise.
	audio_director.set_context("dungeon")
	await get_tree().process_frame
	var pressure_voices := int(audio_director.debug_music_playing_voice_count())
	var dungeon_ambience_voices := int(audio_director.debug_ambience_playing_voice_count())
	audio_director.set_era("steam")
	await get_tree().process_frame
	audio_director.set_context("boss")
	await get_tree().process_frame
	var decisive_voices := int(audio_director.debug_music_playing_voice_count())
	var rare_cue_ok := bool(audio_director.play_event("dungeon.boss_enter"))
	if (audio_director.get_era() != "steam" or audio_director.get_music_state() != "decisive" or
			pressure_voices != 2 or decisive_voices != 2 or dungeon_ambience_voices != 1 or not rare_cue_ok):
		push_error("AUDIO_DEVICE_MUSIC_SMOKE_FAILED: era=%s state=%s pressure_voices=%d decisive_voices=%d ambience_voices=%d rare_cue=%s" % [
			audio_director.get_era(), audio_director.get_music_state(), pressure_voices,
			decisive_voices, dungeon_ambience_voices, rare_cue_ok])
		return
	print("AUDIO_DEVICE_MUSIC_SMOKE_OK: era=steam state=decisive pressure_voices=2 decisive_voices=2 ambience_voices=1 rare_cue=true")
	audio_director.shutdown_for_exit()
	await get_tree().create_timer(0.15).timeout
	audio_director.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.05).timeout
	print("AUDIO_DEVICE_SHUTDOWN_OK: players_stopped streams_released")
	get_tree().quit(0)


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
	if is_instance_valid(vignette) and vignette.material is ShaderMaterial:
		vignette.material.set_shader_parameter("pulse", (sin(background_time * 1.1) + 1.0) * 0.5)
	if not achievement_notice_queue.is_empty() and not is_instance_valid(achievement_toast):
		_show_next_achievement_notice()


func _build_theme() -> void:
	var body_base := load(BODY_FONT_PATH) as Font
	var display_base := load(DISPLAY_FONT_PATH) as Font
	body_font = _font_variation(body_base, 740)
	body_medium_font = _font_variation(body_base, 790)
	body_semibold_font = _font_variation(body_base, 870)
	display_font = _font_variation(display_base, 700)
	base_theme = Theme.new()
	base_theme.default_font = body_font
	base_theme.default_font_size = 18
	base_theme.set_font("font", "Button", body_medium_font)
	base_theme.set_font("font", "LineEdit", body_font)
	base_theme.set_font("normal_font", "RichTextLabel", body_font)
	base_theme.set_font("bold_font", "RichTextLabel", body_semibold_font)
	base_theme.set_type_variation("DisplayLabel", "Label")
	base_theme.set_font("font", "DisplayLabel", display_font)
	theme = base_theme


func _font_variation(base: Font, weight: int) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = {"wght":weight}
	return variation


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
		screen_host.add_theme_constant_override(side, 28)
	add_child(screen_host)


func _load_events() -> void:
	var validation: Dictionary = EventCatalogScript.validate_catalog()
	if bool(validation.get("ok", false)):
		events = EventCatalogScript.load_events()
	else:
		push_error("无法读取事件数据：%s" % EVENTS_PATH)
		events = []


func _clear_screen() -> void:
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


func _attach_art_motion(target: Control, profile_id: String, layer_mode: int,
		seed_text: String, allow_offset_motion: bool = true) -> void:
	var profile: Dictionary = CharacterArtCatalogScript.motion_profile(profile_id)
	if profile.is_empty():
		return
	var rig := CinematicArtMotionScript.new()
	rig.name = "CinematicArtMotion"
	target.add_child(rig)
	rig.call("configure", target, profile, layer_mode, seed_text, allow_offset_motion)


func _show_menu() -> void:
	state = ScreenState.MENU
	_set_audio_context("menu")
	_clear_screen()
	_set_background(MENU_SCENE)
	var style := _era_style("古典修仙纪")
	era_accent = style.accent
	ambient.call("configure", "motes", style.soft)
	if vignette.material is ShaderMaterial:
		vignette.material.set_shader_parameter("accent", era_accent)
		vignette.material.set_shader_parameter("tint", Color(0.014, 0.025, 0.045, 0.14))

	# Keep every primary desktop action in the first 720p viewport. Narrow or
	# large-font layouts collapse to one column and retain a real scroll path.
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

	var menu_panel := _panel(0.88, era_accent)
	menu_panel.name = "MenuPanel"
	menu_panel.custom_minimum_size = Vector2(590, 0)
	center.add_child(menu_panel)

	var layout := GridContainer.new()
	layout.name = "MenuResponsiveGrid"
	layout.columns = 2 if screen_host.size.x >= 1040.0 else 1
	layout.add_theme_constant_override("h_separation", 28)
	layout.add_theme_constant_override("v_separation", 18)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_panel.add_child(layout)
	scroll.resized.connect(func() -> void:
		if is_instance_valid(layout):
			layout.columns = 2 if scroll.size.x >= 1040.0 else 1
	)

	var identity_column := VBoxContainer.new()
	identity_column.name = "MenuIdentityColumn"
	identity_column.alignment = BoxContainer.ALIGNMENT_CENTER
	identity_column.add_theme_constant_override("separation", 8)
	identity_column.custom_minimum_size.x = 390
	identity_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(identity_column)

	var eyebrow := _label("旧玉纪事 · 神游新篇", 15, Color(era_accent, 0.92), HORIZONTAL_ALIGNMENT_CENTER)
	identity_column.add_child(eyebrow)
	var title := _display_label("问道长生", 60, Color("f4e5b7"), HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override("outline_size", 9)
	title.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.72))
	identity_column.add_child(title)
	var promise := _label("山河会老，名字会被误传；\n只有选择仍在轮回里发光。", 17,
		Color(0.86, 0.88, 0.87, 0.86), HORIZONTAL_ALIGNMENT_CENTER)
	promise.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	promise.custom_minimum_size.x = 370
	identity_column.add_child(promise)
	identity_column.add_child(_spacer(4))

	var seal := DaoCompassScript.new()
	seal.name = "MenuDaoCompass"
	seal.custom_minimum_size = Vector2(250, 176)
	seal.call("set_stats", player.roots, 0, 4, era_accent)
	identity_column.add_child(seal)
	var feature_strip := HBoxContainer.new()
	feature_strip.name = "MenuFeatureStrip"
	feature_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	feature_strip.add_theme_constant_override("separation", 7)
	for feature_text in ["六纪元", "十世轮回", "分歧长卷"]:
		feature_strip.add_child(_menu_feature_pill(feature_text))
	identity_column.add_child(feature_strip)
	identity_column.add_child(_label("一枚旧玉，记录每一世留下的因果。", 14,
		Color(0.70, 0.76, 0.77, 0.82), HORIZONTAL_ALIGNMENT_CENTER))

	var action_panel := _panel(0.42, era_accent)
	action_panel.name = "MenuActionPanel"
	action_panel.custom_minimum_size.x = 474
	action_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(action_panel)
	var action_column := VBoxContainer.new()
	action_column.name = "MenuActionColumn"
	action_column.alignment = BoxContainer.ALIGNMENT_CENTER
	action_column.add_theme_constant_override("separation", 8)
	action_panel.add_child(action_column)
	action_column.add_child(_section_title("请写下此世道号"))
	action_column.add_child(_label("道号只属于这一世，旧玉会替你记住。", 14,
		Color(0.72, 0.77, 0.78, 0.86)))
	var name_input := LineEdit.new()
	name_input.name = "DaoNameInput"
	name_input.placeholder_text = "旧玉会记住这个名字"
	name_input.text = "云归客" if player.name == "无名" else str(player.name)
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input.custom_minimum_size = Vector2(430, 46)
	_style_line_edit(name_input)
	action_column.add_child(name_input)

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
	continue_button.custom_minimum_size = Vector2(430, 48)
	continue_button.disabled = not can_continue
	continue_button.tooltip_text = str(save_probe.get("message", "尚无可继续的旧档。"))
	action_column.add_child(continue_button)

	var start_label := "另开新生 · 覆写当前档" if can_continue else "入世 · 开始新生"
	var start_button := _button(start_label, _start_new_game.bind(name_input), not can_continue)
	start_button.name = "MenuStartButton"
	start_button.custom_minimum_size = Vector2(430, 48)
	action_column.add_child(start_button)
	name_input.text_submitted.connect(func(_submitted_text: String) -> void:
		_start_new_game(name_input)
	)
	if can_continue:
		name_input.focus_next = continue_button.get_path()
		continue_button.focus_previous = name_input.get_path()
		continue_button.focus_next = start_button.get_path()
		start_button.focus_previous = continue_button.get_path()
	else:
		continue_button.focus_mode = Control.FOCUS_NONE
		name_input.focus_next = start_button.get_path()
		start_button.focus_previous = name_input.get_path()
	var legacy_probe: Dictionary = save_service.call("inspect_legacy_saves")
	var can_import_legacy := bool(legacy_probe.get("ok", false))
	var secondary_actions := HBoxContainer.new()
	secondary_actions.name = "MenuSecondaryActions"
	secondary_actions.add_theme_constant_override("separation", 8)
	secondary_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if can_import_legacy:
		var legacy_latest: Dictionary = legacy_probe.get("latest", {})
		var import_text := "导入旧版" if can_continue else "承接旧版"
		var import_button := _button(import_text, _import_legacy_game, false)
		import_button.name = "LegacyImportButton"
		import_button.custom_minimum_size = Vector2(0, 46)
		import_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		import_button.tooltip_text = "%s · %s。只读导入最近的旧版 slot_*.txt；源文件不会被修改。%s" % [
			str(legacy_latest.get("player_name", "旧日之我")),
			str(legacy_latest.get("era", "未知纪元")),
			"当前主档会先自动备份。" if can_continue else "",
		]
		secondary_actions.add_child(import_button)
	var audio_button := _button("音律设置", _open_audio_settings, false)
	audio_button.name = "MenuAudioSettingsButton"
	audio_button.custom_minimum_size = Vector2(0, 46)
	audio_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	secondary_actions.add_child(audio_button)
	var exit_button := _button("离开游戏", _quit_game, false)
	exit_button.name = "MenuExitButton"
	exit_button.custom_minimum_size = Vector2(0, 46)
	exit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	secondary_actions.add_child(exit_button)
	action_column.add_child(secondary_actions)
	var save_status := menu_notice if not menu_notice.is_empty() else str(save_probe.get("message", ""))
	var status_label := _label(save_status, 14,
		Color("e9c67a") if not can_continue and save_probe.get("code", "") == "corrupt_save" else Color(0.72, 0.76, 0.78, 0.84),
		HORIZONTAL_ALIGNMENT_CENTER)
	status_label.name = "MenuSaveStatus"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.x = 430
	action_column.add_child(status_label)
	var shortcut_text := "Enter 开始新生  ·  C 续接旧档  ·  O 音律"
	if can_import_legacy:
		shortcut_text += "  ·  I 导入旧版"
	var shortcut_label := _label(shortcut_text, 13,
		Color(0.72, 0.76, 0.78, 0.78), HORIZONTAL_ALIGNMENT_CENTER)
	shortcut_label.name = "MenuShortcutLabel"
	shortcut_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shortcut_label.custom_minimum_size.x = 430
	action_column.add_child(shortcut_label)
	name_input.grab_focus()


func _quit_game() -> void:
	get_tree().quit()


func _start_new_game(name_input: LineEdit) -> void:
	var dao_name := name_input.text.strip_edges()
	if dao_name.is_empty():
		dao_name = "无名客"
	run_state = GameStateScript.create_new_game(dao_name)
	current_event = {}
	current_event_result = {}
	_sync_state_views()
	menu_notice = ""
	_save_current_state("新生命途已立档")
	_open_adventure()


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
	current_event_result = {}
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
	current_event_result = {}
	_show_game()


func _sync_state_views() -> void:
	run_state = GameStateScript.ensure_v2(run_state)
	WorldSimulationScript.initialize(run_state)
	ItemSystemScript.normalize(run_state)
	CombatSystemScript.normalize(run_state)
	DungeonSystemScript.normalize(run_state)
	StorySystemScript.normalize(run_state)
	ObjectiveSystemScript.normalize(run_state)
	EncounterSystemScript.normalize(run_state)
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
	_set_audio_context("world")
	_clear_screen()
	_apply_era_visuals()

	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 18)
	screen_host.add_child(page)
	var narrow_layout := screen_host.size.x < 1040.0
	page.resized.connect(func() -> void:
		if state == ScreenState.GAME and (screen_host.size.x < 1040.0) != narrow_layout:
			call_deferred("_refresh_screen_layout", ScreenState.GAME)
	)
	page.add_child(_build_header())
	if not dungeon_action_feedback.is_empty():
		var feedback_slot := MarginContainer.new()
		feedback_slot.name = "DungeonFeedbackSlot"
		feedback_slot.custom_minimum_size.y = 58
		feedback_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(feedback_slot)

	var body: BoxContainer = VBoxContainer.new() if narrow_layout else HBoxContainer.new()
	body.name = "GameBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	if narrow_layout:
		var body_scroll := ScrollContainer.new()
		body_scroll.name = "GameBodyScroll"
		body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		body_scroll.follow_focus = true
		body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body_scroll.add_child(body)
		page.add_child(body_scroll)
	else:
		page.add_child(body)
	var player_panel := _build_player_panel()
	var world_panel := _build_world_panel(not narrow_layout)
	var action_panel := _build_action_panel()
	if narrow_layout:
		body.add_child(world_panel)
		var detail_row := HBoxContainer.new()
		detail_row.name = "GameNarrowDetailRow"
		detail_row.add_theme_constant_override("separation", 12)
		detail_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		player_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_row.add_child(player_panel)
		detail_row.add_child(action_panel)
		body.add_child(detail_row)
	else:
		body.add_child(player_panel)
		body.add_child(world_panel)
		body.add_child(action_panel)

	_show_dungeon_action_feedback()


func _build_header() -> Control:
	var header := _panel(0.78, era_accent)
	header.name = "MainHeader"
	header.custom_minimum_size.y = 82
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	header.add_child(row)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_box)
	title_box.add_child(_display_label("问道长生 · %s" % player.name, 28, Color("f4e5b7")))
	title_box.add_child(_label("第%d世 · %s · 世界第 %d 年" % [
		int(run_state.get("generation", 1)), current_era,
		int((run_state.get("world", {}) as Dictionary).get("year", 1))], 15,
		Color(era_accent, 0.92)))
	var status_box := VBoxContainer.new()
	status_box.custom_minimum_size.x = 280
	status_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(status_box)
	status_box.add_child(_label("长卷随章节自动封存", 15, Color("c9c2a8"),
		HORIZONTAL_ALIGNMENT_RIGHT))
	status_box.add_child(_label(save_notice, 13,
		Color("df776c") if save_notice.begins_with("保存失败") else Color(era_accent, 0.88),
		HORIZONTAL_ALIGNMENT_RIGHT))
	return header


func _build_player_panel() -> Control:
	var panel := _panel(0.83, era_accent)
	panel.name = "MainPlayerPanel"
	panel.custom_minimum_size.x = 320
	var column := VBoxContainer.new()
	column.name = "MainPlayerColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	column.add_child(_section_title("此世照影"))

	var identity_row := HBoxContainer.new()
	identity_row.name = "MainPlayerIdentity"
	identity_row.custom_minimum_size.y = 154
	identity_row.add_theme_constant_override("separation", 12)
	identity_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(identity_row)
	var portrait_frame := _panel(0.34, era_accent)
	portrait_frame.name = "MainPortraitFrame"
	portrait_frame.custom_minimum_size = Vector2(104, 154)
	var portrait_style := portrait_frame.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	portrait_style.content_margin_left = 6
	portrait_style.content_margin_right = 6
	portrait_style.content_margin_top = 6
	portrait_style.content_margin_bottom = 6
	portrait_frame.add_theme_stylebox_override("panel", portrait_style)
	identity_row.add_child(portrait_frame)
	var portrait := TextureRect.new()
	portrait.name = "MainPortrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = load(PROTAGONIST)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait)
	_attach_art_motion(portrait, "introspective", CinematicArtMotionScript.LayerMode.PORTRAIT,
		"protagonist-main")

	var identity_detail := VBoxContainer.new()
	identity_detail.name = "MainPlayerVitals"
	identity_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_detail.add_theme_constant_override("separation", 3)
	identity_row.add_child(identity_detail)
	identity_detail.add_child(_label(str(player.name), 20, Color("f1e5c5"),
		HORIZONTAL_ALIGNMENT_CENTER))
	identity_detail.add_child(_label("%s %d层 · 第%d世" % [
		str(player.realm), int(player.level), int(run_state.get("generation", 1))], 13,
		Color(era_accent, 0.86), HORIZONTAL_ALIGNMENT_CENTER))
	identity_detail.add_child(_progress_row("修为", int(player.exp),
		CultivationScript.exp_needed(player), era_accent))
	identity_detail.add_child(_progress_row("气血", int(player.hp), int(player.max_hp), Color("c95858")))
	identity_detail.add_child(_progress_row("灵力", int(player.mp), int(player.max_mp), Color("538fc2")))

	var compass := DaoCompassScript.new()
	compass.name = "PlayerDaoCompass"
	compass.custom_minimum_size = Vector2(276, 92)
	compass.size_flags_vertical = Control.SIZE_EXPAND_FILL
	compass.call("set_stats", player.roots, int(player.karma), int(player.dao_heart), era_accent)
	column.add_child(compass)
	column.add_child(_label("因果 %+d   道心 %d   名望 %+d   仇怨 %d" % [
		int(player.karma), int(player.dao_heart), int(player.reputation), int(player.enmity)],
		13, Color(0.85, 0.87, 0.88, 0.92), HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_label("寿元 %d/%d（%s）  灵石 %d   丹药 %d" % [
		int(player.get("age", 18)), int(player.get("lifespan", 88)),
		CultivationScript.lifespan_pressure(player),
		int(player.spirit_stones),
		int(player.pills) + ItemSystemScript.count(run_state, "healing_pill")],
		13, Color(0.72, 0.78, 0.80, 0.90), HORIZONTAL_ALIGNMENT_CENTER))
	var effective_stats: Dictionary = ItemSystemScript.effective_stats(run_state)
	column.add_child(_label("实战属性 · 攻%d  守%d  气血上限%d" % [
		int(effective_stats.attack), int(effective_stats.defense), int(effective_stats.max_hp)],
		13, Color(0.76, 0.82, 0.82), HORIZONTAL_ALIGNMENT_CENTER))
	var jade_weapon: Dictionary = AchievementSystemScript.current_weapon(run_state)
	var relic_resonance := int(((run_state.get("legacy", {}) as Dictionary).get("relic", {}) as Dictionary).get("resonance", 0))
	var weapon_summary := "尚未显化" if jade_weapon.is_empty() else "%s·%s %d/100" % [
		str(jade_weapon.name), str(jade_weapon.stage_name), int(jade_weapon.charge)]
	column.add_child(_label("旧玉共鸣 %d   玉兵 · %s" % [relic_resonance, weapon_summary],
		13, Color("e8c87f"), HORIZONTAL_ALIGNMENT_CENTER))
	return panel


func _build_world_panel(use_inner_scroll: bool = true) -> Control:
	var panel := _panel(0.78, era_accent)
	panel.name = "MainWorldPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(_section_title("山河正在发生"))

	var pulse_card := _panel(0.44, era_accent)
	pulse_card.name = "MainWorldPulseCard"
	pulse_card.custom_minimum_size.y = 78
	var pulse := _label(feedback, 18, Color("f0e7d2"))
	pulse.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pulse.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pulse_card.add_child(pulse)
	column.add_child(pulse_card)

	var narrative := RichTextLabel.new()
	narrative.name = "MainWorldNarrative"
	narrative.bbcode_enabled = true
	narrative.fit_content = true
	narrative.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	narrative.add_theme_font_size_override("normal_font_size", 18)
	narrative.add_theme_font_size_override("bold_font_size", 20)
	narrative.text = _world_digest()
	if use_inner_scroll:
		var scroll := ScrollContainer.new()
		scroll.name = "MainWorldScroll"
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(scroll)
		scroll.add_child(narrative)
	else:
		column.add_child(narrative)
	return panel


func _build_action_panel() -> Control:
	var panel := _panel(0.84, era_accent)
	panel.name = "GameActionPanel"
	panel.custom_minimum_size.x = 300
	var column := VBoxContainer.new()
	column.name = "GameActionColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	column.add_child(_section_title("当前章节"))
	column.add_child(_build_chapter_direction())
	column.add_child(_divider())
	var action_grid := VBoxContainer.new()
	action_grid.name = "ChapterActionList"
	action_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_grid.add_theme_constant_override("separation", 8)
	column.add_child(action_grid)
	var story_ready := not StorySystemScript.next_event(run_state.duplicate(true)).is_empty()
	var encounter: Dictionary = EncounterSystemScript.summary(run_state)
	var primary_text := "继续当前章"
	var primary_callback := _open_adventure
	if bool(encounter.get("active", false)):
		primary_text = "回应敌踪 · %s" % str(encounter.get("title", "无名追兵"))
		primary_callback = _start_combat
	elif not story_ready:
		primary_text = "追索下一处因果"
	var adventure_button := _main_action_button(primary_text, primary_callback, true)
	adventure_button.name = "ChapterPrimaryButton"
	adventure_button.tooltip_text = str(encounter.get("detail", "让当前卷继续向前，而不是在大厅里盲点功能。"))
	action_grid.add_child(adventure_button)
	var meditate_button := _main_action_button("章前准备 · 调息修炼", _show_cultivation, false)
	meditate_button.name = "MeditateButton"
	meditate_button.tooltip_text = "为即将发生的章节积累修为、道心或气血；准备也会推进时间。"
	action_grid.add_child(meditate_button)
	var breakthrough_readiness: Dictionary = CultivationScript.can_breakthrough(player)
	if bool(breakthrough_readiness.get("ok", false)):
		var breakthrough_button := _main_action_button("关键准备 · 叩问瓶颈", _breakthrough, false)
		breakthrough_button.name = "BreakthroughButton"
		breakthrough_button.tooltip_text = "境界突破已经成熟；它会改变后续危机的胜算。"
		action_grid.add_child(breakthrough_button)
	var dungeon: Dictionary = run_state.get("dungeon", {})
	if int(dungeon.get("clues", 0)) > 0 and int(dungeon.get("last_entered_generation", 0)) != int(run_state.get("generation", 1)):
		var dungeon_button := _main_action_button("线索已明 · 踏入镜湖空阙", _enter_dungeon, false)
		dungeon_button.name = "DungeonButton"
		dungeon_button.tooltip_text = "来源：%s。此世只开放一次，胜败都会写入长卷。" % str(dungeon.get("clue_source", "当前因果"))
		action_grid.add_child(dungeon_button)
	column.add_child(_divider())
	column.add_child(_build_secondary_navigation())
	return panel


func _build_chapter_direction() -> Control:
	var box := VBoxContainer.new()
	box.name = "ChapterDirection"
	box.add_theme_constant_override("separation", 5)
	var next_event := StorySystemScript.next_event(run_state.duplicate(true))
	var encounter := EncounterSystemScript.summary(run_state)
	var title := "山河尚有一页未写"
	var hook := "追索下一处因果；修炼、战斗与秘境都会作为故事中的手段出现。"
	if bool(encounter.get("active", false)):
		title = "危机逼近 · %s" % str(encounter.get("title", "无名敌踪"))
		hook = "%s · 尚余%d次年轮，回应或拖延都会改变山河。" % [
			str(encounter.get("detail", "敌意已经显形。")), int(encounter.get("remaining_turns", 0))]
	elif not next_event.is_empty():
		title = str(next_event.get("title", "命途下一章"))
		hook = str(next_event.get("description", "下一页正在等待你的选择。")).left(170)
	box.add_child(_label(title, 17, Color("e8c87f")))
	var hook_label := _label(hook, 14, Color(0.80, 0.84, 0.83, 0.94))
	hook_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hook_label)
	var story := StorySystemScript.normalize(run_state)
	var threads: Array = story.get("unresolved_threads", [])
	if not threads.is_empty():
		var thread_label := _label("未竟 · %s" % str(threads[-1]).split(":")[-1], 12,
			Color(0.72, 0.78, 0.78, 0.9))
		thread_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(thread_label)
	var characters: Array = CharacterArtCatalogScript.story_characters()
	var relationship_text := NarrativeConsequenceScript.relationship_summary(run_state, characters)
	var obligation_text := NarrativeConsequenceScript.open_obligation_summary(run_state, characters)
	var consequence_label := _label("牵系 · %s\n未偿 · %s" % [
		relationship_text.left(72), obligation_text.left(88)], 12,
		Color(0.70, 0.78, 0.78, 0.90))
	consequence_label.name = "ChapterConsequenceSummary"
	consequence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(consequence_label)
	return box


func _build_secondary_navigation() -> Control:
	var grid := GridContainer.new()
	grid.name = "SecondaryNavigation"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	var entries := [
		["准备", _show_inventory, "InventoryButton"],
		["传承", _show_armory, "ArmoryButton"],
		["长卷", _show_journal, "JournalButton"],
		["系统", _open_system_menu, "SystemMenuButton"],
	]
	for entry_value in entries:
		var entry: Array = entry_value
		var button := _button(str(entry[0]), entry[1], false, "", true)
		button.name = str(entry[2])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(button)
	return grid


func _open_system_menu() -> void:
	_show_audio_settings()


func _build_objective_section() -> Control:
	var column := VBoxContainer.new()
	column.name = "ObjectiveSection"
	column.add_theme_constant_override("separation", 5)
	var summary: Dictionary = ObjectiveSystemScript.summary(run_state)
	if not bool(summary.get("active", false)):
		var status := "上一轮已经圆满" if str(summary.get("last_result", "")) == "completed" else \
			"尚未择定本轮命途"
		column.add_child(_label("阶段命途 · %s" % status, 14, Color("e8c87f")))
		column.add_child(_label("从修炼、入世或实战中选择一个八回合目标，让每次行动形成连贯计划。",
			12, Color(0.77, 0.81, 0.81, 0.92)))
		var choose_button := _button("择定本轮命途", _show_objective_selection, true, "", true)
		choose_button.name = "ChooseObjectiveButton"
		choose_button.custom_minimum_size.y = 42
		column.add_child(choose_button)
		return column
	column.add_child(_label("阶段命途 · %s" % str(summary.name), 15, Color("e8c87f")))
	column.add_child(_progress_row("道印", int(summary.progress), int(summary.target), Color("8fc7b5")))
	column.add_child(_label("余 %d 次年轮 · 连续践行 %d" % [
		int(summary.remaining_turns), int(summary.streak)], 12, Color(0.78, 0.83, 0.83, 0.92)))
	var recommendation := _label(str(summary.recommendation), 12, Color(0.72, 0.77, 0.78, 0.88))
	recommendation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(recommendation)
	return column


func _show_objective_selection() -> void:
	state = ScreenState.OBJECTIVE
	_set_audio_context("world")
	_clear_screen()
	_apply_era_visuals()
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 18)
	screen_host.add_child(page)
	var heading := _panel(0.82, era_accent)
	heading.custom_minimum_size.y = 104
	var heading_column := VBoxContainer.new()
	heading_column.add_child(_display_label("择定本轮问道", 30, Color("f4e5b7")))
	heading_column.add_child(_label("选择不是职业锁定。八次年轮内完成目标即可得偿，未完成只会中断连续践行。",
		15, Color(0.82, 0.85, 0.84, 0.94)))
	heading.add_child(heading_column)
	page.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var options: BoxContainer = VBoxContainer.new() if screen_host.size.x < 1040.0 else HBoxContainer.new()
	options.name = "ObjectiveOptions"
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 14)
	scroll.add_child(options)
	var first_button: Button
	for index in range(ObjectiveSystemScript.OBJECTIVE_IDS.size()):
		var objective_id: String = ObjectiveSystemScript.OBJECTIVE_IDS[index]
		var option := _build_objective_option(objective_id, index + 1)
		options.add_child(option)
		if first_button == null:
			first_button = option.find_child("ObjectiveOptionButton_%s" % objective_id, true, false) as Button
	var back := _button("返回山河", _show_game, false)
	back.name = "ObjectiveBackButton"
	back.custom_minimum_size.y = 46
	page.add_child(back)
	if first_button != null:
		first_button.grab_focus()


func _build_objective_option(objective_id: String, number: int) -> PanelContainer:
	var definition: Dictionary = ObjectiveSystemScript.definition(objective_id)
	var card := _panel(0.84, era_accent)
	card.name = "ObjectiveOption_%s" % objective_id
	card.custom_minimum_size = Vector2(0, 250)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	column.add_child(_label("%d · %s" % [number, str(definition.name)], 22, Color("f0ddb1")))
	var tagline := _label(str(definition.tagline), 16, Color("edf0ea"))
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tagline)
	var recommendation := _label(str(definition.recommendation), 14, Color(0.72, 0.80, 0.80, 0.92))
	recommendation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(recommendation)
	var reward := _label("圆满所得 · %s" % ObjectiveSystemScript.reward_text(objective_id, run_state),
		14, Color("8fc7b5"))
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(reward)
	var choose := _button("立下此愿", _select_objective.bind(objective_id), true)
	choose.name = "ObjectiveOptionButton_%s" % objective_id
	choose.custom_minimum_size.y = 48
	column.add_child(choose)
	return card


func _select_objective(objective_id: String) -> void:
	var result: Dictionary = ObjectiveSystemScript.choose(run_state, objective_id)
	if not bool(result.get("ok", false)):
		feedback = "当前命途仍在践行，不能无代价改立新愿。"
		_show_game()
		return
	feedback = str(result.get("message", "阶段命途已经择定。"))
	_add_memory("第%d年，你立下阶段命途【%s】。" % [
		int((run_state.get("world", {}) as Dictionary).get("year", 1)),
		str(ObjectiveSystemScript.definition(objective_id).get("name", objective_id))])
	_save_current_state("阶段命途已自动封存")
	_show_game()


func _show_cultivation() -> void:
	if bool(run_state.get("life_closed", false)) or CultivationScript.is_dead(run_state):
		_end_current_life(_current_death_cause())
		return
	state = ScreenState.CULTIVATION
	_set_audio_context("world")
	_clear_screen()
	_apply_era_visuals()
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 18)
	screen_host.add_child(page)
	var heading := _panel(0.82, era_accent)
	heading.custom_minimum_size.y = 110
	var heading_column := VBoxContainer.new()
	heading_column.add_child(_display_label("运转周天", 30, Color("f4e5b7")))
	heading_column.add_child(_label("%s %d层 · 气血 %d/%d · 灵潮 %d" % [
		str(player.realm), int(player.level), int(player.hp), int(player.max_hp),
		int((run_state.get("world", {}) as Dictionary).get("qi_tide", 50))],
		15, Color(0.82, 0.86, 0.85, 0.94)))
	heading.add_child(heading_column)
	page.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var choices: BoxContainer = VBoxContainer.new() if screen_host.size.x < 1040.0 else HBoxContainer.new()
	choices.name = "CultivationChoices"
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 14)
	scroll.add_child(choices)
	var first_button: Button
	for index in range(CultivationScript.MEDITATION_MODE_IDS.size()):
		var mode_id: String = CultivationScript.MEDITATION_MODE_IDS[index]
		var option := _build_cultivation_option(mode_id, index + 1)
		choices.add_child(option)
		if first_button == null:
			first_button = option.find_child("CultivationModeButton_%s" % mode_id, true, false) as Button
	var back := _button("暂不运功", _show_game, false)
	back.name = "CultivationBackButton"
	back.custom_minimum_size.y = 46
	page.add_child(back)
	if first_button != null:
		first_button.grab_focus()


func _build_cultivation_option(mode_id: String, number: int) -> PanelContainer:
	var preview: Dictionary = CultivationScript.meditation_preview(run_state, mode_id)
	var card := _panel(0.84, era_accent)
	card.name = "CultivationMode_%s" % mode_id
	card.custom_minimum_size = Vector2(0, 252)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	column.add_child(_label("%d · %s" % [number, str(preview.name)], 22, Color("f0ddb1")))
	var description := _label(str(preview.description), 16, Color("edf0ea"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(description)
	column.add_child(_label("预计修为 +%d～%d" % [
		int(preview.minimum_gain), int(preview.maximum_gain)], 16, Color("8fc7b5")))
	var consequence := "恢复气血，补充灵力"
	if mode_id == "rush":
		consequence = "气血 -%d" % int(preview.hp_cost)
	elif mode_id == "insight":
		consequence = "道心 +1 · 灵潮越盛，修为越高"
	column.add_child(_label(consequence, 14,
		Color("dc8278") if mode_id == "rush" else Color("d9c98f")))
	var choose := _button("按此法运功", _resolve_meditation.bind(mode_id), true)
	choose.name = "CultivationModeButton_%s" % mode_id
	choose.custom_minimum_size.y = 48
	choose.disabled = not bool(preview.get("available", true))
	choose.tooltip_text = "气血至少需要 %d。" % (int(preview.hp_cost) + 1) if choose.disabled else ""
	column.add_child(choose)
	return card


func _main_action_button(text_value: String, callback: Callable, primary: bool) -> Button:
	var button := _button(text_value, callback, primary, "", true)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


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
			int(npc.get("age", 18)), _faction_name(str(npc.get("faction_id", "")), factions),
			relation_suffix]
		visible_npcs += 1
		if visible_npcs >= 4:
			break
	if npc_lines.is_empty():
		npc_lines = "- 旧人皆已隐入年史。\n"
	var encounter: Dictionary = EncounterSystemScript.summary(run_state)
	var encounter_line := "当前没有可追索敌踪；先历练、卷入因果，再决定是否迎战。"
	if bool(encounter.get("active", false)):
		encounter_line = "[color=#ef9a78][b]%s[/b][/color] · 尚余%d次年轮\n%s" % [
			str(encounter.get("title", "无名敌踪")), int(encounter.get("remaining_turns", 0)),
			str(encounter.get("detail", "杀机仍在山河间游移。"))]
	return "[color=#%s][font_size=22][b]%s[/b][/font_size][/color]\n\n%s\n\n" % [
		era_accent.to_html(false), current_era, era_line] + \
		"[color=#d9c98f][b]天地脉象[/b][/color]\n" + \
		"世界第%d年 · 灵潮%d · 稳定%d · 纪元压力%d\n%s\n\n" % [
			int(world.get("year", 1)), int(world.get("qi_tide", 50)),
			int(world.get("stability", 65)), int(world.get("era_pressure", 0)), annual_line] + \
		"[color=#d9c98f][b]当前敌情[/b][/color]\n" + encounter_line + "\n\n" + \
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
	_resolve_meditation("steady")


func _resolve_meditation(mode_id: String) -> void:
	var result: Dictionary = CultivationScript.meditate(run_state, -1, mode_id)
	if not bool(result.get("ok", false)):
		if str(result.get("code", "")) == "life_ended":
			_end_current_life(_current_death_cause())
			return
		feedback = str(result.get("message", "此刻无法运转周天。"))
		_show_cultivation()
		return
	_sync_state_views()
	var gain := int(result.get("gain", 0))
	var levels_gained := int(result.get("levels_gained", 0))
	var level_note := "，连破%d层" % levels_gained if levels_gained > 0 else ""
	var consequence := ""
	if mode_id == "steady":
		consequence = "，气血恢复 %d" % int(result.get("hp_recovered", 0))
	elif mode_id == "rush":
		consequence = "，气血消耗 %d" % int(result.get("hp_cost", 0))
	elif mode_id == "insight":
		consequence = "，道心 +%d" % int(result.get("dao_heart_gain", 0))
	feedback = "你以【%s】运转周天，修为 +%d%s%s。" % [
		str(result.get("mode_name", "守一周天")), gain, level_note, consequence]
	_add_memory("第%d年，你在%s以%s运功，命途罗盘的%s位微微发亮。" % [
		int((run_state.world as Dictionary).get("year", 1)), current_era,
		str(result.get("mode_name", "守一周天")),
		["火", "水", "木", "金", "土"][int(run_state.rng_cursor) % 5]])
	if bool(result.get("dead", false)):
		_end_current_life("寿元耗尽")
		return
	AchievementSystemScript.add_resonance(run_state,
		2 + levels_gained * 2, "周天修炼")
	var objective_result := _record_objective_action("meditate_%s" % mode_id)
	_sync_state_views()
	_append_objective_feedback(objective_result)
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
		var objective_action := "breakthrough_success" if bool(result.get("success", false)) else \
			"breakthrough_failure"
		var objective_result := _record_objective_action(objective_action)
		_sync_state_views()
		_append_objective_feedback(objective_result)
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
	var expiry: Dictionary = EncounterSystemScript.expire_if_needed(run_state)
	if bool(expiry.get("expired", false)):
		feedback = str(expiry.get("message", "敌踪已经消散。"))
		_sync_state_views()
		_save_current_state("敌踪变化已自动封存")
		_show_game()
		return
	var encounter: Dictionary = EncounterSystemScript.summary(run_state)
	if not bool(encounter.get("active", false)):
		feedback = "当前山河没有可追索敌踪。先去历练，让选择引来真实对手。"
		_show_game()
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
	_set_audio_context("combat")
	_clear_screen()
	_apply_era_visuals()
	var battle: Dictionary = run_state.combat.current
	var intent_forecast: Dictionary = CombatSystemScript.intent_forecast(battle)
	var action_forecasts: Dictionary = CombatSystemScript.action_forecasts(run_state, battle)
	var technique_forecasts: Array = CombatSystemScript.technique_forecasts(run_state, battle)
	var page := VBoxContainer.new()
	page.name = "CombatPage"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 8)
	screen_host.add_child(page)
	var narrow_layout := screen_host.size.x < 1040.0
	page.resized.connect(func() -> void:
		if state == ScreenState.COMBAT and (screen_host.size.x < 1040.0) != narrow_layout:
			call_deferred("_refresh_screen_layout", ScreenState.COMBAT)
	)

	var objective: Dictionary = CombatSystemScript.battle_objective(battle)
	page.add_child(_build_combat_header(battle, objective))
	page.add_child(_build_combat_status_band(battle))

	var arena_row := HBoxContainer.new()
	arena_row.name = "CombatArenaRow"
	arena_row.custom_minimum_size.y = 218
	arena_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena_row.add_theme_constant_override("separation", 10)
	page.add_child(arena_row)

	var stage_frame := _panel(0.46, era_accent)
	stage_frame.name = "CombatStageFrame"
	stage_frame.custom_minimum_size.x = 270 if narrow_layout else 390
	stage_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_frame.size_flags_stretch_ratio = 0.82
	var stage_style := stage_frame.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	stage_style.content_margin_left = 0
	stage_style.content_margin_right = 0
	stage_style.content_margin_top = 0
	stage_style.content_margin_bottom = 0
	stage_style.corner_radius_top_left = 6
	stage_style.corner_radius_top_right = 6
	stage_style.corner_radius_bottom_left = 6
	stage_style.corner_radius_bottom_right = 6
	stage_frame.add_theme_stylebox_override("panel", stage_style)
	var combat_stage: Control = CombatStageScript.new()
	combat_stage.name = "CombatStage"
	combat_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combat_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	combat_stage.call("configure", battle, era_accent)
	stage_frame.add_child(combat_stage)
	arena_row.add_child(stage_frame)

	var tactics := _build_combat_tactics_panel(battle, intent_forecast, objective, narrow_layout)
	tactics.size_flags_stretch_ratio = 1.18
	arena_row.add_child(tactics)
	page.add_child(_build_combat_action_deck(battle, action_forecasts, technique_forecasts,
		intent_forecast, objective))


func _build_combat_header(battle: Dictionary, objective: Dictionary) -> Control:
	var header := _panel(0.82, era_accent)
	header.name = "CombatHeader"
	header.custom_minimum_size.y = 68
	var style := header.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.content_margin_left = 14
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	header.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	header.add_child(row)
	var title_stack := VBoxContainer.new()
	title_stack.custom_minimum_size.x = 165
	title_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	title_stack.add_theme_constant_override("separation", 0)
	var round_label := _display_label("第%d回合" % int(battle.turn), 23, Color("f5e7bd"))
	round_label.name = "CombatRoundTitle"
	title_stack.add_child(round_label)
	var era_label := _label(current_era, 12, Color(era_accent, 0.88))
	era_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_stack.add_child(era_label)
	row.add_child(title_stack)

	var context := VBoxContainer.new()
	context.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	context.alignment = BoxContainer.ALIGNMENT_CENTER
	context.add_theme_constant_override("separation", 1)
	var motivation := str(objective.get("motivation", "")).strip_edges()
	if motivation.is_empty():
		motivation = "%s已封住你的去路。" % str(battle.get("enemy_name", "来敌"))
	var motive_label := _label("敌踪 · %s" % motivation, 12, Color(0.72, 0.79, 0.79, 0.90))
	motive_label.name = "CombatEnemyMotive"
	motive_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	context.add_child(motive_label)
	var stakes := str(objective.get("stakes", "")).strip_edges()
	if stakes.is_empty():
		stakes = "压住来敌，活着把这一段因果带回去。"
	var stakes_label := _label("此战所争 · %s" % stakes, 14, Color(0.90, 0.89, 0.82, 0.98))
	stakes_label.name = "CombatStoryStakes"
	stakes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stakes_label.max_lines_visible = 2
	context.add_child(stakes_label)
	row.add_child(context)
	var log_button := _button("实录", _open_combat_log_overlay, false, "", true)
	log_button.name = "CombatLogButton"
	log_button.custom_minimum_size = Vector2(70, 38)
	row.add_child(log_button)
	return header


func _build_combat_status_band(battle: Dictionary) -> Control:
	var band := _panel(0.72, Color("7aa9b5"))
	band.name = "CombatStatusBand"
	band.custom_minimum_size.y = 84
	var style := band.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	band.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	band.add_child(row)
	var player_status := _build_combatant_status_block("此世之我", battle, false)
	player_status.name = "CombatPlayerStatus"
	row.add_child(player_status)
	var divider := VSeparator.new()
	divider.add_theme_constant_override("separation", 8)
	row.add_child(divider)
	var enemy_status := _build_combatant_status_block(str(battle.get("enemy_name", "来敌")), battle, true)
	enemy_status.name = "CombatEnemyStatus"
	row.add_child(enemy_status)
	return band


func _build_combatant_status_block(title: String, battle: Dictionary, enemy_side: bool) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.0
	column.add_theme_constant_override("separation", 3)
	var hp := int(battle.get("enemy_hp" if enemy_side else "player_hp", 0))
	var max_hp := int(battle.get("enemy_max_hp" if enemy_side else "player_max_hp", 1))
	var attack := int(battle.get("enemy_attack" if enemy_side else "player_attack", 0))
	var defense := int(battle.get("enemy_defense" if enemy_side else "player_defense", 0))
	var statuses_value: Variant = battle.get("enemy_statuses" if enemy_side else "player_statuses", {})
	var statuses: Dictionary = statuses_value if statuses_value is Dictionary else {}
	var title_row := HBoxContainer.new()
	var name_label := _label(title, 17, Color("ef9a78") if enemy_side else Color("f0d37e"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_row.add_child(name_label)
	var summary := _label("攻 %d · 护 %d · %s" % [attack, defense, _combat_status_text(statuses)], 12,
		Color(0.76, 0.81, 0.81), HORIZONTAL_ALIGNMENT_RIGHT)
	summary.name = "CombatEnemyStatusSummary" if enemy_side else "CombatPlayerStatusSummary"
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_row.add_child(summary)
	column.add_child(title_row)
	column.add_child(_combat_resource_track("气血", hp, max_hp, Color("c95858"),
		"CombatEnemyHPBar" if enemy_side else "CombatPlayerHPBar"))
	if enemy_side:
		var phase_text := "二相 · %s" % str(battle.get("phase_title", "换势")) \
			if bool(battle.get("second_phase_active", false)) else "气机尚在前半"
		var phase_label := _label(phase_text, 12,
			Color("ef8a72") if bool(battle.get("second_phase_active", false)) else Color(0.68, 0.74, 0.75))
		phase_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		column.add_child(phase_label)
	else:
		column.add_child(_combat_resource_track("灵力", int(battle.get("player_mp", 0)),
			int(battle.get("player_max_mp", 1)), Color("538fc2"), "CombatPlayerMPBar"))
	return column


func _combat_resource_track(title: String, value: int, maximum: int, color: Color,
		node_name: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var value_label := _label("%s %d/%d" % [title, value, maximum], 12, Color(0.80, 0.84, 0.84))
	value_label.custom_minimum_size.x = 102
	row.add_child(value_label)
	var bar := ProgressBar.new()
	bar.name = node_name
	bar.max_value = max(1, maximum)
	bar.value = clamp(value, 0, maximum)
	bar.show_percentage = false
	bar.custom_minimum_size.y = 7
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color(0.08, 0.10, 0.13, 0.86)
	background_style.corner_radius_top_left = 3
	background_style.corner_radius_top_right = 3
	background_style.corner_radius_bottom_left = 3
	background_style.corner_radius_bottom_right = 3
	var fill_style := background_style.duplicate() as StyleBoxFlat
	fill_style.bg_color = Color(color, 0.92)
	bar.add_theme_stylebox_override("background", background_style)
	bar.add_theme_stylebox_override("fill", fill_style)
	row.add_child(bar)
	return row


func _build_combat_action_deck(battle: Dictionary, forecasts: Dictionary,
		technique_forecasts: Array, intent_forecast: Dictionary, objective: Dictionary) -> Control:
	var deck := _panel(0.76, era_accent)
	deck.name = "CombatActionDeck"
	var style := deck.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	deck.add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	deck.add_child(stack)
	var primary_row := HBoxContainer.new()
	primary_row.name = "CombatPrimaryActions"
	primary_row.add_theme_constant_override("separation", 7)
	primary_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(primary_row)
	for technique_index in range(technique_forecasts.size()):
		var forecast_value: Variant = technique_forecasts[technique_index]
		if not forecast_value is Dictionary:
			continue
		var forecast: Dictionary = forecast_value
		primary_row.add_child(_combat_technique_card(forecast, technique_index, battle,
			objective, intent_forecast))

	var utility_row := HBoxContainer.new()
	utility_row.name = "CombatUtilityActions"
	utility_row.add_theme_constant_override("separation", 7)
	utility_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(utility_row)
	var pill: Dictionary = forecasts.get("pill", {})
	var pill_state := "气血已满" if int(pill.get("heal", 0)) <= 0 else \
		"恢复 %d · 余 %d枚" % [int(pill.get("heal", 0)), int(pill.get("count", 0))]
	var pill_button := _combat_utility_button("服丹", pill_state,
		str(pill.get("counter_role", "utility")), _resolve_combat_action.bind("pill"))
	pill_button.name = "CombatPillButton"
	var pill_available := int(pill.get("count", 0)) > 0 and int(pill.get("heal", 0)) > 0
	pill_button.set_meta("combat_available", pill_available)
	pill_button.disabled = combat_input_locked or not pill_available
	pill_button.tooltip_text = "行囊中没有疗伤丹。" if int(pill.get("count", 0)) <= 0 else \
		("气血已满，无需消耗疗伤丹。" if int(pill.get("heal", 0)) <= 0 else \
		"消耗1枚疗伤丹，恢复四成气血；已有破势节拍不会丢失。")
	utility_row.add_child(pill_button)
	var flee: Dictionary = forecasts.get("flee", {})
	var flee_button := _combat_utility_button("撤离战圈", "成功率 %d%% · 失败保拍" % int(flee.get("chance", 0)),
		str(flee.get("counter_role", "withdraw")), _resolve_combat_action.bind("flee"))
	flee_button.name = "CombatFleeButton"
	flee_button.set_meta("combat_available", true)
	flee_button.disabled = combat_input_locked
	flee_button.tooltip_text = "尝试退出战圈；拖得越久，成功率越低。\n%s" % \
		str(objective.get("escape_consequence", "未分胜负，这段敌意仍会留在山河里。"))
	utility_row.add_child(flee_button)
	return deck


func _combat_technique_card(forecast: Dictionary, technique_index: int, battle: Dictionary,
		objective: Dictionary, intent_forecast: Dictionary) -> Button:
	var technique_id := str(forecast.get("id", ""))
	var base_action := str(forecast.get("base_action", "spell"))
	var slot_id := str(forecast.get("slot", "turn"))
	var role := str(forecast.get("counter_role", "unsuitable"))
	var slot_title := str({
		"pressure": "压制", "guard": "守势", "turn": "转机",
	}.get(slot_id, "应变"))
	var timing_title := str({
		"action": "行招", "reaction": "应招", "follow_up": "回气",
	}.get(str(forecast.get("timing", "action")), "行招"))
	var title := str(forecast.get("name", "未名战技"))
	if bool(objective.get("ready", false)) and base_action in ["attack", "spell"] and \
			int(forecast.get("max_damage", 0)) > 0:
		title += " · 破势"
	var description := str(forecast.get("description", "")).strip_edges()
	var prediction := _combat_technique_prediction(forecast)
	var resource := _combat_technique_resource(forecast)
	var rhythm := _combat_rhythm_card_line(role, int(objective.get("progress", 0)),
		int(objective.get("target", 3)))
	var signature_note := _combat_action_signature_note(forecast)
	if not signature_note.is_empty():
		rhythm += " · " + signature_note
	var button := _button("", _resolve_combat_technique.bind(technique_id),
		role == "recommended", "", true)
	button.name = str({
		"pressure": "CombatPressureButton",
		"guard": "CombatGuardButton",
		"turn": "CombatTurnButton",
	}.get(slot_id, "CombatTechniqueButton%d" % technique_index))
	button.set_meta("technique_id", technique_id)
	button.set_meta("technique_slot", slot_id)
	button.custom_minimum_size = Vector2(0, 108)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	var role_color := _combat_role_color(role)
	button.add_theme_stylebox_override("normal", _button_style(0.18, role_color, 0.62, true))
	button.add_theme_stylebox_override("hover", _button_style(0.36, role_color, 0.98, true))
	button.add_theme_stylebox_override("focus", _button_style(0.36, role_color, 0.98, true))
	button.add_theme_stylebox_override("pressed", _button_style(0.50, role_color, 1.0, true))
	var technique_available := bool(forecast.get("available", true))
	button.set_meta("combat_available", technique_available)
	button.disabled = combat_input_locked or not technique_available
	if button.disabled:
		button.add_theme_stylebox_override("disabled", _button_style(0.10,
			Color("6f7478"), 0.28, true))

	var content := MarginContainer.new()
	content.name = "CombatTechniqueContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("margin_left", 12)
	content.add_theme_constant_override("margin_right", 12)
	content.add_theme_constant_override("margin_top", 8)
	content.add_theme_constant_override("margin_bottom", 8)
	button.add_child(content)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	content.add_child(column)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)
	var slot_label := _label("%d  %s · %s" % [technique_index + 1, slot_title, timing_title],
		11, Color(role_color, 0.98))
	slot_label.name = "CombatTechniqueSlotLabel"
	slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(slot_label)
	var cost_label := _label(resource, 11,
		Color("efc66e") if int(forecast.get("mp_cost", 0)) > 0 else Color(0.67, 0.74, 0.74),
		HORIZONTAL_ALIGNMENT_RIGHT)
	cost_label.name = "CombatTechniqueCostLabel"
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(cost_label)
	var name_label := _display_label(title, 17, Color("f3e3b9"))
	name_label.name = "CombatTechniqueNameLabel"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(name_label)
	var description_label := _label(description, 11, Color(0.70, 0.75, 0.74, 0.94))
	description_label.name = "CombatTechniqueDescriptionLabel"
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(description_label)
	var footer := HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_constant_override("separation", 8)
	column.add_child(footer)
	var effect_label := _label(prediction, 12, Color(0.84, 0.87, 0.84))
	effect_label.name = "CombatTechniqueEffectLabel"
	effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footer.add_child(effect_label)
	var rhythm_label := _label(rhythm, 11, Color(role_color, 0.96),
		HORIZONTAL_ALIGNMENT_RIGHT)
	rhythm_label.name = "CombatTechniqueRhythmLabel"
	rhythm_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rhythm_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footer.add_child(rhythm_label)
	if button.disabled:
		content.modulate = Color(0.68, 0.70, 0.70, 0.82)
	var blocked_reason := str(forecast.get("blocked_reason", "")).strip_edges()
	if button.disabled and blocked_reason.is_empty():
		blocked_reason = "当前不可施展"
	var tooltip_lines: Array[String] = []
	if button.disabled:
		tooltip_lines.append("当前不可施展：%s" % blocked_reason)
	if not description.is_empty():
		tooltip_lines.append(description)
	tooltip_lines.append(_combat_rhythm_detail(base_action, role, intent_forecast))
	button.tooltip_text = "\n".join(tooltip_lines)
	return button


func _combat_technique_prediction(forecast: Dictionary) -> String:
	var effects: Array[String] = []
	if int(forecast.get("max_damage", 0)) > 0:
		effects.append("伤害 %d–%d" % [int(forecast.get("min_damage", 0)),
			int(forecast.get("max_damage", 0))])
	if int(forecast.get("shield", 0)) > 0:
		effects.append("护盾 +%d" % int(forecast.get("shield", 0)))
	if int(forecast.get("heal", 0)) > 0:
		effects.append("气血 +%d" % int(forecast.get("heal", 0)))
	if int(forecast.get("mp_gain", 0)) > 0:
		effects.append("灵力 +%d" % int(forecast.get("mp_gain", 0)))
	var status_value: Variant = (forecast.get("effects", {}) as Dictionary).get("status", {})
	if status_value is Dictionary and not (status_value as Dictionary).is_empty():
		var status: Dictionary = status_value
		var status_name := str({
			"bleed": "流血", "weak": "虚弱", "shield": "护体",
		}.get(str(status.get("id", "")), "状态"))
		effects.append("%s %d回合" % [status_name, int(status.get("duration", 1))])
	return " · ".join(effects) if not effects.is_empty() else "调息换势"


func _combat_technique_resource(forecast: Dictionary) -> String:
	var cost := int(forecast.get("mp_cost", forecast.get("cost", 0)))
	return "灵力 %d" % cost if cost > 0 else "无消耗"


func _combat_action_card(action_id: String, forecast: Dictionary, battle: Dictionary,
		objective: Dictionary, intent_forecast: Dictionary) -> Button:
	var role := str(forecast.get("counter_role", "unsuitable"))
	var title := CombatSystemScript.action_name(action_id)
	var prediction := _combat_action_prediction(action_id, forecast)
	var resource := _combat_action_resource(action_id, forecast)
	var rhythm := _combat_rhythm_card_line(role, int(objective.get("progress", 0)),
		int(objective.get("target", 3)))
	var signature_note := _combat_action_signature_note(forecast)
	if not signature_note.is_empty():
		rhythm += " · " + signature_note
	if bool(objective.get("ready", false)) and action_id in ["attack", "spell"]:
		title += " · 破势"
	var button := _button("%s\n%s · %s\n%s" % [title, prediction, resource, rhythm],
		_resolve_combat_action.bind(action_id), role == "recommended", "", true)
	button.custom_minimum_size = Vector2(0, 96)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 14)
	var role_color := _combat_role_color(role)
	button.add_theme_stylebox_override("normal", _button_style(0.20, role_color, 0.62, true))
	button.add_theme_stylebox_override("hover", _button_style(0.38, role_color, 0.96, true))
	button.add_theme_stylebox_override("focus", _button_style(0.38, role_color, 0.96, true))
	button.add_theme_stylebox_override("pressed", _button_style(0.52, role_color, 1.0, true))
	var available := bool(forecast.get("available", true))
	var mp_cost := int(forecast.get("mp_cost", 0))
	button.disabled = not available or (action_id == "spell" and int(battle.get("player_mp", 0)) < mp_cost)
	if button.disabled:
		button.add_theme_color_override("font_disabled_color", Color(0.64, 0.67, 0.67, 0.90))
		button.add_theme_stylebox_override("disabled", _button_style(0.10, Color("6f7478"), 0.28, true))
	var blocked_reason := str(forecast.get("blocked_reason", "")).strip_edges()
	if button.disabled and blocked_reason.is_empty():
		blocked_reason = "灵力不足"
	button.tooltip_text = ("当前不可施展：%s\n" % blocked_reason if button.disabled else "") + \
		_combat_rhythm_detail(action_id, role, intent_forecast)
	return button


func _combat_utility_button(title: String, detail: String, role: String,
		callback: Callable) -> Button:
	var button := _button("%s · %s" % [title, detail], callback, false, "", true)
	button.custom_minimum_size = Vector2(0, 40)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 13)
	var role_color := _combat_role_color(role)
	button.add_theme_stylebox_override("normal", _button_style(0.15, role_color, 0.40, true))
	button.add_theme_stylebox_override("hover", _button_style(0.30, role_color, 0.84, true))
	button.add_theme_stylebox_override("focus", _button_style(0.30, role_color, 0.84, true))
	return button


func _combat_action_prediction(action_id: String, forecast: Dictionary) -> String:
	if action_id == "guard":
		return "护盾 +%d–%d" % [int(forecast.get("min_shield", 0)), int(forecast.get("max_shield", 0))]
	return "伤害 %d–%d" % [int(forecast.get("min_damage", 0)), int(forecast.get("max_damage", 0))]


func _combat_action_resource(action_id: String, forecast: Dictionary) -> String:
	var costs: Array[String] = []
	var mp_cost := int(forecast.get("mp_cost", 0))
	var extra_mp_cost := int(forecast.get("extra_mp_cost", 0))
	if mp_cost > 0:
		costs.append("灵力 %d" % mp_cost)
	elif extra_mp_cost > 0:
		costs.append("灵力税 %d" % extra_mp_cost)
	var hp_cost := int(forecast.get("signature_hp_cost", 0))
	if hp_cost > 0:
		costs.append("触律失血 %d" % hp_cost)
	if not bool(forecast.get("available", true)):
		costs.append(str(forecast.get("blocked_reason", "当前封禁")))
	return " · ".join(costs) if not costs.is_empty() else "无消耗"


func _combat_rhythm_card_line(role: String, progress: int, target: int) -> String:
	return str({
		"recommended": "进势 · 破绽 %d/%d" % [mini(target, progress + 1), target],
		"alternative": "保拍 · 维持 %d/%d" % [progress, target],
		"utility": "保拍 · 维持 %d/%d" % [progress, target],
		"withdraw": "离场 · 失败保拍",
		"unsuitable": "断势 · 连势归零",
	}.get(role, "断势 · 连势归零"))


func _combat_action_signature_note(forecast: Dictionary) -> String:
	var notes: Array[String] = []
	var power := int(forecast.get("signature_power_percent", 100))
	if power < 100:
		notes.append("威力 %d%%" % power)
	if int(forecast.get("enemy_shield_gain", 0)) > 0:
		notes.append("敌盾 +%d" % int(forecast.enemy_shield_gain))
	var heat := int(forecast.get("heat_delta", 0))
	if heat != 0:
		notes.append("炉压 %+d" % heat)
	if int(forecast.get("bleed_clear", 0)) > 0:
		notes.append("流血 -%d" % int(forecast.bleed_clear))
	if int(forecast.get("silence_clear", 0)) > 0:
		notes.append("寂印 -%d" % int(forecast.silence_clear))
	return " · ".join(notes)


func _combat_role_color(role: String) -> Color:
	return {
		"recommended": Color("d7b85a"),
		"alternative": Color("62aebc"),
		"utility": Color("78959a"),
		"withdraw": Color("8c8176"),
		"unsuitable": Color("aa625e"),
	}.get(role, era_accent)


func _combat_rhythm_detail(action_id: String, role: String, forecast: Dictionary) -> String:
	if role == "recommended":
		return "节拍：推进破势一拍。%s" % str(forecast.get("recommended_text", ""))
	if role == "alternative":
		return "节拍：保住当前进度，但不推进。%s" % str(forecast.get("alternative_text", ""))
	if role == "utility":
		return "节拍：%s不会推进，也不会打断当前进度。" % CombatSystemScript.action_name(action_id)
	if role == "withdraw":
		return "节拍：脱战失败时保留当前进度；成功则结束交锋。"
	return "节拍：这一手与当前敌意失配，会打断已经积累的进度。"


func _build_combat_tactics_panel(battle: Dictionary, forecast: Dictionary,
		objective: Dictionary, compact: bool = false) -> Control:
	var panel := _panel(0.80, _combat_threat_color(str(forecast.get("threat", "常规"))))
	panel.name = "CombatTacticsPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = 10
	style.content_margin_bottom = 9
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)

	var signature := VBoxContainer.new()
	signature.name = "CombatSignaturePanel"
	signature.add_theme_constant_override("separation", 2)
	column.add_child(signature)
	var signature_header := HBoxContainer.new()
	var signature_title := _label(str(objective.get("signature_title", "临阵换势")), 17,
		Color("ef9a78"))
	signature_title.name = "CombatSignatureTitle"
	signature_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	signature_header.add_child(signature_title)
	var phase_active := bool(battle.get("second_phase_active", false))
	var phase_pending := bool(battle.get("phase_shift_pending", false))
	var phase_text := "第二阶段" if phase_active else "换势将至" if phase_pending else "第一阶段"
	var phase_label := _label(phase_text, 12,
		Color("ef7867") if phase_active else Color(0.72, 0.77, 0.76), HORIZONTAL_ALIGNMENT_RIGHT)
	phase_label.name = "CombatPhaseState"
	signature_header.add_child(phase_label)
	signature.add_child(signature_header)
	var signature_status := _label(str(objective.get("signature_status", "敌势尚未显出变化。")),
		12, Color(era_accent, 0.92))
	signature_status.name = "CombatSignatureStatus"
	signature_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	signature.add_child(signature_status)
	var rule := _label(str(objective.get("signature_rule", "敌人会在半血后改变招路。")), 12,
		Color(0.79, 0.82, 0.80))
	rule.name = "CombatSignatureRule"
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.max_lines_visible = 2
	signature.add_child(rule)
	if phase_active or phase_pending:
		var phase_rule := _label("换势 · %s" % str(objective.get("signature_phase_rule", "后半程招路已经改变。")),
			12, Color("e88972"))
		phase_rule.name = "CombatSignaturePhaseRule"
		phase_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		phase_rule.max_lines_visible = 2
		signature.add_child(phase_rule)
	column.add_child(_divider())

	var forecast_card := VBoxContainer.new()
	forecast_card.name = "CombatForecastCard"
	forecast_card.add_theme_constant_override("separation", 2)
	column.add_child(forecast_card)
	var forecast_row := HBoxContainer.new()
	forecast_row.add_theme_constant_override("separation", 10)
	forecast_card.add_child(forecast_row)
	var intent_name := _label("敌意 · %s" % CombatSystemScript.intent_label(battle), 18, Color("f0b08b"))
	intent_name.name = "CombatIntentName"
	intent_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forecast_row.add_child(intent_name)
	var threat_color := _combat_threat_color(str(forecast.get("threat", "常规")))
	var range_label := _label("%s · %s" % [str(forecast.get("threat", "常规")),
		_combat_forecast_range_text(forecast)], 14, threat_color, HORIZONTAL_ALIGNMENT_RIGHT)
	range_label.name = "CombatForecastRange"
	forecast_row.add_child(range_label)
	var counterplay := _label("应对线索 · %s" % str(forecast.get("counter",
		"先看清敌意，再决定这一回合。")), 12, Color(0.78, 0.82, 0.81))
	counterplay.name = "CombatCounterplay"
	counterplay.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	counterplay.max_lines_visible = 2
	forecast_card.add_child(counterplay)
	var intent_effect := _combat_intent_signature_effect(forecast)
	if not intent_effect.is_empty():
		var effect_label := _label(intent_effect, 12, Color("d99aba"))
		effect_label.name = "CombatIntentSignatureEffect"
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		forecast_card.add_child(effect_label)
	forecast_card.add_child(_build_combat_intent_timeline(battle))
	column.add_child(_divider())
	column.add_child(_build_combat_objective_card(objective))

	var recent_lines := _combat_event_lines(battle, true)
	if not compact and not recent_lines.is_empty():
		var latest := _label("上一拍\n%s" % "\n".join(recent_lines), 11,
			Color(0.65, 0.70, 0.70))
		latest.name = "CombatLogPreview"
		latest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		latest.max_lines_visible = 4
		column.add_child(latest)
	return panel


func _combat_intent_signature_effect(forecast: Dictionary) -> String:
	if int(forecast.get("mp_loss", 0)) > 0:
		var mp_loss := int(forecast.mp_loss)
		return "签名生效 · 抽走%d点灵力%s" % [mp_loss,
			"，并化作等量敌盾" if bool(forecast.get("shield_gain_equals_mp_loss", false)) else ""]
	if int(forecast.get("shield_plunder_max", 0)) > 0:
		return "签名生效 · 至多夺走%d点护盾" % int(forecast.shield_plunder_max)
	if int(forecast.get("overheat_multiplier_percent", 0)) > 0:
		return "签名生效 · 过热攻势为%d%%" % int(forecast.overheat_multiplier_percent)
	if int(forecast.get("blood_scent_multiplier_percent", 0)) > 0:
		return "签名生效 · 闻血追击为%d%%" % int(forecast.blood_scent_multiplier_percent)
	if int(forecast.get("shield_pierce_percent", 0)) > 0:
		return "签名生效 · 穿透%d%%现有护盾" % int(forecast.shield_pierce_percent)
	if not str(forecast.get("next_edict_action", "")).is_empty():
		return "当前禁令 · 不可使%s" % CombatSystemScript.action_name(str(forecast.next_edict_action))
	return ""


func _open_combat_log_overlay() -> void:
	if not CombatSystemScript.has_active_combat(run_state) or \
		is_instance_valid(screen_host.find_child("CombatLogOverlay", true, false)):
		return
	var battle: Dictionary = run_state.combat.current
	var overlay := Control.new()
	overlay.name = "CombatLogOverlay"
	overlay.z_index = 180
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_host.add_child(overlay)
	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.005, 0.01, 0.018, 0.86)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(scrim)
	var dialog := _panel(0.98, era_accent)
	dialog.name = "CombatLogDialog"
	dialog.anchor_left = 0.12
	dialog.anchor_top = 0.10
	dialog.anchor_right = 0.88
	dialog.anchor_bottom = 0.90
	dialog.offset_left = 0
	dialog.offset_top = 0
	dialog.offset_right = 0
	dialog.offset_bottom = 0
	overlay.add_child(dialog)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	dialog.add_child(stack)
	var title_row := HBoxContainer.new()
	var title := _display_label("交锋实录", 24, Color("f3dfb3"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close_button := _button("收起", _close_combat_log_overlay, false, "", true)
	close_button.name = "CombatLogCloseButton"
	close_button.custom_minimum_size = Vector2(82, 40)
	title_row.add_child(close_button)
	stack.add_child(title_row)
	stack.add_child(_label("%s · 第%d回合 · %s" % [str(battle.get("enemy_name", "来敌")),
		int(battle.get("turn", 1)), str(battle.get("signature_title", "临阵换势"))], 13,
		Color(era_accent, 0.88)))
	stack.add_child(_divider())
	var scroll := ScrollContainer.new()
	scroll.name = "CombatLogScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	var log_lines := _combat_event_lines(battle, false)
	if log_lines.is_empty():
		log_lines.append("· 双方尚未出手。")
	var log_label := _label("\n\n".join(log_lines), 15, Color("e8e4da"))
	log_label.name = "CombatLogLabel"
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(log_label)


func _close_combat_log_overlay() -> void:
	var overlay := screen_host.find_child("CombatLogOverlay", true, false)
	if is_instance_valid(overlay):
		overlay.queue_free()


func _combat_event_lines(battle: Dictionary, latest_only: bool) -> Array[String]:
	var lines: Array[String] = []
	var history_value: Variant = battle.get("event_history", [])
	var history: Array = history_value if history_value is Array else []
	if not history.is_empty():
		var first_index := history.size() - 1 if latest_only else 0
		for event_index in range(first_index, history.size()):
			var event_value: Variant = history[event_index]
			if not event_value is Dictionary:
				continue
			var combat_event: Dictionary = event_value
			if not latest_only:
				lines.append("第%d回合 · %s" % [int(combat_event.get("turn", event_index + 1)),
					_combat_event_action_name(combat_event)])
			var steps_value: Variant = combat_event.get("steps", [])
			var steps: Array = steps_value if steps_value is Array else []
			for step_value in steps:
				if not step_value is Dictionary:
					continue
				var step: Dictionary = step_value
				var kind := str(step.get("kind", "note"))
				var cue := str(step.get("cue", ""))
				var meaningful := kind in ["damage", "shield", "heal", "resource", "status",
					"signature", "counter", "phase_shift", "outcome"]
				meaningful = meaningful or (kind == "intent" and cue == "combat_next_intent")
				meaningful = meaningful or (kind == "action" and cue in ["combat_flee", "combat_flee_blocked"])
				var step_text := str(step.get("text", "")).strip_edges()
				if not meaningful or step_text.is_empty():
					continue
				var actor_label := str({"player": "我方", "enemy": "敌方", "system": "战局"}.get(
					str(step.get("actor", "system")), "战局"))
				lines.append("· %s · %s" % [actor_label, step_text])
		if latest_only and lines.size() > 3:
			var recent: Array[String] = []
			for line_index in range(lines.size() - 3, lines.size()):
				recent.append(lines[line_index])
			return recent
	if not lines.is_empty():
		return lines
	# Legacy active battles may predate structured traces. They remain readable
	# until the next resolved turn creates an event_history entry.
	var legacy_value: Variant = battle.get("log", [])
	var legacy: Array = legacy_value if legacy_value is Array else []
	var legacy_start := maxi(0, legacy.size() - (3 if latest_only else legacy.size()))
	for log_index in range(legacy_start, legacy.size()):
		lines.append("· %s" % str(legacy[log_index]))
	return lines


func _combat_event_action_name(combat_event: Dictionary) -> String:
	var action_id := str(combat_event.get("action_id", "attack"))
	for technique_value in CombatSystemScript.technique_slots(run_state):
		if not technique_value is Dictionary:
			continue
		var technique: Dictionary = technique_value
		if str(technique.get("id", "")) == action_id:
			return str(technique.get("name", "战技"))
	return CombatSystemScript.action_name(action_id)


func _build_combat_objective_card(objective: Dictionary) -> Control:
	var ready := bool(objective.get("ready", false))
	var card := VBoxContainer.new()
	card.name = "CombatObjectiveCard"
	card.add_theme_constant_override("separation", 3)
	var row := HBoxContainer.new()
	card.add_child(row)
	var progress := _label("%s · %d/%d" % [str(objective.get("title", "三拍破势")),
		int(objective.progress), int(objective.target)], 15,
		Color("f2d28a") if ready else Color(era_accent, 0.96))
	progress.name = "CombatCounterProgress"
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(progress)
	var state_label := _label("破势已成" if ready else "连势推进", 12,
		Color("efc76f") if ready else Color(0.69, 0.77, 0.77), HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(state_label)
	var progress_bar := ProgressBar.new()
	progress_bar.name = "CombatCounterBar"
	progress_bar.max_value = max(1, int(objective.get("target", 3)))
	progress_bar.value = int(objective.get("progress", 0))
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size.y = 6
	var bar_background := StyleBoxFlat.new()
	bar_background.bg_color = Color(0.09, 0.11, 0.14, 0.86)
	var bar_fill := bar_background.duplicate() as StyleBoxFlat
	bar_fill.bg_color = Color("e0b95e") if ready else Color(era_accent, 0.80)
	progress_bar.add_theme_stylebox_override("background", bar_background)
	progress_bar.add_theme_stylebox_override("fill", bar_fill)
	card.add_child(progress_bar)
	var status_label := _label(str(objective.get("status", "看清三手，等破绽自己露出来。")), 12,
		Color(0.75, 0.80, 0.79, 0.94))
	status_label.name = "CombatCounterStatus"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.max_lines_visible = 2
	card.add_child(status_label)
	return card


func _build_combat_intent_timeline(battle: Dictionary) -> HBoxContainer:
	var timeline := HBoxContainer.new()
	timeline.name = "CombatIntentTimeline"
	timeline.add_theme_constant_override("separation", 8)
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cycle: Array = battle.get("intent_cycle", ["strike"])
	var current_index := int(battle.get("intent_index", 0))
	var prefixes := ["当前", "下一", "随后"]
	for offset in range(mini(3, cycle.size())):
		var intent_id := str(cycle[(current_index + offset) % cycle.size()])
		var intent_panel := _panel(0.28 if offset == 0 else 0.18,
			Color("ef8a68") if offset == 0 else era_accent)
		intent_panel.name = "CombatIntentStep%d" % offset
		intent_panel.custom_minimum_size.y = 32
		intent_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var intent_style := intent_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		intent_style.content_margin_left = 5
		intent_style.content_margin_right = 5
		intent_style.content_margin_top = 3
		intent_style.content_margin_bottom = 3
		intent_style.shadow_size = 0
		intent_style.corner_radius_top_left = 4
		intent_style.corner_radius_top_right = 4
		intent_style.corner_radius_bottom_left = 4
		intent_style.corner_radius_bottom_right = 4
		intent_panel.add_theme_stylebox_override("panel", intent_style)
		intent_panel.add_child(_label("%s · %s" % [prefixes[offset],
			CombatSystemScript.intent_name(intent_id)], 11,
			Color("f1d4b7") if offset == 0 else Color(0.74, 0.78, 0.78, 0.86),
			HORIZONTAL_ALIGNMENT_CENTER))
		timeline.add_child(intent_panel)
	return timeline


func _combat_forecast_range_text(forecast: Dictionary) -> String:
	if str(forecast.get("kind", "damage")) == "guard":
		return "预计护盾 +%d–%d" % [int(forecast.get("min_shield", 0)),
			int(forecast.get("max_shield", 0))]
	return "预计伤害 %d–%d" % [int(forecast.get("min_damage", 0)),
		int(forecast.get("max_damage", 0))]


func _combat_threat_color(threat: String) -> Color:
	return {
		"致命": Color("ff625f"),
		"高危": Color("ef7a62"),
		"持续": Color("dc7c9c"),
		"压制": Color("b68ddd"),
		"蓄势": Color("74b9d8"),
	}.get(threat, Color("d9bd76"))


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
	if combat_input_locked:
		return
	_resolve_combat_result(action, CombatSystemScript.perform_action(run_state, action))


func _resolve_combat_technique(technique_id: String) -> void:
	if combat_input_locked:
		return
	_resolve_combat_result(technique_id,
		CombatSystemScript.perform_technique(run_state, technique_id))


func _resolve_combat_technique_slot(slot_index: int) -> void:
	if combat_input_locked:
		return
	var slots: Array = CombatSystemScript.technique_slots(run_state)
	if slot_index < 0 or slot_index >= slots.size() or not slots[slot_index] is Dictionary:
		feedback = "这一式尚未纳入当前战技构筑。"
		_show_combat()
		return
	_resolve_combat_technique(str((slots[slot_index] as Dictionary).get("id", "")))


func _resolve_combat_result(action: String, result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		feedback = str({
			"insufficient_mp": "灵力不足，术式未能成形。",
			"no_healing_pill": "行囊中已无疗伤丹。",
			"hp_full": "气血已满，旧玉阻止你浪费疗伤丹。",
			"technique_not_in_loadout": "这一式不在当前构筑中。",
			"signature_action_blocked": str(result.get("message", "敌方规则封住了这一式。")),
		}.get(str(result.get("code", "")), "这一行动未能落入战局。"))
		_show_combat()
		return
	_play_combat_action_audio(action, result)
	_sync_state_views()
	if str(result.get("code", "")) != "combat_finished":
		var feedback_duration := 0.72 if bool(result.get("second_phase_triggered", false)) or \
			bool(result.get("second_phase_shifted", false)) else 0.38
		_begin_combat_feedback_lock(feedback_duration)
		_save_current_state("战斗回合已自动封存")
		_show_combat()
		return
	_release_combat_feedback_lock()
	var outcome := str(result.get("outcome", "escaped"))
	var battle: Dictionary = result.get("battle", {})
	var story_consequence := str(result.get("story_consequence", "")).strip_edges()
	if outcome == "victory":
		var rewards: Dictionary = result.get("rewards", {})
		AchievementSystemScript.add_resonance(run_state, 6, "正面胜战")
		CultivationScript.advance_time(run_state, 1)
		_sync_state_views()
		feedback = "你击败%s，修为 +%d、灵石 +%d，并取得一份战利材料。" % [
			str(battle.get("enemy_name", "强敌")), int(rewards.get("exp", 0)),
			int(rewards.get("spirit_stones", 0))]
		if not story_consequence.is_empty():
			feedback += "\n\n" + story_consequence
		_add_memory("第%d年，你看穿%s的意图并在正面交锋中取胜。" % [
			int((run_state.world as Dictionary).get("year", 1)), str(battle.get("enemy_name", "强敌"))])
		if not story_consequence.is_empty():
			_add_memory(story_consequence)
		var objective_result := _record_objective_action("combat_victory")
		_sync_state_views()
		_append_objective_feedback(objective_result)
		if CultivationScript.is_dead(run_state):
			_end_current_life("胜战后寿元耗尽")
			return
		_save_current_state("胜战与年史已自动封存")
		_show_game()
		return
	if outcome == "defeat":
		feedback = "你败于%s，此世气血归零。" % str(battle.get("enemy_name", "强敌"))
		if not story_consequence.is_empty():
			feedback += "\n\n" + story_consequence
		_end_current_life("战败身陨：%s%s" % [str(battle.get("enemy_name", "强敌")),
			"；%s" % story_consequence if not story_consequence.is_empty() else ""])
		return
	feedback = "你脱离了与%s的战圈，未分胜负。" % str(battle.get("enemy_name", "强敌"))
	if not story_consequence.is_empty():
		feedback += "\n\n" + story_consequence
		_add_memory(story_consequence)
	_save_current_state("脱战结果已自动封存")
	_show_game()


func _begin_combat_feedback_lock(duration_seconds: float) -> void:
	combat_feedback_sequence += 1
	var sequence := combat_feedback_sequence
	combat_input_locked = true
	get_tree().create_timer(maxf(0.12, duration_seconds)).timeout.connect(func() -> void:
		if sequence != combat_feedback_sequence:
			return
		combat_input_locked = false
		_apply_combat_input_lock()
	)


func _release_combat_feedback_lock() -> void:
	combat_feedback_sequence += 1
	combat_input_locked = false
	_apply_combat_input_lock()


func _apply_combat_input_lock() -> void:
	if not is_instance_valid(screen_host):
		return
	for button_value in screen_host.find_children("Combat*Button", "Button", true, false):
		if not button_value is Button:
			continue
		var button := button_value as Button
		if button.has_meta("combat_available"):
			button.disabled = combat_input_locked or not bool(button.get_meta("combat_available"))


func _enter_dungeon() -> void:
	if bool(run_state.get("life_closed", false)) or CultivationScript.is_dead(run_state):
		_end_current_life(_current_death_cause())
		return
	var result: Dictionary = DungeonSystemScript.start(run_state, "mirror_lake")
	if not bool(result.get("ok", false)):
		feedback = str(result.get("message", "镜湖空阙没有形成稳定入口。"))
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
	_set_audio_context("dungeon")
	_clear_screen()
	var run: Dictionary = run_state.dungeon.run
	_apply_era_visuals(_dungeon_scene_path(str(run.dungeon_id)))
	_apply_dungeon_stress_visuals(int(run.stress))
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 14)
	screen_host.add_child(page)
	var narrow_layout := get_viewport_rect().size.x < 1040.0
	page.resized.connect(func() -> void:
		if state == ScreenState.DUNGEON_ROUTE and \
				(get_viewport_rect().size.x < 1040.0) != narrow_layout:
			call_deferred("_refresh_screen_layout", ScreenState.DUNGEON_ROUTE)
	)
	page.add_child(_build_dungeon_header(run, "秘境岔路", narrow_layout))
	var content_host: Container = page
	if narrow_layout:
		var content_scroll := ScrollContainer.new()
		content_scroll.name = "DungeonRouteScroll"
		content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		content_scroll.follow_focus = true
		content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var content := VBoxContainer.new()
		content.name = "DungeonRouteContent"
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", 14)
		content_scroll.add_child(content)
		page.add_child(content_scroll)
		content_host = content

	var status := HBoxContainer.new()
	status.name = "DungeonRouteStatus"
	status.add_theme_constant_override("separation", 14)
	content_host.add_child(status)
	var stress_color := _dungeon_stress_color(int(run.stress))
	var vitality := _dungeon_surface(stress_color if int(run.stress) >= 60 else era_accent)
	vitality.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vitality_column := VBoxContainer.new()
	vitality_column.add_theme_constant_override("separation", 7)
	vitality.add_child(vitality_column)
	vitality_column.add_child(_progress_row("秘境气血", int(run.hp), int(run.max_hp), Color("c95858")))
	vitality_column.add_child(_progress_row("心魔压力", int(run.stress), 100, stress_color))
	var route_stress_label := _label(_dungeon_stress_status(run), 14, Color(stress_color, 0.94))
	route_stress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vitality_column.add_child(route_stress_label)
	status.add_child(vitality)
	var depth_panel := _dungeon_surface(era_accent)
	depth_panel.custom_minimum_size.x = 260 if narrow_layout else 310
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

	var body: BoxContainer = VBoxContainer.new() if narrow_layout else HBoxContainer.new()
	body.name = "DungeonRouteBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	content_host.add_child(body)
	body.add_child(_build_dungeon_route_journal(run, not narrow_layout))
	var route_panel := _dungeon_surface(Color("6b9ba8"), true)
	route_panel.name = "DungeonRouteChoicePanel"
	route_panel.custom_minimum_size.x = 0 if narrow_layout else 420
	if narrow_layout:
		route_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var route_column := VBoxContainer.new()
	route_column.add_theme_constant_override("separation", 12)
	route_panel.add_child(route_column)
	route_column.add_child(_section_title("选择下一处道标"))
	var routes: Array = run.route_choices
	for index in range(routes.size()):
		var node: Dictionary = routes[index]
		var route_button := _button("%d · %s\n%s\n%s" % [index + 1,
			_dungeon_route_action(node), str(node.get("description", "前路因果未明。")),
			_dungeon_route_preview(node)],
			_choose_dungeon_route.bind(index), index == 0)
		route_button.name = "DungeonRouteButton%d" % index
		route_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		route_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		route_button.custom_minimum_size.y = 112
		var node_color := _dungeon_route_type_color(str(node.get("type", "memory")))
		route_button.add_theme_stylebox_override("normal", _button_style(0.17, node_color, 0.44))
		route_button.add_theme_stylebox_override("hover", _button_style(0.33, node_color, 0.88))
		route_button.add_theme_stylebox_override("focus", _button_style(0.33, node_color, 0.88))
		route_column.add_child(route_button)
	route_column.add_child(_spacer(6))
	var abandon_button := _button("撤出秘境", _abandon_dungeon, false)
	abandon_button.name = "DungeonAbandonButton"
	route_column.add_child(abandon_button)
	body.add_child(route_panel)
	var feedback_slot := MarginContainer.new()
	feedback_slot.name = "DungeonFeedbackSlot"
	feedback_slot.custom_minimum_size.y = 54
	feedback_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(feedback_slot)
	var footer := _label("数字键选择道标 · Esc 撤离", 14, Color(0.76, 0.80, 0.81, 0.82),
		HORIZONTAL_ALIGNMENT_CENTER)
	footer.name = "DungeonRouteFooter"
	page.add_child(footer)
	_show_dungeon_action_feedback()


func _show_dungeon_combat() -> void:
	state = ScreenState.DUNGEON_COMBAT
	_clear_screen()
	var run: Dictionary = run_state.dungeon.run
	var battle: Dictionary = run.battle
	_set_audio_context("boss" if str(battle.get("rank", "combat")) == "boss" else "dungeon")
	_apply_era_visuals(_dungeon_scene_path(str(run.dungeon_id)))
	_apply_dungeon_stress_visuals(int(run.stress))
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 12)
	screen_host.add_child(page)
	var viewport_size := get_viewport_rect().size
	var narrow_layout := viewport_size.x < 1040.0 or viewport_size.y < 820.0
	page.resized.connect(func() -> void:
		if state == ScreenState.DUNGEON_COMBAT and \
				(get_viewport_rect().size.x < 1040.0 or
				get_viewport_rect().size.y < 820.0) != narrow_layout:
			call_deferred("_refresh_screen_layout", ScreenState.DUNGEON_COMBAT)
	)
	page.add_child(_build_dungeon_header(run, "能力交锋 · 第%d回合" % int(battle.turn),
		narrow_layout))
	var content_host: Container = page
	if narrow_layout:
		var content_scroll := ScrollContainer.new()
		content_scroll.name = "DungeonCombatScroll"
		content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		content_scroll.follow_focus = true
		content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var content := VBoxContainer.new()
		content.name = "DungeonCombatBody"
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", 12)
		content_scroll.add_child(content)
		page.add_child(content_scroll)
		content_host = content

	var combat_row := HBoxContainer.new()
	combat_row.name = "DungeonCombatStatusRow"
	combat_row.custom_minimum_size.y = 0 if narrow_layout else 332
	combat_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combat_row.add_theme_constant_override("separation", 14)
	content_host.add_child(combat_row)
	var stress_color := _dungeon_stress_color(int(run.stress))
	var self_panel := _dungeon_surface(stress_color if int(run.stress) >= 60 else Color("6696a6"))
	self_panel.name = "DungeonSelfPanel"
	self_panel.custom_minimum_size.x = 0 if narrow_layout else 260
	if narrow_layout:
		self_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var self_column := VBoxContainer.new()
	self_column.add_theme_constant_override("separation", 8)
	self_panel.add_child(self_column)
	self_column.add_child(_section_title(str(player.name)))
	self_column.add_child(_progress_row("秘境气血", int(run.hp), int(run.max_hp), Color("c95858")))
	self_column.add_child(_progress_row("心魔压力", int(run.stress), 100, stress_color))
	var combat_stress_label := _label(_dungeon_stress_status(run), 15, Color(stress_color, 0.98))
	combat_stress_label.name = "DungeonStressStatus"
	combat_stress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	self_column.add_child(combat_stress_label)
	self_column.add_child(_label("灵力 %d · 回合基础 %d · 护体 %d" % [int(battle.energy),
		DungeonSystemScript.energy_cap(battle), int(battle.player_block)], 15, Color("b9d5e8")))
	self_column.add_child(_label("器诀 +%d · 护诀 +%d" % [int(run.get("attack_power", 0)),
		int(run.get("guard_power", 0))], 14, Color(era_accent, 0.88)))
	var log_panel := _build_dungeon_log(run, battle, narrow_layout)
	var enemy_panel := _dungeon_surface(Color("d46b61"), str(battle.get("rank", "combat")) == "boss")
	enemy_panel.name = "DungeonEnemyPanel"
	enemy_panel.custom_minimum_size.x = 0 if narrow_layout else 330
	if narrow_layout:
		enemy_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var enemy_column := VBoxContainer.new()
	enemy_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_column.add_theme_constant_override("separation", 8)
	if narrow_layout:
		# Keep one outer dungeon scroll on narrow screens. The clipped viewport
		# prevents long boss rules from pushing cards and feedback off-screen.
		var enemy_viewport := Control.new()
		enemy_viewport.name = "DungeonEnemyViewport"
		enemy_viewport.clip_contents = true
		enemy_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		enemy_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
		enemy_panel.add_child(enemy_viewport)
		enemy_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		enemy_viewport.add_child(enemy_column)
	else:
		var enemy_scroll := ScrollContainer.new()
		enemy_scroll.name = "DungeonEnemyScroll"
		enemy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		enemy_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		enemy_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		enemy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		enemy_scroll.follow_focus = true
		enemy_panel.add_child(enemy_scroll)
		enemy_scroll.add_child(enemy_column)
	enemy_column.add_child(_section_title(str(battle.enemy_name)))
	enemy_column.add_child(_progress_row("气血", int(battle.enemy_hp), int(battle.enemy_max_hp), Color("d35f58")))
	enemy_column.add_child(_label("护体 %d · 虚弱 %d回合" % [int(battle.enemy_block), int(battle.enemy_weak)],
		14, Color(0.78, 0.81, 0.81)))
	var intent_preview := DungeonSystemScript.intent_preview(battle)
	enemy_column.add_child(_label("下一意图", 12, Color(0.68, 0.72, 0.73)))
	var intent_name := _display_label("%s  %d %s" % [str(intent_preview.title),
		int(intent_preview.value), str(intent_preview.unit)], 21,
		Color("ef9a78"), HORIZONTAL_ALIGNMENT_CENTER)
	intent_name.name = "DungeonIntentName"
	enemy_column.add_child(intent_name)
	var intent_detail := _label(str(intent_preview.detail), 13, Color(0.83, 0.80, 0.75))
	intent_detail.name = "DungeonIntentDetail"
	intent_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enemy_column.add_child(intent_detail)
	var rule_value: Variant = battle.get("trait", {})
	if rule_value is Dictionary and not (rule_value as Dictionary).is_empty():
		var rule: Dictionary = rule_value
		enemy_column.add_child(_divider())
		enemy_column.add_child(_label("%s · %s" % [DungeonSystemScript.combat_rule_title(battle),
			str(rule.get("name", "未知法则"))], 15,
			Color("efbd72"), HORIZONTAL_ALIGNMENT_CENTER))
		var trait_description := _label(str(rule.get("description", "")), 15, Color(0.90, 0.86, 0.79))
		trait_description.name = "DungeonTraitDescription"
		trait_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		enemy_column.add_child(trait_description)
	var phase_value: Variant = battle.get("phase", {})
	if phase_value is Dictionary and not (phase_value as Dictionary).is_empty():
		var phase: Dictionary = phase_value
		var phase_active := bool(battle.get("phase_active", false))
		enemy_column.add_child(_divider())
		enemy_column.add_child(_label("%s · %s" % ["第二相已显" if phase_active else "未显之相",
			str(phase.get("name", "未知形态"))], 15,
			Color("f08b72") if phase_active else Color("b9a780"), HORIZONTAL_ALIGNMENT_CENTER))
		var phase_description := _label(str(phase.get("description", "")), 15,
			Color(0.92, 0.80, 0.73) if phase_active else Color(0.76, 0.76, 0.72))
		phase_description.name = "DungeonPhaseDescription"
		phase_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		enemy_column.add_child(phase_description)
	combat_row.add_child(self_panel)
	if narrow_layout:
		combat_row.add_child(enemy_panel)
		content_host.add_child(log_panel)
	else:
		combat_row.add_child(log_panel)
		combat_row.add_child(enemy_panel)

	var hand_host: Container = content_host
	if not narrow_layout:
		var hand_scroll := ScrollContainer.new()
		hand_scroll.name = "DungeonHandScroll"
		hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		hand_scroll.custom_minimum_size.y = 126
		hand_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		page.add_child(hand_scroll)
		hand_host = hand_scroll
	var hand_grid := GridContainer.new()
	hand_grid.name = "DungeonHandGrid"
	hand_grid.columns = 2 if narrow_layout else 5
	hand_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_grid.add_theme_constant_override("h_separation", 10)
	hand_grid.add_theme_constant_override("v_separation", 10)
	hand_host.add_child(hand_grid)
	var hand: Array = battle.hand
	for index in range(hand.size()):
		var card: Dictionary = hand[index]
		var definition: Dictionary = DungeonSystemScript.card_definition(str(card.card_id))
		var upgrade := int(card.get("upgrade", 0))
		var source_name := str(card.get("source_name", "既有功法"))
		var source_kind := str(card.get("source_kind", "foundation"))
		var card_button := _button("%d  %s%s\n%s · 灵力 %d\n%s\n%s" % [index + 1, str(definition.name),
			" +%d" % upgrade if upgrade > 0 else "", source_name, int(definition.cost),
			DungeonSystemScript.card_effect_summary(definition, upgrade),
			str(definition.description)],
			_play_dungeon_card.bind(index), false)
		card_button.name = "DungeonCardButton%d" % index
		card_button.custom_minimum_size = Vector2(0 if narrow_layout else 194, 136 if narrow_layout else 142)
		if narrow_layout:
			card_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Ability cards are primary decisions, so keep their copy centered on an
		# opaque surface instead of letting the scene art compete with the text.
		card_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_button.add_theme_font_size_override("font_size", 16)
		card_button.add_theme_color_override("font_color", Color("f5eee0"))
		card_button.add_theme_color_override("font_hover_color", Color.WHITE)
		card_button.add_theme_color_override("font_pressed_color", Color("fff6d6"))
		card_button.add_theme_color_override("font_disabled_color", Color("9da7a8"))
		var source_color := _ability_source_color(source_kind)
		card_button.add_theme_stylebox_override("normal", _dungeon_card_style(source_color, "normal"))
		card_button.add_theme_stylebox_override("hover", _dungeon_card_style(source_color, "hover"))
		card_button.add_theme_stylebox_override("focus", _dungeon_card_style(source_color, "hover"))
		card_button.add_theme_stylebox_override("pressed", _dungeon_card_style(source_color, "pressed"))
		card_button.add_theme_stylebox_override("disabled", _dungeon_card_style(source_color, "disabled"))
		card_button.disabled = int(definition.cost) > int(battle.energy)
		card_button.tooltip_text = "当前灵力不足。" if card_button.disabled else \
			"能力来源：%s\n%s" % [source_name, str(definition.description)]
		hand_grid.add_child(card_button)
	var feedback_slot := MarginContainer.new()
	feedback_slot.name = "DungeonFeedbackSlot"
	feedback_slot.custom_minimum_size.y = 50
	feedback_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if narrow_layout:
		content_host.add_child(feedback_slot)
	else:
		page.add_child(feedback_slot)

	var actions := HBoxContainer.new()
	actions.name = "DungeonCombatActions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	page.add_child(actions)
	var end_button := _button("结束回合 [E]", _end_dungeon_turn, true)
	end_button.name = "DungeonEndTurnButton"
	actions.add_child(end_button)
	var abandon_button := _button("撤出秘境", _abandon_dungeon, false)
	abandon_button.name = "DungeonCombatAbandonButton"
	actions.add_child(abandon_button)
	_show_dungeon_action_feedback()


func _build_dungeon_header(run: Dictionary, subtitle: String, narrow_layout: bool = false) -> Control:
	var header := _dungeon_surface(era_accent, true)
	header.name = "DungeonHeader"
	header.custom_minimum_size.y = 112 if narrow_layout else 86
	var header_style := header.get_theme_stylebox("panel") as StyleBoxFlat
	header_style.content_margin_top = 10
	header_style.content_margin_bottom = 10
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	header.add_child(content)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	content.add_child(row)
	var title := VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	title.add_child(_display_label(str(run.name), 24, Color("f5e7bd")))
	title.add_child(_label(subtitle, 14, Color(era_accent, 0.90)))
	var profile_label := _label(DungeonSystemScript.ability_profile_label(run), 14,
		Color(0.77, 0.83, 0.82))
	profile_label.name = "DungeonAbilityProfile"
	profile_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if narrow_layout:
		profile_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(profile_label)
	else:
		profile_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.add_child(profile_label)
	var rewards: Dictionary = run.rewards
	row.add_child(_label("暂存修为 %d · 灵石 %d" % [int(rewards.exp), int(rewards.spirit_stones)],
		15, Color("e7c778"), HORIZONTAL_ALIGNMENT_RIGHT))
	return header


func _build_dungeon_log(run: Dictionary, battle: Dictionary, narrow_layout: bool = false) -> Control:
	# The center is a readable combat stage, not a second scrolling transcript.
	var panel := MarginContainer.new()
	panel.name = "DungeonLogPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("margin_left", 2)
	panel.add_theme_constant_override("margin_right", 2)
	var arena := _dungeon_surface(Color("6b9ba8"), true)
	arena.name = "DungeonArenaStage"
	arena.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena.custom_minimum_size.y = 310 if narrow_layout else 292
	panel.add_child(arena)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	arena.add_child(column)
	var title_row := HBoxContainer.new()
	var round_label := _label("交锋中轴", 15, Color("d7e2df"))
	round_label.name = "DungeonArenaTitle"
	title_row.add_child(round_label)
	title_row.add_spacer(false)
	title_row.add_child(_label("第 %d 回合" % int(battle.get("turn", 1)), 14,
		Color(0.69, 0.78, 0.79), HORIZONTAL_ALIGNMENT_RIGHT))
	column.add_child(title_row)
	var duel_stage: Control = DungeonDuelStageScript.new()
	duel_stage.name = "DungeonDuelStage"
	duel_stage.custom_minimum_size.y = 126 if narrow_layout else 118
	duel_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duel_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	duel_stage.call("configure", run, battle, era_accent)
	column.add_child(duel_stage)
	var matchup := HBoxContainer.new()
	matchup.name = "DungeonArenaMatchup"
	matchup.add_theme_constant_override("separation", 10)
	matchup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var player_mark := _label("我方\n气血 %d" % int(run.get("hp", 0)), 16,
		Color("b5d2db"), HORIZONTAL_ALIGNMENT_CENTER)
	player_mark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	matchup.add_child(player_mark)
	matchup.add_child(_display_label("VS", 20, Color("d9b66c"), HORIZONTAL_ALIGNMENT_CENTER))
	var enemy_mark := _label("%s\n气血 %d" % [str(battle.get("enemy_name", "秘境异影")),
		int(battle.get("enemy_hp", 0))], 16, Color("e3b2a6"), HORIZONTAL_ALIGNMENT_CENTER)
	enemy_mark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	matchup.add_child(enemy_mark)
	column.add_child(matchup)
	var preview: Dictionary = DungeonSystemScript.intent_preview(battle)
	var intent_band := MarginContainer.new()
	intent_band.name = "DungeonIntentPanel"
	intent_band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intent_band.add_theme_constant_override("margin_top", 4)
	intent_band.add_theme_constant_override("margin_bottom", 4)
	var intent_column := VBoxContainer.new()
	intent_column.alignment = BoxContainer.ALIGNMENT_CENTER
	intent_band.add_child(intent_column)
	intent_column.add_child(_label("敌意锁定", 11, Color(0.76, 0.77, 0.73), HORIZONTAL_ALIGNMENT_CENTER))
	intent_column.add_child(_display_label("%s  ·  %d %s" % [str(preview.title), int(preview.value),
		str(preview.unit)], 18, Color("f0b181"), HORIZONTAL_ALIGNMENT_CENTER))
	var detail := _label(str(preview.detail), 12, Color(0.84, 0.82, 0.77), HORIZONTAL_ALIGNMENT_CENTER)
	detail.name = "DungeonIntentForecast"
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intent_column.add_child(detail)
	column.add_child(intent_band)
	column.add_child(_build_dungeon_intent_timeline(battle))
	var tape := _label(" · ".join((run.get("log", []) as Array).slice(-2)), 12,
		Color(0.60, 0.68, 0.69, 0.84))
	tape.name = "DungeonBattleTape"
	tape.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(tape)
	return panel


func _build_dungeon_intent_timeline(battle: Dictionary) -> Control:
	var timeline := HBoxContainer.new()
	timeline.name = "DungeonIntentTimeline"
	timeline.add_theme_constant_override("separation", 6)
	var cycle: Array = battle.get("intent_cycle", ["strike"])
	var current := int(battle.get("intent_index", 0))
	for offset in range(mini(3, cycle.size())):
		var intent_id := str(cycle[(current + offset) % cycle.size()])
		var marker := _label(("当前  " if offset == 0 else "随后  ") + DungeonSystemScript.intent_label(intent_id),
			11, Color("e3b67f") if offset == 0 else Color(0.61, 0.68, 0.69),
			HORIZONTAL_ALIGNMENT_CENTER)
		marker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		marker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		timeline.add_child(marker)
	return timeline


func _build_dungeon_route_journal(run: Dictionary, use_inner_scroll: bool = true) -> Control:
	var panel := VBoxContainer.new()
	panel.name = "DungeonRouteJournal"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 10)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(_section_title("镜路因果图"))
	column.add_child(_build_dungeon_route_trail(run))
	column.add_child(_divider())
	column.add_child(_label("近途回声", 16, Color(era_accent, 0.88)))
	var log_label := _label("\n".join((run.log as Array).slice(-7)), 15, Color("eee8da"))
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if use_inner_scroll:
		var scroll := ScrollContainer.new()
		scroll.name = "DungeonRouteJournalScroll"
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(scroll)
		scroll.add_child(log_label)
	else:
		column.add_child(log_label)
	return panel


func _build_dungeon_route_trail(run: Dictionary) -> Control:
	var trail := HBoxContainer.new()
	trail.name = "DungeonRouteTrail"
	trail.custom_minimum_size.y = 116
	trail.add_theme_constant_override("separation", 6)
	var history: Array = run.get("route_history", [])
	var depth := int(run.get("depth", 0))
	var max_depth := maxi(1, int(run.get("max_depth", 4)))
	var choice_count := (run.get("route_choices", []) as Array).size()
	for stage_index in range(max_depth):
		var reached: Dictionary = {}
		for entry_value in history:
			if entry_value is Dictionary and int((entry_value as Dictionary).get("depth", -1)) == stage_index:
				reached = entry_value as Dictionary
				break
		var stage_color := Color(era_accent, 0.56)
		var status_text := "因果未显"
		var name_text := "雾中道标"
		if not reached.is_empty():
			stage_color = _dungeon_route_type_color(str(reached.get("type", "unknown")))
			status_text = "%s · 已渡" % str(reached.get("danger", "因果"))
			name_text = str(reached.get("name", "无名道标"))
		elif stage_index == depth:
			stage_color = era_accent
			status_text = "%d 条因果待择" % maxi(1, choice_count)
			name_text = "此刻立足"
		elif stage_index == max_depth - 1:
			stage_color = Color("df8764")
			status_text = "首领 · 必经"
			name_text = "未生门"
		var stage_panel := _panel(0.47, stage_color)
		stage_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := stage_panel.get_theme_stylebox("panel") as StyleBoxFlat
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 9
		style.content_margin_bottom = 9
		style.shadow_size = 5
		var stack := VBoxContainer.new()
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stage_panel.add_child(stack)
		stack.add_child(_label("第 %d 层" % (stage_index + 1), 13, Color(stage_color, 0.92),
			HORIZONTAL_ALIGNMENT_CENTER))
		var marker := "◆" if not reached.is_empty() else ("◇" if stage_index == depth else "·")
		stack.add_child(_display_label(marker, 18, Color(stage_color, 0.96), HORIZONTAL_ALIGNMENT_CENTER))
		var name_label := _label(name_text, 14, Color("f0eadb"), HORIZONTAL_ALIGNMENT_CENTER)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		stack.add_child(name_label)
		stack.add_child(_label(status_text, 12, Color(0.72, 0.78, 0.79, 0.90),
			HORIZONTAL_ALIGNMENT_CENTER))
		trail.add_child(stage_panel)
		if stage_index < max_depth - 1:
			var connector := _display_label("›", 22, Color(era_accent, 0.58),
				HORIZONTAL_ALIGNMENT_CENTER)
			connector.custom_minimum_size.x = 14
			connector.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			trail.add_child(connector)
	return trail


func _dungeon_route_type_color(node_type: String) -> Color:
	return {
		"combat": Color("dc8262"),
		"memory": Color("74b9c9"),
		"rest": Color("72bd98"),
		"elite": Color("d96f7b"),
		"forge": Color("d5a957"),
		"boss": Color("e55f67"),
	}.get(node_type, era_accent)


func _dungeon_route_preview(node: Dictionary) -> String:
	var node_type := str(node.get("type", "memory"))
	if node_type == "combat":
		return "雾里传来兵刃声，旧剑意正等一个先动的人。"
	if node_type == "elite":
		return "石阶一层层压低灵台，守誓者不会给你第二次试探。"
	if node_type == "boss":
		return "门后站着从未作出选择的你，门缝里没有退路的回声。"
	if node_type == "memory":
		return "残碑没有功法，只有你走过的经脉；触碰它会唤醒谁，尚未可知。"
	if node_type == "forge":
		return "玉台上的火还亮着，能磨一式灵诀，也会留下新的纹路。"
	if node_type == "rest":
		return "泉声替你梳开一段心魔，短暂的安静不会替你停住时间。"
	return "前路的回声尚未落定，走近才能知道它要你付出什么。"


func _dungeon_route_action(node: Dictionary) -> String:
	var node_type := str(node.get("type", "memory"))
	var node_name := str(node.get("name", "无名道标"))
	return {
		"combat": "踏上%s" % node_name,
		"elite": "沿%s继续向上" % node_name,
		"boss": "推开%s" % node_name,
		"memory": "伸手触碰%s" % node_name,
		"forge": "走近%s的余火" % node_name,
		"rest": "在%s旁停步" % node_name,
	}.get(node_type, "走近%s" % node_name)


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
	_play_dungeon_feedback_audio(action_feedback)
	var kind := str(action_feedback.get("kind", "card"))
	var resolution := _dungeon_resolution_feedback(action_feedback)
	var feedback_color := Color("ef665e")
	if kind == "card":
		feedback_color = _ability_source_color(str(action_feedback.get("source_kind", "foundation")))
	elif kind == "encounter":
		feedback_color = Color("ef8b69") if str(action_feedback.get("rank", "combat")) == "boss" \
			else Color("e6b05f")
	elif kind == "victory":
		feedback_color = Color("f0c36b")
	elif kind == "defeat":
		feedback_color = Color("c95868")
	if not resolution.is_empty():
		feedback_color = Color("f29a67") if str(resolution.get("rank", "combat")) == "boss" \
			else Color("f0c36b")
	elif bool(action_feedback.get("phase_shifted", false)):
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
	var label := _label(summary, 17, Color(feedback_color, 0.98), HORIZONTAL_ALIGNMENT_CENTER)
	label.name = "DungeonFeedbackSummary"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size.y = 38
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.015, 0.02, 0.03, 0.94))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var slot := screen_host.find_child("DungeonFeedbackSlot", true, false) as Control
	if slot != null:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot.add_child(label)
		get_tree().create_timer(float(layer.get("lifetime"))).timeout.connect(label.queue_free)
	else:
		label.anchor_left = 0.30
		label.anchor_right = 0.70
		label.anchor_top = 0.64
		label.anchor_bottom = 0.64
		label.offset_top = -26
		label.offset_bottom = 48
		layer.add_child(label)


func _dungeon_feedback_summary(action_feedback: Dictionary) -> String:
	var parts: Array[String] = []
	var kind := str(action_feedback.get("kind", ""))
	if kind == "encounter":
		var rank_label := str({"boss":"首领显形", "elite":"精英压境"}.get(
			str(action_feedback.get("rank", "combat")), "异影拦路"))
		parts.append("%s · %s" % [rank_label, str(action_feedback.get("enemy_name", "秘境异影"))])
		if not str(action_feedback.get("rule_name", "")).is_empty():
			parts.append("%s · %s" % [str(action_feedback.get("rule_title", "敌方法则")),
				str(action_feedback.get("rule_name", ""))])
	elif kind == "victory":
		parts.append("镇灭 · %s" % str(action_feedback.get("enemy_name", "秘境异影")))
	elif kind == "defeat":
		parts.append("道身溃散 · 秘境逐离")
	elif kind == "card":
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
	var resolution := _dungeon_resolution_feedback(action_feedback)
	if not resolution.is_empty():
		parts.append("镇灭 · %s" % str(resolution.get("enemy_name", "秘境异影")) \
			if str(resolution.get("kind", "victory")) == "victory" else "秘境逐离")
		var nested_prefix := "" if bool(resolution.get("dungeon_completed", false)) else "暂存"
		var nested_exp := int(resolution.get("total_exp", 0)) \
			if bool(resolution.get("dungeon_completed", false)) else int(resolution.get("exp_gain", 0))
		var nested_stones := int(resolution.get("total_stones", 0)) \
			if bool(resolution.get("dungeon_completed", false)) else int(resolution.get("stone_gain", 0))
		if nested_exp > 0:
			parts.append("%s修为 +%d" % [nested_prefix, nested_exp])
		if nested_stones > 0:
			parts.append("%s灵石 +%d" % [nested_prefix, nested_stones])
	if kind in ["victory", "defeat"]:
		var reward_prefix := "" if bool(action_feedback.get("dungeon_completed", false)) else "暂存"
		var exp_reward := int(action_feedback.get("total_exp", 0)) \
			if bool(action_feedback.get("dungeon_completed", false)) else int(action_feedback.get("exp_gain", 0))
		var stone_reward := int(action_feedback.get("total_stones", 0)) \
			if bool(action_feedback.get("dungeon_completed", false)) else int(action_feedback.get("stone_gain", 0))
		if exp_reward > 0:
			parts.append("%s修为 +%d" % [reward_prefix, exp_reward])
		if stone_reward > 0:
			parts.append("%s灵石 +%d" % [reward_prefix, stone_reward])
	return "  ·  ".join(parts)


func _dungeon_resolution_feedback(action_feedback: Dictionary) -> Dictionary:
	var value: Variant = action_feedback.get("resolution", {})
	return value as Dictionary if value is Dictionary else {}


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
	var completed_resolution := _dungeon_resolution_feedback(dungeon_action_feedback)
	if not completed_resolution.is_empty():
		dungeon_action_feedback = completed_resolution.duplicate(true)
		dungeon_action_feedback["placement"] = "main" \
			if str(result.get("code", "")) == "dungeon_finished" else "route"
	if str(result.get("code", "")) == "dungeon_finished":
		var exit_feedback := _dungeon_resolution_feedback(dungeon_action_feedback)
		if exit_feedback.is_empty() and str(dungeon_action_feedback.get("kind", "")) in ["victory", "defeat"]:
			exit_feedback = dungeon_action_feedback.duplicate(true)
		dungeon_action_feedback = {}
		_finalize_dungeon_exit(result, save_reason, exit_feedback)
		return
	_sync_state_views()
	_save_current_state(save_reason)
	_show_dungeon()


func _finalize_dungeon_exit(result: Dictionary, save_reason: String,
		resolution_feedback: Dictionary = {}) -> void:
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
	var objective_action := "dungeon_completed" if outcome == "completed" else \
		"dungeon_defeat" if outcome == "defeat" else "dungeon_abandoned"
	var objective_result := _record_objective_action(objective_action)
	_sync_state_views()
	_append_objective_feedback(objective_result)
	if CultivationScript.is_dead(run_state):
		_end_current_life("秘境归来后寿元耗尽")
		return
	_save_current_state(save_reason)
	if not resolution_feedback.is_empty():
		dungeon_action_feedback = resolution_feedback.duplicate(true)
	_show_game()


func _dungeon_scene_path(dungeon_id: String) -> String:
	for value in (DungeonSystemScript.load_definitions().get("dungeons", []) as Array):
		var definition: Dictionary = value
		if str(definition.id) == dungeon_id:
			return str(definition.scene)
	return MENU_SCENE


func _show_event() -> void:
	state = ScreenState.EVENT
	_set_audio_context("event")
	_clear_screen()
	var scene_path := str(current_event.get("scene", ERA_SCENES.get(current_era, MENU_SCENE)))
	_apply_era_visuals(scene_path)

	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 16)
	screen_host.add_child(page)
	var narrow_layout := screen_host.size.x < 1040.0
	page.resized.connect(func() -> void:
		if state == ScreenState.EVENT and (screen_host.size.x < 1040.0) != narrow_layout:
			call_deferred("_refresh_screen_layout", ScreenState.EVENT)
	)

	var header := _panel(0.78, era_accent)
	header.name = "EventHeader"
	header.custom_minimum_size.y = 92
	var header_column := VBoxContainer.new()
	header_column.alignment = BoxContainer.ALIGNMENT_CENTER
	header_column.add_theme_constant_override("separation", 1)
	header.add_child(header_column)
	var chapter_meta := _event_chapter_meta(current_event)
	var chapter_label := _label(str(chapter_meta.get("line", "山河异闻")), 14,
		Color(era_accent, 0.94), HORIZONTAL_ALIGNMENT_CENTER)
	chapter_label.name = "EventChapterMeta"
	header_column.add_child(chapter_label)
	var header_label := _display_label(str(current_event.get("title", "无名因果")), 29,
		Color("f5e7bd"), HORIZONTAL_ALIGNMENT_CENTER)
	header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_column.add_child(header_label)
	page.add_child(header)

	var body: BoxContainer = VBoxContainer.new() if narrow_layout else HBoxContainer.new()
	body.name = "EventBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	if narrow_layout:
		var body_scroll := ScrollContainer.new()
		body_scroll.name = "EventBodyScroll"
		body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		body_scroll.follow_focus = true
		body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body_scroll.add_child(body)
		page.add_child(body_scroll)
	else:
		page.add_child(body)
	if _event_uses_dedicated_visual():
		body.add_child(_build_event_stage(narrow_layout))
	body.add_child(_build_event_choices())

	var footer := _label("数字键选择  ·  ESC 暂离此事", 15,
		Color(0.78, 0.82, 0.82, 0.82), HORIZONTAL_ALIGNMENT_CENTER)
	footer.name = "EventFooter"
	page.add_child(footer)


func _event_uses_dedicated_visual() -> bool:
	# Catalog and generated events intentionally use the stronger text layout
	# until they receive event-specific art; shared placeholders are not shown.
	return str(current_event.get("source", "")) not in ["authored_event", "local_ai"]


func _event_chapter_meta(event: Dictionary) -> Dictionary:
	var source := str(event.get("source", "authored_event"))
	var arc_name := str(event.get("story_arc_name", event.get("arc_name", {
		"story_arc": "命途主卷", "local_ai": "天机外章", "authored_event": "山河异闻",
	}.get(source, "无名纪事"))))
	var chapter := int(event.get("chapter_number", int(player.get("total_events", 0)) + 1))
	var total := int(event.get("chapter_total", 0))
	var phase_name := str(event.get("chapter_phase_name", {
		"main": "今生卷", "echo": "轮回续章", "chronicle": "纪事",
	}.get(str(event.get("phase", event.get("story_phase", "chronicle"))), "纪事")))
	var chapter_text := "第%d章" % maxi(1, chapter)
	if total > 0:
		chapter_text += "/%d" % total
	return {
		"arc_name": arc_name,
		"chapter": maxi(1, chapter),
		"total": maxi(0, total),
		"line": "%s · %s %s · 第%d世 · 世界第%d年" % [arc_name, phase_name,
			chapter_text, int(event.get("generation", run_state.get("generation", 1))),
			int(event.get("world_year", event.get("year",
				(run_state.get("world", {}) as Dictionary).get("year", 1))))],
	}


func _build_event_stage(narrow_layout: bool = false) -> Control:
	var frame := _panel(0.38, era_accent)
	frame.name = "EventStage"
	frame.custom_minimum_size = Vector2(0, 360) if narrow_layout else Vector2(515, 0)
	var stage := Control.new()
	stage.clip_contents = true
	frame.add_child(stage)

	var motion_profile_id := str(current_event.get("motion_profile", "restrained"))
	var motion_seed := str(current_event.get("id", current_event.get("story_arc_id", "event")))
	var portrait_path := str(current_event.get("portrait", ""))
	var portrait_mode := str(current_event.get("portrait_mode", "focus"))
	if portrait_mode == "scene_only" or portrait_path.is_empty():
		var scene := TextureRect.new()
		scene.name = "EventScene"
		scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		scene.texture = load(str(current_event.get("scene", MENU_SCENE)))
		scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(scene)
		_attach_art_motion(scene, motion_profile_id, CinematicArtMotionScript.LayerMode.SCENE,
			"%s-scene" % motion_seed)
	else:
		var portrait := TextureRect.new()
		portrait.name = "EventPortrait"
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_SCALE
		portrait.texture = load(portrait_path)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(portrait)
		var focus_y := clampf(float(current_event.get("portrait_focus_y", 0.18)), 0.0, 1.0)
		stage.resized.connect(func() -> void:
			_layout_focus_portrait(portrait, stage, focus_y)
		)
		call_deferred("_layout_focus_portrait", portrait, stage, focus_y)
		_attach_art_motion(portrait, motion_profile_id, CinematicArtMotionScript.LayerMode.PORTRAIT,
			"%s-%s" % [motion_seed, str(current_event.get("character_id", "portrait"))], false)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.025, 0.045, 0.16)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(shade)

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


func _layout_focus_portrait(portrait: TextureRect, stage: Control, focus_y: float) -> void:
	if not is_instance_valid(portrait) or portrait.texture == null or stage.size.x < 1.0 or stage.size.y < 1.0:
		return
	var texture_size := portrait.texture.get_size()
	if texture_size.x < 1.0 or texture_size.y < 1.0:
		return
	var cover_scale := maxf(stage.size.x / texture_size.x, stage.size.y / texture_size.y)
	var rendered_size := texture_size * cover_scale
	var overflow := rendered_size - stage.size
	portrait.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	portrait.position = Vector2(-overflow.x * 0.5, -overflow.y * focus_y)
	portrait.size = rendered_size


func _build_event_choices() -> Control:
	var panel := _panel(0.84, era_accent)
	panel.name = "EventChoicesPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	column.add_child(_label(current_era + " · 因果抉择", 15, Color(era_accent, 0.92)))
	var recap := str(current_event.get("previous_choice_recap", ""))
	if recap.is_empty():
		recap = StorySystemScript.previous_choice_recap(run_state, current_event)
	if not recap.is_empty():
		var recap_label := _label("前情 · %s" % recap, 15, Color(0.75, 0.81, 0.80, 0.92))
		recap_label.name = "EventPreviousChoice"
		recap_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(recap_label)
	var description := _label(str(current_event.get("description", "")), 20, Color("f1eee5"))
	description.name = "EventDescription"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.y = 128
	column.add_child(description)
	column.add_child(_divider())

	var choices: Array = current_event.get("choices", [])
	for index in range(choices.size()):
		var choice: Dictionary = choices[index]
		var unavailable_reason := _choice_unavailable_reason(choice)
		var choice_button := _button("%d  %s" % [index + 1, str(choice.get("text", "沉默"))],
			_resolve_choice.bind(index), false)
		choice_button.name = "EventChoiceButton%d" % index
		choice_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choice_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice_button.custom_minimum_size.y = 64
		choice_button.disabled = not unavailable_reason.is_empty()
		choice_button.tooltip_text = unavailable_reason
		column.add_child(choice_button)
		if not unavailable_reason.is_empty():
			var reason_label := _label("此路未开 · %s" % unavailable_reason, 12,
				Color(0.78, 0.68, 0.65, 0.94))
			reason_label.name = "EventChoiceUnavailableReason%d" % index
			reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			column.add_child(reason_label)
	return panel


func _resolve_choice(index: int) -> void:
	var choices: Array = current_event.get("choices", [])
	if index < 0 or index >= choices.size():
		return
	var choice: Dictionary = choices[index]
	if not current_event.has("chapter_number"):
		current_event["chapter_number"] = int(player.get("total_events", 0)) + 1
	current_event["generation"] = int(run_state.get("generation", 1))
	current_event["world_year"] = int((run_state.get("world", {}) as Dictionary).get("year", 1))
	current_event["turn"] = int(run_state.get("turn", 0))
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
	var outcome := str(choice.get("outcome", "因果落定，旧玉没有给出解释。"))
	feedback = outcome
	_add_memory("%s：%s" % [str(current_event.get("title", "无名事件")), str(choice.get("text", "沉默"))])
	run_state["player"] = player
	EventCatalogScript.record_resolution(run_state, current_event, choice)
	var story_resolution: Dictionary = StorySystemScript.resolve_choice(run_state, current_event, index)
	var story_message := ""
	if bool(story_resolution.get("ok", false)):
		story_message = str(story_resolution.get("message", "命途长卷又落下一笔。"))
		feedback += "\n\n" + story_message
		if bool(story_resolution.get("terminal", false)):
			_add_memory(str(story_resolution.get("message", "一条跨世因果已经定局。")))
	AchievementSystemScript.add_resonance(run_state, 3, "历练抉择")
	CultivationScript.advance_time(run_state, 1)
	var event_source := str(current_event.get("source", ""))
	var objective_action := "story_event" if event_source == "story_arc" else \
		"local_ai_event" if event_source == "local_ai" else "adventure"
	var objective_result := _record_objective_action(objective_action)
	var encounter_offer := EncounterSystemScript.offer_from_choice(run_state, current_event, choice)
	var encounter_message := ""
	if bool(encounter_offer.get("ok", false)) and \
		str(encounter_offer.get("code", "")) == "encounter_offered":
		encounter_message = str(encounter_offer.get("message", "敌踪已现。"))
		objective_result["encounter_message"] = encounter_message
	if _choice_grants_dungeon_clue(choice):
		var clue_result: Dictionary = DungeonSystemScript.grant_clue(run_state,
			"%s · %s" % [str(current_event.get("title", "无名因果")), str(choice.get("text", "沉默"))])
		if bool(clue_result.get("granted", false)):
			var clue_message := str(clue_result.get("message", "秘境线索已显形。"))
			feedback += "\n\n" + clue_message
			objective_result["world_message"] = clue_message
	_sync_state_views()
	_append_objective_feedback(objective_result)
	if str(objective_result.get("encounter_message", "")).is_empty() == false:
		feedback += "\n\n" + str(objective_result.get("encounter_message", ""))
		run_state["feedback"] = feedback
	var objective_message := str(objective_result.get("message", ""))
	var world_message := str(objective_result.get("world_message", ""))
	if not world_message.is_empty():
		objective_message += ("\n" if not objective_message.is_empty() else "") + world_message
	var chapter_entry := StorySystemScript.record_chapter(run_state, current_event, choice,
		outcome, story_message, objective_message, encounter_message)
	current_event_result = chapter_entry.duplicate(true)
	current_event_result["world_message"] = world_message
	current_event_result["full_feedback"] = feedback
	current_event = {}
	if CultivationScript.is_dead(run_state):
		_end_current_life("因果事件中的重创")
		return
	_save_current_state("因果抉择已自动封存")
	_show_event_result()

func _choice_unavailable_reason(choice: Dictionary) -> String:
	# Authored story nodes provide availability from the consequence system. Keep
	# that decision authoritative, while legacy/catalog events still receive a
	# small local resource check.
	var declared_reason := str(choice.get("unavailable_reason", "")).strip_edges()
	if choice.has("available"):
		if bool(choice.get("available", true)):
			return ""
		return declared_reason if not declared_reason.is_empty() else "此前的因果尚未走到这里。"
	if not declared_reason.is_empty():
		return declared_reason
	var deltas: Dictionary = choice.get("deltas", {})
	var resource_names := {"spirit_stones": "灵石", "pills": "丹药"}
	for resource_id in resource_names.keys():
		var delta := int(deltas.get(resource_id, 0))
		if delta < 0 and int(player.get(resource_id, 0)) + delta < 0:
			return "%s不足，无法作出这个选择。" % str(resource_names[resource_id])
	return ""


func _choice_grants_dungeon_clue(choice: Dictionary) -> bool:
	if bool(choice.get("dungeon_clue", false)):
		return true
	return int(choice.get("dungeon_clues", 0)) > 0


func _show_event_result() -> void:
	state = ScreenState.EVENT_RESULT
	_set_audio_context("event")
	_clear_screen()
	_apply_era_visuals()
	var page := VBoxContainer.new()
	page.name = "EventResultPage"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 14)
	screen_host.add_child(page)
	var meta := _event_chapter_meta(current_event_result)
	var header := _panel(0.78, era_accent)
	header.name = "EventResultHeader"
	header.custom_minimum_size.y = 104
	var heading := VBoxContainer.new()
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_theme_constant_override("separation", 2)
	heading.add_child(_label(str(meta.get("line", "命途纪事")), 14,
		Color(era_accent, 0.94), HORIZONTAL_ALIGNMENT_CENTER))
	heading.add_child(_display_label("这一页已经写下", 30, Color("f5e7bd"), HORIZONTAL_ALIGNMENT_CENTER))
	heading.add_child(_label(str(current_event_result.get("title", "无名因果")), 16,
		Color(0.84, 0.87, 0.85, 0.94), HORIZONTAL_ALIGNMENT_CENTER))
	header.add_child(heading)
	page.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.name = "EventResultScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var reading := _panel(0.86, era_accent)
	reading.name = "EventResultReading"
	reading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	reading.add_child(content)
	content.add_child(_label("你选择了", 15, Color(era_accent, 0.92)))
	var choice_label := _display_label("“%s”" % str(current_event_result.get("choice", "沉默")), 22,
		Color("f0e7d2"))
	choice_label.name = "EventResultChoice"
	choice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(choice_label)
	content.add_child(_divider())
	content.add_child(_label("余波", 15, Color(era_accent, 0.92)))
	var outcome := _label(str(current_event_result.get("outcome", "因果无声落定。")), 21,
		Color("f3eee3"))
	outcome.name = "EventResultOutcome"
	outcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(outcome)
	var story_message := str(current_event_result.get("story_message", ""))
	if not story_message.is_empty():
		content.add_child(_result_note("长卷余音", story_message, Color("d9c98f")))
	var world_message := str(current_event_result.get("world_message", ""))
	if not world_message.is_empty():
		content.add_child(_result_note("山河回声", world_message, Color("8fc7b5")))
	var encounter_message := str(current_event_result.get("encounter_message", ""))
	if not encounter_message.is_empty():
		content.add_child(_result_note("敌踪", encounter_message, Color("ef9a78")))
	scroll.add_child(reading)

	var footer := HBoxContainer.new()
	footer.name = "EventResultFooter"
	footer.add_theme_constant_override("separation", 10)
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var journal_button := _button("查看命途长卷", _show_journal, false)
	journal_button.name = "EventResultJournalButton"
	journal_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(journal_button)
	var continue_button := _button("翻过此页", _continue_from_event_result, true)
	continue_button.name = "EventResultContinueButton"
	continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(continue_button)
	page.add_child(footer)
	continue_button.grab_focus()


func _result_note(title: String, detail: String, color: Color) -> Control:
	var note := VBoxContainer.new()
	note.add_theme_constant_override("separation", 2)
	note.add_child(_label(title, 14, color))
	var body := _label(detail, 16, Color(0.82, 0.85, 0.84, 0.92))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_child(body)
	return note


func _continue_from_event_result() -> void:
	current_event_result = {}
	_show_game()


func _show_journal() -> void:
	state = ScreenState.JOURNAL
	_set_audio_context("world")
	_clear_screen()
	_apply_era_visuals()
	var page := VBoxContainer.new()
	page.name = "JournalPage"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 12)
	screen_host.add_child(page)
	var header := _panel(0.78, era_accent)
	header.name = "JournalHeader"
	header.custom_minimum_size.y = 92
	var heading := VBoxContainer.new()
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_child(_display_label("命途长卷", 31, Color("f0d99c"), HORIZONTAL_ALIGNMENT_CENTER))
	heading.add_child(_label("每一次选择都留下可回看的章节；未竟之事不会因为离开页面而消失。", 15,
		Color(0.82, 0.85, 0.84, 0.92), HORIZONTAL_ALIGNMENT_CENTER))
	header.add_child(heading)
	page.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.name = "JournalScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "JournalBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	var surface := PanelContainer.new()
	surface.name = "JournalSurface"
	surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var surface_style := StyleBoxFlat.new()
	surface_style.bg_color = Color(0.025, 0.04, 0.058, 0.88)
	surface_style.content_margin_left = 24
	surface_style.content_margin_right = 24
	surface_style.content_margin_top = 18
	surface_style.content_margin_bottom = 28
	surface.add_theme_stylebox_override("panel", surface_style)
	scroll.add_child(surface)
	surface.add_child(body)
	_build_journal_objective(body)
	_build_journal_threads(body)
	_build_journal_arcs(body)
	_build_journal_resolved(body)
	_build_journal_recent(body)
	var back := _button("返回山河", _show_game, true)
	back.name = "JournalBackButton"
	page.add_child(back)
	back.grab_focus()


func _build_journal_objective(body: VBoxContainer) -> void:
	body.add_child(_section_title("此世所求"))
	var summary: Dictionary = ObjectiveSystemScript.summary(run_state)
	if not bool(summary.get("active", false)):
		body.add_child(_label("本轮命途尚未择定。回到山河后，先决定接下来八次年轮要追求什么。", 16,
			Color(0.78, 0.83, 0.82, 0.92)))
		return
	body.add_child(_label("%s · 尚余%d次年轮 · 连续践行%d" % [str(summary.get("name", "无名命途")),
		int(summary.get("remaining_turns", 0)), int(summary.get("streak", 0))], 16,
		Color(0.86, 0.88, 0.84, 0.95)))
	body.add_child(_progress_row("道印", int(summary.get("progress", 0)), int(summary.get("target", 1)),
		Color("8fc7b5")))
	var recommendation := _label(str(summary.get("recommendation", "继续沿着已经选择的方向行动。")), 14,
		Color(0.74, 0.80, 0.79, 0.9))
	recommendation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(recommendation)


func _build_journal_threads(body: VBoxContainer) -> void:
	body.add_child(_section_title("未竟因果"))
	var threads: Array = (run_state.get("story", {}) as Dictionary).get("unresolved_threads", [])
	if threads.is_empty():
		body.add_child(_label("眼下没有悬而未决的主线，山河暂时允许你喘息。", 16,
			Color(0.76, 0.82, 0.81, 0.9)))
		return
	for thread_value in threads.slice(-8):
		var thread := _journal_thread_text(str(thread_value))
		body.add_child(_result_note("仍在等待", thread, Color("efb779")))


func _build_journal_arcs(body: VBoxContainer) -> void:
	body.add_child(_section_title("主线时钟"))
	var story: Dictionary = run_state.get("story", {})
	var definitions: Dictionary = StorySystemScript.load_definitions()
	var names := {}
	for arc_value in (definitions.get("arcs", []) as Array):
		var arc: Dictionary = arc_value
		names[str(arc.get("id", ""))] = str(arc.get("name", "无名主线"))
	for arc_id in StorySystemScript.ARC_IDS:
		var progress := int((story.get("arc_progress", {}) as Dictionary).get(arc_id, 0))
		var legacy := str((story.get("arc_legacies", {}) as Dictionary).get(arc_id, ""))
		var echo: Dictionary = (story.get("arc_echoes", {}) as Dictionary).get(arc_id, {})
		var display_progress := progress
		var maximum := StorySystemScript.MAIN_STAGE_COUNT
		var status := "主线 %d/%d" % [progress, maximum]
		if not legacy.is_empty():
			display_progress = int(echo.get("stage", 0))
			maximum = StorySystemScript.ECHO_STAGE_COUNT
			status = "已定局 · 续章 %d/%d" % [display_progress, maximum]
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 3)
		stack.add_child(_label("%s · %s" % [str(names.get(arc_id, arc_id)), status], 15,
			Color(0.84, 0.87, 0.84, 0.94)))
		stack.add_child(_progress_row("命途进度", display_progress, maximum, era_accent))
		if not legacy.is_empty():
			stack.add_child(_label("跨世定局：%s" % legacy, 14, Color("d9c98f")))
		body.add_child(stack)


func _build_journal_resolved(body: VBoxContainer) -> void:
	var resolved: Array = (run_state.get("story", {}) as Dictionary).get("resolved_arcs", [])
	if resolved.is_empty():
		return
	body.add_child(_section_title("已成定局"))
	for resolution_value in resolved.slice(-8):
		var resolution: Dictionary = resolution_value
		var phase_name := "今生定局" if str(resolution.get("phase", "main")) == "main" else "续章结论"
		body.add_child(_result_note("%s · %s" % [str(resolution.get("arc_name", "无名主线")), phase_name],
			"第%d世：%s" % [int(resolution.get("generation", 1)),
				str(resolution.get("resolution", "结局未名"))], Color("d9c98f")))


func _build_journal_recent(body: VBoxContainer) -> void:
	body.add_child(_section_title("最近章节"))
	var chapters: Array = StorySystemScript.recent_chapters(run_state, 12)
	if chapters.is_empty():
		body.add_child(_label("你还没有翻开第一章。下一次历练会把新的文字交给你。", 16,
			Color(0.76, 0.82, 0.81, 0.9)))
		return
	for entry_value in chapters:
		var entry: Dictionary = entry_value
		var card := VBoxContainer.new()
		card.name = "JournalChapter_%s" % str(entry.get("id", "chapter")).replace(":", "_")
		var column := card
		column.add_theme_constant_override("separation", 4)
		column.add_child(_label("第%d世 · 世界第%d年 · %s · 第%d章%s" % [
			int(entry.get("generation", 1)), int(entry.get("year", 1)),
			str(entry.get("arc_name", "无名纪事")), int(entry.get("chapter_number", 1)),
			"/%d" % int(entry.get("chapter_total", 0)) if int(entry.get("chapter_total", 0)) > 0 else ""],
			13, Color(era_accent, 0.9)))
		column.add_child(_display_label(str(entry.get("title", "无名因果")), 19, Color("f0e7d2")))
		column.add_child(_label("你选择了“%s”" % str(entry.get("choice", "沉默")), 15,
			Color(0.83, 0.86, 0.84, 0.94)))
		var outcome := _label(str(entry.get("outcome", "")), 16, Color(0.78, 0.82, 0.81, 0.92))
		outcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(outcome)
		body.add_child(card)
		body.add_child(_divider())


func _journal_thread_text(thread: String) -> String:
	# Storage keeps stable prefixes for migration and cleanup; the journal only
	# exposes the authored thread text, never internal arc/thread identifiers.
	if thread.begins_with("side:") or thread.begins_with("story:"):
		var first_separator := thread.find(":")
		var second_separator := thread.find(":", first_separator + 1)
		if second_separator >= 0:
			var authored_text := thread.substr(second_separator + 1)
			return authored_text.trim_prefix(":").strip_edges()
	var parts := thread.split(":")
	var visible: Array[String] = []
	for part in parts:
		if not str(part).is_empty() and part not in ["story", "jade", "sect", "family", "rival"]:
			visible.append(str(part))
	return ":".join(visible) if not visible.is_empty() else thread


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


func _return_to_menu() -> void:
	if not _save_current_state("返回标题前自动封存"):
		feedback = "旧玉未能完成封存；为避免丢失此世进度，仍留在当前山河。"
		_show_game()
		return
	menu_notice = save_notice
	_show_menu()


func _save_current_state(reason: String) -> bool:
	_commit_state_views()
	var save_result: Dictionary = save_service.call("save_game", run_state)
	if bool(save_result.get("ok", false)):
		save_notice = "%s · %s" % [reason, str(save_result.get("message", "已保存"))]
		return true
	save_notice = "保存失败 · %s" % str(save_result.get("message", "未知原因"))
	return false


func _record_objective_action(action_id: String) -> Dictionary:
	_commit_state_views()
	var encounter_result: Dictionary = EncounterSystemScript.expire_if_needed(run_state)
	var result: Dictionary = ObjectiveSystemScript.record_action(run_state, action_id)
	if bool(encounter_result.get("expired", false)):
		result["world_message"] = str(encounter_result.get("message", "敌踪已经消散。"))
	if bool(result.get("completed", false)):
		var objective_id := str(result.get("objective_id", ""))
		_add_memory("阶段命途【%s】圆满，连续践行被旧玉记下。" %
			str(ObjectiveSystemScript.definition(objective_id).get("name", objective_id)))
	elif bool(result.get("missed", false)):
		var objective_id := str(result.get("objective_id", ""))
		_add_memory("阶段命途【%s】逾期，连续践行归零。" %
			str(ObjectiveSystemScript.definition(objective_id).get("name", objective_id)))
	return result


func _append_objective_feedback(result: Dictionary) -> void:
	var message := str(result.get("message", ""))
	if not message.is_empty():
		feedback += "\n\n" + message
	var world_message := str(result.get("world_message", ""))
	if not world_message.is_empty():
		feedback += "\n\n" + world_message
	run_state["feedback"] = feedback


func _add_memory(text: String) -> void:
	recent_memories.append(text)
	while recent_memories.size() > 12:
		recent_memories.pop_front()
	run_state["recent_memories"] = recent_memories.duplicate()


func _end_current_life(cause: String, rebirth_roll: int = -1) -> void:
	_commit_state_views()
	var result: Dictionary = ReincarnationScript.close_life(run_state, cause, rebirth_roll)
	if not bool(result.get("ok", false)) and str(result.get("code", "")) != "already_closed":
		feedback = "旧玉无法封存此世，轮回暂时停在门外。"
		_show_game()
		return
	_sync_state_views()
	_save_current_state("此世终章已封存")
	_show_reincarnation()

func _current_death_cause() -> String:
	if int(player.get("hp", 0)) <= 0:
		return "重伤不治"
	return "寿元耗尽"


func _show_reincarnation() -> void:
	state = ScreenState.REINCARNATION
	_set_audio_context("reincarnation", "reincarnation.enter")
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
	var verdict: Dictionary = legacy.get("last_rebirth_verdict", {})
	if int(verdict.get("generation", -1)) != int(run_state.get("generation", 1)):
		verdict = ReincarnationScript.judge_rebirth(run_state)
	var rebirth_triggered := bool(verdict.get("triggered", false))
	var narrow_layout := screen_host.size.x < 1040.0
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 16)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.resized.connect(func() -> void:
		if state == ScreenState.REINCARNATION and (screen_host.size.x < 1040.0) != narrow_layout:
			call_deferred("_refresh_screen_layout", ScreenState.REINCARNATION)
	)
	if narrow_layout:
		var page_scroll := ScrollContainer.new()
		page_scroll.name = "ReincarnationScroll"
		page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		page_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		page_scroll.follow_focus = true
		page_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		page.custom_minimum_size.y = screen_host.size.y
		page_scroll.add_child(page)
		screen_host.add_child(page_scroll)
	else:
		screen_host.add_child(page)
	var card := _panel(0.86, Color("d7bd75"))
	card.name = "ReincarnationCard"
	card.custom_minimum_size = Vector2(0 if narrow_layout else 760, 560)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow_layout else Control.SIZE_SHRINK_CENTER
	page.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)
	column.add_child(_display_label(
		"此世已尽，轮回玉重新亮起" if rebirth_triggered else "此世已尽，轮回未启",
		34, Color("f0d99c") if rebirth_triggered else Color("d8b5aa"), HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_label("第%d世 · %s · %s %d层 · 享年%d" % [
		int(last_life.get("generation", 1)), str(last_life.get("name", "无名")),
		str(last_life.get("realm", "凡人")), int(last_life.get("level", 1)),
		int(last_life.get("age_at_death", 18))],
		18, Color(0.86, 0.87, 0.85), HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_label("死因 · %s\n道途归结 · %s" % [
		str(last_life.get("cause_of_death", "命数已尽")), str(last_life.get("dao_name", "本我大道"))],
		17, Color(0.78, 0.82, 0.82), HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_label("轮回判定 · %d%% · 命数 %d/100 · %s" % [
		int(verdict.get("chance", 0)), int(verdict.get("roll", 0)),
		"旧玉接住了这一缕神魂" if rebirth_triggered else "这一世的神魂归于天地"],
		16, Color("cfd8c1") if rebirth_triggered else Color("d8b5aa"), HORIZONTAL_ALIGNMENT_CENTER))
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
	if rebirth_triggered:
		var name_input := LineEdit.new()
		name_input.name = "NextLifeNameInput"
		name_input.placeholder_text = "为第%d世写下道号" % (int(run_state.get("generation", 1)) + 1)
		name_input.max_length = 32
		name_input.custom_minimum_size.y = 48
		_style_line_edit(name_input)
		column.add_child(name_input)
		var next_life_button := _button("循着心跳醒入下一世", _begin_next_life.bind(name_input), true)
		next_life_button.name = "NextLifeButton"
		column.add_child(next_life_button)
		column.add_child(_label("世界不会重置：旧人会老去，宗门会兴衰，未竟因果会换一副面孔回来。",
			14, Color(0.72, 0.76, 0.77), HORIZONTAL_ALIGNMENT_CENTER))
		name_input.grab_focus()
	else:
		var ending_text := _label("没有按钮可以让死亡反悔。此生命途、许诺与遗憾仍留在长卷中；若再开一局，天地会给出另一条路。",
			17, Color("ddd2c2"), HORIZONTAL_ALIGNMENT_CENTER)
		ending_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(ending_text)
		var ending_actions := HBoxContainer.new()
		ending_actions.add_theme_constant_override("separation", 12)
		var journal_button := _button("回看此生命途", _show_journal, false)
		journal_button.name = "EndingJournalButton"
		journal_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ending_actions.add_child(journal_button)
		var menu_button := _button("返回标题", _return_to_menu, true)
		menu_button.name = "EndingMenuButton"
		menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ending_actions.add_child(menu_button)
		column.add_child(ending_actions)


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


func _open_audio_settings() -> void:
	audio_return_state = state if state in [ScreenState.MENU, ScreenState.GAME] else ScreenState.GAME
	_show_audio_settings()


func _show_audio_settings() -> void:
	state = ScreenState.AUDIO_SETTINGS
	_clear_screen()
	var narrow_layout := screen_host.size.x < 1040.0
	var scroll := ScrollContainer.new()
	scroll.name = "AudioSettingsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.resized.connect(func() -> void:
		if state == ScreenState.AUDIO_SETTINGS and (screen_host.size.x < 1040.0) != narrow_layout:
			call_deferred("_refresh_screen_layout", ScreenState.AUDIO_SETTINGS)
	)
	screen_host.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.custom_minimum_size.y = 760
	scroll.add_child(center)
	var card := _panel(0.90, Color("d8b967"))
	card.name = "AudioSettingsPanel"
	card.custom_minimum_size = Vector2(0 if narrow_layout else 850, 0)
	if narrow_layout:
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	column.add_child(_display_label("音律与听觉设置", 34, Color("f3dfa8"), HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_label("每一类声音都可独立归零；关键危险始终同时保留文字与视觉反馈。", 15,
		Color(0.80, 0.84, 0.83), HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_divider())
	column.add_child(_section_title("音量分层"))
	var settings: Dictionary = audio_director.call("get_settings") if is_instance_valid(audio_director) else {}
	var volume_specs := [
		["master", "总音量", "全局最终输出", "AudioMasterSlider"],
		["music", "音乐", "主题、探索与战斗音乐", "AudioMusicSlider"],
		["ambience", "环境", "时代声景、天气与地点底床", "AudioAmbienceSlider"],
		["sfx", "音效", "战斗、能力、秘境与转场", "AudioSFXSlider"],
		["ui", "界面", "确认、返回与操作反馈", "AudioUISlider"],
		["vo", "语音", "为后续角色语音保留的独立通道", "AudioVOSlider"],
	]
	for spec_value in volume_specs:
		var spec: Array = spec_value
		column.add_child(_audio_volume_row(str(spec[0]), str(spec[1]), str(spec[2]),
			str(spec[3]), float(settings.get(spec[0], 100.0)), narrow_layout))
	column.add_child(_divider())
	column.add_child(_section_title("舒适与无障碍"))
	var toggle_grid := GridContainer.new()
	toggle_grid.name = "AudioAccessibilityGrid"
	toggle_grid.columns = 1 if narrow_layout else 2
	toggle_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle_grid.add_theme_constant_override("h_separation", 12)
	toggle_grid.add_theme_constant_override("v_separation", 10)
	column.add_child(toggle_grid)
	toggle_grid.add_child(_audio_toggle("全局静音", "立即静音全部总线，音量值不会丢失。", "muted",
		bool(settings.get("muted", false)), "AudioMutedToggle", narrow_layout))
	toggle_grid.add_child(_audio_toggle("失焦时静音", "切换到其他窗口时停止非必要声音。", "mute_unfocused",
		bool(settings.get("mute_unfocused", true)), "AudioUnfocusedToggle", narrow_layout))
	toggle_grid.add_child(_audio_toggle("夜间模式", "压缩动态范围，让低声可辨而强声不扰人。", "night_mode",
		bool(settings.get("night_mode", false)), "AudioNightToggle", narrow_layout))
	toggle_grid.add_child(_audio_toggle("减少突发强音", "首领破相、失败与强冲击降低峰值约六分贝。", "reduce_sudden",
		bool(settings.get("reduce_sudden", false)), "AudioSuddenToggle", narrow_layout))
	toggle_grid.add_child(_audio_toggle("单声道输出", "折叠左右声像；关键信息不会只存在于一侧。", "mono",
		bool(settings.get("mono", false)), "AudioMonoToggle", narrow_layout))
	column.add_child(_label("运行规格 · 48 kHz 立体声 · Master 安全限幅 -1 dB · 设置保存在本机用户目录",
		14, Color(0.70, 0.76, 0.77), HORIZONTAL_ALIGNMENT_CENTER))
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	column.add_child(actions)
	var preview := _button("试听关键反馈", _preview_audio_mix, false)
	preview.name = "AudioPreviewButton"
	preview.custom_minimum_size.x = 0 if narrow_layout else 230
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(preview)
	var close := _button("关闭并返回", _close_audio_settings, true)
	close.name = "AudioSettingsBackButton"
	close.custom_minimum_size.x = 0 if narrow_layout else 230
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(close)


func _audio_volume_row(key: String, title: String, description: String,
		node_name: String, value: float, compact: bool = false) -> Control:
	var row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var text_box := VBoxContainer.new()
	text_box.custom_minimum_size.x = 0 if compact else 245
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_child(_label(title, 17, Color("f0e7d2")))
	text_box.add_child(_label(description, 13, Color(0.70, 0.76, 0.77)))
	var slider := HSlider.new()
	slider.name = node_name
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = value
	slider.tick_count = 11
	slider.ticks_on_borders = true
	slider.custom_minimum_size = Vector2(0 if compact else 420, 38)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.tooltip_text = "%s音量，方向键可逐级调整。" % title
	var value_label := _label("%d%%" % int(round(value)), 16, Color("e8c878"), HORIZONTAL_ALIGNMENT_RIGHT)
	value_label.name = "%sValue" % node_name
	value_label.custom_minimum_size.x = 60
	if compact:
		var heading := HBoxContainer.new()
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(text_box)
		heading.add_child(value_label)
		row.add_child(heading)
		row.add_child(slider)
	else:
		row.add_child(text_box)
		row.add_child(slider)
		row.add_child(value_label)
	slider.value_changed.connect(_on_audio_volume_changed.bind(key, value_label))
	return row


func _audio_toggle(title: String, description: String, key: String,
		value: bool, node_name: String, compact: bool = false) -> Control:
	var panel := _panel(0.46, era_accent)
	panel.custom_minimum_size = Vector2(0 if compact else 380, 82)
	if compact:
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	var toggle := CheckButton.new()
	toggle.name = node_name
	toggle.text = title
	toggle.button_pressed = value
	toggle.add_theme_font_size_override("font_size", 17)
	toggle.tooltip_text = description
	column.add_child(toggle)
	var explanation := _label(description, 13, Color(0.72, 0.78, 0.78))
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(explanation)
	toggle.toggled.connect(_on_audio_setting_toggled.bind(key))
	return panel


func _on_audio_volume_changed(value: float, key: String, value_label: Label) -> void:
	value_label.text = "%d%%" % int(round(value))
	if not is_instance_valid(audio_director):
		return
	audio_director.call("set_bus_percent", key, value)
	audio_director.call("save_settings")


func _on_audio_setting_toggled(enabled: bool, key: String) -> void:
	if not is_instance_valid(audio_director):
		return
	audio_director.call("set_setting", key, enabled)
	audio_director.call("save_settings")
	if key == "muted" and not enabled:
		audio_director.call("play_event", "ui.confirm")


func _preview_audio_mix() -> void:
	if is_instance_valid(audio_director):
		audio_director.call("play_event", "dungeon.phase_break")


func _close_audio_settings() -> void:
	if is_instance_valid(audio_director):
		audio_director.call("save_settings")
	if audio_return_state == ScreenState.MENU:
		_show_menu()
	else:
		_show_game()


func _set_audio_context(context_id: String, entry_event: String = "") -> void:
	if not is_instance_valid(audio_director):
		return
	var previous := str(audio_director.call("get_context"))
	audio_director.call("set_context", context_id)
	audio_director.call("set_era", str(run_state.get("current_era_id", "classical")))
	if previous != context_id and not entry_event.is_empty():
		audio_director.call("play_event", entry_event)


func _play_combat_action_audio(action: String, result: Dictionary) -> void:
	if not is_instance_valid(audio_director):
		return
	if str(result.get("code", "")) == "combat_finished":
		var outcome := str(result.get("outcome", "escaped"))
		if outcome == "victory":
			audio_director.call("play_event", "combat.victory")
		elif outcome == "defeat":
			audio_director.call("play_event", "combat.defeat")
		else:
			audio_director.call("play_event", "ui.cancel")
		return
	var event_id: String = str({
		"attack": "combat.impact", "guard": "combat.guard", "spell": "combat.spell",
		"pill": "ui.confirm", "flee": "ui.cancel",
	}.get(action, "ui.confirm"))
	var event_value: Variant = result.get("event", {})
	if event_value is Dictionary:
		var event: Dictionary = event_value
		var steps_value: Variant = event.get("steps", [])
		if steps_value is Array:
			for step_value in (steps_value as Array):
				if not step_value is Dictionary:
					continue
				var cue := str((step_value as Dictionary).get("cue", ""))
				if cue in ["combat.impact", "combat.guard", "combat.spell"]:
					event_id = cue
					break
	audio_director.call("play_event", event_id)


func _play_dungeon_feedback_audio(action_feedback: Dictionary) -> void:
	if not is_instance_valid(audio_director):
		return
	if bool(action_feedback.get("phase_shifted", false)):
		audio_director.call("play_event", "dungeon.phase_break")
		return
	if bool(action_feedback.get("heart_awakened", false)):
		audio_director.call("play_event", "dungeon.heart")
		return
	var resolution := _dungeon_resolution_feedback(action_feedback)
	var audible := resolution if not resolution.is_empty() else action_feedback
	var kind := str(audible.get("kind", "card"))
	if kind == "encounter":
		var rank := str(audible.get("rank", "combat"))
		if rank == "boss":
			audio_director.call("play_event", "dungeon.boss_enter")
		elif rank == "elite":
			audio_director.call("play_event", "dungeon.elite_enter")
		return
	if kind == "victory":
		audio_director.call("play_event", "dungeon.victory")
		return
	if kind == "defeat":
		audio_director.call("play_event", "dungeon.defeat")
		return
	if int(audible.get("stress_delta", 0)) >= 6:
		audio_director.call("play_event", "dungeon.stress")
	elif kind == "card":
		audio_director.call("play_event", "dungeon.card")
	elif int(audible.get("damage", 0)) > 0 or int(audible.get("hp_delta", 0)) < 0:
		audio_director.call("play_event", "dungeon.impact")
	elif int(audible.get("block", 0)) > 0 or int(audible.get("enemy_block_delta", 0)) > 0:
		audio_director.call("play_event", "dungeon.guard")


func _show_inventory() -> void:
	state = ScreenState.INVENTORY
	_sync_state_views()
	_clear_screen()
	_apply_era_visuals()
	var page := VBoxContainer.new()
	page.name = "InventoryPage"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 16)
	screen_host.add_child(page)
	var narrow_layout := screen_host.size.x < 1040.0
	page.resized.connect(func() -> void:
		if state == ScreenState.INVENTORY and (screen_host.size.x < 1040.0) != narrow_layout:
			call_deferred("_refresh_screen_layout", ScreenState.INVENTORY)
	)
	page.add_child(_display_label("行囊与炼器", 30, Color("f0d99c"), HORIZONTAL_ALIGNMENT_CENTER))
	var notice_card := _panel(0.36, era_accent)
	notice_card.name = "InventoryNoticeCard"
	notice_card.custom_minimum_size.y = 54
	var notice := _label(inventory_notice, 14, Color(0.82, 0.85, 0.83),
		HORIZONTAL_ALIGNMENT_CENTER)
	notice.name = "InventoryNotice"
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice_card.add_child(notice)
	page.add_child(notice_card)
	var body: BoxContainer = VBoxContainer.new() if narrow_layout else HBoxContainer.new()
	body.name = "InventoryBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	if narrow_layout:
		var body_scroll := ScrollContainer.new()
		body_scroll.name = "InventoryBodyScroll"
		body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		body_scroll.follow_focus = true
		body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body_scroll.add_child(body)
		page.add_child(body_scroll)
	else:
		page.add_child(body)
	var inventory_panel := _build_inventory_list(not narrow_layout)
	var forge_panel := _build_forge_panel()
	if narrow_layout:
		forge_panel.custom_minimum_size = Vector2(0, 480)
	body.add_child(inventory_panel)
	body.add_child(forge_panel)
	var back_button := _button("返回山河", _show_game, true)
	back_button.name = "InventoryBackButton"
	page.add_child(back_button)


func _build_inventory_list(use_inner_scroll: bool = true) -> Control:
	var panel := _panel(0.84, era_accent)
	panel.name = "InventoryListPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(_section_title("所持器物"))
	var inventory: Dictionary = run_state.inventory
	var equipped: Dictionary = inventory.equipped
	var loadout := HBoxContainer.new()
	loadout.name = "InventoryLoadout"
	loadout.add_theme_constant_override("separation", 8)
	loadout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loadout.add_child(_inventory_loadout_card("兵器", _equipped_name(str(equipped.weapon_id)),
		Color("d49a62")))
	loadout.add_child(_inventory_loadout_card("护甲", _equipped_name(str(equipped.armor_id)),
		Color("69b1c5")))
	loadout.add_child(_inventory_loadout_card("灵物", _equipped_name(str(equipped.relic_id)),
		Color("b18bd0")))
	column.add_child(loadout)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	if use_inner_scroll:
		var scroll := ScrollContainer.new()
		scroll.name = "InventoryListScroll"
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(scroll)
		scroll.add_child(list)
	else:
		list.name = "InventoryNarrowList"
		column.add_child(list)
	for entry_value in inventory.items:
		var entry: Dictionary = entry_value
		var item_id := str(entry.item_id)
		var definition: Dictionary = ItemSystemScript.ITEMS.get(item_id, {})
		var category := str(entry.get("category", definition.get("category", "器物")))
		var item_card := _panel(0.28, _inventory_category_color(category))
		item_card.custom_minimum_size.y = 72
		var item_style := item_card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		item_style.content_margin_left = 12
		item_style.content_margin_right = 12
		item_style.content_margin_top = 8
		item_style.content_margin_bottom = 8
		item_style.shadow_size = 4
		item_card.add_theme_stylebox_override("panel", item_style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		item_card.add_child(row)
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_box)
		var name_text := "%s ×%d" % [ItemSystemScript.display_name(entry), int(entry.quantity)]
		text_box.add_child(_label(name_text, 16, Color(0.90, 0.89, 0.84)))
		var detail := _label(_inventory_item_detail(entry, definition), 13,
			Color(0.70, 0.77, 0.78))
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_box.add_child(detail)
		if str(definition.get("category", "")) == "consumable":
			var use_button := _button("服用", _use_inventory_item.bind(item_id), false, "", true)
			use_button.custom_minimum_size = Vector2(84, 46)
			row.add_child(use_button)
		elif definition.has("slot") or entry.has("slot"):
			var slot := str(entry.get("slot", definition.get("slot", "")))
			var is_equipped := str(equipped.get("%s_id" % slot, "")) == str(entry.instance_id)
			if is_equipped:
				var equipped_label := _label("已装备", 14, _inventory_category_color(category),
					HORIZONTAL_ALIGNMENT_CENTER)
				equipped_label.custom_minimum_size.x = 84
				equipped_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				row.add_child(equipped_label)
			else:
				var equip_button := _button("装备", _equip_inventory_item.bind(str(entry.instance_id)),
					false, "", true)
				equip_button.custom_minimum_size = Vector2(84, 46)
				row.add_child(equip_button)
		list.add_child(item_card)
	list.add_child(_divider())
	list.add_child(_section_title("材料"))
	var material_grid := GridContainer.new()
	material_grid.name = "InventoryMaterialGrid"
	material_grid.columns = 3
	material_grid.add_theme_constant_override("h_separation", 8)
	material_grid.add_theme_constant_override("v_separation", 8)
	for material_id in (inventory.materials as Dictionary).keys():
		var material_definition: Dictionary = ItemSystemScript.ITEMS.get(str(material_id), {})
		material_grid.add_child(_inventory_material_chip(str(material_definition.get("name", material_id)),
			int(inventory.materials[material_id])))
	if material_grid.get_child_count() > 0:
		list.add_child(material_grid)
	else:
		list.add_child(_label("炉中尚无材料。", 15, Color(0.73, 0.78, 0.78)))
	return panel


func _build_forge_panel() -> Control:
	var panel := _panel(0.84, era_accent)
	panel.name = "ForgePanel"
	panel.custom_minimum_size.x = 430
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	column.add_child(_section_title("当世炼器"))
	column.add_child(_label("灵石 %d · 造化道途 %d" % [int(player.spirit_stones),
		int((player.get("path", {}) as Dictionary).get("creation", 0))], 14,
		Color(0.74, 0.80, 0.80)))
	for recipe_id_value in ItemSystemScript.RECIPES.keys():
		var recipe_id := str(recipe_id_value)
		var recipe: Dictionary = ItemSystemScript.RECIPES[recipe_id]
		var cost_parts: Array[String] = []
		for material_id in (recipe.cost as Dictionary).keys():
			var material: Dictionary = ItemSystemScript.ITEMS.get(str(material_id), {})
			cost_parts.append("%s %d/%d" % [str(material.get("name", material_id)),
				ItemSystemScript.count(run_state, str(material_id)), int(recipe.cost[material_id])])
		cost_parts.append("灵石 %d/%d" % [int(player.spirit_stones), int(recipe.spirit_stones)])
		var readiness: Dictionary = ItemSystemScript.can_forge(run_state, recipe_id)
		var recipe_card := _panel(0.28, Color("67b98d") if bool(readiness.ok) else era_accent)
		recipe_card.custom_minimum_size.y = 96
		var recipe_style := recipe_card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		recipe_style.content_margin_left = 12
		recipe_style.content_margin_right = 12
		recipe_style.content_margin_top = 8
		recipe_style.content_margin_bottom = 8
		recipe_style.shadow_size = 4
		recipe_card.add_theme_stylebox_override("panel", recipe_style)
		var recipe_row := HBoxContainer.new()
		recipe_row.add_theme_constant_override("separation", 10)
		recipe_card.add_child(recipe_row)
		var recipe_text := VBoxContainer.new()
		recipe_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recipe_row.add_child(recipe_text)
		recipe_text.add_child(_label(str(recipe.name), 16, Color("eee4cc")))
		recipe_text.add_child(_label(_inventory_bonus_text(recipe.base_bonuses), 13,
			Color("d8bf79")))
		var cost_label := _label(" · ".join(cost_parts), 12,
			Color("83c4a4") if bool(readiness.ok) else Color(0.67, 0.70, 0.70))
		cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		recipe_text.add_child(cost_label)
		var button_text := "开炉炼制" if bool(readiness.ok) else _forge_blocked_label(str(readiness.code))
		var button := _button(button_text, _forge_inventory_item.bind(recipe_id), bool(readiness.ok),
			"", true)
		button.name = "ForgeRecipe_%s" % recipe_id
		button.custom_minimum_size = Vector2(100, 48)
		button.disabled = not bool(readiness.ok)
		if button.disabled:
			button.add_theme_color_override("font_disabled_color", Color(0.62, 0.66, 0.66))
			button.add_theme_stylebox_override("disabled", _button_style(0.08, era_accent, 0.18, true))
		button.tooltip_text = "补齐卡片中标出的材料与灵石后即可开炉。" if button.disabled else ""
		recipe_row.add_child(button)
		column.add_child(recipe_card)
	column.add_child(_label("品质由造化道途、当前境界与此世随机游标共同决定。道品虚痕佩可随轮回保留。",
		13, Color(0.72, 0.77, 0.78)))
	return panel


func _inventory_loadout_card(title: String, item_name: String, color: Color) -> PanelContainer:
	var card := _panel(0.26, color)
	card.custom_minimum_size.y = 60
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.shadow_size = 3
	card.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_child(_label(title, 12, Color(color, 0.86)))
	var name_label := _label(item_name, 14, Color(0.88, 0.88, 0.84),
		HORIZONTAL_ALIGNMENT_CENTER)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(name_label)
	card.add_child(column)
	return card


func _inventory_material_chip(material_name: String, count: int) -> PanelContainer:
	var chip := _panel(0.20, era_accent)
	chip.custom_minimum_size.y = 38
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := chip.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.shadow_size = 2
	chip.add_theme_stylebox_override("panel", style)
	chip.add_child(_label("%s ×%d" % [material_name, count], 13,
		Color(0.76, 0.81, 0.81), HORIZONTAL_ALIGNMENT_CENTER))
	return chip


func _inventory_item_detail(entry: Dictionary, definition: Dictionary) -> String:
	var category := str(entry.get("category", definition.get("category", "器物")))
	var category_name := str({
		"consumable":"丹药", "weapon":"兵器", "armor":"护甲", "relic":"灵物",
	}.get(category, "器物"))
	var description := str(definition.get("description", ""))
	var bonuses: Dictionary = entry.get("bonuses", definition.get("bonuses", {}))
	var bonus_text := _inventory_bonus_text(bonuses)
	var parts: Array[String] = [category_name]
	if not description.is_empty(): parts.append(description)
	if not bonus_text.is_empty(): parts.append(bonus_text)
	return " · ".join(parts)


func _inventory_bonus_text(bonuses: Dictionary) -> String:
	var stat_names := {"attack":"攻势", "defense":"护体", "max_hp":"气血", "max_mp":"灵力", "dao_heart":"道心"}
	var parts: Array[String] = []
	for stat_id in ["attack", "defense", "max_hp", "max_mp", "dao_heart"]:
		if int(bonuses.get(stat_id, 0)) != 0:
			parts.append("%s%+d" % [str(stat_names[stat_id]), int(bonuses[stat_id])])
	return "  ".join(parts)


func _inventory_category_color(category: String) -> Color:
	return {
		"consumable": Color("70b98b"), "weapon": Color("d49a62"),
		"armor": Color("69b1c5"), "relic": Color("b18bd0"),
	}.get(category, era_accent)


func _forge_blocked_label(code: String) -> String:
	return {
		"insufficient_spirit_stones":"灵石不足", "insufficient_material":"材料不足",
		"inventory_full":"行囊已满",
	}.get(code, "暂不可炼")


func _use_inventory_item(item_id: String) -> void:
	var result: Dictionary = ItemSystemScript.use_consumable(run_state, item_id)
	feedback = "你服下%s，药力已经进入此世经脉。" % str((ItemSystemScript.ITEMS[item_id] as Dictionary).name) \
		if bool(result.ok) else "此刻无法服用这件物品。"
	inventory_notice = feedback
	_sync_state_views()
	if bool(result.ok):
		_save_current_state("行囊变化已封存")
	_show_inventory()


func _equip_inventory_item(reference_id: String) -> void:
	var result: Dictionary = ItemSystemScript.equip(run_state, reference_id)
	feedback = "器物与气机完成共鸣。" if bool(result.ok) else "这件器物无法装备。"
	inventory_notice = feedback
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
	inventory_notice = feedback
	_sync_state_views()
	_show_inventory()


func _show_armory() -> void:
	state = ScreenState.ARMORY
	_sync_state_views()
	_clear_screen()
	_apply_era_visuals(MENU_SCENE)
	var page := VBoxContainer.new()
	page.name = "ArmoryPage"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 12)
	screen_host.add_child(page)
	page.add_child(_display_label("成就与轮回玉藏兵", 28, Color("f1d79a"), HORIZONTAL_ALIGNMENT_CENTER))
	var body := HBoxContainer.new()
	body.name = "ArmoryBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	page.add_child(body)
	body.add_child(_build_achievement_list())
	body.add_child(_build_jade_armory_list())
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	page.add_child(actions)
	var cycle_button := _button("切换下一件 [Y]", _cycle_jade_weapon, false)
	cycle_button.name = "ArmoryCycleButton"
	actions.add_child(cycle_button)
	var invoke_button := _button("玉兵显圣 [J]", _invoke_jade_weapon, true)
	invoke_button.name = "ArmoryInvokeButton"
	var current := AchievementSystemScript.current_weapon(run_state)
	invoke_button.disabled = current.is_empty() or int(current.get("charge", 0)) < 100
	invoke_button.tooltip_text = "显圣蓄能尚未达到100。" if invoke_button.disabled else "释放当前玉兵道法。"
	actions.add_child(invoke_button)
	var back_button := _button("返回山河", _show_game, false)
	back_button.name = "ArmoryBackButton"
	actions.add_child(back_button)


func _build_achievement_list() -> Control:
	var panel := _panel(0.84, era_accent)
	panel.name = "AchievementListPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var definitions: Dictionary = AchievementSystemScript.load_definitions()
	var achievement_total := (definitions.get("achievements", []) as Array).size()
	var achievement_count := AchievementSystemScript.unlocked_count(run_state)
	column.add_child(_section_title("轮回道痕"))
	var summary := _panel(0.28, _achievement_tier_color(2) if achievement_count >= 12 else era_accent)
	summary.name = "AchievementSummaryCard"
	summary.custom_minimum_size.y = 82
	var summary_style := summary.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	summary_style.content_margin_left = 12
	summary_style.content_margin_right = 12
	summary_style.content_margin_top = 8
	summary_style.content_margin_bottom = 8
	summary_style.shadow_size = 4
	summary.add_theme_stylebox_override("panel", summary_style)
	var summary_column := VBoxContainer.new()
	summary_column.add_theme_constant_override("separation", 4)
	summary.add_child(summary_column)
	var summary_row := HBoxContainer.new()
	var summary_title := _label("已铭刻 %d / %d" % [achievement_count, achievement_total], 17,
		Color("f2dfaa"))
	summary_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_row.add_child(summary_title)
	summary_row.add_child(_label("尚余 %d 道因果" % (achievement_total - achievement_count), 13,
		Color(0.70, 0.77, 0.78), HORIZONTAL_ALIGNMENT_RIGHT))
	summary_column.add_child(summary_row)
	summary_column.add_child(_progress_row("总体完成", achievement_count, achievement_total,
		_achievement_tier_color(2), "AchievementOverallProgress"))
	column.add_child(summary)
	var scroll := ScrollContainer.new()
	scroll.name = "AchievementListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 9)
	scroll.add_child(list)
	for value in (definitions.get("achievements", []) as Array):
		var achievement: Dictionary = value
		list.add_child(_build_achievement_card(achievement))
	return panel


func _build_achievement_card(achievement: Dictionary) -> PanelContainer:
	var progress: Dictionary = AchievementSystemScript.achievement_progress(run_state, achievement)
	var unlocked := bool(progress.unlocked)
	var tier := clampi(int(achievement.get("tier", 0)), 0, 2)
	var tier_color := _achievement_tier_color(tier)
	var card := _panel(0.31 if unlocked else 0.18, tier_color)
	card.name = "AchievementCard_%s" % str(achievement.id)
	card.custom_minimum_size.y = 116
	var card_style := card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	card_style.content_margin_left = 12
	card_style.content_margin_right = 12
	card_style.content_margin_top = 8
	card_style.content_margin_bottom = 8
	card_style.shadow_size = 4
	if not unlocked:
		card_style.border_color = Color(tier_color, 0.30)
	card.add_theme_stylebox_override("panel", card_style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	var status := _label("已铭刻" if unlocked else "行途中", 13,
		tier_color if unlocked else Color(0.64, 0.69, 0.70))
	status.custom_minimum_size.x = 48
	heading.add_child(status)
	var name_label := _label("[%s] %s" % [AchievementSystemScript.TIER_NAMES[tier],
		str(achievement.name)], 16, Color("f2e7cf") if unlocked else Color(0.76, 0.78, 0.76))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.add_child(name_label)
	var weapon_definition := AchievementSystemScript.weapon_definition(str(achievement.weapon_id))
	var reward := _label("玉兵 · %s" % str(weapon_definition.get("name", "未名玉兵")), 12,
		Color(tier_color, 0.92), HORIZONTAL_ALIGNMENT_RIGHT)
	reward.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.add_child(reward)
	column.add_child(heading)
	var description := _label(str(achievement.description), 13,
		Color(0.73, 0.78, 0.78) if not unlocked else Color(0.79, 0.82, 0.80))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = 2
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(description)
	column.add_child(_progress_row("达成进度", int(progress.current), int(progress.target),
		tier_color if unlocked else Color(0.54, 0.63, 0.66),
		"AchievementProgress_%s" % str(achievement.id)))
	return card


func _build_jade_armory_list() -> Control:
	var panel := _panel(0.84, Color("d5a957"))
	panel.name = "JadeArmoryPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	column.add_child(_section_title("轮回玉藏兵"))
	column.add_child(_build_current_jade_weapon_card())
	var collection_row := HBoxContainer.new()
	var unlocked_count := AchievementSystemScript.unlocked_count(run_state)
	var collection_title := _label("玉兵谱录", 15, Color("e9d29b"))
	collection_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_row.add_child(collection_title)
	collection_row.add_child(_label("已显化 %d / 16" % unlocked_count, 13,
		Color(0.70, 0.77, 0.78), HORIZONTAL_ALIGNMENT_RIGHT))
	column.add_child(collection_row)
	var scroll := ScrollContainer.new()
	scroll.name = "JadeArmoryScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var armory: Dictionary = run_state.legacy.armory
	var definitions: Dictionary = AchievementSystemScript.load_definitions()
	var achievement_by_weapon := {}
	for achievement_value in (definitions.get("achievements", []) as Array):
		var achievement: Dictionary = achievement_value
		achievement_by_weapon[str(achievement.weapon_id)] = achievement
	for value in (definitions.get("weapons", []) as Array):
		var definition: Dictionary = value
		list.add_child(_build_jade_weapon_card(definition, armory,
			achievement_by_weapon.get(str(definition.id), {})))
	return panel


func _build_current_jade_weapon_card() -> PanelContainer:
	var current := AchievementSystemScript.current_weapon(run_state)
	var tier := clampi(int(current.get("tier", 0)), 0, 2)
	var accent := _achievement_tier_color(tier) if not current.is_empty() else era_accent
	var card := _panel(0.34, accent)
	card.name = "ArmoryCurrentCard"
	card.custom_minimum_size.y = 168
	var card_style := card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	card_style.content_margin_left = 14
	card_style.content_margin_right = 14
	card_style.content_margin_top = 10
	card_style.content_margin_bottom = 10
	card_style.shadow_size = 6
	card.add_theme_stylebox_override("panel", card_style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	card.add_child(column)
	if current.is_empty():
		column.add_child(_label("本命玉兵尚未显化", 18, Color("e2d5b7"), HORIZONTAL_ALIGNMENT_CENTER))
		var empty_hint := _label("完成任一道轮回成就，黑白轮回玉便会显化第一件永久玉兵。", 14,
			Color(0.72, 0.78, 0.78), HORIZONTAL_ALIGNMENT_CENTER)
		empty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(empty_hint)
		return card
	var heading := HBoxContainer.new()
	var name_label := _label(str(current.name), 19, Color("f5e5bd"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(name_label)
	heading.add_child(_label("[%s] %s · %s" % [AchievementSystemScript.TIER_NAMES[tier],
		_jade_style_name(str(current.style)), str(current.stage_name)], 13, accent,
		HORIZONTAL_ALIGNMENT_RIGHT))
	column.add_child(heading)
	var description := _label(str(current.description), 13, Color(0.77, 0.81, 0.80))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = 2
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(description)
	var effective: Dictionary = AchievementSystemScript.effective_bonuses(run_state)
	column.add_child(_label("当前加成 · %s   ·   已显圣 %d 次" % [
		_jade_bonus_text(effective), int(current.invocations)], 13, Color("e4c878")))
	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 12)
	var stage := int(current.stage)
	var resonance_target := int(AchievementSystemScript.STAGE_THRESHOLDS[mini(stage + 1, 3)])
	var resonance_value := mini(int(current.resonance), resonance_target)
	var resonance_title := "共鸣 · 道化圆满" if stage >= 3 else "共鸣 · 至%s" % \
		AchievementSystemScript.stage_name(stage + 1)
	var resonance_progress := _progress_row(resonance_title, resonance_value, resonance_target,
		accent, "ArmoryResonanceProgress")
	resonance_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.add_child(resonance_progress)
	var charge_progress := _progress_row("显圣蓄能", int(current.charge), 100,
		Color("74c8d4"), "ArmoryChargeProgress")
	charge_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.add_child(charge_progress)
	column.add_child(progress_row)
	return card


func _build_jade_weapon_card(definition: Dictionary, armory: Dictionary,
		achievement: Dictionary) -> PanelContainer:
	var weapon_id := str(definition.id)
	var weapon: Dictionary = armory.weapons[weapon_id]
	var unlocked := bool(weapon.unlocked)
	var equipped := unlocked and str(armory.equipped_id) == weapon_id
	var tier := clampi(int(definition.tier), 0, 2)
	var tier_color := _achievement_tier_color(tier)
	var card := _panel(0.28 if unlocked else 0.15, tier_color)
	card.name = "JadeWeaponCard_%s" % weapon_id
	card.custom_minimum_size.y = 112
	var card_style := card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	card_style.content_margin_left = 12
	card_style.content_margin_right = 12
	card_style.content_margin_top = 8
	card_style.content_margin_bottom = 8
	card_style.shadow_size = 4
	if not unlocked:
		card_style.border_color = Color(tier_color, 0.24)
	card.add_theme_stylebox_override("panel", card_style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 3)
	row.add_child(text_box)
	var state_text := "已共鸣" if equipped else ("已显化" if unlocked else "未显化")
	text_box.add_child(_label("%s  [%s] %s · %s" % [state_text,
		AchievementSystemScript.TIER_NAMES[tier], str(definition.name),
		AchievementSystemScript.stage_name(int(weapon.stage)) if unlocked else _jade_style_name(str(definition.style))],
		15, tier_color if unlocked else Color(0.63, 0.66, 0.66)))
	var detail := _label(str(definition.description), 12,
		Color(0.72, 0.77, 0.77) if unlocked else Color(0.58, 0.62, 0.63))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.max_lines_visible = 2
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(detail)
	if unlocked:
		text_box.add_child(_label("%s · 基础 %s · 共鸣 %d" % [_jade_style_name(str(definition.style)),
			_jade_bonus_text(definition.bonuses), int(weapon.resonance)], 12, Color("d7be7c")))
		var button := _button("当前" if equipped else "装备", _equip_jade_weapon.bind(weapon_id),
			not equipped, "", true)
		button.name = "JadeWeaponButton_%s" % weapon_id
		button.custom_minimum_size = Vector2(82, 48)
		button.disabled = equipped
		if equipped:
			button.add_theme_color_override("font_disabled_color", Color("f0ddb0"))
			button.add_theme_stylebox_override("disabled", _button_style(0.30, tier_color, 0.78, true))
		row.add_child(button)
	else:
		var progress: Dictionary = AchievementSystemScript.achievement_progress(run_state, achievement)
		text_box.add_child(_label("解锁 · 成就「%s」 · %s" % [str(achievement.get("name", "未知道痕")),
			str(progress.get("label", "0 / 1"))], 12, Color(tier_color, 0.72)))
	return card


func _jade_style_name(style_id: String) -> String:
	return {"slaughter":"杀伐道", "guardian":"守御道", "insight":"问心道", "myriad":"万象道"}.get(
		style_id, "未定道")


func _jade_bonus_text(bonuses: Dictionary) -> String:
	var text_value := _inventory_bonus_text(bonuses)
	return text_value if not text_value.is_empty() else "暂无属性加成"


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
	column.add_child(_display_label(str(notice.get("name", "无名道痕")), 23, Color("fff4d6"), HORIZONTAL_ALIGNMENT_CENTER))
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
	# Surfaces establish hierarchy; era color is reserved for active states and headings.
	style.bg_color = Color(0.018, 0.030, 0.045, clampf(alpha, 0.62, 0.94))
	style.border_color = Color(0.28, 0.35, 0.39, 0.46)
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _dungeon_surface(accent: Color, emphasis: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.024, 0.035, 0.90 if emphasis else 0.82)
	style.border_color = Color(accent, 0.44 if emphasis else 0.26)
	style.set_border_width_all(1)
	style.border_width_top = 3 if emphasis else 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0, 0, 0, 0.48 if emphasis else 0.28)
	style.shadow_size = 10 if emphasis else 4
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _menu_feature_pill(text_value: String) -> PanelContainer:
	var pill := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(era_accent.darkened(0.72), 0.36)
	style.border_color = Color(era_accent, 0.38)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	pill.add_theme_stylebox_override("panel", style)
	pill.add_child(_label(text_value, 13, Color(0.82, 0.85, 0.82, 0.92),
		HORIZONTAL_ALIGNMENT_CENTER))
	return pill


func _button(text_value: String, callback: Callable, primary: bool,
		sound_event: String = "", compact: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 44 if compact else 50
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 15 if compact else 18)
	button.add_theme_color_override("font_color", Color("f4eee0"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	var normal := _button_style(0.18 if not primary else 0.31, era_accent, 0.44, compact)
	var hover := _button_style(0.34 if not primary else 0.48, era_accent, 0.92, compact)
	var pressed := _button_style(0.50, era_accent, 1.0, compact)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	if sound_event.is_empty():
		sound_event = "ui.cancel" if _is_cancel_action(text_value) else "ui.confirm"
	button.pressed.connect(_activate_button.bind(callback, sound_event))
	return button


func _activate_button(callback: Callable, sound_event: String) -> void:
	if is_instance_valid(audio_director):
		audio_director.call("play_event", sound_event)
	if callback.is_valid():
		callback.call()


func _is_cancel_action(text_value: String) -> bool:
	for marker in ["返回", "撤出", "脱战", "取消", "收回", "暂离", "关闭"]:
		if text_value.contains(marker):
			return true
	return false


func _button_style(alpha: float, accent: Color, border_alpha: float,
		compact: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var muted_accent := accent.lerp(Color("7b8589"), 0.62)
	style.bg_color = Color(accent.darkened(0.86), minf(alpha, 0.48))
	style.border_color = Color(muted_accent, minf(border_alpha, 0.58))
	style.set_border_width_all(1)
	style.border_width_left = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 9 if compact else 18
	style.content_margin_right = 9 if compact else 18
	style.content_margin_top = 7 if compact else 10
	style.content_margin_bottom = 7 if compact else 10
	return style


func _dungeon_card_style(accent: Color, state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var surface := Color(0.025, 0.043, 0.060, 0.97)
	match state:
		"hover":
			surface = Color(0.075, 0.125, 0.145, 0.98)
		"pressed":
			surface = Color(0.105, 0.145, 0.155, 0.99)
		"disabled":
			surface = Color(0.022, 0.032, 0.042, 0.95)
	style.bg_color = surface
	var border_mix := accent.lerp(Color("a8b1ad"), 0.30)
	var border_alpha := 0.82
	if state == "disabled":
		border_alpha = 0.36
	style.border_color = Color(border_mix, border_alpha)
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	style.shadow_size = 8 if state != "disabled" else 4
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _style_line_edit(edit: LineEdit) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.02, 0.035, 0.055, 0.92)
	normal.border_color = Color(era_accent, 0.64)
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
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
	var readable_color := color
	readable_color.a = maxf(readable_color.a, 0.84)
	label.add_theme_color_override("font_color", readable_color)
	label.horizontal_alignment = alignment
	return label


func _display_label(text_value: String, font_size: int, color: Color = Color.WHITE,
		alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := _label(text_value, font_size, color, alignment)
	label.theme_type_variation = "DisplayLabel"
	return label


func _section_title(text_value: String) -> Label:
	var label := _label(text_value, 20, Color(era_accent, 0.98))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.74))
	return label


func _progress_row(title: String, value: int, maximum: int, color: Color,
		node_name: String = "") -> Control:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	stack.add_child(_label("%s  %d / %d" % [title, value, maximum], 14,
		Color(0.84, 0.87, 0.87, 0.92)))
	var bar := ProgressBar.new()
	if not node_name.is_empty():
		bar.name = node_name
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
			if event.keycode == KEY_1:
				var input := screen_host.find_child("DaoNameInput", true, false) as LineEdit
				if input:
					_start_new_game(input)
			elif event.keycode == KEY_C:
				_continue_game()
			elif event.keycode == KEY_I:
				_import_legacy_game()
			elif event.keycode == KEY_O:
				_open_audio_settings()
		ScreenState.GAME:
			match event.keycode:
				KEY_I: _show_inventory()
				KEY_A: _show_armory()
				KEY_L: _show_journal()
				KEY_S: _manual_save()
				KEY_O: _open_audio_settings()
				KEY_ESCAPE: _return_to_menu()
		ScreenState.CULTIVATION:
			if event.keycode >= KEY_1 and event.keycode <= KEY_3:
				_resolve_meditation(str(CultivationScript.MEDITATION_MODE_IDS[int(event.keycode - KEY_1)]))
			elif event.keycode == KEY_ESCAPE:
				_show_game()
		ScreenState.OBJECTIVE:
			if event.keycode >= KEY_1 and event.keycode <= KEY_3:
				_select_objective(str(ObjectiveSystemScript.OBJECTIVE_IDS[int(event.keycode - KEY_1)]))
			elif event.keycode == KEY_ESCAPE:
				_show_game()
		ScreenState.EVENT:
			if event.keycode >= KEY_1 and event.keycode <= KEY_9:
				_resolve_choice(int(event.keycode - KEY_1))
			elif event.keycode == KEY_ESCAPE:
				feedback = "你暂时离开这段因果，但它没有真正结束。"
				current_event = {}
				_show_game()
		ScreenState.EVENT_RESULT:
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
				_continue_from_event_result()
			elif event.keycode == KEY_L:
				_show_journal()
		ScreenState.JOURNAL:
			if event.keycode in [KEY_ESCAPE, KEY_L]:
				_show_game()
		ScreenState.REINCARNATION:
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
				var input := screen_host.find_child("NextLifeNameInput", true, false) as LineEdit
				if input:
					_begin_next_life(input)
		ScreenState.INVENTORY:
			if event.keycode in [KEY_ESCAPE, KEY_I]:
				_show_game()
		ScreenState.ARMORY:
			match event.keycode:
				KEY_ESCAPE, KEY_A: _show_game()
				KEY_Y: _cycle_jade_weapon()
				KEY_J: _invoke_jade_weapon()
		ScreenState.COMBAT:
			var combat_log_overlay := screen_host.find_child("CombatLogOverlay", true, false)
			if is_instance_valid(combat_log_overlay):
				if event.keycode in [KEY_ESCAPE, KEY_L]:
					_close_combat_log_overlay()
				get_viewport().set_input_as_handled()
				return
			match event.keycode:
				KEY_1: _resolve_combat_technique_slot(0)
				KEY_2: _resolve_combat_technique_slot(1)
				KEY_3: _resolve_combat_technique_slot(2)
				KEY_4: _resolve_combat_action("pill")
				KEY_L: _open_combat_log_overlay()
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
		ScreenState.AUDIO_SETTINGS:
			if event.keycode in [KEY_ESCAPE, KEY_O]:
				_close_audio_settings()
