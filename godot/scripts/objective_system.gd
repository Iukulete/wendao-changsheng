class_name ObjectiveSystem
extends RefCounted

## Short, player-chosen goals that make the main actions form a readable loop.
## The state is intentionally data-only so old saves can adopt it in place.

const OBJECTIVE_VERSION := 1
const DEADLINE_TURNS := 8
const HISTORY_LIMIT := 32

const OBJECTIVE_IDS := ["cultivation", "world", "battle"]

const DEFINITIONS := {
	"cultivation": {
		"name": "凝神筑道",
		"tagline": "以不同运功法推进修为，并叩问一次瓶颈。",
		"target": 9,
		"recommendation": "修炼与破境推进最快；历练也能带来少量印证。",
		"contributions": {
			"meditate_steady": 3,
			"meditate_rush": 4,
			"meditate_insight": 3,
			"breakthrough_success": 5,
			"breakthrough_failure": 2,
			"adventure": 1,
			"story_event": 1,
		},
		"reward": {"exp": 90, "dao_heart": 2, "pills": 1},
	},
	"world": {
		"name": "入世问因",
		"tagline": "介入山河中的抉择，让一段长卷真正向前。",
		"target": 9,
		"recommendation": "历练是主路；连续剧情与天机事件推进更多。",
		"contributions": {
			"adventure": 3,
			"story_event": 4,
			"local_ai_event": 3,
			"combat_victory": 1,
			"dungeon_completed": 2,
		},
		"reward": {"spirit_stones": 14, "reputation": 5, "karma": 3},
	},
	"battle": {
		"name": "踏劫磨锋",
		"tagline": "以可控风险锻炼实战，在胜负中完成证道。",
		"target": 9,
		"recommendation": "正面胜战推进最快；完整走出秘境可一次取得六印。",
		"contributions": {
			"combat_victory": 4,
			"dungeon_completed": 6,
			"dungeon_defeat": 1,
			"adventure": 1,
		},
		"reward": {"exp": 65, "spirit_stones": 10, "pills": 1, "dao_heart": 1},
	},
}


static func normalize(state: Dictionary) -> Dictionary:
	var source: Variant = state.get("objective", {})
	var objective: Dictionary = source.duplicate(true) if source is Dictionary else {}
	var generation := clampi(int(state.get("generation", 1)), 1, 100000)
	var previous_generation := int(objective.get("generation", generation))
	var completed_total := clampi(int(objective.get("completed_total", 0)), 0, 1000000)
	var missed_total := clampi(int(objective.get("missed_total", 0)), 0, 1000000)
	var history := _bounded_history(objective.get("history", []))
	if previous_generation != generation:
		objective = _fresh_state(generation)
		objective["completed_total"] = completed_total
		objective["missed_total"] = missed_total
		objective["history"] = history

	objective["version"] = OBJECTIVE_VERSION
	objective["generation"] = generation
	objective["cycle"] = clampi(int(objective.get("cycle", 1)), 1, 1000000)
	var active_id := str(objective.get("active_id", ""))
	if not OBJECTIVE_IDS.has(active_id):
		active_id = ""
	objective["active_id"] = active_id
	objective["progress"] = clampi(int(objective.get("progress", 0)), 0, 1000000)
	objective["selected_turn"] = clampi(int(objective.get("selected_turn", 0)), 0, 0x7fffffff)
	objective["deadline_turn"] = clampi(int(objective.get("deadline_turn", 0)), 0, 0x7fffffff)
	objective["streak"] = clampi(int(objective.get("streak", 0)), 0, 1000000)
	objective["completed_total"] = completed_total
	objective["missed_total"] = missed_total
	objective["last_result"] = str(objective.get("last_result", "")).left(32)
	objective["history"] = history
	if active_id.is_empty():
		objective["progress"] = 0
		objective["selected_turn"] = 0
		objective["deadline_turn"] = 0
	else:
		objective["progress"] = mini(int(objective.progress), int(DEFINITIONS[active_id].target))
		if int(objective.deadline_turn) <= int(objective.selected_turn):
			objective["deadline_turn"] = mini(0x7fffffff, int(objective.selected_turn) + DEADLINE_TURNS)
	state["objective"] = objective
	return objective


static func definition(objective_id: String) -> Dictionary:
	if not DEFINITIONS.has(objective_id):
		return {}
	return (DEFINITIONS[objective_id] as Dictionary).duplicate(true)


static func choose(state: Dictionary, objective_id: String) -> Dictionary:
	var objective := normalize(state)
	if not OBJECTIVE_IDS.has(objective_id):
		return {"ok": false, "code": "invalid_objective"}
	if not str(objective.active_id).is_empty():
		return {"ok": false, "code": "objective_active", "objective": objective.duplicate(true)}
	var turn := clampi(int(state.get("turn", 0)), 0, 0x7fffffff)
	objective["active_id"] = objective_id
	objective["progress"] = 0
	objective["selected_turn"] = turn
	objective["deadline_turn"] = mini(0x7fffffff, turn + DEADLINE_TURNS)
	objective["last_result"] = "selected"
	state["objective"] = objective
	var selected_definition: Dictionary = DEFINITIONS[objective_id]
	return {
		"ok": true,
		"code": "objective_selected",
		"objective": objective.duplicate(true),
		"message": "你立下阶段命途【%s】。八次年轮推进之内，所行之事都会留下可见道印。" % str(selected_definition.name),
	}


static func record_action(state: Dictionary, action_id: String) -> Dictionary:
	var objective := normalize(state)
	var objective_id := str(objective.active_id)
	if objective_id.is_empty():
		return {"ok": true, "code": "no_active_objective", "points": 0, "message": ""}
	var objective_definition: Dictionary = DEFINITIONS[objective_id]
	var contributions: Dictionary = objective_definition.contributions
	var points := maxi(0, int(contributions.get(action_id, 0)))
	objective["progress"] = mini(int(objective_definition.target), int(objective.progress) + points)
	var current_turn := clampi(int(state.get("turn", 0)), 0, 0x7fffffff)
	if int(objective.progress) >= int(objective_definition.target):
		return _complete(state, objective, objective_id, action_id, points)
	if current_turn >= int(objective.deadline_turn):
		return _miss(state, objective, objective_id, action_id, points)
	state["objective"] = objective
	var remaining := maxi(0, int(objective.deadline_turn) - current_turn)
	var message := ""
	if points > 0:
		message = "【%s】道印 +%d，当前 %d/%d；还可推进 %d 次年轮。" % [
			str(objective_definition.name), points, int(objective.progress),
			int(objective_definition.target), remaining]
	return {
		"ok": true,
		"code": "objective_progressed" if points > 0 else "objective_unchanged",
		"points": points,
		"progress": int(objective.progress),
		"target": int(objective_definition.target),
		"remaining_turns": remaining,
		"message": message,
	}


static func summary(state: Dictionary) -> Dictionary:
	var objective := normalize(state)
	var objective_id := str(objective.active_id)
	if objective_id.is_empty():
		return {
			"active": false,
			"cycle": int(objective.cycle),
			"streak": int(objective.streak),
			"completed_total": int(objective.completed_total),
			"last_result": str(objective.last_result),
		}
	var objective_definition: Dictionary = DEFINITIONS[objective_id]
	return {
		"active": true,
		"id": objective_id,
		"name": str(objective_definition.name),
		"tagline": str(objective_definition.tagline),
		"recommendation": str(objective_definition.recommendation),
		"progress": int(objective.progress),
		"target": int(objective_definition.target),
		"remaining_turns": maxi(0, int(objective.deadline_turn) - int(state.get("turn", 0))),
		"streak": int(objective.streak),
		"reward_text": reward_text(objective_id, state),
	}


static func reward_text(objective_id: String, state: Dictionary) -> String:
	if not DEFINITIONS.has(objective_id):
		return ""
	var reward: Dictionary = (DEFINITIONS[objective_id] as Dictionary).reward
	var realm_index := clampi(int((state.get("player", {}) as Dictionary).get("realm_index", 0)), 0, 20)
	var parts: Array[String] = []
	var names := {
		"exp": "修为", "spirit_stones": "灵石", "pills": "丹药",
		"dao_heart": "道心", "reputation": "名望", "karma": "因果",
	}
	for field in ["exp", "spirit_stones", "pills", "dao_heart", "reputation", "karma"]:
		if not reward.has(field):
			continue
		var amount := int(reward[field])
		if field == "exp":
			amount += realm_index * 18
		parts.append("%s +%d" % [str(names[field]), amount])
	return "  ·  ".join(parts)


static func _complete(state: Dictionary, objective: Dictionary, objective_id: String,
		action_id: String, points: int) -> Dictionary:
	var objective_definition: Dictionary = DEFINITIONS[objective_id]
	var applied_reward := _apply_reward(state, objective_definition.reward)
	objective["completed_total"] = int(objective.completed_total) + 1
	objective["streak"] = int(objective.streak) + 1
	objective["cycle"] = int(objective.cycle) + 1
	objective["last_result"] = "completed"
	var record := {
		"result": "completed", "objective_id": objective_id,
		"generation": int(state.get("generation", 1)), "turn": int(state.get("turn", 0)),
		"action_id": action_id, "reward": applied_reward.duplicate(true),
	}
	var history: Array = objective.history
	history.append(record)
	objective["history"] = _bounded_history(history)
	_clear_active(objective)
	state["objective"] = objective
	return {
		"ok": true,
		"code": "objective_completed",
		"completed": true,
		"points": points,
		"objective_id": objective_id,
		"reward": applied_reward,
		"message": "【%s】圆满，道印化为实质回报：%s。新的阶段命途已经可以择定。" % [
			str(objective_definition.name), _reward_dictionary_text(applied_reward)],
	}


static func _miss(state: Dictionary, objective: Dictionary, objective_id: String,
		action_id: String, points: int) -> Dictionary:
	var objective_definition: Dictionary = DEFINITIONS[objective_id]
	objective["missed_total"] = int(objective.missed_total) + 1
	objective["streak"] = 0
	objective["cycle"] = int(objective.cycle) + 1
	objective["last_result"] = "missed"
	var history: Array = objective.history
	history.append({
		"result": "missed", "objective_id": objective_id,
		"generation": int(state.get("generation", 1)), "turn": int(state.get("turn", 0)),
		"action_id": action_id, "progress": int(objective.progress),
	})
	objective["history"] = _bounded_history(history)
	_clear_active(objective)
	state["objective"] = objective
	return {
		"ok": true,
		"code": "objective_missed",
		"missed": true,
		"points": points,
		"objective_id": objective_id,
		"message": "【%s】未能在期限内圆满。没有数值惩罚，但连续践行归零；你可以立即改立新的命途。" % str(objective_definition.name),
	}


static func _apply_reward(state: Dictionary, reward: Dictionary) -> Dictionary:
	var player: Dictionary = state.get("player", {})
	var realm_index := clampi(int(player.get("realm_index", 0)), 0, 20)
	var applied := {}
	for field in reward.keys():
		if not player.has(field):
			continue
		var amount := int(reward[field])
		if str(field) == "exp":
			amount += realm_index * 18
		player[field] = int(player[field]) + amount
		applied[field] = amount
	player["exp"] = maxi(0, int(player.get("exp", 0)))
	player["spirit_stones"] = maxi(0, int(player.get("spirit_stones", 0)))
	player["pills"] = maxi(0, int(player.get("pills", 0)))
	state["player"] = player
	return applied


static func _reward_dictionary_text(reward: Dictionary) -> String:
	var names := {
		"exp": "修为", "spirit_stones": "灵石", "pills": "丹药",
		"dao_heart": "道心", "reputation": "名望", "karma": "因果",
	}
	var parts: Array[String] = []
	for field in ["exp", "spirit_stones", "pills", "dao_heart", "reputation", "karma"]:
		if reward.has(field):
			parts.append("%s +%d" % [str(names[field]), int(reward[field])])
	return "、".join(parts)


static func _clear_active(objective: Dictionary) -> void:
	objective["active_id"] = ""
	objective["progress"] = 0
	objective["selected_turn"] = 0
	objective["deadline_turn"] = 0


static func _fresh_state(generation: int) -> Dictionary:
	return {
		"version": OBJECTIVE_VERSION,
		"generation": generation,
		"cycle": 1,
		"active_id": "",
		"progress": 0,
		"selected_turn": 0,
		"deadline_turn": 0,
		"streak": 0,
		"completed_total": 0,
		"missed_total": 0,
		"last_result": "",
		"history": [],
	}


static func _bounded_history(value: Variant) -> Array:
	if not value is Array:
		return []
	var history: Array = (value as Array).duplicate(true)
	if history.size() > HISTORY_LIMIT:
		history = history.slice(history.size() - HISTORY_LIMIT)
	return history
