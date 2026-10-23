extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const TestPaths = preload("res://tests/ark_test_paths.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var original: Variant = ProjectSettings.get_setting("application/config/version")
	assert(original is String and original == "0.1.003", "game version preserves its three-digit repair field")
	var save_root := ProjectSettings.globalize_path("res://../.local/test_ark_game_version").simplify_path()
	assert(TestPaths.is_safe_save_root(save_root))
	# The second instance proves the menu reads the authority, not a copied literal.
	for version in [original, "12.8.010"]:
		ProjectSettings.set_setting("application/config/version", version)
		var menu := MainScene.instantiate()
		menu.set("save_root_override", save_root)
		root.add_child(menu)
		await process_frame
		var label := menu.find_child("ArkMenuVersion", true, false) as Label
		assert(label != null and label.text == "版本 " + str(version))
		assert(label.is_visible_in_tree())
		menu.queue_free()
		await process_frame
	ProjectSettings.set_setting("application/config/version", original)
	print("ARK_GAME_VERSION_TEST_OK: menu uses authoritative project version")
	quit()
