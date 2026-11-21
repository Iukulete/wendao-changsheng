extends Node
const TensionGauge = preload("res://scripts/presentation/ark_fishing_tension_gauge.gd")
const VoyageSkin = preload("res://scripts/presentation/ark_voyage_skin.gd")
const Gear = preload("res://scripts/presentation/ark_fishing_gear.gd")
var gear = Gear.new()
const Equipment = preload("res://scripts/modules/leisure/ark_fishing_equipment.gd")
const Rules = preload("res://scripts/modules/leisure/ark_fishing.gd")
const RodProfiles = preload("res://scripts/modules/leisure/ark_fishing_rod_profiles.gd")
const PaidFight = preload("res://scripts/modules/leisure/ark_bait_fight.gd")
const Bait = preload("res://scripts/modules/leisure/ark_bait_fishing.gd")
var bait = Bait.new()
var pending_bait := false
var game: Node3D
var rules = Rules.new()
var panel: PanelContainer
var title: Label
var info: Label
var action_label: Label
var action_key: Label
var paid_action_row: HBoxContainer
var paid_action_key: Label
var paid_action_label: Label
var tension_marker: Control
var gear_label: Label
var tension_bar: ProgressBar
var distance_bar: ProgressBar
var tension_row: HBoxContainer
var distance_row: HBoxContainer
var tension_title: Label
var distance_title: Label
var marker: Node3D
var rod: Node3D
var bob: Node3D
var line: MeshInstance3D
var held_guard := false
var _paid_retry_key_down := false
var _paid_retry_notice := ""
var tension_fill: StyleBoxFlat
# Layout is frozen for a cast, except viewport/save-warning geometry changes.
# The camera is already locked by the existing fishing modal owner.
var _panel_layout_key: Array = []
var _panel_layout_top := 0.0
var _panel_layout_limit := 0.0
var _panel_layout_ready := false
var _panel_layout_height := 212.0
var _panel_settle_queued := false

func attach(g: Node3D) -> void:
	game = g
	# Use the actual rail-side grip height, not a ground-level point in the chest aisle.
	marker = Node3D.new(); marker.name = "FishingStation"; marker.position = Vector3(2.95, 0.65, -0.65)
	game.ark_root.add_child(marker)
	game.interactables.append({"id":"fishing","node":marker})
	gear.attach(game,marker)
	rod=gear.rod;bob=gear.bob;line=gear.line
	var layer := CanvasLayer.new(); layer.layer = 32; add_child(layer)
	panel = PanelContainer.new(); layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -250; panel.offset_right = 250; panel.offset_top = -250; panel.offset_bottom = -38
	var style := VoyageSkin.panel(18)
	style.content_margin_left = 16; style.content_margin_right = 16; style.content_margin_top = 10; style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	var theme := Theme.new(); theme.default_font = game.UI_FONT; theme.default_font_size = 18; panel.theme = theme
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 5); panel.add_child(box)
	title = Label.new(); title.add_theme_font_size_override("font_size", 18); title.add_theme_color_override("font_color", VoyageSkin.TEXT); box.add_child(title)
	tension_row = HBoxContainer.new(); box.add_child(tension_row)
	tension_title = Label.new(); tension_title.add_theme_font_size_override("font_size", 14); tension_title.add_theme_color_override("font_color", VoyageSkin.TEXT); tension_title.custom_minimum_size.x = 128; tension_row.add_child(tension_title)
	tension_bar = ProgressBar.new(); tension_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tension_bar.max_value = 100; tension_bar.custom_minimum_size.y = 18; tension_bar.show_percentage = false; tension_row.add_child(tension_bar)
	tension_fill = VoyageSkin.progress(Color("8b9d7a")); tension_bar.add_theme_stylebox_override("fill",tension_fill); tension_bar.add_theme_stylebox_override("background",VoyageSkin.track())
	var danger := ColorRect.new(); danger.color = Color(0.9,0.24,0.15,0.65); danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tension_bar.add_child(danger); danger.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); danger.anchor_left = 0.97
	tension_bar.tooltip_text = "红端 97% 起持续绷线会让鱼挣脱；收线到 90% 已停止推进。"
	tension_marker = TensionGauge.new(); tension_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE; tension_bar.add_child(tension_marker); tension_marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	distance_row = HBoxContainer.new(); box.add_child(distance_row)
	distance_title = Label.new(); distance_title.add_theme_font_size_override("font_size", 15); distance_title.add_theme_color_override("font_color", VoyageSkin.TEXT); distance_title.custom_minimum_size.x = 128; distance_row.add_child(distance_title)
	distance_bar = ProgressBar.new(); distance_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL; distance_bar.max_value = 100; distance_bar.custom_minimum_size.y = 10; distance_bar.show_percentage = false; distance_row.add_child(distance_bar)
	distance_bar.add_theme_stylebox_override("background",VoyageSkin.track()); distance_bar.add_theme_stylebox_override("fill",VoyageSkin.progress(Color("9b8b63")))
	# One measured column prevents gauge left edges moving at threshold changes.
	var gauge_label_width: float = ceilf(maxf(tension_title.get_theme_font("font").get_string_size("张力 100% · 90%停收",HORIZONTAL_ALIGNMENT_LEFT,-1,14).x,distance_title.get_theme_font("font").get_string_size("收回距离 100%",HORIZONTAL_ALIGNMENT_LEFT,-1,15).x))+8.0
	tension_title.custom_minimum_size.x = gauge_label_width
	distance_title.custom_minimum_size.x = gauge_label_width
	var action_row := HBoxContainer.new(); action_row.add_theme_constant_override("separation", 10); box.add_child(action_row)
	action_key = Label.new(); action_key.text = "E"; action_key.custom_minimum_size = Vector2(32,32); action_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; action_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; action_key.mouse_filter = Control.MOUSE_FILTER_IGNORE; action_key.add_theme_font_size_override("font_size", 17); action_key.add_theme_color_override("font_color", VoyageSkin.TEXT); action_key.add_theme_stylebox_override("normal", VoyageSkin.key()); action_row.add_child(action_key)
	action_label = Label.new(); action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; action_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER; action_label.add_theme_font_size_override("font_size", 16); action_label.add_theme_color_override("font_color", VoyageSkin.TEXT); action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; action_row.add_child(action_label)
	# A keyboard cue, not another default/focusable action.
	paid_action_row = HBoxContainer.new()
	paid_action_row.name = "PaidResultAction"
	paid_action_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paid_action_row.add_theme_constant_override("separation", 10)
	box.add_child(paid_action_row)
	paid_action_key = Label.new()
	paid_action_key.text = "R"
	paid_action_key.custom_minimum_size = action_key.custom_minimum_size
	paid_action_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	paid_action_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	paid_action_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paid_action_key.add_theme_font_size_override("font_size", 17)
	paid_action_key.add_theme_stylebox_override("normal", VoyageSkin.key())
	paid_action_row.add_child(paid_action_key)
	paid_action_label = Label.new()
	paid_action_label.text = "贝肉饵重抛 · 1 鲜贝"
	paid_action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paid_action_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	paid_action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paid_action_label.add_theme_font_size_override("font_size", 16)
	paid_action_row.add_child(paid_action_label)
	paid_action_row.hide()
	info = Label.new(); info.add_theme_font_size_override("font_size", 14); info.add_theme_color_override("font_color", VoyageSkin.MUTED); info.add_theme_constant_override("line_spacing", 3); info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(info)
	var footer := HBoxContainer.new(); box.add_child(footer)
	gear_label = Label.new(); gear_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; gear_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER; gear_label.add_theme_font_size_override("font_size", 13); gear_label.add_theme_color_override("font_color", VoyageSkin.MUTED); footer.add_child(gear_label)
	var close := Button.new(); close.size_flags_horizontal = Control.SIZE_SHRINK_END; close.add_theme_font_size_override("font_size", 14); close.add_theme_color_override("font_color", VoyageSkin.TEXT)
	for state in ["normal", "hover", "pressed", "focus"]: close.add_theme_stylebox_override(state, VoyageSkin.key(state != "normal"))
	close.text = "收竿 · Esc"; close.pressed.connect(func(): cancel("已收竿；没有领取未钓到的鱼。")); footer.add_child(close)
	panel.resized.connect(_fit_panel_vertical)
	panel.minimum_size_changed.connect(_queue_panel_settle)
	if is_instance_valid(game.save_status_notice):
		game.save_status_notice.item_rect_changed.connect(_save_notice_layout_changed)
		game.save_status_notice.visibility_changed.connect(_save_notice_layout_changed)
	panel.hide()
	refresh_equipped_gear()

func active() -> bool: return rules.active()

func set_bait_intent(value: bool) -> bool:
	if active() or game.sailing_mode or game.building_mode or not game.inventory_ui.active() or game.inventory_ui.mode != "bag" or not game._maintenance_window_focused or game.get_tree().paused: return false
	if value and game.economy.inventory("player", "shellfish") < 1: return false
	pending_bait = value
	game._update_interaction_hint()
	return true

func forget_bait_intent() -> void:
	pending_bait = false

func reset_paid_session() -> void:
	pending_bait = false
	bait.reset()

func start() -> void:
	if active() or game.sailing_mode or game.building_mode or game.inventory_ui.active() or game._hud_choice_open(): return
	if game._opening_support_context() != "own_ark":
		game.message = "先站稳在自家甲板的钓竿旁，再抛竿。"; game._update_hud(); return
	if game.equipment_items.selected().is_empty():
		game.message = "未装备钓竿；按 B 打开背包，先装备一支随身钓竿。"; game._update_hud(); return
	game._cancel_maintenance_hold(); game.orbit_camera.release()
	var use_bait: bool = pending_bait
	pending_bait = false # An explicit paid intent applies to this attempt only.
	if use_bait:
		if not _start_paid(game.equipment_items.selected(), false): return
	else:
		rules = Rules.new()
		if not rules.cast(game.economy, _wind(), game.equipment_items.selected()): return
	held_guard = true; panel.show(); _refresh(); game._update_hud(); game._update_interaction_hint()

# The same payment and authority are used for the bag's first paid cast and
# an explicit retry. A failed retry never discards its previous outcome.
func _start_paid(rod_id: String, retry: bool) -> bool:
	var payment: Dictionary = bait.begin(game.economy)
	if not payment.get("ok", false):
		var refusal := "未重新抛竿，未耗鲜贝。请检查随身鲜贝、背包容量和账本。"
		if retry:
			_paid_retry_notice = refusal
			_refresh()
		else:
			game.message = "这次没有抛竿或扣鱼饵：请检查随身鲜贝、容量和账本。下次默认普通钓。"
			game._update_hud(); game._update_interaction_hint()
		return false
	# Stage the already authorized cast without replacing any visible result yet.
	var next_rules = PaidFight.new()
	if not next_rules.cast_paid(game.economy, _wind(), rod_id, bait, payment):
		bait.cancel(payment.ticket)
		game.message = "本局未能抛竿；已使用的鱼饵仍记在本局账本，请查看保存状态。"
		game._write_progress()
		if retry:
			_paid_retry_notice = "未能重新抛竿；本次扣贝请查看保存状态。"
			_refresh()
		game._update_hud()
		return false
	# Keep the payment checkpoint before publishing/stepping the new cast.
	# The no-cancel write is essential when the old result is still visible.
	game._write_progress()
	rules = next_rules
	_paid_retry_notice = ""
	return true

func _paid_result() -> bool:
	return rules is PaidFight and rules.phase in ["caught", "failed"]

func _paid_retry_block_reason() -> String:
	if not game._maintenance_window_focused or game.get_tree().paused: return "窗口恢复后再试。"
	if game.sailing_mode or game.building_mode or game.inventory_ui.active(): return "请先停船，结束其它操作。"
	if not rules.released or held_guard or Input.is_key_pressed(KEY_E): return "先松开 E。"
	if bait.active(): return "上一竿尚未结束。"
	if game.save_service == null or game._restoring_progress or bool(game.get_meta("save_load_blocked", false)) or not str(game.get_meta("save_warning", "")).is_empty():
		return "进度尚未保存；先按 F5 收竿保存。"
	if game._opening_support_context() != "own_ark" or not is_instance_valid(marker) or game.player.global_position.distance_to(marker.global_position) >= 2.8:
		return "请稳站在自家钓位旁。"
	if RodProfiles.profile(game.equipment_items.selected()).is_empty(): return "请先装备钓竿。"
	if game.economy.inventory("player", "shellfish") < 1: return "随身鲜贝不足；不会取用箱内鲜贝。"
	return ""

func _retry_paid() -> void:
	if not _paid_result() or not panel.visible: return
	if not _paid_retry_block_reason().is_empty():
		_refresh()
		return
	if not _start_paid(game.equipment_items.selected(), true): return
	# R does not hold E. The new cast can observe a normal first E at bite.
	rules.release()
	held_guard = false
	_refresh(); game._update_hud(); game._update_interaction_hint()

func _restart_free() -> void:
	_paid_retry_notice = ""
	var rod_id: String = str(rules.rod_profile().id)
	rules.cancel(); bait.reset(); pending_bait = false
	rules = Rules.new()
	rules.cast(game.economy, _wind(), rod_id)
	held_guard = true

func _wind() -> float:
	return 1.0 if game.weather_phase == game.WeatherPhase.STORM else 0.4 if game.weather_phase == game.WeatherPhase.FORECAST else 0.0

func handle(event: InputEvent) -> bool:
	if event is InputEventKey and event.keycode == KEY_F8: return false # Existing global read-only diagnostics.
	if event is InputEventKey and event.keycode == KEY_R:
		var fresh: bool = event.pressed and not event.echo and not _paid_retry_key_down
		_paid_retry_key_down = event.pressed
		if active():
			if fresh and not (event.alt_pressed or event.ctrl_pressed or event.meta_pressed or event.shift_pressed):
				_retry_paid()
			return true
		# Observe release across handoffs; leave idle/world R behavior original.
		return false
	if not active():
		if held_guard and event is InputEventKey and event.keycode == KEY_E:
			if not event.pressed: held_guard = false
			return true
		return false
	if event is InputEventKey:
		if event.keycode == KEY_E:
			if not event.pressed: rules.release(); held_guard = false
			elif not event.echo:
				held_guard = true
				if rules.phase in ["failed","caught"] and rules.released: _restart_free()
				else: rules.press()
		elif event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE: cancel("已收竿；没有领取未钓到的鱼。")
			elif event.keycode == KEY_F5:
				cancel("已收竿再保存；未完成的钓局不会在读档时发鱼。")
				game._manual_save_progress()
				if str(game.get_meta("save_warning", "")).is_empty():
					game.message = "已收竿并保存；未完成的钓局不会在读档时发鱼。"
					game._update_hud()
		return true
	return false # Modal owner blocks world input; GUI close must still receive clicks.

func cancel(note: String = "") -> void:
	if not active(): return
	var used_bait: bool = rules is PaidFight
	rules.cancel(); panel.hide()
	_paid_retry_notice = ""
	refresh_equipped_gear()
	gear.update_visual("idle",0,0,0,0,Transform3D.IDENTITY)
	if not note.is_empty(): game.message = note + (" 本次已使用的1鲜贝不退。" if used_bait else "")
	# Exit-tree autosave can run after the player and Ark children have detached.
	if is_instance_valid(game.player) and game.player.is_inside_tree() and is_instance_valid(game.ark_root) and game.ark_root.is_inside_tree():
		game._update_hud()

func _process(delta: float) -> void:
	if not active(): return
	if not game._maintenance_window_focused or game.get_tree().paused:
		rules.release(); return
	if game.sailing_mode:
		cancel("已收竿；掌舵时不能同时钓鱼。"); return
	rules.step(delta, _wind())
	if rules.phase == "landed":
		var result: Dictionary = rules.settle(game.economy)
		game.message = rules.reason
		if result.get("ok",false) and not result.get("duplicate",false):
			game._record_world_event("fish_caught", {"resource":"large_fish" if rules is PaidFight else "fish","amount":1,"sequence":rules.sequence,"weather":game.weather_phase})
			game._write_progress()
	_refresh()

func refresh_equipped_gear() -> void:
	if not active():
		var equipped:String=game.equipment_items.selected()
		gear.set_profile(equipped)
		if is_instance_valid(gear.rod): gear.rod.visible=not equipped.is_empty()

func _refresh() -> void:
	var rod_profile:Dictionary=rules.rod_profile()
	gear.set_profile(str(rod_profile.id))
	tension_bar.tooltip_text="红端97%%起持续%.2f秒会脱鱼；90%%起收线停止推进。" % float(rod_profile.stress_limit)
	tension_row.visible = rules.phase == "fighting"; distance_row.visible = tension_row.visible
	tension_title.text = "张力 %d%% · 90%%停收" % int(rules.tension*100)
	var distance_fraction: float = rules.distance / rules.total_distance if rules is PaidFight else rules.distance
	distance_title.text = "收回距离 %d%%" % int((1-distance_fraction)*100)
	tension_bar.value = rules.tension * 100; distance_bar.value = (1.0-distance_fraction)*100
	tension_fill.bg_color = Color("df795d") if rules.tension >= 0.97 or rules.slack > 0 else Color("d5b971") if rules.tension >= 0.9 else Color("73b1ac")
	tension_fill.border_color = tension_fill.bg_color.lightened(0.15)
	tension_marker.value = rules.tension; tension_marker.queue_redraw()
	var danger_now: bool = rules.phase=="fighting" and (rules.tension>=0.97 or rules.slack>0.0)
	title.add_theme_color_override("font_color", Color("efb09a") if danger_now else VoyageSkin.TEXT)
	action_label.add_theme_color_override("font_color", Color("efb09a") if danger_now else VoyageSkin.TEXT)
	if rules.phase=="fighting" and rules.tension>=0.97: tension_title.text = "张力 %d%% · 危险" % int(rules.tension*100)
	elif rules.phase=="fighting" and rules.tension>=0.9: tension_title.text = "张力 %d%% · 停收" % int(rules.tension*100)
	var weather := "风雨正急：浪涌额外拉紧鱼线。" if rules.wind > 0.8 else "海风带来一点牵扯。" if rules.wind > 0 else "海面平静。"
	match rules.phase:
		"waiting": title.text = "浮漂轻晃 · 等待咬钩"; info.text = "先松开 E；看见浮漂下沉，再按 E 提竿。\n"+weather
		"bite": title.text = "咬钩了 · 提竿窗口"; info.text = "浮漂正在下沉，别错过这一口。\n"+weather
		"fighting":
			if rules.tension >= 0.97: title.text = "鱼线绷紧 · 即将脱鱼"
			elif rules.tension >= 0.9: title.text = "鱼线吃紧 · 收线已停"
			elif rules.slack > 0.0: title.text = "鱼线松弛 · 鱼快游走了"
			else: title.text = "鱼正猛挣 · 留意鱼线" if rules.pull else "鱼暂歇力 · 收线机会"
			info.text = "按住 E 收线，松开 E 降张力；勿绷断或长时间松空。\n" + weather
		_: title.text = "收获鲜鱼" if rules.phase == "caught" else "这次鱼游走了"; info.text = rules.reason + "\n松开后再按 E 重新抛竿，Esc 收竿。"
	if rules is PaidFight:
		if rules.phase == "waiting": title.text = "贝肉饵已抛出 · 等待咬钩"
		elif rules.phase == "fighting" and rules.tension < 0.9 and rules.slack <= 0:
			title.text = "肥鱼急冲 · 留意鱼线" if rules.pull else "肥鱼缓劲 · 收线机会"
		elif rules.phase == "caught": title.text = "收获肥鱼"
		if rules.phase in ["waiting", "bite", "fighting"]:
			var paid_weather: String = "风雨拉紧鱼线" if rules.wind > 0.8 else "海风牵动鱼线" if rules.wind > 0 else "平静海面"
			info.text = info.text.replace(weather, paid_weather + " · 已用1贝，失败或收竿不退。")
		else:
			info.text = rules.reason + "\n松开后按E普通重抛（不耗饵），Esc收竿。"
	var sea_note: String = "风雨拉紧鱼线" if rules.wind>0.8 else "海风牵动鱼线" if rules.wind>0 else "平静海面"
	gear_label.text = str(rod_profile.title) + " · " + sea_note
	var paid_note: String = "已用1贝，失败或收竿不退。" if rules is PaidFight else ""
	match rules.phase:
		"waiting":
			action_label.text = "先松开；浮漂下沉后再按下"
			info.text = paid_note
		"bite":
			action_label.text = "先松开，再按下提竿" if held_guard and (not rules.released or Input.is_key_pressed(KEY_E)) else "现在按下提竿"
			info.text = paid_note if not paid_note.is_empty() else "浮漂正在下沉，别错过这一口。"
		"fighting":
			action_label.text = "立即松开，降低张力" if rules.tension>=0.9 else "按住收线，别让鱼线松空" if rules.slack>0 else "按住收线 · 松开降张力"
			info.text = "勿绷断或久松空；" + paid_note if not paid_note.is_empty() else "勿绷断或长时间松空。"
		_:
			action_label.text = "松开后再按下，普通重抛"
			info.text = rules.reason + ("\n普通重抛不耗饵。" if rules is PaidFight else "")
	paid_action_row.visible = _paid_result()
	info.add_theme_color_override("font_color", VoyageSkin.MUTED)
	if paid_action_row.visible:
		_refresh_paid_result_actions()
	# Use this frame's actual world pose before choosing a screen-space layout.
	gear.update_visual(rules.phase,rules.tension,distance_fraction,rules.elapsed,rules.wind,game.ark_root.global_transform)
	_update_panel_layout()

func _refresh_paid_result_actions() -> void:
	action_label.text = "普通重抛 · 免费"
	var blocked := _paid_retry_block_reason()
	var accent := VoyageSkin.ACCENT if blocked.is_empty() else VoyageSkin.MUTED
	paid_action_key.add_theme_color_override("font_color", accent)
	paid_action_label.add_theme_color_override("font_color", accent)
	# Keep catch/authority outcomes authoritative; shorten only the three
	# known failure descriptions while preserving used bait and intact rod.
	var result: String = rules.reason
	if rules.phase == "failed":
		if result.begins_with("鱼已脱钩："): result = "错过提竿 · 已耗饵，竿无损"
		elif result.begins_with("线绷得太紧"): result = "绷线脱钩 · 已耗饵，竿无损"
		elif result.begins_with("线松得太久"): result = "松线脱钩 · 已耗饵，竿无损"
	info.text = result
	if not blocked.is_empty():
		info.add_theme_color_override("font_color", VoyageSkin.TEXT)
		info.text += "\nR 暂不可用：" + blocked
	elif not _paid_retry_notice.is_empty():
		info.text += "\n" + _paid_retry_notice


func _cast_float_screen_region() -> Dictionary:
	# Bound every existing float mesh in its local frame, including temporarily
	# submerged parts. Rotate conservatively through the gear's maximum 0.13rad
	# sway; then include distance 0..1, +/-0.06 wave and 0..0.27 bite dip.
	# No geometry or rule is changed to obtain this presentation-only envelope.
	var box := AABB()
	var found := false
	for child in bob.get_children():
		if child is MeshInstance3D:
			var child_box: AABB = child.transform * child.get_aabb()
			box = box.merge(child_box) if found else child_box
			found = true
	if not found: return {"valid":false}
	var max_x: float = maxf(absf(box.position.x),absf(box.end.x))
	var max_y: float = maxf(absf(box.position.y),absf(box.end.y))
	var x_radius: float = max_x + sin(0.13) * max_y
	var y_margin: float = sin(0.13) * max_x
	var points: Array[Vector2] = []
	# The float is parented to game/world, not ArkRoot: its sway axes must NOT
	# rotate with the boat. Transform center travel first, then add world-parent
	# mesh offsets. This also covers a boat previously steered away from yaw 0.
	for x in [4.5, 6.0]:
		for y in [0.025 - 0.06 - 0.27, 0.025 + 0.06]:
			var center: Vector3 = game.ark_root.to_global(Vector3(x,y,-0.65))
			for dx in [-x_radius,x_radius]:
				for dy in [box.position.y-y_margin,box.end.y+y_margin]:
					for dz in [box.position.z,box.end.z]:
						var point: Vector3 = center + game.global_basis * Vector3(dx,dy,dz)
						if game.camera.is_position_behind(point): return {"valid":false}
						var projected: Vector2 = game.camera.unproject_position(point)
						if not projected.is_finite(): return {"valid":false}
						points.append(projected)
	var region := Rect2(points[0], Vector2.ZERO)
	for point in points: region = region.expand(point)
	return {"valid":true, "rect":region.grow(8.0)}

func _update_panel_layout() -> void:
	var screen: Vector2 = game.get_viewport().get_visible_rect().size
	var warning := Rect2()
	if not str(game.get_meta("save_warning", "")).is_empty() and is_instance_valid(game.save_status_notice) and game.save_status_notice.is_visible_in_tree():
		warning = game.save_status_notice.get_global_rect()
	var key: Array = [rules.get_instance_id(), screen, warning]
	if key == _panel_layout_key: return
	_panel_layout_key = key
	_panel_layout_ready = false
	var warned := warning.has_area()
	var top: float = warning.position.y - 252.0 if warned else screen.y - 268.0
	var height: float = 142.0
	var width := 400.0
	var x: float = 24.0
	var mode := "left"
	# Reserve the full compact fight envelope, independent of the current phase.
	var center := Rect2(Vector2(x, top), Vector2(width,244.0))
	var projected := _cast_float_screen_region()
	if projected.get("valid", false):
		var region: Rect2 = projected.rect
		if center.intersects(region):
			var left_width: float = minf(400.0, region.position.x - 32.0)
			var right_width: float = minf(400.0, screen.x - region.end.x - 32.0)
			# Measured longest existing title + panel padding; never shrink text.
			var minimum_width: float = maxf(360.0, title.get_minimum_size().x + 32.0)
			if maxf(left_width,right_width) >= minimum_width:
				width = maxf(left_width,right_width)
				mode = "left" if left_width >= right_width else "right"
				x = 24.0 if mode == "left" else screen.x - 24.0 - width
			else:
				mode = "bounded_fallback"
				# Unusually close/oblique views may leave no side. A clear upper
				# corner is preferable, but never sacrifice the warning or Close.
				for upper_x in [24.0, screen.x - 424.0]:
					var upper := Rect2(Vector2(upper_x,24.0),Vector2(400.0,244.0))
					if Rect2(Vector2.ZERO,screen).encloses(upper) and not upper.intersects(region) and (not warned or not upper.intersects(warning)):
						x = upper_x; top = 24.0; mode = "upper"; break
	else:
		mode = "offscreen_projection"
	panel.set_meta("fishing_layout_mode",mode)
	panel.set_meta("fishing_layout_region",projected.get("rect",Rect2()))
	# Avoid temporarily resetting the container to zero width: autowrap would
	# report a one-character-column minimum until the next layout pass.
	panel.position = Vector2(x,top)
	panel.size = Vector2(width,height)
	_panel_layout_height = height
	_panel_layout_top = top
	_panel_layout_limit = warning.position.y - 8.0 if warned else screen.y - 24.0
	_panel_layout_ready = true
	_queue_panel_settle()
	_fit_panel_vertical()

func _fit_panel_vertical() -> void:
	if not _panel_layout_ready or not is_instance_valid(panel): return
	# Containers can grow after autowrap is measured. Move the existing panel,
	# never trim its text or hide a persistent failed-save warning.
	panel.position.y = maxf(0.0,minf(_panel_layout_top,_panel_layout_limit-panel.size.y)) if str(panel.get_meta("fishing_layout_mode", ""))=="upper" else maxf(0.0,_panel_layout_limit-panel.size.y)

func _queue_panel_settle() -> void:
	if not _panel_layout_ready or _panel_settle_queued: return
	_panel_settle_queued = true
	_settle_panel_size.call_deferred()

func _settle_panel_size() -> void:
	_panel_settle_queued = false
	if not _panel_layout_ready or not is_instance_valid(panel): return
	panel.size.y = maxf(_panel_layout_height,panel.get_combined_minimum_size().y)
	_fit_panel_vertical()

func _save_notice_layout_changed() -> void:
	# Autowrap can move the existing notice's top during the same render pass.
	# React to its final Control rectangle rather than waiting a fishing tick.
	if active() and is_instance_valid(panel) and panel.is_inside_tree() and is_instance_valid(game.camera) and game.camera.is_inside_tree() and is_instance_valid(game.ark_root) and game.ark_root.is_inside_tree():
		_update_panel_layout()
