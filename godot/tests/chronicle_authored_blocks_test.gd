extends SceneTree

const ChronicleSystemScript = preload("res://scripts/chronicle_system.gd")

var failures: Array[String] = []


func _init() -> void:
	var raw_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/chronicles/star_network_v1.json"))
	_expect(raw_value is Dictionary, "星网长卷源文件必须可解析")
	if not raw_value is Dictionary:
		_finish()
		return
	var raw: Dictionary = raw_value
	var raw_chapter: Dictionary = (raw.get("chapters", []) as Array)[0]
	var expected_description := _joined(raw_chapter, "description")
	var raw_choice: Dictionary = (raw_chapter.get("choices", []) as Array)[0]
	var expected_outcome := _joined(raw_choice, "outcome")

	ChronicleSystemScript.clear_cache()
	var volume := ChronicleSystemScript.load_volume("star_network")
	var chapter: Dictionary = (volume.get("chapters", []) as Array)[0]
	var choice: Dictionary = (chapter.get("choices", []) as Array)[0]
	_expect(str(chapter.get("description", "")) == expected_description,
		"运行时必须逐字、按原顺序连接人工 description_blocks")
	_expect(str(choice.get("outcome", "")) == expected_outcome,
		"运行时必须逐字、按原顺序连接人工 outcome_blocks")
	_expect(not chapter.has("description_blocks") and not choice.has("outcome_blocks"),
		"连接后的事件数据不应把编辑字段泄露到游戏界面")
	_expect(expected_description.split("\n\n", false).size() >= 12 and
		expected_outcome.split("\n\n", false).size() >= 9,
		"第一章必须保留人工划分的独立段落边界")
	_finish()


func _joined(container: Dictionary, field: String) -> String:
	var parts: Array[String] = [str(container.get(field, "")).strip_edges()]
	for block_value in (container.get("%s_blocks" % field, []) as Array):
		parts.append(str(block_value).strip_edges())
	return "\n\n".join(parts)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHRONICLE_AUTHORED_BLOCKS_TEST_OK: exact authored paragraph materialization passed")
		quit(0)
		return
	for failure in failures:
		push_error("CHRONICLE_AUTHORED_BLOCKS_TEST_FAILED: %s" % failure)
	quit(1)
