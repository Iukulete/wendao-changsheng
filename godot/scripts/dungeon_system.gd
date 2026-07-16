class_name DungeonSystem
extends RefCounted

const ItemSystemScript = preload("res://scripts/item_system.gd")
const AchievementSystemScript = preload("res://scripts/achievement_system.gd")

const DATA_PATH := "res://data/dungeon_cards_v1.json"
const MAX_DECK := 64
const MAX_HAND := 10
const MAX_LOG := 48
const MAX_HISTORY := 64
const MAX_TURNS := 60
const STARTING_ENERGY := 3

static var _data_cache: Dictionary = {}


static func load_definitions() -> Dictionary:
	if not _data_cache.is_empty():
		return _data_cache
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		_data_cache = (parsed as Dictionary).duplicate(true)
	return _data_cache


static func validate_definitions() -> Dictionary:
	var data := load_definitions()
	if int(data.get("schema_version", 0)) != 1:
		return {"ok": false, "code": "unsupported_dungeon_schema"}
	var cards_value: Variant = data.get("cards", [])
	var dungeons_value: Variant = data.get("dungeons", [])
	if not cards_value is Array or (cards_value as Array).size() < 12 or not dungeons_value is Array or \
			(dungeons_value as Array).is_empty():
		return {"ok": false, "code": "missing_dungeon_content"}
	var card_ids := {}
	for value in (cards_value as Array):
		if not value is Dictionary:
			return {"ok": false, "code": "invalid_card"}
		var card: Dictionary = value
		var card_id := str(card.get("id", ""))
		if card_id.is_empty() or card_ids.has(card_id) or str(card.get("name", "")).is_empty() or \
				not card.get("effects", null) is Dictionary or int(card.get("cost", -1)) < 0:
			return {"ok": false, "code": "invalid_card"}
		card_ids[card_id] = true
	for era_id in ["classical", "steam", "star_network", "wasteland", "final_age", "immortal_dynasty"]:
		var era: Dictionary = (data.get("era_enemies", {}) as Dictionary).get(era_id, {})
		for rank in ["normal", "elite", "boss"]:
			if not era.get(rank, null) is Dictionary:
				return {"ok": false, "code": "missing_enemy", "era_id": era_id, "rank": rank}
	return {"ok": true, "code": "valid", "card_count": card_ids.size(),
		"dungeon_count": (dungeons_value as Array).size()}


static func normalize(state: Dictionary) -> Dictionary:
	var value: Variant = state.get("dungeon", {})
	var dungeon: Dictionary = value.duplicate(true) if value is Dictionary else {}
	dungeon["active"] = bool(dungeon.get("active", false))
	dungeon["history"] = _bounded_array(dungeon.get("history", []), MAX_HISTORY)
	var run_value: Variant = dungeon.get("run", {})
	var run: Dictionary = run_value.duplicate(true) if run_value is Dictionary else {}
	if bool(dungeon.active):
		run = _normalize_run(run)
		if run.is_empty() or str(run.get("outcome", "active")) != "active":
			dungeon["active"] = false
	dungeon["run"] = run
	state["dungeon"] = dungeon
	return dungeon


static func has_active_run(state: Dictionary) -> bool:
	return bool(normalize(state).active)


static func start(state: Dictionary, dungeon_id: String = "mirror_lake") -> Dictionary:
	var dungeon := normalize(state)
	if bool(dungeon.active):
		return {"ok": false, "code": "dungeon_already_active", "run": dungeon.run}
	var definition := _dungeon_definition(dungeon_id)
	if definition.is_empty():
		return {"ok": false, "code": "unknown_dungeon"}
	var effective: Dictionary = ItemSystemScript.effective_stats(state)
	var deck := _starting_deck(state)
	var run := {
		"id": "dungeon_%s" % ("%s|%s|%d|%d" % [state.get("run_id", "run"), dungeon_id,
			state.get("turn", 0), state.get("rng_cursor", 0)]).sha256_text().left(16),
		"dungeon_id": dungeon_id, "name": str(definition.name), "outcome": "active",
		"era_id": str(state.get("current_era_id", "classical")), "depth": 0,
		"max_depth": int(definition.max_depth), "hp": int(effective.max_hp),
		"max_hp": int(effective.max_hp), "stress": 0, "attack_power": 0,
		"deck": deck, "route_choices": [], "battle": {}, "rewards": {"exp": 0, "spirit_stones": 0},
		"log": ["你踏入%s，今生功法被秘境折成一组临时灵诀。" % str(definition.name)],
	}
	_generate_route(state, run)
	dungeon["active"] = true
	dungeon["run"] = run
	state["dungeon"] = dungeon
	return {"ok": true, "code": "dungeon_started", "run": run}


static func choose_route(state: Dictionary, choice_index: int) -> Dictionary:
	var dungeon := normalize(state)
	if not bool(dungeon.active):
		return {"ok": false, "code": "no_active_dungeon"}
	var run: Dictionary = dungeon.run.duplicate(true)
	if not (run.battle as Dictionary).is_empty():
		return {"ok": false, "code": "battle_in_progress"}
	var choices: Array = run.route_choices
	if choice_index < 0 or choice_index >= choices.size():
		return {"ok": false, "code": "invalid_route_choice"}
	var node: Dictionary = choices[choice_index]
	run["route_choices"] = []
	var node_type := str(node.type)
	if node_type in ["combat", "elite", "boss"]:
		run["battle"] = _start_battle(state, run, node_type)
		_append_log(run, "你选择%s，%s在前方显形。" % [str(node.name), str(run.battle.enemy_name)])
		dungeon["run"] = run
		state["dungeon"] = dungeon
		return {"ok": true, "code": "dungeon_battle_started", "node": node, "run": run}
	_resolve_noncombat_node(state, run, node_type)
	return _advance_after_node(state, dungeon, run, node)


static func play_card(state: Dictionary, hand_index: int) -> Dictionary:
	var dungeon := normalize(state)
	if not bool(dungeon.active):
		return {"ok": false, "code": "no_active_dungeon"}
	var run: Dictionary = dungeon.run.duplicate(true)
	var battle: Dictionary = run.battle
	if battle.is_empty() or str(battle.get("outcome", "")) != "active":
		return {"ok": false, "code": "no_dungeon_battle"}
	var hand: Array = battle.hand
	if hand_index < 0 or hand_index >= hand.size():
		return {"ok": false, "code": "invalid_hand_index"}
	var card: Dictionary = hand[hand_index]
	var definition := card_definition(str(card.card_id))
	var cost := int(definition.cost)
	if int(battle.energy) < cost:
		return {"ok": false, "code": "insufficient_energy", "battle": battle}
	battle["energy"] = int(battle.energy) - cost
	hand.remove_at(hand_index)
	battle["hand"] = hand
	var effects: Dictionary = definition.effects
	var scale := 100 + int(card.get("upgrade", 0)) * 30
	var damage := 0
	var block := 0
	if int(effects.get("attack", 0)) > 0:
		var base_damage := int(effects.attack) * scale / 100 + int(run.attack_power)
		damage = _damage_enemy(battle, base_damage + int((state.get("player", {}) as Dictionary).get("realm_index", 0)))
	if int(effects.get("block", 0)) > 0:
		block = int(effects.block) * scale / 100
		battle["player_block"] = int(battle.player_block) + block
	if int(effects.get("heal", 0)) > 0:
		run["hp"] = mini(int(run.max_hp), int(run.hp) + int(effects.heal) * scale / 100)
	if int(effects.get("energy", 0)) > 0:
		battle["energy"] = mini(6, int(battle.energy) + int(effects.energy))
	if int(effects.get("weak", 0)) > 0:
		battle["enemy_weak"] = maxi(int(battle.enemy_weak), int(effects.weak))
	if int(effects.get("power", 0)) > 0:
		run["attack_power"] = int(run.attack_power) + int(effects.power)
	run["stress"] = clampi(int(run.stress) + int(effects.get("stress", 0)) - int(effects.get("calm", 0)), 0, 100)
	_draw_cards(state, battle, int(effects.get("draw", 0)))
	if bool(definition.get("exhaust", false)):
		var exhausted: Array = battle.exhausted
		exhausted.append(card)
		battle["exhausted"] = exhausted
	else:
		var discard: Array = battle.discard_pile
		discard.append(card)
		battle["discard_pile"] = discard
	_append_log(run, "你施展%s，造成%d伤害、凝成%d护体。" % [str(definition.name), damage, block])
	if int(battle.enemy_hp) <= 0:
		run["battle"] = battle
		return _finish_battle(state, dungeon, run, "victory")
	run["battle"] = battle
	dungeon["run"] = run
	state["dungeon"] = dungeon
	return {"ok": true, "code": "card_played", "card": card, "battle": battle, "run": run}


static func end_turn(state: Dictionary) -> Dictionary:
	var dungeon := normalize(state)
	if not bool(dungeon.active):
		return {"ok": false, "code": "no_active_dungeon"}
	var run: Dictionary = dungeon.run.duplicate(true)
	var battle: Dictionary = run.battle
	if battle.is_empty() or str(battle.get("outcome", "")) != "active":
		return {"ok": false, "code": "no_dungeon_battle"}
	var intent := str(battle.intent)
	var damage := 0
	if intent == "guard":
		battle["enemy_block"] = int(battle.enemy_block) + maxi(5, int(battle.enemy_attack) / 2)
	elif intent == "stress":
		run["stress"] = mini(100, int(run.stress) + 18)
	else:
		var power := int(battle.enemy_attack)
		if intent == "heavy": power = int(round(power * 1.55))
		if int(battle.enemy_weak) > 0: power = power * 75 / 100
		damage = maxi(0, power - int(battle.player_block))
		run["hp"] = maxi(0, int(run.hp) - damage)
		run["stress"] = mini(100, int(run.stress) + maxi(2, damage / 3))
	_append_log(run, "%s施展%s，你失去%d点气血。" % [str(battle.enemy_name), intent_label(intent), damage])
	var discard: Array = battle.discard_pile
	for card_value in (battle.hand as Array): discard.append(card_value)
	battle["discard_pile"] = discard
	battle["hand"] = []
	battle["player_block"] = 0
	battle["enemy_weak"] = maxi(0, int(battle.enemy_weak) - 1)
	battle["turn"] = int(battle.turn) + 1
	if int(run.hp) <= 0:
		run["battle"] = battle
		return _finish_battle(state, dungeon, run, "defeat")
	if int(battle.turn) > MAX_TURNS:
		run["battle"] = battle
		return _finish_battle(state, dungeon, run, "defeat")
	if int(run.stress) >= 100:
		var curse := _new_card(run, "heart_demon")
		discard = battle.discard_pile
		discard.append(curse)
		battle["discard_pile"] = discard
		run["stress"] = 60
		_append_log(run, "心魔压力越过极限，一张心障残页混入牌组。")
	var cycle: Array = battle.intent_cycle
	battle["intent_index"] = (int(battle.intent_index) + 1) % cycle.size()
	battle["intent"] = str(cycle[int(battle.intent_index)])
	battle["energy"] = STARTING_ENERGY
	_draw_cards(state, battle, 5)
	run["battle"] = battle
	dungeon["run"] = run
	state["dungeon"] = dungeon
	return {"ok": true, "code": "dungeon_turn_ended", "battle": battle, "run": run}


static func abandon(state: Dictionary) -> Dictionary:
	var dungeon := normalize(state)
	if not bool(dungeon.active):
		return {"ok": false, "code": "no_active_dungeon"}
	var run: Dictionary = dungeon.run
	return _finish_run(state, dungeon, run, "abandoned")


static func auto_resolve(state: Dictionary, action_limit: int = 512) -> Dictionary:
	var actions := 0
	var last: Dictionary = {"ok": true, "code": "idle"}
	while has_active_run(state) and actions < action_limit:
		var run: Dictionary = state.dungeon.run
		if (run.battle as Dictionary).is_empty():
			last = choose_route(state, 0)
		else:
			var battle: Dictionary = run.battle
			var best_index := -1
			var best_score := -1
			for index in range((battle.hand as Array).size()):
				var card: Dictionary = battle.hand[index]
				var definition := card_definition(str(card.card_id))
				if int(definition.cost) <= int(battle.energy):
					var score := int((definition.effects as Dictionary).get("attack", 0)) * 3 + \
						int((definition.effects as Dictionary).get("block", 0))
					if score > best_score: best_score = score; best_index = index
			if best_index >= 0:
				last = play_card(state, best_index)
			else:
				last = end_turn(state)
		actions += 1
		if not bool(last.get("ok", false)): break
	if has_active_run(state):
		last = abandon(state)
	last["actions"] = actions
	return last


static func card_definition(card_id: String) -> Dictionary:
	for value in (load_definitions().get("cards", []) as Array):
		var card: Dictionary = value
		if str(card.id) == card_id: return card
	return {}


static func intent_label(intent: String) -> String:
	return str({"strike": "迅击", "heavy": "蓄势重击", "guard": "结界护体", "stress": "心魔低语"}.get(intent, "未知意图"))


static func _starting_deck(state: Dictionary) -> Array:
	var run_seed := {"card_counter": 0}
	var deck: Array = []
	for _i in range(4): deck.append(_new_card(run_seed, "sword_cut"))
	for _i in range(4): deck.append(_new_card(run_seed, "jade_guard"))
	deck.append(_new_card(run_seed, "qi_breath"))
	var path: Dictionary = (state.get("player", {}) as Dictionary).get("path", {})
	var dominant := "insight"
	var best := -1000000
	for path_id in ["compassion", "ambition", "defiance", "insight", "creation", "bonds"]:
		if int(path.get(path_id, 0)) > best: best = int(path.get(path_id, 0)); dominant = path_id
	var path_cards := {"compassion":"lotus_vow", "ambition":"sky_seize", "defiance":"fate_break",
		"insight":"cause_trace", "creation":"forge_edge", "bonds":"shared_oath"}
	deck.append(_new_card(run_seed, str(path_cards[dominant])))
	var jade := AchievementSystemScript.current_weapon(state)
	if not jade.is_empty():
		var style_cards := {"slaughter":"blood_arc", "guardian":"timeless_ward",
			"insight":"mind_mirror", "myriad":"myriad_cycle"}
		deck.append(_new_card(run_seed, str(style_cards.get(str(jade.style), "mind_mirror"))))
	return deck


static func _generate_route(state: Dictionary, run: Dictionary) -> void:
	var depth := int(run.depth)
	var max_depth := int(run.max_depth)
	if depth >= max_depth - 1:
		run["route_choices"] = [{"type":"boss", "name":"空阙终门", "danger":"首领"}]
		return
	var pools := [["combat", "memory"], ["combat", "rest"], ["elite", "forge"]]
	var pool: Array = pools[mini(depth, pools.size() - 1)]
	if _roll(state, 0, 1) == 1: pool.reverse()
	var names := {"combat":"因果岔路", "memory":"失落道碑", "rest":"无风静室", "elite":"守门死局", "forge":"器痕炉台"}
	var danger := {"combat":"交锋", "memory":"机缘", "rest":"休整", "elite":"强敌", "forge":"炼器"}
	var choices: Array = []
	for node_type in pool:
		choices.append({"type":str(node_type), "name":str(names[node_type]), "danger":str(danger[node_type])})
	run["route_choices"] = choices


static func _start_battle(state: Dictionary, run: Dictionary, rank: String) -> Dictionary:
	var enemies: Dictionary = (load_definitions().era_enemies as Dictionary).get(str(run.era_id), {})
	var source: Dictionary = enemies.get(rank, enemies.get("normal", {}))
	var realm := int((state.get("player", {}) as Dictionary).get("realm_index", 0))
	var scale := 100 + realm * 12 + int(run.depth) * 12
	var deck: Array = run.deck.duplicate(true)
	_shuffle(state, deck)
	var battle := {"outcome":"active", "rank":rank, "turn":1, "energy":STARTING_ENERGY,
		"player_block":0, "enemy_name":str(source.name), "enemy_hp":maxi(20, int(source.hp) * scale / 100),
		"enemy_max_hp":maxi(20, int(source.hp) * scale / 100), "enemy_attack":maxi(4, int(source.attack) * scale / 100),
		"enemy_block":0, "enemy_weak":0, "intent_cycle":(source.intents as Array).duplicate(),
		"intent_index":0, "intent":str((source.intents as Array)[0]), "draw_pile":deck,
		"discard_pile":[], "exhausted":[], "hand":[]}
	_draw_cards(state, battle, 5)
	return battle


static func _draw_cards(state: Dictionary, battle: Dictionary, amount: int) -> void:
	var hand: Array = battle.hand
	var draw: Array = battle.draw_pile
	var discard: Array = battle.discard_pile
	for _i in range(amount):
		if hand.size() >= MAX_HAND: break
		if draw.is_empty() and not discard.is_empty():
			draw = discard
			discard = []
			_shuffle(state, draw)
		if draw.is_empty(): break
		hand.append(draw.pop_back())
	battle["hand"] = hand
	battle["draw_pile"] = draw
	battle["discard_pile"] = discard


static func _damage_enemy(battle: Dictionary, amount: int) -> int:
	var weak_scale := 75 if int(battle.enemy_weak) > 0 else 100
	var raw := maxi(1, amount * weak_scale / 100)
	var absorbed := mini(int(battle.enemy_block), raw)
	battle["enemy_block"] = int(battle.enemy_block) - absorbed
	var damage := raw - absorbed
	battle["enemy_hp"] = maxi(0, int(battle.enemy_hp) - damage)
	return damage


static func _finish_battle(state: Dictionary, dungeon: Dictionary, run: Dictionary, outcome: String) -> Dictionary:
	var battle: Dictionary = run.battle
	battle["outcome"] = outcome
	run["battle"] = {}
	if outcome == "defeat":
		return _finish_run(state, dungeon, run, "defeat")
	var rank := str(battle.rank)
	var exp_gain := 32 + int(run.depth) * 18 + (45 if rank == "elite" else 0) + (90 if rank == "boss" else 0)
	var stone_gain := 2 + int(run.depth) + (5 if rank == "elite" else 0) + (12 if rank == "boss" else 0)
	run.rewards.exp = int(run.rewards.exp) + exp_gain
	run.rewards.spirit_stones = int(run.rewards.spirit_stones) + stone_gain
	_append_log(run, "你战胜%s，秘境暂存修为%d、灵石%d。" % [str(battle.enemy_name), exp_gain, stone_gain])
	return _advance_after_node(state, dungeon, run, {"type":rank, "name":str(battle.enemy_name)})


static func _resolve_noncombat_node(state: Dictionary, run: Dictionary, node_type: String) -> void:
	if node_type == "rest":
		var healed := mini(int(run.max_hp) - int(run.hp), maxi(1, int(run.max_hp) * 28 / 100))
		run["hp"] = int(run.hp) + healed
		run["stress"] = maxi(0, int(run.stress) - 22)
		_append_log(run, "无风静室令你恢复%d点气血，心魔压力下降。" % healed)
	elif node_type == "forge":
		var deck: Array = run.deck
		var index := _roll(state, 0, deck.size() - 1)
		var card: Dictionary = deck[index]
		card["upgrade"] = mini(2, int(card.get("upgrade", 0)) + 1)
		deck[index] = card
		run["deck"] = deck
		_append_log(run, "%s被炉台刻入一道强化器痕。" % str(card_definition(str(card.card_id)).name))
	else:
		var candidates := ["lotus_vow", "fate_break", "cause_trace", "forge_edge", "shared_oath"]
		var card := _new_card(run, str(candidates[_roll(state, 0, candidates.size() - 1)]))
		var deck: Array = run.deck
		if deck.size() < MAX_DECK: deck.append(card)
		run["deck"] = deck
		_append_log(run, "失落道碑让你临时领悟%s。" % str(card_definition(str(card.card_id)).name))


static func _advance_after_node(state: Dictionary, dungeon: Dictionary, run: Dictionary, node: Dictionary) -> Dictionary:
	run["depth"] = int(run.depth) + 1
	if int(run.depth) >= int(run.max_depth):
		return _finish_run(state, dungeon, run, "completed")
	_generate_route(state, run)
	dungeon["run"] = run
	state["dungeon"] = dungeon
	return {"ok": true, "code": "dungeon_node_completed", "node": node, "run": run}


static func _finish_run(state: Dictionary, dungeon: Dictionary, run: Dictionary, outcome: String) -> Dictionary:
	run["outcome"] = outcome
	var player: Dictionary = state.get("player", {})
	var rewards: Dictionary = run.rewards
	if outcome == "completed":
		player["exp"] = int(player.exp) + int(rewards.exp)
		player["spirit_stones"] = int(player.spirit_stones) + int(rewards.spirit_stones)
		ItemSystemScript.add_item(state, str(_dungeon_definition(str(run.dungeon_id)).reward_material), 1)
		AchievementSystemScript.add_resonance(state, 12, "秘境通关")
	elif outcome == "defeat":
		player["hp"] = maxi(1, int(player.hp) - maxi(1, int(player.max_hp) / 3))
		player["statuses"] = _bounded_array(player.get("statuses", []) + ["秘境心创"], 64)
	state["player"] = player
	dungeon["active"] = false
	dungeon["run"] = run
	var history: Array = dungeon.history
	history.append({"id":run.id, "dungeon_id":run.dungeon_id, "outcome":outcome,
		"depth":int(run.depth), "rewards":rewards.duplicate(true), "generation":int(state.get("generation", 1))})
	dungeon["history"] = _bounded_array(history, MAX_HISTORY)
	state["dungeon"] = dungeon
	return {"ok": true, "code": "dungeon_finished", "outcome": outcome, "run": run, "rewards": rewards}


static func _normalize_run(source: Dictionary) -> Dictionary:
	if str(source.get("id", "")).is_empty(): return {}
	var run := source.duplicate(true)
	run["outcome"] = str(run.get("outcome", "active"))
	run["depth"] = clampi(int(run.get("depth", 0)), 0, 64)
	run["max_depth"] = clampi(int(run.get("max_depth", 4)), 1, 64)
	run["max_hp"] = clampi(int(run.get("max_hp", 1)), 1, 100000000)
	run["hp"] = clampi(int(run.get("hp", 1)), 0, int(run.max_hp))
	run["stress"] = clampi(int(run.get("stress", 0)), 0, 100)
	run["attack_power"] = clampi(int(run.get("attack_power", 0)), 0, 100000)
	run["deck"] = _normalize_cards(run.get("deck", []))
	run["route_choices"] = _bounded_array(run.get("route_choices", []), 3)
	run["log"] = _bounded_array(run.get("log", []), MAX_LOG)
	var battle_value: Variant = run.get("battle", {})
	run["battle"] = battle_value.duplicate(true) if battle_value is Dictionary else {}
	return run


static func _normalize_cards(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for card_value in (value as Array):
			if card_value is Dictionary and not card_definition(str((card_value as Dictionary).get("card_id", ""))).is_empty():
				result.append({"uid":str((card_value as Dictionary).get("uid", "")).left(64),
					"card_id":str((card_value as Dictionary).card_id),
					"upgrade":clampi(int((card_value as Dictionary).get("upgrade", 0)), 0, 2)})
				if result.size() >= MAX_DECK: break
	return result


static func _new_card(run: Dictionary, card_id: String) -> Dictionary:
	var counter := int(run.get("card_counter", 0)) + 1
	run["card_counter"] = counter
	return {"uid":"card_%06d" % counter, "card_id":card_id, "upgrade":0}


static func _dungeon_definition(dungeon_id: String) -> Dictionary:
	for value in (load_definitions().get("dungeons", []) as Array):
		var dungeon: Dictionary = value
		if str(dungeon.id) == dungeon_id: return dungeon
	return {}


static func _append_log(run: Dictionary, message: String) -> void:
	var log: Array = run.log
	log.append(message.left(240))
	run["log"] = _bounded_array(log, MAX_LOG)


static func _shuffle(state: Dictionary, items: Array) -> void:
	for index in range(items.size() - 1, 0, -1):
		var target := _roll(state, 0, index)
		var temporary: Variant = items[index]
		items[index] = items[target]
		items[target] = temporary


static func _roll(state: Dictionary, minimum: int, maximum: int) -> int:
	var cursor := int(state.get("rng_cursor", 0))
	var seed_value := (int(state.get("world_seed", 1)) + cursor * 196613 + 0x2c1b3c6d) & 0x7fffffff
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	state["rng_cursor"] = cursor + 1
	return rng.randi_range(minimum, maximum)


static func _bounded_array(value: Variant, maximum: int) -> Array:
	var result: Array = value.duplicate(true) if value is Array else []
	while result.size() > maximum: result.pop_front()
	return result
