extends VBoxContainer
## Read-only help presentation. Tabs and disclosure never issue game actions.
const HomeDetails = preload("res://scripts/presentation/ark_home_details_view.gd")
const Type = preload("res://scripts/presentation/ark_ui_type.gd")
const INK := Color("13272c")
const TEXT := Color("e8e3d3")
const MUTED := Color("b7b8a8")
const COPPER := Color("b69a6f")
const CYAN := Color("d1bf8f")
const SECTIONS := [
	["行动", "WASD 行走 / 游泳 · Shift 快跑\nSpace 跳跃 / 蹬水 · Q 近身反击\nE 互动 · B 背包 · V 营造\n非营造：右键拖转 · 滚轮缩放 · Home 回正\nF5 存档 · NPC 对话按屏上提示选择"],
	["物品", "B 背包 · 箱边 E 直接开箱\n左键整组 · 右键1个 · 也可拖到对侧\n拖动时尚未扣物；Esc 或放回原侧可取消\n箱子装满时，只转入能容纳的数量\n本舟储箱可直接供建造木料，不必先取回"],
	["营造", "V 逐件建造 · 左键确认 · 右键 / Esc 取消\n靠近储物箱 / 工作台按 F 搬移\n搬移预览中 R 旋转，不消耗材料\n营造中要开箱：先 Esc 退出，再到箱边按 E\n模板与蓝图：切换到家园管理"],
	["航行", "船尾舵位 E 掌舵\nW/S 前后航行 · A/D 转舵\nE 或 Esc 停航，恢复步行与游泳\nM 潮痕图：查看方向，不会直接传送\n风雨中也可航行；留意浪势与船况\n筏舷受损须先修补，也可停船避雨"],
	["风雨", "备雨：左侧筏舷中段 / 棚入口左柱\n按住 E 0.7 秒系唯一好绳；另一处不会加固\n雨后：船艏裂口 / 棚入口左柱，按住 E 修补\n每处 1 木，先随身再本舟储箱；松开或离开取消\nT 等待；非搬移预览时 R 推进天气\n每3分钟自动换时段；清晨补回采空的漂木 / 潮贝，不叠加库存。"],
	["钓鱼", "停船后到右舷钓竿旁按 E 抛竿\n先松开 E；浮漂下沉时再按 E 提竿\n按住 E 收线，松开降张力；勿绷断或松空\n鱼猛挣与风浪会拉紧线，及时缓一缓\nEsc 收竿；F5 收竿后保存，不恢复未完钓局\n鲜鱼可存箱；取回后到火盆做汤（1鱼→1热汤）\n工作台 E 制作鱼竿；B 选随身钓竿，再点「装备」"]
]
signal mode_changed(title: String)
var navigation: HBoxContainer
var controls: RichTextLabel
var tabs: Array[Button] = []
var details_toggle: Button
var details: Label
var stats_view: VBoxContainer
var actions: VBoxContainer
var more: VBoxContainer
var more_toggle: Button
var selected := 0

func setup(font: Font, status_details: Label) -> void:
	name = "ArkPlayerGuide"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	var guide_theme := Theme.new()
	guide_theme.default_font = Type.face(400)
	guide_theme.default_font_size = 16
	theme = guide_theme
	navigation = HBoxContainer.new()
	navigation.name = "ArkHelpCategories"
	navigation.theme = guide_theme
	var row := navigation
	row.add_theme_constant_override("separation", 0)
	add_child(row)
	for i in range(SECTIONS.size()):
		var button := _quiet_button(SECTIONS[i][0])
		button.name = "ArkHelpTab" + str(i)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.pressed.connect(select_section.bind(i))
		row.add_child(button)
		tabs.append(button)
	controls = RichTextLabel.new()
	controls.bbcode_enabled = true
	controls.add_theme_font_override("normal_font", Type.face(400))
	controls.add_theme_font_override("bold_font", Type.face(600))
	controls.fit_content = true
	controls.scroll_active = false
	controls.selection_enabled = false
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_font_size_override("normal_font_size", 16)
	controls.add_theme_color_override("default_color", TEXT)
	controls.name = "ArkControlsHelp"
	controls.add_theme_constant_override("line_separation", 1)
	add_child(controls)
	more_toggle = _quiet_button("家园详情与管理  ›")
	more_toggle.name = "ArkHelpMoreButton"
	more_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	more_toggle.toggle_mode = true
	more_toggle.add_theme_font_size_override("font_size", 14)
	more_toggle.toggled.connect(_show_more)
	add_child(more_toggle)
	more = VBoxContainer.new()
	more.name = "ArkHelpMoreContent"
	more.add_theme_constant_override("separation", 6)
	add_child(more)
	details_toggle = _quiet_button("家园详情  ›")
	details_toggle.name = "ArkHelpDetailsToggle"
	details_toggle.toggle_mode = true
	details_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	details_toggle.toggled.connect(_show_details)
	more.add_child(details_toggle)
	details = status_details
	details.add_theme_font_override("font", Type.face(400))
	details.add_theme_font_size_override("font_size", 15)
	more.add_child(details)
	details.visible = false
	stats_view = HomeDetails.new()
	stats_view.attach(details, more)
	actions = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	more.add_child(actions)
	_show_more(false)
	_show_details(false)
	select_section(0)

func select_section(index: int) -> void:
	if index < 0 or index >= SECTIONS.size(): return
	selected = index
	controls.text = _formatted_section(index)
	_show_more(false)
	for i in range(tabs.size()):
		tabs[i].set_pressed_no_signal(i == index)
		tabs[i].add_theme_font_override("font", Type.face(600 if i == index else 400))

func _show_more(expanded: bool) -> void:
	more.visible = expanded
	controls.visible = not expanded
	more_toggle.set_pressed_no_signal(expanded)
	for i in tabs.size():
		tabs[i].set_pressed_no_signal(not expanded and i == selected)
		tabs[i].add_theme_font_override("font", Type.face(600 if not expanded and i == selected else 400))
	more_toggle.text = "返回操作速查  ‹" if expanded else "家园管理  ›"
	if expanded: _show_details(false)
	mode_changed.emit("家园管理" if expanded else "操作速查")

func _show_details(expanded: bool) -> void:
	details.visible = false
	stats_view.visible = expanded
	stats_view.refresh()
	details_toggle.set_pressed_no_signal(expanded)
	details_toggle.text = "收起家园详情  ‹" if expanded else "家园详情  ›"

func _formatted_section(index: int) -> String:
	# All original rule text is rendered by this actual body, never a hidden
	# compatibility label. Only emphasis changes; parsed text stays verbatim.
	var key_pattern := RegEx.new()
	key_pattern.compile("(?<![A-Za-z])(WASD|Shift|Space|Home|Esc|F5|W/S|A/D|E|B|V|F|R|T|M|Q)(?![A-Za-z0-9])")
	var primary_rows := [[0,1,2],[0,1],[0,1,2],[0,1,2,3],[0,1,2],[0,1,2]]
	var action_pattern := RegEx.new()
	action_pattern.compile("按住|先松开|松开|再按|提竿|收线|抛竿|行走|游泳|快跑|跳跃|互动|背包|确认|取消|搬移|旋转|掌舵|停航|修补|系唯一好绳")
	var rendered := PackedStringArray()
	var lines: PackedStringArray = str(SECTIONS[index][1]).split("\n")
	for i in lines.size():
		var line := action_pattern.sub(lines[i], "[b]$0[/b]", true)
		line = key_pattern.sub(line,"[color=#d1bf8f][b]$0[/b][/color]",true)
		if i in primary_rows[index]:
			rendered.append("[font_size=16][color=#e8e3d3]"+line+"[/color][/font_size]")
		else:
			rendered.append("[font_size=15][color=#b7b8a8]"+line+"[/color][/font_size]")
	return "\n".join(rendered)

func _quiet_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", Type.face(500))
	button.focus_mode = Control.FOCUS_NONE
	button.set_meta("quiet_help", true)
	button.custom_minimum_size.y = 30
	var plain := StyleBoxFlat.new()
	plain.bg_color = Color.TRANSPARENT
	plain.content_margin_left = 8
	plain.content_margin_right = 8
	plain.content_margin_top = 4
	plain.content_margin_bottom = 5
	var selected_style := plain.duplicate() as StyleBoxFlat
	selected_style.border_color = COPPER
	selected_style.bg_color = Color("344036")
	selected_style.border_width_bottom = 2
	button.add_theme_stylebox_override("normal", plain)
	var hover_style := plain.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color("303b33")
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", selected_style)
	button.add_theme_color_override("font_color", MUTED)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)
	return button

func _label(points: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	return label
