extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const EncounterSystemScript = preload("res://scripts/encounter_system.gd")

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
	state.player.total_events = 2
	var choice_offer := EncounterSystemScript.offer_from_choice(state,
		{"title": "灯河旧契"}, {"deltas": {"enmity": 0}, "path_deltas": {"bonds": 2}})
	_expect(str(choice_offer.get("code", "")) == "encounter_offered" and
		str((choice_offer.encounter as Dictionary).title).contains("灯河旧契"),
		"事件节奏必须通过统一规则生成带来源的敌踪")
	state.generation = 2
	var reincarnated := EncounterSystemScript.normalize(state)
	_expect(not bool(reincarnated.active), "旧世敌踪不得追进下一次轮回")
	if failures.is_empty():
		print("ENCOUNTER_SYSTEM_TEST_OK: contextual offer, consume, expiry and world pressure passed")
		quit(0)
	else:
		for failure in failures:
			push_error("ENCOUNTER_SYSTEM_TEST_FAILED: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
