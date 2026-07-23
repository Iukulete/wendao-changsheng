class_name EncounterSystem
extends RefCounted

const NarrativeConsequenceScript = preload("res://scripts/narrative_consequence_system.gd")

## Contextual combat opportunities. Combat is a response to a visible threat,
## not a permanently enabled resource button.

const VERSION := 3
const DEFAULT_DURATION_TURNS := 3
const ERA_ENEMIES := {
	"classical": [
		{"id": "classical_razor_wolf", "name": "断刃苍狼", "tier": "normal"},
		{"id": "classical_oath_breaker", "name": "毁誓剑客", "tier": "elite"},
		{"id": "classical_fate_registrar", "name": "司命执笔", "tier": "boss"},
	],
	"steam": [
		{"id": "steam_furnace_hound", "name": "赤炉机犬", "tier": "normal"},
		{"id": "steam_debt_collector", "name": "灵轨债吏", "tier": "elite"},
		{"id": "steam_blackbox_foreman", "name": "黑匣炉监", "tier": "boss"},
	],
	"star_network": [
		{"id": "star_echo_hunter", "name": "星网猎忆者", "tier": "normal"},
		{"id": "star_void_daemon", "name": "虚航道魔", "tier": "elite"},
		{"id": "star_ghost_archivist", "name": "幽档归档官", "tier": "boss"},
	],
	"wasteland": [
		{"id": "wasteland_rain_beast", "name": "黑雨畸兽", "tier": "normal"},
		{"id": "wasteland_relic_raider", "name": "拾遗劫修", "tier": "elite"},
		{"id": "wasteland_false_sun_prophet", "name": "伪日预言师", "tier": "boss"},
	],
	"final_age": [
		{"id": "final_age_breath_taxer", "name": "夺息使", "tier": "normal"},
		{"id": "final_age_silent_cultivator", "name": "寂法修士", "tier": "elite"},
		{"id": "final_age_meridian_creditor", "name": "经脉债主", "tier": "boss"},
	],
	"immortal_dynasty": [
		{"id": "immortal_sky_enforcer", "name": "巡天仙吏", "tier": "normal"},
		{"id": "immortal_unchained_duelist", "name": "不系仙客", "tier": "elite"},
		{"id": "immortal_fate_registrar", "name": "白玉司命", "tier": "boss"},
	],
}

const CONTEXT_FIELDS := [
	"source_event_id", "source_choice_id", "source_choice_text", "encounter_id",
	"base_enemy_id", "enemy_id", "enemy_name",
	"motivation", "stakes", "victory_consequence", "defeat_consequence", "escape_consequence",
	"encounter_tier", "visual_profile_id", "weapon_profile_id", "vfx_profile_id",
	"rematch_key", "ally_support_id", "ally_support_name", "support_effect",
]
const PROFILE_CONTRACTS := {
	"classical_razor_wolf": ["enemy.classical.razor_wolf", "weapon.claw.bone_razor", "vfx.classical.blood_scent"],
	"classical_oath_breaker": ["enemy.classical.oath_breaker", "weapon.sword.broken_oath", "vfx.classical.oath_shards"],
	"classical_fate_registrar": ["enemy.classical.fate_registrar", "weapon.brush.fate_register", "vfx.classical.ink_decree"],
	"steam_furnace_hound": ["enemy.steam.furnace_hound", "weapon.jaw.rivet_furnace", "vfx.steam.pressure_vent"],
	"steam_debt_collector": ["enemy.steam.debt_collector", "weapon.chain.spirit_ledger", "vfx.steam.debt_seal"],
	"steam_blackbox_foreman": ["enemy.steam.blackbox_foreman", "weapon.hammer.blackbox_foundry", "vfx.steam.soul_furnace"],
	"star_echo_hunter": ["enemy.star.echo_hunter", "weapon.rifle.memory_lance", "vfx.star.echo_scan"],
	"star_void_daemon": ["enemy.star.void_daemon", "weapon.blade.phase_splitter", "vfx.star.void_refraction"],
	"star_ghost_archivist": ["enemy.star.ghost_archivist", "weapon.array.archive_needles", "vfx.star.identity_rollback"],
	"wasteland_rain_beast": ["enemy.wasteland.rain_beast", "weapon.fang.rain_corroded", "vfx.wasteland.black_rain"],
	"wasteland_relic_raider": ["enemy.wasteland.relic_raider", "weapon.glaive.relic_splice", "vfx.wasteland.shield_plunder"],
	"wasteland_false_sun_prophet": ["enemy.wasteland.false_sun_prophet", "weapon.censer.false_sun", "vfx.wasteland.ash_eclipse"],
	"final_age_breath_taxer": ["enemy.final_age.breath_taxer", "weapon.abacus.breath_levy", "vfx.final_age.breath_receipt"],
	"final_age_silent_cultivator": ["enemy.final_age.silent_cultivator", "weapon.bell.silent_seal", "vfx.final_age.silence_field"],
	"final_age_meridian_creditor": ["enemy.final_age.meridian_creditor", "weapon.needle.meridian_contract", "vfx.final_age.life_foreclosure"],
	"immortal_sky_enforcer": ["enemy.immortal.sky_enforcer", "weapon.halberd.heaven_edict", "vfx.immortal.rotating_law"],
	"immortal_unchained_duelist": ["enemy.immortal.unchained_duelist", "weapon.sword.unbound_edge", "vfx.immortal.unbound_cut"],
	"immortal_fate_registrar": ["enemy.immortal.fate_registrar", "weapon.brush.white_jade_fate", "vfx.immortal.name_erasure"],
}


static func normalize(state: Dictionary) -> Dictionary:
	_normalize_adversaries(state)
	var source: Variant = state.get("encounter", {})
	var encounter: Dictionary = source.duplicate(true) if source is Dictionary else {}
	var generation := clampi(int(state.get("generation", 1)), 1, 100000)
	if int(encounter.get("generation", generation)) != generation:
		encounter["active"] = false
		encounter["source"] = ""
		encounter["title"] = ""
		encounter["detail"] = ""
	encounter["version"] = VERSION
	encounter["generation"] = generation
	encounter["active"] = bool(encounter.get("active", false))
	encounter["source"] = str(encounter.get("source", "")).left(32)
	encounter["title"] = str(encounter.get("title", "")).left(96)
	encounter["detail"] = str(encounter.get("detail", "")).left(240)
	for field in CONTEXT_FIELDS:
		encounter[field] = str(encounter.get(field, "")).left(240)
	_normalize_identity_fields(encounter)
	encounter["offered_turn"] = clampi(int(encounter.get("offered_turn", 0)), 0, 0x7fffffff)
	encounter["expires_turn"] = clampi(int(encounter.get("expires_turn", 0)), 0, 0x7fffffff)
	encounter["offered_total"] = clampi(int(encounter.get("offered_total", 0)), 0, 1000000)
	encounter["resolved_total"] = clampi(int(encounter.get("resolved_total", 0)), 0, 1000000)
	encounter["expired_total"] = clampi(int(encounter.get("expired_total", 0)), 0, 1000000)
	encounter["last_result"] = str(encounter.get("last_result", "")).left(32)
	if not encounter.active:
		encounter["source"] = ""
		encounter["title"] = ""
		encounter["detail"] = ""
		for field in CONTEXT_FIELDS:
			encounter[field] = ""
	state["encounter"] = encounter
	return encounter


static func _normalize_identity_fields(encounter: Dictionary) -> void:
	var base_enemy_id := str(encounter.get("base_enemy_id", "")).strip_edges()
	if base_enemy_id.is_empty():
		base_enemy_id = str(encounter.get("enemy_id", "")).strip_edges()
	var encounter_id := str(encounter.get("encounter_id", "")).strip_edges()
	if encounter_id.is_empty():
		encounter_id = str(encounter.get("enemy_id", base_enemy_id)).strip_edges()
	if encounter_id.is_empty():
		encounter_id = base_enemy_id
	encounter["encounter_id"] = encounter_id.left(96)
	encounter["base_enemy_id"] = base_enemy_id.left(96)
	# enemy_id remains a compatibility alias for the roster definition.
	encounter["enemy_id"] = base_enemy_id.left(96)


static func _normalize_adversaries(state: Dictionary) -> Dictionary:
	var source: Variant = state.get("adversaries", {})
	var ledger: Dictionary = source.duplicate(true) if source is Dictionary else {}
	for enemy_id_value in ledger.keys():
		var enemy_id := str(enemy_id_value)
		var entry: Dictionary = ledger[enemy_id] if ledger[enemy_id] is Dictionary else {}
		entry["enemy_id"] = enemy_id
		entry["tier"] = str(entry.get("tier", "normal")).left(16)
		entry["encounters"] = clampi(int(entry.get("encounters", 0)), 0, 1000000)
		entry["wins"] = clampi(int(entry.get("wins", 0)), 0, 1000000)
		entry["losses"] = clampi(int(entry.get("losses", 0)), 0, 1000000)
		entry["escapes"] = clampi(int(entry.get("escapes", 0)), 0, 1000000)
		entry["expired"] = clampi(int(entry.get("expired", 0)), 0, 1000000)
		entry["last_outcome"] = str(entry.get("last_outcome", "")).left(16)
		entry["status"] = str(entry.get("status", "unknown")).left(24)
		entry["rematch_available"] = bool(entry.get("rematch_available", false))
		entry["rematch_key"] = str(entry.get("rematch_key", "")).left(96)
		ledger[enemy_id] = entry
	state["adversaries"] = ledger
	return ledger


static func record_outcome(state: Dictionary, enemy_id: String, tier: String,
		outcome: String, rematch_key: String = "") -> Dictionary:
	if enemy_id.strip_edges().is_empty():
		return {}
	var ledger := _normalize_adversaries(state)
	var entry: Dictionary = ledger.get(enemy_id, {}) as Dictionary
	entry["enemy_id"] = enemy_id
	entry["tier"] = tier if tier in ["normal", "elite", "boss"] else "normal"
	entry["encounters"] = int(entry.get("encounters", 0)) + 1
	entry["last_outcome"] = outcome.left(16)
	match outcome:
		"victory":
			entry["wins"] = int(entry.get("wins", 0)) + 1
			entry["status"] = "defeated"
		"defeat":
			entry["losses"] = int(entry.get("losses", 0)) + 1
			entry["status"] = "at_large"
		"escaped":
			entry["escapes"] = int(entry.get("escapes", 0)) + 1
			entry["status"] = "at_large"
		"expired":
			entry["expired"] = int(entry.get("expired", 0)) + 1
			entry["status"] = "trail_cold"
	var explicit_key := rematch_key.strip_edges()
	if not explicit_key.is_empty():
		entry["rematch_key"] = explicit_key.left(96)
	entry["rematch_available"] = tier == "boss" or not explicit_key.is_empty()
	ledger[enemy_id] = entry
	state["adversaries"] = ledger
	return entry.duplicate(true)


static func adversary_summary(state: Dictionary, enemy_id: String = "") -> Dictionary:
	var ledger := _normalize_adversaries(state)
	if enemy_id.is_empty():
		return ledger.duplicate(true)
	return (ledger.get(enemy_id, {}) as Dictionary).duplicate(true)


static func offer(state: Dictionary, source: String, title: String, detail: String,
		duration_turns: int = DEFAULT_DURATION_TURNS, context: Dictionary = {}) -> Dictionary:
	var encounter := normalize(state)
	if bool(encounter.active):
		return {"ok": false, "code": "encounter_active", "encounter": encounter.duplicate(true)}
	var current_turn := clampi(int(state.get("turn", 0)), 0, 0x7fffffff)
	encounter["active"] = true
	encounter["source"] = source.left(32)
	encounter["title"] = title.left(96)
	encounter["detail"] = detail.left(240)
	for field in CONTEXT_FIELDS:
		encounter[field] = str(context.get(field, "")).left(240)
	_normalize_identity_fields(encounter)
	encounter["offered_turn"] = current_turn
	encounter["expires_turn"] = mini(0x7fffffff, current_turn + maxi(1, duration_turns))
	encounter["offered_total"] = int(encounter.offered_total) + 1
	encounter["last_result"] = "offered"
	state["encounter"] = encounter
	return {"ok": true, "code": "encounter_offered", "encounter": encounter.duplicate(true),
		"message": "敌踪已现：%s。%s" % [title, detail]}


static func offer_from_choice(state: Dictionary, event: Dictionary,
		choice: Dictionary) -> Dictionary:
	var encounter_value: Variant = choice.get("encounter", {})
	var explicit: Dictionary = encounter_value if encounter_value is Dictionary else {}
	var should_offer: bool = not bool(choice.get("suppress_encounter", false)) and \
		(not explicit.is_empty() or bool(choice.get("combat_trigger", false)))
	if not should_offer:
		return {"ok": true, "code": "choice_left_no_enemy", "offered": false}
	var enemy := _encounter_enemy(state, event, choice, explicit)
	var event_title := str(event.get("title", "无名因果")).trim_prefix("【").left(48)
	var choice_text := str(choice.get("text", "沉默")).left(80)
	var enemy_name := str(explicit.get("enemy_name", enemy.get("name", "无名追兵"))).left(64)
	var legacy_enemy_id := str(explicit.get("enemy_id", "")).strip_edges()
	var base_enemy_id := str(explicit.get("base_enemy_id", legacy_enemy_id)).strip_edges()
	if base_enemy_id.is_empty():
		base_enemy_id = str(enemy.get("id", "")).strip_edges()
	var encounter_id := str(explicit.get("encounter_id", "")).strip_edges()
	if encounter_id.is_empty() and not legacy_enemy_id.is_empty() and \
			str(explicit.get("base_enemy_id", "")).strip_edges().is_empty():
		# Existing canonical encounters keep their historical ledger identity.
		encounter_id = legacy_enemy_id
	if encounter_id.is_empty():
		var authored_identity := "%s|%s" % [
			str(event.get("id", event.get("title", "event"))),
			str(choice.get("id", choice.get("text", "choice"))),
		]
		encounter_id = "story_%s" % authored_identity.sha256_text().left(16)
	encounter_id = encounter_id.left(96)
	base_enemy_id = base_enemy_id.left(96)
	var profile: Array = PROFILE_CONTRACTS.get(base_enemy_id,
		["enemy.generic.unknown", "weapon.generic.unarmed", "vfx.generic.impact"])
	var motivation := str(explicit.get("motivation",
		"%s循着你在“%s”中的行动追到此地。" % [enemy_name, choice_text])).left(180)
	var stakes := str(explicit.get("stakes",
		"若置之不理，这份敌意会在三次年轮后反噬山河稳定。" )).left(180)
	var context := {
		"source_event_id": str(event.get("id", "")).left(96),
		"source_choice_id": str(choice.get("id", "")).left(96),
		"source_choice_text": choice_text,
		"encounter_id": encounter_id,
		"base_enemy_id": base_enemy_id,
		"enemy_id": base_enemy_id,
		"enemy_name": enemy_name,
		"encounter_tier": str(explicit.get("encounter_tier", enemy.get("tier", "normal"))).left(16),
		"visual_profile_id": str(explicit.get("visual_profile_id", profile[0])).left(96),
		"weapon_profile_id": str(explicit.get("weapon_profile_id", profile[1])).left(96),
		"vfx_profile_id": str(explicit.get("vfx_profile_id", profile[2])).left(96),
		"rematch_key": str(explicit.get("rematch_key", "")).left(96),
		"ally_support_id": str(explicit.get("ally_support_id", "")).left(96),
		"ally_support_name": str(explicit.get("ally_support_name", "")).left(96),
		"support_effect": str(explicit.get("support_effect", "")).left(48),
		"motivation": motivation,
		"stakes": stakes,
		"victory_consequence": str(explicit.get("victory_consequence",
			"击败%s会暂时截断这条追索。" % enemy_name)).left(200),
		"defeat_consequence": str(explicit.get("defeat_consequence",
			"若败在%s手中，此世可能在这里终结。" % enemy_name)).left(200),
		"escape_consequence": str(explicit.get("escape_consequence",
			"若撤离，%s会保留这笔未结的敌意。" % enemy_name)).left(200),
	}
	return offer(state, "event_choice", "%s · %s" % [enemy_name, event_title],
		"%s %s" % [motivation, stakes], int(explicit.get("duration_turns",
			DEFAULT_DURATION_TURNS)), context)


static func expire_if_needed(state: Dictionary) -> Dictionary:
	var encounter := normalize(state)
	if not bool(encounter.active):
		return {"ok": true, "code": "no_encounter", "expired": false}
	var current_turn := int(state.get("turn", 0))
	if current_turn <= int(encounter.expires_turn):
		return {"ok": true, "code": "encounter_active", "expired": false,
			"encounter": encounter.duplicate(true)}
	var snapshot := encounter.duplicate(true)
	var title := str(encounter.title)
	encounter["active"] = false
	encounter["expired_total"] = int(encounter.expired_total) + 1
	encounter["last_result"] = "expired"
	state["encounter"] = encounter
	var world: Dictionary = state.get("world", {})
	world["stability"] = clampi(int(world.get("stability", 65)) - 3, 0, 100)
	world["era_pressure"] = clampi(int(world.get("era_pressure", 0)) + 2, 0, 100)
	state["world"] = world
	var consequence_result := NarrativeConsequenceScript.resolve_combat_outcome(state,
		str(snapshot.get("source_event_id", "")), str(snapshot.get("source_choice_id", "")),
		"expired")
	var adversary_id := str(snapshot.get("encounter_id", "")).strip_edges()
	if adversary_id.is_empty():
		adversary_id = str(snapshot.get("enemy_id", "")).strip_edges()
	var adversary_result := record_outcome(state, adversary_id,
		str(snapshot.get("encounter_tier", "normal")), "expired",
		str(snapshot.get("rematch_key", "")))
	return {"ok": true, "code": "encounter_expired", "expired": true,
		"message": "敌踪【%s】已从山河中消散；你没有回应，局势稳定度下降。" % title,
		"encounter": snapshot, "narrative_consequence": consequence_result,
		"adversary": adversary_result}


static func consume(state: Dictionary) -> Dictionary:
	var encounter := normalize(state)
	if not bool(encounter.active):
		return {"ok": false, "code": "no_encounter"}
	var snapshot := encounter.duplicate(true)
	encounter["active"] = false
	encounter["resolved_total"] = int(encounter.resolved_total) + 1
	encounter["last_result"] = "engaged"
	state["encounter"] = encounter
	return {"ok": true, "code": "encounter_consumed", "encounter": snapshot}


static func summary(state: Dictionary) -> Dictionary:
	var encounter := normalize(state)
	if not bool(encounter.active):
		return {"active": false, "last_result": str(encounter.last_result)}
	var remaining := int(encounter.expires_turn) - int(state.get("turn", 0))
	return {
		"active": remaining >= 0,
		"title": str(encounter.title),
		"detail": str(encounter.detail),
		"source": str(encounter.source),
		"remaining_turns": maxi(0, remaining),
		"source_event_id": str(encounter.source_event_id),
		"source_choice_id": str(encounter.source_choice_id),
		"source_choice_text": str(encounter.source_choice_text),
		"encounter_id": str(encounter.encounter_id),
		"base_enemy_id": str(encounter.base_enemy_id),
		"enemy_id": str(encounter.enemy_id),
		"enemy_name": str(encounter.enemy_name),
		"motivation": str(encounter.motivation),
		"stakes": str(encounter.stakes),
		"victory_consequence": str(encounter.victory_consequence),
		"defeat_consequence": str(encounter.defeat_consequence),
		"escape_consequence": str(encounter.escape_consequence),
		"encounter_tier": str(encounter.encounter_tier),
		"visual_profile_id": str(encounter.visual_profile_id),
		"weapon_profile_id": str(encounter.weapon_profile_id),
		"vfx_profile_id": str(encounter.vfx_profile_id),
		"rematch_key": str(encounter.rematch_key),
		"ally_support_id": str(encounter.ally_support_id),
		"ally_support_name": str(encounter.ally_support_name),
		"support_effect": str(encounter.support_effect),
	}


static func _encounter_enemy(state: Dictionary, event: Dictionary, choice: Dictionary,
		explicit: Dictionary) -> Dictionary:
	var explicit_base_id := str(explicit.get("base_enemy_id",
		explicit.get("enemy_id", ""))).strip_edges()
	if not explicit_base_id.is_empty():
		var explicit_enemy := _enemy_descriptor(explicit_base_id)
		if not explicit_enemy.is_empty():
			return explicit_enemy
		return {"id": explicit_base_id, "name": str(explicit.get("enemy_name", "无名追兵")),
			"tier": str(explicit.get("encounter_tier", "normal"))}
	var era_id := str(state.get("current_era_id", "classical"))
	var pool: Array = ERA_ENEMIES.get(era_id, ERA_ENEMIES.classical)
	var requested_tier := str(explicit.get("encounter_tier", ""))
	if requested_tier in ["normal", "elite", "boss"]:
		var tier_pool: Array = pool.filter(func(entry: Variant) -> bool:
			return entry is Dictionary and str((entry as Dictionary).get("tier", "normal")) == requested_tier)
		if not tier_pool.is_empty():
			pool = tier_pool
	var identity := "%s|%s|%s" % [str(event.get("id", event.get("title", "event"))),
		str(choice.get("id", choice.get("text", "choice"))), era_id]
	return (pool[posmod(hash(identity), pool.size())] as Dictionary).duplicate(true)


static func _enemy_descriptor(enemy_id: String) -> Dictionary:
	for pool_value in ERA_ENEMIES.values():
		for enemy_value in (pool_value as Array):
			if enemy_value is Dictionary and str((enemy_value as Dictionary).get("id", "")) == enemy_id:
				return (enemy_value as Dictionary).duplicate(true)
	return {}
