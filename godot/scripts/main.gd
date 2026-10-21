extends Control
## The only launcher is the independent 3D Ark scene. No legacy save is read.

const ARK_SCENE_PATH := "res://scenes/ark_greybox.tscn"
const SESSION_SAVE_ROOT_META := "ark_menu_save_root_override"
const SaveScript = preload("res://scripts/ark_greybox_save.gd")
const BODY_FONT = preload("res://art/fonts/ark_ui_font.tres")

@export var save_root_override := ""

var entering_ark := false
var enter_button: Button
var save_notice: Label
var menu_panel: PanelContainer
var menu_columns: GridContainer
var left_column: VBoxContainer
var right_column: VBoxContainer


func _ready() -> void:
	# A test or explicit session override must survive Ark -> menu -> Ark.
	# Normal launches have no metadata and retain the established save path.
	if save_root_override.is_empty():
		save_root_override = str(get_tree().get_meta(SESSION_SAVE_ROOT_META, ""))
	var menu_theme := Theme.new()
	menu_theme.default_font = BODY_FONT
	menu_theme.default_font_size = 20
	theme = menu_theme
	_build_menu()
	_refresh_save_notice()
	resized.connect(_fit_menu)
	_fit_menu()
	enter_button.grab_focus()
	print("ARK_MENU_READY_OK: 问道：归舟")


func _build_menu() -> void:
	var background := ColorRect.new()
	background.name = "ArkMenuBackground"
	background.color = Color("101d1d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var scroll := ScrollContainer.new()
	scroll.name = "ArkMenuScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var outer := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		outer.add_theme_constant_override("margin_" + side, 32)
	center.add_child(outer)

	menu_panel = PanelContainer.new()
	menu_panel.name = "ArkMenuPanel"
	menu_panel.add_theme_stylebox_override("panel", _panel_style(Color("1d2927"), Color("425c50"), 36))
	outer.add_child(menu_panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	menu_panel.add_child(body)
	menu_columns = GridContainer.new()
	menu_columns.name = "ArkMenuColumns"
	menu_columns.columns = 2
	menu_columns.add_theme_constant_override("h_separation", 48)
	menu_columns.add_theme_constant_override("v_separation", 32)
	body.add_child(menu_columns)

	left_column = VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 16)
	menu_columns.add_child(left_column)
	_label(left_column, "ArkMenuEyebrow", "海上生存 · 仙舟家园", 16, Color("9bb9aa"))
	_label(left_column, "ArkMenuTitle", "问道：归舟", 48, Color("f4e8ce"))
	_label(left_column, "ArkMenuSubtitle", "以舟为家，向海而行。", 24, Color("d5d9c8"))
	var summary := _label(left_column, "ArkMenuSummary", "从一叶木筏启程，拾取漂木、搭建住处。\n在连续的三维海域里探索、安居，与同行者共渡风雨。", 20, Color("b8c9be"))
	summary.custom_minimum_size.y = 94

	enter_button = Button.new()
	enter_button.name = "ArkEnterButton"
	enter_button.custom_minimum_size.y = 60
	enter_button.add_theme_font_size_override("font_size", 24)
	_style_button(enter_button, true)
	enter_button.pressed.connect(_enter_ark)
	left_column.add_child(enter_button)
	save_notice = _label(left_column, "ArkMenuSaveNotice", "", 16, Color("a6b8ac"))
	save_notice.custom_minimum_size.y = 56
	var quit_button := Button.new()
	quit_button.name = "ArkQuitButton"
	quit_button.text = "退出游戏"
	quit_button.custom_minimum_size.y = 44
	_style_button(quit_button, false)
	quit_button.pressed.connect(_quit_game)
	left_column.add_child(quit_button)

	right_column = VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 18)
	menu_columns.add_child(right_column)
	_label(right_column, "ArkMenuControlsTitle", "初次登舟", 24, Color("e4d7b6"))
	_control_hint("行动", "W A S D  移动　 ·　 空格  跳跃\nE  与身旁物件、居民互动")
	_control_hint("安居", "B  开始建造　 ·　 左键  放置\nF  调整已建物件　 ·　 R  旋转调整预览\n右键 / Esc  取消建造或调整")
	_control_hint("远行", "M  打开 / 关闭海图\nQ  近身应对礁兽　 ·　 T  等待时段")
	_control_hint("保存与归返", "F5  手动保存\n左侧面板“保存并返回主菜单”可安全离开")

	var divider := HSeparator.new()
	divider.add_theme_color_override("color", Color("425c50"))
	body.add_child(divider)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 20)
	body.add_child(footer)
	var version_label := _label(footer, "ArkMenuVersion", "版本 " + str(ProjectSettings.get_setting("application/config/version", "")), 16, Color("9bb9aa"))
	version_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var footer_note := _label(footer, "ArkMenuFooter", "三维原型 · 一个持续的海上家园 · 进入或继续均不会重置进度", 16, Color("9bb9aa"))
	footer_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _label(parent: Node, node_name: String, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _control_hint(heading: String, description: String) -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 6)
	right_column.add_child(group)
	_label(group, "Heading", heading, 18, Color("8cbea6"))
	_label(group, "Description", description, 18, Color("c8d0c0"))


func _panel_style(fill: Color, border: Color, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style


func _style_button(button: Button, primary: bool) -> void:
	button.add_theme_stylebox_override("normal", _panel_style(Color("366451") if primary else Color("24362f"), Color("67987a") if primary else Color("425c50"), 8))
	button.add_theme_stylebox_override("hover", _panel_style(Color("457b62"), Color("a0c7a2"), 8))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("284f40"), Color("b9d3ae"), 8))
	var focus := _panel_style(Color(0, 0, 0, 0), Color("d7cd9f"), 8)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", Color("f1ead6"))
	button.add_theme_color_override("font_hover_color", Color("ffffff"))
	button.add_theme_color_override("font_focus_color", Color("ffffff"))


func _fit_menu() -> void:
	if menu_panel == null:
		return
	var available_width := maxf(240.0, size.x - 64.0)
	var panel_width := minf(1120.0, available_width)
	menu_panel.custom_minimum_size.x = panel_width
	menu_columns.columns = 2 if panel_width >= 960.0 else 1
	var content_width := panel_width - 72.0
	left_column.custom_minimum_size.x = (content_width - 48.0) * 0.54 if menu_columns.columns == 2 else content_width
	right_column.custom_minimum_size.x = (content_width - 48.0) * 0.46 if menu_columns.columns == 2 else content_width


func _refresh_save_notice() -> void:
	var service := SaveScript.new(save_root_override)
	var save_path: String = service.get_save_path()
	# Merely visiting the menu must neither repair nor write an existing save.
	var has_save := FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".backup")
	enter_button.text = "继续归舟" if has_save else "进入归舟"
	save_notice.text = "继续现有的独立存档；进入后自动读取进度。" if has_save else "首次登舟将从木筏启程，进度独立保存。"
	save_notice.text += "\n返回主菜单前会保存；也可按 F5 手动保存。"


func _enter_ark() -> void:
	if entering_ark:
		return
	entering_ark = true
	enter_button.disabled = true
	_open_ark_scene.call_deferred()


func _open_ark_scene() -> void:
	var scene := load(ARK_SCENE_PATH) as PackedScene
	if scene == null:
		entering_ark = false
		enter_button.disabled = false
		save_notice.text = "归舟场景暂时无法载入。现有进度未更改，请重试。"
		return
	var game := scene.instantiate()
	game.set("save_root_override", save_root_override)
	var tree := get_tree()
	if save_root_override.is_empty():
		if tree.has_meta(SESSION_SAVE_ROOT_META):
			tree.remove_meta(SESSION_SAVE_ROOT_META)
	else:
		tree.set_meta(SESSION_SAVE_ROOT_META, save_root_override)
	# Set the override before _ready creates the save service. A plain
	# change_scene_to_file cannot forward an injected root to the new instance.
	tree.root.add_child(game)
	tree.current_scene = game
	queue_free()


func _quit_game() -> void:
	get_tree().quit()
