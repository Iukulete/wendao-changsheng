extends SceneTree

const PipelineScript = preload("res://scripts/combat_event_pipeline.gd")

var failures: Array[String] = []


func _init() -> void:
	var battle := {"id": "battle_contract", "turn": 3}
	var event_a := _build_event(battle)
	var event_b := _build_event(battle)
	_expect(event_a == event_b, "相同战局与行动必须产生完全一致的事件轨迹")
	_expect(bool(PipelineScript.validate(event_a).get("ok", false)),
		"完成的事件必须通过生命周期与步骤契约校验")
	_expect(str(event_a.get("trace_hash", "")).length() == 64,
		"完成事件必须带稳定的 SHA-256 轨迹哈希")

	var invalid_order := PipelineScript.begin(battle, "guard")
	PipelineScript.advance(invalid_order, "action_content")
	var backwards := PipelineScript.advance(invalid_order, "action_begin")
	_expect(not bool(backwards.get("ok", false)) and
		str(backwards.get("code", "")) == "invalid_phase_order",
		"事件相位不得倒退或重复")

	var no_phase := PipelineScript.begin(battle, "spell")
	var premature_emit := PipelineScript.emit(no_phase, "action", "player", "enemy", "越序")
	_expect(not bool(premature_emit.get("ok", false)) and
		str(premature_emit.get("code", "")) == "event_phase_required",
		"created 状态不得直接写入效果步骤")

	var cancelled := PipelineScript.begin(battle, "flee")
	PipelineScript.advance(cancelled, "before_action")
	PipelineScript.cancel(cancelled, "退路不存在")
	_expect(str(cancelled.get("status", "")) == "cancelled" and
		not bool(PipelineScript.complete(cancelled).get("ok", false)),
		"取消的事件不得再次结算")

	var tampered := event_a.duplicate(true)
	(tampered.steps[1] as Dictionary)["value"] = 999
	_expect(not bool(PipelineScript.validate(tampered).get("ok", false)),
		"轨迹内容被篡改后必须由哈希校验拒绝")

	var history_battle := {"event_history": []}
	for index in range(PipelineScript.MAX_HISTORY + 4):
		var history_event := _build_event({"id": "history", "turn": index + 1})
		PipelineScript.append_history(history_battle, history_event)
	_expect((history_battle.event_history as Array).size() == PipelineScript.MAX_HISTORY and
		int((history_battle.event_history as Array)[0].turn) == 5,
		"事件历史必须按固定上限淘汰最旧轨迹")

	if failures.is_empty():
		print("COMBAT_EVENT_PIPELINE_TEST_OK: structured lifecycle is deterministic and bounded")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _build_event(battle: Dictionary) -> Dictionary:
	var event := PipelineScript.begin(battle, "attack")
	PipelineScript.advance(event, "before_action")
	PipelineScript.emit(event, "action", "player", "battle", "选定斩击", 0,
		"combat_action_selected", {"action_id": "attack"})
	PipelineScript.advance(event, "action_begin")
	PipelineScript.advance(event, "action_content")
	PipelineScript.emit(event, "damage", "player", "enemy", "剑锋命中", 12,
		"combat_attack", {"action_id": "attack"})
	PipelineScript.advance(event, "action_end")
	PipelineScript.advance(event, "after_action")
	PipelineScript.advance(event, "turn_end")
	PipelineScript.complete(event, {"outcome": "active", "next_turn": int(battle.turn) + 1})
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
