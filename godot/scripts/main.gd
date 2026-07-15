extends Control

const AmbientLayerScript = preload("res://scripts/ambient_layer.gd")
const DaoCompassScript = preload("res://scripts/dao_compass.gd")
const SaveServiceScript = preload("res://scripts/save_service.gd")

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

enum ScreenState { MENU, GAME, EVENT }

var state: ScreenState = ScreenState.MENU
var current_era: String = "古典修仙纪"
var current_event: Dictionary = {}
var events: Array = []
var recent_memories: Array[String] = []
var feedback: String = "旧玉仍温，今生尚未落笔。"
var save_notice: String = "尚未封存"
var menu_notice: String = ""

var player: Dictionary = DEFAULT_PLAYER.duplicate(true)
var save_service: RefCounted = SaveServiceScript.new()

var background: TextureRect
var vignette: ColorRect
var ambient: Control
var screen_host: MarginContainer
var animated_portrait: TextureRect
var background_time: float = 0.0
var era_accent: Color = Color("e4be4c")
var base_theme: Theme


func _ready() -> void:
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
	var payload := FileAccess.get_file_as_string(EVENTS_PATH)
	var parsed = JSON.parse_string(payload)
	if parsed is Array:
		events = parsed
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
	var save_status := menu_notice if not menu_notice.is_empty() else str(save_probe.get("message", ""))
	column.add_child(_label(save_status, 14,
		Color("e9c67a") if not can_continue and save_probe.get("code", "") == "corrupt_save" else Color(0.72, 0.76, 0.78, 0.84),
		HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_label("Enter 开始新生  ·  C 续接旧档", 14,
		Color(0.72, 0.76, 0.78, 0.78), HORIZONTAL_ALIGNMENT_CENTER))
	name_input.grab_focus()


func _start_new_game(name_input: LineEdit) -> void:
	var dao_name := name_input.text.strip_edges()
	if dao_name.is_empty():
		dao_name = "无名客"
	player = DEFAULT_PLAYER.duplicate(true)
	player.name = dao_name.left(16)
	current_era = "古典修仙纪"
	feedback = "镜湖古门在你写下道号的那一刻开启。"
	recent_memories = ["测灵台没有记下识海中的空阙。", "黑白旧玉在掌心第一次发热。"]
	menu_notice = ""
	_save_current_state("新生命途已立档")
	_show_game()


func _continue_game() -> void:
	var load_result: Dictionary = save_service.call("load_game")
	if not bool(load_result.get("ok", false)):
		menu_notice = str(load_result.get("message", "旧档无法读取。"))
		_show_menu()
		return
	var loaded_state: Dictionary = load_result.get("state", {})
	var loaded_era := str(loaded_state.get("current_era", ""))
	if not ERA_ORDER.has(loaded_era):
		menu_notice = "旧档记载了当前版本不认识的时代，未载入任何状态。"
		_show_menu()
		return
	current_era = loaded_era
	player = (loaded_state.get("player", DEFAULT_PLAYER) as Dictionary).duplicate(true)
	recent_memories.clear()
	recent_memories.assign(loaded_state.get("recent_memories", []))
	feedback = str(loaded_state.get("feedback", "旧玉从沉眠中醒来。"))
	save_notice = str(load_result.get("message", "旧玉已续接上一次命途。"))
	menu_notice = ""
	current_event = {}
	_show_game()


func _show_game() -> void:
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
	var footer_text := _label("[1] 修炼   [2] 历练   [3] 突破   [Tab] 时代观测   [S] 保存   [Esc] 返回题签",
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
	title_box.add_child(_label("%s · 世界第 %d 年" % [current_era, int(player.age) - 15], 15,
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
	column.add_child(_progress_row("修为", int(player.exp), 100, era_accent))
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
		int(player.age), int(player.lifespan), int(player.spirit_stones), int(player.pills)],
		15, Color(0.72, 0.78, 0.80, 0.90), HORIZONTAL_ALIGNMENT_CENTER))
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
		for memory in recent_memories.slice(max(0, recent_memories.size() - 5)):
			memory_lines += "- %s\n" % memory
	return "[color=#%s][font_size=22][b]%s[/b][/font_size][/color]\n\n%s\n\n" % [
		era_accent.to_html(false), current_era, era_line] + \
		"[color=#d9c98f][b]眼前要事[/b][/color]\n" + \
		"在寿元耗尽前推进境界，也别让每次选择只剩数值。因果、道心和人情会改变命途罗盘。\n\n" + \
		"[color=#d9c98f][b]旧玉近录[/b][/color]\n" + memory_lines + \
		"\n[color=#8fbfb7][b]迁移状态[/b][/color]\n" + \
		"Godot 主版本已接管界面、动态背景、事件与可靠存档；世界系统和本地 AI 将在同一运行时中继续扩展。"


func _meditate() -> void:
	var gain := 28 + int(player.roots.reduce(func(total, value): return total + int(value), 0)) / 5
	player.exp = min(140, int(player.exp) + gain)
	player.mp = min(int(player.max_mp), int(player.mp) + 5)
	player.age = int(player.age) + 1
	feedback = "你在%s的灵机中运转周天，修为 +%d。" % [current_era, gain]
	_add_memory("第%d年，你在%s打坐，命途罗盘的%s位微微发亮。" % [
		int(player.age) - 15, current_era, ["火", "水", "木", "金", "土"][randi() % 5]])
	_save_current_state("周天已自动封存")
	_show_game()


func _breakthrough() -> void:
	if int(player.exp) < 100:
		feedback = "修为尚差 %d，瓶颈没有真正显形。" % (100 - int(player.exp))
	else:
		player.exp = int(player.exp) - 100
		player.level = int(player.level) + 1
		player.max_hp = int(player.max_hp) + 12
		player.hp = int(player.max_hp)
		player.dao_heart = int(player.dao_heart) + 2
		feedback = "旧玉映出五道流光，你踏入凡人 %d 层。" % int(player.level)
		_add_memory("一次突破改变了五行流向，道心更稳。")
		_save_current_state("突破已自动封存")
	_show_game()


func _open_adventure() -> void:
	var candidates: Array = events.filter(func(event_data): return str(event_data.get("era", "")) == current_era)
	if candidates.is_empty():
		candidates = events
	if candidates.is_empty():
		feedback = "事件数据尚未显形。"
		_show_game()
		return
	current_event = candidates.pick_random()
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
		var choice_button := _button("%d  %s\n     %s" % [index + 1, str(choice.get("text", "沉默")), delta_hint],
			_resolve_choice.bind(index), false)
		choice_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choice_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice_button.custom_minimum_size.y = 88
		column.add_child(choice_button)
	return panel


func _resolve_choice(index: int) -> void:
	var choices: Array = current_event.get("choices", [])
	if index < 0 or index >= choices.size():
		return
	var choice: Dictionary = choices[index]
	var deltas: Dictionary = choice.get("deltas", {})
	for key in deltas.keys():
		if player.has(key):
			player[key] = int(player[key]) + int(deltas[key])
	player.hp = clamp(int(player.hp), 0, int(player.max_hp))
	player.exp = max(0, int(player.exp))
	feedback = str(choice.get("outcome", "因果落定，旧玉没有给出解释。"))
	_add_memory("%s：%s" % [str(current_event.get("title", "无名事件")), str(choice.get("text", "沉默"))])
	current_event = {}
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


func _cycle_era() -> void:
	var index := ERA_ORDER.find(current_era)
	current_era = ERA_ORDER[(index + 1) % ERA_ORDER.size()]
	feedback = "天机镜越过一层纪元尘埃：%s正在覆盖旧日山河。" % current_era
	_add_memory("旧玉观测到%s的一段可能未来。" % current_era)
	_save_current_state("纪元变化已自动封存")
	_show_game()


func _manual_save() -> void:
	_save_current_state("手动封存")
	_show_game()


func _save_current_state(reason: String) -> bool:
	var snapshot := {
		"current_era": current_era,
		"player": player.duplicate(true),
		"recent_memories": recent_memories.duplicate(),
		"feedback": feedback,
	}
	var save_result: Dictionary = save_service.call("save_game", snapshot)
	if bool(save_result.get("ok", false)):
		save_notice = "%s · %s" % [reason, str(save_result.get("message", "已保存"))]
		return true
	save_notice = "保存失败 · %s" % str(save_result.get("message", "未知原因"))
	return false


func _add_memory(text: String) -> void:
	recent_memories.append(text)
	while recent_memories.size() > 12:
		recent_memories.pop_front()


func _local_model_ready() -> bool:
	var root := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	return FileAccess.file_exists(root.path_join("ai_engine/models/gemma-4-E4B_q4_0-it.gguf"))


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
		ScreenState.GAME:
			match event.keycode:
				KEY_1: _meditate()
				KEY_2: _open_adventure()
				KEY_3: _breakthrough()
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
