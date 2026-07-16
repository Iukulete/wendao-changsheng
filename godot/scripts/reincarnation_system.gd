class_name ReincarnationSystem
extends RefCounted

const GameStateScript = preload("res://scripts/game_state.gd")
const WorldSimulationScript = preload("res://scripts/world_simulation.gd")
const ItemSystemScript = preload("res://scripts/item_system.gd")
const StorySystemScript = preload("res://scripts/story_system.gd")

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


static func close_life(state: Dictionary, cause: String) -> Dictionary:
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
		"age_at_death": int(player.get("age", 16)),
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
	state["feedback"] = "%s享年%d岁，此世道痕已被黑白旧玉收存。" % [player.name, player.age]
	return {"ok": true, "code": "life_closed", "past_life": past_life, "resonance_gain": resonance_gain}


static func begin_next_life(state: Dictionary, dao_name: String) -> Dictionary:
	if not bool(state.get("life_closed", false)):
		return {"ok": false, "code": "life_not_closed"}
	var legacy: Dictionary = state.get("legacy", GameStateScript.create_legacy_state())
	var lives: Array = legacy.get("past_lives", [])
	if lives.is_empty():
		return {"ok": false, "code": "missing_past_life"}
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
	var combat: Dictionary = state.get("combat", {})
	combat["active"] = false
	combat["current"] = {}
	state["combat"] = combat
	var dungeon: Dictionary = state.get("dungeon", {})
	dungeon["active"] = false
	dungeon["run"] = {}
	state["dungeon"] = dungeon
	var birth_story: Dictionary = StorySystemScript.apply_birth_legacies(state)
	var opening_memories := _memory_opening(last_life, inherited_echoes)
	for note_value in (birth_story.get("notes", []) as Array):
		opening_memories.append("轮回定局入世：%s。" % str(note_value))
	state["recent_memories"] = opening_memories
	state["feedback"] = "旧玉冷了%d年，又在你的新生掌心里醒来。" % years_between
	state["life_closed"] = false
	return {
		"ok": true, "code": "next_life_started", "generation": next_generation,
		"years_between": years_between, "inherited_echoes": inherited_echoes,
		"inventory_result": inventory_result,
	}


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
