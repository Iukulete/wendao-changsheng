extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const ItemSystemScript = preload("res://scripts/item_system.gd")
const CombatSystemScript = preload("res://scripts/combat_system.gd")
const CombatEventPipelineScript = preload("res://scripts/combat_event_pipeline.gd")
const EncounterSystemScript = preload("res://scripts/encounter_system.gd")
const NarrativeConsequenceScript = preload("res://scripts/narrative_consequence_system.gd")

var failures: Array[String] = []


func _init() -> void:
	var base := GameStateScript.create_new_game("问剑", 515151, [7, 7, 7, 7, 7])
	var rejected_without_encounter := CombatSystemScript.start_combat(base,
		"classical_razor_wolf")
	_expect(not bool(rejected_without_encounter.get("ok", false)) and
		str(rejected_without_encounter.get("code", "")) == "encounter_required",
		"底层战斗 API 必须拒绝没有剧情敌踪的随机开战旁路")
	var deterministic_a := base.duplicate(true)
	var deterministic_b := base.duplicate(true)
	var start_a: Dictionary = _start_test_combat(deterministic_a, "classical_razor_wolf")
	var start_b: Dictionary = _start_test_combat(deterministic_b, "classical_razor_wolf")
	_expect(bool(start_a.ok) and start_a == start_b and deterministic_a == deterministic_b,
		"同一状态与敌人必须生成完全相同的战局")
	_expect(not bool(EncounterSystemScript.summary(deterministic_a).get("active", false)),
		"开战必须原子消费敌踪，不能依赖 UI 另行清理常亮入口")
	_expect(not CombatSystemScript.intent_label(start_a.battle).is_empty() and
		not CombatSystemScript.intent_description(start_a.battle).is_empty(),
		"敌人必须提前暴露明确意图及其战术含义")
	var opening_objective: Dictionary = CombatSystemScript.battle_objective(start_a.battle)
	_expect(str(opening_objective.get("title", "")) == "三拍破势" and
		int(opening_objective.get("progress", -1)) == 0 and
		int(opening_objective.get("target", 0)) == CombatSystemScript.COUNTER_CHAIN_TARGET and
		not str(opening_objective.get("signature_title", "")).is_empty() and
		not str(opening_objective.get("signature_rule", "")).is_empty() and
		not str(opening_objective.get("signature_status", "")).is_empty(),
		"普通战斗必须从开场就给出短目标，而不是只剩五个重复按钮")
	var first_intent_forecast: Dictionary = CombatSystemScript.intent_forecast(start_a.battle)
	var first_action_forecasts: Dictionary = CombatSystemScript.action_forecasts(deterministic_a, start_a.battle)
	_expect(str(first_intent_forecast.get("kind", "")) == "damage" and
		int(first_intent_forecast.get("max_damage", -1)) >= int(first_intent_forecast.get("min_damage", 0)) and
		not str(first_intent_forecast.get("counter", "")).is_empty(),
		"敌方意图必须给出与真实公式一致的伤害范围和应对建议")
	_expect(int((first_action_forecasts.attack as Dictionary).max_damage) >=
		int((first_action_forecasts.attack as Dictionary).min_damage) and
		int((first_action_forecasts.spell as Dictionary).mp_cost) == CombatSystemScript.SPELL_COST and
		int((first_action_forecasts.flee as Dictionary).chance) in range(18, 83),
		"五种玩家行动必须暴露确定性的收益、消耗与脱战概率")
	_expect(str(first_intent_forecast.get("counter_action", "")) == "attack" and
		str(first_intent_forecast.get("counter_action_name", "")) == "斩击" and
		not str(first_intent_forecast.get("signature_status", "")).is_empty() and
		str((first_action_forecasts.attack as Dictionary).get("signature_id", "")) ==
			"blood_scent",
		"公开敌意与行动预测必须同时携带可供界面读取的敌人规则")
	var expected_counter_options := {
		"strike": ["attack", "guard"], "heavy": ["guard", "spell"],
		"guard": ["spell", "attack"], "bleed": ["guard", "attack"],
		"weaken": ["spell", "guard"],
	}
	for intent_id in expected_counter_options:
		var expected: Array = expected_counter_options[intent_id]
		var options: Dictionary = CombatSystemScript.counter_options(intent_id)
		_expect(str(options.get("recommended", "")) == str(expected[0]) and
			str(options.get("alternative", "")) == str(expected[1]) and
			not str(options.get("recommended_text", "")).is_empty() and
			not str(options.get("alternative_text", "")).is_empty(),
			"%s必须同时给出有取舍的推荐应对与备选应对" % intent_id)
	var first_turn: Dictionary = CombatSystemScript.perform_action(deterministic_a, "attack")
	var mirrored_first_turn: Dictionary = CombatSystemScript.perform_action(deterministic_b, "attack")
	_expect(bool(first_turn.ok) and int(first_turn.battle.turn) == 2 and
		(first_turn.battle.log as Array).size() >= 3, "攻击必须推进双方行动并留下战斗日志")
	_expect(first_turn.event == mirrored_first_turn.event and
		bool(CombatEventPipelineScript.validate(first_turn.event).get("ok", false)) and
		(first_turn.event.steps as Array).any(func(step: Variant) -> bool:
			return step is Dictionary and str((step as Dictionary).get("kind", "")) == "damage") and
		(first_turn.battle.event_history as Array).size() == 1,
		"每一手必须生成确定、可校验且写入战局历史的结构化事件轨迹")
	var technique_state := base.duplicate(true)
	_start_test_combat(technique_state, "classical_razor_wolf")
	var technique_slots: Array = CombatSystemScript.technique_slots(technique_state)
	var first_technique: Dictionary = technique_slots[0]
	var technique_turn: Dictionary = CombatSystemScript.perform_technique(technique_state,
		str(first_technique.get("id", "")))
	_expect(bool(technique_turn.get("ok", false)) and
		str(technique_turn.get("technique_id", "")) == str(first_technique.get("id", "")) and
		str((technique_turn.event as Dictionary).get("action_id", "")) ==
			str(first_technique.get("id", "")) and
		int((technique_turn.battle.technique_counts as Dictionary).get(
			str(first_technique.get("id", "")), 0)) == 1,
		"道途战技必须以目录 ID 执行、扣除成本并写入结构化战斗记录")

	var guard_state := base.duplicate(true)
	_start_test_combat(guard_state, "classical_oath_breaker")
	guard_state.combat.current.intent = "heavy"
	guard_state.combat.current.intent_cycle = ["heavy"]
	var heavy_forecast: Dictionary = CombatSystemScript.intent_forecast(guard_state.combat.current)
	_expect(str(heavy_forecast.get("threat", "")) in ["高危", "致命"] and
		int(heavy_forecast.get("max_damage", 0)) > 0,
		"蓄势重击必须在执行前标注高危范围")
	var hp_before := int(guard_state.combat.current.player_hp)
	var guarded: Dictionary = CombatSystemScript.perform_action(guard_state, "guard")
	_expect(int(guarded.battle.player_hp) > 0 and int(guarded.battle.player_hp) >= hp_before - 20,
		"防御必须用护盾吸收蓄势重击，而不是装饰选项")

	var chain_state := base.duplicate(true)
	chain_state.player.attack = 2
	chain_state.player.defense = 120
	chain_state.player.max_hp = 800
	chain_state.player.hp = 800
	_start_test_combat(chain_state, "classical_oath_breaker")
	chain_state.combat.current.intent_cycle = ["strike"]
	chain_state.combat.current.intent_index = 0
	var chain_one: Dictionary = CombatSystemScript.perform_action(chain_state, "attack")
	chain_state.combat.current.intent_cycle = ["heavy"]
	chain_state.combat.current.intent_index = 0
	var chain_two: Dictionary = CombatSystemScript.perform_action(chain_state, "guard")
	chain_state.combat.current.intent_cycle = ["guard"]
	chain_state.combat.current.intent_index = 0
	var chain_three: Dictionary = CombatSystemScript.perform_action(chain_state, "spell")
	_expect(int(chain_one.battle.counter_chain) == 1 and int(chain_two.battle.counter_chain) == 2 and
		int(chain_three.battle.counter_chain) == CombatSystemScript.COUNTER_CHAIN_TARGET and
		bool(chain_three.battle.counter_burst_ready) and
		int(chain_three.battle.best_counter_chain) == CombatSystemScript.COUNTER_CHAIN_TARGET,
		"连续读懂三道敌意必须积成一次清晰可见的破势")
	var burst_forecasts: Dictionary = CombatSystemScript.action_forecasts(chain_state,
		chain_state.combat.current)
	_expect(bool((burst_forecasts.attack as Dictionary).burst_ready) and
		bool((burst_forecasts.spell as Dictionary).burst_ready),
		"破势伤害必须在玩家点击前进入两种进攻行动的预测")
	chain_state.combat.current.intent_cycle = ["strike"]
	chain_state.combat.current.intent_index = 0
	var burst: Dictionary = CombatSystemScript.perform_action(chain_state, "attack")
	_expect(not bool(burst.battle.counter_burst_ready) and int(burst.battle.counter_chain) == 1 and
		(burst.battle.log as Array).any(func(line: Variant) -> bool: return str(line).contains("余劲尽数贯入")),
		"破势必须被下一次进攻消费，并允许这一手重新开始积势")
	chain_state.combat.current.intent_cycle = ["heavy"]
	chain_state.combat.current.intent_index = 0
	var broken_chain: Dictionary = CombatSystemScript.perform_action(chain_state, "attack")
	_expect(int(broken_chain.battle.counter_chain) == 0 and
		int(broken_chain.battle.best_counter_chain) == CombatSystemScript.COUNTER_CHAIN_TARGET,
		"错误应对必须打断当前节拍，但保留本场最佳表现用于结算")

	var choice_state := base.duplicate(true)
	choice_state.player.attack = 2
	choice_state.player.defense = 160
	choice_state.player.max_hp = 900
	choice_state.player.hp = 900
	_start_test_combat(choice_state, "classical_razor_wolf")
	choice_state.combat.current.intent_cycle = ["strike"]
	choice_state.combat.current.intent_index = 0
	var recommended_choice := CombatSystemScript.perform_action(choice_state, "attack")
	var alternative_choice := CombatSystemScript.perform_action(choice_state, "guard")
	choice_state.combat.current.player_hp = int(choice_state.combat.current.player_max_hp) - 20
	var utility_choice := CombatSystemScript.perform_action(choice_state, "pill")
	var unsuitable_choice := CombatSystemScript.perform_action(choice_state, "spell")
	var role_counts: Dictionary = unsuitable_choice.battle.counter_role_counts
	_expect(int(recommended_choice.battle.counter_chain) == 1 and
		int(alternative_choice.battle.counter_chain) == 1 and
		int(utility_choice.battle.counter_chain) == 1 and
		int(unsuitable_choice.battle.counter_chain) == 0,
		"备选与辅助行动必须保留节拍，只有完全失配的行动才会清零")
	_expect(int(role_counts.get("recommended", 0)) == 1 and
		int(role_counts.get("alternative", 0)) == 1 and
		int(role_counts.get("utility", 0)) == 1 and
		int(role_counts.get("unsuitable", 0)) == 1 and
		int((unsuitable_choice.battle.action_counts as Dictionary).get("guard", 0)) == 1,
		"战局必须按具体行动及其应对角色记录分布")

	var phase_state := base.duplicate(true)
	phase_state.player.attack = 20
	phase_state.player.defense = 180
	phase_state.player.max_hp = 900
	phase_state.player.hp = 900
	_start_test_combat(phase_state, "classical_razor_wolf")
	phase_state.combat.current.enemy_max_hp = 200
	phase_state.combat.current.enemy_hp = 110
	phase_state.combat.current.player_attack = 20
	phase_state.combat.current.enemy_defense = 0
	phase_state.combat.current.intent_cycle = ["bleed"]
	phase_state.combat.current.intent_index = 0
	var phase_turn := CombatSystemScript.perform_action(phase_state, "attack")
	var phase_cycle: Array = phase_turn.battle.intent_cycle
	_expect(bool(phase_turn.get("second_phase_triggered", false)) and
		bool(phase_turn.get("second_phase_shifted", false)) and
		bool(phase_turn.battle.second_phase_active) and
		int(phase_turn.battle.second_phase_triggered_turn) == 1 and
		int(phase_turn.battle.second_phase_trigger_count) == 1,
		"敌人降至半血后必须且只能触发一次可观测的第二阶段")
	_expect(int((phase_turn.battle.player_statuses as Dictionary).get("bleed", 0)) > 0 and
		phase_cycle == (phase_turn.battle.second_phase_cycle as Array) and
		str(phase_turn.battle.intent) == str(phase_cycle[0]) and
		(phase_turn.battle.log as Array).any(func(line: Variant) -> bool:
			return str(line).contains("眼前这记撕裂经脉仍照旧落下")) and
		(phase_turn.battle.log as Array).any(func(line: Variant) -> bool:
			return str(line).contains("完成换势")),
		"半血回合必须先兑现已公开意图，再把下一回合切到新循环")
	var phase_followup := CombatSystemScript.perform_action(phase_state, "attack")
	_expect(not bool(phase_followup.get("second_phase_triggered", false)) and
		int(phase_followup.battle.second_phase_trigger_count) == 1,
		"第二阶段不能在后续低血回合重复触发")

	var legacy_state := base.duplicate(true)
	_start_test_combat(legacy_state, "classical_razor_wolf")
	for field in ["base_intent_cycle", "second_phase_cycle", "counter_completions",
		"counter_bursts_used", "action_counts", "counter_role_counts", "second_phase_active",
		"second_phase_triggered_turn", "second_phase_trigger_count", "phase_shift_pending",
		"phase_title", "signature_id", "signature_title", "signature_rule",
		"signature_phase_rule", "signature_state"]:
		legacy_state.combat.current.erase(field)
	legacy_state.combat.current.visual_profile_id = "enemy.immortal.fate_registrar"
	legacy_state.combat.current.weapon_profile_id = "weapon.brush.white_jade_fate"
	legacy_state.combat.current.vfx_profile_id = "vfx.immortal.name_erasure"
	var normalized_legacy := CombatSystemScript.normalize(legacy_state)
	_expect((normalized_legacy.current.second_phase_cycle as Array).size() >= 3 and
		normalized_legacy.current.action_counts is Dictionary and
		normalized_legacy.current.counter_role_counts is Dictionary and
		not bool(normalized_legacy.current.second_phase_active) and
		str(normalized_legacy.current.encounter_id) == "classical_razor_wolf" and
		str(normalized_legacy.current.base_enemy_id) == "classical_razor_wolf" and
		str(normalized_legacy.current.signature_id) == "blood_scent" and
		normalized_legacy.current.signature_state is Dictionary and
		str(normalized_legacy.current.phase_title) == "血月伏脊" and
		str(normalized_legacy.current.visual_profile_id) == "enemy.immortal.fate_registrar" and
		str(normalized_legacy.current.weapon_profile_id) == "weapon.brush.white_jade_fate" and
		str(normalized_legacy.current.vfx_profile_id) == "vfx.immortal.name_erasure",
		"旧存档战局必须补齐基础敌人字段，同时保留剧情身份与 authored visual profile")
	var legacy_history_state := {"combat": {"history": [
		{"id": "legacy_history", "enemy_id": "classical_razor_wolf", "outcome": "victory"}]}}
	var normalized_history := CombatSystemScript.normalize(legacy_history_state)
	var normalized_history_entry: Dictionary = (normalized_history.history as Array)[0]
	_expect(str(normalized_history_entry.get("encounter_id", "")) == "classical_razor_wolf" and
		str(normalized_history_entry.get("base_enemy_id", "")) == "classical_razor_wolf" and
		str(normalized_history_entry.get("visual_profile_id", "")) == "enemy.classical.razor_wolf" and
		str(normalized_history_entry.get("weapon_profile_id", "")) == "weapon.claw.bone_razor" and
		str(normalized_history_entry.get("vfx_profile_id", "")) == "vfx.classical.blood_scent",
		"旧战斗历史缺少双身份时必须按 enemy_id 补全并恢复正式默认 profiles")

	# 所有敌人先通过同一份公开契约，再针对不同机制验证真实状态变化。
	var signature_ids := {}
	var phase_cycles := {}
	for pool_value in CombatSystemScript.ENEMY_POOLS.values():
		for enemy_value in (pool_value as Array):
			var enemy: Dictionary = enemy_value
			var contract_state := base.duplicate(true)
			var contract_start: Dictionary = _start_test_combat(contract_state, str(enemy.id))
			var contract_battle: Dictionary = contract_start.get("battle", {})
			var contract_objective := CombatSystemScript.battle_objective(contract_battle)
			var contract_intent := CombatSystemScript.intent_forecast(contract_battle)
			var contract_actions := CombatSystemScript.action_forecasts(contract_state, contract_battle)
			var signature_id := str(contract_battle.get("signature_id", ""))
			signature_ids[signature_id] = true
			phase_cycles[JSON.stringify(contract_battle.get("second_phase_cycle", []))] = true
			var base_signature_metric := _signature_phase_metric(contract_state, contract_battle,
				signature_id, false)
			var phase_signature_metric := _signature_phase_metric(contract_state, contract_battle,
				signature_id, true)
			_expect(bool(contract_start.get("ok", false)) and not signature_id.is_empty() and
				str(contract_battle.get("encounter_tier", "")) in ["normal", "elite", "boss"] and
				not str(contract_battle.get("visual_profile_id", "")).is_empty() and
				not str(contract_battle.get("weapon_profile_id", "")).is_empty() and
				not str(contract_battle.get("vfx_profile_id", "")).is_empty() and
				not str(contract_objective.get("signature_rule", "")).is_empty() and
				not str(contract_objective.get("signature_status", "")).is_empty() and
				str(contract_intent.get("signature_id", "")) == signature_id and
				str((contract_actions.attack as Dictionary).get("signature_id", "")) == signature_id and
				base_signature_metric >= 0 and phase_signature_metric >= 0 and
				base_signature_metric != phase_signature_metric,
				"%s的签名规则必须同时进入战局、目标、意图与行动预测" % str(enemy.id))
			var contract_result := CombatSystemScript.auto_resolve(contract_state)
			_expect(str(contract_result.get("outcome", "")) in ["victory", "defeat", "escaped"] and
				not CombatSystemScript.has_active_combat(contract_state) and
				int(contract_result.get("actions", 0)) <= CombatSystemScript.MAX_TURNS,
				"%s的自动战斗必须在统一硬上限内正常终止" % str(enemy.id))
	_expect(signature_ids.size() == 18 and phase_cycles.size() == 18,
		"十八名正式敌人必须各有独立签名，并使用十八套身份化第二相循环")

	var wolf_state := base.duplicate(true)
	_start_test_combat(wolf_state, "classical_razor_wolf")
	wolf_state.combat.current.intent = "strike"
	wolf_state.combat.current.intent_cycle = ["strike"]
	var calm_wolf := CombatSystemScript.intent_forecast(wolf_state.combat.current)
	wolf_state.combat.current.player_statuses.bleed = 2
	var hunting_wolf := CombatSystemScript.intent_forecast(wolf_state.combat.current)
	_expect(int(hunting_wolf.get("max_damage", 0)) > int(calm_wolf.get("max_damage", 0)) and
		int(hunting_wolf.get("blood_scent_multiplier_percent", 0)) == 130,
		"苍狼嗅血必须真实提高公开伤害范围，而不是只改描述")

	var oath_state := base.duplicate(true)
	oath_state.player.attack = 1
	oath_state.player.defense = 300
	oath_state.player.max_hp = 900
	oath_state.player.hp = 900
	_start_test_combat(oath_state, "classical_oath_breaker")
	oath_state.combat.current.intent_cycle = ["strike"]
	oath_state.combat.current.intent_index = 0
	CombatSystemScript.perform_action(oath_state, "guard")
	var oath_repeat_forecast := CombatSystemScript.action_forecasts(oath_state,
		oath_state.combat.current)
	var repeated_oath := CombatSystemScript.perform_action(oath_state, "guard")
	_expect(int((oath_repeat_forecast.guard as Dictionary).get("enemy_shield_gain", 0)) > 0 and
		int((repeated_oath.battle.enemy_statuses as Dictionary).get("shield", 0)) > 0 and
		int((repeated_oath.battle.signature_state as Dictionary).get("trigger_count", 0)) == 1,
		"毁誓剑客必须识破连续同式，并在点击前公开将获得的护体")

	var furnace_state := base.duplicate(true)
	furnace_state.player.attack = 1
	furnace_state.player.defense = 300
	furnace_state.player.max_hp = 900
	furnace_state.player.hp = 900
	_start_test_combat(furnace_state, "steam_furnace_hound")
	furnace_state.combat.current.intent_cycle = ["guard"]
	furnace_state.combat.current.intent_index = 0
	CombatSystemScript.perform_action(furnace_state, "attack")
	CombatSystemScript.perform_action(furnace_state, "attack")
	var furnace_before_guard := int((furnace_state.combat.current.signature_state as Dictionary).heat)
	var furnace_guard_forecast := CombatSystemScript.action_forecasts(furnace_state,
		furnace_state.combat.current)
	CombatSystemScript.perform_action(furnace_state, "guard")
	_expect(furnace_before_guard == 2 and
		int((furnace_guard_forecast.guard as Dictionary).get("heat_delta", 0)) == -2 and
		int((furnace_state.combat.current.signature_state as Dictionary).heat) == 0,
		"赤炉机犬的炉压必须由进攻积累，并可用守势按预测泄去")

	var debt_state := base.duplicate(true)
	debt_state.player.attack = 1
	debt_state.player.defense = 300
	debt_state.player.max_hp = 900
	debt_state.player.hp = 900
	_start_test_combat(debt_state, "steam_debt_collector")
	debt_state.combat.current.intent_cycle = ["weaken"]
	debt_state.combat.current.intent_index = 0
	debt_state.combat.current.intent = "weaken"
	var debt_mp_before := int(debt_state.combat.current.player_mp)
	var debt_forecast := CombatSystemScript.intent_forecast(debt_state.combat.current)
	var debt_turn := CombatSystemScript.perform_action(debt_state, "guard")
	_expect(int(debt_forecast.get("mp_loss", 0)) == 4 and
		int(debt_turn.battle.player_mp) == debt_mp_before - 4 and
		int((debt_turn.battle.enemy_statuses as Dictionary).shield) >= 4,
		"灵轨债吏的蚀心讨息必须同时改变灵力与敌方护体，并提前公开数值")

	var memory_state := base.duplicate(true)
	_start_test_combat(memory_state, "star_echo_hunter")
	var memory_fresh := CombatSystemScript.action_forecasts(memory_state,
		memory_state.combat.current)
	memory_state.combat.current.signature_state.last_offense = "attack"
	var memory_repeated := CombatSystemScript.action_forecasts(memory_state,
		memory_state.combat.current)
	_expect(int((memory_repeated.attack as Dictionary).max_damage) <
		int((memory_fresh.attack as Dictionary).max_damage) and
		int((memory_repeated.attack as Dictionary).signature_power_percent) == 70,
		"猎忆者必须削弱重复进攻，并让行动伤害预测使用同一公式")

	var void_state := base.duplicate(true)
	_start_test_combat(void_state, "star_void_daemon")
	void_state.combat.current.signature_state.ward = "attack"
	var void_forecasts := CombatSystemScript.action_forecasts(void_state, void_state.combat.current)
	_expect(int((void_forecasts.attack as Dictionary).signature_power_percent) == 60 and
		int((void_forecasts.spell as Dictionary).signature_power_percent) == 100 and
		int((void_forecasts.attack as Dictionary).max_damage) <
		int((void_forecasts.spell as Dictionary).max_damage),
		"虚航道魔的偏折必须形成可判断的进攻类型差，而非隐藏减伤")

	var relic_state := base.duplicate(true)
	relic_state.player.attack = 1
	relic_state.player.defense = 300
	relic_state.player.max_hp = 900
	relic_state.player.hp = 900
	_start_test_combat(relic_state, "wasteland_relic_raider")
	relic_state.combat.current.player_statuses.shield = 20
	relic_state.combat.current.intent_cycle = ["guard"]
	relic_state.combat.current.intent_index = 0
	relic_state.combat.current.intent = "guard"
	var relic_forecast := CombatSystemScript.intent_forecast(relic_state.combat.current)
	var relic_turn := CombatSystemScript.perform_action(relic_state, "attack")
	_expect(int(relic_forecast.get("shield_plunder_max", 0)) > 0 and
		int((relic_turn.battle.player_statuses as Dictionary).shield) < 20 and
		int((relic_turn.battle.signature_state as Dictionary).trigger_count) == 1,
		"拾遗劫修结印时必须真实夺盾，并在意图预测中公开上限")

	var tax_state := base.duplicate(true)
	tax_state.player.attack = 1
	tax_state.player.defense = 300
	tax_state.player.max_hp = 900
	tax_state.player.hp = 900
	_start_test_combat(tax_state, "final_age_breath_taxer")
	var tax_mp_before := int(tax_state.combat.current.player_mp)
	var tax_forecasts := CombatSystemScript.action_forecasts(tax_state, tax_state.combat.current)
	var taxed_turn := CombatSystemScript.perform_action(tax_state, "guard")
	_expect(int((tax_forecasts.guard as Dictionary).extra_mp_cost) == 2 and
		int((tax_forecasts.spell as Dictionary).mp_cost) == CombatSystemScript.SPELL_COST + 2 and
		int(taxed_turn.battle.player_mp) == tax_mp_before - 2,
		"夺息使必须让武招与术法承担一致、可预见的额外灵力税")

	var silence_state := base.duplicate(true)
	silence_state.player.attack = 1
	silence_state.player.defense = 300
	silence_state.player.max_hp = 900
	silence_state.player.hp = 900
	_start_test_combat(silence_state, "final_age_silent_cultivator")
	CombatSystemScript.perform_action(silence_state, "spell")
	var sealed_forecasts := CombatSystemScript.action_forecasts(silence_state,
		silence_state.combat.current)
	var sealed_spell := CombatSystemScript.perform_action(silence_state, "spell")
	CombatSystemScript.perform_action(silence_state, "attack")
	var reopened_spell := CombatSystemScript.perform_action(silence_state, "spell")
	_expect(not bool((sealed_forecasts.spell as Dictionary).available) and
		str(sealed_spell.get("code", "")) == "signature_action_blocked" and
		bool(reopened_spell.get("ok", false)),
		"寂法修士必须封住连续术法，且武招解印后可重新施法")

	var law_state := base.duplicate(true)
	law_state.player.attack = 1
	law_state.player.defense = 300
	law_state.player.max_hp = 1000
	law_state.player.hp = 1000
	_start_test_combat(law_state, "immortal_sky_enforcer")
	law_state.combat.current.intent_cycle = ["guard"]
	law_state.combat.current.intent_index = 0
	law_state.combat.current.intent = "guard"
	var law_forecasts := CombatSystemScript.action_forecasts(law_state, law_state.combat.current)
	var law_hp_before := int(law_state.combat.current.player_hp)
	var law_turn := CombatSystemScript.perform_action(law_state, "attack")
	_expect(int((law_forecasts.attack as Dictionary).signature_hp_cost) == 50 and
		int(law_turn.battle.player_hp) == law_hp_before - 50 and
		str((law_turn.battle.signature_state as Dictionary).edict_action) == "guard",
		"巡天仙吏的轮转禁令必须按预测反噬，并在回合后切换禁式")

	var duelist_state := base.duplicate(true)
	duelist_state.player.attack = 1
	duelist_state.player.defense = 0
	duelist_state.player.max_hp = 1000
	duelist_state.player.hp = 1000
	_start_test_combat(duelist_state, "immortal_unchained_duelist")
	duelist_state.combat.current.second_phase_active = true
	duelist_state.combat.current.intent_cycle = \
		(duelist_state.combat.current.second_phase_cycle as Array).duplicate()
	duelist_state.combat.current.intent_index = 0
	duelist_state.combat.current.intent = "strike"
	duelist_state.combat.current.player_statuses.shield = 500
	var duelist_forecast := CombatSystemScript.intent_forecast(duelist_state.combat.current)
	var duelist_hp_before := int(duelist_state.combat.current.player_hp)
	var duelist_turn := CombatSystemScript.perform_action(duelist_state, "attack")
	_expect(int(duelist_forecast.get("shield_pierce_percent", 0)) == 100 and
		int(duelist_forecast.get("min_damage", 0)) > 0 and
		int(duelist_turn.battle.player_hp) < duelist_hp_before and
		int((duelist_turn.battle.player_statuses as Dictionary).shield) == 500,
		"不系仙客第二相必须完全穿盾，预测与实际都不能把护盾算作减伤")

	var spell_state := base.duplicate(true)
	_start_test_combat(spell_state, "classical_razor_wolf")
	var mp_before := int(spell_state.combat.current.player_mp)
	var spell: Dictionary = CombatSystemScript.perform_action(spell_state, "spell")
	_expect(bool(spell.ok) and int(spell.battle.player_mp) == mp_before - CombatSystemScript.SPELL_COST and
		int((spell.battle.enemy_statuses as Dictionary).weak) > 0,
		"术法必须消耗灵力并施加可持续虚弱")

	var pill_state := base.duplicate(true)
	_start_test_combat(pill_state, "classical_razor_wolf")
	pill_state.combat.current.player_hp = 10
	var pills_before := ItemSystemScript.count(pill_state, "healing_pill")
	var pill: Dictionary = CombatSystemScript.perform_action(pill_state, "pill")
	_expect(bool(pill.ok) and int(pill.battle.player_hp) > 10 and
		ItemSystemScript.count(pill_state, "healing_pill") == pills_before - 1,
		"战斗丹药必须真实恢复并消耗库存")
	var full_hp_state := base.duplicate(true)
	_start_test_combat(full_hp_state, "classical_razor_wolf")
	var full_hp_pills_before := ItemSystemScript.count(full_hp_state, "healing_pill")
	var wasted_pill: Dictionary = CombatSystemScript.perform_action(full_hp_state, "pill")
	_expect(not bool(wasted_pill.ok) and str(wasted_pill.code) == "hp_full" and
		ItemSystemScript.count(full_hp_state, "healing_pill") == full_hp_pills_before,
		"气血已满时必须拒绝消耗疗伤丹")

	var victory_state := base.duplicate(true)
	victory_state.player.attack = 500
	_start_test_combat(victory_state, "classical_razor_wolf")
	var victory: Dictionary = CombatSystemScript.auto_resolve(victory_state)
	_expect(str(victory.outcome) == "victory" and not CombatSystemScript.has_active_combat(victory_state),
		"强势角色自动战斗必须在硬上限内获胜并结束")
	_expect(int(victory_state.player.battles_won) == 1 and int(victory_state.player.exp) > 0 and
		ItemSystemScript.count(victory_state, str(victory.rewards.material)) > 0,
		"胜利必须写入战绩、修为与稳定材料奖励")

	var telemetry_state := base.duplicate(true)
	telemetry_state.player.attack = 8
	telemetry_state.player.defense = 180
	telemetry_state.player.max_hp = 900
	telemetry_state.player.hp = 900
	telemetry_state.player.max_mp = 400
	telemetry_state.player.mp = 400
	_start_test_combat(telemetry_state, "classical_razor_wolf")
	var telemetry_result := CombatSystemScript.auto_resolve(telemetry_state)
	var telemetry_battle: Dictionary = telemetry_result.battle
	var telemetry_roles: Dictionary = telemetry_battle.counter_role_counts
	_expect(int(telemetry_roles.get("recommended", 0)) > 0 and
		int(telemetry_roles.get("alternative", 0)) > 0 and
		int(telemetry_battle.counter_completions) > 0 and
		int(telemetry_battle.counter_bursts_used) > 0 and
		int(telemetry_battle.second_phase_trigger_count) == 1,
		"自动战斗必须覆盖推荐与备选路线，并真实达成、消费破势和进入第二阶段")

	var defeat_state := base.duplicate(true)
	defeat_state.player.hp = 12
	defeat_state.player.max_hp = 12
	defeat_state.player.attack = 1
	defeat_state.player.defense = 0
	_start_test_combat(defeat_state, "immortal_unchained_duelist")
	var defeat: Dictionary = CombatSystemScript.auto_resolve(defeat_state)
	_expect(str(defeat.outcome) == "defeat" and int(defeat_state.player.hp) == 0,
		"致命战斗必须形成可供轮回系统识别的死亡状态")
	_expect(int(defeat.get("actions", 0)) <= CombatSystemScript.MAX_TURNS,
		"自动战斗必须保证终止，不能形成阻断长局的死循环")

	var boss_story_state := base.duplicate(true)
	boss_story_state.player.attack = 900
	EncounterSystemScript.offer(boss_story_state, "story_choice", "空册庭审",
		"裴照微把不可删改的证词交给你。", 3, {
			"source_event_id": "imperial_siming_order",
			"source_choice_id": "immortal_face_fate_registrar",
			"enemy_id": "immortal_fate_registrar", "enemy_name": "白玉司命·空册庭审",
			"encounter_tier": "boss",
			"rematch_key": "immortal_fate_registrar_name_erasure",
			"ally_support_id": "pei_zhaowei", "ally_support_name": "裴照微",
			"support_effect": "enemy_weak",
		})
	var boss_start := CombatSystemScript.start_combat(boss_story_state)
	_expect(bool(boss_start.get("ok", false)) and
		str((boss_start.battle as Dictionary).get("ally_support_id", "")) == "pei_zhaowei" and
		int(((boss_start.battle as Dictionary).enemy_statuses as Dictionary).get("weak", 0)) == 2 and
		str((boss_start.battle as Dictionary).get("encounter_tier", "")) == "boss",
		"剧情盟友必须按选择进入首领战，并真实改变开场状态")
	var boss_result := CombatSystemScript.auto_resolve(boss_story_state)
	var boss_adversary := EncounterSystemScript.adversary_summary(boss_story_state,
		"immortal_fate_registrar")
	_expect(str(boss_result.get("outcome", "")) == "victory" and
		str(boss_adversary.get("status", "")) == "defeated" and
		bool(boss_adversary.get("rematch_available", false)) and
		str(boss_adversary.get("rematch_key", "")) ==
			"immortal_fate_registrar_name_erasure",
		"首领胜利必须写回可追索敌手账本与复战键")

	# Story identity must survive the handoff to combat: the authored antagonist
	# owns the display/ledger identity while the roster base owns mechanics.
	var authored_gate_state := base.duplicate(true)
	authored_gate_state.player.attack = 900
	EncounterSystemScript.offer(authored_gate_state, "story_choice", "封门执律",
		"执律弟子封住山门。", 3, {
			"encounter_id": "story_test_gate_disciples",
			"base_enemy_id": "immortal_sky_enforcer",
			"enemy_id": "immortal_sky_enforcer",
			"enemy_name": "封门执律弟子",
			"encounter_tier": "elite",
			"visual_profile_id": "enemy.story.gate_disciples",
			"weapon_profile_id": "weapon.story.seal_halberd",
			"vfx_profile_id": "vfx.story.gate_lock",
			"rematch_key": "story_gate_disciples_rematch",
		})
	var authored_gate_start := CombatSystemScript.start_combat(authored_gate_state)
	var authored_gate_battle: Dictionary = authored_gate_start.get("battle", {})
	_expect(bool(authored_gate_start.get("ok", false)) and
		str(authored_gate_battle.get("encounter_id", "")) == "story_test_gate_disciples" and
		str(authored_gate_battle.get("base_enemy_id", "")) == "immortal_sky_enforcer" and
		str(authored_gate_battle.get("enemy_id", "")) == "immortal_sky_enforcer" and
		str(authored_gate_battle.get("enemy_name", "")) == "封门执律弟子" and
		str(authored_gate_battle.get("encounter_tier", "")) == "elite" and
		str(authored_gate_battle.get("visual_profile_id", "")) == "enemy.story.gate_disciples" and
		str(authored_gate_battle.get("weapon_profile_id", "")) == "weapon.story.seal_halberd" and
		str(authored_gate_battle.get("vfx_profile_id", "")) == "vfx.story.gate_lock" and
		str(authored_gate_battle.get("signature_id", "")) == "rotating_heaven_law",
		"剧情敌人的显示身份、战斗基底、武器特效与签名规则必须各自落到正确字段")
	var authored_gate_result := CombatSystemScript.auto_resolve(authored_gate_state)
	var authored_gate_ledger := EncounterSystemScript.adversary_summary(authored_gate_state,
		"story_test_gate_disciples")
	var canonical_gate_ledger := EncounterSystemScript.adversary_summary(authored_gate_state,
		"immortal_sky_enforcer")
	var authored_gate_history: Array = authored_gate_state.combat.history
	var authored_gate_history_entry: Dictionary = authored_gate_history[-1] if not authored_gate_history.is_empty() else {}
	_expect(str(authored_gate_result.get("outcome", "")) == "victory" and
		str(authored_gate_ledger.get("status", "")) == "defeated" and
		canonical_gate_ledger.is_empty() and
		str(authored_gate_history_entry.get("encounter_id", "")) == "story_test_gate_disciples" and
		str(authored_gate_history_entry.get("base_enemy_id", "")) == "immortal_sky_enforcer" and
		str(authored_gate_history_entry.get("visual_profile_id", "")) == "enemy.story.gate_disciples",
		"剧情战斗结算必须写入 authored encounter_id，不能污染基础敌人账本")

	var authored_rival_state := base.duplicate(true)
	authored_rival_state.player.attack = 900
	EncounterSystemScript.offer(authored_rival_state, "story_choice", "星网伏击",
		"江追命借阵列落子。", 3, {
			"encounter_id": "story_test_jiang_ambush",
			"base_enemy_id": "immortal_unchained_duelist",
			"enemy_name": "江追命·借阵落子",
			"encounter_tier": "boss",
			"visual_profile_id": "enemy.story.jiang_ambush",
			"weapon_profile_id": "weapon.story.jiang_edge",
			"vfx_profile_id": "vfx.story.jiang_afterimage",
		})
	var authored_rival_start := CombatSystemScript.start_combat(authored_rival_state)
	var authored_rival_battle: Dictionary = authored_rival_start.get("battle", {})
	_expect(bool(authored_rival_start.get("ok", false)) and
		str(authored_rival_battle.get("encounter_id", "")) == "story_test_jiang_ambush" and
		str(authored_rival_battle.get("base_enemy_id", "")) == "immortal_unchained_duelist" and
		str(authored_rival_battle.get("enemy_name", "")) == "江追命·借阵落子" and
		str(authored_rival_battle.get("signature_id", "")) == "unbound_edge" and
		str(authored_rival_battle.get("visual_profile_id", "")) == "enemy.story.jiang_ambush" and
		str(authored_rival_battle.get("weapon_profile_id", "")) == "weapon.story.jiang_edge" and
		str(authored_rival_battle.get("vfx_profile_id", "")) == "vfx.story.jiang_afterimage",
		"第二个剧情敌人也必须保持独立身份并继承正确的基础签名")
	var authored_rival_save := authored_rival_state.duplicate(true)
	var normalized_rival := CombatSystemScript.normalize(authored_rival_save)
	_expect(str(normalized_rival.current.encounter_id) == "story_test_jiang_ambush" and
		str(normalized_rival.current.base_enemy_id) == "immortal_unchained_duelist" and
		str(normalized_rival.current.visual_profile_id) == "enemy.story.jiang_ambush" and
		str(normalized_rival.current.weapon_profile_id) == "weapon.story.jiang_edge" and
		str(normalized_rival.current.vfx_profile_id) == "vfx.story.jiang_afterimage",
		"存档归一化必须同时保留剧情身份与三类 authored profile")

	var story_battle_state := base.duplicate(true)
	story_battle_state.player.attack = 500
	NarrativeConsequenceScript.apply_choice(story_battle_state,
		{"id": "lantern_vow", "story_arc_id": "jade", "story_phase": "main",
			"story_stage": 0},
		{"id": "break_seal", "text": "当众斩断追魂印", "outcome": "执令者追到灯河。",
			"route_id": "jade_break", "deltas": {}, "path_deltas": {},
			"combat_trigger": true, "combat_outcomes": {
				"victory": {"flags_add": ["lantern_registry_recovered"]},
				"escaped": {"flags_add": ["lantern_registry_lost"]},
			}}, [])
	EncounterSystemScript.offer(story_battle_state, "story_choice", "镜湖执令者 · 灯河旧契",
		"执令者循着断印追来。若无人阻止，守灯人会重回追魂册。", 3, {
			"source_event_id": "lantern_vow", "source_choice_id": "break_seal",
			"source_choice_text": "当众斩断追魂印", "enemy_id": "classical_oath_breaker",
			"enemy_name": "镜湖执令者", "motivation": "执令者循着断印追到灯河。",
			"stakes": "若无人阻止，他会把守灯人的名字重新写回追魂册。",
			"victory_consequence": "追魂册被夺回，守灯人得以离开镜湖。",
			"defeat_consequence": "追魂印落回你身上，此世止于灯河。",
			"escape_consequence": "执令者带着追魂册退入夜色，旧契仍未了结。",
		})
	var contextual_start: Dictionary = _start_test_combat(story_battle_state)
	var contextual_battle: Dictionary = contextual_start.get("battle", {})
	var contextual_objective: Dictionary = CombatSystemScript.battle_objective(contextual_battle)
	_expect(bool(contextual_start.get("ok", false)) and
		str(contextual_battle.get("enemy_name", "")) == "镜湖执令者" and
		str((contextual_battle.narrative_context as Dictionary).source_event_id) == "lantern_vow" and
		(contextual_battle.log as Array).has("执令者循着断印追到灯河。") and
		(contextual_battle.log as Array).has("若无人阻止，他会把守灯人的名字重新写回追魂册。") and
		str(contextual_objective.get("stakes", "")) ==
			"若无人阻止，他会把守灯人的名字重新写回追魂册。",
		"剧情战斗必须在开场显示具体敌人、来源、动机和赌注")
	var contextual_result: Dictionary = CombatSystemScript.auto_resolve(story_battle_state)
	var history: Array = story_battle_state.combat.history
	_expect(str(contextual_result.get("outcome", "")) == "victory" and
		str(contextual_result.get("story_consequence", "")) == "追魂册被夺回，守灯人得以离开镜湖。" and
		str((history[-1] as Dictionary).get("story_consequence", "")) ==
			"追魂册被夺回，守灯人得以离开镜湖。" and
		str(((history[-1] as Dictionary).narrative_context as Dictionary).source_choice_id) == "break_seal",
		"胜败余波和来源选择必须进入战斗结果与持久历史")
	_expect(bool((story_battle_state.story.flags as Dictionary).get(
		"lantern_registry_recovered", false)) and
		not bool((story_battle_state.story.flags as Dictionary).get("lantern_registry_lost", false)) and
		bool((history[-1] as Dictionary).get("narrative_outcome_applied", false)),
		"真正获胜后才可写入胜利事实，战史必须记录结构化余波已结算")

	var escape_state := base.duplicate(true)
	escape_state.player.attack = 1
	escape_state.player.defense = 200
	escape_state.player.max_hp = 900
	escape_state.player.hp = 900
	EncounterSystemScript.offer(escape_state, "story_choice", "未尽追索", "用于验证撤离余波。", 3, {
		"enemy_id": "classical_oath_breaker", "enemy_name": "镜湖执令者",
		"stakes": "守灯人仍在等你带回追魂册。",
		"escape_consequence": "你保住性命退回灯河，追魂册仍在对方手里。",
	})
	_start_test_combat(escape_state)
	var escaped: Dictionary = CombatSystemScript.auto_resolve(escape_state, 1)
	_expect(str(escaped.get("outcome", "")) == "escaped" and
		not CombatSystemScript.has_active_combat(escape_state) and int(escape_state.player.hp) > 0 and
		str(escaped.get("story_consequence", "")) == "你保住性命退回灯河，追魂册仍在对方手里。",
		"撤离必须结束战斗、保留角色并把未竟后果带回主线")

	if failures.is_empty():
		print("COMBAT_SYSTEM_TEST_OK: deterministic intents, actions, narrative context, consequences, rewards and termination passed")
		quit(0)
	else:
		for failure in failures:
			push_error("COMBAT_SYSTEM_TEST_FAILED: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _signature_phase_metric(state: Dictionary, battle: Dictionary, signature_id: String,
		phase_active: bool) -> int:
	var probe := battle.duplicate(true)
	probe["second_phase_active"] = phase_active
	var signature_state: Dictionary = probe.get("signature_state", {})
	match signature_id:
		"blood_scent":
			(probe.player_statuses as Dictionary)["bleed"] = 2
			probe["intent"] = "strike"
			return int(CombatSystemScript.intent_forecast(probe).get(
				"blood_scent_multiplier_percent", -1))
		"broken_oath_forms":
			signature_state["last_action"] = "attack"
			probe["signature_state"] = signature_state
			return int((CombatSystemScript.action_forecasts(state, probe).attack as Dictionary).get(
				"enemy_shield_gain", -1))
		"furnace_pressure":
			return int((CombatSystemScript.action_forecasts(state, probe).attack as Dictionary).get(
				"heat_delta", -1))
		"spirit_interest":
			probe["intent"] = "weaken"
			return int(CombatSystemScript.intent_forecast(probe).get("mp_loss", -1))
		"memory_countermeasure":
			signature_state["last_offense"] = "attack"
			probe["signature_state"] = signature_state
			return int((CombatSystemScript.action_forecasts(state, probe).attack as Dictionary).get(
				"signature_power_percent", -1))
		"adaptive_void_ward":
			signature_state["ward"] = "attack"
			probe["signature_state"] = signature_state
			return int((CombatSystemScript.action_forecasts(state, probe).attack as Dictionary).get(
				"signature_power_percent", -1))
		"corrosive_black_rain":
			return int((CombatSystemScript.action_forecasts(state, probe).guard as Dictionary).get(
				"bleed_clear", -1))
		"shield_plunder":
			probe["intent"] = "guard"
			return int(CombatSystemScript.intent_forecast(probe).get("shield_plunder_max", -1))
		"breath_levy":
			return int((CombatSystemScript.action_forecasts(state, probe).guard as Dictionary).get(
				"extra_mp_cost", -1))
		"silent_seal":
			return int((CombatSystemScript.action_forecasts(state, probe).spell as Dictionary).get(
				"silence_applied", -1))
		"rotating_heaven_law":
			signature_state["edict_action"] = "attack"
			probe["signature_state"] = signature_state
			return int((CombatSystemScript.action_forecasts(state, probe).attack as Dictionary).get(
				"signature_hp_cost", -1))
		"unbound_edge":
			probe["intent"] = "strike"
			return int(CombatSystemScript.intent_forecast(probe).get("shield_pierce_percent", -1))
		"ink_decree":
			signature_state["last_action"] = "attack"
			probe["signature_state"] = signature_state
			return int((CombatSystemScript.action_forecasts(state, probe).attack as Dictionary).get(
				"signature_hp_cost", -1))
		"soul_furnace":
			signature_state["heat"] = 3
			probe["signature_state"] = signature_state
			probe["intent"] = "heavy"
			return int(CombatSystemScript.intent_forecast(probe).get(
				"furnace_multiplier_percent", -1))
		"identity_rollback":
			signature_state["last_action"] = "attack"
			probe["signature_state"] = signature_state
			return int((CombatSystemScript.action_forecasts(state, probe).attack as Dictionary).get(
				"signature_power_percent", -1))
		"ash_eclipse":
			signature_state["ash"] = 3
			probe["signature_state"] = signature_state
			probe["intent"] = "strike"
			return 1 if bool(CombatSystemScript.intent_forecast(probe).get(
				"ash_burst_ready", false)) else 0
		"life_foreclosure":
			return 1 if bool((CombatSystemScript.action_forecasts(state, probe).pill as Dictionary).get(
				"available", false)) else 0
		"name_erasure":
			signature_state["last_action"] = "attack"
			probe["signature_state"] = signature_state
			return int((CombatSystemScript.action_forecasts(state, probe).attack as Dictionary).get(
				"signature_hp_cost", -1))
	return -1


func _start_test_combat(state: Dictionary, enemy_id: String = "") -> Dictionary:
	if not bool(EncounterSystemScript.summary(state).get("active", false)):
		EncounterSystemScript.offer(state, "test", "回归敌踪", "仅用于验证战斗规则。", 3,
			{"enemy_id": enemy_id})
	return CombatSystemScript.start_combat(state, enemy_id)
