extends SceneTree

const FONT_PATHS: PackedStringArray = [
	"res://art/fonts/NotoSansSC-Variable.ttf",
	"res://art/fonts/NotoSerifSC-Variable.ttf",
]
const MANIFEST_PATH := "res://art/fonts/font_manifest.json"
const REQUIRED_GLYPHS := "问道长生天地人修炼境界突破轮回秘境卡牌能力气血灵力因果宗门师徒宿敌前世今生，。！？：；（）《》ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

var failures: Array[String] = []


func _init() -> void:
	_validate_manifest()
	for font_path in FONT_PATHS:
		_validate_font(font_path)

	if failures.is_empty():
		print("TYPOGRAPHY_SYSTEM_TEST_OK: bundled sans and serif fonts load and cover required Chinese and ASCII glyphs")
		quit(0)
	else:
		for failure in failures:
			push_error("TYPOGRAPHY_SYSTEM_TEST_FAILED: %s" % failure)
		quit(1)


func _validate_manifest() -> void:
	_expect(FileAccess.file_exists(MANIFEST_PATH), "字体清单不存在：%s" % MANIFEST_PATH)
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_expect(parsed is Dictionary, "字体清单不是有效JSON对象")
	if not parsed is Dictionary:
		return
	var entries: Array = (parsed as Dictionary).get("fonts", [])
	_expect(entries.size() == 2, "字体清单必须恰好登记标题与正文两套字体")
	for entry_value in entries:
		if not entry_value is Dictionary:
			failures.append("字体清单包含非法条目")
			continue
		var entry: Dictionary = entry_value
		var font_path := "res://art/fonts/%s" % str(entry.get("file", ""))
		var license_path := "res://art/fonts/%s" % str(entry.get("license_file", ""))
		_expect(str(entry.get("license", "")) == "OFL-1.1", "字体必须登记OFL-1.1授权：%s" % font_path)
		_expect(FileAccess.file_exists(license_path), "字体许可证不存在：%s" % license_path)
		if FileAccess.file_exists(font_path):
			_expect(FileAccess.get_sha256(font_path).to_upper() == str(entry.get("sha256", "")).to_upper(),
				"字体哈希与清单不一致：%s" % font_path)


func _validate_font(font_path: String) -> void:
	_expect(FileAccess.file_exists(font_path), "字体文件不存在：%s" % font_path)
	if not FileAccess.file_exists(font_path):
		return

	var resource := ResourceLoader.load(font_path)
	_expect(resource is Font, "字体资源无法由 Godot 加载：%s" % font_path)
	if not resource is Font:
		return

	var font := resource as Font
	var missing_glyphs := ""
	for character in REQUIRED_GLYPHS:
		if not font.has_char(character.unicode_at(0)):
			missing_glyphs += character
	_expect(missing_glyphs.is_empty(), "字体缺少必要字形（%s）：%s" % [font_path, missing_glyphs])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
