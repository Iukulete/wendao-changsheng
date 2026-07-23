extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const ItemSystemScript = preload("res://scripts/item_system.gd")
const EncounterSystemScript = preload("res://scripts/encounter_system.gd")
const CombatSystemScript = preload("res://scripts/combat_system.gd")
const CombatVisualCatalogScript = preload("res://scripts/combat_visual_catalog.gd")
const CombatStageScript = preload("res://scripts/combat_stage.gd")

var failures: Array[String] = []


func _init() -> void:
	var validation: Dictionary = CombatVisualCatalogScript.validate_definitions()
	_expect(bool(validation.get("ok", false)), "catalog definitions must validate")
	_expect(int(validation.get("enemy_count", 0)) == 18, "all 18 authored enemies must be covered")
	_expect(int(validation.get("path_count", 0)) == 6, "all six paths must be covered")
	_expect(int(validation.get("equipment_count", 0)) == 7, "all actual equipment forms must be covered")
	_expect(int(validation.get("jade_weapon_count", 0)) == 16, "all jade weapons must be covered")

	var stage: Control = CombatStageScript.new()
	var roster: Dictionary = stage.debug_validate_pixel_pipeline()
	_expect(bool(roster.get("ok", false)), "full rendered roster audit must pass")
	_expect(int(roster.get("enemy_count", 0)) == 18, "no formal enemy may use fallback art")
	_expect(int(roster.get("pose_count", 0)) == 108, "each enemy needs six distinct action poses")
	_expect(int(roster.get("path_count", 0)) == 6, "path silhouettes must differ")
	_expect(int(roster.get("jade_weapon_count", 0)) == 16, "jade weapon outlines must differ")
	_expect(int(roster.get("enemy_weapon_count", 0)) == 18, "all enemy weapon outlines must differ")
	_expect(int(roster.get("signature_vfx_count", 0)) == 18, "all enemy signature effects must differ")
	_expect(int(roster.get("vfx_count", 0)) >= 9, "semantic effect cues must differ")
	stage.free()

	var unknown_a: Dictionary = CombatVisualCatalogScript.enemy_profile("legacy_unknown_duelist")
	var unknown_b: Dictionary = CombatVisualCatalogScript.enemy_profile("legacy_unknown_duelist")
	_expect(bool(unknown_a.get("fallback", false)) and unknown_a == unknown_b,
		"unknown legacy enemy fallback must be explicit and deterministic")
	for enemy_id in CombatVisualCatalogScript.enemy_ids():
		_expect(not bool(CombatVisualCatalogScript.enemy_profile(enemy_id).get("fallback", true)),
			"formal enemy used fallback: %s" % enemy_id)

	var state: Dictionary = GameStateScript.create_new_game("Visual Loadout", 710227, [7, 7, 7, 7, 7])
	state.player.path["creation"] = 80
	var forged_weapon := {"item_id":"forged_spirit_blade", "instance_id":"forge_weapon_test",
		"quantity":1, "stackable":false, "name":"test blade", "category":"weapon", "slot":"weapon",
		"bonuses":{"attack":12}}
	var forged_armor := {"item_id":"forged_warding_armor", "instance_id":"forge_armor_test",
		"quantity":1, "stackable":false, "name":"test armor", "category":"armor", "slot":"armor",
		"bonuses":{"defense":9}}
	state.inventory.items.append(forged_weapon)
	state.inventory.items.append(forged_armor)
	state.inventory.equipped = {"weapon_id":"forge_weapon_test", "armor_id":"forge_armor_test",
		"relic_id":"black_white_jade"}
	state.legacy.armory["weapons"] = {"wuliang":{"unlocked":true, "resonance":0,
		"stage":0, "charge":0, "invocations":0}}
	state.legacy.armory["equipped_id"] = "wuliang"
	ItemSystemScript.normalize(state)
	EncounterSystemScript.offer(state, "test", "visual", "visual contract", 3,
		{"enemy_id":"immortal_fate_registrar"})
	var started: Dictionary = CombatSystemScript.start_combat(state, "immortal_fate_registrar")
	_expect(bool(started.get("ok", false)), "combat must start for loadout integration")
	var loadout: Dictionary = (started.get("battle", {}) as Dictionary).get("visual_loadout", {})
	_expect(str(loadout.get("path_id", "")) == "creation", "dominant path must reach battle visuals")
	_expect(str(loadout.get("weapon_id", "")) == "spirit_blade", "forged weapon must resolve by instance")
	_expect(str(loadout.get("armor_id", "")) == "warding_armor", "forged armor must resolve by instance")
	_expect(str(loadout.get("relic_id", "")) == "black_white_jade", "equipped relic must reach visuals")
	_expect(str(loadout.get("jade_weapon_id", "")) == "wuliang", "jade armory choice must reach visuals")

	var round_trip_value: Variant = JSON.parse_string(JSON.stringify(state))
	_expect(round_trip_value is Dictionary, "combat state must JSON round-trip")
	if round_trip_value is Dictionary:
		var round_trip: Dictionary = round_trip_value
		CombatSystemScript.normalize(round_trip)
		var restored: Dictionary = (round_trip.combat.current as Dictionary).get("visual_loadout", {})
		_expect(restored == loadout, "visual loadout must survive save normalization")
		round_trip.combat.current.visual_loadout = {
			"path_id":"x".repeat(500), "weapon_id":"cloud_robe", "armor_id":"iron_sword",
			"relic_id":"unknown_relic", "jade_weapon_id":"x".repeat(500)}
		CombatSystemScript.normalize(round_trip)
		var cleaned: Dictionary = round_trip.combat.current.visual_loadout
		_expect(str(cleaned.path_id) == "insight" and str(cleaned.weapon_id).is_empty() and
			str(cleaned.armor_id).is_empty() and str(cleaned.relic_id).is_empty() and
			str(cleaned.jade_weapon_id).is_empty(),
			"unknown, cross-slot and malicious ids must be removed")

	if failures.is_empty():
		print("COMBAT_VISUAL_CATALOG_TEST_OK: authored roster, loadout, save round-trip and hostile ids validated")
		quit(0)
		return
	for failure in failures:
		push_error("COMBAT_VISUAL_CATALOG_TEST_FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
