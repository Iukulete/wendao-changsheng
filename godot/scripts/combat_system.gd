class_name CombatSystem
extends RefCounted

const ItemSystemScript = preload("res://scripts/item_system.gd")

const MAX_TURNS := 48
const MAX_LOG := 40
const MAX_HISTORY := 64
const SPELL_COST := 12

const ENEMY_POOLS := {
	"classical": [
		{"id": "classical_razor_wolf", "name": "断刃苍狼", "hp": 88, "attack": 18, "defense": 6,
			"intents": ["strike", "bleed", "guard"], "material": "spirit_herb"},
		{"id": "classical_oath_breaker", "name": "毁誓剑客", "hp": 105, "attack": 21, "defense": 9,
			"intents": ["guard", "heavy", "strike"], "material": "black_iron"},
	],
	"steam": [
		{"id": "steam_furnace_hound", "name": "赤炉机犬", "hp": 118, "attack": 24, "defense": 12,
			"intents": ["strike", "heavy", "guard"], "material": "black_iron"},
		{"id": "steam_debt_collector", "name": "灵轨债吏", "hp": 102, "attack": 26, "defense": 8,
			"intents": ["weaken", "strike", "heavy"], "material": "star_sand"},
	],
	"star_network": [
		{"id": "star_echo_hunter", "name": "星网猎忆者", "hp": 142, "attack": 30, "defense": 13,
			"intents": ["weaken", "bleed", "heavy"], "material": "star_sand"},
		{"id": "star_void_daemon", "name": "虚航道魔", "hp": 155, "attack": 32, "defense": 15,
			"intents": ["guard", "heavy", "weaken"], "material": "void_crystal"},
	],
	"wasteland": [
		{"id": "wasteland_rain_beast", "name": "黑雨畸兽", "hp": 132, "attack": 29, "defense": 10,
			"intents": ["bleed", "strike", "heavy"], "material": "spirit_herb"},
		{"id": "wasteland_relic_raider", "name": "拾遗劫修", "hp": 148, "attack": 31, "defense": 14,
			"intents": ["guard", "weaken", "heavy"], "material": "void_crystal"},
	],
	"final_age": [
		{"id": "final_age_breath_taxer", "name": "夺息使", "hp": 112, "attack": 34, "defense": 9,
			"intents": ["weaken", "heavy", "strike"], "material": "fate_thread"},
		{"id": "final_age_silent_cultivator", "name": "寂法修士", "hp": 126, "attack": 32, "defense": 16,
			"intents": ["guard", "bleed", "heavy"], "material": "void_crystal"},
	],
	"immortal_dynasty": [
		{"id": "immortal_sky_enforcer", "name": "巡天仙吏", "hp": 178, "attack": 38, "defense": 18,
			"intents": ["guard", "heavy", "weaken"], "material": "fate_thread"},
		{"id": "immortal_unchained_duelist", "name": "不系仙客", "hp": 165, "attack": 42, "defense": 14,
			"intents": ["strike", "bleed", "heavy"], "material": "void_crystal"},
	],
}

const INTENT_NAMES := {
	"strike": "迅击", "heavy": "蓄势重击", "guard": "结印护身",
	"bleed": "撕裂经脉", "weaken": "蚀心咒",
}
const INTENT_DESCRIPTIONS := {
	"strike": "直接攻势，伤害存在小幅波动。",
	"heavy": "高威胁重击，护盾能抵消主要伤害。",
	"guard": "本回合不攻击，并结成护身罡气。",
	"bleed": "攻击后留下流血，后续回合持续损伤气血。",
	"weaken": "攻击并施加虚弱，暂时降低你的伤害。",
}


static func normalize(state: Dictionary) -> Dictionary:
	var value: Variant = state.get("combat", {})
	var combat: Dictionary = value.duplicate(true) if value is Dictionary else {}
	combat["active"] = bool(combat.get("active", false))
	combat["history"] = _bounded_array(combat.get("history", []), MAX_HISTORY)
	var current_value: Variant = combat.get("current", {})
	if bool(combat.active) and current_value is Dictionary:
		combat["current"] = _normalize_battle(current_value as Dictionary)
		if (combat.current as Dictionary).is_empty() or str(combat.current.outcome) != "active":
			combat["active"] = false
	else:
		combat["active"] = false
		combat["current"] = current_value.duplicate(true) if current_value is Dictionary else {}
	state["combat"] = combat
	return combat


static func has_active_combat(state: Dictionary) -> bool:
	return bool(normalize(state).active)


static func start_combat(state: Dictionary, enemy_id: String = "") -> Dictionary:
	var combat := normalize(state)
	if bool(combat.active):
		return {"ok": false, "code": "combat_already_active", "battle": combat.current}
	if bool((state.get("dungeon", {}) as Dictionary).get("active", false)):
		return {"ok": false, "code": "dungeon_active"}
	var era_id := str(state.get("current_era_id", "classical"))
	var definition := _find_enemy(enemy_id)
	if definition.is_empty():
		var pool: Array = ENEMY_POOLS.get(era_id, ENEMY_POOLS.classical)
		definition = (pool[_roll(state, 0, pool.size() - 1)] as Dictionary).duplicate(true)
	var player: Dictionary = state.get("player", {})
	var effective: Dictionary = ItemSystemScript.effective_stats(state)
	var realm_index := clampi(int(player.get("realm_index", 0)), 0, 20)
	var level := clampi(int(player.get("level", 1)), 1, 9)
	var scale_percent := 100 + realm_index * 32 + level * 3
	var enemy_hp := maxi(20, int(definition.hp) * scale_percent / 100)
	var enemy_attack := maxi(4, int(definition.attack) * scale_percent / 100)
	var enemy_defense := maxi(0, int(definition.defense) * scale_percent / 100)
	var hp_bonus := maxi(0, int(effective.max_hp) - int(player.get("max_hp", 1)))
	var battle := {
		"id": "battle_%s" % ("%s|%s|%d|%d" % [state.get("run_id", "run"), definition.id,
			state.get("turn", 0), state.get("rng_cursor", 0)]).sha256_text().left(16),
		"outcome": "active", "turn": 1, "max_turns": MAX_TURNS,
		"era_id": era_id, "player_hp": mini(int(effective.max_hp), int(player.get("hp", 1)) + hp_bonus),
		"player_max_hp": int(effective.max_hp), "player_mp": int(player.get("mp", 0)),
		"player_max_mp": int(effective.max_mp), "player_attack": int(effective.attack),
		"player_defense": int(effective.defense), "player_hp_bonus": hp_bonus,
		"player_statuses": {"bleed": 0, "weak": 0, "shield": 0},
		"enemy_id": str(definition.id), "enemy_name": str(definition.name),
		"enemy_hp": enemy_hp, "enemy_max_hp": enemy_hp, "enemy_attack": enemy_attack,
		"enemy_defense": enemy_defense, "enemy_statuses": {"bleed": 0, "weak": 0, "shield": 0},
		"intent_cycle": (definition.intents as Array).duplicate(), "intent_index": 0,
		"intent": str((definition.intents as Array)[0]), "material": str(definition.material),
		"log": ["%s拦住去路，第一道意图是%s。" % [definition.name, INTENT_NAMES[definition.intents[0]]]],
		"rewards": {},
	}
	combat["active"] = true
	combat["current"] = battle
	state["combat"] = combat
	return {"ok": true, "code": "combat_started", "battle": battle}


static func perform_action(state: Dictionary, action: String) -> Dictionary:
	var combat := normalize(state)
	if not bool(combat.active):
		return {"ok": false, "code": "no_active_combat"}
	var battle: Dictionary = combat.current.duplicate(true)
	if action not in ["attack", "guard", "spell", "pill", "flee"]:
		return {"ok": false, "code": "unknown_action", "battle": battle}
	if action == "spell" and int(battle.player_mp) < SPELL_COST:
		return {"ok": false, "code": "insufficient_mp", "battle": battle}
	if action == "pill" and ItemSystemScript.count(state, "healing_pill") <= 0 and \
		int((state.get("player", {}) as Dictionary).get("pills", 0)) <= 0:
		return {"ok": false, "code": "no_healing_pill", "battle": battle}

	_apply_bleed_start(battle, true)
	_apply_bleed_start(battle, false)
	if int(battle.player_hp) <= 0:
		return _finish(state, battle, "defeat")
	if int(battle.enemy_hp) <= 0:
		return _finish(state, battle, "victory")

	var action_result := _apply_player_action(state, battle, action)
	_append_log(battle, str(action_result.message))
	if action == "flee" and bool(action_result.success):
		return _finish(state, battle, "escaped")
	if int(battle.enemy_hp) <= 0:
		return _finish(state, battle, "victory")

	var enemy_result := _apply_enemy_intent(state, battle)
	_append_log(battle, str(enemy_result.message))
	_tick_duration_statuses(battle)
	if int(battle.player_hp) <= 0:
		return _finish(state, battle, "defeat")
	battle["turn"] = int(battle.turn) + 1
	if int(battle.turn) > int(battle.max_turns):
		return _finish(state, battle, "escaped")
	var cycle: Array = battle.intent_cycle
	battle["intent_index"] = (int(battle.intent_index) + 1) % cycle.size()
	battle["intent"] = str(cycle[int(battle.intent_index)])
	combat["current"] = battle
	state["combat"] = combat
	return {"ok": true, "code": "turn_resolved", "battle": battle,
		"action": action, "enemy_intent": str(battle.intent)}


static func auto_resolve(state: Dictionary, action_limit: int = MAX_TURNS) -> Dictionary:
	var limit := clampi(action_limit, 1, MAX_TURNS)
	var actions := 0
	var last_result: Dictionary = {"ok": false, "code": "no_active_combat"}
	while has_active_combat(state) and actions < limit:
		var battle: Dictionary = state.combat.current
		var action := "attack"
		if int(battle.player_hp) * 100 <= int(battle.player_max_hp) * 32 and \
			(ItemSystemScript.count(state, "healing_pill") > 0 or int(state.player.get("pills", 0)) > 0):
			action = "pill"
		elif str(battle.intent) == "heavy" and int((battle.player_statuses as Dictionary).get("shield", 0)) <= 0:
			action = "guard"
		elif int(battle.player_mp) >= SPELL_COST and actions % 3 == 1:
			action = "spell"
		last_result = perform_action(state, action)
		actions += 1
		if not bool(last_result.get("ok", false)):
			last_result = perform_action(state, "attack")
	if has_active_combat(state):
		var battle: Dictionary = state.combat.current
		last_result = _finish(state, battle, "escaped")
	last_result["actions"] = actions
	return last_result


static func intent_label(battle: Dictionary) -> String:
	return str(INTENT_NAMES.get(str(battle.get("intent", "strike")), "未知意图"))


static func intent_description(battle: Dictionary) -> String:
	return str(INTENT_DESCRIPTIONS.get(str(battle.get("intent", "strike")), "敌意尚未完全显形。"))


static func _apply_player_action(state: Dictionary, battle: Dictionary, action: String) -> Dictionary:
	var weak_scale := 75 if int((battle.player_statuses as Dictionary).get("weak", 0)) > 0 else 100
	if action == "attack":
		var power := int(battle.player_attack) * weak_scale / 100
		var damage := _deal_damage(state, battle, false, power, int(battle.enemy_defense), 18)
		if _roll(state, 1, 100) <= 22:
			var statuses: Dictionary = battle.enemy_statuses
			statuses["bleed"] = maxi(int(statuses.bleed), 2)
			battle["enemy_statuses"] = statuses
		return {"success": true, "message": "你斩出一式，造成%d点伤害。" % damage}
	if action == "guard":
		var statuses: Dictionary = battle.player_statuses
		var shield := maxi(4, int(battle.player_defense) + _roll(state, 0, maxi(2, int(battle.player_defense) / 2)))
		statuses["shield"] = maxi(int(statuses.shield), shield)
		battle["player_statuses"] = statuses
		return {"success": true, "message": "你收势结印，凝成%d点护盾。" % shield}
	if action == "spell":
		battle["player_mp"] = int(battle.player_mp) - SPELL_COST
		var power := int(round(int(battle.player_attack) * 1.45)) * weak_scale / 100
		var damage := _deal_damage(state, battle, false, power, int(battle.enemy_defense) / 2, 12)
		var statuses: Dictionary = battle.enemy_statuses
		statuses["weak"] = maxi(int(statuses.weak), 2)
		battle["enemy_statuses"] = statuses
		return {"success": true, "message": "术法贯穿护体灵光，造成%d点伤害并令敌势衰弱。" % damage}
	if action == "pill":
		if ItemSystemScript.count(state, "healing_pill") > 0:
			ItemSystemScript.remove_item(state, "healing_pill", 1)
		else:
			var player: Dictionary = state.player
			player["pills"] = maxi(0, int(player.get("pills", 0)) - 1)
			state["player"] = player
		var healed := mini(int(battle.player_max_hp) - int(battle.player_hp), maxi(1, int(battle.player_max_hp) * 40 / 100))
		battle["player_hp"] = int(battle.player_hp) + healed
		return {"success": true, "message": "丹力化开，恢复%d点气血。" % healed}
	var flee_chance := clampi(42 + int(state.player.get("realm_index", 0)) * 2 - int(battle.turn), 18, 82)
	var escaped := _roll(state, 1, 100) <= flee_chance
	return {"success": escaped, "message": "你脱离了战圈。" if escaped else "退路被敌意截断。"}


static func _apply_enemy_intent(state: Dictionary, battle: Dictionary) -> Dictionary:
	var intent := str(battle.intent)
	var weak_scale := 75 if int((battle.enemy_statuses as Dictionary).get("weak", 0)) > 0 else 100
	var attack := int(battle.enemy_attack) * weak_scale / 100
	if intent == "guard":
		var statuses: Dictionary = battle.enemy_statuses
		var shield := maxi(4, int(battle.enemy_defense) + _roll(state, 0, maxi(2, int(battle.enemy_defense) / 2)))
		statuses["shield"] = maxi(int(statuses.shield), shield)
		battle["enemy_statuses"] = statuses
		return {"message": "%s结成%d点护身罡气。" % [battle.enemy_name, shield]}
	var variance := 14
	var label := "迅击"
	if intent == "heavy":
		attack = int(round(attack * 1.55))
		variance = 20
		label = "重击"
	var damage := _deal_damage(state, battle, true, attack, int(battle.player_defense), variance)
	if intent == "bleed":
		var statuses: Dictionary = battle.player_statuses
		statuses["bleed"] = maxi(int(statuses.bleed), 3)
		battle["player_statuses"] = statuses
		label = "撕裂"
	elif intent == "weaken":
		var statuses: Dictionary = battle.player_statuses
		statuses["weak"] = maxi(int(statuses.weak), 2)
		battle["player_statuses"] = statuses
		label = "蚀心咒"
	return {"message": "%s施展%s，造成%d点伤害。" % [battle.enemy_name, label, damage]}


static func _deal_damage(state: Dictionary, battle: Dictionary, to_player: bool,
		power: int, defense: int, variance_percent: int) -> int:
	var variance := _roll(state, -variance_percent, variance_percent)
	var raw := maxi(1, power + power * variance / 100 - int(defense * 0.55))
	var status_key := "player_statuses" if to_player else "enemy_statuses"
	var hp_key := "player_hp" if to_player else "enemy_hp"
	var statuses: Dictionary = battle[status_key]
	var shield := int(statuses.get("shield", 0))
	var absorbed := mini(shield, raw)
	statuses["shield"] = shield - absorbed
	battle[status_key] = statuses
	var damage := raw - absorbed
	battle[hp_key] = maxi(0, int(battle[hp_key]) - damage)
	return damage


static func _apply_bleed_start(battle: Dictionary, player_side: bool) -> void:
	var statuses_key := "player_statuses" if player_side else "enemy_statuses"
	var hp_key := "player_hp" if player_side else "enemy_hp"
	var max_hp_key := "player_max_hp" if player_side else "enemy_max_hp"
	var statuses: Dictionary = battle[statuses_key]
	if int(statuses.get("bleed", 0)) > 0:
		var damage := maxi(1, int(battle[max_hp_key]) / 25)
		battle[hp_key] = maxi(0, int(battle[hp_key]) - damage)
		_append_log(battle, "%s因流血失去%d点气血。" % ["你" if player_side else str(battle.enemy_name), damage])


static func _tick_duration_statuses(battle: Dictionary) -> void:
	for statuses_key in ["player_statuses", "enemy_statuses"]:
		var statuses: Dictionary = battle[statuses_key]
		for status_id in ["bleed", "weak"]:
			statuses[status_id] = maxi(0, int(statuses.get(status_id, 0)) - 1)
		battle[statuses_key] = statuses


static func _finish(state: Dictionary, battle: Dictionary, outcome: String) -> Dictionary:
	battle["outcome"] = outcome
	var player: Dictionary = state.player
	var base_hp := maxi(0, int(battle.player_hp) - int(battle.player_hp_bonus))
	player["hp"] = clampi(base_hp, 0, int(player.get("max_hp", 1)))
	player["mp"] = clampi(int(battle.player_mp), 0, int(player.get("max_mp", 0)))
	var rewards := {}
	if outcome == "victory":
		var realm_index := int(player.get("realm_index", 0))
		var exp_reward := 35 + realm_index * 18 + int(battle.turn) * 2
		var stone_reward := 3 + realm_index + _roll(state, 0, 5)
		player["exp"] = int(player.get("exp", 0)) + exp_reward
		player["spirit_stones"] = int(player.get("spirit_stones", 0)) + stone_reward
		player["battles_won"] = int(player.get("battles_won", 0)) + 1
		ItemSystemScript.add_item(state, str(battle.material), 1)
		rewards = {"exp": exp_reward, "spirit_stones": stone_reward, "material": str(battle.material)}
	elif outcome == "defeat":
		player["hp"] = 0
	state["player"] = player
	battle["rewards"] = rewards
	_append_log(battle, _outcome_text(outcome, rewards))
	var combat: Dictionary = state.combat
	combat["active"] = false
	combat["current"] = battle
	var history: Array = combat.get("history", [])
	history.append({"id": battle.id, "enemy_id": battle.enemy_id, "enemy_name": battle.enemy_name,
		"outcome": outcome, "turns": int(battle.turn), "rewards": rewards.duplicate(true)})
	combat["history"] = _bounded_array(history, MAX_HISTORY)
	state["combat"] = combat
	return {"ok": true, "code": "combat_finished", "outcome": outcome,
		"battle": battle, "rewards": rewards}


static func _outcome_text(outcome: String, rewards: Dictionary) -> String:
	if outcome == "victory":
		return "战局已定：修为+%d，灵石+%d。" % [int(rewards.exp), int(rewards.spirit_stones)]
	if outcome == "defeat":
		return "气血归零，此世战局在这里终结。"
	return "双方脱离战圈，胜负留待后来。"


static func _find_enemy(enemy_id: String) -> Dictionary:
	if enemy_id.is_empty():
		return {}
	for pool_value in ENEMY_POOLS.values():
		for definition_value in (pool_value as Array):
			var definition: Dictionary = definition_value
			if str(definition.id) == enemy_id:
				return definition.duplicate(true)
	return {}


static func _normalize_battle(source: Dictionary) -> Dictionary:
	if str(source.get("id", "")).is_empty():
		return {}
	var battle := source.duplicate(true)
	battle["outcome"] = str(battle.get("outcome", "active"))
	battle["turn"] = clampi(int(battle.get("turn", 1)), 1, MAX_TURNS + 1)
	battle["max_turns"] = MAX_TURNS
	for hp_key in ["player_hp", "player_max_hp", "enemy_hp", "enemy_max_hp"]:
		battle[hp_key] = clampi(int(battle.get(hp_key, 1)), 0, 100000000)
	for stat_key in ["player_mp", "player_max_mp", "player_attack", "player_defense",
		"player_hp_bonus", "enemy_attack", "enemy_defense", "intent_index"]:
		battle[stat_key] = clampi(int(battle.get(stat_key, 0)), 0, 100000000)
	battle["player_statuses"] = _normalize_statuses(battle.get("player_statuses", {}))
	battle["enemy_statuses"] = _normalize_statuses(battle.get("enemy_statuses", {}))
	var cycle_value: Variant = battle.get("intent_cycle", ["strike"])
	var cycle: Array = cycle_value.duplicate() if cycle_value is Array and not cycle_value.is_empty() else ["strike"]
	battle["intent_cycle"] = cycle.slice(0, 8)
	battle["intent_index"] = int(battle.intent_index) % battle.intent_cycle.size()
	battle["intent"] = str(battle.intent_cycle[int(battle.intent_index)])
	battle["log"] = _bounded_array(battle.get("log", []), MAX_LOG)
	return battle


static func _normalize_statuses(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	return {"bleed": clampi(int(source.get("bleed", 0)), 0, 20),
		"weak": clampi(int(source.get("weak", 0)), 0, 20),
		"shield": clampi(int(source.get("shield", 0)), 0, 1000000)}


static func _append_log(battle: Dictionary, text: String) -> void:
	var log: Array = battle.get("log", [])
	log.append(text.left(240))
	while log.size() > MAX_LOG:
		log.pop_front()
	battle["log"] = log


static func _roll(state: Dictionary, minimum: int, maximum: int) -> int:
	var cursor := int(state.get("rng_cursor", 0))
	var seed_value := (int(state.get("world_seed", 1)) + cursor * 130363 + 0x6d2b79f5) & 0x7fffffff
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	state["rng_cursor"] = cursor + 1
	return rng.randi_range(minimum, maximum)


static func _bounded_array(value: Variant, maximum: int) -> Array:
	var result: Array = value.duplicate(true) if value is Array else []
	while result.size() > maximum:
		result.pop_front()
	return result
