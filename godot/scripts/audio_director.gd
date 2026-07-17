extends Node
class_name AudioDirector

const SETTINGS_PATH := "user://audio_settings.cfg"
const BUS_NAMES: PackedStringArray = ["Master", "Music", "Ambience", "SFX", "UI", "VO"]
const SFX_POOL_SIZE := 12
const UI_POOL_SIZE := 4
const SILENCE_DB := -80.0

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
var _initialized := false
var _application_focused := true
var _audio_cursor := 0
var _last_played_ms: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _ambience_player: AudioStreamPlayer


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
	# Explicitly release active playback before the audio server shuts down.
	# This matters for short headless runs as well as scene replacement.
	if is_instance_valid(_ambience_player):
		_ambience_player.stop()
		_ambience_player.stream = null
	for player in _players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null


func _initialize_runtime() -> void:
	if _initialized:
		return
	_initialized = true
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "AmbienceLoop"
	_ambience_player.bus = &"Ambience"
	add_child(_ambience_player)
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
	_context = context_id
	_initialize_runtime()
	_apply_context_mix()
	_start_ambience_if_needed()


func get_context() -> String:
	return _context


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
		_last_played_ms[resolved_id] = now_ms
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
	_last_played_ms[resolved_id] = now_ms
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


func debug_event_variant_count(event_id: String) -> int:
	var resolved_id := str(EVENT_ALIASES.get(event_id, event_id))
	if not EVENTS.has(resolved_id):
		return 0
	return (EVENTS[resolved_id].get("files", []) as Array).size()


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
	# Music has no bundled score in this vertical slice yet, but its context
	# trim is already expressed at the bus so future stems inherit the mix.
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
	if not _audio_output_available() or not is_instance_valid(_ambience_player) or _ambience_player.playing:
		return
	var stream := _load_audio_stream("classical_ambience")
	if stream == null:
		return
	if stream is AudioStreamWAV and (stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
		stream = stream.duplicate()
		var wave := stream as AudioStreamWAV
		wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wave.loop_begin = 0
		wave.loop_end = maxi(1, int(round(wave.get_length() * 48000.0)))
	_ambience_player.stream = stream
	_ambience_player.play()


func _load_audio_stream(asset_id: String) -> AudioStream:
	var path := "res://audio/generated/classical/%s.wav" % asset_id
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as AudioStream


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
