class_name LegacySaveImporter
extends RefCounted

const GameStateScript = preload("res://scripts/game_state.gd")
const WorldSimulationScript = preload("res://scripts/world_simulation.gd")
const AchievementSystemScript = preload("res://scripts/achievement_system.gd")

const MAX_FILE_BYTES := 16 * 1024 * 1024
const LEGACY_TYPES := ["memory", "technique", "treasure", "knowledge", "reputation"]
const ACHIEVEMENT_IDS := [
	"first_ascension", "hundred_battles", "great_kindness", "demonic_supreme",
	"long_life", "dao_ancestor", "heavenly_dao", "ten_lives", "legacy_keeper",
	"hundred_events", "steadfast_heart", "renown", "all_arcs", "four_legacies",
	"relic_three", "jade_armory",
]
const WEAPON_IDS := [
	"qingxiao", "zhanjie", "qinglian", "xuesha", "suiyue", "zuting", "wandao",
	"lunhui", "chuancheng", "baijie", "wugou", "jiuxiao", "sixiang", "heibai",
	"canxing", "wuliang",
]


class LineReader:
	var lines: PackedStringArray
	var index: int
	var error: String = ""

	func _init(source: PackedStringArray, start_index: int) -> void:
		lines = source
		index = start_index

	func failed() -> bool:
		return not error.is_empty()

	func reject(message: String) -> void:
		if error.is_empty():
			error = message

	func take(label: String) -> String:
		if failed():
			return ""
		if index < 0 or index >= lines.size():
			reject("旧档在%s处意外结束。" % label)
			return ""
		var value := lines[index]
		index += 1
		return value

	func take_int(label: String, minimum: int = -0x7fffffff,
			maximum: int = 0x7fffffff) -> int:
		var raw := take(label).strip_edges()
		if failed():
			return 0
		if not raw.is_valid_int():
			reject("旧档字段%s不是整数。" % label)
			return 0
		var value := int(raw)
		if value < minimum or value > maximum:
			reject("旧档字段%s超出允许范围。" % label)
			return 0
		return value

	func take_count(label: String, maximum: int) -> int:
		return take_int(label, 0, maximum)

	func take_numbers(label: String, expected: int) -> Array[int]:
		var raw := take(label).strip_edges()
		var result: Array[int] = []
		if failed():
			return result
		var tokens := raw.split(" ", false)
		if tokens.size() != expected:
			reject("旧档字段%s的数字数量不正确。" % label)
			return result
		for token in tokens:
			var value := str(token).strip_edges()
			if not value.is_valid_int():
				reject("旧档字段%s包含无效数字。" % label)
				return []
			result.append(int(value))
		return result


static func inspect_file(path: String) -> Dictionary:
	var imported := import_file(path)
	if not bool(imported.get("ok", false)):
		return imported
	var state: Dictionary = imported.state
	var player: Dictionary = state.player
	return {
		"ok": true,
		"code": "legacy_save_valid",
		"path": imported.source_path,
		"source_sha256": imported.source_sha256,
		"save_version": imported.save_version,
		"player_name": str(player.name),
		"realm": str(player.realm),
		"era": str(state.current_era),
		"generation": int(state.generation),
		"world_year": int((state.world as Dictionary).get("year", 1)),
	}


static func find_candidates(search_roots: Array[String]) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var seen := {}
	for root_value in search_roots:
		var root := root_value.simplify_path()
		if root.is_empty():
			continue
		for slot in range(1, 7):
			var path := root.path_join("slot_%d.txt" % slot).simplify_path()
			var key := path.replace("\\", "/").to_lower()
			if seen.has(key) or not FileAccess.file_exists(path):
				continue
			seen[key] = true
			var probe := inspect_file(path)
			if not bool(probe.get("ok", false)):
				continue
			probe["slot"] = slot
			probe["modified_at_unix"] = int(FileAccess.get_modified_time(path))
			candidates.append(probe)
	candidates.sort_custom(_candidate_newer)
	return candidates


static func import_file(path: String) -> Dictionary:
	var source := _read_source(path)
	if not bool(source.get("ok", false)):
		return source
	var lines: PackedStringArray = source.lines
	var save_version := str(lines[0]).strip_edges()
	if save_version not in ["SAVE_V4", "SAVE_V5"]:
		return _failure("unsupported_legacy_save", "仅支持旧版 SAVE_V4/SAVE_V5 存档。")

	var player_result := _parse_player(lines, save_version)
	if not bool(player_result.get("ok", false)):
		return player_result
	var world_result := _parse_world(lines)
	if not bool(world_result.get("ok", false)):
		return world_result
	var legacy_result := _parse_legacy(lines)
	if not bool(legacy_result.get("ok", false)):
		return legacy_result

	var era_result := _parse_world_era(lines)
	if not bool(era_result.get("ok", false)):
		return era_result
	var player_data: Dictionary = player_result.player
	var era_name := _normalize_era_name(str(era_result.era))
	var seed_value := int((str(source.sha256).substr(0, 8)).hex_to_int()) & 0x7fffffff
	if seed_value == 0:
		seed_value = 1
	var state := GameStateScript.create_new_game(
		str(player_data.name), seed_value, player_data.roots)
	state["run_id"] = "wendao-win32-import-%s" % str(source.sha256).substr(0, 16)
	state["current_era"] = era_name
	state["current_era_id"] = GameStateScript.era_id_for_name(era_name)
	state["player"] = player_data
	state["legacy"] = legacy_result.legacy
	state["generation"] = int((legacy_result.legacy as Dictionary).get("generation", 1))
	state["world"] = world_result.world
	(state.world as Dictionary)["seed"] = seed_value
	state["turn"] = maxi(int((world_result.world as Dictionary).get("age", 0)),
		int(player_data.get("total_events", 0)))
	state["feedback"] = "旧版存档已只读迁入；原始六槽旧录保持不变。"

	var family_result := _parse_family(lines)
	if bool(family_result.get("ok", false)):
		(state.player as Dictionary)["family"] = family_result.family
	elif str(family_result.get("code", "")) != "missing_legacy_family":
		return family_result
	var memory_result := _parse_memory(lines)
	if bool(memory_result.get("ok", false)):
		state["recent_memories"] = (memory_result.memories as Array).slice(-64)
		state["generation"] = maxi(int(state.generation), int(memory_result.generation))
		(state.legacy as Dictionary)["generation"] = int(state.generation)
	else:
		if str(memory_result.get("code", "")) != "missing_legacy_memory":
			return memory_result
		state["recent_memories"] = ["旧玉从旧版六槽存档中唤回了这段命途。"]
	var story_result := _parse_story(lines)
	if bool(story_result.get("ok", false)):
		_apply_story_import(state, story_result)
	elif str(story_result.get("code", "")) != "missing_legacy_story":
		return story_result
	var social_result := _parse_social(lines)
	if bool(social_result.get("ok", false)):
		_apply_social_import(state, social_result)
	elif str(social_result.get("code", "")) != "missing_legacy_social":
		return social_result
	var achievement_result := _parse_achievements(lines)
	if bool(achievement_result.get("ok", false)):
		(state.legacy as Dictionary)["armory"] = achievement_result.armory
	elif str(achievement_result.get("code", "")) != "missing_legacy_achievements":
		return achievement_result

	state = GameStateScript.ensure_v2(state)
	WorldSimulationScript.initialize(state)
	AchievementSystemScript.normalize(state)
	return {
		"ok": true,
		"code": "legacy_import_ready",
		"state": state,
		"source_path": str(source.path),
		"source_sha256": str(source.sha256),
		"save_version": save_version,
	}


static func _parse_player(lines: PackedStringArray, save_version: String) -> Dictionary:
	var reader := LineReader.new(lines, 1)
	var name := reader.take("角色名").strip_edges().left(32)
	if name.is_empty():
		return _failure("invalid_legacy_player", "旧档角色名为空。")
	var realm_index := reader.take_int("境界", 0, GameStateScript.REALM_IDS.size() - 1)
	var level := reader.take_int("层数", 1, 9)
	var exp := reader.take_int("修为", 0)
	var hp := reader.take_int("气血", 0)
	var max_hp := reader.take_int("气血上限", 1)
	var mp := reader.take_int("灵力", 0)
	var max_mp := reader.take_int("灵力上限", 0)
	var karma := reader.take_int("因果")
	var dao_heart := 0
	var reputation := clampi(int(karma / 2.0), -20, 20)
	var enmity := maxi(0, int(-karma / 5.0))
	if save_version == "SAVE_V5":
		dao_heart = reader.take_int("道心")
		reputation = reader.take_int("名望")
		enmity = reader.take_int("仇怨", 0)
	var age := reader.take_int("年龄", 0)
	var lifespan := reader.take_int("寿元", 1)
	var spirit_stones := reader.take_int("灵石", 0)
	var pills := reader.take_int("丹药", 0)
	var attack := reader.take_int("攻击")
	var defense := reader.take_int("防御")
	var roots: Array[int] = []
	for label in ["火灵根", "水灵根", "木灵根", "金灵根", "土灵根"]:
		roots.append(reader.take_int(label, 0, 100000))
	var total_events := reader.take_int("历练数", 0)
	var battles_won := reader.take_int("胜场", 0)
	var npcs_met := reader.take_int("结识人数", 0)
	if reader.failed():
		return _failure("invalid_legacy_player", reader.error)
	hp = clampi(hp, 0, max_hp)
	mp = clampi(mp, 0, max_mp)
	return {
		"ok": true,
		"player": {
			"id": "current_life", "name": name,
			"realm_id": GameStateScript.REALM_IDS[realm_index],
			"realm_index": realm_index, "realm": GameStateScript.REALM_NAMES[realm_index],
			"level": level, "exp": exp, "hp": hp, "max_hp": max_hp,
			"mp": mp, "max_mp": max_mp, "age": age, "lifespan": lifespan,
			"spirit_stones": spirit_stones, "pills": pills, "karma": karma,
			"dao_heart": dao_heart, "reputation": reputation, "enmity": enmity,
			"attack": attack, "defense": defense, "total_events": total_events,
			"battles_won": battles_won, "npcs_met": npcs_met, "roots": roots,
			"path": {"compassion": 0, "ambition": 0, "defiance": 0,
				"insight": 0, "creation": 0, "bonds": 0},
			"family": {}, "statuses": [],
		},
	}


static func _parse_family(lines: PackedStringArray) -> Dictionary:
	var reader := _section_reader(lines, ["FAMILY_V1"])
	if reader == null:
		return _failure("missing_legacy_family", "旧档缺少家世段。")
	var origin := reader.take("家世来历").left(256)
	var clan := reader.take("家族名").left(128)
	var father := reader.take("父亲").left(128)
	var mother := reader.take("母亲").left(128)
	var guardian := reader.take("监护人").left(128)
	var secret := reader.take("家世秘密").left(512)
	var values := reader.take_numbers("家世数值", 4)
	if reader.failed():
		return _failure("invalid_legacy_family", reader.error)
	return {"ok": true, "family": {
		"origin": origin, "clan": clan, "father": father, "mother": mother,
		"guardian": guardian, "secret": secret, "fame": values[0], "wealth": values[1],
		"knows_parents": values[2] != 0, "adopted": values[3] != 0,
	}}


static func _parse_world_era(lines: PackedStringArray) -> Dictionary:
	var index := _find_prefixed_marker(lines, "WORLD_ERA_V")
	if index < 0 or index + 1 >= lines.size():
		return _failure("missing_legacy_era", "旧档缺少纪元段。")
	var era := _unescape_field(lines[index + 1]).strip_edges()
	if era.is_empty():
		return _failure("invalid_legacy_era", "旧档纪元名称为空。")
	return {"ok": true, "era": era}


static func _parse_world(lines: PackedStringArray) -> Dictionary:
	var reader := _section_reader(lines, ["WORLD_V2"])
	if reader == null:
		return _failure("missing_legacy_world", "旧档缺少动态世界段。")
	var world_time := reader.take_int("世界年份", 0, 2000000000)
	var npc_count := reader.take_count("动态人物数量", 512)
	var npcs: Array[Dictionary] = []
	for npc_index in range(npc_count):
		var name := reader.take("动态人物名").strip_edges().left(48)
		var values := reader.take_numbers("动态人物数值", 11)
		var ally := reader.take("动态人物盟友").left(128)
		var enemy := reader.take("动态人物敌手").left(128)
		if reader.failed():
			break
		if npc_index >= 24 or name.is_empty():
			continue
		var realm_index := clampi(values[0], 0, GameStateScript.REALM_IDS.size() - 1)
		npcs.append({
			"id": "legacy_npc_%02d" % (npc_index + 1), "name": name,
			"realm_id": GameStateScript.REALM_IDS[realm_index], "realm_index": realm_index,
			"realm": GameStateScript.REALM_NAMES[realm_index], "shown_realm_index": values[1],
			"level": clampi(values[2], 1, 9), "age": maxi(0, values[3]),
			"lifespan": maxi(1, values[4]), "karma": values[5],
			"goal": values[6], "personality": values[7],
			"player_relation": clampi(values[8], -100, 100),
			"alive": values[9] != 0, "ascended": values[10] != 0,
			"ally_name": ally, "enemy_name": enemy, "relations": {},
			"stance": "legacy", "faction_id": "",
		})
	var event_count := reader.take_count("世界事件数量", 512)
	var event_memories: Array[String] = []
	for _event_index in range(event_count):
		var title := reader.take("世界事件标题").left(160)
		var description := reader.take("世界事件描述").left(512)
		var event_values := reader.take_numbers("世界事件数值", 3)
		if reader.failed():
			break
		if event_values[1] != 0 and event_memories.size() < 16:
			event_memories.append("旧世事件·%s：%s" % [title, description])
	var history_count := reader.take_count("世界史数量", 4096)
	var history: Array[String] = []
	for _history_index in range(history_count):
		var entry := reader.take("世界史条目").strip_edges().left(512)
		if not entry.is_empty():
			history.append(entry)
	if reader.failed():
		return _failure("invalid_legacy_world", reader.error)
	history.append_array(event_memories)
	history.append("第%d年，旧版山河被只读迁入 Godot 新纪元。" % maxi(1, world_time))
	return {"ok": true, "world": {
		"seed": 1, "year": maxi(1, world_time), "age": world_time,
		"era_pressure": 0, "qi_tide": 50, "stability": 65,
		"factions": [], "npcs": npcs, "active_events": [], "history": history.slice(-128),
	}}


static func _parse_legacy(lines: PackedStringArray) -> Dictionary:
	var marker_index := _find_prefixed_marker(lines, "LEGACY_V")
	if marker_index < 0:
		return _failure("missing_legacy_state", "旧档缺少轮回传承段。")
	var marker := str(lines[marker_index]).strip_edges()
	var version := int(marker.trim_prefix("LEGACY_V")) if marker.trim_prefix("LEGACY_V").is_valid_int() else 0
	if version < 1 or version > 4:
		return _failure("unsupported_legacy_state", "旧档轮回传承版本不受支持。")
	var reader := LineReader.new(lines, marker_index + 1)
	var generation := reader.take_int("轮回世数", 1, 100000)
	var inherited_count := reader.take_count("当前传承数量", 256)
	var inherited: Array[Dictionary] = []
	for inherited_index in range(inherited_count):
		var legacy_type := reader.take_int("传承类型", 0, LEGACY_TYPES.size() - 1)
		var name := reader.take("传承名").left(160)
		var description := reader.take("传承描述").left(512)
		var power := reader.take_int("传承强度", 0, 1000000)
		if reader.failed():
			break
		if inherited.size() < 16:
			inherited.append(_legacy_echo(inherited_index, legacy_type, name, description, power))
	var relic_name := reader.take("旧玉名").left(160)
	var resonance := reader.take_int("旧玉共鸣", 0, 1000000)
	var awakenings := reader.take_int("旧玉苏醒", 0, 1000)
	var aspect := reader.take("旧玉道痕").left(160)
	var dao_linked := reader.take_int("旧玉证道标记", 0, 1) != 0
	var dao_name := "本我大道" if dao_linked else "未证大道"
	var dao_depth := 0
	if version >= 2:
		dao_name = reader.take("旧玉大道").left(160)
		dao_depth = reader.take_int("旧玉大道深度", 0, 1000000)
	var life_count := reader.take_count("前世数量", 1024)
	var past_lives: Array[Dictionary] = []
	for life_index in range(life_count):
		var life_generation := reader.take_int("前世世数", 1, 100000)
		var life_name := reader.take("前世名").left(160)
		var realm_index := reader.take_int("前世境界", 0, GameStateScript.REALM_IDS.size() - 1)
		var age_at_death := reader.take_int("前世寿数", 0, 1000000)
		var cause := reader.take("前世死因").left(160)
		var karma := reader.take_int("前世因果")
		var total_events := reader.take_int("前世历练", 0)
		var battles_won := reader.take_int("前世胜场", 0)
		var npcs_met := reader.take_int("前世结识人数", 0)
		var life_legacy_count := reader.take_count("前世传承数量", 256)
		var echoes: Array[Dictionary] = []
		for echo_index in range(life_legacy_count):
			var echo_type := reader.take_int("前世传承类型", 0, LEGACY_TYPES.size() - 1)
			var echo_name := reader.take("前世传承名").left(160)
			var echo_description := reader.take("前世传承描述").left(512)
			var echo_power := reader.take_int("前世传承强度", 0, 1000000)
			if echoes.size() < 16:
				echoes.append(_legacy_echo(echo_index, echo_type, echo_name, echo_description, echo_power))
		var memory_fragments: Array[String] = []
		if version >= 3:
			var fragment_count := reader.take_count("前世记忆数量", 512)
			for _fragment_index in range(fragment_count):
				var fragment := reader.take("前世记忆").left(512)
				if memory_fragments.size() < 8:
					memory_fragments.append(fragment)
		var unfinished: Array[String] = []
		if version >= 4:
			var unfinished_count := reader.take_count("未竟因果数量", 512)
			for _unfinished_index in range(unfinished_count):
				var thread := reader.take("未竟因果").left(512)
				if unfinished.size() < 8:
					unfinished.append(thread)
		if reader.failed():
			break
		if life_index >= maxi(0, life_count - 64):
			past_lives.append({
				"generation": life_generation, "name": life_name,
				"realm_id": GameStateScript.REALM_IDS[realm_index], "realm_index": realm_index,
				"realm": GameStateScript.REALM_NAMES[realm_index], "level": 9,
				"age_at_death": age_at_death, "cause_of_death": cause, "karma": karma,
				"total_events": total_events, "battles_won": battles_won, "npcs_met": npcs_met,
				"path": {"compassion": 0, "ambition": 0, "defiance": 0,
					"insight": 0, "creation": 0, "bonds": 0},
				"dao_id": "legacy", "dao_name": dao_name,
				"memory_fragments": memory_fragments, "unfinished_threads": unfinished,
				"echoes": echoes,
			})
	if reader.failed():
		return _failure("invalid_legacy_state", reader.error)
	var unresolved: Array = [] if past_lives.is_empty() else (past_lives[-1].unfinished_threads as Array).duplicate()
	return {"ok": true, "legacy": {
		"generation": generation, "past_lives": past_lives,
		"inherited_echoes": inherited, "unresolved_threads": unresolved,
		"relic": {
			"id": "black_white_jade", "name": relic_name, "resonance": resonance,
			"awakening_stage": clampi(awakenings, 0, 5), "aspect": aspect,
			"dao_id": "legacy" if dao_linked else "", "dao_name": dao_name,
			"dao_depth": dao_depth,
		},
		"armory": {"version": 1, "achievements": {}, "weapons": {},
			"equipped_id": "", "notices": []},
	}}


static func _parse_memory(lines: PackedStringArray) -> Dictionary:
	var marker_index := _find_prefixed_marker(lines, "MEMORY_V")
	if marker_index < 0:
		return _failure("missing_legacy_memory", "旧档缺少记忆段。")
	var version_text := str(lines[marker_index]).strip_edges().trim_prefix("MEMORY_V")
	var version := int(version_text) if version_text.is_valid_int() else 0
	if version < 1 or version > 3:
		return _failure("unsupported_legacy_memory", "旧档记忆版本不受支持。")
	var reader := LineReader.new(lines, marker_index + 1)
	var generation := reader.take_int("记忆世数", 1, 100000)
	var count := reader.take_count("记忆数量", 4096)
	var memories: Array[String] = []
	for memory_index in range(count):
		var memory := reader.take("记忆条目")
		if version >= 2:
			memory = _unescape_field(memory)
		memory = memory.strip_edges().left(512)
		if not memory.is_empty() and memory_index >= maxi(0, count - 64):
			memories.append(memory)
	if reader.failed():
		return _failure("invalid_legacy_memory", reader.error)
	return {"ok": true, "generation": generation, "memories": memories}


static func _parse_story(lines: PackedStringArray) -> Dictionary:
	var marker_index := _find_prefixed_marker(lines, "STORY_STATE_V")
	if marker_index < 0:
		return _failure("missing_legacy_story", "旧档缺少剧情段。")
	var version_text := str(lines[marker_index]).strip_edges().trim_prefix("STORY_STATE_V")
	var version := int(version_text) if version_text.is_valid_int() else 0
	if version < 1 or version > 4:
		return _failure("unsupported_legacy_story", "旧档剧情版本不受支持。")
	var reader := LineReader.new(lines, marker_index + 1)
	var world_law := _unescape_field(reader.take("世界法则")).left(512)
	var hongmeng_rule := _unescape_field(reader.take("鸿蒙法则")).left(512)
	var jade_rule := _unescape_field(reader.take("伴生玉法则")).left(512)
	var destiny := _unescape_field(reader.take("主角命数")).left(512)
	var synopsis := _unescape_field(reader.take("剧情梗概")).left(512)
	var next_hook := _unescape_field(reader.take("后续线索")).left(512)
	var faction_pressure := reader.take_int("势力压力")
	var thread_count := reader.take_count("剧情线索数量", 1024)
	var threads: Array[String] = []
	for thread_index in range(thread_count):
		var thread := _unescape_field(reader.take("剧情线索")).left(512)
		if thread_index >= maxi(0, thread_count - 128):
			threads.append(thread)
	var relationship_count := reader.take_count("剧情关系数量", 1024)
	var relationships := {}
	for relationship_index in range(relationship_count):
		var relationship_name := _unescape_field(reader.take("剧情关系名")).left(160)
		var relationship_value := reader.take_int("剧情关系值", -100, 100)
		if relationship_index >= maxi(0, relationship_count - 128):
			relationships[relationship_name] = relationship_value
	var mood_count := reader.take_count("人物心境数量", 1024)
	for _mood_index in range(mood_count):
		reader.take("人物心境")
	var arc_progress := {"jade": 0, "sect": 0, "family": 0, "rival": 0}
	var arc_legacies := {}
	var arc_echoes := {}
	if version >= 2:
		var stages := reader.take_numbers("剧情分线进度", 5)
		if not reader.failed():
			arc_progress = {"jade": clampi(stages[0], 0, 4), "sect": clampi(stages[1], 0, 4),
				"family": clampi(stages[2], 0, 4), "rival": clampi(stages[3], 0, 4)}
	if version >= 3:
		for arc_id in ["jade", "sect", "family", "rival"]:
			var resolution := _unescape_field(reader.take("分线定局")).left(160)
			if not resolution.is_empty():
				arc_legacies[arc_id] = resolution
	if version >= 4:
		var echo_stages := reader.take_numbers("跨世续章进度", 5)
		for arc_id in ["jade", "sect", "family", "rival"]:
			var resolution := _unescape_field(reader.take("跨世续章定局")).left(160)
			var stage_index := ["jade", "sect", "family", "rival"].find(arc_id)
			if echo_stages.size() == 5 and (echo_stages[stage_index] > 0 or not resolution.is_empty()):
				arc_echoes[arc_id] = {"stage": clampi(echo_stages[stage_index], 0, 3),
					"resolution": resolution}
	if reader.failed():
		return _failure("invalid_legacy_story", reader.error)
	return {"ok": true, "world_law": world_law, "hongmeng_rule": hongmeng_rule,
		"jade_rule": jade_rule, "destiny": destiny, "synopsis": synopsis,
		"next_hook": next_hook, "faction_pressure": faction_pressure,
		"threads": threads, "relationships": relationships,
		"arc_progress": arc_progress, "arc_legacies": arc_legacies, "arc_echoes": arc_echoes}


static func _parse_social(lines: PackedStringArray) -> Dictionary:
	var marker_index := _find_prefixed_marker(lines, "SOCIAL_V")
	if marker_index < 0:
		return _failure("missing_legacy_social", "旧档缺少人情段。")
	var version_text := str(lines[marker_index]).strip_edges().trim_prefix("SOCIAL_V")
	var version := int(version_text) if version_text.is_valid_int() else 0
	if version < 1 or version > 3:
		return _failure("unsupported_legacy_social", "旧档人情版本不受支持。")
	var reader := LineReader.new(lines, marker_index + 1)
	var rumor_count := reader.take_count("人情风声数量", 2048)
	var rumors: Array[String] = []
	for rumor_index in range(rumor_count):
		var rumor := reader.take("人情风声")
		if version >= 2:
			rumor = _unescape_field(rumor)
		rumor = rumor.strip_edges().left(512)
		if not rumor.is_empty() and rumor_index >= maxi(0, rumor_count - 32):
			rumors.append(rumor)
	var threads: Array[Dictionary] = []
	if version >= 2:
		var thread_count := reader.take_count("人情人物数量", 512)
		for thread_index in range(thread_count):
			var thread := {
				"name": _unescape_field(reader.take("人情人物名")).strip_edges().left(48),
				"role": _unescape_field(reader.take("人情人物身份")).left(80),
				"attitude": _unescape_field(reader.take("人情人物态度")).left(80),
				"hook": _unescape_field(reader.take("人情人物线索")).left(256),
				"visible_realm": _unescape_field(reader.take("人情人物境界")).left(32),
				"hidden_hint": _unescape_field(reader.take("人情人物隐藏线索")).left(256),
				"desire": "", "fear": "", "next_move": "",
			}
			if version >= 3:
				thread["desire"] = _unescape_field(reader.take("人情人物欲望")).left(256)
				thread["fear"] = _unescape_field(reader.take("人情人物恐惧")).left(256)
				thread["next_move"] = _unescape_field(reader.take("人情人物下一步")).left(256)
			var values := reader.take_numbers("人情人物关系", 2)
			if reader.failed():
				break
			thread["player_relation"] = clampi(values[0], -100, 100)
			thread["hides_power"] = values[1] != 0
			if thread_index >= maxi(0, thread_count - 64) and not str(thread.name).is_empty():
				threads.append(thread)
	if reader.failed():
		return _failure("invalid_legacy_social", reader.error)
	return {"ok": true, "rumors": rumors, "threads": threads}


static func _parse_achievements(lines: PackedStringArray) -> Dictionary:
	var marker_index := _find_prefixed_marker(lines, "ACHIEVEMENTS_V")
	if marker_index < 0:
		return _failure("missing_legacy_achievements", "旧档缺少成就段。")
	var version_text := str(lines[marker_index]).strip_edges().trim_prefix("ACHIEVEMENTS_V")
	var version := int(version_text) if version_text.is_valid_int() else 0
	if version < 1 or version > 3:
		return _failure("unsupported_legacy_achievements", "旧档成就版本不受支持。")
	var reader := LineReader.new(lines, marker_index + 1)
	var achievement_count := reader.take_count("成就数量", 256)
	var achievements := {}
	for index in range(achievement_count):
		var unlocked := reader.take_int("成就状态", 0, 1) != 0
		if index < ACHIEVEMENT_IDS.size():
			achievements[ACHIEVEMENT_IDS[index]] = unlocked
	var weapons := {}
	var equipped_index := -1
	if version >= 2:
		var weapon_count := reader.take_count("玉兵数量", 256)
		for index in range(weapon_count):
			var values := reader.take_numbers("玉兵状态", 5 if version >= 3 else 1)
			if index >= WEAPON_IDS.size() or reader.failed():
				continue
			weapons[WEAPON_IDS[index]] = {
				"unlocked": values[0] != 0,
				"resonance": maxi(0, values[1]) if version >= 3 else 0,
				"stage": clampi(values[2], 0, 3) if version >= 3 else 0,
				"charge": clampi(values[3], 0, 100) if version >= 3 else 0,
				"invocations": maxi(0, values[4]) if version >= 3 else 0,
			}
		equipped_index = reader.take_int("已装备玉兵", -1, WEAPON_IDS.size() - 1)
	else:
		for index in range(ACHIEVEMENT_IDS.size()):
			if bool(achievements.get(ACHIEVEMENT_IDS[index], false)):
				weapons[WEAPON_IDS[index]] = {"unlocked": true}
	if reader.failed():
		return _failure("invalid_legacy_achievements", reader.error)
	var equipped_id: String = str(WEAPON_IDS[equipped_index]) if equipped_index >= 0 else ""
	return {"ok": true, "armory": {"version": 1, "achievements": achievements,
		"weapons": weapons, "equipped_id": equipped_id, "notices": []}}


static func _apply_story_import(state: Dictionary, story_result: Dictionary) -> void:
	var story: Dictionary = state.story
	story["unresolved_threads"] = (story_result.threads as Array).duplicate()
	story["arc_progress"] = (story_result.arc_progress as Dictionary).duplicate(true)
	story["arc_legacies"] = (story_result.arc_legacies as Dictionary).duplicate(true)
	story["arc_echoes"] = (story_result.arc_echoes as Dictionary).duplicate(true)
	story["imported_relationships"] = (story_result.relationships as Dictionary).duplicate(true)
	story["imported_world_law"] = str(story_result.world_law)
	story["imported_hongmeng_rule"] = str(story_result.hongmeng_rule)
	story["imported_jade_rule"] = str(story_result.jade_rule)
	story["imported_destiny"] = str(story_result.destiny)
	state["story"] = story
	var world: Dictionary = state.world
	world["era_pressure"] = clampi(int(story_result.faction_pressure), 0, 100)
	state["world"] = world
	for note in [str(story_result.synopsis), str(story_result.next_hook)]:
		if not note.is_empty():
			(state.recent_memories as Array).append(note.left(512))


static func _apply_social_import(state: Dictionary, social_result: Dictionary) -> void:
	var story: Dictionary = state.story
	story["imported_social_threads"] = (social_result.threads as Array).duplicate(true)
	state["story"] = story
	for rumor_value in (social_result.rumors as Array):
		var rumor := str(rumor_value).strip_edges().left(512)
		if not rumor.is_empty():
			(state.recent_memories as Array).append("旧世风声：%s" % rumor)
	var world: Dictionary = state.world
	var npcs: Array = world.get("npcs", [])
	for thread_value in (social_result.threads as Array):
		var thread: Dictionary = thread_value
		var match_index := -1
		for npc_index in range(npcs.size()):
			if str((npcs[npc_index] as Dictionary).get("name", "")) == str(thread.name):
				match_index = npc_index
				break
		var npc: Dictionary
		if match_index >= 0:
			npc = (npcs[match_index] as Dictionary).duplicate(true)
		else:
			if npcs.size() >= 24:
				continue
			var realm_index := _realm_index_for_name(str(thread.visible_realm))
			npc = {
				"id": "legacy_social_%02d" % (npcs.size() + 1), "name": str(thread.name),
				"realm_id": GameStateScript.REALM_IDS[realm_index], "realm_index": realm_index,
				"realm": GameStateScript.REALM_NAMES[realm_index], "level": 1,
				"age": 30, "lifespan": 80 + realm_index * 20, "alive": true,
				"faction_id": "", "relations": {}, "fame": 0,
			}
		npc["player_relation"] = int(thread.player_relation)
		npc["role"] = str(thread.role)
		npc["stance"] = str(thread.attitude).left(24)
		npc["attitude"] = str(thread.attitude)
		npc["hook"] = str(thread.hook)
		npc["hidden_hint"] = str(thread.hidden_hint)
		npc["desire"] = str(thread.desire)
		npc["fear"] = str(thread.fear)
		npc["next_move"] = str(thread.next_move)
		npc["hides_power"] = bool(thread.hides_power)
		if match_index >= 0:
			npcs[match_index] = npc
		else:
			npcs.append(npc)
	world["npcs"] = npcs
	state["world"] = world
	while (state.recent_memories as Array).size() > 64:
		(state.recent_memories as Array).pop_front()


static func _realm_index_for_name(value: String) -> int:
	var realm_name := value.strip_edges()
	var index := GameStateScript.REALM_NAMES.find(realm_name)
	if index >= 0:
		return index
	var realm_id := str(GameStateScript.LEGACY_REALM_ALIASES.get(realm_name, ""))
	if GameStateScript.REALM_IDS.has(realm_id):
		return GameStateScript.REALM_IDS.find(realm_id)
	return 0


static func _legacy_echo(index: int, legacy_type: int, name: String,
		description: String, power: int) -> Dictionary:
	return {"id": "win32_legacy_%03d" % index, "type": LEGACY_TYPES[legacy_type],
		"name": name, "description": description, "power": power}


static func _read_source(path: String) -> Dictionary:
	var normalized := path.strip_edges().simplify_path()
	if normalized.is_empty() or not normalized.is_absolute_path():
		return _failure("invalid_legacy_path", "旧档路径必须是绝对路径。")
	if not FileAccess.file_exists(normalized):
		return _failure("missing_legacy_save", "旧版存档不存在。")
	var file := FileAccess.open(normalized, FileAccess.READ)
	if file == null:
		return _failure("legacy_read_failed", "无法只读打开旧版存档。")
	var length := file.get_length()
	if length <= 0 or length > MAX_FILE_BYTES:
		file.close()
		return _failure("legacy_size_invalid", "旧版存档为空或体积异常。")
	var contents := file.get_as_text()
	file.close()
	if contents.is_empty():
		return _failure("legacy_read_failed", "旧版存档没有可读取内容。")
	var normalized_text := contents.replace("\r\n", "\n").replace("\r", "\n")
	var lines := normalized_text.split("\n", true)
	if lines.is_empty():
		return _failure("legacy_read_failed", "旧版存档没有有效行。")
	return {"ok": true, "path": normalized, "sha256": _sha256(contents), "lines": lines}


static func _section_reader(lines: PackedStringArray, markers: Array[String]) -> LineReader:
	for index in range(lines.size()):
		if markers.has(str(lines[index]).strip_edges()):
			return LineReader.new(lines, index + 1)
	return null


static func _find_prefixed_marker(lines: PackedStringArray, prefix: String) -> int:
	for index in range(lines.size()):
		if str(lines[index]).strip_edges().begins_with(prefix):
			return index
	return -1


static func _normalize_era_name(value: String) -> String:
	var era := value.strip_edges()
	if era in ["灵气初盛纪", "经典修仙纪", "古典修仙"]:
		return "古典修仙纪"
	if GameStateScript.ERA_NAMES.values().has(era):
		return era
	return "古典修仙纪"


static func _unescape_field(value: String) -> String:
	var result := ""
	var index := 0
	while index < value.length():
		var character := value.substr(index, 1)
		if character == "\\" and index + 1 < value.length():
			var next := value.substr(index + 1, 1)
			if next == "n":
				result += "\n"
				index += 2
				continue
			if next == "\\":
				result += "\\"
				index += 2
				continue
		result += character
		index += 1
	return result


static func _sha256(value: String) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(value.to_utf8_buffer()) != OK:
		return ""
	return context.finish().hex_encode()


static func _candidate_newer(left: Dictionary, right: Dictionary) -> bool:
	return int(left.get("modified_at_unix", 0)) > int(right.get("modified_at_unix", 0))


static func _failure(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
