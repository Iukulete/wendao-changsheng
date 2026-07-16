class_name LocalAIBridge
extends Node

signal event_ready(event_data: Dictionary, metadata: Dictionary)

const DEFAULT_TIMEOUT_MS := 60000
const OUTPUT_TAGS := ["【机缘】", "【危机】", "【奇遇】", "【因果】", "【传承】"]
const BLOCKED_OUTPUT_MARKERS := [
	"model", "assistant", "system", "prompt", "genericagent", "provider",
	"c++", "ui", "按钮", "请选择", "系统提示", "隐藏设定",
]

var _active_pid := -1
var _active_started_ms := 0
var _active_timeout_ms := DEFAULT_TIMEOUT_MS
var _active_directory := ""
var _active_state: Dictionary = {}


func _ready() -> void:
	set_process(false)


func probe_runtime(root_override: String = "") -> Dictionary:
	var root := _project_root(root_override)
	var ai_root := root.path_join("ai_engine")
	var model_path := _resolve_model_path(ai_root)
	var runtime_path := ai_root.path_join("runtime").path_join("llama.cpp").path_join("llama-completion.exe")
	var generator_path := ai_root.path_join("generate_event.ps1")
	var windows_host := OS.get_name() == "Windows"
	var ready := windows_host and FileAccess.file_exists(model_path) and \
		FileAccess.file_exists(runtime_path) and FileAccess.file_exists(generator_path)
	return {
		"ready": ready,
		"local_only": true,
		"windows_host": windows_host,
		"root": root,
		"model_path": model_path,
		"runtime_path": runtime_path,
		"generator_path": generator_path,
		"code": "ready" if ready else "runtime_unavailable",
	}


func request_event(state: Dictionary, root_override: String = "",
		timeout_ms: int = DEFAULT_TIMEOUT_MS) -> Dictionary:
	if is_busy():
		return {"ok": false, "pending": false, "code": "busy"}
	var probe := probe_runtime(root_override)
	if not bool(probe.ready):
		return {
			"ok": false, "pending": false, "code": "runtime_unavailable",
			"event": fallback_event(state, "本地天机尚未就绪"), "probe": probe,
		}

	var request_directory := str(probe.root).path_join(".local").path_join("ai_bridge").path_join("current")
	if DirAccess.make_dir_recursive_absolute(request_directory) != OK:
		return {
			"ok": false, "pending": false, "code": "request_directory_failed",
			"event": fallback_event(state, "天机落笔处不可写"),
		}
	var prompt_path := request_directory.path_join("ai_prompt.txt")
	var prompt_file := FileAccess.open(prompt_path, FileAccess.WRITE)
	if prompt_file == null:
		return {
			"ok": false, "pending": false, "code": "prompt_write_failed",
			"event": fallback_event(state, "天机上下文无法封存"),
		}
	prompt_file.store_string(build_prompt(state))
	prompt_file.close()
	for stale_name in ["ai_event.txt", "ai_event_raw.txt", "ai_scene.json", "ai_status.txt", "ai_backend.txt"]:
		var stale_path := request_directory.path_join(stale_name)
		if FileAccess.file_exists(stale_path):
			DirAccess.remove_absolute(stale_path)

	_active_timeout_ms = clampi(timeout_ms, 5000, 90000)
	var portable_timeout_seconds := maxi(5, int((_active_timeout_ms - 2000) / 1000.0))
	var arguments := PackedStringArray([
		"-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
		"-File", str(probe.generator_path),
		"-ReleaseDir", request_directory,
		"-Backend", "portable",
		"-PortableTimeoutSec", str(portable_timeout_seconds),
	])
	_active_pid = OS.create_process("powershell.exe", arguments, false)
	if _active_pid <= 0:
		_active_pid = -1
		return {
			"ok": false, "pending": false, "code": "process_start_failed",
			"event": fallback_event(state, "本地天机进程未能启动"),
		}
	_active_started_ms = Time.get_ticks_msec()
	_active_directory = request_directory
	_active_state = state.duplicate(true)
	set_process(true)
	return {"ok": true, "pending": true, "code": "generation_started", "pid": _active_pid}


func cancel() -> void:
	if _active_pid > 0 and OS.is_process_running(_active_pid):
		OS.kill(_active_pid)
	_reset_request()


func is_busy() -> bool:
	return _active_pid > 0


func _process(_delta: float) -> void:
	if _active_pid <= 0:
		set_process(false)
		return
	if Time.get_ticks_msec() - _active_started_ms >= _active_timeout_ms:
		if OS.is_process_running(_active_pid):
			OS.kill(_active_pid)
		_emit_resolution(resolve_timeout(_active_state))
		return
	if OS.is_process_running(_active_pid):
		return
	var output_path := _active_directory.path_join("ai_event.txt")
	var backend_path := _active_directory.path_join("ai_backend.txt")
	var generated_text := _read_text(output_path)
	var backend := _read_text(backend_path)
	if backend.is_empty():
		backend = "portable-local"
	_emit_resolution(resolve_generated_text(generated_text, _active_state, backend))


func _emit_resolution(resolution: Dictionary) -> void:
	var event_data: Dictionary = resolution.get("event", fallback_event(_active_state, "天机没有留下可用文字"))
	var metadata := resolution.duplicate(true)
	metadata.erase("event")
	_reset_request()
	event_ready.emit(event_data, metadata)


func _reset_request() -> void:
	_active_pid = -1
	_active_started_ms = 0
	_active_directory = ""
	_active_state = {}
	set_process(false)


func resolve_generated_text(text: String, state: Dictionary, backend: String = "local-fixture") -> Dictionary:
	var parsed := parse_event_text(text, state)
	if not bool(parsed.get("ok", false)):
		return {
			"ok": false, "code": str(parsed.get("code", "invalid_output")),
			"fallback": true, "backend": backend.left(96),
			"event": fallback_event(state, "本地天机文字未通过规则校验"),
		}
	return {
		"ok": true, "code": "generated", "fallback": false,
		"backend": backend.left(96), "event": parsed.event,
	}


func resolve_timeout(state: Dictionary) -> Dictionary:
	return {
		"ok": false, "code": "timeout", "fallback": true, "backend": "portable-local",
		"event": fallback_event(state, "本地天机推演超时"),
	}


func parse_event_text(text: String, state: Dictionary) -> Dictionary:
	var cleaned := text.replace("\r", "").strip_edges()
	if cleaned.is_empty() or cleaned.length() > 1200:
		return {"ok": false, "code": "empty_or_oversized"}
	var lowered := cleaned.to_lower()
	for marker in BLOCKED_OUTPUT_MARKERS:
		if lowered.contains(marker):
			return {"ok": false, "code": "unsafe_output"}
	if int(state.get("generation", 1)) <= 1:
		for forbidden_memory in ["前世", "转世", "上一世", "旧日因果"]:
			if cleaned.contains(forbidden_memory):
				return {"ok": false, "code": "first_life_memory_leak"}

	var lines: Array[String] = []
	for raw_line in cleaned.split("\n"):
		var line := str(raw_line).strip_edges()
		if not line.is_empty():
			lines.append(line)
	if lines.size() != 5:
		return {"ok": false, "code": "invalid_line_count"}
	var title := lines[0].left(48)
	var valid_tag := false
	for tag in OUTPUT_TAGS:
		if title.begins_with(tag):
			valid_tag = true
			break
	if not valid_tag:
		return {"ok": false, "code": "invalid_title_tag"}
	var description := lines[1].left(240)
	if description.length() < 20:
		return {"ok": false, "code": "description_too_short"}
	var choice_texts: Array[String] = []
	for index in range(2, 5):
		var choice_text := lines[index].strip_edges().left(16)
		if choice_text.length() < 2 or choice_texts.has(choice_text):
			return {"ok": false, "code": "invalid_choice"}
		choice_texts.append(choice_text)
	return {"ok": true, "code": "valid", "event": _event_from_prose(state, title, description, choice_texts, "local_ai")}


func fallback_event(state: Dictionary, reason: String = "规则天机接管") -> Dictionary:
	var world: Dictionary = state.get("world", {})
	var player: Dictionary = state.get("player", {})
	var npcs: Array = world.get("npcs", [])
	var witness_name := "无名行者"
	for npc_value in npcs:
		var npc: Dictionary = npc_value
		if bool(npc.get("alive", true)):
			witness_name = str(npc.get("name", witness_name))
			break
	var title := "【因果】年史来客"
	var description := "%s带来第%d年的一页残史：旧盟正在松动，而你留下的道痕恰好能改变其中一处空白。" % [
		witness_name, int(world.get("year", 1))]
	var choices: Array[String] = ["替人守约", "查明旧因", "借势破局"]
	var event_data := _event_from_prose(state, title, description, choices, "rule_fallback")
	event_data["fallback_reason"] = reason.left(120)
	event_data["player_realm_id"] = str(player.get("realm_id", "mortal"))
	return event_data


func _event_from_prose(state: Dictionary, title: String, description: String,
		choice_texts: Array[String], source: String) -> Dictionary:
	var era_name := str(state.get("current_era", "古典修仙纪"))
	var stable_material := "%s|%s|%s|%s" % [
		str(state.get("run_id", "wendao")), int((state.get("world", {}) as Dictionary).get("year", 1)),
		title, "|".join(choice_texts)]
	return {
		"id": "ai_%s" % stable_material.sha256_text().left(16),
		"era": era_name,
		"source": source,
		"title": title,
		"description": description,
		"choices": [
			{"text": choice_texts[0], "deltas": {"karma": 3, "reputation": 1},
				"path_deltas": {"compassion": 3, "bonds": 2},
				"outcome": "你替人承住因果，年史里多出一笔愿意回望你的名字。"},
			{"text": choice_texts[1], "deltas": {"exp": 40, "dao_heart": 1},
				"path_deltas": {"insight": 3, "creation": 1},
				"outcome": "你没有急着站队，而是从矛盾的证词里照见更深的旧因。"},
			{"text": choice_texts[2], "deltas": {"exp": 25, "enmity": 1},
				"path_deltas": {"defiance": 3, "ambition": 2},
				"outcome": "你把裂隙化作自己的道路，也让暗处多了一双记住你的眼睛。"},
		],
	}


func build_prompt(state: Dictionary) -> String:
	var player: Dictionary = state.get("player", {})
	var world: Dictionary = state.get("world", {})
	var legacy: Dictionary = state.get("legacy", {})
	var generation := maxi(1, int(state.get("generation", 1)))
	var lines: Array[String] = [
		"你是修仙Roguelike事件模型。严格只输出5行：标题、描述、选项一、选项二、选项三。",
		"标题以【机缘】【危机】【奇遇】【因果】【传承】之一开头；三个选项只写行动短语。",
		"模型只负责叙事措辞，不决定数值、奖励、死亡或存档。不要解释规则。",
		"玩家: %s" % str(player.get("name", "无名客")).left(32),
		"境界名称: %s%d层" % [str(player.get("realm", "凡人")).left(24), int(player.get("level", 1))],
		"年龄: %d/%d" % [int(player.get("age", 16)), int(player.get("lifespan", 80))],
		"时代纪元: %s；世界第%d年；灵潮%d；稳定%d；纪元压力%d。" % [
			str(state.get("current_era", "古典修仙纪")).left(32), int(world.get("year", 1)),
			int(world.get("qi_tide", 50)), int(world.get("stability", 65)), int(world.get("era_pressure", 0))],
	]
	if generation <= 1:
		lines.append("因果: 第一世，尚无明确前世记忆；只能写今生直觉与黑白旧玉异样。")
	else:
		var echoes: Array = legacy.get("inherited_echoes", [])
		lines.append("因果: 第%d世；继承回响: %s" % [generation, _summarize_echoes(echoes)])
	var npcs: Array = world.get("npcs", [])
	var npc_count := 0
	lines.append("同世人物:")
	for npc_value in npcs:
		var npc: Dictionary = npc_value
		if not bool(npc.get("alive", true)):
			continue
		lines.append("- %s，%s，立场%s。" % [
			str(npc.get("name", "无名")).left(32), str(npc.get("realm", "凡人")).left(20),
			str(npc.get("stance", "未明")).left(20)])
		npc_count += 1
		if npc_count >= 4:
			break
	lines.append("最近记忆:")
	var memories: Array = state.get("recent_memories", [])
	for memory_value in memories.slice(maxi(0, memories.size() - 5)):
		lines.append("- %s" % str(memory_value).replace("\n", " ").left(160))
	return "\n".join(lines).left(5000)


func _summarize_echoes(echoes: Array) -> String:
	var names: Array[String] = []
	for echo_value in echoes.slice(0, 4):
		if echo_value is Dictionary:
			names.append(str((echo_value as Dictionary).get("name", "无名回响")).left(32))
	return "无" if names.is_empty() else "、".join(names)


func _project_root(root_override: String) -> String:
	if not root_override.strip_edges().is_empty():
		return root_override.simplify_path()
	return ProjectSettings.globalize_path("res://").path_join("..").simplify_path()


func _resolve_model_path(ai_root: String) -> String:
	var environment_path := OS.get_environment("WENDAO_GGUF_MODEL").strip_edges()
	if not environment_path.is_empty():
		return environment_path if environment_path.is_absolute_path() else ai_root.path_join(environment_path).simplify_path()
	var config_path := ai_root.path_join("model_path.txt")
	var configured := _read_text(config_path)
	if not configured.is_empty():
		return configured if configured.is_absolute_path() else ai_root.path_join(configured).simplify_path()
	return ai_root.path_join("models").path_join("gemma-4-E4B_q4_0-it.gguf")


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text().strip_edges()
	file.close()
	return text
