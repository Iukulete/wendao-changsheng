extends SceneTree
## Real native lifecycle, synthetic isolated saves; presentation is not gameplay authority.
const Paths = preload("res://tests/ark_test_paths.gd")
const Save = preload("res://scripts/ark_greybox_save.gd")
var game: Node
var hud: Node
var save_root: String

func _initialize() -> void:
	_run.call_deferred()

func _settle() -> void:
	for frame in range(4):
		await process_frame

func _tap(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event)

func _freeze() -> void:
	game.set_process(false)
	game.set_physics_process(false)
	(game.get("player") as Node).set_physics_process(false)

func _state() -> Dictionary:
	var result := {}
	for field in ["day_count", "day_period", "weather_phase", "wood", "stored_wood", "raw_shellfish", "stew_servings", "player_health", "cold_exposure_level", "shelter_built", "storage_built", "workbench_built", "shelter_roof_damaged", "raft_edge_damaged", "building_mode", "editing_fixture_id", "preview_valid", "event_sequence", "world_events", "life_period_elapsed"]:
		var value: Variant = game.get(field)
		result[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	for field in ["economy", "construction", "memories", "gathering", "water", "vessel_navigation"]:
		result[field] = game.get(field).snapshot().duplicate(true)
	result.player = (game.get("player") as Node3D).global_transform
	result.ark = (game.get("ark_root") as Node3D).global_transform
	return result

func _single_hud() -> void:
	assert(game.find_children("QANearfutureHudAdapter", "", true, false).size() == 1)
	assert(game.find_children("QANearfutureHud", "", true, false).size() == 1)
	assert(hud.get_parent() == game and hud.is_processing())
	assert(not (game.get("hud_panel") as Control).visible)

func _name_cache_counts() -> Dictionary:
	var records: Dictionary = hud.get("_world_signs")
	var live := 0
	for row in records.values():
		if is_instance_valid(row.node.get_ref()):
			live += 1
	return {"total": records.size(), "live": live, "expired": records.size() - live}

func _bounds() -> void:
	for key in ["status_panel", "objective_panel", "alert_panel", "build_panel", "keys_label"]:
		var node := hud.get(key) as Control
		if node.is_visible_in_tree():
			assert(root.get_visible_rect().encloses(node.get_global_rect()), key + " must fit viewport")
	for key in ["note_panel", "interaction_hint", "save_status_notice", "hud_drawer", "hud_toggle"]:
		var node := game.get(key) as Control
		if node.is_visible_in_tree():
			assert(root.get_visible_rect().encloses(node.get_global_rect()), key + " must fit viewport")

func _run() -> void:
	save_root = ProjectSettings.globalize_path("res://../.local/test_nearfuture_hud_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]).simplify_path()
	assert(Paths.is_safe_save_root(save_root))
	var saves := Save.new(save_root)
	var menu := load("res://scenes/main.tscn").instantiate() as Control
	menu.set("save_root_override", save_root)
	root.add_child(menu)
	current_scene = menu
	await _settle()
	(menu.get("enter_button") as Button).pressed.emit()
	await _settle()
	game = current_scene
	_freeze()
	hud = game.get("nearfuture_hud")
	assert(hud != null)
	_single_hud()
	var before := _state()
	assert(bool(game.call("_ensure_nearfuture_hud")))
	assert(bool(game.call("_ensure_nearfuture_hud")))
	for iteration in range(20):
		hud.call("refresh")
	assert(before == _state(), "HUD refresh and repeated initialization must not change live game/module state")
	_single_hud()
	var snapshot: Dictionary = hud.call("snapshot")
	assert(snapshot.health == game.get("player_health") and snapshot.wood_carried == game.get("wood"))
	assert(snapshot.wood_stored == game.get("stored_wood"))
	assert(snapshot.objective == game.call("_opening_objective_hint"))
	assert((hud.get("objective_label") as Label).text == snapshot.objective)
	for screen in [Vector2i(1280, 720), Vector2i(3440, 1440)]:
		root.size = screen
		await _settle()
		_bounds()
		assert((hud.get("status_panel") as Control).is_visible_in_tree())
	root.size = Vector2i(1280, 720)
	game.set("wood", 20)
	game.set("weather_phase", 2)
	_tap(KEY_B)
	assert(game.get("building_mode"))
	for valid in [false, true]:
		game.set("preview_valid", valid)
		game.call("_update_hud")
		await _settle()
		assert((hud.get("build_panel") as Control).is_visible_in_tree())
		assert((hud.get("build_label") as Label).text == ("可放置 · 左键确认" if valid else "位置不合适 · 请在甲板承重区内选择位置"))
		assert((game.get("note") as Label).text.contains("可放置" if valid else "位置不合适"))
	_tap(KEY_H)
	await _settle()
	assert((game.get("hud_drawer") as Control).visible and not (hud.get("build_panel") as Control).visible)
	_tap(KEY_ESCAPE)
	assert(game.get("building_mode"))
	_tap(KEY_ESCAPE)
	assert(not game.get("building_mode") and int(game.get("wood")) == 20)
	game.set("traveler_choice_pending", true)
	game.set("message", "1 邀请上筏\n2 暂不同行\nEsc 暂不决定")
	game.call("_update_hud")
	await _settle()
	assert(not (hud.get("objective_panel") as Control).visible and (game.get("hud_toggle") as Button).disabled)
	assert((game.get("note") as Label).text.contains("2 暂不同行"))
	_tap(KEY_ESCAPE)
	assert(not game.get("traveler_choice_pending"))
	game.set("message", "")
	game.call("_update_hud")
	await _settle()
	assert(not (game.get("note_panel") as Control).visible)
	game.set("message", "完整原生消息仍保留。")
	game.call("_update_hud")
	await _settle()
	assert((game.get("note_panel") as Control).visible and (game.get("note") as Label).text == "完整原生消息仍保留。")
	game.set("player_health", 1)
	game.set("cold_exposure_level", 3)
	game.set("shelter_roof_damaged", true)
	game.set("raft_edge_damaged", true)
	game.call("_update_hud")
	await _settle()
	var alerts := (hud.get("alert_label") as Label).text
	assert(alerts.contains("生命危急") and alerts.contains("彻骨 3/3 · 步速 28%"))
	assert(alerts.contains("棚顶松脱 / 筏舷松动"))
	before = _state()
	hud.call("detach")
	await _settle()
	assert(before == _state() and (game.get("hud_panel") as Control).visible)
	assert(bool(game.call("_ensure_nearfuture_hud")))
	await _settle()
	assert(before == _state())
	_single_hud()
	game.set("player_health", 4)
	game.set("cold_exposure_level", 0)
	game.set("shelter_roof_damaged", false)
	game.set("raft_edge_damaged", false)
	assert(bool(game.call("_try_place_workshop_home_template", Vector3(0, 0.12, 0))))
	assert(bool(game.call("_save_progress")))
	var saved_bytes := FileAccess.get_file_as_string(saves.get_save_path())
	var cache_before := _name_cache_counts()
	for reload_index in range(20):
		game.call("_load_progress")
		game.call("_update_hud")
		await _settle()
		_single_hud()
		assert(game.get_node_or_null("ArkRoot/BuiltStorage") != null and game.get_node_or_null("ArkRoot/BuiltWorkbench") != null)
		assert(FileAccess.get_file_as_string(saves.get_save_path()) == saved_bytes)
		assert((hud.get("objective_label") as Label).text == str(game.call("_opening_objective_hint")))
		assert(_name_cache_counts() == cache_before, "twenty fixture reloads must not accumulate expired weak-reference metadata")
	print("HUD_NAME_CACHE_BOUNDED: ", JSON.stringify({"loads": 20, "before": cache_before, "after": _name_cache_counts()}))
	# Pruning is validity-only: a live node temporarily outside the tree survives.
	var off_tree := Label3D.new()
	var off_tree_id := off_tree.get_instance_id()
	var records: Dictionary = hud.get("_world_signs")
	records[off_tree_id] = {"node": weakref(off_tree), "visible": true}
	hud.call("refresh")
	assert(records.has(off_tree_id))
	off_tree.free()
	hud.call("refresh")
	assert(not records.has(off_tree_id) and _name_cache_counts() == cache_before)
	var restored_names: Array = records.values()
	before = _state()
	hud.call("detach")
	for record in restored_names:
		var sign: Object = record.node.get_ref()
		assert(is_instance_valid(sign) and sign.get("visible") == record.visible, "detach restores every current rebuilt name")
	await _settle()
	assert(before == _state())
	assert(bool(game.call("_ensure_nearfuture_hud")))
	await _settle()
	_single_hud()
	# Real, harmless path-shape failure: a directory cannot be opened as the temp file.
	var obstruction: String = saves.get_save_path() + ".tmp"
	assert(DirAccess.make_dir_absolute(obstruction) == OK)
	_tap(KEY_F5)
	await _settle()
	var notice := game.get("save_status_notice") as Label
	var warning := str(game.get_meta("save_warning", ""))
	assert(not warning.is_empty() and notice.text == warning and notice.is_visible_in_tree())
	assert(FileAccess.get_file_as_string(saves.get_save_path()) == saved_bytes)
	game.set("traveler_choice_pending", true)
	game.set("message", "1 邀请上筏\n2 暂不同行\nEsc 暂不决定")
	game.call("_update_hud")
	await _settle()
	assert(notice.is_visible_in_tree() and notice.text == warning and (game.get("hud_toggle") as Button).disabled)
	_tap(KEY_ESCAPE)
	assert(bool(game.call("_start_fixture_edit", "storage")))
	await _settle()
	assert(notice.is_visible_in_tree() and notice.text == warning and (hud.get("build_panel") as Control).is_visible_in_tree())
	_tap(KEY_ESCAPE)
	assert(not game.get("building_mode") and FileAccess.get_file_as_string(saves.get_save_path()) == saved_bytes)
	_tap(KEY_H)
	await _settle()
	assert(notice.is_visible_in_tree() and notice.text == warning)
	_tap(KEY_M)
	await _settle()
	assert((game.get("world_chart") as Control).visible and not (hud.get("overlay") as Control).visible)
	assert(notice.is_visible_in_tree() and notice.text == warning)
	_bounds()
	_tap(KEY_ESCAPE)
	await _settle()
	assert((hud.get("overlay") as Control).visible)
	(game.find_child("ArkReturnToMainButton", true, false) as Button).pressed.emit()
	await _settle()
	assert(current_scene == game and FileAccess.get_file_as_string(saves.get_save_path()) == saved_bytes)
	assert(notice.is_visible_in_tree() and notice.text == warning)
	assert(DirAccess.remove_absolute(obstruction) == OK)
	var old_hud: WeakRef = weakref(hud)
	var old_overlay: WeakRef = weakref(hud.get("overlay"))
	(game.find_child("ArkReturnToMainButton", true, false) as Button).pressed.emit()
	await _settle()
	assert(current_scene.scene_file_path == "res://scenes/main.tscn")
	assert(old_hud.get_ref() == null and old_overlay.get_ref() == null)
	(current_scene.get("enter_button") as Button).pressed.emit()
	await _settle()
	game = current_scene
	_freeze()
	hud = game.get("nearfuture_hud")
	_single_hud()
	assert(str(game.get("save_root_override")) == save_root and game.get("shelter_built"))
	assert(not (game.get("save_status_notice") as Control).visible)
	# An invalid scene dependency may leave a stale interaction reference until
	# fresh-scene Continue. Presentation validates it before any typed cast.
	var before_invalid_reference := _state()
	var transient := Node3D.new()
	transient.name = "InvalidReferenceRegression"
	var transient_name := Label3D.new()
	transient_name.name = "Name"
	transient.add_child(transient_name)
	game.add_child(transient)
	var interactions: Array = game.get("interactables")
	interactions.append({"node": transient, "id": "wood"})
	hud.refresh()
	transient.free()
	hud.refresh()
	await _settle()
	interactions.pop_back()
	assert(_state() == before_invalid_reference, "expired interaction guard changes no gameplay/module state")
	_single_hud()
	game.queue_free()
	await _settle()
	saves.clear_for_test()
	if has_meta("ark_menu_save_root_override"):
		remove_meta("ark_menu_save_root_override")
	print("ARK_NEARFUTURE_HUD_TEST_OK: visible state, modes, read-only data, lifecycle, real isolated save failure and reload")
	quit()
