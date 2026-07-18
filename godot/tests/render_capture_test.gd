extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const SaveServiceScript = preload("res://scripts/save_service.gd")
const AchievementSystemScript = preload("res://scripts/achievement_system.gd")
const ItemSystemScript = preload("res://scripts/item_system.gd")
const DungeonSystemScript = preload("res://scripts/dungeon_system.gd")
const EventCatalogScript = preload("res://scripts/event_catalog.gd")
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
	var menu_viewport := root.get_visible_rect()
	var menu_scroll := game.find_child("MenuScroll", true, false) as ScrollContainer
	var menu_grid := game.find_child("MenuResponsiveGrid", true, false) as GridContainer
	var menu_panel := game.find_child("MenuPanel", true, false) as Control
	var menu_controls: Array[Control] = [
		game.find_child("DaoNameInput", true, false) as Control,
		game.find_child("ContinueButton", true, false) as Control,
		game.find_child("MenuStartButton", true, false) as Control,
		game.find_child("LegacyImportButton", true, false) as Control,
		game.find_child("MenuAudioSettingsButton", true, false) as Control,
		game.find_child("MenuExitButton", true, false) as Control,
	]
	if menu_scroll == null or menu_grid == null or menu_panel == null or menu_grid.columns != 2:
		failures.append("1280x720主菜单没有启用双栏首屏布局")
	elif menu_scroll.get_v_scroll_bar().visible or not menu_viewport.encloses(menu_panel.get_global_rect()):
		failures.append("1280x720主菜单仍需要滚动或标题卡越出首屏：%s" % [menu_panel.get_global_rect()])
	for control in menu_controls:
		if control == null or not menu_viewport.encloses(control.get_global_rect()):
			failures.append("1280x720主菜单关键操作没有完整落在首屏：%s" % [
				control.name if control != null else "missing"])
	_capture(root, output_root.path_join("menu_1280x720.png"), Vector2i(1280, 720), "主菜单 1280x720")
	root.size = Vector2i(800, 720)
	await _settle_frames(4)
	var narrow_viewport := root.get_visible_rect()
	var narrow_scroll_bar := menu_scroll.get_v_scroll_bar() if menu_scroll != null else null
	if menu_grid == null or menu_grid.columns != 1:
		failures.append("800x720主菜单没有切换到单栏回退布局")
	elif menu_panel == null or menu_panel.size.x > narrow_viewport.size.x:
		failures.append("800x720主菜单标题卡发生横向裁切：%s" % [
			menu_panel.get_global_rect() if menu_panel != null else "missing"])
	if narrow_scroll_bar == null or not narrow_scroll_bar.visible or \
			narrow_scroll_bar.max_value <= narrow_scroll_bar.page:
		failures.append("800x720主菜单没有提供可用的纵向滚动路径")
	_capture(root, output_root.path_join("menu_narrow_top_800x720.png"), Vector2i(800, 720),
		"窄屏主菜单顶部 800x720")
	if menu_scroll != null and narrow_scroll_bar != null:
		menu_scroll.scroll_vertical = int(narrow_scroll_bar.max_value)
		await _settle_frames(4)
		var narrow_exit := game.find_child("MenuExitButton", true, false) as Control
		if narrow_exit == null or not narrow_viewport.encloses(narrow_exit.get_global_rect()):
			failures.append("800x720主菜单滚动到底后末端操作仍不可达")
	_capture(root, output_root.path_join("menu_narrow_bottom_800x720.png"), Vector2i(800, 720),
		"窄屏主菜单底部 800x720")
	root.size = Vector2i(1280, 720)
	await _settle_frames(4)
	game.call("_open_audio_settings")
	await _settle_frames(4)
	var audio_panel := game.find_child("AudioSettingsPanel", true, false) as Control
	var audio_scroll := game.find_child("AudioSettingsScroll", true, false) as ScrollContainer
	if audio_panel == null or audio_scroll == null or audio_panel.size.x < 800.0 or \
			audio_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_AUTO:
		failures.append("1280x720音频设置没有保持清晰宽度与真实滚动路径")
	_capture(root, output_root.path_join("audio_settings_1280x720.png"), Vector2i(1280, 720),
		"音频设置 1280x720")
	root.size = Vector2i(800, 720)
	game.call("_show_audio_settings")
	await _settle_frames(4)
	var narrow_audio_viewport := root.get_visible_rect()
	var narrow_audio_panel := game.find_child("AudioSettingsPanel", true, false) as Control
	var narrow_audio_scroll := game.find_child("AudioSettingsScroll", true, false) as ScrollContainer
	var narrow_audio_grid := game.find_child("AudioAccessibilityGrid", true, false) as GridContainer
	var narrow_audio_master := game.find_child("AudioMasterSlider", true, false) as Control
	if narrow_audio_panel == null or narrow_audio_panel.get_global_rect().size.x > narrow_audio_viewport.size.x:
		failures.append("800x720音律设置面板发生横向裁切：%s" % [
			narrow_audio_panel.get_global_rect() if narrow_audio_panel != null else "missing"])
	if narrow_audio_scroll == null or not narrow_audio_scroll.get_v_scroll_bar().visible:
		failures.append("800x720音律设置没有提供完整的纵向滚动路径")
	if narrow_audio_grid == null or narrow_audio_grid.columns != 1:
		failures.append("800x720音律设置无障碍选项没有切换为单列布局")
	if narrow_audio_master == null or not narrow_audio_viewport.encloses(narrow_audio_master.get_global_rect()):
		failures.append("800x720音律设置首屏总音量不可达")
	_capture(root, output_root.path_join("audio_settings_narrow_top_800x720.png"), Vector2i(800, 720),
		"窄屏音律设置顶部 800x720")
	if narrow_audio_scroll != null:
		narrow_audio_scroll.scroll_vertical = int(narrow_audio_scroll.get_v_scroll_bar().max_value)
		await _settle_frames(4)
	var narrow_audio_mono := game.find_child("AudioMonoToggle", true, false) as Control
	var narrow_audio_back := game.find_child("AudioSettingsBackButton", true, false) as Control
	for audio_control in [narrow_audio_mono, narrow_audio_back]:
		if audio_control == null or not narrow_audio_viewport.encloses(audio_control.get_global_rect()):
			failures.append("800x720音律设置滚动到底后无障碍选项或返回操作不可达")
	_capture(root, output_root.path_join("audio_settings_narrow_bottom_800x720.png"), Vector2i(800, 720),
		"窄屏音律设置底部 800x720")
	game.call("_close_audio_settings")
	root.size = Vector2i(1280, 720)
	await _settle_frames(2)
	DirAccess.remove_absolute(legacy_source_path)
	game.call("_show_game")

	for viewport_size in VIEWPORTS:
		root.size = viewport_size
		await _settle_frames(4)
		if viewport_size == Vector2i(1280, 720):
			var main_viewport := root.get_visible_rect()
			var footer := game.find_child("GameFooter", true, false) as Control
			if footer == null or not root.get_visible_rect().encloses(footer.get_global_rect()):
				failures.append("1280x720主界面页脚没有完整落在视口内：%s" % [
					footer.get_global_rect() if footer != null else "missing"])
			var player_panel := game.find_child("MainPlayerPanel", true, false) as Control
			var main_portrait := game.find_child("MainPortrait", true, false) as TextureRect
			var player_compass := game.find_child("PlayerDaoCompass", true, false) as Control
			var action_panel := game.find_child("GameActionPanel", true, false) as Control
			var action_grid := game.find_child("GameActionGrid", true, false) as GridContainer
			if player_panel == null or player_compass == null or action_panel == null or \
					action_grid == null or action_grid.columns != 2:
				failures.append("1280x720主界面没有启用无裁切人物栏与双列行动栏")
			elif main_portrait == null or main_portrait.texture == null or \
					main_portrait.size.x < 70.0 or main_portrait.size.y < 100.0:
				failures.append("1280x720主界面男主身份图为空或被动效挤出容器")
			elif game.find_child("PlayerPanelScroll", true, false) != null or \
					game.find_child("ActionPanelScroll", true, false) != null:
				failures.append("1280x720主界面人物或行动栏仍依赖纵向滚动")
			elif not main_viewport.encloses(player_compass.get_global_rect()):
				failures.append("1280x720主界面命途罗盘没有完整落在首屏")
			var main_actions: Array[Control] = [
				game.find_child("MeditateButton", true, false) as Control,
				game.find_child("AdventureButton", true, false) as Control,
				game.find_child("BreakthroughButton", true, false) as Control,
				game.find_child("CombatButton", true, false) as Control,
				game.find_child("LocalAIButton", true, false) as Control,
				game.find_child("InventoryButton", true, false) as Control,
				game.find_child("ArmoryButton", true, false) as Control,
				game.find_child("DungeonButton", true, false) as Control,
				game.find_child("SaveGameButton", true, false) as Control,
				game.find_child("GameAudioSettingsButton", true, false) as Control,
				game.find_child("CycleEraButton", true, false) as Control,
				game.find_child("ReturnToMenuButton", true, false) as Control,
			]
			for action in main_actions:
				if action == null or not main_viewport.encloses(action.get_global_rect()):
					failures.append("1280x720主界面行动入口没有完整落在首屏：%s" % [
						action.name if action != null else "missing"])
		_capture(root, output_root.path_join("main_%dx%d.png" % [viewport_size.x, viewport_size.y]),
			viewport_size, "主界面 %dx%d" % [viewport_size.x, viewport_size.y])
	root.size = Vector2i(800, 720)
	game.call("_show_game")
	await _settle_frames(4)
	var narrow_main_viewport := root.get_visible_rect()
	var narrow_main_scroll := game.find_child("GameBodyScroll", true, false) as ScrollContainer
	var narrow_main_body := game.find_child("GameBody", true, false) as Control
	var narrow_main_header := game.find_child("MainHeader", true, false) as Control
	var narrow_main_footer := game.find_child("GameFooter", true, false) as Control
	var narrow_world_pulse := game.find_child("MainWorldPulseCard", true, false) as Control
	if narrow_main_scroll == null or not narrow_main_scroll.get_v_scroll_bar().visible:
		failures.append("800x720主界面没有提供山河叙事到人物行动区的纵向滚动路径")
	if game.find_child("MainWorldScroll", true, false) != null:
		failures.append("800x720主界面仍存在山河叙事与页面级嵌套滚动")
	if narrow_main_body == null or narrow_main_body.get_global_rect().size.x > narrow_main_viewport.size.x:
		failures.append("800x720主界面主体发生横向裁切：%s" % [
			narrow_main_body.get_global_rect() if narrow_main_body != null else "missing"])
	for fixed_control in [narrow_main_header, narrow_main_footer, narrow_world_pulse]:
		if fixed_control == null or not narrow_main_viewport.encloses(fixed_control.get_global_rect()):
			failures.append("800x720主界面固定标题、页脚或山河脉冲不可达")
	_capture(root, output_root.path_join("main_narrow_top_800x720.png"), Vector2i(800, 720),
		"窄屏山河主界面顶部 800x720")
	if narrow_main_scroll != null:
		narrow_main_scroll.scroll_vertical = int(narrow_main_scroll.get_v_scroll_bar().max_value)
		await _settle_frames(4)
	var narrow_main_detail_row := game.find_child("GameNarrowDetailRow", true, false) as Control
	var narrow_main_player := game.find_child("MainPlayerPanel", true, false) as Control
	var narrow_main_actions := game.find_child("GameActionPanel", true, false) as Control
	for detail_control in [narrow_main_detail_row, narrow_main_player, narrow_main_actions]:
		if detail_control == null or not narrow_main_viewport.encloses(detail_control.get_global_rect()):
			failures.append("800x720主界面滚动到底后人物或行动区仍不可达")
	for action_name in ["MeditateButton", "AdventureButton", "BreakthroughButton", "CombatButton",
			"LocalAIButton", "InventoryButton", "ArmoryButton", "DungeonButton", "SaveGameButton",
			"GameAudioSettingsButton", "CycleEraButton", "ReturnToMenuButton"]:
		var narrow_main_action := game.find_child(action_name, true, false) as Control
		if narrow_main_action == null or not narrow_main_viewport.encloses(narrow_main_action.get_global_rect()):
			failures.append("800x720主界面行动入口不可达：%s" % action_name)
	_capture(root, output_root.path_join("main_narrow_bottom_800x720.png"), Vector2i(800, 720),
		"窄屏山河人物与行动 800x720")

	var auxiliary_state: Dictionary = (game.get("run_state") as Dictionary).duplicate(true)
	root.size = Vector2i(1280, 720)
	var inventory_render_state: Dictionary = game.get("run_state")
	ItemSystemScript.add_item(inventory_render_state, "spirit_pill", 1)
	ItemSystemScript.add_item(inventory_render_state, "cloud_robe", 1)
	ItemSystemScript.add_item(inventory_render_state, "black_iron", 2)
	inventory_render_state.player.spirit_stones = 24
	game.set("inventory_notice", "行囊已展开：至少一式配方材料齐备，可直接开炉验收。")
	game.call("_sync_state_views")
	game.call("_show_inventory")
	await _settle_frames(4)
	var auxiliary_viewport := root.get_visible_rect()
	var inventory_controls: Array[Control] = [
		game.find_child("InventoryNoticeCard", true, false) as Control,
		game.find_child("InventoryLoadout", true, false) as Control,
		game.find_child("InventoryListPanel", true, false) as Control,
		game.find_child("ForgePanel", true, false) as Control,
		game.find_child("ForgeRecipe_spirit_blade", true, false) as Control,
		game.find_child("InventoryBackButton", true, false) as Control,
	]
	for control in inventory_controls:
		if control == null or not auxiliary_viewport.encloses(control.get_global_rect()):
			failures.append("1280x720行囊炼器关键区域没有完整落在首屏：%s" % [
				control.name if control != null else "missing"])
	_capture(root, output_root.path_join("inventory_1280x720.png"), Vector2i(1280, 720),
		"行囊炼器 1280x720")
	root.size = Vector2i(800, 720)
	game.call("_show_inventory")
	await _settle_frames(4)
	var narrow_inventory_viewport := root.get_visible_rect()
	var narrow_inventory_scroll := game.find_child("InventoryBodyScroll", true, false) as ScrollContainer
	var narrow_inventory_panel := game.find_child("InventoryListPanel", true, false) as Control
	var narrow_inventory_back := game.find_child("InventoryBackButton", true, false) as Control
	if narrow_inventory_scroll == null or not narrow_inventory_scroll.get_v_scroll_bar().visible:
		failures.append("800x720行囊炼器没有提供上下分段的纵向滚动路径")
	if game.find_child("InventoryListScroll", true, false) != null:
		failures.append("800x720行囊炼器仍存在器物区与页面级嵌套滚动")
	if narrow_inventory_panel == null or narrow_inventory_panel.get_global_rect().size.x > narrow_inventory_viewport.size.x:
		failures.append("800x720行囊器物区发生横向裁切：%s" % [
			narrow_inventory_panel.get_global_rect() if narrow_inventory_panel != null else "missing"])
	if narrow_inventory_back == null or not narrow_inventory_viewport.encloses(narrow_inventory_back.get_global_rect()):
		failures.append("800x720行囊炼器返回入口不可达")
	_capture(root, output_root.path_join("inventory_narrow_top_800x720.png"), Vector2i(800, 720),
		"窄屏行囊顶部 800x720")
	if narrow_inventory_scroll != null:
		narrow_inventory_scroll.scroll_vertical = int(narrow_inventory_scroll.get_v_scroll_bar().max_value)
		await _settle_frames(4)
	var narrow_forge_recipe := game.find_child("ForgeRecipe_spirit_blade", true, false) as Control
	if narrow_forge_recipe == null or not narrow_inventory_viewport.encloses(narrow_forge_recipe.get_global_rect()):
		failures.append("800x720行囊滚动到底后炼器操作仍不可达")
	_capture(root, output_root.path_join("inventory_narrow_bottom_800x720.png"), Vector2i(800, 720),
		"窄屏炼器底部 800x720")
	root.size = Vector2i(1280, 720)

	var armory_state: Dictionary = game.get("run_state")
	armory_state.player.realm_index = 10
	armory_state.player.realm_id = GameStateScript.REALM_IDS[10]
	armory_state.player.battles_won = 100
	armory_state.player.dao_heart = 80
	AchievementSystemScript.check_progress(armory_state)
	AchievementSystemScript.consume_notices(armory_state)
	var render_armory: Dictionary = AchievementSystemScript.normalize(armory_state)
	var qingxiao: Dictionary = render_armory.weapons.qingxiao
	qingxiao["resonance"] = 168
	qingxiao["charge"] = 100
	qingxiao["stage"] = 2
	render_armory.weapons.qingxiao = qingxiao
	render_armory["equipped_id"] = "qingxiao"
	armory_state.legacy.armory = render_armory
	game.call("_show_armory")
	await _settle_frames(4)
	var armory_controls: Array[Control] = [
		game.find_child("AchievementListPanel", true, false) as Control,
		game.find_child("AchievementSummaryCard", true, false) as Control,
		game.find_child("AchievementOverallProgress", true, false) as Control,
		game.find_child("AchievementCard_first_ascension", true, false) as Control,
		game.find_child("AchievementProgress_first_ascension", true, false) as Control,
		game.find_child("JadeArmoryPanel", true, false) as Control,
		game.find_child("ArmoryCurrentCard", true, false) as Control,
		game.find_child("ArmoryResonanceProgress", true, false) as Control,
		game.find_child("ArmoryChargeProgress", true, false) as Control,
		game.find_child("ArmoryCycleButton", true, false) as Control,
		game.find_child("ArmoryInvokeButton", true, false) as Control,
		game.find_child("ArmoryBackButton", true, false) as Control,
		game.find_child("JadeWeaponCard_qingxiao", true, false) as Control,
		game.find_child("JadeWeaponButton_qingxiao", true, false) as Control,
	]
	for control in armory_controls:
		if control == null or not auxiliary_viewport.encloses(control.get_global_rect()):
			failures.append("1280x720成就玉兵关键区域没有完整落在首屏：%s" % [
				control.name if control != null else "missing"])
	if AchievementSystemScript.unlocked_count(armory_state) != 3:
		failures.append("成就玉兵渲染夹具没有保持三项成就与三件玉兵的一致解锁状态")
	var invoke_control := game.find_child("ArmoryInvokeButton", true, false) as Button
	if invoke_control == null or invoke_control.disabled:
		failures.append("满蓄能玉兵在成就玉兵首屏仍无法显圣")
	var zhanjie_button := game.find_child("JadeWeaponButton_zhanjie", true, false) as Button
	if zhanjie_button == null or zhanjie_button.text != "装备":
		failures.append("未装备玉兵的操作按钮必须明确写为装备，不能误导为增加共鸣")
	_capture(root, output_root.path_join("armory_1280x720.png"), Vector2i(1280, 720),
		"成就玉兵 1280x720")
	root.size = Vector2i(800, 720)
	game.call("_show_armory")
	await _settle_frames(4)
	var narrow_armory_viewport := root.get_visible_rect()
	var narrow_armory_body := game.find_child("ArmoryBody", true, false) as Control
	var narrow_armory_back := game.find_child("ArmoryBackButton", true, false) as Control
	if narrow_armory_body == null or narrow_armory_body.get_global_rect().size.x > narrow_armory_viewport.size.x:
		failures.append("800x720成就玉兵主体发生横向裁切：%s" % [
			narrow_armory_body.get_global_rect() if narrow_armory_body != null else "missing"])
	if narrow_armory_back == null or not narrow_armory_viewport.encloses(narrow_armory_back.get_global_rect()):
		failures.append("800x720成就玉兵返回入口不可达")
	_capture(root, output_root.path_join("armory_narrow_800x720.png"), Vector2i(800, 720),
		"成就玉兵 800x720")
	root.size = Vector2i(1280, 720)

	game.set("run_state", auxiliary_state.duplicate(true))
	game.call("_sync_state_views")
	game.set("current_event", {
		"id": "render_lantern_healer", "title": "灯河医契",
		"description": "灯河灵市的药师沈照川拦住你。她手中的旧契记着一名本应死去的散修，而契尾的血印正与你的轮回玉产生同一阵脉动。",
		"scene": "res://art/scenes/lantern_river_spirit_bazaar.png",
		"portrait": "res://art/portraits/jade_healer.jpg",
		"portrait_name": "沈照川", "portrait_title": "镜湖药师 · 旧契守人",
		"character_id": "chi_yaoqing", "motion_profile": "restrained",
		"choices": [
			{"text":"替她验明旧契中的魂息", "deltas":{"exp":18, "dao_heart":2},
				"path_deltas":{"insight":2}, "outcome":"旧契映出一段被宗门抹去的归魂路。"},
			{"text":"以灵石买下契尾血印", "deltas":{"spirit_stones":-4, "reputation":2},
				"path_deltas":{"creation":1}, "outcome":"血印离纸，化作一枚温热的因果种。"},
			{"text":"劝她将旧契投入灯河", "deltas":{"karma":-1, "dao_heart":1},
				"path_deltas":{"compassion":2}, "outcome":"纸灰顺流而下，那名散修的名字却留在你心里。"},
		],
	})
	game.call("_show_event")
	await _settle_frames(4)
	var focused_event_stage := game.find_child("EventStage", true, false) as Control
	if game.find_children("CinematicArtMotion", "Node", true, false).is_empty():
		failures.append("叙事事件没有启用身份安全的人物微动")
	if focused_event_stage == null or \
			focused_event_stage.find_children("*", "TextureRect", true, false).size() != 1 or \
			game.find_child("EventScene", true, false) != null:
		failures.append("人物焦点事件仍在舞台内硬贴两张不同图片")
	var event_controls: Array[Control] = [
		game.find_child("EventHeader", true, false) as Control,
		game.find_child("EventStage", true, false) as Control,
		game.find_child("EventChoicesPanel", true, false) as Control,
		game.find_child("EventChoiceButton0", true, false) as Control,
		game.find_child("EventChoiceButton1", true, false) as Control,
		game.find_child("EventChoiceButton2", true, false) as Control,
		game.find_child("EventFooter", true, false) as Control,
	]
	for control in event_controls:
		if control == null or not auxiliary_viewport.encloses(control.get_global_rect()):
			failures.append("1280x720叙事事件关键区域没有完整落在首屏：%s" % [
				control.name if control != null else "missing"])
	_capture(root, output_root.path_join("event_1280x720.png"), Vector2i(1280, 720),
		"叙事事件 1280x720")
	var imperial_event: Dictionary = {}
	for event_value in EventCatalogScript.load_events():
		if event_value is Dictionary and str((event_value as Dictionary).get("id", "")) == \
				"imperial_falling_skycourt":
			imperial_event = (event_value as Dictionary).duplicate(true)
			break
	if imperial_event.is_empty():
		failures.append("无法加载裴照微V2实机验收事件")
	else:
		game.set("current_event", imperial_event)
		game.call("_show_event")
		await _settle_frames(4)
		var imperial_portrait := game.find_child("EventPortrait", true, false) as TextureRect
		if imperial_portrait == null or imperial_portrait.texture == null or \
				imperial_portrait.texture.resource_path != \
				"res://art/portraits/imperial_sky_inspector_v2.png":
			failures.append("裴照微V2没有进入叙事事件舞台")
		_capture(root, output_root.path_join("event_imperial_v2_1280x720.png"),
			Vector2i(1280, 720), "裴照微V2叙事事件 1280x720")
	var expanded_event: Dictionary = {}
	for event_value in EventCatalogScript.load_events():
		if event_value is Dictionary and str((event_value as Dictionary).get("id", "")) == \
				"imperial_siming_order":
			expanded_event = (event_value as Dictionary).duplicate(true)
			break
	if expanded_event.is_empty():
		failures.append("无法加载扩展后的司命执笔事件")
	else:
		game.set("current_event", expanded_event)
		game.call("_show_event")
		await _settle_frames(4)
		var expanded_description := game.find_child("EventDescription", true, false) as Label
		var expanded_choices := game.find_children("EventChoiceButton*", "Button", true, false)
		if expanded_description == null or expanded_description.text != str(expanded_event.description) or \
				expanded_choices.size() != 3:
			failures.append("扩展事件没有完整进入叙事舞台与三选一交互")
		_capture(root, output_root.path_join("event_content_expansion_1280x720.png"),
			Vector2i(1280, 720), "司命执笔扩展事件 1280x720")
	root.size = Vector2i(800, 720)
	game.call("_show_event")
	await _settle_frames(4)
	var narrow_event_viewport := root.get_visible_rect()
	var narrow_event_scroll := game.find_child("EventBodyScroll", true, false) as ScrollContainer
	var narrow_event_stage := game.find_child("EventStage", true, false) as Control
	var narrow_event_footer := game.find_child("EventFooter", true, false) as Control
	if narrow_event_scroll == null or not narrow_event_scroll.get_v_scroll_bar().visible:
		failures.append("800x720叙事事件没有提供舞台到抉择区的纵向滚动路径")
	if narrow_event_stage == null or narrow_event_stage.get_global_rect().size.x > narrow_event_viewport.size.x:
		failures.append("800x720叙事事件舞台发生横向裁切：%s" % [
			narrow_event_stage.get_global_rect() if narrow_event_stage != null else "missing"])
	if narrow_event_footer == null or not narrow_event_viewport.encloses(narrow_event_footer.get_global_rect()):
		failures.append("800x720叙事事件键盘提示不可达")
	_capture(root, output_root.path_join("event_narrow_top_800x720.png"), Vector2i(800, 720),
		"窄屏叙事舞台 800x720")
	if narrow_event_scroll != null:
		narrow_event_scroll.scroll_vertical = int(narrow_event_scroll.get_v_scroll_bar().max_value)
		await _settle_frames(4)
	for choice_index in range(3):
		var narrow_choice := game.find_child("EventChoiceButton%d" % choice_index, true, false) as Control
		if narrow_choice == null or not narrow_event_viewport.encloses(narrow_choice.get_global_rect()):
			failures.append("800x720叙事事件滚动到底后选择%d仍不可达" % (choice_index + 1))
	_capture(root, output_root.path_join("event_narrow_bottom_800x720.png"), Vector2i(800, 720),
		"窄屏因果抉择 800x720")
	root.size = Vector2i(1280, 720)

	var reincarnation_state := auxiliary_state.duplicate(true)
	reincarnation_state.player.age = reincarnation_state.player.lifespan
	game.set("run_state", reincarnation_state)
	game.call("_sync_state_views")
	game.call("_end_current_life", "寿元耗尽")
	await _settle_frames(4)
	var reincarnation_controls: Array[Control] = [
		game.find_child("ReincarnationCard", true, false) as Control,
		game.find_child("NextLifeNameInput", true, false) as Control,
		game.find_child("NextLifeButton", true, false) as Control,
	]
	for control in reincarnation_controls:
		if control == null or not auxiliary_viewport.encloses(control.get_global_rect()):
			failures.append("1280x720轮回页关键区域没有完整落在首屏：%s" % [
				control.name if control != null else "missing"])
	_capture(root, output_root.path_join("reincarnation_1280x720.png"), Vector2i(1280, 720),
		"轮回页 1280x720")
	root.size = Vector2i(800, 720)
	game.call("_show_reincarnation")
	await _settle_frames(4)
	var narrow_reincarnation_viewport := root.get_visible_rect()
	var narrow_reincarnation_scroll := game.find_child("ReincarnationScroll", true, false) as ScrollContainer
	var narrow_reincarnation_card := game.find_child("ReincarnationCard", true, false) as Control
	var narrow_reincarnation_input := game.find_child("NextLifeNameInput", true, false) as Control
	var narrow_reincarnation_button := game.find_child("NextLifeButton", true, false) as Control
	if narrow_reincarnation_scroll == null or narrow_reincarnation_scroll.horizontal_scroll_mode != \
			ScrollContainer.SCROLL_MODE_DISABLED:
		failures.append("800x720轮回页没有提供禁止横向越界的页面容器")
	if narrow_reincarnation_card == null or \
			narrow_reincarnation_card.get_global_rect().size.x > narrow_reincarnation_viewport.size.x:
		failures.append("800x720轮回卡发生横向裁切：%s" % [
			narrow_reincarnation_card.get_global_rect() if narrow_reincarnation_card != null else "missing"])
	for narrow_reincarnation_control in [narrow_reincarnation_input, narrow_reincarnation_button]:
		if narrow_reincarnation_control == null or \
				not narrow_reincarnation_viewport.encloses(narrow_reincarnation_control.get_global_rect()):
			failures.append("800x720轮回页新世道号或继续操作不可达")
	_capture(root, output_root.path_join("reincarnation_narrow_800x720.png"), Vector2i(800, 720),
		"窄屏轮回页 800x720")
	root.size = Vector2i(1280, 720)
	game.set("run_state", auxiliary_state)
	game.set("current_event", {})
	game.set("achievement_notice_queue", [])
	game.call("_sync_state_views")
	game.call("_show_game")
	await _settle_frames(2)

	var pre_combat_state: Dictionary = (game.get("run_state") as Dictionary).duplicate(true)
	root.size = Vector2i(1280, 720)
	game.call("_start_combat")
	await _settle_frames(4)
	var combat_viewport := root.get_visible_rect()
	var combat_player_panel := game.find_child("CombatPlayerPanel", true, false) as Control
	var combat_enemy_panel := game.find_child("CombatEnemyPanel", true, false) as Control
	var combat_forecast_card := game.find_child("CombatForecastCard", true, false) as Control
	var combat_forecast_range := game.find_child("CombatForecastRange", true, false) as Label
	var combat_counterplay := game.find_child("CombatCounterplay", true, false) as Label
	var combat_timeline := game.find_child("CombatIntentTimeline", true, false) as HBoxContainer
	var combat_player_forecast := game.find_child("CombatPlayerDamageForecast", true, false) as Label
	if combat_player_panel == null or combat_enemy_panel == null or combat_forecast_card == null or \
			combat_forecast_range == null or combat_counterplay == null or combat_timeline == null or \
			combat_player_forecast == null:
		failures.append("1280x720普通战斗缺少规则驱动的双方预测与战术卡")
	elif combat_timeline.get_child_count() < 3 or not combat_forecast_range.text.contains("预计") or \
			combat_counterplay.text.is_empty() or not combat_player_forecast.text.contains("斩击"):
		failures.append("1280x720普通战斗没有显示三步意图轮转与行动收益")
	var combat_controls: Array[Control] = [
		combat_player_panel, combat_enemy_panel, combat_forecast_card, combat_timeline,
		game.find_child("CombatAttackButton", true, false) as Control,
		game.find_child("CombatGuardButton", true, false) as Control,
		game.find_child("CombatSpellButton", true, false) as Control,
		game.find_child("CombatPillButton", true, false) as Control,
		game.find_child("CombatFleeButton", true, false) as Control,
	]
	for control in combat_controls:
		if control == null or not combat_viewport.encloses(control.get_global_rect()):
			failures.append("1280x720普通战斗关键战术信息没有完整落在首屏：%s" % [
				control.name if control != null else "missing"])
	var full_hp_pill_button := game.find_child("CombatPillButton", true, false) as Button
	if full_hp_pill_button == null or not full_hp_pill_button.disabled or \
			not full_hp_pill_button.text.contains("气血已满"):
		failures.append("普通战斗满血状态没有阻止并解释疗伤丹浪费")
	_capture(root, output_root.path_join("normal_combat_1280x720.png"), Vector2i(1280, 720),
		"普通战斗 1280x720")
	root.size = Vector2i(1440, 900)
	await _settle_frames(4)
	_capture(root, output_root.path_join("normal_combat_1440x900.png"), Vector2i(1440, 900),
		"普通战斗 1440x900")
	root.size = Vector2i(800, 720)
	game.call("_show_combat")
	await _settle_frames(4)
	var narrow_combat_viewport := root.get_visible_rect()
	var narrow_combat_scroll := game.find_child("CombatBodyScroll", true, false) as ScrollContainer
	var narrow_combat_body := game.find_child("CombatBody", true, false) as Control
	var narrow_combat_stage := game.find_child("CombatStage", true, false) as Control
	var narrow_combat_status_row := game.find_child("CombatNarrowStatusRow", true, false) as Control
	var narrow_combat_header := game.find_child("CombatHeader", true, false) as Control
	var narrow_combat_actions := game.find_child("CombatActionBar", true, false) as Control
	if narrow_combat_scroll == null or not narrow_combat_scroll.get_v_scroll_bar().visible:
		failures.append("800x720普通战斗没有提供战场到双方详情的纵向滚动路径")
	if narrow_combat_body == null or narrow_combat_body.get_global_rect().size.x > narrow_combat_viewport.size.x:
		failures.append("800x720普通战斗主体发生横向裁切：%s" % [
			narrow_combat_body.get_global_rect() if narrow_combat_body != null else "missing"])
	if narrow_combat_stage == null or not narrow_combat_viewport.encloses(narrow_combat_stage.get_global_rect()):
		failures.append("800x720普通战斗首屏没有完整显示交锋舞台")
	for fixed_control in [narrow_combat_header, narrow_combat_actions]:
		if fixed_control == null or not narrow_combat_viewport.encloses(fixed_control.get_global_rect()):
			failures.append("800x720普通战斗固定标题或操作区不可达")
	for action_name in ["CombatAttackButton", "CombatGuardButton", "CombatSpellButton",
			"CombatPillButton", "CombatFleeButton"]:
		var narrow_action := game.find_child(action_name, true, false) as Control
		if narrow_action == null or not narrow_combat_viewport.encloses(narrow_action.get_global_rect()):
			failures.append("800x720普通战斗操作不可达：%s" % action_name)
	_capture(root, output_root.path_join("normal_combat_narrow_top_800x720.png"), Vector2i(800, 720),
		"窄屏普通战斗舞台 800x720")
	if narrow_combat_scroll != null:
		narrow_combat_scroll.scroll_vertical = int(narrow_combat_scroll.get_v_scroll_bar().max_value)
		await _settle_frames(4)
	var narrow_player_panel := game.find_child("CombatPlayerPanel", true, false) as Control
	var narrow_enemy_panel := game.find_child("CombatEnemyPanel", true, false) as Control
	for detail_control in [narrow_combat_status_row, narrow_player_panel, narrow_enemy_panel]:
		if detail_control == null or not narrow_combat_viewport.encloses(detail_control.get_global_rect()):
			failures.append("800x720普通战斗滚动到底后双方详情仍不可达")
	_capture(root, output_root.path_join("normal_combat_narrow_bottom_800x720.png"), Vector2i(800, 720),
		"窄屏普通战斗双方详情 800x720")
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
	root.size = Vector2i(800, 720)
	game.call("_show_dungeon_route")
	await _settle_frames(4)
	var narrow_route_viewport := root.get_visible_rect()
	var narrow_route_scroll := game.find_child("DungeonRouteScroll", true, false) as ScrollContainer
	var narrow_route_content := game.find_child("DungeonRouteContent", true, false) as Control
	var narrow_route_header := game.find_child("DungeonHeader", true, false) as Control
	var narrow_route_footer := game.find_child("DungeonRouteFooter", true, false) as Control
	var narrow_route_trail := game.find_child("DungeonRouteTrail", true, false) as Control
	if narrow_route_scroll == null or not narrow_route_scroll.get_v_scroll_bar().visible:
		failures.append("800x720秘境路线没有提供因果图到选路区的纵向滚动路径")
	if game.find_child("DungeonRouteJournalScroll", true, false) != null:
		failures.append("800x720秘境路线仍存在日志与页面级嵌套滚动")
	if narrow_route_content == null or narrow_route_content.get_global_rect().size.x > narrow_route_viewport.size.x:
		failures.append("800x720秘境路线主体发生横向裁切：%s" % [
			narrow_route_content.get_global_rect() if narrow_route_content != null else "missing"])
	for narrow_route_control in [narrow_route_header, narrow_route_footer, narrow_route_trail]:
		if narrow_route_control == null or not narrow_route_viewport.encloses(narrow_route_control.get_global_rect()):
			failures.append("800x720秘境路线页首、页脚或因果图不可达")
	_capture(root, output_root.path_join("dungeon_route_narrow_top_800x720.png"), Vector2i(800, 720),
		"窄屏秘境路线因果图 800x720")
	if narrow_route_scroll != null:
		for route_choice_index in range((game.get("run_state").dungeon.run.route_choices as Array).size()):
			var narrow_route_button := game.find_child("DungeonRouteButton%d" % route_choice_index,
				true, false) as Control
			if narrow_route_button != null:
				narrow_route_scroll.ensure_control_visible(narrow_route_button)
				await _settle_frames(2)
			if narrow_route_button == null or not narrow_route_viewport.encloses(narrow_route_button.get_global_rect()):
				failures.append("800x720秘境路线选择不可达：%d" % (route_choice_index + 1))
		narrow_route_scroll.scroll_vertical = int(narrow_route_scroll.get_v_scroll_bar().max_value)
		await _settle_frames(4)
	var narrow_route_abandon := game.find_child("DungeonAbandonButton", true, false) as Control
	if narrow_route_abandon == null or not narrow_route_viewport.encloses(narrow_route_abandon.get_global_rect()):
		failures.append("800x720秘境路线滚动到底后撤离操作不可达")
	_capture(root, output_root.path_join("dungeon_route_narrow_bottom_800x720.png"), Vector2i(800, 720),
		"窄屏秘境路线选择 800x720")
	root.size = Vector2i(1440, 900)
	game.call("_show_dungeon_route")
	await _settle_frames(4)
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
	root.size = Vector2i(800, 720)
	game.call("_show_dungeon_combat")
	await _settle_frames(4)
	var narrow_dungeon_viewport := root.get_visible_rect()
	var narrow_dungeon_scroll := game.find_child("DungeonCombatScroll", true, false) as ScrollContainer
	var narrow_dungeon_body := game.find_child("DungeonCombatBody", true, false) as Control
	var narrow_dungeon_status := game.find_child("DungeonCombatStatusRow", true, false) as Control
	var narrow_dungeon_header := game.find_child("DungeonHeader", true, false) as Control
	var narrow_dungeon_actions := game.find_child("DungeonCombatActions", true, false) as Control
	var narrow_dungeon_hand := game.find_child("DungeonHandGrid", true, false) as GridContainer
	if narrow_dungeon_scroll == null or not narrow_dungeon_scroll.get_v_scroll_bar().visible:
		failures.append("800x720秘境战斗没有提供双方状态到两列手牌的纵向滚动路径")
	if game.find_child("DungeonEnemyScroll", true, false) != null or \
			game.find_child("DungeonHandScroll", true, false) != null or \
			game.find_child("DungeonLogScroll", true, false) != null:
		failures.append("800x720秘境战斗仍存在敌方、日志或手牌嵌套滚动")
	if narrow_dungeon_body == null or narrow_dungeon_body.get_global_rect().size.x > narrow_dungeon_viewport.size.x:
		failures.append("800x720秘境战斗主体发生横向裁切：%s" % [
			narrow_dungeon_body.get_global_rect() if narrow_dungeon_body != null else "missing"])
	if narrow_dungeon_hand == null or narrow_dungeon_hand.columns != 2:
		failures.append("800x720秘境战斗手牌没有切换为两列布局")
	for narrow_dungeon_control in [narrow_dungeon_header, narrow_dungeon_actions, narrow_dungeon_status]:
		if narrow_dungeon_control == null or not narrow_dungeon_viewport.encloses(narrow_dungeon_control.get_global_rect()):
			failures.append("800x720秘境战斗页首、固定操作或双方状态不可达")
	_capture(root, output_root.path_join("dungeon_combat_narrow_top_800x720.png"), Vector2i(800, 720),
		"窄屏秘境战斗双方状态 800x720")
	if narrow_dungeon_scroll != null:
		narrow_dungeon_scroll.scroll_vertical = int(narrow_dungeon_scroll.get_v_scroll_bar().max_value)
		await _settle_frames(4)
	var narrow_dungeon_cards := game.find_children("DungeonCardButton*", "Button", true, false)
	for narrow_card_value in narrow_dungeon_cards:
		var narrow_card := narrow_card_value as Control
		if narrow_card == null or not narrow_dungeon_viewport.encloses(narrow_card.get_global_rect()):
			failures.append("800x720秘境战斗滚动到底后仍有手牌不可达")
	for action_name in ["DungeonEndTurnButton", "DungeonCombatAbandonButton"]:
		var narrow_dungeon_action := game.find_child(action_name, true, false) as Control
		if narrow_dungeon_action == null or not narrow_dungeon_viewport.encloses(narrow_dungeon_action.get_global_rect()):
			failures.append("800x720秘境战斗固定操作不可达：%s" % action_name)
	_capture(root, output_root.path_join("dungeon_combat_narrow_bottom_800x720.png"), Vector2i(800, 720),
		"窄屏秘境战斗两列手牌 800x720")
	root.size = Vector2i(1440, 900)
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
