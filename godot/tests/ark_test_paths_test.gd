extends SceneTree

const Paths = preload("res://tests/ark_test_paths.gd")


func _initialize() -> void:
	var root := ProjectSettings.globalize_path("res://../.local").simplify_path()
	var valid := root.path_join("test_path_guard")
	var allowed_host := OS.get_name() != "Windows" or valid.to_lower().begins_with("d:/")
	assert(Paths.is_safe_save_root(valid) == allowed_host, "only the permitted platform-local test directory is safe")
	assert(not Paths.is_safe_save_root(root.path_join("save")), "production saves are never test targets")
	assert(not Paths.is_safe_save_root(root.path_join("test_a/../save")), "normalized traversal cannot reach player saves")
	assert(not Paths.is_safe_save_root(root.path_join("test_a/child")), "test roots must be direct isolated children")
	assert(not Paths.is_safe_save_root(root + "-other/test_a"), "a matching directory prefix is not the same repository")
	assert(not Paths.is_safe_save_root("/tmp/test_a"), "external directories are not test targets")
	assert(not Paths.is_safe_save_root("C:/test_a"), "Windows C: is never a test target")
	print("ARK_TEST_PATHS_TEST_OK:")
	quit()
