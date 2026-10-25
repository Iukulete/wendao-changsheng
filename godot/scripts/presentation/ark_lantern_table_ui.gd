extends Control
## View-only: emits intents. Rules, eligibility and persistence live elsewhere.
signal action_requested(action: String)
const CLOTH_PATH := "res://art/lantern_table/cloth_albedo_v1.png"
const INK := Color("243b3a")
const CREAM := Color("f4ecd8")
const GOLD := Color("d7b779")
const SUITS := ["♠", "♥", "♣", "♦"]
var panel: PanelContainer
var title: Label
var resident_label: Label
var player_label: Label
var resident_cards: HBoxContainer
var player_cards: HBoxContainer
var conversation: Label
var result_label: Label
var feedback: Label
var hit_button: Button
var stand_button: Button
var again_button: Button
var _stack: VBoxContainer
var _description: Label
var _words: ScrollContainer
var _rows: Array[ScrollContainer] = []
var _last: Dictionary = {}

func _ready() -> void:
	name = "ArkLanternTableUI"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := ColorRect.new()
	veil.color = Color(0.015, .035, .04, .84)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	panel = PanelContainer.new()
	panel.name = "LanternTablePanel"
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("122e30")
	frame.border_color = GOLD
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(16)
	frame.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", frame)
	add_child(panel)
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	var cloth := TextureRect.new()
	cloth.texture = load(CLOTH_PATH)
	cloth.modulate = Color(.5, .5, .5, 1)
	cloth.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cloth.stretch_mode = TextureRect.STRETCH_SCALE
	cloth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(cloth)
	cloth.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stack := VBoxContainer.new()
	_stack = stack
	stack.add_theme_constant_override("separation", 6)
	content.add_child(stack)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_left = 42
	stack.offset_right = -42
	stack.offset_top = 22
	stack.offset_bottom = -22
	var header := HBoxContainer.new()
	stack.add_child(header)
	title = _label("灯下牌局", 28, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := _button("暂离 · Esc", "close")
	close.name = "LanternCloseButton"
	header.add_child(close)
	_description = _label("不押物资，只图灯下相伴。A 算 1 或 11；J / Q / K 算 10。居民在 17 点停牌。", 13, CREAM)
	stack.add_child(_description)
	resident_label = _label("", 20, GOLD)
	stack.add_child(resident_label)
	resident_cards = _card_row(stack)
	player_label = _label("", 20, GOLD)
	stack.add_child(player_label)
	player_cards = _card_row(stack)
	result_label = _label("", 20, GOLD)
	stack.add_child(result_label)
	_words = ScrollContainer.new()
	_words.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_words.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_words.custom_minimum_size.y = 48
	stack.add_child(_words)
	conversation = _label("", 16, CREAM)
	conversation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	conversation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_words.add_child(conversation)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	stack.add_child(actions)
	hit_button = _button("1 · 再要一张", "hit")
	hit_button.name = "LanternHitButton"
	stand_button = _button("2 · 停牌亮底", "stand")
	stand_button.name = "LanternStandButton"
	again_button = _button("1 · 再来一局", "again")
	again_button.name = "LanternAgainButton"
	for button in [hit_button, stand_button, again_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	feedback = _label("F5 保存牌序 · 暂离后可从 H 继续，未结束的牌局不会重洗。", 12, Color("c6d9d2"))
	stack.add_child(feedback)
	resized.connect(_layout)
	_layout()
	hide()

func _label(text_: String, size_: int, color_: Color) -> Label:
	var label := Label.new()
	label.text = text_
	label.add_theme_font_size_override("font_size", size_)
	label.add_theme_color_override("font_color", color_)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text_: String, action: String) -> Button:
	var button := Button.new()
	button.text = text_
	button.custom_minimum_size.y = 42
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("204b49")
	box.border_color = GOLD
	box.set_border_width_all(1)
	box.set_corner_radius_all(7)
	box.set_content_margin_all(10)
	button.add_theme_stylebox_override("normal", box)
	var hover := box.duplicate() as StyleBoxFlat
	hover.bg_color = Color("356560")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", CREAM)
	button.pressed.connect(func(): action_requested.emit(action))
	return button

func _card_row(parent: Node) -> HBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 92
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	_rows.append(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(row)
	return row

func _layout() -> void:
	if panel == null: return
	var viewport_size := get_viewport_rect().size
	var desired := Vector2(minf(1040, viewport_size.x - 40), minf(640, viewport_size.y - 40))
	var compact := viewport_size.y < 680
	_stack.offset_top = 12 if compact else 22
	_stack.offset_bottom = -12 if compact else -22
	_stack.add_theme_constant_override("separation", 4 if compact else 6)
	(panel.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(14 if compact else 18)
	title.add_theme_font_size_override("font_size", 22 if compact else 26)
	_description.add_theme_font_size_override("font_size", 14)
	for label in [resident_label, player_label]: label.add_theme_font_size_override("font_size", 16 if compact else 18)
	result_label.add_theme_font_size_override("font_size", 18 if compact else 20)
	conversation.add_theme_font_size_override("font_size", 14 if compact else 16)
	_words.custom_minimum_size.y = 40 if compact else 48
	for row in _rows:
		row.custom_minimum_size.y = 78 if compact else 92
		for card in row.get_child(0).get_children(): card.custom_minimum_size = Vector2(62 if compact else 70, 78 if compact else 92)
	for button in [hit_button, stand_button, again_button]:
		button.custom_minimum_size.y = 36 if compact else 40
		button.add_theme_font_size_override("font_size", 15 if compact else 16)
	feedback.add_theme_font_size_override("font_size", 13)
	panel.position = (viewport_size - desired) / 2
	panel.size = desired

func present(view: Dictionary, line: String) -> void:
	var resident_name := "守潮人" if view.opponent == "tidekeeper" else "缝帆人"
	title.text = "灯下牌局 · 第 %d 局" % int(view.round)
	var playing: bool = view.phase == "playing"
	resident_label.text = "%s · 明牌 %d 点 / 另一张尚未亮开" % [resident_name, int(view.resident_score)] if playing else "%s · %d 点" % [resident_name, int(view.resident_score)]
	player_label.text = "你 · %d 点" % int(view.player_score)
	result_label.text = "你的回合" if playing else "你赢了这一局" if view.result == "player_win" else "这一局由她收下" if view.result == "resident_win" else "平分秋色"
	conversation.text = line
	hit_button.visible = playing
	stand_button.visible = playing
	again_button.visible = not playing
	feedback.text = "F5 保存牌序 · 暂离后可从 H 继续，未结束的牌局不会重洗。"
	if view != _last:
		_cards(resident_cards, view.resident)
		_cards(player_cards, view.player)
		_last = view.duplicate(true)
	_layout()
	show()

func _cards(row: HBoxContainer, cards: Array) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	for id in cards:
		var card := PanelContainer.new()
		var compact := get_viewport_rect().size.y < 680
		card.custom_minimum_size = Vector2(62 if compact else 70, 78 if compact else 92)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var paper := StyleBoxFlat.new()
		paper.bg_color = CREAM if int(id) >= 0 else Color("163c3d")
		paper.border_color = GOLD
		paper.set_border_width_all(2)
		paper.set_corner_radius_all(7)
		paper.set_content_margin_all(4 if compact else 5)
		card.add_theme_stylebox_override("panel", paper)
		row.add_child(card)
		if int(id) < 0:
			var back := _label("灯\n下", 24, GOLD)
			back.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			back.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			card.add_child(back)
		else:
			var rank := int(id) % 13 + 1
			var suit: int = int(id) / 13
			var red := suit in [1, 3]
			var color_ := Color("a14739") if red else INK
			var stack := VBoxContainer.new()
			card.add_child(stack)
			var rank_text := "A" if rank == 1 else "J" if rank == 11 else "Q" if rank == 12 else "K" if rank == 13 else str(rank)
			stack.add_child(_label(rank_text, 18 if compact else 21, color_))
			var symbol := _label(SUITS[suit], 23 if compact else 27, color_)
			symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stack.add_child(symbol)

func save_feedback(ok: bool) -> void:
	feedback.text = "牌序和这一局已保存。" if ok else "保存没有成功；原档保留，当前牌局仍在。"
