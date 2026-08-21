extends SceneTree

const ChronicleSystemScript = preload("res://scripts/chronicle_system.gd")
const GameStateScript = preload("res://scripts/game_state.gd")

const RESOURCE_REACHABILITY_ERAS := [
	"classical", "steam", "star_network", "wasteland", "final_age", "immortal_dynasty",
]
const EXPECTED_STARTING_STONES := 10
const EXPECTED_STARTING_PILLS := 0

var failures: Array[String] = []


func _init() -> void:
	for era_id in RESOURCE_REACHABILITY_ERAS:
		var probe_state := GameStateScript.create_new_game("资源可达校验", 20260820,
			[7, 7, 7, 7, 7])
		_expect(int(probe_state.player.spirit_stones) == EXPECTED_STARTING_STONES and
			int(probe_state.player.pills) == EXPECTED_STARTING_PILLS,
			"新档资源基线发生变化；Python 长卷门禁也必须同步更新")
		var volume := ChronicleSystemScript.load_volume(era_id)
		var path := _strict_resource_path(era_id, volume,
			int(probe_state.player.spirit_stones), int(probe_state.player.pills))
		_expect(path.size() == (volume.get("chapters", []) as Array).size(),
			"%s 必须从真实新档资源找到完整直读路线" % era_id)
		if path.size() == (volume.get("chapters", []) as Array).size():
			_replay_runtime_path(era_id, path)

	_finish()


func _strict_resource_path(era_id: String, volume: Dictionary, starting_stones: int,
		starting_pills: int) -> Array[String]:
	var frontier := {
		_balance_key(starting_stones, starting_pills): {
			"spirit_stones": starting_stones,
			"pills": starting_pills,
			"path": [],
		},
	}
	for chapter_value in (volume.get("chapters", []) as Array):
		var chapter: Dictionary = chapter_value
		var chapter_id := str(chapter.get("id", "unknown_chapter"))
		var next_frontier := {}
		for state_value in frontier.values():
			var resource_state: Dictionary = state_value
			var stones := int(resource_state.get("spirit_stones", 0))
			var pills := int(resource_state.get("pills", 0))
			var affordable := 0
			for choice_value in (chapter.get("choices", []) as Array):
				var choice: Dictionary = choice_value
				var deltas: Dictionary = choice.get("deltas", {})
				var next_stones := stones + int(deltas.get("spirit_stones", 0))
				var next_pills := pills + int(deltas.get("pills", 0))
				if next_stones < 0 or next_pills < 0:
					continue
				affordable += 1
				var next_path: Array = (resource_state.get("path", []) as Array).duplicate()
				next_path.append(str(choice.get("id", "unknown_choice")))
				var key := _balance_key(next_stones, next_pills)
				if not next_frontier.has(key):
					next_frontier[key] = {
						"spirit_stones": next_stones,
						"pills": next_pills,
						"path": next_path,
					}
			if affordable == 0:
				var trail: Array = resource_state.get("path", [])
				var recent: Array = trail.slice(maxi(0, trail.size() - 6))
				_expect(false, "%s/%s 可在 %d 灵石、%d 丹药时软锁；最近路线：%s" % [
					era_id, chapter_id, stones, pills, " > ".join(recent),
				])
		if next_frontier.is_empty():
			_expect(false, "%s/%s 无法从真实新档资源继续" % [era_id, chapter_id])
			return []
		frontier = next_frontier

	var completed_state: Dictionary = frontier.values()[0]
	var raw_path: Array = completed_state.get("path", [])
	var result: Array[String] = []
	for choice_id in raw_path:
		result.append(str(choice_id))
	return result


func _replay_runtime_path(era_id: String, path: Array[String]) -> void:
	var state := GameStateScript.create_new_game("资源可达重放", 20260821,
		[7, 7, 7, 7, 7])
	state.current_era_id = era_id
	state.current_era = str(GameStateScript.ERA_NAMES.get(era_id, era_id))
	for choice_id in path:
		var event := ChronicleSystemScript.next_event(state)
		_expect(not event.is_empty(), "%s 在重放 %s 前必须仍有下一章" % [era_id, choice_id])
		if event.is_empty():
			return
		var choices: Array = event.get("choices", [])
		var choice_index := -1
		for index in range(choices.size()):
			if str((choices[index] as Dictionary).get("id", "")) == choice_id:
				choice_index = index
				break
		_expect(choice_index >= 0, "%s 重放找不到选择 %s" % [era_id, choice_id])
		if choice_index < 0:
			return
		var choice: Dictionary = choices[choice_index]
		_expect(bool(choice.get("available", false)),
			"%s 重放选择 %s 必须按运行时规则可用：%s" % [era_id, choice_id,
				str(choice.get("unavailable_reason", ""))])
		if not bool(choice.get("available", false)):
			return
		var before_stones := int(state.player.spirit_stones)
		var before_pills := int(state.player.pills)
		var deltas: Dictionary = choice.get("deltas", {})
		var resolution := ChronicleSystemScript.resolve_choice(state, event, choice_index)
		_expect(bool(resolution.get("ok", false)), "%s 重放选择 %s 必须成功结算：%s" % [
			era_id, choice_id, str(resolution.get("code", "unknown")),
		])
		if not bool(resolution.get("ok", false)):
			return
		_apply_main_choice_deltas(state, choice)
		_expect(int(state.player.spirit_stones) == before_stones +
			int(deltas.get("spirit_stones", 0)) and int(state.player.pills) == before_pills +
			int(deltas.get("pills", 0)), "%s/%s 必须实际应用主界面的资源增减" % [
				era_id, choice_id,
			])
		_expect(int(state.player.spirit_stones) >= 0 and int(state.player.pills) >= 0,
			"%s/%s 结算后资源不得为负" % [era_id, choice_id])

	_expect(bool((state.story.life_chronicle as Dictionary).get("completed", false)) and
		ChronicleSystemScript.next_event(state).is_empty(),
		"%s 的正常资源重放必须抵达真实完卷" % era_id)


func _apply_main_choice_deltas(state: Dictionary, choice: Dictionary) -> void:
	var player: Dictionary = state.get("player", {})
	var deltas: Dictionary = choice.get("deltas", {})
	for key_value in deltas.keys():
		var key := str(key_value)
		if player.has(key):
			player[key] = int(player[key]) + int(deltas[key_value])
	var path_deltas: Dictionary = choice.get("path_deltas", {})
	var player_path: Dictionary = player.get("path", {})
	for path_value in path_deltas.keys():
		var path_id := str(path_value)
		if player_path.has(path_id):
			player_path[path_id] = int(player_path[path_id]) + int(path_deltas[path_value])
	player["path"] = player_path
	player["hp"] = clampi(int(player.get("hp", 0)), 0, int(player.get("max_hp", 0)))
	player["exp"] = maxi(0, int(player.get("exp", 0)))
	player["total_events"] = int(player.get("total_events", 0)) + 1
	state["player"] = player


func _balance_key(spirit_stones: int, pills: int) -> String:
	return "%d|%d" % [spirit_stones, pills]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHRONICLE_RESOURCE_REACHABILITY_TEST_OK: default resources, strict frontier and runtime delta replay passed")
		quit(0)
		return
	for failure in failures:
		push_error("CHRONICLE_RESOURCE_REACHABILITY_TEST_FAILED: %s" % failure)
	quit(1)
