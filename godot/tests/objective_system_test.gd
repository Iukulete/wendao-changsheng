extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const ObjectiveSystemScript = preload("res://scripts/objective_system.gd")

var failures: Array[String] = []


func _init() -> void:
	var state := GameStateScript.create_new_game("立愿者", 20260721, [6, 6, 6, 6, 6])
	var initial := ObjectiveSystemScript.normalize(state)
	_expect(str(initial.active_id).is_empty() and int(initial.cycle) == 1,
		"新生命途应等待玩家主动择定，不能暗中分配目标")

	var selected := ObjectiveSystemScript.choose(state, "cultivation")
	_expect(bool(selected.get("ok", false)) and str(state.objective.active_id) == "cultivation",
		"玩家必须能择定凝神筑道目标")
	_expect(int(state.objective.deadline_turn) == 8,
		"阶段命途必须给出明确的八回合期限")
	var duplicate := ObjectiveSystemScript.choose(state, "world")
	_expect(str(duplicate.get("code", "")) == "objective_active",
		"进行中的命途不能被无代价覆盖")

	state.turn = 1
	var first := ObjectiveSystemScript.record_action(state, "meditate_steady")
	_expect(int(first.get("points", 0)) == 3 and int(state.objective.progress) == 3,
		"稳健修炼必须为凝神筑道留下三点可见进度")
	state.turn = 2
	ObjectiveSystemScript.record_action(state, "meditate_rush")
	var exp_before := int(state.player.exp)
	state.turn = 3
	var completed := ObjectiveSystemScript.record_action(state, "meditate_insight")
	_expect(str(completed.get("code", "")) == "objective_completed" and
		str(state.objective.active_id).is_empty(),
		"达到目标后必须立即结算并开放下一轮择定")
	_expect(int(state.player.exp) > exp_before and int(state.player.dao_heart) >= 2 and
		int(state.player.pills) >= 1,
		"目标完成奖励必须真实写入角色状态")
	_expect(int(state.objective.streak) == 1 and int(state.objective.completed_total) == 1,
		"连续践行与累计完成必须持久记录")

	ObjectiveSystemScript.choose(state, "world")
	state.turn = int(state.objective.deadline_turn)
	var missed := ObjectiveSystemScript.record_action(state, "meditate_steady")
	_expect(str(missed.get("code", "")) == "objective_missed" and
		int(state.objective.streak) == 0 and int(state.objective.missed_total) == 1,
		"期限耗尽应清空连续践行，但不得卡住下一次择定")

	ObjectiveSystemScript.choose(state, "battle")
	state.generation = 2
	var next_life := ObjectiveSystemScript.normalize(state)
	_expect(str(next_life.active_id).is_empty() and int(next_life.completed_total) == 1 and
		int(next_life.missed_total) == 1,
		"轮回必须重置进行中目标，同时保留跨世完成统计")

	var summary := ObjectiveSystemScript.summary(state)
	_expect(not bool(summary.active) and str(ObjectiveSystemScript.reward_text("battle", state)).contains("修为"),
		"目标摘要必须为主界面提供可读状态与奖励说明")

	if failures.is_empty():
		print("OBJECTIVE_SYSTEM_TEST_OK: choice, progress, deadline, reward and reincarnation reset passed")
		quit(0)
	else:
		for failure in failures:
			push_error("OBJECTIVE_SYSTEM_TEST_FAILED: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
