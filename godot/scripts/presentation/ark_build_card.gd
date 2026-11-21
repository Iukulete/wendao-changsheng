extends Control
## Presentation-only construction card. Receives current, read-only game facts.
const Inventory = preload("res://scripts/presentation/ark_inventory_panel.gd")
const INK := Color("13272c")
const TEXT := Color("e7e6d9")
const MUTED := Color("9db5b2")
const COPPER := Color("b69a6f")
const CYAN := Color("9dd1c3")
const AMBER := Color("e5bb83")
var title: Label
var caption: Label
var status: Label
var next_step: Label
var notice: Label
var keys: Label
var source: Label
var wood_cost: Label
var extra_cost: Label
var wood_icon: Control
var extra_icon: Control
var crest: Control
var chip: Label
var model := {}
var _chip_point := Vector2.ZERO
var _has_chip := false
var _has_attachment_target := false
var _attachment_point := Vector2.ZERO
var _preview_id := 0
var _last_message := ""
var _last_position := Vector3.ZERO
var _notice := ""

func setup(font: Font) -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var theme_ := Theme.new(); theme_.default_font = font; theme_.default_font_size = 15; theme = theme_
	caption = _label(12, COPPER); caption.text = "仙舟营造  /  选址预览"
	title = _label(21, TEXT)
	status = _label(15, AMBER); status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	next_step = _label(15, TEXT); next_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice = _label(13, MUTED); notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.max_lines_visible = 3; notice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	wood_cost = _label(16, TEXT); extra_cost = _label(16, TEXT)
	source = _label(13, MUTED)
	keys = _label(13, MUTED)
	crest = _glyph("crest", 1)
	wood_icon = _glyph("wood", 1); extra_icon = _glyph("keel_beams", 1)
	chip = _label(13, AMBER)
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var style := StyleBoxFlat.new(); style.bg_color = Color("172b2e"); style.border_color = Color("776b52")
	style.set_border_width_all(1); style.set_corner_radius_all(3); style.content_margin_left = 10; style.content_margin_right = 10; style.content_margin_top = 5; style.content_margin_bottom = 5
	chip.add_theme_stylebox_override("normal", style)

func _label(points: int, color: Color) -> Label:
	var label := Label.new(); label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", points); label.add_theme_color_override("font_color", color)
	add_child(label); return label

func _glyph(resource: String, count: int) -> Control:
	var glyph := Inventory.InventoryGlyph.new(); glyph.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(glyph); glyph.show_resource(resource, count); return glyph

func present(state: Dictionary) -> void:
	model = state
	if model.is_empty():
		_preview_id = 0; _last_message = ""; _notice = ""; _has_attachment_target = false; hide(); return
	if int(model.preview_id) != _preview_id:
		_preview_id = int(model.preview_id); _last_message = str(model.message); _notice = ""
	elif not model.editing:
		if str(model.message) != _last_message: _notice = "" if str(model.message) in [str(model.detail), str(model.save_warning)] else str(model.message)
		elif model.position != _last_position: _notice = ""
	_last_message = str(model.message); _last_position = model.position
	title.text = ("布置 · " if model.editing else "") + str(model.title)
	status.text = ("◇  " if model.valid else "!  ") + str(model.status)
	status.add_theme_color_override("font_color", CYAN if model.valid else AMBER)
	next_step.text = str(model.next)
	notice.text = "最新说明 · " + _notice
	notice.visible = not _notice.is_empty()
	wood_cost.text = "无需材料" if model.editing else "木料  × %d" % int(model.wood_cost)
	wood_cost.add_theme_color_override("font_color", AMBER if int(model.wood_carried)+int(model.wood_stored)<int(model.wood_cost) else TEXT)
	extra_icon.visible = not str(model.extra).is_empty()
	extra_cost.visible = extra_icon.visible
	if extra_icon.visible:
		extra_icon.show_resource(str(model.extra), int(model.extra_owned))
		extra_cost.text = ("龙骨" if model.extra == "keel_beams" else "舱骨") + "  × %d   /  持有 %d" % [model.extra_cost, model.extra_owned]
		extra_cost.add_theme_color_override("font_color", AMBER if model.extra_owned < model.extra_cost else TEXT)
	wood_icon.visible = not model.editing
	source.text = "原物件搬移 · 不扣木料 · %d°" % (int(model.turns)*90) if model.editing else "随身 %d + 本舟箱 %d  ·  先用随身" % [model.wood_carried, model.wood_stored]
	keys.text = ("左键 确认布置   R 旋转" if model.editing else "左键 确认建造") + "     右键 / Esc 取消"
	if not model.valid: keys.text = ("R 旋转    " if model.editing else "") + "暂不可确认     右键 / Esc 退出预览"
	queue_redraw()

func arrange(screen: Vector2, camera: Camera3D, blocked_rects: Array[Rect2], _save_visible: bool) -> void:
	# A restrained right-hand drafting card, below the central boat/ghost.
	var compact := screen.x <= 1000
	var width := minf(480.0 if compact else 540.0, screen.x - 48.0)
	var text_width := width - 48.0
	var measured := theme.default_font.get_multiline_string_size(next_step.text,HORIZONTAL_ALIGNMENT_LEFT,text_width,15).y
	next_step.size.x = text_width
	var text_height := maxf(28.0,maxf(ceilf(measured)+8.0,next_step.get_minimum_size().y))
	var body_y := 116.0 if compact else 143.0
	notice.size.x = text_width
	var notice_height := maxf(notice.get_minimum_size().y, minf(ceilf(theme.default_font.get_multiline_string_size(notice.text,HORIZONTAL_ALIGNMENT_LEFT,text_width,13).y)+8.0,notice.get_line_height()*3.0+8.0)) if notice.visible else 0.0
	var keys_y := body_y + text_height + notice_height + 7.0
	var height := maxf(180.0 if compact else 210.0,keys_y+26.0)
	size = Vector2(width, height)
	position = Vector2(screen.x-width-24, screen.y-height-40.0)
	caption.position = Vector2(68,11 if compact else 15); caption.size = Vector2(width-90,18)
	crest.position = Vector2(18,14); crest.size = Vector2(40,40)
	title.position = Vector2(68,29 if compact else 34); title.size = Vector2(width-230,32)
	status.position = Vector2(width-208,35 if compact else 40); status.size = Vector2(184,24)
	wood_icon.position = Vector2(22,60 if compact else 76); wood_icon.size = Vector2(32,32)
	wood_cost.position = Vector2(62,62 if compact else 78); wood_cost.size = Vector2(145,26)
	extra_icon.position = Vector2(201,60 if compact else 76); extra_icon.size = Vector2(32,32)
	extra_cost.position = Vector2(239,62 if compact else 78); extra_cost.size = Vector2(width-257,26)
	source.position = Vector2(24,91 if compact else 112); source.size = Vector2(width-48,21)
	next_step.position = Vector2(24,body_y); next_step.size = Vector2(text_width,text_height)
	notice.position = Vector2(24,body_y+text_height); notice.size = Vector2(text_width,notice_height)
	keys.position = Vector2(24,keys_y); keys.size = Vector2(width-48,20)
	_arrange_attachment_target(screen, camera, blocked_rects)
	_has_chip = false; chip.hide()
	queue_redraw()

## A neutral aiming cue, never a validity signal or an input/snap override.
func _arrange_attachment_target(screen: Vector2, camera: Camera3D, blocked_rects: Array[Rect2]) -> void:
	_has_attachment_target = false
	var anchor: Variant = model.get("attachment_anchor")
	if not is_visible_in_tree() or camera == null or not anchor is Vector3: return
	if not anchor.is_finite() or camera.is_position_behind(anchor): return
	var point := camera.unproject_position(anchor)
	if not point.is_finite(): return
	var bounds := Rect2(point - Vector2(9,9), Vector2(18,18))
	if not Rect2(Vector2.ZERO,screen).encloses(bounds) or get_global_rect().intersects(bounds): return
	for obstacle in blocked_rects:
		if obstacle.intersects(bounds): return
	_attachment_point = point-position
	_has_attachment_target = true

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO,size)
	draw_style_box(_box(Color(0,0,0,.28),Color.TRANSPARENT,4),Rect2(Vector2(3,5),size))
	draw_style_box(_box(INK,Color("536b68"),4),rect)
	draw_style_box(_box(Color("1d3438"),Color.TRANSPARENT,3),Rect2(Vector2(2,2),Vector2(size.x-4,55 if size.x<=480 else 65)))
	# Copper joinery, not a full gold frame. A narrow warm inlay anchors the title.
	draw_rect(Rect2(18,56 if size.x<=480 else 66,size.x-36,1), Color("665b48"))
	draw_rect(Rect2(18,next_step.position.y-7,size.x-36,1), Color("36514f"))
	for x in [5.0,size.x-17.0]:
		for y in [5.0,size.y-17.0]:
			draw_line(Vector2(x,y),Vector2(x+12,y),COPPER,1); draw_line(Vector2(x,y),Vector2(x,y+12),COPPER,1)
	if _has_chip: draw_line(chip.position+Vector2(chip.size.x/2,chip.size.y),_chip_point,Color(.64,.72,.66,.55),1)
	if _has_attachment_target:
		var diamond := PackedVector2Array([Vector2(0,-7),Vector2(7,0),Vector2(0,7),Vector2(-7,0),Vector2(0,-7)])
		for index in range(diamond.size()-1):
			var start := _attachment_point+diamond[index]
			var end := _attachment_point+diamond[index+1]
			draw_line(start,end,INK,3.0,true)
			draw_line(start,end,TEXT,1.0,true)


func _box(fill: Color, edge: Color, radius: int) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new(); box.bg_color=fill; box.border_color=edge; box.set_border_width_all(1); box.set_corner_radius_all(radius); return box
