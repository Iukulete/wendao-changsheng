class_name ReincarnationSystem
extends RefCounted

const GameStateScript = preload("res://scripts/game_state.gd")
const WorldSimulationScript = preload("res://scripts/world_simulation.gd")
const ItemSystemScript = preload("res://scripts/item_system.gd")
const StorySystemScript = preload("res://scripts/story_system.gd")

const REBIRTH_MIN_CHANCE := 18
const REBIRTH_MAX_CHANCE := 92

const DAO_NAMES := {
	"compassion": "护生大道",
	"ambition": "凌霄大道",
	"defiance": "逆命大道",
	"insight": "照因大道",
	"creation": "造化大道",
	"bonds": "众生大道",
}

const DAO_ECHOES := {
	"compassion": ["护生余愿", "前世护住的性命会在陌生人身上回望你。"],
	"ambition": ["未竟高台", "越接近权柄，越能听见前世没有登完的阶梯。"],
	"defiance": ["逆命旧痕", "曾经拒绝的天命不会消失，只会换一种方式重来。"],
	"insight": ["照因残卷", "偶然发生之前，你有时会先看见它的影子。"],
	"creation": ["造化器纹", "前世造物留下的手感仍藏在指骨与灵台之间。"],
	"bonds": ["众生回声", "真正结下的人情不会因一场死亡自动清零。"],
}


static func close_life(state: Dictionary, cause: String, rebirth_roll: int = -1) -> Dictionary:
	if bool(state.get("life_closed", false)):
		return {"ok": false, "code": "already_closed"}
	var player: Dictionary = state.get("player", {})
	var legacy: Dictionary = state.get("legacy", GameStateScript.create_legacy_state())
	var story: Dictionary = state.get("story", {})
	var path: Dictionary = player.get("path", {})
	var dao_id := _dominant_path(path)
	var past_life := {
		"generation": int(state.get("generation", 1)),
		"name": str(player.get("name", "无名")),
		"realm_id": str(player.get("realm_id", "mortal")),
		"realm_index": int(player.get("realm_index", 0)),
		"realm": str(player.get("realm", "凡人")),
		"level": int(player.get("level", 1)),
		"age_at_death": int(player.get("age", 18)),
		"cause_of_death": cause.left(160),
		"karma": int(player.get("karma", 0)),
		"total_events": int(player.get("total_events", 0)),
		"battles_won": int(player.get("battles_won", 0)),
		"npcs_met": int(player.get("npcs_met", 0)),
		"path": path.duplicate(true),
		"dao_id": dao_id,
		"dao_name": str(DAO_NAMES.get(dao_id, "本我大道")),
		"memory_fragments": state.get("recent_memories", []).duplicate().slice(-8),
		"unfinished_threads": story.get("unresolved_threads", []).duplicate().slice(-8),
		"echoes": _build_echoes(player, dao_id),
	}
	var lives: Array = legacy.get("past_lives", [])
	lives.append(past_life)
	while lives.size() > 64:
		lives.pop_front()
	legacy["past_lives"] = lives
	legacy["unresolved_threads"] = past_life.unfinished_threads.duplicate()
	var relic: Dictionary = legacy.get("relic", {})
	var resonance_gain := 8 + int(player.get("realm_index", 0)) * 3
	resonance_gain += int(player.get("total_events", 0)) / 4 + absi(int(player.get("karma", 0))) / 8
	relic["resonance"] = int(relic.get("resonance", 0)) + resonance_gain
	relic["awakening_stage"] = _awakening_stage(int(relic.resonance))
	relic["aspect"] = _awakening_aspect(int(relic.awakening_stage))
	if int(player.get("realm_index", 0)) >= 19:
		relic["dao_id"] = dao_id
		relic["dao_depth"] = int(relic.get("dao_depth", 0)) + 30 + int(player.get("total_events", 0)) / 5
		relic["aspect"] = "%s·祖境道痕" % str(DAO_NAMES.get(dao_id, "本我大道"))
	legacy["relic"] = relic
	state["legacy"] = legacy
	state["life_closed"] = true
	var verdict := judge_rebirth(state, rebirth_roll)
	state["ending_state"] = "rebirth_ready" if bool(verdict.get("triggered", false)) else "lineage_ended"
	state["feedback"] = "%s享年%d岁，此世道痕已被黑白旧玉收存。%s" % [
		player.name, player.age,
		"玉中传来新生的心跳。" if bool(verdict.get("triggered", false)) else "旧玉最终没有再亮起。",
	]
	return {
		"ok": true, "code": "life_closed", "past_life": past_life,
		"resonance_gain": resonance_gain, "rebirth": verdict,
	}


static func rebirth_chance(state: Dictionary) -> Dictionary:
	var player: Dictionary = state.get("player", {})
	var legacy: Dictionary = state.get("legacy", {})
	var story: Dictionary = state.get("story", {})
	var equipped: Dictionary = (state.get("inventory", {}) as Dictionary).get("equipped", {})
	var relic: Dictionary = legacy.get("relic", {})
	var resolved_count := (story.get("resolved_arcs", []) as Array).size()
	var unfinished_count := (story.get("unresolved_threads", []) as Array).size()
	var factors: Array[Dictionary] = [
		{"label": "凡命余火", "value": 24},
	]
	if str(equipped.get("relic_id", "")) == "black_white_jade":
		factors.append({"label": "黑白旧玉认主", "value": 22})
	var awakening_bonus := clampi(int(relic.get("awakening_stage", 0)) * 6, 0, 30)
	if awakening_bonus > 0:
		factors.append({"label": "旧玉苏醒", "value": awakening_bonus})
	var story_bonus := clampi(resolved_count * 4, 0, 20)
	if story_bonus > 0:
		factors.append({"label": "已兑现的跨世因果", "value": story_bonus})
	var heart_bonus := clampi(int(player.get("dao_heart", 0)) / 12, 0, 10)
	if heart_bonus > 0:
		factors.append({"label": "道心不灭", "value": heart_bonus})
	var lived_bonus := clampi(int(player.get("total_events", 0)) / 10, 0, 10)
	if lived_bonus > 0:
		factors.append({"label": "此世留下的故事", "value": lived_bonus})
	var unfinished_bonus := clampi(unfinished_count, 0, 6)
	if unfinished_bonus > 0:
		factors.append({"label": "未竟之约", "value": unfinished_bonus})
	var chance := 0
	for factor in factors:
		chance += int(factor.value)
	chance = clampi(chance, REBIRTH_MIN_CHANCE, REBIRTH_MAX_CHANCE)
	return {"chance": chance, "factors": factors}


static func judge_rebirth(state: Dictionary, roll_override: int = -1) -> Dictionary:
	if not bool(state.get("life_closed", false)):
		return {"ok": false, "code": "life_not_closed"}
	var legacy: Dictionary = state.get("legacy", GameStateScript.create_legacy_state())
	var lives: Array = legacy.get("past_lives", [])
	if lives.is_empty():
		return {"ok": false, "code": "missing_past_life"}
	var generation := int(state.get("generation", 1))
	var previous_value: Variant = legacy.get("last_rebirth_verdict", {})
	if previous_value is Dictionary:
		var previous: Dictionary = previous_value
		if int(previous.get("generation", -1)) == generation and previous.has("triggered"):
			return previous.duplicate(true)
	var chance_data := rebirth_chance(state)
	var roll := clampi(roll_override, 1, 100) if roll_override >= 1 else _rebirth_roll(state)
	var triggered := roll <= int(chance_data.chance)
	var verdict := {
		"ok": true,
		"code": "rebirth_triggered" if triggered else "rebirth_failed",
		"generation": generation,
		"chance": int(chance_data.chance),
		"roll": roll,
		"triggered": triggered,
		"factors": (chance_data.factors as Array).duplicate(true),
	}
	legacy["last_rebirth_verdict"] = verdict.duplicate(true)
	var last_life: Dictionary = lives[-1]
	last_life["rebirth_verdict"] = verdict.duplicate(true)
	lives[lives.size() - 1] = last_life
	legacy["past_lives"] = lives
	state["legacy"] = legacy
	return verdict


static func begin_next_life(state: Dictionary, dao_name: String) -> Dictionary:
	if not bool(state.get("life_closed", false)):
		return {"ok": false, "code": "life_not_closed"}
	var legacy: Dictionary = state.get("legacy", GameStateScript.create_legacy_state())
	var lives: Array = legacy.get("past_lives", [])
	if lives.is_empty():
		return {"ok": false, "code": "missing_past_life"}
	var verdict_value: Variant = legacy.get("last_rebirth_verdict", {})
	var verdict: Dictionary = verdict_value if verdict_value is Dictionary else {}
	if int(verdict.get("generation", -1)) != int(state.get("generation", 1)) or \
			not bool(verdict.get("triggered", false)):
		return {"ok": false, "code": "rebirth_not_triggered"}
	var last_life: Dictionary = lives[-1]
	var inventory_result: Dictionary = ItemSystemScript.apply_reincarnation(state)
	var next_generation := int(state.get("generation", 1)) + 1
	var next_seed := int(state.get("world_seed", 1)) + next_generation * 7919
	var next_name := dao_name.strip_edges().left(32)
	if next_name.is_empty():
		next_name = "第%d世·无名" % next_generation
	var player := GameStateScript.create_player(next_name, next_seed)
	var inherited_echoes: Array = last_life.get("echoes", []).duplicate().slice(0, 3)
	legacy["generation"] = next_generation
	legacy["inherited_echoes"] = inherited_echoes
	var memory_bonus := mini(80, int(last_life.get("realm_index", 0)) * 4 + inherited_echoes.size() * 12)
	player["exp"] = memory_bonus
	player["dao_heart"] = inherited_echoes.size() * 2
	if int(last_life.get("karma", 0)) >= 80:
		player["reputation"] = 8
		player["karma"] = 4
	elif int(last_life.get("karma", 0)) <= -80:
		player["enmity"] = 8
		player["karma"] = -4
	var world: Dictionary = state.get("world", GameStateScript.create_world_state(next_seed))
	var years_between := 7 + (next_seed % 23)
	state["generation"] = next_generation
	state["player"] = player
	state["legacy"] = legacy
	state["world"] = world
	for _year in range(years_between):
		WorldSimulationScript.advance_year(state)
	world = state.world
	var current_era_id := str(state.get("current_era_id", "classical"))
	var era_index := GameStateScript.ERA_IDS.find(current_era_id)
	if era_index < 0:
		era_index = 0
	var next_era_id: String = str(GameStateScript.ERA_IDS[(era_index + 1) % GameStateScript.ERA_IDS.size()])
	var era_transition: Dictionary = WorldSimulationScript.transition_era(state, next_era_id)
	world = state.world
	var history: Array = world.get("history", [])
	history.append("%s陨落%d年后，第%d世在同一片山河中睁眼。" % [
		str(last_life.get("name", "前世")), years_between, next_generation])
	while history.size() > 128:
		history.pop_front()
	world["history"] = history
	state["world"] = world
	state["turn"] = int(state.get("turn", 0)) + 1
	state["story"]["life_event_ids"] = []
	state["story"]["active_arcs"] = {}
	state["story"]["unresolved_threads"] = legacy.get("unresolved_threads", []).duplicate()
	state["story"]["next_arc_event_at"] = 0
	state["story"]["last_arc_id"] = ""
	var combat: Dictionary = state.get("combat", {})
	combat["active"] = false
	combat["current"] = {}
	state["combat"] = combat
	var dungeon: Dictionary = state.get("dungeon", {})
	dungeon["active"] = false
	dungeon["run"] = {}
	dungeon["clues"] = 0
	dungeon["clue_source"] = ""
	state["dungeon"] = dungeon
	var birth_story: Dictionary = StorySystemScript.apply_birth_legacies(state)
	var opening_memories := _memory_opening(last_life, inherited_echoes)
	for note_value in (birth_story.get("notes", []) as Array):
		opening_memories.append("轮回定局入世：%s。" % str(note_value))
	state["recent_memories"] = opening_memories
	state["feedback"] = "旧玉冷了%d年，又在你的新生掌心里醒来。" % years_between
	state["life_closed"] = false
	state["ending_state"] = ""
	return {
		"ok": true, "code": "next_life_started", "generation": next_generation,
		"years_between": years_between, "inherited_echoes": inherited_echoes,
		"inventory_result": inventory_result, "era_transition": era_transition,
	}


static func _rebirth_roll(state: Dictionary) -> int:
	var cursor := int(state.get("rng_cursor", 0))
	var generation := int(state.get("generation", 1))
	var seed_value := (int(state.get("world_seed", 1)) + cursor * 1618033 + generation * 7919 + 0x4f1bbcdc) & 0x7fffffff
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	state["rng_cursor"] = cursor + 1
	return rng.randi_range(1, 100)


static func _build_echoes(player: Dictionary, dao_id: String) -> Array:
	var echoes: Array = []
	var dao_echo: Array = DAO_ECHOES.get(dao_id, ["本我残响", "前世没有完成的自问仍在。"])
	echoes.append({"id": "dao_%s" % dao_id, "type": "dao", "name": dao_echo[0], "description": dao_echo[1], "power": 20 + int(player.get("realm_index", 0)) * 4})
	if int(player.get("realm_index", 0)) >= 5:
		echoes.append({"id": "cultivation_memory", "type": "technique", "name": "前世行功残篇", "description": "经脉还记得上一世反复走过的修炼路线。", "power": 18 + int(player.realm_index) * 3})
	if int(player.get("battles_won", 0)) >= 12:
		echoes.append({"id": "battle_instinct", "type": "knowledge", "name": "死生直觉", "description": "杀机真正落下前，身体会先于记忆做出反应。", "power": int(player.battles_won)})
	if int(player.get("total_events", 0)) >= 20:
		echoes.append({"id": "world_memory", "type": "memory", "name": "山河旧闻", "description": "你记得世界曾经怎样，因此也更容易看出它正在变成什么。", "power": int(player.total_events)})
	return echoes


static func _dominant_path(path: Dictionary) -> String:
	var winner := "insight"
	var score := -1000000
	for path_id in GameStateScript.PATH_DIMENSIONS:
		var value := int(path.get(path_id, 0))
		if value > score:
			score = value
			winner = path_id
	return winner


static func _awakening_stage(resonance: int) -> int:
	if resonance >= 760: return 5
	if resonance >= 520: return 4
	if resonance >= 300: return 3
	if resonance >= 180: return 2
	if resonance >= 80: return 1
	return 0


static func _awakening_aspect(stage: int) -> String:
	return ["未定道痕", "器鸣初醒", "认主残印", "道胚成形", "通天灵胚", "半步通天"][clampi(stage, 0, 5)]


static func _memory_opening(last_life: Dictionary, echoes: Array) -> Array[String]:
	var memories: Array[String] = []
	memories.append("你梦见%s在%s止步，醒来时不知道那是不是自己。" % [
		str(last_life.get("name", "某位前世")), str(last_life.get("realm", "凡尘"))])
	for echo in echoes:
		memories.append("旧玉遗响：%s。" % str((echo as Dictionary).get("name", "无名道痕")))
	return memories
