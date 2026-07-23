extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const EncounterSystemScript = preload("res://scripts/encounter_system.gd")
const StorySystemScript = preload("res://scripts/story_system.gd")
const NarrativeConsequenceScript = preload("res://scripts/narrative_consequence_system.gd")

const REQUIRED_CONTEXT_FIELDS := [
	"encounter_id", "base_enemy_id", "enemy_name", "motivation", "stakes", "victory_consequence",
	"defeat_consequence", "escape_consequence",
]

var failures: Array[String] = []


func _init() -> void:
	var state := GameStateScript.create_new_game("追踪者", 20260721, [6, 6, 6, 6, 6])
	var initial := EncounterSystemScript.summary(state)
	_expect(not bool(initial.active), "新生不应无故常驻战斗入口")
	var offered := EncounterSystemScript.offer(state, "event", "镜湖追兵", "你刚才的抉择被人盯上，三次年轮内仍可追索。")
	_expect(bool(offered.get("ok", false)) and bool(EncounterSystemScript.summary(state).active),
		"因果事件必须能生成有期限的敌踪")
	state.turn = 2
	var summary := EncounterSystemScript.summary(state)
	_expect(int(summary.remaining_turns) == 1, "敌踪摘要必须显示剩余回应窗口")
	var consumed := EncounterSystemScript.consume(state)
	_expect(bool(consumed.get("ok", false)) and not bool(EncounterSystemScript.summary(state).active),
		"进入战斗后敌踪必须被消费，避免战斗按钮无限常亮")
	var second := EncounterSystemScript.offer(state, "world", "失控灵潮", "灵潮正在抬高压力。")
	_expect(bool(second.get("ok", false)), "消费后应能产生下一次独立敌踪")
	state.turn = 6
	var expired := EncounterSystemScript.expire_if_needed(state)
	_expect(bool(expired.get("expired", false)) and int(state.world.stability) == 62 and
		int(state.world.era_pressure) == 2,
		"逾期敌踪必须改变世界，而非静默消失")
	_test_authored_story_encounters(state)
	_test_identity_contract()
	state.player.total_events = 200
	var quiet_choice := EncounterSystemScript.offer_from_choice(state,
		{"id": "lantern_vow", "title": "灯河旧契"},
		{"id": "keep_vow", "text": "替故人守住灯火", "deltas": {"enmity": 9},
			"path_deltas": {"bonds": 2}})
	_expect(str(quiet_choice.get("code", "")) == "choice_left_no_enemy" and
		not bool(EncounterSystemScript.summary(state).active),
		"普通选择不得因游玩次数、事件奇偶或单一仇怨数值自动点亮战斗")
	var choice_offer := EncounterSystemScript.offer_from_choice(state,
		{"id": "lantern_vow", "title": "灯河旧契"},
		{"id": "break_seal", "text": "当众斩断追魂印", "deltas": {"enmity": 0},
			"path_deltas": {"defiance": 2}, "combat_trigger": true,
			"encounter": {"enemy_id": "classical_oath_breaker", "enemy_name": "镜湖执令者",
				"motivation": "执令者循着断印的气息追到灯河。",
				"stakes": "若无人阻止，他会把守灯人的名字重新写回追魂册。",
				"victory_consequence": "追魂册被夺回，守灯人得以离开镜湖。",
				"defeat_consequence": "追魂印落回你身上，此世止于灯河。",
				"escape_consequence": "执令者带着追魂册退入夜色，旧契仍未了结。"}})
	_expect(str(choice_offer.get("code", "")) == "encounter_offered" and
		str((choice_offer.encounter as Dictionary).title).contains("灯河旧契") and
		str((choice_offer.encounter as Dictionary).source_event_id) == "lantern_vow" and
		str((choice_offer.encounter as Dictionary).source_choice_id) == "break_seal" and
		str((choice_offer.encounter as Dictionary).enemy_name) == "镜湖执令者" and
		not str((choice_offer.encounter as Dictionary).stakes).is_empty(),
		"显式冲突必须保存来源章节、选择、敌人身份、动机、赌注和结果")
	_test_expired_encounter_resolves_authored_aftermath()
	_test_adversary_rematch_ledger()
	state.generation = 2
	var reincarnated := EncounterSystemScript.normalize(state)
	_expect(not bool(reincarnated.active), "旧世敌踪不得追进下一次轮回")
	if failures.is_empty():
		print("ENCOUNTER_SYSTEM_TEST_OK: explicit contextual offer, no rhythm spawn, consume, expiry and world pressure passed")
		quit(0)
	else:
		for failure in failures:
			push_error("ENCOUNTER_SYSTEM_TEST_FAILED: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _test_authored_story_encounters(state: Dictionary) -> void:
	var definitions: Dictionary = StorySystemScript.load_definitions()
	var explicit_count := 0
	var authored_ids := {}
	var quiet_choice: Dictionary = {}
	var quiet_event: Dictionary = {}
	for arc_value in (definitions.get("arcs", []) as Array):
		if not arc_value is Dictionary:
			continue
		var arc: Dictionary = arc_value
		for phase in ["main", "echo"]:
			var nodes_value: Variant = arc.get(phase, [])
			if not nodes_value is Array:
				continue
			for node_value in nodes_value as Array:
				if not node_value is Dictionary:
					continue
				var node: Dictionary = node_value
				for choice_value in (node.get("choices", []) as Array):
					if not choice_value is Dictionary:
						continue
					var choice: Dictionary = choice_value
					if bool(choice.get("combat_trigger", false)):
						explicit_count += 1
						var encounter_value: Variant = choice.get("encounter", {})
						_expect(encounter_value is Dictionary,
							"显式战斗选择必须附带 encounter 叙事对象：%s" % str(choice.get("id", "")))
						if encounter_value is Dictionary:
							var encounter: Dictionary = encounter_value
							for field in REQUIRED_CONTEXT_FIELDS:
								_expect(not str(encounter.get(field, "")).strip_edges().is_empty(),
									"战斗选择 %s 缺少叙事字段 %s" % [str(choice.get("id", "")), field])
							var authored_id := str(encounter.get("encounter_id", "")).strip_edges()
							var base_id := str(encounter.get("base_enemy_id", "")).strip_edges()
							_expect(authored_id != base_id,
								"剧情敌手必须与基础战斗定义分离：%s" % str(choice.get("id", "")))
							_expect(not authored_ids.has(authored_id),
								"剧情敌手 authored ID 不得复用：%s" % authored_id)
							authored_ids[authored_id] = str(choice.get("id", ""))
							_expect(EncounterSystemScript.PROFILE_CONTRACTS.has(base_id),
								"剧情敌手的基础定义必须存在于正式敌人契约：%s" % base_id)
							if EncounterSystemScript.PROFILE_CONTRACTS.has(base_id):
								var contract_state := GameStateScript.create_new_game("剧情敌踪审计",
									str(choice.get("id", "")).hash(), [6, 6, 6, 6, 6])
								var contract_event := {"id": str(node.get("id", "")),
									"title": str(node.get("title", "剧情战斗"))}
								var contract_offer := EncounterSystemScript.offer_from_choice(
									contract_state, contract_event, choice)
								var contract_summary := EncounterSystemScript.summary(contract_state)
								var profiles: Array = EncounterSystemScript.PROFILE_CONTRACTS[base_id]
								_expect(bool(contract_offer.get("ok", false)) and
									str(contract_summary.get("encounter_id", "")) == authored_id and
									str(contract_summary.get("base_enemy_id", "")) == base_id and
									str(contract_summary.get("enemy_name", "")) == str(encounter.get("enemy_name", "")) and
									str(contract_summary.get("visual_profile_id", "")) == str(profiles[0]) and
									str(contract_summary.get("weapon_profile_id", "")) == str(profiles[1]) and
									str(contract_summary.get("vfx_profile_id", "")) == str(profiles[2]),
									"剧情敌踪必须把 authored 身份与基础视觉契约完整交给战斗层：%s" % authored_id)
							var tier := str(encounter.get("encounter_tier", "normal"))
							_expect(tier in ["normal", "elite", "boss"],
								"剧情战斗必须声明层级：%s" % str(choice.get("id", "")))
							if tier == "boss":
								_expect(not str(encounter.get("rematch_key", "")).is_empty(),
									"主线首领必须保留复战键：%s" % str(choice.get("id", "")))
					elif str(choice.get("id", "")) == "family_m4_truth":
						quiet_choice = choice.duplicate(true)
						quiet_event = {"id": str(node.get("id", "family_main_4")),
							"title": str(node.get("title", "家世终局"))}
	_expect(explicit_count >= 9 and authored_ids.size() == explicit_count,
		"剧情至少要有九个 authored 战斗入口且身份唯一，当前仅有 %d 个" % explicit_count)
	_expect(not quiet_choice.is_empty(), "必须保留一个高仇恨但不立即开战的真实剧情选择")
	if not quiet_choice.is_empty():
		var quiet_offer := EncounterSystemScript.offer_from_choice(state, quiet_event, quiet_choice)
		_expect(str(quiet_offer.get("code", "")) == "choice_left_no_enemy" and
			not bool(EncounterSystemScript.summary(state).active),
			"承认血脉等高仇恨叙事不能仅凭数值自动点亮战斗")


func _test_identity_contract() -> void:
	var state := GameStateScript.create_new_game("身份契约审计", 20260724, [6, 6, 6, 6, 6])
	var event := {"id": "legacy_story_event", "title": "旧式剧情事件"}
	var choice := {"id": "legacy_story_choice", "text": "接受旧式敌踪", "combat_trigger": true,
		"encounter": {"enemy_name": "旧式执令者", "encounter_tier": "elite"}}
	var first := EncounterSystemScript.offer_from_choice(state, event, choice)
	var first_summary := EncounterSystemScript.summary(state)
	_expect(bool(first.get("ok", false)) and str(first_summary.get("encounter_id", "")).begins_with("story_") and
		not str(first_summary.get("base_enemy_id", "")).is_empty() and
		str(first_summary.get("enemy_id", "")) == str(first_summary.get("base_enemy_id", "")),
		"缺少新字段的旧式剧情敌踪必须稳定派生 authored ID，并保留基础敌人别名")
	var state_copy := GameStateScript.create_new_game("身份契约审计", 20260724, [6, 6, 6, 6, 6])
	var second := EncounterSystemScript.offer_from_choice(state_copy, event, choice)
	var second_summary := EncounterSystemScript.summary(state_copy)
	_expect(bool(second.get("ok", false)) and
		str(first_summary.get("encounter_id", "")) == str(second_summary.get("encounter_id", "")) and
		str(first_summary.get("base_enemy_id", "")) == str(second_summary.get("base_enemy_id", "")),
		"旧式剧情敌踪的身份派生必须跨同一事件与选择保持确定性")
	var explicit_state := GameStateScript.create_new_game("身份契约审计", 20260725, [6, 6, 6, 6, 6])
	var explicit_choice := {"id": "explicit_base_choice", "text": "指定基础敌人", "combat_trigger": true,
		"encounter": {"base_enemy_id": "immortal_sky_enforcer", "enemy_name": "指定巡天执吏",
			"encounter_tier": "elite"}}
	var explicit_offer := EncounterSystemScript.offer_from_choice(explicit_state, event, explicit_choice)
	var explicit_summary := EncounterSystemScript.summary(explicit_state)
	_expect(bool(explicit_offer.get("ok", false)) and
		str(explicit_summary.get("base_enemy_id", "")) == "immortal_sky_enforcer" and
		str(explicit_summary.get("enemy_id", "")) == "immortal_sky_enforcer" and
		str(explicit_summary.get("encounter_id", "")) != "immortal_sky_enforcer",
		"只声明基础敌人的新式剧情敌踪也必须生成独立 authored ID")
	explicit_state.turn = int(explicit_summary.get("remaining_turns", 0)) + 2
	var expired := EncounterSystemScript.expire_if_needed(explicit_state)
	var authored_ledger := EncounterSystemScript.adversary_summary(explicit_state,
		str(explicit_summary.get("encounter_id", "")))
	var base_ledger := EncounterSystemScript.adversary_summary(explicit_state,
		"immortal_sky_enforcer")
	_expect(bool(expired.get("expired", false)) and not authored_ledger.is_empty() and
		str(authored_ledger.get("last_outcome", "")) == "expired" and base_ledger.is_empty(),
		"敌踪过期必须按 authored ID 记账，不能污染基础敌人账本")


func _test_expired_encounter_resolves_authored_aftermath() -> void:
	var state := GameStateScript.create_new_game("迟行者", 20260722, [6, 6, 6, 6, 6])
	var event := {"id": "sealed_vault", "title": "封库追索", "story_arc_id": "rival",
		"story_phase": "main", "story_stage": 2}
	var choice := {"id": "hold_the_gate", "text": "守住库门", "outcome": "追兵已至。",
		"route_id": "alliance", "deltas": {}, "path_deltas": {}, "combat_trigger": true,
		"combat_outcomes": {
			"victory": {"flags_add": ["vault_held"]},
			"expired": {"flags_add": ["vault_resealed"]},
		},
		"encounter": {"enemy_name": "封库追兵", "motivation": "追兵赶来夺回原件。",
			"stakes": "若无人回应，库门会再次落锁。"}}
	NarrativeConsequenceScript.apply_choice(state, event, choice)
	EncounterSystemScript.offer_from_choice(state, event, choice)
	state.turn = 4
	var expired: Dictionary = EncounterSystemScript.expire_if_needed(state)
	_expect(bool(expired.get("expired", false)) and
		bool((state.story.flags as Dictionary).get("vault_resealed", false)) and
		not bool((state.story.flags as Dictionary).get("vault_held", false)) and
		(state.story.pending_combat_consequences as Array).is_empty() and
		str((state.story.combat_consequence_history[-1] as Dictionary).outcome) == "expired",
		"放任敌踪过期必须结算过期余波，不能误写胜利事实或留下悬空因果")


func _test_adversary_rematch_ledger() -> void:
	var state := GameStateScript.create_new_game("复战见证人", 20260723, [7, 7, 7, 7, 7])
	state.erase("adversaries")
	_expect(EncounterSystemScript.adversary_summary(state).is_empty(),
		"旧存档缺失敌手账本时必须无损补空")
	var escaped := EncounterSystemScript.record_outcome(state, "immortal_fate_registrar", "boss",
		"escaped", "immortal_fate_registrar_name_erasure")
	_expect(str(escaped.get("status", "")) == "at_large" and
		bool(escaped.get("rematch_available", false)) and int(escaped.get("encounters", 0)) == 1,
		"首领撤离后必须保留在逃与可复战状态")
	var defeated := EncounterSystemScript.record_outcome(state, "immortal_fate_registrar", "boss",
		"victory", "immortal_fate_registrar_name_erasure")
	_expect(str(defeated.get("status", "")) == "defeated" and
		bool(defeated.get("rematch_available", false)) and int(defeated.get("wins", 0)) == 1 and
		int(defeated.get("encounters", 0)) == 2,
		"复战胜利必须累计会面与胜场，不能抹去前一次撤离")
	var roundtrip_value: Variant = JSON.parse_string(JSON.stringify(state))
	var roundtrip: Dictionary = roundtrip_value as Dictionary
	var restored := EncounterSystemScript.adversary_summary(roundtrip,
		"immortal_fate_registrar")
	_expect(restored == defeated, "敌手复战状态必须通过存档JSON往返")
