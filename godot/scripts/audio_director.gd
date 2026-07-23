extends Node
class_name AudioDirector

const SETTINGS_PATH := "user://audio_settings.cfg"
const MANIFEST_PATH := "res://audio/audio_manifest_v2.json"
const BUS_NAMES: PackedStringArray = ["Master", "Music", "Ambience", "SFX", "UI", "VO"]
const SFX_POOL_SIZE := 12
const UI_POOL_SIZE := 4
const SILENCE_DB := -80.0
const AMBIENCE_CROSSFADE_SECONDS := 1.25
const AMBIENCE_DETAIL_TRIM_DB := -4.0
const MUSIC_CROSSFADE_SECONDS := 1.75
const ERA_IDS: PackedStringArray = [
	"classical", "steam", "star_network", "wasteland", "final_age", "immortal_dynasty",
]

const DEFAULT_SETTINGS := {
	"master": 100.0,
	"music": 72.0,
	"ambience": 62.0,
	"sfx": 86.0,
	"ui": 74.0,
	"vo": 100.0,
	"muted": false,
	"mute_unfocused": true,
	"night_mode": false,
	"reduce_sudden": false,
	"mono": false,
}

const CONTEXT_PROFILES := {
	"menu": {"ambience_db": -10.0, "music_db": -4.0},
	"world": {"ambience_db": -7.0, "music_db": -2.0},
	"event": {"ambience_db": -11.0, "music_db": -4.0},
	"combat": {"ambience_db": -12.0, "music_db": 0.0},
	"dungeon": {"ambience_db": -9.0, "music_db": -1.0},
	"boss": {"ambience_db": -14.0, "music_db": 1.0},
	"reincarnation": {"ambience_db": -13.0, "music_db": -5.0},
}

const CONTEXT_MUSIC_STATES := {
	"menu": "exploration",
	"world": "exploration",
	"event": "exploration",
	"combat": "pressure",
	"dungeon": "pressure",
	"boss": "decisive",
	"reincarnation": "exploration",
}

const EVENT_ALIASES := {
	"ui_confirm": "ui.confirm", "ui_cancel": "ui.cancel", "card_cast": "dungeon.card",
	"impact": "dungeon.impact", "guard": "dungeon.guard", "stress": "dungeon.stress",
	"heart_awaken": "dungeon.heart", "elite_enter": "dungeon.elite_enter",
	"boss_enter": "dungeon.boss_enter", "phase_break": "dungeon.phase_break",
	"victory": "dungeon.victory", "defeat": "dungeon.defeat",
	"heal": "combat.heal", "recover": "combat.recover", "status": "combat.status",
}

var _settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var _manifest: Dictionary = {}
var _assets_by_id: Dictionary = {}
var _events: Dictionary = {}
var _music_playlists: Dictionary = {}
var _soundscapes: Dictionary = {}
var _context := "menu"
var _era_id := "classical"
var _initialized := false
var _application_focused := true
var _audio_cursor := 0
var _last_played_ms: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _ambience_player: AudioStreamPlayer
var _ambience_outgoing_player: AudioStreamPlayer
var _ambience_tween: Tween
var _ambience_detail_player: AudioStreamPlayer
var _ambience_detail_outgoing_player: AudioStreamPlayer
var _ambience_detail_tween: Tween
var _music_player: AudioStreamPlayer
var _music_outgoing_player: AudioStreamPlayer
var _music_tween: Tween
var _music_state := ""
var _current_music_asset_id := ""
var _music_playlist_positions: Dictionary = {}
var _last_music_start_position := 0.0
var _shutting_down := false


func _ready() -> void:
	_initialize_runtime()
	load_settings()
	set_context(_context)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_application_focused = false
		_apply_master_mute()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_application_focused = true
		_apply_master_mute()


func _exit_tree() -> void:
	shutdown_for_exit()


func shutdown_for_exit() -> void:
	if _shutting_down:
		return
	_shutting_down = true
	for tween in [_ambience_tween, _ambience_detail_tween, _music_tween]:
		if is_instance_valid(tween):
			tween.kill()
	_ambience_tween = null
	_ambience_detail_tween = null
	_music_tween = null
	for player in [_ambience_player, _ambience_outgoing_player,
			_ambience_detail_player, _ambience_detail_outgoing_player,
			_music_player, _music_outgoing_player]:
		_stop_and_release_player(player)
	for player in _players:
		_stop_and_release_player(player)
	_last_played_ms.clear()


func debug_stream_reference_count() -> int:
	var count := 0
	for player in [_ambience_player, _ambience_outgoing_player,
			_ambience_detail_player, _ambience_detail_outgoing_player,
			_music_player, _music_outgoing_player]:
		if is_instance_valid(player) and player.stream != null:
			count += 1
	for player in _players:
		if is_instance_valid(player) and player.stream != null:
			count += 1
	return count


func _stop_and_release_player(player: AudioStreamPlayer) -> void:
	if not is_instance_valid(player):
		return
	player.stop()
	player.stream = null
	player.set_meta("audio_priority", -1)
	player.set_meta("audio_event", "")
	player.set_meta("audio_asset_id", "")
	player.set_meta("audio_started_ms", 0)


func _initialize_runtime() -> void:
	if _initialized:
		return
	_initialized = true
	_load_manifest()
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "AmbienceLoop"
	_ambience_player.bus = &"Ambience"
	add_child(_ambience_player)
	_ambience_outgoing_player = AudioStreamPlayer.new()
	_ambience_outgoing_player.name = "AmbienceCrossfade"
	_ambience_outgoing_player.bus = &"Ambience"
	add_child(_ambience_outgoing_player)
	_ambience_detail_player = AudioStreamPlayer.new()
	_ambience_detail_player.name = "AmbienceWeatherPoints"
	_ambience_detail_player.bus = &"Ambience"
	add_child(_ambience_detail_player)
	_ambience_detail_outgoing_player = AudioStreamPlayer.new()
	_ambience_detail_outgoing_player.name = "AmbienceWeatherPointsCrossfade"
	_ambience_detail_outgoing_player.bus = &"Ambience"
	add_child(_ambience_detail_outgoing_player)
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicLoop"
	_music_player.bus = &"Music"
	_music_player.finished.connect(_on_music_finished.bind(_music_player))
	add_child(_music_player)
	_music_outgoing_player = AudioStreamPlayer.new()
	_music_outgoing_player.name = "MusicCrossfade"
	_music_outgoing_player.bus = &"Music"
	_music_outgoing_player.finished.connect(_on_music_finished.bind(_music_outgoing_player))
	add_child(_music_outgoing_player)
	for index in range(SFX_POOL_SIZE + UI_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "Voice%02d" % index
		player.bus = &"UI" if index >= SFX_POOL_SIZE else &"SFX"
		player.set_meta("audio_priority", -1)
		player.set_meta("audio_event", "")
		player.set_meta("audio_started_ms", 0)
		add_child(player)
		_players.append(player)


func _load_manifest() -> void:
	_manifest = {}
	_assets_by_id = {}
	_events = {}
	_music_playlists = {}
	_soundscapes = {}
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_error("Audio manifest missing: %s" % MANIFEST_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		push_error("Audio manifest is not a JSON object: %s" % MANIFEST_PATH)
		return
	_manifest = parsed as Dictionary
	if int(_manifest.get("version", 0)) != 2:
		push_error("Unsupported audio manifest version: %s" % str(_manifest.get("version", "missing")))
		_manifest = {}
		return
	_events = (_manifest.get("events", {}) as Dictionary).duplicate(true)
	_music_playlists = (_manifest.get("music_playlists", {}) as Dictionary).duplicate(true)
	_soundscapes = (_manifest.get("soundscapes", {}) as Dictionary).duplicate(true)
	for entry_value in (_manifest.get("assets", []) as Array):
		if not entry_value is Dictionary:
			continue
		var entry := (entry_value as Dictionary).duplicate(true)
		var asset_id := str(entry.get("id", ""))
		if not asset_id.is_empty():
			_assets_by_id[asset_id] = entry


func load_settings() -> void:
	_settings = DEFAULT_SETTINGS.duplicate(true)
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		for key in DEFAULT_SETTINGS.keys():
			if config.has_section_key("audio", key):
				_settings[key] = config.get_value("audio", key, DEFAULT_SETTINGS[key])
	_sanitize_settings()
	_apply_settings()


func save_settings() -> void:
	var config := ConfigFile.new()
	for key in DEFAULT_SETTINGS.keys():
		config.set_value("audio", key, _settings[key])
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("音频设置未能保存：%s" % error_string(error))


func get_settings() -> Dictionary:
	return _settings.duplicate(true)


func set_bus_percent(bus_name: String, value: float) -> void:
	var key := bus_name.to_lower()
	if not DEFAULT_SETTINGS.has(key) or not DEFAULT_SETTINGS[key] is float:
		return
	_settings[key] = clampf(value, 0.0, 100.0)
	_apply_bus_volumes()


func set_setting(key: String, value: Variant) -> void:
	if not DEFAULT_SETTINGS.has(key):
		return
	if DEFAULT_SETTINGS[key] is bool:
		_settings[key] = bool(value)
	else:
		_settings[key] = clampf(float(value), 0.0, 100.0)
	_apply_settings()


func set_context(context_id: String) -> void:
	if not CONTEXT_PROFILES.has(context_id):
		context_id = "world"
	var previous_soundscape_location := _soundscape_location_for_context(_context)
	_context = context_id
	_initialize_runtime()
	_apply_context_mix()
	if previous_soundscape_location != _soundscape_location_for_context(_context):
		_switch_ambience_for_era()
	else:
		_start_ambience_if_needed()
	var next_music_state := str(CONTEXT_MUSIC_STATES.get(_context, "exploration"))
	if _music_state != next_music_state:
		_music_state = next_music_state
		_switch_music_for_state_or_era(true)
	else:
		_start_music_if_needed()


func get_context() -> String:
	return _context


func set_era(era_id: String) -> void:
	if era_id not in ERA_IDS:
		era_id = "classical"
	if _era_id == era_id:
		return
	_era_id = era_id
	_initialize_runtime()
	_switch_ambience_for_era()
	_switch_music_for_state_or_era(false)


func get_era() -> String:
	return _era_id


func get_music_state() -> String:
	return _music_state


func play_event(event_id: String, context: Dictionary = {}) -> bool:
	_initialize_runtime()
	var resolved_id := str(EVENT_ALIASES.get(event_id, event_id))
	if not _events.has(resolved_id):
		return false
	var event: Dictionary = _events[resolved_id]
	var now_ms := Time.get_ticks_msec()
	var cooldown_ms := int(event.get("cooldown_ms", 0))
	if now_ms - int(_last_played_ms.get(resolved_id, -cooldown_ms - 1)) < cooldown_ms:
		return false
	if _active_instance_count(resolved_id) >= int(event.get("max_instances", 1)):
		return false
	var priority := int(event.get("priority", 0)) + int(context.get("priority_offset", 0))
	var player := _acquire_player(str(event.get("bus", "SFX")), priority)
	if player == null:
		return false
	var asset_ids: Array = event.get("asset_ids", [])
	if asset_ids.is_empty():
		return false
	var variant_index := _next_variant_index(resolved_id, asset_ids.size())
	var asset_id := str(asset_ids[variant_index])
	var stream := _load_audio_stream(asset_id)
	if stream == null:
		return false
	if not _audio_output_available():
		# Headless/Dummy runs still validate event resolution and cooldowns, but
		# must not create playback handles that cannot be mixed or released.
		_last_played_ms[resolved_id] = Time.get_ticks_msec()
		return true
	var gain_db := float(event.get("gain_db", 0.0)) + float(context.get("gain_db", 0.0))
	if bool(_settings.get("reduce_sudden", false)) and bool(event.get("sudden", false)):
		gain_db -= 6.0
	if bool(_settings.get("night_mode", false)) and str(event.get("bus", "SFX")) == "SFX":
		gain_db -= 2.0
	player.stop()
	player.stream = stream
	player.bus = StringName(str(event.get("bus", "SFX")))
	player.volume_db = gain_db
	player.set_meta("audio_priority", priority)
	player.set_meta("audio_event", resolved_id)
	player.set_meta("audio_asset_id", asset_id)
	player.set_meta("audio_started_ms", now_ms)
	player.play()
	_last_played_ms[resolved_id] = Time.get_ticks_msec()
	return true


func event_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for event_id in _events.keys():
		ids.append(str(event_id))
	ids.sort()
	return ids


func debug_audio_cursor() -> int:
	return _audio_cursor


func debug_active_voice_count() -> int:
	var count := 0
	for player in _players:
		if player.playing:
			count += 1
	return count


func debug_pool_size() -> int:
	return _players.size()


func debug_ambience_voice_count() -> int:
	return (int(is_instance_valid(_ambience_player)) + int(is_instance_valid(_ambience_outgoing_player)) +
		int(is_instance_valid(_ambience_detail_player)) + int(is_instance_valid(_ambience_detail_outgoing_player)))


func debug_ambience_playing_voice_count() -> int:
	return (int(is_instance_valid(_ambience_player) and _ambience_player.playing) +
		int(is_instance_valid(_ambience_outgoing_player) and _ambience_outgoing_player.playing) +
		int(is_instance_valid(_ambience_detail_player) and _ambience_detail_player.playing) +
		int(is_instance_valid(_ambience_detail_outgoing_player) and _ambience_detail_outgoing_player.playing))


func debug_soundscape_location() -> String:
	return _soundscape_location_for_context(_context)


func debug_ambience_crossfade_seconds() -> float:
	return AMBIENCE_CROSSFADE_SECONDS


func debug_music_voice_count() -> int:
	return int(is_instance_valid(_music_player)) + int(is_instance_valid(_music_outgoing_player))


func debug_music_playing_voice_count() -> int:
	return int(is_instance_valid(_music_player) and _music_player.playing) + int(
		is_instance_valid(_music_outgoing_player) and _music_outgoing_player.playing)


func debug_music_crossfade_seconds() -> float:
	return MUSIC_CROSSFADE_SECONDS


func debug_event_variant_count(event_id: String) -> int:
	var resolved_id := str(EVENT_ALIASES.get(event_id, event_id))
	if not _events.has(resolved_id):
		return 0
	return (_events[resolved_id].get("asset_ids", []) as Array).size()


func debug_event_asset_ids(event_id: String) -> PackedStringArray:
	_initialize_runtime()
	var resolved_id := str(EVENT_ALIASES.get(event_id, event_id))
	var result := PackedStringArray()
	if not _events.has(resolved_id):
		return result
	for asset_id in (_events[resolved_id].get("asset_ids", []) as Array):
		result.append(str(asset_id))
	return result


func debug_event_semantic_category(event_id: String) -> String:
	_initialize_runtime()
	var resolved_id := str(EVENT_ALIASES.get(event_id, event_id))
	return str((_events.get(resolved_id, {}) as Dictionary).get("semantic_category", ""))


func debug_resolved_asset_path(asset_id: String) -> String:
	_initialize_runtime()
	return _resolve_audio_path(asset_id)


func debug_manifest_version() -> int:
	_initialize_runtime()
	return int(_manifest.get("version", 0))


func debug_current_music_asset_id() -> String:
	return _current_music_asset_id


func debug_last_music_start_position() -> float:
	return _last_music_start_position


func debug_asset_loop_enabled(asset_id: String) -> bool:
	_initialize_runtime()
	return bool((_assets_by_id.get(asset_id, {}) as Dictionary).get("loop", false))


func debug_loaded_stream_loop_enabled(asset_id: String) -> bool:
	_initialize_runtime()
	var stream := _load_audio_stream(asset_id)
	if stream is AudioStreamOggVorbis:
		return (stream as AudioStreamOggVorbis).loop
	if stream is AudioStreamWAV:
		return (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	return false


func debug_music_playlist(state: String) -> PackedStringArray:
	_initialize_runtime()
	var result := PackedStringArray()
	for asset_id in (_music_playlists.get(state, []) as Array):
		result.append(str(asset_id))
	return result


func debug_advance_music_playlist() -> String:
	if _music_state.is_empty():
		_music_state = str(CONTEXT_MUSIC_STATES.get(_context, "exploration"))
	_current_music_asset_id = _next_music_asset_id(_music_state)
	_last_music_start_position = 0.0
	return _current_music_asset_id


func debug_transition_start_position(from_asset_id: String, to_asset_id: String,
		previous_position: float) -> float:
	return _transition_start_position(from_asset_id, to_asset_id, previous_position)


func debug_reset_cooldowns() -> void:
	_last_played_ms.clear()


func _sanitize_settings() -> void:
	for bus_name in ["master", "music", "ambience", "sfx", "ui", "vo"]:
		_settings[bus_name] = clampf(float(_settings.get(bus_name, DEFAULT_SETTINGS[bus_name])), 0.0, 100.0)
	for key in ["muted", "mute_unfocused", "night_mode", "reduce_sudden", "mono"]:
		_settings[key] = bool(_settings.get(key, DEFAULT_SETTINGS[key]))


func _apply_settings() -> void:
	_apply_bus_volumes()
	_apply_master_mute()
	_apply_master_effects()


func _apply_bus_volumes() -> void:
	for bus_name in BUS_NAMES:
		var index := AudioServer.get_bus_index(bus_name)
		if index < 0:
			continue
		var percent := float(_settings.get(bus_name.to_lower(), 100.0))
		var volume_db := SILENCE_DB if percent <= 0.0 else linear_to_db(percent / 100.0)
		AudioServer.set_bus_volume_db(index, volume_db)
	_apply_context_mix()


func _apply_context_mix() -> void:
	if not CONTEXT_PROFILES.has(_context):
		return
	var profile: Dictionary = CONTEXT_PROFILES[_context]
	if is_instance_valid(_ambience_player):
		_ambience_player.volume_db = float(profile.get("ambience_db", -8.0))
	if is_instance_valid(_ambience_detail_player):
		_ambience_detail_player.volume_db = float(profile.get("ambience_db", -8.0)) + AMBIENCE_DETAIL_TRIM_DB
	# Context trim lives on the bus while the two player gains are reserved for
	# phase-synchronised state/era crossfades.
	var music_index := AudioServer.get_bus_index(&"Music")
	if music_index >= 0:
		var percent := float(_settings.get("music", 100.0))
		var base_db := SILENCE_DB if percent <= 0.0 else linear_to_db(percent / 100.0)
		AudioServer.set_bus_volume_db(music_index, base_db + float(profile.get("music_db", 0.0)))


func _apply_master_mute() -> void:
	var index := AudioServer.get_bus_index(&"Master")
	if index < 0:
		return
	var muted := bool(_settings.get("muted", false))
	muted = muted or (bool(_settings.get("mute_unfocused", true)) and not _application_focused)
	AudioServer.set_bus_mute(index, muted)


func _apply_master_effects() -> void:
	var index := AudioServer.get_bus_index(&"Master")
	if index < 0:
		return
	var dynamics_enabled := bool(_settings.get("night_mode", false)) or bool(_settings.get("reduce_sudden", false))
	for effect_index in range(AudioServer.get_bus_effect_count(index)):
		var effect := AudioServer.get_bus_effect(index, effect_index)
		if effect is AudioEffectCompressor:
			AudioServer.set_bus_effect_enabled(index, effect_index, dynamics_enabled)
			var compressor := effect as AudioEffectCompressor
			compressor.threshold = -24.0 if bool(_settings.get("night_mode", false)) else -18.0
			compressor.ratio = 6.0 if bool(_settings.get("night_mode", false)) else 4.0
			compressor.gain = 4.0 if bool(_settings.get("night_mode", false)) else 0.0
		elif effect is AudioEffectStereoEnhance:
			(effect as AudioEffectStereoEnhance).pan_pullout = 0.0 if bool(_settings.get("mono", false)) else 1.0


func _start_ambience_if_needed() -> void:
	if not _audio_output_available():
		return
	_start_ambience_layer_if_needed(_ambience_player, _ambience_asset_id("bed"),
		_ambience_target_db())
	_start_ambience_layer_if_needed(_ambience_detail_player, _ambience_asset_id("detail"),
		_ambience_detail_target_db())


func _start_ambience_layer_if_needed(player: AudioStreamPlayer, asset_id: String,
		target_db: float) -> void:
	if not is_instance_valid(player) or asset_id.is_empty() or player.playing:
		return
	var stream := _load_audio_stream(asset_id)
	if stream == null:
		return
	player.stream = stream
	player.volume_db = target_db
	player.set_meta("audio_asset_id", asset_id)
	player.play(0.0)


func _switch_ambience_for_era() -> void:
	if not _audio_output_available():
		return
	_switch_ambience_bed(_ambience_asset_id("bed"))
	_switch_ambience_detail(_ambience_asset_id("detail"))


func _switch_ambience_bed(asset_id: String) -> void:
	if asset_id.is_empty():
		_release_ambience_bed()
		return
	if (_ambience_player.playing and
			str(_ambience_player.get_meta("audio_asset_id", "")) == asset_id):
		return
	var stream := _load_audio_stream(asset_id)
	if stream == null:
		return
	if not _ambience_player.playing:
		_ambience_player.stream = stream
		_ambience_player.volume_db = _ambience_target_db()
		_ambience_player.set_meta("audio_asset_id", asset_id)
		_ambience_player.play(0.0)
		return
	if is_instance_valid(_ambience_tween):
		_ambience_tween.kill()
		_ambience_tween = null
	if _ambience_outgoing_player.playing:
		if _ambience_outgoing_player.volume_db > _ambience_player.volume_db:
			var swap := _ambience_player
			_ambience_player = _ambience_outgoing_player
			_ambience_outgoing_player = swap
		_ambience_outgoing_player.stop()
		_ambience_outgoing_player.stream = null
	var previous := _ambience_player
	var incoming := _ambience_outgoing_player
	var previous_asset_id := str(previous.get_meta("audio_asset_id", ""))
	var start_position := _transition_start_position(previous_asset_id, asset_id,
		previous.get_playback_position())
	previous.volume_db = _ambience_target_db()
	incoming.stream = stream
	incoming.volume_db = SILENCE_DB
	incoming.set_meta("audio_asset_id", asset_id)
	incoming.play(start_position)
	_ambience_player = incoming
	_ambience_outgoing_player = previous
	_ambience_tween = create_tween().set_parallel(true)
	_ambience_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ambience_tween.tween_property(previous, "volume_db", SILENCE_DB,
		AMBIENCE_CROSSFADE_SECONDS)
	_ambience_tween.tween_property(incoming, "volume_db", _ambience_target_db(),
		AMBIENCE_CROSSFADE_SECONDS)
	_ambience_tween.chain().tween_callback(_finish_ambience_crossfade.bind(previous, incoming))


func _finish_ambience_crossfade(previous: AudioStreamPlayer, incoming: AudioStreamPlayer) -> void:
	if is_instance_valid(previous):
		previous.stop()
		previous.stream = null
		previous.set_meta("audio_asset_id", "")
	if _ambience_player == incoming:
		_ambience_outgoing_player = previous
	_ambience_tween = null


func _switch_ambience_detail(asset_id: String) -> void:
	if asset_id.is_empty():
		_release_ambience_detail()
		return
	if (_ambience_detail_player.playing and
			str(_ambience_detail_player.get_meta("audio_asset_id", "")) == asset_id):
		return
	var stream := _load_audio_stream(asset_id)
	if stream == null:
		return
	if not _ambience_detail_player.playing:
		_ambience_detail_player.stream = stream
		_ambience_detail_player.volume_db = _ambience_detail_target_db()
		_ambience_detail_player.set_meta("audio_asset_id", asset_id)
		_ambience_detail_player.play(0.0)
		return
	if is_instance_valid(_ambience_detail_tween):
		_ambience_detail_tween.kill()
		_ambience_detail_tween = null
	if _ambience_detail_outgoing_player.playing:
		if _ambience_detail_outgoing_player.volume_db > _ambience_detail_player.volume_db:
			var swap := _ambience_detail_player
			_ambience_detail_player = _ambience_detail_outgoing_player
			_ambience_detail_outgoing_player = swap
		_ambience_detail_outgoing_player.stop()
		_ambience_detail_outgoing_player.stream = null
	var previous := _ambience_detail_player
	var incoming := _ambience_detail_outgoing_player
	var previous_asset_id := str(previous.get_meta("audio_asset_id", ""))
	var start_position := _transition_start_position(previous_asset_id, asset_id,
		previous.get_playback_position())
	previous.volume_db = _ambience_detail_target_db()
	incoming.stream = stream
	incoming.volume_db = SILENCE_DB
	incoming.set_meta("audio_asset_id", asset_id)
	incoming.play(start_position)
	_ambience_detail_player = incoming
	_ambience_detail_outgoing_player = previous
	_ambience_detail_tween = create_tween().set_parallel(true)
	_ambience_detail_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ambience_detail_tween.tween_property(previous, "volume_db", SILENCE_DB,
		AMBIENCE_CROSSFADE_SECONDS)
	_ambience_detail_tween.tween_property(incoming, "volume_db", _ambience_detail_target_db(),
		AMBIENCE_CROSSFADE_SECONDS)
	_ambience_detail_tween.chain().tween_callback(
		_finish_ambience_detail_crossfade.bind(previous, incoming))


func _finish_ambience_detail_crossfade(previous: AudioStreamPlayer, incoming: AudioStreamPlayer) -> void:
	if is_instance_valid(previous):
		previous.stop()
		previous.stream = null
		previous.set_meta("audio_asset_id", "")
	if _ambience_detail_player == incoming:
		_ambience_detail_outgoing_player = previous
	_ambience_detail_tween = null


func _release_ambience_bed() -> void:
	if is_instance_valid(_ambience_tween):
		_ambience_tween.kill()
		_ambience_tween = null
	_stop_and_release_player(_ambience_player)
	_stop_and_release_player(_ambience_outgoing_player)


func _release_ambience_detail() -> void:
	if is_instance_valid(_ambience_detail_tween):
		_ambience_detail_tween.kill()
		_ambience_detail_tween = null
	_stop_and_release_player(_ambience_detail_player)
	_stop_and_release_player(_ambience_detail_outgoing_player)


func _start_music_if_needed() -> void:
	if not _audio_output_available() or not is_instance_valid(_music_player) or _music_player.playing:
		return
	if _music_state.is_empty():
		_music_state = str(CONTEXT_MUSIC_STATES.get(_context, "exploration"))
	var playlist: Array = _music_playlists.get(_music_state, [])
	if _current_music_asset_id.is_empty() or _current_music_asset_id not in playlist:
		_current_music_asset_id = _next_music_asset_id(_music_state)
	var stream := _load_audio_stream(_current_music_asset_id)
	if stream == null:
		return
	_music_player.stream = stream
	_music_player.volume_db = 0.0
	_music_player.set_meta("audio_asset_id", _current_music_asset_id)
	_last_music_start_position = 0.0
	_music_player.play(0.0)


func _switch_music_for_state_or_era(force_transition: bool = true) -> void:
	if not _audio_output_available():
		return
	if not is_instance_valid(_music_player) or not _music_player.playing:
		_current_music_asset_id = ""
		_start_music_if_needed()
		return
	var playlist: Array = _music_playlists.get(_music_state, [])
	if not force_transition and _current_music_asset_id in playlist:
		return
	var next_asset_id := _next_music_asset_id(_music_state, _current_music_asset_id)
	if next_asset_id.is_empty():
		return
	if next_asset_id == _current_music_asset_id:
		return
	var stream := _load_audio_stream(next_asset_id)
	if stream == null:
		return
	# A context can change again before a previous fade finishes.  Keep the
	# louder voice as the timing reference and deterministically release the
	# quieter one before starting the next two-voice transition.
	if is_instance_valid(_music_tween):
		_music_tween.kill()
		_music_tween = null
	if _music_outgoing_player.playing:
		if _music_outgoing_player.volume_db > _music_player.volume_db:
			var swap := _music_player
			_music_player = _music_outgoing_player
			_music_outgoing_player = swap
		_music_outgoing_player.stop()
		_music_outgoing_player.stream = null
	var previous := _music_player
	var incoming := _music_outgoing_player
	previous.volume_db = 0.0
	incoming.stream = stream
	incoming.volume_db = SILENCE_DB
	incoming.set_meta("audio_asset_id", next_asset_id)
	_last_music_start_position = 0.0
	incoming.play(0.0)
	# Swap immediately: the named active player always represents the target
	# state even while the old state is still fading out.
	_music_player = incoming
	_music_outgoing_player = previous
	_current_music_asset_id = next_asset_id
	_music_tween = create_tween().set_parallel(true)
	_music_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_music_tween.tween_property(previous, "volume_db", SILENCE_DB,
		MUSIC_CROSSFADE_SECONDS)
	_music_tween.tween_property(incoming, "volume_db", 0.0,
		MUSIC_CROSSFADE_SECONDS)
	_music_tween.chain().tween_callback(_finish_music_crossfade.bind(previous, incoming))


func _finish_music_crossfade(previous: AudioStreamPlayer, incoming: AudioStreamPlayer) -> void:
	if is_instance_valid(previous):
		previous.stop()
		previous.stream = null
		previous.set_meta("audio_asset_id", "")
	if _music_player == incoming:
		_music_outgoing_player = previous
	_music_tween = null


func _on_music_finished(player: AudioStreamPlayer) -> void:
	if _shutting_down or player != _music_player:
		return
	player.stream = null
	player.set_meta("audio_asset_id", "")
	_current_music_asset_id = ""
	call_deferred("_start_music_if_needed")


func _ambience_target_db() -> float:
	var profile: Dictionary = CONTEXT_PROFILES.get(_context, CONTEXT_PROFILES.world)
	return float(profile.get("ambience_db", -8.0))


func _ambience_detail_target_db() -> float:
	return _ambience_target_db() + AMBIENCE_DETAIL_TRIM_DB


func _load_audio_stream(asset_id: String) -> AudioStream:
	var path := _resolve_audio_path(asset_id)
	if path.is_empty():
		return null
	var source := ResourceLoader.load(path) as AudioStream
	if source == null:
		return null
	var stream := source.duplicate() as AudioStream
	var entry: Dictionary = _assets_by_id.get(asset_id, {})
	var should_loop := bool(entry.get("loop", false))
	if stream is AudioStreamWAV:
		var wave := stream as AudioStreamWAV
		wave.loop_mode = AudioStreamWAV.LOOP_FORWARD if should_loop else AudioStreamWAV.LOOP_DISABLED
		if should_loop:
			wave.loop_begin = int(entry.get("loop_start_sample", 0))
			wave.loop_end = int(entry.get("loop_end_sample", maxi(1,
				int(round(wave.get_length() * float(entry.get("sample_rate", 48000)))))))
	elif stream is AudioStreamOggVorbis:
		var vorbis := stream as AudioStreamOggVorbis
		vorbis.loop = should_loop
		vorbis.loop_offset = (float(entry.get("loop_start_sample", 0)) /
			maxf(1.0, float(entry.get("sample_rate", 48000)))) if should_loop else 0.0
	return stream


func _soundscape_location_for_context(context_id: String) -> String:
	return "dungeon" if context_id in ["dungeon", "boss"] else "world"


func _ambience_asset_id(layer: String) -> String:
	var location := _soundscape_location_for_context(_context)
	var soundscape: Dictionary = _soundscapes.get(location, {})
	var manifest_layer := "detail" if layer in ["detail", "weather_points"] else "bed"
	return str(soundscape.get(manifest_layer, ""))


func _music_asset_id() -> String:
	if not _current_music_asset_id.is_empty():
		return _current_music_asset_id
	var state := "exploration" if _music_state.is_empty() else _music_state
	var playlist: Array = _music_playlists.get(state, [])
	return "" if playlist.is_empty() else str(playlist[0])


func _next_music_asset_id(state: String, avoid_asset_id: String = "") -> String:
	var playlist: Array = _music_playlists.get(state, [])
	if playlist.is_empty():
		return ""
	var start := int(_music_playlist_positions.get(state, 0)) % playlist.size()
	for offset in range(playlist.size()):
		var index := (start + offset) % playlist.size()
		var candidate := str(playlist[index])
		if candidate == avoid_asset_id and playlist.size() > 1:
			continue
		_music_playlist_positions[state] = (index + 1) % playlist.size()
		return candidate
	return str(playlist[start])


func _transition_start_position(from_asset_id: String, to_asset_id: String,
		previous_position: float) -> float:
	var from_entry: Dictionary = _assets_by_id.get(from_asset_id, {})
	var to_entry: Dictionary = _assets_by_id.get(to_asset_id, {})
	var from_group := str(from_entry.get("sync_group", ""))
	var to_group := str(to_entry.get("sync_group", ""))
	if from_group.is_empty() or from_group != to_group:
		return 0.0
	var duration := float(to_entry.get("duration", 0.0))
	return fposmod(previous_position, duration) if duration > 0.0 else 0.0


func _resolve_audio_path(asset_id: String) -> String:
	var entry: Dictionary = _assets_by_id.get(asset_id, {})
	var path := str(entry.get("runtime_path", ""))
	return path if not path.is_empty() and ResourceLoader.exists(path) else ""


func _audio_output_available() -> bool:
	return DisplayServer.get_name() != "headless" and AudioServer.get_driver_name() != "Dummy"


func _next_variant_index(event_id: String, variant_count: int) -> int:
	_audio_cursor = (_audio_cursor + 1) & 0x7fffffff
	if variant_count <= 1:
		return 0
	return absi(hash("%s:%d" % [event_id, _audio_cursor])) % variant_count


func _active_instance_count(event_id: String) -> int:
	var count := 0
	for player in _players:
		if player.playing and str(player.get_meta("audio_event", "")) == event_id:
			count += 1
	return count


func _acquire_player(bus_name: String, incoming_priority: int) -> AudioStreamPlayer:
	var begin := SFX_POOL_SIZE if bus_name == "UI" else 0
	var end := _players.size() if bus_name == "UI" else SFX_POOL_SIZE
	for index in range(begin, end):
		if not _players[index].playing:
			return _players[index]
	var candidate: AudioStreamPlayer
	var lowest_priority := 1 << 30
	var oldest_started := 1 << 62
	for index in range(begin, end):
		var player := _players[index]
		var priority := int(player.get_meta("audio_priority", -1))
		var started := int(player.get_meta("audio_started_ms", 0))
		if priority < lowest_priority or (priority == lowest_priority and started < oldest_started):
			candidate = player
			lowest_priority = priority
			oldest_started = started
	if candidate != null and incoming_priority > lowest_priority:
		candidate.stop()
		return candidate
	return null
