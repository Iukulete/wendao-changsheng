class_name CultivationSystem
extends RefCounted

const GameStateScript = preload("res://scripts/game_state.gd")
const WorldSimulationScript = preload("res://scripts/world_simulation.gd")

const REALMS := [
	{"id": "mortal", "name": "凡人", "phase": "下界修真", "base_lifespan": 82},
	{"id": "qi_refining", "name": "炼气期", "phase": "下界修真", "base_lifespan": 180},
	{"id": "foundation", "name": "筑基期", "phase": "下界修真", "base_lifespan": 280},
	{"id": "golden_core", "name": "金丹期", "phase": "下界修真", "base_lifespan": 420},
	{"id": "nascent_soul", "name": "元婴期", "phase": "下界修真", "base_lifespan": 650},
	{"id": "spirit_severing", "name": "化神期", "phase": "下界修真", "base_lifespan": 900},
	{"id": "void_refining", "name": "炼虚期", "phase": "下界修真", "base_lifespan": 1150},
	{"id": "unity", "name": "合体期", "phase": "下界修真", "base_lifespan": 1400},
	{"id": "tribulation", "name": "渡劫期", "phase": "下界修真", "base_lifespan": 1700},
	{"id": "mahayana", "name": "大乘期", "phase": "下界修真", "base_lifespan": 2100},
	{"id": "half_immortal", "name": "半仙之体", "phase": "冲仙门", "base_lifespan": 2500},
	{"id": "true_immortal", "name": "真仙境", "phase": "仙界低阶", "base_lifespan": 3000},
	{"id": "heaven_immortal", "name": "天仙境", "phase": "仙界低阶", "base_lifespan": 3500},
	{"id": "mystic_immortal", "name": "玄仙境", "phase": "仙界低阶", "base_lifespan": 4100},
	{"id": "golden_immortal", "name": "金仙境", "phase": "仙界低阶", "base_lifespan": 4800},
	{"id": "immortal_lord", "name": "仙君", "phase": "仙界高阶", "base_lifespan": 5600},
	{"id": "immortal_king", "name": "仙王", "phase": "仙界高阶", "base_lifespan": 6500},
	{"id": "immortal_sovereign", "name": "仙尊", "phase": "仙界高阶", "base_lifespan": 7600},
	{"id": "immortal_emperor", "name": "仙帝", "phase": "至高主宰", "base_lifespan": 9000},
	{"id": "dao_ancestor", "name": "道祖", "phase": "与道共生", "base_lifespan": 12000},
	{"id": "heavenly_dao", "name": "道祖-天道境", "phase": "万道归一", "base_lifespan": 1000000},
]

const MEDITATION_MODE_IDS := ["steady", "rush", "insight"]

const MEDITATION_MODES := {
	"steady": {
		"name": "守一周天",
		"description": "收束气机，修为稍缓，同时恢复气血与灵力。",
		"gain_percent": 85,
	},
	"rush": {
		"name": "燃血冲脉",
		"description": "以气血换取最快积累；气血不足时不可强行运功。",
		"gain_percent": 145,
	},
	"insight": {
		"name": "引潮悟道",
		"description": "顺应当年灵潮调整周天，修为随天时浮动并增长道心。",
		"gain_percent": 0,
	},
}


static func exp_needed(player: Dictionary) -> int:
	var realm_index := _realm_index(player)
	var level := clampi(int(player.get("level", 1)), 1, 9)
	if realm_index == 0:
		return 4 * level
	if realm_index == 1:
		return 24 * level
	if realm_index == 2:
		return 62 * level
	if realm_index == 3:
		return 125 * level
	var unit := 125 + (realm_index - 3) * 55
	if realm_index >= 10:
		unit += 180 + (realm_index - 10) * 45
	if realm_index >= 11:
		unit += 220 + (realm_index - 11) * 70
	if realm_index >= 19:
		unit += 520
	return unit * level


static func meditation_preview(state: Dictionary, mode_id: String) -> Dictionary:
	if not MEDITATION_MODE_IDS.has(mode_id):
		return {"ok": false, "code": "invalid_meditation_mode"}
	var player: Dictionary = state.get("player", {})
	if player.is_empty():
		return {"ok": false, "code": "missing_player"}
	var realm_index := _realm_index(player)
	var minimum_gain := _meditation_gain(player, realm_index, 28, mode_id, state)
	var maximum_gain := _meditation_gain(player, realm_index, 100, mode_id, state)
	var max_hp := maxi(1, int(player.get("max_hp", 1)))
	var hp_cost := maxi(8, int(ceil(float(max_hp) * 0.14))) if mode_id == "rush" else 0
	var heal := maxi(10, int(ceil(float(max_hp) * 0.12))) if mode_id == "steady" else 0
	return {
		"ok": true,
		"code": "preview_ready",
		"mode_id": mode_id,
		"name": str(MEDITATION_MODES[mode_id].name),
		"description": str(MEDITATION_MODES[mode_id].description),
		"minimum_gain": minimum_gain,
		"maximum_gain": maximum_gain,
		"hp_cost": hp_cost,
		"heal": heal,
		"dao_heart_gain": 1 if mode_id == "insight" else 0,
		"available": mode_id != "rush" or int(player.get("hp", 0)) > hp_cost,
		"qi_tide": int((state.get("world", {}) as Dictionary).get("qi_tide", 50)),
	}


static func meditate(state: Dictionary, roll: int = -1, mode_id: String = "steady") -> Dictionary:
	var player: Dictionary = state.get("player", {})
	if player.is_empty():
		return {"ok": false, "code": "missing_player"}
	if bool(state.get("life_closed", false)) or is_dead(state):
		return {"ok": false, "code": "life_ended", "dead": true}
	if not MEDITATION_MODE_IDS.has(mode_id):
		return {"ok": false, "code": "invalid_meditation_mode"}
	var realm_index := _realm_index(player)
	var actual_roll := _roll(state, 28, 100) if roll < 0 else clampi(roll, 0, 100)
	var gain := _meditation_gain(player, realm_index, actual_roll, mode_id, state)
	var max_hp := maxi(1, int(player.get("max_hp", 1)))
	var hp_cost := maxi(8, int(ceil(float(max_hp) * 0.14))) if mode_id == "rush" else 0
	if mode_id == "rush" and int(player.get("hp", 0)) <= hp_cost:
		return {
			"ok": false,
			"code": "insufficient_hp",
			"message": "当前气血不足以承受燃血冲脉，先守一周天或服用丹药。",
			"required_hp": hp_cost + 1,
		}
	player["exp"] = int(player.get("exp", 0)) + gain
	player["mp"] = mini(int(player.get("max_mp", 0)), int(player.get("mp", 0)) + 5)
	advance_time(state, 1)
	var levels_gained := 0
	while int(player.level) < 9 and int(player.exp) >= exp_needed(player):
		player["exp"] = int(player.exp) - exp_needed(player)
		_level_up(player)
		levels_gained += 1
	var hp_recovered := 0
	var dao_heart_gain := 0
	if mode_id == "steady":
		var recovery := maxi(10, int(ceil(float(player.get("max_hp", 1)) * 0.12)))
		var hp_before := int(player.get("hp", 0))
		player["hp"] = mini(int(player.get("max_hp", 1)), hp_before + recovery)
		player["mp"] = mini(int(player.get("max_mp", 0)),
			int(player.get("mp", 0)) + maxi(6, int(player.get("max_mp", 0)) / 6))
		hp_recovered = int(player.hp) - hp_before
	elif mode_id == "rush":
		player["hp"] = maxi(1, int(player.get("hp", 1)) - hp_cost)
	elif mode_id == "insight":
		player["dao_heart"] = int(player.get("dao_heart", 0)) + 1
		dao_heart_gain = 1
	state["player"] = player
	return {
		"ok": true,
		"code": "meditated",
		"mode_id": mode_id,
		"mode_name": str(MEDITATION_MODES[mode_id].name),
		"gain": gain,
		"levels_gained": levels_gained,
		"hp_cost": hp_cost if mode_id == "rush" else 0,
		"hp_recovered": hp_recovered,
		"dao_heart_gain": dao_heart_gain,
		"dead": is_dead(state),
		"lifespan_pressure": lifespan_pressure(player),
	}


static func can_breakthrough(player: Dictionary) -> Dictionary:
	var realm_index := _realm_index(player)
	if realm_index >= REALMS.size() - 1:
		return {"ok": false, "code": "peak_reached", "message": "你已与天道并行，前方不再是境界。"}
	if int(player.get("level", 1)) < 9:
		return {"ok": false, "code": "layer_incomplete", "message": "当前境界尚未修至九层。"}
	if realm_index > 0 and int(player.get("exp", 0)) < exp_needed(player):
		return {
			"ok": false, "code": "insufficient_exp",
			"message": "破境积累尚差 %d。" % (exp_needed(player) - int(player.get("exp", 0))),
		}
	if realm_index == 9 and not _is_balanced(player):
		return {"ok": false, "code": "roots_unbalanced", "message": "五行尚未圆融，仙门不会为偏缺之身开启。"}
	return {"ok": true, "code": "ready"}


static func breakthrough_chance(player: Dictionary) -> int:
	var realm_index := _realm_index(player)
	var chance := 38 + _root_total(player) + int(player.get("karma", 0)) / 4
	chance += int(player.get("dao_heart", 0)) * 2
	if _is_balanced(player):
		chance += 15
	if realm_index == 0:
		chance += 20
	if realm_index >= 11:
		chance -= 20
	if realm_index >= 19:
		chance -= 35
	return clampi(chance, 10, 95)


static func attempt_breakthrough(state: Dictionary, roll: int = -1) -> Dictionary:
	var player: Dictionary = state.get("player", {})
	if player.is_empty():
		return {"ok": false, "code": "missing_player"}
	if bool(state.get("life_closed", false)) or is_dead(state):
		return {"ok": false, "code": "life_ended", "dead": true,
			"message": "这一世已经走到尽头，无法再叩问瓶颈。"}
	var readiness := can_breakthrough(player)
	if not bool(readiness.get("ok", false)):
		return readiness
	var chance := breakthrough_chance(player)
	var actual_roll := _roll(state, 1, 100) if roll < 0 else clampi(roll, 1, 100)
	advance_time(state, 1)
	if actual_roll <= chance:
		var next_index := _realm_index(player) + 1
		player["realm_index"] = next_index
		player["realm_id"] = str(REALMS[next_index].id)
		player["realm"] = str(REALMS[next_index].name)
		player["level"] = 1
		player["exp"] = 0
		var bonuses := _breakthrough_bonuses(next_index)
		player["max_hp"] = int(player.get("max_hp", 1)) + int(bonuses.hp)
		player["max_mp"] = int(player.get("max_mp", 0)) + int(bonuses.mp)
		player["hp"] = int(player.max_hp)
		player["mp"] = int(player.max_mp)
		player["lifespan"] = maxi(int(player.get("lifespan", 1)) + int(bonuses.lifespan),
			int(REALMS[next_index].base_lifespan))
		player["attack"] = int(player.get("attack", 0)) + 20
		player["defense"] = int(player.get("defense", 0)) + 10
		player["dao_heart"] = int(player.get("dao_heart", 0)) + 2
		state["player"] = player
		return {
			"ok": true, "code": "breakthrough_success", "success": true,
			"chance": chance, "roll": actual_roll, "realm": player.realm,
		}
	player["hp"] = maxi(1, int(player.get("max_hp", 1)) / 2)
	player["exp"] = maxi(0, int(player.get("exp", 0)) / 2)
	if _realm_index(player) == 0:
		player["level"] = 8
	state["player"] = player
	return {
		"ok": true, "code": "breakthrough_failed", "success": false,
		"chance": chance, "roll": actual_roll, "dead": is_dead(state),
	}


static func advance_time(state: Dictionary, years: int) -> void:
	var safe_years := maxi(0, years)
	var player: Dictionary = state.get("player", {})
	player["age"] = int(player.get("age", 0)) + safe_years
	state["player"] = player
	for _year in range(safe_years):
		WorldSimulationScript.advance_year(state)
	state["turn"] = int(state.get("turn", 0)) + 1


static func is_dead(state: Dictionary) -> bool:
	var player: Dictionary = state.get("player", {})
	if int(player.get("hp", 0)) <= 0:
		return true
	if _realm_index(player) >= 19:
		return false
	return int(player.get("age", 0)) >= int(player.get("lifespan", 1))


static func lifespan_pressure(player: Dictionary) -> String:
	if _realm_index(player) >= 19:
		return "与道共生"
	var remaining := int(player.get("lifespan", 1)) - int(player.get("age", 0))
	if remaining <= 0:
		return "寿尽"
	var ratio := float(remaining) / maxf(1.0, float(player.get("lifespan", 1)))
	if ratio <= 0.08:
		return "风烛"
	if ratio <= 0.20:
		return "迫近"
	if ratio <= 0.40:
		return "有压"
	return "从容"


static func _realm_index(player: Dictionary) -> int:
	return clampi(int(player.get("realm_index", 0)), 0, REALMS.size() - 1)


static func _root_total(player: Dictionary) -> int:
	var total := 0
	for value in player.get("roots", []):
		total += int(value)
	return total


static func _is_balanced(player: Dictionary) -> bool:
	var roots: Array = player.get("roots", [])
	if roots.size() != 5:
		return false
	var minimum := int(roots[0])
	var maximum := int(roots[0])
	for value in roots:
		minimum = mini(minimum, int(value))
		maximum = maxi(maximum, int(value))
	return maximum - minimum <= 3 and minimum >= 5


static func _meditation_base(realm_index: int) -> int:
	if realm_index == 0:
		return 58
	if realm_index == 1:
		return 138
	if realm_index == 2:
		return 112
	if realm_index == 3:
		return 92
	if realm_index <= 9:
		return 155 + (realm_index - 4) * 24
	if realm_index <= 18:
		return 320 + (realm_index - 10) * 92
	return 820 + (realm_index - 19) * 260


static func _meditation_gain(player: Dictionary, realm_index: int, roll: int,
		mode_id: String, state: Dictionary) -> int:
	var total_root := _root_total(player)
	var base_gain := _meditation_base(realm_index) + total_root * _root_scale(realm_index)
	var variance := int(round(base_gain * (float(roll) - 50.0) / 250.0))
	var gain: int = maxi(1, base_gain + variance)
	if _is_balanced(player):
		gain = int(round(gain * 1.18))
	elif total_root < 22:
		gain = int(round(gain * 0.62))
	var gain_percent := int((MEDITATION_MODES.get(mode_id, MEDITATION_MODES.steady) as Dictionary).get("gain_percent", 85))
	if mode_id == "insight":
		var qi_tide := clampi(int((state.get("world", {}) as Dictionary).get("qi_tide", 50)), 0, 100)
		gain_percent = 70 + int(qi_tide / 2.0)
	return maxi(1, int(round(float(gain) * float(gain_percent) / 100.0)))


static func _root_scale(realm_index: int) -> int:
	if realm_index <= 3:
		return 3
	if realm_index <= 10:
		return 2
	if realm_index <= 18:
		return 4
	return 5


static func _level_up(player: Dictionary) -> void:
	player["level"] = mini(9, int(player.get("level", 1)) + 1)
	var scale := 3 if _realm_index(player) >= 11 else 1
	player["max_hp"] = int(player.get("max_hp", 1)) + 20 * scale
	player["max_mp"] = int(player.get("max_mp", 0)) + 10 * scale
	player["attack"] = int(player.get("attack", 0)) + 5 * scale
	player["defense"] = int(player.get("defense", 0)) + 3 * scale
	player["hp"] = int(player.max_hp)
	player["mp"] = int(player.max_mp)


static func _breakthrough_bonuses(target_realm_index: int) -> Dictionary:
	if target_realm_index == 11:
		return {"hp": 500, "mp": 300, "lifespan": 1000}
	if target_realm_index == 19:
		return {"hp": 5000, "mp": 3000, "lifespan": 100000}
	if target_realm_index == 20:
		return {"hp": 20000, "mp": 12000, "lifespan": 1000000}
	return {"hp": 100, "mp": 50, "lifespan": 100}


static func _roll(state: Dictionary, minimum: int, maximum: int) -> int:
	var cursor := int(state.get("rng_cursor", 0))
	var seed_value := int(state.get("world_seed", 1)) + cursor * 104729 + int(state.get("turn", 0)) * 8191
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	state["rng_cursor"] = cursor + 1
	return rng.randi_range(minimum, maximum)
