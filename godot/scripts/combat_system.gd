class_name CombatSystem
extends RefCounted

const ItemSystemScript = preload("res://scripts/item_system.gd")
const EncounterSystemScript = preload("res://scripts/encounter_system.gd")
const NarrativeConsequenceScript = preload("res://scripts/narrative_consequence_system.gd")
const CombatEventPipelineScript = preload("res://scripts/combat_event_pipeline.gd")
const CombatTechniqueCatalogScript = preload("res://scripts/combat_technique_catalog.gd")
const CombatVisualCatalogScript = preload("res://scripts/combat_visual_catalog.gd")

const MAX_TURNS := 48
const MAX_LOG := 40
const MAX_HISTORY := 64
const SPELL_COST := 12
const COUNTER_CHAIN_TARGET := 3
const COUNTER_BURST_PERCENT := 130
const SECOND_PHASE_THRESHOLD_PERCENT := 50
const NARRATIVE_CONTEXT_FIELDS := [
	"source_event_id", "source_choice_id", "source_choice_text", "encounter_id",
	"base_enemy_id", "enemy_id", "enemy_name",
	"motivation", "stakes", "victory_consequence", "defeat_consequence", "escape_consequence",
	"encounter_tier", "visual_profile_id", "weapon_profile_id", "vfx_profile_id",
	"rematch_key", "ally_support_id", "ally_support_name", "support_effect",
]

const ENEMY_POOLS := {
	"classical": [
		{"id": "classical_razor_wolf", "name": "断刃苍狼", "hp": 88, "attack": 18, "defense": 6,
			"intents": ["strike", "bleed", "guard"], "material": "spirit_herb", "tier": "normal",
			"visual_profile_id": "enemy.classical.razor_wolf", "weapon_profile_id": "weapon.claw.bone_razor", "vfx_profile_id": "vfx.classical.blood_scent"},
		{"id": "classical_oath_breaker", "name": "毁誓剑客", "hp": 105, "attack": 21, "defense": 9,
			"intents": ["guard", "heavy", "strike"], "material": "black_iron", "tier": "elite",
			"visual_profile_id": "enemy.classical.oath_breaker", "weapon_profile_id": "weapon.sword.broken_oath", "vfx_profile_id": "vfx.classical.oath_shards"},
		{"id": "classical_fate_registrar", "name": "司命执笔", "hp": 238, "attack": 34, "defense": 18,
			"intents": ["weaken", "guard", "heavy", "strike"], "material": "fate_thread", "tier": "boss",
			"visual_profile_id": "enemy.classical.fate_registrar", "weapon_profile_id": "weapon.brush.fate_register", "vfx_profile_id": "vfx.classical.ink_decree"},
	],
	"steam": [
		{"id": "steam_furnace_hound", "name": "赤炉机犬", "hp": 118, "attack": 24, "defense": 12,
			"intents": ["strike", "heavy", "guard"], "material": "black_iron", "tier": "normal",
			"visual_profile_id": "enemy.steam.furnace_hound", "weapon_profile_id": "weapon.jaw.rivet_furnace", "vfx_profile_id": "vfx.steam.pressure_vent"},
		{"id": "steam_debt_collector", "name": "灵轨债吏", "hp": 102, "attack": 26, "defense": 8,
			"intents": ["weaken", "strike", "heavy"], "material": "star_sand", "tier": "elite",
			"visual_profile_id": "enemy.steam.debt_collector", "weapon_profile_id": "weapon.chain.spirit_ledger", "vfx_profile_id": "vfx.steam.debt_seal"},
		{"id": "steam_blackbox_foreman", "name": "黑匣炉监", "hp": 270, "attack": 39, "defense": 20,
			"intents": ["guard", "weaken", "heavy", "bleed"], "material": "void_crystal", "tier": "boss",
			"visual_profile_id": "enemy.steam.blackbox_foreman", "weapon_profile_id": "weapon.hammer.blackbox_foundry", "vfx_profile_id": "vfx.steam.soul_furnace"},
	],
	"star_network": [
		{"id": "star_echo_hunter", "name": "星网猎忆者", "hp": 142, "attack": 30, "defense": 13,
			"intents": ["weaken", "bleed", "heavy"], "material": "star_sand", "tier": "normal",
			"visual_profile_id": "enemy.star.echo_hunter", "weapon_profile_id": "weapon.rifle.memory_lance", "vfx_profile_id": "vfx.star.echo_scan"},
		{"id": "star_void_daemon", "name": "虚航道魔", "hp": 155, "attack": 32, "defense": 15,
			"intents": ["guard", "heavy", "weaken"], "material": "void_crystal", "tier": "elite",
			"visual_profile_id": "enemy.star.void_daemon", "weapon_profile_id": "weapon.blade.phase_splitter", "vfx_profile_id": "vfx.star.void_refraction"},
		{"id": "star_ghost_archivist", "name": "幽档归档官", "hp": 292, "attack": 45, "defense": 22,
			"intents": ["weaken", "guard", "bleed", "heavy"], "material": "fate_thread", "tier": "boss",
			"visual_profile_id": "enemy.star.ghost_archivist", "weapon_profile_id": "weapon.array.archive_needles", "vfx_profile_id": "vfx.star.identity_rollback"},
	],
	"wasteland": [
		{"id": "wasteland_rain_beast", "name": "黑雨畸兽", "hp": 132, "attack": 29, "defense": 10,
			"intents": ["bleed", "strike", "heavy"], "material": "spirit_herb", "tier": "normal",
			"visual_profile_id": "enemy.wasteland.rain_beast", "weapon_profile_id": "weapon.fang.rain_corroded", "vfx_profile_id": "vfx.wasteland.black_rain"},
		{"id": "wasteland_relic_raider", "name": "拾遗劫修", "hp": 148, "attack": 31, "defense": 14,
			"intents": ["guard", "weaken", "heavy"], "material": "void_crystal", "tier": "elite",
			"visual_profile_id": "enemy.wasteland.relic_raider", "weapon_profile_id": "weapon.glaive.relic_splice", "vfx_profile_id": "vfx.wasteland.shield_plunder"},
		{"id": "wasteland_false_sun_prophet", "name": "伪日预言师", "hp": 308, "attack": 43, "defense": 19,
			"intents": ["bleed", "weaken", "heavy", "guard"], "material": "fate_thread", "tier": "boss",
			"visual_profile_id": "enemy.wasteland.false_sun_prophet", "weapon_profile_id": "weapon.censer.false_sun", "vfx_profile_id": "vfx.wasteland.ash_eclipse"},
	],
	"final_age": [
		{"id": "final_age_breath_taxer", "name": "夺息使", "hp": 112, "attack": 34, "defense": 9,
			"intents": ["weaken", "heavy", "strike"], "material": "fate_thread", "tier": "normal",
			"visual_profile_id": "enemy.final_age.breath_taxer", "weapon_profile_id": "weapon.abacus.breath_levy", "vfx_profile_id": "vfx.final_age.breath_receipt"},
		{"id": "final_age_silent_cultivator", "name": "寂法修士", "hp": 126, "attack": 32, "defense": 16,
			"intents": ["guard", "bleed", "heavy"], "material": "void_crystal", "tier": "elite",
			"visual_profile_id": "enemy.final_age.silent_cultivator", "weapon_profile_id": "weapon.bell.silent_seal", "vfx_profile_id": "vfx.final_age.silence_field"},
		{"id": "final_age_meridian_creditor", "name": "经脉债主", "hp": 326, "attack": 48, "defense": 23,
			"intents": ["weaken", "bleed", "guard", "heavy"], "material": "fate_thread", "tier": "boss",
			"visual_profile_id": "enemy.final_age.meridian_creditor", "weapon_profile_id": "weapon.needle.meridian_contract", "vfx_profile_id": "vfx.final_age.life_foreclosure"},
	],
	"immortal_dynasty": [
		{"id": "immortal_sky_enforcer", "name": "巡天仙吏", "hp": 178, "attack": 38, "defense": 18,
			"intents": ["guard", "heavy", "weaken"], "material": "fate_thread", "tier": "normal",
			"visual_profile_id": "enemy.immortal.sky_enforcer", "weapon_profile_id": "weapon.halberd.heaven_edict", "vfx_profile_id": "vfx.immortal.rotating_law"},
		{"id": "immortal_unchained_duelist", "name": "不系仙客", "hp": 165, "attack": 42, "defense": 14,
			"intents": ["strike", "bleed", "heavy"], "material": "void_crystal", "tier": "elite",
			"visual_profile_id": "enemy.immortal.unchained_duelist", "weapon_profile_id": "weapon.sword.unbound_edge", "vfx_profile_id": "vfx.immortal.unbound_cut"},
		{"id": "immortal_fate_registrar", "name": "白玉司命", "hp": 350, "attack": 52, "defense": 26,
			"intents": ["weaken", "guard", "heavy", "bleed"], "material": "fate_thread", "tier": "boss",
			"visual_profile_id": "enemy.immortal.fate_registrar", "weapon_profile_id": "weapon.brush.white_jade_fate", "vfx_profile_id": "vfx.immortal.name_erasure"},
	],
}

const GENERIC_SIGNATURE := {
	"id": "measured_exchange", "title": "临阵换势",
	"rule": "敌人会在半血后改变招路。",
	"phase_title": "换势 · 逆息成阵", "phase_rule": "后半程的意图循环已经改变。",
	"second_intents": ["heavy", "strike", "guard"],
}
const SIGNATURE_RULES := {
	"classical_razor_wolf": {
		"id": "blood_scent", "title": "嗅血追猎",
		"rule": "你身上有流血时，苍狼的伤害提高三成；守住撕裂能压低后续风险。",
		"phase_title": "血月伏脊", "phase_rule": "后半程追猎增至五成，撕裂出现得更频繁。",
		"second_intents": ["bleed", "strike", "heavy", "bleed"],
	},
	"classical_oath_breaker": {
		"id": "broken_oath_forms", "title": "破誓识式",
		"rule": "连续使用同一种斩击、守势或术法，会被识破并为敌人添一层护体。",
		"phase_title": "三誓俱断", "phase_rule": "后半程识式所得护体翻倍，更需要主动换招。",
		"second_intents": ["heavy", "guard", "weaken", "strike"],
	},
	"classical_fate_registrar": {
		"id": "ink_decree", "title": "墨诏改名",
		"rule": "司命执笔会把你最近一次使用的行动写入禁令；重复该行动会损失气血并为其加护。",
		"phase_title": "删名落款", "phase_rule": "后半程禁令连续维持两回合，触犯会同时削减灵力。",
		"second_intents": ["weaken", "guard", "weaken", "heavy"],
	},
	"steam_furnace_hound": {
		"id": "furnace_pressure", "title": "炉压刻度",
		"rule": "斩击与术法会升高炉压；三格时下一次攻击强化。守势可泄去两格。",
		"phase_title": "赤炉开闸", "phase_rule": "后半程进攻一次升两格炉压，过热攻势也更凶。",
		"second_intents": ["heavy", "strike", "heavy", "guard"],
	},
	"steam_debt_collector": {
		"id": "spirit_interest", "title": "灵息计债",
		"rule": "蚀心咒会抽走四点灵力，并把实收灵力化为敌方护体。",
		"phase_title": "复利封契", "phase_rule": "后半程每次蚀心咒改收七点灵力。",
		"second_intents": ["weaken", "guard", "heavy", "weaken"],
	},
	"steam_blackbox_foreman": {
		"id": "soul_furnace", "title": "黑匣炼魂",
		"rule": "炉监会把场上的护盾压进黑匣；护盾越高，下一次重击越痛。攻击黑匣可释放被困残识。",
		"phase_title": "炉心暴走", "phase_rule": "后半程黑匣每回合自燃，必须在结盾前打断其蓄压。",
		"second_intents": ["guard", "heavy", "bleed", "weaken"],
	},
	"star_echo_hunter": {
		"id": "memory_countermeasure", "title": "猎忆回声",
		"rule": "连续使用同一种进攻会被记忆拦截，第二次及以后只剩七成威力。",
		"phase_title": "回声合围", "phase_rule": "后半程重复进攻只剩五成威力。",
		"second_intents": ["weaken", "heavy", "bleed", "strike"],
	},
	"star_void_daemon": {
		"id": "adaptive_void_ward", "title": "虚相偏折",
		"rule": "虚相会抵消当前记住的进攻类型；每次斩击或术法都会令它改记该类型。",
		"phase_title": "两界折光", "phase_rule": "后半程被虚相记住的进攻只剩四成威力。",
		"second_intents": ["guard", "weaken", "heavy", "guard"],
	},
	"star_ghost_archivist": {
		"id": "identity_rollback", "title": "身份回档",
		"rule": "归档官会记录你本回合的行动；连续两次相同动作会回滚上一回合造成的伤害并复制该意图。",
		"phase_title": "全网回滚", "phase_rule": "后半程回滚同时清除你的护盾，必须轮换行动并保持压制。",
		"second_intents": ["weaken", "bleed", "guard", "heavy"],
	},
	"wasteland_rain_beast": {
		"id": "corrosive_black_rain", "title": "腐蚀黑雨",
		"rule": "流血每回合损失百分之四气血；守势可额外洗去两回合流血。",
		"phase_title": "雨腹决堤", "phase_rule": "后半程流血损失升至百分之六，守势只能洗去一回合。",
		"second_intents": ["bleed", "heavy", "bleed", "strike"],
	},
	"wasteland_relic_raider": {
		"id": "shield_plunder", "title": "劫盾夺器",
		"rule": "敌人结印时会夺走你至多其自身半份防御值的护盾，转入自己的护体。",
		"phase_title": "万器归匣", "phase_rule": "后半程每次结印可夺走至多其自身一份防御值的护盾。",
		"second_intents": ["guard", "heavy", "guard", "weaken"],
	},
	"wasteland_false_sun_prophet": {
		"id": "ash_eclipse", "title": "伪日蚀信",
		"rule": "预言师每次施加流血都会积攒灰烬；三层后下一次攻击遮蔽治疗并引爆流血。",
		"phase_title": "灰日坠落", "phase_rule": "后半程灰烬上限提高，爆燃会额外摧毁一半护盾。",
		"second_intents": ["bleed", "weaken", "heavy", "bleed"],
	},
	"final_age_breath_taxer": {
		"id": "breath_levy", "title": "一息一税",
		"rule": "斩击与守势各额外消耗两点灵力，术法也要在原消耗外纳税。",
		"phase_title": "百息归一", "phase_rule": "后半程每次纳税增至四点；灵力不足的武招会招致虚弱。",
		"second_intents": ["weaken", "heavy", "weaken", "strike"],
	},
	"final_age_silent_cultivator": {
		"id": "silent_seal", "title": "寂法封音",
		"rule": "每次施放术法后，必须先用一次斩击或守势破开寂印，才能再次施法。",
		"phase_title": "万籁俱寂", "phase_rule": "后半程术法会留下两重寂印，需要两次武招解开。",
		"second_intents": ["guard", "bleed", "guard", "heavy"],
	},
	"final_age_meridian_creditor": {
		"id": "life_foreclosure", "title": "经脉止赎",
		"rule": "债主会冻结你本回合获得的治疗并把失去的气血记入契额；契额过高会强制扣除最大气血。",
		"phase_title": "全身查封", "phase_rule": "后半程契额每回合增长，服丹会转为偿债而非恢复。",
		"second_intents": ["weaken", "bleed", "heavy", "guard"],
	},
	"immortal_sky_enforcer": {
		"id": "rotating_heaven_law", "title": "巡天禁令",
		"rule": "禁令在斩击、守势、术法间轮转；触犯会直接损失百分之五气血。",
		"phase_title": "天条倒悬", "phase_rule": "后半程禁令逆向轮转，触犯损失增至百分之八。",
		"second_intents": ["guard", "heavy", "weaken", "heavy"],
	},
	"immortal_unchained_duelist": {
		"id": "unbound_edge", "title": "无系剑锋",
		"rule": "所有伤害招式穿过一半现有护盾，单靠守势不能完全卸力。",
		"phase_title": "身剑两忘", "phase_rule": "后半程伤害招式完全穿盾，必须压制、疗伤或尽快决胜。",
		"second_intents": ["strike", "heavy", "bleed", "heavy"],
	},
	"immortal_fate_registrar": {
		"id": "name_erasure", "title": "白玉除名",
		"rule": "白玉司命会封存一个玩家行动；重复该行动会抹除一项战技效果并提高其下一击。",
		"phase_title": "天命空册", "phase_rule": "后半程每次触犯同时推进除名计数，三次后强制清空护盾。",
		"second_intents": ["guard", "weaken", "heavy", "bleed"],
	},
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
const ACTION_NAMES := {
	"attack": "斩击", "guard": "守势", "spell": "术法",
	"pill": "服丹", "flee": "脱战",
}
const COUNTER_ACTIONS := {
	"strike": "attack", "heavy": "guard", "guard": "spell",
	"bleed": "guard", "weaken": "spell",
}
const ALTERNATIVE_ACTIONS := {
	"strike": "guard", "heavy": "spell", "guard": "attack",
	"bleed": "attack", "weaken": "guard",
}
const COUNTER_OPTION_TEXT := {
	"strike": {
		"recommended": "抢在短击成形前压回去，推进一拍。",
		"alternative": "放弃推进，换一层护盾稳住眼前。",
	},
	"heavy": {
		"recommended": "收势承力，护盾能吃掉重击。",
		"alternative": "消耗灵力反制并施加虚弱，但会硬吃一记。",
	},
	"guard": {
		"recommended": "趁结印未完以术法穿透，推进一拍。",
		"alternative": "不耗灵力抢血，仍守住当前节拍。",
	},
	"bleed": {
		"recommended": "以护盾挡住撕裂，推进一拍。",
		"alternative": "抢先压低气血，接受流血的后续代价。",
	},
	"weaken": {
		"recommended": "以术法回敬蚀心咒，推进一拍。",
		"alternative": "先结盾保命，承受虚弱但不丢节拍。",
	},
}


static func normalize(state: Dictionary) -> Dictionary:
	var value: Variant = state.get("combat", {})
	var combat: Dictionary = value.duplicate(true) if value is Dictionary else {}
	combat["active"] = bool(combat.get("active", false))
	combat["history"] = _normalize_combat_history(combat.get("history", []))
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


static func _normalize_combat_history(value: Variant) -> Array:
	var source := _bounded_array(value, MAX_HISTORY)
	var result: Array = []
	for entry_value in source:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = (entry_value as Dictionary).duplicate(true)
		var base_enemy_id := str(entry.get("base_enemy_id", entry.get("enemy_id", ""))).strip_edges()
		var encounter_id := str(entry.get("encounter_id", entry.get("enemy_id", base_enemy_id))).strip_edges()
		entry["base_enemy_id"] = base_enemy_id.left(96)
		entry["enemy_id"] = base_enemy_id.left(96)
		entry["encounter_id"] = (encounter_id if not encounter_id.is_empty() else base_enemy_id).left(96)
		var definition := _find_enemy(base_enemy_id)
		entry["encounter_tier"] = _encounter_tier(str(entry.get("encounter_tier", "")),
			str(definition.get("tier", "normal")))
		entry["visual_profile_id"] = _profile_or_default(entry, "visual_profile_id",
			str(definition.get("visual_profile_id", "enemy.generic.unknown")))
		entry["weapon_profile_id"] = _profile_or_default(entry, "weapon_profile_id",
			str(definition.get("weapon_profile_id", "weapon.generic.unarmed")))
		entry["vfx_profile_id"] = _profile_or_default(entry, "vfx_profile_id",
			str(definition.get("vfx_profile_id", "vfx.generic.impact")))
		var narrative_context_value: Variant = entry.get("narrative_context", null)
		if narrative_context_value is Dictionary:
			entry["narrative_context"] = _normalize_narrative_context(narrative_context_value)
		result.append(entry)
	return result


static func has_active_combat(state: Dictionary) -> bool:
	return bool(normalize(state).active)


static func start_combat(state: Dictionary, enemy_id: String = "") -> Dictionary:
	var combat := normalize(state)
	if bool(combat.active):
		return {"ok": false, "code": "combat_already_active", "battle": combat.current}
	if bool((state.get("dungeon", {}) as Dictionary).get("active", false)):
		return {"ok": false, "code": "dungeon_active"}
	var expiry := EncounterSystemScript.expire_if_needed(state)
	if bool(expiry.get("expired", false)):
		return {"ok": false, "code": "encounter_expired",
			"message": str(expiry.get("message", "敌踪已经消散。"))}
	var encounter: Dictionary = EncounterSystemScript.summary(state)
	if not bool(encounter.get("active", false)):
		return {"ok": false, "code": "encounter_required",
			"message": "此刻没有由剧情选择引来的敌踪。"}
	var era_id := str(state.get("current_era_id", "classical"))
	# Story encounters carry an authored identity and a roster definition separately.
	# The latter is the only source for combat math and signature mechanics.
	var contextual_base_enemy_id := str(encounter.get("base_enemy_id", "")).strip_edges()
	if contextual_base_enemy_id.is_empty():
		contextual_base_enemy_id = str(encounter.get("enemy_id", "")).strip_edges()
	if contextual_base_enemy_id.is_empty():
		contextual_base_enemy_id = enemy_id.strip_edges()
	if not contextual_base_enemy_id.is_empty():
		enemy_id = contextual_base_enemy_id
	var definition := _find_enemy(contextual_base_enemy_id)
	if definition.is_empty():
		var pool: Array = ENEMY_POOLS.get(era_id, ENEMY_POOLS.classical)
		definition = (pool[_roll(state, 0, pool.size() - 1)] as Dictionary).duplicate(true)
	var player: Dictionary = state.get("player", {})
	var effective: Dictionary = ItemSystemScript.effective_stats(state)
	var realm_index := clampi(int(player.get("realm_index", 0)), 0, 20)
	var level := clampi(int(player.get("level", 1)), 1, 9)
	var scale_percent := 100 + realm_index * 32 + (level - 1) * 14
	var enemy_hp := maxi(20, int(definition.hp) * scale_percent / 100)
	var enemy_attack := maxi(4, int(definition.attack) * scale_percent / 100)
	var enemy_defense := maxi(0, int(definition.defense) * scale_percent / 100)
	var hp_bonus := maxi(0, int(effective.max_hp) - int(player.get("max_hp", 1)))
	var narrative_context := _normalize_narrative_context(encounter)
	var enemy_display_name := str(narrative_context.get("enemy_name", "")).strip_edges()
	if enemy_display_name.is_empty():
		enemy_display_name = str(definition.name)
	var authored_encounter_id := str(narrative_context.get("encounter_id", "")).strip_edges()
	if authored_encounter_id.is_empty():
		authored_encounter_id = contextual_base_enemy_id if not contextual_base_enemy_id.is_empty() else \
		str(definition.id)
	var encounter_tier := _encounter_tier(
		str(narrative_context.get("encounter_tier", "")), str(definition.get("tier", "normal")))
	var visual_profile_id := _profile_or_default(narrative_context, "visual_profile_id",
		str(definition.get("visual_profile_id", "enemy.generic.unknown")))
	var weapon_profile_id := _profile_or_default(narrative_context, "weapon_profile_id",
		str(definition.get("weapon_profile_id", "weapon.generic.unarmed")))
	var vfx_profile_id := _profile_or_default(narrative_context, "vfx_profile_id",
		str(definition.get("vfx_profile_id", "vfx.generic.impact")))
	var signature := _signature_for_enemy(str(definition.id))
	var visual_loadout := _visual_loadout_for_state(state)
	var signature_state := _initial_signature_state(str(signature.get("id", "")))
	var second_phase_cycle := _normalize_intent_cycle(signature.get("second_intents", []),
		_second_phase_cycle(definition.intents as Array))
	var opening_log: Array = []
	if not str(narrative_context.get("motivation", "")).is_empty():
		opening_log.append(str(narrative_context.motivation))
	if not str(narrative_context.get("stakes", "")).is_empty():
		opening_log.append(str(narrative_context.stakes))
	opening_log.append("%s拦住去路，第一道意图是%s。" % [enemy_display_name,
		INTENT_NAMES[definition.intents[0]]])
	var battle := {
		"id": "battle_%s" % ("%s|%s|%s|%d|%d" % [state.get("run_id", "run"),
			authored_encounter_id, definition.id, state.get("turn", 0),
			state.get("rng_cursor", 0)]).sha256_text().left(16),
		"outcome": "active", "turn": 1, "max_turns": MAX_TURNS,
		"era_id": era_id, "player_hp": mini(int(effective.max_hp), int(player.get("hp", 1)) + hp_bonus),
		"player_max_hp": int(effective.max_hp), "player_mp": int(player.get("mp", 0)),
		"player_max_mp": int(effective.max_mp), "player_attack": int(effective.attack),
		"player_defense": int(effective.defense), "player_hp_bonus": hp_bonus,
		"player_statuses": {"bleed": 0, "weak": 0, "shield": 0},
		"encounter_id": authored_encounter_id, "base_enemy_id": str(definition.id),
		"enemy_id": str(definition.id), "enemy_name": enemy_display_name,
		"visual_loadout": visual_loadout,
		"encounter_tier": encounter_tier,
		"visual_profile_id": visual_profile_id,
		"weapon_profile_id": weapon_profile_id,
		"vfx_profile_id": vfx_profile_id,
		"enemy_hp": enemy_hp, "enemy_max_hp": enemy_hp, "enemy_attack": enemy_attack,
		"enemy_defense": enemy_defense, "enemy_statuses": {"bleed": 0, "weak": 0, "shield": 0},
		"intent_cycle": (definition.intents as Array).duplicate(),
		"base_intent_cycle": (definition.intents as Array).duplicate(),
		"second_phase_cycle": second_phase_cycle, "intent_index": 0,
		"intent": str((definition.intents as Array)[0]), "material": str(definition.material),
		"counter_chain": 0, "best_counter_chain": 0,
		"counter_target": COUNTER_CHAIN_TARGET, "counter_burst_ready": false,
		"counter_completions": 0, "counter_bursts_used": 0,
		"action_counts": {}, "technique_counts": {}, "counter_role_counts": {},
		"second_phase_active": false, "second_phase_triggered_turn": 0,
		"second_phase_trigger_count": 0, "phase_shift_pending": false,
		"phase_title": str(signature.get("phase_title", "换势 · 逆息成阵")),
		"signature_id": str(signature.get("id", GENERIC_SIGNATURE.id)),
		"signature_title": str(signature.get("title", GENERIC_SIGNATURE.title)),
		"signature_rule": str(signature.get("rule", GENERIC_SIGNATURE.rule)),
		"signature_phase_rule": str(signature.get("phase_rule", GENERIC_SIGNATURE.phase_rule)),
		"signature_state": signature_state,
		"log": opening_log,
		"event_history": [],
		"narrative_context": narrative_context,
		"rewards": {},
	}
	_apply_ally_support(battle, narrative_context)
	var consumed := EncounterSystemScript.consume(state)
	if not bool(consumed.get("ok", false)):
		return {"ok": false, "code": "encounter_consume_failed"}
	combat["active"] = true
	combat["current"] = battle
	state["combat"] = combat
	return {"ok": true, "code": "combat_started", "battle": battle}


static func _apply_ally_support(battle: Dictionary, context: Dictionary) -> void:
	var ally_id := str(context.get("ally_support_id", "")).strip_edges()
	if ally_id.is_empty():
		return
	var ally_name := str(context.get("ally_support_name", ally_id))
	var effect := str(context.get("support_effect", "opening_shield"))
	match effect:
		"enemy_weak":
			var enemy_statuses: Dictionary = battle.get("enemy_statuses", {})
			enemy_statuses["weak"] = 2
			battle["enemy_statuses"] = enemy_statuses
		"restore_mp":
			battle["player_mp"] = mini(int(battle.get("player_max_mp", 0)),
				int(battle.get("player_mp", 0)) + 12)
		_:
			var player_statuses: Dictionary = battle.get("player_statuses", {})
			player_statuses["shield"] = maxi(int(player_statuses.get("shield", 0)),
				maxi(8, int(battle.get("player_defense", 0)) / 2))
			battle["player_statuses"] = player_statuses
	battle["ally_support_id"] = ally_id
	battle["ally_support_name"] = ally_name
	battle["support_effect"] = effect
	_append_log(battle, "%s应约加入战局，支援效果：%s。" % [ally_name, effect])


static func perform_action(state: Dictionary, action: String) -> Dictionary:
	return _perform_action(state, action, {})


static func perform_technique(state: Dictionary, technique_id: String) -> Dictionary:
	for technique_value in CombatTechniqueCatalogScript.slots_for_state(state):
		if not technique_value is Dictionary:
			continue
		var technique: Dictionary = technique_value
		if str(technique.get("id", "")) == technique_id:
			return _perform_action(state, str(technique.get("base_action", "")), technique)
	return {"ok": false, "code": "technique_not_in_loadout", "technique_id": technique_id}


static func technique_slots(state: Dictionary) -> Array:
	return CombatTechniqueCatalogScript.slots_for_state(state)


static func _perform_action(state: Dictionary, action: String, technique: Dictionary) -> Dictionary:
	var combat := normalize(state)
	if not bool(combat.active):
		return {"ok": false, "code": "no_active_combat"}
	var battle: Dictionary = combat.current.duplicate(true)
	if action not in ["attack", "guard", "spell", "pill", "flee"]:
		return {"ok": false, "code": "unknown_action", "battle": battle}
	var technique_id := str(technique.get("id", ""))
	var technique_cost := int(technique.get("cost", 0)) if not technique_id.is_empty() else 0
	if not technique_id.is_empty() and int(battle.player_mp) < technique_cost:
		return {"ok": false, "code": "insufficient_mp", "battle": battle,
			"technique_id": technique_id, "required_mp": technique_cost}
	if technique_id.is_empty() and action == "spell" and int(battle.player_mp) < _spell_cost(battle):
		return {"ok": false, "code": "insufficient_mp", "battle": battle}
	if action == "pill" and ItemSystemScript.count(state, "healing_pill") <= 0 and \
		int((state.get("player", {}) as Dictionary).get("pills", 0)) <= 0:
		return {"ok": false, "code": "no_healing_pill", "battle": battle}
	if action == "pill" and int(battle.player_hp) >= int(battle.player_max_hp):
		return {"ok": false, "code": "hp_full", "battle": battle}
	var signature_block := _signature_action_block(battle, action)
	if not signature_block.is_empty():
		return {"ok": false, "code": "signature_action_blocked", "battle": battle,
			"message": signature_block}

	var event_action_id := technique_id if not technique_id.is_empty() else action
	var action_display_name := str(technique.get("name", action_name(action)))
	var event := CombatEventPipelineScript.begin(battle, event_action_id)
	CombatEventPipelineScript.advance(event, "before_action")
	CombatEventPipelineScript.emit(event, "action", "player", "battle",
		"你选择了%s。" % action_display_name, 0, "combat_action_selected",
		{"action_id": action, "technique_id": technique_id})
	var action_role_id := "utility" if str(technique.get("slot", "")) == "turn" else \
		counter_action_role(battle, action)
	_record_action(battle, action, action_role_id, technique_id)
	var player_bleed := _apply_bleed_start(battle, true)
	if player_bleed > 0:
		CombatEventPipelineScript.emit(event, "damage", "system", "player",
			"旧伤在运气前迸开。", player_bleed, "combat_bleed_tick",
			{"status_id": "bleed"})
	var enemy_bleed := _apply_bleed_start(battle, false)
	if enemy_bleed > 0:
		CombatEventPipelineScript.emit(event, "damage", "system", "enemy",
			"伤口继续夺走对手气血。", enemy_bleed, "combat_bleed_tick",
			{"status_id": "bleed"})
	var signature_before := _apply_signature_before_player_action(battle, action, technique_cost,
		not technique_id.is_empty())
	if not signature_before.is_empty():
		_append_log(battle, signature_before)
		CombatEventPipelineScript.emit(event, "signature", "enemy", "battle",
			signature_before, 0, "combat_signature_trigger",
			{"signature_id": str(battle.get("signature_id", ""))})
	if int(battle.player_hp) <= 0:
		return _finish(state, battle, "defeat", event)
	if int(battle.enemy_hp) <= 0:
		return _finish(state, battle, "victory", event)

	CombatEventPipelineScript.advance(event, "action_begin")
	CombatEventPipelineScript.emit(event, "action", "player", "enemy",
		"%s起手。" % action_display_name, 0, "combat_action_begin",
		{"action_id": action, "technique_id": technique_id, "role": action_role_id})
	var burst_used := bool(battle.get("counter_burst_ready", false)) and \
		action in ["attack", "spell"] and (technique_id.is_empty() or \
			(technique.get("effects", {}) as Dictionary).has("damage"))
	if burst_used:
		battle["counter_burst_ready"] = false
		battle["counter_chain"] = 0
		battle["counter_bursts_used"] = int(battle.get("counter_bursts_used", 0)) + 1
	CombatEventPipelineScript.advance(event, "action_content")
	var action_result := _apply_player_technique(state, battle, technique, burst_used) \
		if not technique_id.is_empty() else _apply_player_action(state, battle, action, burst_used)
	_append_log(battle, str(action_result.message))
	_emit_action_result(event, action_result, "player", "enemy")
	CombatEventPipelineScript.advance(event, "action_end")
	var signature_after := _apply_signature_after_player_action(battle, action)
	if not signature_after.is_empty():
		_append_log(battle, signature_after)
		CombatEventPipelineScript.emit(event, "signature", "enemy", "battle",
			signature_after, 0, "combat_signature_trigger",
			{"signature_id": str(battle.get("signature_id", ""))})
	var counter_feedback := _advance_counter_chain(battle, action, action_role_id)
	if not counter_feedback.is_empty():
		_append_log(battle, counter_feedback)
		CombatEventPipelineScript.emit(event, "counter", "player", "battle",
			counter_feedback, int(battle.get("counter_chain", 0)), "combat_counter_step",
			{"role": action_role_id, "burst_ready": bool(battle.get("counter_burst_ready", false))})
	CombatEventPipelineScript.advance(event, "after_action")
	if action == "flee" and bool(action_result.success):
		return _finish(state, battle, "escaped", event)
	if int(battle.enemy_hp) <= 0:
		return _finish(state, battle, "victory", event)
	var phase_triggered := _trigger_second_phase_if_needed(battle)
	if phase_triggered:
		CombatEventPipelineScript.emit(event, "phase_shift", "enemy", "battle",
			"%s的气息开始逆转。" % str(battle.get("enemy_name", "敌手")), 0,
			"combat_phase_warning", {"phase_title": str(battle.get("phase_title", "换势"))})

	CombatEventPipelineScript.advance(event, "before_enemy")
	CombatEventPipelineScript.emit(event, "intent", "enemy", "player",
		"%s将要施展%s。" % [str(battle.get("enemy_name", "敌手")),
			intent_name(str(battle.get("intent", "strike")))], 0, "combat_intent_commit",
		{"intent_id": str(battle.get("intent", "strike"))})
	CombatEventPipelineScript.advance(event, "enemy_begin")
	CombatEventPipelineScript.advance(event, "enemy_content")
	var enemy_result := _apply_enemy_intent(state, battle)
	_append_log(battle, str(enemy_result.message))
	_emit_action_result(event, enemy_result, "enemy", "player")
	CombatEventPipelineScript.advance(event, "enemy_end")
	_tick_duration_statuses(battle)
	CombatEventPipelineScript.advance(event, "after_enemy")
	var phase_shifted := _apply_pending_second_phase(battle)
	if phase_shifted:
		CombatEventPipelineScript.emit(event, "phase_shift", "enemy", "battle",
			"%s完成换势：%s。" % [str(battle.get("enemy_name", "敌手")),
				str(battle.get("phase_title", "换势"))], 0, "combat_phase_shift",
			{"phase_title": str(battle.get("phase_title", "换势")),
				"intent_id": str(battle.get("intent", "strike"))})
	if int(battle.player_hp) <= 0:
		return _finish(state, battle, "defeat", event)
	CombatEventPipelineScript.advance(event, "turn_end")
	battle["turn"] = int(battle.turn) + 1
	if int(battle.turn) > int(battle.max_turns):
		return _finish(state, battle, "escaped", event)
	var cycle: Array = battle.intent_cycle
	if not phase_shifted:
		battle["intent_index"] = (int(battle.intent_index) + 1) % cycle.size()
	battle["intent"] = str(cycle[int(battle.intent_index)])
	CombatEventPipelineScript.emit(event, "intent", "enemy", "player",
		"下一拍：%s。" % intent_name(str(battle.intent)), 0, "combat_next_intent",
		{"intent_id": str(battle.intent)})
	CombatEventPipelineScript.complete(event, {"outcome": "active", "next_turn": int(battle.turn),
		"next_intent": str(battle.intent)})
	CombatEventPipelineScript.append_history(battle, event)
	combat["current"] = battle
	state["combat"] = combat
	return {"ok": true, "code": "turn_resolved", "battle": battle,
		"action": action, "technique_id": technique_id, "action_role": action_role_id,
		"second_phase_triggered": phase_triggered,
		"second_phase_shifted": phase_shifted, "enemy_intent": str(battle.intent),
		"event": event}


static func auto_resolve(state: Dictionary, action_limit: int = MAX_TURNS) -> Dictionary:
	var limit := clampi(action_limit, 1, MAX_TURNS)
	var actions := 0
	var last_result: Dictionary = {"ok": false, "code": "no_active_combat"}
	while has_active_combat(state) and actions < limit:
		var battle: Dictionary = state.combat.current
		var action := _auto_select_action(state, battle, actions)
		last_result = perform_action(state, action)
		actions += 1
		if not bool(last_result.get("ok", false)):
			var fallback := _auto_fallback_action(state, battle, action)
			if fallback != action:
				last_result = perform_action(state, fallback)
			if not bool(last_result.get("ok", false)):
				last_result = perform_action(state, "guard")
	if has_active_combat(state):
		var battle: Dictionary = state.combat.current
		last_result = _finish(state, battle, "escaped")
	last_result["actions"] = actions
	return last_result


static func _auto_select_action(state: Dictionary, battle: Dictionary, turn_index: int) -> String:
	if int(battle.get("player_hp", 0)) * 100 <= int(battle.get("player_max_hp", 1)) * 32 and \
			_action_available(state, battle, "pill"):
		return "pill"
	var options := counter_options(str(battle.get("intent", "strike")))
	var preferred := str(options.get("recommended", "attack"))
	var alternative := str(options.get("alternative", "guard"))
	var burst_ready := bool(battle.get("counter_burst_ready", false))
	# Periodically take the lower-commitment line so automated coverage exercises
	# the same visible tradeoff as a player, while still prioritising a ready burst.
	var should_take_alternative := not burst_ready and turn_index > 0 and turn_index % 5 == 1
	var candidates: Array[String] = []
	if should_take_alternative:
		candidates = [alternative, preferred]
	else:
		candidates = [preferred, alternative]
	if burst_ready:
		candidates = [preferred, alternative, "attack", "spell"]
	for candidate in candidates:
		if _action_available(state, battle, candidate):
			return candidate
	return "attack"


static func _auto_fallback_action(state: Dictionary, battle: Dictionary, attempted: String) -> String:
	var options := counter_options(str(battle.get("intent", "strike")))
	for candidate in [str(options.get("recommended", "attack")),
		str(options.get("alternative", "guard")), "pill", "guard", "attack"]:
		if candidate != attempted and _action_available(state, battle, candidate):
			return candidate
	return attempted


static func _action_available(state: Dictionary, battle: Dictionary, action: String) -> bool:
	if not _signature_action_block(battle, action).is_empty() or \
			_signature_auto_avoids_action(battle, action):
		return false
	if action == "spell":
		return int(battle.get("player_mp", 0)) >= _spell_cost(battle)
	if action == "pill":
		return int(battle.get("player_hp", 0)) < int(battle.get("player_max_hp", 1)) and \
			(ItemSystemScript.count(state, "healing_pill") > 0 or
			int((state.get("player", {}) as Dictionary).get("pills", 0)) > 0)
	return action in ["attack", "guard", "flee"]


static func intent_label(battle: Dictionary) -> String:
	return intent_name(str(battle.get("intent", "strike")))


static func intent_name(intent_id: String) -> String:
	return str(INTENT_NAMES.get(intent_id, "未知意图"))


static func counter_action(intent_id: String) -> String:
	return str(COUNTER_ACTIONS.get(intent_id, "attack"))


static func alternative_action(intent_id: String) -> String:
	return str(ALTERNATIVE_ACTIONS.get(intent_id, "guard"))


static func counter_options(intent_id: String) -> Dictionary:
	var normalized_intent := intent_id if INTENT_NAMES.has(intent_id) else "strike"
	var recommended := counter_action(normalized_intent)
	var alternative := alternative_action(normalized_intent)
	var copy: Dictionary = (COUNTER_OPTION_TEXT.get(normalized_intent, {}) as Dictionary).duplicate(true)
	return {
		"intent": normalized_intent,
		"recommended": recommended,
		"recommended_name": action_name(recommended),
		"recommended_text": str(copy.get("recommended", "推进一拍。")),
		"alternative": alternative,
		"alternative_name": action_name(alternative),
		"alternative_text": str(copy.get("alternative", "保住当前节拍。")),
	}


static func _counter_forecast_fields(intent_id: String) -> Dictionary:
	var options := counter_options(intent_id)
	return {
		"recommended_action": str(options.recommended),
		"recommended_action_name": str(options.recommended_name),
		"recommended_text": str(options.recommended_text),
		"alternative_action": str(options.alternative),
		"alternative_action_name": str(options.alternative_name),
		"alternative_text": str(options.alternative_text),
	}


static func counter_action_role(battle: Dictionary, action: String) -> String:
	var intent := str(battle.get("intent", "strike"))
	if action == counter_action(intent):
		return "recommended"
	if action == alternative_action(intent):
		return "alternative"
	if action == "pill":
		return "utility"
	if action == "flee":
		return "withdraw"
	return "unsuitable"


static func action_name(action_id: String) -> String:
	return str(ACTION_NAMES.get(action_id, "应变"))


static func intent_description(battle: Dictionary) -> String:
	return str(INTENT_DESCRIPTIONS.get(str(battle.get("intent", "strike")), "敌意尚未完全显形。"))


static func intent_forecast(battle: Dictionary) -> Dictionary:
	var intent := str(battle.get("intent", "strike"))
	var counter_id := counter_action(intent)
	var option_fields := _counter_forecast_fields(intent)
	var signature_fields := _signature_intent_forecast(battle, intent)
	if intent == "guard":
		var guard_base := maxi(4, int(battle.get("enemy_defense", 0)))
		var guard_roll := maxi(2, int(battle.get("enemy_defense", 0)) / 2)
		var guard_max := maxi(4, int(battle.get("enemy_defense", 0)) + guard_roll)
		var guard_forecast := {
			"intent": intent, "kind": "guard", "threat": "蓄势",
			"min_shield": guard_base, "max_shield": guard_max,
			"status": "护盾", "counter": "敌方本回合不会造成伤害；趁其结印蓄势，术法可绕过一半护体。",
			"counter_action": counter_id, "counter_action_name": action_name(counter_id),
			"lethal": false,
		}
		guard_forecast.merge(option_fields)
		guard_forecast.merge(signature_fields)
		return guard_forecast
	var attack_profile := _enemy_attack_profile(battle, intent)
	var power := int(attack_profile.get("power", 1))
	var variance := int(attack_profile.get("variance", 14))
	var shield_pierce := int(attack_profile.get("shield_pierce_percent", 0))
	var visible_shield := int((battle.get("player_statuses", {}) as Dictionary).get("shield", 0))
	var effective_shield := visible_shield * (100 - shield_pierce) / 100
	var damage_range := _damage_range(power, int(battle.get("player_defense", 0)),
		variance, effective_shield)
	var status := ""
	var counter := "斩击与术法都可抢先压低敌方气血。"
	var threat := "常规"
	if intent == "heavy":
		threat = "高危"
		counter = "蓄势重击伤害最高；守势生成的护盾能直接抵消这段伤害。"
	elif intent == "bleed":
		threat = "持续"
		status = "流血 3回合"
		counter = "撕裂会留下持续伤害；尽快压制敌人，或用守势削减首次命中。"
	elif intent == "weaken":
		threat = "压制"
		status = "虚弱 2回合"
		counter = "蚀心咒会压低后续输出；术法反施虚弱可削减敌方攻势。"
	var lethal := int(damage_range.max_damage) >= int(battle.get("player_hp", 1))
	if lethal:
		threat = "致命"
		counter = "预测上限足以令你气血归零；优先守势或服丹，不宜赌伤害波动。"
	var forecast := {
		"intent": intent, "kind": "damage", "threat": threat,
		"min_damage": int(damage_range.min_damage), "max_damage": int(damage_range.max_damage),
		"status": status, "counter": counter, "lethal": lethal,
		"counter_action": counter_id, "counter_action_name": action_name(counter_id),
		"shield_pierce_percent": shield_pierce,
	}
	forecast.merge(option_fields)
	forecast.merge(signature_fields)
	return forecast


static func action_forecasts(state: Dictionary, battle: Dictionary) -> Dictionary:
	var weak_scale := 75 if int((battle.get("player_statuses", {}) as Dictionary).get("weak", 0)) > 0 else 100
	var burst_ready := bool(battle.get("counter_burst_ready", false))
	var burst_scale := COUNTER_BURST_PERCENT if burst_ready else 100
	var attack_signature_scale := _signature_player_power_percent(battle, "attack")
	var spell_signature_scale := _signature_player_power_percent(battle, "spell")
	var attack_power := int(battle.get("player_attack", 0)) * weak_scale / 100 * burst_scale / 100 * \
		attack_signature_scale / 100
	var attack_range := _damage_range(attack_power, int(battle.get("enemy_defense", 0)),
		18, int((battle.get("enemy_statuses", {}) as Dictionary).get("shield", 0)))
	var spell_power := int(round(int(battle.get("player_attack", 0)) * 1.45)) * weak_scale / 100 * \
		burst_scale / 100 * spell_signature_scale / 100
	var spell_range := _damage_range(spell_power, int(battle.get("enemy_defense", 0)) / 2,
		12, int((battle.get("enemy_statuses", {}) as Dictionary).get("shield", 0)))
	var defense := int(battle.get("player_defense", 0))
	var guard_base := maxi(4, defense)
	var guard_roll := maxi(2, defense / 2)
	var guard_max := maxi(4, defense + guard_roll)
	var heal := mini(int(battle.get("player_max_hp", 1)) - int(battle.get("player_hp", 0)),
		maxi(1, int(battle.get("player_max_hp", 1)) * 40 / 100))
	var pill_count := ItemSystemScript.count(state, "healing_pill") + \
		int((state.get("player", {}) as Dictionary).get("pills", 0))
	var flee_chance := clampi(42 + int((state.get("player", {}) as Dictionary).get("realm_index", 0)) * 2 -
		int(battle.get("turn", 1)), 18, 82)
	var forecasts := {
		"attack": {"min_damage": int(attack_range.min_damage), "max_damage": int(attack_range.max_damage),
			"bleed_chance": 22, "burst_ready": burst_ready,
			"counter_role": counter_action_role(battle, "attack")},
		"guard": {"min_shield": guard_base, "max_shield": guard_max,
			"counter_role": counter_action_role(battle, "guard")},
		"spell": {"min_damage": int(spell_range.min_damage), "max_damage": int(spell_range.max_damage),
			"mp_cost": _spell_cost(battle), "applies_weak": true, "burst_ready": burst_ready,
			"counter_role": counter_action_role(battle, "spell")},
		"pill": {"heal": maxi(0, heal), "count": maxi(0, pill_count),
			"counter_role": counter_action_role(battle, "pill")},
		"flee": {"chance": flee_chance,
			"counter_role": counter_action_role(battle, "flee")},
	}
	for action_id in forecasts:
		(forecasts[action_id] as Dictionary).merge(_signature_action_forecast(battle, str(action_id)))
	return forecasts


static func technique_forecasts(state: Dictionary, battle: Dictionary) -> Array:
	var result: Array = []
	for technique_value in technique_slots(state):
		if not technique_value is Dictionary:
			continue
		var technique: Dictionary = technique_value
		var base_action := str(technique.get("base_action", ""))
		var profile := _technique_effect_profile(battle, technique,
			bool(battle.get("counter_burst_ready", false)))
		var signature := _signature_action_forecast(battle, base_action)
		var cost := int(technique.get("cost", 0))
		var available := bool(signature.get("available", true)) and \
			int(battle.get("player_mp", 0)) >= cost
		var blocked_reason := str(signature.get("blocked_reason", ""))
		if int(battle.get("player_mp", 0)) < cost:
			blocked_reason = "灵力不足"
		var forecast := technique.duplicate(true)
		forecast["available"] = available
		forecast["blocked_reason"] = blocked_reason
		forecast["mp_cost"] = cost
		forecast["mp_gain"] = int(profile.get("mp_gain", 0))
		forecast["heal"] = int(profile.get("heal", 0))
		forecast["shield"] = int(profile.get("block", 0))
		forecast["burst_ready"] = bool(profile.get("burst_used", false))
		forecast["counter_role"] = "utility" if str(technique.get("slot", "")) == "turn" \
			else counter_action_role(battle, base_action)
		forecast["effect_tags"] = CombatTechniqueCatalogScript.effect_tags(technique)
		if int(profile.get("damage_power", 0)) > 0:
			var damage_range := _damage_range(int(profile.damage_power),
				int(profile.enemy_defense), int(profile.variance),
				int((battle.get("enemy_statuses", {}) as Dictionary).get("shield", 0)))
			forecast["min_damage"] = int(damage_range.min_damage)
			forecast["max_damage"] = int(damage_range.max_damage)
		else:
			forecast["min_damage"] = 0
			forecast["max_damage"] = 0
		forecast.merge(signature)
		forecast["available"] = available
		forecast["blocked_reason"] = blocked_reason
		result.append(forecast)
	return result


static func battle_objective(battle: Dictionary) -> Dictionary:
	var progress := clampi(int(battle.get("counter_chain", 0)), 0, COUNTER_CHAIN_TARGET)
	var ready := bool(battle.get("counter_burst_ready", false))
	var context_value: Variant = battle.get("narrative_context", {})
	var context: Dictionary = context_value if context_value is Dictionary else {}
	var status := "先看对方怎么换气。连着拿住三手，就有破绽可借。"
	if ready:
		status = "破绽已经露出来了。下一次斩击或术法会重三成。"
	elif progress > 0:
		status = "还差%d手。别让刚摸到的节拍断掉。" % (COUNTER_CHAIN_TARGET - progress)
	var signature := signature_snapshot(battle)
	return {
		"id": "three_beat_counter", "title": "三拍破势",
		"progress": progress, "target": COUNTER_CHAIN_TARGET, "ready": ready,
		"phase": 2 if bool(battle.get("second_phase_active", false)) else 1,
		"phase_title": str(battle.get("phase_title", "换势 · 逆息成阵")),
		"phase_shift_pending": bool(battle.get("phase_shift_pending", false)),
		"status": status, "stakes": str(context.get("stakes", "")).strip_edges(),
		"motivation": str(context.get("motivation", "")).strip_edges(),
		"escape_consequence": str(context.get("escape_consequence", "")).strip_edges(),
		"signature": signature,
		"signature_title": str(signature.get("title", "")),
		"signature_rule": str(signature.get("rule", "")),
		"signature_status": str(signature.get("status", "")),
		"signature_phase_rule": str(signature.get("phase_rule", "")),
	}


static func _technique_effect_profile(battle: Dictionary, technique: Dictionary,
		burst_ready: bool = false) -> Dictionary:
	var effects_value: Variant = technique.get("effects", {})
	var effects: Dictionary = effects_value if effects_value is Dictionary else {}
	var base_action := str(technique.get("base_action", "spell"))
	var weak_scale := 75 if int((battle.get("player_statuses", {}) as Dictionary).get("weak", 0)) > 0 else 100
	var burst_scale := COUNTER_BURST_PERCENT if burst_ready and effects.has("damage") else 100
	var damage_units := int(effects.get("damage", 0))
	var damage_power := 0
	if damage_units > 0:
		damage_power = maxi(damage_units, int(battle.get("player_attack", 0)) * damage_units / 10)
		damage_power = damage_power * weak_scale / 100 * burst_scale / 100 * \
			_signature_player_power_percent(battle, base_action) / 100
	var block_units := int(effects.get("block", 0))
	var block := maxi(0, block_units)
	if block_units > 0:
		block = maxi(block_units, int(battle.get("player_defense", 0)) * block_units / 10)
	var heal_units := int(effects.get("heal", 0))
	var heal := maxi(0, heal_units)
	if heal_units > 0:
		heal = maxi(heal_units, int(battle.get("player_max_hp", 1)) * heal_units / 100)
	var status_value: Variant = effects.get("status", {})
	var status: Dictionary = status_value if status_value is Dictionary else {}
	return {
		"damage_power": damage_power,
		"block": block,
		"heal": heal,
		"mp_gain": maxi(0, int(effects.get("mp", 0))),
		"status": status.duplicate(true),
		"variance": 12 if base_action == "spell" else 18,
		"enemy_defense": int(battle.get("enemy_defense", 0)) / 2 if base_action == "spell" else \
			int(battle.get("enemy_defense", 0)),
		"burst_used": burst_ready and effects.has("damage") and base_action in ["attack", "spell"],
	}


static func _apply_player_technique(state: Dictionary, battle: Dictionary,
		technique: Dictionary, burst_used: bool) -> Dictionary:
	var technique_id := str(technique.get("id", ""))
	var technique_name := str(technique.get("name", "战技"))
	var cost := int(technique.get("cost", 0))
	battle["player_mp"] = maxi(0, int(battle.get("player_mp", 0)) - cost)
	var profile := _technique_effect_profile(battle, technique, burst_used)
	var effects_value: Variant = technique.get("effects", {})
	var effects: Dictionary = effects_value if effects_value is Dictionary else {}
	var effect_events: Array = []
	var message_parts: Array[String] = []
	var damage := 0
	if int(profile.get("damage_power", 0)) > 0:
		damage = _deal_damage(state, battle, false, int(profile.damage_power),
			int(profile.enemy_defense), int(profile.variance))
		message_parts.append("造成%d点伤害" % damage)
		effect_events.append({"kind": "damage", "actor": "player", "target": "enemy",
			"text": "%s命中，削去%d点气血。" % [technique_name, damage], "value": damage,
			"cue": str(technique.get("cue", "combat.impact")),
			"data": {"technique_id": technique_id}})
	var shield := int(profile.get("block", 0))
	if shield > 0:
		var player_statuses: Dictionary = battle.get("player_statuses", {})
		player_statuses["shield"] = int(player_statuses.get("shield", 0)) + shield
		battle["player_statuses"] = player_statuses
		message_parts.append("凝成%d点护盾" % shield)
		effect_events.append({"kind": "shield", "actor": "player", "target": "player",
			"text": "护体纹路增加%d点。" % shield, "value": shield,
			"cue": "combat.guard", "data": {"technique_id": technique_id}})
	var heal_cap := maxi(0, int(battle.get("player_max_hp", 1)) - int(battle.get("player_hp", 0)))
	var healed := mini(heal_cap, int(profile.get("heal", 0)))
	if healed > 0:
		battle["player_hp"] = int(battle.get("player_hp", 0)) + healed
		message_parts.append("恢复%d点气血" % healed)
		effect_events.append({"kind": "heal", "actor": "player", "target": "player",
			"text": "经络回稳，恢复%d点气血。" % healed, "value": healed,
			"cue": "combat_heal", "data": {"technique_id": technique_id}})
	var mp_gain := mini(int(battle.get("player_max_mp", 0)) - int(battle.get("player_mp", 0)),
		int(profile.get("mp_gain", 0)))
	if mp_gain > 0:
		battle["player_mp"] = int(battle.get("player_mp", 0)) + mp_gain
		message_parts.append("回纳%d点灵力" % mp_gain)
		effect_events.append({"kind": "resource", "actor": "player", "target": "player",
			"text": "灵力回纳%d点。" % mp_gain, "value": mp_gain,
			"cue": "combat_resource_gain", "data": {"resource_id": "mp",
				"technique_id": technique_id}})
	var status_value: Variant = effects.get("status", {})
	if status_value is Dictionary and not (status_value as Dictionary).is_empty():
		var status: Dictionary = status_value
		var status_id := str(status.get("id", ""))
		var status_target := str(status.get("target", "enemy"))
		var target_key := "enemy_statuses" if status_target == "enemy" else "player_statuses"
		var target_statuses: Dictionary = battle.get(target_key, {})
		var duration := int(status.get("duration", 1))
		target_statuses[status_id] = maxi(int(target_statuses.get(status_id, 0)), duration)
		battle[target_key] = target_statuses
		message_parts.append("施加%s%d回合" % [{"bleed": "流血", "weak": "衰弱", "shield": "护体"}.get(status_id, status_id), duration])
		effect_events.append({"kind": "status", "actor": "player",
			"target": status_target, "text": "状态%s延续%d回合。" % [status_id, duration],
			"value": duration, "cue": "combat_status_apply",
			"data": {"status_id": status_id, "duration": duration,
				"technique_id": technique_id}})
	var primary: Dictionary = effect_events[0] if not effect_events.is_empty() else {
		"kind": "action", "actor": "player", "target": "battle", "text": technique_name,
		"value": 0, "cue": str(technique.get("cue", "combat.spell")), "data": {}}
	var extras: Array = effect_events.slice(1)
	var data := {"technique_id": technique_id, "technique_name": technique_name,
		"mp_cost": cost, "effect_events": extras}
	return {"success": true, "kind": str(primary.get("kind", "action")),
		"value": int(primary.get("value", 0)), "target": str(primary.get("target", "battle")),
		"cue": str(primary.get("cue", technique.get("cue", "combat.spell"))),
		"data": data,
		"message": "%s：%s。" % [technique_name, "，".join(message_parts)]}


static func _apply_player_action(state: Dictionary, battle: Dictionary, action: String,
		burst_used: bool = false) -> Dictionary:
	var weak_scale := 75 if int((battle.player_statuses as Dictionary).get("weak", 0)) > 0 else 100
	var burst_scale := COUNTER_BURST_PERCENT if burst_used else 100
	var burst_suffix := " 破绽在这一刻张开，余劲尽数贯入。" if burst_used else ""
	if action == "attack":
		var power := int(battle.player_attack) * weak_scale / 100 * burst_scale / 100 * \
			_signature_player_power_percent(battle, action) / 100
		var damage := _deal_damage(state, battle, false, power, int(battle.enemy_defense), 18)
		var bleed_applied := false
		if _roll(state, 1, 100) <= 22:
			var statuses: Dictionary = battle.enemy_statuses
			statuses["bleed"] = maxi(int(statuses.bleed), 2)
			battle["enemy_statuses"] = statuses
			bleed_applied = true
		return {"success": true, "kind": "damage", "value": damage, "target": "enemy",
			"cue": "combat_attack", "data": {"action_id": action, "burst": burst_used,
				"status_id": "bleed" if bleed_applied else ""},
			"message": "你斩出一式，造成%d点伤害。%s" % [damage, burst_suffix]}
	if action == "guard":
		var statuses: Dictionary = battle.player_statuses
		var shield := maxi(4, int(battle.player_defense) + _roll(state, 0, maxi(2, int(battle.player_defense) / 2)))
		statuses["shield"] = maxi(int(statuses.shield), shield)
		battle["player_statuses"] = statuses
		return {"success": true, "kind": "shield", "value": shield, "target": "player",
			"cue": "combat_guard", "data": {"action_id": action},
			"message": "你收势结印，凝成%d点护盾。" % shield}
	if action == "spell":
		var spell_cost := _spell_cost(battle)
		battle["player_mp"] = int(battle.player_mp) - spell_cost
		var power := int(round(int(battle.player_attack) * 1.45)) * weak_scale / 100 * burst_scale / 100 * \
			_signature_player_power_percent(battle, action) / 100
		var damage := _deal_damage(state, battle, false, power, int(battle.enemy_defense) / 2, 12)
		var statuses: Dictionary = battle.enemy_statuses
		statuses["weak"] = maxi(int(statuses.weak), 2)
		battle["enemy_statuses"] = statuses
		return {"success": true, "kind": "damage", "value": damage, "target": "enemy",
			"cue": "combat_spell", "data": {"action_id": action, "burst": burst_used,
				"status_id": "weak", "mp_cost": spell_cost},
			"message": "术法贯穿护体灵光，造成%d点伤害并令敌势衰弱。%s" % [damage, burst_suffix]}
	if action == "pill":
		if ItemSystemScript.count(state, "healing_pill") > 0:
			ItemSystemScript.remove_item(state, "healing_pill", 1)
		else:
			var player: Dictionary = state.player
			player["pills"] = maxi(0, int(player.get("pills", 0)) - 1)
			state["player"] = player
		var healed := mini(int(battle.player_max_hp) - int(battle.player_hp), maxi(1, int(battle.player_max_hp) * 40 / 100))
		battle["player_hp"] = int(battle.player_hp) + healed
		return {"success": true, "kind": "heal", "value": healed, "target": "player",
			"cue": "combat_heal", "data": {"action_id": action, "item_id": "healing_pill"},
			"message": "丹力化开，恢复%d点气血。" % healed}
	var flee_chance := clampi(42 + int(state.player.get("realm_index", 0)) * 2 - int(battle.turn), 18, 82)
	var escaped := _roll(state, 1, 100) <= flee_chance
	return {"success": escaped, "kind": "action", "value": flee_chance, "target": "battle",
		"cue": "combat_flee" if escaped else "combat_flee_blocked",
		"data": {"action_id": action, "chance": flee_chance, "escaped": escaped},
		"message": "你脱离了战圈。" if escaped else "退路被敌意截断。"}


static func _emit_action_result(event: Dictionary, result: Dictionary, actor: String,
		default_target: String) -> void:
	var kind := str(result.get("kind", "note"))
	var target := str(result.get("target", default_target))
	var data_value: Variant = result.get("data", {})
	var data: Dictionary = data_value if data_value is Dictionary else {}
	CombatEventPipelineScript.emit(event, kind, actor, target,
		str(result.get("message", "交锋继续。")), int(result.get("value", 0)),
		str(result.get("cue", "")), data)
	var status_id := str(data.get("status_id", ""))
	if not status_id.is_empty():
		CombatEventPipelineScript.emit(event, "status", actor, target,
			"%s承受了%s。" % ["你" if target == "player" else "对手",
				{"bleed": "流血", "weak": "衰弱"}.get(status_id, status_id)],
			1, "combat_status_apply", {"status_id": status_id})
	var mp_cost := int(data.get("mp_cost", 0))
	if mp_cost > 0:
		CombatEventPipelineScript.emit(event, "resource", actor, actor,
			"灵力随招式运转。", -mp_cost, "combat_resource_spent", {"resource_id": "mp"})
	var extra_events_value: Variant = data.get("effect_events", [])
	if extra_events_value is Array:
		for extra_value in extra_events_value:
			if not extra_value is Dictionary:
				continue
			var extra: Dictionary = extra_value
			CombatEventPipelineScript.emit(event, str(extra.get("kind", "note")),
				str(extra.get("actor", actor)), str(extra.get("target", default_target)),
				str(extra.get("text", "")), int(extra.get("value", 0)),
				str(extra.get("cue", "")), extra.get("data", {}))


static func _advance_counter_chain(battle: Dictionary, action: String,
		role_override: String = "") -> String:
	var intent := str(battle.get("intent", "strike"))
	var role := role_override if not role_override.is_empty() else counter_action_role(battle, action)
	var previous := int(battle.get("counter_chain", 0))
	if role == "alternative":
		return "%s没有追那一拍，但保住了当前的破势节拍（%d/%d）。" % [
			action_name(action), previous, COUNTER_CHAIN_TARGET]
	if role in ["utility", "withdraw"]:
		if previous <= 0:
			return ""
		return "%s暂缓了正面交锋，已有的破势节拍仍在（%d/%d）。" % [
			action_name(action), previous, COUNTER_CHAIN_TARGET]
	if role != "recommended":
		battle["counter_chain"] = 0
		return "这一手撞在%s上，刚摸到的节拍断了。" % intent_name(intent) if previous > 0 else ""
	var progress := mini(COUNTER_CHAIN_TARGET, int(battle.get("counter_chain", 0)) + 1)
	battle["counter_chain"] = progress
	battle["best_counter_chain"] = maxi(int(battle.get("best_counter_chain", 0)), progress)
	if progress >= COUNTER_CHAIN_TARGET:
		var newly_completed := previous < COUNTER_CHAIN_TARGET and \
			not bool(battle.get("counter_burst_ready", false))
		battle["counter_burst_ready"] = true
		if newly_completed:
			battle["counter_completions"] = int(battle.get("counter_completions", 0)) + 1
		else:
			return "%s继续压住%s，已经露出的破绽没有合拢。" % [
				action_name(action), intent_name(intent)]
		return "三道换气都被你拿住。破绽已开，下一记斩击或术法会更重。"
	return "%s正好压住%s。你已经看清%d/%d道换气。" % [
		action_name(action), intent_name(intent), progress, COUNTER_CHAIN_TARGET]


static func _record_action(battle: Dictionary, action: String, role: String,
		technique_id: String = "") -> void:
	var action_value: Variant = battle.get("action_counts", {})
	var action_counts: Dictionary = action_value.duplicate(true) if action_value is Dictionary else {}
	action_counts[action] = int(action_counts.get(action, 0)) + 1
	battle["action_counts"] = action_counts
	if not technique_id.is_empty():
		var technique_value: Variant = battle.get("technique_counts", {})
		var technique_counts: Dictionary = technique_value.duplicate(true) \
			if technique_value is Dictionary else {}
		technique_counts[technique_id] = int(technique_counts.get(technique_id, 0)) + 1
		battle["technique_counts"] = technique_counts
	var role_value: Variant = battle.get("counter_role_counts", {})
	var role_counts: Dictionary = role_value.duplicate(true) if role_value is Dictionary else {}
	role_counts[role] = int(role_counts.get(role, 0)) + 1
	battle["counter_role_counts"] = role_counts


static func _trigger_second_phase_if_needed(battle: Dictionary) -> bool:
	if bool(battle.get("second_phase_active", false)) or \
			bool(battle.get("phase_shift_pending", false)):
		return false
	var enemy_hp := int(battle.get("enemy_hp", 0))
	var enemy_max_hp := maxi(1, int(battle.get("enemy_max_hp", 1)))
	if enemy_hp <= 0 or enemy_hp * 100 > enemy_max_hp * SECOND_PHASE_THRESHOLD_PERCENT:
		return false
	battle["phase_shift_pending"] = true
	battle["second_phase_triggered_turn"] = int(battle.get("turn", 1))
	battle["second_phase_trigger_count"] = int(battle.get("second_phase_trigger_count", 0)) + 1
	_append_log(battle, "%s气息骤然倒转，%s将成。眼前这记%s仍照旧落下，下一回合起招路会变。" % [
		str(battle.get("enemy_name", "敌人")), str(battle.get("phase_title", "换势")),
		intent_name(str(battle.get("intent", "strike")))])
	return true


static func _apply_pending_second_phase(battle: Dictionary) -> bool:
	if not bool(battle.get("phase_shift_pending", false)):
		return false
	var second_cycle := _normalize_intent_cycle(battle.get("second_phase_cycle", []),
		_second_phase_cycle(battle.get("base_intent_cycle", ["strike"]) as Array))
	battle["phase_shift_pending"] = false
	battle["second_phase_active"] = true
	battle["second_phase_cycle"] = second_cycle
	battle["intent_cycle"] = second_cycle.duplicate()
	battle["intent_index"] = 0
	battle["intent"] = str(second_cycle[0])
	var signature_shift := _apply_signature_phase_shift(battle)
	_append_log(battle, "%s完成换势：%s。新的招路从%s起手。" % [
		str(battle.get("enemy_name", "敌人")), str(battle.get("phase_title", "换势")),
		intent_name(str(second_cycle[0]))])
	if not signature_shift.is_empty():
		_append_log(battle, signature_shift)
	return true


static func _apply_enemy_intent(state: Dictionary, battle: Dictionary) -> Dictionary:
	var intent := str(battle.intent)
	if intent == "guard":
		var statuses: Dictionary = battle.enemy_statuses
		var shield := maxi(4, int(battle.enemy_defense) + _roll(state, 0, maxi(2, int(battle.enemy_defense) / 2)))
		statuses["shield"] = maxi(int(statuses.shield), shield)
		battle["enemy_statuses"] = statuses
		var guard_message := "%s结成%d点护身罡气。" % [battle.enemy_name, shield]
		var guard_signature := _apply_signature_after_enemy_intent(battle, intent)
		if not guard_signature.is_empty():
			guard_message += " " + guard_signature
		return {"kind": "shield", "value": shield, "target": "enemy",
			"cue": "combat_enemy_guard", "data": {"intent_id": intent},
			"message": guard_message}
	var attack_profile := _enemy_attack_profile(battle, intent)
	var attack := int(attack_profile.get("power", 1))
	var variance := int(attack_profile.get("variance", 14))
	var shield_pierce := int(attack_profile.get("shield_pierce_percent", 0))
	var label := "迅击"
	if intent == "heavy":
		label = "重击"
	var damage := _deal_damage(state, battle, true, attack, int(battle.player_defense), variance,
		shield_pierce)
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
	var message := "%s施展%s，造成%d点伤害。" % [battle.enemy_name, label, damage]
	var signature_message := _apply_signature_after_enemy_intent(battle, intent)
	if not signature_message.is_empty():
		message += " " + signature_message
	return {"kind": "damage", "value": damage, "target": "player",
		"cue": "combat_enemy_hit", "data": {"intent_id": intent,
			"status_id": "bleed" if intent == "bleed" else ("weak" if intent == "weaken" else ""),
			"shield_pierce_percent": shield_pierce}, "message": message}


static func _deal_damage(state: Dictionary, battle: Dictionary, to_player: bool,
		power: int, defense: int, variance_percent: int, shield_pierce_percent: int = 0) -> int:
	var variance := _roll(state, -variance_percent, variance_percent)
	var raw := maxi(1, power + power * variance / 100 - int(defense * 0.55))
	var status_key := "player_statuses" if to_player else "enemy_statuses"
	var hp_key := "player_hp" if to_player else "enemy_hp"
	var statuses: Dictionary = battle[status_key]
	var shield := int(statuses.get("shield", 0))
	var usable_shield := shield * (100 - clampi(shield_pierce_percent, 0, 100)) / 100
	var absorbed := mini(usable_shield, raw)
	statuses["shield"] = shield - absorbed
	battle[status_key] = statuses
	var damage := raw - absorbed
	battle[hp_key] = maxi(0, int(battle[hp_key]) - damage)
	return damage


static func _apply_bleed_start(battle: Dictionary, player_side: bool) -> int:
	var statuses_key := "player_statuses" if player_side else "enemy_statuses"
	var hp_key := "player_hp" if player_side else "enemy_hp"
	var max_hp_key := "player_max_hp" if player_side else "enemy_max_hp"
	var statuses: Dictionary = battle[statuses_key]
	if int(statuses.get("bleed", 0)) > 0:
		var bleed_percent := 4
		if player_side and str(battle.get("signature_id", "")) == "corrosive_black_rain":
			bleed_percent = 6 if bool(battle.get("second_phase_active", false)) else 4
		var damage := maxi(1, int(battle[max_hp_key]) * bleed_percent / 100)
		battle[hp_key] = maxi(0, int(battle[hp_key]) - damage)
		_append_log(battle, "%s因流血失去%d点气血。" % ["你" if player_side else str(battle.enemy_name), damage])
		return damage
	return 0


static func _tick_duration_statuses(battle: Dictionary) -> void:
	for statuses_key in ["player_statuses", "enemy_statuses"]:
		var statuses: Dictionary = battle[statuses_key]
		for status_id in ["bleed", "weak"]:
			statuses[status_id] = maxi(0, int(statuses.get(status_id, 0)) - 1)
		battle[statuses_key] = statuses


static func _finish(state: Dictionary, battle: Dictionary, outcome: String,
		event: Dictionary = {}) -> Dictionary:
	battle["outcome"] = outcome
	var player: Dictionary = state.player
	var base_hp := maxi(0, int(battle.player_hp) - int(battle.player_hp_bonus))
	player["hp"] = clampi(base_hp, 0, int(player.get("max_hp", 1)))
	player["mp"] = clampi(int(battle.player_mp), 0, int(player.get("max_mp", 0)))
	var rewards := {}
	if outcome == "victory":
		var realm_index := int(player.get("realm_index", 0))
		var base_exp := 41 + realm_index * 18
		var tactical_exp := mini(18, int(battle.get("counter_completions", 0)) * 6 +
			int(battle.get("counter_bursts_used", 0)) * 3)
		var exp_reward := base_exp + tactical_exp
		var stone_reward := 3 + realm_index + _roll(state, 0, 5)
		player["exp"] = int(player.get("exp", 0)) + exp_reward
		player["spirit_stones"] = int(player.get("spirit_stones", 0)) + stone_reward
		player["battles_won"] = int(player.get("battles_won", 0)) + 1
		ItemSystemScript.add_item(state, str(battle.material), 1)
		rewards = {"exp": exp_reward, "base_exp": base_exp, "tactical_exp": tactical_exp,
			"spirit_stones": stone_reward, "material": str(battle.material)}
	elif outcome == "defeat":
		player["hp"] = 0
	state["player"] = player
	battle["rewards"] = rewards
	var narrative_context: Dictionary = _normalize_narrative_context(
		battle.get("narrative_context", {}))
	var story_consequence := str(narrative_context.get({
		"victory": "victory_consequence",
		"defeat": "defeat_consequence",
	}.get(outcome, "escape_consequence"), ""))
	var narrative_outcome_result := NarrativeConsequenceScript.resolve_combat_outcome(state,
		str(narrative_context.get("source_event_id", "")),
		str(narrative_context.get("source_choice_id", "")), outcome)
	var adversary_id := str(battle.get("encounter_id", "")).strip_edges()
	if adversary_id.is_empty():
		adversary_id = str(battle.get("base_enemy_id", battle.get("enemy_id", ""))).strip_edges()
	var adversary_result := EncounterSystemScript.record_outcome(state,
		adversary_id, str(battle.get("encounter_tier", "normal")), outcome,
		str(narrative_context.get("rematch_key", "")))
	if not story_consequence.is_empty():
		_append_log(battle, story_consequence)
	var outcome_message := _outcome_text(outcome, rewards)
	_append_log(battle, outcome_message)
	if event.is_empty():
		event = CombatEventPipelineScript.begin(battle, "forced_resolution")
		CombatEventPipelineScript.advance(event, "before_action")
		CombatEventPipelineScript.emit(event, "note", "system", "battle",
			"战局越过了可持续的回合上限。", 0, "combat_forced_resolution")
	if str(event.get("status", "")) == "running":
		if str(event.get("phase", "")) != "combat_end":
			CombatEventPipelineScript.advance(event, "combat_end")
		CombatEventPipelineScript.emit(event, "outcome", "system", "battle",
			outcome_message, 0, "combat_%s" % outcome,
			{"outcome": outcome, "story_consequence": story_consequence})
		CombatEventPipelineScript.complete(event, {"outcome": outcome,
			"rewards": rewards.duplicate(true),
			"narrative_outcome_applied": bool(narrative_outcome_result.get("applied", false))})
	CombatEventPipelineScript.append_history(battle, event)
	var combat: Dictionary = state.combat
	combat["active"] = false
	combat["current"] = battle
	var history: Array = combat.get("history", [])
	history.append({"id": battle.id, "encounter_id": str(battle.get("encounter_id", "")),
		"base_enemy_id": str(battle.get("base_enemy_id", battle.get("enemy_id", ""))),
		"enemy_id": battle.enemy_id, "enemy_name": battle.enemy_name,
		"encounter_tier": str(battle.get("encounter_tier", "normal")),
		"visual_profile_id": str(battle.get("visual_profile_id", "enemy.generic.unknown")),
		"weapon_profile_id": str(battle.get("weapon_profile_id", "weapon.generic.unarmed")),
		"vfx_profile_id": str(battle.get("vfx_profile_id", "vfx.generic.impact")),
		"outcome": outcome, "turns": int(battle.turn), "rewards": rewards.duplicate(true),
		"narrative_context": narrative_context.duplicate(true),
		"story_consequence": story_consequence,
		"best_counter_chain": int(battle.get("best_counter_chain", 0)),
		"counter_completions": int(battle.get("counter_completions", 0)),
		"counter_bursts_used": int(battle.get("counter_bursts_used", 0)),
		"action_counts": (battle.get("action_counts", {}) as Dictionary).duplicate(true),
		"technique_counts": (battle.get("technique_counts", {}) as Dictionary).duplicate(true),
		"counter_role_counts": (battle.get("counter_role_counts", {}) as Dictionary).duplicate(true),
		"second_phase_trigger_count": int(battle.get("second_phase_trigger_count", 0)),
		"signature_id": str(battle.get("signature_id", "")),
		"signature_trigger_count": int((battle.get("signature_state", {}) as Dictionary).get(
			"trigger_count", 0)),
		"last_event_hash": str(event.get("trace_hash", "")),
		"narrative_outcome_applied": bool(narrative_outcome_result.get("applied", false))})
	combat["history"] = _bounded_array(history, MAX_HISTORY)
	state["combat"] = combat
	return {"ok": true, "code": "combat_finished", "outcome": outcome,
		"battle": battle, "rewards": rewards, "story_consequence": story_consequence,
		"narrative_consequence": narrative_outcome_result, "adversary": adversary_result,
		"event": event}


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


static func _encounter_tier(value: String, fallback: String = "normal") -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized in ["normal", "elite", "boss"]:
		return normalized
	var fallback_normalized := fallback.strip_edges().to_lower()
	return fallback_normalized if fallback_normalized in ["normal", "elite", "boss"] else "normal"


static func _profile_or_default(source: Dictionary, key: String, fallback: String) -> String:
	var value := str(source.get(key, "")).strip_edges()
	return value.left(96) if not value.is_empty() else fallback.left(96)


static func _signature_for_enemy(enemy_id: String) -> Dictionary:
	var signature_value: Variant = SIGNATURE_RULES.get(enemy_id, GENERIC_SIGNATURE)
	var signature: Dictionary = signature_value.duplicate(true) if signature_value is Dictionary else \
		GENERIC_SIGNATURE.duplicate(true)
	if not signature.has("second_intents"):
		signature["second_intents"] = ["heavy", "strike", "guard"]
	return signature


static func _initial_signature_state(signature_id: String) -> Dictionary:
	var state := {
		"last_action": "", "last_offense": "", "heat": 0, "ward": "attack",
		"silence_steps": 0, "edict_action": "attack", "trigger_count": 0,
		"ash": 0, "debt": 0, "repeat_count": 0,
	}
	if signature_id == "adaptive_void_ward":
		state["ward"] = "attack"
	if signature_id == "rotating_heaven_law":
		state["edict_action"] = "attack"
	return state


static func _normalize_signature_state(value: Variant, signature_id: String) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := _initial_signature_state(signature_id)
	var action_ids := ["", "attack", "guard", "spell", "pill", "flee"]
	var last_action := str(source.get("last_action", ""))
	var last_offense := str(source.get("last_offense", ""))
	var ward := str(source.get("ward", "attack"))
	var edict := str(source.get("edict_action", "attack"))
	result["last_action"] = last_action if last_action in action_ids else ""
	result["last_offense"] = last_offense if last_offense in ["", "attack", "spell"] else ""
	result["ward"] = ward if ward in ["attack", "spell"] else "attack"
	result["edict_action"] = edict if edict in ["attack", "guard", "spell"] else "attack"
	result["heat"] = clampi(int(source.get("heat", 0)), 0, 3)
	result["silence_steps"] = clampi(int(source.get("silence_steps", 0)), 0, 2)
	result["trigger_count"] = clampi(int(source.get("trigger_count", 0)), 0, 1000000)
	result["ash"] = clampi(int(source.get("ash", 0)), 0, 5)
	result["debt"] = clampi(int(source.get("debt", 0)), 0, 1000000)
	result["repeat_count"] = clampi(int(source.get("repeat_count", 0)), 0, 3)
	return result


static func signature_snapshot(battle: Dictionary) -> Dictionary:
	var signature_id := str(battle.get("signature_id", ""))
	var definition := _signature_for_enemy(str(battle.get("base_enemy_id",
		battle.get("enemy_id", ""))))
	if signature_id.is_empty():
		signature_id = str(definition.get("id", GENERIC_SIGNATURE.id))
	var state := _normalize_signature_state(battle.get("signature_state", {}), signature_id)
	var snapshot := {
		"id": signature_id,
		"title": str(battle.get("signature_title", definition.get("title", GENERIC_SIGNATURE.title))),
		"rule": str(battle.get("signature_rule", definition.get("rule", GENERIC_SIGNATURE.rule))),
		"phase_rule": str(battle.get("signature_phase_rule", definition.get("phase_rule", GENERIC_SIGNATURE.phase_rule))),
		"phase_active": bool(battle.get("second_phase_active", false)),
		"status": _signature_status_text(battle, state),
		"state": state.duplicate(true),
	}
	return snapshot


static func _signature_status_text(battle: Dictionary, state: Dictionary) -> String:
	var signature_id := str(battle.get("signature_id", ""))
	var phase := bool(battle.get("second_phase_active", false))
	match signature_id:
		"blood_scent":
			var bleed := int((battle.get("player_statuses", {}) as Dictionary).get("bleed", 0))
			return "你正流血，下一次敌攻伤害为%d%%。" % (150 if phase else 130) if bleed > 0 else "尚未闻到血腥味。"
		"broken_oath_forms":
			var last := str(state.get("last_action", ""))
			return "上一式是%s；再用同式会添%d点敌方护体。" % [action_name(last),
				int(battle.get("enemy_defense", 0)) if phase else maxi(3, int(battle.get("enemy_defense", 0)) / 2)] \
				if not last.is_empty() else "尚未记住你的招式。"
		"furnace_pressure":
			return "炉压%d/3；进攻升%d格，守势泄压。" % [int(state.get("heat", 0)), 2 if phase else 1]
		"spirit_interest":
			return "蚀心咒下次会抽走%d点灵力。" % (7 if phase else 4)
		"memory_countermeasure":
			var last_offense := str(state.get("last_offense", ""))
			return "回声记住了%s；重复进攻威力降至%d%%。" % [action_name(last_offense), 50 if phase else 70] \
				if not last_offense.is_empty() else "回声尚未记住你的进攻。"
		"adaptive_void_ward":
			return "虚相正偏折%s；改用另一种进攻可绕开。" % action_name(str(state.get("ward", "attack")))
		"corrosive_black_rain":
			return "流血每回合损失%d%%气血；守势可洗去%d回合。" % [6 if phase else 4, 1 if phase else 2]
		"shield_plunder":
			return "敌方结印会夺走你至多%d点护盾。" % [int(battle.get("enemy_defense", 0)) if phase else maxi(4, int(battle.get("enemy_defense", 0)) / 2)]
		"breath_levy":
			return "每次武招额外纳%d点灵力税；灵力不足会变虚弱。" % (4 if phase else 2)
		"silent_seal":
			return "寂印还需%d次武招解开。" % int(state.get("silence_steps", 0)) if int(state.get("silence_steps", 0)) > 0 else "寂印已开，可再次施法。"
		"rotating_heaven_law":
			return "当前天律禁止%s；触犯损失%d%%气血。" % [action_name(str(state.get("edict_action", "attack"))), 8 if phase else 5]
		"unbound_edge":
			return "敌方伤害穿透%d%%现有护盾。" % [100 if phase else 50]
		"ink_decree":
			var ink_action := str(state.get("last_action", ""))
			return "墨诏正禁用%s；重复会损血%s。" % [action_name(ink_action), "并失去灵力" if phase else ""] \
				if not ink_action.is_empty() else "白玉命笔尚未写下你的招式。"
		"soul_furnace":
			return "黑匣炉压%d/3；攻击可泄压，结盾会助长下一次重击。" % int(state.get("heat", 0))
		"identity_rollback":
			var archived := str(state.get("last_action", ""))
			return "归档动作：%s；重复进攻威力降至%d%%。" % [action_name(archived), 35 if phase else 55] \
				if not archived.is_empty() else "归档官尚未锁定你的动作。"
		"ash_eclipse":
			return "蚀日灰烬%d/%d；满层后的攻击会引爆流血。" % [int(state.get("ash", 0)), 5 if phase else 3]
		"life_foreclosure":
			return "经脉契额%d；%s" % [int(state.get("debt", 0)), "全身查封中，服丹不可用。" if phase else "受创会继续累积契额。"]
		"name_erasure":
			var sealed := str(state.get("last_action", ""))
			return "空册封存%s；重复触犯%d/3。" % [action_name(sealed), int(state.get("repeat_count", 0))] \
				if not sealed.is_empty() else "白玉空册尚未封存招式。"
	return str(battle.get("signature_rule", GENERIC_SIGNATURE.rule))


static func _signature_action_block(battle: Dictionary, action: String) -> String:
	if str(battle.get("signature_id", "")) == "silent_seal" and action == "spell":
		var steps := int((battle.get("signature_state", {}) as Dictionary).get("silence_steps", 0))
		if steps > 0:
			return "寂印未解，还需%d次斩击或守势才能施法。" % steps
	if str(battle.get("signature_id", "")) == "life_foreclosure" and \
			bool(battle.get("second_phase_active", false)) and action == "pill":
		return "经脉已被查封，服丹只会被契书收走。"
	return ""


static func _signature_auto_avoids_action(battle: Dictionary, action: String) -> bool:
	return str(battle.get("signature_id", "")) == "rotating_heaven_law" and \
		action == str((battle.get("signature_state", {}) as Dictionary).get("edict_action", ""))


static func _signature_tax(battle: Dictionary) -> int:
	return 4 if bool(battle.get("second_phase_active", false)) else 2


static func _spell_cost(battle: Dictionary) -> int:
	return SPELL_COST + _signature_tax(battle) if str(battle.get("signature_id", "")) == "breath_levy" else SPELL_COST


static func _signature_player_power_percent(battle: Dictionary, action: String) -> int:
	if action not in ["attack", "spell"]:
		return 100
	var signature_id := str(battle.get("signature_id", ""))
	var state: Dictionary = battle.get("signature_state", {}) as Dictionary
	var phase := bool(battle.get("second_phase_active", false))
	var multiplier := 100
	if signature_id == "memory_countermeasure" and str(state.get("last_offense", "")) == action:
		multiplier = 50 if phase else 70
	if signature_id == "adaptive_void_ward" and str(state.get("ward", "")) == action:
		multiplier = multiplier * (40 if phase else 60) / 100
	if signature_id == "identity_rollback" and str(state.get("last_action", "")) == action:
		multiplier = multiplier * (35 if phase else 55) / 100
	return multiplier


static func _signature_action_forecast(battle: Dictionary, action: String) -> Dictionary:
	var signature_id := str(battle.get("signature_id", ""))
	var state: Dictionary = battle.get("signature_state", {}) as Dictionary
	var phase := bool(battle.get("second_phase_active", false))
	var result := {"signature_id": signature_id, "signature_title": str(battle.get("signature_title", "")),
		"signature_status": _signature_status_text(battle, state), "available": true,
		"blocked_reason": "", "signature_power_percent": _signature_player_power_percent(battle, action),
		"extra_mp_cost": 0, "signature_hp_cost": 0}
	if signature_id == "silent_seal" and action == "spell" and int(state.get("silence_steps", 0)) > 0:
		result["available"] = false
		result["blocked_reason"] = "寂印未解"
	if signature_id == "silent_seal" and action == "spell":
		result["silence_applied"] = 2 if phase else 1
	if signature_id == "breath_levy" and action in ["attack", "guard", "spell"]:
		result["extra_mp_cost"] = _signature_tax(battle)
		result["signature_effect"] = "本式需额外纳灵力税。"
	if signature_id == "broken_oath_forms" and action in ["attack", "guard", "spell"] and \
			str(state.get("last_action", "")) == action:
		result["enemy_shield_gain"] = int(battle.get("enemy_defense", 0)) if phase else \
			maxi(3, int(battle.get("enemy_defense", 0)) / 2)
	if signature_id == "furnace_pressure":
		result["heat_delta"] = (2 if phase else 1) if action in ["attack", "spell"] else \
			-(2 if not phase else 1) if action == "guard" else 0
	if signature_id == "corrosive_black_rain" and action == "guard":
		result["bleed_clear"] = 1 if phase else 2
	if signature_id == "silent_seal" and action in ["attack", "guard"]:
		result["silence_clear"] = 1
	if signature_id == "rotating_heaven_law" and action == str(state.get("edict_action", "")):
		result["signature_hp_cost"] = maxi(1, int(battle.get("player_max_hp", 1)) * (8 if phase else 5) / 100)
		result["signature_effect"] = "触犯当前天律。"
	if signature_id in ["ink_decree", "name_erasure"] and action in ["attack", "guard", "spell"] and \
			str(state.get("last_action", "")) == action:
		result["signature_hp_cost"] = maxi(1, int(battle.get("player_max_hp", 1)) * (9 if phase else 6) / 100)
		result["signature_effect"] = "重复动作触犯敌方签名规则。"
	if signature_id == "life_foreclosure" and phase and action == "pill":
		result["available"] = false
		result["blocked_reason"] = "经脉查封"
	return result


static func _signature_intent_forecast(battle: Dictionary, intent: String) -> Dictionary:
	var signature_id := str(battle.get("signature_id", ""))
	var phase := bool(battle.get("second_phase_active", false))
	var state: Dictionary = battle.get("signature_state", {}) as Dictionary
	var result := {"signature_id": signature_id, "signature_title": str(battle.get("signature_title", "")),
		"signature_status": _signature_status_text(battle, state),
		"signature_rule": str(battle.get("signature_rule", "")),
		"signature_phase_rule": str(battle.get("signature_phase_rule", ""))}
	if signature_id == "spirit_interest" and intent == "weaken":
		result["mp_loss"] = 7 if phase else 4
		result["shield_gain_equals_mp_loss"] = true
	if signature_id == "shield_plunder" and intent == "guard":
		result["shield_plunder_max"] = int(battle.get("enemy_defense", 0)) if phase else \
			maxi(4, int(battle.get("enemy_defense", 0)) / 2)
	if signature_id == "furnace_pressure" and int(state.get("heat", 0)) >= 3 and intent != "guard":
		result["overheat_multiplier_percent"] = 155 if phase else 135
	if signature_id == "blood_scent" and int((battle.get("player_statuses", {}) as Dictionary).get("bleed", 0)) > 0:
		result["blood_scent_multiplier_percent"] = 150 if phase else 130
	if signature_id == "unbound_edge" and intent != "guard":
		result["shield_pierce_percent"] = 100 if phase else 50
	if signature_id == "rotating_heaven_law":
		result["next_edict_action"] = str(state.get("edict_action", "attack"))
	if signature_id == "soul_furnace" and intent == "heavy":
		result["furnace_multiplier_percent"] = 100 + int(state.get("heat", 0)) * (22 if phase else 15)
	if signature_id == "ash_eclipse" and intent != "guard":
		result["ash"] = int(state.get("ash", 0))
		result["ash_burst_ready"] = int(state.get("ash", 0)) >= (5 if phase else 3)
	if signature_id == "life_foreclosure":
		result["meridian_debt"] = int(state.get("debt", 0))
	return result


static func _enemy_attack_profile(battle: Dictionary, intent: String) -> Dictionary:
	var weak_scale := 75 if int((battle.get("enemy_statuses", {}) as Dictionary).get("weak", 0)) > 0 else 100
	var power := int(battle.get("enemy_attack", 0)) * weak_scale / 100
	var variance := 14
	if intent == "heavy":
		power = int(round(power * 1.55))
		variance = 20
	var signature_id := str(battle.get("signature_id", ""))
	var phase := bool(battle.get("second_phase_active", false))
	var state: Dictionary = battle.get("signature_state", {}) as Dictionary
	var shield_pierce := 0
	if signature_id == "blood_scent" and int((battle.get("player_statuses", {}) as Dictionary).get("bleed", 0)) > 0:
		power = power * (150 if phase else 130) / 100
	if signature_id == "furnace_pressure" and int(state.get("heat", 0)) >= 3 and intent != "guard":
		power = power * (155 if phase else 135) / 100
	if signature_id == "unbound_edge":
		shield_pierce = 100 if phase else 50
	if signature_id == "soul_furnace" and intent == "heavy":
		power = power * (100 + int(state.get("heat", 0)) * (22 if phase else 15)) / 100
	if signature_id == "ash_eclipse" and int(state.get("ash", 0)) >= (5 if phase else 3):
		power = power * (170 if phase else 145) / 100
		shield_pierce = 50 if phase else 0
	return {"power": maxi(1, power), "variance": variance, "shield_pierce_percent": shield_pierce}


static func _apply_signature_before_player_action(battle: Dictionary, action: String,
		reserved_mp: int = 0, include_spell_tax: bool = false) -> String:
	var signature_id := str(battle.get("signature_id", ""))
	var state: Dictionary = battle.get("signature_state", {}) as Dictionary
	var phase := bool(battle.get("second_phase_active", false))
	var messages: Array[String] = []
	if signature_id == "breath_levy" and \
			(action in ["attack", "guard"] or (include_spell_tax and action == "spell")):
		var tax := _signature_tax(battle)
		var available_for_tax := maxi(0, int(battle.get("player_mp", 0)) - maxi(0, reserved_mp))
		var paid := mini(available_for_tax, tax)
		battle["player_mp"] = int(battle.get("player_mp", 0)) - paid
		if paid < tax:
			var player_statuses: Dictionary = battle.get("player_statuses", {})
			player_statuses["weak"] = maxi(int(player_statuses.get("weak", 0)), 2)
			battle["player_statuses"] = player_statuses
			messages.append("灵力不足，未纳足息税，气势被压低。")
		else:
			messages.append("夺息使收走%d点灵力税。" % tax)
	if signature_id == "rotating_heaven_law" and action == str(state.get("edict_action", "")):
		var penalty_percent := 8 if phase else 5
		var penalty := maxi(1, int(battle.get("player_max_hp", 1)) * penalty_percent / 100)
		battle["player_hp"] = maxi(0, int(battle.get("player_hp", 0)) - penalty)
		state["trigger_count"] = int(state.get("trigger_count", 0)) + 1
		messages.append("天律反噬，你失去%d点气血。" % penalty)
	if signature_id in ["ink_decree", "name_erasure"] and action in ["attack", "guard", "spell"] and \
			str(state.get("last_action", "")) == action:
		var repeat_penalty := maxi(1, int(battle.get("player_max_hp", 1)) * (9 if phase else 6) / 100)
		battle["player_hp"] = maxi(0, int(battle.get("player_hp", 0)) - repeat_penalty)
		state["trigger_count"] = int(state.get("trigger_count", 0)) + 1
		state["repeat_count"] = mini(3, int(state.get("repeat_count", 0)) + 1)
		if signature_id == "ink_decree":
			var enemy_statuses: Dictionary = battle.get("enemy_statuses", {})
			enemy_statuses["shield"] = int(enemy_statuses.get("shield", 0)) + maxi(4, int(battle.get("enemy_defense", 0)) / 2)
			battle["enemy_statuses"] = enemy_statuses
			if phase:
				battle["player_mp"] = maxi(0, int(battle.get("player_mp", 0)) - 5)
			messages.append("墨诏反噬重复招式，并把罚痕写成护体。")
		else:
			if int(state.get("repeat_count", 0)) >= 3:
				var player_statuses: Dictionary = battle.get("player_statuses", {})
				player_statuses["shield"] = 0
				battle["player_statuses"] = player_statuses
				state["repeat_count"] = 0
			messages.append("白玉空册抹去重复招式留下的护体。")
	battle["signature_state"] = state
	return " ".join(messages)


static func _apply_signature_after_player_action(battle: Dictionary, action: String) -> String:
	var signature_id := str(battle.get("signature_id", ""))
	var state: Dictionary = battle.get("signature_state", {}) as Dictionary
	var phase := bool(battle.get("second_phase_active", false))
	var message := ""
	if signature_id == "broken_oath_forms":
		var previous := str(state.get("last_action", ""))
		if action in ["attack", "guard", "spell"] and previous == action:
			var gain := int(battle.get("enemy_defense", 0)) if phase else maxi(3, int(battle.get("enemy_defense", 0)) / 2)
			var enemy_statuses: Dictionary = battle.get("enemy_statuses", {})
			enemy_statuses["shield"] = int(enemy_statuses.get("shield", 0)) + gain
			battle["enemy_statuses"] = enemy_statuses
			state["trigger_count"] = int(state.get("trigger_count", 0)) + 1
			message = "毁誓剑客识破重复招式，添上%d点护体。" % gain
		if action in ["attack", "guard", "spell"]:
			state["last_action"] = action
	if signature_id == "furnace_pressure":
		var heat := int(state.get("heat", 0))
		if action in ["attack", "spell"]:
			heat = mini(3, heat + (2 if phase else 1))
			if heat >= 3:
				message = "炉压升至%d/3，赤炉即将过热。" % heat
		elif action == "guard":
			var vent := 1 if phase else 2
			heat = maxi(0, heat - vent)
			message = "守势泄去%d格炉压，余压%d/3。" % [vent, heat]
		state["heat"] = heat
	if signature_id == "memory_countermeasure" and action in ["attack", "spell"]:
		if str(state.get("last_offense", "")) == action:
			state["trigger_count"] = int(state.get("trigger_count", 0)) + 1
		state["last_offense"] = action
	if signature_id == "adaptive_void_ward" and action in ["attack", "spell"]:
		state["ward"] = action
	if signature_id == "corrosive_black_rain" and action == "guard":
		var statuses: Dictionary = battle.get("player_statuses", {})
		var clear_amount := 1 if phase else 2
		statuses["bleed"] = maxi(0, int(statuses.get("bleed", 0)) - clear_amount)
		battle["player_statuses"] = statuses
		message = "守势冲开黑雨，流血余势减少%d回合。" % clear_amount
	if signature_id == "silent_seal":
		if action == "spell":
			state["silence_steps"] = 2 if phase else 1
			message = "寂法封住你的下一轮术式。"
		elif action in ["attack", "guard"] and int(state.get("silence_steps", 0)) > 0:
			state["silence_steps"] = maxi(0, int(state.get("silence_steps", 0)) - 1)
			message = "武招震开一重寂印。"
	if signature_id in ["ink_decree", "identity_rollback", "name_erasure"] and \
			action in ["attack", "guard", "spell"]:
		if str(state.get("last_action", "")) != action and signature_id == "name_erasure":
			state["repeat_count"] = 0
		state["last_action"] = action
	if signature_id == "soul_furnace":
		var furnace_heat := int(state.get("heat", 0))
		if action == "guard":
			furnace_heat = mini(3, furnace_heat + (2 if phase else 1))
			message = "你的护盾被黑匣压成炉压：%d/3。" % furnace_heat
		elif action in ["attack", "spell"]:
			furnace_heat = maxi(0, furnace_heat - 1)
			message = "进攻震开黑匣，炉压降至%d/3。" % furnace_heat
		state["heat"] = furnace_heat
	battle["signature_state"] = state
	return message


static func _apply_signature_after_enemy_intent(battle: Dictionary, intent: String) -> String:
	var signature_id := str(battle.get("signature_id", ""))
	var state: Dictionary = battle.get("signature_state", {}) as Dictionary
	var phase := bool(battle.get("second_phase_active", false))
	var message := ""
	if signature_id == "spirit_interest" and intent == "weaken":
		var requested := 7 if phase else 4
		var paid := mini(int(battle.get("player_mp", 0)), requested)
		battle["player_mp"] = int(battle.get("player_mp", 0)) - paid
		var enemy_statuses: Dictionary = battle.get("enemy_statuses", {})
		enemy_statuses["shield"] = int(enemy_statuses.get("shield", 0)) + paid
		battle["enemy_statuses"] = enemy_statuses
		state["trigger_count"] = int(state.get("trigger_count", 0)) + 1
		message = "灵轨债吏收走%d点灵息，化作同额护体。" % paid
	if signature_id == "shield_plunder" and intent == "guard":
		var player_statuses: Dictionary = battle.get("player_statuses", {})
		var enemy_statuses: Dictionary = battle.get("enemy_statuses", {})
		var maximum := int(battle.get("enemy_defense", 0)) if phase else maxi(4, int(battle.get("enemy_defense", 0)) / 2)
		var stolen := mini(maximum, int(player_statuses.get("shield", 0)))
		player_statuses["shield"] = int(player_statuses.get("shield", 0)) - stolen
		enemy_statuses["shield"] = int(enemy_statuses.get("shield", 0)) + stolen
		battle["player_statuses"] = player_statuses
		battle["enemy_statuses"] = enemy_statuses
		if stolen > 0:
			state["trigger_count"] = int(state.get("trigger_count", 0)) + 1
			message = "拾遗劫修夺走你%d点护盾，收入自己的匣中。" % stolen
	if signature_id == "furnace_pressure" and intent != "guard" and int(state.get("heat", 0)) >= 3:
		state["heat"] = 0
		message = "赤炉过热喷涌，炉压归零。"
	if signature_id == "rotating_heaven_law":
		var order := ["attack", "guard", "spell"]
		var current := order.find(str(state.get("edict_action", "attack")))
		if current < 0:
			current = 0
		var step := -1 if phase else 1
		state["edict_action"] = str(order[posmod(current + step, order.size())])
	if signature_id == "soul_furnace" and intent == "heavy" and int(state.get("heat", 0)) > 0:
		state["heat"] = 0
		state["trigger_count"] = int(state.get("trigger_count", 0)) + 1
		message = "黑匣把积存炉压尽数轰出，随后归零。"
	if signature_id == "ash_eclipse":
		if intent == "bleed":
			state["ash"] = mini(5, int(state.get("ash", 0)) + 1)
			message = "流血被伪日炼成灰烬：%d/%d。" % [int(state.get("ash", 0)), 5 if phase else 3]
		elif int(state.get("ash", 0)) >= (5 if phase else 3) and intent != "guard":
			state["ash"] = 0
			state["trigger_count"] = int(state.get("trigger_count", 0)) + 1
			message = "灰日爆燃，引爆后灰烬归零。"
	if signature_id == "life_foreclosure" and intent != "guard":
		state["debt"] = int(state.get("debt", 0)) + (9 if phase else 5)
		if int(state.get("debt", 0)) >= 20:
			var foreclosure := maxi(1, int(battle.get("player_max_hp", 1)) * (10 if phase else 6) / 100)
			battle["player_hp"] = maxi(0, int(battle.get("player_hp", 0)) - foreclosure)
			state["debt"] = maxi(0, int(state.get("debt", 0)) - 20)
			state["trigger_count"] = int(state.get("trigger_count", 0)) + 1
			message = "契额越线，经脉止赎额外扣去%d点气血。" % foreclosure
		else:
			message = "受创被记入契额：%d/20。" % int(state.get("debt", 0))
	battle["signature_state"] = state
	return message


static func _apply_signature_phase_shift(battle: Dictionary) -> String:
	var signature_id := str(battle.get("signature_id", ""))
	var state: Dictionary = battle.get("signature_state", {}) as Dictionary
	if signature_id == "furnace_pressure":
		state["heat"] = maxi(2, int(state.get("heat", 0)))
		battle["signature_state"] = state
		return "赤炉开闸，炉压从%d/3起步。" % int(state.get("heat", 0))
	if signature_id == "silent_seal" and int(state.get("silence_steps", 0)) > 0:
		state["silence_steps"] = 2
		battle["signature_state"] = state
		return "万籁俱寂，残留寂印加深为两重。"
	if signature_id == "rotating_heaven_law":
		state["edict_action"] = "spell"
		battle["signature_state"] = state
		return "天条倒悬，禁令开始逆向轮转。"
	battle["signature_state"] = state
	return ""


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
	var base_enemy_id := str(battle.get("base_enemy_id", "")).strip_edges()
	if base_enemy_id.is_empty():
		base_enemy_id = str(battle.get("enemy_id", "")).strip_edges()
	var definition := _find_enemy(base_enemy_id)
	if not definition.is_empty():
		base_enemy_id = str(definition.id)
		battle["base_enemy_id"] = base_enemy_id
		# Keep enemy_id as the legacy alias used by older callers and saves.
		battle["enemy_id"] = base_enemy_id
		var encounter_id := str(battle.get("encounter_id", "")).strip_edges()
		battle["encounter_id"] = encounter_id if not encounter_id.is_empty() else base_enemy_id
		battle["encounter_tier"] = _encounter_tier(
			str(battle.get("encounter_tier", "")), str(definition.get("tier", "normal")))
		battle["visual_profile_id"] = _profile_or_default(battle, "visual_profile_id",
			str(definition.get("visual_profile_id", "enemy.generic.unknown")))
		battle["weapon_profile_id"] = _profile_or_default(battle, "weapon_profile_id",
			str(definition.get("weapon_profile_id", "weapon.generic.unarmed")))
		battle["vfx_profile_id"] = _profile_or_default(battle, "vfx_profile_id",
			str(definition.get("vfx_profile_id", "vfx.generic.impact")))
	else:
		battle["base_enemy_id"] = base_enemy_id.left(96)
		battle["enemy_id"] = base_enemy_id.left(96)
		var fallback_encounter_id := str(battle.get("encounter_id", "")).strip_edges()
		battle["encounter_id"] = fallback_encounter_id if not fallback_encounter_id.is_empty() else \
			base_enemy_id.left(96)
		battle["encounter_tier"] = _encounter_tier(str(battle.get("encounter_tier", "")), "normal")
		battle["visual_profile_id"] = str(battle.get("visual_profile_id", "enemy.generic.unknown")).strip_edges().left(96)
		battle["weapon_profile_id"] = str(battle.get("weapon_profile_id", "weapon.generic.unarmed")).strip_edges().left(96)
		battle["vfx_profile_id"] = str(battle.get("vfx_profile_id", "vfx.generic.impact")).strip_edges().left(96)
	battle["visual_loadout"] = _normalize_visual_loadout(battle.get("visual_loadout", {}))
	battle["ally_support_id"] = str(battle.get("ally_support_id", "")).left(96)
	battle["ally_support_name"] = str(battle.get("ally_support_name", "")).left(96)
	battle["support_effect"] = str(battle.get("support_effect", "")).left(48)
	var signature := _signature_for_enemy(base_enemy_id)
	var had_signature := not str(battle.get("signature_id", "")).is_empty()
	battle["signature_id"] = str(signature.get("id", GENERIC_SIGNATURE.id))
	battle["signature_title"] = str(signature.get("title", GENERIC_SIGNATURE.title))
	battle["signature_rule"] = str(signature.get("rule", GENERIC_SIGNATURE.rule))
	battle["signature_phase_rule"] = str(signature.get("phase_rule", GENERIC_SIGNATURE.phase_rule))
	battle["signature_state"] = _normalize_signature_state(battle.get("signature_state", {}),
		str(battle.signature_id))
	var cycle := _normalize_intent_cycle(battle.get("intent_cycle", ["strike"]), ["strike"])
	var base_cycle := _normalize_intent_cycle(battle.get("base_intent_cycle", cycle), cycle)
	var generated_second_cycle := _normalize_intent_cycle(signature.get("second_intents", []),
		_second_phase_cycle(base_cycle))
	var second_cycle_value: Variant = battle.get("second_phase_cycle", generated_second_cycle) \
		if had_signature else generated_second_cycle
	var second_cycle := _normalize_intent_cycle(
		second_cycle_value, generated_second_cycle)
	battle["base_intent_cycle"] = base_cycle
	battle["second_phase_cycle"] = second_cycle
	battle["second_phase_active"] = bool(battle.get("second_phase_active", false))
	battle["phase_shift_pending"] = bool(battle.get("phase_shift_pending", false)) and \
		not bool(battle.second_phase_active)
	if bool(battle.second_phase_active):
		cycle = second_cycle.duplicate()
	battle["intent_cycle"] = cycle
	battle["intent_index"] = int(battle.intent_index) % battle.intent_cycle.size()
	battle["intent"] = str(battle.intent_cycle[int(battle.intent_index)])
	battle["counter_target"] = COUNTER_CHAIN_TARGET
	battle["counter_chain"] = clampi(int(battle.get("counter_chain", 0)), 0, COUNTER_CHAIN_TARGET)
	battle["best_counter_chain"] = clampi(int(battle.get("best_counter_chain", 0)), 0,
		COUNTER_CHAIN_TARGET)
	battle["counter_burst_ready"] = bool(battle.get("counter_burst_ready", false))
	if bool(battle.counter_burst_ready):
		battle["counter_chain"] = COUNTER_CHAIN_TARGET
	battle["best_counter_chain"] = maxi(int(battle.best_counter_chain), int(battle.counter_chain))
	var inferred_completions := 1 if int(battle.best_counter_chain) >= COUNTER_CHAIN_TARGET else 0
	battle["counter_completions"] = clampi(int(battle.get("counter_completions",
		inferred_completions)), inferred_completions, 100000000)
	battle["counter_bursts_used"] = clampi(int(battle.get("counter_bursts_used", 0)), 0, 100000000)
	battle["action_counts"] = _normalize_count_map(battle.get("action_counts", {}),
		["attack", "guard", "spell", "pill", "flee"])
	battle["technique_counts"] = _normalize_technique_counts(battle.get("technique_counts", {}))
	battle["counter_role_counts"] = _normalize_count_map(battle.get("counter_role_counts", {}),
		["recommended", "alternative", "utility", "withdraw", "unsuitable"])
	battle["second_phase_triggered_turn"] = clampi(int(battle.get(
		"second_phase_triggered_turn", 0)), 0, MAX_TURNS)
	var inferred_phase_count := 1 if bool(battle.second_phase_active) or \
		bool(battle.phase_shift_pending) else 0
	battle["second_phase_trigger_count"] = clampi(int(battle.get(
		"second_phase_trigger_count", inferred_phase_count)), inferred_phase_count, 1)
	var canonical_phase_title := str(signature.get("phase_title", GENERIC_SIGNATURE.phase_title))
	var phase_title := str(battle.get("phase_title", canonical_phase_title) if had_signature else \
		canonical_phase_title).strip_edges().left(48)
	battle["phase_title"] = phase_title if not phase_title.is_empty() else canonical_phase_title
	battle["log"] = _bounded_array(battle.get("log", []), MAX_LOG)
	battle["event_history"] = CombatEventPipelineScript.normalize_history(
		battle.get("event_history", []))
	battle["narrative_context"] = _normalize_narrative_context(
		battle.get("narrative_context", {}))
	return battle


static func _visual_loadout_for_state(state: Dictionary) -> Dictionary:
	var player_value: Variant = state.get("player", {})
	var player: Dictionary = player_value if player_value is Dictionary else {}
	var inventory_value: Variant = state.get("inventory", {})
	var inventory: Dictionary = inventory_value if inventory_value is Dictionary else {}
	var equipped_value: Variant = inventory.get("equipped", {})
	var equipped: Dictionary = equipped_value if equipped_value is Dictionary else {}
	var path_id := CombatTechniqueCatalogScript.dominant_path(player)
	var weapon_ref := str(equipped.get("weapon_id", ""))
	var armor_ref := str(equipped.get("armor_id", ""))
	var relic_ref := str(equipped.get("relic_id", "black_white_jade"))
	var legacy_value: Variant = state.get("legacy", {})
	var legacy: Dictionary = legacy_value if legacy_value is Dictionary else {}
	var armory_value: Variant = legacy.get("armory", {})
	var armory: Dictionary = armory_value if armory_value is Dictionary else {}
	var jade_weapon_id := str(armory.get("equipped_id", ""))
	if not CombatVisualCatalogScript.jade_weapon_ids().has(jade_weapon_id):
		jade_weapon_id = ""
	return {
		"path_id": path_id,
		"weapon_id": _visual_equipment_id(inventory, weapon_ref, "weapon"),
		"armor_id": _visual_equipment_id(inventory, armor_ref, "armor"),
		"relic_id": _visual_equipment_id(inventory, relic_ref, "relic"),
		"jade_weapon_id": jade_weapon_id,
	}


static func _normalize_visual_loadout(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var resolved := CombatVisualCatalogScript.resolve_loadout({"visual_loadout": source})
	# Existing saves always carry the persistent black/white jade relic. Preserve
	# that stable fallback while keeping genuinely empty weapon/armor slots empty.
	if not source.has("relic_id"):
		resolved["relic_id"] = "black_white_jade"
	return resolved


static func _visual_equipment_id(inventory: Dictionary, reference_id: String,
		slot: String) -> String:
	var reference := reference_id.strip_edges().left(96)
	if reference.is_empty():
		return ""
	var direct: Dictionary = {
		"iron_sword": "iron_sword", "jade_qingxiao": "jade_qingxiao",
		"spirit_blade": "spirit_blade", "cloud_robe": "cloud_robe",
		"warding_armor": "warding_armor", "black_white_jade": "black_white_jade",
		"void_relic": "void_relic",
	}
	if direct.has(reference):
		return str(direct[reference])
	var items_value: Variant = inventory.get("items", [])
	var items: Array = items_value if items_value is Array else []
	for entry_value in items:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("instance_id", "")) != reference and str(entry.get("item_id", "")) != reference:
			continue
		if str(entry.get("slot", entry.get("category", ""))) != slot:
			continue
		var item_id := str(entry.get("item_id", ""))
		if item_id == "forged_spirit_blade": return "spirit_blade"
		if item_id == "forged_warding_armor": return "warding_armor"
		if item_id == "forged_void_relic": return "void_relic"
		return item_id if CombatVisualCatalogScript.equipment_ids().has(item_id) else ""
	return ""


static func _second_phase_cycle(value: Array) -> Array:
	var base := _normalize_intent_cycle(value, ["strike"])
	if base.size() == 1:
		var pressure_intent := "heavy" if str(base[0]) != "heavy" else "strike"
		return [pressure_intent, str(base[0]), pressure_intent]
	if base.size() == 2:
		return [str(base[1]), str(base[0]), str(base[1]), str(base[0])]
	return [str(base[2]), str(base[0]), str(base[1]), str(base[0])]


static func _normalize_intent_cycle(value: Variant, fallback: Array) -> Array:
	var source: Array = value if value is Array else []
	var result: Array = []
	for entry in source:
		var intent_id := str(entry)
		if INTENT_NAMES.has(intent_id):
			result.append(intent_id)
	if result.is_empty():
		for entry in fallback:
			var intent_id := str(entry)
			if INTENT_NAMES.has(intent_id):
				result.append(intent_id)
	if result.is_empty():
		result.append("strike")
	return result.slice(0, 8)


static func _normalize_count_map(value: Variant, allowed_keys: Array) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for key_value in allowed_keys:
		var key := str(key_value)
		var count := clampi(int(source.get(key, 0)), 0, 100000000)
		if count > 0:
			result[key] = count
	return result


static func _normalize_technique_counts(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for technique_value in (CombatTechniqueCatalogScript.load_definitions().get(
			"techniques", []) as Array):
		if not technique_value is Dictionary:
			continue
		var technique_id := str((technique_value as Dictionary).get("id", ""))
		var count := clampi(int(source.get(technique_id, 0)), 0, 100000000)
		if count > 0:
			result[technique_id] = count
	return result


static func _normalize_narrative_context(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for field in NARRATIVE_CONTEXT_FIELDS:
		result[field] = str(source.get(field, "")).left(240)
	return result


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


static func _damage_range(power: int, defense: int, variance_percent: int,
		shield: int = 0) -> Dictionary:
	var defense_reduction := int(defense * 0.55)
	var minimum_raw := maxi(1, power - power * variance_percent / 100 - defense_reduction)
	var maximum_raw := maxi(1, power + power * variance_percent / 100 - defense_reduction)
	return {
		"min_damage": maxi(0, minimum_raw - maxi(0, shield)),
		"max_damage": maxi(0, maximum_raw - maxi(0, shield)),
	}


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
