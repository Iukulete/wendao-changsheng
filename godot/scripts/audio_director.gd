extends Node
class_name AudioDirector

const SETTINGS_PATH := "user://audio_settings.cfg"
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

const EVENTS := {
	"ui.confirm": {"files": ["ui_confirm", "ui_confirm_02", "ui_confirm_03", "ui_confirm_04"], "bus": "UI", "gain_db": -11.0,
		"priority": 20, "cooldown_ms": 55, "max_instances": 2},
	"ui.cancel": {"files": ["ui_cancel", "ui_cancel_02", "ui_cancel_03", "ui_cancel_04"], "bus": "UI", "gain_db": -10.0,
		"priority": 22, "cooldown_ms": 70, "max_instances": 2},
	"dungeon.card": {"files": ["card_cast", "card_cast_02", "card_cast_03", "card_cast_04"], "bus": "SFX", "gain_db": -5.0,
		"priority": 42, "cooldown_ms": 45, "max_instances": 3},
	"combat.spell": {"files": ["card_cast", "card_cast_02", "card_cast_03", "card_cast_04"], "bus": "SFX", "gain_db": -6.0,
		"priority": 42, "cooldown_ms": 80, "max_instances": 2},
	"combat.impact": {"files": ["impact", "impact_02", "impact_03", "impact_04"], "bus": "SFX", "gain_db": -4.0,
		"priority": 55, "cooldown_ms": 65, "max_instances": 3, "sudden": true},
	"dungeon.impact": {"files": ["impact", "impact_02", "impact_03", "impact_04"], "bus": "SFX", "gain_db": -4.0,
		"priority": 56, "cooldown_ms": 65, "max_instances": 3, "sudden": true},
	"combat.guard": {"files": ["guard", "guard_02", "guard_03", "guard_04"], "bus": "SFX", "gain_db": -5.5,
		"priority": 48, "cooldown_ms": 90, "max_instances": 2},
	"dungeon.guard": {"files": ["guard", "guard_02", "guard_03", "guard_04"], "bus": "SFX", "gain_db": -5.5,
		"priority": 48, "cooldown_ms": 90, "max_instances": 2},
	"dungeon.stress": {"files": ["stress"], "bus": "SFX", "gain_db": -9.0,
		"priority": 58, "cooldown_ms": 260, "max_instances": 1},
	"dungeon.heart": {"files": ["heart_awaken"], "bus": "SFX", "gain_db": -7.0,
		"priority": 72, "cooldown_ms": 900, "max_instances": 1, "sudden": true},
	"dungeon.elite_enter": {"files": ["elite_enter"], "bus": "SFX", "gain_db": -4.0,
		"priority": 76, "cooldown_ms": 1200, "max_instances": 1, "sudden": true},
	"dungeon.boss_enter": {"files": ["boss_enter"], "bus": "SFX", "gain_db": -3.0,
		"priority": 88, "cooldown_ms": 1500, "max_instances": 1, "sudden": true},
	"dungeon.phase_break": {"files": ["phase_break"], "bus": "SFX", "gain_db": -5.0,
		"priority": 92, "cooldown_ms": 1100, "max_instances": 1, "sudden": true},
	"dungeon.victory": {"files": ["victory"], "bus": "SFX", "gain_db": -5.0,
		"priority": 82, "cooldown_ms": 1000, "max_instances": 1},
	"combat.victory": {"files": ["victory"], "bus": "SFX", "gain_db": -6.0,
		"priority": 80, "cooldown_ms": 1000, "max_instances": 1},
	"dungeon.defeat": {"files": ["defeat"], "bus": "SFX", "gain_db": -8.0,
		"priority": 86, "cooldown_ms": 1000, "max_instances": 1, "sudden": true},
	"combat.defeat": {"files": ["defeat"], "bus": "SFX", "gain_db": -8.0,
		"priority": 84, "cooldown_ms": 1000, "max_instances": 1, "sudden": true},
	"reincarnation.enter": {"files": ["heart_awaken"], "bus": "SFX", "gain_db": -9.0,
		"priority": 78, "cooldown_ms": 1600, "max_instances": 1},
}

const EVENT_ALIASES := {
	"ui_confirm": "ui.confirm", "ui_cancel": "ui.cancel", "card_cast": "dungeon.card",
	"impact": "dungeon.impact", "guard": "dungeon.guard", "stress": "dungeon.stress",
	"heart_awaken": "dungeon.heart", "elite_enter": "dungeon.elite_enter",
	"boss_enter": "dungeon.boss_enter", "phase_break": "dungeon.phase_break",
	"victory": "dungeon.victory", "defeat": "dungeon.defeat",
}

var _settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
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
	player.set_meta("audio_started_ms", 0)


func _initialize_runtime() -> void:
	if _initialized:
		return
	_initialized = true
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
	add_child(_music_player)
	_music_outgoing_player = AudioStreamPlayer.new()
	_music_outgoing_player.name = "MusicCrossfade"
	_music_outgoing_player.bus = &"Music"
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
		_switch_music_for_state_or_era()
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
	_switch_music_for_state_or_era()


func get_era() -> String:
	return _era_id


func get_music_state() -> String:
	return _music_state


func play_event(event_id: String, context: Dictionary = {}) -> bool:
	_initialize_runtime()
	var resolved_id := str(EVENT_ALIASES.get(event_id, event_id))
	if not EVENTS.has(resolved_id):
		return false
	var event: Dictionary = EVENTS[resolved_id]
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
	var files: Array = event.get("files", [])
	if files.is_empty():
		return false
	var variant_index := _next_variant_index(resolved_id, files.size())
	var stream := _load_audio_stream(str(files[variant_index]))
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
	player.set_meta("audio_started_ms", now_ms)
	player.play()
	_last_played_ms[resolved_id] = Time.get_ticks_msec()
	return true


func event_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for event_id in EVENTS.keys():
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
	if not EVENTS.has(resolved_id):
		return 0
	return (EVENTS[resolved_id].get("files", []) as Array).size()


func debug_resolved_asset_path(asset_id: String) -> String:
	return _resolve_audio_path(asset_id)


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
	if is_instance_valid(_ambience_player) and not _ambience_player.playing:
		var bed_stream := _looping_stream(_ambience_asset_id("bed"))
		if bed_stream != null:
			_ambience_player.stream = bed_stream
			_ambience_player.volume_db = _ambience_target_db()
			_ambience_player.play()
	if is_instance_valid(_ambience_detail_player) and not _ambience_detail_player.playing:
		var detail_stream := _looping_stream(_ambience_asset_id("weather_points"))
		if detail_stream != null:
			_ambience_detail_player.stream = detail_stream
			_ambience_detail_player.volume_db = _ambience_detail_target_db()
			_ambience_detail_player.play()


func _switch_ambience_for_era() -> void:
	if not _audio_output_available():
		return
	var bed_stream := _looping_stream(_ambience_asset_id("bed"))
	var detail_stream := _looping_stream(_ambience_asset_id("weather_points"))
	if bed_stream == null or detail_stream == null:
		return
	if (not is_instance_valid(_ambience_player) or not _ambience_player.playing or
			not is_instance_valid(_ambience_detail_player) or not _ambience_detail_player.playing):
		_start_ambience_if_needed()
		return
	_switch_ambience_bed(bed_stream)
	_switch_ambience_detail(detail_stream)


func _switch_ambience_bed(stream: AudioStream) -> void:
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
	var phase_seconds := previous.get_playback_position()
	if stream.get_length() > 0.0:
		phase_seconds = fposmod(phase_seconds, stream.get_length())
	previous.volume_db = _ambience_target_db()
	incoming.stream = stream
	incoming.volume_db = SILENCE_DB
	incoming.play(phase_seconds)
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
	if _ambience_player == incoming:
		_ambience_outgoing_player = previous
	_ambience_tween = null


func _switch_ambience_detail(stream: AudioStream) -> void:
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
	var phase_seconds := previous.get_playback_position()
	if stream.get_length() > 0.0:
		phase_seconds = fposmod(phase_seconds, stream.get_length())
	previous.volume_db = _ambience_detail_target_db()
	incoming.stream = stream
	incoming.volume_db = SILENCE_DB
	incoming.play(phase_seconds)
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
	if _ambience_detail_player == incoming:
		_ambience_detail_outgoing_player = previous
	_ambience_detail_tween = null


func _start_music_if_needed() -> void:
	if not _audio_output_available() or not is_instance_valid(_music_player) or _music_player.playing:
		return
	if _music_state.is_empty():
		_music_state = str(CONTEXT_MUSIC_STATES.get(_context, "exploration"))
	var stream := _looping_stream(_music_asset_id())
	if stream == null:
		return
	_music_player.stream = stream
	_music_player.volume_db = 0.0
	_music_player.play()


func _switch_music_for_state_or_era() -> void:
	if not _audio_output_available():
		return
	var stream := _looping_stream(_music_asset_id())
	if stream == null:
		return
	if not is_instance_valid(_music_player) or not _music_player.playing:
		_start_music_if_needed()
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
	var phase_seconds := previous.get_playback_position()
	if previous.stream != null and previous.stream.get_length() > 0.0:
		phase_seconds = fposmod(phase_seconds, previous.stream.get_length())
	if stream.get_length() > 0.0:
		phase_seconds = fposmod(phase_seconds, stream.get_length())
	previous.volume_db = 0.0
	incoming.stream = stream
	incoming.volume_db = SILENCE_DB
	incoming.play(phase_seconds)
	# Swap immediately: the named active player always represents the target
	# state even while the old state is still fading out.
	_music_player = incoming
	_music_outgoing_player = previous
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
	if _music_player == incoming:
		_music_outgoing_player = previous
	_music_tween = null


func _looping_stream(asset_id: String) -> AudioStream:
	var stream := _load_audio_stream(asset_id)
	if stream is AudioStreamWAV and (stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
		stream = stream.duplicate()
		var wave := stream as AudioStreamWAV
		wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wave.loop_begin = 0
		wave.loop_end = maxi(1, int(round(wave.get_length() * 48000.0)))
	elif stream is AudioStreamOggVorbis and not (stream as AudioStreamOggVorbis).loop:
		stream = stream.duplicate()
		var vorbis := stream as AudioStreamOggVorbis
		vorbis.loop = true
		vorbis.loop_offset = 0.0
	return stream


func _ambience_target_db() -> float:
	var profile: Dictionary = CONTEXT_PROFILES.get(_context, CONTEXT_PROFILES.world)
	return float(profile.get("ambience_db", -8.0))


func _ambience_detail_target_db() -> float:
	return _ambience_target_db() + AMBIENCE_DETAIL_TRIM_DB


func _load_audio_stream(asset_id: String) -> AudioStream:
	var path := _resolve_audio_path(asset_id)
	if path.is_empty():
		return null
	return ResourceLoader.load(path) as AudioStream


func _soundscape_location_for_context(context_id: String) -> String:
	return "dungeon" if context_id in ["dungeon", "boss"] else "world"


func _ambience_asset_id(layer: String) -> String:
	var location := _soundscape_location_for_context(_context)
	if layer == "weather_points":
		return "%s_%s_detail" % [_era_id, location]
	if location == "dungeon":
		return "%s_dungeon_ambience" % _era_id
	return "classical_ambience" if _era_id == "classical" else "%s_ambience" % _era_id


func _music_asset_id() -> String:
	return "music_%s" % ("exploration" if _music_state.is_empty() else _music_state)


func _resolve_audio_path(asset_id: String) -> String:
	var candidates: PackedStringArray = []
	if asset_id.begins_with("music_"):
		var state := asset_id.trim_prefix("music_")
		if state in ["exploration", "pressure", "decisive"]:
			candidates.append("res://audio/generated/%s/%s.ogg" % [_era_id, asset_id])
			if _era_id != "classical":
				candidates.append("res://audio/generated/classical/%s.ogg" % asset_id)
	elif asset_id.ends_with("_ambience") or asset_id.ends_with("_detail"):
		var soundscape_era := "classical" if asset_id == "classical_ambience" else ""
		if soundscape_era.is_empty():
			for candidate_era in ERA_IDS:
				if asset_id.begins_with("%s_" % candidate_era):
					soundscape_era = candidate_era
					break
		if not soundscape_era.is_empty():
			candidates.append("res://audio/generated/%s/%s.ogg" % [soundscape_era, asset_id])
	else:
		candidates.append("res://audio/generated/%s/%s.wav" % [_era_id, asset_id])
		# UI semantics intentionally stay shared.  Every gameplay and narrative
		# cue is release-gated per era and must never silently fall back.
		if _era_id != "classical" and asset_id.begins_with("ui_"):
			candidates.append("res://audio/generated/classical/%s.wav" % asset_id)
	for path in candidates:
		if ResourceLoader.exists(path):
			return path
	return ""


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
