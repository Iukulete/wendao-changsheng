extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const SaveServiceScript = preload("res://scripts/save_service.gd")
const AchievementSystemScript = preload("res://scripts/achievement_system.gd")
const ItemSystemScript = preload("res://scripts/item_system.gd")
const DungeonSystemScript = preload("res://scripts/dungeon_system.gd")
const MainScene = preload("res://scenes/main.tscn")

const VIEWPORTS := [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(1920, 1080)]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_root := ProjectSettings.globalize_path("res://").path_join("..").path_join(".tmp").path_join("render-captures").simplify_path()
	DirAccess.make_dir_recursive_absolute(output_root)
	var save_root := ProjectSettings.globalize_path("res://").path_join("..").path_join(".tmp").path_join("godot-save-tests").path_join("render").simplify_path()
	var service: RefCounted = SaveServiceScript.new("rendercapture", save_root)
	service.call("clear_slot")
	DirAccess.remove_absolute(save_root)
	DirAccess.make_dir_recursive_absolute(save_root)
	var legacy_source_path := save_root.path_join("slot_1.txt")
	_write_text(legacy_source_path, _minimal_legacy_save())
	var game := MainScene.instantiate()
	game.set("save_service", service)
	game.set("run_state", GameStateScript.create_new_game("镜湖照影", 42424242, [8, 8, 8, 8, 8]))
	root.add_child(game)
	await process_frame
	root.size = Vector2i(1280, 720)
	await _settle_frames(4)
	_capture(root, output_root.path_join("menu_1280x720.png"), Vector2i(1280, 720), "主菜单 1280x720")
	game.call("_open_audio_settings")
	await _settle_frames(4)
	var audio_panel := game.find_child("AudioSettingsPanel", true, false) as Control
	var audio_scroll := game.find_child("AudioSettingsScroll", true, false) as ScrollContainer
	if audio_panel == null or audio_scroll == null or audio_panel.size.x < 800.0 or \
			audio_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_AUTO:
		failures.append("1280x720音频设置没有保持清晰宽度与真实滚动路径")
	_capture(root, output_root.path_join("audio_settings_1280x720.png"), Vector2i(1280, 720),
		"音频设置 1280x720")
	game.call("_close_audio_settings")
	await _settle_frames(2)
	DirAccess.remove_absolute(legacy_source_path)
	game.call("_show_game")

	for viewport_size in VIEWPORTS:
		root.size = viewport_size
		await _settle_frames(4)
		if viewport_size == Vector2i(1280, 720):
			var footer := game.find_child("GameFooter", true, false) as Control
			if footer == null or not root.get_visible_rect().encloses(footer.get_global_rect()):
				failures.append("1280x720主界面页脚没有完整落在视口内：%s" % [
					footer.get_global_rect() if footer != null else "missing"])
		_capture(root, output_root.path_join("main_%dx%d.png" % [viewport_size.x, viewport_size.y]),
			viewport_size, "主界面 %dx%d" % [viewport_size.x, viewport_size.y])

	var pre_combat_state: Dictionary = (game.get("run_state") as Dictionary).duplicate(true)
	root.size = Vector2i(1280, 720)
	game.call("_start_combat")
	await _settle_frames(4)
	_capture(root, output_root.path_join("normal_combat_1280x720.png"), Vector2i(1280, 720),
		"普通战斗 1280x720")
	root.size = Vector2i(1440, 900)
	await _settle_frames(4)
	_capture(root, output_root.path_join("normal_combat_1440x900.png"), Vector2i(1440, 900),
		"普通战斗 1440x900")
	game.set("run_state", pre_combat_state)
	game.call("_sync_state_views")
	game.call("_show_game")

	root.size = Vector2i(1440, 900)
	var dungeon_state: Dictionary = game.get("run_state")
	dungeon_state.player.path.insight = 18
	dungeon_state.player.path.creation = 12
	dungeon_state.player.path.bonds = 8
	ItemSystemScript.equip(dungeon_state, "item_iron_sword_000001")
	var armor_result: Dictionary = ItemSystemScript.add_item(dungeon_state, "cloud_robe")
	ItemSystemScript.equip(dungeon_state, str(armor_result.get("instance_id", "")))
	var armory: Dictionary = AchievementSystemScript.normalize(dungeon_state)
	var jade_weapon: Dictionary = armory.weapons.qingxiao
	jade_weapon["unlocked"] = true
	armory.weapons.qingxiao = jade_weapon
	armory["equipped_id"] = "qingxiao"
	dungeon_state.legacy.armory = armory
	dungeon_state.legacy.inherited_echoes = [{"id": "render_echo", "name": "前世行功残篇"}]
	dungeon_state.story.arc_legacies = {"jade":"旧我为证", "sect":"师承共担",
		"family":"断名自立", "rival":"照雪盟友"}
	dungeon_state.story.arc_echoes = {
		"jade":{"stage":3, "resolution":"今身定锚"},
		"sect":{"stage":0, "resolution":""},
		"family":{"stage":3, "resolution":"去名留义"},
		"rival":{"stage":3, "resolution":"相争不相害"},
	}
	game.call("_enter_dungeon")
	await _settle_frames(4)
	var route_trail := game.find_child("DungeonRouteTrail", true, false) as Control
	var route_button := game.find_child("DungeonRouteButton0", true, false) as Button
	if route_trail == null or route_trail.size.x < 500.0 or route_button == null or \
			not route_button.text.contains("预示"):
		failures.append("秘境岔路没有显示可读的四层因果路线与收益风险预示")
	_capture(root, output_root.path_join("dungeon_route_1440x900.png"), Vector2i(1440, 900), "秘境路线")
	var first_run_state: Dictionary = game.get("run_state")
	var memory_index := -1
	var memory_name := ""
	for index in range((first_run_state.dungeon.run.route_choices as Array).size()):
		var node: Dictionary = first_run_state.dungeon.run.route_choices[index]
		if str(node.type) == "memory":
			memory_index = index
			memory_name = str(node.name)
			break
	if memory_index < 0:
		failures.append("首层秘境没有生成用于路线历史验收的机缘道标")
	else:
		game.call("_choose_dungeon_route", memory_index)
		await _settle_frames(4)
		var progressed_trail := game.find_child("DungeonRouteTrail", true, false) as Control
		var progressed_text := ""
		if progressed_trail != null:
			for label_value in progressed_trail.find_children("*", "Label", true, false):
				progressed_text += (label_value as Label).text + "\n"
		if progressed_trail == null or not progressed_text.contains(memory_name) or \
				not progressed_text.contains("已渡"):
			failures.append("已选择道标没有在因果路线中转为可见的已渡节点")
		_capture(root, output_root.path_join("dungeon_route_progress_1440x900.png"),
			Vector2i(1440, 900), "秘境路线推进")
	var run_state: Dictionary = game.get("run_state")
	var route_index := 0
	for index in range((run_state.dungeon.run.route_choices as Array).size()):
		var node: Dictionary = run_state.dungeon.run.route_choices[index]
		if str(node.type) in ["combat", "elite", "boss"]:
			route_index = index
			break
	game.call("_choose_dungeon_route", route_index)
	var combat_state: Dictionary = game.get("run_state")
	var story_card: Dictionary = {}
	for card_value in (combat_state.dungeon.run.deck as Array):
		if card_value is Dictionary and str((card_value as Dictionary).get("source_kind", "")) == "story":
			story_card = (card_value as Dictionary).duplicate(true)
			break
	if story_card.is_empty():
		failures.append("剧情定局能力没有进入秘境牌组")
	if not story_card.is_empty() and not (combat_state.dungeon.run.battle.hand as Array).is_empty():
		combat_state.dungeon.run.battle.hand[0] = story_card
		game.set("run_state", combat_state)
		game.call("_show_dungeon_combat")
	await _settle_frames(4)
	_capture(root, output_root.path_join("dungeon_combat_1440x900.png"), Vector2i(1440, 900), "秘境能力战斗")
	game.set("dungeon_action_feedback", {"kind":"card", "card_name":"今身定锚",
		"source_kind":"story", "damage":18, "block":10, "hp_delta":0,
		"stress_delta":-5, "enemy_block_delta":0, "attack_power_delta":0,
		"phase_shifted":false, "phase_name":""})
	game.call("_show_dungeon_combat")
	await _settle_frames(4)
	var card_summary := game.find_child("DungeonFeedbackSummary", true, false) as Label
	var card_layer := game.find_child("DungeonFeedbackLayer", true, false) as Control
	if card_layer == null or card_layer.mouse_filter != Control.MOUSE_FILTER_IGNORE or card_summary == null or \
			not card_summary.text.contains("今身定锚") or \
			card_summary.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		failures.append("秘境出牌没有生成程序化反馈层与摘要")
	_capture(root, output_root.path_join("dungeon_card_feedback_1440x900.png"), Vector2i(1440, 900),
		"秘境出牌反馈")
	var critical_state: Dictionary = game.get("run_state")
	critical_state.dungeon.run.stress = 92
	var heart: Dictionary = DungeonSystemScript.heart_demon_for_era(
		str(critical_state.dungeon.run.era_id))
	if (critical_state.dungeon.run.battle.hand as Array).is_empty() or heart.is_empty():
		failures.append("无法构造时代心魔临界画面")
	else:
		var heart_card: Dictionary = critical_state.dungeon.run.battle.hand[0].duplicate(true)
		heart_card["uid"] = "render_heart_demon"
		heart_card["card_id"] = str(heart.card_id)
		heart_card["source_kind"] = "heart"
		heart_card["source_name"] = str(heart.source_name)
		heart_card["upgrade"] = 0
		critical_state.dungeon.run.battle.hand[0] = heart_card
		game.set("run_state", critical_state)
		game.call("_show_dungeon_combat")
	await _settle_frames(4)
	_capture(root, output_root.path_join("dungeon_stress_1440x900.png"), Vector2i(1440, 900),
		"秘境时代心魔临界")
	var elite_state: Dictionary = game.get("run_state")
	elite_state.dungeon.run.stress = 0
	elite_state.dungeon.run.battle = {}
	elite_state.dungeon.run.route_choices = [DungeonSystemScript.route_definition(
		str(elite_state.dungeon.run.era_id), "elite")]
	game.set("run_state", elite_state)
	game.call("_choose_dungeon_route", 0)
	await _settle_frames(4)
	var elite_summary := game.find_child("DungeonFeedbackSummary", true, false) as Label
	if game.find_child("DungeonFeedbackLayer", true, false) == null or elite_summary == null or \
			not elite_summary.text.contains("精英压境"):
		failures.append("精英遭遇没有生成专属入场反馈")
	_capture(root, output_root.path_join("dungeon_elite_1440x900.png"), Vector2i(1440, 900), "秘境精英被动")
	var boss_state: Dictionary = game.get("run_state")
	boss_state.dungeon.run.battle = {}
	boss_state.dungeon.run.route_choices = [DungeonSystemScript.route_definition(
		str(boss_state.dungeon.run.era_id), "boss")]
	game.call("_choose_dungeon_route", 0)
	await _settle_frames(4)
	var boss_summary := game.find_child("DungeonFeedbackSummary", true, false) as Label
	if game.find_child("DungeonFeedbackLayer", true, false) == null or boss_summary == null or \
			not boss_summary.text.contains("首领显形"):
		failures.append("首领遭遇没有生成专属显形反馈")
	_capture(root, output_root.path_join("dungeon_boss_1440x900.png"), Vector2i(1440, 900), "秘境首领法则")
	var phase_state: Dictionary = game.get("run_state")
	var phase_battle: Dictionary = phase_state.dungeon.run.battle
	var phase: Dictionary = phase_battle.get("phase", {})
	phase_battle["phase_active"] = true
	phase_battle["phase_turn"] = int(phase_battle.get("turn", 1))
	phase_battle["enemy_hp"] = maxi(1, int(phase_battle.enemy_max_hp) * int(phase.get("threshold", 50)) / 100)
	var phase_intents: Array = phase.get("intents", [])
	if not phase_intents.is_empty():
		phase_battle["intent_cycle"] = phase_intents.duplicate()
		phase_battle["intent_index"] = 0
		phase_battle["intent"] = str(phase_intents[0])
	phase_state.dungeon.run.battle = phase_battle
	game.set("run_state", phase_state)
	game.set("dungeon_action_feedback", {"kind":"card", "card_name":"引锋式",
		"source_kind":"weapon", "damage":74, "block":0, "hp_delta":-2,
		"stress_delta":0, "enemy_block_delta":0, "attack_power_delta":0,
		"phase_shifted":true, "phase_name":str(phase.get("name", "第二相"))})
	game.call("_show_dungeon_combat")
	await _settle_frames(4)
	var phase_summary := game.find_child("DungeonFeedbackSummary", true, false) as Label
	if game.find_child("DungeonFeedbackLayer", true, false) == null or phase_summary == null or \
			not phase_summary.text.contains("破相"):
		failures.append("首领破相没有生成程序化转场反馈层")
	_capture(root, output_root.path_join("dungeon_boss_phase_1440x900.png"), Vector2i(1440, 900),
		"秘境首领第二相")
	root.size = Vector2i(1280, 720)
	game.set("dungeon_action_feedback", {"kind":"card", "card_name":"引锋式",
		"source_kind":"weapon", "damage":74, "block":0, "hp_delta":-2,
		"stress_delta":0, "enemy_block_delta":0, "attack_power_delta":0,
		"phase_shifted":true, "phase_name":str(phase.get("name", "第二相"))})
	game.call("_show_dungeon_combat")
	await _settle_frames(4)
	var compact_summary := game.find_child("DungeonFeedbackSummary", true, false) as Label
	var compact_card := game.find_child("DungeonCardButton0", true, false) as Control
	var compact_end := game.find_child("DungeonEndTurnButton", true, false) as Control
	var compact_trait := game.find_child("DungeonTraitDescription", true, false) as Label
	var compact_phase := game.find_child("DungeonPhaseDescription", true, false) as Label
	if compact_summary == null or compact_card == null or compact_end == null or \
			compact_trait == null or compact_phase == null or \
			compact_trait.get_theme_font_size("font_size") < 15 or \
			compact_phase.get_theme_font_size("font_size") < 15 or \
			compact_summary.get_global_rect().intersects(compact_card.get_global_rect()) or \
			compact_summary.get_global_rect().intersects(compact_end.get_global_rect()):
		failures.append("1280x720秘境反馈与手牌或操作按钮发生交叠")
	_capture(root, output_root.path_join("dungeon_feedback_1280x720.png"), Vector2i(1280, 720),
		"秘境反馈紧凑布局")
	root.size = Vector2i(1440, 900)
	await _settle_frames(4)
	var victory_state: Dictionary = game.get("run_state")
	var victory_battle: Dictionary = victory_state.dungeon.run.battle
	victory_state.dungeon.run.depth = int(victory_state.dungeon.run.max_depth) - 1
	victory_state.dungeon.run.attack_power = 300
	victory_battle["phase_active"] = true
	victory_battle["enemy_hp"] = 1
	victory_battle["enemy_block"] = 0
	victory_battle["energy"] = 3
	victory_battle["hand"] = [{"uid":"render_finisher", "card_id":"sword_cut", "upgrade":0,
		"source_kind":"story", "source_name":"今身定锚"}]
	victory_battle["draw_pile"] = []
	victory_battle["discard_pile"] = []
	victory_state.dungeon.run.battle = victory_battle
	game.set("run_state", victory_state)
	game.call("_play_dungeon_card", 0)
	await _settle_frames(4)
	var victory_summary := game.find_child("DungeonFeedbackSummary", true, false) as Label
	var victory_layer := game.find_child("DungeonFeedbackLayer", true, false) as Control
	if victory_layer == null or victory_layer.mouse_filter != Control.MOUSE_FILTER_IGNORE or \
			victory_summary == null or not victory_summary.text.contains("镇灭") or \
			not victory_summary.text.contains("修为") or \
			DungeonSystemScript.has_active_run(game.get("run_state")):
		failures.append("首领击破没有生成退场与奖励反馈")
	_capture(root, output_root.path_join("dungeon_boss_victory_1440x900.png"), Vector2i(1440, 900),
		"秘境首领击破结算")

	service.call("clear_slot")
	DirAccess.remove_absolute(save_root)
	game.free()
	if failures.is_empty():
		print("RENDER_CAPTURE_TEST_OK: abilities, encounters, heart demons, boss phases and victory feedback are nonblank")
		quit(0)
	else:
		for failure in failures:
			push_error("RENDER_CAPTURE_TEST_FAILED: %s" % failure)
		quit(1)


func _capture(viewport: Viewport, path: String, expected_size: Vector2i, label: String) -> void:
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		failures.append("%s没有生成图像" % label)
		return
	if image.get_size() != expected_size:
		failures.append("%s尺寸错误：%s" % [label, image.get_size()])
	var minimum_luminance := 1.0
	var maximum_luminance := 0.0
	var opaque_samples := 0
	for y in range(0, image.get_height(), maxi(1, int(image.get_height() / 24.0))):
		for x in range(0, image.get_width(), maxi(1, int(image.get_width() / 32.0))):
			var color := image.get_pixel(x, y)
			var luminance := color.get_luminance()
			minimum_luminance = minf(minimum_luminance, luminance)
			maximum_luminance = maxf(maximum_luminance, luminance)
			if color.a > 0.95:
				opaque_samples += 1
	if maximum_luminance - minimum_luminance < 0.08 or opaque_samples < 100:
		failures.append("%s像素变化不足，疑似空白或未渲染" % label)
	var save_error := image.save_png(path)
	if save_error != OK:
		failures.append("%s无法保存截图：%s" % [label, error_string(save_error)])


func _settle_frames(count: int) -> void:
	for _index in range(count):
		await process_frame
	await RenderingServer.frame_post_draw


func _write_text(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("无法创建渲染测试旧录")
		return
	file.store_string(contents)
	file.close()


func _minimal_legacy_save() -> String:
	return "\n".join([
		"SAVE_V5", "旧录访客", "1", "1", "0", "100", "100", "50", "50",
		"0", "0", "0", "0", "16", "80", "10", "0", "10", "5",
		"5", "5", "5", "5", "5", "0", "0", "0",
		"WORLD_ERA_V1", "古典修仙纪",
		"WORLD_V2", "1", "0", "0", "0",
		"LEGACY_V1", "1", "0", "黑白轮回玉", "0", "0", "未定道痕", "0", "0",
	]) + "\n"
