class_name IslandSurvivalSystem
extends RefCounted

## Compact, deterministic island expedition loop kept inside the main save.

const ACTIONS_PER_DAY := 3
const RESOURCE_NAMES := {
	"wood": "浮木", "stone": "玄礁石", "herb": "灵草",
	"ore": "灵铁", "crystal": "潮晶", "food": "口粮",
}

const NODE_DEFINITIONS := [
	{"id": "camp", "name": "木筏锚地", "x": 0.48, "y": 0.66, "kind": "camp", "danger": 0, "neighbors": ["beach", "grove", "shelter"]},
	{"id": "beach", "name": "漂木浅滩", "x": 0.19, "y": 0.52, "kind": "beach", "danger": 0, "neighbors": ["camp", "reef"]},
	{"id": "grove", "name": "雾隐灵林", "x": 0.35, "y": 0.25, "kind": "grove", "danger": 1, "neighbors": ["camp", "shelter", "cave"]},
	{"id": "shelter", "name": "坍塌避难所", "x": 0.64, "y": 0.32, "kind": "shelter", "danger": 1, "neighbors": ["camp", "grove", "ruins", "beacon"]},
	{"id": "ruins", "name": "沉没工坊", "x": 0.77, "y": 0.62, "kind": "ruins", "danger": 2, "neighbors": ["shelter", "beacon", "reef"]},
	{"id": "cave", "name": "回声石窟", "x": 0.78, "y": 0.20, "kind": "cave", "danger": 3, "neighbors": ["grove", "reef"]},
	{"id": "reef", "name": "断潮礁脊", "x": 0.22, "y": 0.80, "kind": "reef", "danger": 2, "neighbors": ["beach", "ruins", "cave"]},
	{"id": "beacon", "name": "孤灯信标", "x": 0.91, "y": 0.43, "kind": "beacon", "danger": 2, "neighbors": ["shelter", "ruins", "old_port"]},
	{"id": "old_port", "name": "雾外旧港", "x": 0.94, "y": 0.72, "kind": "port", "danger": 4, "neighbors": ["beacon", "ruins", "sky_wreck"]},
	{"id": "sky_wreck", "name": "坠星仙舟", "x": 0.57, "y": 0.10, "kind": "wreck", "danger": 5, "neighbors": ["old_port", "cave"]},
]


static func new_run(seed_value: int = 1) -> Dictionary:
	var nodes: Array[Dictionary] = []
	for definition_value in NODE_DEFINITIONS:
		var definition: Dictionary = definition_value
		nodes.append({
			"id": str(definition.id), "name": str(definition.name),
			"x": float(definition.x), "y": float(definition.y),
			"kind": str(definition.kind), "neighbors": definition.neighbors.duplicate(),
			"revealed": true,
			"explored": str(definition.id) == "camp", "gathered_day": 0,
		})
	return {
		"version": 2, "seed": maxi(1, seed_value), "active": true, "in_mode": true,
		"day": 1, "actions_left": ACTIONS_PER_DAY, "tide": 18, "vitality": 100,
		"shelter_level": 1, "survivors": 0, "survivor_rescued": false,
		"ark": {
			"name": "无名木筏", "level": 1, "durability": 62,
			"rooms": ["deck"], "residents": [], "mood": 68,
		},
		"beacon_repaired": false, "escaped": false, "failed": false,
		"selected_node_id": "beach",
		"resources": {"wood": 1, "stone": 1, "herb": 0, "ore": 0, "crystal": 0, "food": 2},
		"nodes": nodes,
		"log": ["你在灵潮时代醒来，手边只有几块木板。海雾遮住的每个方向都能去，只是有些地方看起来不欢迎弱者。"],
	}


static func normalize(run_value: Dictionary) -> Dictionary:
	if run_value.is_empty():
		return new_run()
	var run := run_value.duplicate(true)
	var defaults := new_run(int(run.get("seed", 1)))
	for key in defaults:
		if not run.has(key):
			run[key] = defaults[key]
	var ark: Dictionary = run.get("ark", defaults.ark).duplicate(true)
	ark["level"] = clampi(int(ark.get("level", run.get("shelter_level", 1))), 1, 3)
	ark["durability"] = clampi(int(ark.get("durability", 62)), 0, 100)
	ark["rooms"] = ark.get("rooms", ["deck"]).duplicate()
	ark["residents"] = ark.get("residents", []).duplicate(true)
	ark["mood"] = clampi(int(ark.get("mood", 68)), 0, 100)
	run["ark"] = ark
	var resources: Dictionary = run.get("resources", {})
	for key in RESOURCE_NAMES:
		resources[key] = maxi(0, int(resources.get(key, 0)))
	run["resources"] = resources
	run["day"] = clampi(int(run.get("day", 1)), 1, 99)
	run["actions_left"] = clampi(int(run.get("actions_left", ACTIONS_PER_DAY)), 0, ACTIONS_PER_DAY)
	run["tide"] = clampi(int(run.get("tide", 0)), 0, 100)
	run["vitality"] = clampi(int(run.get("vitality", 100)), 0, 100)
	run["shelter_level"] = clampi(int(run.get("shelter_level", 1)), 1, 3)
	return run


static func nodes(run_value: Dictionary) -> Array:
	return normalize(run_value).get("nodes", [])


static func node_by_id(run: Dictionary, node_id: String) -> Dictionary:
	for node_value in run.get("nodes", []):
		var node: Dictionary = node_value
		if str(node.get("id", "")) == node_id:
			return node
	return {}


static func perform(run_value: Dictionary, action_id: String, node_id: String = "") -> Dictionary:
	var run := normalize(run_value)
	if not bool(run.active) or bool(run.escaped) or bool(run.failed):
		return {"ok": false, "run": run, "message": "这段孤岛旅程已经结束。"}
	if action_id not in ["end_day", "share_meal", "talk"] and int(run.actions_left) <= 0:
		return {"ok": false, "run": run, "message": "今日体力已尽，先扎营休整。"}
	var resources: Dictionary = run.resources
	var message := ""
	var node := node_by_id(run, node_id)

	match action_id:
		"explore":
			if node.is_empty() or not bool(node.get("revealed", false)):
					return _failure(run, "航图上还没有这片区域的坐标。")
			if bool(node.get("explored", false)):
				return _failure(run, "这里已经搜查过了，可以采集周边材料。")
			node["explored"] = true
			node["gathered_day"] = int(run.day)
			_apply_first_discovery(run, node, resources)
			message = _discovery_message(node, run)
			_consume_action(run)
		"gather":
			if node.is_empty() or not bool(node.get("explored", false)):
				return _failure(run, "先探索并确认这个地点，再采集材料。")
			if str(node.get("kind", "")) in ["camp", "beacon"]:
				return _failure(run, "这里没有可采集的自然材料。")
			if int(node.get("gathered_day", 0)) == int(run.day):
				return _failure(run, "今天已搜集过这里，明日潮汐退去后资源会重新显露。")
			node["gathered_day"] = int(run.day)
			var gains := _gather_yield(str(node.kind))
			_apply_resources(resources, gains)
			message = "搜集完成：%s。" % _format_resources(gains)
			_consume_action(run)
		"rescue":
			if node_id != "shelter" or not bool(node.get("explored", false)):
				return _failure(run, "先到避难所看看，或许有人正等着一盏灯。")
			if bool(run.survivor_rescued):
				return _failure(run, "沈砚已经住进仙舟了。")
			if int(resources.get("herb", 0)) < 1:
				return _failure(run, "伤者需要灵草稳定伤势；附近区域的灵林传来草木气息。")
			resources["herb"] = int(resources.herb) - 1
			run["survivor_rescued"] = true
			run["survivors"] = 1
			var rescue_ark: Dictionary = run.ark
			var rescued_residents: Array = rescue_ark.get("residents", [])
			rescued_residents.append({"id": "array_maker", "name": "沈砚", "role": "阵师", "mood": 58, "bond": 0, "last_talk_day": 0})
			rescue_ark["residents"] = rescued_residents
			rescue_ark["mood"] = mini(100, int(rescue_ark.get("mood", 68)) + 8)
			run["ark"] = rescue_ark
			message = "你用灵草为沈砚止血，把她接上木筏。她看着漏风的棚顶说：‘我来修阵，你先把这地方搭成一个家。’"
			_consume_action(run)
		"upgrade":
			var level := int(run.shelter_level)
			var cost: Dictionary = {"wood": 3, "stone": 2} if level == 1 else {"wood": 5, "stone": 4, "ore": 1}
			if level >= 3:
				return _failure(run, "舟身已经加固到当前阶段的上限。")
			if not _can_pay(resources, cost):
				return _failure(run, "材料不足：加固需要%s。" % _format_resources(cost))
			_pay(resources, cost)
			run["shelter_level"] = level + 1
			var upgrade_ark: Dictionary = run.ark
			upgrade_ark["level"] = int(run.shelter_level)
			upgrade_ark["durability"] = mini(100, int(upgrade_ark.get("durability", 62)) + 24)
			if int(run.shelter_level) >= 2 and not upgrade_ark.rooms.has("cabin"):
				upgrade_ark.rooms.append("cabin")
			if int(run.shelter_level) >= 3 and not upgrade_ark.rooms.has("galley"):
				upgrade_ark.rooms.append("galley")
			upgrade_ark["name"] = "逐潮仙舟" if int(run.shelter_level) >= 3 else "加固木筏"
			run["ark"] = upgrade_ark
			message = "舟身升至%d级。你把新木料一块块钉上船舷，沈砚压住阵脚；夜里终于不再漏风。" % int(run.shelter_level)
			_consume_action(run)
		"share_meal":
			if int(resources.get("food", 0)) < 1:
				return _failure(run, "灶台还没开火：先去岛上找些吃的。")
			resources["food"] = int(resources.food) - 1
			run["vitality"] = mini(100, int(run.vitality) + 14)
			var meal_ark: Dictionary = run.ark
			meal_ark["mood"] = mini(100, int(meal_ark.get("mood", 68)) + 7)
			var meal_residents: Array = meal_ark.get("residents", [])
			for index in range(meal_residents.size()):
				var resident: Dictionary = meal_residents[index]
				resident["mood"] = mini(100, int(resident.get("mood", 50)) + 9)
				resident["bond"] = mini(100, int(resident.get("bond", 0)) + 2)
				meal_residents[index] = resident
			meal_ark["residents"] = meal_residents
			run["ark"] = meal_ark
			message = "你把锅里的热粥分给舟上每个人。沈砚捧着碗，第一次露出笑意。体力恢复，舟上心气也更稳了。"
		"talk":
			var talk_ark: Dictionary = run.ark
			var talk_residents: Array = talk_ark.get("residents", [])
			if talk_residents.is_empty():
				return _failure(run, "舱里还没有同伴。去废墟和避难所看看，或许有人正等着一盏灯。")
			var resident: Dictionary = talk_residents[0]
			if int(resident.get("last_talk_day", 0)) == int(run.day):
				return _failure(run, "你们今日已经聊过了。她说晚些时候还想再听你讲讲过去。")
			resident["last_talk_day"] = int(run.day)
			resident["mood"] = mini(100, int(resident.get("mood", 50)) + 5)
			resident["bond"] = mini(100, int(resident.get("bond", 0)) + 4)
			talk_residents[0] = resident
			talk_ark["residents"] = talk_residents
			talk_ark["mood"] = mini(100, int(talk_ark.get("mood", 68)) + 3)
			run["ark"] = talk_ark
			message = "沈砚告诉你，她曾替一座浮空仙城画过万家灯火图。‘那时我不懂，为什么有人要把一盏灯画得那么认真。现在懂了。’"
		"repair_beacon":
			if node_id != "beacon" or not bool(node.get("explored", false)):
				return _failure(run, "先找到孤灯信标，才能开始修复。")
			if bool(run.beacon_repaired):
				return _failure(run, "信标已经重新点亮，远方的援光正穿过云层。")
			if not bool(run.survivor_rescued):
				return _failure(run, "需要救出避难所里的阵师，才能读懂信标阵纹。")
			var beacon_cost := {"wood": 4, "stone": 3, "ore": 2, "crystal": 1}
			if not _can_pay(resources, beacon_cost):
				return _failure(run, "信标缺少材料：%s。" % _format_resources(beacon_cost))
			_pay(resources, beacon_cost)
			run["beacon_repaired"] = true
			message = "孤灯信标重新亮起。远方回传了灵阵坐标：海雾之外还有广阔的旧大陆。沈砚把新航线刻在甲板上，仙舟从此不必只绕着这座岛打转。"
		"end_day":
			message = _end_day(run, resources)
		_:
			return _failure(run, "未知的孤岛行动。")

	_append_log(run, message)
	run["resources"] = resources
	return {"ok": true, "run": run, "message": message}


static func _failure(run: Dictionary, message: String) -> Dictionary:
	return {"ok": false, "run": run, "message": message}


static func _consume_action(run: Dictionary) -> void:
	run["actions_left"] = maxi(0, int(run.actions_left) - 1)


static func _has_explored_neighbor(run: Dictionary, node: Dictionary) -> bool:
	for neighbor_id in node.get("neighbors", []):
		var neighbor := node_by_id(run, str(neighbor_id))
		if not neighbor.is_empty() and bool(neighbor.get("explored", false)):
			return true
	return false


static func _apply_first_discovery(run: Dictionary, node: Dictionary, resources: Dictionary) -> void:
	match str(node.get("kind", "")):
		"beach": _apply_resources(resources, {"wood": 3, "food": 2})
		"grove": _apply_resources(resources, {"herb": 2, "food": 1})
		"shelter": _apply_resources(resources, {"stone": 2, "wood": 1})
		"ruins": _apply_resources(resources, {"stone": 2, "ore": 1})
		"cave":
			_apply_resources(resources, {"ore": 2, "crystal": 1})
			run["vitality"] = maxi(0, int(run.vitality) - 14)
		"reef": _apply_resources(resources, {"wood": 1, "stone": 1, "food": 1})
		"port": _apply_resources(resources, {"stone": 2, "ore": 2, "food": 1})
		"wreck":
			_apply_resources(resources, {"ore": 2, "crystal": 2})
			run["vitality"] = maxi(0, int(run.vitality) - 24)


static func _gather_yield(kind: String) -> Dictionary:
	match kind:
		"beach": return {"wood": 1, "food": 1}
		"grove": return {"herb": 1, "food": 1}
		"shelter": return {"stone": 1}
		"ruins": return {"stone": 1, "ore": 1}
		"cave": return {"ore": 1}
		"reef": return {"wood": 1, "stone": 1}
		"port": return {"stone": 1, "ore": 1}
		"wreck": return {"ore": 1, "crystal": 1}
	return {}


static func _discovery_message(node: Dictionary, run: Dictionary) -> String:
	var name := str(node.get("name", "未知区域"))
	match str(node.get("kind", "")):
		"beach": return "抵达%s，潮线留下了可用浮木和口粮。" % name
		"grove": return "穿过%s，你采到灵草，也看见了更深处的古阵残光。" % name
		"shelter": return "你扒开%s的断墙，里面传出微弱的敲击声。" % name
		"ruins": return "搜查%s时发现了旧工坊的矿料仓，还有一枚指向信标的阵纹。" % name
		"cave": return "石窟深处藏着潮晶和灵铁，但回声引来了碎岩。你受了些轻伤。"
		"reef": return "越过%s，你找到了通向外海的安全潮路。" % name
		"beacon": return "你终于抵达%s。阵纹虽暗，结构仍然完整。" % name
		"port": return "雾外旧港已经出现在航图上。妖影在远处巡行，港湾里或许有能改变舟身的旧构件。"
		"wreck": return "你登上坠星仙舟。阵风像刀一样刮过船壳；里面有什么，由你自己承担风险去看。"
	return "你探索了%s。" % name


static func _end_day(run: Dictionary, resources: Dictionary) -> String:
	if int(resources.get("food", 0)) > 0:
		resources["food"] = int(resources.food) - 1
		run["vitality"] = mini(100, int(run.vitality) + 4)
	else:
		run["vitality"] = maxi(0, int(run.vitality) - 14)
	var next_day := int(run.day) + 1
	run["day"] = next_day
	run["actions_left"] = ACTIONS_PER_DAY
	run["tide"] = mini(100, int(run.tide) + 11)
	var message := "第%d日开始。你补充了体力，灵潮也比昨日更近。" % next_day
	var ark: Dictionary = run.get("ark", {})
	if int(run.tide) >= 60:
		var surge_damage := 8 if int(run.shelter_level) == 1 else (3 if int(run.shelter_level) == 2 else 0)
		if surge_damage > 0:
			run["vitality"] = maxi(0, int(run.vitality) - surge_damage)
			ark["durability"] = maxi(0, int(ark.get("durability", 62)) - surge_damage * 2)
			message += " 灵潮漫过外舷，护舟阵替你挡下冲击，舟身耐久-%d。" % (surge_damage * 2)
	if next_day % 3 == 0:
		var damage := 16 if int(run.shelter_level) == 1 else (8 if int(run.shelter_level) == 2 else 2)
		run["tide"] = mini(100, int(run.tide) + 12)
		run["vitality"] = maxi(0, int(run.vitality) - damage)
		ark["durability"] = maxi(0, int(ark.get("durability", 62)) - (damage + 1))
		message += " 风暴拍上岛脊，舟身耐久-%d。" % (damage + 1)
		if int(ark.get("durability", 0)) <= 0:
			run["vitality"] = maxi(0, int(run.vitality) - 12)
			message += " 船板裂开，夜风灌进舱里。"
	ark["mood"] = maxi(0, int(ark.get("mood", 68)) - (4 if int(ark.get("durability", 0)) < 30 else 1))
	var residents: Array = ark.get("residents", [])
	for index in range(residents.size()):
		var resident: Dictionary = residents[index]
		if int(ark.get("durability", 0)) < 30:
			resident["mood"] = maxi(0, int(resident.get("mood", 50)) - 4)
		else:
			resident["mood"] = mini(100, int(resident.get("mood", 50)) + 1)
		residents[index] = resident
	ark["residents"] = residents
	run["ark"] = ark
	if int(run.vitality) <= 0:
		run["failed"] = true
		message = "灵潮与饥饿压垮了你。木筏还在，舟上那盏灯却熄了。"
	return message


static func _apply_resources(resources: Dictionary, gains: Dictionary) -> void:
	for key in gains:
		resources[key] = maxi(0, int(resources.get(key, 0)) + int(gains[key]))


static func _can_pay(resources: Dictionary, cost: Dictionary) -> bool:
	for key in cost:
		if int(resources.get(key, 0)) < int(cost[key]):
			return false
	return true


static func _pay(resources: Dictionary, cost: Dictionary) -> void:
	for key in cost:
		resources[key] = int(resources.get(key, 0)) - int(cost[key])


static func _format_resources(values: Dictionary) -> String:
	var parts: Array[String] = []
	for key in values:
		var amount := int(values[key])
		if amount > 0:
			parts.append("%s×%d" % [str(RESOURCE_NAMES.get(str(key), key)), amount])
	return "、".join(parts) if not parts.is_empty() else "无"


static func resource_summary(run: Dictionary) -> String:
	var resources: Dictionary = normalize(run).get("resources", {})
	var parts: Array[String] = []
	for key in RESOURCE_NAMES:
		parts.append("%s %d" % [str(RESOURCE_NAMES[key]), int(resources.get(key, 0))])
	return "　".join(parts)


static func _append_log(run: Dictionary, message: String) -> void:
	var log: Array = run.get("log", [])
	log.append(message)
	while log.size() > 7:
		log.pop_front()
	run["log"] = log
