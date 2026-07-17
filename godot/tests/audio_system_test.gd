extends SceneTree

const AudioDirectorScript = preload("res://scripts/audio_director.gd")
const GameStateScript = preload("res://scripts/game_state.gd")
const SETTINGS_PATH := "user://audio_settings.cfg"

var failures: Array[String] = []
var previous_settings_existed := false
var previous_settings_text := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_backup_settings()
	_validate_bus_layout()
	var director: Node = AudioDirectorScript.new()
	director.name = "AudioDirectorUnderTest"
	root.add_child(director)
	await process_frame
	_validate_director(director)
	_validate_manifest_events(director)
	await _validate_settings_roundtrip(director)
	await _validate_audio_rng_isolation(director)
	await _validate_settings_ui()
	director.queue_free()
	await process_frame
	_restore_settings()
	if failures.is_empty():
		print("AUDIO_SYSTEM_TEST_OK: six-era routing, synchronized three-state music, two-location layered soundscapes, crossfades, buses, pool, settings, accessibility and audio RNG isolation verified")
		quit(0)
	else:
		for failure in failures:
			push_error("AUDIO_SYSTEM_TEST_FAILED: %s" % failure)
		quit(1)


func _validate_bus_layout() -> void:
	var expected := ["Master", "Music", "Ambience", "SFX", "UI", "VO"]
	_expect(AudioServer.bus_count == expected.size(), "总线数量必须恰好覆盖六类产品音频")
	for index in range(mini(AudioServer.bus_count, expected.size())):
		_expect(AudioServer.get_bus_name(index) == expected[index], "总线顺序或名称错误：%s" % expected[index])
		if index > 0:
			_expect(AudioServer.get_bus_send(index) == &"Master", "%s必须汇入Master" % expected[index])
	var master := AudioServer.get_bus_index(&"Master")
	var has_limiter := false
	var has_compressor := false
	var has_stereo_accessibility := false
	for effect_index in range(AudioServer.get_bus_effect_count(master)):
		var effect := AudioServer.get_bus_effect(master, effect_index)
		has_limiter = has_limiter or effect is AudioEffectLimiter
		has_compressor = has_compressor or effect is AudioEffectCompressor
		has_stereo_accessibility = has_stereo_accessibility or effect is AudioEffectStereoEnhance
	_expect(has_limiter and has_compressor and has_stereo_accessibility,
		"Master必须同时拥有安全限幅、夜间动态与单声道辅助处理")


func _validate_director(director: Node) -> void:
	var ids: PackedStringArray = director.call("event_ids")
	for required in ["ui.confirm", "ui.cancel", "combat.impact", "dungeon.card",
		"dungeon.heart", "dungeon.elite_enter", "dungeon.boss_enter", "dungeon.phase_break",
		"dungeon.victory", "dungeon.defeat", "reincarnation.enter"]:
		_expect(required in ids, "AudioDirector缺少稳定事件：%s" % required)
	_expect(int(director.call("debug_pool_size")) == 16, "必须提供12个SFX与4个UI复用声部")
	_expect(int(director.call("debug_ambience_voice_count")) == 4 and
		float(director.call("debug_ambience_crossfade_seconds")) >= 1.0,
		"地点声景的底床与天气点声必须各有独立双声部，不能硬切循环")
	_expect(int(director.call("debug_music_voice_count")) == 2 and
		float(director.call("debug_music_crossfade_seconds")) >= 1.5,
		"音乐必须使用独立双声部和产品级交叉淡化，不能硬切状态或纪元")
	for repeated_event in ["ui.confirm", "ui.cancel", "dungeon.card", "dungeon.impact", "dungeon.guard"]:
		_expect(int(director.call("debug_event_variant_count", repeated_event)) >= 4,
			"高频事件必须至少有四个轮换变体：%s" % repeated_event)
	for era_id in ["classical", "steam", "star_network", "wasteland", "final_age", "immortal_dynasty"]:
		director.call("set_era", era_id)
		var event_path := str(director.call("debug_resolved_asset_path", "card_cast"))
		var ambience_id := "classical_ambience" if era_id == "classical" else "%s_ambience" % era_id
		var ambience_path := str(director.call("debug_resolved_asset_path", ambience_id))
		_expect(str(director.call("get_era")) == era_id and
			event_path.contains("/generated/%s/" % era_id) and
			ambience_path.contains("/generated/%s/" % era_id) and
			ResourceLoader.exists(event_path) and ResourceLoader.exists(ambience_path),
			"纪元必须解析自己的高频交互材质与环境底床：%s" % era_id)
		_expect(str(director.call("debug_resolved_asset_path", "boss_enter")).contains(
			"/generated/classical/boss_enter.wav"), "未完成时代专属终稿时必须稳定回退共享首领语义")
		var soundscape_ids := [
			"classical_ambience" if era_id == "classical" else "%s_ambience" % era_id,
			"%s_world_detail" % era_id,
			"%s_dungeon_ambience" % era_id,
			"%s_dungeon_detail" % era_id,
		]
		for soundscape_id in soundscape_ids:
			var soundscape_path := str(director.call("debug_resolved_asset_path", soundscape_id))
			var soundscape_stream := ResourceLoader.load(soundscape_path)
			_expect(soundscape_path.contains("/generated/%s/" % era_id) and
				soundscape_path.ends_with(".ogg") and soundscape_stream is AudioStreamOggVorbis and
				(soundscape_stream as AudioStreamOggVorbis).loop and
				is_equal_approx((soundscape_stream as AudioStreamOggVorbis).get_length(), 64.0),
				"每个纪元必须解码世界/秘境的底床与天气点声层：%s/%s" % [era_id, soundscape_id])
		for state in ["exploration", "pressure", "decisive"]:
			var music_path := str(director.call("debug_resolved_asset_path", "music_%s" % state))
			var music_stream := ResourceLoader.load(music_path)
			_expect(music_path.contains("/generated/%s/music_%s.ogg" % [era_id, state]) and
				music_stream is AudioStreamOggVorbis and
				(music_stream as AudioStreamOggVorbis).loop and
				is_equal_approx((music_stream as AudioStreamOggVorbis).get_length(), 64.0),
				"每个纪元必须解析并解码自己的64秒流式音乐：%s/%s" % [era_id, state])
	_expect(not bool(director.call("play_event", "missing.event")), "未知事件必须安静降级")
	director.call("set_context", "boss")
	_expect(str(director.call("get_context")) == "boss" and
		str(director.call("get_music_state")) == "decisive" and
		str(director.call("debug_soundscape_location")) == "dungeon",
		"首领上下文必须进入决战音乐和秘境声景")
	director.call("set_context", "combat")
	_expect(str(director.call("get_music_state")) == "pressure" and
		str(director.call("debug_soundscape_location")) == "world",
		"普通战斗上下文必须进入压力音乐和世界声景")
	director.call("set_context", "event")
	_expect(str(director.call("get_music_state")) == "exploration", "事件与阅读上下文必须回到探索音乐")
	director.call("set_context", "not-a-context")
	_expect(str(director.call("get_context")) == "world" and
		str(director.call("get_music_state")) == "exploration", "非法上下文必须稳定回退世界探索混音")
	director.call("set_era", "not-an-era")
	_expect(str(director.call("get_era")) == "classical", "非法纪元必须稳定回退到古典声音语言")
	director.call("debug_reset_cooldowns")
	var first := bool(director.call("play_event", "ui.confirm"))
	var second := bool(director.call("play_event", "ui.confirm"))
	_expect(first and not second, "UI高频事件必须执行防抖冷却")
	director.call("debug_reset_cooldowns")
	_expect(bool(director.call("play_event", "ui.confirm")), "清除冷却后事件必须可再次解析")


func _validate_manifest_events(director: Node) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://audio/audio_manifest_v1.json"))
	_expect(parsed is Dictionary, "音频manifest必须是有效JSON对象")
	if not parsed is Dictionary:
		return
	var registered: PackedStringArray = director.call("event_ids")
	var era_event_counts := {}
	var era_ambience_counts := {}
	var era_music_counts := {}
	var era_soundscape_counts := {}
	var music_sync: Dictionary = (parsed as Dictionary).get("music_sync", {})
	_expect(float(music_sync.get("duration_seconds", 0.0)) == 64.0 and
		int(music_sync.get("tempo_bpm", 0)) == 120 and
		(music_sync.get("states", []) as Array).size() == 3,
		"音乐manifest必须声明统一的64秒、120 BPM三状态同步契约")
	var soundscape_contract: Dictionary = (parsed as Dictionary).get("soundscape_contract", {})
	_expect(float(soundscape_contract.get("duration_seconds", 0.0)) == 64.0 and
		int(soundscape_contract.get("per_era_asset_count", 0)) == 4,
		"声景manifest必须声明每纪元四条世界/秘境双层契约")
	for asset_value in ((parsed as Dictionary).get("assets", []) as Array):
		var asset: Dictionary = asset_value
		if str(asset.get("kind", "")) == "soundscape":
			for era_value in (asset.get("era_ids", []) as Array):
				var soundscape_key := "%s:%s:%s" % [str(era_value),
					str(asset.get("soundscape_location", "")), str(asset.get("soundscape_layer", ""))]
				era_soundscape_counts[soundscape_key] = int(era_soundscape_counts.get(soundscape_key, 0)) + 1
		for event_value in (asset.get("event_ids", []) as Array):
			var event_id := str(event_value)
			if not event_id.begins_with("context.") and not event_id.begins_with("music."):
				_expect(event_id in registered, "manifest引用了未注册事件：%s" % event_id)
			for era_value in (asset.get("era_ids", []) as Array):
				var era_id := str(era_value)
				var key := "%s:%s" % [era_id, event_id]
				era_event_counts[key] = int(era_event_counts.get(key, 0)) + 1
				if event_id == "context.world" and str(asset.get("role", "")) == "ambience":
					era_ambience_counts[era_id] = int(era_ambience_counts.get(era_id, 0)) + 1
				if event_id.begins_with("music.") and str(asset.get("role", "")) == "music":
					era_music_counts[key] = int(era_music_counts.get(key, 0)) + 1
	for era_id in ["classical", "steam", "star_network", "wasteland", "final_age", "immortal_dynasty"]:
		for event_id in ["dungeon.card", "combat.impact", "combat.guard"]:
			_expect(int(era_event_counts.get("%s:%s" % [era_id, event_id], 0)) >= 4,
				"每个纪元的高频事件必须拥有四个独立资产：%s/%s" % [era_id, event_id])
		_expect(int(era_ambience_counts.get(era_id, 0)) == 1,
			"每个纪元必须恰好登记一套世界环境底床：%s" % era_id)
		for state in ["exploration", "pressure", "decisive"]:
			_expect(int(era_music_counts.get("%s:music.%s" % [era_id, state], 0)) == 1,
				"每个纪元必须恰好登记一套三状态音乐：%s/%s" % [era_id, state])
		for location in ["world", "dungeon"]:
			for layer in ["bed", "weather_points"]:
				_expect(int(era_soundscape_counts.get("%s:%s:%s" % [era_id, location, layer], 0)) == 1,
					"每个纪元必须恰好登记世界/秘境底床与天气点声：%s/%s/%s" % [era_id, location, layer])


func _validate_settings_roundtrip(director: Node) -> void:
	director.call("set_bus_percent", "Master", 43.0)
	director.call("set_setting", "night_mode", true)
	director.call("set_setting", "reduce_sudden", true)
	director.call("set_setting", "mono", true)
	director.call("save_settings")
	var second: Node = AudioDirectorScript.new()
	second.name = "AudioDirectorRoundTrip"
	root.add_child(second)
	await process_frame
	var restored: Dictionary = second.call("get_settings")
	_expect(is_equal_approx(float(restored.master), 43.0) and bool(restored.night_mode) and
		bool(restored.reduce_sudden) and bool(restored.mono), "音量与听觉辅助选项必须通过配置往返")
	var master := AudioServer.get_bus_index(&"Master")
	var compressor_enabled := false
	var mono_enabled := false
	for effect_index in range(AudioServer.get_bus_effect_count(master)):
		var effect := AudioServer.get_bus_effect(master, effect_index)
		if effect is AudioEffectCompressor:
			compressor_enabled = AudioServer.is_bus_effect_enabled(master, effect_index)
		elif effect is AudioEffectStereoEnhance:
			mono_enabled = is_zero_approx((effect as AudioEffectStereoEnhance).pan_pullout)
	_expect(compressor_enabled and mono_enabled, "夜间模式与单声道必须实际作用于Master处理链")
	second.queue_free()
	await process_frame


func _validate_audio_rng_isolation(director: Node) -> void:
	var game_state: Dictionary = GameStateScript.create_new_game("听雨人", 718001, [7, 7, 7, 7, 7])
	var gameplay_cursor := int(game_state.get("rng_cursor", -1))
	var audio_cursor_before := int(director.call("debug_audio_cursor"))
	for event_id in ["dungeon.card", "dungeon.impact", "dungeon.guard", "dungeon.stress"]:
		director.call("debug_reset_cooldowns")
		director.call("play_event", event_id)
	_expect(int(game_state.get("rng_cursor", -1)) == gameplay_cursor,
		"声音变体绝不能消耗或写入玩法rng_cursor")
	_expect(int(director.call("debug_audio_cursor")) >= audio_cursor_before + 4,
		"声音变体必须使用独立游标")
	_expect(int(director.call("debug_active_voice_count")) <= int(director.call("debug_pool_size")),
		"并发播放不得突破池上限")
	await process_frame


func _validate_settings_ui() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	_expect(scene != null, "主场景必须可加载")
	if scene == null:
		return
	var main: Control = scene.instantiate()
	root.add_child(main)
	await process_frame
	var era_state: Dictionary = main.get("run_state")
	era_state["current_era_id"] = "steam"
	main.set("run_state", era_state)
	main.call("_set_audio_context", "world")
	var runtime_director: Node = main.get("audio_director")
	_expect(runtime_director != null and str(runtime_director.call("get_era")) == "steam",
		"主场景切换纪元时必须同步切换AudioDirector声音语言")
	main.call("_open_audio_settings")
	await process_frame
	for node_name in ["AudioMasterSlider", "AudioMusicSlider", "AudioAmbienceSlider", "AudioSFXSlider",
		"AudioUISlider", "AudioVOSlider", "AudioMutedToggle", "AudioUnfocusedToggle", "AudioNightToggle",
		"AudioSuddenToggle", "AudioMonoToggle", "AudioPreviewButton", "AudioSettingsBackButton"]:
		_expect(main.find_child(node_name, true, false) != null, "音频设置缺少可访问控件：%s" % node_name)
	var panel := main.find_child("AudioSettingsPanel", true, false) as Control
	var scroll := main.find_child("AudioSettingsScroll", true, false) as ScrollContainer
	_expect(panel != null and scroll != null and scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO,
		"音频设置必须在短窗口中保留真实滚动路径")
	main.queue_free()
	await process_frame


func _backup_settings() -> void:
	previous_settings_existed = FileAccess.file_exists(SETTINGS_PATH)
	if previous_settings_existed:
		previous_settings_text = FileAccess.get_file_as_string(SETTINGS_PATH)


func _restore_settings() -> void:
	if previous_settings_existed:
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(previous_settings_text)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
