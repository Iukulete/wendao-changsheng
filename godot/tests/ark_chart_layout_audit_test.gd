extends SceneTree

const ArkTestPaths = preload("res://tests/ark_test_paths.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var save_root := ProjectSettings.globalize_path("res://../.local/test_ark_chart_layout_audit").simplify_path()
	assert(ArkTestPaths.is_safe_save_root(save_root))
	var service := preload("res://scripts/ark_greybox_save.gd").new(save_root)
	service.clear_for_test()
	var game := preload("res://scenes/ark_greybox.tscn").instantiate()
	game.set("save_root_override", save_root)
	root.add_child(game)
	await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	var chart := game.get("world_chart") as Control
	var points: Array[Dictionary] = game.call("_world_chart_destinations")
	chart.visible = true
	for viewport_size in [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(800, 720)]:
		root.size = viewport_size
		chart.refresh(Vector3.ZERO, points)
		await process_frame
		await process_frame
		_check_layout(chart, points, viewport_size)
	# The home marker moves with the ship and can share an island's position.
	# Labels must remain separately selectable even when their dots coincide.
	points[0]["position"] = points[1]["position"]
	chart.refresh(Vector3.ZERO, points)
	await process_frame
	await process_frame
	_check_layout(chart, points, root.size)
	for point in points:
		var labels: Dictionary = chart.get("_label_rects")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = (labels[point.id] as Rect2).get_center()
		chart.call("_gui_input", click)
		assert(str(chart.get("selected_id")) == str(point.id), "every displaced map label must select its own destination")
	var home := game.get_node("ArkRoot/homeMarker/Name") as Label3D
	var helm := game.get_node("ArkRoot/helmMarker/Name") as Label3D
	assert(is_equal_approx(home.pixel_size, 0.009) and is_equal_approx(helm.pixel_size, 0.009), "nearby labels must not regress to 5–8 screen pixels")
	assert(home.visible and helm.visible, "readability must not hide interaction names")
	assert(home.position.y < helm.position.y, "home and helm nameplates need distinct heights")
	assert(str(game.call("_interaction_hint_action", "helm")) == "掌舵仙舟", "the focused helm hint must name the steering action")
	game.call("_build_storage_at", Vector3(2.0, 0.12, -1.5))
	var storage_name := game.get_node("ArkRoot/StorageInteractable/Name") as Label3D
	assert(storage_name.text.contains("E") and storage_name.text.contains("存取木料"), "compact storage labels must preserve the interaction key and action")
	assert(storage_name.text.contains("\n"), "storage affordance should use a bounded second line instead of crowding nearby names")
	assert(storage_name.no_depth_test, "the crate lid must not occlude the storage interaction line")
	var font_path := "res://art/fonts/ark_ui_font.tres"
	assert((home.font as FontVariation).base_font.resource_path == "res://art/fonts/NotoSansSC-Variable.ttf", "the shared font must use bundled Chinese glyphs")
	var weight_axis := TextServerManager.get_primary_interface().name_to_tag("wght")
	assert(float((home.font as FontVariation).variation_opentype.get(weight_axis, 0.0)) >= 400.0, "the variable font's hairline default is unreadable at HUD sizes")
	assert(home.font.resource_path == font_path and helm.font.resource_path == font_path, "world labels must use the bundled Chinese font")
	assert((game.get("hud") as Label).get_theme_font("font").resource_path == font_path, "HUD must not depend on system font fallback")
	assert((game.get("interaction_hint") as Label).get_theme_font("font").resource_path == font_path, "the sibling interaction hint needs the same bundled font")
	assert((game.get("save_status_notice") as Label).get_theme_font("font").resource_path == font_path, "the sibling save notice needs the same bundled font")
	assert(chart.UI_FONT == home.font, "chart and world labels must share the same bundled font resource")
	for label in game.find_children("*", "Label3D", true, false):
		assert(label.font != null and label.font.resource_path == font_path, "all generated 3D labels need bundled Chinese glyphs")
	game.queue_free()
	await process_frame
	service.clear_for_test()
	print("ARK_CHART_LAYOUT_AUDIT_TEST_OK:")
	quit()


func _check_layout(chart: Control, points: Array[Dictionary], viewport_size: Vector2i) -> void:
	var panel: Rect2 = chart.get("_panel_rect")
	var map: Rect2 = chart.get("_map_rect")
	var labels: Dictionary = chart.get("_label_rects")
	assert(panel.end.y <= viewport_size.y - 96.0, "chart footer must reserve the bottom save-warning strip")
	assert(labels.size() == points.size(), "every destination needs a readable label")
	var occupied: Array[Rect2] = []
	for point in points:
		var label: Rect2 = labels[point.id]
		assert(map.encloses(label), "map labels must stay inside the map")
		for other in occupied:
			assert(not label.intersects(other), "nearby destination names must not overlap")
		for marker in points:
			var position: Vector2 = chart.call("_world_to_map", marker.position)
			assert(not label.intersects(Rect2(position - Vector2(11, 11), Vector2(22, 22))), "labels must not cover destination dots")
		occupied.append(label)
