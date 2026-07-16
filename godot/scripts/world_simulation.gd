class_name WorldSimulation
extends RefCounted

## Deterministic, data-only annual simulation for the persistent world.
##
## Every random draw is derived from world_seed and rng_cursor. The cursor is
## stored back on the state, so saves can resume the exact same timeline.

const SIMULATION_VERSION := 1
const MIN_FACTIONS := 3
const MIN_NPCS := 6
const MAX_FACTIONS := 8
const MAX_NPCS := 24
const MAX_HISTORY_ENTRIES := 128
const MAX_ANNUAL_SUMMARIES := 32
const MAX_ACTIVE_EVENTS := 16
const MAX_FACTION_ARCHIVE := 24
const MAX_NPC_ARCHIVE := 48
const MAX_WORLD_YEAR := 2000000000
const RNG_MASK := 0x7fffffff

const REALM_IDS := [
	"mortal", "qi_refining", "foundation", "golden_core", "nascent_soul",
	"spirit_severing", "void_refining", "unity", "tribulation", "mahayana",
	"half_immortal", "true_immortal", "heaven_immortal", "mystic_immortal",
	"golden_immortal", "immortal_lord", "immortal_king", "immortal_sovereign",
	"immortal_emperor", "dao_ancestor", "heavenly_dao",
]

const REALM_NAMES := [
	"凡人", "炼气", "筑基", "金丹", "元婴", "化神", "炼虚", "合体", "渡劫", "大乘",
	"半仙", "真仙", "天仙", "玄仙", "金仙", "仙君", "仙王", "仙尊", "仙帝", "道祖", "天道",
]

const ERA_RULES := {
	"classical": {"realm_cap": 7, "qi_bias": 1, "pressure_bias": 1},
	"steam": {"realm_cap": 9, "qi_bias": -1, "pressure_bias": 2},
	"star_network": {"realm_cap": 14, "qi_bias": 2, "pressure_bias": 2},
	"wasteland": {"realm_cap": 11, "qi_bias": -2, "pressure_bias": 3},
	"final_age": {"realm_cap": 6, "qi_bias": -3, "pressure_bias": 4},
	"immortal_dynasty": {"realm_cap": 19, "qi_bias": 3, "pressure_bias": 2},
}

const ERA_NAMES := {
	"classical": "古典修仙纪",
	"steam": "灵机蒸汽纪",
	"star_network": "星穹道网纪",
	"wasteland": "废土返道纪",
	"final_age": "末法裂变纪",
	"immortal_dynasty": "仙朝鼎盛纪",
}

const ERA_FACTIONS := {
	"classical": [
		{"id": "mirror_sword_court", "name": "镜湖剑庭", "stance": "order", "archetype": "sect"},
		{"id": "hundred_craft_league", "name": "百工盟", "stance": "creation", "archetype": "guild"},
		{"id": "wild_oath_clans", "name": "荒誓诸部", "stance": "freedom", "archetype": "clan"},
	],
	"steam": [
		{"id": "celestial_engine_bureau", "name": "天工机枢局", "stance": "order", "archetype": "bureau"},
		{"id": "red_furnace_union", "name": "赤炉同盟", "stance": "creation", "archetype": "union"},
		{"id": "cloud_rail_rangers", "name": "云轨游侠会", "stance": "freedom", "archetype": "rangers"},
	],
	"star_network": [
		{"id": "constellation_archive", "name": "星图总藏", "stance": "insight", "archetype": "archive"},
		{"id": "void_sail_consortium", "name": "虚舟商团", "stance": "ambition", "archetype": "consortium"},
		{"id": "free_signal_collective", "name": "自由灵讯体", "stance": "freedom", "archetype": "collective"},
	],
	"wasteland": [
		{"id": "last_spring_citadel", "name": "末泉城", "stance": "survival", "archetype": "citadel"},
		{"id": "relic_scavenger_covenant", "name": "拾遗契", "stance": "ambition", "archetype": "covenant"},
		{"id": "ashland_healers", "name": "灰原医盟", "stance": "compassion", "archetype": "healers"},
	],
	"final_age": [
		{"id": "last_lamp_monastery", "name": "守灯院", "stance": "order", "archetype": "monastery"},
		{"id": "silent_heaven_observers", "name": "寂天观测所", "stance": "insight", "archetype": "observatory"},
		{"id": "mortal_dawn_compact", "name": "凡曦公约", "stance": "defiance", "archetype": "compact"},
	],
	"immortal_dynasty": [
		{"id": "nine_heaven_court", "name": "九天仙朝", "stance": "order", "archetype": "dynasty"},
		{"id": "myriad_dao_academy", "name": "万道学宫", "stance": "insight", "archetype": "academy"},
		{"id": "unchained_immortal_isles", "name": "不系仙洲", "stance": "freedom", "archetype": "isles"},
	],
}

const ERA_NPC_NAMES := {
	"classical": ["沈照川", "陆听雪", "顾长风", "苏青梧", "裴砚", "闻人渡", "叶停云", "商无咎"],
	"steam": ["程火候", "林枢月", "沈铜雀", "陆鸣汽", "顾云轨", "苏炉青", "周铸星", "白衡"],
	"star_network": ["星遥", "弦七", "闻波", "镜零", "辰砂", "陆离光", "苏迭", "沈天线"],
	"wasteland": ["灰禾", "拾九", "泉生", "砾歌", "陆余火", "沈旧雨", "白药", "野渡"],
	"final_age": ["守灯", "观尘", "余昼", "末弦", "沈微明", "陆无钟", "苏凡曦", "白归夜"],
	"immortal_dynasty": ["玄阙", "瑶衡", "太微", "青帝子", "沈凌霄", "陆天章", "苏九真", "白无极"],
}

const NPC_STANCES := ["order", "compassion", "ambition", "insight", "creation", "defiance"]


static func initialize(state: Dictionary) -> Dictionary:
	var world := _ensure_world(state)
	var era_id := str(state.get("current_era_id", world.get("simulated_era_id", "classical")))
	if not ERA_RULES.has(era_id):
		era_id = "classical"
	var first_install := int(world.get("simulation_version", 0)) < SIMULATION_VERSION
	var factions := _normalize_factions(state, world, era_id)
	_ensure_faction_relations(state, factions)
	var npcs := _normalize_npcs(state, world, era_id, factions)
	_ensure_npc_relations(state, npcs)

	world["year"] = clampi(int(world.get("year", 1)), 1, MAX_WORLD_YEAR)
	world["age"] = clampi(int(world.get("age", 0)), 0, MAX_WORLD_YEAR)
	world["qi_tide"] = clampi(int(world.get("qi_tide", 50)), 0, 100)
	world["stability"] = clampi(int(world.get("stability", 65)), 0, 100)
	world["era_pressure"] = clampi(int(world.get("era_pressure", 0)), 0, 100)
	world["factions"] = factions
	world["npcs"] = npcs
	world["history"] = _bounded_history(world.get("history", []))
	world["annual_summaries"] = _bounded_array(world.get("annual_summaries", []), MAX_ANNUAL_SUMMARIES, true)
	world["active_events"] = _bounded_array(world.get("active_events", []), MAX_ACTIVE_EVENTS, true)
	world["simulation_version"] = SIMULATION_VERSION
	world["simulated_era_id"] = era_id

	if first_install:
		var faction_names: Array[String] = []
		for faction_value in factions:
			var faction: Dictionary = faction_value
			faction_names.append(str(faction.get("name", faction.get("id", "无名势力"))))
		_append_history(world, "第%d年，%s在同一片天地立下旗号；六位命运交汇者开始彼此留下痕迹。" % [
			int(world.year), "、".join(faction_names.slice(0, MIN_FACTIONS))])

	state["world"] = world
	return {
		"ok": true,
		"initialized": first_install,
		"era_id": era_id,
		"faction_count": factions.size(),
		"npc_count": npcs.size(),
		"rng_cursor": int(state.get("rng_cursor", 0)),
	}


static func advance_year(state: Dictionary) -> Dictionary:
	initialize(state)
	var world: Dictionary = state.world
	var era_id := str(world.get("simulated_era_id", "classical"))
	var rules: Dictionary = ERA_RULES.get(era_id, ERA_RULES.classical)
	var previous_qi := int(world.qi_tide)
	var previous_stability := int(world.stability)
	var previous_pressure := int(world.era_pressure)
	var year := mini(MAX_WORLD_YEAR, int(world.year) + 1)
	world["year"] = year
	world["age"] = mini(MAX_WORLD_YEAR, int(world.age) + 1)

	var qi_delta := _rand_range(state, -7, 7) + int(rules.get("qi_bias", 0))
	world["qi_tide"] = clampi(previous_qi + qi_delta, 0, 100)
	qi_delta = int(world.qi_tide) - previous_qi
	var pressure_delta := _rand_range(state, 0, 4) + int(rules.get("pressure_bias", 1))
	if previous_stability < 35:
		pressure_delta += 2
	elif previous_stability > 78:
		pressure_delta -= 1
	world["era_pressure"] = clampi(previous_pressure + pressure_delta, 0, 100)
	pressure_delta = int(world.era_pressure) - previous_pressure

	var factions: Array = world.factions
	var faction_changes := _advance_factions(state, factions, int(world.qi_tide), int(world.era_pressure))
	var npcs: Array = world.npcs
	var npc_changes := _advance_npcs(
		state, npcs, factions, year, int(world.qi_tide), previous_stability)
	var relation_balance := _average_faction_relation(factions)
	var deaths: Array = npc_changes.deaths
	var stability_delta := _rand_range(state, -5, 5) + int(relation_balance / 30.0) - deaths.size() * 3
	if int(world.era_pressure) >= 80:
		stability_delta -= 2
	elif int(world.era_pressure) <= 25:
		stability_delta += 1
	world["stability"] = clampi(previous_stability + stability_delta, 0, 100)
	stability_delta = int(world.stability) - previous_stability

	world["factions"] = factions
	world["npcs"] = npcs
	var dominant := _dominant_faction(factions)
	var summary := _build_summary(
		year, world, dominant, faction_changes, npc_changes,
		qi_delta, stability_delta, pressure_delta)
	world["last_year_summary"] = summary.duplicate(true)
	var summaries: Array = _bounded_array(world.get("annual_summaries", []), MAX_ANNUAL_SUMMARIES, true)
	summaries.append(summary.duplicate(true))
	while summaries.size() > MAX_ANNUAL_SUMMARIES:
		summaries.pop_front()
	world["annual_summaries"] = summaries
	_append_history(world, str(summary.detail))
	_update_active_events(world, summary)
	state["world"] = world
	return {"ok": true, "year": year, "summary": summary, "rng_cursor": int(state.rng_cursor)}


static func transition_era(state: Dictionary, target_era_id: String) -> Dictionary:
	var target_id := target_era_id.strip_edges()
	if not ERA_RULES.has(target_id):
		return {"ok": false, "changed": false, "code": "invalid_era", "target_era_id": target_id}
	initialize(state)
	var world: Dictionary = state.world
	var previous_id := str(world.get("simulated_era_id", "classical"))
	if previous_id == target_id:
		return {
			"ok": true,
			"changed": false,
			"code": "already_current_era",
			"previous_era_id": previous_id,
			"target_era_id": target_id,
			"rng_cursor": int(state.rng_cursor),
		}

	var transition_index := int(world.get("era_transition_count", 0)) + 1
	var transition_year := int(world.year)
	var factions: Array = world.factions
	var npcs: Array = world.npcs
	var old_faction_ids: Array[String] = []
	var old_survivor_ids: Array[String] = []

	for index in range(factions.size()):
		var faction: Dictionary = factions[index]
		old_faction_ids.append(str(faction.id))
		faction["legacy"] = true
		faction["previous_era_id"] = str(faction.get("era_id", previous_id))
		faction["legacy_since_year"] = transition_year
		faction["influence"] = clampi(int(faction.influence) - _rand_range(state, 8, 18), 0, 100)
		faction["resources"] = clampi(int(faction.resources) - _rand_range(state, 3, 10), 0, 100)
		faction["cohesion"] = clampi(int(faction.cohesion) - _rand_range(state, 1, 7), 0, 100)
		factions[index] = faction

	for index in range(npcs.size()):
		var npc: Dictionary = npcs[index]
		if bool(npc.alive):
			old_survivor_ids.append(str(npc.id))
			npc["legacy"] = true
			npc["previous_era_id"] = str(npc.get("era_id", previous_id))
			npc["legacy_since_year"] = transition_year
			npc["fame"] = clampi(int(npc.get("fame", 0)) - _rand_range(state, 0, 6), -100, 100)
		else:
			npc["historical_era_id"] = str(npc.get("era_id", previous_id))
		npcs[index] = npc

	var faction_archive := _bounded_array(world.get("faction_archive", []), MAX_FACTION_ARCHIVE, true)
	while factions.size() > MAX_FACTIONS - 2:
		var archived_faction: Dictionary = factions.pop_back()
		archived_faction["archived"] = true
		faction_archive.append(archived_faction)
		while faction_archive.size() > MAX_FACTION_ARCHIVE:
			faction_archive.pop_front()
	world["faction_archive"] = faction_archive

	var used_faction_ids := _entity_id_set(factions)
	for archived_value in faction_archive:
		if archived_value is Dictionary:
			used_faction_ids[str((archived_value as Dictionary).get("id", ""))] = true
	var new_faction_ids: Array[String] = []
	var target_templates: Array = ERA_FACTIONS[target_id]
	for template_value in target_templates:
		if new_faction_ids.size() >= 2:
			break
		var template: Dictionary = template_value
		var faction_id := _unique_transition_id(str(template.id), used_faction_ids, transition_index)
		used_faction_ids[faction_id] = true
		factions.append({
			"id": faction_id,
			"name": str(template.name),
			"era_id": target_id,
			"stance": str(template.stance),
			"archetype": str(template.archetype),
			"resources": _rand_range(state, 48, 78),
			"influence": _rand_range(state, 38, 68),
			"cohesion": _rand_range(state, 52, 84),
			"relations": {},
			"legacy": false,
			"founded_year": transition_year,
		})
		new_faction_ids.append(faction_id)
	_ensure_faction_relations(state, factions)

	var npc_archive := _bounded_array(world.get("npc_archive", []), MAX_NPC_ARCHIVE, true)
	while npcs.size() > MAX_NPCS - 2:
		var archive_index := _archive_npc_index(npcs)
		var archived_npc: Dictionary = npcs[archive_index]
		npcs.remove_at(archive_index)
		archived_npc["archived"] = true
		npc_archive.append(archived_npc)
		while npc_archive.size() > MAX_NPC_ARCHIVE:
			npc_archive.pop_front()
	world["npc_archive"] = npc_archive

	var used_npc_ids := _entity_id_set(npcs)
	for archived_value in npc_archive:
		if archived_value is Dictionary:
			used_npc_ids[str((archived_value as Dictionary).get("id", ""))] = true
	var new_npc_ids: Array[String] = []
	for serial in range(1, 3):
		var base_id := "npc_%s_%02d" % [target_id, serial]
		var npc_id := _unique_transition_id(base_id, used_npc_ids, transition_index)
		used_npc_ids[npc_id] = true
		var newcomer := _create_transition_npc(
			state, target_id, serial, npc_id,
			new_faction_ids[(serial - 1) % new_faction_ids.size()], transition_year)
		npcs.append(newcomer)
		new_npc_ids.append(npc_id)
	_ensure_npc_relations(state, npcs)

	world["factions"] = factions
	world["npcs"] = npcs
	world["simulated_era_id"] = target_id
	world["era_transition_count"] = transition_index
	world["era_pressure"] = clampi(int(world.era_pressure) - 35, 0, 100)
	world["stability"] = clampi(int(world.stability) - 8, 0, 100)
	state["current_era_id"] = target_id
	state["current_era"] = str(ERA_NAMES[target_id])

	var detail := "第%d年，世界由%s跨入%s。旧日人物与势力退为时代遗响，%s、%s成为新纪元最先升起的旗帜。" % [
		transition_year, str(ERA_NAMES.get(previous_id, previous_id)), str(ERA_NAMES[target_id]),
		str((factions[factions.size() - 2] as Dictionary).name),
		str((factions[factions.size() - 1] as Dictionary).name)]
	_append_history(world, detail)
	var event_id := "era_transition_%s_%s_%d" % [previous_id, target_id, transition_index]
	_append_active_event(world, {
		"id": event_id,
		"type": "era_transition",
		"started_year": transition_year,
		"expires_year": mini(MAX_WORLD_YEAR, transition_year + 5),
		"previous_era_id": previous_id,
		"target_era_id": target_id,
		"headline": "%s降临" % str(ERA_NAMES[target_id]),
	})
	var transition_record := {
		"index": transition_index,
		"year": transition_year,
		"previous_era_id": previous_id,
		"target_era_id": target_id,
		"old_faction_ids": old_faction_ids,
		"old_survivor_ids": old_survivor_ids,
		"new_faction_ids": new_faction_ids,
		"new_npc_ids": new_npc_ids,
		"history": detail,
		"event_id": event_id,
	}
	world["last_era_transition"] = transition_record.duplicate(true)
	state["world"] = world
	return {
		"ok": true,
		"changed": true,
		"code": "era_transitioned",
		"previous_era_id": previous_id,
		"target_era_id": target_id,
		"transition": transition_record,
		"rng_cursor": int(state.rng_cursor),
	}


static func _entity_id_set(entities: Array) -> Dictionary:
	var ids := {}
	for entity_value in entities:
		if entity_value is Dictionary:
			var entity_id := str((entity_value as Dictionary).get("id", ""))
			if not entity_id.is_empty():
				ids[entity_id] = true
	return ids


static func _unique_transition_id(base_id: String, used_ids: Dictionary, transition_index: int) -> String:
	if not used_ids.has(base_id):
		return base_id
	var suffix := maxi(1, transition_index)
	var candidate := "%s_rekindled_%02d" % [base_id, suffix]
	while used_ids.has(candidate):
		suffix += 1
		candidate = "%s_rekindled_%02d" % [base_id, suffix]
	return candidate


static func _archive_npc_index(npcs: Array) -> int:
	for index in range(npcs.size() - 1, -1, -1):
		if not bool((npcs[index] as Dictionary).get("alive", true)):
			return index
	return npcs.size() - 1


static func _create_transition_npc(
		state: Dictionary, era_id: String, serial: int, npc_id: String,
		faction_id: String, introduced_year: int) -> Dictionary:
	var names: Array = ERA_NPC_NAMES.get(era_id, ERA_NPC_NAMES.classical)
	var rules: Dictionary = ERA_RULES.get(era_id, ERA_RULES.classical)
	var age := _rand_range(state, 18, 54)
	var realm_cap := clampi(int(rules.get("realm_cap", 7)), 0, REALM_IDS.size() - 1)
	var age_realm_cap := mini(realm_cap, maxi(1, int(age / 11.0)))
	var realm_index := _rand_range(state, 0, age_realm_cap)
	var lifespan := maxi(age + 10, 62 + realm_index * 24 + _rand_range(state, 0, 28))
	return {
		"id": npc_id,
		"name": str(names[(serial - 1) % names.size()]),
		"age": age,
		"lifespan": lifespan,
		"realm_id": REALM_IDS[realm_index],
		"realm_index": realm_index,
		"realm": REALM_NAMES[realm_index],
		"stance": NPC_STANCES[(serial + 1) % NPC_STANCES.size()],
		"faction_id": faction_id,
		"era_id": era_id,
		"alive": true,
		"relations": {},
		"fame": _rand_range(state, -6, 18),
		"legacy": false,
		"introduced_year": introduced_year,
	}


static func _ensure_world(state: Dictionary) -> Dictionary:
	var value: Variant = state.get("world", {})
	var world: Dictionary = value.duplicate(true) if value is Dictionary else {}
	var seed_value := int(state.get("world_seed", world.get("seed", 1))) & RNG_MASK
	if seed_value == 0:
		seed_value = 1
	state["world_seed"] = seed_value
	state["rng_cursor"] = int(state.get("rng_cursor", 0)) & RNG_MASK
	world["seed"] = seed_value
	state["world"] = world
	return world


static func _normalize_factions(state: Dictionary, world: Dictionary, era_id: String) -> Array:
	var factions: Array = []
	var used_ids := {}
	var source: Variant = world.get("factions", [])
	if source is Array:
		for entry_value in source:
			if factions.size() >= MAX_FACTIONS:
				break
			if not (entry_value is Dictionary):
				continue
			var faction: Dictionary = entry_value.duplicate(true)
			var faction_id := str(faction.get("id", "")).strip_edges().left(64)
			if faction_id.is_empty() or used_ids.has(faction_id):
				continue
			used_ids[faction_id] = true
			faction["id"] = faction_id
			faction["name"] = str(faction.get("name", faction_id)).left(48)
			faction["era_id"] = str(faction.get("era_id", era_id)).left(32)
			faction["stance"] = str(faction.get("stance", "pragmatic")).left(24)
			faction["archetype"] = str(faction.get("archetype", "organization")).left(24)
			faction["resources"] = clampi(int(faction.get("resources", 50)), 0, 100)
			faction["influence"] = clampi(int(faction.get("influence", 45)), 0, 100)
			faction["cohesion"] = clampi(int(faction.get("cohesion", 55)), 0, 100)
			faction["relations"] = _dictionary_or_empty(faction.get("relations", {}))
			factions.append(faction)

	var templates: Array = ERA_FACTIONS.get(era_id, ERA_FACTIONS.classical)
	for template_value in templates:
		if factions.size() >= MIN_FACTIONS:
			break
		var template: Dictionary = template_value
		var faction_id := str(template.id)
		if used_ids.has(faction_id):
			continue
		used_ids[faction_id] = true
		factions.append({
			"id": faction_id,
			"name": str(template.name),
			"era_id": era_id,
			"stance": str(template.stance),
			"archetype": str(template.archetype),
			"resources": _rand_range(state, 42, 76),
			"influence": _rand_range(state, 34, 70),
			"cohesion": _rand_range(state, 46, 82),
			"relations": {},
		})
	return factions


static func _ensure_faction_relations(state: Dictionary, factions: Array) -> void:
	for left_index in range(factions.size()):
		var left: Dictionary = factions[left_index]
		var left_relations := _dictionary_or_empty(left.get("relations", {}))
		for right_index in range(left_index + 1, factions.size()):
			var right: Dictionary = factions[right_index]
			var right_relations := _dictionary_or_empty(right.get("relations", {}))
			var right_id := str(right.id)
			var left_id := str(left.id)
			var score: int
			if left_relations.has(right_id):
				score = int(left_relations[right_id])
			elif right_relations.has(left_id):
				score = int(right_relations[left_id])
			else:
				score = _rand_range(state, -24, 30)
			score = clampi(score, -100, 100)
			left_relations[right_id] = score
			right_relations[left_id] = score
			right["relations"] = right_relations
			factions[right_index] = right
		left["relations"] = left_relations
		factions[left_index] = left
	_clean_entity_relations(factions)


static func _normalize_npcs(
		state: Dictionary, world: Dictionary, era_id: String, factions: Array) -> Array:
	var npcs: Array = []
	var used_ids := {}
	var faction_ids: Array[String] = []
	for faction_value in factions:
		faction_ids.append(str((faction_value as Dictionary).id))
	var source: Variant = world.get("npcs", [])
	if source is Array:
		for entry_value in source:
			if npcs.size() >= MAX_NPCS:
				break
			if not (entry_value is Dictionary):
				continue
			var npc: Dictionary = entry_value.duplicate(true)
			var npc_id := str(npc.get("id", "")).strip_edges().left(64)
			if npc_id.is_empty() or used_ids.has(npc_id):
				continue
			used_ids[npc_id] = true
			npcs.append(_normalize_npc(npc, npc_id, faction_ids))

	var names: Array = ERA_NPC_NAMES.get(era_id, ERA_NPC_NAMES.classical)
	var rules: Dictionary = ERA_RULES.get(era_id, ERA_RULES.classical)
	var realm_cap := clampi(int(rules.get("realm_cap", 7)), 0, REALM_IDS.size() - 1)
	var serial := 1
	while npcs.size() < MIN_NPCS:
		var npc_id := "npc_%s_%02d" % [era_id, serial]
		serial += 1
		if used_ids.has(npc_id):
			continue
		used_ids[npc_id] = true
		var age := _rand_range(state, 18, 66)
		var age_realm_cap := mini(realm_cap, maxi(1, int(age / 12.0)))
		var realm_index := _rand_range(state, 0, age_realm_cap)
		var lifespan := maxi(age + 8, 58 + realm_index * 24 + _rand_range(state, 0, 30))
		var faction_id := faction_ids[(serial - 2) % faction_ids.size()]
		npcs.append({
			"id": npc_id,
			"name": str(names[(serial - 2) % names.size()]),
			"age": age,
			"lifespan": lifespan,
			"realm_id": REALM_IDS[realm_index],
			"realm_index": realm_index,
			"realm": REALM_NAMES[realm_index],
			"stance": NPC_STANCES[(serial - 2) % NPC_STANCES.size()],
			"faction_id": faction_id,
			"alive": true,
			"relations": {},
			"fame": _rand_range(state, -12, 24),
		})
	return npcs


static func _normalize_npc(npc: Dictionary, npc_id: String, faction_ids: Array[String]) -> Dictionary:
	var realm_index := int(npc.get("realm_index", REALM_IDS.find(str(npc.get("realm_id", "mortal")))))
	realm_index = clampi(realm_index, 0, REALM_IDS.size() - 1)
	npc["id"] = npc_id
	npc["name"] = str(npc.get("name", npc_id)).left(48)
	npc["age"] = clampi(int(npc.get("age", 18)), 0, 10000)
	npc["lifespan"] = clampi(int(npc.get("lifespan", 70 + realm_index * 20)), 1, 10000)
	npc["realm_id"] = REALM_IDS[realm_index]
	npc["realm_index"] = realm_index
	npc["realm"] = REALM_NAMES[realm_index]
	npc["stance"] = str(npc.get("stance", "pragmatic")).left(24)
	var faction_id := str(npc.get("faction_id", ""))
	if not faction_ids.has(faction_id):
		faction_id = faction_ids[0]
	npc["faction_id"] = faction_id
	npc["alive"] = bool(npc.get("alive", true))
	npc["relations"] = _dictionary_or_empty(npc.get("relations", {}))
	npc["fame"] = clampi(int(npc.get("fame", 0)), -100, 100)
	return npc


static func _ensure_npc_relations(state: Dictionary, npcs: Array) -> void:
	for left_index in range(npcs.size()):
		var left: Dictionary = npcs[left_index]
		var left_relations := _dictionary_or_empty(left.get("relations", {}))
		for right_index in range(left_index + 1, npcs.size()):
			var right: Dictionary = npcs[right_index]
			var right_relations := _dictionary_or_empty(right.get("relations", {}))
			var right_id := str(right.id)
			var left_id := str(left.id)
			var score: int
			if left_relations.has(right_id):
				score = int(left_relations[right_id])
			elif right_relations.has(left_id):
				score = int(right_relations[left_id])
			else:
				score = _rand_range(state, -18, 34)
			score = clampi(score, -100, 100)
			left_relations[right_id] = score
			right_relations[left_id] = score
			right["relations"] = right_relations
			npcs[right_index] = right
		left["relations"] = left_relations
		npcs[left_index] = left
	_clean_entity_relations(npcs)


static func _clean_entity_relations(entities: Array) -> void:
	var valid_ids := {}
	for entity_value in entities:
		valid_ids[str((entity_value as Dictionary).id)] = true
	for index in range(entities.size()):
		var entity: Dictionary = entities[index]
		var own_id := str(entity.id)
		var source := _dictionary_or_empty(entity.get("relations", {}))
		var cleaned := {}
		for peer_value in entities:
			var peer_id := str((peer_value as Dictionary).id)
			if peer_id != own_id and valid_ids.has(peer_id) and source.has(peer_id):
				cleaned[peer_id] = clampi(int(source[peer_id]), -100, 100)
		entity["relations"] = cleaned
		entities[index] = entity


static func _advance_factions(
		state: Dictionary, factions: Array, qi_tide: int, era_pressure: int) -> Array:
	var changes: Array = []
	for index in range(factions.size()):
		var faction: Dictionary = factions[index]
		var old_resources := int(faction.resources)
		var old_influence := int(faction.influence)
		var old_cohesion := int(faction.cohesion)
		var resource_delta := _rand_range(state, -6, 8) + int((qi_tide - 50) / 20.0)
		var influence_delta := _rand_range(state, -4, 5) + int((old_resources - 50) / 30.0)
		var cohesion_delta := _rand_range(state, -4, 4) - int(era_pressure / 45.0)
		faction["resources"] = clampi(old_resources + resource_delta, 0, 100)
		faction["influence"] = clampi(old_influence + influence_delta, 0, 100)
		faction["cohesion"] = clampi(old_cohesion + cohesion_delta, 0, 100)
		factions[index] = faction
		changes.append({
			"id": str(faction.id),
			"resource_delta": int(faction.resources) - old_resources,
			"influence_delta": int(faction.influence) - old_influence,
			"cohesion_delta": int(faction.cohesion) - old_cohesion,
		})

	for left_index in range(factions.size()):
		var left: Dictionary = factions[left_index]
		var left_relations: Dictionary = left.relations
		for right_index in range(left_index + 1, factions.size()):
			var right: Dictionary = factions[right_index]
			var right_relations: Dictionary = right.relations
			var old_score := int(left_relations.get(str(right.id), 0))
			var pressure_drag := -1 if era_pressure >= 65 else 0
			var new_score := clampi(old_score + _rand_range(state, -3, 3) + pressure_drag, -100, 100)
			left_relations[str(right.id)] = new_score
			right_relations[str(left.id)] = new_score
			right["relations"] = right_relations
			factions[right_index] = right
		left["relations"] = left_relations
		factions[left_index] = left
	return changes


static func _advance_npcs(
		state: Dictionary, npcs: Array, factions: Array, year: int,
		qi_tide: int, stability: int) -> Dictionary:
	var deaths: Array = []
	var promotions: Array = []
	for index in range(npcs.size()):
		var npc: Dictionary = npcs[index]
		if not bool(npc.alive):
			continue
		npc["age"] = mini(10000, int(npc.age) + 1)
		var lifespan := int(npc.lifespan)
		var dies := int(npc.age) >= lifespan
		if not dies:
			var danger_age := maxi(35, int(lifespan * 0.78))
			if int(npc.age) > danger_age:
				var mortality := clampi(1 + (int(npc.age) - danger_age) * 3 + maxi(0, 35 - stability), 0, 92)
				dies = _rand_range(state, 0, 99) < mortality
		if dies:
			var cause := _death_cause(qi_tide, stability)
			npc["alive"] = false
			npc["death_year"] = year
			npc["death_cause"] = cause
			deaths.append({"id": str(npc.id), "name": str(npc.name), "cause": cause})
		else:
			var old_realm := int(npc.realm_index)
			var advancement_chance := clampi(3 + int(qi_tide / 9.0) - int(npc.age / 80.0), 2, 22)
			if old_realm < REALM_IDS.size() - 1 and _rand_range(state, 0, 99) < advancement_chance:
				var new_realm := old_realm + 1
				npc["realm_index"] = new_realm
				npc["realm_id"] = REALM_IDS[new_realm]
				npc["realm"] = REALM_NAMES[new_realm]
				npc["lifespan"] = mini(10000, int(npc.lifespan) + 12 + new_realm * 2)
				promotions.append({"id": str(npc.id), "name": str(npc.name), "realm_id": str(npc.realm_id)})
		npcs[index] = npc

	var relation_shifts := 0
	for left_index in range(npcs.size()):
		var left: Dictionary = npcs[left_index]
		var left_relations: Dictionary = left.relations
		for right_index in range(left_index + 1, npcs.size()):
			var right: Dictionary = npcs[right_index]
			var right_relations: Dictionary = right.relations
			var right_id := str(right.id)
			var old_score := int(left_relations.get(right_id, 0))
			var delta := 0
			if bool(left.alive) and bool(right.alive):
				delta = _rand_range(state, -2, 2)
				if str(left.faction_id) == str(right.faction_id):
					delta += 1
				else:
					delta += int(_faction_relation(factions, str(left.faction_id), str(right.faction_id)) / 45.0)
				if str(left.stance) == str(right.stance):
					delta += 1
			var new_score := clampi(old_score + delta, -100, 100)
			if new_score != old_score:
				relation_shifts += 1
			left_relations[right_id] = new_score
			right_relations[str(left.id)] = new_score
			right["relations"] = right_relations
			npcs[right_index] = right
		left["relations"] = left_relations
		npcs[left_index] = left
	return {"deaths": deaths, "promotions": promotions, "relationship_shifts": relation_shifts}


static func _build_summary(
		year: int, world: Dictionary, dominant: Dictionary, faction_changes: Array,
		npc_changes: Dictionary, qi_delta: int, stability_delta: int,
		pressure_delta: int) -> Dictionary:
	var deaths: Array = npc_changes.deaths
	var promotions: Array = npc_changes.promotions
	var headline := "诸势力在变动中维持均衡"
	if not deaths.is_empty():
		headline = "%s等人的命数在今年终结" % str((deaths[0] as Dictionary).name)
	elif stability_delta <= -5:
		headline = "秩序裂隙正在扩张"
	elif qi_delta >= 5:
		headline = "灵潮高涨，修行者竞逐天机"
	elif qi_delta <= -5:
		headline = "灵潮退去，旧有盟约承受考验"
	elif not promotions.is_empty():
		headline = "%s破境，引动一方气数" % str((promotions[0] as Dictionary).name)
	var dominant_name := str(dominant.get("name", "无名势力"))
	var detail := "第%d年：%s。灵潮%d（%+d），稳定%d（%+d），纪元压力%d（%+d）；%s暂居势力之首。" % [
		year, headline, int(world.qi_tide), qi_delta, int(world.stability), stability_delta,
		int(world.era_pressure), pressure_delta, dominant_name]
	return {
		"year": year,
		"headline": headline,
		"detail": detail,
		"qi_tide": int(world.qi_tide),
		"qi_delta": qi_delta,
		"stability": int(world.stability),
		"stability_delta": stability_delta,
		"era_pressure": int(world.era_pressure),
		"era_pressure_delta": pressure_delta,
		"dominant_faction_id": str(dominant.get("id", "")),
		"faction_changes": faction_changes,
		"deaths": deaths.duplicate(true),
		"promotions": promotions.duplicate(true),
		"relationship_shifts": int(npc_changes.relationship_shifts),
	}


static func _dominant_faction(factions: Array) -> Dictionary:
	var winner: Dictionary = factions[0] if not factions.is_empty() else {}
	var winner_score := -1
	for faction_value in factions:
		var faction: Dictionary = faction_value
		var score := int(faction.resources) + int(faction.influence) + int(faction.cohesion)
		if score > winner_score:
			winner = faction
			winner_score = score
	return winner


static func _average_faction_relation(factions: Array) -> int:
	var total := 0
	var pairs := 0
	for left_index in range(factions.size()):
		var left: Dictionary = factions[left_index]
		var relations: Dictionary = left.relations
		for right_index in range(left_index + 1, factions.size()):
			total += int(relations.get(str((factions[right_index] as Dictionary).id), 0))
			pairs += 1
	return 0 if pairs == 0 else int(total / float(pairs))


static func _faction_relation(factions: Array, left_id: String, right_id: String) -> int:
	if left_id == right_id:
		return 70
	for faction_value in factions:
		var faction: Dictionary = faction_value
		if str(faction.id) == left_id:
			var relations: Dictionary = faction.relations
			return int(relations.get(right_id, 0))
	return 0


static func _death_cause(qi_tide: int, stability: int) -> String:
	if qi_tide <= 22:
		return "灵潮枯竭"
	if stability <= 25:
		return "乱世余波"
	return "寿元耗尽"


static func _update_active_events(world: Dictionary, summary: Dictionary) -> void:
	var events: Array = _bounded_array(world.get("active_events", []), MAX_ACTIVE_EVENTS, true)
	var current_year := int(world.year)
	var retained: Array = []
	for event_value in events:
		if event_value is Dictionary and int((event_value as Dictionary).get("expires_year", current_year)) >= current_year:
			retained.append((event_value as Dictionary).duplicate(true))
	retained.append({
		"id": "world_year_%d" % current_year,
		"started_year": current_year,
		"expires_year": mini(MAX_WORLD_YEAR, current_year + 1),
		"headline": str(summary.headline),
	})
	while retained.size() > MAX_ACTIVE_EVENTS:
		retained.pop_front()
	world["active_events"] = retained


static func _append_active_event(world: Dictionary, event: Dictionary) -> void:
	var events: Array = _bounded_array(world.get("active_events", []), MAX_ACTIVE_EVENTS, true)
	var event_id := str(event.get("id", ""))
	for existing_value in events:
		if existing_value is Dictionary and str((existing_value as Dictionary).get("id", "")) == event_id:
			return
	events.append(event.duplicate(true))
	while events.size() > MAX_ACTIVE_EVENTS:
		events.pop_front()
	world["active_events"] = events


static func _append_history(world: Dictionary, text: String) -> void:
	var history := _bounded_history(world.get("history", []))
	history.append(text.left(320))
	while history.size() > MAX_HISTORY_ENTRIES:
		history.pop_front()
	world["history"] = history


static func _bounded_history(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for entry in value:
			result.append(str(entry).left(320))
			if result.size() > MAX_HISTORY_ENTRIES:
				result.pop_front()
	return result


static func _bounded_array(value: Variant, maximum: int, keep_newest: bool) -> Array:
	var result: Array = value.duplicate(true) if value is Array else []
	while result.size() > maximum:
		if keep_newest:
			result.pop_front()
		else:
			result.pop_back()
	return result


static func _dictionary_or_empty(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}


static func _rand_range(state: Dictionary, minimum: int, maximum: int) -> int:
	if maximum <= minimum:
		return minimum
	var seed_value := int(state.get("world_seed", 1)) & RNG_MASK
	if seed_value == 0:
		seed_value = 1
	var cursor := int(state.get("rng_cursor", 0)) & RNG_MASK
	var mixed := (seed_value * 1103515245 + cursor * 12345 + 1013904223) & RNG_MASK
	mixed = (mixed * 48271 + 1) & RNG_MASK
	state["rng_cursor"] = (cursor + 1) & RNG_MASK
	return minimum + int(mixed % (maximum - minimum + 1))
