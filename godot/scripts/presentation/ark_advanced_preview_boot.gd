extends SceneTree
## Advanced launcher guard, before loading a game scene or touching a save.
func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	var version := Engine.get_version_info()
	if int(version.major) != 4 or int(version.minor) != 7 or int(version.patch) != 1:
		printerr("ADVANCED_PREVIEW_REFUSED: requires Godot 4.7.1; default launcher remains available.")
		quit(2); return
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		printerr("ADVANCED_PREVIEW_REFUSED: Forward+ Vulkan is unavailable. No volumetric preview was started. Use the ordinary compatibility launcher.")
		quit(3); return
	if OS.get_environment("ARK_HD2D_ATMOSPHERE") != "1" or OS.get_environment("ARK_HD2D") == "0":
		printerr("ADVANCED_PREVIEW_REFUSED: explicit HD2D atmosphere opt-in is required.")
		quit(4); return
	print("ADVANCED_PREVIEW_READY: Forward+ / real local volumetrics / authored single sun proxy; hardware performance not certified.")
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	if main_scene.is_empty() or change_scene_to_file(main_scene) != OK:
		printerr("ADVANCED_PREVIEW_REFUSED: current source main scene could not be loaded.")
		quit(5)
