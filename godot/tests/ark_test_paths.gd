extends RefCounted
## Test-only guard: isolated repository-local saves on every host, D: on Windows.
## Never permit the normal .local/save directory or a path outside this checkout.


static func is_safe_save_root(path: String) -> bool:
	var normalized := path.replace("\\", "/").simplify_path()
	var local_root := ProjectSettings.globalize_path("res://../.local").replace("\\", "/").simplify_path()
	if OS.get_name() == "Windows":
		normalized = normalized.to_lower()
		local_root = local_root.to_lower()
		if not normalized.begins_with("d:/"):
			return false
	if not normalized.begins_with(local_root + "/"):
		return false
	var leaf := normalized.trim_prefix(local_root + "/")
	return leaf.begins_with("test_") and not leaf.contains("/") and leaf.length() > 5
