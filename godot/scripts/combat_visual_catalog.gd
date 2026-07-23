class_name CombatVisualCatalog
extends RefCounted

## Product combat visual contract.  CombatStage owns no roster knowledge: every
## silhouette, equipment layer and semantic effect is resolved here.

const DATA_PATH := "res://data/combat_visual_catalog_v1.json"
const ENEMY_IDS := [
	"classical_razor_wolf", "classical_oath_breaker", "classical_fate_registrar",
	"steam_furnace_hound", "steam_debt_collector", "steam_blackbox_foreman",
	"star_echo_hunter", "star_void_daemon", "star_ghost_archivist",
	"wasteland_rain_beast", "wasteland_relic_raider", "wasteland_false_sun_prophet",
	"final_age_breath_taxer", "final_age_silent_cultivator", "final_age_meridian_creditor",
	"immortal_sky_enforcer", "immortal_unchained_duelist", "immortal_fate_registrar",
]
const PATH_IDS := ["compassion", "ambition", "defiance", "insight", "creation", "bonds"]
const EQUIPMENT_IDS := [
	"iron_sword", "jade_qingxiao", "spirit_blade", "cloud_robe", "warding_armor",
	"black_white_jade", "void_relic",
]
const JADE_WEAPON_IDS := [
	"qingxiao", "zhanjie", "qinglian", "xuesha", "suiyue", "zuting", "wandao", "lunhui",
	"chuancheng", "baijie", "wugou", "jiuxiao", "sixiang", "heibai", "canxing", "wuliang",
]
const FALLBACK_ENEMY := {
	"profile_id": "enemy.fallback",
	"weapon_profile_id": "weapon.fallback",
	"vfx_profile_id": "vfx.fallback",
	"palette": ["#181b1e", "#3c4648", "#75858a", "#d6bd7b"],
	"body": [[-7,-4,15,4],[-6,-12,13,8],[-4,-20,9,8],[-3,-28,7,7],[-9,-15,3,4],[6,-15,3,4],[-5,0,3,4],[2,0,3,4]],
	"marks": [[-1,-25,1,2],[2,-22,1,2]],
	"weapon": "fallback",
}

static var _data_cache: Dictionary = {}


static func load_definitions() -> Dictionary:
	if _data_cache.is_empty() and FileAccess.file_exists(DATA_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_data_cache = (parsed as Dictionary).duplicate(true)
	return _data_cache.duplicate(true)


static func enemy_ids() -> Array[String]:
	return ENEMY_IDS.duplicate()


static func path_ids() -> Array[String]:
	return PATH_IDS.duplicate()


static func equipment_ids() -> Array[String]:
	return EQUIPMENT_IDS.duplicate()


static func jade_weapon_ids() -> Array[String]:
	return JADE_WEAPON_IDS.duplicate()


static func enemy_profile(enemy_id: String) -> Dictionary:
	var data := load_definitions()
	var enemies: Dictionary = data.get("enemies", {})
	var profile_value: Variant = enemies.get(enemy_id, null)
	if profile_value is Dictionary:
		var profile: Dictionary = (profile_value as Dictionary).duplicate(true)
		profile["enemy_id"] = enemy_id
		profile["fallback"] = false
		return profile
	return fallback_enemy(enemy_id)


static func enemy_profile_for_battle(battle: Dictionary) -> Dictionary:
	var requested_profile_id := str(battle.get("visual_profile_id", "")).strip_edges().left(96)
	if not requested_profile_id.is_empty():
		var enemies: Dictionary = load_definitions().get("enemies", {})
		for enemy_id in ENEMY_IDS:
			var value: Variant = enemies.get(enemy_id, null)
			if value is Dictionary and str((value as Dictionary).get("profile_id", "")) == requested_profile_id:
				var profile: Dictionary = (value as Dictionary).duplicate(true)
				profile["enemy_id"] = str(battle.get("enemy_id", enemy_id))
				profile["fallback"] = false
				return profile
	return enemy_profile(str(battle.get("enemy_id", "")))


static func fallback_enemy(enemy_id: String) -> Dictionary:
	var profile := FALLBACK_ENEMY.duplicate(true)
	profile["enemy_id"] = enemy_id
	profile["fallback"] = true
	# A stable id-specific mark prevents unknown legacy enemies from collapsing into
	# the same sprite while keeping the fallback visibly subordinate to authored art.
	var seed_value := absi(hash(enemy_id))
	profile["marks"] = [[-1 - seed_value % 5, -25, 1, 2], [2 + seed_value % 4, -22, 1, 2],
		[-6 + seed_value % 11, -17, 2, 1]]
	profile["palette"] = ["#181b1e", "#3c%02x%02x" % [40 + seed_value % 35, 40 + seed_value % 30],
		"#75%02x%02x" % [70 + seed_value % 40, 70 + seed_value % 40], "#d6bd7b"]
	return profile


static func path_profile(path_id: String) -> Dictionary:
	var data := load_definitions()
	var paths: Dictionary = data.get("paths", {})
	var value: Variant = paths.get(path_id, null)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return (paths.get("insight", {}) as Dictionary).duplicate(true)


static func equipment_profile(equipment_id: String) -> Dictionary:
	var data := load_definitions()
	var equipment: Dictionary = data.get("equipment", {})
	var value: Variant = equipment.get(equipment_id, null)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func jade_weapon_profile(weapon_id: String) -> Dictionary:
	var data := load_definitions()
	var weapons: Dictionary = data.get("jade_weapons", {})
	var value: Variant = weapons.get(weapon_id, null)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func enemy_weapon_profile(profile_id: String) -> Dictionary:
	var weapons: Dictionary = load_definitions().get("enemy_weapons", {})
	var value: Variant = weapons.get(profile_id, null)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func enemy_anatomy(enemy_id: String) -> Dictionary:
	var anatomy: Dictionary = load_definitions().get("enemy_anatomy", {})
	var value: Variant = anatomy.get(enemy_id, null)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func signature_vfx_profile(profile_id: String) -> Dictionary:
	var profiles: Dictionary = load_definitions().get("signature_vfx", {})
	var value: Variant = profiles.get(profile_id, null)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func vfx_profile(cue: String) -> Dictionary:
	var data := load_definitions()
	var vfx: Dictionary = data.get("vfx", {})
	var value: Variant = vfx.get(cue, null)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	# Technique cues arrive as combat.impact / guard / spell; semantic status and
	# phase cues are normalized before this lookup.
	if cue.begins_with("combat."):
		var base := cue.split(".")
		if base.size() >= 2:
			var fallback_key := "combat.%s" % base[1]
			value = vfx.get(fallback_key, null)
			if value is Dictionary:
				return (value as Dictionary).duplicate(true)
	return (vfx.get("combat.impact", {}) as Dictionary).duplicate(true)


static func resolve_loadout(battle: Dictionary) -> Dictionary:
	var source_value: Variant = battle.get("visual_loadout", {})
	var source: Dictionary = source_value if source_value is Dictionary else {}
	var result := {
		"path_id": _safe_id(source.get("path_id", battle.get("path_id", "insight")), PATH_IDS, "insight"),
		"weapon_id": _safe_equipment(source.get("weapon_id", ""), "weapon"),
		"armor_id": _safe_equipment(source.get("armor_id", ""), "armor"),
		"relic_id": _safe_equipment(source.get("relic_id", ""), "relic"),
		"jade_weapon_id": _safe_id(source.get("jade_weapon_id", ""), JADE_WEAPON_IDS, ""),
	}
	return result


static func normalize_cue(cue: String, kind: String = "") -> String:
	var normalized := cue.strip_edges()
	if normalized.is_empty():
		normalized = "combat.%s" % ("impact" if kind == "damage" else kind)
	if (load_definitions().get("vfx", {}) as Dictionary).has(normalized):
		return normalized
	if kind == "phase_shift" or normalized.find("phase") >= 0:
		return "combat.phase"
	if kind == "shield" or normalized.find("guard") >= 0:
		return "combat.guard"
	if kind == "heal" or normalized.find("heal") >= 0:
		return "combat.heal"
	if normalized.find("bleed") >= 0:
		return "combat.status.bleed"
	if normalized.find("weak") >= 0:
		return "combat.status.weak"
	return normalized if load_definitions().get("vfx", {}).has(normalized) else "combat.impact"


static func validate_definitions(data_override: Variant = null) -> Dictionary:
	var data: Dictionary = load_definitions() if data_override == null else \
		(data_override as Dictionary).duplicate(true) if data_override is Dictionary else {}
	var failures: Array[String] = []
	if int(data.get("schema_version", 0)) != 1:
		failures.append("unsupported_schema")
	var enemies: Dictionary = data.get("enemies", {})
	for enemy_id in ENEMY_IDS:
		if not enemies.has(enemy_id):
			failures.append("missing_enemy:%s" % enemy_id)
			continue
		var profile: Dictionary = enemies[enemy_id]
		if profile.get("profile_id", "") == "" or profile.get("weapon_profile_id", "") == "" or \
				profile.get("vfx_profile_id", "") == "":
			failures.append("incomplete_enemy:%s" % enemy_id)
		if enemy_weapon_profile(str(profile.get("weapon_profile_id", ""))).is_empty():
			failures.append("missing_enemy_weapon:%s" % enemy_id)
		var anatomy := enemy_anatomy(enemy_id)
		for part_id in ["head", "torso", "front_arm", "back_arm", "legs", "garment", "ornament"]:
			if not anatomy.get(part_id, []) is Array or (anatomy.get(part_id, []) as Array).is_empty():
				failures.append("missing_anatomy:%s:%s" % [enemy_id, part_id])
		if signature_vfx_profile(str(profile.get("vfx_profile_id", ""))).is_empty():
			failures.append("missing_signature_vfx:%s" % enemy_id)
		if not profile.get("body", []) is Array or (profile.get("body", []) as Array).size() < 8:
			failures.append("sparse_enemy:%s" % enemy_id)
	for path_id in PATH_IDS:
		if not (data.get("paths", {}) as Dictionary).has(path_id):
			failures.append("missing_path:%s" % path_id)
	for equipment_id in EQUIPMENT_IDS:
		if not (data.get("equipment", {}) as Dictionary).has(equipment_id):
			failures.append("missing_equipment:%s" % equipment_id)
	for weapon_id in JADE_WEAPON_IDS:
		if not (data.get("jade_weapons", {}) as Dictionary).has(weapon_id):
			failures.append("missing_jade:%s" % weapon_id)
	var hashes := {}
	for enemy_id in ENEMY_IDS:
		var profile := enemies.get(enemy_id, {}) as Dictionary
		var identity := JSON.stringify([profile.get("body", []), profile.get("marks", [])])
		var identity_hash := hash(identity)
		if hashes.has(identity_hash):
			failures.append("duplicate_identity:%s:%s" % [hashes[identity_hash], enemy_id])
		hashes[identity_hash] = enemy_id
	return {"ok": failures.is_empty(), "failures": failures, "enemy_count": ENEMY_IDS.size(),
		"path_count": PATH_IDS.size(), "equipment_count": EQUIPMENT_IDS.size(),
		"jade_weapon_count": JADE_WEAPON_IDS.size(), "vfx_count": (data.get("vfx", {}) as Dictionary).size()}


static func _safe_id(value: Variant, allowed: Array, fallback: String) -> String:
	var normalized := str(value).strip_edges().left(64)
	if normalized.is_empty() and fallback.is_empty():
		return ""
	return normalized if allowed.has(normalized) else fallback


static func _safe_equipment(value: Variant, slot: String) -> String:
	var equipment_id := str(value).strip_edges().left(64)
	if equipment_id.is_empty() or not EQUIPMENT_IDS.has(equipment_id):
		return ""
	var profile := equipment_profile(equipment_id)
	return equipment_id if str(profile.get("slot", "")) == slot else ""
