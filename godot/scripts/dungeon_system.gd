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
const ERA_IDS := ["classical", "steam", "star_network", "wasteland", "final_age", "immortal_dynasty"]
const ROUTE_TYPES := ["combat", "memory", "rest", "elite", "forge", "boss"]
const SUPPORTED_NODE_EFFECTS := ["heal_percent", "calm", "stress", "hp_cost", "attack_power", "guard_power"]
const SUPPORTED_ENEMY_TRAITS := [
	"oath_barrier", "zero_cost_pressure", "causal_checksum",
	"salvage_shell", "breath_interest", "upgrade_censure",
	"mirror_rebuke", "furnace_overload", "memory_fork",
	"black_rain_erosion", "breath_tax", "heavenly_decree",
]
const SUPPORTED_BOSS_PHASES := [
	"mirror_unbound", "redline", "future_merge",
	"rain_deluge", "total_collection", "blank_edict",
]
const SUPPORTED_INTENTS := ["strike", "heavy", "guard", "stress"]
const SUPPORTED_HEART_PENALTIES := [
	"copies", "hp_loss", "energy_loss", "enemy_block", "attack_loss", "guard_loss",
]
const STORY_ARC_IDS := ["jade", "sect", "family", "rival"]
const PATH_IDS := ["compassion", "ambition", "defiance", "insight", "creation", "bonds"]
const PATH_TIE_ORDER := ["insight", "creation", "compassion", "bonds", "defiance", "ambition"]
const PATH_NAMES := {
	"compassion": "慈悲", "ambition": "凌云", "defiance": "逆命",
	"insight": "明悟", "creation": "造化", "bonds": "羁绊",
}
const PATH_CARDS := {
	"compassion": "lotus_vow", "ambition": "sky_seize", "defiance": "fate_break",
	"insight": "cause_trace", "creation": "forge_edge", "bonds": "shared_oath",
}
const JADE_STYLE_CARDS := {
	"slaughter": "blood_arc", "guardian": "timeless_ward",
	"insight": "mind_mirror", "myriad": "myriad_cycle",
}
const REQUIRED_ABILITY_CARDS := [
	"sword_cut", "jade_guard", "qi_breath", "weapon_resonance", "armor_circulation",
	"realm_manifestation", "relic_cycle", "past_life_echo", "lotus_vow", "sky_seize",
	"fate_break", "cause_trace", "forge_edge", "shared_oath", "blood_arc",
	"timeless_ward", "mind_mirror", "myriad_cycle", "heart_demon",
	"old_self_witness", "present_anchor", "dream_seal", "law_inscription",
	"lineage_burden", "founding_doctrine", "ancestral_covenant", "nurture_first",
	"nameless_duty", "snow_duel", "shoulder_snow", "lucid_rivalry",
	"heart_unmade_self", "heart_pressure_debt", "heart_identity_fork",
	"heart_black_rain", "heart_breath_ledger", "heart_unregistered",
]
const SUPPORTED_EFFECTS := ["attack", "block", "heal", "energy", "weak", "power", "stress", "calm", "draw"]

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
	if not cards_value is Array or (cards_value as Array).size() < REQUIRED_ABILITY_CARDS.size() or not dungeons_value is Array or \
			(dungeons_value as Array).is_empty():
		return {"ok": false, "code": "missing_dungeon_content"}
	var card_ids := {}
	for value in (cards_value as Array):
		if not value is Dictionary:
			return {"ok": false, "code": "invalid_card"}
		var card: Dictionary = value
		var card_id := str(card.get("id", ""))
		if card_id.is_empty() or card_ids.has(card_id) or str(card.get("name", "")).is_empty() or \
				str(card.get("description", "")).is_empty() or \
				not card.get("effects", null) is Dictionary or int(card.get("cost", -1)) < 0:
			return {"ok": false, "code": "invalid_card"}
		for effect_id in (card.effects as Dictionary).keys():
			if not SUPPORTED_EFFECTS.has(str(effect_id)) or \
					typeof(card.effects[effect_id]) not in [TYPE_INT, TYPE_FLOAT]:
				return {"ok": false, "code": "invalid_card_effect", "card_id": card_id}
		card_ids[card_id] = true
	for required_id in REQUIRED_ABILITY_CARDS:
		if not card_ids.has(required_id):
			return {"ok": false, "code": "missing_ability_card", "card_id": required_id}
	var story_projections_value: Variant = data.get("story_projections", {})
	if not story_projections_value is Dictionary:
		return {"ok": false, "code": "missing_story_projections"}
	var story_projection_count := 0
	var story_card_ids := {}
	for arc_id in STORY_ARC_IDS:
		var arc_projection_value: Variant = (story_projections_value as Dictionary).get(arc_id, {})
		if not arc_projection_value is Dictionary:
			return {"ok": false, "code": "missing_story_projection", "arc_id": arc_id}
		var arc_projection: Dictionary = arc_projection_value
		var resolutions_value: Variant = arc_projection.get("resolutions", {})
		if str(arc_projection.get("name", "")).is_empty() or not resolutions_value is Dictionary or \
				(resolutions_value as Dictionary).size() != 6:
			return {"ok": false, "code": "invalid_story_projection", "arc_id": arc_id}
		for resolution_value in (resolutions_value as Dictionary).keys():
			var resolution := str(resolution_value)
			var card_id := str((resolutions_value as Dictionary)[resolution_value])
			if resolution.is_empty() or not card_ids.has(card_id):
				return {"ok": false, "code": "invalid_story_ability", "arc_id": arc_id,
					"resolution": resolution, "card_id": card_id}
			story_projection_count += 1
			story_card_ids[card_id] = true
	if story_card_ids.size() != 12:
		return {"ok": false, "code": "invalid_story_ability_variety"}
	var heart_demons_value: Variant = data.get("heart_demons", {})
	if not heart_demons_value is Dictionary:
		return {"ok": false, "code": "missing_heart_demons"}
	var heart_card_ids := {}
	for era_id in ERA_IDS:
		var heart_value: Variant = (heart_demons_value as Dictionary).get(era_id, {})
		if not heart_value is Dictionary:
			return {"ok": false, "code": "missing_heart_demon", "era_id": era_id}
		var heart: Dictionary = heart_value
		var heart_card_id := str(heart.get("card_id", ""))
		var penalty_value: Variant = heart.get("penalty", {})
		if not card_ids.has(heart_card_id) or heart_card_ids.has(heart_card_id) or \
				not bool(card_definition(heart_card_id).get("curse", false)) or \
				str(heart.get("source_name", "")).is_empty() or str(heart.get("awakening", "")).is_empty() or \
				int(heart.get("recovery", -1)) not in range(0, 100) or not penalty_value is Dictionary or \
				(penalty_value as Dictionary).is_empty():
			return {"ok": false, "code": "invalid_heart_demon", "era_id": era_id}
		for penalty_id in (penalty_value as Dictionary).keys():
			if not SUPPORTED_HEART_PENALTIES.has(str(penalty_id)) or \
					typeof((penalty_value as Dictionary)[penalty_id]) not in [TYPE_INT, TYPE_FLOAT] or \
					int((penalty_value as Dictionary)[penalty_id]) <= 0:
				return {"ok": false, "code": "invalid_heart_penalty", "era_id": era_id,
					"penalty_id": str(penalty_id)}
		var copies := int((penalty_value as Dictionary).get("copies", 1))
		if copies < 1 or copies > 3:
			return {"ok": false, "code": "invalid_heart_copies", "era_id": era_id}
		heart_card_ids[heart_card_id] = true
	var route_node_count := 0
	var elite_trait_count := 0
	var boss_trait_count := 0
	var phase_count := 0
	var trait_ids := {}
	var phase_ids := {}
	var era_routes_value: Variant = data.get("era_routes", {})
	if not era_routes_value is Dictionary:
		return {"ok": false, "code": "missing_era_routes"}
	for era_id in ERA_IDS:
		var routes_value: Variant = (era_routes_value as Dictionary).get(era_id, {})
		if not routes_value is Dictionary:
			return {"ok": false, "code": "missing_era_routes", "era_id": era_id}
		for node_type in ROUTE_TYPES:
			var node_value: Variant = (routes_value as Dictionary).get(node_type, {})
			if not node_value is Dictionary:
				return {"ok": false, "code": "missing_route_node", "era_id": era_id, "node_type": node_type}
			var node: Dictionary = node_value
			if str(node.get("name", "")).is_empty() or str(node.get("danger", "")).is_empty() or \
					str(node.get("description", "")).is_empty():
				return {"ok": false, "code": "invalid_route_node", "era_id": era_id, "node_type": node_type}
			var effects_value: Variant = node.get("effects", {})
			if not effects_value is Dictionary:
				return {"ok": false, "code": "invalid_route_effects", "era_id": era_id, "node_type": node_type}
			for effect_id in (effects_value as Dictionary).keys():
				if not SUPPORTED_NODE_EFFECTS.has(str(effect_id)) or \
						typeof((effects_value as Dictionary)[effect_id]) not in [TYPE_INT, TYPE_FLOAT]:
					return {"ok": false, "code": "invalid_route_effect", "era_id": era_id,
						"node_type": node_type, "effect_id": str(effect_id)}
			route_node_count += 1
		var era: Dictionary = (data.get("era_enemies", {}) as Dictionary).get(era_id, {})
		for rank in ["normal", "elite", "boss"]:
			var enemy_value: Variant = era.get(rank, null)
			if not enemy_value is Dictionary:
				return {"ok": false, "code": "missing_enemy", "era_id": era_id, "rank": rank}
			var intents_value: Variant = (enemy_value as Dictionary).get("intents", [])
			if not intents_value is Array or (intents_value as Array).is_empty():
				return {"ok": false, "code": "missing_enemy_intents", "era_id": era_id, "rank": rank}
			for intent_value in (intents_value as Array):
				if not SUPPORTED_INTENTS.has(str(intent_value)):
					return {"ok": false, "code": "invalid_enemy_intent", "era_id": era_id, "rank": rank}
		for rank in ["elite", "boss"]:
			var rule_value: Variant = (era.get(rank, {}) as Dictionary).get("trait", {})
			if not rule_value is Dictionary:
				return {"ok": false, "code": "missing_enemy_trait", "era_id": era_id, "rank": rank}
			var rule: Dictionary = rule_value
			var rule_id := str(rule.get("id", ""))
			if not SUPPORTED_ENEMY_TRAITS.has(rule_id) or trait_ids.has(rule_id) or \
					str(rule.get("name", "")).is_empty() or str(rule.get("description", "")).is_empty() or \
					int(rule.get("value", 0)) <= 0:
				return {"ok": false, "code": "invalid_enemy_trait", "era_id": era_id, "rank": rank}
			trait_ids[rule_id] = true
			if rank == "elite": elite_trait_count += 1
			else: boss_trait_count += 1
		var phase_value: Variant = (era.boss as Dictionary).get("phase", {})
		if not phase_value is Dictionary:
			return {"ok": false, "code": "missing_boss_phase", "era_id": era_id}
		var phase: Dictionary = phase_value
		var phase_id := str(phase.get("id", ""))
		var phase_intents_value: Variant = phase.get("intents", [])
		if not SUPPORTED_BOSS_PHASES.has(phase_id) or phase_ids.has(phase_id) or \
				str(phase.get("name", "")).is_empty() or str(phase.get("description", "")).is_empty() or \
				int(phase.get("threshold", 0)) not in range(1, 100) or int(phase.get("value", 0)) <= 0 or \
				not phase_intents_value is Array or (phase_intents_value as Array).is_empty():
			return {"ok": false, "code": "invalid_boss_phase", "era_id": era_id}
		for intent_value in (phase_intents_value as Array):
			if not SUPPORTED_INTENTS.has(str(intent_value)):
				return {"ok": false, "code": "invalid_boss_phase_intent", "era_id": era_id}
		phase_ids[phase_id] = true
		phase_count += 1
	return {"ok": true, "code": "valid", "card_count": card_ids.size(),
		"dungeon_count": (dungeons_value as Array).size(), "route_node_count": route_node_count,
		"elite_trait_count": elite_trait_count, "boss_trait_count": boss_trait_count,
		"phase_count": phase_count, "story_projection_count": story_projection_count,
		"story_card_count": story_card_ids.size(), "heart_demon_count": heart_card_ids.size()}


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
	if bool((state.get("combat", {}) as Dictionary).get("active", false)):
		return {"ok": false, "code": "combat_active"}
	var definition := _dungeon_definition(dungeon_id)
	if definition.is_empty():
		return {"ok": false, "code": "unknown_dungeon"}
	var effective: Dictionary = ItemSystemScript.effective_stats(state)
	var projection := _starting_deck(state)
	var deck: Array = projection.deck
	var run := {
		"id": "dungeon_%s" % ("%s|%s|%d|%d" % [state.get("run_id", "run"), dungeon_id,
			state.get("turn", 0), state.get("rng_cursor", 0)]).sha256_text().left(16),
		"dungeon_id": dungeon_id, "name": str(definition.name), "outcome": "active",
		"era_id": str(state.get("current_era_id", "classical")), "depth": 0,
		"max_depth": int(definition.max_depth), "hp": int(effective.max_hp),
		"max_hp": int(effective.max_hp), "stress": 0,
		"attack_power": clampi(int(effective.attack) / 24, 0, 14),
		"guard_power": clampi(int(effective.defense) / 18, 0, 14),
		"card_counter": int(projection.card_counter),
		"ability_profile": projection.profile,
		"deck": deck, "route_choices": [], "battle": {}, "rewards": {"exp": 0, "spirit_stones": 0},
		"log": ["你踏入%s，今生功法被秘境折成一组临时灵诀。" % str(definition.name),
			"能力映照：%s" % ability_profile_label(projection.profile)],
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
		_append_log(run, "%s：%s" % [str(node.name), str(node.get("description", "前路敌意凝结。"))])
		_append_log(run, "%s在前方显形。" % str(run.battle.enemy_name))
		var rule: Dictionary = run.battle.get("trait", {})
		if not rule.is_empty():
			_append_log(run, "%s·%s：%s" % [combat_rule_title(run.battle), str(rule.name),
				str(rule.description)])
		var phase: Dictionary = run.battle.get("phase", {})
		if not phase.is_empty():
			_append_log(run, "未显之相·%s：%s" % [str(phase.name), str(phase.description)])
		dungeon["run"] = run
		state["dungeon"] = dungeon
		return {"ok": true, "code": "dungeon_battle_started", "node": node, "run": run}
	_resolve_noncombat_node(state, run, node)
	return _advance_after_node(state, dungeon, run, node)


static func play_card(state: Dictionary, hand_index: int) -> Dictionary:
	var dungeon := normalize(state)
	if not bool(dungeon.active):
		return {"ok": false, "code": "no_active_dungeon"}
	var run: Dictionary = dungeon.run.duplicate(true)
	var battle: Dictionary = run.battle
	if battle.is_empty() or str(battle.get("outcome", "")) != "active":
		return {"ok": false, "code": "no_dungeon_battle"}
	var player_hp_before := int(run.hp)
	var stress_before := int(run.stress)
	var enemy_block_before := int(battle.enemy_block)
	var attack_power_before := int(run.attack_power)
	var phase_was_active := bool(battle.get("phase_active", false))
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
	var enemy_hp_before := int(battle.enemy_hp)
	if int(effects.get("attack", 0)) > 0:
		var base_damage := int(effects.attack) * scale / 100 + int(run.attack_power)
		damage = _damage_enemy(battle, base_damage + int((state.get("player", {}) as Dictionary).get("realm_index", 0)))
		_activate_phase_if_needed(run, battle)
		damage = maxi(0, enemy_hp_before - int(battle.enemy_hp))
	if int(effects.get("block", 0)) > 0:
		block = int(effects.block) * scale / 100 + int(run.get("guard_power", 0))
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
	battle["cards_played_turn"] = int(battle.get("cards_played_turn", 0)) + 1
	_apply_trait_after_card(run, battle, card, damage)
	var phase_shifted := not phase_was_active and bool(battle.get("phase_active", false))
	var phase: Dictionary = battle.get("phase", {})
	var feedback := {"kind":"card", "card_id":str(card.card_id),
		"card_name":str(definition.name), "source_kind":str(card.get("source_kind", "foundation")),
		"damage":damage, "block":block, "hp_delta":int(run.hp) - player_hp_before,
		"stress_delta":int(run.stress) - stress_before,
		"enemy_block_delta":int(battle.enemy_block) - enemy_block_before,
		"attack_power_delta":int(run.attack_power) - attack_power_before,
		"phase_shifted":phase_shifted,
		"phase_name":str(phase.get("name", "")) if phase_shifted else ""}
	if int(battle.enemy_hp) <= 0:
		run["battle"] = battle
		var victory := _finish_battle(state, dungeon, run, "victory")
		victory["feedback"] = feedback
		return victory
	if int(run.hp) <= 0:
		run["battle"] = battle
		var defeat := _finish_battle(state, dungeon, run, "defeat")
		defeat["feedback"] = feedback
		return defeat
	run["battle"] = battle
	dungeon["run"] = run
	state["dungeon"] = dungeon
	return {"ok": true, "code": "card_played", "card": card, "battle": battle, "run": run,
		"feedback":feedback}


static func end_turn(state: Dictionary) -> Dictionary:
	var dungeon := normalize(state)
	if not bool(dungeon.active):
		return {"ok": false, "code": "no_active_dungeon"}
	var run: Dictionary = dungeon.run.duplicate(true)
	var battle: Dictionary = run.battle
	if battle.is_empty() or str(battle.get("outcome", "")) != "active":
		return {"ok": false, "code": "no_dungeon_battle"}
	var player_hp_before := int(run.hp)
	var stress_before := int(run.stress)
	var enemy_block_before := int(battle.enemy_block)
	var attack_power_before := int(run.attack_power)
	var guard_power_before := int(run.guard_power)
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
	_apply_trait_end_turn(run, battle, intent)
	var discard: Array = battle.discard_pile
	for card_value in (battle.hand as Array): discard.append(card_value)
	battle["discard_pile"] = discard
	battle["hand"] = []
	battle["player_block"] = 0
	battle["enemy_weak"] = maxi(0, int(battle.enemy_weak) - 1)
	battle["cards_played_turn"] = 0
	battle["trait_triggered_turn"] = false
	battle["last_source_kind"] = ""
	battle["turn"] = int(battle.turn) + 1
	var feedback := {"kind":"enemy", "intent":intent, "intent_name":intent_label(intent),
		"damage":damage, "hp_delta":int(run.hp) - player_hp_before,
		"stress_delta":int(run.stress) - stress_before,
		"enemy_block_delta":int(battle.enemy_block) - enemy_block_before,
		"attack_power_delta":int(run.attack_power) - attack_power_before,
		"guard_power_delta":int(run.guard_power) - guard_power_before,
		"heart_awakened":false, "heart_name":""}
	if int(run.hp) <= 0:
		run["battle"] = battle
		var defeat := _finish_battle(state, dungeon, run, "defeat")
		defeat["feedback"] = feedback
		return defeat
	if int(battle.turn) > MAX_TURNS:
		run["battle"] = battle
		var timeout := _finish_battle(state, dungeon, run, "defeat")
		timeout["feedback"] = feedback
		return timeout
	var heart_penalty: Dictionary = {}
	if int(run.stress) >= 100:
		heart_penalty = _awaken_heart_demon(run, battle)
	var cycle: Array = battle.intent_cycle
	battle["intent_index"] = (int(battle.intent_index) + 1) % cycle.size()
	battle["intent"] = str(cycle[int(battle.intent_index)])
	battle["energy"] = maxi(0, energy_cap(battle) - int(heart_penalty.get("energy_loss", 0)))
	_draw_cards(state, battle, 5)
	feedback["hp_delta"] = int(run.hp) - player_hp_before
	feedback["stress_delta"] = int(run.stress) - stress_before
	feedback["enemy_block_delta"] = int(battle.enemy_block) - enemy_block_before
	feedback["attack_power_delta"] = int(run.attack_power) - attack_power_before
	feedback["guard_power_delta"] = int(run.guard_power) - guard_power_before
	feedback["heart_awakened"] = bool(heart_penalty.get("heart_awakened", false))
	feedback["heart_name"] = str(heart_penalty.get("heart_name", ""))
	run["battle"] = battle
	dungeon["run"] = run
	state["dungeon"] = dungeon
	return {"ok": true, "code": "dungeon_turn_ended", "battle": battle, "run": run,
		"feedback":feedback}


static func _awaken_heart_demon(run: Dictionary, battle: Dictionary) -> Dictionary:
	var heart := heart_demon_for_era(str(run.get("era_id", "classical")))
	var penalty: Dictionary = (heart.get("penalty", {}) as Dictionary).duplicate(true)
	var copies := clampi(int(penalty.get("copies", 1)), 1, 3)
	var deck: Array = run.deck
	var discard: Array = battle.discard_pile
	for _index in range(copies):
		var curse := _new_card(run, str(heart.card_id), "heart", str(heart.source_name))
		discard.append(curse)
		if deck.size() >= MAX_DECK:
			deck.pop_front()
		deck.append(curse.duplicate(true))
	battle["discard_pile"] = discard
	run["deck"] = deck
	var hp_loss := mini(maxi(0, int(run.hp) - 1), maxi(0, int(penalty.get("hp_loss", 0))))
	if hp_loss > 0: run["hp"] = int(run.hp) - hp_loss
	var attack_loss := mini(int(run.attack_power), maxi(0, int(penalty.get("attack_loss", 0))))
	if attack_loss > 0: run["attack_power"] = int(run.attack_power) - attack_loss
	var guard_loss := mini(int(run.guard_power), maxi(0, int(penalty.get("guard_loss", 0))))
	if guard_loss > 0: run["guard_power"] = int(run.guard_power) - guard_loss
	var enemy_block := maxi(0, int(penalty.get("enemy_block", 0)))
	if enemy_block > 0: battle["enemy_block"] = int(battle.enemy_block) + enemy_block
	run["stress"] = clampi(int(heart.get("recovery", 60)), 0, 99)
	_append_log(run, "%s显化，%d张心障混入能力循环。%s" % [
		str(card_definition(str(heart.card_id)).name), copies, str(heart.awakening)])
	penalty["heart_awakened"] = true
	penalty["heart_name"] = str(card_definition(str(heart.card_id)).name)
	return penalty


static func _apply_trait_after_card(run: Dictionary, battle: Dictionary, card: Dictionary,
		damage: int) -> void:
	var rule: Dictionary = battle.get("trait", {})
	var trait_id := str(rule.get("id", ""))
	var value := maxi(0, int(rule.get("value", 0)))
	var phase: Dictionary = battle.get("phase", {})
	var phase_active := bool(battle.get("phase_active", false))
	var phase_id := str(phase.get("id", "")) if phase_active else ""
	var phase_value := maxi(0, int(phase.get("value", 0)))
	var played := int(battle.get("cards_played_turn", 0))
	var source_kind := str(card.get("source_kind", "unknown"))
	if trait_id == "zero_cost_pressure" and int(card_definition(str(card.card_id)).get("cost", 0)) == 0:
		run["stress"] = mini(100, int(run.stress) + value)
		_append_log(run, "无偿能力触发炉城禁令，心魔压力+%d。" % value)
	elif trait_id == "causal_checksum" and source_kind == str(battle.get("last_source_kind", "")):
		run["stress"] = mini(100, int(run.stress) + value)
		_append_log(run, "连续的同源能力未通过因果校验，心魔压力+%d。" % value)
	elif trait_id == "salvage_shell" and not bool(battle.get("trait_triggered_battle", false)) and \
			int(battle.enemy_hp) * 2 <= int(battle.enemy_max_hp):
		battle["enemy_block"] = int(battle.enemy_block) + value
		battle["trait_triggered_battle"] = true
		_append_log(run, "拾荒记忆聚成覆甲，敌方护体+%d。" % value)
	elif trait_id == "upgrade_censure" and int(card.get("upgrade", 0)) > 0 and \
			not bool(battle.get("trait_triggered_turn", false)):
		run["stress"] = mini(100, int(run.stress) + value)
		battle["trait_triggered_turn"] = true
		_append_log(run, "强化器痕被天册追责，心魔压力+%d。" % value)
	elif trait_id == "mirror_rebuke" and damage > 0 and (phase_id == "mirror_unbound" or \
			not bool(battle.get("trait_triggered_turn", false))):
		var reflected_value := phase_value if phase_id == "mirror_unbound" else value
		var reflected := mini(int(run.hp), reflected_value)
		run["hp"] = maxi(0, int(run.hp) - reflected)
		battle["trait_triggered_turn"] = true
		_append_log(run, "镜身照返沿灵诀反噬，你失去%d点气血。" % reflected)
	elif trait_id == "furnace_overload" and played == (2 if phase_id == "redline" else 3):
		var overload := phase_value if phase_id == "redline" else value
		run["stress"] = mini(100, int(run.stress) + overload)
		_append_log(run, "连续施法令炉压越线，心魔压力+%d。" % overload)
	elif trait_id == "memory_fork" and played <= (2 if phase_id == "future_merge" else 1):
		var copied := _new_card(run, str(card.card_id), "trait", "道网复制·%s" % str(card.get("source_name", "能力")))
		var discard: Array = battle.discard_pile
		discard.append(copied)
		battle["discard_pile"] = discard
		var fork_stress := phase_value if phase_id == "future_merge" else value
		run["stress"] = mini(100, int(run.stress) + fork_stress)
		_append_log(run, "记忆分叉复制了%s，心魔压力+%d。" % [
			str(card_definition(str(card.card_id)).name), fork_stress])
	battle["last_source_kind"] = source_kind


static func _apply_trait_end_turn(run: Dictionary, battle: Dictionary, intent: String) -> void:
	var rule: Dictionary = battle.get("trait", {})
	var trait_id := str(rule.get("id", ""))
	var value := maxi(0, int(rule.get("value", 0)))
	var phase: Dictionary = battle.get("phase", {})
	var phase_id := str(phase.get("id", "")) if bool(battle.get("phase_active", false)) else ""
	var phase_value := maxi(0, int(phase.get("value", 0)))
	if trait_id == "oath_barrier":
		battle["enemy_block"] = int(battle.enemy_block) + value
		_append_log(run, "守誓石障复原，敌方护体+%d。" % value)
	elif trait_id == "breath_interest" and int(battle.energy) > 0:
		var interest := int(battle.energy) * value
		run["stress"] = mini(100, int(run.stress) + interest)
		_append_log(run, "未用灵息被契约计息，心魔压力+%d。" % interest)
	if trait_id == "black_rain_erosion":
		var eroded := mini(int(run.hp), phase_value if phase_id == "rain_deluge" else value)
		run["hp"] = maxi(0, int(run.hp) - eroded)
		_append_log(run, "黑雨穿透护体，额外侵蚀%d点气血。" % eroded)
	elif trait_id == "heavenly_decree" and intent == "guard":
		run["stress"] = mini(100, int(run.stress) + value)
		_append_log(run, "天册敕令在结界中落印，心魔压力+%d。" % value)
	if phase_id == "total_collection":
		run["stress"] = mini(100, int(run.stress) + phase_value)
		_append_log(run, "全额追缴越过护体，心魔压力+%d。" % phase_value)
	elif phase_id == "blank_edict":
		run["stress"] = mini(100, int(run.stress) + phase_value)
		_append_log(run, "无字天敕随敌方行动落印，心魔压力+%d。" % phase_value)


static func _activate_phase_if_needed(run: Dictionary, battle: Dictionary) -> void:
	if str(battle.get("rank", "")) != "boss" or bool(battle.get("phase_active", false)):
		return
	var phase: Dictionary = battle.get("phase", {})
	if phase.is_empty():
		return
	var threshold_hp := maxi(1, int(battle.enemy_max_hp) * int(phase.get("threshold", 50)) / 100)
	if int(battle.enemy_hp) > threshold_hp:
		return
	battle["enemy_hp"] = threshold_hp
	battle["phase_active"] = true
	battle["phase_turn"] = int(battle.get("turn", 1))
	var phase_intents: Array = phase.get("intents", [])
	if not phase_intents.is_empty():
		battle["intent_cycle"] = phase_intents.duplicate()
		battle["intent_index"] = 0
		battle["intent"] = str(phase_intents[0])
	_append_log(run, "%s破开第一相，显露%s：%s" % [str(battle.enemy_name), str(phase.name),
		str(phase.description)])


static func combat_rule_title(battle: Dictionary) -> String:
	return "首领法则" if str(battle.get("rank", "")) == "boss" else "精英被动"


static func energy_cap(battle: Dictionary) -> int:
	var boss_rule: Dictionary = battle.get("trait", {})
	if str(boss_rule.get("id", "")) == "breath_tax":
		return maxi(1, STARTING_ENERGY - int(boss_rule.get("value", 1)))
	return STARTING_ENERGY


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


static func route_definition(era_id: String, node_type: String) -> Dictionary:
	var all_routes: Dictionary = load_definitions().get("era_routes", {})
	var era_routes: Dictionary = all_routes.get(era_id, all_routes.get("classical", {}))
	var node_value: Variant = era_routes.get(node_type, {})
	if not node_value is Dictionary:
		return {}
	var node: Dictionary = (node_value as Dictionary).duplicate(true)
	node["type"] = node_type
	return node


static func boss_trait_for_era(era_id: String) -> Dictionary:
	var enemies: Dictionary = load_definitions().get("era_enemies", {})
	var era: Dictionary = enemies.get(era_id, enemies.get("classical", {}))
	var boss_value: Variant = (era.get("boss", {}) as Dictionary).get("trait", {})
	return (boss_value as Dictionary).duplicate(true) if boss_value is Dictionary else {}


static func elite_trait_for_era(era_id: String) -> Dictionary:
	var enemies: Dictionary = load_definitions().get("era_enemies", {})
	var era: Dictionary = enemies.get(era_id, enemies.get("classical", {}))
	var elite_value: Variant = (era.get("elite", {}) as Dictionary).get("trait", {})
	return (elite_value as Dictionary).duplicate(true) if elite_value is Dictionary else {}


static func boss_phase_for_era(era_id: String) -> Dictionary:
	var enemies: Dictionary = load_definitions().get("era_enemies", {})
	var era: Dictionary = enemies.get(era_id, enemies.get("classical", {}))
	var phase_value: Variant = (era.get("boss", {}) as Dictionary).get("phase", {})
	return (phase_value as Dictionary).duplicate(true) if phase_value is Dictionary else {}


static func heart_demon_for_era(era_id: String) -> Dictionary:
	var hearts_value: Variant = load_definitions().get("heart_demons", {})
	if not hearts_value is Dictionary:
		return {}
	var hearts: Dictionary = hearts_value
	var heart_value: Variant = hearts.get(era_id, hearts.get("classical", {}))
	return (heart_value as Dictionary).duplicate(true) if heart_value is Dictionary else {}


static func intent_label(intent: String) -> String:
	return str({"strike": "迅击", "heavy": "蓄势重击", "guard": "结界护体", "stress": "心魔低语"}.get(intent, "未知意图"))


static func _starting_deck(state: Dictionary) -> Dictionary:
	var run_seed := {"card_counter": 0}
	var profile := _build_ability_profile(state)
	var deck: Array = []
	var weapon_source := str(profile.weapon_name)
	for index in range(3):
		var card_id := "weapon_resonance" if index == 0 and bool(profile.weapon_equipped) else "sword_cut"
		deck.append(_new_card(run_seed, card_id, "weapon", weapon_source))
	var armor_source := str(profile.armor_name)
	for index in range(3):
		var card_id := "armor_circulation" if index == 0 and bool(profile.armor_equipped) else "jade_guard"
		deck.append(_new_card(run_seed, card_id, "armor", armor_source))
	deck.append(_new_card(run_seed, "qi_breath", "realm", str(profile.realm_name)))
	deck.append(_new_card(run_seed, str(PATH_CARDS[profile.primary_path_id]), "path",
		str(profile.primary_source_name), _bond_upgrade(profile, str(profile.primary_path_id))))
	deck.append(_new_card(run_seed, str(PATH_CARDS[profile.secondary_path_id]), "path",
		str(profile.secondary_source_name), _bond_upgrade(profile, str(profile.secondary_path_id))))
	deck.append(_new_card(run_seed, "realm_manifestation", "realm", str(profile.realm_name)))
	deck.append(_new_card(run_seed, "relic_cycle", "relic", str(profile.relic_name)))
	if not str(profile.jade_weapon_name).is_empty():
		deck.append(_new_card(run_seed, str(profile.jade_card_id), "jade",
			str(profile.jade_weapon_name)))
	if not str(profile.memory_name).is_empty():
		deck.append(_new_card(run_seed, "past_life_echo", "memory", str(profile.memory_name)))
	for ability_value in (profile.get("story_abilities", []) as Array):
		var ability: Dictionary = ability_value
		deck.append(_new_card(run_seed, str(ability.card_id), "story", str(ability.source_name),
			int(ability.get("upgrade", 0))))
	return {"deck": deck, "profile": profile, "card_counter": int(run_seed.card_counter)}


static func ability_profile_label(run_or_profile: Dictionary) -> String:
	var profile_value: Variant = run_or_profile.get("ability_profile", run_or_profile)
	var profile: Dictionary = profile_value if profile_value is Dictionary else {}
	var primary_name := str(PATH_NAMES.get(str(profile.get("primary_path_id", "insight")), "未定"))
	var primary_source := str(profile.get("primary_source_name", primary_name))
	var secondary_name := str(PATH_NAMES.get(str(profile.get("secondary_path_id", "creation")), "未定"))
	var secondary_source := str(profile.get("secondary_source_name", secondary_name))
	var parts: Array[String] = [
		"境界·%s" % str(profile.get("realm_name", "未显")),
		"主道·%s%s" % [primary_name, "·%s" % primary_source if primary_source != primary_name else ""],
		"次道·%s%s" % [secondary_name, "·%s" % secondary_source if secondary_source != secondary_name else ""],
		"器·%s" % str(profile.get("weapon_name", "本命攻法")),
	]
	if not str(profile.get("jade_weapon_name", "")).is_empty():
		parts.append("玉兵·%s" % str(profile.jade_weapon_name))
	if not str(profile.get("memory_name", "")).is_empty():
		parts.append("前世·%s" % str(profile.memory_name))
	var story_abilities_value: Variant = profile.get("story_abilities", [])
	if story_abilities_value is Array and not (story_abilities_value as Array).is_empty():
		var arc_names: Array[String] = []
		for ability_value in (story_abilities_value as Array):
			if ability_value is Dictionary: arc_names.append(str((ability_value as Dictionary).get("arc_name", "定局")))
		parts.append("定局·%s" % "/".join(arc_names))
	if int(profile.get("bond_relation", 0)) > 0 and \
			(str(profile.get("primary_path_id", "")) == "bonds" or str(profile.get("secondary_path_id", "")) == "bonds"):
		parts.append("羁绊·%s%d" % [str(profile.get("bond_name", "故人")), int(profile.bond_relation)])
	return "  |  ".join(parts)


static func _build_ability_profile(state: Dictionary) -> Dictionary:
	var player: Dictionary = state.get("player", {})
	var ranked_paths := _ranked_paths(player.get("path", {}))
	var primary: Dictionary = ranked_paths[0]
	var secondary: Dictionary = ranked_paths[1]
	var weapon := _equipped_source(state, "weapon", "本命攻法")
	var armor := _equipped_source(state, "armor", "护体根基")
	var relic := _equipped_source(state, "relic", "黑白轮回玉")
	var bond := _strongest_bond(state)
	var story_abilities := _story_ability_projections(state)
	var jade := AchievementSystemScript.current_weapon(state)
	var jade_card_id := ""
	if not jade.is_empty():
		jade_card_id = str(JADE_STYLE_CARDS.get(str(jade.style), "mind_mirror"))
	var echoes_value: Variant = (state.get("legacy", {}) as Dictionary).get("inherited_echoes", [])
	var echoes: Array = echoes_value if echoes_value is Array else []
	var memory_name := ""
	if not echoes.is_empty() and echoes[0] is Dictionary:
		memory_name = str((echoes[0] as Dictionary).get("name", "前世残响")).left(32)
	return {
		"realm_name": "%s %d层" % [str(player.get("realm", "凡人")), int(player.get("level", 1))],
		"primary_path_id": str(primary.id),
		"primary_path_score": int(primary.score),
		"primary_source_name": _path_source_name(str(primary.id), bond),
		"secondary_path_id": str(secondary.id),
		"secondary_path_score": int(secondary.score),
		"secondary_source_name": _path_source_name(str(secondary.id), bond),
		"weapon_name": str(weapon.name), "weapon_equipped": bool(weapon.equipped),
		"armor_name": str(armor.name), "armor_equipped": bool(armor.equipped),
		"relic_name": str(relic.name),
		"jade_weapon_name": str(jade.get("name", "")).left(32),
		"jade_card_id": jade_card_id,
		"memory_name": memory_name,
		"bond_name": str(bond.get("name", "")), "bond_relation": int(bond.get("relation", 0)),
		"bond_role": str(bond.get("role", "")), "story_abilities": story_abilities,
	}


static func _ranked_paths(path_value: Variant) -> Array:
	var path: Dictionary = path_value if path_value is Dictionary else {}
	var ranked: Array = []
	for path_id in PATH_IDS:
		ranked.append({"id": path_id, "score": int(path.get(path_id, 0)),
			"tie": PATH_TIE_ORDER.find(path_id)})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary):
		if int(left.score) == int(right.score):
			return int(left.tie) < int(right.tie)
		return int(left.score) > int(right.score))
	return ranked


static func _path_source_name(path_id: String, bond: Dictionary) -> String:
	if path_id == "bonds" and not str(bond.get("name", "")).is_empty():
		return str(bond.name)
	return str(PATH_NAMES.get(path_id, path_id))


static func _strongest_bond(state: Dictionary) -> Dictionary:
	var world_value: Variant = state.get("world", {})
	var world: Dictionary = world_value if world_value is Dictionary else {}
	var npcs_value: Variant = world.get("npcs", [])
	if not npcs_value is Array:
		return {"name":"", "relation":0, "role":""}
	var best_relation := 0
	var best: Dictionary = {"name":"", "relation":0, "role":""}
	for npc_value in (npcs_value as Array):
		if not npc_value is Dictionary:
			continue
		var npc: Dictionary = npc_value
		var relation := int(npc.get("player_relation", 0))
		if bool(npc.get("alive", true)) and relation > best_relation:
			best_relation = relation
			best = {"name":str(npc.get("name", "")).left(24), "relation":clampi(relation, 0, 100),
				"role":str(npc.get("role", npc.get("stance", "故人"))).left(24)}
	return best


static func story_projection_for_resolution(arc_id: String, resolution: String) -> Dictionary:
	var projections_value: Variant = load_definitions().get("story_projections", {})
	if not projections_value is Dictionary:
		return {}
	var arc_value: Variant = (projections_value as Dictionary).get(arc_id, {})
	if not arc_value is Dictionary:
		return {}
	var arc: Dictionary = arc_value
	var resolutions_value: Variant = arc.get("resolutions", {})
	if not resolutions_value is Dictionary:
		return {}
	var card_id := str((resolutions_value as Dictionary).get(resolution, ""))
	if card_id.is_empty():
		return {}
	return {"arc_id":arc_id, "arc_name":str(arc.get("name", arc_id)),
		"resolution":resolution, "card_id":card_id,
		"source_name":"%s·%s" % [str(arc.get("name", arc_id)), resolution]}


static func _story_ability_projections(state: Dictionary) -> Array:
	var story_value: Variant = state.get("story", {})
	var story: Dictionary = story_value if story_value is Dictionary else {}
	var legacies_value: Variant = story.get("arc_legacies", {})
	var legacies: Dictionary = legacies_value if legacies_value is Dictionary else {}
	var echoes_value: Variant = story.get("arc_echoes", {})
	var echoes: Dictionary = echoes_value if echoes_value is Dictionary else {}
	var result: Array = []
	for arc_id in STORY_ARC_IDS:
		var resolution := str(legacies.get(arc_id, ""))
		if resolution.is_empty():
			continue
		var upgrade := 0
		var echo_value: Variant = echoes.get(arc_id, {})
		if echo_value is Dictionary:
			var echo_resolution := str((echo_value as Dictionary).get("resolution", ""))
			if not echo_resolution.is_empty():
				resolution = echo_resolution
				upgrade = 1
		var projection := story_projection_for_resolution(arc_id, resolution)
		if projection.is_empty():
			continue
		projection["upgrade"] = upgrade
		result.append(projection)
	return result


static func _bond_upgrade(profile: Dictionary, path_id: String) -> int:
	if path_id != "bonds":
		return 0
	var relation := int(profile.get("bond_relation", 0))
	if relation >= 75: return 2
	if relation >= 40: return 1
	return 0


static func _equipped_source(state: Dictionary, slot: String, fallback: String) -> Dictionary:
	var inventory := ItemSystemScript.normalize(state)
	var reference := str((inventory.equipped as Dictionary).get("%s_id" % slot, ""))
	if reference.is_empty():
		return {"name": fallback, "equipped": false}
	if reference == "black_white_jade":
		return {"name": "黑白轮回玉", "equipped": true}
	for entry_value in (inventory.items as Array):
		var entry: Dictionary = entry_value
		if str(entry.get("instance_id", "")) == reference or str(entry.get("item_id", "")) == reference:
			return {"name": ItemSystemScript.display_name(entry).left(32), "equipped": true}
	return {"name": fallback, "equipped": false}


static func _generate_route(state: Dictionary, run: Dictionary) -> void:
	var depth := int(run.depth)
	var max_depth := int(run.max_depth)
	if depth >= max_depth - 1:
		run["route_choices"] = [route_definition(str(run.era_id), "boss")]
		return
	var pools := [["combat", "memory"], ["combat", "rest"], ["elite", "forge"]]
	var pool: Array = pools[mini(depth, pools.size() - 1)]
	if _roll(state, 0, 1) == 1: pool.reverse()
	var choices: Array = []
	for node_type in pool:
		choices.append(route_definition(str(run.era_id), str(node_type)))
	run["route_choices"] = choices


static func _start_battle(state: Dictionary, run: Dictionary, rank: String) -> Dictionary:
	var enemies: Dictionary = (load_definitions().era_enemies as Dictionary).get(str(run.era_id), {})
	var source: Dictionary = enemies.get(rank, enemies.get("normal", {}))
	var realm := int((state.get("player", {}) as Dictionary).get("realm_index", 0))
	var scale := 100 + realm * 12 + int(run.depth) * 12
	var deck: Array = run.deck.duplicate(true)
	_shuffle(state, deck)
	var rule_value: Variant = source.get("trait", {})
	var rule: Dictionary = (rule_value as Dictionary).duplicate(true) if rule_value is Dictionary else {}
	var phase_value: Variant = source.get("phase", {})
	var phase: Dictionary = (phase_value as Dictionary).duplicate(true) if phase_value is Dictionary else {}
	var battle := {"outcome":"active", "rank":rank, "turn":1, "energy":STARTING_ENERGY,
		"player_block":0, "enemy_name":str(source.name), "enemy_hp":maxi(20, int(source.hp) * scale / 100),
		"enemy_max_hp":maxi(20, int(source.hp) * scale / 100), "enemy_attack":maxi(4, int(source.attack) * scale / 100),
		"enemy_block":0, "enemy_weak":0, "intent_cycle":(source.intents as Array).duplicate(),
		"intent_index":0, "intent":str((source.intents as Array)[0]), "draw_pile":deck,
		"discard_pile":[], "exhausted":[], "hand":[], "trait":rule, "phase":phase,
		"phase_active":false, "phase_turn":0, "cards_played_turn":0,
		"trait_triggered_turn":false, "trait_triggered_battle":false, "last_source_kind":""}
	if str(rule.get("id", "")) == "oath_barrier":
		battle["enemy_block"] = maxi(0, int(rule.get("value", 0)))
	battle["energy"] = energy_cap(battle)
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


static func _resolve_noncombat_node(state: Dictionary, run: Dictionary, node: Dictionary) -> void:
	var node_type := str(node.get("type", "memory"))
	_append_log(run, "%s：%s" % [str(node.get("name", "无名道标")),
		str(node.get("description", "空阙没有留下解释。"))])
	if node_type == "rest":
		var notes := _apply_node_effects(run, node.get("effects", {}))
		_append_log(run, "休整落定：%s。" % "，".join(notes))
	elif node_type == "forge":
		var deck: Array = run.deck
		var index := _roll(state, 0, deck.size() - 1)
		var card: Dictionary = deck[index]
		card["upgrade"] = mini(2, int(card.get("upgrade", 0)) + 1)
		deck[index] = card
		run["deck"] = deck
		var notes := _apply_node_effects(run, node.get("effects", {}))
		var suffix := "；%s" % "，".join(notes) if not notes.is_empty() else ""
		_append_log(run, "%s被刻入一道强化器痕%s。" % [str(card_definition(str(card.card_id)).name), suffix])
	else:
		var candidates := _memory_candidates(run)
		var projection: Dictionary = candidates[_roll(state, 0, candidates.size() - 1)]
		var card := _new_card(run, str(projection.card_id), str(projection.source_kind),
			str(projection.source_name), int(projection.get("upgrade", 0)))
		var deck: Array = run.deck
		if deck.size() < MAX_DECK: deck.append(card)
		run["deck"] = deck
		var notes := _apply_node_effects(run, node.get("effects", {}))
		var suffix := "；%s" % "，".join(notes) if not notes.is_empty() else ""
		_append_log(run, "此地从%s中映出%s%s。" % [str(card.source_name),
			str(card_definition(str(card.card_id)).name), suffix])


static func _apply_node_effects(run: Dictionary, effects_value: Variant) -> Array[String]:
	var effects: Dictionary = effects_value if effects_value is Dictionary else {}
	var notes: Array[String] = []
	var heal_percent := maxi(0, int(effects.get("heal_percent", 0)))
	if heal_percent > 0:
		var healed := mini(int(run.max_hp) - int(run.hp), maxi(1, int(run.max_hp) * heal_percent / 100))
		run["hp"] = int(run.hp) + healed
		notes.append("气血+%d" % healed)
	var calm := maxi(0, int(effects.get("calm", 0)))
	if calm > 0:
		var reduced := mini(int(run.stress), calm)
		run["stress"] = int(run.stress) - reduced
		notes.append("压力-%d" % reduced)
	var stress := maxi(0, int(effects.get("stress", 0)))
	if stress > 0:
		run["stress"] = mini(100, int(run.stress) + stress)
		notes.append("压力+%d" % stress)
	var hp_cost := maxi(0, int(effects.get("hp_cost", 0)))
	if hp_cost > 0:
		var paid := mini(maxi(0, int(run.hp) - 1), hp_cost)
		run["hp"] = int(run.hp) - paid
		notes.append("气血-%d" % paid)
	var attack_gain := maxi(0, int(effects.get("attack_power", 0)))
	if attack_gain > 0:
		run["attack_power"] = mini(100000, int(run.attack_power) + attack_gain)
		notes.append("器诀+%d" % attack_gain)
	var guard_gain := maxi(0, int(effects.get("guard_power", 0)))
	if guard_gain > 0:
		run["guard_power"] = mini(100000, int(run.guard_power) + guard_gain)
		notes.append("护诀+%d" % guard_gain)
	if notes.is_empty():
		notes.append("气机未改")
	return notes


static func _memory_candidates(run: Dictionary) -> Array:
	var profile: Dictionary = run.get("ability_profile", {})
	var candidates: Array = [
		{"card_id": str(PATH_CARDS.get(str(profile.get("primary_path_id", "insight")), "cause_trace")),
			"source_kind": "path", "source_name": str(profile.get("primary_source_name", "明悟")),
			"upgrade": _bond_upgrade(profile, str(profile.get("primary_path_id", "insight")))},
		{"card_id": str(PATH_CARDS.get(str(profile.get("secondary_path_id", "creation")), "forge_edge")),
			"source_kind": "path", "source_name": str(profile.get("secondary_source_name", "造化")),
			"upgrade": _bond_upgrade(profile, str(profile.get("secondary_path_id", "creation")))},
		{"card_id": "relic_cycle", "source_kind": "relic",
			"source_name": str(profile.get("relic_name", "黑白轮回玉"))},
	]
	if bool(profile.get("weapon_equipped", false)):
		candidates.append({"card_id": "weapon_resonance", "source_kind": "weapon",
			"source_name": str(profile.get("weapon_name", "本命攻法"))})
	if not str(profile.get("memory_name", "")).is_empty():
		candidates.append({"card_id": "past_life_echo", "source_kind": "memory",
			"source_name": str(profile.memory_name)})
	for ability_value in (profile.get("story_abilities", []) as Array):
		if ability_value is Dictionary:
			var ability: Dictionary = ability_value
			candidates.append({"card_id":str(ability.card_id), "source_kind":"story",
				"source_name":str(ability.source_name), "upgrade":int(ability.get("upgrade", 0))})
	return candidates


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
	run["guard_power"] = clampi(int(run.get("guard_power", 0)), 0, 100000)
	run["ability_profile"] = _normalize_ability_profile(run.get("ability_profile", {}))
	run["deck"] = _normalize_cards(run.get("deck", []))
	run["card_counter"] = maxi(int(run.get("card_counter", 0)), (run.deck as Array).size())
	run["route_choices"] = _bounded_array(run.get("route_choices", []), 3)
	run["log"] = _bounded_array(run.get("log", []), MAX_LOG)
	var battle_value: Variant = run.get("battle", {})
	var battle: Dictionary = battle_value.duplicate(true) if battle_value is Dictionary else {}
	if not battle.is_empty():
		battle["trait"] = _normalize_trait(battle.get("trait", {}))
		battle["phase"] = _normalize_phase(battle.get("phase", {}))
		battle["phase_active"] = bool(battle.get("phase_active", false)) and not (battle.phase as Dictionary).is_empty()
		battle["phase_turn"] = clampi(int(battle.get("phase_turn", 0)), 0, MAX_TURNS)
		battle["cards_played_turn"] = clampi(int(battle.get("cards_played_turn", 0)), 0, MAX_HAND)
		battle["trait_triggered_turn"] = bool(battle.get("trait_triggered_turn", false))
		battle["trait_triggered_battle"] = bool(battle.get("trait_triggered_battle", false))
		battle["last_source_kind"] = str(battle.get("last_source_kind", "")).left(32)
		run["battle"] = battle
	else:
		run["battle"] = {}
	return run


static func _normalize_trait(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var rule: Dictionary = value
	var trait_id := str(rule.get("id", ""))
	if not SUPPORTED_ENEMY_TRAITS.has(trait_id):
		return {}
	return {"id":trait_id, "name":str(rule.get("name", "战斗规则")).left(32),
		"description":str(rule.get("description", "")).left(160),
		"value":clampi(int(rule.get("value", 1)), 1, 1000)}


static func _normalize_phase(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var source: Dictionary = value
	var phase_id := str(source.get("id", ""))
	if not SUPPORTED_BOSS_PHASES.has(phase_id):
		return {}
	var intents: Array = []
	var intents_value: Variant = source.get("intents", [])
	if intents_value is Array:
		for intent_value in (intents_value as Array):
			var intent := str(intent_value)
			if SUPPORTED_INTENTS.has(intent): intents.append(intent)
	if intents.is_empty():
		return {}
	return {"id":phase_id, "name":str(source.get("name", "未显之相")).left(32),
		"description":str(source.get("description", "")).left(160),
		"threshold":clampi(int(source.get("threshold", 50)), 1, 99),
		"value":clampi(int(source.get("value", 1)), 1, 1000), "intents":intents}


static func _normalize_cards(value: Variant) -> Array:
	var result: Array = []
	var seen_uids := {}
	if value is Array:
		for card_value in (value as Array):
			if card_value is Dictionary and not card_definition(str((card_value as Dictionary).get("card_id", ""))).is_empty():
				var uid := str((card_value as Dictionary).get("uid", "")).left(64)
				if uid.is_empty() or seen_uids.has(uid):
					uid = "card_legacy_%06d" % (result.size() + 1)
				seen_uids[uid] = true
				result.append({"uid":uid,
					"card_id":str((card_value as Dictionary).card_id),
					"upgrade":clampi(int((card_value as Dictionary).get("upgrade", 0)), 0, 2),
					"source_kind":str((card_value as Dictionary).get("source_kind", "foundation")).left(24),
					"source_name":str((card_value as Dictionary).get("source_name", "既有功法")).left(48)})
				if result.size() >= MAX_DECK: break
	return result


static func _normalize_ability_profile(value: Variant) -> Dictionary:
	var profile: Dictionary = value.duplicate(true) if value is Dictionary else {}
	return {
		"realm_name": str(profile.get("realm_name", "未显境界")).left(48),
		"primary_path_id": str(profile.get("primary_path_id", "insight")),
		"primary_path_score": int(profile.get("primary_path_score", 0)),
		"primary_source_name": str(profile.get("primary_source_name", "明悟")).left(32),
		"secondary_path_id": str(profile.get("secondary_path_id", "creation")),
		"secondary_path_score": int(profile.get("secondary_path_score", 0)),
		"secondary_source_name": str(profile.get("secondary_source_name", "造化")).left(32),
		"weapon_name": str(profile.get("weapon_name", "本命攻法")).left(32),
		"weapon_equipped": bool(profile.get("weapon_equipped", false)),
		"armor_name": str(profile.get("armor_name", "护体根基")).left(32),
		"armor_equipped": bool(profile.get("armor_equipped", false)),
		"relic_name": str(profile.get("relic_name", "黑白轮回玉")).left(32),
		"jade_weapon_name": str(profile.get("jade_weapon_name", "")).left(32),
		"jade_card_id": str(profile.get("jade_card_id", "")).left(64),
		"memory_name": str(profile.get("memory_name", "")).left(32),
		"bond_name": str(profile.get("bond_name", "")).left(24),
		"bond_relation": clampi(int(profile.get("bond_relation", 0)), 0, 100),
		"bond_role": str(profile.get("bond_role", "")).left(24),
		"story_abilities": _normalize_story_abilities(profile.get("story_abilities", [])),
	}


static func _normalize_story_abilities(value: Variant) -> Array:
	var result: Array = []
	if not value is Array:
		return result
	for ability_value in (value as Array):
		if not ability_value is Dictionary:
			continue
		var ability: Dictionary = ability_value
		var arc_id := str(ability.get("arc_id", ""))
		var card_id := str(ability.get("card_id", ""))
		if not STORY_ARC_IDS.has(arc_id) or card_definition(card_id).is_empty():
			continue
		result.append({"arc_id":arc_id, "arc_name":str(ability.get("arc_name", arc_id)).left(24),
			"resolution":str(ability.get("resolution", "")).left(48), "card_id":card_id,
			"source_name":str(ability.get("source_name", "定局映照")).left(48),
			"upgrade":clampi(int(ability.get("upgrade", 0)), 0, 1)})
		if result.size() >= STORY_ARC_IDS.size(): break
	return result


static func _new_card(run: Dictionary, card_id: String, source_kind: String = "dungeon",
		source_name: String = "秘境映照", upgrade: int = 0) -> Dictionary:
	var counter := int(run.get("card_counter", 0)) + 1
	run["card_counter"] = counter
	return {"uid":"card_%06d" % counter, "card_id":card_id, "upgrade":clampi(upgrade, 0, 2),
		"source_kind":source_kind.left(24), "source_name":source_name.left(48)}


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
