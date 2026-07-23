extends SceneTree

const AudioDirectorScript = preload("res://scripts/audio_director.gd")
const GameStateScript = preload("res://scripts/game_state.gd")
const MANIFEST_PATH := "res://audio/audio_manifest_v2.json"
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
	_validate_manifest(director)
	await _validate_settings_roundtrip(director)
	await _validate_audio_rng_isolation(director)
	await _validate_settings_ui()
	director.call("shutdown_for_exit")
	director.call("shutdown_for_exit")
	_expect(int(director.call("debug_active_voice_count")) == 0 and
		int(director.call("debug_ambience_playing_voice_count")) == 0 and
		int(director.call("debug_ambience_stream_reference_count")) == 0 and
		int(director.call("debug_music_playing_voice_count")) == 0 and
		int(director.call("debug_stream_reference_count")) == 0,
		"AudioDirector shutdown must be idempotent and release every stream")
	director.queue_free()
	await process_frame
	_restore_settings()
	if failures.is_empty():
		print("AUDIO_SYSTEM_TEST_OK: curated manifest v2, non-loop playlists, manifest-only ambience looping, shared era routing, buses, settings and RNG isolation verified")
		quit(0)
	else:
		for failure in failures:
			push_error("AUDIO_SYSTEM_TEST_FAILED: %s" % failure)
		quit(1)


func _validate_bus_layout() -> void:
	var expected := ["Master", "Music", "Ambience", "SFX", "UI", "VO"]
	_expect(AudioServer.bus_count == expected.size(), "audio bus count must cover six product buses")
	for index in range(mini(AudioServer.bus_count, expected.size())):
		_expect(AudioServer.get_bus_name(index) == expected[index],
			"audio bus order/name mismatch: %s" % expected[index])
		if index > 0:
			_expect(AudioServer.get_bus_send(index) == &"Master", "%s must feed Master" % expected[index])
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
		"Master must retain limiter, night dynamics and mono accessibility processing")


func _validate_director(director: Node) -> void:
	_expect(int(director.call("debug_manifest_version")) == 2,
		"AudioDirector must load curated manifest v2")
	var ids: PackedStringArray = director.call("event_ids")
	for required in ["ui.confirm", "ui.cancel", "combat.impact", "dungeon.card",
			"dungeon.heart", "dungeon.elite_enter", "dungeon.boss_enter",
			"dungeon.phase_break", "dungeon.victory", "dungeon.defeat",
			"reincarnation.enter", "combat.spell", "combat.guard", "combat.recover",
			"combat.heal", "combat.status", "combat.victory", "combat.defeat"]:
		_expect(required in ids, "AudioDirector is missing stable event: %s" % required)
	_expect(int(director.call("debug_pool_size")) == 16,
		"AudioDirector must retain twelve SFX and four UI pooled voices")
	_expect(int(director.call("debug_ambience_voice_count")) == 4 and
		float(director.call("debug_ambience_crossfade_seconds")) >= 1.0,
		"soundscape bed/detail layers must retain independent crossfade voices")
	_expect(int(director.call("debug_music_voice_count")) == 2 and
		float(director.call("debug_music_crossfade_seconds")) >= 1.5,
		"music state changes must retain two-voice crossfading")
	for repeated_event in ["ui.confirm", "ui.cancel", "dungeon.card", "combat.impact", "combat.guard"]:
		_expect(int(director.call("debug_event_variant_count", repeated_event)) >= 3,
			"high-frequency event needs at least three curated variants: %s" % repeated_event)
	for repeated_event in ["combat.recover", "combat.heal", "combat.status"]:
		_expect(int(director.call("debug_event_variant_count", repeated_event)) >= 2,
			"recovery/status event needs at least two curated variants: %s" % repeated_event)
	var semantic_categories := {
		"combat.impact": "weapon_impact",
		"combat.guard": "shield_guard",
		"combat.spell": "spell_cast",
		"combat.recover": "recovery",
		"combat.status": "status",
		"dungeon.phase_break": "phase_change",
		"combat.victory": "victory",
		"combat.defeat": "defeat",
	}
	var semantic_assets := {}
	for event_id in semantic_categories:
		_expect(str(director.call("debug_event_semantic_category", event_id)) ==
			str(semantic_categories[event_id]),
			"combat event semantic category mismatch: %s" % event_id)
		var event_assets: PackedStringArray = director.call("debug_event_asset_ids", event_id)
		_expect(not event_assets.is_empty(), "semantic event must resolve assets: %s" % event_id)
		for asset_id in event_assets:
			_expect(not semantic_assets.has(asset_id),
				"distinct semantic categories must not share an asset: %s" % asset_id)
			semantic_assets[asset_id] = event_id

	var stable_paths := {
		"music": str(director.call("debug_resolved_asset_path", "music_sunrise")),
		"ambience": str(director.call("debug_resolved_asset_path", "ambience_dungeon_loop")),
		"ui": str(director.call("debug_resolved_asset_path", "sfx_ui_confirm_01")),
	}
	for path_value in stable_paths.values():
		_expect(not str(path_value).is_empty() and ResourceLoader.exists(str(path_value)),
			"curated runtime asset must resolve through manifest: %s" % str(path_value))
	for era_id in ["classical", "steam", "star_network", "wasteland", "final_age", "immortal_dynasty"]:
		director.call("set_era", era_id)
		_expect(str(director.call("get_era")) == era_id,
			"valid era must remain selected: %s" % era_id)
		_expect(str(director.call("debug_resolved_asset_path", "music_sunrise")) == stable_paths.music and
			str(director.call("debug_resolved_asset_path", "ambience_dungeon_loop")) == stable_paths.ambience and
			str(director.call("debug_resolved_asset_path", "sfx_ui_confirm_01")) == stable_paths.ui,
			"all eras must share the curated manifest paths without legacy fallback: %s" % era_id)

	director.call("set_context", "boss")
	_expect(str(director.call("get_music_state")) == "decisive" and
		str(director.call("debug_soundscape_location")) == "dungeon",
		"boss context must map to decisive music and dungeon soundscape")
	director.call("set_context", "combat")
	_expect(str(director.call("get_music_state")) == "pressure" and
		str(director.call("debug_soundscape_location")) == "world",
		"combat context must map to pressure music and world soundscape")
	director.call("set_context", "event")
	_expect(str(director.call("get_music_state")) == "exploration",
		"reading/event context must return to exploration music")
	director.call("set_context", "not-a-context")
	_expect(str(director.call("get_context")) == "world" and
		str(director.call("get_music_state")) == "exploration",
		"unknown context must fall back to world/exploration")
	director.call("set_era", "not-an-era")
	_expect(str(director.call("get_era")) == "classical",
		"unknown era must fall back to classical without changing asset paths")

	var exploration: PackedStringArray = director.call("debug_music_playlist", "exploration")
	_expect(exploration.size() >= 3, "exploration playlist needs at least three long-form tracks")
	director.call("set_context", "world")
	var first_track := str(director.call("debug_advance_music_playlist"))
	var second_track := str(director.call("debug_advance_music_playlist"))
	_expect(first_track in exploration and second_track in exploration and first_track != second_track,
		"playlist advancement must be deterministic and rotate within the active state")
	_expect(is_zero_approx(float(director.call("debug_last_music_start_position"))) and
		is_zero_approx(float(director.call("debug_transition_start_position",
			"music_sunrise", "music_eastern_dreams", 57.0))),
		"independent non-loop music must start at zero and never inherit playback phase")

	_expect(not bool(director.call("play_event", "missing.event")),
		"unknown audio event must fail quietly")
	director.call("debug_reset_cooldowns")
	var first := bool(director.call("play_event", "ui.confirm"))
	var second := bool(director.call("play_event", "ui.confirm"))
	_expect(first and not second, "UI event cooldown must remain active in Dummy/headless runs")
	director.call("debug_reset_cooldowns")
	_expect(bool(director.call("play_event", "ui_confirm")),
		"legacy event aliases must continue resolving through manifest v2")
	director.call("debug_reset_cooldowns")
	_expect(bool(director.call("play_event", "heal")) and
		str(director.call("debug_event_semantic_category", "heal")) == "recovery",
		"gameplay recovery aliases must resolve to the dedicated recovery category")


func _validate_manifest(director: Node) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_expect(parsed is Dictionary, "audio manifest v2 must be valid JSON")
	if not parsed is Dictionary:
		return
	var manifest := parsed as Dictionary
	_expect(int(manifest.get("version", 0)) == 2 and
		str(manifest.get("schema", "")) == "curated-audio-v2",
		"audio manifest must declare the curated v2 schema")
	var assets_by_id := {}
	var music_count := 0
	var ambience_count := 0
	var sfx_count := 0
	for asset_value in (manifest.get("assets", []) as Array):
		_expect(asset_value is Dictionary, "every manifest asset must be an object")
		if not asset_value is Dictionary:
			continue
		var asset := asset_value as Dictionary
		var asset_id := str(asset.get("id", ""))
		_expect(not asset_id.is_empty() and not assets_by_id.has(asset_id),
			"manifest asset IDs must be non-empty and unique: %s" % asset_id)
		assets_by_id[asset_id] = asset
		var runtime_path := str(asset.get("runtime_path", ""))
		_expect(runtime_path.begins_with("res://audio/") and ResourceLoader.exists(runtime_path),
			"manifest runtime path must stay inside audio root and resolve: %s" % runtime_path)
		_expect(str(asset.get("sha256", "")).length() == 64 and
			str(asset.get("source_sha256", "")).length() == 64 and
			str(asset.get("source_url", "")).begins_with("https://") and
			not str(asset.get("creator", "")).is_empty() and
			not str(asset.get("attribution_text", "")).is_empty() and
			FileAccess.file_exists(str(asset.get("license_file", ""))),
			"asset provenance must include hashes, HTTPS source, creator, attribution and license: %s" % asset_id)
		_expect(bool(asset.get("commercial_use", false)) and
			bool(asset.get("redistribution_in_game", false)) and
			str(asset.get("release_state", "")) == "final",
			"runtime asset must be commercially redistributable and final: %s" % asset_id)
		var stream := ResourceLoader.load(runtime_path)
		_expect(stream is AudioStreamOggVorbis,
			"all curated runtime assets must decode as Ogg Vorbis: %s" % asset_id)
		if stream is AudioStreamOggVorbis:
			_expect(not (stream as AudioStreamOggVorbis).loop,
				"Ogg importer must remain non-looping; runtime manifest owns loop policy: %s" % asset_id)
		var role := str(asset.get("role", ""))
		if role == "music":
			music_count += 1
			_expect(not bool(asset.get("loop", true)) and asset.get("loop_start_sample") == null and
				asset.get("loop_end_sample") == null and float(asset.get("duration", 0.0)) > 90.0,
				"long-form music must be non-looping with null loop points: %s" % asset_id)
			_expect(not bool(director.call("debug_loaded_stream_loop_enabled", asset_id)),
				"runtime must not force curated music into a loop: %s" % asset_id)
		elif role == "ambience":
			ambience_count += 1
			_expect(bool(asset.get("loop", false)) and int(asset.get("loop_end_sample", 0)) > 0,
				"ambience loop range must be explicit in manifest: %s" % asset_id)
			_expect(bool(director.call("debug_loaded_stream_loop_enabled", asset_id)),
				"runtime duplicate must enable looping only for manifest-loop ambience: %s" % asset_id)
		if str(asset.get("kind", "")) == "sfx":
			sfx_count += 1
	_expect(music_count >= 6 and ambience_count >= 2 and sfx_count >= 24 and sfx_count <= 32,
		"curated set must contain 6+ music, 2+ ambience and 24-32 selected SFX")

	var playlists: Dictionary = manifest.get("music_playlists", {})
	for state in ["exploration", "pressure", "decisive"]:
		var playlist: Array = playlists.get(state, [])
		var minimum_variants := 3 if state in ["exploration", "pressure"] else 2
		_expect(playlist.size() >= minimum_variants,
			"music playlist needs curated variants: %s" % state)
		for asset_id_value in playlist:
			var asset_id := str(asset_id_value)
			_expect(assets_by_id.has(asset_id) and
				str((assets_by_id.get(asset_id, {}) as Dictionary).get("role", "")) == "music",
				"playlist must reference a registered music asset: %s/%s" % [state, asset_id])
	var soundscapes: Dictionary = manifest.get("soundscapes", {})
	for location in ["world", "dungeon"]:
		var soundscape: Dictionary = soundscapes.get(location, {})
		var bed_id := str(soundscape.get("bed", ""))
		_expect(assets_by_id.has(bed_id) and bool((assets_by_id[bed_id] as Dictionary).get("loop", false)),
			"soundscape bed must reference a registered loop asset: %s" % location)
	_expect(str((soundscapes.get("world", {}) as Dictionary).get("bed", "")) !=
		str((soundscapes.get("dungeon", {}) as Dictionary).get("bed", "")),
		"world and dungeon must have distinct ambience beds")
	var registered: PackedStringArray = director.call("event_ids")
	for event_id_value in (manifest.get("events", {}) as Dictionary).keys():
		var event_id := str(event_id_value)
		_expect(event_id in registered, "manifest event must be exposed by AudioDirector: %s" % event_id)
		var event: Dictionary = (manifest.get("events", {}) as Dictionary).get(event_id, {})
		for asset_id_value in (event.get("asset_ids", []) as Array):
			_expect(assets_by_id.has(str(asset_id_value)),
				"manifest event references an unknown asset: %s/%s" % [event_id, str(asset_id_value)])


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
		bool(restored.reduce_sudden) and bool(restored.mono),
		"audio volume and accessibility settings must round-trip through ConfigFile")
	var master := AudioServer.get_bus_index(&"Master")
	var compressor_enabled := false
	var mono_enabled := false
	for effect_index in range(AudioServer.get_bus_effect_count(master)):
		var effect := AudioServer.get_bus_effect(master, effect_index)
		if effect is AudioEffectCompressor:
			compressor_enabled = AudioServer.is_bus_effect_enabled(master, effect_index)
		elif effect is AudioEffectStereoEnhance:
			mono_enabled = is_zero_approx((effect as AudioEffectStereoEnhance).pan_pullout)
	_expect(compressor_enabled and mono_enabled,
		"night mode and mono accessibility must affect the Master processing chain")
	second.call("shutdown_for_exit")
	second.queue_free()
	await process_frame


func _validate_audio_rng_isolation(director: Node) -> void:
	var game_state: Dictionary = GameStateScript.create_new_game("Audio RNG Test", 718001, [7, 7, 7, 7, 7])
	var gameplay_cursor := int(game_state.get("rng_cursor", -1))
	var audio_cursor_before := int(director.call("debug_audio_cursor"))
	for event_id in ["dungeon.card", "dungeon.impact", "dungeon.guard", "dungeon.stress"]:
		director.call("debug_reset_cooldowns")
		director.call("play_event", event_id)
	_expect(int(game_state.get("rng_cursor", -1)) == gameplay_cursor,
		"audio variation must never consume gameplay RNG")
	_expect(int(director.call("debug_audio_cursor")) >= audio_cursor_before + 4,
		"audio variation must use its independent cursor")
	_expect(int(director.call("debug_active_voice_count")) <= int(director.call("debug_pool_size")),
		"concurrent playback must never exceed the voice pool")
	await process_frame


func _validate_settings_ui() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	_expect(scene != null, "main scene must remain loadable")
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
		"main scene era changes must still synchronize AudioDirector")
	main.call("_open_audio_settings")
	await process_frame
	for node_name in ["AudioMasterSlider", "AudioMusicSlider", "AudioAmbienceSlider", "AudioSFXSlider",
			"AudioUISlider", "AudioVOSlider", "AudioMutedToggle", "AudioUnfocusedToggle",
			"AudioNightToggle", "AudioSuddenToggle", "AudioMonoToggle", "AudioPreviewButton",
			"AudioSettingsBackButton"]:
		_expect(main.find_child(node_name, true, false) != null,
			"audio settings is missing accessible control: %s" % node_name)
	var panel := main.find_child("AudioSettingsPanel", true, false) as Control
	var scroll := main.find_child("AudioSettingsScroll", true, false) as ScrollContainer
	_expect(panel != null and scroll != null and
		scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO,
		"audio settings must retain a real scroll path on short windows")
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
