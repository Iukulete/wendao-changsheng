extends VBoxContainer
## Read-only projection of the authoritative hud_details Label.
## No game reference, rule calculations, command routing, save access or input.
const Type = preload("res://scripts/presentation/ark_ui_type.gd")
const TEXT := Color("e8e3d3")
const MUTED := Color("b7b8a8")
const KEY_WIDTH := 112.0
const GROUP_ORDER := ["生存物资", "居住防护", "当前目标", "居民近况", "远礁", "补充信息"]
# Match the existing presentation grammar, never infer missing gameplay facts.
# A failed/extended grammar falls back to the original, complete visible line.
const PATTERNS := {
	"time": r"^(第 [0-9]+ 天·[^\n]+)  ·  生命 ([0-9]+/[0-9]+)$",
	"materials": r"^木料 ([0-9]+（随身）\+ [0-9]+（储存）) · 鲜贝 ([0-9]+) · 热汤 ([0-9]+)(.*)$",
	"cold": r"^(轻寒|重寒|彻骨) ([0-9]+/3（步速 [0-9]+%）)$",
	"weather": r"^(下一场风雨已预报|风雨将至|风雨正急|雨后)  ·  (避风棚已建|避风棚未建)(?: · (棚顶松脱 ?(?:筏舷松动)?|筏舷松动))?$",
	"residents": r"^避难者 ([0-9]+/[0-9]+（不含玩家）)$",
	"beds": r"^居民专用床位 ([0-9]+) · 临时避难名额 ([0-9]+)$",
	"refuge": r"^玩家床铺 ([0-9]+) · 仙舟庇护圈 ([0-9]+m(?:（阵灯增幅）)?) · (圈内|圈外 [0-9]+m)$",
	"supply": r"^可施工木料 ([0-9]+（随身 [0-9]+ \+ 本舟储箱 [0-9]+，先用随身）)$",
	"reef": r"^远礁：礁背兽 (已击退|[0-9]+/[0-9]+) · 礁壳 ([0-9]+) · 风撑 (已安装|未安装)$",
}
var _source: Label
var _last_text := ""
var _built := false
var _patterns: Dictionary = {}

func _init() -> void:
	name = "ArkHomeDetailsView"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 16)
	visible = false # The existing disclosure remains the only way to open it.
	for key in PATTERNS:
		var expression := RegEx.new()
		assert(expression.compile(PATTERNS[key]) == OK)
		_patterns[key] = expression

func attach(source: Label, parent: Node) -> void:
	assert(is_instance_valid(source) and is_instance_valid(parent))
	assert(get_parent() == null or get_parent() == parent)
	_source = source
	if get_parent() == null:
		parent.add_child(self)
	_built = false
	refresh()

func refresh() -> void:
	if not is_instance_valid(_source):
		return
	var text := _source.text
	if _built and text == _last_text:
		return
	_last_text = text
	_built = true
	# Remove old controls immediately. Queued children must not remain visible
	# for one frame or contaminate rendered_text()/input/geometry assertions.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var groups: Dictionary = {}
	for raw_line in text.split("\n"):
		var line := raw_line.trim_suffix("\r")
		if line.is_empty():
			continue
		var result := _decode_line(line)
		var title: String = result["group"]
		if not groups.has(title):
			groups[title] = []
		groups[title].append_array(result["rows"])
	for title in GROUP_ORDER:
		if groups.has(title):
			_add_group(title, groups[title])

func _process(_delta: float) -> void:
	# No extra call into _update_hud or the game's mutable subsystem owners.
	# Closed views do no automatic parsing; opening refreshes synchronously.
	if is_visible_in_tree():
		refresh()

func rendered_text() -> String:
	# Deliberately reads the actual currently visible Label tree, not _source,
	# cached parse records or hidden compatibility text. A closed view is empty.
	var lines := PackedStringArray()
	_collect_rendered_lines(self, lines)
	return "\n".join(lines)

func content_text() -> String:
	# For legacy pure-content assertions while H is closed, refresh the same
	# real view controls and read their text. This is NOT pixel-visible proof.
	refresh()
	var lines := PackedStringArray()
	_collect_rendered_lines(self, lines, true)
	return "\n".join(lines)

func _collect_rendered_lines(node: Node, lines: PackedStringArray, include_hidden: bool = false) -> void:
	if not include_hidden and node is Control and not (node as Control).is_visible_in_tree():
		return
	if node is Label:
		lines.append((node as Label).text)
		return
	if node is HBoxContainer:
		var cells := PackedStringArray()
		for child in node.get_children():
			_collect_rendered_lines(child, cells, include_hidden)
		if not cells.is_empty():
			lines.append(" ".join(cells))
		return
	for child in node.get_children():
		_collect_rendered_lines(child, lines, include_hidden)

func _match(key: String, line: String) -> RegExMatch:
	var expression: RegEx = _patterns[key]
	return expression.search(line)

func _row(key: String, value: String, prose: bool = false) -> Dictionary:
	return {"key": key, "value": value, "prose": prose}

func _result(group: String, rows: Array) -> Dictionary:
	return {"group": group, "rows": rows}

func _decode_line(line: String) -> Dictionary:
	var found := _match("time", line)
	if found != null:
		return _result("生存物资", [_row("时日", found.get_string(1)), _row("生命", found.get_string(2))])
	found = _match("materials", line)
	if found != null:
		var rows: Array = [_row("木料", found.get_string(1)), _row("鲜贝", found.get_string(2)), _row("热汤", found.get_string(3))]
		var tail := found.get_string(4)
		if not tail.is_empty():
			if not tail.begins_with(" · "):
				return _fallback("生存物资", line)
			for token in tail.trim_prefix(" · ").split(" · "):
				if token == "游泳":
					rows.append(_row("行动状态", token))
				elif _match("cold", token) != null:
					rows.append(_row("寒冷", token))
				else:
					# Unknown suffix: keep the ENTIRE line, not a lossy tail.
					return _fallback("生存物资", line)
		return _result("生存物资", rows)
	found = _match("weather", line)
	if found != null:
		var rows: Array = [_row("天气", found.get_string(1)), _row("避风棚", found.get_string(2).trim_prefix("避风棚"))]
		if not found.get_string(3).is_empty():
			rows.append(_row("损伤", found.get_string(3).strip_edges()))
		return _result("居住防护", rows)
	found = _match("residents", line)
	if found != null:
		return _result("居住防护", [_row("避难者", found.get_string(1))])
	found = _match("beds", line)
	if found != null:
		return _result("居住防护", [_row("居民专用床位", found.get_string(1)), _row("临时避难名额", found.get_string(2))])
	found = _match("refuge", line)
	if found != null:
		return _result("居住防护", [_row("玩家床铺", found.get_string(1)), _row("仙舟庇护圈", found.get_string(2)), _row("所在位置", found.get_string(3))])
	if line.begins_with("当前目标："):
		return _result("当前目标", [_row("", line.trim_prefix("当前目标："), true)])
	for key in ["居民采集偏好", "家中缺口", "居民营生"]:
		if line.begins_with(key + "："):
			return _result("居民近况", [_row(key, line.trim_prefix(key + "："), key != "居民采集偏好")])
	found = _match("supply", line)
	if found != null:
		return _result("生存物资", [_row("可施工木料", found.get_string(1))])
	found = _match("reef", line)
	if found != null:
		return _result("远礁", [_row("礁背兽", found.get_string(1)), _row("礁壳", found.get_string(2)), _row("风撑", found.get_string(3))])
	return _fallback(_fallback_group(line), line)

func _fallback_group(line: String) -> String:
	# Classification never removes text or prevents an unknown field appearing.
	for prefix in ["第 ", "木料 ", "可施工木料 "]:
		if line.begins_with(prefix):
			return "生存物资"
	for prefix in ["避难者 ", "居民专用床位 ", "玩家床铺 ", "风雨", "雨后", "下一场风雨"]:
		if line.begins_with(prefix):
			return "居住防护"
	if line.begins_with("远礁："):
		return "远礁"
	return "补充信息"

func _fallback(group: String, line: String) -> Dictionary:
	return _result(group, [_row("", line, true)])

func _add_group(title: String, rows: Array) -> void:
	var group := VBoxContainer.new()
	group.name = "StatsGroup" + str(get_child_count())
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.add_theme_constant_override("separation", 7)
	add_child(group)
	var heading := _label(title, 16, 600, TEXT)
	heading.name = "Heading"
	group.add_child(heading)
	for data in rows:
		if bool(data["prose"]):
			_add_prose(group, str(data["key"]), str(data["value"]))
		else:
			_add_stat(group, str(data["key"]), str(data["value"]))

func _add_stat(parent: VBoxContainer, key: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := _label(key, 15, 400, MUTED)
	label.name = "Key"
	label.custom_minimum_size.x = KEY_WIDTH
	label.size_flags_horizontal = Control.SIZE_FILL
	row.add_child(label)
	var content := _label(value, 16, 500, TEXT)
	content.name = "Value"
	row.add_child(content)

func _add_prose(parent: VBoxContainer, key: String, value: String) -> void:
	# Long objective/need/work paragraphs get the full width rather than a
	# squeezed numeric column. Their words and clauses are never rewritten.
	var block := VBoxContainer.new()
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 4)
	parent.add_child(block)
	if not key.is_empty():
		var label := _label(key, 15, 500, MUTED)
		label.name = "Key"
		block.add_child(label)
	var content := _label(value, 15, 400, TEXT)
	content.name = "Value"
	block.add_child(content)

func _label(value: String, points: int, weight: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.focus_mode = Control.FOCUS_NONE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.add_theme_font_override("font", Type.face(weight))
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("line_spacing", 2)
	return label
