class_name GameStateSchema
extends RefCounted

## Canonical v2 runtime state shared by every gameplay system.
##
## The previous vertical slice saved a handful of UI fields.  Version 2 keeps
## the whole run in one stable, data-oriented document so cultivation, world
## simulation, reincarnation, inventory and AI can evolve without inventing
## separate save formats.

const SCHEMA_VERSION := 2

const ERA_IDS := [
	"classical",
	"steam",
	"star_network",
	"wasteland",
	"final_age",
	"immortal_dynasty",
]

const ERA_NAMES := {
	"classical": "古典修仙纪",
	"steam": "灵机蒸汽纪",
	"star_network": "星穹道网纪",
	"wasteland": "废土返道纪",
	"final_age": "末法裂变纪",
	"immortal_dynasty": "仙朝鼎盛纪",
}

const REALM_IDS := [
	"mortal", "qi_refining", "foundation", "golden_core", "nascent_soul",
	"spirit_severing", "void_refining", "unity", "tribulation", "mahayana",
	"half_immortal", "true_immortal", "heaven_immortal", "mystic_immortal",
	"golden_immortal", "immortal_lord", "immortal_king", "immortal_sovereign",
	"immortal_emperor", "dao_ancestor", "heavenly_dao",
]

const REALM_NAMES := [
	"凡人", "炼气期", "筑基期", "金丹期", "元婴期", "化神期", "炼虚期",
	"合体期", "渡劫期", "大乘期", "半仙之体", "真仙境", "天仙境", "玄仙境",
	"金仙境", "仙君", "仙王", "仙尊", "仙帝", "道祖", "道祖-天道境",
]

const LEGACY_REALM_ALIASES := {
	"炼气": "qi_refining",
	"练气": "qi_refining",
	"筑基": "foundation",
	"金丹": "golden_core",
	"元婴": "nascent_soul",
	"化神": "spirit_severing",
	"炼虚": "void_refining",
	"合体": "unity",
	"渡劫": "tribulation",
	"大乘": "mahayana",
	"半仙": "half_immortal",
	"真仙": "true_immortal",
	"天仙": "heaven_immortal",
	"玄仙": "mystic_immortal",
	"金仙": "golden_immortal",
}

const PATH_DIMENSIONS := [
	"compassion", "ambition", "defiance", "insight", "creation", "bonds",
]


static func create_new_game(dao_name: String, seed_value: int = 0,
		root_values: Array = []) -> Dictionary:
	var safe_name := dao_name.strip_edges().left(32)
	if safe_name.is_empty():
		safe_name = "无名客"
	var actual_seed := seed_value
	if actual_seed == 0:
		actual_seed = int(Time.get_unix_time_from_system()) ^ int(Time.get_ticks_usec()) ^ hash(safe_name)
	actual_seed = actual_seed & 0x7fffffff
	var player := create_player(safe_name, actual_seed, root_values)
	return {
		"schema_version": SCHEMA_VERSION,
		"run_id": "wendao-%s-%s" % [actual_seed, Time.get_unix_time_from_system()],
		"world_seed": actual_seed,
		"rng_cursor": 0,
		"generation": 1,
		"turn": 0,
		"current_era_id": "classical",
		"current_era": ERA_NAMES.classical,
		"player": player,
		"legacy": create_legacy_state(),
		"world": create_world_state(actual_seed),
		"inventory": {
			"items": [
				{"item_id": "healing_pill", "instance_id": "healing_pill", "quantity": 1, "stackable": true},
				{"item_id": "iron_sword", "instance_id": "item_iron_sword_000001", "quantity": 1, "stackable": false},
			],
			"materials": {"spirit_herb": 2, "black_iron": 2},
			"equipped": {"weapon_id": "", "armor_id": "", "relic_id": "black_white_jade"},
			"instance_counter": 1,
			"forge_counter": 0,
			"lost_artifacts": [],
		},
		"combat": {
			"active": false,
			"current": {},
			"history": [],
		},
		"dungeon": {
			"active": false,
			"run": {},
			"history": [],
		},
		"story": {
			"story_version": 2,
			"completed_event_ids": [],
			"life_event_ids": [],
			"chapter_log": [],
			"event_cooldowns": {},
			"active_arcs": {},
			"arc_progress": {"jade": 0, "sect": 0, "family": 0, "rival": 0},
			"arc_legacies": {},
			"arc_echoes": {},
			"last_arc_id": "",
			"next_arc_event_at": 0,
			"birth_effects_applied_generation": 0,
			"resolved_arcs": [],
			"unresolved_threads": [],
		},
		"objective": {
			"version": 1,
			"generation": 1,
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
		},
		"encounter": {
			"version": 1,
			"generation": 1,
			"active": false,
			"source": "",
			"title": "",
			"detail": "",
			"offered_turn": 0,
			"expires_turn": 0,
			"offered_total": 0,
			"resolved_total": 0,
			"expired_total": 0,
			"last_result": "",
		},
		"ai": {
			"enabled": true,
			"local_only": true,
			"last_status": "not_requested",
			"last_backend": "",
			"request_count": 0,
			"fallback_count": 0,
		},
		"recent_memories": [
			"测灵台没有记下识海中的空阙。",
			"黑白旧玉在掌心第一次发热。",
		],
		"feedback": "镜湖古门在你写下道号的那一刻开启。",
		"life_closed": false,
	}


static func create_player(dao_name: String, seed_value: int, root_values: Array = []) -> Dictionary:
	var roots := _normalize_or_roll_roots(seed_value, root_values)
	var total_root := 0
	for value in roots:
		total_root += int(value)
	return {
		"id": "current_life",
		"name": dao_name.strip_edges().left(32),
		"realm_id": "mortal",
		"realm_index": 0,
		"realm": REALM_NAMES[0],
		"level": 1,
		"exp": 0,
		"hp": 100 + total_root * 5,
		"max_hp": 100 + total_root * 5,
		"mp": 50 + total_root * 3,
		"max_mp": 50 + total_root * 3,
		"age": 16,
		"lifespan": 60 + total_root,
		"spirit_stones": 10,
		"pills": 0,
		"karma": 0,
		"dao_heart": 0,
		"reputation": 0,
		"enmity": 0,
		"attack": 10 + total_root,
		"defense": 5 + total_root / 2,
		"total_events": 0,
		"battles_won": 0,
		"npcs_met": 0,
		"roots": roots,
		"path": {
			"compassion": 0,
			"ambition": 0,
			"defiance": 0,
			"insight": 0,
			"creation": 0,
			"bonds": 0,
		},
		"family": _create_family(seed_value),
		"statuses": [],
	}


static func create_legacy_state() -> Dictionary:
	return {
		"generation": 1,
		"past_lives": [],
		"inherited_echoes": [],
		"unresolved_threads": [],
		"relic": {
			"id": "black_white_jade",
			"name": "黑白轮回玉",
			"resonance": 0,
			"awakening_stage": 0,
			"aspect": "未定道痕",
			"dao_id": "",
			"dao_depth": 0,
		},
		"armory": {
			"version": 1,
			"achievements": {},
			"weapons": {},
			"equipped_id": "",
			"notices": [],
		},
	}


static func create_world_state(seed_value: int) -> Dictionary:
	return {
		"seed": seed_value,
		"year": 1,
		"age": 0,
		"era_pressure": 0,
		"qi_tide": 50,
		"stability": 65,
		"factions": [],
		"npcs": [],
		"active_events": [],
		"history": ["镜湖古门重现，六种纪元的倒影同时落入水中。"],
	}


static func ensure_v2(snapshot: Dictionary) -> Dictionary:
	var state := snapshot.duplicate(true)
	if int(state.get("schema_version", 0)) < SCHEMA_VERSION:
		state = migrate_v1(state)
	state["schema_version"] = SCHEMA_VERSION
	var era_name := str(state.get("current_era", ERA_NAMES.classical))
	var era_id := str(state.get("current_era_id", era_id_for_name(era_name)))
	if not ERA_IDS.has(era_id):
		era_id = era_id_for_name(era_name)
	state["current_era_id"] = era_id
	state["current_era"] = str(ERA_NAMES.get(era_id, ERA_NAMES.classical))
	state["generation"] = max(1, int(state.get("generation", 1)))
	state["turn"] = max(0, int(state.get("turn", 0)))
	state["world_seed"] = int(state.get("world_seed", 1)) & 0x7fffffff
	state["rng_cursor"] = max(0, int(state.get("rng_cursor", 0)))
	state["run_id"] = str(state.get("run_id", "wendao-imported" )).left(96)
	state["legacy"] = _merge_defaults(state.get("legacy", {}), create_legacy_state())
	state["world"] = _merge_defaults(state.get("world", {}), create_world_state(int(state.world_seed)))
	state["inventory"] = _merge_defaults(state.get("inventory", {}), {
		"items": [], "materials": {},
		"equipped": {"weapon_id": "", "armor_id": "", "relic_id": "black_white_jade"},
		"instance_counter": 0, "forge_counter": 0, "lost_artifacts": [],
	})
	state["combat"] = _merge_defaults(state.get("combat", {}), {
		"active": false, "current": {}, "history": [],
	})
	state["dungeon"] = _merge_defaults(state.get("dungeon", {}), {
		"active": false, "run": {}, "history": [],
	})
	state["story"] = _merge_defaults(state.get("story", {}), {
		"story_version": 2,
		"completed_event_ids": [], "life_event_ids": [], "event_cooldowns": {},
		"chapter_log": [],
		"active_arcs": {}, "resolved_arcs": [], "unresolved_threads": [],
		"arc_progress": {"jade": 0, "sect": 0, "family": 0, "rival": 0},
		"arc_legacies": {}, "arc_echoes": {}, "last_arc_id": "",
		"next_arc_event_at": 0, "birth_effects_applied_generation": 0,
	})
	state["ai"] = _merge_defaults(state.get("ai", {}), {
		"enabled": true, "local_only": true, "last_status": "not_requested",
		"last_backend": "", "request_count": 0, "fallback_count": 0,
	})
	state["life_closed"] = bool(state.get("life_closed", false))
	var source_player: Dictionary = state.get("player", {})
	state["player"] = ensure_player_v2(source_player)
	return state


static func migrate_v1(snapshot: Dictionary) -> Dictionary:
	var source_player: Dictionary = snapshot.get("player", {})
	var roots: Array = source_player.get("roots", [7, 4, 8, 5, 6])
	var seed_value := hash("%s:%s:%s" % [
		str(source_player.get("name", "旧档修士")),
		str(snapshot.get("current_era", ERA_NAMES.classical)),
		int(source_player.get("age", 16)),
	]) & 0x7fffffff
	var state := create_new_game(str(source_player.get("name", "旧档修士")), seed_value, roots)
	var upgraded_player: Dictionary = state.player
	for field in source_player.keys():
		upgraded_player[field] = source_player[field]
	# v1 had display names only. Do not let the freshly-created mortal IDs
	# override the realm carried by the legacy snapshot.
	if not source_player.has("realm_index"):
		upgraded_player.erase("realm_index")
	if not source_player.has("realm_id"):
		upgraded_player.erase("realm_id")
	upgraded_player = ensure_player_v2(upgraded_player)
	# The vertical slice let its single visible realm grow beyond layer nine.
	# Preserve that earned progress by carrying each complete nine-layer span
	# into the next canonical realm instead of rejecting an otherwise valid save.
	var legacy_level := maxi(1, int(source_player.get("level", 1)))
	if legacy_level > 9:
		var realm_progress := int((legacy_level - 1) / 9.0)
		var target_realm := mini(REALM_IDS.size() - 1,
			int(upgraded_player.realm_index) + realm_progress)
		upgraded_player["realm_index"] = target_realm
		upgraded_player["realm_id"] = REALM_IDS[target_realm]
		upgraded_player["realm"] = REALM_NAMES[target_realm]
		upgraded_player["level"] = 9 if target_realm == REALM_IDS.size() - 1 else ((legacy_level - 1) % 9) + 1
	else:
		upgraded_player["level"] = legacy_level
	state["player"] = upgraded_player
	state["current_era"] = str(snapshot.get("current_era", ERA_NAMES.classical))
	state["current_era_id"] = era_id_for_name(str(state.current_era))
	state["recent_memories"] = snapshot.get("recent_memories", []).duplicate()
	state["feedback"] = str(snapshot.get("feedback", "旧玉从旧档中唤回一段命途。"))
	state["run_id"] = "wendao-v1-import-%s" % seed_value
	return state


static func ensure_player_v2(source: Dictionary) -> Dictionary:
	var player := source.duplicate(true)
	var realm_index := int(player.get("realm_index", -1))
	var realm_id := str(player.get("realm_id", ""))
	if REALM_IDS.has(realm_id):
		realm_index = REALM_IDS.find(realm_id)
	elif realm_index < 0 or realm_index >= REALM_IDS.size():
		var realm_name := str(player.get("realm", "凡人")).strip_edges()
		realm_index = REALM_NAMES.find(realm_name)
		if realm_index < 0:
			var legacy_realm_id := str(LEGACY_REALM_ALIASES.get(realm_name, ""))
			if REALM_IDS.has(legacy_realm_id):
				realm_index = REALM_IDS.find(legacy_realm_id)
	if realm_index < 0 or realm_index >= REALM_IDS.size():
		realm_index = 0
	player["realm_index"] = realm_index
	player["realm_id"] = REALM_IDS[realm_index]
	player["realm"] = REALM_NAMES[realm_index]
	player["attack"] = int(player.get("attack", player.get("attack_power", 10)))
	player["defense"] = int(player.get("defense", 5))
	player["total_events"] = max(0, int(player.get("total_events", 0)))
	player["battles_won"] = max(0, int(player.get("battles_won", 0)))
	player["npcs_met"] = max(0, int(player.get("npcs_met", 0)))
	player["path"] = _merge_defaults(player.get("path", {}), {
		"compassion": 0, "ambition": 0, "defiance": 0,
		"insight": 0, "creation": 0, "bonds": 0,
	})
	player["family"] = _merge_defaults(player.get("family", {}), {
		"origin": "来历未明", "clan": "", "guardian": "", "secret": "",
		"fame": 0, "wealth": 0,
	})
	player["statuses"] = player.get("statuses", []).duplicate()
	return player


static func era_id_for_name(era_name: String) -> String:
	for era_id in ERA_IDS:
		if str(ERA_NAMES[era_id]) == era_name:
			return era_id
	return "classical"


static func _normalize_or_roll_roots(seed_value: int, values: Array) -> Array[int]:
	var roots: Array[int] = []
	if values.size() == 5:
		for value in values:
			roots.append(clampi(int(value), 1, 10))
		return roots
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for _index in range(5):
		roots.append(rng.randi_range(1, 10))
	return roots


static func _create_family(seed_value: int) -> Dictionary:
	var origins := ["寒门药户", "边城镖户", "旧宗旁支", "散修遗孤", "坊市工匠", "隐退世家"]
	var guardians := ["沉默的养父", "守山的姑母", "坊市老医", "无名剑客", "独居阵师", "族中长姐"]
	var secrets := [
		"族谱里有一页被整齐裁去。",
		"幼时随身的黑白旧玉无人认得来历。",
		"家中每逢月蚀都会多出一副碗筷。",
		"养育者从不允许你靠近镜湖。",
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x51f15e
	return {
		"origin": origins[rng.randi_range(0, origins.size() - 1)],
		"clan": "",
		"guardian": guardians[rng.randi_range(0, guardians.size() - 1)],
		"secret": secrets[rng.randi_range(0, secrets.size() - 1)],
		"fame": rng.randi_range(-8, 12),
		"wealth": rng.randi_range(0, 18),
	}


static func _merge_defaults(value: Variant, defaults: Dictionary) -> Dictionary:
	var merged := defaults.duplicate(true)
	if value is Dictionary:
		for key in value.keys():
			merged[key] = value[key]
	return merged
