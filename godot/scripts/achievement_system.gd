class_name AchievementSystem
extends RefCounted

const DATA_PATH := "res://data/jade_armory_v1.json"
const STAGE_THRESHOLDS := [0, 30, 120, 300]
const STAGE_NAMES := ["沉眠", "初鸣", "真名", "道化"]
const TIER_NAMES := ["灵玉", "玄金", "天命"]
const MAX_NOTICES := 32

static var _definitions_cache: Dictionary = {}


static func load_definitions() -> Dictionary:
	if not _definitions_cache.is_empty():
		return _definitions_cache
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		_definitions_cache = (parsed as Dictionary).duplicate(true)
	return _definitions_cache


static func validate_definitions() -> Dictionary:
	var data := load_definitions()
	if int(data.get("schema_version", 0)) != 1:
		return {"ok": false, "code": "unsupported_armory_schema"}
	var weapons: Variant = data.get("weapons", [])
	var achievements: Variant = data.get("achievements", [])
	if not weapons is Array or (weapons as Array).size() != 16 or not achievements is Array or \
			(achievements as Array).size() != 16:
		return {"ok": false, "code": "invalid_definition_count"}
	var weapon_ids := {}
	for weapon_value in (weapons as Array):
		if not weapon_value is Dictionary:
			return {"ok": false, "code": "invalid_weapon"}
		var weapon: Dictionary = weapon_value
		var weapon_id := str(weapon.get("id", ""))
		if weapon_id.is_empty() or weapon_ids.has(weapon_id) or str(weapon.get("name", "")).is_empty() or \
				not weapon.get("bonuses", null) is Dictionary or str(weapon.get("style", "")) not in \
				["slaughter", "guardian", "insight", "myriad"]:
			return {"ok": false, "code": "invalid_weapon"}
		weapon_ids[weapon_id] = true
	var achievement_ids := {}
	for achievement_value in (achievements as Array):
		if not achievement_value is Dictionary:
			return {"ok": false, "code": "invalid_achievement"}
		var achievement: Dictionary = achievement_value
		var achievement_id := str(achievement.get("id", ""))
		if achievement_id.is_empty() or achievement_ids.has(achievement_id) or \
				not weapon_ids.has(str(achievement.get("weapon_id", ""))) or \
				not achievement.get("condition", null) is Dictionary:
			return {"ok": false, "code": "invalid_achievement"}
		achievement_ids[achievement_id] = true
	return {"ok": true, "code": "valid", "achievement_count": achievement_ids.size(),
		"weapon_count": weapon_ids.size()}


static func normalize(state: Dictionary) -> Dictionary:
	var legacy_value: Variant = state.get("legacy", {})
	var legacy: Dictionary = legacy_value if legacy_value is Dictionary else {}
	var armory_value: Variant = legacy.get("armory", {})
	var armory: Dictionary = armory_value.duplicate(true) if armory_value is Dictionary else {}
	armory["version"] = 1
	var achievements_value: Variant = armory.get("achievements", {})
	var source_achievements: Dictionary = achievements_value if achievements_value is Dictionary else {}
	var achievements := {}
	for definition_value in (load_definitions().get("achievements", []) as Array):
		var definition: Dictionary = definition_value
		achievements[str(definition.id)] = bool(source_achievements.get(str(definition.id), false))
	armory["achievements"] = achievements
	var weapons_value: Variant = armory.get("weapons", {})
	var source_weapons: Dictionary = weapons_value if weapons_value is Dictionary else {}
	var weapons := {}
	for definition_value in (load_definitions().get("weapons", []) as Array):
		var definition: Dictionary = definition_value
		var weapon_id := str(definition.id)
		var source_value: Variant = source_weapons.get(weapon_id, {})
		var source: Dictionary = source_value if source_value is Dictionary else {}
		var resonance := clampi(int(source.get("resonance", 0)), 0, 999999)
		weapons[weapon_id] = {
			"unlocked": bool(source.get("unlocked", false)), "resonance": resonance,
			"stage": maxi(clampi(int(source.get("stage", 0)), 0, 3), _stage_from_resonance(resonance)),
			"charge": clampi(int(source.get("charge", 0)), 0, 100),
			"invocations": clampi(int(source.get("invocations", 0)), 0, 1000000),
		}
	armory["weapons"] = weapons
	for achievement_value in (load_definitions().get("achievements", []) as Array):
		var achievement: Dictionary = achievement_value
		if bool(achievements.get(str(achievement.id), false)):
			var weapon: Dictionary = weapons[str(achievement.weapon_id)]
			weapon["unlocked"] = true
			weapons[str(achievement.weapon_id)] = weapon
	armory["notices"] = _bounded_array(armory.get("notices", []), MAX_NOTICES)
	var equipped_id := str(armory.get("equipped_id", ""))
	if equipped_id.is_empty() or not weapons.has(equipped_id) or not bool((weapons[equipped_id] as Dictionary).unlocked):
		equipped_id = _strongest_unlocked(weapons)
	armory["equipped_id"] = equipped_id
	legacy["armory"] = armory
	state["legacy"] = legacy
	return armory


static func check_progress(state: Dictionary) -> Dictionary:
	var armory := normalize(state)
	var unlocked: Array[Dictionary] = []
	for achievement_value in (load_definitions().get("achievements", []) as Array):
		var achievement: Dictionary = achievement_value
		var achievement_id := str(achievement.id)
		if bool((armory.achievements as Dictionary).get(achievement_id, false)):
			continue
		if _condition_met(state, achievement.condition, armory):
			unlocked.append(_unlock(state, achievement))
			armory = state.legacy.armory
	return {"ok": true, "code": "progress_checked", "unlocked": unlocked,
		"count": unlocked_count(state)}


static func consume_notices(state: Dictionary) -> Array:
	var armory := normalize(state)
	var notices: Array = armory.notices.duplicate(true)
	armory["notices"] = []
	state.legacy["armory"] = armory
	return notices


static func unlocked_count(state: Dictionary) -> int:
	var armory := normalize(state)
	var count := 0
	for value in (armory.achievements as Dictionary).values():
		if bool(value):
			count += 1
	return count


static func effective_bonuses(state: Dictionary) -> Dictionary:
	var armory := normalize(state)
	var result := {"attack": 0, "defense": 0, "max_hp": 0, "dao_heart": 0}
	var weapon_id := str(armory.equipped_id)
	if weapon_id.is_empty():
		return result
	var definition := weapon_definition(weapon_id)
	var weapon: Dictionary = armory.weapons[weapon_id]
	var stage := int(weapon.stage)
	var scale_percent: int = int([0, 20, 45, 80][stage])
	for stat_id in result.keys():
		var base := int((definition.get("bonuses", {}) as Dictionary).get(stat_id, 0))
		result[stat_id] = base + base * scale_percent / 100
	match str(definition.style):
		"slaughter": result.attack += stage * 3
		"guardian":
			result.defense += stage * 2
			result.max_hp += stage * 45
		"insight": result.dao_heart += stage * 2
		"myriad":
			result.attack += stage * 2
			result.defense += stage * 2
			result.max_hp += stage * 30
			result.dao_heart += stage
	return result


static func add_resonance(state: Dictionary, amount: int, reason: String) -> Dictionary:
	var armory := normalize(state)
	var weapon_id := str(armory.equipped_id)
	if amount <= 0 or weapon_id.is_empty():
		return {"ok": false, "code": "no_equipped_jade_weapon"}
	var weapon: Dictionary = armory.weapons[weapon_id]
	var previous_stage := int(weapon.stage)
	weapon["resonance"] = mini(999999, int(weapon.resonance) + amount)
	weapon["charge"] = mini(100, int(weapon.charge) + maxi(1, amount * 4))
	weapon["stage"] = maxi(previous_stage, _stage_from_resonance(int(weapon.resonance)))
	armory.weapons[weapon_id] = weapon
	if int(weapon.stage) > previous_stage:
		_append_notice(armory, {"kind": "awakening", "id": "awaken_%s_%d" % [weapon_id, int(weapon.stage)],
			"name": "%s·%s" % [str(weapon_definition(weapon_id).name), stage_name(int(weapon.stage))],
			"description": "轮回玉兵因%s完成新一层苏醒。" % reason,
			"tier": mini(2, maxi(int(weapon_definition(weapon_id).tier), int(weapon.stage) - 1)),
			"reward_weapon": str(weapon_definition(weapon_id).name)})
	state.legacy["armory"] = armory
	return {"ok": true, "code": "resonance_added", "weapon_id": weapon_id,
		"resonance": int(weapon.resonance), "charge": int(weapon.charge),
		"stage": int(weapon.stage), "awakened": int(weapon.stage) > previous_stage}


static func cycle_weapon(state: Dictionary) -> Dictionary:
	var armory := normalize(state)
	var definitions: Array = load_definitions().get("weapons", [])
	var current_index := -1
	for index in range(definitions.size()):
		if str((definitions[index] as Dictionary).id) == str(armory.equipped_id):
			current_index = index
			break
	for offset in range(1, definitions.size() + 1):
		var index := (current_index + offset) % definitions.size()
		var weapon_id := str((definitions[index] as Dictionary).id)
		if bool((armory.weapons[weapon_id] as Dictionary).unlocked):
			armory["equipped_id"] = weapon_id
			state.legacy["armory"] = armory
			return {"ok": true, "code": "weapon_cycled", "weapon_id": weapon_id,
				"name": str((definitions[index] as Dictionary).name)}
	return {"ok": false, "code": "no_unlocked_weapon"}


static func equip_weapon(state: Dictionary, weapon_id: String) -> Dictionary:
	var armory := normalize(state)
	if not (armory.weapons as Dictionary).has(weapon_id) or \
			not bool((armory.weapons[weapon_id] as Dictionary).unlocked):
		return {"ok": false, "code": "weapon_locked"}
	armory["equipped_id"] = weapon_id
	state.legacy["armory"] = armory
	return {"ok": true, "code": "weapon_equipped", "weapon_id": weapon_id,
		"name": str(weapon_definition(weapon_id).name)}


static func invoke(state: Dictionary) -> Dictionary:
	var armory := normalize(state)
	var weapon_id := str(armory.equipped_id)
	if weapon_id.is_empty():
		return {"ok": false, "code": "no_equipped_jade_weapon"}
	var weapon: Dictionary = armory.weapons[weapon_id]
	if int(weapon.charge) < 100:
		return {"ok": false, "code": "insufficient_charge", "charge": int(weapon.charge)}
	var definition := weapon_definition(weapon_id)
	var style := str(definition.style)
	var stage := int(weapon.stage)
	var player: Dictionary = state.get("player", {})
	var result := {"ok": true, "code": "jade_weapon_invoked", "weapon_id": weapon_id,
		"name": str(definition.name), "style": style, "stage": stage, "exp": 0, "heal": 0,
		"spirit_stones": 0, "dao_heart": 0, "pill": 0}
	if style == "slaughter":
		result.exp = 70 + stage * 45
		result.spirit_stones = 2 + stage * 2
	elif style == "guardian":
		result.heal = mini(int(player.max_hp) - int(player.hp), maxi(1, int(player.max_hp) * (35 + stage * 10) / 100))
		result.pill = 1 if stage >= 2 else 0
	elif style == "insight":
		result.exp = 45 + stage * 35
		result.dao_heart = 2 + stage * 2
	else:
		result.exp = 35 + stage * 30
		result.heal = mini(int(player.max_hp) - int(player.hp), maxi(1, int(player.max_hp) * (20 + stage * 8) / 100))
		result.dao_heart = 1 + stage
	player["exp"] = int(player.exp) + int(result.exp)
	player["hp"] = mini(int(player.max_hp), int(player.hp) + int(result.heal))
	player["spirit_stones"] = int(player.spirit_stones) + int(result.spirit_stones)
	player["dao_heart"] = int(player.dao_heart) + int(result.dao_heart)
	player["pills"] = int(player.get("pills", 0)) + int(result.pill)
	state["player"] = player
	weapon["charge"] = 0
	weapon["invocations"] = int(weapon.invocations) + 1
	armory.weapons[weapon_id] = weapon
	state.legacy["armory"] = armory
	return result


static func current_weapon(state: Dictionary) -> Dictionary:
	var armory := normalize(state)
	var weapon_id := str(armory.equipped_id)
	if weapon_id.is_empty():
		return {}
	var result := weapon_definition(weapon_id).duplicate(true)
	for key in (armory.weapons[weapon_id] as Dictionary).keys():
		result[key] = armory.weapons[weapon_id][key]
	result["stage_name"] = stage_name(int(result.stage))
	return result


static func weapon_definition(weapon_id: String) -> Dictionary:
	for value in (load_definitions().get("weapons", []) as Array):
		var weapon: Dictionary = value
		if str(weapon.id) == weapon_id:
			return weapon
	return {}


static func stage_name(stage: int) -> String:
	return STAGE_NAMES[clampi(stage, 0, 3)]


static func _unlock(state: Dictionary, achievement: Dictionary) -> Dictionary:
	var armory: Dictionary = state.legacy.armory
	armory.achievements[str(achievement.id)] = true
	var weapon_id := str(achievement.weapon_id)
	var weapon: Dictionary = armory.weapons[weapon_id]
	weapon["unlocked"] = true
	armory.weapons[weapon_id] = weapon
	var previous_equipped := str(armory.equipped_id)
	if previous_equipped.is_empty() or _weapon_score(weapon_id, weapon) > \
			_weapon_score(previous_equipped, armory.weapons[previous_equipped]):
		armory["equipped_id"] = weapon_id
	var definition := weapon_definition(weapon_id)
	var notice := {"kind": "achievement", "id": str(achievement.id), "name": str(achievement.name),
		"description": str(achievement.description), "tier": int(achievement.tier),
		"reward_weapon": str(definition.name), "reward_text": str(definition.description)}
	_append_notice(armory, notice)
	state.legacy["armory"] = armory
	return notice


static func _condition_met(state: Dictionary, condition: Dictionary, armory: Dictionary) -> bool:
	var condition_type := str(condition.get("type", ""))
	var value := int(condition.get("value", 0))
	var player: Dictionary = state.get("player", {})
	if condition_type == "player_min":
		return int(player.get(str(condition.get("field", "")), 0)) >= value
	if condition_type == "player_max":
		return int(player.get(str(condition.get("field", "")), 0)) <= value
	if condition_type == "state_min":
		return int(state.get(str(condition.get("field", "")), 0)) >= value
	if condition_type == "legacy_echo_count":
		return _legacy_echo_count(state) >= value
	if condition_type == "arc_progress":
		var total := 0
		for progress in ((state.get("story", {}) as Dictionary).get("arc_progress", {}) as Dictionary).values():
			total += int(progress)
		return total >= value
	if condition_type == "arc_legacy_count":
		var count := 0
		for tag in ((state.get("story", {}) as Dictionary).get("arc_legacies", {}) as Dictionary).values():
			if not str(tag).is_empty(): count += 1
		return count >= value
	if condition_type == "relic_stage":
		return int(((state.get("legacy", {}) as Dictionary).get("relic", {}) as Dictionary).get("awakening_stage", 0)) >= value
	if condition_type == "achievement_count":
		var count := 0
		for unlocked in (armory.achievements as Dictionary).values():
			if bool(unlocked): count += 1
		return count >= value
	return false


static func _legacy_echo_count(state: Dictionary) -> int:
	var ids := {}
	var legacy: Dictionary = state.get("legacy", {})
	for echo_value in (legacy.get("inherited_echoes", []) as Array):
		if echo_value is Dictionary:
			ids[str((echo_value as Dictionary).get("id", ""))] = true
	for life_value in (legacy.get("past_lives", []) as Array):
		if life_value is Dictionary:
			for echo_value in ((life_value as Dictionary).get("echoes", []) as Array):
				if echo_value is Dictionary:
					ids[str((echo_value as Dictionary).get("id", ""))] = true
	ids.erase("")
	return ids.size()


static func _strongest_unlocked(weapons: Dictionary) -> String:
	var best_id := ""
	var best_score := -1
	for weapon_id_value in weapons.keys():
		var weapon_id := str(weapon_id_value)
		var weapon: Dictionary = weapons[weapon_id]
		if bool(weapon.unlocked):
			var score := _weapon_score(weapon_id, weapon)
			if score > best_score:
				best_score = score
				best_id = weapon_id
	return best_id


static func _weapon_score(weapon_id: String, weapon: Dictionary) -> int:
	var definition := weapon_definition(weapon_id)
	var bonuses: Dictionary = definition.get("bonuses", {})
	return int(definition.get("tier", 0)) * 1000 + int(bonuses.get("attack", 0)) * 20 + \
		int(bonuses.get("defense", 0)) * 16 + int(bonuses.get("max_hp", 0)) / 4 + \
		int(bonuses.get("dao_heart", 0)) * 18 + int(weapon.get("stage", 0)) * 260 + \
		int(weapon.get("resonance", 0)) / 3


static func _stage_from_resonance(resonance: int) -> int:
	if resonance >= STAGE_THRESHOLDS[3]: return 3
	if resonance >= STAGE_THRESHOLDS[2]: return 2
	if resonance >= STAGE_THRESHOLDS[1]: return 1
	return 0


static func _append_notice(armory: Dictionary, notice: Dictionary) -> void:
	var notices: Array = armory.notices
	notices.append(notice)
	armory["notices"] = _bounded_array(notices, MAX_NOTICES)


static func _bounded_array(value: Variant, maximum: int) -> Array:
	var result: Array = value.duplicate(true) if value is Array else []
	while result.size() > maximum:
		result.pop_front()
	return result
