extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const LocalAIBridgeScript = preload("res://scripts/local_ai_bridge.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bridge := LocalAIBridgeScript.new()
	root.add_child(bridge)
	var state := GameStateScript.create_new_game("观微", 20260716, [6, 7, 6, 7, 6])
	state.world.npcs = [{
		"id": "npc_test", "name": "沈照川", "realm": "筑基", "stance": "insight", "alive": true,
	}]

	var missing_root := ProjectSettings.globalize_path("res://").path_join("..").path_join(".tmp").path_join("missing-ai-runtime").simplify_path()
	var probe: Dictionary = bridge.probe_runtime(missing_root)
	_expect(not bool(probe.ready) and bool(probe.local_only),
		"缺少本地模型或运行时时不得伪装为 AI 就绪")
	var disabled: Dictionary = bridge.request_event(state, missing_root, 5000)
	_expect(not bool(disabled.get("ok", true)) and str(disabled.code) == "runtime_unavailable",
		"禁用路径必须立即返回结构化降级结果")
	_expect((disabled.event as Dictionary).get("choices", []).size() == 3,
		"无模型降级仍必须给出可玩的三选项事件")

	var valid_text := "【因果】灯下旧契\n沈照川从镜湖带回一页湿透的旧契，三家势力都声称空白处原本写着你的名字。\n替他守约\n照见墨痕\n借契开路"
	var valid: Dictionary = bridge.resolve_generated_text(valid_text, state, "fixture-local")
	_expect(bool(valid.ok) and not bool(valid.fallback), "合法五行本地输出必须通过")
	_expect(str(valid.event.source) == "local_ai" and (valid.event.choices as Array).size() == 3,
		"AI 只能生成叙事外壳，必须转成规则托管的结构化事件")
	_expect((valid.event.choices[0].path_deltas as Dictionary).has("compassion"),
		"AI 事件的机械效果必须来自固定规则而非模型自由文本")

	var leaked := "【因果】旧梦\n你记起上一世在这里埋下的全部秘密，因此无需调查便知道真相。\n追问旧梦\n接受轮回\n召回前世"
	var invalid: Dictionary = bridge.resolve_generated_text(leaked, state, "fixture-local")
	_expect(not bool(invalid.ok) and bool(invalid.fallback) and
		str(invalid.code) == "first_life_memory_leak",
		"第一世记忆泄漏必须被拒绝并无损降级")
	var malformed: Dictionary = bridge.resolve_generated_text("model\n只有两行", state, "fixture-local")
	_expect(not bool(malformed.ok) and bool(malformed.fallback),
		"非法输出必须回退，不能进入事件解析器")

	var fallback_a: Dictionary = bridge.fallback_event(state, "test")
	var fallback_b: Dictionary = bridge.fallback_event(state, "test")
	_expect(fallback_a == fallback_b, "同一状态的规则降级事件必须确定性一致")
	var timeout: Dictionary = bridge.resolve_timeout(state)
	_expect(str(timeout.code) == "timeout" and bool(timeout.fallback),
		"超时路径必须返回明确状态和可玩降级事件")
	var prompt := bridge.build_prompt(state)
	_expect(prompt.contains("第一世") and not prompt.contains("上一世"),
		"第一世提示必须声明隐私边界且不注入不存在的前世记忆")

	bridge.free()
	if failures.is_empty():
		print("LOCAL_AI_BRIDGE_TEST_OK: disabled, valid, timeout and illegal-output fallback paths passed")
		quit(0)
	else:
		for failure in failures:
			push_error("LOCAL_AI_BRIDGE_TEST_FAILED: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
